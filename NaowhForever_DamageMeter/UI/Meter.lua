-- Meter.lua: the Damage Meter window: drag, resize, scroll, its mode and session pickers, and its updates.
local ns = _G.NaowhForever

local UI = ns.UI
local DM = ns.DamageMeter
local S = DM.Settings
local C, Look = DM.C, DM.Look

local UPDATE_DELAY = 0.25
local PREVIEW_SECONDS = 10
local INSET, HEADER, ROUND = C.INSET, C.HEADER, C.ROUND
local MIN_WIDTH, MAX_WIDTH, MAX_HEIGHT = C.MIN_WIDTH, C.MAX_WIDTH, C.MAX_HEIGHT
local BUTTON_H, SMALL_W, SESSION_W, BUTTON_GAP, BUTTON_RIGHT = 18, 22, 62, 4, -6
local TITLE_PAD = 8
local GRIP_SIZE, GRIP_INSET, GRIP_LEVEL, GRIP_LOCKED_ALPHA = 20, 2, 20, 0.4
local HOME_X, HOME_Y = -24, 210
local CARD = C.PAGE .. ":meter"
local GAME_CVAR, GAME_CVAR_OFF = "damageMeterEnabled", "0"
local GAME_CVAR_SAVED = "damageMeterGameWas"
local DATA_EVENTS = { "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED",
    "DAMAGE_METER_RESET" }
local STATE_EVENTS = { "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE" }

local TEXT_MOVER = "Damage Meter"
local TEXT_OFF = "Enable the Damage Meter first."
local TEXT_IN_COMBAT = "Preview is available outside combat."
local TEXT_RESET = "Reset the damage meter data?"
local TEXT_RESET_TIP = "Clears the current and overall data."
local TEXT_MODE_TIP = "Click for the next list, right-click for the last."
local TEXT_SESSION_TIP = "Switch between the current fight and everything since the last reset."

local frame, pendingUpdate, unlocked
local offset, preview = 0, false
local updateGeneration, previewGeneration = 0, 0
local events = CreateFrame("Frame")
local Update

local function Layout(session)
    local bh, gap, fontSize = S.Get("barHeight"), S.Get("barSpacing"), S.Get("fontSize")
    frame:SetResizeBounds(MIN_WIDTH, math.max(C.MIN_HEIGHT, HEADER + 2 * INSET + bh), MAX_WIDTH, MAX_HEIGHT)
    local mode = DM.Mode(S.Get("mode"))
    local shown
    shown, offset = Look.Layout(frame, #session.combatSources, offset, bh, gap, fontSize, mode)
    frame.grip:SetShown(not unlocked)
    frame.grip:SetAlpha(S.Get("locked") and GRIP_LOCKED_ALPHA or 1)
    return shown, mode
end

local function Render(session, available)
    local shown, mode = Layout(session)
    Look.Paint(frame, session, offset, shown, mode, available)
    frame.title:SetText(mode.label)
    frame.modeButton:SetWidth(frame.title:GetStringWidth() + 2 * TITLE_PAD)
    ns.SetButtonText(frame.session, C.SESSION_LABELS[S.Get("session")] or C.SESSION_LABELS.current)
end

local function Place()
    local pos = S.Get("meterPos")
    frame:ClearAllPoints()
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", HOME_X, HOME_Y)
    end
end

local function SavePosition()
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x, y = frame:GetLeft() * scale, frame:GetTop() * scale - UIParent:GetHeight()
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
    S.Set("meterPos", { point = "TOPLEFT", relPoint = "TOPLEFT", x = x, y = y })
end

local function Cycle(step)
    local order, at = C.MODE_ORDER, 1
    for i, key in ipairs(order) do
        if key == S.Get("mode") then at = i end
    end
    offset = 0
    S.Set("mode", order[(at - 1 + step) % #order + 1])
end

local function OnModeClick(_, button)
    Cycle(button == "RightButton" and -1 or 1)
end

local function ToggleSession()
    offset = 0
    S.Set("session", S.Get("session") == "overall" and "current" or "overall")
end

local function AskReset()
    ns.Confirm(TEXT_RESET, DM.Reset)
end

local function OpenSettings()
    ns.OpenOptionsWindow(TEXT_MOVER)
end

local function OnDragStart()
    if not S.Get("locked") and not unlocked and not InCombatLockdown() then frame.moving = true; frame:StartMoving() end
end

local function OnDragStop()
    if frame.moving then frame:StopMovingOrSizing(); frame.moving = false; SavePosition() end
end

local function OnGripDown(_, button)
    if button ~= "LeftButton" or S.Get("locked") or unlocked or InCombatLockdown() then return end
    SavePosition()
    frame.sizing = true; frame:StartSizing("BOTTOMRIGHT")
end

local function OnGripUp()
    if not frame.sizing then return end
    local width, height = frame:GetWidth(), frame:GetHeight()
    frame:StopMovingOrSizing(); frame.sizing = false
    S.Set("width", math.floor(width + ROUND)); S.Set("height", math.floor(height + ROUND))
    SavePosition(); Update()
end

local function OnSizeChanged()
    if frame.sizing then Update() end
end

local function OnHide()
    if frame.moving or frame.sizing then
        frame:StopMovingOrSizing(); frame.moving, frame.sizing = false, false
    end
end

local function OnWheel(_, delta)
    offset = math.max(0, offset - delta)
    Update()
end

local function SaveMoved(pos)
    S.Set("meterPos", pos)
end

local function NewButtons()
    local header = frame.header
    frame.settings = ns.Button(header, "...", SMALL_W, BUTTON_H, OpenSettings)
    frame.settings:SetPoint("RIGHT", BUTTON_RIGHT, 0)
    ns.Tooltip(frame.settings, "Damage Meter Settings")
    frame.reset = ns.Button(header, "R", SMALL_W, BUTTON_H, AskReset)
    frame.reset:SetPoint("RIGHT", frame.settings, "LEFT", -BUTTON_GAP, 0)
    ns.Tooltip(frame.reset, "Reset", TEXT_RESET_TIP)
    frame.session = ns.Button(header, "", SESSION_W, BUTTON_H, ToggleSession)
    frame.session:SetPoint("RIGHT", frame.reset, "LEFT", -BUTTON_GAP, 0)
    ns.Tooltip(frame.session, "Session", TEXT_SESSION_TIP)
    frame.modeButton = CreateFrame("Button", nil, header)
    frame.modeButton:SetPoint("TOPLEFT"); frame.modeButton:SetPoint("BOTTOMLEFT")
    frame.modeButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame.modeButton:SetScript("OnClick", OnModeClick)
    ns.Tooltip(frame.modeButton, "List", TEXT_MODE_TIP)
end

local function NewGrip()
    frame.grip = CreateFrame("Button", nil, frame)
    frame.grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    frame.grip:SetPoint("BOTTOMRIGHT", -GRIP_INSET, GRIP_INSET)
    frame.grip:SetFrameLevel(frame:GetFrameLevel() + GRIP_LEVEL)
    frame.grip:SetNormalTexture(C.GRIP_UP)
    frame.grip:SetHighlightTexture(C.GRIP_HIGHLIGHT)
    frame.grip:SetPushedTexture(C.GRIP_DOWN)
    ns.Tooltip(frame.grip, "Resize Damage Meter", "Drag to resize. Turn off Lock Window first; resizing is available outside combat.")
    frame.grip:SetScript("OnMouseDown", OnGripDown)
    frame.grip:SetScript("OnMouseUp", OnGripUp)
end

local function Build()
    frame = CreateFrame("Frame", "NaowhForeverDamageMeter", UIParent)
    frame:SetMovable(true); frame:SetClampedToScreen(true); frame:SetResizable(true)
    frame:SetResizeBounds(MIN_WIDTH, C.MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
    Look.New(frame)
    NewButtons()
    frame.header:EnableMouse(true); frame.header:RegisterForDrag("LeftButton")
    frame.header:SetScript("OnDragStart", OnDragStart)
    frame.header:SetScript("OnDragStop", OnDragStop)
    NewGrip()
    frame:SetScript("OnSizeChanged", OnSizeChanged)
    ns.AllowOffscreen(frame)
    frame:SetScript("OnHide", OnHide)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", OnWheel)
    frame.mover = UI.AttachMover(frame, TEXT_MOVER, SaveMoved, C.PAGE, CARD)
    frame:Hide(); Place()
end

local function ShownNow()
    local where = S.Get("visibility")
    if where == "group" then return IsInGroup() end
    if where == "instance" then return (IsInInstance()) end
    return true
end

-- The game's own meter is switched off while ours is up, and put back as it was after.
local function GameMeter(takeOver)
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end
    local account = ns.AccountSettings()
    if takeOver then
        if account[GAME_CVAR_SAVED] == nil and not InCombatLockdown() then
            local was = C_CVar.GetCVar(GAME_CVAR)
            if was and was ~= GAME_CVAR_OFF then
                account[GAME_CVAR_SAVED] = was
                C_CVar.SetCVar(GAME_CVAR, GAME_CVAR_OFF)
            end
        end
    elseif account[GAME_CVAR_SAVED] ~= nil and not InCombatLockdown() then
        C_CVar.SetCVar(GAME_CVAR, account[GAME_CVAR_SAVED])
        account[GAME_CVAR_SAVED] = nil
    end
end

function Update()
    pendingUpdate = false
    if not frame then return end
    if not DM.On() and not unlocked then frame:Hide(); return end
    local sample = unlocked or preview
    if not sample and not ShownNow() then frame:Hide(); return end
    if sample then
        Render(DM.SAMPLE, true)
    else
        Render(DM.Session(S.Get("mode"), S.Get("session")), DM.Available())
    end
    frame:Show()
end

local function RequestUpdate()
    if pendingUpdate or not DM.On() then return end
    pendingUpdate = true
    local generation = updateGeneration
    C_Timer.After(UPDATE_DELAY, function() if generation == updateGeneration then Update() end end)
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        preview = false
        if frame and (frame.sizing or frame.moving) then
            frame:StopMovingOrSizing(); frame.sizing, frame.moving = false, false
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        GameMeter(DM.On() and S.Get("hideGameMeter"))
    end
    RequestUpdate()
end

local function Listen()
    for _, event in ipairs(DATA_EVENTS) do events:RegisterEvent(event) end
    for _, event in ipairs(STATE_EVENTS) do events:RegisterEvent(event) end
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function Apply()
    events:UnregisterAllEvents()
    updateGeneration = updateGeneration + 1; pendingUpdate = false
    GameMeter(DM.On() and S.Get("hideGameMeter"))
    if not (DM.On() or unlocked) then
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() end
    Place()
    frame.mover:SetShown(unlocked == true)
    if DM.On() then Listen() end
    Update()
end

local function EndPreview(generation)
    if generation ~= previewGeneration then return end
    preview = false
    Update()
end

function ns.PreviewDamageMeter()
    if not DM.On() then ns.Print(TEXT_OFF) return end
    if InCombatLockdown() then ns.Print(TEXT_IN_COMBAT) return end
    previewGeneration = previewGeneration + 1
    local generation = previewGeneration
    preview = true
    Update()
    C_Timer.After(PREVIEW_SECONDS, function() EndPreview(generation) end)
end

local function OnSet(key)
    if key == "meterPos" then return end
    if key == "enabled" or key == "hideGameMeter" then
        previewGeneration = previewGeneration + 1
        preview = false
        Apply()
    else
        RequestUpdate()
    end
end

local function OnUnlock()
    unlocked = DM.On() == true
    Apply()
end

local function OnLock()
    unlocked = false
    if frame then Apply() end
end

events:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", OnUnlock)
hooksecurefunc(ns, "HideUnlockMode", OnLock)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

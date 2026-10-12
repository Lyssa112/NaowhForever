-- Meter.lua: the Damage Meter windows: drag, resize, scroll, their buttons and their updates.
local ns = _G.NaowhForever

local UI = ns.UI
local DM = ns.DamageMeter
local S = DM.Settings
local C, Look, Key, Menus, Breakdown = DM.C, DM.Look, DM.Key, DM.Menus, DM.Breakdown

local UPDATE_DELAY = 0.25
local PREVIEW_SECONDS = 10
local INSET, HEADER, ROUND = C.INSET, C.HEADER, C.ROUND
local MIN_WIDTH, MAX_WIDTH, MAX_HEIGHT = C.MIN_WIDTH, C.MAX_WIDTH, C.MAX_HEIGHT
local BUTTON_H, MORE_W, SESSION_W, BUTTON_GAP, BUTTON_RIGHT = 18, 22, 62, 4, -6
local TITLE_PAD = 8
local TIME_NEED = 2 * TITLE_PAD + C.TIME_WIDTH + SESSION_W + MORE_W + BUTTON_GAP - BUTTON_RIGHT
local GRIP_SIZE, GRIP_INSET, GRIP_LEVEL, GRIP_LOCKED_ALPHA = 20, 2, 20, 0.4
local HOME_X, HOME_Y = -24, 210
local FRAME_NAME = "NaowhForeverDamageMeter"
local CARD, CARD_MORE = C.PAGE .. ":meter", C.PAGE .. ":windows"
local GAME_CVAR, GAME_CVAR_OFF = "damageMeterEnabled", "0"
local GAME_CVAR_SAVED = "damageMeterGameWas"
local DATA_EVENTS = { "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED",
    "DAMAGE_METER_RESET" }
local STATE_EVENTS = { "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE" }

local TEXT_OFF = "Enable the Damage Meter first."
local TEXT_IN_COMBAT = "Preview is available outside combat."
local TEXT_RESET_DONE = "Damage meter data reset."
local TEXT_FIGHT = "Fight"
local TEXT_LIST_TIP = "Choose what the window lists."
local TEXT_SESSION_TIP = "The current fight, everything since the last reset, or a past fight."
local TEXT_MORE_TIP = "Report, reset, add or close a window, and settings."

local windows = {}
local pendingUpdate, unlocked, hovered
local preview = false
local updateGeneration, previewGeneration = 0, 0
local events = CreateFrame("Frame")
local Update

local function Get(w, base)
    return S.Get(Key(base, w.index))
end

local function Window(index)
    local w = windows[index]
    if not w then
        w = { index = index, offset = 0 }
        windows[index] = w
    end
    return w
end

local function Layout(w, session)
    local frame = w.frame
    local bh, gap, fontSize = S.Get("barHeight"), S.Get("barSpacing"), S.Get("fontSize")
    frame:SetResizeBounds(MIN_WIDTH, math.max(C.MIN_HEIGHT, HEADER + 2 * INSET + bh), MAX_WIDTH, MAX_HEIGHT)
    local mode = DM.Mode(Get(w, "mode"))
    local shown
    shown, w.offset = Look.Layout(frame, #session.combatSources, w.offset, bh, gap, fontSize, mode)
    frame.grip:SetShown(not unlocked)
    frame.grip:SetAlpha(S.Get("locked") and GRIP_LOCKED_ALPHA or 1)
    return shown, mode
end

-- seconds is how long the session has run, or nil; it is shown when the title bar has room for it.
local function Render(w, session, available, seconds)
    local frame = w.frame
    local shown, mode = Layout(w, session)
    Look.Paint(frame, session, w.offset, shown, mode, available)
    frame.title:SetText(mode.label)
    local titleWidth = frame.title:GetStringWidth()
    frame.modeButton:SetWidth(titleWidth + 2 * TITLE_PAD)
    local fits = seconds ~= nil and S.Get("showTime") and frame:GetWidth() >= titleWidth + TIME_NEED
    frame.time:SetText(fits and DM.Clock(seconds) or "")
    frame.time:SetShown(fits == true)
    ns.SetButtonText(frame.session, w.fight and TEXT_FIGHT or C.SESSION_LABELS[Get(w, "session")]
        or C.SESSION_LABELS.current)
end

local function Place(w)
    local pos = Get(w, "meterPos")
    local frame = w.frame
    frame:ClearAllPoints()
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", HOME_X, HOME_Y)
    end
end

local function SavePosition(w)
    local frame = w.frame
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x, y = frame:GetLeft() * scale, frame:GetTop() * scale - UIParent:GetHeight()
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
    S.Set(Key("meterPos", w.index), { point = "TOPLEFT", relPoint = "TOPLEFT", x = x, y = y })
end

local function OnDragStart(w)
    if not S.Get("locked") and not unlocked and not InCombatLockdown() then
        w.moving = true; w.frame:StartMoving()
    end
end

local function OnDragStop(w)
    if w.moving then w.frame:StopMovingOrSizing(); w.moving = false; SavePosition(w) end
end

local function OnGripDown(w, button)
    if button ~= "LeftButton" or S.Get("locked") or unlocked or InCombatLockdown() then return end
    SavePosition(w)
    w.sizing = true; w.frame:StartSizing("BOTTOMRIGHT")
end

local function OnGripUp(w)
    if not w.sizing then return end
    local width, height = w.frame:GetWidth(), w.frame:GetHeight()
    w.frame:StopMovingOrSizing(); w.sizing = false
    S.Set(Key("width", w.index), math.floor(width + ROUND)); S.Set(Key("height", w.index), math.floor(height + ROUND))
    SavePosition(w); Update()
end

local function OnHide(w)
    if w.moving or w.sizing then
        w.frame:StopMovingOrSizing(); w.moving, w.sizing = false, false
    end
end

local function OnWheel(w, delta)
    w.offset = math.max(0, w.offset - delta)
    Update()
end

-- The spells behind the hovered row; the panel says why when there are none.
local function ShowBreakdown(w, row)
    local mode = DM.Mode(Get(w, "mode"))
    if not S.Get("breakdown") or w.sample or row.source == nil or mode.spells == false then
        Breakdown.Hide()
        return
    end
    local data = DM.SourceSpells(mode.key, Get(w, "session"), w.fight, row.source)
    local x = w.frame:GetCenter()
    Breakdown.Show(row, row.source, data, x ~= nil and x < UIParent:GetWidth() / 2, InCombatLockdown())
end

local function OnRowEnter(w, row)
    hovered = { w = w, row = row }
    ShowBreakdown(w, row)
end

local function OnRowLeave()
    hovered = nil
    Breakdown.Hide()
end

local function NewButtons(w)
    local frame = w.frame
    local header = frame.header
    frame.more = ns.Button(header, "...", MORE_W, BUTTON_H, function() Menus.Window(w, frame.more) end)
    frame.more:SetPoint("RIGHT", BUTTON_RIGHT, 0)
    ns.Tooltip(frame.more, "Menu", TEXT_MORE_TIP)
    frame.session = ns.Button(header, "", SESSION_W, BUTTON_H, function() Menus.Session(w, frame.session) end)
    frame.session:SetPoint("RIGHT", frame.more, "LEFT", -BUTTON_GAP, 0)
    frame.time:SetPoint("RIGHT", frame.session, "LEFT", -BUTTON_GAP, 0)
    ns.Tooltip(frame.session, "Session", TEXT_SESSION_TIP)
    frame.modeButton = CreateFrame("Button", nil, header)
    frame.modeButton:SetPoint("TOPLEFT"); frame.modeButton:SetPoint("BOTTOMLEFT")
    frame.modeButton:SetScript("OnClick", function() Menus.List(w, frame.modeButton) end)
    ns.Tooltip(frame.modeButton, "List", TEXT_LIST_TIP)
end

local function NewGrip(w)
    local frame = w.frame
    frame.grip = CreateFrame("Button", nil, frame)
    frame.grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    frame.grip:SetPoint("BOTTOMRIGHT", -GRIP_INSET, GRIP_INSET)
    frame.grip:SetFrameLevel(frame:GetFrameLevel() + GRIP_LEVEL)
    frame.grip:SetNormalTexture(C.GRIP_UP)
    frame.grip:SetHighlightTexture(C.GRIP_HIGHLIGHT)
    frame.grip:SetPushedTexture(C.GRIP_DOWN)
    ns.Tooltip(frame.grip, "Resize Damage Meter", "Drag to resize. Turn off Lock Window first; resizing is available outside combat.")
    frame.grip:SetScript("OnMouseDown", function(_, button) OnGripDown(w, button) end)
    frame.grip:SetScript("OnMouseUp", function() OnGripUp(w) end)
end

-- The first window's mover points at the meter card, the others' at the card of the extra windows.
local function AttachMover(frame, index, onSave)
    if index == 1 then
        return UI.AttachMover(frame, DM.WindowName(index), onSave, C.PAGE, CARD)
    end
    return UI.AttachMover(frame, DM.WindowName(index), onSave, C.PAGE, CARD_MORE)
end

local function Build(w)
    local index = w.index
    local frame = CreateFrame("Frame", index == 1 and FRAME_NAME or FRAME_NAME .. index, UIParent)
    w.frame = frame
    frame:SetMovable(true); frame:SetClampedToScreen(true); frame:SetResizable(true)
    frame:SetResizeBounds(MIN_WIDTH, C.MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
    Look.New(frame, index)
    NewButtons(w)
    frame.header:EnableMouse(true); frame.header:RegisterForDrag("LeftButton")
    frame.header:SetScript("OnDragStart", function() OnDragStart(w) end)
    frame.header:SetScript("OnDragStop", function() OnDragStop(w) end)
    NewGrip(w)
    frame:SetScript("OnSizeChanged", function() if w.sizing then Update() end end)
    ns.AllowOffscreen(frame)
    frame:SetScript("OnHide", function() OnHide(w) end)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta) OnWheel(w, delta) end)
    frame.onWheel = function(delta) OnWheel(w, delta) end
    frame.onRowEnter = function(row) OnRowEnter(w, row) end
    frame.onRowLeave = OnRowLeave
    frame.mover = AttachMover(frame, index, function(pos) S.Set(Key("meterPos", index), pos) end)
    frame:Hide(); Place(w)
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

local function HideAll()
    for _, w in pairs(windows) do
        if w.frame then w.frame:Hide() end
    end
    OnRowLeave()
end

local function Draw(w, sample)
    w.sample = sample
    if sample then
        Render(w, DM.SAMPLE, true, DM.SAMPLE.durationSeconds)
    else
        local session, fight = Get(w, "session"), w.fight
        Render(w, DM.Session(Get(w, "mode"), session, fight), DM.Available(), DM.Duration(session, fight))
    end
    w.frame:Show()
end

function Update()
    pendingUpdate = false
    if not DM.On() and not unlocked then HideAll() return end
    local sample = unlocked or preview
    local visible = sample or ShownNow()
    for index = 1, DM.MAX_WINDOWS do
        local w = windows[index]
        if w and w.frame then
            if visible and DM.WindowOn(index) then Draw(w, sample) else w.frame:Hide() end
        end
    end
    if hovered and hovered.w.frame:IsShown() then ShowBreakdown(hovered.w, hovered.row) else OnRowLeave() end
end

local function RequestUpdate()
    if pendingUpdate or not DM.On() then return end
    pendingUpdate = true
    local generation = updateGeneration
    C_Timer.After(UPDATE_DELAY, function() if generation == updateGeneration then Update() end end)
end

DM.Refresh = RequestUpdate

local function ForgetFights()
    for _, w in pairs(windows) do w.fight, w.offset = nil, 0 end
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        preview = false
        for _, w in pairs(windows) do
            if w.frame and (w.sizing or w.moving) then
                w.frame:StopMovingOrSizing(); w.sizing, w.moving = false, false
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        GameMeter(DM.On() and S.Get("hideGameMeter"))
    elseif event == "DAMAGE_METER_RESET" then
        ForgetFights()
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
    if not (DM.On() or unlocked) then HideAll() return end
    for index = 1, DM.MAX_WINDOWS do
        if DM.WindowOn(index) then
            local w = Window(index)
            if not w.frame then Build(w) end
            Place(w)
            w.frame.mover:SetShown(unlocked == true)
        end
    end
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

function NaowhForever_ResetDamageMeter()
    if not DM.On() then ns.Print(TEXT_OFF) return end
    DM.Reset()
    ns.Print(TEXT_RESET_DONE)
end

local function OnSet(key)
    if key:find("^meterPos") then return end
    if key == "enabled" or key == "hideGameMeter" or key:find("^window%d$") then
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
    if windows[1] and windows[1].frame then Apply() end
end

events:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", OnUnlock)
hooksecurefunc(ns, "HideUnlockMode", OnLock)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

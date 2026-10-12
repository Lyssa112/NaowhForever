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
local TITLE_X = C.TITLE_X
local TITLE_JOIN = " - "
-- What the buttons take of the title bar's right end, from the edge to the session button's left.
local BAR_BUTTONS = BUTTON_GAP + SESSION_W + BUTTON_GAP + MORE_W - BUTTON_RIGHT
local GRIP_SIZE, GRIP_INSET, GRIP_LEVEL, GRIP_LOCKED_ALPHA = 20, 2, 20, 0.4
local HOME_X, HOME_Y = -24, 210
local FRAME_NAME = "NaowhForeverDamageMeter"
local CARD, CARD_SECOND, CARD_THIRD = C.PAGE .. ":window", C.PAGE .. ":window2", C.PAGE .. ":window3"
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
local TEXT_LOWER_TIP = "Choose the list under the first, or none."
local TEXT_SESSION_TIP = "The current fight, everything since the last reset, or a past fight."
local TEXT_MORE_TIP = "Report, reset, add or close a window, and settings."

local windows = {}
local pendingUpdate, unlocked, hovered
local lastCombatEnd, override
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
        w = { index = index, offset = 0, offset2 = 0 }
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

-- Raid Mode: the session as it would be with only you in it, still ranked as you are.
local function OwnOnly(session)
    local rank = DM.Rank(session)
    local sources = {}
    if rank then sources[1] = session.combatSources[rank] end
    return { combatSources = sources, maxAmount = session.maxAmount, totalAmount = session.totalAmount, rank = rank }
end

-- The title's words: the list's name, the fight's, or both when there is a fight's name to give.
local function TitleText(mode, fightName)
    local says = S.Get("titleText")
    if says == "list" or not fightName then return mode.label end
    if says == "fight" then return fightName end
    return mode.label .. TITLE_JOIN .. fightName
end

-- Puts the title and the fight time in the bar where the settings say. The buttons hold its right end and
-- the two share the rest: the time goes when both do not fit, and a long title is cut to what is there.
local function PaintTitleBar(frame, mode, seconds, fightName)
    local title, time, header = frame.title, frame.time, frame.header
    title:SetWidth(0)
    title:SetText(TitleText(mode, fightName))
    local textWidth, timeWidth = math.ceil(title:GetStringWidth()), Look.TimeWidth()
    local low, high = TITLE_X, frame:GetWidth() - BAR_BUTTONS
    local shown = seconds ~= nil and S.Get("showTime") == true and textWidth + BUTTON_GAP + timeWidth <= high - low
    local place = S.Get("timePlace")
    local first, last = low, high
    if shown and place == "left" then first = low + timeWidth + BUTTON_GAP end
    if shown and place == "buttons" then last = high - timeWidth - BUTTON_GAP end
    local drawn = math.min(textWidth, last - first)
    local group = drawn
    if shown and place == "title" then group = drawn + BUTTON_GAP + timeWidth end
    local x, align = first, S.Get("titleAlign")
    if align == "center" then
        x = first + math.floor((last - first - group) / 2)
    elseif align == "right" then
        x = last - group
    end
    title:ClearAllPoints()
    title:SetPoint("LEFT", header, "LEFT", x, 0)
    title:SetWidth(drawn)
    time:ClearAllPoints()
    if place == "title" then
        time:SetPoint("LEFT", title, "RIGHT", BUTTON_GAP, 0); time:SetJustifyH("LEFT")
    elseif place == "left" then
        time:SetPoint("LEFT", header, "LEFT", low, 0); time:SetJustifyH("LEFT")
    else
        time:SetPoint("RIGHT", frame.session, "LEFT", -BUTTON_GAP, 0); time:SetJustifyH("RIGHT")
    end
    time:SetText(shown and DM.Clock(seconds) or "")
    time:SetShown(shown)
    local left = math.max(0, x - TITLE_X)
    frame.modeButton:ClearAllPoints()
    frame.modeButton:SetPoint("TOPLEFT", header, "TOPLEFT", left, 0)
    frame.modeButton:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", left, 0)
    frame.modeButton:SetWidth(drawn + 2 * TITLE_X)
end

-- seconds is how long the session has run, or nil; fightName is what the game calls the fight, or nil.
local function Render(w, session, available, seconds, lowerSession, fightName)
    local frame = w.frame
    local raid = S.Get("raidMode")
    local view = raid and OwnOnly(session) or session
    local lowerKey = Get(w, "lower")
    frame.lowerOn = lowerKey ~= ""
    local shown, mode = Layout(w, view)
    Look.Paint(frame, view, w.offset, shown, mode, available)
    if frame.lowerOn then
        local lowerMode = DM.Mode(lowerKey)
        local lowerView = raid and OwnOnly(lowerSession) or lowerSession
        local lowerShown
        lowerShown, w.offset2 = Look.LayoutLower(frame, #lowerView.combatSources, w.offset2, lowerMode)
        Look.PaintLower(frame, lowerView, w.offset2, lowerShown, lowerMode, available)
    else
        Look.HideLower(frame)
    end
    frame.lowerButton:SetShown(frame.lowerOn)
    local summary = S.Get("showSummary") == true
    frame.summary:SetShown(summary)
    if summary then
        Look.PaintSummary(frame, session, mode, DM.SessionName(Get(w, "session"), w.fight), seconds)
    end
    PaintTitleBar(frame, mode, seconds, fightName)
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
    if S.Get("locked") or unlocked then return end
    w.frame.moving = true; w.frame:StartMoving()
end

local function OnDragStop(w)
    local frame = w.frame
    if frame.moving then frame:StopMovingOrSizing(); frame.moving = false; SavePosition(w) end
end

local function OnGripDown(w, button)
    if button ~= "LeftButton" or S.Get("locked") or unlocked then return end
    SavePosition(w)
    w.frame.sizing = true; w.frame:StartSizing("BOTTOMRIGHT")
end

local function OnGripUp(w)
    local frame = w.frame
    if not frame.sizing then return end
    local width, height = frame:GetWidth(), frame:GetHeight()
    frame:StopMovingOrSizing(); frame.sizing = false
    S.Set(Key("width", w.index), math.floor(width + ROUND)); S.Set(Key("height", w.index), math.floor(height + ROUND))
    SavePosition(w); Update()
end

local function OnHide(w)
    local frame = w.frame
    if frame.moving or frame.sizing then
        frame:StopMovingOrSizing(); frame.moving, frame.sizing = false, false
    end
end

-- The wheel scrolls the pane under it: the second list's rows, or the first's.
local function OnWheel(w, delta, row)
    if row and row.pane == 2 then
        w.offset2 = math.max(0, w.offset2 - delta)
    else
        w.offset = math.max(0, w.offset - delta)
    end
    Update()
end

-- The spells behind the hovered row; the panel says why when there are none.
local function ShowBreakdown(w, row)
    local mode = DM.Mode(row.modeKey or Get(w, "mode"))
    if not S.Get("breakdown") or w.sample or row.source == nil or mode.spells == false then
        Breakdown.Hide()
        return
    end
    local data = DM.SourceSpells(mode.key, Get(w, "session"), w.fight, row.source)
    local inCombat = InCombatLockdown()
    local targets, seconds
    if mode.targets and not inCombat then
        targets = DM.Targets(Get(w, "session"), w.fight, row.source.name)
        seconds = DM.Duration(Get(w, "session"), w.fight)
    end
    local x = w.frame:GetCenter()
    Breakdown.Show(row, row.source, data, x ~= nil and x < UIParent:GetWidth() / 2, inCombat, targets, seconds)
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
    ns.Tooltip(frame.session, "Session", TEXT_SESSION_TIP)
    frame.modeButton = CreateFrame("Button", nil, header)
    frame.modeButton:SetScript("OnClick", function() Menus.List(w, frame.modeButton) end)
    ns.Tooltip(frame.modeButton, "List", TEXT_LIST_TIP)
    frame.lowerButton = CreateFrame("Button", nil, frame)
    frame.lowerButton:SetPoint("TOPLEFT", frame.lowerBar, "TOPLEFT")
    frame.lowerButton:SetPoint("BOTTOMRIGHT", frame.lowerBar, "BOTTOMRIGHT")
    frame.lowerButton:SetScript("OnClick", function() Menus.List(w, frame.lowerButton, 2) end)
    frame.lowerButton:Hide()
    ns.Tooltip(frame.lowerButton, "Second List", TEXT_LOWER_TIP)
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
    ns.Tooltip(frame.grip, "Resize Damage Meter", "Drag to resize. Turn off Lock Window first.")
    frame.grip:SetScript("OnMouseDown", function(_, button) OnGripDown(w, button) end)
    frame.grip:SetScript("OnMouseUp", function() OnGripUp(w) end)
end

-- A window's mover points at the card with its size: the Window card, or the card of the second or third.
local function AttachMover(frame, index, onSave)
    local name = DM.WindowName(index)
    if index == 1 then return UI.AttachMover(frame, name, onSave, C.PAGE, CARD) end
    if index == 2 then return UI.AttachMover(frame, name, onSave, C.PAGE, CARD_SECOND) end
    return UI.AttachMover(frame, name, onSave, C.PAGE, CARD_THIRD)
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
    frame:SetScript("OnSizeChanged", function() if frame.sizing then Update() end end)
    ns.AllowOffscreen(frame)
    frame:SetScript("OnHide", function() OnHide(w) end)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta) OnWheel(w, delta) end)
    frame.onWheel = function(delta, row) OnWheel(w, delta, row) end
    frame.onRowEnter = function(row) OnRowEnter(w, row) end
    frame.onRowLeave = OnRowLeave
    frame.mover = AttachMover(frame, index, function(pos) S.Set(Key("meterPos", index), pos) end)
    frame:Hide(); Place(w)
end

-- Whether the visibility setting wants the windows up: a key press can override it until combat starts.
local function ShownNow()
    if override ~= nil then return override end
    local where = S.Get("visibility")
    if where == "group" then return IsInGroup() end
    if where == "instance" then return (IsInInstance()) end
    if where == "combat" then
        if InCombatLockdown() then return true end
        return lastCombatEnd ~= nil and GetTime() - lastCombatEnd < S.Get("hideDelay")
    end
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

local function Draw(w, asSample)
    w.sample = asSample
    local lowerKey = Get(w, "lower")
    if asSample then
        local sample = DM.Sample()
        Render(w, sample, true, sample.durationSeconds, lowerKey ~= "" and sample or nil, sample.fightName)
    else
        local session, fight = Get(w, "session"), w.fight
        local lower = lowerKey ~= "" and DM.Session(lowerKey, session, fight) or nil
        local name = S.Get("titleText") ~= "list" and DM.FightName(session, fight) or nil
        Render(w, DM.Session(Get(w, "mode"), session, fight), DM.Available(), DM.Duration(session, fight), lower,
            name)
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
    for _, w in pairs(windows) do w.fight, w.offset, w.offset2 = nil, 0, 0 end
end

local function OnEvent(_, event, ...)
    if event == "PLAYER_REGEN_DISABLED" or event:find("^DAMAGE_METER") then DM.ClearTargets() end
    if event == "PLAYER_REGEN_DISABLED" then
        preview, override = false, nil
        DM.History.OnCombatStart()
    elseif event == "ENCOUNTER_END" then
        DM.History.OnEncounterEnd((select(2, ...)))
    elseif event == "PLAYER_REGEN_ENABLED" then
        DM.History.Arm()
        GameMeter(DM.On() and S.Get("hideGameMeter"))
        DM.ScanRoster()
        lastCombatEnd = GetTime()
        if S.Get("visibility") == "combat" then
            C_Timer.After(S.Get("hideDelay") + UPDATE_DELAY, RequestUpdate)
        end
    elseif event == "DAMAGE_METER_RESET" then
        ForgetFights()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        DM.ScanRoster()
    end
    RequestUpdate()
end

local function Listen()
    for _, event in ipairs(DATA_EVENTS) do events:RegisterEvent(event) end
    for _, event in ipairs(STATE_EVENTS) do events:RegisterEvent(event) end
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    pcall(events.RegisterEvent, events, "ENCOUNTER_END")
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
    if DM.On() then Listen(); DM.ScanRoster() end
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

function NaowhForever_ToggleDamageMeter()
    if not DM.On() then ns.Print(TEXT_OFF) return end
    local first = windows[1]
    override = not (first and first.frame and first.frame:IsShown())
    Update()
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

-- Settings from before: a background the page no longer lists is none, and a path typed when Image had no
-- choice for it, or behind a switch, is your own picture.
local function Tidy()
    local picked = S.Get("backgroundImage")
    if C.HIDDEN_BACKGROUNDS[picked] then S.Set("backgroundImage", ""); picked = "" end
    if not S.Raw then return end
    local switch = S.Raw("customImage")
    if switch == true or (switch == nil and picked == "" and S.Get("backgroundPath") ~= "") then
        S.Set("backgroundImage", C.OWN_PICTURE)
        S.Set("customImage", false)
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    Tidy()
    Apply()
end)

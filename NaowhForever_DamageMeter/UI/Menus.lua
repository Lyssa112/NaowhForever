-- Menus.lua: a window's menus: its list, its session, and the rest. They keep no state of their own; w is the
-- window (index, offset, fight) and every choice goes to the settings or to the window's own fields.
local ns = _G.NaowhForever

local DM = ns.DamageMeter
local S = DM.Settings
local C, Key = DM.C, DM.Key

local TEXT_LIST, TEXT_LOWER, TEXT_NONE = "List", "Second List", "None"
local TEXT_SESSION = "Session"
local TEXT_FIGHTS, TEXT_NO_FIGHTS = "Past Fights", "No Past Fights Yet"
local TEXT_REPORT, TEXT_RESET, TEXT_RESET_ASK = "Report To", "Reset Data", "Reset the damage meter data?"
local TEXT_ADD, TEXT_CLOSE, TEXT_LOCK, TEXT_SETTINGS = "Add Window", "Close Window", "Lock Window", "Settings"
local TEXT_RAID, TEXT_BAR_COLOR = "Raid Mode", "Bar Color"
local TEXT_HISTORY, TEXT_SHOT = "Fight History", "Take Screenshot"
local SHOT_DELAY = 0.3

local Menus = {}
DM.Menus = Menus

local function Chosen(w, base, value)
    return function() return w.fight == nil and S.Get(Key(base, w.index)) == value end
end

-- The first list, or with pane 2 the list under it, which can also be none.
function Menus.List(w, owner, pane)
    local lower = pane == 2
    local setting = Key(lower and "lower" or "mode", w.index)
    local function Choose(key)
        if lower then w.offset2 = 0 else w.offset = 0 end
        S.Set(setting, key)
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(lower and TEXT_LOWER or TEXT_LIST)
        if lower then
            root:CreateRadio(TEXT_NONE, function() return S.Get(setting) == "" end, function() Choose("") end)
        end
        for _, key in ipairs(C.MODE_ORDER) do
            root:CreateRadio(C.MODE_LABELS[key], function() return S.Get(setting) == key end,
                function() Choose(key) end)
        end
    end)
end

function Menus.Session(w, owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(TEXT_SESSION)
        for _, key in ipairs(C.SESSION_ORDER) do
            root:CreateRadio(C.SESSION_LABELS[key], Chosen(w, "session", key),
                function() w.fight, w.offset = nil, 0; S.Set(Key("session", w.index), key); DM.Refresh() end)
        end
        local fights = DM.Fights()
        root:CreateDivider()
        root:CreateTitle(#fights > 0 and TEXT_FIGHTS or TEXT_NO_FIGHTS)
        for _, fight in ipairs(fights) do
            root:CreateRadio(DM.FightLabel(fight), function() return w.fight == fight.id end,
                function() w.fight, w.offset = fight.id, 0; DM.Refresh() end)
        end
    end)
end

-- A little later, so the menu has closed and is not in the picture.
local function TakeScreenshot()
    C_Timer.After(SHOT_DELAY, function()
        if Screenshot then pcall(Screenshot) end
    end)
end

local function FirstClosed()
    for i = 2, DM.MAX_WINDOWS do
        if not DM.WindowOn(i) then return i end
    end
end

local function Report(w, channel)
    DM.Report(channel, S.Get(Key("mode", w.index)), S.Get(Key("session", w.index)), w.fight)
end

function Menus.Window(w, owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(DM.WindowName(w.index))
        local report = root:CreateButton(TEXT_REPORT)
        for _, channel in ipairs(DM.Channels()) do
            report:CreateButton(channel.label, function() Report(w, channel.key) end)
        end
        root:CreateButton(TEXT_HISTORY, function() DM.HistoryWindow.Toggle() end)
        root:CreateButton(TEXT_SHOT, TakeScreenshot)
        root:CreateButton(TEXT_RESET, function() ns.Confirm(TEXT_RESET_ASK, DM.Reset) end)
        root:CreateDivider()
        local free = FirstClosed()
        if free then root:CreateButton(TEXT_ADD, function() S.Set(Key("window", free), true) end) end
        if w.index > 1 then root:CreateButton(TEXT_CLOSE, function() S.Set(Key("window", w.index), false) end) end
        local lower = root:CreateButton(TEXT_LOWER)
        lower:CreateRadio(TEXT_NONE, function() return S.Get(Key("lower", w.index)) == "" end,
            function() w.offset2 = 0; S.Set(Key("lower", w.index), "") end)
        for _, key in ipairs(C.MODE_ORDER) do
            lower:CreateRadio(C.MODE_LABELS[key], function() return S.Get(Key("lower", w.index)) == key end,
                function() w.offset2 = 0; S.Set(Key("lower", w.index), key) end)
        end
        local bars = root:CreateButton(TEXT_BAR_COLOR)
        for _, key in ipairs(C.BAR_COLORS_ORDER) do
            bars:CreateRadio(C.BAR_COLORS[key], function() return S.Get("barColor") == key end,
                function() S.Set("barColor", key) end)
        end
        root:CreateCheckbox(TEXT_RAID, function() return S.Get("raidMode") == true end,
            function() S.Set("raidMode", not S.Get("raidMode")) end)
        root:CreateCheckbox(TEXT_LOCK, function() return S.Get("locked") == true end,
            function() S.Set("locked", not S.Get("locked")) end)
        root:CreateButton(TEXT_SETTINGS, function() ns.OpenOptionsWindow(DM.TITLE) end)
    end)
end

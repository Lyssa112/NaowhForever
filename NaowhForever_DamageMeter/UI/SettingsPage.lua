-- SettingsPage.lua: the Damage Meter's settings page, declared as cards.
local ns = _G.NaowhForever

local DM = ns.DamageMeter
local S = DM.Settings
local C, Key = DM.C, DM.Key

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end
local Group = Settings.Group

local OFF = "Turn on the Damage Meter"
local OFF_WINDOW = "Turn this window on first"
local Style = ns.Shared.Style
local WIDTH_RANGE, HEIGHT_RANGE = { C.MIN_WIDTH, C.MAX_WIDTH, 1 }, { C.MIN_HEIGHT, C.MAX_HEIGHT, 1 }
local BAR_RANGE, SPACING_RANGE = { C.MIN_BAR, C.MAX_BAR, 1 }, { 0, C.MAX_SPACING, 1 }
local TEXT_RANGE = { C.MIN_FONT, C.MAX_FONT, 1 }
local BACKGROUND_RANGE, BAR_ALPHA_RANGE = Style.ALPHA_RANGE, { 10, 100, Style.OPACITY_STEP }
local TO_FRACTION = Style.PERCENT_SCALE
local REPORT_RANGE = { 1, C.REPORT_MAX, 1 }
local ORDER_METER, ORDER_MORE = 10, 20
local MORE_NAMES = { [2] = "Second Window", [3] = "Third Window" }

local MODE = { C.MODE_LABELS, C.MODE_ORDER }
local SESSION = { C.SESSION_LABELS, C.SESSION_ORDER }
local SHOW = { { always = "Always", instance = "In Instances", group = "In a Group" }, { "always", "instance", "group" } }
local BAR_COLOR = { { class = "Class Colors", accent = "Theme Accent" }, { "class", "accent" } }

local function Enabled() return DM.On() and true or false end

local function Headline()
    if not DM.On() then return "Damage Meter is off" end
    return DM.Mode(S.Get("mode")).label
end

local function Detail()
    local session = (C.SESSION_LABELS[S.Get("session")] or C.SESSION_LABELS.current):lower()
    return ("The %s session. Unlock its window to drag and resize it, or place it in the HUD Editor."):format(session)
end

local function Summary(store)
    return ("%s, %d by %d"):format(DM.Mode(store.Get("mode")).label, store.Get("width"), store.Get("height"))
end

-- What the second and third windows show, or Off.
local function MoreSummary(store)
    local parts = {}
    for index = 2, DM.MAX_WINDOWS do
        local on = store.Get(Key("window", index))
        parts[#parts + 1] = (index == 2 and "Second: " or "Third: ")
            .. (on and DM.Mode(store.Get(Key("mode", index))).label or "Off")
    end
    return table.concat(parts, ", ")
end

-- The rows of the second or third window: its own list, session and size.
local function WindowRows(index)
    local title = MORE_NAMES[index]
    local function On() return DM.On() and S.Get(Key("window", index)) == true end
    return {
        Group(title),
        { key = Key("window", index), label = "Show " .. title, toggle = true, needs = Enabled, why = OFF },
        { key = Key("mode", index), label = title .. " Shows", choice = MODE, needs = On, why = OFF_WINDOW },
        { key = Key("session", index), label = title .. " Session", choice = SESSION, needs = On, why = OFF_WINDOW },
        { key = Key("width", index), label = title .. " Width", slider = WIDTH_RANGE, needs = On, why = OFF_WINDOW },
        { key = Key("height", index), label = title .. " Height", slider = HEIGHT_RANGE, needs = On, why = OFF_WINDOW },
    }
end

local function MoreRows()
    local rows = {}
    for index = 2, DM.MAX_WINDOWS do
        for _, row in ipairs(WindowRows(index)) do rows[#rows + 1] = row end
    end
    return rows
end

local page = Settings.Page(C.PAGE, S)

page:Window({
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "meter", name = "Meter", order = ORDER_METER,
    help = "Damage, healing and more for your group, from the game's own meter data, in your theme.",
    summary = Summary,
    rows = {
        Group("List"),
        { key = "mode", label = "Show", choice = MODE, needs = Enabled, why = OFF,
          help = "Click the title in the window to choose a list." },
        { key = "session", label = "Session", choice = SESSION, needs = Enabled, why = OFF,
          help = "The current fight, or everything since the last reset. Past fights are in the window's "
              .. "Session button." },
        { key = "visibility", label = "Where", choice = SHOW, needs = Enabled, why = OFF },
        Group("Window"),
        { key = "width", label = "Width", slider = WIDTH_RANGE, needs = Enabled, why = OFF },
        { key = "height", label = "Window Height", slider = HEIGHT_RANGE, needs = Enabled, why = OFF },
        { key = "locked", label = "Lock Window", toggle = true, needs = Enabled, why = OFF,
          help = "Off: drag the title bar or resize with the corner, outside combat." },
        { key = "backgroundAlpha", label = "Background Opacity", slider = BACKGROUND_RANGE, unit = "%",
          scale = TO_FRACTION, needs = Enabled, why = OFF },
        { key = "hideGameMeter", label = "Replace the Game's Meter", toggle = true, needs = Enabled, why = OFF,
          help = "Turns the game's own damage meter off while this one is on." },
        Group("Rows"),
        { key = "barHeight", label = "Row Height", slider = BAR_RANGE, needs = Enabled, why = OFF },
        { key = "barSpacing", label = "Row Spacing", slider = SPACING_RANGE, needs = Enabled, why = OFF },
        { key = "showTotal", label = "Show Total", toggle = true, needs = Enabled, why = OFF },
        { key = "showRate", label = "Show Per Second", toggle = true, needs = Enabled, why = OFF,
          help = "Damage, healing and absorbs only." },
        { key = "showIcons", label = "Spec Icons", toggle = true, needs = Enabled, why = OFF },
        { key = "showRanks", label = "Rank Numbers", toggle = true, needs = Enabled, why = OFF },
        { key = "highlightPlayer", label = "Highlight Your Row", toggle = true, needs = Enabled, why = OFF },
        Settings.Look("", { text = true, size = TEXT_RANGE, bar = "Naowh Gradient", needs = Enabled, why = OFF }),
        { key = "barAlpha", label = "Bar Opacity", slider = BAR_ALPHA_RANGE, unit = "%", scale = TO_FRACTION,
          needs = Enabled, why = OFF },
        Group("Hover and Report"),
        { key = "breakdown", label = "Spell Breakdown on Hover", toggle = true, needs = Enabled, why = OFF,
          help = "Hover a row to see its spells. In combat only your own row and rows the game lets through "
              .. "show spells." },
        { key = "reportLines", label = "Report Lines", slider = REPORT_RANGE, needs = Enabled, why = OFF,
          help = "How many rows Report To sends, out of combat only. Reset has a key binding under Naowh Forever." },
        Group("Colors"),
        { key = "barColor", label = "Bar Color", choice = BAR_COLOR, needs = Enabled, why = OFF,
          help = "Class Colors: each player's class. Theme Accent: every bar in your theme's Accent." },
        { label = "Show It on Screen", buttonText = "Preview", needs = Enabled, why = OFF,
          button = function() ns.PreviewDamageMeter() end,
          help = "Shows the meter with sample bars where it sits on your screen, for ten seconds. Out of "
              .. "combat only." },
    },
})

page:Card({
    id = "windows", name = "More Windows", order = ORDER_MORE,
    help = "A second and a third window, each with its own list, session and size.",
    summary = MoreSummary,
    rows = MoreRows(),
})

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
local OFF_CUSTOM = "Set Bar Color to Custom Color"
local OFF_HIGHLIGHT = "Turn on Highlight Your Row"
local OFF_ABBREVIATING = "Number Format is Game Default or Full Numbers"
local Style = ns.Shared.Style
local WIDTH_RANGE, HEIGHT_RANGE = { C.MIN_WIDTH, C.MAX_WIDTH, 1 }, { C.MIN_HEIGHT, C.MAX_HEIGHT, 1 }
local BAR_RANGE, SPACING_RANGE = { C.MIN_BAR, C.MAX_BAR, 1 }, { 0, C.MAX_SPACING, 1 }
local TEXT_RANGE = { C.MIN_FONT, C.MAX_FONT, 1 }
local BACKGROUND_RANGE, BAR_ALPHA_RANGE = Style.ALPHA_RANGE, { 10, 100, Style.OPACITY_STEP }
local TO_FRACTION = Style.PERCENT_SCALE
local REPORT_RANGE = { 1, C.REPORT_MAX, 1 }
local ORDER_METER, ORDER_COLORS, ORDER_MORE = 10, 15, 20
local MORE_NAMES = { [2] = "Second Window", [3] = "Third Window" }

local MODE = { C.MODE_LABELS, C.MODE_ORDER }
local SESSION = { C.SESSION_LABELS, C.SESSION_ORDER }
local SHOW = { { always = "Always", instance = "In Instances", group = "In a Group" }, { "always", "instance", "group" } }
local BAR_COLOR = { { class = "Class Colors", accent = "Theme Accent", custom = "Custom Color" },
    { "class", "accent", "custom" } }
local ICON_STYLE = { { spec = "Spec Icon", class = "Class Icon" }, { "spec", "class" } }
local NUMBER_UNITS = { C.NUMBER_UNITS, C.NUMBER_UNITS_ORDER }
local DECIMALS_RANGE = { 0, C.NUMBER_DECIMALS_MAX, 1 }

local function Enabled() return DM.On() and true or false end
local function CustomBars() return DM.On() and S.Get("barColor") == "custom" end
local function Highlighting() return DM.On() and S.Get("highlightPlayer") == true end
local function Abbreviating()
    local units = S.Get("numberUnits")
    return DM.On() and (units == "latin" or units == "asian")
end

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

-- A color picker shows the color in use: the theme's until one is picked.
local function PickedGet(key)
    return function()
        local c = DM.Look.Color(key)
        return c.r, c.g, c.b, 1
    end
end

local function PickedSet(key)
    return function(r, g, b) S.Set(key, { r = r, g = g, b = b }) end
end

local COLOR_NEEDS = { barCustomColor = CustomBars, edgeColor = Highlighting }
local COLOR_WHY = { barCustomColor = OFF_CUSTOM, edgeColor = OFF_HIGHLIGHT }
local COLOR_HELP = {
    barCustomColor = "The bars' color when Bar Color is Custom Color.",
    edgeColor = "The strip on the left of your own row.",
    trackColor = "What shows behind a bar.",
}

local function ColorsSummary(store)
    local picked = 0
    for _, entry in ipairs(C.COLORS) do
        if type(store.Get(entry.key)) == "table" then picked = picked + 1 end
    end
    return picked == 0 and "Theme" or picked .. " picked"
end

local function ColorRows()
    local rows = {
        Group("Bars"),
        { key = "barColor", label = "Bar Color", choice = BAR_COLOR, needs = Enabled, why = OFF,
          help = "Class Colors: each player's class. Theme Accent: every bar in your theme's Accent. Custom "
              .. "Color: every bar in the one you pick." },
    }
    local group = "Bars"
    for _, entry in ipairs(C.COLORS) do
        if entry.group ~= group then
            group = entry.group
            rows[#rows + 1] = Group(group)
        end
        rows[#rows + 1] = { key = entry.key, label = entry.label, colour = true, get = PickedGet(entry.key),
            set = PickedSet(entry.key), needs = COLOR_NEEDS[entry.key] or Enabled,
            why = COLOR_WHY[entry.key] or OFF, help = COLOR_HELP[entry.key] }
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
          help = "Off: drag the title bar to move it and the corner to resize it, in combat too." },
        { key = "showTime", label = "Show Fight Time", toggle = true, needs = Enabled, why = OFF,
          help = "How long the shown session has run, in the title bar when there is room." },
        { key = "showBorder", label = "Border", toggle = true, needs = Enabled, why = OFF },
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
        { key = "showColumnHeaders", label = "Column Titles", toggle = true, needs = Enabled, why = OFF,
          help = "A line of titles above the rows: Name and what each column shows." },
        { key = "numberUnits", label = "Number Format", choice = NUMBER_UNITS, needs = Enabled, why = OFF,
          help = "How big numbers are written. Ten-thousands groups by ten-thousands and hundred-millions." },
        { key = "numberDecimals", label = "Decimals", slider = DECIMALS_RANGE, needs = Abbreviating,
          why = OFF_ABBREVIATING },
        { key = "showIcons", label = "Icons", toggle = true, needs = Enabled, why = OFF },
        { key = "iconStyle", label = "Icon Style", choice = ICON_STYLE, needs = Enabled, why = OFF },
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
        Group("Preview"),
        { label = "Show It on Screen", buttonText = "Preview", needs = Enabled, why = OFF,
          button = function() ns.PreviewDamageMeter() end,
          help = "Shows the meter with sample bars where it sits on your screen, for ten seconds. Out of "
              .. "combat only." },
    },
})

page:Card({
    id = "colors", name = "Colors", order = ORDER_COLORS,
    help = "A color for each part of the window. Until you pick one, a part follows your theme.",
    summary = ColorsSummary,
    rows = ColorRows(),
})

page:Card({
    id = "windows", name = "More Windows", order = ORDER_MORE,
    help = "A second and a third window, each with its own list, session and size.",
    summary = MoreSummary,
    rows = MoreRows(),
})

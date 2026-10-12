-- SettingsPage.lua: the Damage Meter's settings page, declared as cards.
local ns = _G.NaowhForever

local DM = ns.DamageMeter
local S = DM.Settings
local C = DM.C

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end
local Group = Settings.Group

local OFF = "Turn on the Damage Meter"
local Style = ns.Shared.Style
local WIDTH_RANGE, HEIGHT_RANGE = { C.MIN_WIDTH, C.MAX_WIDTH, 1 }, { C.MIN_HEIGHT, C.MAX_HEIGHT, 1 }
local BAR_RANGE, SPACING_RANGE = { C.MIN_BAR, C.MAX_BAR, 1 }, { 0, C.MAX_SPACING, 1 }
local TEXT_RANGE = { C.MIN_FONT, C.MAX_FONT, 1 }
local BACKGROUND_RANGE, BAR_ALPHA_RANGE = Style.ALPHA_RANGE, { 10, 100, Style.OPACITY_STEP }
local TO_FRACTION = Style.PERCENT_SCALE
local ORDER_METER = 10

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
          help = "Click the title in the window to flip through the lists." },
        { key = "session", label = "Session", choice = SESSION, needs = Enabled, why = OFF,
          help = "The current fight, or everything since the last reset." },
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
        Group("Colors"),
        { key = "barColor", label = "Bar Color", choice = BAR_COLOR, needs = Enabled, why = OFF,
          help = "Class Colors: each player's class. Theme Accent: every bar in your theme's Accent." },
        { label = "Show It on Screen", buttonText = "Preview", needs = Enabled, why = OFF,
          button = function() ns.PreviewDamageMeter() end,
          help = "Shows the meter with sample bars where it sits on your screen, for ten seconds. Out of "
              .. "combat only." },
    },
})

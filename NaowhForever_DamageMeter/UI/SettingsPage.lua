-- SettingsPage.lua: the Damage Meter's settings page, declared as cards.
local ns = _G.NaowhForever

local DM = ns.DamageMeter
local S = DM.Settings
local C = DM.C

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end
local Group = Settings.Group

local OFF = "Turn on the Damage Meter"
local OFF_CUSTOM_BARS = "Set Bar Color to Custom Color"
local OFF_OWN_CUSTOM = "Set Your Bar to Custom Color"
local OFF_EDGE_CUSTOM = "Set Your Row Edge to Custom Color"
local OFF_HIGHLIGHT = "Turn on Highlight Your Row"
local OFF_ABBREVIATING = "Number Format is Game Default or Full Numbers"
local OFF_CLASS = "Set Bar Color to Class Colors"
local OFF_IMAGE = "Pick a Background Image"
local OFF_COMBAT = "Set Where to In Combat"
local OFF_TILE = "Turn on Tile Image"
local OFF_OWN = "Pick Your Own Picture in Image"
local OFF_TIME = "Turn on Show Fight Time"
local Style = ns.Shared.Style
local WIDTH_RANGE, HEIGHT_RANGE = { C.MIN_WIDTH, C.MAX_WIDTH, 1 }, { C.MIN_HEIGHT, C.MAX_HEIGHT, 1 }
local BAR_RANGE, SPACING_RANGE = { C.MIN_BAR, C.MAX_BAR, 1 }, { 0, C.MAX_SPACING, 1 }
local TEXT_RANGE = { C.MIN_FONT, C.MAX_FONT, 1 }
local BACKGROUND_RANGE, BAR_ALPHA_RANGE = Style.ALPHA_RANGE, { 10, 100, Style.OPACITY_STEP }
local TO_FRACTION = Style.PERCENT_SCALE
local REPORT_RANGE = { 1, C.REPORT_MAX, 1 }
local DELAY_RANGE = { 0, C.MAX_HIDE_DELAY, 1 }
local DECIMALS_RANGE = { 0, C.NUMBER_DECIMALS_MAX, 1 }
local TITLE_RANGE = { C.MIN_TITLE, C.MAX_TITLE, 1 }
local OFFSET_X_RANGE, OFFSET_Y_RANGE = { -C.MAX_OFFSET_X, C.MAX_OFFSET_X, 1 }, { -C.MAX_OFFSET_Y, C.MAX_OFFSET_Y, 1 }
local KEEP_RANGE = { C.MIN_KEEP, C.MAX_KEEP, 1 }
local TILE_RANGE = { C.MIN_TILE, C.MAX_TILE, 8 }

local MODE = { C.MODE_LABELS, C.MODE_ORDER }
local SESSION = { C.SESSION_LABELS, C.SESSION_ORDER }
-- The second list: any list, or none.
local LOWER_LABELS, LOWER_ORDER = { [""] = "None" }, { "" }
for _, key in ipairs(C.MODE_ORDER) do
    LOWER_LABELS[key] = C.MODE_LABELS[key]
    LOWER_ORDER[#LOWER_ORDER + 1] = key
end
local LOWER = { LOWER_LABELS, LOWER_ORDER }
local SHOW = { { always = "Always", instance = "In Instances", group = "In a Group", combat = "In Combat" },
    { "always", "instance", "group", "combat" } }
local BAR_COLOR = { C.BAR_COLORS, C.BAR_COLORS_ORDER }
local OWN_BAR = { C.OWN_BAR_STYLES, C.OWN_BAR_STYLES_ORDER }
local EDGE = { C.EDGE_STYLES, C.EDGE_STYLES_ORDER }
local ICON_STYLE = { { spec = "Spec Icon", class = "Class Icon" }, { "spec", "class" } }
local NUMBER_UNITS = { C.NUMBER_UNITS, C.NUMBER_UNITS_ORDER }
local NAME_FORMAT = { C.NAME_FORMATS, C.NAME_FORMATS_ORDER }
local TITLE_TEXT = { C.TITLE_TEXTS, C.TITLE_TEXTS_ORDER }

local function Enabled() return DM.On() and true or false end
local function CustomBars() return DM.On() and S.Get("barColor") == "custom" end
local function ClassBars() return DM.On() and S.Get("barColor") == "class" end
local function Highlighting() return DM.On() and S.Get("highlightPlayer") == true end
local function OwnCustom() return DM.On() and S.Get("ownBarStyle") == "custom" end
local function EdgeCustom()
    return DM.On() and S.Get("highlightPlayer") == true and S.Get("edgeStyle") == "custom"
end
local function HidesAfterCombat() return DM.On() and S.Get("visibility") == "combat" end
local function ShowingTime() return DM.On() and S.Get("showTime") == true end
-- Custom Image is for the choice of Image that is your own picture, and a picture is there when that has a
-- path or another choice is a picture.
local function OwnPicture() return S.Get("backgroundImage") == C.OWN_PICTURE end
local function PicturePath() return DM.On() and OwnPicture() end
local function HasImage()
    if not DM.On() then return false end
    local picked = S.Get("backgroundImage")
    if picked == C.OWN_PICTURE then return S.Get("backgroundPath") ~= "" end
    return picked ~= "" and not C.HIDDEN_BACKGROUNDS[picked]
end
local function TilesImage() return HasImage() and S.Get("imageTile") == true end
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

-- ---- what a card says about itself when it is closed

local function ListsSummary(store)
    local text = DM.Mode(store.Get("mode")).label
    local lower = store.Get("lower")
    if lower ~= "" then text = text .. " over " .. DM.Mode(lower).label end
    return ("%s, %s"):format(text, (C.SESSION_LABELS[store.Get("session")] or C.SESSION_LABELS.current):lower())
end

local function WindowSummary(store)
    local text = ("%d by %d"):format(store.Get("width"), store.Get("height"))
    if store.Get("locked") then text = text .. ", locked" end
    return text
end

local function RowsSummary(store)
    return ("%d px rows, %d px apart"):format(store.Get("barHeight"), store.Get("barSpacing"))
end

local function NumbersSummary(store)
    return ("%s, %s"):format(C.NUMBER_UNITS[store.Get("numberUnits")] or "", C.NAME_FORMATS[store.Get("nameFormat")] or "")
end

local function HeaderSummary(store)
    return ("%s, time %s"):format(C.TITLE_TEXTS[store.Get("titleText")] or "", store.Get("showTime") and "on" or "off")
end

local function TextSummary(store)
    return ("Size %d"):format(store.Get("fontSize"))
end

local function HoverSummary(store)
    return ("Spells %s, reports of %d lines"):format(store.Get("breakdown") and "on" or "off",
        store.Get("reportLines"))
end

local function HistorySummary(store)
    return ("%d of %d fights kept"):format(#(store.Get("history") or {}), store.Get("keepFights"))
end

local function BarColorsSummary(store)
    return C.BAR_COLORS[store.Get("barColor")] or ""
end

local function PickedSummary(group)
    return function(store)
        local picked = 0
        for _, entry in ipairs(C.COLORS) do
            if entry.group == group and type(store.Get(entry.key)) == "table" then picked = picked + 1 end
        end
        return picked == 0 and "Theme" or picked .. " picked"
    end
end

local function ClassesSummary(store)
    local picked = 0
    for _ in pairs(store.Get("classColors") or {}) do picked = picked + 1 end
    return picked == 0 and "The game's" or picked .. " picked"
end

local function WindowNSummary(index)
    return function(store)
        return ("%s, %d by %d"):format(DM.Mode(store.Get(DM.Key("mode", index))).label,
            store.Get(DM.Key("width", index)), store.Get(DM.Key("height", index)))
    end
end

-- ---- colors

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

local COLOR_NEEDS = { barCustomColor = CustomBars, ownBarColor = OwnCustom, edgeColor = EdgeCustom }
local COLOR_WHY = { barCustomColor = OFF_CUSTOM_BARS, ownBarColor = OFF_OWN_CUSTOM, edgeColor = OFF_EDGE_CUSTOM }
local COLOR_HELP = {
    barCustomColor = "The bars' color when Bar Color is Custom Color.",
    ownBarColor = "The color of your own bar when Your Bar is Custom Color.",
    edgeColor = "The strip on the left of your row when Your Row Edge is Custom Color.",
}

local colorEntry = {}
for _, entry in ipairs(C.COLORS) do colorEntry[entry.key] = entry end

local function ColorRow(key)
    local entry = colorEntry[key]
    return { key = key, label = entry.label, colour = true, get = PickedGet(key), set = PickedSet(key),
        needs = COLOR_NEEDS[key] or Enabled, why = COLOR_WHY[key] or OFF, help = COLOR_HELP[key] }
end

local function ColorRows(group)
    local rows = {}
    for _, entry in ipairs(C.COLORS) do
        if entry.group == group then rows[#rows + 1] = ColorRow(entry.key) end
    end
    return rows
end

-- The classes the game has, in its own order, each with a picker for its bar color.
local function ClassList()
    local list = {}
    if CLASS_SORT_ORDER then
        for _, class in ipairs(CLASS_SORT_ORDER) do list[#list + 1] = class end
    else
        for class in pairs(RAID_CLASS_COLORS or {}) do list[#list + 1] = class end
        table.sort(list)
    end
    return list
end

local function ClassName(class)
    return LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class
end

local function ClassRow(class)
    return { key = "classColors", field = class, label = ClassName(class), colour = true,
        get = function()
            local c = DM.Look.ClassColor(class)
            return c.r, c.g, c.b, 1
        end,
        set = function(r, g, b)
            local picked = {}
            for k, v in pairs(S.Get("classColors") or {}) do picked[k] = v end
            picked[class] = { r = r, g = g, b = b }
            S.Set("classColors", picked)
        end,
        needs = ClassBars, why = OFF_CLASS }
end

local function ClassRows()
    local rows = {}
    for _, class in ipairs(ClassList()) do rows[#rows + 1] = ClassRow(class) end
    return rows
end

-- None, your own picture, and the backgrounds the shared media offers by name without the game's plain
-- ones. One picked before they were left out reads as None.
local function ImageChoices()
    local values, order = { [""] = "None", [C.OWN_PICTURE] = "Your Own Picture" }, { "", C.OWN_PICTURE }
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        for _, name in ipairs(LSM:List("background")) do
            if not C.HIDDEN_BACKGROUNDS[name] then
                values[name] = name
                order[#order + 1] = name
            end
        end
    end
    local picked = S.Get("backgroundImage")
    if C.HIDDEN_BACKGROUNDS[picked] then
        values[picked] = values[""]
    elseif picked ~= "" and not values[picked] then
        values[picked] = picked .. " (unavailable)"
        order[#order + 1] = picked
    end
    return values, order
end

local page = Settings.Page(C.PAGE, S)

page:Window({
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "lists", name = "Lists", order = 10,
    help = "What the window lists, for which session, and when it shows. Preview shows it with sample bars.",
    summary = ListsSummary,
    rows = {
        { key = "mode", label = "Show", choice = MODE, needs = Enabled, why = OFF,
          help = "Click the title in the window to choose a list." },
        { key = "lower", label = "Second List", choice = LOWER, needs = Enabled, why = OFF,
          help = "Another list under the first, in the same window, like damage above healing." },
        { key = "session", label = "Session", choice = SESSION, needs = Enabled, why = OFF,
          help = "The current fight, or everything since the last reset. Past fights are in the window's "
              .. "Session button." },
        Group("Showing"),
        { key = "hideGameMeter", label = "Replace the Game's Meter", toggle = true, needs = Enabled, why = OFF,
          help = "Turns the game's own damage meter off while this one is on." },
        { key = "visibility", label = "Where", choice = SHOW, needs = Enabled, why = OFF,
          help = "In Combat shows it while you fight and a while after. A key binding shows or hides it." },
        { key = "hideDelay", label = "Hide After", slider = DELAY_RANGE, unit = "s", needs = HidesAfterCombat,
          why = OFF_COMBAT },
        { key = "raidMode", label = "Raid Mode", toggle = true, needs = Enabled, why = OFF,
          help = "Only your own row, with your rank, in place of the whole group." },
        { label = "Show It on Screen", buttonText = "Preview", needs = Enabled, why = OFF,
          button = function() ns.PreviewDamageMeter() end,
          help = "Shows the meter with sample bars where it sits on your screen, for ten seconds. Out of "
              .. "combat only." },
    },
})

page:Card({
    id = "window", name = "Window", order = 20,
    help = "Its size, its background and its picture. Move it in the HUD Editor.",
    summary = WindowSummary,
    rows = {
        Group("Size"),
        { key = "width", label = "Width", slider = WIDTH_RANGE, needs = Enabled, why = OFF },
        { key = "height", label = "Height", slider = HEIGHT_RANGE, needs = Enabled, why = OFF },
        { key = "locked", label = "Lock Window", toggle = true, needs = Enabled, why = OFF,
          help = "Off: drag the title bar to move it and the corner to resize it, in combat too." },
        Group("Background"),
        { key = "backgroundAlpha", label = "Opacity", slider = BACKGROUND_RANGE, unit = "%",
          scale = TO_FRACTION, needs = Enabled, why = OFF },
        { key = "showBorder", label = "Border", toggle = true, needs = Enabled, why = OFF },
        Group("Picture"),
        { key = "backgroundImage", label = "Image", choice = ImageChoices, needs = Enabled, why = OFF,
          help = "None, your own picture, or one from a shared media add-on." },
        { key = "backgroundPath", label = "Custom Image", text = true, wide = true, needs = PicturePath,
          why = OFF_OWN, help = "The path of your own picture. Used when Image is Your Own Picture." },
        { label = "Adding a Picture", buttonText = "Show How", needs = Enabled, why = OFF,
          button = function() DM.ShowImageHelp() end,
          help = "A window that says where to put a picture and what to type." },
        { key = "imageAlpha", label = "Image Opacity", slider = BACKGROUND_RANGE, unit = "%", scale = TO_FRACTION,
          needs = HasImage, why = OFF_IMAGE },
        { key = "imageTile", label = "Tile Image", toggle = true, needs = HasImage, why = OFF_IMAGE,
          help = "Repeats the picture in place of stretching it, for patterns." },
        { key = "imageTileSize", label = "Tile Size", slider = TILE_RANGE, unit = "px", needs = TilesImage,
          why = OFF_TILE, help = "How wide each repeat is, in pixels." },
    },
})

page:Card({
    id = "rows", name = "Rows", order = 30,
    help = "How tall the rows are, and what each one shows.",
    summary = RowsSummary,
    rows = {
        Group("Bars"),
        { key = "barHeight", label = "Row Height", slider = BAR_RANGE, needs = Enabled, why = OFF },
        { key = "barSpacing", label = "Row Spacing", slider = SPACING_RANGE, needs = Enabled, why = OFF },
        { key = "barAlpha", label = "Bar Opacity", slider = BAR_ALPHA_RANGE, unit = "%", scale = TO_FRACTION,
          needs = Enabled, why = OFF },
        Group("Row"),
        { key = "showIcons", label = "Icons", toggle = true, needs = Enabled, why = OFF },
        { key = "iconStyle", label = "Icon Style", choice = ICON_STYLE, needs = Enabled, why = OFF },
        { key = "showRanks", label = "Rank Numbers", toggle = true, needs = Enabled, why = OFF },
        { key = "highlightPlayer", label = "Highlight Your Row", toggle = true, needs = Enabled, why = OFF },
    },
})

page:Card({
    id = "numbers", name = "Numbers and Names", order = 40,
    help = "The columns of figures, how numbers are written and how names are.",
    summary = NumbersSummary,
    rows = {
        Group("Columns"),
        { key = "showTotal", label = "Show Total", toggle = true, needs = Enabled, why = OFF },
        { key = "showRate", label = "Show Per Second", toggle = true, needs = Enabled, why = OFF,
          help = "Damage, healing and absorbs only." },
        { key = "showColumnHeaders", label = "Column Titles", toggle = true, needs = Enabled, why = OFF,
          help = "A line of titles above the rows: Name and what each column shows." },
        Group("Writing"),
        { key = "numberUnits", label = "Number Format", choice = NUMBER_UNITS, needs = Enabled, why = OFF,
          help = "How big numbers are written. Ten-thousands groups by ten-thousands and hundred-millions." },
        { key = "numberDecimals", label = "Decimals", slider = DECIMALS_RANGE, needs = Abbreviating,
          why = OFF_ABBREVIATING },
        { key = "nameFormat", label = "Name Format", choice = NAME_FORMAT, needs = Enabled, why = OFF,
          help = "How a player's name is written. In combat the game hides other players' names, so those "
              .. "are found by class and left whole when two players share one." },
    },
})

page:Card({
    id = "header", name = "Title Bar", order = 50,
    help = "The title, the length of the fight and the line under them.",
    summary = HeaderSummary,
    rows = {
        Group("Title"),
        { key = "titleText", label = "Title Shows", choice = TITLE_TEXT, needs = Enabled, why = OFF,
          help = "The list's name, the name the game gave the fight, or both. A fight with no name yet "
              .. "shows the list's." },
        { key = "titleX", label = "Title X Offset", slider = OFFSET_X_RANGE, unit = "px", needs = Enabled, why = OFF,
          help = "Moves the title right, or left below zero. The second list's title moves with it." },
        { key = "titleY", label = "Title Y Offset", slider = OFFSET_Y_RANGE, unit = "px", needs = Enabled, why = OFF,
          help = "Moves the title up, or down below zero." },
        { key = "titleSize", label = "Title Size", slider = TITLE_RANGE, needs = Enabled, why = OFF },
        Group("Fight Time"),
        { key = "showTime", label = "Show Fight Time", toggle = true, needs = Enabled, why = OFF,
          help = "How long the shown session has run, when there is room beside the title." },
        { key = "timeX", label = "Time X Offset", slider = OFFSET_X_RANGE, unit = "px", needs = ShowingTime,
          why = OFF_TIME, help = "Moves the time right, or left below zero, from beside the buttons." },
        { key = "timeY", label = "Time Y Offset", slider = OFFSET_Y_RANGE, unit = "px", needs = ShowingTime,
          why = OFF_TIME, help = "Moves the time up, or down below zero." },
        { key = "timeSize", label = "Fight Time Size", slider = TITLE_RANGE, needs = Enabled, why = OFF },
        Group("Under the Bar"),
        { key = "showSummary", label = "Summary Line", toggle = true, needs = Enabled, why = OFF,
          help = "Under the title bar: the session, its total, the raid's per-second figure once the fight "
              .. "is over, and your rank." },
    },
})

page:Card({
    id = "text", name = "Text and Bars", order = 60,
    help = "The font, its outline and the texture of the bars.",
    summary = TextSummary,
    rows = {
        Settings.Look("", { text = true, size = TEXT_RANGE, bar = "Naowh Gradient", needs = Enabled, why = OFF }),
    },
})

page:Card({
    id = "hover", name = "Hover and Report", order = 70,
    help = "The spells behind a row, and what Report To sends.",
    summary = HoverSummary,
    rows = {
        Group("Spells"),
        { key = "breakdown", label = "Spell Breakdown", toggle = true, needs = Enabled, why = OFF,
          help = "Hover a row to see its spells. In combat only your own row and rows the game lets through "
              .. "show spells." },
        Group("Report"),
        { key = "reportLines", label = "Report Lines", slider = REPORT_RANGE, needs = Enabled, why = OFF,
          help = "How many rows Report To sends, out of combat only. Reset has a key binding under Naowh Forever." },
    },
})

page:Card({
    id = "history", name = "Fight History", order = 80,
    help = "A summary of each fight, kept when it ends, with your figures and the raid's.",
    summary = HistorySummary,
    rows = {
        { key = "keepFights", label = "Fights Kept", slider = KEEP_RANGE, needs = Enabled, why = OFF },
        { label = "Fight History", buttonText = "Open", needs = Enabled, why = OFF,
          button = function() DM.HistoryWindow.Toggle() end,
          help = "The fights kept: when, which, how long, and the per-second figures." },
        { label = "Clear Fight History", buttonText = "Clear", needs = Enabled, why = OFF,
          button = function() DM.HistoryWindow.AskClear() end },
    },
})

page:Card({
    id = "barColors", name = "Bar Colors", order = 90,
    help = "The bars: for everyone, and for you and the strip beside your row.",
    summary = BarColorsSummary,
    rows = {
        Group("Everyone"),
        { key = "barColor", label = "Bar Color", choice = BAR_COLOR, needs = Enabled, why = OFF,
          help = "Class Colors: each player's class. Theme Accent: every bar in your theme's Accent. Custom "
              .. "Color: every bar in the one you pick." },
        ColorRow("barCustomColor"),
        Group("You"),
        { key = "ownBarStyle", label = "Your Bar", choice = OWN_BAR, needs = Enabled, why = OFF,
          help = "Your own bar: the same as the others, in your class's color, or in a color of its own." },
        ColorRow("ownBarColor"),
        { key = "edgeStyle", label = "Your Row Edge", choice = EDGE, needs = Highlighting, why = OFF_HIGHLIGHT,
          help = "The strip on the left of your row: the theme's Accent, your class's color, or one of your "
              .. "own." },
        ColorRow("edgeColor"),
    },
})

page:Card({
    id = "textColors", name = "Text Colors", order = 100,
    help = "A color for each text. Until you pick one, it follows your theme.",
    summary = PickedSummary("Text"),
    rows = ColorRows("Text"),
})

page:Card({
    id = "windowColors", name = "Window Colors", order = 110,
    help = "The window, its title bar and its border. Until you pick one, it follows your theme.",
    summary = PickedSummary("Window"),
    rows = ColorRows("Window"),
})

page:Card({
    id = "classColors", name = "Class Colors", order = 120,
    help = "The color of each class's bars, when Bar Color is Class Colors.",
    summary = ClassesSummary,
    rows = ClassRows(),
})

page:Card({
    id = "window2", name = "Second Window", order = 130, switch = "window2",
    help = "A second window, with its own list, session and size.",
    summary = WindowNSummary(2),
    rows = {
        { key = "mode2", label = "Show", choice = MODE, needs = Enabled, why = OFF },
        { key = "lower2", label = "Second List", choice = LOWER, needs = Enabled, why = OFF },
        { key = "session2", label = "Session", choice = SESSION, needs = Enabled, why = OFF },
        { key = "width2", label = "Width", slider = WIDTH_RANGE, needs = Enabled, why = OFF },
        { key = "height2", label = "Height", slider = HEIGHT_RANGE, needs = Enabled, why = OFF },
    },
})

page:Card({
    id = "window3", name = "Third Window", order = 140, switch = "window3",
    help = "A third window, with its own list, session and size.",
    summary = WindowNSummary(3),
    rows = {
        { key = "mode3", label = "Show", choice = MODE, needs = Enabled, why = OFF },
        { key = "lower3", label = "Second List", choice = LOWER, needs = Enabled, why = OFF },
        { key = "session3", label = "Session", choice = SESSION, needs = Enabled, why = OFF },
        { key = "width3", label = "Width", slider = WIDTH_RANGE, needs = Enabled, why = OFF },
        { key = "height3", label = "Height", slider = HEIGHT_RANGE, needs = Enabled, why = OFF },
    },
})

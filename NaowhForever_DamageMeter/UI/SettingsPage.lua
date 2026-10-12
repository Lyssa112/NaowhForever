-- SettingsPage.lua: the Damage Meter's settings page, declared as a few cards. What a part has beyond its
-- switch or its first control (a text's size and font, a picture's tiling, the classes' colors) is behind
-- the cog of the row that owns it, and a row that means something only for one choice shows with it.
local ns = _G.NaowhForever

local DM = ns.DamageMeter
local S = DM.Settings
local C = DM.C

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end
local Group = Settings.Group

local OFF = "Turn on the Damage Meter"
local OFF_OWN_CUSTOM = "Set Your Bar to Custom Color"
local OFF_EDGE_CUSTOM = "Set Your Row Edge to Custom Color"
local OFF_HIGHLIGHT = "Turn on Highlight Your Row"
local OFF_CLASS = "Set Bar Color to Class Colors"
local OFF_IMAGE = "Pick a Background Image"
local OFF_TILE = "Turn on Tile Image"
local OFF_OWN = "Pick Your Own Picture in Image"
local OFF_TIME = "Turn on Show Fight Time"
local OFF_BOTH = "Turn on Show Total and Show Per Second"
local OFF_FADE = "Set Out of Combat Opacity below 100%"
local OFF_SUMMARY = "Turn on Summary Line"
local OFF_LOCKED = "Turn on Lock Window"
local OFF_OWN_FONT = "Turn on its Own Font"
local OFF_OWN_LOOK = "Turn on Own Look"
local TEXT_LOOK_NAME, TEXT_LOOK_EXPORT, TEXT_LOOK_IMPORT = "Name this look", "Look", "Paste a look"
local TEXT_LOOKS_FULL = "There is room for twelve looks. Delete one first."
local TEXT_LOOK_NO_NAME, TEXT_LOOK_BAD = "A look needs a name.", "That is not a look."
local TEXT_LOOK_DELETE = "Delete the look %s?"
local Style = ns.Shared.Style
local WIDTH_RANGE, HEIGHT_RANGE = { C.MIN_WIDTH, C.MAX_WIDTH, 1 }, { C.MIN_HEIGHT, C.MAX_HEIGHT, 1 }
local SCALE_RANGE = { C.MIN_SCALE, C.MAX_SCALE, 5 }
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
local ICON_SIZE_RANGE, ICON_ZOOM_RANGE = { 0, C.MAX_ICON, 1 }, { 0, 30, 1 }
local PANEL_LINES_RANGE, TARGET_LINES_RANGE = { 1, C.BREAKDOWN_MAX, 1 }, { 1, C.TARGET_MAX, 1 }
local PANEL_WIDTH_RANGE, PANEL_SCALE_RANGE = { C.MIN_PANEL_WIDTH, C.MAX_PANEL_WIDTH, 5 },
    { C.MIN_PANEL_SCALE, C.MAX_PANEL_SCALE, 5 }
local FIGHTS_RANGE = { 1, C.FIGHTS_MAX, 1 }
local PAD_RANGE, EDGE_RANGE = { 0, C.MAX_PAD, 1 }, { 0, 8, 1 }
local LETTERS_RANGE, PERCENT_DECIMALS_RANGE = { 0, C.MAX_NAME_LETTERS, 1 }, { 0, C.MAX_PERCENT_DECIMALS, 1 }

local MODE = { C.MODE_LABELS, C.MODE_ORDER }
local SESSION = { C.SESSION_LABELS, C.SESSION_ORDER }
-- The second list: any list, or none.
local LOWER_LABELS, LOWER_ORDER = { [""] = "None" }, { "" }
for _, key in ipairs(C.MODE_ORDER) do
    LOWER_LABELS[key] = C.MODE_LABELS[key]
    LOWER_ORDER[#LOWER_ORDER + 1] = key
end
local LOWER = { LOWER_LABELS, LOWER_ORDER }
local SHOW = { { always = "Always", instance = "In Instances", group = "In a Group", raid = "In a Raid",
    combat = "In Combat" }, { "always", "instance", "group", "raid", "combat" } }
local RESET_ON = { C.RESET_ON, C.RESET_ON_ORDER }
local BAR_COLOR = { C.BAR_COLORS, C.BAR_COLORS_ORDER }
local OWN_BAR = { C.OWN_BAR_STYLES, C.OWN_BAR_STYLES_ORDER }
local EDGE = { C.EDGE_STYLES, C.EDGE_STYLES_ORDER }
local ICON_STYLE = { { spec = "Spec Icon", class = "Class Icon" }, { "spec", "class" } }
local NUMBER_UNITS = { C.NUMBER_UNITS, C.NUMBER_UNITS_ORDER }
local NAME_FORMAT = { C.NAME_FORMATS, C.NAME_FORMATS_ORDER }
local BAR_SCALE = { C.BAR_SCALES, C.BAR_SCALES_ORDER }
local PANEL_SIDE = { C.PANEL_SIDES, C.PANEL_SIDES_ORDER }
local COLUMN_ORDER = { C.COLUMN_ORDERS, C.COLUMN_ORDERS_ORDER }
local ICON_SIDE = { C.ICON_SIDES, C.ICON_SIDES_ORDER }
local TITLE_TEXT = { C.TITLE_TEXTS, C.TITLE_TEXTS_ORDER }
local OUTLINE = ns.Shared.Parts.HUD_OUTLINES

local function Enabled() return DM.On() and true or false end
local function On(key) return function() return DM.On() and S.Get(key) == true end end
local function ClassBars() return DM.On() and S.Get("barColor") == "class" end
local function Highlighting() return DM.On() and S.Get("highlightPlayer") == true end
local function OwnCustom() return DM.On() and S.Get("ownBarStyle") == "custom" end
local function EdgeCustom()
    return DM.On() and S.Get("highlightPlayer") == true and S.Get("edgeStyle") == "custom"
end
local function BothFigures() return DM.On() and S.Get("showTotal") == true and S.Get("showRate") == true end
local function Fading() return DM.On() and S.Get("idleAlpha") < 1 end
local function Locked() return DM.On() and S.Get("locked") == true end
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
local function OwnFonted(element) return On(element .. "OwnFont") end

-- Rows that mean something for one choice only are left off the page for the others.
local function NotCombat() return S.Get("visibility") ~= "combat" end
local function NotCustomBars() return S.Get("barColor") ~= "custom" end
local function NotTracking() return S.Get("barTrack") ~= true end
local function NotAbbreviating()
    local units = S.Get("numberUnits")
    return units ~= "latin" and units ~= "asian"
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

local function BarsSummary(store)
    return ("%d px rows, %d px apart"):format(store.Get("barHeight"), store.Get("barSpacing"))
end

local function RowSummary(store)
    local icons = store.Get("showIcons") and (C.ICON_SIDES[store.Get("iconSide")] or ""):lower() or "off"
    return ("Icons %s, ranks %s"):format(icons, store.Get("showRanks") and "on" or "off")
end

local function FiguresSummary(store)
    return ("%s, %s"):format(C.COLUMN_ORDERS[store.Get("columnOrder")] or "",
        C.NUMBER_UNITS[store.Get("numberUnits")] or "")
end

local function HeaderSummary(store)
    return ("%s, buttons %s"):format(C.TITLE_TEXTS[store.Get("titleText")] or "",
        store.Get("showButtons") and "on" or "off")
end

local function HoverSummary(store)
    return ("Spells %s, reports of %d lines"):format(store.Get("breakdown") and "on" or "off",
        store.Get("reportLines"))
end

local function DataSummary(store)
    local text = ("%d of %d fights kept"):format(#DM.History.List(), store.Get("keepFights"))
    local rule = store.Get("resetOn")
    if rule ~= "never" then text = text .. ", reset " .. (C.RESET_ON[rule] or ""):lower() end
    return text
end

local function LooksSummary()
    local count = #DM.LookNames()
    return count == 0 and "None kept" or ("%d kept"):format(count)
end

local function WindowNSummary(index)
    return function(store)
        return ("%s, %d by %d"):format(DM.Mode(store.Get(DM.Key("mode", index))).label,
            store.Get(DM.Key("width", index)), store.Get(DM.Key("height", index)))
    end
end

-- The settings that leave only the title and the bars: no titles over the columns, no buttons, no rank
-- numbers, nothing behind or around, and the time in brackets after the title.
local CLEAN_LOOK = { showColumnHeaders = false, showButtons = false, showSummary = false, showRanks = false,
    showBorder = false, headerAlpha = 0, backgroundAlpha = 0, timeBrackets = true, timeByTitle = true,
    showDivider = true }
local TEXT_CLEAN_ASK = "Hide the column titles, buttons, rank numbers, backgrounds and border?"

local function ApplyCleanLook()
    for key, value in pairs(CLEAN_LOOK) do S.Set(key, value) end
    if ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
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

local COLOR_NEEDS = { ownBarColor = OwnCustom, edgeColor = EdgeCustom }
local COLOR_WHY = { ownBarColor = OFF_OWN_CUSTOM, edgeColor = OFF_EDGE_CUSTOM }
local COLOR_HELP = {
    barCustomColor = "The bars' color when Bar Color is Custom Color.",
    ownBarColor = "The color of your own bar when Your Bar is Custom Color.",
    edgeColor = "The strip on the left of your row when Your Row Edge is Custom Color.",
    trackColor = "The color behind each bar, where it is not filled.",
}

local colorEntry = {}
for _, entry in ipairs(C.COLORS) do colorEntry[entry.key] = entry end

local function ColorRow(key)
    local entry = colorEntry[key]
    return { key = key, label = entry.label, colour = true, get = PickedGet(key), set = PickedSet(key),
        needs = COLOR_NEEDS[key] or Enabled, why = COLOR_WHY[key] or OFF, help = COLOR_HELP[key] }
end

-- A text's color picker as the row of the text's settings: it is called what its cog holds, and is still
-- found by the color's name.
local function SettingsRow(key, label, help)
    local row = ColorRow(key)
    row.search = row.label:lower()
    row.label, row.help = label, help
    return row
end

-- A row that is left off the page while hidden() says so.
local function HiddenWhen(row, hidden)
    row.hidden = hidden
    return row
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

-- ---- building blocks

-- The parts of a card's rows, rows and lists of rows, as one list.
local function Join(...)
    local rows = {}
    for _, part in ipairs({ ... }) do
        if part[1] ~= nil then
            for _, row in ipairs(part) do rows[#rows + 1] = row end
        else
            rows[#rows + 1] = part
        end
    end
    return rows
end

-- A row with a cog, and the rows behind it: they are left off the page and shown in the cog's panel.
local function Under(owner, title, tip, rows)
    owner.cog = { title = title, tip = tip }
    for _, row in ipairs(rows[1] ~= nil and rows or { rows }) do row.under = owner.label end
    return Join(owner, rows)
end

-- A text's size, on the card beside the row that owns the text. It shows the size the text has, and setting
-- it gives the text a size of its own, which the switch in the text's cog turns off again. noun is what the
-- rows call the text ("Rank": Rank Size, Own Rank Size, ...).
local function SizeRow(noun, element, sizeKey, range)
    return { key = sizeKey, label = noun .. " Size", slider = range, needs = Enabled, why = OFF,
        get = function()
            local _, _, size = DM.Look.TextStyle(element, S.Get("fontSize"))
            return size
        end,
        set = function(v)
            S.Set(sizeKey, v)
            S.Set(element .. "OwnSize", true)
        end,
        help = "Setting it gives the " .. noun:lower() .. " a size of its own, which the cog turns off again." }
end

-- A text's size switch, and its font and outline behind a switch: with a switch off the text has the usual
-- size, and the window's font and outline.
local function TextRows(noun, element, help)
    return {
        { key = element .. "OwnSize", label = "Own " .. noun .. " Size", toggle = true, needs = Enabled, why = OFF,
          help = help },
        { key = element .. "OwnFont", label = "Own " .. noun .. " Font", toggle = true, needs = Enabled, why = OFF,
          help = "Off: the font and outline of Window." },
        { key = element .. "Font", label = noun .. " Font", font = true, needs = OwnFonted(element),
          why = OFF_OWN_FONT },
        { key = element .. "Outline", label = noun .. " Outline", choice = OUTLINE, needs = OwnFonted(element),
          why = OFF_OWN_FONT },
    }
end

local page = Settings.Page(C.PAGE, S)

page:Window({
    headline = Headline,
    detail = Detail,
})

-- ---- what the window lists, and when

page:Card({
    id = "lists", name = "Lists", order = 10,
    help = "What the window lists, for which session, and when it shows. Preview shows it with sample bars.",
    summary = ListsSummary,
    rows = {
        { key = "mode", label = "Show", choice = MODE, needs = Enabled, why = OFF,
          help = "Also in the window's ... menu, under List." },
        { key = "lower", label = "Second List", choice = LOWER, needs = Enabled, why = OFF,
          help = "Another list under the first, in the same window, like damage above healing." },
        { key = "session", label = "Session", choice = SESSION, needs = Enabled, why = OFF,
          help = "The current fight, or everything since the last reset. Past fights are in the window's "
              .. "Session button or its ... menu." },
        { key = "shortNames", label = "Short List Names", toggle = true, needs = Enabled, why = OFF,
          help = "Damage in place of Damage Done, Healing in place of Healing Done, in the title and the "
              .. "spell panel. The menus and the reports keep the full names." },
        Group("Showing"),
        { key = "hideGameMeter", label = "Replace the Game's Meter", toggle = true, needs = Enabled, why = OFF,
          help = "Turns the game's own damage meter off while this one is on." },
        { key = "visibility", label = "Where", choice = SHOW, needs = Enabled, why = OFF,
          help = "In Combat shows it while you fight and a while after. A key binding shows or hides it." },
        HiddenWhen({ key = "hideDelay", label = "Hide After", slider = DELAY_RANGE, unit = "s", needs = Enabled,
            why = OFF }, NotCombat),
        { key = "hideInPvP", label = "Hide in Battlegrounds", toggle = true, needs = Enabled, why = OFF,
          help = "Hides the windows in battlegrounds and arenas, whatever Where says." },
        { key = "raidMode", label = "Raid Mode", toggle = true, needs = Enabled, why = OFF,
          help = "Only your own row, with your rank, in place of the whole group." },
        { label = "Show It on Screen", buttonText = "Preview", needs = Enabled, why = OFF,
          button = function() ns.PreviewDamageMeter() end,
          help = "Shows the meter with sample bars where it sits on your screen, for ten seconds. Out of "
              .. "combat only." },
    },
})

-- ---- the window: its size, its background, its picture, its fade and the font its texts have

page:Card({
    id = "window", name = "Window", order = 20,
    help = "Its size, background, picture and fade, and the font every text has unless it has its own.",
    summary = WindowSummary,
    rows = Join(
        Group("Size"),
        { key = "width", label = "Width", slider = WIDTH_RANGE, needs = Enabled, why = OFF },
        { key = "height", label = "Height", slider = HEIGHT_RANGE, needs = Enabled, why = OFF },
        { key = "scale", label = "Scale", slider = SCALE_RANGE, unit = "%", scale = TO_FRACTION, needs = Enabled,
          why = OFF, help = "Makes the whole window larger or smaller, text and all." },
        Under({ key = "locked", label = "Lock Window", toggle = true, needs = Enabled, why = OFF,
            help = "Off: drag the title bar to move it and the corner to resize it, in combat too." },
            "Lock Window", "What the mouse does while the window is locked.",
            { key = "clickThrough", label = "Mouse Passes Through", toggle = true, needs = Locked, why = OFF_LOCKED,
              help = "While the window is locked, clicks and the mouse go through it to the game. The spell "
                  .. "panel and clicking a name do not work then." }),
        Group("Background"),
        { key = "backgroundAlpha", label = "Window Opacity", slider = BACKGROUND_RANGE, unit = "%",
          scale = TO_FRACTION, needs = Enabled, why = OFF },
        ColorRow("windowColor"),
        { key = "showBorder", label = "Border", toggle = true, needs = Enabled, why = OFF },
        ColorRow("borderColor"),
        Under({ key = "backgroundImage", label = "Image", choice = ImageChoices, needs = Enabled, why = OFF,
            help = "None, your own picture, or one from a shared media add-on." },
            "Picture", "Your own picture's path, and how the picture is drawn.", {
            { key = "backgroundPath", label = "Custom Image", text = true, wide = true, needs = PicturePath,
              why = OFF_OWN, help = "The path of your own picture. Used when Image is Your Own Picture." },
            { label = "Adding a Picture", buttonText = "Show How", needs = Enabled, why = OFF,
              button = function() DM.ShowImageHelp() end,
              help = "A window that says where to put a picture and what to type." },
            { key = "imageAlpha", label = "Image Opacity", slider = BACKGROUND_RANGE, unit = "%",
              scale = TO_FRACTION, needs = HasImage, why = OFF_IMAGE },
            { key = "imageTile", label = "Tile Image", toggle = true, needs = HasImage, why = OFF_IMAGE,
              help = "Repeats the picture in place of stretching it, for patterns." },
            { key = "imageTileSize", label = "Tile Size", slider = TILE_RANGE, unit = "px", needs = TilesImage,
              why = OFF_TILE, help = "How wide each repeat is, in pixels." } }),
        Under({ key = "idleAlpha", label = "Out of Combat Opacity", slider = BACKGROUND_RANGE, unit = "%",
            scale = TO_FRACTION, needs = Enabled, why = OFF,
            help = "How opaque the whole window is when you are not in combat. In combat it is full." },
            "Fade", "What the fade does with the mouse.",
            { key = "hoverFull", label = "Full While Hovered", toggle = true, needs = Fading, why = OFF_FADE,
              help = "The window is fully opaque while the mouse is over it." }),
        Group("Text"),
        { key = "font", label = "Font", font = true, needs = Enabled, why = OFF },
        { key = "outline", label = "Outline", choice = OUTLINE, needs = Enabled, why = OFF,
          help = "None, the soft shadow, a thin outline or a thick one." }
    ),
})

-- ---- the bars: how they stand, their color and texture, and yours

page:Card({
    id = "bars", name = "Bars", order = 30,
    help = "How tall the bars are, their color, texture and track, and how your own row stands out.",
    summary = BarsSummary,
    rows = Join(
        Group("Bars"),
        { key = "barHeight", label = "Row Height", slider = BAR_RANGE, needs = Enabled, why = OFF },
        { key = "barSpacing", label = "Row Spacing", slider = SPACING_RANGE, needs = Enabled, why = OFF },
        { key = "barAlpha", label = "Bar Opacity", slider = BAR_ALPHA_RANGE, unit = "%", scale = TO_FRACTION,
          needs = Enabled, why = OFF },
        { key = "growUp", label = "Grow Upward", toggle = true, needs = Enabled, why = OFF,
          help = "The first row at the bottom and the rest stacked above it, as some meters do." },
        { key = "reverseFill", label = "Fill From the Right", toggle = true, needs = Enabled, why = OFF,
          help = "Each bar grows from its right end toward the left." },
        { key = "barScale", label = "Bars Compare To", choice = BAR_SCALE, needs = Enabled, why = OFF,
          help = "Top Player: the biggest bar is full. List Total: each bar is its share of the whole list." },
        Group("Color"),
        Under({ key = "barColor", label = "Bar Color", choice = BAR_COLOR, needs = Enabled, why = OFF,
            help = "Class Colors: each player's class. Theme Accent: every bar in your theme's Accent. Custom "
                .. "Color: every bar in the one you pick." },
            "Class Colors", "The color of each class's bars, when Bar Color is Class Colors.", ClassRows()),
        HiddenWhen(ColorRow("barCustomColor"), NotCustomBars),
        { key = "texture", label = "Bar Texture", texture = "Naowh Gradient", needs = Enabled, why = OFF },
        { key = "barTrack", label = "Bar Track", toggle = true, needs = Enabled, why = OFF,
          help = "A color behind each bar, where it is not filled." },
        HiddenWhen(ColorRow("trackColor"), NotTracking),
        Group("Your Row"),
        Under({ key = "highlightPlayer", label = "Highlight Your Row", toggle = true, needs = Enabled, why = OFF },
            "Your Row", "Your bar's color, and the strip on the left of your row.", {
            { key = "ownBarStyle", label = "Your Bar", choice = OWN_BAR, needs = Enabled, why = OFF,
              help = "Your own bar: the same as the others, in your class's color, or in a color of its own." },
            ColorRow("ownBarColor"),
            { key = "edgeStyle", label = "Your Row Edge", choice = EDGE, needs = Highlighting, why = OFF_HIGHLIGHT,
              help = "The strip on the left of your row: the theme's Accent, your class's color, or one of your "
                  .. "own." },
            ColorRow("edgeColor"),
            { key = "edgeWidth", label = "Edge Width", slider = EDGE_RANGE, unit = "px", needs = Enabled,
              why = OFF, help = "The strip on the left of a row, which shows your row in your edge color." } }),
        { key = "pinSelf", label = "Always Show My Row", toggle = true, needs = Enabled, why = OFF,
          help = "When you are not among the rows shown, the last row is yours, with your rank." }
    ),
})

-- ---- a row: its icon, rank and name, and the room between them

page:Card({
    id = "row", name = "Row", order = 40,
    help = "What each row has before its figures: icon, rank and name, with their sizes, fonts and colors.",
    summary = RowSummary,
    rows = Join(
        Under({ key = "showIcons", label = "Icons", toggle = true, needs = Enabled, why = OFF },
            "Icon", "The icon's style, side and crop.", {
            { key = "iconStyle", label = "Icon Style", choice = ICON_STYLE, needs = Enabled, why = OFF },
            { key = "iconSide", label = "Icon Side", choice = ICON_SIDE, needs = Enabled, why = OFF,
              help = "Before the Bar puts it outside the bar, touching its left end." },
            { key = "iconZoom", label = "Icon Crop", slider = ICON_ZOOM_RANGE, unit = "%", needs = Enabled,
              why = OFF, help = "How much of the icon's edge is cut off, so the frame in it does not show." },
            { key = "iconGap", label = "Icon Gap", slider = PAD_RANGE, unit = "px", needs = Enabled, why = OFF,
              help = "The room between the icon and the name. None before the bar." } }),
        { key = "iconSize", label = "Icon Size", slider = ICON_SIZE_RANGE, unit = "px", needs = Enabled, why = OFF,
          help = "Zero fits the icon to the row, as tall as the bar when it stands before it." },
        Under({ key = "showRanks", label = "Rank Numbers", toggle = true, needs = Enabled, why = OFF },
            "Rank Text", "The rank's size switch, font and color.",
            Join(TextRows("Rank", "rank", "Off: the usual size."), ColorRow("rankColor"))),
        SizeRow("Rank", "rank", "rankSize", TEXT_RANGE),
        Under(SettingsRow("nameColor", "Name Settings", "The names' color. Their size, font and class colors "
                .. "are behind the cog."),
            "Name Settings", "The name's size, font and color.", {
            { key = "fontSize", label = "Name Size", slider = TEXT_RANGE, needs = Enabled, why = OFF,
              help = "The names' size. The figures follow it unless they have a size of their own." },
            { key = "nameOwnFont", label = "Own Name Font", toggle = true, needs = Enabled, why = OFF,
              help = "Off: the font and outline of Window." },
            { key = "nameFont", label = "Name Font", font = true, needs = OwnFonted("name"), why = OFF_OWN_FONT },
            { key = "nameOutline", label = "Name Outline", choice = OUTLINE, needs = OwnFonted("name"),
              why = OFF_OWN_FONT },
            { key = "nameClassColor", label = "Class Colored Names", toggle = true, needs = Enabled, why = OFF,
              help = "Each name in its class's color, in place of the name's color." } }),
        { key = "nameFormat", label = "Name Format", choice = NAME_FORMAT, needs = Enabled, why = OFF,
          help = "How a player's name is written. In combat the game hides other players' names, so those "
              .. "are found by class and left whole when two players share one." },
        { key = "youLabel", label = "Call Me You", toggle = true, needs = Enabled, why = OFF,
          help = "Your own row says You in place of your name." },
        { key = "nameMaxLetters", label = "Name Length", slider = LETTERS_RANGE, needs = Enabled, why = OFF,
          help = "Cuts a name to this many letters, with ... after it. Zero leaves names whole." },
        { key = "textPad", label = "Text Padding", slider = PAD_RANGE, unit = "px", needs = Enabled, why = OFF,
          help = "The room at the ends of a row, before the first text and after the last." },
        { key = "colGap", label = "Column Gap", slider = PAD_RANGE, unit = "px", needs = Enabled, why = OFF,
          help = "The room between the columns of figures." }
    ),
})

-- ---- the figures: which columns, in what order, how they are written

page:Card({
    id = "figures", name = "Figures", order = 50,
    help = "The columns of figures, in what order, and how numbers, shares and per-second figures are written.",
    summary = FiguresSummary,
    rows = Join(
        Group("Columns"),
        { key = "showTotal", label = "Show Total", toggle = true, needs = Enabled, why = OFF },
        { key = "showRate", label = "Show Per Second", toggle = true, needs = Enabled, why = OFF,
          help = "Damage, healing and absorbs only." },
        { key = "showDivider", label = "Column Divider", toggle = true, needs = BothFigures, why = OFF_BOTH,
          help = "Writes the total and the per-second figure as one text with a bar between: 117 | 23." },
        { key = "showPercent", label = "Show Percent", toggle = true, needs = Enabled, why = OFF,
          help = "Each one's share of what the list totals, in a column of its own. The game hides the figures "
              .. "in combat, so it fills in after the fight." },
        { key = "columnOrder", label = "Column Order", choice = COLUMN_ORDER, needs = Enabled, why = OFF,
          help = "Which way round the figures go, and where the share stands. As the Game Has It leads with "
              .. "the per-second figure in the DPS and HPS lists." },
        Under(SettingsRow("valueColor", "Figure Settings", "The figures' color. Their size, font and class "
                .. "colors are behind the cog."),
            "Figure Settings", "The figures' size, font and color.", Join(
            SizeRow("Figure", "value", "valueFontSize", TEXT_RANGE),
            TextRows("Figure", "value", "Off: the same size as the names."),
            { key = "valueClassColor", label = "Class Colored Figures", toggle = true, needs = Enabled, why = OFF,
              help = "Each amount in its class's color, in place of the figures' color." })),
        Group("Writing"),
        { key = "numberUnits", label = "Number Format", choice = NUMBER_UNITS, needs = Enabled, why = OFF,
          help = "How big numbers are written. Ten-thousands groups by ten-thousands and hundred-millions." },
        HiddenWhen({ key = "numberDecimals", label = "Decimals", slider = DECIMALS_RANGE, needs = Enabled,
            why = OFF }, NotAbbreviating),
        { key = "percentDecimals", label = "Percent Decimals", slider = PERCENT_DECIMALS_RANGE, needs = Enabled,
          why = OFF },
        { key = "rateSuffix", label = "Per-Second Suffix", toggle = true, needs = Enabled, why = OFF,
          help = "Writes the per-second figure with /s after it." }
    ),
})

-- ---- the title bar, and the lines under it

page:Card({
    id = "header", name = "Title Bar", order = 60,
    help = "The title, the fight time and the buttons, and the column titles and summary line under the bar.",
    summary = HeaderSummary,
    rows = Join(
        Group("Title"),
        { key = "titleText", label = "Title Shows", choice = TITLE_TEXT, needs = Enabled, why = OFF,
          help = "The list's name, the name the game gave the fight, or both. A fight with no name yet "
              .. "shows the list's." },
        Under(SettingsRow("titleColor", "Title Settings", "The title's color. Its size, font and place are "
                .. "behind the cog."),
            "Title Settings", "The title's size, font, color and place.", Join(
            SizeRow("Title", "title", "titleSize", TITLE_RANGE),
            TextRows("Title", "title", "Off: the usual size."),
            { key = "titleX", label = "Title X Offset", slider = OFFSET_X_RANGE, unit = "px", needs = Enabled,
              why = OFF, help = "Moves the title right, or left below zero. The second list's title moves "
                  .. "with it." },
            { key = "titleY", label = "Title Y Offset", slider = OFFSET_Y_RANGE, unit = "px", needs = Enabled,
              why = OFF, help = "Moves the title up, or down below zero." })),
        { key = "showButtons", label = "Show Buttons", toggle = true, needs = Enabled, why = OFF,
          help = "The session button and the ... menu at the right of the bar. Off: right-click the bar "
              .. "for the same menu." },
        { key = "headerAlpha", label = "Title Bar Opacity", slider = BACKGROUND_RANGE, unit = "%",
          scale = TO_FRACTION, needs = Enabled, why = OFF,
          help = "At zero the title bar and the line under it are not drawn, only its words." },
        ColorRow("headerColor"),
        Group("Fight Time"),
        Under({ key = "showTime", label = "Show Fight Time", toggle = true, needs = Enabled, why = OFF,
            help = "How long the shown session has run, when there is room beside the title." },
            "Fight Time", "Where the time sits, and its size switch, font and color.", Join(
            { key = "timeBrackets", label = "Time in Brackets", toggle = true, needs = On("showTime"),
              why = OFF_TIME, help = "Writes the time as (0:05)." },
            { key = "timeByTitle", label = "Time Next to Title", toggle = true, needs = On("showTime"),
              why = OFF_TIME, help = "Puts the time right after the title, in place of beside the buttons." },
            { key = "timeX", label = "Time X Offset", slider = OFFSET_X_RANGE, unit = "px", needs = On("showTime"),
              why = OFF_TIME, help = "Moves the time right, or left below zero, from where it sits." },
            { key = "timeY", label = "Time Y Offset", slider = OFFSET_Y_RANGE, unit = "px", needs = On("showTime"),
              why = OFF_TIME, help = "Moves the time up, or down below zero." },
            TextRows("Time", "time", "Off: the usual size."),
            ColorRow("timeColor"))),
        SizeRow("Time", "time", "timeSize", TITLE_RANGE),
        Group("Under the Bar"),
        Under({ key = "showColumnHeaders", label = "Column Titles", toggle = true, needs = Enabled, why = OFF,
            help = "A line of titles above the rows: Name and what each column shows." },
            "Column Title Text", "The column titles' size switch, font and color.",
            Join(TextRows("Column Title", "head", "Off: the usual size."), ColorRow("columnColor"))),
        SizeRow("Column Title", "head", "headSize", TEXT_RANGE),
        Under({ key = "showSummary", label = "Summary Line", toggle = true, needs = Enabled, why = OFF,
            help = "Under the title bar: the session, its total, the raid's per-second figure once the fight "
                .. "is over, and your rank." },
            "Summary Line", "What the line says, and its size switch, font and color.", Join(
            { key = "summaryName", label = "Session Name", toggle = true, needs = On("showSummary"),
              why = OFF_SUMMARY },
            { key = "summaryTotal", label = "Total", toggle = true, needs = On("showSummary"), why = OFF_SUMMARY },
            { key = "summaryRate", label = "Raid Per Second", toggle = true, needs = On("showSummary"),
              why = OFF_SUMMARY, help = "The raid's figure per second, once the fight is over." },
            { key = "summaryRank", label = "Your Rank", toggle = true, needs = On("showSummary"),
              why = OFF_SUMMARY },
            TextRows("Summary", "summary", "Off: the usual size."),
            ColorRow("summaryColor"))),
        SizeRow("Summary", "summary", "summarySize", TEXT_RANGE)
    ),
})

-- ---- what hovering a row shows, and what a report sends

page:Card({
    id = "hover", name = "Spells and Reports", order = 70,
    help = "The spells behind a row, on hover or in the window, and what Report To sends.",
    summary = HoverSummary,
    rows = Join(
        Under({ key = "breakdown", label = "Spell Breakdown", toggle = true, needs = Enabled, why = OFF,
            help = "Hover a row to see its spells, or click it to see them in the window, and click again to go "
                .. "back. In combat only your own row and rows the game lets through show spells." },
            "Spell Panel", "How many it lists, how wide it is, and which side it opens on.", {
            { key = "panelLines", label = "Spells Shown", slider = PANEL_LINES_RANGE, needs = Enabled, why = OFF,
              help = "How many spells the panel lists, the biggest first." },
            { key = "targetLines", label = "Enemies Shown", slider = TARGET_LINES_RANGE, needs = Enabled,
              why = OFF, help = "How many enemies it lists under the spells, in the panel and in a player's "
                  .. "breakdown." },
            { key = "panelWidth", label = "Panel Width", slider = PANEL_WIDTH_RANGE, unit = "px", needs = Enabled,
              why = OFF },
            { key = "panelScale", label = "Panel Scale", slider = PANEL_SCALE_RANGE, unit = "%",
              scale = TO_FRACTION, needs = Enabled, why = OFF },
            { key = "panelAlpha", label = "Panel Opacity", slider = BACKGROUND_RANGE, unit = "%",
              scale = TO_FRACTION, needs = Enabled, why = OFF },
            { key = "panelSide", label = "Panel Side", choice = PANEL_SIDE, needs = Enabled, why = OFF,
              help = "By the window's side on the screen puts it on the side that has room." } }),
        { key = "reportLines", label = "Report Lines", slider = REPORT_RANGE, needs = Enabled, why = OFF,
          help = "How many rows Report To sends, out of combat only. Reset has a key binding under Naowh Forever." }
    ),
})

-- ---- the fights kept, and when the data is cleared

page:Card({
    id = "data", name = "Fights and Data", order = 80,
    help = "The fights kept, when the game's figures are cleared, and the way back to the defaults.",
    summary = DataSummary,
    rows = {
        Group("Fights"),
        { key = "keepFights", label = "Fights Kept", slider = KEEP_RANGE, needs = Enabled, why = OFF },
        { key = "fightsShown", label = "Past Fights Offered", slider = FIGHTS_RANGE, needs = Enabled, why = OFF,
          help = "How many of the game's past fights the Session menu lists, the newest first." },
        { label = "Fight History", buttonText = "Open", needs = Enabled, why = OFF,
          button = function() DM.HistoryWindow.Toggle() end,
          help = "The fights kept: when, which, how long, and the per-second figures." },
        { label = "Clear Fight History", buttonText = "Clear", needs = Enabled, why = OFF,
          button = function() DM.HistoryWindow.AskClear() end },
        Group("Reset"),
        { key = "resetOn", label = "Reset on", choice = RESET_ON, needs = Enabled, why = OFF,
          help = "Clears the data when you enter a new instance, or asks first. A login or a reload does "
              .. "not count, and nothing is cleared in combat." },
        { key = "resetOnLeave", label = "Reset When You Leave a Group", toggle = true, needs = Enabled, why = OFF },
        { key = "overallOutOfCombat", label = "Show Overall Out of Combat", toggle = true, needs = Enabled,
          why = OFF, help = "Each window shows Overall when combat ends and the current fight when it begins." },
        { label = "Reset Data Now", buttonText = "Reset", needs = Enabled, why = OFF,
          button = function() ns.Confirm(C.TEXT_RESET_ASK, DM.Reset) end,
          help = "Clears the game's damage meter data, as Reset Data in the window's menu does." },
        { label = "Reset All Settings", buttonText = "Reset",
          button = function()
              ns.Confirm(C.TEXT_RESET_SETTINGS_ASK, function()
                  DM.ResetSettings()
                  if ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
              end)
          end,
          help = "Puts every setting back to its default. Where the windows are, the looks you kept and the "
              .. "fights kept stay." },
    },
})

-- ---- looks: clean, kept by name, copied to the other windows, and shared as text

-- Saving, sharing and applying looks: the buttons, then a row to apply and one to delete for each look kept.
local function LookRows()
    local rows = {
        Group("Clean"),
        { label = "Clean Look", buttonText = "Apply", needs = Enabled, why = OFF,
          button = function() ns.Confirm(TEXT_CLEAN_ASK, ApplyCleanLook) end,
          help = "Only the title and the bars: no column titles, buttons, rank numbers, backgrounds or "
              .. "border, the time in brackets after the title, and a bar between the figures." },
        Group("Save and Share"),
        { label = "Save This Look", buttonText = "Save", needs = Enabled, why = OFF,
          button = function()
              ns.PromptText(TEXT_LOOK_NAME, "", C.LOOK_NAME_MAX, function(name)
                  local ok, why = DM.SaveLook(name)
                  if not ok then
                      ns.Print(why == "full" and TEXT_LOOKS_FULL or TEXT_LOOK_NO_NAME)
                  elseif ns.UI.RefreshPage then
                      ns.UI:RefreshPage(true)
                  end
              end)
          end,
          help = "Keeps the look the meter has now, under a name, for every character." },
        { label = "Copy to Other Windows", buttonText = "Copy", needs = Enabled, why = OFF,
          button = function() DM.CopyLookToWindows() end,
          help = "Gives the second and third windows this look as their own." },
        { label = "Export This Look", buttonText = "Export", needs = Enabled, why = OFF,
          button = function() ns.ShowCopyBox(TEXT_LOOK_EXPORT, DM.EncodeLook(DM.CaptureLook())) end,
          help = "Shows the look as a line of text to copy and give to someone." },
        { label = "Import a Look", buttonText = "Import", needs = Enabled, why = OFF,
          button = function()
              ns.PromptText(TEXT_LOOK_IMPORT, "", C.LOOK_TEXT_MAX, function(text)
                  local look = DM.DecodeLook(text)
                  if not look then
                      ns.Print(TEXT_LOOK_BAD)
                  else
                      DM.ApplyLook(look)
                      if ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
                  end
              end)
          end,
          help = "Takes a look somebody exported. Only the look's settings are set." },
    }
    local names = DM.LookNames()
    if #names > 0 then rows[#rows + 1] = Group("Saved Looks") end
    for _, name in ipairs(names) do
        rows[#rows + 1] = { label = name, buttonText = "Apply", needs = Enabled, why = OFF,
            button = function()
                DM.ApplyLook(DM.SavedLook(name))
                if ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
            end }
        rows[#rows + 1] = { label = "Delete " .. name, buttonText = "Delete", needs = Enabled, why = OFF,
            button = function()
                ns.Confirm(TEXT_LOOK_DELETE:format(name), function()
                    DM.DeleteLook(name)
                    if ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
                end)
            end }
    end
    return rows
end

page:Card({
    id = "looks", name = "Looks", order = 90,
    help = "Clean it up, keep the way the meter looks under a name, copy it to the other windows or share it.",
    summary = LooksSummary,
    rows = LookRows,
})

-- ---- a second and a third window: their own list, session and size, and a look of their own

-- The rows of a window's own look: the settings of the Bars, Row, Figures, Window and Title Bar cards that
-- it may have of its own, under its number. columns says which of the two sets: the bars and the window, or
-- the columns.
local function OwnLookRows(index, columns)
    local specs = {
        barHeight = { label = "Row Height", slider = BAR_RANGE },
        barSpacing = { label = "Row Spacing", slider = SPACING_RANGE },
        barAlpha = { label = "Bar Opacity", slider = BAR_ALPHA_RANGE, unit = "%", scale = TO_FRACTION },
        growUp = { label = "Grow Upward", toggle = true },
        fontSize = { label = "Name Size", slider = TEXT_RANGE },
        showIcons = { label = "Icons", toggle = true },
        showRanks = { label = "Rank Numbers", toggle = true },
        backgroundAlpha = { label = "Window Opacity", slider = BACKGROUND_RANGE, unit = "%", scale = TO_FRACTION },
        headerAlpha = { label = "Title Bar Opacity", slider = BACKGROUND_RANGE, unit = "%", scale = TO_FRACTION },
        showBorder = { label = "Border", toggle = true },
        barColor = { label = "Bar Color", choice = BAR_COLOR },
        showTotal = { label = "Show Total", toggle = true },
        showRate = { label = "Show Per Second", toggle = true },
        showPercent = { label = "Show Percent", toggle = true },
        showDivider = { label = "Column Divider", toggle = true },
        columnOrder = { label = "Column Order", choice = COLUMN_ORDER },
        showColumnHeaders = { label = "Column Titles", toggle = true },
    }
    local rows = {}
    for _, key in ipairs(C.OWN_LOOK_ORDER) do
        if (C.OWN_LOOK_COLUMNS[key] == true) == columns then
            local row = { key = key .. index, needs = On("ownLook" .. index), why = OFF_OWN_LOOK }
            for field, value in pairs(specs[key]) do row[field] = value end
            rows[#rows + 1] = row
        end
    end
    return rows
end

-- A window's card: its list, session and size, then a look of its own behind a switch, and the columns of
-- its own behind the column order. spec is the card's id, name and order, and the window's index.
local function WindowCard(spec)
    local index = spec.index
    local own = "ownLook" .. index
    local columns = OwnLookRows(index, true)
    local columnOrder = "columnOrder" .. index
    local owner, rest = nil, {}
    for _, row in ipairs(columns) do
        if row.key == columnOrder then owner = row else rest[#rest + 1] = row end
    end
    spec.switch = "window" .. index
    spec.help = "A window of its own, with its own list, session and size, and a look of its own if you want one."
    spec.summary = WindowNSummary(index)
    spec.rows = Join(
        { key = DM.Key("mode", index), label = "Show", choice = MODE, needs = Enabled, why = OFF },
        { key = DM.Key("lower", index), label = "Second List", choice = LOWER, needs = Enabled, why = OFF },
        { key = DM.Key("session", index), label = "Session", choice = SESSION, needs = Enabled, why = OFF },
        { key = DM.Key("width", index), label = "Width", slider = WIDTH_RANGE, needs = Enabled, why = OFF },
        { key = DM.Key("height", index), label = "Height", slider = HEIGHT_RANGE, needs = Enabled, why = OFF },
        { key = DM.Key("scale", index), label = "Scale", slider = SCALE_RANGE, unit = "%", scale = TO_FRACTION,
          needs = Enabled, why = OFF },
        Under({ key = own, label = "Own Look", toggle = true, needs = Enabled, why = OFF,
            help = "Off: it looks as the first window does. On: the rows, opacities and more behind the "
                .. "cog are its own, starting as the first window's." },
            "Look of This Window", "Its own row height, text size, opacities and more.",
            OwnLookRows(index, false)),
        Under(owner, "Columns of This Window", "What it shows in a row.", rest)
    )
    page:Card(spec)
end

WindowCard({ index = 2, id = "window2", name = "Second Window", order = 100 })
WindowCard({ index = 3, id = "window3", name = "Third Window", order = 110 })

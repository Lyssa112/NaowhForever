-- Constants.lua: the sizes and names the Damage Meter's files share.
local ns = _G.NaowhForever

-- Each list: its game type, whether it has a per-second figure, and the titles of its two columns. The
-- DPS and HPS lists are the game's own, sorted by the per-second figure, which then leads.
local MODES = {
    { key = "damage", label = "Damage Done", type = "DamageDone", rate = true, total = "Damage", perSecond = "DPS",
      targets = true },
    { key = "dps", label = "DPS", type = "Dps", rate = true, rateFirst = true, total = "Damage", perSecond = "DPS",
      targets = true },
    { key = "healing", label = "Healing Done", type = "HealingDone", rate = true, total = "Healing", perSecond = "HPS" },
    { key = "hps", label = "HPS", type = "Hps", rate = true, rateFirst = true, total = "Healing", perSecond = "HPS" },
    { key = "taken", label = "Damage Taken", type = "DamageTaken", rate = true, total = "Taken", perSecond = "DTPS" },
    { key = "avoidable", label = "Avoidable Damage", type = "AvoidableDamageTaken", rate = true, total = "Avoidable",
      perSecond = "Per Sec" },
    { key = "absorbs", label = "Absorbs", type = "Absorbs", rate = true, total = "Absorbed", perSecond = "Per Sec" },
    { key = "interrupts", label = "Interrupts", type = "Interrupts", rate = false, total = "Interrupts" },
    { key = "dispels", label = "Dispels", type = "Dispels", rate = false, total = "Dispels" },
    { key = "deaths", label = "Deaths", type = "Deaths", rate = false, spells = false, percent = false,
      total = "Deaths" },
}

local byKey, labels, order = {}, {}, {}
for i, mode in ipairs(MODES) do
    byKey[mode.key] = mode
    labels[mode.key] = mode.label
    order[i] = mode.key
end

ns.DamageMeter.C = {
    PAGE = "Damage Meter/Settings",
    MIN_WIDTH = 170, MIN_HEIGHT = 70, MAX_WIDTH = 1000, MAX_HEIGHT = 1000, MIN_SCALE = 50, MAX_SCALE = 200,
    MIN_BAR = 12, MAX_BAR = 40, MAX_SPACING = 12, MIN_FONT = 8, MAX_FONT = 20,
    INSET = 6, HEADER = 26, TITLE_X = 8,
    ROUND = 0.5,
    DEFAULT_MODE = "damage",
    BREAKDOWN_LINES = 8, TARGET_LINES = 5, REPORT_MAX = 10, FIGHTS_MAX = 10,
    TEXT_SPELLS_COMBAT = "Spells show after combat.", TEXT_SPELLS_NONE = "No spell data.",
    TEXT_RESET_ASK = "Reset the damage meter data?",
    ENEMY_COLOR = { r = 0.78, g = 0.2, b = 0.2 },
    COLUMN_HEAD = 16, SUMMARY_H = 16, LOWER_STRIP = 20, LOWER_GAP = 4,
    MIN_TITLE = 8, MAX_TITLE = 20, MAX_NAME_LETTERS = 24, MAX_PERCENT_DECIMALS = 2, MAX_ICON = 40, MAX_PAD = 20,
    NUMBER_UNITS = { game = "Game Default", latin = "K, M, B", asian = "Ten-thousands", full = "Full Numbers" },
    NUMBER_UNITS_ORDER = { "game", "latin", "asian", "full" },
    NUMBER_DECIMALS_MAX = 2, MAX_HIDE_DELAY = 60, MIN_KEEP = 5, MAX_KEEP = 100, MIN_TILE = 16, MAX_TILE = 512,
    -- The choice of Image that stands for the picture typed in Custom Image.
    OWN_PICTURE = "@own",
    -- Pictures the shared media lists that are not backgrounds worth putting behind a meter, and its own
    -- None, which the page already has.
    HIDDEN_BACKGROUNDS = { ["Solid"] = true, ["Blizzard Tooltip"] = true, ["Blizzard Out of Control"] = true,
        ["Blizzard Low Health"] = true, ["None"] = true },
    BAR_COLORS = { class = "Class Colors", accent = "Theme Accent", custom = "Custom Color" },
    BAR_COLORS_ORDER = { "class", "accent", "custom" },
    RESET_ON = { never = "Never", instance = "Entering an Instance", ask = "Ask When Entering an Instance" },
    RESET_ON_ORDER = { "never", "instance", "ask" },
    ICON_SIDES = { left = "Left", right = "Right" },
    ICON_SIDES_ORDER = { "left", "right" },
    -- The look settings a second or third window may have of its own (barHeight2, barHeight3, ...).
    OWN_LOOK_ORDER = { "barHeight", "barSpacing", "barAlpha", "growUp", "fontSize", "showIcons", "showRanks",
        "showColumnHeaders", "showPercent", "backgroundAlpha", "headerAlpha", "showBorder", "barColor" },
    BAR_SCALES = { top = "Top Player", total = "List Total" },
    BAR_SCALES_ORDER = { "top", "total" },
    OWN_BAR_STYLES = { bar = "Same as Bar Color", class = "Class Color", custom = "Custom Color" },
    OWN_BAR_STYLES_ORDER = { "bar", "class", "custom" },
    EDGE_STYLES = { accent = "Theme Accent", class = "Class Color", custom = "Custom Color" },
    EDGE_STYLES_ORDER = { "accent", "class", "custom" },
    NAME_FORMATS = { full = "Full Name", first = "First Name", last = "Last Name", initials = "Initials",
        firstInitial = "First Name and Initial" },
    NAME_FORMATS_ORDER = { "full", "first", "last", "initials", "firstInitial" },
    -- What the title says, and how far the title and the fight time may be moved from where they sit.
    TITLE_TEXTS = { list = "List Name", fight = "Fight Name", both = "List and Fight" },
    TITLE_TEXTS_ORDER = { "list", "fight", "both" },
    MAX_OFFSET_X = 300, MAX_OFFSET_Y = 20,
    -- Ten-thousand grouping: the glyphs of thousand, ten-thousand and hundred-million, by locale (UTF-8).
    ASIAN_GLYPHS = {
        zhCN = { "\229\141\131", "\228\184\135", "\228\186\191" },
        zhTW = { "\229\141\131", "\232\144\172", "\229\132\132" },
        koKR = { "\236\178\156", "\235\167\140", "\236\150\181" },
    },
    -- The colors of a window, in the order the page shows them. Each is a setting that is false until a
    -- color is picked, and then follows the theme's token.
    COLORS = {
        { key = "barCustomColor", label = "Custom Bar Color", group = "Bars", token = "accent" },
        { key = "ownBarColor", label = "Your Bar Color", group = "Bars", token = "accent" },
        { key = "edgeColor", label = "Edge Color", group = "Bars", token = "accent" },
        { key = "trackColor", label = "Bar Track", group = "Bars", token = "panel" },
        { key = "nameColor", label = "Names", group = "Text", token = "fg" },
        { key = "valueColor", label = "Amounts", group = "Text", token = "fg" },
        { key = "rankColor", label = "Ranks", group = "Text", token = "muted" },
        { key = "columnColor", label = "Column Titles", group = "Text", token = "muted" },
        { key = "titleColor", label = "Title", group = "Text", token = "fg" },
        { key = "timeColor", label = "Fight Time", group = "Text", token = "muted" },
        { key = "summaryColor", label = "Summary Line", group = "Text", token = "muted" },
        { key = "windowColor", label = "Window Background", group = "Window", token = "bg" },
        { key = "headerColor", label = "Title Bar", group = "Window", token = "panel" },
        { key = "borderColor", label = "Border", group = "Window", token = "line" },
    },
    OWN_LOOK = {},
    MODES = MODES, MODE_BY_KEY = byKey, MODE_LABELS = labels, MODE_ORDER = order,
    SESSION_LABELS = { current = "Current", overall = "Overall" },
    SESSION_ORDER = { "current", "overall" },
    GRIP_UP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
    GRIP_HIGHLIGHT = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight",
    GRIP_DOWN = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down",
}

for _, key in ipairs(ns.DamageMeter.C.OWN_LOOK_ORDER) do ns.DamageMeter.C.OWN_LOOK[key] = true end

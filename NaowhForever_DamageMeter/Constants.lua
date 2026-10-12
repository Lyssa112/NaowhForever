-- Constants.lua: the sizes and names the Damage Meter's files share.
local ns = _G.NaowhForever

-- Each list: its game type, whether it has a per-second figure, and the titles of its two columns. The
-- DPS and HPS lists are the game's own, sorted by the per-second figure, which then leads.
local MODES = {
    { key = "damage", label = "Damage Done", type = "DamageDone", rate = true, total = "Damage", perSecond = "DPS" },
    { key = "dps", label = "DPS", type = "Dps", rate = true, rateFirst = true, total = "Damage", perSecond = "DPS" },
    { key = "healing", label = "Healing Done", type = "HealingDone", rate = true, total = "Healing", perSecond = "HPS" },
    { key = "hps", label = "HPS", type = "Hps", rate = true, rateFirst = true, total = "Healing", perSecond = "HPS" },
    { key = "taken", label = "Damage Taken", type = "DamageTaken", rate = true, total = "Taken", perSecond = "DTPS" },
    { key = "avoidable", label = "Avoidable Damage", type = "AvoidableDamageTaken", rate = true, total = "Avoidable",
      perSecond = "Per Sec" },
    { key = "absorbs", label = "Absorbs", type = "Absorbs", rate = true, total = "Absorbed", perSecond = "Per Sec" },
    { key = "interrupts", label = "Interrupts", type = "Interrupts", rate = false, total = "Interrupts" },
    { key = "dispels", label = "Dispels", type = "Dispels", rate = false, total = "Dispels" },
    { key = "deaths", label = "Deaths", type = "Deaths", rate = false, spells = false, total = "Deaths" },
}

local byKey, labels, order = {}, {}, {}
for i, mode in ipairs(MODES) do
    byKey[mode.key] = mode
    labels[mode.key] = mode.label
    order[i] = mode.key
end

ns.DamageMeter.C = {
    PAGE = "Damage Meter/Settings",
    MIN_WIDTH = 170, MIN_HEIGHT = 70, MAX_WIDTH = 600, MAX_HEIGHT = 700,
    MIN_BAR = 12, MAX_BAR = 40, MAX_SPACING = 12, MIN_FONT = 8, MAX_FONT = 20,
    INSET = 6, HEADER = 26,
    ROUND = 0.5,
    DEFAULT_MODE = "damage",
    BREAKDOWN_LINES = 8, REPORT_MAX = 10, FIGHTS_MAX = 10,
    TIME_WIDTH = 48, COLUMN_HEAD = 16, COL_GAP = 6,
    NUMBER_UNITS = { game = "Game Default", latin = "K, M, B", asian = "Ten-thousands", full = "Full Numbers" },
    NUMBER_UNITS_ORDER = { "game", "latin", "asian", "full" },
    NUMBER_DECIMALS_MAX = 2,
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
        { key = "trackColor", label = "Bar Background", group = "Bars", token = "panel" },
        { key = "edgeColor", label = "Your Row Edge", group = "Bars", token = "accent" },
        { key = "nameColor", label = "Names", group = "Text", token = "fg" },
        { key = "valueColor", label = "Amounts", group = "Text", token = "fg" },
        { key = "rankColor", label = "Ranks", group = "Text", token = "muted" },
        { key = "columnColor", label = "Column Titles", group = "Text", token = "muted" },
        { key = "titleColor", label = "Title", group = "Text", token = "fg" },
        { key = "timeColor", label = "Fight Time", group = "Text", token = "muted" },
        { key = "windowColor", label = "Window Background", group = "Window", token = "bg" },
        { key = "headerColor", label = "Title Bar", group = "Window", token = "panel" },
        { key = "borderColor", label = "Border", group = "Window", token = "line" },
    },
    MODES = MODES, MODE_BY_KEY = byKey, MODE_LABELS = labels, MODE_ORDER = order,
    SESSION_LABELS = { current = "Current", overall = "Overall" },
    SESSION_ORDER = { "current", "overall" },
    GRIP_UP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
    GRIP_HIGHLIGHT = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight",
    GRIP_DOWN = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down",
}

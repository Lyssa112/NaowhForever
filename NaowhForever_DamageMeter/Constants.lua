-- Constants.lua: the sizes and names the Damage Meter's files share.
local ns = _G.NaowhForever

local MODES = {
    { key = "damage", label = "Damage Done", type = "DamageDone", rate = true },
    { key = "healing", label = "Healing Done", type = "HealingDone", rate = true },
    { key = "taken", label = "Damage Taken", type = "DamageTaken", rate = true },
    { key = "absorbs", label = "Absorbs", type = "Absorbs", rate = true },
    { key = "interrupts", label = "Interrupts", type = "Interrupts", rate = false },
    { key = "dispels", label = "Dispels", type = "Dispels", rate = false },
    { key = "deaths", label = "Deaths", type = "Deaths", rate = false, spells = false },
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
    MODES = MODES, MODE_BY_KEY = byKey, MODE_LABELS = labels, MODE_ORDER = order,
    SESSION_LABELS = { current = "Current", overall = "Overall" },
    SESSION_ORDER = { "current", "overall" },
    GRIP_UP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
    GRIP_HIGHLIGHT = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight",
    GRIP_DOWN = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down",
}

-- Icons.lua: RestedXP's step icons in Naowh's own, in a line or a filled style, put in its icon table as it loads.
local ns = _G.NaowhForever
local Safe = ns.RXPSafe
local Dig, Quiet = Safe.Dig, Safe.Quiet

local RXP_ADDON = "RXPGuides"
local ART = "Interface\\AddOns\\NaowhForever\\Core\\Integrations\\RestedXP\\Media\\Icons\\"
local EXTENSION = ".tga"
local ESCAPE = "|T%s%s\\%s%s:0:0:0:0:%d:%d:0:%d:0:%d:%d:%d:%d|t"
local TEXELS = 64
local CHANNEL_MAX, ROUND = 255, 0.5
local NONE = ""
local OTHER = "other"
local COLORS_KEY = "rxpIconColors"
local STYLES = { line = true, filled = true }
local ART_PATTERN = ART:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
local LOOK_PATTERN = "|T" .. ART_PATTERN .. "(%a+)\\(%a+)%.tga"

local INLINE = {
    ["interface/worldmap/chatbubble_64grey.blp"] = "gossip",
    ["interface/cursor/crosshair/interact.blp"] = "interact",
}
local INLINE_PATTERN = "|T([^|:]+):%d+|t"

local COLORS = {
    { name = "quest", label = "Quest Icon Color", token = "accent",
      glyphs = { "accept", "daily", "turnin", "dailyturnin", "complete", "abandon", "gossip", "interact" },
      tip = "The quest and gossip icons." },
    { name = "travel", label = "Travel Icon Color", token = "accentSoft",
      glyphs = { "goto", "fly", "fp", "home", "deathskip", "marker", "arrow", "clicknext" },
      tip = "The go to, flight and home icons." },
    { name = OTHER, label = "Other Icon Color", token = "accent", glyphs = {}, tip = "The rest of the icons." },
}

local COLOR_BY_NAME, GROUP_OF = {}, {}
for _, color in ipairs(COLORS) do
    COLOR_BY_NAME[color.name] = color
    for _, glyph in ipairs(color.glyphs) do GROUP_OF[glyph] = color.name end
end

local GLYPHS = {
    accept = "accept", acceptmultiple = "accept",
    daily = "daily",
    turnin = "turnin", turninmultiple = "turnin",
    dailyturnin = "dailyturnin",
    collect = "collect", collectmultiple = "collect",
    equip = "equip",
    combat = "combat",
    complete = "complete", scenario = "complete",
    vendor = "vendor",
    reputation = "reputation",
    fly = "fly",
    fp = "fp",
    ["goto"] = "goto", groundgoto = "goto", flygoto = "goto", explore = "goto",
    gossip = "gossip",
    hs = "home", home = "home",
    trainer = "trainer", train = "trainer",
    arrow = "arrow",
    marker = "marker",
    xp = "xp", xpto60 = "xp",
    stable = "stable",
    tame = "tame",
    abandon = "abandon",
    error = "error",
    link = "link",
    clock = "clock",
    engrave = "engrave",
    clicknext = "clicknext",
    deathskip = "deathskip",
}

function ns.RXPIconStyle()
    local style = ns.AccountSettings().rxpIconStyle
    return STYLES[style] and style or NONE
end

function ns.SetRXPIconStyle(style)
    ns.AccountSettings().rxpIconStyle = STYLES[style] and style or nil
end

function ns.RXPIconGlyphs() return GLYPHS end

function ns.RXPIconInline() return INLINE end

function ns.RXPIconPath(style, glyph)
    return ART .. style .. "\\" .. glyph .. EXTENSION
end

function ns.RXPIconColors() return COLORS end

local function Rgb(color)
    if type(color) == "table" and type(color.r) == "number" and type(color.g) == "number"
            and type(color.b) == "number" then
        return color.r, color.g, color.b
    end
end

function ns.RXPIconColor(name)
    local color = COLOR_BY_NAME[name] or COLOR_BY_NAME[OTHER]
    local r, g, b = Rgb(Dig(ns.AccountSettings(), COLORS_KEY, color.name))
    if r then return r, g, b end
    r, g, b = Rgb(ns.THEME[color.token])
    if r then return r, g, b end
    return 1, 1, 1
end

local function Redraw()
    if type(ns.RXPWindowRefresh) == "function" then ns.RXPWindowRefresh() end
end

function ns.SetRXPIconColor(name, r, g, b)
    if not COLOR_BY_NAME[name] then return end
    local all = ns.AccountSettings()[COLORS_KEY]
    if type(all) ~= "table" then
        all = {}
        ns.AccountSettings()[COLORS_KEY] = all
    end
    if type(r) == "number" and type(g) == "number" and type(b) == "number" then
        all[name] = { r = r, g = g, b = b }
    else
        all[name] = nil
    end
    if next(all) == nil then ns.AccountSettings()[COLORS_KEY] = nil end
    Redraw()
end

function ns.ResetRXPIconColors()
    ns.AccountSettings()[COLORS_KEY] = nil
    Redraw()
end

function ns.RXPIconLook(text)
    if type(text) ~= "string" then return end
    local style, glyph = text:match(LOOK_PATTERN)
    if not (STYLES[style] and glyph) then return end
    return ns.RXPIconPath(style, glyph), ns.RXPIconColor(GROUP_OF[glyph])
end

local function Channel(value)
    return math.floor(value * CHANNEL_MAX + ROUND)
end

local function Escape(style, glyph)
    local r, g, b = ns.RXPIconColor(GROUP_OF[glyph])
    return ESCAPE:format(ART, style, glyph, EXTENSION, TEXELS, TEXELS, TEXELS, TEXELS, Channel(r), Channel(g),
        Channel(b))
end

function ns.RXPIconText(text)
    local style = ns.RXPIconStyle()
    if style == NONE or type(text) ~= "string" then return text end
    return (text:gsub(INLINE_PATTERN, function(path)
        local key = path:lower():gsub("\\", "/")
        local glyph = INLINE[key]
        if glyph then return Escape(style, glyph) end
    end))
end

function ns.RXPIconsApply()
    local style = ns.RXPIconStyle()
    local icons = Dig(_G.RXP, "icons")
    if style == NONE or type(icons) ~= "table" then return end
    for key, glyph in pairs(GLYPHS) do
        if type(icons[key]) == "string" then icons[key] = Escape(style, glyph) end
    end
end

local function OnEvent(self, _, name)
    if name == ns.MODULE_KEY then
        if ns.RXPIconStyle() == NONE or not ns.RXPThemesAvailable() then
            self:UnregisterAllEvents()
        elseif C_AddOns.IsAddOnLoaded(RXP_ADDON) then
            self:UnregisterAllEvents()
            Quiet("Icons", ns.RXPIconsApply)
        end
    elseif name == RXP_ADDON then
        self:UnregisterAllEvents()
        Quiet("Icons", ns.RXPIconsApply)
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", OnEvent)

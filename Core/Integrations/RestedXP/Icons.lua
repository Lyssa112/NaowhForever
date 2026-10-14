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
local ACCENT = "accent"
local STYLES = { line = true, filled = true }
local ART_PATTERN = ART:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
local LOOK_PATTERN = "|T" .. ART_PATTERN .. "(%a+)\\(%a+)%.tga"

local INLINE = {
    ["interface/worldmap/chatbubble_64grey.blp"] = "gossip",
    ["interface/cursor/crosshair/interact.blp"] = "interact",
}
local INLINE_PATTERN = "|T([^|:]+):%d+|t"

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
    if type(ns.RXPWindowEnabled) == "function" and not ns.RXPWindowEnabled() then return NONE end
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

local function Rgb(color)
    if type(color) == "table" and type(color.r) == "number" and type(color.g) == "number"
            and type(color.b) == "number" then
        return color.r, color.g, color.b
    end
end

function ns.RXPIconColor()
    if type(ns.RXPWindowColor) == "function" then
        local ok, r, g, b = pcall(ns.RXPWindowColor, ACCENT)
        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then return r, g, b end
    end
    local r, g, b = Rgb(ns.THEME.accent)
    if r then return r, g, b end
    return 1, 1, 1
end

function ns.RXPIconLook(text)
    if type(text) ~= "string" then return end
    local style, glyph = text:match(LOOK_PATTERN)
    if not (STYLES[style] and glyph) then return end
    return ns.RXPIconPath(style, glyph), ns.RXPIconColor()
end

local function Channel(value)
    return math.floor(value * CHANNEL_MAX + ROUND)
end

local function Escape(style, glyph)
    local r, g, b = ns.RXPIconColor()
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

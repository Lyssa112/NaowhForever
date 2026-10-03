-------------------------------------------------------------------------------
--  NaowhForever_RXPThemes.lua -- NaowhUI and the eight Naowh themes in RestedXP Guides.
--  RestedXP reads a global RXPGuides_Themes table once, while it starts, and registers every
--  theme in it (its own RXPGuides_Themes addon fills the same table). Colors only: the frames
--  and icons are RestedXP's own, already installed. Off unless Settings > COLORS turns it on.
-------------------------------------------------------------------------------
local ns = _G.NaowhForever

local RXP_ADDON = "RXPGuides"
-- RestedXP's neutral grey frames and icons, which sit under any theme color.
local TEXTURES = "Interface/AddOns/RXPGuides/Textures/DarkMode/"
local AUTHOR = "Naowh Forever"
local NAME_PREFIX = "NaowhForever:"
local DEFAULT_KEY, DEFAULT_NAME = "default", "NaowhUI"
-- The frame highlight is RestedXP's soft edge color, not a solid one, as in its other themes.
local HIGHLIGHT_ALPHA = 0.5

--- Whether RestedXP Guides is installed, which is when the toggle is offered.
---@return boolean
function ns.RXPThemesAvailable()
    return C_AddOns.DoesAddOnExist(RXP_ADDON) == true
end

---@return boolean
function ns.RXPThemesEnabled()
    return ns.AccountSettings().rxpThemes == true
end

--- Saved for this computer; read when the addon loads, so a change takes effect after a reload.
---@param on boolean
function ns.SetRXPThemes(on)
    ns.AccountSettings().rxpThemes = on and true or nil
end

local function Rgba(c, alpha)
    return { c.r, c.g, c.b, alpha }
end

local function Hex(c)
    return ("%02x%02x%02x"):format(math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5),
        math.floor(c.b * 255 + 0.5))
end

-- One RestedXP theme from a Naowh palette: a preset's key, or "" for the default theme. The
-- palettes are the ones the Theme row previews, so the player's own theme never leaks in.
local function Theme(key)
    local palette = ns.ThemePalette(key)
    local c = {}
    for i, token in ipairs(ns.THEME_EDITABLE) do c[token] = palette[i] end
    local preset = ns.THEME_PRESETS[key]
    return {
        name = NAME_PREFIX .. (key == "" and DEFAULT_KEY or key),
        displayName = preset and preset.name or DEFAULT_NAME,
        author = AUTHOR,
        background = Rgba(c.bg, 1),
        bottomFrameBG = Rgba(c.panel, 1),
        bottomFrameHighlight = Rgba(c.accent, HIGHLIGHT_ALPHA),
        mapPins = Rgba(c.accent, 1),
        tooltip = "|cff" .. Hex(c.accent),
        textColor = { c.fg.r, c.fg.g, c.fg.b },
        texturePath = TEXTURES,
        -- Left out, RestedXP would fill these in from its blue theme, borders included.
        edges = { edge = TEXTURES .. "rxp-borders", guideName = TEXTURES .. "rxp-borders" },
    }
end

-- Adds the nine themes to the table RestedXP imports from, next to whatever other addons put there.
local function Register()
    local list = _G.RXPGuides_Themes
    if type(list) ~= "table" then
        list = {}
        _G.RXPGuides_Themes = list
    end
    local keys = { "" }
    for _, key in ipairs(ns.THEME_PRESET_ORDER) do keys[#keys + 1] = key end
    for _, key in ipairs(keys) do
        local theme = Theme(key)
        list[theme.name] = theme
    end
end

-- Once, when this addon has loaded: that is after the saved toggle can be read and before RestedXP
-- starts (it loads after Naowh Forever, and imports in its own ADDON_LOADED).
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, _, name)
    if name ~= ns.MODULE_KEY then return end
    self:UnregisterAllEvents()
    if ns.RXPThemesEnabled() and ns.RXPThemesAvailable() then Register() end
end)

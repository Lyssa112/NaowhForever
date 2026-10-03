-------------------------------------------------------------------------------
--  NaowhForever_RXPThemes.lua -- NaowhUI and the eight Naowh themes in RestedXP Guides.
--  RestedXP reads a global RXPGuides_Themes table once, while it starts, and registers every
--  theme in it (its own RXPGuides_Themes addon fills the same table). Colors only: the frames
--  and icons are RestedXP's own, already installed. Its waypoint arrow, which it cannot color,
--  is drawn in the theme's Accent while one of these themes is the active one: by a layer over
--  its image, or by Naowh's own arrow image, as the player picks. Off unless Settings > COLORS
--  turns it on.
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
        -- One step lighter than the addon's own windows: these frames sit over the game world, where
        -- the darkest colors read as black.
        background = Rgba(c.panel, 1),
        bottomFrameBG = Rgba(c.line, 1),
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

-- RestedXP draws its waypoint arrow, the frame RXPG_ARROW, from an image its theme gives it (a dark
-- one) and has no setting to color it. While one of our themes is the active one, the arrow is drawn
-- the way the player picked (Settings > COLORS, RestedXP Arrow):
--   layer  a layer of ours over the arrow: the Accent, added to the arrow's own colors and clipped
--          to its shape (the arrow's own image is the mask). RestedXP's image is not touched;
--   image  Naowh's own white arrow (Media/rxp_arrow.tga) in the Accent, in place of RestedXP's;
--   off    RestedXP's own arrow, as it is.
-- With any other RestedXP theme the arrow is left alone.
local ARROW_IMAGE = "Interface\\AddOns\\NaowhForever\\Media\\rxp_arrow.tga"
local ARROW_STYLES = { layer = true, image = true, off = true }
local DEFAULT_ARROW = "layer"
-- The layer's Accent is lighter at the top and deeper at the bottom, as if lit from above, and not at
-- full strength, so the dark arrow underneath still shades it; flat, it reads as a neon shape.
local TOP_TOWARD_WHITE = 0.22   -- how far the top goes from the Accent toward white
local BOTTOM_SHARE = 0.72       -- how much of the Accent the bottom keeps
local LAYER_STRENGTH = 0.9

local layer     -- our layer over the arrow, built the first time it is needed
local swapped   -- the arrow shows our image in place of RestedXP's
local tinted    -- the arrow's texture carries our tint
local rxpImage  -- the image RestedXP last set, to hand back

--- How the arrow is drawn while one of the Naowh themes is active: "layer" (the default), "image"
--- or "off".
---@return string
function ns.RXPArrowStyle()
    local style = ns.AccountSettings().rxpArrow
    return ARROW_STYLES[style] and style or DEFAULT_ARROW
end

local function BuildLayer(arrow)
    local texture = arrow.texture
    if type(texture.SetRotation) ~= "function" then return nil end
    local f = CreateFrame("Frame", nil, arrow)
    f:SetAllPoints()
    f:SetFrameLevel(arrow:GetFrameLevel() + 1)
    f.color = f:CreateTexture(nil, "OVERLAY")
    f.color:SetAllPoints()
    f.color:SetBlendMode("ADD")
    f.mask = f:CreateMaskTexture()
    f.mask:SetAllPoints()
    f.color:AddMaskTexture(f.mask)
    hooksecurefunc(texture, "SetRotation", function(_, radians) f.mask:SetRotation(radians) end)
    return f
end

-- The active RestedXP theme, when it is one of ours.
local function ActiveTheme()
    local rxp = _G.RXP
    local theme = rxp and rxp.activeTheme
    if type(theme) == "table" and type(theme.name) == "string" and type(theme.mapPins) == "table"
            and theme.name:find(NAME_PREFIX, 1, true) == 1 then
        return theme
    end
end

local function PaintLayer(arrow, c)
    layer = layer or BuildLayer(arrow)
    if not layer then return end
    layer.color:SetColorTexture(1, 1, 1, 1)
    layer.color:SetGradient("VERTICAL",
        CreateColor(c[1] * BOTTOM_SHARE, c[2] * BOTTOM_SHARE, c[3] * BOTTOM_SHARE, LAYER_STRENGTH),
        CreateColor(c[1] + (1 - c[1]) * TOP_TOWARD_WHITE, c[2] + (1 - c[2]) * TOP_TOWARD_WHITE,
            c[3] + (1 - c[3]) * TOP_TOWARD_WHITE, LAYER_STRENGTH))
    layer.mask:SetTexture(arrow.texture:GetTexture(), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    layer.mask:SetRotation(arrow.orientation or 0)
    layer:Show()
end

local function Paint()
    local arrow = _G.RXPG_ARROW
    local texture = arrow and arrow.texture
    if not texture then return end
    local theme = ActiveTheme()
    local style = theme and ns.RXPArrowStyle() or "off"
    if style == "layer" then
        PaintLayer(arrow, theme.mapPins)
    elseif layer then
        layer:Hide()
    end
    if style == "image" then
        local c = theme.mapPins
        texture:SetTexture(ARROW_IMAGE)
        texture:SetVertexColor(c[1], c[2], c[3], 1)
        swapped, tinted = true, true
    else
        if swapped then
            if rxpImage then texture:SetTexture(rxpImage) end
            swapped = false
        end
        if tinted then
            texture:SetVertexColor(1, 1, 1, 1)
            tinted = false
        end
    end
end

-- RestedXP has just set the arrow's image again, because its theme loaded or changed: that is its
-- own image now, and the arrow is drawn once more.
local function OnRxpUpdate()
    local arrow = _G.RXPG_ARROW
    swapped = false
    rxpImage = arrow and arrow.texture and arrow.texture:GetTexture()
    Paint()
end

--- Saved for this computer, and applied at once when the arrow is already hooked.
---@param style string "layer", "image" or "off"
function ns.SetRXPArrowStyle(style)
    ns.AccountSettings().rxpArrow = (ARROW_STYLES[style] and style ~= DEFAULT_ARROW) and style or nil
    Paint()
end

local function HookArrow()
    local arrow = _G.RXPG_ARROW
    if not (arrow and arrow.texture and type(arrow.UpdateVisuals) == "function") then return end
    hooksecurefunc(arrow, "UpdateVisuals", OnRxpUpdate)
    OnRxpUpdate()
end

-- When this addon has loaded: that is after the saved toggle can be read and before RestedXP
-- starts (it loads after Naowh Forever, and imports in its own ADDON_LOADED). The arrow exists once
-- every addon has loaded, so that part waits for PLAYER_LOGIN, and only while the themes are on.
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ns.MODULE_KEY then return end
        self:UnregisterEvent("ADDON_LOADED")
        if ns.RXPThemesEnabled() and ns.RXPThemesAvailable() then
            Register()
            self:RegisterEvent("PLAYER_LOGIN")
        end
    else
        self:UnregisterAllEvents()
        HookArrow()
    end
end)

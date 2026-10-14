-- Themes.lua: the Naowh themes in RestedXP Guides, and the hooks that style it.
local ns = _G.NaowhForever
local F = ns.FEATURES.account

local RXP_ADDON = "RXPGuides"
local NAME_PREFIX = "NaowhForever:"
local AUTHOR = "Naowh Forever"
local DEFAULT_KEY, DEFAULT_NAME = "default", "Naowh"
local CURRENT_KEY, CURRENT_NAME = "current", ns.L("Naowh (current)")
local RXP_DEFAULT = "Default"
local TEXT_RXP_DEFAULT = ns.L("RestedXP (default)")
local TEXT_CURRENT = ns.L("Current Theme")
local TEXT_SETUP = ns.L("Naowh turned on RestedXP's new interface for this character. Reload UI to use it.")

local RXP_TEXTURES = "Interface/AddOns/RXPGuides/Textures/"
local TEXTURES = RXP_TEXTURES .. "DarkMode/"
local WHITE = "Interface/BUTTONS/WHITE8X8"

local HIGHLIGHT_ALPHA = 0.5
local RULE_ALPHA = 0.6
local CHROME_ALPHA = 0.7
local RULE_DROP = 3
local RULE_H = 1

local MEDIA = ns.MEDIA
local RXP_ART = "Interface\\AddOns\\NaowhForever\\Core\\Integrations\\RestedXP\\Media\\"
local FRAME = RXP_ART .. "rxp_frame.tga"
local ARROW_IMAGES = {
    kite = { [false] = RXP_ART .. "rxp_arrow.tga", [true] = RXP_ART .. "rxp_arrow_glow.tga" },
    wide = { [false] = RXP_ART .. "rxp_arrow_wide.tga", [true] = RXP_ART .. "rxp_arrow_wide_glow.tga" },
}
local DEFAULT_SHAPE = "kite"
local ARROW_STYLES = { layer = true, image = true, off = true }
local DEFAULT_ARROW = "layer"
local SIZE_MIN, SIZE_MAX, SIZE_STEP, DEFAULT_SIZE = 60, 200, 5, 90
local GLOW_FILL = 0.76
local GAP_MIN, GAP_MAX, DEFAULT_GAP = 0, 20, 4
local TEXT_MIN, TEXT_MAX, DEFAULT_TEXT = 8, 24, 13
local TEXT_WIDTH = 240
local GAP_STEP = 1
local PERCENT = 100
local ARROW_DISTANCE = "%d yd"
local CHANNEL_MAX = 255
local ROUND = 0.5
local TOP_TOWARD_WHITE = 0.22
local BOTTOM_SHARE = 0.72
local LAYER_STRENGTH = 0.9
local DIAGONAL = math.sqrt(2)

local BARS = { "GuideName", "Footer" }
local COG = MEDIA .. "cog.tga"
local GRIP = RXP_ART .. "rxp_grip.tga"
local ARROWS = { "ScrollUpButton", "ScrollDownButton" }
local ARROW_PARTS = { "Normal", "Highlight", "Pushed", "Disabled" }
local THUMB_W, THUMB_H = 8, 40

local PaintArrow
local ApplyFont
local StartArrow
local boot

function ns.RXPThemesAvailable()
    return C_AddOns.DoesAddOnExist(RXP_ADDON) == true
end

function ns.RXPThemesEnabled()
    if type(ns.RXPWindowEnabled) == "function" and ns.RXPWindowEnabled() then return false end
    local on = ns.AccountSettings().rxpThemes
    if on == nil then return F.rxpThemes end
    return on == true
end

function ns.RXPSetUpEnabled()
    local on = ns.AccountSettings().rxpSetup
    if on == nil then return F.rxpSetup end
    return on == true
end

function ns.SetRXPSetUp(on)
    ns.AccountSettings().rxpSetup = on and true or nil
end

function ns.RXPArrowKept()
    local account = ns.AccountSettings()
    if account.rxpArrowOn == nil then account.rxpArrowOn = ns.RXPArrowEnabled() end
end

function ns.SetRXPThemes(on)
    ns.RXPArrowKept()
    ns.AccountSettings().rxpThemes = on and true or nil
    if on and type(ns.SetRXPWindow) == "function" and ns.RXPWindowEnabled() then ns.SetRXPWindow(false) end
end

function ns.RXPArrowEnabled()
    local account = ns.AccountSettings()
    local on = account.rxpArrowOn
    if on == nil then return account.rxpThemes == true or F.rxpArrowOn end
    return on == true
end

function ns.SetRXPArrow(on)
    ns.AccountSettings().rxpArrowOn = on and true or false
    if on and StartArrow then StartArrow() end
    if PaintArrow then PaintArrow() end
end

function ns.RXPThemeChoices()
    local values = { [""] = TEXT_RXP_DEFAULT, [CURRENT_KEY] = TEXT_CURRENT, [DEFAULT_KEY] = DEFAULT_NAME }
    local order = { "", CURRENT_KEY, DEFAULT_KEY }
    for _, key in ipairs(ns.THEME_PRESET_ORDER) do
        values[key] = ns.THEME_PRESETS[key].name
        order[#order + 1] = key
    end
    return values, order
end

local function ThemeId(key)
    return key == CURRENT_KEY or key == DEFAULT_KEY or (type(key) == "string" and ns.THEME_PRESETS[key] ~= nil)
end

local function Has(object, method)
    return type(object) == "table" and type(object[method]) == "function"
end

local function Dig(t, ...)
    for i = 1, select("#", ...) do
        if type(t) ~= "table" then return nil end
        t = t[select(i, ...)]
    end
    return t
end

local function Ours(name)
    return type(name) == "string" and name:find(NAME_PREFIX, 1, true) == 1
end

ns.RXPFailures = {}

local function Quiet(name, fn, ...)
    local ok, problem = pcall(fn, ...)
    if not ok then ns.RXPFailures[name] = tostring(problem) end
    return ok
end

local function Guarded(name, fn)
    return function(...) Quiet(name, fn, ...) end
end

local function Run(name, fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then return result end
    ns.RXPFailures[name] = tostring(result)
end

ns.RXPSafe = { Has = Has, Dig = Dig, Quiet = Quiet, Guarded = Guarded, Run = Run }

local function Visible(region)
    if Has(region, "IsVisible") then return region:IsVisible() == true end
    if Has(region, "IsShown") then return region:IsShown() == true end
    return true
end

local function Reload()
    local rxp = _G.RXP
    if not Has(rxp, "ReloadTheme") then return end
    if InCombatLockdown() then
        boot:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    Quiet("ReloadTheme", rxp.ReloadTheme, rxp)
end

function ns.RXPThemesReady()
    local rxp = _G.RXP
    return type(Dig(rxp, "settings", "profile")) == "table" and Has(rxp, "ReloadTheme")
        and type(Dig(rxp, "themes", NAME_PREFIX .. DEFAULT_KEY)) == "table"
end

function ns.RXPThemeChoice()
    local name = Dig(_G.RXP, "settings", "profile", "activeTheme")
    local key = Ours(name) and name:sub(#NAME_PREFIX + 1)
    return ThemeId(key) and Dig(_G.RXP, "themes", name) and key or ""
end

function ns.SetRXPThemeChoice(key)
    local rxp = _G.RXP
    local profile = Dig(rxp, "settings", "profile")
    if type(profile) ~= "table" or not Has(rxp, "ReloadTheme") then return end
    local name
    if key == "" then
        name = Ours(profile.activeTheme) and RXP_DEFAULT
    elseif ThemeId(key) and Dig(rxp, "themes", NAME_PREFIX .. key) then
        name = NAME_PREFIX .. key
    end
    if not name or profile.activeTheme == name then return end
    profile.activeTheme = name
    if not profile.enableThemeLiveReload then return "reload" end
    Reload()
end

local function Wanted(key)
    return ns.AccountSettings()[key] ~= false
end

local function Want(key, on)
    if on then ns.AccountSettings()[key] = nil else ns.AccountSettings()[key] = false end
end

function ns.RXPFontEnabled() return Wanted("rxpFont") end

function ns.SetRXPFont(on)
    Want("rxpFont", on)
end

function ns.RXPArrowFontEnabled() return Wanted("rxpArrowFont") end

function ns.SetRXPArrowFont(on)
    Want("rxpArrowFont", on)
    if ApplyFont then ApplyFont() end
end

function ns.RXPTextColorEnabled() return Wanted("rxpTextColor") end

function ns.SetRXPTextColor(on) Want("rxpTextColor", on) end

function ns.RXPArrowStyle()
    local style = ns.AccountSettings().rxpArrow
    return ARROW_STYLES[style] and style or DEFAULT_ARROW
end

function ns.SetRXPArrowStyle(style)
    ns.AccountSettings().rxpArrow = (ARROW_STYLES[style] and style ~= DEFAULT_ARROW) and style or nil
    PaintArrow()
end

function ns.RXPArrowShape()
    local shape = ns.AccountSettings().rxpArrowShape
    return ARROW_IMAGES[shape] and shape or DEFAULT_SHAPE
end

function ns.SetRXPArrowShape(shape)
    ns.AccountSettings().rxpArrowShape = (ARROW_IMAGES[shape] and shape ~= DEFAULT_SHAPE) and shape or nil
    PaintArrow()
end

function ns.RXPArrowSizeRange() return SIZE_MIN, SIZE_MAX, SIZE_STEP end

local function Snap(value, lo, hi, step)
    return math.min(hi, math.max(lo, math.floor(value / step + ROUND) * step))
end

function ns.RXPArrowSize()
    local size = tonumber(ns.AccountSettings().rxpArrowSize)
    return size and Snap(size, SIZE_MIN, SIZE_MAX, SIZE_STEP) or DEFAULT_SIZE
end

function ns.SetRXPArrowSize(size)
    size = tonumber(size)
    size = size and Snap(size, SIZE_MIN, SIZE_MAX, SIZE_STEP)
    ns.AccountSettings().rxpArrowSize = size ~= DEFAULT_SIZE and size or nil
    PaintArrow()
end

function ns.RXPArrowGapRange() return GAP_MIN, GAP_MAX end

function ns.RXPArrowGap()
    local gap = tonumber(ns.AccountSettings().rxpArrowGap)
    return gap and Snap(gap, GAP_MIN, GAP_MAX, GAP_STEP) or DEFAULT_GAP
end

function ns.SetRXPArrowGap(gap)
    gap = tonumber(gap)
    gap = gap and Snap(gap, GAP_MIN, GAP_MAX, GAP_STEP)
    ns.AccountSettings().rxpArrowGap = gap ~= DEFAULT_GAP and gap or nil
    PaintArrow()
end

function ns.RXPArrowTextSizeRange() return TEXT_MIN, TEXT_MAX, 1 end

function ns.RXPArrowTextSize()
    local size = tonumber(ns.AccountSettings().rxpArrowTextSize)
    return size and Snap(size, TEXT_MIN, TEXT_MAX, 1) or DEFAULT_TEXT
end

function ns.SetRXPArrowTextSize(size)
    size = tonumber(size)
    size = size and Snap(size, TEXT_MIN, TEXT_MAX, 1)
    ns.AccountSettings().rxpArrowTextSize = size ~= DEFAULT_TEXT and size or nil
    if ApplyFont then ApplyFont() end
end

function ns.RXPArrowTextEnabled() return Wanted("rxpArrowText") end

function ns.SetRXPArrowText(on)
    Want("rxpArrowText", on)
    PaintArrow()
end

function ns.RXPArrowObjective()
    return ns.AccountSettings().rxpArrowObjective == true
end

function ns.RXPArrowGlow()
    return ns.AccountSettings().rxpArrowGlow == true
end

function ns.SetRXPArrowGlow(on)
    ns.AccountSettings().rxpArrowGlow = on and true or nil
    PaintArrow()
end

local function Rgba(c, alpha)
    return { c.r, c.g, c.b, alpha }
end

local function Hex(c)
    return ("%02x%02x%02x"):format(math.floor(c.r * CHANNEL_MAX + ROUND),
        math.floor(c.g * CHANNEL_MAX + ROUND), math.floor(c.b * CHANNEL_MAX + ROUND))
end

local function LivePalette()
    local palette = {}
    for i, token in ipairs(ns.THEME_EDITABLE) do palette[i] = ns.THEME[token] end
    return palette
end

local function Theme(id, displayName, palette)
    local c = {}
    for i, token in ipairs(ns.THEME_EDITABLE) do c[token] = palette[i] end
    return {
        name = NAME_PREFIX .. id,
        displayName = displayName,
        author = AUTHOR,
        background = Rgba(c.panel, 1),
        bottomFrameBG = Rgba(c.panel, 1),
        bottomFrameHighlight = Rgba(c.accent, HIGHLIGHT_ALPHA),
        dividerColor = Rgba(c.line, RULE_ALPHA),
        chromeColor = Rgba(c.muted, CHROME_ALPHA),
        mapPins = Rgba(c.accent, 1),
        tooltip = "|cff" .. Hex(c.accent),
        textColor = ns.RXPTextColorEnabled() and { c.fg.r, c.fg.g, c.fg.b } or nil,
        font = ns.RXPFontEnabled() and ns.AddonFontPath() or nil,
        texturePath = TEXTURES,
        bgTextures = { edge = WHITE, bottom = WHITE, guideName = WHITE },
        edges = { edge = FRAME, guideName = FRAME },
    }
end

local late

local function Add(themes, id, displayName, palette)
    local theme = Theme(id, displayName, palette)
    themes[theme.name] = theme
end

local function Register()
    local themes = {}
    Add(themes, DEFAULT_KEY, DEFAULT_NAME, ns.ThemePalette(""))
    for _, key in ipairs(ns.THEME_PRESET_ORDER) do
        Add(themes, key, ns.THEME_PRESETS[key].name, ns.ThemePalette(key))
    end
    Add(themes, CURRENT_KEY, CURRENT_NAME, LivePalette())
    local rxp = _G.RXP
    if Has(rxp, "RegisterTheme") and type(rxp.activeTheme) == "table" then
        late = true
        for _, theme in pairs(themes) do Quiet("RegisterTheme", rxp.RegisterTheme, rxp, theme) end
        return
    end
    local list = _G.RXPGuides_Themes
    if type(list) ~= "table" then
        list = {}
        _G.RXPGuides_Themes = list
    end
    for name, theme in pairs(themes) do list[name] = theme end
end

local function Resume()
    local rxp = _G.RXP
    local saved = Dig(rxp, "themes", Dig(rxp, "settings", "profile", "activeTheme"))
    if type(saved) == "table" and Ours(saved.name) and saved ~= rxp.activeTheme then Reload() end
end

local function ActiveTheme()
    local rxp = _G.RXP
    local theme = rxp and rxp.activeTheme
    if type(theme) == "table" and type(theme.name) == "string" and type(theme.mapPins) == "table"
            and theme.name:find(NAME_PREFIX, 1, true) == 1 then
        return theme
    end
end

local layer
local swapped
local fitted
local rxpImage
local textHome
local textHidden
local hookedArrow

local function BuildLayer(arrow)
    local texture = arrow.texture
    if not (Has(texture, "SetRotation") and Has(arrow, "GetFrameLevel") and Has(arrow, "GetSize")) then return nil end
    local f = CreateFrame("Frame", nil, arrow)
    f:SetAllPoints()
    f:SetFrameLevel(arrow:GetFrameLevel() + 1)
    f.color = f:CreateTexture(nil, "OVERLAY")
    f.color:SetPoint("CENTER")
    f.color:SetBlendMode("ADD")
    f.mask = f:CreateMaskTexture()
    f.mask:SetAllPoints()
    f.color:AddMaskTexture(f.mask)
    hooksecurefunc(texture, "SetRotation", function(_, radians) f.mask:SetRotation(radians) end)
    local function Cover(self, w, h)
        local side = math.max(w, h) * DIAGONAL
        self.color:SetSize(side, side)
    end
    f:SetScript("OnSizeChanged", Guarded("LayerSize", Cover))
    Cover(f, arrow:GetSize())
    return f
end

local function ShowLayer(arrow, c)
    if not Has(arrow.texture, "GetTexture") then return end
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

local function MoveText(arrow, down)
    local text = arrow.text
    if not (Has(text, "GetPoint") and Has(text, "SetPoint")) then return end
    textHome = textHome or { text:GetPoint() }
    local point, relativeTo, relativePoint, x, y = unpack(textHome)
    if point == nil or type(x) ~= "number" or type(y) ~= "number" then
        textHome = nil
        return
    end
    text:SetPoint(point, relativeTo, relativePoint, x, y - down)
end

local function Fit(arrow, texture, scale)
    if not (Has(texture, "ClearAllPoints") and Has(texture, "SetPoint") and Has(arrow, "GetSize")) then return end
    local w, h = arrow:GetSize()
    local dx, dy = w * (scale - 1) / 2, h * (scale - 1) / 2
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", arrow, "TOPLEFT", -dx, dy)
    texture:SetPoint("BOTTOMRIGHT", arrow, "BOTTOMRIGHT", dx, -dy)
    MoveText(arrow, math.max(0, dy) + ns.RXPArrowGap())
end

local function ShowImage(arrow, texture, c)
    if not (Has(texture, "SetTexture") and Has(texture, "SetVertexColor")) then return end
    texture:SetTexture(ARROW_IMAGES[ns.RXPArrowShape()][ns.RXPArrowGlow()])
    texture:SetVertexColor(c[1], c[2], c[3], 1)
    fitted = ns.RXPArrowSize() / PERCENT / (ns.RXPArrowGlow() and GLOW_FILL or 1)
    Fit(arrow, texture, fitted)
    swapped = true
end

local function HandBack(arrow, texture)
    if fitted then
        fitted = nil
        if Has(texture, "SetAllPoints") then
            texture:ClearAllPoints()
            texture:SetAllPoints()
        end
        if textHome and Has(arrow.text, "SetPoint") then arrow.text:SetPoint(unpack(textHome)) end
        if Has(texture, "SetVertexColor") then texture:SetVertexColor(1, 1, 1, 1) end
    end
    if swapped then
        if rxpImage and Has(texture, "SetTexture") then texture:SetTexture(rxpImage) end
        swapped = false
    end
end

local function PaintText(arrow, on)
    local text = arrow.text
    if not (Has(text, "Hide") and Has(text, "Show")) then return end
    local hide = on and not ns.RXPArrowTextEnabled()
    if hide and not textHidden then
        text:Hide()
    elseif textHidden and not hide then
        text:Show()
    end
    textHidden = hide
    if Has(text, "SetWidth") then text:SetWidth(on and ns.RXPArrowObjective() and TEXT_WIDTH or 0) end
end

local objectiveHooked, composing

local function Words(source)
    if type(source) ~= "table" or source.completed or source.skip or source.hideTooltip then return nil end
    local raw = source.text ~= " " and source.text or nil
    raw = raw or source.tooltipText or source.rawtext
    if type(raw) == "string" and raw ~= "" then return raw end
end

local function Source(element)
    local sources = { element }
    if type(element.parent) == "table" then table.insert(sources, 1, element.parent) end
    local list = Dig(element, "step", "elements")
    if type(list) == "table" then
        local at = 0
        for i, other in ipairs(list) do
            if other == element then
                at = i
                break
            end
        end
        for i = at + 1, #list do sources[#sources + 1] = list[i] end
        for i = 1, at - 1 do sources[#sources + 1] = list[i] end
    end
    for _, source in ipairs(sources) do
        if type(source) == "table" and Words(source) then return source end
    end
end

local function Plain(text)
    text = text:gsub("|T[^|]*|t", "")
    text = text:gsub("|A[^|]*|a", "")
    text = text:gsub("^%s+", "")
    return text ~= "" and text or nil
end

local function Objective(arrow)
    local element = arrow.element
    if type(element) ~= "table" then return nil end
    local source = Source(element)
    local rxp = _G.RXP
    if not source then return type(element.title) == "string" and Plain(element.title) or nil end
    local shown = Dig(source, "frame", "text")
    local text = Has(shown, "GetText") and shown:GetText()
    if type(text) ~= "string" or text == "" or text == " " then
        local raw = Words(source)
        text = raw
        if Has(rxp, "ReplaceNpcIds") then
            local ok, replaced = pcall(rxp.ReplaceNpcIds, raw, source)
            if ok and type(replaced) == "string" then text = replaced end
        end
    end
    return Plain(text)
end

local keeping, fontHooked

local function KeepFont(text, restore)
    if keeping or not (Has(text, "GetFont") and Has(text, "SetFont")) or not ns.RXPArrowEnabled() then return end
    local path, size, flags = text:GetFont()
    local want = ns.RXPArrowFontEnabled() and ns.AddonFontPath() or restore and Dig(_G.RXP, "font") or path
    local wantSize = ns.RXPArrowTextSize()
    if type(want) ~= "string" or type(size) ~= "number" or path == want and size == wantSize then return end
    keeping = true
    local ok, problem = pcall(text.SetFont, text, want, wantSize, flags)
    keeping = false
    if not ok then error(problem, 0) end
end

local function HookFont()
    local text = Dig(_G.RXPG_ARROW, "text")
    if not Has(text, "SetFont") then return end
    if fontHooked ~= text then
        fontHooked = text
        hooksecurefunc(text, "SetFont", Guarded("ArrowFont", function() KeepFont(text) end))
    end
    KeepFont(text, true)
end

function ApplyFont()
    Quiet("ArrowFont", HookFont)
end

local function OnArrowText(text)
    if composing or not ns.RXPArrowEnabled() or not ns.RXPArrowObjective() or not ns.RXPArrowTextEnabled() then
        return
    end
    local arrow = _G.RXPG_ARROW
    if Dig(arrow, "text") ~= text or arrow.wrongContinent or type(arrow.distance) ~= "number" then return end
    local line = ARROW_DISTANCE:format(arrow.distance)
    local objective = Objective(arrow)
    composing = true
    local ok, problem = pcall(text.SetText, text, objective and (line .. "\n" .. objective) or line)
    composing = false
    if not ok then error(problem, 0) end
end

local function HookObjective()
    local text = Dig(_G.RXPG_ARROW, "text")
    if objectiveHooked == text or not Has(text, "SetText") then return end
    objectiveHooked = text
    hooksecurefunc(text, "SetText", Guarded("ArrowObjective", function() OnArrowText(text) end))
end

function ns.SetRXPArrowObjective(on)
    ns.AccountSettings().rxpArrowObjective = on and true or nil
    if on then Quiet("ArrowObjective", HookObjective) end
    local arrow = _G.RXPG_ARROW
    if type(arrow) == "table" then arrow.distance = nil end
    PaintArrow()
end

local function OwnArrowColor()
    if type(ns.RXPWindowEnabled) ~= "function" or not ns.RXPWindowEnabled() then return end
    if type(ns.RXPWindowOwnColors) ~= "function" or not ns.RXPWindowOwnColors() then return end
    local r, g, b = ns.RXPWindowColor("arrow")
    if type(r) == "number" and type(g) == "number" and type(b) == "number" then return { r, g, b, 1 } end
end

local function DrawArrow()
    local arrow = _G.RXPG_ARROW
    local texture = Dig(arrow, "texture")
    if type(texture) ~= "table" then return end
    local on = ns.RXPArrowEnabled()
    local theme = ActiveTheme()
    local color = OwnArrowColor() or (theme and theme.mapPins) or Rgba(ns.THEME.accent, 1)
    local style = on and ns.RXPArrowStyle() or "off"
    if style == "layer" then
        ShowLayer(arrow, color)
    elseif layer then
        layer:Hide()
    end
    if style == "image" then
        ShowImage(arrow, texture, color)
    else
        HandBack(arrow, texture)
    end
    PaintText(arrow, on)
end

function PaintArrow()
    Quiet("PaintArrow", DrawArrow)
end

function ns.RXPPaintArrow()
    PaintArrow()
end

local function OnRxpUpdate()
    local texture = Dig(_G.RXPG_ARROW, "texture")
    swapped = false
    rxpImage = Has(texture, "GetTexture") and texture:GetTexture() or nil
    PaintArrow()
end

local function OnArrowSize()
    if fitted then Fit(hookedArrow, hookedArrow.texture, fitted) end
end

local arrowStarted

local function HookArrow()
    local arrow = _G.RXPG_ARROW
    if type(Dig(arrow, "texture")) ~= "table" or not Has(arrow, "UpdateVisuals") or arrowStarted == arrow then return end
    arrowStarted = arrow
    hooksecurefunc(arrow, "UpdateVisuals", Guarded("UpdateVisuals", OnRxpUpdate))
    if ns.RXPArrowObjective() then Quiet("ArrowObjective", HookObjective) end
    ApplyFont()
    if Has(arrow, "HookScript") then
        hookedArrow = arrow
        arrow:HookScript("OnSizeChanged", Guarded("ArrowSize", OnArrowSize))
    end
    OnRxpUpdate()
end

function StartArrow()
    Quiet("HookArrow", HookArrow)
end

local faded = setmetatable({}, { __mode = "k" })

local function Banner(name)
    local banner = Dig(_G.RXPFrame, name, "bg")
    return type(banner) == "table" and banner or nil
end

local function PaintBars()
    local hide = ActiveTheme() ~= nil
    for _, name in ipairs(BARS) do
        local banner = Banner(name)
        if Has(banner, "SetAlpha") and (hide or faded[banner]) and Visible(banner) then
            banner:SetAlpha(hide and 0 or 1)
            faded[banner] = hide or nil
        end
    end
end

local function HookBars()
    for _, name in ipairs(BARS) do
        local banner = Banner(name)
        if Has(banner, "SetTexture") then hooksecurefunc(banner, "SetTexture", Guarded("Banners", PaintBars)) end
    end
    PaintBars()
end

local footerTinted, scrollTinted, gripOriginal, thumbSize

local function Skin(texture, path, color)
    if not Has(texture, "SetVertexColor") then return end
    if path and Has(texture, "SetTexture") then texture:SetTexture(path) end
    local r, g, b, a = 1, 1, 1, 1
    if color then r, g, b, a = color[1], color[2], color[3], color[4] or 1 end
    texture:SetVertexColor(r, g, b, a)
end

local function Normal(button)
    return Has(button, "GetNormalTexture") and button:GetNormalTexture() or nil
end

local function PaintThumb(thumb, color)
    if not (Has(thumb, "SetSize") and Has(thumb, "GetSize")) then return end
    if not thumbSize then
        local w, h = thumb:GetSize()
        if type(w) ~= "number" or type(h) ~= "number" then return end
        thumbSize = { w, h }
    end
    if color and Has(thumb, "SetColorTexture") then
        thumb:SetColorTexture(color[1], color[2], color[3], color[4])
        thumb:SetSize(THUMB_W, THUMB_H)
    else
        thumb:SetSize(thumbSize[1], thumbSize[2])
    end
end

local function PaintFooter(color)
    local frame = _G.RXPFrame
    local grip = Normal(Dig(frame, "Footer", "icon"))
    if Has(grip, "GetTexture") then gripOriginal = gripOriginal or grip:GetTexture() end
    Skin(Normal(Dig(frame, "Footer", "cog")), color and COG, color)
    Skin(grip, color and GRIP or gripOriginal, color)
end

local function PaintScrollBar(color)
    local bar = Dig(_G.RXPFrame, "ScrollFrame", "ScrollBar")
    PaintThumb(Has(bar, "GetThumbTexture") and bar:GetThumbTexture() or nil, color)
    for _, name in ipairs(ARROWS) do
        for _, part in ipairs(ARROW_PARTS) do
            local texture = Dig(bar, name, part)
            if Has(texture, "SetAlpha") then texture:SetAlpha(color and 0 or 1) end
        end
    end
end

local function PaintChrome()
    local theme = ActiveTheme()
    local color = theme and type(theme.chromeColor) == "table" and theme.chromeColor or nil
    local frame = _G.RXPFrame
    if (color or footerTinted) and Visible(Dig(frame, "Footer")) then
        footerTinted = color ~= nil
        PaintFooter(color)
    end
    if (color or scrollTinted) and Visible(Dig(frame, "ScrollFrame", "ScrollBar")) then
        scrollTinted = color ~= nil
        PaintScrollBar(color)
    end
end

local function HookChrome()
    local frame = _G.RXPFrame
    if Has(frame, "UpdateScrollBar") then hooksecurefunc(frame, "UpdateScrollBar", Guarded("Chrome", PaintChrome)) end
    PaintChrome()
end

local rules = setmetatable({}, { __mode = "k" })
local ruleTheme, ruleRows

local function PaintRules()
    local list = Dig(_G.RXPFrame, "ScrollChild", "framePool")
    if type(list) ~= "table" or not Visible(Dig(_G.RXPFrame, "ScrollChild")) then return end
    local theme = ActiveTheme()
    if theme == ruleTheme and #list == ruleRows then return end
    local color = theme and theme.dividerColor
    if type(color) ~= "table" then color = nil end
    for _, row in ipairs(list) do
        local rule = rules[row]
        if color and not rule and Has(row, "CreateTexture") then
            rule = row:CreateTexture(nil, "ARTWORK")
            rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, -RULE_DROP)
            rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -RULE_DROP)
            rule:SetHeight(RULE_H)
            rules[row] = rule
        end
        if rule and color then
            rule:SetColorTexture(color[1], color[2], color[3], color[4])
            rule:Show()
        elseif rule then
            rule:Hide()
        end
    end
    ruleTheme, ruleRows = theme, #list
end

local function HookRules()
    local rxp = _G.RXP
    if Has(rxp, "SetStep") then hooksecurefunc(rxp, "SetStep", Guarded("Rules", PaintRules)) end
    PaintRules()
end

local SHOWN = { {}, { "GuideName" }, { "Footer" }, { "ScrollChild" }, { "ScrollFrame", "ScrollBar" } }

local function PaintLegacy()
    Quiet("Banners", PaintBars)
    Quiet("Chrome", PaintChrome)
    Quiet("Rules", PaintRules)
end

local function HookShown()
    for _, path in ipairs(SHOWN) do
        local part = Dig(_G.RXPFrame, unpack(path))
        if Has(part, "HookScript") then part:HookScript("OnShow", Guarded("Shown", PaintLegacy)) end
    end
end

local function WindowWanted()
    return type(ns.RXPWindowEnabled) == "function" and ns.RXPWindowEnabled()
end

local ARROW_FRAME, SCREEN, MIDDLE, EDGE = "arrowFrame", "UIParent", "CENTER", "TOP"

local function InRestedXPsPlace(places)
    if type(places) ~= "table" then return true end
    if #places ~= 1 then return false end
    local p = places[1]
    return type(p) == "table" and p[1] == EDGE and p[2] == SCREEN and p[3] == EDGE and (p[4] or 0) == 0
        and (p[5] or 0) == 0
end

local function CenterArrow(rxp, profile)
    if type(profile.framePositions) ~= "table" then profile.framePositions = {} end
    if not InRestedXPsPlace(profile.framePositions[ARROW_FRAME]) then return end
    profile.framePositions[ARROW_FRAME] = { { MIDDLE, SCREEN, MIDDLE, 0, 0 } }
    local frame = Dig(rxp, ARROW_FRAME)
    if Has(frame, "ClearAllPoints") and Has(frame, "SetPoint") then
        frame:ClearAllPoints()
        frame:SetPoint(MIDDLE, SCREEN, MIDDLE, 0, 0)
    end
end

local function SetUp(force)
    local rxp = _G.RXP
    local profile = Dig(rxp, "settings", "profile")
    local guid = UnitGUID("player")
    if type(profile) ~= "table" or type(guid) ~= "string" then return end
    local account = ns.AccountSettings()
    if type(account.rxpSetUp) ~= "table" then account.rxpSetUp = {} end
    if account.rxpSetUp[guid] and not force then return end
    account.rxpSetUp[guid] = true
    CenterArrow(rxp, profile)
    local restart
    if WindowWanted() and not (profile.enableBetaFeatures and profile.enableV2Interface) then
        profile.enableBetaFeatures, profile.enableV2Interface = true, true
        restart = true
    end
    local current = NAME_PREFIX .. CURRENT_KEY
    local changed = not Ours(profile.activeTheme) and type(Dig(rxp, "themes", current)) == "table"
    if changed then
        profile.activeTheme = current
        if not restart then Reload() end
    end
    if restart then ns.ConfirmReload(TEXT_SETUP) end
    return restart and "reload" or (changed and "theme") or nil
end

function ns.RXPSetUpCharacter()
    return SetUp(true)
end

local function OnBootEvent(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ns.MODULE_KEY then return end
        self:UnregisterEvent("ADDON_LOADED")
        if ns.RXPThemesAvailable() and (ns.RXPThemesEnabled() or WindowWanted() or ns.RXPArrowEnabled()) then
            if ns.RXPThemesEnabled() then Quiet("Register", Register) end
            self:RegisterEvent("PLAYER_LOGIN")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        Reload()
    else
        self:UnregisterAllEvents()
        if ns.RXPSetUpEnabled() then Quiet("SetUp", SetUp) end
        if ns.RXPThemesEnabled() and late then Quiet("Resume", Resume) end
        if ns.RXPArrowEnabled() then StartArrow() end
        if ns.RXPThemesEnabled() then
            Quiet("HookBars", HookBars)
            Quiet("HookChrome", HookChrome)
            Quiet("HookRules", HookRules)
            Quiet("HookShown", HookShown)
        end
        if WindowWanted() then Quiet("Window", ns.RXPWindowStart) end
    end
end

boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", OnBootEvent)

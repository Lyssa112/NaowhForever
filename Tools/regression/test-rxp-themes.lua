-- NaowhUI and the eight Naowh themes in RestedXP Guides (Core/NaowhForever_RXPThemes.lua): written to
-- RestedXP's RXPGuides_Themes table only when the player turned it on and RestedXP Guides is installed.
-- The real Core and the real module are loaded, in the order the TOC lists them. Run with Lua 5.1 from
-- the repository root.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"); f:close()
    return s
end
local coreSource = Read("Core/NaowhForever_Core.lua")
local moduleSource = Read("Core/NaowhForever_RXPThemes.lua")

local cases = 0
local function Check(ok, label) assert(ok, label); cases = cases + 1 end
local function Same(got, want)
    for i = 1, #want do if got[i] ~= want[i] then return false end end
    return #got == #want
end
local function Hex(c)
    return ("%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
        math.floor(c[3] * 255 + 0.5))
end

-- installed: whether RestedXP Guides exists. existing: what another addon already put in the table.
local function Load(account, installed, existing)
    local frames = {}
    -- A texture or a mask: it records what the module asks of it.
    local function Region()
        local r = {}
        function r:SetAllPoints() self.allPoints = true end
        function r:SetColorTexture(...) self.rgba = { ... } end
        function r:SetGradient(orientation, low, high) self.gradient = { orientation, low, high } end
        function r:SetBlendMode(mode) self.blend = mode end
        function r:AddMaskTexture(mask) self.masks = self.masks or {}; self.masks[#self.masks + 1] = mask end
        function r:SetTexture(path, wrapH, wrapV) self.path, self.wrapH, self.wrapV = path, wrapH, wrapV end
        function r:SetRotation(radians) self.rotation = radians end
        return r
    end
    local function NewFrame(_, _, parent)
        local f = { events = {}, parent = parent }
        setmetatable(f, { __index = function() return function() end end })
        function f:SetScript(name, fn) self[name] = fn end
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterEvent(e) self.events[e] = nil end
        function f:UnregisterAllEvents() self.events = {} end
        function f:SetFrameLevel(level) self.level = level end
        function f:CreateTexture() self.colorRegion = Region(); return self.colorRegion end
        function f:CreateMaskTexture() self.maskRegion = Region(); return self.maskRegion end
        function f:Show() self.shown = true end
        function f:Hide() self.shown = false end
        frames[#frames + 1] = f
        return f
    end
    local hooked = {}
    local env = { CreateFrame = NewFrame, RXPGuides_Themes = existing, hooked = hooked,
        CreateColor = function(r, g, b, a) return { r, g, b, a } end,
        hooksecurefunc = function(tbl, name, fn) hooked[#hooked + 1] = { tbl, name, fn } end,
        C_AddOns = { DoesAddOnExist = function(name) return installed and name == "RXPGuides" end },
        NaowhForeverDB = { account = account, profiles = {}, charActive = {} } }
    env._G = env
    setmetatable(env, { __index = _G })
    local core = assert(loadstring(coreSource, "Core"))
    setfenv(core, env)
    core("NaowhForever")
    local coreFrames = #frames
    local module = assert(loadstring(moduleSource, "RXPThemes"))
    setfenv(module, env)
    module("NaowhForever")
    assert(#frames == coreFrames + 1, "the module makes one frame")
    return env, env.NaowhForever, frames, frames[#frames]
end

-- The game tells every frame that listens, in the order they registered.
local function Fire(frames, name)
    for _, f in ipairs(frames) do
        if f.events.ADDON_LOADED and f.OnEvent then f.OnEvent(f, "ADDON_LOADED", name) end
    end
end
-- Only the module's own frame: Core has login work of its own, which is not under test.
local function Login(boot)
    if boot.events.PLAYER_LOGIN and boot.OnEvent then boot.OnEvent(boot, "PLAYER_LOGIN") end
end
local function Count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local KEYS = { "", "midnight", "slate", "obsidian", "aubergine", "forest", "crimson", "rosenoir", "cottoncandy" }
local NAMES = { [""] = "NaowhUI", midnight = "Midnight", slate = "Slate", obsidian = "Obsidian",
    aubergine = "Aubergine", forest = "Forest", crimson = "Crimson", rosenoir = "Rose Noir",
    cottoncandy = "Cotton Candy" }
local function NameOf(key) return "NaowhForever:" .. (key == "" and "default" or key) end
local RXP_OWN = { "RXP Blue", "RXP Red", "RXP Gold", "DarkMode", "RXP Green", "Custom" }
local TEX = "Interface/AddOns/RXPGuides/Textures/"
local WHITE = "Interface/BUTTONS/WHITE8X8"
-- RestedXP's frame borders whose thin light line suits each theme's Accent: lavender (its blue set),
-- teal, tan, grey. Written out here on its own, so a wrong table in the module cannot hide behind itself.
local BORDER = { [""] = TEX, midnight = TEX, aubergine = TEX, cottoncandy = TEX,
    slate = TEX .. "Green/", forest = TEX .. "Green/", obsidian = TEX .. "GoldAssistant/",
    crimson = TEX .. "Hardcore/", rosenoir = TEX .. "Hardcore/" }

-- Off by default: nothing is written, whatever else is going on.
do
    local env, ns, frames, boot = Load({}, true)
    Check(boot.events.ADDON_LOADED, "the module waits for its addon to load")
    Fire(frames, "SomeOtherAddon")
    Check(env.RXPGuides_Themes == nil and boot.events.ADDON_LOADED, "another addon loading changes nothing")
    Fire(frames, "NaowhForever")
    Check(env.RXPGuides_Themes == nil, "off by default: RestedXP's table is not even created")
    Check(next(boot.events) == nil, "the event is unregistered once our addon has loaded")
    Check(ns.RXPThemesEnabled() == false and ns.RXPThemesAvailable() == true, "off, and RestedXP is seen")

    env, ns, frames = Load({ rxpThemes = true }, false)
    Fire(frames, "NaowhForever")
    Check(env.RXPGuides_Themes == nil, "on, but RestedXP Guides is not installed: nothing is written")
    Check(ns.RXPThemesAvailable() == false, "not installed")
end

-- On, with RestedXP installed: nine themes, from the palettes the Theme row previews.
do
    local env, ns, frames, boot = Load({ rxpThemes = true }, true)
    Fire(frames, "NaowhForever")
    local list = env.RXPGuides_Themes
    Check(type(list) == "table" and Count(list) == 9, "nine themes are registered")
    Check(boot.events.PLAYER_LOGIN and not boot.events.ADDON_LOADED, "then it waits for login, for the arrow")
    Login(boot)
    Check(next(boot.events) == nil, "and is unregistered after login")
    local seen = {}
    for _, key in ipairs(KEYS) do
        local theme = list[NameOf(key)]
        Check(theme and theme.name == NameOf(key), key .. ": registered under its own name")
        seen[theme.name] = true
        Check(theme.displayName == NAMES[key] and theme.author == "Naowh Forever", key .. ": name and author")
        local p = ns.ThemePalette(key)   -- bg, panel, line, fg, muted, accent
        Check(Same(theme.background, { p[1].r, p[1].g, p[1].b, 1 }), key .. ": the window is the Background color")
        Check(Same(theme.bottomFrameBG, { p[1].r, p[1].g, p[1].b, 1 }), key .. ": the step frames are the Background color too")
        Check(Same(theme.dividerColor, { p[3].r, p[3].g, p[3].b, 0.6 }), key .. ": the rule between list rows is Borders & Lines at 60%")
        Check(Same(theme.bottomFrameHighlight, { p[6].r, p[6].g, p[6].b, 0.5 }), key .. ": the Accent at half opacity")
        Check(Same(theme.mapPins, { p[6].r, p[6].g, p[6].b, 1 }), key .. ": map pins in the Accent")
        Check(Same(theme.textColor, { p[4].r, p[4].g, p[4].b }), key .. ": Text")
        Check(theme.tooltip == "|cff" .. Hex(theme.mapPins), key .. ": the tooltip color is the Accent")
        Check(theme.texturePath == TEX .. "DarkMode/", key .. ": RestedXP's own DarkMode logo and icons")
        local border = BORDER[key] .. "rxp-borders"
        Check(theme.edges.edge == border and theme.edges.guideName == border, key .. ": the window borders of its set")
        Check(not theme.edges.edge:find("DarkMode", 1, true), key .. ": not the near-black line of DarkMode")
        Check(theme.bgTextures.edge == WHITE and theme.bgTextures.bottom == WHITE and theme.bgTextures.guideName == WHITE,
            key .. ": every frame, the title bar and footer too, has a fill to color")
    end
    Check(Count(seen) == 9, "every theme has its own name")
    for _, own in ipairs(RXP_OWN) do
        Check(not list[own] and not seen[own], "RestedXP's own theme " .. own .. " is never overwritten")
    end

    -- The values themselves, pinned: a wrong mapping cannot hide behind re-deriving it.
    local default, midnight = list["NaowhForever:default"], list["NaowhForever:midnight"]
    Check(Hex(default.background) == "0e0f11" and Hex(default.bottomFrameBG) == "0e0f11", "NaowhUI: Background for the window and the step frames")
    Check(Hex(default.dividerColor) == "2e3136" and Hex(midnight.dividerColor) == "2a3550", "the rules: NaowhUI's and Midnight's Borders & Lines")
    Check(Hex(default.mapPins) == "0091ed" and default.tooltip == "|cff0091ed", "NaowhUI: the blue Accent")
    Check(Hex(default.textColor) == "f0f1f3", "NaowhUI: Text")
    Check(Hex(midnight.background) == "0b1020" and Hex(midnight.mapPins) == "5b8cff", "Midnight: Background and Accent")
end

-- Another addon's themes stay, and the same table is used.
do
    local other = { name = "RoseGold", author = "Bypass" }
    local existing = { RoseGold = other }
    local env, _, frames = Load({ rxpThemes = true }, true, existing)
    Fire(frames, "NaowhForever")
    Check(env.RXPGuides_Themes == existing and existing.RoseGold == other, "the table and the other addon's theme are kept")
    Check(Count(existing) == 10, "ten themes: theirs and our nine")
end

-- The player's own theme never leaks in: the nine are the fixed ones.
do
    for _, account in ipairs({
        { rxpThemes = true, themePreset = "crimson" },
        { rxpThemes = true, themePreset = "custom",
          themeColors = { bg = { r = 1, g = 0, b = 0 }, accent = { r = 0, g = 1, b = 0 } } } }) do
        local env, ns, frames = Load(account, true)
        Fire(frames, "NaowhForever")   -- Core applies the player's theme first, then the module registers
        local list = env.RXPGuides_Themes
        Check(Count(list) == 9, "still nine themes")
        Check(ns.THEME.accent.r ~= 0 or ns.THEME.accent.g ~= 0x91 / 255, "the player's theme is applied to the addon itself")
        Check(Hex(list["NaowhForever:default"].mapPins) == "0091ed" and Hex(list["NaowhForever:default"].background) == "0e0f11",
            "NaowhUI is still the default theme's colors")
        Check(Hex(list["NaowhForever:crimson"].mapPins) == "ef4b56", "Crimson is still Crimson")
    end
end

-- The waypoint arrow: while one of our themes is the active one, by default a layer of its Accent
-- lies over RestedXP's arrow (clipped to the arrow's own image, turning with it) and RestedXP's image
-- is not touched; or Naowh's own arrow image in the Accent, or RestedXP's own arrow. With any other
-- theme the arrow is left alone.
do
    local IMAGE = "Interface/AddOns/RXPGuides/Textures/DarkMode/rxp_navigation_arrow-1"
    local function Arrow()
        local a = { orientation = 1.25, sets = {}, tints = {} }
        a.texture = { path = IMAGE }
        function a.texture:GetTexture() return self.path end
        function a.texture:SetTexture(path) self.path = path; a.sets[#a.sets + 1] = path end
        function a.texture:SetVertexColor(...) a.tints[#a.tints + 1] = { ... } end
        function a.texture:SetRotation() end   -- RestedXP's own call, which the hook follows
        function a:GetFrameLevel() return 3 end
        function a.UpdateVisuals() end
        return a
    end
    local function Start(account, active)
        local env, _, frames, boot = Load(account, true)
        env.RXPG_ARROW = Arrow()
        Fire(frames, "NaowhForever")
        local list = env.RXPGuides_Themes
        env.RXP = { activeTheme = active and list[active] or { name = "RXP Blue" } }
        return env, frames, boot, list
    end
    local function Layers(frames, arrow)
        local out = {}
        for _, f in ipairs(frames) do
            if f.parent == arrow then out[#out + 1] = f end
        end
        return out
    end

    -- one of ours is active at login: hooked, and the layer is built and painted at once
    local env, frames, boot, list = Start({ rxpThemes = true }, "NaowhForever:rosenoir")
    local arrow = env.RXPG_ARROW
    Check(#env.hooked == 0 and #Layers(frames, arrow) == 0, "nothing is hooked or built before login")
    Login(boot)
    Check(#env.hooked == 2 and env.hooked[1][1] == arrow and env.hooked[1][2] == "UpdateVisuals",
        "RestedXP's UpdateVisuals is hooked")
    Check(env.hooked[2][1] == arrow.texture and env.hooked[2][2] == "SetRotation", "and so is its arrow's SetRotation")
    local layers = Layers(frames, arrow)
    Check(#layers == 1, "one layer, a child of the arrow")
    local layer = layers[1]
    Check(layer.level == 4 and layer.shown == true, "above the arrow, and shown")
    local color, mask = layer.colorRegion, layer.maskRegion
    Check(color.blend == "ADD" and Same(color.rgba, { 1, 1, 1, 1 }), "an added layer, white until its gradient colors it")
    -- The Accent, lighter at the top and deeper at the bottom, at 90% strength.
    local function Close(got, want)
        for i = 1, 4 do if math.abs(got[i] - want[i]) > 1e-9 then return false end end
        return true
    end
    local function Gradient(accent)
        return { accent[1] * 0.72, accent[2] * 0.72, accent[3] * 0.72, 0.9 },
            { accent[1] + (1 - accent[1]) * 0.22, accent[2] + (1 - accent[2]) * 0.22,
              accent[3] + (1 - accent[3]) * 0.22, 0.9 }
    end
    local deep, light = Gradient(list["NaowhForever:rosenoir"].mapPins)
    Check(color.gradient[1] == "VERTICAL" and Close(color.gradient[2], deep) and Close(color.gradient[3], light),
        "Rose Noir's Accent, deeper at the bottom and lighter at the top")
    Check(Hex(color.gradient[2]) == "b84475" and Hex(color.gradient[3]) == "ff82b6", "and those are the colors, pinned")
    Check(color.masks and color.masks[1] == mask, "clipped by the mask")
    Check(mask.path == IMAGE and mask.wrapH == "CLAMPTOBLACKADDITIVE" and mask.wrapV == "CLAMPTOBLACKADDITIVE",
        "the mask is the arrow's own image")
    Check(mask.rotation == 1.25, "turned the way the arrow is")
    env.hooked[2][3](arrow.texture, 0.5)
    Check(mask.rotation == 0.5, "and it turns with the arrow")
    Check(arrow.texture.path == IMAGE, "RestedXP's own image is untouched")

    -- RestedXP sets its image again when its theme changes, and the hook runs after it
    env.RXP.activeTheme = { name = "DarkMode" }
    env.hooked[1][3](arrow)
    Check(layer.shown == false and #Layers(frames, arrow) == 1, "a theme of RestedXP's: the layer is hidden, not rebuilt")
    env.RXP.activeTheme = list["NaowhForever:midnight"]
    arrow.texture.path = "Interface/AddOns/RXPGuides/Textures/Other/rxp_navigation_arrow-1"
    env.hooked[1][3](arrow)
    deep, light = Gradient(list["NaowhForever:midnight"].mapPins)
    Check(layer.shown == true and Close(color.gradient[2], deep) and Close(color.gradient[3], light)
        and mask.path == arrow.texture.path and #Layers(frames, arrow) == 1,
        "back to one of ours: shown, in Midnight's Accent, from the arrow's image of the moment")

    -- RestedXP's own theme at login: hooked, but no layer is ever built
    env, frames, boot = Start({ rxpThemes = true }, nil)
    Login(boot)
    Check(#env.hooked == 1 and #Layers(frames, env.RXPG_ARROW) == 0, "RestedXP's own theme: no layer is built")
    env.RXP.activeTheme = { name = "xNaowhForever:default", mapPins = { 1, 0, 0, 1 } }
    env.hooked[1][3]()
    Check(#Layers(frames, env.RXPG_ARROW) == 0, "only a name that starts with ours counts")

    -- off: no login event, nothing hooked
    local off, _, offBoot = Start({}, nil)
    Check(next(offBoot.events) == nil and #off.hooked == 0, "off: no event left, nothing hooked")
    Login(offBoot)
    Check(#off.hooked == 0, "off: login does nothing")

    -- RestedXP without the pieces: no error, and nothing built
    local e2, _, f2, b2 = Load({ rxpThemes = true }, true)
    Fire(f2, "NaowhForever"); Login(b2)
    Check(#e2.hooked == 0 and next(b2.events) == nil, "no arrow frame: nothing to do")
    e2, _, f2, b2 = Load({ rxpThemes = true }, true)
    e2.RXPG_ARROW = { UpdateVisuals = function() end }
    Fire(f2, "NaowhForever"); Login(b2)
    Check(#e2.hooked == 0, "no arrow texture: nothing is hooked")
    e2, _, f2, b2 = Load({ rxpThemes = true }, true)
    e2.RXPG_ARROW = Arrow()
    Fire(f2, "NaowhForever"); Login(b2)
    Check(#e2.hooked == 1 and #Layers(f2, e2.RXPG_ARROW) == 0, "no RXP table: hooked, and nothing built")
    e2, _, f2, b2 = Load({ rxpThemes = true }, true)
    local fixed = Arrow()
    fixed.texture.SetRotation = nil
    e2.RXPG_ARROW = fixed
    Fire(f2, "NaowhForever")
    e2.RXP = { activeTheme = e2.RXPGuides_Themes["NaowhForever:default"] }
    Login(b2)
    Check(#e2.hooked == 1 and #Layers(f2, fixed) == 0, "an arrow that cannot be turned: no layer")
    e2, _, f2, b2 = Load({ rxpThemes = true }, false)
    e2.RXPG_ARROW = Arrow()
    Fire(f2, "NaowhForever"); Login(b2)
    Check(#e2.hooked == 0, "RestedXP not installed: nothing is hooked")

    -- the style: the layer by default, saved only when it is another, and nothing else accepted
    local account = {}
    local _, styleNs = Load(account, true)
    Check(styleNs.RXPArrowStyle() == "layer" and account.rxpArrow == nil, "the arrow is a layer by default")
    styleNs.SetRXPArrowStyle("image")
    Check(account.rxpArrow == "image" and styleNs.RXPArrowStyle() == "image", "the image style is stored")
    styleNs.SetRXPArrowStyle("off")
    Check(account.rxpArrow == "off" and styleNs.RXPArrowStyle() == "off", "so is off")
    styleNs.SetRXPArrowStyle("layer")
    Check(account.rxpArrow == nil and styleNs.RXPArrowStyle() == "layer", "the default is stored as nothing")
    styleNs.SetRXPArrowStyle("bogus")
    Check(account.rxpArrow == nil, "an unknown style is not stored")
    account.rxpArrow = "junk"
    Check(styleNs.RXPArrowStyle() == "layer", "an unknown saved style reads as the layer")

    -- Naowh's own arrow image: in place of RestedXP's, in the Accent, and no layer
    local OURS = "Interface\\AddOns\\NaowhForever\\Media\\rxp_arrow.tga"
    local imageEnv, imageFrames, imageBoot, imageList = Start({ rxpThemes = true, rxpArrow = "image" }, "NaowhForever:rosenoir")
    local drawn = imageEnv.RXPG_ARROW
    Login(imageBoot)
    Check(#imageEnv.hooked == 1 and #Layers(imageFrames, drawn) == 0, "image: only UpdateVisuals is hooked, and no layer is built")
    Check(drawn.texture.path == OURS and #drawn.sets == 1, "image: Naowh's arrow image is on the arrow")
    local tint = drawn.tints[#drawn.tints]
    Check(Hex(tint) == "ff5fa2" and tint[4] == 1, "image: in Rose Noir's Accent")
    -- RestedXP sets its own image again for its own theme, and the tint goes
    imageEnv.RXP.activeTheme = { name = "DarkMode" }
    drawn.texture.path = IMAGE
    imageEnv.hooked[1][3](drawn)
    Check(#drawn.sets == 1 and drawn.texture.path == IMAGE, "a theme of RestedXP's: its image is left on the arrow")
    Check(Same(drawn.tints[#drawn.tints], { 1, 1, 1, 1 }), "and the tint is cleared")
    -- and one of ours again: RestedXP sets its image, then ours goes on
    imageEnv.RXP.activeTheme = imageList["NaowhForever:midnight"]
    imageEnv.hooked[1][3](drawn)
    tint = drawn.tints[#drawn.tints]
    Check(drawn.texture.path == OURS and #drawn.sets == 2 and Hex(tint) == "5b8cff", "back to one of ours: the image and Midnight's Accent")

    -- switching the style takes effect at once, and RestedXP's image is handed back
    local styles = imageEnv.NaowhForever
    styles.SetRXPArrowStyle("layer")
    Check(drawn.texture.path == IMAGE and Same(drawn.tints[#drawn.tints], { 1, 1, 1, 1 }),
        "to the layer: RestedXP's own image is back, untinted")
    local switched = Layers(imageFrames, drawn)
    Check(#switched == 1 and switched[1].shown == true, "and the layer is built and shown")
    styles.SetRXPArrowStyle("off")
    Check(switched[1].shown == false and drawn.texture.path == IMAGE, "to off: the layer is hidden, and the arrow is RestedXP's")
    local setsBefore = #drawn.sets
    styles.SetRXPArrowStyle("image")
    Check(drawn.texture.path == OURS and #drawn.sets == setsBefore + 1 and switched[1].shown == false,
        "back to the image: ours is on, and the layer stays hidden")
    styles.SetRXPArrowStyle("off")
    Check(drawn.texture.path == IMAGE, "off hands RestedXP's image back again")

    -- off from the start: RestedXP's own arrow, untouched
    local quietEnv, quietFrames, quietBoot = Start({ rxpThemes = true, rxpArrow = "off" }, "NaowhForever:rosenoir")
    Login(quietBoot)
    Check(#quietEnv.hooked == 1 and #Layers(quietFrames, quietEnv.RXPG_ARROW) == 0 and #quietEnv.RXPG_ARROW.sets == 0
        and #quietEnv.RXPG_ARROW.tints == 0, "off: RestedXP's own arrow, untouched")

    -- RestedXP not on one of our themes: no style does anything
    for _, style in ipairs({ "layer", "image", "off" }) do
        local e3, f3, b3 = Start({ rxpThemes = true, rxpArrow = style }, nil)
        Login(b3)
        Check(#Layers(f3, e3.RXPG_ARROW) == 0 and #e3.RXPG_ARROW.sets == 0 and #e3.RXPG_ARROW.tints == 0,
            style .. ": with RestedXP's own theme the arrow is left alone")
    end
end

-- The classic window's title bar and footer: a fill under a banner image, black in the set these themes
-- take their icons from. While one of ours is the active theme the image is hidden, so the fill (the
-- theme's Background) shows; with any other theme the image is never touched.
do
    local function Banner()
        local b = { alphas = {} }
        function b:SetTexture() end   -- RestedXP's own call, which the hook follows
        function b:SetAlpha(alpha) self.alphas[#self.alphas + 1] = alpha; self.alpha = alpha end
        return b
    end
    local function Start(account, active)
        local env, _, frames, boot = Load(account, true)
        env.RXPFrame = { GuideName = { bg = Banner() }, Footer = { bg = Banner() } }
        Fire(frames, "NaowhForever")
        env.RXP = { activeTheme = active and env.RXPGuides_Themes[active] or { name = "RXP Blue" } }
        return env, boot
    end
    -- the function hooked onto a banner's SetTexture
    local function Hook(env, banner)
        for _, h in ipairs(env.hooked) do
            if h[1] == banner and h[2] == "SetTexture" then return h[3] end
        end
    end

    -- one of ours is active at login: both banners are hidden at once
    local env, boot = Start({ rxpThemes = true }, "NaowhForever:crimson")
    local title, footer = env.RXPFrame.GuideName.bg, env.RXPFrame.Footer.bg
    Check(#env.hooked == 0 and #title.alphas == 0 and #footer.alphas == 0, "nothing is hooked or hidden before login")
    Login(boot)
    Check(#env.hooked == 2 and Hook(env, title) and Hook(env, footer), "both banners' SetTexture are hooked")
    Check(title.alpha == 0 and footer.alpha == 0, "and both are hidden at once")
    -- RestedXP sets its banner again whenever it draws its theme, and the hook hides it again
    title.alpha = 1
    Hook(env, title)(title, TEX .. "DarkMode/rxp-banner")
    Check(title.alpha == 0 and footer.alpha == 0, "RestedXP sets its banner again: hidden again")
    -- another theme of RestedXP's: the banners come back, once
    env.RXP.activeTheme = { name = "DarkMode" }
    Hook(env, title)(title)
    Check(title.alpha == 1 and footer.alpha == 1, "a theme of RestedXP's: the banners are shown")
    local sets = #title.alphas + #footer.alphas
    Hook(env, footer)(footer)
    Check(#title.alphas + #footer.alphas == sets, "and not set again while they are RestedXP's")
    -- one of ours again
    env.RXP.activeTheme = env.RXPGuides_Themes["NaowhForever:midnight"]
    Hook(env, footer)(footer)
    Check(title.alpha == 0 and footer.alpha == 0, "back to one of ours: hidden again")

    -- RestedXP's own theme at login: hooked, and the banners are never touched
    local own, ownBoot = Start({ rxpThemes = true }, nil)
    Login(ownBoot)
    local ownTitle, ownFooter = own.RXPFrame.GuideName.bg, own.RXPFrame.Footer.bg
    Check(Hook(own, ownTitle) and Hook(own, ownFooter), "RestedXP's own theme: the banners are hooked")
    Check(#ownTitle.alphas == 0 and #ownFooter.alphas == 0, "but never touched")
    Hook(own, ownTitle)(ownTitle)
    own.RXP.activeTheme = { name = "xNaowhForever:crimson", mapPins = { 1, 0, 0, 1 } }
    Hook(own, ownFooter)(ownFooter)
    Check(#ownTitle.alphas == 0 and #ownFooter.alphas == 0, "not when RestedXP sets them again, and only a name that starts with ours counts")
    -- and one of ours picked later hides them
    own.RXP.activeTheme = own.RXPGuides_Themes["NaowhForever:slate"]
    Hook(own, ownFooter)(ownFooter)
    Check(ownTitle.alpha == 0 and ownFooter.alpha == 0, "one of ours picked later: hidden")

    -- off: no login event, nothing hooked or hidden
    local off, offBoot = Start({}, nil)
    Login(offBoot)
    Check(#off.hooked == 0 and #off.RXPFrame.GuideName.bg.alphas == 0 and #off.RXPFrame.Footer.bg.alphas == 0,
        "off: nothing is hooked, nothing is hidden")

    -- RestedXP without the pieces: no error, and only what is there is hooked
    local function Bare(window, active)
        local e, _, f, b = Load({ rxpThemes = true }, true)
        e.RXPFrame = window
        Fire(f, "NaowhForever")
        e.RXP = { activeTheme = active and e.RXPGuides_Themes[active] or nil }
        Login(b)
        return e
    end
    Check(#Bare(nil).hooked == 0 and #Bare({}).hooked == 0, "no window, or one without bars: nothing is hooked")
    Check(#Bare({ GuideName = {}, Footer = {} }).hooked == 0, "bars without banners: nothing is hooked")
    local half = { GuideName = { bg = Banner() }, Footer = { bg = {} } }
    Check(#Bare(half, "NaowhForever:crimson").hooked == 1 and half.GuideName.bg.alpha == 0,
        "the banner that is there is hooked and hidden; the other is skipped")
    local mute = { GuideName = { bg = { SetTexture = function() end } } }
    Check(#Bare(mute, "NaowhForever:crimson").hooked == 1, "a banner that cannot be hidden is hooked and left alone")
end

-- The classic window's quest list: rows with no line between them. While one of ours is the active theme
-- each row gets a 1px rule at its bottom, in Borders & Lines at 60% like Naowh's own lists; with any other
-- theme there are none. The rows are made when a guide loads, which ends in SetStep.
do
    -- a texture that records what the module asks of it
    local function Rule(layer)
        local t = { layer = layer, points = {}, paints = 0, hides = 0 }
        function t:SetPoint(point) self.points[#self.points + 1] = point end
        function t:SetHeight(height) self.height = height end
        function t:SetColorTexture(...) self.rgba = { ... }; self.paints = self.paints + 1 end
        function t:Show() self.shown = true end
        function t:Hide() self.shown = false; self.hides = self.hides + 1 end
        return t
    end
    local function Row()
        local row = { textures = {} }
        function row:CreateTexture(_, layer)
            local t = Rule(layer)
            self.textures[#self.textures + 1] = t
            return t
        end
        return row
    end
    local function Start(account, active, rows)
        local env, _, frames, boot = Load(account, true)
        local pool = {}
        for i = 1, rows do pool[i] = Row() end
        env.RXPFrame = { ScrollChild = { framePool = pool } }
        Fire(frames, "NaowhForever")
        env.RXP = { SetStep = function() end,
            activeTheme = active and env.RXPGuides_Themes[active] or { name = "RXP Blue" } }
        return env, boot, pool
    end
    -- the function hooked onto SetStep
    local function Hook(env)
        for _, h in ipairs(env.hooked) do
            if h[1] == env.RXP and h[2] == "SetStep" then return h[3] end
        end
    end

    -- one of ours is active at login: every row has its rule at once
    local env, boot, pool = Start({ rxpThemes = true }, "NaowhForever:crimson", 2)
    Check(#env.hooked == 0 and #pool[1].textures == 0, "nothing is hooked or drawn before login")
    Login(boot)
    Check(#env.hooked == 1 and Hook(env), "SetStep is hooked")
    for i, row in ipairs(pool) do
        local rule = row.textures[1]
        Check(#row.textures == 1 and rule.layer == "ARTWORK" and rule.height == 1 and rule.shown == true
            and Same(rule.points, { "BOTTOMLEFT", "BOTTOMRIGHT" }), "row " .. i .. ": a 1px rule along its bottom")
        Check(Hex(rule.rgba) == "3d2429" and rule.rgba[4] == 0.6, "row " .. i .. ": Crimson's Borders & Lines at 60%")
    end

    -- a guide with more steps adds rows; the old rules are not drawn again
    pool[3] = Row()
    Hook(env)()
    Check(#pool[3].textures == 1 and pool[3].textures[1].shown == true, "a new row gets its rule")
    Check(#pool[1].textures == 1 and pool[1].textures[1].paints == 2, "the first row is drawn again, but keeps its one rule")
    local before = pool[1].textures[1].paints
    Hook(env)()
    Hook(env)()
    Check(pool[1].textures[1].paints == before and pool[3].textures[1].paints == 1, "nothing changed: nothing is drawn")

    -- another of ours: the same rules, in its color
    env.RXP.activeTheme = env.RXPGuides_Themes["NaowhForever:midnight"]
    Hook(env)()
    Check(#pool[2].textures == 1 and Hex(pool[2].textures[1].rgba) == "2a3550", "another of ours: the same rule in Midnight's Borders & Lines")

    -- a theme of RestedXP's: the rules go, once
    env.RXP.activeTheme = { name = "DarkMode" }
    Hook(env)()
    Check(pool[1].textures[1].shown == false and pool[3].textures[1].shown == false, "a theme of RestedXP's: no rules")
    local hides = pool[1].textures[1].hides
    Hook(env)()
    Check(pool[1].textures[1].hides == hides, "and they are not hidden again")
    env.RXP.activeTheme = env.RXPGuides_Themes["NaowhForever:midnight"]
    Hook(env)()
    Check(pool[1].textures[1].shown == true and #pool[1].textures == 1, "back to one of ours: shown again, not made again")

    -- RestedXP's own theme at login: hooked, and no rule is ever made
    local own, ownBoot, ownPool = Start({ rxpThemes = true }, nil, 2)
    Login(ownBoot)
    Check(Hook(own) and #ownPool[1].textures == 0, "RestedXP's own theme: hooked, no rules made")
    own.RXP.activeTheme = { name = "xNaowhForever:crimson", dividerColor = { 1, 0, 0, 1 } }
    Hook(own)()
    Check(#ownPool[1].textures == 0, "only a name that starts with ours counts")
    own.RXP.activeTheme = own.RXPGuides_Themes["NaowhForever:slate"]
    Hook(own)()
    Check(#ownPool[1].textures == 1 and ownPool[2].textures[1].shown == true, "one of ours picked later: the rules appear")

    -- off: no login event, nothing hooked or drawn
    local off, offBoot, offPool = Start({}, nil, 2)
    Login(offBoot)
    Check(#off.hooked == 0 and #offPool[1].textures == 0, "off: nothing is hooked, nothing is drawn")

    -- RestedXP without the pieces: no error, and only what is there is used
    local function Bare(window, rxp)
        local e, _, f, b = Load({ rxpThemes = true }, true)
        e.RXPFrame = window
        Fire(f, "NaowhForever")
        e.RXP = rxp and { SetStep = rxp.SetStep, activeTheme = e.RXPGuides_Themes["NaowhForever:crimson"] } or nil
        Login(b)
        return e
    end
    Check(#Bare(nil, {}).hooked == 0, "no window and no SetStep: nothing is hooked")
    Check(#Bare({}, { SetStep = function() end }).hooked == 1, "a window without a list: hooked, nothing drawn, no error")
    Check(#Bare({ ScrollChild = {} }, { SetStep = function() end }).hooked == 1, "a list without rows: no error")
    local empty = { ScrollChild = { framePool = {} } }
    Check(#Bare(empty, { SetStep = function() end }).hooked == 1, "an empty list: no error")
    local plain = { ScrollChild = { framePool = { {} } } }
    Check(#Bare(plain, { SetStep = function() end }).hooked == 1, "a row that cannot make a texture is skipped")
end

-- The setting.
do
    local account = {}
    local _, ns = Load(account, true)
    Check(ns.RXPThemesEnabled() == false and account.rxpThemes == nil, "off by default")
    ns.SetRXPThemes(true)
    Check(account.rxpThemes == true and ns.RXPThemesEnabled() == true, "on is stored")
    ns.SetRXPThemes(false)
    Check(account.rxpThemes == nil and ns.RXPThemesEnabled() == false, "off clears it")
    account.rxpThemes = "yes"
    Check(ns.RXPThemesEnabled() == false, "only true turns it on")
end

print("PASS rxp themes: " .. cases .. " checks")

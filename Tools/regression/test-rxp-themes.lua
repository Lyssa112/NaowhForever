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
        Check(Same(theme.background, { p[2].r, p[2].g, p[2].b, 1 }), key .. ": the window is the Panels color")
        Check(Same(theme.bottomFrameBG, { p[3].r, p[3].g, p[3].b, 1 }), key .. ": the step frames are the Borders & Lines color")
        Check(Same(theme.bottomFrameHighlight, { p[6].r, p[6].g, p[6].b, 0.5 }), key .. ": the Accent at half opacity")
        Check(Same(theme.mapPins, { p[6].r, p[6].g, p[6].b, 1 }), key .. ": map pins in the Accent")
        Check(Same(theme.textColor, { p[4].r, p[4].g, p[4].b }), key .. ": Text")
        Check(theme.tooltip == "|cff" .. Hex(theme.mapPins), key .. ": the tooltip color is the Accent")
        Check(theme.texturePath == "Interface/AddOns/RXPGuides/Textures/DarkMode/", key .. ": RestedXP's own neutral frames")
        Check(theme.edges.edge == theme.texturePath .. "rxp-borders" and theme.edges.guideName == theme.texturePath .. "rxp-borders",
            key .. ": the window borders are from the same frames")
    end
    Check(Count(seen) == 9, "every theme has its own name")
    for _, own in ipairs(RXP_OWN) do
        Check(not list[own] and not seen[own], "RestedXP's own theme " .. own .. " is never overwritten")
    end

    -- The values themselves, pinned: a wrong mapping cannot hide behind re-deriving it.
    local default, midnight = list["NaowhForever:default"], list["NaowhForever:midnight"]
    Check(Hex(default.background) == "1a1c1f" and Hex(default.bottomFrameBG) == "2e3136", "NaowhUI: Panels and Borders & Lines")
    Check(Hex(default.mapPins) == "0091ed" and default.tooltip == "|cff0091ed", "NaowhUI: the blue Accent")
    Check(Hex(default.textColor) == "f0f1f3", "NaowhUI: Text")
    Check(Hex(midnight.background) == "151c30" and Hex(midnight.mapPins) == "5b8cff", "Midnight: Panels and Accent")
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
        Check(Hex(list["NaowhForever:default"].mapPins) == "0091ed" and Hex(list["NaowhForever:default"].background) == "1a1c1f",
            "NaowhUI is still the default theme's colors")
        Check(Hex(list["NaowhForever:crimson"].mapPins) == "ef4b56", "Crimson is still Crimson")
    end
end

-- The waypoint arrow: while one of our themes is the active one, a layer of its Accent lies over
-- RestedXP's arrow (clipped to the arrow's own image, turning with it); RestedXP's image is never
-- touched, and with any other theme there is no layer.
do
    local IMAGE = "Interface/AddOns/RXPGuides/Textures/DarkMode/rxp_navigation_arrow-1"
    local function Arrow()
        local a = { orientation = 1.25 }
        a.texture = { path = IMAGE }
        function a.texture:GetTexture() return self.path end
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

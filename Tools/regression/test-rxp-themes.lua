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
    local function NewFrame()
        local f = { events = {} }
        setmetatable(f, { __index = function() return function() end end })
        function f:SetScript(name, fn) self[name] = fn end
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterEvent(e) self.events[e] = nil end
        function f:UnregisterAllEvents() self.events = {} end
        frames[#frames + 1] = f
        return f
    end
    local env = { CreateFrame = NewFrame, RXPGuides_Themes = existing,
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
    Check(next(boot.events) == nil, "and the event is unregistered")
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

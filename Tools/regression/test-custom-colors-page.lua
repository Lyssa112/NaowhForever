-- Settings > COLORS section: the Theme dropdown, the Reset button, the Custom swatches, and
-- when the "Reload UI" hint shows. The COLORS and RESTEDXP sections are sliced out of
-- SettingsPage.lua (with its named values) and run against the real Core; running them again on
-- the same environment stands in for a page rebuild. Run from the repository root.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end
local coreSource = Read("Core/Core.lua")
local featuresSource = Read("Core/Features.lua")
local rxpSource = Read("Core/Integrations/RestedXP/Themes.lua")
local windowSource = Read("Core/Integrations/RestedXP/Window.lua")
local source = Read("Core/Options/SettingsPage.lua")
local constants = assert(source:match("\n(local DEFAULT_SCALE = .-\n)\nlocal colorsPending = false\n"), "named values")
local empty = assert(source:match("\n(local function Empty%(%).-end\n)"), "Empty")
local first = assert(source:find("local function ThemeChoices()", 1, true))
local last = assert(source:find("function ns.BuildSettingsPage", first, true))
local section = source:sub(first, last - 1)
local chunk = assert(loadstring(constants .. empty .. section
    .. "local parent, y = ...\ny = ColorsSection(W, parent, y)\nreturn RestedXPSection(W, parent, y)"))

-- The pending flag has to outlive a rebuild, so it lives at file scope, above the builder.
local build = assert(source:find("function ns.BuildSettingsPage", 1, true))
for _, name in ipairs({ "colorsPending", "rxpPending" }) do
    local flag = assert(source:find("\nlocal " .. name .. " = false\n", 1, true))
    assert(flag < build, name .. " is file scope")
end

local HINT = "Reload UI to apply your color changes."
local RXP_HINT = "Reload UI to apply your RestedXP changes."
local cases = 0
local function Check(ok, label) assert(ok, label); cases = cases + 1 end
Check(not section:find("ReloadUI", 1, true), "the section never calls ReloadUI itself")

-- RestedXP as the page needs it: its theme list, its settings and a reload that records what it was on.
local function RxpStub(active, live)
    local rxp = { settings = { profile = { activeTheme = active, enableThemeLiveReload = live ~= false } }, reloads = {},
        themes = { ["NaowhForever:default"] = {}, ["NaowhForever:crimson"] = {}, ["NaowhForever:current"] = {} } }
    function rxp:ReloadTheme() self.reloads[#self.reloads + 1] = self.settings.profile.activeTheme end
    return rxp
end

local function RealCore(account, rxp, up)
    local frame = setmetatable({}, { __index = function() return function() end end })
    function frame:SetScript() end
    local env = { CreateFrame = function() return frame end,
        C_AddOns = { DoesAddOnExist = function(name) return rxp == true and name == "RXPGuides" end },
        NaowhForeverDB = { account = account, profiles = {}, charActive = {} } }
    env._G = env
    env.RXP = up
    env.InCombatLockdown = function() return false end
    setmetatable(env, { __index = _G })
    local core = assert(loadstring(coreSource, "Core"))
    setfenv(core, env)
    core("NaowhForever")
    local features = assert(loadstring(featuresSource, "Features"))
    setfenv(features, env)
    features()
    local module = assert(loadstring(rxpSource, "RXPThemes"))
    setfenv(module, env)
    module("NaowhForever")
    local window = assert(loadstring(windowSource, "RXPWindow"))
    setfenv(window, env)
    window("NaowhForever")
    return env.NaowhForever
end

-- rxp: RestedXP Guides is installed. up: its table in the game, when it has started with our themes in it.
local function Page(account, rxp, up)
    local e = { confirms = {}, refreshes = 0, account = account, rxp = up }
    local ns = RealCore(account, rxp, up)
    e.ns = ns
    ns.Confirm = function(text, onYes) e.confirms[#e.confirms + 1] = { text = text, yes = onYes } end
    local env = { ns = ns, W = {}, colorsPending = false, rxpPending = false,
        UI = { RefreshPage = function() e.refreshes = e.refreshes + 1 end,
            FontChoices = function() return { [""] = "Addon Font" }, { "" } end,
            TextureChoices = function(_, label) return { [""] = label }, { "" } end } }
    function env.W:SectionHeader(_, text)
        e.headers[#e.headers + 1] = text
        return nil, 0
    end
    function env.W:DualRow(_, _, left, right)
        -- The Skin row is checked on its own below; the Theme rows keep their places.
        if left.text == "Skin" then
            e.skin = left
            return nil, 0
        end
        e.rows[#e.rows + 1] = { left, right }
        return nil, 0
    end
    function env.W:Note(_, text)
        e.notes[#e.notes + 1] = text
        return nil, 0
    end
    setmetatable(env, { __index = _G })
    setfenv(chunk, env)
    function e.build()
        e.rows, e.notes, e.headers = {}, {}, {}
        chunk({}, 0)
        e.theme = e.rows[1][1]
    end
    e.build()
    return e
end
local function Texts(e)
    local out = {}
    for i = 3, #e.rows do
        for _, cfg in ipairs(e.rows[i]) do if cfg.text ~= "" then out[#out + 1] = cfg.text end end
    end
    return out
end

-- The dropdown: Naowh (default) first, the presets as Core lists them, Custom last.
do
    local e = Page({})
    local t = e.theme
    local presets, want = e.ns.THEME_PRESET_ORDER, {}
    for _, key in ipairs(presets) do want[#want + 1] = e.ns.THEME_PRESETS[key].name end
    Check(t.type == "dropdown" and t.text == "Theme", "a Theme dropdown")
    Check(t.order[1] == "" and t.values[""] == "Naowh (default)", "the default comes first")
    Check(t.order[#t.order] == "custom" and t.values.custom == "Custom", "Custom comes last")
    local names = {}
    for i = 2, #t.order - 1 do names[#names + 1] = t.values[t.order[i]] end
    Check(table.concat(names, ",") == table.concat(want, ","), "the presets in order")
    Check(#t.order == #presets + 2, "the default, every preset and Custom")
    Check(t.getValue() == "", "the default is selected when nothing is saved")
    for _, word in ipairs({ "Theme presets", "windows and HUD frames", "Custom", "Naowh (default)", "/reload" }) do
        Check(t.tooltip:find(word, 1, true), "tooltip mentions " .. word)
    end
    Check(e.rows[1][2].type == "palette" and #e.rows[1][2].colors() == 6, "a six-chip preview beside the Theme dropdown")
    Check(not t.tooltip:find("Reset", 1, true), "no reset any more")
end

-- Swatches show for Custom and for nothing else.
do
    Check(#Page({}).rows == 1, "no swatches for the default theme")
    for _, key in ipairs(Page({}).ns.THEME_PRESET_ORDER) do
        local e = Page({ themePreset = key })
        Check(#e.rows == 1 and e.theme.getValue() == key, "no swatches for " .. key)
    end
    for _, bad in ipairs({ "bogus", "order", 5 }) do
        local e = Page({ themePreset = bad })
        Check(#e.rows == 1 and e.theme.getValue() == "", "an invalid preset reads as the default, no swatches")
    end
    local e = Page({ themePreset = "custom" })
    Check(#e.rows == 5, "Custom shows the Start From row and three swatch rows")
    Check(e.rows[2][1].text == "Start From" and e.rows[2][1].type == "dropdown", "the Start From dropdown")
    Check(table.concat(Texts(e), ",") == "Background,Panels,Borders & Lines,Text,Secondary Text,Accent",
        "the six swatches, in order")
    for i = 3, 5 do
        for _, cfg in ipairs(e.rows[i]) do
            if cfg.text ~= "" then Check(cfg.type == "colorpicker" and cfg.hasAlpha == false, cfg.text .. " is a swatch") end
        end
    end
    Check(#Page({}).notes == 0, "no hint before any change")
end

-- Picking from the dropdown redraws the page and brings the hint up, with no dialog.
do
    local a = {}
    local e = Page(a)
    e.theme.setValue("midnight")
    Check(a.themePreset == "midnight" and e.refreshes == 1 and #e.confirms == 0, "a preset is stored and the page redraws")
    e.build()
    Check(#e.notes == 1 and e.notes[1] == HINT and #e.rows == 1, "the hint shows, still no swatches")
    e.theme.setValue("")
    e.build()
    Check(a.themePreset == nil and #e.notes == 1, "the default is stored as nothing, and the hint stays")
end

-- Skin: the default or Classic+, stored for a reload; Classic+ has its own colors, so the
-- Theme dropdown is greyed out under it.
do
    local a = {}
    local e = Page(a)
    local k = e.skin
    Check(k and k.type == "dropdown" and k.order[1] == "" and k.values.classic == "Classic+", "a Skin dropdown, default first")
    Check(k.getValue() == "" and not e.theme.disabled(), "nothing saved: the default, and Theme can be picked")
    k.setValue("classic")
    Check(a.skin == "classic" and e.refreshes == 1, "Classic+ is stored and the page redraws")
    e.build()
    Check(#e.notes == 1 and e.notes[1] == HINT and e.theme.disabled(), "the hint shows, and Theme is greyed out")
    e.skin.setValue("")
    Check(a.skin == nil, "the default is stored as nothing")
end

-- Custom starts from the palette the player was looking at, and only then shows swatches.
do
    local a = { themePreset = "slate" }
    local e = Page(a)
    e.theme.setValue("custom")
    Check(a.themePreset == "custom" and a.themeColors.bg.r == 0x12 / 255, "Custom is prefilled from the selected preset")
    e.build()
    Check(#e.rows == 5 and #e.notes == 1, "the swatches appear once Custom is selected")
    local bg = e.rows[3][1]
    local r = bg.getValue()
    Check(r == 0x12 / 255, "the swatch shows the prefilled color")
end

-- A swatch drag calls setValue on every tick: one redraw, never a dialog.
do
    local a = { themePreset = "custom", themeColors = { bg = { r = 0.1, g = 0.1, b = 0.1 } } }
    local e = Page(a)
    local swatch = e.rows[3][1]
    Check(#e.notes == 0, "no hint before a swatch changes")
    for i = 1, 50 do swatch.setValue(i / 50, 0, 0) end
    Check(e.refreshes == 1, "only the first tick redraws the page")
    Check(#e.confirms == 0, "dragging never opens a dialog")
    Check(a.themeColors.bg.r == 1, "the last pick is saved")
    e.build()
    Check(#e.notes == 1 and e.notes[1] == HINT, "hint shows after a swatch change")
end

-- Start From: an action that always reads the placeholder, asks first, then replaces the picks.
do
    local a = { themePreset = "custom", themeColors = { bg = { r = 1, g = 0, b = 0 } } }
    local e = Page(a)
    local start = e.rows[2][1]
    Check(start.order[1] == "" and start.values[""] == "Choose a theme...", "the placeholder comes first")
    Check(start.order[2] == "default" and start.values.default == "Naowh (default)", "the default is offered")
    Check(#start.order == #e.ns.THEME_PRESET_ORDER + 2 and start.values.custom == nil, "every preset, and not Custom itself")
    Check(start.getValue() == "", "it always shows the placeholder")
    start.setValue("")
    Check(#e.confirms == 0, "the placeholder does nothing")
    start.setValue("slate")
    Check(#e.confirms == 1 and e.confirms[1].text == "Replace your custom colors with Slate?", "it asks first")
    Check(a.themeColors.bg.r == 1 and e.refreshes == 0, "nothing is replaced before Yes")
    e.build()
    Check(#e.notes == 0, "no hint if it is declined")
    e.confirms[1].yes()
    Check(a.themePreset == "custom" and a.themeColors.bg.r == 0x12 / 255 and e.refreshes == 1,
        "Yes replaces the picks with Slate's and redraws")
    Check(#e.confirms == 1, "no second dialog")
    e.build()
    Check(#e.notes == 1 and e.notes[1] == HINT, "the hint shows")
    start.setValue("default")
    e.confirms[2].yes()
    Check(a.themeColors.bg.r == 0x0e / 255 and a.themeColors.accent.b == 0xed / 255, "the default theme's colors")
end

-- The preview follows the selection.
do
    local function Chips(account) return Page(account).rows[1][2].colors() end
    local function Hex(c)
        return ("%02x%02x%02x"):format(math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
    end
    local default, midnight = Chips({}), Chips({ themePreset = "midnight" })
    Check(Hex(default[1]) == "0e0f11" and Hex(default[6]) == "0091ed", "default: the shipped background and accent")
    Check(Hex(midnight[1]) == "0b1020" and Hex(midnight[4]) == "eef2ff" and Hex(midnight[6]) == "5b8cff",
        "a preset: its own background, text and accent")
    local custom = Chips({ themePreset = "custom", themeColors = { bg = { r = 1, g = 0, b = 0 } } })
    Check(Hex(custom[1]) == "ff0000" and Hex(custom[2]) == "1a1c1f", "custom: the saved pick, the shipped color for the rest")
    local invalid = Chips({ themePreset = "bogus" })
    Check(Hex(invalid[1]) == "0e0f11", "an invalid preset previews the default")
end

-- The chips themselves: the control is cut out of Widgets.lua and run with stub frames.
do
    local widgets = Read("Core/Options/Widgets.lua")
    local widgetConstants = assert(widgets:match("\n(local MEDIA = .-\n)\nlocal UI = {}\n"), "Widgets constants")
    local atEnd = assert(widgets:match("\n(local function AtRowEnd%(.-\nend\n)"), "AtRowEnd")
    local from = assert(widgets:find("local function PaletteChip(", 1, true))
    local upTo = assert(widgets:find("local function ColorPickerControl(", from, true))
    local code = widgetConstants .. atEnd .. widgets:sub(from, upTo - 1)
        .. "local cfg, rgn = ...\nreturn PaletteControl(rgn, cfg)\n"
    local paletteChunk = assert(loadstring(code))
    local frames, painted = {}, {}
    local function Frame()
        local f = { shown = true }
        function f.Show() f.shown = true end
        function f.Hide() f.shown = false end
        frames[#frames + 1] = f
        return setmetatable(f, { __index = function() return function() end end })
    end
    local function Build(colors)
        frames, painted = {}, {}
        local count = 0
        local env = { CreateFrame = Frame, T = { bg = {}, muted = {} },
            ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"), Solid = function()
                count = count + 1
                local index = count
                return { SetAllPoints = function() end,
                    SetColorTexture = function(_, r, g, b, a) painted[index] = { r, g, b, a } end }
            end, Border = function() end } }
        setfenv(paletteChunk, setmetatable(env, { __index = _G }))
        local cfg = { colors = colors }
        local control = paletteChunk(cfg, Frame())
        return control, cfg
    end
    local function Shown()
        local n = 0
        for i = 3, #frames do if frames[i].shown then n = n + 1 end end
        return n
    end
    local function List(count, r)
        local out = {}
        for i = 1, count do out[i] = { r = r, g = 0, b = 0 } end
        return out
    end
    local control, cfg = Build(function() return List(6, 1) end)
    Check(#frames == 8 and control._refreshValue, "the rgn, one frame for the row of chips and one for each chip")
    Check(#painted == 6 and painted[1][1] == 1 and painted[6][4] == 1, "every chip is painted from cfg.colors()")
    cfg.colors = function() return List(2, 0.5) end
    control._refreshValue()
    Check(painted[1][1] == 0.5 and painted[2][1] == 0.5 and painted[3][1] == 1, "a refresh repaints from the current colors")
    Check(#frames == 8 and Shown() == 2, "fewer colors hide the extra chips and build nothing")
    ---@diagnostic disable-next-line: duplicate-set-field
    cfg.colors = function() return List(8, 0.25) end
    control._refreshValue()
    Check(#frames == 10 and Shown() == 8 and #painted == 8 and painted[8][1] == 0.25, "more colors build only the missing chips and show them all")
    Check(Build(function() return List(3, 1) end) and #frames == 5 and Shown() == 3, "one chip per color from the start")
    Check(Build(function() return {} end) and #frames == 2 and Shown() == 0, "no colors, no chips")
end

-- The RESTEDXP section.
do
    local function Toggle(e)
        for _, row in ipairs(e.rows) do
            if row[1].text == "RestedXP Theme (V1)" then return row[1], row[2] end
        end
    end
    local function Pair(page, name)
        for _, row in ipairs(page.rows) do
            if row[1].text == name then return row[1], row[2] end
        end
    end
    local function Hidden(page)
        for _, name in ipairs({ "RestedXP Theme", "RestedXP Arrow", "Naowh Arrow Shape", "Naowh Arrow Glow", "Naowh Arrow Size", "Show Arrow Text", "Naowh Arrow Text Gap", "Use Addon Font",
                "Use Theme Text Color" }) do
            for _, row in ipairs(page.rows) do
                if row[1].text == name or (row[2] and row[2].text == name) then return false end
            end
        end
        return true
    end
    -- the RestedXP rows after the Theme rows, each as "left|right"
    local function Layout(page)
        local out = {}
        for i = #page.rows, 1, -1 do
            local row = page.rows[i]
            table.insert(out, 1, (row[1].text or "") .. "|" .. (row[2] and row[2].text or ""))
            if row[1].text == "RestedXP Theme (V1)" then break end
        end
        return table.concat(out, ", ")
    end
    Check(Toggle(Page({})) == nil and Toggle(Page({}, false)) == nil, "no RestedXP toggle without RestedXP Guides")
    Check(table.concat(Page({}).headers, ",") == "COLORS", "and no RESTEDXP section either")
    local a = {}
    local e = Page(a, true)
    local toggle, beside = Toggle(e)
    Check(table.concat(e.headers, ",") == "COLORS,RESTEDXP THEME (V1),RESTEDXP NAOWH WINDOW (V2),RESTEDXP ARROW",
        "RestedXP Guides installed: V1's section, V2's, and the arrow's own while neither is on")
    Check(toggle and toggle.type == "toggle", "the toggle is there with RestedXP Guides installed")
    Check(toggle.getValue() == false and a.rxpThemes == nil, "off by default")
    Check(toggle.tooltip == "Adds the Naowh themes to RestedXP's theme list, in place of the Naowh window.",
        "its tooltip is one short sentence")

    Check(beside.type == "label" and beside.text == "", "nothing is beside the toggle")
    local NEEDS = "Turn on RestedXP's Beta Features and V2 interface."
    Check(Layout(e) == "RestedXP Theme (V1)|, RestedXP Naowh Window (V2)|" .. NEEDS .. ", Style RestedXP's Arrow|",
        "with them off: the toggle of V1, of V2 with its note, and the arrow's own switch, and nothing else")
    Check(Hidden(e), "and none of the other RestedXP choices is shown")
    local window, need = Pair(e, "RestedXP Naowh Window (V2)")
    Check(window and window.type == "toggle" and window.getValue() == false and a.rxpWindow == nil,
        "a RestedXP Naowh Window (V2) toggle, off by default")
    Check(need.type == "label" and need.text == NEEDS, "with a note beside it while RestedXP's V2 interface is off")
    Check(Pair(e, "Naowh Window Width") == nil, "and no width or steps while it is off")
    window.setValue(true)
    Check(a.rxpWindow == true, "on is stored")
    e.build()
    local width, steps = Pair(e, "Naowh Window Width")
    Check(width and width.type == "slider" and width.min == 260 and width.max == 640 and width.step == 1
        and steps and steps.text == "Upcoming Steps" and steps.min == 0 and steps.max == 12 and steps.step == 1,
        "on: the window's width and the steps listed after the active one")
    local scale = Pair(e, "Naowh Window Scale")
    Check(scale and scale.type == "slider" and scale.min == 60 and scale.max == 200 and scale.step == 5,
        "and its size, as a percent of its own")
    width.setValue(900)
    steps.setValue(3)
    scale.setValue(150)
    Check(a.rxpWindowWidth == 640 and a.rxpWindowSteps == 3 and a.rxpWindowScale == 150,
        "a width is held to its range and a step count and a scale are stored")
    width.setValue(380)
    steps.setValue(6)
    scale.setValue(100)
    Check(a.rxpWindowWidth == nil and a.rxpWindowSteps == nil and a.rxpWindowScale == nil,
        "and the defaults are not stored")
    Pair(e, "RestedXP Naowh Window (V2)").setValue(false)
    Check(a.rxpWindow == nil, "off is not stored")
    Check(#e.notes == 0, "no hint before a change")
    local refreshed = e.refreshes
    toggle.setValue(true)
    Check(a.rxpThemes == true and e.refreshes == refreshed + 1 and #e.confirms == 0, "on is stored and the page redraws")
    e.build()
    Check(Toggle(e).getValue() == true and #e.notes == 1 and e.notes[1] == RXP_HINT, "it reads back, and the RestedXP reload hint shows")
    Check(not Hidden(e), "and the choices are shown")

    Check(Layout(e) == "RestedXP Theme (V1)|Reload UI to pick a theme., Use Addon Font|Use Theme Text Color, Style RestedXP's Arrow|, RestedXP Naowh Window (V2)|" .. NEEDS,
        "with the themes just turned on: a note beside the toggle in place of the theme, the font and text color, the arrow's switch as it was (off), and the window")
    local _, waiting = Pair(e, "RestedXP Theme (V1)")
    Check(waiting.type == "label" and waiting.getValue == nil, "RestedXP has not started with the themes yet: a note, not a dropdown")

    -- RestedXP up with the themes in its list: the dropdown, which is RestedXP's own setting
    local up = RxpStub("RXP Blue")
    local u = Page({ rxpThemes = true }, true, up)
    Check(Layout(u) == "RestedXP Theme (V1)|RestedXP Theme, Use Addon Font|Use Theme Text Color, Style RestedXP's Arrow|, RestedXP Arrow|, Show Arrow Text|, Arrow Shows Objective|Arrow Text Size, Arrow Addon Font|, RestedXP Naowh Window (V2)|" .. NEEDS,
        "with RestedXP started: the toggle with the theme beside it, the font and text color, and the arrow's own rows")
    local switch, picker = Pair(u, "RestedXP Theme (V1)")
    Check(switch and picker.type == "dropdown" and picker.text == "RestedXP Theme", "the theme is a dropdown beside the toggle")
    Check(picker.getValue() == "" and u.account.rxpTheme == nil, "RestedXP's own while RestedXP is on its own, and nothing stored")
    local presets = u.ns.THEME_PRESET_ORDER
    Check(#picker.order == #presets + 3 and picker.order[1] == "" and picker.order[2] == "current" and picker.order[3] == "default"
        and picker.order[#picker.order] == presets[#presets]
        and picker.values[""] == "RestedXP (default)" and picker.values.current == "Current Theme" and picker.values.default == "Naowh"
        and picker.values.crimson == "Crimson", "RestedXP (default), Current Theme, Naowh and every preset")
    Check(picker.tooltip == "The theme RestedXP uses: its own, or one of the Naowh themes.", "its tooltip is one short sentence")
    Check(picker.disabled == nil, "never greyed out: it is not shown when it does not apply")
    picker.setValue("crimson")
    Check(up.settings.profile.activeTheme == "NaowhForever:crimson" and picker.getValue() == "crimson" and #up.reloads == 1,
        "a pick is RestedXP's own setting, and RestedXP reloads onto it")
    Check(u.refreshes == 0 and u.account.rxpTheme == nil, "the page is not redrawn, and nothing of ours is stored")
    u.build()
    Check(#u.notes == 0, "and no reload note: it shows at once")
    picker.setValue("current")
    Check(up.settings.profile.activeTheme == "NaowhForever:current" and picker.getValue() == "current", "so is the current theme")
    picker.setValue("")
    Check(up.settings.profile.activeTheme == "Default" and picker.getValue() == "", "RestedXP (default) puts RestedXP back on its own")

    -- RestedXP's live reload off: the theme shows after a reload, so the note does
    local quiet = RxpStub("RXP Blue", false)
    local q = Page({ rxpThemes = true }, true, quiet)
    local _, quietPicker = Pair(q, "RestedXP Theme (V1)")
    quietPicker.setValue("crimson")
    Check(quiet.settings.profile.activeTheme == "NaowhForever:crimson" and #quiet.reloads == 0 and q.refreshes == 1,
        "RestedXP's live reload off: the pick is set, RestedXP is not reloaded, and the page redraws")
    q.build()
    Check(#q.notes == 1 and q.notes[1] == RXP_HINT, "with the reload note")
    a = { rxpThemes = true, rxpArrowOn = true }
    e = Page(a, true)
    local arrow, noShape = Pair(e, "RestedXP Arrow")
    Check(arrow and arrow.type == "dropdown" and noShape.type == "label" and noShape.text == "",
        "the arrow choice is the next row, with nothing beside it until Naowh arrow is picked")
    Check(#arrow.order == 3 and arrow.order[1] == "layer" and arrow.values.layer == "Colored layer"
        and arrow.values.image == "Naowh arrow" and arrow.values.off == "RestedXP's own", "three ways to draw it")
    Check(arrow.getValue() == "layer" and arrow.disabled == nil, "a layer by default, and never greyed out: it is only shown with the themes on")
    refreshed = e.refreshes
    arrow.setValue("image")
    Check(a.rxpArrow == "image" and arrow.getValue() == "image" and e.refreshes == refreshed + 1,
        "the choice is stored, and the page redraws so the choices below follow it")
    arrow.setValue("layer")
    Check(a.rxpArrow == nil, "the default is stored as nothing")

    Check(Pair(e, "Naowh Arrow Shape") == nil and Pair(e, "Naowh Arrow Size") == nil,
        "with the layer as the arrow style, the choices for Naowh's arrow are not shown")
    local imaged = Page({ rxpThemes = true, rxpArrow = "image" }, true, RxpStub("RXP Blue"))
    Check(Layout(imaged) == "RestedXP Theme (V1)|RestedXP Theme, Use Addon Font|Use Theme Text Color, Style RestedXP's Arrow|, "
        .. "RestedXP Arrow|Naowh Arrow Shape, Naowh Arrow Glow|Naowh Arrow Size, "
        .. "Show Arrow Text|Naowh Arrow Text Gap, Arrow Shows Objective|Arrow Text Size, Arrow Addon Font|, RestedXP Naowh Window (V2)|" .. NEEDS,
        "with Naowh arrow picked: the arrow and its shape, its glow and size, the arrow text and its gap, what it says, and its font")
    local _, shape = Pair(imaged, "RestedXP Arrow")
    local glow, size = Pair(imaged, "Naowh Arrow Glow")
    Check(shape.type == "dropdown" and glow.type == "toggle" and size.type == "slider", "a dropdown, a toggle and a slider")
    Check(#shape.order == 2 and shape.order[1] == "kite" and shape.order[2] == "wide" and shape.values.kite == "Kite"
        and shape.values.wide == "Wide kite", "a kite or a wide kite")
    Check(shape.getValue() == "kite" and glow.getValue() == false, "a kite without a glow by default")
    Check(shape.disabled == nil and glow.disabled == nil, "and never greyed out")
    shape.setValue("wide")
    glow.setValue(true)
    Check(imaged.account.rxpArrowShape == "wide" and imaged.account.rxpArrowGlow == true and shape.getValue() == "wide"
        and glow.getValue() == true, "the choices are stored")
    shape.setValue("kite")
    glow.setValue(false)
    Check(imaged.account.rxpArrowShape == nil and imaged.account.rxpArrowGlow == nil, "the defaults are stored as nothing")
    Check(size.min == 60 and size.max == 200 and size.step == 5 and size.getValue() == 90, "from 60 to 200, 90 by default")
    size.setValue(150)
    Check(imaged.account.rxpArrowSize == 150 and size.getValue() == 150 and imaged.refreshes == 0, "a size is stored, and the page is not redrawn")
    size.setValue(90)
    Check(imaged.account.rxpArrowSize == nil, "the default is stored as nothing")
    local arrowText, gap = Pair(imaged, "Show Arrow Text")
    Check(arrowText.type == "toggle" and arrowText.getValue() == true and arrowText.disabled == nil, "the arrow text is a switch, on by default")
    arrowText.setValue(false)
    Check(imaged.account.rxpArrowText == false and arrowText.getValue() == false and imaged.refreshes == 0, "off is stored, and the page is not redrawn")
    arrowText.setValue(true)
    Check(imaged.account.rxpArrowText == nil, "on is stored as nothing")
    Check(gap.type == "slider" and gap.min == 0 and gap.max == 20 and gap.step == 1 and gap.getValue() == 4,
        "the text gap is a slider from 0 to 20, 4 by default")
    gap.setValue(9)
    Check(imaged.account.rxpArrowGap == 9 and gap.getValue() == 9 and imaged.refreshes == 0, "a gap is stored, and the page is not redrawn")
    gap.setValue(4)
    Check(imaged.account.rxpArrowGap == nil, "the default is stored as nothing")

    local font, text = Pair(e, "Use Addon Font")
    Check(font and text and font.type == "toggle" and text.type == "toggle", "two more switches, in one row")
    Check(text.text == "Use Theme Text Color", "named for what they do")
    Check(font.getValue() == true and text.getValue() == true, "both on by default")
    Check(font.disabled == nil and text.disabled == nil, "and never greyed out")
    Check(font.tooltip == "RestedXP's text uses your Addon Font." and text.tooltip == "RestedXP's text uses the theme's Text color.",
        "each says what it does")

    -- every tooltip in the section is one short sentence, with no numbers
    local count = 0
    for _, page in ipairs({ u, imaged }) do
        local inSection
        for _, row in ipairs(page.rows) do
            inSection = inSection or row[1].text == "RestedXP Theme (V1)"
            for _, cfg in ipairs(inSection and row or {}) do
                if cfg.tooltip then
                    count = count + 1
                    Check(#cfg.tooltip < 100 and not cfg.tooltip:find("|n", 1, true) and not cfg.tooltip:find("%d")
                        and select(2, cfg.tooltip:gsub("[%.!?]", "")) == 1, "one short sentence: " .. cfg.tooltip)
                end
            end
        end
    end
    Check(count >= 11, "every row's tooltip was checked")

    local fp = Page({ rxpThemes = true }, true)
    local fpFont, fpText = Pair(fp, "Use Addon Font")
    fpFont.setValue(false)
    fp.build()
    Check(fp.account.rxpFont == false and fp.account.rxpTextColor == nil and fpFont.getValue() == false and fpText.getValue() == true
        and fp.refreshes == 1 and #fp.notes == 1 and fp.notes[1] == RXP_HINT, "the font alone: stored, the page redraws, and the reload hint shows")
    fpFont.setValue(true)
    Check(fp.account.rxpFont == nil and fpFont.getValue() == true, "on is stored as nothing")
    local tp = Page({ rxpThemes = true }, true)
    local tpFont, tpText = Pair(tp, "Use Addon Font")
    tpText.setValue(false)
    tp.build()
    Check(tp.account.rxpTextColor == false and tp.account.rxpFont == nil and tpText.getValue() == false and tpFont.getValue() == true
        and tp.refreshes == 1 and #tp.notes == 1 and tp.notes[1] == RXP_HINT, "the text color alone: the same")

    local both = Page({ rxpThemes = true }, true)
    both.theme.setValue("crimson")
    both.build()
    Check(#both.notes == 1 and both.notes[1] == HINT, "a color change brings up the color hint, not the RestedXP one")
    local bothFont = Pair(both, "Use Addon Font")
    bothFont.setValue(false)
    both.build()
    Check(#both.notes == 2 and both.notes[1] == HINT and both.notes[2] == RXP_HINT,
        "and after a RestedXP change as well, both: the color one first")

    -- a fresh page: the slice is rebuilt in the newest page's environment
    local again = Page({ rxpThemes = true }, true)
    Toggle(again).setValue(false)
    again.build()
    Check(again.account.rxpThemes == nil, "off clears it")
    local themeHidden = true
    for _, name in ipairs({ "RestedXP Theme", "Use Addon Font", "Use Theme Text Color" }) do
        if Pair(again, name) then themeHidden = false end
    end
    Check(themeHidden and select(2, Toggle(again)).type == "label" and Pair(again, "RestedXP Arrow") ~= nil,
        "and the theme's choices are hidden again, the arrow's being its own as they were")

    local plain = #Page({ themePreset = "custom" }).rows
    local custom = Page({ themePreset = "custom" }, true)
    Check(Toggle(custom) and #custom.rows == plain + 3, "with Custom and everything off, RestedXP adds three rows: the theme's, the arrow's and the window's")
    Check(custom.rows[#custom.rows][1].text == "Style RestedXP's Arrow", "and the arrow's own is the last, above the Reload button")
    local onCustom = Page({ themePreset = "custom", rxpThemes = true }, true)
    Check(#onCustom.rows == plain + 9, "with the themes on, RestedXP adds nine rows: the toggle and theme, the font and text, the arrow's switch, its style, its text, what it says, its font, the set up and the window")
    Check(onCustom.rows[#onCustom.rows][1].text == "RestedXP Naowh Window (V2)", "and the window row is the last, above the Reload button")
    local onImage = Page({ themePreset = "custom", rxpThemes = true, rxpArrow = "image" }, true)
    Check(#onImage.rows == plain + 10, "with Naowh arrow picked, one more: the glow and size")
    local objective, size = Pair(onImage, "Arrow Shows Objective")
    Check(objective and objective.type == "toggle" and objective.getValue() == false and onImage.account.rxpArrowObjective == nil,
        "an Arrow Shows Objective toggle, off by default")
    Check(size and size.type == "slider" and size.text == "Arrow Text Size" and size.min == 8 and size.max == 24
        and size.step == 1 and size.getValue() == 13, "and the arrow text's size beside it, 13 to start")
    size.setValue(18)
    Check(onImage.account.rxpArrowTextSize == 18, "a size is stored")
    size.setValue(13)
    Check(onImage.account.rxpArrowTextSize == nil, "and the default is not")
    objective.setValue(true)
    Check(onImage.account.rxpArrowObjective == true, "on is stored")
    objective.setValue(false)
    Check(onImage.account.rxpArrowObjective == nil, "and off is not")
end

-- The Naowh guide window's look: a row for each thing it can be changed in, from its own list.
do
    -- the window's look: a row for each thing it can be changed in, from its own list
    local styled = {}
    local s = Page({ rxpWindow = true }, true)
    Check(table.concat(s.headers, ","):find("WINDOW LOOK", 1, true) ~= nil, "a WINDOW LOOK section with it on")
    Check(table.concat(Page({}, true).headers, ","):find("WINDOW LOOK", 1, true) == nil, "and none with it off")
    local cells = {}
    for _, row in ipairs(s.rows) do
        for _, cell in ipairs(row) do cells[#cells + 1] = cell end
    end
    local function Cell(text)
        for _, cell in ipairs(cells) do
            if cell.text == text then return cell end
        end
    end
    for _, option in ipairs(s.ns.RXPWindowOptions()) do
        local cell = Cell(option.label)
        local want = { toggle = "toggle", number = "slider", choice = "dropdown", font = "dropdown",
            texture = "dropdown" }
        Check(cell and cell.type == want[option.kind] and cell.tooltip == option.tip, option.label .. ": its row")
        styled[option.key] = cell
    end
    for _, color in ipairs(s.ns.RXPWindowColors()) do
        local cell = Cell(color.label)
        Check(cell and cell.type == "colorpicker" and cell.hasAlpha == not color.opaque, color.label .. ": its swatch")
        local r, g, b, alpha = cell.getValue()
        Check(type(r) == "number" and type(g) == "number" and type(b) == "number" and type(alpha) == "number",
            color.label .. ": it reads a color")
        cell.setValue(0.25, 0.5, 0.75, 0.5)
        Check(s.account.rxpWindowColors[color.name].g == 0.5
            and select(4, cell.getValue()) == (color.opaque and 1 or 0.5), color.label .. ": and keeps one picked")
    end
    local size = styled.rxpWindowTitleSize
    Check(size.min == 10 and size.max == 28 and size.step == 1 and size.getValue() == 16, "a size has its range and start")
    size.setValue(20)
    Check(s.account.rxpWindowTitleSize == 20 and size.getValue() == 20, "a size picked is kept")
    local outline = styled.rxpWindowOutline
    Check(outline.values.shadow == "Shadow" and outline.order[1] == "shadow", "a choice has its own words")
    outline.setValue("outline")
    Check(s.account.rxpWindowOutline == "outline", "and keeps the one picked")
    local reset = Cell("Window Look")
    Check(reset and reset.type == "button" and reset.buttonText == "Reset", "a button puts the look back")
    local refreshed = s.refreshes
    reset.onClick()
    Check(s.account.rxpWindowColors == nil and s.account.rxpWindowTitleSize == nil
        and s.account.rxpWindowOutline == nil and s.refreshes == refreshed + 1, "it clears them and redraws the page")
end

do
    -- setting a character up: only when themes or the window are wished for, off to start, and a button for the one played
    local function Cells(page)
        local out = {}
        for _, row in ipairs(page.rows) do
            for _, cell in ipairs(row) do out[cell.text] = cell end
        end
        return out
    end
    local none = Cells(Page({}, true))
    Check(none["Set Up New Characters"] == nil and none["This Character"] == nil,
        "nothing wished for: no row of it")
    local s = Page({ rxpThemes = true }, true)
    local cells = Cells(s)
    local toggle, button = cells["Set Up New Characters"], cells["This Character"]
    Check(toggle and toggle.type == "toggle" and toggle.getValue() == false, "with themes wished for: a switch, off to start")
    Check(button and button.type == "button" and button.buttonText == "Set Up", "and a button for the character played")
    toggle.setValue(true)
    Check(s.account.rxpSetup == true and toggle.getValue() == true, "turned on, it is kept")
    toggle.setValue(false)
    Check(s.account.rxpSetup == nil, "and the default is not")
    local w = Page({ rxpWindow = true }, true)
    Check(Cells(w)["Set Up New Characters"] ~= nil, "the window wished for is enough")
    local refreshed = s.refreshes
    s.ns.RXPSetUpCharacter = function() return "reload" end
    button.onClick()
    Check(s.refreshes == refreshed + 1, "the button draws the page again with its reload note")
    s.ns.RXPSetUpCharacter = function() return nil end
    button.onClick()
    Check(s.refreshes == refreshed + 2, "and when nothing needed a reload")
end

do
    -- the old theme, the arrow and the window: three sections of their own
    local function Cells(page)
        local out = {}
        for _, row in ipairs(page.rows) do
            for _, cell in ipairs(row) do out[cell.text] = cell end
        end
        return out
    end
    local s = Page({}, true)
    local cells = Cells(s)
    Check(table.concat(s.headers, ","):find("RESTEDXP,", 1, true) == nil, "nothing wished for: no section of shared rows")
    local arrow = cells["Style RestedXP's Arrow"]
    Check(arrow and arrow.type == "toggle" and arrow.getValue() == false, "the arrow has a switch of its own, off to start")
    Check(cells["RestedXP Arrow"] == nil and cells["Show Arrow Text"] == nil and cells["Arrow Addon Font"] == nil,
        "and its rows are not shown while it is off")
    arrow.setValue(true)
    Check(s.account.rxpArrowOn == true, "turned on, it is kept")
    s.build()
    cells = Cells(s)
    Check(cells["RestedXP Arrow"] and cells["Show Arrow Text"] and cells["Arrow Shows Objective"]
        and cells["Arrow Addon Font"], "and its rows are there, with no theme turned on")
    arrow.setValue(false)
    Check(s.account.rxpArrowOn == false, "off is kept as off, so that a theme does not turn it on again")

    -- the arrow's font is its own, and so is the theme's
    local f = Page({ rxpArrowOn = true }, true)
    local font = Cells(f)["Arrow Addon Font"]
    Check(font and font.type == "toggle" and font.getValue() == true, "the arrow's font is a switch of its own, on to start")
    font.setValue(false)
    Check(f.account.rxpArrowFont == false and f.ns.RXPFontEnabled() == true, "and not the theme's")

    -- the window on: the theme's toggle reads off, and turning it on turns the window off
    local w = Page({ rxpThemes = true, rxpWindow = true }, true)
    local themes = Cells(w)["RestedXP Theme (V1)"]
    Check(themes.getValue() == false, "saved with both on, the window is used and the theme reads off")
    local before = w.account.rxpWindow
    Check(before == true, "the window is on")
    themes.setValue(true)
    Check(w.account.rxpThemes == true and w.account.rxpWindow == nil, "the theme turned on turns the window off")
end

do
    -- the arrow's options are in V1 and in V2, and on their own when neither is on: once on the page
    local function Count(page, name)
        local count = 0
        for _, row in ipairs(page.rows) do
            for _, cell in ipairs(row) do
                if cell.text == name then count = count + 1 end
            end
        end
        return count
    end
    local function Has(page, header)
        return ("," .. table.concat(page.headers, ",") .. ","):find("," .. header .. ",", 1, true) ~= nil
    end
    local neither = Page({}, true)
    Check(Count(neither, "Style RestedXP's Arrow") == 1 and Has(neither, "RESTEDXP ARROW"),
        "neither on: the arrow's options have a section of their own")
    local v1 = Page({ rxpThemes = true, rxpArrowOn = true }, true)
    Check(Count(v1, "Style RestedXP's Arrow") == 1 and Count(v1, "RestedXP Arrow") == 1 and not Has(v1, "RESTEDXP ARROW")
        and Has(v1, "RESTEDXP THEME (V1)"), "V1 on: the arrow's options are in V1's section, once")
    local v2 = Page({ rxpWindow = true, rxpArrowOn = true }, true)
    Check(Count(v2, "Style RestedXP's Arrow") == 1 and Count(v2, "RestedXP Arrow") == 1 and not Has(v2, "RESTEDXP ARROW")
        and Has(v2, "RESTEDXP NAOWH WINDOW (V2)") and Has(v2, "WINDOW LOOK"),
        "V2 on: the arrow's options are in V2's section, once, before the window's look")
    Check(Count(v2, "Use Addon Font") == 0 and Count(v1, "Naowh Window Width") == 0,
        "and what is of the one is not in the other")
    local function Position(page, name)
        local at = 0
        for _, row in ipairs(page.rows) do
            for _, cell in ipairs(row) do
                at = at + 1
                if cell.text == name then return at end
            end
        end
    end
    local firstLook
    for _, option in ipairs(v2.ns.RXPWindowOptions()) do
        if option.group == "Text" and not firstLook then firstLook = option.label end
    end
    local sliders, arrow, look = Position(v2, "Naowh Window Scale"), Position(v2, "Style RestedXP's Arrow"), Position(v2, firstLook)
    Check(sliders and arrow and look and sliders < arrow and arrow < look,
        "V2: the window's sliders, then the arrow's options, then the window's look")
end

print("PASS custom colors page: " .. cases .. " checks")

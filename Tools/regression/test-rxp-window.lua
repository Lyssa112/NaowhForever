-- The Naowh guide window for RestedXP (Core/Integrations/RestedXP/Window.lua), run against the real Core with
-- RestedXP stood in for by plain tables. Run with Lua 5.1 from the repository root.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"); f:close()
    return s
end
local coreSource = Read("Core/Core.lua")
local featuresSource = Read("Core/Features.lua")
local themesSource = Read("Core/Integrations/RestedXP/Themes.lua")
local windowSource = Read("Core/Integrations/RestedXP/Window.lua")

local cases = 0
local function Check(ok, label) assert(ok, label); cases = cases + 1 end

-- A frame, a font string or a texture: it keeps what it was told, and every other method does nothing.
local function Object(everything)
    local o = { shown = true, points = {}, scripts = {}, kids = {}, width = 0, height = 0 }
    setmetatable(o, { __index = function(_, key)
        if type(key) == "string" and key:find("^%u") then return function() end end
    end })
    function o:SetText(text) self.text = text end
    function o:GetText() return self.text end
    function o:GetStringHeight() return 12 end
    function o:SetWidth(w) self.width = w end
    function o:SetHeight(h) self.height = h end
    function o:SetSize(w, h) self.width, self.height = w, h end
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false end
    function o:IsShown() return self.shown end
    function o:SetParent(parent) self.parent = parent end
    function o:ClearAllPoints() self.points = {} end
    function o:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function o:GetPoint(i)
        local p = self.points[i or 1]
        if p then return unpack(p) end
    end
    function o:SetScript(name, fn) self.scripts[name] = fn end
    function o:SetTextColor(r, g, b) self.color = { r, g, b } end
    function o:SetColorTexture(r, g, b, a) self.solid = { r, g, b, a } end
    function o:SetFont(path, size, flags) self.font, self.fontSize, self.fontFlags = path, size, flags end
    function o:SetAlpha(a) self.alpha = a end
    function o:GetAlpha() return self.alpha or 1 end
    function o:EnableMouse(on) self.mouse = on end
    function o:IsMouseEnabled() return self.mouse ~= false end
    function o:IsForbidden() return false end
    function o:GetChildren() return unpack(self.kids) end
    function o:CreateFontString()
        local fs = Object(everything)
        fs.parent = self
        everything[#everything + 1] = fs
        return fs
    end
    function o:CreateTexture()
        local t = Object(everything)
        t.parent = self
        everything[#everything + 1] = t
        return t
    end
    function o:Click() self.clicks = (self.clicks or 0) + 1 end
    function o:SetScale(scale) self.scale = scale end
    function o:GetScale() return self.scale or 1 end
    function o:StartMoving() self.moving = true end
    function o:StopMovingOrSizing() self.moving = false end
    return o
end

-- The game, RestedXP's pieces and our window; each call builds a fresh one.
local function World(account, opts)
    opts = opts or {}
    local w = { everything = {}, timers = {}, frames = {}, menus = 0, links = {} }
    local env = { hooked = {} }
    env._G = env
    env.UIParent = Object(w.everything)
    env.GameTooltip = Object(w.everything)
    function env.GameTooltip:GetOwner() return self.owner end
    function env.GameTooltip:SetOwner(owner) self.owner = owner end
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    env.CreateColor = function(r, g, b, a) return { r, g, b, a } end
    env.InCombatLockdown = function() return false end
    env.C_AddOns = { DoesAddOnExist = function(name) return opts.installed ~= false and name == "RXPGuides" end }
    env.C_Timer = { After = function(_, fn) w.timers[#w.timers + 1] = fn end }
    env.SetItemRef = function(link) w.links[#w.links + 1] = link end
    env.NaowhForeverDB = { account = account, profiles = {}, charActive = {} }
    env.CreateFrame = function(_, name, parent)
        local f = Object(w.everything)
        f.name, f.parent = name, parent
        if parent and parent.kids then parent.kids[#parent.kids + 1] = f end
        w.frames[#w.frames + 1] = f
        if name then env[name] = f end
        return f
    end
    env.hooksecurefunc = function(tbl, name, fn)
        local original = tbl[name]
        tbl[name] = function(...)
            local results = { original(...) }
            fn(...)
            return unpack(results)
        end
    end
    setmetatable(env, { __index = _G })
    for _, part in ipairs({ { coreSource, "Core" }, { featuresSource, "Features" } }) do
        local chunk = assert(loadstring(part[1], part[2]))
        setfenv(chunk, env)
        chunk("NaowhForever")
    end
    local ns = env.NaowhForever
    -- what draws needs the client's pixel fitting, which the stand-ins have none of
    w.solids, w.borders = {}, {}
    ns.Solid = function(parent, layer)
        local o = Object(w.everything)
        o.parent, o.layer = parent, layer
        w.solids[#w.solids + 1] = o
        return o
    end
    ns.Border = function(parent)
        w.borders[#w.borders + 1] = parent
        return {}
    end
    ns.Hairline = function() end
    ns.AddonFontPath = function() return "Fonts\\Naowh.ttf" end
    for _, part in ipairs({ { themesSource, "Themes" }, { windowSource, "Window" } }) do
        local chunk = assert(loadstring(part[1], part[2]))
        setfenv(chunk, env)
        chunk("NaowhForever")
    end
    w.env, w.ns = env, ns
    return w
end

-- RestedXP as v2 leaves it: a guide, its progress, an active step with live rows, and the steps that follow.
local function Rxp(w, opts)
    opts = opts or {}
    local env = w.env
    local steps = {}
    for i = 1, 66 do steps[i] = { index = i, elements = {} } end
    local function Row(text, tag, icon, done)
        local frame = { text = Object(w.everything), icon = Object(w.everything), button = Object(w.everything) }
        frame.text:SetText(text)
        frame.icon:SetText(icon)
        function frame.button:GetChecked() return done == true end
        return frame
    end
    local talk = { text = "Talk to Duokna", tag = "target", frame = Row("Talk to |cff00ff00Duokna|r", "target", "|Ttalk|t", false) }
    local buy = { text = "Buy", tag = "buy", frame = Row("Buy [Refreshing Spring Water] from her", "buy", "|Tbuy|t", false) }
    local vendor = { text = "Vendor Trash", tag = "vendor", frame = Row("Vendor Trash", "vendor", "|Tv|t", true) }
    local active = { active = true, index = 36, title = "Step 36", elements = { talk, buy, vendor } }
    local tipOnly = { active = true, index = 37, hidewindow = true, elements = { { text = "A tip" } } }
    local idle = { active = false, index = 38, elements = { { text = "Not active" } } }
    local rows = {}
    for i = 37, 50 do
        rows[#rows + 1] = { index = i, text = "Step " .. i .. " line one\nline two", hidden = false, complete = false }
    end
    table.insert(rows, 1, { index = 36, text = "Talk to Duokna", hidden = false, complete = false, current = true })
    table.insert(rows, 1, { index = 35, text = "Done", hidden = false, complete = true })
    rows[4].hidden = true   -- 38 is a step RestedXP hides
    rows[7].complete = true   -- and 41 is done already
    rows[5].text = "|TInterface\\Icons\\Talk:0|t |cff00ff00Talk to Gornek|r\nline two"   -- 39 has an icon and a color
    local rxp = {
        currentGuide = { name = "1-6 Durotar", steps = steps },
        player = { name = "Tester" },
        icons = {},
        locale = { Get = function(text) return text end },
        RXPFrame = { activeSteps = { active, tipOnly, idle }, DropDownMenu = function() w.menus = w.menus + 1 end },
        v2 = { snapshots = 0 },
        SetStep = function() end,
    }
    function rxp.GetGuideProgress() return 36, "id" end
    function rxp.GetGuideName(guide) return guide.name end
    function rxp.v2:IsGuideWindowEnabled() return opts.v2 ~= false end
    function rxp.v2:BuildGuideStepsSnapshot()
        self.snapshots = self.snapshots + 1
        if opts.snapshotRaises then error("snapshot") end
        return { title = "", rows = rows }
    end
    function rxp.v2:UpdateGuideWindow() end
    function rxp.v2:UpdateActiveStepsFrame() end
    function rxp.v2:UpdatePlayerActiveStepItem() end
    env.RXP = rxp
    -- RestedXP's two v2 windows, with children that take the mouse
    local guide = { frame = Object(w.everything) }
    local button = Object(w.everything)
    guide.frame.kids[1] = button
    guide.frame:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 12, -240)
    local stepsFrame = { frame = Object(w.everything) }
    local checkbox = Object(w.everything)
    stepsFrame.frame.kids[1] = checkbox
    env.RXPV2GuideWindow = guide
    env.RXPActiveStepsFrameTester = stepsFrame
    w.rxp, w.guide, w.steps, w.rows, w.active, w.button, w.checkbox = rxp, guide, stepsFrame, rows, active, button, checkbox
    w.talk, w.buy, w.vendor = talk, buy, vendor
    return rxp
end

-- The module's own boot frame is the last one made at load: the game tells it the addon loaded, then that
-- the player is in.
local function Start(account, opts)
    local w = World(account, opts)
    Rxp(w, opts)
    local boot
    for _, f in ipairs(w.frames) do boot = f end
    w.boot = boot
    boot.scripts.OnEvent(boot, "ADDON_LOADED", "NaowhForever")
    boot.scripts.OnEvent(boot, "PLAYER_LOGIN")
    return w
end

local function Flush(w)
    local timers = w.timers
    w.timers = {}
    for _, fn in ipairs(timers) do fn() end
end

local function Window(w) return w.env.NaowhRXPWindow end

-- shown, and everything it hangs from shown
local function Seen(o)
    while o do
        if o.shown == false then return false end
        o = o.parent
    end
    return true
end

local function Texts(w, owner)
    local out = {}
    for _, o in ipairs(w.everything) do
        if o.parent == owner and o.text then out[#out + 1] = o.text end
    end
    return out
end

-- off by default: nothing is built, and RestedXP's windows are as they were
do
    local w = Start({})
    Flush(w)
    Check(Window(w) == nil, "the window is off by default: nothing is built")
    Check(w.guide.frame.alpha == nil and w.steps.frame.alpha == nil and w.guide.frame.mouse == nil,
        "and RestedXP's windows are left alone")
    Check(w.ns.RXPWindowEnabled() == false and w.ns.RXPWindowWidth() == 380 and w.ns.RXPWindowSteps() == 6
        and w.ns.RXPWindowScale() == 100, "the defaults: off, 380 wide, six steps after the active one, full size")
    local wild = Start({ rxpWindowWidth = 9999, rxpWindowSteps = -5, rxpWindowScale = 900 })
    Check(wild.ns.RXPWindowWidth() == 640 and wild.ns.RXPWindowSteps() == 0 and wild.ns.RXPWindowScale() == 200,
        "a width, a count and a scale out of range are held")
    local odd = Start({ rxpWindowWidth = "wide", rxpWindowSteps = "many", rxpWindowScale = "big" })
    Check(odd.ns.RXPWindowWidth() == 380 and odd.ns.RXPWindowSteps() == 6 and odd.ns.RXPWindowScale() == 100,
        "and what is no number is the default")
end

-- on: the heading, the progress, the active step and the steps after it
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local f = Window(w)
    Check(f ~= nil and f.shown and f.width == 380 and f.scale == 1, "on: the window is built, shown, at its width and size")
    Check(w.ns.RXPWindowReady() == true, "RestedXP's V2 interface is on: ready")
    local heading, progress
    for _, o in ipairs(w.everything) do
        if o.parent == f and o.text then
            if o.text:find("Durotar", 1, true) then heading = o end
            if o.text:find("36/66", 1, true) then progress = o end
        end
    end
    Check(heading and heading.text:find("|cffffd100" .. "1-6", 1, true) and not heading.text:find("^1%-6"),
        "the place, then its level range in gold")
    Check(progress and progress.text:find("36/66", 1, true) and progress.text:find("55%%"),
        "the step and the percent of the guide")
    local labels, rowTexts, lines = {}, {}, {}
    local seenTip
    for _, o in ipairs(w.everything) do
        if o.text and o.shown then
            if o.text == "A tip" or o.text == "Not active" then seenTip = true end
            if o.text == "STEP 36" then labels[#labels + 1] = o end
            if o.text:find("^Talk to") or o.text:find("^Buy") or o.text:find("^Vendor") then rowTexts[#rowTexts + 1] = o.text end
            if o.text:find("^%d+  ") then lines[#lines + 1] = o.text end
        end
    end
    Check(#labels == 1, "the active step is labelled in capitals, as RestedXP titles it")
    Check(#rowTexts == 3 and rowTexts[1] == "Talk to |cff00ff00Duokna|r", "its rows are RestedXP's own, as they read now")
    Check(#lines == 6 and lines[1] == "37  Step 37 line one" and lines[2] == "39  Talk to Gornek"
        and lines[3] == "40  Step 40 line one" and lines[4] == "42  Step 42 line one",
        "six steps after it, one line each, without the one RestedXP hides and the one that is done")
    Check(progress.text:find(string.char(194, 183), 1, true), "the step and the percent are joined by a dot")
    local menu
    for _, o in ipairs(w.frames) do
        if o.parent == f and o.scripts.OnClick and o.text == nil then menu = o end
    end
    Check(menu ~= nil and menu.shown, "a menu button sits below the list")
    menu.scripts.OnClick(menu)
    Check(w.menus == 1, "and it opens RestedXP's menu")
    local backgrounds = 0
    for _, o in ipairs(w.solids) do
        if o.parent == f and o.layer == "BACKGROUND" then backgrounds = backgrounds + 1 end
    end
    local edges = 0
    for _, parent in ipairs(w.borders) do
        if parent == f then edges = edges + 1 end
    end
    Check(backgrounds == 0 and edges == 0, "the window has no panel and no border, as RestedXP's v2 has none to hide")
    local boxed = 0
    for _, parent in ipairs(w.borders) do
        if parent ~= f then boxed = boxed + 1 end
    end
    Check(boxed == 1, "only the active step is in a box")
    Check(not seenTip, "a step that is a tip only, or not active, is not a box")
    Check(f.height > 0, "the window is as tall as what it shows")

    -- the steps listed are a setting
    w.ns.SetRXPWindowSteps(2)
    Flush(w)
    local count = 0
    for _, o in ipairs(w.everything) do
        if o.text and o.shown and o.text:find("^%d+  ") then count = count + 1 end
    end
    Check(count == 2 and account.rxpWindowSteps == 2, "two steps after it: two lines, stored")
    w.ns.SetRXPWindowSteps(6)
    Check(account.rxpWindowSteps == nil, "the default is not stored")
    w.ns.SetRXPWindowSteps(40)
    Check(w.ns.RXPWindowSteps() == 12 and account.rxpWindowSteps == 12, "and the most is held to its range")
end

-- every text of the window is in the Addon Font
do
    local w = Start({ rxpWindow = true })
    local texts, other = 0, 0
    for _, o in ipairs(w.everything) do
        if o.font ~= nil then
            texts = texts + 1
            if o.font ~= "Fonts\\Naowh.ttf" then other = other + 1 end
        end
    end
    Check(texts >= 10 and other == 0, "every text the window makes is in the Addon Font")
end

-- RestedXP's two windows are kept alive, and out of sight and out of the way
do
    local w = Start({ rxpWindow = true })
    Check(w.guide.frame.alpha == 0 and w.steps.frame.alpha == 0, "RestedXP's guide and steps windows are see-through")
    Check(w.guide.frame.mouse == false and w.button.mouse == false and w.steps.frame.mouse == false
        and w.checkbox.mouse == false, "and take no clicks, with what is in them")
    w.guide.frame:SetAlpha(1)
    Check(w.guide.frame.alpha == 0, "RestedXP showing it again leaves it see-through")
    w.ns.SetRXPWindow(false)
    Check(w.guide.frame.alpha == 1 and w.steps.frame.alpha == 1 and w.guide.frame.mouse == true
        and w.button.mouse == true and w.checkbox.mouse == true, "off: both windows are given back as they were")
    Check(Window(w).shown == false, "and the Naowh window is hidden")
    w.ns.SetRXPWindow(true)
    Check(Window(w).shown == true and w.guide.frame.alpha == 0, "on again: the other way")
    w.guide.frame:SetAlpha(0.5)
    Check(w.guide.frame.alpha == 0, "and it is held there")
end

-- live: a row's text and a step's progress follow RestedXP
do
    local w = Start({ rxpWindow = true })
    Check(#w.timers == 0, "nothing waits after the first draw")
    w.talk.frame.text:SetText("Talk to Duokna 1/1")
    w.buy.frame.text:SetText("Buy [Refreshing Spring Water] 5/5")
    Check(#w.timers == 1, "a burst of changes is one redraw")
    Flush(w)
    local seen = {}
    for _, o in ipairs(w.everything) do
        if o.text then seen[o.text] = true end
    end
    Check(seen["Talk to Duokna 1/1"] and seen["Buy [Refreshing Spring Water] 5/5"], "the rows read what RestedXP's say now")
    w.rxp.v2:UpdateGuideWindow()
    Check(#w.timers == 1, "and RestedXP laying its windows out again redraws it")
    Flush(w)
    w.rxp.SetStep(37)
    Check(#w.timers == 1, "and so does a step being set")
end

-- the header folds, and the position is kept
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local f = Window(w)
    local fold
    for _, o in ipairs(w.frames) do
        if o.parent == f and o.scripts.OnClick then fold = fold or o end
    end
    local expanded = f.height
    fold.scripts.OnClick(fold)
    Check(account.rxpWindowCollapsed == true and f.height < expanded, "folded: the header only, and it is kept")
    local foldedMenu
    for _, o in ipairs(w.frames) do
        if o.parent == f and o.scripts.OnClick and o.text == nil then foldedMenu = o end
    end
    Check(foldedMenu and foldedMenu.shown == false, "and the menu button goes with the list")
    local leftShown = 0
    for _, o in ipairs(w.everything) do
        if Seen(o) and o.text and (o.text == "STEP 36" or o.text:find("^%d+  ")) then leftShown = leftShown + 1 end
    end
    Check(leftShown == 0, "and neither the active step nor the steps after it are shown")
    fold.scripts.OnClick(fold)
    Check(account.rxpWindowCollapsed == nil and f.height == expanded, "unfolded: as before")
    Check(f.points[1][1] == "TOPLEFT" and f.points[1][4] == 12 and f.points[1][5] == -240,
        "first placed where RestedXP's guide window was")
    f.points = { { "TOPLEFT", w.env.UIParent, "TOPLEFT", 300, -100 } }
    f.scripts.OnDragStop(f)
    Check(account.rxpWindowPos and account.rxpWindowPos[1] == "TOPLEFT" and account.rxpWindowPos[3] == 300
        and account.rxpWindowPos[4] == -100, "dragged: the place is kept")
    local again = Start(account)
    local g = Window(again)
    Check(g.points[1][1] == "TOPLEFT" and g.points[1][4] == 300 and g.points[1][5] == -100,
        "and it comes back there")
    f.scripts.OnMouseUp(f, "RightButton")
    Check(w.menus == 1, "a right click opens RestedXP's own menu")
    f.scripts.OnMouseUp(f, "LeftButton")
    Check(w.menus == 1, "a left click does not")
end

-- the size: the window scales as a whole and stays in the same place on the screen
do
    local account = { rxpWindow = true, rxpWindowPos = { "TOPLEFT", "TOPLEFT", 300, -100 } }
    local w = Start(account)
    local f = Window(w)
    Check(f.scale == 1 and f.points[1][4] == 300 and f.points[1][5] == -100, "at full size: where it was kept")
    w.ns.SetRXPWindowScale(150)
    Check(f.scale == 1.5 and account.rxpWindowScale == 150, "bigger: scaled, and stored")
    Check(math.abs(f.points[1][4] - 200) < 1e-9 and math.abs(f.points[1][5] + 100 / 1.5) < 1e-9,
        "and held in the same place on the screen")
    Check(math.abs(account.rxpWindowPos[3] - 200) < 1e-9, "and the place is kept in the new size's units")
    w.ns.SetRXPWindowScale(100)
    Check(f.scale == 1 and account.rxpWindowScale == nil and math.abs(f.points[1][4] - 300) < 1e-9,
        "back to full size: the default is not stored")
    w.ns.SetRXPWindowScale(900)
    Check(account.rxpWindowScale == 200 and f.scale == 2, "and the biggest is held to its range")
    local off = { rxpWindowPos = { "TOPLEFT", "TOPLEFT", 300, -100 } }
    local o = Start(off)
    o.ns.SetRXPWindowScale(200)
    Check(off.rxpWindowScale == 200 and off.rxpWindowPos[3] == 150 and off.rxpWindowPos[4] == -50,
        "with the window off the place that was kept follows the size")
    local sized = Start({ rxpWindow = true, rxpWindowScale = 125 })
    Check(Window(sized).scale == 1.25, "a saved size is the size it is built at")
end

-- a row's click is RestedXP's own, on its own hidden button
do
    local w = Start({ rxpWindow = true })
    local row
    for _, o in ipairs(w.frames) do
        if o.scripts.OnClick and o.source == w.talk.frame.button then row = o end
    end
    Check(row ~= nil, "each row knows RestedXP's button for its element")
    row.scripts.OnClick(row)
    Check(w.talk.frame.button.clicks == 1, "a click on it is a click on RestedXP's")
    row.scripts.OnHyperlinkClick(row, "quest:1", "[Quest]", "LeftButton")
    Check(w.links[1] == "quest:1", "and a link in it opens as RestedXP's would")
end

-- what is missing or fails is left out, quietly
do
    local w = Start({ rxpWindow = true }, { snapshotRaises = true })
    local lines = 0
    for _, o in ipairs(w.everything) do
        if o.text and o.shown and o.text:find("^%d+  ") then lines = lines + 1 end
    end
    Check(Window(w) and lines == 0 and w.ns.RXPFailures.WindowSteps and w.ns.RXPFailures.WindowSteps:find("snapshot", 1, true),
        "the steps after it failing: none listed, kept by name, and the rest is drawn")
    w = Start({ rxpWindow = true }, { v2 = false })
    Check(Window(w) == nil and w.ns.RXPWindowReady() == false and w.guide.frame.alpha == nil,
        "RestedXP's V2 interface off: no window, and RestedXP's own is left alone")
    w = Start({ rxpWindow = true })
    w.rxp.currentGuide = { empty = true, steps = {} }
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(Window(w).shown == false, "no guide: nothing to show")
    w = Start({ rxpWindow = true })
    w.rxp.RXPFrame.activeSteps = nil
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(Window(w).shown == true, "no active steps: the heading and the steps after it are still drawn")
    w = Start({ rxpWindow = true }, { installed = false })
    Check(Window(w) == nil, "RestedXP not installed: nothing")
end

print("PASS rxp window: " .. cases .. " checks")

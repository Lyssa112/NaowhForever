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
    function o:SetTexture(path) self.texture = path end
    function o:RegisterEvent(event)
        self.events = self.events or {}
        self.events[event] = true
    end
    function o:UnregisterEvent(event)
        if self.events then self.events[event] = nil end
    end
    function o:SetFont(path, size, flags) self.font, self.fontSize, self.fontFlags = path, size, flags end
    function o:SetShown(on) self.shown = on and true or false end
    function o:SetShadowOffset(x, y) self.shadowX, self.shadowY = x, y end
    function o:SetValue(v) self.value = v end
    function o:SetMinMaxValues(lo, hi) self.range = { lo, hi } end
    function o:SetStatusBarTexture(path) self.barTexture = path end
    function o:SetStatusBarColor(r, g, b, a) self.barColor = { r, g, b, a } end
    function o:GetHeight() return self.height end
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
    function o:StartSizing(corner) self.sizing = corner end
    function o:SetResizable(on) self.resizable = on and true or false end
    function o:SetResizeBounds(a, b, c, d) self.resizeBounds = { a, b, c, d } end
    function o:GetWidth() return self.width end
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
    w.items = {}
    env.GetItemCount = function(id)
        if w.itemsRaise then error("items") end
        return w.items[id] or 0
    end
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
        local border = { _frame = Object(w.everything), parent = parent }
        function border:SetColor(r, g, b, a) self.color = { r, g, b, a } end
        parent.borderObject = border
        return border
    end
    ns.UI = { FontPath = function(name) return "Fonts\\" .. name .. ".ttf" end,
        TexturePath = function(name) return "Textures\\" .. name end }
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
    local panel
    for _, o in ipairs(w.solids) do
        if o.parent == f and o.layer == "BACKGROUND" then panel = o end
    end
    Check(panel and panel.shown == false and f.borderObject._frame.shown == false,
        "the window has a panel and a border to turn on, and both are off to start")
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

-- everything the window can be changed in: each setting is kept only when it is not the default
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local ns = w.ns
    local options = ns.RXPWindowOptions()
    Check(#options >= 15, "the window lists what it can be changed in")
    for _, option in ipairs(options) do
        local label = option.key .. ": "
        local default = ns.RXPWindowOption(option.key)
        Check(option.label and option.tip and option.group, label .. "named, with a tip, in a group")
        ns.SetRXPWindowOption(option.key, default)
        Check(account[option.key] == nil, label .. "the default is not kept")
        if option.kind == "number" then
            ns.SetRXPWindowOption(option.key, option.max + 100)
            Check(ns.RXPWindowOption(option.key) == option.max and account[option.key] == option.max,
                label .. "held to its largest")
            ns.SetRXPWindowOption(option.key, option.min - 100)
            Check(ns.RXPWindowOption(option.key) == option.min, label .. "and its smallest")
            ns.SetRXPWindowOption(option.key, "many")
            Check(account[option.key] == nil and ns.RXPWindowOption(option.key) == option.default,
                label .. "what is no number is the default")
        elseif option.kind == "toggle" then
            ns.SetRXPWindowOption(option.key, not default)
            Check(ns.RXPWindowOption(option.key) == (not default) and account[option.key] == (not default),
                label .. "flipped is kept")
        elseif option.kind == "choice" then
            for _, value in ipairs(option.order) do
                ns.SetRXPWindowOption(option.key, value)
                Check(ns.RXPWindowOption(option.key) == value, label .. value)
            end
            ns.SetRXPWindowOption(option.key, "bogus")
            Check(account[option.key] == nil and ns.RXPWindowOption(option.key) == option.default,
                label .. "what is not a choice is the default")
        else
            ns.SetRXPWindowOption(option.key, "Some Name")
            Check(ns.RXPWindowOption(option.key) == "Some Name" and account[option.key] == "Some Name",
                label .. "a name is kept")
            ns.SetRXPWindowOption(option.key, "")
            Check(account[option.key] == nil and ns.RXPWindowOption(option.key) == "", label .. "and none is not")
        end
        account[option.key] = nil
    end
    account.rxpWindowTitleSize, account.rxpWindowOutline, account.rxpWindowLine = 999, "bogus", 7
    Check(ns.RXPWindowOption("rxpWindowTitleSize") == 28 and ns.RXPWindowOption("rxpWindowOutline") == "shadow"
        and ns.RXPWindowOption("rxpWindowLine") == "bar", "a saved value that is out of range or no choice is held")
    account.rxpWindowMenu = "no"
    Check(ns.RXPWindowOption("rxpWindowMenu") == false, "and what is not true is off")
end

-- the colors: the theme's, until one is picked
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local ns = w.ns
    local T = ns.THEME
    local r, g, b, a = ns.RXPWindowColor("title")
    Check(r == T.fg.r and g == T.fg.g and b == T.fg.b and a == 1, "the title is the theme's text color")
    r, g, b, a = ns.RXPWindowColor("range")
    Check(r == 1 and math.abs(g - 0.82) < 1e-9 and b == 0 and a == 1, "the level range is gold")
    r, g, b, a = ns.RXPWindowColor("list")
    Check(r == T.muted.r and a == 0.9, "the list is the theme's muted, a little see-through")
    r, g, b, a = ns.RXPWindowColor("panel")
    Check(r == T.panel.r and a == 0.92, "the panel is the theme's panel color")
    Check(#ns.RXPWindowColors() >= 10, "the colors it lists")
    ns.SetRXPWindowColor("title", 0.1, 0.2, 0.3, 0.4)
    r, g, b, a = ns.RXPWindowColor("title")
    Check(r == 0.1 and g == 0.2 and b == 0.3 and a == 0.4 and account.rxpWindowColors.title.a == 0.4,
        "a color picked is kept whole")
    ns.SetRXPWindowColor("title", 0.5, 0.5, 0.5)
    Check(select(4, ns.RXPWindowColor("title")) == 1, "with no opacity it is solid")
    ns.SetRXPWindowColor("title", nil)
    Check(account.rxpWindowColors == nil and ns.RXPWindowColor("title") == T.fg.r, "and none puts the theme's back")
    ns.SetRXPWindowColor("nothing", 1, 1, 1, 1)
    Check(account.rxpWindowColors == nil, "a color that is not one of them is not kept")
    account.rxpWindowColors = { text = { r = "x" } }
    Check(ns.RXPWindowColor("text") == T.fg.r, "a color saved wrongly is the theme's")
    account.rxpWindowColors = nil
    ns.SetRXPWindowOption("rxpWindowMenu", false)
    ns.SetRXPWindowColor("fill", 1, 0, 0, 1)
    ns.ResetRXPWindowStyle()
    Check(account.rxpWindowMenu == nil and account.rxpWindowColors == nil, "reset puts the look back")
    account.rxpWindowWidth, account.rxpWindowSteps, account.rxpWindowScale = 400, 3, 120
    ns.ResetRXPWindowStyle()
    Check(account.rxpWindowWidth == 400 and account.rxpWindowSteps == 3 and account.rxpWindowScale == 120,
        "and leaves its size, its width and its steps")
end

-- the bars
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local f = Window(w)
    local T = w.ns.THEME
    Check(f.bar.shown == true and f.rule.shown == false, "under the title: the guide's progress bar to start")
    Check(math.abs(f.bar.value - 36 / 66) < 1e-9 and f.bar.range[1] == 0 and f.bar.range[2] == 1,
        "full as far as the guide is, steps 36 of 66")
    Check(f.bar.height == 5 and f.bar.barTexture == w.ns.MEDIA .. "NaowhGradient.tga", "5 thick, in the Naowh Gradient")
    Check(f.bar.barColor[1] == T.accent.r and f.bar.barColor[4] == 1, "in the accent")
    Check(f.bar.track.solid[1] == T.fg.r and f.bar.track.solid[4] == 0.5, "over a track of the line's color")
    local box
    for _, o in ipairs(w.frames) do
        if o.label and o.bar then box = o end
    end
    Check(box and box.bar.shown == false and w.ns.RXPWindowOption("rxpWindowStepBar") == false,
        "the active step's bar is off to start: the guide's is the only one")
    w.ns.SetRXPWindowOption("rxpWindowStepBar", true)
    Check(account.rxpWindowStepBar == true, "and kept when it is turned on")
    Flush(w)
    Check(box and box.bar.shown == true and math.abs(box.bar.value - 1 / 3) < 1e-9,
        "turned on, the active step has a bar of its objectives done: one of three")
    Check(box.bar.parent == f and box.bar.points[1][2] == f and box.bar.points[2][2] == f,
        "it is a divider of the window and not in the step's box")
    Check(math.abs(box.bar.points[1][5] - (box.points[1][5] - box.height - 5)) < 1e-9
        and box.bar.points[1][4] == box.points[1][4], "under the box, as wide as it, a gap below it")
    local activeSteps = w.rxp.RXPFrame.activeSteps
    w.rxp.RXPFrame.activeSteps = {}
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(box.shown == false and box.bar.shown == false, "with no active step the divider goes with its box")
    w.rxp.RXPFrame.activeSteps = activeSteps
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(box.bar.shown == true, "and comes back with it")
    w.ns.SetRXPWindowOption("rxpWindowStepBar", false)
    Flush(w)
    Check(box.bar.shown == false, "off: not drawn")
    w.ns.SetRXPWindowOption("rxpWindowStepBar", true)
    w.ns.SetRXPWindowOption("rxpWindowLine", "rule")
    Flush(w)
    Check(f.bar.shown == false and f.rule.shown == true and f.rule.solid[4] == 0.5, "a line instead: the bar is not drawn")
    w.ns.SetRXPWindowOption("rxpWindowLine", "none")
    Flush(w)
    Check(f.bar.shown == false and f.rule.shown == false, "or nothing")
    w.ns.SetRXPWindowOption("rxpWindowLine", "bar")
    w.ns.SetRXPWindowOption("rxpWindowBarHeight", 9)
    w.ns.SetRXPWindowOption("rxpWindowBarTexture", "Flat Name")
    Flush(w)
    Check(f.bar.barTexture == "Textures\\Flat Name", "another texture picked is the bar's")
    w.ns.SetRXPWindowOption("rxpWindowBarTexture", "")
    Flush(w)
    Check(f.bar.barTexture == w.ns.MEDIA .. "NaowhGradient.tga", "and none is the Naowh Gradient again")
    w.ns.SetRXPWindowOption("rxpWindowBarTexture", "Flat Name")
    w.ns.SetRXPWindowColor("fill", 1, 0, 0, 0.5)
    w.ns.SetRXPWindowColor("line", 0, 0, 1, 1)
    Flush(w)
    Check(f.bar.height == 9 and f.bar.barTexture == "Textures\\Flat Name" and f.bar.barColor[1] == 1
        and f.bar.barColor[4] == 0.5 and f.bar.track.solid[3] == 1, "the height, the texture and the colors are its own")
    Check(box.bar.height == 9 and box.bar.barTexture == "Textures\\Flat Name", "and the active step's bar follows")
    w.rows[1].complete = true
    w.rxp.GetGuideProgress = function() return 66, "id" end
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(f.bar.value == 1, "the last step is a full bar")
    w.rxp.GetGuideProgress = function() return 0, "id" end
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(f.bar.value == 0, "and none an empty one")
    w.vendor.frame.button.GetChecked = function() return true end
    w.talk.frame.button.GetChecked = function() return true end
    w.buy.frame.button.GetChecked = function() return true end
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(box.bar.value == 1, "all three objectives done is a full bar")
    w.ns.SetRXPWindowOption("rxpWindowProgressText", false)
    Flush(w)
    Check(f.progress.text == "", "the progress text can be left out")
end

-- the look: panel, borders, menu, spacing and the colors of every text
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local ns = w.ns
    local f = Window(w)
    local T = ns.THEME
    ns.SetRXPWindowOption("rxpWindowPanel", true)
    ns.SetRXPWindowColor("panel", 0.1, 0.2, 0.3, 0.4)
    ns.SetRXPWindowOption("rxpWindowBorder", true)
    ns.SetRXPWindowColor("edge", 0.9, 0.8, 0.7, 0.6)
    Flush(w)
    Check(f.back.shown == true and f.back.solid[1] == 0.1 and f.back.solid[4] == 0.4, "a panel behind the window, in its color")
    Check(f.borderObject._frame.shown == true and f.borderObject.color[1] == 0.9 and f.borderObject.color[4] == 0.6,
        "a border round it, in its color")
    local box
    for _, o in ipairs(w.frames) do
        if o.label and o.bar then box = o end
    end
    Check(box.borderObject._frame.shown == true and box.borderObject.color[1] == T.line.r, "the step's box has its own border")
    Check(math.abs(box.back.solid[4] - 0.55) < 1e-9, "the box is a little see-through to start")
    ns.SetRXPWindowOption("rxpWindowBoxBorder", false)
    ns.SetRXPWindowColor("box", 0.3, 0.3, 0.3, 0.3)
    ns.SetRXPWindowColor("boxEdge", 1, 1, 0, 1)
    Flush(w)
    Check(box.borderObject._frame.shown == false and box.back.solid[1] == 0.3 and box.borderObject.color[1] == 1,
        "which can be turned off, and has its colors")
    Check(math.abs(box.back.solid[4] - 0.55) < 1e-9 and select(4, ns.RXPWindowColor("box")) == 1,
        "the opacity of the box is not part of its color")
    ns.SetRXPWindowOption("rxpWindowBoxOpacity", 100)
    Flush(w)
    Check(box.back.solid[4] == 1, "its opacity: solid")
    ns.SetRXPWindowOption("rxpWindowBoxOpacity", 0)
    Flush(w)
    Check(box.back.solid[4] == 0, "and none")
    ns.SetRXPWindowOption("rxpWindowBoxOpacity", 30)
    Flush(w)
    Check(math.abs(box.back.solid[4] - 0.3) < 1e-9, "and in between")
    ns.SetRXPWindowOption("rxpWindowMenu", false)
    Flush(w)
    Check(f.menu.shown == false, "the menu button can be left out")
    local before = f.height
    ns.SetRXPWindowOption("rxpWindowSpacing", 12)
    Flush(w)
    Check(f.height > before, "more spacing, a taller window")
    ns.SetRXPWindowOption("rxpWindowSpacing", 0)
    Flush(w)
    Check(f.height < before, "less, a shorter one")

    -- every text has its color
    ns.SetRXPWindowColor("title", 1, 0, 0, 1)
    ns.SetRXPWindowColor("label", 0, 1, 0, 1)
    ns.SetRXPWindowColor("text", 0, 0, 1, 1)
    ns.SetRXPWindowColor("done", 1, 1, 0, 1)
    ns.SetRXPWindowColor("list", 0, 1, 1, 1)
    Flush(w)
    Check(f.title.color[1] == 1 and f.title.color[2] == 0, "the title's color")
    Check(box.label.color[2] == 1 and box.label.color[1] == 0, "the step label's")
    local rowText, doneText, listText
    for _, o in ipairs(w.everything) do
        if o.text == "Talk to |cff00ff00Duokna|r" then rowText = o end
        if o.text == "Vendor Trash" then doneText = o end
        if o.text and o.text:find("^37  ") then listText = o end
    end
    Check(rowText and rowText.color[3] == 1, "a row's")
    Check(doneText and doneText.color[1] == 1 and doneText.color[2] == 1 and doneText.color[3] == 0, "a done row's")
    Check(listText and listText.color[2] == 1 and listText.color[3] == 1, "and a line in the list")
end

-- the text: its face, its size and how it is kept readable
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local ns = w.ns
    local f = Window(w)
    local function Texts(of)
        local out = {}
        for _, o in ipairs(w.everything) do
            if o.font ~= nil and (of == nil or o.sizeKey == of) then out[#out + 1] = o end
        end
        return out
    end
    local all = Texts()
    Check(#all >= 10, "texts to look at")
    local plain = 0
    for _, o in ipairs(all) do
        if o.font == "Fonts\\Naowh.ttf" and o.fontFlags == "" and o.shadowX == 1 and o.shadowY == -1 then
            plain = plain + 1
        end
    end
    Check(plain == #all, "every text is in the Addon Font with a shadow to start")
    ns.SetRXPWindowOption("rxpWindowFont", "Fira")
    ns.SetRXPWindowOption("rxpWindowOutline", "outline")
    ns.SetRXPWindowOption("rxpWindowTitleSize", 20)
    ns.SetRXPWindowOption("rxpWindowTextSize", 15)
    ns.SetRXPWindowOption("rxpWindowListSize", 9)
    Flush(w)
    for _, size in ipairs({ { "rxpWindowTitleSize", 20 }, { "rxpWindowTextSize", 15 }, { "rxpWindowListSize", 9 } }) do
        local group = Texts(size[1])
        Check(#group > 0, size[1] .. " has texts")
        for _, o in ipairs(group) do
            Check(o.font == "Fonts\\Fira.ttf" and o.fontSize == size[2] and o.fontFlags == "OUTLINE" and o.shadowX == 0,
                size[1] .. ": its face, size and outline")
        end
    end
    ns.SetRXPWindowOption("rxpWindowOutline", "thick")
    Flush(w)
    for _, o in ipairs(Texts()) do
        Check(o.fontFlags == "THICKOUTLINE" and o.shadowX == 0, "a thick outline, with no shadow")
        break
    end
    ns.SetRXPWindowOption("rxpWindowOutline", "none")
    Flush(w)
    Check(Texts("rxpWindowListSize")[1].fontFlags == "" and Texts("rxpWindowListSize")[1].shadowX == 0,
        "with none, neither outline nor shadow")
    ns.SetRXPWindowOption("rxpWindowFont", "")
    ns.SetRXPWindowOption("rxpWindowOutline", "shadow")
    Flush(w)
    Check(Texts("rxpWindowTitleSize")[1].font == "Fonts\\Naowh.ttf" and Texts("rxpWindowTitleSize")[1].shadowX == 1,
        "back to the Addon Font and the shadow")
    Check(f.title.fontSize == 20, "the sizes stay")
end

-- the window is resized from its corner: the width, and the steps listed from how tall it is made
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local f = Window(w)
    local ns = w.ns
    local function Lines()
        local count = 0
        for _, o in ipairs(w.everything) do
            if Seen(o) and o.text and o.text:find("^%d+  ") then count = count + 1 end
        end
        return count
    end
    Check(f.resizable == true and f.grip ~= nil and f.grip.shown == true, "resizable, with a grip in its corner")
    local base, line = f.chrome, f.lineHeight
    Check(base > 0 and line > 0 and math.abs((f.height - base) / line - 6) < 1e-9,
        "the height without the list and the height of a line are known: six lines drawn")
    Check(f.resizeBounds[1] == 260 and f.resizeBounds[2] == base and f.resizeBounds[3] == 640
        and f.resizeBounds[4] == base + 12 * line, "its smallest has no steps listed and its biggest all of them")
    f.grip.scripts.OnMouseDown(f.grip)
    Check(f.sizing == "BOTTOMRIGHT", "the grip starts the sizing from its corner")

    -- while it is dragged the window follows, with nothing kept until the grip is let go
    local snapshots = w.rxp.v2.snapshots
    f.width, f.height = 450, base + 2 * line
    f.scripts.OnSizeChanged(f, 450, base + 2 * line)
    Check(Lines() == 2 and account.rxpWindowSteps == nil and account.rxpWindowWidth == nil,
        "dragged to two lines: two are listed, and nothing is kept yet")
    local box
    for _, o in ipairs(w.frames) do
        if o.label and o.bar then box = o end
    end
    Check(box.width == 450 - 20 and f.title.width == 450 - 20 - 16 - 5 - 120,
        "and everything is laid out to the width it has now")
    f.scripts.OnSizeChanged(f, 520, base + 5 * line)
    Check(Lines() == 5 and box.width == 520 - 20, "bigger again: five lines, and wider")
    f.scripts.OnSizeChanged(f, 100, 3)
    Check(Lines() == 0 and box.width == 260 - 20, "smaller than it can be: none, and the narrowest")
    f.scripts.OnSizeChanged(f, 900, base + 40 * line)
    Check(Lines() == 12 and box.width == 640 - 20, "bigger than it can be: all of them, and the widest")
    Check(f.width == 450 and f.height == base + 2 * line, "the size is the dragged one's: the window does not set its own meanwhile")
    Check(w.rxp.v2.snapshots == snapshots, "and what it lists is not read again: it was, once, when the grip was pressed")
    f.width, f.height = 500, base + 3 * line + line / 2
    f.points = { { "TOPLEFT", w.env.UIParent, "TOPLEFT", 40, -60 } }
    f.grip.scripts.OnMouseUp(f.grip)
    Check(f.moving == false and account.rxpWindowWidth == 500 and account.rxpWindowSteps == 3,
        "let go: the width and the steps that fit, and a part of a line is not one")
    Check(f.width == 500 and Lines() == 3 and math.abs(f.height - (base + 3 * line)) < 1e-9,
        "and the window is drawn at that size")
    Check(account.rxpWindowPos and account.rxpWindowPos[3] == 40 and account.rxpWindowPos[4] == -60,
        "the place it ended up in is kept")
    f.width, f.height = 900, base + 40 * line
    f.grip.scripts.OnMouseUp(f.grip)
    Check(account.rxpWindowWidth == 640 and account.rxpWindowSteps == 12 and f.width == 640 and Lines() == 12,
        "bigger than it can be: held to the most")
    f.width, f.height = 100, 5
    f.grip.scripts.OnMouseUp(f.grip)
    Check(account.rxpWindowWidth == 260 and account.rxpWindowSteps == 0 and Lines() == 0,
        "smaller than it can be: held to the least, with no steps listed")
    f.width, f.height = 380, base + 6 * line
    f.grip.scripts.OnMouseUp(f.grip)
    Check(account.rxpWindowWidth == nil and account.rxpWindowSteps == nil, "back to the start: nothing is kept")

    -- locked, and the grip left out
    ns.SetRXPWindowOption("rxpWindowLock", true)
    Flush(w)
    f.sizing = nil
    f.moving = nil
    f.grip.scripts.OnMouseDown(f.grip)
    f.scripts.OnDragStart(f)
    Check(f.sizing == nil and f.moving == nil and f.resizable == false,
        "locked: it is not sized or moved, and is not resizable")
    ns.SetRXPWindowOption("rxpWindowLock", false)
    ns.SetRXPWindowOption("rxpWindowGrip", false)
    Flush(w)
    Check(f.grip.shown == false and f.resizable == true, "the grip can be left out, and the window is still resizable")
    ns.SetRXPWindowOption("rxpWindowGrip", true)
    account.rxpWindowCollapsed = true
    ns.SetRXPWindowOption("rxpWindowGrip", true)
    Flush(w)
    Check(f.grip.shown == false and f.resizable == false, "folded: there is no list to size, and no grip")
end

-- RestedXP's Active Targets and Active Items windows take the look of the active step
do
    local RXP_EDGE = "Textures\\RXPEdge"
    local RXP_FONT = "Fonts\\RXP.ttf"

    local function Box(w)
        local part = Object(w.everything)
        local fill = Object(w.everything)
        function fill:SetVertexColor(r, g, b, a)
            self.vertex, self.sets = { r, g, b, a }, (self.sets or 0) + 1
        end
        part.rxpBackground = Object(w.everything)
        part.rxpBackground.textures = { fill }
        part.rxpBorder = Object(w.everything)
        part.rxpBorder.textures = {}
        for i = 1, 4 do
            local edge = Object(w.everything)
            function edge:SetTexture(path) self.texture, self.solid = path, nil end
            function edge:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a } end
            part.rxpBorder.textures[i] = edge
        end
        return part
    end

    -- RestedXP's frame: what its UpdateVisuals paints is its own, each time it is called
    local function Satellite(w, title)
        local f = Box(w)
        f.paints = 0
        f.title = Box(w)
        local text = Object(w.everything)
        text:SetText(title)
        text:SetFont(RXP_FONT, 9, "")
        function text:GetFont() return self.font, self.fontSize, self.fontFlags end
        function text:GetStringWidth() return self.font == RXP_FONT and 60 or 80 end
        f.title.text = text
        local function Paint(part)
            part.rxpBackground.textures[1]:SetVertexColor(0.1, 0.2, 0.3, 0.9)
            for _, edge in ipairs(part.rxpBorder.textures) do
                edge:SetTexture(RXP_EDGE)
                edge:SetVertexColor(0.7, 0.6, 0.5, 1)
            end
        end
        function f:UpdateVisuals()
            self.paints = self.paints + 1
            Paint(self)
            Paint(self.title)
            self.title.text:SetFont(RXP_FONT, 9, "")
            self.title.text:SetTextColor(0.9, 0.9, 0.9)
            self.title:SetSize(70, 19)
        end
        f:UpdateVisuals()
        return f
    end

    local function Begin(account, make)
        local w = World(account)
        local rxp = Rxp(w)
        make(w, rxp)
        for _, f in ipairs(w.frames) do w.boot = f end
        w.boot.scripts.OnEvent(w.boot, "ADDON_LOADED", "NaowhForever")
        w.boot.scripts.OnEvent(w.boot, "PLAYER_LOGIN")
        Flush(w)
        return w
    end

    local function Both(w, rxp)
        rxp.targeting = { activeTargetFrame = Satellite(w, "Active Targets") }
        function rxp.targeting:RenderTargetFrameBackground()
            self.activeTargetFrame.rxpBackground.textures[1]:SetVertexColor(0.1, 0.2, 0.3, 0.9)
            self.renders = (self.renders or 0) + 1
        end
        rxp.activeItemFrame = Satellite(w, "Active Items")
    end

    local function Fill(part) return part.rxpBackground.textures[1].vertex end

    local function Is(color, r, g, b, a)
        return color and math.abs(color[1] - r) < 1e-6 and math.abs(color[2] - g) < 1e-6
            and math.abs(color[3] - b) < 1e-6 and math.abs(color[4] - a) < 1e-6
    end

    -- the window off: they are as RestedXP paints them, and are not hooked
    local off = Begin({}, Both)
    local target, items = off.rxp.targeting.activeTargetFrame, off.rxp.activeItemFrame
    Check(Is(Fill(target), 0.1, 0.2, 0.3, 0.9) and target.rxpBorder.textures[1].texture == RXP_EDGE
        and target.title.text.font == RXP_FONT, "the window is off: RestedXP's windows are left as RestedXP paints them")
    target:UpdateVisuals()
    Check(Is(Fill(target), 0.1, 0.2, 0.3, 0.9) and items.paints == 1, "and are painted that way again")

    -- the window on: both take its look, and keep it when RestedXP paints them again
    local account = { rxpWindow = true }
    local w = Begin(account, Both)
    local ns = w.ns
    target, items = w.rxp.targeting.activeTargetFrame, w.rxp.activeItemFrame
    Check(ns.RXPWindowOption("rxpWindowSatellites") == true and account.rxpWindowSatellites == nil,
        "styling the two windows is on with the window, and the default is not stored")
    local function Look(frame, name)
        local r, g, b = ns.RXPWindowColor("box")
        local opacity = ns.RXPWindowOption("rxpWindowBoxOpacity") / 100
        local er, eg, eb, ea = ns.RXPWindowColor("boxEdge")
        local label = { ns.RXPWindowColor("label") }
        Check(Is(Fill(frame), r, g, b, opacity), name .. ": the background is the active step's color and opacity")
        Check(Fill(frame.title) and Is(Fill(frame.title), r, g, b, opacity), name .. ": and so is its title's")
        for i, edge in ipairs(frame.rxpBorder.textures) do
            Check(Is(edge.solid, er, eg, eb, ea), name .. ": border " .. i .. " is the active step's border color")
        end
        Check(frame.rxpBorder.shown == true and frame.title.rxpBorder.shown == true, name .. ": the border is shown")
        local text = frame.title.text
        Check(text.font == "Fonts\\Naowh.ttf" and text.fontSize == 9 and text.fontFlags == "" and text.shadowX == 1,
            name .. ": the title is in the window's face and RestedXP's size, with the window's shadow")
        Check(text.color and math.abs(text.color[1] - label[1]) < 1e-6 and math.abs(text.color[3] - label[3]) < 1e-6,
            name .. ": and in the step label's color")
        Check(frame.title.width == 90 and frame.title.height == 19,
            name .. ": the title is as wide as its text in the window's face, and RestedXP's height")
    end
    Look(target, "targets")
    Look(items, "items")

    target:UpdateVisuals()
    Look(target, "targets painted again")
    w.rxp.targeting:RenderTargetFrameBackground()
    local r, g, b = ns.RXPWindowColor("box")
    Check(Is(Fill(target), r, g, b, 0.55) and w.rxp.targeting.renders == 1,
        "RestedXP rendering the background of the targets again does not undo it")

    -- what is set for the window is what they follow
    ns.SetRXPWindowOption("rxpWindowBoxOpacity", 80)
    ns.SetRXPWindowColor("box", 1, 0, 0)
    ns.SetRXPWindowColor("boxEdge", 0, 1, 0, 0.5)
    ns.SetRXPWindowOption("rxpWindowOutline", "outline")
    ns.SetRXPWindowOption("rxpWindowFont", "Fancy")
    Flush(w)
    Check(Is(Fill(target), 1, 0, 0, 0.8) and Is(Fill(items.title), 1, 0, 0, 0.8), "a color and an opacity set for the box")
    Check(Is(target.rxpBorder.textures[3].solid, 0, 1, 0, 0.5), "a border color set for the box")
    Check(items.title.text.font == "Fonts\\Fancy.ttf" and items.title.text.fontFlags == "OUTLINE"
        and items.title.text.shadowX == 0, "a face and an outline set for the window")
    ns.SetRXPWindowOption("rxpWindowBoxBorder", false)
    Flush(w)
    Check(target.rxpBorder.shown == false and items.title.rxpBorder.shown == false, "no border: none is shown")
    ns.SetRXPWindowOption("rxpWindowBoxBorder", true)
    Flush(w)
    Check(target.rxpBorder.shown == true, "and shown again")

    -- hooked once, however often it is drawn
    for _ = 1, 3 do
        ns.SetRXPWindowOption("rxpWindowSpacing", 6)
        Flush(w)
    end
    local fill = target.rxpBackground.textures[1]
    fill.sets = 0
    target:UpdateVisuals()
    Check(fill.sets == 2, "RestedXP paints it once and the window once, however often the window was drawn")
    ns.SetRXPWindowOption("rxpWindowSpacing", 5)
    Flush(w)

    -- RestedXP hides the background of a window: the border is not shown without it
    target.rxpBackground:Hide()
    target.rxpBorder:Hide()
    target:UpdateVisuals()
    Check(target.rxpBorder.shown == false and Is(Fill(target), 1, 0, 0, 0.8),
        "a background RestedXP hides keeps its border hidden")
    target.rxpBackground:Show()
    target.rxpBorder:Show()

    -- a frame RestedXP makes later is taken at the next draw
    local late = Begin({ rxpWindow = true }, function(world, rxp)
        rxp.targeting = { activeTargetFrame = Satellite(world, "Active Targets") }
    end)
    local lr, lg, lb = late.ns.RXPWindowColor("box")
    Check(late.rxp.activeItemFrame == nil and Is(Fill(late.rxp.targeting.activeTargetFrame), lr, lg, lb, 0.55),
        "one of the two is not there yet, and the other has the look")
    late.rxp.activeItemFrame = Satellite(late, "Active Items")
    Check(Is(Fill(late.rxp.activeItemFrame), 0.1, 0.2, 0.3, 0.9), "it is painted as RestedXP paints it")
    late.rxp.SetStep()
    Flush(late)
    Check(Is(Fill(late.rxp.activeItemFrame), lr, lg, lb, 0.55), "and has the look of the window at the next draw")

    -- a border the window hid is shown again when RestedXP's own look is
    ns.SetRXPWindowOption("rxpWindowBoxBorder", false)
    Flush(w)
    Check(items.rxpBorder.shown == false and items.title.rxpBorder.shown == false, "the border is hidden to begin with")
    ns.SetRXPWindowOption("rxpWindowSatellites", false)
    Flush(w)
    Check(items.rxpBorder.shown == true and items.title.rxpBorder.shown == true and target.title.rxpBorder.shown == true,
        "a border the window hid is shown again with RestedXP's own look")
    ns.SetRXPWindowOption("rxpWindowSatellites", true)
    ns.SetRXPWindowOption("rxpWindowBoxBorder", true)
    Flush(w)

    -- the option off, and RestedXP paints its own again, then not hooked into any more
    ns.SetRXPWindowOption("rxpWindowSatellites", false)
    Flush(w)
    Check(target.paints >= 3 and Is(Fill(target), 0.1, 0.2, 0.3, 0.9) and target.rxpBorder.textures[1].texture == RXP_EDGE
        and target.rxpBorder.textures[1].solid == nil and target.title.text.font == RXP_FONT
        and target.rxpBorder.shown == true, "turned off: RestedXP's own look is back, border and all")
    local paints = items.paints
    items:UpdateVisuals()
    Check(items.paints == paints + 1 and Is(Fill(items), 0.1, 0.2, 0.3, 0.9) and items.title.text.font == RXP_FONT,
        "and what RestedXP paints is left as it is")
    Check(account.rxpWindowSatellites == false, "left out: kept")
    ns.SetRXPWindowOption("rxpWindowSatellites", true)
    Flush(w)
    Check(Is(Fill(items), 1, 0, 0, 0.8) and account.rxpWindowSatellites == nil, "turned on again: the look is back")

    -- the window turned off: they are RestedXP's again
    ns.SetRXPWindow(false)
    Flush(w)
    Check(Is(Fill(items), 0.1, 0.2, 0.3, 0.9) and Is(Fill(target.title), 0.1, 0.2, 0.3, 0.9)
        and items.title.text.font == RXP_FONT and items.rxpBorder.textures[2].texture == RXP_EDGE,
        "the window turned off: RestedXP's own look is back")
    target:UpdateVisuals()
    Check(Is(Fill(target), 0.1, 0.2, 0.3, 0.9), "and stays")

    -- pieces that are not there raise nothing
    local bare = Begin({ rxpWindow = true }, function(world, rxp)
        rxp.targeting = { activeTargetFrame = Object(world.everything) }
        rxp.activeItemFrame = { UpdateVisuals = function() end, title = {} }
    end)
    bare.rxp.activeItemFrame:UpdateVisuals()
    bare.rxp.SetStep()
    Flush(bare)
    Check(Window(bare) ~= nil and Window(bare).shown, "frames without a background, a border or a title: nothing raises")
end

-- a row that counts has a bar of its own: the items in the bags for a buy, the numbers in a counted line
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local f = Window(w)
    local ns = w.ns
    local BAGS = "BAG_UPDATE_DELAYED"
    local function Row(text)
        for _, o in ipairs(w.frames) do
            if o.meter and o.text and o.text.text == text and Seen(o) then return o end
        end
    end
    local function Meters()
        local count = 0
        for _, o in ipairs(w.frames) do
            if o.meter and Seen(o) and o.meter.shown then count = count + 1 end
        end
        return count
    end
    local BUY = "Buy [Refreshing Spring Water] from her"
    local TALK = "Talk to |cff00ff00Duokna|r"
    Check(Meters() == 0 and (f.events == nil or f.events[BAGS] == nil), "nothing counts to start: no bar, and no event")

    w.buy.id, w.buy.qty = 159, 5
    w.items[159] = 2
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    local buy = Row(BUY)
    Check(buy.meter.shown and math.abs(buy.meter.value - 0.4) < 1e-9, "buy five with two in the bags: two fifths")
    Check(buy.meter.width == buy.width - 2 - 5 - 18 and buy.height == 13 + 2 + 5,
        "under the text as wide as it, and the row is as tall as both")
    Check(f.events and f.events[BAGS] == true, "and the bags are listened to")

    w.items[159] = 4
    f.scripts.OnEvent(f, BAGS)
    Flush(w)
    Check(math.abs(Row(BUY).meter.value - 0.8) < 1e-9, "a bag update draws it again: four fifths")
    w.items[159] = 9
    f.scripts.OnEvent(f, BAGS)
    Flush(w)
    Check(Row(BUY).meter.value == 1, "more than needed is a full bar")

    w.buy.qty = 1
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(Meters() == 0 and f.events[BAGS] == nil, "one of something is not a count: no bar, and the bags are let go")

    w.talk.frame.text:SetText("|cff00ff00Boar Meat|r: |cffffd1003/8|r")
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    local talk = Row("|cff00ff00Boar Meat|r: |cffffd1003/8|r")
    Check(talk and talk.meter.shown and math.abs(talk.meter.value - 3 / 8) < 1e-9, "a line that counts: three of eight")
    Check(f.events[BAGS] == nil, "and needs no bags: RestedXP changes its text")
    w.talk.frame.button.GetChecked = function() return true end
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(talk.meter.value == 1, "a row that is done is a full bar")
    w.talk.frame.button.GetChecked = function() return false end
    w.talk.frame.text:SetText("Kill 12/10 Boars")
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(Row("Kill 12/10 Boars").meter.value == 1, "past its count is full")
    w.talk.frame.text:SetText("Talk to 1/1 Duokna")
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(Meters() == 0, "1/1 is not a count")

    w.buy.id, w.buy.qty = "Refreshing Spring Water", 5
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(Meters() == 0, "a buy that is of an item by name has nothing to count in the bags")
    w.buy.id = 159

    w.talk.frame.text:SetText("Talk to |cff00ff00Duokna|r")
    w.vendor.tag, w.vendor.id, w.vendor.qty = "vendor", 5, 9
    w.buy.qty = 5
    w.items[159] = 1
    ns.SetRXPWindowOption("rxpWindowCountBar", false)
    Flush(w)
    Check(Meters() == 0 and f.events[BAGS] == nil, "turned off: no bars, and no bags")
    ns.SetRXPWindowOption("rxpWindowCountBar", true)
    Flush(w)
    Check(Meters() == 1 and Row(BUY).meter.shown, "turned on: the buy only, and not a row that is not a buy with an id")
    Check(f.events[BAGS] == true, "and the bags are listened to again")

    w.itemsRaise = true
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(Meters() == 0 and type(ns.RXPFailures.WindowCount) == "string" and f.shown,
        "bags that raise: no bar, kept by name, and the window is drawn")
    w.itemsRaise = false

    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(Meters() == 1 and f.events[BAGS] == true, "and back when they do not")
    ns.SetRXPWindow(false)
    Flush(w)
    Check(f.events[BAGS] == nil, "the window turned off: the bags are let go")
end

-- RestedXP's logo in the corner of the current step's box
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local f = Window(w)
    local ns = w.ns
    local LOGO = "Interface\\AddOns\\RXPGuides\\Textures\\rxp_logo-64"
    local function Boxes()
        local out = {}
        for _, o in ipairs(w.frames) do
            if o.label and o.logo and Seen(o) then out[#out + 1] = o end
        end
        return out
    end
    local boxes = Boxes()
    Check(#boxes == 1 and boxes[1].logo.shown and boxes[1].logo.texture == LOGO,
        "RestedXP's logo, from RestedXP's own files, is in the current step's box")
    local logo = boxes[1].logo
    Check(logo.points[1][1] == "TOPRIGHT" and logo.points[1][2] == boxes[1] and logo.points[1][3] == "TOPRIGHT"
        and logo.points[1][4] == -7 and logo.points[1][5] == -7, "in its top right corner")
    Check(logo.width == 17 and logo.height == 17, "a little taller than the step's text")
    Check(f.title.points[1][4] == 31 and f.title.width == 380 - 10 - 31 - 120,
        "and the guide's name has all its room")
    ns.SetRXPWindowOption("rxpWindowTextSize", 20)
    Flush(w)
    Check(logo.width == 24, "it follows the size of the text")
    ns.SetRXPWindowOption("rxpWindowTextSize", 13)

    -- with a second active step, only the first has it
    local second = { active = true, index = 37, title = "Step 37", elements = { w.buy } }
    local steps = w.rxp.RXPFrame.activeSteps
    w.rxp.RXPFrame.activeSteps = { steps[1], second }
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    boxes = Boxes()
    Check(#boxes == 2 and boxes[1].logo.shown and boxes[2].logo.shown == false, "with two steps, it is the first one's")
    w.rxp.RXPFrame.activeSteps = steps
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    boxes = Boxes()
    Check(#boxes == 1 and boxes[1].logo.shown, "and back with one")

    ns.SetRXPWindowOption("rxpWindowLogo", false)
    Flush(w)
    Check(boxes[1].logo.shown == false and account.rxpWindowLogo == false, "it can be left out, and that is kept")
    ns.SetRXPWindowOption("rxpWindowLogo", true)
    Flush(w)
    Check(boxes[1].logo.shown and account.rxpWindowLogo == nil, "and back: the default is not kept")
end

print("PASS rxp window: " .. cases .. " checks")

-- Offline behavior checks for the Damage Meter (NaowhForever_DamageMeter) against stubs of the game's frames and
-- C_DamageMeter; they do not emulate the client. Amounts are tables here, so any arithmetic or comparison on a
-- value that is secret in combat fails the test, as it would in game. Run with Lua 5.1 from the repository root.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local function Noop() end
local METHODS = { __index = function(_, k) if type(k) == "string" and k:find("^[A-Z]") then return Noop end end }

local function Region(kind, parent)
    local r = setmetatable({ kind = kind, parent = parent, shown = true, scripts = {}, events = {}, children = {},
        w = 0, h = 0, alpha = 1, level = 1, text = "" }, METHODS)
    function r:SetScript(k, fn) self.scripts[k] = fn end
    function r:HookScript(k, fn) self.scripts[k] = fn end
    function r:RegisterEvent(e) self.events[e] = true end
    function r:UnregisterEvent(e) self.events[e] = nil end
    function r:UnregisterAllEvents() self.events = {} end
    function r:RegisterForClicks() end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:SetSize(w, h) self.w, self.h = w, h end
    function r:SetWidth(w) self.w = w end
    function r:SetHeight(h) self.h = h end
    function r:GetWidth() return self.w end
    function r:GetHeight() return self.h end
    function r:SetAlpha(a) self.alpha = a end
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetFormattedText(fmt, ...) self.text = fmt:format(...) end
    function r:GetStringWidth() return 40 end
    function r:SetFrameLevel(l) self.level = l end
    function r:GetFrameLevel() return self.level end
    function r:SetMinMaxValues(lo, hi) self.barMin, self.barMax = lo, hi end
    function r:SetValue(v) self.barValue = v end
    function r:SetStatusBarColor(rr, g, b, a) self.color = { rr, g, b, a } end
    function r:SetStatusBarTexture(t) self.barTexture = t end
    function r:SetColorTexture(rr, g, b, a) self.solid = { rr, g, b, a } end
    function r:SetTexture(t) self.texture = t end
    function r:CreateTexture() return Region("Texture", self) end
    function r:GetLeft() return 100 end
    function r:GetTop() return 300 end
    function r:GetEffectiveScale() return 1 end
    function r:StartMoving() self.moving = true end
    function r:StartSizing() self.sizing = true end
    function r:StopMovingOrSizing() self.moving, self.sizing = false, false end
    return r
end

local THEME = {
    bg = { r = 0.1, g = 0.1, b = 0.1 }, panel = { r = 0.2, g = 0.2, b = 0.2 }, line = { r = 0.3, g = 0.3, b = 0.3 },
    fg = { r = 0.9, g = 0.9, b = 0.9 }, muted = { r = 0.6, g = 0.6, b = 0.6 }, accent = { r = 0, g = 0.5, b = 1 },
}
local CLASS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, ROGUE = { r = 1, g = 0.96, b = 0.41 } }

local function Amount(name) return setmetatable({ name = name }, { __tostring = function() return name end }) end

local function Source(name, class, total, rate, own)
    return { name = name, classFilename = class, specIconID = 0, totalAmount = Amount(total), amountPerSecond = Amount(rate),
        isLocalPlayer = own == true }
end

local function Boot(opts)
    opts = opts or {}
    local s = { settings = opts.settings or {}, calls = {}, cvars = { damageMeterEnabled = opts.gameMeter or "1" },
        timers = {}, printed = {}, frames = {}, buttons = {}, confirms = {}, hooks = {}, account = {} }
    local defaults
    local store = {}
    function store.Get(k)
        local v = s.settings[k]
        if v == nil then v = defaults[k] end
        return v
    end
    function store.Set(k, v) s.settings[k] = v end
    function store.DB() return s.settings end
    local session = { combatSources = { Source("Aldrin", "MAGE", "A", "a"), Source("You", "ROGUE", "B", "b", true),
        Source("Cara", "MAGE", "C", "c") }, maxAmount = Amount("max"), totalAmount = Amount("total") }
    s.session = session
    local ns = { THEME = THEME, MEDIA = "Media\\",
        FEATURES = { damageMeter = { enabled = false } },
        UI = {
            ModuleSettings = function(_, d) defaults = d; return store end,
            TexturePath = function(name, fallback) return name ~= "" and name or fallback end,
            AttachMover = function(frame) local m = Region("Mover", frame); s.mover = m; return m end,
        },
        Shared = {
            Style = { ICON_CROP = 0.08, ALPHA_RANGE = { 0, 100, 5 }, OPACITY_STEP = 5, PERCENT_SCALE = 0.01 },
            Parts = { HudFont = function(fs, font, size) fs.fontSize = size; fs.font = font end },
            Settings = { Group = function(name) return { group = name } end, Look = function(_, o) return { look = o } end,
                Page = function(_, st)
                    local page = { store = st, cards = {} }
                    function page:Window(def) self.window = def; return self end
                    function page:Card(def) self.cards[#self.cards + 1] = def; s.page = self; return self end
                    return page
                end },
        },
        Solid = function(parent) return Region("Solid", parent) end,
        Border = function(frame) return { _frame = Region("Border", frame) } end,
        Font = function(parent) return Region("FontString", parent) end,
        Button = function(parent, text, w, h, onClick)
            local b = Region("Button", parent); b.label = text; b.onClick = onClick
            s.buttons[#s.buttons + 1] = b
            return b
        end,
        SetButtonText = function(b, text) b.label = text end,
        Tooltip = Noop, AllowOffscreen = Noop,
        Confirm = function(text, yes) s.confirms[#s.confirms + 1] = { text = text, yes = yes } end,
        Print = function(t) s.printed[#s.printed + 1] = t end,
        OpenOptionsWindow = function(name) s.opened = name end,
        AccountSettings = function() return s.account end,
        Apply = Noop, ShowUnlockMode = Noop, HideUnlockMode = Noop,
    }
    local env = { ipairs = ipairs, pairs = pairs, type = type, select = select, tostring = tostring, tonumber = tonumber,
        math = math, table = table, string = string, setmetatable = setmetatable, pcall = pcall, unpack = unpack,
        UIParent = Region("Frame"), NaowhForever = ns, RAID_CLASS_COLORS = CLASS,
        InCombatLockdown = function() return s.combat == true end,
        IsInGroup = function() return s.group == true end,
        IsInInstance = function() return s.instance == true end,
        AbbreviateLargeNumbers = function(n) return "<" .. tostring(n) .. ">" end,
        Enum = { DamageMeterType = { DamageDone = 0, HealingDone = 2, DamageTaken = 7, Absorbs = 4, Interrupts = 5,
                Dispels = 6, Deaths = 9 }, DamageMeterSessionType = { Overall = 0, Current = 1 } },
        C_DamageMeter = {
            GetCombatSessionFromType = function(kind, type)
                s.calls[#s.calls + 1] = { kind, type }
                if s.apiError then error("secret") end
                return s.apiResult == nil and session or s.apiResult
            end,
            ResetAllCombatSessions = function() s.resets = (s.resets or 0) + 1 end,
        },
        C_CVar = { GetCVar = function(k) return s.cvars[k] end, SetCVar = function(k, v) s.cvars[k] = v end },
        C_Timer = { After = function(sec, fn) s.timers[#s.timers + 1] = { sec = sec, fn = fn } end },
        hooksecurefunc = function(tbl, name, fn)
            local original = tbl[name]
            tbl[name] = function(...) local r = original(...); fn(...); return r end
        end,
        CreateFrame = function(kind, name, parent)
            local f = Region(kind, parent)
            f.name = name
            s.frames[#s.frames + 1] = f
            return f
        end,
    }
    env._G = env
    local files = { "DamageMeter.lua", "Constants.lua", "Data/Samples.lua", "Source.lua", "View/Meter.lua", "UI/Meter.lua",
        "UI/SettingsPage.lua" }
    for _, file in ipairs(files) do
        local chunk = assert(loadfile("NaowhForever_DamageMeter/" .. file))
        setfenv(chunk, env)
        chunk("NaowhForever")
    end
    s.ns, s.store, s.env = ns, store, env
    s.DM = ns.DamageMeter
    -- the frame of the window, and the boot frame that logs in
    for _, f in ipairs(s.frames) do
        if f.name == "NaowhForeverDamageMeter" then s.window = f end
        if f.events and f.events.PLAYER_LOGIN then s.boot = f end
    end
    function s.Login() s.boot.scripts.OnEvent(s.boot, "PLAYER_LOGIN") end
    function s.Window()
        for _, f in ipairs(s.frames) do
            if f.name == "NaowhForeverDamageMeter" then return f end
        end
    end
    function s.Fire(event)
        for _, f in ipairs(s.frames) do
            if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event) end
        end
    end
    function s.Flush()
        local due = s.timers
        s.timers = {}
        for _, t in ipairs(due) do t.fn() end
    end
    return s
end

-- the data: defaults, modes, and the API read
do
    local s = Boot()
    check("off by default", s.ns.FEATURES.damageMeter.enabled == false and s.store.Get("enabled") == false)
    check("class colors by default", s.store.Get("barColor") == "class")
    local DM = s.DM
    local C = DM.C
    check("seven lists, in order", #C.MODES == 7 and C.MODE_ORDER[1] == "damage" and C.MODE_ORDER[7] == "deaths")
    check("each has its game type", DM.Mode("healing").type == "HealingDone" and DM.Mode("deaths").type == "Deaths"
        and DM.Mode("interrupts").rate == false and DM.Mode("damage").rate == true)
    check("an unknown list reads as Damage Done", DM.Mode("bogus").key == "damage" and DM.Mode(nil).key == "damage")
    check("the API is there", DM.Available() == true)
    local got = DM.Session("taken", "overall")
    check("the session is the API's, by session type and list type",
        got == s.session and s.calls[1][1] == 0 and s.calls[1][2] == 7)
    DM.Session("damage", "current")
    check("current is the current session", s.calls[2][1] == 1 and s.calls[2][2] == 0)
    s.apiError = true
    check("an error from the API reads as nothing", #DM.Session("damage", "current").combatSources == 0)
    s.apiError = nil
    s.apiResult = "no"
    check("a result that is not a session reads as nothing", #DM.Session("damage", "current").combatSources == 0)
    s.apiResult = {}
    check("one without its sources too", #DM.Session("damage", "current").combatSources == 0)
    s.env.C_DamageMeter = nil
    check("no API: not available, and nothing", DM.Available() == false and #DM.Session("damage", "current").combatSources == 0)
    DM.Reset()
    check("and a reset does nothing", s.resets == nil)
end

-- off: nothing is built, listened to or changed
do
    local s = Boot()
    s.Login()
    check("off: no window", s.Window() == nil)
    local listening = false
    for _, f in ipairs(s.frames) do
        for e in pairs(f.events) do
            if e:find("^DAMAGE_METER") then listening = true end
        end
    end
    check("off: no damage meter events", not listening)
    check("off: the game's meter is untouched", s.cvars.damageMeterEnabled == "1" and s.account.damageMeterGameWas == nil)
end

-- on: the window, its rows and its texts
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    check("on: the window is built and shown", w and w.shown)
    check("on: three rows", #w.rows == 3 and w.rows[3].shown)
    local first, own = w.rows[1], w.rows[2]
    check("the name goes straight to the text", first.name.text == "Aldrin")
    check("the value shows total and per second, secret-safe", first.value.text == "<A> (<a>)")
    check("the bar is the amount out of the maximum", first.barMax == s.session.maxAmount
        and first.barValue == s.session.combatSources[1].totalAmount)
    check("class colors", first.color[1] == CLASS.MAGE.r and own.color[1] == CLASS.ROGUE.r)
    check("rank numbers", first.rank.text == "1" and w.rows[3].rank.text == "3")
    check("your row's edge is the Accent, the others' their class color",
        own.edge.solid[1] == THEME.accent.r and first.edge.solid[1] == CLASS.MAGE.r)
    check("the title is the list", w.title.text == "Damage Done")
    check("the session button names the session", w.session.label == "Current")
    check("the preview text is hidden with rows shown", w.empty.shown == false)

    s.store.Set("barColor", "accent")
    s.Flush()
    check("Theme Accent: every bar in the Accent", first.color[1] == THEME.accent.r and own.color[1] == THEME.accent.r
        and w.rows[3].color[3] == THEME.accent.b)
    s.store.Set("barColor", "class")
    s.store.Set("showRate", false)
    s.Flush()
    check("Show Per Second off: the total alone", first.value.text == "<A>")
    s.store.Set("showTotal", false)
    s.store.Set("showRate", true)
    s.Flush()
    check("Show Total off: the rate alone", first.value.text == "<a>")
    s.store.Set("showTotal", true)
    s.store.Set("mode", "interrupts")
    s.Flush()
    check("a list without a rate shows the total", first.value.text == "<A>")
    check("and is titled so", w.title.text == "Interrupts")
    check("and the API was asked for it", s.calls[#s.calls][2] == 5)
end

-- the pickers, reset and settings
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    local click = w.modeButton.scripts.OnClick
    click(w.modeButton, "LeftButton")
    check("a click: the next list", s.store.Get("mode") == "healing")
    click(w.modeButton, "RightButton")
    click(w.modeButton, "RightButton")
    check("right clicks go back, round the end", s.store.Get("mode") == "deaths")
    click(w.modeButton, "LeftButton")
    check("and forward round the end", s.store.Get("mode") == "damage")
    w.session.onClick()
    check("the session button switches to Overall", s.store.Get("session") == "overall")
    s.Flush()
    check("and says so", w.session.label == "Overall")
    w.session.onClick()
    check("and back", s.store.Get("session") == "current")
    w.reset.onClick()
    check("reset asks first", #s.confirms == 1 and s.resets == nil)
    s.confirms[1].yes()
    check("then clears the game's data", s.resets == 1)
    w.settings.onClick()
    check("the settings button opens the page", s.opened == "Damage Meter")
end

-- where it shows
do
    local s = Boot({ settings = { enabled = true, visibility = "group" } })
    s.Login()
    check("In a Group: hidden alone", s.Window().shown == false)
    s.group = true
    s.Fire("GROUP_ROSTER_UPDATE"); s.Flush()
    check("and shown in a group", s.Window().shown == true)
    s.store.Set("visibility", "instance"); s.Flush()
    check("In Instances: hidden outside one", s.Window().shown == false)
    s.instance = true
    s.Fire("PLAYER_ENTERING_WORLD"); s.Flush()
    check("and shown inside", s.Window().shown == true)
end

-- the game's own meter
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    check("the game's meter is turned off, and what it was is kept", s.cvars.damageMeterEnabled == "0" and s.account.damageMeterGameWas == "1")
    s.store.Set("enabled", false)
    check("off again: it is put back as it was", s.cvars.damageMeterEnabled == "1" and s.account.damageMeterGameWas == nil)
    s.store.Set("enabled", true)
    s.store.Set("hideGameMeter", false)
    check("Replace the Game's Meter off: put back too", s.cvars.damageMeterEnabled == "1")

    local off = Boot({ settings = { enabled = true }, gameMeter = "0" })
    off.Login()
    check("a game meter that was off: nothing kept, nothing restored later", off.account.damageMeterGameWas == nil)
    off.store.Set("enabled", false)
    check("and left off", off.cvars.damageMeterEnabled == "0")

    local fight = Boot({ settings = { enabled = true } })
    fight.combat = true
    fight.Login()
    check("in combat: the game's meter is left for later", fight.cvars.damageMeterEnabled == "1")
    fight.combat = false
    fight.Fire("PLAYER_REGEN_ENABLED"); fight.Flush()
    check("and turned off when combat ends", fight.cvars.damageMeterEnabled == "0")
end

-- Unlock Mode shows the sample, and switching the meter off while it is unlocked stops the listening
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    s.ns.ShowUnlockMode()
    local w = s.Window()
    check("Unlock Mode: the sample and the mover", #w.rows == 7 and s.mover.shown == true)
    s.store.Set("enabled", false)
    local listening = false
    for _, f in ipairs(s.frames) do
        for e in pairs(f.events) do
            if e:find("^DAMAGE_METER") then listening = true end
        end
    end
    check("switched off while unlocked: no damage meter events", not listening)
    s.ns.HideUnlockMode()
    check("locked again: the window goes", w.shown == false)
end

-- updates are coalesced, and the sample shows without data
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local before = #s.calls
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED")
    s.Fire("DAMAGE_METER_COMBAT_SESSION_UPDATED")
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED")
    check("an update is requested once for a burst", #s.timers == 1)
    s.Flush()
    check("and reads the session once", #s.calls == before + 1)
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("a reset redraws", #s.calls == before + 2)

    s.apiResult = { combatSources = {}, maxAmount = Amount("0"), totalAmount = Amount("0") }
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    local w = s.Window()
    check("no sources: the empty line, no rows shown", w.empty.shown == true and w.empty.text == "No data yet"
        and w.rows[1].shown == false)
    s.apiResult = nil

    s.ns.PreviewDamageMeter()
    check("the preview shows the sample's seven rows", #w.rows == 7 and w.rows[7].shown == true and w.rows[7].name.text == "Fenna")
    s.Flush()
    check("and ends after its seconds, back to the three real ones", w.rows[4].shown == false and w.rows[3].shown == true)

    s.combat = true
    s.printed = {}
    s.ns.PreviewDamageMeter()
    check("in combat: no preview, and it says why", #s.printed == 1)
end

-- the unavailable game meter
do
    local s = Boot({ settings = { enabled = true } })
    s.env.C_DamageMeter = nil
    s.Login()
    local w = s.Window()
    check("no API: the window says so", w.empty.text == "The damage meter is not available" and w.empty.shown == true)
end

-- the page
do
    local s = Boot()
    local page = s.page
    check("one page, one card, with its heading", page and #page.cards == 1 and page.cards[1].id == "meter" and page.window ~= nil)
    check("the heading reads the state", page.window.headline() == "Damage Meter is off")
    s.store.Set("enabled", true)
    check("on: it names the list", page.window.headline() == "Damage Done")
    local keys = 0
    for _, row in ipairs(page.cards[1].rows) do
        if row.key then
            keys = keys + 1
            check("the setting " .. row.key .. " has a default", s.store.Get(row.key) ~= nil or row.key == "backgroundColor")
            if row.choice then
                for _, value in ipairs(row.choice[2]) do
                    check(row.key .. " choice " .. value .. " has a label", row.choice[1][value] ~= nil)
                end
            end
        end
    end
    check("the rows cover the window, the rows and the colors", keys >= 14)
    check("one short help sentence on the card", #page.cards[1].help < 120)
end

print("PASS damage meter: " .. checks .. " checks")

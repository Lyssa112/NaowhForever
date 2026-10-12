-- Offline behavior checks for the Damage Meter (NaowhForever_DamageMeter) against stubs of the game's frames and
-- C_DamageMeter; they do not emulate the client. Amounts are tables here, so any arithmetic or comparison on a
-- value that is secret in combat fails the test, as it would in game. Run with Lua 5.1 from the repository root.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local function Noop() end
local METHODS = { __index = function(_, k) if type(k) == "string" and k:find("^[A-Z]") then return Noop end end }

local function Region(kind, parent)
    local r = setmetatable({ kind = kind, parent = parent, shown = true, scripts = {}, events = {}, children = {},
        w = 0, h = 0, alpha = 1, level = 1, text = "", points = {} }, METHODS)
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
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:ClearAllPoints() self.points = {} end
    function r:GetCenter() return self.centerX end
    function r:SetAlpha(a) self.alpha = a end
    function r:SetText(t) self.text = t end
    function r:SetTextColor(rr, g, b) self.textColor = { r = rr, g = g, b = b } end
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
-- what the stub client calls secret: a flagged table, this number and this string
local SECRET_NUMBER, SECRET_TEXT = 424242, "secret-name"

local function Amount(name) return setmetatable({ name = name }, { __tostring = function() return name end }) end

local function Source(name, class, total, rate, own, guid)
    return { name = name, classFilename = class, specIconID = 0, totalAmount = Amount(total), amountPerSecond = Amount(rate),
        isLocalPlayer = own == true, sourceGUID = guid }
end

local function Spell(id, total) return { spellID = id, totalAmount = total, amountPerSecond = total / 10 } end

-- a menu, as the game's builder hands it to the generator
local function Menu()
    local m = { items = {} }
    local function add(self, item) self.items[#self.items + 1] = item; return item end
    function m:CreateTitle(text) return add(self, { kind = "title", text = text }) end
    function m:CreateDivider() return add(self, { kind = "divider" }) end
    function m:CreateButton(text, onClick)
        local item = Menu(); item.kind, item.text, item.onClick = "button", text, onClick
        return add(self, item)
    end
    function m:CreateRadio(text, isSelected, set)
        return add(self, { kind = "radio", text = text, selected = isSelected, set = set })
    end
    function m:CreateCheckbox(text, isSelected, set)
        return add(self, { kind = "check", text = text, selected = isSelected, set = set })
    end
    function m:Find(text)
        for _, item in ipairs(self.items) do
            if item.text == text then return item end
        end
    end
    return m
end

local function Boot(opts)
    opts = opts or {}
    local s = { settings = opts.settings or {}, calls = {}, idCalls = {}, spellCalls = {}, spellIdCalls = {},
        durationCalls = {}, duration = 125,
        cvars = { damageMeterEnabled = opts.gameMeter or "1" }, timers = {}, printed = {}, frames = {}, buttons = {},
        confirms = {}, hooks = {}, account = {}, sent = {}, movers = {}, names = { [101] = "Fireball", [102] = "Pyroblast" } }
    local defaults
    local store = {}
    function store.Get(k)
        local v = s.settings[k]
        if v == nil then v = defaults[k] end
        return v
    end
    function store.Set(k, v) s.settings[k] = v end
    function store.DB() return s.settings end
    local session = { combatSources = { Source("Aldrin", "MAGE", "A", "a", false, "Player-2"),
        Source("You", "ROGUE", "B", "b", true, "Player-1"), Source("Cara", "MAGE", "C", "c", false, "Player-3") },
        maxAmount = Amount("max"), totalAmount = Amount("total") }
    s.session = session
    s.spells = { combatSpells = { Spell(101, 600), Spell(102, 300), Spell(103, 100) }, maxAmount = 600, totalAmount = 1000 }
    local ns = { THEME = THEME, MEDIA = "Media\\",
        FEATURES = { damageMeter = { enabled = false } },
        UI = {
            ModuleSettings = function(_, d) defaults = d; return store end,
            TexturePath = function(name, fallback) return name ~= "" and name or fallback end,
            AttachMover = function(frame, label, onSave, page, card)
                local m = Region("Mover", frame)
                s.mover = m
                s.movers[label] = { mover = m, save = onSave, page = page, card = card }
                return m
            end,
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
        IsInGroup = function(category) if category == 2 then return s.instanceGroup == true end return s.group == true end,
        IsInRaid = function() return s.raid == true end,
        IsInGuild = function() return s.guild == true end,
        IsInInstance = function() return s.instance == true end,
        LE_PARTY_CATEGORY_INSTANCE = 2,
        UnitGUID = function(unit) if unit == "player" then return "Player-1" end end,
        SendChatMessage = function(text, channel) s.sent[#s.sent + 1] = { text = text, channel = channel } end,
        issecretvalue = function(v)
            return (type(v) == "table" and v.secret == true) or v == SECRET_NUMBER or v == SECRET_TEXT
        end,
        AbbreviateLargeNumbers = function(n) return "<" .. tostring(n) .. ">" end,
        Enum = { DamageMeterType = { DamageDone = 0, HealingDone = 2, DamageTaken = 7, AvoidableDamageTaken = 8,
                Absorbs = 4, Interrupts = 5, Dispels = 6, Deaths = 9 },
            DamageMeterSessionType = { Overall = 0, Current = 1 } },
        C_DamageMeter = {
            GetCombatSessionFromType = function(kind, type)
                s.calls[#s.calls + 1] = { kind, type }
                if s.apiError then error("secret") end
                return s.apiResult == nil and session or s.apiResult
            end,
            GetCombatSessionFromID = function(id, type)
                s.idCalls[#s.idCalls + 1] = { id, type }
                if s.apiError then error("secret") end
                return s.idResult == nil and session or s.idResult
            end,
            GetSessionDurationSeconds = function(kind)
                s.durationCalls[#s.durationCalls + 1] = kind
                if s.durationError then error("secret") end
                return s.duration
            end,
            GetAvailableCombatSessions = function()
                if s.fightsError then error("secret") end
                return s.fights or {}
            end,
            GetCombatSessionSourceFromType = function(kind, type, guid, creature)
                s.spellCalls[#s.spellCalls + 1] = { kind = kind, type = type, guid = guid, creature = creature }
                if s.spellError then error("secret") end
                if s.spellsResult ~= nil then return s.spellsResult end
                return s.spells
            end,
            GetCombatSessionSourceFromID = function(id, type, guid, creature)
                s.spellIdCalls[#s.spellIdCalls + 1] = { id = id, type = type, guid = guid, creature = creature }
                return s.spells
            end,
            ResetAllCombatSessions = function() s.resets = (s.resets or 0) + 1 end,
        },
        C_Spell = {
            GetSpellName = function(id) return s.names[id] end,
            GetSpellTexture = function(id)
                if s.noTexture then error("bad argument") end
                return 1000 + id
            end,
        },
        MenuUtil = {
            CreateContextMenu = function(owner, generator)
                local root = Menu()
                root.owner = owner
                generator(owner, root)
                s.menu = root
            end,
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
    env.UIParent.w = 1000
    local files = { "DamageMeter.lua", "Constants.lua", "Data/Samples.lua", "Source.lua", "Report.lua", "View/Meter.lua",
        "View/Breakdown.lua", "UI/Menus.lua", "UI/Meter.lua", "UI/SettingsPage.lua" }
    for _, file in ipairs(files) do
        local chunk = assert(loadfile("NaowhForever_DamageMeter/" .. file))
        setfenv(chunk, env)
        chunk("NaowhForever")
    end
    s.ns, s.store, s.env = ns, store, env
    s.DM = ns.DamageMeter
    for _, f in ipairs(s.frames) do
        if f.events and f.events.PLAYER_LOGIN then s.boot = f end
    end
    function s.Login() s.boot.scripts.OnEvent(s.boot, "PLAYER_LOGIN") end
    local function Named(name)
        for _, f in ipairs(s.frames) do
            if f.name == name then return f end
        end
    end
    function s.Window(i) return Named(i and i > 1 and "NaowhForeverDamageMeter" .. i or "NaowhForeverDamageMeter") end
    function s.Panel() return Named("NaowhForeverDamageMeterBreakdown") end
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
    function s.Listening()
        for _, f in ipairs(s.frames) do
            for e in pairs(f.events) do
                if e:find("^DAMAGE_METER") then return true end
            end
        end
        return false
    end
    function s.Hover(w, i)
        local row = w.rows[i]
        row.scripts.OnEnter(row)
        return row
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
    check("eight lists, in order", #C.MODES == 8 and C.MODE_ORDER[1] == "damage" and C.MODE_ORDER[4] == "avoidable"
        and C.MODE_ORDER[8] == "deaths")
    check("each has its game type", DM.Mode("healing").type == "HealingDone" and DM.Mode("deaths").type == "Deaths"
        and DM.Mode("avoidable").type == "AvoidableDamageTaken" and DM.Mode("interrupts").rate == false
        and DM.Mode("damage").rate == true)
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
    check("and there are no fights", #DM.Fights() == 0)
end

-- past fights: the list, their labels and reading one by its id
do
    local s = Boot()
    local DM = s.DM
    local got = DM.Session("healing", "overall", 7)
    check("a fight is read by its id and the list's type", got == s.session and s.idCalls[1][1] == 7
        and s.idCalls[1][2] == 2 and #s.calls == 0)
    s.apiError = true
    check("a fight the game errors on reads as nothing", #DM.Session("damage", "current", 7).combatSources == 0)
    s.apiError = nil
    s.fights = { { sessionID = 3, name = "Boss", durationSeconds = 125 }, { sessionID = 5, name = "", durationSeconds = 61 },
        { sessionID = 4 } }
    local fights = DM.Fights()
    check("past fights, newest first", #fights == 3 and fights[1].id == 5 and fights[2].id == 4 and fights[3].id == 3)
    check("with the name the game gives", fights[3].name == "Boss" and fights[1].name == nil)
    check("labeled by name and length", DM.FightLabel(fights[3]) == "Boss (2:05)" and DM.FightLabel(fights[1]) == "Fight 5 (1:01)"
        and DM.FightLabel(fights[2]) == "Fight 4")
    check("a session's name", DM.SessionName("overall") == "Overall" and DM.SessionName("bogus") == "Current"
        and DM.SessionName("current", 3) == "Boss (2:05)" and DM.SessionName("current", 99) == "Fight 99")
    s.fights = {}
    for i = 1, 15 do s.fights[i] = { sessionID = i } end
    local many = DM.Fights()
    check("at most ten, the newest", #many == 10 and many[1].id == 15 and many[10].id == 6)
    s.fights = { { sessionID = SECRET_NUMBER }, { sessionID = 2, name = SECRET_TEXT, durationSeconds = SECRET_NUMBER },
        "junk" }
    local plain = DM.Fights()
    check("a secret id is skipped, a secret name or length left off", #plain == 1 and plain[1].id == 2
        and plain[1].name == nil and plain[1].seconds == nil)
    s.fightsError = true
    check("an error from the API: no fights", #DM.Fights() == 0)
end

-- how long the shown session has run
do
    local s = Boot()
    local DM = s.DM
    check("the current session's length, from the game", DM.Duration("current") == 125 and s.durationCalls[1] == 1)
    check("and the overall one's", DM.Duration("overall") == 125 and s.durationCalls[2] == 0)
    s.duration = SECRET_NUMBER
    check("a secret length reads as nothing", DM.Duration("current") == nil)
    s.duration = "soon"
    check("so does one that is no number", DM.Duration("current") == nil)
    s.duration = 125
    s.durationError = true
    check("and an error from the API", DM.Duration("current") == nil)
    s.durationError = nil
    s.fights = { { sessionID = 3, durationSeconds = 61 }, { sessionID = 4 } }
    check("a past fight's length is the game's list's", DM.Duration("current", 3) == 61 and DM.Duration("current", 4) == nil
        and DM.Duration("current", 9) == nil)
    check("a clock reads m:ss, and h:mm:ss from an hour", DM.Clock(0) == "0:00" and DM.Clock(65) == "1:05"
        and DM.Clock(59.9) == "0:59" and DM.Clock(600) == "10:00" and DM.Clock(3599) == "59:59"
        and DM.Clock(3600) == "1:00:00" and DM.Clock(3725) == "1:02:05")
    s.env.C_DamageMeter.GetSessionDurationSeconds = nil
    check("an API without it reads as nothing", DM.Duration("current") == nil)
    s.env.C_DamageMeter = nil
    check("and no API", DM.Duration("current") == nil)
end

-- the spells behind a row
do
    local s = Boot()
    local DM = s.DM
    local you = Source("You", "ROGUE", 5, 1, true, "Player-9")
    local other = Source("Aldrin", "MAGE", 5, 1, false, "Player-2")
    local data = DM.SourceSpells("damage", "current", nil, you)
    local call = s.spellCalls[1]
    check("your row asks with your own guid, the list's type and no creature", data == s.spells and call.guid == "Player-1"
        and call.type == 0 and call.kind == 1 and call.creature == nil)
    DM.SourceSpells("damage", "overall", nil, other)
    check("another row asks with its guid, for the overall session", s.spellCalls[2].guid == "Player-2" and s.spellCalls[2].kind == 0)
    DM.SourceSpells("healing", "current", 9, other)
    check("a past fight by its id", s.spellIdCalls[1].id == 9 and s.spellIdCalls[1].type == 2
        and s.spellIdCalls[1].guid == "Player-2" and s.spellIdCalls[1].creature == nil)
    local before = #s.spellCalls
    check("a secret guid: nothing, and the game is not asked",
        DM.SourceSpells("damage", "current", nil, Source("X", "MAGE", 5, 1, false, SECRET_TEXT)) == nil
        and DM.SourceSpells("damage", "current", nil, Source("Y", "MAGE", 5, 1, false, nil)) == nil
        and #s.spellCalls == before)
    check("deaths have no spells", DM.SourceSpells("deaths", "current", nil, you) == nil and #s.spellCalls == before)
    s.spellsResult = { combatSpells = {} }
    check("a source without spells reads as nothing", DM.SourceSpells("damage", "current", nil, you) == nil)
    s.spellsResult = "no"
    check("an answer that is no table too", DM.SourceSpells("damage", "current", nil, you) == nil)
    s.spellsResult = nil
    s.spellError = true
    check("an error from the API reads as nothing", DM.SourceSpells("damage", "current", nil, you) == nil)
    s.env.C_DamageMeter = nil
    check("no API: nothing", DM.SourceSpells("damage", "current", nil, you) == nil)

    check("a share of a total", DM.Percent(250, 1000) == 25)
    check("none when either is secret, missing or zero", DM.Percent(SECRET_NUMBER, 1000) == nil
        and DM.Percent(5, SECRET_NUMBER) == nil and DM.Percent(5, 0) == nil and DM.Percent(Amount("x"), 10) == nil
        and DM.Percent(5, nil) == nil)
end

-- off: nothing is built, listened to or changed
do
    local s = Boot()
    s.Login()
    check("off: no window", s.Window() == nil and s.Window(2) == nil)
    check("off: no damage meter events", not s.Listening())
    check("off: the game's meter is untouched", s.cvars.damageMeterEnabled == "1" and s.account.damageMeterGameWas == nil)
    s.env.NaowhForever_ResetDamageMeter()
    check("off: the reset key says so and resets nothing", s.resets == nil and #s.printed == 1)
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
    check("only the first window", s.Window(2) == nil and s.Window(3) == nil)

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

-- the fight time in the title bar
do
    local s = Boot({ settings = { enabled = true } })
    s.fights = { { sessionID = 3, durationSeconds = 61 } }
    s.Login()
    local w = s.Window()
    check("the title bar shows how long the session ran", w.time.text == "2:05" and w.time.shown == true)
    s.duration = 3725
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("and follows it", w.time.text == "1:02:05")
    s.store.Set("showTime", false); s.Flush()
    check("Show Fight Time off: nothing", w.time.shown == false and w.time.text == "")
    s.store.Set("showTime", true)
    s.store.Set("width", 170); s.Flush()
    check("no room beside the title: hidden", w.time.shown == false)
    s.store.Set("width", 300)
    s.duration = SECRET_NUMBER; s.Flush()
    check("a length the game keeps back: hidden", w.time.shown == false)
    s.duration = 125
    w.session.onClick()
    s.menu:Find("Fight 3 (1:01)").set()
    s.Flush()
    check("a past fight: its own length", w.time.text == "1:01" and w.time.shown == true)
    s.ns.PreviewDamageMeter()
    check("the sample has a length too", w.time.text == "3:25")
end

-- the text color
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    local row = w.rows[1]
    check("text follows the theme by default", row.name.textColor.r == THEME.fg.r and row.value.textColor.g == THEME.fg.g
        and w.title.textColor.b == THEME.fg.b)
    check("ranks, the time and the empty line are the muted color", row.rank.textColor.r == THEME.muted.r
        and w.time.textColor.r == THEME.muted.r and w.empty.textColor.r == THEME.muted.r)
    s.store.Set("textColor", { r = 1, g = 0.2, b = 0.1 })
    s.Flush()
    check("a picked color goes to names, amounts and the title", row.name.textColor.r == 1 and row.name.textColor.g == 0.2
        and row.value.textColor.b == 0.1 and w.title.textColor.g == 0.2)
    check("and to the rank, the time and the empty line", row.rank.textColor.g == 0.2 and w.time.textColor.g == 0.2
        and w.empty.textColor.g == 0.2)
    check("every row, not the first alone", w.rows[3].name.textColor.r == 1 and w.rows[3].rank.textColor.g == 0.2)
    s.store.Set("textColor", false)
    s.Flush()
    check("back to the theme", row.name.textColor.r == THEME.fg.r and row.rank.textColor.r == THEME.muted.r
        and w.title.textColor.r == THEME.fg.r)

    s.store.Set("textColor", { r = 0, g = 1, b = 0 })
    s.Flush()
    s.Hover(w, 2)
    local panel = s.Panel()
    check("the spell panel takes it", panel.title.textColor.g == 1 and panel.rows[1].name.textColor.g == 1
        and panel.rows[1].value.textColor.g == 1)
    s.store.Set("textColor", false)
    s.spellsResult = { combatSpells = {} }
    s.Hover(w, 2)
    check("and the theme's colors without one", panel.title.textColor.r == THEME.fg.r
        and panel.note.textColor.r == THEME.muted.r)
end

-- the menus: the list, the session, and the rest
do
    local s = Boot({ settings = { enabled = true } })
    s.fights = { { sessionID = 3, name = "Boss", durationSeconds = 125 }, { sessionID = 4 } }
    s.Login()
    local w = s.Window()
    w.modeButton.scripts.OnClick(w.modeButton)
    local list = s.menu
    check("the title opens the list menu on itself", list.owner == w.modeButton and list.items[1].text == "List")
    check("with the eight lists, the current one chosen", #list.items == 9 and list:Find("Damage Done").selected() == true
        and list:Find("Healing Done").selected() == false)
    list:Find("Healing Done").set()
    check("choosing one sets it", s.store.Get("mode") == "healing")
    s.Flush()
    check("and the window follows", w.title.text == "Healing Done" and s.calls[#s.calls][2] == 2)
    list:Find("Deaths").set()
    check("the last one too", s.store.Get("mode") == "deaths" and list:Find("Deaths").selected() == true)
    s.store.Set("mode", "damage")

    w.session.onClick()
    local menu = s.menu
    check("the session button opens the session menu", menu.owner == w.session and menu:Find("Current").selected() == true
        and menu:Find("Overall").selected() == false)
    check("past fights, newest first, each by its label", menu:Find("Past Fights") ~= nil and menu.items[6].text == "Fight 4"
        and menu.items[7].text == "Boss (2:05)")
    menu:Find("Overall").set()
    check("Overall is a setting", s.store.Get("session") == "overall")
    s.Flush()
    check("and the button says so", w.session.label == "Overall")
    menu:Find("Boss (2:05)").set()
    s.Flush()
    check("a past fight is read by its id", s.idCalls[#s.idCalls][1] == 3 and w.session.label == "Fight")
    s.Hover(w, 2)
    check("its spells are asked for by the fight's id", s.spellIdCalls[#s.spellIdCalls].id == 3)
    w.rows[2].scripts.OnLeave(w.rows[2])
    local asked = #s.idCalls
    w.more.onClick()
    s.menu:Find("Report To"):Find("Yourself").onClick()
    check("and so is its report", #s.idCalls == asked + 1 and s.idCalls[#s.idCalls][1] == 3)
    w.session.onClick()
    menu = s.menu
    check("and chosen in the menu, the sessions not", menu:Find("Boss (2:05)").selected() == true
        and menu:Find("Overall").selected() == false and s.store.Get("session") == "overall")
    menu:Find("Current").set()
    s.Flush()
    check("Current goes back to the live session", s.store.Get("session") == "current" and w.session.label == "Current"
        and menu:Find("Boss (2:05)").selected() == false)

    s.fights = {}
    w.session.onClick()
    check("no past fights: it says so", s.menu:Find("No Past Fights Yet") ~= nil)

    s.fights = { { sessionID = 3 } }
    s.store.Set("session", "current")
    w.session.onClick()
    s.menu:Find("Fight 3").set()
    s.Flush()
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("a reset forgets the past fight", w.session.label == "Current")
end

-- the window menu
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    w.more.onClick()
    local menu = s.menu
    check("the ... button opens the window menu", menu.owner == w.more and menu.items[1].text == "Damage Meter")
    check("with a report, a reset, add, lock and settings", menu:Find("Report To") ~= nil and menu:Find("Reset Data") ~= nil
        and menu:Find("Add Window") ~= nil and menu:Find("Lock Window").kind == "check" and menu:Find("Settings") ~= nil)
    check("no Close Window on the first window", menu:Find("Close Window") == nil)
    menu:Find("Reset Data").onClick()
    check("reset asks first", #s.confirms == 1 and s.resets == nil)
    s.confirms[1].yes()
    check("then clears the game's data", s.resets == 1)
    menu:Find("Lock Window").set()
    check("Lock Window is the setting", s.store.Get("locked") == true and menu:Find("Lock Window").selected() == true)
    menu:Find("Settings").onClick()
    check("Settings opens the page", s.opened == "Damage Meter")
    local channels = menu:Find("Report To").items
    check("reports go to yourself and Say alone, alone", #channels == 2 and channels[1].text == "Yourself" and channels[2].text == "Say")
    s.group, s.raid, s.guild, s.instanceGroup = true, true, true, true
    w.more.onClick()
    local all = s.menu:Find("Report To").items
    check("and to the party, raid, instance and guild when there", #all == 6 and all[3].text == "Party" and all[4].text == "Raid"
        and all[5].text == "Instance" and all[6].text == "Guild")
    s.menu:Find("Add Window").onClick()
    check("Add Window opens the next one", s.store.Get("window2") == true and s.Window(2) ~= nil and s.Window(2).shown == true)
    w.more.onClick()
    s.menu:Find("Add Window").onClick()
    check("and the one after", s.store.Get("window3") == true and s.Window(3).shown == true)
    w.more.onClick()
    check("with all three open there is nothing to add", s.menu:Find("Add Window") == nil)
    local second = s.Window(2)
    second.more.onClick()
    check("the other windows can close", s.menu.items[1].text == "Damage Meter 2" and s.menu:Find("Close Window") ~= nil)
    s.menu:Find("Close Window").onClick()
    check("closing hides it and keeps the rest", s.store.Get("window2") == false and second.shown == false
        and s.Window(3).shown == true and s.Window().shown == true)
    w.more.onClick()
    check("and it can be added again", s.menu:Find("Add Window") ~= nil)
end

-- more windows: each with its own list, session, size and place
do
    local s = Boot({ settings = { enabled = true, window2 = true, mode2 = "taken", session2 = "overall", width2 = 240,
        height2 = 120 } })
    s.Login()
    local one, two = s.Window(), s.Window(2)
    check("a second window, shown", two and two.shown and s.Window(3) == nil)
    check("its own list and session", two.title.text == "Damage Taken" and two.session.label == "Overall"
        and one.title.text == "Damage Done" and one.session.label == "Current")
    check("each asked the game for its own", s.calls[#s.calls][2] == 7 and s.calls[#s.calls][1] == 0)
    check("its own size", two.w == 240 and two.h == 120 and one.w == 300 and one.h == 190)
    s.store.Set("mode2", "healing")
    s.Flush()
    check("a change to one leaves the other", two.title.text == "Healing Done" and one.title.text == "Damage Done")
    two.modeButton.scripts.OnClick(two.modeButton)
    s.menu:Find("Absorbs").set()
    check("a window's list menu sets its own list", s.store.Get("mode2") == "absorbs" and s.settings.mode == nil)
    two.header.scripts.OnDragStart(two.header)
    two.header.scripts.OnDragStop(two.header)
    check("dragging a window saves its own place", s.store.Get("meterPos2").point == "TOPLEFT"
        and s.settings.meterPos == nil)
    check("their own name, page and card for Unlock Mode", s.movers["Damage Meter"].card == "Damage Meter/Settings:meter"
        and s.movers["Damage Meter 2"].card == "Damage Meter/Settings:windows"
        and s.movers["Damage Meter 2"].page == "Damage Meter/Settings")
    s.movers["Damage Meter 2"].save({ point = "CENTER", relPoint = "CENTER", x = 5, y = 6 })
    check("a moved window saves its own place", s.store.Get("meterPos2").x == 5 and s.store.Get("meterPos").x == -24)
    check("the others start stacked above the first", s.settings.meterPos == nil and s.store.Get("meterPos").y == 210
        and s.store.Get("meterPos3").y == 630)
    check("keys carry the window's number", s.DM.Key("mode", 1) == "mode" and s.DM.Key("mode", 2) == "mode2"
        and s.DM.Key("width", 3) == "width3")
    s.store.Set("window2", false)
    check("switching one off hides just it", two.shown == false and one.shown == true)
    s.store.Set("enabled", false)
    check("the module off hides all", one.shown == false and not s.Listening())
end

-- the wheel scrolls the window under it, from its rows or from its frame
do
    local s = Boot({ settings = { enabled = true, window2 = true, height2 = 70 } })
    s.Login()
    local one, two = s.Window(), s.Window(2)
    check("a short window shows one row", two.rows[1].shown == true and two.rows[2] == nil
        and two.rows[1].name.text == "Aldrin")
    two.rows[1].scripts.OnMouseWheel(two.rows[1], -1)
    check("a row passes the wheel to its window: one row down", two.rows[1].name.text == "You"
        and two.rows[1].rank.text == "2" and one.rows[1].name.text == "Aldrin")
    two.scripts.OnMouseWheel(two, -1)
    check("and the frame scrolls it too", two.rows[1].name.text == "Cara")
    two.scripts.OnMouseWheel(two, -1)
    check("not past the last row", two.rows[1].name.text == "Cara")
    two.scripts.OnMouseWheel(two, 2)
    check("and back to the top", two.rows[1].name.text == "Aldrin")
end

-- the second window's grip saves its own size
do
    local s = Boot({ settings = { enabled = true, window2 = true } })
    s.Login()
    local two = s.Window(2)
    local grip
    for _, f in ipairs(s.frames) do
        if f.parent == two and f.kind == "Button" and f.scripts.OnMouseDown then grip = f end
    end
    grip.scripts.OnMouseDown(grip, "LeftButton")
    check("the grip sizes the window", two.sizing == true)
    two.w, two.h = 260.4, 150.6
    grip.scripts.OnMouseUp(grip)
    check("and saves its size under its number", s.store.Get("width2") == 260 and s.store.Get("height2") == 151
        and s.settings.width == nil)
end

-- where it shows
do
    local s = Boot({ settings = { enabled = true, visibility = "group", window2 = true } })
    s.Login()
    check("In a Group: hidden alone", s.Window().shown == false and s.Window(2).shown == false)
    s.group = true
    s.Fire("GROUP_ROSTER_UPDATE"); s.Flush()
    check("and shown in a group", s.Window().shown == true and s.Window(2).shown == true)
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
    local s = Boot({ settings = { enabled = true, window2 = true } })
    s.Login()
    s.ns.ShowUnlockMode()
    local w = s.Window()
    check("Unlock Mode: the sample and the mover, on every open window", #w.rows == 7 and s.Window(2).rows[7] ~= nil
        and s.movers["Damage Meter 2"].mover.shown == true and s.movers["Damage Meter"].mover.shown == true)
    s.store.Set("enabled", false)
    check("switched off while unlocked: no damage meter events", not s.Listening())
    s.ns.HideUnlockMode()
    check("locked again: the windows go", w.shown == false and s.Window(2).shown == false)
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

-- the reset key
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    s.env.NaowhForever_ResetDamageMeter()
    check("the reset key clears the data and says so", s.resets == 1 and #s.printed == 1 and #s.confirms == 0)
end

-- the report
do
    local s = Boot({ settings = { enabled = true, reportLines = 2 } })
    s.Login()
    local DM = s.DM
    local plain = { combatSources = {
        { name = "Aldrin", totalAmount = 1500, amountPerSecond = 150 }, { name = SECRET_TEXT, totalAmount = 1200, amountPerSecond = 120 },
        { name = "You", totalAmount = 900, amountPerSecond = 90 }, { name = "Cara", totalAmount = SECRET_NUMBER, amountPerSecond = 30 },
        { name = Amount("table"), totalAmount = 200, amountPerSecond = 20 }, { name = "Dan", totalAmount = 100, amountPerSecond = 10 },
    }, maxAmount = 1500, totalAmount = 4000 }
    local lines = DM.ReportLines(plain, DM.Mode("damage"), "Current", 2, true)
    check("a header, then the top rows with total and rate", #lines == 3 and lines[1] == "Damage Done, Current"
        and lines[2] == "1. Aldrin  <1500> (<150>)")
    check("a secret name is left out and the ranks go on", lines[3] == "2. You  <900> (<90>)")
    lines = DM.ReportLines(plain, DM.Mode("damage"), "Current", 10, false)
    check("without the rate, the total alone; secret names and amounts left out",
        #lines == 4 and lines[2] == "1. Aldrin  <1500>" and lines[4] == "3. Dan  <100>")
    lines = DM.ReportLines(plain, DM.Mode("interrupts"), "Overall", 1, true)
    check("a list without a rate has none", lines[1] == "Interrupts, Overall" and lines[2] == "1. Aldrin  <1500>")
    check("a secret rate is left off the line", DM.ReportLines({ combatSources = { { name = "A", totalAmount = 5,
        amountPerSecond = SECRET_NUMBER } } }, DM.Mode("damage"), "x", 5, true)[2] == "1. A  <5>")

    s.apiResult = plain
    DM.Report("PARTY", "damage", "current", nil)
    check("sent to the channel, header first, as many as Report Lines says", #s.sent == 3 and s.sent[1].channel == "PARTY"
        and s.sent[1].text == "Damage Done, Current" and s.sent[3].text == "2. You  <900> (<90>)")
    s.sent = {}
    s.store.Set("showRate", false)
    DM.Report("RAID", "damage", "overall", nil)
    check("Show Per Second off: totals only", s.sent[2].text == "1. Aldrin  <1500>" and s.sent[1].text == "Damage Done, Overall")
    s.sent = {}
    s.printed = {}
    DM.Report("SELF", "damage", "current", nil)
    check("Yourself: printed, not sent", #s.sent == 0 and #s.printed == 3)
    s.printed = {}
    s.combat = true
    DM.Report("SAY", "damage", "current", nil)
    check("in combat: nothing is sent, and it says why", #s.sent == 0 and #s.printed == 1)
    s.combat = false
    s.printed = {}
    s.apiResult = { combatSources = {}, maxAmount = 0, totalAmount = 0 }
    DM.Report("SAY", "damage", "current", nil)
    check("nothing to report: it says so", #s.sent == 0 and #s.printed == 1)
    s.apiResult = nil
    s.sent = {}
    s.fights = { { sessionID = 3, name = "Boss", durationSeconds = 60 } }
    s.idResult = plain
    DM.Report("GUILD", "damage", "current", 3)
    check("a past fight is reported by its name", s.sent[1].text == "Damage Done, Boss (1:00)" and s.idCalls[#s.idCalls][1] == 3)

    s.apiResult = plain
    s.sent = {}
    s.Window().more.onClick()
    s.menu:Find("Report To"):Find("Say").onClick()
    check("the menu's channel sends what its window shows", #s.sent == 3 and s.sent[1].channel == "SAY"
        and s.sent[1].text == "Damage Done, Current")
end

-- the spell breakdown on hover
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    local row = s.Hover(w, 2)
    local panel = s.Panel()
    check("hover: the panel shows, titled by the row", panel and panel.shown and panel.title.text == "You")
    check("with the spells of your row, by your own guid", s.spellCalls[#s.spellCalls].guid == "Player-1")
    check("the spells, in the game's order, with their names", panel.rows[1].name.text == "Fireball"
        and panel.rows[2].name.text == "Pyroblast" and panel.rows[3].name.text == "Unknown")
    check("each a bar out of the largest", panel.rows[2].barMax == 600 and panel.rows[2].barValue == 300)
    check("amount and share when both are plain", panel.rows[1].value.text == "<600>  60.0%"
        and panel.rows[3].value.text == "<100>  10.0%")
    check("and the spell's icon", panel.rows[1].icon.texture == 1101 and panel.rows[1].icon.shown == true)
    check("only as many rows as spells, and no note", panel.rows[4].shown == false and panel.note.shown == false
        and panel.h == 24 + 3 * 20 - 2 + 6)
    check("the bars in the row's class color", panel.rows[1].color[1] == CLASS.ROGUE.r)
    local spells = s.spells
    local many = {}
    for i = 1, 12 do many[i] = Spell(200 + i, 100 - i) end
    s.spells = { combatSpells = many, maxAmount = 100, totalAmount = 1000 }
    s.Hover(w, 2)
    check("at most eight spells", panel.rows[8].shown == true and panel.h == 24 + 8 * 20 - 2 + 6)
    s.spells = spells
    s.Hover(w, 2)
    check("on the left of a window on the right half, the right of one on the left",
        panel.points[1][1] == "TOPRIGHT" and panel.points[1][2] == row)
    w.centerX = 100
    s.Hover(w, 2)
    check("a window on the left half: beside its right edge", s.Panel().points[1][1] == "TOPLEFT")
    w.rows[2].scripts.OnLeave(w.rows[2])
    check("leaving hides it", panel.shown == false)

    s.spells.totalAmount = SECRET_NUMBER
    s.Hover(w, 2)
    check("a secret total: amounts, no share", panel.rows[1].value.text == "<600>")
    s.spells.totalAmount = 1000
    s.noTexture = true
    s.Hover(w, 2)
    check("an icon the game refuses: no icon, no error", panel.rows[1].icon.shown == false)
    s.noTexture = nil
    s.names = { [101] = SECRET_TEXT }
    s.Hover(w, 2)
    check("a secret name goes to the text as it is", panel.rows[1].name.text == SECRET_TEXT)
    s.names = { [101] = "Fireball", [102] = "Pyroblast" }

    s.combat = true
    s.Hover(w, 1)
    check("in combat, a row with a readable guid still shows", panel.rows[1].shown == true)
    s.session.combatSources[1].sourceGUID = SECRET_TEXT
    s.spellCalls = {}
    s.Hover(w, 1)
    check("in combat, a row with a secret guid says spells show after combat", #s.spellCalls == 0 and panel.rows[1].shown == false
        and panel.note.text == "Spells show after combat." and panel.note.shown == true)
    s.combat = false
    s.Hover(w, 1)
    check("out of combat with no data: a plain note", panel.note.text == "No spell data.")
    s.session.combatSources[1].sourceGUID = "Player-2"
    s.spellsResult = { combatSpells = {} }
    s.Hover(w, 1)
    check("a source with no spells says so", panel.note.text == "No spell data." and panel.note.shown == true)
    s.spellsResult = nil

    s.store.Set("mode", "deaths"); s.Flush()
    s.spellCalls = {}
    w.rows[1].scripts.OnLeave(w.rows[1])
    s.Hover(w, 1)
    check("Deaths: no panel, no question", panel.shown == false and #s.spellCalls == 0)
    s.store.Set("mode", "damage"); s.Flush()

    s.store.Set("breakdown", false)
    s.spellCalls = {}
    s.Hover(w, 2)
    check("Spell Breakdown off: nothing", panel.shown == false and #s.spellCalls == 0)
    s.store.Set("breakdown", true)
end

-- the panel follows updates, and goes with its window
do
    local s = Boot({ settings = { enabled = true, visibility = "group" } })
    s.group = true
    s.Login()
    local w = s.Window()
    s.Hover(w, 2)
    local panel = s.Panel()
    s.spells.combatSpells = { Spell(101, 50) }
    s.spells.maxAmount, s.spells.totalAmount = 50, 100
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("an update redraws the hovered row's spells", panel.rows[1].value.text == "<50>  50.0%" and panel.rows[2].shown == false)
    s.group = false
    s.Fire("GROUP_ROSTER_UPDATE"); s.Flush()
    check("the window hiding takes the panel with it", w.shown == false and panel.shown == false)

    local sample = Boot({ settings = { enabled = true } })
    sample.Login()
    sample.ns.ShowUnlockMode()
    sample.Hover(sample.Window(), 1)
    check("the sample has no spells to show", sample.Panel() == nil or sample.Panel().shown == false)
end

-- the page
do
    local s = Boot()
    local page = s.page
    check("one page, two cards: the meter and its more windows", page and #page.cards == 2
        and page.cards[1].id == "meter" and page.cards[2].id == "windows" and page.window ~= nil)
    check("the heading reads the state", page.window.headline() == "Damage Meter is off")
    s.store.Set("enabled", true)
    check("on: it names the list", page.window.headline() == "Damage Done")
    local keys = {}
    for _, card in ipairs(page.cards) do
        for _, row in ipairs(card.rows) do
            if row.key then
                keys[#keys + 1] = row.key
                check("the setting " .. row.key .. " has a default", s.store.Get(row.key) ~= nil or row.key == "backgroundColor")
                if row.choice then
                    for _, value in ipairs(row.choice[2]) do
                        check(row.key .. " choice " .. value .. " has a label", row.choice[1][value] ~= nil)
                    end
                end
            end
        end
    end
    check("the rows cover the windows, the rows, the hover and the colors", #keys >= 28)
    check("one short help sentence on each card", #page.cards[1].help < 120 and #page.cards[2].help < 120)
    local pick
    for _, r in ipairs(page.cards[1].rows) do
        if r.key == "textColor" then pick = r end
    end
    check("a Text Color row, a color picker", pick and pick.colour == true and pick.label == "Text Color")
    local pr, pg, pb = pick.get()
    check("it shows the theme's foreground until one is picked", pr == THEME.fg.r and pg == THEME.fg.g and pb == THEME.fg.b)
    pick.set(0.1, 0.2, 0.3)
    local c = s.store.Get("textColor")
    check("picking stores the color", type(c) == "table" and c.r == 0.1 and c.g == 0.2 and c.b == 0.3)
    pr, pg, pb = pick.get()
    check("and the picker shows it", pr == 0.1 and pg == 0.2 and pb == 0.3)
    s.store.Set("textColor", false)
    check("the first card's summary reads window one", page.cards[1].summary(s.store) == "Damage Done, 300 by 190")
    check("the closed windows say off", page.cards[2].summary(s.store) == "Second: Off, Third: Off")
    s.store.Set("window2", true)
    s.store.Set("mode2", "healing")
    check("an open one reads its own list", page.cards[2].summary(s.store) == "Second: Healing Done, Third: Off")
    local more = page.cards[2].rows
    check("each window has a group and five rows, with its own keys", #more == 12 and more[2].key == "window2"
        and more[3].key == "mode2" and more[6].key == "height2" and more[8].key == "window3" and more[12].key == "height3")
    check("the labels differ across the card", more[3].label ~= more[9].label and more[2].label ~= more[8].label)
    check("an open window's rows are enabled", more[2].needs() == true and more[3].needs() == true)
    s.store.Set("window2", false)
    check("closed: its own rows are disabled, its toggle is not", more[3].needs() == false and more[2].needs() == true)
end

print("PASS damage meter: " .. checks .. " checks")

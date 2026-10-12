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
    function r:SetTexture(t, h, v) self.texture = t; self.wrap = { h, v } end
    function r:CreateTexture() return Region("Texture", self) end
    function r:GetLeft() return 100 end
    function r:GetTop() return 300 end
    function r:GetEffectiveScale() return 1 end
    function r:StartMoving() self.dragging = true end
    function r:StartSizing(point) self.sizingFrom = point end
    function r:StopMovingOrSizing() self.dragging, self.sizingFrom = false, nil end
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
        Border = function(frame)
            return { _frame = Region("Border", frame),
                SetColor = function(self, r, g, b, a) self.color = { r = r, g = g, b = b, a = a } end }
        end,
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
        UnitName = function(unit)
            if unit == "player" then return s.ownName or "You", s.ownSurname end
            local u = s.units and s.units[unit]
            if u then return u.name, u.surname end
        end,
        UnitClass = function(unit)
            if unit == "player" then return "Rogue", s.ownClass or "ROGUE" end
            local u = s.units and s.units[unit]
            if u then return u.class, u.class end
        end,
        UnitExists = function(unit) return unit == "player" or (s.units ~= nil and s.units[unit] ~= nil) end,
        UnitIsPlayer = function(unit) return not (s.units and s.units[unit] and s.units[unit].npc) end,
        UnitIsUnit = function(a, b)
            if a == b then return true end
            local u = s.units and s.units[a]
            return u ~= nil and u.self == true and b == "player"
        end,
        GetNumGroupMembers = function() return s.members or 1 end,
        Ambiguate = function(name) return (name:gsub("%-.+$", "")) end,
        Constants = opts.separator and { CharacterNameSeparatorConsts = {
            CHARACTERNAME_SURNAME_SEPARATOR = opts.separator } } or nil,
        C_PlayerInfo = opts.forever and { ShouldDisplaySurname = function() return s.showSurname ~= false end } or nil,
        SendChatMessage = function(text, channel) s.sent[#s.sent + 1] = { text = text, channel = channel } end,
        issecretvalue = function(v)
            return (type(v) == "table" and v.secret == true) or v == SECRET_NUMBER or v == SECRET_TEXT
        end,
        AbbreviateLargeNumbers = function(n) return "<" .. tostring(n) .. ">" end,
        CreateAbbreviateConfig = function(rows) s.configs = (s.configs or 0) + 1; return { rows = rows } end,
        AbbreviateNumbers = function(n, options)
            s.abbreviated = { n = n, rows = options.config.rows }
            return "{" .. tostring(n) .. ":" .. #options.config.rows .. "}"
        end,
        GetLocale = function() return s.locale or "enUS" end,
        LibStub = function() return s.lsm end,
        GetTime = function() return s.now or 0 end,
        time = function() return s.clock or 1700000000 end,
        date = os.date,
        GetInstanceInfo = function() return s.instanceName end,
        GetZoneText = function() return s.zone or "Plains" end,
        Screenshot = function() s.shots = (s.shots or 0) + 1 end,
        CLASS_SORT_ORDER = opts.classes,
        LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage", ROGUE = "Rogue" },
        Enum = { DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, DamageTaken = 7,
                AvoidableDamageTaken = 8, Absorbs = 4, Interrupts = 5, Dispels = 6, Deaths = 9 },
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
    local files = { "DamageMeter.lua", "Constants.lua", "Data/Samples.lua", "Source.lua", "Names.lua", "Report.lua",
        "History.lua", "View/Meter.lua", "View/Breakdown.lua", "UI/History.lua", "UI/Menus.lua", "UI/Meter.lua",
        "UI/SettingsPage.lua" }
    for _, file in ipairs(files) do
        local chunk = assert(loadfile("NaowhForever_DamageMeter/" .. file))
        setfenv(chunk, env)
        chunk("NaowhForever")
    end
    s.ns, s.store, s.env = ns, store, env
    if opts.media then
        s.lsm = { List = function(_, kind) return kind == "background" and { "Marble", "Dots" } or {} end,
            Fetch = function(_, kind, name)
                if kind == "background" and (name == "Marble" or name == "Dots") then return "Media\\" .. name end
            end }
    end
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
    function s.Fire(event, ...)
        for _, f in ipairs(s.frames) do
            if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
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
    check("ten lists, in order", #C.MODES == 10 and C.MODE_ORDER[1] == "damage" and C.MODE_ORDER[2] == "dps"
        and C.MODE_ORDER[4] == "hps" and C.MODE_ORDER[6] == "avoidable" and C.MODE_ORDER[10] == "deaths")
    check("DPS and HPS are the game's own lists and lead with the per-second figure",
        DM.Mode("dps").type == "Dps" and DM.Mode("hps").type == "Hps" and DM.Mode("dps").rateFirst == true
        and DM.Mode("damage").rateFirst == nil)
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
    check("two columns: the total, then the per-second figure, secret-safe", first.colA.text == "<A>"
        and first.colB.text == "<a>" and first.colA.shown == true and first.colB.shown == true)
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
    check("Show Per Second off: the total alone, in the right column", first.colB.text == "<A>"
        and first.colA.shown == false)
    s.store.Set("showTotal", false)
    s.store.Set("showRate", true)
    s.Flush()
    check("Show Total off: the rate alone", first.colB.text == "<a>" and first.colA.shown == false)
    s.store.Set("showTotal", true)
    s.store.Set("mode", "interrupts")
    s.Flush()
    check("a list without a rate shows the total", first.colB.text == "<A>" and first.colA.shown == false)
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

-- names: full, first, last, initials, and found by class in combat
do
    local s = Boot({ settings = { enabled = true } })
    local DM = s.DM
    local function Show(name, format, class)
        s.store.Set("nameFormat", format)
        return DM.DisplayName({ name = name, classFilename = class or "MAGE" })
    end
    check("full: both words, the realm dropped", Show("Aldrin Stormwind-Draenor", "full") == "Aldrin Stormwind")
    check("first: the first word", Show("Aldrin Stormwind-Draenor", "first") == "Aldrin")
    check("last: the last word", Show("Aldrin Stormwind-Draenor", "last") == "Stormwind")
    check("initials: the first letter of each word", Show("Aldrin Stormwind", "initials") == "A.S.")
    check("first name and the last name's initial", Show("Aldrin Stormwind", "firstInitial") == "Aldrin S.")
    check("a one-word name stays one word", Show("Cara", "first") == "Cara" and Show("Cara", "last") == "Cara"
        and Show("Cara", "initials") == "C." and Show("Cara", "firstInitial") == "Cara")
    check("a realm alone is dropped", Show("Cara-Draenor", "full") == "Cara")
    check("letters beyond ASCII are whole characters", Show("\195\137dith \195\150rn", "initials")
        == "\195\137.\195\150.")
    check("a name that is not a player's is left as it is", DM.DisplayName({ name = "Boar Dog", classFilename = "",
        sourceCreatureID = 5 }) == "Boar Dog")
    for i = 1, 300 do Show("Name" .. i .. " Last", "first") end
    check("the cache wipes itself and still answers", Show("Name1 Last", "first") == "Name1"
        and Show("Zed Last", "first") == "Zed")

    s.store.Set("nameFormat", "first")
    check("your own row comes from your unit", DM.DisplayName({ name = s.session.combatSources[1].name,
        classFilename = "ROGUE", isLocalPlayer = true }) == "You")
    s.ownName = "Rowan"
    check("not from the name the row carries, which is secret in combat", DM.DisplayName({ name = SECRET_TEXT,
        classFilename = "ROGUE", isLocalPlayer = true }) == "Rowan")

    s.units = { party1 = { name = "Brenna Ashdown", surname = nil, class = "WARLOCK" },
        party2 = { name = "Corvus Reed", class = "HUNTER" }, party3 = { name = "Dara Vale", class = "HUNTER" } }
    s.group = true
    s.members = 4
    DM.ScanRoster()
    local function Secret(class) return { name = SECRET_TEXT, classFilename = class } end
    check("in combat a secret name is found by its class, then written", DM.DisplayName(Secret("WARLOCK")) == "Brenna")
    s.store.Set("nameFormat", "initials")
    check("in the format chosen", DM.DisplayName(Secret("WARLOCK")) == "B.A.")
    check("a class two players share stays as it is, whole", DM.DisplayName(Secret("HUNTER")) == SECRET_TEXT)
    check("so does one that is not in the group", DM.DisplayName(Secret("PRIEST")) == SECRET_TEXT)
    s.units.party2 = nil
    DM.ScanRoster()
    check("a new scan: the hunter is alone now", DM.DisplayName(Secret("HUNTER")) == "D.V.")
    s.group = false
    DM.ScanRoster()
    check("alone, nobody to find", DM.DisplayName(Secret("HUNTER")) == SECRET_TEXT)
    s.raid = true
    s.group = true
    s.members = 2
    s.units = { raid1 = { name = "You", class = "ROGUE", self = true }, raid2 = { name = "Eira Moss", class = "DRUID" } }
    DM.ScanRoster()
    check("in a raid: raid units, and you not twice", DM.DisplayName(Secret("DRUID")) == "E.M."
        and DM.DisplayName({ name = SECRET_TEXT, classFilename = "ROGUE" }) == "R.")
    s.units.raid2.name = SECRET_TEXT
    DM.ScanRoster()
    check("a secret name in the group is not used", DM.DisplayName(Secret("DRUID")) == SECRET_TEXT)
end

-- a surname separator other than a space
do
    local s = Boot({ settings = { enabled = true }, separator = "_" })
    local DM = s.DM
    local function Show(name, format)
        s.store.Set("nameFormat", format)
        return DM.DisplayName({ name = name, classFilename = "MAGE" })
    end
    check("words are cut at the separator too", Show("Aldrin_Stormwind", "first") == "Aldrin"
        and Show("Aldrin_Stormwind", "last") == "Stormwind" and Show("Aldrin_Stormwind", "initials") == "A.S."
        and Show("Aldrin_Stormwind", "full") == "Aldrin Stormwind")
end

-- surnames on a client that has them
do
    local s = Boot({ settings = { enabled = true, nameFormat = "full" }, forever = true })
    local DM = s.DM
    s.ownName, s.ownSurname = "Rowan", "Thorne"
    local own = { name = SECRET_TEXT, classFilename = "ROGUE", isLocalPlayer = true }
    check("your name with its surname", DM.DisplayName(own) == "Rowan Thorne")
    s.store.Set("nameFormat", "last")
    check("and its last name", DM.DisplayName(own) == "Thorne")
    s.showSurname = false
    s.store.Set("nameFormat", "full")
    check("Blizzard's show-surname setting leaves yours off", DM.DisplayName(own) == "Rowan")
    s.showSurname = true
    s.ownSurname = ""
    check("an empty surname adds nothing", DM.DisplayName(own) == "Rowan")
    s.ownSurname = "Thorne"
    s.units = { party1 = { name = "Brenna", surname = "Ashdown", class = "WARLOCK" } }
    s.group = true
    DM.ScanRoster()
    check("a group member's too", DM.DisplayName({ name = SECRET_TEXT, classFilename = "WARLOCK" }) == "Brenna Ashdown")
    s.units.party1 = { name = "Brenna Ashdown", surname = "Ashdown", class = "WARLOCK" }
    DM.ScanRoster()
    check("a name that already carries it is not doubled",
        DM.DisplayName({ name = SECRET_TEXT, classFilename = "WARLOCK" }) == "Brenna Ashdown")
end

-- the window and the roster follow the group
do
    local s = Boot({ settings = { enabled = true, nameFormat = "first" } })
    s.units = { party1 = { name = "Aldrin Hale", class = "MAGE" } }
    s.group = true
    s.members = 2
    s.session.combatSources[1].name = SECRET_TEXT
    s.Login()
    local w = s.Window()
    check("the rows write the names the way chosen", w.rows[1].name.text == "Aldrin" and w.rows[2].name.text == "You"
        and w.rows[3].name.text == "Cara")
    s.units.party1 = nil
    s.Fire("GROUP_ROSTER_UPDATE"); s.Flush()
    check("a roster change is scanned again", w.rows[1].name.text == SECRET_TEXT)
    s.units.party1 = { name = "Aldrin Hale", class = "MAGE" }
    s.Fire("PLAYER_REGEN_ENABLED"); s.Flush()
    check("and after combat", w.rows[1].name.text == "Aldrin")
    s.Hover(w, 1)
    check("the spell panel is titled the same way", s.Panel().title.text == "Aldrin")
    s.units.party1 = { name = "Aldrin Hale", class = "WARLOCK" }
    s.Fire("PLAYER_ENTERING_WORLD"); s.Flush()
    check("and on entering the world", w.rows[1].name.text == SECRET_TEXT)
    s.apiResult = { combatSources = { { name = "Aldrin Hale", classFilename = "MAGE", totalAmount = 100,
        amountPerSecond = 10 } }, maxAmount = 100, totalAmount = 100 }
    s.printed = {}
    s.DM.Report("SELF", "damage", "current", nil)
    check("and a report", s.printed[2] == "1. Aldrin  <100> (<10>)")
end

-- the summary line, the title and time sizes
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    check("the summary line is off by default", w.summary.shown == false)
    s.store.Set("showSummary", true); s.Flush()
    check("on: the session, its total and your rank, the total as the game's secret", w.summary.shown == true
        and w.summary.text == "Current   Damage <total>   Rank 2/3")
    check("the rows move down for it, and the column titles", w.rows[1].points[1][5] == -(26 + 16 + 16) - 6
        and w.headB.points[1][5] == -(26 + 16) - 3)
    s.apiResult = { combatSources = { { name = "You", classFilename = "ROGUE", isLocalPlayer = true,
        totalAmount = 5000, amountPerSecond = 40 } }, maxAmount = 5000, totalAmount = 5000 }
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("with plain numbers: the raid's per-second figure too", w.summary.text
        == "Current   Damage <5000>   Raid DPS <40>   Rank 1/1")
    s.apiResult.totalAmount = SECRET_NUMBER
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("a total the game keeps back has none", w.summary.text == "Current   Damage <424242>   Rank 1/1")
    s.apiResult.totalAmount = 5000
    s.duration = SECRET_NUMBER
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("nor a length it keeps back", w.summary.text == "Current   Damage <5000>   Rank 1/1")
    s.duration = 0
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("nor no time at all", w.summary.text == "Current   Damage <5000>   Rank 1/1")
    s.duration = 125
    s.apiResult.combatSources[1].isLocalPlayer = false
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("without you in it, no rank", w.summary.text == "Current   Damage <5000>   Raid DPS <40>")
    s.apiResult.combatSources[1].isLocalPlayer = true
    s.store.Set("mode", "interrupts"); s.Flush()
    check("a list without a rate has no raid figure, and names its own total", w.summary.text
        == "Current   Interrupts <5000>   Rank 1/1")
    s.store.Set("mode", "damage")
    s.store.Set("session", "overall"); s.Flush()
    check("it names the session", w.summary.text:find("^Overall   ") ~= nil)
    s.store.Set("session", "current")
    w.summary.text = "untouched"
    s.store.Set("showSummary", false); s.Flush()
    check("off again: gone, not painted, and the rows back", w.summary.shown == false and w.summary.text == "untouched"
        and w.rows[1].points[1][5] == -(26 + 16) - 6)
    s.apiResult = nil

    check("the title and the time have their own sizes", w.title.fontSize == 12 and w.time.fontSize == 11
        and w.time.w == 48)
    s.store.Set("titleSize", 16); s.store.Set("timeSize", 14); s.Flush()
    check("which follow the settings, the time's room with it", w.title.fontSize == 16 and w.time.fontSize == 14
        and w.time.w == math.ceil(7 * 0.62 * 14))
    check("the time still shows", w.time.shown == true and w.time.text == "2:05")
    s.store.Set("width", 205); s.Flush()
    check("a bigger time needs more room: it fits at 11 and not at 14", w.time.shown == false)
    s.store.Set("width", 300); s.Flush()
    check("and the time is back with it", w.time.shown == true)
    check("they are drawn in the window's font", w.title.font == "" and w.summary.font == "")
    s.store.Set("font", "Fonts\\x.ttf"); s.Flush()
    check("and a font picked reaches them", w.title.font == "Fonts\\x.ttf" and w.time.font == "Fonts\\x.ttf"
        and w.summary.font == "Fonts\\x.ttf")
end

-- the columns and their titles
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    check("column titles over the columns, from the list", w.headName.shown == true and w.headName.text == "Name"
        and w.headA.text == "Damage" and w.headB.text == "DPS" and w.headA.shown == true and w.headB.shown == true)
    check("each column as wide as seven characters of the text size", w.rows[1].colA.w == 47 and w.rows[1].colB.w == 47)
    check("the name stops short of both columns", w.rows[1].name.points[2][2] == -(6 + 2 * 47 + 6 + 6))
    s.store.Set("showRate", false); s.Flush()
    check("one column takes less room", w.rows[1].name.points[2][2] == -(6 + 47 + 6))
    s.store.Set("showTotal", false); s.Flush()
    check("none: both hidden and the name takes the row", w.rows[1].colA.shown == false and w.rows[1].colB.shown == false
        and w.rows[1].name.points[2][2] == -12 and w.headB.shown == false)
    s.store.Set("showTotal", true); s.store.Set("showRate", true); s.Flush()
    s.store.Set("mode", "healing"); s.Flush()
    check("a list names its own columns", w.headA.text == "Healing" and w.headB.text == "HPS")
    s.store.Set("mode", "dps"); s.Flush()
    check("DPS leads with the per-second figure", w.headA.text == "DPS" and w.headB.text == "Damage"
        and w.rows[1].colA.text == "<a>" and w.rows[1].colB.text == "<A>")
    s.store.Set("mode", "interrupts"); s.Flush()
    check("a list with one column has one title", w.headB.text == "Interrupts" and w.headA.shown == false)
    s.store.Set("mode", "damage"); s.store.Set("showColumnHeaders", false); s.Flush()
    check("Column Titles off: none, and the rows move up", w.headName.shown == false and w.headB.shown == false)
    local up = w.rows[1].points[1][5]
    s.store.Set("showColumnHeaders", true); s.Flush()
    check("on they are back, and the rows sit below them", w.headB.shown == true
        and w.rows[1].points[1][5] == up - 16)
    s.store.Set("showRanks", false); s.Flush()
    check("the Name title follows the rank column", w.headName.points[1][4] == 12)
    s.store.Set("showRanks", true); s.Flush()
    check("and goes back past it", w.headName.points[1][4] == 12 + 18)
    s.store.Set("fontSize", 16); s.Flush()
    check("the columns grow with the text", w.rows[1].colA.w == math.floor(7 * 0.62 * 16))
    s.store.Set("fontSize", 11)
    s.store.Set("numberUnits", "full"); s.Flush()
    check("Full Numbers need more room", w.rows[1].colA.w == math.floor(10 * 0.62 * 11))
end

-- number formats
do
    local s = Boot({ settings = { enabled = true } })
    local DM = s.DM
    check("Game Default: the game's own abbreviation", DM.Format(1234) == "<1234>" and s.configs == nil)
    s.store.Set("numberUnits", "latin")
    check("K, M, B: the client's AbbreviateNumbers with a config", DM.Format(1234) == "{1234:4}")
    local rows = s.abbreviated.rows
    check("with B, M, K and a plain tier, largest first", rows[1].abbreviation == "B" and rows[1].breakpoint == 1e9
        and rows[2].abbreviation == "M" and rows[3].abbreviation == "K" and rows[4].breakpoint == 1
        and rows[4].abbreviation == "")
    check("one decimal: the M tier is in tenths", rows[2].fractionDivisor == 10 and rows[2].significandDivisor == 1e5
        and rows[3].significandDivisor == 100)
    DM.Format(1)
    check("the config is built once", s.configs == 1)
    s.store.Set("numberDecimals", 0)
    DM.Format(1)
    rows = s.abbreviated.rows
    check("no decimals: whole units", s.configs == 2 and rows[2].fractionDivisor == 1 and rows[2].significandDivisor == 1e6)
    s.store.Set("numberDecimals", 2)
    DM.Format(1)
    rows = s.abbreviated.rows
    check("two: hundredths", rows[2].fractionDivisor == 100 and rows[2].significandDivisor == 1e4)
    s.store.Set("numberUnits", "asian")
    DM.Format(1)
    rows = s.abbreviated.rows
    check("ten-thousands: hundred-millions, ten-thousands and thousands", rows[1].breakpoint == 1e8
        and rows[2].breakpoint == 1e4 and rows[3].breakpoint == 1e3 and #rows == 4)
    check("the simplified Chinese glyphs by default", rows[2].abbreviation == "\228\184\135")
    s.locale = "koKR"
    DM.Format(1)
    check("the Korean ones on a Korean client", s.abbreviated.rows[2].abbreviation == "\235\167\140")
    s.locale = "zhTW"
    DM.Format(1)
    check("the traditional ones on a Taiwanese client", s.abbreviated.rows[2].abbreviation == "\232\144\172")
    s.store.Set("numberUnits", "full")
    DM.Format(1)
    check("Full Numbers: one plain tier", #s.abbreviated.rows == 1 and s.abbreviated.rows[1].breakpoint == 1)
    s.env.AbbreviateNumbers = nil
    check("a client without it falls back to the game's", DM.Format(5) == "<5>")
    local secret = Amount("s")
    s.env.AbbreviateNumbers = function(n) return n end
    s.store.Set("numberUnits", "latin")
    check("a secret number goes straight through", DM.Format(secret) == secret)
end

-- the colors: each part from its own setting, the theme's until one is picked
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    local row, own = w.rows[1], w.rows[2]
    local PICK = { r = 0.9, g = 0.1, b = 0.4 }
    local function Is(c, t) return c ~= nil and c.r == t.r and c.g == t.g and c.b == t.b end
    local function Solid(r) return { r = r.solid[1], g = r.solid[2], b = r.solid[3] } end
    local function Pick(key) s.store.Set(key, PICK); s.Flush() end
    local function Unpick(key) s.store.Set(key, false); s.Flush() end

    check("names, amounts and the title follow the theme", Is(row.name.textColor, THEME.fg)
        and Is(row.colA.textColor, THEME.fg) and Is(row.colB.textColor, THEME.fg) and Is(w.title.textColor, THEME.fg))
    check("ranks, the time and the empty line its muted color", Is(row.rank.textColor, THEME.muted)
        and Is(w.time.textColor, THEME.muted) and Is(w.empty.textColor, THEME.muted))
    check("the window, the title bar and the border their own tokens", Is(Solid(w.background), THEME.bg)
        and Is(Solid(w.headerBackground), THEME.panel) and Is(w.border.color, THEME.line))
    check("your row's edge is the Accent", Is(Solid(own.edge), THEME.accent))
    check("a row has no background of its own: the window's shows behind the bars", row.bg == nil and own.bg == nil
        and w.rows[3].bg == nil)
    check("the window and its border take the background opacity", w.background.alpha == 0.9
        and w.border._frame.alpha == 0.9)

    local parts = {
        nameColor = function() return row.name.textColor end,
        valueColor = function() return row.colB.textColor end,
        columnColor = function() return w.headB.textColor end,
        rankColor = function() return row.rank.textColor end,
        titleColor = function() return w.title.textColor end,
        timeColor = function() return w.time.textColor end,
        summaryColor = function() return w.summary.textColor end,
        edgeColor = function() return Solid(own.edge) end,
        windowColor = function() return Solid(w.background) end,
        headerColor = function() return Solid(w.headerBackground) end,
        borderColor = function() return w.border.color end,
    }
    local count = 0
    for key, read in pairs(parts) do
        count = count + 1
        Pick(key)
        check(key .. ": its part takes it", Is(read(), PICK))
        for other, readOther in pairs(parts) do
            if other ~= key then check(key .. " leaves " .. other .. " alone", not Is(readOther(), PICK)) end
        end
        Unpick(key)
        check(key .. ": back to the theme", not Is(read(), PICK))
    end
    check("every color of the window is covered", count == 11)
    Pick("valueColor")
    check("a picked amount color reaches both columns", Is(row.colA.textColor, PICK) and Is(row.colB.textColor, PICK))
    Unpick("valueColor")
    Pick("nameColor")
    check("a picked name color reaches every row", Is(w.rows[3].name.textColor, PICK))
    Unpick("nameColor")
    Pick("rankColor")
    check("the rank color is the empty line's too", Is(w.empty.textColor, PICK))
    Unpick("rankColor")

    s.store.Set("barColor", "custom"); s.Flush()
    check("Custom Color before one is picked: the theme's Accent", row.color[1] == THEME.accent.r
        and row.color[3] == THEME.accent.b)
    Pick("barCustomColor")
    check("Custom Color: every bar the one picked", row.color[1] == PICK.r and own.color[2] == PICK.g
        and w.rows[3].color[3] == PICK.b)
    s.store.Set("barColor", "class"); s.Flush()
    check("Class Colors ignore it", row.color[1] == CLASS.MAGE.r and own.color[1] == CLASS.ROGUE.r)
    Unpick("barCustomColor")

    s.store.Set("highlightPlayer", false)
    Pick("edgeColor")
    check("no highlight: your edge is your class color, whatever is picked", Is(Solid(own.edge), CLASS.ROGUE))
    s.store.Set("highlightPlayer", true); Unpick("edgeColor")
    check("the column title color is its own", Is(w.headA.textColor, THEME.muted))

    s.store.Set("showBorder", false); s.Flush()
    check("Border off hides it", w.border._frame.shown == false)
    s.store.Set("showBorder", true); s.Flush()
    check("and on shows it", w.border._frame.shown == true)

    s.session.combatSources[1].specIconID = 62
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("a spec icon when the game gives one", row.icon.texture == 62)
    s.store.Set("iconStyle", "class"); s.Flush()
    check("Class Icon: the class's, always", row.icon.texture == "Interface\\Icons\\ClassIcon_MAGE")
    s.store.Set("iconStyle", "spec"); s.Flush()
    check("and back", row.icon.texture == 62)

    Pick("nameColor"); Pick("valueColor"); Pick("titleColor"); Pick("windowColor"); Pick("borderColor")
    Pick("rankColor")
    s.Hover(w, 2)
    local panel = s.Panel()
    check("the spell panel's names, amounts and title", Is(panel.rows[1].name.textColor, PICK)
        and Is(panel.rows[1].value.textColor, PICK) and Is(panel.title.textColor, PICK))
    check("its window and border", Is(Solid(panel.background), PICK) and Is(panel.border.color, PICK)
        and panel.rows[1].bg == nil)
    s.store.Set("showBorder", false)
    s.Hover(w, 2)
    check("and its border follows Border", panel.border._frame.shown == false)
    for _, key in ipairs({ "nameColor", "valueColor", "titleColor", "windowColor", "borderColor",
        "rankColor" }) do s.store.Set(key, false) end
    s.store.Set("showBorder", true)
    s.spellsResult = { combatSpells = {} }
    s.Hover(w, 2)
    check("without picks the panel follows the theme", Is(panel.title.textColor, THEME.fg)
        and Is(panel.note.textColor, THEME.muted) and Is(Solid(panel.background), THEME.bg))
end

-- fight history: a summary kept when a fight ends, once its numbers are plain
do
    local function Fight(total, secret)
        return { combatSources = {
            { name = "Aldrin", classFilename = "MAGE", totalAmount = 3000, amountPerSecond = 24 },
            { name = "You", classFilename = "ROGUE", isLocalPlayer = true, totalAmount = 5000, amountPerSecond = 40 },
        }, maxAmount = 5000, totalAmount = secret and SECRET_NUMBER or total or 9000 }
    end
    local function End(s)
        s.combat = true
        s.Fire("PLAYER_REGEN_DISABLED"); s.Flush()
        s.combat = false
        s.Fire("PLAYER_REGEN_ENABLED")
    end
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    s.duration = 125
    s.apiResult = Fight()
    s.now, s.clock = 1000, 1700000500
    s.zone = "Plains"
    s.combat = true
    s.Fire("PLAYER_REGEN_DISABLED"); s.Flush()
    s.Fire("ENCOUNTER_END", 77, "The Hollow King")
    s.combat = false
    s.Fire("PLAYER_REGEN_ENABLED")
    local scheduled = false
    for _, t in ipairs(s.timers) do
        if t.sec == 1.5 then scheduled = true end
    end
    check("a read is scheduled for just after combat ends", scheduled)
    s.Flush(); s.Flush()
    local list = s.store.Get("history")
    local e = list[1]
    check("the fight is kept: when, where, which, how long", #list == 1 and e.at == 1700000500 and e.place == "Plains"
        and e.boss == "The Hollow King" and e.seconds == 125)
    check("with your figures and the raid's, damage then healing", e.damage.own == 5000 and e.damage.perSecond == 40
        and e.damage.total == 9000 and e.damage.totalPerSecond == 72 and e.damage.rank == 2 and e.damage.count == 2
        and e.healing.own == 5000)

    -- not plain yet: read again until it is
    s.now = 2000
    End(s)
    s.apiResult = Fight(nil, true)
    s.Flush()
    check("a secret total is not kept, and is read again", #s.store.Get("history") == 1 and #s.timers >= 1)
    s.apiResult = Fight(4000)
    s.Flush(); s.Flush()
    local again = s.store.Get("history")
    check("kept once it is plain, newest first, no boss from the last fight", #again == 2 and again[1].damage.total == 4000
        and again[1].boss == nil and again[2].boss == "The Hollow King")

    -- a length or your own figures still secret
    local before = #s.store.Get("history")
    s.duration = SECRET_NUMBER
    s.apiResult = Fight(5000)
    End(s)
    s.Flush()
    check("a length the game keeps back is waited for", #s.store.Get("history") == before and #s.timers >= 1)
    s.duration = 125
    local mine = Fight(5000)
    mine.combatSources[2].totalAmount = SECRET_NUMBER
    s.apiResult = mine
    s.Flush()
    check("as are your own figures", #s.store.Get("history") == before and #s.timers >= 1)
    mine.combatSources[2].totalAmount = 5000
    s.Flush(); s.Flush()
    check("both kept once they are plain", #s.store.Get("history") == before + 1)

    -- combat begins while it waits for plain numbers
    s.apiResult = Fight(nil, true)
    End(s)
    s.apiResult = Fight(5100)
    s.Fire("PLAYER_REGEN_DISABLED")
    s.Flush(); s.Flush()
    check("a fight that begins drops the read of the last", #s.store.Get("history") == before + 1)
    s.combat = false
    s.Fire("PLAYER_REGEN_ENABLED")
    s.Flush(); s.Flush()
    check("and the one that ends is read as its own", #s.store.Get("history") == before + 2)

    -- an end of combat that was never a start
    s.Fire("PLAYER_REGEN_ENABLED")
    s.Flush(); s.Flush()
    check("an end with no start is not read", #s.store.Get("history") == before + 2)

    -- a name the game keeps back is not used
    s.now = 5000
    s.Fire("ENCOUNTER_END", 1, SECRET_TEXT)
    End(s)
    s.Flush(); s.Flush()
    check("an encounter name that is secret is not kept as the boss", s.store.Get("history")[1].boss == nil)

    -- a fight that is too short
    s.duration = 3
    End(s)
    s.Flush(); s.Flush()
    check("a fight under five seconds is not kept", #s.store.Get("history") == 5)
    s.duration = 125

    -- the game never gives plain numbers: give up
    s.apiResult = Fight(nil, true)
    End(s)
    for _ = 1, 12 do s.Flush() end
    check("it gives up after a few tries, and keeps nothing", #s.store.Get("history") == 5 and #s.timers == 0)

    -- the next fight starts while it waits
    End(s)
    s.combat = true
    s.Flush()
    s.apiResult = Fight(7000)
    s.Flush(); s.Flush()
    check("combat again: the earlier read is dropped", #s.store.Get("history") == 5)
    s.combat = false
    s.apiResult = Fight(7000)

    -- the list is capped
    s.store.Set("keepFights", 3)
    for i = 1, 4 do
        s.apiResult = Fight(8000 + i)
        End(s)
        s.Flush(); s.Flush()
    end
    local capped = s.store.Get("history")
    check("only as many as Fights Kept, the newest", #capped == 3 and capped[1].damage.total == 8004
        and capped[3].damage.total == 8002)

    -- the window
    local win
    for _, f in ipairs(s.frames) do
        if f.name == "NaowhForeverDamageMeterHistory" then win = f end
    end
    check("not built before it is opened", win == nil)
    s.DM.HistoryWindow.Toggle()
    for _, f in ipairs(s.frames) do
        if f.name == "NaowhForeverDamageMeterHistory" then win = f end
    end
    check("opened", win and win.shown == true and win.title.text == "Fight History")
    check("with a line per fight: when, which, how long, the figures", win.rows[1].cells[1].text
        == os.date("%m/%d %H:%M", capped[1].at) and win.rows[1].cells[2].text == "Plains"
        and win.rows[1].cells[3].text == "2:05" and win.rows[1].cells[4].text == "<40>"
        and win.rows[1].cells[5].text == "<" .. tostring(capped[1].damage.totalPerSecond) .. ">"
        and win.rows[3].cells[1].shown == true and win.rows[4].cells[1].shown == false)
    check("and the empty line is hidden", win.empty.shown == false)
    s.apiResult = Fight(9999)
    End(s)
    s.Flush(); s.Flush()
    check("a new fight refreshes it while it is open", win.rows[1].cells[5].text
        == "<" .. tostring(s.store.Get("history")[1].damage.totalPerSecond) .. ">")
    win.scripts.OnMouseWheel(win, -5)
    check("scrolling past the end stays on the list", win.rows[1].cells[1].shown == true)
    win.scripts.OnMouseWheel(win, 5)
    check("and so does scrolling above the start", win.rows[1].cells[1].shown == true)
    win.clear.onClick()
    check("Clear asks first", #s.confirms == 1 and #s.store.Get("history") == 3)
    s.confirms[1].yes()
    check("then empties it, and says so", #s.store.Get("history") == 0 and win.empty.shown == true
        and win.rows[1].cells[1].shown == false)

    win.close.onClick()
    check("Close hides it", win.shown == false)
    s.DM.HistoryWindow.Toggle()
    check("and it opens again", win.shown == true)

    -- from the menu
    s.Window().more.onClick()
    s.menu:Find("Fight History").onClick()
    check("the window menu toggles it", win.shown == false)
    s.menu:Find("Take Screenshot").onClick()
    check("a screenshot is taken a moment later, with the menu gone", s.shots == nil)
    s.Flush()
    check("then", s.shots == 1)
end

-- the boss name is only used while it is recent, and the place is the instance's inside one
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    s.duration = 90
    s.apiResult = { combatSources = {}, maxAmount = 0, totalAmount = 100 }
    s.combat = true
    s.Fire("PLAYER_REGEN_DISABLED"); s.Flush()
    s.now = 100
    s.Fire("ENCOUNTER_END", 1, "Old Boss")
    s.now = 400
    s.combat = false
    s.instance, s.instanceName = true, "The Deep Hall"
    s.Fire("PLAYER_REGEN_ENABLED")
    s.Flush(); s.Flush()
    local e = s.store.Get("history")[1]
    check("a boss from minutes ago is not this fight's; the instance's name is the place", e and e.boss == nil
        and e.place == "The Deep Hall" and e.damage.own == 0 and e.damage.rank == nil)
end

-- Raid Mode: your row alone
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local w = s.Window()
    s.store.Set("raidMode", true); s.Flush()
    check("your row alone, still ranked as you are", w.rows[1].name.text == "You" and w.rows[1].rank.text == "2"
        and w.rows[2].shown == false)
    check("the bar still against the group's largest", w.rows[1].barMax == s.session.maxAmount
        and w.rows[1].barValue == s.session.combatSources[2].totalAmount)
    s.store.Set("showSummary", true); s.Flush()
    check("the summary still reads the whole group", w.summary.text == "Current   Damage <total>   Rank 2/3")
    s.session.combatSources[2].isLocalPlayer = false
    s.Fire("DAMAGE_METER_RESET"); s.Flush()
    check("not in the session: nothing to show", w.rows[1].shown == false and w.empty.shown == true)
    s.session.combatSources[2].isLocalPlayer = true
    s.store.Set("raidMode", false); s.Flush()
    check("off again: the whole group", w.rows[3].shown == true and w.rows[1].rank.text == "1")
    w.more.onClick()
    local bars = s.menu:Find("Bar Color")
    check("the window menu changes the bar color: three choices, the current one marked", bars and #bars.items == 3
        and bars.items[1].text == "Class Colors" and bars.items[1].selected() == true
        and bars.items[2].selected() == false)
    bars.items[2].set()
    check("and sets it", s.store.Get("barColor") == "accent")
    bars.items[3].set()
    check("custom too", s.store.Get("barColor") == "custom" and bars.items[3].selected() == true)
    s.store.Set("barColor", "class")
    local item = s.menu:Find("Raid Mode")
    check("the window menu has it", item and item.kind == "check" and item.selected() == false)
    item.set()
    check("and sets it", s.store.Get("raidMode") == true)
end

-- In Combat: shown while you fight and a while after, and a key to show or hide it
do
    local s = Boot({ settings = { enabled = true, visibility = "combat", hideDelay = 8 } })
    s.Login()
    local w = s.Window()
    check("hidden until combat", w.shown == false)
    s.combat = true
    s.Fire("PLAYER_REGEN_DISABLED"); s.Flush()
    check("shown in combat", w.shown == true)
    s.combat = false
    s.now = 100
    s.Fire("PLAYER_REGEN_ENABLED")
    local scheduled = false
    for _, t in ipairs(s.timers) do
        if t.sec == 8.25 then scheduled = true end
    end
    check("a check is scheduled for when the delay is out", scheduled)
    s.Flush()
    check("shown for a while after", w.shown == true)
    s.now = 107
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("still shown before the delay is out", w.shown == true)
    s.now = 109
    s.Fire("DAMAGE_METER_CURRENT_SESSION_UPDATED"); s.Flush()
    check("hidden when it is", w.shown == false)

    s.env.NaowhForever_ToggleDamageMeter()
    check("the key shows it", w.shown == true)
    s.env.NaowhForever_ToggleDamageMeter()
    check("and hides it", w.shown == false)
    s.env.NaowhForever_ToggleDamageMeter()
    s.combat = true
    s.Fire("PLAYER_REGEN_DISABLED"); s.Flush()
    s.env.NaowhForever_ToggleDamageMeter()
    check("in combat the key hides it", w.shown == false)
    s.combat = false
    s.Fire("PLAYER_REGEN_DISABLED"); s.combat = true; s.Flush()
    check("and the next fight clears that", w.shown == true)

    local always = Boot({ settings = { enabled = true } })
    always.Login()
    always.env.NaowhForever_ToggleDamageMeter()
    check("with Where on Always the key hides it", always.Window().shown == false)
    always.env.NaowhForever_ToggleDamageMeter()
    check("and shows it again", always.Window().shown == true)

    local off = Boot()
    off.Login()
    off.env.NaowhForever_ToggleDamageMeter()
    check("off: the key says so", #off.printed == 1)
end

-- bar colors by class, alternating rows, a background image
do
    local s = Boot({ settings = { enabled = true }, media = true, classes = { "ROGUE", "MAGE" } })
    s.Login()
    local w = s.Window()
    local row, own, third = w.rows[1], w.rows[2], w.rows[3]
    local function Is(c, t) return c.r == t.r and c.g == t.g and c.b == t.b end
    local function Bar(r) return { r = r.color[1], g = r.color[2], b = r.color[3] } end

    s.store.Set("classColors", { MAGE = { r = 0.1, g = 0.9, b = 0.5 } }); s.Flush()
    check("a class picked in the settings colors its bars", Is(Bar(row), { r = 0.1, g = 0.9, b = 0.5 })
        and Is(Bar(third), { r = 0.1, g = 0.9, b = 0.5 }))
    check("and the others keep the game's", Is(Bar(own), CLASS.ROGUE))
    s.store.Set("barColor", "accent"); s.Flush()
    check("Theme Accent ignores the picks", Is(Bar(row), THEME.accent))
    s.store.Set("barColor", "class"); s.store.Set("classColors", {}); s.Flush()
    check("none picked: the game's colors", Is(Bar(row), CLASS.MAGE))

    local MINE = { r = 0.9, g = 0.2, b = 0.7 }
    s.store.Set("ownBarColor", MINE); s.Flush()
    check("Your Bar Color: your bar alone", Is(Bar(own), MINE) and Is(Bar(row), CLASS.MAGE) and Is(Bar(third), CLASS.MAGE))
    s.store.Set("barColor", "accent"); s.Flush()
    check("whichever Bar Color is chosen", Is(Bar(own), MINE) and Is(Bar(row), THEME.accent))
    s.store.Set("barColor", "custom"); s.Flush()
    check("custom too", Is(Bar(own), MINE))
    s.store.Set("barColor", "class"); s.store.Set("ownBarColor", false); s.Flush()
    check("not picked: your bar follows Bar Color", Is(Bar(own), CLASS.ROGUE))

    check("no image by default", w.image.shown == false)
    s.store.Set("backgroundImage", "Marble"); s.Flush()
    check("a background from the shared media, stretched", w.image.shown == true and w.image.texture == "Media\\Marble"
        and w.image.alpha == 1 and w.image.wrap[1] == nil)
    s.store.Set("imageAlpha", 0.4); s.Flush()
    check("at its own opacity", w.image.alpha == 0.4)
    s.store.Set("backgroundImage", "Gone"); s.Flush()
    check("a name the media no longer has: no image", w.image.shown == false)
    s.store.Set("backgroundImage", "Dots"); s.store.Set("imageTile", true); s.Flush()
    check("another, tiled", w.image.shown == true and w.image.texture == "Media\\Dots"
        and w.image.wrap[1] == "REPEAT" and w.image.wrap[2] == "REPEAT")
    s.store.Set("backgroundImage", ""); s.Flush()
    check("none again", w.image.shown == false)

    local page = s.page
    local rows = page.cards[2].rows
    local classRows = {}
    for _, r in ipairs(rows) do
        if r.key == "classColors" then classRows[#classRows + 1] = r end
    end
    check("a color row per class, in the game's order", #classRows == 2 and classRows[1].field == "ROGUE"
        and classRows[2].field == "MAGE" and classRows[2].label == "Mage")
    local r, g, b = classRows[2].get()
    check("it shows the game's color until one is picked", r == CLASS.MAGE.r and g == CLASS.MAGE.g and b == CLASS.MAGE.b)
    classRows[2].set(0.2, 0.3, 0.4)
    local picked = s.store.Get("classColors")
    check("picking adds that class alone", picked.MAGE.r == 0.2 and picked.MAGE.g == 0.3 and picked.ROGUE == nil)
    classRows[1].set(0.9, 0.8, 0.7)
    picked = s.store.Get("classColors")
    check("and the next keeps the first", picked.MAGE.r == 0.2 and picked.ROGUE.r == 0.9)
    r = classRows[2].get()
    check("the picker shows it", r == 0.2)
    check("they need Class Colors", classRows[1].needs() == true)
    s.store.Set("barColor", "accent")
    check("and are off without it", classRows[1].needs() == false)
    s.store.Set("barColor", "class")

    local mine
    for _, r2 in ipairs(rows) do
        if r2.key == "ownBarColor" then mine = r2 end
    end
    check("a Your Bar Color row, a color picker", mine and mine.colour == true and mine.label == "Your Bar Color")
    s.store.Set("classColors", {})
    local mr, mg, mb = mine.get()
    check("it shows what your bar is now, your class's color", mr == CLASS.ROGUE.r and mg == CLASS.ROGUE.g
        and mb == CLASS.ROGUE.b)
    s.store.Set("barColor", "accent")
    mr = mine.get()
    check("and follows Bar Color", mr == THEME.accent.r)
    s.store.Set("barColor", "class")
    mine.set(0.1, 0.2, 0.3)
    local stored = s.store.Get("ownBarColor")
    check("picking stores it", type(stored) == "table" and stored.r == 0.1 and stored.g == 0.2 and stored.b == 0.3)
    mr, mg = mine.get()
    check("and it shows it", mr == 0.1 and mg == 0.2)
    s.store.Set("ownBarColor", false)

    local choices
    for _, r2 in ipairs(page.cards[1].rows) do
        if r2.key == "backgroundImage" then choices = r2.choice end
    end
    local values, order = choices()
    check("the image choices: None, then the media's", values[""] == "None" and order[1] == "" and order[2] == "Marble"
        and order[3] == "Dots")
    s.store.Set("backgroundImage", "Lost")
    values, order = choices()
    check("a name that is not there stays chosen, marked", values.Lost == "Lost (unavailable)" and order[4] == "Lost")
    s.store.Set("backgroundImage", "")
end

-- moving and resizing work in combat too, and a resize keeps the size the client gives
do
    local s = Boot({ settings = { enabled = true } })
    s.Login()
    local one = s.Window()
    local grip
    for _, f in ipairs(s.frames) do
        if f.parent == one and f.kind == "Button" and f.scripts.OnMouseDown then grip = f end
    end
    s.combat = true
    grip.scripts.OnMouseDown(grip, "LeftButton")
    check("in combat: the corner starts sizing", one.sizingFrom == "BOTTOMRIGHT")
    one.w, one.h = 420, 260
    one.scripts.OnSizeChanged(one, 420, 260)
    check("the window keeps the size the client gives, not the saved one", one.w == 420 and one.h == 260)
    grip.scripts.OnMouseUp(grip)
    check("on release the size is saved", s.store.Get("width") == 420 and s.store.Get("height") == 260
        and one.sizingFrom == nil)
    s.Flush()
    check("and the window stays that size", one.w == 420 and one.h == 260)

    one.header.scripts.OnDragStart(one.header)
    check("in combat: the title bar starts moving", one.dragging == true)
    one.header.scripts.OnDragStop(one.header)
    check("and the place is saved", s.store.Get("meterPos").point == "TOPLEFT" and one.dragging == false)

    s.store.Set("locked", true)
    one.header.scripts.OnDragStart(one.header)
    check("Lock Window: it does not move", not one.dragging)
    grip.scripts.OnMouseDown(grip, "LeftButton")
    check("nor resize", one.sizingFrom == nil)
    s.store.Set("locked", false)

    s.combat = false
    one.header.scripts.OnDragStart(one.header)
    s.combat = true
    s.Fire("PLAYER_REGEN_DISABLED")
    check("combat starting does not cancel a drag", one.dragging == true)
    one.header.scripts.OnDragStop(one.header)
    one.scripts.OnHide(one)
    check("hiding the window ends a drag", one.dragging == false)
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
    check("with the ten lists, the current one chosen", #list.items == 11 and list:Find("Damage Done").selected() == true
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
    check("its own size", two.w == 240 and two.h == 120 and one.w == 300 and one.h == 206)
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
    check("the grip sizes the window", two.sizingFrom == "BOTTOMRIGHT")
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
    local C = s.DM.C
    check("one page, three cards: the meter, its colors and its more windows", page and #page.cards == 3
        and page.cards[1].id == "meter" and page.cards[2].id == "colors" and page.cards[3].id == "windows"
        and page.window ~= nil)
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
                    local values, order
                    if type(row.choice) == "function" then
                        values, order = row.choice()
                    else
                        values, order = row.choice[1], row.choice[2]
                    end
                    for _, value in ipairs(order) do
                        check(row.key .. " choice " .. value .. " has a label", values[value] ~= nil)
                    end
                end
            end
        end
    end
    check("the rows cover the windows, the rows, the hover and the colors", #keys >= 55)
    check("one short help sentence on each card", #page.cards[1].help < 120 and #page.cards[2].help < 120
        and #page.cards[3].help < 120)
    local delay
    for _, r in ipairs(page.cards[1].rows) do
        if r.key == "hideDelay" then delay = r end
    end
    check("Hide After needs Where on In Combat", delay and delay.needs() == false)
    s.store.Set("visibility", "combat")
    check("which turns it on", delay.needs() == true)
    s.store.Set("visibility", "always")
    check("the first card's summary reads window one", page.cards[1].summary(s.store) == "Damage Done, 300 by 206")

    local colors = {}
    for _, row in ipairs(page.cards[2].rows) do
        if row.colour then colors[row.key] = row end
    end
    for _, entry in ipairs(C.COLORS) do
        local row = colors[entry.key]
        check(entry.key .. ": a color row, labeled", row and row.label == entry.label)
        local token = THEME[entry.token]
        local r, g, b = row.get()
        check(entry.key .. ": shows the theme's " .. entry.token .. " until one is picked",
            r == token.r and g == token.g and b == token.b)
        row.set(0.1, 0.2, 0.3)
        local c = s.store.Get(entry.key)
        check(entry.key .. ": picking stores it", type(c) == "table" and c.r == 0.1 and c.g == 0.2 and c.b == 0.3)
        r, g, b = row.get()
        check(entry.key .. ": and shows it", r == 0.1 and g == 0.2 and b == 0.3)
        s.store.Set(entry.key, false)
    end
    check("the colors card counts what was picked", page.cards[2].summary(s.store) == "Theme")
    s.store.Set("nameColor", { r = 1, g = 1, b = 1 })
    s.store.Set("rankColor", { r = 1, g = 1, b = 1 })
    check("and says how many", page.cards[2].summary(s.store) == "2 picked")
    s.store.Set("nameColor", false); s.store.Set("rankColor", false)

    check("the custom bar color needs Custom Color", colors.barCustomColor.needs() == false)
    s.store.Set("barColor", "custom")
    check("which turns it on", colors.barCustomColor.needs() == true)
    check("the row edge needs Highlight Your Row", colors.edgeColor.needs() == true)
    s.store.Set("highlightPlayer", false)
    check("and is off without it", colors.edgeColor.needs() == false)
    s.store.Set("highlightPlayer", true)

    check("the closed windows say off", page.cards[3].summary(s.store) == "Second: Off, Third: Off")
    s.store.Set("window2", true)
    s.store.Set("mode2", "healing")
    check("an open one reads its own list", page.cards[3].summary(s.store) == "Second: Healing Done, Third: Off")
    local more = page.cards[3].rows
    check("each window has a group and five rows, with its own keys", #more == 12 and more[2].key == "window2"
        and more[3].key == "mode2" and more[6].key == "height2" and more[8].key == "window3" and more[12].key == "height3")
    check("the labels differ across the card", more[3].label ~= more[9].label and more[2].label ~= more[8].label)
    check("an open window's rows are enabled", more[2].needs() == true and more[3].needs() == true)
    s.store.Set("window2", false)
    check("closed: its own rows are disabled, its toggle is not", more[3].needs() == false and more[2].needs() == true)
end

print("PASS damage meter: " .. checks .. " checks")

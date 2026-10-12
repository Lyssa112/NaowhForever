-- Source.lua: reads the game's damage meter data. Amounts and names are secret in combat, so nothing here
-- compares or adds them without asking Plain first; they go straight to the bars and texts.
local ns = _G.NaowhForever

local DM = ns.DamageMeter
local C = DM.C

local EMPTY = { combatSources = {}, maxAmount = 0, totalAmount = 0 }

function DM.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

-- Whether value is of the kind and readable.
function DM.Plain(value, kind)
    return type(value) == kind and not DM.IsSecret(value)
end

local IsSecret, Plain = DM.IsSecret, DM.Plain

function DM.Mode(key)
    return C.MODE_BY_KEY[key] or C.MODE_BY_KEY[C.DEFAULT_MODE]
end

-- What a window calls a list: its name, or the short one when the settings say so.
function DM.ModeLabel(mode)
    if mode.short and DM.Settings.Get("shortNames") == true then return mode.short end
    return mode.label
end

function DM.Available()
    return C_DamageMeter ~= nil and Enum.DamageMeterType ~= nil and Enum.DamageMeterSessionType ~= nil
end

local function SessionType(key)
    return key == "overall" and Enum.DamageMeterSessionType.Overall or Enum.DamageMeterSessionType.Current
end

local function ListType(modeKey)
    return Enum.DamageMeterType[DM.Mode(modeKey).type]
end

-- The game's session for a list type: a past fight by its id, else the current or the overall one. Nil
-- when the game gives nothing usable.
local function FetchSession(kind, sessionKey, fightID)
    local ok, session
    if fightID ~= nil then
        ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, fightID, kind)
    else
        ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, SessionType(sessionKey), kind)
    end
    if ok and type(session) == "table" and type(session.combatSources) == "table" then return session end
end

-- One source's data with its spells, by guid (and an enemy's creature id). Nil when it cannot be read.
local function FetchSource(kind, sessionKey, fightID, guid, creatureID)
    local ok, data
    if fightID ~= nil then
        ok, data = pcall(C_DamageMeter.GetCombatSessionSourceFromID, fightID, kind, guid, creatureID)
    else
        ok, data = pcall(C_DamageMeter.GetCombatSessionSourceFromType, SessionType(sessionKey), kind, guid, creatureID)
    end
    if ok and type(data) == "table" and type(data.combatSpells) == "table" then return data end
end

function DM.Session(modeKey, sessionKey, fightID)
    if not DM.Available() then return EMPTY end
    return FetchSession(ListType(modeKey), sessionKey, fightID) or EMPTY
end

local function Newest(a, b)
    return a.id > b.id
end

-- The fights the game still holds, newest first, as { id, name, seconds }.
function DM.Fights()
    local fights = {}
    if not (DM.Available() and C_DamageMeter.GetAvailableCombatSessions) then return fights end
    local ok, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
    if not (ok and type(sessions) == "table") then return fights end
    for _, entry in ipairs(sessions) do
        if type(entry) == "table" and Plain(entry.sessionID, "number") then
            local name, seconds = entry.name, entry.durationSeconds
            fights[#fights + 1] = { id = entry.sessionID,
                name = Plain(name, "string") and name ~= "" and name or nil,
                seconds = Plain(seconds, "number") and seconds or nil }
        end
    end
    table.sort(fights, Newest)
    for i = #fights, C.FIGHTS_MAX + 1, -1 do fights[i] = nil end
    return fights
end

-- A fight as the menus and reports name it: "Name (m:ss)", or "Fight 12" when the game gives no name.
function DM.FightLabel(fight)
    local label = fight.name or ("Fight " .. fight.id)
    if fight.seconds then
        label = ("%s (%d:%02d)"):format(label, math.floor(fight.seconds / 60), math.floor(fight.seconds % 60))
    end
    return label
end

-- What a session is called: Current, Overall, or the past fight's own name.
function DM.SessionName(sessionKey, fightID)
    if fightID == nil then return C.SESSION_LABELS[sessionKey] or C.SESSION_LABELS.current end
    for _, fight in ipairs(DM.Fights()) do
        if fight.id == fightID then return DM.FightLabel(fight) end
    end
    return "Fight " .. fightID
end

-- Seconds the shown session has run, as a plain number, or nil when the game keeps it back.
function DM.Duration(sessionKey, fightID)
    if not DM.Available() then return nil end
    if fightID ~= nil then
        for _, fight in ipairs(DM.Fights()) do
            if fight.id == fightID then return fight.seconds end
        end
        return nil
    end
    local ok, seconds = pcall(C_DamageMeter.GetSessionDurationSeconds, SessionType(sessionKey))
    if ok and Plain(seconds, "number") then return seconds end
    return nil
end

-- The name a title can use for a session: Overall, a past fight's own name, or the newest fight's for
-- Current. Nil when there is none: in combat the newest fight listed is not the one running.
function DM.FightName(sessionKey, fightID)
    if fightID == nil and sessionKey == "overall" then return C.SESSION_LABELS.overall end
    if fightID == nil and InCombatLockdown() then return nil end
    for _, fight in ipairs(DM.Fights()) do
        if fightID == nil or fight.id == fightID then return fight.name end
    end
    return nil
end

-- Where the local player stands in a session's sources, and how many there are: the game sorts them.
function DM.Rank(session)
    local sources = session.combatSources
    for i = 1, #sources do
        if sources[i].isLocalPlayer == true then return i, #sources end
    end
    return nil, #sources
end

-- The spells behind one row, as the game's { combatSpells, maxAmount, totalAmount }, or nil. In combat the
-- game takes a plain guid only: your own row's, or a row whose guid is readable.
function DM.SourceSpells(modeKey, sessionKey, fightID, source)
    if not DM.Available() or DM.Mode(modeKey).spells == false then return nil end
    local guid
    if source.isLocalPlayer == true then guid = UnitGUID("player") else guid = source.sourceGUID end
    if IsSecret(guid) or guid == nil then return nil end
    local data = FetchSource(ListType(modeKey), sessionKey, fightID, guid)
    if data and #data.combatSpells > 0 then return data end
    return nil
end

local targetsCache = {}

-- Forgets the targets read, when the game's data has changed.
function DM.ClearTargets()
    for key in pairs(targetsCache) do targetsCache[key] = nil end
end

-- What one enemy took from the player of that name: the enemy's list is by attacker and spell, so the
-- player's spells are added up. Plain numbers only, so after combat.
local function Share(kind, sessionKey, fightID, enemy, name)
    local guid = enemy.sourceGUID
    if IsSecret(guid) then return 0 end
    local data = FetchSource(kind, sessionKey, fightID, guid, enemy.sourceCreatureID)
    if not data then return 0 end
    local total = 0
    for _, spell in ipairs(data.combatSpells) do
        local details = spell.combatSpellDetails
        local who = type(details) == "table" and details.unitName
        if Plain(who, "string") and who == name and Plain(spell.totalAmount, "number") then
            total = total + spell.totalAmount
        end
    end
    return total
end

local function Biggest(a, b)
    return a.total > b.total
end

-- The enemies a player hurt and how much each took, biggest first: { { name, total }, ... }, or nil.
function DM.Targets(sessionKey, fightID, name)
    if not DM.Available() or not Plain(name, "string") or name == "" then return nil end
    local kind = Enum.DamageMeterType.EnemyDamageTaken
    if kind == nil then return nil end
    local key = tostring(fightID or sessionKey) .. "|" .. name
    local cached = targetsCache[key]
    if cached ~= nil then return cached or nil end
    local list = {}
    local session = FetchSession(kind, sessionKey, fightID)
    for _, enemy in ipairs(session and session.combatSources or {}) do
        local total = Share(kind, sessionKey, fightID, enemy, name)
        if total > 0 then list[#list + 1] = { name = enemy.name, total = total } end
    end
    table.sort(list, Biggest)
    if #list == 0 then list = nil end
    targetsCache[key] = list or false
    return list
end

function DM.Reset()
    if DM.Available() then C_DamageMeter.ResetAllCombatSessions() end
end

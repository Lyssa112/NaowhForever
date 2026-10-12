-- Source.lua: reads the game's damage meter data. Amounts and names are secret in combat, so nothing here
-- compares or adds them without asking IsSecret first; they go straight to the bars and texts.
local ns = _G.NaowhForever

local DM = ns.DamageMeter
local C = DM.C

local EMPTY = { combatSources = {}, maxAmount = 0, totalAmount = 0 }

function DM.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end
local IsSecret = DM.IsSecret

-- The client's own abbreviation takes a secret number and returns a string made from it, and so does
-- AbbreviateNumbers with a config of breakpoints, which is how the other formats are made.
local function Game(n)
    if AbbreviateLargeNumbers then return AbbreviateLargeNumbers(n) end
    return tostring(n)
end

local PLAIN_TIER = { breakpoint = 1, abbreviation = "", significandDivisor = 1, fractionDivisor = 1,
    abbreviationIsGlobal = false }

local function Tier(base, glyph, decimals)
    local d = 10 ^ decimals
    return { breakpoint = base, abbreviation = glyph, significandDivisor = base / d, fractionDivisor = d,
        abbreviationIsGlobal = false }
end

local function Tiers(units, decimals)
    if units == "latin" then
        return { Tier(1e9, "B", decimals), Tier(1e6, "M", decimals), Tier(1e3, "K", decimals), PLAIN_TIER }
    elseif units == "asian" then
        local g = C.ASIAN_GLYPHS[GetLocale and GetLocale()] or C.ASIAN_GLYPHS.zhCN
        return { Tier(1e8, g[3], decimals), Tier(1e4, g[2], decimals), Tier(1e3, g[1], decimals), PLAIN_TIER }
    end
    return { PLAIN_TIER }
end

local formatKey, formatOptions

-- A number as the settings write it. n may be secret, and the answer is a string made from it.
function DM.Format(n)
    local units = DM.Settings.Get("numberUnits")
    if units == "game" or not (AbbreviateNumbers and CreateAbbreviateConfig) then return Game(n) end
    local decimals = DM.Settings.Get("numberDecimals")
    local key = units .. decimals .. (GetLocale and GetLocale() or "")
    if key ~= formatKey then
        formatOptions = { config = CreateAbbreviateConfig(Tiers(units, decimals)) }
        formatKey = key
    end
    return AbbreviateNumbers(n, formatOptions)
end

function DM.Mode(key)
    return C.MODE_BY_KEY[key] or C.MODE_BY_KEY[C.DEFAULT_MODE]
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

-- fightID names one of the game's past fights; without it the session is the current or the overall one.
function DM.Session(modeKey, sessionKey, fightID)
    if not DM.Available() then return EMPTY end
    local ok, session
    if fightID ~= nil then
        ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, fightID, ListType(modeKey))
    else
        ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, SessionType(sessionKey), ListType(modeKey))
    end
    if ok and type(session) == "table" and type(session.combatSources) == "table" then return session end
    return EMPTY
end

local function Plain(value, kind)
    return type(value) == kind and not IsSecret(value)
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

-- m:ss, or h:mm:ss from an hour.
function DM.Clock(seconds)
    seconds = math.floor(seconds)
    if seconds >= 3600 then
        return ("%d:%02d:%02d"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60)
    end
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- The spells behind one row, as the game's { combatSpells, maxAmount, totalAmount }, or nil. In combat the
-- game takes a plain guid only: your own row's, or a row whose guid is readable.
function DM.SourceSpells(modeKey, sessionKey, fightID, source)
    if not DM.Available() or DM.Mode(modeKey).spells == false then return nil end
    local guid
    if source.isLocalPlayer == true then guid = UnitGUID("player") else guid = source.sourceGUID end
    if IsSecret(guid) or guid == nil then return nil end
    local ok, data
    if fightID ~= nil then
        ok, data = pcall(C_DamageMeter.GetCombatSessionSourceFromID, fightID, ListType(modeKey), guid)
    else
        ok, data = pcall(C_DamageMeter.GetCombatSessionSourceFromType, SessionType(sessionKey), ListType(modeKey), guid)
    end
    if ok and type(data) == "table" and type(data.combatSpells) == "table" and #data.combatSpells > 0 then
        return data
    end
    return nil
end

-- A total over a length of time, or nil when either is secret or there is no time.
function DM.PerSecond(total, seconds)
    if not (Plain(total, "number") and Plain(seconds, "number")) or seconds <= 0 then return nil end
    return total / seconds
end

-- Where the local player stands in a session's sources, and how many there are: the game sorts them.
function DM.Rank(session)
    local sources = session.combatSources
    for i = 1, #sources do
        if sources[i].isLocalPlayer == true then return i, #sources end
    end
    return nil, #sources
end

-- A share of a total, as a percentage, or nil when either is secret or there is no total.
function DM.Percent(amount, total)
    if not (Plain(amount, "number") and Plain(total, "number")) or total <= 0 then return nil end
    return amount / total * 100
end

function DM.Reset()
    if DM.Available() then C_DamageMeter.ResetAllCombatSessions() end
end

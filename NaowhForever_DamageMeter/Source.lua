-- Source.lua: reads the game's damage meter session. Amounts and names are secret in combat, so nothing here
-- compares or adds them; they go straight to the bars and texts.
local ns = _G.NaowhForever

local DM = ns.DamageMeter
local C = DM.C

local EMPTY = { combatSources = {}, maxAmount = 0, totalAmount = 0 }

function DM.Mode(key)
    return C.MODE_BY_KEY[key] or C.MODE_BY_KEY[C.DEFAULT_MODE]
end

function DM.Available()
    return C_DamageMeter ~= nil and Enum.DamageMeterType ~= nil and Enum.DamageMeterSessionType ~= nil
end

local function SessionType(key)
    return key == "overall" and Enum.DamageMeterSessionType.Overall or Enum.DamageMeterSessionType.Current
end

function DM.Session(modeKey, sessionKey)
    if not DM.Available() then return EMPTY end
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, SessionType(sessionKey),
        Enum.DamageMeterType[DM.Mode(modeKey).type])
    if ok and type(session) == "table" and type(session.combatSources) == "table" then return session end
    return EMPTY
end

function DM.Reset()
    if DM.Available() then C_DamageMeter.ResetAllCombatSessions() end
end

-- History.lua: a summary of each fight, kept when it ends, so the numbers outlive the game's own sessions.
-- The game's amounts are secret in combat and for a moment after it, so a fight is read again until
-- they are plain, and only plain numbers are kept.
local ns = _G.NaowhForever

local DM = ns.DamageMeter
local S = DM.Settings

local MIN_SECONDS = 5
local FIRST_TRY, TRY_EVERY, TRIES = 1.5, 2, 8
local BOSS_AGE = 90

local History = {}
DM.History = History

local waiting, tries, started
local boss, bossAt

local function Plain(value)
    return type(value) == "number" and not DM.IsSecret(value)
end

function History.OnEncounterEnd(name)
    if type(name) == "string" and not DM.IsSecret(name) then boss, bossAt = name, GetTime() end
end

function History.OnCombatStart()
    started = true
    waiting = false
end

local function Place()
    if IsInInstance() then
        local name = GetInstanceInfo()
        if type(name) == "string" and name ~= "" then return name end
    end
    return GetZoneText() or ""
end

-- One list's figures for you and for the raid, or nil while any of them is still secret.
local function Figures(list, seconds)
    local session = DM.Session(list, "current")
    if not Plain(session.totalAmount) then return nil end
    local rank, count = DM.Rank(session)
    local mine = rank and session.combatSources[rank]
    local own, perSecond = 0, 0
    if mine then
        if not (Plain(mine.totalAmount) and Plain(mine.amountPerSecond)) then return nil end
        own, perSecond = mine.totalAmount, mine.amountPerSecond
    end
    return { own = own, perSecond = perSecond, total = session.totalAmount,
        totalPerSecond = DM.PerSecond(session.totalAmount, seconds) or 0, rank = rank, count = count }
end

-- The fight as it stands, or nil when it is not readable yet, or false when it is not worth keeping.
local function Snapshot()
    local seconds = DM.Duration("current")
    if not Plain(seconds) then return nil end
    if seconds < MIN_SECONDS then return false end
    local damage, healing = Figures("damage", seconds), Figures("healing", seconds)
    if not (damage and healing) then return nil end
    local name
    if boss and bossAt and GetTime() - bossAt < BOSS_AGE then name = boss end
    return { at = time(), place = Place(), boss = name, seconds = seconds, damage = damage, healing = healing }
end

local function Keep(entry)
    local list = { entry }
    for _, old in ipairs(S.Get("history") or {}) do
        if #list >= S.Get("keepFights") then break end
        list[#list + 1] = old
    end
    S.Set("history", list)
    if History.OnChanged then History.OnChanged() end
end

local function Try()
    if not waiting then return end
    if InCombatLockdown() then waiting = false return end
    local entry = Snapshot()
    if entry then
        waiting = false
        Keep(entry)
    elseif entry == false then
        waiting = false
    else
        tries = tries + 1
        if tries >= TRIES then waiting = false return end
        C_Timer.After(TRY_EVERY, Try)
    end
end

-- Called when combat ends: read the fight once its numbers are plain.
function History.Arm()
    if not started then return end
    started = false
    waiting, tries = true, 0
    C_Timer.After(FIRST_TRY, Try)
end

function History.List()
    return S.Get("history") or {}
end

function History.Clear()
    S.Set("history", {})
    if History.OnChanged then History.OnChanged() end
end

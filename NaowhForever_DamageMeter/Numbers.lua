-- Numbers.lua: how a number is written, and the sums over plain numbers.
local ns = _G.NaowhForever

local DM = ns.DamageMeter
local S = DM.Settings
local C, Plain = DM.C, DM.Plain

local DECIMAL_BASE = 10
local THOUSAND, TEN_THOUSAND, MILLION, HUNDRED_MILLION, BILLION = 1e3, 1e4, 1e6, 1e8, 1e9
local MINUTE, HOUR = C.SECONDS_PER_MINUTE, C.SECONDS_PER_HOUR

local PLAIN_TIER = { breakpoint = 1, abbreviation = "", significandDivisor = 1, fractionDivisor = 1,
    abbreviationIsGlobal = false }

local function Tier(base, glyph, decimals)
    local d = DECIMAL_BASE ^ decimals
    return { breakpoint = base, abbreviation = glyph, significandDivisor = base / d, fractionDivisor = d,
        abbreviationIsGlobal = false }
end

local function Tiers(units, decimals)
    if units == "latin" then
        return { Tier(BILLION, "B", decimals), Tier(MILLION, "M", decimals), Tier(THOUSAND, "K", decimals),
            PLAIN_TIER }
    elseif units == "asian" then
        local g = C.ASIAN_GLYPHS[GetLocale and GetLocale()] or C.ASIAN_GLYPHS.zhCN
        return { Tier(HUNDRED_MILLION, g[3], decimals), Tier(TEN_THOUSAND, g[2], decimals),
            Tier(THOUSAND, g[1], decimals), PLAIN_TIER }
    end
    return { PLAIN_TIER }
end

local function Game(n)
    if AbbreviateLargeNumbers then return AbbreviateLargeNumbers(n) end
    return tostring(n)
end

local formatKey, formatOptions

function DM.Format(n)
    local units = S.Get("numberUnits")
    if units == "game" or not (AbbreviateNumbers and CreateAbbreviateConfig) then return Game(n) end
    local decimals = S.Get("numberDecimals")
    local key = units .. decimals .. (GetLocale and GetLocale() or "")
    if key ~= formatKey then
        formatOptions = { config = CreateAbbreviateConfig(Tiers(units, decimals)) }
        formatKey = key
    end
    return AbbreviateNumbers(n, formatOptions)
end

function DM.PercentText(percent)
    return ("%." .. S.Get("percentDecimals") .. "f%%"):format(percent)
end

function DM.RateSuffix()
    return S.Get("rateSuffix") == true and "/s" or ""
end

function DM.Clock(seconds)
    seconds = math.floor(seconds)
    if seconds >= HOUR then
        return ("%d:%02d:%02d"):format(math.floor(seconds / HOUR), math.floor(seconds % HOUR / MINUTE),
            seconds % MINUTE)
    end
    return ("%d:%02d"):format(math.floor(seconds / MINUTE), seconds % MINUTE)
end

function DM.PerSecond(total, seconds)
    if not (Plain(total, "number") and Plain(seconds, "number")) or seconds <= 0 then return nil end
    return total / seconds
end

function DM.Percent(amount, total)
    if not (Plain(amount, "number") and Plain(total, "number")) or total <= 0 then return nil end
    return amount / total * C.PERCENT
end

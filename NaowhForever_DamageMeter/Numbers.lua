-- Numbers.lua: how a number is written, and the sums over plain numbers. The client formats a secret
-- number for us (AbbreviateNumbers with a config of breakpoints), so a format works in combat too.
local ns = _G.NaowhForever

local DM = ns.DamageMeter
local S = DM.Settings
local C, Plain = DM.C, DM.Plain

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

local function Game(n)
    if AbbreviateLargeNumbers then return AbbreviateLargeNumbers(n) end
    return tostring(n)
end

local formatKey, formatOptions

-- A number as the settings write it. n may be secret, and the answer is a string made from it.
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

-- A share as the settings write it: 25.0%.
function DM.PercentText(percent)
    return ("%." .. S.Get("percentDecimals") .. "f%%"):format(percent)
end

-- What follows a per-second figure: "/s" when the settings say so.
function DM.RateSuffix()
    return S.Get("rateSuffix") == true and "/s" or ""
end

-- m:ss, or h:mm:ss from an hour.
function DM.Clock(seconds)
    seconds = math.floor(seconds)
    if seconds >= 3600 then
        return ("%d:%02d:%02d"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60)
    end
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- A total over a length of time, or nil when either is secret or there is no time.
function DM.PerSecond(total, seconds)
    if not (Plain(total, "number") and Plain(seconds, "number")) or seconds <= 0 then return nil end
    return total / seconds
end

-- A share of a total, as a percentage, or nil when either is secret or there is no total.
function DM.Percent(amount, total)
    if not (Plain(amount, "number") and Plain(total, "number")) or total <= 0 then return nil end
    return amount / total * 100
end

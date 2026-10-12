-- DamageMeter.lua: the Damage Meter's settings (ns.DamageMeterSettings) and its table (ns.DamageMeter).
local ns = _G.NaowhForever

local F = ns.FEATURES.damageMeter

local TITLE, MAX_WINDOWS = "Damage Meter", 3

-- The first window keeps the plain keys; the others add their number: mode2, session3, meterPos2.
local S = ns.UI.ModuleSettings("damageMeter", {
    enabled = F.enabled,
    visibility = "always", locked = false,
    barHeight = 20, barSpacing = 2,
    showTotal = true, showRate = true, showIcons = true, showRanks = true, highlightPlayer = true,
    barColor = "class", barAlpha = 0.85, backgroundAlpha = 0.9,
    fontSize = 11, font = "", outline = "OUTLINE", texture = "",
    hideGameMeter = true, breakdown = true, reportLines = 5,
    mode = "damage", session = "current", width = 300, height = 190,
    meterPos = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -24, y = 210 },
    window2 = false, mode2 = "healing", session2 = "current", width2 = 300, height2 = 190,
    meterPos2 = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -24, y = 420 },
    window3 = false, mode3 = "taken", session3 = "current", width3 = 300, height3 = 190,
    meterPos3 = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -24, y = 630 },
})
ns.DamageMeterSettings = S

local DM = { Settings = S, TITLE = TITLE, MAX_WINDOWS = MAX_WINDOWS }
ns.DamageMeter = DM

function DM.Key(base, index)
    return index and index > 1 and base .. index or base
end

function DM.On()
    return S.Get("enabled")
end

function DM.WindowName(index)
    return index > 1 and TITLE .. " " .. index or TITLE
end

-- Whether window index is open: the first always is, the others when their setting is on.
function DM.WindowOn(index)
    return index == 1 or S.Get(DM.Key("window", index)) == true
end

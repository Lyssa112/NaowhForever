-- DamageMeter.lua: the Damage Meter's settings (ns.DamageMeterSettings) and its table (ns.DamageMeter).
local ns = _G.NaowhForever

local F = ns.FEATURES.damageMeter

local TITLE, MAX_WINDOWS = "Damage Meter", 3

-- The first window keeps the plain keys; the others add their number: mode2, session3, meterPos2.
local S = ns.UI.ModuleSettings("damageMeter", {
    enabled = F.enabled,
    visibility = "always", locked = false,
    barHeight = 20, barSpacing = 2, growUp = false, reverseFill = false, barScale = "top",
    showTotal = true, showRate = true, showPercent = false, showDivider = false, showIcons = true, showRanks = true, highlightPlayer = true,
    barColor = "class", barAlpha = 0.85, backgroundAlpha = 0.9,
    fontSize = 11, font = "", outline = "OUTLINE", texture = "",
    hideGameMeter = true, breakdown = true, reportLines = 5, showTime = true,
    showBorder = true, iconStyle = "spec",
    showColumnHeaders = true, numberUnits = "game", numberDecimals = 1, nameFormat = "full",
    showSummary = false, titleSize = 12, timeSize = 11,
    titleText = "list", titleX = 0, titleY = 0, timeX = 0, timeY = 0, showButtons = true,
    headerAlpha = 1, timeBrackets = false, timeByTitle = false,
    classColors = {}, raidMode = false, hideDelay = 8, ownBarStyle = "bar", edgeStyle = "accent",
    keepFights = 30,
    backgroundImage = "", backgroundPath = "", imageAlpha = 1, imageTile = false, imageTileSize = 128,
    barCustomColor = false, ownBarColor = false, edgeColor = false,
    nameColor = false, valueColor = false, rankColor = false, columnColor = false, titleColor = false,
    timeColor = false, summaryColor = false,
    windowColor = false, headerColor = false, borderColor = false,
    mode = "damage", session = "current", width = 300, height = 206, lower = "", scale = 1,
    meterPos = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -24, y = 210 },
    window2 = false, mode2 = "healing", session2 = "current", width2 = 300, height2 = 206, lower2 = "", scale2 = 1,
    meterPos2 = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -24, y = 420 },
    window3 = false, mode3 = "taken", session3 = "current", width3 = 300, height3 = 206, lower3 = "", scale3 = 1,
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

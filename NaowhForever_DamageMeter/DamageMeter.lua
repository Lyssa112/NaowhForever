-- DamageMeter.lua: the Damage Meter's settings (ns.DamageMeterSettings) and its table (ns.DamageMeter).
local ns = _G.NaowhForever

local F = ns.FEATURES.damageMeter

local S = ns.UI.ModuleSettings("damageMeter", {
    enabled = F.enabled,
    mode = "damage", session = "current", visibility = "always",
    width = 300, height = 190, barHeight = 20, barSpacing = 2, locked = false,
    showTotal = true, showRate = true, showIcons = true, showRanks = true, highlightPlayer = true,
    barColor = "class", barAlpha = 0.85, backgroundAlpha = 0.9,
    fontSize = 11, font = "", outline = "OUTLINE", texture = "",
    hideGameMeter = true,
    meterPos = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -24, y = 210 },
})
ns.DamageMeterSettings = S

local DM = { Settings = S }
ns.DamageMeter = DM

function DM.On()
    return S.Get("enabled")
end

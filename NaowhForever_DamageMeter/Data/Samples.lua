-- Samples.lua: the sample group the preview and Unlock Mode show (DM.SAMPLE), shaped like the game's session.
local ns = _G.NaowhForever

ns.DamageMeter.SAMPLE = {
    durationSeconds = 205,
    maxAmount = 100,
    totalAmount = 660,
    combatSources = {
        { name = "Aldrin", classFilename = "MAGE", totalAmount = 100, amountPerSecond = 41, isLocalPlayer = false },
        { name = "You", classFilename = "ROGUE", totalAmount = 91, amountPerSecond = 37, isLocalPlayer = true },
        { name = "Brenna", classFilename = "WARLOCK", totalAmount = 84, amountPerSecond = 34, isLocalPlayer = false },
        { name = "Corvus", classFilename = "HUNTER", totalAmount = 77, amountPerSecond = 31, isLocalPlayer = false },
        { name = "Dara", classFilename = "WARRIOR", totalAmount = 62, amountPerSecond = 25, isLocalPlayer = false },
        { name = "Edric", classFilename = "PALADIN", totalAmount = 48, amountPerSecond = 20, isLocalPlayer = false },
        { name = "Fenna", classFilename = "PRIEST", totalAmount = 31, amountPerSecond = 13, isLocalPlayer = false },
    },
}

-- Spells.lua: a source's spells, and the enemies it hurt, as the rows a window draws in place of its list.
-- Amounts may be secret in combat: they go straight into the rows, and a figure made from them is made
-- only once they are plain.
local ns = _G.NaowhForever

local DM = ns.DamageMeter
local C = DM.C

local TEXT_UNKNOWN, TEXT_TARGETS = "Unknown", "Targets"

-- A spell's name from the game, or its creature's for a pet or a summon.
function DM.SpellName(spell)
    local getName = C_Spell and C_Spell.GetSpellName
    if getName then
        local ok, name = pcall(getName, spell.spellID)
        if ok and type(name) == "string" then return name end
    end
    if type(spell.creatureName) == "string" then return spell.creatureName end
    return TEXT_UNKNOWN
end

-- A spell's icon, or nil when the game has none or refuses the id.
function DM.SpellIcon(spell)
    local getTexture = C_Spell and C_Spell.GetSpellTexture
    if not getTexture then return nil end
    local ok, texture = pcall(getTexture, spell.spellID)
    if ok and type(texture) ~= "nil" then return texture end
    return nil
end

-- The rows of a source's breakdown, shaped like a session so the window paints them as it does a list: its
-- spells, then the enemies it hurt under a Targets line. data is the game's answer for the source (or nil),
-- and view says seconds (the session's length), rate (the list has a per-second figure), targets and
-- inCombat. Each row says what it is: isSpell, isHeader or isTarget.
function DM.SpellSession(data, source, view)
    local rows = {}
    local spells = data and data.combatSpells or {}
    for _, spell in ipairs(spells) do
        rows[#rows + 1] = { isSpell = true, label = DM.SpellName(spell), icon = DM.SpellIcon(spell),
            spellID = spell.spellID, totalAmount = spell.totalAmount, classFilename = source.classFilename,
            amountPerSecond = view.rate and DM.PerSecond(spell.totalAmount, view.seconds) or nil }
    end
    local targets = view.targets
    if targets and #targets > 0 then
        rows[#rows + 1] = { isHeader = true, label = TEXT_TARGETS }
        for i = 1, math.min(C.TARGET_LINES, #targets) do
            local target = targets[i]
            rows[#rows + 1] = { isTarget = true, label = target.name, totalAmount = target.total,
                maxAmount = targets[1].total, color = C.ENEMY_COLOR, noIcon = true, noPercent = true,
                amountPerSecond = view.rate and DM.PerSecond(target.total, view.seconds) or nil }
        end
    end
    local empty
    if #spells == 0 then empty = view.inCombat and C.TEXT_SPELLS_COMBAT or C.TEXT_SPELLS_NONE end
    return { combatSources = rows, maxAmount = data and data.maxAmount or 0, totalAmount = data and data.totalAmount or 0,
        emptyText = empty }
end

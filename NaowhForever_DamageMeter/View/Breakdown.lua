-- Breakdown.lua: the spells behind a hovered row, in a small panel beside it, in the theme's colors.
local ns = _G.NaowhForever

local UI = ns.UI
local T = ns.THEME
local Parts = ns.Shared.Parts
local DM = ns.DamageMeter
local S = DM.Settings
local C, Look, Format = DM.C, DM.Look, DM.Format
local CROP = ns.Shared.Style.ICON_CROP

local WIDTH, ROW_H, GAP, PAD, HEADER_H, NOTE_H = 260, 18, 2, 6, 24, 22
local SECTION_GAP, SECTION_H = 6, 16
local TEXT_SIZE, TITLE_SIZE, ICON_PAD, VALUE_W = 11, 12, 2, 96
local SIDE_GAP = 6
local GRADIENT_TEX = ns.MEDIA .. "NaowhGradient.tga"

local TEXT_COMBAT = "Spells show after combat."
local TEXT_NONE = "No spell data."
local TEXT_UNKNOWN = "Unknown"
local TEXT_TARGETS = "Targets"
local VALUE_PERCENT = "%s  %.1f%%"
local VALUE_TARGET = "%s | %s"

local Breakdown = {}
DM.Breakdown = Breakdown

local panel

-- A row of the panel: a bar with a name and a value, and for a spell its icon. Rows are placed when the
-- panel is shown, since the sections stack.
local function NewRow(pool, i, withIcon)
    local row = CreateFrame("StatusBar", nil, panel)
    row:SetMinMaxValues(0, 1)
    row:SetSize(WIDTH - 2 * PAD, ROW_H)
    row.value = ns.Font(row, TEXT_SIZE, "OUTLINE", T.fg)
    row.value:SetPoint("RIGHT", -PAD, 0); row.value:SetWidth(VALUE_W); row.value:SetJustifyH("RIGHT")
    row.name = ns.Font(row, TEXT_SIZE, "OUTLINE", T.fg)
    if withIcon then
        row.icon = row:CreateTexture(nil, "OVERLAY")
        row.icon:SetPoint("LEFT", ICON_PAD, 0); row.icon:SetSize(ROW_H - 2 * ICON_PAD, ROW_H - 2 * ICON_PAD)
        row.icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", ICON_PAD + 2, 0)
    else
        row.name:SetPoint("LEFT", PAD, 0)
    end
    row.name:SetPoint("RIGHT", row.value, "LEFT", -PAD, 0)
    row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
    pool[i] = row
    return row
end

local function PlaceRow(row, y)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
end

local function Build()
    panel = CreateFrame("Frame", "NaowhForeverDamageMeterBreakdown", UIParent)
    panel:SetFrameStrata("TOOLTIP"); panel:SetClampedToScreen(true)
    panel.rows, panel.targetRows = {}, {}
    panel.background = ns.Solid(panel, "BACKGROUND", T.bg, 1)
    panel.background:SetAllPoints()
    panel.border = ns.Border(panel)
    panel.title = ns.Font(panel, TITLE_SIZE, "OUTLINE", T.fg)
    panel.title:SetPoint("TOPLEFT", PAD, -PAD); panel.title:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    panel.title:SetJustifyH("LEFT"); panel.title:SetWordWrap(false)
    panel.note = ns.Font(panel, TEXT_SIZE, "OUTLINE", T.muted)
    panel.note:SetPoint("TOPLEFT", PAD, -HEADER_H)
    panel.targetsTitle = ns.Font(panel, TEXT_SIZE, "OUTLINE", T.muted)
    panel.targetsTitle:SetText(TEXT_TARGETS)
    for i = 1, C.BREAKDOWN_LINES do NewRow(panel.rows, i, true) end
    for i = 1, C.TARGET_LINES do NewRow(panel.targetRows, i, false) end
    panel:Hide()
end

local function PaintIcon(icon, spell)
    local getTexture = C_Spell and C_Spell.GetSpellTexture
    if not getTexture then icon:Hide() return end
    local ok, texture = pcall(getTexture, spell.spellID)
    local has = ok and type(texture) ~= "nil"
    if has then icon:SetTexture(texture) end
    icon:SetShown(has)
end

local function SpellName(spell)
    local getName = C_Spell and C_Spell.GetSpellName
    if getName then
        local ok, name = pcall(getName, spell.spellID)
        if ok and type(name) == "string" then return name end
    end
    if type(spell.creatureName) == "string" then return spell.creatureName end
    return TEXT_UNKNOWN
end

local function PaintRow(row, spell, data, color, alpha)
    row:SetStatusBarTexture(UI.TexturePath(S.Get("texture"), GRADIENT_TEX))
    row:SetStatusBarColor(color.r, color.g, color.b, alpha)
    row:SetMinMaxValues(0, data.maxAmount)
    row:SetValue(spell.totalAmount)
    PaintIcon(row.icon, spell)
    row.name:SetText(SpellName(spell))
    local percent = DM.Percent(spell.totalAmount, data.totalAmount)
    if percent then
        row.value:SetFormattedText(VALUE_PERCENT, Format(spell.totalAmount), percent)
    else
        row.value:SetText(Format(spell.totalAmount))
    end
    row:Show()
end

-- The font, outline and colors the meter's settings ask for.
local function Style()
    local font, outline = S.Get("font"), S.Get("outline")
    local name, value, rank = Look.Color("nameColor"), Look.Color("valueColor"), Look.Color("rankColor")
    local title = Look.Color("titleColor")
    local window, border = Look.Color("windowColor"), Look.Color("borderColor")
    panel.background:SetColorTexture(window.r, window.g, window.b, 1)
    panel.border:SetColor(border.r, border.g, border.b, 1)
    panel.border._frame:SetShown(S.Get("showBorder"))
    Parts.HudFont(panel.title, font, TITLE_SIZE, outline)
    panel.title:SetTextColor(title.r, title.g, title.b)
    Parts.HudFont(panel.note, font, TEXT_SIZE, outline)
    panel.note:SetTextColor(rank.r, rank.g, rank.b)
    Parts.HudFont(panel.targetsTitle, font, TEXT_SIZE, outline)
    panel.targetsTitle:SetTextColor(rank.r, rank.g, rank.b)
    for _, pool in ipairs({ panel.rows, panel.targetRows }) do
        for _, row in ipairs(pool) do
            Parts.HudFont(row.name, font, TEXT_SIZE, outline)
            Parts.HudFont(row.value, font, TEXT_SIZE, outline)
            row.name:SetTextColor(name.r, name.g, name.b)
            row.value:SetTextColor(value.r, value.g, value.b)
        end
    end
end

-- A target: its bar against the largest, its name, and the damage with its per-second figure.
local function PaintTarget(row, target, largest, seconds, alpha)
    local c = C.ENEMY_COLOR
    row:SetStatusBarTexture(UI.TexturePath(S.Get("texture"), GRADIENT_TEX))
    row:SetStatusBarColor(c.r, c.g, c.b, alpha)
    row:SetMinMaxValues(0, largest)
    row:SetValue(target.total)
    row.name:SetText(target.name)
    local perSecond = DM.PerSecond(target.total, seconds)
    if perSecond then
        row.value:SetFormattedText(VALUE_TARGET, Format(target.total), Format(perSecond))
    else
        row.value:SetText(Format(target.total))
    end
    row:Show()
end

local function Place(owner, toRight)
    panel:ClearAllPoints()
    if toRight then
        panel:SetPoint("TOPLEFT", owner, "TOPRIGHT", SIDE_GAP, 0)
    else
        panel:SetPoint("TOPRIGHT", owner, "TOPLEFT", -SIDE_GAP, 0)
    end
end

-- Shows source's spells beside row. data is the game's answer for the source, or nil: then the panel says
-- why. targets, when there are any, are the enemies it hurt, and seconds the session's length.
function Breakdown.Show(row, source, data, toRight, inCombat, targets, seconds)
    if not panel then Build() end
    Style()
    panel.title:SetText(DM.DisplayName(source))
    local lines = data and math.min(C.BREAKDOWN_LINES, #data.combatSpells) or 0
    local color, alpha = Look.BarColor(source), S.Get("barAlpha")
    for i = 1, C.BREAKDOWN_LINES do
        local spellRow = panel.rows[i]
        if i <= lines then
            PlaceRow(spellRow, HEADER_H + (i - 1) * (ROW_H + GAP))
            PaintRow(spellRow, data.combatSpells[i], data, color, alpha)
        else
            spellRow:Hide()
        end
    end
    panel.note:SetText(inCombat and TEXT_COMBAT or TEXT_NONE)
    panel.note:SetShown(lines == 0)
    local bottom = HEADER_H + (lines > 0 and lines * (ROW_H + GAP) - GAP or NOTE_H)
    local count = targets and math.min(C.TARGET_LINES, #targets) or 0
    panel.targetsTitle:SetShown(count > 0)
    if count > 0 then
        local top = bottom + SECTION_GAP
        panel.targetsTitle:ClearAllPoints()
        panel.targetsTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -top)
        local y = top + SECTION_H
        for i = 1, C.TARGET_LINES do
            local targetRow = panel.targetRows[i]
            if i <= count then
                PlaceRow(targetRow, y + (i - 1) * (ROW_H + GAP))
                PaintTarget(targetRow, targets[i], targets[1].total, seconds, alpha)
            else
                targetRow:Hide()
            end
        end
        bottom = y + count * (ROW_H + GAP) - GAP
    else
        for _, targetRow in ipairs(panel.targetRows) do targetRow:Hide() end
    end
    panel:SetSize(WIDTH, bottom + PAD)
    Place(row, toRight)
    panel:Show()
end

function Breakdown.Hide()
    if panel then panel:Hide() end
end

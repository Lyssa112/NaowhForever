-- Breakdown.lua: the spells behind a hovered row, in a small panel beside it, in the theme's colors.
local ns = _G.NaowhForever

local UI = ns.UI
local T = ns.THEME
local Parts = ns.Shared.Parts
local DM = ns.DamageMeter
local S = DM.Settings
local C, Look, Short = DM.C, DM.Look, DM.Short
local CROP = ns.Shared.Style.ICON_CROP

local WIDTH, ROW_H, GAP, PAD, HEADER_H, NOTE_H = 260, 18, 2, 6, 24, 22
local TEXT_SIZE, TITLE_SIZE, ICON_PAD, VALUE_W = 11, 12, 2, 96
local SIDE_GAP = 6
local GRADIENT_TEX = ns.MEDIA .. "NaowhGradient.tga"

local TEXT_COMBAT = "Spells show after combat."
local TEXT_NONE = "No spell data."
local TEXT_UNKNOWN = "Unknown"
local VALUE_PERCENT = "%s  %.1f%%"

local Breakdown = {}
DM.Breakdown = Breakdown

local panel

local function NewRow(i)
    local row = CreateFrame("StatusBar", nil, panel)
    row:SetMinMaxValues(0, 1)
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -HEADER_H - (i - 1) * (ROW_H + GAP))
    row:SetSize(WIDTH - 2 * PAD, ROW_H)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(T.panel.r, T.panel.g, T.panel.b, 1)
    row.icon = row:CreateTexture(nil, "OVERLAY")
    row.icon:SetPoint("LEFT", ICON_PAD, 0); row.icon:SetSize(ROW_H - 2 * ICON_PAD, ROW_H - 2 * ICON_PAD)
    row.icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
    row.value = ns.Font(row, TEXT_SIZE, "OUTLINE", T.fg)
    row.value:SetPoint("RIGHT", -PAD, 0); row.value:SetWidth(VALUE_W); row.value:SetJustifyH("RIGHT")
    row.name = ns.Font(row, TEXT_SIZE, "OUTLINE", T.fg)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", ICON_PAD + 2, 0)
    row.name:SetPoint("RIGHT", row.value, "LEFT", -PAD, 0)
    row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
    panel.rows[i] = row
    return row
end

local function Build()
    panel = CreateFrame("Frame", "NaowhForeverDamageMeterBreakdown", UIParent)
    panel:SetFrameStrata("TOOLTIP"); panel:SetClampedToScreen(true)
    panel.rows = {}
    panel.background = ns.Solid(panel, "BACKGROUND", T.bg, 1)
    panel.background:SetAllPoints()
    panel.border = ns.Border(panel)
    panel.title = ns.Font(panel, TITLE_SIZE, "OUTLINE", T.fg)
    panel.title:SetPoint("TOPLEFT", PAD, -PAD); panel.title:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    panel.title:SetJustifyH("LEFT"); panel.title:SetWordWrap(false)
    panel.note = ns.Font(panel, TEXT_SIZE, "OUTLINE", T.muted)
    panel.note:SetPoint("TOPLEFT", PAD, -HEADER_H)
    for i = 1, C.BREAKDOWN_LINES do NewRow(i) end
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
        row.value:SetFormattedText(VALUE_PERCENT, Short(spell.totalAmount), percent)
    else
        row.value:SetText(Short(spell.totalAmount))
    end
    row:Show()
end

-- The font, outline and text colors the meter's settings ask for.
local function Style()
    local font, outline = S.Get("font"), S.Get("outline")
    local text, quiet = Look.TextColor(), Look.QuietColor()
    Parts.HudFont(panel.title, font, TITLE_SIZE, outline)
    panel.title:SetTextColor(text.r, text.g, text.b)
    Parts.HudFont(panel.note, font, TEXT_SIZE, outline)
    panel.note:SetTextColor(quiet.r, quiet.g, quiet.b)
    for _, row in ipairs(panel.rows) do
        Parts.HudFont(row.name, font, TEXT_SIZE, outline)
        Parts.HudFont(row.value, font, TEXT_SIZE, outline)
        row.name:SetTextColor(text.r, text.g, text.b)
        row.value:SetTextColor(text.r, text.g, text.b)
    end
end

local function Place(owner, toRight)
    panel:ClearAllPoints()
    if toRight then
        panel:SetPoint("TOPLEFT", owner, "TOPRIGHT", SIDE_GAP, 0)
    else
        panel:SetPoint("TOPRIGHT", owner, "TOPLEFT", -SIDE_GAP, 0)
    end
end

-- Shows source's spells beside row. data is the game's answer for the source, or nil: then the panel says why.
function Breakdown.Show(row, source, data, toRight, inCombat)
    if not panel then Build() end
    Style()
    panel.title:SetText(source.name)
    local lines = data and math.min(C.BREAKDOWN_LINES, #data.combatSpells) or 0
    local color, alpha = Look.Color(source), S.Get("barAlpha")
    for i = 1, C.BREAKDOWN_LINES do
        if i <= lines then
            PaintRow(panel.rows[i], data.combatSpells[i], data, color, alpha)
        else
            panel.rows[i]:Hide()
        end
    end
    panel.note:SetText(inCombat and TEXT_COMBAT or TEXT_NONE)
    panel.note:SetShown(lines == 0)
    local body = lines > 0 and lines * (ROW_H + GAP) - GAP or NOTE_H
    panel:SetSize(WIDTH, HEADER_H + body + PAD)
    Place(row, toRight)
    panel:Show()
end

function Breakdown.Hide()
    if panel then panel:Hide() end
end

-- Meter.lua: the Damage Meter's look and layout, in the theme's colors.
local ns = _G.NaowhForever

local UI = ns.UI
local T = ns.THEME
local Parts = ns.Shared.Parts
local DM = ns.DamageMeter
local S = DM.Settings
local C, Key, Short = DM.C, DM.Key, DM.Short

local FALLBACK = { r = 0.6, g = 0.6, b = 0.6 }
local GRADIENT_TEX = ns.MEDIA .. "NaowhGradient.tga"
local CLASS_ICON = "Interface\\Icons\\ClassIcon_"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ICON_CROP, ICON_MAX, ICON_PAD, ICON_GAP = ns.Shared.Style.ICON_CROP, 28, 4, 5
local INSET, HEADER = C.INSET, C.HEADER
local TEXT_PAD, NAME_GAP, EDGE_W = 6, 6, 2
local RANK_W, RANK_SIZE = 18, 10
local VALUE_CHARS_BOTH, VALUE_CHARS_ONE, CHAR_W = 14, 7, 0.62
local EMPTY_SIZE, EMPTY_Y = 12, -10
local TITLE_SIZE, TITLE_X = 12, 8

local TEXT_EMPTY = "No data yet"
local TEXT_UNAVAILABLE = "The damage meter is not available"
local VALUE_BOTH, RANK_TEXT = "%s (%s)", "%d"

local Look = {}
DM.Look = Look

local classIcons = {}

local function ClassColor(class)
    return class and RAID_CLASS_COLORS[class] or FALLBACK
end

local function IconOf(source)
    local id = source.specIconID
    if type(id) == "number" and id ~= 0 then return id end
    local class = source.classFilename
    if class and class ~= "" then
        local path = classIcons[class]
        if not path then path = CLASS_ICON .. class; classIcons[class] = path end
        return path
    end
    return UNKNOWN_ICON
end

function Look.New(frame, index)
    frame.rows = {}
    frame.index = index
    frame.background = ns.Solid(frame, "BACKGROUND", T.bg, 1)
    frame.background:SetAllPoints()
    frame.border = ns.Border(frame)
    frame.header = CreateFrame("Frame", nil, frame)
    frame.header:SetPoint("TOPLEFT"); frame.header:SetPoint("TOPRIGHT"); frame.header:SetHeight(HEADER)
    ns.Solid(frame.header, "BACKGROUND", T.panel, 1):SetAllPoints()
    local rule = ns.Solid(frame.header, "OVERLAY", T.line, 1)
    rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT"); rule:SetHeight(1)
    frame.empty = ns.Font(frame, EMPTY_SIZE, "OUTLINE", T.muted)
    frame.empty:SetPoint("CENTER", 0, EMPTY_Y)
    frame.title = ns.Font(frame.header, TITLE_SIZE, "OUTLINE", T.fg)
    frame.title:SetPoint("LEFT", TITLE_X, 0); frame.title:SetJustifyH("LEFT"); frame.title:SetWordWrap(false)
end

function Look.Row(f, i)
    local row = CreateFrame("StatusBar", nil, f)
    row:SetMinMaxValues(0, 1)
    row:EnableMouse(true); row:EnableMouseWheel(true)
    row:SetScript("OnEnter", function(self) if f.onRowEnter then f.onRowEnter(self) end end)
    row:SetScript("OnLeave", function() if f.onRowLeave then f.onRowLeave() end end)
    row:SetScript("OnMouseWheel", function(_, delta) if f.onWheel then f.onWheel(delta) end end)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.edge = row:CreateTexture(nil, "OVERLAY")
    row.edge:SetPoint("TOPLEFT"); row.edge:SetPoint("BOTTOMLEFT"); row.edge:SetWidth(EDGE_W)
    row.rank = ns.Font(row, RANK_SIZE, "OUTLINE", T.muted)
    row.icon = row:CreateTexture(nil, "OVERLAY")
    row.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    row.value = ns.Font(row, C.MIN_FONT, "OUTLINE", T.fg)
    row.value:SetJustifyH("RIGHT")
    row.name = ns.Font(row, C.MIN_FONT, "OUTLINE", T.fg)
    row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
    f.rows[i] = row
    return row
end

function Look.Capacity(h, bh, gap)
    return math.max(1, math.floor((h - HEADER - 2 * INSET + gap) / (bh + gap)))
end

local function LayRow(row, f, i, bh, gap, w, fontSize, showRanks, showIcons, valueWidth, texture, font, outline)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", f, "TOPLEFT", INSET, -HEADER - INSET - (i - 1) * (bh + gap))
    row:SetSize(w - 2 * INSET, bh)
    row:SetStatusBarTexture(UI.TexturePath(texture, GRADIENT_TEX))
    local left = TEXT_PAD
    row.rank:ClearAllPoints(); row.rank:SetPoint("LEFT", left, 0); row.rank:SetWidth(RANK_W)
    row.rank:SetShown(showRanks)
    if showRanks then left = left + RANK_W end
    local iconSize = math.min(ICON_MAX, bh - ICON_PAD)
    row.icon:ClearAllPoints(); row.icon:SetPoint("LEFT", left, 0); row.icon:SetSize(iconSize, iconSize)
    row.icon:SetShown(showIcons)
    if showIcons then left = left + iconSize + ICON_GAP end
    row.value:ClearAllPoints(); row.value:SetPoint("RIGHT", -TEXT_PAD, 0); row.value:SetWidth(math.max(1, valueWidth))
    row.name:ClearAllPoints(); row.name:SetPoint("LEFT", left, 0)
    row.name:SetPoint("RIGHT", -TEXT_PAD - valueWidth - NAME_GAP, 0)
    Parts.HudFont(row.name, font, fontSize, outline)
    Parts.HudFont(row.value, font, fontSize, outline)
end

-- Sizes the window and lays the rows that fit; returns how many are shown and the first one's index.
function Look.Layout(f, total, first, bh, gap, fontSize, mode)
    local w = math.max(C.MIN_WIDTH, S.Get(Key("width", f.index)))
    local minHeight = math.max(C.MIN_HEIGHT, HEADER + 2 * INSET + bh)
    local h = math.max(minHeight, S.Get(Key("height", f.index)))
    if not f.sizing then f:SetSize(w, h) else w, h = f:GetWidth(), f:GetHeight() end
    local capacity = Look.Capacity(h, bh, gap)
    first = math.max(0, math.min(first, total - capacity))
    local shown = math.min(total - first, capacity)
    local showRanks, showIcons = S.Get("showRanks"), S.Get("showIcons")
    local columns = (S.Get("showTotal") and 1 or 0) + (S.Get("showRate") and mode.rate and 1 or 0)
    local chars = columns == 2 and VALUE_CHARS_BOTH or columns == 1 and VALUE_CHARS_ONE or 0
    local valueWidth = math.floor(chars * CHAR_W * fontSize)
    local texture, font, outline = S.Get("texture"), S.Get("font"), S.Get("outline")
    local key = table.concat({ w, h, bh, gap, fontSize, tostring(showRanks), tostring(showIcons), valueWidth,
        texture, font, outline }, "|")
    local rows = f.rows
    for i = 1, shown do
        local row = rows[i] or Look.Row(f, i)
        if f.laidKey ~= key or row.laidKey ~= key then
            LayRow(row, f, i, bh, gap, w, fontSize, showRanks, showIcons, valueWidth, texture, font, outline)
            row.laidKey = key
        end
        row:Show()
    end
    f.laidKey = key
    for i = shown + 1, #rows do rows[i]:Hide() end
    f.background:SetAlpha(S.Get("backgroundAlpha"))
    f.border._frame:SetAlpha(S.Get("backgroundAlpha"))
    return shown, first
end

local function PaintValue(row, source, mode, showTotal, showRate)
    local rate = showRate and mode.rate
    if showTotal and rate then
        row.value:SetFormattedText(VALUE_BOTH, Short(source.totalAmount), Short(source.amountPerSecond))
    elseif showTotal then
        row.value:SetText(Short(source.totalAmount))
    elseif rate then
        row.value:SetText(Short(source.amountPerSecond))
    else
        row.value:SetText("")
    end
end

-- A source's bar color: its class, or the theme's Accent for everyone.
function Look.Color(source)
    if S.Get("barColor") == "accent" then return T.accent end
    return ClassColor(source.classFilename)
end

function Look.Paint(f, session, first, shown, mode, available)
    local sources = session.combatSources
    local alpha = S.Get("barAlpha")
    local showTotal, showRate = S.Get("showTotal"), S.Get("showRate")
    local own = S.Get("highlightPlayer")
    f.empty:SetText(available and TEXT_EMPTY or TEXT_UNAVAILABLE)
    f.empty:SetShown(shown == 0)
    for i = 1, shown do
        local source, row = sources[first + i], f.rows[i]
        local c = Look.Color(source)
        row.source = source
        row:SetStatusBarColor(c.r, c.g, c.b, alpha)
        row:SetMinMaxValues(0, session.maxAmount)
        row:SetValue(source.totalAmount)
        row.bg:SetColorTexture(T.panel.r, T.panel.g, T.panel.b, 1)
        local mine = own and source.isLocalPlayer == true
        row.edge:SetColorTexture(mine and T.accent.r or c.r, mine and T.accent.g or c.g, mine and T.accent.b or c.b, 1)
        row.rank:SetFormattedText(RANK_TEXT, first + i)
        row.icon:SetTexture(IconOf(source))
        row.name:SetText(source.name)
        PaintValue(row, source, mode, showTotal, showRate)
    end
end

-- Meter.lua: the Damage Meter's look and layout, in the theme's colors unless the settings pick others.
local ns = _G.NaowhForever

local UI = ns.UI
local T = ns.THEME
local Parts = ns.Shared.Parts
local DM = ns.DamageMeter
local S = DM.Settings
local C, Key, Format = DM.C, DM.Key, DM.Format

local FALLBACK = { r = 0.6, g = 0.6, b = 0.6 }
local GRADIENT_TEX = ns.MEDIA .. "NaowhGradient.tga"
local CLASS_ICON = "Interface\\Icons\\ClassIcon_"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ICON_CROP, ICON_MAX, ICON_PAD, ICON_GAP = ns.Shared.Style.ICON_CROP, 28, 4, 5
local INSET, HEADER, COLUMN_HEAD, COL_GAP = C.INSET, C.HEADER, C.COLUMN_HEAD, C.COL_GAP
local TEXT_PAD, NAME_GAP, EDGE_W = 6, 6, 2
local RANK_W, RANK_SIZE = 18, 10
local COL_CHARS, COL_CHARS_FULL, CHAR_W = 7, 10, 0.62
local EMPTY_SIZE, EMPTY_Y = 12, -10
local TITLE_SIZE, TITLE_X, TIME_SIZE, HEAD_SIZE, HEAD_PAD = 12, 8, 11, 10, 3

local TEXT_EMPTY = "No data yet"
local TEXT_UNAVAILABLE = "The damage meter is not available"
local TEXT_NAME_HEAD, TEXT_TOTAL, TEXT_RATE = "Name", "Total", "Per Sec"
local RANK_TEXT = "%d"

local Look = {}
DM.Look = Look

local classIcons = {}
local tokenOf = {}
for _, entry in ipairs(C.COLORS) do tokenOf[entry.key] = entry.token end

local function ClassColor(class)
    return class and RAID_CLASS_COLORS[class] or FALLBACK
end

local function ClassIcon(class)
    local path = classIcons[class]
    if not path then path = CLASS_ICON .. class; classIcons[class] = path end
    return path
end

local function IconOf(source, classOnly)
    local id = source.specIconID
    if not classOnly and type(id) == "number" and id ~= 0 then return id end
    local class = source.classFilename
    if class and class ~= "" then return ClassIcon(class) end
    return UNKNOWN_ICON
end

-- A color of the window: the one picked in the settings, or the theme's token it stands in for.
function Look.Color(key)
    local c = S.Get(key)
    if type(c) == "table" then return c end
    return T[tokenOf[key]]
end

-- A source's bar color: its class, the theme's Accent for everyone, or the one picked.
function Look.BarColor(source)
    local choice = S.Get("barColor")
    if choice == "accent" then return T.accent end
    if choice == "custom" then return Look.Color("barCustomColor") end
    return ClassColor(source.classFilename)
end

function Look.New(frame, index)
    frame.rows = {}
    frame.cols = {}
    frame.index = index
    frame.background = ns.Solid(frame, "BACKGROUND", T.bg, 1)
    frame.background:SetAllPoints()
    frame.border = ns.Border(frame)
    frame.header = CreateFrame("Frame", nil, frame)
    frame.header:SetPoint("TOPLEFT"); frame.header:SetPoint("TOPRIGHT"); frame.header:SetHeight(HEADER)
    frame.headerBackground = ns.Solid(frame.header, "BACKGROUND", T.panel, 1)
    frame.headerBackground:SetAllPoints()
    local rule = ns.Solid(frame.header, "OVERLAY", T.line, 1)
    rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT"); rule:SetHeight(1)
    frame.empty = ns.Font(frame, EMPTY_SIZE, "OUTLINE", T.muted)
    frame.empty:SetPoint("CENTER", 0, EMPTY_Y)
    frame.title = ns.Font(frame.header, TITLE_SIZE, "OUTLINE", T.fg)
    frame.title:SetPoint("LEFT", TITLE_X, 0); frame.title:SetJustifyH("LEFT"); frame.title:SetWordWrap(false)
    frame.time = ns.Font(frame.header, TIME_SIZE, "OUTLINE", T.muted)
    frame.time:SetWidth(C.TIME_WIDTH); frame.time:SetJustifyH("RIGHT")
    frame.headName = ns.Font(frame, HEAD_SIZE, "OUTLINE", T.muted)
    frame.headName:SetJustifyH("LEFT"); frame.headName:SetText(TEXT_NAME_HEAD)
    frame.headA = ns.Font(frame, HEAD_SIZE, "OUTLINE", T.muted)
    frame.headA:SetJustifyH("RIGHT")
    frame.headB = ns.Font(frame, HEAD_SIZE, "OUTLINE", T.muted)
    frame.headB:SetJustifyH("RIGHT")
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
    row.colA = ns.Font(row, C.MIN_FONT, "OUTLINE", T.fg)
    row.colA:SetJustifyH("RIGHT")
    row.colB = ns.Font(row, C.MIN_FONT, "OUTLINE", T.fg)
    row.colB:SetJustifyH("RIGHT")
    row.name = ns.Font(row, C.MIN_FONT, "OUTLINE", T.fg)
    row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
    f.rows[i] = row
    return row
end

-- How many rows fit under a title bar and the column titles of height top.
function Look.Capacity(h, bh, gap, top)
    return math.max(1, math.floor((h - (top or HEADER) - 2 * INSET + gap) / (bh + gap)))
end

-- The kinds of value the two columns show, left to right: "total", "rate" or nil. One column is the
-- right one; the DPS and HPS lists lead with the per-second figure.
local function Columns(f, mode)
    local total, rate = S.Get("showTotal"), S.Get("showRate") and mode.rate
    local first, second = "total", "rate"
    if mode.rateFirst then first, second = "rate", "total" end
    local a, b = first, second
    if (first == "total" and not total) or (first == "rate" and not rate) then a = nil end
    if (second == "total" and not total) or (second == "rate" and not rate) then b = nil end
    if a and not b then a, b = nil, a end
    f.cols.a, f.cols.b = a, b
    return a, b
end

local function ColumnTitle(mode, kind)
    if kind == "rate" then return mode.perSecond or TEXT_RATE end
    return mode.total or TEXT_TOTAL
end

local function LayRow(row, f, i, g)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", f, "TOPLEFT", INSET, -g.top - INSET - (i - 1) * (g.bh + g.gap))
    row:SetSize(g.w - 2 * INSET, g.bh)
    row:SetStatusBarTexture(UI.TexturePath(g.texture, GRADIENT_TEX))
    local left = TEXT_PAD
    row.rank:ClearAllPoints(); row.rank:SetPoint("LEFT", left, 0); row.rank:SetWidth(RANK_W)
    row.rank:SetShown(g.showRanks)
    row.rank:SetTextColor(f.rankColor.r, f.rankColor.g, f.rankColor.b)
    row.name:SetTextColor(f.nameColor.r, f.nameColor.g, f.nameColor.b)
    row.colA:SetTextColor(f.valueColor.r, f.valueColor.g, f.valueColor.b)
    row.colB:SetTextColor(f.valueColor.r, f.valueColor.g, f.valueColor.b)
    if g.showRanks then left = left + RANK_W end
    local iconSize = math.min(ICON_MAX, g.bh - ICON_PAD)
    row.icon:ClearAllPoints(); row.icon:SetPoint("LEFT", left, 0); row.icon:SetSize(iconSize, iconSize)
    row.icon:SetShown(g.showIcons)
    if g.showIcons then left = left + iconSize + ICON_GAP end
    row.colB:ClearAllPoints(); row.colB:SetPoint("RIGHT", -TEXT_PAD, 0); row.colB:SetWidth(g.colWidth)
    row.colB:SetShown(g.columns >= 1)
    row.colA:ClearAllPoints(); row.colA:SetPoint("RIGHT", row.colB, "LEFT", -COL_GAP, 0); row.colA:SetWidth(g.colWidth)
    row.colA:SetShown(g.columns == 2)
    row.name:ClearAllPoints(); row.name:SetPoint("LEFT", left, 0)
    row.name:SetPoint("RIGHT", -TEXT_PAD - g.valueWidth - NAME_GAP, 0)
    Parts.HudFont(row.name, g.font, g.fontSize, g.outline)
    Parts.HudFont(row.colA, g.font, g.fontSize, g.outline)
    Parts.HudFont(row.colB, g.font, g.fontSize, g.outline)
end

-- The column titles above the rows: Name, and a title over each value column.
local function LayHeads(f, g)
    local show = g.showHead
    f.headName:SetShown(show)
    f.headA:SetShown(show and g.columns == 2)
    f.headB:SetShown(show and g.columns >= 1)
    if not show then return end
    local y = -HEADER - HEAD_PAD
    f.headB:ClearAllPoints(); f.headB:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(INSET + TEXT_PAD), y)
    f.headB:SetWidth(g.colWidth)
    f.headA:ClearAllPoints(); f.headA:SetPoint("TOPRIGHT", f.headB, "TOPLEFT", -COL_GAP, 0)
    f.headA:SetWidth(g.colWidth)
    f.headName:ClearAllPoints()
    f.headName:SetPoint("TOPLEFT", f, "TOPLEFT", INSET + TEXT_PAD + (g.showRanks and RANK_W or 0), y)
    for _, fs in ipairs({ f.headName, f.headA, f.headB }) do
        Parts.HudFont(fs, g.font, HEAD_SIZE, g.outline)
        fs:SetTextColor(f.columnColor.r, f.columnColor.g, f.columnColor.b)
    end
end

-- The window's own colors: the frame, the title bar and its texts.
local function PaintFrame(f)
    local window, header, border = Look.Color("windowColor"), Look.Color("headerColor"), Look.Color("borderColor")
    local title, time, rank = Look.Color("titleColor"), Look.Color("timeColor"), Look.Color("rankColor")
    local alpha = S.Get("backgroundAlpha")
    f.background:SetColorTexture(window.r, window.g, window.b, 1)
    f.background:SetAlpha(alpha)
    f.headerBackground:SetColorTexture(header.r, header.g, header.b, 1)
    f.border:SetColor(border.r, border.g, border.b, 1)
    f.border._frame:SetShown(S.Get("showBorder"))
    f.border._frame:SetAlpha(alpha)
    f.title:SetTextColor(title.r, title.g, title.b)
    f.time:SetTextColor(time.r, time.g, time.b)
    f.empty:SetTextColor(rank.r, rank.g, rank.b)
end

-- Sizes the window and lays the rows that fit; returns how many are shown and the first one's index.
function Look.Layout(f, total, first, bh, gap, fontSize, mode)
    local w = math.max(C.MIN_WIDTH, S.Get(Key("width", f.index)))
    local minHeight = math.max(C.MIN_HEIGHT, HEADER + 2 * INSET + bh)
    local h = math.max(minHeight, S.Get(Key("height", f.index)))
    if not f.sizing then f:SetSize(w, h) else w, h = f:GetWidth(), f:GetHeight() end
    local showHead = S.Get("showColumnHeaders") == true
    local top = HEADER + (showHead and COLUMN_HEAD or 0)
    local capacity = Look.Capacity(h, bh, gap, top)
    first = math.max(0, math.min(first, total - capacity))
    local shown = math.min(total - first, capacity)
    local a, b = Columns(f, mode)
    local columns = (a and 1 or 0) + (b and 1 or 0)
    local chars = S.Get("numberUnits") == "full" and COL_CHARS_FULL or COL_CHARS
    local colWidth = math.floor(chars * CHAR_W * fontSize)
    local valueWidth = columns == 0 and 0 or columns * colWidth + (columns - 1) * COL_GAP
    PaintFrame(f)
    local name, value, rank = Look.Color("nameColor"), Look.Color("valueColor"), Look.Color("rankColor")
    local column = Look.Color("columnColor")
    f.nameColor, f.valueColor, f.rankColor, f.columnColor = name, value, rank, column
    local g = f.geo or {}
    f.geo = g
    g.w, g.bh, g.gap, g.top, g.fontSize = w, bh, gap, top, fontSize
    g.showRanks, g.showIcons, g.showHead = S.Get("showRanks"), S.Get("showIcons"), showHead
    g.columns, g.colWidth, g.valueWidth = columns, colWidth, valueWidth
    g.texture, g.font, g.outline = S.Get("texture"), S.Get("font"), S.Get("outline")
    local key = table.concat({ w, h, bh, gap, fontSize, tostring(g.showRanks), tostring(g.showIcons), tostring(showHead),
        columns, colWidth, g.texture, g.font, g.outline, name.r, name.g, name.b, value.r, value.g, value.b,
        rank.r, rank.g, rank.b, column.r, column.g, column.b }, "|")
    if f.laidKey ~= key then LayHeads(f, g) end
    f.headName:SetText(TEXT_NAME_HEAD)
    if a then f.headA:SetText(ColumnTitle(mode, a)) end
    if b then f.headB:SetText(ColumnTitle(mode, b)) end
    local rows = f.rows
    for i = 1, shown do
        local row = rows[i] or Look.Row(f, i)
        if f.laidKey ~= key or row.laidKey ~= key then
            LayRow(row, f, i, g)
            row.laidKey = key
        end
        row:Show()
    end
    f.laidKey = key
    for i = shown + 1, #rows do rows[i]:Hide() end
    return shown, first
end

local function ValueOf(source, kind)
    if kind == "rate" then return source.amountPerSecond end
    return source.totalAmount
end

local function PaintValues(row, source, cols)
    if cols.a then row.colA:SetText(Format(ValueOf(source, cols.a))) end
    if cols.b then row.colB:SetText(Format(ValueOf(source, cols.b))) end
end

function Look.Paint(f, session, first, shown, _, available)
    local sources = session.combatSources
    local alpha = S.Get("barAlpha")
    local own = S.Get("highlightPlayer")
    local classOnly = S.Get("iconStyle") == "class"
    local track, edge = Look.Color("trackColor"), Look.Color("edgeColor")
    f.empty:SetText(available and TEXT_EMPTY or TEXT_UNAVAILABLE)
    f.empty:SetShown(shown == 0)
    for i = 1, shown do
        local source, row = sources[first + i], f.rows[i]
        local c = Look.BarColor(source)
        row.source = source
        row:SetStatusBarColor(c.r, c.g, c.b, alpha)
        row:SetMinMaxValues(0, session.maxAmount)
        row:SetValue(source.totalAmount)
        row.bg:SetColorTexture(track.r, track.g, track.b, 1)
        local e = own and source.isLocalPlayer == true and edge or c
        row.edge:SetColorTexture(e.r, e.g, e.b, 1)
        row.rank:SetFormattedText(RANK_TEXT, first + i)
        row.icon:SetTexture(IconOf(source, classOnly))
        row.name:SetText(source.name)
        PaintValues(row, source, f.cols)
    end
end

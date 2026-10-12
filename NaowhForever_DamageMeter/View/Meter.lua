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
local SUMMARY_H, TIME_CHARS, LOWER_STRIP, LOWER_GAP = C.SUMMARY_H, 7, C.LOWER_STRIP, C.LOWER_GAP
local TEXT_PAD, NAME_GAP, EDGE_W = 6, 6, 2
local RANK_W, RANK_SIZE = 18, 10
local COL_CHARS, COL_CHARS_FULL, CHAR_W = 7, 10, 0.62
local EMPTY_SIZE = 12
local TITLE_X = C.TITLE_X
local TITLE_SIZE, TIME_SIZE, HEAD_SIZE, HEAD_PAD, SUMMARY_SIZE = 12, 11, 10, 3, 11

local TEXT_EMPTY = "No data yet"
local TEXT_UNAVAILABLE = "The damage meter is not available"
local TEXT_NAME_HEAD, TEXT_TOTAL, TEXT_RATE = "Name", "Total", "Per Sec"
local SUMMARY_GAP, TEXT_RAID, TEXT_RANK = "   ", "Raid %s", "Rank %d/%d"
local RANK_TEXT = "%d"

local Look = {}
DM.Look = Look

local classIcons = {}
local tokenOf = {}
for _, entry in ipairs(C.COLORS) do tokenOf[entry.key] = entry.token end

-- A class's bar color: the one picked for it in the settings, or the game's.
local function ClassColor(class)
    local picked = S.Get("classColors")
    local c = type(picked) == "table" and class and picked[class]
    return c or class and RAID_CLASS_COLORS[class] or FALLBACK
end

local function SharedMedia()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

-- The path of the background in use: the path typed in the settings when Image is your own picture, or
-- else the one picked by name from the shared media. Nil for none.
local function ImagePath(name, typed)
    if name == C.OWN_PICTURE then return typed ~= "" and typed or nil end
    if C.HIDDEN_BACKGROUNDS[name] then return nil end
    local LSM = SharedMedia()
    return LSM and name and name ~= "" and LSM:Fetch("background", name, true) or nil
end

Look.ClassColor = ClassColor

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

-- A source's bar color: your own as Your Bar says, else its class, the theme's Accent for everyone, or
-- the one picked for everyone.
function Look.BarColor(source)
    if source.isLocalPlayer == true then
        local style = S.Get("ownBarStyle")
        if style == "custom" then return Look.Color("ownBarColor") end
        if style == "class" then return ClassColor(source.classFilename) end
    end
    local choice = S.Get("barColor")
    if choice == "accent" then return T.accent end
    if choice == "custom" then return Look.Color("barCustomColor") end
    return ClassColor(source.classFilename)
end

-- The strip on the left of your row: the theme's Accent, your class's color, or the one picked.
function Look.EdgeColor(source)
    local style = S.Get("edgeStyle")
    if style == "class" then return ClassColor(source.classFilename) end
    if style == "custom" then return Look.Color("edgeColor") end
    return T.accent
end

-- How wide the fight time is at the size the settings give it.
function Look.TimeWidth()
    return math.ceil(TIME_CHARS * CHAR_W * S.Get("timeSize"))
end

-- A pane is a list of rows with its column titles. A window has one, and a second below it on request.
local function NewPane(f, n)
    local pane = { f = f, n = n, rows = {}, cols = {}, columns = 0, valueWidth = 0, top = 0 }
    pane.headName = ns.Font(f, HEAD_SIZE, "OUTLINE", T.muted)
    pane.headName:SetJustifyH("LEFT"); pane.headName:SetText(TEXT_NAME_HEAD)
    pane.headA = ns.Font(f, HEAD_SIZE, "OUTLINE", T.muted)
    pane.headA:SetJustifyH("RIGHT")
    pane.headB = ns.Font(f, HEAD_SIZE, "OUTLINE", T.muted)
    pane.headB:SetJustifyH("RIGHT")
    pane.empty = ns.Font(f, EMPTY_SIZE, "OUTLINE", T.muted)
    return pane
end

function Look.New(frame, index)
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
    frame.image = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.image:SetAllPoints()
    frame.image:Hide()
    frame.title = ns.Font(frame.header, TITLE_SIZE, "OUTLINE", T.fg)
    frame.title:SetJustifyH("LEFT"); frame.title:SetWordWrap(false)
    frame.time = ns.Font(frame.header, TIME_SIZE, "OUTLINE", T.muted)
    frame.time:SetJustifyH("RIGHT")
    frame.summary = ns.Font(frame, SUMMARY_SIZE, "OUTLINE", T.muted)
    frame.summary:SetJustifyH("LEFT"); frame.summary:SetWordWrap(false)
    local upper, lower = NewPane(frame, 1), NewPane(frame, 2)
    frame.panes = { upper, lower }
    frame.rows, frame.cols = upper.rows, upper.cols
    frame.headName, frame.headA, frame.headB, frame.empty = upper.headName, upper.headA, upper.headB, upper.empty
    frame.rows2 = lower.rows
    frame.lowerBar = CreateFrame("Frame", nil, frame)
    frame.lowerBar:SetHeight(LOWER_STRIP)
    frame.lowerBackground = ns.Solid(frame.lowerBar, "BACKGROUND", T.panel, 1)
    frame.lowerBackground:SetAllPoints()
    frame.lowerTitle = ns.Font(frame.lowerBar, TITLE_SIZE, "OUTLINE", T.fg)
    frame.lowerTitle:SetWordWrap(false)
    frame.lowerBar:Hide()
end

function Look.Row(pane, i)
    local f = pane.f
    local row = CreateFrame("StatusBar", nil, f)
    row.pane = pane.n
    row:SetMinMaxValues(0, 1)
    row:EnableMouse(true); row:EnableMouseWheel(true)
    row:SetScript("OnEnter", function(self) if f.onRowEnter then f.onRowEnter(self) end end)
    row:SetScript("OnLeave", function() if f.onRowLeave then f.onRowLeave() end end)
    row:SetScript("OnMouseWheel", function(self, delta) if f.onWheel then f.onWheel(delta, self) end end)
    row:SetScript("OnMouseUp", function(self, button) if f.onRowClick then f.onRowClick(self, button) end end)
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
    pane.rows[i] = row
    return row
end

-- How many rows fit under a title bar and the column titles of height top.
function Look.Capacity(h, bh, gap, top)
    return math.max(1, math.floor((h - (top or HEADER) - 2 * INSET + gap) / (bh + gap)))
end

-- The kinds of value the pane's two columns show, left to right: "total", "rate" or nil. One column is
-- the right one; the DPS and HPS lists lead with the per-second figure.
local function Columns(pane, mode)
    local total, rate = S.Get("showTotal"), S.Get("showRate") and mode.rate
    local first, second = "total", "rate"
    if mode.rateFirst then first, second = "rate", "total" end
    local a, b = first, second
    if (first == "total" and not total) or (first == "rate" and not rate) then a = nil end
    if (second == "total" and not total) or (second == "rate" and not rate) then b = nil end
    if a and not b then a, b = nil, a end
    pane.cols.a, pane.cols.b = a, b
    return a, b
end

local function ColumnTitle(mode, kind)
    if kind == "rate" then return mode.perSecond or TEXT_RATE end
    return mode.total or TEXT_TOTAL
end

local function LayRow(row, pane, i, g)
    local f = pane.f
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", f, "TOPLEFT", INSET, -pane.top - INSET - (i - 1) * (g.bh + g.gap))
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
    row.colB:SetShown(pane.columns >= 1)
    row.colA:ClearAllPoints(); row.colA:SetPoint("RIGHT", row.colB, "LEFT", -COL_GAP, 0); row.colA:SetWidth(g.colWidth)
    row.colA:SetShown(pane.columns == 2)
    row.name:ClearAllPoints(); row.name:SetPoint("LEFT", left, 0)
    row.name:SetPoint("RIGHT", -TEXT_PAD - pane.valueWidth - NAME_GAP, 0)
    Parts.HudFont(row.name, g.font, g.fontSize, g.outline)
    Parts.HudFont(row.colA, g.font, g.fontSize, g.outline)
    Parts.HudFont(row.colB, g.font, g.fontSize, g.outline)
end

-- The column titles above a pane's rows at y: Name, and a title over each value column.
local function LayHeads(pane, g, y)
    local f = pane.f
    local show = g.showHead
    pane.headName:SetShown(show)
    pane.headA:SetShown(show and pane.columns == 2)
    pane.headB:SetShown(show and pane.columns >= 1)
    if not show then return end
    pane.headB:ClearAllPoints(); pane.headB:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(INSET + TEXT_PAD), y)
    pane.headB:SetWidth(g.colWidth)
    pane.headA:ClearAllPoints(); pane.headA:SetPoint("TOPRIGHT", pane.headB, "TOPLEFT", -COL_GAP, 0)
    pane.headA:SetWidth(g.colWidth)
    pane.headName:ClearAllPoints()
    pane.headName:SetPoint("TOPLEFT", f, "TOPLEFT", INSET + TEXT_PAD + (g.showRanks and RANK_W or 0), y)
    for _, fs in ipairs({ pane.headName, pane.headA, pane.headB }) do
        Parts.HudFont(fs, g.font, HEAD_SIZE, g.outline)
        fs:SetTextColor(f.columnColor.r, f.columnColor.g, f.columnColor.b)
    end
end

-- The parts of the window outside the panes: the summary line, the title and the time, the image.
local function LayFrame(f, g)
    f.summary:ClearAllPoints()
    f.summary:SetPoint("TOPLEFT", f, "TOPLEFT", INSET + TEXT_PAD, -HEADER - HEAD_PAD)
    f.summary:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(INSET + TEXT_PAD), -HEADER - HEAD_PAD)
    Parts.HudFont(f.summary, g.font, SUMMARY_SIZE, g.outline)
    Parts.HudFont(f.title, g.font, g.titleSize, g.outline)
    Parts.HudFont(f.lowerTitle, g.font, g.titleSize, g.outline)
    Parts.HudFont(f.time, g.font, g.timeSize, g.outline)
    f.time:SetWidth(Look.TimeWidth())
    f.lowerTitle:ClearAllPoints()
    f.lowerTitle:SetPoint("LEFT", TITLE_X + g.titleX, g.titleY); f.lowerTitle:SetPoint("RIGHT", -TITLE_X, g.titleY)
    f.lowerTitle:SetJustifyH("LEFT")
end

-- The picture behind the rows: stretched over the window, or repeated with each repeat tileSize wide.
-- The repeat is worked out here from the window's size, since a picture's own size is not known.
local function LayImage(f, g, w, h)
    local path = ImagePath(g.image, g.path)
    f.image:SetShown(path ~= nil)
    if not path then
        f.imageKey = nil
        return
    end
    local key = table.concat({ path, g.tileSize, g.tile and w or 0, g.tile and h or 0 }, "|")
    if f.imageKey == key then return end
    f.imageKey = key
    if g.tile then
        f.image:SetTexture(path, "REPEAT", "REPEAT")
        f.image:SetTexCoord(0, w / g.tileSize, 0, h / g.tileSize)
    else
        f.image:SetTexture(path)
        f.image:SetTexCoord(0, 1, 0, 1)
    end
end

-- The window's own colors: the frame, the title bar and its texts.
local function PaintFrame(f)
    local window, header, border = Look.Color("windowColor"), Look.Color("headerColor"), Look.Color("borderColor")
    local title, time, rank = Look.Color("titleColor"), Look.Color("timeColor"), Look.Color("rankColor")
    local summary = Look.Color("summaryColor")
    local alpha = S.Get("backgroundAlpha")
    f.summary:SetTextColor(summary.r, summary.g, summary.b)
    f.image:SetAlpha(S.Get("imageAlpha"))
    f.background:SetColorTexture(window.r, window.g, window.b, 1)
    f.background:SetAlpha(alpha)
    f.headerBackground:SetColorTexture(header.r, header.g, header.b, 1)
    f.lowerBackground:SetColorTexture(header.r, header.g, header.b, 1)
    f.border:SetColor(border.r, border.g, border.b, 1)
    f.border._frame:SetShown(S.Get("showBorder"))
    f.border._frame:SetAlpha(alpha)
    f.title:SetTextColor(title.r, title.g, title.b)
    f.lowerTitle:SetTextColor(title.r, title.g, title.b)
    f.time:SetTextColor(time.r, time.g, time.b)
    for _, pane in ipairs(f.panes) do pane.empty:SetTextColor(rank.r, rank.g, rank.b) end
end

-- Lays out one pane's columns, titles and the rows that fit; returns how many rows are shown.
local function LayPane(pane, mode, total, first, capacity, g, key, headY)
    local a, b = Columns(pane, mode)
    pane.columns = (a and 1 or 0) + (b and 1 or 0)
    pane.valueWidth = pane.columns == 0 and 0 or pane.columns * g.colWidth + (pane.columns - 1) * COL_GAP
    first = math.max(0, math.min(first, total - capacity))
    local shown = math.min(total - first, capacity)
    local paneKey = key .. "|" .. pane.columns .. "|" .. pane.top
    local fresh = pane.laidKey ~= paneKey
    if fresh then
        LayHeads(pane, g, headY)
        pane.empty:ClearAllPoints()
        pane.empty:SetPoint("TOP", pane.f, "TOPLEFT", g.w / 2, -pane.top - INSET)
    end
    pane.headName:SetText(TEXT_NAME_HEAD)
    if a then pane.headA:SetText(ColumnTitle(mode, a)) end
    if b then pane.headB:SetText(ColumnTitle(mode, b)) end
    local rows = pane.rows
    for i = 1, shown do
        local row = rows[i] or Look.Row(pane, i)
        if fresh or row.laidKey ~= paneKey then
            LayRow(row, pane, i, g)
            row.laidKey = paneKey
        end
        row:Show()
    end
    pane.laidKey = paneKey
    for i = shown + 1, #rows do rows[i]:Hide() end
    return shown, first
end

-- Sizes the window and lays the first pane's rows that fit; returns how many are shown and the first
-- one's index. With a second list (f.lowerOn) the rows are shared between the panes, the first taking the
-- larger half.
function Look.Layout(f, total, first, bh, gap, fontSize, mode)
    local w = math.max(C.MIN_WIDTH, S.Get(Key("width", f.index)))
    local minHeight = math.max(C.MIN_HEIGHT, HEADER + 2 * INSET + bh)
    local h = math.max(minHeight, S.Get(Key("height", f.index)))
    if not f.sizing then f:SetSize(w, h) else w, h = f:GetWidth(), f:GetHeight() end
    local showHead, showSummary = S.Get("showColumnHeaders") == true, S.Get("showSummary") == true
    local headTop = HEADER + (showSummary and SUMMARY_H or 0)
    local top = headTop + (showHead and COLUMN_HEAD or 0)
    local lower = f.lowerOn == true
    local strip = LOWER_STRIP + (showHead and COLUMN_HEAD or 0)
    local capacity = Look.Capacity(h, bh, gap, top)
    local n1, n2 = capacity, 0
    if lower then
        local both = math.max(2, math.floor((h - top - 3 * INSET - strip - LOWER_GAP + 2 * gap) / (bh + gap)))
        n1 = math.ceil(both / 2)
        n2 = both - n1
    end
    local chars = S.Get("numberUnits") == "full" and COL_CHARS_FULL or COL_CHARS
    PaintFrame(f)
    local name, value, rank = Look.Color("nameColor"), Look.Color("valueColor"), Look.Color("rankColor")
    local column = Look.Color("columnColor")
    f.nameColor, f.valueColor, f.rankColor, f.columnColor = name, value, rank, column
    local g = f.geo or {}
    f.geo = g
    g.w, g.bh, g.gap, g.headTop, g.fontSize = w, bh, gap, headTop, fontSize
    g.showRanks, g.showIcons, g.showHead = S.Get("showRanks"), S.Get("showIcons"), showHead
    g.colWidth = math.floor(chars * CHAR_W * fontSize)
    g.texture, g.font, g.outline = S.Get("texture"), S.Get("font"), S.Get("outline")
    g.titleSize, g.timeSize = S.Get("titleSize"), S.Get("timeSize")
    g.titleX, g.titleY = S.Get("titleX"), S.Get("titleY")
    g.image, g.path, g.tile = S.Get("backgroundImage"), S.Get("backgroundPath"), S.Get("imageTile") == true
    g.tileSize = math.max(C.MIN_TILE, S.Get("imageTileSize"))
    g.n1, g.n2 = n1, n2
    g.lowerTop = top + INSET + (n1 * bh + (n1 - 1) * gap) + LOWER_GAP
    local key = table.concat({ w, h, bh, gap, fontSize, tostring(g.showRanks), tostring(g.showIcons), tostring(showHead),
        headTop, g.titleSize, g.timeSize, g.titleX, g.titleY, g.colWidth, g.texture, g.font, g.outline, name.r, name.g,
        name.b, value.r, value.g, value.b, rank.r, rank.g, rank.b, column.r, column.g, column.b }, "|")
    g.key = key
    if f.laidKey ~= key then LayFrame(f, g) end
    f.laidKey = key
    LayImage(f, g, w, h)
    local pane = f.panes[1]
    pane.top = top
    return LayPane(pane, mode, total, first, n1, g, key, -headTop - HEAD_PAD)
end

-- The second pane: the list under the first, with a title strip of its own. Returns how many rows are
-- shown and the first one's index.
function Look.LayoutLower(f, total, first, mode)
    local g, pane = f.geo, f.panes[2]
    local strip = f.lowerBar
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -g.lowerTop)
    strip:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -g.lowerTop)
    strip:Show()
    f.lowerTitle:SetText(mode.label)
    pane.top = g.lowerTop + LOWER_STRIP + (g.showHead and COLUMN_HEAD or 0)
    return LayPane(pane, mode, total, first, g.n2, g, g.key, -g.lowerTop - LOWER_STRIP - HEAD_PAD)
end

-- The second pane is off: its strip, titles and rows go.
function Look.HideLower(f)
    local pane = f.panes[2]
    f.lowerBar:Hide()
    pane.headName:Hide(); pane.headA:Hide(); pane.headB:Hide(); pane.empty:Hide()
    for _, row in ipairs(pane.rows) do row:Hide() end
    pane.laidKey = nil
end

local function ValueOf(source, kind)
    if kind == "rate" then return source.amountPerSecond end
    return source.totalAmount
end

local function PaintValues(row, source, cols)
    if cols.a then row.colA:SetText(Format(ValueOf(source, cols.a))) end
    if cols.b then row.colB:SetText(Format(ValueOf(source, cols.b))) end
end

-- The line under the title bar: the session's name, its total, the raid's per-second figure once both
-- are plain numbers, and where you stand. The total is secret in combat and goes in as a string.
function Look.PaintSummary(f, session, mode, name, seconds)
    local format, args = "%s", { name }
    format = format .. SUMMARY_GAP .. (mode.total or TEXT_TOTAL) .. " %s"
    args[#args + 1] = Format(session.totalAmount)
    local rate = mode.rate and DM.PerSecond(session.totalAmount, seconds)
    if rate then
        format = format .. SUMMARY_GAP .. TEXT_RAID:format(mode.perSecond or TEXT_RATE) .. " %s"
        args[#args + 1] = Format(rate)
    end
    local rank, count = DM.Rank(session)
    if rank then
        format = format .. SUMMARY_GAP .. TEXT_RANK:format(rank, count)
    end
    f.summary:SetFormattedText(format, unpack(args))
end

local function PaintPane(pane, session, first, shown, mode, available)
    local sources = session.combatSources
    local alpha = S.Get("barAlpha")
    local own = S.Get("highlightPlayer")
    local classOnly = S.Get("iconStyle") == "class"
    pane.empty:SetText(available and TEXT_EMPTY or TEXT_UNAVAILABLE)
    pane.empty:SetShown(shown == 0)
    for i = 1, shown do
        local source, row = sources[first + i], pane.rows[i]
        local c = Look.BarColor(source)
        row.source, row.modeKey = source, mode.key
        row:SetStatusBarColor(c.r, c.g, c.b, alpha)
        row:SetMinMaxValues(0, session.maxAmount)
        row:SetValue(source.totalAmount)
        local e = own and source.isLocalPlayer == true and Look.EdgeColor(source) or c
        row.edge:SetColorTexture(e.r, e.g, e.b, 1)
        row.rank:SetFormattedText(RANK_TEXT, session.rank or first + i)
        row.icon:SetTexture(IconOf(source, classOnly))
        row.name:SetText(DM.DisplayName(source))
        PaintValues(row, source, pane.cols)
    end
end

function Look.Paint(f, session, first, shown, mode, available)
    PaintPane(f.panes[1], session, first, shown, mode, available)
end

function Look.PaintLower(f, session, first, shown, mode, available)
    PaintPane(f.panes[2], session, first, shown, mode, available)
end

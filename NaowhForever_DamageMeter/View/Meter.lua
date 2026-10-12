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
local ICON_MAX, ICON_PAD = 28, 4
local INSET, HEADER, COLUMN_HEAD = C.INSET, C.HEADER, C.COLUMN_HEAD
local SUMMARY_H, TIME_CHARS, LOWER_STRIP, LOWER_GAP = C.SUMMARY_H, 7, C.LOWER_STRIP, C.LOWER_GAP
local NAME_GAP, TRACK_ALPHA = 6, 0.6
local RANK_W, RANK_SIZE = 18, 10
local COL_CHARS, COL_CHARS_FULL, CHAR_W = 7, 10, 0.62
-- Every cell a row can have beside its name: A the first figure, B the second (or the only one, or both with a
-- divider), P the share, and X1 to X5 the totals of other lists. A cell is the row's colA, colB, ... and its
-- title the pane's headA, headB, ...
local CELLS = { "A", "B", "P", "X1", "X2", "X3", "X4", "X5" }
local PERCENT_CHARS, DIVIDER_CHARS = 6, 3
local FIT_PAD = 2
local EMPTY_SIZE = 12
local TITLE_X = C.TITLE_X
local TITLE_SIZE, TIME_SIZE, HEAD_SIZE, HEAD_PAD, SUMMARY_SIZE = 12, 11, 10, 3, 11

local TEXT_EMPTY = "No data yet"
local TEXT_UNAVAILABLE = "The damage meter is not available"
local TEXT_NAME_HEAD, TEXT_TOTAL, TEXT_RATE, TEXT_PERCENT_HEAD = "Name", "Total", "Per Sec", "%"
local DIVIDED_TEXT, TEXT_YOU = "%s | %s", "You"
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
    if source.icon ~= nil then return source.icon end
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
function Look.BarColor(source, index)
    if source.color then return source.color end
    if source.isLocalPlayer == true then
        local style = S.Get("ownBarStyle")
        if style == "custom" then return Look.Color("ownBarColor") end
        if style == "class" then return ClassColor(source.classFilename) end
    end
    local choice = DM.Setting(index, "barColor")
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

-- The size a text has when it has none of its own (the names' and the figures' follow the window's), and
-- the key of the size it can have of its own.
local DEFAULT_SIZES = { rank = 10, title = 12, time = 11, summary = 11, head = 10 }
local OWN_SIZES = { value = "valueFontSize", rank = "rankSize", title = "titleSize", time = "timeSize",
    summary = "summarySize", head = "headSize" }

-- The font, outline and size of one of the texts (name, value, rank, title, time, summary, head): its
-- own when the settings give it its own, else the window's. nameSize is the names' size.
function Look.TextStyle(element, nameSize)
    local font, outline = S.Get("font"), S.Get("outline")
    if S.Get(element .. "OwnFont") == true then font, outline = S.Get(element .. "Font"), S.Get(element .. "Outline") end
    local size = DEFAULT_SIZES[element] or nameSize
    if OWN_SIZES[element] and S.Get(element .. "OwnSize") == true then
        local own = S.Get(OWN_SIZES[element])
        if type(own) == "number" and own > 0 then size = own end
    end
    return font, outline, size
end

-- Throws away what the layout kept, so that the next paint does all of it again.
function Look.Invalidate(f)
    f.laidKey = nil
    for _, pane in ipairs(f.panes) do
        pane.laidKey = nil
        for _, row in ipairs(pane.rows) do row.laidKey = nil end
    end
end

-- How tall a window's bars are: the Row Height, and at least as tall as an icon of its own size, so that a
-- big icon is not taller than the bar it sits on.
function Look.BarHeight(index)
    local height = DM.Setting(index, "barHeight")
    local icon = S.Get("iconSize")
    if DM.Setting(index, "showIcons") == true and icon > 0 then
        height = math.max(height, math.min(icon, C.MAX_ICON))
    end
    return height
end

-- How wide the fight time is at the size the settings give it.
function Look.TimeWidth()
    local chars = TIME_CHARS + (S.Get("timeBrackets") == true and 2 or 0)
    local _, _, size = Look.TextStyle("time", S.Get("fontSize"))
    return math.ceil(chars * CHAR_W * size)
end

-- A pane is a list of rows with its column titles. A window has one, and a second below it on request.
local function NewPane(f, n)
    local pane = { f = f, n = n, rows = {}, cols = { x = {} }, order = {}, cells = {}, before = {}, after = {},
        beforeWidth = 0, afterWidth = 0, top = 0 }
    pane.headName = ns.Font(f, HEAD_SIZE, "OUTLINE", T.muted)
    pane.headName:SetJustifyH("LEFT"); pane.headName:SetWordWrap(false); pane.headName:SetText(TEXT_NAME_HEAD)
    for _, id in ipairs(CELLS) do
        local head = ns.Font(f, HEAD_SIZE, "OUTLINE", T.muted)
        head:SetJustifyH("RIGHT"); head:SetWordWrap(false)
        pane["head" .. id] = head
    end
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
    frame.headerRule = ns.Solid(frame.header, "OVERLAY", T.line, 1)
    frame.headerRule:SetPoint("BOTTOMLEFT"); frame.headerRule:SetPoint("BOTTOMRIGHT")
    frame.headerRule:SetHeight(1)
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
    row.track = row:CreateTexture(nil, "BACKGROUND")
    row.track:SetAllPoints()
    row.track:Hide()
    row.edge = row:CreateTexture(nil, "OVERLAY")
    row.edge:SetPoint("TOPLEFT"); row.edge:SetPoint("BOTTOMLEFT")
    row.rank = ns.Font(row, RANK_SIZE, "OUTLINE", T.muted)
    row.icon = row:CreateTexture(nil, "OVERLAY")
    for _, id in ipairs(CELLS) do
        local cell = ns.Font(row, C.MIN_FONT, "OUTLINE", T.fg)
        cell:SetJustifyH("RIGHT"); cell:SetWordWrap(false)
        row["col" .. id] = cell
    end
    row.name = ns.Font(row, C.MIN_FONT, "OUTLINE", T.fg)
    row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
    pane.rows[i] = row
    return row
end

-- How many rows fit under a title bar and the column titles of height top.
function Look.Capacity(h, bh, gap, top)
    return math.max(1, math.floor((h - (top or HEADER) - 2 * INSET + gap) / (bh + gap)))
end

-- Which cell of a row takes which kind of column, from the window's `columns` setting. pane.order lists N,
-- the name, and the cells in the order they stand, left to right; pane.before and pane.after the cells on
-- each side of the name. pane.cols says what the cells show: a and b the kinds of the two figures (b alone
-- when there is one), merged when both are one text, p the share, x the list each X cell takes its total from.
local function Columns(pane, mode)
    local f = pane.f
    local slots = DM.ColumnSlots(DM.Setting(f.index, "columns"), mode)
    local figures, extras, order = {}, {}, {}
    for _, kind in ipairs(slots) do
        if kind == "name" then
            order[#order + 1] = "N"
        elseif kind == "total" or (kind == "rate" and mode.rate) then
            figures[#figures + 1] = kind
            order[#order + 1] = "F" .. #figures
        elseif kind == "percent" and mode.percent ~= false then
            order[#order + 1] = "P"
        elseif C.COLUMN_EXTRAS[kind] and not f.detail then
            extras[#extras + 1] = kind
            order[#order + 1] = "X" .. #extras
        end
    end
    local cols = pane.cols
    local two = #figures == 2
    cols.a, cols.b = two and figures[1] or nil, figures[two and 2 or 1]
    cols.merged = two and DM.Setting(f.index, "showDivider") == true
    cols.p, cols.x = false, {}
    pane.order, pane.cells, pane.before, pane.after = {}, {}, {}, {}
    local side = pane.before
    for _, id in ipairs(order) do
        if id == "F1" then
            id = (two and not cols.merged) and "A" or "B"
        elseif id == "F2" then
            id = not cols.merged and "B" or nil
        end
        if id ~= nil then
            pane.order[#pane.order + 1] = id
            if id == "N" then
                side = pane.after
            else
                pane.cells[#pane.cells + 1] = id
                side[#side + 1] = id
                if id == "P" then
                    cols.p = true
                elseif id:sub(1, 1) == "X" then
                    cols.x[id] = extras[tonumber(id:sub(2))]
                end
            end
        end
    end
end

-- The width of a column of figures: what its texts need once they are known (pane.fit), else what the
-- longest figure of the settings would need.
local function CellWidth(g, pane, cell)
    local fit = pane.fit and pane.fit[cell]
    if fit then return fit end
    if cell == "P" then return g.pctWidth end
    if cell == "B" and pane.cols.merged then return g.mergedWidth end
    return g.colWidth
end

-- How much room cells take: their widths, and the gaps between them.
local function GroupWidth(cells, pane, g)
    local width = 0
    for k, cell in ipairs(cells) do
        width = width + CellWidth(g, pane, cell) + (k > 1 and g.colGap or 0)
    end
    return width
end

-- The room the cells before the name take, with the gap that keeps the name from them, and the room the cells
-- after it take.
local function Measure(pane, g)
    pane.beforeWidth = #pane.before > 0 and GroupWidth(pane.before, pane, g) + NAME_GAP or 0
    pane.afterWidth = GroupWidth(pane.after, pane, g)
end

-- Puts a row's rank, icon and name in the room the cells leave: from after the cells before the name to before
-- the cells after it.
local function PlaceName(row, pane, g)
    local left = g.textPad + pane.beforeWidth
    row.rank:ClearAllPoints(); row.rank:SetPoint("LEFT", left, 0); row.rank:SetWidth(g.rankWidth)
    if g.showRanks then left = left + g.rankWidth end
    row.icon:ClearAllPoints()
    if g.iconSide == "right" then
        row.icon:SetPoint("RIGHT", -g.textPad, 0)
    elseif g.iconSide == "before" then
        row.icon:SetPoint("RIGHT", row, "LEFT", 0, 0)
    else
        row.icon:SetPoint("LEFT", left, 0)
        if g.showIcons then left = left + g.iconSize + g.iconGap end
    end
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", left, 0)
    row.name:SetPoint("RIGHT", -g.rightInset - pane.afterWidth - NAME_GAP, 0)
end

-- Sets a row's cells to the widths of their columns, and its name to the room they leave.
local function SizeCells(row, pane, g)
    for _, cell in ipairs(pane.cells) do
        row["col" .. cell]:SetWidth(CellWidth(g, pane, cell))
    end
    PlaceName(row, pane, g)
end

local function ColumnTitle(mode, kind)
    if kind == "rate" then return mode.perSecond or TEXT_RATE end
    return mode.total or TEXT_TOTAL
end

-- The words over a cell: the title of the figure it has, both with a divider, the share, or the other list.
local function HeadText(pane, mode, id)
    local cols = pane.cols
    if id == "P" then return TEXT_PERCENT_HEAD end
    if id == "A" then return ColumnTitle(mode, cols.a) end
    if id == "B" then
        if cols.merged then return DIVIDED_TEXT:format(ColumnTitle(mode, cols.a), ColumnTitle(mode, cols.b)) end
        return ColumnTitle(mode, cols.b)
    end
    return DM.Mode(cols.x[id]).total or TEXT_TOTAL
end

local function LayRow(row, pane, i, g)
    local f = pane.f
    row:ClearAllPoints()
    local slot = i - 1
    if g.growUp then slot = pane.capacity - i end
    row:SetPoint("TOPLEFT", f, "TOPLEFT", INSET + g.iconOutside, -pane.top - INSET - slot * (g.bh + g.gap))
    row:SetSize(g.w - 2 * INSET - g.iconOutside, g.bh)
    row:SetReverseFill(g.reverseFill)
    row:SetStatusBarTexture(UI.TexturePath(g.texture, GRADIENT_TEX))
    row.edge:SetWidth(g.edgeWidth)
    row.track:SetColorTexture(f.trackColor.r, f.trackColor.g, f.trackColor.b, TRACK_ALPHA)
    row.rank:SetShown(g.showRanks)
    row.rank:SetTextColor(f.rankColor.r, f.rankColor.g, f.rankColor.b)
    row.name:SetTextColor(f.nameColor.r, f.nameColor.g, f.nameColor.b)
    row.icon:SetSize(g.iconSize, g.iconSize)
    row.icon:SetTexCoord(g.iconCrop, 1 - g.iconCrop, g.iconCrop, 1 - g.iconCrop)
    row.icon:SetShown(g.showIcons)
    for _, id in ipairs(CELLS) do
        local cell = row["col" .. id]
        cell:SetTextColor(f.valueColor.r, f.valueColor.g, f.valueColor.b)
        cell:SetShown(false)
    end
    -- The cells before the name from the left end, each to the right of the one before; the cells after it
    -- from the right end, each to the left of the one after.
    local before
    for _, id in ipairs(pane.before) do
        local cell = row["col" .. id]
        cell:ClearAllPoints()
        if before then
            cell:SetPoint("LEFT", before, "RIGHT", g.colGap, 0)
        else
            cell:SetPoint("LEFT", g.textPad, 0)
        end
        cell:SetShown(true)
        before = cell
    end
    local after
    for k = #pane.after, 1, -1 do
        local cell = row["col" .. pane.after[k]]
        cell:ClearAllPoints()
        if after then
            cell:SetPoint("RIGHT", after, "LEFT", -g.colGap, 0)
        else
            cell:SetPoint("RIGHT", -g.rightInset, 0)
        end
        cell:SetShown(true)
        after = cell
    end
    SizeCells(row, pane, g)
    Parts.HudFont(row.rank, g.rankFont, g.rankSize, g.rankOutline)
    Parts.HudFont(row.name, g.nameFont, g.fontSize, g.nameOutline)
    for _, id in ipairs(CELLS) do
        Parts.HudFont(row["col" .. id], g.valueFont, g.valueSize, g.valueOutline)
    end
end

-- The column titles above a pane's rows at y: Name, and a title over each value column. A title is put
-- by its right end, at the right end of its column, and is as wide as its words, so that a long one is
-- not cut and sits on the line of the others.
local function LayHeads(pane, g, y)
    local f = pane.f
    local show = g.showHead
    pane.headName:SetShown(show)
    for _, id in ipairs(CELLS) do pane["head" .. id]:SetShown(false) end
    if not show then return end
    local edge = -(INSET + g.rightInset)
    for k = #pane.after, 1, -1 do
        local id = pane.after[k]
        local fs = pane["head" .. id]
        fs:ClearAllPoints()
        fs:SetPoint("TOPRIGHT", f, "TOPRIGHT", edge, y)
        fs:SetShown(true)
        edge = edge - CellWidth(g, pane, id) - g.colGap
    end
    local x = INSET + g.iconOutside + g.textPad
    for _, id in ipairs(pane.before) do
        local fs = pane["head" .. id]
        x = x + CellWidth(g, pane, id)
        fs:ClearAllPoints()
        fs:SetPoint("TOPRIGHT", f, "TOPLEFT", x, y)
        fs:SetShown(true)
        x = x + g.colGap
    end
    pane.headName:ClearAllPoints()
    pane.headName:SetPoint("TOPLEFT", f, "TOPLEFT",
        INSET + g.iconOutside + g.textPad + pane.beforeWidth + (g.showRanks and g.rankWidth or 0), y)
    Parts.HudFont(pane.headName, g.headFont, g.headSize, g.headOutline)
    pane.headName:SetTextColor(f.columnColor.r, f.columnColor.g, f.columnColor.b)
    for _, id in ipairs(CELLS) do
        local fs = pane["head" .. id]
        Parts.HudFont(fs, g.headFont, g.headSize, g.headOutline)
        fs:SetTextColor(f.columnColor.r, f.columnColor.g, f.columnColor.b)
    end
end

-- The parts of the window outside the panes: the summary line, the title and the time, the image.
local function LayFrame(f, g)
    f.summary:ClearAllPoints()
    f.summary:SetPoint("TOPLEFT", f, "TOPLEFT", INSET + g.textPad, -HEADER - HEAD_PAD)
    f.summary:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(INSET + g.textPad), -HEADER - HEAD_PAD)
    Parts.HudFont(f.summary, g.summaryFont, g.summarySize, g.summaryOutline)
    Parts.HudFont(f.title, g.titleFont, g.titleSize, g.titleOutline)
    Parts.HudFont(f.lowerTitle, g.titleFont, g.titleSize, g.titleOutline)
    Parts.HudFont(f.time, g.timeFont, g.timeSize, g.timeOutline)
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
    local alpha = DM.Setting(f.index, "backgroundAlpha")
    f.summary:SetTextColor(summary.r, summary.g, summary.b)
    f.image:SetAlpha(S.Get("imageAlpha"))
    f.background:SetColorTexture(window.r, window.g, window.b, 1)
    f.background:SetAlpha(alpha)
    local headerAlpha = DM.Setting(f.index, "headerAlpha")
    f.headerBackground:SetColorTexture(header.r, header.g, header.b, 1)
    f.headerBackground:SetAlpha(headerAlpha)
    f.lowerBackground:SetColorTexture(header.r, header.g, header.b, 1)
    f.lowerBackground:SetAlpha(headerAlpha)
    f.headerRule:SetAlpha(headerAlpha)
    f.border:SetColor(border.r, border.g, border.b, 1)
    f.border._frame:SetShown(DM.Setting(f.index, "showBorder"))
    f.border._frame:SetAlpha(alpha)
    f.title:SetTextColor(title.r, title.g, title.b)
    f.lowerTitle:SetTextColor(title.r, title.g, title.b)
    f.time:SetTextColor(time.r, time.g, time.b)
    for _, pane in ipairs(f.panes) do pane.empty:SetTextColor(rank.r, rank.g, rank.b) end
end

-- Lays out one pane's columns, titles and the rows that fit; returns how many rows are shown.
local function LayPane(pane, mode, total, first, capacity, g, key, headY)
    Columns(pane, mode)
    pane.capacity = capacity
    pane.merged = pane.cols.merged == true
    first = math.max(0, math.min(first, total - capacity))
    local shown = math.min(total - first, capacity)
    local paneKey = key .. "|" .. table.concat(pane.order, ",") .. "|" .. tostring(pane.merged) .. "|" .. capacity
        .. "|" .. pane.top
    local fresh = pane.laidKey ~= paneKey
    Measure(pane, g)
    pane.headY = headY
    if fresh then
        LayHeads(pane, g, headY)
        pane.empty:ClearAllPoints()
        pane.empty:SetPoint("TOP", pane.f, "TOPLEFT", g.w / 2, -pane.top - INSET)
    end
    pane.headName:SetText(TEXT_NAME_HEAD)
    for _, id in ipairs(pane.cells) do pane["head" .. id]:SetText(HeadText(pane, mode, id)) end
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
    local showHead, showSummary = DM.Setting(f.index, "showColumnHeaders") == true, S.Get("showSummary") == true
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
    g.showRanks = DM.Setting(f.index, "showRanks") and not f.detail
    g.showIcons, g.showHead = DM.Setting(f.index, "showIcons"), showHead
    g.textPad, g.iconGap, g.edgeWidth, g.colGap = S.Get("textPad"), S.Get("iconGap"), S.Get("edgeWidth"), S.Get("colGap")
    g.iconSide, g.iconCrop = S.Get("iconSide"), S.Get("iconZoom") / 100
    -- A size of its own is used as it is, even taller than the row. Fitted, an icon before the bar is the
    -- bar's height and touches it: the rows start after it.
    local iconSetting, before = S.Get("iconSize"), g.iconSide == "before"
    g.iconSize = iconSetting > 0 and math.min(iconSetting, C.MAX_ICON)
        or math.min(ICON_MAX, before and bh or bh - ICON_PAD)
    g.iconOutside = g.showIcons and before and g.iconSize or 0
    g.rightInset = g.textPad
    if g.showIcons and g.iconSide == "right" then g.rightInset = g.textPad + g.iconSize + g.iconGap end
    g.barTrack = S.Get("barTrack") == true
    f.trackColor = Look.Color("trackColor")
    for _, element in ipairs({ "name", "value", "rank", "title", "time", "summary", "head" }) do
        g[element .. "Font"], g[element .. "Outline"], g[element .. "Size"] = Look.TextStyle(element, fontSize)
    end
    g.fontSize = fontSize
    g.rankWidth = math.ceil(RANK_W * g.rankSize / RANK_SIZE)
    g.colWidth = math.floor(chars * CHAR_W * g.valueSize)
    g.pctWidth = math.floor(PERCENT_CHARS * CHAR_W * g.valueSize)
    g.mergedWidth = 2 * g.colWidth + math.floor(DIVIDER_CHARS * CHAR_W * g.valueSize)
    g.texture = S.Get("texture")
    g.titleX, g.titleY = S.Get("titleX"), S.Get("titleY")
    g.growUp, g.reverseFill = DM.Setting(f.index, "growUp") == true, S.Get("reverseFill") == true
    g.image, g.path, g.tile = S.Get("backgroundImage"), S.Get("backgroundPath"), S.Get("imageTile") == true
    g.tileSize = math.max(C.MIN_TILE, S.Get("imageTileSize"))
    g.n1, g.n2 = n1, n2
    g.lowerTop = top + INSET + (n1 * bh + (n1 - 1) * gap) + LOWER_GAP
    local key = table.concat({ w, h, bh, gap, fontSize, tostring(g.showRanks), tostring(g.showIcons), tostring(showHead),
        headTop, g.titleSize, g.timeSize, g.headSize, tostring(S.Get("timeBrackets")), g.titleX, g.titleY, tostring(g.growUp), tostring(g.reverseFill), g.summarySize, g.valueSize, g.rankSize, g.textPad, g.iconGap, g.edgeWidth,
        g.colGap, g.iconSide, g.iconCrop, g.iconSize, tostring(g.barTrack), f.trackColor.r, f.trackColor.g,
        f.trackColor.b, g.colWidth, g.texture, name.r, name.g,
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
    f.lowerTitle:SetText(DM.ModeLabel(mode))
    pane.top = g.lowerTop + LOWER_STRIP + (g.showHead and COLUMN_HEAD or 0)
    return LayPane(pane, mode, total, first, g.n2, g, g.key, -g.lowerTop - LOWER_STRIP - HEAD_PAD)
end

-- The second pane is off: its strip, titles and rows go.
function Look.HideLower(f)
    local pane = f.panes[2]
    f.lowerBar:Hide()
    pane.headName:Hide(); pane.empty:Hide()
    for _, id in ipairs(CELLS) do pane["head" .. id]:Hide() end
    for _, row in ipairs(pane.rows) do row:Hide() end
    pane.laidKey = nil
end

local function ValueOf(source, kind)
    if kind == "rate" then return source.amountPerSecond end
    return source.totalAmount
end

-- A figure in its column, or nothing when there is none: a spell's per-second figure is not known in combat.
-- suffix follows it ("/s" for a per-second figure, when the settings say so); the figure may be secret, so
-- the text is made by the client.
local function PaintValue(fs, value, suffix)
    if value == nil then
        fs:SetText("")
    elseif suffix ~= "" then
        fs:SetFormattedText("%s" .. suffix, Format(value))
    else
        fs:SetText(Format(value))
    end
end

-- The total another list has for a source: yours, or the one with the same guid. A guid the game keeps back
-- (in combat) finds nothing, so the cell is empty until the fight is over.
local function ExtraOf(lookup, source)
    if not lookup then return nil end
    local other = source.isLocalPlayer == true and lookup.own or nil
    local guid = source.sourceGUID
    if not other and DM.Plain(guid, "string") then other = lookup.byGuid[guid] end
    return other and other.totalAmount
end

-- The values of a row: the two figures, its share of the list's total once both are plain numbers, and the
-- totals of other lists.
local function PaintValues(row, source, cols, session, extras)
    local rate = DM.RateSuffix()
    local suffixA, suffixB = cols.a == "rate" and rate or "", cols.b == "rate" and rate or ""
    if cols.merged then
        local first, second = ValueOf(source, cols.a), ValueOf(source, cols.b)
        if first ~= nil and second ~= nil then
            row.colB:SetFormattedText("%s" .. suffixA .. " | %s" .. suffixB, Format(first), Format(second))
        elseif first ~= nil then
            PaintValue(row.colB, first, suffixA)
        else
            PaintValue(row.colB, second, suffixB)
        end
    else
        if cols.a then PaintValue(row.colA, ValueOf(source, cols.a), suffixA) end
        if cols.b then PaintValue(row.colB, ValueOf(source, cols.b), suffixB) end
    end
    if cols.p then
        local percent = source.noPercent ~= true and DM.Percent(source.totalAmount, session.totalAmount)
        row.colP:SetText(percent and DM.PercentText(percent) or "")
    end
    for id, kind in pairs(cols.x) do
        local value = ExtraOf(extras and extras[kind], source)
        row["col" .. id]:SetText(DM.Plain(value, "number") and Format(value) or "")
    end
end

-- The lists the columns of other lists take their totals from, read as they are asked for: { own, byGuid }
-- for each, which is a player's row in it, yours or by guid.
function Look.Extras(sessionKey, fightID)
    return setmetatable({}, { __index = function(lookups, kind)
        local lookup = { byGuid = {} }
        for _, source in ipairs(DM.Session(kind, sessionKey, fightID).combatSources) do
            if source.isLocalPlayer == true then lookup.own = source end
            local guid = source.sourceGUID
            if DM.Plain(guid, "string") then lookup.byGuid[guid] = source end
        end
        lookups[kind] = lookup
        return lookup
    end })
end

-- The line under the title bar, from the pieces the settings keep: the session's name, its total, the
-- raid's per-second figure once both are plain numbers, and where you stand. The total is secret in
-- combat and goes in as a string.
function Look.PaintSummary(f, session, mode, name, seconds)
    local parts, args = {}, {}
    if S.Get("summaryName") ~= false then
        parts[#parts + 1] = "%s"
        args[#args + 1] = name
    end
    if S.Get("summaryTotal") ~= false then
        parts[#parts + 1] = (mode.total or TEXT_TOTAL) .. " %s"
        args[#args + 1] = Format(session.totalAmount)
    end
    local rate = S.Get("summaryRate") ~= false and mode.rate and DM.PerSecond(session.totalAmount, seconds)
    if rate then
        parts[#parts + 1] = TEXT_RAID:format(mode.perSecond or TEXT_RATE) .. " %s"
        args[#args + 1] = Format(rate)
    end
    local rank, count = DM.Rank(session)
    if rank and S.Get("summaryRank") ~= false then
        parts[#parts + 1] = TEXT_RANK:format(rank, count)
    end
    f.summary:SetFormattedText(table.concat(parts, SUMMARY_GAP), unpack(args))
end

-- A line that heads a section, such as Targets: its words, and no bar or figures.
local function PaintHeading(row, source, f)
    row:SetMinMaxValues(0, 1)
    row:SetValue(0)
    row.edge:SetColorTexture(0, 0, 0, 0)
    row.track:Hide()
    row.rank:SetText("")
    row.icon:Hide()
    row.name:SetText(source.label)
    row.name:SetTextColor(f.columnColor.r, f.columnColor.g, f.columnColor.b)
    for _, id in ipairs(CELLS) do row["col" .. id]:SetText("") end
end

-- A cut of text to letters characters, with ... after it.
local function Truncate(text, letters)
    local count, position = 0, 1
    for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > letters then return text:sub(1, position - 1) .. "..." end
        position = position + #char
    end
    return text
end

-- What a row calls its source: You for your own when the settings say so, the name as written, cut to the
-- letters allowed when it is a plain text (a name the game keeps back goes as it is).
local function NameOf(source, you, letters)
    if you and source.isLocalPlayer == true then return TEXT_YOU end
    local name = DM.DisplayName(source)
    if letters > 0 and DM.Plain(name, "string") then name = Truncate(name, letters) end
    return name
end

-- Whether a source's figures are known to the addon, which is when they can be measured.
local function Known(source)
    return DM.Plain(source.totalAmount, "number")
        and (source.amountPerSecond == nil or DM.Plain(source.amountPerSecond, "number"))
end

-- Sizes the columns of figures to the widest text in each, so that the name has the room they leave. A
-- figure the game keeps back (in combat) cannot be measured, and its columns keep the width the settings'
-- longest figure needs; a share is always known. plain is whether every figure shown is known.
local function FitColumns(pane, shown, plain)
    local g = pane.f.geo
    local ruler = pane.ruler
    if not ruler then
        ruler = ns.Font(pane.f, g.valueSize, g.valueOutline, T.fg)
        pane.ruler = ruler
    end
    if pane.rulerKey ~= g.key then
        Parts.HudFont(ruler, g.valueFont, g.valueSize, g.valueOutline)
        pane.rulerKey = g.key
    end
    local fit
    for _, cell in ipairs(pane.cells) do
        if (cell ~= "A" and cell ~= "B") or plain then
            local widest = 0
            for i = 1, shown do
                local text = pane.rows[i]["col" .. cell]:GetText()
                if text and text ~= "" then
                    ruler:SetText(text)
                    widest = math.max(widest, ruler:GetStringWidth())
                end
            end
            if widest > 0 then
                fit = fit or {}
                fit[cell] = math.ceil(widest) + FIT_PAD
            end
        end
    end
    local changed = false
    for _, cell in ipairs(CELLS) do
        if (fit and fit[cell]) ~= (pane.fit and pane.fit[cell]) then changed = true end
    end
    if not changed then return end
    pane.fit = fit
    Measure(pane, g)
    LayHeads(pane, g, pane.headY)
    for _, row in ipairs(pane.rows) do
        if row.laidKey then SizeCells(row, pane, g) end
    end
end

local function PaintPane(pane, session, first, shown, mode, available, extras)
    local sources = session.combatSources
    local you, letters = S.Get("youLabel") == true, S.Get("nameMaxLetters")
    local classNames, classValues = S.Get("nameClassColor") == true, S.Get("valueClassColor") == true
    local alpha = DM.Setting(pane.f.index, "barAlpha")
    local own = S.Get("highlightPlayer")
    local classOnly = S.Get("iconStyle") == "class"
    local byTotal = S.Get("barScale") == "total"
    local f, showIcons = pane.f, pane.f.geo.showIcons
    local plain = true
    pane.empty:SetText(session.emptyText or (available and TEXT_EMPTY or TEXT_UNAVAILABLE))
    pane.empty:SetShown(shown == 0)
    -- With Always Show My Row, the last row is yours when yours is not among the rows shown.
    local pinned
    if S.Get("pinSelf") == true and shown >= 1 then
        local rank = DM.Rank(session)
        if rank and (rank <= first or rank > first + shown) then pinned = rank end
    end
    for i = 1, shown do
        local index = first + i
        if pinned and i == shown then index = pinned end
        local source, row = sources[index], pane.rows[i]
        row.source, row.modeKey = source, mode.key
        if source.isHeader then
            PaintHeading(row, source, f)
        else
            if not Known(source) then plain = false end
            local c = Look.BarColor(source, f.index)
            row:SetStatusBarColor(c.r, c.g, c.b, alpha)
            row:SetMinMaxValues(0, source.maxAmount or (byTotal and session.totalAmount or session.maxAmount))
            row:SetValue(source.totalAmount)
            local e = own and source.isLocalPlayer == true and Look.EdgeColor(source) or c
            row.edge:SetColorTexture(e.r, e.g, e.b, 1)
            row.track:SetShown(f.geo.barTrack)
            row.rank:SetFormattedText(RANK_TEXT, session.rank or index)
            row.icon:SetTexture(IconOf(source, classOnly))
            row.icon:SetShown(showIcons and source.noIcon ~= true)
            row.name:SetText(source.label or NameOf(source, you, letters))
            local tint = f.nameColor
            if classNames and not source.label then tint = ClassColor(source.classFilename) end
            row.name:SetTextColor(tint.r, tint.g, tint.b)
            tint = f.valueColor
            if classValues and not source.label then tint = ClassColor(source.classFilename) end
            for _, id in ipairs(pane.cells) do row["col" .. id]:SetTextColor(tint.r, tint.g, tint.b) end
            PaintValues(row, source, pane.cols, session, extras)
        end
    end
    FitColumns(pane, shown, plain)
end

function Look.Paint(f, session, first, shown, mode, available, extras)
    PaintPane(f.panes[1], session, first, shown, mode, available, extras)
end

function Look.PaintLower(f, session, first, shown, mode, available, extras)
    PaintPane(f.panes[2], session, first, shown, mode, available, extras)
end

-- Window.lua: RestedXP's guide in one Naowh window: its progress, the active step and the steps after it.
local ns = _G.NaowhForever
local F = ns.FEATURES.account
local Safe = ns.RXPSafe
local Has, Dig, Quiet, Guarded = Safe.Has, Safe.Dig, Safe.Quiet, Safe.Guarded

local WINDOW_NAME = "NaowhRXPWindow"
local STRATA = "MEDIUM"
local WIDTH_MIN, WIDTH_MAX, WIDTH_STEP, DEFAULT_WIDTH = 260, 640, 10, 380
local SCALE_MIN, SCALE_MAX, SCALE_STEP, DEFAULT_SCALE = 60, 200, 5, 100
local STEPS_MIN, STEPS_MAX, DEFAULT_STEPS = 0, 12, 6
local ACTIVE_SHOWN = 3
local PERCENT, ROUND, CHANNEL_MAX = 100, 0.5, 255
local PAD, GAP, BOX_PAD, HEAD_H, FOLD_W, PROGRESS_W = 10, 5, 7, 26, 16, 120
local BAR_W, ICON_W, LIST_H, MENU_SIZE = 2, 18, 18, 22
local FONT_HEAD, FONT_TEXT, FONT_LIST = 16, 13, 12
local EDGE_ALPHA, BOX_ALPHA, RULE_ALPHA, MUTED_ALPHA = 0.8, 0.55, 0.5, 0.9
local SHADOW, SHADOW_ALPHA = 1, 0.9
local GOLD = { r = 1, g = 0.82, b = 0 }
local TEXT_FOLD, TEXT_UNFOLD, TEXT_DOT = "-", "+", " \194\183 "
local MENU_ICON = "Interface\\ChatFrame\\UI-ChatIcon-Chat-Up"
local TEXT_STEP = "Step %d"
local TEXT_SKIP = "Skip step"
local HOME = { "LEFT", "LEFT", 0, 35 }
local DRAG_BUTTON, TIP_ANCHOR = "LeftButton", "ANCHOR_TOP"

local window, active, started, pending
local pool, used = { box = {}, row = {}, line = {} }, { box = 0, row = 0, line = 0 }
local silenced = setmetatable({}, { __mode = "k" })
local watched = setmetatable({}, { __mode = "k" })
local Draw

local function Settings()
    return ns.AccountSettings()
end

local function Snap(value, lo, hi, step)
    return math.min(hi, math.max(lo, math.floor(value / step + ROUND) * step))
end

function ns.RXPWindowEnabled()
    local on = ns.AccountSettings().rxpWindow
    if on == nil then return F.rxpWindow end
    return on == true
end

function ns.RXPWindowWidthRange() return WIDTH_MIN, WIDTH_MAX, WIDTH_STEP end

function ns.RXPWindowStepsRange() return STEPS_MIN, STEPS_MAX, 1 end

function ns.RXPWindowScaleRange() return SCALE_MIN, SCALE_MAX, SCALE_STEP end

function ns.RXPWindowScale()
    local scale = tonumber(Settings().rxpWindowScale)
    return scale and Snap(scale, SCALE_MIN, SCALE_MAX, SCALE_STEP) or DEFAULT_SCALE
end

function ns.RXPWindowWidth()
    local width = tonumber(Settings().rxpWindowWidth)
    return width and Snap(width, WIDTH_MIN, WIDTH_MAX, WIDTH_STEP) or DEFAULT_WIDTH
end

function ns.RXPWindowSteps()
    local steps = tonumber(Settings().rxpWindowSteps)
    return steps and Snap(steps, STEPS_MIN, STEPS_MAX, 1) or DEFAULT_STEPS
end

function ns.RXPWindowReady()
    local v2 = Dig(_G.RXP, "v2")
    return Has(v2, "IsGuideWindowEnabled") and v2:IsGuideWindowEnabled() and true or false
end

local function Run(name, fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then return result end
    ns.RXPFailures[name] = tostring(result)
end

local function SplitRange(text)
    local range, place = text:match("^(%d+%-%d+)%s+(.+)$")
    if range then return place, range end
    place, range = text:match("^(.-)%s+(%d+%-%d+)$")
    if place then return place, range end
    return text
end

local function Hex(c)
    return ("%02x%02x%02x"):format(math.floor(c.r * CHANNEL_MAX + ROUND), math.floor(c.g * CHANNEL_MAX + ROUND),
        math.floor(c.b * CHANNEL_MAX + ROUND))
end

local function Tint(c, text)
    return "|cff" .. Hex(c) .. text .. "|r"
end

local function Plain(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|T[^|]*|t", "")
    text = text:gsub("|A[^|]*|a", "")
    text = text:gsub("|H[^|]*|h", "")
    text = text:gsub("|h", "")
    return (text:gsub("^%s+", ""))
end

local function Heading(rxp, guide)
    local name = Has(rxp, "GetGuideName") and Run("WindowGuideName", rxp.GetGuideName, guide) or guide.name
    local title = guide.title or guide.subgroup or name
    if type(title) ~= "string" then return "" end
    local place, range = SplitRange(title)
    return range and (place .. " " .. Tint(GOLD, range)) or place
end

local function Row(rxp, element)
    local frame = element.frame
    local text = Dig(frame, "text")
    local shown = Has(text, "GetText") and text:GetText()
    if type(shown) ~= "string" or shown == "" or shown == " " then
        local raw = element.text ~= " " and element.text or element.tooltipText or element.rawtext
        shown = type(raw) == "string" and raw or ""
        if Has(rxp, "ReplaceNpcIds") then shown = Run("WindowNpc", rxp.ReplaceNpcIds, shown, element) or shown end
    end
    local icon = Dig(frame, "icon")
    local glyph = Has(icon, "GetText") and icon:GetText()
    if type(glyph) ~= "string" then glyph = element.icon or Dig(rxp, "icons", element.tag) or "" end
    local button = Dig(frame, "button")
    local done = Has(button, "GetChecked") and button:GetChecked() or element.completed or element.skip
    return { text = shown, icon = glyph, done = done and true or false, button = button, source = text }
end

local function ActiveSteps(rxp)
    local list = Dig(rxp, "RXPFrame", "activeSteps")
    local out = {}
    if type(list) ~= "table" then return out end
    for _, step in ipairs(list) do
        if type(step) == "table" and step.active and not step.hidewindow and not step.hidetip then
            out[#out + 1] = step
            if #out == ACTIVE_SHOWN then break end
        end
    end
    return out
end

local function StepLabel(rxp, step)
    if type(step.title) == "string" and step.title ~= "" then return step.title end
    local get = Dig(rxp, "locale", "Get")
    local format = type(get) == "function" and Run("WindowLocale", get, TEXT_STEP) or TEXT_STEP
    return (type(format) == "string" and format or TEXT_STEP):format(tonumber(step.index) or 0)
end

local function Upcoming(rxp, after, count)
    local out = {}
    local v2 = Dig(rxp, "v2")
    if count == 0 or not Has(v2, "BuildGuideStepsSnapshot") then return out end
    local snapshot = Run("WindowSteps", v2.BuildGuideStepsSnapshot, v2, true)
    if type(snapshot) ~= "table" or type(snapshot.rows) ~= "table" then return out end
    for _, row in ipairs(snapshot.rows) do
        if type(row) == "table" and type(row.index) == "number" and row.index > after and not row.hidden
                and not row.complete and type(row.text) == "string" then
            out[#out + 1] = { index = row.index, text = Plain(row.text:match("^[^\n]*")) }
            if #out == count then break end
        end
    end
    return out
end

-- What RestedXP is showing, as plain data: the heading, the progress, the active steps with their rows,
-- and the steps that follow. Nil without a guide.
local function Read()
    local rxp = _G.RXP
    local guide = Dig(rxp, "currentGuide")
    if type(guide) ~= "table" or guide.empty or type(guide.steps) ~= "table" then return nil end
    local model = { heading = Heading(rxp, guide), steps = {} }
    local step = Has(rxp, "GetGuideProgress") and Run("WindowProgress", rxp.GetGuideProgress)
    local total = #guide.steps
    if type(step) == "number" and total > 0 then
        model.step, model.total = step, total
        model.percent = math.floor(step / total * PERCENT + ROUND)
    end
    local after = step or 0
    for _, active in ipairs(ActiveSteps(rxp)) do
        local rows = {}
        for _, element in ipairs(active.elements or {}) do
            if type(element) == "table" and (element.text or element.rawtext or element.tooltipText) then
                rows[#rows + 1] = Row(rxp, element)
            end
        end
        model.steps[#model.steps + 1] = { label = StepLabel(rxp, active), rows = rows }
        if type(active.index) == "number" and active.index > after then after = active.index end
    end
    model.upcoming = Upcoming(rxp, after, ns.RXPWindowSteps())
    return model
end

local function Refresh()
    if not active or pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        Quiet("WindowDraw", Draw)
    end)
end

local function Silence(frame, top)
    if type(frame) ~= "table" then return end
    if not silenced[frame] then
        local home = {}
        if top and Has(frame, "GetAlpha") then home.alpha = frame:GetAlpha() end
        if Has(frame, "IsMouseEnabled") then home.mouse = frame:IsMouseEnabled() end
        silenced[frame] = home
        if top and Has(frame, "SetAlpha") then
            frame:SetAlpha(0)
            if not watched[frame] then
                watched[frame] = true
                hooksecurefunc(frame, "SetAlpha", function(self, alpha)
                    if active and alpha ~= 0 then self:SetAlpha(0) end
                end)
            end
        end
        if Has(frame, "EnableMouse") then frame:EnableMouse(false) end
    end
    if Has(frame, "GetChildren") then
        for _, child in ipairs({ frame:GetChildren() }) do Silence(child, false) end
    end
end

local function Take()
    local rxp = _G.RXP
    Silence(Dig(_G, "RXPV2GuideWindow", "frame"), true)
    local name = Dig(rxp, "player", "name")
    local steps = type(name) == "string" and Dig(_G, "RXPActiveStepsFrame" .. name) or nil
    Silence(Dig(steps, "frame") or steps, true)
end

local function Release()
    for frame, home in pairs(silenced) do
        if home.alpha ~= nil and Has(frame, "SetAlpha") then frame:SetAlpha(home.alpha) end
        if home.mouse ~= nil and Has(frame, "EnableMouse") then frame:EnableMouse(home.mouse) end
        silenced[frame] = nil
    end
end

local function Save(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point then Settings().rxpWindowPos = { point, relativePoint, x, y } end
end

local function Place(frame)
    local saved = Settings().rxpWindowPos
    frame:ClearAllPoints()
    if type(saved) == "table" and type(saved[1]) == "string" then
        frame:SetPoint(saved[1], UIParent, saved[2] or saved[1], saved[3] or 0, saved[4] or 0)
        return
    end
    local home = Dig(_G, "RXPV2GuideWindow", "frame")
    local point, relativePoint, x, y = HOME[1], HOME[2], HOME[3], HOME[4]
    if Has(home, "GetPoint") then
        local first, _, relative, dx, dy = home:GetPoint(1)
        if first then point, relativePoint, x, y = first, relative, dx, dy end
    end
    frame:SetPoint(point, UIParent, relativePoint, x, y)
end

local function Menu()
    local frame = Dig(_G.RXP, "RXPFrame")
    if Has(frame, "DropDownMenu") then Quiet("WindowMenu", frame.DropDownMenu) end
end

local function Text(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.AddonFontPath(), size, "")
    fs:SetShadowOffset(SHADOW, -SHADOW)
    fs:SetShadowColor(0, 0, 0, SHADOW_ALPHA)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetJustifyV("TOP")
    return fs
end

local function Draggable(frame)
    frame:RegisterForDrag(DRAG_BUTTON)
    frame:SetScript("OnDragStart", function() window:StartMoving() end)
    frame:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        Save(window)
    end)
end

local function Build()
    local T = ns.THEME
    local f = CreateFrame("Frame", WINDOW_NAME, UIParent)
    f:SetFrameStrata(STRATA)
    f:SetScale(ns.RXPWindowScale() / PERCENT)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    Draggable(f)
    f:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then Menu() end
    end)
    f.fold = CreateFrame("Button", nil, f)
    f.fold:SetSize(FOLD_W, HEAD_H)
    f.fold.text = Text(f.fold, FONT_HEAD, "CENTER")
    f.fold.text:SetAllPoints()
    f.fold:SetScript("OnClick", function()
        local on = Settings().rxpWindowCollapsed ~= true
        Settings().rxpWindowCollapsed = on or nil
        Quiet("WindowDraw", Draw)
    end)
    f.title = Text(f, FONT_HEAD)
    f.title:SetWordWrap(false)
    f.progress = Text(f, FONT_TEXT, "RIGHT")
    f.rule = ns.Solid(f, "ARTWORK", T.fg, RULE_ALPHA)
    ns.Hairline(f.rule, "h")
    f.menu = CreateFrame("Button", nil, f)
    f.menu:SetSize(MENU_SIZE, MENU_SIZE)
    f.menu:SetNormalTexture(MENU_ICON)
    f.menu:SetHighlightTexture(MENU_ICON)
    f.menu:SetScript("OnClick", Menu)
    Place(f)
    return f
end

local function MakeBox()
    local T = ns.THEME
    local box = CreateFrame("Frame", nil, window)
    ns.Solid(box, "BACKGROUND", T.bg, BOX_ALPHA):SetAllPoints()
    ns.Border(box, T.line, EDGE_ALPHA)
    box.label = Text(box, FONT_TEXT)
    box.label:SetTextColor(T.accent.r, T.accent.g, T.accent.b)
    return box
end

local function LinkEnter(row, link)
    if row:IsForbidden() or GameTooltip:IsForbidden() then return end
    GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
    GameTooltip:SetHyperlink(link)
end

local function LinkLeave(row)
    if row:IsForbidden() or GameTooltip:IsForbidden() then return end
    if GameTooltip:GetOwner() == row then GameTooltip:Hide() end
end

local function MakeRow()
    local T = ns.THEME
    local row = CreateFrame("Button", nil, window)
    row:SetHyperlinksEnabled(true)
    row:SetScript("OnHyperlinkClick", function(_, link, text, button)
        Quiet("WindowLink", SetItemRef, link, text, button)
    end)
    row:SetScript("OnHyperlinkEnter", LinkEnter)
    row:SetScript("OnHyperlinkLeave", LinkLeave)
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", function(self)
        if Has(self.source, "Click") then Quiet("WindowSkip", self.source.Click, self.source) end
    end)
    row:SetScript("OnEnter", function(self)
        if self.source and not GameTooltip:IsForbidden() then
            GameTooltip:SetOwner(self, TIP_ANCHOR)
            GameTooltip:SetText(TEXT_SKIP)
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.bar = ns.Solid(row, "ARTWORK", T.accent, 1)
    row.icon = Text(row, FONT_TEXT)
    row.text = Text(row, FONT_TEXT)
    row.text:SetWordWrap(true)
    Draggable(row)
    return row
end

local function MakeLine()
    local line = Text(window, FONT_LIST)
    line:SetWordWrap(false)
    return line
end

local MAKERS = { box = MakeBox, row = MakeRow, line = MakeLine }

local function Acquire(kind)
    used[kind] = used[kind] + 1
    local item = pool[kind][used[kind]]
    if not item then
        item = MAKERS[kind]()
        pool[kind][used[kind]] = item
    end
    item:Show()
    return item
end

local function Reset()
    for kind, list in pairs(pool) do
        for i = 1, #list do list[i]:Hide() end
        used[kind] = 0
    end
end

local function Watch(source)
    if type(source) ~= "table" or watched[source] or not Has(source, "SetText") then return end
    watched[source] = true
    hooksecurefunc(source, "SetText", Guarded("WindowText", Refresh))
end

local function DrawRow(box, row, x, y, width)
    local T = ns.THEME
    local item = Acquire("row")
    item:SetParent(box)
    item.source = row.button
    item:ClearAllPoints()
    item:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
    item:SetWidth(width)
    local c = row.done and T.muted or T.fg
    local textWidth = width - BAR_W - GAP - ICON_W
    item.bar:ClearAllPoints()
    item.bar:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
    item.bar:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 0, 0)
    item.bar:SetWidth(BAR_W)
    local a = row.done and T.muted or T.accent
    item.bar:SetColorTexture(a.r, a.g, a.b, 1)
    item.icon:ClearAllPoints()
    item.icon:SetPoint("TOPLEFT", item, "TOPLEFT", BAR_W + GAP, 0)
    item.icon:SetText(row.icon)
    item.text:ClearAllPoints()
    item.text:SetPoint("TOPLEFT", item, "TOPLEFT", BAR_W + GAP + ICON_W, 0)
    item.text:SetWidth(textWidth)
    item.text:SetTextColor(c.r, c.g, c.b)
    item.text:SetText(row.text)
    local height = math.max(item.text:GetStringHeight(), FONT_TEXT)
    item:SetHeight(height)
    Watch(row.source)
    return height
end

local function DrawBox(step, y, inner)
    local box = Acquire("box")
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
    box:SetWidth(inner)
    box.label:ClearAllPoints()
    box.label:SetPoint("TOPLEFT", box, "TOPLEFT", BOX_PAD, -BOX_PAD)
    box.label:SetText(step.label:upper())
    local by = -BOX_PAD - FONT_TEXT - GAP
    for _, row in ipairs(step.rows) do
        by = by - DrawRow(box, row, BOX_PAD, by, inner - BOX_PAD * 2) - GAP
    end
    box:SetHeight(-by + BOX_PAD - GAP)
    return y + by - BOX_PAD
end

local function DrawHeader(model, folded, width)
    local T = ns.THEME
    window.fold:ClearAllPoints()
    window.fold:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -PAD)
    window.fold.text:SetText(folded and TEXT_UNFOLD or TEXT_FOLD)
    window.fold.text:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
    window.title:ClearAllPoints()
    window.title:SetPoint("TOPLEFT", window, "TOPLEFT", PAD + FOLD_W + GAP, -PAD)
    window.title:SetWidth(width - PAD * 2 - FOLD_W - GAP - PROGRESS_W)
    window.title:SetTextColor(T.fg.r, T.fg.g, T.fg.b)
    window.title:SetText(model.heading)
    window.progress:ClearAllPoints()
    window.progress:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, -PAD)
    if model.step then
        window.progress:SetText(Tint(T.accent, ("%d/%d"):format(model.step, model.total)) .. TEXT_DOT
            .. ("%d%%"):format(model.percent))
    else
        window.progress:SetText("")
    end
    window.progress:SetTextColor(T.fg.r, T.fg.g, T.fg.b)
    window.rule:ClearAllPoints()
    window.rule:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -PAD - HEAD_H)
    window.rule:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, -PAD - HEAD_H)
end

function Draw()
    if not active then return end
    window = window or Build()
    Take()
    local model = Read()
    if not model then
        window:Hide()
        return
    end
    Reset()
    local T = ns.THEME
    local width = ns.RXPWindowWidth()
    local inner = width - PAD * 2
    local folded = Settings().rxpWindowCollapsed == true
    window:SetWidth(width)
    DrawHeader(model, folded, width)
    local y = -PAD - HEAD_H - GAP
    if not folded then
        for _, step in ipairs(model.steps) do y = DrawBox(step, y, inner) end
        for _, line in ipairs(model.upcoming) do
            local item = Acquire("line")
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
            item:SetWidth(inner)
            item:SetTextColor(T.muted.r, T.muted.g, T.muted.b, MUTED_ALPHA)
            item:SetText(("%d  %s"):format(line.index, line.text))
            y = y - LIST_H
        end
    end
    window.menu:ClearAllPoints()
    if folded then
        window.menu:Hide()
    else
        window.menu:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y - GAP)
        window.menu:Show()
        y = y - GAP - MENU_SIZE
    end
    window:SetHeight(-y + PAD)
    window:Show()
end

local function Apply()
    local want = ns.RXPWindowEnabled() and ns.RXPThemesAvailable() and ns.RXPWindowReady()
    if want == active then
        if active then Refresh() end
        return
    end
    active = want
    if want then
        Quiet("WindowDraw", Draw)
    else
        Release()
        if window then window:Hide() end
    end
end

local function Hook(owner, name)
    if Has(owner, name) then hooksecurefunc(owner, name, Guarded("WindowRefresh", Refresh)) end
end

function ns.RXPWindowStart()
    if not started then
        started = true
        local rxp = _G.RXP
        Hook(rxp, "SetStep")
        local v2 = Dig(rxp, "v2")
        Hook(v2, "UpdateGuideWindow")
        Hook(v2, "UpdateActiveStepsFrame")
        Hook(v2, "UpdatePlayerActiveStepItem")
    end
    Apply()
end

function ns.SetRXPWindow(on)
    Settings().rxpWindow = on and true or nil
    ns.RXPWindowStart()
end

function ns.SetRXPWindowWidth(width)
    width = tonumber(width)
    width = width and Snap(width, WIDTH_MIN, WIDTH_MAX, WIDTH_STEP)
    Settings().rxpWindowWidth = width ~= DEFAULT_WIDTH and width or nil
    Refresh()
end

function ns.SetRXPWindowScale(scale)
    local was = window and window:GetScale() or ns.RXPWindowScale() / PERCENT
    scale = tonumber(scale)
    scale = scale and Snap(scale, SCALE_MIN, SCALE_MAX, SCALE_STEP)
    Settings().rxpWindowScale = scale ~= DEFAULT_SCALE and scale or nil
    local now = ns.RXPWindowScale() / PERCENT
    local saved = Settings().rxpWindowPos
    if window then
        local point, _, relativePoint, x, y = window:GetPoint(1)
        window:SetScale(now)
        if point then
            window:ClearAllPoints()
            window:SetPoint(point, UIParent, relativePoint, x * was / now, y * was / now)
            Save(window)
        end
    elseif type(saved) == "table" and type(saved[3]) == "number" and type(saved[4]) == "number" then
        saved[3], saved[4] = saved[3] * was / now, saved[4] * was / now
    end
end

function ns.SetRXPWindowSteps(steps)
    steps = tonumber(steps)
    steps = steps and Snap(steps, STEPS_MIN, STEPS_MAX, 1)
    Settings().rxpWindowSteps = steps ~= DEFAULT_STEPS and steps or nil
    Refresh()
end

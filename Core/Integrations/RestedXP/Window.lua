-- Window.lua: RestedXP's guide in one Naowh window: its progress, the active step and the steps after it.
local ns = _G.NaowhForever
local F = ns.FEATURES.account
local Safe = ns.RXPSafe
local Has, Dig, Quiet, Guarded = Safe.Has, Safe.Dig, Safe.Quiet, Safe.Guarded

local WINDOW_NAME = "NaowhRXPWindow"
local STRATA = "MEDIUM"
local WIDTH_MIN, WIDTH_MAX, WIDTH_STEP, DEFAULT_WIDTH = 260, 640, 1, 380
local SCALE_MIN, SCALE_MAX, SCALE_STEP, DEFAULT_SCALE = 60, 200, 5, 100
local STEPS_MIN, STEPS_MAX, DEFAULT_STEPS = 0, 12, 6
local ACTIVE_SHOWN = 3
local PERCENT, ROUND, CHANNEL_MAX = 100, 0.5, 255
local PAD, BOX_PAD, FOLD_W, PROGRESS_W = 10, 7, 16, 120
local HEAD_PAD, LIST_PAD = 10, 6
local BOX_TITLE_TEXT, BOX_TITLE_HEIGHT, BOX_TITLE_ROOM = 9, 19, 10
local BAR_W, ICON_W, MENU_SIZE, GRIP_SIZE = 2, 18, 22, 16
local PANEL_ALPHA, EDGE_ALPHA, RULE_ALPHA, MUTED_ALPHA = 0.92, 0.8, 0.5, 0.9
local BOX_OPACITY = 55
local COUNT_PATTERN, COUNT_MIN, COUNT_GAP = "(%d+)%s*/%s*(%d+)", 2, 2
local BAG_EVENT = "BAG_UPDATE_DELAYED"
local SHADOW, SHADOW_ALPHA = 1, 0.9
local GOLD = { r = 1, g = 0.82, b = 0 }
local TEXT_FOLD, TEXT_UNFOLD, TEXT_DOT = "-", "+", " \194\183 "
local MENU_ICON = "Interface\\ChatFrame\\UI-ChatIcon-Chat-Up"
local LOGO = "Interface\\AddOns\\RXPGuides\\Textures\\rxp_logo-64"
local GRADIENT = ns.MEDIA .. "NaowhGradient.tga"
local TEXT_GRADIENT = "Naowh Gradient"
local GRIP_UP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
local GRIP_DOWN = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down"
local GRIP_HIGHLIGHT = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"
local GRIP_CORNER = "BOTTOMRIGHT"
local TEXT_STEP = "Step %d"
local TEXT_SKIP = "Skip step"
local TEXT_SKIP_ROW = "Shift-click: skip this objective"
local TEXT_GO = "Go to step %d"
local TIP_DIM = 0.7
local HOME = { "LEFT", "LEFT", 0, 35 }
local DRAG_BUTTON, TIP_ANCHOR = "LeftButton", "ANCHOR_TOP"
local COLORS_KEY = "rxpWindowColors"

-- Everything the window can be changed in, in the order a page lists it. A saved value is only kept when it
-- is not the default, as in the other settings of this integration.
local OUTLINES = { shadow = "Shadow", outline = "Outline", thick = "Thick Outline", none = "None" }
local OUTLINE_FLAGS = { outline = "OUTLINE", thick = "THICKOUTLINE" }
local LINES = { bar = "Progress Bar", rule = "Line", none = "Nothing" }
local OPTIONS = {
    { key = "rxpWindowFont", group = "Text", kind = "font", label = "Window Font",
      tip = "The face of every text in the window." },
    { key = "rxpWindowOutline", group = "Text", kind = "choice", label = "Text Outline", default = "shadow",
      values = OUTLINES, order = { "shadow", "outline", "thick", "none" },
      tip = "How the text is kept readable over the world." },
    { key = "rxpWindowTitleSize", group = "Text", kind = "number", label = "Title Size", default = 16, min = 10,
      max = 28, tip = "The guide's name and its progress." },
    { key = "rxpWindowTextSize", group = "Text", kind = "number", label = "Step Text Size", default = 13, min = 8,
      max = 24, tip = "The active step." },
    { key = "rxpWindowListSize", group = "Text", kind = "number", label = "List Text Size", default = 12, min = 8,
      max = 24, tip = "The steps after the active one." },
    { key = "rxpWindowProgressText", group = "Look", kind = "toggle", label = "Show Progress Text", default = true,
      tip = "The step and the percent of the guide, beside its name." },
    { key = "rxpWindowLine", group = "Look", kind = "choice", label = "Under the Title", default = "bar",
      values = LINES, order = { "bar", "rule", "none" }, tip = "A progress bar of the guide, a line, or nothing." },
    { key = "rxpWindowLogo", group = "Look", kind = "toggle", label = "Show RestedXP Logo", default = true,
      tip = "RestedXP's logo in the corner of the current step." },
    { key = "rxpWindowLogoSize", group = "Look", kind = "number", label = "RestedXP Logo Size", default = 24,
      min = 12, max = 48, tip = "How big RestedXP's logo is." },
    { key = "rxpWindowIndent", group = "Look", kind = "number", label = "Row Indent", default = 12, min = 0,
      max = 32, tip = "How far the rows after the first are set in." },
    { key = "rxpWindowMenu", group = "Look", kind = "toggle", label = "Show Menu Button", default = true,
      tip = "The button that opens RestedXP's menu." },
    { key = "rxpWindowGrip", group = "Look", kind = "toggle", label = "Show Resize Grip", default = true,
      tip = "The corner that is dragged to change the window's width and how many steps are listed." },
    { key = "rxpWindowLock", group = "Look", kind = "toggle", label = "Lock Window", default = false,
      tip = "The window cannot be moved or resized." },
    { key = "rxpWindowPanel", group = "Look", kind = "toggle", label = "Window Background", default = false,
      tip = "A panel behind the whole window." },
    { key = "rxpWindowBorder", group = "Look", kind = "toggle", label = "Window Border", default = false,
      tip = "A border round the whole window." },
    { key = "rxpWindowBoxBorder", group = "Look", kind = "toggle", label = "Step Box Border", default = true,
      tip = "A border round the active step." },
    { key = "rxpWindowBoxOpacity", group = "Look", kind = "number", label = "Step Box Opacity",
      default = BOX_OPACITY, min = 0, max = PERCENT, tip = "How solid the background of the active step is." },
    { key = "rxpWindowSatellites", group = "Look", kind = "toggle", label = "Style Targets and Items",
      default = true, tip = "RestedXP's Active Targets and Active Items windows take the look of the active step." },
    { key = "rxpWindowSpacing", group = "Look", kind = "number", label = "Spacing", default = 5, min = 0, max = 12,
      tip = "The room between the rows." },
    { key = "rxpWindowBarHeight", group = "Progress", kind = "number", label = "Bar Height", default = 5, min = 2,
      max = 16, tip = "How thick the progress bars are." },
    { key = "rxpWindowBarTexture", group = "Progress", kind = "texture", label = "Bar Texture",
      defaultLabel = TEXT_GRADIENT, tip = "The texture of the progress bars, the Naowh Gradient to start." },
    { key = "rxpWindowStepBar", group = "Progress", kind = "toggle", label = "Step Objectives Bar", default = false,
      tip = "A bar under the active step of the objectives done." },
    { key = "rxpWindowCountBar", group = "Progress", kind = "toggle", label = "Item Count Bars", default = true,
      tip = "A bar under a row that counts, as in Buy 5 or 3/8 Boar Meat." },
}

-- A color is a theme token and an opacity, or a color of its own; a picked one is kept whole.
local COLORS = {
    { name = "title", label = "Title Color", token = "fg", tip = "The guide's name." },
    { name = "range", label = "Level Range Color", rgb = GOLD, tip = "The level range in the guide's name." },
    { name = "progress", label = "Progress Color", token = "accent", tip = "The step count at the right." },
    { name = "percent", label = "Percent Color", token = "fg", tip = "The percent at the right." },
    { name = "label", label = "Step Label Color", token = "accent", tip = "STEP and its number." },
    { name = "text", label = "Step Text Color", token = "fg", tip = "The rows of the active step." },
    { name = "done", label = "Done Text Color", token = "muted", tip = "A row that is done." },
    { name = "list", label = "List Text Color", token = "muted", alpha = MUTED_ALPHA,
      tip = "The steps after the active one." },
    { name = "line", label = "Line Color", token = "fg", alpha = RULE_ALPHA, tip = "The line and the bars' track." },
    { name = "fill", label = "Bar Color", token = "accent", tip = "The filled part of the bars." },
    { name = "box", label = "Step Box Color", token = "bg", opaque = true,
      tip = "Behind the active step; its opacity is its own setting." },
    { name = "boxEdge", label = "Step Box Border Color", token = "line", alpha = EDGE_ALPHA,
      tip = "Round the active step." },
    { name = "panel", label = "Window Color", token = "panel", alpha = PANEL_ALPHA, tip = "Behind the whole window." },
    { name = "edge", label = "Window Border Color", token = "line", alpha = EDGE_ALPHA,
      tip = "Round the whole window." },
}

local OPTION_BY_KEY, COLOR_BY_NAME = {}, {}
for _, option in ipairs(OPTIONS) do OPTION_BY_KEY[option.key] = option end
for _, color in ipairs(COLORS) do COLOR_BY_NAME[color.name] = color end

local window, active, started, pending, skinned, wantsBags
local sizing, sizingModel
local pool, used = { box = {}, row = {}, line = {}, hit = {} }, { box = 0, row = 0, line = 0, hit = 0 }
local silenced = setmetatable({}, { __mode = "k" })
local watched = setmetatable({}, { __mode = "k" })
local faced = {}
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

function ns.RXPWindowOptions() return OPTIONS end

function ns.RXPWindowColors() return COLORS end

function ns.RXPWindowOption(key)
    local option = OPTION_BY_KEY[key]
    if not option then return nil end
    local value = Settings()[key]
    if option.kind == "number" then
        local number = tonumber(value)
        return number and Snap(number, option.min, option.max, 1) or option.default
    elseif option.kind == "toggle" then
        if value == nil then return option.default end
        return value == true
    elseif option.kind == "choice" then
        return option.values[value] and value or option.default
    end
    return type(value) == "string" and value or ""
end

local function Refresh()
    if not active or pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        Quiet("WindowDraw", Draw)
    end)
end

function ns.SetRXPWindowOption(key, value)
    local option = OPTION_BY_KEY[key]
    if not option then return end
    local store
    if option.kind == "number" then
        local number = tonumber(value)
        number = number and Snap(number, option.min, option.max, 1)
        store = number ~= option.default and number or nil
    elseif option.kind == "toggle" then
        local on = value and true or false
        if on ~= option.default then store = on end
    elseif option.kind == "choice" then
        store = option.values[value] and value ~= option.default and value or nil
    else
        store = type(value) == "string" and value ~= "" and value or nil
    end
    Settings()[key] = store
    Refresh()
end

function ns.RXPWindowColor(name)
    local color = COLOR_BY_NAME[name]
    if not color then return 1, 1, 1, 1 end
    local saved = Dig(Settings(), COLORS_KEY, name)
    if type(saved) == "table" and type(saved.r) == "number" and type(saved.g) == "number"
            and type(saved.b) == "number" then
        return saved.r, saved.g, saved.b, type(saved.a) == "number" and saved.a or 1
    end
    local base = color.rgb or ns.THEME[color.token]
    return base.r, base.g, base.b, color.alpha or 1
end

function ns.SetRXPWindowColor(name, r, g, b, a)
    if not COLOR_BY_NAME[name] then return end
    local all = Settings()[COLORS_KEY]
    if type(all) ~= "table" then
        all = {}
        Settings()[COLORS_KEY] = all
    end
    if type(r) == "number" and type(g) == "number" and type(b) == "number" then
        local solid = COLOR_BY_NAME[name].opaque or type(a) ~= "number"
        all[name] = { r = r, g = g, b = b, a = solid and 1 or a }
    else
        all[name] = nil
    end
    if next(all) == nil then Settings()[COLORS_KEY] = nil end
    Refresh()
end

function ns.ResetRXPWindowStyle()
    for _, option in ipairs(OPTIONS) do Settings()[option.key] = nil end
    Settings()[COLORS_KEY] = nil
    Refresh()
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

local function Hex(r, g, b)
    return ("%02x%02x%02x"):format(math.floor(r * CHANNEL_MAX + ROUND), math.floor(g * CHANNEL_MAX + ROUND),
        math.floor(b * CHANNEL_MAX + ROUND))
end

local function Tint(name, text)
    local r, g, b = ns.RXPWindowColor(name)
    return "|cff" .. Hex(r, g, b) .. text .. "|r"
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
    return range and (place .. " " .. Tint("range", range)) or place
end

local function ItemCount(id)
    local item = _G.C_Item
    local count = Has(item, "GetItemCount") and item.GetItemCount or _G.GetItemCount
    if type(count) ~= "function" then return nil end
    local have = Run("WindowCount", count, id)
    return type(have) == "number" and have or nil
end

local function Counted(element, shown)
    local tag = element.tag
    if type(tag) == "string" and tag:find("^buy") and type(element.id) == "number"
            and type(element.qty) == "number" then
        local have = ItemCount(element.id)
        if have then return have, element.qty, true end
    end
    local have, need = Plain(shown):match(COUNT_PATTERN)
    return tonumber(have), tonumber(need), false
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
    local have, need, bags = Counted(element, shown)
    return { text = shown, icon = glyph, done = done and true or false, button = button, source = text,
        have = have, need = need, bags = bags }
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
local function Read(steps)
    local rxp = _G.RXP
    local guide = Dig(rxp, "currentGuide")
    if type(guide) ~= "table" or guide.empty or type(guide.steps) ~= "table" then return nil end
    local model = { heading = Heading(rxp, guide), steps = {} }
    local step = Has(rxp, "GetGuideProgress") and Run("WindowProgress", rxp.GetGuideProgress)
    local total = #guide.steps
    if type(step) == "number" and total > 0 then
        model.step, model.total = step, total
        model.fraction = math.min(1, math.max(0, step / total))
        model.percent = math.floor(model.fraction * PERCENT + ROUND)
    end
    local after = step or 0
    for _, activeStep in ipairs(ActiveSteps(rxp)) do
        local rows, done = {}, 0
        for _, element in ipairs(activeStep.elements or {}) do
            if type(element) == "table" and (element.text or element.rawtext or element.tooltipText) then
                local row = Row(rxp, element)
                rows[#rows + 1] = row
                if row.done then done = done + 1 end
            end
        end
        model.steps[#model.steps + 1] = { label = StepLabel(rxp, activeStep), rows = rows, done = done }
        if type(activeStep.index) == "number" and activeStep.index > after then after = activeStep.index end
    end
    model.upcoming = Upcoming(rxp, after, steps or ns.RXPWindowSteps())
    return model
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

local function FacePath()
    local name = ns.RXPWindowOption("rxpWindowFont")
    local custom = name ~= "" and type(ns.UI) == "table" and ns.UI.FontPath and ns.UI.FontPath(name)
    return custom or ns.AddonFontPath()
end

-- A text: its face, size, outline and shadow are the window's own, set again each time it is drawn.
local function Faced(fs, size)
    local outline = ns.RXPWindowOption("rxpWindowOutline")
    fs:SetFont(FacePath(), size, OUTLINE_FLAGS[outline] or "")
    if outline == "shadow" then
        fs:SetShadowOffset(SHADOW, -SHADOW)
        fs:SetShadowColor(0, 0, 0, SHADOW_ALPHA)
    else
        fs:SetShadowOffset(0, 0)
    end
end

local function Face(fs, sizeKey)
    Faced(fs, ns.RXPWindowOption(sizeKey))
end

local function Text(parent, sizeKey, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs.sizeKey = sizeKey
    faced[#faced + 1] = fs
    Face(fs, sizeKey)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetJustifyV("TOP")
    return fs
end

local function Refaced()
    for _, fs in ipairs(faced) do Face(fs, fs.sizeKey) end
end

local function Coloured(fs, name)
    local r, g, b, a = ns.RXPWindowColor(name)
    fs:SetTextColor(r, g, b, a)
end

-- RestedXP's Active Targets and Active Items windows in the look of the active step: the colors of their v2
-- background and border are set in place, and the text of their title takes the window's face.
local function SkinBox(part)
    local fill = Dig(part, "rxpBackground", "textures", 1)
    if Has(fill, "SetVertexColor") then
        local r, g, b = ns.RXPWindowColor("box")
        fill:SetVertexColor(r, g, b, ns.RXPWindowOption("rxpWindowBoxOpacity") / PERCENT)
    end
    local border = Dig(part, "rxpBorder")
    if type(border) ~= "table" then return end
    local r, g, b, a = ns.RXPWindowColor("boxEdge")
    for _, texture in ipairs(type(border.textures) == "table" and border.textures or {}) do
        if Has(texture, "SetColorTexture") then texture:SetColorTexture(r, g, b, a) end
    end
    local back = part.rxpBackground
    local shown = not Has(back, "IsShown") or back:IsShown()
    if Has(border, "SetShown") then
        border:SetShown(ns.RXPWindowOption("rxpWindowBoxBorder") and shown and true or false)
    end
end

local function SkinTitle(title)
    SkinBox(title)
    local text = title.text
    if not (Has(text, "SetFont") and Has(text, "GetFont") and Has(text, "GetStringWidth")) then return end
    local _, size = text:GetFont()
    Faced(text, type(size) == "number" and size or BOX_TITLE_TEXT)
    Coloured(text, "label")
    if Has(title, "SetSize") then title:SetSize(text:GetStringWidth() + BOX_TITLE_ROOM, BOX_TITLE_HEIGHT) end
end

local function SkinFrame(frame)
    SkinBox(frame)
    if type(frame.title) == "table" then SkinTitle(frame.title) end
end

local function SkinWanted()
    return active and ns.RXPWindowOption("rxpWindowSatellites")
end

local function SkinFrames()
    local rxp = _G.RXP
    local frames = {}
    local target, items = Dig(rxp, "targeting", "activeTargetFrame"), Dig(rxp, "activeItemFrame")
    if type(target) == "table" then table.insert(frames, target) end
    if type(items) == "table" then table.insert(frames, items) end
    return frames
end

local function SkinHooks(frames)
    for _, frame in ipairs(frames) do
        if not watched[frame] and Has(frame, "UpdateVisuals") then
            watched[frame] = true
            hooksecurefunc(frame, "UpdateVisuals", Guarded("WindowSkin", function(self)
                if SkinWanted() then SkinFrame(self) end
            end))
        end
    end
    local targeting = Dig(_G.RXP, "targeting")
    if not watched[targeting] and Has(targeting, "RenderTargetFrameBackground") then
        watched[targeting] = true
        hooksecurefunc(targeting, "RenderTargetFrameBackground", Guarded("WindowSkin", function()
            local target = Dig(_G.RXP, "targeting", "activeTargetFrame")
            if SkinWanted() and type(target) == "table" then SkinBox(target) end
        end))
    end
end

-- RestedXP paints its own look again, and shows the border where it shows the background
local function SkinRestore(frame)
    if Has(frame, "UpdateVisuals") then Quiet("WindowSkin", frame.UpdateVisuals, frame) end
    for _, part in ipairs({ frame, frame.title }) do
        local border, back = Dig(part, "rxpBorder"), Dig(part, "rxpBackground")
        if Has(border, "SetShown") then border:SetShown(not Has(back, "IsShown") or back:IsShown()) end
    end
end

local function Skin()
    local frames = SkinFrames()
    if SkinWanted() then
        skinned = true
        SkinHooks(frames)
        for _, frame in ipairs(frames) do Quiet("WindowSkin", SkinFrame, frame) end
    elseif skinned then
        skinned = false
        for _, frame in ipairs(frames) do SkinRestore(frame) end
    end
end

local function Draggable(frame)
    frame:RegisterForDrag(DRAG_BUTTON)
    frame:SetScript("OnDragStart", function()
        if not ns.RXPWindowOption("rxpWindowLock") then window:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        Save(window)
    end)
end

local function GoTo(index)
    local rxp = _G.RXP
    if type(index) == "number" and Has(rxp, "SetStep") then Quiet("WindowGo", rxp.SetStep, index) end
end

local function SkipStep()
    local rxp = _G.RXP
    local step = Has(rxp, "GetGuideProgress") and Run("WindowProgress", rxp.GetGuideProgress)
    if type(step) == "number" then GoTo(step + 1) end
end

local function Tip(owner, text, extra)
    if GameTooltip:IsForbidden() then return end
    GameTooltip:SetOwner(owner, TIP_ANCHOR)
    GameTooltip:SetText(text)
    if extra then
        GameTooltip:AddLine(extra, TIP_DIM, TIP_DIM, TIP_DIM)
        GameTooltip:Show()
    end
end

-- Dragging the corner sets the window's width, and how many steps are listed from how tall it was made: the
-- height the window has without any, and the height of a line, are what Draw last drew.
local function LiveSize(width, height)
    if not (sizing and sizingModel and window) then return end
    sizing.width = math.min(WIDTH_MAX, math.max(WIDTH_MIN, width))
    local base, line = window.chrome, window.lineHeight
    if type(base) == "number" and type(line) == "number" and line > 0 then
        sizing.steps = math.floor((height - base) / line)
    end
    Quiet("WindowDraw", Draw)
end

local function Resized()
    if not window then return end
    local width, height = window:GetWidth(), window:GetHeight()
    if type(width) == "number" then ns.SetRXPWindowWidth(width) end
    local base, line = window.chrome, window.lineHeight
    if type(height) == "number" and type(base) == "number" and type(line) == "number" and line > 0 then
        ns.SetRXPWindowSteps(math.floor((height - base) / line))
    end
    Save(window)
    Quiet("WindowDraw", Draw)
end

local function MakeGrip(parent)
    local grip = CreateFrame("Button", nil, parent)
    grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    grip:SetPoint(GRIP_CORNER, parent, GRIP_CORNER, 0, 0)
    grip:SetNormalTexture(GRIP_UP)
    grip:SetPushedTexture(GRIP_DOWN)
    grip:SetHighlightTexture(GRIP_HIGHLIGHT)
    grip:SetScript("OnMouseDown", function()
        if ns.RXPWindowOption("rxpWindowLock") then return end
        -- read once, with every step it could list: each size it is dragged through draws from this
        sizingModel = Read(STEPS_MAX)
        sizing = { width = window:GetWidth(), steps = ns.RXPWindowSteps() }
        window:StartSizing(GRIP_CORNER)
    end)
    grip:SetScript("OnMouseUp", function()
        sizing, sizingModel = nil, nil
        window:StopMovingOrSizing()
        Resized()
    end)
    return grip
end

local function TexturePath()
    local name = ns.RXPWindowOption("rxpWindowBarTexture")
    local custom = name ~= "" and type(ns.UI) == "table" and ns.UI.TexturePath and ns.UI.TexturePath(name, GRADIENT)
    return custom or GRADIENT
end

local function MakeBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar.track = bar:CreateTexture(nil, "BACKGROUND")
    bar.track:SetAllPoints()
    return bar
end

local function PaintBar(bar, fraction)
    bar:SetStatusBarTexture(TexturePath())
    local r, g, b, a = ns.RXPWindowColor("fill")
    bar:SetStatusBarColor(r, g, b, a)
    r, g, b, a = ns.RXPWindowColor("line")
    bar.track:SetColorTexture(r, g, b, a)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(fraction)
    bar:SetHeight(ns.RXPWindowOption("rxpWindowBarHeight"))
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
    f:SetScript("OnEvent", function() Refresh() end)
    f.back = ns.Solid(f, "BACKGROUND", T.panel, 1)
    f.back:SetAllPoints()
    f.edge = ns.Border(f, T.line, EDGE_ALPHA)
    f.fold = CreateFrame("Button", nil, f)
    f.fold.text = Text(f.fold, "rxpWindowTitleSize", "CENTER")
    f.fold.text:SetAllPoints()
    f.fold:SetScript("OnClick", function()
        local on = Settings().rxpWindowCollapsed ~= true
        Settings().rxpWindowCollapsed = on or nil
        Quiet("WindowDraw", Draw)
    end)
    f.title = Text(f, "rxpWindowTitleSize")
    f.title:SetWordWrap(false)
    f.progress = Text(f, "rxpWindowTextSize", "RIGHT")
    f.rule = ns.Solid(f, "ARTWORK", T.fg, 1)
    ns.Hairline(f.rule, "h")
    f.bar = MakeBar(f)
    f.menu = CreateFrame("Button", nil, f)
    f.menu:SetSize(MENU_SIZE, MENU_SIZE)
    f.menu:SetNormalTexture(MENU_ICON)
    f.menu:SetHighlightTexture(MENU_ICON)
    f.menu:SetScript("OnClick", Menu)
    f:SetScript("OnSizeChanged", function(_, width, height) LiveSize(width, height) end)
    f.grip = MakeGrip(f)
    Place(f)
    return f
end

local function MakeBox()
    local T = ns.THEME
    local box = CreateFrame("Button", nil, window)
    box:RegisterForClicks("LeftButtonUp")
    box:SetScript("OnClick", function() SkipStep() end)
    box:SetScript("OnEnter", function(self) Tip(self, TEXT_SKIP) end)
    box:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Draggable(box)
    box.back = ns.Solid(box, "BACKGROUND", T.bg, 1)
    box.back:SetAllPoints()
    box.edge = ns.Border(box, T.line, EDGE_ALPHA)
    box.label = Text(box, "rxpWindowTextSize")
    box.logo = box:CreateTexture(nil, "OVERLAY")
    box.logo:SetTexture(LOGO)
    box.bar = MakeBar(window)
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
    local row = CreateFrame("Button", nil, window)
    row:SetHyperlinksEnabled(true)
    row:SetScript("OnHyperlinkClick", function(_, link, text, button)
        Quiet("WindowLink", SetItemRef, link, text, button)
    end)
    row:SetScript("OnHyperlinkEnter", LinkEnter)
    row:SetScript("OnHyperlinkLeave", LinkLeave)
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", function(self)
        if not IsShiftKeyDown() then return SkipStep() end
        if Has(self.source, "Click") then Quiet("WindowSkip", self.source.Click, self.source) end
    end)
    row:SetScript("OnEnter", function(self) Tip(self, TEXT_SKIP, self.source and TEXT_SKIP_ROW or nil) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.bar = ns.Solid(row, "ARTWORK", ns.THEME.accent, 1)
    row.icon = Text(row, "rxpWindowTextSize")
    row.meter = MakeBar(row)
    row.text = Text(row, "rxpWindowTextSize")
    row.text:SetWordWrap(true)
    Draggable(row)
    return row
end

local function MakeLine()
    local line = Text(window, "rxpWindowListSize")
    line:SetWordWrap(false)
    return line
end

local function MakeHit()
    local hit = CreateFrame("Button", nil, window)
    hit:RegisterForClicks("LeftButtonUp")
    hit.shade = hit:CreateTexture(nil, "BACKGROUND")
    hit.shade:SetAllPoints()
    hit:SetScript("OnClick", function(self) GoTo(self.index) end)
    hit:SetScript("OnEnter", function(self)
        self.shade:SetColorTexture(ns.RXPWindowColor("line"))
        self.shade:Show()
        Tip(self, TEXT_GO:format(self.index or 0))
    end)
    hit:SetScript("OnLeave", function(self)
        self.shade:Hide()
        GameTooltip:Hide()
    end)
    Draggable(hit)
    return hit
end

local MAKERS = { box = MakeBox, row = MakeRow, line = MakeLine, hit = MakeHit }

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
        for i = 1, #list do
            list[i]:Hide()
            if kind == "box" then list[i].bar:Hide() end
        end
        used[kind] = 0
    end
end

local function Watch(source)
    if type(source) ~= "table" or watched[source] or not Has(source, "SetText") then return end
    watched[source] = true
    hooksecurefunc(source, "SetText", Guarded("WindowText", Refresh))
end

local function Spacing()
    return ns.RXPWindowOption("rxpWindowSpacing")
end

local function DrawRow(box, row, x, y, width)
    local item = Acquire("row")
    item:SetParent(box)
    item.source = row.button
    item:ClearAllPoints()
    item:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
    item:SetWidth(width)
    local gap = Spacing()
    local textWidth = width - BAR_W - gap - ICON_W
    item.bar:ClearAllPoints()
    item.bar:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
    item.bar:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 0, 0)
    item.bar:SetWidth(BAR_W)
    local a = row.done and "done" or "label"
    item.bar:SetColorTexture(ns.RXPWindowColor(a))
    item.icon:ClearAllPoints()
    item.icon:SetPoint("TOPLEFT", item, "TOPLEFT", BAR_W + gap, 0)
    item.icon:SetText(row.icon)
    item.text:ClearAllPoints()
    item.text:SetPoint("TOPLEFT", item, "TOPLEFT", BAR_W + gap + ICON_W, 0)
    item.text:SetWidth(textWidth)
    Coloured(item.text, row.done and "done" or "text")
    item.text:SetText(row.text)
    local height = math.max(item.text:GetStringHeight(), ns.RXPWindowOption("rxpWindowTextSize"))
    if row.need and row.need >= COUNT_MIN and ns.RXPWindowOption("rxpWindowCountBar") then
        local fraction = row.done and 1 or math.min(1, math.max(0, (row.have or 0) / row.need))
        item.meter:ClearAllPoints()
        item.meter:SetPoint("TOPLEFT", item, "TOPLEFT", BAR_W + gap + ICON_W, -(height + COUNT_GAP))
        item.meter:SetWidth(textWidth)
        PaintBar(item.meter, fraction)
        item.meter:Show()
        height = height + COUNT_GAP + ns.RXPWindowOption("rxpWindowBarHeight")
        if row.bags then wantsBags = true end
    else
        item.meter:Hide()
    end
    item:SetHeight(height)
    Watch(row.source)
    return height
end

local function DrawBox(step, y, inner, current)
    local box = Acquire("box")
    local gap = Spacing()
    local size = ns.RXPWindowOption("rxpWindowTextSize")
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
    box:SetWidth(inner)
    local boxR, boxG, boxB = ns.RXPWindowColor("box")
    box.back:SetColorTexture(boxR, boxG, boxB, ns.RXPWindowOption("rxpWindowBoxOpacity") / PERCENT)
    local r, g, b, a = ns.RXPWindowColor("boxEdge")
    box.edge:SetColor(r, g, b, a)
    box.edge._frame:SetShown(ns.RXPWindowOption("rxpWindowBoxBorder"))
    box.label:ClearAllPoints()
    box.label:SetPoint("TOPLEFT", box, "TOPLEFT", BOX_PAD, -BOX_PAD)
    Coloured(box.label, "label")
    box.label:SetText(step.label:upper())
    local head = size
    if current and ns.RXPWindowOption("rxpWindowLogo") then
        local logo = ns.RXPWindowOption("rxpWindowLogoSize")
        box.logo:ClearAllPoints()
        box.logo:SetPoint("TOPRIGHT", box, "TOPRIGHT", -BOX_PAD, -BOX_PAD)
        box.logo:SetSize(logo, logo)
        box.logo:Show()
        head = math.max(size, logo)
    else
        box.logo:Hide()
    end
    local by = -BOX_PAD - head - gap
    local indent = ns.RXPWindowOption("rxpWindowIndent")
    for i, row in ipairs(step.rows) do
        local set = i > 1 and indent or 0
        by = by - DrawRow(box, row, BOX_PAD + set, by, inner - BOX_PAD * 2 - set) - gap
    end
    box:SetHeight(-by + BOX_PAD - gap)
    local bottom = y + by - BOX_PAD
    -- the objectives done are a divider under the box, as the guide's is under the title
    if ns.RXPWindowOption("rxpWindowStepBar") and #step.rows > 0 then
        local top = bottom
        box.bar:ClearAllPoints()
        box.bar:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, top)
        box.bar:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, top)
        PaintBar(box.bar, step.done / #step.rows)
        box.bar:Show()
        bottom = top - ns.RXPWindowOption("rxpWindowBarHeight") - gap
    else
        box.bar:Hide()
    end
    return bottom
end

local function DrawHeader(model, folded, width, headH)
    window.fold:SetSize(FOLD_W, headH)
    window.fold:ClearAllPoints()
    window.fold:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -PAD)
    window.fold.text:SetText(folded and TEXT_UNFOLD or TEXT_FOLD)
    Coloured(window.fold.text, "line")
    window.title:ClearAllPoints()
    window.title:SetPoint("TOPLEFT", window, "TOPLEFT", PAD + FOLD_W + Spacing(), -PAD)
    window.title:SetWidth(width - PAD * 2 - FOLD_W - Spacing() - PROGRESS_W)
    Coloured(window.title, "title")
    window.title:SetText(model.heading)
    window.progress:ClearAllPoints()
    window.progress:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, -PAD)
    if model.step and ns.RXPWindowOption("rxpWindowProgressText") then
        window.progress:SetText(Tint("progress", ("%d/%d"):format(model.step, model.total)) .. TEXT_DOT
            .. Tint("percent", ("%d%%"):format(model.percent)))
    else
        window.progress:SetText("")
    end
    window.progress:SetTextColor(1, 1, 1, 1)
end

-- The line under the title: a bar of how far the guide is, a plain line, or nothing. Returns where the rest
-- begins.
local function DrawLine(model, y)
    local line = ns.RXPWindowOption("rxpWindowLine")
    local gap = Spacing()
    window.rule:Hide()
    window.bar:Hide()
    if line == "bar" then
        window.bar:ClearAllPoints()
        window.bar:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
        window.bar:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, y)
        PaintBar(window.bar, model.fraction or 0)
        window.bar:Show()
        return y - ns.RXPWindowOption("rxpWindowBarHeight") - gap
    elseif line == "rule" then
        window.rule:ClearAllPoints()
        window.rule:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
        window.rule:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, y)
        window.rule:SetColorTexture(ns.RXPWindowColor("line"))
        window.rule:Show()
        return y - gap
    end
    return y
end

function Draw()
    if not active then return end
    wantsBags = false
    if not sizing then Quiet("WindowSkin", Skin) end
    window = window or Build()
    if not sizing then Take() end
    local model = sizing and sizingModel or Read()
    if not model then
        window:Hide()
        return
    end
    Reset()
    Refaced()
    local width = sizing and sizing.width or ns.RXPWindowWidth()
    local inner = width - PAD * 2
    local folded = Settings().rxpWindowCollapsed == true
    local headH = ns.RXPWindowOption("rxpWindowTitleSize") + HEAD_PAD
    local gap = Spacing()
    local listH = ns.RXPWindowOption("rxpWindowListSize") + LIST_PAD
    if not sizing then window:SetWidth(width) end
    window.back:SetColorTexture(ns.RXPWindowColor("panel"))
    window.back:SetShown(ns.RXPWindowOption("rxpWindowPanel"))
    window.edge:SetColor(ns.RXPWindowColor("edge"))
    window.edge._frame:SetShown(ns.RXPWindowOption("rxpWindowBorder"))
    DrawHeader(model, folded, width, headH)
    local y = DrawLine(model, -PAD - headH)
    if not folded then
        for i, step in ipairs(model.steps) do y = DrawBox(step, y, inner, i == 1) end
        for i = 1, sizing and sizing.steps or #model.upcoming do
            local entry = model.upcoming[i]
            if not entry then break end
            local item = Acquire("line")
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
            item:SetWidth(inner)
            Coloured(item, "list")
            item:SetText(("%d  %s"):format(entry.index, entry.text))
            local hit = Acquire("hit")
            hit:ClearAllPoints()
            hit:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
            hit:SetSize(inner, listH)
            hit.index = entry.index
            hit.shade:Hide()
            y = y - listH
        end
    end
    window.menu:ClearAllPoints()
    if folded or not ns.RXPWindowOption("rxpWindowMenu") then
        window.menu:Hide()
    else
        window.menu:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y - gap)
        window.menu:Show()
        y = y - gap - MENU_SIZE
    end
    if not sizing then window:SetHeight(-y + PAD) end
    if wantsBags then window:RegisterEvent(BAG_EVENT) else window:UnregisterEvent(BAG_EVENT) end
    window.lineHeight = listH
    window.chrome = -y + PAD - used.line * listH
    local locked = ns.RXPWindowOption("rxpWindowLock")
    window:SetResizable(not locked and not folded)
    if Has(window, "SetResizeBounds") then
        window:SetResizeBounds(WIDTH_MIN, window.chrome, WIDTH_MAX, window.chrome + STEPS_MAX * listH)
    end
    window.grip:SetShown(ns.RXPWindowOption("rxpWindowGrip") and not folded)
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
        if window then
            window:Hide()
            window:UnregisterEvent(BAG_EVENT)
        end
        Quiet("WindowSkin", Skin)
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

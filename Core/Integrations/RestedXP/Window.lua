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
local BAR_W, ICON_GAP, GRIP_SIZE = 2, 5, 16
local FIRST_GROW, FIRST_ICON_GROW, LOGO_SIZE, BAR_HEIGHT, INDENT, ICON_SIZE = 2, 2, 24, 5, 12, 18
local PANEL_ALPHA, EDGE_ALPHA, RULE_ALPHA, MUTED_ALPHA, HOVER_ALPHA = 0.92, 0.8, 0.5, 0.9, 0.25
local BOX_OPACITY = 55
local COUNT_PATTERN, COUNT_MIN, COUNT_GAP = "(%d+)%s*/%s*(%d+)", 2, 2
local BAG_EVENT = "BAG_UPDATE_DELAYED"
local SHADOW, SHADOW_ALPHA = 1, 0.9
local TEXT_FOLD, TEXT_UNFOLD, TEXT_DOT = "-", "+", " \194\183 "
local LOGO = "Interface\\AddOns\\RXPGuides\\Textures\\rxp_logo-64"
local GRADIENT = ns.MEDIA .. "NaowhGradient.tga"
local TEXT_GRADIENT = "Naowh Gradient"
local GRIP_UP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
local GRIP_DOWN = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down"
local GRIP_HIGHLIGHT = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"
local GRIP_CORNER = "BOTTOMRIGHT"
local TEXT_STEP = "Step %d"
local TEXT_SKIP = "Skip step"
local TEXT_SHIFT = "Shift-click"
local TEXT_MENU = "Right-click: menu"
local TEXT_GO = "Go to step %d"
local TEXT_NO_GUIDE, TEXT_PICK = "No guide selected", "Pick a guide"
local TIP_DIM = 0.7
local HOME = { "LEFT", "LEFT", 0, 35 }
local DRAG_BUTTON, TIP_ANCHOR = "LeftButton", "ANCHOR_TOP"
local COLORS_KEY = "rxpWindowColors"
local THEME_KEY = "rxpWindowTheme"
local CUSTOM = "custom"
local FOLLOW = ""
local FOREVER = "forever"
local ACCENT = "accent"
local TARGET_PLACEHOLDER, MOB_PLACEHOLDER = 2056011, 135274
local PLACEHOLDER_GLYPHS = { [TARGET_PLACEHOLDER] = "gossip", [MOB_PLACEHOLDER] = "combat" }

-- Everything the window can be changed in, in the order a page lists it. A saved value is only kept when it
-- is not the default, as in the other settings of this integration.
local OUTLINES = { shadow = "Shadow", outline = "Outline", thick = "Thick Outline", none = "None" }
local SKIPS = { shift = "Shift-click", click = "Click", off = "Off" }
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
    { key = "rxpWindowLine", group = "Look", kind = "choice", label = "Under the Title", default = "bar",
      values = LINES, order = { "bar", "rule", "none" }, tip = "A progress bar of the guide, a line, or nothing." },
    { key = "rxpWindowGrip", group = "Look", kind = "toggle", label = "Show Resize Grip", default = true,
      tip = "The corner that is dragged to change the window's width and how many steps are listed." },
    { key = "rxpWindowSkip", group = "Look", kind = "choice", label = "Skipping Steps", default = "shift",
      values = SKIPS, order = { "shift", "click", "off" },
      tip = "What it takes to click the active step to skip it, or a step of the list to go to it." },
    { key = "rxpWindowTips", group = "Look", kind = "toggle", label = "Show Tooltips", default = true,
      tip = "What a click on a step does, said when the mouse is over it." },
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
    { key = "rxpWindowSpacing", group = "Look", kind = "number", label = "Spacing", default = 5, min = 0, max = 12,
      tip = "The room between the rows." },
    { key = "rxpWindowBarTexture", group = "Progress", kind = "texture", label = "Bar Texture",
      defaultLabel = TEXT_GRADIENT, tip = "The texture of the progress bars, the Naowh Gradient to start." },
}

-- A color is a theme token and an opacity; a picked one is kept whole. Each is for several things.
local COLORS = {
    { name = "title", label = "Title Color", token = "fg", tip = "The guide's name and its percent." },
    { name = "accent", label = "Accent Color", token = "accent",
      tip = "The level range, the step count, STEP and its number, and the filled part of the bars." },
    { name = "text", label = "Step Text Color", token = "fg", tip = "The rows of the active step." },
    { name = "muted", label = "Muted Text Color", token = "muted", alpha = MUTED_ALPHA,
      tip = "A row that is done and the steps after the active one." },
    { name = "line", label = "Line Color", token = "fg", alpha = RULE_ALPHA, tip = "The line and the bars' track." },
    { name = "box", label = "Step Box Color", token = "bg", opaque = true,
      tip = "Behind the active step; its opacity is its own setting." },
    { name = "border", label = "Border Color", token = "line", alpha = EDGE_ALPHA,
      tip = "Round the active step and round the whole window." },
    { name = "panel", label = "Window Color", token = "panel", alpha = PANEL_ALPHA, tip = "Behind the whole window." },
    { name = "arrow", label = "Arrow Color", token = "accent", tip = "RestedXP's waypoint arrow." },
}

local OPTION_BY_KEY, COLOR_BY_NAME = {}, {}
for _, option in ipairs(OPTIONS) do OPTION_BY_KEY[option.key] = option end
for _, color in ipairs(COLORS) do COLOR_BY_NAME[color.name] = color end

local window, active, started, pending, skinned, wantsBags
local sizing, sizingModel
local pool, used = { box = {}, row = {}, line = {}, hit = {} }, { box = 0, row = 0, line = 0, hit = 0 }
local silenced = setmetatable({}, { __mode = "k" })
local watched = setmetatable({}, { __mode = "k" })
local placeholders = setmetatable({}, { __mode = "k" })
local targetingHooked = {}
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

-- The window has a theme of its own: the addon's to start, one of the presets, or Custom. It is the window's
-- colors only; the addon's theme is not read or changed by it, and a change shows at once.
local function RepaintArrow()
    if type(ns.RXPPaintArrow) == "function" then ns.RXPPaintArrow() end
end

local function IsPreset(key)
    return type(key) == "string" and type(ns.THEME_PRESETS) == "table" and ns.THEME_PRESETS[key] ~= nil
end

-- The Forever skin's gold and bronze, and its face, for the window alone, without the addon's skin.
local function IsTheme(key)
    return key == CUSTOM or key == FOREVER or IsPreset(key)
end

function ns.RXPWindowThemeKey()
    local key = Settings()[THEME_KEY]
    if IsTheme(key) then return key end
    return FOLLOW
end

function ns.SetRXPWindowTheme(key)
    Settings()[THEME_KEY] = IsTheme(key) and key or nil
    Refresh()
    RepaintArrow()
end

-- The colors are the theme's, and the player's own only when the theme is Custom: a theme is a look as a whole.
function ns.RXPWindowOwnColors()
    return ns.RXPWindowThemeKey() == CUSTOM
end

function ns.RXPWindowColor(name)
    local color = COLOR_BY_NAME[name]
    if not color then return 1, 1, 1, 1 end
    local saved = ns.RXPWindowOwnColors() and Dig(Settings(), COLORS_KEY, name)
    if type(saved) == "table" and type(saved.r) == "number" and type(saved.g) == "number"
            and type(saved.b) == "number" then
        return saved.r, saved.g, saved.b, type(saved.a) == "number" and saved.a or 1
    end
    local key = ns.RXPWindowThemeKey()
    local source = (key == FOREVER and ns.FOREVER_SKIN) or (IsPreset(key) and ns.THEME_PRESETS[key]) or nil
    local preset = type(source) == "table" and source[color.token]
    local base = type(preset) == "table" and preset or ns.THEME[color.token]
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
    RepaintArrow()
end

function ns.ResetRXPWindowStyle()
    for _, option in ipairs(OPTIONS) do Settings()[option.key] = nil end
    Settings()[COLORS_KEY] = nil
    Settings()[THEME_KEY] = nil
    Refresh()
    RepaintArrow()
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
    return range and (place .. " " .. Tint("accent", range)) or place
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
-- RestedXP is there and has no guide: what a character that has not picked one has
local function NoGuide()
    local rxp = _G.RXP
    if type(rxp) ~= "table" then return nil end
    local guide = rxp.currentGuide
    if type(guide) == "table" and not guide.empty and type(guide.steps) == "table" then return nil end
    return { heading = TEXT_NO_GUIDE, steps = {}, upcoming = {}, empty = true }
end

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
        local rows = {}
        for _, element in ipairs(activeStep.elements or {}) do
            if type(element) == "table" and (element.text or element.rawtext or element.tooltipText) then
                local row = Row(rxp, element)
                row.step = activeStep
                rows[#rows + 1] = row
            end
        end
        model.steps[#model.steps + 1] = { label = StepLabel(rxp, activeStep), rows = rows, source = activeStep }
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
                    if silenced[self] and alpha ~= 0 then self:SetAlpha(0) end
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
        silenced[frame] = nil
        if home.alpha ~= nil and Has(frame, "SetAlpha") then frame:SetAlpha(home.alpha) end
        if home.mouse ~= nil and Has(frame, "EnableMouse") then frame:EnableMouse(home.mouse) end
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

-- RestedXP's list of guides, as its own welcome window opens it, or its menu when it has no such list
local function PickGuide()
    local v2 = Dig(_G.RXP, "v2")
    if Has(v2, "ShowGuideSelectionMenu") then
        Quiet("WindowPick", v2.ShowGuideSelectionMenu, v2)
    else
        Menu()
    end
end

local function FacePath()
    local name = ns.RXPWindowOption("rxpWindowFont")
    local custom = name ~= "" and type(ns.UI) == "table" and ns.UI.FontPath and ns.UI.FontPath(name)
    return custom or ns.AddonFontPath(ns.RXPWindowThemeKey() == FOREVER or nil)
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
    Faced(fs, type(sizeKey) == "number" and sizeKey or ns.RXPWindowOption(sizeKey))
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
    local r, g, b, a = ns.RXPWindowColor("border")
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
    Coloured(text, "title")
    if Has(title, "SetSize") then title:SetSize(text:GetStringWidth() + BOX_TITLE_ROOM, BOX_TITLE_HEIGHT) end
end

local function SkinPlaceholders(frame)
    if type(ns.RXPIconTexture) ~= "function" or not Has(frame, "GetChildren") then return end
    for _, button in ipairs({ frame:GetChildren() }) do
        local texture = Dig(button, "placeholder")
        if Has(texture, "GetTexture") and Has(texture, "SetTexture") then
            local id = texture:GetTexture()
            local glyph = PLACEHOLDER_GLYPHS[id]
            local path = glyph and ns.RXPIconTexture(glyph)
            if path then
                placeholders[texture] = id
                texture:SetTexture(path)
            end
        end
    end
end

local function RestorePlaceholders()
    for texture, id in pairs(placeholders) do
        placeholders[texture] = nil
        if Has(texture, "SetTexture") then texture:SetTexture(id) end
    end
end

local function SkinFrame(frame)
    SkinBox(frame)
    if type(frame.title) == "table" then SkinTitle(frame.title) end
    SkinPlaceholders(frame)
end

local function SkinWanted()
    return active
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
    if not targetingHooked.background and Has(targeting, "RenderTargetFrameBackground") then
        targetingHooked.background = true
        hooksecurefunc(targeting, "RenderTargetFrameBackground", Guarded("WindowSkin", function()
            local target = Dig(_G.RXP, "targeting", "activeTargetFrame")
            if SkinWanted() and type(target) == "table" then SkinBox(target) end
        end))
    end
    if not targetingHooked.update and Has(targeting, "UpdateTargetFrame") then
        targetingHooked.update = true
        hooksecurefunc(targeting, "UpdateTargetFrame", Guarded("WindowSkin", function()
            local target = Dig(_G.RXP, "targeting", "activeTargetFrame")
            if SkinWanted() and type(target) == "table" then SkinPlaceholders(target) end
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
        RestorePlaceholders()
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

-- a step that stays while the guide goes on (a trainer to see, say) is not the guide's progress: skipping
-- it is its objectives skipped, as RestedXP's checkboxes do, and RestedXP then lets it go
local function SkipObjectives(rxp, step)
    for _, element in ipairs(step.elements or {}) do
        if type(element) == "table" and not element.optional and not element.skip then
            element.skip = true
            if type(element.OnComplete) == "function" then Quiet("WindowComplete", element.OnComplete, element) end
        end
    end
    rxp.updateSteps = true
    if Has(rxp, "UpdateMap") then Quiet("WindowMap", rxp.UpdateMap) end
end

local function SkipStep(step)
    local rxp = _G.RXP
    local progress = Has(rxp, "GetGuideProgress") and Run("WindowProgress", rxp.GetGuideProgress)
    if type(progress) ~= "number" then return end
    if type(step) == "table" and type(step.index) == "number" and step.index ~= progress then
        SkipObjectives(rxp, step)
    else
        GoTo(progress + 1)
    end
end

local function MaySkip()
    local mode = ns.RXPWindowOption("rxpWindowSkip")
    return mode == "click" or (mode == "shift" and IsShiftKeyDown())
end

local function Tip(owner, text, menu, plain)
    if not ns.RXPWindowOption("rxpWindowTips") or GameTooltip:IsForbidden() then return end
    local mode = ns.RXPWindowOption("rxpWindowSkip")
    GameTooltip:SetOwner(owner, TIP_ANCHOR)
    local r, g, b = ns.RXPWindowColor(ACCENT)
    if plain then
        GameTooltip:SetText(text, r, g, b)
    elseif mode == "off" then
        GameTooltip:SetText(TEXT_MENU, r, g, b)
    else
        GameTooltip:SetText(text, r, g, b)
        if mode == "shift" then GameTooltip:AddLine(TEXT_SHIFT, TIP_DIM, TIP_DIM, TIP_DIM) end
        if menu then GameTooltip:AddLine(TEXT_MENU, TIP_DIM, TIP_DIM, TIP_DIM) end
    end
    GameTooltip:Show()
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

-- The window is in the Forever skin's art when its theme is Forever, or is the addon's and the addon is in the
-- skin: the bronze inset on the step box and the window, the skin's field and rim on the bars, its sign to fold.
local function SkinParts()
    local shared = type(ns.Shared) == "table" and ns.Shared or nil
    local parts = shared and shared.Parts
    if type(parts) == "table" and parts.ForeverInset and parts.ForeverBox and parts.ForeverAtlas then
        return parts, shared.Style
    end
end

local function Skinned()
    if not SkinParts() then return false end
    local key = ns.RXPWindowThemeKey()
    return key == FOREVER or (key == FOLLOW and ns.foreverSkin == true)
end

-- A bronze inset behind a frame, drawn under what the frame holds.
local function SkinInset(frame, on)
    if on then
        if not frame.inset then
            local parts = SkinParts()
            frame.inset = parts.ForeverInset(frame)
            frame.inset:SetAllPoints(frame)
            local level = frame:GetFrameLevel()
            if type(level) == "number" then frame.inset:SetFrameLevel(math.max(0, level - 1)) end
        end
        frame.inset:Show()
    elseif frame.inset then
        frame.inset:Hide()
    end
end

local function PaintBar(bar, fraction)
    bar:SetStatusBarTexture(TexturePath())
    local r, g, b, a = ns.RXPWindowColor("accent")
    bar:SetStatusBarColor(r, g, b, a)
    local parts, style = SkinParts()
    local skinned = Skinned()
    if skinned and not bar.rim then bar.rim = parts.ForeverBox(bar) end
    if bar.rim then bar.rim._frame:SetShown(skinned) end
    if skinned and style and style.FOREVER_FIELD_RGB then
        local field = style.FOREVER_FIELD_RGB
        bar.track:SetColorTexture(field.r, field.g, field.b, 1)
    else
        r, g, b, a = ns.RXPWindowColor("line")
        bar.track:SetColorTexture(r, g, b, a)
    end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(fraction)
    bar:SetHeight(BAR_HEIGHT)
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
    f.fold.sign = f.fold:CreateTexture(nil, "OVERLAY")
    f.fold.sign:SetPoint("CENTER")
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
    f:SetScript("OnSizeChanged", function(_, width, height) LiveSize(width, height) end)
    f.grip = MakeGrip(f)
    Place(f)
    return f
end

local function MakeBox()
    local T = ns.THEME
    local box = CreateFrame("Button", nil, window)
    box:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    box:SetScript("OnClick", function(self, button)
        if button == "RightButton" then return Menu() end
        if MaySkip() then SkipStep(self.step) end
    end)
    box:SetScript("OnEnter", function(self) Tip(self, TEXT_SKIP, true) end)
    box:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Draggable(box)
    box.back = ns.Solid(box, "BACKGROUND", T.bg, 1)
    box.back:SetAllPoints()
    box.edge = ns.Border(box, T.line, EDGE_ALPHA)
    box.label = Text(box, "rxpWindowTextSize")
    box.logo = box:CreateTexture(nil, "OVERLAY")
    box.logo:SetTexture(LOGO)
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
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then return Menu() end
        if MaySkip() then SkipStep(self.step) end
    end)
    row:SetScript("OnEnter", function(self) Tip(self.box or self, TEXT_SKIP, true) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.bar = ns.Solid(row, "ARTWORK", ns.THEME.accent, 1)
    row.icon = Text(row, ICON_SIZE)
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
    hit:SetScript("OnClick", function(self)
        if self.menu then return PickGuide() end
        if MaySkip() then GoTo(self.index) end
    end)
    hit:SetScript("OnEnter", function(self)
        if not self.menu and ns.RXPWindowOption("rxpWindowSkip") == "off" then return end
        local r, g, b = ns.RXPWindowColor(ACCENT)
        self.shade:SetColorTexture(r, g, b, HOVER_ALPHA)
        self.shade:Show()
        if self.menu then
            Tip(self, TEXT_PICK, false, true)
        else
            Tip(self, TEXT_GO:format(self.index or 0))
        end
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

local function DrawRow(box, row, x, y, width, first)
    local item = Acquire("row")
    item:SetParent(box)
    item.box = box
    item.step = row.step
    item:ClearAllPoints()
    item:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
    item:SetWidth(width)
    local gap = Spacing()
    local iconSize = ICON_SIZE
    local textSize = ns.RXPWindowOption("rxpWindowTextSize")
    if first then
        textSize = textSize + FIRST_GROW
        iconSize = iconSize + FIRST_GROW * FIRST_ICON_GROW
    end
    local iconW = iconSize + ICON_GAP
    local drop = math.max(0, math.floor((iconSize - textSize) / 2))
    local textWidth = width - BAR_W - gap - iconW
    item.bar:ClearAllPoints()
    item.bar:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
    item.bar:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 0, 0)
    item.bar:SetWidth(BAR_W)
    item.bar:SetShown(not first)
    local a = row.done and "muted" or "accent"
    item.bar:SetColorTexture(ns.RXPWindowColor(a))
    item.icon:ClearAllPoints()
    item.icon:SetPoint("TOPLEFT", item, "TOPLEFT", BAR_W + gap, 0)
    Faced(item.icon, iconSize)
    item.icon:SetText(row.icon)
    item.text:ClearAllPoints()
    item.text:SetPoint("TOPLEFT", item, "TOPLEFT", BAR_W + gap + iconW, -drop)
    item.text:SetWidth(textWidth)
    Coloured(item.text, row.done and "muted" or "text")
    Faced(item.text, textSize)
    item.text:SetText(row.text)
    local height = math.max(drop + math.max(item.text:GetStringHeight(), textSize), iconSize)
    if row.need and row.need >= COUNT_MIN then
        local fraction = row.done and 1 or math.min(1, math.max(0, (row.have or 0) / row.need))
        item.meter:ClearAllPoints()
        item.meter:SetPoint("TOPLEFT", item, "TOPLEFT", BAR_W + gap + iconW, -(height + COUNT_GAP))
        item.meter:SetWidth(textWidth)
        PaintBar(item.meter, fraction)
        item.meter:Show()
        height = height + COUNT_GAP + BAR_HEIGHT
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
    box.step = step.source
    local gap = Spacing()
    local size = ns.RXPWindowOption("rxpWindowTextSize")
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
    box:SetWidth(inner)
    local boxR, boxG, boxB = ns.RXPWindowColor("box")
    local opacity = ns.RXPWindowOption("rxpWindowBoxOpacity") / PERCENT
    local bordered = ns.RXPWindowOption("rxpWindowBoxBorder")
    local skinned = bordered and Skinned()
    SkinInset(box, skinned)
    if skinned then box.inset.fill:SetColorTexture(boxR, boxG, boxB, opacity) end
    box.back:SetColorTexture(boxR, boxG, boxB, opacity)
    box.back:SetShown(not skinned)
    local r, g, b, a = ns.RXPWindowColor("border")
    box.edge:SetColor(r, g, b, a)
    box.edge._frame:SetShown(bordered and not skinned)
    box.label:ClearAllPoints()
    box.label:SetPoint("TOPLEFT", box, "TOPLEFT", BOX_PAD, -BOX_PAD)
    Coloured(box.label, "accent")
    box.label:SetText(step.label:upper())
    local head = size
    if current then
        box.logo:ClearAllPoints()
        box.logo:SetPoint("TOPRIGHT", box, "TOPRIGHT", -BOX_PAD, -BOX_PAD)
        box.logo:SetSize(LOGO_SIZE, LOGO_SIZE)
        box.logo:Show()
        head = math.max(size, LOGO_SIZE)
    else
        box.logo:Hide()
    end
    local by = -BOX_PAD - head - gap
    for i, row in ipairs(step.rows) do
        local set = i > 1 and INDENT or 0
        by = by - DrawRow(box, row, BOX_PAD + set, by, inner - BOX_PAD * 2 - set, i == 1) - gap
    end
    box:SetHeight(-by + BOX_PAD - gap)
    return y + by - BOX_PAD
end

local function DrawHeader(model, folded, width, headH)
    window.fold:SetSize(FOLD_W, headH)
    window.fold:ClearAllPoints()
    window.fold:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -PAD)
    window.fold.text:SetText(folded and TEXT_UNFOLD or TEXT_FOLD)
    local parts, style = SkinParts()
    local name = style and Skinned() and (folded and style.FOREVER_PLUS_ATLAS or style.FOREVER_MINUS_ATLAS)
    local sign = type(name) == "string" and parts.ForeverAtlas(window.fold.sign, name, true) == true
    window.fold.sign:SetShown(sign)
    window.fold.text:SetShown(not sign)
    Coloured(window.fold.text, "line")
    window.title:ClearAllPoints()
    window.title:SetPoint("TOPLEFT", window, "TOPLEFT", PAD + FOLD_W + Spacing(), -PAD)
    window.title:SetWidth(width - PAD * 2 - FOLD_W - Spacing() - PROGRESS_W)
    Coloured(window.title, "title")
    window.title:SetText(model.heading)
    window.progress:ClearAllPoints()
    window.progress:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, -PAD)
    if model.step then
        window.progress:SetText(Tint("accent", ("%d/%d"):format(model.step, model.total)) .. TEXT_DOT
            .. Tint("title", ("%d%%"):format(model.percent)))
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
        return y - BAR_HEIGHT - gap
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
    local model = sizing and sizingModel or Read() or NoGuide()
    if not model then
        Release()
        window:Hide()
        return
    end
    if not sizing then Take() end
    Reset()
    Refaced()
    local width = sizing and sizing.width or ns.RXPWindowWidth()
    local inner = width - PAD * 2
    local folded = Settings().rxpWindowCollapsed == true
    local headH = ns.RXPWindowOption("rxpWindowTitleSize") + HEAD_PAD
    local gap = Spacing()
    local listH = ns.RXPWindowOption("rxpWindowListSize") + LIST_PAD
    if not sizing then window:SetWidth(width) end
    local panelOn, borderOn = ns.RXPWindowOption("rxpWindowPanel"), ns.RXPWindowOption("rxpWindowBorder")
    local skinned = borderOn and Skinned()
    SkinInset(window, skinned)
    if skinned then
        local pr, pg, pb, pa = ns.RXPWindowColor("panel")
        window.inset.fill:SetColorTexture(pr, pg, pb, panelOn and pa or 0)
    end
    window.back:SetColorTexture(ns.RXPWindowColor("panel"))
    window.back:SetShown(panelOn and not skinned)
    window.edge:SetColor(ns.RXPWindowColor("border"))
    window.edge._frame:SetShown(borderOn and not skinned)
    DrawHeader(model, folded, width, headH)
    local y = DrawLine(model, -PAD - headH)
    if not folded then
        if model.empty then
            local item = Acquire("line")
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
            item:SetWidth(inner)
            Coloured(item, "muted")
            item:SetText(TEXT_PICK)
            local hit = Acquire("hit")
            hit:ClearAllPoints()
            hit:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
            hit:SetSize(inner, listH)
            hit.index, hit.menu = nil, true
            hit.shade:Hide()
            y = y - listH
        end
        for i, step in ipairs(model.steps) do y = DrawBox(step, y, inner, i == 1) end
        for i = 1, sizing and sizing.steps or #model.upcoming do
            local entry = model.upcoming[i]
            if not entry then break end
            local item = Acquire("line")
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
            item:SetWidth(inner)
            Coloured(item, "muted")
            item:SetText(("%d  %s"):format(entry.index, entry.text))
            local hit = Acquire("hit")
            hit:ClearAllPoints()
            hit:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, y)
            hit:SetSize(inner, listH)
            hit.index, hit.menu = entry.index, false
            hit.shade:Hide()
            y = y - listH
        end
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
    window.grip:SetShown(ns.RXPWindowOption("rxpWindowGrip") and not folded and not locked)
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
    if on then
        if type(ns.RXPArrowKept) == "function" then ns.RXPArrowKept() end
        Settings().rxpThemes = nil
    end
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

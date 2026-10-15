-- test-border-pixels.lua: ns.Hairline and ns.Border of Core/Core.lua, which draw an edge of one pixel and, when
-- asked, of more. Run with Lua 5.1 from the repository root.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"); f:close()
    return s
end

local cases = 0
local function Check(ok, label) assert(ok, label); cases = cases + 1 end

local pixel = 0.5
local frames = {}

local function Object(kind, parent)
    local o = { kind = kind, parent = parent, scripts = {}, level = 1, scale = 1, textures = {} }
    setmetatable(o, { __index = function(_, key)
        if type(key) == "string" and key:find("^%u") then return function() end end
    end })
    function o:GetObjectType() return self.kind end
    function o:GetParent() return self.parent end
    function o:GetEffectiveScale() return self.scale end
    function o:GetFrameLevel() return self.level end
    function o:SetFrameLevel(level) self.level = level end
    function o:SetHeight(height) self.height = height end
    function o:SetWidth(width) self.width = width end
    function o:SetScript(name, fn) self.scripts[name] = fn end
    function o:IsVisible() return true end
    function o:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function o:CreateTexture()
        local t = Object("Texture", self)
        self.textures[#self.textures + 1] = t
        return t
    end
    return o
end

local env = {}
env._G = env
env.UIParent = Object("Frame")
env.CreateFrame = function(_, _, parent)
    local f = Object("Frame", parent)
    frames[#frames + 1] = f
    return f
end
env.PixelUtil = { GetPixelToUIUnitFactor = function() return pixel end }
env.hooksecurefunc = function() end
env.C_Timer = { After = function() end }
env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
env.CreateColor = function(r, g, b, a) return { r, g, b, a } end
env.InCombatLockdown = function() return false end
env.C_AddOns = { DoesAddOnExist = function() return false end }
env.NaowhForeverDB = { account = {}, profiles = {}, charActive = {} }
setmetatable(env, { __index = _G })
for _, part in ipairs({ { "Core/Core.lua", "Core" }, { "Core/Features.lua", "Features" } }) do
    local chunk = assert(loadstring(Read(part[1]), part[2]))
    setfenv(chunk, env)
    chunk("NaowhForever")
end
local ns = env.NaowhForever

local owner = Object("Frame")
local top, side = owner:CreateTexture(), owner:CreateTexture()
ns.Hairline(top, "h")
ns.Hairline(side, "v", 3)
Check(top.height == pixel, "a hairline is one pixel")
Check(side.width == 3 * pixel, "or as many as it is asked for")

local card = Object("Frame")
local border = ns.Border(card)
local edges
for _, frame in ipairs(frames) do
    if #frame.textures == 4 then edges = frame.textures end
end
Check(edges and border._frame and type(border.SetPixels) == "function", "a border has four edges and can be sized")
Check(edges[1].height == pixel and edges[2].height == pixel and edges[3].width == pixel and edges[4].width == pixel,
    "each one pixel to start, as every border was")

border:SetPixels(3)
Check(edges[1].height == 3 * pixel and edges[2].height == 3 * pixel and edges[3].width == 3 * pixel
    and edges[4].width == 3 * pixel, "three pixels when asked")
border:SetColor(1, 0, 0, 0.5)
Check(edges[1].color[1] == 1 and edges[4].color[4] == 0.5, "and the color is every edge's")

pixel = 1
ns.RefitPixels()
Check(edges[1].height == 3 and edges[3].width == 3, "the size is kept in pixels: a change of scale refits it")
border:SetPixels(1)
Check(edges[2].height == 1 and edges[4].width == 1, "and one pixel again")

print(("PASS border pixels: %d checks"):format(cases))

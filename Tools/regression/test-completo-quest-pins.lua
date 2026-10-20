-- Run with Lua 5.1 from the repository root: Completo's quest giver pins on the world map are
-- Pin Size on the small map and the full screen map alike, and keep one size on screen as the
-- map zooms. While Ctrl is held they take no clicks, so a Ctrl+Click reaches the map's waypoint.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local settings = { enabled = true, mapPins = true, mapPinSize = 20 }
local S = { Get = function(key) return settings[key] end, Set = function() end }
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, CompletoSettings = S, Apply = function() end, ThemeTint = function() end,
    Completo = { Settings = S, Style = {}, C = { PERCENT = 100 },
        Quests = { Refresh = function() end, Givers = function() return {} end } } }

local maximized, canvasScale = false, 1
local pins = {}
local map = {
    IsShown = function() return true end,
    IsMaximized = function() return maximized end,
    AddDataProvider = function() end,
    GetCanvasScale = function() return canvasScale end,
    GetMapID = function() return 1 end,
    RemoveAllPinsByTemplate = function() end,
    AcquirePin = function() end,
    EnumeratePinsByTemplate = function()
        local i = 0
        return function() i = i + 1; return pins[i] end
    end,
}
local boot, lastFrame
local ctrl = false
local env = setmetatable({
    _G = { NaowhForever = ns },
    CreateFromMixins = function() return { GetMap = function() return map end } end,
    MapCanvasPinMixin = {}, MapCanvasDataProviderMixin = {},
    CreateFrame = function()
        local f = { events = {} }
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterAllEvents() self.events = {} end
        function f:SetScript(name, fn) self[name] = fn end
        if not boot then boot = f end
        lastFrame = f
        return f
    end,
    hooksecurefunc = function() end,
    IsControlKeyDown = function() return ctrl end,
    WorldMapFrame = map,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
}, { __index = _G })
local shared = assert(loadstring(Read("Shared/Shared.lua")))
setfenv(shared, env)
shared()
local chunk = assert(loadstring(Read("NaowhForever_Discovery/QuestList/UI/QuestPins.lua")))
setfenv(chunk, env)
chunk()
boot.OnEvent(boot)

local Pin = env.NaowhForeverQuestGiverPinMixin
local function NewPin()
    local pin = setmetatable({ Icon = { SetAtlas = function() return true end, SetDesaturated = function() end,
        SetVertexColor = function() end } }, { __index = Pin })
    function pin:GetMap() return map end
    function pin:SetSize(w) self.size = w end
    function pin:SetPosition() end
    function pin:SetScale(s) self.scale = s end
    function pin:ApplyCurrentPosition() end
    function pin:EnableMouse(on) self.clicks = on end
    return pin
end

local pin = NewPin()
pin:OnAcquired({ x = 50, y = 50, quests = { 1 } })
Check(pin.size == 20, "Pin Size on the small map")
Check(pin.scale == 0.75, "scaled as it is placed, not only on the next zoom, at half the shared scale")
maximized = true
local big = NewPin()
big:OnAcquired({ x = 50, y = 50, quests = { 1 } })
Check(big.size == 20, "the same Pin Size on the full screen map")
Check(math.abs(big.scale - pin.scale * 1.5) < 1e-9, "drawn half as big again there")
maximized = false

Check(pin.clicks == true, "a placed pin takes clicks")
local watch = lastFrame
ctrl = true
watch.OnEvent(watch, "MODIFIER_STATE_CHANGED", "LSHIFT", 1)
Check(pin.clicks == true, "another modifier changes nothing")
watch.OnEvent(watch, "MODIFIER_STATE_CHANGED", "LCTRL", 1)
Check(pin.clicks == false and big.clicks == false, "no clicks while Ctrl is held")
local held = NewPin()
held:OnAcquired({ x = 50, y = 50, quests = { 1 } })
Check(held.clicks == false, "a pin placed while Ctrl is held takes no clicks either")
ctrl = false
watch.OnEvent(watch, "MODIFIER_STATE_CHANGED", "RCTRL", 0)
Check(pin.clicks == true and held.clicks == true, "clicks again once Ctrl is let go")

Check(Pin.ApplyCurrentScale ~= nil, "scaled by the shared map pin scale, with its own factor")
local onScreen
for _, scale in ipairs({ 0.5, 1, 2.5 }) do
    canvasScale = scale
    pin:ApplyCurrentScale()
    local size = pin.scale * scale
    Check(not onScreen or math.abs(size - onScreen) < 1e-9, "one size on screen at canvas scale " .. scale)
    onScreen = size
end

-- The mark: a dungeon quest's giver is the ! tinted green, a repeatable-only giver the game's blue
-- !, a grey one the game's grey mark.
ns.Completo.Style.DUNGEON_RGB = { r = 0.3, g = 1, b = 0.3 }
ns.Completo.Style.REPEAT_RGB = { r = 0.35, g = 0.7, b = 1 }
local function Mark(giver)
    local seen = {}
    local p = NewPin()
    p.Icon.SetAtlas = function(_, atlas) seen.atlas = atlas; return true end
    p.Icon.SetDesaturated = function(_, on) seen.desaturated = on end
    p.Icon.SetVertexColor = function(_, r, g, b) seen.color = { r, g, b } end
    giver.x, giver.y, giver.quests = 50, 50, { 1 }
    p:OnAcquired(giver)
    return seen
end
local m = Mark({ grey = false, repeatable = false, dungeon = true })
Check(m.atlas == "QuestNormal" and m.desaturated and m.color[2] == 1 and m.color[1] < 1, "a dungeon quest's giver is green")
m = Mark({ grey = false, repeatable = true, dungeon = true })
Check(m.atlas == "QuestNormal" and m.color[2] == 1, "a dungeon quest stays green when it is also repeatable")
m = Mark({ grey = false, repeatable = true, dungeon = false })
Check(m.atlas == "QuestDaily" and not m.desaturated, "a repeatable-only giver gets the game's blue !")
m = Mark({ grey = true, repeatable = true, dungeon = false })
Check(m.atlas == "QuestDaily", "a repeatable-only giver stays blue when its quests no longer give experience")
m = Mark({ grey = true, repeatable = false, dungeon = true })
Check(m.atlas == "TrivialQuests", "a grey dungeon quest stays grey")
m = Mark({ grey = false, repeatable = false, dungeon = false })
Check(m.atlas == "QuestNormal" and not m.desaturated and m.color[1] == 1, "any other giver keeps the yellow !")

print(("test-completo-quest-pins: %d checks passed"):format(checks))

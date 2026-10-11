-- Run with Lua 5.1 from the repository root: Completo's quest giver pins on the world map are
-- Pin Size on the small map and the full screen map alike, and keep one size on screen as the
-- map zooms.
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
local boot
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
        return f
    end,
    hooksecurefunc = function() end,
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
    return pin
end

local pin = NewPin()
pin:OnAcquired({ x = 50, y = 50, quests = { 1 } })
Check(pin.size == 20, "Pin Size on the small map")
Check(pin.scale == 1.5, "scaled as it is placed, not only on the next zoom")
maximized = true
local big = NewPin()
big:OnAcquired({ x = 50, y = 50, quests = { 1 } })
Check(big.size == 20, "the same on the full screen map")

Check(Pin.ApplyCurrentScale == ns.Shared.ScalePin, "scaled by the shared map pin scale")
local onScreen
for _, scale in ipairs({ 0.5, 1, 2.5 }) do
    canvasScale = scale
    pin:ApplyCurrentScale()
    local size = pin.scale * scale
    Check(not onScreen or math.abs(size - onScreen) < 1e-9, "one size on screen at canvas scale " .. scale)
    onScreen = size
end

print(("test-completo-quest-pins: %d checks passed"):format(checks))

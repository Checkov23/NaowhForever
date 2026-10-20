local file = assert(io.open("NaowhForever_QoL/Interface/MapSize.lua", "rb"))
local source = file:read("*a"):gsub("\r\n", "\n"); file:close()
local owns, standDown, moved = false, false, 0
local function noop() end
local function Widget()
 local w = { shown = true }
 for _, name in ipairs({ "SetSize", "SetPoint", "SetFrameStrata", "SetNormalTexture", "SetHighlightTexture",
  "SetPushedTexture", "RegisterForClicks", "RegisterEvent", "SetScript", "SetHeight", "SetFrameLevel", "EnableMouse" }) do
  w[name] = noop
 end
 function w:Hide() self.shown = false end
 function w:SetShown(on) self.shown = on end
 return w
end
local function Move() moved = moved + 1 end
local built = {}
local map = { scale = 1, ClearAllPoints = Move, SetPoint = Move, HookScript = noop }
function map:GetScale() return self.scale end
function map:SetScale(scale) self.scale = scale Move() end
map.GetPoint = function() return "TOPLEFT", {}, "TOPLEFT", 10, -10 end
map.GetNumPoints = function() return 1 end
map.IsShown = function() return true end
map.IsMaximized = function() return false end
map.GetFrameLevel = function() return 1 end
local settings = { enabled = true, mapSizePercent = 120, mapSizePos = { x = 100, y = 500 } }
local S = { Get = function(key) return settings[key] end, Set = noop }
local ns = { QoLSettings = S, QoLConstants = { PERCENT = 100, ROUND = 0.5 }, L = function(text) return text end,
 Tooltip = noop, Apply = noop, GamepadOwnsPanels = function() return owns end,
 GamepadStandDown = function() return standDown end }
local env = setmetatable({
 NaowhForever = ns,
 WorldMapFrame = map,
 CreateFrame = function() local w = Widget() built[#built + 1] = w return w end,
 hooksecurefunc = noop,
}, { __index = _G })
env._G = env
local chunk = assert(loadstring((source:gsub("hooksecurefunc%(ns, \"Apply\", Setup%)", "_G.Setup = Setup"))))
setfenv(chunk, env)
chunk()
local Setup = env.Setup
standDown = true
local before = #built
Setup()
assert(moved == 0 and #built == before, "a session in the Gamepad interface style builds and moves nothing")
standDown = false
owns = true
Setup()
assert(moved == 0, "the map must not be scaled or anchored while the gamepad owns Blizzard's panels")
assert(not built[2].shown and not built[3].shown, "the grip and handle must be hidden under the gamepad")
owns = false
Setup()
assert(moved > 0, "the map is scaled and placed again once the mouse is back")
assert(built[2].shown and built[3].shown, "the grip and handle come back with the mouse")
print("4 map window gamepad checks passed")

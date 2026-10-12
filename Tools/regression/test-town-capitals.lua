-- Run with Lua 5.1 from the repository root: the town map's Vendors & Trainers Only in Cities.
-- With it on, a questing map keeps its flight masters, innkeepers and stable masters but not its
-- vendors and trainers; a capital keeps everything; with it off every map keeps everything.
-- Stable masters are for hunters only.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local settings = { enabled = true, townMap = true, townCapitalsOnly = true, townFlight = true, townInn = true,
    townStable = true, townVendors = true, townRepair = true, townClass = true, townProfession = true,
    townBank = true, townSupplies = true }
local S = { Get = function(key) return settings[key] end, Set = function() end }
local function Town()
    return {
        { 10, 10, "flight", "Flyer", "Flight Master", nil, "AH" },
        { 11, 11, "inn", "Host", "Innkeeper", nil, "AH" },
        { 12, 12, "stable", "Keeper", "Stable Master", nil, "AH" },
        { 13, 13, "vendor", "Seller", "General Goods", nil, "AH" },
        { 14, 14, "repair", "Smith", "Armorer", nil, "AH" },
        { 15, 15, "profession", "Teacher", "Trainer", nil, "AH" },
        { 16, 16, "bank", "Banker", "Banker", nil, "AH" },
    }
end
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    QoLConstants = dofile("Tools/regression/qol_constants.lua"),
    QoLSettings = S, Apply = function() end, ThemeTint = function() end,
    TownCapitals = { [2] = true }, TownNPCs = { [1] = Town(), [2] = Town() },
    TownMailboxes = {}, TownSpiritHealers = {}, ZoneExits = {}, TownTravel = {},
    Shared = { Style = dofile("Tools/regression/shared_style.lua"),
        Settings = { Group = function() end, Page = function() return { Card = function() end } end } },
}

local playerClass = "HUNTER"
local frames = {}
local function NewFrame()
    local f = { events = {}, scripts = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    frames[#frames + 1] = f
    return f
end

local provider, shownMap
local pins = {}
local map = {
    GetMapID = function() return shownMap end,
    AcquirePin = function(_, _, npc) pins[#pins + 1] = npc[3] end,
    RemoveAllPinsByTemplate = function() end,
}
local env = setmetatable({
    _G = { NaowhForever = ns },
    CreateFromMixins = function() return {} end,
    MapCanvasPinMixin = {}, MapCanvasDataProviderMixin = {},
    CreateFrame = function() return NewFrame() end,
    hooksecurefunc = function() end,
    WorldMapFrame = { AddDataProvider = function(_, p) provider = p end, IsShown = function() return false end },
    UnitFactionGroup = function() return "Alliance" end,
    UnitClass = function() return playerClass, playerClass end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
}, { __index = _G })
local chunk = assert(loadstring(Read("NaowhForever_QoL/Interface/TownMap.lua")))
setfenv(chunk, env)
chunk()
for _, f in ipairs(frames) do
    if f.events.PLAYER_LOGIN then f.scripts.OnEvent() end
end
Check(provider, "the world map's data provider")
provider.GetMap = function() return map end

local function Shown(mapID)
    shownMap = mapID
    for i = #pins, 1, -1 do pins[i] = nil end
    provider:RefreshAllData()
    table.sort(pins)
    return table.concat(pins, " ")
end

Check(Shown(1) == "flight inn stable", "a questing map keeps its flight master, innkeeper and stable master")
Check(Shown(2) == "bank flight inn profession repair stable vendor", "a capital keeps everything")
settings.townCapitalsOnly = false
Check(Shown(1) == "bank flight inn profession repair stable vendor", "switched off, every map keeps everything")
settings.townCapitalsOnly, settings.townFlight = true, false
Check(Shown(1) == "inn stable", "a category switched off stays off")

playerClass = "WARRIOR"
settings.townCapitalsOnly, settings.townFlight = false, true
Check(Shown(1) == "bank flight inn profession repair vendor", "stable masters are left off for a warrior")
Check(Shown(2) == "bank flight inn profession repair vendor", "in a capital too")
playerClass = "HUNTER"
Check(Shown(1) == "bank flight inn profession repair stable vendor", "and shown for a hunter")

print(("test-town-capitals: %d checks passed"):format(checks))

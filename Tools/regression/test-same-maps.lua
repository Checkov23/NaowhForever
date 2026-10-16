-- Run with Lua 5.1 from the repository root: a map the game has under a second ID reads the first
-- one's data. Zephras Isle is 2521 and 2665: on 2665 the town map draws the island's zeppelin docks,
-- town NPCs, mailboxes and spirit healers as on 2521, and the Quest List finds the island and its
-- quest givers; a map without an alias keeps its own data.
local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local ZEPHRAS, ZEPHRAS_TOO, DUROTAR, NOWHERE = 2521, 2665, 1411, 99999

local Places = dofile("Tools/regression/shared_places.lua")
local aliases = 0
for alias, map in pairs(dofile("Tools/regression/load_files.lua")({ "Shared/Data/SameMaps.lua" },
        { _G = { NaowhForever = { Shared = {} } } })._G.NaowhForever.Shared.SameMaps) do
    Check(alias ~= map and Places.SameMap(alias) == map, "an alias reads another map's data: " .. alias)
    aliases = aliases + 1
end
Check(aliases == 1 and Places.SameMap(ZEPHRAS_TOO) == ZEPHRAS, "Zephras Isle's second map reads 2521")
Check(Places.SameMap(ZEPHRAS) == ZEPHRAS and Places.SameMap(DUROTAR) == DUROTAR and Places.SameMap(nil) == nil,
    "any other map is itself")

local settings = { enabled = true, townMap = true, townCapitalsOnly = false, townFlight = true, townInn = true,
    townStable = true, townVendors = true, townRepair = true, townClass = true, townProfession = true,
    townBank = true, townSupplies = true, townMail = true, townSpiritHealers = true, townTravel = true,
    townZoneLinks = false, townPinSize = 20 }
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    QoLConstants = dofile("Tools/regression/qol_constants.lua"),
    QoLSettings = { Get = function(key) return settings[key] end, Set = function() end },
    Apply = function() end, ThemeTint = function() end, ZoneExits = {},
    Shared = { Style = dofile("Tools/regression/shared_style.lua"), Places = Places,
        Settings = { Group = function() end, Page = function() return { Card = function() end } end } },
}

local faction = "Alliance"
local provider, shownMap
local pins = {}
local map = {
    GetMapID = function() return shownMap end,
    AcquirePin = function(_, _, pin) pins[#pins + 1] = pin.linkedUiMapID and pin.name or pin[3] end,
    RemoveAllPinsByTemplate = function() end,
}
local frames = {}
local function NewFrame()
    local f = { events = {}, scripts = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    frames[#frames + 1] = f
    return f
end
local env = setmetatable({
    _G = { NaowhForever = ns },
    CreateFromMixins = function() return {} end,
    MapCanvasPinMixin = {}, MapCanvasDataProviderMixin = {},
    CreateFrame = NewFrame,
    hooksecurefunc = function() end,
    WorldMapFrame = { AddDataProvider = function(_, p) provider = p end, IsShown = function() return false end },
    UIParent = { CreateTexture = function() return { SetTexture = function() return true end } end },
    C_Texture = { GetAtlasInfo = function() return nil end },
    CreateVector2D = function(x, y) return { x = x, y = y } end,
    UnitFactionGroup = function() return faction end,
    UnitClass = function() return "HUNTER", "HUNTER" end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
}, { __index = _G })
dofile("Tools/regression/load_files.lua")({ "Shared/Game/Towns.lua", "NaowhForever_QoL/Interface/TownTravel.lua",
    "NaowhForever_QoL/Interface/TownMailboxes.lua", "NaowhForever_QoL/Interface/TownSpiritHealers.lua",
    "NaowhForever_QoL/Interface/TownMap.lua" }, env)
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
    return table.concat(pins, ", ")
end

local function Has(list, what) return (", " .. list .. ", "):find(", " .. what .. ", ", 1, true) ~= nil end

local island = Shown(ZEPHRAS)
Check(Has(island, "Zeppelin to Dalaran") and not Has(island, "Zeppelin to Mulgore"),
    "2521 shows the Alliance zeppelin to Dalaran")
Check(Has(island, "mail") and Has(island, "spirit") and Has(island, "inn") and Has(island, "bank"),
    "and the island's mailboxes, spirit healers and town NPCs")
Check(Shown(ZEPHRAS_TOO) == island, "2665 shows the same pins as 2521")
faction = "Horde"
Check(Has(Shown(ZEPHRAS_TOO), "Zeppelin to Mulgore") and not Has(Shown(ZEPHRAS_TOO), "Zeppelin to Dalaran"),
    "the Horde zeppelin to Mulgore on 2665")
local durotar = Shown(DUROTAR)
Check(Has(durotar, "Zeppelin to Grom'gol") and not Has(durotar, "Zeppelin to Mulgore"), "Durotar keeps its own docks")
Check(Shown(NOWHERE) == "", "a map with no data draws nothing")

local completed = {}
local best = ZEPHRAS_TOO
local quests = { AccountSettings = function() return {} end,
    Completo = { CharKey = function() return "Me-Realm" end }, CompletoQuestData = {}, Shared = { Places = Places } }
local questEnv = setmetatable({
    _G = { NaowhForever = quests },
    wipe = env.wipe,
    UnitFactionGroup = function() return "Horde", "Horde" end,
    UnitRace = function() return "Tauren", "Tauren", 6 end,
    UnitClass = function() return "DRUID", "DRUID", 11 end,
    UnitLevel = function() return 5 end,
    C_QuestLog = { GetAllCompletedQuestIDs = function() return completed end,
        GetLogIndexForQuestID = function() return nil end },
    C_Map = { GetBestMapForUnit = function() return best end, GetMapInfo = function() return nil end },
}, { __index = _G })
dofile("Tools/regression/load_files.lua")({ "NaowhForever_DiscoveryData/Quests.lua",
    "NaowhForever_Discovery/QuestList/Quests.lua" }, questEnv)
local Q = quests.Completo.Quests
Q.Refresh()
local zone = Q.CurrentZone()
Check(zone and zone.map == ZEPHRAS, "standing on 2665, the Quest List's zone is Zephras Isle")
best = ZEPHRAS
Check(Q.CurrentZone() == zone, "and on 2521")
local givers = #Q.Givers(ZEPHRAS, true, false)
Check(givers > 0 and #Q.Givers(ZEPHRAS_TOO, true, false) == givers, "the island's quest givers on 2665 as on 2521")
best = NOWHERE
Check(Q.CurrentZone() == nil and #Q.Givers(NOWHERE, true, false) == 0, "a map with no quests has no zone or givers")

print(("test-same-maps: %d checks passed"):format(checks))

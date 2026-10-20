-- Run with Lua 5.1 from the repository root: the Quest List holds back a quest until everything it
-- requires is done, says what is missing, and believes a quest its giver offers.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local account, completed, level = {}, {}, 60
local ns = { AccountSettings = function() return account end, Completo = { CharKey = function() return "Me-Realm" end },
    Shared = { Places = dofile("Tools/regression/shared_places.lua") } }
local env = setmetatable({
    _G = { NaowhForever = ns },
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    UnitFactionGroup = function() return "Alliance" end,
    UnitRace = function() return "Human", "Human", 1 end,
    UnitClass = function() return "Warrior", "WARRIOR", 1 end,
    UnitLevel = function() return level end,
    C_QuestLog = {
        GetAllCompletedQuestIDs = function()
            local ids = {}
            for id in pairs(completed) do ids[#ids + 1] = id end
            return ids
        end,
        GetLogIndexForQuestID = function() return nil end,
        GetTitleForQuestID = function(id) return id == 900 and "Elsewhere" or nil end,
    },
}, { __index = _G })

local function Quest(name, side) return { name, 10, 1, side or 3, 0, 0 } end
ns.CompletoQuestData = {
    Zones = { { map = 1, name = "Zone", quests = { 1, 2, 3, 4, 5, 6, 7 } } },
    Quests = { [1] = Quest("First"), [2] = Quest("Second A"), [3] = Quest("Second B"), [4] = Quest("Last"),
        [5] = Quest("Horde Only", 2), [6] = Quest("Alone"),
        [7] = { "Into the Dungeon", 10, 1, 3, 0, 0, 1, 40.0, 50.0, "Dungeon Giver" } },
    Repeatable = {},
    Dungeon = { [7] = true },
    Requires = { [4] = { 1, { 2, 3 }, 900 }, [6] = { { 5 } } },
    Chains = {},
}
local chunk = assert(loadstring(Read("NaowhForever_Discovery/QuestList/Quests.lua")))
setfenv(chunk, env)
chunk()
local Q = ns.Completo.Quests

local function Fresh(...)
    completed = {}
    for _, id in ipairs({ ... }) do completed[id] = true end
    Q.Refresh()
end

Fresh()
Check(Q.State(4) == "later", "held back with nothing done")
Check(#Q.Blocking(4) == 3 and Q.Blocking(4)[1] == 1 and Q.Blocking(4)[2] == 2 and Q.Blocking(4)[3] == 900,
    "every missing element is named, an alternative by its first quest")
Check(Q.Title(900) == "Elsewhere" and Q.Title(1) == "First", "a quest the data lacks is named by the client")

Fresh(1, 2)
Check(Q.State(4) == "later", "one element met is not enough")
Check(#Q.Blocking(4) == 1 and Q.Blocking(4)[1] == 900, "only what is missing is named")

Fresh(1, 3, 900)
Check(Q.State(4) == "open", "any alternative will do")

Fresh(1, 2, 3)
Check(Q.State(4) == "later", "a quest the data lacks still has to be done")

Fresh(1, 2)
Q.SetOpened(4)
Check(Q.State(4) == "open", "a quest its giver offered is open whatever the data says")
Check(account.completoOpened["Me-Realm"][4] == true, "kept per character")

Fresh()
Check(Q.State(6) == "open", "the other faction's quest is no requirement")
Check(Q.State(1) == "open" and #Q.Blocking(1) == 0, "no requirements, nothing blocks")

local givers = Q.Givers(1, true, false)
Check(#givers == 1 and givers[1].quests[1] == 7 and Q.State(7) == "open", "a dungeon quest gets its giver's pin")
givers = Q.Givers(1, true, true)
Check(#givers == 1 and givers[1].quests[1] == 7 and givers[1].dungeon, "a dungeon quest keeps its pin with Chains Only")
local _, total = Q.ZoneProgress(ns.CompletoQuestData.Zones[1])
Check(total == 5, "a dungeon quest is left out of the zone's progress")

local real = setmetatable({ _G = { NaowhForever = { AccountSettings = ns.AccountSettings, CompletoQuestData = {} } } },
    { __index = env })
local data = assert(loadstring(Read("NaowhForever_DiscoveryData/Quests.lua")))
setfenv(data, real)
data()
local D = real._G.NaowhForever.CompletoQuestData
local covert = D.Requires[1079]
Check(covert[1] == 1074 and covert[2] == 1077, "Covert Ops - Alpha needs both quests before it")
Check(type(D.Requires[1000][1]) == "table" and #D.Requires[1000] == 1, "the versions of one quest are alternatives")
local brother = D.Quests[167]
Check(D.Dungeon[167] and brother[7] == 1453 and brother[10] == "Wilder Thistlenettle",
    "Oh Brother. . . is pinned at its giver in Stormwind")
Check(D.Dungeon[1654] and D.Quests[1654][6] == 2 and D.Requires[1654][1] == 1653,
    "a class's dungeon quest keeps its class and the quest before it")
local inStormwind = false
for _, zone in ipairs(D.Zones) do
    if zone.map == 1453 then
        for _, id in ipairs(zone.quests) do inStormwind = inStormwind or id == 167 end
    end
end
Check(inStormwind, "a dungeon quest is listed in its giver's zone")

print(("test-completo-quest-prereqs: %d checks passed"):format(checks))

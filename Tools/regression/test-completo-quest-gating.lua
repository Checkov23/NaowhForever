-- Run with Lua 5.1 from the repository root: a quest you can no longer take is closed, out of its zone's
-- count and off its giver's !: one of its exclusive group or its breadcrumb's target done or in your log,
-- a quest that needs it done or in your log, a profession you lack, a camp recipe you know. A closed quest
-- its giver offers is open for good. Then the shipped data's groups, and the zone counts' cost.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end
local Measure = dofile("Tools/regression/measure.lua")(Check)

local ALCHEMY, SKINNING = 171, 393
local MANA_WELL = 1230564
local ALCHEMY_INDEX = 1

local account, completed, inLog, professions, spells = {}, {}, {}, {}, {}
local logIDs = {}

local function Env(ns)
    return setmetatable({
        _G = { NaowhForever = ns },
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        UnitFactionGroup = function() return "Alliance" end,
        UnitRace = function() return "Human", "Human", 1 end,
        UnitClass = function() return "Warrior", "WARRIOR", 1 end,
        UnitLevel = function() return 10 end,
        GetProfessions = function() return professions[1], professions[2] end,
        GetProfessionInfo = function(index)
            return "Profession", nil, 1, 300, 0, 0, index == ALCHEMY_INDEX and ALCHEMY or SKINNING
        end,
        C_SpellBook = { IsSpellKnown = function(spell) return spells[spell] == true end },
        C_QuestLog = {
            GetAllCompletedQuestIDs = function()
                local ids = {}
                for id in pairs(completed) do ids[#ids + 1] = id end
                return ids
            end,
            GetLogIndexForQuestID = function(id) return inLog[id] and 1 or nil end,
            GetNumQuestLogEntries = function() return #logIDs end,
            GetQuestIDForLogIndex = function(i) return logIDs[i] end,
        },
    }, { __index = _G })
end

local function Quest(name) return { name, 6, 1, 1, 0, 0, 1429, 40.0, 50.0, "Sam" } end
local ns = { AccountSettings = function() return account end, Completo = { CharKey = function() return "Me-Realm" end },
    Shared = { Places = dofile("Tools/regression/shared_places.lua") } }
ns.CompletoQuestData = {
    Zones = { { map = 1429, name = "Elwynn Forest", quests = { 1, 2, 3, 4, 5, 6, 7, 8, 9 } } },
    Quests = { [1] = Quest("The Great Outdoors"), [2] = Quest("The Great Outdoors"), [3] = Quest("The Adventurer"),
        [4] = Quest("The Great Outdoors"), [5] = Quest("Nibbled-On Book"), [6] = Quest("Book Inventory"),
        [7] = Quest("Rough Wolf Pelts"), [8] = Quest("Camping 101: Alchemy"), [9] = Quest("Kobold Camp Cleanup") },
    Repeatable = {}, Dungeon = {},
    Requires = { [6] = { 5 } },
    Chains = {},
    Exclusive = { { 1, 2, 4 } },
    Breadcrumb = { [3] = 4 },
    Profession = { [7] = SKINNING, [8] = ALCHEMY },
    Recipe = { [8] = MANA_WELL },
}
local chunk = assert(loadstring(Read("NaowhForever_Discovery/QuestList/Quests.lua")))
setfenv(chunk, Env(ns))
chunk()
local Q = ns.Completo.Quests
local zone = ns.CompletoQuestData.Zones[1]

local function Fresh(done, logged)
    completed, inLog, logIDs = {}, {}, {}
    for _, id in ipairs(done or {}) do completed[id] = true end
    for _, id in ipairs(logged or {}) do
        inLog[id] = true
        logIDs[#logIDs + 1] = id
    end
    Q.Refresh()
end

local function Pinned(id)
    for _, giver in ipairs(Q.Givers(1429, true, false)) do
        for _, quest in ipairs(giver.quests) do
            if quest == id then return true end
        end
    end
    return false
end

Fresh()
Check(Q.State(1) == "open" and Q.State(2) == "open" and Q.State(3) == "open", "nothing taken, every version is open")
Check(Q.State(7) == "skill" and Q.State(8) == "skill", "a profession you lack keeps its quests closed")
local _, total = Q.ZoneProgress(zone)
Check(total == 7, "quests needing a profession you lack are out of the zone's count")
Fresh(nil, { 7 })
_, total = Q.ZoneProgress(zone)
Check(Q.State(7) == "log" and total == 8, "a quest in your log counts as its row shows it, closed or not")

Fresh({ 1 })
Check(Q.State(2) == "closed" and Q.State(4) == "closed", "one of an exclusive group done closes the rest")
Check(Q.State(3) == "closed", "a breadcrumb closes once its target can no longer be taken")
Check(not Pinned(2) and not Pinned(3) and Pinned(9), "a closed quest gets no !")
local n
n, total = Q.ZoneProgress(zone)
Check(n == 1 and total == 4, "closed quests are out of the zone's count, the done one in it")

Fresh(nil, { 4 })
Check(Q.State(3) == "closed" and Q.State(1) == "closed", "the breadcrumb's target or a version in your log closes them")

Fresh(nil, { 6 })
Check(Q.State(5) == "closed", "a quest whose next quest is in your log is closed")
Fresh({ 6 })
Check(Q.State(5) == "closed", "and once that one is done")

professions = { nil, ALCHEMY_INDEX }
Fresh()
Check(Q.State(8) == "open" and Q.State(7) == "skill", "your profession's quest opens, another's stays closed")
spells[MANA_WELL] = true
Fresh()
Check(Q.State(8) == "closed", "a Camping 101 quest closes once you know its camp recipe")

Fresh({ 1 })
Q.SetOpened(2)
Check(Q.State(2) == "closed", "opening a quest past a requirement does not reopen it")
Q.SetReopened(2)
Check(Q.State(2) == "open", "a closed quest its giver offered is open for good")

local real = setmetatable({ _G = { NaowhForever = { CompletoQuestData = {} } } }, { __index = _G })
local data = assert(loadstring(Read("NaowhForever_DiscoveryData/Quests.lua")))
setfenv(data, real)
data()
local D = real._G.NaowhForever.CompletoQuestData
local function GroupOf(id)
    for _, group in ipairs(D.Exclusive) do
        for _, other in ipairs(group) do
            if other == id then return group end
        end
    end
end
Check(#GroupOf(95998) == 7 and GroupOf(96604) == GroupOf(95998), "The Great Outdoors: one per starting area, take one")
Check(#GroupOf(97915) == 7 and #GroupOf(96626) == 7, "each Camping 101 is one quest in seven places")
Check(GroupOf(324) and GroupOf(526) == GroupOf(324) and GroupOf(1516) == GroupOf(92466), "the other exclusive pairs")
Check(D.Breadcrumb[96627] == 95998 and D.Breadcrumb[96659] == 96605 and D.Breadcrumb[97894] == 982,
    "The Adventurer and the other breadcrumbs lead to their quest")
Check(D.Profession[97915] == ALCHEMY and D.Recipe[97915] == MANA_WELL and D.Profession[91751] == SKINNING,
    "Camping 101 needs its profession and closes on its recipe")
Check(D.Recipe[97925] ~= D.Recipe[96102] and D.Profession[96626] == nil,
    "each faction's Faction Banner; Camping 101: Cooking teaches cooking, so needs none")
Check(D.Profession[95217] == nil and D.Profession[96874] == nil and D.Profession[92109] == nil
    and D.Profession[92110] == nil, "a quest that introduces a profession needs none")

ns.CompletoQuestData = D
chunk = assert(loadstring(Read("NaowhForever_Discovery/QuestList/Quests.lua")))
setfenv(chunk, Env(ns))
chunk()
Q = ns.Completo.Quests
Fresh({ 95998, 96627 }, { 97915 })
Measure("every zone's count", 15, Q.Progress)

print(("test-completo-quest-gating: %d checks passed"):format(checks))

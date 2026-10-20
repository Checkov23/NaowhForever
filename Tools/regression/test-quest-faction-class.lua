-- Run with Lua 5.1 from the repository root: the Quest List and the Dungeon Quest Tracker give each
-- character only its own faction's quests and its own class's class quests, read from the shipped
-- data: Alliance-only, Horde-only and warlock-only quests for an Alliance and a Horde hunter and a
-- Human warlock.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local ALLIANCE_HUNTER = { faction = "Alliance", race = "Dwarf", raceID = 3, class = "HUNTER", classID = 3 }
local HORDE_HUNTER = { faction = "Horde", race = "Orc", raceID = 2, class = "HUNTER", classID = 3 }
local HUMAN_WARLOCK = { faction = "Alliance", race = "Human", raceID = 1, class = "WARLOCK", classID = 9 }

local function Env(ns, who)
    return setmetatable({
        _G = { NaowhForever = ns },
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        UnitFactionGroup = function() return who.faction, who.faction end,
        UnitRace = function() return who.race, who.race, who.raceID end,
        UnitClass = function() return who.class, who.class, who.classID end,
        UnitLevel = function() return 60 end,
        C_QuestLog = { GetAllCompletedQuestIDs = function() return {} end },
    }, { __index = _G })
end

local function Run(path, env)
    local chunk = assert(loadstring(Read(path), path))
    setfenv(chunk, env)
    chunk()
end

-- The Quest List: Kobold Camp Cleanup (7) and Hearts of the Lost (87318) are Alliance-only,
-- Cutting Teeth (788) and Strahnbrad Mystery (95534) Horde-only, You Have Served Us Well (397) is
-- for Human and Gnome warlocks, and An Earnest Proposition has a version per class (8906 hunter,
-- 8911 warlock).
local function QuestList(who)
    local ns = { AccountSettings = function() return {} end,
        Completo = { CharKey = function() return "Me-Realm" end }, CompletoQuestData = {},
        Shared = { Places = dofile("Tools/regression/shared_places.lua") } }
    local env = Env(ns, who)
    Run("NaowhForever_DiscoveryData/Quests.lua", env)
    Run("NaowhForever_Discovery/QuestList/Quests.lua", env)
    local Q = ns.Completo.Quests
    Q.Refresh()
    return Q
end

local Q = QuestList(ALLIANCE_HUNTER)
Check(Q.Mine(7) and Q.Mine(87318), "an Alliance hunter has the Alliance-only quests")
Check(not Q.Mine(788) and not Q.Mine(95534), "an Alliance hunter does not have the Horde-only quests")
Check(not Q.Mine(397), "an Alliance hunter does not have the warlock quest")
Check(Q.Mine(8906) and not Q.Mine(8911), "an Alliance hunter has the hunter version, not the warlock one")

Q = QuestList(HORDE_HUNTER)
Check(Q.Mine(788) and Q.Mine(95534), "a Horde hunter has the Horde-only quests")
Check(not Q.Mine(7) and not Q.Mine(87318), "a Horde hunter does not have the Alliance-only quests")
Check(not Q.Mine(397) and not Q.Mine(8906) and not Q.Mine(8911), "a Horde hunter has no Alliance class quest")

Q = QuestList(HUMAN_WARLOCK)
Check(Q.Mine(397) and Q.Mine(8911), "a Human warlock has the warlock quests")
Check(not Q.Mine(8906), "a Human warlock does not have the hunter version")

-- The Dungeon Quest Tracker: Serpentbloom (962) is Horde-only, Important Heirlooms (96403)
-- Alliance-only, and The Orb of Soran'ruk (1740) is for warlocks of either faction.
local function Tracker(who)
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Journal = {} }
    local env = Env(ns, who)
    for _, path in ipairs({ "NaowhForever_DungeonJournal/Constants.lua", "NaowhForever_DungeonJournal/Data/Quests.lua",
        "NaowhForever_DungeonJournal/Data/QuestChains.lua", "NaowhForever_DungeonJournal/Quests.lua" }) do
        Run(path, env)
    end
    local J = ns.Journal
    return function(id) return J.Quests.ForMe(assert(J.Quests.ByID(id), id)) end
end

local ForMe = Tracker(ALLIANCE_HUNTER)
Check(ForMe(96403) and not ForMe(962), "the tracker gives an Alliance hunter the Alliance quest, not the Horde one")
Check(not ForMe(1740), "the tracker gives a hunter no warlock quest")

ForMe = Tracker(HORDE_HUNTER)
Check(ForMe(962) and not ForMe(96403), "the tracker gives a Horde hunter the Horde quest, not the Alliance one")
Check(not ForMe(1740), "the tracker gives a Horde hunter no warlock quest")

ForMe = Tracker(HUMAN_WARLOCK)
Check(ForMe(1740) and ForMe(96403) and not ForMe(962), "the tracker gives a warlock its class quest and its faction's")

print(("test-quest-faction-class: %d checks passed"):format(checks))

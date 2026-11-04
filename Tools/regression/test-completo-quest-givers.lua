-- Run with Lua 5.1 from the repository root: a quest the Quest List's data says is not yours (its
-- race or class mask) becomes yours, for good, once a quest giver offers it to you; a player
-- sharing a quest, a giver outside the Quest List's zones, or a quest the data lacks, teaches nothing,
-- and one giver's quests are learned in one pass.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local ALLIANCE_NO_HUMAN = 4294967372
local SHAMAN = 64

local account = {}
local offers, player = {}, false
local bestMap, builds, refreshes = 1429, 0, 0
local handlers = {}

local function Frame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(_, fn) handlers[#handlers + 1] = { frame = self, fn = fn } end
    return frame
end

local function Fire(event, ...)
    for _, h in ipairs(handlers) do
        if h.frame.events[event] then h.fn(h.frame, event, ...) end
    end
end

local function Quest(name, side, races, classes)
    return { name, 5, 1, side, races or 0, classes or 0, 1429, 40.0, 50.0, "Giver" }
end

local function Load()
    handlers = {}
    local settings = { Get = function(key) return key == "enabled" end, Set = function() end }
    local ns = {
        AccountSettings = function() return account end,
        Apply = function() end,
        Completo = { CharKey = function() return "Me-Realm" end, Settings = settings },
        Shared = { Places = dofile("Tools/regression/shared_places.lua") },
        CompletoQuestData = {
            Zones = { { map = 1429, name = "Elwynn Forest", quests = { 1, 2, 3, 4 } } },
            Quests = { [1] = Quest("Delicate Instruments", 1, ALLIANCE_NO_HUMAN),
                [2] = Quest("Call of Earth", 1, 0, SHAMAN), [3] = Quest("Kobold Camp Cleanup", 1),
                [4] = Quest("Horde Only", 2) },
            Repeatable = {}, Dungeon = {}, Requires = {}, Chains = {},
        },
    }
    local env = setmetatable({
        _G = { NaowhForever = ns },
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        hooksecurefunc = function() end,
        CreateFrame = Frame,
        issecretvalue = function() return false end,
        UnitFactionGroup = function() return "Alliance" end,
        UnitRace = function()
            builds = builds + 1
            return "Human", "Human", 1
        end,
        UnitClass = function() return "Warrior", "WARRIOR", 1 end,
        UnitLevel = function() return 5 end,
        UnitExists = function() return true end,
        UnitIsPlayer = function() return player end,
        UnitGUID = function() return "Creature-0-1" end,
        UnitName = function() return "Giver" end,
        C_GossipInfo = { GetAvailableQuests = function() return offers end },
        C_Minimap = { IsFilteredOut = function() return true end },
        Enum = { MinimapTrackingFilter = { TrivialQuests = 1 } },
        C_Map = { GetBestMapForUnit = function() return bestMap end, GetMapInfo = function() return nil end },
        C_QuestLog = {
            GetAllCompletedQuestIDs = function()
                refreshes = refreshes + 1
                return {}
            end,
            GetLogIndexForQuestID = function() return nil end,
        },
    }, { __index = _G })
    for _, path in ipairs({ "NaowhForever_Discovery/QuestList/Quests.lua", "NaowhForever_Discovery/QuestList/Givers.lua" }) do
        local chunk = assert(loadstring(Read(path), path))
        setfenv(chunk, env)
        chunk()
    end
    Fire("PLAYER_LOGIN")
    local Q = ns.Completo.Quests
    Q.Refresh()
    return Q
end

local Q = Load()
Check(not Q.Mine(1) and not Q.Mine(2) and Q.Mine(3), "the data's masks leave a Human warrior out of two quests")

offers = { { questID = 1 }, { questID = 2 }, { questID = 3 }, { questID = 999 } }
player = true
Fire("GOSSIP_SHOW")
Check(not Q.Mine(1) and not Q.Mine(2), "a player sharing a quest teaches nothing")

player, bestMap = false, nil
local before = refreshes
Fire("GOSSIP_SHOW")
Check(refreshes == before and not Q.Mine(1), "a giver outside the Quest List's zones reads nothing and teaches nothing")

bestMap, before = 1429, builds
Fire("GOSSIP_SHOW")
Check(Q.Mine(1) and Q.Mine(2), "a quest a giver offers you is yours whatever its mask says")
Check(builds == before + 1, "the quests one giver offers are learned in one pass")
local pinned = false
for _, id in ipairs(Q.Givers(1429, true, false)[1].quests) do pinned = pinned or id == 1 end
Check(Q.State(1) == "open" and pinned, "it is open and its giver gets a ! for it")
local learned = account.completoMine["Me-Realm"]
Check(learned[1] and learned[2] and not learned[3] and not learned[999], "only quests the data has and left out are kept")

Q = Load()
Check(Q.Mine(1) and Q.Mine(2) and not Q.Mine(4), "kept per character, after a reload too")

print(("test-completo-quest-givers: %d checks passed"):format(checks))

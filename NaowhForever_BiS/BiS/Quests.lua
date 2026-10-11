-- Quests.lua: the quests that reward a pick you do not have yet, by zone (B.Quests).
local ns = _G.NaowhForever

local B = ns.BiS
local Items = ns.Shared.Items

local QUEST_ID, QUEST_LEVEL, QUEST_MAP = 1, 3, 7
local RACE_ID = 3
local TEXT_ELSEWHERE = ns.L("Elsewhere")
local RACE_BITS = { [1] = 0, [2] = 1, [3] = 2, [4] = 3, [5] = 4, [6] = 5, [7] = 6, [8] = 7, [95] = 32, [96] = 33 }

local zones = {}
local shown = {}
local picked = {}
local picks = {}
local races = {}
local zoneOf = {}
local dungeonOf = {}
local swapped = false

local function Swap(J)
    swapped = true
    local byID = {}
    for _, dungeon in ipairs(J.QuestData) do
        for _, quest in ipairs(dungeon.quests) do
            local id = quest[QUEST_ID]
            byID[id], dungeonOf[id] = quest, dungeon.name
        end
    end
    local quests = J.BiSQuestData.quests
    for i, quest in ipairs(quests) do
        local id = quest[QUEST_ID]
        races[id] = quest.races
        quests[i] = byID[id] or quest
    end
end

local function ZoneOf(J, quest)
    local id = quest[QUEST_ID]
    local zone = zoneOf[id]
    if not zone then
        local info = quest[QUEST_MAP] and C_Map.GetMapInfo(quest[QUEST_MAP])
        zone = J.BiSQuestZones[id] or info and info.name or dungeonOf[id] or TEXT_ELSEWHERE
        zoneOf[id] = zone
    end
    return zone
end

local function ForYourRace(questID, raceBit)
    local mask = races[questID]
    return not (mask and raceBit) or math.floor(mask / 2 ^ raceBit) % 2 == 1
end

local function ByLevel(a, b)
    if a.level ~= b.level then return a.level < b.level end
    return a.name < b.name
end

local function Pick(list)
    wipe(picked)
    for _, gear in ipairs(Items.GEAR_SLOTS) do
        for _, id in ipairs(B.Picks(list, gear[1], picks)) do picked[id] = true end
    end
end

local function ZoneFor(name)
    local zone = zones[name]
    if not zone then
        zone = { name = name, data = { quests = {} }, out = {}, pool = {} }
        zones[name] = zone
    end
    return zone
end

local function AddQuest(zone, quest)
    local quests = zone.data.quests
    local level = quest[QUEST_LEVEL]
    if #quests == 0 then
        zone.level = level
        shown[#shown + 1] = zone
    end
    quests[#quests + 1] = quest
    if level < zone.level then zone.level = level end
end

local Q = {}
B.Quests = Q

function Q.Available()
    local J = ns.Journal
    return J ~= nil and J.BiSQuestData ~= nil and J.Quests ~= nil
end

function Q.Rewards(questID)
    return ns.Journal.BiSQuestRewards[questID]
end

function Q.Choice(questID)
    return ns.Journal.BiSQuestChoices[questID] == true
end

function Q.Wanted(itemID)
    return picked[itemID] == true and not Items.Owned(itemID)
end

local function Gives(questID)
    for _, id in ipairs(Q.Rewards(questID)) do
        if Q.Wanted(id) then return true end
    end
    return false
end

function Q.Zones(list)
    wipe(shown)
    if not Q.Available() then return shown end
    local J = ns.Journal
    if not swapped then Swap(J) end
    Pick(list)
    for _, zone in pairs(zones) do wipe(zone.data.quests) end
    local raceBit = RACE_BITS[select(RACE_ID, UnitRace("player"))]
    for _, quest in ipairs(J.BiSQuestData.quests) do
        local id = quest[QUEST_ID]
        if ForYourRace(id, raceBit) and Gives(id) then AddQuest(ZoneFor(ZoneOf(J, quest)), quest) end
    end
    table.sort(shown, ByLevel)
    return shown
end

function Q.Count(list)
    local count = 0
    for _, zone in ipairs(Q.Zones(list)) do
        local toPickUp, inLog = ns.Journal.Quests.Count(zone.data)
        count = count + toPickUp + inLog
    end
    return count
end

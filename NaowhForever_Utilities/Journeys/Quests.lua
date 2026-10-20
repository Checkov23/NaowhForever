-- Quests.lua: a quest you track that is far away becomes a journey to it; arriving hands it back to the game.
local ns = _G.NaowhForever

local Jy = ns.Journeys
local C = Jy.C
local S = Jy.Settings
local World = Jy.World
local Walk = Jy.Walk
local Guide = Jy.Guide

local PERCENT = 100
local CENTER = 0.5
local PLAYER = "player"
local CONTINENTS = { 1415, 1414 }
local UNFOCUS_DELAY = 1

local events

local function On()
    return Jy.On() and S.Get("quests")
end

local function OnMap(quest, map)
    local quests = C_QuestLog.GetQuestsOnMap(map)
    if not quests then return nil end
    for _, info in ipairs(quests) do
        if info.questID == quest then return info.x, info.y end
    end
end

local function Continent(map)
    local info = C_Map.GetMapInfo(map)
    while info and info.mapType ~= Enum.UIMapType.Continent do
        info = info.parentMapID and info.parentMapID ~= 0 and C_Map.GetMapInfo(info.parentMapID) or nil
    end
    return info and info.mapID
end

local function Inside(x, y)
    return CENTER - math.max(math.abs(x - CENTER), math.abs(y - CENTER))
end

local function InZones(quest, continent)
    local bestMap, bestX, bestY, bestInside
    for _, zone in ipairs(C_Map.GetMapChildrenInfo(continent, Enum.UIMapType.Zone, true)) do
        local x, y = OnMap(quest, zone.mapID)
        if x and (not bestInside or Inside(x, y) > bestInside) then
            bestMap, bestX, bestY, bestInside = zone.mapID, x, y, Inside(x, y)
        end
    end
    return bestMap, bestX, bestY
end

local function Nearest(camps, faction)
    local here = World.Player()
    local best, bestMap, bestX, bestY
    for _, camp in ipairs(camps) do
        local allowed = not faction or camp[4] and camp[4]:find(faction, 1, true)
        local there = allowed and here and World.FromMap(camp[1], camp[2], camp[3])
        local far = there and (there.c ~= here.c and math.huge or (there.x - here.x) ^ 2 + (there.y - here.y) ^ 2)
        if far and (not best or far < best) then best, bestMap, bestX, bestY = far, camp[1], camp[2], camp[3] end
    end
    if bestMap then return bestMap, bestX / PERCENT, bestY / PERCENT end
end

local function FromData(quest)
    if not ns.JourneyQuestSpots then Walk.Ready() end
    local spots = ns.JourneyQuestSpots and ns.JourneyQuestSpots[quest]
    if not spots then return nil end
    local turnIn, camps = spots[1], spots[2]
    local complete = C_QuestLog.IsComplete(quest)
    if turnIn and (complete or #camps == 0) then
        return turnIn[1], turnIn[2] / PERCENT, turnIn[3] / PERCENT
    end
    if spots[4] and (complete or #camps == 0) then
        local map, x, y = Nearest(spots[4], World.Faction())
        if map then return map, x, y end
    end
    if complete then return nil end
    local map, x, y = Nearest(camps)
    if map then return map, x, y end
    if spots[3] then return Nearest(spots[3]) end
end

local function Entrance(quest)
    local journal = ns.Journal
    if not journal or C_QuestLog.IsComplete(quest) then return nil end
    for _, dungeon in ipairs(journal.Dungeons()) do
        local door = dungeon.entrance
        for _, row in ipairs(door and dungeon.quests and dungeon.quests.quests or {}) do
            if row[1] == quest then return door.map, door.x / PERCENT, door.y / PERCENT end
        end
    end
end

local function Recorded(quest)
    local map, x, y = FromData(quest)
    if map then return map, x, y end
    return Entrance(quest)
end

local function Marked(quest)
    local here = C_Map.GetBestMapForUnit(PLAYER)
    if not here then return nil end
    local x, y = OnMap(quest, here)
    if x then return here, x, y end
    local mine = Continent(here)
    local map
    if mine then
        map, x, y = InZones(quest, mine)
        if map then return map, x, y end
    end
    for _, continent in ipairs(CONTINENTS) do
        if continent ~= mine then
            map, x, y = InZones(quest, continent)
            if map then return map, x, y end
        end
    end
end

local function Target(quest)
    local map, x, y = Marked(quest)
    if map then return map, x, y end
    map, x, y = Recorded(quest)
    if map then return map, x, y end
    map, x, y = C_QuestLog.GetNextWaypoint(quest)
    if map and x and y then return map, x, y end
end

local function Far(map, x, y)
    local here, there = World.Player(), World.FromMap(map, x * PERCENT, y * PERCENT)
    if not here or not there then return false end
    if here.c ~= there.c then return true end
    local dx, dy = here.x - there.x, here.y - there.y
    return dx * dx + dy * dy > C.QUEST_NEAR * C.QUEST_NEAR
end

local function ForgetDismissed()
    local quest = C_SuperTrack.GetSuperTrackedQuestID()
    if not quest or quest == 0 then Guide.Undismiss() end
end

local function OnSuperTrack()
    local quest = C_SuperTrack.GetSuperTrackedQuestID()
    if not quest or quest == 0 then return C_Timer.After(UNFOCUS_DELAY, ForgetDismissed) end
    if quest == Guide.Dismissed() then return end
    Guide.Undismiss()
    local current = Guide.Current()
    if current and current.quest == quest then return end
    local map, x, y = Target(quest)
    if not map or not Far(map, x, y) then return end
    local title = C_QuestLog.GetTitleForQuestID(quest) or ""
    Guide.Start(title, { { title, map, x * PERCENT, y * PERCENT } }, quest)
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnSuperTrack)
    end
    events:RegisterEvent("SUPER_TRACKING_CHANGED")
end

S.OnChange(Apply)
hooksecurefunc(ns, "Apply", Apply)
Apply()

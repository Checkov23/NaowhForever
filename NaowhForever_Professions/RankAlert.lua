-- RankAlert.lua: a profession ready for its next rank, for the window's banner and once in chat (ns.ProfessionRank).
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local S = P.Settings
local C = P.C

local RANK_LEVEL = { [150] = 10, [225] = 20, [300] = 35 }
local RANK_TITLE = { [150] = "Journeyman", [225] = "Expert", [300] = "Artisan" }
local GATHERING = { [182] = "Herbalism Trainer", [393] = "Skinning Trainer" }
local MINING = 186
local TOWN_X, TOWN_Y, TOWN_KIND, TOWN_NAME, TOWN_TITLE, TOWN_SIDE, TOWN_ID = 1, 2, 3, 4, 5, 7, 8
local NO_ID = 0
local ANY_SIDE = "AH"
local CHECK_DELAY = 1
local LOGIN_DELAY = 5
local TEXT_BOOK = ns.L("its book")
local TEXT_QUEST = ns.L("its quest")
local TEXT_NEXT_RANK = ns.L("the next rank of %s (cap %d)")
local TEXT_READ = ns.L("Buy and read %s%s|r (%s)")
local TEXT_DO_QUEST = ns.L("Do the quest %s%s|r")
local TEXT_TRAIN = ns.L("Train it for %s")
local TEXT_READY = ns.L("%s is ready for %s%s|r. %s%s. Open %s for a waypoint.")
local TEXT_FROM = ns.L(" from ")
local TEXT_NONE_READY = ns.L("No profession is ready for its next rank yet.")

local gathered = {}
local queued = false
local events = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and S.Get("rankAlert")
end

local function Announced()
    return P.CharacterData("profRankAlerted", true) or {}
end

local function GatheringTrainers(title)
    local trainers = {}
    for map, npcs in pairs(ns.TownNPCs) do
        for _, n in ipairs(npcs) do
            if n[TOWN_KIND] == "profession" and n[TOWN_TITLE] == title then
                trainers[#trainers + 1] = { n[TOWN_ID] or NO_ID, n[TOWN_NAME], n[TOWN_SIDE] or ANY_SIDE, map,
                    n[TOWN_X], n[TOWN_Y] }
            end
        end
    end
    return trainers
end

local function GatheringData(line, title, mining)
    if not gathered[line] then
        local ranks = {}
        for i, rank in ipairs(mining.ranks) do
            ranks[i] = { cap = rank.cap, skill = rank.skill, cost = rank.cost }
        end
        gathered[line] = { trainers = GatheringTrainers(title), ranks = ranks }
    end
    return gathered[line]
end

local function Data(line)
    if not line or not ns.RecipeData then return end
    if ns.RecipeData[line] then return ns.RecipeData[line] end
    local title, mining = GATHERING[line], ns.RecipeData[MINING]
    if not (title and mining and ns.TownNPCs) then return end
    return GatheringData(line, title, mining)
end

local function NextRank(data, max)
    for _, rank in ipairs(data.ranks or {}) do
        if rank.cap > max then return rank end
    end
end

local function RankName(rank, prof)
    if rank.name then return rank.name end
    if RANK_TITLE[rank.cap] then return RANK_TITLE[rank.cap] .. " " .. prof end
    return TEXT_NEXT_RANK:format(prof, rank.cap)
end

local function Where(data, rank)
    local RF = ns.RecipeFinder
    if rank.item then
        local npc = RF.Nearest(rank.vendors or {}, 1)[1]
        local name = C_Item.GetItemNameByID(rank.item)
        if not name then (ns.ProfRequestItem or C_Item.RequestLoadItemDataByID)(rank.item) end
        return npc, TEXT_READ:format(RF.Hex(T.accent), name or TEXT_BOOK, RF.Money(npc and npc[C.NPC_PRICE]))
    elseif rank.quest then
        local id = rank.quest[UnitFactionGroup("player") == "Horde" and "H" or "A"]
        local title = id and C_QuestLog.GetTitleForQuestID(id) or rank.questName or TEXT_QUEST
        return RF.Nearest(rank.teachers or {}, 1)[1], TEXT_DO_QUEST:format(RF.Hex(T.accent), title)
    end
    local list = rank.t and RF.Rows(rank.t, data) or data.trainers
    return RF.Nearest(list or {}, 1)[1], TEXT_TRAIN:format(RF.Money(rank.cost))
end

local function For(line, skill, max, prof)
    local data = Data(line)
    local rank = data and (max or 0) > 0 and NextRank(data, max)
    if not rank or (skill or 0) < rank.skill then return end
    if UnitLevel("player") < (rank.level or RANK_LEVEL[rank.cap] or 0) then return end
    local npc, how = Where(data, rank)
    return { rankName = RankName(rank, prof or ""), how = how, npc = npc, cap = rank.cap }
end

local function Announce(name, line, a, announced)
    announced[line] = a.cap
    ns.Print(TEXT_READY:format(name, ns.RecipeFinder.Hex(T.accent), a.rankName, a.how,
        a.npc and (TEXT_FROM .. a.npc[C.NPC_NAME]) or "", name))
end

local function Check(force)
    if not ns.RecipeFinder then return end
    local announced, any = Announced(), false
    for _, index in pairs({ GetProfessions() }) do
        local name, _, skill, max, _, _, line = GetProfessionInfo(index)
        local a = For(line, skill, max, name)
        if a and (force or announced[line] ~= a.cap) then
            Announce(name, line, a, announced)
            any = true
        end
    end
    if any then
        pcall(PlaySound, SOUNDKIT.IG_QUEST_LIST_OPEN)
    elseif force then
        ns.Print(TEXT_NONE_READY)
    end
end

local function RunCheck()
    queued = false
    if On() then Check(false) end
end

local function Queue()
    if queued then return end
    queued = true
    C_Timer.After(CHECK_DELAY, RunCheck)
end

ns.ProfessionRank = {
    For = function(line, skill, max, prof)
        if not On() then return end
        return For(line, skill, max, prof)
    end,
    Waypoint = function(npc)
        if npc and ns.PlaceWaypoint then ns.PlaceWaypoint(npc[C.NPC_NAME], npc[C.NPC_MAP], npc[C.NPC_X], npc[C.NPC_Y]) end
    end,
}

function ns.ProfessionRankCheck()
    Check(true)
end

local function Apply()
    events:UnregisterAllEvents()
    if ns.ProfWindowRefresh then ns.ProfWindowRefresh() end
    if not On() then return end
    events:RegisterEvent("SKILL_LINES_CHANGED")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    C_Timer.After(LOGIN_DELAY, Queue)
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "rankAlert" then Apply() end
end

events:SetScript("OnEvent", Queue)
hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

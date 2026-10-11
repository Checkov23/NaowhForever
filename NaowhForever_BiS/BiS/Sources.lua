-- Sources.lua: where a click on an item's source takes you (B.Sources).
local ns = _G.NaowhForever

local B = ns.BiS
local R = B.Rankings
local Shared = ns.Shared
local Parts, Places = Shared.Parts, Shared.Places

local FACTION_TABS = { "reputation", "pvp" }
local TEXT_BACK = ns.L("Back to BiS List")
local HINTS = {
    dungeon = ns.L("Click: open it in the Dungeon Journal"),
    quest = ns.L("Click: show the quest"),
    zone = ns.L("Click: show it on your map"),
    wowhead = ns.L("Click: copy its Wowhead link"),
}
local TEXT_FACTION_HINT = ns.L("Click: open %s in the Dungeon Journal")
local TEXT_NPC_HINT = ns.L("Click: a waypoint on %s")
local TEXT_RECIPE_HINT = ns.L("Click: open the recipe")
local TEXT_RECIPE_COPY_HINT = ns.L("Click: copy its recipe's Wowhead link")
local EMPTY = {}

local kinds, targets = {}, {}
local factionOf, questOf, recipeOf

local function IndexFactions(J)
    for _, tab in ipairs(FACTION_TABS) do
        for _, faction in ipairs(J.Factions(tab)) do
            for _, tier in ipairs(faction.tiers) do
                for _, id in ipairs(tier.items) do factionOf[id] = factionOf[id] or faction end
            end
        end
    end
end

local function Index()
    if factionOf then return end
    factionOf, questOf, recipeOf = {}, {}, {}
    local J = ns.Journal
    if J and J.Factions then IndexFactions(J) end
    for questID, items in pairs(J and J.BiSQuestRewards or EMPTY) do
        for _, id in ipairs(items) do questOf[id] = questOf[id] or questID end
    end
    for _, profession in pairs(ns.RecipeData or EMPTY) do
        for _, recipe in ipairs(profession.recipes or EMPTY) do
            if recipe.item then recipeOf[recipe.item] = recipeOf[recipe.item] or recipe.spell end
        end
    end
end

local function Find(itemID)
    local target = R.DropDungeon(itemID)
    if target then return "dungeon", target end
    if factionOf[itemID] then return "faction", factionOf[itemID] end
    if questOf[itemID] then return "quest", questOf[itemID] end
    if (ns.BiSSpots or EMPTY)[itemID] then return "npc", ns.BiSSpots[itemID] end
    if recipeOf[itemID] then return "recipe", recipeOf[itemID] end
    local place = R.Place(ns.BiSSource(itemID) or "")
    target = Places and Places.Zone(place)
    return target and "zone" or "wowhead", target
end

local function CanOpenRecipe(spell)
    return C_TradeSkillUI.IsRecipeProfessionLearned(spell) == true
end

local function Waypoint(itemID, spot, name)
    ns.PlaceWaypoint(spot.name, spot.map, spot.x, spot.y, name and " (" .. name .. ")", C_Item.GetItemIconByID(itemID))
    if Places.ShowMap(spot.map) then B.StepAside("map") end
end

local function Recipe(spell, name)
    if CanOpenRecipe(spell) then
        C_TradeSkillUI.OpenRecipe(spell)
    else
        Parts.CopyWowhead("spell", spell, name)
    end
end

local Sources = {}
B.Sources = Sources

function Sources.Of(itemID)
    local kind = kinds[itemID]
    if kind then return kind, targets[itemID] end
    Index()
    local target
    kind, target = Find(itemID)
    kinds[itemID], targets[itemID] = kind, target
    return kind, target
end

function Sources.Hint(itemID)
    local kind, target = Sources.Of(itemID)
    if kind == "faction" then return TEXT_FACTION_HINT:format(target.name) end
    if kind == "npc" then return TEXT_NPC_HINT:format(target.name) end
    if kind == "recipe" then return CanOpenRecipe(target) and TEXT_RECIPE_HINT or TEXT_RECIPE_COPY_HINT end
    return HINTS[kind] or HINTS.wowhead
end

function Sources.Go(itemID)
    local kind, target = Sources.Of(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    if kind == "dungeon" or kind == "faction" then
        B.StepAside("journal")
        ns.OpenJournalWindow(target, B.BackFromJournal, TEXT_BACK, itemID)
    elseif kind == "quest" then
        if not B.ShowQuest(target) then Parts.CopyWowhead("quest", target, name) end
    elseif kind == "npc" then
        Waypoint(itemID, target, name)
    elseif kind == "recipe" then
        Recipe(target, name)
    elseif kind == "zone" then
        if Places.ShowMap(target) then B.StepAside("map") end
    else
        Parts.CopyWowhead("item", itemID, name)
    end
end

-- Search.lua: a search of Forever's group finder from the Browse screen, for the activities that suit your level, all of them or one dungeon (ns.GroupFinder.Search).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local S = GF.Settings
local Listings = GF.Listings

local SEARCH_WAIT = 15
local NO_FILTER, NO_PREFERRED = 0, 0
local LEVEL, ALL = "level", "all"

local Search = { state = "idle", pick = LEVEL, LEVEL = LEVEL, ALL = ALL, SEARCH_WAIT = SEARCH_WAIT }
GF.Search = Search

local wanted = {}
local generation = 0

local function Listed(entry, id)
    if not entry then return false end
    for _, listed in ipairs(entry.activityIDs) do
        if listed == id then return true end
    end
    return false
end

local function Suits(activity, level)
    return not ((activity.min > 0 and activity.min > level) or (activity.max > 0 and activity.max < level))
end

local function Fill(categoryID, level, entry)
    wipe(wanted)
    local suited, pick = false, Search.pick
    for _, id in ipairs(C_LFGList.GetAvailableActivities(categoryID)) do
        local activity = Listings.Activity(id)
        local suits = activity ~= nil and Suits(activity, level)
        suited = suited or suits
        if pick == ALL or pick == id or (pick == LEVEL and (suits or Listed(entry, id))) then
            wanted[#wanted + 1] = id
        end
    end
    return suited
end

local function Category()
    local level, entry = UnitLevel("player"), C_LFGList.GetActiveEntryInfo()
    local categories = C_LFGList.GetAvailableCategories()
    for i = 1, #categories do
        if Fill(categories[i], level, entry) then return categories[i] end
    end
end

Search.Category = Category

function Search.Suits(activityID)
    local activity = Listings.Activity(activityID)
    return activity ~= nil and Suits(activity, UnitLevel("player"))
end

local function ByLevel(a, b)
    local x, y = Listings.Activity(a), Listings.Activity(b)
    if x.min ~= y.min then return x.min < y.min end
    return x.name < y.name
end

function Search.Activities(list)
    wipe(list)
    local category = Category()
    if not category then return 0 end
    for _, id in ipairs(C_LFGList.GetAvailableActivities(category)) do
        if Listings.Activity(id) then list[#list + 1] = id end
    end
    table.sort(list, ByLevel)
    return #list
end

local function Settle(state)
    generation = generation + 1
    Search.state = state
    GF.Fire("search", state)
end

function Search.Run(pick)
    if not GF.On() or Search.state == "searching" then return false end
    Search.pick = pick or Search.pick
    local category = Category()
    if not category then
        Settle("unavailable")
        return false
    end
    C_LFGList.Search(category, NO_FILTER, NO_PREFERRED, nil, false, nil, wanted)
    Settle("searching")
    local gen = generation
    C_Timer.After(SEARCH_WAIT, function()
        if gen == generation then Settle("failed") end
    end)
    return true
end

GF.Listen("listings", function(failed)
    Settle(failed and "failed" or "done")
end)

S.OnChange(function(key)
    if key == "enabled" and not GF.On() then
        generation = generation + 1
        Search.state, Search.pick = "idle", LEVEL
    end
end)

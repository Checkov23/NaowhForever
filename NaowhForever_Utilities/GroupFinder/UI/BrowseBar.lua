-- BrowseBar.lua: the Browse screen's bar: a chip for your level, every dungeon and each one, each a search, then a text filter and the sort (ns.GroupFinder.UI.BrowseBar).
local ns = _G.NaowhForever
local T = ns.THEME

local GF = ns.GroupFinder
if not GF then return end
local UI = GF.UI
local S = GF.Settings
local Listings, Search = GF.Listings, GF.Search
local Parts = ns.Shared.Parts

local St = UI.Style
local CHIP_H, CHIP_GAP, CHIP_PAD, FILTER_GAP = St.CHIP_H, St.CHIP_GAP, St.CHIP_PAD, St.FILTER_GAP
local SEARCH_H = St.SEARCH_H

local TEXT_LEVEL, TEXT_ALL = "For your level", "All"
local TEXT_CHIP = "%s %d-%d"
local TEXT_FILTER = "Filter by dungeon, leader or note"
local SORTS = { { "newest", "Newest" }, { "score", "Naowh Score" }, { "level", "Level" } }
local TEXT_SORT = ns.L("Sort: %s")
local SORT_LABELS = {}
for _, sort in ipairs(SORTS) do SORT_LABELS[sort[1]] = TEXT_SORT:format(ns.L(sort[2])) end

local activities = {}
local bar
local x, y = 0, 0

local Paint

local function NewChip(i)
    local chip = ns.Button(bar, "", 2 * CHIP_PAD, CHIP_H)
    chip.idle = chip._rest
    chip._onClick = function()
        if Search.Run(chip.pick) then Paint() end
    end
    bar.chips[i] = chip
    return chip
end

local function Place(i, pick, text, suits)
    local chip = bar.chips[i] or NewChip(i)
    chip.pick = pick
    ns.SetButtonText(chip, text)
    local w = math.ceil(chip.label:GetStringWidth()) + 2 * CHIP_PAD
    chip:SetWidth(w)
    UI.Pick(chip, Search.pick == pick, not suits and T.muted or nil)
    if x > 0 and x + w > UI.CONTENT_W then x, y = 0, y + CHIP_H + CHIP_GAP end
    chip:ClearAllPoints()
    chip:SetPoint("TOPLEFT", x, -y)
    chip:Show()
    x = x + w + CHIP_GAP
end

function Paint()
    local n = Search.Activities(activities)
    x, y = 0, 0
    Place(1, Search.LEVEL, TEXT_LEVEL, true)
    Place(2, Search.ALL, TEXT_ALL, true)
    for i = 1, n do
        local id = activities[i]
        local activity = Listings.Activity(id)
        local text = activity.max > 0 and TEXT_CHIP:format(activity.short, activity.min, activity.max) or activity.short
        Place(i + 2, id, text, Search.Suits(id))
    end
    for i = n + 3, #bar.chips do bar.chips[i]:Hide() end
    bar:SetHeight(y + CHIP_H + FILTER_GAP + SEARCH_H)
    Parts.SetLink(bar.sort, SORT_LABELS[S.Get("sort")] or SORT_LABELS.newest)
end

local function Filtered(text)
    bar.needle = text:lower()
    bar.onChange()
end

local function IsSort(key)
    return S.Get("sort") == key
end

local function SetSort(key)
    S.Set("sort", key)
end

local function SortMenu(_, root)
    root:CreateTitle(ns.L("Sort by"))
    for _, sort in ipairs(SORTS) do root:CreateRadio(ns.L(sort[2]), IsSort, SetSort, sort[1]) end
end

local function SortClicked(link)
    MenuUtil.CreateContextMenu(link, SortMenu)
end

function UI.BrowseBar(parent, onChange)
    bar = CreateFrame("Frame", nil, parent)
    bar:SetWidth(UI.CONTENT_W)
    bar.chips, bar.needle, bar.onChange = {}, "", onChange
    bar.sort = Parts.Link(bar, SortClicked, true)
    bar.sort:SetPoint("RIGHT", bar, "BOTTOMRIGHT", 0, SEARCH_H / 2)
    bar.search = Parts.SearchBox(bar, TEXT_FILTER, Filtered)
    bar.search:SetHeight(SEARCH_H)
    bar.search:SetPoint("BOTTOMLEFT")
    bar.search:SetPoint("RIGHT", bar.sort, "LEFT", -FILTER_GAP, 0)
    bar.Paint = Paint
    return bar
end

S.OnChange(function(key)
    if key == "sort" and bar then
        Parts.SetLink(bar.sort, SORT_LABELS[S.Get("sort")] or SORT_LABELS.newest)
        bar.onChange()
    end
end)

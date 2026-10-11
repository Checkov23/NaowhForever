-- RaidBar.lua: Group Inspect's raid toolbar: the Gear, Talents and Stats view, the sort menu and the filter menu (GI.UI.RaidBar).
local ns = _G.NaowhForever
local S = ns.QoLSettings
local GI = ns.GroupInspect
local UI = GI.UI
local Parts = ns.Shared.Parts
local Order = UI.RaidOrder

local St = UI.Style
local BAR_SPACE, VIEWS_W, BAR_ROOM, FILTER_PAD = 16, 210, 240, 8

local VIEWS = {
    { key = "gear", label = "Gear", tip = "Everyone's gear, with its item level and enchants on hover." },
    { key = "talents", label = "Talents", tip = "Everyone's talent points per tree." },
    { key = "stats", label = "Stats", tip = "Everyone's key stats." },
}
local SORTS_LIST = { { "score", "Naowh Score" }, { "ilvl", "Item Level" }, { "name", "Name" },
    { "class", "Class" }, { "role", "Role" } }
local TEXT_SORT = ns.L("Sort: %s")
local SORT_LABELS = {}
for _, sort in ipairs(SORTS_LIST) do SORT_LABELS[sort[1]] = TEXT_SORT:format(ns.L(sort[2])) end
local FILTERS, FILTERS_N = ns.L("Filters"), ns.L("Filters (%d)")

local FILTER_GROUPS = {
    { title = ns.L("Class"), items = {} },
    { title = ns.L("Role"), items = { { group = "role", value = "TANK", label = ns.L("Tank") },
        { group = "role", value = "HEALER", label = ns.L("Healer") }, { group = "role", value = "DAMAGER", label = ns.L("Damage") } } },
    { title = ns.L("Armor"), items = { { group = "armor", value = ns.L("Cloth"), label = ns.L("Cloth") },
        { group = "armor", value = ns.L("Leather"), label = ns.L("Leather") }, { group = "armor", value = ns.L("Mail"), label = ns.L("Mail") },
        { group = "armor", value = ns.L("Plate"), label = ns.L("Plate") } } },
}
for _, class in ipairs(UI.CLASS_ORDER) do
    local items = FILTER_GROUPS[1].items
    items[#items + 1] = { group = "class", value = class, label = UI.CLASS_NAMES[class] }
end
local NF_ITEM = { group = "nf", label = ns.L("Runs Naowh Forever") }
local BARE_ITEM = { group = "bare", label = ns.L("Missing enchants") }

local IsFiltered, ToggleFilter = Order.IsFiltered, UI.ToggleFilter

local bar

function UI.PaintRaidBar()
    if not bar then return end
    Parts.PaintTabs(bar.views, S.Get("groupInspectView"))
    Parts.SetLink(bar.sort, SORT_LABELS[S.Get("groupInspectSort")] or SORT_LABELS.score)
    local n = Order.FilterCount()
    local button = bar.filter
    button.label:SetText(n > 0 and FILTERS_N:format(n) or FILTERS)
    button:SetWidth(St.BAR_ICON + FILTER_PAD + math.ceil(button.label:GetStringWidth()))
    Parts.LightBarIcon(button, n > 0)
end

local function IsSort(key)
    return S.Get("groupInspectSort") == key
end

local function SetSort(key)
    S.Set("groupInspectSort", key)
end

local function SortMenu(_, root)
    root:CreateTitle(ns.L("Sort by"))
    for _, sort in ipairs(SORTS_LIST) do root:CreateRadio(ns.L(sort[2]), IsSort, SetSort, sort[1]) end
end

local function SortClicked(link)
    MenuUtil.CreateContextMenu(link, SortMenu)
end

local function FilterMenu(_, root)
    for _, group in ipairs(FILTER_GROUPS) do
        root:CreateTitle(group.title)
        for _, item in ipairs(group.items) do root:CreateCheckbox(item.label, IsFiltered, ToggleFilter, item) end
        root:CreateDivider()
    end
    root:CreateCheckbox(NF_ITEM.label, IsFiltered, ToggleFilter, NF_ITEM)
    root:CreateCheckbox(BARE_ITEM.label, IsFiltered, ToggleFilter, BARE_ITEM)
    if Order.FilterCount() > 0 then
        root:CreateDivider()
        root:CreateButton(ns.L("Clear filters"), UI.ClearFilters)
    end
end

local function FilterClicked(button)
    MenuUtil.CreateContextMenu(button, FilterMenu)
end

local function PickView(key)
    S.Set("groupInspectView", key)
end

function UI.RaidBar(parent)
    bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(VIEWS_W + 2 * BAR_SPACE + BAR_ROOM, St.TAB_H)
    bar.filter = Parts.BarButton(bar, St.FUNNEL, "Filters", ns.L("Shows only part of the raid."), FilterClicked, FILTERS)
    bar.filter:SetPoint("RIGHT")
    bar.sort = Parts.Link(bar, SortClicked, true)
    bar.sort:SetPoint("RIGHT", bar.filter, "LEFT", -BAR_SPACE, 0)
    bar.views = Parts.Tabs(bar, VIEWS_W, VIEWS, PickView)
    bar.views:SetPoint("RIGHT", bar.sort, "LEFT", -BAR_SPACE, 0)
    UI.PaintRaidBar()
    return bar
end

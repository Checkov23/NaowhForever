-- Entries.lua: what the recipe list holds: your recipes by category, then the unlearned ones by what they need.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local W = P.State
local Filters = P.Filters

local OTHER_ORDER = 999
local TEXT_OTHER = OTHER or ns.L("Other")

local LEARNED = { name = ns.L("Learned"), key = "profLearnedCollapsed", closed = false }
local UNLEARNED = { name = ns.L("Unlearned"), key = "profUnlearnedCollapsed", closed = false }
local UNLEARNED_GROUPS = {
    { status = "ready", name = ns.L("Learnable now"), key = "profUnlearnedReadyCollapsed", closed = false, sub = true },
    { status = "later", name = ns.L("Needs more skill"), key = "profUnlearnedLaterCollapsed", closed = true, sub = true },
    { status = "rank", name = ns.L("Needs next rank"), key = "profUnlearnedRankCollapsed", closed = true, sub = true },
}

local EMPTY = {}
local categories, entries, unlearned = {}, {}, EMPTY
local collapsed = {}
local catPool, byID, learned, entryPool = {}, {}, {}, {}
local shown, shownUnlearned, inGroup, status = {}, {}, {}, {}
local recipeCount = 0

local function ByOrder(a, b)
    if a.order ~= b.order then return a.order < b.order end
    return a.name < b.name
end

local function Category(catID, used)
    local ci = catID > 0 and C_TradeSkillUI.GetCategoryInfo(catID)
    local cat = catPool[used]
    if not cat then
        cat = { recipes = {}, sub = true }
        catPool[used] = cat
    end
    cat.id, cat.name, cat.order = catID, ci and ci.name or TEXT_OTHER, ci and ci.uiOrder or OTHER_ORDER
    wipe(cat.recipes)
    byID[catID] = cat
    categories[#categories + 1] = cat
    return cat
end

local function Collect()
    wipe(categories)
    wipe(byID)
    wipe(learned)
    local used = 0
    local ids = C_TradeSkillUI.GetAllRecipeIDs() or EMPTY
    recipeCount = #ids
    for _, id in ipairs(ids) do
        local info = C_TradeSkillUI.GetRecipeInfo(id)
        if info then
            learned[id] = info.learned and true or false
            info.numAvailable = nil
        end
        if info and info.learned then
            local catID = info.categoryID or 0
            local cat = byID[catID]
            if not cat then
                used = used + 1
                cat = Category(catID, used)
            end
            cat.recipes[#cat.recipes + 1] = info
        end
    end
    table.sort(categories, ByOrder)
    unlearned = not W.linked and ns.RecipeFinder and ns.RecipeFinder.Unlearned(learned) or EMPTY
end

local function GroupClosed(group)
    local v = S.Get(group.key)
    if v == nil then return group.closed end
    return v
end

local function IsCollapsed(cat)
    if W.query ~= "" then return false end
    if cat.key then return GroupClosed(cat) end
    return collapsed[cat.name]
end

local function Toggle(cat)
    if cat.key then
        S.Set(cat.key, not GroupClosed(cat))
    else
        collapsed[cat.name] = not collapsed[cat.name] or nil
    end
end

local function Matches(info)
    return W.query == "" or (info.name and info.name:lower():find(W.query, 1, true) ~= nil)
end

local function MatchesUnlearned(r)
    return W.query == "" or (C_Spell.GetSpellName(r.spell) or ""):lower():find(W.query, 1, true)
end

local function Add(kind, value)
    local n = #entries + 1
    local e = entryPool[n]
    if not e then
        e = {}
        entryPool[n] = e
    end
    e.cat, e.recipe, e.unlearned = nil, nil, nil
    e[kind] = value
    entries[n] = e
end

local function AddLearned()
    local first, found
    local learnedAt, learnedCount = #entries + 1, 0
    Add("cat", LEARNED)
    local learnedOpen = not IsCollapsed(LEARNED)
    for _, cat in ipairs(categories) do
        wipe(shown)
        for _, info in ipairs(cat.recipes) do
            if Matches(info) and Filters.Passes(info) then shown[#shown + 1] = info end
        end
        if #shown > 0 then
            learnedCount = learnedCount + #shown
            if learnedOpen then Add("cat", cat) end
            local open = learnedOpen and not IsCollapsed(cat)
            for _, info in ipairs(shown) do
                first = first or info.recipeID
                if info.recipeID == W.selectedID then found = true end
                if open then Add("recipe", info) end
            end
        end
    end
    LEARNED.count = learnedCount
    if learnedCount == 0 then entries[learnedAt] = nil end
    return first, found
end

local function AddGroup(group, open)
    local found = false
    wipe(inGroup)
    for _, r in ipairs(shownUnlearned) do
        if status[r] == group.status then inGroup[#inGroup + 1] = r end
    end
    group.count = #inGroup
    if open and #inGroup > 0 then Add("cat", group) end
    local groupOpen = open and not IsCollapsed(group)
    for _, r in ipairs(inGroup) do
        if r == W.selectedUnlearned then found = true end
        if groupOpen then Add("unlearned", r) end
    end
    return found
end

local function AddUnlearned()
    local found = false
    wipe(shownUnlearned)
    for _, r in ipairs(unlearned) do
        if MatchesUnlearned(r) and Filters.Passes(nil, r) then
            shownUnlearned[#shownUnlearned + 1] = r
            status[r] = ns.RecipeFinder.Status(r)
        end
    end
    if #shownUnlearned == 0 then return false end
    UNLEARNED.count = #shownUnlearned
    Add("cat", UNLEARNED)
    local open = not IsCollapsed(UNLEARNED)
    for _, group in ipairs(UNLEARNED_GROUPS) do
        if AddGroup(group, open) then found = true end
    end
    return found
end

local function Build()
    wipe(entries)
    local first, found = AddLearned()
    local foundUnlearned = AddUnlearned()
    if not foundUnlearned then W.selectedUnlearned = nil end
    if not found then W.selectedID = first end
end

local function Count()
    return recipeCount
end

P.Entries = {
    list = entries,
    Collect = Collect,
    Build = Build,
    IsCollapsed = IsCollapsed,
    Toggle = Toggle,
    Count = Count,
}

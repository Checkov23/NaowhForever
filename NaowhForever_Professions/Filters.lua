-- Filters.lua: the Filter menu's choices and which recipes, learned or not, pass them.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local W = P.State
local R = P.Recipes
local Prices = P.Prices
local Favorites = P.Favorites

local TRIVIAL = 3
local BIND_INDEX = 14
local BIND_NEVER = 0

local FILTERS = {
    { key = "filterFavorite", text = ns.L("Favorites") },
    { key = "filterMaterials", text = ns.L("Have Materials") },
    { key = "filterSkillUp", text = ns.L("Has Skill-Up") },
    { key = "filterProfit", text = ns.L("Profitable"), profit = true },
    { key = "filterBoE", text = ns.L("Bind on Equip"), bind = 2, divider = true },
    { key = "filterBoP", text = ns.L("Bind on Pickup"), bind = 1 },
}
for _, f in ipairs(FILTERS) do FILTERS[f.key] = f end

local function FilterOn(f)
    return S.Get(f.key) and (not f.profit or Prices.ProfitShown())
end

local function MadeItem(info, r)
    if info then return R.OutputItem(info.recipeID) end
    return r.item or R.OutputItem(r.spell)
end

local function PassesBind(info, r)
    local boe, bop = FilterOn(FILTERS.filterBoE), FilterOn(FILTERS.filterBoP)
    if not (boe or bop) then return true end
    local item = MadeItem(info, r)
    local bind = item and select(BIND_INDEX, C_Item.GetItemInfo(item))
    if item and bind == nil then R.Request(item) end
    local asBoE = bind == FILTERS.filterBoE.bind or bind == BIND_NEVER
    return (boe and asBoE) or (bop and bind == FILTERS.filterBoP.bind)
end

local function Profitable(recipeID, output, made)
    local profit = Prices.RecipeProfit(recipeID, output, made)
    return profit and profit > 0
end

local function PassesLearned(info)
    if FilterOn(FILTERS.filterMaterials) and R.Craftable(info) == 0 then return false end
    if FilterOn(FILTERS.filterSkillUp) and info.relativeDifficulty == TRIVIAL then return false end
    if FilterOn(FILTERS.filterProfit) and not Profitable(info.recipeID, R.OutputItem(info.recipeID)) then
        return false
    end
    return true
end

local function PassesUnlearned(r)
    if FilterOn(FILTERS.filterMaterials) then return false end
    if FilterOn(FILTERS.filterProfit) then
        local read, made = R.OutputItem(r.spell)
        if not Profitable(r.spell, r.item or read, made) then return false end
    end
    return true
end

local function Passes(info, r)
    if W.linked then return true end
    if FilterOn(FILTERS.filterFavorite) and not Favorites.Is(info or r) then return false end
    if not PassesBind(info, r) then return false end
    if info then return PassesLearned(info) end
    return PassesUnlearned(r)
end

local function Active()
    local n = 0
    for _, f in ipairs(FILTERS) do
        if FilterOn(f) then n = n + 1 end
    end
    return n
end

P.Filters = {
    LIST = FILTERS,
    Passes = Passes,
    Active = Active,
}

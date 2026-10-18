-- Patterns.lua: your favourite recipes not learned yet: a trainer's offers of them, and their patterns to buy.
local ns = _G.NaowhForever

local IsUsableItem = C_Item.IsUsableItem

local P = ns.Professions

local KINDS = { available = true, unavailable = true, used = true, header = true }
local ICON_MIN_ID = 1000
local SECONDS_PER_DAY = 86400
local BOUGHT_KEEP = 30 * SECONDS_PER_DAY
local SKILL_LINE_INDEX = P.C.SKILL_LINE_INDEX

local NONE = {}
local mine, patterns, patternPool = {}, {}, {}

local function Favorites()
    return ns.ProfFavorites and ns.ProfFavorites.Store() or {}
end

local function Known(spell)
    local info = C_TradeSkillUI.GetRecipeInfo(spell)
    if info and info.learned then return true end
    return (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spell)) or false
end

local function Learnable(item)
    return IsUsableItem(item)
end

local function ServiceInfo(i)
    local values = { GetTrainerServiceInfo(i) }
    local kind, icon
    for k = 2, #values do
        local v = values[k]
        if not kind and type(v) == "string" and KINDS[v] then kind = v end
        if not icon and type(v) == "number" and v > ICON_MIN_ID then icon = v end
    end
    return values[1], kind, icon
end

local function FavoritesByName()
    local byName = {}
    for spell, on in pairs(Favorites()) do
        if on and not Known(spell) then
            local name = C_Spell.GetSpellName(spell)
            if name then byName[name] = spell end
        end
    end
    return byName
end

local function TrainerOffers()
    if not (IsTradeskillTrainer and IsTradeskillTrainer()) then return {} end
    local byName = FavoritesByName()
    local out = {}
    for i = 1, GetNumTrainerServices() do
        local name, kind, icon = ServiceInfo(i)
        if not kind and name and byName[name] then
            local _, _, met = GetTrainerServiceSkillReq(i)
            kind = met ~= false and "available" or "unavailable"
        end
        if name and kind == "available" and byName[name] then
            out[#out + 1] = { index = i, name = name, spell = byName[name],
                cost = GetTrainerServiceCost(i) or 0,
                icon = icon or (GetTrainerServiceIcon and GetTrainerServiceIcon(i))
                    or C_Spell.GetSpellTexture(byName[name]) }
        end
    end
    return out
end

local function LastFirst(a, b)
    return a.index > b.index
end

local function Learn(offers)
    local money = GetMoney()
    table.sort(offers, LastFirst)
    for _, o in ipairs(offers) do
        if o.cost <= money and ServiceInfo(o.index) == o.name then
            BuyTrainerService(o.index)
            money = money - o.cost
        end
    end
end

local function Bought()
    return P.CharacterData("profBoughtPatterns", true) or {}
end

local function Owned(item)
    if (C_Item.GetItemCount(item, true, false, true) or 0) > 0 then return true end
    local at = Bought()[item]
    if at and time() - at < BOUGHT_KEEP then return true end
    if at then Bought()[item] = nil end
    return false
end

local function Mine(index)
    local line = index and select(SKILL_LINE_INDEX, GetProfessionInfo(index))
    if line then mine[line] = true end
end

local function PricedFirst(a, b)
    if (a.price ~= nil) ~= (b.price ~= nil) then return a.price ~= nil end
    if a.price and b.price and a.price ~= b.price then return a.price < b.price end
    return a.r.spell < b.r.spell
end

local function List()
    wipe(mine)
    local p1, p2, p3, p4, p5 = GetProfessions()
    Mine(p1)
    Mine(p2)
    Mine(p3)
    Mine(p4)
    Mine(p5)
    local favorites, n = Favorites(), 0
    for line, data in pairs(ns.RecipeData or NONE) do
        if mine[line] then
            for _, r in ipairs(data.recipes) do
                if r.recipe and favorites[r.spell] and not Known(r.spell) and not Owned(r.recipe) then
                    n = n + 1
                    local e = patternPool[n] or {}
                    patternPool[n] = e
                    e.r, e.item, e.price = r, r.recipe, ns.AuctionPrice and ns.AuctionPrice(r.recipe)
                    patterns[n] = e
                end
            end
        end
    end
    for i = n + 1, #patterns do patterns[i] = nil end
    table.sort(patterns, PricedFirst)
    return patterns
end

P.Patterns = {
    TrainerOffers = TrainerOffers,
    Learn = Learn,
    Learnable = Learnable,
    Bought = Bought,
    List = List,
}

ns.TrainerServiceInfo = ServiceInfo

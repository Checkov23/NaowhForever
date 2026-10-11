-- ShoppingPlan.lua: the shopping list's crafts and materials, and the cheapest way to each: bought or made.
local ns = _G.NaowhForever

local P = ns.Professions
local C = P.C
local Text = P.Text

local MAX_DEPTH = 4
local SKILL_LINE_INDEX = C.SKILL_LINE_INDEX
local NO_ITEM = 0
local TEXT_UNKNOWN = "?"
local TEXT_ITEM = ns.L("item ")
local TEXT_ADDED = ns.L("Shopping list: %s for %d %s (%s).")
local TEXT_CRAFT, TEXT_CRAFTS = ns.L("craft"), ns.L("crafts")
local TEXT_PART = "%dx %s"
local TEXT_ESTIMATE = ns.L("About %s at your last scan%s%s")
local TEXT_AGO = ns.L(" ago")
local TEXT_NO_SCAN = ns.L(" (none yet)")
local TEXT_MISSING = ", %d %s"

local EMPTY = {}
local waiting = {}
local shopPlan = { cost = {}, make = {}, craft = {}, busy = {}, planned = {}, saves = {} }
local demand, nextDemand, toMake, buy, had = {}, {}, {}, {}, {}
local trials = {}
for depth = 0, MAX_DEPTH do trials[depth] = { left = {}, made = {} } end
local materialList, materialPool = {}, {}

local Shopping = { waiting = waiting }
P.Shopping = Shopping

local function ItemName(item)
    local name = C_Item.GetItemNameByID(item)
    if not name then
        waiting[item] = true
        C_Item.RequestLoadItemDataByID(item)
    end
    return name
end

local function Mine(name)
    local account = ns.AccountSettings()
    if type(account[name]) ~= "table" then account[name] = {} end
    local key = (UnitName("player") or TEXT_UNKNOWN) .. "-" .. (GetRealmName() or TEXT_UNKNOWN)
    account[name][key] = account[name][key] or {}
    return account[name][key]
end

local function List()
    return Mine("profShopping")
end

local function Have()
    return Mine("profShopHave")
end

local function Makes()
    return Mine("profMakes")
end

local function Keep()
    local account = ns.AccountSettings()
    if type(account.profShopKeep) ~= "table" then account.profShopKeep = {} end
    return account.profShopKeep
end

local function Reach()
    local reach, makes = {}, Makes()
    local function Use(item, qty, depth)
        reach[item] = (reach[item] or 0) + qty
        local m = makes[item]
        if m and depth < MAX_DEPTH then
            local crafts = math.ceil(qty / m.made)
            for part, per in pairs(m.need) do Use(part, per * crafts, depth + 1) end
        end
    end
    for _, craft in pairs(List()) do
        for item, per in pairs(craft.need) do Use(item, per * craft.count, 0) end
    end
    return reach
end

local function Trim()
    local have, reach = Have(), Reach()
    for item, qty in pairs(have) do
        local most = reach[item] or 0
        if qty > most then have[item] = most > 0 and most or nil end
    end
end

local function BuyPrice(item)
    local scan = ns.AuctionPrice and ns.AuctionPrice(item)
    local api = ns.ProfWindowAPI
    local vendor = api and api.IsVendorItem(item) and ns.AccountSettings().profVendorPrices
    vendor = vendor and vendor[item]
    if scan and vendor then return math.min(scan, vendor) end
    return scan or vendor
end

local Cheapest

local function PartsCost(m, plan, depth)
    local total = 0
    for part, per in pairs(m.need) do
        local c = plan.owned[part] and 0 or Cheapest(part, plan, depth + 1)
        if not c then return nil end
        total = total + c * per
    end
    return total
end

function Cheapest(item, plan, depth, ignoreKeep)
    if not ignoreKeep and plan.cost[item] ~= nil then return plan.cost[item] or nil, plan.make[item] end
    local bought, make = BuyPrice(item), false
    local cost, m = bought, Makes()[item]
    if m and not m.cooldown and depth < MAX_DEPTH and not plan.busy[item] and (ignoreKeep or not Keep()[item]) then
        plan.busy[item] = true
        local total = PartsCost(m, plan, depth)
        plan.busy[item] = nil
        if total and (not bought or total / m.made < bought) then cost, make = total / m.made, true end
        if make and not ignoreKeep then plan.craft[item] = total end
    end
    if not ignoreKeep then plan.cost[item], plan.make[item] = cost or false, make end
    return cost, make
end

local function ByName(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.item < b.item
end

local function Listed(part)
    local api = ns.ProfWindowAPI
    return not shopPlan.owned[part] and not (api and api.IsVendorItem(part))
end

local function Supply(item, want, from, into, depth)
    local got = math.min(want, from[item] or 0)
    if got > 0 then from[item] = from[item] - got end
    local m = shopPlan.makes[item]
    if not m or m.cooldown or depth >= MAX_DEPTH then return got end
    local listed = false
    for part in pairs(m.need) do listed = listed or Listed(part) end
    local trial, trialMade = trials[depth].left, trials[depth].made
    while listed and got < want do
        wipe(trial)
        wipe(trialMade)
        for k, v in pairs(from) do trial[k] = v end
        local whole = true
        for part, per in pairs(m.need) do
            if Listed(part) and Supply(part, per, trial, trialMade, depth + 1) < per then
                whole = false
                break
            end
        end
        if not whole then break end
        for k in pairs(from) do from[k] = trial[k] end
        for k, v in pairs(trialMade) do into[k] = (into[k] or 0) + v end
        into[item] = (into[item] or 0) + m.made
        got = got + m.made
    end
    return got
end

local function ResetPlan()
    local api = ns.ProfWindowAPI
    wipe(shopPlan.cost); wipe(shopPlan.make); wipe(shopPlan.craft)
    wipe(shopPlan.busy); wipe(shopPlan.planned); wipe(shopPlan.saves)
    shopPlan.owned = api and api.Owned() or {}
    shopPlan.makes = Makes()
    wipe(demand); wipe(toMake); wipe(buy); wipe(had)
    for _, craft in pairs(List()) do
        for item, per in pairs(craft.need) do
            demand[item] = (demand[item] or 0) + per * craft.count - (craft.got and craft.got[item] or 0)
        end
    end
    for item, qty in pairs(Have()) do had[item] = qty end
end

local function PlanItem(item, qty, depth)
    if qty > 0 then qty = qty - Supply(item, qty, had, toMake, depth) end
    if qty <= 0 then return end
    local _, make = Cheapest(item, shopPlan, 0)
    local m, price, craft = shopPlan.makes[item], BuyPrice(item), shopPlan.craft[item]
    local crafts = m and math.ceil(qty / m.made)
    if make and price and craft and crafts * craft >= qty * price then make = false end
    if not (make and depth < MAX_DEPTH) then
        buy[item] = (buy[item] or 0) + qty
        return
    end
    toMake[item] = (toMake[item] or 0) + crafts * m.made
    shopPlan.planned[item] = true
    if price and craft then shopPlan.saves[item] = (shopPlan.saves[item] or 0) + qty * price - crafts * craft end
    for part, per in pairs(m.need) do
        if Listed(part) then nextDemand[part] = (nextDemand[part] or 0) + per * crafts end
    end
end

local function Materials()
    ResetPlan()
    for depth = 0, MAX_DEPTH do
        wipe(nextDemand)
        for item, qty in pairs(demand) do PlanItem(item, qty, depth) end
        demand, nextDemand = nextDemand, demand
        if next(demand) == nil then break end
    end
    local n = 0
    for item, qty in pairs(buy) do
        n = n + 1
        local m = materialPool[n] or {}
        materialPool[n] = m
        m.item, m.qty, m.name = item, qty, ItemName(item) or ""
        materialList[n] = m
    end
    for i = n + 1, #materialList do materialList[i] = nil end
    table.sort(materialList, ByName)
    return materialList, toMake, shopPlan
end

local function Drop(item, qty)
    local have = Have()
    have[item] = (have[item] or 0) + (qty or 0)
end

local function HasCooldown(recipeID, was)
    if was or P.CooldownRecipes[recipeID] then return true end
    local base = GetSpellBaseCooldown and GetSpellBaseCooldown(recipeID)
    if base and base > 0 then return true end
    local ok, left, isDay = pcall(C_TradeSkillUI.GetRecipeCooldown, recipeID)
    return ok and ((left and left > 0) or isDay) and true or false
end

local function RecordRecipe(api, makes, id, prof, seen)
    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, id, false)
    local output = ok and schematic and schematic.outputItemID
    if not (output and output > NO_ITEM) then return end
    local need = {}
    local okR, reagents = pcall(api.Reagents, id)
    for _, r in ipairs(okR and reagents or EMPTY) do need[r.itemID] = r.need end
    if not next(need) then return end
    local old = makes[output]
    makes[output] = { recipe = id, made = math.max(1, schematic.quantityMin or 1), need = need,
        cooldown = HasCooldown(id, old and old.recipe == id and old.cooldown), prof = prof }
    seen[output] = true
end

local function ForgetDropped(makes, prof, seen)
    local mine = {}
    for _, index in pairs({ GetProfessions() }) do
        local line = select(SKILL_LINE_INDEX, GetProfessionInfo(index))
        if line then mine[line] = true end
    end
    for output, m in pairs(makes) do
        if (m.prof == prof and not seen[output]) or (mine[prof] and m.prof and not mine[m.prof]) then
            makes[output] = nil
        end
    end
end

local function Learn()
    local api = ns.ProfWindowAPI
    if not (api and api.Own and C_TradeSkillUI.GetAllRecipeIDs) or not api.Own() then return end
    local makes = Makes()
    local base = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    local prof = base and base.professionID
    local seen = {}
    for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or EMPTY) do
        local info = C_TradeSkillUI.GetRecipeInfo(id)
        if info and info.learned then RecordRecipe(api, makes, id, prof, seen) end
    end
    if not prof then return end
    ForgetDropped(makes, prof, seen)
end

local function Estimate(materials, unpriced)
    local est, missing = 0, 0
    for _, m in ipairs(materials) do
        local price = BuyPrice(m.item)
        if price then est = est + price * m.qty else missing = missing + 1 end
    end
    local at = ns.AuctionScanTime and ns.AuctionScanTime()
    return TEXT_ESTIMATE:format(Text.Short(est),
        at and ns.AuctionAge and (", " .. ns.AuctionAge(time() - at) .. TEXT_AGO) or TEXT_NO_SCAN,
        missing > 0 and TEXT_MISSING:format(missing, unpriced) or "")
end

local function Needs(recipeID)
    local api = ns.ProfWindowAPI
    local out, owned = {}, api.Owned()
    local ok, reagents = pcall(api.Reagents, recipeID)
    for _, r in ipairs(ok and reagents or EMPTY) do
        if not owned[r.itemID] and not api.IsVendorItem(r.itemID) then out[r.itemID] = r.need end
    end
    return out
end

local function HasNeeds(recipeID)
    local api = ns.ProfWindowAPI
    local owned = api.Owned()
    local ok, reagents = pcall(api.Reagents, recipeID)
    if not ok then return false end
    for _, r in ipairs(reagents) do
        if not owned[r.itemID] and not api.IsVendorItem(r.itemID) then return true end
    end
    return false
end

local function Redraw()
    if Shopping.Render then Shopping.Render() end
end

local function Add(info, crafts)
    local need = Needs(info.recipeID)
    if next(need) == nil then return end
    local list = List()
    local craft = list[info.recipeID]
    if craft then
        craft.count = craft.count + crafts
        craft.icon = craft.icon or info.icon
        for item, per in pairs(need) do craft.need[item] = per end
    else
        list[info.recipeID] = { name = info.name, icon = info.icon, count = crafts, need = need }
    end
    local parts = {}
    for item, per in pairs(need) do
        parts[#parts + 1] = TEXT_PART:format(per * crafts, ItemName(item) or (TEXT_ITEM .. item))
    end
    ns.Print(TEXT_ADDED:format(info.name, crafts, crafts == 1 and TEXT_CRAFT or TEXT_CRAFTS, table.concat(parts, ", ")))
    Redraw()
end

local function Step(recipeID, by)
    local craft = recipeID and List()[recipeID]
    if not craft then return end
    craft.count = math.max(1, math.min(C.MAX_CRAFTS, craft.count + by))
    Trim()
    Redraw()
end

local function Remove(recipeID)
    List()[recipeID] = nil
    Trim()
    Redraw()
end

local function Clear()
    wipe(List())
    Trim()
    Redraw()
end

Shopping.ItemName = ItemName
Shopping.List = List
Shopping.Have = Have
Shopping.Makes = Makes
Shopping.Keep = Keep
Shopping.Trim = Trim
Shopping.BuyPrice = BuyPrice
Shopping.Cheapest = Cheapest
Shopping.Materials = Materials
Shopping.Drop = Drop
Shopping.Learn = Learn
Shopping.Estimate = Estimate
Shopping.HasNeeds = HasNeeds
Shopping.Add = Add
Shopping.Step = Step
Shopping.Remove = Remove
Shopping.Clear = Clear
Shopping.Redraw = Redraw
Shopping.ByName = ByName

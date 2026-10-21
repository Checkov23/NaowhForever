-- ShoppingPlan.lua: the shopping list's crafts and materials, and the cheapest way to each: bought or made.
local ns = _G.NaowhForever

local P = ns.Professions
local C = P.C
local Text = P.Text

local MAX_DEPTH = 4
local SKILL_LINE_INDEX = C.SKILL_LINE_INDEX
local NO_ITEM = 0
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
local materialList, materialPool, vendorList, vendorPool = {}, {}, {}, {}
local listeners = {}

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
    return P.CharacterData(name, true) or {}
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

local function Manual()
    return Mine("profShopItems")
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
    for item, qty in pairs(Manual()) do reach[item] = (reach[item] or 0) + qty end
    return reach
end

local function Changed()
    for i = 1, #listeners do listeners[i]() end
end

local function Trim()
    local have, reach = Have(), Reach()
    for item, qty in pairs(have) do
        local most = reach[item] or 0
        if qty > most then have[item] = most > 0 and most or nil end
    end
    Changed()
end

local function VendorOn()
    return P.Settings.Get("shoppingVendor")
end

local function SkipVendor(item)
    local api = ns.ProfWindowAPI
    return not VendorOn() and api and api.IsVendorItem(item)
end

local function VendorPrice(item)
    local api = ns.ProfWindowAPI
    return api and api.IsVendorItem(item) and api.VendorPrice(item)
end

local function BuyPrice(item)
    local scan = ns.AuctionPrice and ns.AuctionPrice(item)
    local vendor = VendorPrice(item)
    if scan and vendor then return math.min(scan, vendor) end
    return scan or vendor
end

local function BuyFromVendor(item)
    local api = ns.ProfWindowAPI
    if not (VendorOn() and api and api.IsVendorItem(item)) then return false end
    local auction, vendor = ns.AuctionPrice and ns.AuctionPrice(item), VendorPrice(item)
    return not (auction and vendor and auction < vendor)
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
    return not shopPlan.owned[part] and not SkipVendor(part)
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
    for item, qty in pairs(Manual()) do
        local got = math.min(qty, had[item] or 0)
        if got > 0 then had[item] = had[item] - got end
        if qty > got then buy[item] = (buy[item] or 0) + qty - got end
    end
    local n, vn = 0, 0
    for item, qty in pairs(buy) do
        local list, pool, index
        if BuyFromVendor(item) then
            vn = vn + 1
            list, pool, index = vendorList, vendorPool, vn
        else
            n = n + 1
            list, pool, index = materialList, materialPool, n
        end
        local m = pool[index] or {}
        pool[index] = m
        m.item, m.qty, m.name = item, qty, ItemName(item) or ""
        list[index] = m
    end
    for i = n + 1, #materialList do materialList[i] = nil end
    for i = vn + 1, #vendorList do vendorList[i] = nil end
    table.sort(materialList, ByName)
    table.sort(vendorList, ByName)
    return materialList, toMake, shopPlan, vendorList
end

local function VendorMaterials()
    local _, _, _, materials = Materials()
    return materials
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

local function EstimateList(materials, price)
    local est, missing = 0, 0
    for _, m in ipairs(materials) do
        local each = price(m.item)
        if each then est = est + each * m.qty else missing = missing + 1 end
    end
    return est, missing
end

local function Estimate(materials, unpriced, vendorMaterials)
    local est, missing = EstimateList(materials, BuyPrice)
    local vendorEst, vendorMissing = EstimateList(vendorMaterials or EMPTY, VendorPrice)
    est, missing = est + vendorEst, missing + vendorMissing
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
        if not owned[r.itemID] and not SkipVendor(r.itemID) then out[r.itemID] = r.need end
    end
    return out
end

local function HasNeeds(recipeID)
    local api = ns.ProfWindowAPI
    local owned = api.Owned()
    local ok, reagents = pcall(api.Reagents, recipeID)
    if not ok then return false end
    for _, r in ipairs(reagents) do
        if not owned[r.itemID] and not SkipVendor(r.itemID) then return true end
    end
    return false
end

local function Redraw()
    if Shopping.Render then Shopping.Render() end
    Changed()
end

local function Bought(item, qty)
    Drop(item, qty)
    local materials, _, _, vendorMaterials = Materials()
    if #materials == 0 and #vendorMaterials == 0 then
        wipe(List())
        wipe(Manual())
        Trim()
    end
end

local function OnChange(fn)
    listeners[#listeners + 1] = fn
end

local function Add(info, crafts, got, quiet, fromQueue, defer)
    local need = Needs(info.recipeID)
    if next(need) == nil then return false end
    local list = List()
    local craft = list[info.recipeID]
    if craft then
        craft.count = craft.count + crafts
        if fromQueue then craft.queueCount = (tonumber(craft.queueCount) or 0) + crafts end
        craft.icon = craft.icon or info.icon
        for item, per in pairs(need) do craft.need[item] = per end
        if got then
            craft.got = craft.got or {}
            for item, qty in pairs(got) do craft.got[item] = (craft.got[item] or 0) + qty end
        end
        craft.fromQueue = craft.queueCount ~= nil and craft.queueCount == craft.count
    else
        list[info.recipeID] = { name = info.name, icon = info.icon, count = crafts, need = need, got = got,
            fromQueue = fromQueue and true or false, queueCount = fromQueue and crafts or nil }
    end
    local parts = {}
    for item, per in pairs(need) do
        parts[#parts + 1] = TEXT_PART:format(per * crafts, ItemName(item) or (TEXT_ITEM .. item))
    end
    if not quiet then
        ns.Print(TEXT_ADDED:format(info.name, crafts, crafts == 1 and TEXT_CRAFT or TEXT_CRAFTS,
            table.concat(parts, ", ")))
    end
    if not defer then Redraw() end
    return true
end

local function Step(recipeID, by)
    local craft = recipeID and List()[recipeID]
    if not craft then return end
    local queued = craft.queueCount or 0
    local own = math.max(queued > 0 and 0 or 1, math.min(C.MAX_CRAFTS, craft.count - queued + by))
    craft.count = queued + own
    if queued > 0 then craft.fromQueue = own == 0 end
    Trim()
    Redraw()
end

local function Remove(recipeID)
    local craft = recipeID and List()[recipeID]
    List()[recipeID] = nil
    if craft and craft.queueCount then return P.CraftQueue.RemoveCraft(recipeID) end
    Trim()
    Redraw()
end

local function AddItem(item, qty)
    local items = Manual()
    items[item] = math.min(C.MAX_ITEMS, (items[item] or 0) + qty)
    Redraw()
end

local function StepItem(item, by)
    local items = Manual()
    if not items[item] then return end
    items[item] = math.max(1, math.min(C.MAX_ITEMS, items[item] + by))
    Trim()
    Redraw()
end

local function SetItem(item, qty)
    Manual()[item] = qty > 0 and math.min(C.MAX_ITEMS, qty) or nil
    Trim()
    Redraw()
end

local function RemoveItem(item)
    Manual()[item] = nil
    Trim()
    Redraw()
end

local function Clear()
    local queue = P.Settings and P.Settings.Get("craftQueue") and P.CraftQueue
    if queue then queue.Clear() end
    wipe(List())
    wipe(Manual())
    Trim()
    Redraw()
end

Shopping.ItemName = ItemName
Shopping.List = List
Shopping.Have = Have
Shopping.Makes = Makes
Shopping.Keep = Keep
Shopping.Manual = Manual
Shopping.AddItem = AddItem
Shopping.StepItem = StepItem
Shopping.SetItem = SetItem
Shopping.RemoveItem = RemoveItem
Shopping.Trim = Trim
Shopping.BuyPrice = BuyPrice
Shopping.VendorPrice = VendorPrice
Shopping.BuyFromVendor = BuyFromVendor
Shopping.Cheapest = Cheapest
Shopping.Materials = Materials
Shopping.VendorMaterials = VendorMaterials
Shopping.Drop = Drop
Shopping.Bought = Bought
Shopping.Learn = Learn
Shopping.Estimate = Estimate
Shopping.HasNeeds = HasNeeds
Shopping.Add = Add
Shopping.Step = Step
Shopping.Remove = Remove
Shopping.Clear = Clear
Shopping.Redraw = Redraw
Shopping.OnChange = OnChange
Shopping.ByName = ByName

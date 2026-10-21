-- Vendors.lua: the reagents merchants sell, what they cost there, and buying them at an open merchant.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local R = P.Recipes
local Text = P.Text

local UNLIMITED = -1
local CLASS_INDEX = 12
local PERCENT = 100
local PLAYER, NPC = "player", "npc"
local SPOT_NAME, SPOT_MAP, SPOT_X, SPOT_Y, SPOT_SIDE = 1, 2, 3, 4, 5
local TOWN_X, TOWN_Y, TOWN_NAME, TOWN_SIDE = 1, 2, 4, 7
local TEXT_TOO_DEAR = ns.L("Buy at Vendor: that costs %s, more than you have.")
local TEXT_BOUGHT = ns.L("Bought %s for %s.")
local TEXT_NO_VENDOR = ns.L("Visit a vendor that sells this item to remember its location.")
local TEXT_PART = "%dx %s"
local MERCHANT_EVENTS = { "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED" }
local MERCHANT_KEYS = { enabled = true, shoppingList = true, shoppingVendor = true, vendorMaterials = true,
    craftProfit = true, buyVendor = true }
local WAIT_EVENTS = { "BAG_UPDATE_DELAYED", "UI_ERROR_MESSAGE" }

local merchant
local shoppingList, shoppingPool, buyList, buyPool, buyParts = {}, {}, {}, {}, {}
local expected, counted = {}, {}
local townSpots
local waiting = false

local function LearnedVendorItems()
    local account = ns.AccountSettings()
    account.profVendorItems = account.profVendorItems or {}
    return account.profVendorItems
end

local function IsVendorItem(itemID)
    return P.VendorReagents[itemID] or LearnedVendorItems()[itemID] or false
end

local function VendorPrices()
    local account = ns.AccountSettings()
    account.profVendorPrices = account.profVendorPrices or {}
    return account.profVendorPrices
end

local function VendorPrice(itemID)
    return VendorPrices()[itemID] or (P.VendorPrices or {})[itemID]
end

local function LearnedSpots()
    local account = ns.AccountSettings()
    account.profVendorSpots = account.profVendorSpots or {}
    return account.profVendorSpots
end

local function TownSpots()
    if townSpots then return townSpots end
    townSpots = {}
    local wanted = {}
    for _, name in ipairs(P.VendorSellerNames or {}) do wanted[name] = true end
    for map, npcs in pairs(ns.TownNPCs or {}) do
        for _, npc in ipairs(npcs) do
            local name = npc[TOWN_NAME]
            if wanted[name] then
                local spots = townSpots[name]
                if not spots then spots = {}; townSpots[name] = spots end
                spots[#spots + 1] = { name, map, npc[TOWN_X], npc[TOWN_Y], npc[TOWN_SIDE] }
            end
        end
    end
    return townSpots
end

local function MerchantSpot()
    if not (UnitName and C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
    local name = UnitName(NPC)
    if name and issecretvalue and issecretvalue(name) then name = nil end
    local map = C_Map.GetBestMapForUnit(PLAYER)
    local position = map and C_Map.GetPlayerMapPosition(map, PLAYER)
    if not (name and position) then return end
    local x, y = position:GetXY()
    return name, map, x * PERCENT, y * PERCENT, UnitFactionGroup and UnitFactionGroup(PLAYER)
end

local function RememberSpot(itemID, name, map, x, y, side)
    if not name then return end
    local byItem = LearnedSpots()
    local sellers = byItem[itemID]
    if not sellers then sellers = {}; byItem[itemID] = sellers end
    for _, seller in ipairs(sellers) do
        if seller[SPOT_NAME] == name and seller[SPOT_MAP] == map and seller[SPOT_SIDE] == side then
            seller[SPOT_X], seller[SPOT_Y] = x, y
            return
        end
    end
    sellers[#sellers + 1] = { name, map, x, y, side }
end

local function WorldPosition(map, x, y)
    local ok, continent, position = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
    if ok and continent and position then return continent, position end
end

local function SpotDistance(spot, continent, position)
    if not (continent and position) then return math.huge end
    local spotContinent, spotPosition = WorldPosition(spot[SPOT_MAP],
        spot[SPOT_X] / PERCENT, spot[SPOT_Y] / PERCENT)
    if spotContinent ~= continent then return math.huge end
    local x1, y1 = position:GetXY()
    local x2, y2 = spotPosition:GetXY()
    return (x1 - x2) ^ 2 + (y1 - y2) ^ 2
end

local function SameSide(side, faction)
    return side == "AH" or side == faction or faction == "Alliance" and side == "A"
        or faction == "Horde" and side == "H"
end

local function NearestVendor(itemID)
    local map = C_Map.GetBestMapForUnit(PLAYER)
    local here = map and C_Map.GetPlayerMapPosition(map, PLAYER)
    local continent, position
    if here then continent, position = WorldPosition(map, here:GetXY()) end
    local side = UnitFactionGroup(PLAYER)
    local nearest, distance
    local function Consider(seller)
        if SameSide(seller[SPOT_SIDE], side) then
            local candidate = SpotDistance(seller, continent, position)
            if not nearest or candidate < distance or candidate == distance
                and seller[SPOT_NAME] < nearest[SPOT_NAME] then
                nearest, distance = seller, candidate
            end
        end
    end
    local names = P.VendorSellerNames or {}
    local spots = TownSpots()
    for _, index in ipairs((P.VendorSellers or {})[itemID] or {}) do
        for _, seller in ipairs(spots[names[index]] or {}) do Consider(seller) end
    end
    for _, seller in ipairs(LearnedSpots()[itemID] or {}) do Consider(seller) end
    return nearest
end

local function VendorWaypoint(itemID)
    local seller = NearestVendor(itemID)
    if not seller then
        ns.Print(TEXT_NO_VENDOR)
        return false
    end
    if not ns.PlaceWaypoint then return false end
    return ns.PlaceWaypoint(seller[SPOT_NAME], seller[SPOT_MAP], seller[SPOT_X], seller[SPOT_Y])
end

local function MerchantInfo(i)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local info = C_MerchantFrame.GetItemInfo(i)
        if info then return info.price, info.stackCount, info.numAvailable, info.hasExtendedCost end
        return
    end
    local _, _, price, stack, available, _, _, extended = GetMerchantItemInfo(i)
    return price, stack, available, extended
end

local function ShoppingOn()
    return S.Get("shoppingList") and S.Get("shoppingVendor")
end

local function ScanMerchant()
    local shopping = ShoppingOn()
    local learn, price = S.Get("vendorMaterials") or shopping, S.Get("craftProfit") or shopping
    if not (learn or price) then return end
    local learned, prices = LearnedVendorItems(), VendorPrices()
    local spotName, spotMap, spotX, spotY, spotSide
    if shopping then spotName, spotMap, spotX, spotY, spotSide = MerchantSpot() end
    for i = 1, GetMerchantNumItems() do
        local itemID = GetMerchantItemID(i)
        local cost, stack, available, extended = MerchantInfo(i)
        if itemID and (cost or 0) > 0 and available == UNLIMITED and not extended
            and select(CLASS_INDEX, C_Item.GetItemInfo(itemID)) == Enum.ItemClass.Tradegoods then
            if learn then learned[itemID] = true end
            if price then prices[itemID] = cost / math.max(stack or 1, 1) end
            if shopping then RememberSpot(itemID, spotName, spotMap, spotX, spotY, spotSide) end
        end
    end
end

local function StopWaiting()
    wipe(expected)
    waiting = false
    if merchant then
        for _, event in ipairs(WAIT_EVENTS) do merchant:UnregisterEvent(event) end
    end
end

local function Expect(itemID, count)
    if not expected[itemID] then counted[itemID] = R.ItemCount(itemID) end
    expected[itemID] = (expected[itemID] or 0) + count
    waiting = true
    for _, event in ipairs(WAIT_EVENTS) do merchant:RegisterEvent(event) end
end

local function Settle()
    for itemID, left in pairs(expected) do
        local now = R.ItemCount(itemID)
        local got = math.min(left, now - counted[itemID])
        if got > 0 then
            counted[itemID] = now
            expected[itemID] = left > got and left - got or nil
            P.Shopping.Bought(itemID, got)
        end
    end
    if next(expected) == nil then StopWaiting() end
end

local function OnMerchantEvent(_, event)
    if event == "BAG_UPDATE_DELAYED" then
        Settle()
        return P.Shopping.Redraw()
    end
    if event == "UI_ERROR_MESSAGE" then
        waiting = false
        merchant:UnregisterEvent(event)
        return P.ShoppingVendorView.OnMerchantEvent(event)
    end
    if event == "MERCHANT_CLOSED" then
        Settle()
        StopWaiting()
    else
        ScanMerchant()
    end
    if event ~= "MERCHANT_UPDATE" and S.Get("buyVendor") and ns.ProfWindowRefresh then ns.ProfWindowRefresh() end
    if not ShoppingOn() then return end
    P.Shopping.Redraw()
    P.ShoppingVendorView.OnMerchantEvent(event)
end

local function CraftableWithVendor(info)
    local n
    for _, r in ipairs(R.Reagents(info.recipeID)) do
        if not IsVendorItem(r.itemID) then
            local can = math.floor(R.ItemCount(r.itemID) / math.max(r.need, 1))
            n = n and math.min(n, can) or can
        end
    end
    return n
end

local function Open()
    local frame = _G.MerchantFrame
    return frame ~= nil and frame:IsShown()
end

local function Find(itemID)
    for i = 1, GetMerchantNumItems() do
        if GetMerchantItemID(i) == itemID then
            local price, stack, available, extended = MerchantInfo(i)
            if (price or 0) > 0 and not extended then
                return i, price, math.max(stack or 1, 1), available or UNLIMITED
            end
            return
        end
    end
end

local function ShoppingNeeds(onlyItem)
    local n, total = 0, 0
    for _, material in ipairs(P.Shopping.VendorMaterials()) do
        if not onlyItem or material.item == onlyItem then
            local index, price, stack, available = Find(material.item)
            if index then
                local buys = math.ceil(material.qty / stack)
                if available >= 0 then buys = math.min(buys, available) end
                if buys > 0 then
                    n = n + 1
                    local entry = shoppingPool[n] or {}
                    shoppingPool[n] = entry
                    entry.index, entry.itemID = index, material.item
                    entry.want, entry.count = material.qty, buys * stack
                    entry.cost, entry.short = buys * price, available >= 0 and buys * stack < material.qty
                    shoppingList[n] = entry
                    total = total + entry.cost
                end
            end
        end
    end
    for i = n + 1, #shoppingList do shoppingList[i] = nil end
    return shoppingList, total
end

local function BuyEntries(list, total, trackShopping)
    if #list == 0 then return false end
    if GetMoney() < total then
        ns.Print(TEXT_TOO_DEAR:format(Text.Money(total)))
        return false
    end
    if trackShopping and C_Container.CalculateTotalNumberOfFreeBagSlots() == 0 then
        ns.Print(ERR_INV_FULL)
        return false
    end
    for index, entry in ipairs(list) do
        local purchase = buyPool[index] or {}
        buyPool[index] = purchase
        purchase.index, purchase.itemID, purchase.count = entry.index, entry.itemID, entry.count
        buyList[index] = purchase
    end
    for index = #list + 1, #buyList do buyList[index] = nil end
    wipe(buyParts)
    for _, entry in ipairs(buyList) do
        local left = entry.count
        local most = math.max(1, GetMerchantItemMaxStack(entry.index) or left)
        if trackShopping then Expect(entry.itemID, entry.count) end
        while left > 0 do
            local count = math.min(left, most)
            BuyMerchantItem(entry.index, count)
            left = left - count
        end
        buyParts[#buyParts + 1] = TEXT_PART:format(entry.count, R.Link(entry.itemID))
    end
    ns.Print(TEXT_BOUGHT:format(table.concat(buyParts, ", "), Text.Money(total)))
    return true
end

local function List(recipeID, crafts, topUp)
    local out, total, owned = {}, 0, R.Owned()
    local ok, reagents = pcall(R.Reagents, recipeID)
    for _, r in ipairs(ok and reagents or {}) do
        local index, price, stack, available = Find(r.itemID)
        if index and not owned[r.itemID] then
            local want = r.need * crafts - (topUp and R.ItemCount(r.itemID) or 0)
            local buys = math.max(0, math.ceil(want / stack))
            if available >= 0 then buys = math.min(buys, available) end
            if buys > 0 then
                out[#out + 1] = { index = index, itemID = r.itemID, count = buys * stack,
                    cost = buys * price, short = available >= 0 and buys * stack < want }
                total = total + buys * price
            end
        end
    end
    return out, total
end

local function Sells(recipeID)
    return #List(recipeID, 1) > 0
end

local function Buy(recipeID, crafts, topUp)
    local list, total = List(recipeID, crafts, topUp)
    return BuyEntries(list, total)
end

local function BuyShoppingItem(itemID)
    local list, total = ShoppingNeeds(itemID)
    return BuyEntries(list, total, true)
end

local function BuyShoppingAll()
    local list, total = ShoppingNeeds()
    return BuyEntries(list, total, true)
end

local function Waiting()
    return waiting
end

P.Vendors = {
    IsVendorItem = IsVendorItem,
    Price = VendorPrice,
    CraftableWithVendor = CraftableWithVendor,
    Open = Open,
    List = List,
    Sells = Sells,
    Buy = Buy,
    ShoppingNeeds = ShoppingNeeds,
    BuyShoppingItem = BuyShoppingItem,
    BuyShoppingAll = BuyShoppingAll,
    VendorWaypoint = VendorWaypoint,
    Waiting = Waiting,
}

ns.ProfWindowAPI.IsVendorItem = IsVendorItem
ns.ProfWindowAPI.VendorPrice = VendorPrice

local function MerchantWanted()
    return P.On() and (ShoppingOn() or S.Get("vendorMaterials") or S.Get("craftProfit") or S.Get("buyVendor"))
end

local function Apply()
    if not (P.On() and ShoppingOn()) then
        StopWaiting()
        if P.ShoppingVendorView then P.ShoppingVendorView.Hide() end
    end
    if not MerchantWanted() then
        if merchant then merchant:UnregisterAllEvents() end
        return
    end
    if not merchant then
        merchant = CreateFrame("Frame")
        merchant:SetScript("OnEvent", OnMerchantEvent)
    end
    for _, event in ipairs(MERCHANT_EVENTS) do merchant:RegisterEvent(event) end
    if Open() then OnMerchantEvent(merchant, "MERCHANT_SHOW") end
end

local function OnSettingChanged(key)
    if MERCHANT_KEYS[key] then Apply() end
    if key == "shoppingVendor" then P.Shopping.Redraw() end
end

S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
Apply()

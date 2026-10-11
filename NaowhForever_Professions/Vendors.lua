-- Vendors.lua: the reagents merchants sell, what they cost there, and buying them at an open merchant.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local R = P.Recipes
local Text = P.Text

local UNLIMITED = -1
local CLASS_INDEX = 12
local TEXT_TOO_DEAR = ns.L("Buy at Vendor: that costs %s, more than you have.")
local TEXT_BOUGHT = ns.L("Bought %s for %s.")
local TEXT_PART = "%dx %s"
local MERCHANT_EVENTS = { "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED" }
local MERCHANT_KEYS = { enabled = true, vendorMaterials = true, craftProfit = true, buyVendor = true }

local merchant

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

local function MerchantInfo(i)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local info = C_MerchantFrame.GetItemInfo(i)
        if info then return info.price, info.stackCount, info.numAvailable, info.hasExtendedCost end
        return
    end
    local _, _, price, stack, available, _, _, extended = GetMerchantItemInfo(i)
    return price, stack, available, extended
end

local function ScanMerchant()
    local learn, price = S.Get("vendorMaterials"), S.Get("craftProfit")
    if not (learn or price) then return end
    local learned, prices = LearnedVendorItems(), VendorPrices()
    for i = 1, GetMerchantNumItems() do
        local itemID = GetMerchantItemID(i)
        local cost, stack, available, extended = MerchantInfo(i)
        if itemID and (cost or 0) > 0 and available == UNLIMITED and not extended
            and select(CLASS_INDEX, C_Item.GetItemInfo(itemID)) == Enum.ItemClass.Tradegoods then
            if learn then learned[itemID] = true end
            if price then prices[itemID] = cost / math.max(stack or 1, 1) end
        end
    end
end

local function OnMerchantEvent(_, event)
    if event ~= "MERCHANT_CLOSED" then ScanMerchant() end
    if event ~= "MERCHANT_UPDATE" and S.Get("buyVendor") and ns.ProfWindowRefresh then ns.ProfWindowRefresh() end
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
    if #list == 0 then return end
    if GetMoney() < total then return ns.Print(TEXT_TOO_DEAR:format(Text.Money(total))) end
    local parts = {}
    for _, e in ipairs(list) do
        local left = e.count
        local most = math.max(1, GetMerchantItemMaxStack(e.index) or left)
        while left > 0 do
            local n = math.min(left, most)
            BuyMerchantItem(e.index, n)
            left = left - n
        end
        parts[#parts + 1] = TEXT_PART:format(e.count, R.Link(e.itemID))
    end
    ns.Print(TEXT_BOUGHT:format(table.concat(parts, ", "), Text.Money(total)))
end

P.Vendors = {
    IsVendorItem = IsVendorItem,
    Prices = VendorPrices,
    CraftableWithVendor = CraftableWithVendor,
    Open = Open,
    List = List,
    Sells = Sells,
    Buy = Buy,
}

ns.ProfWindowAPI.IsVendorItem = IsVendorItem

local function MerchantWanted()
    return P.On() and (S.Get("vendorMaterials") or S.Get("craftProfit") or S.Get("buyVendor"))
end

local function Apply()
    if not MerchantWanted() then
        if merchant then merchant:UnregisterAllEvents() end
        return
    end
    if not merchant then
        merchant = CreateFrame("Frame")
        merchant:SetScript("OnEvent", OnMerchantEvent)
    end
    for _, event in ipairs(MERCHANT_EVENTS) do merchant:RegisterEvent(event) end
end

local function OnSettingChanged(key)
    if MERCHANT_KEYS[key] then Apply() end
end

S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
Apply()

-- Prices.lua: what a reagent costs to buy, and what a craft costs and fetches on the auction house.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local R = P.Recipes
local V = P.Vendors

local AH_CUT = 0.05
local FROM_VENDOR, FROM_AH = "vendor", "ah"
local DEFAULT_ROI_GREY_BELOW, DEFAULT_ROI_GREEN_FROM = 10, 30
local PERCENT = 100
local TEXT_ROI = ns.L("(%.0f%% ROI)")

local EMPTY = {}
local profitCache = {}

local function AuctionPrice(itemID)
    return ns.AuctionPrice and ns.AuctionPrice(itemID)
end

local function BuyPrice(itemID)
    local vendor = V.Price(itemID)
    local ah = AuctionPrice(itemID)
    if vendor and (not ah or vendor <= ah) then return vendor, FROM_VENDOR end
    if ah then return ah, FROM_AH end
end

local function ProfitShown()
    return S.Get("craftProfit") and ns.AuctionScanTime and ns.AuctionScanTime() ~= nil
end

local function AfterCut(each, made)
    return math.floor(each * made * (1 - AH_CUT))
end

local function CraftValue(recipeID, output, made, v)
    v.cost, v.missing, v.owned, v.output, v.made = 0, 0, 0, output, made or 1
    local ok, reagents = pcall(R.Reagents, recipeID)
    local owned, n = R.Owned(), 0
    for _, r in ipairs(ok and reagents or EMPTY) do
        local each, from = BuyPrice(r.itemID)
        local have = owned[r.itemID] == true
        n = n + 1
        local p = v.parts[n] or {}
        v.parts[n] = p
        p.itemID, p.need, p.each, p.from, p.owned = r.itemID, r.need, each, from, have
        if have then
            v.owned = v.owned + 1
        elseif each then
            v.cost = v.cost + each * r.need
        else
            v.missing = v.missing + 1
        end
    end
    for i = n + 1, #v.parts do v.parts[i] = nil end
    local each = output and AuctionPrice(output)
    v.each = each
    v.sale = each and AfterCut(each, v.made)
    return v
end

local function ReagentCost(reagents)
    local owned, cost, missing = R.Owned(), 0, 0
    for _, r in ipairs(reagents) do
        if owned[r.itemID] ~= true then
            local price = BuyPrice(r.itemID)
            if price then
                cost = cost + price * r.need
            else
                missing = missing + 1
            end
        end
    end
    return cost, missing
end

local function RecipeProfit(recipeID, output, made)
    if not (output and ProfitShown()) then return end
    local profit = profitCache[recipeID]
    if profit == nil then
        profit = false
        local each = AuctionPrice(output)
        local ok, reagents = pcall(R.Reagents, recipeID)
        if each and ok and #reagents > 0 then
            local cost, missing = ReagentCost(reagents)
            if missing == 0 then profit = AfterCut(each, made or 1) - cost end
        end
        profitCache[recipeID] = profit
    end
    return profit or nil
end

local function ROI(profit, cost)
    if type(profit) ~= "number" or type(cost) ~= "number" or cost <= 0 then return end
    return profit / cost * PERCENT
end

local function ROIThresholds()
    local grey = math.max(0, tonumber(S.Get("roiGreyBelow")) or DEFAULT_ROI_GREY_BELOW)
    local green = math.max(grey, tonumber(S.Get("roiGreenFrom")) or DEFAULT_ROI_GREEN_FROM)
    return grey, green
end

local function ROIBand(roi)
    if type(roi) ~= "number" then return end
    if roi < 0 then return "negative" end
    local grey, green = ROIThresholds()
    if roi < grey then return "muted" end
    if roi < green then return "yellow" end
    return "green"
end

local function ROIText(roi)
    if type(roi) ~= "number" then return end
    return TEXT_ROI:format(roi)
end

local function ClearCache()
    wipe(profitCache)
end

P.Prices = {
    FROM_VENDOR = FROM_VENDOR,
    BuyPrice = BuyPrice,
    ProfitShown = ProfitShown,
    CraftValue = CraftValue,
    RecipeProfit = RecipeProfit,
    ROI = ROI,
    ROIThresholds = ROIThresholds,
    ROIBand = ROIBand,
    ROIText = ROIText,
    ClearCache = ClearCache,
}

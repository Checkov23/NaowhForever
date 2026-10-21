-- Run with Lua 5.1 from the repository root: Professions crafting ROI and its colour thresholds.
local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end

local settings = { craftProfit = true, craftROI = false, roiGreyBelow = 10, roiGreenFrom = 30 }
local prices = { [10] = 100, [20] = 250 }
local vendorPrices = {}
_G.wipe = function(t) for key in pairs(t) do t[key] = nil end return t end
_G.NaowhForever = {
    L = function(text) return text end,
    AuctionScanTime = function() return 1 end,
    AuctionPrice = function(item) return prices[item] end,
    Professions = {
        Settings = { Get = function(key) return settings[key] end },
        Recipes = {
            Owned = function() return {} end,
            Reagents = function() return { { itemID = 10, need = 2 } } end,
        },
        Vendors = { Price = function(item) return vendorPrices[item] end },
    },
}
dofile("NaowhForever_Professions/Prices.lua")

local Prices = _G.NaowhForever.Professions.Prices
Check("ROI is profit divided by materials cost", Prices.ROI(25, 100) == 25)
Check("negative ROI is retained", Prices.ROI(-10, 50) == -20)
Check("zero crafting cost has no ROI", Prices.ROI(10, 0) == nil)
Check("negative ROI is red", Prices.ROIBand(-1) == "negative")
Check("ROI below 10% is grey", Prices.ROIBand(9.9) == "muted")
Check("ROI from 10% is yellow", Prices.ROIBand(10) == "yellow")
Check("ROI below 30% remains yellow", Prices.ROIBand(29.9) == "yellow")
Check("ROI from 30% is green", Prices.ROIBand(30) == "green")
Check("ROI text is rounded", Prices.ROIText(12.6) == "(13% ROI)")

settings.roiGreyBelow, settings.roiGreenFrom = 20, 50
Check("custom grey threshold is used", Prices.ROIBand(19) == "muted")
Check("custom yellow threshold is used", Prices.ROIBand(20) == "yellow")
Check("custom green threshold is used", Prices.ROIBand(50) == "green")
settings.roiGreyBelow, settings.roiGreenFrom = 40, 20
Check("green cannot fall below grey", Prices.ROIBand(40) == "green")

local price, from = Prices.BuyPrice(10)
Check("with no vendor price a reagent costs its buyout", price == 100 and from == "ah")
vendorPrices[10] = 10
price, from = Prices.BuyPrice(10)
Check("a cheaper vendor price beats the buyout", price == 10 and from == Prices.FROM_VENDOR)
vendorPrices[10] = 150
price, from = Prices.BuyPrice(10)
Check("a cheaper buyout beats the vendor price", price == 100 and from == "ah")
price, from = Prices.BuyPrice(30)
Check("a reagent with neither price has none", price == nil and from == nil)
vendorPrices[30] = 5
price, from = Prices.BuyPrice(30)
Check("a vendor price alone is used without a buyout", price == 5 and from == Prices.FROM_VENDOR)

print(("test-profession-roi: %d checks passed"):format(checks))

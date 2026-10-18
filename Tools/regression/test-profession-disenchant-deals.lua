-- Run with Lua 5.1 from the repository root: cached disenchant deals stay correct and resumable.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function Check(label, value) assert(value, label); checks = checks + 1 end
local function Near(actual, expected) return math.abs(actual - expected) < 0.001 end

local timers, requested, cached = {}, {}, {}
local skill = 30
local prices = {
    [100] = 50,
    [101] = 60,
    [102] = 100,
    [10939] = 50,
    [10940] = 10,
    [10978] = 200,
    [10998] = 20,
}
for itemID = 1000, 1090 do prices[itemID] = 55 end

local function After(_, fn) timers[#timers + 1] = fn end
local function Drain(limit)
    local count = 0
    while #timers > 0 do
        local fn = table.remove(timers, 1)
        fn()
        count = count + 1
        assert(count < (limit or 1000), "timer loop did not settle")
    end
end

local function Item(itemID)
    if itemID == 102 then return "Rare Armor", 3, 21, "INVTYPE_CHEST", 4 end
    if itemID == 101 then return "Cheap Weapon", 2, 21, "INVTYPE_WEAPON", 2 end
    if itemID == 100 or itemID >= 1000 and itemID <= 1090 then
        return "Cheap Armor " .. itemID, 2, 21, "INVTYPE_CHEST", 4
    end
end

local ns = {
    Professions = {
        Settings = { Get = function(key) return key == "disenchantDeals" end },
        Disenchant = { ENCHANTING = 333, Known = function() return true end },
    },
    AuctionPriceList = function() return prices, 123 end,
}
ns.Professions.On = function() return true end

local env = setmetatable({
    NaowhForever = ns,
    C_Timer = { After = After },
    C_TradeSkillUI = { GetProfessionInfoBySkillLineID = function() return { skillLevel = skill } end },
    C_Item = {
        GetItemInfo = function(itemID)
            local name, quality, level, equip, classID = Item(itemID)
            if not name then return end
            return name, "item:" .. itemID, quality, level, 1, nil, nil, 1, equip, 10000 + itemID, 0, classID
        end,
        GetItemInfoInstant = function(itemID)
            local _, _, _, equip, classID = Item(itemID)
            return itemID, nil, nil, equip, nil, classID
        end,
        GetDetailedItemLevelInfo = function(link) return tonumber(link:match("%d+")) and 21 end,
        IsItemDataCachedByID = function(itemID) return cached[itemID] ~= false end,
        RequestLoadItemDataByID = function(itemID) requested[itemID] = true end,
    },
    GetProfessions = function() end,
    GetProfessionInfo = function() end,
    wipe = function(t) for key in pairs(t) do t[key] = nil end return t end,
}, { __index = _G })
env._G = env

Load({ "NaowhForever_Professions/Data/DisenchantValues.lua",
    "NaowhForever_Professions/DisenchantDeals.lua" }, env)

local Values, Deals = ns.Professions.DisenchantValues, ns.Professions.DisenchantDeals
local gross, outcomes = Values.Expected(4, 2, 21, prices)
Check("armor expected value uses mutually exclusive weighted outcomes", gross == 62 and #outcomes == 3)
Check("outcomes are cached instead of allocated for each auction", Values.Outcomes(4, 2, 21) == outcomes)
Check("weapon and armor odds remain distinct", Values.Expected(2, 2, 21, prices) == 50)
Check("one possible profitable material is guaranteed", Values.Guaranteed(Values.Outcomes(4, 3, 21), prices, 100))
Check("multiple outcomes are not called guaranteed when one loses", not Values.Guaranteed(outcomes, prices, 50))
Check("skill-ups stop at 60", Values.SkillupBand(59) and not Values.SkillupBand(60))
local tooltipEntry = Deals.TooltipEntry(100)
Check("an item tooltip can calculate disenchant details without a deal-list job",
    tooltipEntry and tooltipEntry.gross == 62 and tooltipEntry.scanPrice == 50)
Check("item tooltip calculations are cached for the current manual scan", Deals.TooltipEntry(100) == tooltipEntry)

Deals.Start()
local first = Deals.Job()
Check("the search begins in bounded work", first and not first.done and #timers > 0)
local step = table.remove(timers, 1)
step()
local cursor = first.cursor
Check("a partial search saves its cursor", cursor ~= nil and not first.done)
Deals.Pause()
Deals.Start()
Drain()
local profit = Deals.Job()
Check("resume finishes the same cached job", profit == first and profit.done)
Check("profit mode ranks the highest expected gain first", profit.visible[1].item == 102)
Check("cached item data starts no load requests", next(requested) == nil)

Deals.SetGuaranteedOnly(true)
Check("the guaranteed filter keeps only risk-free expected outcomes",
    #profit.visible == 1 and profit.visible[1].item == 102)
Deals.SetGuaranteedOnly(false)
local allProfit = #profit.visible
profit.candidates[1].required = 50
Deals.SetCurrentSkillOnly(true)
Check("the current-skill filter removes profitable items this character cannot disenchant",
    #profit.visible == allProfit - 1)
skill = 50
Deals.SkillChanged()
Check("a skill change refreshes the current-skill profit filter without rebuilding",
    #profit.visible == allProfit)
Deals.SetCurrentSkillOnly(false)
skill = 30
Deals.UpdateLive(profit.byItem[102], 195)
Check("one live price update removes an unprofitable deal without rebuilding", profit.byItem[102] == nil)

Deals.SetMode(Deals.MODE_LEVEL)
Deals.Start()
Drain()
local level = Deals.Job()
Check("level mode keeps only ten visible choices", level.done and #level.visible == 10)
Check("level mode prioritizes a profitable low investment", level.visible[1].price == 50)
Check("level ROI remains mathematically consistent", Near(level.visible[1].roi,
    level.visible[1].profit / level.visible[1].price * 100))

prices = { [100] = 50, [10940] = 10, [10998] = 20, [10978] = 200 }
ns.AuctionPriceList = function() return prices, 124 end
Deals.ScanChanged()
Check("a new manual scan invalidates both mode caches", Deals.Job() == nil)

prices = { [10940] = 10, [10998] = 20, [10978] = 200 }
for itemID = 1000, 1006 do
    prices[itemID], cached[itemID] = 55, false
end
ns.AuctionPriceList = function() return prices, 125 end
Deals.ScanChanged()
Deals.SetMode(Deals.MODE_PROFIT)
Deals.Start()
assert(table.remove(timers, 1))()
local resumableProfit = Deals.Job()
Check("an uncached profit job finishes iterating before its item loads",
    resumableProfit.iterated and resumableProfit.pendingCount == 7)

Deals.SetMode(Deals.MODE_LEVEL)
Deals.Start()
assert(table.remove(timers, 2))()
local resumableLevel = Deals.Job()
Check("an uncached level job can wait alongside the profit job",
    resumableLevel.iterated and resumableLevel.pendingCount == 7)
Deals.SetMode(Deals.MODE_PROFIT)
Deals.Start()
Drain()
Check("switching back to an iterated job restarts its current-generation load pump",
    requested[1000] and requested[1006])

cached[1000] = true
Deals.ItemLoaded(1000, true)
local staleSort = assert(table.remove(timers, 1))
Deals.SetMode(Deals.MODE_LEVEL)
Deals.Start()
staleSort()
Drain()
cached[1001] = true
Deals.ItemLoaded(1001, true)
Check("a stale sort callback does not block the next mode's deferred sort", #timers > 0)
Drain()

local favoriteFile = assert(io.open("NaowhForever_Professions/UI/FavoritePatterns.lua", "rb"))
local favoriteSource = favoriteFile:read("*a"); favoriteFile:close()
Check("the first favorite purchase confirmation reflows the auction side panels",
    favoriteSource:find('c:Hide%(%)[\r\n]+%s*c:HookScript%("OnShow", PlaceShopping%)') ~= nil)
local dealsFile = assert(io.open("NaowhForever_Professions/UI/DisenchantDeals.lua", "rb"))
local dealsSource = dealsFile:read("*a"); dealsFile:close()
Check("the first deal purchase confirmation reflows the shopping list",
    dealsSource:find('confirm:Hide%(%)[\r\n]+%s*confirm:HookScript%("OnShow", QueuePlace%)') ~= nil)
Check("the deal purchase confirmation names the selected item",
    dealsSource:find("confirm.item:SetText%(ItemLabel%(entry%)%)") ~= nil)
Check("detailed deal tooltips can be limited to characters that know Enchanting",
    dealsSource:find('S.Get%("disenchantDealsTooltipEnchanters"%) and not P.Disenchant.Known%(%)') ~= nil)
Check("detailed deal tooltips can be limited to the open auction house",
    dealsSource:find('S.Get%("disenchantDealsTooltipAuctionOnly"%) and not AuctionHouseOpen%(%)') ~= nil)
Check("detailed deal tooltips use the shared item-tooltip processor instead of deal rows",
    dealsSource:find("TooltipDataProcessor.AddTooltipPostCall", 1, true) ~= nil
        and dealsSource:find("row.onTooltip = entry, entry.item, nil, nil", 1, true) ~= nil)

local settingsFile = assert(io.open("NaowhForever_Professions/UI/SettingsPage.lua", "rb"))
local settingsSource = settingsFile:read("*a"); settingsFile:close()
Check("the Enchanter-only tooltip setting depends on detailed deal tooltips",
    settingsSource:find('key = "disenchantDealsTooltipEnchanters"') ~= nil
        and settingsSource:find('needs = DisenchantDealsTooltipOn') ~= nil)
Check("the auction-only tooltip setting depends on detailed deal tooltips",
    settingsSource:find('key = "disenchantDealsTooltipAuctionOnly"') ~= nil
        and settingsSource:find('needs = DisenchantDealsTooltipOn') ~= nil)

print(("test-profession-disenchant-deals: %d checks passed"):format(checks))

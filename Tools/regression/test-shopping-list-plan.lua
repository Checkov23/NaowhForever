-- Run with Lua 5.1 from the repository root: the Shopping List's make-or-buy planning. What was
-- bought counts at every level of an item's tree, a craft taken off takes its purchases along,
-- a recipe with a cooldown is never planned, and only your own profession's recipes are
-- recorded. The module's real planning file is loaded and run, with the files it reads.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local Load = dofile("Tools/regression/load_files.lua")

-- Items: ore smelts to bars, two ore a bar; a sword takes bars. Arcanite is a transmute.
local ORE, BAR, SWORD, THORIUM, CRYSTAL, ARCANITE, FLUX = 1, 2, 3, 4, 5, 6, 7
local account, prices, vendor, own = {}, {}, {}, true
local profSettings = {}
local recipes, cooldownBase, cooldownLeft, dayCooldown = {}, {}, {}, {}
local ALCHEMY, MINING, TAILORING = 171, 186, 197
local openProf, myLines = ALCHEMY, { ALCHEMY, MINING }
local playerName = "Grim"
local playerGUID = "Player-Grim"
local function CharacterData(store, create)
    account[store] = account[store] or {}
    local mine = account[store][playerGUID]
    if mine or not create then return mine end
    mine = {}
    account[store][playerGUID] = mine
    return mine, true, false
end
local env = {
    UnitName = function() return playerName end,
    UnitGUID = function() return playerGUID end,
    GetRealmName = function() return "Realm" end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    C_Item = { GetItemNameByID = function(id) return "item" .. id end, RequestLoadItemDataByID = function() end },
    GetSpellBaseCooldown = function(id) return cooldownBase[id] or 0, 0 end,
    GetProfessions = function() local t = {} for i = 1, #myLines do t[i] = i end return unpack(t) end,
    GetProfessionInfo = function(i) return "prof", nil, 1, 300, 0, 0, myLines[i] end,
    C_TradeSkillUI = {
        GetAllRecipeIDs = function() local ids = {} for id in pairs(recipes) do ids[#ids + 1] = id end return ids end,
        GetRecipeInfo = function(id) return { learned = true } end,
        GetRecipeSchematic = function(id) return { outputItemID = recipes[id].output, quantityMin = 1 } end,
        GetRecipeCooldown = function(id) return cooldownLeft[id] or 0, dayCooldown[id] or false end,
        GetBaseProfessionInfo = function() return { professionID = openProf } end,
    },
    NaowhForever = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        Professions = { CharacterData = CharacterData,
            Settings = { Get = function(key) return profSettings[key] end } },
        AccountSettings = function() return account end,
        AuctionPrice = function(item) return prices[item] end,
        Print = function() end,
        ProfWindowAPI = {
            Owned = function() return {} end,
            IsVendorItem = function(item) return vendor[item] or false end,
            Own = function() return own end,
            Reagents = function(id)
                local out = {}
                for item, per in pairs(recipes[id].need) do out[#out + 1] = { itemID = item, need = per } end
                return out
            end,
        },
    },
}
env._G = env
Load({ "NaowhForever_Professions/Constants.lua", "NaowhForever_Professions/Text.lua",
    "NaowhForever_Professions/Data/CooldownRecipes.lua", "NaowhForever_Professions/ShoppingPlan.lua" },
    setmetatable(env, { __index = _G }))
local SL = env.NaowhForever.Professions.Shopping

local function Reset()
    for k in pairs(account) do account[k] = nil end
    for k in pairs(prices) do prices[k] = nil end
    prices[ORE], prices[BAR], prices[SWORD] = 10, 100, 5000
    own = true
end
local function Learned(makes)
    local m = SL.Makes()
    for k in pairs(m) do m[k] = nil end
    for item, v in pairs(makes) do m[item] = v end
end
local SMELT = { recipe = 100, made = 1, need = { [ORE] = 2 } }
local function Craft(id, need, count) SL.List()[id] = { name = "c" .. id, count = count or 1, need = need } end
-- itemID -> qty to buy, and itemID -> qty made first.
local function Plan()
    local materials, made, _, vendorMaterials = SL.Materials()
    local buy, vendorBuy = {}, {}
    for _, m in ipairs(materials) do buy[m.item] = m.qty end
    for _, m in ipairs(vendorMaterials) do vendorBuy[m.item] = m.qty end
    return buy, made, vendorBuy
end
local function Only(t, item, qty)
    for k, v in pairs(t) do if k ~= item or v ~= qty then return false end end
    return t[item] == qty
end
local function Empty(t) return next(t) == nil end

Craft(9, { [ORE] = 1 })
playerName, playerGUID = "Alt", "Player-Alt"
check("another character starts with an empty Shopping List", Empty(SL.List()))
Craft(8, { [BAR] = 1 })
check("the second character has an independent Shopping List", SL.List()[8] and not SL.List()[9])
playerName, playerGUID = "Grim", "Player-Grim"
check("switching back restores the first character's Shopping List", SL.List()[9] and not SL.List()[8])
SL.Clear()

-- Making is cheaper: the ore is bought, the bars made first.
Reset(); Learned({ [BAR] = SMELT }); Craft(10, { [BAR] = 20 })
local buy, made = Plan()
check("cheaper to make: 40 ore bought", Only(buy, ORE, 40))
check("cheaper to make: 20 bars made first", Only(made, BAR, 20))

-- The ore is bought, then Buy is clicked on the bars: the ore still counts.
SL.Drop(ORE, 40)
SL.Keep()[BAR] = true
buy, made = Plan()
check("ore bought, bars then kept to buy: nothing left to buy", Empty(buy))
check("ore bought, bars then kept to buy: the bars are still made from it", Only(made, BAR, 20))

-- A new scan makes the bars cheaper to buy: the ore bought still counts.
SL.Keep()[BAR] = nil
prices[BAR] = 15
buy, made = Plan()
check("bars now cheaper to buy: nothing left to buy", Empty(buy))
check("bars now cheaper to buy: still made from the ore bought", Only(made, BAR, 20))

-- Part of the ore: what it makes is made, the rest of the bars bought.
Reset(); Learned({ [BAR] = SMELT }); Craft(10, { [BAR] = 20 })
prices[BAR] = 15
SL.Drop(ORE, 10)
buy, made = Plan()
check("10 ore bought, bars cheaper to buy: 15 bars bought", Only(buy, BAR, 15))
check("10 ore bought, bars cheaper to buy: 5 bars made from it", Only(made, BAR, 5))

-- Bars bought while kept, then Make clicked: the bars count, no ore is bought.
Reset(); Learned({ [BAR] = SMELT }); Craft(10, { [BAR] = 20 })
SL.Drop(BAR, 20)
buy, made = Plan()
check("bars bought, then made instead: nothing to buy", Empty(buy) and Empty(made))

-- A recipe whose parts are all from a vendor is never made out of nothing.
Reset(); Learned({ [BAR] = { recipe = 101, made = 1, need = { [FLUX] = 1 } } }); Craft(10, { [BAR] = 3 })
vendor[FLUX] = true; prices[BAR] = 1
buy = Plan()
check("vendor parts only: the bars are bought", Only(buy, BAR, 3))
vendor[FLUX] = nil

-- Vendor Items on Shopping List off (the default): vendor reagents stay off the list, as before.
Reset(); Learned({}); vendor[FLUX] = true
account.profVendorPrices = { [FLUX] = 40 }
recipes[10] = { need = { [FLUX] = 1 } }
check("off: a recipe with only vendor materials has nothing to add", not SL.HasNeeds(10))
recipes[10] = { need = { [FLUX] = 1, [ORE] = 2 } }
check("off: only the reagents vendors do not sell are added",
    SL.Add({ recipeID = 10, name = "c10" }, 1, nil, true) and SL.List()[10].need[FLUX] == nil)
local auctionBuy, _, vendorBuy = Plan()
check("off: nothing goes to Buy from Vendor", Only(auctionBuy, ORE, 2) and Empty(vendorBuy))
SL.Bought(ORE, 2)
check("off: buying the last auction material clears the list", Empty(SL.List()))
SL.AddItem(FLUX, 2)
auctionBuy, _, vendorBuy = Plan()
check("off: a manually added vendor item stays with the auction house",
    Only(auctionBuy, FLUX, 2) and Empty(vendorBuy))
SL.Clear()
profSettings.shoppingVendor = true

-- Vendor materials stay out of the AH run unless a known AH price is strictly cheaper.
Reset(); Learned({}); vendor[FLUX] = true; prices[FLUX] = 100
account.profVendorPrices = { [FLUX] = 40 }
Craft(10, { [FLUX] = 3 })
auctionBuy, _, vendorBuy = Plan()
check("vendor cheaper: material is routed to the vendor", Empty(auctionBuy) and Only(vendorBuy, FLUX, 3))
prices[FLUX] = 30
auctionBuy, _, vendorBuy = Plan()
check("AH cheaper: material is routed to the auction house", Only(auctionBuy, FLUX, 3) and Empty(vendorBuy))
prices[FLUX] = 40
auctionBuy, _, vendorBuy = Plan()
check("equal prices: material stays with the vendor", Empty(auctionBuy) and Only(vendorBuy, FLUX, 3))
account.profVendorPrices = nil
auctionBuy, _, vendorBuy = Plan()
check("unknown vendor price: material stays with the vendor", Empty(auctionBuy) and Only(vendorBuy, FLUX, 3))
recipes[10] = { need = { [FLUX] = 1 } }
check("a recipe with only vendor materials can be added", SL.HasNeeds(10))
SL.Clear(); SL.AddItem(FLUX, 2)
auctionBuy, _, vendorBuy = Plan()
check("a manually added vendor item uses the same routing", Empty(auctionBuy) and Only(vendorBuy, FLUX, 2))

Reset(); Learned({}); vendor[FLUX] = true; prices[ORE] = 10
account.profVendorPrices = { [FLUX] = 5 }
Craft(20, { [ORE] = 2, [FLUX] = 1 })
SL.Bought(ORE, 2)
auctionBuy, _, vendorBuy = Plan()
check("buying the last AH material keeps vendor work on the list",
    SL.List()[20] ~= nil and Empty(auctionBuy) and Only(vendorBuy, FLUX, 1))
SL.Bought(FLUX, 1)
check("buying the final vendor material clears the completed list", Empty(SL.List()) and Empty(SL.Have()))
vendor[FLUX] = nil
profSettings.shoppingVendor = nil

-- A craft taken off takes its purchases along (the reviewer's case).
Reset(); Learned({}); Craft(10, { [ORE] = 20 }); Craft(11, { [THORIUM] = 5 })
SL.Drop(ORE, 20)
SL.List()[10] = nil
SL.Trim()
check("craft taken off: its ore is no longer counted", SL.Have()[ORE] == nil)
Craft(12, { [ORE] = 20 })
buy = Plan()
check("a later craft needing ore buys it", buy[ORE] == 20)

-- What the crafts left can use is kept.
Reset(); Learned({ [BAR] = SMELT }); Craft(10, { [ORE] = 20 }); Craft(11, { [BAR] = 5 })
SL.Drop(ORE, 30)
SL.List()[10] = nil
SL.Trim()
check("the craft left keeps the ore it can use, through its bars", SL.Have()[ORE] == 10)
SL.List()[11] = nil
SL.Trim()
check("an empty list keeps nothing", Empty(SL.Have()))

-- A recipe with a cooldown is never planned, however much cheaper.
Reset()
prices[THORIUM], prices[CRYSTAL], prices[ARCANITE] = 1, 1, 10000
Learned({ [ARCANITE] = { recipe = 17187, made = 1, need = { [THORIUM] = 1, [CRYSTAL] = 1 }, cooldown = true } })
Craft(10, { [ARCANITE] = 10 })
buy, made = Plan()
check("cooldown recipe: the arcanite is bought", Only(buy, ARCANITE, 10) and Empty(made))
SL.Drop(THORIUM, 10); SL.Drop(CRYSTAL, 10)
buy, made = Plan()
check("cooldown recipe: not even from parts bought", Only(buy, ARCANITE, 10) and Empty(made))

-- Whole crafts against what is needed (the reviewer's Bronze Bars): 50s a bar bought, 80s of
-- parts for a craft of 2. 3 bars: 2 crafts are 160s, buying is 150s. 4 bars: 160s against 200s.
Reset()
prices[BAR], prices[ORE] = 5000, 2000
Learned({ [BAR] = { recipe = 2659, made = 2, need = { [ORE] = 4 } } })
Craft(10, { [BAR] = 3 })
buy, made = Plan()
check("3 bars: buying them is cheaper than 2 whole crafts", Only(buy, BAR, 3) and Empty(made))
SL.List()[10] = nil; Craft(10, { [BAR] = 4 })
local materials, made4, plan = SL.Materials()
check("4 bars: 2 crafts made", Only(made4, BAR, 4) and materials[1].item == ORE and materials[1].qty == 8)
check("and it saves 40s, not per bar", plan.saves[BAR] == 4000 and plan.planned[BAR])

-- Learn: only your own profession, and what has a cooldown.
Reset(); Learned({})
for k in pairs(recipes) do recipes[k] = nil end
recipes[100] = { output = BAR, need = { [ORE] = 2 } }
recipes[17187] = { output = ARCANITE, need = { [THORIUM] = 1, [CRYSTAL] = 1 } }
recipes[99001] = { output = CRYSTAL, need = { [ORE] = 1 } }
recipes[99002] = { output = FLUX, need = { [ORE] = 3 } }
recipes[99003] = { output = SWORD, need = { [BAR] = 3 } }
own = false
SL.Learn()
check("another player's profession is not recorded", Empty(SL.Makes()))
own = true
cooldownLeft[99001] = 3600
dayCooldown[99002] = true
SL.Learn()
local makes = SL.Makes()
check("your own profession is recorded", makes[BAR] and makes[BAR].need[ORE] == 2 and not makes[BAR].cooldown)
check("Transmute: Arcanite is a cooldown recipe, though its spell reads 0", makes[ARCANITE].cooldown)
check("a cooldown running now marks the recipe", makes[CRYSTAL].cooldown)
check("a day cooldown marks the recipe", makes[FLUX].cooldown)
check("one without is not marked", not makes[SWORD].cooldown)
cooldownLeft[99001] = nil
SL.Learn()
check("a cooldown seen once is remembered when it is ready again", SL.Makes()[CRYSTAL].cooldown)

-- Recipes of a profession are forgotten once no longer known, or the profession is dropped.
recipes[99003] = nil
SL.Learn()
check("a recipe no longer known is forgotten", SL.Makes()[SWORD] == nil and SL.Makes()[BAR] ~= nil)
local tailoring = { recipe = 18560, made = 1, need = { [ORE] = 1 }, prof = TAILORING }
SL.Makes()[ARCANITE + 100] = tailoring
SL.Learn()
check("a profession you no longer have is forgotten", SL.Makes()[ARCANITE + 100] == nil)
SL.Makes()[ARCANITE + 100] = tailoring
SL.Makes()[ARCANITE + 101] = { recipe = 1, made = 1, need = { [ORE] = 1 } }
openProf = 999
SL.Learn()
check("not when the open profession's id is not among yours (ids that do not match)",
    SL.Makes()[ARCANITE + 100] ~= nil)
check("a recipe recorded before professions were kept stays", SL.Makes()[ARCANITE + 101] ~= nil)
openProf = ALCHEMY

-- Other items: always bought as they are, merged with a craft's need, kept when bought.
Reset(); Learned({ [BAR] = SMELT })
SL.AddItem(BAR, 5)
local buy2, made2 = Plan()
check("an item with a recipe is bought, not made", Only(buy2, BAR, 5) and Empty(made2))
SL.AddItem(BAR, 3)
buy2 = Plan()
check("adding it again adds to the amount", Only(buy2, BAR, 8))
SL.StepItem(BAR, -1)
buy2 = Plan()
check("one fewer takes one off", Only(buy2, BAR, 7))
SL.Drop(BAR, 7)
buy2 = Plan()
check("bought items are not asked for again", Empty(buy2))
SL.Trim()
check("and the purchase is kept", SL.Have()[BAR] == 7)
SL.RemoveItem(BAR)
check("removing an item drops its purchase", SL.Manual()[BAR] == nil and SL.Have()[BAR] == nil)
Reset(); Learned({ [BAR] = SMELT }); Craft(10, { [BAR] = 20 })
prices[BAR] = 15
SL.AddItem(ORE, 4)
buy2 = Plan()
check("another item joins a craft's materials", buy2[ORE] == 4 and buy2[BAR] == 20)
SL.Clear()
check("Clear empties the items too", next(SL.Manual()) == nil and next(SL.List()) == nil)
SL.AddItem(ORE, 100000)
check("an amount is capped", SL.Manual()[ORE] == env.NaowhForever.Professions.C.MAX_ITEMS)
local queueClears = 0
env.NaowhForever.Professions.Settings = { Get = function(key) return key == "craftQueue" end }
env.NaowhForever.Professions.CraftQueue = { Clear = function() queueClears = queueClears + 1 end }
SL.Clear()
check("Clear also empties the enabled Crafting Queue", queueClears == 1)

local queueRemoved
env.NaowhForever.Professions.CraftQueue.RemoveCraft = function(id) queueRemoved = id end
SL.List()[20] = { name = "c20", count = 3, need = { [ORE] = 1 }, queueCount = 2, fromQueue = false }
SL.Step(20, 1)
check("+ on a mixed row raises your own count and keeps the queue part",
    SL.List()[20].count == 4 and SL.List()[20].queueCount == 2)
SL.Step(20, -1)
SL.Step(20, -1)
check("- on a mixed row can take your own count to zero", SL.List()[20].count == 2 and SL.List()[20].fromQueue)
SL.Step(20, -1)
check("- never cuts into the queue part", SL.List()[20].count == 2 and SL.List()[20].queueCount == 2)
SL.Step(20, 1)
check("+ on a queue-only row adds your own craft", SL.List()[20].count == 3 and not SL.List()[20].fromQueue)
SL.Remove(20)
check("X takes the whole row off and hands its queue part to the queue",
    SL.List()[20] == nil and queueRemoved == 20)
queueRemoved = nil
SL.List()[21] = { name = "c21", count = 1, need = { [ORE] = 1 } }
SL.Step(21, -1)
SL.Remove(21)
check("rows without a queue part keep their old floor and never touch the queue",
    SL.List()[21] == nil and queueRemoved == nil)

print(("test-shopping-list-plan: %d checks passed"):format(checks))

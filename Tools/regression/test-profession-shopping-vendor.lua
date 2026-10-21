-- Shopping List vendor regression: merchant bundles, limited stock, click-driven buys, and purchases
-- counted only once they land in the bags (refused ones never), with Buy at Vendor left as it was.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local settings, applyHooks = {}, {}
local merchantShown = false
local purchases, messages, drops = {}, {}, {}
local bags, freeSlots = {}, 10
local redraws, viewEvents = 0, 0
local vendorName, vendorMap, vendorX, vendorY = "Far Supplies", 10, 0.8, 0.8
local playerMap, playerX, playerY = 10, 0.1, 0.1
local playerFaction = "Alliance"
local waypoint
local registry = {}
local merchantItems = {
    { item = 111, price = 200, stack = 5, available = -1 },
    { item = 222, price = 100, stack = 5, available = 1 },
}
local materials = {
    { item = 111, qty = 7 },
    { item = 222, qty = 7 },
    { item = 333, qty = 4 },
}

local function Noop() end
local function Vector(x, y)
    return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end
local frameMethods = {}
function frameMethods.RegisterEvent(frame, event) registry[event] = frame end
function frameMethods.UnregisterEvent(frame, event)
    if registry[event] == frame then registry[event] = nil end
end
function frameMethods.UnregisterAllEvents(frame)
    for event, f in pairs(registry) do
        if f == frame then registry[event] = nil end
    end
end
function frameMethods.SetScript(frame, name, fn) frame.scripts[name] = fn end
local frameMeta = { __index = function(_, key) return frameMethods[key] or Noop end }

local function Fire(event)
    local frame = registry[event]
    if frame then frame.scripts.OnEvent(frame, event) end
end

local ns = {
    L = dofile("Tools/regression/locale_stub.lua").L,
    Upper = string.upper,
    Lower = string.lower,
    UI = {
        ModuleSettings = function(_, defaults)
            local store, listeners = {}, {}
            function store.Get(key)
                if settings[key] == nil then return defaults[key] end
                return settings[key]
            end
            function store.Set(key, value)
                settings[key] = value
                for index = 1, #listeners do listeners[index](key, value) end
            end
            function store.OnChange(fn) listeners[#listeners + 1] = fn end
            return store
        end,
    },
    ProfWindowAPI = {},
    AccountSettings = function() return settings.account end,
    Print = function(message) messages[#messages + 1] = message end,
    PlaceWaypoint = function(name, map, x, y)
        waypoint = { name = name, map = map, x = x, y = y }
        return true
    end,
    TownNPCs = {
        [10] = {
            { 30, 30, "trade", "Catalog Supplies", "Trade Supplies", nil, "A" },
            { 5, 5, "trade", "Horde Catalog", "Trade Supplies", nil, "H" },
        },
    },
}
settings.account = {}

local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function() return setmetatable({ scripts = {} }, frameMeta) end,
    hooksecurefunc = function(target, name, fn)
        if target == ns and name == "Apply" then applyHooks[#applyHooks + 1] = fn end
    end,
    wipe = function(list) for key in pairs(list) do list[key] = nil end end,
    C_MerchantFrame = {
        GetItemInfo = function(index)
            local item = merchantItems[index]
            return item and { price = item.price, stackCount = item.stack,
                numAvailable = item.available, hasExtendedCost = false }
        end,
    },
    C_Item = {
        GetItemInfo = function()
            return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 7
        end,
    },
    C_Container = { CalculateTotalNumberOfFreeBagSlots = function() return freeSlots end },
    C_Map = {
        GetBestMapForUnit = function(unit) return unit == "player" and playerMap end,
        GetPlayerMapPosition = function(map, unit)
            if unit == "npc" then return end
            if map == vendorMap and unit == "player" and merchantShown then return Vector(vendorX, vendorY) end
            if map == playerMap and unit == "player" then return Vector(playerX, playerY) end
        end,
        GetWorldPosFromMapPos = function(map, position) return map, position end,
    },
    CreateVector2D = Vector,
    ERR_INV_FULL = "Inventory is full.",
    Enum = { ItemClass = { Tradegoods = 7 } },
    MerchantFrame = { IsShown = function() return merchantShown end },
    UnitName = function(unit) return unit == "npc" and vendorName or "Player" end,
    UnitFactionGroup = function() return playerFaction end,
    issecretvalue = function() return false end,
    GetMerchantNumItems = function() return #merchantItems end,
    GetMerchantItemID = function(index) return merchantItems[index] and merchantItems[index].item end,
    GetMerchantItemMaxStack = function(index) return merchantItems[index].stack end,
    GetMoney = function() return 10000 end,
    BuyMerchantItem = function(index, count)
        purchases[#purchases + 1] = { index = index, count = count }
    end,
}, { __index = _G })
env._G = env

Load({ "Core/Features.lua", "NaowhForever_Professions/Professions.lua" }, env)
local P = ns.Professions
P.VendorSellerNames = { "Catalog Supplies", "Horde Catalog" }
P.VendorSellers = { [333] = { 1, 2 } }
P.Recipes = {
    Link = function(itemID) return "item:" .. itemID end,
    Owned = function() return {} end,
    Reagents = function() return { { itemID = 111, need = 5 } } end,
    ItemCount = function(itemID) return bags[itemID] or 0 end,
}
P.Text = { Money = tostring }
P.Shopping = {
    VendorMaterials = function() return materials end,
    Bought = function(itemID, count)
        drops[itemID] = (drops[itemID] or 0) + count
    end,
    Redraw = function() redraws = redraws + 1 end,
}
P.ShoppingVendorView = { Hide = Noop, OnMerchantEvent = function() viewEvents = viewEvents + 1 end }
Load({ "NaowhForever_Professions/Vendors.lua" }, env)
local V = P.Vendors

P.VendorPrices = { [111] = 99, [333] = 7 }
check("a built-in vendor price is known before any merchant visit", V.Price(333) == 7)
check("the Shopping List reads the same vendor price", ns.ProfWindowAPI.VendorPrice == V.Price)
check("an item with no built-in or seen price has none", V.Price(444) == nil)

check("a built-in vendor waypoint works before any merchant visit", V.VendorWaypoint(333) == true
    and waypoint.name == "Catalog Supplies" and waypoint.map == 10 and waypoint.x == 30 and waypoint.y == 30)
check("a built-in vendor waypoint ignores the other faction even when it is nearer",
    waypoint.name ~= "Horde Catalog")

local list, total = V.ShoppingNeeds()
check("only Shopping List materials sold by this merchant are listed", #list == 2)
check("unlimited stock rounds seven items to two five-item bundles",
    list[1].itemID == 111 and list[1].want == 7 and list[1].count == 10 and list[1].cost == 400)
check("limited stock marks the unmet remainder",
    list[2].itemID == 222 and list[2].count == 5 and list[2].short == true)
check("the total uses whole merchant purchases", total == 500)
check("listing materials never buys anything", #purchases == 0)

merchantShown = true
P.Settings.Set("shoppingList", true)
check("Shopping List alone learns nothing at a merchant", settings.account.profVendorItems == nil)
P.Settings.Set("shoppingVendor", true)
check("Vendor Items on Shopping List learns vendor trade goods", settings.account.profVendorItems[111] == true)
check("and records the vendor unit price", settings.account.profVendorPrices[111] == 40)
check("a price seen at a merchant wins over the built-in one", V.Price(111) == 40)
check("and remembers which merchant sold each item",
    settings.account.profVendorSpots[111][1][1] == "Far Supplies")

vendorName, vendorX, vendorY = "Near Supplies", 0.2, 0.2
Fire("MERCHANT_SHOW")
check("seeing another seller keeps both locations", #settings.account.profVendorSpots[111] == 2)
playerFaction, vendorName, vendorX, vendorY = "Horde", "Horde Supplies", 0.1, 0.1
Fire("MERCHANT_SHOW")
check("a merchant visit remembers the visiting faction", settings.account.profVendorSpots[111][3][5] == "Horde")
merchantShown = false
playerFaction = "Alliance"
check("a vendor waypoint picks the nearest learned seller", V.VendorWaypoint(111) == true
    and waypoint.name == "Near Supplies" and waypoint.map == 10 and waypoint.x == 20 and waypoint.y == 20)
check("a vendor waypoint ignores sellers learned by the other faction", waypoint.name ~= "Horde Supplies")
playerX, playerY = 0.9, 0.9
check("the same item can route to a different seller from another position", V.VendorWaypoint(111) == true
    and waypoint.name == "Far Supplies")
check("an item with no known seller does not guess a location", V.VendorWaypoint(444) == false)
check("and explains how to teach it a vendor", messages[#messages]:find("Visit a vendor", 1, true) ~= nil)
messages = {}
merchantShown = true

check("buying one shortage succeeds", V.BuyShoppingItem(111) == true)
check("a click buys the rounded item count in merchant-sized chunks",
    #purchases == 2 and purchases[1].count == 5 and purchases[2].count == 5)
check("the purchase reports what was bought", #messages == 1)
check("nothing is counted before it lands", drops[111] == nil)
check("Buy waits for the purchase", V.Waiting() and registry.BAG_UPDATE_DELAYED ~= nil)
Fire("BAG_UPDATE_DELAYED")
check("a bag update without the item counts nothing and keeps waiting", drops[111] == nil and V.Waiting())
bags[111] = 10
redraws = 0
Fire("BAG_UPDATE_DELAYED")
check("once it lands, the Shopping List records the bundle", drops[111] == 10 and redraws == 1)
check("and stops waiting and listening to bags", not V.Waiting() and registry.BAG_UPDATE_DELAYED == nil)
bags[111] = 20
Fire("BAG_UPDATE_DELAYED")
check("later bag changes are not purchases", drops[111] == 10)

drops[111], drops[222] = nil, nil
check("Buy All succeeds", V.BuyShoppingAll() == true)
bags[111] = 30
Fire("BAG_UPDATE_DELAYED")
check("each item counts as it lands", drops[111] == 10 and drops[222] == nil and V.Waiting())
bags[222] = 5
Fire("BAG_UPDATE_DELAYED")
check("and Buy All is done when the last one lands", drops[222] == 5 and not V.Waiting())

drops[111] = nil
check("a purchase the merchant refuses is still asked for", V.BuyShoppingItem(111) == true)
viewEvents = 0
Fire("UI_ERROR_MESSAGE")
check("an error stops the wait so Buy can be clicked again", not V.Waiting() and viewEvents == 1)
Fire("BAG_UPDATE_DELAYED")
check("a refused purchase is never counted", drops[111] == nil)
bags[111] = 40
Fire("BAG_UPDATE_DELAYED")
check("but one that lands after the error still counts", drops[111] == 10)

drops[111] = nil
V.BuyShoppingItem(111)
merchantShown = false
Fire("MERCHANT_CLOSED")
check("closing the merchant stops waiting", not V.Waiting() and registry.BAG_UPDATE_DELAYED == nil)
bags[111] = 50
Fire("BAG_UPDATE_DELAYED")
check("and nothing lands on the list after it", drops[111] == nil)
merchantShown = true

local bought = #purchases
freeSlots = 0
messages = {}
check("with full bags nothing is bought", V.BuyShoppingItem(111) == false and #purchases == bought)
check("and the game's full-bags message is shown", messages[1] == env.ERR_INV_FULL and not V.Waiting())

check("Buy at Vendor still buys with full bags, as before", V.Buy(1, 2) == true and #purchases == bought + 2)
check("and never counts on the Shopping List", drops[111] == nil and not V.Waiting())
freeSlots = 10

V.BuyShoppingItem(111)
P.Settings.Set("shoppingVendor", false)
check("turning the setting off drops a pending purchase", not V.Waiting() and registry.BAG_UPDATE_DELAYED == nil)

local file = assert(io.open("NaowhForever_Professions/UI/ShoppingWindow.lua", "rb"))
local source = file:read("*a")
file:close()
check("vendor rows build their pin from the shared icon button", source:find("Parts.IconButton", 1, true) ~= nil)
check("the vendor-row pin calls the vendor waypoint model", source:find("V.VendorWaypoint", 1, true) ~= nil)

print(("test-profession-shopping-vendor: %d checks passed"):format(checks))

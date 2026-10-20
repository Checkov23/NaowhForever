-- SettingsPage.lua: the Professions settings page (Professions/Settings), declared as cards.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local Settings = ns.Shared.Settings
local Group = Settings.Group

local RECIPE_KEYS = { "recipeFinder", "rankAlert", "bagReagents", "bankReagents", "trainFavorites", "skillThresholds" }
local GATHER_LIFT = 8
local GATHER_STAGE_H = 130
local CRAFT_STAGE_H = 100
local TIP_RANGE, ICON_RANGE, TEXT_RANGE = { 0, 50, 1 }, { 24, 80, 1 }, ns.Shared.Style.HUD_TEXT_RANGE
local ROI_RANGE = { 0, 100, 1 }
local ORDER_RECIPES, ORDER_ORDERS, ORDER_CRAFT_TIMER, ORDER_BUYING, ORDER_GATHER = 10, 20, 30, 40, 50
local ORDER_DISENCHANT, ORDER_DISENCHANT_DEALS = 60, 70
local SAMPLE_ICON = "Interface\\Icons\\INV_Ingot_02"
local SAMPLE_NAME, SAMPLE_DONE, SAMPLE_COUNT = ns.L("Smelt Copper"), 4, 10
local SAMPLE_SHARE, SAMPLE_LEFT = 0.4, 15
local TEXT_OFF = ns.L("Turn on Professions")
local TEXT_SAMPLE_TRACK = ns.L("Track Herbs / Minerals")
local TEXT_NONE = ns.L("No professions learned yet")
local TEXT_PROFESSION = "%s %d/%d"
local TEXT_DETAIL_OFF = ns.L("Turn on Professions to use Naowh's recipe window in place of the game's.")
local TEXT_DETAIL_ON = ns.L("Open a profession from your spellbook: Naowh's recipe window takes the place of the game's.")
local TEXT_DETAIL_PAD = ns.L("With the Gamepad interface style, the game's own recipe window is used.")
local TEXT_RECIPE_SUMMARY = ns.L("%d of %d on")
local TEXT_ORDERS_SUMMARY = ns.L("Suggested tip %d%% of value")
local TEXT_NO_BUYING = ns.L("No prices or buying")
local TEXT_PROFIT, TEXT_NO_PROFIT = ns.L("Profit"), ns.L("No profit")
local TEXT_BUYS_AH, TEXT_BUYS_VENDOR = ns.L(", buys on the AH"), ns.L(", buys at vendors")
local TEXT_GATHER_SUMMARY = ns.L("%d px icon%s")
local TEXT_IN_INSTANCES = ns.L(", in instances too")
local GATHER_STATES = {
    { key = "untracked", label = "Not Tracking", tip = "What shows while you know a find but track none." },
}
local CRAFT_STATES = {
    { key = "crafting", label = "Crafting", tip = "A batch of ten, four done, as it shows while you craft." },
}

local function On()
    return S.Get("enabled") == true
end

local function PadFree()
    return On() and not ns.GamepadStandDown()
end

local function PadWhy()
    return ns.GamepadWhy() or TEXT_OFF
end

local function ProfitOn()
    return On() and S.Get("craftProfit") == true
end

local function ROIOn()
    return ProfitOn() and S.Get("craftROI") == true
end

local function FavoriteSearchOn()
    return On() and S.Get("searchFavoritesAH") == true
end

local function ShoppingOn()
    return On() and S.Get("shoppingList") == true
end

local function DisenchantDealsOn()
    return On() and S.Get("disenchantDeals") == true
end

local function DisenchantDealsTooltipOn()
    return DisenchantDealsOn() and S.Get("disenchantDealsTooltip") == true
end

local function ProfessionLine(index)
    if not index then return nil end
    local name, _, rank, maxRank = GetProfessionInfo(index)
    return name and TEXT_PROFESSION:format(name, rank or 0, maxRank or 0)
end

local function Headline()
    local prof1, prof2 = GetProfessions()
    local a, b = ProfessionLine(prof1), ProfessionLine(prof2)
    if a and b then return a .. ",  " .. b end
    return a or b or TEXT_NONE
end

local function Detail()
    if not On() then return TEXT_DETAIL_OFF end
    if ns.GamepadStandDown() then return TEXT_DETAIL_PAD end
    return TEXT_DETAIL_ON
end

local function RecipeSummary(store)
    local n = 0
    for _, key in ipairs(RECIPE_KEYS) do
        if store.Get(key) then n = n + 1 end
    end
    return TEXT_RECIPE_SUMMARY:format(n, #RECIPE_KEYS)
end

local function OrdersSummary(store)
    return TEXT_ORDERS_SUMMARY:format(store.Get("orderTip"))
end

local function BuyingSummary(store)
    local profit, ah, vendor = store.Get("craftProfit"), store.Get("buyMaterials"), store.Get("buyVendor")
    if not (profit or ah or vendor) then return TEXT_NO_BUYING end
    return (profit and TEXT_PROFIT or TEXT_NO_PROFIT) .. (ah and TEXT_BUYS_AH or "") .. (vendor and TEXT_BUYS_VENDOR or "")
end

local function GatherSummary(store)
    return TEXT_GATHER_SUMMARY:format(store.Get("gatherIconSize"), store.Get("gatherInInstances") and TEXT_IN_INSTANCES or "")
end

local function NewGatherPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetPoint("CENTER", 0, GATHER_LIFT)
    P.GatherLook.New(preview)
    return preview
end

local function PaintGatherPreview(preview)
    local Look = P.GatherLook
    Look.Fill(preview, S.Get("gatherIconSize"), C_Spell.GetSpellTexture(Look.FIND_HERBS), TEXT_SAMPLE_TRACK)
end

local function NewCraftPreview(stage)
    local preview = P.CraftTimerLook.New(stage)
    preview:SetPoint("CENTER")
    return preview
end

local function PaintCraftPreview(preview)
    local Look = P.CraftTimerLook
    Look.Style(preview)
    Look.Fill(preview, SAMPLE_ICON, SAMPLE_NAME, SAMPLE_DONE, SAMPLE_COUNT)
    Look.Progress(preview, SAMPLE_SHARE, SAMPLE_LEFT)
end

local page = Settings.Page("Professions/Settings", S)

page:Window({
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "recipeWindow", name = "Recipe Window", order = ORDER_RECIPES, switchWhy = ns.GamepadWhy,
    help = "What Naowh's profession window adds to each recipe: the ones you have not learned yet, your next "
        .. "rank, and how many of each reagent you have.",
    search = "filter favorites favourites have materials skill-up skill up profitable boe bop bind on equip pickup "
        .. "star right-click right click track recipe create all bags full chat link shift ctrl click",
    summary = RecipeSummary,
    rows = {
        { key = "skillThresholds", label = "Skill-up Thresholds", toggle = true, needs = On, why = TEXT_OFF,
          help = "Shows when the selected recipe turns yellow, green and grey beneath its name." },
        { key = "recipeFinder", label = "Unlearned Recipes", toggle = true, needs = On, why = TEXT_OFF,
          help = "Lists the recipes you have not learned yet below your own. Click one to see the skill it "
              .. "needs, what it costs and where it comes from: the nearest trainers, the vendor selling its "
              .. "manual, or the mobs that drop it. Click a trainer or vendor to set a waypoint." },
        { key = "rankAlert", label = "Next Rank Alert", toggle = true, needs = On, why = TEXT_OFF,
          help = "When a profession's skill is high enough for its next rank (Journeyman, Expert, Artisan), a "
              .. "banner under the skill bar and on its card in the overview says what it takes and who "
              .. "teaches it: the nearest trainer, book vendor or quest giver. Click Waypoint to mark them on "
              .. "your map. Reaching it also says so once in chat; /naowh profrank repeats that." },
        { key = "bagReagents", label = "Reagents in Bags", toggle = true, needs = On, why = TEXT_OFF,
          help = "Adds a Bags column to the chosen recipe's reagents, showing how many of each you carry." },
        { key = "bankReagents", label = "Reagents in Bank", toggle = true, needs = On, why = TEXT_OFF,
          help = "Adds a Bank column to the chosen recipe's reagents, showing how many of each are in your "
              .. "bank." },
        { key = "trainFavorites", label = "Train Favorites", toggle = true, needs = On, why = TEXT_OFF,
          help = "At a profession trainer who teaches any of your favourite recipes that you can learn now "
              .. "(star one before its name, or right-click it in the list), a window beside the trainer's "
              .. "lists them with their cost: Learn one, or Learn All." },
    },
})

page:Card({
    id = "craftOrders", name = "Craft Orders", order = ORDER_ORDERS, switch = "craftOrders", switchWhy = ns.GamepadWhy,
    help = "Opens another player's profession link in this window, to order crafts from them. Choose a recipe, "
        .. "set how many crafts, tick the materials you bring (or type how many), and Add to Order. The order "
        .. "on the right has a suggested tip per craft that you can change; Ask sends the crafter one message "
        .. "per craft with the amount, your materials and the tip: in party chat when they are in your party, "
        .. "else as a whisper. Prices and the tip need an auction house scan.",
    search = "scan prices auction prices quality of life loot items",
    summary = OrdersSummary,
    rows = {
        { key = "orderTip", label = "Suggested Tip", slider = TIP_RANGE, unit = "%", needs = On,
          why = TEXT_OFF,
          help = "The share of what the items sell for that the suggested tip adds on top of paying back the "
              .. "crafter's own materials. At least 1s unless set to 0." },
    },
})

page:Card({
    id = "buying", name = "Buying and Selling", order = ORDER_BUYING,
    help = "Prices, profit and buying the reagents of the chosen recipe, at the auction house or a vendor.",
    summary = BuyingSummary,
    rows = {
        Group("Prices"),
        { key = "craftProfit", label = "Crafting Profit", toggle = true, needs = On, why = TEXT_OFF,
          help = "Once you have scanned the auction house (Scan Prices), the chosen recipe shows what its "
              .. "reagents cost to buy and what the item sells for, and the profit after the 5% auction house "
              .. "cut. Each reagent is priced at its cheapest: a vendor's price once you have seen a vendor "
              .. "sell it, else the lowest buyout at your last scan. Uncheck a reagent you already have to "
              .. "leave it out of the cost, for every recipe that uses it. Hover the lines for the breakdown.",
          search = "auction prices quality of life loot items" },
        { key = "craftProfitList", label = "Profit in Recipe List", toggle = true, needs = ProfitOn,
          why = "Needs Crafting Profit",
          help = "Also shows each recipe's profit at the right of its row in the list, green or red. Recipes "
              .. "whose profit is not known show none." },
        { key = "recipeAvailability", label = "Recipe Availability Marks", toggle = true, needs = On,
          why = TEXT_OFF,
          help = "Shows small markers on recipe rows when the result is in your bags or bank, or the recipe "
              .. "is already on the Shopping List. Hover a marker for its exact count. Equipped items do not "
              .. "count as bag contents." },
        Group("Return on Investment"),
        { key = "craftROI", label = "Show ROI", toggle = true, needs = ProfitOn,
          why = "Needs Crafting Profit",
          help = "Shows the selected recipe's profit as a percentage of the materials' cost, under its "
              .. "profit." },
        { key = "roiGreyBelow", label = "Grey Below", slider = ROI_RANGE, unit = "%", needs = ROIOn,
          why = "Needs Show ROI",
          help = "ROI below this percentage is grey." },
        { key = "roiGreenFrom", label = "Green From", slider = ROI_RANGE, unit = "%", needs = ROIOn,
          why = "Needs Show ROI",
          help = "ROI from this percentage is green; the range below it is yellow." },
        Group("Auction House"),
        { key = "ahShiftClick", label = "Shift-Click Searches AH", toggle = true, needs = On,
          why = TEXT_OFF,
          help = "While the auction house is open, Shift-click a recipe or a reagent to search the auction "
              .. "house for the item: what the recipe makes, or the reagent. While you type in chat, "
              .. "Shift-click still links it." },
        { key = "ahSearch", label = "Search AH Button", toggle = true, needs = On, why = TEXT_OFF,
          help = "While the auction house is open, a Search AH button next to the chosen recipe's name "
              .. "searches it for the item the recipe makes. Unlearned recipes also get Search Recipe, for the "
              .. "pattern, plans or manual that teaches it. Recipes that make no item, such as enchants, get "
              .. "no Search AH." },
        { key = "buyMaterials", label = "Buy on AH", toggle = true, needs = On, why = TEXT_OFF,
          help = "While the auction house is open, a Buy button under the chosen recipe's reagents buys the "
              .. "materials for as many crafts as you set beside it: every checked reagent that vendors do not "
              .. "sell. Each one shows its price first and is only bought when you click Confirm." },
        { key = "searchFavoritesAH", label = "Search Favorites AH", toggle = true, needs = On,
          why = TEXT_OFF,
          help = "At the auction house, a window beside it lists the patterns, plans and manuals of your "
              .. "favourite recipes that you have not learned or bought, with what they cost now. Buy finds "
              .. "the cheapest and asks before Accept buys it." },
        { key = "manualPatternScan", label = "Manual Favorite Scans", toggle = true, needs = FavoriteSearchOn,
          why = "Needs Search Favorites AH",
          help = "Adds Scan, Pause and Resume controls instead of searching every favourite automatically." },
        { key = "favoriteVendorMarks", label = "Favorite Recipe Marks", toggle = true, needs = PadFree,
          why = PadWhy,
          help = "Marks favorite unlearned recipes sold by the open trainer or merchant." },
        { key = "ownedAuctions", label = "Your Auctions", toggle = true, needs = On, why = TEXT_OFF,
          help = "Marks recipe rows whose results you have listed at the auction house.",
          search = "not selling filter listed" },
        { key = "shoppingList", label = "Shopping List", toggle = true, needs = On, why = TEXT_OFF,
          help = "Adds \"- [1] + Add to List\" under a recipe's reagents: the materials Buy on AH would buy for "
              .. "that many crafts go on a shopping list, from anywhere. At the auction house the list shows "
              .. "beside it: Check Prices looks each one up and warns in red when one is well above your last "
              .. "scan, then Buy All goes through the list one material at a time, each bought only when you "
              .. "confirm its final price. A material you can make for less from its parts, such as a bar from "
              .. "ore, has its parts bought instead." },
        { key = "craftQueue", label = "Crafting Queue", toggle = true, needs = ShoppingOn,
          why = "Needs Shopping List",
          help = "Queues crafts and prerequisites, and adds their missing materials to the Shopping List." },
        { key = "shoppingVendor", label = "Vendor Items on Shopping List", toggle = true, needs = ShoppingOn,
          why = "Needs Shopping List",
          help = "Lists materials vendors sell under Buy from Vendor, with Buy buttons beside the merchant." },
        Group("Vendors"),
        { key = "vendorMaterials", label = "Crafts with Vendor Buys", toggle = true, needs = On,
          why = TEXT_OFF,
          help = "Adds a second, orange number next to each recipe: how many you could make after buying the "
              .. "reagents vendors sell, such as Weak Flux or Coarse Thread. The recipe's reagents then say "
              .. "how many of each to buy." },
        { key = "buyVendor", label = "Buy at Vendor", toggle = true, needs = On, why = TEXT_OFF,
          help = "While a merchant is open, a Buy button under the chosen recipe's reagents buys from them, in "
              .. "one click, every checked reagent they sell, such as Coarse Thread or Weak Flux, for as many "
              .. "crafts as you set beside it. The total cost shows beside the button; hover Buy for each "
              .. "reagent." },
    },
})

page:Card({
    id = "gather", name = "Tracking Reminder", order = ORDER_GATHER, switch = "gatherReminder",
    help = "Shows an icon on screen while you know Find Herbs, Find Minerals or Find Fish but are tracking none "
        .. "of them. Click it to start tracking: left-click for the first, right-click for the second, "
        .. "middle-click for the third. Hover it to see which is which. Hidden in combat. Move it in the HUD Editor.",
    summary = GatherSummary,
    studio = { height = GATHER_STAGE_H, states = GATHER_STATES, new = NewGatherPreview, paint = PaintGatherPreview },
    rows = {
        { key = "gatherInInstances", label = "Show in Dungeons and Raids", toggle = true, needs = On,
          why = TEXT_OFF, help = "Also reminds you inside instances. Off by default: few have herbs or ore." },
        { key = "gatherFish", label = "Include Find Fish", toggle = true, needs = On, why = TEXT_OFF,
          help = "Counts Find Fish as a tracking to remind you of, once you have learned it. Turn off if you only "
              .. "track fish now and then." },
        Group("Size"),
        { key = "gatherIconSize", label = "Icon Size", slider = ICON_RANGE, needs = On, why = TEXT_OFF,
          help = "How big the reminder icon is." },
        Settings.Look("gather", { text = true, size = TEXT_RANGE, needs = On, why = TEXT_OFF }),
    },
})

page:Card({
    id = "craftTimer", name = "Total Craft Timer", order = ORDER_CRAFT_TIMER, switch = "craftTimer",
    help = "Crafting several at once (Create All, or Create with a count) shows one bar for the whole batch, "
        .. "drawn like the Flight Timer: the recipe, how many are done and the time left on all of them. It sits "
        .. "where the Flight Timer is, as nobody crafts in flight: move it in the HUD Editor as the Flight Timer.",
    studio = { height = CRAFT_STAGE_H, states = CRAFT_STATES, new = NewCraftPreview, paint = PaintCraftPreview },
    rows = {
        { key = "craftTimerShowCastBar", label = "Show Normal Cast Bar", toggle = true, needs = On,
          why = TEXT_OFF, help = "Keeps the normal cast bar visible alongside the total crafting timer." },
        Settings.Look("craftTimer", { text = true, size = TEXT_RANGE, bar = "Naowh Gradient", background = "alpha" }),
    },
})

page:Card({
    id = "disenchant", name = "Disenchant Window", order = ORDER_DISENCHANT, switch = "disenchant",
    help = "With Enchanting open, a Disenchant button at the top of the window opens a window of every item in "
        .. "your bags you can disenchant: green, blue and purple weapons and armor (or type /naowh disenchant). "
        .. "Right-click an item to keep that one copy, or Shift-right-click to keep every copy of it, on any "
        .. "character, until you right-click it again. Disenchant All disenchants the rest one by one, one item "
        .. "per click, as the game asks a click for every disenchant. An item the game will not take (skill too low) is skipped until you reload. "
        .. "Closes when combat starts.",
})

page:Card({
    id = "disenchantDeals", name = "Disenchant Deals", order = ORDER_DISENCHANT_DEALS,
    switch = "disenchantDeals",
    help = "Finds profitable or low-cost disenchant purchases from your last Scan Prices.",
    search = "auction house enchanting profit level skill expected value guaranteed ROI",
    rows = {
        { key = "disenchantDealsTooltip", label = "Detailed Deal Tooltips", toggle = true,
          needs = DisenchantDealsOn, why = "Needs Disenchant Deals",
          help = "Shows possible materials, expected value, required skill and profit on deal tooltips." },
        { key = "disenchantDealsTooltipEnchanters", label = "Only On Enchanters", toggle = true,
          needs = DisenchantDealsTooltipOn, why = "Needs Detailed Deal Tooltips",
          help = "Only shows detailed deal tooltips on characters that know Enchanting." },
        { key = "disenchantDealsTooltipAuctionOnly", label = "Only At Auction House", toggle = true,
          needs = DisenchantDealsTooltipOn, why = "Needs Detailed Deal Tooltips",
          help = "Only shows detailed deal tooltips while the auction house is open." },
    },
})

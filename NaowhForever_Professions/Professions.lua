-- Professions.lua: the Professions module's settings, its window's shared state and its public calls.
local ns = _G.NaowhForever

local F = ns.FEATURES.professions

local S = ns.UI.ModuleSettings("professions", {
    enabled = F.enabled,
    skillThresholds = F.skillThresholds,
    recipeFinder = F.recipeFinder, rankAlert = F.rankAlert, bagReagents = F.bagReagents,
    bankReagents = F.bankReagents, vendorMaterials = F.vendorMaterials,
    craftOrders = F.craftOrders, orderTip = 10,
    craftTimer = F.craftTimer, craftTimerShowCastBar = F.craftTimerShowCastBar,
    craftTimerFont = "", craftTimerFontSize = 14, craftTimerOutline = "OUTLINE", craftTimerTexture = "",
    craftTimerBgAlpha = 0.9,
    shoppingList = F.shoppingList, shoppingListDock = F.shoppingListDock,
    craftQueue = F.craftQueue,
    shoppingVendor = F.shoppingVendor,
    trainFavorites = F.trainFavorites, searchFavoritesAH = F.searchFavoritesAH,
    manualPatternScan = F.manualPatternScan, favoriteVendorMarks = F.favoriteVendorMarks,
    gatherReminder = F.gatherReminder, gatherInInstances = false, gatherIconSize = 40, gatherFish = false,
    gatherFont = "", gatherFontSize = 13, gatherOutline = "OUTLINE",
    ahSearch = F.ahSearch, ahShiftClick = F.ahShiftClick, craftProfit = F.craftProfit,
    craftProfitList = F.craftProfitList, recipeAvailability = F.recipeAvailability,
    ownedAuctions = F.ownedAuctions,
    buyMaterials = F.buyMaterials, buyVendor = F.buyVendor,
    craftROI = F.craftROI, roiGreyBelow = 10, roiGreenFrom = 30,
    disenchant = F.disenchant, disenchantDeals = F.disenchantDeals, disenchantDealsTooltip = false,
    disenchantDealsTooltipAllCharacters = false, disenchantDealsTooltipAuctionOnly = false,
    filterMaterials = false, filterSkillUp = false, filterProfit = false,
    filterNotSelling = false, filterBoE = false, filterBoP = false, filterFavorite = false,
})
ns.ProfessionSettings = S
ns.ProfBagChanges = 0

local P = {
    Settings = S,
    State = { offset = 0, query = "", linked = false, stale = true, listChanged = false },
}
ns.Professions = P

local function SplitTooltipCharacters()
    if S.Raw("disenchantDealsTooltipAllCharacters") ~= nil then return end
    local onlyEnchanters = S.Raw("disenchantDealsTooltipEnchanters")
    local all = S.Raw("disenchantDealsTooltip") == true
    if onlyEnchanters ~= nil then all = not onlyEnchanters end
    S.DB().disenchantDealsTooltipEnchanters = nil
    S.Set("disenchantDealsTooltipAllCharacters", all)
end

hooksecurefunc(ns, "Apply", SplitTooltipCharacters)

local temporary = {}

local function LegacyKey()
    local name, realm = UnitName("player"), GetRealmName()
    if not name or name == _G.UNKNOWNOBJECT or not realm then return end
    return name .. "-" .. realm
end

function P.CharacterData(store, create)
    local mine = ns.Shared.CharacterData(store)
    if mine then return mine, false, false end
    if not UnitGUID("player") then
        if not create then return end
        temporary[store] = temporary[store] or {}
        return temporary[store]
    end
    local all = ns.AccountSettings()[store]
    local legacyKey = LegacyKey()
    local legacy = type(all) == "table" and legacyKey and all[legacyKey]
    if type(legacy) ~= "table" and not create then return end
    mine = ns.Shared.CharacterData(store, true)
    if not mine then return end
    local migrated = type(legacy) == "table"
    if migrated then
        for key, value in pairs(CopyTable(legacy)) do mine[key] = value end
    end
    return mine, true, migrated
end

function P.On()
    return S.Get("enabled")
end

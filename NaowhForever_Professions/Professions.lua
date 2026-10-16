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
    shoppingList = F.shoppingList,
    trainFavorites = F.trainFavorites, searchFavoritesAH = F.searchFavoritesAH,
    manualPatternScan = F.manualPatternScan,
    gatherReminder = F.gatherReminder, gatherInInstances = false, gatherIconSize = 40, gatherFish = false,
    gatherFont = "", gatherFontSize = 13, gatherOutline = "OUTLINE",
    ahSearch = F.ahSearch, ahShiftClick = F.ahShiftClick, craftProfit = F.craftProfit,
    craftProfitList = F.craftProfitList, recipeAvailability = F.recipeAvailability,
    buyMaterials = F.buyMaterials, buyVendor = F.buyVendor,
    craftROI = F.craftROI, roiGreyBelow = 10, roiGreenFrom = 30,
    disenchant = F.disenchant,
    filterMaterials = false, filterSkillUp = false, filterProfit = false,
    filterBoE = false, filterBoP = false, filterFavorite = false,
})
ns.ProfessionSettings = S
ns.ProfBagChanges = 0

local P = {
    Settings = S,
    State = { offset = 0, query = "", linked = false, stale = true, listChanged = false },
}
ns.Professions = P

function P.On()
    return S.Get("enabled")
end

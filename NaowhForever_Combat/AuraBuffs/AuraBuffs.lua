-- AuraBuffs.lua: the AuraBuffs module's settings (ns.AuraBuffSettings), its table (ns.AuraBuffs) and API.
local ns = _G.NaowhForever

local F = ns.FEATURES.auraBuffs

local S = ns.UI.ModuleSettings("auraBuffs", {
    enabled = F.enabled,
    campBuffTextSize = 16, campBuffSide = "right", campShowMissing = true,
    consumablesWorld = false, consumablesDungeon = true, consumablesRaid = true, consumablesMinutes = 2,
    consumablesMaxHide = false, raidBuffsMaxHide = false, personalBuffsMaxHide = false,
    onlyIfCarried = true, carriedPicks = {}, hideResting = true,
    raidBuffsWorld = true, raidBuffsDungeon = true, raidBuffsRaid = true,
    personalBuffsWorld = true, personalBuffsDungeon = true, personalBuffsRaid = true,
    raidBuffs = F.raidBuffs, raidBuffsOwn = true, raidBuffRange = F.raidBuffRange, raidBuffRangeHide = F.raidBuffRangeHide,
    hideBlessingsOnPaladin = F.hideBlessingsOnPaladin,
    raidBuffPicks = { intellect = true, stamina = true, spirit = true, wild = true, blessing = false, salvation = false },
    personalBuffs = F.personalBuffs, personalBuffPicks = {}, weaponEnhancements = F.weaponEnhancements,
    buffGlow = false, buffGlowType = "standard", buffGlowColor = { r = 1, g = 0.82, b = 0.2 }, buffGlowLines = 8,
    buffGlowThickness = 2, buffGlowSpeed = 5,
    iconSize = 48, buffIconMode = "default", buffsFont = "", buffsFontSize = 14, buffsOutline = "OUTLINE",
    buffsBorderColor = false,
    buffsPos = { point = "TOP", relPoint = "TOP", x = 0, y = -232 },

    campfire = F.campfire, campTimer = true, campBuffs = true,
    campSound = true, campSoundKey = "none", campIconSize = 110, campNearbyAlert = F.campNearbyAlert,
    campSitButton = true, campGlow = false, campGlowType = "pixel",
    campGlowColor = { r = 0.97, g = 0.27, b = 0.27 }, campGlowLines = 8, campGlowThickness = 2, campGlowSpeed = 5,
    campShowUnder = true, campShowUnderMinutes = 2, campNearbyMinutes = 2, campStyle = "round",
    campAlertScale = 1.4, campAlertFade = true,
    campAlertFont = "", campAlertOutline = "", campAlertBackground = "none",
    campSimpleWidth = 360, campSimpleHeight = 26, campSimpleTextSize = 12, campBonusIcons = false,
    campHiddenBonuses = {}, campFont = "", campOutline = "", campBarOutline = "NONE",
    campPos = { point = "CENTER", relPoint = "BOTTOMRIGHT", x = -223, y = 61 },

    lowHealth = F.lowHealth, lowHealthBelow = 35, lowHealthItem = "auto", lowHealthShowEmpty = false,
    lowHealthIconSize = 48, lowHealthGlow = true, lowHealthGlowType = "pixel",
    lowHealthGlowColor = { r = 1, g = 0.25, b = 0.25 }, lowHealthGlowLines = 8, lowHealthGlowThickness = 2,
    lowHealthGlowSpeed = 5,
    lowHealthFont = "", lowHealthFontSize = 16, lowHealthOutline = "OUTLINE",
    lowHealthSound = true, lowHealthSoundKey = "none",
    lowHealthPos = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 249 },
    campBuffMode = false,
})

local OLD_ADDON = "NaowhForever_AuraBuffs"
local OLD_COPY = C_AddOns.DoesAddOnExist(OLD_ADDON) and C_AddOns.GetAddOnEnableState(OLD_ADDON) > 0
local CATEGORY_NAMES = { food = ns.L("Food"), flask = ns.L("Flask"), scroll = ns.L("Scroll"),
    battle = ns.L("Battle Elixir") }
local CATEGORY_ORDER = { "food", "flask", "scroll", "battle" }
local OLD_WHERE = {
    always = { world = true, dungeon = true, raid = true },
    instance = { world = false, dungeon = true, raid = true },
    raid = { world = false, dungeon = false, raid = true },
}

local GetSetting = S.Get

function S.Get(key)
    if key == "enabled" and OLD_COPY then return false end
    return GetSetting(key)
end

ns.AuraBuffSettings = S

local A = {
    Settings = S,
    PAGE = "AuraBuffs/Settings",
    CATEGORY_NAMES = CATEGORY_NAMES,
    CATEGORY_ORDER = CATEGORY_ORDER,
    OLD_COPY = OLD_COPY,
}
ns.AuraBuffs = A

function A.Enabled()
    return S.Get("enabled") and true or false
end

function A.Needs(key)
    return function() return S.Get("enabled") and S.Get(key) and true or false end
end

function A.Migrate()
    local db = S.DB()
    local old = OLD_WHERE[db.consumablesWhere]
    db.consumablesWhere = nil
    if not old then return end
    db.consumablesWorld, db.consumablesDungeon, db.consumablesRaid = old.world, old.dungeon, old.raid
end

function ns.CampBuffMode()
    local mode = S.Get("campBuffMode")
    if mode then return mode end
    return S.Get("campBuffs") and "always" or "off"
end

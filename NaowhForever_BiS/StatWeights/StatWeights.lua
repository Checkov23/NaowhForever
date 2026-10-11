-- StatWeights.lua: what each stat is worth to your spec (ns.StatWeights): its settings, specs and weights.
local ns = _G.NaowhForever

local UI = ns.UI
local F = ns.FEATURES.statWeights

local SAME = 1e-9
local PER_POINT = 1
local EMPTY = {}

local STATS = {
    { "str", ns.L("Strength"), 0, 3, 0.05 }, { "agi", ns.L("Agility"), 0, 3, 0.05 },
    { "sta", ns.L("Stamina"), 0, 3, 0.05 }, { "int", ns.L("Intellect"), 0, 3, 0.05 },
    { "spi", ns.L("Spirit"), 0, 3, 0.05 }, { "ap", ns.L("Attack Power"), 0, 3, 0.05 },
    { "rap", ns.L("Ranged Attack Power"), 0, 3, 0.05 }, { "dps", ns.L("Weapon DPS"), 0, 20, 0.1 },
    { "hit", ns.L("Hit %"), 0, 30, 0.5 },
    { "crit", ns.L("Crit %"), 0, 30, 0.5 }, { "haste", ns.L("Haste %"), 0, 30, 0.5 },
    { "spell", ns.L("Spell Damage"), 0, 3, 0.05 }, { "heal", ns.L("Healing"), 0, 3, 0.05 },
    { "shit", ns.L("Spell Hit %"), 0, 30, 0.5 }, { "scrit", ns.L("Spell Crit %"), 0, 30, 0.5 },
    { "mp5", ns.L("Mana every 5 sec"), 0, 5, 0.1 },
    { "fire", ns.L("Fire Damage"), 0, 3, 0.05 }, { "frost", ns.L("Frost Damage"), 0, 3, 0.05 },
    { "shadow", ns.L("Shadow Damage"), 0, 3, 0.05 }, { "nature", ns.L("Nature Damage"), 0, 3, 0.05 },
    { "arcane", ns.L("Arcane Damage"), 0, 3, 0.05 }, { "holy", ns.L("Holy Damage"), 0, 3, 0.05 },
    { "def", ns.L("Defense"), 0, 5, 0.05 }, { "dodge", ns.L("Dodge %"), 0, 30, 0.5 },
    { "block", ns.L("Block %"), 0, 30, 0.5 }, { "armor", ns.L("Armor"), 0, 0.2, 0.005 },
    { "threat", ns.L("Threat %"), 0, 30, 0.5 },
}
local GAME_KEYS = {
    ITEM_MOD_STRENGTH_SHORT = "str", ITEM_MOD_AGILITY_SHORT = "agi", ITEM_MOD_STAMINA_SHORT = "sta",
    ITEM_MOD_INTELLECT_SHORT = "int", ITEM_MOD_SPIRIT_SHORT = "spi", ITEM_MOD_ATTACK_POWER_SHORT = "ap",
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "rap", ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "spell",
    ITEM_MOD_SPELL_POWER_SHORT = { "spell", "heal" }, ITEM_MOD_SPELL_HEALING_DONE_SHORT = "heal",
    ITEM_MOD_HIT_RATING_SHORT = { "hit", "shit" }, ITEM_MOD_CRIT_RATING_SHORT = { "crit", "scrit" },
    ITEM_MOD_HIT_SPELL_RATING_SHORT = "shit", ITEM_MOD_CRIT_SPELL_RATING_SHORT = "scrit",
    ITEM_MOD_SPELL_CRIT_RATING_SHORT = "scrit", ITEM_MOD_MANA_REGENERATION_SHORT = "mp5",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "def", ITEM_MOD_DODGE_RATING_SHORT = "dodge",
    ITEM_MOD_BLOCK_RATING_SHORT = "block", ITEM_MOD_HASTE_RATING_SHORT = "haste", RESISTANCE0_NAME = "armor",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "dps",
}
local PER_PERCENT = {
    ITEM_MOD_HIT_RATING_SHORT = 10, ITEM_MOD_HIT_SPELL_RATING_SHORT = 10, ITEM_MOD_CRIT_RATING_SHORT = 14,
    ITEM_MOD_CRIT_SPELL_RATING_SHORT = 14, ITEM_MOD_SPELL_CRIT_RATING_SHORT = 14, ITEM_MOD_DODGE_RATING_SHORT = 12,
    ITEM_MOD_BLOCK_RATING_SHORT = 5, ITEM_MOD_HASTE_RATING_SHORT = 10,
}
local TREES = {
    DRUID = { "balance-druid", "feral-dps-druid", "restoration-druid" },
    HUNTER = { "beast-mastery-hunter", "marksmanship-hunter", "survival-hunter" },
    MAGE = { "arcane-mage", "fire-mage", "frost-mage" },
    PALADIN = { "holy-paladin", "protection-paladin", "retribution-paladin" },
    PRIEST = { "discipline-priest", "holy-priest", "shadow-priest" },
    ROGUE = { "assassination-rogue", "combat-rogue", "subtlety-rogue" },
    SHAMAN = { "elemental-shaman", "enhancement-shaman", "restoration-shaman" },
    WARLOCK = { "affliction-warlock", "demonology-warlock", "destruction-warlock" },
    WARRIOR = { "arms-warrior", "fury-warrior", "protection-warrior" },
}

local STAT_KEY, STAT_NAME = {}, {}
for _, stat in ipairs(STATS) do STAT_KEY[stat[1]], STAT_NAME[stat[1]] = true, stat[2] end

local classSpecs, byKey
local talentSpec, talentRead = nil, false
local watcher
local groupIDs, spentBy = {}, {}
local merged = {}
local listeners = {}

local function Index()
    byKey = {}
    for _, spec in ipairs(ns.StatWeightDefaults) do byKey[spec.key] = spec end
end

local function ReadSpent(configID, groups)
    wipe(groupIDs)
    wipe(spentBy)
    for i, group in ipairs(groups) do groupIDs[i] = group.groupID end
    for _, info in ipairs(C_Traits.GetGroupCurrencyInfo(configID, groupIDs)) do
        local currency = info.currencyInfos and info.currencyInfos[1]
        spentBy[info.traitNodeGroupID] = currency and currency.spent or 0
    end
end

local function ReadTalents()
    local trees = TREES[select(2, UnitClass("player"))]
    local configID = trees and C_ClassTalents and C_ClassTalents.GetActiveConfigID()
    local config = configID and C_Traits.GetConfigInfo(configID)
    local treeID = config and config.treeIDs and config.treeIDs[1]
    if not treeID then return nil end
    local groups = C_Traits.GetGroupDisplayInfoByTreeID(treeID)
    ReadSpent(configID, groups)
    local best, most = nil, 0
    for i, group in ipairs(groups) do
        local spent = spentBy[group.groupID] or 0
        if spent > most then best, most = trees[i], spent end
    end
    return best
end

local function TalentsChanged()
    talentRead = false
end

local function Changes(create)
    local account = ns.AccountSettings()
    if create and type(account.statWeights) ~= "table" then account.statWeights = {} end
    return type(account.statWeights) == "table" and account.statWeights or nil
end

local function Changed(key)
    merged[key] = nil
    for i = 1, #listeners do listeners[i](key) end
end

local SW = { MAX_WORTH = 1000, PERCENT = 100 }
ns.StatWeights = SW

local S = UI.ModuleSettings("statWeights", { enabled = F.enabled })
SW.Settings = S
ns.StatWeightSettings = S
SW.STATS = STATS
SW.GAME_KEYS = GAME_KEYS
SW.PER_PERCENT = PER_PERCENT

function SW.IsStat(stat)
    return STAT_KEY[stat] == true
end

function SW.TreeSpec(class, index)
    local trees = TREES[class]
    return trees and trees[index]
end

function SW.KeyAmount(gameKey, amount)
    return amount / (PER_PERCENT[gameKey] or PER_POINT)
end

function SW.KeyWorth(gameKey, amount, weights)
    local mapped = GAME_KEYS[gameKey]
    if not mapped then return 0 end
    amount = amount / (PER_PERCENT[gameKey] or PER_POINT)
    if type(mapped) == "string" then return amount * (weights[mapped] or 0) end
    local worth = 0
    for i = 1, #mapped do worth = worth + amount * (weights[mapped[i]] or 0) end
    return worth
end

function SW.KeyName(gameKey)
    local mapped = GAME_KEYS[gameKey]
    if type(mapped) == "table" then mapped = mapped[1] end
    return mapped and STAT_NAME[mapped]
end

function SW.On()
    return S.Get("enabled") == true
end

function SW.ClassSpecs()
    if not classSpecs then
        classSpecs = {}
        local _, class = UnitClass("player")
        for _, spec in ipairs(ns.StatWeightDefaults) do
            if spec.class == class then classSpecs[#classSpecs + 1] = spec end
        end
    end
    return classSpecs
end

function SW.Spec(key)
    if not byKey then Index() end
    return byKey[key]
end

function SW.TalentSpec()
    if talentRead then return talentSpec end
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:RegisterEvent("TRAIT_CONFIG_UPDATED")
        watcher:SetScript("OnEvent", TalentsChanged)
    end
    talentSpec, talentRead = ReadTalents(), true
    return talentSpec
end

function SW.ActiveSpec()
    local picked = S.Get("spec")
    local mine = SW.ClassSpecs()
    for _, spec in ipairs(mine) do
        if spec.key == picked then return picked end
    end
    local talents = SW.TalentSpec()
    if talents then return talents end
    local B = ns.BiS
    local listSpec = B and B.Lists and B.Lists.CurrentSpec()
    if listSpec and SW.Spec(listSpec.key) then return listSpec.key end
    return mine[1] and mine[1].key
end

function SW.For(key)
    if not key then return nil end
    local weights = merged[key]
    if weights then return weights end
    local spec = SW.Spec(key)
    if not spec then return nil end
    weights = {}
    for stat, worth in pairs(spec.weights) do weights[stat] = worth end
    local changes = Changes()
    for stat, worth in pairs(changes and changes[key] or EMPTY) do
        if STAT_KEY[stat] and type(worth) == "number" then weights[stat] = worth end
    end
    merged[key] = weights
    return weights
end

function SW.Default(key, stat)
    local spec = SW.Spec(key)
    return spec and spec.weights[stat] or 0
end

function SW.Changed(key, stat)
    local changes = Changes()
    return changes ~= nil and changes[key] ~= nil and changes[key][stat] ~= nil
end

function SW.Set(key, stat, worth)
    if not (SW.Spec(key) and STAT_KEY[stat]) then return end
    local changes = Changes(true)
    if worth ~= nil and math.abs(worth - SW.Default(key, stat)) < SAME then worth = nil end
    if worth == nil and not (changes[key] and changes[key][stat] ~= nil) then return end
    changes[key] = changes[key] or {}
    changes[key][stat] = worth
    if next(changes[key]) == nil then changes[key] = nil end
    Changed(key)
end

function SW.Reset(key)
    local changes = Changes()
    if not (changes and changes[key]) then return end
    changes[key] = nil
    Changed(key)
end

function SW.OnChange(fn)
    listeners[#listeners + 1] = fn
end

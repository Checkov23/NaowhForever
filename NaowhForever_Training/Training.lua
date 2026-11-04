-- Training.lua: the Training Planner's settings, its module table (ns.Training) and each character's prices and skipped spells.
local ns = _G.NaowhForever

local UI = ns.UI
local CharacterData = ns.Shared.CharacterData

local F = ns.FEATURES.training

local S = UI.ModuleSettings("training", { enabled = F.enabled, levelUpToast = F.levelUpToast,
    trainerPanel = F.trainerPanel, spellbook = F.spellbook, spellbookOpen = true, showLearned = true,
    miniShown = false })
ns.TrainingSettings = S

local Training = { Settings = S }
ns.Training = Training

local SPELL, COST = 2, 3
local PRICES = "trainingCharPrices"

local charKey
local unnamed = {}
local listeners = {}

local function On()
    return S.Get("enabled")
end

local function Account(key)
    local account = ns.AccountSettings()
    account[key] = account[key] or {}
    return account[key]
end

local function CharKey()
    if charKey then return charKey end
    local name = UnitName("player")
    local key = name .. "-" .. GetRealmName()
    if name ~= UNKNOWNOBJECT then charKey = key end
    return key
end

local function Characters(key)
    if charKey or UnitName("player") ~= UNKNOWNOBJECT then return Account(key) end
    unnamed[key] = unnamed[key] or {}
    return unnamed[key]
end

local function Prices(create)
    return CharacterData(PRICES, create)
end

local function Ignored()
    local all = Characters("trainingIgnored")
    local key = CharKey()
    all[key] = all[key] or {}
    return all[key]
end

local function ClassSpells()
    local _, _, classID = UnitClass("player")
    return ns.TrainingData[classID] or {}
end

local function Price(entry, prices)
    return prices and prices[entry[SPELL]] or entry[COST]
end

local function Changed()
    for i = 1, #listeners do listeners[i]() end
    UI:RefreshPage(true)
end

function Training.OnChange(fn)
    listeners[#listeners + 1] = fn
end

Training.On = On
Training.Account = Account
Training.CharKey = CharKey
Training.Characters = Characters
Training.Prices = Prices
Training.Ignored = Ignored
Training.ClassSpells = ClassSpells
Training.Price = Price
Training.Changed = Changed

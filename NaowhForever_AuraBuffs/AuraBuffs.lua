-- AuraBuffs.lua: the AuraBuffs module's settings (ns.AuraBuffSettings), its table (ns.AuraBuffs) and API.
local ns = _G.NaowhForever

local F = ns.FEATURES.auraBuffs

local S = ns.UI.ModuleSettings("auraBuffs", {
    enabled = F.enabled, consumableEntries = {},
    campBuffTextSize = 16, campBuffSide = "right", campShowMissing = true,
    consumablesWhere = "instance", consumablesMinutes = 2,
    onlyIfCarried = true, hideResting = true,
    raidBuffs = F.raidBuffs, raidBuffsOwn = true,
    raidBuffPicks = { intellect = true, stamina = true, spirit = true, wild = true, blessing = false },
    personalBuffs = F.personalBuffs, personalBuffPicks = {},
    iconSize = 36, buffsFont = "", buffsFontSize = 14, buffsOutline = "OUTLINE",
    buffsPos = { point = "TOP", relPoint = "TOP", x = 0, y = -232 },

    campfire = F.campfire, campTimer = true, campBuffs = true,
    campSound = true, campSoundKey = "none", campIconSize = 110, campNearbyAlert = F.campNearbyAlert,
    campShowUnder = true, campShowUnderMinutes = 2, campNearbyMinutes = 2, campStyle = "round",
    campAlertScale = 1.4, campAlertFade = true,
    campAlertFont = "", campAlertOutline = "", campAlertBackground = "none",
    campSimpleWidth = 360, campSimpleHeight = 26, campSimpleTextSize = 12, campBonusIcons = false,
    campHiddenBonuses = {}, campFont = "", campOutline = "", campBarOutline = "NONE",
    campPos = { point = "CENTER", relPoint = "BOTTOMRIGHT", x = -223, y = 61 },

    lowHealth = F.lowHealth, lowHealthBelow = 35, lowHealthItem = "auto",
    lowHealthIconSize = 48, lowHealthGlow = true,
    lowHealthFont = "", lowHealthFontSize = 16, lowHealthOutline = "OUTLINE",
    lowHealthSound = true, lowHealthSoundKey = "none",
    lowHealthPos = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 249 },
    campBuffMode = false, windowAlpha = 1,
})

local ENTRIES = "consumableEntries"
local MIN_ID, MAX_ID = 1, 2147483647
local LIST_PREFIX = "NFCONSUMABLES1:"
local MAX_ENTRIES = 500
local CATEGORY_NAMES = { food = ns.L("Food"), flask = ns.L("Flask"), scroll = ns.L("Scroll"),
    battle = ns.L("Battle Elixir"), guardian = ns.L("Guardian Elixir") }
local CATEGORY_ORDER = { "food", "flask", "scroll", "battle", "guardian" }

local GetSetting, SetSetting = S.Get, S.Set

function S.Get(key)
    if key == ENTRIES and ns.DB then
        local data = ns.DB().utilityReminders
        return data and data.consumables or {}
    end
    return GetSetting(key)
end

function S.Set(key, value)
    if key ~= ENTRIES or not ns.DB then
        SetSetting(key, value)
        return
    end
    local db = ns.DB()
    db.utilityReminders = db.utilityReminders or {}
    db.utilityReminders.consumables = value
end

ns.AuraBuffSettings = S

local function ParseListString(text, entries)
    for group in text:sub(#LIST_PREFIX + 1):gmatch("[^;]+") do
        local category, ids = group:match("^(%a+)=(.+)$")
        if not category then return end
        for item in ids:gmatch("[^,]+") do
            local entry = ns.ParseConsumableEntry(category, (item:gsub("/", ",")))
            if not entry then return end
            entries[#entries + 1] = entry
        end
    end
    return entries
end

local function ProfileConsumables(text, entries)
    local payload = ns.DecodeProfile(text)
    local list = payload and payload.parts.consumables
    if type(list) ~= "table" then return entries end
    for _, entry in ipairs(list) do entries[#entries + 1] = entry end
    return entries
end

local A = {
    Settings = S,
    PAGE = "AuraBuffs/Settings",
    CATEGORY_NAMES = CATEGORY_NAMES,
    CATEGORY_ORDER = CATEGORY_ORDER,
    MAX_ENTRIES = MAX_ENTRIES,
}
ns.AuraBuffs = A

function A.Enabled()
    return S.Get("enabled") and true or false
end

function A.Needs(key)
    return function() return S.Get("enabled") and S.Get(key) and true or false end
end

function ns.ParseConsumableEntry(category, text)
    if not CATEGORY_NAMES[category] or type(text) ~= "string" then return end
    local ids = {}
    for token in text:gmatch("[^,%s]+") do
        if not token:match("^%d+$") then return end
        local id = tonumber(token)
        if id < MIN_ID or id > MAX_ID then return end
        ids[#ids + 1] = id
    end
    if #ids == 0 then return end
    local itemID = table.remove(ids, 1)
    return { category = category, itemID = itemID, auras = ids[1] and ids or nil }
end

function ns.ConsumableListString(entries)
    local byCategory = {}
    for _, entry in ipairs(entries) do
        local ids = byCategory[entry.category] or {}
        byCategory[entry.category] = ids
        ids[#ids + 1] = entry.auras and entry.itemID .. "/" .. table.concat(entry.auras, "/") or tostring(entry.itemID)
    end
    local groups = {}
    for _, category in ipairs(CATEGORY_ORDER) do
        if byCategory[category] then
            groups[#groups + 1] = category .. "=" .. table.concat(byCategory[category], ",")
        end
    end
    return LIST_PREFIX .. table.concat(groups, ";")
end

function ns.ParseConsumableList(text)
    text = text:gsub("%s", "")
    local entries
    if text:sub(1, #LIST_PREFIX) == LIST_PREFIX then
        entries = ParseListString(text, {})
    else
        entries = ProfileConsumables(text, {})
    end
    if entries and #entries > 0 then return entries end
end

function ns.CampBuffMode()
    local mode = S.Get("campBuffMode")
    if mode then return mode end
    return S.Get("campBuffs") and "always" or "off"
end

-- Gear.lua: gear helpers on ns.Shared.Items: the slots, what fits where, what you wear, weapons in short and what a class can use.
local ns = _G.NaowhForever

local GetItemInfoInstant = C_Item.GetItemInfoInstant

local Items = ns.Shared.Items

local WEAPON_CLASS = 2
local NO_ARMOR_TYPE = 0
local SHIELD_SUBCLASS = 6
local HEAVY_ARMOR_LEVEL = 40
local FACT_CLASS, FACT_SUBCLASS, FACT_REQUIRED = 1, 2, 4
local TWO_HAND = "INVTYPE_2HWEAPON"

local GEAR_SLOTS = {
    { 1, "Head" }, { 2, "Neck" }, { 3, "Shoulder" }, { 15, "Back", "Back (slot)" }, { 5, "Chest" },
    { 9, "Wrist" }, { 10, "Hands" }, { 6, "Waist" }, { 7, "Legs" }, { 8, "Feet" },
    { 11, "Ring 1" }, { 12, "Ring 2" }, { 13, "Trinket 1" }, { 14, "Trinket 2" },
    { 16, "Main Hand" }, { 17, "Off Hand" }, { 18, "Ranged" },
}

local EQUIP_SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

local PAIR = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 }

local ONE_HAND_ONLY = { INVTYPE_WEAPONMAINHAND = "MH", INVTYPE_WEAPONOFFHAND = "OH" }

local WEAPON_SHORT = {
    [0] = { "Axe", "1h" }, [1] = { "Axe", "2h" }, [2] = { "Bow" }, [3] = { "Gun" },
    [4] = { "Mace", "1h" }, [5] = { "Mace", "2h" }, [6] = { "Polearm" }, [7] = { "Sword", "1h" },
    [8] = { "Sword", "2h" }, [10] = { "Staff" }, [13] = { "Fist Weapon" }, [15] = { "Dagger" },
    [16] = { "Thrown" }, [18] = { "Crossbow" }, [19] = { "Wand" },
}

local ARMOR = { MAGE = 1, PRIEST = 1, WARLOCK = 1, ROGUE = 2, DRUID = 2, HUNTER = 3, SHAMAN = 3,
    WARRIOR = 4, PALADIN = 4 }
local ARMOR_BEFORE_HEAVY = { HUNTER = 2, SHAMAN = 2, WARRIOR = 3, PALADIN = 3 }
local SHIELD = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local RELIC = { [7] = "PALADIN", [8] = "DRUID", [9] = "SHAMAN" }
local WEAPONS = {
    DRUID = { 4, 5, 10, 13, 15 },
    HUNTER = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 },
    MAGE = { 7, 10, 15, 19 },
    PALADIN = { 0, 1, 4, 5, 6, 7, 8 },
    PRIEST = { 4, 10, 15, 19 },
    ROGUE = { 2, 3, 4, 7, 13, 15, 16, 18 },
    SHAMAN = { 0, 1, 4, 5, 10, 13, 15 },
    WARLOCK = { 7, 10, 15, 19 },
    WARRIOR = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 },
}

local EMPTY = {}

local weaponNames = {}

local function AsSet(list)
    local set = {}
    for _, value in ipairs(list) do set[value] = true end
    return set
end

for class, subclasses in pairs(WEAPONS) do WEAPONS[class] = AsSet(subclasses) end

local function ByHand(subclass)
    local byHand = weaponNames[subclass]
    if byHand then return byHand end
    byHand = {}
    weaponNames[subclass] = byHand
    return byHand
end

Items.GEAR_SLOTS = GEAR_SLOTS
Items.SLOT_NAME = {}
local SLOT_KEY = {}
for _, s in ipairs(GEAR_SLOTS) do Items.SLOT_NAME[s[1]], SLOT_KEY[s[1]] = s[2], s[3] or s[2] end
Items.ONE_HAND_ONLY = ONE_HAND_ONLY

function Items.SlotName(slot)
    return SLOT_KEY[slot] and ns.L(SLOT_KEY[slot])
end

function Items.SlotsFor(itemID)
    local _, _, _, equipLoc = GetItemInfoInstant(itemID)
    return EQUIP_SLOTS[equipLoc]
end

local SlotsFor = Items.SlotsFor

function Items.Fits(itemID, slot)
    local slots = SlotsFor(itemID) or EMPTY
    for i = 1, #slots do
        if slots[i] == slot then return true end
    end
    return false
end

function Items.IsTwoHand(itemID)
    local _, _, _, equipLoc = GetItemInfoInstant(itemID)
    return equipLoc == TWO_HAND
end

function Items.Wearing(slot, itemID)
    if GetInventoryItemID("player", slot) == itemID then return true end
    local pair = PAIR[slot]
    return pair ~= nil and GetInventoryItemID("player", pair) == itemID
end

function Items.WeaponName(subclass, equipLoc)
    local short = WEAPON_SHORT[subclass]
    if not short then return nil end
    local hand = ONE_HAND_ONLY[equipLoc] or short[2] or ""
    local byHand = ByHand(subclass)
    local name = byHand[hand]
    if name then return name end
    name = hand ~= "" and hand .. " " .. short[1] or short[1]
    byHand[hand] = name
    return name
end

function Items.WeaponOf(itemID)
    local _, _, _, equipLoc, _, classID, subclass = GetItemInfoInstant(itemID)
    return classID == WEAPON_CLASS and Items.WeaponName(subclass, equipLoc) or nil
end

function Items.ClassCanUse(class, item)
    local itemClass, sub, req = item[FACT_CLASS], item[FACT_SUBCLASS], item[FACT_REQUIRED]
    if itemClass == WEAPON_CLASS then return WEAPONS[class][sub] == true end
    if sub == NO_ARMOR_TYPE then return true end
    if sub == SHIELD_SUBCLASS then return SHIELD[class] == true end
    if RELIC[sub] then return RELIC[sub] == class end
    return sub == (req < HEAVY_ARMOR_LEVEL and ARMOR_BEFORE_HEAVY[class] or ARMOR[class])
end

ns.ClassCanUse = Items.ClassCanUse

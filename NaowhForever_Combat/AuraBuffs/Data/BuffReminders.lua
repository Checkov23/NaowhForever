-- BuffReminders.lua: the spells and items behind the Buffs & Consumables reminders (ns.BuffReminderData).
local ns = _G.NaowhForever

local ICON_PATH = "Interface\\Icons\\"

local D = {}
ns.BuffReminderData = D

D.WELL_FED = ns.WELL_FED
D.FOOD_SPELLS = ns.FOOD_SPELLS

D.FLASKS = {
    items = { 13510, 13511, 13512, 13513 },
    auras = { 17626, 17627, 17628, 17629 },
}

D.ELIXIRS = {
    { stat = "Agility", items = { 13452, 9187 }, auras = { 17538, 11334 } },
    { stat = "Strength", items = { 13453, 9206 }, auras = { 17537, 11405 } },
    { stat = "Spell damage", items = { 13454, 9155 }, auras = { 17539, 11390 } },
    { stat = "Shadow Power", items = { 9264 }, auras = { 11474 } },
    { stat = "Holy Power", items = { 21546 }, auras = { 1310077 } },
    { stat = "Fire Power", items = { 6373 }, auras = { 7844 } },
    { stat = "Frost Power", items = { 17708 }, auras = { 21920 } },
    { stat = "Intellect", items = { 13447, 9179 }, auras = { 17535, 11396 } },
    { stat = "Armor", items = { 13445, 8951 }, auras = { 11348, 11349 } },
    { stat = "Mageblood", items = { 20007 }, auras = { 24363 } },
    { stat = "Major Troll's Blood", items = { 20004 }, auras = { 24361 } },
}

D.WEAPON_ITEMS = {
    20750, 20749, 20748, 20747, 20746, 20745, 20744, 23123, 3829, 3824,
    23122, 18262, 12404, 7964, 2871, 2863, 2862,
    12643, 7965, 3241, 3240, 3239,
}
D.WEAPON_ICON_ITEM = 2862
D.WEAPON_ICONS = {
    [20750] = "inv_potion_104", [20749] = "inv_potion_105", [20748] = "inv_potion_100",
    [20747] = "inv_potion_99", [20746] = "inv_potion_103", [20745] = "inv_potion_98",
    [20744] = "inv_poison_mindnumbing", [23123] = "inv_potion_26", [3829] = "inv_potion_20",
    [3824] = "inv_potion_23", [23122] = "inv_stone_sharpeningstone_02", [18262] = "inv_stone_02",
    [12404] = "inv_stone_sharpeningstone_05", [7964] = "inv_stone_sharpeningstone_04",
    [2871] = "inv_stone_sharpeningstone_03", [2863] = "inv_stone_sharpeningstone_02",
    [2862] = "inv_stone_sharpeningstone_01", [12643] = "inv_stone_weightstone_05",
    [7965] = "inv_stone_weightstone_04", [3241] = "inv_stone_weightstone_03",
    [3240] = "inv_stone_weightstone_02", [3239] = "inv_stone_weightstone_01",
}
for id, name in pairs(D.WEAPON_ICONS) do D.WEAPON_ICONS[id] = ICON_PATH .. name end

D.WORN = {
    { item = 273084, slot = 15, instance = 43, setting = "wornReminders" },
    { weapon = "Fishingpole", slot = 16, where = "fishingPoleWhere", setting = "fishingPoleReminder" },
}

D.SCROLLS = {
    { stat = "Agility", items = { 3012, 1477, 4425, 10309 }, auras = { 8115, 8116, 8117, 12174 } },
    { stat = "Intellect", items = { 955, 2290, 4419, 10308 }, auras = { 8096, 8097, 8098, 12176 }, raid = "intellect" },
    { stat = "Protection", items = { 3013, 1478, 4421, 10305 }, auras = { 8091, 8094, 8095, 12175 } },
    { stat = "Spirit", items = { 1181, 1712, 4424, 10306 }, auras = { 8112, 8113, 8114, 12177 }, raid = "spirit" },
    { stat = "Stamina", items = { 1180, 1711, 4422, 10307 }, auras = { 8099, 8100, 8101, 12178 }, raid = "stamina" },
    { stat = "Strength", items = { 954, 2289, 4426, 10310 }, auras = { 8118, 8119, 8120, 12179 } },
}

D.DEFAULT_GROUPS = { food = { items = {}, auras = {}, wellFed = true }, flask = { items = D.FLASKS.items, auras = D.FLASKS.auras },
    battle = { items = {}, auras = {} }, scroll = { items = {}, auras = {}, carried = true } }
for _, elixir in ipairs(D.ELIXIRS) do
    for _, id in ipairs(elixir.items) do table.insert(D.DEFAULT_GROUPS.battle.items, id) end
    for _, id in ipairs(elixir.auras) do table.insert(D.DEFAULT_GROUPS.battle.auras, id) end
end

D.RAID = {
    { key = "intellect", name = "Arcane Intellect", class = "MAGE", skip = { WARRIOR = true, ROGUE = true },
        spells = { 10157, 10156, 1461, 1460, 1459, 23028 } },
    { key = "stamina", name = "Power Word: Fortitude", class = "PRIEST",
        spells = { 10938, 10937, 2791, 1245, 1244, 1243, 21564, 21562 } },
    { key = "spirit", name = "Divine Spirit", class = "PRIEST", talent = true,
        skip = { WARRIOR = true, ROGUE = true },
        spells = { 27841, 14819, 14818, 14752, 27681 } },
    { key = "wild", name = "Mark of the Wild", class = "DRUID",
        spells = { 9885, 9884, 8907, 5234, 6756, 5232, 1126, 21850, 21849 } },
    { key = "blessing", name = "Paladin Blessings", class = "PALADIN",
        spells = { 25291, 19838, 19837, 19836, 19835, 19834, 19740, 25916, 25782,
            25290, 19854, 19853, 19852, 19850, 19742, 25918, 25894,
            20217, 25898, 19979, 19978, 19977, 25890 } },
    { key = "salvation", name = "Salvation", class = "PALADIN", skipTanks = true,
        spells = { 1038, 25895 } },
}

local raidSpells = {}
for _, family in ipairs(D.RAID) do raidSpells[family.key] = family.spells end
D.SCROLL_AURAS = {}
for _, scroll in ipairs(D.SCROLLS) do
    local auras = {}
    for _, id in ipairs(scroll.auras) do auras[#auras + 1] = id end
    for _, id in ipairs(raidSpells[scroll.raid] or {}) do auras[#auras + 1] = id end
    for _, id in ipairs(scroll.items) do
        D.SCROLL_AURAS[id] = auras
        table.insert(D.DEFAULT_GROUPS.scroll.items, id)
    end
end

D.PERSONAL = {
    { key = "demonArmor", name = "Demon Armor", class = "WARLOCK",
        spells = { 11735, 11734, 11733, 1086, 706, 696, 687, 403619 } },
    { key = "mageArmor", name = "Mage Armor", class = "MAGE",
        spells = { 22783, 22782, 6117, 10220, 10219, 7320, 7302, 7301, 7300, 168 } },
    { key = "poisons", name = "Poisons", class = "ROGUE", weapons = { 16, 17 }, spells = { 2842 } },
    { key = "battleShout", name = "Battle Shout", class = "WARRIOR",
        spells = { 25289, 11551, 11550, 11549, 6192, 5242, 6673 } },
    { key = "innerFire", name = "Inner Fire", class = "PRIEST",
        spells = { 10952, 10951, 1006, 602, 7128, 588 } },
    { key = "shadowform", name = "Shadowform", class = "PRIEST", spells = { 15473 } },
    { key = "aspect", name = "Aspect", class = "HUNTER", own = true,
        help = "Any aspect you cast yourself; another hunter's Pack or Wild does not count.",
        spells = { 25296, 14322, 14321, 14320, 14319, 14318, 13165, 13163, 5118, 13159,
            1299447, 1299446, 1299445, 13161, 20190, 20043 } },
    { key = "trueshot", name = "Trueshot Aura", class = "HUNTER",
        spells = { 20906, 20905, 19506, 1299348, 1299346 } },
    { key = "huntersMark", name = "Hunter's Mark on Elites", class = "HUNTER", target = true,
        help = "A hostile elite, rare elite or boss targeted out of combat without Hunter's Mark.",
        spells = { 14325, 14324, 14323, 1130 } },
    { key = "thorns", name = "Thorns", class = "DRUID", spells = { 9910, 9756, 8914, 1075, 782, 467 } },
    { key = "imbue", name = "Weapon Imbue", class = "SHAMAN", weapons = { 16 },
        spells = { 16362, 10486, 8235, 8232, 16342, 16341, 16339, 8030, 8027, 8024,
            16356, 16355, 10456, 8038, 8033, 16316, 16315, 16314, 10399, 8019, 8018, 8017 } },
    { key = "shield", name = "Lightning or Water Shield", class = "SHAMAN",
        spells = { 408510, 10432, 10431, 8134, 945, 905, 325, 324 } },
}

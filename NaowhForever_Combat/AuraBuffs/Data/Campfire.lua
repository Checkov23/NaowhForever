-- Campfire.lua: Forever's camp auras and each camp feature's bonus, by spell ID, for the Campfire reminder.
local ns = _G.NaowhForever

local D = {
    CAMP_BENEFITS = 1229741,
    CAMPFIRE_NEARBY = 1283391,
    WELCOMING_CAMPFIRE = 1229739,
    WELCOMING_CAMPFIRE_CRAFT = 1289723,
    WELL_RESTED = 429959,
}
ns.AuraBuffs.CampData = D

D.FEATURES = {
    { id = 1229451, tag = "+Rested", short = "Rested", name = "Camp Tent", stat = "Rested experience", points = 0,
      aliases = { "Tent", "Camp Tent", "Tanning Rack", "Sewing Machine" } },
    { id = 1230172, tag = "+STR", short = "Str", name = "Sharpening Wheel", stat = "Strength",
      amount = "+%s Strength", aliases = { "Sharpening Wheel", "Anvil", "Master Forge" } },
    { id = 1230124, tag = "+STA", short = "Sta", name = "First Aid Kit", stat = "Stamina", amount = "+%s Stamina",
      aliases = { "First Aid Kit", "Toxin Study", "Plague Doctor's Laboratory" } },
    { id = 1229513, tag = "+INT", short = "Int", name = "Incense Candle", stat = "Intellect",
      amount = "+%s Intellect", aliases = { "Incense Candle", "Greenhouse", "Seed Hybridizer" } },
    { id = 1229718, tag = "+Spirit", short = "Spi", name = "Faction Banner", stat = "Spirit", amount = "+%s Spirit",
      aliases = { "Faction Banner", "Spinning Wheel", "Loom" } },
    { id = 1230098, tag = "+Stats", short = "Stats", unit = "%", name = "Fish Bowl", stat = "All stats",
      amount = "+%s%% all stats", aliases = { "Fish Bowl", "Fishing Rack", "Fishing Hut" } },
    { id = 1230653, tag = "+MotW", short = "Armor", name = "Enchanted Lute", stat = "Armor, all stats and resistances",
      amount = "+%s Armor, +%s all stats, +%s resistances", points = 3, aliases = { "Enchanted Lute" } },
    { id = 1230164, tag = "+ATK", short = "AP", name = "Lodestone", stat = "Melee Attack Power",
      amount = "+%s Melee Attack Power", aliases = { "Lodestone", "Rock Garden", "Molten Foundry" } },
    { id = 1230552, tag = "+Spell", short = "SP", stat = "Spell damage and healing",
      amount = "+%s spell damage, +%s healing", points = 2 },
    { id = 1229519, tag = "+Crit", short = "Crit", unit = "%", name = "Camp Chair", stat = "Critical Strike",
      amount = "+%s%% Critical Strike", aliases = { "Camp Chair", "Trapper's Workbench", "Field Guide" } },
    { id = 1230587, tag = "+MP5", short = "MP5", name = "Mana Well", stat = "Mana every 5 sec",
      amount = "+%s Mana every %s sec", numbers = 2, period = 5,
      aliases = { "Mana Well", "Fermenter", "Alchemy Laboratory" } },
    { id = 1283701, tag = "+Disenchant", short = "Disenchant", name = "Arcane Salvager", stat = "Better disenchanting",
      points = 0 },
}

D.SAMPLE_BONUSES = { { D.FEATURES[1] }, { D.FEATURES[3], 56 }, { D.FEATURES[4], 25 }, { D.FEATURES[10], 2 } }

D.EFFECT_TAGS = {
    { "rested", "+Rested" }, { "rest experience", "+Rested" }, { "disenchant", "+Disenchant" },
    { "critical strike", "+Crit" }, { "spell damage", "+Spell" }, { "spell power", "+Spell" },
    { "armor", "+MotW" }, { "attack power", "+ATK" }, { "strength", "+STR" }, { "stamina", "+STA" },
    { "intellect", "+INT" }, { "spirit", "+Spirit" }, { "mana", "+MP5" }, { "mp5", "+MP5" },
    { "stats", "+Stats" },
}

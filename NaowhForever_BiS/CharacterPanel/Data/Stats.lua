-- Stats.lua: the stats the character panel lists for your spec, in order, and what each one does for your class (CP.Stats).
local ns = _G.NaowhForever

local CP = ns.CharacterPanel

local AGI_MELEE = ns.L("Attack power, ranged attack power, crit chance, armor and dodge.")
local STR_BLOCK = ns.L("Attack power and block value.")
local INT_NO_MANA = ns.L("Faster weapon skill gains.")
local SPI_NO_MANA = ns.L("Health back out of combat.")

CP.Stats = {
    ORDER = { "agi", "str", "int", "spi", "ap", "rap", "spell", "heal", "fire", "frost", "shadow",
        "nature", "arcane", "holy", "crit", "scrit", "hit", "shit", "haste", "dps", "mp5", "def", "dodge",
        "block", "sta", "armor" },
    ALWAYS = { sta = true, armor = true },
    SHORT = { rap = ns.L("Ranged AP"), mp5 = ns.L("Mana / 5 sec") },
    YARDSTICKS = { "agi", "str", "sta", "spell", "heal", "int", "ap" },
    HEADING = { agi = ns.L("VS AGI"), str = ns.L("VS STR"), sta = ns.L("VS STA"), spell = ns.L("VS SPELL"), heal = ns.L("VS HEAL"),
        int = ns.L("VS INT"), ap = ns.L("VS AP") },
    PERCENT = { hit = true, shit = true, crit = true, haste = true, scrit = true, dodge = true, block = true },
    DOES_BY_CLASS = {
        agi = {
            WARRIOR = ns.L("Ranged attack power, crit chance, armor and dodge."),
            ROGUE = AGI_MELEE,
            HUNTER = AGI_MELEE,
            DRUID = ns.L("Attack power in Cat Form, crit chance, armor and dodge."),
        },
        str = { WARRIOR = STR_BLOCK, PALADIN = STR_BLOCK, SHAMAN = STR_BLOCK },
        int = { WARRIOR = INT_NO_MANA, ROGUE = INT_NO_MANA },
        spi = { WARRIOR = SPI_NO_MANA, ROGUE = SPI_NO_MANA },
    },
    DOES = {
        agi = ns.L("Crit chance, armor and dodge."),
        str = ns.L("Attack power."),
        int = ns.L("Mana, spell crit chance and faster weapon skill gains."),
        spi = ns.L("Health back out of combat, and mana back while not casting."),
        ap = ns.L("More damage from your weapons."),
        rap = ns.L("More damage from your ranged weapon."),
        spell = ns.L("More damage from your spells."),
        heal = ns.L("More healing from your spells."),
        fire = ns.L("More damage from your Fire spells."),
        frost = ns.L("More damage from your Frost spells."),
        shadow = ns.L("More damage from your Shadow spells."),
        nature = ns.L("More damage from your Nature spells."),
        arcane = ns.L("More damage from your Arcane spells."),
        holy = ns.L("More damage from your Holy spells."),
        crit = ns.L("Chance for a hit to deal double damage."),
        scrit = ns.L("Chance for a spell to crit."),
        hit = ns.L("Chance not to miss: worth the most until you stop missing."),
        shit = ns.L("Chance for a spell not to miss: worth the most until you stop missing."),
        haste = ns.L("Faster attacks."),
        dps = ns.L("Your weapon's damage per second."),
        mp5 = ns.L("Mana back every 5 seconds, even while casting."),
        def = ns.L("Lowers the chance to be hit, crit and dazed."),
        dodge = ns.L("Chance to dodge a melee hit."),
        block = ns.L("Chance to block a hit with a shield."),
        sta = ns.L("Health."),
        armor = ns.L("Less physical damage taken."),
    },
}

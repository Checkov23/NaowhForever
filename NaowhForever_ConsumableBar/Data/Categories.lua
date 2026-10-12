-- Categories.lua: the kinds of consumable, by the game's subclass and by item ID (ns.ConsumableBar.Data).
local ns = _G.NaowhForever

local CB = ns.ConsumableBar

CB.Data = {
    ORDER = { "potion", "elixir", "flask", "scroll", "food", "bandage", "weapon",
        "healthstone", "explosive", "device", "other" },
    NAMES = { potion = "Potions", elixir = "Elixirs", flask = "Flasks", scroll = "Scrolls",
        food = "Food & Drink", bandage = "Bandages", weapon = "Weapon Enhancements",
        healthstone = "Healthstones", explosive = "Explosives", device = "Devices", other = "Other Consumables" },
    BY_SUBCLASS = { [1] = "potion", [2] = "elixir", [3] = "flask", [4] = "scroll",
        [5] = "food", [6] = "weapon", [7] = "bandage" },
    TRADE_GOODS = { [2] = "explosive", [3] = "device" },
    WEAPON = {
        [2862] = true, [2863] = true, [2871] = true, [7964] = true, [12404] = true, [18262] = true,
        [23122] = true,
        [3239] = true, [3240] = true, [3241] = true, [7965] = true, [12643] = true,
        [20744] = true, [20745] = true, [20746] = true, [20747] = true, [20748] = true, [20749] = true,
        [20750] = true, [23123] = true, [3824] = true, [3829] = true,
        [6947] = true, [6949] = true, [6950] = true, [8926] = true, [8927] = true, [8928] = true,
        [2892] = true, [2893] = true, [8984] = true, [8985] = true, [20844] = true, [3775] = true,
        [3776] = true, [5237] = true, [6951] = true, [9186] = true, [10918] = true, [10920] = true,
        [10921] = true, [10922] = true,
    },
    SCROLLS = {
        [3012] = true, [1477] = true, [4425] = true, [10309] = true,
        [955] = true, [2290] = true, [4419] = true, [10308] = true,
        [3013] = true, [1478] = true, [4421] = true, [10305] = true,
        [1181] = true, [1712] = true, [4424] = true, [10306] = true,
        [1180] = true, [1711] = true, [4422] = true, [10307] = true,
        [954] = true, [2289] = true, [4426] = true, [10310] = true,
    },
}

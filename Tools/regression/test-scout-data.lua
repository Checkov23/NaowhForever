-- Run with Lua 5.1 from the repository root: Scout's generated data (NaowhForever_QoL/Combat/ScoutData.lua),
-- unpacked the way the client does (Tools/regression/encoding_util.lua stands in for C_EncodingUtil). The
-- abilities, the tameable beasts and each creature's stats come back as plain lists of numbers, a few known
-- creatures have the abilities and stats the game's database gives them and none of the spells the scripts wrongly
-- put on creatures, and the armor by level is the game's ExpectedStat: one value for each of the 63 levels, level
-- 63 at classic's raid boss 3731. Missing instance abilities also use cached Journal pages and reviewed numeric
-- records; missing creature stats remain unknown rather than being inferred from those ability lists.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local HOGGER, BROKEN_TOOTH, RAGNAROS, RAZORMANE_MYSTIC, SPRINGVALE, BOAR = 448, 2850, 11502, 3271, 4278, 3098
local PIERCE_ARMOR, HEAD_BUTT, MEATHOOK, DAZED = 6016, 6730, 403233, 1604
local CAMP_BENEFITS, BOOSTED_REST = 1229741, 1229451
local ARMOR, SCHOOLS_IMMUNE, MECHANICS_IMMUNE, FIRE_SCHOOL, STUN_BIT, FEAR_BIT = 1, 2, 3, 4, 12, 5
local PACKED_MAX = 600 * 1024
local MIN_CREATURES, MIN_STATS, MIN_TAMEABLE = 3000, 4500, 400
local STAT_FIELDS = 9

local ns = {}
local env = setmetatable({ NaowhForever = ns, C_EncodingUtil = dofile("Tools/regression/encoding_util.lua")() },
    { __index = _G })
env._G = env
local chunk = assert(loadfile("NaowhForever_QoL/Combat/ScoutData.lua"))
setfenv(chunk, env)
chunk()

local function Unpack(packed)
    local u = env.C_EncodingUtil
    return u.DeserializeCBOR(u.DecompressString(u.DecodeBase64(packed), 0))
end

local function Ascii(s) return type(s) == "string" and not s:find("[\128-\255]") end
check("the three lists ship as ASCII strings, small enough", Ascii(ns.ScoutAbilitiesPacked)
    and Ascii(ns.ScoutTameablePacked) and Ascii(ns.ScoutStatsPacked)
    and #ns.ScoutAbilitiesPacked + #ns.ScoutTameablePacked + #ns.ScoutStatsPacked < PACKED_MAX)

local flat = Unpack(ns.ScoutAbilitiesPacked)
check("the abilities unpack to a creature ID and its spells, pair by pair", type(flat) == "table" and #flat % 2 == 0)
local abilities, creatures, valid = {}, 0, true
for i = 1, #flat, 2 do
    local npc, spells = flat[i], flat[i + 1]
    abilities[npc] = spells
    creatures = creatures + 1
    if type(npc) ~= "number" or type(spells) ~= "table" or #spells == 0 then valid = false end
    for _, spell in ipairs(spells) do
        if type(spell) ~= "number" or spell <= 0 or spell == MEATHOOK then valid = false end
    end
end
check("every creature has a list of real spell IDs, and none is Meathook", valid)
check(("many creatures have abilities (%d)"):format(creatures), creatures >= MIN_CREATURES)

local function Has(list, spell)
    for _, id in ipairs(list or {}) do if id == spell then return true end end
    return false
end
check("Hogger has Pierce Armor and Head Butt", Has(abilities[HOGGER], PIERCE_ARMOR) and Has(abilities[HOGGER], HEAD_BUTT))
check("a shaman creature has a shaman's spells", Has(abilities[RAZORMANE_MYSTIC], 547) and Has(abilities[RAZORMANE_MYSTIC], 324))
check("a paladin boss has Holy Light and Hammer of Justice", Has(abilities[SPRINGVALE], 1026)
    and Has(abilities[SPRINGVALE], 5588))
check("Dalaran's final boss has the reported orb and mana-reset spells", Has(abilities[246020], 1241515)
    and Has(abilities[246020], 1303598) and Has(abilities[246020], 1303599))
check("Classic reflection and hatcher casts survive the offline build", Has(abilities[8923], 9941)
    and Has(abilities[10683], 15572) and Has(abilities[10683], 15580)
    and not Has(abilities[10683], 15746))
check("encounter adds retain their passive damage abilities", Has(abilities[16427], 28458)
    and Has(abilities[16429], 28460) and Has(abilities[16290], 28156))
check("the arena healer retains its support spells", Has(abilities[16055], 17138)
    and Has(abilities[16055], 20697) and Has(abilities[16055], 23895))
check("the diseased maggot's plague is not assigned to the rotting variant", Has(abilities[16056], 30079)
    and not Has(abilities[16057], 30079))
check("Dazed and the campfire buffs guards carry are left out wherever they appeared", (function()
    for _, spells in pairs(abilities) do
        if Has(spells, DAZED) or Has(spells, CAMP_BENEFITS) or Has(spells, BOOSTED_REST) then return false end
    end
    return true
end)())
check("a spell is listed once for each name: Frost Armor's ranks are one spell", (function()
    for _, spells in pairs(abilities) do
        if Has(spells, 168) and Has(spells, 12544) then return false end
    end
    return true
end)())

local tame = Unpack(ns.ScoutTameablePacked)
check("the tameable beasts unpack under key 0", type(tame) == "table" and tame[1] == 0 and type(tame[2]) == "table")
local tameable = {}
for _, npc in ipairs(tame[2]) do tameable[npc] = true end
check(("many beasts can be tamed (%d)"):format(#tame[2]), #tame[2] >= MIN_TAMEABLE)
check("Broken Tooth can be tamed", tameable[BROKEN_TOOTH])
check("Hogger and Ragnaros cannot", not tameable[HOGGER] and not tameable[RAGNAROS])
check("a boar can", tameable[BOAR])

local numbers = Unpack(ns.ScoutStatsPacked)
check("the stats unpack to a creature ID and its numbers, pair by pair", type(numbers) == "table" and #numbers % 2 == 0)
local stats, withStats, shaped = {}, 0, true
for i = 1, #numbers, 2 do
    local npc, row = numbers[i], numbers[i + 1]
    stats[npc] = row
    withStats = withStats + 1
    if type(row) ~= "table" or #row ~= STAT_FIELDS then shaped = false end
    for _, value in ipairs(row) do
        if type(value) ~= "number" or value < 0 then shaped = false end
    end
end
check("previously skipped bosses and guards have their database stats", stats[9019] and stats[9502]
    and stats[12129] and Has(abilities[12129], 18958))
check("every creature's stats are nine numbers: armor, immunities, six resistances", shaped)
check(("most creatures have stats (%d)"):format(withStats), withStats >= MIN_STATS)
check("Hogger's own armor is 538", stats[HOGGER][ARMOR] == 538)
check("Broken Tooth's is 1593, a boar's 16", stats[BROKEN_TOOTH][ARMOR] == 1593 and stats[BOAR][ARMOR] == 16)
check("Ragnaros's is 4691, more than a level 63's expected 3731", stats[RAGNAROS][ARMOR] == 4691)
check("Ragnaros is immune to fire", stats[RAGNAROS][SCHOOLS_IMMUNE] == FIRE_SCHOOL)
local mechanics = stats[RAGNAROS][MECHANICS_IMMUNE]
check("and to stuns and fears", mechanics % 2 ^ STUN_BIT >= 2 ^ (STUN_BIT - 1) and mechanics % 2 ^ FEAR_BIT >= 2 ^ (FEAR_BIT - 1))
check("Hogger is immune to nothing", stats[HOGGER][SCHOOLS_IMMUNE] == 0 and stats[HOGGER][MECHANICS_IMMUNE] == 0)

check("armor is one value for each of the 63 levels", #ns.ScoutArmor == 63)
local rising = true
for level = 2, 63 do
    if type(ns.ScoutArmor[level]) ~= "number" or ns.ScoutArmor[level] < ns.ScoutArmor[level - 1] then rising = false end
end
check("and never drops from one level to the next", rising)
check("level 1, 11 and 60 are the game's 20, 545 and 3566", ns.ScoutArmor[1] == 20 and ns.ScoutArmor[11] == 545
    and ns.ScoutArmor[60] == 3566)
check("level 63, a raid boss, is classic's 3731", ns.ScoutArmor[63] == 3731)

print(("test-scout-data: %d checks passed"):format(checks))

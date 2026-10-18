-- Run with Lua 5.1 from the repository root: the rules that decide who gets which blessing. A tank is
-- the Tank role or a Main Tank mark; tanks and Main Assists can get their own blessing in place of the
-- class one, but never over a player's own choice; Smart Blessings leaves out a blessing a class has no
-- use for; the bench is the raid groups past a raid dungeon's size.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local settings = { blessTank = "none", blessAssist = "none", blessSmart = false, blessBench = false }
local store = { players = {}, classes = { WARRIOR = "kings", DRUID = "wisdom", MAGE = "wisdom" } }
local learned = { might = true, kings = true, wisdom = true, light = true }
local roles, marks, raid, instance = {}, {}, true, { "Dungeon", "raid", 14, 0, 40 }
local B = {
    Secret = function(v) return v == "SECRET" end,
    Settings = { Get = function(key) return settings[key] end },
    Store = function() return store end,
    BY_KEY = { might = { key = "might" }, kings = { key = "kings" }, wisdom = { key = "wisdom" },
        light = { key = "light" }, salvation = { key = "salvation" } },
    Learned = function(entry) return learned[entry.key] end,
}
local env = setmetatable({
    NaowhForever = { Blessings = B },
    UnitGroupRolesAssigned = function(unit) return roles[unit] or "NONE" end,
    GetPartyAssignment = function(kind, unit) return marks[kind .. unit] end,
    IsInRaid = function() return raid end,
    GetInstanceInfo = function() return unpack(instance) end,
}, { __index = _G })
env._G = env
local chunk = assert(loadfile("NaowhForever_Combat/Blessings/Group.lua"))
setfenv(chunk, env)
chunk("NaowhForever", env.NaowhForever)

local function Member(unit, class, guid)
    return { unit = unit, class = class, guid = guid or unit }
end
local warrior, druid, mage = Member("raid1", "WARRIOR"), Member("raid2", "DRUID"), Member("raid3", "MAGE")

check("no role and no mark: not a tank", B.IsTank("raid1") == false)
roles.raid1 = "TANK"
check("the Tank role", B.IsTank("raid1") == true)
roles.raid1 = "SECRET"
check("a hidden role is not a tank", B.IsTank("raid1") == false)
roles.raid1 = nil
marks["MAINTANKraid1"] = true
check("a Main Tank mark", B.IsTank("raid1") == true)
marks["MAINTANKraid1"] = nil

check("the class blessing by default", B.Assigned(warrior) == "kings" and B.Assigned(mage) == "wisdom")
settings.blessTank = "might"
check("a tank rule changes nothing for a player who is not a tank", B.Assigned(warrior) == "kings")
roles.raid1 = "TANK"
check("a tank gets it in place of the class blessing", B.Assigned(warrior) == "might")
roles.raid3 = "TANK"
check("but only a class that can tank", B.Assigned(mage) == "wisdom")
store.players.raid1 = "light"
check("and never over a player's own choice", B.Assigned(warrior) == "light")
store.players.raid1 = nil
learned.might = false
check("a blessing you have not learned is not given", B.Assigned(warrior) == "kings")
learned.might = true

settings.blessTank = "none"
settings.blessAssist = "wisdom"
marks["MAINASSISTraid2"] = true
check("a Main Assist gets the assist blessing", B.Assigned(druid) == "wisdom")
store.classes.DRUID = "kings"
check("in place of the class blessing", B.Assigned(druid) == "wisdom")
settings.blessTank, roles.raid2 = "might", "TANK"
check("a tank who is also Main Assist gets the tank blessing", B.Assigned(druid) == "might")
settings.blessTank, settings.blessAssist = "none", "none"

check("without Smart Blessings anything goes", B.Allowed("WARRIOR", "wisdom") and B.Allowed("MAGE", "might"))
settings.blessSmart = true
check("Smart: no Wisdom for warriors and rogues", not B.Allowed("WARRIOR", "wisdom") and not B.Allowed("ROGUE", "wisdom"))
check("Smart: no Might for priests, mages and warlocks", not B.Allowed("MAGE", "might")
    and not B.Allowed("WARLOCK", "might") and not B.Allowed("PRIEST", "might"))
check("Smart: the rest are fine", B.Allowed("WARRIOR", "might") and B.Allowed("MAGE", "wisdom")
    and B.Allowed("HUNTER", "might") and B.Allowed("PALADIN", "kings"))

local roster = {}
for i = 1, 40 do roster[i] = { unit = "raid" .. i, subgroup = math.ceil(i / 5) } end
check("the bench is shown unless hidden", #B.Visible(roster) == 40)
settings.blessBench = true
check("a raid of 40: everyone is in a usual group", #B.Visible(roster) == 40)
instance = { "Dungeon", "raid", 14, 0, 10 }
local shown = B.Visible(roster)
check("a raid of 10: groups 1 and 2 stay", #shown == 10 and shown[10].subgroup == 2)
roster[11].subgroup = nil
check("a player with no known group stays", #B.Visible(roster) == 11)
instance = { "Dungeon", "party", 1, 0, 5 }
check("outside a raid dungeon nothing is benched", #B.Visible(roster) == 40)
raid = false
instance = { "Dungeon", "raid", 14, 0, 10 }
check("in a party nothing is benched", #B.Visible(roster) == 40)

print(("test-blessing-rules: %d checks passed"):format(checks))

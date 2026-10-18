-- Run with Lua 5.1 from the repository root: Blessings Auto-Assign. One blessing per paladin per
-- class, never the same blessing twice in a class, nothing a paladin has not learned, the most
-- wanted blessings first, one aura each, and a paladin who knows little is served before one who
-- knows everything. Salvation is no class blessing: one paladin who knows it gives it to the group.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local f = assert(io.open("NaowhForever_Combat/Blessings/AutoAssign.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n")
f:close()
local first = assert(source:find("local WANTED = {", 1, true))
local last = assert(source:find("local function ApplyPlans(plans)", first, true))
local chunk = source:sub(first, last - 1) .. "return AutoPlans"

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local mine = {}
local others = {}
local roster = { { class = "PALADIN", unit = "player" } }
local env = {
    B = { Roster = function() return roster end },
    CLASSES = CLASSES,
    SALVATION = { key = "salvation" },
    BLESSINGS = { { key = "might" }, { key = "wisdom" }, { key = "kings" }, { key = "light" } },
    AURAS = { { key = "devotion" }, { key = "retribution" }, { key = "concentration" } },
    IsPaladin = function() return true end,
    Learned = function(entry) return mine[entry.key] end,
    MyName = function() return "Glyadin Skywolf" end,
}
env.others = others
local fn = assert(loadstring(chunk))
setfenv(fn, setmetatable(env, { __index = _G }))
local AutoPlans = fn()

local function Set(...)
    local t = {}
    for _, k in ipairs({ ... }) do t[k] = true end
    return t
end

-- You know everything; another paladin knows only Might and Devotion.
mine = Set("might", "wisdom", "kings", "salvation", "light", "devotion", "retribution", "concentration")
others["Bram Hollow"] = { known = Set("might", "devotion") }
local plans = AutoPlans()
local me, bram = plans["Glyadin Skywolf"], plans["Bram Hollow"]
check("the paladin who knows only Might gives warriors Might", bram.classes.WARRIOR == "might")
check("you then give warriors the next one, Kings", me.classes.WARRIOR == "kings")
check("the scarce paladin gets the only aura they know", bram.aura == "devotion")
check("you get the next aura", me.aura == "retribution")

for _, class in ipairs(CLASSES) do
    local a, b = me.classes[class], bram.classes[class]
    check(class .. ": never the same blessing twice", not (a and b and a == b))
    check(class .. ": nothing the other paladin has not learned", b == nil or b == "might")
    check(class .. ": Salvation is not a class blessing", a ~= "salvation" and b ~= "salvation")
end

check("Salvation goes to the paladin who knows it", me.salv == true and bram.salv == nil)
check("a lone paladin gives mages Wisdom, in a party or a raid", plans["Glyadin Skywolf"].classes.MAGE == "wisdom")

-- Two paladins who both know Salvation: the one who knows less gives it, once.
others["Bram Hollow"] = { known = Set("might", "wisdom", "kings", "salvation", "light", "devotion") }
roster = { { class = "PALADIN", unit = "player" }, { class = "PALADIN", unit = "party1" },
    { class = "MAGE", unit = "party2" } }
plans = AutoPlans()
check("two paladins: the paladin who knows less gives Salvation", plans["Bram Hollow"].salv == true
    and plans["Glyadin Skywolf"].salv == nil)
check("two paladins: the class blessings are unchanged by it", plans["Bram Hollow"].classes.PALADIN == "wisdom"
    and plans["Glyadin Skywolf"].classes.PALADIN == "kings")

-- Nobody knows Salvation: nobody is given it.
mine.salvation, others["Bram Hollow"].known.salvation = nil, nil
plans = AutoPlans()
check("nobody knows Salvation: nobody gives it", plans["Glyadin Skywolf"].salv == nil
    and plans["Bram Hollow"].salv == nil)

print(("test-blessing-autoassign: %d checks passed"):format(checks))

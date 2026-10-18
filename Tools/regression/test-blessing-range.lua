-- Run with Lua 5.1 from the repository root: a Blessings class button lights up (glow, red) only
-- for members in range who are missing their blessing or running out. Someone across the zone
-- without it, with everyone nearby blessed, must not light it.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local f = assert(io.open("NaowhForever_Combat/Blessings/Buffs.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n")
f:close()
local first = assert(source:find("local function InRange(member, spell)", 1, true))
local last = assert(source:find("local function Due(member, key, spell)", first, true))
local chunk = source:sub(first, last - 1) .. "return Survey, SalvationGroup, SalvationSurvey"

-- unit -> { has buff, seconds left, IsSpellInRange answer }
local state = {}
local players = {}   -- guid -> a player's own blessing
local castSpell = 19740
local roles, symbols = {}, 0
local SALV = { key = "salvation", ranks = { 1038 }, greater = { 25895 } }
local env = {
    B = { SALVATION = SALV, CLASSES = { "WARRIOR", "MAGE", "PRIEST" } },
    HighestKnown = function(ids) return ids[#ids] end,
    SYMBOL_OF_KINGS = 21177,
    C_Item = { GetItemCount = function() return symbols end },
    UnitGroupRolesAssigned = function(unit) return roles[unit] or "NONE" end,
    EXPIRING = 300,
    Secret = function() return false end,
    Assigned = function() return "might" end,
    Store = function() return { players = players } end,
    CastSpell = function() return castSpell end,
    GREATER = { [25782] = true, [25895] = true },
    BuffState = function(unit) return state[unit][1], state[unit][2] end,
    UnitGUID = function(unit) return unit == "player" and "me" or unit end,
    UnitIsConnected = function() return true end,
    UnitIsDeadOrGhost = function() return false end,
    UnitIsVisible = function() return true end,
    C_Spell = { IsSpellInRange = function(_, unit) return state[unit][3] end },
}
local fn = assert(loadstring(chunk))
setfenv(fn, setmetatable(env, { __index = _G }))
local Survey, SalvationGroup, SalvationSurvey = fn()

local function Member(unit) return { unit = unit, guid = unit, names = unit, targetable = true } end
local members = { Member("party1"), Member("party2") }

state = { party1 = { true, 3000, true }, party2 = { false, nil, false } }
local s = Survey(members)
check("one missing, but out of range: counted as missing", s.missing == 1)
check("nobody in range is missing it", s.missingNear == 0 and s.expiringNear == 0)
check("the blessed one in range is still a target", s.reachable and s.target == members[1])

state = { party1 = { true, 3000, true }, party2 = { false, nil, nil } }
s = Survey(members)
check("no range answer: does not light the button", s.missing == 1 and s.missingNear == 0)
check("no range answer: still left to the cast", s.target == members[2])

state = { party1 = { true, 3000, true }, party2 = { false, nil, true } }
s = Survey(members)
check("missing and in range: lights the button and is the target", s.missingNear == 1 and s.target == members[2])

state = { party1 = { true, 120, true }, party2 = { true, 3000, true } }
s = Survey(members)
check("running out in range counts as expiring, not missing", s.missingNear == 0 and s.expiringNear == 1)

-- The click queue: those in range who need it, most urgent first; the buffed and the out of
-- range left out.
state = { party1 = { true, 1500, true }, party2 = { false, nil, true }, party3 = { true, 200, true },
    party4 = { false, nil, false } }
members[3] = Member("party3")
members[4] = Member("party4")
local queue = Survey(members).queue
check("queue: missing, then running out, nobody already blessed", #queue == 2 and queue[1].names == "party2"
    and queue[2].names == "party3")

state = { party1 = { true, 1500, true }, party2 = { true, 2500, true }, party3 = { true, 3000, true },
    party4 = { true, 900, false } }
queue = Survey(members).queue
check("queue: with nobody due, the one in range with least left", #queue == 1 and queue[1].names == "party1")

castSpell = 25782
state = { party1 = { false, nil, true }, party2 = { false, nil, true }, party3 = { true, 200, true },
    party4 = { false, nil, false } }
queue = Survey(members).queue
check("queue: a Greater Blessing is cast once for the class", #queue == 1)
castSpell = 19740

-- Colour counts: a player on their own blessing does not make the class button red.
state = { party1 = { true, 1500, true }, party2 = { false, nil, true }, party3 = { true, 200, true },
    party4 = { false, nil, false } }
players = { party2 = "kings" }
s = Survey(members)
check("only the class blessing's members count for red and yellow", s.classDue == 1 and s.classMissing == 0)

-- A member the group header cannot find by name never enters the click queue.
players = {}
members[2].targetable = false
queue = Survey(members).queue
check("queue: a member the header cannot find is left out", queue[1].names == "party3")
members[2].targetable = true

-- Salvation: everyone but tanks, a Greater one once for a class with no tank and two who need it.
local function Of(unit, class)
    local m = Member(unit)
    m.class = class
    return m
end
local roster = { Of("party1", "WARRIOR"), Of("party2", "WARRIOR"), Of("party3", "MAGE"), Of("party4", "MAGE"),
    Of("party5", "MAGE") }
roles.party1 = "TANK"
local group, tankClass = SalvationGroup(roster)
check("salvation: a tank is left out and marks its class", #group == 4 and tankClass.WARRIOR and not tankClass.MAGE)
roles.party1 = nil
group, tankClass = SalvationGroup(roster)
check("salvation: with no tank everyone is in", #group == 5 and next(tankClass) == nil)

roles.party1 = "TANK"
group, tankClass = SalvationGroup(roster)
symbols = 3
state = { party2 = { false, nil, true }, party3 = { false, nil, true }, party4 = { false, nil, true },
    party5 = { true, 3000, true } }
local all = SalvationSurvey(group, tankClass)
local warriorSpell
for _, entry in ipairs(all.queue) do if entry.names == "party2" then warriorSpell = entry.spell end end
check("salvation: a class with a tank gets single Salvation", warriorSpell == 1038)
local greaters = 0
for _, entry in ipairs(all.queue) do if entry.spell == 25895 then greaters = greaters + 1 end end
check("salvation: a class with no tank and two who need it gets one Greater", greaters == 1)
check("salvation: counts add up over the classes", all.missing == 3 and all.missingNear == 3 and all.reachable)
check("salvation: a target is chosen", all.target ~= nil and all.spell ~= nil)

state = { party2 = { true, 3000, true }, party3 = { false, nil, true }, party4 = { true, 3000, true },
    party5 = { true, 3000, true } }
all = SalvationSurvey(group, tankClass)
check("salvation: one who needs it in a class with no tank gets the single one", #all.queue == 1
    and all.queue[1].spell == 1038)
symbols = 0
state = { party2 = { false, nil, true }, party3 = { false, nil, true }, party4 = { false, nil, true },
    party5 = { false, nil, true } }
all = SalvationSurvey(group, tankClass)
local anyGreater = false
for _, entry in ipairs(all.queue) do if entry.spell == 25895 then anyGreater = true end end
check("salvation: no Symbol of Kings, no Greater", not anyGreater and #all.queue == 4)

print(("test-blessing-range: %d checks passed"):format(checks))

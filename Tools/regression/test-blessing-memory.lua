-- Run with Lua 5.1 from the repository root: where the game hides other players' auras
-- (battlegrounds and arenas) the bar remembers the blessings you cast and counts them down. A cast
-- counts once that cast lands, a Greater one for the whole class, a death forgets it, an aura has no end,
-- and elsewhere an unreadable aura stays unknown instead of missing.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local now, kind, secret = 1000, "pvp", true
local dead = {}
local classOf = { a = "MAGE", b = "MAGE", c = "WARRIOR", me = "PALADIN" }
local roster = {}
for _, unit in ipairs({ "a", "b", "c", "me" }) do
    roster[#roster + 1] = { unit = unit, guid = "G-" .. unit, class = classOf[unit] }
end
local B = {
    Secret = function(v) return v == "SECRET" end,
    BY_KEY = { kings = { blessing = true }, salvation = { salvation = true }, devotion = {} },
    FAMILY = { [20217] = "kings", [25898] = "kings", [1038] = "salvation", [465] = "devotion" },
    GREATER = { [25898] = true },
    Roster = function() return roster end,
}
local env = setmetatable({
    NaowhForever = { Blessings = B },
    IsInInstance = function() return true, kind end,
    UnitGUID = function(unit) return "G-" .. unit end,
    UnitIsUnit = function(a, b) return a == b end,
    UnitIsDeadOrGhost = function(unit) return dead[unit] or false end,
    GetTime = function() return now end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end end,
}, { __index = _G })
env._G = env
local chunk = assert(loadfile("NaowhForever_Combat/Blessings/Memory.lua"))
setfenv(chunk, env)
chunk("NaowhForever", env.NaowhForever)

check("battlegrounds and arenas hide auras", B.HiddenAuras())
kind = "party"
check("a dungeon does not", not B.HiddenAuras())
kind = "pvp"

-- A click notes its cast only when the game sent one in the same frame, keyed by the cast's GUID.
local castN = 0
local function Click(unit, spell)
    castN = castN + 1
    local id = "Cast-" .. castN
    B.CastSent(id, spell)
    B.NoteCast(unit, spell)
    return id
end

check("nothing remembered at first", B.Remembered("a", "kings") == false)
local id = Click("a", 20217)
check("a cast that has not landed is not remembered", B.Remembered("a", "kings") == false)
B.CastDone("Cast-other")
check("another cast landing does not count", B.Remembered("a", "kings") == false)
B.CastDone(id)
local has, left = B.Remembered("a", "kings")
check("a single blessing is remembered for an hour", has and left == 3600)
check("only the one who got it", B.Remembered("b", "kings") == false)
now = now + 600
has, left = B.Remembered("a", "kings")
check("and counts down", has and left == 3000)
now = now + 3000
check("then it runs out", B.Remembered("a", "kings") == false)

now = 1000
B.CastDone(Click("a", 25898))
check("a Greater blessing is remembered for the whole class", B.Remembered("a", "kings") and B.Remembered("b", "kings"))
check("and not for other classes", B.Remembered("c", "kings") == false)
dead.b = true
check("a death forgets it", B.Remembered("b", "kings") == false)
dead.b = false
check("and it stays forgotten", B.Remembered("b", "kings") == false)
B.ForgetIfDead("a")
check("a living player keeps it", B.Remembered("a", "kings") == true)
dead.a = true
B.ForgetIfDead("a")
dead.a = false
check("a death seen on a health update forgets it, though they are back up when asked",
    B.Remembered("a", "kings") == false)

B.CastDone(Click("c", 1038))
check("Salvation is remembered like a blessing", select(2, B.Remembered("c", "salvation")) == 3600)

B.CastDone(Click("me", 465))
has, left = B.Remembered("me", "devotion")
check("an aura has no end", has and left == nil)
now = now + 100000
check("and is still there", B.Remembered("me", "devotion") == true)

id = Click("a", 20217)
now = now + 6
B.CastDone(id)
check("a cast that lands long after the click is not matched", B.Remembered("a", "kings") == false)

id = Click("a", 20217)
B.NoteCast("b", 20217)
B.CastDone(id)
check("a second click that cast nothing does not take over the first cast",
    B.Remembered("a", "kings") == true and B.Remembered("b", "kings") == false)
B.ForgetCasts()

B.CastSent("Cast-bar", 20217)
now = now + 1
B.NoteCast("b", 20217)
B.CastDone("Cast-bar")
check("a cast sent in an earlier frame is not this click's", B.Remembered("b", "kings") == false)

Click("a", 20217)
kind = "party"
id = Click("b", 20217)
B.CastDone(id)
check("outside a battleground clicks are not noted", B.Remembered("b", "kings") == false)
kind = "pvp"
B.CastDone(Click("c", 1038))
id = Click("a", 20217)
B.ForgetCasts()
B.CastDone(id)
check("leaving forgets everything", B.Remembered("a", "kings") == false and B.Remembered("c", "salvation") == false)
B.CastDone(Click("zzz", 20217))
check("a unit that is not in the group is ignored", B.Remembered("zzz", "kings") == false)

-- Buffs.lua asks the memory only where auras are hidden.
local f = assert(io.open("NaowhForever_Combat/Blessings/Buffs.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n")
f:close()
local first = assert(source:find("local function BuffState(unit, key)", 1, true))
local last = assert(source:find("local function InRange(member, spell)", first, true))
local state = setmetatable({
    B = B, Secret = B.Secret, FAMILY = B.FAMILY, MAX_AURAS = 40, memoAt = nil, memo = {}, scratch = {},
    Found = function(v) if v == true then return true end return true, v - now end,
    C_Secrets = { ShouldAurasBeSecret = function() return secret end },
    C_UnitAuras = { GetAuraDataByIndex = function() return nil end },
}, { __index = env })
local fn = assert(loadstring(source:sub(first, last - 1) .. "return BuffState"))
setfenv(fn, state)
local BuffState = fn()
now = 1000
B.CastDone(Click("a", 20217))
check("hidden auras in a battleground: what you cast", select(1, BuffState("a", "kings")) == true)
check("and what you did not is missing", BuffState("b", "kings") == false)
kind = "party"
check("hidden elsewhere: unknown, not missing", BuffState("b", "kings") == nil)
secret = false
check("readable auras are read", BuffState("b", "kings") == false)

print(("test-blessing-memory: %d checks passed"):format(checks))

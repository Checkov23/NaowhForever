-- Run with Lua 5.1 from the repository root: learning lifts. Standing still while the ground carries you up or
-- down is a lift: its two ends and the seconds it took are kept, and the same lift ridden again is merged. A ride
-- that drifts sideways (a boat, a zeppelin), a fall, a flight, or moving yourself is not one. /nf lifts lists
-- what was learned and "clear" forgets it; with Learn Lifts as You Ride off, nothing is watched.
local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local now, here = 0, { c = 1, x = 0, y = 0, z = 0 }
local falling = false
local settings = { learnLifts = true }
local store, printed = {}, {}
local frame, ticks

local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Print = function(msg) printed[#printed + 1] = msg end, AccountSettings = function() return store end }
local env = setmetatable({
    NaowhForever = ns,
    hooksecurefunc = function() end,
    GetTime = function() return now end,
    GetSubZoneText = function() return here.z < 30 and "The Base" or "The Rise" end,
    GetZoneText = function() return "Mulgore" end,
    IsFalling = function() return falling end,
    IsFlying = function() return false end,
    IsSwimming = function() return false end,
    UnitOnTaxi = function() return false end,
    C_Timer = { NewTicker = function(_, fn)
        ticks = { fn = fn, cancelled = false }
        ticks.Cancel = function(t) t.cancelled = true end
        return ticks
    end },
    CreateFrame = function()
        frame = { events = {}, scripts = {} }
        frame.SetScript = function(f, k, fn) f.scripts[k] = fn end
        frame.RegisterEvent = function(f, e) f.events[e] = true end
        frame.UnregisterAllEvents = function(f) f.events = {} end
        return frame
    end,
}, { __index = _G })
env._G = env

ns.Journeys = {
    On = function() return true end,
    Settings = { Get = function(key) return settings[key] end, OnChange = function() end },
    World = { Player = function() return { c = here.c, x = here.x, y = here.y, z = here.z } end },
}
for _, path in ipairs({ "NaowhForever_Journeys/Constants.lua", "NaowhForever_Journeys/Lifts.lua" }) do
    local chunk = assert(loadstring(Read(path), path))
    setfenv(chunk, env)
    chunk()
end
local Jy = ns.Journeys

local function Fire(event)
    frame.scripts.OnEvent(frame, event)
end

local function Tick(z, x)
    now = now + 1
    here.z = z
    if x then here.x = x end
    if not ticks.cancelled then ticks.fn() end
end

-- Stand at the bottom, wait three seconds, rise four yards a second to 60, stop at 62.
local function Ride(from, x0)
    here.x, here.y, here.z = x0 or 0, 0, from
    Fire("PLAYER_STOPPED_MOVING")
    for _ = 1, 3 do Tick(from) end
    for k = 1, 15 do Tick(from + 4 * k) end
    Tick(from + 62)
    Tick(from + 62)
    Tick(from + 62)
end

Check(frame.events.PLAYER_STARTED_MOVING and frame.events.PLAYER_STOPPED_MOVING, "watching your movement when on")
local list = store.journeyLifts
Check(list == nil, "nothing learned yet")

now = 0
Ride(0)
list = store.journeyLifts
Check(list and #list == 1, "one lift learned")
local lift = list[1]
Check(lift.c == 1 and lift.low.z == 0 and lift.high.z == 62, "its two ends, low and high")
Check(lift.low.place == "The Base" and lift.high.place == "The Rise", "with the places at each")
Check(lift.seconds == 15 and lift.n == 1, "and how long it took: " .. lift.seconds)
Check(ticks.cancelled, "the watching stops when the ride is over")

Ride(0)
Check(#store.journeyLifts == 1 and store.journeyLifts[1].n == 2, "the same lift again is merged, not added")
Ride(0, 200)
Check(#store.journeyLifts == 2, "a lift elsewhere is another")

local before = #store.journeyLifts
here.x, here.y, here.z = 0, 0, 0
Fire("PLAYER_STOPPED_MOVING")
Tick(0)
Tick(10, 40)
Tick(30, 80)
Check(ticks.cancelled and #store.journeyLifts == before, "a ride that drifts sideways is not a lift")

here.x, here.y, here.z = 0, 0, 0
local last = ticks
falling = true
Fire("PLAYER_STOPPED_MOVING")
Check(ticks == last, "stopping while falling starts no watch")
falling = false
Fire("PLAYER_STOPPED_MOVING")
Check(ticks ~= last and not ticks.cancelled, "stopping on foot starts one")
Fire("PLAYER_STARTED_MOVING")
Check(ticks.cancelled, "moving yourself ends the watch")

printed = {}
ns.LiftsCommand("")
Check(#printed == #store.journeyLifts and printed[1]:find("{ 1, ", 1, true) and printed[1]:find("The Base to The Rise", 1, true),
    "/nf lifts lists each learned lift, ready to paste")
printed = {}
ns.LiftsCommand("clear")
Check(store.journeyLifts == nil, "/nf lifts clear forgets them")
ns.LiftsCommand("")
Check(printed[#printed]:find("No lifts learned", 1, true), "and says so")

settings.learnLifts = false
Jy.Lifts.Apply()
Check(next(frame.events) == nil, "with Learn Lifts as You Ride off, nothing is watched")

print(("journeys lifts: %d checks passed"):format(checks))

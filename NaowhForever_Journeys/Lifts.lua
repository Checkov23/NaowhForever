-- Lifts.lua: learns the lifts you ride, where each one starts and stops and how long it takes, for /nf lifts.
local ns = _G.NaowhForever

local abs, floor = math.abs, math.floor

local Jy = ns.Journeys
local C = Jy.C
local S = Jy.Settings
local World = Jy.World

local STORE = "journeyLifts"
local EVENTS = { "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING" }
local MOVED = 1
local TEXT_LINE = "{ %d, %.1f, %.1f, %.1f, %.1f, %.1f, %.1f, %d }, -- %s to %s, seen %d times"
local TEXT_NONE = ns.L("No lifts learned yet. Ride one with Learn Lifts as You Ride on.")
local TEXT_CLEARED = ns.L("Learned lifts cleared.")
local TEXT_LEARNED = ns.L("Learned a lift: %s to %s, %d seconds.")

local Lifts = {}
Jy.Lifts = Lifts

local events, ticker
local base, last, ticks, settled, startedAt

local function On()
    return Jy.On() and S.Get("learnLifts")
end

local function Place()
    local sub = GetSubZoneText()
    if sub and sub ~= "" then return sub end
    return GetZoneText()
end

local function Carried()
    return IsFalling() or IsFlying() or IsSwimming() or UnitOnTaxi("player")
end

local function Along(a, b)
    return (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2
end

local function Remember(low, high, seconds)
    local list = ns.AccountSettings()[STORE]
    if type(list) ~= "table" then
        list = {}
        ns.AccountSettings()[STORE] = list
    end
    for _, lift in ipairs(list) do
        if lift.c == low.c and Along(lift.low, low) <= C.LIFT_MERGE ^ 2 and Along(lift.high, high) <= C.LIFT_MERGE ^ 2 then
            local n = lift.n
            for _, field in ipairs({ "x", "y", "z" }) do
                lift.low[field] = (lift.low[field] * n + low[field]) / (n + 1)
                lift.high[field] = (lift.high[field] * n + high[field]) / (n + 1)
            end
            lift.seconds = (lift.seconds * n + seconds) / (n + 1)
            lift.n = n + 1
            return
        end
    end
    list[#list + 1] = { c = low.c, low = { x = low.x, y = low.y, z = low.z, place = low.place },
        high = { x = high.x, y = high.y, z = high.z, place = high.place }, seconds = seconds, n = 1 }
    while #list > C.LIFT_KEEP do table.remove(list, 1) end
end

local function Stop()
    if ticker then ticker:Cancel() end
    ticker, base, last, ticks, settled, startedAt = nil, nil, nil, 0, 0, nil
end

local function Finish(here)
    local seconds = floor(GetTime() - (startedAt or GetTime() - ticks * C.LIFT_TICK) - settled * C.LIFT_TICK + 0.5)
    local a, b = base, { c = here.c, x = here.x, y = here.y, z = here.z, place = Place() }
    local low, high = a, b
    if b.z < a.z then low, high = b, a end
    Remember(low, high, seconds)
    ns.Print(TEXT_LEARNED:format(low.place, high.place, seconds))
end

local function Tick()
    ticks = ticks + 1
    local here = World.Player()
    if not here or not here.z or Carried() or ticks * C.LIFT_TICK > C.LIFT_WINDOW then return Stop() end
    if Along(here, base) > C.LIFT_DRIFT ^ 2 then return Stop() end
    if abs(here.z - base.z) < C.LIFT_RISE then
        if abs(here.z - last) > MOVED and not startedAt then startedAt = GetTime() end
        last = here.z
        return
    end
    if abs(here.z - last) < C.LIFT_SETTLE then settled = settled + 1 else settled = 0 end
    last = here.z
    if settled >= C.LIFT_SETTLE_TICKS then
        Finish(here)
        Stop()
    end
end

local function OnEvent(_, event)
    if event == "PLAYER_STARTED_MOVING" then return Stop() end
    local here = World.Player()
    if not here or not here.z or Carried() then return end
    Stop()
    base = { c = here.c, x = here.x, y = here.y, z = here.z, place = Place() }
    last, ticks, settled = here.z, 0, 0
    ticker = C_Timer.NewTicker(C.LIFT_TICK, Tick)
end

function Lifts.Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        Stop()
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
end

function ns.LiftsCommand(arg)
    local list = ns.AccountSettings()[STORE]
    if arg == "clear" then
        ns.AccountSettings()[STORE] = nil
        return ns.Print(TEXT_CLEARED)
    end
    if type(list) ~= "table" or #list == 0 then return ns.Print(TEXT_NONE) end
    for _, lift in ipairs(list) do
        ns.Print(TEXT_LINE:format(lift.c, lift.low.x, lift.low.y, lift.low.z, lift.high.x, lift.high.y, lift.high.z,
            floor(lift.seconds + 0.5), lift.low.place, lift.high.place, lift.n))
    end
end

S.OnChange(Lifts.Apply)
hooksecurefunc(ns, "Apply", Lifts.Apply)
Lifts.Apply()

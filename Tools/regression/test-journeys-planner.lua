-- Run with Lua 5.1 from the repository root: the Journeys planner. A short trip is a walk, a long
-- one takes known flights and your faction's ships, an unknown flight point or the other faction's
-- boat is never used, the Hearthstone is taken only when it wins, and a ship's wait counts.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local ns = { Journeys = {} }
local env = setmetatable({ _G = { NaowhForever = ns } }, { __index = _G })
for _, path in ipairs({ "NaowhForever_Journeys/Constants.lua", "NaowhForever_Journeys/Data/Network.lua",
        "NaowhForever_Journeys/Planner.lua" }) do
    local chunk = assert(loadstring(Read(path), path))
    setfenv(chunk, env)
    chunk()
end
local P, C = ns.Journeys.Planner, ns.Journeys.C

local IRONFORGE = { c = 0, x = -4821.8, y = -1155.4 }
local DARNASSUS = { c = 1, x = 9945.0, y = 2490.0, name = "Druid Trainer" }
local ALLIANCE_KNOWN = { [2] = true, [6] = true, [7] = true, [26] = true, [27] = true }

local function Modes(journey)
    local list = {}
    for i, leg in ipairs(journey.legs) do list[i] = leg.mode end
    return table.concat(list, ",")
end

local function Plan(over)
    local ctx = { faction = "A", known = ALLIANCE_KNOWN, from = IRONFORGE, to = DARNASSUS, speed = C.RUN_SPEED, now = 0 }
    for k, v in pairs(over or {}) do ctx[k] = v end
    return P.Plan(ctx)
end

local long = Plan()
Check(long and long.legs[#long.legs].name == "Druid Trainer", "Ironforge to Darnassus finds a way")
Check(Modes(long):find("fly", 1, true) and Modes(long):find("ship", 1, true), "it flies and sails: " .. Modes(long))
for _, leg in ipairs(long.legs) do
    if leg.mode == "ship" then Check(leg.shipKind == "Boat" and leg.wait > 0, "a boat leg waits for the boat") end
end
Check(Modes(long):find("tram", 1, true) and long.legs[#long.legs - 1].mode == "portal",
    "the tram out of Ironforge and the portal up to Darnassus: " .. Modes(long))
local total = 0
for _, leg in ipairs(long.legs) do total = total + leg.seconds end
Check(math.abs(total - long.seconds) < 0.01, "the legs add up to the journey")

local short = Plan({ to = { c = 0, x = -4900, y = -1100, name = "Bank" } })
Check(short and Modes(short) == "walk", "a short trip is one walk: " .. (short and Modes(short) or "none"))
local here = Plan({ to = { c = 0, x = IRONFORGE.x, y = IRONFORGE.y, name = "Here" } })
Check(here and #here.legs == 0 and here.seconds == 0, "standing on the spot is no journey")

local unknown = Plan({ known = {} })
Check(unknown and not Modes(unknown):find("fly", 1, true), "no flight from a point you have not learned")

local horde = Plan({ faction = "H", known = { [22] = true, [23] = true, [25] = true },
    from = { c = 1, x = 1677.6, y = -4315.7 }, to = { c = 1, x = 6594.4, y = 759.8, name = "Auberdine dock" } })
Check(horde and not Modes(horde):find("ship", 1, true), "the Horde never boards the Alliance boats")

local home = { mode = "hearth", name = "Rut'theran Village", cast = C.HEARTH_CAST, item = C.HEARTHSTONE,
    c = 1, x = 8700, y = 900 }
local hearth = Plan({ jumps = { home } })
Check(hearth and hearth.legs[1].mode == "hearth", "the Hearthstone home beats the boats: " .. Modes(hearth))
Check(hearth.seconds < long.seconds, "and is faster")
local stay = Plan({ jumps = { home }, to = { c = 0, x = -4900, y = -1100, name = "Bank" } })
Check(Modes(stay) == "walk", "but not for a walk across town")

local waits = Plan({ shipWait = function() return 0 end })
local slow = Plan({ shipWait = function() return 600 end })
Check(waits.seconds < long.seconds and (slow.seconds > long.seconds or not Modes(slow):find("ship", 1, true)),
    "the next departure changes the plan")

local blocked = Plan({ to = { c = 0, x = -4900, y = -1100, name = "Bank" }, walk = function(_, b)
    if b.kind == "goal" then return false end
end })
Check(blocked == nil, "a goal the map says no walk reaches has no plan")
local measured = Plan({ to = { c = 0, x = -4900, y = -1100, name = "Bank" }, walk = function(a, b)
    if a.kind == "start" and b.kind == "goal" then return 700 end
    return false
end })
Check(measured and Modes(measured) == "walk" and math.abs(measured.seconds - 700 / C.RUN_SPEED) < 0.01,
    "a measured walk costs its yards at running speed")
local unknown2 = Plan({ to = { c = 0, x = -4900, y = -1100, name = "Bank" }, walk = function() return nil end })
Check(math.abs(unknown2.seconds - short.seconds) < 0.01, "no answer falls back to the straight line")

local ship = ns.JourneyNetwork.ships[3]
Check(math.abs(P.Sail(nil, ship, 1, 2) + P.Sail(nil, ship, 2, 1) + ship[3][6] + ship[4][6] - P.Period(nil, ship)) < 0.01,
    "there and back again is one period")

local planner = Read("NaowhForever_Journeys/Planner.lua")
Check(not planner:find("ship.docks", 1, true), "the shared network table is never written")

print(("journeys planner: %d checks passed"):format(checks))

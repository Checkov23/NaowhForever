-- Run with Lua 5.1 from the repository root: ns.PlaceWaypoint and routes. With TomTom loaded its
-- waypoint is used, unless the Waypoint Pin is on, which follows the game's own; either way the
-- spot's title, note and icon are kept for the pin. A route places its stops in order, the next
-- one a moment after the game says the last was reached, and ends when another waypoint is
-- placed or the waypoint is cleared.
local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local tomtom, set, tracked, printed, timers = {}, {}, 0, {}, {}
local current   -- the game's user waypoint, as C_Map.GetUserWaypoint gives it
local pinOn = false
local watch
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    Print = function(msg) printed[#printed + 1] = msg end,
    WaypointPinOn = function() return pinOn end,
}
local function Fire(event, ...)
    if watch.events[event] then watch.scripts.OnEvent(watch, event, ...) end
end
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function()
        watch = { events = {}, scripts = {} }
        function watch:SetScript(k, fn) self.scripts[k] = fn end
        function watch:RegisterEvent(e) self.events[e] = true end
        function watch:UnregisterAllEvents() self.events = {} end
        return watch
    end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    TomTom = {
        AddWaypoint = function(_, map, x, y, opts)
            tomtom[#tomtom + 1] = { map = map, x = x, y = y, title = opts.title }
            return #tomtom
        end,
        RemoveWaypoint = function() end,
    },
    C_Map = {
        CanSetUserWaypointOnMap = function() return true end,
        SetUserWaypoint = function(point)
            set[#set + 1] = point
            current = { uiMapID = point.map, position = { x = point.x, y = point.y } }
            Fire("USER_WAYPOINT_UPDATED")
        end,
        ClearUserWaypoint = function()
            current = nil
            Fire("USER_WAYPOINT_UPDATED")
        end,
        GetUserWaypoint = function() return current end,
        GetMapInfo = function() return { name = "Orgrimmar" } end,
    },
    C_SuperTrack = { SetSuperTrackedUserWaypoint = function() tracked = tracked + 1 end },
    UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { map = map, x = x, y = y } end },
}, { __index = _G })
env._G = env
local f = assert(io.open("Core/Waypoint.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local chunk = assert(loadstring(source, "Core/Waypoint.lua"))
setfenv(chunk, env)
chunk()

Check(next(watch.events) == nil, "nothing listens without a route")
Check(ns.PlaceWaypoint("Hanashi", 1454, 81.5, 19.6, " (Weapon Master)", 132), "placed")
Check(#tomtom == 1 and #set == 0 and tomtom[1].title == "Hanashi (Weapon Master)", "pin off: TomTom's waypoint")

pinOn = true
Check(ns.PlaceWaypoint("Hanashi", 1454, 81.5, 19.6, " (Weapon Master)", 132), "placed again")
Check(#tomtom == 1 and #set == 1 and set[1].map == 1454 and tracked == 1, "pin on: the game's, tracked, not TomTom's")
local placed = ns.placedWaypoint
Check(placed.title == "Hanashi" and placed.note == " (Weapon Master)" and placed.icon == 132
    and placed.map == 1454 and placed.x == 81.5 and placed.y == 19.6, "the title, note and icon kept for the pin")

-- A route, even with the pin off and TomTom loaded: the game's waypoint on the first stop.
pinOn = false
local STOPS = {
    { "Grezz Ragefist", 1454, 80.0, 30.0, " (Warrior Trainer)", "class" },
    { "Hanashi", 1454, 81.5, 19.6, " (Weapon Master)" },
    { "Kaja", 1454, 50.0, 50.0, " (Mining Trainer)", 136248 },
}
Check(ns.PlaceWaypointRoute("Training run", STOPS), "a route is placed")
Check(#tomtom == 1 and #set == 2 and ns.placedWaypoint.title == "Grezz Ragefist" and ns.placedWaypoint.icon == "class",
    "the game's waypoint on the first stop, with its icon")
Check(printed[#printed]:find("Training run, stop 1 of 3", 1, true) ~= nil, "and a chat line for it")
local title, at, n, nextTitle = ns.WaypointRoute()
Check(title == "Training run" and at == 1 and n == 3 and nextTitle == "Hanashi", "the route, the stop and the next")

-- A stop on the way is not the stop; reaching it moves on after the hold.
local waiting = #timers
Fire("NAVIGATION_DESTINATION_REACHED", true)
Check(#timers == waiting, "a stop on the way does nothing")
Fire("NAVIGATION_DESTINATION_REACHED", false)
Check(ns.placedWaypoint.title == "Grezz Ragefist", "still on the stop while its arrival shows")
timers[#timers]()
Check(ns.placedWaypoint.title == "Hanashi" and select(2, ns.WaypointRoute()) == 2, "then the next stop")
-- An arrival superseded by another keeps the older timer from moving twice.
Fire("NAVIGATION_DESTINATION_REACHED", false)
local older = timers[#timers]
Fire("NAVIGATION_DESTINATION_REACHED", false)
older()
Check(select(2, ns.WaypointRoute()) == 2, "an older arrival's timer does nothing")
timers[#timers]()
Check(ns.placedWaypoint.title == "Kaja" and select(4, ns.WaypointRoute()) == nil, "the last stop, nothing after it")
Fire("NAVIGATION_DESTINATION_REACHED", false)
Check(ns.WaypointRoute() ~= nil, "the route stays while the last arrival shows")
timers[#timers]()
Check(ns.WaypointRoute() == nil and next(watch.events) == nil, "then it ends and stops listening")

-- Another waypoint, or clearing it, ends a route.
ns.PlaceWaypointRoute("Training run", STOPS)
env.C_Map.SetUserWaypoint({ map = 1411, x = 0.5, y = 0.5 })
Check(ns.WaypointRoute() == nil, "a waypoint set elsewhere ends it")
ns.PlaceWaypointRoute("Training run", STOPS)
env.C_Map.ClearUserWaypoint()
Check(ns.WaypointRoute() == nil, "clearing the waypoint ends it")
ns.PlaceWaypointRoute("Training run", STOPS)
pinOn = true
ns.PlaceWaypoint("Rwag", 1411, 41.3, 68.0)
Check(ns.WaypointRoute() == nil and ns.placedWaypoint.title == "Rwag", "placing a waypoint ends it")

-- A route of one stop is a plain waypoint.
Check(ns.PlaceWaypointRoute("Training run", { STOPS[2] }) and ns.WaypointRoute() == nil
    and ns.placedWaypoint.title == "Hanashi", "one stop is a plain waypoint")

env.TomTom = nil
pinOn = false
ns.PlaceWaypoint("Rwag", 1411, 41.3, 68.0)
Check(ns.placedWaypoint.icon == nil and ns.placedWaypoint.note == nil, "no TomTom: the game's, without extras")

print(("test-waypoint-place: %d checks passed"):format(checks))

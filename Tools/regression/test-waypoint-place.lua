-- Run with Lua 5.1 from the repository root: ns.PlaceWaypoint and routes. With TomTom loaded its
-- waypoint is used, unless the Waypoint Pin is on, which follows the game's own; either way the
-- spot's title, note and icon are kept for the pin. A route places its stops in order, the next
-- one a moment after the game says the last was reached, and ends when another waypoint is
-- placed or the waypoint is cleared. A dungeon's entrance clears once you are inside.
local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local tomtom, set, tracked, printed, timers = {}, {}, 0, {}, {}
local current   -- the game's user waypoint, as C_Map.GetUserWaypoint gives it
local pinOn = false
local watch
local frames = {}
local instanceKind
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    Print = function(msg) printed[#printed + 1] = msg end,
    WaypointPinOn = function() return pinOn end,
}
local function Fire(event, ...)
    if watch.events[event] then watch.scripts.OnEvent(watch, event, ...) end
end
local function Listening(event)
    for _, frame in ipairs(frames) do
        if frame ~= watch and frame.events[event] then return frame end
    end
end
local function Load(kind)
    instanceKind = kind
    local frame = Listening("PLAYER_ENTERING_WORLD")
    if frame then frame.scripts.OnEvent(frame, "PLAYER_ENTERING_WORLD") end
end
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function()
        local frame = { events = {}, scripts = {} }
        function frame:SetScript(k, fn) self.scripts[k] = fn end
        function frame:RegisterEvent(e) self.events[e] = true end
        function frame:UnregisterAllEvents() self.events = {} end
        frames[#frames + 1] = frame
        watch = watch or frame
        return frame
    end,
    IsInInstance = function() return instanceKind ~= nil, instanceKind or "none" end,
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
    CreateFromMixins = function(...)
        local t = {}
        for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do t[k] = v end end
        return t
    end,
    MapCanvasPinMixin = {},
    MapCanvasDataProviderMixin = {},
    C_SuperTrack = { SetSuperTrackedUserWaypoint = function() tracked = tracked + 1 end, ClearAllSuperTracked = function() end },
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

-- A dungeon's entrance clears as you go from outside a dungeon or raid to inside one.
ns.PlaceWaypoint("The Deadmines", 1436, 43.2, 72.4, " (entrance)", nil, true)
Check(Listening("PLAYER_ENTERING_WORLD"), "an entrance listens for loading screens")
Load(nil)
Check(current ~= nil, "outside: kept")
Load("pvp")
Check(current ~= nil, "a battleground is not a dungeon: kept")
Load("party")
Check(current == nil and ns.placedWaypoint == nil and not Listening("PLAYER_ENTERING_WORLD"), "inside: cleared, not listening")

-- Placed while inside one: it waits until you leave and enter again.
Load("party")
ns.PlaceWaypoint("Wailing Caverns", 1413, 46.0, 36.0, " (entrance)", nil, true)
Load("party")
Check(current ~= nil, "still inside: kept")
Load(nil)
Load("party")
Check(current == nil, "out and back in: cleared")
Load(nil)

-- Only the waypoint it was placed with: one set by hand, one placed since, or a route drop it.
ns.PlaceWaypoint("The Deadmines", 1436, 43.2, 72.4, " (entrance)", nil, true)
env.C_Map.SetUserWaypoint({ map = 1429, x = 0.1, y = 0.1 })
Load("party")
Check(current ~= nil and current.uiMapID == 1429, "a waypoint set by hand since is not cleared")
Load(nil)
ns.PlaceWaypoint("The Deadmines", 1436, 43.2, 72.4, " (entrance)", nil, true)
ns.PlaceWaypoint("Rwag", 1411, 41.3, 68.0)
Check(not Listening("PLAYER_ENTERING_WORLD"), "a waypoint placed since stops listening")
Load("party")
Check(current ~= nil and ns.placedWaypoint.title == "Rwag", "and is not cleared")
Load(nil)
ns.PlaceWaypoint("The Deadmines", 1436, 43.2, 72.4, " (entrance)", nil, true)
ns.PlaceWaypointRoute("Training run", STOPS)
Check(not Listening("PLAYER_ENTERING_WORLD"), "so does a route")

-- With TomTom's arrow, a map pin's second click removes that arrow.
local removed = 0
env.TomTom = {
    AddWaypoint = function(_, map, x, y, opts)
        tomtom[#tomtom + 1] = { map = map, x = x, y = y, title = opts.title }
        return #tomtom
    end,
    RemoveWaypoint = function() removed = removed + 1 end,
}
pinOn = false
ns.ToggleWaypoint("Kaja", 1454, 50.0, 50.0)
local arrows, gone = #tomtom, removed
Check(tomtom[arrows].title == "Kaja", "a pin's click: TomTom's arrow")
ns.ToggleWaypoint("Kaja", 1454, 50.0, 50.0)
Check(removed == gone + 1 and #tomtom == arrows, "a second click removes it, nothing new")
ns.ToggleWaypoint("Kaja", 1454, 50.0, 50.0)
Check(#tomtom == arrows + 1 and removed == gone + 1, "a third places it again")

-- With Journeys on, the waypoint is the journey's step, not the pin: a second click on the pin
-- the journey ends at cancels the journey and clears its waypoint.
env.TomTom = nil
pinOn = true
local journey, started = nil, 0
ns.JourneyTo = function(_, stops)
    journey, started = stops, started + 1
    ns.ShowJourneyStep("Flight Master: Doras", 1454, 49.6, 59.2)
    return true
end
ns.JourneyCancel = function() journey = nil end
ns.JourneyDestination = function()
    if not journey then return end
    local stop = journey[#journey]
    return stop[2], stop[3], stop[4]
end
local WC = { "Wailing Caverns", 1413, 46.0, 36.0, " (entrance)" }
ns.ToggleWaypoint(unpack(WC))
Check(started == 1 and journey ~= nil and current.uiMapID == 1454, "a pin's click starts a journey, its step on the waypoint")
ns.ToggleWaypoint(unpack(WC))
Check(started == 1 and journey == nil and current == nil and ns.placedWaypoint == nil,
    "a second click cancels the journey and clears its waypoint")
Check(printed[#printed]:find("Removed the waypoint for Wailing Caverns", 1, true) ~= nil, "and says so")
ns.ToggleWaypoint(unpack(WC))
ns.ToggleWaypoint("The Deadmines", 1436, 43.2, 72.4, " (entrance)")
Check(started == 3 and journey[1][1] == "The Deadmines" and current ~= nil,
    "a click on another pin starts a journey there instead")

print(("test-waypoint-place: %d checks passed"):format(checks))

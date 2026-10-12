-- Run with Lua 5.1 from the repository root: a waypoint becomes a journey. With Journeys off, or in a
-- spot the game gives no position for, the plain waypoint is placed. With it on, the game's waypoint
-- goes on the first thing to do, named for it; arriving plans again from where you stand; combat
-- waits; another waypoint, or clearing it, ends the journey; and the pin hears it is on a route.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local SCALE = 1000
local WORLD_MAP = 9000
local IRONFORGE, DARNASSUS = 1455, 1457
local EASTERN_KINGDOMS, KALIMDOR = 1415, 1414
local MAPS = {
    [IRONFORGE] = { c = 0, x = -4821.8, y = -1155.4 },
    [DARNASSUS] = { c = 1, x = 9945.0, y = 2490.0 },
}

local frames, timers, printed = {}, {}, {}
local tracking, handedBack = 0, nil
local QUESTS = { [101] = { 1457, 0.5, 0.5 }, [102] = { 1455, 0.5, 0.5 } }
local here = { x = -4821.8, y = -1155.4, c = 0 }
local current
local combat = false
local account = {}
local store = {}

local function Fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] then f.scripts.OnEvent(f, event, ...) end
    end
end

local function RunTimers()
    local run = timers
    timers = {}
    for _, fn in ipairs(run) do fn() end
end

local ns = {
    JourneyQuestSpots = {
        [104] = { { IRONFORGE, 50, 50 }, { { DARNASSUS, 50, 50 }, { IRONFORGE, 50, 50 } } },
        [105] = { { DARNASSUS, 50, 50 }, { { IRONFORGE, 50, 50 } } },
    },
    Print = function(msg) printed[#printed + 1] = msg end,
    WaypointPinOn = function() return true end,
    AccountSettings = function() return account end,
    FEATURES = { journeys = { enabled = false, card = true } },
    Apply = function() end,
}
ns.UI = {
    ModuleSettings = function(_, defaults)
        local S, listeners = {}, {}
        function S.Get(k)
            if store[k] == nil then return defaults[k] end
            return store[k]
        end
        function S.Set(k, v)
            store[k] = v
            for _, fn in ipairs(listeners) do fn(k, v) end
        end
        function S.OnChange(fn) listeners[#listeners + 1] = fn end
        return S
    end,
}

local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function()
        local f = { events = {}, scripts = {} }
        function f:SetScript(k, fn) self.scripts[k] = fn end
        function f:RegisterEvent(e) self.events[e] = true end
        function f:RegisterUnitEvent(e) self.events[e] = true end
        function f:UnregisterAllEvents() self.events = {} end
        frames[#frames + 1] = f
        return f
    end,
    hooksecurefunc = function(t, k, fn)
        local old = t[k]
        t[k] = function(...) local r = old(...); fn(...); return r end
    end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    UnitPosition = function()
        if not here then return nil end
        return here.x, here.y, 0, here.c
    end,
    UnitName = function() return "Glyadin" end,
    GetRealmName = function() return "Forever" end,
    UnitFactionGroup = function() return "Alliance" end,
    GetServerTime = function() return 0 end,
    GetTime = function() return 0 end,
    InCombatLockdown = function() return combat end,
    GetBindLocation = function() return "Ironforge" end,
    CreateVector2D = function(x, y) return { x = x, y = y } end,
    Enum = { UIMapType = { Continent = 2, Zone = 3 }, FlightPathState = { Unreachable = 2 } },
    C_Item = { GetItemCount = function() return 0 end },
    C_AddOns = { IsAddOnLoaded = function() return false end, LoadAddOn = function() end },
    debugprofilestop = function() return 0 end,
    geterrorhandler = function() return error end,
    C_SpellBook = { IsSpellKnown = function() return false end },
    C_Map = {
        GetBestMapForUnit = function() return IRONFORGE end,
        GetMapChildrenInfo = function(continent)
            if continent == KALIMDOR then return { { mapID = DARNASSUS } } end
            return { { mapID = IRONFORGE } }
        end,
        CanSetUserWaypointOnMap = function() return true end,
        SetUserWaypoint = function(point)
            current = { uiMapID = point.map, position = { x = point.x, y = point.y } }
            Fire("USER_WAYPOINT_UPDATED")
        end,
        ClearUserWaypoint = function()
            current = nil
            Fire("USER_WAYPOINT_UPDATED")
        end,
        GetUserWaypoint = function() return current end,
        GetMapInfo = function(map)
            if map == KALIMDOR or map == EASTERN_KINGDOMS then return { mapID = map, mapType = 2 } end
            return { name = "Somewhere", mapType = 3, parentMapID = map == DARNASSUS and KALIMDOR or EASTERN_KINGDOMS }
        end,
        GetWorldPosFromMapPos = function(map)
            local spot = MAPS[map]
            if not spot then return nil end
            return spot.c, { x = spot.x, y = spot.y }
        end,
        GetMapPosFromWorldPos = function(c, pos)
            return WORLD_MAP + c, { x = pos.x / SCALE, y = pos.y / SCALE }
        end,
    },
    C_SuperTrack = {
        SetSuperTrackedUserWaypoint = function() tracking = 0 end,
        ClearAllSuperTracked = function() tracking = 0 end,
        GetSuperTrackedQuestID = function() return tracking end,
        SetSuperTrackedQuestID = function(id) tracking = id; handedBack = id end,
    },
    C_QuestLog = {
        GetNextWaypoint = function(id) local q = QUESTS[id]; if q then return q[1], q[2], q[3] end end,
        GetTitleForQuestID = function(id) return "Quest " .. id end,
        IsComplete = function(id) return id == 105 end,
        GetQuestsOnMap = function(map)
            if map == DARNASSUS then return { { questID = 103, x = 0.5, y = 0.5 } } end
            return {}
        end,
    },
    UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { map = map, x = x, y = y } end },
}, { __index = _G })
env._G = env
env.WorldMapFrame = nil

for _, path in ipairs({ "Core/Waypoint.lua", "NaowhForever_Journeys/Journeys.lua", "NaowhForever_Journeys/Constants.lua",
        "NaowhForever_Journeys/Data/Network.lua", "NaowhForever_Journeys/Data/Teleports.lua",
        "NaowhForever_Journeys/Planner.lua", "NaowhForever_Journeys/World.lua", "NaowhForever_Journeys/Walk.lua",
        "NaowhForever_Journeys/Guide.lua", "NaowhForever_Journeys/Quests.lua" }) do
    local chunk = assert(loadstring(Read(path), path))
    setfenv(chunk, env)
    chunk()
end
local Jy = ns.Journeys
local DESTINATION = { "Mathrengyl Bearwalker", DARNASSUS, 50, 50, " (Druid Trainer)" }

local function Title()
    return ns.placedWaypoint and ns.placedWaypoint.title
end

Check(ns.PlaceWaypoint(unpack(DESTINATION)), "placed with Journeys off")
Check(Title() == "Mathrengyl Bearwalker" and not Jy.Guide.Current(), "off: the plain waypoint, no journey")

Jy.Settings.Set("enabled", true)
account.journeyFlights = { ["Glyadin-Forever"] = { [2] = true, [6] = true, [7] = true, [26] = true, [27] = true } }

here = nil
Check(ns.PlaceWaypoint(unpack(DESTINATION)) and not Jy.Guide.Current(), "no position (an instance): the plain waypoint")
here = { x = -4821.8, y = -1155.4, c = 0 }

Check(ns.PlaceWaypoint(unpack(DESTINATION)), "placed with Journeys on")
local journey = Jy.Guide.Current()
Check(journey and journey.title == "Mathrengyl Bearwalker", "a journey to the trainer")
Check(Title() == "Deeprun Tram to Stormwind", "the waypoint names the first thing to do: " .. tostring(Title()))
local route, at, n, nextTitle = ns.WaypointRoute()
Check(route == "Mathrengyl Bearwalker" and at == 1 and n > 3 and nextTitle, "the pin hears it is on a route")

local tram = journey.plan.legs[1]
here = { x = tram.x, y = tram.y, c = tram.c }
Fire("NAVIGATION_DESTINATION_REACHED", false)
RunTimers()
Check(Title() == "Deeprun Tram to Stormwind" and Jy.Guide.Current().plan.legs[1].mode == "tram",
    "at the tram: ride it, the waypoint now at the far end")

local before = Title()
combat = true
here = { x = -8346.5, y = 514.0, c = 0 }
Fire("PLAYER_ENTERING_WORLD")
RunTimers()
Check(Title() == before and Jy.Guide.Current().waiting, "in combat the plan waits")
combat = false
Fire("PLAYER_REGEN_ENABLED")
RunTimers()
Check(Title() == "Boat to Auberdine" and not Jy.Guide.Current().waiting,
    "and is made again when combat ends, from Stormwind: " .. tostring(Title()))
Check(Jy.Guide.Current().done > 0, "the steps behind you count as done")

env.C_Map.SetUserWaypoint({ map = 1, x = 0.1, y = 0.1 })
Check(not Jy.Guide.Current() and ns.WaypointRoute() == nil, "another waypoint ends the journey")

Check(ns.PlaceWaypoint(unpack(DESTINATION)) and Jy.Guide.Current(), "a new journey")
ns.ClearWaypoint()
Check(not Jy.Guide.Current(), "clearing the waypoint ends it")

here = { x = 9945.0, y = 2490.0, c = 1 }
Check(ns.PlaceWaypoint(unpack(DESTINATION)) and not Jy.Guide.Current(), "already there: no journey left")

local stops = { { "A", IRONFORGE, 50, 50 }, { "B", DARNASSUS, 50, 50 } }
Check(ns.PlaceWaypointRoute("Training run", stops) and #stops[1] == 4 and stops[1].spot == nil,
    "a route becomes one journey, and its stops are not written to")

Jy.Guide.Cancel()
here = { x = -4821.8, y = -1155.4, c = 0 }
tracking = 102
Fire("SUPER_TRACKING_CHANGED")
Check(not Jy.Guide.Current(), "a tracked quest close by stays with the game's own arrow")
tracking = 101
Fire("SUPER_TRACKING_CHANGED")
local quest = Jy.Guide.Current()
Check(quest and quest.quest == 101 and quest.title == "Quest 101", "a far tracked quest becomes a journey")
here = { x = 9945.0, y = 2490.0, c = 1 }
Fire("PLAYER_ENTERING_WORLD")
RunTimers()
Check(not Jy.Guide.Current() and handedBack == 101 and tracking == 101, "arriving tracks the quest again")
Fire("SUPER_TRACKING_CHANGED")
Check(not Jy.Guide.Current(), "and the quest, now close, does not start another")

Jy.Guide.Cancel()
here = { x = -4821.8, y = -1155.4, c = 0 }
tracking = 103
Fire("SUPER_TRACKING_CHANGED")
local found = Jy.Guide.Current()
Check(found and found.quest == 103 and found.stops[1][2] == DARNASSUS,
    "a quest with no next point is found on its zone map, on another continent")
Jy.Guide.Cancel()

tracking = 101
Fire("SUPER_TRACKING_CHANGED")
Check(Jy.Guide.Current() and Jy.Guide.Current().quest == 101, "a far quest's journey again")
ns.ClearWaypoint()
Check(not Jy.Guide.Current(), "clearing the waypoint ends it")
tracking = 101
Fire("SUPER_TRACKING_CHANGED")
Check(not Jy.Guide.Current(), "and the game tracking that quest again does not bring it back")
tracking = 103
Fire("SUPER_TRACKING_CHANGED")
Check(Jy.Guide.Current() and Jy.Guide.Current().quest == 103, "tracking another quest starts its journey")
Jy.Guide.Cancel()

here = { x = 9945.0, y = 2490.0, c = 1 }
tracking = 104
Fire("SUPER_TRACKING_CHANGED")
Check(not Jy.Guide.Current(), "a quest the game has no point for goes to its nearest camp, here")
here = { x = -4821.8, y = -1155.4, c = 0 }
tracking = 105
Fire("SUPER_TRACKING_CHANGED")
local done = Jy.Guide.Current()
Check(done and done.quest == 105 and done.stops[1][2] == DARNASSUS, "a finished quest goes to its turn-in")
Jy.Guide.Cancel()

Jy.Settings.Set("quests", false)
here = { x = -4821.8, y = -1155.4, c = 0 }
Fire("SUPER_TRACKING_CHANGED")
Check(not Jy.Guide.Current(), "with Journeys to Tracked Quests off, tracking a quest is left alone")

local function Driver()
    for _, f in ipairs(frames) do
        if f.scripts.OnUpdate then return f end
    end
end
local realFrom, slow = Jy.Walk.From, true
Jy.Walk.From = function()
    if slow then coroutine.yield() end
    return nil
end
Jy.Settings.Set("quests", true)
here = { x = -4821.8, y = -1155.4, c = 0 }
Check(ns.PlaceWaypoint(unpack(DESTINATION)) and Jy.Guide.Current(), "a journey whose search takes frames")
Check(Driver() ~= nil and not Jy.Guide.Current().plan, "its search runs from an update, and has no plan yet")
slow = false
Fire("PLAYER_ENTERING_WORLD")
RunTimers()
Check(Jy.Guide.Current().plan ~= nil and Driver() == nil, "a replan that finishes at once leaves the slow one's update gone")
Jy.Guide.Cancel()
slow = true
Check(ns.PlaceWaypoint(unpack(DESTINATION)) and Driver() ~= nil, "a slow search again")
Jy.Guide.Cancel()
Check(Driver() == nil, "cancelling the journey stops its search")
slow = false

ns.placedWaypoint = nil
combat = true
Check(ns.PlaceWaypoint(unpack(DESTINATION)) and ns.placedWaypoint and ns.placedWaypoint.title == "Mathrengyl Bearwalker"
    and Jy.Guide.Current().waiting, "a click in combat puts the plain waypoint up at once")
combat = false
Fire("PLAYER_REGEN_ENABLED")
RunTimers()
Check(Jy.Guide.Current().plan ~= nil and ns.placedWaypoint.title ~= "Mathrengyl Bearwalker",
    "and the journey takes over when combat ends")
Jy.Guide.Cancel()

here = { x = -8832.8, y = 478.6, c = 0 }
local two = { { "Ironforge", IRONFORGE, 50, 50 }, { "Darnassus", DARNASSUS, 50, 50 } }
Check(ns.PlaceWaypointRoute("Training run", two), "a two-stop route")
local first = #Jy.Guide.Current().plan.legs
Check(Jy.Guide.Current().done == 0, "no step done yet")
here = { x = -4821.8, y = -1155.4, c = 0 }
Fire("PLAYER_ENTERING_WORLD")
RunTimers()
Check(Jy.Guide.Current().at == 2 and Jy.Guide.Current().done == first,
    "reaching the first stop counts all its steps, whatever the next plan's length: " .. Jy.Guide.Current().done)
Jy.Guide.Cancel()

env.C_Map.CanSetUserWaypointOnMap = function() return false end
here = { x = -4821.8, y = -1155.4, c = 0 }
Check(ns.PlaceWaypoint(unpack(DESTINATION)) and not Jy.Guide.Current(),
    "a journey whose steps no map takes a waypoint for ends, and says so")
env.C_Map.CanSetUserWaypointOnMap = function() return true end
Jy.Walk.From = realFrom

Jy.Settings.Set("enabled", false)
Check(not Jy.Guide.Current(), "turning Journeys off ends the journey")

print(("journeys guide: %d checks passed"):format(checks))

-- Run with Lua 5.1 from the repository root: a waypoint becomes a journey. With Journeys off, or in a
-- spot the game gives no position for, the plain waypoint is placed. With it on, the game's waypoint
-- goes on the first thing to do, named for it; arriving plans again from where you stand; combat
-- waits; another waypoint, or clearing it, ends the journey; and the pin hears it is on a route. A tracked
-- quest goes to its own marker, and a flight point learned on the way plans again.
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
local CROSSING, DUSKWOOD = 1426, 1431
local EASTERN_KINGDOMS, KALIMDOR = 1415, 1414
local MAPS = {
    [IRONFORGE] = { c = 0, x = -4821.8, y = -1155.4 },
    [DARNASSUS] = { c = 1, x = 9945.0, y = 2490.0 },
    [CROSSING] = { c = 0, x = -5500.0, y = -1500.0 },
    [DUSKWOOD] = { c = 0, x = -10560.0, y = -1170.0 },
}

local frames, timers, printed, tickers = {}, {}, {}, {}
local tracking, handedBack = 0, nil
local QUESTS = { [101] = { 1457, 0.5, 0.5 }, [102] = { 1455, 0.5, 0.5 }, [106] = { CROSSING, 0.5, 0.5 } }
QUESTS[116] = { DARNASSUS, 0.5, 0.5 }
local here = { x = -4821.8, y = -1155.4, c = 0 }
local current, placedAtSet
local combat = false
local now = 0
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

local rxpPin = false
local ns = {
    RestedXPPin = function() return rxpPin end,
    JourneyQuestSpots = {
        [104] = { { IRONFORGE, 50, 50 }, { { DARNASSUS, 50, 50 }, { IRONFORGE, 50, 50 } } },
        [105] = { { DARNASSUS, 50, 50 }, { { IRONFORGE, 50, 50 } } },
        [107] = { false, {}, { { DARNASSUS, 50, 50 } } },
        [108] = { false, {}, { { DARNASSUS, 50, 50 } } },
        [109] = { false, { { DUSKWOOD, 50, 50 } }, { { DARNASSUS, 50, 50 } } },
        [110] = { false, { { IRONFORGE, 50, 50 } }, {},
            { { IRONFORGE, 50, 50, "H" }, { DARNASSUS, 50, 50, "A" } } },
        [111] = { false, { { DUSKWOOD, 50, 50 } }, {}, { { DARNASSUS, 50, 50, "A" } } },
        [112] = { false, {}, {}, { { DARNASSUS, 50, 50, "H" } } },
        [113] = { false, {}, {}, { { IRONFORGE, 50, 50, "A" }, { DARNASSUS, 50, 50, "H" } } },
        [114] = { false, { { DARNASSUS, 50, 50 } } },
        [115] = { false, { { DARNASSUS, 50, 50 } }, {}, { { DUSKWOOD, 50, 50, "H" } } },
        [116] = { false, { { DUSKWOOD, 50, 50 } } },
    },
    L = dofile("Tools/regression/locale_stub.lua").L,
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
    C_Timer = {
        After = function(_, fn) timers[#timers + 1] = fn end,
        NewTicker = function(_, fn)
            local t = { fn = fn }
            function t:Cancel() self.cancelled = true end
            tickers[#tickers + 1] = t
            return t
        end,
    },
    UnitPosition = function()
        if not here then return nil end
        return here.x, here.y, 0, here.c
    end,
    UnitName = function() return "Glyadin" end,
    UnitOnTaxi = function() return false end,
    GetRealmName = function() return "Forever" end,
    UnitFactionGroup = function() return "Alliance" end,
    GetServerTime = function() return 0 end,
    GetTime = function() return now end,
    InCombatLockdown = function() return combat end,
    GetBindLocation = function() return "Ironforge" end,
    CreateVector2D = function(x, y) return { x = x, y = y } end,
    Enum = { UIMapType = { Continent = 2, Zone = 3 }, FlightPathState = { Unreachable = 2 } },
    C_Item = { GetItemCount = function() return 0 end },
    C_AddOns = { IsAddOnLoaded = function() return false end, LoadAddOn = function() end,
        DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end },
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
            placedAtSet = ns.placedWaypoint
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
        IsComplete = function(id) return id == 105 or id == 108 or id == 110 or id == 114 or id == 115 or id == 116 end,
        GetQuestsOnMap = function(map)
            if map == DARNASSUS then return { { questID = 103, x = 0.5, y = 0.5 }, { questID = 106, x = 0.5, y = 0.5 } } end
            return {}
        end,
    },
    CreateFromMixins = function(...)
        local t = {}
        for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do t[k] = v end end
        return t
    end,
    MapCanvasPinMixin = {},
    MapCanvasDataProviderMixin = {},
    UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { map = map, x = x, y = y } end },
}, { __index = _G })
env._G = env
env.WorldMapFrame = nil

for _, path in ipairs({ "Core/Waypoint.lua", "NaowhForever_Utilities/Journeys/Journeys.lua", "NaowhForever_Utilities/Journeys/Constants.lua",
        "NaowhForever_Utilities/Journeys/Data/Network.lua", "NaowhForever_Utilities/Journeys/Data/Teleports.lua",
        "NaowhForever_Utilities/Journeys/Planner.lua", "NaowhForever_Utilities/Journeys/World.lua", "NaowhForever_Utilities/Journeys/Walk.lua",
        "NaowhForever_Utilities/Journeys/Guide.lua", "NaowhForever_Utilities/Journeys/Quests.lua", "NaowhForever_Utilities/Journeys/Pins.lua" }) do
    local chunk = assert(loadstring(Read(path), path))
    setfenv(chunk, env)
    chunk()
end
local Jy = ns.Journeys
local function Tick()
    for _, t in ipairs(tickers) do
        if not t.cancelled then t.fn() end
    end
end
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
Check(Jy.World.Player().z == nil, "UnitPosition's placeholder height of 0 is no height at all")

Check(ns.PlaceWaypoint(unpack(DESTINATION)), "placed with Journeys on")
local journey = Jy.Guide.Current()
Check(journey and journey.title == "Mathrengyl Bearwalker", "a journey to the trainer")
Check(placedAtSet and placedAtSet.title == Title(), "the pin is known as ours before the game hears of it")
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
tracking = 106
Fire("SUPER_TRACKING_CHANGED")
local marked = Jy.Guide.Current()
Check(marked and marked.quest == 106 and marked.stops[1][2] == DARNASSUS,
    "a quest the game routes through a zone crossing goes to its own marker, not the crossing")
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

tracking = 107
Fire("SUPER_TRACKING_CHANGED")
local dungeon = Jy.Guide.Current()
Check(dungeon and dungeon.stops[1][2] == DARNASSUS, "an unmapped dungeon quest uses its recorded entrance")
Jy.Guide.Cancel()
tracking = 108
Fire("SUPER_TRACKING_CHANGED")
Check(not Jy.Guide.Current(), "a completed quest never uses an entrance as its turn-in")
tracking = 109
Fire("SUPER_TRACKING_CHANGED")
local objective = Jy.Guide.Current()
Check(objective and objective.stops[1][2] == DUSKWOOD, "an exact objective takes priority over entrance guidance")
Jy.Guide.Cancel()

tracking = 110
Fire("SUPER_TRACKING_CHANGED")
local alternative = Jy.Guide.Current()
Check(alternative and alternative.stops[1][2] == DARNASSUS,
    "a completed quest chooses its faction's turn-in over the closer enemy and objective")
Jy.Guide.Cancel()
tracking = 111
Fire("SUPER_TRACKING_CHANGED")
local unfinished = Jy.Guide.Current()
Check(unfinished and unfinished.stops[1][2] == DUSKWOOD, "an unfinished quest follows its objective before alternative turn-ins")
Jy.Guide.Cancel()
tracking = 112
Fire("SUPER_TRACKING_CHANGED")
Check(not Jy.Guide.Current(), "an alternative for the opposite faction never becomes a destination")
env.UnitFactionGroup = function() return "Horde" end
tracking = 113
Fire("SUPER_TRACKING_CHANGED")
local horde = Jy.Guide.Current()
Check(horde and horde.stops[1][2] == DARNASSUS, "Horde chooses its own alternative turn-in")
Jy.Guide.Cancel()
env.UnitFactionGroup = function() return "Alliance" end

tracking = 114
Fire("SUPER_TRACKING_CHANGED")
Check(not Jy.Guide.Current(), "a completed quest without a turn-in never returns to its objective or vendor")
tracking = 115
Fire("SUPER_TRACKING_CHANGED")
Check(not Jy.Guide.Current(), "a completed quest with only an enemy turn-in never falls back to its objective")
tracking = 116
Fire("SUPER_TRACKING_CHANGED")
local liveEnd = Jy.Guide.Current()
Check(liveEnd and liveEnd.stops[1][2] == DARNASSUS, "a completed quest still uses the game's waypoint when its static turn-in is unknown")
Jy.Guide.Cancel()

-- A pin you put on the map yourself becomes a journey; our own pins do not start another.
Jy.Guide.Cancel()
here = { x = -4821.8, y = -1155.4, c = 0 }
env.C_Map.SetUserWaypoint({ map = DARNASSUS, x = 0.5, y = 0.5 })
RunTimers()
Check(Jy.Guide.Current() and Jy.Guide.Current().title == "Map Pin", "a pin set on the map starts a journey to it")
local pinJourney = Jy.Guide.Current()
RunTimers()
Check(Jy.Guide.Current() == pinJourney, "and the pin the journey puts up does not start another")
Jy.Settings.Set("mapPins", false)
Jy.Guide.Cancel()
env.C_Map.SetUserWaypoint({ map = DARNASSUS, x = 0.5, y = 0.5 })
RunTimers()
Check(not Jy.Guide.Current(), "with Journeys to Map Pins off, a pin is left alone")
Jy.Settings.Set("mapPins", true)
env.C_Map.ClearUserWaypoint()
RunTimers()
rxpPin = true
env.C_Map.SetUserWaypoint({ map = DARNASSUS, x = 0.5, y = 0.5 })
RunTimers()
Check(not Jy.Guide.Current(), "a pin RestedXP's guide puts down is not a journey")
rxpPin = false
env.C_Map.ClearUserWaypoint()

-- Removing the pin yourself ends its journey; the game clearing it as you arrive does not.
local function PinJourney()
    now = now + 1
    env.C_Map.SetUserWaypoint({ map = DARNASSUS, x = 0.5, y = 0.5 })
    RunTimers()
    now = now + 1
    return Jy.Guide.Current() ~= nil and current ~= nil
end
Check(PinJourney(), "a pin journey for the removal test")
env.C_Map.ClearUserWaypoint()
RunTimers()
Check(not Jy.Guide.Current() and current == nil, "removing its pin ends it, and the pin stays gone")
Check(PinJourney(), "a pin journey for the arrival test")
Fire("NAVIGATION_DESTINATION_REACHED", true)
env.C_Map.ClearUserWaypoint()
RunTimers()
RunTimers()
Check(Jy.Guide.Current() and current ~= nil, "a pin cleared as the game arrives: the journey goes on")
Jy.Guide.Cancel()
Check(PinJourney(), "a pin journey for the arrival heard after the clear")
env.C_Map.ClearUserWaypoint()
Fire("NAVIGATION_DESTINATION_REACHED", false)
RunTimers()
RunTimers()
Check(Jy.Guide.Current() ~= nil, "the arrival heard after the clear, in the same frame, still counts")
Jy.Guide.Cancel()
Check(PinJourney(), "a pin journey for the tram test")
here = { x = 20, y = 30, c = 369 }
env.C_Map.ClearUserWaypoint()
RunTimers()
Check(Jy.Guide.Current() ~= nil, "a pin cleared off the continents leaves the journey to hold")
Jy.Guide.Cancel()
env.C_Map.ClearUserWaypoint()
here = { x = -4821.8, y = -1155.4, c = 0 }

-- Inside the tram (an instance, outside the continents) the journey holds, and picks up on the way out.
Check(ns.PlaceWaypoint(unpack(DESTINATION)) and Jy.Guide.Current(), "a journey for the tram test")
local legs = #Jy.Guide.Current().plan.legs
here = { x = 20, y = 30, c = 369 }
Fire("PLAYER_ENTERING_WORLD")
RunTimers()
Check(Jy.Guide.Current() and #Jy.Guide.Current().plan.legs == legs and Jy.Guide.Current().waiting,
    "in an instance the journey is kept, not given up")
Tick()
Check(Jy.Guide.Current() and Jy.Guide.Current().waiting, "and the ticker leaves it alone")
here = { x = -8346.5, y = 514.0, c = 0 }
Fire("PLAYER_ENTERING_WORLD")
RunTimers()
Check(Jy.Guide.Current() and not Jy.Guide.Current().waiting, "out of the instance it plans again")

-- The ticker plans again as you move, and a plain waypoint is cleared on arrival.
local planned = Jy.Guide.Current().plan
for _ = 1, 3 do Tick() end
Check(Jy.Guide.Current().plan == planned, "standing still, it is not planned again")
here = { x = here.x + 20, y = here.y, c = here.c }
for _ = 1, 3 do Tick() end
Check(Jy.Guide.Current().plan ~= planned, "every few seconds on the move it is planned again from where you stand")
local kept = Jy.Guide.Current().plan
local realPlan = Jy.Planner.Plan
Jy.Planner.Plan = function() return nil end
here = { x = here.x + 20, y = here.y, c = here.c }
for _ = 1, 3 do Tick() end
Jy.Planner.Plan = realPlan
Check(Jy.Guide.Current() and Jy.Guide.Current().plan == kept, "a plan that finds no way keeps the journey and its last plan")
Jy.Guide.Cancel()
here = { x = -4821.8, y = -1155.4, c = 0 }
Check(ns.PlaceWaypoint(unpack(DESTINATION)) and Jy.Guide.Current() and current, "a journey with its pin up")
here = { x = 9945.0, y = 2490.0, c = 1 }
Tick()
Check(not Jy.Guide.Current() and current == nil, "arriving, found by the ticker, ends it and clears the pin")
here = { x = -4821.8, y = -1155.4, c = 0 }
Tick()

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

local realPath, realCost = Jy.Walk.Path, Jy.Walk.Cost
local WALK_START_X, WALK_START_Y = -4821.8, -1155.4
local WALK_MID_X, WALK_MID_Y = WALK_START_X - 30, WALK_START_Y
local WALK_END_X, WALK_END_Y = WALK_START_X - 60, WALK_START_Y
local reachesFor = {}
Jy.Walk.From = function(spot)
    local key = spot.x .. "," .. spot.y
    reachesFor[key] = (reachesFor[key] or 0) + 1
    return { c = spot.c, x = spot.x, y = spot.y }
end
Jy.Walk.Path = function(a, b) return { a.x, a.y, WALK_MID_X, WALK_MID_Y, b.x, b.y } end
Jy.Walk.Cost = function(_, a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return nil end
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end
MAPS[IRONFORGE] = { c = 0, x = WALK_END_X, y = WALK_END_Y }
here = { x = WALK_START_X, y = WALK_START_Y, c = 0 }
Check(ns.PlaceWaypoint("Nearby Spot", IRONFORGE, 50, 50), "a short walk-only journey")
Check(Jy.Guide.Current() ~= nil, "it starts a journey")
Check(current and math.abs(current.position.x - WALK_END_X / SCALE) < 1e-6, "the waypoint goes where the walk ends, not on its bends")
here = { x = WALK_MID_X, y = WALK_MID_Y, c = 0 }
Fire("NAVIGATION_DESTINATION_REACHED", false)
RunTimers()
Check(Jy.Guide.Current() ~= nil, "not there yet, at the walk's middle corner")
Check(reachesFor[WALK_END_X .. "," .. WALK_END_Y] == 1 and reachesFor[WALK_MID_X .. "," .. WALK_MID_Y] == 1,
    "planning again walks out from where you stand, keeping the journey's own reach for where it ends")
here = { x = WALK_END_X, y = WALK_END_Y, c = 0 }
Fire("NAVIGATION_DESTINATION_REACHED", false)
RunTimers()
Check(not Jy.Guide.Current(), "arriving at the walk's last corner ends the journey")
Check(current == nil, "and clears the game's waypoint, instead of leaving the pin where you now stand")
Jy.Settings.Set("stepEnds", false)
here = { x = WALK_START_X, y = WALK_START_Y, c = 0 }
Check(ns.PlaceWaypoint("Nearby Spot", IRONFORGE, 50, 50) and current and math.abs(current.position.x - WALK_MID_X / SCALE) < 1e-6,
    "with Waypoint Only Where Steps End off, it goes on each bend")
Jy.Guide.Cancel()
Jy.Settings.Set("stepEnds", true)

here = { x = -8835.6, y = 489.3, c = 0 }
local flights = account.journeyFlights["Glyadin-Forever"]
account.journeyFlights["Glyadin-Forever"] = {}
local hintBefore = #printed
Check(ns.SetGuideWaypoint("Far Spot", IRONFORGE, 50, 50, { guide = true, title = "Far Spot" }) and Jy.Guide.Current()
    and #printed == hintBefore, "a guide journey never prints the flight point hint")
ns.ClearGuideWaypoint()
Check(ns.PlaceWaypoint("Far Spot", IRONFORGE, 50, 50), "a journey by the tram")
Check(printed[#printed] and printed[#printed]:find("flight points", 1, true), "with no flight points known, it says how to learn them")
local tramLegs = Jy.Guide.Current().plan.legs
Check(tramLegs[2].mode == "tram" and tramLegs[3].mode == "walk" and tramLegs[3].corners, "the walk after the tram has its own path")
local points = Jy.Guide.Points()
Check(points[#points].walk and points[#points - 1].x == WALK_MID_X, "the route draws that walk's bends")
local rides = 0
for _, p in ipairs(points) do
    if p.mode == "tram" then rides = rides + 1 end
end
Check(rides == 1, "and the tram as a ride")
Jy.Guide.Cancel()
account.journeyFlights["Glyadin-Forever"] = flights
Jy.Walk.Path, Jy.Walk.Cost = realPath, realCost

Check(Jy.Guide.LegText({ mode = "lift", name = "The Rise" }) == "Lift to The Rise", "a lift step reads as one")

-- On the boat the plan holds: out on the water it is not made again, and reaching the far dock makes it again.
Jy.Walk.From = realFrom
here = { x = -8654.5, y = 1344.4, c = 0 }
Check(ns.PlaceWaypoint(unpack(DESTINATION)) and Title() == "Boat to Auberdine" and Jy.Guide.Current().ride,
    "at the Stormwind dock the boat is the next thing to do: " .. tostring(Title()))
local aboard = Jy.Guide.Current().plan
local realAshore = Jy.Walk.Ashore
Jy.Walk.Ashore = function() return false end
here = { x = -8700.0, y = 1700.0, c = 0 }
for _ = 1, 3 do Tick() end
Fire("PLAYER_ENTERING_WORLD")
RunTimers()
Check(Jy.Guide.Current().plan == aboard and Title() == "Boat to Auberdine", "out on the water the boat stays the plan")
here = { x = 6548.3, y = 942.2, c = 1 }
Fire("NAVIGATION_DESTINATION_REACHED", false)
RunTimers()
Check(Jy.Guide.Current().plan ~= aboard and not Jy.Guide.Current().ride, "reaching the far dock plans again: " .. tostring(Title()))
Jy.Walk.Ashore = realAshore
Jy.Guide.Cancel()

-- A flight point learned at a flight master plans the journey again, and a flight is drawn through its stops.
local MENETHIL, DARKSHIRE_FLIGHT = { c = 0, x = -3793.4, y = -782.4 }, 12
local nodes = {}
env.GetTaxiMapID = function() return EASTERN_KINGDOMS end
env.C_TaxiMap = { GetAllTaxiNodes = function() return nodes end }
here = { x = MENETHIL.x, y = MENETHIL.y, c = MENETHIL.c }
Check(ns.PlaceWaypoint("Darkshire", DUSKWOOD, 50, 50) and Jy.Guide.Current(), "a journey to Duskwood")
local unlearned = Jy.Guide.Current().plan
Check(unlearned.legs[#unlearned.legs - 1].name ~= "Darkshire, Duskwood", "with Darkshire's flight point unknown, it does not fly there")
nodes = { { nodeID = 6, state = 1 } }
Fire("TAXIMAP_OPENED")
RunTimers()
Fire("TAXIMAP_CLOSED")
Check(Jy.Guide.Current().plan == unlearned, "a flight master's map with nothing new leaves the plan alone")
nodes = { { nodeID = DARKSHIRE_FLIGHT, state = 1 } }
Fire("TAXIMAP_OPENED")
RunTimers()
Fire("TAXIMAP_CLOSED")
local learnedPlan = Jy.Guide.Current().plan
local flight = learnedPlan.legs[1]
Check(learnedPlan ~= unlearned and flight.mode == "fly" and flight.name == "Darkshire, Duskwood",
    "learning Darkshire's flight point plans again, flying there")
local stopsAt = {}
for _, p in ipairs(Jy.Guide.Points()) do
    if p.mode == "fly" then stopsAt[#stopsAt + 1] = p.x end
end
Check(#stopsAt == 3 and stopsAt[1] == ns.JourneyNetwork.flights[6][3] and stopsAt[2] == ns.JourneyNetwork.flights[2][3],
    "and the flight is drawn through Ironforge and Stormwind, where it stops: " .. #stopsAt)
Jy.Guide.Cancel()
account.journeyFlights["Glyadin-Forever"][DARKSHIRE_FLIGHT] = nil

-- A guide destination is a journey too, and every step it shows carries the guide's details.
here = { x = -4821.8, y = -1155.4, c = 0 }
local guide = { guide = true, quest = 7, objectives = "0/10 Bandits", title = "Mathrengyl Bearwalker" }
tracking = 101
Fire("SUPER_TRACKING_CHANGED")
ns.ClearWaypoint()
Check(Jy.Guide.Dismissed() == 101, "a quest journey dismissed before the guide takes over")
Check(ns.SetGuideWaypoint("Mathrengyl Bearwalker", DARNASSUS, 50, 50, guide), "a guide destination is placed")
local guided = Jy.Guide.Current()
Check(guided and guided.details == guide and Title() == "Deeprun Tram to Stormwind",
    "with Journeys on, the guide destination becomes a journey: " .. tostring(Title()))
Check(ns.placedWaypoint.details == guide and ns.GuideWaypointIsCurrent(), "its first step is the guide's waypoint")
ns.ClearGuideWaypoint()
Check(not Jy.Guide.Current() and current == nil, "clearing the guide waypoint ends its journey")
Fire("SUPER_TRACKING_CHANGED")
Check(Jy.Guide.Dismissed() == 101 and not Jy.Guide.Current(), "and the dismissed quest stays dismissed")
tracking = 0
Check(ns.SetGuideWaypoint("Mathrengyl Bearwalker", DARNASSUS, 50, 50, guide) and Jy.Guide.Current(), "a guide journey again")
current = nil
ns.ClearGuideWaypoint()
Check(not Jy.Guide.Current(), "a guide journey with nothing placed yet still ends when the guide lets go")
Check(ns.SetGuideWaypoint("Mathrengyl Bearwalker", DARNASSUS, 50, 50, guide) and Jy.Guide.Current(), "and again")
here = { x = 9945.0, y = 2490.0, c = 1 }
Fire("PLAYER_ENTERING_WORLD")
RunTimers()
Check(not Jy.Guide.Current() and current and current.uiMapID == DARNASSUS and ns.placedWaypoint.details == guide
    and ns.GuideWaypointIsCurrent(), "arriving keeps the guide destination up until the guide moves on")
here = { x = -4821.8, y = -1155.4, c = 0 }
ns.ClearGuideWaypoint()
local printedBefore = #printed
Jy.Planner.Plan = function() return nil end
Check(ns.SetGuideWaypoint("Mathrengyl Bearwalker", DARNASSUS, 50, 50, guide) and not Jy.Guide.Current()
    and ns.placedWaypoint.details == guide and ns.placedWaypoint.x == 50, "no way found: the plain guide waypoint")
Check(#printed == printedBefore, "and the guide feed says nothing in chat about it")
Jy.Planner.Plan = realPlan
ns.ClearGuideWaypoint()

Jy.Settings.Set("enabled", false)
Check(not Jy.Guide.Current(), "turning Journeys off ends the journey")
Check(ns.SetGuideWaypoint("Mathrengyl Bearwalker", DARNASSUS, 50, 50, guide) and not Jy.Guide.Current()
    and ns.placedWaypoint.details == guide and ns.placedWaypoint.x == 50, "with Journeys off, the plain guide waypoint")
ns.ClearGuideWaypoint()

print(("journeys guide: %d checks passed"):format(checks))

-- Run with Lua 5.1 from the repository root: no waypoint change from addon code while the world
-- map is open. USER_WAYPOINT_UPDATED is a synchronous event, so a change made then redraws the
-- map's own waypoint pin inside our call and taints it, and the game blocks that pin's Share
-- (CopyToClipboard). ns.PlaceWaypoint, routes and ns.ClearWaypoint wait for the map to close,
-- the latest change winning and a newer one of the game's dropping it; ns.WaypointLink gives no
-- link while it is open. Only Core/Waypoint.lua may set or clear the waypoint.
local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local frames = {}
local function NewFrame()
    local f = { events = {}, scripts = {} }
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    frames[#frames + 1] = f
    return f
end
local function Fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] then f.scripts.OnEvent(f, event, ...) end
    end
end

local calls = { set = 0, clear = 0, track = 0, untrack = 0 }
local current, printed = nil, {}
local hooks = {}
local mapOpen = false
local WorldMapFrame = {}
function WorldMapFrame:IsVisible() return mapOpen end
function WorldMapFrame:HookScript(script, fn)
    hooks[script] = hooks[script] or {}
    table.insert(hooks[script], fn)
end
local providers, pins, shownMap = {}, {}, 1454
function WorldMapFrame:AddDataProvider(provider) providers[#providers + 1] = provider end
local canvas = {}
function canvas:GetMapID() return shownMap end
function canvas:RemoveAllPinsByTemplate() pins = {} end
function canvas:AcquirePin()
    local pin = {}
    pin.SetPosition = function(p, x, y) p.x, p.y = x, y end
    pins[#pins + 1] = pin
    return pin
end
local function CloseMap()
    mapOpen = false
    for _, fn in ipairs(hooks.OnHide or {}) do fn(WorldMapFrame) end
end

local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    Print = function(msg) printed[#printed + 1] = msg end,
    WaypointPinOn = function() return true end,
}
local env = setmetatable({
    NaowhForever = ns,
    WorldMapFrame = WorldMapFrame,
    CreateFrame = NewFrame,
    CreateFromMixins = function(...)
        local t = {}
        for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do t[k] = v end end
        return t
    end,
    MapCanvasPinMixin = {},
    MapCanvasDataProviderMixin = { GetMap = function() return canvas end },
    C_Timer = { After = function() end },
    C_Map = {
        CanSetUserWaypointOnMap = function() return true end,
        SetUserWaypoint = function(point)
            calls.set = calls.set + 1
            current = { uiMapID = point.uiMapID, position = { x = point.position.x, y = point.position.y } }
            Fire("USER_WAYPOINT_UPDATED")
        end,
        ClearUserWaypoint = function()
            calls.clear = calls.clear + 1
            current = nil
            Fire("USER_WAYPOINT_UPDATED")
        end,
        GetUserWaypoint = function() return current end,
        GetUserWaypointHyperlink = function()
            return current and ("|Hworldmap:%d|h[Map Pin]|h"):format(current.uiMapID)
        end,
        GetMapInfo = function() return { name = "Orgrimmar" } end,
        GetWorldPosFromMapPos = function() return nil end,
    },
    CreateVector2D = function(x, y) return { x = x, y = y } end,
    C_SuperTrack = {
        SetSuperTrackedUserWaypoint = function() calls.track = calls.track + 1 end,
        ClearAllSuperTracked = function() calls.untrack = calls.untrack + 1 end,
    },
    UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { uiMapID = map, position = { x = x, y = y } } end },
}, { __index = _G })
env._G = env
local f = assert(io.open("Core/Waypoint.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local chunk = assert(loadstring(source, "Core/Waypoint.lua"))
setfenv(chunk, env)
chunk()

Check(ns.PlaceWaypoint("Rwag", 1411, 41.3, 68.0), "placed with the map closed")
Check(calls.set == 1 and calls.track == 1 and ns.placedWaypoint.title == "Rwag", "set at once")
Check(hooks.OnHide == nil, "nothing hooked on the map until a change has to wait")

mapOpen = true
Check(ns.PlaceWaypoint("Hanashi", 1454, 81.5, 19.6, " (Weapon Master)", 132), "placed with the map open")
Check(calls.set == 1 and calls.track == 1, "not set while the map is open")
Check(#providers == 1 and #pins == 1 and math.abs(pins[1].x - 0.815) < 1e-9 and math.abs(pins[1].y - 0.196) < 1e-9, "a preview pin on the open map")
Check(printed[#printed]:find("when you close the map", 1, true) ~= nil, "the chat line says when")
Check(ns.PlaceWaypoint("Kaja", 1454, 50.0, 50.0, " (Mining Trainer)", 136248), "another while it is open")
Check(calls.set == 1 and #hooks.OnHide == 1, "still not set, and the map hooked once")
Check(#providers == 1 and #pins == 1 and pins[1].x == 0.5, "one preview pin, at the latest spot")
shownMap = 1411
providers[1]:RefreshAllData()
Check(#pins == 0, "no preview on a map it is not on")
shownMap = 1454
CloseMap()
Check(#pins == 0, "the preview goes as the map closes")
Check(calls.set == 2 and calls.track == 2, "set once as the map closes")
Check(current.uiMapID == 1454 and current.position.x == 0.5 and ns.placedWaypoint.title == "Kaja"
    and ns.placedWaypoint.icon == 136248, "the latest spot, with its title and icon")
CloseMap()
Check(calls.set == 2, "closing again does nothing")

mapOpen = true
ns.ClearWaypoint()
Check(calls.clear == 0 and calls.untrack == 0, "no clear while the map is open")
CloseMap()
Check(calls.clear == 1 and calls.untrack == 1 and current == nil, "cleared as it closes")
mapOpen = false
ns.ClearWaypoint()
Check(calls.clear == 2 and calls.untrack == 2, "cleared at once with the map closed")

mapOpen = true
ns.PlaceWaypoint("Hanashi", 1454, 81.5, 19.6)
Check(#pins == 1, "previewed")
env.C_Map.SetUserWaypoint(env.UiMapPoint.CreateFromCoordinates(1411, 0.25, 0.75))
Check(#pins == 0, "a newer waypoint of the game's takes the preview away")
local sets = calls.set
CloseMap()
Check(calls.set == sets and current.uiMapID == 1411, "a newer waypoint of the game's drops the waiting one")
Check(#hooks.OnHide == 1, "and the map is still hooked only once")

mapOpen = true
sets = calls.set
Check(ns.WaypointLink(1454, 81.5, 19.6) == nil, "no link while the map is open")
Check(calls.set == sets and calls.clear == 2 and current.uiMapID == 1411, "and the waypoint untouched")
mapOpen = false
local link = ns.WaypointLink(1454, 81.5, 19.6)
Check(link ~= nil and link:find("1454", 1, true) ~= nil and current.uiMapID == 1411, "a link with it closed, put back")

mapOpen = true
local STOPS = {
    { "Grezz Ragefist", 1454, 80.0, 30.0, " (Warrior Trainer)" },
    { "Hanashi", 1454, 81.5, 19.6, " (Weapon Master)" },
}
sets = calls.set
Check(ns.PlaceWaypointRoute("Training run", STOPS), "a route with the map open")
Check(calls.set == sets and ns.WaypointRoute() == "Training run", "its first stop waits, the route stays")
CloseMap()
Check(calls.set == sets + 1 and ns.placedWaypoint.title == "Grezz Ragefist" and select(2, ns.WaypointRoute()) == 1,
    "the first stop is set as the map closes, and the route goes on")

-- Guide ownership and context survive the map-open hold and never clear a manual replacement.
mapOpen = true
sets = calls.set
local details = { guide = true, quest = 7, objectives = "0/10 Bandits" }
local journeyCancels = 0
ns.JourneyCancel = function() journeyCancels = journeyCancels + 1 end
Check(ns.SetGuideWaypoint("Guide quest", 1454, 30, 40, details), "guide waypoint queued")
Check(journeyCancels == 1, "explicit guide destination ends a competing journey")
Check(calls.set == sets and ns.GuideWaypointIsCurrent(), "guide uses the existing map-open hold")
details.objectives = "1/10 Bandits"
CloseMap()
Check(ns.GuideWaypointIsCurrent() and ns.placedWaypoint.details == details
    and ns.placedWaypoint.details.objectives == "1/10 Bandits", "guide context survives deferred placement")
mapOpen = true
local guideClears = calls.clear
ns.ClearGuideWaypoint()
Check(calls.clear == guideClears, "guide clear waits while map is open")
CloseMap()
Check(calls.clear == guideClears + 1 and not ns.GuideWaypointIsCurrent(), "owned guide clears when map closes")
ns.SetGuideWaypoint("Guide quest", 1454, 30, 40, details)
env.C_Map.SetUserWaypoint(env.UiMapPoint.CreateFromCoordinates(1411, 0.25, 0.75))
guideClears = calls.clear
ns.ClearGuideWaypoint()
Check(calls.clear == guideClears and current.uiMapID == 1411, "guide clear preserves a user's replacement")

ns.SetGuideWaypoint("Guide quest", 1454, 30, 40, details)
env.C_SuperTrack.IsSuperTrackingUserWaypoint = function() return false end
guideClears = calls.clear
Check(not ns.GuideWaypointIsCurrent(), "ending native user-waypoint tracking ends guide ownership")
ns.ClearGuideWaypoint()
Check(calls.clear == guideClears, "an untracked guide pin is left alone")

env.C_Map.SetUserWaypoint(env.UiMapPoint.CreateFromCoordinates(1411, 0.25, 0.75))
mapOpen = true
sets, guideClears = calls.set, calls.clear
ns.SetGuideWaypoint("Guide quest", 1454, 30, 40, details)
ns.ClearGuideWaypoint()
Check(not ns.GuideWaypointIsCurrent() and calls.clear == guideClears,
    "disabling a queued guide discards the pending placement without clearing the actual manual pin")
CloseMap()
Check(calls.set == sets and current.uiMapID == 1411 and calls.clear == guideClears,
    "closing the map after cancelling a queued guide preserves the original manual pin")

local TocFiles = dofile("Tools/regression/toc_files.lua")
local OWNER = "Core/Waypoint.lua"
local scanned = 0
for _, path in ipairs(TocFiles("%.lua$")) do
    if not path:find("^Libs/") then
        local file = assert(io.open(path, "rb"))
        local text = file:read("*a")
        file:close()
        scanned = scanned + 1
        if path ~= OWNER then
            Check(not text:find("C_Map.SetUserWaypoint", 1, true) and not text:find("C_Map.ClearUserWaypoint", 1, true),
                path .. " changes the waypoint itself; use ns.PlaceWaypoint or ns.ClearWaypoint")
        end
    end
end
Check(scanned > 50, "the addon's files were scanned")

print(("test-waypoint-map: %d checks passed"):format(checks))

-- Waypoint.lua: a waypoint on the map for any module (ns.PlaceWaypoint), TomTom's when loaded.
local ns = _G.NaowhForever

local PERCENT = 100
local ARRIVED_WITHIN = 0.05
local ROUTE_MIN_STOPS = 2
local STOP_FIELDS = 6
local TOMTOM_FROM = "Naowh Forever"
local TEXT_SPOT = "%s%s: %s %.1f, %.1f"
local TEXT_TOMTOM = ns.L("TomTom waypoint for ")
local TEXT_PLACED = ns.L("Waypoint for ")
local TEXT_ROUTE_STOP = ns.L("%s, stop %d of %d: %s%s")
local TEXT_NO_WAYPOINTS = ns.L("That map does not take waypoints.")
local TEXT_LATER = ns.L(" (placed when you close the map)")

ns.WAYPOINT_HOLD = 4

local tomtomWaypoint
local route
local arrivals = 0
local watch = CreateFrame("Frame")
local CLEAR = {}
local pending, held

local function MapOpen()
    return WorldMapFrame ~= nil and WorldMapFrame:IsVisible()
end

local function MapPoint(map, x, y)
    return UiMapPoint.CreateFromCoordinates(map, x / PERCENT, y / PERCENT)
end

function ns.CanPlaceWaypoint(map)
    return (TomTom and TomTom.AddWaypoint) ~= nil or C_Map.CanSetUserWaypointOnMap(map)
end

function ns.WaypointText(title, map, x, y, note)
    local info = C_Map.GetMapInfo(map)
    return TEXT_SPOT:format(title, note or "", info and info.name or "", x, y)
end

local function PlaceTomTom(title, map, x, y, note)
    if tomtomWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, tomtomWaypoint) end
    local ok, uid = pcall(TomTom.AddWaypoint, TomTom, map, x / PERCENT, y / PERCENT, {
        title = title .. (note or ""), from = TOMTOM_FROM, persistent = false, crazy = true,
        silent = true,
    })
    if not ok then return false end
    tomtomWaypoint = uid
    ns.Print(TEXT_TOMTOM .. ns.WaypointText(title, map, x, y, note))
    return true
end

function ns.WaypointLink(map, x, y)
    if MapOpen() or not C_Map.CanSetUserWaypointOnMap(map) then return nil end
    local previous = C_Map.GetUserWaypoint()
    C_Map.SetUserWaypoint(MapPoint(map, x, y))
    local link = C_Map.GetUserWaypointHyperlink()
    if previous then C_Map.SetUserWaypoint(previous) else C_Map.ClearUserWaypoint() end
    return link
end

local function SetNow(title, map, x, y, note, icon)
    C_Map.SetUserWaypoint(MapPoint(map, x, y))
    if C_SuperTrack then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    ns.placedWaypoint = { title = title, note = note, icon = icon, map = map, x = x, y = y }
end

local function ClearNow()
    C_Map.ClearUserWaypoint()
    if C_SuperTrack then C_SuperTrack.ClearAllSuperTracked() end
end

local function TrackNow(quest)
    C_Map.ClearUserWaypoint()
    C_SuperTrack.SetSuperTrackedQuestID(quest)
end

local function Flush()
    local change = pending
    if not change then return end
    pending = nil
    held:UnregisterAllEvents()
    if change == CLEAR then
        ClearNow()
    elseif change.quest then
        TrackNow(change.quest)
    else
        SetNow(unpack(change, 1, STOP_FIELDS))
    end
end

local function DropPending()
    pending = nil
    held:UnregisterAllEvents()
end

local function Hold(change)
    pending = change
    if not held then
        held = CreateFrame("Frame")
        held:SetScript("OnEvent", DropPending)
        WorldMapFrame:HookScript("OnHide", Flush)
    end
    held:RegisterEvent("USER_WAYPOINT_UPDATED")
end

local function SetGameWaypoint(title, map, x, y, note, icon)
    if not MapOpen() then
        SetNow(title, map, x, y, note, icon)
        return false
    end
    Hold({ title, map, x, y, note, icon })
    return true
end

function ns.TrackQuest(quest)
    if MapOpen() then Hold({ quest = quest }) else TrackNow(quest) end
end

function ns.ClearWaypoint()
    if ns.JourneyCancel then ns.JourneyCancel() end
    if MapOpen() then Hold(CLEAR) else ClearNow() end
end

local function EndRoute()
    route = nil
    watch:UnregisterAllEvents()
end

function ns.ShowJourneyStep(title, map, x, y, note, icon)
    EndRoute()
    if not C_Map.CanSetUserWaypointOnMap(map) then return false end
    SetGameWaypoint(title, map, x, y, note, icon)
    return true
end

function ns.PlaceWaypoint(title, map, x, y, note, icon)
    EndRoute()
    if ns.JourneyTo and ns.JourneyTo(title, { { title, map, x, y, note, icon } }) then return true end
    local pin = ns.WaypointPinOn and ns.WaypointPinOn()
    if not pin and TomTom and TomTom.AddWaypoint and PlaceTomTom(title, map, x, y, note) then return true end
    if not C_Map.CanSetUserWaypointOnMap(map) then
        ns.Print(TEXT_NO_WAYPOINTS)
        return false
    end
    local later = SetGameWaypoint(title, map, x, y, note, icon)
    ns.Print(TEXT_PLACED .. ns.WaypointText(title, map, x, y, note) .. (later and TEXT_LATER or ""))
    return true
end

local function Near(position, spot)
    return math.abs(position * PERCENT - spot) < ARRIVED_WITHIN
end

local function OnStop(point)
    local stop = route.stops[route.at]
    return point ~= nil and point.uiMapID == stop[2] and Near(point.position.x, stop[3])
        and Near(point.position.y, stop[4])
end

local function PlaceStop()
    local stop = route.stops[route.at]
    if not C_Map.CanSetUserWaypointOnMap(stop[2]) then
        ns.Print(TEXT_NO_WAYPOINTS)
        EndRoute()
        return false
    end
    local later = SetGameWaypoint(stop[1], stop[2], stop[3], stop[4], stop[5], stop[6])
    ns.Print(TEXT_ROUTE_STOP:format(route.title, route.at, #route.stops,
        ns.WaypointText(stop[1], stop[2], stop[3], stop[4], stop[5]), later and TEXT_LATER or ""))
    return true
end

local function NextStopAfterHold(this)
    if this ~= arrivals or not route then return end
    if route.at == #route.stops then EndRoute() return end
    route.at = route.at + 1
    PlaceStop()
end

local function OnRouteEvent(_, event, isWaypoint)
    if event == "USER_WAYPOINT_UPDATED" then
        if not OnStop(C_Map.GetUserWaypoint()) then EndRoute() end
    elseif not isWaypoint and OnStop(C_Map.GetUserWaypoint()) then
        arrivals = arrivals + 1
        local this = arrivals
        C_Timer.After(ns.WAYPOINT_HOLD, function() NextStopAfterHold(this) end)
    end
end

watch:SetScript("OnEvent", OnRouteEvent)

function ns.PlaceWaypointRoute(title, stops)
    if ns.JourneyTo and ns.JourneyTo(title, stops) then
        EndRoute()
        return true
    end
    if #stops < ROUTE_MIN_STOPS then
        local stop = stops[1]
        return stop ~= nil and ns.PlaceWaypoint(stop[1], stop[2], stop[3], stop[4], stop[5], stop[6])
    end
    EndRoute()
    route = { title = title, stops = stops, at = 1 }
    watch:RegisterEvent("USER_WAYPOINT_UPDATED")
    watch:RegisterEvent("NAVIGATION_DESTINATION_REACHED")
    return PlaceStop()
end

function ns.WaypointRoute()
    if ns.JourneyStep then
        local title, at, n, nextTitle = ns.JourneyStep()
        if title then return title, at, n, nextTitle end
    end
    if not route then return end
    local nextStop = route.stops[route.at + 1]
    return route.title, route.at, #route.stops, nextStop and nextStop[1]
end

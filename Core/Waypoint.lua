-- Waypoint.lua: a waypoint on the map for any module (ns.PlaceWaypoint, ns.ToggleWaypoint for map pins), TomTom's when loaded.
local ns = _G.NaowhForever

local PERCENT = 100
local ARRIVED_WITHIN = 0.05
local ROUTE_MIN_STOPS = 2
local PLACE_FIELDS = 8
local TOMTOM_FROM = "Naowh Forever"
local TEXT_SPOT = "%s%s: %s %.1f, %.1f"
local TEXT_TOMTOM = ns.L("TomTom waypoint for ")
local TEXT_PLACED = ns.L("Waypoint for ")
local TEXT_ROUTE_STOP = ns.L("%s, stop %d of %d: %s%s")
local TEXT_NO_WAYPOINTS = ns.L("That map does not take waypoints.")
local TEXT_LATER = ns.L(" (placed when you close the map)")
local TEXT_REMOVED = ns.L("Removed the waypoint for ")
local TEXT_REMOVED_LATER = ns.L(" (removed when you close the map)")
local PREVIEW_TEMPLATE = "NaowhForeverWaypointPreviewPinTemplate"
local WORLD_POS_RETURN = 2

ns.WAYPOINT_HOLD = 4

local tomtomWaypoint, tomtomSpot
local route
local arrivals = 0
local watch = CreateFrame("Frame")
local dungeon, wasInside
local CLEAR = {}
local pending, held, preview

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
    tomtomWaypoint, tomtomSpot = uid, { map, x, y }
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

local WatchDungeon

local function SetNow(title, map, x, y, note, icon, clearInside, details)
    ns.placedWaypoint = { title = title, note = note, icon = icon, map = map, x = x, y = y, details = details }
    WatchDungeon(clearInside)
    C_Map.SetUserWaypoint(MapPoint(map, x, y))
    if C_SuperTrack then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
end

local function ClearNow()
    WatchDungeon(false)
    ns.placedWaypoint = nil
    C_Map.ClearUserWaypoint()
    if C_SuperTrack then C_SuperTrack.ClearAllSuperTracked() end
end

local function TrackNow(quest)
    C_Map.ClearUserWaypoint()
    C_SuperTrack.SetSuperTrackedQuestID(quest)
end

NaowhForeverWaypointPreviewPinMixin = CreateFromMixins(MapCanvasPinMixin)

function NaowhForeverWaypointPreviewPinMixin:OnLoad()
    self:SetScalingLimits(1, 1.0, 1.2)
end

function NaowhForeverWaypointPreviewPinMixin:OnAcquired()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_WAYPOINT_LOCATION")
end

function NaowhForeverWaypointPreviewPinMixin:CheckMouseButtonPassthrough() end

local function PreviewSpot(mapID, map, x, y)
    if map == mapID then return x, y end
    local continent, world = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x, y))
    local pos = continent and world and select(WORLD_POS_RETURN, C_Map.GetMapPosFromWorldPos(continent, world, mapID))
    if not pos then return end
    local px, py = pos:GetXY()
    if px >= 0 and px <= 1 and py >= 0 and py <= 1 then return px, py end
end

local function NewPreview()
    local provider = CreateFromMixins(MapCanvasDataProviderMixin)
    function provider:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate(PREVIEW_TEMPLATE)
    end
    function provider:RefreshAllData()
        self:RemoveAllData()
        if not (pending and pending[2]) then return end
        local map = self:GetMap()
        local x, y = PreviewSpot(map:GetMapID(), pending[2], pending[3] / PERCENT, pending[4] / PERCENT)
        if x then map:AcquirePin(PREVIEW_TEMPLATE):SetPosition(x, y) end
    end
    WorldMapFrame:AddDataProvider(provider)
    return provider
end

local function Flush()
    local change = pending
    if not change then return end
    pending = nil
    held:UnregisterAllEvents()
    preview:RemoveAllData()
    if change == CLEAR then
        ClearNow()
    elseif change.quest then
        TrackNow(change.quest)
    else
        SetNow(unpack(change, 1, PLACE_FIELDS))
    end
end

local function DropPending()
    pending = nil
    held:UnregisterAllEvents()
    preview:RemoveAllData()
end

local function Hold(change)
    pending = change
    if not held then
        held = CreateFrame("Frame")
        held:SetScript("OnEvent", DropPending)
        WorldMapFrame:HookScript("OnHide", Flush)
        preview = NewPreview()
    end
    held:RegisterEvent("USER_WAYPOINT_UPDATED")
    preview:RefreshAllData()
end

local function SetGameWaypoint(title, map, x, y, note, icon, clearInside, details)
    if not MapOpen() then
        SetNow(title, map, x, y, note, icon, clearInside, details)
        return false
    end
    Hold({ title, map, x, y, note, icon, clearInside, details })
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

function ns.ShowJourneyStep(title, map, x, y, note, icon, details)
    EndRoute()
    if not C_Map.CanSetUserWaypointOnMap(map) then return false end
    SetGameWaypoint(title, map, x, y, note, icon, false, details)
    return true
end

function ns.PlaceWaypoint(title, map, x, y, note, icon, clearInside)
    EndRoute()
    if ns.JourneyTo and ns.JourneyTo(title, { { title, map, x, y, note, icon } }) then return true end
    local pin = ns.WaypointPinOn and ns.WaypointPinOn()
    if not pin and TomTom and TomTom.AddWaypoint and PlaceTomTom(title, map, x, y, note) then return true end
    if not C_Map.CanSetUserWaypointOnMap(map) then
        ns.Print(TEXT_NO_WAYPOINTS)
        return false
    end
    local later = SetGameWaypoint(title, map, x, y, note, icon, clearInside)
    ns.Print(TEXT_PLACED .. ns.WaypointText(title, map, x, y, note) .. (later and TEXT_LATER or ""))
    return true
end

local function Near(position, spot)
    return math.abs(position * PERCENT - spot) < ARRIVED_WITHIN
end

local function StillPlaced()
    local point, placed = C_Map.GetUserWaypoint(), ns.placedWaypoint
    return point ~= nil and placed ~= nil and point.uiMapID == placed.map and Near(point.position.x, placed.x)
        and Near(point.position.y, placed.y)
end

local function SameSpot(map, x, y, spotMap, spotX, spotY)
    return map == spotMap and math.abs(x - spotX) < ARRIVED_WITHIN and math.abs(y - spotY) < ARRIVED_WITHIN
end

local function TomTomHere(map, x, y)
    if not (tomtomWaypoint and TomTom and TomTom.RemoveWaypoint) then return false end
    if TomTom.IsValidWaypoint and not TomTom:IsValidWaypoint(tomtomWaypoint) then return false end
    return SameSpot(map, x, y, tomtomSpot[1], tomtomSpot[2], tomtomSpot[3])
end

local function PendingHere(map, x, y)
    return pending ~= nil and pending ~= CLEAR and not pending.quest
        and SameSpot(map, x, y, pending[2], pending[3], pending[4])
end

local function PlacedHere(map, x, y)
    local placed = ns.placedWaypoint
    return pending == nil and StillPlaced() and SameSpot(map, x, y, placed.map, placed.x, placed.y)
end

local function JourneyHere(map, x, y)
    if not ns.JourneyDestination then return false end
    local toMap, toX, toY = ns.JourneyDestination()
    return toMap ~= nil and SameSpot(map, x, y, toMap, toX, toY)
end

function ns.ToggleWaypoint(title, map, x, y, note, icon, clearInside)
    local later = false
    if TomTomHere(map, x, y) then
        pcall(TomTom.RemoveWaypoint, TomTom, tomtomWaypoint)
        tomtomWaypoint, tomtomSpot = nil, nil
    elseif JourneyHere(map, x, y) then
        later = MapOpen()
        ns.ClearWaypoint()
    elseif PendingHere(map, x, y) then
        DropPending()
    elseif PlacedHere(map, x, y) then
        later = MapOpen()
        ns.ClearWaypoint()
    else
        return ns.PlaceWaypoint(title, map, x, y, note, icon, clearInside)
    end
    ns.Print(TEXT_REMOVED .. ns.WaypointText(title, map, x, y, note) .. (later and TEXT_REMOVED_LATER or ""))
    return true
end

function ns.GuideWaypointIsCurrent()
    if pending then return pending[PLACE_FIELDS] and pending[PLACE_FIELDS].guide == true or false end
    if C_SuperTrack.IsSuperTrackingUserWaypoint and not C_SuperTrack.IsSuperTrackingUserWaypoint() then return false end
    local placed = ns.placedWaypoint
    return placed and placed.details and placed.details.guide == true and StillPlaced() or false
end

function ns.SetGuideWaypoint(title, map, x, y, details)
    if not C_Map.CanSetUserWaypointOnMap(map) then return false end
    if ns.JourneyCancel then ns.JourneyCancel() end
    EndRoute()
    if ns.JourneyTo and ns.JourneyTo(title, { { title, map, x, y } }, nil, details) then return true end
    SetGameWaypoint(title, map, x, y, nil, nil, false, details)
    return true
end

function ns.ClearGuideWaypoint()
    local journey = ns.JourneyDetails and ns.JourneyDetails()
    if journey and journey.guide == true and ns.JourneyCancel then ns.JourneyCancel() end
    if pending and pending[PLACE_FIELDS] and pending[PLACE_FIELDS].guide == true then DropPending() end
    if not ns.GuideWaypointIsCurrent() then return end
    ns.ClearWaypoint()
end

local function InDungeon()
    local _, kind = IsInInstance()
    return kind == "party" or kind == "raid"
end

local function OnDungeonEvent()
    local inside = InDungeon()
    local entered = inside and not wasInside
    wasInside = inside
    if entered and StillPlaced() then ns.ClearWaypoint() end
end

function WatchDungeon(on)
    if not on then
        if dungeon then dungeon:UnregisterAllEvents() end
        return
    end
    if not dungeon then
        dungeon = CreateFrame("Frame")
        dungeon:SetScript("OnEvent", OnDungeonEvent)
    end
    wasInside = InDungeon()
    dungeon:RegisterEvent("PLAYER_ENTERING_WORLD")
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

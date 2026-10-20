-- Pins.lua: a pin you put on the map yourself becomes a journey to it.
local ns = _G.NaowhForever

local Jy = ns.Journeys
local S = Jy.Settings
local Guide = Jy.Guide

local PERCENT = 100
local SAME_SPOT = 0.05
local TEXT_PIN = ns.L("Map Pin")

local events

local function On()
    return Jy.On() and S.Get("mapPins")
end

local function Ours(point)
    local placed = ns.placedWaypoint
    return placed ~= nil and placed.map == point.uiMapID
        and math.abs(point.position.x * PERCENT - placed.x) < SAME_SPOT
        and math.abs(point.position.y * PERCENT - placed.y) < SAME_SPOT
end

local function Start()
    local point = C_Map.GetUserWaypoint()
    if not point or Ours(point) or Guide.Current() or ns.RestedXPPin() then return end
    Guide.Start(TEXT_PIN, { { TEXT_PIN, point.uiMapID, point.position.x * PERCENT, point.position.y * PERCENT } })
end

local function OnEvent()
    C_Timer.After(0, Start)
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    events:RegisterEvent("USER_WAYPOINT_UPDATED")
end

S.OnChange(Apply)
hooksecurefunc(ns, "Apply", Apply)
Apply()

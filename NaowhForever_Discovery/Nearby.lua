-- Nearby.lua: a sound and a chat line when you come within range of a library book you still need.
local ns = _G.NaowhForever

local Discovery = ns.Discovery
local C = Discovery.C
local S = Discovery.Settings
local L = Discovery.Library

local INTERVAL = 1
local REARM = 1.5
local BOOK, SPOT, WORLD = 1, 2, 3
local CHANNEL = "Master"
local TEXT_NEARBY = ns.L("Library book nearby: %s, %d yards%s")
local TEXT_PLACE = " - %s"

local ticker, zoneEvents, bagEvents, moveEvents
local zone, targets
local alerted = {}

local function On()
    return S.Get("enabled") and S.Get("nearbySound")
end

local function WorldPos(mapID, x, y)
    local _, pos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
    return pos
end

local function Announce(target, dist)
    if S.Get("nearbyPing") then PlaySound(SOUNDKIT.MAP_PING, CHANNEL) end
    if not S.Get("nearbyChat") then return end
    local place = target[SPOT][C.SPOT_PLACE]
    ns.Print(TEXT_NEARBY:format(target[BOOK].name, math.floor(dist), place and TEXT_PLACE:format(place) or ""))
end

local function Check()
    local here = C_Map.GetPlayerMapPosition(zone, "player")
    local me = here and WorldPos(zone, here:GetXY())
    if not me then return end
    local range = S.Get("nearbyRange")
    local mx, my = me:GetXY()
    for _, target in ipairs(targets) do
        local tx, ty = target[WORLD]:GetXY()
        local dist = math.sqrt((tx - mx) ^ 2 + (ty - my) ^ 2)
        local quest = target[BOOK].quest
        if dist <= range and not alerted[quest] then
            alerted[quest] = true
            Announce(target, dist)
        elseif dist > range * REARM then
            alerted[quest] = nil
        end
    end
end

local function StartTicker()
    ticker = ticker or C_Timer.NewTicker(INTERVAL, Check)
end

local function StopTicker()
    if ticker then ticker:Cancel() end
    ticker = nil
end

local function Stop()
    StopTicker()
    zone, targets = nil, nil
    if bagEvents then bagEvents:UnregisterAllEvents() end
    if moveEvents then moveEvents:UnregisterAllEvents() end
end

local function Targets(id)
    local list = {}
    for _, item in ipairs(L.OnMap(id)) do
        local spot = item[SPOT]
        local pos = WorldPos(id, spot[C.SPOT_X] / C.PERCENT, spot[C.SPOT_Y] / C.PERCENT)
        if pos then list[#list + 1] = { item[BOOK], spot, pos } end
    end
    return list
end

local function Refresh()
    if not On() or IsInInstance() then return Stop() end
    local id = L.PlayerZone()
    local list = Targets(id)
    if #list == 0 then return Stop() end
    zone, targets = id, list
    bagEvents:RegisterEvent("BAG_UPDATE_DELAYED")
    bagEvents:RegisterEvent("QUEST_TURNED_IN")
    moveEvents:RegisterEvent("PLAYER_STARTED_MOVING")
    moveEvents:RegisterEvent("PLAYER_STOPPED_MOVING")
    Check()
    if IsPlayerMoving() then StartTicker() else StopTicker() end
end

local function OnMove(_, event)
    if event == "PLAYER_STARTED_MOVING" then return StartTicker() end
    StopTicker()
    Check()
end

local function Build()
    zoneEvents = CreateFrame("Frame")
    zoneEvents:SetScript("OnEvent", Refresh)
    bagEvents = CreateFrame("Frame")
    bagEvents:SetScript("OnEvent", Refresh)
    moveEvents = CreateFrame("Frame")
    moveEvents:SetScript("OnEvent", OnMove)
end

local function Apply()
    if On() then
        if not zoneEvents then Build() end
        zoneEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
        zoneEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    elseif zoneEvents then
        zoneEvents:UnregisterAllEvents()
    end
    Refresh()
end

local function OnSet(key)
    if key == "enabled" or key == "nearbySound" then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)

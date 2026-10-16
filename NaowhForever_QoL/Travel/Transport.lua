-- Transport.lua: boat and zeppelin estimates from a recorded sighting, on minimap pins at each stop, and its Travel settings.
local ns = _G.NaowhForever

local GetServerTime = GetServerTime
local S = ns.QoLSettings
local T = ns.THEME
local Times = ns.TransportTimes
local Data = ns.TransportData

local PIN_SIZE = 16
local MAX_PINS = 3
local UPDATE_EVERY = 1
local SECONDS_PER_MINUTE = ns.QoLConstants.SECONDS_PER_MINUTE
local HINT = ns.QoLConstants.HINT_RGB
local PLAYER, HORDE = "player", "Horde"
local ARRIVAL, DEPARTURE = "arrival", "departure"
local LEFT_BUTTON = "LeftButton"
local EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS" }
local TEXT_DEPARTS = ns.L("Departs in ~%d:%02d")
local TEXT_ARRIVES = ns.L("Arrives in ~%d:%02d")
local TEXT_NEW = ns.L("Record a sighting")
local TEXT_EXPIRED = ns.L("Estimate out of date")
local TEXT_STALE = ns.L("Server clock changed; record a new sighting.")
local TEXT_LEFT = ns.L("Left-click when it arrives")
local TEXT_RIGHT = ns.L("Right-click when it leaves")

local layer, events
local spots = {}
local elapsed = 0

local function On()
    return S.Get("enabled") == true and S.Get("transportTimers") == true
end

local function Status(key)
    local seconds, kind = Times.Next(key, GetServerTime())
    if seconds then
        local rounded = math.ceil(seconds)
        return (kind == ARRIVAL and TEXT_ARRIVES or TEXT_DEPARTS):format(math.floor(rounded / SECONDS_PER_MINUTE),
            rounded % SECONDS_PER_MINUTE)
    end
    if kind == "stale" then return TEXT_STALE end
    if kind == "expired" then return TEXT_EXPIRED end
    return TEXT_NEW
end

local function ShowTip(pin)
    local routes = Data[pin.key].routes
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:SetText(ns.L(routes[1]), 1, 1, 1)
    for i = 2, #routes do GameTooltip:AddLine(ns.L(routes[i]), 1, 1, 1) end
    GameTooltip:AddLine(Status(pin.key), T.accent.r, T.accent.g, T.accent.b)
    GameTooltip:AddLine(TEXT_LEFT, HINT.r, HINT.g, HINT.b)
    GameTooltip:AddLine(TEXT_RIGHT, HINT.r, HINT.g, HINT.b)
    GameTooltip:Show()
end

local function OnTick(pin, delta)
    elapsed = elapsed + delta
    if elapsed < UPDATE_EVERY then return end
    elapsed = 0
    ShowTip(pin)
end

local function OnEnter(pin)
    elapsed = 0
    ShowTip(pin)
    pin:SetScript("OnUpdate", OnTick)
end

local function OnLeave(pin)
    pin:SetScript("OnUpdate", nil)
    GameTooltip:Hide()
end

local function OnClick(pin, button)
    Times.Record(pin.key, button == LEFT_BUTTON and ARRIVAL or DEPARTURE, GetServerTime())
    ShowTip(pin)
end

local function NewPin()
    local pin = CreateFrame("Button", nil, Minimap)
    pin:SetSize(PIN_SIZE, PIN_SIZE)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pin:SetScript("OnClick", OnClick)
    pin:SetScript("OnEnter", OnEnter)
    pin:SetScript("OnLeave", OnLeave)
    return pin
end

local function Paint(pin, list, i)
    pin.key = list[i]
    ns.TownTravelIcon(pin.icon, Data[pin.key].routes[1])
end

local function XY(list, i)
    local stop = Data[list[i]]
    return stop.mapX, stop.mapY
end

local function Refresh()
    wipe(spots)
    local map = On() and C_Map.GetBestMapForUnit(PLAYER)
    if map then
        local side = UnitFactionGroup(PLAYER) == HORDE and "H" or "A"
        for key, stop in pairs(Data) do
            if stop.map == map and stop.side:find(side, 1, true) then
                if not stop.mapX then
                    local _, pos = C_Map.GetMapPosFromWorldPos(stop.continent, CreateVector2D(stop.x, stop.y), map)
                    stop.mapX, stop.mapY = pos:GetXY()
                end
                spots[#spots + 1] = key
            end
        end
    end
    if not layer and #spots == 0 then return end
    layer = layer or ns.Shared.Parts.MinimapLayer({ max = MAX_PINS, new = NewPin, paint = Paint, xy = XY })
    layer:Set(map, spots, #spots)
end

local function OnEvent(_, event)
    if event == "PLAYER_ENTERING_WORLD" then Times.Prune(GetServerTime()) end
    Refresh()
end

local function Apply()
    if On() then
        if not events then
            events = CreateFrame("Frame")
            events:SetScript("OnEvent", OnEvent)
        end
        for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
        if IsLoggedIn() then Times.Prune(GetServerTime()) end
    elseif events then
        events:UnregisterAllEvents()
    end
    Refresh()
end

local function OnSetting(key)
    if key == "enabled" or key == "transportTimers" then Apply() end
end

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Apply)
Apply()

ns.Shared.Settings.Page("QoL/Travel", S):Card({
    id = "transportTimers", name = "Boat and Zeppelin Timers", order = 13, switch = "transportTimers",
    help = "Shows when boats and zeppelins come and go on the minimap, from arrivals you record.",
})

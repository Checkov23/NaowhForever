-- Transport.lua: boat and zeppelin times, from a ride or a recorded sighting, on minimap pins at each stop, the world map's docks and the Zone Timer, and its Travel settings.
local ns = _G.NaowhForever

local GetServerTime = GetServerTime
local S = ns.QoLSettings
local T = ns.THEME
local UI = ns.UI
local Parts, St = ns.Shared.Parts, ns.Shared.Style
local SameMap = ns.Shared.Places.SameMap
local Times = ns.TransportTimes
local Data = ns.TransportData
local Routes = ns.TransportRoutes
local Ride = ns.TransportRide

local PIN_SIZE = 16
local MAX_PINS = 3
local UPDATE_EVERY = 1
local SECONDS_PER_MINUTE = ns.QoLConstants.SECONDS_PER_MINUTE
local HINT = ns.QoLConstants.HINT_RGB
local WHITE = ns.QoLConstants.WHITE_RGB
local SHIP_RGB = { r = 0.25, g = 0.75, b = 1 }
local LABEL_RGB = { r = 1, g = 0.82, b = 0 }
local DOCKED_RGB = { r = 1, g = 0.82, b = 0 }
local LEAVING_RGB = { r = 1, g = 0.25, b = 0.25 }
local SAILING_RGB = { r = 0.25, g = 1, b = 0.25 }
local LEAVING_SOON = 30
local PLAYER, HORDE = "player", "Horde"
local ARRIVAL, DEPARTURE = "arrival", "departure"
local LEFT_BUTTON = "LeftButton"
local EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS" }
local CITY_ZONES = { [1454] = 1411, [1456] = 1412, [1457] = 1438, [1458] = 1420 }
local COLUMN_GAP = 12
local LINE_BREAK = "\n"
local ROUTE_SEPARATOR = " / "
local TIME_COLOR = "|cff%02x%02x%02x%s|r"
local COLOR_STEPS = 255
local ROUND = ns.QoLConstants.ROUND
local SAMPLE_ROUTE, SAMPLE_WAIT = "Boat to Booty Bay", 42
local MOVER_LABEL = "Boat and Zeppelin Timers"
local PAGE, CARD = "QoL/Travel", "QoL/Travel:transportTimers"
local TEXT_DEPARTS = ns.L("Departs in ~%d:%02d")
local TEXT_ARRIVES = ns.L("Arrives in ~%d:%02d")
local TEXT_NEW = ns.L("Record a sighting")
local TEXT_EXPIRED = ns.L("Estimate out of date")
local TEXT_STALE = ns.L("Server clock changed; record a new sighting.")
local TEXT_LEFT = ns.L("Left-click when it arrives")
local TEXT_RIGHT = ns.L("Right-click when it leaves")
local TEXT_DEPARTURE = ns.L("Departure:")
local TEXT_ARRIVAL = ns.L("Arrival:")
local TEXT_SECONDS = ns.L("%ds")
local TEXT_MINUTES = ns.L("%dm %02ds")
local TEXT_PLACE = ns.L("%s, %s")
local TEXT_UNTIMED = ns.L("Not timed yet")
local TEXT_RIDE = ns.L("Ride it once to time it.")
local TEXT_AT_DOCK = ns.L("Time it from its minimap pin at the dock.")
local TEXT_SHIP_DEPARTS = ns.L("Departs in %d:%02d")
local TEXT_SHIP_ARRIVES = ns.L("Arrives in %d:%02d")

local layer, events, hud, unlocked
local spots, zoneSpots, names, times = {}, {}, {}, {}
local elapsed, hudElapsed = 0, 0

local function On()
    return S.Get("enabled") == true and S.Get("transportTimers") == true
end

local function ZoneOn()
    return On() and S.Get("transportZone") == true
end

local function Color(kind, seconds)
    if kind == ARRIVAL then return SAILING_RGB end
    return seconds > LEAVING_SOON and DOCKED_RGB or LEAVING_RGB
end

local function Countdown(seconds, kind, named)
    local rounded = math.ceil(seconds)
    local text = named and (kind == ARRIVAL and TEXT_SHIP_ARRIVES or TEXT_SHIP_DEPARTS)
        or (kind == ARRIVAL and TEXT_ARRIVES or TEXT_DEPARTS)
    return text:format(math.floor(rounded / SECONDS_PER_MINUTE), rounded % SECONDS_PER_MINUTE)
end

local function Status(key)
    local seconds, kind = Times.Next(key, GetServerTime())
    if seconds then return Countdown(seconds, kind) end
    if kind == "stale" then return TEXT_STALE end
    if kind == "expired" then return TEXT_EXPIRED end
    return TEXT_NEW
end

local function Clock(seconds)
    local rounded = math.ceil(seconds)
    if rounded < SECONDS_PER_MINUTE then return TEXT_SECONDS:format(rounded) end
    return TEXT_MINUTES:format(math.floor(rounded / SECONDS_PER_MINUTE), rounded % SECONDS_PER_MINUTE)
end

local function Place(dock)
    local zone = C_Map.GetMapInfo(Data[dock.stop].map)
    return zone and TEXT_PLACE:format(ns.L(dock.place), zone.name) or ns.L(dock.place)
end

local function ShowRoute(pin, name)
    local now, timed = GetServerTime(), false
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:SetText(ns.L(name), SHIP_RGB.r, SHIP_RGB.g, SHIP_RGB.b)
    for index, dock in ipairs(Routes[name].docks) do
        GameTooltip:AddLine(Place(dock), WHITE.r, WHITE.g, WHITE.b)
        local seconds, kind = Times.Dock(name, index, now)
        if seconds then
            timed = true
            local color = Color(kind, seconds)
            GameTooltip:AddDoubleLine(kind == ARRIVAL and TEXT_ARRIVAL or TEXT_DEPARTURE, Clock(seconds),
                LABEL_RGB.r, LABEL_RGB.g, LABEL_RGB.b, color.r, color.g, color.b)
        else
            GameTooltip:AddLine(kind == "stale" and TEXT_STALE or TEXT_UNTIMED, HINT.r, HINT.g, HINT.b)
        end
    end
    if not timed then
        GameTooltip:AddLine(TEXT_RIDE, HINT.r, HINT.g, HINT.b)
        GameTooltip:AddLine(TEXT_LEFT, HINT.r, HINT.g, HINT.b)
        GameTooltip:AddLine(TEXT_RIGHT, HINT.r, HINT.g, HINT.b)
    end
    GameTooltip:Show()
end

local function ShowTip(pin)
    local name = Times.RouteAt(pin.key)
    if name then return ShowRoute(pin, name) end
    local routes = Data[pin.key].routes
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:SetText(ns.L(routes[1]), 1, 1, 1)
    for i = 2, #routes do GameTooltip:AddLine(ns.L(routes[i]), 1, 1, 1) end
    GameTooltip:AddLine(Status(pin.key), T.accent.r, T.accent.g, T.accent.b)
    GameTooltip:AddLine(TEXT_LEFT, HINT.r, HINT.g, HINT.b)
    GameTooltip:AddLine(TEXT_RIGHT, HINT.r, HINT.g, HINT.b)
    GameTooltip:Show()
end

local function Timer(key, now)
    if not On() or not Data[key] then return nil end
    local seconds, kind = Times.Next(key, now)
    if not seconds then return false, nil, kind end
    return seconds, Color(kind, seconds), kind
end

local function TimeText(key, now)
    local seconds, color, kind = Timer(key, now)
    if seconds == nil then return nil end
    local named = Times.RouteAt(key) ~= nil
    if seconds then return Countdown(seconds, kind, named), color end
    return kind == "stale" and TEXT_STALE or kind == "expired" and TEXT_EXPIRED or TEXT_UNTIMED, HINT,
        named and TEXT_RIDE or TEXT_AT_DOCK
end

local function TimerTip(tooltip, now, ...)
    local hint
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        local text, color, untimed = TimeText(key, now)
        if text then
            tooltip:AddDoubleLine(ns.L(Data[key].routes[1]), text,
                LABEL_RGB.r, LABEL_RGB.g, LABEL_RGB.b, color.r, color.g, color.b)
            hint = hint or untimed
        end
    end
    if hint then tooltip:AddLine(hint, HINT.r, HINT.g, HINT.b) end
end

local function Tinted(text, color)
    return TIME_COLOR:format(math.floor(color.r * COLOR_STEPS + ROUND), math.floor(color.g * COLOR_STEPS + ROUND),
        math.floor(color.b * COLOR_STEPS + ROUND), text)
end

local function Label(key)
    local routes = Data[key].routes
    local label = ns.L(routes[1])
    for i = 2, #routes do label = label .. ROUTE_SEPARATOR .. ns.L(routes[i]) end
    return label
end

local function DrawTimes(fit)
    wipe(times)
    if zoneSpots[1] then
        local now = GetServerTime()
        for i, key in ipairs(zoneSpots) do
            local text, color = TimeText(key, now)
            times[i] = Tinted(text, color)
        end
    else
        times[1] = Tinted(Countdown(SAMPLE_WAIT, DEPARTURE, true), DOCKED_RGB)
    end
    hud.times:SetText(table.concat(times, LINE_BREAK))
    local width = hud.names:GetStringWidth() + COLUMN_GAP + hud.times:GetStringWidth() + 2 * St.CARD_PAD
    if fit or width > hud:GetWidth() then
        hud:SetSize(width, hud.names:GetStringHeight() + 2 * St.CARD_PAD)
    end
end

local function OnZoneTick(_, delta)
    hudElapsed = hudElapsed + delta
    if hudElapsed < UPDATE_EVERY then return end
    hudElapsed = 0
    if ZoneOn() then DrawTimes() end
end

local function ShowZone()
    if not hud then return end
    local shown = ZoneOn() and (zoneSpots[1] ~= nil or unlocked == true)
    hud.mover:SetShown(shown and unlocked == true)
    if not shown then
        hud:Hide()
        return
    end
    wipe(names)
    for i, key in ipairs(zoneSpots) do names[i] = Label(key) end
    names[1] = names[1] or ns.L(SAMPLE_ROUTE)
    hud.names:SetText(table.concat(names, LINE_BREAK))
    hudElapsed = 0
    DrawTimes(true)
    hud:Show()
end

local function SaveZone(pos)
    S.Set("transportZonePos", pos)
end

local function BuildZone()
    hud = CreateFrame("Frame", nil, UIParent)
    hud:SetMovable(true)
    hud:SetClampedToScreen(true)
    hud.backdrop = Parts.HudBackdrop(hud, { mode = "none" })
    hud.names = ns.Font(hud, St.TEXT_SIZE, "OUTLINE")
    hud.names:SetPoint("TOPLEFT", St.CARD_PAD, -St.CARD_PAD)
    hud.names:SetJustifyH("LEFT")
    hud.names:SetTextColor(LABEL_RGB.r, LABEL_RGB.g, LABEL_RGB.b)
    hud.times = ns.Font(hud, St.TEXT_SIZE, "OUTLINE")
    hud.times:SetPoint("TOPRIGHT", -St.CARD_PAD, -St.CARD_PAD)
    hud.times:SetJustifyH("RIGHT")
    hud.mover = UI.AttachMover(hud, MOVER_LABEL, SaveZone, PAGE, CARD)
    hud:SetScript("OnUpdate", OnZoneTick)
    hud:Hide()
end

local function RestyleZone()
    local font, size, outline = S.Get("transportZoneFont"), S.Get("transportZoneFontSize"), S.Get("transportZoneOutline")
    local mode = hud.backdrop:SetMode(S.Get("transportZoneBackground"))
    Parts.HudFont(hud.names, font, size, outline, mode)
    Parts.HudFont(hud.times, font, size, outline, mode)
    local pos = S.Get("transportZonePos")
    hud:ClearAllPoints()
    hud:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
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
    wipe(zoneSpots)
    local map = On() and C_Map.GetBestMapForUnit(PLAYER)
    if map then
        local side = UnitFactionGroup(PLAYER) == HORDE and "H" or "A"
        local same = SameMap(map)
        local zone = CITY_ZONES[same] or same
        for key, stop in pairs(Data) do
            if stop.map == same and stop.side:find(side, 1, true) then
                if not stop.mapX then
                    local _, pos = C_Map.GetMapPosFromWorldPos(stop.continent, CreateVector2D(stop.x, stop.y), map)
                    stop.mapX, stop.mapY = pos:GetXY()
                end
                spots[#spots + 1] = key
            end
            if stop.map == zone and stop.side:find(side, 1, true) then zoneSpots[#zoneSpots + 1] = key end
        end
        table.sort(zoneSpots)
    end
    Ride.Watch(map)
    ShowZone()
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
    if ZoneOn() and not hud then BuildZone() end
    if hud then RestyleZone() end
    Refresh()
end

local function OnSetting(key)
    if key == "enabled" or key == "transportTimers" or key == "transportZone" then
        Apply()
    elseif hud and key:find("^transportZone") and key ~= "transportZonePos" then
        RestyleZone()
        ShowZone()
    end
end

local function SetUnlocked(on)
    unlocked = on
    ShowZone()
end

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function() SetUnlocked(true) end)
hooksecurefunc(ns, "HideUnlockMode", function() SetUnlocked(false) end)
Apply()

ns.TransportTimer = Timer
ns.TransportTimerTip = TimerTip

ns.Shared.Settings.Page(PAGE, S):Card({
    id = "transportTimers", name = "Boat and Zeppelin Timers", order = 13, switch = "transportTimers",
    help = "Shows when boats and zeppelins come and go on the minimap and world map.",
    rows = {
        { key = "transportShare", label = "Share Timings", toggle = true,
          help = "Sends the ships you time to your group and guild." },
        { key = "transportZone", label = "Zone Timer", toggle = true,
          help = "Shows the times of the boats and zeppelins in the zone you are in." },
        ns.Shared.Settings.Look("transportZone", { text = true, size = St.HUD_TEXT_RANGE, background = "card",
            needs = "transportZone" }),
    },
})

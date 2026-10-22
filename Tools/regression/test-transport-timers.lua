-- Run with Lua 5.1: saved server-clock sightings, period refinement, expiry, the stop data, ride timings and the minimap pins.
local checks = 0
local function Check(ok, why) assert(ok, why); checks = checks + 1 end
local now = 100
local ns = { Shared = { Parts = {}, Settings = {}, Places = dofile("Tools/regression/shared_places.lua") }, THEME = { accent = { r = 0, g = 0.5, b = 1 } }, UI = {},
    QoLConstants = { PERCENT = 100, SECONDS_PER_MINUTE = 60, SECONDS_PER_DAY = 86400,
        HINT_RGB = { r = 0.3, g = 0.71, b = 0.96 }, WHITE_RGB = { r = 1, g = 1, b = 1 } } }
_G.NaowhForever = ns
ns.L = function(text) return text end
local account, realm, untilReset = {}, "Realm", 3 * 86400
ns.AccountSettings = function() return account end
_G.GetRealmName = function() return realm end
_G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return untilReset end }

ns.TransportData = { boat = { period = 120, dwell = 20 }, other = { period = 150, dwell = 30 } }
ns.TransportRoutes = {}
dofile("NaowhForever_QoL/Travel/TransportTimes.lua")
local Times = ns.TransportTimes
local function Next(key, time, seconds, kind)
    local actual, state = Times.Next(key, time)
    Check(actual == seconds and state == kind, key .. " at " .. time .. ": " .. tostring(actual) .. ", " .. state)
end
Next("boat", now, nil, "new")
Check(Times.Record("boat", "departure", now), "a single departure calibrates immediately")
Next("boat", now, 100, "arrival")
Next("boat", now + 100, 20, "departure")
Check(Times.Record("boat", "arrival", 220), "a single arrival replaces the previous phase")
Check(not Times.Record("boat", "arrival", 220), "double clicks do not replace a sighting")
Next("boat", 225, 15, "departure")
Next("boat", 240, 100, "arrival")
Next("boat", 340, 20, "departure")
Next("boat", 460, 20, "departure")
Next("boat", 220 + 6 * 120, 20, "departure")
Next("boat", 221 + 6 * 120, nil, "expired")
Next("boat", 360220, nil, "expired")
Next("boat", 219, nil, "stale")
Next("other", 225, nil, "new")
Check(Times.Record("other", "arrival", 225), "a second stop calibrates independently")
Next("other", 230, 25, "departure")
Next("boat", 225, 15, "departure")
Check(Times.Record("boat", "departure", 245), "a new departure resynchronizes immediately")
Next("boat", 250, 95, "arrival")
Check(Times.Record("boat", "arrival", 200), "fresh sighting recovers after clock rollback")
Next("boat", 205, 15, "departure")
Check(not Times.Record("boat", "flight", 300), "unknown observation type rejected")
Check(not Times.Record(nil, "arrival", 300), "no observations without a stop")
Check(not Times.Record("unknown", "arrival", 300) and account.transportSightings.Realm.unknown == nil,
    "only known stops are saved")

account.transportSightings.Realm.boat = nil
Check(Times.Record("boat", "arrival", 1000), "a first sighting")
Next("boat", 1010, 10, "departure")
Check(Times.Record("boat", "arrival", 1000 + 2 * 126), "a same-kind sighting two cycles later")
Check(account.transportSightings.Realm.boat.period == 126, "refines the period from whole cycles")
Next("boat", 1252 + 30, 96, "arrival")
Next("boat", 1252 + 130, 16, "departure")
Check(Times.Record("boat", "departure", 1500), "a different kind only re-anchors")
Check(account.transportSightings.Realm.boat.period == 126, "re-anchoring keeps the refined period")
Check(Times.Record("boat", "departure", 1500 + 7 * 126), "ambiguous cycle count")
Check(account.transportSightings.Realm.boat.period == 126, "ambiguous cycle counts do not refine")
Check(Times.Record("boat", "departure", 1500 + 7 * 126 + 50), "a partial cycle")
Check(account.transportSightings.Realm.boat.period == 126, "partial cycles do not refine")
account.transportSightings.Realm.boat = nil
Check(Times.Record("boat", "arrival", 2000) and Times.Record("boat", "arrival", 2000 + 2 * 150),
    "out-of-band sightings re-anchor")
Check(account.transportSightings.Realm.boat.period == nil, "periods beyond the band are not adopted")
Next("boat", 2310, 10, "departure")

realm = "Other"
Next("boat", 2310, nil, "new")
realm = "Realm"
dofile("NaowhForever_QoL/Travel/TransportTimes.lua")
Times = ns.TransportTimes
Next("boat", 2310, 10, "departure")
Check(Times.Record("other", "arrival", 2400), "a second saved stop")
account.transportSightings.Realm.removed = { arrival = 2400, last = 2400, kind = "arrival" }
untilReset = 7 * 86400 - 50
Times.Prune(2400)
Next("boat", 2400, nil, "new")
Next("other", 2410, 20, "departure")
Check(account.transportSightings.Realm.removed == nil, "pruning drops stops no longer in the data")
untilReset = 3 * 86400
account.transportSightings = nil

-- Every stop is one of Journeys' ship stops; the two published cycles replace the estimate.
dofile("NaowhForever_QoL/Travel/TransportData.lua")
ns.Journeys = {}
dofile("NaowhForever_Utilities/Journeys/Constants.lua")
dofile("NaowhForever_Utilities/Journeys/Data/Network.lua")
local PUBLISHED = { ["Orgrimmar/Undercity"] = 239, ["Grom'gol/Undercity"] = 315 }
local f = assert(io.open("Core/Locales/enUS.lua", "rb"))
local english = f:read("*a")
f:close()
local total, perMap, published = 0, {}, 0
for _, ship in ipairs(ns.JourneyNetwork.ships) do
    local period, places = 0, {}
    for i = 3, #ship do
        period = period + ship[i][6] + ship[i][7] / ns.Journeys.C.SHIP_SPEED[ship[1]]
        places[#places + 1] = ship[i][5]
    end
    table.sort(places)
    local route = table.concat(places, "/")
    for i = 3, #ship do
        local stop = ship[i]
        local nextStop = ship[3 + (i - 2) % (#ship - 2)]
        local key = stop[4] .. ":" .. ship[1] .. " to " .. nextStop[5]
        local data = ns.TransportData[key]
        Check(data and data.map == stop[4] and data.continent == stop[1] and data.x == stop[2] and data.y == stop[3]
            and data.side == ship[2] and data.dwell == stop[6], "stop matches Journeys: " .. key)
        Check(#data.routes == #ship - 3, "every other dock of the ship is named at " .. key)
        for _, label in ipairs(data.routes) do
            Check(english:find('L["' .. label .. '"]', 1, true), "route label is in enUS: " .. label)
        end
        if PUBLISHED[route] then
            Check(data.period == PUBLISHED[route], "published cycle for " .. key)
            published = published + 1
        else
            Check(math.abs(data.period - period) < .000001, "estimated cycle for " .. key)
        end
        perMap[stop[4]] = (perMap[stop[4]] or 0) + 1
        total = total + 1
    end
end
for _ in pairs(ns.TransportData) do total = total - 1 end
Check(total == 0, "no stop outside Journeys' ships")
Check(published == 4, "both ends of the two published zeppelins")
for map, count in pairs(perMap) do Check(count <= 3, "at most MAX_PINS stops on map " .. map) end
Check(ns.TransportData["1437:Boat to Southshore"].routes[2] == "Boat to Auberdine",
    "the three-stop boat names both places it sails on to")
ns.Journeys, ns.JourneyNetwork = nil, nil

-- The ships NauticusClassic timed: both docks are stops above, and one ride or click times the whole ship.
dofile("NaowhForever_QoL/Travel/TransportRoutes.lua")
local ships = 0
for name, route in pairs(ns.TransportRoutes) do
    ships = ships + 1
    Check(english:find('L["' .. name .. '"]', 1, true), "ship name is in enUS: " .. name)
    Check(#route.docks == 2 and #route.triggers == 2, name .. " has two docks and two trigger points")
    local one, two = route.docks[1], route.docks[2]
    Check(one.arrive == 0 and one.leave < two.arrive and two.arrive < two.leave and two.leave < route.period,
        name .. "'s docks follow its cycle")
    for _, dock in ipairs(route.docks) do
        Check(ns.TransportData[dock.stop], name .. " docks at a known stop: " .. dock.stop)
        Check(english:find('L["' .. dock.place .. '"]', 1, true), "dock place is in enUS: " .. dock.place)
    end
    Check(ns.TransportData[one.stop].side == ns.TransportData[two.stop].side, name .. "'s docks serve the same side")
    for _, trigger in ipairs(route.triggers) do
        Check(trigger.span > 0 and trigger.at > one.leave and trigger.at < route.period,
            name .. "'s trigger point is on the way, inside its cycle")
    end
end
Check(ships == 7, "seven ships are timed from rides")

dofile("NaowhForever_QoL/Travel/TransportTimes.lua")
Times = ns.TransportTimes
local SHIP = "The Thundercaller"
local ship = ns.TransportRoutes[SHIP]
local ORG_DOCK, UC_DOCK = ship.docks[1].stop, ship.docks[2].stop
Check(Times.RouteAt(ORG_DOCK) == SHIP and select(2, Times.RouteAt(UC_DOCK)) == 2, "both docks belong to the ship")
Check(Times.RouteAt("1453:Boat to Auberdine") == nil, "a ship NauticusClassic never timed keeps its sightings")
local function Dock(index, time, seconds, kind)
    local actual, state = Times.Dock(SHIP, index, time)
    Check(state == kind and (seconds == nil and actual == nil or actual and math.abs(actual - seconds) < 1e-6),
        SHIP .. " dock " .. index .. " at " .. time .. ": " .. tostring(actual) .. ", " .. tostring(state))
end
Dock(1, 5000, nil, "new")
Check(Times.Ride(SHIP, 5000), "a ride times the ship")
Dock(1, 5000, 60, "departure")
Dock(2, 5000, ship.docks[2].arrive, "arrival")
Dock(1, 5070, ship.period - 70, "arrival")
Dock(2, 5200, ship.docks[2].leave - 200, "departure")
Dock(1, 4999, nil, "stale")
Check(not Times.Ride(SHIP, 5000), "the same timing twice is not a new ride")
Next(UC_DOCK, 5200, ship.docks[2].leave - 200, "departure")
Check(Times.Record(UC_DOCK, "departure", 6000)
    and account.transportRides.Realm[SHIP].at == 6000 - ship.docks[2].leave, "a click at a dock times the whole ship")
account.transportRides = nil
local measured = ship.period + 0.5
Check(Times.Ride(SHIP, 10000) and Times.Ride(SHIP, 10000 + 4 * measured), "a ride four cycles later")
Check(math.abs(account.transportRides.Realm[SHIP].period - measured) < 1e-6, "measures the cycle over whole cycles")
Check(account.transportRides.Realm[SHIP].base == 10000, "and keeps the first ride to measure from")
local off = 10000 + 4 * measured + ship.period / 2
Check(Times.Ride(SHIP, off) and account.transportRides.Realm[SHIP].base == off
    and account.transportRides.Realm[SHIP].period == nil, "a timing that does not fit the cycle starts over")
account.transportRides.Realm.Gone = { base = 1, at = 1 }
untilReset = 7 * 86400 - 50
Times.Prune(off + 10)
Check(account.transportRides.Realm[SHIP] and account.transportRides.Realm.Gone == nil,
    "the weekly reset keeps ride timings; a ship no longer in the data is dropped")
untilReset = 3 * 86400
account.transportRides, account.transportSightings = nil, nil

local made, mapReads, conversions, widgets, listeners = 0, 0, 0, {}, {}
local function Widget(kind)
    local w = { kind = kind, scripts = {}, events = {}, shown = true }
    function w:SetScript(key, fn) self.scripts[key] = fn end
    function w:RegisterEvent(key) self.events[key] = true end
    function w:UnregisterEvent(key) self.events[key] = nil end
    function w:UnregisterAllEvents() self.events = {} end
    function w:RegisterForClicks(...) self.clicks = { ... } end
    function w:Show() self.shown = true end
    function w:Hide() self.shown = false end
    function w:SetSize(width) self.size = width end
    function w:SetAllPoints() end
    function w:ClearAllPoints() self.point = nil end
    function w:SetPoint(_, relative, _, x, y) self.point = { relative = relative, x = x, y = y } end
    function w:GetWidth() return 140 end
    function w:GetHeight() return 140 end
    function w:CreateTexture() return Widget("Texture") end
    widgets[#widgets + 1] = w
    return w
end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.CreateFrame = function(kind) made = made + 1; return Widget(kind) end
_G.Minimap = Widget("Minimap")
widgets = {}
local tip = { lines = {} }
_G.GameTooltip = {
    SetOwner = function(_, owner) tip.owner, tip.lines, tip.shown = owner, {}, false end,
    SetText = function(_, text) tip.lines[1] = text end,
    AddLine = function(_, text) tip.lines[#tip.lines + 1] = text end,
    AddDoubleLine = function(_, left, right) tip.lines[#tip.lines + 1] = left .. " " .. right end,
    Show = function() tip.shown = true end,
    Hide = function() tip.shown = false end,
}
_G.GetServerTime = function() return now end
_G.IsPlayerMoving = function() return false end
_G.IsLoggedIn = function() return true end
_G.GetPlayerFacing = function() return 0 end
_G.C_Minimap = { GetViewRadius = function() return 100 end }
_G.C_CVar = { GetCVarBool = function() return false end }
_G.CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(v) return v.x, v.y end } end
local faction, playerMap, playerWorld = "Alliance", 1413, nil
local CONTINENT = { [1411] = 1, [1413] = 1, [1420] = 0, [1429] = 0, [1453] = 0, [2521] = 2991, [2665] = 2991 }
local ZONES = { [1411] = "Durotar", [1420] = "Tirisfal Glades" }
local KALIMDOR = 1414
_G.UnitFactionGroup = function() return faction end
_G.C_Map = {
    GetBestMapForUnit = function() mapReads = mapReads + 1; return playerMap end,
    GetWorldPosFromMapPos = function(map, v)
        return CONTINENT[map], { GetXY = function() return v.x * 1000, v.y * 1000 end }
    end,
    GetMapPosFromWorldPos = function(_, world, map)
        conversions = conversions + 1
        return map, { GetXY = function() return world.x / 1000, world.y / 1000 end }
    end,
    GetMapWorldSize = function() return 1000, 1000 end,
    GetMapInfo = function(map)
        return { name = ZONES[map] or ("Map " .. map), mapType = map == KALIMDOR and 2 or 3 }
    end,
}
_G.Enum = { UIMapType = { Continent = 2 } }
local tickers, taxi, swimming, clock = {}, false, false, 0
_G.C_Timer = { NewTicker = function(_, fn)
    local ticker = { fn = fn }
    function ticker:Cancel() self.cancelled = true end
    tickers[#tickers + 1] = ticker
    return ticker
end }
_G.UnitOnTaxi = function() return taxi end
_G.IsSwimming = function() return swimming end
_G.GetTime = function() return clock end
_G.UnitPosition = function() return playerWorld[1], playerWorld[2], 0, CONTINENT[playerMap] end
_G.hooksecurefunc = function(target, key, fn)
    local original = target[key]
    target[key] = function(...) original(...); fn(...) end
end
ns.Apply = function() end
dofile("Shared/UI/MinimapPins.lua")
local layers = 0
local MinimapLayer = ns.Shared.Parts.MinimapLayer
ns.Shared.Parts.MinimapLayer = function(opts) layers = layers + 1; return MinimapLayer(opts) end
local icons = {}
ns.TownTravelIcon = function(icon, label) icons[icon] = label end
local card
ns.Shared.Settings.Page = function()
    return { Card = function(_, spec) card = spec end }
end
local settings = { enabled = true, transportTimers = false }
ns.QoLSettings = {
    Get = function(key) return settings[key] end,
    OnChange = function(fn) listeners[#listeners + 1] = fn end,
    Set = function(key, value)
        settings[key] = value
        for _, fn in ipairs(listeners) do fn(key) end
    end,
}
dofile("NaowhForever_QoL/Travel/TransportRide.lua")
dofile("NaowhForever_QoL/Travel/Transport.lua")
Check(made == 0 and mapReads == 0 and layers == 0 and #tickers == 0,
    "default off builds no frames, reads no maps and watches no rides")
Check(card.switch == "transportTimers" and #card.rows == 1 and card.rows[1].key == "transportShare",
    "the settings card is the switch and its sharing toggle")
ns.QoLSettings.Set("unrelated", true)
Check(made == 0, "an unrelated setting builds nothing")

local function Pins()
    local shown = {}
    for _, w in ipairs(widgets) do
        if w.kind == "Button" and w.shown then shown[#shown + 1] = w end
    end
    return shown
end
local function PinFor(key)
    for _, pin in ipairs(Pins()) do if pin.key == key then return pin end end
end
local function TipStatus() return tip.lines[#tip.lines - 2] end

playerMap, playerWorld = 1429, { 0, 0 }
ns.QoLSettings.Set("transportTimers", true)
Check(made == 1 and layers == 0, "a map without stops builds only the event frame")
local events = widgets[1]
Check(events.events.PLAYER_ENTERING_WORLD and events.events.ZONE_CHANGED_NEW_AREA, "zone events while on")
local function Event(name) events.scripts.OnEvent(events, name) end

local HARBOR = "1453:Boat to Auberdine"
local harbor = ns.TransportData[HARBOR]
playerMap, playerWorld = 1453, { harbor.x, harbor.y }
Event("ZONE_CHANGED_NEW_AREA")
Check(layers == 1 and #Pins() == 1, "one minimap pin at the Stormwind Harbor dock, through the shared minimap layer")
Check(#tickers == 0, "no ride watch where no timed ship docks")
local pin = Pins()[1]
Check(pin.key == HARBOR and icons[pin.icon] == "Boat to Auberdine", "the pin shows the boat art for its route")
Check(pin.point.relative == Minimap and pin.point.x == 0 and pin.point.y == 0,
    "the layer places the pin on the minimap where the ship waits")
Check(pin.clicks[1] == "LeftButtonUp" and pin.clicks[2] == "RightButtonUp", "both buttons click")
Check(conversions == 1, "the stop's map position is worked out once")

now = 1700000000
pin.scripts.OnEnter(pin)
Check(tip.owner == pin and tip.shown and tip.lines[1] == "Boat to Auberdine", "hover names the destination")
Check(TipStatus() == "Record a sighting", "no sighting yet asks for one")
Check(tip.lines[#tip.lines - 1] == "Left-click when it arrives" and tip.lines[#tip.lines] == "Right-click when it leaves",
    "the tooltip says how to record a sighting")
Check(pin.scripts.OnUpdate, "the tooltip counts down only while hovered")
pin.scripts.OnClick(pin, "LeftButton")
Check(TipStatus() == "Departs in ~1:00", "left click records an arrival: " .. TipStatus())
Check(account.transportSightings.Realm[HARBOR].kind == "arrival", "the sighting is saved per realm under its stop")
now = now + 65
pin.scripts.OnUpdate(pin, 0.5)
Check(TipStatus() == "Departs in ~1:00", "the tooltip redraws once a second, not every frame")
pin.scripts.OnUpdate(pin, 0.5)
local wait = math.ceil(harbor.period - 65)
Check(TipStatus() == ("Arrives in ~%d:%02d"):format(math.floor(wait / 60), wait % 60), "counts to the next arrival")
pin.scripts.OnClick(pin, "RightButton")
wait = math.ceil(harbor.period - 60)
Check(TipStatus() == ("Arrives in ~%d:%02d"):format(math.floor(wait / 60), wait % 60),
    "right click records a departure")
pin.scripts.OnLeave(pin)
Check(pin.scripts.OnUpdate == nil and not tip.shown, "leaving the pin stops the countdown")
now = now + 7 * harbor.period
pin.scripts.OnEnter(pin)
Check(TipStatus() == "Estimate out of date", "six cycles on, the estimate is out of date")
now = 1600000000
pin.scripts.OnUpdate(pin, 1)
Check(TipStatus() == "Server clock changed; record a new sighting.", "a backwards clock suspends the estimate")
pin.scripts.OnLeave(pin)
now = 1700010000

local UC, GROMGOL = "1411:Zeppelin to Undercity", "1411:Zeppelin to Grom'gol"
playerMap = 1411
playerWorld = { ns.TransportData[UC].x, ns.TransportData[UC].y }
Event("ZONE_CHANGED_NEW_AREA")
Check(#Pins() == 0, "Horde zeppelins do not show for the Alliance")
faction = "Horde"
Event("ZONE_CHANGED_NEW_AREA")
Check(#Pins() == 2 and PinFor(UC) and PinFor(GROMGOL), "each zeppelin at the Orgrimmar tower has its own pin")
Check(math.abs(PinFor(UC).point.x) < 1e-6 and math.abs(PinFor(GROMGOL).point.x) > 1, "each pin sits at its own ship's stop")
Check(#tickers == 1 and not tickers[1].cancelled, "a zone where a timed ship docks watches for rides")
local org = PinFor(UC)
org.scripts.OnEnter(org)
Check(tip.lines[1] == "The Thundercaller" and tip.lines[2] == "Orgrimmar, Durotar" and tip.lines[3] == "Not timed yet"
    and tip.lines[4] == "Undercity, Tirisfal Glades" and tip.lines[6] == "Ride it once to time it.",
    "an untimed ship names both docks and asks for a ride")
org.scripts.OnClick(org, "LeftButton")
Check(#tip.lines == 5 and tip.lines[3] == "Departure: 1m 00s" and tip.lines[5] == "Arrival: 3m 12s",
    "an arrival click at Orgrimmar times both docks: " .. table.concat(tip.lines, " | "))
org.scripts.OnLeave(org)
local gg = PinFor(GROMGOL)
gg.scripts.OnEnter(gg)
Check(tip.lines[1] == "The Iron Eagle" and tip.lines[3] == "Not timed yet",
    "the other zeppelin at the tower keeps its own timing")
gg.scripts.OnLeave(gg)
now = now + 60 + 30
org.scripts.OnEnter(org)
Check(tip.lines[3] == "Arrival: 4m 27s" and tip.lines[5] == "Arrival: 1m 42s",
    "both docks count down to their next arrival: " .. table.concat(tip.lines, " | "))
now = now + 110
org.scripts.OnUpdate(org, 1)
Check(tip.lines[5] == "Departure: 52s", "a docked ship counts down to leaving: " .. tostring(tip.lines[5]))
org.scripts.OnLeave(org)

local MULGORE = "2521:Zeppelin to Mulgore"
playerMap = 2665
playerWorld = { ns.TransportData[MULGORE].x, ns.TransportData[MULGORE].y }
Event("ZONE_CHANGED_NEW_AREA")
Check(#Pins() == 1 and PinFor(MULGORE), "on Zephras Isle's second map, 2665, the island's zeppelin shows")
playerMap = 1411
playerWorld = { ns.TransportData[UC].x, ns.TransportData[UC].y }
Event("ZONE_CHANGED_NEW_AREA")

local layerFrame
for _, w in ipairs(widgets) do if w.kind == "Frame" and w ~= events then layerFrame = w end end
local watching = tickers[#tickers]
ns.QoLSettings.Set("transportTimers", false)
Check(#Pins() == 0 and next(events.events) == nil, "off hides the pins and unregisters the events")
Check(next(layerFrame.events) == nil and layerFrame.scripts.OnUpdate == nil, "off stops the layer's movement work")
local before = mapReads
Event("ZONE_CHANGED_NEW_AREA")
Check(#Pins() == 0, "a late event while off shows nothing")
ns.QoLSettings.Set("transportTimers", true)
Check(#Pins() == 2 and layers == 1 and mapReads > before, "on again reuses the layer and its pins")
Check(watching.cancelled and tickers[#tickers] ~= watching and not tickers[#tickers].cancelled,
    "off stops the ride watch, on starts it again")
Check(account.transportRides.Realm[SHIP], "turning off keeps the ride timings")
ns.QoLSettings.Set("enabled", false)
Check(#Pins() == 0 and next(events.events) == nil, "QoL off hides the pins too")
ns.QoLSettings.Set("enabled", true)
now, untilReset = now + 10, 7 * 86400 - 5
Event("PLAYER_ENTERING_WORLD")
Check(account.transportRides.Realm[SHIP], "a login after the weekly reset keeps ride timings")

-- Riding past a trigger point times the ship: at the ship's speed, heading its way, off a flight path.
account.transportRides = nil
local trigger = ship.triggers[1]
local ax, ay, bx, by = trigger.ax, trigger.ay, trigger.bx, trigger.by
local function Pass(x1, y1, x2, y2)
    clock = clock + 100
    playerWorld = { x1, y1 }
    tickers[#tickers].fn()
    clock = clock + 1
    playerWorld = { x2, y2 }
    tickers[#tickers].fn()
end
local function Untimed() return Times.Dock(SHIP, 1, now) == nil end
Pass(bx - (bx - ax) * 0.1, by - (by - ay) * 0.1, bx, by)
Check(Untimed(), "walking past the trigger point times nothing")
Pass(bx + (bx - ax), by + (by - ay), bx, by)
Check(Untimed(), "passing it the other way times nothing")
Pass(ax + 30, ay, bx + 30, by)
Check(Untimed(), "riding beside the route, out of reach of the point, times nothing")
taxi = true
Pass(ax, ay, bx, by)
taxi = false
Check(Untimed(), "a flight path past it times nothing")
Pass(ax, ay, bx, by)
Dock(1, now, ship.period - (trigger.at + trigger.span), "arrival")
local timedAt = account.transportRides.Realm[SHIP].at
Check(math.abs(timedAt - (now - trigger.at - trigger.span)) < 1e-6,
    "riding through the point times the ship from where that point is in its cycle")
now = now + 5
clock = clock + 9
playerWorld = { ax, ay }
tickers[#tickers].fn()
clock = clock + 1
playerWorld = { bx, by }
tickers[#tickers].fn()
Check(account.transportRides.Realm[SHIP].at == timedAt, "the same ride is not timed twice within the lockout")
playerMap = 1429
Event("ZONE_CHANGED_NEW_AREA")
Check(tickers[#tickers].cancelled, "leaving the docks' zones stops the ride watch")
print("transport timers: " .. checks .. " checks passed")

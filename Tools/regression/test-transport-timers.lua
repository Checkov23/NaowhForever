-- Run with Lua 5.1: saved server-clock sightings, period refinement, expiry, the stop data and the minimap pins.
local checks = 0
local function Check(ok, why) assert(ok, why); checks = checks + 1 end
local now = 100
local ns = { Shared = { Parts = {}, Settings = {} }, THEME = { accent = { r = 0, g = 0.5, b = 1 } }, UI = {},
    QoLConstants = { PERCENT = 100, SECONDS_PER_MINUTE = 60, SECONDS_PER_DAY = 86400,
        HINT_RGB = { r = 0.3, g = 0.71, b = 0.96 } } }
_G.NaowhForever = ns
ns.L = function(text) return text end
local account, realm, untilReset = {}, "Realm", 3 * 86400
ns.AccountSettings = function() return account end
_G.GetRealmName = function() return realm end
_G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return untilReset end }

ns.TransportData = { boat = { period = 120, dwell = 20 }, other = { period = 150, dwell = 30 } }
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
local CONTINENT = { [1411] = 1, [1413] = 1, [1429] = 0 }
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
}
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
dofile("NaowhForever_QoL/Travel/Transport.lua")
Check(made == 0 and mapReads == 0 and layers == 0, "default off builds no frames and reads no maps")
Check(card.switch == "transportTimers" and card.rows == nil, "the settings card is the switch alone")
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

local RATCHET = "1413:Boat to Booty Bay"
local ratchet = ns.TransportData[RATCHET]
playerMap, playerWorld = 1413, { ratchet.x, ratchet.y }
Event("ZONE_CHANGED_NEW_AREA")
Check(layers == 1 and #Pins() == 1, "one minimap pin at the Ratchet dock, through the shared minimap layer")
local pin = Pins()[1]
Check(pin.key == RATCHET and icons[pin.icon] == "Boat to Booty Bay", "the pin shows the boat art for its route")
Check(pin.point.relative == Minimap and pin.point.x == 0 and pin.point.y == 0,
    "the layer places the pin on the minimap where the ship waits")
Check(pin.clicks[1] == "LeftButtonUp" and pin.clicks[2] == "RightButtonUp", "both buttons click")
Check(conversions == 1, "the stop's map position is worked out once")

now = 1700000000
pin.scripts.OnEnter(pin)
Check(tip.owner == pin and tip.shown and tip.lines[1] == "Boat to Booty Bay", "hover names the destination")
Check(TipStatus() == "Record a sighting", "no sighting yet asks for one")
Check(tip.lines[#tip.lines - 1] == "Left-click when it arrives" and tip.lines[#tip.lines] == "Right-click when it leaves",
    "the tooltip says how to record a sighting")
Check(pin.scripts.OnUpdate, "the tooltip counts down only while hovered")
pin.scripts.OnClick(pin, "LeftButton")
Check(TipStatus() == "Departs in ~1:00", "left click records an arrival: " .. TipStatus())
Check(account.transportSightings.Realm[RATCHET].kind == "arrival", "the sighting is saved per realm under its stop")
now = now + 65
pin.scripts.OnUpdate(pin, 0.5)
Check(TipStatus() == "Departs in ~1:00", "the tooltip redraws once a second, not every frame")
pin.scripts.OnUpdate(pin, 0.5)
local wait = math.ceil(ratchet.period - 65)
Check(TipStatus() == ("Arrives in ~%d:%02d"):format(math.floor(wait / 60), wait % 60), "counts to the next arrival")
pin.scripts.OnClick(pin, "RightButton")
wait = math.ceil(ratchet.period - 60)
Check(TipStatus() == ("Arrives in ~%d:%02d"):format(math.floor(wait / 60), wait % 60),
    "right click records a departure")
pin.scripts.OnLeave(pin)
Check(pin.scripts.OnUpdate == nil and not tip.shown, "leaving the pin stops the countdown")
now = now + 7 * ratchet.period
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
PinFor(UC).scripts.OnClick(PinFor(UC), "LeftButton")
Check(tip.lines[1] == "Zeppelin to Undercity" and TipStatus() == "Departs in ~1:00", "a click records that zeppelin")
local gg = PinFor(GROMGOL)
gg.scripts.OnEnter(gg)
Check(TipStatus() == "Record a sighting", "the other zeppelin at the tower keeps its own phase")
gg.scripts.OnLeave(gg)
now = now + 60 + 30
PinFor(UC).scripts.OnEnter(PinFor(UC))
Check(TipStatus() == "Arrives in ~2:29", "Orgrimmar-Undercity counts down its published 3:59 cycle: " .. TipStatus())
PinFor(UC).scripts.OnLeave(PinFor(UC))

local layerFrame
for _, w in ipairs(widgets) do if w.kind == "Frame" and w ~= events then layerFrame = w end end
ns.QoLSettings.Set("transportTimers", false)
Check(#Pins() == 0 and next(events.events) == nil, "off hides the pins and unregisters the events")
Check(next(layerFrame.events) == nil and layerFrame.scripts.OnUpdate == nil, "off stops the layer's movement work")
local before = mapReads
Event("ZONE_CHANGED_NEW_AREA")
Check(#Pins() == 0, "a late event while off shows nothing")
ns.QoLSettings.Set("transportTimers", true)
Check(#Pins() == 2 and layers == 1 and mapReads > before, "on again reuses the layer and its pins")
Check(account.transportSightings.Realm[UC], "turning off keeps the sightings")
ns.QoLSettings.Set("enabled", false)
Check(#Pins() == 0 and next(events.events) == nil, "QoL off hides the pins too")
ns.QoLSettings.Set("enabled", true)
now, untilReset = now + 10, 7 * 86400 - 5
Event("PLAYER_ENTERING_WORLD")
Check(account.transportSightings.Realm[UC] == nil, "a login after the weekly reset drops older sightings")
print("transport timers: " .. checks .. " checks passed")

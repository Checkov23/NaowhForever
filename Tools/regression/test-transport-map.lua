-- Run with Lua 5.1 from the repository root: boat and zeppelin times on the world map's dock pins, and ride timings
-- shared with the group and guild.
local checks = 0
local function Check(ok, why) assert(ok, why); checks = checks + 1 end
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local now, clock = 1700000000, 0
local ns = { Shared = { Parts = {}, Settings = {}, Places = dofile("Tools/regression/shared_places.lua"),
    Style = dofile("Tools/regression/shared_style.lua") },
    THEME = { accent = { r = 0, g = 0.5, b = 1 }, fg = { r = 1, g = 1, b = 1 } }, UI = {},
    QoLConstants = dofile("Tools/regression/qol_constants.lua"),
    L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower }
_G.NaowhForever = ns
local account = {}
ns.AccountSettings = function() return account end
_G.GetRealmName = function() return "Realm" end
_G.C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return 3 * 86400 end }
_G.GetServerTime = function() return now end
_G.GetTime = function() return clock end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

dofile("NaowhForever_QoL/Travel/TransportData.lua")
dofile("NaowhForever_QoL/Travel/TransportRoutes.lua")
dofile("NaowhForever_QoL/Travel/TransportTimes.lua")
local Times = ns.TransportTimes
local SHIP, OTHER = "The Iron Eagle", "The Thundercaller"
local ship = ns.TransportRoutes[SHIP]
local function Row(name) return account.transportRides.Realm[name] end

-- A shared timing fills a ship you never timed and a fresher one replaces yours; older, impossible ones do not.
local timedNames = {}
Times.OnTimed = function(name) timedNames[#timedNames + 1] = name end
Check(not Times.Shared("Nobody's Boat", now - 100, nil, now), "a ship not in the data is not kept")
Check(not Times.Shared(SHIP, now + 60, nil, now), "a timing from the future is not kept")
Check(not Times.Shared(SHIP, now - 100, ship.period * 1.5, now), "a cycle far from the ship's is not kept")
Check(Times.Shared(SHIP, now - 100, ship.period + 0.4, now) and Row(SHIP).at == now - 100
    and math.abs(Row(SHIP).period - ship.period - 0.4) < 1e-6, "a ship you never timed takes the shared timing and cycle")
Check(#timedNames == 0, "a shared timing is never sent on")
Check(not Times.Shared(SHIP, now - 200, nil, now), "an older timing than yours is not kept")
Check(not Times.Shared(SHIP, now - 100, nil, now), "the same timing twice is not kept")
local later = now - 100 + 3 * (ship.period + 0.4)
Check(Times.Shared(SHIP, later, nil, now + 3 * ship.period) and Row(SHIP).base == now - 100 and Row(SHIP).at == later,
    "a fresher timing that fits the cycle keeps the first one to measure from")
Check(Times.Latest(SHIP) == nil and Row(SHIP).shared, "a shared timing is not yours to send")
Check(Times.Dock(SHIP, 1, now + 3 * ship.period), "a shared timing still counts down")
Check(Times.Ride(OTHER, now - 30) and timedNames[1] == OTHER, "your own ride is announced")
Check(Times.Latest(OTHER) == now - 30 and not Row(OTHER).shared, "your own ride is yours to send")
Check(Times.Ride(SHIP, later + ship.period + 1) and not Row(SHIP).shared and Times.Latest(SHIP) == later + ship.period + 1,
    "your own ride over a shared timing makes it yours to send")
account.transportRides = nil
Times.OnTimed = nil

-- The sharing: nothing until the timers are on, then each ride goes to the group and guild, asks are answered once.
local frames, sent, timers, prefixes = {}, {}, {}, {}
local function Frame(kind, parent)
    local f = { kind = kind, parent = parent, events = {}, scripts = {}, shown = true }
    function f:SetScript(key, fn) self.scripts[key] = fn end
    function f:RegisterEvent(key) self.events[key] = true end
    function f:UnregisterEvent(key) self.events[key] = nil end
    function f:UnregisterAllEvents() self.events = {} end
    function f:RegisterForClicks() end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(shown) self.shown = shown end
    function f:IsShown() return self.shown end
    function f:SetSize(w) self.size = w end
    function f:SetAllPoints() end
    function f:SetPoint(...) self.point = { ... } end
    function f:CreateTexture() return Frame("Texture") end
    function f:CreateFontString()
        local fs = Frame("FontString", self)
        fs.SetText = function(label, text) label.text = text end
        return fs
    end
    frames[#frames + 1] = f
    return f
end
_G.CreateFrame = function(kind, _, parent) return Frame(kind, parent) end
_G.Minimap = Frame("Minimap")
_G.C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix) prefixes[#prefixes + 1] = prefix end,
    SendAddonMessage = function(prefix, message, channel) sent[#sent + 1] = { prefix, message, channel } end,
}
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function()
    return { Cancel = function() end }
end }
_G.math.random = function(low) return low end
local OWN, MATE, OTHER_SHARD = "Player-1234-0000AAAA", "Player-1234-0000BBBB", "Player-9999-0000CCCC"
local loggedIn, guild, group = true, true, false
_G.UnitGUID = function() return OWN end
_G.IsLoggedIn = function() return loggedIn end
_G.IsInGuild = function() return guild end
_G.IsInGroup = function(category) return group and category == nil end
_G.IsInRaid = function() return false end
_G.LE_PARTY_CATEGORY_INSTANCE = 2
_G.issecretvalue = function() return false end
local trusted = { [MATE] = true, [OTHER_SHARD] = true }
ns.SenderIs = function(_, _, guid) return trusted[guid] == true end
_G.hooksecurefunc = function(target, key, fn)
    local original = target[key]
    target[key] = function(...) original(...); fn(...) end
end
ns.Apply = function() end
local listeners = {}
local settings = { enabled = true, transportTimers = false, transportShare = false, townMap = true, townTravel = true, townPinSize = 20 }
ns.QoLSettings = {
    Get = function(key) return settings[key] end,
    OnChange = function(fn) listeners[#listeners + 1] = fn end,
    Set = function(key, value)
        settings[key] = value
        for _, fn in ipairs(listeners) do fn(key) end
    end,
}
local S = ns.QoLSettings
_G.UnitFactionGroup = function() return "Horde" end
_G.C_Map = { GetBestMapForUnit = function() return 1429 end, GetMapInfo = function(map)
    return { name = "Map " .. map, mapType = 3 }
end }
_G.Enum = { UIMapType = { Continent = 2 } }
_G.CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(v) return v.x, v.y end } end
local card
ns.Shared.Settings.Page = function() return { Card = function(_, spec) card = spec end } end
ns.Shared.Parts.MinimapLayer = function() return { Set = function() end } end
ns.TownTravelIcon = function() end
dofile("NaowhForever_QoL/Travel/TransportRide.lua")
dofile("NaowhForever_QoL/Travel/TransportShare.lua")
dofile("NaowhForever_QoL/Travel/Transport.lua")
Check(#frames == 1 and #prefixes == 0 and #sent == 0, "default off: no event frame, no prefix, nothing sent")
Check(Times.OnTimed == nil, "default off: rides are not announced")
Check(ns.TransportTimer("1411:Zeppelin to Grom'gol", now) == nil, "default off: the map gets no times")
Check(card.help:find("world map", 1, true), "the settings card says the times show on the world map too")
Check(#card.help < 100, "the settings card's help is one short sentence")
Check(card.rows and card.rows[1].key == "transportShare" and card.rows[1].toggle, "the card has a Share Timings toggle")
Check(Read("Core/Settings.lua"):find("transportShare = true", 1, true), "sharing is on once the timers are")

S.Set("transportTimers", true)
Check(#prefixes == 0 and #sent == 0 and Times.OnTimed == nil, "sharing off: no prefix, no asks, rides are not announced")
Times.Ride(SHIP, now - 60)
Check(#sent == 0, "sharing off: a ride is not sent")
account.transportRides = nil
S.Set("transportShare", true)
local share
for _, f in ipairs(frames) do if f.events.CHAT_MSG_ADDON then share = f end end
Check(share and prefixes[1] == "NaowhShips", "on: the sharing frame listens on its own prefix")
Check(#sent == 1 and sent[1][2] == "Q" and sent[1][3] == "GUILD", "on: asks the guild once for its timings")
Check(Times.OnTimed ~= nil, "on: rides are announced")
local function Event(name, ...) share.scripts.OnEvent(share, name, ...) end
Event("PLAYER_ENTERING_WORLD")
Check(#sent == 1, "the guild is asked only once a session")

sent = {}
Times.Ride(SHIP, now - 50)
Check(#sent == 1 and sent[1][3] == "GUILD"
    and sent[1][2] == ("T %s %.3f %.3f %s"):format(OWN, now - 50, 0, SHIP), "your ride goes to the guild")
sent = {}
group = true
Event("GROUP_ROSTER_UPDATE")
Check(#sent == 2 and sent[1][2] == "Q" and sent[1][3] == "PARTY" and sent[2][2]:find(SHIP, 1, true)
    and sent[2][3] == "PARTY", "joining a group asks it and sends it what you have timed")
sent = {}
Event("GROUP_ROSTER_UPDATE")
Check(#sent == 0, "a roster change within the group sends nothing")
Times.Ride(SHIP, now - 40)
Check(#sent == 2 and sent[1][3] == "PARTY" and sent[2][3] == "GUILD", "in a group a ride goes to both")

local function Hear(message, channel, guid)
    Event("CHAT_MSG_ADDON", "NaowhShips", message, channel, "Someone-Realm", guid)
end
local function Timing(guid, at, period, name) return ("T %s %.3f %.3f %s"):format(guid, at, period, name) end
local Rides = account.transportRides.Realm
Hear(Timing(MATE, now - 20, ns.TransportRoutes[OTHER].period, OTHER), "GUILD")
Check(Rides[OTHER] and math.abs(Rides[OTHER].at - (now - 20)) < 1e-3,
    "a guild mate's timing of a ship you never timed is kept")
Hear(Timing(OTHER_SHARD, now - 10, ns.TransportRoutes["The Purple Princess"].period, "The Purple Princess"), "PARTY")
Check(Rides["The Purple Princess"], "a timing from a player on another shard is kept: the ships are the same")
trusted[MATE] = false
Hear(Timing(MATE, now - 10, 0, "The Moonspray"), "GUILD")
Check(Rides["The Moonspray"] == nil, "a sender who is not who the message says is not believed")
trusted[MATE] = true
Hear(Timing(OWN, now - 10, 0, "The Moonspray"), "GUILD")
Check(Rides["The Moonspray"] == nil, "your own message coming back is ignored")
Hear(Timing(MATE, now - 10, 0, "Nobody's Boat"), "GUILD")
Event("CHAT_MSG_ADDON", "OtherAddon", Timing(MATE, now - 10, 0, "The Moonspray"), "GUILD", "Someone-Realm")
Event("CHAT_MSG_ADDON", "NaowhShips", Timing(MATE, now - 10, 0, "The Moonspray"), "WHISPER", "Someone-Realm")
Check(Rides["The Moonspray"] == nil, "other prefixes and whispers are ignored")

sent = {}
Times.Ride(OTHER, now - 5)
sent, timers = {}, {}
group = false
Event("GROUP_ROSTER_UPDATE")
group = true
Event("GROUP_ROSTER_UPDATE")
local rejoined = {}
for _, message in ipairs(sent) do rejoined[#rejoined + 1] = message[2] end
local joined = table.concat(rejoined, " ")
Check(joined:find(SHIP, 1, true) and not joined:find("The Purple Princess", 1, true),
    "joining a group sends your timings, not one you received")
sent = {}
Hear("Q", "PARTY")
Hear("Q", "PARTY")
Check(#timers == 1 and #sent == 0, "an ask is answered once, after a short random wait")
Hear(Timing(MATE, now, ns.TransportRoutes[OTHER].period, OTHER), "PARTY")
timers[1]()
local answered = {}
for _, message in ipairs(sent) do answered[message[2]:match(" %d+%.%d+ %d+%.%d+ (.+)$")] = message[3] end
Check(#sent == 1 and answered[SHIP] == "PARTY" and not answered[OTHER],
    "the answer leaves out a ship someone else already answered as fresh")
Check(not answered["The Purple Princess"], "a received timing is not in the answer")
sent, timers = {}, {}
clock = 100
Hear("Q", "GUILD")
clock = 110
Hear("Q", "GUILD")
Check(#timers == 1, "the guild is answered at most once every half minute")

-- The world map's countdown and tooltip lines, from the same timings.
account.transportRides.Realm[OTHER] = nil
local UC, GG = "1411:Zeppelin to Undercity", "1411:Zeppelin to Grom'gol"
local BOAT = "1453:Boat to Auberdine"
Check(ns.TransportTimer("1424:Boat to Menethil Harbor", now) == nil, "a label with no stop has no timer")
local seconds = ns.TransportTimer(BOAT, now)
Check(seconds == false, "an untimed stop says so")
seconds = ns.TransportTimer(GG, now)
local inDock = ship.docks[1]
local _, color = ns.TransportTimer(GG, now)
Check(seconds and seconds > 0 and color, "a timed stop gives its countdown and color")
local tip = {}
local tooltip = {
    AddLine = function(_, text) tip[#tip + 1] = text end,
    AddDoubleLine = function(_, left, right) tip[#tip + 1] = left .. " | " .. right end,
}
ns.TransportTimerTip(tooltip, now, GG, UC)
Check(#tip == 3 and tip[1]:find("^Zeppelin to Grom'gol | Departs in %d:%d%d$")
    and tip[2] == "Zeppelin to Undercity | Not timed yet" and tip[3] == "Ride it once to time it.",
    "a tower's tooltip has a line for each of its zeppelins: " .. table.concat(tip, " / "))
Check(not tip[1]:find("~", 1, true), "a measured ship's countdown is not marked as an estimate")
tip = {}
ns.TransportTimerTip(tooltip, now, BOAT, nil)
Check(#tip == 2 and tip[1] == "Boat to Auberdine | Not timed yet" and tip[2] == "Time it from its minimap pin at the dock.",
    "an untimed boat says where to time it")
Check(inDock.arrive == 0, "the first dock of a ship starts its cycle")

-- The town map's dock pins: a stop for each destination, a countdown under the pin and a clock while the map is open.
local env = setmetatable({
    CreateFromMixins = function() return {} end,
    MapCanvasPinMixin = {}, MapCanvasDataProviderMixin = {},
    WorldMapFrame = { AddDataProvider = function() end, IsShown = function() return false end },
    C_Texture = { GetAtlasInfo = function() return true end },
    UIParent = Frame("UIParent"),
    UnitClass = function() return "Warrior", "WARRIOR" end,
    GameTooltip = { SetOwner = function() end, SetText = function() end, AddLine = function() end, Show = function() end,
        AddDoubleLine = function() end, IsOwned = function() return false end },
}, { __index = _G })
env._G = env
ns.Font = function(parent) return parent:CreateFontString() end
ns.ThemeTint = function() end
ns.TownCapitals, ns.TownNPCs, ns.TownMailboxes, ns.TownSpiritHealers, ns.ZoneExits = {}, {}, {}, {}, {}
ns.Shared.ScalePin = function() end
ns.Shared.PinClicks = function() end
ns.Shared.Settings.Group = function() end
dofile("NaowhForever_QoL/Interface/TownTravel.lua")
local chunk = assert(loadstring(Read("NaowhForever_QoL/Interface/TownMap.lua")))
setfenv(chunk, env)
chunk()
local Mixin = env.NaowhForeverZoneLinkPinMixin
local acquired = {}
local map = { GetMapID = function() return 1411 end }
function map:AcquirePin(_, link)
    local pin = Frame("Button")
    for k, fn in pairs(Mixin) do pin[k] = fn end
    pin.Icon = Frame("Texture")
    pin.Icon.SetAtlas, pin.Icon.SetRotation = function() end, function() end
    pin.SetPosition, pin.ApplyCurrentScale = function() end, function() end
    pin.GetMap = function() return map end
    pin:OnAcquired(link)
    acquired[#acquired + 1] = pin
    return pin
end
function map:RemoveAllPinsByTemplate() acquired = {} end
function map:EnumeratePinsByTemplate()
    local i = 0
    return function() i = i + 1; return acquired[i] end
end
local provider
env.WorldMapFrame.AddDataProvider = function(_, p) provider = p; p.GetMap = function() return map end end
ns.Apply()
Check(provider, "the town map's provider")
local function Clock()
    for _, f in ipairs(frames) do if f.parent == map then return f end end
end

provider:RefreshAllData()
local tower = acquired[1]
Check(#acquired == 1 and tower.link.stop == GG and tower.link.rightStop == UC,
    "Orgrimmar's tower pin carries both of its zeppelins' stops")
Check(tower.Time and tower.Time.shown and tower.Time.text:find(" / ", 1, true),
    "a timed tower shows both countdowns under the pin: " .. tostring(tower.Time and tower.Time.text))
Check(tower.Time.text:find("-:--", 1, true), "the zeppelin nobody timed shows no time")
local ticking = Clock()
Check(ticking and ticking.shown and ticking.scripts.OnUpdate, "a clock runs while the map is open")
now = now + 5
ticking.scripts.OnUpdate(ticking, 0.5)
local before = tower.Time.text
ticking.scripts.OnUpdate(ticking, 0.5)
Check(tower.Time.text ~= before, "the countdown is redrawn once a second")

S.Set("transportTimers", false)
provider:RefreshAllData()
Check(not acquired[1].Time or not acquired[1].Time.shown, "with the timers off the pin shows no countdown")
Check(not ticking.shown, "and the clock stops")
S.Set("transportTimers", true)
settings.townMap = false
provider:RefreshAllData()
Check(#acquired == 0 and not ticking.shown, "the town map off stops the clock too")
settings.townMap = true

-- The built-in schedule: a ship nobody here has timed still counts down, and a timing of your own replaces it.
dofile("NaowhForever_QoL/Travel/TransportSchedule.lua")
for name, row in pairs(ns.TransportSchedule) do
    Check(ns.TransportRoutes[name], "a scheduled ship is one of the timed ships: " .. name)
    Check(row.at > 1.7e9 and row.at < now + 1e8 and row.period == nil, name .. " has a cycle start on the server clock")
end
local PRINCESS = "The Purple Princess"
local princess = ns.TransportRoutes[PRINCESS]
account.transportRides.Realm[PRINCESS] = nil
local start = ns.TransportSchedule[PRINCESS].at
local at = start + 10 * princess.period + princess.docks[1].leave - 5
local left, kind = Times.Dock(PRINCESS, 1, at)
Check(kind == "departure" and math.abs(left - 5) < 1e-6, "the schedule times a ship you never rode: " .. tostring(left))
Check(Times.Latest(PRINCESS) == nil, "the schedule is not sent on as your own timing")
left, kind = Times.Dock(PRINCESS, 1, start + 30 * 86400)
Check(left == nil and kind == "expired", "a schedule too many cycles old is no longer used")
Check(Times.Ride(PRINCESS, start + 20.5) and math.abs(Times.Dock(PRINCESS, 1, start + 21) - (princess.docks[1].leave - 0.5)) < 1e-6,
    "a ride of your own replaces the schedule")
Check(ns.TransportTimer(princess.docks[2].stop, start + 21), "the world map shows the scheduled ship's other dock")

local town = Read("NaowhForever_QoL/Interface/TownMap.lua")
Check(town:find('key == "transportTimers"', 1, true), "switching the timers redraws the open map")
Check(Read("Core/Features.lua"):find("transportTimers = false", 1, true), "Boat and Zeppelin Timers stays off by default")
Check(Read("NaowhForever_QoL/QoL.xml"):find('TransportRoutes.lua"/>\n    <Script file="Travel\\TransportSchedule.lua"/>\n'
    .. '    <Script file="Travel\\TransportTimes.lua"/>', 1, true), "the schedule loads before the times that read it")
Check(Read("NaowhForever_QoL/QoL.xml"):find('TransportRide.lua"/>\n    <Script file="Travel\\TransportShare.lua"/>\n'
    .. '    <Script file="Travel\\Transport.lua"/>', 1, true), "the sharing loads between the ride watch and the timers")

print("transport map: " .. checks .. " checks passed")

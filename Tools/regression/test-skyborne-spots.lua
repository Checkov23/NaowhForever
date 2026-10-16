-- Run with Lua 5.1 from the repository root: Skyborne Spots. The racial cast on a spot gives
-- its buff, and the spot is saved once; a find close to a known spot is that spot, a buff
-- unreadable in combat is looked at again after it, other races watch nothing, and the map
-- pins the character's own kind only, the shipped ones and the found ones.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local LEY_CAST, LEY_BUFF, SKY_CAST, SKY_BUFF = 1259705, 1259691, 1259686, 1270893

local settings = { enabled = true, mapSkyborne = true, mapSkyborneSize = 20 }
local S = { Get = function(key) return settings[key] end, Set = function() end }
local account, printed = {}, {}
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    QoLConstants = dofile("Tools/regression/qol_constants.lua"),
    QoLSettings = S,
    Apply = function() end,
    AccountSettings = function() return account end,
    Print = function(msg) printed[#printed + 1] = msg end,
    ThemeTint = function() return nil end,
    PlaceWaypoint = function() end,
    Shared = { Style = dofile("Tools/regression/shared_style.lua"), MapPins = {} },
}

local race, faction, combat, now = "Skyborne", "Horde", false, 1000
local where = { map = 2521, x = 0.20, y = 0.10 }
local buffs = {}
local function Vector(x, y) return { GetXY = function() return x, y end } end

-- Frames in the order the file makes them: the watcher first, then the login frame.
local frames = {}
local function NewFrame()
    local f = { events = {}, unitEvents = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:RegisterUnitEvent(e) self.unitEvents[e] = true end
    function f:UnregisterAllEvents() self.events, self.unitEvents = {}, {} end
    function f:SetScript(_, fn) self.onEvent = fn end
    frames[#frames + 1] = f
    return f
end

-- Timers run when the test says so.
local timers = {}
local function RunTimers()
    while #timers > 0 do table.remove(timers, 1)() end
end

local pins = {}
local mapShown = {
    GetMapID = function() return 2521 end,
    IsMaximized = function() return false end,
    AcquirePin = function(_, _, entry, x, y) pins[#pins + 1] = { entry = entry, x = x, y = y } end,
    RemoveAllPinsByTemplate = function() for i = #pins, 1, -1 do pins[i] = nil end end,
}
local provider

local function Mixin(...)
    local t = {}
    for i = 1, select("#", ...) do for k, v in pairs(select(i, ...)) do t[k] = v end end
    return t
end

local env = setmetatable({
    _G = { NaowhForever = ns },
    CreateFromMixins = Mixin,
    CreateVector2D = Vector,
    MapCanvasPinMixin = {},
    MapCanvasDataProviderMixin = { GetMap = function() return mapShown end },
    CreateFrame = NewFrame,
    hooksecurefunc = function() end,
    GameTooltip = { Hide = function() end },
    InCombatLockdown = function() return combat end,
    C_Secrets = { ShouldAurasBeSecret = function() return combat end },
    GetTime = function() return now end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    UnitRace = function() return "Windshaper Skyborne", race, 96 end,
    UnitFactionGroup = function() return faction end,
    C_Map = {
        GetBestMapForUnit = function() return where.map end,
        GetPlayerMapPosition = function() return Vector(where.x, where.y) end,
        GetMapInfo = function() return { name = "Zephras Isle", mapType = 3 } end,
        -- 1000 yards across the zone, on continent 1.
        GetWorldPosFromMapPos = function(_, v)
            local x, y = v:GetXY()
            return 1, Vector(x * 1000, y * 1000)
        end,
        GetMapPosFromWorldPos = function() return 1, nil end,
    },
    C_UnitAuras = {
        GetPlayerAuraBySpellID = function(id)
            if combat then error("secret in combat") end
            return buffs[id]
        end,
    },
    WorldMapFrame = {
        IsShown = function() return true end,
        HookScript = function() end,
        AddDataProvider = function(_, p) provider = p end,
    },
}, { __index = _G })
for _, file in ipairs({ "NaowhForever_QoL/Interface/SkyborneData.lua", "NaowhForever_QoL/Interface/SkyborneSpots.lua" }) do
    local chunk = assert(loadstring(Read(file)))
    setfenv(chunk, env)
    chunk()
end
local watch, boot = frames[1], frames[2]

-- The shipped list: every spot on a real map, in percent.
local shipped = 0
for kind, list in pairs(ns.SkyborneSpots) do
    for _, spot in ipairs(list) do
        Check(type(spot[1]) == "number" and spot[2] > 0 and spot[2] < 100 and spot[3] > 0 and spot[3] < 100,
            "a shipped " .. kind .. " in percent")
        shipped = shipped + 1
    end
end
Check(#ns.SkyborneSpots.leyline == 76 and #ns.SkyborneSpots.convergence == 56, "76 ley lines, 56 convergences")
Check(Read("NaowhForever_QoL/Interface/SkyborneData.lua"):find("Copyright (c) 2026 tr0tsky", 1, true), "with tr0tsky's notice")

Check(Read("Core/Settings.lua"):find("mapSkyborne = F.mapSkyborne,", 1, true)
    and Read("Core/Features.lua"):find("mapSkyborne = false,", 1, true), "Skyborne Spots starts off")
local section = ns.Shared.MapPins[1]
Check(section and section.switch == "mapSkyborne" and section.store == S and section.rows[1].key == "mapSkyborne",
    "its section on Map & Pins switches the setting")
Check(section.rows[2].key == "mapSkyborneSize" and section.rows[2].needs == "mapSkyborne", "the pin size waits for the switch")

local function CastAt(spellID, buffID, duration)
    now = now + 100
    watch.onEvent(watch, "UNIT_SPELLCAST_SUCCEEDED", "player", "guid", spellID)
    if buffID then buffs[buffID] = { duration = duration, expirationTime = now + duration } end
    RunTimers()
end

-- A spot found before it shipped with the addon is dropped from the found list on the first draw.
local shipped2521
for _, spot in ipairs(ns.SkyborneSpots.convergence) do
    if spot[1] == 2521 then shipped2521 = spot break end
end
account.skyborneSpots = { convergence = { { shipped2521[1], shipped2521[2], shipped2521[3] } } }
boot.onEvent(boot, "PLAYER_LOGIN")
Check(watch.unitEvents.UNIT_SPELLCAST_SUCCEEDED, "a Skyborne watches its casts")
Check(#account.skyborneSpots.convergence == 0, "a found spot that now ships with the addon is dropped")

CastAt(SKY_CAST, nil)
Check(not account.skyborneSpots or #account.skyborneSpots.convergence == 0, "Skysight away from a spot saves nothing")

CastAt(SKY_CAST, SKY_BUFF, 900)
local found = account.skyborneSpots.convergence
Check(#found == 1 and found[1][1] == 2521 and found[1][2] == 20 and found[1][3] == 10,
    "Skysight that gives Elemental Blessing saves the spot, in percent")
Check(printed[1] and printed[1]:find("Elemental Convergence saved", 1, true), "and says so")

where.x = 0.215   -- 15 yards on
buffs = {}
CastAt(SKY_CAST, SKY_BUFF, 900)
Check(#found == 1, "a find a few yards away is the same spot")

where.x, where.y = 0.4844, 0.2031   -- a shipped convergence
buffs = {}
CastAt(SKY_CAST, SKY_BUFF, 900)
Check(#found == 1, "a shipped spot is not saved again")

where.x, where.y = 0.9, 0.9
buffs = {}
CastAt(LEY_CAST, LEY_BUFF, 900)
Check(#found == 1, "the other faction's racial does nothing")

combat = true
buffs = {}
CastAt(SKY_CAST, SKY_BUFF, 900)
Check(#found == 1 and watch.events.PLAYER_REGEN_ENABLED, "in combat the buff waits for combat to end")
combat = false
watch.onEvent(watch, "PLAYER_REGEN_ENABLED")
Check(#found == 2 and found[2][2] == 90, "and is saved then")

provider:RefreshAllData()
local mine, theirs = 0, 0
for _, pin in ipairs(pins) do
    Check(pin.entry.kind == "convergence", "a Horde map shows convergences only")
    if pin.entry.found then mine = mine + 1 else theirs = theirs + 1 end
end
Check(mine == 2 and theirs == 15, "the two found and Zephras Isle's 15 shipped")

settings.mapSkyborne = false
provider:RefreshAllData()
Check(#pins == 0, "no pins while off")
settings.mapSkyborne = true

faction = "Alliance"
where.x, where.y = 0.1, 0.1
buffs = {}
boot.onEvent(boot, "PLAYER_LOGIN")
CastAt(LEY_CAST, LEY_BUFF, 600)
Check(#account.skyborneSpots.leyline == 1, "Read Ley Line that gives Energized saves a ley line")
provider:RefreshAllData()
Check(#pins == 14 and pins[1].entry.kind == "leyline", "an Alliance map shows ley lines, not convergences")

Check(Read("NaowhForever_QoL/Interface/SkyborneSpots.xml"):find('registerForClicks="LeftButtonUp, RightButtonUp"', 1, true),
    "a pin takes right-clicks")
local foundPin
for _, pin in ipairs(pins) do
    if pin.entry.found then foundPin = pin end
end
env.NaowhForeverSkybornePinMixin.OnClick(foundPin, "RightButton")
Check(#account.skyborneSpots.leyline == 0 and #pins == 13, "a right-click forgets a found spot")

race = "Human"
boot.onEvent(boot, "PLAYER_LOGIN")
Check(next(watch.unitEvents) == nil, "another race watches nothing")
provider:RefreshAllData()
Check(#pins == 0, "and sees no pins")

print(("test-skyborne-spots: %d checks passed (%d shipped spots)"):format(checks, shipped))

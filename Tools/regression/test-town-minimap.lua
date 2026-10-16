-- Run with Lua 5.1 from the repository root: the town map's minimap pins. With the setting on,
-- the zone's mailboxes and spirit healers (whatever the world map's toggles for them say) are
-- pinned around the player in yards, sized from Town Pin Size, scaled to the minimap's view radius, hidden out of range,
-- turned with a rotating minimap, placed often only while moving, and nothing is registered
-- while the setting is off.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local settings = { enabled = true, townMap = true, townMinimap = false, townMail = false, townSpiritHealers = false,
    townPinSize = 20 }
local S = { Get = function(key) return settings[key] end, Set = function() end }
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    QoLConstants = dofile("Tools/regression/qol_constants.lua"),
    QoLSettings = S, Apply = function() end, ThemeTint = function() end,
    TownCapitals = {}, TownNPCs = {},
    TownMailboxes = { [1] = { { 55, 50, "mail", "Mailbox", "", nil, "AH" }, { 50, 30, "mail", "Mailbox", "", nil, "AH" } } },
    TownSpiritHealers = { [1] = { { 50, 55, "spirit", "Spirit Healer", "Graveyard", nil, "AH" } } },
    Shared = { Style = dofile("Tools/regression/shared_style.lua"), Places = dofile("Tools/regression/shared_places.lua"),
        Settings = { Group = function() end, Page = function() return { Card = function() end } end } },
}

local frames = {}
local function NewFrame()
    local f = { events = {}, scripts = {}, shown = true }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:SetSize(w) self.size = w end
    function f:SetPoint(_, _, _, x, y) self.x, self.y = x, y end
    function f:SetShown(shown) self.shown = shown end
    function f:Hide() self.shown = false end
    f.Icon = { SetTexCoord = function() end, SetTexture = function() return true end,
        AddMaskTexture = function() end, RemoveMaskTexture = function() end }
    f.Border = { Show = function() end, Hide = function() end }
    function f:CreateMaskTexture() return { SetTexture = function() end, SetAllPoints = function() end } end
    frames[#frames + 1] = f
    return f
end

local player = { 0.5, 0.5 }
local facing, rotate, walking, continent = 0, false, false, 0
local bestMap = 1
-- World coordinates as the game has them: the axes swapped and mirrored from the map's.
local function World(x, y) return 5000 - y * 1000, 3000 - x * 1000 end
local function Vector(x, y) return { GetXY = function() return x, y end } end
local env = setmetatable({
    _G = { NaowhForever = ns },
    CreateFromMixins = function() return {} end,
    MapCanvasPinMixin = {}, MapCanvasDataProviderMixin = {},
    CreateFrame = function(_, _, parent) local f = NewFrame(); f.parent = parent; return f end,
    hooksecurefunc = function() end,
    WorldMapFrame = { AddDataProvider = function() end, IsShown = function() return false end,
        dataProviders = {}, EnumeratePinsByTemplate = function() return function() end end },
    Minimap = { GetWidth = function() return 200 end, GetHeight = function() return 200 end },
    C_Map = {
        GetBestMapForUnit = function() return bestMap end,
        GetMapWorldSize = function() return 1000, 1000 end,
        GetWorldPosFromMapPos = function(_, pos) return 0, Vector(World(pos:GetXY())) end,
        GetPlayerMapPosition = function() error("makes a table on every tick") end,
    },
    CreateVector2D = Vector,
    C_Texture = { GetAtlasInfo = function() return nil end },
    UnitPosition = function()
        local wx, wy = World(player[1], player[2])
        return wx, wy, 0, continent
    end,
    IsPlayerMoving = function() return walking end,
    C_Minimap = { GetViewRadius = function() return 100 end },
    C_CVar = { GetCVarBool = function() return rotate end },
    GetPlayerFacing = function() return facing end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
}, { __index = _G })
local chunk = assert(loadstring(Read("NaowhForever_QoL/Interface/TownMap.lua")))
setfenv(chunk, env)
chunk()

local boot, mini
for _, f in ipairs(frames) do
    if f.events.PLAYER_LOGIN then boot = f end
end
mini = frames[1]
Check(boot and mini.scripts.OnEvent, "the town map's frames")

boot.scripts.OnEvent()
Check(next(mini.events) == nil, "nothing registered while the minimap setting is off")

settings.townMinimapSpirit = true
boot.scripts.OnEvent()
-- The pins on the minimap now: east is the near mailbox, south the spirit healer (the other
-- mailbox is out of range).
local function Shown()
    local out = {}
    for _, f in ipairs(frames) do
        if f.parent == env.Minimap and f.shown then
            out[#out + 1] = math.abs(f.y or 0) < 1e-6 and "mailbox" or "healer"
        end
    end
    return table.concat(out, " ")
end
Check(Shown() == "healer" and mini.events.ZONE_CHANGED_NEW_AREA, "spirit healers alone: no mailboxes")
settings.townMinimap, settings.townMinimapSpirit = true, false
boot.scripts.OnEvent()
Check(Shown() == "mailbox", "mailboxes alone: no spirit healer")
settings.townMinimapSpirit = true
boot.scripts.OnEvent()
local pins = {}
for _, f in ipairs(frames) do
    if f.parent == env.Minimap then pins[#pins + 1] = f end
end
Check(#pins == 3 and mini.events.PLAYER_STARTED_MOVING and mini.events.ZONE_CHANGED_NEW_AREA,
    "a pin for each mailbox and spirit healer, with the world map's toggles for them off")
local east, north, south = pins[1], pins[2], pins[3]
Check(math.abs(east.x - 50) < 1e-6 and math.abs(east.y) < 1e-6 and east.shown, "50 yards east, in range")
Check(not north.shown, "200 yards north is out of range")
Check(math.abs(south.y + 50) < 1e-6 and south.shown, "50 yards south, below the player")
Check(mini.scripts.OnUpdate == nil, "standing still nothing runs")
Check(math.abs(east.size - 18) < 1e-6 and math.abs(south.size - 18) < 1e-6, "Town Pin Size 20 is 18 on the minimap")
settings.townPinSize = 30
boot.scripts.OnEvent()
Check(math.abs(east.size - 27) < 1e-6 and math.abs(south.size - 27) < 1e-6, "the minimap pins follow Town Pin Size")
settings.townPinSize = 20
boot.scripts.OnEvent()

mini.scripts.OnEvent(mini, "PLAYER_STARTED_MOVING")
Check(mini.scripts.OnUpdate ~= nil, "placed while moving")
player[1] = 0.53
mini.scripts.OnUpdate(mini, 0.1)
Check(math.abs(east.x - 20) < 1e-6, "the pin follows as you walk")
mini.scripts.OnEvent(mini, "PLAYER_STOPPED_MOVING")
Check(mini.scripts.OnUpdate == nil, "and stops when you stop")

player[1] = 0.5
rotate, facing = true, math.pi / 2
mini.scripts.OnEvent(mini, "MINIMAP_UPDATE_ZOOM")
Check(math.abs(east.x) < 1e-6 and math.abs(east.y + 50) < 1e-6, "facing west, east is behind you")
rotate, facing = false, 0

continent = 1
mini.scripts.OnEvent(mini, "MINIMAP_UPDATE_ZOOM")
Check(not east.shown and not south.shown, "on another continent the pins hide")
continent = 0

walking = true
mini.scripts.OnEvent(mini, "PLAYER_STARTED_MOVING")
settings.townMinimap, settings.townMinimapSpirit = false, false
boot.scripts.OnEvent()
Check(not east.shown and not south.shown and next(mini.events) == nil, "turning it off clears the minimap")
Check(mini.scripts.OnUpdate == nil, "and stops placing pins")
walking = false
settings.townMinimap, settings.townMinimapSpirit = true, true
boot.scripts.OnEvent()
Check(mini.scripts.OnUpdate == nil, "back on while standing still, nothing runs")

ns.TownMailboxes[2521], ns.TownSpiritHealers[2521] = ns.TownMailboxes[1], ns.TownSpiritHealers[1]
bestMap = 2665
boot.scripts.OnEvent()
Check(Shown() == "mailbox healer", "on Zephras Isle's second map, the pins of its first (2521)")
bestMap = 2521
boot.scripts.OnEvent()
Check(Shown() == "mailbox healer", "and on 2521 itself")
bestMap = 7
boot.scripts.OnEvent()
Check(Shown() == "", "a map with no data has no pins")
bestMap = 1
settings.townMinimap = false
boot.scripts.OnEvent()

Check(Read("Core/Settings.lua"):find("townMinimap = true", 1, true), "Minimap mailboxes start on")
Check(Read("Core/Settings.lua"):find("townMinimapSpirit = true", 1, true), "Minimap spirit healers start on")

print(("test-town-minimap: %d checks passed"):format(checks))

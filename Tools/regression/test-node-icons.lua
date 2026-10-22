-- Run with Lua 5.1 from the repository root: Minimap Node Icons (NodeScan.lua, UI/NodeIcons.lua).
-- A stub minimap names the herbs and veins under its soft cursor, as the game's minimap tooltip
-- does, for dots that stay put in the world while the player walks and turns. The scan finds each
-- dot, a fine probe puts its icon on the dot's middle, and Parts.MinimapLayer keeps it there while the
-- player walks and turns. A rescan waits for time or distance and leaves found nodes alone; nothing
-- runs while no Find is tracked or off the map; a node above your skill is ringed red, with its skill on
-- the tooltip; Glimmer can ask where a live icon is; and on a client whose node names are not English it
-- stays off. The data table matches Glimmer's herbs and veins, name for name and skill for skill.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Near(a, b, within) return math.abs(a - b) <= within end

local WIDTH, LEFT, BOTTOM = 140, 100, 200
local VIEW_RADIUS = 140
local MAP_YARDS = 1000
local MAP_ID, CONTINENT = 1429, 0
local DOT = 5
local SCALE = WIDTH / 2 / VIEW_RADIUS
local ON_DOT = 1
local FINE_PROBES = 2 * 21
local DOTS = {
    { name = "Tin Vein", x = 40, y = 90 },
    { name = "Copper Vein", x = 100, y = 50 },
    { name = "Peacebloom", x = 70, y = 105 },
}

local function Noop() end
local softCursor, mouseOver, inCombat, moving = false, false, false, false
local probes, probesWithoutCursor = 0, 0
local cursorX, cursorY
local rotate, facing = false, 0
local player = { x = 0.5, y = 0.5 }
local onMap, trackingOn = true, true
local locale = "enUS"
local tooltipHook
local boot
local frames, pins = {}, {}

local function Texture()
    local t = {}
    function t.SetTexture(self, tex) self.texture = tex end
    function t.SetSize(self, w) self.size = w end
    function t.SetVertexColor(self, r, g, b) self.rgb = { r, g, b } end
    setmetatable(t, { __index = function(_, k) if k:find("^%u") then return Noop end end })
    return t
end

local frameMethods = {
    SetScript = function(f, name, fn) f[name] = fn end,
    RegisterEvent = function(f, event)
        f.events[event] = true
        if event == "PLAYER_LOGIN" then boot = f end
    end,
    UnregisterEvent = function(f, event) f.events[event] = nil end,
    UnregisterAllEvents = function(f) f.events = {} end,
    CreateTexture = function() return Texture() end,
    CreateMaskTexture = function() return Texture() end,
    GetFrameLevel = function() return 1 end,
    SetPoint = function(f, _, _, _, x, y) f.x, f.y = x, y end,
    Show = function(f) f.shown = true end,
    Hide = function(f) f.shown = false end,
}
local frameMeta = { __index = function(_, k) return frameMethods[k] or Noop end }

local Minimap = setmetatable({ events = {} }, frameMeta)
function Minimap.GetWidth() return WIDTH end
function Minimap.GetHeight() return WIDTH end
function Minimap.GetLeft() return LEFT end
function Minimap.GetBottom() return BOTTOM end
function Minimap.GetEffectiveScale() return 1 end
function Minimap.IsVisible() return true end
function Minimap.IsMouseOver() return mouseOver end
function Minimap.SetUsingSoftCursor(_, on) softCursor = on end
function Minimap.UpdateMouseoverAtPoint(_, x, y)
    probes = probes + 1
    if not softCursor then probesWithoutCursor = probesWithoutCursor + 1 end
    cursorX, cursorY = x - LEFT, y - BOTTOM
end

for _, dot in ipairs(DOTS) do
    dot.east, dot.north = (dot.x - WIDTH / 2) / SCALE, (dot.y - WIDTH / 2) / SCALE
end

local function DotScreen(dot)
    local east = dot.east - (player.x - 0.5) * MAP_YARDS
    local north = dot.north + (player.y - 0.5) * MAP_YARDS
    local turn = rotate and -facing or 0
    local c, s = math.cos(turn), math.sin(turn)
    return WIDTH / 2 + (east * c - north * s) * SCALE, WIDTH / 2 + (east * s + north * c) * SCALE
end

local function Mouseover()
    if not softCursor then return nil end
    local names = {}
    for _, dot in ipairs(DOTS) do
        local x, y = DotScreen(dot)
        local dx, dy = cursorX - x, cursorY - y
        if dx * dx + dy * dy <= DOT * DOT then names[#names + 1] = dot.name end
    end
    if #names == 0 then return { lines = {} } end
    return { lines = { { leftText = "|cffffffff" .. table.concat(names, "\n") .. "|r" } } }
end

local function CreateFrame(_, _, parent)
    local f = setmetatable({ events = {} }, frameMeta)
    frames[#frames + 1] = f
    if parent == Minimap then pins[#pins + 1] = f end
    return f
end

local function Vector(x, y) return { x = x, y = y, GetXY = function(v) return v.x, v.y end } end

local profession = { herb = nil, ore = 50, oreBonus = 0 }
local settings = { enabled = true, nodeIcons = true, nodeIconSize = 12 }
local setHook
local RED, BORDER = { r = 1, g = 0.3, b = 0.3 }, { r = 0, g = 0, b = 0 }
local ns = {
    L = dofile("Tools/regression/locale_stub.lua").L,
    Apply = Noop,
    Shared = { Parts = {} },
    Professions = {
        Settings = { Get = function(k) return settings[k] end, Set = Noop },
        Style = {
            RED_RGB = RED, BORDER_RGB = BORDER, ICON_CROP = 0.08, ICON_CROP_HIGH = 0.92,
            DIFFICULTY_RGB = { [0] = { r = 1, g = 0.5, b = 0.25 }, [1] = { r = 1, g = 1, b = 0 },
                [2] = { r = 0.25, g = 0.75, b = 0.25 }, [3] = { r = 0.55, g = 0.55, b = 0.55 } },
        },
    },
}

local env = setmetatable({
    NaowhForever = ns,
    Minimap = Minimap,
    CreateFrame = CreateFrame,
    CreateVector2D = Vector,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    issecretvalue = function() return false end,
    InCombatLockdown = function() return inCombat end,
    IsPlayerMoving = function() return moving end,
    GetLocale = function() return locale end,
    GetPlayerFacing = function() return facing end,
    GetMinimapShape = function() return "ROUND" end,
    UnitPosition = function()
        if not onMap then return nil end
        return player.x * MAP_YARDS, player.y * MAP_YARDS, 0, CONTINENT
    end,
    GetProfessions = function() return profession.ore and 1 or nil, profession.herb and 2 or nil end,
    GetProfessionInfo = function(index)
        if index == 1 then return "Mining", nil, profession.ore, 300, nil, nil, 186, profession.oreBonus end
        return "Herbalism", nil, profession.herb, 300, nil, nil, 182, 0
    end,
    C_CVar = { GetCVarBool = function(name) return name == "rotateMinimap" and rotate end },
    C_TooltipInfo = { GetMinimapMouseover = Mouseover },
    C_Map = {
        GetBestMapForUnit = function() return MAP_ID end,
        GetPlayerMapPosition = function() if onMap then return Vector(player.x, player.y) end end,
        GetMapWorldSize = function() return MAP_YARDS, MAP_YARDS end,
        GetWorldPosFromMapPos = function(_, v) return CONTINENT, Vector(v.x * MAP_YARDS, v.y * MAP_YARDS) end,
    },
    C_Minimap = {
        GetViewRadius = function() return VIEW_RADIUS end,
        GetNumTrackingTypes = function() return 1 end,
        GetTrackingInfo = function() return { active = trackingOn, spellID = 2580 } end,
    },
    C_Item = { GetItemIconByID = function(id) return "item:" .. id end },
    C_Spell = { GetSpellTexture = function(id) return "spell:" .. id end },
    Enum = { TooltipDataType = { MinimapMouseover = 22 } },
    TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) tooltipHook = fn end },
    hooksecurefunc = function(target, name, fn)
        if target == ns.Professions.Settings and name == "Set" then setHook = fn end
    end,
}, { __index = _G })
env._G = env

Load({
    "Shared/UI/MinimapPins.lua",
    "NaowhForever_Professions/Constants.lua",
    "NaowhForever_Professions/Data/GatherNodes.lua",
    "NaowhForever_Professions/NodeScan.lua",
    "NaowhForever_Professions/UI/NodeIcons.lua",
}, env)

local function Find(event)
    for _, f in ipairs(frames) do
        if f.events[event] and f ~= boot then return f end
    end
end

local function Shown()
    local list = {}
    for _, pin in ipairs(pins) do
        if pin.shown then list[#list + 1] = pin end
    end
    return list
end

local function RingNear(x, y)
    local half = WIDTH / 2
    for _, pin in ipairs(Shown()) do
        if Near(pin.x, x - half, 4) and Near(pin.y, y - half, 4) then return pin end
    end
end

local function Off(dot)
    local x, y = DotScreen(dot)
    local best
    for _, pin in ipairs(Shown()) do
        local d = math.sqrt((pin.x + WIDTH / 2 - x) ^ 2 + (pin.y + WIDTH / 2 - y) ^ 2)
        if not best or d < best then best = d end
    end
    return best or math.huge
end

local function AllOnDots()
    for _, dot in ipairs(DOTS) do
        if Off(dot) > ON_DOT then return false end
    end
    return true
end

boot.OnEvent(boot, "PLAYER_LOGIN")
local events = Find("MINIMAP_UPDATE_TRACKING")
check("logging in with Find Minerals tracked starts the scan", events and rawget(events, "OnUpdate") ~= nil)
check("the minimap tooltip gets the skill line hook", tooltipHook ~= nil)

local function Frames(n, elapsed)
    for _ = 1, n do events.OnUpdate(events, elapsed or 0.1) end
end

local function Fire(event)
    events.OnEvent(events, event)
end

Frames(20)
local firstScan = probes
local layerFrame = Find("PLAYER_STARTED_MOVING")
check("the grid was probed", probes > 0)
check("every probe ran with the soft cursor on", probesWithoutCursor == 0)
check("the soft cursor is off between frames", softCursor == false)
check("one icon per dot", #Shown() == #DOTS)
check("each icon sits on its dot's middle, not on the grid", AllOnDots())
check("the icons are drawn through Parts.MinimapLayer", layerFrame ~= nil and rawget(layerFrame, "layer") ~= nil)

local tin = RingNear(40, 90)
local copper = RingNear(100, 50)
local bloom = RingNear(70, 105)
check("Tin Vein sits on its dot", tin ~= nil)
check("Copper Vein sits on its dot", copper ~= nil)
check("Peacebloom sits on its dot", bloom ~= nil)
check("Tin Vein (65) is ringed red at Mining 50", tin.ring.rgb[1] == RED.r and tin.ring.rgb[2] == RED.g)
check("Copper Vein (1) has the plain ring", copper.ring.rgb[1] == BORDER.r and copper.ring.rgb[2] == BORDER.g)
check("Peacebloom is red with no Herbalism", bloom.ring.rgb[1] == RED.r)
check("Tin Vein shows Tin Ore's icon", tin.art.texture == "item:2771")
check("Copper Vein shows Copper Ore's icon", copper.art.texture == "item:2770")
check("Peacebloom shows its herb's icon", bloom.art.texture == "item:2447")

profession.oreBonus = 20
Fire("SKILL_LINES_CHANGED")
check("a Mining bonus counts: Tin Vein (65) is gatherable at 50 plus 20", tin.ring.rgb[1] == BORDER.r)
profession.oreBonus = 0
Fire("SKILL_LINES_CHANGED")

local before = probes
Frames(15)
check("standing still, no rescan before its interval", probes == before)
check("and the layer is idle while not moving", rawget(layerFrame, "OnUpdate") == nil)
Frames(60)
check("after the interval it scans again", probes > before)
check("a rescan leaves the nodes it still finds alone, with no fine probe",
    probes - before + #DOTS * FINE_PROBES == firstScan)
check("and every icon stays on its dot", AllOnDots())

profession.ore = 70
Fire("SKILL_LINES_CHANGED")
before = probes
mouseOver = true
Frames(80)
check("no probing while the real mouse is over the minimap", probes == before)

moving = true
layerFrame.OnEvent(layerFrame, "PLAYER_STARTED_MOVING")
player.x = player.x + 10 / MAP_YARDS
layerFrame.OnUpdate(layerFrame, 0.05)
check("ten yards east moves the icons five units left", RingNear(40 - 5, 90) ~= nil and RingNear(100 - 5, 50) ~= nil)
player.y = player.y - 10 / MAP_YARDS
layerFrame.OnUpdate(layerFrame, 0.05)
check("then ten yards north moves them five units down", RingNear(35, 90 - 5) ~= nil)
check("and every icon is still on its dot", AllOnDots())
moving = false
layerFrame.OnEvent(layerFrame, "PLAYER_STOPPED_MOVING")

mouseOver = false
inCombat = true
before = probes
Frames(80)
check("no probing in combat", probes == before)
inCombat = false

player.x, player.y = 0.5, 0.5
Frames(80)
check("back in place, a fresh scan puts Tin Vein back", RingNear(40, 90) ~= nil)

before = probes
player.x = player.x + 25 / MAP_YARDS
Frames(6)
check("walking further than the rescan distance scans at once", probes > before)
Frames(20)
player.x = 0.5
Frames(6)
Frames(20)

rotate, facing = true, math.pi / 2
Fire("MINIMAP_UPDATE_TRACKING")
Frames(20)
check("a rotating minimap facing west puts Tin Vein a quarter turn round", RingNear(70 + 20, 70 + 30) ~= nil)
check("each icon on its dot", AllOnDots())
check("the layer follows a rotating minimap", rawget(layerFrame, "OnUpdate") ~= nil)
mouseOver = true
facing = math.pi
layerFrame.OnUpdate(layerFrame, 0.05)
check("turning a quarter left turns the icons a quarter right", RingNear(70 + 30, 70 - 20) ~= nil
    and RingNear(70 - 30, 70 + 20) ~= nil)
check("and keeps each on its dot", AllOnDots())
mouseOver, rotate, facing = false, false, 0
Fire("MINIMAP_UPDATE_TRACKING")
Frames(20)

local worst = 0
moving = true
layerFrame.OnEvent(layerFrame, "PLAYER_STARTED_MOVING")
for _ = 1, 80 do
    player.x = player.x + 0.4 / MAP_YARDS
    player.y = player.y + 0.1 / MAP_YARDS
    Frames(1)
    layerFrame.OnUpdate(layerFrame, 0.05)
    for _, dot in ipairs(DOTS) do worst = math.max(worst, Off(dot)) end
end
moving = false
layerFrame.OnEvent(layerFrame, "PLAYER_STOPPED_MOVING")
check("walking through rescans, no icon strays from its dot (" .. worst .. ")", worst <= ON_DOT)
player.x, player.y = 0.5, 0.5
Fire("MINIMAP_UPDATE_TRACKING")
Frames(20)

local x, y = 0.5 + DOTS[1].east / MAP_YARDS, 0.5 - DOTS[1].north / MAP_YARDS
check("Glimmer can see a live icon on a spot", ns.NodeIconAt(MAP_ID, x, y) == true)
check("but not ten yards away from it", ns.NodeIconAt(MAP_ID, x + 10 / MAP_YARDS, y) == false)
check("nor on another map", ns.NodeIconAt(MAP_ID + 1, x, y) == false)

onMap = false
Fire("ZONE_CHANGED_NEW_AREA")
before = probes
Frames(80)
check("with no map position (an instance) the icons are hidden", #Shown() == 0)
check("and nothing is probed", probes == before)
check("nor is there a live icon for Glimmer", ns.NodeIconAt(MAP_ID, x, y) == false)
onMap = true
Fire("ZONE_CHANGED_NEW_AREA")
Frames(20)
check("back on the map, the icons come back", #Shown() == #DOTS)

trackingOn = false
Fire("MINIMAP_UPDATE_TRACKING")
check("Find Minerals off: the scan stops", rawget(events, "OnUpdate") == nil)
check("and the icons go", #Shown() == 0)
check("and the layer stops listening", next(layerFrame.events) == nil)
trackingOn = true
Fire("MINIMAP_UPDATE_TRACKING")
check("Find Minerals on again: the scan starts", rawget(events, "OnUpdate") ~= nil)
Frames(20)

local tooltip = { added = {} }
function tooltip.AddLine(self, text, r) self.added[#self.added + 1] = { text = text, r = r } end
tooltip.Show = Noop
profession.ore = 50
ns.Professions.NodeScan.ReadSkills()
tooltipHook(tooltip, { lines = { { leftText = "Tin Vein" } } })
check("hovering Tin Vein says the Mining it needs", tooltip.added[1] and tooltip.added[1].text == "Requires Mining 65")
check("in red, as Mining 50 is too low", tooltip.added[1].r == RED.r)
tooltip.added = {}
tooltipHook(tooltip, { lines = { { leftText = "Copper Vein\nPeacebloom" } } })
check("two nodes under the mouse each name their own need", #tooltip.added == 2
    and tooltip.added[1].text == "Copper Vein: Requires Mining 1"
    and tooltip.added[2].text == "Peacebloom: Requires Herbalism 1")
tooltip.added = {}
tooltipHook(tooltip, { lines = { { leftText = "Kobold Tunneler" } } })
check("a creature on the minimap gets no skill line", #tooltip.added == 0)

local function Smallest()
    local smallest = math.huge
    for _, pin in ipairs(Shown()) do smallest = math.min(smallest, pin.ring.size) end
    return smallest
end

settings.nodeIconSize = 6
setHook("nodeIconSize")
Frames(20)
check("a size saved below the slider's 10 draws at 10", Smallest() == 10 + 3)
settings.nodeIconSize = 10
setHook("nodeIconSize")
check("Icon Size 10 draws at 10", Smallest() == 10 + 3)
settings.nodeIconSize = 22
setHook("nodeIconSize")
check("and a bigger size is drawn as set", Smallest() == 22 + 3)

settings.nodeIcons = false
setHook("nodeIcons")
check("turning it off stops the scan", rawget(events, "OnUpdate") == nil)
check("and every event", next(events.events) == nil)
check("and hides every icon", #Shown() == 0)
tooltip.added = {}
tooltipHook(tooltip, { lines = { { leftText = "Tin Vein" } } })
check("and the tooltip line", #tooltip.added == 0)

locale = "deDE"
settings.nodeIcons = true
local built = #frames
Load({ "NaowhForever_Professions/NodeScan.lua", "NaowhForever_Professions/UI/NodeIcons.lua" }, env)
boot.OnEvent(boot, "PLAYER_LOGIN")
check("a German client cannot read the English node names", ns.Professions.NodeScan.Usable() == false)
check("so even switched on it builds and registers nothing", #frames == built + 1)
locale = "enGB"
check("a British client reads them", ns.Professions.NodeScan.Usable() == true)

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"); f:close()
    return s
end

local nodes = ns.Professions.GatherNodes
for name, node in pairs(nodes) do
    check(name .. " is a herb or vein", node[1] == "herb" or node[1] == "ore")
    check(name .. " needs a skill", type(node[2]) == "number" and node[2] >= 1)
    check(name .. " has an item or none", node[3] == nil or type(node[3]) == "number")
end
local glimmer = Read("NaowhForever_QoL/Glimmer/Data/Nodes.lua")
local listed = 0
for kind, need, name in glimmer:gmatch('{ "(%a+)", (%d+), "([^"]+)" }') do
    if kind == "herb" or kind == "ore" then
        listed = listed + 1
        check(name .. " from Glimmer is in GatherNodes", nodes[name] ~= nil)
        check(name .. " needs the same skill as in Glimmer", nodes[name][2] == tonumber(need)
            and nodes[name][1] == kind)
    end
end
check("Glimmer's herbs and veins were read", listed > 50)

local features = Read("Core/Features.lua")
check("Minimap Node Icons is off by default", features:find("\n%s*nodeIcons = false,") ~= nil)

print(("test-node-icons: %d checks passed"):format(checks))

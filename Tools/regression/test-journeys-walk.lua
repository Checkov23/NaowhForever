-- Run with Lua 5.1 from the repository root: walking over the baked maps. Zephras Isle's real data is
-- decoded the way the client does (Base64, deflate, CBOR; Tools/regression/encoding_util.lua stands in for
-- C_EncodingUtil), a spot finds the polygon under it, a walk costs at least the straight line, the same
-- walk costs the same both ways, and the network's own places walk to each other through the table.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local env = setmetatable({}, { __index = _G })
env._G = env
local function Load(path)
    local chunk = assert(loadstring(Read(path), path))
    setfenv(chunk, env)
    return chunk()
end
local ns = { Journeys = {} }
env.NaowhForever = ns
env.C_EncodingUtil = dofile("Tools/regression/encoding_util.lua")()
env.Enum = { CompressionMethod = { Deflate = 0 } }
env.InCombatLockdown = function() return false end
env.C_AddOns = { IsAddOnLoaded = function() return true end, LoadAddOn = function() end }
local now, timers = 0, {}
env.GetTime = function() return now end
env.C_Timer = { After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end }
env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
local function RunTimers()
    local due = timers
    timers = {}
    for _, t in ipairs(due) do
        if t.at <= now then t.fn() else timers[#timers + 1] = t end
    end
end
env.debugprofilestop = function() return 0 end

Load("NaowhForever_Journeys/Constants.lua")
Load("NaowhForever_Journeys/Data/Network.lua")
Load("NaowhForever_JourneysData/Data.lua")
for line in Read("NaowhForever_JourneysData/JourneysData.xml"):gmatch('file="Data\\(Map2991[^"]*)"') do
    Load("NaowhForever_JourneysData/Data/" .. line)
end
Load("NaowhForever_Journeys/Walk.lua")
local Walk = ns.Journeys.Walk

local ZEPHRAS = 2991
local A = { c = ZEPHRAS, x = 2992.9, y = 1637.2, z = 780.4 }
local B = { c = ZEPHRAS, x = 2827.3, y = 957.1, z = 766.0 }

local tx, ty = Walk.TileOf(A.x, A.y)
local tile = Walk.Tile(ZEPHRAS, tx, ty)
Check(tile and #tile.polys > 0, "the first spot's tile decodes")
local shared = 0
for p = 1, #tile.polys do
    for k = 1, #tile.polys[p] do
        local q = tile.nbr[p][k]
        if q then
            shared = shared + 1
            local back = false
            for j = 1, #tile.polys[q] do if tile.nbr[q][j] == p then back = true end end
            Check(back, "a neighbour knows it back")
        end
    end
end
Check(shared > #tile.polys, "polygons find their neighbours by shared edges: " .. shared)

local a, b = Walk.From(A), Walk.From(B)
Check(a and b, "both spots stand on walking ground")
local scratch = Walk.Scratch()
local reused = Walk.From(A, scratch)
Check(Walk.Cost(ZEPHRAS, reused, b) == Walk.Cost(ZEPHRAS, a, b), "a walk searched into reused tables costs the same")
local refilled = Walk.From(A, scratch)
Check(refilled.near == reused.near and refilled.far == reused.far
    and Walk.Cost(ZEPHRAS, refilled, b) == Walk.Cost(ZEPHRAS, a, b),
    "the next search fills the same tables")
local ab, ba = Walk.Cost(ZEPHRAS, a, b), Walk.Cost(ZEPHRAS, b, a)
local straight = math.sqrt((A.x - B.x) ^ 2 + (A.y - B.y) ^ 2)
Check(ab and ab >= straight * 0.95, ("a walk is no shorter than the line: %s vs %.0f"):format(tostring(ab), straight))
Check(ab and ba and math.abs(ab - ba) < 0.05 * ab, ("the same both ways: %s and %s"):format(tostring(ab), tostring(ba)))

local path = Walk.Path(a, b)
Check(path and #path >= 4, "a walk has a path")
Check(path[1] == A.x and path[2] == A.y and path[#path - 1] == B.x and path[#path] == B.y, "from one spot to the other")
local length = 0
for i = 3, #path, 2 do length = length + math.sqrt((path[i] - path[i - 2]) ^ 2 + (path[i + 1] - path[i - 1]) ^ 2) end
Check(length >= straight * 0.99 and length <= ab * 1.05, ("its corners are pulled tight: %.0f yards, cost %.0f"):format(length, ab))

local placeCost = Walk.Cost(ZEPHRAS, a, "s8.2")
Check(placeCost ~= nil, "a spot walks to a network place: " .. tostring(placeCost))
Check(Walk.Cost(ZEPHRAS, "s8.2", "s8.2") == 0, "a place is no walk from itself")
Check(Walk.Cost(ZEPHRAS, a, "nowhere") == nil, "an unknown place: no answer, not a wall")

-- The Eastern Kingdoms: Stormwind Harbor's dock is the ship's spot in the water at the end of a long pier
-- the walking maps do not have. Its walk ends where the pier meets the land, never across the harbour,
-- and the open sea is no walk at all.
for line in Read("NaowhForever_JourneysData/JourneysData.xml"):gmatch('file="Data\\(Map0[^"]*)"') do
    Load("NaowhForever_JourneysData/Data/" .. line)
end
local EK = 0
local CITY = { c = EK, x = -8830, y = 650 }
local DOCK = { c = EK, x = -8654.5, y = 1344.4 }
local city, dock = Walk.From(CITY), Walk.From(DOCK)
Check(city and dock and dock.off, "the dock walks from the land its pier joins")
local harbour = Walk.Path(city, dock)
Check(harbour and harbour[#harbour - 1] == DOCK.x and harbour[#harbour] == DOCK.y, "the walk there is drawn, out to the dock")
local measured, baked = Walk.Cost(EK, city, dock), Walk.Cost(EK, city, "s5.2")
Check(measured and baked and math.abs(measured - baked) < 50, ("and costs what the baked table says: %s and %s"):format(
    tostring(measured), tostring(baked)))
local onPier = Walk.From({ c = EK, x = (DOCK.x + dock.x) / 2, y = (DOCK.y + dock.y) / 2 })
Check(onPier and onPier.poly == dock.poly and onPier.tx == dock.tx, "halfway along the pier walks from its root too")
Check(Walk.From({ c = EK, x = -10500, y = 2600 }) == false, "the open sea is off the walking maps: no walk, not a straight line")

-- Goldshire to Eastvale crosses tile sides through the middles of their runs; the traced corners are cut
-- where a straight line stays on the walking map, so the walk comes out close to the line.
local GOLDSHIRE, EASTVALE = { c = EK, x = -9460, y = 60 }, { c = EK, x = -9450, y = -1380 }
local across = Walk.Path(Walk.From(GOLDSHIRE), Walk.From(EASTVALE))
local walked = 0
for i = 3, #across, 2 do walked = walked + math.sqrt((across[i] - across[i - 2]) ^ 2 + (across[i + 1] - across[i - 1]) ^ 2) end
local line = math.sqrt((GOLDSHIRE.x - EASTVALE.x) ^ 2 + (GOLDSHIRE.y - EASTVALE.y) ^ 2)
Check(walked >= line and walked <= line * 1.17, ("a walk across tiles is cut straight: %.0f yards for %.0f"):format(walked, line))

-- Idle for a minute, the built tiles, crossings and walks are let go: a journey or estimate builds them again.
local before = Walk.Tile(EK, Walk.TileOf(CITY.x, CITY.y))
now = now + 30
RunTimers()
Check(Walk.Tile(EK, Walk.TileOf(CITY.x, CITY.y)) == before, "in use, the built tiles are kept")
Check(#timers == 1, "one release waits, however much is used")
now = now + 59
RunTimers()
Check(Walk.Tile(EK, Walk.TileOf(CITY.x, CITY.y)) == before, "used again within the minute, they stay")
now = now + 61
RunTimers()
RunTimers()
local again = Walk.Tile(EK, Walk.TileOf(CITY.x, CITY.y))
Check(again and again ~= before and #again.polys == #before.polys, "a minute idle, they are let go and built the same again")
local city2 = Walk.From(CITY)
Check(city2 and city2.poly == city.poly and Walk.Cost(EK, city2, dock) == measured, "and a walk after the release costs the same")

print(("journeys walk: %d checks passed"):format(checks))

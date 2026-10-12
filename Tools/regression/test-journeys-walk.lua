-- Run with Lua 5.1 from the repository root: walking over the baked maps. Zephras Isle's real data is
-- decoded the way the client does (Base64, deflate, CBOR; LibDeflate and the readers below stand in for
-- C_EncodingUtil), a spot finds the polygon under it, a walk costs at least the straight line, the same
-- walk costs the same both ways, and the network's own places walk to each other through the table.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_VALUE = {}
for i = 1, #B64 do B64_VALUE[B64:sub(i, i)] = i - 1 end

local function DecodeBase64(s)
    local out, bits, count = {}, 0, 0
    for i = 1, #s do
        local v = B64_VALUE[s:sub(i, i)]
        if v then
            bits, count = bits * 64 + v, count + 6
            if count >= 8 then
                count = count - 8
                local byte = math.floor(bits / 2 ^ count)
                out[#out + 1] = string.char(byte)
                bits = bits - byte * 2 ^ count
            end
        end
    end
    return table.concat(out)
end

local function Cbor(s)
    local at = 1
    local function Arg(info)
        if info < 24 then return info end
        local n = ({ [24] = 1, [25] = 2, [26] = 4 })[info]
        local v = 0
        for _ = 1, n do v = v * 256 + s:byte(at); at = at + 1 end
        return v
    end
    local function Item()
        local head = s:byte(at); at = at + 1
        local major, n = math.floor(head / 32), Arg(head % 32)
        if major == 0 then return n end
        if major == 1 then return -1 - n end
        if major == 3 then local text = s:sub(at, at + n - 1); at = at + n; return text end
        if major == 4 then local t = {}; for i = 1, n do t[i] = Item() end; return t end
        local t = {}
        for _ = 1, n do local k = Item(); t[k] = Item() end
        return t
    end
    return Item()
end

local env = setmetatable({}, { __index = _G })
env._G = env
local function Load(path)
    local chunk = assert(loadstring(Read(path), path))
    setfenv(chunk, env)
    return chunk()
end
env.LibStub = nil
env.strmatch = string.match
Load("Libs/LibStub/LibStub.lua")
Load("Libs/LibDeflate/LibDeflate.lua")
local LibDeflate = env.LibStub("LibDeflate")

local ns = { Journeys = {} }
env.NaowhForever = ns
env.C_EncodingUtil = {
    DecodeBase64 = DecodeBase64,
    DecompressString = function(s) return LibDeflate:DecompressDeflate(s) end,
    DeserializeCBOR = Cbor,
}
env.Enum = { CompressionMethod = { Deflate = 0 } }
env.InCombatLockdown = function() return false end
env.C_AddOns = { IsAddOnLoaded = function() return true end, LoadAddOn = function() end }
env.GetTime = function() return 0 end
env.debugprofilestop = function() return 0 end

Load("NaowhForever_Journeys/Constants.lua")
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

print(("journeys walk: %d checks passed"):format(checks))

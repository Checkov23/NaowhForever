-- Spots.lua: where herbs and veins grow (unpacked from Data/Spots.lua on first use), and the ones you have gathered (G.Spots).
local ns = _G.NaowhForever

local G = ns.Glimmer
local S = G.Settings
local C = G.C
local Target = G.Target
local SameMap = ns.Shared.Places.SameMap

local GATHERED = "glimmerGathered"
local KEY = "%d:%d:%d"
local GATHER_KINDS = { "ore", "herb" }

local Spots = {}
G.Spots = Spots

local wanted = {}

function Spots.Load()
    if ns.GlimmerSpots then return true end
    local packed = ns.GlimmerSpotsPacked
    if not packed or InCombatLockdown() then return false end
    local u = C_EncodingUtil
    local flat = u.DeserializeCBOR(u.DecompressString(u.DecodeBase64(packed), Enum.CompressionMethod.Deflate))
    if type(flat) ~= "table" then return false end
    local all = {}
    for i = 1, #flat, 2 do all[flat[i]] = flat[i + 1] end
    ns.GlimmerSpots, ns.GlimmerSpotsPacked = all, nil
    return true
end

local function Has(category)
    return Target.Skill(category) > 0
end

function Spots.Wanted(category)
    if not S.Get(category) then return false end
    if not S.Get("myProfessions") then return true end
    return Has(category)
end

function Spots.ForMap(mapID, out)
    wipe(out)
    local all = ns.GlimmerSpots and ns.GlimmerSpots[SameMap(mapID)]
    if not all then return 0 end
    wipe(wanted)
    for _, category in ipairs(GATHER_KINDS) do wanted[category] = Spots.Wanted(category) end
    local n = 0
    for i = 1, #all, 3 do
        local node = G.NODES[all[i]]
        if node and wanted[node[1]] then
            out[n + 1], out[n + 2], out[n + 3] = all[i], all[i + 1], all[i + 2]
            n = n + 3
        end
    end
    return n / 3
end

function Spots.XY(list, i)
    local at = i * 3
    return list[at - 1] / C.SPOT_SCALE, list[at] / C.SPOT_SCALE
end

function Spots.Tier(objectID)
    local node = G.NODES[objectID]
    if not node then return end
    return Target.Tier(Target.Skill(node[1]), node[2])
end

local function Snap(mapID, gathered, objectID, x, y)
    local bestX, bestY, best = x, y, C.SNAP * C.SNAP
    for _, e in pairs(gathered) do
        if e.id == objectID then
            local d = (e.x - x) ^ 2 + (e.y - y) ^ 2
            if d <= best then bestX, bestY, best = e.x, e.y, d end
        end
    end
    if best < C.SNAP * C.SNAP then return bestX, bestY end
    local all = ns.GlimmerSpots and ns.GlimmerSpots[SameMap(mapID)]
    for i = 1, all and #all or 0, 3 do
        if all[i] == objectID then
            local d = (all[i + 1] - x) ^ 2 + (all[i + 2] - y) ^ 2
            if d <= best then bestX, bestY, best = all[i + 1], all[i + 2], d end
        end
    end
    return bestX, bestY
end

function Spots.Gathered(mapID)
    local all = ns.AccountSettings()[GATHERED]
    return all and all[mapID]
end

function Spots.Record(objectID)
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end
    local px, py = pos:GetXY()
    local account = ns.AccountSettings()
    account[GATHERED] = account[GATHERED] or {}
    local map = account[GATHERED][mapID] or {}
    account[GATHERED][mapID] = map
    local x, y = Snap(mapID, map, objectID, math.floor(px * C.SPOT_SCALE + 0.5),
        math.floor(py * C.SPOT_SCALE + 0.5))
    local key = KEY:format(objectID, x, y)
    local entry = map[key]
    if not entry then
        local count, oldest, oldestKey = 0, nil, nil
        for k, e in pairs(map) do
            count = count + 1
            if not oldest or e.last < oldest then oldest, oldestKey = e.last, k end
        end
        if count >= C.MAX_GATHERED then map[oldestKey] = nil end
        entry = { id = objectID, x = x, y = y, count = 0 }
        map[key] = entry
    end
    entry.count, entry.last = entry.count + 1, time()
    return entry
end

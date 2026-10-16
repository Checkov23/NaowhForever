-- Places.lua: the world's zones by name, the map whose data a map reads, and showing a map on the world map (ns.Shared.Places).
local ns = _G.NaowhForever

local NONE = {}
local SAME = ns.Shared.SameMaps

local zones

local function SameMap(map)
    return SAME[map] or map
end

local function WorldOf(map)
    local info = map and C_Map.GetMapInfo(map)
    while info and info.parentMapID and info.parentMapID > 0 do
        info = C_Map.GetMapInfo(info.parentMapID)
    end
    return info
end

local function Load()
    zones = {}
    local world = WorldOf(SameMap(C_Map.GetBestMapForUnit("player")) or C_Map.GetFallbackWorldMapID())
    if not world then return end
    for _, zone in ipairs(C_Map.GetMapChildrenInfo(world.mapID, Enum.UIMapType.Zone, true) or NONE) do
        zones[zone.name] = zones[zone.name] or zone.mapID
    end
end

local Places = {}
ns.Shared.Places = Places

Places.SameMap = SameMap

function Places.Zone(name)
    if not zones then Load() end
    return zones[name]
end

function Places.ShowMap(map)
    if not map or InCombatLockdown() then return false end
    C_Map.OpenWorldMap(map)
    return true
end

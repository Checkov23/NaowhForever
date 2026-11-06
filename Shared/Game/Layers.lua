-- Layers.lua: the layer an NPC is on, read from its GUID (Shared.LayerOf).
local ns = _G.NaowhForever

local strsplit = strsplit
local issecretvalue = issecretvalue

local NPC_KINDS = { Creature = true, Vehicle = true }
local KEY = "%d-%d"

function ns.Shared.LayerOf(guid)
    if type(guid) ~= "string" or issecretvalue(guid) then return end
    local kind, _, server, _, zone = strsplit("-", guid)
    if not NPC_KINDS[kind] then return end
    server, zone = tonumber(server), tonumber(zone)
    if not (server and zone and server > 0 and zone > 0) then return end
    return KEY:format(server, zone), zone
end

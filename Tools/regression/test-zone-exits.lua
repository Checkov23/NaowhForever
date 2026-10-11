-- Run with Lua 5.1 from the repository root: the town map's zone exit arrows. Forever has no map
-- links of its own, so they come from data: every arrow is on its map, turned, and leads to
-- another map; the main roads are there both ways, Forever's Riverglades and Shen'dralas too; the town map draws them as clickable
-- links on the Clickable Zone Exits setting, turned to face out of the zone, longer than wide,
-- and with no waypoint on right click.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,}
local chunk = assert(loadstring(Read("NaowhForever_QoL/Interface/ZoneExits.lua")))
setfenv(chunk, { _G = { NaowhForever = ns } })
chunk()

local total = 0
for map, list in pairs(ns.ZoneExits) do
    for _, exit in ipairs(list) do
        Check(exit[1] >= 0 and exit[1] <= 100 and exit[2] >= 0 and exit[2] <= 100, "on the map: " .. map)
        Check(exit[3] >= -math.pi - 0.01 and exit[3] <= math.pi + 0.01, "turned: " .. map)
        Check(type(exit[4]) == "number" and exit[4] ~= map, "leads somewhere else: " .. map)
        total = total + 1
    end
end
Check(total >= 80, "the roads out of every zone (" .. total .. ")")

local function Leads(from, to)
    for _, exit in ipairs(ns.ZoneExits[from] or {}) do
        if exit[4] == to then return true end
    end
end
for _, pair in ipairs({ { 1413, 1411 }, { 1429, 1436 }, { 1429, 1431 }, { 1440, 1413 }, { 1420, 1421 },
    { 2548, 1433 }, { 2652, 1443 }, { 1442, 1412 } }) do
    Check(Leads(pair[1], pair[2]) and Leads(pair[2], pair[1]), ("both ways: %d and %d"):format(pair[1], pair[2]))
end
Check(Leads(1411, 1454) and Leads(1429, 1453), "city gates: Orgrimmar, Stormwind")

local map = Read("NaowhForever_QoL/Interface/TownMap.lua")
Check(map:find("ns.ZoneExits[mapID]", 1, true) and not map:find("GetMapLinksForMap(mapID)", 1, true),
    "the town map draws our own exits")
Check(map:find('if S.Get("townZoneLinks") then', 1, true), "on the Clickable Zone Exits setting")
Check(map:find("self.Icon:SetRotation(link.rotation or 0)", 1, true), "each arrow turned to face out")
Check(map:find("local EXIT_SHRINK = 0.6", 1, true) and map:find("size = size * EXIT_SHRINK", 1, true),
    "each arrow 40% smaller than a pin")
Check(map:find("length = size * EXIT_LENGTH", 1, true) and map:find("self.Icon:SetSize(size, length)", 1, true),
    "each arrow stretched along its length")
Check(not map:find("PlaceWaypoint", 1, true) and not map:find("exitX", 1, true), "right click: no waypoint")

print(("test-zone-exits: %d checks passed"):format(checks))

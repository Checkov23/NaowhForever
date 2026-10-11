-- Run with Lua 5.1 from the repository root: the town map's spirit healers. Forever's
-- GetGraveyardsForMap returns nothing while alive, so they come from data: every one is a pin
-- the town map can draw, every zone has them, and the town map reads the data, not the game.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,}
local chunk = assert(loadstring(Read("NaowhForever_QoL/Interface/TownSpiritHealers.lua")))
setfenv(chunk, { _G = { NaowhForever = ns } })
chunk()

local total = 0
for map, list in pairs(ns.TownSpiritHealers) do
    Check(type(map) == "number" and #list > 0, "a map with spirit healers: " .. tostring(map))
    for _, healer in ipairs(list) do
        Check(healer[1] >= 0 and healer[1] <= 100 and healer[2] >= 0 and healer[2] <= 100, "on the map: " .. map)
        Check(healer[3] == "spirit" and healer[7] == "AH", "a spirit healer pin row: " .. map)
        total = total + 1
    end
end
Check(total >= 90, "every spirit healer found (" .. total .. ")")
Check(#ns.TownSpiritHealers[1413] == 3, "the Barrens has its three")

local map = Read("NaowhForever_QoL/Interface/TownMap.lua")
Check(map:find("ns.TownSpiritHealers[mapID]", 1, true), "the town map draws them")
Check(not map:find("GetGraveyardsForMap", 1, true), "and no longer asks the game")

print(("test-town-spirit-healers: %d checks passed"):format(checks))

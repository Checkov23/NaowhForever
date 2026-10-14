-- Run with Lua 5.1 from the repository root: Glimmer's spots, packed into NaowhForever_QoL (Data/Spots.lua) and
-- unpacked by Spots.Load the way the client does (Tools/regression/encoding_util.lua stands in for
-- C_EncodingUtil). Every map and spot of the old NaowhForever_GlimmerData comes back, each spot is a known
-- herb or vein inside its map, the string is let go once unpacked, and nothing unpacks in combat.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local OLD_MAPS, OLD_SPOTS = 44, 25177
local FIRST_DUROTAR = { 1617, 378, 297 }
local SPOT_MAX = 1000
local PACKED_MAX = 200 * 1024

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n")
    f:close()
    return s
end

local combat = false
local ns = { Glimmer = { Settings = {}, C = {} } }
local env = setmetatable({ NaowhForever = ns, C_EncodingUtil = dofile("Tools/regression/encoding_util.lua")(),
    Enum = { CompressionMethod = { Deflate = 0 } }, InCombatLockdown = function() return combat end },
    { __index = _G })
env._G = env
for _, path in ipairs({ "NaowhForever_QoL/Glimmer/Data/Nodes.lua", "NaowhForever_QoL/Glimmer/Data/Spots.lua" }) do
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk()
end

local packed = ns.GlimmerSpotsPacked
check("the spots ship as one ASCII string in QoL", type(packed) == "string" and not packed:find("[\128-\255]")
    and #packed < PACKED_MAX)
check("NaowhForever_GlimmerData is gone", io.open("NaowhForever_GlimmerData/NaowhForever_GlimmerData.toc") == nil)
check("an old Glimmer Data folder is switched off at login",
    Read("Core/Core.lua"):find('RETIRED_ADDONS = { "NaowhForever_Glimmer", "NaowhForever_GlimmerData" }', 1, true))

local source = Read("NaowhForever_QoL/Glimmer/Spots.lua")
local Load = assert(source:match("\n(function Spots%.Load%(%).-\nend)\n"))
local chunk = assert(loadstring("local ns, Spots = NaowhForever, {}\n" .. Load .. "\nreturn Spots.Load"))
setfenv(chunk, env)
Load = chunk()

combat = true
check("in combat nothing unpacks", Load() == false and ns.GlimmerSpots == nil and ns.GlimmerSpotsPacked == packed)
combat = false
check("out of combat the spots unpack", Load() == true and type(ns.GlimmerSpots) == "table")
check("and the string is let go", ns.GlimmerSpotsPacked == nil)
check("a second call keeps what it has", Load() == true)

local maps, spots, known, inside = 0, 0, true, true
for _, list in pairs(ns.GlimmerSpots) do
    maps = maps + 1
    spots = spots + #list / 3
    for i = 1, #list, 3 do
        if not ns.Glimmer.NODES[list[i]] then known = false end
        local x, y = list[i + 1], list[i + 2]
        if x < 0 or x > SPOT_MAX or y < 0 or y > SPOT_MAX then inside = false end
    end
end
check(("every map and spot of the old data comes back: %d maps, %d spots"):format(maps, spots),
    maps == OLD_MAPS and spots == OLD_SPOTS)
check("every spot is a known herb or vein", known)
check("every spot is inside its map", inside)
local durotar = ns.GlimmerSpots[1411]
check("in the old order: Durotar's first spot is the same", durotar and durotar[1] == FIRST_DUROTAR[1]
    and durotar[2] == FIRST_DUROTAR[2] and durotar[3] == FIRST_DUROTAR[3])

print(("test-glimmer-spots: %d checks passed"):format(checks))

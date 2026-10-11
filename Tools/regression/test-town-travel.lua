-- Run with Lua 5.1 from the repository root: the town map's boats and zeppelins. Every dock is a
-- clickable pin that opens a zone with a dock leading back, the routes run both ways, a zeppelin
-- tower is one pin with both destinations, a ferry within one zone offers no click, the town map
-- draws them for your faction, and the setting starts off.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,}
local chunk = assert(loadstring(Read("NaowhForever_QoL/Interface/TownTravel.lua")))
setfenv(chunk, { _G = { NaowhForever = ns } })
chunk()

-- Each destination a pin offers: map -> { { pin, label, to }, ... }
local function Ends(pin)
    local ends = { { pin[4], pin[5] } }
    if pin[6] then ends[2] = { pin[6], pin[7] } end
    return ends
end

local total, towers = 0, 0
for map, list in pairs(ns.TownTravel) do
    for _, pin in ipairs(list) do
        Check(pin[1] >= 0 and pin[1] <= 100 and pin[2] >= 0 and pin[2] <= 100, "on the map: " .. map)
        Check(pin[3] == "A" or pin[3] == "H" or pin[3] == "AH", "a faction: " .. map)
        if pin[6] and pin[4]:find("^Zeppelin") then towers = towers + 1 end
        for _, finish in ipairs(Ends(pin)) do
            Check(finish[1]:find("^Boat to ") or finish[1]:find("^Zeppelin to "), "says where it goes: " .. finish[1])
            local back = false
            for _, other in ipairs(ns.TownTravel[finish[2]] or {}) do
                for _, otherEnd in ipairs(Ends(other)) do
                    if otherEnd[2] == map and other ~= pin then back = true end
                end
            end
            Check(back, "the zone it opens has another dock leading back: " .. finish[1])
            total = total + 1
        end
    end
end
Check(total == 28, "both ends of the eleven routes, and the three-dock Southshore boat (" .. total .. ")")
Check(towers == 3, "the three zeppelin towers are one pin each")
Check(ns.TownTravel[1413][1][4] == "Boat to Booty Bay" and ns.TownTravel[1413][1][5] == 1434,
    "Ratchet's boat opens Stranglethorn")
Check(#ns.TownTravel[1411] == 1 and ns.TownTravel[1411][1][7] == 1420, "Durotar's tower: Grom'gol, then Undercity")

local map = Read("NaowhForever_QoL/Interface/TownMap.lua")
Check(map:find("ns.TownTravel[mapID]", 1, true) and map:find('S.Get("townTravel")', 1, true),
    "the town map draws them on their own switch")
Check(map:find("linkedUiMapID = dock[5]", 1, true) and map:find("rightUiMapID = dock[7]", 1, true),
    "as clickable zone links, a tower's second destination on right click")
Check(Read("NaowhForever_QoL/Interface/TownMap.xml"):find('registerForClicks="LeftButtonUp, RightButtonUp"', 1, true),
    "and the pin takes right clicks: a Button gets only left clicks unless it asks")
Check(map:find("elseif link.linkedUiMapID ~= self:GetMap():GetMapID() then", 1, true),
    "no click hint on a pin that opens the map you are on")
Check(Read("Core/Settings.lua"):find("townTravel = false", 1, true), "Boats & Zeppelins starts off")

print(("test-town-travel: %d checks passed"):format(checks))

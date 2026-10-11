-- Route.lua: your nearest class trainer, and a waypoint route through it and your professions' trainers.
local ns = _G.NaowhForever

local Training = ns.Training

local PERCENT = 100
local SAME_CONTINENT, OWN_CAPITAL, SHARED_CAPITAL, ELSEWHERE = 0, 1, 2, 3
local NPC_X, NPC_Y, NPC_KIND, NPC_NAME, NPC_TITLE, NPC_CLASS, NPC_SIDE = 1, 2, 3, 4, 5, 6, 7
local PROFESSION_TITLES = {
    [171] = { "Alchem" }, [164] = { "Blacksmith" }, [333] = { "Enchant" }, [202] = { "Engineer" },
    [182] = { "Herbal" }, [165] = { "Leather" }, [186] = { "^Min" }, [393] = { "Skinn" },
    [197] = { "Tailor", "Clothier" }, [185] = { "Cooking" }, [129] = { "First Aid" }, [356] = { "Fishing" },
}
local CLASS_ICON = "Interface\\Icons\\ClassIcon_"
local ROUTE_TITLE = ns.L("Training run")
local TEXT_NO_TRAINER = ns.L("No trainer for your class is known for your faction.")

local function WorldPos(map, x, y)
    local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
    if ok and cont and pos then return cont, pos end
end

local function Side()
    return UnitFactionGroup("player") == "Horde" and "H" or "A"
end

local function Where()
    local map = C_Map.GetBestMapForUnit("player")
    local here = map and C_Map.GetPlayerMapPosition(map, "player")
    if here then return WorldPos(map, here:GetXY()) end
end

local function Rank(npc, npcMap, side, cont, pos)
    local c, p = WorldPos(npcMap, npc[NPC_X] / PERCENT, npc[NPC_Y] / PERCENT)
    if cont and c == cont then
        local x1, y1 = pos:GetXY()
        local x2, y2 = p:GetXY()
        return SAME_CONTINENT, (x1 - x2) ^ 2 + (y1 - y2) ^ 2
    end
    if ns.TownCapitals[npcMap] then return npc[NPC_SIDE] == side and OWN_CAPITAL or SHARED_CAPITAL, 0 end
    return ELSEWHERE, 0
end

local function Better(npc, tier, dist, best, bestTier, bestDist)
    if not best or tier < bestTier then return true end
    return tier == bestTier and (dist < bestDist or dist == bestDist and npc[NPC_NAME] < best[NPC_NAME])
end

function Training.NearestTrainer()
    local _, class = UnitClass("player")
    local side = Side()
    local cont, pos = Where()
    local best, bestMap, bestTier, bestDist
    for npcMap, npcs in pairs(ns.TownNPCs) do
        for _, npc in ipairs(npcs) do
            if npc[NPC_KIND] == "class" and npc[NPC_CLASS] == class and npc[NPC_SIDE]:find(side, 1, true) then
                local tier, dist = Rank(npc, npcMap, side, cont, pos)
                if Better(npc, tier, dist, best, bestTier, bestDist) then
                    best, bestMap, bestTier, bestDist = npc, npcMap, tier, dist
                end
            end
        end
    end
    return best, bestMap
end

local function Titled(title, patterns)
    for _, pattern in ipairs(patterns) do
        if title:find(pattern) then return true end
    end
    return false
end

local function Wanted()
    local wanted = {}
    for _, index in pairs({ GetProfessions() }) do
        local _, icon, _, _, _, _, line = GetProfessionInfo(index)
        if PROFESSION_TITLES[line] then wanted[#wanted + 1] = { PROFESSION_TITLES[line], icon } end
    end
    return wanted
end

local function Closest(map, wanted, side, x, y)
    local best, which, bestDist
    for i, want in ipairs(wanted) do
        for _, npc in ipairs(ns.TownNPCs[map]) do
            if npc[NPC_KIND] == "profession" and npc[NPC_SIDE]:find(side, 1, true) and Titled(npc[NPC_TITLE], want[1]) then
                local dist = (npc[NPC_X] - x) ^ 2 + (npc[NPC_Y] - y) ^ 2
                if not bestDist or dist < bestDist then best, which, bestDist = npc, i, dist end
            end
        end
    end
    return best, which
end

local function ProfessionStops(map, from, side)
    local wanted = Wanted()
    local stops, x, y = {}, from[NPC_X], from[NPC_Y]
    while #wanted > 0 do
        local best, which = Closest(map, wanted, side, x, y)
        if not best then break end
        stops[#stops + 1] = { best[NPC_NAME], map, best[NPC_X], best[NPC_Y], " (" .. best[NPC_TITLE] .. ")",
            wanted[which][2] }
        x, y = best[NPC_X], best[NPC_Y]
        table.remove(wanted, which)
    end
    return stops
end

function Training.WaypointToTrainer()
    local npc, map = Training.NearestTrainer()
    if not npc then
        ns.Print(TEXT_NO_TRAINER)
        return
    end
    local icon = CLASS_ICON .. npc[NPC_CLASS]:lower():gsub("^%l", string.upper)
    local stops = { { npc[NPC_NAME], map, npc[NPC_X], npc[NPC_Y], " (" .. npc[NPC_TITLE] .. ")", icon } }
    for _, stop in ipairs(ProfessionStops(map, npc, Side())) do stops[#stops + 1] = stop end
    ns.PlaceWaypointRoute(ROUTE_TITLE, stops)
end

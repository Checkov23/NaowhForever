-- QuestPositions.lua: puts each world position on the zone map the game client shows it on, for Tools/build/elsewhere_quests.py.
local _, T = ...

local CONTINENT_MAPS = { [0] = 1415, [1] = 1414 }
local MAX_DEPTH = 3
local PERCENT = 100

local function Resolve(c, x, y)
    local where = CreateVector2D(x, y)
    local map, pos = C_Map.GetMapPosFromWorldPos(c, where, CONTINENT_MAPS[c])
    if not map then return nil end
    for _ = 1, MAX_DEPTH do
        local child = C_Map.GetMapInfoAtPosition(map, pos.x, pos.y)
        if not child or child.mapID == map or child.mapType ~= Enum.UIMapType.Zone then break end
        local m, p = C_Map.GetMapPosFromWorldPos(c, where, child.mapID)
        if not m then break end
        map, pos = m, p
    end
    if map == CONTINENT_MAPS[c] then return nil end
    return string.format("%d,%.2f,%.2f", map, pos.x * PERCENT, pos.y * PERCENT)
end

SLASH_QUESTPOSITIONS1 = "/questpositions"
SlashCmdList.QUESTPOSITIONS = function()
    local results = {}
    for i, key in ipairs(T.positions) do
        local c, x, y = strsplit(",", key)
        results[i] = key .. "=" .. (Resolve(tonumber(c), tonumber(x), tonumber(y)) or "")
    end
    QuestPositionsResults = results
    print(string.format("QuestPositions: resolved %d positions, /reload to save them.", #results))
end

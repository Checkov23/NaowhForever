-- Model.lua: Zone Info's zone summaries, professions, gathering nodes, dungeon entrances and travel links.
local ns = _G.NaowhForever
local S = ns.QoLSettings
local T = ns.THEME
local Z = { skills = {}, nodes = {} }
ns.ZoneInfo = Z
local HERBALISM, MINING, PERCENT = 182, 186, 100
local MAX_PARENTS = 12
local EMPTY = {}
local seen = {}
local TEXT_RANGE, TEXT_LEVEL = ns.L("Level %d-%d"), ns.L("Level %d")
local TEXT_SKILL = ns.L("Your skill %d / Requires %d")
local TEXT_FISH = ns.L("Fishing %d minimum / %d reliable")
local TEXT_FISH_SKILL = ns.L("Your Fishing: %d")
local TEXT_NO_FISH = ns.L("Fishing not learned")
local TEXT_NO_FISH_ZONE = ns.L("Fishing requirements are not recorded for this zone.")
local TEXT_KNOWN = ns.L("Known locations do not indicate currently spawned nodes.")
local TEXT_DEFERRED = ns.L("Gathering details are available after combat.")
local TEXT_NO_NODES = ns.L("No gathering locations are recorded for this zone.")
local TEXT_NO_PROF = ns.L("No matching gathering profession learned.")
local TEXT_UNKNOWN_SKILL = ns.L("Profession information is unavailable.")
local TEXT_JOURNAL_OFF = ns.L("Enable the Dungeon Journal module to list this zone's dungeons.")
local TEXT_NO_DUNGEONS = ns.L("No dungeon entrances are recorded for this zone.")
local TEXT_READY, TEXT_HIGH, TEXT_LOW = ns.L("Good for your level"), ns.L("Above your level"), ns.L("Below your level")
local TEXT_REQUIRES = ns.L("Requires skill %d")
local TEXT_EXIT = ns.L("Road to %s")
local TEXT_DUNGEON_RANGE = ns.L("Level %s")
local TEXT_FLIGHT = ns.L("Flight Master")
local TEXT_NO_TRAVEL = ns.L("No travel connections are recorded for this zone.")
local TEXT_UNKNOWN_ZONE = ns.L("Unknown zone")
local TEXT_UNAVAILABLE = ns.L("Zone information is unavailable here.")
local TEXT_CONTENT = ns.L("Choose the details to show in Zone Info settings.")
local TEXT_BELOW_MINIMUM, TEXT_MAY_ESCAPE, TEXT_RELIABLE = ns.L("Below minimum"), ns.L("Fish may escape"), ns.L("Reliable fishing")
local GROUP_DUNGEONS, GROUP_TRAVEL, GROUP_FISHING, GROUP_GATHERING = "Dungeons & Raids", "Travel", "Fishing", "Herbs & Mining"
local TERRITORY = { friendly = ns.L("Friendly territory"), hostile = ns.L("Hostile territory"),
    contested = ns.L("Contested territory"), sanctuary = ns.L("Sanctuary"), combat = ns.L("Combat zone") }

function Z.Plain(value)
    return not (issecretvalue and issecretvalue(value))
        and not (type(value) == "table" and issecrettable and issecrettable(value))
end

function Z.MapInfo(mapID)
    if not Z.Plain(mapID) or type(mapID) ~= "number" or mapID <= 0 then return end
    local info = C_Map.GetMapInfo(mapID)
    if not (Z.Plain(info) and type(info) == "table" and Z.Plain(info.name)
        and Z.Plain(info.mapID) and Z.Plain(info.mapType) and Z.Plain(info.parentMapID)) then return end
    return info
end

function Z.ZoneMap(mapID)
    for _ = 1, MAX_PARENTS do
        local info = Z.MapInfo(mapID)
        if not info then return end
        if ns.ZoneLevels[mapID] or ns.FishingLevels[mapID] or info.mapType == Enum.UIMapType.Zone then return mapID end
        if not info.parentMapID or info.parentMapID <= 0 or info.parentMapID == mapID then return end
        mapID = info.parentMapID
    end
end

local function Skill(index)
    if not Z.Plain(index) then Z.professionsKnown = false; return end
    if type(index) ~= "number" then return end
    local _, _, rank, _, _, _, line, modifier = GetProfessionInfo(index)
    if not (Z.Plain(line) and Z.Plain(rank) and Z.Plain(modifier)) then Z.professionsKnown = false; return end
    if type(line) ~= "number" or type(rank) ~= "number" then Z.professionsKnown = false; return end
    Z.skills[line] = rank + (modifier or 0)
end

function Z.Character()
    if InCombatLockdown() then return end
    local level = UnitLevel("player")
    Z.level = Z.Plain(level) and type(level) == "number" and level > 0 and level or nil
    wipe(Z.skills)
    Z.professionsKnown = true
    local first, second, _, fish = GetProfessions()
    Skill(first)
    Skill(second)
    Skill(fish)
    Z.fishing = nil
    if Z.Plain(fish) and type(fish) == "number" then
        local _, _, rank, _, _, _, _, modifier = GetProfessionInfo(fish)
        if Z.Plain(rank) and Z.Plain(modifier) and type(rank) == "number" then Z.fishing = rank + (modifier or 0) end
    end
    local faction = UnitFactionGroup("player")
    Z.faction = Z.Plain(faction) and faction or nil
    local subzone = GetSubZoneText()
    Z.subzone = Z.Plain(subzone) and type(subzone) == "string" and subzone or nil
    local kind = C_PvP and C_PvP.GetZonePVPInfo and C_PvP.GetZonePVPInfo()
    Z.territory = Z.Plain(kind) and TERRITORY[kind] or nil
end

function Z.Levels(mapID)
    local range = ns.ZoneLevels[ns.Shared.Places.SameMap(mapID)]
    if not range then return "", nil, T.muted end
    local low, high = range[1], range[2]
    local text = low == high and TEXT_LEVEL:format(low) or TEXT_RANGE:format(low, high)
    if not Z.level then return text, nil, T.muted end
    local rating = Z.level < low and TEXT_HIGH or Z.level > high and TEXT_LOW or TEXT_READY
    local color = Z.level < low and ns.Shared.Style.TIME_OUT_RGB or Z.level > high and T.muted or ns.Shared.Style.HAVE_RGB
    return text, rating, color
end

local function Add(out, kind, title, detail, map, x, y, dungeon)
    out.count = out.count + 1
    local row = out.rows[out.count]
    if not row then row = {}; out.rows[out.count] = row end
    wipe(row)
    row.kind, row.title, row.detail = kind, title, detail
    row.map, row.x, row.y, row.dungeon = map, x, y, dungeon
    return row
end

local function Dungeons(out, mapID)
    Add(out, "section", GROUP_DUNGEONS)
    local J = ns.Journal
    if not (J and J.Settings and J.Settings.Get("enabled") and J.Dungeons) then Add(out, "note", TEXT_JOURNAL_OFF); return end
    local count = 0
    for _, dungeon in ipairs(J.Dungeons()) do
        local entrance = dungeon.entrance
        if entrance and ns.Shared.Places.SameMap(entrance.map) == ns.Shared.Places.SameMap(mapID) and not dungeon.closed then
            count = count + 1
            local levels = J.LevelRange and J.LevelRange(dungeon)
            Add(out, "entry", ns.L(dungeon.name), levels and TEXT_DUNGEON_RANGE:format(levels) or nil,
                entrance.map, entrance.x, entrance.y, dungeon)
        end
    end
    if count == 0 then Add(out, "note", TEXT_NO_DUNGEONS) end
end

local function Allowed(side)
    return not side or side == "AH" or Z.faction and side:find(Z.faction:sub(1, 1), 1, true) ~= nil
end

local function Travel(out, mapID)
    local count = out.count
    local source = ns.Shared.Places.SameMap(mapID)
    Add(out, "section", GROUP_TRAVEL)
    for _, npc in ipairs(ns.TownNPCs and ns.TownNPCs[source] or EMPTY) do
        if npc[3] == "flight" and Allowed(npc[7]) then
            Add(out, "entry", ns.L(npc[4]), TEXT_FLIGHT, mapID, npc[1], npc[2])
        end
    end
    for _, stop in ipairs(ns.TownTravel and ns.TownTravel[source] or EMPTY) do
        if Allowed(stop[3]) then
            for i = 4, #stop, 2 do Add(out, "entry", ns.L(stop[i]), nil, mapID, stop[1], stop[2]) end
        end
    end
    for _, exit in ipairs(ns.ZoneExits and ns.ZoneExits[source] or EMPTY) do
        local info = Z.MapInfo(exit[4])
        if info then Add(out, "entry", TEXT_EXIT:format(info.name), nil, mapID, exit[1], exit[2]) end
    end
    if out.count == count + 1 then Add(out, "note", TEXT_NO_TRAVEL) end
end

local function BySkill(a, b)
    if a.need ~= b.need then return a.need < b.need end
    return a.name < b.name
end

local function Nodes(mapID)
    if Z.nodes[mapID] then return Z.nodes[mapID] end
    local G = ns.Glimmer
    if not (G and G.Spots and G.Spots.Load()) then return end
    local same = ns.Shared.Places.SameMap(mapID)
    local spots = ns.GlimmerSpots and ns.GlimmerSpots[same]
    local list = {}
    wipe(seen)
    for i = 1, spots and #spots or 0, 3 do
        local node = G.NODES[spots[i]]
        local key = node and node[1] .. ":" .. node[3]
        if node and (node[1] == "herb" or node[1] == "ore") and not seen[key] then
            seen[key] = true
            list[#list + 1] = { kind = node[1], need = node[2], name = node[3],
                x = spots[i + 1] / G.C.SPOT_SCALE * PERCENT, y = spots[i + 2] / G.C.SPOT_SCALE * PERCENT }
        end
    end
    table.sort(list, BySkill)
    Z.nodes[mapID] = list
    return list
end

local function Gathering(out, mapID)
    Add(out, "section", GROUP_GATHERING)
    if S.Get("zoneInfoOnlyProfessions") and not Z.professionsKnown then Add(out, "note", TEXT_UNKNOWN_SKILL); return end
    local list = Nodes(mapID)
    if not list then Add(out, "note", TEXT_DEFERRED); return end
    local count = 0
    Add(out, "note", TEXT_KNOWN)
    for _, node in ipairs(list) do
        local skill = Z.skills[node.kind == "herb" and HERBALISM or MINING]
        if skill or not S.Get("zoneInfoOnlyProfessions") then
            count = count + 1
            local row = Add(out, "entry", ns.L(node.name), skill and TEXT_SKILL:format(skill, node.need)
                or TEXT_REQUIRES:format(node.need), mapID, node.x, node.y)
            row.nodeKind = node.kind
            row.color = not skill and T.muted or skill >= node.need and ns.Shared.Style.HAVE_RGB or ns.Shared.Style.TIME_OUT_RGB
        end
    end
    if count == 0 then Add(out, "note", #list == 0 and TEXT_NO_NODES or TEXT_NO_PROF) end
end

function Z.Fill(out, mapID, gathering)
    out.count, out.map = 0, mapID
    local info = Z.MapInfo(mapID)
    out.name = info and info.name or TEXT_UNKNOWN_ZONE
    out.range, out.rating, out.color = Z.Levels(mapID)
    out.territory = mapID == Z.current and Z.territory or nil
    if not info then Add(out, "note", TEXT_UNAVAILABLE); return end
    if gathering then Gathering(out, mapID); return end
    if S.Get("zoneInfoDungeons") then Dungeons(out, mapID) end
    if S.Get("zoneInfoFishing") then
        local range = ns.FishingLevels[ns.Shared.Places.SameMap(mapID)]
        Add(out, "section", GROUP_FISHING)
        if range then
            local row = Add(out, "entry", TEXT_FISH:format(range[1], range[2]), Z.fishing and TEXT_FISH_SKILL:format(Z.fishing)
                or not Z.professionsKnown and TEXT_UNKNOWN_SKILL or TEXT_NO_FISH)
            if Z.fishing then
                local state = Z.fishing < range[1] and TEXT_BELOW_MINIMUM or Z.fishing < range[2] and TEXT_MAY_ESCAPE or TEXT_RELIABLE
                row.detail = row.detail .. " / " .. state
                row.color = Z.fishing < range[1] and ns.Shared.Style.TIME_OUT_RGB or Z.fishing < range[2] and ns.Shared.Style.TIME_LOW_RGB or ns.Shared.Style.HAVE_RGB
            end
        else
            Add(out, "note", TEXT_NO_FISH_ZONE)
        end
    end
    if S.Get("zoneInfoTravel") then Travel(out, mapID) end
    if out.count == 0 then Add(out, "note", TEXT_CONTENT) end
end

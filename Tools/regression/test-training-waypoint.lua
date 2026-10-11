local DIR = arg[1] or "NaowhForever_Training"
local Load = dofile("Tools/regression/load_files.lua")

-- The module's Route.lua, loaded into env with ns.Training to fill.
local function LoadRoute(env)
    env.ns.Training = env.Training
    env.NaowhForever = env.ns
    env._G = env
    Load({ DIR .. "/Route.lua" }, setmetatable(env, { __index = _G }))
    return env.Training
end

-- uiMapID -> its continent, its corner in world units and its size.
local MAPS = {
    [1411] = { cont = 1, x = 0, y = 0, size = 1000 },      -- Durotar
    [1454] = { cont = 1, x = 200, y = -800, size = 200 },  -- Orgrimmar
    [1413] = { cont = 1, x = -1500, y = 0, size = 2000 },  -- The Barrens
    [1453] = { cont = 0, x = 0, y = 0, size = 300 },       -- Stormwind
    [1429] = { cont = 0, x = 400, y = 0, size = 1000 },    -- Elwynn
    [2521] = { cont = 2, x = 0, y = 0, size = 500 },       -- Zephras Isle
}
local NPCS = {
    [1411] = {
        { 54.2, 42.5, "class", "Tarshaw Jaggedscar", "Warrior Trainer", "WARRIOR", "H" },
        { 52.0, 43.7, "class", "Kaplak", "Rogue Trainer", "ROGUE", "H" },
        { 50.0, 50.0, "vendor", "Duokna", "General Goods", nil, "H" },
    },
    [1454] = {
        { 80.0, 30.0, "class", "Grezz Ragefist", "Warrior Trainer", "WARRIOR", "H" },
        { 43.9, 54.6, "class", "Shenthul", "Rogue Trainer", "ROGUE", "H" },
    },
    [2521] = { { 40.0, 40.0, "class", "Akeri Duskblade", "Rogue Trainer", "ROGUE", "AH" } },
    [1413] = { { 10.0, 10.0, "class", "Far Off", "Warrior Trainer", "WARRIOR", "H" } },
    [1453] = { { 78.0, 45.0, "class", "Wu Shen", "Warrior Trainer", "WARRIOR", "A" } },
    [1429] = { { 41.0, 65.0, "class", "Lyria Du Lac", "Warrior Trainer", "WARRIOR", "A" } },
}

local function Vector(x, y) return { GetXY = function() return x, y end } end

-- The nearest trainer for a character of `class` and `faction` standing at `at` ({ map, x, y }
-- as fractions), or nowhere with a position when `at` is nil.
local function Nearest(class, faction, at)
    local env = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, TownNPCs = NPCS, TownCapitals = { [1453] = true, [1454] = true, [2521] = true } },
        Training = {},
        UnitClass = function() return "", class end,
        UnitFactionGroup = function() return faction end,
        CreateVector2D = Vector,
        C_Map = {
            GetBestMapForUnit = function() return at and at[1] or 1411 end,
            GetPlayerMapPosition = function() return at and Vector(at[2], at[3]) end,
            GetWorldPosFromMapPos = function(map, pos)
                local m = MAPS[map]
                local x, y = pos:GetXY()
                return m.cont, Vector(m.x + x * m.size, m.y + y * m.size)
            end,
        },
    }
    local npc, map = LoadRoute(env).NearestTrainer()
    return npc and (npc[4] .. "@" .. map) or "none"
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("the nearest trainer of your class on your continent", function()
    local got = Nearest("WARRIOR", "Horde", { 1411, 0.5, 0.45 })
    assert(got == "Tarshaw Jaggedscar@1411", got)
    got = Nearest("WARRIOR", "Horde", { 1454, 0.5, 0.5 })
    assert(got == "Grezz Ragefist@1454", got)
    got = Nearest("ROGUE", "Horde", { 1411, 0.5, 0.45 })
    assert(got == "Kaplak@1411", got)
end)
Case("other factions' trainers and other services are left out", function()
    local got = Nearest("WARRIOR", "Alliance", { 1429, 0.4, 0.6 })
    assert(got == "Lyria Du Lac@1429", got)
    got = Nearest("PALADIN", "Alliance", { 1429, 0.4, 0.6 })
    assert(got == "none", got)
end)
Case("with none on your continent, or no position, a capital's trainer", function()
    local got = Nearest("WARRIOR", "Alliance", { 1411, 0.5, 0.5 })
    assert(got == "Wu Shen@1453", got)
    got = Nearest("WARRIOR", "Horde", nil)
    assert(got == "Grezz Ragefist@1454", got)
end)
Case("your faction's capital before one both factions share", function()
    local got = Nearest("ROGUE", "Horde", nil)
    assert(got == "Shenthul@1454", got)
    got = Nearest("ROGUE", "Alliance", nil)
    assert(got == "Akeri Duskblade@2521", got)
end)

-- The route Training.WaypointToTrainer places: your class trainer, then your professions'
-- trainers in that town, each the nearest to the stop before it.
local function Route(class, faction, professions, at)
    local placed
    local lines = {}
    for i, p in ipairs(professions) do lines[i] = p end
    local env = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
            TownNPCs = NPCS, TownCapitals = { [1453] = true, [1454] = true, [2521] = true },
            Print = function() end,
            PlaceWaypointRoute = function(title, stops) placed = { title = title, stops = stops } end,
        },
        Training = {},
        UnitClass = function() return "", class end,
        UnitFactionGroup = function() return faction end,
        CreateVector2D = Vector,
        GetProfessions = function() return 1, 2, nil, 4 end,
        GetProfessionInfo = function(index)
            local p = lines[index]
            if p then return p.name, p.icon, 1, 75, 0, 0, p.line end
        end,
        C_Map = {
            GetBestMapForUnit = function() return at[1] end,
            GetPlayerMapPosition = function() return Vector(at[2], at[3]) end,
            GetWorldPosFromMapPos = function(map, pos)
                local m = MAPS[map]
                local x, y = pos:GetXY()
                return m.cont, Vector(m.x + x * m.size, m.y + y * m.size)
            end,
        },
    }
    LoadRoute(env).WaypointToTrainer()
    return placed
end

NPCS[1454][#NPCS[1454] + 1] = { 30.0, 30.0, "profession", "Far Herbalist", "Herbalism Trainer", nil, "H" }
NPCS[1454][#NPCS[1454] + 1] = { 79.0, 31.0, "profession", "Near Herbalist", "Herbalist", nil, "H" }
NPCS[1454][#NPCS[1454] + 1] = { 70.0, 40.0, "profession", "Ore", "Miner", nil, "H" }
NPCS[1454][#NPCS[1454] + 1] = { 78.0, 31.0, "profession", "Ally Miner", "Mining Trainer", nil, "A" }
NPCS[1454][#NPCS[1454] + 1] = { 79.5, 30.5, "profession", "Swords", "Weapon Master", nil, "H" }

Case("your professions' trainers in that town follow the class trainer, nearest first", function()
    local route = Route("WARRIOR", "Horde", {
        { name = "Mining", icon = 136248, line = 186 },
        { name = "Herbalism", icon = 136246, line = 182 },
        [4] = { name = "Fishing", icon = 136245, line = 356 },
    }, { 1454, 0.5, 0.5 })
    assert(route.title == "Training run", route.title)
    local s = route.stops
    assert(#s == 3, #s)
    assert(s[1][1] == "Grezz Ragefist" and s[1][2] == 1454 and s[1][5] == " (Warrior Trainer)"
        and s[1][6] == "Interface\\Icons\\ClassIcon_Warrior", s[1][6])
    assert(s[2][1] == "Near Herbalist" and s[2][6] == 136246, s[2][1])
    assert(s[3][1] == "Ore" and s[3][5] == " (Miner)" and s[3][6] == 136248, s[3][1])
end)
Case("no professions, or none trained in that town: the class trainer alone", function()
    local route = Route("ROGUE", "Horde", {}, { 1454, 0.5, 0.5 })
    assert(#route.stops == 1 and route.stops[1][1] == "Shenthul", route.stops[1][1])
    route = Route("WARRIOR", "Horde", { { name = "Tailoring", icon = 1, line = 197 } }, { 1454, 0.5, 0.5 })
    assert(#route.stops == 1, #route.stops)
end)

print(("%d cases passed"):format(count))

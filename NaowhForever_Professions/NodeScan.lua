-- NodeScan.lua: the herbs and veins the minimap's tracking dots show, read from its tooltip over a grid of points, and the skill each needs (P.NodeScan).
local ns = _G.NaowhForever

local GetMinimapMouseover = C_TooltipInfo.GetMinimapMouseover
local GetProfessions, GetProfessionInfo = GetProfessions, GetProfessionInfo
local floor = math.floor

local P = ns.Professions
local NODES = P.GatherNodes

local GRID_STEP = 7
local PROBES_PER_FRAME = 60
local FINE_REACH = 10
local ROW = 1000
local NEIGHBOURS = { -ROW - 1, -ROW, -ROW + 1, -1, 1, ROW - 1, ROW, ROW + 1 }
local PROFESSION_LINE = { herb = 182, ore = 186 }
local KIND, NEED, ITEM = 1, 2, 3
local CODES = { "|c%x%x%x%x%x%x%x%x", "|r", "|T.-|t", "|A.-|a" }
local LINE_PART = "[^\n]+"
local TRIM = "^%s*(.-)%s*$"
local CACHE_MAX = 200
local ENGLISH_CLIENTS = { enUS = true, enGB = true }

local grid = {}
local gridWidth, gridSquare
local nextPoint = 1
local hits = {}
local seen, stack = {}, {}
local places = {}
local placeCount = 0
local skills = {}
local cache = {}
local cacheCount = 0

local function Plain(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Clean(text)
    for _, code in ipairs(CODES) do text = text:gsub(code, "") end
    return text:match(TRIM)
end

local function KnownIn(text)
    local list = cache[text]
    if list then return list end
    list = {}
    for part in text:gmatch(LINE_PART) do
        local name = Clean(part)
        if NODES[name] then list[#list + 1] = name end
    end
    if cacheCount >= CACHE_MAX then
        wipe(cache)
        cacheCount = 0
    end
    cache[text], cacheCount = list, cacheCount + 1
    return list
end

local function Record(point)
    local data = GetMinimapMouseover()
    if not (data and Plain(data)) then return end
    local lines = data.lines
    if not (lines and Plain(lines)) then return end
    for _, line in ipairs(lines) do
        local text = line.leftText
        if text and Plain(text) then
            for _, name in ipairs(KnownIn(text)) do
                local set = hits[name]
                if not set then
                    set = {}
                    hits[name] = set
                end
                set[point] = true
            end
        end
    end
end

local function Under(name)
    local data = GetMinimapMouseover()
    if not (data and Plain(data)) then return false end
    local lines = data.lines
    if not (lines and Plain(lines)) then return false end
    for _, line in ipairs(lines) do
        local text = line.leftText
        if text and Plain(text) then
            for _, known in ipairs(KnownIn(text)) do
                if known == name then return true end
            end
        end
    end
    return false
end

local function Span(left, bottom, scale, name, x, y, dx, dy)
    local low, high
    for step = -FINE_REACH, FINE_REACH do
        Minimap:UpdateMouseoverAtPoint((left + x + step * dx) * scale, (bottom + y + step * dy) * scale)
        if Under(name) then
            low = low or step
            high = step
        end
    end
    if not low then return 0 end
    return (low + high) / 2
end

local function BuildGrid(width, square)
    wipe(grid)
    local cells = floor(width / GRID_STEP)
    local half = width / 2
    for x = 0, cells do
        for y = 0, cells do
            local dx, dy = x * GRID_STEP - half, y * GRID_STEP - half
            if square or dx * dx + dy * dy <= half * half then grid[#grid + 1] = x * ROW + y end
        end
    end
    gridWidth, gridSquare = width, square
end

local function NewPlace(name)
    placeCount = placeCount + 1
    local place = places[placeCount]
    if not place then
        place = {}
        places[placeCount] = place
    end
    place.name = name
    return place
end

local function Middle(set, start)
    wipe(stack)
    stack[1] = start
    seen[start] = true
    local count, sumX, sumY = 0, 0, 0
    while #stack > 0 do
        local point = stack[#stack]
        stack[#stack] = nil
        count = count + 1
        sumX = sumX + floor(point / ROW)
        sumY = sumY + point % ROW
        for _, offset in ipairs(NEIGHBOURS) do
            local near = point + offset
            if set[near] and not seen[near] then
                seen[near] = true
                stack[#stack + 1] = near
            end
        end
    end
    return sumX / count * GRID_STEP, sumY / count * GRID_STEP
end

local function AddSkill(index)
    if not index then return end
    local _, _, rank, _, _, _, line, modifier = GetProfessionInfo(index)
    for kind, id in pairs(PROFESSION_LINE) do
        if line == id then skills[kind] = (rank or 0) + (modifier or 0) end
    end
end

local Scan = {}
P.NodeScan = Scan

function Scan.Usable()
    return ENGLISH_CLIENTS[GetLocale()] == true
end

function Scan.Known(text)
    return KnownIn(text)
end

function Scan.Node(name)
    return NODES[name]
end

function Scan.Kind(node)
    return node[KIND]
end

function Scan.Need(node)
    return node[NEED]
end

function Scan.Item(node)
    return node[ITEM]
end

function Scan.ReadSkills()
    wipe(skills)
    local first, second = GetProfessions()
    AddSkill(first)
    AddSkill(second)
end

function Scan.Skill(kind)
    return skills[kind] or 0
end

function Scan.TooHard(node)
    return Scan.Skill(node[KIND]) < node[NEED]
end

function Scan.Start(width, square)
    if width ~= gridWidth or square ~= gridSquare then BuildGrid(width, square) end
    for _, set in pairs(hits) do wipe(set) end
    nextPoint = 1
end

function Scan.Step(left, bottom, scale)
    local last = math.min(nextPoint + PROBES_PER_FRAME - 1, #grid)
    Minimap:SetUsingSoftCursor(true)
    for i = nextPoint, last do
        local point = grid[i]
        local x, y = floor(point / ROW) * GRID_STEP, point % ROW * GRID_STEP
        Minimap:UpdateMouseoverAtPoint((left + x) * scale, (bottom + y) * scale)
        Record(point)
    end
    Minimap:SetUsingSoftCursor(false)
    nextPoint = last + 1
    return nextPoint > #grid
end

function Scan.Refine(left, bottom, scale, name, x, y)
    Minimap:SetUsingSoftCursor(true)
    x = x + Span(left, bottom, scale, name, x, y, 1, 0)
    y = y + Span(left, bottom, scale, name, x, y, 0, 1)
    Minimap:SetUsingSoftCursor(false)
    return x, y
end

function Scan.Places()
    placeCount = 0
    for name, set in pairs(hits) do
        wipe(seen)
        for point in pairs(set) do
            if not seen[point] then
                local place = NewPlace(name)
                place.x, place.y = Middle(set, point)
            end
        end
    end
    return places, placeCount
end

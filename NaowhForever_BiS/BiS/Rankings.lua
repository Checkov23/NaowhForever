-- Rankings.lua: rankings, dungeon drops your class can use, sources and Run Next (B.Rankings).
local ns = _G.NaowhForever

local B = ns.BiS
local C = B.C
local Items = ns.Shared.Items
local Fits, Wearing = Items.Fits, Items.Wearing

local OFF_HAND = C.OFF_HAND
local FACT_CLASS, FACT_ITEM_LEVEL, FACT_REQUIRED, FACT_QUALITY = 1, 3, 4, 5
local INFO_MIN_LEVEL = 5
local WEAPON, ARMOR = 2, 4
local MIN_QUALITY = 2
local NEAR_LEVELS = 10
local TRASH_CHANCE = -1
local RUN_NEXT_MAX = 3
local SOURCE_SEP = " \194\183 "
local PLACE_PATTERN = "^(.*)" .. SOURCE_SEP .. "(.+)$"
local TEXT_TRASH = ns.L("Trash drop")
local DUAL_WIELD = { WARRIOR = true, ROGUE = true, HUNTER = true }
local NOT_A_PLACE = { Crafted = true, Quest = true, ["Quest (Horde)"] = true, ["Quest (Alliance)"] = true,
    ["Quest Reward"] = true, ["World drop"] = true, Reputation = true }
local VIA_DETAIL = { quest = true, recipe = true }
local EMPTY = {}

local _, playerClass = UnitClass("player")

local classSpecs
local rankPos = {}
local drops, dropIDs
local dropDungeon = {}
local places, details = {}, {}
local nextPlaces, byName, placePool = {}, {}, {}

local function ByRank(a, b)
    local pa, pb = rankPos[a] or math.huge, rankPos[b] or math.huge
    if pa ~= pb then return pa < pb end
    return a < b
end

local function Facts(itemID)
    return ns.Shared.ItemFacts[itemID]
end

local function ByLevel(a, b)
    local fa, fb = Facts(a), Facts(b)
    if fa[FACT_REQUIRED] ~= fb[FACT_REQUIRED] then return fa[FACT_REQUIRED] > fb[FACT_REQUIRED] end
    if fa[FACT_ITEM_LEVEL] ~= fb[FACT_ITEM_LEVEL] then return fa[FACT_ITEM_LEVEL] > fb[FACT_ITEM_LEVEL] end
    return a < b
end

local function ByGain(a, b)
    if a.gain ~= b.gain then return a.gain > b.gain end
    if a.bis ~= b.bis then return a.bis > b.bis end
    return a.name < b.name
end

local function AddBossLoot(dungeon, boss, best, notYet)
    local who = (boss.trash and TEXT_TRASH or boss.name) .. SOURCE_SEP .. dungeon.name
    for i, id in ipairs(boss.loot or EMPTY) do
        local chance = boss.trash and TRASH_CHANCE or boss.chance and boss.chance[i] or 0
        if not notYet[id] then
            if not drops[id] then dropIDs[#dropIDs + 1] = id end
            if not drops[id] or chance > best[id] then
                drops[id], best[id], dropDungeon[id] = who, chance, dungeon
            end
        end
    end
end

local function Drops()
    if drops then return drops end
    local J = ns.Journal
    if not (J and J.Dungeons) then return EMPTY end
    drops, dropIDs = {}, {}
    local best, notYet = {}, J.NotYet or EMPTY
    for _, dungeon in ipairs(J.Dungeons()) do
        for _, wing in ipairs(dungeon.wings) do
            for _, boss in ipairs(wing.bosses) do AddBossLoot(dungeon, boss, best, notYet) end
        end
    end
    return drops
end

local function IsGear(item)
    local class = item[FACT_CLASS]
    return (class == WEAPON or class == ARMOR) and item[FACT_QUALITY] >= MIN_QUALITY
end

local function Wieldable(item, slot)
    return not (slot == OFF_HAND and item[FACT_CLASS] == WEAPON and not DUAL_WIELD[playerClass])
end

local function Near(item, level, near)
    return not near or math.abs(item[FACT_REQUIRED] - level) <= NEAR_LEVELS
end

local function Owned(slot, id)
    return Wearing(slot, id) or C_Item.GetItemCount(id, true) > 0
end

local function Counted(slot, idle)
    return not (slot == OFF_HAND and idle)
end

local function Place(source)
    local place = places[source]
    if not place then
        local detail
        detail, place = source:match(PLACE_PATTERN)
        place = place or source
        places[source], details[source] = place, detail or false
    end
    return place, details[source] or nil
end

local function PlaceOf(id)
    local source = id and ns.BiSSource(id)
    if not source then return nil end
    local name, detail = Place(source)
    if not NOT_A_PLACE[name] then return name, nil end
    local kind, target = B.Sources.Of(id)
    if kind == "faction" then return target.name, kind end
    if VIA_DETAIL[kind] and detail then return detail, kind end
    return nil
end

local function NewPlace(found, name, kind, id)
    local place = placePool[#found + 1] or { slots = {} }
    placePool[#found + 1] = place
    place.name, place.bis, place.gain, place.mask, place.key = name, 0, 0, 0, 0
    place.kind, place.via = kind, kind and id or nil
    wipe(place.slots)
    byName[name] = place
    found[#found + 1] = place
    return place
end

local function AddToPlace(place, slot, id, gains)
    place.bis = place.bis + 1
    place.gain = place.gain + (gains and gains[slot] or 0)
    place.slots[place.bis] = slot
    place.mask = place.mask + 2 ^ slot
    place.key = place.key + id * slot
end

local R = {}
B.Rankings = R
R.SOURCE_SEP = SOURCE_SEP
R.Usable = Items.ClassCanUse

function R.ClassSpecs()
    if not classSpecs then
        classSpecs = {}
        for _, spec in ipairs(ns.BiSData.specs) do
            if spec.class == playerClass then classSpecs[#classSpecs + 1] = spec end
        end
    end
    return classSpecs
end

function R.Ranking(key, slot)
    for _, spec in ipairs(ns.BiSData.specs) do
        if spec.key == key then return spec.slots[slot] end
    end
    local spec = R.ClassSpecs()[1]
    return spec and spec.slots[slot]
end

function R.Ranked(set, order)
    wipe(rankPos)
    order = order or EMPTY
    for i = #order, 1, -1 do rankPos[order[i]] = i end
    local ids = {}
    for id in pairs(set) do ids[#ids + 1] = id end
    table.sort(ids, ByRank)
    return ids
end

function R.Candidates(slot, spec)
    local ids = {}
    for _, id in ipairs(spec and spec.slots[slot] or EMPTY) do
        if C_Item.GetItemInfoInstant(id) then ids[#ids + 1] = id end
    end
    return ids
end

function R.DungeonDrops(slot, ranked, near)
    Drops()
    local level = UnitLevel("player")
    local skip = {}
    for _, id in ipairs(ranked) do skip[id] = true end
    local ids = {}
    for _, id in ipairs(dropIDs or EMPTY) do
        local item = Facts(id)
        if item and not skip[id] and IsGear(item) and R.Usable(playerClass, item) and Fits(id, slot)
            and Wieldable(item, slot) and Near(item, level, near) then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids, ByLevel)
    return ids
end

function ns.BiSSource(itemID)
    return Drops()[itemID] or ns.BiSData.sources[itemID]
end

function R.DropDungeon(itemID)
    Drops()
    return dropDungeon[itemID]
end

function R.ReqLevel(itemID)
    local item = Facts(itemID)
    return item and item[FACT_REQUIRED] or select(INFO_MIN_LEVEL, C_Item.GetItemInfo(itemID))
end

function R.ItemLevel(itemID)
    local item = Facts(itemID)
    return item and item[FACT_ITEM_LEVEL]
end

R.Place = Place

function R.Had(list)
    local have, total = 0, 0
    local idle = B.OffHandIdle(list)
    for slot in pairs(Items.SLOT_NAME) do
        local id = list.slots[slot]
        if id and Counted(slot, idle) then
            total = total + 1
            if Items.Owned(id) then have = have + 1 end
        end
    end
    return have, total
end

function R.RunNext(list, gains)
    local found = wipe(nextPlaces)
    wipe(byName)
    local idle = B.OffHandIdle(list)
    for _, gear in ipairs(Items.GEAR_SLOTS) do
        local slot = gear[1]
        local id = Counted(slot, idle) and list.slots[slot]
        local name, kind = PlaceOf(id)
        if name and not Owned(slot, id) then
            AddToPlace(byName[name] or NewPlace(found, name, kind, id), slot, id, gains)
        end
    end
    table.sort(found, ByGain)
    for i = #found, RUN_NEXT_MAX + 1, -1 do found[i] = nil end
    return found
end

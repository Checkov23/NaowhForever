-- Rares.lua: the rare rules: which rares are yours, their zones, spots and drops, and your kills (Completo.Rares).
local ns = _G.NaowhForever

local T = ns.THEME
local Completo = ns.Completo
local C = Completo.C
local St = ns.Shared.Style
local SameMap = ns.Shared.Places.SameMap
local D = ns.CompletoRareData

local NAME, LOW, HIGH, ELITE, REACT_A, REACT_H, MAP, SPOTS, TRAIL = 1, 2, 3, 4, 5, 6, 7, 8, 9
local FRIENDLY = 1
local PERCENT = C.PERCENT
local TOOLTIP_ICON = 14
local ROUND_HALF = C.ROUND_HALF
local GOLD_RGB = { r = 1, g = 0.82, b = 0 }
local WHITE = { r = 1, g = 1, b = 1 }
local KILLS_STORE, DROPS_STORE = "completoRareKills", "completoRareDrops"
local TEXT_DROPS = ns.L("Drops")
local TEXT_GOT_IT = ns.L("(you got it)")
local TEXT_MORE = ns.L("And %d more")
local TEXT_UNKNOWN_LEVEL = "??"
local TEXT_KILLED = ns.L("Killed")
local TEXT_KILLED_TIMES = ns.L("Killed %d times")
local NONE = {}

local mine, kills, drops, byMap
local listeners = {}
local list = {}
local found, foundIn, lowered = {}, {}, {}

local R = {}
Completo.Rares = R

local function Prepare()
    if mine then return end
    mine = {}
    local react = UnitFactionGroup("player") == "Horde" and REACT_H or REACT_A
    for npc, rare in pairs(D.Rares) do
        if rare[react] ~= FRIENDLY then mine[npc] = true end
    end
end

local function Kills()
    kills = kills or ns.Shared.CharacterData(KILLS_STORE, true)
    return kills or NONE
end

local function Drops()
    drops = drops or ns.Shared.CharacterData(DROPS_STORE, true)
    return drops or NONE
end

local function Changed(npc)
    for _, fn in ipairs(listeners) do fn(npc) end
end

local function ZoneFor(map)
    for _, zone in ipairs(D.Zones) do
        if zone.map == map then return zone end
    end
end

local function LowerName(npc)
    local name = lowered[npc]
    if name then return name end
    name = D.Rares[npc][NAME]:lower()
    lowered[npc] = name
    return name
end

local function Nearest(points, px, py, bx, by, bestD)
    for i = 1, #points, 2 do
        local dx, dy = points[i] / PERCENT - px, points[i + 1] / PERCENT - py
        local d = dx * dx + dy * dy
        if not bestD or d < bestD then bx, by, bestD = points[i], points[i + 1], d end
    end
    return bx, by, bestD
end

local function QualityColor(quality)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] or WHITE
    return c.r, c.g, c.b
end

local function BuildByMap()
    byMap = {}
    for npc, rare in pairs(D.Rares) do
        if mine[npc] and #rare[SPOTS] > 0 then
            byMap[rare[MAP]] = byMap[rare[MAP]] or {}
            table.insert(byMap[rare[MAP]], npc)
        end
    end
end

local function LootLine(npc, item)
    local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(item[C.LOOT_ID])
    local name = item[C.LOOT_NAME]
    if icon then name = ("|T%s:%d:%d|t %s"):format(icon, TOOLTIP_ICON, TOOLTIP_ICON, name) end
    if item[C.LOOT_NEW] == 1 then name = name .. ns.Shared.Parts.ForeverInline(C.FOREVER_SIGN_SIZE) end
    if R.Dropped(npc, item[C.LOOT_ID]) then name = name .. "  " .. ns.Color(St.HAVE_RGB, TEXT_GOT_IT) end
    return name
end

function R.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

function R.Readable(...)
    for i = 1, select("#", ...) do
        if R.IsSecret((select(i, ...))) then return false end
    end
    return true
end

function R.NpcOf(guid)
    if type(guid) ~= "string" or R.IsSecret(guid) then return end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

function R.Known(npc) return D.Rares[npc] ~= nil end
function R.Name(npc) return D.Rares[npc][NAME] end
function R.Elite(npc) return D.Rares[npc][ELITE] == 1 end
function R.Map(npc) return D.Rares[npc][MAP] end

function R.Levels(npc)
    local rare = D.Rares[npc]
    return rare[LOW], rare[HIGH]
end

function R.LevelText(npc)
    local low, high = R.Levels(npc)
    if low <= 0 then return TEXT_UNKNOWN_LEVEL end
    if low == high then return tostring(low) end
    return ("%d-%d"):format(low, high)
end

function R.KilledText(record)
    if record.n > 1 then return TEXT_KILLED_TIMES:format(record.n) end
    return TEXT_KILLED
end

function R.ChanceText(chance)
    if chance >= 1 then return ("%d%%"):format(math.floor(chance + ROUND_HALF)) end
    return ("%.1f%%"):format(chance)
end

function R.SpotCount(npc) return #D.Rares[npc][SPOTS] / 2 end

function R.Mine(npc)
    Prepare()
    return mine[npc] == true
end

function R.OnChange(fn) listeners[#listeners + 1] = fn end

function R.Killed(npc) return Kills()[npc] ~= nil end

function R.Record(npc) return Kills()[npc] end

function R.AddKill(npc, guid)
    local all = Kills()
    if all == NONE then return end
    local record = all[npc] or { n = 0 }
    record.n = record.n + 1
    record.at = time()
    record.guid = guid
    all[npc] = record
    Changed(npc)
end

function R.SetKilled(npc, killed)
    local all = Kills()
    if all == NONE then return end
    all[npc] = killed and (all[npc] or { n = 0, at = time() }) or nil
    Changed(npc)
end

function R.Dropped(npc, itemID)
    local items = Drops()[npc]
    return items ~= nil and items[itemID] ~= nil
end

function R.AddDrop(npc, itemID)
    local all = Drops()
    if all == NONE then return end
    all[npc] = all[npc] or {}
    if all[npc][itemID] then return end
    all[npc][itemID] = time()
    Changed(npc)
end

function R.ZoneProgress(zone)
    Prepare()
    local all = Kills()
    local n, total, low, high = 0, 0, nil, nil
    for _, npc in ipairs(zone.rares) do
        if mine[npc] then
            total = total + 1
            if all[npc] then n = n + 1 end
            local lo, hi = R.Levels(npc)
            if lo > 0 then
                low = math.min(low or lo, lo)
                high = math.max(high or hi, hi)
            end
        end
    end
    return n, total, low, high
end

function R.Progress()
    local n, total = 0, 0
    for _, zone in ipairs(D.Zones) do
        local zn, zt = R.ZoneProgress(zone)
        n, total = n + zn, total + zt
    end
    return n, total
end

function R.Zones() return D.Zones end

function R.ZoneList(zone)
    Prepare()
    wipe(list)
    for _, npc in ipairs(zone.rares) do
        if mine[npc] then list[#list + 1] = npc end
    end
    return list
end

function R.CurrentZone()
    local map = SameMap(C_Map.GetBestMapForUnit("player"))
    while map do
        local zone = ZoneFor(map)
        if zone then return zone end
        local info = C_Map.GetMapInfo(map)
        map = info and info.parentMapID ~= 0 and info.parentMapID or nil
    end
end

function R.Zone(npc) return ZoneFor(D.Rares[npc][MAP]) end

function R.Search(text, limit)
    Prepare()
    wipe(found)
    local n = 0
    for _, zone in ipairs(D.Zones) do
        local entry = foundIn[zone] or { zone = zone, ids = {} }
        foundIn[zone] = entry
        local ids = wipe(entry.ids)
        for _, npc in ipairs(zone.rares) do
            if mine[npc] and LowerName(npc):find(text, 1, true) then
                n = n + 1
                if n <= limit then ids[#ids + 1] = npc end
            end
        end
        if #ids > 0 then found[#found + 1] = entry end
    end
    return found, n
end

function R.Spot(npc)
    local rare = D.Rares[npc]
    local spots = rare[SPOTS]
    if #spots == 0 then return end
    local pos = C_Map.GetPlayerMapPosition and SameMap(C_Map.GetBestMapForUnit("player")) == rare[MAP]
        and C_Map.GetPlayerMapPosition(rare[MAP], "player")
    if not pos then return rare[MAP], spots[1], spots[2] end
    local px, py = pos:GetXY()
    local bx, by, bestD = Nearest(spots, px, py, spots[1], spots[2], nil)
    if rare[TRAIL] then bx, by = Nearest(rare[TRAIL], px, py, bx, by, bestD) end
    return rare[MAP], bx, by
end

function R.Spots(npc) return D.Rares[npc][SPOTS] end
function R.Trail(npc) return D.Rares[npc][TRAIL] end
function R.Loot(npc) return D.Loot and D.Loot[npc] end
function R.NewInForever(item) return item[C.LOOT_NEW] == 1 end

function R.AddLoot(tooltip, npc)
    local loot = R.Loot(npc)
    if not loot then return end
    local m = T.muted
    tooltip:AddLine(" ")
    tooltip:AddLine(TEXT_DROPS, GOLD_RGB.r, GOLD_RGB.g, GOLD_RGB.b)
    for _, item in ipairs(loot) do
        local r, g, b = QualityColor(item[C.LOOT_QUALITY])
        tooltip:AddDoubleLine(LootLine(npc, item), R.ChanceText(item[C.LOOT_CHANCE]), r, g, b, m.r, m.g, m.b)
    end
    if loot.more then tooltip:AddLine(TEXT_MORE:format(loot.more), m.r, m.g, m.b) end
end

function R.OnMap(mapID)
    Prepare()
    if not byMap then BuildByMap() end
    return byMap[SameMap(mapID)] or NONE
end

function R.Waypoint(npc)
    local map, x, y = R.Spot(npc)
    if map then ns.PlaceWaypoint(R.Name(npc), map, x, y) end
end

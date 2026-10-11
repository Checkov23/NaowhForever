-- NaowhScore.lua: the Naowh Score (ns.NaowhScore): one number for a character's gear, and its grade.
local ns = _G.NaowhForever

local GetItemInfo = C_Item.GetItemInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetDetailedItemLevelInfo = C_Item.GetDetailedItemLevelInfo

local Score = ns.NaowhScore

local MAIN, OFF = 16, 17
local RING_1, RING_2, TRINKET_1, TRINKET_2 = 11, 12, 13, 14
local LAST_SLOT = 18
local LEVEL_GAP = 5
local AHEAD = 5
local BLUE = 3
local EPIC_SCALE, EPIC_SHIFT = 1, 0
local MAX = 0
local NO_REQUIRED = 0
local FACT_ITEM_LEVEL, FACT_REQUIRED, FACT_QUALITY = 3, 4, 5
local PERCENT = 100
local COLOR_MAX = 255
local ROUND = 0.5
local OF_LEVEL_KEY = 101
local UNGRADED = 1
local COMPARE = { LEVEL = "level", BOTH = "both", MAX = "max" }
local TWO_HAND = "INVTYPE_2HWEAPON"
local ID_KEY = "id"
local GOLD = "|cffffd100"
local SCORE_FORMAT = "%.1f"
local CODE_FORMAT = "|cff%02x%02x%02x"
local OF_LEVEL_FORMAT = ns.L("%s%d%% of level %d|r")
local GAP = "  "
local ORDER = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local CATEGORY = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
    INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
    INVTYPE_FINGER = "ring", INVTYPE_TRINKET = "trinket", INVTYPE_CLOAK = 15,
    INVTYPE_WEAPON = "one", INVTYPE_WEAPONMAINHAND = "main", INVTYPE_2HWEAPON = "two",
    INVTYPE_SHIELD = "off", INVTYPE_HOLDABLE = "off", INVTYPE_WEAPONOFFHAND = "off",
    INVTYPE_RANGED = 18, INVTYPE_RANGEDRIGHT = 18, INVTYPE_THROWN = 18, INVTYPE_RELIC = 18,
}
local GRADES = { { 0, 0 }, { 0.25, 1 }, { 0.45, 2 }, { 0.65, 3 }, { 0.80, 4 }, { 0.95, 5 } }
local RAMP = {
    { 0.00, 0.62, 0.62, 0.62 }, { 0.15, 1.00, 1.00, 1.00 }, { 0.25, 0.78, 1.00, 0.70 },
    { 0.35, 0.50, 1.00, 0.40 }, { 0.45, 0.12, 1.00, 0.00 }, { 0.55, 0.20, 0.75, 1.00 },
    { 0.65, 0.00, 0.44, 0.87 }, { 0.72, 0.40, 0.36, 1.00 }, { 0.80, 0.64, 0.21, 0.93 },
    { 0.88, 0.82, 0.32, 0.88 }, { 0.94, 1.00, 0.66, 0.25 }, { 1.00, 1.00, 0.50, 0.00 },
}
local RAMP_SHARE, RAMP_R, RAMP_G, RAMP_B = 1, 2, 3, 4

local TOTAL = 0
for _, slot in ipairs(ORDER) do TOTAL = TOTAL + Score.SLOTS[slot] end

local unitLinks = {}
local bestAt = {}
local rampCodes = {}
local percents, ofLevels = {}, {}

local function Worth(level, quality)
    return level * (Score.SCALE[quality] or EPIC_SCALE) + (Score.SHIFT[quality] or EPIC_SHIFT)
end

local function Epic(level, quality)
    return math.max(0, Worth(level, quality))
end

local function ReadUnit(slot)
    return Score.Link(unitLinks[slot])
end

local function Offer(best, second, category, worth, id)
    local top = best[category]
    if not top or worth > top then
        if top then second[category] = top end
        best[category] = worth
        best[category .. ID_KEY] = id
    elseif id ~= best[category .. ID_KEY] and (not second[category] or worth > second[category]) then
        second[category] = worth
    end
end

local function Collect(level, best, second)
    for id, facts in pairs(ns.Shared.ItemFacts) do
        local itemLevel, required, quality = facts[FACT_ITEM_LEVEL], facts[FACT_REQUIRED], facts[FACT_QUALITY]
        if required == NO_REQUIRED then required = itemLevel - LEVEL_GAP end
        if level == MAX or required <= level then
            local _, _, _, equipLoc = GetItemInfoInstant(id)
            local category = CATEGORY[equipLoc or ""]
            if category then Offer(best, second, category, Epic(itemLevel, quality), id) end
        end
    end
end

local function Best(level)
    local best, second = {}, {}
    Collect(level, best, second)
    local W = Score.SLOTS
    local sum = 0
    for slot = 1, LAST_SLOT do
        if W[slot] and best[slot] then sum = sum + W[slot] * best[slot] end
    end
    sum = sum + W[RING_1] * (best.ring or 0) + W[RING_2] * (second.ring or 0)
    sum = sum + W[TRINKET_1] * (best.trinket or 0) + W[TRINKET_2] * (second.trinket or 0)
    local one = math.max(best.one or 0, best.main or 0)
    local off = math.max(best.off or 0, second.one or 0)
    sum = sum + math.max((W[MAIN] + W[OFF]) * (best.two or 0), W[MAIN] * one + W[OFF] * off)
    return sum > 0 and sum / TOTAL or nil
end

local function Percentage(share)
    return math.floor(math.max(0, math.min(1, share)) * PERCENT + ROUND)
end

local function Mix(low, high, t, k)
    return math.floor((low[k] + (high[k] - low[k]) * t) * COLOR_MAX + ROUND)
end

local function Stops(s)
    for i = 2, #RAMP do
        if s <= RAMP[i][RAMP_SHARE] then return RAMP[i - 1], RAMP[i] end
    end
    return RAMP[1], RAMP[#RAMP]
end

local function Percent(share)
    local percent = Percentage(share)
    local text = percents[percent]
    if not text then
        text = Score.Code(percent / PERCENT) .. percent .. "%|r"
        percents[percent] = text
    end
    return text
end

local function OfLevel(share, level)
    local percent = Percentage(share)
    local key = level * OF_LEVEL_KEY + percent
    local text = ofLevels[key]
    if not text then
        text = OF_LEVEL_FORMAT:format(GOLD, percent, level)
        ofLevels[key] = text
    end
    return text
end

Score.GRADES = GRADES
Score.RAMP = RAMP
Score.COMPARE = COMPARE

function Score.Of(read)
    local sum, complete, twoHand = 0, true, false
    for _, slot in ipairs(ORDER) do
        if not (slot == OFF and twoHand) then
            local weight = Score.SLOTS[slot]
            local level, quality, two = read(slot)
            if slot == MAIN and two then
                twoHand = true
                weight = weight + Score.SLOTS[OFF]
            end
            if level then
                if not quality then complete = false end
                local epic = level * (Score.SCALE[quality] or EPIC_SCALE) + (Score.SHIFT[quality] or EPIC_SHIFT)
                if epic > 0 then sum = sum + weight * epic end
            end
        end
    end
    return sum / TOTAL, complete
end

function Score.Link(link)
    if not link then return nil end
    local level = GetDetailedItemLevelInfo(link)
    local _, _, quality = GetItemInfo(link)
    local _, _, _, equip = GetItemInfoInstant(link)
    return level or 0, level and quality, equip == TWO_HAND
end

function Score.Unit(unit)
    wipe(unitLinks)
    for slot in pairs(Score.SLOTS) do unitLinks[slot] = GetInventoryItemLink(unit, slot) end
    return Score.Of(ReadUnit)
end

function Score.Links(links)
    wipe(unitLinks)
    for slot, link in pairs(links) do unitLinks[slot] = link end
    return Score.Of(ReadUnit)
end

function Score.Text(score)
    return SCORE_FORMAT:format(score)
end

function Score.Best(level)
    local key = level or MAX
    local best = bestAt[key]
    if best == nil then
        best = Best(key) or false
        if key ~= MAX then
            local top = Score.Best()
            best = math.max(best or 0, Epic(key + AHEAD, BLUE))
            if top then best = math.min(best, top) end
        end
        bestAt[key] = best
    end
    return best or nil
end

function Score.Code(share)
    local percent = Percentage(share)
    local code = rampCodes[percent]
    if code then return code end
    local s = percent / PERCENT
    local low, high = Stops(s)
    local t = high[RAMP_SHARE] > low[RAMP_SHARE] and (s - low[RAMP_SHARE]) / (high[RAMP_SHARE] - low[RAMP_SHARE]) or 1
    code = CODE_FORMAT:format(Mix(low, high, t, RAMP_R), Mix(low, high, t, RAMP_G), Mix(low, high, t, RAMP_B))
    rampCodes[percent] = code
    return code
end

function Score.Grade(score, level, against)
    against = against or ns.QoLSettings.Get("naowhScoreCompare")
    local best = Score.Best(against == COMPARE.LEVEL and level or nil)
    if not best or best <= 0 then return nil, UNGRADED end
    local share = math.min(1, score / best)
    local quality = 0
    for _, grade in ipairs(Score.GRADES) do
        if share >= grade[1] then quality = grade[2] end
    end
    return share, quality
end

function Score.Colored(score, level, against)
    local share = Score.Grade(score, level, against)
    return share and Score.Code(share) .. Score.Text(score) .. "|r" or Score.Text(score)
end

function Score.Tooltip(score, level)
    local compare = ns.QoLSettings.Get("naowhScoreCompare")
    local against = compare == COMPARE.BOTH and COMPARE.MAX or nil
    local text = Score.Colored(score, level, against)
    if compare == COMPARE.BOTH and level then
        local best, top = Score.Best(level), Score.Best()
        if best and top and best < top then return text .. GAP .. OfLevel(math.min(1, score / best), level) end
    end
    local share = Score.Grade(score, level, against)
    return share and (text .. GAP .. Percent(share)) or text
end

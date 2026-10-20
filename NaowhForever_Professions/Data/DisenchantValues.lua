-- DisenchantValues.lua: expected Forever disenchant outcomes, skill bands and auction values.
local ns = _G.NaowhForever

local P = ns.Professions

local WEAPON, ARMOR = 2, 4
local UNCOMMON, RARE, EPIC = 2, 3, 4
local AUCTION_RETURN = 0.95
local NEVER = { INVTYPE_BODY = true, INVTYPE_TABARD = true }
local NO_DISENCHANT = {
    [11287] = true,
    [11288] = true,
    [11289] = true,
    [20406] = true,
    [20407] = true,
    [20408] = true,
    [44803] = true,
    [217287] = true,
    [249144] = true,
    [249232] = true,
    [249234] = true,
    [249237] = true,
}
local outcomeCache = {}

local uncommon = {
    { 5, 15, 10940, 10938, nil, 80, 20, 20, 80, 1, 2, 1, 2 },
    { 16, 20, 10940, 10939, 10978, 75, 20, 20, 75, 2, 3, 1, 2 },
    { 21, 25, 10940, 10998, 10978, 75, 15, 15, 75, 4, 6, 1, 2 },
    { 26, 30, 11083, 11082, 11084, 75, 20, 20, 75, 1, 2, 1, 2 },
    { 31, 35, 11083, 11134, 11138, 75, 20, 20, 75, 2, 5, 1, 2 },
    { 36, 40, 11137, 11135, 11139, 75, 20, 20, 75, 1, 2, 1, 2 },
    { 41, 45, 11137, 11174, 11177, 75, 20, 20, 75, 2, 5, 1, 2 },
    { 46, 50, 11176, 11175, 11178, 75, 20, 20, 75, 1, 2, 1, 2 },
    { 51, 55, 11176, 16202, 14343, 75, 20, 22, 75, 2, 5, 1, 2 },
    { 56, 60, 16204, 16203, 14344, 75, 20, 22, 75, 1, 2, 1, 2 },
    { 61, 65, 16204, 16203, 14344, 75, 20, 22, 75, 2, 5, 2, 3 },
}

local rare = {
    { 1, 25, 10978 },
    { 26, 30, 11084 },
    { 31, 35, 11138 },
    { 36, 40, 11139 },
    { 41, 45, 11177 },
    { 46, 50, 11178 },
    { 51, 55, 14343 },
    { 56, 80, 14344, 20725 },
}

local epic = {
    { 40, 45, 11177, 2, 4 },
    { 46, 50, 11178, 2, 4 },
    { 51, 55, 14343, 2, 4 },
    { 56, 60, 20725, 1, 1 },
    { 61, 88, 20725, 1, 2 },
}

local Values = { WEAPON = WEAPON, ARMOR = ARMOR }
P.DisenchantValues = Values

local function Find(rows, level)
    for _, row in ipairs(rows) do
        if level >= row[1] and level <= row[2] then return row end
    end
end

local function Outcome(itemID, chance, minimum, maximum)
    return { itemID = itemID, chance = chance, minimum = minimum or 1, maximum = maximum or minimum or 1 }
end

function Values.Equipment(classID, equip)
    return (classID == WEAPON or classID == ARMOR) and not NEVER[equip or ""]
end

function Values.Takes(classID, quality, equip)
    return Values.Equipment(classID, equip) and type(quality) == "number"
        and quality >= UNCOMMON and quality <= EPIC
end

function Values.ItemEligible(itemID, classID, equip)
    return not NO_DISENCHANT[itemID] and Values.Equipment(classID, equip)
end

function Values.ItemTakes(itemID, classID, quality, equip)
    return Values.ItemEligible(itemID, classID, equip) and type(quality) == "number"
        and quality >= UNCOMMON and quality <= EPIC
end

function Values.RequiredSkill(level, quality)
    if not level or level < 1 or not quality then return end
    if quality >= RARE and level <= 25 then return 25 end
    if level <= 20 then return 1 end
    return math.max(25, (math.ceil(level / 5) - 4) * 25)
end

function Values.SkillupBand(skill)
    if not skill or skill < 1 or skill >= 60 then return end
    if skill < 20 then return "guaranteed" end
    if skill < 40 then return "likely" end
    return "unlikely"
end

function Values.LevelBracket(skill)
    if not Values.SkillupBand(skill) then return end
    if skill < 25 then return 1 end
    return math.floor(skill / 25) * 25
end

function Values.LevelEligible(required, skill)
    return required and skill and required <= skill and Values.SkillupBand(skill) ~= nil
end

local function BuildOutcomes(classID, quality, level)
    if quality == UNCOMMON then
        local row = Find(uncommon, level)
        if not row then return end
        local weapon = classID == WEAPON
        local dustChance, essenceChance = row[weapon and 8 or 6], row[weapon and 9 or 7]
        local outcomes = {
            Outcome(row[3], dustChance, row[10], row[11]),
            Outcome(row[4], essenceChance, row[12], row[13]),
        }
        if row[5] then outcomes[#outcomes + 1] = Outcome(row[5], 100 - dustChance - essenceChance) end
        return outcomes
    end
    if quality == RARE then
        local row = Find(rare, level)
        if not row then return end
        if row[4] then return { Outcome(row[3], 99.5), Outcome(row[4], 0.5) } end
        return { Outcome(row[3], 100) }
    end
    if quality == EPIC then
        local row = Find(epic, level)
        if row then return { Outcome(row[3], 100, row[4], row[5]) } end
    end
end

function Values.Outcomes(classID, quality, level)
    if not (classID and quality and level) then return end
    local key = classID * 100000 + quality * 1000 + level
    local outcomes = outcomeCache[key]
    if outcomes == false then return end
    if outcomes then return outcomes end
    outcomes = BuildOutcomes(classID, quality, level)
    outcomeCache[key] = outcomes or false
    return outcomes
end

function Values.Expected(classID, quality, level, prices)
    local outcomes = Values.Outcomes(classID, quality, level)
    if not outcomes then return end
    local total, complete = 0, true
    for _, result in ipairs(outcomes) do
        local each = prices[result.itemID]
        if each then
            total = total + result.chance / 100 * (result.minimum + result.maximum) / 2 * each
        else
            complete = false
        end
    end
    if complete then return math.floor(total), outcomes end
end

function Values.AfterCut(gross)
    return math.floor(gross * AUCTION_RETURN)
end

function Values.Guaranteed(outcomes, prices, cost)
    for _, result in ipairs(outcomes) do
        local each = prices[result.itemID]
        if not each or Values.AfterCut(each * result.minimum) <= cost then return false end
    end
    return #outcomes > 0
end

function Values.LevelBetter(a, b)
    local aProfit, bProfit = a.profit >= 0, b.profit >= 0
    if aProfit ~= bProfit then return aProfit end
    if a.price ~= b.price then return a.price < b.price end
    if a.profit ~= b.profit then return a.profit > b.profit end
    if a.roi ~= b.roi then return a.roi > b.roi end
    return a.item < b.item
end

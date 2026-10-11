-- Sharing.lua: a spec's weights as a line to share, and back, or a simulator's export (SW.Export, SW.Import).
local ns = _G.NaowhForever

local SW = ns.StatWeights

local PREFIX = "NFSW1"
local LINE_PATTERN = "^%s*" .. PREFIX .. ":([%w%-]+):([%w=.,%-]*)%s*$"
local PART_PATTERN = "^(%w+)=([%d.]+)$"
local SIM_STRING = '^%s*%(%s*%a+%s*:%s*v1%s*:%s*"([^"]*)"%s*:%s*(.-)%s*%)%s*$'
local SIM_PART = "^%s*(%w+)%s*=%s*(%S-)%s*$"
local WEIGHT = "%s=%g"
local MAX_WORTH = SW.MAX_WORTH
local MAX_NAME = 40
local CLASS_KEY, RANGED_DPS = "class", "rangeddps"
local HUNTER = "HUNTER"
local TEXT_PICK_SPEC = ns.L("Pick your spec first.")
local TEXT_OTHER_CLASS = ns.L("Those weights are for a %s.")
local TEXT_NO_STAT = ns.L("Those weights name no stat it can read.")
local TEXT_SIM_IMPORTED = ns.L("%s imported for %s.")
local TEXT_THE_WEIGHTS = ns.L("The weights")
local TEXT_NOT_A_LINE = ns.L("That is not a Naowh stat weights line, nor a simulator's export.")
local TEXT_BAD_WEIGHT = ns.L("That line has a weight it cannot read: %s.")
local TEXT_IMPORTED = ns.L("Weights for %s imported.")
local SIM_KEYS = {
    strength = "str", agility = "agi", stamina = "sta", intellect = "int", spirit = "spi",
    ap = "ap", rap = "rap", dps = "dps", meleedps = "dps", mainhanddps = "dps", onehanddps = "dps",
    twohanddps = "dps", hitrating = "hit", spellhitrating = "shit", critrating = "crit",
    spellcritrating = "scrit", hasterating = "haste", spellhasterating = "haste", spelldamage = "spell",
    spellpower = "spell", healing = "heal", mp5 = "mp5", armor = "armor", defenserating = "def",
    dodgerating = "dodge", blockrating = "block", firespelldamage = "fire", frostspelldamage = "frost",
    shadowspelldamage = "shadow", naturespelldamage = "nature", arcanespelldamage = "arcane",
    holyspelldamage = "holy",
}

local function SimStat(stat, class)
    if stat == RANGED_DPS then return class == HUNTER and "dps" end
    return SIM_KEYS[stat]
end

local function ReadSim(body, class, read)
    local count = 0
    for part in body:gmatch("[^,]+") do
        local stat, value = part:match(SIM_PART)
        stat = stat and stat:lower()
        if stat == CLASS_KEY then
            if value:upper():gsub("%s", "") ~= class then
                return nil, TEXT_OTHER_CLASS:format(ns.Shared.Decode.Text(value, MAX_NAME))
            end
        else
            local mine = SimStat(stat, class)
            local worth = tonumber(value)
            if mine and worth and worth > 0 and worth < MAX_WORTH then
                read[mine] = (read[mine] or 0) + worth
                count = count + 1
            end
        end
    end
    return count
end

local function ImportSim(name, body, key)
    local spec = SW.Spec(key)
    if not spec then return false, TEXT_PICK_SPEC end
    local _, class = UnitClass("player")
    local read = {}
    local count, err = ReadSim(body, class, read)
    if not count then return false, err end
    if count == 0 then return false, TEXT_NO_STAT end
    for _, stat in ipairs(SW.STATS) do SW.Set(key, stat[1], read[stat[1]] or 0) end
    name = ns.Shared.Decode.Text(name, MAX_NAME)
    return true, TEXT_SIM_IMPORTED:format(name ~= "" and name or TEXT_THE_WEIGHTS, spec.name)
end

local function ReadLine(body)
    local read = {}
    for part in body:gmatch("[^,]+") do
        local stat, worth = part:match(PART_PATTERN)
        worth = tonumber(worth)
        if not (SW.IsStat(stat) and worth and worth < MAX_WORTH) then return nil, TEXT_BAD_WEIGHT:format(part) end
        read[stat] = worth
    end
    return read
end

function SW.Export(key)
    local weights = SW.For(key)
    if not weights then return "" end
    local parts = {}
    for _, stat in ipairs(SW.STATS) do
        if SW.Changed(key, stat[1]) then parts[#parts + 1] = WEIGHT:format(stat[1], weights[stat[1]] or 0) end
    end
    return PREFIX .. ":" .. key .. ":" .. table.concat(parts, ",")
end

function SW.Import(text, key)
    local name, simBody = (text or ""):match(SIM_STRING)
    if simBody then return ImportSim(name, simBody, key) end
    local lineKey, body = (text or ""):match(LINE_PATTERN)
    local spec = lineKey and SW.Spec(lineKey)
    if not spec then return false, TEXT_NOT_A_LINE end
    local read, err = ReadLine(body)
    if not read then return false, err end
    SW.Reset(lineKey)
    for stat, worth in pairs(read) do SW.Set(lineKey, stat, worth) end
    return true, TEXT_IMPORTED:format(spec.name)
end

-- Message.lua: Group Inspect's addon messages: the request, an answer written and read back, and an answer kept on a member (GI.Message).
local ns = _G.NaowhForever

local GI = ns.GroupInspect
local C = GI.C
local SW = ns.StatWeights

local PREFIX = "NaowhGroup"
local REQUEST = "1 R"
local ANSWER_FORMAT = "1 S %s %s %d/%d/%d %d %d %d %d %d %d %d %d %d %d"
local ANSWER_PATTERN = "^1 S (Player%-%d+%-%x+) (%d[%w%.%-]*) (%d+)/(%d+)/(%d+) (%d+) (%d+) (%d+) (%d+) (%d+) "
    .. "(%d+) (%d+) (%d+) (%d+) (%d+)$"
local VERSION_PATTERN = "^%d[%w%.%-]*$"
local MAX_BYTES = 255
local MAX_VERSION = 20
local MAX_POINTS = 100
local STAT_KEYS, STAT_MAX = C.STAT_KEYS, C.STAT_MAX
local TENTHS = { CRIT = true, HIT = true }
local TENTH_SCALE = C.TENTHS
local CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true }
local ROLE = {
    ["protection-warrior"] = ns.L("Tank"), ["protection-paladin"] = ns.L("Tank"),
    ["holy-paladin"] = ns.L("Healer"), ["discipline-priest"] = ns.L("Healer"), ["holy-priest"] = ns.L("Healer"),
    ["restoration-druid"] = ns.L("Healer"), ["restoration-shaman"] = ns.L("Healer"),
}
local DAMAGE = ns.L("Damage")

local mine = GI.OwnStats.values
local version = type(ns.CODE_BUILD) == "string" and #ns.CODE_BUILD <= MAX_VERSION
    and ns.CODE_BUILD:find(VERSION_PATTERN) and ns.CODE_BUILD or "0"
local parsed = { stats = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, spent = { 0, 0, 0 } }

local function Answer(guid)
    local stats, spent = mine.stats, mine.spent
    return ANSWER_FORMAT:format(guid, version, spent[1], spent[2], spent[3],
        stats[1], stats[2], stats[3], stats[4], stats[5], stats[6], stats[7], stats[8], stats[9], stats[10])
end

local function Number(text, index, into, most)
    local value = tonumber(text)
    if not value or value ~= value or value > most then return false end
    into[index] = value
    return true
end

local function Parse(message)
    local guid, ver, t1, t2, t3, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10 = message:match(ANSWER_PATTERN)
    if not guid or #ver > MAX_VERSION then return nil end
    local spent, stats = parsed.spent, parsed.stats
    if not (Number(t1, 1, spent, MAX_POINTS) and Number(t2, 2, spent, MAX_POINTS) and Number(t3, 3, spent, MAX_POINTS))
        or spent[1] + spent[2] + spent[3] > MAX_POINTS then
        return nil
    end
    if not (Number(s1, 1, stats, STAT_MAX[1]) and Number(s2, 2, stats, STAT_MAX[2]) and Number(s3, 3, stats, STAT_MAX[3])
        and Number(s4, 4, stats, STAT_MAX[4]) and Number(s5, 5, stats, STAT_MAX[5]) and Number(s6, 6, stats, STAT_MAX[6])
        and Number(s7, 7, stats, STAT_MAX[7]) and Number(s8, 8, stats, STAT_MAX[8]) and Number(s9, 9, stats, STAT_MAX[9])
        and Number(s10, 10, stats, STAT_MAX[10])) then
        return nil
    end
    parsed.version = ver
    return guid
end

local function Apply(guid, from)
    local record = GI.Member(guid)
    if type(record) ~= "table" then return end
    local into = record.stats
    if type(into) ~= "table" then
        into = {}
        record.stats = into
    end
    local stats = from.stats
    for i = 1, #STAT_KEYS do
        local key = STAT_KEYS[i]
        into[key] = TENTHS[key] and stats[i] / TENTH_SCALE or stats[i]
    end
    local talents = record.talents
    if type(talents) ~= "table" then
        talents = {}
        record.talents = talents
    end
    if type(talents.spent) ~= "table" then talents.spent = {} end
    local spent, best, most = from.spent, nil, 0
    for i = 1, #spent do
        talents.spent[i] = spent[i]
        if spent[i] > most then best, most = i, spent[i] end
    end
    local key = best and record.classFile and SW.TreeSpec(record.classFile, best)
    local spec = key and SW.Spec(key)
    talents.tree = spec and spec.name or nil
    talents.role = best and (ROLE[key or ""] or DAMAGE) or nil
    record.statsShared, record.hasNF = true, true
    record.nfVersion = from == mine and version or from.version
    record.updated = GetTime()
    if GI.Changed then GI.Changed(guid) end
end

GI.Message = { PREFIX = PREFIX, REQUEST = REQUEST, MAX_BYTES = MAX_BYTES, CHANNELS = CHANNELS, parsed = parsed,
    Answer = Answer, Parse = Parse, Apply = Apply }

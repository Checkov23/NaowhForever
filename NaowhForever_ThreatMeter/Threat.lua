-- Threat.lua: the Threat Meter's rules: whose threat to read, on which mob, sorted, and when to warn.
local ns = _G.NaowhForever

local TM = ns.ThreatMeter
local S = TM.Settings
local C = TM.C

local PERCENT = C.PERCENT
local TANK_FORMS = { [5] = true, [8] = true, [18] = true }
local YOU = ns.L("You")

local entries = {}
local list = {}
local count = 0
local watched = "target"
local armed = true

local PARTY_UNITS, RAID_UNITS = { "player", "pet" }, {}
for i = 1, MAX_PARTY_MEMBERS do
    PARTY_UNITS[#PARTY_UNITS + 1] = "party" .. i
    PARTY_UNITS[#PARTY_UNITS + 1] = "partypet" .. i
end
for i = 1, MAX_RAID_MEMBERS do
    RAID_UNITS[#RAID_UNITS + 1] = "raid" .. i
    RAID_UNITS[#RAID_UNITS + 1] = "raidpet" .. i
end
local OWNER, IN_GROUP = {}, {}
for _, units in ipairs({ PARTY_UNITS, RAID_UNITS }) do
    for i = 1, #units, 2 do
        local member, pet = units[i], units[i + 1]
        OWNER[member], OWNER[pet] = member, member
        IN_GROUP[member], IN_GROUP[pet] = true, true
    end
end

local function Readable(v)
    return not (issecretvalue and issecretvalue(v)) and v ~= nil
end

local function Attackable(unit)
    local exists, hostile = UnitExists(unit), UnitCanAttack("player", unit)
    return Readable(exists) and exists and Readable(hostile) and hostile
end

local function TankSkipsWarning()
    if not S.Get("warnSkipTank") then return false end
    return UnitGroupRolesAssigned("player") == "TANK" or TANK_FORMS[GetShapeshiftFormID()] == true
end

local function NextEntry()
    count = count + 1
    local e = entries[count]
    if not e then e = {}; entries[count] = e end
    list[#list + 1] = e
    return e
end

local function Clear()
    count = 0
    for i = #list, 1, -1 do list[i] = nil end
end

local function Read(unit, mob)
    if not UnitExists(unit) then return end
    local tanking, _, pullPct, tankPct, threat = UnitDetailedThreatSituation(unit, mob)
    if not (Readable(threat) and Readable(pullPct) and Readable(tanking)) or threat <= 0 then return end
    local isPlayer = UnitIsUnit(unit, "player")
    local owner = OWNER[unit]
    local _, class = UnitClass(owner)
    local e = NextEntry()
    e.unit, e.name, e.seq = unit, UnitName(unit), count
    e.threat, e.pullPct, e.tankPct = threat, pullPct, Readable(tankPct) and tankPct or nil
    e.tanking, e.isPlayer, e.isLine = tanking, Readable(isPlayer) and isPlayer, false
    e.isPet, e.class = owner ~= unit, Readable(class) and class or nil
    return e
end

local function FillLine(e, me)
    e.unit, e.name, e.class, e.seq = nil, C.LINE_NAME, nil, 0
    e.threat, e.pullPct = me.threat * PERCENT / me.pullPct, PERCENT
    e.tankPct = me.tankPct and me.tankPct * PERCENT / me.pullPct
    e.tanking, e.isPlayer, e.isLine, e.isPet = false, false, true, false
end

local function LineFor(me)
    return S.Get("pullBar") and me and not me.tanking and me.pullPct > 0
end

local function MoreThreat(a, b)
    return a.threat > b.threat or a.threat == b.threat and a.seq < b.seq
end

local function SampleTank(sample)
    local tankThreat
    for _, s in ipairs(sample) do
        if s.tanking then tankThreat = s.threat end
    end
    return tankThreat
end

local function FillSampleEntry(e, s, i, class, tankThreat)
    e.unit, e.name, e.seq = nil, s.you and (UnitName("player") or YOU) or s.name, i
    e.threat, e.pullPct, e.tankPct = s.threat, s.pullPct, s.threat * PERCENT / tankThreat
    e.tanking, e.isPlayer, e.isLine, e.isPet = s.tanking == true, s.you == true, false, s.pet == true
    e.class = s.you and class or s.class
end

TM.list = list
TM.entries = entries
TM.IN_GROUP = IN_GROUP
TM.Readable = Readable
TM.Clear = Clear

function TM.Watched()
    return watched
end

function TM.Rewatch()
    watched = S.Get("focusEnabled") and S.Get("source") or "target"
end

function TM.ThreatMob()
    if Attackable(watched) then return watched end
    local enemy = watched .. "target"
    if Attackable(enemy) then return enemy end
end

function TM.Collect(mob)
    Clear()
    local units, members = PARTY_UNITS, GetNumSubgroupMembers() + 1
    if IsInRaid() then units, members = RAID_UNITS, GetNumGroupMembers() end
    local step = S.Get("ignorePets") and 2 or 1
    local me
    for i = 1, members * 2, step do
        local e = Read(units[i], mob)
        if e and e.isPlayer then me = e end
    end
    if LineFor(me) then FillLine(NextEntry(), me) end
    table.sort(list, MoreThreat)
    return me
end

function TM.FillSample(sample, out, pool)
    wipe(out)
    local tankThreat = SampleTank(sample)
    local _, class = UnitClass("player")
    local me
    for i, s in ipairs(sample) do
        if not (s.pet and S.Get("ignorePets")) then
            local e = pool[i] or {}
            pool[i] = e
            FillSampleEntry(e, s, i, class, tankThreat)
            if e.isPlayer then me = e end
            out[#out + 1] = e
        end
    end
    if LineFor(me) then
        local e = pool[#sample + 1] or {}
        pool[#sample + 1] = e
        FillLine(e, me)
        out[#out + 1] = e
    end
    table.sort(out, MoreThreat)
    return me
end

function TM.Rearm()
    armed = true
end

function TM.Warn(me)
    local due = S.Get("warnSound") and me and not me.tanking and me.pullPct >= S.Get("warnAt")
        and not TankSkipsWarning()
    if not due then
        armed = true
    elseif armed then
        armed = false
        ns.UI._PlayLSMSound(ns.UI.SoundPathFor(S.Get("warnSoundKey")))
    end
end

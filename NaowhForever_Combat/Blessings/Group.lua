-- Group.lua: your group as the bar sees it: each member's names, class and GUID, and who can plan for others.
local ns = _G.NaowhForever

local B = ns.Blessings
local Secret = B.Secret

local NAME_SLOTS = 4

local function Readable(v)
    return not Secret(v) and v ~= nil and v ~= ""
end

local function HeaderNames(member, realm, firstNames, raid)
    local seen, out = {}, {}
    local function Add(name)
        if Readable(name) and not seen[name] then
            seen[name] = true
            out[#out + 1] = name
        end
    end
    for _, name in ipairs(member.candidates) do
        if firstNames[name] == 1 then Add(name) end
    end
    if not member.who:find("-", 1, true) then Add(member.who .. "-" .. realm) end
    local seenBy
    if raid then
        seenBy = member.rosterName
    elseif Readable(member.short) then
        seenBy = Readable(member.server) and member.short .. "-" .. member.server or member.short
    end
    return table.concat(out, ","), Readable(seenBy) and seen[seenBy] == true
end

local function Roster()
    local units = { "player" }
    local raid = IsInRaid()
    if raid then
        units = {}
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    else
        for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
    end
    local realm = GetNormalizedRealmName()
    local list, firstNames = {}, {}
    for i, unit in ipairs(units) do
        local name, unitRealm = UnitFullName(unit)
        local _, class = UnitClass(unit)
        local guid = UnitGUID(unit)
        if name and not (Secret(name) or Secret(unitRealm) or Secret(class) or Secret(guid)) and class then
            local who = name
            if unitRealm and unitRealm ~= "" and unitRealm ~= realm then who = name .. "-" .. unitRealm end
            local short, server = UnitName(unit)
            local member = { unit = unit, guid = guid, class = class, who = who, short = short,
                server = server, rosterName = raid and (GetRaidRosterInfo(i)) or nil }
            local subgroup = raid and select(3, GetRaidRosterInfo(i))
            member.subgroup = not Secret(subgroup) and subgroup or nil
            local names = { who, short, member.rosterName }
            if Readable(short) and Readable(server) then names[4] = short .. "-" .. server end
            member.candidates = {}
            local counted = {}
            for k = 1, NAME_SLOTS do
                local n = names[k]
                if Readable(n) and not counted[n] then
                    counted[n] = true
                    firstNames[n] = (firstNames[n] or 0) + 1
                    member.candidates[#member.candidates + 1] = n
                end
            end
            list[#list + 1] = member
        end
    end
    for _, member in ipairs(list) do
        member.names, member.targetable = HeaderNames(member, realm, firstNames, raid)
    end
    return list
end

B.Roster = Roster

function B.Visible(roster)
    if not (B.Settings.Get("blessBench") and IsInRaid()) then return roster end
    local _, kind, _, _, maxPlayers = GetInstanceInfo()
    if kind ~= "raid" or not maxPlayers or maxPlayers <= 0 then return roster end
    local last = math.ceil(maxPlayers / 5)
    local shown = {}
    for _, member in ipairs(roster) do
        if not member.subgroup or member.subgroup <= last then shown[#shown + 1] = member end
    end
    return shown
end

function B.InGroup(who)
    for _, member in ipairs(Roster()) do
        if member.who == who then return member end
    end
end

function B.CanAssign(unit)
    local lead, assist = UnitIsGroupLeader(unit), UnitIsGroupAssistant(unit)
    return not (Secret(lead) or Secret(assist)) and (lead or assist)
end

local TANKING = { WARRIOR = true, DRUID = true, PALADIN = true }
local UNSUITED = {
    WARRIOR = { wisdom = true }, ROGUE = { wisdom = true },
    MAGE = { might = true }, WARLOCK = { might = true }, PRIEST = { might = true },
}
local NO_BLESSING = "none"

function B.IsTank(unit)
    local role = UnitGroupRolesAssigned(unit)
    if not Secret(role) and role == "TANK" then return true end
    return GetPartyAssignment("MAINTANK", unit) and true or false
end

local function IsAssist(unit)
    return GetPartyAssignment("MAINASSIST", unit) and true or false
end

local function RoleBlessing(member)
    local S = B.Settings
    local tank, assist = S.Get("blessTank"), S.Get("blessAssist")
    if not TANKING[member.class] or (tank == NO_BLESSING and assist == NO_BLESSING) then return end
    local key = tank ~= NO_BLESSING and B.IsTank(member.unit) and tank
        or assist ~= NO_BLESSING and IsAssist(member.unit) and assist
    return key and B.Learned(B.BY_KEY[key]) and key or nil
end

function B.Assigned(member)
    local store = B.Store()
    return store.players[member.guid] or RoleBlessing(member) or store.classes[member.class]
end

function B.Allowed(class, key)
    local no = B.Settings.Get("blessSmart") and UNSUITED[class]
    return not (no and no[key])
end

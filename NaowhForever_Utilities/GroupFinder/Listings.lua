-- Listings.lua: Forever's own group listings from the player's last search, read into pooled entries with their dungeon as a Journal key (ns.GroupFinder.Listings).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local Card = GF.Card
local S = GF.Settings

local lower, gsub, sub, min = string.lower, string.gsub, string.sub, math.min

local MEMBERS_READ = 5
local MAX_ENTRIES = 100
local NAME_MIN = 4
local RECEIVED, UPDATED, FAILED = "LFG_LIST_SEARCH_RESULTS_RECEIVED", "LFG_LIST_SEARCH_RESULT_UPDATED",
    "LFG_LIST_SEARCH_FAILED"
local EVENTS = { RECEIVED, UPDATED, FAILED }

local Listings = { entries = {}, n = 0, state = "none", searched = false, MEMBERS_READ = MEMBERS_READ }
GF.Listings = Listings

local entries = Listings.entries
local stale = true
local frame, on = nil, false
local activityKey, activityInfo = {}, {}
local byName, byMap, names

local function Secret(v)
    return v ~= nil and issecretvalue(v)
end

local function Plain(name)
    return (gsub(gsub(lower(name), "^the ", ""), "[^%w]", ""))
end

local function Index()
    if byName then return true end
    local J = ns.Journal
    if not J then return false end
    byName, byMap, names = {}, {}, {}
    for _, dungeon in ipairs(J.Dungeons()) do
        local plain = Plain(dungeon.name)
        byName[plain] = dungeon.key
        names[#names + 1] = plain
        local map = dungeon.quests and dungeon.quests.map
        if map then byMap[map] = byMap[map] == nil and dungeon.key or false end
    end
    return true
end

local function Match(fullName, mapID)
    local plain = Plain(fullName)
    if byName[plain] then return byName[plain] end
    if #plain >= NAME_MIN then
        local best
        for i = 1, #names do
            local name = names[i]
            if sub(plain, 1, #name) == name and (not best or #name > #best) then best = name end
        end
        if best then return byName[best] end
        local only, count = nil, 0
        for i = 1, #names do
            if sub(names[i], 1, #plain) == plain then only, count = names[i], count + 1 end
        end
        if count == 1 then return byName[only] end
    end
    return mapID and byMap[mapID] or false
end

function Listings.Match(fullName, mapID)
    if not Index() then return nil end
    return Match(fullName, mapID) or nil
end

function Listings.DungeonOf(activityID)
    local key = activityKey[activityID]
    if key ~= nil then return key or nil end
    if not Index() then return nil end
    local info = C_LFGList.GetActivityInfoTable(activityID)
    local name = info and info.fullName
    if type(name) ~= "string" or Secret(name) or Secret(info.mapID) then return nil end
    key = Match(name, info.mapID)
    activityKey[activityID] = key
    return key or nil
end

function Listings.Activity(activityID)
    local activity = activityInfo[activityID]
    if activity then return activity end
    local info = C_LFGList.GetActivityInfoTable(activityID)
    if not info or Secret(info.fullName) or Secret(info.shortName) then return nil end
    activity = { name = info.fullName, short = info.shortName ~= "" and info.shortName or info.fullName,
        min = info.minLevelSuggestion, max = info.maxLevelSuggestion, size = info.maxNumPlayers }
    activityInfo[activityID] = activity
    return activity
end

local function Counts(entry, id)
    local counts = C_LFGList.GetSearchResultMemberCounts(id)
    local tanks, healers, damage = counts and counts.TANK, counts and counts.HEALER, counts and counts.DAMAGER
    if Secret(tanks) or Secret(healers) or Secret(damage) then tanks, healers, damage = nil, nil, nil end
    entry.tanks, entry.healers, entry.damage = tanks or 0, healers or 0, damage or 0
end

local function Fill(entry, id)
    local info = C_LFGList.GetSearchResultInfo(id)
    if not info then return false end
    local leader, count, age, delisted, activities = info.leaderName, info.numMembers, info.age, info.isDelisted,
        info.activityIDs
    if Secret(leader) or Secret(count) or Secret(age) or Secret(delisted) or Secret(activities) then return false end
    if type(count) ~= "number" or type(activities) ~= "table" then return false end
    local activity = activities[1]
    if Secret(activity) then return false end
    entry.id, entry.leader, entry.numMembers = id, type(leader) == "string" and leader or nil, count
    entry.age, entry.delisted, entry.party = type(age) == "number" and age or 0, delisted == true, info.partyGUID
    entry.mine = not Secret(info.hasSelf) and info.hasSelf == true
    entry.activity, entry.nActivities = activity, #activities
    entry.dungeon = activity and Listings.DungeonOf(activity) or nil
    Counts(entry, id)
    local members, n = entry.members, 0
    for m = 1, min(count, MEMBERS_READ) do
        local player = C_LFGList.GetSearchResultPlayerInfo(id, m)
        local roles = player and player.lfgRoles
        if roles and not (Secret(player.name) or Secret(player.level) or Secret(player.classFilename)
            or Secret(player.isLeader) or Secret(roles.tank) or Secret(roles.healer) or Secret(roles.dps)) then
            n = n + 1
            local member = members[n]
            if not member then
                member = {}
                members[n] = member
            end
            member.name, member.level, member.class = player.name, player.level, player.classFilename
            member.roles, member.leader = Card.Roles(roles.tank, roles.healer, roles.dps), player.isLeader == true
        end
    end
    entry.nMembers = n
    return true
end

function Listings.Read(force)
    if C_ChatInfo.InChatMessagingLockdown() then
        Listings.state, Listings.n, stale = "locked", 0, true
        return 0
    end
    if not (stale or force) then return Listings.n end
    local _, results = C_LFGList.GetFilteredSearchResults()
    local n = 0
    for i = 1, min(#results, MAX_ENTRIES) do
        local entry = entries[n + 1]
        if not entry then
            entry = { members = {} }
            entries[n + 1] = entry
        end
        if Fill(entry, results[i]) then n = n + 1 end
    end
    Listings.n, Listings.state, stale = n, "ready", false
    return n
end

local function OnEvent(_, event, id)
    if event == RECEIVED then
        stale, Listings.searched = true, true
        GF.Fire("listings", false)
        return
    end
    if event == FAILED then
        Listings.n, Listings.state, Listings.searched, stale = 0, "failed", true, false
        GF.Fire("listings", true)
        return
    end
    if stale or Secret(id) then return end
    for i = 1, Listings.n do
        local entry = entries[i]
        if entry.id == id then
            if C_ChatInfo.InChatMessagingLockdown() or not Fill(entry, id) then stale = true end
            GF.Fire("listing", entry)
            return
        end
    end
end

local function Sync()
    local want = GF.On()
    if want == on then return end
    on = want
    if want then
        if not frame then
            frame = CreateFrame("Frame")
            frame:SetScript("OnEvent", OnEvent)
        end
        for _, event in ipairs(EVENTS) do frame:RegisterEvent(event) end
    else
        frame:UnregisterAllEvents()
        Listings.n, Listings.state, Listings.searched, stale = 0, "none", false, true
    end
end

S.OnChange(function(key)
    if key == "enabled" then Sync() end
end)
hooksecurefunc(ns, "Apply", Sync)

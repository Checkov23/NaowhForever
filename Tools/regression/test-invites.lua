-- Run with Lua 5.1 from the repository root: the invite buttons' invites.
-- A Battle.net friend is found by BattleTag and invited on their Forever game account; one not on
-- Forever is named in chat; a character is invited by name; Invite All stops at a full party and
-- skips people already in it. Like the friends list, an account with no realm, or on the other
-- faction while cross-faction parties are off, cannot be invited.
local printed, bnInvites, nameInvites = {}, {}, {}
local subgroup, raid, members = 0, false, {}
local crossFaction = false

local friends = {
    { battleTag = "Robin#1234", games = { { isOnline = true, wowProjectID = 99, playerGuid = "g1", realmID = 5,
        factionName = "Alliance", gameAccountID = 11, characterName = "Robinpal" } } },
    { battleTag = "Dieman#5678", games = {
        { isOnline = true, wowProjectID = 1, playerGuid = "g2", realmID = 5, factionName = "Alliance",
            gameAccountID = 21, characterName = "Retail" },
        { isOnline = true, wowProjectID = 99, playerGuid = "g3", realmID = 5, factionName = "Alliance",
            gameAccountID = 22, characterName = "Dieman" } } },
    { battleTag = "Away#9999", games = { { isOnline = false, wowProjectID = 99, gameAccountID = 31 } } },
    { battleTag = "Alt#4242", games = {
        { isOnline = true, wowProjectID = 99, playerGuid = "g4", realmID = 0, factionName = "Alliance",
            gameAccountID = 41, characterName = "Loading" },
        { isOnline = true, wowProjectID = 99, playerGuid = "g5", realmID = 5, factionName = "Horde",
            gameAccountID = 42, characterName = "Hordealt" } } },
}

local settings = {}
local S = { Get = function(k) return settings[k] end, Set = function(k, v) settings[k] = v end }
local ns = { QoLSettings = S, UI = {}, THEME = {}, Print = function(m) printed[#printed + 1] = m end }
local env = setmetatable({
    NaowhForever = ns,
    WOW_PROJECT_ID = 99, MAX_PARTY_MEMBERS = 4, MAX_RAID_MEMBERS = 40,
    BNGetNumFriends = function() return #friends end,
    C_BattleNet = {
        GetFriendAccountInfo = function(i) return friends[i] end,
        GetFriendNumGameAccounts = function(i) return #friends[i].games end,
        GetFriendGameAccountInfo = function(i, j) return friends[i].games[j] end,
        InviteFriend = function(id) bnInvites[#bnInvites + 1] = id end,
    },
    C_PartyInfo = {
        InviteUnit = function(name) nameInvites[#nameInvites + 1] = name end,
        CanFormCrossFactionParties = function() return crossFaction end,
    },
    UnitFactionGroup = function() return "Alliance", "Alliance" end,
    IsInRaid = function() return raid end,
    GetNumGroupMembers = function() return subgroup + 1 end,
    GetNumSubgroupMembers = function() return subgroup end,
    UnitInParty = function(name) return members[name] end,
    UnitInRaid = function() return nil end,
}, { __index = _G })
env._G = env
local chunk = assert(loadfile("NaowhForever_QoL/Questing/Invites.lua"))
setfenv(chunk, env)
chunk()

local count = 0
local function Case(name, fn)
    printed, bnInvites, nameInvites = {}, {}, {}
    fn()
    count = count + 1
    print("PASS " .. name)
end

Case("a friend on Forever is invited on that game account", function()
    ns.InvitePerson({ name = "Robin", tag = "Robin#1234" })
    assert(bnInvites[1] == 11 and #printed == 0)
end)

Case("a friend on two games is invited on the Forever one", function()
    ns.InvitePerson({ name = "Dieman", tag = "Dieman#5678" })
    assert(bnInvites[1] == 22)
end)

Case("a friend not on Forever is named, not invited", function()
    ns.InvitePerson({ name = "Away", tag = "Away#9999" })
    ns.InvitePerson({ name = "Gone", tag = "Gone#0000" })
    assert(#bnInvites == 0 and printed[1] == "Away is not online on Forever." and printed[2]:find("^Gone"))
end)

Case("a character is invited by name", function()
    ns.InvitePerson({ name = "Gly", char = "Glyalith" })
    assert(nameInvites[1] == "Glyalith")
end)

Case("an alt on the other faction or with no realm is not invited", function()
    ns.InvitePerson({ name = "Alt", tag = "Alt#4242" })
    assert(#bnInvites == 0 and printed[1] == "Alt is not online on Forever.")
    settings.groupInvites = { { name = "Alt", tag = "Alt#4242" }, { name = "Gly", char = "Glyalith" } }
    subgroup = 3
    ns.InviteAll()
    assert(#bnInvites == 0 and nameInvites[1] == "Glyalith", "Invite All does not spend the last slot on the alt")
    subgroup = 0
end)

Case("with cross-faction parties the other faction is invited", function()
    crossFaction = true
    ns.InvitePerson({ name = "Alt", tag = "Alt#4242" })
    assert(bnInvites[1] == 42, "the realm-less account is still passed over")
    crossFaction = false
end)

Case("Invite All invites everyone while there is room", function()
    settings.groupInvites = { { name = "Robin", tag = "Robin#1234" }, { name = "Away", tag = "Away#9999" },
        { name = "Gly", char = "Glyalith" } }
    ns.InviteAll()
    assert(#bnInvites == 1 and nameInvites[1] == "Glyalith" and printed[1]:find("^Away"))
end)

Case("Invite All stops at a full party and skips members", function()
    settings.groupInvites = { { name = "Robin", tag = "Robin#1234" }, { name = "Dieman", tag = "Dieman#5678" },
        { name = "Gly", char = "Glyalith" }, { name = "Two", char = "Two" } }
    subgroup, members = 2, { Robinpal = true }
    ns.InviteAll()
    assert(#bnInvites == 1 and bnInvites[1] == 22, "Robin is in already, Dieman invited")
    assert(#nameInvites == 1 and nameInvites[1] == "Glyalith", "then the party is full")
    assert(printed[#printed] == "Your group is full.")
    subgroup, members = 0, {}
end)

Case("in a raid there is room to forty", function()
    settings.groupInvites = { { name = "Gly", char = "Glyalith" }, { name = "Two", char = "Two" } }
    raid, subgroup = true, 4
    ns.InviteAll()
    assert(#nameInvites == 2)
    raid, subgroup = false, 0
end)

print(count .. " invite checks passed")

-- Invites.lua: the people you keep an invite button for (ns.InvitePerson, ns.InviteAll, ns.ShowInviteEditor).
local ns = _G.NaowhForever

local S = ns.QoLSettings
local UI = ns.UI
local T = ns.THEME

local TAG_NAME = "^([^#]+)"
local NAME_MAX = 24
local HEAD_SIZE, LABEL_SIZE, NAME_SIZE, HEAD_TOP = 14, 12, 13, 16
local EDITOR_W, EDITOR_PAD, EDITOR_TOP, EDITOR_ROW, EDITOR_FOOT = 460, 20, 52, 30, 62
local EDITOR_NAME_W, EDITOR_GAP, EDITOR_BUTTON_W, EDITOR_BUTTON_H = 110, 8, 70, 22
local FOOT_BUTTON_W, FOOT_BUTTON_H, FOOT_Y = 110, 26, 16

local TEXT_TITLE = ns.L("Invite Buttons")
local TEXT_NONE = ns.L("No one yet. Add a Battle.net friend or a character name.")
local TEXT_ADD_FRIEND, TEXT_ADD_NAME, TEXT_CLOSE = ns.L("Add Friend"), ns.L("Add Name"), ns.L("Close")
local TEXT_RENAME, TEXT_REMOVE = ns.L("Rename"), ns.L("Remove")
local TEXT_ASK_NAME = ns.L("Invite which character?")
local TEXT_ASK_LABEL = ns.L("Text on the button")
local TEXT_FRIENDS = ns.L("Battle.net Friends")
local TEXT_NO_FRIENDS = ns.L("You have no Battle.net friends.")
local TEXT_ON_FOREVER = "%s (%s)"
local TEXT_WHO_FRIEND, TEXT_WHO_NAME = ns.L("Battle.net: %s"), ns.L("Character: %s")
local TEXT_OFFLINE = ns.L("%s is not online on Forever.")
local TEXT_FULL = ns.L("Your group is full.")

local function List()
    return S.Get("groupInvites") or {}
end

local function Copy()
    local out = {}
    for i, entry in ipairs(List()) do out[i] = { name = entry.name, tag = entry.tag, char = entry.char } end
    return out
end

local function ForeverAccount(friendIndex)
    local faction = not C_PartyInfo.CanFormCrossFactionParties() and UnitFactionGroup("player")
    for i = 1, C_BattleNet.GetFriendNumGameAccounts(friendIndex) do
        local game = C_BattleNet.GetFriendGameAccountInfo(friendIndex, i)
        if game and game.isOnline and game.wowProjectID == WOW_PROJECT_ID and game.playerGuid and game.realmID ~= 0
            and (not faction or game.factionName == faction) then
            return game
        end
    end
end

local function FindFriend(tag)
    for i = 1, BNGetNumFriends() do
        local account = C_BattleNet.GetFriendAccountInfo(i)
        if account and account.battleTag == tag then return ForeverAccount(i) end
    end
end

local function InGroup(name)
    return name ~= nil and (UnitInParty(name) or UnitInRaid(name)) and true or false
end

local function Invite(entry, skipMembers)
    if entry.char then
        if skipMembers and InGroup(entry.char) then return false end
        C_PartyInfo.InviteUnit(entry.char)
        return true
    end
    local game = FindFriend(entry.tag)
    if not game then
        ns.Print(TEXT_OFFLINE:format(entry.name))
        return false
    end
    if skipMembers and InGroup(game.characterName) then return false end
    C_BattleNet.InviteFriend(game.gameAccountID)
    return true
end

function ns.InvitePerson(entry)
    Invite(entry)
end

function ns.InviteAll()
    local room
    if IsInRaid() then
        room = MAX_RAID_MEMBERS - GetNumGroupMembers()
    else
        room = MAX_PARTY_MEMBERS - GetNumSubgroupMembers()
    end
    for _, entry in ipairs(List()) do
        if room <= 0 then
            ns.Print(TEXT_FULL)
            return
        end
        if Invite(entry, true) then room = room - 1 end
    end
end

function ns.InviteWho(entry)
    if entry.char then return TEXT_WHO_NAME:format(entry.char) end
    return TEXT_WHO_FRIEND:format(entry.tag)
end

local function Saved(list)
    S.Set("groupInvites", list)
    UI:RefreshPage(true)
    ns.ShowInviteEditor()
end

local function Add(entry)
    local list = Copy()
    for _, kept in ipairs(list) do
        if (entry.tag and kept.tag == entry.tag)
            or (entry.char and kept.char and strlower(kept.char) == strlower(entry.char)) then
            return ns.ShowInviteEditor()
        end
    end
    list[#list + 1] = entry
    Saved(list)
end

local function AddName()
    ns.PromptText(TEXT_ASK_NAME, "", NAME_MAX, function(name)
        Add({ name = name, char = name })
    end)
end

local function AddFriend(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(TEXT_FRIENDS)
        local count = BNGetNumFriends()
        for i = 1, count do
            local account = C_BattleNet.GetFriendAccountInfo(i)
            local tag = account and account.battleTag
            if tag then
                local name = tag:match(TAG_NAME) or tag
                local game = ForeverAccount(i)
                local text = game and game.characterName and TEXT_ON_FOREVER:format(name, game.characterName) or name
                root:CreateButton(text, function() Add({ name = name, tag = tag }) end)
            end
        end
        if count == 0 then root:CreateTitle(ns.Color("muted", TEXT_NO_FRIENDS)) end
    end)
end

local function Rename(index)
    ns.PromptText(TEXT_ASK_LABEL, List()[index].name, NAME_MAX, function(text)
        local list = Copy()
        list[index].name = text
        Saved(list)
    end)
end

local function Remove(index)
    local list = Copy()
    table.remove(list, index)
    Saved(list)
end

function ns.ShowInviteEditor()
    local list = List()
    local dimmer, panel = ns.MakeModal(EDITOR_W, EDITOR_TOP + math.max(1, #list) * EDITOR_ROW + EDITOR_FOOT,
        "inviteEditor")
    local head = UI.KeepFont(panel, "head", HEAD_SIZE, "OUTLINE")
    head:SetPoint("TOPLEFT", EDITOR_PAD, -HEAD_TOP)
    head:SetText(TEXT_TITLE)

    if #list == 0 then
        local none = UI.KeepFont(panel, "none", LABEL_SIZE, nil, T.muted)
        none:SetPoint("TOPLEFT", EDITOR_PAD, -EDITOR_TOP)
        none:SetText(TEXT_NONE)
    end
    for i, entry in ipairs(list) do
        local y = -(EDITOR_TOP + (i - 1) * EDITOR_ROW)
        local remove = UI.KeepButton(panel, "remove", TEXT_REMOVE, EDITOR_BUTTON_W, EDITOR_BUTTON_H,
            function() Remove(i) end)
        remove:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -EDITOR_PAD, y)
        local rename = UI.KeepButton(panel, "rename", TEXT_RENAME, EDITOR_BUTTON_W, EDITOR_BUTTON_H,
            function() Rename(i) end)
        rename:SetPoint("RIGHT", remove, "LEFT", -EDITOR_GAP, 0)
        local name = UI.KeepFont(panel, "name", NAME_SIZE)
        name:SetPoint("LEFT", panel, "TOPLEFT", EDITOR_PAD, y - EDITOR_BUTTON_H / 2)
        name:SetWidth(EDITOR_NAME_W)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        name:SetText(entry.name)
        local who = UI.KeepFont(panel, "who", LABEL_SIZE, nil, T.muted)
        who:SetPoint("LEFT", name, "RIGHT", EDITOR_GAP, 0)
        who:SetPoint("RIGHT", rename, "LEFT", -EDITOR_GAP, 0)
        who:SetJustifyH("LEFT")
        who:SetWordWrap(false)
        who:SetText(ns.InviteWho(entry))
    end

    local friend = UI.KeepButton(panel, "addFriend", TEXT_ADD_FRIEND, FOOT_BUTTON_W, FOOT_BUTTON_H, nil)
    friend._onClick = function() AddFriend(friend) end
    friend:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", EDITOR_PAD, FOOT_Y)
    UI.KeepButton(panel, "addName", TEXT_ADD_NAME, FOOT_BUTTON_W, FOOT_BUTTON_H, AddName)
        :SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", EDITOR_PAD + FOOT_BUTTON_W + EDITOR_GAP, FOOT_Y)
    UI.KeepButton(panel, "close", TEXT_CLOSE, FOOT_BUTTON_W, FOOT_BUTTON_H, function() dimmer:Hide() end)
        :SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -EDITOR_PAD, FOOT_Y)
    dimmer:Show()
end

-- Roster.lua: Naowh Forever's part of a player's tooltip in the Guild & Communities and Friends lists (ns.Shared.Roster).
local ns = _G.NaowhForever

local TIP_NAME = "NaowhForeverFriendTooltip"
local TIP_GAP = 2
local COMMUNITIES_ADDON = "Blizzard_Communities"
local FRIENDS_ADDON = "Blizzard_FriendsFrame"

local adders = {}
local hookedRows = setmetatable({}, { __mode = "k" })
local friend = {}
local friendTip, friendRow

local function Readable(value)
    return type(value) == "string" and not (issecretvalue and issecretvalue(value)) and value ~= ""
end

local function Run(tooltip, guid, info, row, anchor)
    local added = false
    for i = 1, #adders do
        if adders[i](tooltip, guid, info, row, anchor) then added = true end
    end
    return added
end

local function GuildEnter(row)
    local tooltip = GameTooltip
    if tooltip:IsForbidden() or not tooltip:IsShown() or not tooltip:IsOwned(row) then return end
    local info = row.memberInfo
    local guid = info and info.guid
    if not Readable(guid) then return end
    if Run(tooltip, guid, info, row, tooltip) then tooltip:Show() end
end

local function WowFriend(index, presence)
    local info = C_FriendList.GetFriendInfoByIndex(index)
    if not info then return false end
    friend.guid, friend.level = info.guid, info.level
    friend.presence = info.connected and presence.Online or presence.Offline
    return true
end

local function BattleNetFriend(index, presence)
    local account = C_BattleNet.GetFriendAccountInfo(index)
    local game = account and account.gameAccountInfo
    if not game or game.wowProjectID ~= WOW_PROJECT_ID then return false end
    friend.guid, friend.level = game.playerGuid, game.characterLevel
    friend.presence = game.isOnline and presence.Online or presence.Offline
    return true
end

local function FriendGUID(row)
    wipe(friend)
    local presence = Enum.ClubMemberPresence
    local found
    if row.buttonType == FRIENDS_BUTTON_TYPE_WOW then
        found = WowFriend(row.id, presence)
    elseif row.buttonType == FRIENDS_BUTTON_TYPE_BNET then
        found = BattleNetFriend(row.id, presence)
    end
    if found == false then return end
    return Readable(friend.guid) and friend.guid or nil
end

local function FriendShowing(row)
    return row ~= nil and row == friendRow and FriendsTooltip:IsShown() and FriendsTooltip.button == row
end

local function FriendTipUpdate(tip)
    if not FriendShowing(friendRow) then tip:Hide() end
end

local function FriendTip()
    if friendTip then return friendTip end
    friendTip = CreateFrame("GameTooltip", TIP_NAME, UIParent, "GameTooltipTemplate")
    _G[TIP_NAME .. "TextLeft1"]:SetFontObject(GameTooltipText)
    _G[TIP_NAME .. "TextRight1"]:SetFontObject(GameTooltipText)
    friendTip:SetScript("OnUpdate", FriendTipUpdate)
    return friendTip
end

local function FriendEnter(row)
    local frame = FriendsTooltip
    if not frame:IsShown() or frame.button ~= row then return end
    friendRow = row
    local tip = FriendTip()
    tip:SetOwner(frame, "ANCHOR_NONE")
    tip:ClearAllPoints()
    tip:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -TIP_GAP)
    local guid = FriendGUID(row)
    if guid and Run(tip, guid, friend, row, frame) then
        tip:SetMinimumWidth(frame:GetWidth())
        tip:Show()
    else
        tip:Hide()
    end
end

local function HookRow(row, onEnter)
    if hookedRows[row] then return end
    hookedRows[row] = true
    row:HookScript("OnEnter", onEnter)
end

local function GuildRow(row)
    HookRow(row, GuildEnter)
end

local function GuildRowInitialized(_, row)
    HookRow(row, GuildEnter)
end

local function HookGuild()
    local frame = CommunitiesFrame
    local scroll = frame and frame.MemberList and frame.MemberList.ScrollBox
    if not scroll then return end
    scroll:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, GuildRowInitialized, hookedRows)
    scroll:ForEachFrame(GuildRow)
end

local function FriendUpdated(button)
    HookRow(button, FriendEnter)
    if FriendsTooltip:IsShown() and FriendsTooltip.button == button then FriendEnter(button) end
end

local function HookFriends()
    if not FriendsFrame_UpdateFriendButton then return end
    hooksecurefunc("FriendsFrame_UpdateFriendButton", FriendUpdated)
end

local Roster = {}
ns.Shared.Roster = Roster

function Roster.Showing(row)
    if FriendShowing(row) then return true end
    return GameTooltip:IsShown() and GameTooltip:IsOwned(row)
end

function Roster.AddTooltip(fn)
    if ns.GamepadStandDown() then return end
    adders[#adders + 1] = fn
    if #adders > 1 then return end
    if CommunitiesFrame then
        HookGuild()
    else
        EventUtil.ContinueOnAddOnLoaded(COMMUNITIES_ADDON, HookGuild)
    end
    if FriendsFrame_UpdateFriendButton then
        HookFriends()
    else
        EventUtil.ContinueOnAddOnLoaded(FRIENDS_ADDON, HookFriends)
    end
end

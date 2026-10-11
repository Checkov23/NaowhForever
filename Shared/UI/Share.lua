-- Share.lua: sharing a line in chat or on a copy card, and a spot on the map with its pin link (ns.Shared.Parts).
local ns = _G.NaowhForever
local Parts = ns.Shared.Parts

local CHANNEL_FIELDS = 3
local TRADE_NAME = "^Trade"
local TEXT_SAY = ns.L("Say")
local TEXT_TRADE = ns.L("Trade")
local TEXT_PARTY = ns.L("Party")
local TEXT_RAID = ns.L("Raid")
local TEXT_GUILD = ns.L("Guild")
local TEXT_WHISPER = ns.L("Whisper ")
local TEXT_WHISPER_TARGET = ns.L("Whisper your target")
local TEXT_COPY = ns.L("Copy")
local TEXT_LOCKED = ns.L("Chat is locked right now.")
local TEXT_NO_TRADE = ns.L("Trade chat is only available in cities.")

local function PartyChat()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    return "PARTY"
end

local function TradeChannel()
    local list = { GetChannelList() }
    for i = 1, #list, CHANNEL_FIELDS do
        local name = list[i + 1]
        if type(name) == "string" and name:find(TRADE_NAME) then return list[i] end
    end
end

local function FriendlyTarget()
    if not (UnitIsPlayer("target") and not UnitIsUnit("target", "player") and UnitIsFriend("player", "target")) then
        return nil
    end
    return GetUnitName("target", true) or nil
end

Parts.PartyChat = PartyChat

function Parts.ShareMenu(owner, title, message, copyTitle, copyText, trade, icon, say)
    local locked = C_ChatInfo.InChatMessagingLockdown()
    local target = FriendlyTarget()
    local function Send(channel, to)
        local text = type(message) == "function" and message() or message
        C_ChatInfo.SendChatMessage(text, channel, nil, to)
    end
    local tradeChannel = trade and TradeChannel()
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(title)
        if say then
            root:CreateButton(TEXT_SAY, function() Send("SAY") end):SetEnabled(not locked and IsInInstance())
        end
        if trade then
            root:CreateButton(TEXT_TRADE, function() Send("CHANNEL", tradeChannel) end)
                :SetEnabled(not locked and tradeChannel ~= nil)
        end
        root:CreateButton(TEXT_PARTY, function() Send(PartyChat()) end):SetEnabled(not locked and IsInGroup())
        root:CreateButton(TEXT_RAID, function() Send("RAID") end):SetEnabled(not locked and IsInRaid())
        root:CreateButton(TEXT_GUILD, function() Send("GUILD") end):SetEnabled(not locked and IsInGuild())
        root:CreateButton(target and TEXT_WHISPER .. target or TEXT_WHISPER_TARGET, function()
            Send("WHISPER", target)
        end):SetEnabled(not locked and target ~= nil)
        root:CreateDivider()
        root:CreateButton(TEXT_COPY, function() ns.ShowCopyLine(copyTitle, copyText, icon) end)
        if locked then root:CreateTitle(ns.Color("muted", TEXT_LOCKED)) end
        if trade and not tradeChannel then root:CreateTitle(ns.Color("muted", TEXT_NO_TRADE)) end
    end)
end

function Parts.SharePlace(owner, title, name, map, x, y, note)
    local text = ns.WaypointText(name, map, x, y, note)
    Parts.ShareMenu(owner, title, function()
        local link = ns.WaypointLink(map, x, y)
        return link and text .. " " .. link or text
    end, name, text)
end

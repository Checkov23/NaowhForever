-- Sharing.lua: asking a group member with Naowh Forever to share a dungeon quest, and answering them (J.Sharing).
local ns = _G.NaowhForever

local J = ns.Journal
local S = J.Settings
local ID = J.C.QUEST.ID

local PREFIX = "NaowhJournal"
local VERSION = "1"
local GROUP_CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true }
local PARTY = { "party1", "party2", "party3", "party4" }
local WAIT = 5
local MAX_IDS = 8
local COOLDOWN = 3
local ASK_LIMIT, ASK_WINDOW = 4, 10
local ASK_PRINT_GAP, ASKERS_MAX = 30, 40
local MESSAGE_PARTS, ANSWER_PARTS = 5, 2
local ASK, ANSWER = "A", "R"
local SHARED, NOT_ON, NOT_PUSHABLE, WAIT_CODE = "S", "N", "P", "W"
local ASK_FORMAT = "%s A %s %s %s"
local ANSWER_FORMAT = "%s R %s %s %d %s"
local SPACE, COMMA = " ", ","
local EACH_ID = "[^,]+"
local GUID_PATTERN = "^Player%-%d+%-%x+$"
local ID_PATTERN = "^%d%d?%d?%d?%d?%d?%d?$"
local NAME_PART = "^([^%-]+)"

local TEXT_NO_ANSWER = ns.L("%s did not answer: they need Naowh Forever with its Dungeon Journal on.")
local TEXT_NO_ONE = ns.L("No one else in your group can share %s.")
local TEXT_LOCKED = ns.L("The game is not passing addon messages right now (in an encounter): ask again after it.")
local TEXT_ASKING = ns.L("Asking %s to share %s with you...")
local TEXT_STILL_WAITING = ns.L("Still waiting on %s for %s.")
local TEXT_ASKED_NOT_ON = ns.L("%s asked you to share a quest you are not on.")
local TEXT_ASKED_NOT_PUSHABLE = ns.L("%s asked you to share %s, but the game does not let it be shared.")
local TEXT_ASKED_TOO_SOON = ns.L("%s asked you to share %s: you shared one a moment ago.")
local TEXT_ASKED_SHARED = ns.L("%s asked you to share %s: shared it with your group.")
local TEXT_A_QUEST = ns.L("a quest")
local ANSWERS = {
    S = ns.L("%s shared %s with you: accept it in the window the game opens."),
    N = ns.L("%s is not on %s any more."),
    P = ns.L("%s cannot share %s: the game does not let it be shared."),
    W = ns.L("%s shared a quest a moment ago: ask again in a few seconds."),
}

local frame, prefixed
local lastShared = 0
local askers, askerCount = {}, 0
local asking = { units = {}, names = {} }
local generation = 0
local AskNext

local function Channel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function Short(sender)
    return sender:match(NAME_PART) or sender
end

local function Send(text)
    local channel = Channel()
    if not channel or C_ChatInfo.InChatMessagingLockdown() then return false end
    local result = C_ChatInfo.SendAddonMessage(PREFIX, text, channel)
    return result == nil or result == Enum.SendAddonMessageResult.Success
end

local function Stop()
    generation = generation + 1
    asking.active = false
end

local function Timeout(sent)
    if sent ~= generation or not asking.active then return end
    ns.Print(TEXT_NO_ANSWER:format(asking.names[asking.at]))
    AskNext()
end

function AskNext()
    asking.at = asking.at + 1
    local unit = asking.units[asking.at]
    if not unit then
        if asking.at > 1 then ns.Print(TEXT_NO_ONE:format(asking.name)) end
        return Stop()
    end
    local guid = UnitGUID(unit)
    if not guid or issecretvalue(guid) then return AskNext() end
    asking.guid = guid
    local mine = UnitGUID("player")
    if not mine or not Send(ASK_FORMAT:format(VERSION, guid, mine, asking.ids)) then
        ns.Print(TEXT_LOCKED)
        return Stop()
    end
    ns.Print(TEXT_ASKING:format(asking.names[asking.at], asking.name))
    generation = generation + 1
    local sent = generation
    C_Timer.After(WAIT, function() Timeout(sent) end)
end

local function GatherMembers(quest)
    wipe(asking.units)
    wipe(asking.names)
    for i = 1, math.min(GetNumSubgroupMembers(), #PARTY) do
        local unit = PARTY[i]
        if J.Quests.UnitOnQuest(unit, quest, nil) then
            local name = UnitName(unit)
            asking.units[#asking.units + 1] = unit
            asking.names[#asking.names + 1] = name and not issecretvalue(name) and name or unit
        end
    end
end

local function AskedIDs(quest)
    local ids = tostring(quest[ID])
    for i = 1, math.min(quest.alt and #quest.alt or 0, MAX_IDS - 1) do ids = ids .. COMMA .. quest.alt[i] end
    return ids
end

local function OnAnswer(from, code)
    if not asking.active or from ~= asking.guid or not ANSWERS[code] then return end
    ns.Print(ANSWERS[code]:format(asking.names[asking.at], asking.name))
    if code == SHARED or code == WAIT_CODE then return Stop() end
    generation = generation + 1
    AskNext()
end

local function Asker(asker, now)
    local a = askers[asker]
    if not a then
        if askerCount >= ASKERS_MAX then
            wipe(askers)
            askerCount = 0
        end
        a = { window = now, count = 0 }
        askers[asker], askerCount = a, askerCount + 1
    end
    if now - a.window >= ASK_WINDOW then a.window, a.count = now, 0 end
    return a
end

local function AskPrint(a, text, who, title)
    local now = GetTime()
    if a.printed and now - a.printed < ASK_PRINT_GAP then return end
    a.printed = now
    ns.Print(text:format(who, title))
end

local function FirstInLog(ids)
    local tried = 0
    for id in ids:gmatch(EACH_ID) do
        tried = tried + 1
        if tried > MAX_IDS then return end
        if id:find(ID_PATTERN) then
            local index = C_QuestLog.GetLogIndexForQuestID(tonumber(id))
            if index then return tonumber(id), index end
        end
    end
end

local function Answer(a, who, found, index)
    if not found then
        AskPrint(a, TEXT_ASKED_NOT_ON, who)
        return NOT_ON
    end
    local title = C_QuestLog.GetTitleForQuestID(found) or TEXT_A_QUEST
    if not C_QuestLog.IsPushableQuest(found) then
        AskPrint(a, TEXT_ASKED_NOT_PUSHABLE, who, title)
        return NOT_PUSHABLE
    end
    if GetTime() - lastShared < COOLDOWN then
        AskPrint(a, TEXT_ASKED_TOO_SOON, who, title)
        return WAIT_CODE
    end
    lastShared = GetTime()
    QuestLogPushQuest(index)
    AskPrint(a, TEXT_ASKED_SHARED, who, title)
    return SHARED
end

local function OnAsk(asker, ids, sender)
    if not asker:find(GUID_PATTERN) then return end
    local a = Asker(asker, GetTime())
    if a.count >= ASK_LIMIT then return end
    a.count = a.count + 1
    local found, index = FirstInLog(ids)
    local code = Answer(a, Short(sender), found, index)
    Send(ANSWER_FORMAT:format(VERSION, asker, UnitGUID("player"), found or 0, code))
end

local function OnMessage(text, sender, channel)
    local version, kind, to, from, rest = strsplit(SPACE, text, MESSAGE_PARTS)
    if version ~= VERSION or not rest or to ~= UnitGUID("player") then return end
    if not (from and from:find(GUID_PATTERN) and ns.SenderIs(sender, channel, from)) then return end
    if kind == ASK then
        OnAsk(from, rest, sender)
    elseif kind == ANSWER then
        local _, code = strsplit(SPACE, rest, ANSWER_PARTS)
        OnAnswer(from, code)
    end
end

local Sharing = {}
J.Sharing = Sharing

function Sharing.On()
    return S.Get("enabled") == true and S.Get("shareRequests") == true
end

function Sharing.Ask(entry)
    if entry.inLog or not IsInGroup() or not Sharing.On() then return end
    if asking.active then
        ns.Print(TEXT_STILL_WAITING:format(asking.names[asking.at], asking.name))
        return
    end
    local quest = entry.quest
    GatherMembers(quest)
    if #asking.units == 0 then return end
    asking.active, asking.name, asking.ids, asking.at = true, entry.name, AskedIDs(quest), 0
    AskNext()
end

local function Listen()
    if IsInGroup() then
        frame:RegisterEvent("CHAT_MSG_ADDON")
        return
    end
    frame:UnregisterEvent("CHAT_MSG_ADDON")
    Stop()
end

local function OnEvent(_, event, prefix, text, channel, sender)
    if event == "GROUP_ROSTER_UPDATE" then return Listen() end
    if issecretvalue(prefix) or prefix ~= PREFIX then return end
    if issecretvalue(text) or issecretvalue(channel) or issecretvalue(sender) then return end
    if GROUP_CHANNELS[channel] then OnMessage(text, sender, channel) end
end

local function Sync()
    local on = Sharing.On()
    if not (on or frame) then return end
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", OnEvent)
    end
    if not on then
        frame:UnregisterAllEvents()
        Stop()
        return
    end
    if not prefixed then
        prefixed = true
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    Listen()
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "shareRequests" then Sync() end
end

S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Sync)

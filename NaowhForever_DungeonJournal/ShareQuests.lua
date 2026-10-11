-- ShareQuests.lua: sharing a dungeon's quests in your log with your group, one at a time (J.Sharing.ShareAll).
local ns = _G.NaowhForever

local J = ns.Journal
local Sharing = J.Sharing

local SENT_WAIT, ANSWER_WAIT, RETRIES = 2, 30, 2
local PUSH_RESULT = "^ERR_QUEST_PUSH_.+_S$"
local PUSH_SENT = "ERR_QUEST_PUSH_SUCCESS_S"
local MESSAGE_EVENTS = { "CHAT_MSG_SYSTEM", "UI_INFO_MESSAGE", "UI_ERROR_MESSAGE" }
local NAME_MARK = "\001"
local FORMAT_NAME = "%%%d?%$?s"
local MAGIC = "[%^%$%(%)%%%.%[%]%*%+%-%?]"
local CAPTURE = "(.+)"

local TEXT_BUSY = ns.L("Someone was busy for %s; sharing it again after the rest.")
local TEXT_NO_GROUP = ns.L("Stopped sharing: you are not in a group.")
local TEXT_DONE = ns.L("Done sharing.")
local TEXT_AFTER_COMBAT = ns.L("Sharing carries on after combat.")
local TEXT_JOIN = ns.L("Join a group to share quests.")
local TEXT_NONE = ns.L("None of your quests for this dungeon can be shared.")
local TEXT_ALREADY = ns.L("Those quests are being shared already.")
local TEXT_SHARING = ns.L("Sharing %s. Each one waits until your group has answered the one before.")
local TEXT_LIST = ", "

local EMPTY = {}
local shareQueue, sharing = {}, nil
local shareFrame
local sentPattern, busyPattern, answerPatterns
local NextShare

local function QuestName(id)
    return C_QuestLog.GetTitleForQuestID(id) or tostring(id)
end

local function Pattern(fmt)
    fmt = fmt:gsub(FORMAT_NAME, NAME_MARK):gsub(MAGIC, "%%%0")
    return "^" .. fmt:gsub(NAME_MARK, CAPTURE) .. "$"
end

local function PushPatterns()
    if answerPatterns then return end
    answerPatterns = {}
    for key, value in pairs(_G) do
        if type(key) == "string" and type(value) == "string" and key:find(PUSH_RESULT) and key ~= PUSH_SENT then
            answerPatterns[#answerPatterns + 1] = Pattern(value)
        end
    end
    sentPattern = ERR_QUEST_PUSH_SUCCESS_S and Pattern(ERR_QUEST_PUSH_SUCCESS_S)
    busyPattern = ERR_QUEST_PUSH_BUSY_S and Pattern(ERR_QUEST_PUSH_BUSY_S)
end

local function FinishShare()
    local cur = sharing
    sharing = nil
    if cur.timer then cur.timer:Cancel() end
    if cur.busy and cur.tries < RETRIES then
        cur.tries, cur.busy = cur.tries + 1, nil
        shareQueue[#shareQueue + 1] = cur
        ns.Print(TEXT_BUSY:format(QuestName(cur.id)))
    end
    NextShare()
end

local function WaitForAnswers(cur)
    cur.timer = C_Timer.NewTimer(SENT_WAIT, function()
        if sharing ~= cur then return end
        if next(cur.sent) == nil then return FinishShare() end
        cur.timer = C_Timer.NewTimer(ANSWER_WAIT - SENT_WAIT, function()
            if sharing == cur then FinishShare() end
        end)
    end)
end

local function StopSharing(cur)
    ns.Print(cur and TEXT_NO_GROUP or TEXT_DONE)
    wipe(shareQueue)
    shareFrame:UnregisterAllEvents()
end

function NextShare()
    local cur = table.remove(shareQueue, 1)
    if not (cur and IsInGroup()) then return StopSharing(cur) end
    if InCombatLockdown() then
        table.insert(shareQueue, 1, cur)
        shareFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        ns.Print(TEXT_AFTER_COMBAT)
        return
    end
    local index = C_QuestLog.GetLogIndexForQuestID(cur.id)
    if not index then return NextShare() end
    QuestLogPushQuest(index)
    sharing, cur.sent, cur.answered = cur, {}, {}
    WaitForAnswers(cur)
end

local function AllAnswered(cur)
    for sent in pairs(cur.sent) do
        if not cur.answered[sent] then return false end
    end
    return next(cur.sent) ~= nil
end

local function OnAnswer(cur, msg)
    for _, pattern in ipairs(answerPatterns) do
        local name = msg:match(pattern)
        if name then
            cur.answered[name] = true
            if busyPattern and msg:match(busyPattern) then cur.busy = true end
            if AllAnswered(cur) then FinishShare() end
            return
        end
    end
end

local function OnShareEvent(_, event, a, b)
    if event == "PLAYER_REGEN_ENABLED" then
        shareFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if not sharing then NextShare() end
        return
    end
    local cur, msg = sharing, event == "CHAT_MSG_SYSTEM" and a or b
    if not cur or type(msg) ~= "string" or issecretvalue(msg) then return end
    local name = sentPattern and msg:match(sentPattern)
    if name then
        cur.sent[name] = true
        return
    end
    OnAnswer(cur, msg)
end

local function Queue(ids)
    local queued = { [sharing and sharing.id or 0] = true }
    for _, item in ipairs(shareQueue) do queued[item.id] = true end
    local names = {}
    for _, id in ipairs(ids) do
        if not queued[id] then
            shareQueue[#shareQueue + 1] = { id = id, tries = 0 }
            names[#names + 1] = QuestName(id)
        end
    end
    return names
end

local function Listen()
    PushPatterns()
    if not shareFrame then
        shareFrame = CreateFrame("Frame")
        shareFrame:SetScript("OnEvent", OnShareEvent)
    end
    for _, event in ipairs(MESSAGE_EVENTS) do shareFrame:RegisterEvent(event) end
end

function Sharing.Shareable(dungeon)
    local ids = {}
    for _, quest in ipairs(dungeon.quests and dungeon.quests.quests or EMPTY) do
        local id = J.Quests.LoggedID(quest)
        if id and C_QuestLog.IsPushableQuest(id) then ids[#ids + 1] = id end
    end
    return ids
end

function Sharing.ShareAll(dungeon)
    if not IsInGroup() then
        ns.Print(TEXT_JOIN)
        return
    end
    local ids = Sharing.Shareable(dungeon)
    if #ids == 0 then
        ns.Print(TEXT_NONE)
        return
    end
    local names = Queue(ids)
    if #names == 0 then
        ns.Print(TEXT_ALREADY)
        return
    end
    ns.Print(TEXT_SHARING:format(table.concat(names, TEXT_LIST)))
    Listen()
    if not sharing then NextShare() end
end

-- Comms.lua: the Group Finder's addon whispers (ns.GroupFinder.Comms): card requests, applications and their answers, sent through a queue kept to the game's limits.
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local Card = GF.Card
local S = GF.Settings

local lower, match, gsub, find, sub = string.lower, string.match, string.gsub, string.find, string.sub
local remove, max = table.remove, math.max

local PREFIX = GF.PREFIX
local WHISPER = "WHISPER"
local SYSTEM = "CHAT_MSG_SYSTEM"
local BURST, RATE = 10, 1
local QUEUE_MAX = 30
local LOCKDOWN_RETRY = 2
local PING_WAIT = 10
local APP_TTL = 600
local SENDER_WINDOW, SENDER_MAX, SENDERS_MAX = 10, 8, 200
local ANSWER_GAP, ANSWERS_MAX, ANSWERS_WINDOW, ASKERS_MAX = 30, 5, 10, 40
local NOT_FOUND_WINDOW, WHISPERED_MAX = 10, 40
local MAX_PINGS, MAX_SENT, MAX_APPLICANTS, MAX_CARDS = 20, 10, 40, 100
local RESULT = Enum.SendAddonMessageResult
local LISTS = {}
local CARD_LISTS = { "kills", "have", "need" }

local Comms = {
    BURST = BURST, RATE = RATE, QUEUE_MAX = QUEUE_MAX, PING_WAIT = PING_WAIT, APP_TTL = APP_TTL,
    SENDER_MAX = SENDER_MAX, SENDER_WINDOW = SENDER_WINDOW, NOT_FOUND_WINDOW = NOT_FOUND_WINDOW,
    ANSWER_GAP = ANSWER_GAP, ANSWERS_MAX = ANSWERS_MAX, ANSWERS_WINDOW = ANSWERS_WINDOW,
    MAX_APPLICANTS = MAX_APPLICANTS,
    pings = {}, sent = {}, applicants = {},
    dropped = { self = 0, ignored = 0, flood = 0, malformed = 0, secret = 0, unasked = 0, full = 0,
        unlisted = 0, answered = 0 },
}
GF.Comms = Comms

local pings, sent, applicants = Comms.pings, Comms.sent, Comms.applicants
LISTS[1], LISTS[2], LISTS[3] = pings, sent, applicants
local sparePings, spareSent, spareApplicants = {}, {}, {}
local on, frame, prefixed, ownKey = false, nil, false, nil
local qTarget, qText = {}, {}
local tokens, refilled, drainAt = BURST, 0, nil
local whispered, nWhispered = {}, 0
local senderCount, senderStart, senderN = {}, {}, 0
local askers, nAskers = {}, 0
local windowAt, answeredCount = -ANSWERS_WINDOW, 0
local cards, nCards = {}, 0
local nextId = 0
local sweepGen, sweepAt = 0, nil
local incoming = Card.New()
local incomingGroup = { min = 0, tanks = 0, healers = 0, damage = 0, note = "" }
local notFound

local function Key(name)
    return lower(Ambiguate(name, "none"))
end
Comms.Key = Key

function Comms.IsMe(name)
    return Key(name) == ownKey
end

local function NamePart(key)
    local dash = find(key, "-", 1, true)
    return dash and sub(key, 1, dash - 1) or key, dash ~= nil
end

local function SameName(a, b)
    local ka, kb = Key(a), Key(b)
    if ka == kb then return true end
    local na, realmA = NamePart(ka)
    local nb, realmB = NamePart(kb)
    return not (realmA and realmB) and na == nb
end

local function Drop(reason)
    Comms.dropped[reason] = Comms.dropped[reason] + 1
end

local function NextId()
    nextId = nextId % Card.ID_MAX + 1
    return nextId
end

local function Take(list, spare)
    local record = remove(spare) or {}
    list[#list + 1] = record
    return record
end

local function Release(list, i, spare)
    spare[#spare + 1] = remove(list, i)
end

local function Find(list, id, name)
    for i = 1, #list do
        local record = list[i]
        if (not id or record.id == id) and SameName(record.name, name) then return record, i end
    end
end

local Sweep

local function Earliest()
    local at
    for l = 1, #LISTS do
        local list = LISTS[l]
        for i = 1, #list do
            local deadline = list[i].deadline
            if not at or deadline < at then at = deadline end
        end
    end
    return at
end

local function ScheduleSweep()
    local at = Earliest()
    if not at then
        sweepAt = nil
        sweepGen = sweepGen + 1
        return
    end
    if sweepAt and sweepAt <= at then return end
    sweepGen = sweepGen + 1
    sweepAt = at
    local gen = sweepGen
    C_Timer.After(max(0, at - GetTime()), function() Sweep(gen) end)
end

local function Expire(list, spare, now, what)
    for i = #list, 1, -1 do
        local record = list[i]
        if record.deadline <= now then
            GF.Fire(what, record)
            Release(list, i, spare)
        end
    end
end

function Sweep(gen)
    if gen ~= sweepGen or not on then return false end
    sweepAt = nil
    local now = GetTime()
    Expire(pings, sparePings, now, "noreply")
    Expire(sent, spareSent, now, "expired")
    Expire(applicants, spareApplicants, now, "applicantExpired")
    ScheduleSweep()
    return true
end
Comms.Sweep = Sweep

local Drain

local function DrainLater(delay)
    local at = GetTime() + delay
    if drainAt and drainAt <= at then return end
    drainAt = at
    C_Timer.After(delay, Drain)
end

local function Whispered(target)
    local key = Key(target)
    if not whispered[key] then
        if nWhispered >= WHISPERED_MAX then
            wipe(whispered)
            nWhispered = 0
        end
        nWhispered = nWhispered + 1
    end
    whispered[key] = GetTime()
end

local function Offline(name)
    for i = #pings, 1, -1 do
        local ping = pings[i]
        if SameName(ping.name, name) then
            GF.Fire("offline", ping)
            Release(pings, i, sparePings)
        end
    end
end

function Drain()
    drainAt = nil
    if not on then return end
    while #qText > 0 do
        if C_ChatInfo.InChatMessagingLockdown() then return DrainLater(LOCKDOWN_RETRY) end
        local now = GetTime()
        tokens = tokens + (now - refilled) * RATE
        if tokens > BURST then tokens = BURST end
        refilled = now
        if tokens < 1 then return DrainLater((1 - tokens) / RATE) end
        local target = qTarget[1]
        Whispered(target)
        local result = C_ChatInfo.SendAddonMessage(PREFIX, qText[1], WHISPER, target)
        if result == RESULT.AddonMessageThrottle or result == RESULT.ChannelThrottle then
            tokens = 0
            return DrainLater(1 / RATE)
        end
        if result == RESULT.AddOnMessageLockdown then return DrainLater(LOCKDOWN_RETRY) end
        remove(qTarget, 1)
        remove(qText, 1)
        tokens = tokens - 1
        if result == RESULT.TargetOffline then Offline(target) end
    end
end

local function Send(target, text)
    if not (on and target and text) then return false end
    for i = 1, #qText do
        if qTarget[i] == target and qText[i] == text then return true end
    end
    if #qText >= QUEUE_MAX then return false end
    qTarget[#qTarget + 1] = target
    qText[#qText + 1] = text
    if not drainAt then Drain() end
    return true
end
Comms.Send = Send

function Comms.Queued()
    return #qText
end

function Comms.Ping(name, dungeonKey)
    if not on then return nil, "off" end
    if #pings >= MAX_PINGS then return nil, "busy" end
    if #qText >= QUEUE_MAX then return nil, "queue" end
    local nonce = NextId()
    local now = GetTime()
    local ping = Take(pings, sparePings)
    ping.id, ping.name, ping.dungeon, ping.sentAt, ping.deadline = nonce, name, dungeonKey, now, now + PING_WAIT
    Send(name, Card.Ask(nonce, dungeonKey))
    ScheduleSweep()
    return nonce
end

function Comms.Apply(name, dungeonKey, roles, note)
    if not on then return nil, "off" end
    if #sent >= MAX_SENT then return nil, "busy" end
    local id = NextId()
    local text = Card.Application(id, Card.Mine(dungeonKey, roles), Card.CleanNote(note))
    if not Send(name, text) then return nil, "queue" end
    local record = Take(sent, spareSent)
    record.id, record.name, record.dungeon = id, name, dungeonKey
    record.deadline, record.acked, record.declined = GetTime() + APP_TTL, false, false
    ScheduleSweep()
    return id
end

function Comms.Withdraw(id)
    for i = 1, #sent do
        local record = sent[i]
        if record.id == id then
            Send(record.name, Card.Short("X", id))
            Release(sent, i, spareSent)
            ScheduleSweep()
            return true
        end
    end
    return false
end

function Comms.SentTo(name)
    return (Find(sent, nil, name))
end

function Comms.Decline(name)
    local record, i = Find(applicants, nil, name)
    if not record then return false end
    Send(record.name, Card.Short("D", record.id))
    Release(applicants, i, spareApplicants)
    ScheduleSweep()
    return true
end

local function Copy(from, to)
    to.class, to.level, to.roles, to.spec = from.class, from.level, from.roles, from.spec
    to.score, to.bisHave, to.bisTotal, to.dungeon = from.score, from.bisHave, from.bisTotal, from.dungeon
    to.hasKills, to.hasQuests = from.hasKills, from.hasQuests
    to.nKills, to.nHave, to.nNeed = from.nKills, from.nHave, from.nNeed
    for l = 1, #CARD_LISTS do
        local a, b = from[CARD_LISTS[l]], to[CARD_LISTS[l]]
        for i = 1, #a do b[i] = a[i] end
        for i = #b, #a + 1, -1 do b[i] = nil end
    end
    return to
end
Comms.Copy = Copy

local function Keep(name, card)
    local key = Key(name)
    local kept = cards[key]
    if not kept then
        if nCards >= MAX_CARDS then
            wipe(cards)
            nCards = 0
        end
        kept = Card.New()
        cards[key] = kept
        nCards = nCards + 1
    end
    return Copy(card, kept)
end

function Comms.CardOf(name)
    return cards[Key(name)]
end

local function MayAnswer(key, now)
    if now - windowAt >= ANSWERS_WINDOW then windowAt, answeredCount = now, 0 end
    if answeredCount >= ANSWERS_MAX then return false end
    local last = askers[key]
    if last and now - last < ANSWER_GAP then return false end
    if not last then
        if nAskers >= ASKERS_MAX then
            wipe(askers)
            nAskers = 0
        end
        nAskers = nAskers + 1
    end
    askers[key] = now
    answeredCount = answeredCount + 1
    return true
end

local Handle = {}

function Handle.Q(sender, id, dungeonKey, now)
    if not C_LFGList.HasActiveEntryInfo() then return Drop("unlisted") end
    if not MayAnswer(Key(sender), now) then return Drop("answered") end
    Send(sender, Card.Reply(id, Card.Mine(dungeonKey), GF.Group.Info()))
end

local function KeepGroup(card, group)
    if not group then
        card.group = nil
        return
    end
    local kept = card.group or {}
    kept.min, kept.tanks, kept.healers, kept.damage = group.min, group.tanks, group.healers, group.damage
    kept.note = group.note
    card.group = kept
end

local function Answered(sender, id, now, group)
    local ping, i = Find(pings, id, sender)
    if not ping then return Drop("unasked") end
    local card = Keep(sender, incoming)
    KeepGroup(card, group)
    GF.Fire("card", sender, card, ping, now - ping.sentAt)
    Release(pings, i, sparePings)
    ScheduleSweep()
end

function Handle.C(sender, id, _, now)
    Answered(sender, id, now, nil)
end

function Handle.L(sender, id, note, now)
    incomingGroup.note = note or ""
    Answered(sender, id, now, incomingGroup)
end

function Handle.A(sender, id, note, now)
    if not C_LFGList.HasActiveEntryInfo() then return Drop("unlisted") end
    local record = Find(applicants, nil, sender)
    if not record then
        if #applicants >= MAX_APPLICANTS then return Drop("full") end
        record = Take(applicants, spareApplicants)
        record.card = record.card or Card.New()
    end
    Copy(incoming, record.card)
    record.id, record.name, record.note = id, sender, note
    record.at, record.deadline = now, now + APP_TTL
    Send(sender, Card.Short("K", id))
    ScheduleSweep()
    GF.Fire("applicant", record)
end

function Handle.K(sender, id)
    local record = Find(sent, id, sender)
    if not record then return Drop("unasked") end
    record.acked = true
    GF.Fire("received", record)
end

function Handle.X(sender, id)
    local record, i = Find(applicants, id, sender)
    if not record then return Drop("unasked") end
    GF.Fire("withdrawn", record)
    Release(applicants, i, spareApplicants)
    ScheduleSweep()
end

function Handle.D(sender, id)
    local record = Find(sent, id, sender)
    if not record then return Drop("unasked") end
    record.declined = true
    GF.Fire("declined", record)
end

local function Allowed(key, now)
    local start = senderStart[key]
    if not start or now - start > SENDER_WINDOW then
        if not start then
            senderN = senderN + 1
            if senderN > SENDERS_MAX then
                wipe(senderStart)
                wipe(senderCount)
                senderN = 1
            end
        end
        senderStart[key], senderCount[key] = now, 1
        return true
    end
    local n = senderCount[key] + 1
    senderCount[key] = n
    return n <= SENDER_MAX
end

local function OnMessage(text, sender)
    local key = Key(sender)
    if key == ownKey then return Drop("self") end
    if C_FriendList.IsIgnored(Ambiguate(sender, "none")) then return Drop("ignored") end
    local now = GetTime()
    if not Allowed(key, now) then return Drop("flood") end
    local kind, id, extra = Card.Decode(text, incoming, incomingGroup)
    if not kind then return Drop("malformed") end
    Handle[kind](sender, id, extra, now)
end
Comms.OnMessage = OnMessage

local function OnEvent(_, _, prefix, text, channel, sender)
    if issecretvalue(prefix) or prefix ~= PREFIX then return end
    if issecretvalue(text) or issecretvalue(channel) or issecretvalue(sender) then return Drop("secret") end
    if channel ~= WHISPER or type(text) ~= "string" or type(sender) ~= "string" or sender == "" then return end
    OnMessage(text, sender)
end

local function NotFoundPattern()
    if notFound then return notFound end
    local fmt = gsub(gsub(ERR_CHAT_PLAYER_NOT_FOUND_S, "%%%d?%$?s", "\001"), "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    notFound = "^" .. gsub(fmt, "\001", "(.+)") .. "$"
    return notFound
end

local function Filter(_, _, msg)
    if not on or type(msg) ~= "string" or issecretvalue(msg) then return false end
    local name = match(msg, NotFoundPattern())
    if not name then return false end
    local at = whispered[Key(name)]
    if not at or GetTime() - at > NOT_FOUND_WINDOW then return false end
    Offline(name)
    return true
end
Comms.Filter = Filter

local function Reset()
    wipe(qTarget)
    wipe(qText)
    tokens, drainAt = BURST, nil
    for i = #pings, 1, -1 do Release(pings, i, sparePings) end
    for i = #sent, 1, -1 do Release(sent, i, spareSent) end
    for i = #applicants, 1, -1 do Release(applicants, i, spareApplicants) end
    wipe(whispered)
    nWhispered = 0
    wipe(senderStart)
    wipe(senderCount)
    senderN = 0
    wipe(askers)
    nAskers, windowAt, answeredCount = 0, -ANSWERS_WINDOW, 0
    wipe(cards)
    nCards = 0
    sweepGen, sweepAt = sweepGen + 1, nil
end

function Comms.On()
    return on
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
        if not prefixed then
            prefixed = true
            C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        end
        ownKey = Key(GetUnitName("player", true))
        frame:RegisterEvent("CHAT_MSG_ADDON")
        ChatFrameUtil.AddMessageEventFilter(SYSTEM, Filter)
    else
        frame:UnregisterAllEvents()
        ChatFrameUtil.RemoveMessageEventFilter(SYSTEM, Filter)
        Reset()
    end
end

S.OnChange(function(key)
    if key == "enabled" then Sync() end
end)
hooksecurefunc(ns, "Apply", Sync)

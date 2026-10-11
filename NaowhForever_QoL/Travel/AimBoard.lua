-- AimBoard.lua: the Aim Trainer's leaderboard (ns.AimBoard), your bests shared and others' kept.
local ns = _G.NaowhForever

local GetTime, InCombatLockdown = GetTime, InCombatLockdown
local floor, random, tonumber, tostring, pairs, type = math.floor, math.random, tonumber, tostring, pairs, type

local S = ns.QoLSettings
local T = ns.THEME
local Rules = ns.AimRules
local Parts, St = ns.Shared.Parts, ns.Shared.Style
local BORDER_RGB = St.BORDER_RGB

local PREFIX, VERSION = "NaowhAim", "2"
local VERSION_PATTERN = "^(%d+) "
local GUID_PATTERN = ns.QoLConstants.GUID_PATTERN
local REQUEST_PATTERN = "^%d+ R (Player%-%d+%-%x+)$"
local BEST_PATTERN = "^%d+ B (Player%-%d+%-%x+) (%l+) (%d+) ([%d%-]+) (%u+) (%d+)$"
local NO_ACCURACY = "-"
local REQUEST = " R "
local BEST = "%s B %s %s %d %s %s %d"
local GUILD_CHANNEL = "GUILD"
local MAX_LENGTH, MAX_GUID_LENGTH, MAX_NAME_LENGTH, MAX_CLASS_LENGTH, MAX_ACCURACY = 112, 40, 40, 12, 100
local MAX_ENTRIES = 200
local RATE_WINDOW, RATE_COUNT, MAX_SENDERS = 60, 12, 400
local SETTLE_DELAY, ROSTER_DELAY, REFRESH_DELAY = 10, 2, 1
local ANSWER_SPREAD, ANSWER_TENTHS = 30, 10
local ANSWER_GAP = { GUILD = 30, PARTY = 10, RAID = 10, INSTANCE_CHAT = 10 }
local DAY_SECONDS = 86400
local EVENTS = { "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED" }

local ALL, GUILD = "all", "guild"
local YOU = ns.L("You")
local NO_VALUE = "--"
local SHARING_OFF = ns.L(", sharing is off")
local NO_SCORES = ns.L("No scores yet. Play a round, and meet\nother players running Naowh Forever.")
local NO_GUILD = ns.L("No scores from your guild yet.")
local KICKER = "LEADERBOARD"
local TEXT_RECORD_RANK = ns.L("New personal best, rank #%d of %d")
local TEXT_RANK = ns.L("Rank #%d of %d")
local TEXT_PLAYER, TEXT_PLAYERS = ns.L("%d player%s"), ns.L("%d players%s")
local TEXT_RANK_NUMBER, TEXT_ACCURACY = "%d", "%d%%"
local HEAD_RANK, HEAD_NAME, HEAD_SCORE, HEAD_ACC = "#", ns.L("Name"), ns.L("Score"), ns.L("Acc.")
local TEXT_BACK = ns.L("Back")
local NAME_JOIN = " "

local VIEW_W, VIEW_PAD, VIEW_GAP, VIEW_ALPHA = 300, 12, 8, 0.97
local KICKER_H, TITLE_H, TITLE_SIZE, COUNT_H, TEXT_SIZE, SMALL_SIZE = 12, 18, 15, 14, 12, 10
local TOP_ROWS, ROW_H, YOU_GAP = 10, 16, 6
local RANK_W, SCORE_W, ACC_W = 28, 72, 44
local FILTERS_W, TITLE_GAP = 104, 8
local BACK_W, BTN_H = 104, 24
local HEAD_H = KICKER_H + TITLE_H + COUNT_H
local FILTERS = { { key = ALL, label = "All", tip = "Everyone who shared a score with you." },
    { key = GUILD, label = "Guild", tip = "Only the scores shared over your guild." } }
local VIEW_H = VIEW_PAD + HEAD_H + ROW_H + TOP_ROWS * ROW_H + YOU_GAP + ROW_H + VIEW_GAP + BTN_H + VIEW_PAD

local Board = {}
ns.AimBoard = Board

local events, view, listening, held, inGroup, guildAsked, refreshQueued, Paint
local gen, settleGen, rosterGen = 0, nil, nil
local myGUID, myName, myClass, request
local rate, stamp, rateSenders, rateStart, window = {}, {}, 0, nil, 0
local answerQueued, lastAnswer, answerers = {}, {}, {}
local sorted, ranks = {}, {}
local me = { you = true, guild = true }

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

local function Played()
    local best = ns.AccountSettings().aimBest
    if type(best) ~= "table" then return false end
    for _, score in pairs(best) do
        if type(score) == "number" and score > 0 then return true end
    end
    return false
end

local function Sharing()
    return (S.Get("enabled") and S.Get("aimTrainer") and S.Get("aimShare") and Played()) and true or false
end

local function Today()
    return floor(time() / DAY_SECONDS)
end

local function Account(key)
    local t = ns.AccountSettings()[key]
    return type(t) == "table" and t or nil
end

local function OwnBest(m)
    local best = Account("aimBest")
    local score = best and best[m]
    return type(score) == "number" and score > 0 and score or nil
end

local function OwnAccuracy(m)
    local accuracy = Account("aimBestAccuracy")
    accuracy = accuracy and accuracy[m]
    return type(accuracy) == "number" and accuracy >= 0 and accuracy <= MAX_ACCURACY and accuracy or nil
end

local function GoodGUID(guid)
    return type(guid) == "string" and #guid <= MAX_GUID_LENGTH and guid:find(GUID_PATTERN) ~= nil
end

local function Identify()
    if myGUID then return true end
    local guid = UnitGUID("player")
    if Secret(guid) or not GoodGUID(guid) then return false end
    myGUID, request = guid, VERSION .. REQUEST .. guid
    local first, second = UnitFullName("player")
    if first and not (Secret(first) or Secret(second)) then
        myName = (second and second ~= "") and (first .. NAME_JOIN .. second) or first
    end
    local _, class = UnitClass("player")
    if class and not Secret(class) then myClass = class end
    return true
end

local function BoardTable(make)
    local account = ns.AccountSettings()
    if type(account.aimBoard) == "table" then return account.aimBoard end
    if not make then return nil end
    account.aimBoard = {}
    return account.aimBoard
end

local function List(m, make)
    local board = BoardTable(make)
    if not board then return nil end
    local list = board[m]
    if type(list) ~= "table" then
        if not make then return nil end
        list = {}
        board[m] = list
    end
    return list
end

local function Valid(e)
    return type(e) == "table" and type(e.score) == "number" and (e.acc == nil or type(e.acc) == "number")
end

local function Weakest(list)
    local count, weakest, low, lowDay = 0, nil, nil, nil
    for key, e in pairs(list) do
        count = count + 1
        local valid = Valid(e)
        local score = valid and e.score or -1
        local day = valid and type(e.day) == "number" and e.day or 0
        if not weakest or score < low or (score == low and day < lowDay) then
            weakest, low, lowDay = key, score, day
        end
    end
    return count, weakest, low, lowDay
end

local function MakeRoom(list, score, day)
    local count, weakest, low, lowDay = Weakest(list)
    if count < MAX_ENTRIES then return true end
    if score < low or (score == low and day <= lowDay) then return false end
    list[weakest] = nil
    return true
end

local function Keep(m, guid, who, score, accuracy, class, day, guild)
    local list = List(m, true)
    local entry = list[guid]
    if type(entry) == "table" and entry.name ~= nil and entry.name ~= who then return false end
    if type(entry) ~= "table" then
        if entry == nil and not MakeRoom(list, score, day) then return false end
        entry = {}
        list[guid] = entry
    end
    entry.score, entry.acc, entry.class, entry.day, entry.name = score, accuracy, class, day, who
    entry.guild = guild or entry.guild == true
    return true
end

local function Allowed(who)
    local now = GetTime()
    if not rateStart or now - rateStart >= RATE_WINDOW then
        window, rateStart = window + 1, now
        if rateSenders >= MAX_SENDERS then
            wipe(rate)
            wipe(stamp)
            rateSenders = 0
        end
    end
    if stamp[who] ~= window then
        if rate[who] == nil then
            if rateSenders >= MAX_SENDERS then return false end
            rateSenders = rateSenders + 1
        end
        stamp[who], rate[who] = window, 0
    end
    local n = rate[who]
    if n >= RATE_COUNT then return false end
    rate[who] = n + 1
    return true
end

local function GroupChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function Post(message, channel)
    C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
end

local function Message(m)
    local score = OwnBest(m)
    if not score or score > Rules.Ceiling(m) or not Identify() or not myClass then return nil end
    local accuracy = OwnAccuracy(m)
    return BEST:format(VERSION, myGUID, m, score,
        accuracy and tostring(floor(accuracy)) or NO_ACCURACY, myClass, Today())
end

local function Send(channel, only)
    if not listening then return end
    if InCombatLockdown() then
        held = true
        return
    end
    local group = not channel and GroupChannel()
    local guild = not channel and IsInGuild()
    local order = Rules.order
    for i = 1, #order do
        local m = order[i]
        local message = (not only or only == m) and Message(m)
        if message then
            if channel then Post(message, channel) end
            if group then Post(message, group) end
            if guild then Post(message, GUILD_CHANNEL) end
        end
    end
end

local function Ask(channel)
    if not Identify() then return end
    Post(request, channel)
    Send(channel)
end

local function Joined()
    if not listening then return end
    if InCombatLockdown() then
        held = true
        return
    end
    local group = GroupChannel()
    if group and not inGroup then Ask(group) end
    inGroup = group ~= nil
    if not guildAsked and IsInGuild() then
        guildAsked = true
        Ask(GUILD_CHANNEL)
    end
end

local function Settled()
    if settleGen ~= gen then return end
    settleGen = nil
    Joined()
end

local function RosterChanged()
    if rosterGen ~= gen then return end
    rosterGen = nil
    if settleGen ~= gen then Joined() end
end

local function RosterSoon()
    if rosterGen == gen then return end
    rosterGen = gen
    C_Timer.After(ROSTER_DELAY, RosterChanged)
end

local function Answerer(channel)
    local fn = answerers[channel]
    if not fn then
        fn = function()
            if answerQueued[channel] ~= gen then return end
            answerQueued[channel] = nil
            Send(channel)
        end
        answerers[channel] = fn
    end
    return fn
end

local function AnswerSoon(channel)
    local now, last = GetTime(), lastAnswer[channel]
    if answerQueued[channel] == gen or (last and now - last < ANSWER_GAP[channel]) then return end
    lastAnswer[channel] = now
    answerQueued[channel] = gen
    C_Timer.After(random(1, ANSWER_SPREAD) / ANSWER_TENTHS, Answerer(channel))
end

local function Refresh()
    refreshQueued = false
    if view and view:IsShown() and not InCombatLockdown() then Paint(view) end
end

local function RefreshSoon()
    if refreshQueued or not (view and view:IsShown()) or InCombatLockdown() then return end
    refreshQueued = true
    C_Timer.After(REFRESH_DELAY, Refresh)
end

local function ReadAccuracy(accuracy)
    if accuracy == NO_ACCURACY then return nil, true end
    accuracy = tonumber(accuracy)
    if not accuracy or accuracy < 0 or accuracy > MAX_ACCURACY or accuracy ~= floor(accuracy) then return nil, false end
    return accuracy, true
end

local function ReceivedBest(message, channel, sender)
    local guid, m, score, accuracy, class, day = message:match(BEST_PATTERN)
    if not (guid and guid ~= myGUID and GoodGUID(guid) and Rules.names[m]) or #class > MAX_CLASS_LENGTH then return end
    score, day = tonumber(score), tonumber(day)
    if not score or score < 1 or score > Rules.Ceiling(m) or not day or day < 1 or day > Today() + 1 then return end
    local ok
    accuracy, ok = ReadAccuracy(accuracy)
    if not ok then return end
    if not ns.SenderIs(sender, channel, guid) then return end
    local who = sender:gsub("%-", NAME_JOIN, 1)
    if Keep(m, guid, who, score, accuracy, class, day, channel == GUILD_CHANNEL) then RefreshSoon() end
end

local function Received(message, channel, sender)
    if #message > MAX_LENGTH then return end
    if sender == "" or #sender > MAX_NAME_LENGTH or not Identify() or not Allowed(sender) then return end
    if message:match(VERSION_PATTERN) ~= VERSION then return end
    local asker = message:match(REQUEST_PATTERN)
    if asker then
        if asker ~= myGUID and GoodGUID(asker) then AnswerSoon(channel) end
        return
    end
    ReceivedBest(message, channel, sender)
end

local CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true, GUILD = true }

local function OnEvent(_, event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" then
        if Secret(prefix) or Secret(message) or Secret(channel) or Secret(sender) then return end
        if prefix ~= PREFIX or not CHANNELS[channel] or type(message) ~= "string" or type(sender) ~= "string" then
            return
        end
        Received(message, channel, sender)
    elseif event == "GROUP_ROSTER_UPDATE" then
        RosterSoon()
    elseif held then
        held = false
        Joined()
        Send()
    end
end

local function Tidy()
    local board = ns.AccountSettings().aimBoard
    if type(board) ~= "table" then return end
    for m, list in pairs(board) do
        if not Rules.names[m] or type(list) ~= "table" then
            board[m] = nil
        else
            for key, e in pairs(list) do
                if not GoodGUID(key) or not Valid(e) then list[key] = nil end
            end
        end
    end
end

local function Sync()
    local want = Sharing()
    if want == (listening == true) then return end
    listening = want
    gen = gen + 1
    if want then
        if not events then
            Tidy()
            events = CreateFrame("Frame")
            events:SetScript("OnEvent", OnEvent)
            C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        end
        for i = 1, #EVENTS do events:RegisterEvent(EVENTS[i]) end
        settleGen = gen
        C_Timer.After(SETTLE_DELAY, Settled)
    else
        events:UnregisterAllEvents()
        inGroup, held = false, false
    end
end

local function ByScore(a, b)
    if a.score ~= b.score then return a.score > b.score end
    local x, y = a.acc or -1, b.acc or -1
    if x ~= y then return x > y end
    return (a.name or "") < (b.name or "")
end

local function CollectOthers(m, guildOnly)
    local n = 0
    local list = List(m)
    if not list then return n end
    for key, e in pairs(list) do
        if Valid(e) and (not guildOnly or e.guild) and key ~= myGUID and GoodGUID(key) then
            n = n + 1
            sorted[n] = e
        end
    end
    return n
end

local function Collect(m, guildOnly)
    wipe(sorted)
    Identify()
    local n = CollectOthers(m, guildOnly)
    local best = OwnBest(m)
    if best then
        me.score, me.acc, me.class, me.name = best, OwnAccuracy(m), myClass, myName or YOU
        n = n + 1
        sorted[n] = me
    end
    table.sort(sorted, ByScore)
    local mine
    for i = 1, n do
        local e = sorted[i]
        ranks[i] = (i > 1 and e.score == sorted[i - 1].score) and ranks[i - 1] or i
        if e == me then mine = i end
    end
    return n, mine
end

function Board.Rank(m, guildOnly)
    local n, mine = Collect(m, guildOnly)
    if mine then return ranks[mine], n end
end

function Board.RankLine(m, record)
    local rank, n = Board.Rank(m)
    if not rank then return nil end
    return (record and TEXT_RECORD_RANK or TEXT_RANK):format(rank, n)
end

function Board.Record(m)
    if listening then Send(nil, m) else Sync() end
end

Board.Sync = Sync

function Board.Clear()
    ns.AccountSettings().aimBoard = nil
    if view and view:IsShown() then Paint(view) end
end

local function NewRow(v)
    local row = CreateFrame("Frame", nil, v)
    row:SetSize(VIEW_W - 2 * VIEW_PAD, ROW_H)
    row.mark = ns.Solid(row, "BACKGROUND", T.accent, St.TAB_FILL)
    row.mark:SetAllPoints()
    row.rank = ns.Font(row, TEXT_SIZE, nil, T.muted)
    row.rank:SetPoint("LEFT")
    row.name = ns.Font(row, TEXT_SIZE, nil)
    row.name:SetPoint("LEFT", RANK_W, 0)
    row.name:SetPoint("RIGHT", -(SCORE_W + ACC_W), 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.acc = ns.Font(row, TEXT_SIZE, nil, T.muted)
    row.acc:SetPoint("RIGHT")
    row.score = ns.Font(row, TEXT_SIZE, nil)
    row.score:SetPoint("RIGHT", -ACC_W, 0)
    row:Hide()
    return row
end

local function PaintRow(row, e, rank)
    row.mark:SetShown(e == me)
    row.rank:SetFormattedText(TEXT_RANK_NUMBER, rank)
    row.name:SetText(e.name)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class] or T.fg
    row.name:SetTextColor(color.r, color.g, color.b)
    row.score:SetText(BreakUpLargeNumbers(e.score))
    if e.acc then row.acc:SetFormattedText(TEXT_ACCURACY, e.acc) else row.acc:SetText(NO_VALUE) end
    row:Show()
end

Paint = function(v)
    local guildOnly = v.filter == GUILD
    local n, mine = Collect(v.mode, guildOnly)
    v.title:SetText(Rules.names[v.mode])
    v.count:SetFormattedText(n == 1 and TEXT_PLAYER or TEXT_PLAYERS, n, Sharing() and "" or SHARING_OFF)
    Parts.PaintTabs(v.filters, v.filter)
    local rows = v.rows
    for i = 1, TOP_ROWS do
        if i <= n then PaintRow(rows[i], sorted[i], ranks[i]) else rows[i]:Hide() end
    end
    if mine and mine > TOP_ROWS then PaintRow(v.you, me, ranks[mine]) else v.you:Hide() end
    v.empty:SetText(guildOnly and NO_GUILD or NO_SCORES)
    v.empty:SetShown(n == 0)
end

local function Line(text, width)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
end

local function Filter(v, filter)
    v.filter = filter
    Paint(v)
end

local function Picked(filter)
    Filter(view, filter)
end

local function NewHead(v)
    local textW = VIEW_W - 2 * VIEW_PAD - FILTERS_W - TITLE_GAP
    v.kicker = ns.Font(v, SMALL_SIZE, nil, T.accent)
    v.kicker:SetPoint("TOPLEFT", VIEW_PAD, -VIEW_PAD)
    v.kicker:SetText(KICKER)
    Line(v.kicker, textW)
    v.title = ns.Font(v, TITLE_SIZE)
    v.title:SetPoint("TOPLEFT", VIEW_PAD, -(VIEW_PAD + KICKER_H))
    v.title:SetHeight(TITLE_H)
    Line(v.title, textW)
    v.count = ns.Font(v, SMALL_SIZE, nil, T.muted)
    v.count:SetPoint("TOPLEFT", VIEW_PAD, -(VIEW_PAD + KICKER_H + TITLE_H))
    Line(v.count, textW)
    v.filters = Parts.Tabs(v, FILTERS_W, FILTERS, Picked)
    v.filters:SetPoint("TOPRIGHT", -VIEW_PAD, -(VIEW_PAD + (HEAD_H - St.TAB_H) / 2))
end

local function NewColumnHeads(v, top)
    local head = NewRow(v)
    head:SetPoint("TOPLEFT", VIEW_PAD, -top)
    head.mark:Hide()
    head.rank:SetText(HEAD_RANK)
    head.name:SetText(HEAD_NAME)
    head.name:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
    head.score:SetText(HEAD_SCORE)
    head.score:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
    head.acc:SetText(HEAD_ACC)
    head:Show()
end

local function NewRows(v, top)
    v.rows = {}
    for i = 1, TOP_ROWS do
        local row = NewRow(v)
        row:SetPoint("TOPLEFT", VIEW_PAD, -(top + i * ROW_H))
        v.rows[i] = row
    end
    v.you = NewRow(v)
    v.you:SetPoint("TOPLEFT", VIEW_PAD, -(top + (TOP_ROWS + 1) * ROW_H + YOU_GAP))
end

function Board.NewView(parent, level)
    local v = CreateFrame("Frame", nil, parent)
    v:SetSize(VIEW_W, VIEW_H)
    v:SetPoint("CENTER")
    v:SetFrameLevel(parent:GetFrameLevel() + level)
    v:EnableMouse(true)
    Parts.Backdrop(v):Paint(VIEW_ALPHA)
    ns.Border(v, BORDER_RGB)
    NewHead(v)
    local top = VIEW_PAD + HEAD_H
    NewColumnHeads(v, top)
    NewRows(v, top)
    v.empty = ns.Font(v, TEXT_SIZE, nil, T.muted)
    v.empty:SetPoint("CENTER")
    v.back = ns.Button(v, TEXT_BACK, BACK_W, BTN_H)
    v.back:SetPoint("BOTTOM", 0, VIEW_PAD)
    v.filter = ALL
    v:Hide()
    view = v
    return v
end

function Board.Show(v, m)
    v.mode = m
    Paint(v)
    v:Show()
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "aimTrainer" or key == "aimShare" then Sync() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Sync)

-- History.lua: the inspect panel's History tab, from Player History.
local ns = _G.NaowhForever

local T = ns.THEME
local IP = ns.InspectPanel

local TITLE_SIZE, LINE_SIZE, META_SIZE = IP.SECTION_TITLE_SIZE, IP.SECTION_LINE_SIZE, 10
local TITLE_H, ROW_H, CHAT_H, SECTION_GAP = IP.SECTION_TITLE_H, 18, 30, IP.SECTION_GAP
local SUMMARY_H, SUMMARY_LINES = 34, 2
local SESSIONS, CHATS = 3, 4
local TEXT_MAX, NAME_MAX = 200, 40
local META_GAP = 6
local TEXT_GAP = 2
local MINUTE, HOUR = 60, 60
local NO_HISTORY = ns.L("No history with them yet.")
local NOT_GROUPED = ns.L("Not grouped yet.")
local GROUPED_ONCE, GROUPED = ns.L("Grouped once"), ns.L("Grouped %d times")
local DUNGEON, DUNGEONS, RAID, RAIDS = ns.L("1 dungeon"), ns.L("%d dungeons"), ns.L("1 raid"), ns.L("%d raids")
local LAST_SEEN = ns.L(" Last seen %s.")
local PARTY_PLACE, RAID_PLACE = ns.L("Party"), ns.L("Raid")
local SHORT, MINUTES, HOURS = ns.L("under a minute"), ns.L("%d min"), ns.L("%d h %d min")
local PLACE = "%s, %s"
local YOU = ns.L("You")
local CHANNEL = { WHISPER = ns.L("whisper"), PARTY = ns.L("party"), RAID = ns.L("raid"), INSTANCE_CHAT = ns.L("instance") }
local META = "%s, %s"
local NONE = {}

local body, summary, sessionsTitle, chatsTitle
local sessionRows, chatRows = {}, {}
local pieces, kinds = {}, {}

local function Section(y, title)
    local frame = CreateFrame("Frame", nil, body)
    frame:SetPoint("TOPLEFT", 0, -y)
    frame:SetPoint("TOPRIGHT", 0, -y)
    frame:SetHeight(TITLE_H)
    local text = ns.Font(frame, TITLE_SIZE, nil, T.accentSoft)
    text:SetPoint("TOPLEFT")
    text:SetText(title)
    local line = ns.Solid(frame, "ARTWORK", T.line, 1)
    line:SetPoint("TOPLEFT", 0, -(TITLE_SIZE + SECTION_GAP))
    line:SetPoint("TOPRIGHT", 0, -(TITLE_SIZE + SECTION_GAP))
    ns.Hairline(line, "h")
    return frame, y + TITLE_H
end

local function Text(parent, size, color)
    local text = ns.Font(parent, size, nil, color)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

local function RowEnter(row)
    if not (row.full and ns.Shared.Parts.Tip(row, "ANCHOR_LEFT")) then return end
    GameTooltip:SetText(row.who:GetText() or "", 1, 1, 1)
    GameTooltip:AddLine(row.full, T.fg.r, T.fg.g, T.fg.b, true)
    GameTooltip:Show()
end

local function SessionRow(y)
    local row = CreateFrame("Frame", nil, body)
    row:SetPoint("TOPLEFT", 0, -y)
    row:SetPoint("TOPRIGHT", 0, -y)
    row:SetHeight(ROW_H)
    row.when = ns.Font(row, LINE_SIZE, nil, T.muted)
    row.when:SetPoint("RIGHT")
    row.place = Text(row, LINE_SIZE, T.fg)
    row.place:SetPoint("LEFT")
    row.place:SetPoint("RIGHT", row.when, "LEFT", -META_GAP, 0)
    return row
end

local function ChatRow(y)
    local row = CreateFrame("Frame", nil, body)
    row:SetPoint("TOPLEFT", 0, -y)
    row:SetPoint("TOPRIGHT", 0, -y)
    row:SetHeight(CHAT_H)
    row.who = Text(row, META_SIZE, T.fg)
    row.who:SetPoint("TOPLEFT")
    row.meta = Text(row, META_SIZE, T.muted)
    row.meta:SetPoint("LEFT", row.who, "RIGHT", META_GAP, 0)
    row.text = Text(row, LINE_SIZE, T.fg)
    row.text:SetPoint("TOPLEFT", row.who, "BOTTOMLEFT", 0, -TEXT_GAP)
    row.text:SetPoint("RIGHT")
    row:EnableMouse(true)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function Build()
    body = IP.bodies.history
    summary = ns.Font(body, LINE_SIZE, nil, T.fg)
    summary:SetPoint("TOPLEFT")
    summary:SetWidth(IP.BODY_W)
    summary:SetJustifyH("LEFT")
    summary:SetMaxLines(SUMMARY_LINES)
    local y
    sessionsTitle, y = Section(SUMMARY_H, "GROUPS")
    for i = 1, SESSIONS do
        sessionRows[i] = SessionRow(y)
        y = y + ROW_H
    end
    chatsTitle, y = Section(y + SECTION_GAP, "CHAT")
    for i = 1, CHATS do
        chatRows[i] = ChatRow(y)
        y = y + CHAT_H
    end
end

local function Count(n, one, many)
    return n == 1 and one or many:format(n)
end

local function Summary(rec)
    local groups = tonumber(rec.groups) or 0
    local dungeons, raids = tonumber(rec.dungeons) or 0, tonumber(rec.raids) or 0
    wipe(kinds)
    if dungeons > 0 then kinds[#kinds + 1] = Count(dungeons, DUNGEON, DUNGEONS) end
    if raids > 0 then kinds[#kinds + 1] = Count(raids, RAID, RAIDS) end
    wipe(pieces)
    if groups > 0 then
        pieces[1] = Count(groups, GROUPED_ONCE, GROUPED)
        if #kinds > 0 then pieces[2] = ": " .. table.concat(kinds, ", ") end
        pieces[#pieces + 1] = "."
    else
        pieces[1] = NOT_GROUPED
    end
    if tonumber(rec.lastSeen) then pieces[#pieces + 1] = LAST_SEEN:format(ns.Shared.Ago(rec.lastSeen)) end
    return table.concat(pieces)
end

local function Duration(seconds)
    seconds = tonumber(seconds) or 0
    if seconds < MINUTE then return SHORT end
    local minutes = math.floor(seconds / MINUTE)
    if minutes < HOUR then return MINUTES:format(minutes) end
    return HOURS:format(math.floor(minutes / HOUR), minutes % HOUR)
end

local function PaintSessions(rec)
    local sessions = type(rec.sessions) == "table" and rec.sessions or NONE
    sessionsTitle:SetShown(sessions[1] ~= nil)
    for i, row in ipairs(sessionRows) do
        local session = sessions[i]
        row:SetShown(type(session) == "table")
        if type(session) == "table" then
            local place = type(session.place) == "string" and ns.PlainText(session.place, NAME_MAX)
                or (session.kind == "raid" and RAID_PLACE or PARTY_PLACE)
            row.place:SetText(PLACE:format(place, Duration(session.seconds)))
            row.when:SetText(tonumber(session.at) and ns.Shared.Ago(session.at) or "")
        end
    end
end

local function Them(rec)
    local name = type(rec.name) == "string" and ns.PlainText(rec.name, NAME_MAX)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[rec.classFile]
    return name or "", color or T.fg
end

local function PaintChats(rec)
    local chats = type(rec.chats) == "table" and rec.chats or NONE
    chatsTitle:SetShown(chats[1] ~= nil)
    local name, color = Them(rec)
    for i, row in ipairs(chatRows) do
        local chat = chats[i]
        local shown = type(chat) == "table" and type(chat.text) == "string"
        row:SetShown(shown)
        if shown then
            local who = chat.mine and T.accentSoft or color
            row.who:SetText(chat.mine and YOU or name)
            row.who:SetTextColor(who.r, who.g, who.b)
            row.meta:SetText(META:format(CHANNEL[chat.channel] or "", tonumber(chat.at) and ns.Shared.Ago(chat.at) or ""))
            row.full = ns.PlainText(chat.text, TEXT_MAX)
            row.text:SetText(row.full)
        else
            row.full = nil
        end
    end
end

local function Paint(guid)
    local H = ns.PlayerHistory
    local on = H ~= nil and H.On ~= nil and H.Of ~= nil and H.On() == true
    IP.SetHistory(on)
    if not on then return end
    local rec = guid and H.Of(guid)
    if type(rec) ~= "table" then
        summary:SetText(NO_HISTORY)
        summary:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
        rec = NONE
    else
        summary:SetText(Summary(rec))
        summary:SetTextColor(T.fg.r, T.fg.g, T.fg.b)
    end
    PaintSessions(rec)
    PaintChats(rec)
end

IP.OnApply(function(on)
    if on and not body then Build() end
end)

IP.OnRefresh(function(_, guid)
    Paint(guid)
end)

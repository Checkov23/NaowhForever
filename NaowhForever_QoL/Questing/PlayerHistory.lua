-- PlayerHistory.lua: Player History (ns.PlayerHistory): players you grouped with, and your notes on them.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local Style = ns.Shared.Style
local Decode = ns.Shared.Decode
local T = ns.THEME

local type, pairs, next, find, gsub, sub, byte = type, pairs, next, string.find, string.gsub, string.sub, string.byte
local huge = math.huge

local VERSION = 1
local MAX_PLAYERS, MAX_SESSIONS, MAX_CHATS = 1000, 10, 10
local MIN_SESSION = 60
local RESUME = 300
local MAX_TEXT, MAX_NOTE, MAX_NAME, MAX_GUID, MAX_CLASS = 200, 120, 64, 64, 20
local DAY = ns.QoLConstants.SECONDS_PER_DAY
local DAYS_MIN, DAYS_MAX, DAYS_DEFAULT = 7, 365, 90
local UTF8_TAIL_MIN, UTF8_TAIL_MAX = 128, 191
local PARTY_SIZE, RAID_SIZE = ns.QoLConstants.PARTY_SIZE, ns.QoLConstants.RAID_SIZE
local SETTINGS = { enabled = true, playerHistory = true, playerHistoryChats = true, playerNotesTooltip = true }
local TAGS = {
    { key = "tank", label = "Great Tank", color = Style.HAVE_RGB },
    { key = "healer", label = "Great Healer", color = Style.HAVE_RGB },
    { key = "dps", label = "Great DPS", color = Style.HAVE_RGB },
    { key = "friendly", label = "Friendly", color = Style.HAVE_RGB },
    { key = "avoid", label = "Avoid", color = Style.RED_RGB },
}

local NOTE_LABEL = ns.L("Note")
local TEXT_CLEAR_HISTORY = ns.L("Clear the history of every player? Your notes are kept.")
local TEXT_CLEAR_NOTES = ns.L("Delete every note you wrote on a player?")
local TEXT_NOTHING = ns.L("Nothing recorded yet")
local TEXT_SUMMARY = ns.L("%d players, %d notes")

local TAG = {}
for _, tag in ipairs(TAGS) do TAG[tag.key] = tag end

local CHANNEL = {
    CHAT_MSG_WHISPER = "WHISPER", CHAT_MSG_WHISPER_INFORM = "WHISPER",
    CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID", CHAT_MSG_RAID_WARNING = "RAID",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT", CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
}
local CHANNELS = { WHISPER = true, PARTY = true, RAID = true, INSTANCE_CHAT = true }
local KINDS = { party = true, raid = true }
local GROUP_EVENTS = { "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_LOGOUT" }
local PARTY_UNITS, RAID_UNITS = {}, {}
for i = 1, PARTY_SIZE do PARTY_UNITS[i] = "party" .. i end
for i = 1, RAID_SIZE do RAID_UNITS[i] = "raid" .. i end

local db, players, notes, count, frozen
local frame, active, chatsOn, loggedIn, myGUID
local open, seen, pool, poolN = {}, {}, {}, 0
local curInst, curPlace, curType
local resume, resumeAt
local tooltipOn, tooltipHooked

local PlayerHistory = {}
ns.PlayerHistory = PlayerHistory
PlayerHistory.NOTE_MAX = MAX_NOTE
PlayerHistory.TAGS = TAGS

local function Secret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

local function Readable(v)
    return type(v) == "string" and not Secret(v) and v ~= ""
end

local function IsPlayerGUID(guid)
    return type(guid) == "string" and not Secret(guid) and #guid <= MAX_GUID and find(guid, "^Player%-") ~= nil
end

local function Number(v)
    return type(v) == "number" and v == v and v > -huge and v < huge
end

local function Cutoff(now)
    local days = tonumber(S.Get("playerHistoryDays")) or DAYS_DEFAULT
    if days < DAYS_MIN then days = DAYS_MIN elseif days > DAYS_MAX then days = DAYS_MAX end
    return now - days * DAY
end

local function Cap(text, max)
    if #text <= max then return text end
    local cut = max
    while cut > 0 do
        local b = byte(text, cut + 1)
        if b < UTF8_TAIL_MIN or b > UTF8_TAIL_MAX then break end
        cut = cut - 1
    end
    return sub(text, 1, cut)
end

local function Clean(text, max)
    if find(text, "|", 1, true) then
        text = gsub(text, "|H.-|h(.-)|h", "%1")
        text = gsub(text, "|T.-|t", "")
        text = gsub(text, "|A.-|a", "")
        text = gsub(text, "|c%x%x%x%x%x%x%x%x", "")
        text = gsub(text, "|r", "")
        text = gsub(text, "|n", " ")
    end
    text = Decode.Text(text)
    if not text or text == "" then return nil end
    return Cap(text, max)
end

local function ValidSession(e, cutoff)
    if not (type(e) == "table" and Number(e.at) and e.at >= cutoff and Number(e.seconds) and e.seconds >= 0
        and KINDS[e.kind]) then return false end
    if type(e.place) ~= "string" then e.place = nil elseif #e.place > MAX_NAME then e.place = Cap(e.place, MAX_NAME) end
    if not KINDS[e.instance] then e.instance = nil end
    return true
end

local function ValidChat(e, cutoff)
    if not (type(e) == "table" and Number(e.at) and e.at >= cutoff and type(e.mine) == "boolean"
        and CHANNELS[e.channel] and type(e.text) == "string") then return false end
    e.text = Cap(e.text, MAX_TEXT)
    return true
end

local function Trim(list, cap, valid, cutoff)
    if type(list) ~= "table" then return {} end
    local n, i = 0, 1
    local e = list[1]
    while e ~= nil do
        list[i] = nil
        if n < cap and valid(e, cutoff) then
            n = n + 1
            list[n] = e
        end
        i = i + 1
        e = list[i]
    end
    for k in pairs(list) do
        if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then list[k] = nil end
    end
    return list
end

local function Count(rec, key)
    local v = rec[key]
    rec[key] = (Number(v) and v >= 0) and math.floor(v) or 0
end

local function ValidRecord(guid, rec, cutoff)
    if not IsPlayerGUID(guid) or type(rec) ~= "table" or not (Number(rec.firstSeen) and Number(rec.lastSeen)) then
        return false
    end
    if rec.lastSeen < cutoff and not notes[guid] then return false end
    if type(rec.name) ~= "string" or #rec.name > MAX_NAME then rec.name = nil end
    local class = rec.classFile
    if not (type(class) == "string" and #class <= MAX_CLASS and find(class, "^%u+$")) then rec.classFile = nil end
    Count(rec, "groups")
    Count(rec, "dungeons")
    Count(rec, "raids")
    rec.sessions = Trim(rec.sessions, MAX_SESSIONS, ValidSession, cutoff)
    rec.chats = Trim(rec.chats, MAX_CHATS, ValidChat, cutoff)
    return true
end

local function ValidNote(guid, note)
    if not IsPlayerGUID(guid) or type(note) ~= "table" or not Number(note.at) then return false end
    if type(note.text) ~= "string" or note.text == "" then note.text = nil else note.text = Cap(note.text, MAX_NOTE) end
    if not TAG[note.tag] then note.tag = nil end
    if type(note.name) ~= "string" or #note.name > MAX_NAME then note.name = nil end
    return note.text ~= nil or note.tag ~= nil
end

local function Newer(a, b)
    return players[a].lastSeen > players[b].lastSeen
end

local function Prune(now)
    local cutoff = Cutoff(now)
    count = 0
    local noted = 0
    for guid, rec in pairs(players) do
        if ValidRecord(guid, rec, cutoff) and guid ~= myGUID then
            count = count + 1
            if notes[guid] then noted = noted + 1 end
        else
            players[guid] = nil
        end
    end
    if count <= MAX_PLAYERS then return end
    local list = {}
    for guid in pairs(players) do
        if not notes[guid] then list[#list + 1] = guid end
    end
    table.sort(list, Newer)
    for i = math.max(MAX_PLAYERS - noted, 0) + 1, #list do
        players[list[i]] = nil
        count = count - 1
    end
end

local function Load(create)
    if players then return true end
    if frozen then return false end
    local account = ns.AccountSettings()
    local saved = account.playerHistory
    if type(saved) ~= "table" then
        if not create then return false end
        saved = {}
        account.playerHistory = saved
    end
    if Number(saved.version) and saved.version > VERSION then
        frozen = true
        return false
    end
    saved.version = VERSION
    if type(saved.players) ~= "table" then saved.players = {} end
    if type(saved.notes) ~= "table" then saved.notes = {} end
    db, players, notes = saved, saved.players, saved.notes
    for guid, note in pairs(notes) do
        if not ValidNote(guid, note) then notes[guid] = nil end
    end
    Prune(time())
    local r = saved.resume
    if type(r) == "table" and Number(r.at) then resume, resumeAt = r, r.at end
    saved.resume = nil
    return true
end

local function Push(list, cap)
    local n = #list
    local entry
    if n >= cap then
        entry = list[cap]
        for i = n, cap + 1, -1 do list[i] = nil end
        n = cap - 1
    end
    for i = n, 1, -1 do list[i + 1] = list[i] end
    entry = entry or {}
    list[1] = entry
    return entry
end

local function Empty(list)
    for i = #list, 1, -1 do list[i] = nil end
end

local function Evict()
    local oldest, seenAt
    for guid, rec in pairs(players) do
        if not open[guid] and not notes[guid] and (not seenAt or rec.lastSeen < seenAt) then
            oldest, seenAt = guid, rec.lastSeen
        end
    end
    if not oldest then return nil end
    local rec = players[oldest]
    players[oldest] = nil
    return rec
end

local function Record(guid, now)
    local rec = players[guid]
    if rec then return rec end
    if count >= MAX_PLAYERS then
        rec = Evict()
        if not rec then return nil end
        Empty(rec.sessions)
        Empty(rec.chats)
        rec.name, rec.classFile = nil, nil
    else
        rec = { sessions = {}, chats = {} }
        count = count + 1
    end
    rec.firstSeen, rec.lastSeen, rec.groups, rec.dungeons, rec.raids = now, now, 0, 0, 0
    local note = notes[guid]
    if note and note.name then rec.name = note.name end
    players[guid] = rec
    return rec
end

local function AddChat(rec, now, mine, channel, text)
    local e = Push(rec.chats, MAX_CHATS)
    e.at, e.mine, e.channel, e.text = now, mine, channel, text
    rec.lastSeen = now
end

local function Enter(st)
    if st.inst == curInst then return end
    st.inst, st.place, st.instance = curInst, curPlace, curType
    if curType == "raid" then st.raids = st.raids + 1 else st.dungeons = st.dungeons + 1 end
end

local function Release(guid)
    poolN = poolN + 1
    pool[poolN] = open[guid]
    open[guid] = nil
end

local function Resume(st, guid, rec, now)
    local r = resume and resume[guid]
    if resume then resume[guid] = nil end
    if type(r) ~= "table" or now - resumeAt > RESUME or not Number(r.at) or r.at > now then return end
    st.at = r.at
    st.raid = st.raid or r.raid == true
    st.inst = Number(r.inst) and r.inst or nil
    st.place = type(r.place) == "string" and r.place or nil
    st.instance = KINDS[r.instance] and r.instance or nil
    st.dungeons = Number(r.dungeons) and r.dungeons or 0
    st.raids = Number(r.raids) and r.raids or 0
    local last = rec.sessions[1]
    st.extend = r.kept == true and last ~= nil and last.at == r.at
end

local function Learn(rec, unit)
    local first, second = UnitFullName(unit)
    if Readable(first) and not Secret(second) then
        local name = Readable(second) and (first .. " " .. second) or first
        if #name <= MAX_NAME then rec.name = name end
    end
    local _, class = UnitClass(unit)
    if Readable(class) and #class <= MAX_CLASS then rec.classFile = class end
end

local function Take()
    if poolN == 0 then return {} end
    local st = pool[poolN]
    pool[poolN] = nil
    poolN = poolN - 1
    return st
end

local function Open(guid, unit, now, raid)
    local rec = Record(guid, now)
    if not rec then return end
    Learn(rec, unit)
    rec.lastSeen = now
    local st = Take()
    st.at, st.raid, st.inst, st.place, st.instance = now, raid, nil, nil, nil
    st.dungeons, st.raids, st.extend = 0, 0, false
    Resume(st, guid, rec, now)
    open[guid] = st
    if curInst then Enter(st) end
end

local function Close(guid, now)
    local st = open[guid]
    local rec = players[guid]
    local seconds = now - st.at
    if rec and (st.extend or seconds >= MIN_SESSION) then
        local s = st.extend and rec.sessions[1]
        if not s then
            s = Push(rec.sessions, MAX_SESSIONS)
            rec.groups = rec.groups + 1
        end
        s.at, s.seconds, s.kind = st.at, seconds, st.raid and "raid" or "party"
        s.place, s.instance = st.place, st.instance
        rec.dungeons, rec.raids = rec.dungeons + st.dungeons, rec.raids + st.raids
        rec.lastSeen = now
    end
    Release(guid)
end

local function Seen(unit, now, raid)
    local guid = UnitGUID(unit)
    if not IsPlayerGUID(guid) or guid == myGUID then return end
    seen[guid] = true
    local st = open[guid]
    if st then
        if raid then st.raid = true end
    else
        Open(guid, unit, now, raid)
    end
end

local function Scan(now)
    wipe(seen)
    local members = GetNumGroupMembers() or 0
    if IsInRaid() then
        for i = 1, math.min(members, #RAID_UNITS) do Seen(RAID_UNITS[i], now, true) end
    elseif members > 0 then
        for i = 1, #PARTY_UNITS do Seen(PARTY_UNITS[i], now, false) end
    end
    for guid in pairs(open) do
        if not seen[guid] then Close(guid, now) end
    end
end

local function Instance()
    local name, kind, _, _, _, _, _, id = GetInstanceInfo()
    if Secret(kind) or Secret(id) or Secret(name) or not KINDS[kind] or not Number(id) then
        curInst, curPlace, curType = nil, nil, nil
        return
    end
    curInst, curType = id, kind
    curPlace = (type(name) == "string" and name ~= "") and Cap(name, MAX_NAME) or nil
    for _, st in pairs(open) do Enter(st) end
end

local function Logout()
    local now = time()
    local saved
    for guid, st in pairs(open) do
        local kept = st.extend or now - st.at >= MIN_SESSION
        saved = saved or {}
        saved[guid] = { at = st.at, raid = st.raid, inst = st.inst, place = st.place, instance = st.instance,
            kept = kept, dungeons = kept and 0 or st.dungeons, raids = kept and 0 or st.raids }
        Close(guid, now)
    end
    if saved then
        saved.at = now
        db.resume = saved
    end
end

local function SenderName(sender)
    if not Readable(sender) then return nil end
    local name = Ambiguate and Ambiguate(sender, "none") or sender
    if Readable(name) and #name <= MAX_NAME then return name end
end

local function Whisper(event, text, sender, guid)
    if guid == myGUID or not IsPlayerGUID(guid) then return end
    local clean = Clean(text, MAX_TEXT)
    if not clean then return end
    local now = time()
    local rec = Record(guid, now)
    if not rec then return end
    if not rec.name then rec.name = SenderName(sender) end
    if not rec.classFile then
        local _, class = GetPlayerInfoByGUID(guid)
        if Readable(class) and #class <= MAX_CLASS then rec.classFile = class end
    end
    AddChat(rec, now, event == "CHAT_MSG_WHISPER_INFORM", "WHISPER", clean)
end

local function MyLine(channel, text)
    if next(open) == nil or IsInRaid() then return end
    local clean = Clean(text, MAX_TEXT)
    if not clean then return end
    local now = time()
    for other in pairs(open) do
        local rec = players[other]
        if rec then AddChat(rec, now, true, channel, clean) end
    end
end

local function TheirLine(guid, channel, text)
    local rec = players[guid]
    if not rec then return end
    local clean = Clean(text, MAX_TEXT)
    if not clean then return end
    AddChat(rec, time(), false, channel, clean)
end

local function Chat(event, text, sender, _, _, _, _, _, _, _, _, _, guid)
    if type(guid) ~= "string" or Secret(guid) or Secret(text) or Secret(sender) or type(text) ~= "string" then
        return
    end
    local channel = CHANNEL[event]
    if channel == "WHISPER" then
        Whisper(event, text, sender, guid)
    elseif guid == myGUID then
        MyLine(channel, text)
    elseif open[guid] then
        TheirLine(guid, channel, text)
    end
end

local function OnEvent(_, event, ...)
    if CHANNEL[event] then return Chat(event, ...) end
    if event == "GROUP_ROSTER_UPDATE" then
        Scan(time())
    elseif event == "PLAYER_LOGOUT" then
        Logout()
    else
        Instance()
        Scan(time())
    end
end

local function On()
    return (S.Get("enabled") and S.Get("playerHistory")) and true or false
end

local function SetChats(on)
    if on == chatsOn then return end
    chatsOn = on
    for event in pairs(CHANNEL) do
        if on then frame:RegisterEvent(event) else frame:UnregisterEvent(event) end
    end
end

local function Enable()
    if not Load(true) then return end
    local guid = UnitGUID("player")
    if not IsPlayerGUID(guid) then return end
    myGUID = guid
    if players[guid] then
        players[guid] = nil
        count = count - 1
    end
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", OnEvent)
    end
    for i = 1, #GROUP_EVENTS do frame:RegisterEvent(GROUP_EVENTS[i]) end
    active = true
    Instance()
    Scan(time())
end

local function Disable()
    active = false
    chatsOn = false
    if frame then frame:UnregisterAllEvents() end
    local now = time()
    for guid in pairs(open) do Close(guid, now) end
end

local function OnUnit(tooltip, data)
    if not tooltipOn or not notes then return end
    local guid = data and data.guid
    if type(guid) ~= "string" or Secret(guid) then return end
    local note = notes[guid]
    if not note or tooltip:IsForbidden() then return end
    local tag = TAG[note.tag]
    if tag then
        tooltip:AddLine(tag.label, tag.color.r, tag.color.g, tag.color.b)
    else
        tooltip:AddLine(NOTE_LABEL, T.accent.r, T.accent.g, T.accent.b)
    end
    if note.text then tooltip:AddLine(note.text, T.fg.r, T.fg.g, T.fg.b, true) end
end

local function Hook()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnit)
end

local function HookNextFrame()
    C_Timer.After(0, Hook)
end

local function SavedNotes()
    if notes then return next(notes) ~= nil end
    local saved = ns.AccountSettings().playerHistory
    return type(saved) == "table" and type(saved.notes) == "table" and next(saved.notes) ~= nil
end

local function SyncTooltip()
    tooltipOn = S.Get("enabled") and S.Get("playerNotesTooltip") and true or false
    if tooltipHooked or not tooltipOn or not SavedNotes() or not Load(false) then return end
    tooltipHooked = true
    C_Timer.After(0, HookNextFrame)
end

local function Apply()
    if not loggedIn then return end
    if On() then
        if not active then Enable() end
        if active then SetChats(S.Get("playerHistoryChats") and true or false) end
    elseif active then
        Disable()
    end
    SyncTooltip()
end

local function OnLogin(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    loggedIn = true
    Apply()
end

PlayerHistory.On = On

function PlayerHistory.Of(guid)
    if type(guid) ~= "string" or Secret(guid) or not Load(false) then return nil end
    return players[guid]
end

function PlayerHistory.Forget(guid)
    if type(guid) ~= "string" or Secret(guid) or not Load(false) then return end
    if players[guid] then
        players[guid] = nil
        count = count - 1
    end
    if open[guid] then Release(guid) end
end

function PlayerHistory.Note(guid)
    if type(guid) ~= "string" or Secret(guid) or not Load(false) then return nil end
    return notes[guid]
end

function PlayerHistory.SetNote(guid, text, tag, name)
    if not IsPlayerGUID(guid) then return false end
    local me = UnitGUID("player")
    if not Secret(me) and guid == me then return false end
    if tag ~= nil and not TAG[tag] then return false end
    if not Load(true) then return false end
    text = (type(text) == "string" and not Secret(text)) and Clean(text, MAX_NOTE) or nil
    if not text and not tag then
        notes[guid] = nil
        return true
    end
    local note = notes[guid] or {}
    note.text, note.tag, note.at = text, tag, time()
    if Readable(name) and #name <= MAX_NAME then
        note.name = name
        local rec = players[guid]
        if rec then rec.name = name end
    end
    notes[guid] = note
    SyncTooltip()
    return true
end

local function HasHistory()
    return Load(false) and next(players) ~= nil
end

local function HasNotes()
    return Load(false) and next(notes) ~= nil
end

local function WipeHistory()
    if not Load(false) then return end
    wipe(players)
    count = 0
    for guid in pairs(open) do Release(guid) end
    db.resume, resume = nil, nil
    if active then Scan(time()) end
end

local function ClearHistory()
    ns.Confirm(TEXT_CLEAR_HISTORY, WipeHistory)
end

local function WipeNotes()
    if Load(false) then wipe(notes) end
end

local function ClearNotes()
    ns.Confirm(TEXT_CLEAR_NOTES, WipeNotes)
end

local function Summary()
    if not Load(false) then return TEXT_NOTHING end
    local n = 0
    for _ in pairs(notes) do n = n + 1 end
    return TEXT_SUMMARY:format(count, n)
end

hooksecurefunc(S, "Set", function(key)
    if SETTINGS[key] then
        Apply()
    elseif key == "playerHistoryDays" and players then
        Prune(time())
    end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)

ns.Shared.Settings.Page("QoL/Questing & Group", S):Card({
    id = "playerHistory", name = "Player History", order = 40, switch = "playerHistory",
    help = "Remembers the players you group and chat with, stored only on your computer.",
    search = "inspect panel history tab player tab notes",
    summary = Summary,
    rows = {
        { key = "playerHistoryChats", label = "Record Chats", toggle = true,
          help = "Also keeps your last whispers and group chat lines with each player." },
        { key = "playerHistoryDays", label = "Forget After", slider = { DAYS_MIN, DAYS_MAX, 1 }, unit = " days",
          help = "Forgets players you have not met for this many days." },
        { key = "playerNotesTooltip", label = "Notes on Tooltips", toggle = true, always = true,
          help = "Shows your note and tag on a player's tooltip." },
        { label = "Clear History", buttonText = "Clear", button = ClearHistory, always = true,
          needs = HasHistory, why = TEXT_NOTHING,
          help = "Deletes every player's recorded history, keeping your notes." },
        { label = "Clear Notes", buttonText = "Clear", button = ClearNotes, always = true,
          needs = HasNotes, why = "No notes yet",
          help = "Deletes every note and tag you wrote on a player." },
    },
})

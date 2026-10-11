-- Loads PlayerHistory.lua against stubbed groups, chat events and tooltips and checks
-- Player History: nothing listened to while off, sessions with the roster, dungeon and raid runs,
-- whispers and group chat by GUID, secrets, NPCs and yourself skipped, the caps, Forget After and
-- malformed saved data at load, notes and their tooltip line, and that a chat burst, a roster
-- update and a tooltip make no garbage. Run from the repo root: lua Tools/regression/test-player-history.lua
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end
local Measure = dofile("Tools/regression/measure.lua")(check)
local LoadDecode = dofile("Tools/regression/load_decode.lua")

local DAY = 86400
local START = 1000000000
local ME = "Player-1-0001"
local TANK, HEALER, MAGE = "Player-1-0002", "Player-1-0003", "Player-1-0004"
local DEFAULTS = { enabled = true, playerHistory = true, playerHistoryChats = true, playerHistoryDays = 90,
    playerNotesTooltip = true }

local function Noop() end

local function Boot(settings, account, now)
    local s = { now = now or START, frames = {}, timers = {}, posts = {}, settings = settings or {},
        account = account or {}, secret = {}, raid = false, members = 0, instance = { "", "none" },
        units = { player = { guid = ME, first = "Die", second = "Man", class = "PALADIN" } } }
    local function Frame()
        local f = { scripts = {}, events = {} }
        function f:SetScript(k, fn) self.scripts[k] = fn end
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterEvent(e) self.events[e] = nil end
        function f:UnregisterAllEvents() for k in pairs(self.events) do self.events[k] = nil end end
        s.frames[#s.frames + 1] = f
        return f
    end
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        THEME = { accent = { r = 0, g = 0.57, b = 0.93 }, fg = { r = 0.94, g = 0.95, b = 0.95 } },
        Apply = Noop,
        QoLConstants = dofile("Tools/regression/qol_constants.lua"),
        AccountSettings = function() return s.account end,
        Confirm = function(text, yes) s.confirmed = text; yes() end,
    }
    ns.QoLSettings = {
        Get = function(k)
            local v = s.settings[k]
            if v == nil then v = DEFAULTS[k] end
            return v
        end,
        Set = function(k, v) s.settings[k] = v end,
    }
    ns.Shared = {
        Style = { HAVE_RGB = { r = 0.3, g = 0.82, b = 0.48 }, RED_RGB = { r = 0.97, g = 0.44, b = 0.44 } },
        Settings = { Page = function() return { Card = function(_, spec) s.card = spec end } end },
    }
    local env = setmetatable({
        _G = { NaowhForever = ns },
        CreateFrame = Frame,
        hooksecurefunc = function(t, name, hook)
            local orig = t[name]
            t[name] = function(...) orig(...); hook(...) end
        end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        time = function() return s.now end,
        issecretvalue = function(v) return v ~= nil and s.secret[v] == true end,
        IsInRaid = function() return s.raid end,
        GetNumGroupMembers = function() return s.members end,
        UnitGUID = function(u) local m = s.units[u] return m and m.guid end,
        UnitFullName = function(u) local m = s.units[u] if m then return m.first, m.second end end,
        UnitClass = function(u) local m = s.units[u] if m then return "x", m.class end end,
        GetInstanceInfo = function()
            local i = s.instance
            return i[1], i[2], 0, "", 5, 0, false, i[3]
        end,
        GetPlayerInfoByGUID = function() return "Mage", "MAGE" end,
        Ambiguate = function(name) return name end,
        C_Timer = { After = function(_, fn) s.timers[#s.timers + 1] = fn end },
        Enum = { TooltipDataType = { Unit = 2 } },
        TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) s.posts[#s.posts + 1] = { kind, fn } end },
    }, { __index = _G })
    ns.Shared.Decode = LoadDecode(env)
    local chunk = assert(loadfile("NaowhForever_QoL/Questing/PlayerHistory.lua"))
    setfenv(chunk, env)
    chunk()
    s.ns, s.PH, s.S = ns, ns.PlayerHistory, ns.QoLSettings
    s.boot = s.frames[1]
    function s.fire(event, ...)
        for _, f in ipairs(s.frames) do
            if f.events[event] then f.scripts.OnEvent(f, event, ...) end
        end
    end
    function s.listening()
        local n = 0
        for _, f in ipairs(s.frames) do for _ in pairs(f.events) do n = n + 1 end end
        return n
    end
    function s.runTimers()
        local due = s.timers
        s.timers = {}
        for _, fn in ipairs(due) do fn() end
    end
    function s.party(...)
        for i = 1, 4 do s.units["party" .. i] = nil end
        local list = { ... }
        for i, m in ipairs(list) do s.units["party" .. i] = m end
        s.raid, s.members = false, #list > 0 and #list + 1 or 0
        s.fire("GROUP_ROSTER_UPDATE")
    end
    function s.chat(event, text, sender, guid)
        s.fire(event, text, sender, "", "", "", "", 0, 0, "", 0, 1, guid, 0, false, false, false, false)
    end
    function s.row(label)
        for _, row in ipairs(s.card.rows) do
            if row.label == label then return row end
        end
    end
    s.fire("PLAYER_LOGIN")
    return s
end

local function Member(guid, first, second, class)
    return { guid = guid, first = first, second = second, class = class }
end
local tank = Member(TANK, "Tank", "Ironhide", "WARRIOR")
local healer = Member(HEALER, "Heal", "Brightwater", "PRIEST")

do -- off: nothing listened to, nothing read
    local account = { playerHistory = { version = 1, players = { [TANK] = { firstSeen = 1, lastSeen = 1 } } } }
    local s = Boot({ playerHistory = false }, account)
    check("off: no events once logged in", s.listening() == 0)
    check("off: only the boot frame", #s.frames == 1)
    check("off: saved data not touched", account.playerHistory.players[TANK].lastSeen == 1)
    check("off: no tooltip hook without notes", #s.posts == 0 and #s.timers == 0)
    s.party(tank)
    s.chat("CHAT_MSG_WHISPER", "hi", "Tank Ironhide", TANK)
    check("off: nothing recorded", account.playerHistory.players[TANK].lastSeen == 1)
    check("off: On() is false", s.PH.On() == false)
    s.S.Set("playerHistory", true)
    check("turned on: listens", s.frames[2].events.GROUP_ROSTER_UPDATE and s.frames[2].events.CHAT_MSG_WHISPER)
    check("turned on: On() is true", s.PH.On() == true)
    check("turned on: already grouped opens a session", s.PH.Of(TANK) ~= nil)
    s.S.Set("playerHistory", false)
    check("turned off again: no events", s.listening() == 0)
end

do -- sessions open and close with the roster; short ones are dropped
    local s = Boot()
    check("no group, nothing recorded", s.PH.Of(TANK) == nil)
    s.party(tank)
    local rec = s.PH.Of(TANK)
    check("a member joining is recorded at once", rec and rec.name == "Tank Ironhide" and rec.classFile == "WARRIOR")
    check("first and last seen", rec.firstSeen == START and rec.lastSeen == START)
    check("an open session is not counted yet", rec.groups == 0 and #rec.sessions == 0)
    s.now = START + 120
    s.party()
    check("leaving closes the session", #rec.sessions == 1 and rec.sessions[1].seconds == 120
        and rec.sessions[1].at == START and rec.sessions[1].kind == "party" and rec.groups == 1)
    check("no instance, no place", rec.sessions[1].place == nil and rec.sessions[1].instance == nil)
    s.party(tank)
    s.now = s.now + 59
    s.party()
    check("under a minute is dropped", #rec.sessions == 1 and rec.groups == 1)
    s.party(tank, healer)
    s.now = s.now + 100
    s.party(healer)
    check("one leaving closes only theirs", #rec.sessions == 2 and s.PH.Of(HEALER).groups == 0)
    s.now = s.now + 100
    s.S.Set("playerHistory", false)
    check("turning off closes open sessions", s.PH.Of(HEALER).groups == 1)
end

do -- dungeon and raid runs
    local s = Boot()
    s.party(tank)
    s.instance = { "Wailing Caverns", "party", 43 }
    s.fire("PLAYER_ENTERING_WORLD", false, false)
    s.fire("ZONE_CHANGED_NEW_AREA")
    s.instance = { "Kalimdor", "none" }
    s.fire("PLAYER_ENTERING_WORLD", false, false)
    s.instance = { "Wailing Caverns", "party", 43 }
    s.fire("PLAYER_ENTERING_WORLD", false, false)
    s.now = START + 600
    s.party()
    local rec = s.PH.Of(TANK)
    check("a dungeon counted once per instance in a session", rec.dungeons == 1 and rec.raids == 0)
    check("the session has its place", rec.sessions[1].place == "Wailing Caverns"
        and rec.sessions[1].instance == "party")
    s.instance = { "Kalimdor", "none" }
    s.fire("PLAYER_ENTERING_WORLD", false, false)
    s.party(tank)
    s.instance = { "Shadowfang Keep", "party", 33 }
    s.fire("PLAYER_ENTERING_WORLD", false, false)
    s.instance = { "Wailing Caverns", "party", 43 }
    s.fire("PLAYER_ENTERING_WORLD", false, false)
    s.now = s.now + 600
    s.party()
    check("two different dungeons are two runs", rec.dungeons == 3)
    s.party(tank)
    s.now = s.now + 30
    s.party()
    check("a run in a dropped session is not counted", rec.dungeons == 3)

    s.instance = { "Molten Core", "raid", 409 }
    s.raid, s.members = true, 3
    s.units.raid1, s.units.raid2, s.units.raid3 = s.units.player, tank, healer
    s.fire("GROUP_ROSTER_UPDATE")
    s.fire("PLAYER_ENTERING_WORLD", false, false)
    check("yourself in the raid is never recorded", s.PH.Of(ME) == nil)
    s.now = s.now + 3600
    s.raid, s.members = false, 0
    s.fire("GROUP_ROSTER_UPDATE")
    check("a raid run counted, in a raid session", rec.raids == 1 and rec.sessions[1].kind == "raid"
        and rec.sessions[1].instance == "raid" and rec.sessions[1].place == "Molten Core")
    check("the other raider too", s.PH.Of(HEALER).raids == 1)
end

do -- a session open at logout, carried on by a quick reload
    local account = {}
    local s = Boot(nil, account)
    s.party(tank)
    s.now = START + 90
    s.fire("PLAYER_LOGOUT")
    local rec = account.playerHistory.players[TANK]
    check("logout closes the session", #rec.sessions == 1 and rec.sessions[1].seconds == 90 and rec.groups == 1)
    s = Boot(nil, account, START + 100)
    s.party(tank)
    s.now = START + 200
    s.party()
    rec = s.PH.Of(TANK)
    check("a reload carries the session on", #rec.sessions == 1 and rec.sessions[1].seconds == 200
        and rec.sessions[1].at == START and rec.groups == 1)
    s.party(tank)
    s.now = START + 300
    s.fire("PLAYER_LOGOUT")
    s = Boot(nil, account, START + 2000)
    s.party(tank)
    s.now = START + 2100
    s.party()
    check("a long break starts a new one", #rec.sessions == 3 and rec.groups == 3)
end

do -- whispers both ways, group chat, secrets, NPCs and yourself
    local s = Boot()
    s.chat("CHAT_MSG_WHISPER", "hello there", "Mage Frost", MAGE)
    local rec = s.PH.Of(MAGE)
    check("a whisper makes a record from its GUID", rec and rec.name == "Mage Frost" and rec.classFile == "MAGE")
    check("their whisper", #rec.chats == 1 and rec.chats[1].mine == false and rec.chats[1].channel == "WHISPER"
        and rec.chats[1].text == "hello there" and rec.chats[1].at == START)
    s.now = START + 5
    s.chat("CHAT_MSG_WHISPER_INFORM", "hi |cff1eff00|Hitem:2589::|h[Linen Cloth]|h|r", "Mage Frost", MAGE)
    check("your whisper goes on the GUID in arg 12, cleaned", #rec.chats == 2 and rec.chats[1].mine == true
        and rec.chats[1].text == "hi [Linen Cloth]" and rec.chats[2].text == "hello there")
    s.chat("CHAT_MSG_WHISPER", ("x"):rep(300), "Mage Frost", MAGE)
    check("text capped at 200 bytes", #rec.chats[1].text == 200)

    s.chat("CHAT_MSG_WHISPER", "hi", "Bob", "Creature-0-1-2-3-4-5")
    check("an NPC is not recorded", s.PH.Of("Creature-0-1-2-3-4-5") == nil)
    s.chat("CHAT_MSG_WHISPER_INFORM", "note to self", "Die Man", ME)
    check("yourself is not recorded", s.PH.Of(ME) == nil)
    s.secret["Player-1-0099"] = true
    s.chat("CHAT_MSG_WHISPER", "hi", "Hidden", "Player-1-0099")
    check("a secret GUID is skipped", s.PH.Of("Player-1-0099") == nil)
    s.secret["secret text"] = true
    s.chat("CHAT_MSG_WHISPER", "secret text", "Mage Frost", MAGE)
    check("a secret text is skipped", rec.chats[1].text ~= "secret text" and #rec.chats == 3)
    s.secret["Secret Sender"] = true
    s.chat("CHAT_MSG_WHISPER", "plain", "Secret Sender", MAGE)
    check("a secret sender is skipped", #rec.chats == 3)
    s.secret[HEALER] = true
    s.party(healer)
    check("a secret roster GUID is skipped", s.PH.Of(HEALER) == nil)
    s.secret[HEALER] = nil

    s.party(tank, healer)
    s.chat("CHAT_MSG_PARTY", "pull?", "Tank Ironhide", TANK)
    local t = s.PH.Of(TANK)
    check("a member's party line", #t.chats == 1 and t.chats[1].channel == "PARTY" and t.chats[1].mine == false)
    s.chat("CHAT_MSG_PARTY_LEADER", "go", "Die Man", ME)
    check("your party line on every member", t.chats[1].mine == true and t.chats[1].text == "go"
        and s.PH.Of(HEALER).chats[1].text == "go")
    s.chat("CHAT_MSG_INSTANCE_CHAT_LEADER", "gg", "Tank Ironhide", TANK)
    check("instance chat", t.chats[1].channel == "INSTANCE_CHAT")
    s.chat("CHAT_MSG_PARTY", "who?", "Mage Frost", MAGE)
    check("someone not in your group: their party line is not kept", #rec.chats == 3)
    s.raid, s.members = true, 3
    s.units.raid1, s.units.raid2, s.units.raid3 = s.units.player, tank, healer
    s.fire("GROUP_ROSTER_UPDATE")
    local before = #t.chats
    s.chat("CHAT_MSG_RAID", "everyone stack", "Die Man", ME)
    check("your raid line is not put on every raider", #t.chats == before)
    s.chat("CHAT_MSG_RAID_WARNING", "stack", "Tank Ironhide", TANK)
    check("a raider's own raid line is kept", t.chats[1].channel == "RAID" and t.chats[1].text == "stack")
    s.S.Set("playerHistoryChats", false)
    check("Record Chats off: no chat events", not s.frames[2].events.CHAT_MSG_WHISPER
        and s.frames[2].events.GROUP_ROSTER_UPDATE)
end

do -- the caps
    local s = Boot()
    for i = 1, 15 do
        s.now = START + i
        s.chat("CHAT_MSG_WHISPER", "m" .. i, "Mage Frost", MAGE)
    end
    local chats = s.PH.Of(MAGE).chats
    check("10 chats, newest first", #chats == 10 and chats[1].text == "m15" and chats[10].text == "m6")
    for _ = 1, 12 do
        s.party(tank)
        s.now = s.now + 100
        s.party()
    end
    local rec = s.PH.Of(TANK)
    check("10 sessions, newest first, all counted", #rec.sessions == 10 and rec.groups == 12
        and rec.sessions[1].at > rec.sessions[10].at)

    local players = {}
    for i = 1, 1000 do
        players[("Player-2-%04d"):format(i)] = { firstSeen = START - i, lastSeen = START - i, sessions = {}, chats = {} }
    end
    local account = { playerHistory = { version = 1, players = players,
        notes = { ["Player-2-1000"] = { text = "keep", at = START } } } }
    s = Boot(nil, account)
    s.chat("CHAT_MSG_WHISPER", "new", "Mage Frost", MAGE)
    local n = 0
    for _ in pairs(players) do n = n + 1 end
    check("1000 players at most", n == 1000 and players[MAGE] ~= nil)
    check("the longest unseen goes first", players["Player-2-0999"] == nil)
    check("never one with a note", players["Player-2-1000"] ~= nil)
    players["Player-2-1001"] = { firstSeen = 1, lastSeen = START - 5000, sessions = {}, chats = {} }
    players["Player-2-1002"] = { firstSeen = 1, lastSeen = START - 6000, sessions = {}, chats = {} }
    Boot(nil, account)
    n = 0
    for _ in pairs(players) do n = n + 1 end
    check("over the cap at load: trimmed to 1000, oldest first", n == 1000 and players["Player-2-1002"] == nil
        and players["Player-2-1001"] == nil and players["Player-2-1000"] ~= nil)
end

do -- Forget After and malformed data at load
    local old, recent = START - 100 * DAY, START - 10 * DAY
    local account = { playerHistory = { version = 1, notes = {
        ["Player-3-0003"] = { text = "good healer", tag = "healer", at = old },
        ["Player-3-0009"] = { tag = "nope", at = old },
        ["Creature-0-1"] = { text = "npc", at = old },
    }, players = {
        ["Player-3-0001"] = { firstSeen = old, lastSeen = old, groups = 2, sessions = {}, chats = {} },
        ["Player-3-0002"] = { firstSeen = old, lastSeen = recent, groups = "x", dungeons = -1, raids = 2.5,
            name = 42, classFile = "not a class",
            sessions = {
                { at = recent, seconds = 100, kind = "party", place = "Wailing Caverns", instance = "party" },
                { at = recent, seconds = 100, kind = "bogus" },
                { at = old, seconds = 100, kind = "party" },
                "junk",
                nil,
                { at = recent, seconds = 100, kind = "party" },
            },
            chats = {
                { at = recent, mine = true, channel = "SAY", text = "x" },
                { at = recent, mine = false, channel = "WHISPER", text = ("y"):rep(300) },
                { at = old, mine = false, channel = "WHISPER", text = "old" },
            } },
        ["Player-3-0003"] = { firstSeen = old, lastSeen = old, sessions = {}, chats = {} },
        ["Player-3-0004"] = "junk",
        ["Player-3-0005"] = { firstSeen = "a", lastSeen = recent },
        ["Creature-0-1"] = { firstSeen = recent, lastSeen = recent },
        [ME] = { firstSeen = recent, lastSeen = recent },
    } } }
    local s = Boot(nil, account)
    local players = account.playerHistory.players
    check("not seen within Forget After: dropped", players["Player-3-0001"] == nil)
    check("not seen within Forget After but noted: kept", s.PH.Of("Player-3-0003") ~= nil)
    check("malformed records dropped", players["Player-3-0004"] == nil and players["Player-3-0005"] == nil
        and players["Creature-0-1"] == nil)
    check("your own record dropped", players[ME] == nil)
    local rec = s.PH.Of("Player-3-0002")
    check("bad counts made whole", rec.groups == 0 and rec.dungeons == 0 and rec.raids == 2)
    check("bad name and class dropped", rec.name == nil and rec.classFile == nil)
    check("bad and old sessions dropped, and after a hole", #rec.sessions == 1
        and rec.sessions[1].place == "Wailing Caverns" and rec.sessions[6] == nil)
    check("bad and old chats dropped, long text cut", #rec.chats == 1 and #rec.chats[1].text == 200)
    check("a note with a bad tag and no text dropped", s.PH.Note("Player-3-0009") == nil)
    check("a note on an NPC dropped", account.playerHistory.notes["Creature-0-1"] == nil)
    check("load is repeat-safe", Boot(nil, account) and #s.PH.Of("Player-3-0002").sessions == 1)

    s.S.Set("playerHistoryDays", 7)
    check("a shorter Forget After drops at once", s.PH.Of("Player-3-0002") == nil and s.PH.Of("Player-3-0003"))

    account = { playerHistory = "junk" }
    Boot(nil, account)
    check("a broken table is replaced", type(account.playerHistory) == "table"
        and type(account.playerHistory.players) == "table")
    local future = { version = 99, players = { [TANK] = { lastSeen = 1 } } }
    account = { playerHistory = future }
    s = Boot(nil, account)
    s.party(tank)
    check("a newer version is left alone", s.PH.Of(TANK) == nil and future.players[TANK].lastSeen == 1
        and account.playerHistory == future)
end

do -- the read API's shape
    local s = Boot()
    s.party(tank)
    s.instance = { "Wailing Caverns", "party", 43 }
    s.fire("PLAYER_ENTERING_WORLD", false, false)
    s.chat("CHAT_MSG_PARTY", "hi", "Tank Ironhide", TANK)
    s.now = START + 300
    s.party()
    local rec = s.PH.Of(TANK)
    check("record fields", type(rec.name) == "string" and type(rec.classFile) == "string"
        and type(rec.firstSeen) == "number" and type(rec.lastSeen) == "number" and type(rec.groups) == "number"
        and type(rec.dungeons) == "number" and type(rec.raids) == "number")
    local session, chat = rec.sessions[1], rec.chats[1]
    check("session fields", type(session.at) == "number" and type(session.seconds) == "number"
        and (session.kind == "party" or session.kind == "raid") and type(session.place) == "string"
        and session.instance == "party")
    check("chat fields", type(chat.at) == "number" and type(chat.mine) == "boolean"
        and chat.channel == "PARTY" and type(chat.text) == "string")
    check("Of on a secret or a non-string is nil", s.PH.Of(nil) == nil and s.PH.Of(42) == nil)
    s.PH.SetNote(TANK, "kept", "tank")
    s.PH.Forget(TANK)
    check("Forget drops the history, not the note", s.PH.Of(TANK) == nil and s.PH.Note(TANK).text == "kept")
end

do -- notes, with recording off
    local account = {}
    local s = Boot({ playerHistory = false }, account)
    check("a note works with recording off", s.PH.SetNote(TANK, "solid tank", "tank", "Tank Ironhide") == true)
    local note = s.PH.Note(TANK)
    check("its fields", note.text == "solid tank" and note.tag == "tank" and note.at == START
        and note.name == "Tank Ironhide")
    check("still no events", s.listening() == 0 and s.PH.Of(TANK) == nil)
    check("an unknown tag is refused", s.PH.SetNote(TANK, "x", "best") == false and s.PH.Note(TANK).text == "solid tank")
    check("a note on yourself is refused", s.PH.SetNote(ME, "me") == false)
    check("a note on an NPC is refused", s.PH.SetNote("Creature-0-1", "npc") == false)
    s.PH.SetNote(TANK, "|cffff0000red|r and |Hitem:1|h[Thing]|h\nnext", "avoid")
    check("text cleaned", s.PH.Note(TANK).text == "red and [Thing]next" and s.PH.Note(TANK).tag == "avoid")
    s.PH.SetNote(TANK, ("a"):rep(119) .. "\195\169")
    check("cut at 120 bytes, never inside a letter", s.PH.Note(TANK).text == ("a"):rep(119)
        and s.PH.Note(TANK).tag == nil)
    s.PH.SetNote(TANK, nil, "friendly")
    check("a tag alone", s.PH.Note(TANK).text == nil and s.PH.Note(TANK).tag == "friendly")
    s.PH.SetNote(TANK, "", nil)
    check("no text and no tag clears it", s.PH.Note(TANK) == nil)
    check("TAGS in order with colors", #s.PH.TAGS == 5 and s.PH.TAGS[1].key == "tank" and s.PH.TAGS[5].key == "avoid"
        and s.PH.TAGS[5].color == s.ns.Shared.Style.RED_RGB and s.PH.TAGS[1].color == s.ns.Shared.Style.HAVE_RGB)
end

do -- Clear History keeps notes; Clear Notes is its own action
    local s = Boot()
    s.party(tank, healer)
    s.PH.SetNote(TANK, "good", "tank")
    local clearHistory, clearNotes = s.row("Clear History"), s.row("Clear Notes")
    check("buttons wanted", clearHistory.needs() == true and clearNotes.needs() == true)
    clearHistory.button()
    check("Clear History asks first", s.confirmed ~= nil)
    check("history gone, still grouped players start again", s.PH.Of(HEALER) and s.PH.Of(HEALER).groups == 0)
    s.party()
    s.PH.Forget(TANK)
    s.PH.Forget(HEALER)
    check("nothing left to clear", clearHistory.needs() == false)
    check("notes kept", s.PH.Note(TANK).text == "good")
    clearNotes.button()
    check("Clear Notes clears them", s.PH.Note(TANK) == nil and clearNotes.needs() == false)
end

do -- the note line on tooltips
    local s = Boot()
    s.runTimers()
    s.runTimers()
    check("no hook without a note", #s.posts == 0)
    s.PH.SetNote(TANK, "great pulls", "tank")
    s.runTimers()
    check("hooked two frames later, not one", #s.posts == 0)
    s.runTimers()
    check("hooked once a note exists", #s.posts == 1 and s.posts[1][1] == 2)
    s.PH.SetNote(HEALER, "slow", "avoid")
    s.runTimers()
    s.runTimers()
    check("hooked only once", #s.posts == 1)
    local OnUnit = s.posts[1][2]
    local tip = { n = 0, text = {}, r = {}, wrap = {} }
    function tip:AddLine(text, r, _, _, wrap)
        self.n = self.n + 1
        self.text[self.n], self.r[self.n], self.wrap[self.n] = text, r, wrap
    end
    function tip:IsForbidden() return false end
    local data = { guid = TANK }
    OnUnit(tip, data)
    check("the tag in its color, then the note", tip.n == 2 and tip.text[1] == "Great Tank"
        and tip.r[1] == s.ns.Shared.Style.HAVE_RGB.r and tip.text[2] == "great pulls" and tip.wrap[2] == true)
    tip.n, data.guid = 0, HEALER
    OnUnit(tip, data)
    check("Avoid in red", tip.text[1] == "Avoid" and tip.r[1] == s.ns.Shared.Style.RED_RGB.r)
    s.PH.SetNote(MAGE, "met in Barrens")
    tip.n, data.guid = 0, MAGE
    OnUnit(tip, data)
    check("no tag: Note in the accent", tip.text[1] == "Note" and tip.r[1] == s.ns.THEME.accent.r)
    tip.n, data.guid = 0, "Player-1-0777"
    OnUnit(tip, data)
    check("nobody's note: nothing", tip.n == 0)
    s.secret[TANK] = true
    tip.n, data.guid = 0, TANK
    OnUnit(tip, data)
    check("a secret GUID: nothing", tip.n == 0)
    s.secret[TANK] = nil
    s.S.Set("playerNotesTooltip", false)
    OnUnit(tip, data)
    check("setting off: nothing", tip.n == 0)
    s.S.Set("playerNotesTooltip", true)
    Measure("a player tooltip with a note", 0.05, function() tip.n = 0; OnUnit(tip, data) end)

    local saved = s.account
    s = Boot(nil, saved)
    s.runTimers()
    s.runTimers()
    check("notes saved: hooked at login", #s.posts == 1)
end

do -- garbage: a chat burst and a roster update
    local s = Boot()
    s.party(tank, healer)
    for _ = 1, 10 do
        s.chat("CHAT_MSG_WHISPER", "lol", "Mage Frost", MAGE)
        s.chat("CHAT_MSG_PARTY", "lol", "Tank Ironhide", TANK)
        s.chat("CHAT_MSG_PARTY", "ok", "Die Man", ME)
        s.chat("CHAT_MSG_PARTY", "lol", "Heal Brightwater", HEALER)
    end
    Measure("a whisper burst", 0.05, function() s.chat("CHAT_MSG_WHISPER", "lol", "Mage Frost", MAGE) end)
    Measure("a party chat burst", 0.05, function()
        s.chat("CHAT_MSG_PARTY", "lol", "Tank Ironhide", TANK)
        s.chat("CHAT_MSG_PARTY", "ok", "Die Man", ME)
    end)
    Measure("a stranger's party line", 0.05, function() s.chat("CHAT_MSG_PARTY", "lol", "Mage Frost", MAGE) end)
    Measure("a roster update", 0.05, function() s.fire("GROUP_ROSTER_UPDATE") end)
    Measure("a member joining and leaving", 0.05, function()
        s.units.party2, s.members = healer, 3
        s.fire("GROUP_ROSTER_UPDATE")
        s.units.party2, s.members = nil, 2
        s.fire("GROUP_ROSTER_UPDATE")
    end)
end

print(("PASS player-history: %d checks"):format(checks))

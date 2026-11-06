-- Run with Lua 5.1 from the repository root: the Group Finder. Loads the files its GroupFinder.xml
-- lists, in order, against stubs, then checks it is wired in as a Utilities module and off by default,
-- that nothing is made or registered while it is off, the card and its messages (round trip, size,
-- malformed input, opt-outs), the whispers (rate limit, self, ignored and flooding senders, answering
-- only while listed, names across realms, expiry with stale timers, the "No player named" filter), the
-- listings (activity to dungeon, roles, a failed search, chat lockdown), the search for your level, every
-- dungeon or one, Browse's filter and sorts, the probe, and what the hot paths cost.
local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Locale = dofile("Tools/regression/locale_stub.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end
local Measure = dofile("Tools/regression/measure.lua")(check)
local NOTHING = function() end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

local modules = Read("Core/Options/Modules.lua")
check("the options list it as a Utilities module needing BiS", modules:find(
    '{ name = "Group Finder", group = "UTILITIES", navIcon = "search", settings = "GroupFinderSettings",\r\n'
    .. '      addon = "NaowhForever_GroupFinder", host = "NaowhForever_Utilities",\r\n'
    .. '      needs = { "NaowhForever_BiS" },', 1, true) ~= nil)
local commands = Read("Core/Commands.lua")
check("/nf groupfinder reaches the module", commands:find('cmd == "groupfinder" and ns.GroupFinderCommand', 1, true) ~= nil)
check("the onboarding lists it", Read("Core/Onboarding/Setup.lua"):find(
    'groupFinder = { addon = "NaowhForever_GroupFinder", db = "groupFinder", key = "enabled",', 1, true) ~= nil)
check("the Recommended setup leaves it off", Read("Core/Profiles/Presets.lua"):find('"NaowhForever_GroupFinder" }', 1, true) ~= nil
    and Read("Tools/build/presets.lua"):find('"NaowhForever_GroupFinder" } }', 1, true) ~= nil)

local files = TocFiles("^NaowhForever_Utilities/GroupFinder/.*%.lua$")
check("the module loads its files through its XML", #files == 16 and files[1]:find("GroupFinder.lua$") ~= nil)
local rules = {}
for _, path in ipairs(files) do
    if not (path:find("/View/") or path:find("/UI/") and not path:find("/UI/SettingsPage%.lua$")) then
        rules[#rules + 1] = path
    end
end

local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local OWN_REALM = "-Home"
local RESULT = { Success = 0, AddonMessageThrottle = 3, ChannelThrottle = 8, AddOnMessageLockdown = 11,
    TargetOffline = 12 }

local function Boss(name, encounter, extra)
    local boss = { name = name, encounters = encounter and { encounter } or nil }
    for k, v in pairs(extra or {}) do boss[k] = v end
    return boss
end
local QUESTS = {
    { 168, "Collecting Memories", 14, "A" }, { 167, "Oh Brother", 15, "A" }, { 2040, "Underground Assault", 15, "A" },
    { 166, "The Defias Brotherhood", 22, "A" }, { 214, "Red Silk Bandanas", 17, "A" }, { 373, "The Unsent Letter", 22, "A" },
    { 5761, "Slaying the Beast", 9, "H" }, { 1654, "The Test of Righteousness", 22, "A", class = "PALADIN" },
    { 98815, "A Forever Quest", 20, "B" },
}
local DEADMINES = { key = "Deadmines", name = "The Deadmines", quests = { map = 36, quests = QUESTS }, wings = {
    { bosses = { Boss("Rhahk'Zor", 2741), Boss("Miner Johnson", nil, { rare = true }), Boss("Sneed's Shredder", 2742, { with = "Sneed" }),
        Boss("Sneed", 2742), Boss("Gilnid", 2743), Boss("Mr. Smite", 2745) } },
    { bosses = { Boss("Captain Greenskin", 2746), Boss("Edwin VanCleef", 2747), Boss("Cookie", 2748), Boss("Extra", 2749) } },
} }
local function Dungeon(key, name, map)
    return { key = key, name = name, quests = { map = map, quests = {} }, wings = {} }
end
local DUNGEONS = { DEADMINES,
    Dungeon("ScarletMonasteryGraveyard", "Scarlet Monastery - Graveyard", 189),
    Dungeon("ScarletMonasteryLibrary", "Scarlet Monastery - Library", 189),
    Dungeon("DireMaul", "Dire Maul", 429),
    Dungeon("ExcavationSite", "Excavation Site: Wetlands", 2998),
    Dungeon("SunkenTemple", "Sunken Temple", 109),
    Dungeon("LowerBlackrockSpire", "Lower Blackrock Spire", 229),
    Dungeon("UpperBlackrockSpire", "Upper Blackrock Spire", 229),
}
local BY_KEY = {}
for _, dungeon in ipairs(DUNGEONS) do BY_KEY[dungeon.key] = dungeon end

local ACTIVITIES = {
    [1] = { fullName = "The Deadmines", mapID = 36 },
    [2] = { fullName = "Scarlet Monastery - Graveyard", mapID = 189 },
    [3] = { fullName = "Dire Maul - East", mapID = 429 },
    [4] = { fullName = "Excavation Site", mapID = 2998 },
    [5] = { fullName = "The Temple of Atal'Hakkar", mapID = 109 },
    [6] = { fullName = "Blackrock Spire", mapID = 229 },
    [7] = { fullName = "Stormwind Stockade", mapID = 34 },
    [8] = { fullName = "Scarlet Monastery", mapID = 189 },
}
for id, activity in pairs(ACTIVITIES) do
    activity.shortName, activity.maxNumPlayers = "", 5
    activity.minLevelSuggestion, activity.maxLevelSuggestion = 15 + id, 22 + id
end
ACTIVITIES[1].shortName = "DM"
local CATEGORY_ACTIVITIES = { [1] = { 6, 7 }, [2] = { 1, 2, 3, 4, 5, 6, 7, 8 } }

local RESULTS, INFOS, PLAYERS, COUNTS = {}, {}, {}, {}
for id = 1, 50 do
    RESULTS[id] = id
    INFOS[id] = { searchResultID = id, leaderName = "Leader" .. id, numMembers = id % 5 + 1, age = id * 30,
        isDelisted = false, activityIDs = { (id - 1) % 5 + 1 }, partyGUID = "Party-" .. id, hasSelf = id == 7 }
    COUNTS[id] = { TANK = 1, HEALER = 0, DAMAGER = id % 5, NOROLE = 0 }
    PLAYERS[id] = {}
    for m = 1, 5 do
        PLAYERS[id][m] = { name = "Member" .. id .. "-" .. m, level = 20 + m, classFilename = "WARRIOR",
            assignedRole = m == 1 and "TANK" or "DAMAGER", isLeader = m == 1,
            lfgRoles = { tank = m == 1, healer = false, dps = m ~= 1 } }
    end
end

local function Fixture(values)
    local state = {
        now = 1000, frames = 0, events = {}, prefixes = {}, sent = {}, timers = {}, printed = {},
        filters = {}, ignored = {}, locked = false, listed = true, result = 0, infoCalls = 0, searches = {},
        onQuest = {}, complete = {}, done = {}, minLevel = {}, level = 20, score = 18.9, scoreComplete = true,
        kills = { [2741] = { n = 3 }, [2742] = { n = 2 }, [2743] = { n = 0 }, [2746] = { n = 120 }, [2747] = { n = 1 } },
        bis = true, roles = { tank = true, healer = false, dps = true },
    }
    local settings = {}
    for k, v in pairs(values or {}) do settings[k] = v end
    local function ModuleSettings(_, defaults)
        state.defaults = defaults
        local listeners, S = {}, {}
        function S.Get(key)
            local v = settings[key]
            if v == nil then return defaults[key] end
            return v
        end
        function S.Set(key, value)
            settings[key] = value
            for i = 1, #listeners do listeners[i](key, value) end
        end
        function S.OnChange(fn) listeners[#listeners + 1] = fn end
        return S
    end
    local frameMethods = {
        SetScript = function(frame, _, fn) frame.onEvent = fn end,
        RegisterEvent = function(frame, event)
            if frame.events[event] then return end
            frame.events[event] = true
            state.events[event] = (state.events[event] or 0) + 1
        end,
        UnregisterAllEvents = function(frame)
            for event in pairs(frame.events) do
                frame.events[event] = nil
                state.events[event] = state.events[event] - 1
                if state.events[event] == 0 then state.events[event] = nil end
            end
        end,
    }
    state.frameList = {}
    local cards = {}
    local pages = {}
    local Journal = {
        Get = function(key) return BY_KEY[key] end,
        Dungeons = function() return DUNGEONS end,
        Suggested = function() return DEADMINES end,
        Kills = {
            Counted = function(boss) return boss.encounters ~= nil end,
            Count = function(boss)
                local record = state.kills[boss.encounters[1]]
                return record and record.n or 0
            end,
        },
        Quests = {
            ForMe = function(quest)
                return (quest[4] == "A" or quest[4] == "B") and (quest.class == nil or quest.class == "WARRIOR")
            end,
            Kind = function(quest)
                local id = quest[1]
                if state.onQuest[id] then return state.complete[id] and "ready" or "active" end
                if state.done[id] then return "done" end
                if state.minLevel[id] and state.level < state.minLevel[id] then return "low" end
                return "pickup"
            end,
            InLog = function(kind) return kind == "active" or kind == "ready" end,
        },
    }
    local BIS_LIST = { slots = {} }
    local SPEC = { key = "fury-warrior", name = "Fury Warrior" }
    local ns = {
        Apply = NOTHING,
        L = Locale.L,
        Journal = Journal,
        Print = function(text) state.printed[#state.printed + 1] = text end,
        UI = { ModuleSettings = ModuleSettings, RefreshPage = NOTHING },
        Shared = { Settings = {
            Page = function(key, store)
                local page = { key = key, store = store }
                function page.Card(_, spec) cards[#cards + 1] = spec end
                function page.Window(_, spec) page.window = spec end
                pages[key] = page
                return page
            end,
        } },
        NaowhScore = { Unit = function() return state.score, state.scoreComplete end },
        BiS = {
            On = function() return state.bis end,
            Lists = { List = function() return BIS_LIST end, CurrentSpec = function() return SPEC end },
            Rankings = { Had = function() return 8, 14 end },
        },
    }
    state.cards, state.pages, state.ns = cards, pages, ns
    local env = setmetatable({
        NaowhForever = ns,
        Enum = { SendAddonMessageResult = RESULT },
        issecretvalue = function(v) return rawequal(v, SECRET) end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
        hooksecurefunc = function(t, name, fn)
            local original = t[name]
            t[name] = function(...) original(...); fn(...) end
        end,
        Ambiguate = function(name) return (name:gsub(OWN_REALM .. "$", "")) end,
        CreateFrame = function()
            state.frames = state.frames + 1
            local frame = setmetatable({ events = {} }, { __index = frameMethods })
            state.frameList[#state.frameList + 1] = frame
            return frame
        end,
        GetTime = function() return state.now end,
        C_Timer = { After = function(delay, fn) state.timers[#state.timers + 1] = { at = state.now + delay, fn = fn } end },
        C_ChatInfo = {
            RegisterAddonMessagePrefix = function(prefix) state.prefixes[#state.prefixes + 1] = prefix end,
            SendAddonMessage = function(prefix, text, channel, target)
                if state.result ~= RESULT.AddonMessageThrottle and state.result ~= RESULT.AddOnMessageLockdown then
                    state.sent[#state.sent + 1] = { prefix = prefix, text = text, channel = channel, target = target }
                end
                return state.result
            end,
            InChatMessagingLockdown = function() return state.locked end,
        },
        ChatFrameUtil = {
            AddMessageEventFilter = function(event, fn) state.filters[event] = fn end,
            RemoveMessageEventFilter = function(event, fn)
                if state.filters[event] == fn then state.filters[event] = nil end
            end,
        },
        ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing.",
        C_FriendList = { IsIgnored = function(name) return state.ignored[name] == true end },
        C_LFGListRoles = { GetRoles = function() return state.roles end },
        C_LFGList = {
            GetFilteredSearchResults = function() return #RESULTS, RESULTS end,
            GetSearchResultInfo = function(id)
                state.infoCalls = state.infoCalls + 1
                return INFOS[id]
            end,
            GetSearchResultPlayerInfo = function(id, m) return PLAYERS[id] and PLAYERS[id][m] end,
            GetActivityInfoTable = function(id) return ACTIVITIES[id] end,
            HasActiveEntryInfo = function() return state.listed end,
            GetActiveEntryInfo = function() return state.entry end,
            GetSearchResultMemberCounts = function(id) return COUNTS[id] end,
            GetAvailableCategories = function() return { 1, 2 } end,
            GetAvailableActivities = function(category)
                local list = {}
                for i, id in ipairs(CATEGORY_ACTIVITIES[category]) do list[i] = id end
                return list
            end,
            Search = function(...) state.searches[#state.searches + 1] = { ... } end,
            CreateListing = function(data)
                state.created = { activity = data.activityIDs[1], style = data.generalPlaystyle }
                state.listed = state.listOk
                return state.listOk
            end,
            UpdateListing = function(data)
                state.updated = { activity = data.activityIDs[1], style = data.generalPlaystyle }
                return true
            end,
            RemoveListing = function() state.removed, state.listed = true, false end,
        },
        C_PartyInfo = { InviteUnit = function(name) state.invited = name end },
        IsInGroup = function() return state.inGroup == true end,
        UnitIsGroupLeader = function() return state.leader ~= false end,
        LE_PARTY_CATEGORY_HOME = 1,
        C_AddOns = { IsAddOnLoaded = function() return true end },
        UnitClass = function() return "Warrior", "WARRIOR", 1 end,
        UnitLevel = function() return state.level end,
        GetUnitName = function() return "Die Man" end,
        GetClassInfo = function(id) return id == 1 and "Warrior" or "Class" .. id end,
    }, { __index = _G })
    env._G = env
    state.env = env
    Load({ "Core/Features.lua" }, env)
    Load(rules, env)
    ns.Apply()
    state.GF = ns.GroupFinder
    state.S = ns.GroupFinderSettings
    function state.Advance(seconds)
        local target = state.now + seconds
        while true do
            local first
            for i, timer in ipairs(state.timers) do
                if timer.at <= target and (not first or timer.at < state.timers[first].at) then first = i end
            end
            if not first then break end
            local timer = table.remove(state.timers, first)
            if timer.at > state.now then state.now = timer.at end
            timer.fn()
        end
        state.now = target
    end
    function state.Frame(event)
        for _, frame in ipairs(state.frameList) do
            if frame.events[event] then return frame end
        end
    end
    return state
end

local function Count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

do
    local state = Fixture()
    local GF = state.GF
    check("the module is off by default", state.defaults.enabled == false and GF.On() == false)
    check("its switch is the one in Core/Features.lua", state.env.NaowhForever.FEATURES.groupFinder.enabled == false)
    check("the card shares everything once it is on", state.defaults.shareScore == true
        and state.defaults.shareKills == true and state.defaults.shareQuests == true and state.defaults.shareBis == true)
    check("off: no frame made", state.frames == 0)
    check("off: no event registered", Count(state.events) == 0)
    check("off: no prefix registered", #state.prefixes == 0)
    check("off: no chat filter", next(state.filters) == nil)
    check("off: no timer", #state.timers == 0)
    check("off: nothing sent", GF.Comms.Ping("Bob") == nil and #state.sent == 0)
    check("off: the comms are not listening", GF.Comms.On() == false)
    check("off: a filter call left behind hides nothing",
        GF.Comms.Filter(nil, "CHAT_MSG_SYSTEM", "No player named 'Bob' is currently playing.") == false)

    state.S.Set("enabled", true)
    check("on: the prefix registered once", #state.prefixes == 1 and state.prefixes[1] == "NaowhLFG")
    check("on: addon messages heard", state.events.CHAT_MSG_ADDON == 1)
    check("on: Forever's search results heard", state.events.LFG_LIST_SEARCH_RESULTS_RECEIVED == 1
        and state.events.LFG_LIST_SEARCH_RESULT_UPDATED == 1 and state.events.LFG_LIST_SEARCH_FAILED == 1)
    check("on: the 'No player named' filter installed", state.filters.CHAT_MSG_SYSTEM == GF.Comms.Filter)
    local made = state.frames
    state.S.Set("enabled", false)
    check("off again: every event unregistered", Count(state.events) == 0)
    check("off again: the filter removed", state.filters.CHAT_MSG_SYSTEM == nil)
    state.S.Set("enabled", true)
    check("on again: the frames are reused", state.frames == made)
    check("on again: the prefix is not registered twice", #state.prefixes == 1)
    state.ns.Apply()
    check("a profile reload keeps one registration each", state.events.CHAT_MSG_ADDON == 1)

    check("the settings page declares one card", #state.cards == 1 and state.pages["Group Finder/Settings"] ~= nil)
    local card = state.cards[1]
    check("the card has four switches", #card.rows == 4)
    for _, row in ipairs(card.rows) do
        check(row.label .. "'s help is one short sentence", #row.help < 100 and select(2, row.help:gsub("%.", "")) == 1)
        check(row.label .. " waits for the module", row.needs ~= nil)
    end
    check("the card's help is one short sentence", #card.help < 100 and select(2, card.help:gsub("%.", "")) == 1)
end

do
    local ns = { L = Locale.L, UI = {}, Apply = NOTHING }
    local made = {}
    ns.UI.ModuleSettings = function(key, defaults)
        made[#made + 1] = key
        return { Get = function(k) return defaults[k] end, OnChange = NOTHING }
    end
    local env = setmetatable({ NaowhForever = ns, C_AddOns = { IsAddOnLoaded = function() return false end },
        CreateFrame = function() error("a frame was made without the BiS List") end }, { __index = _G })
    env._G = env
    Load({ "Core/Features.lua" }, env)
    Load(files, env)
    check("without the BiS List its switch still reads its saved value", made[1] == "groupFinder"
        and ns.GroupFinderSettings ~= nil)
    check("and nothing else is made: no module, no command", ns.GroupFinder == nil and ns.GroupFinderCommand == nil)
end

local function Same(a, b)
    if a.class ~= b.class or a.level ~= b.level or a.roles ~= b.roles or a.spec ~= b.spec or a.score ~= b.score
        or a.bisHave ~= b.bisHave or a.bisTotal ~= b.bisTotal or a.dungeon ~= b.dungeon
        or a.hasKills ~= b.hasKills or a.hasQuests ~= b.hasQuests or a.nKills ~= b.nKills
        or a.nHave ~= b.nHave or a.nNeed ~= b.nNeed then
        return false
    end
    for _, list in ipairs({ "kills", "have", "need" }) do
        if #a[list] ~= #b[list] then return false end
        for i = 1, #a[list] do
            if a[list][i] ~= b[list][i] then return false end
        end
    end
    return true
end

local SIZES = {}
do
    local state = Fixture({ enabled = true })
    local Card = state.GF.Card
    state.onQuest[168], state.onQuest[2040], state.complete[2040] = true, true, true
    state.done[167] = true
    state.minLevel[373] = 30
    local mine = Card.Mine("Deadmines")
    check("your card: class and level", mine.class == 1 and mine.level == 20)
    check("your card: the game's saved roles", mine.roles == Card.TANK + Card.DAMAGE)
    check("your card: the BiS list's spec", mine.spec == "fury-warrior")
    check("your card: the Naowh Score in tenths", mine.score == 189)
    check("your card: BiS have and total", mine.bisHave == 8 and mine.bisTotal == 14)
    check("your card: kills of each counted boss, in order, capped",
        mine.hasKills and mine.nKills == 8 and table.concat(mine.kills, ",") == "3,2,0,0,99,1,0,0")
    check("your card: quests in your log, and those you still need, for you only",
        mine.hasQuests and table.concat(mine.have, ",") == "168,2040" and table.concat(mine.need, ",") == "166,214,98815")
    state.scoreComplete = false
    state.score = 1
    check("a score read before your items load keeps the last whole one", Card.Mine("Deadmines").score == 189)
    state.scoreComplete, state.score = true, 18.9

    local reply = Card.Reply(42, mine)
    SIZES.reply = #reply
    check("a card reply is one line, with no GUID", reply == "1 C 42 1 20 TD fury-warrior 189 8/14 Deadmines "
        .. "3,2,0,0,99,1,0,0 168,2040/166,214,98815")
    local back = Card.New()
    local _
    local kind, id, note = Card.Decode(reply, back)
    check("a card reply reads back", kind == "C" and id == 42 and note == nil and Same(back, mine))

    local apply = Card.Application(7, mine, Card.CleanNote("  Tank,   |cffff0000quests|r welcome  "))
    SIZES.apply = #apply
    kind, id, note = Card.Decode(apply, back)
    check("an application reads back with its note", kind == "A" and id == 7 and Same(back, mine))
    check("the note keeps no escape codes", note == "Tank, quests welcome")

    local ask = Card.Ask(9, "Deadmines")
    SIZES.ask = #ask
    kind, id, note = Card.Decode(ask, back)
    check("a card request reads back", ask == "1 Q 9 Deadmines" and kind == "Q" and id == 9 and note == "Deadmines")
    kind, id, note = Card.Decode(Card.Ask(10), back)
    check("a card request without a dungeon", kind == "Q" and id == 10 and note == nil)
    for _, short in ipairs({ "K", "X", "D" }) do
        local text = Card.Short(short, 77)
        SIZES[short] = #text
        kind, id = Card.Decode(text, back)
        check(short .. " reads back", text == "1 " .. short .. " 77" and kind == short and id == 77)
    end

    check("a note is cleaned: printable ASCII, one space between words, 60 bytes at most",
        Card.CleanNote("a\tb\226\128\148c  d|Hitem:6948|h[Hearthstone]|h |TInterface\\Icons\\x:0|t!") == "a bc d[Hearthstone] !"
        and #Card.CleanNote(string.rep("word ", 30)) <= Card.NOTE_MAX
        and Card.CleanNote(nil) == "")

    local big = Card.New()
    big.class, big.level, big.roles, big.spec, big.score = 11, 60, 7, "restoration-shaman-healer-pvp-ab", 99999
    big.bisHave, big.bisTotal, big.dungeon = 40, 40, "ScarletMonasteryCathedralAndMoreWingsXY"
    big.hasKills, big.nKills, big.hasQuests, big.nHave, big.nNeed = true, Card.MAX_KILLS, true, Card.MAX_QUESTS, Card.MAX_QUESTS
    for i = 1, Card.MAX_KILLS do big.kills[i] = Card.KILL_CAP end
    for i = 1, Card.MAX_QUESTS do big.have[i], big.need[i] = 900000 + i, 990000 + i end
    local longNote = Card.CleanNote(string.rep("x", 80))
    local biggest = Card.Application(Card.ID_MAX, big, longNote)
    check("an application at every limit still fits in one message", biggest and #biggest <= Card.MAX_BYTES)
    kind, _, note = Card.Decode(biggest, back)
    check("it reads back with its note, its quests and then its kills left off to fit", kind == "A"
        and note == longNote and back.hasQuests and back.nHave == 0 and back.nNeed == 0 and not back.hasKills)

    big.spec, big.score, big.dungeon = "beast-mastery-hunter", 612, "DireMaul"
    big.nKills = 19
    for i = 20, Card.MAX_KILLS do big.kills[i] = nil end
    for i = 1, Card.MAX_QUESTS do big.have[i], big.need[i] = 98800 + i, 98900 + i end
    biggest = Card.Application(Card.ID_MAX, big, longNote)
    SIZES.biggest = #biggest
    kind, _, note = Card.Decode(biggest, back)
    check("the biggest real application (Dire Maul's 19 bosses, a full note) keeps every kill",
        kind == "A" and note == longNote and back.nKills == 19 and back.nHave > 0 and back.nHave < Card.MAX_QUESTS)
    local fullReply = Card.Reply(Card.ID_MAX, big)
    check("the biggest reply fits", #fullReply <= Card.MAX_BYTES and Card.Decode(fullReply, back) == "C")

    local GOOD = "1 C 42 1 20 TD fury-warrior 154 8/14 Deadmines 3,2,0 168/166"
    check("a well-formed reply passes", Card.Decode(GOOD, back) == "C")
    local BAD = {
        "", "1", "2 C 42 1 20 TD - - - - - -", "1 Z 42", "1 C Player-1-2 42 1 20 TD - - - - - -",
        "1 K 0", "1 K 12345", "1 K 4 extra", "1 K 4 ", "1 K  4", "1 K -4",
        GOOD .. " extra", GOOD .. " ",
        GOOD:gsub(" TD ", " DT "), GOOD:gsub(" TD ", " TT "), GOOD:gsub(" TD ", " X "),
        GOOD:gsub(" 42 1 20 ", " 42 1 0 "), GOOD:gsub(" 42 1 20 ", " 42 1 101 "), GOOD:gsub(" 42 1 20 ", " 42 0 20 "),
        GOOD:gsub(" 8/14 ", " 15/14 "), GOOD:gsub(" 8/14 ", " 8/0 "), GOOD:gsub(" 8/14 ", " 8-14 "),
        GOOD:gsub(" 154 ", " 15.4 "), GOOD:gsub("fury%-warrior", "Fury"), GOOD:gsub(" Deadmines ", " deadmines "),
        GOOD:gsub(" Deadmines ", " - "), GOOD:gsub(" 3,2,0 ", " 3,,0 "), GOOD:gsub(" 3,2,0 ", " 3,2, "),
        GOOD:gsub(" 3,2,0 ", " 100 "), GOOD:gsub(" 3,2,0 ", " " .. string.rep("1,", 30) .. "1 "),
        GOOD:gsub(" 168/166$", " 168"), GOOD:gsub(" 168/166$", " 168/1/66"), GOOD:gsub(" 168/166$", " 0/166"),
        GOOD:gsub(" 168/166$", " 1,2,3,4,5,6,7,8,9/"),
        "1 A 42 1 20 TD - - - Deadmines 3 / note|cff", "1 A 42 1 20 TD - - - - - - " .. string.rep("n", 61),
        "1 Q 4 Deadmines extra", "1 Q 4 dead",
        string.rep("1", 256),
    }
    for i, text in ipairs(BAD) do
        check("malformed message " .. i .. " is rejected", Card.Decode(text, back) == nil)
    end
    check("a number is not a message", Card.Decode(12, back) == nil)
    check("a reply needs a card to fill", Card.Decode(GOOD, nil) == nil)

    state.S.Set("shareScore", false)
    state.S.Set("shareKills", false)
    local partial = Card.Mine("Deadmines")
    check("opted out of score and kills: neither is on the card", partial.score == nil and not partial.hasKills)
    local text = Card.Reply(1, partial)
    check("opted out fields go as -", text:find(" fury%-warrior %- 8/14 Deadmines %- 168,2040/166,214,98815$") ~= nil)
    Card.Decode(text, back)
    check("and read back as not shared", back.score == nil and back.hasKills == false and back.hasQuests == true)
    state.S.Set("shareQuests", false)
    state.S.Set("shareBis", false)
    text = Card.Reply(1, Card.Mine("Deadmines"))
    check("all four off: class, level, roles and spec only", text == "1 C 1 1 20 TD fury-warrior - - Deadmines - -")
    Card.Decode(text, back)
    check("and none of them read back", back.score == nil and back.bisTotal == nil and not back.hasKills and not back.hasQuests)
    state.bis = false
    text = Card.Reply(1, Card.Mine(nil, 0))
    check("BiS List off and no dungeon: no spec, no dungeon, no roles", text == "1 C 1 1 20 - - - - - - -")
    check("an unknown dungeon is left off", Card.Mine("Nowhere").dungeon == nil)
    state.ns.Journal = nil
    check("without the Journal the card has no dungeon", Card.Mine("Deadmines").dungeon == nil)
end

do
    local state = Fixture({ enabled = true })
    local GF = state.GF
    local Comms, Card = GF.Comms, GF.Card
    local fired = {}
    for _, what in ipairs({ "card", "noreply", "offline", "applicant", "received", "declined", "withdrawn", "expired",
        "applicantExpired" }) do
        GF.Listen(what, function(a) fired[#fired + 1] = what; fired[what] = a end)
    end

    for i = 1, 15 do Comms.Ping("Player" .. i) end
    check("a burst of ten goes at once", #state.sent == Comms.BURST)
    check("the rest wait in the queue", Comms.Queued() == 5)
    check("every one is a whisper on the prefix", state.sent[1].channel == "WHISPER" and state.sent[1].prefix == "NaowhLFG"
        and state.sent[1].target == "Player1")
    state.Advance(1)
    check("then one a second", #state.sent == Comms.BURST + 1)
    state.Advance(4)
    check("until the queue is empty", #state.sent == 15 and Comms.Queued() == 0)
    check("the same whisper twice while it waits is queued once", Comms.Send("Bob", "1 K 1")
        and Comms.Send("Bob", "1 K 1") and Comms.Queued() == 1)
    state.Advance(20)
    check("and goes once", #state.sent == 16)

    state.locked = true
    Comms.Send("Bob", "1 K 2")
    check("nothing goes in chat lockdown", #state.sent == 16 and Comms.Queued() == 1)
    state.locked = false
    state.Advance(2)
    check("it goes once the lockdown ends", #state.sent == 17)
    state.result = RESULT.AddonMessageThrottle
    Comms.Send("Bob", "1 K 3")
    check("the game's throttle keeps it queued", Comms.Queued() == 1)
    state.result = 0
    state.Advance(1)
    check("and it goes a second later", Comms.Queued() == 0 and #state.sent == 18)
    for i = 1, Comms.QUEUE_MAX + 5 do
        state.locked = true
        Comms.Send("Q" .. i, "1 K " .. i)
    end
    check("the queue is bounded", Comms.Queued() == Comms.QUEUE_MAX)
    state.locked = false
    state.Advance(60)
    check("and drains", Comms.Queued() == 0)
    state.Advance(Comms.BURST / Comms.RATE)

    local before = #state.sent
    Comms.OnMessage(Card.Ask(5, "Deadmines"), "Die Man")
    check("a message from yourself is dropped", Comms.dropped.self == 1 and #state.sent == before)
    Comms.OnMessage(Card.Ask(5, "Deadmines"), "die man-Home")
    check("so is one from your name on your own realm", Comms.dropped.self == 2 and #state.sent == before)
    Comms.OnMessage(Card.Ask(5, "Deadmines"), "Die Man-Elsewhere")
    check("but your name on another realm is someone else", Comms.dropped.self == 2 and #state.sent == before + 1)
    before = #state.sent
    state.ignored["Rude Guy"] = true
    Comms.OnMessage("1 Q 5 -", "Rude Guy-Home")
    check("an ignored player is dropped", Comms.dropped.ignored == 1 and #state.sent == before)
    Comms.OnMessage("1 Q nonsense", "Bob")
    check("a malformed message is dropped", Comms.dropped.malformed == 1 and #state.sent == before)

    state.listed = false
    Comms.OnMessage("1 Q 5 Deadmines", "Bob")
    check("a card request while you are not listed is not answered", Comms.dropped.unlisted == 1 and #state.sent == before)
    state.listed = true
    Comms.OnMessage("1 Q 5 Deadmines", "Bob")
    check("a card request while you are listed is answered with your card for that dungeon", #state.sent == before + 1
        and state.sent[#state.sent].target == "Bob"
        and state.sent[#state.sent].text:find("^1 C 5 1 20 TD fury%-warrior %d+ 8/14 Deadmines ") ~= nil)
    Comms.OnMessage("1 Q 6 Deadmines", "Bob")
    check("the same player is answered once per gap", Comms.dropped.answered == 1 and #state.sent == before + 1)
    state.Advance(Comms.ANSWER_GAP)
    before = #state.sent
    for i = 1, Comms.ANSWERS_MAX + 2 do Comms.OnMessage("1 Q " .. i .. " -", "Browser" .. i) end
    check("answers are capped per window, so browsers cannot fill your queue",
        #state.sent == before + Comms.ANSWERS_MAX and Comms.dropped.answered == 3)
    state.Advance(Comms.ANSWERS_WINDOW)
    Comms.OnMessage("1 Q 9 -", "Browser99")
    check("and answered again in the next window", #state.sent == before + Comms.ANSWERS_MAX + 1)

    for _ = 1, Comms.SENDER_MAX + 3 do Comms.OnMessage("1 Q 6 -", "Spammer") end
    check("a sender over its cap is dropped", Comms.dropped.flood == 3)
    state.Advance(Comms.SENDER_WINDOW + 1)
    Comms.OnMessage("1 Q 6 -", "Spammer")
    check("and heard again after its window", Comms.dropped.flood == 3)

    local nonce = Comms.Ping("Carol", "Deadmines")
    local asked = state.sent[#state.sent].text
    check("a ping asks for a card", asked == "1 Q " .. nonce .. " Deadmines")
    Comms.OnMessage("1 C " .. (nonce + 1) .. " 1 20 TD - - - - - -", "Carol")
    check("a card nobody asked for is dropped", Comms.dropped.unasked == 1 and fired.card == nil)
    Comms.OnMessage("1 C " .. nonce .. " 1 20 TD - - - - - -", "Bob")
    check("a card from someone else with the right number is dropped", Comms.dropped.unasked == 2 and fired.card == nil)
    state.now = state.now + 0.25
    Comms.OnMessage("1 C " .. nonce .. " 5 31 H - 264 3/9 Deadmines 1,0,2 /166", "Carol-OtherRealm")
    check("the answer to a ping by bare name comes back from their realm as a card", fired.card ~= nil
        and Comms.CardOf("Carol-OtherRealm").level == 31)
    check("the ping is done with", #Comms.pings == 0)
    check("the probe can describe it", GF.Describe(Comms.CardOf("carol-otherrealm")):find(
        "score 26.4; BiS 3/9; Deadmines; kills 1,0,2; quests 0 in log, 1 needed", 1, true) ~= nil)
    fired.card = nil
    nonce = Comms.Ping("Dan-East")
    Comms.OnMessage("1 C " .. nonce .. " 1 20 TD - - - - - -", "Dan-West")
    check("a namesake on another realm does not answer for them", fired.card == nil and #Comms.pings == 1)
    Comms.OnMessage("1 C " .. nonce .. " 1 22 TD - - - - - -", "Dan-East")
    check("and their cards are kept apart", Comms.CardOf("Dan-East").level == 22 and Comms.CardOf("Dan-West") == nil)

    local id = Comms.Apply("Dave", "Deadmines", Card.HEALER, "Can heal, need 2 quests")
    local sentApp = state.sent[#state.sent].text
    check("an application whispers your card with your roles and note", sentApp:find("^1 A " .. id
        .. " 1 20 H fury%-warrior %d+ 8/14 Deadmines .- Can heal, need 2 quests$") ~= nil)
    Comms.OnMessage("1 K " .. id, "Dave")
    check("the leader's K marks it received", fired.received ~= nil and Comms.sent[1].acked == true)
    Comms.OnMessage("1 D " .. id, "Dave")
    check("a decline marks it and says so, and it still just expires", Comms.sent[1].declined == true
        and fired.declined == Comms.sent[1] and fired.expired == nil)

    state.listed = false
    Comms.OnMessage("1 A 12 3 25 D - 201 - Deadmines 2,2 / Hi there", "Erin")
    check("an application while you are not listed is dropped", Comms.dropped.unlisted == 2 and #Comms.applicants == 0)
    state.listed = true
    Comms.OnMessage("1 A 12 3 25 D - 201 - Deadmines 2,2 / Hi there", "Erin")
    local applicant = Comms.applicants[1]
    check("an application is kept with its card and note", fired.applicant == applicant and applicant.note == "Hi there"
        and applicant.card.class == 3 and applicant.card.score == 201 and applicant.name == "Erin")
    check("and acknowledged with K", state.sent[#state.sent].text == "1 K 12" and state.sent[#state.sent].target == "Erin")
    Comms.OnMessage("1 X 12", "Erin")
    check("a withdrawal takes the applicant off", fired.withdrawn ~= nil and #Comms.applicants == 0)
    Comms.OnMessage("1 A 13 3 25 D - - - - - -", "Finn")
    check("declining whispers D and takes the applicant off", Comms.Decline("finn") and #Comms.applicants == 0
        and state.sent[#state.sent].text == "1 D 13")
    check("withdrawing your application whispers X", Comms.Withdraw(id) and #Comms.sent == 0
        and state.sent[#state.sent].text == "1 X " .. id)

    local frame = state.Frame("CHAT_MSG_ADDON")
    before = #state.sent
    frame:onEvent("CHAT_MSG_ADDON", "NaowhLFG", "1 Q 1 -", "WHISPER", SECRET)
    frame:onEvent("CHAT_MSG_ADDON", "NaowhLFG", SECRET, "WHISPER", "Gil")
    frame:onEvent("CHAT_MSG_ADDON", SECRET, "1 Q 1 -", "WHISPER", "Gil")
    check("secret arguments are never read", Comms.dropped.secret == 2 and #state.sent == before)
    frame:onEvent("CHAT_MSG_ADDON", "NaowhLFG", "1 Q 1 -", "PARTY", "Gil")
    frame:onEvent("CHAT_MSG_ADDON", "OtherAddon", "1 Q 1 -", "WHISPER", "Gil")
    check("only whispers on the prefix are heard", #state.sent == before)
    frame:onEvent("CHAT_MSG_ADDON", "NaowhLFG", "1 Q 1 -", "WHISPER", "Gil")
    check("a whisper on the prefix is answered", #state.sent == before + 1 and state.sent[#state.sent].target == "Gil")
end

do
    local state = Fixture({ enabled = true })
    local GF = state.GF
    local Comms = GF.Comms
    local fired = {}
    GF.Listen("noreply", function(ping) fired[#fired + 1] = "noreply " .. ping.name end)
    GF.Listen("expired", function(app) fired[#fired + 1] = "expired " .. app.name end)
    Comms.Apply("Leader", "Deadmines", 1, "")
    check("an application schedules the sweep", #state.timers == 1)
    local stale = state.timers[1]
    Comms.Ping("Pinged")
    check("a sooner ping schedules a sooner sweep", #state.timers == 2 and state.timers[2].at < stale.at)
    table.remove(state.timers, 1)
    state.now = stale.at
    stale.fn()
    check("the superseded sweep does nothing", #fired == 0 and #Comms.sent == 1 and #Comms.pings == 1)
    check("and says it was stale", Comms.Sweep(-1) == false)
    state.now = 1000
    state.Advance(Comms.PING_WAIT)
    check("the ping expires with no answer", fired[1] == "noreply Pinged" and #Comms.pings == 0)
    check("and the next sweep waits for the application", #state.timers == 1)
    local later = state.timers[1]
    state.S.Set("enabled", false)
    table.remove(state.timers, 1)
    state.now = later.at
    later.fn()
    check("turning it off makes a pending sweep stale", #fired == 1)
    state.S.Set("enabled", true)
    state.now = 1000
    Comms.Apply("Leader", "Deadmines", 1, "")
    state.Advance(Comms.APP_TTL)
    check("an application expires after its time", fired[#fired] == "expired Leader" and #Comms.sent == 0)
end

do
    local state = Fixture({ enabled = true })
    local GF = state.GF
    local Comms = GF.Comms
    local offline
    GF.Listen("offline", function(ping) offline = ping.name end)
    local filter = state.filters.CHAT_MSG_SYSTEM
    Comms.Ping("Hal Brand")
    check("the line for a name just whispered is hidden",
        filter(nil, "CHAT_MSG_SYSTEM", "No player named 'Hal Brand' is currently playing.") == true)
    check("and its ping ends as offline", offline == "Hal Brand" and #Comms.pings == 0)
    check("the line for anyone else stays",
        filter(nil, "CHAT_MSG_SYSTEM", "No player named 'Ivy' is currently playing.") == false)
    check("other system lines stay", filter(nil, "CHAT_MSG_SYSTEM", "You are now AFK.") == false)
    check("a secret line is not read", filter(nil, "CHAT_MSG_SYSTEM", SECRET) == false)
    state.Advance(Comms.NOT_FOUND_WINDOW + 1)
    check("the name's line shows again after a moment",
        filter(nil, "CHAT_MSG_SYSTEM", "No player named 'Hal Brand' is currently playing.") == false)
    Comms.Ping("Jo")
    state.S.Set("enabled", false)
    check("off: the filter is gone and hides nothing", state.filters.CHAT_MSG_SYSTEM == nil
        and filter(nil, "CHAT_MSG_SYSTEM", "No player named 'Jo' is currently playing.") == false)
    state.S.Set("enabled", true)
    state.result = RESULT.TargetOffline
    offline = nil
    Comms.Ping("Kim")
    check("the game's own offline answer ends the ping too", offline == "Kim" and #Comms.pings == 0)
end

do
    local state = Fixture({ enabled = true })
    local Listings = state.GF.Listings
    local Card = state.GF.Card
    check("an activity named as the dungeon", Listings.DungeonOf(1) == "Deadmines")
    check("a Scarlet Monastery wing by its name", Listings.DungeonOf(2) == "ScarletMonasteryGraveyard")
    check("a dungeon's part by its prefix", Listings.DungeonOf(3) == "DireMaul")
    check("a shorter name when only one dungeon fits", Listings.DungeonOf(4) == "ExcavationSite")
    check("another name by its instance", Listings.DungeonOf(5) == "SunkenTemple")
    check("an instance two dungeons share is not guessed", Listings.DungeonOf(6) == nil)
    check("a name that fits several wings is not guessed", Listings.DungeonOf(8) == nil)
    check("a dungeon the Journal lacks is none", Listings.DungeonOf(7) == nil and Listings.DungeonOf(99) == nil)

    local n = Listings.Read()
    check("fifty listings read", n == 50 and Listings.state == "ready")
    local entry = Listings.entries[4]
    check("a listing's leader, dungeon, size and age", entry.leader == "Leader4" and entry.dungeon == "ExcavationSite"
        and entry.numMembers == 5 and entry.age == 120 and entry.delisted == false and entry.party == "Party-4")
    check("its members, up to five, with the roles they signed up as", entry.nMembers == 5
        and entry.members[1].roles == Card.TANK and entry.members[2].roles == Card.DAMAGE
        and entry.members[1].leader and entry.members[2].level == 22 and entry.members[1].class == "WARRIOR")
    check("its role counts", entry.tanks == 1 and entry.healers == 0 and entry.damage == 4)
    check("your own listing is marked", Listings.entries[7].mine == true and entry.mine == false)
    local activity = Listings.Activity(1)
    check("an activity's name, short name, levels and size", activity.name == "The Deadmines" and activity.short == "DM"
        and activity.min == 16 and activity.max == 23 and activity.size == 5)
    check("its short name is its full name when the game has none",
        Listings.Activity(2).short == "Scarlet Monastery - Graveyard")
    check("each activity is read once", Listings.Activity(1) == activity and Listings.Activity(99) == nil)
    COUNTS[4].TANK = SECRET
    Listings.Read(true)
    check("secret role counts count nothing", entry.tanks == 0 and entry.damage == 0)
    COUNTS[4].TANK = 1
    local calls = state.infoCalls
    check("a second read without a new search reads nothing", Listings.Read() == 50 and state.infoCalls == calls)

    state.locked = true
    calls = state.infoCalls
    check("chat lockdown: nothing read", Listings.Read(true) == 0 and Listings.state == "locked" and state.infoCalls == calls)
    state.locked = false
    INFOS[2].leaderName = SECRET
    check("a listing with a secret leader is skipped", Listings.Read() == 49)
    INFOS[2].leaderName = nil
    check("a leader the game has not named yet is kept, unnamed", Listings.Read(true) == 50
        and Listings.entries[2].leader == nil)
    INFOS[2].leaderName = "Leader2"
    PLAYERS[3][2].lfgRoles.dps = SECRET
    Listings.Read(true)
    check("a member with a secret role is left out", Listings.entries[3].nMembers == 3)
    PLAYERS[3][2].lfgRoles.dps = true
    local heard, updated
    state.GF.Listen("listings", function() heard = true end)
    state.GF.Listen("listing", function(e) updated = e end)
    local frame = state.Frame("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    frame:onEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    check("a new search is heard and read on the next ask", heard and Listings.searched and Listings.Read() == 50)
    INFOS[1].age = 999
    frame:onEvent("LFG_LIST_SEARCH_RESULT_UPDATED", 1)
    check("an updated listing is read again alone", updated == Listings.entries[1] and Listings.entries[1].age == 999)
    frame:onEvent("LFG_LIST_SEARCH_RESULT_UPDATED", SECRET)
    check("a secret update is ignored", updated == Listings.entries[1])
    INFOS[1].age = 30
    heard = false
    frame:onEvent("LFG_LIST_SEARCH_FAILED")
    check("a failed search is heard and leaves no listings", heard and Listings.state == "failed" and Listings.n == 0)
    calls = state.infoCalls
    check("and nothing is read until the next search", Listings.Read() == 0 and state.infoCalls == calls)
    frame:onEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    check("the next search reads again", Listings.Read() == 50 and Listings.state == "ready")
    state.S.Set("enabled", false)
    check("off: listings forgotten", Listings.n == 0 and Listings.state == "none" and next(state.events) == nil)
end

do
    local state = Fixture()
    local ns = state.ns
    ns.GroupFinderCommand("probe")
    local printed = table.concat(state.printed, "\n")
    check("the probe prints its lines", state.printed[1] == "Group Finder probe:" and #state.printed == 3 + 5)
    for _, line in ipairs(state.printed) do check("the probe prints plain ASCII: " .. line, not line:find("[\128-\255]")) end
    check("it says whether you are listed", printed:find("Listed: yes", 1, true) ~= nil)
    check("it reads the last search", printed:find("Listings from your last search: 50", 1, true) ~= nil)
    check("it shows how an activity maps", printed:find(
        "1. Leader1: activity 1 \"The Deadmines\" map 36 -> Deadmines", 1, true) ~= nil)
    check("probing while off registers nothing", #state.prefixes == 0 and state.frames == 0)
    ns.GroupFinderCommand("ping Bob")
    check("ping needs the module on", state.printed[#state.printed]:find("off") ~= nil and #state.sent == 0)
    state.S.Set("enabled", true)
    ns.GroupFinderCommand("ping die man")
    check("ping refuses yourself", #state.sent == 0)
    ns.GroupFinderCommand("ping Lea Sunfall")
    check("ping whispers a Q to a name with a space", #state.sent == 1 and state.sent[1].target == "Lea Sunfall"
        and state.sent[1].text:find("^1 Q ") ~= nil)
    local nonce = tonumber(state.sent[1].text:match("^1 Q (%d+)"))
    state.now = state.now + 0.08
    state.GF.Comms.OnMessage("1 C " .. nonce .. " 8 24 D - 211 - Deadmines 1 -", "Lea Sunfall")
    check("and prints the answer and the round trip", state.printed[#state.printed]:find(
        "Lea Sunfall answered in 80 ms: Class8 24; roles damage; score 21.1; BiS not shared; Deadmines; kills 1.", 1, true) ~= nil)
    ns.GroupFinderCommand("ping Nobody")
    state.Advance(state.GF.Comms.PING_WAIT)
    check("no answer says the player needs a listing", state.printed[#state.printed]:find("no answer from Nobody", 1, true)
        and state.printed[#state.printed]:find("a listing", 1, true))
    state.locked = true
    ns.GroupFinderCommand("probe")
    check("the probe reads no listings in chat lockdown", state.printed[#state.printed]:find("chat lockdown", 1, true) ~= nil)
    state.locked = false
    ns.GroupFinderCommand("")
    check("anything else prints the usage", state.printed[#state.printed]:find("probe", 1, true) ~= nil)
end

do
    local state = Fixture({ enabled = true })
    local GF = state.GF
    local Card, Listings = GF.Card, GF.Listings
    state.onQuest[168], state.onQuest[2040] = true, true
    local reply
    Measure("your card built and written", 0.1, function() reply = Card.Reply(42, Card.Mine("Deadmines")) end)
    local card = Card.New()
    Measure("a card read", 0.05, function() Card.Decode(reply, card) end)
    Measure("fifty listings read", 0.5, function() Listings.Read(true) end)
end

do
    local state = Fixture({ enabled = true })
    local GF = state.GF
    local Search = GF.Search
    local heard
    GF.Listen("search", function(searchState) heard = searchState end)
    local frame = state.Frame("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    check("nothing is searched until asked", Search.state == "idle" and #state.searches == 0)
    check("a search runs", Search.Run() == true and Search.state == "searching" and heard == "searching")
    local args = state.searches[1]
    check("in the first category with something at your level, with no other filter",
        args[1] == 2 and args[2] == 0 and args[3] == 0 and args[4] == nil and args[5] == false and args[6] == nil)
    check("for the activities that suit your level", table.concat(args[7], ",") == "1,2,3,4,5")
    check("a second search waits for the first", Search.Run() == false and #state.searches == 1)
    frame:onEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    check("its results end it", Search.state == "done" and heard == "done")
    state.Advance(Search.SEARCH_WAIT)
    check("and its wait is forgotten", Search.state == "done")
    Search.Run()
    frame:onEvent("LFG_LIST_SEARCH_FAILED")
    check("a failed search says so", Search.state == "failed" and heard == "failed")
    Search.Run()
    state.Advance(Search.SEARCH_WAIT)
    check("a search with no answer in time has failed", Search.state == "failed")
    state.entry = { activityIDs = { 7 } }
    Search.Run()
    check("your own listing's activity is searched at any level",
        table.concat(state.searches[#state.searches][7], ",") == "1,2,3,4,5,7")
    frame:onEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    check("every dungeon when asked for all", Search.Run(Search.ALL) == true and Search.pick == Search.ALL
        and table.concat(state.searches[#state.searches][7], ",") == "1,2,3,4,5,6,7,8")
    frame:onEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    check("one dungeon when asked for it, without your own listing's", Search.Run(8) == true
        and table.concat(state.searches[#state.searches][7], ",") == "8")
    check("asking while a search runs changes nothing", Search.Run(Search.LEVEL) == false and Search.pick == 8)
    frame:onEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    check("searching again searches the same", Search.Run() == true
        and table.concat(state.searches[#state.searches][7], ",") == "8")
    frame:onEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    local listed = CATEGORY_ACTIVITIES[2]
    CATEGORY_ACTIVITIES[2] = { 8, 3, 1, 5, 2, 7, 4, 6 }
    local list = {}
    check("the dungeons to pick from, lowest level first", Search.Activities(list) == 8
        and table.concat(list, ",") == "1,2,3,4,5,6,7,8")
    CATEGORY_ACTIVITIES[2] = listed
    check("and whether each suits your level", Search.Suits(5) and not Search.Suits(6))
    Search.Run(Search.LEVEL)
    frame:onEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
    state.entry, state.level = nil, 1
    check("nothing at your level: no search", Search.Run() == false and Search.state == "unavailable"
        and heard == "unavailable")
    state.level = 20
    Search.Run(Search.ALL)
    state.S.Set("enabled", false)
    check("off: idle, and a pending wait is forgotten", Search.state == "idle")
    check("and the search is for your level again", Search.pick == Search.LEVEL)
    state.Advance(Search.SEARCH_WAIT)
    check("it stays idle", Search.state == "idle")
    check("off: no search", Search.Run() == false)
end

do
    local state = Fixture({ enabled = true })
    local GF = state.GF
    local Browse, Comms, Listings = GF.Browse, GF.Comms, GF.Listings
    local function Times(name)
        local n = 0
        for _, sent in ipairs(state.sent) do
            if sent.target == name and sent.text:find("^1 Q ") then n = n + 1 end
        end
        return n
    end
    local function Asked(name) return Times(name) > 0 end
    INFOS[3].isDelisted = true
    INFOS[5].leaderName = "Die Man"
    Listings.Read(true)
    Browse.Ask()
    check("listing leaders are asked for their cards, as many as it keeps waiting", #Comms.pings == 20)
    check("for their dungeon", state.sent[1].text:find(" Deadmines$") ~= nil)
    check("not a delisted listing's leader, and not you", not Asked("Leader3") and not Asked("Die Man"))
    local card, waiting = Browse.CardOf("Leader1")
    check("a leader asked is waited on", card == nil and waiting == true)
    local ping = Comms.pings[1]
    Comms.OnMessage("1 C " .. ping.id .. " 1 30 T - 211 - Deadmines - -", "Leader1")
    card, waiting = Browse.CardOf("Leader1")
    check("then has their card", card ~= nil and card.score == 211 and waiting == false)
    Browse.Ask()
    check("the spot freed asks the next leader", select(2, Browse.CardOf("Leader23")) == true and #Comms.pings == 20)
    check("and nobody is asked twice while waited on", Times("Leader2") == 1)
    state.Advance(Comms.PING_WAIT)
    card, waiting = Browse.CardOf("Leader2")
    check("a leader with no answer has no card and is not waited on", card == nil and waiting == false)
    Browse.Ask()
    check("the rest are asked as room frees", select(2, Browse.CardOf("Leader25")) == true and Times("Leader2") == 1
        and #Comms.pings == 20)
    state.Advance(Browse.ASK_AGAIN + 1)
    Browse.Ask()
    check("a leader with no answer is asked again after a while", select(2, Browse.CardOf("Leader2")) == true)
    INFOS[3].isDelisted = false
    INFOS[5].leaderName = "Leader5"
    state.S.Set("enabled", false)
    check("off: nobody is waited on", select(2, Browse.CardOf("Leader2")) == false)
end

do
    local state = Fixture({ enabled = true })
    local GF = state.GF
    local Browse, Card, Comms, Listings = GF.Browse, GF.Card, GF.Comms, GF.Listings
    local n = Listings.Read(true)
    Browse.Ask()
    local function Answer(name, score, note)
        for _, ping in ipairs(Comms.pings) do
            if ping.name == name then
                local card = Card.Mine("Deadmines")
                card.score = score
                local group = note and { min = 0, tanks = 0, healers = 1, damage = 0, note = note } or nil
                Comms.OnMessage(Card.Reply(ping.id, card, group), name)
                return
            end
        end
    end
    Answer("Leader4", 150)
    Answer("Leader9", 263, "Quests welcome")
    local function Shown(needle)
        local list = {}
        for i = 1, n do
            if Browse.Matches(Listings.entries[i], needle) then list[#list + 1] = Listings.entries[i].leader end
        end
        return list
    end
    check("an empty filter shows every listing", #Shown("") == n)
    check("the filter finds a leader", table.concat(Shown("leader12"), ",") == "Leader12")
    check("a dungeon, by its name or short name", #Shown("deadmines") == 10 and #Shown("dm") == 10)
    check("and a leader's note", table.concat(Shown("quests"), ",") == "Leader9")
    check("nothing that matches shows nothing", #Shown("onyxia") == 0)
    local order = {}
    for i = 1, 10 do order[i] = Listings.entries[i] end
    local function Leaders()
        local names = {}
        for i = 1, 4 do names[i] = order[i].leader end
        return table.concat(names, ",")
    end
    Browse.Sort(order, "newest")
    check("newest first, your own listing before them all", Leaders() == "Leader7,Leader1,Leader2,Leader3")
    Browse.Sort(order, "score")
    check("best leader's score first, the rest newest first", Leaders() == "Leader7,Leader9,Leader4,Leader1")
    Browse.Sort(order, "level")
    check("lowest dungeon first, newest first within it", Leaders() == "Leader7,Leader1,Leader6,Leader2")
    Browse.Sort(order, "unknown")
    check("an unknown sort is newest first", Leaders() == "Leader7,Leader1,Leader2,Leader3")
end

do
    local state = Fixture({ enabled = true })
    local Card = state.GF.Card
    local mine = Card.Mine("Deadmines")
    local group = { min = 120, tanks = 1, healers = 0, damage = 2, note = "Full clear, quests welcome" }
    local text = Card.Reply(7, mine, group)
    SIZES.listed = #text
    check("a listed leader's answer carries the group after the card", text:find("^1 L 7 1 20 TD fury%-warrior ") ~= nil
        and text:find(" 120 102 Full clear, quests welcome$") ~= nil)
    local back, got = Card.New(), {}
    local kind, id, note = Card.Decode(text, back, got)
    check("and reads back: card, minimum, needs and note", kind == "L" and id == 7 and note == "Full clear, quests welcome"
        and back.score == 189 and got.min == 120 and got.tanks == 1 and got.healers == 0 and got.damage == 2)
    group.min, group.note = 0, ""
    text = Card.Reply(7, mine, group)
    kind, id, note = Card.Decode(text, back, got)
    check("no minimum and no note", id == 7 and text:find(" %- 102$") ~= nil and kind == "L" and note == nil and got.min == 0)
    local big = Card.New()
    big.class, big.level, big.roles, big.spec, big.score = 11, 60, 7, "beast-mastery-hunter", 612
    big.bisHave, big.bisTotal, big.dungeon = 40, 40, "DireMaul"
    big.hasKills, big.nKills, big.hasQuests, big.nHave, big.nNeed = true, 19, true, Card.MAX_QUESTS, Card.MAX_QUESTS
    for i = 1, 19 do big.kills[i] = Card.KILL_CAP end
    for i = 1, Card.MAX_QUESTS do big.have[i], big.need[i] = 98800 + i, 98900 + i end
    group.min, group.note = 300, Card.CleanNote(string.rep("x", 80))
    text = Card.Reply(Card.ID_MAX, big, group)
    check("the biggest listed answer fits, its quests cut first", #text <= Card.MAX_BYTES
        and Card.Decode(text, back, got) == "L" and back.nKills == 19 and got.min == 300)
    local GOOD = "1 L 42 1 20 TD - - - Deadmines - - 120 112"
    check("a well-formed listed answer passes", Card.Decode(GOOD, back, got) == "L")
    for i, bad in ipairs({ "1 L 42 1 20 TD - - - Deadmines - -", GOOD:gsub(" 112$", " 11"), GOOD:gsub(" 112$", " 1a2"),
        GOOD:gsub(" 120 ", " 0 "), GOOD .. " ", GOOD .. " |cffnote" }) do
        check("malformed listed answer " .. i .. " is rejected", Card.Decode(bad, back, got) == nil)
    end
    check("a listed answer needs a group to fill", Card.Decode(GOOD, back, nil) == nil)
end

do
    local state = Fixture({ enabled = true })
    local GF = state.GF
    local Comms, Group = GF.Comms, GF.Group
    local heard = 0
    GF.Listen("group", function() heard = heard + 1 end)
    state.listed, state.listOk = false, true
    check("nothing to list until a dungeon and a style are picked", Group.List() == false and state.created == nil)
    Group.activity, Group.style, Group.min, Group.damage, Group.note = 2, 3, 120, 2, "Quests welcome"
    check("a group is listed with its dungeon and playstyle", Group.List() == true and state.created.activity == 2
        and state.created.style == 3 and heard > 0)
    check("it is ours, and told to Naowh Forever players", Group.Info() == Group and Group.listedAt ~= nil)
    Group.activity = 1
    Group.List()
    check("listed again, it is updated", state.updated.activity == 1 and state.updated.style == 3)
    Comms.OnMessage("1 Q 5 Deadmines", "Browser")
    local answer = state.sent[#state.sent]
    check("a card request is answered with the group", answer.target == "Browser"
        and answer.text:find("^1 L 5 ") ~= nil and answer.text:find(" 120 112 Quests welcome$") ~= nil)

    local nonce = Comms.Ping("Leader", "Deadmines")
    Comms.OnMessage("1 L " .. nonce .. " 1 30 T - 211 - Deadmines - - 80 011 Bring food", "Leader")
    local card = Comms.CardOf("Leader")
    check("a leader's group is kept with their card", card.group and card.group.min == 80 and card.group.tanks == 0
        and card.group.healers == 1 and card.group.damage == 1 and card.group.note == "Bring food")
    nonce = Comms.Ping("Leader", "Deadmines")
    Comms.OnMessage("1 C " .. nonce .. " 1 30 T - 211 - Deadmines - -", "Leader")
    check("and dropped when they answer without one", Comms.CardOf("Leader").group == nil)

    Comms.OnMessage("1 A 31 3 25 D - 201 - Deadmines - - Hi", "Erin")
    local record = Comms.applicants[1]
    Group.Invite(record)
    check("Invite invites the applicant by name", state.invited == "Erin" and record.invited == true)
    Group.Decline(record)
    check("Decline whispers D and takes them off", #Comms.applicants == 0 and state.sent[#state.sent].text == "1 D 31")

    state.inGroup, state.leader = true, false
    check("in a group, only its leader lists", Group.CanEdit() == false and Group.List() == false)
    check("or delists", Group.Delist() == false and state.removed == nil)
    state.leader = true
    check("the leader delists", Group.Delist() == true and state.removed == true)
    state.Frame("LFG_LIST_ACTIVE_ENTRY_UPDATE"):onEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
    check("once delisted it is no longer ours", Group.Info() == nil and Group.listedAt == nil and Group.ours == false)
    state.listed = true
    check("a listing made in the game's own finder is not told about", Group.Info() == nil)
    state.listed = false
    state.inGroup = false

    local sentBefore = #Comms.sent
    local id = GF.Browse.Apply("Leader", "Deadmines")
    check("Apply applies with your saved roles and no note", id and #Comms.sent == sentBefore + 1
        and Comms.SentTo("leader") ~= nil and state.sent[#state.sent].text:find("^1 A " .. id .. " 1 20 TD ") ~= nil)
    state.S.Set("enabled", false)
    check("off: nothing listened to", next(state.events) == nil)
end

do
    local state = Fixture({ enabled = true })
    local GF = state.GF
    local Comms, Group = GF.Comms, GF.Group
    Comms.OnMessage("1 A 41 3 25 D - - - - - -", "Erin")
    Group.Invite(Comms.applicants[1])
    state.invited = nil
    check("an invited applicant cannot be invited twice", Group.Invite(Comms.applicants[1]) == false
        and state.invited == nil)
    Comms.OnMessage("1 A 41 3 25 D - - - - - -", "Erin")
    check("an application reusing an old ID after a reload starts uninvited", not Comms.applicants[1].invited
        and Group.Invite(Comms.applicants[1]) == true and state.invited == "Erin")
    Comms.OnMessage("1 A 44 3 25 D - - - - - -", "Erin")
    check("so does a new application from the same player", not Comms.applicants[1].invited)
    Comms.OnMessage("1 X 41", "Erin")
    check("an old withdrawal cannot remove a newer application", #Comms.applicants == 1)
    local old = Comms.applicants[1]
    Comms.OnMessage("1 X 44", "Erin")
    Comms.OnMessage("1 A 42 3 25 D - - - - - -", "Finn")
    check("the next applicant gets a record of their own", Comms.applicants[1] ~= old
        and not Comms.applicants[1].invited)
    state.invited = nil
    check("a row still showing a withdrawn applicant cannot invite the next one", Group.Invite(old) == false
        and state.invited == nil)
    check("or decline them", Group.Decline(old) == false and #Comms.applicants == 1)
    local visible
    GF.Listen("withdrawn", function() visible = #Comms.applicants end)
    Comms.OnMessage("1 X 42", "Finn")
    check("withdraw listeners see the updated applicant list", visible == 0)
    Comms.OnMessage("1 A 43 3 25 D - - - - - -", "Gail")
    GF.Listen("applicantExpired", function() visible = #Comms.applicants end)
    state.Advance(Comms.APP_TTL)
    check("expiry listeners see the updated applicant list", visible == 0)
end

do
    local state = Fixture({ enabled = true })
    local GF = state.GF
    local Comms, Group = GF.Comms, GF.Group
    state.listed, state.listOk = false, true
    Group.activity, Group.style, Group.min = 2, 3, 120
    Group.List()
    Comms.OnMessage("1 A 51 3 25 D - - - - - -", "Erin")
    local erin = Comms.applicants[1]
    local before = #state.sent
    state.inGroup, state.leader = true, false
    local leaderChanged = state.Frame("PARTY_LEADER_CHANGED")
    check("leader changes are observed", leaderChanged ~= nil)
    leaderChanged:onEvent("PARTY_LEADER_CHANGED")
    check("a former leader cannot invite an applicant", Group.Invite(erin) == false and state.invited == nil)
    check("or decline one", Group.Decline(erin) == false and #Comms.applicants == 1)
    Comms.OnMessage("1 Q 52 -", "Browser")
    Comms.OnMessage("1 A 53 3 25 D - - - - - -", "Finn")
    check("a group member does not answer for the leader", #state.sent == before and #Comms.applicants == 1)
    state.leader = true
    leaderChanged:onEvent("PARTY_LEADER_CHANGED")
    check("leading again, the applicants are still there, as their games still have them",
        Comms.HasApplicant(erin) and #state.sent == before)
    check("and the listing Create made is told again", Group.Info() == Group and Group.listedAt ~= nil)
    state.leader = false
    state.Frame("GROUP_ROSTER_UPDATE"):onEvent("GROUP_ROSTER_UPDATE")
    state.leader = true
    check("a roster update while not the leader for a moment keeps the applicants", Comms.HasApplicant(erin))
    state.listed = false
    state.Frame("LFG_LIST_ACTIVE_ENTRY_UPDATE"):onEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
    check("delisting keeps the applicants and whispers no one", Comms.HasApplicant(erin) and #state.sent == before)
    check("rows cannot invite while delisted", Group.Invite(erin) == false and state.invited == nil)
    check("or decline", Group.Decline(erin) == false and #state.sent == before)
    state.listed = true
    check("listed again, the applicant can be invited", Group.Invite(erin) == true and state.invited == "Erin")
    state.Advance(Comms.APP_TTL)
    check("and applicants still expire", #Comms.applicants == 0)
end

do
    local state = Fixture({ enabled = true })
    local Comms = state.GF.Comms
    state.locked = true
    local id = Comms.Apply("Leader", "Deadmines", 1, "")
    check("the application is held during messaging lockdown", Comms.Queued() == 1)
    check("a queued application can be withdrawn", Comms.Withdraw(id) and Comms.Queued() == 0)
    state.locked = false
    state.Advance(3)
    check("a withdrawn queued application never reaches the leader", #state.sent == 0)
    state.locked = true
    Comms.Apply("Leader", "Deadmines", 1, "")
    state.Advance(Comms.APP_TTL)
    state.locked = false
    state.Advance(3)
    check("an expired queued application never reaches the leader", #state.sent == 0 and Comms.Queued() == 0)
end

do
    local state = Fixture({ enabled = true })
    local Comms, Group = state.GF.Comms, state.GF.Group
    local id = Comms.Apply("Leader", "Deadmines", 1, "")
    Comms.OnMessage("1 A 61 3 25 D - - - - - -", "Erin")
    state.locked = true
    for i = 1, Comms.QUEUE_MAX do Comms.Send("Other", "1 X " .. i) end
    check("a full queue keeps a sent application until withdrawal can be sent",
        not Comms.Withdraw(id) and #Comms.sent == 1)
    local printed = #state.printed
    check("a full queue keeps an applicant until decline can be sent",
        Group.Decline(Comms.applicants[1]) == false and #Comms.applicants == 1)
    check("and says to try Decline again", #state.printed == printed + 1
        and state.printed[#state.printed]:find("Try Decline again", 1, true) ~= nil)
    state.locked = false
    state.Advance(Comms.QUEUE_MAX / Comms.RATE)
    check("once the queue has room, Decline takes them off", Group.Decline(Comms.applicants[1]) == true
        and #Comms.applicants == 0)
    state.Advance(Comms.BURST / Comms.RATE)
    check("and whispers D", state.sent[#state.sent].text == "1 D 61" and state.sent[#state.sent].target == "Erin")
end

print(("Listed answer: %d bytes."):format(SIZES.listed))
print(("Message sizes: Q %d, C %d, A %d (with a note), K %d, the biggest A %d bytes of %d."):format(
    SIZES.ask, SIZES.reply, SIZES.apply, SIZES.K, SIZES.biggest, 255))
print(("test-group-finder: %d checks passed"):format(checks))

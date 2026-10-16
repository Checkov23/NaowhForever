-- Run with Lua 5.1 from the repository root: Group Inspect's Share.lua. Stats summed from gear
-- (the stat keys, ratings as percents, a hunter's ranged power, items not loaded yet, shared
-- stats left alone, the per-link cache bounded); the Naowh Forever exchange between two
-- clients (request, spread answer, the record filled); answers dropped when spoofed, malformed,
-- oversized, non-finite, too frequent or from someone no longer grouped; no answer with Share
-- Your Stats off or outside a group; requests only while the window is open; answers held in
-- combat or while stats are secret; nothing registered while off; and the garbage budgets.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end
local Measure = dofile("Tools/regression/measure.lua")(check)
local NOTHING = function() end

local PEOPLE = {
    Alpha = { guid = "Player-1-0A", class = "HUNTER" },
    Bravo = { guid = "Player-1-0B", class = "WARRIOR" },
    Charlie = { guid = "Player-1-0C", class = "MAGE" },
}
local GEAR_SLOTS = {
    { 1, "Head" }, { 2, "Neck" }, { 3, "Shoulder" }, { 15, "Back" }, { 5, "Chest" }, { 9, "Wrist" },
    { 10, "Hands" }, { 6, "Waist" }, { 7, "Legs" }, { 8, "Feet" },
    { 11, "Ring 1" }, { 12, "Ring 2" }, { 13, "Trinket 1" }, { 14, "Trinket 2" },
    { 16, "Main Hand" }, { 17, "Off Hand" }, { 18, "Ranged" },
}
local ITEM_STATS = {
    ["item:101"] = { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_STAMINA_SHORT = 15, ITEM_MOD_CRIT_RATING_SHORT = 14,
        RESISTANCE0_NAME = 100 },
    ["item:102"] = { ITEM_MOD_AGILITY_SHORT = 5, ITEM_MOD_ATTACK_POWER_SHORT = 20,
        ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 30, ITEM_MOD_HIT_RATING_SHORT = 10, ITEM_MOD_SPELL_POWER_SHORT = 12,
        ITEM_MOD_SPELL_HEALING_DONE_SHORT = 22, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 8 },
    ["item:103"] = { ITEM_MOD_INTELLECT_SHORT = 7, ITEM_MOD_SPIRIT_SHORT = 3, ITEM_MOD_SPELL_CRIT_RATING_SHORT = 14,
        ITEM_MOD_HIT_SPELL_RATING_SHORT = 10, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 40 },
}
local EMPTY_STATS = {}

-------------------------------------------------------------------------------
--  One client: me (a name in PEOPLE), grouped with others, with my own stats and talents
-------------------------------------------------------------------------------
local function Client(me, others, opts)
    opts = opts or {}
    local state = { now = 1000, combat = false, lockdown = false, secret = false, sent = {}, timers = {},
        statsCalls = 0, cachedOff = {}, raid = opts.raid or false,
        values = { enabled = true, groupInspect = true, groupInspectShare = opts.share ~= false } }
    local listeners = {}
    local S = {
        Get = function(key) return state.values[key] end,
        Set = function(key, value)
            state.values[key] = value
            for i = 1, #listeners do listeners[i](key, value) end
        end,
        OnChange = function(fn) listeners[#listeners + 1] = fn end,
    }
    local units = {}
    local function Seat(unit, name) units[unit] = name end
    Seat("player", me)
    for i, name in ipairs(others) do Seat("party" .. i, name) end
    state.units, state.Seat = units, Seat

    local GI = { open = false, changed = 0, records = {}, list = {}, listeners = {} }
    function GI.On() return S.Get("groupInspect") == true end
    function GI.IsOpen() return GI.open end
    function GI.Open() GI.open = true end
    function GI.Close() GI.open = false end
    function GI.Members() return GI.list end
    function GI.Member(guid) return GI.records[guid] end
    function GI.OnChange(fn) GI.listeners[#GI.listeners + 1] = fn end
    function GI.Changed(guid)
        GI.changed = GI.changed + 1
        GI.last = guid
    end
    function GI.Roster()
        for k in pairs(GI.records) do GI.records[k] = nil end
        for i = #GI.list, 1, -1 do GI.list[i] = nil end
        for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
            local name = units[unit]
            if name then
                local record = { guid = PEOPLE[name].guid, unit = unit, name = name, classFile = PEOPLE[name].class }
                GI.records[record.guid] = record
                GI.list[#GI.list + 1] = record
            end
        end
        for i = 1, #GI.listeners do GI.listeners[i](nil) end
    end
    state.GI = GI

    local frame
    local SWS = { Get = function() return nil end, OnChange = NOTHING }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QoLSettings = S, Apply = NOTHING, CODE_BUILD = opts.version or "0.5.25", GroupInspect = GI,
        UI = { ModuleSettings = function() return SWS end }, Shared = { Items = { GEAR_SLOTS = GEAR_SLOTS } },
        AccountSettings = function() return {} end }
    state.ns = ns
    local mine = opts.stats or { 120, 80, 90, 40, 50, 300, 25, 7.25, 3, 1500 }
    local config = { treeIDs = { 77 } }
    local groups = { { groupID = 1 }, { groupID = 2 }, { groupID = 3 } }
    local spent = opts.spent or { 0, 21, 9 }
    local currencies = {
        { traitNodeGroupID = 1, currencyInfos = { { spent = spent[1] } } },
        { traitNodeGroupID = 2, currencyInfos = { { spent = spent[2] } } },
        { traitNodeGroupID = 3, currencyInfos = { { spent = spent[3] } } },
    }
    local function Number(value) if state.secret == "values" then return state.SECRET end return value end
    local env = setmetatable({
        _G = { NaowhForever = ns },
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        issecretvalue = function(value) return value ~= nil and rawequal(value, state.SECRET) end,
        hooksecurefunc = function(t, key, fn)
            local original = t[key]
            t[key] = function(...) original(...); fn(...) end
        end,
        CreateFrame = function()
            frame = { events = {} }
            function frame.RegisterEvent(self, event) self.events[event] = true end
            function frame.UnregisterEvent(self, event) self.events[event] = nil end
            function frame.SetScript(self, _, fn) self.onEvent = fn end
            state.frame = frame
            return frame
        end,
        GetTime = function() return state.now end,
        C_Timer = { After = function(delay, fn) state.timers[#state.timers + 1] = { delay = delay, fn = fn } end },
        C_ChatInfo = {
            RegisterAddonMessagePrefix = function(prefix) state.prefix = prefix end,
            SendAddonMessage = function(prefix, message, channel)
                state.sent[#state.sent + 1] = { prefix = prefix, message = message, channel = channel }
            end,
            InChatMessagingLockdown = function() return state.lockdown end,
        },
        C_Item = {
            GetItemStats = function(link)
                state.statsCalls = state.statsCalls + 1
                return ITEM_STATS[link] or EMPTY_STATS
            end,
            IsItemDataCachedByID = function(id) return not state.cachedOff[id] end,
            GetItemInfoInstant = function(link) return tonumber(link:match("^item:(%d+)")) end,
            GetItemInfo = NOTHING,
        },
        C_Secrets = { ShouldUnitStatsBeSecret = function() return state.secret == true end },
        C_ClassTalents = { GetActiveConfigID = function() return 9 end },
        C_Traits = {
            GetConfigInfo = function() return config end,
            GetGroupDisplayInfoByTreeID = function() return groups end,
            GetGroupCurrencyInfo = function() return currencies end,
        },
        InCombatLockdown = function() return state.combat end,
        LE_PARTY_CATEGORY_INSTANCE = 2,
        IsInGroup = function(category)
            if category ~= nil then return false end
            for i = 1, 4 do if units["party" .. i] then return true end end
            return false
        end,
        IsInRaid = function() return state.raid end,
        GetNumSubgroupMembers = function()
            local n = 0
            for i = 1, 4 do if units["party" .. i] then n = i end end
            return n
        end,
        GetNumGroupMembers = function() return 0 end,
        UnitGUID = function(unit)
            local name = units[unit]
            return name and PEOPLE[name].guid
        end,
        UnitFullName = function(unit) return units[unit] end,
        GetNormalizedRealmName = function() return "Forever" end,
        UnitClass = function() return "Class", PEOPLE[me].class end,
        UnitStat = function(_, i) return mine[i], Number(mine[i]) end,
        UnitAttackPower = function() return Number(mine[6] - 100), 100, 0 end,
        UnitRangedAttackPower = function() return Number(mine[6]), 0, 0 end,
        GetSpellBonusDamage = function(school) return school == 3 and mine[7] or 0 end,
        GetSpellBonusHealing = function() return 10 end,
        GetCritChance = function() return Number(mine[8]) end,
        GetSpellCritChance = function() return 1 end,
        GetCombatRatingBonus = function() return 1 end,
        CR_HIT_MELEE = 6, CR_HIT_SPELL = 8,
        GetHitModifier = function() return mine[9] - 1 end,
        GetSpellHitModifier = function() return 0 end,
        UnitArmor = function() return mine[10], Number(mine[10]) end,
    }, { __index = _G })
    state.SECRET = {}
    Load({ "Core/Senders.lua", "Core/Features.lua",
        "NaowhForever_BiS/StatWeights/Data/Defaults.lua",
        "NaowhForever_BiS/StatWeights/StatWeights.lua", "NaowhForever_BiS/StatWeights/Worth.lua",
        "NaowhForever_Utilities/GroupInspect/Constants.lua", "NaowhForever_Utilities/GroupInspect/Stats.lua",
        "NaowhForever_Utilities/GroupInspect/OwnStats.lua", "NaowhForever_Utilities/GroupInspect/Message.lua",
        "NaowhForever_Utilities/GroupInspect/Share.lua" }, env)
    state.T = GI._ShareTest
    GI.Roster()

    function state.Fire(event, ...) if frame.events[event] then frame.onEvent(frame, event, ...) end end
    function state.Hear(message, sender, channel)
        state.Fire("CHAT_MSG_ADDON", state.T.PREFIX, message, channel or "PARTY", sender)
    end
    function state.RunTimers()
        local timers = state.timers
        state.timers = {}
        for _, timer in ipairs(timers) do timer.fn() end
        return #timers
    end
    function state.Last() return state.sent[#state.sent] end
    state.Fire("PLAYER_ENTERING_WORLD")
    return state
end

-------------------------------------------------------------------------------
--  Stats summed from gear
-------------------------------------------------------------------------------
do
    local c = Client("Alpha", { "Bravo" })
    local GI = c.GI
    local record = { guid = "Player-1-0B", classFile = "WARRIOR", gear = {
        [1] = { id = 101, link = "item:101" }, [2] = { id = 102, link = "item:102" }, [3] = { id = 103, link = "item:103" },
        [4] = { id = 101, link = "item:101" } } }
    check("gear stats complete once every item has loaded", GI.StatsFromGear(record) == true)
    local s = record.stats
    check("primary stats summed, the shirt slot ignored", s.STR == 10 and s.AGI == 5 and s.STA == 15 and s.INT == 7
        and s.SPI == 3)
    check("armor from the items", s.ARMOR == 100)
    check("attack power without ranged power off a hunter", s.AP == 20)
    check("spell power is power plus the better of damage and healing", s.SP == 12 + 22)
    check("crit rating as a percent, spell crit with it", s.CRIT == 2)
    check("hit rating as a percent, spell hit with it", s.HIT == 2)
    check("summed from gear is not shared", record.statsShared == false)
    local same = record.stats
    record.classFile = "HUNTER"
    GI.StatsFromGear(record)
    check("a hunter's ranged attack power counts", record.stats.AP == 50)
    check("the record's stats table is reused", record.stats == same)

    c.cachedOff[103] = true
    check("an item not loaded yet leaves the sum incomplete", GI.StatsFromGear(record) == false)
    check("the loaded items still count", record.stats.STR == 10 and record.stats.INT == 0)
    c.cachedOff[103] = nil

    local shared = { classFile = "MAGE", statsShared = true, stats = { STR = 1 }, gear = record.gear }
    check("shared stats are not overwritten by gear", GI.StatsFromGear(shared) == false and shared.stats.STR == 1)
    check("nothing to sum without gear", GI.StatsFromGear({ classFile = "MAGE" }) == false)
    check("a non-table record is refused", GI.StatsFromGear(nil) == false)

    local calls = c.statsCalls
    GI.StatsFromGear(record)
    check("each link's stats read once, then cached", c.statsCalls == calls)
    for i = 1, 700 do c.ns.StatWeights.Stats("item:9" .. i) end
    calls = c.statsCalls
    GI.StatsFromGear(record)
    check("the per-link cache is bounded: old links are read again after it fills", c.statsCalls > calls)
    -- Warm the VM string table with distinct IDs before measuring retained cache growth.
    for i = 1, 20000 do c.ns.StatWeights.Stats("item:7" .. i) end
    collectgarbage("collect")
    local before = collectgarbage("count")
    for i = 1, 5000 do c.ns.StatWeights.Stats("item:8" .. i) end
    collectgarbage("collect")
    check("the per-link cache stays small however many links pass", collectgarbage("count") - before < 120)

    GI.StatsFromGear(record)
    Measure("stats summed from 4 items", 0.2, function() GI.StatsFromGear(record) end)
end

-------------------------------------------------------------------------------
--  The exchange: a request, a spread answer, the record filled on the other side
-------------------------------------------------------------------------------
do
    local a = Client("Alpha", { "Bravo", "Charlie" })
    local b = Client("Bravo", { "Alpha", "Charlie" })
    check("the prefix is registered once grouped", a.prefix == "NaowhGroup")
    check("listening while grouped with sharing on", a.frame.events.CHAT_MSG_ADDON == true)
    check("no change events before anyone asks", not a.frame.events.PLAYER_EQUIPMENT_CHANGED)

    b.GI.Open()
    check("opening the window sends a request to the group", #b.sent == 1 and b.Last().message == "1 R"
        and b.Last().channel == "PARTY" and b.Last().prefix == "NaowhGroup")
    check("opening fills your own record with your exact stats", b.GI.Member("Player-1-0B").statsShared == true
        and b.GI.Member("Player-1-0B").hasNF == true and b.GI.Member("Player-1-0B").nfVersion == "0.5.25")

    a.Hear("1 R", "Bravo")
    check("a request is answered after a wait, not at once", #a.sent == 0 and #a.timers == 1)
    check("a party's answer waits at most 1.5 seconds", a.timers[1].delay > 0 and a.timers[1].delay <= 1.5)
    check("being asked turns on the change events", a.frame.events.PLAYER_EQUIPMENT_CHANGED == true)
    a.RunTimers()
    local answer = a.Last().message
    check("one answer on the group channel", #a.sent == 1 and a.Last().channel == "PARTY")
    check("the answer's exact format", answer == "1 S Player-1-0A 0.5.25 0/21/9 120 80 90 40 50 300 25 73 30 1500")
    check("the answer fits one message", #answer < 255)

    local changed = b.GI.changed
    b.Hear(answer, "Alpha")
    local rec = b.GI.Member("Player-1-0A")
    check("the record says they run Naowh Forever", rec.hasNF == true and rec.nfVersion == "0.5.25")
    check("their exact stats, shared", rec.statsShared == true and rec.stats.STR == 120 and rec.stats.AP == 300
        and rec.stats.SP == 25 and rec.stats.ARMOR == 1500)
    check("crit and hit back to percents", rec.stats.CRIT == 7.3 and rec.stats.HIT == 3)
    check("their talents per tree, the tree and its role", rec.talents.spent[1] == 0 and rec.talents.spent[2] == 21
        and rec.talents.spent[3] == 9 and rec.talents.tree == "Marksmanship" and rec.talents.role == "Damage")
    check("the change is fired for their GUID", b.GI.changed == changed + 1 and b.GI.last == "Player-1-0A")
    check("an answer gets nothing sent back", #b.sent == 1 and #b.timers == 0)

    a.Hear("1 R", "Alpha")
    check("your own request is not answered", #a.timers == 0)

    a.now = a.now + 3
    a.Hear("1 R", "Charlie")
    check("a second request inside the gap waits out the gap", #a.timers == 1 and a.timers[1].delay >= 7
        and a.timers[1].delay <= 7 + 1.5)
    a.Hear("1 R", "Charlie")
    check("requests while an answer waits add nothing", #a.timers == 1)
    a.RunTimers()

    a.now = a.now + 20
    a.Fire("PLAYER_EQUIPMENT_CHANGED")
    check("a gear change sends once, after a short delay", #a.timers == 1 and a.timers[1].delay == 2)
    a.Fire("PLAYER_EQUIPMENT_CHANGED")
    check("a gear swap's burst is one change", #a.timers == 1)
    local sentBefore = #a.sent
    a.RunTimers()
    a.RunTimers()
    check("the change is sent while someone asked recently", #a.sent == sentBefore + 1)
    a.now = a.now + 400
    a.Fire("PLAYER_EQUIPMENT_CHANGED")
    a.RunTimers()
    check("after the asked window, a change sends nothing", #a.sent == sentBefore + 1 and #a.timers == 0)
    check("and the change events are dropped", not a.frame.events.PLAYER_EQUIPMENT_CHANGED)

    local raid = Client("Alpha", { "Bravo" }, { raid = true })
    raid.Fire("GROUP_ROSTER_UPDATE")
    local most = 0
    for _ = 1, 200 do
        raid.Hear("1 R", "Bravo", "RAID")
        local delay = raid.timers[1].delay
        if delay > most then most = delay end
        raid.RunTimers()
        raid.now = raid.now + 11
    end
    check("a raid's answers spread over at most 5 seconds", most > 1.5 and most <= 5)
    check("every raid answer went out on the raid channel", raid.Last().channel == "RAID")
end

-------------------------------------------------------------------------------
--  What is dropped
-------------------------------------------------------------------------------
do
    local b = Client("Bravo", { "Alpha", "Charlie" })
    local good = "1 S Player-1-0A 0.5.25 0/21/9 120 80 90 40 50 300 25 73 30 1500"
    local function Kept(message, sender, channel)
        local before = b.GI.changed
        b.Hear(message, sender or "Alpha", channel)
        return b.GI.changed > before
    end
    check("an answer from someone else claiming Alpha's GUID is dropped", not Kept(good, "Charlie"))
    check("an answer from a stranger is dropped", not Kept(good, "Zed"))
    check("an answer on another channel is dropped", not Kept(good, "Alpha", "GUILD"))
    check("an answer on the raid channel while in a party is dropped", not Kept(good, "Alpha", "RAID"))
    check("an answer claiming your own GUID is dropped",
        not Kept("1 S Player-1-0B 0.5.25 0/21/9 1 1 1 1 1 1 1 1 1 1", "Bravo"))
    check("another protocol version is dropped", not Kept((good:gsub("^1", "2"))))
    check("a missing field is dropped", not Kept("1 S Player-1-0A 0.5.25 0/21/9 120 80 90 40 50 300 25 73 30"))
    check("an extra field is dropped", not Kept(good .. " 5"))
    check("a negative number is dropped", not Kept("1 S Player-1-0A 0.5.25 0/21/9 -120 80 90 40 50 300 25 73 30 1500"))
    check("a decimal is dropped", not Kept("1 S Player-1-0A 0.5.25 0/21/9 120.5 80 90 40 50 300 25 73 30 1500"))
    check("a letter in a number is dropped", not Kept("1 S Player-1-0A 0.5.25 0/21/9 1e9 80 90 40 50 300 25 73 30 1500"))
    check("a number too big to be finite is dropped",
        not Kept("1 S Player-1-0A 0.5.25 0/21/9 " .. ("9"):rep(200) .. " 80 90 40 50 300 25 73 30 1500"))
    check("a stat over its range is dropped", not Kept("1 S Player-1-0A 0.5.25 0/21/9 120 80 90 40 50 300 25 1001 30 1500"))
    check("more talent points than there are is dropped", not Kept("1 S Player-1-0A 0.5.25 51/40/20 1 1 1 1 1 1 1 1 1 1"))
    check("a version with odd characters is dropped", not Kept("1 S Player-1-0A 0.5|r 0/21/9 1 1 1 1 1 1 1 1 1 1"))
    check("an overlong version is dropped", not Kept("1 S Player-1-0A " .. ("1"):rep(21) .. " 0/21/9 1 1 1 1 1 1 1 1 1 1"))
    check("a message over 255 bytes is dropped",
        not Kept("1 S Player-1-0A 0.5.25 0/21/9 " .. ("0"):rep(250) .. "120 80 90 40 50 300 25 73 30 1500"))
    check("a format string in the version goes nowhere", not Kept("1 S Player-1-0A 1%s%d 0/21/9 1 1 1 1 1 1 1 1 1 1"))
    check("an empty message is dropped", not Kept(""))
    local secretMessage = b.SECRET
    b.Fire("CHAT_MSG_ADDON", "NaowhGroup", secretMessage, "PARTY", "Alpha")
    check("a secret message is dropped", b.GI.changed == 0)

    check("the real answer is kept", Kept(good))
    b.now = b.now + 1
    check("a second answer from the same member a second later is dropped", not Kept(good))
    b.now = b.now + 8
    check("their next answer after the gap is kept", Kept(good))
    check("a different member is not held by the first's gap", Kept((good:gsub("0A", "0C")), "Charlie"))

    b.Seat("party1", nil)
    b.GI.Roster()
    b.now = b.now + 20
    check("an answer from someone who left the group is dropped", not Kept(good))

    local c = Client("Bravo", { "Alpha" })
    local message = good
    c.Hear(message, "Alpha")
    Measure("an answer parsed and kept", 0.2, function()
        c.now = c.now + 10
        c.Hear(message, "Alpha")
    end)
    Measure("a spoofed answer parsed and dropped", 0.2, function() c.Hear(message, "Charlie") end)
end

-------------------------------------------------------------------------------
--  When nothing is answered, requested or registered
-------------------------------------------------------------------------------
do
    local off = Client("Alpha", { "Bravo" }, { share = false })
    off.Hear("1 R", "Bravo")
    check("no listening with Share Your Stats off and the window closed", next(off.frame.events) == nil)
    off.T.OnEvent(nil, "CHAT_MSG_ADDON", "NaowhGroup", "1 R", "PARTY", "Bravo")
    check("no answer with Share Your Stats off", #off.timers == 0 and #off.sent == 0)
    off.GI.Open()
    check("the open window listens even with sharing off", off.frame.events.CHAT_MSG_ADDON == true)
    check("the open window still asks", #off.sent == 1 and off.Last().message == "1 R")
    off.Hear("1 R", "Bravo")
    check("and still does not answer", #off.timers == 0)
    off.ns.QoLSettings.Set("groupInspectShare", true)
    off.Hear("1 R", "Bravo")
    check("turning sharing on answers the next request", #off.timers == 1)

    local solo = Client("Alpha", {})
    check("solo: the prefix is never registered", solo.prefix == nil)
    check("solo: no addon messages listened to", not solo.frame.events.CHAT_MSG_ADDON)
    solo.T.OnEvent(nil, "CHAT_MSG_ADDON", "NaowhGroup", "1 R", "PARTY", "Bravo")
    check("solo: no answer", #solo.timers == 0 and #solo.sent == 0)
    solo.GI.Open()
    check("solo: opening the window asks nobody", #solo.sent == 0 and #solo.timers == 0)

    local r = Client("Alpha", { "Bravo" })
    r.Fire("GROUP_ROSTER_UPDATE")
    r.GI.Roster()
    check("a roster change with the window closed asks nothing", #r.sent == 0)
    r.GI.Open()
    check("opening asks", #r.sent == 1)
    r.GI.Roster()
    check("a roster change with nobody new asks nothing", #r.sent == 1 and #r.timers == 0)
    r.Seat("party2", "Charlie")
    r.Fire("GROUP_ROSTER_UPDATE")
    r.GI.Roster()
    check("someone joining asks again once the gap is out", #r.sent == 1 and #r.timers == 1
        and r.timers[1].delay <= 10)
    r.GI.Close()
    r.now = r.now + 10
    r.RunTimers()
    check("a request waiting when the window closes is not sent", #r.sent == 1)
    r.GI.Open()
    check("reopening after the gap asks at once", #r.sent == 2)

    local fight = Client("Alpha", { "Bravo" })
    fight.combat = true
    fight.Hear("1 R", "Bravo")
    fight.RunTimers()
    check("no answer in combat", #fight.sent == 0)
    check("waiting for combat's end", fight.frame.events.PLAYER_REGEN_ENABLED == true)
    fight.combat = false
    fight.Fire("PLAYER_REGEN_ENABLED")
    fight.RunTimers()
    check("answered once combat ends", #fight.sent == 1 and fight.Last().message:find("^1 S ") ~= nil)
    check("no longer waiting for combat's end", not fight.frame.events.PLAYER_REGEN_ENABLED)

    local hush = Client("Alpha", { "Bravo" })
    hush.lockdown = true
    hush.Hear("1 R", "Bravo")
    hush.RunTimers()
    check("no answer during chat messaging lockdown", #hush.sent == 0)

    local secret = Client("Alpha", { "Bravo" })
    secret.secret = true
    secret.Hear("1 R", "Bravo")
    secret.RunTimers()
    check("no answer while your stats are secret and none were read", #secret.sent == 0)
    secret.secret = "values"
    secret.Fire("ADDON_RESTRICTION_STATE_CHANGED")
    secret.RunTimers()
    check("secret values are never sent", #secret.sent == 0)
    secret.secret = false
    secret.Fire("ADDON_RESTRICTION_STATE_CHANGED")
    secret.RunTimers()
    check("answered once your stats can be read", #secret.sent == 1)
    secret.secret = true
    secret.now = secret.now + 20
    secret.Hear("1 R", "Bravo")
    secret.RunTimers()
    check("while secret again, the last stats read are sent", #secret.sent == 2
        and secret.sent[2].message == secret.sent[1].message)

    local quit = Client("Alpha", { "Bravo" })
    quit.Hear("1 R", "Bravo")
    quit.Seat("party1", nil)
    quit.Fire("GROUP_ROSTER_UPDATE")
    quit.RunTimers()
    check("an answer waiting when you leave the group is not sent", #quit.sent == 0)
    check("outside a group nothing but the roster is listened to", not quit.frame.events.CHAT_MSG_ADDON
        and not quit.frame.events.PLAYER_EQUIPMENT_CHANGED)

    local noQol = Client("Alpha", { "Bravo" })
    noQol.ns.QoLSettings.Set("enabled", false)
    check("the QoL module off: still shared", noQol.frame.events.CHAT_MSG_ADDON == true)

    local disabled = Client("Alpha", { "Bravo" })
    disabled.ns.QoLSettings.Set("groupInspectShare", false)
    check("Share Your Stats off: nothing registered", next(disabled.frame.events) == nil)

    local inspectOff = Client("Alpha", { "Bravo" })
    check("Group Inspect on, sharing on: listening", inspectOff.frame.events.CHAT_MSG_ADDON == true)
    inspectOff.ns.QoLSettings.Set("groupInspect", false)
    check("Group Inspect switched off, its addon still loaded: nothing registered", next(inspectOff.frame.events) == nil)
    inspectOff.T.OnEvent(nil, "CHAT_MSG_ADDON", "NaowhGroup", "1 R", "PARTY", "Bravo")
    check("and no answer", #inspectOff.timers == 0 and #inspectOff.sent == 0)
    inspectOff.ns.QoLSettings.Set("groupInspect", true)
    check("switched back on: sharing again", inspectOff.frame.events.CHAT_MSG_ADDON == true)
end

print(("test-group-inspect-share: %d checks passed"):format(checks))

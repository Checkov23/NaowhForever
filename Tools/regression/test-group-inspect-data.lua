-- Run with Lua 5.1 from the repository root: Group Inspect's data (Records, Inspect, PreviewGroup) on the
-- real Naowh Score files and the Inspect Panel's talent reading, against stubs. Off or closed it
-- does nothing; open, the roster (party, raid of 40, a recycled unit token), the walk's pacing
-- through the shared inspect queue (one at a time, 2 s apart, never in combat, after your own
-- inspect, out of range retried, Naowh Forever users last, stopped once known), a stale
-- INSPECT_READY ignored, records filled from the inspect, Share's fields kept, the preview, and
-- no garbage per roster update or per inspect read. Everyone wears one set (item 100 + slot,
-- level 30 blues, the chest enchanted, the feet enchantable and bare), its links made once; the
-- clock moves on with Advance, which runs each timer due by then in order, as the game would.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end
local Measure = dofile("Tools/regression/measure.lua")(check)
local NOTHING = function() end

local GEAR_SLOTS = {
    { 1, "Head" }, { 2, "Neck" }, { 3, "Shoulder" }, { 15, "Back" }, { 5, "Chest" }, { 9, "Wrist" },
    { 10, "Hands" }, { 6, "Waist" }, { 7, "Legs" }, { 8, "Feet" },
    { 11, "Ring 1" }, { 12, "Ring 2" }, { 13, "Trinket 1" }, { 14, "Trinket 2" },
    { 16, "Main Hand" }, { 17, "Off Hand" }, { 18, "Ranged" },
}

local LINK, LEVEL, QUALITY, EQUIP, CAN, CURRENT = {}, {}, {}, {}, {}, {}
local SET = {}
for _, entry in ipairs(GEAR_SLOTS) do
    local slot = entry[1]
    local id = 100 + slot
    SET[slot] = id
    local link = ("item:%d:%d"):format(id, slot == 5 and 7 or 0)
    LINK[id], LEVEL[link], QUALITY[id], QUALITY[link] = link, 30, 3, 3
    EQUIP[link], EQUIP[id] = "INVTYPE_HEAD", "INVTYPE_HEAD"
    CAN[link], CURRENT[link] = slot == 5 or slot == 8, slot == 5 and 7 or 0
end

local GROUPS = { { groupID = 11, displayName = "Arms" }, { groupID = 12, displayName = "Fury" },
    { groupID = 13, displayName = "Protection" } }
local CURRENCY = { { traitNodeGroupID = 11, currencyInfos = { { spent = 5 } } },
    { traitNodeGroupID = 12, currencyInfos = { { spent = 20 } } },
    { traitNodeGroupID = 13, currencyInfos = { { spent = 0 } } } }
local CONFIG = { treeIDs = { 77 } }
local WARRIOR_TREES = { "arms-warrior", "fury-warrior", "protection-warrior" }

local function Fixture()
    local state = { now = 100, combat = false, raid = false, members = 0, asked = 0, cleared = 0,
        timerAt = {}, timerFn = {}, timers = 0, frames = {}, listeners = {},
        values = { enabled = true, groupInspect = false, naowhScore = false } }
    local units = {}
    state.units = units
    local function Person(unit, guid, first, second)
        units[unit] = { guid = guid, first = first, second = second, level = 40, online = true,
            role = "NONE", gear = SET }
        return units[unit]
    end
    state.Person = Person
    Person("player", "Player-1-0001", "Me", "Myself")
    local S = {
        Get = function(key) return state.values[key] end,
        Set = function(key, value)
            state.values[key] = value
            for _, fn in ipairs(state.listeners) do fn(key, value) end
        end,
        OnChange = function(fn) state.listeners[#state.listeners + 1] = fn end,
    }
    local IP = {
        OnApply = NOTHING, OnRefresh = NOTHING,
        FullName = function(unit)
            local u = units[unit]
            return u and u.first .. " " .. u.second
        end,
        TheirRank = function(guid, slot) if guid == state.bisGUID and slot == 1 then return 1 end end,
        RunsNaowh = function(guid) return guid == state.nfGUID end,
    }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        QoLSettings = S, Apply = NOTHING, InspectPanel = IP,
        THEME = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end }),
        StatWeights = { TreeSpec = function(_, i) return WARRIOR_TREES[i] end },
        Shared = { Style = {}, Parts = {}, Roster = { AddTooltip = NOTHING },
            Items = { GEAR_SLOTS = GEAR_SLOTS, IsTwoHand = function() return false end } },
        BiS = { Enchants = { SLOTS = { [2] = true, [5] = true, [8] = true, [9] = true, [10] = true,
            [15] = true, [16] = true, [17] = true },
            Enchantable = function(link) return CAN[link], CURRENT[link] end } },
    }
    local function Frame()
        local frame = { events = {} }
        function frame.RegisterEvent(self, event) self.events[event] = true end
        function frame.UnregisterEvent(self, event) self.events[event] = nil end
        function frame.SetScript(self, _, fn) self.onEvent = fn end
        state.frames[#state.frames + 1] = frame
        return frame
    end
    local function U(unit) return units[unit] end
    local env = setmetatable({
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        issecretvalue = function(value) return value ~= nil and rawequal(value, state.SECRET) end,
        GetTime = function() return state.now end,
        CreateFrame = Frame,
        hooksecurefunc = function(t, key, fn)
            if type(t) == "string" then
                local original = state.env[t]
                state.env[t] = function(...) original(...); key(...) end
                return
            end
            local original = t[key]
            t[key] = function(...) original(...); fn(...) end
        end,
        C_Timer = { After = function(delay, fn)
            local n = state.timers + 1
            state.timers = n
            state.timerAt[n], state.timerFn[n] = state.now + delay, fn
        end },
        C_Item = {
            GetDetailedItemLevelInfo = function(link) return LEVEL[link] end,
            GetItemInfo = function(link) if LEVEL[link] then return "x", link, QUALITY[link], LEVEL[link] end end,
            GetItemInfoInstant = function(link) return 1, "", "", EQUIP[link] end,
            GetItemQualityByID = function(id) return QUALITY[id] end,
        },
        C_PaperDollInfo = { GetInspectItemLevel = function() return state.inspectLevel or 0 end },
        C_Traits = {
            HasValidInspectData = function() return true end,
            GetConfigInfo = function(id) return id == -1 and CONFIG or nil end,
            GetGroupDisplayInfoByTreeID = function() return GROUPS end,
            GetGroupCurrencyInfo = function() return CURRENCY end,
        },
        C_ClassTalents = { GetActiveConfigID = function() return -1 end },
        Constants = { TraitConsts = { INSPECT_TRAIT_CONFIG_ID = -1 } },
        GetInventoryItemID = function(unit, slot) local u = U(unit) return u and u.gear and u.gear[slot] end,
        GetInventoryItemLink = function(unit, slot)
            local u = U(unit)
            local id = u and u.gear and u.gear[slot]
            return id and LINK[id]
        end,
        GetAverageItemLevel = function() return 31, 30.5 end,
        UnitGUID = function(unit) local u = U(unit) return u and u.guid end,
        UnitExists = function(unit) return U(unit) ~= nil end,
        UnitIsPlayer = function(unit) return U(unit) ~= nil end,
        UnitIsUnit = function(a, b) return U(a) ~= nil and U(a) == U(b) end,
        UnitIsConnected = function(unit) local u = U(unit) return u ~= nil and u.online end,
        UnitClass = function() return "Warrior", "WARRIOR", 1 end,
        UnitLevel = function(unit) local u = U(unit) return u and u.level or 0 end,
        UnitFullName = function(unit) local u = U(unit) if u then return u.first, u.second end end,
        UnitGroupRolesAssigned = function(unit) local u = U(unit) return u and u.role or "NONE" end,
        InCombatLockdown = function() return state.combat end,
        CanInspect = function() return true end,
        CheckInteractDistance = function(unit) return not (state.far and state.far[unit]) end,
        NotifyInspect = function(unit) state.asked, state.lastAsked = state.asked + 1, unit end,
        ClearInspectPlayer = function() state.cleared = state.cleared + 1 end,
        InspectUnit = function(unit) if state.env.InspectFrame then state.env.InspectFrame.unit = unit end end,
        IsInRaid = function() return state.raid end,
        IsInGroup = function() return state.members > 0 end,
        GetNumSubgroupMembers = function() return state.members end,
        GetNumGroupMembers = function() return state.members + 1 end,
        TooltipDataProcessor = { AddTooltipPostCall = NOTHING },
        Enum = { TooltipDataType = { Unit = 2 } },
    }, { __index = _G })
    env._G = setmetatable({ NaowhForever = ns }, { __index = env })
    state.env, state.SECRET = env, {}
    Load({ "NaowhForever_BiS/NaowhScore/Data/Formula.lua", "NaowhForever_BiS/NaowhScore/NaowhScore.lua",
        "NaowhForever_BiS/NaowhScore/Inspect.lua", "NaowhForever_BiS/InspectPanel/Details.lua",
        "NaowhForever_GroupInspect/GroupInspect.lua", "NaowhForever_GroupInspect/Constants.lua",
        "NaowhForever_GroupInspect/Data/Preview.lua", "NaowhForever_GroupInspect/Records.lua",
        "NaowhForever_GroupInspect/Inspect.lua", "NaowhForever_GroupInspect/PreviewGroup.lua" }, env)
    function state.Fire(event, ...)
        for _, frame in ipairs(state.frames) do
            if frame.events[event] then frame.onEvent(frame, event, ...) end
        end
    end
    function state.Advance(seconds)
        state.now = state.now + (seconds or 0)
        local ran = true
        while ran do
            ran = false
            for i = 1, state.timers do
                if state.timerAt[i] <= state.now + 1e-9 then
                    local fn = state.timerFn[i]
                    for j = i, state.timers - 1 do
                        state.timerAt[j], state.timerFn[j] = state.timerAt[j + 1], state.timerFn[j + 1]
                    end
                    state.timerAt[state.timers], state.timerFn[state.timers] = nil, nil
                    state.timers = state.timers - 1
                    fn()
                    ran = true
                    break
                end
            end
        end
    end
    function state.Party(n)
        state.members = n
        for i = 1, n do
            Person("party" .. i, ("Player-1-%04d"):format(10 + i), "Member" .. i, "Surname" .. i)
        end
    end
    return ns, state, env
end

do
    local ns, state = Fixture()
    local GI = ns.GroupInspect
    state.Party(4)
    check("loaded: the namespace and its API", GI and GI.Open and GI.Close and GI.Members and GI.Changed
        and GI.StatsFromGear and ns.NaowhScore.InspectQueue)
    check("loaded: no frame of its own, no timer", #state.frames == 1 and state.timers == 0)
    GI.Open()
    check("off: opening does nothing", not GI.IsOpen() and #state.frames == 1 and state.timers == 0)
    state.Fire("GROUP_ROSTER_UPDATE")
    state.Advance(10)
    check("off: no inspect", state.asked == 0)
    state.values.groupInspect = true
    GI.Changed("Player-1-0011")
    GI.Refresh("Player-1-0011")
    GI.RefreshAll()
    check("on but closed: still nothing", #state.frames == 1 and state.timers == 0 and GI.Count() == 0)
    state.values.enabled = false
    check("on with the QoL module off: still on", GI.On())
end

do
    local ns, state, env = Fixture()
    local GI = ns.GroupInspect
    local Score = ns.NaowhScore
    state.values.groupInspect = true
    state.Party(4)
    state.units.party2.role = "HEALER"
    local seen, rosterCalls = {}, 0
    GI.OnChange(function(guid)
        if guid == nil then rosterCalls = rosterCalls + 1 else seen[guid] = (seen[guid] or 0) + 1 end
    end)
    GI.Open()
    local scoreFrame, frame = state.frames[1], state.frames[2]
    check("open: its events listened to, and the inspect it shares", GI.IsOpen() and frame.events.GROUP_ROSTER_UPDATE
        and frame.events.UNIT_INVENTORY_CHANGED and scoreFrame.events.INSPECT_READY)
    local list = GI.Members()
    check("you first, then party1..4", GI.Mode() == "party" and GI.Count() == 5 and list[1].unit == "player"
        and list[2].unit == "party1" and list[5].unit == "party4")
    local me = list[1]
    check("you: from your own gear, \"First Surname\"", me.state == "self" and me.name == "Me Myself"
        and me.ilvl == 30.5 and me.score > 0 and me.gear[5].id == 105 and me.gear[5].enchanted == true
        and me.gear[8].enchanted == false and me.gear[2].enchanted == nil and me.hasNF == true)
    check("your talents: points per tree, lead tree, role", me.talents and me.talents.spent[2] == 20
        and me.talents.tree == "Fury" and me.talents.role == "Damage" and me.role == "DAMAGER")
    check("an assigned role wins", list[3].role == "HEALER")
    check("everyone else queued, nothing known yet", list[2].state == "queued" and list[2].gear[1] == nil)
    state.Advance(0)
    check("one roster callback for the burst", rosterCalls == 1)
    check("the first member asked at once", state.asked == 1 and state.lastAsked == "party1"
        and list[2].state == "inspecting")
    state.Advance(1.5)
    check("one at a time: none while that request is out", state.asked == 1)
    local guid1 = list[2].guid
    state.Fire("INSPECT_READY", "Player-1-9999")
    check("an INSPECT_READY for another GUID: ignored", list[2].state == "inspecting" and list[2].gear[1] == nil
        and state.cleared == 0)
    state.inspectLevel = 29.4
    state.Fire("INSPECT_READY", guid1)
    local rec = GI.Member(guid1)
    check("their record filled from the inspect", rec.state == "ready" and rec.ilvl == 29.4 and rec.gear[1].id == 101
        and rec.gear[1].link == LINK[101] and rec.gear[1].quality == 3 and rec.gear[1].ilvl == 30
        and rec.gear[5].enchanted == true and rec.gear[8].enchanted == false)
    check("their score from their gear, kept for tooltips too", rec.score and rec.score > 0 and not rec.scoreShared
        and Score.Known(guid1) ~= nil)
    check("their talents: 5/20/0, Fury, damage", rec.talents.spent[1] == 5 and rec.talents.tree == "Fury"
        and rec.role == "DAMAGER")
    check("then the inspect is let go", state.cleared == 1)
    state.Advance(0.4)
    check("the next not before 2 s after the last request", state.asked == 1)
    state.Advance(0.2)
    check("then the next", state.asked == 2 and state.lastAsked == "party2")
    state.combat = true
    state.Fire("INSPECT_READY", list[3].guid)
    state.Advance(30)
    check("in combat: none asked", state.asked == 2)
    state.combat = false
    state.Fire("PLAYER_REGEN_ENABLED")
    state.Advance(0)
    check("combat over: on again", state.asked == 3 and state.lastAsked == "party3")
    local window = { shown = true }
    function window.IsShown(self) return self.shown end
    env.InspectFrame = window
    env.InspectUnit("party4")
    state.Advance(10)
    check("your inspect goes first: ours dropped, none asked while yours shows", state.asked == 3
        and list[4].state ~= "inspecting")
    window.shown = false
    env.InspectFrame = nil
    state.Advance(10)
    check("yours closed: ours asked again", state.asked == 4 and state.lastAsked == "party3")
    state.Fire("INSPECT_READY", list[4].guid)
    state.Advance(2)
    state.Fire("INSPECT_READY", list[5].guid)
    check("everyone read", list[4].state == "ready" and list[5].state == "ready")
    local asked = state.asked
    state.Advance(100)
    check("everyone known: the walk stops", state.asked == asked)
    state.Advance(250)
    check("stale after five minutes: read again", state.asked == asked + 1)
    check("records changed once each per burst", seen[guid1] ~= nil)
    GI.Close()
    check("closed: its events go quiet, the inspect let go", not GI.IsOpen() and not frame.events.GROUP_ROSTER_UPDATE
        and not scoreFrame.events.INSPECT_READY)
    asked = state.asked
    state.Advance(1000)
    check("closed: nothing asked", state.asked == asked)
end

do
    local ns, state = Fixture()
    local GI = ns.GroupInspect
    state.values.groupInspect = true
    state.Party(3)
    state.nfGUID = "Player-1-0011"
    state.far = { party2 = true }
    GI.Open()
    state.Advance(0)
    check("a Naowh Forever user is read after the rest, and one out of range is skipped",
        state.lastAsked == "party3" and GI.Member("Player-1-0012").state == "out_of_range"
        and GI.Member("Player-1-0012").inRange == false and GI.Member("Player-1-0011").hasNF == true)
    state.Fire("INSPECT_READY", "Player-1-0013")
    state.Advance(2)
    check("then the Naowh Forever user, for their gear", state.lastAsked == "party1")
    state.Fire("INSPECT_READY", "Player-1-0011")
    state.Advance(2)
    check("out of range: not asked", state.asked == 2)
    state.far = nil
    state.Advance(5)
    check("looked at again later, asked once in range", state.asked == 3 and state.lastAsked == "party2")
    state.Fire("INSPECT_READY", "Player-1-0012")
    state.Advance(2)
    GI.Refresh("Player-1-0013")
    check("refresh: forgotten and queued", GI.Member("Player-1-0013").state == "queued")
    state.Advance(0)
    check("and asked again", state.asked == 4 and state.lastAsked == "party3")
    state.Fire("INSPECT_READY", "Player-1-0013")
    state.units.party1.online = false
    state.Fire("UNIT_CONNECTION", "party1", false)
    state.Advance(0)
    check("offline: shown so", GI.Member("Player-1-0011").state == "offline")
    state.Fire("UNIT_INVENTORY_CHANGED", "party3")
    state.Advance(2)
    check("a member's gear changed: read again", state.asked == 5 and state.lastAsked == "party3")
end

do
    local ns, state = Fixture()
    local GI = ns.GroupInspect
    state.values.groupInspect = true
    state.Party(1)
    local statsCalls, statsLoaded = 0, false
    GI.StatsFromGear = function(rec)
        statsCalls = statsCalls + 1
        rec.stats = rec.stats or { AGI = 1 }
        return statsLoaded
    end
    GI.Open()
    state.Advance(0)
    local old = GI.Member("Player-1-0011")
    local shareTalents = { spent = { 0, 0, 31 }, tree = "Protection", role = "Tank" }
    old.talents, old.hasNF, old.nfVersion = shareTalents, true, "0.5.25"
    state.Fire("INSPECT_READY", "Player-1-0011")
    check("stats summed from the gear once it is read", statsCalls >= 2 and old.stats ~= nil)
    check("talents from their Naowh Forever kept over the inspect's", old.talents == shareTalents)
    check("items not loaded for the stats: item data listened for", state.frames[2].events.GET_ITEM_INFO_RECEIVED)
    statsLoaded = true
    local before = statsCalls
    state.Fire("GET_ITEM_INFO_RECEIVED", 1, true)
    state.Advance(0.2)
    check("and summed again when it comes, then no longer listened for", statsCalls > before
        and not state.frames[2].events.GET_ITEM_INFO_RECEIVED)
    old.statsShared = true
    before = statsCalls
    GI.Refresh("Player-1-0011")
    state.Advance(2)
    state.Fire("INSPECT_READY", "Player-1-0011")
    check("exact stats from their Naowh Forever: not summed over", statsCalls == before)
    state.Person("party1", "Player-1-0099", "New", "Person")
    state.units.party1.gear = nil
    state.Fire("GROUP_ROSTER_UPDATE")
    state.Advance(0)
    local new = GI.Member("Player-1-0099")
    check("party1 is someone else now: the old record gone", GI.Member("Player-1-0011") == nil)
    check("and theirs fresh: none of the old one's data", new and new.name == "New Person" and new.gear[1] == nil
        and new.talents == nil and new.stats == nil and new.hasNF == nil and new.nfVersion == nil
        and not new.statsShared and new.score == nil)
end

do
    local ns, state = Fixture()
    local GI = ns.GroupInspect
    state.values.groupInspect = true
    state.raid, state.members = true, 39
    for i = 1, 40 do
        if i == 7 then
            state.units.raid7 = state.units.player
        else
            state.Person("raid" .. i, ("Player-1-%04d"):format(100 + i), "Raider" .. i, "Name")
        end
    end
    local calls = 0
    GI.OnChange(function() calls = calls + 1 end)
    GI.Open()
    local list = GI.Members()
    check("raid of 40: you first, once, then raid order", GI.Mode() == "raid" and GI.Count() == 40
        and list[1].unit == "player" and list[2].unit == "raid1" and list[8].unit == "raid8")
    local seen, dupes = {}, false
    for _, rec in ipairs(list) do
        if seen[rec.guid] then dupes = true end
        seen[rec.guid] = true
    end
    check("no one listed twice", not dupes)
    state.Advance(0)
    for _ = 1, 39 do
        state.Fire("INSPECT_READY", GI.Member(("Player-1-%04d"):format(100 + tonumber(state.lastAsked:match("%d+")))).guid)
        state.Advance(2)
    end
    local ready = 0
    for _, rec in ipairs(list) do if rec.state == "ready" then ready = ready + 1 end end
    check("all 39 read, 2 s apart", ready == 39 and state.asked == 39)
    for _ = 1, 20 do state.Fire("GROUP_ROSTER_UPDATE") end
    calls = 0
    state.Advance(0)
    check("a burst of roster updates: one rebuild, one callback", calls == 1)
    Measure("a raid of 40's roster update", 0.2, function()
        state.Fire("GROUP_ROSTER_UPDATE")
        state.Advance(0)
    end)
    local raider = GI.Member("Player-1-0101")
    local function Read()
        GI.Refresh(raider.guid)
        state.Advance(2)
        state.Fire("INSPECT_READY", raider.guid)
        state.Advance(0)
    end
    for _ = 1, 5 do Read() end
    Measure("a member inspected and read", 0.2, Read)
    local per = 0
    GI.OnChange(function(guid) if guid == raider.guid then per = per + 1 end end)
    GI.Changed(raider.guid)
    GI.Changed(raider.guid)
    state.Advance(0)
    check("a member changed twice in a burst: one callback", per == 1)
    state.raid, state.members = false, 0
    state.Fire("GROUP_ROSTER_UPDATE")
    state.Advance(0)
    check("left the raid: solo, only you", GI.Mode() == "solo" and GI.Count() == 1 and GI.Member(raider.guid) == nil)
end

do
    local ns, state = Fixture()
    local GI = ns.GroupInspect
    state.values.groupInspect = true
    state.Party(4)
    GI.Open()
    state.Advance(0)
    local asked = state.asked
    GI.Preview(true)
    check("preview: a party of 5", GI.Mode() == "party" and GI.Count() == 5 and GI.Members()[1].state == "self")
    for _, rec in ipairs(GI.Members()) do
        check(rec.name .. ": a full record", rec.guid and rec.classFile and rec.level and rec.role and rec.score
            and rec.ilvl and rec.gear[1] and rec.gear[1].id and rec.gear[1].quality and rec.talents
            and #rec.talents.spent == 3 and rec.stats and rec.stats.STA)
    end
    check("a mix of Naowh Forever users", GI.Members()[2].hasNF == true and GI.Members()[3].hasNF == false
        and GI.Members()[2].statsShared and not GI.Members()[3].statsShared)
    GI.PreviewMode("raid")
    local list = GI.Members()
    check("raid preview: 25", GI.Mode() == "raid" and GI.Count() == 25 and GI.Member(list[12].guid) == list[12])
    local states = {}
    for _, rec in ipairs(list) do states[rec.state] = (states[rec.state] or 0) + 1 end
    check("with a few not read yet", states.ready == 21 and states.offline == 1 and states.out_of_range == 1
        and states.queued == 1 and states.self == 1)
    check("a member out of range with Naowh Forever: its shared score, talents and stats, no gear",
        list[19].talents and list[19].stats and list[19].score and list[19].scoreShared and next(list[19].gear) == nil)
    check("one offline: nothing but who they are", list[23].state == "offline" and list[23].online == false
        and list[23].score == nil and list[23].talents == nil and list[23].name == "Talia Stormcaller")
    local classes = {}
    for _, rec in ipairs(list) do classes[rec.classFile] = true end
    check("every class", classes.WARRIOR and classes.PALADIN and classes.HUNTER and classes.ROGUE and classes.PRIEST
        and classes.SHAMAN and classes.MAGE and classes.WARLOCK and classes.DRUID)
    GI.Refresh(list[3].guid)
    state.Advance(30)
    check("while previewing, nothing asked", state.asked == asked)
    GI.Preview(false)
    check("preview off: the real roster", GI.Count() == 5 and GI.Members()[2].unit == "party1")
    state.Advance(30)
    check("and the walk on again", state.asked > asked)
end

print(("test-group-inspect-data: %d checks passed"):format(checks))

-- Run with Lua 5.1 from the repository root: the Naowh Score. Its formula on sets of known
-- gear (a full epic set of a level scores that level; quality, slots, a two-hander, empty
-- slots, an item not loaded yet); player tooltips (off until turned on, one inspect at a time,
-- kept by GUID, filled in when the gear comes, never in combat or while the game's Inspect
-- window, or the talents opened from it, holds the inspect); your group scanned in the
-- background; your score shared with your group and guild while Share My Score and the score are on,
-- theirs kept either way; and what
-- the hot paths cost and keep.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end
local Measure = dofile("Tools/regression/measure.lua")(check)
local NOTHING = function() end

-------------------------------------------------------------------------------
--  Stubs: gear by unit and slot as { level, quality, equip }, links "item:<unit>:<slot>"
-------------------------------------------------------------------------------
local function Fixture()
    local state = { gear = {}, now = 100, combat = false, inspected = {}, cleared = 0, postCalls = {},
        frames = {}, timers = {}, sent = {}, members = 0, guild = false,
        fullNames = { player = "Me", party1 = "One", party2 = "Two", party3 = "Three" },
        guildRoster = { { "Guildie", "Player-7-00AB" }, { "Ninth", "Player-9-00AB" } },
        values = { enabled = true, naowhScore = false, naowhScoreShare = true, naowhScoreTooltip = true,
            naowhScoreScan = true } }
    local listeners = {}
    local S = {
        Get = function(key) return state.values[key] end,
        Set = function(key, value)
            state.values[key] = value
            for i = 1, #listeners do listeners[i](key, value) end
        end,
        OnChange = function(fn) listeners[#listeners + 1] = fn end,
    }
    state.roster, state.account, state.clock = {}, {}, 2000000000
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QoLSettings = S, Apply = NOTHING, Shared = { ItemFacts = {}, Style = { LOGO_SMALL = "logo" },
        Roster = { AddTooltip = function(fn) state.roster[#state.roster + 1] = fn end },
        Ago = function(when) return (state.clock - when) .. "s ago" end },
        AccountSettings = function() return state.account end,
        Color = function(_, text) return "<" .. text .. ">" end,
        THEME = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end }) }
    local function Item(link)
        local unit, slot = link:match("^item:(%w+):(%d+)$")
        return unit and state.gear[unit] and state.gear[unit][tonumber(slot)]
    end
    -- The tooltip: its lines, the right text of each as the game's TextRight font strings.
    local lines, rights = {}, {}
    local tooltip = {
        GetUnit = function() return "Someone", state.hovered end,
        -- The player the tooltip was built for: the one hovered, by the same GUID the game gives.
        GetPrimaryTooltipData = function() return { guid = state.UnitGUID(state.hovered) } end,
        IsForbidden = function() return false end,
        IsShown = function() return true end,
        Show = NOTHING,
        HookScript = function(self, script, fn) self[script] = fn end,
        AddDoubleLine = function(_, left, right)
            lines[#lines + 1] = left
            local n = #lines
            rights[n] = rights[n] or { SetText = function(self, text) self.text = text end }
            rights[n].text = right
        end,
        NumLines = function() return #lines end,
    }
    state.lines, state.rights, state.tooltip = lines, rights, tooltip
    -- Each module's own event frame.
    local function Frame()
        local frame = { events = {} }
        function frame.RegisterEvent(self, event) self.events[event] = true end
        function frame.UnregisterEvent(self, event) self.events[event] = nil end
        function frame.SetScript(self, _, fn) self.onEvent = fn end
        state.frames[#state.frames + 1] = frame
        return frame
    end
    local units = { player = "Player-1-1" }
    state.units = units
    local env = setmetatable({
        _G = setmetatable({ NaowhForever = ns }, { __index = function(_, key)
            local n = key:match("^GameTooltipTextRight(%d+)$")
            return n and rights[tonumber(n)]
        end }),
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        issecretvalue = function(value) return value ~= nil and rawequal(value, state.SECRET) end,
        C_Item = {
            GetDetailedItemLevelInfo = function(link) local i = Item(link) return i and i[1] end,
            GetItemInfo = function(link) local i = Item(link) if i then return "x", link, i[2], i[1] end end,
            -- An item ID: where it goes, as state.instant has it; a link: its gear's.
            GetItemInfoInstant = function(link)
                if type(link) == "number" then
                    local equip = state.instant and state.instant[link]
                    if equip then return link, "", "", equip end
                    return nil
                end
                local i = Item(link)
                if i then return 1, "", "", i[3] end
            end,
        },
        GetInventoryItemLink = function(unit, slot)
            return state.gear[unit] and state.gear[unit][slot] and ("item:" .. unit .. ":" .. slot)
        end,
        GetTime = function() return state.now end,
        CreateFrame = Frame,
        GameTooltip = tooltip,
        TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) state.postCalls[#state.postCalls + 1] = fn end },
        Enum = { TooltipDataType = { Unit = 2 }, ClubMemberPresence = { Online = 1, Offline = 3 } },
        time = function() return state.clock end,
        hooksecurefunc = function(t, key, fn)
            local original = t[key]
            t[key] = function(...) original(...); fn(...) end
        end,
        UnitIsPlayer = function(unit) return unit ~= nil end,
        UnitGUID = function(unit) return units[unit] or (unit and ("Player-1-" .. unit:gsub("%a", "") .. "9")) end,
        UnitIsUnit = function(a, b) return a == b end,
        UnitExists = function(unit) return unit == "player" or state.gear[unit] ~= nil end,
        UnitIsConnected = function() return true end,
        UnitLevel = function() return state.level or 60 end,
        ITEM_QUALITY_COLORS = { [0] = { hex = "|cff9d9d9d" }, [1] = { hex = "|cffffffff" }, [2] = { hex = "|cff1eff00" },
            [3] = { hex = "|cff0070dd" }, [4] = { hex = "|cffa335ee" }, [5] = { hex = "|cffff8000" } },
        InCombatLockdown = function() return state.combat end,
        CanInspect = function() return true end,
        CheckInteractDistance = function(unit) return not (state.far and state.far[unit]) end,
        NotifyInspect = function(unit) state.inspected[#state.inspected + 1] = unit end,
        ClearInspectPlayer = function() state.cleared = state.cleared + 1 end,
        C_Timer = { After = function(_, fn) state.timers[#state.timers + 1] = fn end },
        C_ChatInfo = { RegisterAddonMessagePrefix = NOTHING,
            SendAddonMessage = function(_, message, channel) state.sent[#state.sent + 1] = { message, channel } end },
        LE_PARTY_CATEGORY_INSTANCE = 2,
        IsInGroup = function(category) return category == nil and state.members > 0 end,
        IsInRaid = function() return false end,
        IsInGuild = function() return state.guild end,
        GetNumSubgroupMembers = function() return state.members end,
        GetNumGroupMembers = function() return state.members + 1 end,
        UnitFullName = function(unit) return state.fullNames[unit] end,
        GetNormalizedRealmName = function() return "Forever" end,
        GetNumGuildMembers = function() return #state.guildRoster end,
        GetGuildRosterInfo = function(i)
            local m = state.guildRoster[i]
            if m then return m[1], nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, m[2] end
        end,
    }, { __index = _G })
    state.UnitGUID, state.units, state.SECRET = env.UnitGUID, units, {}
    Load({ "Core/Senders.lua", "NaowhForever_BiS/NaowhScore/Data/Formula.lua", "NaowhForever_BiS/NaowhScore/NaowhScore.lua", "NaowhForever_BiS/NaowhScore/Inspect.lua", "NaowhForever_BiS/NaowhScore/Share.lua" },
        env)
    -- An event, to every frame listening for it (Share always; Inspect while on).
    function state.Fire(event, ...)
        for _, frame in ipairs(state.frames) do
            if frame.events[event] then frame.onEvent(frame, event, ...) end
        end
    end
    -- The timers waiting, run until none is left.
    function state.RunTimers()
        local guard = 0
        while state.timers[1] and guard < 50 do
            guard = guard + 1
            table.remove(state.timers, 1)()
        end
    end
    return ns, state, env
end

-- A full set, every slot at one level and quality; a two-hander or a main and off hand.
local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local function Set(level, quality, twoHand)
    local gear = {}
    for _, slot in ipairs(SLOTS) do gear[slot] = { level, quality, "INVTYPE_HEAD" } end
    if twoHand then
        gear[16] = { level, quality, "INVTYPE_2HWEAPON" }
        gear[17] = nil
    end
    return gear
end

-------------------------------------------------------------------------------
--  The formula
-------------------------------------------------------------------------------
do
    local ns, state = Fixture()
    local Score = ns.NaowhScore
    local function Of(gear)
        state.gear.player = gear
        return Score.Unit("player")
    end
    check("a full set of level 26 epics scores 26", math.abs(Of(Set(26, 4)) - 26) < 1e-9)
    check("so does it with a two-hander in place of a main and off hand",
        math.abs(Of(Set(26, 4, true)) - 26) < 1e-9)
    check("the same set in blues scores less, in greens less again",
        Of(Set(26, 3)) < 26 and Of(Set(26, 2)) < Of(Set(26, 3)))
    check("nothing worn scores 0", Of({}) == 0)
    -- The fitted worth of a quality (Data/Formula.lua): an epic of level x SCALE + SHIFT.
    local function Worth(level, quality) return level * Score.SCALE[quality] + Score.SHIFT[quality] end
    check("a full set of level 60 blues scores what a level 60 blue is worth",
        math.abs(Of(Set(60, 3)) - Worth(60, 3)) < 1e-9 and Worth(60, 3) > 40 and Worth(60, 3) < 55)
    check("a full set of level 20 greens scores what a level 20 green is worth",
        math.abs(Of(Set(20, 2)) - Worth(20, 2)) < 1e-9 and Worth(20, 2) > 5 and Worth(20, 2) < 12)
    check("starter whites worth less than nothing count 0", Of(Set(5, 1)) == 0)
    local gear = Set(30, 4)
    gear[5] = nil
    local noChest = Of(gear)
    gear = Set(30, 4)
    gear[11] = nil
    local noRing = Of(gear)
    check("an empty chest costs more than an empty ring: it carries more", noChest < noRing and noRing < 30)
    check("the shirt and tabard do not count", (function()
        local g = Set(30, 4)
        g[4], g[19] = { 300, 4, "INVTYPE_BODY" }, { 300, 4, "INVTYPE_TABARD" }
        return math.abs(Of(g) - 30) < 1e-9
    end)())
    gear = Set(30, 4)
    gear[1] = { 30, nil, "INVTYPE_HEAD" }   -- its quality not loaded yet
    local _, complete = Of(gear)
    check("an item not loaded yet: the score says it is not complete", complete == false)
    check("26.4 reads 26.4", Score.Text(26.44) == "26.4")
    state.gear.player = Set(40, 3)
    Measure("a character's score", 0.05, function() Score.Unit("player") end)
end

-------------------------------------------------------------------------------
--  Player tooltips
-------------------------------------------------------------------------------
do
    local ns, state = Fixture()
    local S = ns.QoLSettings
    S.Set("naowhScoreScan", false)   -- the hover alone here; the scan has its own test
    ns.Apply()
    check("off by default: no tooltip hook, no inspect listened for", #state.postCalls == 0
        and not state.frames[1].events.INSPECT_READY)
    S.Set("naowhScore", true)
    check("on: its hook goes in a frame later, after every module's (the badge line first)",
        #state.postCalls == 0 and state.timers[1] ~= nil)
    state.RunTimers()
    check("then once", #state.postCalls == 1 and state.frames[1].events.INSPECT_READY)
    ns.Apply()
    check("and only once", #state.postCalls == 1)
    local OnUnit = state.postCalls[1]
    local function Hover(unit)
        state.hovered = unit
        for k in pairs(state.lines) do state.lines[k] = nil end
        OnUnit(state.tooltip)
        return state.rights[#state.lines] and state.rights[#state.lines].text
    end
    state.gear.player = Set(20, 4)
    check("your own: from what you wear", Hover("player") == "20.0" and #state.inspected == 0)
    state.gear.party1 = Set(26, 4)
    local guid = "Player-1-19"
    check("another player's: asked for, '...' until it comes", Hover("party1") == "..."
        and state.inspected[1] == "party1")
    state.now = state.now + 0.5
    Hover("party1")
    check("not asked again while that request is out", #state.inspected == 1)
    state.Fire("INSPECT_READY", guid)
    check("the gear comes: the line fills in, and the inspect is let go",
        state.rights[#state.lines].text == "26.0" and state.cleared == 1)
    check("kept: hovered again, shown at once, not asked again", Hover("party1") == "26.0" and #state.inspected == 1)
    state.now = state.now + 400
    state.combat = true
    check("kept too long: asked again, but never in combat", Hover("party1") == "..." and #state.inspected == 1)
    state.combat = false
    local env = getfenv(OnUnit)
    env.InspectFrame = { IsShown = function() return true end }
    Hover("party1")
    check("nor while the game's Inspect window holds the inspect", #state.inspected == 1)
    env.InspectFrame = nil
    Hover("party1")
    check("then it is asked again", #state.inspected == 2)
    check("the guild list's tooltip is asked for with it", #state.roster == 1)
    local OnRoster = state.roster[1]
    local function Roster(member, presence)
        for k in pairs(state.lines) do state.lines[k] = nil end
        local added = OnRoster(state.tooltip, member, { guid = member, level = 60, presence = presence or 1 })
        return added, state.rights[#state.lines] and state.rights[#state.lines].text
    end
    ns.NaowhScore.Remember("Player-1-GUILD", 27.4, true, true, 60)
    local added, text = Roster("Player-1-GUILD")
    check("a guildmate whose score is known: the line, never an inspect", added and text == "27.4"
        and #state.inspected == 2)
    check("yours: from what you wear", select(2, Roster("Player-1-1")) == "20.0")
    added = Roster("Player-1-UNKNOWN")
    check("a guildmate not known: nothing, and no inspect", not added and #state.lines == 0 and #state.inspected == 2)
    local DAY = 86400
    local savedList = { old = { score = 5, at = state.clock - 31 * DAY }, broken = "x" }
    for i = 1, 500 do savedList["Player-8-" .. i] = { score = 10, level = 20, at = state.clock - i } end
    state.account.naowhScoreGuild = savedList
    ns.NaowhScore.Remember("Player-7-00AB", 31.2, true, true, 40)
    check("a guildmate's score is saved for the guild list", savedList["Player-7-00AB"]
        and savedList["Player-7-00AB"].score == 31.2 and savedList["Player-7-00AB"].level == 40)
    check("older than 30 days or damaged: dropped", savedList.old == nil and savedList.broken == nil)
    check("500 at most: the oldest goes", savedList["Player-8-500"] == nil and savedList["Player-8-499"] ~= nil)
    check("someone outside the guild: not saved", savedList["Player-1-GUILD"] == nil)
    ns.NaowhScore.Remember("Player-9-00AB", 12, false, false, 30)
    check("a score still loading: not saved", savedList["Player-9-00AB"] == nil)
    state.clock = state.clock + 2 * DAY
    added, text = Roster("Player-7-00AB", 3)
    check("offline: the saved score, and how long ago", added and text == "31.2 <(" .. 2 * DAY .. "s ago)>")
    check("online: the live one, no age", select(2, Roster("Player-7-00AB", 1)) == "31.2")
    check("offline with nothing saved: no line", not Roster("Player-1-GUILD", 3))
    S.Set("naowhScore", false)
    check("off: no line", Hover("party1") == nil)
    check("off: none in the guild list either", not Roster("Player-1-GUILD"))
    check("off: none for an offline member", not Roster("Player-7-00AB", 3))
    ns.NaowhScore.Remember("Player-9-00AB", 14, true, true, 30)
    check("off: nothing saved", savedList["Player-9-00AB"] == nil)
end

-- Reported on Forever: a unit's GUID can come back secret by the time its gear arrives, and the
-- tooltip can have moved on to someone else.
do
    local ns, state = Fixture()
    local S = ns.QoLSettings
    S.Set("naowhScoreScan", false)
    S.Set("naowhScore", true)
    state.RunTimers()
    local OnUnit = state.postCalls[1]
    state.gear.party1, state.gear.party2 = Set(26, 4), Set(30, 4)
    state.hovered = "party1"
    OnUnit(state.tooltip)
    state.units.party1 = state.SECRET
    state.Fire("INSPECT_READY", "Player-1-19")
    -- Plain Lua cannot make that comparison fail as the game does; this checks the outcome.
    check("a GUID gone secret when the gear comes: nothing kept",
        state.rights[#state.lines].text == "...")
    state.units.party1 = nil
    state.now = state.now + 5
    state.hovered = "party1"
    for k in pairs(state.lines) do state.lines[k] = nil end
    OnUnit(state.tooltip)
    state.hovered = "party2"
    state.Fire("INSPECT_READY", "Player-1-19")
    check("the tooltip moved on: the old player's line is not filled in",
        state.rights[#state.lines].text == "...")
end

-- Reported on Forever: UNIT_INVENTORY_CHANGED for a compound unit (targettarget) answers
-- UnitIsUnit with a secret, which the game will not let us test. Plain Lua cannot fail on it
-- as the game does; this checks the outcome: nothing is reset and no scan is queued.
do
    local ns, state, env = Fixture()
    local S = ns.QoLSettings
    S.Set("naowhScore", true)
    S.Set("naowhScoreScan", true)
    state.RunTimers()
    local real = env.UnitIsUnit
    env.UnitIsUnit = function(a, b) if a == "targettarget" then return state.SECRET end return real(a, b) end
    state.Fire("UNIT_INVENTORY_CHANGED", "targettarget")
    check("a secret answer for a compound unit: no scan queued", #state.timers == 0)
    state.Fire("UNIT_INVENTORY_CHANGED", "party1")
    check("a group member's gear changing still queues one", #state.timers == 1)
    env.UnitIsUnit = real
end

-------------------------------------------------------------------------------
--  Your group, in the background
-------------------------------------------------------------------------------
do
    local ns, state = Fixture()
    state.members = 3
    state.gear.party1, state.gear.party2, state.gear.party3 = Set(10, 4), Set(20, 4), Set(30, 4)
    ns.QoLSettings.Set("naowhScore", true)
    -- party2 runs Naowh Forever: its score is shared, so it is never inspected.
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S Player-1-29 250", "PARTY", "Two")
    state.RunTimers()
    check("the first member not known is read", state.inspected[1] == "party1" and #state.inspected == 1)
    state.Fire("INSPECT_READY", "Player-1-19")
    state.now = state.now + 2
    state.RunTimers()
    check("then the next, skipping one who shares theirs", state.inspected[2] == "party3" and #state.inspected == 2)
    state.Fire("INSPECT_READY", "Player-1-39")
    state.now = state.now + 2
    state.RunTimers()
    check("and it stops once everyone is known", #state.inspected == 2 and not state.timers[1])
    local Score = ns.NaowhScore
    local function Near(guid, score) return math.abs(Score.Known(guid).score - score) < 1e-9 end
    check("their scores kept: inspected and shared", Near("Player-1-19", 10) and Near("Player-1-39", 30)
        and Near("Player-1-29", 25))
    state.Fire("INSPECT_READY", "Player-1-29")
    check("a shared score is never replaced by an inspect", Score.Known("Player-1-29").shared)
    Measure("the group walked, everyone known", 0.05, function() Score.Scan() end)
    ns.QoLSettings.Set("naowhScoreScan", false)
    check("Scan Your Group off: no roster listened to", not state.frames[1].events.GROUP_ROSTER_UPDATE)
end

-------------------------------------------------------------------------------
--  The player you hover goes first
-------------------------------------------------------------------------------
do
    local ns, state = Fixture()
    state.members = 2
    state.gear.party1, state.gear.party2 = Set(10, 4), Set(20, 4)
    ns.QoLSettings.Set("naowhScore", true)
    state.RunTimers()
    check("the walk is reading a group member", state.inspected[1] == "party1" and #state.inspected == 1)
    local OnUnit = state.postCalls[1]
    state.gear.mouseover, state.hovered = Set(30, 4), "mouseover"
    OnUnit(state.tooltip)
    check("hovered while the inspect is busy: '...', not asked over it", #state.inspected == 1)
    state.Fire("INSPECT_READY", "Player-1-19")
    state.now = state.now + 2
    state.RunTimers()
    check("asked next, ahead of the rest of the group", state.inspected[2] == "mouseover")
    state.Fire("INSPECT_READY", "Player-1-9")
    state.now = state.now + 2
    state.RunTimers()
    check("then the group's walk goes on", state.inspected[3] == "party2")
end

do
    local ns, state = Fixture()
    state.members = 2
    state.gear.party1, state.gear.party2 = Set(10, 4), Set(20, 4)
    ns.QoLSettings.Set("naowhScore", true)
    state.RunTimers()
    state.gear.mouseover, state.hovered = Set(30, 4), "mouseover"
    state.postCalls[1](state.tooltip)
    state.gear.mouseover = nil
    state.Fire("INSPECT_READY", "Player-1-19")
    state.now = state.now + 2
    state.RunTimers()
    check("moved off them before their turn: the group goes on", state.inspected[2] == "party2")
end

do
    local ns, state = Fixture()
    local S = ns.QoLSettings
    S.Set("naowhScoreScan", false)
    S.Set("naowhScore", true)
    state.RunTimers()
    local OnUnit = state.postCalls[1]
    local gear = Set(26, 4)
    gear[1] = { 26, nil, "INVTYPE_HEAD" }
    state.gear.party1 = gear
    state.hovered = "party1"
    OnUnit(state.tooltip)
    state.Fire("INSPECT_READY", "Player-1-19")
    local events = state.frames[1].events
    check("an item still loading: item data listened for", events.GET_ITEM_INFO_RECEIVED == true)
    gear[1] = { 26, 4, "INVTYPE_HEAD" }
    for _ = 1, 50 do state.Fire("GET_ITEM_INFO_RECEIVED", 1234, true) end
    check("a burst of item data scores once, a moment later", #state.timers == 1)
    state.RunTimers()
    check("then the score is whole and the line filled in", ns.NaowhScore.Known("Player-1-19").complete == true
        and state.rights[#state.lines].text == "26.0" and not events.GET_ITEM_INFO_RECEIVED)
    Measure("a burst of item data while one score waits", 0.05, function()
        for _ = 1, 50 do state.frames[1].onEvent(state.frames[1], "GET_ITEM_INFO_RECEIVED", 1234, true) end
        state.timers[1] = nil
    end)
end

-------------------------------------------------------------------------------
--  Players nearby: target, focus, mouseover and shown nameplates
-------------------------------------------------------------------------------
do
    local ns, state = Fixture()
    state.values.naowhScoreScan, state.values.naowhScoreNearby = false, true
    state.gear.nameplate1, state.gear.nameplate2, state.gear.target = Set(12, 3), Set(14, 3), Set(16, 3)
    state.far = { nameplate2 = true }
    ns.QoLSettings.Set("naowhScore", true)
    table.remove(state.timers, 1)()   -- the tooltip hook, a frame after Apply
    check("Scan Players Nearby on: nameplates and target listened to",
        state.frames[1].events.NAME_PLATE_UNIT_ADDED and state.frames[1].events.PLAYER_TARGET_CHANGED
        and not state.frames[1].events.GROUP_ROSTER_UPDATE)
    state.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    state.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    state.Fire("PLAYER_TARGET_CHANGED")
    state.timers[1]()
    table.remove(state.timers, 1)
    check("your target first", state.inspected[1] == "target")
    state.Fire("INSPECT_READY", "Player-1-9")
    state.now = state.now + 2
    table.remove(state.timers, 1)()
    check("then a player whose nameplate shows", state.inspected[2] == "nameplate1")
    state.Fire("INSPECT_READY", "Player-1-19")
    state.now = state.now + 2
    for i = #state.timers, 1, -1 do table.remove(state.timers, i)() end
    check("one out of inspect range is not asked, and looked at again later", #state.inspected == 2
        and state.timers[1] ~= nil)
    state.far = nil
    state.now = state.now + 5
    table.remove(state.timers, 1)()
    check("once in range, asked", state.inspected[3] == "nameplate2")
    state.Fire("INSPECT_READY", "Player-1-29")
    state.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    state.now = state.now + 2
    state.RunTimers()
    check("everyone known: the walk stops", #state.inspected == 3 and not state.timers[1])
    ns.QoLSettings.Set("naowhScoreNearby", false)
    check("Scan Players Nearby off: nothing around you listened to",
        not state.frames[1].events.NAME_PLATE_UNIT_ADDED and not state.frames[1].events.UPDATE_MOUSEOVER_UNIT)
end

-------------------------------------------------------------------------------
--  Sharing: to your group and guild while it is on; theirs kept
-------------------------------------------------------------------------------
do
    local ns, state = Fixture()
    local Score = ns.NaowhScore
    check("others' scores are listened for with the feature off",
        state.frames[2].events.CHAT_MSG_ADDON and state.values.naowhScore == false)
    state.values.naowhScore = true
    state.gear.player, state.guild = Set(20, 4), true
    state.Fire("PLAYER_ENTERING_WORLD")
    check("logging in: the guild is asked for theirs and given yours",
        state.sent[1][1] == "R" and state.sent[1][2] == "GUILD" and state.sent[2][1] == "S Player-1-1 200 60")
    local sent = #state.sent
    state.RunTimers()
    check("nothing changed: nothing more goes", #state.sent == sent)
    state.members = 1
    state.gear.party1 = Set(5, 2)
    state.Fire("GROUP_ROSTER_UPDATE")
    check("joining a group: it is asked, and given yours", state.sent[sent + 1][1] == "R"
        and state.sent[sent + 1][2] == "PARTY" and state.sent[sent + 2][2] == "PARTY")
    sent = #state.sent
    state.gear.player = Set(22, 4)
    state.Fire("PLAYER_EQUIPMENT_CHANGED", 1)
    state.Fire("PLAYER_EQUIPMENT_CHANGED", 2)
    state.RunTimers()
    check("a gear swap: one message to the group and one to the guild",
        #state.sent == sent + 2 and state.sent[sent + 1][1] == "S Player-1-1 220 60")
    sent = #state.sent
    state.combat = true
    state.gear.player = Set(24, 4)
    state.Fire("PLAYER_EQUIPMENT_CHANGED", 1)
    state.RunTimers()
    check("in combat: held", #state.sent == sent)
    state.combat = false
    state.Fire("PLAYER_REGEN_ENABLED")
    check("and sent once it ends", #state.sent > sent and state.sent[#state.sent][1] == "S Player-1-1 240 60")
    sent = #state.sent
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "R", "PARTY", "Someone")
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "R", "PARTY", "Another")
    state.RunTimers()
    check("asked twice at once: answered once", #state.sent == sent + 1 and state.sent[#state.sent][2] == "PARTY")
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S Player-7-00AB 264 31", "GUILD", "Guildie")
    check("a guildmate's, kept at once, as shared, with their level", Score.Known("Player-7-00AB").score == 26.4
        and Score.Known("Player-7-00AB").shared and Score.Known("Player-7-00AB").level == 31)
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S nonsense", "GUILD", "Guildie")
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S Player-7-00AB 264", "WHISPER", "Stranger")
    state.Fire("CHAT_MSG_ADDON", "OtherAddon", "S Player-8-00AB 999", "GUILD", "Guildie")
    check("nonsense, whispers and other addons' messages are ignored", Score.Known("Player-8-00AB") == nil)
    state.Fire("CHAT_MSG_ADDON", state.SECRET, "S Player-9-00AB 264", "GUILD", "Ninth")
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S Player-9-00AB 264", state.SECRET, "Ninth")
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S |TInterface\\Icons\\X:0|t 264", "GUILD", "Ninth")
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S %s%d 264", "GUILD", "Ninth")
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S Player-9-00AB " .. ("9"):rep(400), "GUILD", "Ninth")
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S Player-9-00AB 264 " .. ("|cffff0000x|r"):rep(300), "GUILD", "Ninth")
    check("crafted payloads keep nothing", Score.Known("Player-9-00AB") == nil)
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S Player-9-00AB 264 " .. ("9"):rep(400), "GUILD", "Ninth")
    check("a level past any real one is dropped, the score kept", Score.Known("Player-9-00AB").score == 26.4
        and Score.Known("Player-9-00AB").level == nil)
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S Player-7-00AB 999", "GUILD", "Ninth")
    check("a guildmate sending another's GUID is dropped", Score.Known("Player-7-00AB").score == 26.4)
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S Player-6-00AB 500", "GUILD", "Outsider")
    check("a sender not in the guild is dropped", Score.Known("Player-6-00AB") == nil)
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S Player-7-00AB 300", "GUILD", "Guildie-Forever")
    check("the guildmate's own, with your realm after the name, is taken", Score.Known("Player-7-00AB").score == 30)
    state.members = 2
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S Player-1-29 400", "PARTY", "One")
    check("a group member sending another member's GUID is dropped", Score.Known("Player-1-29") == nil)
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S Player-1-29 400", "PARTY", "Two")
    check("their own is taken", Score.Known("Player-1-29").score == 40)
    state.members = 0
    local onEvent = state.frames[2].onEvent
    Measure("a shared score received", 0.02, function()
        onEvent(state.frames[2], "CHAT_MSG_ADDON", "NaowhScore", "S Player-7-00AB 264", "GUILD", "Guildie")
    end)
    Measure("another addon's message passed over", 0.005, function()
        onEvent(state.frames[2], "CHAT_MSG_ADDON", "OtherAddon", "hello", "GUILD", "Someone")
    end)
end

-------------------------------------------------------------------------------
--  Share My Score off, or the score off: yours never goes out, theirs still kept
-------------------------------------------------------------------------------
do
    local ns, state = Fixture()
    local Score = ns.NaowhScore
    local S = ns.QoLSettings
    state.values.naowhScore, state.values.naowhScoreShare = true, false
    state.gear.player, state.guild, state.members = Set(20, 4), true, 1
    state.Fire("PLAYER_ENTERING_WORLD")
    state.RunTimers()
    check("Share My Score off: logging in only asks for theirs",
        #state.sent == 2 and state.sent[1][1] == "R" and state.sent[2][1] == "R")
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "R", "PARTY", "Someone")
    state.gear.player = Set(22, 4)
    state.Fire("PLAYER_EQUIPMENT_CHANGED", 1)
    state.RunTimers()
    check("nor answers a request or sends a gear swap", #state.sent == 2)
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S Player-7-00AB 264 31", "GUILD", "Guildie")
    check("a guildmate's is still kept", Score.Known("Player-7-00AB").score == 26.4)
    S.Set("naowhScoreShare", true)
    state.RunTimers()
    check("turned on: yours goes to the group and guild", #state.sent == 4
        and state.sent[3][1] == "S Player-1-1 220 60" and state.sent[3][2] == "PARTY" and state.sent[4][2] == "GUILD")
    S.Set("naowhScore", false)
    state.RunTimers()
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "R", "GUILD", "Guildie")
    state.gear.player = Set(24, 4)
    state.Fire("PLAYER_EQUIPMENT_CHANGED", 1)
    state.RunTimers()
    check("the Naowh Score off: nothing more goes", #state.sent == 4)
    S.Set("naowhScore", true)
    S.Set("enabled", false)
    state.RunTimers()
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "R", "PARTY", "Someone")
    state.gear.player = Set(26, 4)
    state.Fire("PLAYER_EQUIPMENT_CHANGED", 1)
    state.RunTimers()
    check("the QoL module off: nothing goes either", #state.sent == 4)
end

-------------------------------------------------------------------------------
--  Claims for someone else: a score is kept only from the guild member its GUID names
-------------------------------------------------------------------------------
do
    local ns, state = Fixture()
    local Score = ns.NaowhScore
    state.guildRoster[#state.guildRoster + 1] = { "Guildie2", "Player-7-00CD" }
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S Player-7-00AB 264 31", "GUILD", "Guildie")
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S Player-7-00AB 9999 60", "GUILD", "Mallory")
    check("another sender cannot overwrite a shared score", Score.Known("Player-7-00AB").score == 26.4)
    local kept = 0
    for i = 1, 10 do
        local guid = ("Player-8-%04X"):format(i)
        state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S " .. guid .. " 9999 60", "GUILD", "Mallory")
        if Score.Known(guid) then kept = kept + 1 end
    end
    check("a sender outside the guild speaks for no GUID", kept == 0)
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S Player-7-00AB 270 31", "GUILD", "Guildie")
    check("the owner still updates theirs", Score.Known("Player-7-00AB").score == 27)
    state.Fire("CHAT_MSG_ADDON", "NaowhScore", "S Player-7-00CD 270 99999999999", "GUILD", "Guildie2")
    check("a level past any real one is dropped", Score.Known("Player-7-00CD").level == nil)
end

-------------------------------------------------------------------------------
--  The best there is, and grades: against the best in the game, or for a level
-------------------------------------------------------------------------------
do
    local ns, state = Fixture()
    local Score = ns.NaowhScore
    -- Gear the data knows: { item level, required level, quality } and where it goes.
    local GEAR = {
        [1] = { 60, 55, 4, "INVTYPE_HEAD" }, [2] = { 30, 25, 3, "INVTYPE_HEAD" },
        [3] = { 60, 55, 4, "INVTYPE_FINGER" }, [4] = { 58, 53, 4, "INVTYPE_FINGER" },
        [5] = { 60, 0, 4, "INVTYPE_CHEST" },   -- a faction reward: no required level
        [6] = { 60, 55, 4, "INVTYPE_2HWEAPON" }, [7] = { 60, 55, 4, "INVTYPE_WEAPON" },
    }
    ns.Journal = { NotYet = { [8] = { 4, 0, 90, 60, 5, 134400, "Not Yet" } } }
    ns.Shared.ItemFacts = {}
    for id, g in pairs(GEAR) do ns.Shared.ItemFacts[id] = { 4, 0, g[1], g[2], g[3] } end
    state.instant = {}
    for id, g in pairs(GEAR) do state.instant[id] = g[4] end
    state.instant[8] = "INVTYPE_HEAD"
    local W = Score.SLOTS
    local total = 0
    for _, slot in ipairs(SLOTS) do total = total + W[slot] end
    local expected = (W[1] * 60 + W[11] * 60 + W[12] * 58 + W[5] * 60 + (W[16] + W[17]) * 60) / total
    check("the best in the game: each slot's best, two different rings, a two-hander for both hands",
        math.abs(Score.Best() - expected) < 1e-9)
    check("an item not in Forever yet is not the best in the game", ns.Journal.NotYet[8] and Score.Best() == expected)
    -- A level's best: a full set of blues five item levels over it (the data has little that
    -- low), never over the best in the game.
    local blue = function(level) return level * Score.SCALE[3] + Score.SHIFT[3] end
    local at30 = blue(35)
    check("for a level: a full set of blues five levels over it, capped at the best in the game",
        math.abs(Score.Best(30) - math.min(at30, Score.Best())) < 1e-9 and math.abs(Score.Best(10) - blue(15)) < 1e-9)
    at30 = Score.Best(30)
    check("rising with the level, and never over the best in the game", Score.Best(15) > Score.Best(14)
        and Score.Best(200) == Score.Best())
    check("a level 12 in whites is far from its best, not at it", Score.Grade(1.3, 12, "level") < 0.2)
    local share, quality = Score.Grade(Score.Best() * 0.5, 30)
    check("against the best in the game: half is green", math.abs(share - 0.5) < 1e-9 and quality == 2)
    state.values.naowhScoreCompare = "level"
    share, quality = Score.Grade(at30, 30)
    check("against the best for their level: the best for 30 is orange at 30", share == 1 and quality == 5)
    check("and colored as the top of the ramp", Score.Colored(at30, 30):find("^|cffff8000") ~= nil)
    state.values.naowhScoreCompare = "max"
    -- The ramp: grey at nothing, white, greens, blues, purples, orange at the best.
    check("the ramp: grey, white, green at 45%, blue at 65%, purple at 80%, orange at the best",
        Score.Code(0) == "|cff9e9e9e" and Score.Code(0.15) == "|cffffffff" and Score.Code(0.45) == "|cff1fff00"
        and Score.Code(0.65) == "|cff0070de" and Score.Code(0.8) == "|cffa336ed" and Score.Code(1) == "|cffff8000")
    check("between two stops, a color between them", Score.Code(0.3) ~= Score.Code(0.25)
        and Score.Code(0.3) ~= Score.Code(0.35))
    check("made once per percent", Score.Code(0.301) == Score.Code(0.3))
    -- The tooltip: the number, then its share in the same colour; no bar.
    local tip = Score.Tooltip(Score.Best() * 0.5, 30)
    check("the tooltip: the number and its percent, in one color",
        tip == Score.Colored(Score.Best() * 0.5, 30) .. "  " .. Score.Code(0.5) .. "50%|r")
    check("no bar", not tip:find("|T", 1, true))
    check("made once per percent", Score.Tooltip(Score.Best() * 0.5, 30) == tip)
    -- Both: the number against the best in the game, then in gold its share of their level's.
    state.values.naowhScoreCompare = "both"
    local at10 = Score.Best(10)
    local both = Score.Tooltip(at10 * 0.44, 10)
    check("Both: the number against the best in the game, then in gold, saying so, the level's",
        both == Score.Colored(at10 * 0.44, 10, "max") .. "  |cffffd10044% of level 10|r")
    check("at a level whose best is the best in the game, just the one percent",
        not Score.Tooltip(Score.Best(), 60):find("of level", 1, true))
    -- The real hook, on your own tooltip at 20 with Both and the data loaded: the line is there.
    ns.QoLSettings.Set("naowhScoreScan", false)
    ns.QoLSettings.Set("naowhScore", true)
    ns.Apply()
    state.RunTimers()
    state.level, state.hovered = 20, "player"
    state.gear.player = Set(20, 3)
    for k in pairs(state.lines) do state.lines[k] = nil end
    state.postCalls[#state.postCalls](state.tooltip)
    local right = state.rights[#state.lines] and state.rights[#state.lines].text
    check("your own tooltip at 20, Both: the score and its share of level 20", right
        and right:find("of level 20", 1, true) ~= nil)
    state.level = nil
    state.values.naowhScoreCompare = "max"
end

-------------------------------------------------------------------------------
--  A full list: the oldest goes to make room
-------------------------------------------------------------------------------
do
    local ns, state = Fixture()
    local Score = ns.NaowhScore
    for i = 1, 300 do
        state.now = state.now + 1
        Score.Remember("Player-2-" .. i, i, true, false, 60)
    end
    state.now = state.now + 1
    local ok = pcall(Score.Remember, "Player-2-301", 301, true, false, 60)
    check("a 301st player is kept without an error", ok and Score.Known("Player-2-301") ~= nil)
    check("the oldest went to make room", Score.Known("Player-2-1") == nil and Score.Known("Player-2-2") ~= nil)
end

-------------------------------------------------------------------------------
--  Your own inspect goes first: a request of ours is dropped for it and never clears it, and
--  none is made while your window loads or the talents opened from it still show
-------------------------------------------------------------------------------
do
    local ns, state, env = Fixture()
    local S = ns.QoLSettings
    S.Set("naowhScoreScan", false)
    local hookTable = env.hooksecurefunc
    env.hooksecurefunc = function(t, key, fn)
        if type(t) ~= "string" then return hookTable(t, key, fn) end
        local original = env[t]
        env[t] = function(...) original(...); key(...) end
    end
    local window = { shown = false }
    function window.IsShown(self) return self.shown end
    env.InspectFrame = window
    env.InspectUnit = function(unit) window.unit = unit end
    S.Set("naowhScore", true)
    state.RunTimers()
    local OnUnit = state.postCalls[1]
    local function Hover(unit)
        state.hovered = unit
        for k in pairs(state.lines) do state.lines[k] = nil end
        OnUnit(state.tooltip)
    end
    state.gear.party1, state.gear.party2, state.gear.party3 = Set(26, 4), Set(28, 4), Set(30, 4)
    Hover("party1")
    check("a hover asks for their gear", state.inspected[1] == "party1")
    env.InspectUnit("party2")
    state.Fire("INSPECT_READY", "Player-1-19")
    check("you inspect someone: ours is dropped, and its answer never clears yours",
        state.cleared == 0 and ns.NaowhScore.Known("Player-1-19") == nil)
    state.now = state.now + 3
    Hover("party3")
    check("none asked while your window loads", #state.inspected == 1)
    state.now = state.now + 10
    window.unit = nil
    local talents = { open = true }
    function talents.IsInspecting(self) return self.open end
    env.PlayerSpellsFrame = talents
    Hover("party3")
    check("nor while their talents, opened from your inspect, still show", #state.inspected == 1)
    talents.open = false
    Hover("party3")
    check("their talents closed: asked", state.inspected[2] == "party3")
    talents.open = true
    state.Fire("INSPECT_READY", "Player-1-39")
    check("and its answer, come while their talents show, never clears them", state.cleared == 0
        and ns.NaowhScore.Known("Player-1-39") ~= nil)
end

-- The gear comes while the tooltip is forbidden: it is left alone.
do
    local ns, state = Fixture()
    ns.QoLSettings.Set("naowhScoreScan", false)
    ns.QoLSettings.Set("naowhScore", true)
    state.RunTimers()
    state.gear.party1 = Set(26, 4)
    state.hovered = "party1"
    state.postCalls[1](state.tooltip)
    state.tooltip.IsForbidden = function() return true end
    state.tooltip.GetPrimaryTooltipData = function() error("a forbidden tooltip read") end
    local ok = pcall(state.Fire, "INSPECT_READY", "Player-1-19")
    check("the gear comes while the tooltip is forbidden: kept, the tooltip left alone", ok
        and ns.NaowhScore.Known("Player-1-19") ~= nil and state.rights[#state.lines].text == "...")
end

-------------------------------------------------------------------------------
--  What it keeps and costs: an inspected player's score, not their item links; a nameplate
--  shown makes no garbage
-------------------------------------------------------------------------------
do
    local ns, state = Fixture()
    ns.QoLSettings.Set("naowhScoreScan", false)
    ns.QoLSettings.Set("naowhScore", true)
    state.RunTimers()
    local OnUnit = state.postCalls[1]
    local PLAYERS = 50
    local function Inspected(unit)
        state.now = state.now + 3
        state.hovered = unit
        for k in pairs(state.lines) do state.lines[k] = nil end
        OnUnit(state.tooltip)
        state.Fire("INSPECT_READY", state.UnitGUID(unit))
        return ns.NaowhScore.Known(state.UnitGUID(unit)) ~= nil
    end
    local gear = Set(26, 4)
    local units = {}
    for i = 0, PLAYERS do
        units[i] = "nameplate" .. i
        state.gear[units[i]] = gear
    end
    Inspected(units[0])
    collectgarbage("collect")
    local before = collectgarbage("count")
    local all = true
    for i = 1, PLAYERS do all = Inspected(units[i]) and all end
    collectgarbage("collect")
    local kb = (collectgarbage("count") - before) / PLAYERS
    print(("  an inspected player kept: %.2f KB"):format(kb))
    check("each scored", all)
    check("an inspected player keeps their score, not their item links (under 1 KB each)", kb < 1)
end

do
    local ns, state = Fixture()
    state.values.naowhScoreScan, state.values.naowhScoreNearby = false, true
    ns.QoLSettings.Set("naowhScore", true)
    state.RunTimers()
    state.gear.nameplate1 = Set(20, 3)
    ns.NaowhScore.Remember("Player-1-19", 20, true, true, 60)
    Measure("a nameplate shown, the walk run with everyone known", 0.05, function()
        state.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
        state.RunTimers()
    end)
end

print(("test-naowh-score: %d checks passed"):format(checks))

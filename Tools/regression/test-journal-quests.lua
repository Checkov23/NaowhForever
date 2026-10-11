-- Run with Lua 5.1 from the repository root: the Dungeon Journal's quests (DungeonJournal/
-- Quests.lua). Where each quest stands for you (in your log, ready, done, part done, what to
-- do first and how far along, the level it needs, too high for now), which are listed and in
-- what order, its chain and each step's state, where its waypoint goes, and that the list
-- reuses its entries. Then checks the generated quest and chain data holds together.
local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

local DEFIAS = { 65, 132, 135, 141, 142, 155 }
local function Set(t)
    local out = {}
    for _, id in ipairs(t or {}) do out[id] = true end
    return out
end

-- The quest log's colouring (DifficultyUtil.GetRelativeDifficultyColor) for a player of this
-- level, with 8 levels of standard under it.
local COLORS = { trivial = {}, standard = {}, difficult = {}, verydifficult = {}, impossible = {} }
local function DifficultyColor(level, player)
    local diff = level - player
    if diff >= 5 then return COLORS.impossible end
    if diff >= 3 then return COLORS.verydifficult end
    if diff >= -4 then return COLORS.difficult end
    if -diff <= 8 then return COLORS.standard end
    return COLORS.trivial
end

local function Data()
    return {
        QuestData = { { name = "The Deadmines", quests = {
            { 214, "Red Silk Bandanas", 17, "A", "pre",
              "Westfall, Sentinel Hill - Scout Riell Complete 6 quests, starting with The Defias "
              .. "Brotherhood (56.7, 47.4)", 1436, 56.7, 47.4 },
            { 500, "Split", 20, "B", "pre", "Somewhere", 1411, 10, 10 },
            { 600, "Plain", 20, "B", true, "Plain place", 1411, 20, 20 },
        } } },
        QuestPrereqs = { [214] = DEFIAS, [500] = { { 501, 502 }, 503 }, [700] = DEFIAS },
        -- 700's Series starts at the last prerequisite and goes on past it.
        QuestChains = { [700] = { 155, 700, 701 }, [5728] = { 5727, 5728, 5729, 5730 },
            [914] = { 1489, { 1490, 1491 }, 914 } },
        QuestMinLevel = { [214] = 14, [600] = 30 },
        QuestWhere = { [214] = "Westfall, Sentinel Hill - Scout Riell (56.7, 47.4)" },
        QuestChainNames = { [65] = "The Defias Brotherhood", [132] = "The Defias Brotherhood",
            [135] = "The Defias Brotherhood", [141] = "The Defias Brotherhood",
            [142] = "The Defias Brotherhood", [155] = "The Defias Brotherhood",
            [501] = "Alliance Start", [502] = "Horde Start", [503] = "Middle" },
        QuestChainStarts = { [141] = { 1436, 56.3, 47.5, "Gryan Stoutmantle" } },
        QuestTurnIns = {},
    }
end

-- on: quest IDs in the log; done: turned in; complete: logged IDs with objectives done;
-- level: yours; levels: the game's quest levels, where loaded. Returns the quests module, the
-- quests by ID and what the stubs saw.
local function Fixture(opts)
    opts = opts or {}
    local on, done, complete = Set(opts.on), Set(opts.done), Set(opts.complete)
    local level, levels = opts.level or 20, opts.levels or {}
    local seen = { placed = {}, printed = {}, requested = {} }
    local J = Data()
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        Journal = J,
        Print = function(text) seen.printed[#seen.printed + 1] = text end,
        PlaceWaypoint = function(title, map, x, y, note)
            seen.placed[#seen.placed + 1] = { title = title, map = map, x = x, y = y, note = note }
            return true
        end,
        CanPlaceWaypoint = function() return true end,   -- every map takes one, as PlaceWaypoint says
    }
    local env = setmetatable({
        _G = { NaowhForever = ns },
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        C_QuestLog = {
            IsOnQuest = function(id) return on[id] == true end,
            IsComplete = function(id) return complete[id] == true end,
            IsQuestFlaggedCompleted = function(id) return done[id] == true end,
            GetTitleForQuestID = function() return nil end,
            GetQuestDifficultyLevel = function(id) return levels[id] or 0 end,
            RequestLoadQuestByID = function(id) seen.requested[#seen.requested + 1] = id end,
            GetNextWaypoint = function(id) if on[id] and not opts.noRoute then return 1437, 0.25, 0.75 end end,
            IsUnitOnQuest = function(unit, id)
                local member = opts.party and opts.party[tonumber(unit:match("%d+$"))]
                return member ~= nil and member[id] == true
            end,
        },
        UnitLevel = function() return level end,
        InCombatLockdown = function() return opts.combat == true end,
        C_Map = { OpenWorldMap = function(map) seen.mapOpened = map end },
        -- opts.party: one set of quest IDs per group member, party1 first.
        GetNumSubgroupMembers = function() return opts.party and #opts.party or 0 end,
        UnitClass = function() return "Mage", opts.class or "MAGE" end,
        UnitFactionGroup = function() return opts.faction or "Alliance" end,
        QuestDifficultyColors = COLORS,
        GetQuestDifficultyColor = function(questLevel) return DifficultyColor(questLevel, level) end,
    }, { __index = _G })
    for _, path in ipairs({ "NaowhForever_DungeonJournal/Constants.lua", "NaowhForever_DungeonJournal/Quests.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    local byID = {}
    for _, quest in ipairs(J.QuestData[1].quests) do byID[quest[1]] = quest end
    return J.Quests, byID, seen, J
end

-- The game's levels for the test quests, so none is grey to a level-30 player.
local AT_30 = { [214] = 30, [500] = 30, [600] = 30 }

-- The list entry for a quest, or nil when it is not listed.
local function EntryFor(Q, J, id)
    for _, entry in ipairs(Q.List(J.QuestData[1], {}, {})) do
        if entry.quest[1] == id then return entry end
    end
end

-------------------------------------------------------------------------------
--  In your log, done or part done
-------------------------------------------------------------------------------
local plain = { 100, "Plain", 20, "B", true, "" }
local chain = { 200, "Chain", 20, "B", true, "", steps = { 201, { 202, 203 } } }
local alt = { 300, "Alt", 20, "B", true, "", alt = { 301 } }
local lead = { 400, "Lead", 20, "B", true, "", lead = { 401 } }

Case("a quest in the log with objectives left is In log", function()
    local Q = Fixture({ on = { 100 } })
    assert(Q.Kind(plain) == "active" and Q.InLog("active"))
end)

Case("a quest in the log with its objectives done is ready to hand in", function()
    local Q = Fixture({ on = { 100 }, complete = { 100 } })
    assert(Q.Kind(plain) == "ready" and Q.InLog("ready"))
end)

Case("ready follows the logged step, alt or lead-in, not the first ID", function()
    local Q = Fixture({ on = { 203, 301, 401 }, complete = { 203, 401 }, done = { 200, 201 } })
    assert(Q.Kind(chain) == "ready")
    assert(Q.Kind(alt) == "active")
    assert(Q.Kind(lead) == "ready")
    assert(Q.LoggedID(chain) == 203 and Q.LoggedID(alt) == 301 and Q.LoggedID(lead) == 401)
end)

Case("objectives done on a quest that is not in the log do not count", function()
    local Q = Fixture({ complete = { 100 } })
    assert(Q.Kind(plain) == "pickup")
end)

Case("handed in, part done, an alt handed in, and a lead-in not carried", function()
    local Q = Fixture({ done = { 100, 200, 301 } })
    assert(Q.Kind(plain) == "done")
    assert(Q.Kind(chain) == "next")
    assert(Q.Kind(alt) == "done")
    assert(Q.Kind(lead) == "pickup")
    assert(not Q.InLog("done") and not Q.InLog("next") and not Q.InLog("pickup"))
end)

Case("the quest itself in the log or done ignores its prerequisites", function()
    local Q, q = Fixture({ on = { 214 } })
    assert(Q.Kind(q[214]) == "active")
    Q, q = Fixture({ done = { 214 } })
    assert(Q.Kind(q[214]) == "done")
end)

-------------------------------------------------------------------------------
--  What to do first, and the level it needs
-------------------------------------------------------------------------------
Case("nothing done: Requires names the first step, 1 of 6", function()
    local Q, q, _, J = Fixture()
    assert(Q.Kind(q[214]) == "prereq" and Q.ToPickUp("prereq"))
    assert(EntryFor(Q, J, 214).where == "Requires: The Defias Brotherhood (1/6)")
end)

Case("some steps done: Requires names the next step, with where it starts", function()
    local Q, q, _, J = Fixture({ done = { 65, 132, 135 } })
    assert(Q.Kind(q[214]) == "prereq")
    local where = EntryFor(Q, J, 214).where
    assert(where == "Requires: The Defias Brotherhood (4/6) (Gryan Stoutmantle)", where)
end)

Case("a later step done counts the ones before it as done", function()
    local Q, _, _, J = Fixture({ done = { 142 } })
    local where = EntryFor(Q, J, 214).where
    assert(where == "Requires: The Defias Brotherhood (6/6)", where)
end)

Case("the step to do in your log is the in-log Requires", function()
    local Q, q, _, J = Fixture({ on = { 141 }, done = { 65, 132, 135 } })
    assert(Q.Kind(q[214]) == "prereqLog")
    local entry = EntryFor(Q, J, 214)
    assert(entry.where == "Requires (in your log): The Defias Brotherhood (4/6) (Gryan Stoutmantle)", entry.where)
    assert(entry.canWaypoint)
end)

Case("a step with faction versions: either one done or in the log counts", function()
    local Q, q, _, J = Fixture({ done = { 502 } })
    assert(Q.Kind(q[500]) == "prereq")
    assert(EntryFor(Q, J, 500).where == "Requires: Middle (2/2)")
    Q, q, _, J = Fixture({ on = { 502 } })
    assert(Q.Kind(q[500]) == "prereqLog")
    assert(EntryFor(Q, J, 500).where == "Requires (in your log): Horde Start (1/2)")
end)

Case("all done but your level too low: waiting on your level", function()
    local Q, q = Fixture({ done = DEFIAS, level = 12 })
    assert(Q.Kind(q[214]) == "low" and Q.MinLevel(q[214]) == 14 and Q.ToPickUp("low"))
    Q, q = Fixture({ level = 29 })
    assert(Q.Kind(q[600]) == "low")
end)

Case("all done and your level high enough: to pick up, at the quest giver", function()
    local Q, q, _, J = Fixture({ done = DEFIAS, level = 14 })
    assert(Q.Kind(q[214]) == "pickup")
    -- The where line drops the guide's prerequisite note once the list is known.
    assert(EntryFor(Q, J, 214).where == "Westfall, Sentinel Hill - Scout Riell (56.7, 47.4)")
    Q, q, _, J = Fixture({ level = 30, levels = AT_30 })
    assert(Q.Kind(q[600]) == "pickup")
    assert(EntryFor(Q, J, 600).where == "Plain place")
end)

Case("to pick up but five levels or more above you: too high", function()
    local Q, _, _, J = Fixture({ done = { 501, 503 }, level = 15 })
    local entry = EntryFor(Q, J, 500)
    assert(entry.kind == "pickup" and entry.tooHigh and entry.level == 20)
    Q, _, _, J = Fixture({ done = { 501, 503 }, level = 16 })
    assert(not EntryFor(Q, J, 500).tooHigh)
end)

-------------------------------------------------------------------------------
--  Which quests are listed, and in what order
-------------------------------------------------------------------------------
Case("grey follows the quest log's own color for the game's quest level", function()
    local Q, _, _, J = Fixture({ level = 30, done = DEFIAS, levels = { [214] = 21, [600] = 22, [500] = 40 } })
    assert(EntryFor(Q, J, 214) == nil, "a grey quest to pick up is not listed")
    assert(EntryFor(Q, J, 600) and EntryFor(Q, J, 500))
    Q, _, _, J = Fixture({ level = 30, on = { 214 }, levels = { [214] = 21 } })
    assert(EntryFor(Q, J, 214), "a grey quest in your log still is")
end)

Case("an unloaded quest is judged by the data's level, and loaded once", function()
    local Q, q, seen, J = Fixture({ level = 30, done = DEFIAS })
    assert(EntryFor(Q, J, 214) == nil, "17 in the data is grey at 30")
    assert(Q.Level(q[214]) == 17)
    local asked = 0
    for _, id in ipairs(seen.requested) do if id == 214 then asked = asked + 1 end end
    assert(asked == 1, asked)
end)

Case("only your faction's quests and your class's class quests", function()
    local Q, _, _, J = Fixture({ faction = "Horde", done = DEFIAS })
    assert(EntryFor(Q, J, 214) == nil and EntryFor(Q, J, 600))
    J.QuestData[1].quests[3].class = "WARRIOR"
    assert(EntryFor(Q, J, 600) == nil)
    J.QuestData[1].quests[3].class = "MAGE"
    assert(EntryFor(Q, J, 600))
end)

Case("handed in quests are not listed", function()
    local Q, _, _, J = Fixture({ done = { 600 }, level = 30 })
    assert(EntryFor(Q, J, 600) == nil)
end)

Case("the list goes prerequisites, level, pick up, in your log, ready", function()
    local Q, _, _, J = Fixture({ level = 29, levels = AT_30, on = { 801, 800 }, complete = { 801 } })
    local quests = J.QuestData[1].quests
    quests[#quests + 1] = { 801, "Ready", 25, "B", true, "", 1411, 1, 1 }
    quests[#quests + 1] = { 800, "Active", 25, "B", true, "", 1411, 1, 1 }
    quests[#quests + 1] = { 802, "Open", 25, "B", true, "", 1411, 1, 1 }
    local order = {}
    for i, entry in ipairs(Q.List(J.QuestData[1], {}, {})) do order[i] = entry.kind end
    assert(table.concat(order, ",") == "prereq,prereq,low,pickup,active,ready", table.concat(order, ","))
end)

Case("the list reuses the caller's entries, and two callers never share one", function()
    local Q, _, _, J = Fixture({ level = 30, levels = AT_30 })
    local data = J.QuestData[1]
    local out, pool = {}, {}
    Q.List(data, out, pool)
    local first = out[1]
    assert(Q.List(data, out, pool) == out and out[1] == first and #out == 3)
    local other = Q.List(data, {}, {})
    assert(other[1] ~= first and other[1].quest == first.quest)
end)

Case("the list counts who in your group is on each quest", function()
    local Q, _, _, J = Fixture({ level = 30, levels = AT_30, on = { 600 },
        party = { { [600] = true }, { [214] = true }, { [600] = true } } })
    local byID = {}
    for _, entry in ipairs(Q.List(J.QuestData[1], {}, {})) do byID[entry.quest[1]] = entry end
    assert(byID[600].party == 2 and byID[214].party == 1 and byID[500].party == 0)
    Q, _, _, J = Fixture({ level = 30, levels = AT_30 })
    assert(Q.List(J.QuestData[1], {}, {})[1].party == 0, "out of a group, none")
end)

Case("the count agrees with the list", function()
    local Q, _, _, J = Fixture({ level = 30, levels = AT_30, on = { 600 } })
    local toPickUp, inLog = Q.Count(J.QuestData[1])
    assert(toPickUp == 2 and inLog == 1, toPickUp .. " " .. inLog)
    assert(#Q.List(J.QuestData[1], {}, {}) == toPickUp + inLog)
end)

Case("the signature changes with a quest's state, and only then", function()
    local Q, _, _, J = Fixture({ level = 30 })
    local a = Q.Signature(J.QuestData[1])
    assert(Q.Signature(J.QuestData[1]) == a)
    local Q2, _, _, J2 = Fixture({ level = 30, on = { 600 } })
    assert(Q2.Signature(J2.QuestData[1]) ~= a)
end)

-------------------------------------------------------------------------------
--  Chains
-------------------------------------------------------------------------------
Case("the chain lists the prerequisites first, then the quest", function()
    local Q, q = Fixture()
    local steps, own = Q.Chain(q[214])
    assert(#steps == 7 and steps[1] == 65 and steps[6] == 155 and steps[7] == 214 and own == 7)
end)

Case("a Series overlapping the prerequisites lists each step once, in order", function()
    local Q = Fixture()
    local steps, own = Q.Chain({ 700 })
    assert(#steps == 8 and steps[6] == 155 and steps[7] == 700 and steps[8] == 701 and own == 7)
end)

Case("a quest in a Series knows its step", function()
    local Q = Fixture()
    local steps, own = Q.Chain({ 5728 })
    assert(#steps == 4 and own == 2)
    steps, own = Q.Chain({ 914 })
    assert(#steps == 3 and own == 3)
end)

Case("a quest with neither prerequisites nor a Series has no chain", function()
    local Q, q = Fixture()
    assert(Q.Chain(q[600]) == nil)
end)

Case("each step is done, in the log, or to do", function()
    local Q = Fixture({ on = { 5728 }, done = { 5727 } })
    assert(Q.StepState(5727) == "done")
    assert(Q.StepState(5728) == "active")
    local state, id = Q.StepState(5729)
    assert(state == "todo" and id == 5729)
end)

Case("a step with faction versions is named by the version you have", function()
    local step = { 1490, 1491 }
    local state, id = Fixture({ done = { 1491 } }).StepState(step)
    assert(state == "done" and id == 1491)
    state, id = Fixture({ on = { 1491 } }).StepState(step)
    assert(state == "active" and id == 1491)
    state, id = Fixture().StepState(step)
    assert(state == "todo" and id == 1490)
end)

Case("a step is named by the chain data, the quest data, or its ID", function()
    local Q = Fixture()
    assert(Q.StepName(503) == "Middle" and Q.StepName(600) == "Plain" and Q.StepName(9) == "9")
end)

-------------------------------------------------------------------------------
--  Waypoints
-------------------------------------------------------------------------------
Case("Requires goes to where that step starts", function()
    local Q, q, seen = Fixture({ done = { 65, 132, 135 } })
    Q.Waypoint(q[214])
    local p = seen.placed[1]
    assert(#seen.placed == 1 and p.map == 1436 and p.x == 56.3 and p.note == " (Gryan Stoutmantle)")
end)

Case("a waypoint opens the map to it, out of combat only", function()
    local Q, q, seen = Fixture({ done = { 65, 132, 135 } })
    Q.Waypoint(q[214])
    assert(seen.mapOpened == 1436)
    local Q2, q2, seen2 = Fixture({ done = { 65, 132, 135 }, combat = true })
    Q2.Waypoint(q2[214])
    assert(#seen2.placed == 1 and seen2.mapOpened == nil)
end)

Case("a step in your log goes where the game routes you", function()
    local Q, q, seen = Fixture({ on = { 141 }, done = { 65, 132, 135 } })
    Q.Waypoint(q[214])
    local p = seen.placed[1]
    assert(#seen.placed == 1 and p.map == 1437 and p.x == 25 and p.y == 75)
end)

Case("a step with nowhere known says so", function()
    local Q, q, seen = Fixture()
    Q.Waypoint(q[214])
    assert(#seen.placed == 0 and seen.printed[1]:find("is not known", 1, true))
end)

Case("a quest to pick up goes to its quest giver", function()
    local Q, q, seen = Fixture({ done = DEFIAS })
    Q.Waypoint(q[214])
    local p = seen.placed[1]
    assert(#seen.placed == 1 and p.map == 1436 and p.x == 56.7 and p.y == 47.4)
end)

Case("a quest in your log: the game's route, else the turn-in, else the quest giver", function()
    local Q, q, seen = Fixture({ on = { 214 } })
    Q.Waypoint(q[214])
    assert(seen.placed[1].map == 1437)
    local J
    Q, q, seen, J = Fixture({ on = { 214 }, noRoute = true })
    J.QuestTurnIns[214] = { 1436, 50, 50, "Gryan Stoutmantle" }
    Q.Waypoint(q[214])
    assert(seen.placed[1].x == 50 and seen.placed[1].note == " (turn in: Gryan Stoutmantle)")
    Q, q, seen = Fixture({ on = { 214 }, noRoute = true })
    Q.Waypoint(q[214])
    assert(seen.placed[1].x == 56.7 and seen.placed[1].note == " (quest giver)")
end)

-------------------------------------------------------------------------------
--  The generated data: each step a quest ID or a table of them, none twice, never the quest
--  itself, every step named, and no quest reachable from its own prerequisites.
-------------------------------------------------------------------------------
Case("the generated quest and chain data is well formed and free of loops", function()
    local J = {}
    local env = setmetatable({ _G = { NaowhForever = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Journal = J } } }, { __index = _G })
    for _, path in ipairs({ "NaowhForever_DungeonJournal/Data/Quests.lua", "NaowhForever_DungeonJournal/Data/QuestChains.lua",
        "NaowhForever_DungeonJournal/Data/BiSQuests.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    -- byID: the quests; logged: every ID one of them can be in your log as (its own, an alt,
    -- a step of its chain, a lead-in), which is what a turn-in is keyed by.
    local byID, logged = {}, {}
    local function Log(list)
        for _, step in ipairs(list or {}) do
            for _, id in ipairs(type(step) == "table" and step or { step }) do logged[id] = true end
        end
    end
    for _, dungeon in ipairs(J.QuestData) do
        assert(type(dungeon.name) == "string" and type(dungeon.quests) == "table")
        for _, quest in ipairs(dungeon.quests) do
            assert(type(quest[1]) == "number" and type(quest[2]) == "string", "bad quest")
            assert(quest[4] == "A" or quest[4] == "H" or quest[4] == "B", "bad side for " .. quest[1])
            assert(not quest[7] or (quest[8] > 0 and quest[8] < 100 and quest[9] > 0 and quest[9] < 100),
                "quest giver off the map for " .. quest[1])
            byID[quest[1]], logged[quest[1]] = quest, true
            Log(quest.alt); Log(quest.steps); Log(quest.lead)
        end
    end
    -- The BiS List's quests are quest records too, with their chains in the same data.
    for _, quest in ipairs(J.BiSQuestData.quests) do
        assert(type(quest[1]) == "number" and type(quest[2]) == "string", "bad BiS quest")
        assert(quest[4] == "A" or quest[4] == "H" or quest[4] == "B", "bad side for " .. quest[1])
        assert(not quest[7] or (quest[8] > 0 and quest[8] < 100 and quest[9] > 0 and quest[9] < 100),
            "quest giver off the map for " .. quest[1])
        byID[quest[1]] = byID[quest[1]] or quest
        logged[quest[1]] = true
    end
    local function IDs(step)
        if type(step) == "number" then return { step } end
        assert(type(step) == "table" and #step > 0, "a step is an ID or a table of IDs")
        for _, id in ipairs(step) do assert(type(id) == "number" and id > 0, "bad ID") end
        return step
    end
    local lists = 0
    for questID, list in pairs(J.QuestPrereqs) do
        assert(byID[questID], "prerequisites for " .. questID .. ", which is not a quest in the data")
        assert(type(list) == "table" and #list > 0, "empty list for " .. questID)
        local seen = {}
        for _, step in ipairs(list) do
            for _, id in ipairs(IDs(step)) do
                assert(id ~= questID, questID .. " is among its own prerequisites")
                assert(not seen[id], questID .. " lists " .. id .. " twice")
                seen[id] = true
                assert(J.QuestChainNames[id] or byID[id], "no name for quest " .. id)
            end
        end
        lists = lists + 1
    end
    -- Depth-first over quest -> each ID of its prerequisites; a quest met again while its
    -- own walk is open is a loop.
    local state = {}
    local function Walk(id)
        if state[id] == "open" then error("prerequisite loop through quest " .. id) end
        if state[id] == "done" then return end
        state[id] = "open"
        for _, step in ipairs(J.QuestPrereqs[id] or {}) do
            for _, other in ipairs(IDs(step)) do Walk(other) end
        end
        state[id] = "done"
    end
    for questID in pairs(J.QuestPrereqs) do Walk(questID) end
    for questID, level in pairs(J.QuestMinLevel) do
        assert(byID[questID], "a level for " .. questID .. ", which is not a dungeon quest")
        assert(type(level) == "number" and level >= 1 and level <= 60 and level % 1 == 0)
    end
    for questID, where in pairs(J.QuestWhere) do
        assert(J.QuestPrereqs[questID] and type(where) == "string" and where ~= "")
    end
    for _, series in pairs(J.QuestChains) do
        for _, step in ipairs(series) do
            for _, id in ipairs(IDs(step)) do
                assert(J.QuestChainNames[id] or byID[id], "no name for quest " .. id)
            end
        end
    end
    for id, start in pairs(J.QuestChainStarts) do
        assert(type(start[1]) == "number" and start[2] > 0 and start[2] < 100 and start[3] > 0
            and start[3] < 100 and type(start[4]) == "string", "bad start for " .. id)
    end
    for id, turnIn in pairs(J.QuestTurnIns) do
        assert(logged[id], "a turn-in for " .. id .. ", which is no quest here")
        assert(type(turnIn[1]) == "number" and turnIn[2] > 0 and turnIn[2] < 100 and turnIn[3] > 0
            and turnIn[3] < 100 and type(turnIn[4]) == "string", "bad turn-in for " .. id)
    end
    -- The example the feature started from.
    local bandanas = J.QuestPrereqs[214]
    assert(bandanas and bandanas[1] == 65 and #bandanas == 6, "Red Silk Bandanas starts with 65, 6 steps")
    assert(J.QuestMinLevel[214] == 14)
    assert(lists > 50, "only " .. lists .. " lists")
end)

Case("every quest in a generated chain is in its own chain", function()
    local J = {}
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Journal = J }
    local env = setmetatable({ _G = { NaowhForever = ns }, C_QuestLog = {} }, { __index = _G })
    for _, path in ipairs({ "NaowhForever_DungeonJournal/Data/Quests.lua", "NaowhForever_DungeonJournal/Data/QuestChains.lua",
                            "NaowhForever_DungeonJournal/Constants.lua", "NaowhForever_DungeonJournal/Quests.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    local chained = 0
    for _, dungeon in ipairs(J.QuestData) do
        for _, quest in ipairs(dungeon.quests) do
            if J.QuestChains[quest[1]] then
                assert(J.Quests.Chain(quest), "quest " .. quest[1] .. " is not in its own chain")
                chained = chained + 1
            end
        end
    end
    assert(chained > 0)
end)

print(("test-journal-quests: %d cases passed"):format(count))

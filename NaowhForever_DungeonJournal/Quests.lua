-- Quests.lua: the Dungeon Journal's quest rules: where each quest stands, its chain and its waypoint (J.Quests).
local ns = _G.NaowhForever

local IsOnQuest = C_QuestLog.IsOnQuest
local IsComplete = C_QuestLog.IsComplete
local IsDone = C_QuestLog.IsQuestFlaggedCompleted
local GetTitle = C_QuestLog.GetTitleForQuestID

local J = ns.Journal
local QUEST = J.C.QUEST
local PERCENT = J.C.PERCENT
local ID, NAME, LEVEL, SIDE, WHERE = QUEST.ID, QUEST.NAME, QUEST.LEVEL, QUEST.SIDE, QUEST.WHERE
local MAP, X, Y = QUEST.MAP, QUEST.X, QUEST.Y

local RANK = { prereq = 1, prereqLog = 2, low = 3, pickup = 4, next = 5, active = 6, ready = 7, done = 8 }
local TOO_HIGH = 5
local SIGNATURE_BASE = 9
local SIGNATURE_MOD = 2147483647
local BOTH = "B"
local SIDE_OF = { A = "Alliance", H = "Horde" }
local PARTY = { "party1", "party2", "party3", "party4" }

local TEXT_QUEST_GIVER = ns.L(" (quest giver)")
local TEXT_SPOT = " (%s)"
local TEXT_ENTRANCE = ns.L(" (dungeon entrance)")
local TEXT_TURN_IN = ns.L(" (turn in: %s)")
local TEXT_REQUIRES = ns.L("Requires%s: %s (%d/%d)")
local TEXT_IN_LOG = ns.L(" (in your log)")
local TEXT_NO_START = ns.L("Where %s starts is not known.")
local TEXT_NO_ROUTE = ns.L("The game has no route for %s, and its quest giver's spot is not known.")
local TEXT_TRACKING = ns.L("Tracking %s. Press L to see it in your quest log.")
local TEXT_ALL_DONE = ns.L("Every quest here for you is handed in.")
local TEXT_NOT_YET = ns.L("None to pick up right now: the rest are not for your level yet.")
local TEXT_NONE_HERE = ns.L("None for you here. The rest: %s.")
local TEXT_COUNT = "%d %s"
local TEXT_JOIN = ", "

local requested = {}
local paths = {}
local byID, dungeonOf
local noneParts, noneClasses, noneOrder = {}, {}, {}

local function StepAny(step, check)
    if type(step) ~= "table" then return check(step) and step or nil end
    for i = 1, #step do
        if check(step[i]) then return step[i] end
    end
end

local function StepDone(step)
    return StepAny(step, IsDone) ~= nil
end

local function OnList(list)
    if not list then return end
    for i = 1, #list do
        local id = StepAny(list[i], IsOnQuest)
        if id then return id end
    end
end

local function NextPrereq(quest)
    local list = J.QuestPrereqs[quest[ID]]
    if not list then return end
    local n = #list
    for i = n, 1, -1 do
        if StepDone(list[i]) then
            if i == n then return end
            return list[i + 1], i + 1, n
        end
    end
    return list[1], 1, n
end

local function FirstDone(quest)
    local done = IsDone(quest[ID])
    local alt = quest.alt
    if not alt then return done end
    for i = 1, #alt do done = done or IsDone(alt[i]) end
    return done
end

local function ChainDone(quest)
    local first = FirstDone(quest)
    local all, any = first, first
    local steps = quest.steps
    if not steps then return all, any end
    for i = 1, #steps do
        local done = StepDone(steps[i])
        all, any = all and done, any or done
    end
    return all, any
end

local function ForSide(side, faction)
    local own = SIDE_OF[side]
    return side == BOTH or (own ~= nil and own == faction)
end

local function ForMe(quest, class, faction)
    if quest.class and quest.class ~= class then return false end
    return ForSide(quest[SIDE], faction)
end

local function Covers(step, id)
    if type(step) ~= "table" then return step == id end
    for i = 1, #step do
        if step[i] == id then return true end
    end
    return false
end

local function AddStep(steps, seen, step)
    local ids = type(step) == "table" and step or { step }
    for i = 1, #ids do
        if seen[ids[i]] then return end
    end
    for i = 1, #ids do seen[ids[i]] = true end
    steps[#steps + 1] = step
end

local function BuildPath(id)
    local prereqs, series = J.QuestPrereqs[id], J.QuestChains[id]
    if not (prereqs or series) then return false end
    local steps, seen = {}, {}
    for i = 1, prereqs and #prereqs or 0 do AddStep(steps, seen, prereqs[i]) end
    for i = 1, series and #series or 0 do AddStep(steps, seen, series[i]) end
    AddStep(steps, seen, id)
    for i = 1, #steps do
        if Covers(steps[i], id) then return { steps = steps, own = i } end
    end
    return false
end

local function QuestByID(id)
    if not byID then
        byID = {}
        for _, dungeon in ipairs(J.QuestData) do
            for _, quest in ipairs(dungeon.quests) do byID[quest[ID]] = quest end
        end
    end
    return byID[id]
end

local function SpotOf(id)
    local quest = QuestByID(id)
    if quest and quest[MAP] then return quest[MAP], quest[X], quest[Y], TEXT_QUEST_GIVER end
    local start = J.QuestChainStarts[id]
    if start then return start[1], start[2], start[3], TEXT_SPOT:format(start[4]) end
end

local function StepSpot(step, id)
    local map, x, y, note = SpotOf(id)
    if map then return map, x, y, note end
    if type(step) ~= "table" then return SpotOf(step) end
    for i = 1, #step do
        map, x, y, note = SpotOf(step[i])
        if map then return map, x, y, note end
    end
end

local function NextSpot(quest)
    local steps, spots = quest.steps, quest.next
    if not (steps and spots) then return end
    for i = 1, #steps do
        if not StepDone(steps[i]) then return spots[i] or nil end
    end
end

local function Where(quest)
    return J.QuestWhere[quest[ID]] or quest[WHERE]
end

local function IndexDungeons()
    dungeonOf = {}
    for _, dungeon in ipairs(J.Dungeons()) do
        local data = dungeon.quests
        for _, q in ipairs(data and data.quests or {}) do dungeonOf[q] = dungeon end
    end
end

local function EntranceOf(quest)
    if not dungeonOf then
        if not J.Dungeons then return nil end
        IndexDungeons()
    end
    local dungeon = dungeonOf[quest]
    return dungeon and dungeon.entrance
end

local function Navigation(id)
    local map, x, y = C_QuestLog.GetNextWaypoint(id)
    if map and x and y and ns.CanPlaceWaypoint(map) then return map, x * PERCENT, y * PERCENT end
end

local function StepTarget(step, state, id)
    if state == "active" then
        local map, x, y = Navigation(id)
        if map then return map, x, y end
    end
    return StepSpot(step, id)
end

local function Route(quest, id)
    local map, x, y = Navigation(id)
    if map then return map, x, y end
    local turnIn = J.QuestTurnIns[id]
    if turnIn and ns.CanPlaceWaypoint(turnIn[1]) then
        return turnIn[1], turnIn[2], turnIn[3], TEXT_TURN_IN:format(turnIn[4])
    end
    if quest[MAP] and ns.CanPlaceWaypoint(quest[MAP]) then return quest[MAP], quest[X], quest[Y], TEXT_QUEST_GIVER end
end

local function ByRank(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.index < b.index
end

local function CountOthers(quests, faction)
    wipe(noneClasses)
    wipe(noneOrder)
    local other = 0
    for i = 1, #quests do
        local quest = quests[i]
        local class = quest.class
        if class then
            if not noneClasses[class] then noneOrder[#noneOrder + 1] = class end
            noneClasses[class] = (noneClasses[class] or 0) + 1
        elseif not ForSide(quest[SIDE], faction) then
            other = other + 1
        end
    end
    return other
end

local Q = {}
J.Quests = Q
Q.ByID = QuestByID

function Q.LoggedID(quest)
    if IsOnQuest(quest[ID]) then return quest[ID] end
    return OnList(quest.alt) or OnList(quest.steps) or OnList(quest.lead)
end
local LoggedID = Q.LoggedID

function Q.MinLevel(quest)
    return J.QuestMinLevel[quest[ID]]
end

function Q.Kind(quest)
    local id = LoggedID(quest)
    if id then return IsComplete(id) and "ready" or "active" end
    local all, any = ChainDone(quest)
    if all then return "done" end
    if any then return "next" end
    local step = NextPrereq(quest)
    if step then return StepAny(step, IsOnQuest) and "prereqLog" or "prereq" end
    local need = Q.MinLevel(quest)
    if need and UnitLevel("player") < need then return "low" end
    return "pickup"
end
local Kind = Q.Kind

function Q.InLog(kind)
    return kind == "active" or kind == "ready"
end
local InLog = Q.InLog

function Q.ToPickUp(kind)
    return kind == "pickup" or kind == "prereq" or kind == "prereqLog" or kind == "low"
end
local ToPickUp = Q.ToPickUp

function Q.Level(quest)
    local id = quest[ID]
    local level = C_QuestLog.GetQuestDifficultyLevel(id)
    if level and level > 0 then return level end
    if not requested[id] then
        requested[id] = true
        C_QuestLog.RequestLoadQuestByID(id)
    end
    return quest[LEVEL]
end
local Level = Q.Level

function Q.Name(quest)
    return GetTitle(quest[ID]) or quest[NAME]
end

local function Grey(quest)
    local level = Level(quest)
    return level ~= nil and GetQuestDifficultyColor(level) == QuestDifficultyColors.trivial
end

local function Listed(quest, kind, class, faction)
    return ForMe(quest, class, faction) and kind ~= "done"
        and not (ToPickUp(kind) and Grey(quest) and not quest.turnin)
end

function Q.ForMe(quest)
    local _, class = UnitClass("player")
    return ForMe(quest, class, UnitFactionGroup("player"))
end

function Q.Chain(quest)
    local id = quest[ID]
    local path = paths[id]
    if path == nil then
        path = BuildPath(id)
        paths[id] = path
    end
    if path then return path.steps, path.own end
end
local Chain = Q.Chain

function Q.StepState(step)
    local id = StepAny(step, IsOnQuest)
    if id then return "active", id end
    id = StepAny(step, IsDone)
    if id then return "done", id end
    return "todo", type(step) == "table" and step[1] or step
end
local StepState = Q.StepState

function Q.StepName(id)
    local quest = QuestByID(id)
    return GetTitle(id) or J.QuestChainNames[id] or (quest and quest[NAME]) or tostring(id)
end
local StepName = Q.StepName

function Q.StepHasSpot(step, id)
    return StepSpot(step, id) ~= nil
end

local function PrereqLine(quest)
    local step, i, n = NextPrereq(quest)
    if not step then return end
    local state, id = StepState(step)
    local text = TEXT_REQUIRES:format(state == "active" and TEXT_IN_LOG or "", StepName(id), i, n)
    return text, step, state, id
end

local function Destination(quest, kind)
    if kind == "next" then
        local spot = NextSpot(quest)
        if spot then return spot[4], spot[1], spot[2], spot[3] end
    elseif kind == "prereq" or kind == "prereqLog" then
        local text, step, _, id = PrereqLine(quest)
        local map, x, y, note = StepSpot(step, id)
        return map and text .. note or text, map, x, y
    end
    if quest[MAP] then return Where(quest), quest[MAP], quest[X], quest[Y] end
    local entrance = EntranceOf(quest)
    if entrance then return Where(quest), entrance.map, entrance.x, entrance.y, TEXT_ENTRANCE end
    return Where(quest)
end

function Q.StepWaypoint(step, state, id, name)
    local map, x, y, note = StepTarget(step, state, id)
    if not map then
        ns.Print(TEXT_NO_START:format(name))
        return
    end
    ns.PlaceWaypoint(name, map, x, y, note)
end

local function LoggedSpot(quest, logged)
    local name = GetTitle(logged) or quest[NAME]
    local map, x, y, note = Route(quest, logged)
    return name, map, x, y, note, not map and TEXT_NO_ROUTE:format(name) or nil
end

local function PrereqSpot(quest)
    local _, step, state, id = PrereqLine(quest)
    local name = StepName(id)
    local map, x, y, note = StepTarget(step, state, id)
    return name, map, x, y, note, not map and TEXT_NO_START:format(name) or nil
end

function Q.Spot(quest)
    local logged = LoggedID(quest)
    if logged then return LoggedSpot(quest, logged) end
    local kind = Kind(quest)
    if kind == "prereq" or kind == "prereqLog" then return PrereqSpot(quest) end
    local _, map, x, y, note = Destination(quest, kind)
    return Q.Name(quest), map, x, y, note
end

function Q.Waypoint(quest)
    local name, map, x, y, note, why = Q.Spot(quest)
    if map then
        if ns.PlaceWaypoint(name, map, x, y, note) and not InCombatLockdown() then C_Map.OpenWorldMap(map) end
    elseif why then
        ns.Print(why)
    end
end

function Q.Track(id)
    C_QuestLog.AddQuestWatch(id)
    C_QuestLog.SetSelectedQuest(id)
    C_SuperTrack.SetSuperTrackedQuestID(id)
    ns.Print(TEXT_TRACKING:format(GetTitle(id) or id))
end

function Q.UnitOnQuest(unit, quest, loggedID)
    return C_QuestLog.IsUnitOnQuest(unit, quest[ID])
        or (loggedID ~= nil and C_QuestLog.IsUnitOnQuest(unit, loggedID))
end
local UnitOnQuest = Q.UnitOnQuest

function Q.PartyCount(quest, loggedID)
    local count = 0
    for i = 1, math.min(GetNumSubgroupMembers(), #PARTY) do
        if UnitOnQuest(PARTY[i], quest, loggedID) then count = count + 1 end
    end
    return count
end
local PartyCount = Q.PartyCount

function Q.Progress(data)
    local _, class = UnitClass("player")
    local faction = UnitFactionGroup("player")
    local done, total = 0, 0
    local quests = data and data.quests
    for i = 1, quests and #quests or 0 do
        local quest = quests[i]
        if ForMe(quest, class, faction) then
            total = total + 1
            if Kind(quest) == "done" then done = done + 1 end
        end
    end
    return done, total
end

function Q.NoneWhy(data)
    local quests = data and data.quests
    if not quests or #quests == 0 then return nil end
    local done, total = Q.Progress(data)
    if total > 0 then return done == total and TEXT_ALL_DONE or TEXT_NOT_YET end
    local faction = UnitFactionGroup("player")
    local other = CountOthers(quests, faction)
    wipe(noneParts)
    if other > 0 then
        noneParts[1] = TEXT_COUNT:format(other, faction == "Horde" and (FACTION_ALLIANCE or "Alliance") or (FACTION_HORDE or "Horde"))
    end
    for _, class in ipairs(noneOrder) do
        noneParts[#noneParts + 1] = TEXT_COUNT:format(noneClasses[class], LOCALIZED_CLASS_NAMES_MALE[class] or class)
    end
    return TEXT_NONE_HERE:format(table.concat(noneParts, TEXT_JOIN))
end

local function FillEntry(entry, quest, kind, index, level)
    local where, map = Destination(quest, kind)
    local questLevel = Level(quest)
    entry.quest, entry.kind, entry.index, entry.rank = quest, kind, index, RANK[kind]
    entry.name, entry.level = Q.Name(quest), questLevel
    entry.tooHigh = kind == "pickup" and questLevel ~= nil and questLevel >= level + TOO_HIGH
    entry.where, entry.inLog = where, InLog(kind)
    entry.canWaypoint = map ~= nil or kind == "prereqLog" or entry.inLog
    entry.loggedID = LoggedID(quest)
    entry.party = PartyCount(quest, entry.loggedID)
    local chain, step = Chain(quest)
    entry.step, entry.steps = step, chain and #chain
end

function Q.List(data, out, pool)
    wipe(out)
    local _, class = UnitClass("player")
    local faction = UnitFactionGroup("player")
    local level = UnitLevel("player")
    for index, quest in ipairs(data.quests) do
        local kind = Kind(quest)
        if Listed(quest, kind, class, faction) then
            local n = #out + 1
            local entry = pool[n] or {}
            pool[n] = entry
            FillEntry(entry, quest, kind, index, level)
            out[n] = entry
        end
    end
    table.sort(out, ByRank)
    return out
end

function Q.Signature(data)
    local signature = 0
    for _, quest in ipairs(data.quests) do
        signature = (signature * SIGNATURE_BASE + RANK[Kind(quest)]) % SIGNATURE_MOD
    end
    return signature
end

function Q.Count(data)
    local _, class = UnitClass("player")
    local faction = UnitFactionGroup("player")
    local toPickUp, inLog = 0, 0
    for _, quest in ipairs(data.quests) do
        local kind = Kind(quest)
        if Listed(quest, kind, class, faction) then
            if InLog(kind) then
                inLog = inLog + 1
            elseif ToPickUp(kind) then
                toPickUp = toPickUp + 1
            end
        end
    end
    return toPickUp, inLog
end

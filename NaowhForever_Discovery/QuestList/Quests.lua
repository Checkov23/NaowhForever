-- Quests.lua: the quest rules: which quests are yours, what you have done, chains, quest givers (Completo.Quests).
local ns = _G.NaowhForever

local Completo = ns.Completo
local D = ns.CompletoQuestData
local SameMap = ns.Shared.Places.SameMap

local NAME, LEVEL, REQ_LEVEL, SIDE, RACES, CLASSES, MAP, X, Y, GIVER, ITEM = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
local ALLIANCE, HORDE = 1, 2
local RACE_BITS = { [1] = 0, [2] = 1, [3] = 2, [4] = 3, [5] = 4, [6] = 5, [7] = 6, [8] = 7, [95] = 32, [96] = 33 }
local UNIT_ID = 3
local MAX_UNDER = 10
local CLASSIC_GREEN_RANGE = 8
local NOT_OFFERED_STORE, TURN_INS_STORE = "completoNotOffered", "completoTurnIns"
local OPENED_STORE = "completoOpened"
local NONE = {}

local mine, zoneOf, chains, chainOf
local done = {}
local byMap
local zoneChains, zoneSingles, seenChain = {}, {}, {}
local found, foundIn = {}, {}
local named = {}
local givers, spare, giverAt = {}, {}, {}
local blocking = {}

local Q = {}
Completo.Quests = Q

local function HasBit(mask, bit)
    return math.floor(mask / 2 ^ bit) % 2 == 1
end

local function ForMe(quest, side, raceBit, classBit)
    if quest[SIDE] == ALLIANCE and side ~= ALLIANCE then return false end
    if quest[SIDE] == HORDE and side ~= HORDE then return false end
    if quest[RACES] > 0 and raceBit and not HasBit(quest[RACES], raceBit) then return false end
    if quest[CLASSES] > 0 and classBit and not HasBit(quest[CLASSES], classBit) then return false end
    return true
end

local function OwnSteps(steps)
    local own = {}
    for _, step in ipairs(steps) do
        local ids = {}
        for _, id in ipairs(step) do
            if mine[id] then ids[#ids + 1] = id end
        end
        ids.any = step.any
        if #ids > 0 then own[#own + 1] = ids end
    end
    return own
end

local function AddChain(own)
    local first = D.Quests[own[1][1]]
    local chain = { steps = own, name = first[NAME], level = first[LEVEL], id = #chains + 1 }
    chains[#chains + 1] = chain
    for _, ids in ipairs(own) do
        for _, id in ipairs(ids) do chainOf[id] = chain end
    end
end

local function Prepare()
    if mine then return end
    mine, zoneOf, chains, chainOf = {}, {}, {}, {}
    local side = UnitFactionGroup("player") == "Horde" and HORDE or ALLIANCE
    local raceBit = RACE_BITS[select(UNIT_ID, UnitRace("player"))]
    local classID = select(UNIT_ID, UnitClass("player"))
    local classBit = classID and classID - 1
    for id, quest in pairs(D.Quests) do
        if ForMe(quest, side, raceBit, classBit) then mine[id] = true end
    end
    for _, zone in ipairs(D.Zones) do
        for _, id in ipairs(zone.quests) do zoneOf[id] = zone end
    end
    for _, steps in ipairs(D.Chains) do
        local own = OwnSteps(steps)
        if #own > 1 then AddChain(own) end
    end
end

local function CharStore(key)
    local account = ns.AccountSettings()
    account[key] = account[key] or {}
    local char = Completo.CharKey()
    account[key][char] = account[key][char] or {}
    return account[key][char]
end

local function ZoneTurnIns(id)
    local zone = zoneOf and zoneOf[id]
    return zone and CharStore(TURN_INS_STORE)[zone.map] or 0
end

local function QuestLevel(id)
    return D.Quests[id][LEVEL]
end

local function SortKey(entry)
    if type(entry) == "table" then return entry.level, entry.name end
    local quest = D.Quests[entry]
    return quest[LEVEL], quest[NAME]
end

local function ByLevel(a, b)
    local la, na = SortKey(a)
    local lb, nb = SortKey(b)
    if la ~= lb then return la < lb end
    return na < nb
end

local function FoundKey(id)
    local chain = chainOf[id]
    if not chain then return QuestLevel(id), 0, 0 end
    return chain.level, chain.id, (Q.ChainStep(id))
end

local function FoundOrder(a, b)
    local la, ca, sa = FoundKey(a)
    local lb, cb, sb = FoundKey(b)
    if la ~= lb then return la < lb end
    if ca ~= cb then return ca < cb end
    if sa ~= sb then return sa < sb end
    return D.Quests[a][NAME] < D.Quests[b][NAME]
end

local function Matches(quest, text)
    if quest[NAME]:lower():find(text, 1, true) then return true end
    return quest[GIVER] ~= nil and quest[GIVER]:lower():find(text, 1, true) ~= nil
end

local function Index()
    if byMap then return end
    byMap = {}
    for id, quest in pairs(D.Quests) do
        local map = quest[MAP]
        if map and mine[id] then
            byMap[map] = byMap[map] or {}
            table.insert(byMap[map], id)
        end
    end
end

local function RecycleGivers()
    for i = #givers, 1, -1 do
        local entry = givers[i]
        wipe(entry.quests)
        spare[#spare + 1] = entry
        givers[i] = nil
    end
    wipe(giverAt)
end

local function GiverEntry(quest)
    local key = quest[X] .. ":" .. quest[Y]
    local entry = giverAt[key]
    if entry then return entry end
    entry = table.remove(spare) or { quests = {} }
    entry.x, entry.y, entry.grey, entry.repeatable = quest[X], quest[Y], true, true
    giverAt[key] = entry
    givers[#givers + 1] = entry
    return entry
end

local function AddToLists(id)
    local chain = chainOf[id]
    if not chain then
        zoneSingles[#zoneSingles + 1] = id
        return
    end
    if seenChain[chain] then return end
    seenChain[chain] = true
    zoneChains[#zoneChains + 1] = chain
end

local function Wanted(id, chainsOnly)
    return Q.Available(id) and (chainOf[id] ~= nil or not chainsOnly)
end

local function AddToGiver(id, trivial)
    local entry = GiverEntry(D.Quests[id])
    table.insert(entry.quests, id)
    if not trivial then entry.grey = false end
    if not Q.Repeatable(id) then entry.repeatable = false end
end

function Q.Refresh()
    Prepare()
    wipe(done)
    local all = C_QuestLog.GetAllCompletedQuestIDs and C_QuestLog.GetAllCompletedQuestIDs()
    if all then
        for i = 1, #all do done[all[i]] = true end
        return
    end
    for id in pairs(mine) do
        if C_QuestLog.IsQuestFlaggedCompleted(id) then done[id] = true end
    end
end

function Q.Done(id) return done[id] == true end

function Q.InLog(id)
    return C_QuestLog.GetLogIndexForQuestID(id) ~= nil
end

function Q.Mine(id) return mine[id] == true end
function Q.Name(id) return D.Quests[id][NAME] end
function Q.Level(id) return QuestLevel(id) end

function Q.RequiredLevel(id)
    local quest = D.Quests[id]
    return math.max(quest[REQ_LEVEL], quest[LEVEL] - MAX_UNDER)
end

function Q.Zone(id) return zoneOf[id] end
function Q.Chain(id) return chainOf[id] end
function Q.Zones() return D.Zones end
function Q.Giver(id) return D.Quests[id][GIVER] end
function Q.Item(id) return D.Quests[id][ITEM] end
function Q.Repeatable(id) return D.Repeatable ~= nil and D.Repeatable[id] == true end

function Q.Spot(id)
    local quest = D.Quests[id]
    if quest[MAP] then return quest[MAP], quest[X], quest[Y] end
end

function Q.StepDone(step)
    for _, id in ipairs(step) do
        if done[id] and step.any then return true end
        if not done[id] and not step.any then return false end
    end
    return not step.any
end

function Q.ChainAt(chain)
    local steps = chain.steps
    for i = #steps, 1, -1 do
        if Q.StepDone(steps[i]) then return i + 1, #steps end
    end
    return 1, #steps
end

function Q.NotOffered(id)
    local store = CharStore(NOT_OFFERED_STORE)
    local entry = store[id]
    if not entry then return false end
    if entry[1] == UnitLevel("player") and entry[2] == ZoneTurnIns(id) then return true end
    store[id] = nil
    return false
end

function Q.SetOffered(id, offered)
    CharStore(NOT_OFFERED_STORE)[id] = not offered and { UnitLevel("player"), ZoneTurnIns(id) } or nil
end

function Q.CountTurnIn(id)
    Prepare()
    local zone = zoneOf[id]
    if not zone then return end
    local turnIns = CharStore(TURN_INS_STORE)
    turnIns[zone.map] = (turnIns[zone.map] or 0) + 1
end

function Q.State(id)
    local state = Q.Expected(id)
    if state == "open" and Q.NotOffered(id) then return "held" end
    return state
end

local function Counts(id)
    return mine[id] or not D.Quests[id]
end

local function Met(element)
    if type(element) == "number" then
        return done[element] or not Counts(element)
    end
    local counted = false
    for _, id in ipairs(element) do
        if done[id] then return true end
        if Counts(id) then counted = true end
    end
    return not counted
end

function Q.Opened(id)
    for _, element in ipairs(D.Requires[id] or NONE) do
        if not Met(element) then return CharStore(OPENED_STORE)[id] == true end
    end
    return true
end

function Q.SetOpened(id)
    CharStore(OPENED_STORE)[id] = true
end

function Q.Blocking(id)
    wipe(blocking)
    for _, element in ipairs(D.Requires[id] or NONE) do
        if not Met(element) then
            local first = element
            if type(element) == "table" then
                for _, other in ipairs(element) do
                    if Counts(other) then
                        first = other
                        break
                    end
                end
            end
            blocking[#blocking + 1] = first
        end
    end
    return blocking
end

function Q.Title(id)
    local quest = D.Quests[id]
    return quest and quest[NAME] or C_QuestLog.GetTitleForQuestID(id)
end

function Q.Expected(id)
    if done[id] then return "done" end
    if Q.InLog(id) then return "log" end
    if not Q.Opened(id) then return "later" end
    if UnitLevel("player") < Q.RequiredLevel(id) then return "low" end
    return "open"
end

function Q.ZoneProgress(zone)
    local n, total, low, high = 0, 0, nil, nil
    for _, id in ipairs(zone.quests) do
        if mine[id] and not Q.Repeatable(id) then
            total = total + 1
            if done[id] then n = n + 1 end
            local level = QuestLevel(id)
            if level > 0 then
                low = math.min(low or level, level)
                high = math.max(high or level, level)
            end
        end
    end
    return n, total, low, high
end

function Q.Progress()
    local n, total = 0, 0
    for _, zone in ipairs(D.Zones) do
        local zn, zt = Q.ZoneProgress(zone)
        n, total = n + zn, total + zt
    end
    return n, total
end

function Q.ZoneLists(zone)
    wipe(zoneChains)
    wipe(zoneSingles)
    wipe(seenChain)
    for _, id in ipairs(zone.quests) do
        if mine[id] then AddToLists(id) end
    end
    table.sort(zoneChains, ByLevel)
    table.sort(zoneSingles, ByLevel)
    return zoneChains, zoneSingles
end

function Q.ChainStep(id)
    local chain = chainOf[id]
    if not chain then return end
    for i, step in ipairs(chain.steps) do
        for _, other in ipairs(step) do
            if other == id then return i, #chain.steps end
        end
    end
end

function Q.Search(text, limit)
    Prepare()
    wipe(found)
    local n = 0
    for _, zone in ipairs(D.Zones) do
        local entry = foundIn[zone] or { zone = zone, ids = {} }
        foundIn[zone] = entry
        local ids = wipe(entry.ids)
        for _, id in ipairs(zone.quests) do
            if mine[id] and Matches(D.Quests[id], text) then
                n = n + 1
                if n <= limit then ids[#ids + 1] = id end
            end
        end
        if #ids > 0 then
            table.sort(ids, FoundOrder)
            found[#found + 1] = entry
        end
    end
    return found, n
end

function Q.CurrentZone()
    local map = SameMap(C_Map.GetBestMapForUnit("player"))
    while map do
        for _, zone in ipairs(D.Zones) do
            if zone.map == map then return zone end
        end
        local info = C_Map.GetMapInfo(map)
        map = info and info.parentMapID ~= 0 and info.parentMapID or nil
    end
end

function Q.Waypoint(id)
    local map, x, y = Q.Spot(id)
    if map then ns.PlaceWaypoint(Q.Name(id), map, x, y) end
end

function Q.Trivial(id)
    local level = QuestLevel(id)
    if level <= 0 then return false end
    if QuestDifficultyColors and QuestDifficultyColors.trivial then
        return GetQuestDifficultyColor(level) == QuestDifficultyColors.trivial
    end
    local green = GetQuestGreenRange and GetQuestGreenRange() or CLASSIC_GREEN_RANGE
    return level < UnitLevel("player") - green
end

function Q.Available(id)
    return mine[id] == true and Q.State(id) == "open"
end

function Q.GiverQuests(name, mapID)
    if issecretvalue(name) then return NONE end
    Prepare()
    Index()
    wipe(named)
    for _, id in ipairs(byMap[mapID] or NONE) do
        if D.Quests[id][GIVER] == name then named[#named + 1] = id end
    end
    return named
end

function Q.Givers(mapID, grey, chainsOnly)
    Prepare()
    Index()
    RecycleGivers()
    for _, id in ipairs(byMap[SameMap(mapID)] or NONE) do
        if Wanted(id, chainsOnly) then
            local trivial = Q.Trivial(id)
            if grey or not trivial then AddToGiver(id, trivial) end
        end
    end
    return givers
end

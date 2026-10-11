-- Builds.lua: talent builds: Naowh's and the ones saved or imported, editing them, sharing them, following one.
local ns = _G.NaowhForever

local Training = ns.Training
local C = Training.C
local Account = Training.Account
local CharKey = Training.CharKey
local Changed = Training.Changed

local BUILD_PREFIX = "!NFB1!"
local MAX_POINTS = C.MAX_POINTS
local ROW_POINTS = 5
local NODE_SPELL, NODE_RANKS, NODE_ROW, NODE_COLUMN, NODE_NEEDS = C.NODE_SPELL, C.NODE_RANKS, C.NODE_ROW, C.NODE_COLUMN, 6
local DECODE_LIMITS = { maxChars = 100000, maxBytes = 1048576, maxDepth = 8, maxValues = 20000 }
local BUILD_VERSION = 1
local NAOWH_KEY = "naowh"
local TEXT_NOT_IN_TREE = ns.L("That talent is not in this class's tree.")
local TEXT_ALL_SPENT = ns.L("All %d points are spent.")
local TEXT_FULL_RANK = ns.L("Already at full rank.")
local TEXT_NEEDS_FULL = ns.L("Needs %s at full rank first.")
local TEXT_TALENT_ABOVE = ns.L("the talent above it")
local TEXT_NEEDS_POINTS = ns.L("Needs %d points in %s first.")
local TEXT_NO_POINTS_YET = ns.L("No points yet")
local TEXT_NOT_A_BUILD = ns.L("That is not a Naowh Forever talent build.")
local TEXT_ADD = ns.L("Add the %s build %s (%d points)?")
local TEXT_IMPORTED = ns.L("Imported %s.")
local TEXT_IMPORTED_BUILD, TEXT_IMPORTED_SPEC = ns.L("Imported Build"), ns.L("Imported")
local TEXT_NO_TALENTS = ns.L("You have no talent points spent to save.")
local TEXT_MY_TALENTS, TEXT_YOUR_TALENTS = ns.L("My Talents"), ns.L("Your talents")
local TEXT_NEW_BUILD = ns.L("New Build")
local TEXT_LATER_NEEDS = ns.L("A later point needs it. ")
local TEXT_NOTHING_TO_GIVE = ns.L("No points in it to give back.")
local TEXT_LEARNED = ns.L("Learned %d talent %s from %s.")
local TEXT_POINT, TEXT_POINTS = ns.L("point"), ns.L("points")

local learning = false

local function Saved(classID)
    local all = Account("trainingBuilds")
    all[classID] = all[classID] or {}
    return all[classID]
end

function Training.Builds(classID)
    local list = {}
    for _, build in ipairs(ns.TrainingBuilds[classID] or {}) do list[#list + 1] = build end
    for _, build in ipairs(Saved(classID)) do list[#list + 1] = build end
    return list
end

function Training.Ranks(talents)
    local config = C_ClassTalents.GetActiveConfigID()
    if not config then return nil end
    local ranks = {}
    for node in pairs(talents) do ranks[node] = C_Traits.GetNodeInfo(config, node).activeRank end
    return ranks
end

function Training.CheckBuild(tree, points)
    local count, spent = {}, {}
    for i, node in ipairs(points) do
        local talent = tree.talents[node]
        if not talent then return TEXT_NOT_IN_TREE end
        if i > MAX_POINTS then return TEXT_ALL_SPENT:format(MAX_POINTS) end
        local rank = (count[node] or 0) + 1
        if rank > talent[NODE_RANKS] then return TEXT_FULL_RANK end
        local need = talent[NODE_NEEDS]
        if need and (count[need] or 0) < tree.talents[need][NODE_RANKS] then
            return TEXT_NEEDS_FULL:format(C_Spell.GetSpellName(tree.talents[need][NODE_SPELL]) or TEXT_TALENT_ABOVE)
        end
        local col, row = talent[NODE_COLUMN], talent[NODE_ROW]
        if (spent[col] or 0) < ROW_POINTS * (row - 1) then
            return TEXT_NEEDS_POINTS:format(ROW_POINTS * (row - 1), tree.specs[col])
        end
        count[node], spent[col] = rank, (spent[col] or 0) + 1
    end
end

local function MainSpec(tree, points)
    local spent, best = {}, nil
    for _, node in ipairs(points) do
        local col = tree.talents[node][NODE_COLUMN]
        spent[col] = (spent[col] or 0) + 1
        if not best or spent[col] > spent[best] then best = col end
    end
    return best and tree.specs[best] or TEXT_NO_POINTS_YET
end

local function Codec()
    return LibStub("LibSerialize"), LibStub("LibDeflate")
end

local function BuildName(text, default)
    local name = type(text) == "string" and text:gsub("[|\r\n]", ""):sub(1, C.BUILD_NAME_MAX) or ""
    return name ~= "" and name or default
end
Training.BuildName = BuildName

function Training.ExportBuild(classID, build)
    local LS, LD = Codec()
    return BUILD_PREFIX .. LD:EncodeForPrint(LD:CompressDeflate(LS:Serialize({
        v = BUILD_VERSION, class = classID, name = build.name, spec = build.spec, points = build.points,
    })))
end

local function DecodeBuild(text)
    local body = type(text) == "string" and text:match("^%s*" .. BUILD_PREFIX:gsub("!", "%%!") .. "(%S+)%s*$")
    local data = body and ns.Shared.Decode.String(body, DECODE_LIMITS)
    if not (type(data) == "table" and data.v == BUILD_VERSION and type(data.points) == "table") then return end
    local tree = ns.TrainingBuilds[data.class]
    if not tree then return end
    local points = {}
    for i, node in ipairs(data.points) do
        if i > MAX_POINTS then return end
        points[i] = node
    end
    if #points == 0 or Training.CheckBuild(tree, points) then return end
    return data.class, { name = BuildName(data.name, TEXT_IMPORTED_BUILD),
        spec = BuildName(data.spec, TEXT_IMPORTED_SPEC), points = points, saved = true }
end

function Training.ImportBuild(text, onAdded)
    local classID, build = DecodeBuild(text)
    if not classID then
        ns.Print(TEXT_NOT_A_BUILD)
        return
    end
    ns.Confirm(TEXT_ADD:format(GetClassInfo(classID), build.name, #build.points), function()
        local saved = Saved(classID)
        saved[#saved + 1] = build
        Changed()
        ns.Print(TEXT_IMPORTED:format(build.name))
        onAdded(classID, #(ns.TrainingBuilds[classID]) + #saved)
    end)
end

local function RowOrder(tree)
    return function(a, b)
        local rowA, rowB = tree.talents[a][NODE_ROW], tree.talents[b][NODE_ROW]
        if rowA ~= rowB then return rowA < rowB end
        return a < b
    end
end

function Training.SaveMyTalents(name)
    local _, _, classID = UnitClass("player")
    local tree = ns.TrainingBuilds[classID]
    local ranks = tree and Training.Ranks(tree.talents)
    if not ranks then return end
    local nodes = {}
    for node in pairs(tree.talents) do nodes[#nodes + 1] = node end
    table.sort(nodes, RowOrder(tree))
    local points = {}
    for _, node in ipairs(nodes) do
        for _ = 1, math.min(ranks[node], tree.talents[node][NODE_RANKS]) do points[#points + 1] = node end
    end
    if #points == 0 then
        ns.Print(TEXT_NO_TALENTS)
        return
    end
    local saved = Saved(classID)
    saved[#saved + 1] = { name = BuildName(name, TEXT_MY_TALENTS), spec = TEXT_YOUR_TALENTS, points = points,
        saved = true }
    Changed()
    return classID, #tree + #saved
end

function Training.NewBuild(classID, name, from)
    local points = {}
    for i, node in ipairs(from and from.points or {}) do points[i] = node end
    local saved = Saved(classID)
    saved[#saved + 1] = { name = BuildName(name, TEXT_NEW_BUILD), spec = from and from.spec or TEXT_NO_POINTS_YET,
        points = points, saved = true }
    Changed()
    return #(ns.TrainingBuilds[classID]) + #saved
end

function Training.RenameBuild(build, name)
    if not build or not build.saved then return end
    build.name = BuildName(name, build.name)
    Changed()
end

function Training.AddPoint(tree, build, node)
    local points = build.points
    points[#points + 1] = node
    local why = Training.CheckBuild(tree, points)
    if why then
        points[#points] = nil
        return why
    end
    build.spec = MainSpec(tree, points)
    Changed()
end

function Training.RemovePoint(tree, build, node)
    local points = build.points
    for i = #points, 1, -1 do
        if points[i] == node then
            table.remove(points, i)
            local why = Training.CheckBuild(tree, points)
            if why then
                table.insert(points, i, node)
                return TEXT_LATER_NEEDS .. why
            end
            build.spec = MainSpec(tree, points)
            Changed()
            return
        end
    end
    return TEXT_NOTHING_TO_GIVE
end

function Training.UndoPoint(tree, build)
    build.points[#build.points] = nil
    build.spec = MainSpec(tree, build.points)
    Changed()
end

function Training.ClearPoints(build)
    wipe(build.points)
    build.spec = TEXT_NO_POINTS_YET
    Changed()
end

function Training.LearnBuild(classID, build)
    local _, _, myClass = UnitClass("player")
    local tree = ns.TrainingBuilds[classID]
    local config = C_ClassTalents.GetActiveConfigID()
    if learning or classID ~= myClass or InCombatLockdown() or not (tree and config) then return 0 end
    local ranks, count, bought = Training.Ranks(tree.talents), {}, 0
    learning = true
    for _, node in ipairs(build.points) do
        count[node] = (count[node] or 0) + 1
        if ranks[node] < count[node] then
            if not C_Traits.PurchaseRank(config, node) then break end
            bought = bought + 1
        end
    end
    if bought > 0 then C_Traits.CommitConfig(config) end
    learning = false
    return bought
end

local function BuildKey(classID, build)
    if build.saved then
        if not build.id then
            local serial = Account("trainingBuildSerial")
            serial.n = (serial.n or 0) + 1
            build.id = serial.n
        end
        return build.id
    end
    for i, b in ipairs(ns.TrainingBuilds[classID] or {}) do
        if b == build then return NAOWH_KEY .. i end
    end
end

function Training.Followed()
    local followed = Account("trainingFollow")[CharKey()]
    if not followed then return nil end
    for _, build in ipairs(Training.Builds(followed.class)) do
        if BuildKey(followed.class, build) == followed.key then return build, followed.class end
    end
end

function Training.Follow(classID, build)
    Account("trainingFollow")[CharKey()] = build and { class = classID, key = BuildKey(classID, build) } or nil
    Training.Apply()
    Changed()
end

function Training.LearnedText(bought, name)
    return TEXT_LEARNED:format(bought, bought == 1 and TEXT_POINT or TEXT_POINTS, name)
end

function Training.LearnFollowed()
    local build, classID = Training.Followed()
    if not build then return end
    local bought = Training.LearnBuild(classID, build)
    if bought > 0 then ns.Print(Training.LearnedText(bought, build.name)) end
end

function Training.DeleteBuild(classID, build)
    local key = BuildKey(classID, build)
    local follows = Account("trainingFollow")
    for char, followed in pairs(follows) do
        if followed.class == classID and followed.key == key then follows[char] = nil end
    end
    local saved = Saved(classID)
    for i, b in ipairs(saved) do
        if b == build then
            table.remove(saved, i)
            break
        end
    end
    Changed()
end

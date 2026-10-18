-- Target.lua: what the game's soft interact target is, how far it is, and what gathering it gives you (G.Target).
local ns = _G.NaowhForever

local UnitGUID, UnitIsGameObject = UnitGUID, UnitIsGameObject
local IsRelated = C_QuestLog.UnitIsRelatedToActiveQuest
local GetTooltipUnit = C_TooltipInfo.GetUnit
local InReach = UnitIsInInteractRange

local G = ns.Glimmer
local S = G.Settings
local C = G.C
local Plain = G.Plain

local CURSOR_PATH = "Interface\\Cursor\\"
local CURSOR_FILES = {
    Mine = "ore", GatherHerbs = "herb", QuestTurnIn = "quest", Quest = "quest", QuestRepeatable = "quest",
}
local UNABLE = "Unable"
local QUEST_LINE = Enum.TooltipDataLineType.QuestObjective
local TEXT_REQUIRES = ns.L("Requires %s %d")
local TEXT_TIER = {
    orange = ns.L("Skill-up every gather"),
    yellow = ns.L("Skill-up likely"),
    green = ns.L("Skill-up unlikely"),
    grey = ns.L("No skill-up"),
}
local TEXT_PROFESSION = { ore = ns.L("Mining"), herb = ns.L("Herbalism") }

local Target = {}
G.Target = Target

local cursorIDs
local probe

local function CursorIDs()
    cursorIDs = {}
    for file, category in pairs(CURSOR_FILES) do
        local id = GetFileIDFromPath(CURSOR_PATH .. file)
        if id then cursorIDs[id] = { category, false } end
        id = GetFileIDFromPath(CURSOR_PATH .. UNABLE .. file)
        if id then cursorIDs[id] = { category, true } end
    end
end

local function FromName(name)
    if type(name) ~= "string" or not Plain(name) then return end
    name = name:lower()
    local unable = name:find(C.CURSOR_UNABLE, 1, true) ~= nil
    for word, category in pairs(C.CURSOR_WORDS) do
        if name:find(word, 1, true) then return category, unable end
    end
    return nil, unable
end

local function Cursor(unit, lowPriority)
    if not cursorIDs then CursorIDs() end
    probe = probe or CreateFrame("Frame"):CreateTexture()
    if not SetUnitCursorTexture(probe, unit, nil, lowPriority) then return end
    local texture = probe:GetTexture()
    if not Plain(texture) then return end
    local known = cursorIDs[texture]
    if known then return known[1], known[2] end
    return FromName(texture)
end

local function ObjectID(unit)
    local guid = UnitGUID(unit)
    if not (guid and Plain(guid)) then return end
    return tonumber(guid:match(C.GUID_OBJECT))
end

local function QuestLine(unit)
    local data = GetTooltipUnit(unit)
    if not (data and Plain(data) and data.lines) then return end
    for _, line in ipairs(data.lines) do
        if line.type == QUEST_LINE and Plain(line.leftText) then return line.leftText end
    end
end

function Target.Skill(category)
    local line = C.PROFESSION_OF[category]
    for _, index in pairs({ GetProfessions() }) do
        local _, _, rank, _, _, _, skillLine = GetProfessionInfo(index)
        if skillLine == line then return rank end
    end
    return 0
end

function Target.Tier(skill, need)
    if skill < need then return "red" end
    local over = skill - need
    if over < C.SKILL_ORANGE then return "orange" end
    if over < C.SKILL_YELLOW then return "yellow" end
    if over < C.SKILL_GREEN then return "green" end
    return "grey"
end

function Target.TierText(category, need, tier)
    if tier == "red" then return TEXT_REQUIRES:format(TEXT_PROFESSION[category], need) end
    return TEXT_TIER[tier]
end

function Target.Reach(unit)
    if not InReach then return true end
    local near = InReach(unit)
    if not Plain(near) then return false end
    return near and true or false
end

local function QuestGiver(unit, info)
    local category, unable = Cursor(unit, true)
    if category ~= "quest" then return end
    wipe(info)
    info.category, info.unable = "giver", unable or false
    info.locked = info.unable
    info.ready = Target.Reach(unit)
    return info
end

function Target.Read(unit, info)
    local object = UnitIsGameObject(unit)
    if not Plain(object) then return end
    if not object then return QuestGiver(unit, info) end
    wipe(info)
    local id = ObjectID(unit)
    local node = id and G.NODES[id]
    local cursorCategory, unable = Cursor(unit)
    local category = node and node[1] or (id == C.BOBBER and "bobber") or cursorCategory
    info.id, info.unable = id, unable or false
    if category == "ore" or category == "herb" then
        info.skill = Target.Skill(category)
        info.need = node and node[2]
        if info.need then info.tier = Target.Tier(info.skill, info.need) end
        info.locked = info.tier == "red" or info.skill <= 0 or info.unable
    else
        local line = QuestLine(unit)
        local related = IsRelated and IsRelated(unit)
        if line or (Plain(related) and related) then
            category = "quest"
            info.line = line
        end
        info.locked = info.unable
    end
    if not category then return end
    info.category = category
    info.ready = Target.Reach(unit)
    return info
end

function Target.Wanted(category)
    return category ~= nil and S.Get(category) and true or false
end

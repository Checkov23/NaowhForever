-- DungeonPage.lua: a dungeon's page: its header, your quests, each wing's boss cards, its trash and the folded bosses.
local ns = _G.NaowhForever

local J = ns.Journal
local S = J.Settings
local Quests = J.Quests
local View = J.View
local ViewMixin = View.Mixin
local St = J.Style
local SECTION_SPACE = St.SECTION_SPACE

local BOSS_LOOT_GAP = 4
local TRASH_TOP, TRASH_GAP = 6, 16
local EMPTY_BODY = 28
local SKIPPED_TITLE = { missingBisOnly = ns.L("Nothing you're missing"), upgradesOnly = ns.L("Nothing that beats your gear"),
    usableOnly = ns.L("Nothing for your class") }

local TEXT_QUESTS = ns.L("Dungeon Quests")
local TEXT_TRACKER = ns.L("Tracker")
local TEXT_NO_QUESTS = ns.L("No quests here.")
local TEXT_REPUTATION = ns.L("Reputation")
local TEXT_NO_BOSSES = ns.L("No boss data for this dungeon yet. It fills in with a later version of the addon.")
local TEXT_BOSSES = ns.L("Bosses")
local TEXT_MAP = "Map"
local TEXT_COMING_SOON = "Coming soon"
local TEXT_NO_MAP = ns.L("No map of this dungeon yet.")
local TEXT_TRASH = "Trash"

local EMPTY = {}
local chipLabels = {}

local function OpenQuests()
    S.Set("questsOpen", not S.Get("questsOpen"))
end

local function OpenTracker(dungeon)
    ns.OpenQuestTracker(dungeon)
end

local function OpenMap(dungeon, link)
    J.OpenDungeonMap(dungeon, link)
end

local function ChipLabel(boss, number, wing)
    local label = chipLabels[boss]
    if not label then
        label = (wing and wing .. " " or "") .. (number and number .. " " or "") .. boss.name
        chipLabels[boss] = label
    end
    return label
end

function ViewMixin:DrawBoss(boss, number, shown, query, x, w)
    local top = self.cursor
    local card = self:OpenCard(x, w)
    local loot, chance = boss.loot or EMPTY, boss.chance
    local hidden = not query and #loot - shown or 0
    local header = self:Add("boss", boss, number, shown, hidden)
    header.card = card
    if shown > 0 then self:Space(BOSS_LOOT_GAP) end
    local kept, faded = 0, 0
    for i = 1, #loot do
        local id = loot[i]
        if self:Listed(id, query) then
            local item = self:AddItem(id, chance and chance[i], boss)
            if item.keep then kept = kept + 1 else faded = faded + 1 end
        end
    end
    header.canPin = kept > 0 and faded > 0
    header:EnableMouse(true)
    card.note:SetText(View.Parts.BossEmptyText(shown, boss))
    card.note:SetShown(shown == 0)
    if shown == 0 then self:Space(EMPTY_BODY) end
    return self:CloseCard(card, top)
end

function ViewMixin:DrawTrash(boss, shown, query, x, w)
    local top = self.cursor
    local card = self:OpenCard(x, w)
    local loot, chance = boss.loot or EMPTY, boss.chance
    local left, width = self.left, self.width
    local columnW = math.floor((width - TRASH_GAP) / 2)
    self:Space(TRASH_TOP)
    local start, bottom, n, half = self.cursor, self.cursor, 0, math.ceil(shown / 2)
    self.width = columnW
    for i = 1, #loot do
        local id = loot[i]
        if self:Listed(id, query) then
            n = n + 1
            if n == half + 1 then
                bottom, self.cursor, self.left = self.cursor, start, left + columnW + TRASH_GAP
            end
            self:AddItem(id, chance and chance[i], boss)
        end
    end
    self.cursor = math.max(self.cursor, bottom)
    self.left, self.width = left, width
    return self:CloseCard(card, top)
end

function ViewMixin:DrawQuests(list)
    local open = S.Get("questsOpen")
    self:Add("section", TEXT_QUESTS, #list, open, OpenQuests, TEXT_TRACKER, OpenTracker, self.dungeon)
    if open then
        for i = 1, #list do self:Add("quest", list[i], i) end
    end
    self:Space(SECTION_SPACE)
end

function ViewMixin:QuestList(dungeon)
    if not dungeon.quests then return EMPTY end
    local list = Quests.List(dungeon.quests, self.questList, self.questPool)
    self.questSignature = Quests.Signature(dungeon.quests)
    self.questsDrawn = true
    return list
end

function ViewMixin:DrawTracker(dungeon)
    self:Begin(dungeon, nil)
    self.tight = true
    local list = self:QuestList(dungeon)
    if #list == 0 then self:Note(Quests.NoneWhy(dungeon.quests) or TEXT_NO_QUESTS) end
    for i = 1, #list do self:Add("quest", list[i], i) end
    self:Finish()
end

function ViewMixin:DrawDungeonQuests(dungeon, list)
    if #list > 0 then return self:DrawQuests(list) end
    if not dungeon.quests then return end
    local why = Quests.NoneWhy(dungeon.quests)
    if not why then return end
    self:Section(TEXT_QUESTS, 0)
    self:Note(why)
    self:Space(SECTION_SPACE)
end

function ViewMixin:GatherWing(wing)
    local skipped, skippedBoss, trash = self.skipped, self.skippedBoss, self.trash
    local number, cards = 0, 0
    for _, boss in ipairs(wing.bosses) do
        local ordered = J.Numbered(boss)
        if ordered then number = number + 1 end
        local kill = ordered and number or nil
        local shown = self:ShownCount(boss)
        if shown == 0 and boss.loot then
            skipped[#skipped + 1] = ChipLabel(boss, kill, wing.name)
            skippedBoss[#skippedBoss + 1] = boss
        elseif boss.trash then
            trash[#trash + 1] = boss
            self.trashShown = self.trashShown + shown
        else
            self:Gather(boss, kill, shown)
            if not (boss.trash or boss.chest) then cards = cards + 1 end
        end
    end
    return cards
end

function ViewMixin:WingTitle(dungeon, title, first, count)
    if first and (not self.onWorldMap or J.DungeonMapAway()) then
        if J.Maps[dungeon.key] then
            self:Add("section", title, count, nil, nil, TEXT_MAP, OpenMap, dungeon)
        else
            self:Add("section", title, count, nil, nil, TEXT_MAP, nil, nil, TEXT_COMING_SOON, TEXT_NO_MAP)
        end
    else
        self:Section(title, count)
    end
    self:Space(SECTION_SPACE)
end

function ViewMixin:DrawWings(dungeon)
    for i, wing in ipairs(dungeon.wings) do
        local cards = self:GatherWing(wing)
        local title = wing.name or (i == 1 and TEXT_BOSSES)
        if title then self:WingTitle(dungeon, title, i == 1, cards > 0 and cards or nil) end
        self:DrawGrid()
    end
end

function ViewMixin:DrawTrashCards()
    local trash = self.trash
    if #trash == 0 then return end
    self:Section(TEXT_TRASH, self.trashShown)
    self:Space(SECTION_SPACE)
    for k = 1, #trash do self:Gather(trash[k], nil, self:ShownCount(trash[k])) end
    self.trashColumns = #trash == 1
    self:DrawGrid(#trash == 1 and 1 or nil)
    self.trashColumns = false
end

function ViewMixin:DrawSkipped()
    local skipped = self.skipped
    if #skipped == 0 then return end
    self:Space(BOSS_LOOT_GAP)
    local filters = self.filters
    local key = filters.missingBis and "missingBisOnly" or filters.upgradesOnly and "upgradesOnly" or "usableOnly"
    self:Add("skipped", SKIPPED_TITLE[key], key, self.skippedBoss, skipped)
    self:Space(BOSS_LOOT_GAP)
end

function ViewMixin:Draw(dungeon)
    self:Begin(dungeon, nil)
    local list = self:QuestList(dungeon)
    self:Add("header", dungeon)
    if dungeon.note then self:Note(dungeon.note) end
    if dungeon.closed then self:Note(J.CLOSED_NOTE) end
    if self.navigate and dungeon.factions then
        self:Add("links", TEXT_REPUTATION, dungeon.factions)
        self:Space(SECTION_SPACE)
        self.factionLinks = true
    end
    self:DrawDungeonQuests(dungeon, list)
    if not J.HasBosses(dungeon) then self:Note(TEXT_NO_BOSSES) end
    wipe(self.skipped)
    wipe(self.skippedBoss)
    wipe(self.trash)
    self.trashShown = 0
    self:DrawWings(dungeon)
    self:DrawTrashCards()
    self:DrawBisNote()
    self:DrawSkipped()
    self:Finish()
end

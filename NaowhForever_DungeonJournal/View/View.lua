-- View.lua: one Dungeon Journal page on the shared row engine: per-draw answers, events and redraws (J.View).
local ns = _G.NaowhForever

local Refuse, Refused = ns.Shared.Items.Refuse, ns.Shared.Items.Refused

local J = ns.Journal
local Shared = ns.Shared
local Loot = J.Loot
local Quests = J.Quests
local Rep = J.Reputation
local KnownLowerName = Loot.KnownLowerName
local St = J.Style
local COMPACT_W, FADED, BORDER_RGB = St.COMPACT_W, St.FADED, St.BORDER_RGB

local STATE_EVENTS = {
    "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "TRANSMOG_COLLECTION_SOURCE_ADDED",
    "ENCOUNTER_END",
}
local QUEST_EVENTS = { QUEST_LOG_UPDATE = true, QUEST_DATA_LOAD_RESULT = true }
local GROUP_EVENTS = { GROUP_ROSTER_UPDATE = true, UNIT_QUEST_LOG_CHANGED = true }
local RANK_EVENTS = { "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "CURRENCY_DISPLAY_UPDATE" }

local TEXT_YOUR_BIS = ns.L("Your BiS")
local TEXT_TURN_ON_BIS = ns.L("Turn on the BiS List to see your BiS marked here.")
local TEXT_TURN_ON_BUTTON = ns.L("Turn On BiS List")
local TEXT_BIS_EMPTY = ns.L("Your BiS list is empty")
local TEXT_OPEN_BIS = ns.L("Open BiS List")
local BIS_ADDON = "NaowhForever_BiS"

local EMPTY = {}

local View = { Kinds = Shared.View.NewKinds(), Parts = setmetatable({}, { __index = Shared.Parts }) }
J.View = View
View.Columns = Shared.View.Columns

local ViewMixin = {}
View.Mixin = ViewMixin

local function OpenBisList()
    ns.OpenBisWindow()
end

local function RegisterAll(view, events)
    for event in pairs(events) do view:RegisterEvent(event) end
end

function ViewMixin:ItemShown(itemID)
    local shown = self.shownCache[itemID]
    if shown == nil then
        shown = Loot.Shown(itemID, self.filters)
        self.shownCache[itemID] = shown
    end
    return shown
end

function ViewMixin:ItemRank(itemID)
    local rank = self.rankCache[itemID]
    if rank == nil then
        rank = Loot.Rank(itemID) or false
        self.rankCache[itemID] = rank
    end
    return rank or nil
end

function ViewMixin:ItemUpgrade(itemID)
    local upgrade = self.upgradeCache[itemID]
    if upgrade == nil then
        upgrade = Loot.Upgrade(itemID)
        self.upgradeCache[itemID] = upgrade
    end
    return upgrade
end

function ViewMixin:Listed(itemID, query)
    if query then
        local known = KnownLowerName(itemID)
        if known and not known:find(query, 1, true) then return false end
    end
    if not self:ItemShown(itemID) then return false end
    if not query then return true end
    local name = Loot.LowerName(itemID)
    if name then return name:find(query, 1, true) ~= nil end
    if Refused(itemID) then return false end
    self.waitingFor[itemID] = true
    self.waiting = true
    return false
end

local function TooltipSaysKnown(itemID)
    local data = C_TooltipInfo.GetItemByID(itemID)
    local lines = data and data.lines or EMPTY
    local known = false
    for i = 1, #lines do
        local text = lines[i].leftText
        if text == ITEM_SPELL_KNOWN and not issecretvalue(text) then known = true end
    end
    return known
end

function ViewMixin:RecipeKnown(itemID)
    local known = self.knownCache[itemID]
    if known == nil then
        known = TooltipSaysKnown(itemID)
        self.knownCache[itemID] = known
    end
    return known
end

function ViewMixin:ListCount(items, query)
    local shown = 0
    for i = 1, #items do
        if self:Listed(items[i], query) then shown = shown + 1 end
    end
    return shown
end

function ViewMixin:ShownCount(boss, query)
    return boss.loot and self:ListCount(boss.loot, query) or 0
end

function ViewMixin:AddItem(id, chance, boss)
    local item = self:Add("item", id, chance, self:ItemRank(id), self:ItemUpgrade(id))
    item.boss = boss
    return item
end

function ViewMixin:DrawCard(entry, number, shown, query, x, w)
    if entry.standing then return self:DrawTier(entry, shown, query, x, w) end
    if entry.rewards then return self:DrawRankCard(entry, x, w) end
    if entry.trash and self.trashColumns then return self:DrawTrash(entry, shown, query, x, w) end
    return self:DrawBoss(entry, number, shown, query, x, w)
end

function ViewMixin:DrawBisNote()
    if not self.filters.bisOn then
        self:NeedsModule(TEXT_YOUR_BIS, TEXT_TURN_ON_BIS, BIS_ADDON, TEXT_TURN_ON_BUTTON)
    elseif ns.BisListIsEmpty() then
        self:SectionLink(TEXT_BIS_EMPTY, TEXT_OPEN_BIS, OpenBisList)
    end
end

function ViewMixin:ApplyPin()
    local T = ns.THEME
    local pinned = self.pinned
    local items = self.pools.item
    for i = 1, items.used do
        local row = items[i]
        row:SetAlpha(pinned ~= nil and row.boss == pinned and not row.keep and FADED or row.rest)
    end
    local bosses = self.pools.boss
    for i = 1, bosses.used do
        local row = bosses[i]
        local isPinned = row.boss == pinned
        local color = isPinned and T.accent or row.hovered and T.accentSoft or T.fg
        row.name:SetTextColor(color.r, color.g, color.b)
        local edge = isPinned and T.accent or BORDER_RGB
        row.card.edge:SetColor(edge.r, edge.g, edge.b, 1)
    end
end

function ViewMixin:Pin(boss)
    self.pinned = self.pinned ~= boss and boss or nil
    self:ApplyPin()
end

function ViewMixin:Begin(dungeon, boss, query, page)
    if dungeon ~= self.dungeon or boss ~= self.boss or query ~= self.query or page ~= self.page then
        self.pinned = nil
    end
    if dungeon and dungeon ~= self.dungeon then J.FollowDungeonMap(self, dungeon) end
    self.dungeon, self.boss, self.query, self.page = dungeon, boss, query, page
    self:Clear()
    self.questsDrawn = false
    self.compact = self.width < COMPACT_W
    self.playerLevel = UnitLevel("player")
    Loot.ReadFilters(self.filters)
    self.showChance, self.showTips, self.showKills = true, true, true
    self.bare, self.striped, self.tight, self.column = false, false, false, nil
    self.dense, self.tightTitles = false, false
    self.factionLinks, self.watchMoney = false, false
    self.watchQuestLog = false
    wipe(self.shownCache)
    wipe(self.rankCache)
    wipe(self.upgradeCache)
    wipe(self.knownCache)
end

function ViewMixin:Finish()
    self:Fit(STATE_EVENTS)
    if self.questsDrawn then
        RegisterAll(self, QUEST_EVENTS)
        RegisterAll(self, GROUP_EVENTS)
    elseif self.watchQuestLog then
        RegisterAll(self, QUEST_EVENTS)
    end
    local page = self.page
    if page or self.watchFactions or self.factionLinks then self:RegisterEvent("UPDATE_FACTION") end
    if self.watchMoney then self:RegisterEvent("PLAYER_MONEY") end
    if page and page.rank then
        for i = 1, #RANK_EVENTS do self:RegisterEvent(RANK_EVENTS[i]) end
    end
    self:ApplyPin()
    if self.onResize then self.onResize(self.cursor) end
end

function ViewMixin:RedrawBoss()
    if self.bossPage then
        self:DrawBossPage(self.boss, self.dungeon)
    else
        self:DrawBossLoot(self.boss, self.dungeon)
    end
end

function ViewMixin:Redraw()
    if not self:IsVisible() then return end
    if self.tracker then
        if self.dungeon then self:DrawTracker(self.dungeon) end
    elseif self.query then
        self:DrawSearch(self.query, self.onOpen)
    elseif self.page then
        if self.page.rank then self:DrawRank() else self:DrawFaction(self.page) end
    elseif self.boss then
        self:RedrawBoss()
    elseif self.dungeon then
        self:Draw(self.dungeon)
    end
end

function ViewMixin:QuestsUnchanged()
    if self.dungeon and self.dungeon.quests and Quests.Signature(self.dungeon.quests) == self.questSignature then
        return true
    end
    if not (self.watchQuestLog and self.page) then return false end
    local _, signature = Rep.LogQuests(self.page, self.repLog)
    return signature == self.repSignature
end

function ViewMixin:Flush()
    self.flushQueued = false
    local questsOnly = self.questsDirty and not self.dirty
    self.dirty, self.questsDirty = false, false
    if not self:IsVisible() then return end
    if questsOnly and self:QuestsUnchanged() then return end
    self:Redraw()
end

function ViewMixin:OnEvent(event, arg, success)
    if event == "GET_ITEM_INFO_RECEIVED" then
        if not self.waitingFor[arg] then return end
        if success == false then
            Refuse(arg)
            self.waitingFor[arg] = nil
            return
        end
    elseif QUEST_EVENTS[event] then
        self.questsDirty = true
        return self:QueueFlush()
    elseif event == "UNIT_QUEST_LOG_CHANGED" and arg == "player" then
        return
    end
    self:QueueRedraw()
end

function ViewMixin:OnHide()
    self:UnregisterAllEvents()
    self.dirty, self.questsDirty = false, false
end

function View.New(parent)
    local view = Shared.View.New(parent, View.Kinds, ViewMixin)
    view.filters = {}
    view.shownCache, view.rankCache, view.upgradeCache = {}, {}, {}
    view.knownCache = {}
    view.rankEntries = {}
    view.kindCounts = {}
    view.repLog = {}
    view.repLogData = { quests = {} }
    view.repLogList, view.repLogPool = {}, {}
    view.repList, view.repPool = {}, {}
    view.trackCounts = {}
    view.openRecipes = {}
    view.questList, view.questPool = {}, {}
    view.skipped, view.skippedBoss = {}, {}
    view.trash = {}
    view.hiddenWhy = {}
    return view
end

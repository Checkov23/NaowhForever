-- FactionPage.lua: a faction's page and the PvP rank's: your standing, its quests, and a card of rewards per standing or rank.
local ns = _G.NaowhForever

local GetItemCount = C_Item.GetItemCount
local IsEquippedItem = C_Item.IsEquippedItem
local GetCoinTextureString = C_CurrencyInfo.GetCoinTextureString
local GetTitleForQuestID = C_QuestLog.GetTitleForQuestID
local GetQuestDifficultyLevel = C_QuestLog.GetQuestDifficultyLevel

local J = ns.Journal
local S = J.Settings
local Loot = J.Loot
local Quests = J.Quests
local Rep = J.Reputation
local ViewMixin = J.View.Mixin
local St = J.Style
local QUEST = J.C.QUEST
local SECTION_SPACE, PLACE_DOT = St.SECTION_SPACE, St.PLACE_DOT
local REP_CODE = St.QUEST_CODE.done

local BOSS_LOOT_GAP = 4
local GEAR, RECIPES, OTHER = 1, 2, 3
local KIND_TITLES = { "Gear", "Recipes", "Other" }
local BOTH = "B"
local PRICE_COLUMN, NO_COLUMN = "price", "none"
local SPEND_ICON = "Interface\\Icons\\INV_Misc_Coin_02"

local TEXT_RANK = ns.L("Rank ")
local TEXT_EARNED_IN = ns.L("Earned in")
local TEXT_REWARDS = ns.L("Rewards")
local TEXT_QUESTS = ns.L("Quests")
local TEXT_IN_LOG = ns.L("In your quest log")
local TEXT_QUEST = ns.L("Quest ")
local TEXT_REP = ns.L("  %s+%s rep|r")
local TEXT_NO_RANK = ns.L("The game has no PvP rank for you yet. It shows once the season has started.")
local TEXT_RANK_REWARDS = ns.L("Rank Rewards")
local TEXT_NO_RANK_REWARDS = ns.L("The game lists no rank rewards for this season yet.")
local TEXT_YOU_HAVE = ns.L("you have ")
local TEXT_SPEND = ns.L("Unlocked and not yours yet: %d %s, %s")
local TEXT_REWARD, TEXT_REWARDS_WORD = ns.L("reward"), ns.L("rewards")
local TEXT_CODE_END = "|r"
local TEXT_IS, TEXT_ARE = ns.L("is"), ns.L("are")
local TEXT_WHY_RECIPES = ns.L("%d %s for professions you do not have (My Professions Only)")
local TEXT_IS_RECIPE, TEXT_ARE_RECIPES = ns.L("is a recipe"), ns.L("are recipes")
local TEXT_WHY_CLASS = ns.L("%d %s not for your class (My Class Only)")
local TEXT_WHY_COSMETIC = ns.L("%d %s cosmetic (Show Cosmetic Items, off)")
local TEXT_WHY_BIS = ns.L("%d %s not BiS you are missing (Missing BiS Only)")
local TEXT_WHY_UPGRADES = ns.L("%d %s not an upgrade over what you wear (Upgrades Only)")
local TEXT_NO_REWARDS = ns.L("WoW Forever's build %s has no rewards for it yet: they show here once a build has them.")
local TEXT_NOTHING_HERE = ns.L("Nothing here for you: of its rewards, %s. Turn %s off in Filters to see them.")
local TEXT_THAT_FILTER, TEXT_THOSE_FILTERS = ns.L("that filter"), ns.L("those filters")
local TEXT_LIST = ", "

local EMPTY = {}

local function RewardKind(itemID)
    if Loot.Wearable(itemID) then return GEAR end
    if Loot.Recipe(itemID) then return RECIPES end
    return OTHER
end

local function ToggleRecipes(row)
    local view = row:GetParent()
    view.openRecipes[row.tier] = not view.openRecipes[row.tier]
    view:Redraw()
end

local function OpenRepQuests()
    S.Set("repQuestsOpen", not S.Get("repQuestsOpen"))
end

local function IsAre(n)
    return n == 1 and TEXT_IS or TEXT_ARE
end

local function HiddenBy(filters, id)
    if filters.usableOnly and not Loot.Usable(id) then return "class" end
    if not filters.showCosmetic and Loot.Cosmetic(id) then return "cosmetic" end
    if filters.myRecipes and Loot.Recipe(id) and not Loot.RecipeYours(Loot.Recipe(id), filters) then return "recipes" end
    if filters.missingBis and not Loot.Missing(id) then return "bis" end
    if filters.upgradesOnly and not Loot.Upgrade(id) then return "upgrades" end
end

function ViewMixin:CountKinds(items, query)
    local counts = self.kindCounts
    counts[GEAR], counts[RECIPES], counts[OTHER] = 0, 0, 0
    for i = 1, #items do
        if self:Listed(items[i], query) then
            local kind = RewardKind(items[i])
            counts[kind] = counts[kind] + 1
        end
    end
    return counts
end

function ViewMixin:DrawRewards(tier, kind, query, reached, reaction, value, max)
    local faction, items = tier.faction, tier.items
    for i = 1, #items do
        local id = items[i]
        if RewardKind(id) == kind and self:Listed(id, query) then
            local item = self:Add("item", id, nil, self:ItemRank(id), self:ItemUpgrade(id), Rep.Price(faction, id))
            item.boss = nil
            if not reached then
                item.needs = tier.standing
                item.toGo, item.exact = Rep.ToGo(tier.standing, reaction, value, max)
            end
        end
    end
end

function ViewMixin:DrawTier(tier, shown, query, x, w)
    local top = self.cursor
    local card = self:OpenCard(x, w)
    local reaction, value, max = Rep.Standing(tier.faction)
    local reached = reaction ~= nil and reaction >= tier.standing
    local right
    if reaction and tier.standing == reaction + 1 then right = Rep.ToGoText(max - value, true) end
    self:Add("tier", Rep.Label(tier.standing), Rep.Color(tier.standing), reached, right, shown)
    if shown > 0 then self:Space(BOSS_LOOT_GAP) end
    self.column = PRICE_COLUMN
    local counts = self:CountKinds(tier.items, query)
    for kind = GEAR, OTHER do
        if counts[kind] > 0 then
            local folds = kind == RECIPES and counts[GEAR] > 0 and not query
            local open = not folds or self.openRecipes[tier] == true
            local group = self:Add("group", kind, KIND_TITLES[kind], counts[kind], folds and open, folds and ToggleRecipes)
            group.tier = tier
            if open then self:DrawRewards(tier, kind, query, reached, reaction, value, max) end
        end
    end
    self.column = nil
    return self:CloseCard(card, top)
end

function ViewMixin:DrawRankCard(entry, x, w)
    local top = self.cursor
    local card = self:OpenCard(x, w)
    local info, rank = self.rankInfo, entry.rank
    local right
    if rank == info.renownLevel + 1 then
        right = Rep.ToGoText(info.renownLevelThreshold - info.renownReputationEarned, true)
    end
    local rewards = entry.rewards
    self:Add("tier", TEXT_RANK .. rank .. PLACE_DOT .. Rep.RankTitle(rank), ns.THEME.fg, info.renownLevel >= rank,
        right, #rewards)
    self:Space(BOSS_LOOT_GAP)
    self.column = NO_COLUMN
    for i = 1, #rewards do
        local reward = rewards[i]
        if reward.itemID then
            self:AddItem(reward.itemID, nil, nil)
        else
            self:Add("reward", reward)
        end
    end
    self.column = nil
    return self:CloseCard(card, top)
end

function ViewMixin:GatherTiers(faction)
    local tiers, total = faction.tiers, 0
    for i = 1, #tiers do
        local shown = self:ListCount(tiers[i].items)
        if shown > 0 then
            total = total + shown
            self:Gather(tiers[i], nil, shown)
        end
    end
    return total
end

function ViewMixin:DrawFaction(faction)
    self:Begin(nil, nil, nil, faction)
    self:Add("page", faction)
    local reaction, value, max = Rep.Standing(faction)
    local counts = wipe(self.trackCounts)
    for _, tier in ipairs(faction.tiers) do counts[tier.standing] = self:ListCount(tier.items) end
    self:Add("track", reaction, value, max, counts)
    self:DrawSpend(faction, reaction)
    if self.navigate and faction.linked and #faction.linked > 0 then
        self:Add("links", TEXT_EARNED_IN, faction.linked)
        self:Space(SECTION_SPACE)
    end
    self:DrawRepQuests(faction)
    local total = self:GatherTiers(faction)
    self:Section(TEXT_REWARDS, total)
    self:Space(SECTION_SPACE)
    self:DrawGrid()
    if total == 0 then self:Note(self:HiddenWhy(faction)) end
    self:DrawBisNote()
    self:Finish()
end

function ViewMixin:HiddenWhy(faction)
    local filters, hidden = self.filters, self.hiddenWhy
    hidden.class, hidden.cosmetic, hidden.recipes, hidden.bis, hidden.upgrades = 0, 0, 0, 0, 0
    for _, tier in ipairs(faction.tiers) do
        for _, id in ipairs(tier.items) do
            local by = HiddenBy(filters, id)
            if by then hidden[by] = hidden[by] + 1 end
        end
    end
    local why = wipe(self.whyParts or {})
    self.whyParts = why
    local recipes = hidden.recipes
    if recipes > 0 then
        why[#why + 1] = TEXT_WHY_RECIPES:format(recipes, recipes == 1 and TEXT_IS_RECIPE or TEXT_ARE_RECIPES)
    end
    if hidden.class > 0 then why[#why + 1] = TEXT_WHY_CLASS:format(hidden.class, IsAre(hidden.class)) end
    if hidden.cosmetic > 0 then why[#why + 1] = TEXT_WHY_COSMETIC:format(hidden.cosmetic, IsAre(hidden.cosmetic)) end
    if hidden.bis > 0 then why[#why + 1] = TEXT_WHY_BIS:format(hidden.bis, IsAre(hidden.bis)) end
    if hidden.upgrades > 0 then why[#why + 1] = TEXT_WHY_UPGRADES:format(hidden.upgrades, IsAre(hidden.upgrades)) end
    if #why == 0 then return TEXT_NO_REWARDS:format(J.DATA_BUILD or "") end
    return TEXT_NOTHING_HERE:format(table.concat(why, TEXT_LIST), #why == 1 and TEXT_THAT_FILTER or TEXT_THOSE_FILTERS)
end

function ViewMixin:UnlockedCost(faction, reaction)
    local count, copper = 0, 0
    for _, tier in ipairs(faction.tiers) do
        if tier.standing <= reaction then
            for _, id in ipairs(tier.items) do
                local price = Rep.Price(faction, id)
                if price and self:ItemShown(id) and GetItemCount(id, true) == 0 and not IsEquippedItem(id)
                    and not (Loot.Recipe(id) and self:RecipeKnown(id)) then
                    count, copper = count + 1, copper + price
                end
            end
        end
    end
    return count, copper
end

function ViewMixin:DrawSpend(faction, reaction)
    if not reaction then return end
    local count, copper = self:UnlockedCost(faction, reaction)
    if count == 0 then return end
    local money = GetMoney()
    local have = TEXT_YOU_HAVE .. GetCoinTextureString(money)
    self.watchMoney = true
    self:Add("line", SPEND_ICON, TEXT_SPEND:format(count, count == 1 and TEXT_REWARD or TEXT_REWARDS_WORD,
        GetCoinTextureString(copper)), money < copper and St.RED_CODE .. have .. TEXT_CODE_END or have)
end

function ViewMixin:LogQuestData(log)
    local data = self.repLogData
    local quests = data.quests
    for i = 1, #log do
        local id = log[i]
        local quest = quests[i] or {}
        quests[i] = quest
        quest[QUEST.ID], quest[QUEST.NAME], quest[QUEST.LEVEL] = id, GetTitleForQuestID(id) or (TEXT_QUEST .. id),
            GetQuestDifficultyLevel(id)
        quest[QUEST.SIDE], quest[QUEST.SHAREABLE], quest[QUEST.WHERE] = BOTH, true, TEXT_IN_LOG
    end
    for i = #log + 1, #quests do quests[i] = nil end
    return data
end

local function MarkHandIns(handIns)
    for i = 1, #handIns do
        local entry = handIns[i]
        local turnin = entry.quest.turnin
        entry.turnin, entry.held = turnin, Rep.TurnInsHeld(turnin)
        if entry.held > 0 and not entry.inLog then entry.kind = "ready" end
        entry.name = entry.name .. TEXT_REP:format(REP_CODE, turnin.rep)
    end
end

function ViewMixin:DrawRepQuests(faction)
    local log, signature = Rep.LogQuests(faction, self.repLog)
    self.repSignature, self.watchQuestLog = signature, true
    local logged = Quests.List(self:LogQuestData(log), self.repLogList, self.repLogPool)
    local handIns = faction.questData and Quests.List(faction.questData, self.repList, self.repPool) or EMPTY
    MarkHandIns(handIns)
    local count = #logged + #handIns
    if count == 0 then return end
    local open = S.Get("repQuestsOpen")
    self:SectionToggle(TEXT_QUESTS, count, open, OpenRepQuests)
    if open then
        for i = 1, #logged do self:Add("quest", logged[i], i) end
        for i = 1, #handIns do self:Add("quest", handIns[i], #logged + i) end
    end
    self.questsDrawn = true
    self:Space(SECTION_SPACE)
end

function ViewMixin:GatherRanks(top)
    local entries, count = self.rankEntries, 0
    for rank = 1, top do
        local rewards = Rep.RankRewards(rank)
        if rewards and #rewards > 0 then
            count = count + 1
            local entry = entries[count]
            if not entry then
                entry = {}
                entries[count] = entry
            end
            entry.rank, entry.rewards = rank, rewards
            self:Gather(entry, nil, #rewards)
        end
    end
    return count
end

function ViewMixin:DrawRank()
    self:Begin(nil, nil, nil, J.RANK)
    local info = Rep.Rank()
    self.rankInfo = info
    self:Add("page", J.RANK, info)
    if not info then
        self:Note(TEXT_NO_RANK)
        self:Finish()
        return
    end
    self:Add("rankTrack", info)
    local count = self:GatherRanks(info.maxLevel)
    self:Section(TEXT_RANK_REWARDS, count)
    self:Space(SECTION_SPACE)
    self:DrawGrid()
    if count == 0 then self:Note(TEXT_NO_RANK_REWARDS) end
    self:Finish()
end

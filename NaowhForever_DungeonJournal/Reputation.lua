-- Reputation.lua: the Dungeon Journal's reputation rules: your standing, rewards reached, prices and your PvP rank (J.Reputation).
local ns = _G.NaowhForever

local GetFactionDataByID = C_Reputation.GetFactionDataByID
local GetItemCount = C_Item.GetItemCount
local GetNumQuestLogEntries = C_QuestLog.GetNumQuestLogEntries
local GetQuestIDForLogIndex = C_QuestLog.GetQuestIDForLogIndex
local AwardsReputation = C_QuestLog.DoesQuestAwardReputationWithFaction
local ReadyForTurnIn = C_QuestLog.ReadyForTurnIn

local J = ns.Journal
local S = J.Settings
local Loot = J.Loot
local ListBis, ListNewLooks = Loot.ListBis, Loot.ListNewLooks

local NEUTRAL, EXALTED = 4, 8
local RANK_FACTION = 2800
local HONOR, RANK_POINTS = 1792, 3468
local COPPER_PER_SILVER, COPPER_PER_GOLD = 100, 10000
local WHOLE_GOLD = 10
local TENTHS = 10
local ROUND = J.C.ROUND_HALF
local READY_WEIGHT, LOGGED_WEIGHT = 2, 1
local TAKE_STRIDE = 2
local ALLIANCE_RANKS, HORDE_RANKS = 1, 0
local SECONDS_PER_DAY, SECONDS_PER_HOUR, SECONDS_PER_MINUTE = 86400, 3600, J.C.SECONDS_PER_MINUTE
local BAND = { [1] = 36000, [2] = 3000, [3] = 3000, [4] = 3000, [5] = 6000, [6] = 12000, [7] = 21000 }

local STANDING_LABEL = "FACTION_STANDING_LABEL"
local RANK_LABEL = "PVP_RANK_%d_%d"
local TEXT_TENTHS = "%.1f"
local TEXT_ABOUT = ns.L("about ")
local TEXT_TO_GO = ns.L(" to go")
local TEXT_DAY, TEXT_DAYS = ns.L("1 day"), ns.L(" days")
local TEXT_HOUR, TEXT_HOURS = ns.L("1 hour"), ns.L(" hours")
local TEXT_MINUTE, TEXT_MINUTES = ns.L("1 minute"), ns.L(" minutes")

local labels = {}
local short = {}

local function IsTurnIn(faction, questID)
    local turnins = faction.turnins
    if not turnins then return false end
    for i = 1, #turnins do
        local quests = turnins[i].quests
        for k = 1, #quests do
            if quests[k][1] == questID then return true end
        end
    end
    return false
end

local function GoldText(gold, coin)
    if gold >= WHOLE_GOLD then return math.floor(gold + ROUND) .. coin end
    local tenths = math.floor(gold * TENTHS + ROUND)
    if tenths % TENTHS == 0 then return tostring(tenths / TENTHS) .. coin end
    return TEXT_TENTHS:format(tenths / TENTHS) .. coin
end

local function ShortPrice(copper)
    local coin = J.Style.COIN_ICON
    local gold = copper / COPPER_PER_GOLD
    if gold >= 1 then return GoldText(gold, coin.g) end
    return math.max(1, math.floor(copper / COPPER_PER_SILVER + ROUND)) .. coin.s
end

local function Plural(n, one, many)
    return n == 1 and one or n .. many
end

local Rep = {}
J.Reputation = Rep
Rep.EXALTED = EXALTED
Rep.HONOR, Rep.RANK_POINTS = HONOR, RANK_POINTS

function Rep.Standing(faction)
    local data = GetFactionDataByID(faction.id)
    if not (data and data.reaction) then return nil, 0, 1 end
    local reaction = data.reaction
    if reaction >= EXALTED then return reaction, 1, 1 end
    local low = data.currentReactionThreshold or 0
    return reaction, data.currentStanding - low, math.max(1, (data.nextReactionThreshold or low + 1) - low)
end

function Rep.Label(reaction)
    local label = labels[reaction]
    if label then return label end
    label = GetText(STANDING_LABEL .. reaction, UnitSex("player")) or tostring(reaction)
    labels[reaction] = label
    return label
end

function Rep.Color(reaction)
    return J.Style.STANDING_RGB[reaction] or J.Style.STANDING_RGB[NEUTRAL]
end

function Rep.Shown(faction)
    if faction.rank then return true end
    if faction.side and faction.tab == "reputation" then return faction.side == UnitFactionGroup("player") end
    if faction.side == "Alliance" then return S.Get("showAlliance") end
    if faction.side == "Horde" then return S.Get("showHorde") end
    return true
end

function Rep.Bis(faction)
    local count, have = 0, 0
    for _, tier in ipairs(faction.tiers) do count, have = ListBis(tier.items, count, have) end
    return count, have
end

function Rep.NewLooks(faction, filters)
    local new, looks = 0, 0
    for _, tier in ipairs(faction.tiers) do new, looks = ListNewLooks(tier.items, filters, new, looks) end
    return new, looks
end

function Rep.Price(faction, itemID)
    return faction.prices and faction.prices[itemID]
end

function Rep.PriceText(copper)
    local text = short[copper]
    if text then return text end
    text = ShortPrice(copper)
    short[copper] = text
    return text
end

function Rep.ToGo(standing, reaction, value, max)
    if not reaction then return nil, false end
    if reaction >= standing then return 0, true end
    local toGo = max - value
    for s = reaction + 1, standing - 1 do toGo = toGo + (BAND[s] or 0) end
    return toGo, standing == reaction + 1
end

function Rep.ToGoText(toGo, exact)
    return (exact and "" or TEXT_ABOUT) .. BreakUpLargeNumbers(toGo) .. TEXT_TO_GO
end

function Rep.Unlocked(faction, reaction, filters)
    local unlocked, total = 0, 0
    for _, tier in ipairs(faction.tiers) do
        local reached = reaction ~= nil and reaction >= tier.standing
        for _, id in ipairs(tier.items) do
            if Loot.Shown(id, filters) then
                total = total + 1
                if reached then unlocked = unlocked + 1 end
            end
        end
    end
    return unlocked, total
end

function Rep.LogQuests(faction, out)
    wipe(out)
    local signature = 0
    for i = 1, GetNumQuestLogEntries() do
        local id = GetQuestIDForLogIndex(i)
        if id and id > 0 and AwardsReputation(id, faction.id) and not IsTurnIn(faction, id) then
            out[#out + 1] = id
            signature = signature + id * (ReadyForTurnIn(id) and READY_WEIGHT or LOGGED_WEIGHT)
        end
    end
    return out, signature + #out
end

function Rep.TurnInsHeld(turnin)
    local takes, times = turnin.takes, nil
    for i = 1, #takes, TAKE_STRIDE do
        local n = math.floor(GetItemCount(takes[i]) / takes[i + 1])
        if not times or n < times then times = n end
    end
    return times or 0
end

function Rep.Rank()
    return C_MajorFactions.GetMajorFactionProgressionInfo(RANK_FACTION)
end

function Rep.RankTitle(rank)
    if not rank or rank <= 0 then return PVP_RANK_0_NAME end
    local side = UnitFactionGroup("player") == "Alliance" and ALLIANCE_RANKS or HORDE_RANKS
    return GetText(RANK_LABEL:format(Enum.PvPRanks.Rank_1 + rank - 1, side), UnitSex("player"))
end

function Rep.RankRewards(rank)
    return C_MajorFactions.GetRenownRewardsForLevel(RANK_FACTION, rank)
end

function Rep.Season()
    return GetCurrentArenaSeason() or 0, C_SeasonInfo.GetTimeUntilCurrentPVPSeasonEnd() or 0
end

function Rep.Currency(id)
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    if not info then return 0 end
    return info.quantity or 0, info.name, info.iconFileID
end

function Rep.Duration(seconds)
    local days = math.floor(seconds / SECONDS_PER_DAY)
    if days >= 1 then return Plural(days, TEXT_DAY, TEXT_DAYS) end
    local hours = math.floor(seconds / SECONDS_PER_HOUR)
    if hours >= 1 then return Plural(hours, TEXT_HOUR, TEXT_HOURS) end
    return Plural(math.max(1, math.floor(seconds / SECONDS_PER_MINUTE)), TEXT_MINUTE, TEXT_MINUTES)
end

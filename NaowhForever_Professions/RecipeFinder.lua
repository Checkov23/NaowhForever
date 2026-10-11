-- RecipeFinder.lua: the recipes you have not learned yet, the skill and money each needs and where it comes from.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local S = P.Settings
local C = P.C
local Hex = P.Text.Hex

local NEAREST = 3
local PERCENT = C.PERCENT
local TRAINER_SCAN_DELAY = 0.2
local NO_MAP = 0
local HORDE, ALLIANCE, ANY = "H", "A", "-"
local NPC_NAME, NPC_FACTION, NPC_MAP, NPC_X, NPC_Y, NPC_PRICE = C.NPC_NAME, C.NPC_FACTION, C.NPC_MAP, C.NPC_X,
    C.NPC_Y, C.NPC_PRICE
local DROP_MOB, DROP_AREA, DROP_MIN, DROP_MAX, DROP_CHANCE = 1, 2, 3, 4, 5
local SOURCE_TAG = { trainer = ns.L("Trainer"), teacher = ns.L("Trainer"), vendor = ns.L("Vendor"), drop = ns.L("Drop"),
    quest = ns.L("Quest"), unknown = "?" }
local DEFAULT_PROFESSION = ns.L("First Aid")
local TEXT_FREE = "free"
local TEXT_UNKNOWN = "?"
local TEXT_MANUAL = ns.L("its manual")
local TEXT_NPC = "%s - %s %.1f, %.1f%s"
local TEXT_RANK_BOOK = "Your cap is %d.\nFirst read %s (needs skill %d):"
local TEXT_LEVEL_PART = ns.L("level %d, ")
local TEXT_RANK_QUEST = "Your cap is %d.\nFirst do the quest %s%s|r (%sskill %d):"
local TEXT_RANK_TRAIN = "Your cap is %d.\nFirst train %s (%s, needs skill %d):"
local TEXT_RECIPE = "Recipe: "
local TEXT_QUEST_OTHER = ns.L("A quest reward for the other faction; try the Auction House.")
local TEXT_QUEST_REWARD = ns.L("A reward from the quest ")
local TEXT_QUEST_GIVER = ns.L("  (quest giver)")
local TEXT_TRAINER = "Trainer: %s.%s Nearest:"
local TEXT_ALSO_QUEST = ns.L(" Also a reward from the quest ")
local TEXT_TEACHER = "Taught for free by the Artisan doctor:"
local TEXT_VENDOR_OTHER = "Recipe: %s\nOnly the other faction sells it; try the Auction House."
local TEXT_SOLD_FOR = ns.L("Sold for ")
local TEXT_SOLD = ns.L("Sold")
local TEXT_SOLD_BY = "Recipe: %s\n%s%s by:"
local TEXT_NEEDS = " (needs "
local TEXT_DROPS_FROM = "Recipe: %s\nDrops from:"
local TEXT_BOSS = "%s - %s"
local TEXT_WORLD_DROP = "Recipe: %s\nA world drop%s. Also try the Auction House."
local TEXT_WORLD_LEVEL = ns.L(", from mobs around level ")
local TEXT_CHESTS, TEXT_FISHING, TEXT_PICKPOCKET = ns.L("chests and lockboxes"), ns.L("fishing"), ns.L("pickpocketing")
local TEXT_MOB_KINDS = ns.L("A world drop from %d kinds of mob")
local TEXT_FOUND = ns.L("Found")
local TEXT_THROUGH = " through "
local TEXT_BEST_ODDS = ns.L(" Best odds:")
local TEXT_DROP_LINE = "%s (%s) - %s, %.1f%%"
local TEXT_DROP_RECIPE = "Recipe: %s\n%s%s.%s"
local TEXT_NOT_RECORDED = ns.L("Where it comes from is not recorded yet; try the Auction House.")
local TEXT_REQUIREMENT = ns.L("%sRequires %s %d|r   %s(you: %d/%d)|r")

local list, state = {}, nil
local current, EMPTY, skillOf = {}, {}, {}
local learnedNow
local trainerQueued = false
local events = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and S.Get("recipeFinder")
end

local function Faction()
    return UnitFactionGroup("player") == "Horde" and HORDE or ALLIANCE
end

local function ForMe(fac)
    return fac == ANY or fac:find(Faction(), 1, true) ~= nil
end

local function Money(copper)
    if not copper or copper <= 0 then return TEXT_FREE end
    return GetMoneyString and GetMoneyString(copper, true) or C_CurrencyInfo.GetCoinTextureString(copper)
end

local function ZoneName(map)
    local info = C_Map.GetMapInfo(map)
    return info and info.name or TEXT_UNKNOWN
end

local function Match(p)
    if not p then return end
    if ns.RecipeData[p.professionID] then return p.professionID end
    if ns.RecipeData[p.parentProfessionID] then return p.parentProfessionID end
    for id, data in pairs(ns.RecipeData) do
        if p.professionName and p.professionName == C_Spell.GetSpellName(data.skillSpell) then return id end
    end
end

local function ReadProfession()
    if C_TradeSkillUI.IsTradeSkillLinked() or C_TradeSkillUI.IsTradeSkillGuild() then return end
    if C_TradeSkillUI.IsNPCCrafting and C_TradeSkillUI.IsNPCCrafting() then return end
    local child, base = C_TradeSkillUI.GetChildProfessionInfo(), C_TradeSkillUI.GetBaseProfessionInfo()
    local id = Match(child) or Match(base)
    if not id then return end
    local src = (child and (child.maxSkillLevel or 0) > 0) and child or base
    return id, src.skillLevel or 0, src.maxSkillLevel or 0
end

local function Learned(spell)
    local known = learnedNow and learnedNow[spell]
    if known then return true end
    if known == nil then
        local info = C_TradeSkillUI.GetRecipeInfo(spell)
        if info and info.learned then return true end
    end
    return C_SpellBook.IsSpellKnown(spell)
end

local function Overrides()
    local account = ns.AccountSettings()
    account.profTrainerReq = account.profTrainerReq or {}
    return account.profTrainerReq
end

local function Skill(r)
    local o = Overrides()[r.spell]
    return o and o[1] or r.skill
end

local function Cost(r)
    local o = Overrides()[r.spell]
    return o and o[2] or r.cost
end

local function Status(r)
    local need = Skill(r)
    if state.skill >= need then return "ready" end
    if state.max < need then return "rank" end
    return "later"
end

local function NextRank()
    for _, rank in ipairs(state.data.ranks) do
        if rank.cap > state.max then return rank end
    end
end

local function WorldPos(map, x, y)
    local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
    if ok and cont and pos then return cont, pos end
end

local function NearestFirst(a, b)
    if a.dist ~= b.dist then return a.dist < b.dist end
    return a.npc[NPC_NAME] < b.npc[NPC_NAME]
end

local function Distance(npc, cont, pos)
    if not (cont and npc[NPC_MAP] > NO_MAP) then return math.huge end
    local c, p = WorldPos(npc[NPC_MAP], npc[NPC_X] / PERCENT, npc[NPC_Y] / PERCENT)
    if c ~= cont then return math.huge end
    local x1, y1 = pos:GetXY()
    local x2, y2 = p:GetXY()
    return (x1 - x2) ^ 2 + (y1 - y2) ^ 2
end

local function Nearest(npcs, n)
    local map = C_Map.GetBestMapForUnit("player")
    local here = map and C_Map.GetPlayerMapPosition(map, "player")
    local cont, pos
    if here then cont, pos = WorldPos(map, here:GetXY()) end
    local out = {}
    for _, npc in ipairs(npcs) do
        if ForMe(npc[NPC_FACTION]) then out[#out + 1] = { npc = npc, dist = Distance(npc, cont, pos) } end
    end
    table.sort(out, NearestFirst)
    local picked = {}
    for i = 1, math.min(n or #out, #out) do picked[i] = out[i].npc end
    return picked
end

local function ItemName(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    if name then return Hex(T.accent) .. name .. "|r" end
    if ns.ProfRequestItem then
        ns.ProfRequestItem(itemID)
    else
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return TEXT_MANUAL
end

local function Para(out, text)
    out[#out + 1] = { text = text, para = true }
end

local function NpcLine(out, npc, extra)
    out[#out + 1] = {
        text = TEXT_NPC:format(npc[NPC_NAME], ZoneName(npc[NPC_MAP]), npc[NPC_X], npc[NPC_Y], extra or ""),
        npc = npc,
    }
end

local function Rows(indices, data)
    if not indices or type(indices[1]) ~= "number" then return indices or {} end
    local trainers = (data or state.data).trainers
    local rows = {}
    for i, index in ipairs(indices) do rows[i] = trainers[index] end
    return rows
end

local function QuestTitle(id, fallback)
    return id and C_QuestLog.GetTitleForQuestID(id) or fallback or TEXT_UNKNOWN
end

local function RecipeLine(recipe)
    return recipe and (TEXT_RECIPE .. ItemName(recipe) .. "\n") or ""
end

local function DescribeRank(rank, out)
    if rank.item then
        Para(out, TEXT_RANK_BOOK:format(state.max, ItemName(rank.item), rank.skill))
        for _, v in ipairs(Nearest(rank.vendors, 1)) do NpcLine(out, v, "  " .. Money(v[NPC_PRICE])) end
    elseif rank.quest then
        local title = QuestTitle(rank.quest[Faction()], rank.questName)
        Para(out, TEXT_RANK_QUEST:format(state.max, Hex(T.accent), title,
            rank.level and TEXT_LEVEL_PART:format(rank.level) or "", rank.skill))
        for _, v in ipairs(Nearest(rank.teachers, 1)) do NpcLine(out, v) end
    else
        Para(out, TEXT_RANK_TRAIN:format(state.max, rank.name, Money(rank.cost), rank.skill))
        for _, v in ipairs(Nearest(rank.t and Rows(rank.t) or state.data.trainers, 1)) do NpcLine(out, v) end
    end
end

local function DescribeQuests(out, quests, recipe)
    local mine = {}
    for _, q in ipairs(quests) do
        if ForMe(q.side or "AH") then mine[#mine + 1] = q end
    end
    if #mine == 0 then
        Para(out, RecipeLine(recipe) .. TEXT_QUEST_OTHER)
        return
    end
    local names = {}
    for i, q in ipairs(mine) do names[i] = Hex(T.accent) .. QuestTitle(q.id, q.name) .. "|r" end
    Para(out, RecipeLine(recipe) .. TEXT_QUEST_REWARD .. table.concat(names, ns.L(" or ")) .. ":")
    for _, q in ipairs(mine) do
        if q.npc then NpcLine(out, q.npc, TEXT_QUEST_GIVER) end
    end
end

local function DescribeTrainer(r, out)
    Para(out, TEXT_TRAINER:format(Money(Cost(r)),
        r.quest and (TEXT_ALSO_QUEST .. Hex(T.accent) .. r.quest .. "|r.") or ""))
    for _, v in ipairs(Nearest(r.t and Rows(r.t) or state.data.trainers, NEAREST)) do NpcLine(out, v) end
end

local function DescribeTeacher(out)
    Para(out, TEXT_TEACHER)
    for _, rank in ipairs(state.data.ranks) do
        if rank.teachers then
            for _, v in ipairs(Nearest(rank.teachers, 1)) do NpcLine(out, v) end
        end
    end
end

local function DescribeVendor(r, out)
    local sellers = Nearest(r.vendors)
    if #sellers == 0 then
        Para(out, TEXT_VENDOR_OTHER:format(ItemName(r.recipe)))
        return
    end
    local price = sellers[1][NPC_PRICE] and (TEXT_SOLD_FOR .. Money(sellers[1][NPC_PRICE])) or TEXT_SOLD
    Para(out, TEXT_SOLD_BY:format(ItemName(r.recipe), price, r.rep and (TEXT_NEEDS .. r.rep .. ")") or ""))
    for i = 1, math.min(NEAREST, #sellers) do NpcLine(out, sellers[i]) end
end

local function DescribeBosses(r, out)
    Para(out, TEXT_DROPS_FROM:format(ItemName(r.recipe)))
    for _, b in ipairs(r.bosses) do
        out[#out + 1] = { text = TEXT_BOSS:format(b[1], b[2] and C_Map.GetAreaInfo(b[2]) or TEXT_UNKNOWN) }
    end
end

local function DescribeWorld(r, out)
    Para(out, TEXT_WORLD_DROP:format(ItemName(r.recipe), r.world > 1 and (TEXT_WORLD_LEVEL .. r.world) or ""))
end

local function DescribeDrops(r, out)
    local extra = {}
    if r.chests then extra[#extra + 1] = TEXT_CHESTS end
    if r.fished then extra[#extra + 1] = TEXT_FISHING end
    if r.pickpocket then extra[#extra + 1] = TEXT_PICKPOCKET end
    local mobs = (r.mobs or 0) > 0
    local from = mobs and TEXT_MOB_KINDS:format(r.mobs) or TEXT_FOUND
    Para(out, TEXT_DROP_RECIPE:format(ItemName(r.recipe), from,
        #extra > 0 and (mobs and ", " or TEXT_THROUGH) .. table.concat(extra, ", ") or "",
        #(r.drops or {}) > 0 and TEXT_BEST_ODDS or ""))
    for _, d in ipairs(r.drops or {}) do
        local low, high = d[DROP_MIN], d[DROP_MAX]
        local level = low == high and tostring(low) or (low .. "-" .. high)
        out[#out + 1] = { text = TEXT_DROP_LINE:format(d[DROP_MOB], level,
            C_Map.GetAreaInfo(d[DROP_AREA]) or TEXT_UNKNOWN, d[DROP_CHANCE]) }
    end
end

local function Describe(r)
    local out = {}
    if Status(r) == "rank" then
        local rank = NextRank()
        if rank then DescribeRank(rank, out) end
    end
    if r.source == "trainer" then
        DescribeTrainer(r, out)
    elseif r.source == "teacher" then
        DescribeTeacher(out)
    elseif r.source == "vendor" then
        DescribeVendor(r, out)
    elseif r.source == "drop" and r.bosses then
        DescribeBosses(r, out)
    elseif r.source == "drop" and r.world then
        DescribeWorld(r, out)
    elseif r.source == "drop" then
        DescribeDrops(r, out)
    elseif r.source == "quest" then
        DescribeQuests(out, r.quests, r.recipe)
    else
        Para(out, RecipeLine(r.recipe) .. TEXT_NOT_RECORDED)
    end
    return out
end

local function RowColor(r)
    local st = Status(r)
    if st == "ready" then return P.Style.READY_RGB end
    if st == "rank" then return P.Style.RANK_RGB end
    return T.muted
end

local function BySkill(x, y)
    local sx, sy = skillOf[x], skillOf[y]
    if sx ~= sy then return sx < sy end
    return x.spell < y.spell
end

local function Compute()
    local id, skill, max = ReadProfession()
    wipe(list)
    if not id then
        state = nil
        return false
    end
    state = current
    state.id, state.data, state.skill, state.max = id, ns.RecipeData[id], skill, max
    for _, r in ipairs(state.data.recipes) do
        if not Learned(r.spell) then
            list[#list + 1] = r
            skillOf[r] = Skill(r)
        end
    end
    table.sort(list, BySkill)
    return true
end

local function TrainerRecipesByName()
    local byName, lineOf = {}, {}
    for line, data in pairs(ns.RecipeData) do
        lineOf[C_Spell.GetSpellName(data.skillSpell) or ""] = line
        for _, r in ipairs(data.recipes) do
            local name = C_Spell.GetSpellName(r.spell)
            if name then
                byName[name] = byName[name] or {}
                byName[name][#byName[name] + 1] = { r = r, line = line }
            end
        end
    end
    return byName, lineOf
end

local function ScanTrainer()
    if not (IsTradeskillTrainer and IsTradeskillTrainer()) then return end
    local byName, lineOf = TrainerRecipesByName()
    local overrides, changed = Overrides(), false
    for i = 1, GetNumTrainerServices() do
        local name, _, category = GetTrainerServiceInfo(i)
        local skillName, rank = GetTrainerServiceSkillReq(i)
        if name and category ~= "header" and rank and byName[name] then
            local line = lineOf[skillName or ""]
            for _, m in ipairs(byName[name]) do
                if not line or m.line == line then
                    local cost = GetTrainerServiceCost(i)
                    local old = overrides[m.r.spell]
                    if not old or old[1] ~= rank or old[2] ~= cost then
                        overrides[m.r.spell] = { rank, cost }
                        changed = true
                    end
                end
            end
        end
    end
    if changed and ns.ProfWindowRefresh then ns.ProfWindowRefresh(true) end
end

local function RunTrainerScan()
    trainerQueued = false
    ScanTrainer()
end

local function QueueTrainerScan()
    if trainerQueued then return end
    trainerQueued = true
    C_Timer.After(TRAINER_SCAN_DELAY, RunTrainerScan)
end

local function DumpProfession(label, p)
    if not p then
        ns.Print(label .. ": nil")
        return
    end
    ns.Print(("%s: id=%s parent=%s name=%s skill=%s/%s"):format(label, tostring(p.professionID),
        tostring(p.parentProfessionID), tostring(p.professionName), tostring(p.skillLevel),
        tostring(p.maxSkillLevel)))
end

local function Unlearned(learned)
    learnedNow = learned
    local ok = On() and Compute()
    learnedNow = nil
    if not ok then return EMPTY end
    return list
end

local function Requirement(r)
    local profName = C_Spell.GetSpellName(state.data.skillSpell) or DEFAULT_PROFESSION
    return TEXT_REQUIREMENT:format(Hex(RowColor(r)), profName, Skill(r), Hex(T.muted), state.skill, state.max)
end

local function Tag(r)
    return SOURCE_TAG[r.source] or TEXT_UNKNOWN
end

ns.RecipeFinder = {
    Unlearned = Unlearned,
    Color = RowColor,
    Status = Status,
    Requirement = Requirement,
    Describe = Describe,
    Tag = Tag,
    Skill = Skill,
    Current = ReadProfession,
    Nearest = Nearest,
    Rows = Rows,
    Money = Money,
    ZoneName = ZoneName,
    Hex = Hex,
}

function ns.RecipeFinderDebug()
    DumpProfession("child", C_TradeSkillUI.GetChildProfessionInfo())
    DumpProfession("base", C_TradeSkillUI.GetBaseProfessionInfo())
    local id, skill, max = ReadProfession()
    ns.Print(("matched=%s skill=%s/%s"):format(tostring(id), tostring(skill), tostring(max)))
    local ids = C_TradeSkillUI.GetAllRecipeIDs() or {}
    local apiUnlearned = 0
    for _, rid in ipairs(ids) do
        local info = C_TradeSkillUI.GetRecipeInfo(rid)
        if info and not info.learned then apiUnlearned = apiUnlearned + 1 end
    end
    ns.Print(("API recipes: %d (%d unlearned)"):format(#ids, apiUnlearned))
    if not id then return end
    local learned = 0
    for _, r in ipairs(ns.RecipeData[id].recipes) do
        if Learned(r.spell) then learned = learned + 1 end
    end
    ns.Print(("Data recipes: %d, %d learned"):format(#ns.RecipeData[id].recipes, learned))
end

local function Apply()
    events:UnregisterAllEvents()
    if not On() then return end
    events:RegisterEvent("TRAINER_SHOW")
    events:RegisterEvent("TRAINER_UPDATE")
end

local function OnSettingChanged(key)
    if key ~= "enabled" and key ~= "recipeFinder" then return end
    Apply()
    if ns.ProfWindowRefresh then ns.ProfWindowRefresh(true) end
end

events:SetScript("OnEvent", QueueTrainerScan)
hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

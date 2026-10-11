-- QuestPanel.lua: a quest in your log, in the side panel: objectives, description, rewards and its buttons.
local ns = _G.NaowhForever

local GetCoinTextureString = C_CurrencyInfo.GetCoinTextureString

local J = ns.Journal
local Quests = J.Quests
local View = J.View
local Parts = View.Parts
local Plain = Parts.Plain
local QUEST = J.C.QUEST
local St = J.Style
local SECTION_SPACE, PLACE_DOT = St.SECTION_SPACE, St.PLACE_DOT

local REDRAW_DELAY = 0.15
local ITEM_ID_RETURN = 6
local TURN_IN_WHO = 4

local TEXT_QUEST = ns.L("QUEST")
local TEXT_HAND_IN = ns.L("Hand in: ")
local TEXT_OBJECTIVES = ns.L("Objectives")
local TEXT_DESCRIPTION = ns.L("Description")
local TEXT_REWARDS = ns.L("Rewards")
local TEXT_CHOOSE = ns.L("Choose one of these:")
local TEXT_ALSO = ns.L("And also:")
local TEXT_EXPERIENCE = ns.L(" experience")
local TEXT_TRACK, TEXT_UNTRACK = ns.L("Track"), ns.L("Untrack")
local TEXT_ABANDON = ns.L("Abandon %s?")

local EMPTY = {}
local panel, view
local shownID
local queued = false
local choices, rewards, gains = {}, {}, {}

local function FindQuest(id)
    for _, dungeon in ipairs(J.Dungeons()) do
        local data = dungeon.quests
        for _, quest in ipairs(data and data.quests or EMPTY) do
            if Quests.LoggedID(quest) == id then return quest, dungeon end
        end
    end
end

local function HandIn(id, quest)
    local turnIn = J.QuestTurnIns[id]
    if turnIn then return TEXT_HAND_IN .. turnIn[TURN_IN_WHO] end
    return quest and Plain(quest[QUEST.WHERE])
end

local function ReadItems(out, count, get)
    wipe(out)
    for i = 1, count do
        local itemID = select(ITEM_ID_RETURN, get(i))
        if itemID then out[#out + 1] = itemID end
    end
end

local function Read(id)
    local previous = C_QuestLog.GetSelectedQuest()
    C_QuestLog.SetSelectedQuest(id)
    local description = GetQuestLogQuestText()
    ReadItems(choices, GetNumQuestLogChoices(id, true) or 0, GetQuestLogChoiceInfo)
    ReadItems(rewards, GetNumQuestLogRewards() or 0, GetQuestLogRewardInfo)
    local xp, money = GetQuestLogRewardXP() or 0, GetQuestLogRewardMoney() or 0
    if previous and previous ~= id then C_QuestLog.SetSelectedQuest(previous) end
    return description, xp, money
end

local function Items(list)
    for i = 1, #list do
        local itemID = list[i]
        view:Add("item", itemID, nil, view:ItemRank(itemID), view:ItemUpgrade(itemID))
    end
end

local function DrawObjectives(id)
    local objectives = C_QuestLog.GetQuestObjectives(id) or EMPTY
    if #objectives == 0 then return end
    view:Section(TEXT_OBJECTIVES, #objectives)
    for i = 1, #objectives do view:Add("objective", objectives[i]) end
    view:Space(SECTION_SPACE)
end

local function DrawDescription(description)
    if not description or description == "" then return end
    view:Section(TEXT_DESCRIPTION)
    view:Note(description)
    view:Space(SECTION_SPACE)
end

local function DrawRewards(xp, money)
    if #choices == 0 and #rewards == 0 and xp <= 0 and money <= 0 then return end
    view:Section(TEXT_REWARDS, #choices + #rewards)
    if #choices > 1 then view:Note(TEXT_CHOOSE) end
    Items(choices)
    if #rewards > 0 and #choices > 0 then view:Note(TEXT_ALSO) end
    Items(rewards)
    wipe(gains)
    if xp > 0 then gains[#gains + 1] = BreakUpLargeNumbers(xp) .. TEXT_EXPERIENCE end
    if money > 0 then gains[#gains + 1] = GetCoinTextureString(money) end
    if #gains > 0 then view:Note(table.concat(gains, PLACE_DOT)) end
end

local function PaintButtons(id)
    local buttons = panel.buttons
    ns.SetButtonText(buttons.Track, QuestUtils_IsQuestWatched(id) and TEXT_UNTRACK or TEXT_TRACK)
    buttons.Share:SetEnabled(IsInGroup() and C_QuestLog.IsPushableQuest(id) == true)
    buttons.Abandon:SetEnabled(C_QuestLog.CanAbandonQuest(id) == true)
end

local function Draw()
    local id = shownID
    if not (id and C_QuestLog.GetLogIndexForQuestID(id)) then
        panel:Hide()
        return
    end
    local quest, dungeon = FindQuest(id)
    panel.title:SetText(dungeon and dungeon.name:upper() or TEXT_QUEST)
    local description, xp, money = Read(id)
    view:Begin(nil, nil, nil)
    view.showChance = false
    view:Add("questTitle", C_QuestLog.GetTitleForQuestID(id) or (quest and quest[QUEST.NAME]) or "",
        quest and Quests.Level(quest), C_QuestLog.IsComplete(id), HandIn(id, quest))
    DrawObjectives(id)
    DrawDescription(description)
    DrawRewards(xp, money)
    view:Finish()
    PaintButtons(id)
end

local function Flush()
    queued = false
    if panel:IsShown() then Draw() end
end

local function OnEvent()
    if queued then return end
    queued = true
    C_Timer.After(REDRAW_DELAY, Flush)
end

local function OnShow(self)
    self:RegisterEvent("QUEST_LOG_UPDATE")
end

local function OnHide(self)
    self:UnregisterAllEvents()
end

local function Share()
    local index = C_QuestLog.GetLogIndexForQuestID(shownID)
    if index then QuestLogPushQuest(index) end
end

local function Track()
    if QuestUtils_IsQuestWatched(shownID) then
        C_QuestLog.RemoveQuestWatch(shownID)
    else
        C_QuestLog.AddQuestWatch(shownID)
    end
    Draw()
end

local function Waypoint()
    local quest = FindQuest(shownID)
    if quest then Quests.Waypoint(quest) end
end

local function Abandon()
    local id = shownID
    local name = C_QuestLog.GetTitleForQuestID(id) or ""
    ns.Confirm(TEXT_ABANDON:format(name), function()
        local previous = C_QuestLog.GetSelectedQuest()
        C_QuestLog.SetSelectedQuest(id)
        C_QuestLog.SetAbandonQuest()
        C_QuestLog.AbandonQuest()
        if previous and previous ~= id then C_QuestLog.SetSelectedQuest(previous) end
        panel:Hide()
    end)
end

local ACTIONS = { { "Share", Share }, { "Track", Track }, { "Waypoint", Waypoint }, { "Abandon", Abandon } }

local function Build()
    panel = Parts.SidePanel(ACTIONS)
    view = panel.view
    view.Redraw = Draw
    panel:SetScript("OnEvent", OnEvent)
    panel:SetScript("OnShow", OnShow)
    panel:SetScript("OnHide", OnHide)
end

local QuestPanel = {}
View.QuestPanel = QuestPanel

function QuestPanel.Show(questID, from)
    if not panel then Build() end
    if panel:IsShown() and shownID == questID then
        panel:Hide()
        return
    end
    shownID = questID
    Parts.ShowBeside(panel, from)
    Draw()
end

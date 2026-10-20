-- RewardList.lua: the Saved Quest Rewards window: every reward this class saved for a quest, to look over and remove.
local ns = _G.NaowhForever

local T = ns.THEME
local Shared = ns.Shared
local Parts, St, View = Shared.Parts, Shared.Style, Shared.View
local Rewards = ns.QuestRewards

local PAGE = "QoL/Questing & Group"
local WIDTH, HEIGHT = 620, 480
local HEADER, PAD, FOOTER, SCROLLBAR = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER, St.SCROLLBAR
local INSET = St.CONTENT_INSET
local BOTTOM_H = 34
local CLEAR_W, CLEAR_H = 100, 24
local CARD_INSET = 6
local SCROLL_GAP = 4
local VIEW_SPARE = 8
local SUMMARY_SIZE = 12
local EVENTS = { "QUEST_DATA_LOAD_RESULT" }

local TEXT_TITLE = ns.L("Saved Quest Rewards")
local TEXT_SUBTITLE = ns.L("Picked for you when you hand the quest in. Alt-click a reward to save one for this class.")
local TEXT_EMPTY = ns.L("Nothing saved for this class. Alt-click a quest reward to save it for that quest.")
local TEXT_QUEST = ns.L("Quest %d")
local TEXT_REWARD, TEXT_REWARDS = ns.L("%d saved reward"), ns.L("%d saved rewards")
local TEXT_REMOVE = ns.L("Remove")
local TEXT_UNCONFIRMED = ns.L("Not confirmed")
local TEXT_CLEAR = ns.L("Clear All")
local TEXT_CLEAR_ASK = ns.L("Remove every saved quest reward for this class?")

local window, view, summary
local ids = {}
local requested = {}
local names = {}

local function QuestName(questID)
    local title = Rewards.Title(questID)
    if title then return title end
    if not requested[questID] then
        requested[questID] = true
        C_QuestLog.RequestLoadQuestByID(questID)
    end
    return TEXT_QUEST:format(questID)
end

local function ByName(a, b)
    if names[a] ~= names[b] then return names[a] < names[b] end
    return a < b
end

local function RemoveReward(_, questID)
    Rewards.Remove(questID)
end

local Draw = {}

function Draw:Redraw()
    self:Clear()
    Rewards.List(ids)
    for _, questID in ipairs(ids) do names[questID] = QuestName(questID):lower() end
    table.sort(ids, ByName)
    for _, questID in ipairs(ids) do
        local itemID, unconfirmed = Rewards.ItemID(questID)
        self:Add("item", itemID, QuestName(questID), unconfirmed and TEXT_UNCONFIRMED or "", RemoveReward, TEXT_REMOVE,
            nil, nil, nil, questID)
    end
    if #ids == 0 then self:Note(TEXT_EMPTY) end
    self:Fit(EVENTS)
    summary:SetText((#ids == 1 and TEXT_REWARD or TEXT_REWARDS):format(#ids))
end

local function ClearAll()
    ns.Confirm(TEXT_CLEAR_ASK, Rewards.Clear)
end

local function OnChange()
    if window and window:IsShown() then view:QueueRedraw() end
end

local function Build()
    window = Parts.Window(WIDTH, HEIGHT, "questRewardsWindow")
    window.backdrop:Card(CARD_INSET, HEADER + CARD_INSET, CARD_INSET, FOOTER + CARD_INSET)
    Parts.TitleBar(window, TEXT_TITLE, TEXT_SUBTITLE, PAGE)
    Parts.FooterBrand(window, PAGE)

    local clear = ns.Button(window, TEXT_CLEAR, CLEAR_W, CLEAR_H, ClearAll)
    clear:SetPoint("BOTTOMRIGHT", -INSET, FOOTER + PAD)
    summary = ns.Font(window, SUMMARY_SIZE, nil, T.muted)
    summary:SetPoint("LEFT", window, "BOTTOMLEFT", INSET, FOOTER + PAD + CLEAR_H / 2)
    summary:SetPoint("RIGHT", clear, "LEFT", -PAD, 0)
    summary:SetJustifyH("LEFT")

    local scroll = ns.UI.SlimScroll(window)
    scroll:SetPoint("TOPLEFT", INSET, -(HEADER + PAD))
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR - SCROLL_GAP, FOOTER + PAD + BOTTOM_H)
    view = View.New(scroll, View.NewKinds(), Draw)
    view:SetWidth(WIDTH - INSET - SCROLLBAR - PAD - VIEW_SPARE)
    scroll:SetScrollChild(view)
    Rewards.OnChange(OnChange)
end

function ns.OpenQuestRewards()
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window:Show()
    window.backdrop:Paint(1)
    view:Redraw()
end

Shared.Settings.Page(PAGE, ns.QoLSettings):Window({
    order = 12,
    text = "Open Saved Rewards",
    open = ns.OpenQuestRewards,
    headline = "Saved Quest Rewards",
    detail = "Every reward this class saved for a quest, to look over and remove.",
})

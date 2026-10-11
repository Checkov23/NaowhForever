-- BossQuestRows.lua: the dungeon quests that need a boss, as rows on its page or chips on its compact page.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Quests = J.Quests
local Kinds, Parts = J.View.Kinds, J.View.Parts
local WHERE = J.C.QUEST.WHERE
local St = J.Style
local QUEST_CODE, HAVE_RGB, CHECK, BORDER_RGB = St.QUEST_CODE, St.HAVE_RGB, St.CHECK, St.BORDER_RGB
local CHIP_H, CHIP_PAD, CHIP_GAP = St.CHIP_H, St.CHIP_PAD, St.CHIP_GAP
local TEXT_SIZE, SMALL_SIZE, HOVER = St.TEXT_SIZE, St.SMALL_SIZE, St.ITEM_HOVER

local MARK = 14
local QUEST_H = 22
local STATE_W = 120
local TICK_GAP = 4
local STATE_GAP = 6
local CHIP_FILL = 0.04
local STATE = {
    prereq = ns.L("Prerequisite"), prereqLog = ns.L("Prerequisite"), low = ns.L("Level %d to pick up"), pickup = ns.L("To pick up"),
    next = ns.L("Next step"), active = ns.L("In log"), ready = ns.L("Complete"), done = ns.L("Done"),
}

local TEXT_QUESTS = ns.L("QUESTS")
local TEXT_CODE_END = "|r"

local function NameText(quest, kind)
    return (QUEST_CODE[kind] or "") .. Quests.Name(quest) .. TEXT_CODE_END
end

local function StateText(quest, kind)
    local state = STATE[kind]
    if kind == "low" then state = state:format(Quests.MinLevel(quest) or 0) end
    return state
end

local function ShowQuest(owner, quest, anchor)
    GameTooltip:SetOwner(owner, anchor)
    GameTooltip:SetText(Quests.Name(quest), 1, 1, 1)
    GameTooltip:AddLine(quest[WHERE], T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function QuestEnter(row)
    row.hover:Show()
    ShowQuest(row, row.quest, "ANCHOR_RIGHT")
end

local function HideHover(frame)
    frame.hover:Hide()
    GameTooltip:Hide()
end

local function ChipEnter(chip)
    chip.hover:Show()
    ShowQuest(chip, chip.quest, "ANCHOR_TOP")
end

local function QuestChip(row)
    local chip = CreateFrame("Frame", nil, row)
    chip:SetHeight(CHIP_H)
    ns.Solid(chip, "BACKGROUND", T.fg, CHIP_FILL):SetAllPoints()
    chip.hover = ns.Solid(chip, "BACKGROUND", T.fg, HOVER)
    chip.hover:SetAllPoints()
    chip.hover:Hide()
    ns.Border(chip, BORDER_RGB)
    chip.name = ns.Font(chip, SMALL_SIZE)
    chip.name:SetPoint("LEFT", CHIP_PAD, 0)
    chip.name:SetJustifyH("LEFT")
    chip.name:SetWordWrap(false)
    chip.state = ns.Font(chip, SMALL_SIZE, nil, T.muted)
    chip.state:SetPoint("LEFT", chip.name, "RIGHT", STATE_GAP, 0)
    chip.state:SetWordWrap(false)
    chip:EnableMouse(true)
    chip:SetScript("OnEnter", ChipEnter)
    chip:SetScript("OnLeave", HideHover)
    return chip
end

local function SetChip(chip, quest, room)
    chip.quest = quest
    local kind = Quests.Kind(quest)
    chip.name:SetWidth(0)
    chip.name:SetText(NameText(quest, kind))
    chip.state:SetText(StateText(quest, kind))
    local color = kind == "done" and HAVE_RGB or T.muted
    chip.state:SetTextColor(color.r, color.g, color.b)
    local stateW = math.ceil(chip.state:GetStringWidth())
    local nameW = math.min(math.ceil(chip.name:GetStringWidth()) + 1, room - CHIP_PAD * 2 - STATE_GAP - stateW)
    chip.name:SetWidth(math.max(1, nameW))
    local w = CHIP_PAD * 2 + nameW + STATE_GAP + stateW
    chip:SetWidth(w)
    return w
end

Kinds.bossQuest = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.hover = Parts.CardBand(row, HOVER)
        row.hover:Hide()
        row.state = ns.Font(row, SMALL_SIZE, nil, T.muted)
        row.state:SetPoint("RIGHT", 0, 0)
        row.state:SetJustifyH("RIGHT")
        row.tick = row:CreateTexture(nil, "ARTWORK")
        row.tick:SetTexture(CHECK)
        row.tick:SetSize(MARK, MARK)
        row.tick:SetPoint("RIGHT", row.state, "LEFT", -TICK_GAP, 0)
        row.name = ns.Font(row, TEXT_SIZE)
        row.name:SetPoint("LEFT", 0, 0)
        row.name:SetPoint("RIGHT", -STATE_W, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row:EnableMouse(true)
        row:SetScript("OnEnter", QuestEnter)
        row:SetScript("OnLeave", HideHover)
        return row
    end,
    Set = function(row, quest)
        row.quest = quest
        local kind = Quests.Kind(quest)
        row.name:SetText(NameText(quest, kind))
        row.state:SetText(StateText(quest, kind))
        local done = kind == "done"
        row.tick:SetShown(done)
        local color = done and HAVE_RGB or T.muted
        row.state:SetTextColor(color.r, color.g, color.b)
        return QUEST_H
    end,
}

Kinds.questChips = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.label = ns.Font(row, TEXT_SIZE, nil, T.accentSoft)
        row.label:SetPoint("LEFT", row, "TOPLEFT", 0, -CHIP_H / 2)
        row.label:SetText(TEXT_QUESTS)
        row.chips = {}
        return row
    end,
    Set = function(row, list)
        local width = row:GetWidth()
        local start = math.ceil(row.label:GetStringWidth()) + CHIP_GAP * 2
        local x, y = start, 0
        for i = 1, #list do
            local chip = row.chips[i] or QuestChip(row)
            row.chips[i] = chip
            local w = SetChip(chip, list[i], width - start)
            if x + w > width and x > start then x, y = start, y + CHIP_H + CHIP_GAP end
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", x, -y)
            chip:Show()
            x = x + w + CHIP_GAP
        end
        for i = #list + 1, #row.chips do row.chips[i]:Hide() end
        return y + CHIP_H
    end,
}

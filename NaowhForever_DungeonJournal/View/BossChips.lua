-- BossChips.lua: the bosses with nothing for you, as chips at the end of a dungeon's page, and the x that shows them.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local S = J.Settings
local Kinds = J.View.Kinds
local Parts = J.View.Parts
local Tip = Parts.Tip
local St = J.Style
local TIP_RGB, INFO, BORDER_RGB, CROSS = St.TIP_RGB, St.INFO, St.BORDER_RGB, St.CROSS
local CHIP_H, CHIP_PAD, CHIP_GAP, SMALL_SIZE = St.CHIP_H, St.CHIP_PAD, St.CHIP_GAP, St.SMALL_SIZE

local CHIP_FILL = 0.04
local CHIP_ICON, CHIP_ICON_GAP = 12, 5
local CHIP_TIP_W = 17
local CHIP_BOTTOM = 4
local CLEAR_ICON = 10
local CLEAR_BOX = 18
local CLEAR_DROP = 1

local TEXT_SHOW_LOOT = ns.L("Show their loot")
local TEXT_TURNS_OFF = ns.L("Turns off %s.")
local TEXT_BLANK = " "

local function ChipEnter(chip)
    chip.label:SetTextColor(T.fg.r, T.fg.g, T.fg.b)
    if not Tip(chip, "ANCHOR_TOP") then return end
    GameTooltip:SetText(chip.boss.name, 1, 1, 1)
    GameTooltip:AddLine(chip.reason, T.muted.r, T.muted.g, T.muted.b)
    if chip.tip then
        GameTooltip:AddLine(TEXT_BLANK)
        Parts.AddTip(chip.tip)
    end
    GameTooltip:Show()
end

local function ChipLeave(chip)
    chip.label:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Hide()
end

local function BossChip(row)
    local chip = CreateFrame("Button", nil, row)
    chip:SetHeight(CHIP_H)
    ns.Solid(chip, "BACKGROUND", T.fg, CHIP_FILL):SetAllPoints()
    ns.Border(chip, BORDER_RGB)
    chip.label = ns.Font(chip, SMALL_SIZE, nil, T.muted)
    chip.label:SetPoint("LEFT", CHIP_PAD, 0)
    chip.icon = chip:CreateTexture(nil, "ARTWORK")
    chip.icon:SetTexture(INFO)
    chip.icon:SetSize(CHIP_ICON, CHIP_ICON)
    chip.icon:SetPoint("LEFT", chip.label, "RIGHT", CHIP_ICON_GAP, 0)
    chip.icon:SetVertexColor(TIP_RGB.r, TIP_RGB.g, TIP_RGB.b)
    chip:SetScript("OnEnter", ChipEnter)
    chip:SetScript("OnLeave", ChipLeave)
    chip:SetScript("OnClick", Parts.OpenTipMenu)
    return chip
end

local function OptionLabel(key)
    for _, group in ipairs(J.OPTION_GROUPS) do
        for _, option in ipairs(group.options) do
            if option.key == key then return option.label end
        end
    end
    return key
end

local function ClearEnter(button)
    button.icon:SetVertexColor(T.accent.r, T.accent.g, T.accent.b)
    if not Tip(button, "ANCHOR_TOP") then return end
    GameTooltip:SetText(TEXT_SHOW_LOOT, 1, 1, 1)
    GameTooltip:AddLine(TEXT_TURNS_OFF:format(OptionLabel(button.filterKey)), T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Show()
end

local function ClearLeave(button)
    button.icon:SetVertexColor(T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Hide()
end

local function ClearClicked(button)
    GameTooltip:Hide()
    S.Set(button.filterKey, false)
end

local function NewClear(row)
    local clear = CreateFrame("Button", nil, row)
    clear:SetSize(CLEAR_BOX, CLEAR_BOX)
    clear:SetPoint("LEFT", row.title, "RIGHT", 0, -CLEAR_DROP)
    clear.icon = clear:CreateTexture(nil, "ARTWORK")
    clear.icon:SetTexture(CROSS)
    clear.icon:SetSize(CLEAR_ICON, CLEAR_ICON)
    clear.icon:SetPoint("CENTER")
    clear.icon:SetVertexColor(T.muted.r, T.muted.g, T.muted.b)
    clear:SetScript("OnEnter", ClearEnter)
    clear:SetScript("OnLeave", ClearLeave)
    clear:SetScript("OnClick", ClearClicked)
    return clear
end

local function SetChip(row, i, boss, label, title, showTips)
    local chip = row.chips[i] or BossChip(row)
    row.chips[i] = chip
    chip.boss, chip.reason = boss, title
    chip.tip = showTips and J.Tip(boss) or nil
    chip.label:SetText(label)
    chip.icon:SetShown(chip.tip ~= nil)
    local w = CHIP_PAD * 2 + math.ceil(chip.label:GetStringWidth()) + (chip.tip and CHIP_TIP_W or 0)
    chip:SetWidth(w)
    return chip, w
end

Kinds.skipped = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.title = ns.Font(row, SMALL_SIZE, nil, T.muted)
        row.clear = NewClear(row)
        row.chips = {}
        return row
    end,
    Set = function(row, title, filterKey, bosses, labels)
        local showTips = row:GetParent().showTips
        row.title:ClearAllPoints()
        row.title:SetPoint("LEFT", row, "TOPLEFT", 0, -CHIP_H / 2)
        row.title:SetText(title)
        row.clear.filterKey = filterKey
        local width = row:GetWidth()
        local x, y = math.ceil(row.title:GetStringWidth()) + CLEAR_BOX + CHIP_GAP, 0
        for i = 1, #bosses do
            local chip, w = SetChip(row, i, bosses[i], labels[i], title, showTips)
            if x + w > width and x > 0 then x, y = 0, y + CHIP_H + CHIP_GAP end
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", x, -y)
            chip:Show()
            x = x + w + CHIP_GAP
        end
        for i = #bosses + 1, #row.chips do row.chips[i]:Hide() end
        return y + CHIP_H + CHIP_BOTTOM
    end,
}

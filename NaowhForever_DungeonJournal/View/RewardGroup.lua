-- RewardGroup.lua: a kind of reward inside a standing's card (gear, recipes, the rest), folding recipes on a click.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Kinds, Parts = J.View.Kinds, J.View.Parts
local St = J.Style
local RULE_ALPHA, TINY_SIZE = St.RULE_ALPHA, St.TINY_SIZE
local ICON_CROP_LOW, ICON_CROP_HIGH = St.ICON_CROP, St.ICON_CROP_HIGH

local KIND_ICONS = { "Interface\\Icons\\INV_Chest_Chain_05", "Interface\\Icons\\INV_Scroll_03",
    "Interface\\Icons\\INV_Misc_Bag_08" }
local GROUP_H, GROUP_ICON, GROUP_ARROW = 22, 14, 10
local ARROW_LEFT, ARROW_GAP = -2, 2
local ICON_GAP, LINE_GAP = 6, 8
local OPEN_TURN = St.OPEN_TURN

local TEXT_COUNT = "   "

local function GroupColor(row, color)
    row.label:SetTextColor(color.r, color.g, color.b)
    row.arrow:SetVertexColor(color.r, color.g, color.b)
end

local function GroupEnter(row)
    GroupColor(row, T.fg)
end

local function GroupLeave(row)
    GroupColor(row, T.accentSoft)
end

local function GroupClicked(row)
    if row.onToggle then row.onToggle(row) end
end

Kinds.group = {
    New = function(view)
        local row = CreateFrame("Button", nil, view)
        row.arrow = Parts.Arrow(row, GROUP_ARROW, T.accentSoft)
        row.arrow:SetPoint("LEFT", ARROW_LEFT, 0)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(GROUP_ICON, GROUP_ICON)
        row.icon:SetTexCoord(ICON_CROP_LOW, ICON_CROP_HIGH, ICON_CROP_LOW, ICON_CROP_HIGH)
        row.label = ns.Font(row, TINY_SIZE, nil, T.accentSoft)
        row.label:SetPoint("LEFT", row.icon, "RIGHT", ICON_GAP, 0)
        row.line = ns.Solid(row, "ARTWORK", T.line, RULE_ALPHA)
        row.line:SetPoint("LEFT", row.label, "RIGHT", LINE_GAP, 0)
        row.line:SetPoint("RIGHT")
        ns.Hairline(row.line, "h")
        row:SetScript("OnClick", GroupClicked)
        row:SetScript("OnEnter", GroupEnter)
        row:SetScript("OnLeave", GroupLeave)
        return row
    end,
    Set = function(row, kind, title, count, open, onToggle)
        row.onToggle = onToggle
        row:EnableMouse(onToggle ~= nil)
        row.arrow:SetShown(onToggle ~= nil)
        row.arrow:SetRotation(open and OPEN_TURN or 0)
        row.icon:ClearAllPoints()
        row.icon:SetPoint("LEFT", onToggle and GROUP_ARROW + ARROW_GAP or 0, 0)
        row.icon:SetTexture(KIND_ICONS[kind])
        row.label:SetText(ns.Upper(ns.L(title)) .. TEXT_COUNT .. ns.Color("muted", count))
        GroupColor(row, T.accentSoft)
        return GROUP_H
    end,
}

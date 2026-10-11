-- Summary.lua: how many of your BiS are yours, the filter, and a bar of your slots, pinned over the list.
local ns = _G.NaowhForever

local T = ns.THEME
local B = ns.BiS
local R = B.Rankings
local Shared = ns.Shared
local Items, Parts = Shared.Items, Shared.Parts
local Tip = Parts.Tip
local St = B.Style

local INSET = St.STATUS_W
local FILTER_W = St.FILTER_W
local SEGMENT_H, SEGMENT_GAP = 8, 2
local SEGMENT_TOP = St.TAB_H + 12
local SUMMARY_H = SEGMENT_TOP + SEGMENT_H + 14
local COUNT_Y = 2
local LABEL_X, LABEL_Y = 6, 2
local EMPTY_ALPHA = 0.35
local HAVE_RGB, TITLE_RGB = St.HAVE_RGB, St.TIP_TITLE_RGB
local TEXT_BIS_YOURS = "BiS yours"
local TEXT_STAR_GAP = "|r  "
local STAR_MARK = Parts.RankMark(1, Parts.CARD_DROP)
local FILTER_ITEMS = {
    { key = "all", word = "All", tip = "Every slot." },
    { key = "get", word = "To get", tip = "Your BiS you do not have yet: where to go next." },
    { key = "wear", word = "In bag", tip = "Your BiS in your bags or bank: put it on." },
    { key = "enchant", word = "To enchant", tip = "What you wear that takes a better enchant for your level." },
}
local STATE_WORDS = { worn = "You wear it", kept = "In your bags or bank", get = "Not yours yet",
    none = "Nothing picked" }

local FilterLabel = B.View.Memo("%s %d")

local function SegmentEnter(segment)
    local slot, bis = segment.slot, segment.bis
    if not Tip(segment, "ANCHOR_BOTTOM") then return end
    GameTooltip:SetText(Items.SlotName(slot), TITLE_RGB.r, TITLE_RGB.g, TITLE_RGB.b)
    if bis then GameTooltip:AddLine(Items.QualityHex(bis) .. Items.Name(bis) .. TEXT_STAR_GAP .. STAR_MARK) end
    local color = segment.state == "worn" and HAVE_RGB or T.muted
    GameTooltip:AddLine(STATE_WORDS[segment.state], color.r, color.g, color.b)
    GameTooltip:Show()
end

local function SegmentClicked(segment)
    local view = segment:GetParent().view
    view:Light(segment.slot)
    view:ScrollTo(segment.slot)
end

local function SegmentState(slot, bis)
    if not bis then return "none" end
    if Items.Wearing(slot, bis) then return "worn" end
    return Items.Owned(bis) and "kept" or "get"
end

local function PaintSegment(segment, list)
    local bis = list.slots[segment.slot]
    local state = SegmentState(segment.slot, bis)
    segment.bis, segment.state = bis, state
    local color = state == "worn" and HAVE_RGB or state == "kept" and T.muted or T.line
    segment.fill:SetColorTexture(color.r, color.g, color.b, state == "none" and EMPTY_ALPHA or 1)
end

local function Segment(row, slot)
    local segment = CreateFrame("Button", nil, row)
    segment.slot = slot
    segment.fill = segment:CreateTexture(nil, "ARTWORK")
    segment.fill:SetAllPoints()
    segment:SetScript("OnEnter", SegmentEnter)
    segment:SetScript("OnLeave", GameTooltip_Hide)
    segment:SetScript("OnClick", SegmentClicked)
    return segment
end

local function PaintFilters(row, filter, counts)
    FILTER_ITEMS[1].label = FILTER_ITEMS[1].word
    for i = 2, #FILTER_ITEMS do
        local item = FILTER_ITEMS[i]
        item.label = FilterLabel(item.word, counts[item.key])
    end
    Parts.SetTabs(row.tabs, FILTER_ITEMS)
    Parts.PaintTabs(row.tabs, filter)
end

B.View.SUMMARY_H = SUMMARY_H

function B.View.Summary(parent, view)
    local row = CreateFrame("Frame", nil, parent)
    row.view = view
    row:SetHeight(SUMMARY_H)
    row.count = ns.Font(row, St.COUNT_SIZE, nil, T.fg)
    row.count:SetPoint("TOPLEFT", INSET, -COUNT_Y)
    row.label = ns.Font(row, St.TEXT_SIZE, nil, T.muted)
    row.label:SetPoint("BOTTOMLEFT", row.count, "BOTTOMRIGHT", LABEL_X, LABEL_Y)
    row.label:SetText(TEXT_BIS_YOURS)
    row.tabs = Parts.Tabs(row, FILTER_W, FILTER_ITEMS, function(key) view:SetFilter(key) end)
    row.tabs:SetPoint("TOPRIGHT", -INSET, 0)
    row.segments = {}
    for i, gear in ipairs(Items.GEAR_SLOTS) do row.segments[i] = Segment(row, gear[1]) end
    return row
end

function B.View.PaintSummary(row, list, filter, counts)
    local have, total = R.Had(list)
    row.count:SetText(Parts.Fraction(have, total))
    PaintFilters(row, filter, counts)
    local segments = row.segments
    local width = (row:GetWidth() - SEGMENT_GAP * (#segments - 1)) / #segments
    for i, segment in ipairs(segments) do
        segment:SetPoint("TOPLEFT", (i - 1) * (width + SEGMENT_GAP), -SEGMENT_TOP)
        segment:SetSize(width, SEGMENT_H)
        PaintSegment(segment, list)
    end
end

-- RankTrack.lua: your PvP rank this season as a track, one segment per rank, and this week's cap.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Rep = J.Reputation
local Kinds = J.View.Kinds
local St = J.Style
local PLACE_DOT = St.PLACE_DOT
local LABEL_H, BAR_TOP, BAR_PAD = St.TRACK_LABEL_H, St.TRACK_BAR_TOP, St.TRACK_PAD
local SEG_H, SEG_LABEL_TOP, SEG_LABEL_H = St.SEG_H, St.SEG_LABEL_TOP, St.SEG_LABEL_H
local LABEL_SIZE, SMALL_SIZE, TINY_SIZE = St.HEADING_SIZE, St.SMALL_SIZE, St.TINY_SIZE

local RANK_SEG_GAP = 2
local CAPPED = 0.35
local CAPPED_NUMBER = CAPPED + 0.25
local VALUE_DROP = 2
local CAP_LINE_H = 18
local ROUND_HALF = J.C.ROUND_HALF

local TEXT_TOP_RANK = ns.L("The highest rank this season")
local TEXT_NEXT = ns.L("Next  ")
local TEXT_RANK = ns.L("Rank ")
local TEXT_OF = " / "
local TEXT_CAP = ns.L("This week you can reach rank %d of %d; the faint ranks open in the weeks to come.")

local function RankSegment(row)
    local seg = {}
    seg.track = ns.Solid(row, "BORDER", T.line, 1)
    seg.track:SetHeight(SEG_H)
    seg.fill = ns.Solid(row, "ARTWORK", T.accent, 1)
    seg.fill:SetPoint("TOPLEFT", seg.track)
    seg.fill:SetPoint("BOTTOMLEFT", seg.track)
    seg.number = ns.Font(row, TINY_SIZE, nil, T.muted)
    seg.number:SetPoint("TOP", seg.track, "BOTTOM", 0, -SEG_LABEL_TOP)
    return seg
end

local function SetLabel(row, info)
    local level = info.renownLevel
    if level >= info.maxLevel then
        row.label:SetText(TEXT_TOP_RANK)
        row.value:SetText("")
        return
    end
    row.label:SetText(ns.Color("muted", TEXT_NEXT) .. TEXT_RANK .. (level + 1) .. PLACE_DOT .. Rep.RankTitle(level + 1))
    row.value:SetText(ns.Color("fg", BreakUpLargeNumbers(info.renownReputationEarned)) .. TEXT_OF
        .. BreakUpLargeNumbers(info.renownLevelThreshold))
end

local function Share(r, info)
    local level = info.renownLevel
    if r <= level then return 1 end
    if r == level + 1 then
        return math.min(1, info.renownReputationEarned / math.max(1, info.renownLevelThreshold))
    end
    return 0
end

local function SetSegment(row, seg, r, width, info)
    local top, cap = info.maxLevel, info.currentWeekProgressiveMaxLevel
    local w = r == top and row:GetWidth() - (r - 1) * (width + RANK_SEG_GAP) or width
    seg.track:ClearAllPoints()
    seg.track:SetPoint("TOPLEFT", (r - 1) * (width + RANK_SEG_GAP), -(LABEL_H + BAR_TOP))
    seg.track:SetWidth(w)
    local share = Share(r, info)
    local accent = T.accent
    seg.fill:SetVertexColor(accent.r, accent.g, accent.b, 1)
    seg.fill:SetWidth(math.max(1, math.floor(w * share + ROUND_HALF)))
    seg.fill:SetShown(share > 0)
    local capped = cap > 0 and r > cap
    seg.track:SetAlpha(capped and CAPPED or 1)
    seg.number:SetText(r)
    local tint = r <= info.renownLevel and T.fg or T.muted
    seg.number:SetTextColor(tint.r, tint.g, tint.b)
    seg.number:SetAlpha(capped and CAPPED_NUMBER or 1)
    seg.track:Show()
    seg.number:Show()
end

local function HideSegment(seg)
    seg.track:Hide()
    seg.fill:Hide()
    seg.number:Hide()
end

Kinds.rankTrack = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.label = ns.Font(row, LABEL_SIZE, nil, T.accent)
        row.label:SetPoint("TOPLEFT", 0, 0)
        row.value = ns.Font(row, SMALL_SIZE, nil, T.muted)
        row.value:SetPoint("TOPRIGHT", 0, -VALUE_DROP)
        row.cap = ns.Font(row, SMALL_SIZE, nil, T.muted)
        row.cap:SetPoint("TOPLEFT", 0, -(LABEL_H + BAR_TOP + SEG_H + SEG_LABEL_TOP + SEG_LABEL_H))
        row.segments = {}
        return row
    end,
    Set = function(row, info)
        local top, cap = info.maxLevel, info.currentWeekProgressiveMaxLevel
        SetLabel(row, info)
        local width = math.floor((row:GetWidth() - RANK_SEG_GAP * (top - 1)) / math.max(1, top))
        for r = 1, math.max(top, #row.segments) do
            local seg = row.segments[r]
            if r <= top then
                if not seg then
                    seg = RankSegment(row)
                    row.segments[r] = seg
                end
                SetSegment(row, seg, r, width, info)
            elseif seg then
                HideSegment(seg)
            end
        end
        local capped = cap > 0 and cap < top
        row.cap:SetText(capped and TEXT_CAP:format(cap, top) or "")
        return LABEL_H + BAR_TOP + SEG_H + SEG_LABEL_TOP + SEG_LABEL_H + (capped and CAP_LINE_H or 0) + BAR_PAD
    end,
}

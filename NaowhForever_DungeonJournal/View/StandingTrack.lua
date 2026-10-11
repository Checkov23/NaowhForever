-- StandingTrack.lua: your standing with a faction as a track, one segment per standing, each with its rewards.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Rep = J.Reputation
local Kinds, Parts = J.View.Kinds, J.View.Parts
local Tip = Parts.Tip
local St = J.Style
local PLACE_DOT, HAVE_RGB = St.PLACE_DOT, St.HAVE_RGB
local LABEL_H, BAR_TOP, BAR_PAD = St.TRACK_LABEL_H, St.TRACK_BAR_TOP, St.TRACK_PAD
local SEG_H, SEG_LABEL_TOP, SEG_LABEL_H = St.SEG_H, St.SEG_LABEL_TOP, St.SEG_LABEL_H
local LABEL_SIZE, TINY_SIZE = St.HEADING_SIZE, St.TINY_SIZE

local NEUTRAL = 4
local SEG_GAP = 3
local HERE_TINT = 0.25
local SEG_LABEL_PAD = 6
local HIT_LIFT = 4
local ROUND_HALF = J.C.ROUND_HALF

local TEXT_UNLOCKS = ns.L("%d %s for you %s here")
local TEXT_REWARD, TEXT_REWARDS = ns.L("reward"), ns.L("rewards")
local TEXT_UNLOCK_ONE, TEXT_UNLOCK_MANY = ns.L("unlocks"), ns.L("unlock")
local TEXT_NO_REWARDS = ns.L("No rewards for you here")
local TEXT_NOT_MET = ns.L("You have not met them yet.")
local TEXT_HERE = ns.L("You are here.")
local TEXT_REACHED = ns.L("Reached.")
local TEXT_REPUTATION = ns.L(" (reputation)")
local TEXT_NOT_MET_YET = ns.L("Not met yet")
local TEXT_FAR = "   %s"
local TEXT_OF_TO = ns.L(" / %s to %s")
local TEXT_REWARD_COUNT = ns.L(" reward")
local TEXT_REWARD_COUNTS = ns.L(" rewards")

local function RewardsLine(count)
    if count <= 0 then return TEXT_NO_REWARDS end
    return TEXT_UNLOCKS:format(count, count == 1 and TEXT_REWARD or TEXT_REWARDS,
        count == 1 and TEXT_UNLOCK_ONE or TEXT_UNLOCK_MANY)
end

local function WhereLine(s, info)
    local muted, reaction = T.muted, info.reaction
    if not reaction then return GameTooltip:AddLine(TEXT_NOT_MET, muted.r, muted.g, muted.b) end
    if reaction == s then return GameTooltip:AddLine(TEXT_HERE, muted.r, muted.g, muted.b) end
    if reaction > s then return GameTooltip:AddLine(TEXT_REACHED, HAVE_RGB.r, HAVE_RGB.g, HAVE_RGB.b) end
    local toGo, exact = Rep.ToGo(s, reaction, info.value, info.max)
    GameTooltip:AddLine(Rep.ToGoText(toGo, exact) .. TEXT_REPUTATION, muted.r, muted.g, muted.b)
end

local function SegmentEnter(hit)
    local s, info = hit.standing, hit:GetParent().info
    local color = Rep.Color(s)
    if not Tip(hit, "ANCHOR_BOTTOM") then return end
    GameTooltip:SetText(Rep.Label(s), color.r, color.g, color.b)
    GameTooltip:AddLine(RewardsLine(info.counts[s] or 0), 1, 1, 1)
    WhereLine(s, info)
    GameTooltip:Show()
end

local function Segment(row, s)
    local seg = {}
    seg.track = ns.Solid(row, "BORDER", T.line, 1)
    seg.track:SetHeight(SEG_H)
    seg.fill = row:CreateTexture(nil, "ARTWORK")
    seg.fill:SetColorTexture(1, 1, 1, 1)
    seg.fill:SetPoint("TOPLEFT", seg.track)
    seg.fill:SetPoint("BOTTOMLEFT", seg.track)
    seg.name = ns.Font(row, TINY_SIZE, nil, T.muted)
    seg.name:SetPoint("TOP", seg.track, "BOTTOM", 0, -SEG_LABEL_TOP)
    seg.name:SetWordWrap(false)
    seg.hit = CreateFrame("Frame", nil, row)
    seg.hit:SetPoint("TOPLEFT", seg.track, "TOPLEFT", 0, HIT_LIFT)
    seg.hit:SetPoint("BOTTOMRIGHT", seg.track, "BOTTOMRIGHT", 0, -(SEG_LABEL_TOP + SEG_LABEL_H))
    seg.hit:EnableMouse(true)
    seg.hit.standing = s
    seg.hit:SetScript("OnEnter", SegmentEnter)
    seg.hit:SetScript("OnLeave", GameTooltip_Hide)
    return seg
end

local function SetLabel(row, reaction, value, max)
    if not reaction then
        row.label:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
        row.label:SetText(TEXT_NOT_MET_YET)
        return
    end
    local color = Rep.Color(reaction)
    row.label:SetTextColor(color.r, color.g, color.b)
    local far = ""
    if reaction < Rep.EXALTED then
        far = TEXT_FAR:format(ns.Color("fg", BreakUpLargeNumbers(value)))
            .. ns.Color("muted", TEXT_OF_TO:format(BreakUpLargeNumbers(max), Rep.Label(reaction + 1)))
    end
    row.label:SetText(Rep.Label(reaction) .. far)
end

local function SegmentName(name, label, count, room)
    name:SetWidth(0)
    if count <= 0 then
        name:SetText(label)
    else
        name:SetText(label .. ns.Color("muted", PLACE_DOT .. count .. (count == 1 and TEXT_REWARD_COUNT or TEXT_REWARD_COUNTS)))
        if name:GetStringWidth() > room then name:SetText(label .. ns.Color("muted", PLACE_DOT .. count)) end
        if name:GetStringWidth() > room then name:SetText(label) end
    end
    name:SetWidth(math.max(1, room))
end

local function Share(s, reaction, value, max)
    if not reaction then return 0 end
    if s < reaction then return 1 end
    if s == reaction then return math.min(1, value / math.max(1, max)) end
    return 0
end

local function SetSegment(row, seg, s, i, width, info, counts)
    local reaction = info.reaction
    local w = s == Rep.EXALTED and row:GetWidth() - i * (width + SEG_GAP) or width
    seg.track:ClearAllPoints()
    seg.track:SetPoint("TOPLEFT", i * (width + SEG_GAP), -(LABEL_H + BAR_TOP))
    seg.track:SetWidth(w)
    local share = Share(s, reaction, info.value, info.max)
    local color = Rep.Color(s)
    if share > 0 then
        seg.fill:SetVertexColor(color.r, color.g, color.b, 1)
        seg.fill:SetWidth(math.max(1, math.floor(w * share + ROUND_HALF)))
        seg.fill:Show()
    end
    if s == reaction then
        seg.track:SetColorTexture(color.r, color.g, color.b, HERE_TINT)
    else
        seg.track:SetColorTexture(T.line.r, T.line.g, T.line.b, 1)
    end
    SegmentName(seg.name, Rep.Label(s), counts[s] or 0, w - SEG_LABEL_PAD)
    local tint = (reaction ~= nil and reaction >= s) and color or T.muted
    seg.name:SetTextColor(tint.r, tint.g, tint.b)
end

Kinds.track = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.label = ns.Font(row, LABEL_SIZE)
        row.label:SetPoint("TOPLEFT", 0, 0)
        row.segments = {}
        for s = 1, Rep.EXALTED do row.segments[s] = Segment(row, s) end
        row.info = { counts = {} }
        return row
    end,
    Set = function(row, reaction, value, max, counts)
        local info = row.info
        info.reaction, info.value, info.max, info.counts = reaction, value, max, counts
        SetLabel(row, reaction, value, max)
        local first = math.min(reaction or NEUTRAL, NEUTRAL)
        local n = Rep.EXALTED - first + 1
        local width = math.floor((row:GetWidth() - SEG_GAP * (n - 1)) / n)
        for s = 1, Rep.EXALTED do
            local seg = row.segments[s]
            local shown = s >= first
            seg.track:SetShown(shown)
            seg.name:SetShown(shown)
            seg.hit:SetShown(shown)
            seg.fill:SetShown(false)
            if shown then SetSegment(row, seg, s, s - first, width, info, counts) end
        end
        return LABEL_H + BAR_TOP + SEG_H + SEG_LABEL_TOP + SEG_LABEL_H + BAR_PAD
    end,
}

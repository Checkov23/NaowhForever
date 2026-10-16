-- RollBadge.lua: your star and rank over the game's roll frame for one of your picks (B.RollBadge).
local ns = _G.NaowhForever

local T = ns.THEME
local B = ns.BiS
local S = B.Settings
local A = B.Alerts
local Parts = ns.Shared.Parts
local St = B.Style

local BADGE_H, BADGE_STAR, BADGE_PAD = 20, 14, 6
local BADGE_X, BADGE_Y = 4, 2
local STAR_GAP = St.STAR_GAP
local BADGE_LIFT = 10
local STARRED = 3
local ROLL_FRAMES = 4
local ROLL_FRAME = "GroupLootFrame"
local BADGE_WORDS = { ns.L("Your BiS"), ns.L("Your second pick") }
local TEXT_PICK = ns.L("Your #%d pick")

local badges = {}

local function Badge(frame)
    local badge = badges[frame]
    if badge then return badge end
    badge = CreateFrame("Frame", nil, UIParent)
    badge:SetHeight(BADGE_H)
    badge:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", BADGE_X, BADGE_Y)
    ns.Solid(badge, "BACKGROUND", T.bg, St.CARD_ALPHA):SetAllPoints()
    ns.Border(badge, St.BORDER_RGB)
    badge.star = badge:CreateTexture(nil, "ARTWORK")
    badge.star:SetTexture(St.STAR)
    badge.star:SetSize(BADGE_STAR, BADGE_STAR)
    badge.star:SetPoint("LEFT", BADGE_PAD, 0)
    badge.text = ns.Font(badge, St.TEXT_SIZE)
    badges[frame] = badge
    return badge
end

local function Place(badge, starred)
    badge.star:SetShown(starred)
    badge.text:ClearAllPoints()
    if starred then
        badge.text:SetPoint("LEFT", badge.star, "RIGHT", STAR_GAP, 0)
    else
        badge.text:SetPoint("LEFT", BADGE_PAD, 0)
    end
end

local function Show(frame, rank)
    if not rank then
        if badges[frame] then badges[frame]:Hide() end
        return
    end
    local badge = Badge(frame)
    local color, starred = Parts.RankColor(rank), rank <= STARRED
    badge:SetFrameStrata(frame:GetFrameStrata())
    badge:SetFrameLevel(frame:GetFrameLevel() + BADGE_LIFT)
    Place(badge, starred)
    badge.star:SetVertexColor(color.r, color.g, color.b)
    badge.text:SetText(BADGE_WORDS[rank] or TEXT_PICK:format(rank))
    badge.text:SetTextColor(color.r, color.g, color.b)
    badge:SetWidth(math.ceil(badge.text:GetStringWidth()) + BADGE_PAD * 2 + (starred and BADGE_STAR + STAR_GAP or 0))
    badge:Show()
end

local function MarkRoll(frame)
    local rank = A.On() and S.Get("bisAlertBadge") and frame.rollID and A.Rank(GetLootRollItemLink(frame.rollID))
    Show(frame, A.Wanted(rank or nil) and rank or nil)
end

local function UnmarkRoll(frame)
    Show(frame, nil)
end

B.RollBadge = { Show = Show }

for i = 1, ROLL_FRAMES do
    local frame = _G[ROLL_FRAME .. i]
    if frame then
        frame:HookScript("OnShow", MarkRoll)
        frame:HookScript("OnHide", UnmarkRoll)
    end
end

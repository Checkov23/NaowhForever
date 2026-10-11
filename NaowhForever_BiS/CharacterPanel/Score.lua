-- Score.lua: the Naowh Score card: the score big, a bar to its share of the best, and the best under it (CP.ScoreCard).
local ns = _G.NaowhForever

local T = ns.THEME
local S = ns.QoLSettings
local CP = ns.CharacterPanel
local C = CP.C

local CARD_W = CP.PANE_W - 2 * CP.EDGE
local KICKER_SIZE = C.SMALL_SIZE
local VALUE_TOP, VALUE_SIZE = 13, 26
local SHADOW_ALPHA, SHADOW_X = C.SHADOW_ALPHA, C.SHADOW_X
local BAR_TOP, BAR_H = 46, 6
local LEGEND_GAP, LEGEND_SIZE = 4, C.SMALL_SIZE
local LEGEND_BOTTOM = 2
local TRACK_GREY = C.TRACK_GREY
local GOAL_RGB, BLACK_RGB = C.GOLD_RGB, C.BLACK_RGB
local TICK_W, TICK_OUT = 2, 3
local REST_LAYER, GOAL_LAYER = 2, 2
local NO_LEVEL = 0
local TENTHS = 10
local WAITING = "..."
local LEVEL_COMPARE, BOTH_COMPARE = ns.NaowhScore.COMPARE.LEVEL, ns.NaowhScore.COMPARE.BOTH
local TEXT_KICKER = ns.L("NAOWH SCORE")
local TEXT_LEVEL_BEST, TEXT_BEST = ns.L("Level %d best %%.1f"), ns.L("Best %.1f")

local legends = {}

local function Legend(ofLevel, level, best)
    local key = ofLevel and level or NO_LEVEL
    local byLevel = legends[key]
    if not byLevel then
        byLevel = {}
        legends[key] = byLevel
    end
    local tenths = math.floor(best * TENTHS + C.HALF)
    local text = byLevel[tenths]
    if not text then
        text = (ofLevel and TEXT_LEVEL_BEST:format(level) or TEXT_BEST):format(tenths / TENTHS)
        byLevel[tenths] = text
    end
    return text
end

local function PaintGoal(card, level, best)
    local goal = S.Get("naowhScoreCompare") == BOTH_COMPARE and ns.NaowhScore.Best(level)
    local show = goal and best and goal < best
    card.goal:SetShown(show and true or false)
    if not show then return end
    local x = math.floor(card.barW * goal / best + C.HALF)
    card.goal:ClearAllPoints()
    card.goal:SetPoint("CENTER", card.bar, "LEFT", x, 0)
end

local function Fill(card, x)
    local rest = card.rest
    rest:ClearAllPoints()
    rest:SetPoint("TOPLEFT", card.bar, "TOPLEFT", x, 0)
    rest:SetPoint("BOTTOMRIGHT", card.bar, "BOTTOMRIGHT")
    rest:SetShown(x < card.barW)
end

local function Bar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetPoint("TOPLEFT", 0, -BAR_TOP)
    bar:SetHeight(BAR_H)
    local edge = bar:CreateTexture(nil, "BACKGROUND")
    edge:SetColorTexture(BLACK_RGB.r, BLACK_RGB.g, BLACK_RGB.b, 1)
    ns.PixelInset(edge, C.RING_OUT)
    local ramp = ns.NaowhScore.RAMP
    parent.segments = {}
    for i = 1, #ramp - 1 do
        local a, b = ramp[i], ramp[i + 1]
        local segment = bar:CreateTexture(nil, "ARTWORK")
        segment:SetColorTexture(1, 1, 1, 1)
        segment:SetGradient("HORIZONTAL", CreateColor(a[2], a[3], a[4], 1), CreateColor(b[2], b[3], b[4], 1))
        parent.segments[i] = segment
    end
    parent.rest = bar:CreateTexture(nil, "ARTWORK", nil, REST_LAYER)
    parent.rest:SetColorTexture(TRACK_GREY, TRACK_GREY, TRACK_GREY, 1)
    parent.best = ns.Font(parent, LEGEND_SIZE, nil, T.muted)
    parent.best:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -LEGEND_GAP)
    parent.goal = bar:CreateTexture(nil, "OVERLAY", nil, GOAL_LAYER)
    parent.goal:SetColorTexture(GOAL_RGB.r, GOAL_RGB.g, GOAL_RGB.b, 1)
    parent.goal:SetSize(TICK_W, BAR_H + TICK_OUT * 2)
    parent.goal:Hide()
    return bar
end

CP.BADGE_H = BAR_TOP + BAR_H + LEGEND_GAP + LEGEND_SIZE + LEGEND_BOTTOM
CP.WAITING = WAITING
CP.CARD_W, CP.LEGEND_SIZE, CP.LEGEND_GAP, CP.GOAL_RGB = CARD_W, LEGEND_SIZE, LEGEND_GAP, GOAL_RGB

function CP.PaintScoreCard(card, score, level)
    local Score = ns.NaowhScore
    card.value:SetText(Score.Colored(score, level))
    local ofLevel = S.Get("naowhScoreCompare") == LEVEL_COMPARE
    local best = Score.Best(ofLevel and level or nil)
    local share = Score.Grade(score, level) or 0
    Fill(card, math.floor(card.barW * math.min(1, share) + C.HALF))
    card.best:SetText(best and Legend(ofLevel, level, best) or "")
    PaintGoal(card, level, best)
end

function CP.ScoreCardWaiting(card)
    card.value:SetText(WAITING)
    Fill(card, 0)
    card.best:SetText("")
    card.goal:Hide()
end

function CP.SizeScoreCard(card, width)
    card.barW = width
    card:SetWidth(width)
    card.bar:SetWidth(width)
    local ramp = ns.NaowhScore.RAMP
    for i, segment in ipairs(card.segments) do
        local a, b = ramp[i], ramp[i + 1]
        segment:ClearAllPoints()
        segment:SetPoint("TOPLEFT", a[1] * width, 0)
        segment:SetSize((b[1] - a[1]) * width, BAR_H)
    end
end

function CP.ScoreCard(parent, width)
    local card = CreateFrame("Button", nil, parent)
    card:SetHeight(CP.BADGE_H)
    local kicker = ns.Font(card, KICKER_SIZE, nil, T.accentSoft)
    kicker:SetPoint("TOPLEFT")
    kicker:SetText(TEXT_KICKER)
    card.kicker = kicker
    card.value = ns.Font(card, VALUE_SIZE, nil, T.fg)
    card.value:SetPoint("TOPLEFT", 0, -VALUE_TOP)
    card.value:SetShadowColor(BLACK_RGB.r, BLACK_RGB.g, BLACK_RGB.b, SHADOW_ALPHA)
    card.value:SetShadowOffset(SHADOW_X, -SHADOW_X)
    card.bar = Bar(card)
    CP.SizeScoreCard(card, width or CARD_W)
    return card
end

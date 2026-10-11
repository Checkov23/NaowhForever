-- ScoreCard.lua: the Naowh Score card under the paperdoll: your score, your BiS's, their stats (B.View.ScoreCard).
local ns = _G.NaowhForever

local T = ns.THEME
local B = ns.BiS
local Tip = ns.Shared.Parts.Tip
local St = B.Style

local RED_CODE, UPGRADE_CODE = St.RED_CODE, St.UPGRADE_CODE
local GOAL_RGB, TITLE_RGB, EDGE_RGB = St.GOLD_RGB, St.TIP_TITLE_RGB, St.BORDER_RGB
local STAT_CELLS, COLUMNS = 4, 2
local STAT_ROW, VALUE_W = 20, 44
local GRID_GAP = 16
local BAND_PAD = 4
local VALUE_TOP, VALUE_SIZE = 13, 26
local GAIN_SIZE = 16
local WHICH_X, WHICH_Y = 6, 3
local GAIN_Y = 1
local OTHER_X, OTHER_Y = 6, 1
local BAR_TOP, BAR_H = 48, 8
local TICK_W, TICK_OUT = 2, 3
local LEGEND_GAP = 4
local LEGEND_MIN = 90
local LEGEND_HALF = 40
local GRID_TOP = 82
local CARD_H = 120
local GAIN_ALPHA = 0.5
local TRACK_GREY = 0.16
local SCALE_ROOM = 1.25
local SHOWN_GAIN = 0.05
local TENTHS = 10
local ROUND = B.C.ROUND
local MIN_CUT = 2
local UNORDERED = 1000
local EDGE_OUT = -1
local SHADE_LAYER, REST_LAYER, GOAL_LAYER = 2, 3, 2
local STAT_ORDER = { "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STAMINA_SHORT",
    "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT",
    "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
    "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_MANA_REGENERATION_SHORT",
    "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", "ITEM_MOD_DODGE_RATING_SHORT", "ITEM_MOD_PARRY_RATING_SHORT",
    "ITEM_MOD_BLOCK_RATING_SHORT", "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", "RESISTANCE0_NAME" }
local TEXT_KICKER = ns.L("NAOWH SCORE")
local TEXT_PICK_BIS = ns.L("Pick your BiS")
local TEXT_NOW, TEXT_WITH_BIS = ns.L("now"), ns.L("with your BiS")
local TEXT_GAIN, TEXT_FROM = "+%.1f", ns.L("from %.1f")
local TEXT_BIS_AFTER, TEXT_NOW_AFTER = ns.L("%.1f with your BiS"), ns.L("%.1f now")
local TEXT_LEVEL_BEST, TEXT_BEST = ns.L("Level %d best %%.1f"), ns.L("Best %.1f")
local TEXT_LEVEL_GOAL = ns.L("Level %d goal %%.1f")
local TEXT_WHOLE = ns.L("You wear your whole BiS.")
local TIP_TITLE = "Naowh Score"
local TIP_NOW, TIP_WITH_BIS = ns.L("Now"), ns.L("With your BiS")
local TIP_GOAL = ns.L("Level %d goal")
local TIP_BEST_LEVEL, TIP_BEST_GAME = ns.L("Best for your level"), ns.L("Best in the game")
local TIP_ABOUT = ns.L("Filled to what you wear, dimmer on to your BiS. A level's goal is a full set of blues for it.")
local LEVEL_COMPARE, BOTH_COMPARE = ns.NaowhScore.COMPARE.LEVEL, ns.NaowhScore.COMPARE.BOTH

local CORE = {}
for i, key in ipairs(STAT_ORDER) do CORE[key] = i end

local shown = {}
local worthOf = {}
local scoreTexts = {}

local function ByOrder(a, b)
    local oa, ob = CORE[a] or UNORDERED, CORE[b] or UNORDERED
    if oa ~= ob then return oa < ob end
    return a < b
end

local function ByWorth(a, b)
    local wa, wb = math.abs(worthOf[a]), math.abs(worthOf[b])
    if wa ~= wb then return wa > wb end
    return ByOrder(a, b)
end

local function Amount(value)
    local amount = math.abs(value)
    local text = amount % 1 == 0 and ("%d"):format(amount) or ("%.1f"):format(amount)
    return (value > 0 and UPGRADE_CODE .. "+" or RED_CODE .. "-") .. text .. "|r"
end

local function StatName(key)
    return ns.StatWeights.KeyName(key) or _G[key] or key
end

local function Offer(key, value, weights)
    if not weights then
        if CORE[key] then shown[#shown + 1] = key end
        return
    end
    local worth = ns.StatWeights.KeyWorth(key, value, weights)
    if worth == 0 then return end
    worthOf[key] = worth
    shown[#shown + 1] = key
end

local function Shown(stats)
    wipe(shown)
    wipe(worthOf)
    local spec = B.Lists.CurrentSpec()
    local weights = spec and ns.StatWeights.For(spec.key)
    for key, value in pairs(stats) do
        if value ~= 0 then Offer(key, value, weights) end
    end
    table.sort(shown, weights and ByWorth or ByOrder)
end

local function ScoreText(format, score)
    local tenths = math.floor(score * TENTHS + ROUND)
    local byFormat = scoreTexts[format]
    if not byFormat then
        byFormat = {}
        scoreTexts[format] = byFormat
    end
    local text = byFormat[tenths]
    if not text then
        text = format:format(tenths / TENTHS)
        byFormat[tenths] = text
    end
    return text
end

local function Scale(level, now, bis)
    local Score = ns.NaowhScore
    local compare = ns.QoLSettings.Get("naowhScoreCompare")
    local goal = Score.Best(level)
    local top = Score.Best(compare == LEVEL_COMPARE and level or nil)
    if not top then top = math.max(bis, now, goal or 0) * SCALE_ROOM end
    if compare ~= BOTH_COMPARE or not goal or goal >= top then goal = nil end
    return top, goal, compare == LEVEL_COMPARE
end

local function Stretch(texture, x, x2)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", x, 0)
    texture:SetPoint("BOTTOMLEFT", x, 0)
    texture:SetWidth(math.max(1, x2 - x))
    texture:SetShown(x2 - x >= 1)
end

local function BarX(score, top, width)
    return math.floor(math.min(1, score / top) * width + ROUND)
end

local function PaintEmpty(card)
    card.value:SetText(ns.Color("muted", TEXT_PICK_BIS))
    card.which:SetText("")
    card.other:SetText("")
    card.gain:SetText("")
    card.bar:Hide()
end

local function PaintHeader(card, now, bis, level)
    local onNow = card.look == "now"
    card.value:SetText(ns.NaowhScore.Colored(onNow and now or bis, level))
    card.which:SetText(onNow and TEXT_NOW or TEXT_WITH_BIS)
    local gain = bis - now
    if gain >= SHOWN_GAIN then
        card.gain:SetText(UPGRADE_CODE .. ScoreText(TEXT_GAIN, gain) .. "|r")
        card.other:SetText(onNow and TEXT_WITH_BIS or ScoreText(TEXT_FROM, now))
    else
        card.gain:SetText("")
        card.other:SetText(onNow and ScoreText(TEXT_BIS_AFTER, bis) or ScoreText(TEXT_NOW_AFTER, now))
    end
end

local function PaintGoal(bar, goal, top, width, level)
    local xGoal = goal and BarX(goal, top, width)
    bar.goal:SetShown(xGoal ~= nil)
    bar.goalLabel:SetShown(xGoal ~= nil and width - xGoal >= LEGEND_MIN)
    if not xGoal then return end
    bar.goal:ClearAllPoints()
    bar.goal:SetPoint("CENTER", bar, "LEFT", xGoal, 0)
    bar.goalLabel:ClearAllPoints()
    bar.goalLabel:SetPoint("TOP", bar, "BOTTOMLEFT", math.max(LEGEND_HALF, xGoal), -LEGEND_GAP)
    bar.goalLabel:SetText(ScoreText(TEXT_LEVEL_GOAL:format(level), goal))
end

local function PaintBar(card, now, bis, level)
    local bar = card.bar
    local top, goal, ofLevel = Scale(level, now, bis)
    if top <= 0 then
        bar:Hide()
        return
    end
    local width = card.w
    local xNow, xBis = BarX(now, top, width), BarX(math.max(bis, now), top, width)
    Stretch(bar.gain, xNow, xBis)
    Stretch(bar.rest, xBis, width)
    bar.cut:ClearAllPoints()
    bar.cut:SetPoint("TOPLEFT", xNow, 0)
    bar.cut:SetPoint("BOTTOMLEFT", xNow, 0)
    bar.cut:SetShown(xNow > 0 and xBis - xNow >= MIN_CUT)
    bar.topLabel:SetText(ofLevel and ScoreText(TEXT_LEVEL_BEST:format(level), top) or ScoreText(TEXT_BEST, top))
    PaintGoal(bar, goal, top, width, level)
    bar.values[1], bar.values[2], bar.values[3], bar.values[4] = now, bis, goal or 0, top
    bar.ofLevel = ofLevel
    bar:Show()
end

local function PaintScore(card)
    local gains = card.gains
    local now, bis = gains.now or 0, gains.bis or 0
    if bis == 0 then return PaintEmpty(card) end
    local level = UnitLevel("player")
    PaintHeader(card, now, bis, level)
    PaintBar(card, now, bis, level)
end

local function BarEnter(bar)
    if not Tip(bar, "ANCHOR_TOP") then return end
    local values, Text = bar.values, ns.NaowhScore.Text
    local m, w = T.muted, TITLE_RGB
    GameTooltip:SetText(TIP_TITLE, w.r, w.g, w.b)
    GameTooltip:AddDoubleLine(TIP_NOW, Text(values[1]), m.r, m.g, m.b, w.r, w.g, w.b)
    GameTooltip:AddDoubleLine(TIP_WITH_BIS, Text(values[2]), m.r, m.g, m.b, w.r, w.g, w.b)
    if values[3] > 0 then
        GameTooltip:AddDoubleLine(TIP_GOAL:format(UnitLevel("player")), Text(values[3]),
            GOAL_RGB.r, GOAL_RGB.g, GOAL_RGB.b, w.r, w.g, w.b)
    end
    GameTooltip:AddDoubleLine(bar.ofLevel and TIP_BEST_LEVEL or TIP_BEST_GAME, Text(values[4]),
        m.r, m.g, m.b, w.r, w.g, w.b)
    GameTooltip:AddLine(TIP_ABOUT, m.r, m.g, m.b, true)
    GameTooltip:Show()
end

local function Ramp(bar, width)
    local ramp = ns.NaowhScore.RAMP
    for i = 1, #ramp - 1 do
        local a, b = ramp[i], ramp[i + 1]
        local segment = bar:CreateTexture(nil, "ARTWORK")
        segment:SetColorTexture(1, 1, 1, 1)
        segment:SetGradient("HORIZONTAL", CreateColor(a[2], a[3], a[4], 1), CreateColor(b[2], b[3], b[4], 1))
        segment:SetPoint("TOPLEFT", a[1] * width, 0)
        segment:SetSize((b[1] - a[1]) * width, BAR_H)
    end
end

local function Marks(bar)
    bar.gain = bar:CreateTexture(nil, "ARTWORK", nil, SHADE_LAYER)
    bar.gain:SetColorTexture(EDGE_RGB.r, EDGE_RGB.g, EDGE_RGB.b, GAIN_ALPHA)
    bar.rest = bar:CreateTexture(nil, "ARTWORK", nil, REST_LAYER)
    bar.rest:SetColorTexture(TRACK_GREY, TRACK_GREY, TRACK_GREY, 1)
    bar.cut = bar:CreateTexture(nil, "OVERLAY")
    bar.cut:SetColorTexture(EDGE_RGB.r, EDGE_RGB.g, EDGE_RGB.b, 1)
    ns.Hairline(bar.cut, "v")
    bar.goal = bar:CreateTexture(nil, "OVERLAY", nil, GOAL_LAYER)
    bar.goal:SetColorTexture(GOAL_RGB.r, GOAL_RGB.g, GOAL_RGB.b, 1)
    bar.goal:SetSize(TICK_W, BAR_H + TICK_OUT * 2)
end

local function Bar(card)
    local bar = CreateFrame("Frame", nil, card)
    bar:SetPoint("TOPLEFT", 0, -BAR_TOP)
    bar:SetPoint("TOPRIGHT", 0, -BAR_TOP)
    bar:SetHeight(BAR_H)
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", BarEnter)
    bar:SetScript("OnLeave", GameTooltip_Hide)
    bar.values = { 0, 0, 0, 0 }
    local edge = bar:CreateTexture(nil, "BACKGROUND")
    edge:SetColorTexture(EDGE_RGB.r, EDGE_RGB.g, EDGE_RGB.b, 1)
    ns.PixelInset(edge, EDGE_OUT)
    Ramp(bar, card.w)
    Marks(bar)
    bar.goalLabel = ns.Font(bar, St.SMALL_SIZE, nil, GOAL_RGB)
    bar.goalLabel:SetJustifyH("CENTER")
    bar.topLabel = ns.Font(bar, St.SMALL_SIZE, nil, T.muted)
    bar.topLabel:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -LEGEND_GAP)
    bar:Hide()
    return bar
end

local function GridBands(grid, lines)
    for line = 1, lines do
        local y = -(line - 1) * STAT_ROW + BAND_PAD
        local band = ns.Solid(grid, "BACKGROUND", T.fg, St.STRIPE)
        band:SetPoint("TOPLEFT", -BAND_PAD, y)
        band:SetPoint("TOPRIGHT", BAND_PAD, y)
        band:SetHeight(STAT_ROW)
        grid.bands[line] = band
    end
end

local function GridCell(grid, i, columns, column)
    local x = ((i - 1) % columns) * column
    local y = -math.floor((i - 1) / columns) * STAT_ROW
    local name = ns.Font(grid, St.TEXT_SIZE, nil, T.muted)
    name:SetPoint("TOPLEFT", x, y)
    name:SetWidth(column - VALUE_W - GRID_GAP)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    local value = ns.Font(grid, St.TEXT_SIZE)
    local last = i % columns == 0
    value:SetPoint("TOPRIGHT", grid, "TOPLEFT", last and x + column or x + column - GRID_GAP, y)
    value:SetJustifyH("RIGHT")
    return { name = name, value = value }
end

local function Grid(card, width, columns)
    local grid = CreateFrame("Frame", nil, card)
    local lines = STAT_CELLS / columns
    grid:SetSize(width, lines * STAT_ROW)
    grid:SetPoint("TOPLEFT", 0, -GRID_TOP)
    grid.columns, grid.cells, grid.bands = columns, {}, {}
    GridBands(grid, lines)
    local column = width / columns
    for i = 1, STAT_CELLS do grid.cells[i] = GridCell(grid, i, columns, column) end
    grid.whole = ns.Font(grid, St.TEXT_SIZE, nil, T.muted)
    grid.whole:SetPoint("TOPLEFT", 0, 0)
    grid.whole:SetText(TEXT_WHOLE)
    grid.whole:Hide()
    return grid
end

local function PaintGrid(grid, gains)
    for i, cell in ipairs(grid.cells) do
        local key = shown[i]
        cell.name:SetText(key and StatName(key) or "")
        cell.value:SetText(key and Amount(ns.StatWeights.KeyAmount(key, gains.stats[key])) or "")
    end
    for line, band in ipairs(grid.bands) do
        band:SetShown(line % 2 == 1 and shown[(line - 1) * grid.columns + 1] ~= nil)
    end
    grid.whole:SetShown(gains.bis > 0 and #shown == 0)
end

function B.View.PaintScoreCard(card, list, look)
    card.look = look
    local gains = B.Gains.Read(list, card.gains)
    Shown(gains.stats)
    PaintGrid(card.grid, gains)
    PaintScore(card)
    return gains
end

function B.View.PaintScoreLook(card, look)
    card.look = look
    PaintScore(card)
end

function B.View.ScoreCard(parent, width)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(width, CARD_H)
    card.w, card.look = width, "bis"
    card.gains = { stats = {} }
    local kicker = ns.Font(card, St.TINY_SIZE, nil, T.accentSoft)
    kicker:SetPoint("TOPLEFT", 0, 0)
    kicker:SetText(TEXT_KICKER)
    card.value = ns.Font(card, VALUE_SIZE, nil, T.fg)
    card.value:SetPoint("TOPLEFT", 0, -VALUE_TOP)
    card.which = ns.Font(card, St.TEXT_SIZE, nil, T.muted)
    card.which:SetPoint("BOTTOMLEFT", card.value, "BOTTOMRIGHT", WHICH_X, WHICH_Y)
    card.gain = ns.Font(card, GAIN_SIZE)
    card.gain:SetPoint("BOTTOMRIGHT", card.value, "BOTTOMLEFT", width, GAIN_Y)
    card.other = ns.Font(card, St.TEXT_SIZE, nil, T.muted)
    card.other:SetPoint("BOTTOMRIGHT", card.gain, "BOTTOMLEFT", -OTHER_X, OTHER_Y)
    card.bar = Bar(card)
    card.grid = Grid(card, width, COLUMNS)
    return card
end

B.View.SCORE_CARD_H = CARD_H

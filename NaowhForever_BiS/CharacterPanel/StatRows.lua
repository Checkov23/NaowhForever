-- StatRows.lua: the stats view's heading and rows, each with its worth bar, its total and its hover card (CP.StatRows).
local ns = _G.NaowhForever

local T = ns.THEME
local CP = ns.CharacterPanel
local C = CP.C
local D = CP.Stats
local Worth = CP.Worth
local Parts = ns.Shared.Parts
local Totals = CP.Totals

local EDGE, PANE_W = CP.EDGE, CP.PANE_W
local STRIPE = ns.Shared.Style.STRIPE
local CONTENT_W = PANE_W - 2 * EDGE
local ROWS = C.STAT_ROWS
local SECTION_TOP = 12
local TITLE_SIZE, HEAD_SIZE = C.SECTION_SIZE, C.SMALL_SIZE
local LINE_Y = SECTION_TOP + 16
local HEAD_GAP = 5
local ROWS_TOP = LINE_Y + 20
local ROWS_BOTTOM = 4
local ROW_MAX, ROW_ROOMY, ROW_FLOOR = 30, 24, 12
local ROW_SIZE, ROW_SIZE_TIGHT = 13, C.TEXT_SIZE
local VALUE_W, COLUMN_GAP, NAME_GAP = 44, 10, 6
local BAR_W, BAR_H, BAR_MIN = 50, 4, 2
local NAME_W = CONTENT_W - VALUE_W - COLUMN_GAP - BAR_W - NAME_GAP
local BAR_X = NAME_W + NAME_GAP
local BAND_PAD = 4
local TRACK_ALPHA = 0.08
local BAR_LAYER = 1
local BAR_DROP = Parts.CARD_DROP
local STRIPED = 1
local TITLE_RGB = C.TITLE_RGB
local YOU_LINE = ns.L("You: %s")
local TOOLTIP_LINE = "GameTooltipTextLeft"
local BLANK = " "
local TEXT_YOU = ns.L("YOU")
local TEXT_WEIGHTS = ns.L("Stat Weights")
local TEXT_WEIGHTS_HINT = ns.L("What each stat is worth to your spec: change them as you like.")

local NAME = Worth.NAME

local function YouLine(row)
    local fg = T.fg
    if row.secret then
        GameTooltip:AddLine(BLANK, fg.r, fg.g, fg.b)
        _G[TOOLTIP_LINE .. GameTooltip:NumLines()]:SetFormattedText(YOU_LINE, row.total:GetText())
    else
        GameTooltip:AddLine(YOU_LINE:format(row.total:GetText() or ""), fg.r, fg.g, fg.b)
    end
end

local function Does(stat)
    local byClass = D.DOES_BY_CLASS[stat]
    if not byClass then return D.DOES[stat] end
    local _, class = UnitClass("player")
    return byClass[class] or D.DOES[stat]
end

local function RowEnter(row)
    if not row.stat or not Parts.Tip(row, "ANCHOR_RIGHT") then return end
    local a, m, view = T.accentSoft, T.muted, row.view
    GameTooltip:SetText(NAME[row.stat] or row.stat, TITLE_RGB.r, TITLE_RGB.g, TITLE_RGB.b)
    GameTooltip:AddLine(Worth.Line(row.stat, row.weight, view.specName, view.yard, view.yardWeight), a.r, a.g, a.b,
        true)
    local does = Does(row.stat)
    if does then GameTooltip:AddLine(does, m.r, m.g, m.b, true) end
    YouLine(row)
    GameTooltip:Show()
end

local function PaintTotal(row, stat, hidden)
    row.secret = hidden and Totals.Secret[stat] ~= nil
    if row.secret then
        Totals.Secret[stat](row.total)
    else
        row.total:SetText(hidden and Totals.HIDDEN or Totals.Plain[stat]())
    end
end

local function OpenWeights()
    ns.OpenStatWeightsWindow()
end

local function Row(parent, i)
    local row = CreateFrame("Frame", nil, parent)
    row.view = parent
    if i % 2 == STRIPED then ns.Solid(row, "BACKGROUND", T.fg, STRIPE):SetAllPoints() end
    row.name = ns.Font(row, ROW_SIZE_TIGHT, nil, T.muted)
    row.name:SetPoint("LEFT", BAND_PAD, 0)
    row.name:SetWidth(NAME_W)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.track = ns.Solid(row, "ARTWORK", T.fg, TRACK_ALPHA)
    row.track:SetPoint("LEFT", BAND_PAD + BAR_X, -BAR_DROP)
    row.track:SetSize(BAR_W, BAR_H)
    row.bar = ns.Solid(row, "ARTWORK", T.accent, 1)
    row.bar:SetDrawLayer("ARTWORK", BAR_LAYER)
    row.bar:SetPoint("LEFT", BAND_PAD + BAR_X, -BAR_DROP)
    row.bar:SetHeight(BAR_H)
    row.total = ns.Font(row, ROW_SIZE_TIGHT, nil, T.fg)
    row.total:SetPoint("RIGHT", -BAND_PAD, 0)
    row.total:SetJustifyH("RIGHT")
    row:EnableMouse(true)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function Heading(view)
    local weights = Parts.IconButton(view, OpenWeights, ns.Shared.Style.SCALES, nil, TEXT_WEIGHTS)
    weights.hint = TEXT_WEIGHTS_HINT
    weights:SetPoint("RIGHT", view, "TOPRIGHT", -EDGE, -(SECTION_TOP + TITLE_SIZE / 2))
    view.weights = weights
    view.title = ns.Font(view, TITLE_SIZE, nil, T.accentSoft)
    view.title:SetPoint("TOPLEFT", EDGE, -SECTION_TOP)
    local line = ns.Solid(view, "ARTWORK", T.line, 1)
    line:SetPoint("TOPLEFT", EDGE, -LINE_Y)
    line:SetPoint("TOPRIGHT", -EDGE, -LINE_Y)
    ns.Hairline(line, "h")
    view.head = ns.Font(view, HEAD_SIZE, nil, T.muted)
    view.head:SetPoint("TOPLEFT", line, "BOTTOMLEFT", BAR_X, -HEAD_GAP)
    local you = ns.Font(view, HEAD_SIZE, nil, T.muted)
    you:SetPoint("TOPRIGHT", line, "BOTTOMRIGHT", 0, -HEAD_GAP)
    you:SetText(TEXT_YOU)
end

local StatRows = {}
CP.StatRows = StatRows

function StatRows.Build(view)
    Heading(view)
    view.rows = {}
    for i = 1, ROWS do view.rows[i] = Row(view, i) end
end

function StatRows.Lay(view, count)
    local room = view:GetHeight() - ROWS_TOP - ROWS_BOTTOM
    local height = math.max(ROW_FLOOR, math.min(ROW_MAX, math.floor(room / math.max(1, count))))
    if height == view.rowH then return end
    view.rowH = height
    local size = height >= ROW_ROOMY and ROW_SIZE or ROW_SIZE_TIGHT
    local font = ns.UIFontPath()
    for i, row in ipairs(view.rows) do
        local y = -(ROWS_TOP + (i - 1) * height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", view, "TOPLEFT", EDGE - BAND_PAD, y)
        row:SetPoint("TOPRIGHT", view, "TOPRIGHT", -(EDGE - BAND_PAD), y)
        row:SetHeight(height)
        if size ~= view.size then
            row.name:SetFont(font, size, "")
            row.total:SetFont(font, size, "")
        end
    end
    view.size = size
end

function StatRows.Paint(row, stat, weights, top, hidden)
    local weight = weights and weights[stat] or 0
    row.stat, row.weight = stat, weight
    row.name:SetText(D.SHORT[stat] or NAME[stat] or stat)
    PaintTotal(row, stat, hidden)
    row.track:SetShown(weight > 0)
    row.bar:SetShown(weight > 0)
    if weight > 0 then row.bar:SetWidth(math.max(BAR_MIN, math.floor(BAR_W * math.sqrt(weight / top) + C.HALF))) end
end

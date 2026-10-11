-- Card.lua: a Group Inspect party card, built once and laid out narrow (five) or wide (four or fewer) (GI.UI.PartyCard).
local ns = _G.NaowhForever
local T = ns.THEME
local GI = ns.GroupInspect
local UI = GI.UI
local CP = ns.CharacterPanel
local Parts, Items = ns.Shared.Parts, ns.Shared.Items

local St = UI.Style
local GAP, MAX, PAD = St.PARTY_GAP, St.PARTY_MAX, St.PARTY_PAD
local BAND_H, KICKER_SIZE, KICKER_GAP = St.BAND_H, St.KICKER_SIZE, St.KICKER_GAP
local LINE_SIZE, LINE_H, SUB_SIZE, SECTION_GAP = St.LINE_SIZE, St.LINE_H, St.SUB_SIZE, St.SECTION_GAP
local CLASS_ICON, ROLE_ICON = St.CLASS_ICON, St.ROLE_ICON
local NAME_GAP, ICON_GAP = St.PARTY_NAME_GAP, St.PARTY_ICON_GAP
local STAT_ROWS, VALUE_ROOM = St.PARTY_STAT_ROWS, St.PARTY_VALUE_ROOM
local TITLE_RGB = St.TIP_TITLE_RGB
local GEAR_SLOTS = Items.GEAR_SLOTS

local SUB_Y, PILL_DROP = 19, 1
local RULE_GAP = 8
local ILVL_SIZE, ILVL_GAP = 20, 3
local VALUE_CHARS, POINTS_CHARS = 6, 8
local NARROW_CELL_GAP, WIDE_CELL_GAP = 16, 24
local GRID_COL = { 0, 1, 2, 3, 4, 5, 0, 1, 2, 3, 4, 5, 0, 1, 3, 4, 5 }
local GRID_ROW = { 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2 }
local GRID_COLS, GRID_ROWS = 6, 3

local HEAD_Y = BAND_H + PAD
local RULE_Y = HEAD_Y + CLASS_ICON + RULE_GAP
local SCORE_Y = RULE_Y + RULE_GAP + 1
local GEAR_Y = SCORE_Y + CP.BADGE_H + SECTION_GAP

local NARROW = { w = St.PARTY_W, slot = St.SLOT, slotGap = St.SLOT_GAP, cellGap = NARROW_CELL_GAP }
local WIDE = { w = St.PARTY_WIDE_W, slot = St.WIDE_SLOT, slotGap = St.WIDE_SLOT_GAP, cellGap = WIDE_CELL_GAP, long = true }

local SCORE_SHARED, SCORE_READ, SCORE_YOURS = ns.L("Shared by their Naowh Forever"), ns.L("Read from their gear"), ns.L("Yours")
local TEXT_SCORE = "Naowh Score"

local function Measure(l)
    l.inner = l.w - 2 * PAD
    l.gridW = GRID_COLS * l.slot + (GRID_COLS - 1) * l.slotGap
    l.gridX = PAD + math.floor((l.inner - l.gridW) / 2)
    l.cellW = (l.inner - l.cellGap) / 2
    l.slotsY = GEAR_Y + KICKER_SIZE + KICKER_GAP
    l.talentsY = l.slotsY + GRID_ROWS * l.slot + (GRID_ROWS - 1) * l.slotGap + SECTION_GAP
    l.treeY = l.talentsY + KICKER_SIZE + KICKER_GAP
    l.statsY = l.treeY + 2 * LINE_H + SECTION_GAP
    l.cellsY = l.statsY + KICKER_SIZE + KICKER_GAP
    l.stateY = l.cellsY + STAT_ROWS * LINE_H + SECTION_GAP / 2
    l.h = l.stateY + St.ACTION + PAD
end
Measure(NARROW)
Measure(WIDE)

UI.PARTY_H = math.max(NARROW.h, WIDE.h)
UI.BOARD_W = MAX * NARROW.w + (MAX - 1) * GAP
UI.PARTY_LAYOUTS = { narrow = NARROW, wide = WIDE }

local function ScoreEnter(score)
    if GameTooltip:IsForbidden() then return end
    local guid = score:GetParent().guid
    local rec = guid and GI.Member(guid)
    if not Parts.Tip(score, "ANCHOR_BOTTOM") then return end
    local m = T.muted
    GameTooltip:SetText(TEXT_SCORE, TITLE_RGB.r, TITLE_RGB.g, TITLE_RGB.b)
    if rec and rec.score then
        GameTooltip:AddLine(ns.NaowhScore.Tooltip(rec.score, rec.level))
        local source = rec.state == "self" and SCORE_YOURS or rec.scoreShared and SCORE_SHARED or SCORE_READ
        GameTooltip:AddLine(source, m.r, m.g, m.b)
    else
        GameTooltip:AddLine(UI.NOT_READ, m.r, m.g, m.b)
    end
    GameTooltip:Show()
end

local function Refresh(button)
    local guid = button:GetParent().guid
    if guid then GI.Refresh(guid) end
end

local function NewStat(card)
    local stat = { label = ns.Font(card, SUB_SIZE, nil, T.muted) }
    stat.label:SetJustifyH("LEFT")
    stat.label:SetWordWrap(false)
    stat.value = Parts.Cells(card, LINE_SIZE, T.fg, VALUE_CHARS)
    return stat
end

function UI.PartyCard(board)
    local card = CreateFrame("Frame", nil, board)
    ns.Solid(card, "BACKGROUND", T.fg, St.WINDOW_CARD_FILL):SetAllPoints()
    ns.Border(card, St.BORDER_RGB)
    card.band = ns.Solid(card, "ARTWORK", T.fg, 1)
    card.band:SetPoint("TOPLEFT", 1, -1)
    card.band:SetPoint("TOPRIGHT", -1, -1)
    card.band:SetHeight(BAND_H)

    card.class = UI.ClassIcon(card, CLASS_ICON)
    card.class:SetPoint("TOPLEFT", PAD, -HEAD_Y)
    card.nameHit = UI.NameHit(card, card)
    card.nameHit:SetPoint("TOPLEFT", card.class, "TOPLEFT")
    card.nameHit:SetPoint("BOTTOMRIGHT", card, "TOPRIGHT", -(PAD + ROLE_ICON + ICON_GAP), -(HEAD_Y + CLASS_ICON))
    card.nf = UI.NFPill(card, card)
    card.nf:SetPoint("TOPRIGHT", -PAD, -(HEAD_Y + PILL_DROP))
    card.role = UI.RoleIcon(card, ROLE_ICON)
    card.role:SetPoint("TOPRIGHT", -PAD, -(HEAD_Y + CLASS_ICON - ROLE_ICON))
    card.name = ns.Font(card, St.NAME_SIZE, nil, T.fg)
    card.name:SetPoint("TOPLEFT", card.class, "TOPRIGHT", NAME_GAP, 0)
    card.name:SetJustifyH("LEFT")
    card.name:SetWordWrap(false)
    card.badge = UI.Badge(card, card)
    card.badge:SetFrameLevel(card.nameHit:GetFrameLevel() + 2)
    card.sub = ns.Font(card, SUB_SIZE, nil, T.muted)
    card.sub:SetPoint("TOPLEFT", card.class, "TOPRIGHT", NAME_GAP, -SUB_Y)
    card.sub:SetPoint("RIGHT", card, "RIGHT", -(PAD + ROLE_ICON + ICON_GAP), 0)
    card.sub:SetJustifyH("LEFT")
    card.sub:SetWordWrap(false)
    local rule = ns.Solid(card, "ARTWORK", T.line, 1)
    rule:SetPoint("TOPLEFT", PAD, -RULE_Y)
    rule:SetPoint("TOPRIGHT", -PAD, -RULE_Y)
    ns.Hairline(rule, "h")

    card.score = CP.ScoreCard(card, NARROW.inner)
    card.score:SetPoint("TOPLEFT", PAD, -SCORE_Y)
    card.score:SetScript("OnEnter", ScoreEnter)
    card.score:SetScript("OnLeave", GameTooltip_Hide)
    local ilvlKicker = UI.Kicker(card, ns.L("ITEM LEVEL"))
    ilvlKicker:SetPoint("TOPRIGHT", -PAD, -SCORE_Y)
    card.ilvl = ns.Font(card, ILVL_SIZE, nil, T.fg)
    card.ilvl:SetPoint("TOPRIGHT", ilvlKicker, "BOTTOMRIGHT", 0, -ILVL_GAP)

    UI.Kicker(card, "GEAR"):SetPoint("TOPLEFT", PAD, -GEAR_Y)
    card.enchants = ns.Font(card, KICKER_SIZE, nil, T.fg)
    card.enchants:SetPoint("TOPRIGHT", -PAD, -GEAR_Y)
    card.slots = {}
    for i, entry in ipairs(GEAR_SLOTS) do
        card.slots[i] = UI.GearIcon(card, NARROW.slot, entry[1], card, true)
    end

    card.talentsKicker = UI.Kicker(card, "TALENTS")
    card.tree = ns.Font(card, LINE_SIZE, nil, T.fg)
    card.tree:SetJustifyH("LEFT")
    card.tree:SetWordWrap(false)
    card.points = Parts.Cells(card, LINE_SIZE, T.fg, POINTS_CHARS)
    card.trole = ns.Font(card, SUB_SIZE, nil, T.muted)
    card.statsKicker = UI.Kicker(card, "STATS")
    card.from = ns.Font(card, KICKER_SIZE, nil, T.muted)
    card.stats = {}
    for i = 1, STAT_ROWS * 2 do card.stats[i] = NewStat(card) end

    card.state = ns.Font(card, SUB_SIZE, nil, T.muted)
    card.refresh = Parts.IconButton(card, Refresh, St.RESET, 0, UI.REFRESH_TIP)
    card:Hide()
    return card
end

function UI.PlacePartyCard(card, l)
    card.layout = l
    card:SetSize(l.w, l.h)
    CP.SizeScoreCard(card.score, l.inner)
    for i, icon in ipairs(card.slots) do
        icon:SetSize(l.slot, l.slot)
        Parts.SizeItemMarks(icon.marks, l.slot)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", l.gridX + GRID_COL[i] * (l.slot + l.slotGap),
            -(l.slotsY + GRID_ROW[i] * (l.slot + l.slotGap)))
    end
    card.talentsKicker:ClearAllPoints()
    card.talentsKicker:SetPoint("TOPLEFT", PAD, -l.talentsY)
    card.tree:ClearAllPoints()
    card.tree:SetPoint("TOPLEFT", PAD, -l.treeY)
    card.tree:SetWidth(l.inner - VALUE_ROOM * 2)
    card.points[1]:ClearAllPoints()
    card.points[1]:SetPoint("TOPRIGHT", card, "TOPLEFT", PAD + l.inner, -l.treeY)
    card.trole:ClearAllPoints()
    card.trole:SetPoint("TOPLEFT", PAD, -(l.treeY + LINE_H))
    card.statsKicker:ClearAllPoints()
    card.statsKicker:SetPoint("TOPLEFT", PAD, -l.statsY)
    card.from:ClearAllPoints()
    card.from:SetPoint("TOPRIGHT", -PAD, -l.statsY)
    for _, stat in ipairs(card.stats) do stat.label:SetWidth(l.cellW - VALUE_ROOM) end
    card.state:ClearAllPoints()
    card.state:SetPoint("LEFT", card, "TOPLEFT", PAD, -(l.stateY + St.ACTION / 2))
    card.refresh:ClearAllPoints()
    card.refresh:SetPoint("TOPRIGHT", -PAD, -l.stateY)
end

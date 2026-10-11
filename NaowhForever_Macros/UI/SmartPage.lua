-- SmartPage.lua: the Smart Macros tab of Naowh's Forge: each kept macro, its switch, and what it will use right now.
local ns = _G.NaowhForever
local T = ns.THEME
local UI = ns.UI

local M = ns.Macros
local S = M.Settings
local C = M.C
local St = M.Style
local P = M.Parts
local F = { tab = "smart" }
M.Forge = F

local QUESTION = C.QUESTION
local ROW_ICON, ICON_EDGES, BLACK, CARD_GAP = St.ROW_ICON, St.ICON_EDGES, St.BORDER_RGB, St.CARD_GAP
local SMALL_SIZE, NOTE_SIZE, CARD_TITLE_SIZE = St.SMALL_SIZE, St.NOTE_SIZE, St.CARD_TITLE_SIZE
local CARD_H, CARD_COLS, CARD_PAD = 150, 3, St.MACRO_CARD_PAD
local TEXT_GAP, NOTE_GAP = St.ICON_TEXT_GAP, 3
local TOGGLE_TOP, TOGGLE_LEVEL, TOGGLE_GAP = 14, 2, 8
local USES, USE_H, USE_TOP, USE_STEP = 2, 24, 56, 28
local LEAD_W, USE_ICON, USE_ICON_X, USE_TEXT_GAP, COUNT_GAP = 34, 20, 36, 8, 6
local HINT_BOTTOM = 10
local OFF_ALPHA = 0.6

local TEXT_DRAG_HINT = ns.L("Drag the icon to a bar")
local TEXT_USES, TEXT_THEN = ns.L("Uses"), ns.L("then")
local TEXT_SUMMARY = ns.L("%d of %d Smart Macros on.")
local TEXT_ITEM = ns.L("Item %d")
local TEXT_TRINKET, TEXT_NO_TRINKET = ns.L("Your trinket"), ns.L("No trinket worn")
local TEXT_FOCUS = ns.L("Mouseover, else target")
local TEXT_ACCEPT = ns.L("Clicks Yes on popups")
local TEXT_NOTHING = ns.L("Nothing in your bags")
local COUNT, SLOT = "x%d", ns.L("slot %s")

local NOTES = { health = ns.L("Healthstone and potions"), healthstone = ns.L("Best healthstone"), healthPotion = ns.L("Best healing potion"),
    mana = ns.L("Best mana potion"), food = ns.L("Conjured food first"), drink = ns.L("Conjured drink first"),
    bandage = ns.L("On yourself"), trinket1 = ns.L("Top trinket slot"), trinket2 = ns.L("Bottom trinket slot"),
    focus = ns.L("Marks and announces"), acceptPopup = ns.L("Ready checks, summons") }

local function ItemUse(id)
    return { icon = C_Item.GetItemIconByID(id) or QUESTION,
        text = C_Item.GetItemNameByID(id) or TEXT_ITEM:format(id), count = COUNT:format(C_Item.GetItemCount(id)) }
end

local function SlotUse(slot)
    local id = GetInventoryItemID("player", tonumber(slot))
    return { icon = id and C_Item.GetItemIconByID(id) or QUESTION,
        text = id and (C_Item.GetItemNameByID(id) or TEXT_TRINKET) or TEXT_NO_TRINKET, count = SLOT:format(slot) }
end

local function Uses(key, body)
    local uses, seen = {}, {}
    for id in (body or ""):gmatch("item:(%d+)") do
        if not seen[id] then
            seen[id] = true
            uses[#uses + 1] = ItemUse(tonumber(id))
        end
    end
    local slot = (body or ""):match("/use (1[34])")
    if slot then uses[#uses + 1] = SlotUse(slot) end
    if key == "focus" then
        uses[#uses + 1] = { icon = C.FOCUS_ICON, text = TEXT_FOCUS, count = "" }
    elseif key == "acceptPopup" then
        uses[#uses + 1] = { icon = C.ACCEPT_ICON, text = TEXT_ACCEPT, count = "" }
    end
    if #uses == 0 then uses[1] = { icon = QUESTION, text = TEXT_NOTHING, count = "" } end
    return uses
end

local function PickUp(drag)
    ns.PickupManagedMacro(drag.card.key)
end

local function NewUseRow(c, i)
    local row = CreateFrame("Frame", nil, c)
    row:SetHeight(USE_H)
    row:SetPoint("TOPLEFT", CARD_PAD, -USE_TOP - (i - 1) * USE_STEP)
    row:SetPoint("RIGHT", -CARD_PAD, 0)
    row.lead = P.Text(row, SMALL_SIZE, T.muted)
    row.lead:SetPoint("LEFT")
    row.lead:SetWidth(LEAD_W)
    row.lead:SetJustifyH("LEFT")
    row.icon = P.Icon(row, USE_ICON)
    row.icon.edge:SetPoint("LEFT", USE_ICON_X, 0)
    row.count = P.Text(row, SMALL_SIZE, T.muted)
    row.count:SetPoint("RIGHT")
    row.text = P.Text(row, NOTE_SIZE)
    row.text:SetPoint("LEFT", row.icon.edge, "RIGHT", USE_TEXT_GAP, 0)
    row.text:SetPoint("RIGHT", row.count, "LEFT", -COUNT_GAP, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    return row
end

local function NewSmartCard(parent)
    local c = CreateFrame("Frame", nil, parent)
    c:SetHeight(CARD_H)
    ns.Solid(c, "BACKGROUND", T.fg, St.WINDOW_CARD_FILL):SetAllPoints()
    ns.Border(c, BLACK)
    c.drag = CreateFrame("Button", nil, c)
    c.drag.card = c
    c.drag:SetSize(ROW_ICON + ICON_EDGES, ROW_ICON + ICON_EDGES)
    c.drag:SetPoint("TOPLEFT", CARD_PAD, -CARD_PAD)
    c.drag:RegisterForDrag("LeftButton")
    c.icon = P.Icon(c.drag, ROW_ICON)
    c.icon.edge:SetPoint("TOPLEFT")
    c.title = P.Text(c, CARD_TITLE_SIZE)
    c.title:SetPoint("TOPLEFT", c.drag, "TOPRIGHT", TEXT_GAP, 0)
    c.title:SetJustifyH("LEFT")
    c.title:SetWordWrap(false)
    c.note = P.Text(c, SMALL_SIZE, T.muted)
    c.note:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -NOTE_GAP)
    c.note:SetJustifyH("LEFT")
    c.note:SetWordWrap(false)
    c.toggle = UI.BuildToggleControl(c, c:GetFrameLevel() + TOGGLE_LEVEL, function() return S.Get(c.key) == true end,
        function(v) S.Set(c.key, v) end)
    c.toggle:SetPoint("TOPRIGHT", -CARD_PAD, -TOGGLE_TOP)
    c.uses = {}
    for i = 1, USES do c.uses[i] = NewUseRow(c, i) end
    c.dragHint = P.Text(c, SMALL_SIZE, T.muted)
    c.dragHint:SetPoint("BOTTOMRIGHT", -CARD_PAD, HINT_BOTTOM)
    c.dragHint:SetText(TEXT_DRAG_HINT)
    c.drag:SetScript("OnDragStart", PickUp)
    c.drag:SetScript("OnClick", PickUp)
    return c
end

local function PaintUses(c, uses)
    c.icon:SetTexture(uses[1].icon)
    for k, row in ipairs(c.uses) do
        local use = uses[k]
        row:SetShown(use ~= nil)
        if use then
            row.lead:SetText(k == 1 and TEXT_USES or TEXT_THEN)
            row.icon:SetTexture(use.icon)
            row.text:SetText(use.text)
            P.Paint(row.text, k == 1 and T.fg or T.muted)
            row.count:SetText(use.count)
        end
    end
end

local function PaintCard(c, m, w)
    c:SetWidth(w)
    c.key = m.key
    c:SetAlpha(S.Get(m.key) == true and 1 or OFF_ALPHA)
    local textW = w - CARD_PAD - (ROW_ICON + ICON_EDGES) - TEXT_GAP - TOGGLE_GAP - c.toggle:GetWidth() - CARD_PAD
    c.title:SetWidth(textW)
    c.note:SetWidth(textW)
    c.title:SetText(m.name)
    c.note:SetText(NOTES[m.key] or "")
    c.toggle._refreshValue()
    PaintUses(c, Uses(m.key, ns.MacroSmart.Body(m.key)))
end

F.NewSmartCard = NewSmartCard

function F.DrawSmart()
    local view = F.window.smart
    local list = ns.MacroSmart.list
    view.cards.Release()
    local w = math.floor((view.body:GetWidth() - (CARD_COLS - 1) * CARD_GAP) / CARD_COLS)
    for i, m in ipairs(list) do
        local c = view.cards.Take()
        local col, line = (i - 1) % CARD_COLS, math.floor((i - 1) / CARD_COLS)
        c:SetPoint("TOPLEFT", view.body, "TOPLEFT", col * (w + CARD_GAP), -line * (CARD_H + CARD_GAP))
        PaintCard(c, m, w)
    end
    view.body:SetHeight(math.ceil(#list / CARD_COLS) * (CARD_H + CARD_GAP))
    F.window.smartSummary:SetText(TEXT_SUMMARY:format(M.Smart.KeptCount(S), #list))
end

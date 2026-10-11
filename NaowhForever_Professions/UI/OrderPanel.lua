-- OrderPanel.lua: craft orders in the window: the order controls under a recipe and the order column on the right.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local C = P.C
local W = P.State
local Orders = P.Orders
local Lines = P.Lines
local Text = P.Text
local Style = P.Style
local Widgets = P.Widgets
local SetColor = Widgets.SetColor
local EnableButton = Widgets.EnableButton

local EDGE = Style.PANEL_EDGE
local VALUE_BOTTOM = 44
local ADD_W = 120
local LABEL_GAP = 8
local INVITE_W, INVITE_H = 64, 20
local INVITE_RIGHT, INVITE_DROP = 8, 12
local LABEL_X, LABEL_DROP = 10, 8
local TITLE_DROP = 3
local TITLE_GAP = 6
local ROW_H = 44
local ROW_SHRINK = 4
local ROW_X, ROWS_TOP = 6, 44
local ROW_ICON, ICON_X = 28, 4
local REMOVE = 18
local REMOVE_RIGHT = 2
local TIP_W, TIP_H = 76, 20
local TIP_GAP = 4
local TIP_LETTERS = 16
local NAME_GAP = Style.ICON_NAME_GAP
local NAME_DROP = 1
local SUB_DROP = 3
local EMPTY_X, EMPTY_DROP = 14, 50
local EMPTY_SPACING = 2
local SEND_W, CLEAR_W = 150, 80
local TOTAL_X, TOTAL_GAP = 2, 8
local TEXT_ADD, TEXT_REMOVE = ns.L("Add to Order"), ns.L("Remove")
local TEXT_CRAFTS = ns.L("Crafts:")
local TEXT_YOUR_MATERIALS = ns.L("Your materials")
local TEXT_INVITE = ns.L("Invite")
local TEXT_ORDER_FOR = ns.L("Order for")
local TEXT_ROW = "%dx %s"
local TEXT_NO_MATERIALS = ns.L("No materials from you")
local TEXT_ALL_MATERIALS = ns.L("You bring all materials")
local TEXT_SOME_MATERIALS = ns.L("You bring %d of %d materials")
local TEXT_EMPTY = ns.L("Choose a recipe, set how many crafts, tick the materials you bring and click Add to Order.")
local TEXT_TIPS = ns.L("Tips: %s")
local TEXT_ASK_PARTY, TEXT_ASK_INSTANCE, TEXT_ASK_WHISPER = ns.L("Ask in Party"), ns.L("Ask in Instance"), ns.L("Ask by Whisper")
local TEXT_CLEAR = ns.L("Clear")
local TEXT_THEIRS = ns.L("Their materials:")
local TEXT_UNPRICED = ns.L("+ %d unpriced")
local TEXT_BRING_ALL = ns.L("you bring them all")
local TEXT_YOUR_TIP = ns.L("Your tip:")
local TEXT_SUGGESTED = ns.L("suggested %s")
local TEXT_SUGGESTED_TIP = ns.L("Suggested tip:")
local TEXT_SHARE = ns.L("their materials + %d%%")
local TEXT_SCAN_FIRST = ns.L("scan the auction house first")
local TIP_ADD_HELP = ns.L("Puts this recipe on the order on the right, with the "
    .. "number of crafts and the materials you bring. Changes made here after adding it "
    .. "change the order too. Up to %d recipes per order.")
local TIP_CRAFTS = ns.L("Crafts")
local TIP_CRAFTS_HELP = ns.L("How many crafts to ask for.")
local TIP_INVITE_HELP = ns.L("Invites the crafter to your group, with a whisper saying "
    .. "it is for crafts from their profession. Once they are in your "
    .. "party, Ask sends the order in party chat instead of whispering it. Greyed out once "
    .. "they are in your group, or while you are in a group and not its leader or an assistant.")
local TIP_REMOVE_HELP = ns.L("Takes this craft off the order.")
local TIP_TIP = ns.L("Tip")
local TIP_TIP_HELP = ns.L("What you pay the crafter for this craft, sent with the "
    .. "whisper. Filled in with the suggested tip; type your own as 2g 50s, 75s or 2.5 "
    .. "(gold). Empty it to go back to the suggestion.")
local TIP_ASK = ns.L("Ask for the Order")
local TIP_ASK_HELP = ns.L("Sends the crafter one message per craft: how "
    .. "many you want, the materials you bring and your tip. In party chat, starting with "
    .. "their name, when they are in your party; else as a whisper (also in a raid). The "
    .. "order is emptied once sent.")
local TIP_CLEAR_HELP = ns.L("Empties the order without sending it.")
local TIP_TITLE = ns.L("Craft Order")
local TIP_PART = "%s x%d"
local TIP_YOU_BRING = ns.L("you bring it")
local TIP_OF_THEIRS = ns.L("  (%d of theirs)")
local TIP_NO_PRICE = ns.L("no price")
local TIP_HELP = ns.L("The suggested tip pays back the crafter's materials plus %d%% of what "
    .. "the items sell for (of all the materials, for a recipe that makes no item), "
    .. "rounded, at least 1s. Set a tip of your own in the order list on the right. "
    .. "Change the share in the Professions settings.")
local TEXT_ITEM = ns.L("Item ")

local win

local OrderPanel = {}
P.OrderPanel = OrderPanel

local function OrderChanged()
    P.List.Render()
    P.Detail.Render()
    OrderPanel.Render()
end

local function TheirsPrice(p)
    local theirs = p.total - p.mine
    if theirs == 0 then return ns.Color("muted", TIP_YOU_BRING) end
    if p.each then
        return Text.Money(p.each * theirs) .. (p.mine > 0 and TIP_OF_THEIRS:format(theirs) or "")
    end
    return TIP_NO_PRICE
end

local function OnValueEnter(self)
    local v = self.value
    if not v then return end
    local gold = Style.GOLD_RGB
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(TIP_TITLE, gold.r, gold.g, gold.b)
    for _, p in ipairs(v.parts) do
        local name = C_Item.GetItemNameByID(p.itemID) or (TEXT_ITEM .. p.itemID)
        GameTooltip:AddDoubleLine(TIP_PART:format(name, p.total), TheirsPrice(p), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(TIP_HELP:format(v.pct), T.muted.r, T.muted.g, T.muted.b, true)
    if ns.AuctionScanSummary then
        GameTooltip:AddLine(ns.AuctionScanSummary(), T.muted.r, T.muted.g, T.muted.b, true)
    end
    GameTooltip:Show()
end

local function OnAdd()
    local draft, o = Orders.Current(), Orders.Get()
    if not (draft and o) then return end
    local at = Orders.Index(o, draft)
    if at then
        table.remove(o.list, at)
    elseif #o.list < Orders.MAX then
        o.list[#o.list + 1] = draft
        o.sent = nil
        if draft.output then C_Item.RequestLoadItemDataByID(draft.output) end
        for _, r in ipairs(draft.reagents) do C_Item.RequestLoadItemDataByID(r.itemID) end
    end
    OrderChanged()
end

local function SetCrafts(n)
    local draft = Orders.Current()
    if not draft then return end
    draft.crafts = math.min(C.MAX_CRAFTS, math.max(1, n))
    OrderChanged()
end

local function OnCraftsTyped(self, user)
    local n = tonumber(self:GetText() or "")
    if user and n and n > 0 then SetCrafts(n) end
end

local function StepCrafts(by)
    local draft = Orders.Current()
    if draft then SetCrafts(draft.crafts + by) end
end

local function RedrawDetail()
    P.Detail.Render()
end

function OrderPanel.BuildControls(d)
    local orderRow = CreateFrame("Frame", nil, d)
    orderRow:SetPoint("BOTTOMLEFT", EDGE, EDGE)
    orderRow:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
    orderRow:SetHeight(Style.BUTTON_H)
    orderRow:Hide()
    d.orderRow = orderRow
    d.orderAdd = ns.Button(orderRow, TEXT_ADD, ADD_W, Style.BUTTON_H, OnAdd)
    d.orderAdd:SetPoint("RIGHT")
    ns.Tooltip(d.orderAdd, TEXT_ADD, TIP_ADD_HELP:format(Orders.MAX))
    local orderQty = Widgets.QtyBox(orderRow)
    orderQty:SetScript("OnTextChanged", OnCraftsTyped)
    orderQty:SetScript("OnEditFocusLost", RedrawDetail)
    ns.Tooltip(orderQty, TIP_CRAFTS, TIP_CRAFTS_HELP)
    d.orderQty = orderQty
    local orderPlus = ns.Button(orderRow, "+", Style.STEP_W, Style.BUTTON_H, function() StepCrafts(1) end)
    orderPlus:SetPoint("RIGHT", d.orderAdd, "LEFT", -Style.QTY_GAP, 0)
    orderQty:SetPoint("RIGHT", orderPlus, "LEFT", -Style.STEP_GAP, 0)
    local orderMinus = ns.Button(orderRow, "-", Style.STEP_W, Style.BUTTON_H, function() StepCrafts(-1) end)
    orderMinus:SetPoint("RIGHT", orderQty, "LEFT", -Style.STEP_GAP, 0)
    local craftsLabel = ns.Font(orderRow, Style.FONT, nil, Style.GOLD_RGB)
    craftsLabel:SetPoint("RIGHT", orderMinus, "LEFT", -LABEL_GAP, 0)
    craftsLabel:SetText(TEXT_CRAFTS)
    d.orderValue = Lines.Build(d, { "theirs", "pay" })
    d.orderValue:SetScript("OnEnter", OnValueEnter)
    d.orderValue:SetPoint("BOTTOMLEFT", Style.PANE_EDGE, VALUE_BOTTOM)
    d.bringHead = ns.Font(d, Style.FONT, nil, Style.GOLD_RGB)
    d.bringHead:SetPoint("RIGHT", d.reagentsLabel, "LEFT", Style.PANE_INNER_W, 0)
    d.bringHead:SetText(TEXT_YOUR_MATERIALS)
    d.bringHead:Hide()
end

local function OnRemove(row)
    local o = Orders.Get()
    local at = o and Orders.Index(o, row.draft)
    if at then table.remove(o.list, at) end
    OrderChanged()
end

local function OnTipDone(self)
    local row = self:GetParent()
    if not row.draft then return end
    row.draft.tip = Orders.Parse(self:GetText())
    P.Detail.Render()
    OrderPanel.Render()
end

local function OnRowClick(self)
    if not self.draft then return end
    W.selectedID, W.selectedUnlearned = self.draft.recipeID, nil
    P.Entries.Build()
    OrderChanged()
end

local function OnRowEnter(self)
    local d = self.draft
    if not d then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if d.output then
        GameTooltip:SetItemByID(d.output)
    else
        GameTooltip:SetSpellByID(d.recipeID)
    end
    GameTooltip:Show()
end

local function NewRow(order, i)
    local row = CreateFrame("Button", nil, order)
    row:SetSize(Style.ORDER_W - 2 * ROW_X, ROW_H - ROW_SHRINK)
    row:SetPoint("TOPLEFT", ROW_X, -ROWS_TOP - (i - 1) * ROW_H)
    row.sel = ns.Solid(row, "BACKGROUND", T.accent, Style.SELECTED_ALPHA)
    row.sel:SetAllPoints()
    row.hl = ns.Solid(row, "HIGHLIGHT", T.fg, Style.HIGHLIGHT_ALPHA)
    row.hl:SetAllPoints()
    row.icon = Widgets.Crop(row:CreateTexture(nil, "ARTWORK"))
    row.icon:SetSize(ROW_ICON, ROW_ICON)
    row.icon:SetPoint("LEFT", ICON_X, 0)
    row.remove = ns.Button(row, "X", REMOVE, REMOVE, function() OnRemove(row) end)
    row.remove:SetPoint("RIGHT", -REMOVE_RIGHT, 0)
    ns.Tooltip(row.remove, TEXT_REMOVE, TIP_REMOVE_HELP)
    row.tip = ns.NewEditBox(row)
    row.tip:SetSize(TIP_W, TIP_H)
    row.tip:SetPoint("RIGHT", row.remove, "LEFT", -TIP_GAP, 0)
    row.tip:SetJustifyH("RIGHT")
    row.tip:SetMaxLetters(TIP_LETTERS)
    row.tip:SetScript("OnEscapePressed", row.tip.ClearFocus)
    row.tip:SetScript("OnEnterPressed", row.tip.ClearFocus)
    row.tip:SetScript("OnEditFocusLost", OnTipDone)
    ns.Tooltip(row.tip, TIP_TIP, TIP_TIP_HELP)
    row.name = ns.Font(row, Style.FONT, nil)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", NAME_GAP, -NAME_DROP)
    row.name:SetPoint("RIGHT", row.tip, "LEFT", -NAME_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.sub = ns.Font(row, Style.FONT_SMALL, nil, T.muted)
    row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -SUB_DROP)
    row.sub:SetPoint("RIGHT", row.tip, "LEFT", -NAME_GAP, 0)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetWordWrap(false)
    row:SetScript("OnClick", OnRowClick)
    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:Hide()
    return row
end

local function OnSend()
    for _, row in ipairs(win.order.rows) do row.tip:ClearFocus() end
    Orders.Send()
    OrderChanged()
end

local function OnClear()
    local o = Orders.Get()
    if o then wipe(o.list) end
    OrderChanged()
end

local function BuildHeader(order)
    order.invite = ns.Button(order, TEXT_INVITE, INVITE_W, INVITE_H, Orders.Invite)
    order.invite:SetPoint("TOPRIGHT", -INVITE_RIGHT, -INVITE_DROP)
    ns.Tooltip(order.invite, TEXT_INVITE, TIP_INVITE_HELP)
    order.label = ns.Font(order, Style.FONT_SMALL, nil, T.muted)
    order.label:SetPoint("TOPLEFT", LABEL_X, -LABEL_DROP)
    order.label:SetText(TEXT_ORDER_FOR)
    order.title = ns.Font(order, Style.FONT_HEAD, nil, Style.GOLD_RGB)
    order.title:SetPoint("TOPLEFT", order.label, "BOTTOMLEFT", 0, -TITLE_DROP)
    order.title:SetPoint("RIGHT", order.invite, "LEFT", -TITLE_GAP, 0)
    order.title:SetJustifyH("LEFT")
    order.title:SetWordWrap(false)
end

local function BuildFooter(order)
    order.empty = ns.Font(order, Style.FONT, nil, T.muted)
    order.empty:SetPoint("TOPLEFT", EMPTY_X, -EMPTY_DROP)
    order.empty:SetPoint("RIGHT", -EMPTY_X, 0)
    order.empty:SetJustifyH("LEFT")
    order.empty:SetWordWrap(true)
    order.empty:SetSpacing(EMPTY_SPACING)
    order.send = ns.Button(order, TEXT_ASK_WHISPER, SEND_W, Style.BUTTON_H, OnSend)
    order.send:SetPoint("BOTTOMLEFT", EDGE, EDGE)
    ns.Tooltip(order.send, TIP_ASK, TIP_ASK_HELP)
    order.clear = ns.Button(order, TEXT_CLEAR, CLEAR_W, Style.BUTTON_H, OnClear)
    order.clear:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
    ns.Tooltip(order.clear, TEXT_CLEAR, TIP_CLEAR_HELP)
    order.total = ns.Font(order, Style.FONT, nil, Style.GOLD_RGB)
    order.total:SetPoint("BOTTOMLEFT", order.send, "TOPLEFT", TOTAL_X, TOTAL_GAP)
end

function OrderPanel.Build(frame)
    win = frame
    local order = CreateFrame("Frame", nil, win)
    order:SetPoint("TOPLEFT", Style.WINDOW_W, Style.TOP_Y)
    order:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", Style.WINDOW_W, Style.PAD)
    order:SetWidth(Style.ORDER_W)
    ns.Solid(order, "BACKGROUND", T.panel, Style.PANEL_ALPHA):SetAllPoints()
    order:Hide()
    win.order = order
    BuildHeader(order)
    order.rows = {}
    for i = 1, Orders.MAX do order.rows[i] = NewRow(order, i) end
    BuildFooter(order)
end

function OrderPanel.RenderValue()
    local block = win.detail.orderValue
    local d = Orders.Current()
    if not d or #d.reagents == 0 then
        block.value = nil
        return block:Hide()
    end
    local v = Orders.Value(d)
    block.value = v
    Lines.Set(block.theirs, TEXT_THEIRS, Text.Money(v.theirs),
        v.missing > 0 and TEXT_UNPRICED:format(v.missing) or v.theirsCount == 0 and TEXT_BRING_ALL or nil)
    if d.tip then
        Lines.Set(block.pay, TEXT_YOUR_TIP, Text.Money(d.tip), v.pay and TEXT_SUGGESTED:format(Text.Money(v.pay)) or nil)
    else
        Lines.Set(block.pay, TEXT_SUGGESTED_TIP, v.pay and Text.Money(v.pay) or Lines.None(),
            v.pay and TEXT_SHARE:format(v.pct) or TEXT_SCAN_FIRST)
    end
    Lines.Fit(block.lines)
    block:Show()
end

function OrderPanel.RenderDetail(info)
    local d = win.detail
    local draft = Orders.Draft(info)
    d.track:Hide()
    d.buyRow:Hide()
    d.orderRow:SetShown(draft ~= nil)
    d.bringHead:SetShown(draft ~= nil and #draft.reagents > 0)
    if not draft then
        P.Reagents.Fill(d.reagents, {}, nil, 0)
        return OrderPanel.RenderValue()
    end
    P.Reagents.FillOrder(d.reagents, draft)
    OrderPanel.RenderValue()
    if not d.orderQty:HasFocus() then d.orderQty:SetText(tostring(draft.crafts)) end
    local o = Orders.Get()
    local added = Orders.Index(o, draft)
    ns.SetButtonText(d.orderAdd, added and TEXT_REMOVE or TEXT_ADD)
    EnableButton(d.orderAdd, added ~= nil or #o.list < Orders.MAX)
end

local function Materials(v)
    if #v.parts == 0 then return "" end
    if v.bringCount == 0 then return TEXT_NO_MATERIALS end
    if v.theirsCount == 0 then return TEXT_ALL_MATERIALS end
    return TEXT_SOME_MATERIALS:format(v.bringCount, #v.parts)
end

local function FillRow(row, d)
    local v = Orders.Value(d)
    row.icon:SetTexture(d.icon or (d.output and C_Item.GetItemIconByID(d.output)))
    row.name:SetText(TEXT_ROW:format(d.crafts, d.name or ""))
    row.sub:SetText(Materials(v))
    local pay = Orders.Pay(d, v)
    if not row.tip:HasFocus() then row.tip:SetText(pay and pay > 0 and Text.Short(pay) or "") end
    row.sel:SetShown(not W.selectedUnlearned and d.recipeID == W.selectedID)
    row:Show()
    return pay or 0
end

local function AskText(channel)
    if channel == "PARTY" then return TEXT_ASK_PARTY end
    if channel == "INSTANCE_CHAT" then return TEXT_ASK_INSTANCE end
    return TEXT_ASK_WHISPER
end

function OrderPanel.Render()
    local p = win and win.order
    if not (p and W.linked) then return end
    local o = Orders.Get()
    local list = o and o.list or {}
    p.title:SetText(o and Ambiguate(o.who, "short") or "")
    local mayInvite = not IsInGroup() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
    p.invite:SetShown(o ~= nil)
    EnableButton(p.invite, o ~= nil and not Orders.Grouped(o) and mayInvite)
    local total = 0
    for i, row in ipairs(p.rows) do
        local d = list[i]
        row.draft = d
        if d then
            total = total + FillRow(row, d)
        else
            row:Hide()
        end
    end
    p.empty:SetShown(#list == 0)
    p.empty:SetText(o and o.sent or TEXT_EMPTY)
    SetColor(p.empty, o and o.sent and T.accent or T.muted)
    p.total:SetText(#list > 0 and TEXT_TIPS:format(Text.Money(total)) or "")
    ns.SetButtonText(p.send, AskText(o and Orders.Channel(o)))
    EnableButton(p.send, #list > 0)
    EnableButton(p.clear, #list > 0)
end

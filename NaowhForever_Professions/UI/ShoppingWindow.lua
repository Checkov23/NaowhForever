-- ShoppingWindow.lua: the Shopping List window: your crafts, other items and the materials to buy, open without a profession window.
local ns = _G.NaowhForever

local T = ns.THEME
local Shared = ns.Shared
local Parts, St = Shared.Parts, Shared.Style

local P = ns.Professions
local S = P.Settings
local Shopping = P.Shopping
local Text = P.Text
local Style = P.Style
local V = P.Vendors
local Widgets = P.Widgets

local PAGE = "Professions/Settings"
local WIDTH, HEIGHT = 380, 520
local MIN_W, MIN_H = 320, 300
local HEADER, PAD, FOOTER, SCROLLBAR = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER, St.SCROLLBAR
local INSET = St.CONTENT_INSET
local CARD_INSET = 6
local BOTTOM_H = 34
local SCROLL_GAP = 4
local INPUT_H = St.SEARCH_H
local INPUT_DROP = 4
local ADD_W, FIELD_GAP = 60, 6
local SIDE_ROW_H = 20
local ROW_SHRINK = 2
local ICON_SHRINK = Style.ROW_ICON_SHRINK
local NAME_GAP = Style.ICON_NAME_GAP
local TOP_GAP = 2
local HEAD_X, HEAD_STEP = 4, 18
local SECTION_GAP = 8
local ROW_X = 2
local CLEAR_W, CLEAR_H = 80, 24
local SMALL_BUTTON = 16
local STEP_GAP, MINUS_GAP = 6, 2
local PIN_GAP = 4
local MAKE_W, KEEP_W = 40, 34
local SUMMARY_SIZE = 12
local EVENTS = { "BAG_UPDATE_DELAYED" }
local TEXT_TITLE = ns.L("Shopping List")
local TEXT_SUBTITLE = ns.L("Crafts, other items and what to buy.")
local TEXT_HINT = ns.L("Add an item above, or click Add to List under a recipe: what you need to buy lands here.")
local TEXT_QUEUE_HINT = ns.L("Add an item above, or add a recipe to the Crafting Queue: what you need to buy lands here.")
local TEXT_CRAFTS, TEXT_ITEMS, TEXT_MATERIALS, TEXT_VENDOR, TEXT_MADE = ns.L("Crafts"), ns.L("Other Items"),
    ns.L("Materials"), ns.L("Buy from Vendor"), ns.L("Make First")
local TEXT_CLEAR = ns.L("Clear")
local TEXT_ROW = "%dx %s"
local TEXT_UNKNOWN = "?"
local TEXT_ITEM = ns.L("item ")
local TEXT_OWNED = ns.L("(%d owned)")
local TEXT_NO_PRICE = ns.L("no price")
local TEXT_ABOUT = "~"
local TEXT_PARTS_BOUGHT = ns.L("parts bought")
local TEXT_SAVES = ns.L("saves ~")
local TEXT_NO_AH_PRICE = ns.L("no AH price")
local TEXT_UNPRICED = ns.L("unpriced")
local TEXT_VENDOR_PRICE_UNKNOWN = ns.L("price unknown")
local TEXT_MAKE, TEXT_BUY = ns.L("Make"), ns.L("Buy")
local TEXT_ADD = ns.L("Add")
local TEXT_NOT_FOUND = ns.L("No item found for that. Use a link, an item ID, or the name of an item you have seen.")
local TEXT_OFF = ns.L("Turn on the Shopping List in the Professions settings first.")
local TIP_CLEAR_HELP = ns.L("Empties the Shopping List and the Crafting Queue when it is enabled.")
local TIP_REMOVE, TIP_REMOVE_HELP = ns.L("Remove"), ns.L("Takes this craft and its materials off the list.")
local TIP_MORE, TIP_MORE_HELP = ns.L("One More"), ns.L("Adds the materials for one more craft.")
local TIP_FEWER, TIP_FEWER_HELP = ns.L("One Fewer"), ns.L("Takes the materials for one craft off the list.")
local TIP_ITEM_REMOVE_HELP = ns.L("Takes this item off the list.")
local TIP_ITEM_MORE_HELP = ns.L("Adds one more.")
local TIP_ITEM_FEWER_HELP = ns.L("Takes one off.")
local TIP_MAKE, TIP_MAKE_HELP = ns.L("Make It"), ns.L("Buys its cheaper parts instead, to make it yourself.")
local TIP_KEEP, TIP_KEEP_HELP = ns.L("Buy It"), ns.L("Buys it as it is instead of its parts.")
local TIP_FIELD, TIP_FIELD_HELP = ns.L("Add an Item"), ns.L("Shift-click an item, or type its name or ID.")
local TIP_QTY, TIP_QTY_HELP = ns.L("How Many"), ns.L("How many of the item to add.")
local TIP_ADD_HELP = ns.L("Puts that many of the item on the list.")
local TEXT_CONSUMABLES = ns.L("Consumables")
local TIP_CONSUMABLES_HELP = ns.L("Picks food, flasks, elixirs and more for your class to buy.")
local TIP_VENDOR_WAYPOINT = ns.L("Sets a waypoint to the nearest known vendor for this material.")

local window, side, scroll, input, qty, empty, total, clear, picker, pickerFullWidth, events
local crafts, craftPool, items, itemPool, madeList, madePool = {}, {}, {}, {}, {}, {}
local pools = { crafts = {}, items = {}, materials = {}, vendor = {}, made = {} }
local heads = {}

local function On()
    return S.Get("enabled") and S.Get("shoppingList")
end

local function QueueOn()
    return On() and S.Get("craftQueue")
end

local function ByCraftName(a, b)
    return (a.craft.name or "") < (b.craft.name or "")
end

local function ByItemName(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.item < b.item
end

local function OnRowEnter(self)
    if not (self.item or self.spell) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.item then
        GameTooltip:SetItemByID(self.item)
    elseif not pcall(GameTooltip.SetRecipeResultItem, GameTooltip, self.spell) then
        GameTooltip:SetSpellByID(self.spell)
    end
    GameTooltip:Show()
end

local function SideRow(pool, i)
    local row = pool[i]
    if row then return row end
    row = CreateFrame("Frame", nil, side)
    row:SetHeight(SIDE_ROW_H - ROW_SHRINK)
    row:EnableMouse(true)
    row.icon = Widgets.Crop(row:CreateTexture(nil, "ARTWORK"))
    row.icon:SetSize(SIDE_ROW_H - ICON_SHRINK, SIDE_ROW_H - ICON_SHRINK)
    row.icon:SetPoint("LEFT")
    row.note = ns.Font(row, Style.FONT_SMALL, nil, T.muted)
    row.note:SetJustifyH("RIGHT")
    row.name = ns.Font(row, Style.FONT, nil)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", NAME_GAP, 0)
    row.name:SetPoint("RIGHT", row.note, "LEFT", -NAME_GAP, 0)
    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    pool[i] = row
    return row
end

local function Head(key, text)
    local head = ns.Font(side, Style.FONT, nil, Style.GOLD_RGB)
    head:SetText(text)
    heads[key] = head
end

local function PlaceHead(head, y)
    head:ClearAllPoints()
    head:SetPoint("TOPLEFT", HEAD_X, y)
    head:Show()
    return y - HEAD_STEP
end

local function PlaceRow(row, y)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", ROW_X, y)
    row:SetPoint("TOPRIGHT", -ROW_X, y)
    row:Show()
    return y - SIDE_ROW_H
end

local function StepButtons(row, remove, step, removeHelp, moreHelp, fewerHelp)
    row.remove = ns.Button(row, "X", SMALL_BUTTON, SMALL_BUTTON, function()
        if row.key then remove(row.key) end
    end)
    row.remove:SetPoint("RIGHT")
    ns.Tooltip(row.remove, TIP_REMOVE, removeHelp)
    row.plus = ns.Button(row, "+", SMALL_BUTTON, SMALL_BUTTON, function() step(row.key, 1) end)
    row.plus:SetPoint("RIGHT", row.remove, "LEFT", -STEP_GAP, 0)
    ns.Tooltip(row.plus, TIP_MORE, moreHelp)
    row.minus = ns.Button(row, "-", SMALL_BUTTON, SMALL_BUTTON, function() step(row.key, -1) end)
    row.minus:SetPoint("RIGHT", row.plus, "LEFT", -MINUS_GAP, 0)
    ns.Tooltip(row.minus, TIP_FEWER, fewerHelp)
    row.note:SetPoint("RIGHT", row.minus, "LEFT", -STEP_GAP, 0)
end

local function SortedCrafts()
    local n = 0
    for recipeID, craft in pairs(Shopping.List()) do
        n = n + 1
        local e = craftPool[n] or {}
        craftPool[n] = e
        e.id, e.craft = recipeID, craft
        crafts[n] = e
    end
    for i = n + 1, #crafts do crafts[i] = nil end
    table.sort(crafts, ByCraftName)
end

local function SortedItems()
    local n = 0
    for item, count in pairs(Shopping.Manual()) do
        n = n + 1
        local e = itemPool[n] or {}
        itemPool[n] = e
        e.item, e.qty, e.name = item, count, Shopping.ItemName(item) or ""
        items[n] = e
    end
    for i = n + 1, #items do items[i] = nil end
    table.sort(items, ByItemName)
end

local function HideSpare(pool, from)
    for i = from, #pool do pool[i]:Hide() end
end

local function DrawCrafts(y)
    if #crafts > 0 then y = PlaceHead(heads.crafts, y) end
    local pool = pools.crafts
    for i, e in ipairs(crafts) do
        local row = SideRow(pool, i)
        if not row.remove then
            StepButtons(row, Shopping.Remove, Shopping.Step, TIP_REMOVE_HELP, TIP_MORE_HELP, TIP_FEWER_HELP)
        end
        local queued = e.craft.queueCount
        Widgets.EnableButton(row.minus, e.craft.count - (queued or 0) > (queued and 0 or 1))
        row.key, row.spell, row.item = e.id, e.id, nil
        row.icon:SetTexture(e.craft.icon or C_Spell.GetSpellTexture(e.id))
        row.name:SetText(TEXT_ROW:format(e.craft.count, e.craft.name or TEXT_UNKNOWN))
        row.note:SetText("")
        y = PlaceRow(row, y)
    end
    HideSpare(pool, #crafts + 1)
    return y
end

local function DrawItems(y)
    if #items > 0 then y = PlaceHead(heads.items, y - (#crafts > 0 and SECTION_GAP or 0)) end
    local pool = pools.items
    local muted = Text.Hex(T.muted)
    for i, e in ipairs(items) do
        local row = SideRow(pool, i)
        if not row.remove then
            StepButtons(row, Shopping.RemoveItem, Shopping.StepItem, TIP_ITEM_REMOVE_HELP, TIP_ITEM_MORE_HELP,
                TIP_ITEM_FEWER_HELP)
        end
        Widgets.EnableButton(row.minus, e.qty > 1)
        row.key, row.item = e.item, e.item
        row.icon:SetTexture(C_Item.GetItemIconByID(e.item))
        row.name:SetText(TEXT_ROW:format(e.qty, Shopping.ItemName(e.item) or (TEXT_ITEM .. e.item))
            .. " " .. muted .. TEXT_OWNED:format(C_Item.GetItemCount(e.item, true) or 0) .. "|r")
        row.note:SetText("")
        y = PlaceRow(row, y)
    end
    HideSpare(pool, #items + 1)
    return y
end

local function MakeButton(row)
    row.make = ns.Button(row, TEXT_MAKE, MAKE_W, SMALL_BUTTON, function()
        if row.item then
            Shopping.Keep()[row.item] = nil
            Shopping.Redraw()
        end
    end)
    row.make:SetPoint("RIGHT")
    ns.Tooltip(row.make, TIP_MAKE, TIP_MAKE_HELP)
end

local function FillMaterial(row, m, plan)
    local price = Shopping.BuyPrice(m.item)
    local make = false
    if Shopping.Keep()[m.item] then make = select(2, Shopping.Cheapest(m.item, plan, 0, true)) end
    if make and not row.make then MakeButton(row) end
    if row.make then row.make:SetShown(make and true or false) end
    row.note:ClearAllPoints()
    if make then row.note:SetPoint("RIGHT", row.make, "LEFT", -STEP_GAP, 0) else row.note:SetPoint("RIGHT") end
    row.item, row.key, row.spell = m.item, nil, nil
    row.icon:SetTexture(C_Item.GetItemIconByID(m.item))
    row.name:SetText(TEXT_ROW:format(m.qty, Shopping.ItemName(m.item) or (TEXT_ITEM .. m.item)))
    row.note:SetText(price and (TEXT_ABOUT .. Text.Short(price * m.qty)) or TEXT_NO_PRICE)
end

local function DrawMaterials(materials, plan, y)
    if #materials > 0 then y = PlaceHead(heads.materials, y - SECTION_GAP) end
    local pool = pools.materials
    for i, m in ipairs(materials) do
        local row = SideRow(pool, i)
        FillMaterial(row, m, plan)
        y = PlaceRow(row, y)
    end
    HideSpare(pool, #materials + 1)
    return y
end

local function OnVendorWaypoint(button)
    if button.item then V.VendorWaypoint(button.item) end
end

local function DrawVendorMaterials(materials, y)
    if #materials > 0 then y = PlaceHead(heads.vendor, y - SECTION_GAP) end
    local pool = pools.vendor
    for i, m in ipairs(materials) do
        local row = SideRow(pool, i)
        if not row.pin then
            row.pin = Parts.IconButton(row, OnVendorWaypoint, St.PIN, 0, TIP_VENDOR_WAYPOINT)
            row.pin:SetPoint("RIGHT")
        end
        row.pin.item = m.item
        row.note:ClearAllPoints()
        row.note:SetPoint("RIGHT", row.pin, "LEFT", -PIN_GAP, 0)
        row.item, row.key, row.spell = m.item, nil, nil
        row.icon:SetTexture(C_Item.GetItemIconByID(m.item))
        row.name:SetText(TEXT_ROW:format(m.qty, Shopping.ItemName(m.item) or (TEXT_ITEM .. m.item)))
        local price = Shopping.VendorPrice(m.item)
        row.note:SetText(price and Text.Short(price * m.qty) or TEXT_VENDOR_PRICE_UNKNOWN)
        y = PlaceRow(row, y)
    end
    HideSpare(pool, #materials + 1)
    return y
end

local function SortedMade(made)
    local n = 0
    for item, count in pairs(made) do
        n = n + 1
        local e = madePool[n] or {}
        madePool[n] = e
        e.item, e.qty, e.name = item, count, Shopping.ItemName(item) or ""
        madeList[n] = e
    end
    for i = n + 1, #madeList do madeList[i] = nil end
    table.sort(madeList, Shopping.ByName)
    return madeList
end

local function KeepButton(row)
    row.keep = ns.Button(row, TEXT_BUY, KEEP_W, SMALL_BUTTON, function()
        if row.item then
            Shopping.Keep()[row.item] = true
            Shopping.Redraw()
        end
    end)
    row.keep:SetPoint("RIGHT")
    ns.Tooltip(row.keep, TIP_KEEP, TIP_KEEP_HELP)
end

local function FillMade(row, e, plan)
    if not row.keep then KeepButton(row) end
    local planned = plan.planned[e.item]
    row.keep:SetShown(planned and true or false)
    row.note:ClearAllPoints()
    if planned then row.note:SetPoint("RIGHT", row.keep, "LEFT", -STEP_GAP, 0) else row.note:SetPoint("RIGHT") end
    local saves = plan.saves[e.item]
    row.item, row.key, row.spell = e.item, nil, nil
    row.icon:SetTexture(C_Item.GetItemIconByID(e.item))
    row.name:SetText(TEXT_ROW:format(e.qty, Shopping.ItemName(e.item) or (TEXT_ITEM .. e.item)))
    if not planned then
        row.note:SetText(TEXT_PARTS_BOUGHT)
    else
        row.note:SetText(saves and (TEXT_SAVES .. Text.Short(saves)) or TEXT_NO_AH_PRICE)
    end
end

local function DrawMade(made, plan, y)
    local makes = SortedMade(made)
    if #makes > 0 then y = PlaceHead(heads.made, y - SECTION_GAP) end
    local pool = pools.made
    for i, e in ipairs(makes) do
        local row = SideRow(pool, i)
        FillMade(row, e, plan)
        y = PlaceRow(row, y)
    end
    HideSpare(pool, #makes + 1)
    return y
end

local function RenderWindow()
    if not (window and window:IsShown()) then return end
    if not On() then return window:Hide() end
    local materials, made, plan, vendorMaterials = Shopping.Materials()
    SortedCrafts()
    SortedItems()
    for _, head in pairs(heads) do head:Hide() end
    local y = DrawCrafts(-TOP_GAP)
    y = DrawItems(y)
    y = DrawMaterials(materials, plan, y)
    y = DrawVendorMaterials(vendorMaterials, y)
    y = DrawMade(made, plan, y)
    side:SetHeight(math.max(1, -y))
    local listed = #crafts > 0 or #items > 0
    empty:SetText(QueueOn() and TEXT_QUEUE_HINT or TEXT_HINT)
    empty:SetShown(not listed)
    total:SetText((#materials > 0 or #vendorMaterials > 0)
        and Shopping.Estimate(materials, TEXT_UNPRICED, vendorMaterials) or "")
    clear:SetShown(listed)
end

local function ResolveItem(text)
    text = strtrim(text or "")
    if text == "" then return nil end
    return (C_Item.GetItemInfoInstant(tonumber(text) or text))
end

local function HowMany()
    return math.max(1, tonumber(qty:GetText()) or 1)
end

local function AddItem(item)
    if not item then return ns.Print(TEXT_NOT_FOUND) end
    Shopping.ItemName(item)
    Shopping.AddItem(item, HowMany())
    input:SetText("")
end

local function OnAddClicked()
    AddItem(ResolveItem(input:GetText()))
end

local function OnInsertLink(link)
    if window:IsShown() and input:HasFocus() then AddItem(ResolveItem(link)) end
end

local function OnReceiveDrag()
    local kind, id = GetCursorInfo()
    if kind ~= "item" or not id then return end
    ClearCursor()
    AddItem(id)
end

local function DropClick()
    if GetCursorInfo() then OnReceiveDrag() end
end

local function FitPicker()
    local text = math.max(window.title:GetUnboundedStringWidth(), window.subtitle:GetUnboundedStringWidth())
    local fits = text + St.BAR_GAP + pickerFullWidth <= picker:GetRight() - window.title:GetLeft()
    picker.label:SetShown(fits)
    picker:SetWidth(fits and pickerFullWidth or picker:GetHeight())
end

local function OnShow()
    FitPicker()
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    RenderWindow()
end

local function OnHide()
    events:UnregisterAllEvents()
end

local function OnSized(_, width)
    side:SetWidth(width - INSET - SCROLLBAR - SCROLL_GAP)
    if window:IsShown() then FitPicker() end
end

local function BuildInput()
    local top = HEADER + PAD + INPUT_DROP
    local add = ns.Button(window, TEXT_ADD, ADD_W, INPUT_H, OnAddClicked)
    add:SetPoint("TOPRIGHT", -INSET, -top)
    ns.Tooltip(add, TEXT_ADD, TIP_ADD_HELP)
    qty = Widgets.QtyBox(window)
    qty:SetHeight(INPUT_H)
    qty:SetPoint("RIGHT", add, "LEFT", -FIELD_GAP, 0)
    ns.Tooltip(qty, TIP_QTY, TIP_QTY_HELP)
    input = ns.NewEditBox(window)
    input:SetHeight(INPUT_H)
    input:SetPoint("TOPLEFT", INSET, -top)
    input:SetPoint("RIGHT", qty, "LEFT", -FIELD_GAP, 0)
    input:SetScript("OnEscapePressed", input.ClearFocus)
    input:SetScript("OnEnterPressed", OnAddClicked)
    ns.Tooltip(input, TIP_FIELD, TIP_FIELD_HELP)
    return top
end

local function BuildBody(top)
    scroll = ns.UI.SlimScroll(window)
    scroll:SetPoint("TOPLEFT", INSET, -(top + INPUT_H + PAD))
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR - SCROLL_GAP, FOOTER + PAD + BOTTOM_H)
    side = CreateFrame("Frame", nil, scroll)
    side:SetSize(WIDTH - INSET - SCROLLBAR - SCROLL_GAP, 1)
    scroll:SetScrollChild(side)
    Head("crafts", TEXT_CRAFTS)
    Head("items", TEXT_ITEMS)
    Head("materials", TEXT_MATERIALS)
    Head("vendor", TEXT_VENDOR)
    Head("made", TEXT_MADE)
    empty = ns.Font(window, SUMMARY_SIZE, nil, T.muted)
    empty:SetPoint("LEFT", scroll, "LEFT")
    empty:SetPoint("RIGHT", scroll, "RIGHT")
    empty:SetJustifyH("CENTER")
    empty:SetWordWrap(true)
    empty:SetText(TEXT_HINT)
end

local function BuildFooter()
    clear = ns.Button(window, TEXT_CLEAR, CLEAR_W, CLEAR_H, Shopping.Clear)
    clear:SetPoint("BOTTOMRIGHT", -INSET, FOOTER + PAD)
    ns.Tooltip(clear, TEXT_CLEAR, TIP_CLEAR_HELP)
    total = ns.Font(window, SUMMARY_SIZE, nil, T.muted)
    total:SetPoint("LEFT", window, "BOTTOMLEFT", INSET, FOOTER + PAD + CLEAR_H / 2)
    total:SetPoint("RIGHT", clear, "LEFT", -PAD, 0)
    total:SetJustifyH("LEFT")
    total:SetWordWrap(true)
end

local function OnConsumables()
    Shopping.ToggleConsumables(window)
end

local function BuildBar(close)
    picker = Parts.BarButton(window, St.BAG, TEXT_CONSUMABLES, TIP_CONSUMABLES_HELP, OnConsumables,
        TEXT_CONSUMABLES)
    pickerFullWidth = picker:GetWidth()
    picker:SetPoint("RIGHT", close, "LEFT", -St.BAR_GAP, 0)
    window.subtitle:SetPoint("RIGHT", picker, "LEFT", -St.BAR_GAP, 0)
end

local function Build()
    window = Parts.Window(WIDTH, HEIGHT, "shoppingListWindow")
    window.backdrop:Card(CARD_INSET, HEADER + CARD_INSET, CARD_INSET, FOOTER + CARD_INSET)
    BuildBar(Parts.TitleBar(window, TEXT_TITLE, TEXT_SUBTITLE, PAGE))
    Parts.FooterBrand(window, PAGE)
    BuildBody(BuildInput())
    BuildFooter()
    Parts.Resizable(window, "shoppingList", MIN_W, MIN_H, OnSized)
    OnSized(window, window:GetWidth())
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", RenderWindow)
    window:SetScript("OnReceiveDrag", OnReceiveDrag)
    window:SetScript("OnMouseUp", DropClick)
    window:HookScript("OnShow", OnShow)
    window:HookScript("OnHide", OnHide)
    hooksecurefunc(ChatFrameUtil, "InsertLink", OnInsertLink)
end

function ns.OpenShoppingList()
    if not On() then return ns.Print(TEXT_OFF) end
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window:Show()
    window.backdrop:Paint(1)
end

function ns.ToggleShoppingList()
    if window and window:IsShown() then window:Hide() else ns.OpenShoppingList() end
end

ns.RegisterMinimapFeature({
    id = "ShoppingList", name = "Shopping List", icon = "Interface\\Icons\\INV_Misc_Note_01",
    open = ns.ToggleShoppingList, tooltip = "Click to open or close the Shopping List.",
})

Shopping.RenderWindow = RenderWindow

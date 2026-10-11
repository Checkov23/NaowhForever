-- ShoppingSide.lua: the shopping list in the profession window: its column on the right, and Add to List under a recipe.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local S = P.Settings
local C = P.C
local Shopping = P.Shopping
local Text = P.Text
local Style = P.Style
local Widgets = P.Widgets

local SIDE_W, SIDE_ROW_H = 260, 20
local SIDE_CRAFTS, SIDE_MATERIALS, SIDE_MADE = 6, 12, 6
local SIDE_GAP = 8
local ROW_W_ROOM = 16
local ROW_SHRINK = 2
local ICON_SHRINK = Style.ROW_ICON_SHRINK
local NAME_GAP = Style.ICON_NAME_GAP
local TITLE_X, TITLE_DROP = 10, 10
local HINT_DROP = 36
local HINT_ROOM = 20
local HINT_SPACING = 2
local LIST_TOP = -36
local HEAD_X, HEAD_STEP = 10, 18
local SECTION_GAP = 8
local ROW_X = 8
local TOTAL_X, TOTAL_BOTTOM, TOTAL_RIGHT = 10, 16, 100
local CLEAR_W, CLEAR_EDGE = 80, 10
local SMALL_BUTTON = 16
local STEP_GAP, MINUS_GAP = 6, 2
local MAKE_W, KEEP_W = 40, 34
local ADD_W = 90
local ADD_DROP = 4
local ADD_OVERHANG = 4
local TEXT_TITLE = ns.L("Shopping List")
local TEXT_HINT = ns.L("Choose a recipe, set how many crafts and click Add to List: its materials "
    .. "land here. At the auction house the list shows beside it, to check the prices and "
    .. "buy it all.")
local TEXT_CRAFTS, TEXT_MATERIALS, TEXT_MADE = ns.L("Crafts"), ns.L("Materials"), ns.L("Make First")
local TEXT_CLEAR = ns.L("Clear")
local TEXT_ROW = "%dx %s"
local TEXT_UNKNOWN = "?"
local TEXT_ITEM = ns.L("item ")
local TEXT_NO_PRICE = ns.L("no price")
local TEXT_ABOUT = "~"
local TEXT_PARTS_BOUGHT = ns.L("parts bought")
local TEXT_SAVES = ns.L("saves ~")
local TEXT_NO_AH_PRICE = ns.L("no AH price")
local TEXT_UNPRICED = ns.L("unpriced")
local TEXT_ADD = ns.L("Add to List")
local TEXT_MAKE, TEXT_BUY = ns.L("Make"), ns.L("Buy")
local TIP_CLEAR_HELP = ns.L("Empties the shopping list.")
local TIP_REMOVE, TIP_REMOVE_HELP = ns.L("Remove"), ns.L("Takes this craft and its materials off the list.")
local TIP_MORE, TIP_MORE_HELP = ns.L("One More"), ns.L("Adds the materials for one more craft.")
local TIP_FEWER, TIP_FEWER_HELP = ns.L("One Fewer"), ns.L("Takes the materials for one craft off the list.")
local TIP_MAKE, TIP_MAKE_HELP = ns.L("Make It"), ns.L("Buys its cheaper parts instead, to make it yourself.")
local TIP_KEEP, TIP_KEEP_HELP = ns.L("Buy It"), ns.L("Buys it as it is instead of its parts.")
local TIP_ADD = ns.L("Add to Shopping List")
local TIP_ADD_HELP = ns.L("Puts the materials for that many crafts on your "
    .. "shopping list: every checked reagent that vendors do not sell, whatever is in your "
    .. "bags. Uncheck a reagent to leave it out. At the auction house the list shows beside "
    .. "it, to check the prices and buy it all.")
local TIP_CRAFTS, TIP_CRAFTS_HELP = ns.L("Crafts"), ns.L("How many crafts Add to List adds the materials for.")

local side
local crafts, craftPool, madeList, madePool = {}, {}, {}, {}
local addRow, addRecipe

local function On()
    return S.Get("enabled") and S.Get("shoppingList")
end

local function ByCraftName(a, b)
    return (a.craft.name or "") < (b.craft.name or "")
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
    row:SetSize(SIDE_W - ROW_W_ROOM, SIDE_ROW_H - ROW_SHRINK)
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

local function Head(text)
    local head = ns.Font(side, Style.FONT, nil, Style.GOLD_RGB)
    head:SetText(text)
    return head
end

local function BuildSide(win)
    side = CreateFrame("Frame", nil, win.mid)
    side:SetPoint("TOPLEFT", win.mid, "TOPRIGHT", SIDE_GAP, 0)
    side:SetPoint("BOTTOMLEFT", win.mid, "BOTTOMRIGHT", SIDE_GAP, 0)
    side:SetWidth(SIDE_W)
    ns.Solid(side, "BACKGROUND", T.panel, Style.PANEL_ALPHA):SetAllPoints()
    side.title = ns.Font(side, Style.FONT_HEAD, nil, T.accent)
    side.title:SetPoint("TOPLEFT", TITLE_X, -TITLE_DROP)
    side.title:SetText(TEXT_TITLE)
    side.hint = ns.Font(side, Style.FONT, nil, T.muted)
    side.hint:SetPoint("TOPLEFT", TITLE_X, -HINT_DROP)
    side.hint:SetWidth(SIDE_W - HINT_ROOM)
    side.hint:SetJustifyH("LEFT")
    side.hint:SetWordWrap(true)
    side.hint:SetSpacing(HINT_SPACING)
    side.hint:SetText(TEXT_HINT)
    side.craftsHead = Head(TEXT_CRAFTS)
    side.materialsHead = Head(TEXT_MATERIALS)
    side.madeHead = Head(TEXT_MADE)
    side.crafts, side.materials, side.made = {}, {}, {}
    side.total = ns.Font(side, Style.FONT, nil)
    side.total:SetPoint("BOTTOMLEFT", TOTAL_X, TOTAL_BOTTOM)
    side.total:SetPoint("RIGHT", -TOTAL_RIGHT, 0)
    side.total:SetJustifyH("LEFT")
    side.total:SetWordWrap(true)
    side.clear = ns.Button(side, TEXT_CLEAR, CLEAR_W, Style.BUTTON_H, Shopping.Clear)
    side.clear:SetPoint("BOTTOMRIGHT", -CLEAR_EDGE, CLEAR_EDGE)
    ns.Tooltip(side.clear, TEXT_CLEAR, TIP_CLEAR_HELP)
    side:Hide()
end

local function PlaceHead(head, y)
    head:ClearAllPoints()
    head:SetPoint("TOPLEFT", HEAD_X, y)
    return y - HEAD_STEP
end

local function CraftButtons(row)
    row.remove = ns.Button(row, "X", SMALL_BUTTON, SMALL_BUTTON, function()
        if row.recipeID then Shopping.Remove(row.recipeID) end
    end)
    row.remove:SetPoint("RIGHT")
    ns.Tooltip(row.remove, TIP_REMOVE, TIP_REMOVE_HELP)
    row.plus = ns.Button(row, "+", SMALL_BUTTON, SMALL_BUTTON, function() Shopping.Step(row.recipeID, 1) end)
    row.plus:SetPoint("RIGHT", row.remove, "LEFT", -STEP_GAP, 0)
    ns.Tooltip(row.plus, TIP_MORE, TIP_MORE_HELP)
    row.minus = ns.Button(row, "-", SMALL_BUTTON, SMALL_BUTTON, function() Shopping.Step(row.recipeID, -1) end)
    row.minus:SetPoint("RIGHT", row.plus, "LEFT", -MINUS_GAP, 0)
    ns.Tooltip(row.minus, TIP_FEWER, TIP_FEWER_HELP)
    row.note:SetPoint("RIGHT", row.minus, "LEFT", -STEP_GAP, 0)
end

local function PlaceRow(row, y)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", ROW_X, y)
    row:Show()
    return y - SIDE_ROW_H
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
    return crafts
end

local function DrawCrafts(y)
    if #crafts > 0 then y = PlaceHead(side.craftsHead, y) end
    for i = 1, math.max(#crafts, #side.crafts) do
        local e = crafts[i]
        local row = (e or side.crafts[i]) and SideRow(side.crafts, i)
        if row and e and i <= SIDE_CRAFTS then
            if not row.remove then CraftButtons(row) end
            Widgets.EnableButton(row.minus, e.craft.count > 1)
            row.recipeID, row.spell = e.id, e.id
            row.icon:SetTexture(e.craft.icon or C_Spell.GetSpellTexture(e.id))
            row.name:SetText(TEXT_ROW:format(e.craft.count, e.craft.name or TEXT_UNKNOWN))
            row.note:SetText("")
            y = PlaceRow(row, y)
        elseif row then
            row:Hide()
        end
    end
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
    row.item = m.item
    row.icon:SetTexture(C_Item.GetItemIconByID(m.item))
    row.name:SetText(TEXT_ROW:format(m.qty, Shopping.ItemName(m.item) or (TEXT_ITEM .. m.item)))
    row.note:SetText(price and (TEXT_ABOUT .. Text.Short(price * m.qty)) or TEXT_NO_PRICE)
end

local function DrawMaterials(materials, plan, y)
    if #materials > 0 then y = PlaceHead(side.materialsHead, y - SECTION_GAP) end
    for i = 1, math.max(#materials, #side.materials) do
        local m = materials[i]
        local row = (m or side.materials[i]) and SideRow(side.materials, i)
        if m and i <= SIDE_MATERIALS then
            FillMaterial(row, m, plan)
            y = PlaceRow(row, y)
        elseif row then
            row:Hide()
        end
    end
    return y
end

local function SortedMade(made)
    local n = 0
    for item, qty in pairs(made) do
        n = n + 1
        local e = madePool[n] or {}
        madePool[n] = e
        e.item, e.qty, e.name = item, qty, Shopping.ItemName(item) or ""
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
    row.note:SetPoint("RIGHT", row.keep, "LEFT", -STEP_GAP, 0)
end

local function FillMade(row, e, plan)
    if not row.keep then KeepButton(row) end
    local planned = plan.planned[e.item]
    row.keep:SetShown(planned and true or false)
    row.note:SetPoint("RIGHT", planned and row.keep or row, planned and "LEFT" or "RIGHT", planned and -STEP_GAP or 0, 0)
    local saves = plan.saves[e.item]
    row.item = e.item
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
    side.madeHead:SetShown(#makes > 0)
    if #makes > 0 then y = PlaceHead(side.madeHead, y - SECTION_GAP) end
    for i = 1, math.max(#makes, #side.made) do
        local e = makes[i]
        local row = (e or side.made[i]) and SideRow(side.made, i)
        if e and i <= SIDE_MADE then
            FillMade(row, e, plan)
            y = PlaceRow(row, y)
        elseif row then
            row:Hide()
        end
    end
end

local function RenderSide()
    if not side then return end
    local api = ns.ProfWindowAPI
    if not On() or (api and api.Linked()) then return side:Hide() end
    local materials, made, plan = Shopping.Materials()
    SortedCrafts()
    side.hint:SetShown(#crafts == 0)
    side.craftsHead:SetShown(#crafts > 0)
    side.materialsHead:SetShown(#materials > 0)
    local y = DrawCrafts(LIST_TOP)
    y = DrawMaterials(materials, plan, y)
    DrawMade(made, plan, y)
    side.total:SetText(#materials > 0 and Shopping.Estimate(materials, TEXT_UNPRICED) or "")
    side.clear:SetShown(#crafts > 0)
    side:Show()
end

local function AddCrafts()
    return math.max(1, tonumber(addRow and addRow.qty:GetText() or "") or 1)
end

local function OnAdd()
    local info = ns.ProfWindowAPI.SelectedInfo()
    if info then Shopping.Add(info, AddCrafts()) end
end

function ns.ShoppingListWide()
    return On() and true or false
end

function ns.ShoppingListAttach(win)
    BuildSide(win)
    local row = CreateFrame("Frame", nil, win.detail)
    row:SetSize(Style.BUY_ROW_W, Style.BUTTON_H)
    row:Hide()
    addRow = row
    row.add = ns.Button(row, TEXT_ADD, ADD_W, Style.BUTTON_H, OnAdd)
    row.add:SetPoint("RIGHT")
    ns.Tooltip(row.add, TIP_ADD, TIP_ADD_HELP)
    local qty = Widgets.QtyBox(row)
    row.qty = qty
    local plus = ns.Button(row, "+", Style.STEP_W, Style.BUTTON_H, function()
        qty:SetText(tostring(math.min(C.MAX_CRAFTS, AddCrafts() + 1)))
    end)
    plus:SetPoint("RIGHT", row.add, "LEFT", -Style.QTY_GAP, 0)
    qty:SetPoint("RIGHT", plus, "LEFT", -Style.STEP_GAP, 0)
    local minus = ns.Button(row, "-", Style.STEP_W, Style.BUTTON_H, function()
        qty:SetText(tostring(math.max(1, AddCrafts() - 1)))
    end)
    minus:SetPoint("RIGHT", qty, "LEFT", -Style.STEP_GAP, 0)
    ns.Tooltip(qty, TIP_CRAFTS, TIP_CRAFTS_HELP)
end

function ns.ShoppingListRender(info, last)
    if not info then RenderSide() end
    if not addRow then return end
    if not (On() and info and last) or not Shopping.HasNeeds(info.recipeID) then return addRow:Hide() end
    if info.recipeID ~= addRecipe then
        addRecipe = info.recipeID
        addRow.qty:SetText("1")
    end
    local buyRow = addRow:GetParent().buyRow
    addRow:ClearAllPoints()
    if buyRow and buyRow:IsShown() then
        addRow:SetPoint("TOPRIGHT", buyRow, "BOTTOMRIGHT", 0, -ADD_DROP)
    else
        addRow:SetPoint("TOPRIGHT", last, "BOTTOMRIGHT", ADD_OVERHANG, -ADD_DROP)
    end
    addRow:Show()
end

function Shopping.HideAdd()
    if addRow then addRow:Hide() end
end

Shopping.RenderSide = RenderSide

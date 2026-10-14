-- ShoppingAdd.lua: Add to List under a recipe, and the button on the profession window that opens the Shopping List.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local C = P.C
local Shopping = P.Shopping
local Style = P.Style
local Widgets = P.Widgets

local ADD_W = 90
local ADD_DROP = 4
local ADD_OVERHANG = 4
local OPEN_W, OPEN_H, OPEN_RIGHT, OPEN_DROP = 100, 22, 132, 7
local TEXT_ADD = ns.L("Add to List")
local TEXT_OPEN = ns.L("Shopping List")
local TIP_OPEN, TIP_OPEN_HELP = ns.L("Shopping List"), ns.L("Opens your shopping list, which stays open when this window closes.")
local TIP_ADD = ns.L("Add to Shopping List")
local TIP_ADD_HELP = ns.L("Puts the materials for that many crafts on your "
    .. "shopping list: every checked reagent that vendors do not sell, whatever is in your "
    .. "bags. Uncheck a reagent to leave it out. At the auction house the list shows beside "
    .. "it, to check the prices and buy it all.")
local TIP_CRAFTS, TIP_CRAFTS_HELP = ns.L("Crafts"), ns.L("How many crafts Add to List adds the materials for.")

local addRow, addRecipe, opener

local function On()
    return S.Get("enabled") and S.Get("shoppingList")
end

local function AddCrafts()
    return math.max(1, tonumber(addRow and addRow.qty:GetText() or "") or 1)
end

local function OnAdd()
    local info = ns.ProfWindowAPI.SelectedInfo()
    if not info then return end
    Shopping.Add(info, AddCrafts())
    ns.OpenShoppingList()
end

function ns.ShoppingListAttach(win)
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
    opener = ns.Button(win, TEXT_OPEN, OPEN_W, OPEN_H, ns.ToggleShoppingList)
    opener:SetPoint("TOPRIGHT", -OPEN_RIGHT, -OPEN_DROP)
    ns.Tooltip(opener, TIP_OPEN, TIP_OPEN_HELP)
    opener:Hide()
end

function ns.ShoppingListRender(info, last)
    if opener then opener:SetShown(On()) end
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
    if opener then opener:Hide() end
end

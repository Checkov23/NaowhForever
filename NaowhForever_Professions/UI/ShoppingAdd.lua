-- ShoppingAdd.lua: Add to List under a recipe, and the button on the profession window that opens the Shopping List.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local C = P.C
local Shopping = P.Shopping
local Queue = P.CraftQueue
local Style = P.Style
local Widgets = P.Widgets
local TitleButtons = P.TitleButtons

local ADD_W = 90
local ADD_DROP = 4
local ADD_OVERHANG = 4
local OPEN_W, QUEUE_W, OPEN_H = 100, 108, 22
local OPEN_ORDER, QUEUE_ORDER = 2, 3
local TEXT_ADD = ns.L("Add to List")
local TEXT_ADD_QUEUE = ns.L("Add to Queue")
local TEXT_OPEN = ns.L("Shopping List")
local TEXT_QUEUE = ns.L("Crafting Queue")
local TIP_OPEN, TIP_OPEN_HELP = ns.L("Shopping List"), ns.L("Opens your shopping list, which stays open when this window closes.")
local TIP_DOCKED_HELP = ns.L("Opens your shopping list beside this window.")
local TIP_QUEUE_HELP = ns.L("Opens your crafting queue, which stays open when this window closes.")
local TIP_ADD = ns.L("Add to Shopping List")
local TIP_ADD_HELP = ns.L("Puts the materials for that many crafts on your "
    .. "shopping list: every checked reagent that vendors do not sell, whatever is in your "
    .. "bags. Uncheck a reagent to leave it out. At the auction house the list shows beside "
    .. "it, to check the prices and buy it all.")
local TIP_CRAFTS, TIP_CRAFTS_HELP = ns.L("Crafts"), ns.L("How many crafts Add to List adds the materials for.")
local TIP_ADD_QUEUE_HELP = ns.L("Queues this recipe and its prerequisites, then lists their missing materials.")

local addRow, addRecipe, opener, queueOpener

local function On()
    return S.Get("enabled") and S.Get("shoppingList")
end

local function QueueOn()
    return On() and S.Get("craftQueue")
end

local function AddCrafts()
    return math.max(1, tonumber(addRow and addRow.qty:GetText() or "") or 1)
end

local function OnAdd()
    local info = ns.ProfWindowAPI.SelectedInfo()
    if not info then return end
    if QueueOn() then
        Queue.AddWithShopping(info, AddCrafts())
        ns.OpenCraftQueue()
    else
        Shopping.Add(info, AddCrafts())
        ns.OpenShoppingList()
    end
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
    local dock = S.Get("shoppingListDock")
    opener = ns.Button(win, TEXT_OPEN, OPEN_W, OPEN_H, ns.ToggleShoppingList)
    ns.Tooltip(opener, TIP_OPEN, dock and TIP_DOCKED_HELP or TIP_OPEN_HELP)
    opener:Hide()
    TitleButtons.Add(opener, OPEN_ORDER)
    queueOpener = ns.Button(win, TEXT_QUEUE, QUEUE_W, OPEN_H, ns.ToggleCraftQueue)
    ns.Tooltip(queueOpener, TEXT_QUEUE, TIP_QUEUE_HELP)
    queueOpener:Hide()
    TitleButtons.Add(queueOpener, QUEUE_ORDER)
    if dock then ns.ShoppingListDockTo(win) end
end

function ns.ShoppingListRender(info, last)
    if opener then opener:SetShown(On()) end
    if queueOpener then queueOpener:SetShown(QueueOn()) end
    if not addRow then return end
    local queue = QueueOn()
    if not (On() and info and last) or (not queue and not Shopping.HasNeeds(info.recipeID)) then
        return addRow:Hide()
    end
    ns.SetButtonText(addRow.add, queue and TEXT_ADD_QUEUE or TEXT_ADD)
    addRow.add._tipTitle = queue and TEXT_QUEUE or TIP_ADD
    addRow.add._tipBody = queue and TIP_ADD_QUEUE_HELP or TIP_ADD_HELP
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
    if queueOpener then queueOpener:Hide() end
end

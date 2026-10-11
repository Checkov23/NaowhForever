-- BuyRow.lua: the row under a recipe's reagents that buys them, on the auction house or at an open merchant.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local S = P.Settings
local C = P.C
local R = P.Recipes
local V = P.Vendors
local Text = P.Text
local Style = P.Style

local BUY_ALL_W = 110
local COST_GAP = 8
local ROW_DROP = 4
local ROW_OVERHANG = 4
local TEXT_BUY, TEXT_BUY_ALL = ns.L("Buy"), ns.L("Buy All")
local TEXT_BUY_ALL_COUNT = ns.L("Buy All (%d)")
local TEXT_ALL_IT_HAS = ns.L("  (all it has)")
local TEXT_TOTAL = ns.L("Total")
local TEXT_ITEM = ns.L("Item ")
local TEXT_LINE = "%dx %s"
local TIP_VENDOR = ns.L("Buy at Vendor")
local TIP_VENDOR_HELP = ns.L("Buys from this merchant, in one click, every checked reagent it "
    .. "sells, for that many crafts, whatever is already in your bags. Set the number "
    .. "with the - and + beside it; uncheck a reagent to leave it out.")
local TIP_AH = ns.L("Buy on AH")
local TIP_AH_HELP = ns.L("Buys on the auction house the materials for that many crafts, "
    .. "whatever is already in your bags: every checked reagent that vendors do not "
    .. "sell. Set the number with the - and + beside it; uncheck a reagent to leave it "
    .. "out. Each material asks for the price now and waits for you to confirm.")
local TIP_CRAFTS = ns.L("Crafts to Buy For")
local TIP_CRAFTS_HELP = ns.L("How many crafts Buy buys the materials for.")
local TIP_ALL = ns.L("Buy All at Vendor")
local TIP_ALL_HELP = ns.L("Buys what your bags lack of this merchant's reagents for %d crafts, "
    .. "the orange number next to the recipe, so Create All can make them all. Uncheck a "
    .. "reagent to leave it out.")

local win, buyRecipe

local BuyRow = {}
P.BuyRow = BuyRow

local function Crafts()
    local box = win and win.detail and win.detail.buyQty
    return math.max(1, tonumber(box and box:GetText() or "") or 1)
end

local function ResetCount(recipeID)
    if recipeID == buyRecipe then return end
    buyRecipe = recipeID
    win.detail.buyQty:SetText("1")
end

local function Note()
    local row = win and win.detail and win.detail.buyRow
    if not row then return end
    local info = row.vendor and R.SelectedInfo()
    if not info then return row.cost:SetText("") end
    local _, total = V.List(info.recipeID, Crafts())
    row.cost:SetText(Text.Money(total))
    P.Widgets.SetColor(row.cost, GetMoney() < total and Style.RED_RGB or T.muted)
end

local function VendorTooltip(crafts, topUp)
    local info = R.SelectedInfo()
    if not info then return end
    local list, total = V.List(info.recipeID, crafts or Crafts(), topUp)
    GameTooltip:AddLine(" ")
    for _, e in ipairs(list) do
        local name = C_Item.GetItemNameByID(e.itemID) or (TEXT_ITEM .. e.itemID)
        GameTooltip:AddDoubleLine(TEXT_LINE:format(e.count, name) .. (e.short and TEXT_ALL_IT_HAS or ""),
            Text.Money(e.cost), 1, 1, 1, 1, 1, 1)
    end
    local gold = Style.GOLD_RGB
    GameTooltip:AddDoubleLine(TEXT_TOTAL, Text.Money(total), gold.r, gold.g, gold.b, 1, 1, 1)
end

local function OnBuy()
    local info = R.SelectedInfo()
    if not info then return end
    if win.detail.buyRow.vendor then return V.Buy(info.recipeID, Crafts()) end
    P.Buyer.Open(win, info.recipeID, Crafts())
end

local function OnBuyEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if win.detail.buyRow.vendor then
        GameTooltip:AddLine(TIP_VENDOR, 1, 1, 1)
        GameTooltip:AddLine(TIP_VENDOR_HELP, T.muted.r, T.muted.g, T.muted.b, true)
        VendorTooltip()
    else
        GameTooltip:AddLine(TIP_AH, 1, 1, 1)
        GameTooltip:AddLine(TIP_AH_HELP, T.muted.r, T.muted.g, T.muted.b, true)
    end
    GameTooltip:Show()
end

local function OnBuyAll()
    local info, crafts = R.SelectedInfo(), win.detail.buyAll.crafts
    if info and crafts then V.Buy(info.recipeID, crafts, true) end
end

local function OnBuyAllEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(TIP_ALL, 1, 1, 1)
    GameTooltip:AddLine(TIP_ALL_HELP:format(self.crafts or 0), T.muted.r, T.muted.g, T.muted.b, true)
    VendorTooltip(self.crafts, true)
    GameTooltip:Show()
end

local function More()
    win.detail.buyQty:SetText(tostring(math.min(C.MAX_CRAFTS, Crafts() + 1)))
end

local function Fewer()
    win.detail.buyQty:SetText(tostring(math.max(1, Crafts() - 1)))
end

function BuyRow.Build(frame, d)
    win = frame
    local row = CreateFrame("Frame", nil, d)
    row:SetSize(Style.BUY_ROW_W, Style.BUTTON_H)
    d.buyRow = row
    d.buyMats = ns.Button(row, TEXT_BUY, Style.ACTION_W, Style.BUTTON_H, OnBuy)
    d.buyMats:SetPoint("RIGHT")
    d.buyMats:HookScript("OnEnter", OnBuyEnter)
    d.buyMats:HookScript("OnLeave", GameTooltip_Hide)
    local buyQty = P.Widgets.QtyBox(row)
    d.buyQty = buyQty
    local buyPlus = ns.Button(row, "+", Style.STEP_W, Style.BUTTON_H, More)
    buyPlus:SetPoint("RIGHT", d.buyMats, "LEFT", -Style.QTY_GAP, 0)
    buyQty:SetPoint("RIGHT", buyPlus, "LEFT", -Style.STEP_GAP, 0)
    local buyMinus = ns.Button(row, "-", Style.STEP_W, Style.BUTTON_H, Fewer)
    buyMinus:SetPoint("RIGHT", buyQty, "LEFT", -Style.STEP_GAP, 0)
    ns.Tooltip(buyQty, TIP_CRAFTS, TIP_CRAFTS_HELP)
    row.cost = ns.Font(row, Style.FONT, nil, T.muted)
    row.cost:SetPoint("RIGHT", buyMinus, "LEFT", -COST_GAP, 0)
    buyQty:SetScript("OnTextChanged", Note)
    d.buyAll = ns.Button(row, TEXT_BUY_ALL, BUY_ALL_W, Style.BUTTON_H, OnBuyAll)
    d.buyAll:SetPoint("LEFT", row, "LEFT", -Style.BUY_ROW_W, 0)
    d.buyAll:HookScript("OnEnter", OnBuyAllEnter)
    d.buyAll:HookScript("OnLeave", GameTooltip_Hide)
    d.buyAll:Hide()
    row:Hide()
end

function BuyRow.Render(info, last)
    local d = win.detail
    ResetCount(info.recipeID)
    local ahOpen = P.AH.Open()
    local atAH = S.Get("buyMaterials") and ahOpen and P.Buyer.HasMaterials(info.recipeID)
    local atVendor = not atAH and not ahOpen and S.Get("buyVendor") and V.Open() and V.Sells(info.recipeID)
    d.buyRow:SetShown(last ~= nil and (atAH or atVendor) and true or false)
    d.buyRow.vendor = atVendor and true or false
    Note()
    local all = atVendor and V.CraftableWithVendor(info) or nil
    if all and all <= R.Craftable(info) then all = nil end
    d.buyAll.crafts = all
    d.buyAll:SetShown(d.buyRow:IsShown() and all ~= nil)
    if all then ns.SetButtonText(d.buyAll, TEXT_BUY_ALL_COUNT:format(all)) end
    if last then
        d.buyRow:ClearAllPoints()
        d.buyRow:SetPoint("TOPRIGHT", last, "BOTTOMRIGHT", ROW_OVERHANG, -ROW_DROP)
    end
end

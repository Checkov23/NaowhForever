-- Reagents.lua: a recipe's reagent rows: icon, name, have and need, the Bags and Bank columns, the box to tick.
local ns = _G.NaowhForever

local T = ns.THEME
local Parts = ns.Shared.Parts

local P = ns.Professions
local S = P.Settings
local W = P.State
local R = P.Recipes
local V = P.Vendors
local Prices = P.Prices
local Orders = P.Orders
local Text = P.Text
local Style = P.Style
local Widgets = P.Widgets
local SetColor = Widgets.SetColor

local LABEL_GAP = 6
local ROW_SHRINK = 4
local ICON_SHRINK = 6
local CHECK_X = 1
local TEXT_GAP = 6
local NAME_DROP = 2
local COLUMN_DROP = 2
local VALUE_DROP = 1
local BRING_STEP = 18
local BRING_BOX = 36
local BRING_GAP = 2
local BRING_W = BRING_STEP + BRING_GAP + BRING_BOX + BRING_GAP + BRING_STEP
local BRING_INSET = 2
local BRING_LETTERS = 4
local NAME_GAP = 8
local ROUND = P.C.ROUND
local TEXT_REAGENTS = ns.L("Reagents:")
local TEXT_BANK, TEXT_BAGS = ns.L("Bank"), ns.L("Bags")
local TEXT_COUNT = "%d/%d"
local TEXT_BUY_MORE = ns.L("   %sbuy %d more|r")
local TEXT_ORDER_COUNT = ns.L("%d needed   %s%d in bags|r")
local TEXT_SOLD = ns.L(" Sold by vendors")
local TEXT_SOLD_FOR = ns.L(" Sold by vendors: %s")
local TIP_BRING = ns.L("I bring this")
local TIP_BRING_HELP = ns.L("Tick a material you hand the crafter: all the crafts need of it. "
    .. "Use - and + beside it to bring only part.")
local TIP_COST = ns.L("Count in the cost")
local TIP_COST_HELP = ns.L("Uncheck a reagent you already have: the crafting profit then leaves it "
    .. "out, for every recipe that uses it.")
local TIP_MATERIALS = ns.L("Your Materials")
local TIP_MATERIALS_HELP = ns.L("How many of this material you hand the crafter. "
    .. "Ticking the box fills in all the crafts need; - and + change it by one.")

local Reagents = {}
P.Reagents = Reagents

local function OrderChanged()
    P.Detail.Render()
    P.OrderPanel.Render()
end

local function OnCheck(self)
    local r = self:GetParent()
    if W.linked then
        if r.draft then r.draft.bring[r.itemID] = self:GetChecked() or nil end
        return OrderChanged()
    end
    R.Owned()[r.itemID] = not self:GetChecked() or nil
    Prices.ClearCache()
    P.Entries.Build()
    P.List.Render()
    P.Detail.Render()
end

local function OnCheckEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if W.linked then
        GameTooltip:AddLine(TIP_BRING, 1, 1, 1)
        GameTooltip:AddLine(TIP_BRING_HELP, T.muted.r, T.muted.g, T.muted.b, true)
        return GameTooltip:Show()
    end
    GameTooltip:AddLine(TIP_COST, 1, 1, 1)
    GameTooltip:AddLine(TIP_COST_HELP, T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function Step(r, delta)
    if not r.draft then return end
    local data
    for _, reagent in ipairs(r.draft.reagents) do
        if reagent.itemID == r.itemID then data = reagent end
    end
    if not data then return end
    local total = data.need * r.draft.crafts
    local n = math.max(0, math.min(total, Orders.Bringing(r.draft, data) + delta))
    r.draft.bring[r.itemID] = n > 0 and (n == total or n) or nil
    OrderChanged()
end

local function OnBringTyped(self, user)
    local r = self.reagentRow
    if not (user and r.draft) then return end
    local n = tonumber(self:GetText() or "")
    r.draft.bring[r.itemID] = (n and n > 0) and n or nil
    r.check:SetChecked(n ~= nil and n > 0)
    P.OrderPanel.RenderValue()
    P.OrderPanel.Render()
end

local function OnBringDone()
    P.Detail.Render()
end

local function OnRowClick(self)
    if IsModifiedClick("CHATLINK") then
        local _, link = C_Item.GetItemInfo(self.itemID)
        P.AH.ShiftClick(self.itemID, link)
    end
end

local function OnRowEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.itemID)
    if self.vendor then
        local c, price = Style.VENDOR_RGB, V.Price(self.itemID)
        local sold = price and TEXT_SOLD_FOR:format(Parts.Coins(math.floor(price + ROUND))) or TEXT_SOLD
        GameTooltip:AddLine(Style.VENDOR_ICON .. sold, c.r, c.g, c.b)
    end
    GameTooltip:Show()
end

local function Column(r, right)
    local head = ns.Font(r, Style.FONT_SMALL, nil, T.muted)
    head:SetPoint("TOPRIGHT", right, -COLUMN_DROP)
    head:SetWidth(Style.REAGENT_COL_W)
    head:SetJustifyH("RIGHT")
    local value = ns.Font(r, Style.FONT, nil)
    value:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", 0, -VALUE_DROP)
    value:SetWidth(Style.REAGENT_COL_W)
    value:SetJustifyH("RIGHT")
    return head, value
end

local function BuildBring(r)
    r.bringRow = CreateFrame("Frame", nil, r)
    r.bringRow:SetSize(BRING_W, BRING_STEP)
    r.bringRow:SetPoint("RIGHT")
    r.bringRow:Hide()
    local minus = ns.Button(r.bringRow, "-", BRING_STEP, BRING_STEP, function() Step(r, -1) end)
    minus:SetPoint("LEFT")
    local plus = ns.Button(r.bringRow, "+", BRING_STEP, BRING_STEP, function() Step(r, 1) end)
    plus:SetPoint("RIGHT")
    r.bring = ns.NewEditBox(r.bringRow)
    r.bring.reagentRow = r
    r.bring:SetPoint("LEFT", minus, "RIGHT", BRING_GAP, 0)
    r.bring:SetPoint("RIGHT", plus, "LEFT", -BRING_GAP, 0)
    r.bring:SetHeight(BRING_STEP)
    r.bring:SetTextInsets(BRING_INSET, BRING_INSET, 0, 0)
    r.bring:SetNumeric(true)
    r.bring:SetMaxLetters(BRING_LETTERS)
    r.bring:SetJustifyH("CENTER")
    r.bring:SetScript("OnTextChanged", OnBringTyped)
    r.bring:SetScript("OnEscapePressed", r.bring.ClearFocus)
    r.bring:SetScript("OnEnterPressed", r.bring.ClearFocus)
    r.bring:SetScript("OnEditFocusLost", OnBringDone)
    ns.Tooltip(r.bring, TIP_MATERIALS, TIP_MATERIALS_HELP)
end

local function NewRow(parent, label, i)
    local r = CreateFrame("Button", nil, parent)
    r:SetSize(Style.PANE_INNER_W, Style.REAGENT_H - ROW_SHRINK)
    r:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -LABEL_GAP - (i - 1) * Style.REAGENT_H)
    r.check = Widgets.CheckBox(r)
    r.check:SetPoint("LEFT", CHECK_X, 0)
    r.check:SetScript("OnClick", OnCheck)
    r.check:HookScript("OnEnter", OnCheckEnter)
    r.check:HookScript("OnLeave", GameTooltip_Hide)
    r.check:Hide()
    r.icon = Widgets.Crop(r:CreateTexture(nil, "ARTWORK"))
    r.icon:SetSize(Style.REAGENT_H - ICON_SHRINK, Style.REAGENT_H - ICON_SHRINK)
    r.icon:SetPoint("LEFT")
    r.bankLabel, r.bank = Column(r, 0)
    r.bankLabel:SetText(TEXT_BANK)
    r.bagsLabel, r.bags = Column(r, -Style.REAGENT_COL_W)
    r.bagsLabel:SetText(TEXT_BAGS)
    BuildBring(r)
    r.name = ns.Font(r, Style.FONT, nil)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.count = ns.Font(r, Style.FONT, nil)
    r.count:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -VALUE_DROP)
    r:SetScript("OnClick", OnRowClick)
    r:SetScript("OnEnter", OnRowEnter)
    r:SetScript("OnLeave", GameTooltip_Hide)
    return r
end

function Reagents.Build(parent)
    local label = ns.Font(parent, Style.FONT, nil, Style.GOLD_RGB)
    label:SetText(TEXT_REAGENTS)
    local rows = {}
    for i = 1, Style.MAX_REAGENTS do rows[i] = NewRow(parent, label, i) end
    return label, rows
end

local function ShowColumns(r, showBags, showBank)
    r.bagsLabel:SetShown(showBags)
    r.bags:SetShown(showBags)
    r.bankLabel:SetShown(showBank)
    r.bank:SetShown(showBank)
    r.bagsLabel:ClearAllPoints()
    r.bagsLabel:SetPoint("TOPRIGHT", showBank and -Style.REAGENT_COL_W or 0, -COLUMN_DROP)
end

local function PlaceIcon(r, checks)
    r.icon:ClearAllPoints()
    if checks then
        r.icon:SetPoint("LEFT", r.check, "RIGHT", TEXT_GAP, 0)
    else
        r.icon:SetPoint("LEFT")
    end
end

local function FillColumns(r, itemID, have, showBags, showBank)
    if showBags then
        r.bags:SetText(have)
        SetColor(r.bags, have > 0 and T.fg or T.muted)
    end
    if showBank then
        local bank = R.BankCount(itemID)
        r.bank:SetText(bank)
        SetColor(r.bank, bank > 0 and T.accent or T.muted)
    end
end

local function SetName(r, name, itemID)
    r.vendor = V.IsVendorItem(itemID)
    r.name:SetText((name or "") .. (r.vendor and "  " .. Style.VENDOR_ICON or ""))
end

local function FillRow(r, data, target, checks, owned, showBags, showBank)
    local cols = (showBags and 1 or 0) + (showBank and 1 or 0)
    local name = C_Item.GetItemNameByID(data.itemID)
    if not name then R.Request(data.itemID) end
    local have = R.ItemCount(data.itemID)
    r.itemID = data.itemID
    r.icon:SetTexture(C_Item.GetItemIconByID(data.itemID))
    r.check:SetShown(checks)
    r.check:SetChecked(not owned[data.itemID])
    PlaceIcon(r, checks)
    r.icon:SetDesaturated(checks and owned[data.itemID] == true)
    local buy = target and V.IsVendorItem(data.itemID) and target * data.need - have or 0
    r.count:SetText(TEXT_COUNT:format(have, data.need)
        .. (buy > 0 and TEXT_BUY_MORE:format(Text.Hex(Style.VENDOR_RGB), buy) or ""))
    SetColor(r.count, have >= data.need and T.fg or Style.RED_RGB)
    r.draft = nil
    r.bringRow:Hide()
    ShowColumns(r, showBags, showBank)
    r.name:ClearAllPoints()
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", TEXT_GAP, -NAME_DROP)
    r.name:SetPoint("RIGHT", -cols * Style.REAGENT_COL_W - TEXT_GAP, 0)
    FillColumns(r, data.itemID, have, showBags, showBank)
    SetName(r, name, data.itemID)
    r:Show()
end

function Reagents.Fill(rows, reagents, target, max)
    local showBags, showBank = S.Get("bagReagents"), S.Get("bankReagents")
    local checks = Prices.ProfitShown() or (S.Get("buyMaterials") and P.AH.Open())
        or (S.Get("buyVendor") and V.Open())
    local owned = R.Owned()
    for i, r in ipairs(rows) do
        local data = i <= max and reagents[i]
        if data then
            FillRow(r, data, target, checks, owned, showBags, showBank)
        else
            r:Hide()
        end
    end
end

local function FillOrderRow(r, d, data)
    local name = R.ItemName(data.itemID)
    local total, mine = data.need * d.crafts, Orders.Bringing(d, data)
    local have = R.ItemCount(data.itemID)
    r.itemID, r.draft = data.itemID, d
    r.icon:SetTexture(C_Item.GetItemIconByID(data.itemID))
    r.check:Show()
    r.check:SetChecked(mine > 0)
    PlaceIcon(r, true)
    r.icon:SetDesaturated(false)
    r.count:SetText(TEXT_ORDER_COUNT:format(total, Text.Hex(have >= mine and T.muted or Style.RED_RGB), have))
    SetColor(r.count, T.fg)
    r.bagsLabel:Hide()
    r.bags:Hide()
    r.bankLabel:Hide()
    r.bank:Hide()
    r.bringRow:Show()
    if not r.bring:HasFocus() then r.bring:SetText(tostring(mine)) end
    r.name:ClearAllPoints()
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", TEXT_GAP, -NAME_DROP)
    r.name:SetPoint("RIGHT", r.bringRow, "LEFT", -NAME_GAP, 0)
    SetName(r, name, data.itemID)
    r:Show()
end

function Reagents.FillOrder(rows, d)
    for i, r in ipairs(rows) do
        local data = d.reagents[i]
        if data then
            FillOrderRow(r, d, data)
        else
            r.draft = nil
            r:Hide()
        end
    end
end

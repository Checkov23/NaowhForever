-- PickRow.lua: a pick in a slot's picker, and the hover, clicks and move buttons a backup shares (B.View.PickRow).
local ns = _G.NaowhForever

local GetItemInfo = C_Item.GetItemInfo
local GetItemIconByID = C_Item.GetItemIconByID

local T = ns.THEME
local B = ns.BiS
local Shared = ns.Shared
local Items, Parts = Shared.Items, Shared.Parts
local Tip = Parts.Tip
local Cells = B.View.Cells
local St = B.Style

local CARD_PAD, ICON, ITEM_H = St.CARD_PAD, St.ICON, St.ITEM_H
local PLACE_DOT, ACTION_GAP, NAME_GAP, TIP_X = St.PLACE_DOT, St.ACTION_GAP, St.NAME_GAP, St.CURSOR_TIP_X
local CARD_DROP = Parts.CARD_DROP
local BAND_IN = 1
local NAME_TOP = 1
local ACTIONS = 3
local ACTIONS_W = -(St.ACTION + ACTION_GAP) * ACTIONS
local UP, DOWN = -1, 1
local MARK_GAP = "  "
local TEXT_REMOVE, TEXT_DOWN, TEXT_UP = ns.L("Remove"), ns.L("Move down"), ns.L("Move up")
local WOWHEAD_KIND = B.C.WOWHEAD_KIND
local HINT = { list = ns.L("Right-click: Wowhead link") .. PLACE_DOT .. ns.L("Shift-click: link"),
    own = ns.L("Right-click: Wowhead link") .. PLACE_DOT .. ns.L("Shift-click: link"),
    add = ns.L("Click: add it") .. PLACE_DOT .. ns.L("Right-click: Wowhead link") }

local orders = {}

local function Order(order)
    local text = orders[order]
    if not text then
        text = ns.Color("muted", order .. ".") .. MARK_GAP
        orders[order] = text
    end
    return text
end

local function ShowActions(row, shown)
    local always = row.mode == "own"
    for _, button in ipairs(row.actions) do button:SetShown(row.canAct[button] and (always or shown)) end
end

local function Enter(row)
    row.hover:Show()
    ShowActions(row, true)
end

local function TipEnter(zone)
    local row = zone:GetParent()
    if row.mode ~= "add" or not row.rank then return Cells.ItemTip(zone, row.itemID, HINT[row.mode]) end
    if not Tip(zone, "ANCHOR_CURSOR_RIGHT", TIP_X, 0) then return end
    GameTooltip:SetItemByID(row.itemID)
    Cells.ForeverTip(row.itemID)
    GameTooltip:AddLine(Parts.RankLine(row.rank))
    GameTooltip:Show()
end

local function Leave(row)
    if row:IsMouseOver() then return end
    row.hover:Hide()
    ShowActions(row, false)
    GameTooltip:Hide()
end

local function Clicked(row, button)
    if button == "RightButton" then
        Parts.CopyWowhead(WOWHEAD_KIND, row.itemID, C_Item.GetItemNameByID(row.itemID))
        return
    end
    if IsModifiedClick() then
        local _, link = GetItemInfo(row.itemID)
        if link then HandleModifiedItemClick(link) end
    elseif row.mode == "add" then
        ns.AddBisPick(row.slot, row.itemID)
    end
end

local function MoveUp(button) ns.MoveBisPick(button.row.slot, button.row.itemID, UP) end
local function MoveDown(button) ns.MoveBisPick(button.row.slot, button.row.itemID, DOWN) end
local function Remove(button) ns.RemoveBisPick(button.row.slot, button.row.itemID) end

local function ActionLeave(button)
    Leave(button.row)
end

local function Action(row, onClick, texture, tip)
    local button = Parts.IconButton(row, onClick, texture, 0, tip)
    button.row = row
    button:HookScript("OnLeave", ActionLeave)
    row.actions[#row.actions + 1] = button
    return button
end

local function Actions(row, right)
    row.actions, row.canAct = {}, {}
    row.remove = Action(row, Remove, St.CROSS, TEXT_REMOVE)
    row.remove:SetPoint("RIGHT", right, 0)
    row.down = Action(row, MoveDown, St.UP, TEXT_DOWN)
    row.down.icon:SetTexCoord(0, 1, 1, 0)
    row.down:SetPoint("RIGHT", row.remove, "LEFT", -ACTION_GAP, 0)
    row.up = Action(row, MoveUp, St.UP, TEXT_UP)
    row.up:SetPoint("RIGHT", row.down, "LEFT", -ACTION_GAP, 0)
end

local function Band(row, alpha)
    local band = ns.Solid(row, "BACKGROUND", T.fg, alpha)
    band:SetPoint("TOPLEFT", -CARD_PAD + BAND_IN, 0)
    band:SetPoint("BOTTOMRIGHT", CARD_PAD - BAND_IN, 0)
    return band
end

local function Line(row, size, color)
    local text = ns.Font(row, size, nil, color)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

local function New(view)
    local row = CreateFrame("Button", nil, view)
    row:SetHeight(ITEM_H)
    row.hover = Band(row, St.HOVER)
    row.hover:Hide()
    row.stripe = Band(row, St.STRIPE)
    row.worn = Parts.WornBar(row, CARD_PAD)
    local icon = Parts.ItemIcon(row, ICON)
    Cells.TipZone(row, icon, ITEM_H, TipEnter)
    icon:SetPoint("LEFT", 0, 0)
    row.iconFrame, row.icon = icon, icon.texture
    Actions(row, 0)
    row.name = Line(row, St.TEXT_SIZE)
    row.name:SetPoint("TOPLEFT", icon, "TOPRIGHT", NAME_GAP, -NAME_TOP)
    row.meta = Line(row, St.SMALL_SIZE, T.muted)
    row.meta:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", NAME_GAP, NAME_TOP)
    Cells.SourceZone(row)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", Clicked)
    row:SetScript("OnEnter", Enter)
    row:SetScript("OnLeave", Leave)
    return row
end

local function Set(row, slot, itemID, rank, mode, count, order)
    local view = row:GetParent()
    row.slot, row.itemID, row.rank, row.mode = slot, itemID, rank, mode
    row.hover:Hide()
    row.stripe:SetShown(view.striped)
    local right = mode == "add" and 0 or ACTIONS_W
    row.name:SetPoint("RIGHT", right, 0)
    row.meta:SetPoint("RIGHT", right, 0)
    row.icon:SetTexture(GetItemIconByID(itemID))
    local name = GetItemInfo(itemID)
    if not name then view.waitingFor[itemID] = true end
    local worn = Items.Wearing(slot, itemID)
    row.worn:SetShown(worn)
    Parts.MarkForever(row.iconFrame, itemID)
    row.name:SetText((order and Order(order) or "") .. Cells.Named(itemID, name) .. MARK_GAP
        .. Parts.RankMark(rank, CARD_DROP))
    Cells.FitTip(row)
    row.meta:SetText(Cells.Meta(itemID, view.playerLevel) .. Cells.KeptTail(not worn and Items.Kept(itemID) or ""))
    Cells.FitSource(row, itemID)
    local mine = mode ~= "add"
    row.canAct[row.up] = mine and rank > 1
    row.canAct[row.down] = mine and rank < count
    row.canAct[row.remove] = mine
    ShowActions(row, false)
    return ITEM_H, name == nil
end

B.View.Kinds.pick = { New = New, Set = Set }
B.View.PickRow = { Enter = Enter, Leave = Leave, TipEnter = TipEnter, Clicked = Clicked, Actions = Actions,
    ShowActions = ShowActions }

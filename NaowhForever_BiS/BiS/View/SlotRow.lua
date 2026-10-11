-- SlotRow.lua: a slot's row on your list: the slot, its BiS, the gain, where it drops, its picks.
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

local ROW_H, ROW_ICON = St.ROW_H, St.ROW_ICON
local STATUS_W, SLOT_W, META_W, TAIL_W = St.STATUS_W, St.SLOT_W, St.META_W, St.TAIL_W
local INSET, GAP, NAME_GAP = St.STATUS_W, St.COLUMN_GAP, St.NAME_GAP
local PLACE_DOT, TITLE_RGB, TIP_X = St.PLACE_DOT, St.TIP_TITLE_RGB, St.CURSOR_TIP_X
local SLOT_NAME_PAD = 8
local ARROW_SIZE, ARROW_GAP = 10, 4
local OPEN_TURN = St.OPEN_TURN
local TEXT_HINT = ns.L("Click: change picks") .. PLACE_DOT .. ns.L("Right-click: Wowhead link")
local TEXT_PICK_IT = ns.L("Click to pick its BiS.")
local TEXT_ADD_BACKUP = ns.L("Add a backup pick")
local TEXT_PICK_BIS = ns.L("Pick its BiS")
local TEXT_PICKS = ns.L("picks")
local WOWHEAD_KIND = B.C.WOWHEAD_KIND

local Picks = B.View.Memo("%d %s")

local function RowClicked(row, button)
    if button == "RightButton" then
        if row.bis then Parts.CopyWowhead(WOWHEAD_KIND, row.bis, C_Item.GetItemNameByID(row.bis)) end
        return
    end
    if row.bis and IsModifiedClick() then
        local _, link = GetItemInfo(row.bis)
        if link then HandleModifiedItemClick(link) end
        return
    end
    Cells.OpenPicker(row.slot, row)
end

local function RowEnter(row)
    row.hover:Show()
    row.add:SetShown(row.count == 1)
end

local function GainTip(gain)
    if not gain or (ns.StatWeights and ns.StatWeights.On()) then return end
    local spec = B.Lists.CurrentSpec()
    GameTooltip:AddLine(Parts.UpgradeLine(gain, spec and spec.name))
end

local function ItemTipEnter(zone, row)
    if not Tip(zone, "ANCHOR_CURSOR_RIGHT", TIP_X, 0) then return end
    GameTooltip:SetItemByID(row.bis)
    Cells.ForeverTip(row.bis)
    local gains = row:GetParent().gains
    GainTip(gains and gains[row.slot])
    GameTooltip:AddLine(TEXT_HINT, T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Show()
end

local function SlotTipEnter(zone)
    local row = zone:GetParent()
    if row.bis then return ItemTipEnter(zone, row) end
    if not Tip(zone, "ANCHOR_TOP") then return end
    GameTooltip:SetText(Items.SlotName(row.slot), TITLE_RGB.r, TITLE_RGB.g, TITLE_RGB.b)
    GameTooltip:AddLine(TEXT_PICK_IT, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    GameTooltip:Show()
end

local function RowLeave(row)
    if row:IsMouseOver() then return end
    row.hover:Hide()
    row.add:Hide()
    GameTooltip:Hide()
end

local function ChildLeave(child)
    RowLeave(child:GetParent())
end

local function ToggleClicked(button)
    local row = button:GetParent()
    row:GetParent():Toggle(row.slot)
end

local function AddClicked(button)
    local row = button:GetParent()
    Cells.OpenPicker(row.slot, row)
end

local function Bands(row)
    row.hover = ns.Solid(row, "BACKGROUND", T.fg, St.HOVER)
    row.hover:SetAllPoints()
    row.hover:Hide()
    row.lit = ns.Solid(row, "BACKGROUND", T.accent, St.LIT)
    row.lit:SetAllPoints()
    row.lit:Hide()
    row.stripe = ns.Solid(row, "BACKGROUND", T.fg, St.STRIPE)
    row.stripe:SetAllPoints()
end

local function Toggle(row)
    local toggle = CreateFrame("Button", nil, row)
    toggle:SetSize(TAIL_W, ROW_H)
    toggle:SetPoint("RIGHT", -INSET, 0)
    toggle.arrow = Parts.Arrow(toggle, ARROW_SIZE, T.muted)
    toggle.arrow:SetPoint("RIGHT", 0, 0)
    toggle.text = ns.Font(toggle, St.SMALL_SIZE, nil, T.muted)
    toggle.text:SetPoint("RIGHT", toggle.arrow, "LEFT", -ARROW_GAP, 0)
    toggle:SetScript("OnClick", ToggleClicked)
    toggle:SetScript("OnLeave", ChildLeave)
    row.toggle = toggle
end

local function Meta(row)
    row.meta = ns.Font(row, St.SMALL_SIZE, nil, T.muted)
    row.meta:SetPoint("RIGHT", -(TAIL_W + INSET + GAP), 0)
    row.meta:SetWidth(META_W)
    row.meta:SetJustifyH("LEFT")
    row.meta:SetWordWrap(false)
end

local function New(view)
    local row = CreateFrame("Button", nil, view)
    row:SetHeight(ROW_H)
    Bands(row)
    row.slotName = ns.Font(row, St.TEXT_SIZE, nil, T.muted)
    row.slotName:SetPoint("LEFT", STATUS_W, 0)
    row.slotName:SetWidth(SLOT_W - SLOT_NAME_PAD)
    row.slotName:SetJustifyH("LEFT")
    row.slotName:SetWordWrap(false)
    local icon = Parts.ItemIcon(row, ROW_ICON)
    Cells.TipZone(row, icon, ROW_H, SlotTipEnter)
    icon:SetPoint("LEFT", STATUS_W + SLOT_W, 0)
    row.iconFrame, row.icon = icon, icon.texture
    Toggle(row)
    row.add = Parts.IconButton(row, AddClicked, St.PLUS, 0, TEXT_ADD_BACKUP)
    row.add:SetPoint("RIGHT", -INSET, 0)
    row.add:HookScript("OnLeave", ChildLeave)
    row.add:Hide()
    Meta(row)
    Cells.SourceZone(row)
    Cells.Gain(row, row.meta, GAP)
    row.worn = Parts.WornBar(row, 0)
    row.name = ns.Font(row, St.TEXT_SIZE)
    row.name:SetPoint("LEFT", icon, "RIGHT", NAME_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", RowClicked)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    return row
end

local function SetEmpty(row, slot)
    row.icon:SetTexture(select(2, C_PaperDollInfo.GetInventorySlotInfoForInvSlot(slot)))
    row.name:SetText(ns.Color("accentSoft", TEXT_PICK_BIS))
    Cells.FitTip(row)
    row.meta:SetText("")
    Cells.FitSource(row, nil)
    row.worn:Hide()
    return ROW_H
end

local function SetItem(row, view, slot, bis)
    local name = GetItemInfo(bis)
    if not name then view.waitingFor[bis] = true end
    local worn = Items.Wearing(slot, bis)
    row.icon:SetTexture(GetItemIconByID(bis))
    row.name:SetText(Cells.Named(bis, name))
    Cells.FitTip(row)
    row.meta:SetText(Cells.Meta(bis, view.playerLevel) .. Cells.KeptTail(not worn and Items.Kept(bis) or ""))
    Cells.FitSource(row, bis)
    row.worn:SetShown(worn)
    return ROW_H, name == nil
end

local function Set(row, slot, bis, count, open)
    local view = row:GetParent()
    row.slot, row.bis, row.count = slot, bis, count
    row.hover:Hide()
    row.add:Hide()
    row.stripe:SetShown(view.striped)
    row.slotName:SetText(Items.SlotName(slot))
    local gain = bis and view.gains and view.gains[slot]
    Cells.PaintGain(row.gain, gain, view.mostGain)
    row.name:SetPoint("RIGHT", gain and row.gain or row.meta, "LEFT", -GAP, 0)
    Parts.MarkForever(row.iconFrame, bis)
    row.toggle:SetShown(count > 1)
    if count > 1 then
        row.toggle.text:SetText(Picks(count, TEXT_PICKS))
        row.toggle.arrow:SetRotation(open and OPEN_TURN or 0)
    end
    if not bis then return SetEmpty(row, slot) end
    return SetItem(row, view, slot, bis)
end

B.View.Kinds.slotRow = { New = New, Set = Set }

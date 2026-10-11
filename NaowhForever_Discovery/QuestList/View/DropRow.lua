-- DropRow.lua: a rare's drop under its row while open: icon, name, chance, and a tick once it dropped for you.
local ns = _G.NaowhForever

local T = ns.THEME
local Completo = ns.Completo
local C = Completo.C
local Parts = ns.Shared.Parts
local Style = Completo.Style
local R = Completo.Rares
local V = Completo.View

local DROP_H = 22
local TICK_GAP = 6
local CHANCE_RIGHT = Style.PIN_RIGHT + Style.ACTION + Style.ARROW_GAP * 2 + Style.ARROW_SIZE
local NAME_RIGHT = V.NAME_X + Style.DROP_ICON + Style.ICON_GAP + Style.STATUS_W + Style.PIN_RIGHT
local TEXT_NONE = ns.L("No special drops: no rare or epic items, nor recipes")
local TEXT_DROPPED = ns.L("This rare dropped it for you.")
local TEXT_WOWHEAD = ns.L("Right-click: Wowhead link")

local function DropEnter(row)
    row.hover:Show()
    local item = row.item
    if not item then return end
    local have = Style.HAVE_RGB
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(item[C.LOOT_ID])
    GameTooltip:AddLine(" ")
    if R.NewInForever(item) then GameTooltip:AddLine(Parts.ForeverLine()) end
    if row.tick:IsShown() then GameTooltip:AddLine(TEXT_DROPPED, have.r, have.g, have.b) end
    GameTooltip:AddLine(TEXT_WOWHEAD, V.Soft())
    GameTooltip:Show()
end

local function DropMouseUp(row, button)
    local item = row.item
    if button == "RightButton" and item then Parts.CopyWowhead("item", item[C.LOOT_ID], item[C.LOOT_NAME]) end
end

local function NewDrop(parent)
    local row = V.NewRow(parent)
    row.divider:Hide()
    row.icon = Parts.ItemIcon(row, Style.DROP_ICON)
    row.icon:SetPoint("LEFT", V.NAME_X, 0)
    row.name = V.Line(row, Style.TEXT_SIZE, T.fg)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", Style.ICON_GAP, 0)
    row.chance = ns.Font(row, Style.SMALL_SIZE, nil, T.muted)
    row.chance:SetPoint("RIGHT", -CHANCE_RIGHT, 0)
    row.chance:SetJustifyH("RIGHT")
    row.tick = V.Tick(row)
    row.tick:SetPoint("RIGHT", row.chance, "LEFT", -TICK_GAP, 0)
    row:SetScript("OnEnter", DropEnter)
    row:SetScript("OnLeave", V.RowLeave)
    row:SetScript("OnMouseUp", DropMouseUp)
    return row
end

local function SetNone(row)
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", V.NAME_X, 0)
    row.name:SetText(TEXT_NONE)
    V.Paint(row.name, T.muted)
    row.chance:SetText("")
    return DROP_H
end

local function ItemName(item)
    local name = item[C.LOOT_NAME]
    if not R.NewInForever(item) then return name end
    return name .. Parts.ForeverInline(C.FOREVER_SIGN_SIZE, Parts.CARD_DROP)
end

local function SetDrop(row, item, npc, stripe)
    row.item = item
    row.tick:SetShown(item ~= nil and R.Dropped(npc, item[C.LOOT_ID]))
    V.Reset(row, stripe)
    row.icon:SetShown(item ~= nil)
    if not item then return SetNone(row) end
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row.icon, "RIGHT", Style.ICON_GAP, 0)
    row.icon.texture:SetTexture(C_Item.GetItemIconByID(item[C.LOOT_ID]) or C.FALLBACK_ICON)
    row.name:SetText(ItemName(item))
    V.Paint(row.name, ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item[C.LOOT_QUALITY]] or T.fg)
    row.name:SetWidth(row:GetWidth() - NAME_RIGHT)
    row.chance:SetText(R.ChanceText(item[C.LOOT_CHANCE]))
    return DROP_H
end

V.Kinds.drop = { New = NewDrop, Set = SetDrop }

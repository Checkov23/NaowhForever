-- Gear.lua: Group Inspect's gear slot: the item's icon in its quality's edge, a missing enchant, its tooltip, or the slot's empty art.
local ns = _G.NaowhForever

local GetItemIconByID = C_Item.GetItemIconByID

local T = ns.THEME
local GI = ns.GroupInspect
local UI = GI.UI
local St = UI.Style
local Parts, Items = ns.Shared.Parts, ns.Shared.Items

local BORDER_RGB, WARN_RGB, TITLE_RGB = St.BORDER_RGB, St.WARN_RGB, St.TIP_TITLE_RGB
local BIS_RANK = 1
local NO_ENCHANT, EMPTY = ns.L("No enchant"), ns.L("Empty")
local THEIR_BIS = ns.L("Their BiS")
local BARE = { color = WARN_RGB, tip = NO_ENCHANT }

local emptyArt = {}
local theirBis

local function TheirBis()
    theirBis = theirBis or Parts.RankMark(BIS_RANK) .. " " .. St.BIS_CODE .. THEIR_BIS .. "|r"
    return theirBis
end

local function GearEnter(icon)
    if GameTooltip:IsForbidden() then return end
    local guid = icon.holder.guid
    local rec = guid and GI.Member(guid)
    local entry = rec and rec.gear and rec.gear[icon.slot]
    if not Parts.Tip(icon, "ANCHOR_RIGHT") then return end
    if entry and entry.link then
        GameTooltip:SetHyperlink(entry.link)
        if entry.bis then GameTooltip:AddLine(TheirBis()) end
        if entry.enchanted == false then GameTooltip:AddLine(NO_ENCHANT, WARN_RGB.r, WARN_RGB.g, WARN_RGB.b) end
    else
        GameTooltip:SetText(Items.SlotName(icon.slot) or "", TITLE_RGB.r, TITLE_RGB.g, TITLE_RGB.b)
        GameTooltip:AddLine(rec and rec.gear and EMPTY or UI.NOT_READ, T.muted.r, T.muted.g, T.muted.b)
    end
    GameTooltip:Show()
end

function UI.GearIcon(parent, size, slot, holder, marks)
    local icon = Parts.ItemIcon(parent, size)
    icon.slot, icon.holder = slot, holder
    if marks then icon.marks = Parts.ItemMarks(icon, size) end
    icon.bare = ns.BiS.View.EnchantBadge(icon, BARE)
    icon.bare:EnableMouse(false)
    icon:EnableMouse(true)
    icon:SetScript("OnEnter", GearEnter)
    icon:SetScript("OnLeave", GameTooltip_Hide)
    return icon
end

local function EmptyArt(slot)
    local art = emptyArt[slot]
    if art == nil then
        local info = C_PaperDollInfo and C_PaperDollInfo.GetInventorySlotInfoForInvSlot
        art = info and select(2, info(slot)) or false
        emptyArt[slot] = art
    end
    return art or nil
end

function UI.PaintGear(icon, entry)
    local texture = icon.texture
    local id = entry and entry.id
    if id then
        texture:SetTexture(GetItemIconByID(id))
        texture:SetAlpha(1)
        local quality = entry.quality and ITEM_QUALITY_COLORS[entry.quality]
        local edge = quality or BORDER_RGB
        icon.edge:SetColor(edge.r, edge.g, edge.b, 1)
        icon.bare:SetShown(entry.enchanted == false)
    else
        texture:SetTexture(EmptyArt(icon.slot))
        texture:SetAlpha(St.EMPTY_ALPHA)
        icon.edge:SetColor(BORDER_RGB.r, BORDER_RGB.g, BORDER_RGB.b, 1)
        icon.bare:Hide()
    end
    if icon.marks then
        Parts.PaintItemMarks(icon.marks, id and entry.ilvl, id and entry.bis and BIS_RANK or nil,
            id ~= nil and Parts.IsForever("items", id))
    end
end

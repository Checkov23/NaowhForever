-- Kinds.lua: the rows every page has (ns.Shared.Kinds): a section title, a note, a card, and an item in a list you keep.
local ns = _G.NaowhForever
local T = ns.THEME
local Shared = ns.Shared
local Kinds, Parts, Items = Shared.Kinds, Shared.Parts, Shared.Items
local St = Shared.Style

local GetItemInfo = C_Item.GetItemInfo
local GetItemIconByID = C_Item.GetItemIconByID

local SECTION_H, SECTION_TIGHT_H, INDENT, NOTE_PAD = St.SECTION_H, St.SECTION_TIGHT_H, St.INDENT, St.NOTE_PAD
local CARD_FILL, CARD_HEADER_H, BORDER_RGB = St.CARD_FILL, St.CARD_HEADER_H, St.BORDER_RGB
local ICON, ITEM_H, GAP, HOVER = St.ICON, St.ITEM_H, St.GAP, St.HOVER
local TEXT_SIZE, SMALL_SIZE = St.TEXT_SIZE, St.SMALL_SIZE
local SECTION_ARROW, ARROW_OUT, ARROW_ROOM = 12, 2, 14
local TITLE_RISE, LINK_RISE = 5, 4
local OPEN_TURN = St.OPEN_TURN
local COUNT_GAP = "   "
local NOTE_TOP = 2
local ITEM_TEXT_GAP = 8
local ITEM_NAME_TOP = 1
local ITEM_VALUE_W = 96

local labels = {}

local function Label(title, count)
    local byCount = labels[title]
    if not byCount then
        byCount = { [false] = ns.Upper(ns.L(title)) }
        labels[title] = byCount
    end
    local key = count or false
    local label = byCount[key]
    if label then return label end
    label = byCount[false] .. COUNT_GAP .. ns.Color("muted", count)
    byCount[key] = label
    return label
end

local function SectionClicked(row)
    if row.onToggle then row.onToggle() end
end

local function SectionLinkClicked(link)
    local row = link:GetParent()
    if row.onLink then row.onLink(row.linkArg, link) end
end

local function PaintLink(link, text, onClick, tip, tipLine)
    Parts.SetLink(link, text)
    link.disabled, link.tip, link.tipLine = onClick == nil, tip, tipLine
    Parts.LinkColor(link, link.disabled and T.muted or T.accentSoft)
end

local function NewSection(view)
    local row = CreateFrame("Frame", nil, view)
    row.text = ns.Font(row, TEXT_SIZE, nil, T.accentSoft)
    row.arrow = Parts.Arrow(row, SECTION_ARROW, T.accentSoft)
    row.arrow:SetPoint("BOTTOMLEFT", -ARROW_OUT, TITLE_RISE)
    row.line = ns.Solid(row, "ARTWORK", T.line, 1)
    row.line:SetPoint("BOTTOMLEFT")
    row.line:SetPoint("BOTTOMRIGHT")
    ns.Hairline(row.line, "h")
    row.link = Parts.Link(row, SectionLinkClicked, true)
    row.link:SetPoint("BOTTOMRIGHT", 0, LINK_RISE)
    row:SetScript("OnMouseUp", SectionClicked)
    return row
end

local function SetSection(row, title, count, open, onToggle, linkText, onLink, linkArg, linkTip, linkTipLine)
    row.onToggle, row.onLink, row.linkArg = onToggle, onLink, linkArg
    row:EnableMouse(onToggle ~= nil)
    row.arrow:SetShown(onToggle ~= nil)
    row.arrow:SetRotation(open and OPEN_TURN or 0)
    row.text:ClearAllPoints()
    local inset = row:GetParent().inset or 0
    row.text:SetPoint("BOTTOMLEFT", (onToggle and ARROW_ROOM or 0) + inset, TITLE_RISE)
    row.link:SetPoint("BOTTOMRIGHT", -inset, LINK_RISE)
    row.text:SetText(Label(title, count))
    row.link:SetShown(linkText ~= nil)
    if linkText then
        PaintLink(row.link, linkText, onLink, linkTip, linkTipLine)
        row.link.underline:Hide()
    end
    return row:GetParent().tightTitles and SECTION_TIGHT_H or SECTION_H
end

local function NewNote(view)
    local row = CreateFrame("Frame", nil, view)
    row.text = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.text:SetPoint("TOPLEFT", INDENT, -NOTE_TOP)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)
    return row
end

local function SetNote(row, text)
    row.text:SetWidth(row:GetWidth() - INDENT)
    row.text:SetText(ns.L(text))
    return math.ceil(row.text:GetStringHeight()) + NOTE_PAD
end

local function NewCard(view)
    local card = CreateFrame("Frame", nil, view)
    ns.Solid(card, "BACKGROUND", T.fg, CARD_FILL):SetAllPoints()
    card.edge = ns.Border(card, BORDER_RGB)
    card.note = ns.Font(card, SMALL_SIZE, nil, T.muted)
    card.note:SetPoint("CENTER", 0, -CARD_HEADER_H / 2)
    card.note:Hide()
    return card
end

local function ItemEnter(row)
    row.hover:Show()
    if not Parts.Tip(row, "ANCHOR_RIGHT") then return end
    GameTooltip:SetItemByID(row.itemID)
    GameTooltip:Show()
end

local function ItemLeave(row)
    if row:IsMouseOver() then return end
    row.hover:Hide()
    GameTooltip:Hide()
end

local function RemoveClicked(button)
    local row = button:GetParent()
    if row.onRemove then row.onRemove(row.itemID) end
end

local function TagClicked(link)
    local row = link:GetParent()
    if row.onTag then row.onTag(row.itemID) end
end

local function PartLeave(part)
    ItemLeave(part:GetParent())
end

local function ItemDrop(row)
    local onDrop = row:GetParent().onDrop
    if onDrop and GetCursorInfo() then onDrop() end
end

local function ItemLine(row, size, color, icon, point, iconPoint, y)
    local line = ns.Font(row, size, nil, color)
    line:SetPoint(point, icon, iconPoint, ITEM_TEXT_GAP, y)
    line:SetJustifyH("LEFT")
    line:SetWordWrap(false)
    return line
end

local function NewItem(view)
    local row = CreateFrame("Button", nil, view)
    row.hover = ns.Solid(row, "BACKGROUND", T.fg, HOVER)
    row.hover:SetAllPoints()
    row.hover:Hide()
    local icon = Parts.ItemIcon(row, ICON)
    icon:SetPoint("LEFT", 0, 0)
    row.icon = icon.texture
    row.remove = Parts.IconButton(row, RemoveClicked, St.CROSS, 0)
    row.remove:SetPoint("RIGHT", 0, 0)
    row.remove:HookScript("OnLeave", PartLeave)
    row.value = ns.Font(row, TEXT_SIZE, nil, T.fg)
    row.value:SetWidth(ITEM_VALUE_W)
    row.value:SetPoint("RIGHT", row.remove, "LEFT", -GAP * 2, 0)
    row.value:SetJustifyH("RIGHT")
    row.tag = Parts.Link(row, TagClicked)
    row.tag:SetPoint("RIGHT", row.value, "LEFT", -GAP * 2, 0)
    row.tag:HookScript("OnLeave", PartLeave)
    row.name = ItemLine(row, TEXT_SIZE, nil, icon, "TOPLEFT", "TOPRIGHT", -ITEM_NAME_TOP)
    row.meta = ItemLine(row, SMALL_SIZE, T.muted, icon, "BOTTOMLEFT", "BOTTOMRIGHT", ITEM_NAME_TOP)
    row:SetScript("OnEnter", ItemEnter)
    row:SetScript("OnLeave", ItemLeave)
    row:SetScript("OnReceiveDrag", ItemDrop)
    row:SetScript("OnClick", ItemDrop)
    return row
end

local function ItemName(row, itemID)
    local refused = Items.Refused(itemID)
    local name = not refused and GetItemInfo(itemID) or nil
    if not (name or refused) then row:GetParent().waitingFor[itemID] = true end
    local color = Items.QualityColor(itemID) or T.fg
    row.name:SetTextColor(color.r, color.g, color.b)
    row.name:SetText(name or Items.Name(itemID))
    return name, refused
end

local function SetItem(row, itemID, meta, value, onRemove, removeTip, tag, onTag, tagTip)
    row.itemID, row.onRemove, row.onTag = itemID, onRemove, onTag
    row.hover:Hide()
    row.icon:SetTexture(GetItemIconByID(itemID))
    local name, refused = ItemName(row, itemID)
    row.meta:SetText(meta)
    row.value:SetText(value)
    row.remove:SetShown(onRemove ~= nil)
    row.remove.tip = removeTip
    row.tag:SetShown(tag ~= nil)
    local right = row.value
    if tag then
        PaintLink(row.tag, tag, onTag, tagTip, row.tag.tipLine)
        right = row.tag
    end
    row.name:SetPoint("RIGHT", right, "LEFT", -GAP, 0)
    row.meta:SetPoint("RIGHT", right, "LEFT", -GAP, 0)
    return ITEM_H, name == nil and not refused
end

Kinds.section = { New = NewSection, Set = SetSection }
Kinds.note = { New = NewNote, Set = SetNote }
Kinds.card = { New = NewCard }
Kinds.item = { New = NewItem, Set = SetItem }

-- ItemRows.lua: one item of a boss's loot or a faction's rewards.
local ns = _G.NaowhForever

local GetItemInfo = C_Item.GetItemInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetItemIconByID = C_Item.GetItemIconByID
local GetItemQualityColor = C_Item.GetItemQualityColor
local IsEquippedItem = C_Item.IsEquippedItem
local GetCoinTextureString = C_CurrencyInfo.GetCoinTextureString

local T = ns.THEME
local J = ns.Journal
local Loot = J.Loot
local Rep = J.Reputation
local FACT = J.FACT
local View = J.View
local Kinds, Parts = View.Kinds, View.Parts
local Items = ns.Shared.Items
local Refused = Items.Refused
local Tip, ForeverLine, IsForever = Parts.Tip, Parts.ForeverLine, Parts.IsForever
local Inline, RankMark = Parts.Inline, Parts.RankMark
local INLINE_DROP, CARD_DROP = Parts.TOOLTIP_DROP, Parts.CARD_DROP
local ONE_HAND_ONLY = Items.ONE_HAND_ONLY
local St = J.Style
local RED_CODE, UPGRADE_CODE = St.RED_CODE, St.UPGRADE_CODE
local LOOK_CODE, LOOK_RGB, HAVE_RGB, HANGER = St.LOOK_CODE, St.LOOK_RGB, St.HAVE_RGB, St.HANGER
local UPGRADE_ATLAS = St.UPGRADE_ATLAS
local PLACE_DOT, CARD_PAD, ICON, ITEM_H = St.PLACE_DOT, St.CARD_PAD, St.ICON, St.ITEM_H
local CHANCE_W, CHANCE_BAR_W, CHANCE_HIGH, CHANCE_FAIR = St.CHANCE_W, St.CHANCE_BAR_W, St.CHANCE_HIGH,
    St.CHANCE_FAIR
local UNUSABLE, ROUND, BAG = St.UNUSABLE, St.ROUND, St.BAG
local DENSE_H, DENSE_ICON, DENSE_CHANCE_TOP, DENSE_BAR_BOTTOM = St.DENSE_H, St.DENSE_ICON, St.DENSE_CHANCE_TOP,
    St.DENSE_BAR_BOTTOM
local TEXT_SIZE, SMALL_SIZE, TIP_X = St.TEXT_SIZE, St.SMALL_SIZE, St.CURSOR_TIP_X

local WEAPON, ARMOR, RECIPE = 2, J.C.ITEM_ARMOR, J.C.ITEM_RECIPE
local ARMOR_TYPES = { [1] = true, [2] = true, [3] = true, [4] = true }
local COMMON = 1
local NAME_TOP, CHANCE_TOP, BAR_BOTTOM = 1, 8, 11
local TEXT_GAP = 8
local BAR_H = 4
local DEEP = 0.6
local MIN_FILL = 0.1
local EVERY_KILL = 100
local ROUND_HALF = J.C.ROUND_HALF
local PRICE_COLUMN = "price"

local TEXT_EVERY_KILL = ns.L("every kill")
local TEXT_ONE_IN = ns.L("1 in %d")
local TEXT_ALWAYS = "100%"
local TEXT_CHANCE_VALUE = "%s%%%s"
local TEXT_CHANCE_UNKNOWN = ns.L("Drop chance not known yet")
local TEXT_DROP_CHANCE = ns.L("% drop chance")
local TEXT_ITEM_LEVEL = ns.L("Item Level ")
local TEXT_REQUIRES = ns.L("Requires Level ")
local TEXT_NEEDS = ns.L("Needs ")
local TEXT_PRICE = ns.L("Price")
local TEXT_PRICE_UNKNOWN = ns.L("not known yet")
local TEXT_AT_QUARTERMASTER = ns.L(" at the quartermaster.")
local TEXT_NO_GOLD = ns.L("No gold price: it is a quest's reward, or costs something else.")
local TEXT_CHANCE_TITLE = ns.L("Drop chance")
local TEXT_CHANCE_HELP = ns.L("From the kills recorded so far. The bar fills, and grows brighter, the likelier it is.")
local TEXT_CHANCE_NONE = ns.L("Not known yet: there is no count of how often it drops.")
local TEXT_MENU_HINT = ns.L("Right-click: menu")
local TEXT_CLICK_HINT = TEXT_MENU_HINT .. PLACE_DOT .. ns.L("Shift-click: link")
local TEXT_UPGRADE = ns.L("Upgrade over what you wear|r")
local TEXT_NEW_LOOK = ns.L("A look you do not have yet|r")
local TEXT_KNOWN = ns.L("Known|r")
local TEXT_LEVEL = ns.L("Level ")
local TEXT_ITEM = ns.L("Item ")
local TEXT_UNDER_ONE = "<1"
local TEXT_NONE = "-"
local TEXT_CODE_END = "|r"
local TEXT_KIND = "%s, %s"
local TAG_SPACE, MARK_SPACE = "   ", "  "

local UPGRADE_ICON = ("|A:%s:0:0:0:%d|a"):format(UPGRADE_ATLAS, -INLINE_DROP)
local UPGRADE_TAG = MARK_SPACE .. ("|A:%s:0:0:0:%d|a"):format(UPGRADE_ATLAS, -CARD_DROP)
local KNOWN_TAG = TAG_SPACE .. Inline(St.CHECK, HAVE_RGB) .. " " .. Items.KEPT_CODE .. TEXT_KNOWN
local NEW_LOOK_ICON = Inline(HANGER, LOOK_RGB)
local NEW_LOOK_TAG = TAG_SPACE .. Inline(HANGER, LOOK_RGB, CARD_DROP)
local NOT_YET_TAG = TAG_SPACE .. J.NOT_YET
local UPGRADE_LINE = UPGRADE_ICON .. " " .. UPGRADE_CODE .. TEXT_UPGRADE
local NEW_LOOK_LINE = NEW_LOOK_ICON .. " " .. LOOK_CODE .. TEXT_NEW_LOOK
local PERCENT = ns.Color("muted", "%")

local keptTags = { [""] = "" }
local tiers = {}

local function RankTag(rank)
    return rank and MARK_SPACE .. RankMark(rank, CARD_DROP) or ""
end

local function Kept(itemID)
    local kept = Items.Kept(itemID)
    local tag = keptTags[kept]
    if not tag then
        tag = TAG_SPACE .. kept
        keptTags[kept] = tag
    end
    return tag
end

local function ItemType(itemID)
    local _, itemType, subType, equipLoc, _, classID = GetItemInfoInstant(itemID)
    local slot = equipLoc and _G[equipLoc] or ""
    local facts = J.Facts(itemID)
    if not (facts and subType) then return slot end
    local class = facts[FACT.CLASS]
    if class == WEAPON then
        return Items.WeaponName(facts[FACT.SUBCLASS], equipLoc)
            or (ONE_HAND_ONLY[equipLoc] and TEXT_KIND:format(subType, slot) or subType)
    end
    if class == ARMOR and ARMOR_TYPES[facts[FACT.SUBCLASS]] then return TEXT_KIND:format(subType, slot) end
    if slot ~= "" then return slot end
    if classID == RECIPE and itemType then return TEXT_KIND:format(itemType, subType) end
    return subType
end

local function TierKey(chance)
    return chance >= CHANCE_HIGH and "accent" or chance >= CHANCE_FAIR and "accentSoft" or "muted"
end

local function KillsPer(chance)
    return math.max(1, math.floor(EVERY_KILL / chance + ROUND_HALF))
end

local function ChanceValue(chance)
    if chance >= EVERY_KILL then return TEXT_ALWAYS .. PLACE_DOT .. TEXT_EVERY_KILL end
    return TEXT_CHANCE_VALUE:format(chance, PLACE_DOT) .. TEXT_ONE_IN:format(KillsPer(chance))
end

local function ChanceLine(chance)
    if not chance then
        return Inline(BAG, T.muted) .. " " .. ns.Color("muted", TEXT_CHANCE_UNKNOWN)
    end
    local key = TierKey(chance)
    local often = chance >= EVERY_KILL and TEXT_EVERY_KILL or TEXT_ONE_IN:format(KillsPer(chance))
    return Inline(BAG, T[key]) .. " " .. ns.Color(key, chance .. TEXT_DROP_CHANCE) .. ns.Color("muted", PLACE_DOT .. often)
end

local function NotYetTip(itemID, facts)
    local r, g, b = GetItemQualityColor(facts[FACT.QUALITY])
    local muted = T.muted
    GameTooltip:SetText(facts[FACT.NAME], r, g, b)
    local kind = ItemType(itemID)
    if kind ~= "" then GameTooltip:AddLine(kind, 1, 1, 1) end
    GameTooltip:AddLine(TEXT_ITEM_LEVEL .. facts[FACT.ITEM_LEVEL], 1, 1, 1)
    if facts[FACT.REQUIRED] > 0 then GameTooltip:AddLine(TEXT_REQUIRES .. facts[FACT.REQUIRED], 1, 1, 1) end
    GameTooltip:AddLine(J.NOT_YET, muted.r, muted.g, muted.b)
end

local function NeedsLine(row)
    if not row.needs then return end
    local color = St.STANDING_RGB[row.needs]
    GameTooltip:AddDoubleLine(TEXT_NEEDS .. Rep.Label(row.needs),
        row.toGo and Rep.ToGoText(row.toGo, row.exact) or "", color.r, color.g, color.b, 1, 1, 1)
end

local function ColumnLine(row)
    local muted = T.muted
    if not row.priced then
        GameTooltip:AddLine(ChanceLine(row.chance))
    elseif row.price then
        GameTooltip:AddDoubleLine(TEXT_PRICE, GetCoinTextureString(row.price), muted.r, muted.g, muted.b, 1, 1, 1)
    else
        GameTooltip:AddDoubleLine(TEXT_PRICE, TEXT_PRICE_UNKNOWN, muted.r, muted.g, muted.b, muted.r, muted.g, muted.b)
    end
end

local function MarkLines(row)
    if row.rank and not ns.QoLSettings.Get("bisTooltip") then
        GameTooltip:AddLine(Parts.RankLine(row.rank))
    end
    if row.upgrade and not (ns.StatWeights and ns.StatWeights.On()) then GameTooltip:AddLine(UPGRADE_LINE) end
    if row.newLook then GameTooltip:AddLine(NEW_LOOK_LINE) end
end

local function ItemEnter(row)
    row.hover:Show()
    local muted = T.muted
    if not Tip(row, "ANCHOR_CURSOR_RIGHT", TIP_X, 0) then return end
    local notYet = J.NotYet[row.itemID]
    if notYet then NotYetTip(row.itemID, notYet) else GameTooltip:SetItemByID(row.itemID) end
    if row.forever then GameTooltip:AddLine(ForeverLine()) end
    NeedsLine(row)
    ColumnLine(row)
    MarkLines(row)
    GameTooltip:AddLine(notYet and TEXT_MENU_HINT or TEXT_CLICK_HINT, muted.r, muted.g, muted.b)
    GameTooltip:Show()
end

local function ItemLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function ItemClick(row, button)
    if button == "RightButton" then
        View.ItemMenu(row, row.itemID, row:GetParent().redrawFn)
        return
    end
    if J.IsNotYet(row.itemID) then return end
    local _, link = GetItemInfo(row.itemID)
    if link then HandleModifiedItemClick(link) end
end

local function PriceEnter(row)
    local muted = T.muted
    GameTooltip:SetText(TEXT_PRICE, 1, 1, 1)
    if row.price then
        GameTooltip:AddLine(GetCoinTextureString(row.price) .. TEXT_AT_QUARTERMASTER, 1, 1, 1, true)
    else
        GameTooltip:AddLine(TEXT_NO_GOLD, muted.r, muted.g, muted.b, true)
    end
    GameTooltip:Show()
end

local function ChanceEnter(zone)
    local row = zone:GetParent()
    row.hover:Show()
    local muted = T.muted
    if not Tip(zone, "ANCHOR_RIGHT") then return end
    if row.priced then return PriceEnter(row) end
    GameTooltip:SetText(TEXT_CHANCE_TITLE, 1, 1, 1)
    local chance = row.chance
    if chance then
        GameTooltip:AddLine(ChanceValue(chance), 1, 1, 1)
        GameTooltip:AddLine(TEXT_CHANCE_HELP, muted.r, muted.g, muted.b, true)
    else
        GameTooltip:AddLine(TEXT_CHANCE_NONE, muted.r, muted.g, muted.b, true)
    end
    GameTooltip:Show()
end

local function ChanceLeave(zone)
    zone:GetParent().hover:Hide()
    GameTooltip:Hide()
end

local function Round(row, layer, color)
    local dot = row:CreateTexture(nil, layer)
    dot:SetTexture(ROUND, nil, nil, "TRILINEAR")
    dot:SetSize(BAR_H, BAR_H)
    dot:SetVertexColor(color.r, color.g, color.b, 1)
    return dot
end

local function Tier(chance)
    local key = TierKey(chance)
    local tier = tiers[key]
    if not tier then
        tier = { deep = CreateColor(0, 0, 0, 1), bright = CreateColor(0, 0, 0, 1) }
        tiers[key] = tier
    end
    local color = T[key]
    tier.color = color
    tier.deep:SetRGBA(color.r * DEEP, color.g * DEEP, color.b * DEEP, 1)
    tier.bright:SetRGBA(color.r, color.g, color.b, 1)
    return tier
end

local function ShowBar(row, bar)
    row.chanceTrack:SetShown(bar)
    row.chanceTrackStart:SetShown(bar)
    row.chanceTrackEnd:SetShown(bar)
    row.chanceBar:SetShown(bar)
    row.chanceStart:SetShown(bar)
    row.chanceEnd:SetShown(bar)
end

local function FillBar(row, chance)
    local tier = Tier(chance)
    row.chanceBar:SetGradient("HORIZONTAL", tier.deep, tier.bright)
    local deep, color = tier.deep, tier.color
    row.chanceStart:SetVertexColor(deep.r, deep.g, deep.b, 1)
    row.chanceEnd:SetVertexColor(color.r, color.g, color.b, 1)
    local fill = (CHANCE_BAR_W - BAR_H) * math.sqrt(math.min(chance, EVERY_KILL) / EVERY_KILL)
    row.chanceBar:SetWidth(math.max(MIN_FILL, fill))
end

local function SetChance(row, chance, shown, top)
    local known = chance ~= nil and chance > 0
    row.chance, row.priced, row.price = known and chance or nil, false, nil
    row.chanceText:ClearAllPoints()
    if known then
        row.chanceText:SetPoint("TOPRIGHT", 0, -top)
        row.chanceText:SetTextColor(T.fg.r, T.fg.g, T.fg.b)
        row.chanceText:SetText(shown and (chance < 1 and TEXT_UNDER_ONE or chance) .. PERCENT or "")
        FillBar(row, chance)
    else
        row.chanceText:SetPoint("RIGHT", 0, 0)
        row.chanceText:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
        row.chanceText:SetText(shown and TEXT_NONE or "")
    end
    ShowBar(row, shown and known)
    row.chanceZone:SetShown(shown)
end

local function SetPrice(row, copper)
    row.chance, row.priced, row.price = nil, true, copper
    row.chanceText:ClearAllPoints()
    row.chanceText:SetPoint("RIGHT", 0, 0)
    if copper then
        row.chanceText:SetTextColor(T.fg.r, T.fg.g, T.fg.b)
        row.chanceText:SetText((Rep.PriceText(copper)))
    else
        row.chanceText:SetTextColor(T.muted.r, T.muted.g, T.muted.b)
        row.chanceText:SetText(TEXT_NONE)
    end
    ShowBar(row, false)
    row.chanceZone:Show()
end

local function NewChanceZone(row)
    local zone = CreateFrame("Frame", nil, row)
    zone:SetPoint("TOPRIGHT")
    zone:SetPoint("BOTTOMRIGHT")
    zone:SetWidth(CHANCE_W)
    zone:SetMouseMotionEnabled(true)
    zone:SetMouseClickEnabled(false)
    zone:SetScript("OnEnter", ChanceEnter)
    zone:SetScript("OnLeave", ChanceLeave)
    return zone
end

local function NewChanceBar(row)
    row.chanceTrack = ns.Solid(row, "BORDER", T.line, 1)
    row.chanceTrack:SetSize(CHANCE_BAR_W - BAR_H, BAR_H)
    row.chanceTrackStart = Round(row, "BORDER", T.line)
    row.chanceTrackStart:SetPoint("CENTER", row.chanceTrack, "LEFT")
    row.chanceTrackEnd = Round(row, "BORDER", T.line)
    row.chanceTrackEnd:SetPoint("CENTER", row.chanceTrack, "RIGHT")
    row.chanceBar = row:CreateTexture(nil, "ARTWORK")
    row.chanceBar:SetColorTexture(1, 1, 1, 1)
    row.chanceBar:SetPoint("LEFT", row.chanceTrack)
    row.chanceBar:SetHeight(BAR_H)
    row.chanceStart = Round(row, "ARTWORK", T.muted)
    row.chanceStart:SetPoint("CENTER", row.chanceBar, "LEFT")
    row.chanceEnd = Round(row, "ARTWORK", T.muted)
    row.chanceEnd:SetPoint("CENTER", row.chanceBar, "RIGHT")
end

local function MetaFont(row)
    local font = ns.Font(row, SMALL_SIZE, nil, T.muted)
    font:SetJustifyH("LEFT")
    font:SetWordWrap(false)
    return font
end

local function NewText(row, frame)
    row.name = ns.Font(row, TEXT_SIZE)
    row.name:SetPoint("TOPLEFT", frame, "TOPRIGHT", TEXT_GAP, -NAME_TOP)
    row.name:SetPoint("RIGHT", -(CHANCE_W + TEXT_GAP), 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.meta = MetaFont(row)
    row.meta:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", TEXT_GAP, NAME_TOP)
    row.metaTail = MetaFont(row)
    row.metaTail:SetPoint("LEFT", row.meta, "RIGHT", 0, 0)
end

local function ItemName(itemID, notYet, refused)
    if notYet then return notYet[FACT.NAME] end
    if refused then return nil end
    local name, _, quality = GetItemInfo(itemID)
    return name, quality
end

local function LevelText(required, playerLevel)
    if required <= 0 then return "" end
    return (required > playerLevel and RED_CODE or "") .. TEXT_LEVEL .. required .. TEXT_CODE_END
end

local function TagText(row, itemID, notYet, known, worn, bare)
    if notYet then return NOT_YET_TAG end
    if known then return KNOWN_TAG end
    if not (worn or bare) then return Kept(itemID) end
    return ""
end

local function SetMeta(row, itemID, facts, view, notYet, known, worn, look, icon)
    local bare = view.bare
    local required = not bare and facts and facts[FACT.REQUIRED] or 0
    local level = LevelText(required, view.playerLevel)
    local kind = ItemType(itemID)
    row.metaTail:SetText(((kind ~= "" and level ~= "") and PLACE_DOT or "") .. level
        .. TagText(row, itemID, notYet, known, worn, bare) .. (look == false and NEW_LOOK_TAG or ""))
    row.meta:SetWidth(0)
    row.meta:SetText(kind)
    local room = row:GetWidth() - icon - TEXT_GAP - (CHANCE_W + TEXT_GAP) - math.ceil(row.metaTail:GetStringWidth())
    row.meta:SetWidth(math.max(1, math.min(math.ceil(row.meta:GetStringWidth()) + 1, room)))
end

local function SetColumn(row, view, chance, price, dense)
    local column = view.column
    if column == PRICE_COLUMN then return SetPrice(row, price) end
    SetChance(row, chance, column == nil and view.showChance, dense and DENSE_CHANCE_TOP or CHANCE_TOP)
end

Kinds.item = {
    New = function(view)
        local row = CreateFrame("Button", nil, view)
        row.hover = Parts.CardBand(row, St.ITEM_HOVER)
        row.hover:Hide()
        row.stripe = Parts.CardBand(row, St.STRIPE)
        row.worn = Parts.WornBar(row, CARD_PAD)
        local frame = Parts.ItemIcon(row, ICON)
        frame:SetPoint("LEFT", 0, 0)
        row.iconFrame, row.icon = frame, frame.texture
        row.chanceText = ns.Font(row, SMALL_SIZE, nil, T.fg)
        row.chanceText:SetJustifyH("RIGHT")
        row.chanceZone = NewChanceZone(row)
        NewChanceBar(row)
        NewText(row, frame)
        row:SetScript("OnEnter", ItemEnter)
        row:SetScript("OnLeave", ItemLeave)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", ItemClick)
        return row
    end,
    Set = function(row, itemID, chance, rank, upgrade, price)
        local view = row:GetParent()
        local dense = view.dense
        local icon = dense and DENSE_ICON or ICON
        row.iconFrame:SetSize(icon, icon)
        row.chanceTrack:SetPoint("BOTTOMRIGHT", -BAR_H / 2, dense and DENSE_BAR_BOTTOM or BAR_BOTTOM)
        row.itemID = itemID
        row.needs, row.toGo, row.exact = nil, nil, nil
        row.hover:Hide()
        row.stripe:SetShown(view.striped)
        local notYet = J.NotYet[itemID]
        row.icon:SetTexture(notYet and notYet[FACT.ICON] or GetItemIconByID(itemID))
        local refused = notYet ~= nil or Refused(itemID)
        local name, quality = ItemName(itemID, notYet, refused)
        if not (name or refused) then view.waitingFor[itemID] = true end
        local facts = J.Facts(itemID)
        quality = quality or (facts and facts[FACT.QUALITY]) or COMMON
        local _, _, _, hex = GetItemQualityColor(quality)
        local bare = view.bare
        local worn = not bare and IsEquippedItem(itemID)
        row.worn:SetShown(worn)
        local look
        if view.filters.showAppearance and not (worn or bare) then look = Loot.Appearance(itemID) end
        local known = not bare and Loot.Recipe(itemID) ~= nil and view:RecipeKnown(itemID)
        row.rank, row.upgrade, row.newLook = rank, upgrade, look == false
        row.forever = IsForever("items", itemID)
        row.name:SetText("|c" .. hex .. (name or (TEXT_ITEM .. itemID)) .. TEXT_CODE_END
            .. RankTag(rank) .. (upgrade and UPGRADE_TAG or ""))
        SetMeta(row, itemID, facts, view, notYet, known, worn, look, icon)
        SetColumn(row, view, chance, price, dense)
        row.keep = rank ~= nil or upgrade
        row.rest = (bare or Loot.Usable(itemID)) and 1 or UNUSABLE
        row:SetAlpha(row.rest)
        return dense and DENSE_H or ITEM_H, name == nil and not refused
    end,
}

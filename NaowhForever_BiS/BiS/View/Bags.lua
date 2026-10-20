-- Bags.lua: Bag Marks, the slot marks on your bags' items, the game's, EllesmereUI's, or Baganator's.
local ns = _G.NaowhForever

local GetContainerItemID = C_Container.GetContainerItemID
local GetContainerItemLink = C_Container.GetContainerItemLink
local GetDetailedItemLevelInfo = C_Item.GetDetailedItemLevelInfo
local GetItemQualityByID = C_Item.GetItemQualityByID
local GetTime = GetTime

local S = ns.QoLSettings
local B = ns.BiS
local Shared = ns.Shared
local Items, Parts, Bags = Shared.Items, Shared.Parts, Shared.Bags
local SW = ns.StatWeights

local OVERLAY = "NaowhForever"
local WIDGET = "NaowhForeverBagMarks"
local TEXT_BAGANATOR = ns.L("Naowh Forever Marks")
local BAGANATOR_CORNER = { corner = "top_left", priority = 1 }
local PLAIN_QUALITY = 1
local PLAIN_LEVEL_RGB = { r = 1, g = 0.82, b = 0 }
local BIND_GAP = 1
local FOREVER_KIND = B.C.FOREVER_KIND
local SETTINGS = { enabled = true, bis = true, bisBagMarks = true }

local sets = {}
local ellesmere = {}
local held = {}
local baganator
local installed, registered = false, false
local weights, power, readAt

local function On()
    return B.On() and S.Get("bisBagMarks") == true
end

local function Marks(button, over)
    local set = sets[button]
    if not set then
        set = Parts.ItemMarks(over, button:GetHeight())
        sets[button] = set
    end
    return set
end

local function Weights()
    local now = GetTime()
    if now ~= readAt then
        readAt = now
        local key = SW.ActiveSpec()
        weights = key and SW.For(key)
        power = weights and SW.Power(weights)
    end
    return weights, power
end

local function PaintLevel(set, id)
    local quality = GetItemQualityByID(id)
    local c = quality and quality > PLAIN_QUALITY and ITEM_QUALITY_COLORS[quality] or PLAIN_LEVEL_RGB
    set.level:SetTextColor(c.r, c.g, c.b)
end

local function Paint(set, id, link)
    if not id then
        set:Hide()
        return false
    end
    set:Show()
    local gear = Items.SlotsFor(id) ~= nil
    local level = gear and GetDetailedItemLevelInfo(link or id) or nil
    local upgrade = gear and SW.BestGain(id, link, Weights()) ~= nil
    local shown = Parts.PaintItemMarks(set, level, ns.IsBisItem(id), Parts.IsForever(FOREVER_KIND, id), upgrade)
    if shown then PaintLevel(set, id) end
    return shown
end

local function GameBag(frame)
    if not On() then return end
    for _, button in frame:EnumerateValidItems() do
        local bag, slot = button:GetBagID(), button:GetID()
        local id = GetContainerItemID(bag, slot)
        local set = sets[button] or (id and Marks(button, button))
        if set then Paint(set, id, id and GetContainerItemLink(bag, slot)) end
    end
end

local function Corners(set, button)
    local bind = button.BindTypeText
    local word = bind and bind:GetText()
    set.rank:ClearAllPoints()
    if word and word ~= "" then
        set.rank:SetPoint("LEFT", bind, "RIGHT", BIND_GAP, 0)
    else
        set.rank:SetPoint("BOTTOMLEFT", Parts.MARK_IN, Parts.MARK_IN)
    end
    local arrow = button.UpgradeIcon
    set.level:ClearAllPoints()
    if arrow and arrow:IsShown() then
        set.level:SetPoint("RIGHT", arrow, "LEFT")
    else
        set.level:SetPoint("BOTTOMRIGHT", -Parts.MARK_IN, Parts.MARK_IN)
    end
end

local function TheirLevel(button, alpha)
    if button.ItemLevelText then button.ItemLevelText:SetAlpha(alpha) end
end

local function EllesmereSlot(button, data)
    local info = data.info
    local id = info and info.itemID
    local set = sets[button]
    if not set then
        if not id then return end
        set = Marks(button, button._textOverlay or button)
        ellesmere[button] = true
    end
    local shown = Paint(set, id, data.itemLink)
    if not id then return end
    Corners(set, button)
    TheirLevel(button, shown and 0 or 1)
end

local function BaganatorInit(button)
    local anchor = CreateFrame("Frame", nil, button)
    held[anchor] = button
    Marks(button, anchor):SetAllPoints(button)
    anchor:Hide()
    return anchor
end

local function BaganatorSlot(anchor, details)
    local set = sets[held[anchor]]
    if not set or not On() then
        if set then set:Hide() end
        anchor:Hide()
        return false
    end
    local id = details and details.itemID
    Paint(set, id, id and details.itemLink)
    anchor:SetShown(id ~= nil)
    return false
end

local function RefreshBaganator()
    if baganator then baganator.RequestItemButtonsRefresh() end
end

local function Repaint()
    Bags.RepaintGame(GameBag)
    if registered then Bags.RefreshEllesmere() end
    RefreshBaganator()
end

local function ListChanged()
    if On() then Repaint() end
end

local function Install()
    installed = true
    Bags.OnGameUpdate(GameBag)
    B.OnListChange(ListChanged)
end

local function Release()
    for button, set in pairs(sets) do
        set:Hide()
        if ellesmere[button] then TheirLevel(button, 1) end
    end
    RefreshBaganator()
end

local function RegisterBaganator(on)
    if baganator or not on then return end
    local api = Bags.Baganator()
    if not api then return end
    baganator = api
    api.RegisterCornerWidget(TEXT_BAGANATOR, WIDGET, BaganatorSlot, BaganatorInit, BAGANATOR_CORNER, true)
end

local function Register(on)
    local bags = Bags.Ellesmere()
    if not bags or on == registered then return end
    registered = on
    if on then
        bags.RegisterItemOverlayIcon(OVERLAY, EllesmereSlot)
    else
        bags.UnregisterItemOverlayIcon(OVERLAY)
    end
end

local function Apply()
    local on = On()
    if on and not installed then Install() end
    if not installed then return end
    Register(on)
    RegisterBaganator(on)
    if on then return Repaint() end
    Release()
end

local function OnSetting(key)
    if SETTINGS[key] then Apply() end
end

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Apply)

-- Paperdoll.lua: your character in your BiS, its slots as the game lays them out (B.View.Paperdoll).
local ns = _G.NaowhForever

local T = ns.THEME
local B = ns.BiS
local C = B.C
local Shared = ns.Shared
local Items, Parts = Shared.Items, Shared.Parts
local Tip = Parts.Tip
local St = B.Style

local OFF_HAND, RANGED = C.OFF_HAND, C.RANGED
local SLOT, SLOT_GAP, MODEL_GAP, DOLL_W = St.SLOT, St.SLOT_GAP, St.MODEL_GAP, St.DOLL_W
local LOOK_W, TURN_SPEED, ZOOM_STEP, ZOOM_MAX = St.LOOK_W, St.TURN_SPEED, St.ZOOM_STEP, St.ZOOM_MAX
local CAMERA, GAINS_H, BORDER_RGB = St.CAMERA, St.GAINS_H, St.BORDER_RGB
local PLACE_DOT, TITLE_RGB, IDLE_RGB = St.PLACE_DOT, St.TIP_TITLE_RGB, St.GOLD_RGB
local CROP_IN, CROP_OUT = St.CROP_IN, St.CROP_OUT
local WORN_DROP, WORN_H = 2, 2
local TOP_H = St.TAB_H + 8
local HINT_Y = 6
local COSMETIC_ALPHA = 0.5
local MODEL_ALPHA = 0.35
local WORN_KEY = 20
local LEFT_SLOTS = { 1, 2, 3, 15, 5, 4, 19, 9 }
local RIGHT_SLOTS = { 10, 6, 7, 8, 11, 12, 13, 14 }
local BOTTOM_SLOTS = { 16, 17, 18 }
local COLUMN_H = #RIGHT_SLOTS * (SLOT + SLOT_GAP) - SLOT_GAP
local DOLL_H = TOP_H + COLUMN_H + MODEL_GAP + SLOT + GAINS_H
local COSMETIC = { [4] = "Shirt", [19] = "Tabard" }
local HAND = { [16] = "MAINHANDSLOT", [17] = "SECONDARYHANDSLOT" }
local LOOKS = { { key = "bis", label = "Your BiS" }, { key = "now", label = "Now" } }
local HIGHLIGHT = "Interface\\Buttons\\ButtonHilight-Square"
local FOREVER_KIND = C.FOREVER_KIND
local TEXT_NO_STATS = "No stats: wear what you like."
local TEXT_PICK_BIS = "Click to pick your BiS."
local TEXT_YOUR_PICKS = "Your %s picks"
local TEXT_OFF_HAND_IDLE = "Unused while your main hand's BiS is a two-hander."
local TEXT_NOT_YOURS = "Not yours yet."
local TEXT_CHANGE = "Click to change them."
local TEXT_HINT = "Drag to turn" .. PLACE_DOT .. "Scroll to zoom" .. PLACE_DOT .. "Right-click to reset"
local BLANK = " "

local function TryOn(model, slot, id)
    model:TryOn(select(2, C_Item.GetItemInfo(id)) or ("item:" .. id), HAND[slot])
end

local function Dress(model)
    local doll = model:GetParent()
    model:SetUnit("player")
    if doll.look ~= "bis" or not doll.list then return end
    model:Undress()
    local idle = B.OffHandIdle(doll.list)
    for _, gear in ipairs(Items.GEAR_SLOTS) do
        local slot = gear[1]
        local id = doll.list.slots[slot]
        if id and slot ~= RANGED and not (slot == OFF_HAND and idle) then TryOn(model, slot, id) end
    end
end

local function Straighten(model)
    model.rotation, model.zoom = 0, 0
    model:SetRotation(0)
    model:SetPortraitZoom(0)
    if model.SetCamDistanceScale then model:SetCamDistanceScale(CAMERA) end
end

local function Turn(model)
    local x = GetCursorPosition()
    model.rotation = model.turnFrom + (x - model.turnAt) * TURN_SPEED
    model:SetRotation(model.rotation)
end

local function ModelDown(model, button)
    if button ~= "LeftButton" then return end
    model.turnAt, model.turnFrom = GetCursorPosition(), model.rotation
    model:SetScript("OnUpdate", Turn)
end

local function ModelUp(model, button)
    model:SetScript("OnUpdate", nil)
    if button == "RightButton" then Straighten(model) end
end

local function ModelWheel(model, delta)
    model.zoom = math.max(0, math.min(ZOOM_MAX, model.zoom + delta * ZOOM_STEP))
    model:SetPortraitZoom(model.zoom)
end

local function ModelShown(model)
    model:RegisterUnitEvent("UNIT_MODEL_CHANGED", "player")
    model:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    Dress(model)
end

local function ModelHidden(model)
    model:UnregisterAllEvents()
    model:SetScript("OnUpdate", nil)
end

local function CosmeticEnter(button)
    if not Tip(button, "ANCHOR_RIGHT") then return end
    GameTooltip:SetText(COSMETIC[button.slot], TITLE_RGB.r, TITLE_RGB.g, TITLE_RGB.b)
    GameTooltip:AddLine(TEXT_NO_STATS, T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Show()
end

local function EmptyTip(label)
    GameTooltip:SetText(label, TITLE_RGB.r, TITLE_RGB.g, TITLE_RGB.b)
    GameTooltip:AddLine(TEXT_PICK_BIS, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    GameTooltip:Show()
end

local function PicksTip(doll, slot, picks, label)
    local soft, muted = T.accentSoft, T.muted
    GameTooltip:SetItemByID(picks[1])
    GameTooltip:AddLine(BLANK)
    GameTooltip:AddLine(TEXT_YOUR_PICKS:format(label), soft.r, soft.g, soft.b)
    for rank, id in ipairs(picks) do
        GameTooltip:AddLine(Parts.RankMark(rank) .. " " .. Items.QualityHex(id) .. Items.Name(id) .. "|r")
    end
    if slot == OFF_HAND and B.OffHandIdle(doll.list) then
        GameTooltip:AddLine(TEXT_OFF_HAND_IDLE, IDLE_RGB.r, IDLE_RGB.g, IDLE_RGB.b, true)
    elseif not Items.Owned(picks[1]) then
        GameTooltip:AddLine(TEXT_NOT_YOURS, muted.r, muted.g, muted.b)
    end
    GameTooltip:AddLine(TEXT_CHANGE, muted.r, muted.g, muted.b)
    GameTooltip:Show()
end

local function SlotEnter(button)
    local doll = button:GetParent()
    doll.onHover(button.slot)
    local slot = button.slot
    local picks = B.Picks(doll.list, slot, doll.picks)
    local label = Items.SlotName(slot)
    if not Tip(button, "ANCHOR_RIGHT") then return end
    if not picks[1] then return EmptyTip(label) end
    if doll.look == "now" and slot ~= RANGED then TryOn(doll.model, slot, picks[1]) end
    PicksTip(doll, slot, picks, label)
end

local function SlotLeave(button)
    local doll = button:GetParent()
    doll.onHover(nil)
    if doll.look == "now" then Dress(doll.model) end
    GameTooltip:Hide()
end

local function SlotClicked(button)
    button:GetParent().onClick(button.slot, button)
end

local function Cosmetic(button, slot)
    button.icon:SetTexture(select(2, C_PaperDollInfo.GetInventorySlotInfoForInvSlot(slot)))
    button.icon:SetTexCoord(0, 1, 0, 1)
    button.icon:SetDesaturated(true)
    button:SetAlpha(COSMETIC_ALPHA)
    button:SetScript("OnEnter", CosmeticEnter)
    button:SetScript("OnLeave", GameTooltip_Hide)
end

local function WornLine(button)
    local worn = ns.Solid(button, "ARTWORK", St.HAVE_RGB, 1)
    worn:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -WORN_DROP)
    worn:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -WORN_DROP)
    worn:SetHeight(WORN_H)
    worn:Hide()
    return worn
end

local function SlotButton(doll, slot, x, y)
    local button = CreateFrame("Button", nil, doll)
    button:SetSize(SLOT, SLOT)
    button:SetPoint("TOPLEFT", x, y)
    button.slot = slot
    local icon = Parts.ItemIcon(button, SLOT)
    icon:SetAllPoints()
    button.iconFrame, button.icon, button.edge = icon, icon.texture, icon.edge
    if COSMETIC[slot] then return Cosmetic(button, slot) end
    button.wand = B.View.EnchantBadge(button)
    button.marks = Parts.ItemMarks(icon, SLOT)
    button.worn = WornLine(button)
    button:SetHighlightTexture(HIGHLIGHT, "ADD")
    button:SetScript("OnClick", SlotClicked)
    button:SetScript("OnEnter", SlotEnter)
    button:SetScript("OnLeave", SlotLeave)
    doll.buttons[#doll.buttons + 1] = button
end

local function Outfit(list)
    local sum = 0
    for _, gear in ipairs(Items.GEAR_SLOTS) do
        local slot = gear[1]
        sum = sum + (list.slots[slot] or 0) * slot + (GetInventoryItemID("player", slot) or 0) * (slot + WORN_KEY)
    end
    return sum
end

local function PaintIcon(button, slot, id)
    if id then
        button.icon:SetTexture(C_Item.GetItemIconByID(id))
        button.icon:SetTexCoord(CROP_IN, CROP_OUT, CROP_IN, CROP_OUT)
    else
        button.icon:SetTexture(select(2, C_PaperDollInfo.GetInventorySlotInfoForInvSlot(slot)))
        button.icon:SetTexCoord(0, 1, 0, 1)
    end
end

local function PaintButton(button, list)
    local slot = button.slot
    local id = list.slots[slot]
    PaintIcon(button, slot, id)
    local edge = id and Items.QualityColor(id) or BORDER_RGB
    button.edge:SetColor(edge.r, edge.g, edge.b, 1)
    button.icon:SetDesaturated(slot == OFF_HAND and B.OffHandIdle(list))
    button.worn:SetShown(id ~= nil and Items.Wearing(slot, id))
    Parts.PaintItemMarks(button.marks, id and (B.Rankings.ItemLevel(id) or C_Item.GetDetailedItemLevelInfo(id)),
        nil, Parts.IsForever(FOREVER_KIND, id))
    B.View.PaintEnchantBadge(button.wand, slot)
end

local function Model(doll)
    local model = CreateFrame("DressUpModel", nil, doll)
    model:SetPoint("TOPLEFT", SLOT + MODEL_GAP, -TOP_H)
    model:SetSize(DOLL_W - 2 * (SLOT + MODEL_GAP), COLUMN_H)
    ns.Solid(doll, "BACKGROUND", T.panel, MODEL_ALPHA):SetAllPoints(model)
    model:EnableMouse(true)
    model:EnableMouseWheel(true)
    model:SetScript("OnShow", ModelShown)
    model:SetScript("OnHide", ModelHidden)
    model:SetScript("OnEvent", Dress)
    model:SetScript("OnMouseDown", ModelDown)
    model:SetScript("OnMouseUp", ModelUp)
    model:SetScript("OnMouseWheel", ModelWheel)
    Straighten(model)
    return model
end

local function Slots(doll)
    local row = SLOT + SLOT_GAP
    for i, slot in ipairs(LEFT_SLOTS) do SlotButton(doll, slot, 0, -(TOP_H + (i - 1) * row)) end
    for i, slot in ipairs(RIGHT_SLOTS) do SlotButton(doll, slot, DOLL_W - SLOT, -(TOP_H + (i - 1) * row)) end
    local step = SLOT + MODEL_GAP
    local left = (DOLL_W - #BOTTOM_SLOTS * step + MODEL_GAP) / 2
    for i, slot in ipairs(BOTTOM_SLOTS) do
        SlotButton(doll, slot, left + (i - 1) * step, -(TOP_H + COLUMN_H + MODEL_GAP))
    end
end

local Doll = {}

function Doll:Refresh()
    self.outfit = nil
    self:Paint(self.list)
end

function Doll:Paint(list)
    self.list = list
    for _, button in ipairs(self.buttons) do PaintButton(button, list) end
    local outfit = Outfit(list)
    if outfit == self.outfit then return end
    self.outfit = outfit
    Dress(self.model)
    local gains = B.View.PaintScoreCard(self.gainsBlock, list, self.look)
    if not gains.waiting then return end
    local ids = wipe(self.ids)
    for _, gear in ipairs(Items.GEAR_SLOTS) do ids[#ids + 1] = list.slots[gear[1]] end
    Items.OnLoaded(ids, self.refreshFn)
end

function Doll:SetLook(key)
    self.look = key
    Parts.PaintTabs(self.looks, key)
    Dress(self.model)
    B.View.PaintScoreLook(self.gainsBlock, key)
end

function B.View.Paperdoll(parent, onHover, onClick)
    local doll = Mixin(CreateFrame("Frame", nil, parent), Doll)
    doll:SetSize(DOLL_W, DOLL_H)
    doll.buttons, doll.picks, doll.ids, doll.onHover, doll.onClick = {}, {}, {}, onHover, onClick
    doll.look = "bis"
    doll.refreshFn = function() doll:Refresh() end
    local model = Model(doll)
    doll.model = model
    doll.looks = Parts.Tabs(doll, LOOK_W, LOOKS, function(key) doll:SetLook(key) end)
    doll.looks:SetPoint("TOP", doll, "TOP", 0, 0)
    Parts.PaintTabs(doll.looks, doll.look)
    local hint = ns.Font(doll, St.TINY_SIZE, nil, T.muted)
    hint:SetPoint("BOTTOM", model, "BOTTOM", 0, HINT_Y)
    hint:SetText(TEXT_HINT)
    Slots(doll)
    doll.gainsBlock = B.View.ScoreCard(doll, DOLL_W)
    doll.gainsBlock:SetPoint("TOPLEFT", 0, -(TOP_H + COLUMN_H + MODEL_GAP + SLOT + MODEL_GAP))
    ModelShown(model)
    return doll
end

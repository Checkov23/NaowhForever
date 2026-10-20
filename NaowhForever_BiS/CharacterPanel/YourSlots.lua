-- YourSlots.lua: your character panel's slots: our look over the game's, and their marks.
local ns = _G.NaowhForever

local GetInventoryItemID = GetInventoryItemID
local GetInventoryItemLink = GetInventoryItemLink
local GetDetailedItemLevelInfo = C_Item.GetDetailedItemLevelInfo

local S = ns.QoLSettings
local CP = ns.CharacterPanel
local B = ns.BiS
local Parts = ns.Shared.Parts
local PaintEdge, FadeSlot, CropSlot, SlotOver = CP.PaintEdge, CP.FadeSlot, CP.CropSlot, CP.SlotOver

local NO_AMMO = 0
local SLOT_BUTTON = "Character%sSlot"
local FOREVER_KIND = B.C.FOREVER_KIND

local overs = {}
local installed = false

local function Paint(over)
    local slot = over.slot
    local id = GetInventoryItemID("player", slot)
    if id == NO_AMMO then id = nil end
    over:Show()
    PaintEdge(over, id)
    local link = id and S.Get("characterPanelLevels") and GetInventoryItemLink("player", slot)
    local marks = id and S.Get("characterPanelMarks")
    Parts.PaintItemMarks(over.marks, link and GetDetailedItemLevelInfo(link), marks and ns.IsBisItem(id) or nil,
        marks and Parts.IsForever(FOREVER_KIND, id))
    if S.Get("characterPanelEnchants") and id then
        B.View.PaintEnchantBadge(over.wand, slot)
    else
        over.wand:Hide()
    end
end

local function PaintAll()
    for _, over in pairs(overs) do Paint(over) end
end

local function MarksOn()
    return CP.On() or (S.Get("enabled") == true and S.Get("characterPanelSlotMarks") == true
        and not ns.GamepadStandDown())
end

local function SlotUpdated(button)
    local over = overs[button]
    if not over or not MarksOn() then return end
    if CP.On() then CropSlot(button, true) end
    Paint(over)
end

local function Over(button, slot)
    local over = SlotOver(button, slot)
    over.wand = B.View.EnchantBadge(over)
    return over
end

local function ListChanged()
    if MarksOn() then PaintAll() end
end

local function Install()
    installed = true
    for slot, name in pairs(CP.SLOTS) do
        local button = _G[SLOT_BUTTON:format(name)]
        if button then overs[button] = Over(button, slot) end
    end
    hooksecurefunc("PaperDollItemSlotButton_Update", SlotUpdated)
    B.OnListChange(ListChanged)
end

local function Apply()
    local styled, marked = CP.On(), MarksOn()
    if marked and not installed then Install() end
    if not installed then return end
    for button, over in pairs(overs) do
        FadeSlot(button, styled and 0 or 1)
        CropSlot(button, styled)
        over.look:SetShown(styled)
        if marked then Paint(over) else over:Hide() end
    end
end

local function OnSetting(key)
    if key == "enabled" or key:find("^characterPanel") then Apply() end
end

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Apply)

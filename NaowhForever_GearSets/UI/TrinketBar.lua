-- TrinketBar.lua: the Trinket Bar, your two trinket slots, and its picker of trinkets in your bags.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local G = ns.GearSets
local C, St, Look = G.C, G.Style, G.Look
local TRINKET_SLOTS = C.TRINKET_SLOTS

local PICKER_COLS, PICKER_CELL, PICKER_STEP, PICKER_PAD = 6, 36, 40, 6
local PICKER_ROOM, PICKER_EDGE, PICKER_GAP = 34, 8, 5
local CLOSE_W, CLOSE_H, CLOSE_Y = 80, 22, 5
local HOME_Y = -160
local ICON_INSET, BLACK = St.ICON_INSET, St.BLACK
local TRINKET = "INVTYPE_TRINKET"
local CARD = C.PAGE .. ":trinketBar"
local WATCHED = { "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_EQUIPMENT_CHANGED" }

local TEXT_NONE = ns.L("No spare trinkets in your bags.")
local TEXT_CLOSE = ns.L("Close")
local TEXT_EMPTY = ns.L("Trinket %d - Empty")
local TEXT_MOVER = "Trinkets"

local trinkets, picker, moving
local items, seen = {}, {}
local watcher = CreateFrame("Frame")

local function ClosePicker()
    if picker then picker:Hide() end
end

local function InBags(itemID)
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            if C_Container.GetContainerItemID(bag, slot) == itemID then return true end
        end
    end
    return false
end

local function SpareTrinkets()
    wipe(items)
    wipe(seen)
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id and not seen[id] then
                local _, _, _, equipLoc = C_Item.GetItemInfoInstant(id)
                if equipLoc == TRINKET then
                    seen[id] = true
                    items[#items + 1] = id
                end
            end
        end
    end
    return items
end

local function OnPickClick(self)
    if InCombatLockdown() then return end
    if InBags(self.itemID) then C_Item.EquipItemByName(self.itemID, self.inventorySlot) end
    ClosePicker()
end

local function OnPickEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.itemID)
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function NewPicker()
    picker = CreateFrame("Frame", nil, UIParent)
    picker:SetFrameStrata("DIALOG")
    picker:SetClampedToScreen(true)
    ns.Solid(picker, "BACKGROUND", T.bg, 1):SetAllPoints()
    ns.Border(picker)
    picker.buttons = {}
    picker.close = ns.Button(picker, TEXT_CLOSE, CLOSE_W, CLOSE_H, ClosePicker)
    picker.close:SetPoint("BOTTOM", 0, CLOSE_Y)
end

local function PickButton(i)
    local button = picker.buttons[i]
    if button then return button end
    button = CreateFrame("Button", nil, picker)
    button:SetSize(PICKER_CELL, PICKER_CELL)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    ns.Border(button, BLACK)
    button:SetScript("OnClick", OnPickClick)
    button:SetScript("OnEnter", OnPickEnter)
    button:SetScript("OnLeave", HideTooltip)
    picker.buttons[i] = button
    return button
end

local function Choose(anchor, inventorySlot)
    if InCombatLockdown() then return end
    ClosePicker()
    if not picker then NewPicker() end
    local spare = SpareTrinkets()
    if #spare == 0 then ns.Print(TEXT_NONE) return end
    for i, id in ipairs(spare) do
        local button = PickButton(i)
        button.itemID, button.inventorySlot = id, inventorySlot
        button.icon:SetTexture(C_Item.GetItemIconByID(id))
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", PICKER_PAD + ((i - 1) % PICKER_COLS) * PICKER_STEP,
            -PICKER_PAD - math.floor((i - 1) / PICKER_COLS) * PICKER_STEP)
        button:Show()
    end
    for i = #spare + 1, #picker.buttons do picker.buttons[i]:Hide() end
    picker:SetSize(math.min(#spare, PICKER_COLS) * PICKER_STEP + PICKER_EDGE,
        math.ceil(#spare / PICKER_COLS) * PICKER_STEP + PICKER_ROOM)
    picker:ClearAllPoints()
    picker:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, PICKER_GAP)
    picker:Show()
end

local function OnSlotEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GetInventoryItemID("player", self.trinketSlot) then
        GameTooltip:SetInventoryItem("player", self.trinketSlot)
    else
        GameTooltip:SetText(TEXT_EMPTY:format(self.trinketIndex))
    end
    GameTooltip:Show()
end

local function OnSlotPostClick(self, mouse, down)
    if mouse == "RightButton" and not down then Choose(self, self.trinketSlot) end
end

local function NewSlot(i)
    local slot = TRINKET_SLOTS[i]
    local button = CreateFrame("Button", nil, trinkets, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("item1", tostring(slot))
    button.icon = button:CreateTexture(nil, "ARTWORK")
    ns.PixelInset(button.icon, ICON_INSET)
    ns.Border(button, BLACK)
    button.trinketSlot, button.trinketIndex = slot, i
    button:SetScript("PostClick", OnSlotPostClick)
    button:SetScript("OnEnter", OnSlotEnter)
    button:SetScript("OnLeave", HideTooltip)
    return button
end

local function SavePosition(pos)
    S.Set("trinketPos", pos)
end

local function BuildTrinkets()
    trinkets = CreateFrame("Frame", "NaowhForeverTrinkets", UIParent)
    trinkets:SetMovable(true)
    trinkets:SetClampedToScreen(true)
    trinkets.buttons = {}
    for i = 1, #TRINKET_SLOTS do trinkets.buttons[i] = NewSlot(i) end
    trinkets.mover = ns.UI.AttachMover(trinkets, TEXT_MOVER, SavePosition, C.PAGE, CARD)
end

local function Place()
    trinkets:ClearAllPoints()
    local pos = S.Get("trinketPos")
    if pos then
        trinkets:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        trinkets:SetPoint("CENTER", UIParent, "CENTER", 0, HOME_Y)
    end
end

local function ApplyTrinkets()
    if InCombatLockdown() then
        watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    ClosePicker()
    local on = S.Get("gearSets") and S.Get("trinketBar")
    for _, event in ipairs(WATCHED) do
        if on then watcher:RegisterEvent(event) else watcher:UnregisterEvent(event) end
    end
    if not on then
        if trinkets then trinkets:Hide() end
        return
    end
    if not trinkets then BuildTrinkets() end
    Place()
    Look.Trinkets(trinkets, trinkets.buttons, S.Get("trinketSize"), S.Get("trinketSpacing"))
    for i, button in ipairs(trinkets.buttons) do
        button:SetAttribute("type1", GetInventoryItemID("player", TRINKET_SLOTS[i]) and "item" or nil)
    end
    trinkets.mover:SetShown(moving == true)
    trinkets:Show()
end

local function OnEvent(_, event, slot)
    if event == "PLAYER_REGEN_DISABLED" then
        ClosePicker()
    elseif event ~= "PLAYER_EQUIPMENT_CHANGED" or slot == TRINKET_SLOTS[1] or slot == TRINKET_SLOTS[2] then
        ApplyTrinkets()
    end
end

local function OnSet(key)
    if key == "gearSets" or key:find("^trinket") and key ~= "trinketPos" then ApplyTrinkets() end
end

local function OnUnlock()
    moving = true
    ApplyTrinkets()
end

local function OnLock()
    moving = false
    ApplyTrinkets()
end

watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", ApplyTrinkets)
hooksecurefunc(ns, "ShowUnlockMode", OnUnlock)
hooksecurefunc(ns, "HideUnlockMode", OnLock)

-- Bar.lua: the Gear Set Bar, a button per set, and the events behind it and the automatic swaps.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local G = ns.GearSets
local C, St, Look = G.C, G.Style, G.Look

local ADD_SIZE = 32
local HOME_Y = 180
local NAME_RGB, EQUIPPED_RGB, MISSING_RGB, HINT_RGB = St.NAME_RGB, St.EQUIPPED_RGB, St.MISSING_RGB, St.HINT_RGB
local CARD = C.PAGE .. ":gearBar"
local EVENTS = { "EQUIPMENT_SETS_CHANGED", "EQUIPMENT_SWAP_FINISHED", "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_REGEN_ENABLED", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_UPDATE_RESTING", "PLAYER_ENTERING_WORLD" }
local SWAP_EVENTS = { PLAYER_MOUNT_DISPLAY_CHANGED = true, PLAYER_UPDATE_RESTING = true, PLAYER_ENTERING_WORLD = true }
local QUIET_KEYS = { gearPos = true, gearWindowAlpha = true }

local TEXT_EQUIPPED = ns.L("Equipped")
local TEXT_MISSING_ONE, TEXT_MISSING = ns.L("%d item missing"), ns.L("%d items missing")
local TEXT_HINT = ns.L("Click to equip. Shift-click to save what you wear into it. Ctrl-click to "
    .. "rename it. Right-click to change its icon.")
local TEXT_ADD = ns.L("New Gear Set")
local TEXT_ADD_TIP = ns.L("Saves what you are wearing now as a new set.")
local TEXT_MOVER = "Gear Sets"

local bar, buttons, addButton, unlocked, inCombat, layoutQueued
local events = CreateFrame("Frame")

local function SetTooltip(btn)
    local set = btn.set
    GameTooltip:SetOwner(btn, "ANCHOR_TOP")
    GameTooltip:SetText(set.name, NAME_RGB.r, NAME_RGB.g, NAME_RGB.b)
    if set.equipped then GameTooltip:AddLine(TEXT_EQUIPPED, EQUIPPED_RGB.r, EQUIPPED_RGB.g, EQUIPPED_RGB.b) end
    if set.lost > 0 then
        GameTooltip:AddLine((set.lost == 1 and TEXT_MISSING_ONE or TEXT_MISSING):format(set.lost),
            MISSING_RGB.r, MISSING_RGB.g, MISSING_RGB.b)
    end
    GameTooltip:AddLine(TEXT_HINT, HINT_RGB.r, HINT_RGB.g, HINT_RGB.b, true)
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function OnButtonClick(self, button)
    if button == "RightButton" then
        ns.ChangeGearSetIcon(self.set.id, self.set.name)
    elseif IsShiftKeyDown() then
        ns.SaveGearSet(self.set.id, self.set.name)
    elseif IsControlKeyDown() then
        ns.RenameGearSet(self.set.id, self.set.name)
    else
        G.EquipByHand(self.set.id)
    end
end

local function NewButton()
    local btn = CreateFrame("Button", nil, bar)
    btn.icon, btn.border = Look.Dress(btn)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", OnButtonClick)
    btn:SetScript("OnEnter", SetTooltip)
    btn:SetScript("OnLeave", HideTooltip)
    return btn
end

local function Layout()
    if not bar then return end
    local size, gap = S.Get("gearBarSize"), S.Get("gearBarSpacing")
    local sets = G.Sets()
    for i, set in ipairs(sets) do
        local btn = buttons[i] or NewButton()
        buttons[i] = btn
        btn.set = set
        Look.SetButton(btn, set, i, size, gap)
    end
    for i = #sets + 1, #buttons do buttons[i]:Hide() end
    Look.Fit(bar, addButton, #sets, size, gap)
end

local function BarShown()
    local show = S.Get("gearBarShow")
    return S.Get("gearBarVisible") == true
        and (unlocked == true or show == "always" or (show == "combat") == (inCombat == true))
end

local function SavePosition(pos)
    S.Set("gearPos", pos)
end

local function BuildBar()
    bar = CreateFrame("Frame", "NaowhForeverGearBar", UIParent)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    buttons = {}
    addButton = ns.Button(bar, "+", ADD_SIZE, ADD_SIZE, ns.NewGearSet)
    ns.Tooltip(addButton, TEXT_ADD, TEXT_ADD_TIP)
    bar.mover = ns.UI.AttachMover(bar, TEXT_MOVER, SavePosition, C.PAGE, CARD)
    local pos = S.Get("gearPos")
    if pos then
        bar:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, HOME_Y)
    end
end

local function LayoutNow()
    layoutQueued = false
    Layout()
end

local function LayoutSoon()
    if layoutQueued then return end
    layoutQueued = true
    C_Timer.After(0, LayoutNow)
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        inCombat = event == "PLAYER_REGEN_DISABLED"
        bar:SetShown(BarShown())
    end
    if event == "PLAYER_REGEN_DISABLED" then return end
    if event == "PLAYER_REGEN_ENABLED" then
        G.EquipPending()
        G.AutoSwap()
    elseif SWAP_EVENTS[event] then
        G.AutoSwap()
    elseif event == "EQUIPMENT_SETS_CHANGED" and ns.UI.RefreshPage then
        ns.UI:RefreshPage(true)
    end
    LayoutSoon()
end

local function Apply()
    events:UnregisterAllEvents()
    if not G.On() then
        if bar and not unlocked then bar:Hide() end
        return
    end
    if not bar then BuildBar() end
    for _, e in ipairs(EVENTS) do events:RegisterEvent(e) end
    if S.Get("gearBarShow") ~= "always" then events:RegisterEvent("PLAYER_REGEN_DISABLED") end
    Layout()
    inCombat = InCombatLockdown()
    bar:SetShown(BarShown())
    bar.mover:SetShown(unlocked == true)
    G.AutoSwap()
end

local function OnSet(key)
    if key:find("^gear") and not QUIET_KEYS[key] then Apply() end
end

local function OnUnlock()
    unlocked = true
    if G.On() then Apply() end
end

local function OnLock()
    unlocked = false
    if not bar then return end
    bar.mover:Hide()
    if G.On() then bar:SetShown(BarShown()) end
end

events:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", OnUnlock)
hooksecurefunc(ns, "HideUnlockMode", OnLock)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

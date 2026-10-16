-- Bar.lua: the Consumable Bar on screen: one secure button per entry (an item, a Smart Macro or a Food & Drink button), laid out, placed and shown or hidden out of combat.
local ns = _G.NaowhForever

local InCombatLockdown = InCombatLockdown
local GetTime = GetTime

local CB = ns.ConsumableBar
local S, C = CB.S, CB.C
local ItemBar, ActionKeys = ns.Shared.ItemBar, ns.Shared.ActionKeys

local MOVER_LABEL = "Consumable Bar"
local FLAGS = "consumableBarItemFlags"
local QUIET = { consumableBarPos = true, consumableBarDeclined = true, consumableBarSkip = true,
    consumableBarTooltip = true }
local LOOK = { consumableBarFont = true, consumableBarFontSize = true, consumableBarTextColor = true,
    consumableBarTextPoint = true, consumableBarTextOutside = true, consumableBarTextX = true,
    consumableBarTextY = true, consumableBarKeyFont = true, consumableBarKeySize = true,
    consumableBarKeyColor = true, consumableBarKeyPoint = true, consumableBarKeyOutside = true,
    consumableBarKeyX = true, consumableBarKeyY = true, consumableBarBackground = true,
    consumableBarBgAlpha = true, consumableBarShowCount = true }
local BAR_NAME = "NaowhForeverConsumableBar"
local RULE_COMBAT_HIDE = "[combat] hide; show"
local RULE_COMBAT_SHOW = "[combat] show; hide"

local frame, pending, wakeDue
local syncedMacros = ""
local buttons = {}
local pool = {}
local events

local UpdateVisibility, Apply

local function Driver(f, rule)
    if f.visRule == rule then return end
    f.visRule = rule
    if rule then
        RegisterStateDriver(f, "visibility", rule)
    else
        UnregisterStateDriver(f, "visibility")
    end
end

local function TipOff(button)
    return not S.Get("consumableBarTooltip") or (button.itemID == nil and not button.emptyTip) or button.empty
end

local function ButtonFor(entry)
    local button = pool[entry]
    if not button then
        button = CB.Decorate(ItemBar.SecureButton(frame, CB.ButtonName(entry)))
        button.tipOff = TipOff
        button.emptyTip = CB.EmptyTip(entry)
        pool[entry] = button
    end
    return button
end

local function Retire(button)
    Driver(button, nil)
    if CB.MacroInfo(button.entry) then
        button:SetAttribute("type1", nil)
        button:SetAttribute("macro1", nil)
        button.itemID = nil
    else
        ItemBar.SetItem(button, nil)
    end
    button.entry, button.spent, button.slot = nil, nil, nil
    button:Hide()
end

local function Point(button, entry)
    local info = CB.MacroInfo(entry)
    if info then
        button:SetAttribute("type1", "macro")
        button:SetAttribute("macro1", info.name)
        button.itemID = CB.Resolve(entry)
    else
        ItemBar.SetItem(button, CB.Resolve(entry))
    end
end

local function SavePosition(pos)
    S.Set("consumableBarPos", pos)
    if ItemBar.Anchored(S, CB.PREFIX) then S.Set("consumableBarAnchor", "UIParent") end
end

local function Build()
    frame = ItemBar.Frame(BAR_NAME, MOVER_LABEL, SavePosition, "Consumable Bar/Settings", "Consumable Bar/Settings:bar")
    ItemBar.Outline(frame, C.BG_PAD)
end

function CB.BarFrame()
    return frame
end

local function Layout()
    CB.RefreshSmart()
    local items = CB.ShownItems()
    local size, gap, grow, perRow, height, flip = CB.Grid()
    local inUse = {}
    for i = #buttons, 1, -1 do buttons[i] = nil end
    for i, entry in ipairs(items) do
        local button = ButtonFor(entry)
        buttons[i], inUse[button] = button, true
        ItemBar.Place(button, frame, i, size, gap, grow, perRow, height, flip)
        CB.PlaceBackground(button, i, #items, gap, grow, perRow, flip)
        CB.StyleCell(button, entry, size, height)
        button.entry, button.slot = entry, i
        Point(button, entry)
    end
    for _, button in pairs(pool) do
        if not inUse[button] and (button.entry ~= nil or button:IsShown()) then Retire(button) end
    end
    frame:SetSize(ItemBar.Size(#items, size, gap, grow, perRow, height))
end

local function UpdateCounts()
    local quiet = not InCombatLockdown()
    for _, button in ipairs(buttons) do
        if button.entry ~= nil then
            CB.ShowCount(button, button.itemID, 0)
            if quiet then button:EnableMouse(not button.empty) end
        end
    end
end

local function UpdateCooldowns()
    for _, button in ipairs(buttons) do
        if button.entry ~= nil then CB.ShowCooldown(button, button.itemID) else button.timer:Hide() end
    end
end

local function UpdateKeys()
    local map = CB.KeyMap()
    for _, button in ipairs(buttons) do CB.ShowKey(button, map) end
    CB.Changed()
end

local QueueKeys = ActionKeys.NewQueue(UpdateKeys)

local function OnWake()
    wakeDue = nil
    UpdateVisibility()
end

local function Wake(at)
    if not at then return end
    local due = GetTime() + at + C.WAKE_LEAD
    if wakeDue and wakeDue <= due then return end
    wakeDue = due
    C_Timer.After(at + C.WAKE_LEAD, OnWake)
end

local function ShowIcon(button)
    local flags = CB.Flags(button.entry)
    local combat = flags.combat and not CB.unlocked
    local used = flags.used and not CB.unlocked and CB.Spent(button)
    if combat and used then
        Driver(button, nil)
        button:Hide()
    elseif combat then
        Driver(button, RULE_COMBAT_HIDE)
    elseif used then
        Driver(button, RULE_COMBAT_SHOW)
    else
        Driver(button, nil)
        button:Show()
    end
    return not combat, not used
end

function UpdateVisibility()
    if not frame or InCombatLockdown() or not CB.On() then return end
    CB.TakeWake()
    local fight, rest = CB.unlocked == true, CB.unlocked == true
    for _, button in ipairs(buttons) do
        if button.entry ~= nil then
            local inFight, atRest = ShowIcon(button)
            fight, rest = fight or inFight, rest or atRest
        end
    end
    if S.Get("consumableBarHideCombat") and not CB.unlocked then fight = false end
    if fight and rest then
        Driver(frame, nil)
        frame:Show()
    elseif fight then
        Driver(frame, RULE_COMBAT_SHOW)
    elseif rest then
        Driver(frame, RULE_COMBAT_HIDE)
    else
        Driver(frame, nil)
        frame:Hide()
    end
    Wake(CB.TakeWake())
end

local function Has(test)
    for _, entry in ipairs(CB.Items()) do
        if test(entry) then return true end
    end
    return false
end

local function HasMacros()
    return Has(CB.MacroInfo)
end

local function HasSmart()
    return Has(CB.Smart)
end

local function RestyleWhere(test)
    local size, height = CB.IconSize()
    for _, button in ipairs(buttons) do
        if test(button.entry) then
            Point(button, button.entry)
            CB.StyleCell(button, button.entry, size, height)
        end
    end
end

local function RefreshSmart()
    if not HasSmart() then return end
    if InCombatLockdown() then
        pending = true
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    CB.RefreshSmart()
    RestyleWhere(CB.Smart)
end

local function OutChanged()
    if not S.Get("consumableBarHideEmpty") then return false end
    for _, entry in ipairs(CB.Items()) do
        local button = pool[entry]
        if (button ~= nil and button.entry ~= nil) == CB.Out(entry) then return true end
    end
    return false
end

local function RefreshMacros()
    local fight = InCombatLockdown()
    for _, button in ipairs(buttons) do
        if CB.MacroInfo(button.entry) then
            button.itemID = CB.Resolve(button.entry)
            if fight then
                button.icon:SetTexture(CB.EntryIcon(button.entry))
            else
                CB.StyleCell(button, button.entry, CB.IconSize())
            end
        end
    end
    UpdateCounts()
    UpdateCooldowns()
    UpdateVisibility()
    QueueKeys()
    CB.Changed()
    if OutChanged() then Apply() end
end

local function SyncMacros()
    local used = ""
    for _, entry in ipairs(CB.SavedItems()) do
        if CB.On() and CB.MacroInfo(entry) then used = used .. entry end
    end
    if used == syncedMacros then return end
    syncedMacros = used
    if ns.UpdateManagedMacros then ns.UpdateManagedMacros() end
end

local function AnyHideUsed()
    if CB.unlocked then return false end
    for _, entry in ipairs(CB.Items()) do
        if CB.Flags(entry).used then return true end
    end
    return false
end

local function OnEvent(_, event, unit, success, spellID)
    if event == "UNIT_LEVEL" or event == "GET_ITEM_INFO_RECEIVED" then
        if event == "UNIT_LEVEL" and unit ~= "player" then return end
        if event == "GET_ITEM_INFO_RECEIVED" and (not success or C_Item.GetItemCount(unit) == 0) then return end
        RefreshSmart()
        if OutChanged() then Apply() end
        return
    end
    if event == "PLAYER_LOGIN" then
        Apply()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        CB.NoteCast(spellID)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then
            Apply()
        else
            UpdateCounts()
            UpdateVisibility()
        end
        CB.ShowAsk()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Apply()
    elseif event == "BAG_UPDATE_COOLDOWN" then
        UpdateCooldowns()
        UpdateVisibility()
    elseif event == "UNIT_AURA" or event == "UNIT_INVENTORY_CHANGED" then
        if unit == "player" then UpdateVisibility() end
    elseif event == "UPDATE_MACROS" then
        RefreshMacros()
    elseif event == "BAG_UPDATE_DELAYED" then
        RefreshSmart()
        UpdateCounts()
        UpdateCooldowns()
        if OutChanged() then Apply() end
        CB.CheckNewItems()
        CB.Changed()
    else
        QueueKeys()
    end
end

local function Listen(hideUsed)
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    if HasSmart() then
        events:RegisterEvent("UNIT_LEVEL")
        events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    end
    if HasMacros() then events:RegisterEvent("UPDATE_MACROS") end
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    if S.Get("consumableBarCooldown") or hideUsed then events:RegisterEvent("BAG_UPDATE_COOLDOWN") end
    if hideUsed then
        events:RegisterUnitEvent("UNIT_AURA", "player")
        events:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
        events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    end
    ActionKeys.Listen(events, S.Get("consumableBarKeybinds"))
end

local function Events()
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    return events
end

function Apply()
    if InCombatLockdown() then
        pending = true
        Events():RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    pending = nil
    if events then events:UnregisterAllEvents() end
    if not CB.On() then
        CB.StopAsking()
        if frame then
            Driver(frame, nil)
            frame:Hide()
        end
        SyncMacros()
        return
    end
    if not frame then Build() end
    Events()
    Layout()
    ItemBar.Put(frame, S, CB.PREFIX, C.HOME_Y)
    frame.mover:SetShown(CB.unlocked == true)
    Listen(AnyHideUsed())
    UpdateCounts()
    UpdateCooldowns()
    UpdateVisibility()
    QueueKeys()
    SyncMacros()
end

local function Restyle()
    if not (frame and CB.On()) then return end
    if InCombatLockdown() then
        Apply()
        return
    end
    local size, gap, grow, perRow, height, flip = CB.Grid()
    for i, button in ipairs(buttons) do
        CB.StyleCell(button, button.entry, size, height)
        CB.PlaceBackground(button, i, #buttons, gap, grow, perRow, flip)
    end
    UpdateCounts()
    QueueKeys()
end

local function OnSettingChanged(key)
    if not key:find("^consumableBar") then return end
    if key == "consumableBarAskNew" then
        if not S.Get(key) then CB.StopAsking() end
    elseif LOOK[key] or (key == FLAGS and CB.lookOnly) then
        Restyle()
    elseif not QUIET[key] then
        Apply()
    end
    CB.Changed()
end

local function Unlock()
    CB.unlocked = true
    Apply()
end

local function Lock()
    CB.unlocked = false
    Apply()
end

local function OnMacrosChanged(key)
    if key == "enabled" then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
if ns.MacroSettings then ns.MacroSettings.OnChange(OnMacrosChanged) end
hooksecurefunc(ns, "ShowUnlockMode", Unlock)
hooksecurefunc(ns, "HideUnlockMode", Lock)

if CB.On() then Events():RegisterEvent("PLAYER_LOGIN") end

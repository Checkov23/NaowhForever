-- GearReminders.lua: an icon while you wear gear with a drawback where you are, so you remember to swap it.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local UI = ns.UI
local T = ns.THEME
local Parts = ns.Shared.Parts
local Settings = ns.Shared.Settings

local WORN = {
    { item = 273084, slot = 15, instance = 43, setting = "wornReminders" },
    { weapon = "Fishingpole", sample = 6256, slot = 16, where = "fishingPoleWhere", setting = "fishingPoleReminder" },
}

local INSTANCE_ID = 8
local GAP = 4
local SIZE_RANGE = { 20, 96, 1 }
local ORDER = 55
local PAGE = "QoL/Loot & Items"
local CARD = PAGE .. ":gearReminders"
local POLE_WHERE = { { always = "Everywhere", instance = "Dungeons & Raids" }, { "always", "instance" } }
local MOVED = { "wornReminders", "fishingPoleReminder", "fishingPoleWhere" }
local KEYS = { enabled = true, wornReminders = true, fishingPoleReminder = true, fishingPoleWhere = true,
    gearReminderSize = true }
local TEXT_MOVER = "Gear Reminders"
local TEXT_WORN = ns.L("You are wearing this.")
local TEXT_HIDE = ns.L("Ctrl-click to hide it until you take it off.")

local frame, unlocked
local icons, dismissed = {}, {}
local events = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and (S.Get("wornReminders") or S.Get("fishingPoleReminder"))
end

local function Migrate()
    local old, db = ns.SettingsRoot().auraBuffs, S.DB()
    if type(old) ~= "table" then return end
    for _, key in ipairs(MOVED) do
        if old[key] ~= nil and db[key] == nil then db[key] = old[key] end
        old[key] = nil
    end
end

local function Wearing(worn, id)
    if worn.item then return id == worn.item end
    local _, _, _, _, _, class, subclass = C_Item.GetItemInfoInstant(id)
    return class == Enum.ItemClass.Weapon and subclass == Enum.ItemWeaponSubclass[worn.weapon]
end

local function WornHere(worn, here)
    if worn.instance then return worn.instance == here end
    if worn.where and S.Get(worn.where) == "instance" then
        local _, kind = IsInInstance()
        return kind == "party" or kind == "raid"
    end
    return true
end

local Update

local function OnIconEnter(icon)
    if not icon.slot then return end
    local tip, muted = T.accentSoft, T.muted
    GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
    GameTooltip:SetInventoryItem("player", icon.slot)
    GameTooltip:AddLine(TEXT_WORN, tip.r, tip.g, tip.b)
    GameTooltip:AddLine(TEXT_HIDE, muted.r, muted.g, muted.b)
    GameTooltip:Show()
end

local function OnIconLeave()
    GameTooltip:Hide()
end

local function OnIconClick(icon)
    if not (icon.slot and IsControlKeyDown()) then return end
    dismissed[icon.slot] = GetInventoryItemID("player", icon.slot)
    Update()
end

local function ShowIcon(i, texture, slot, size)
    local icon = icons[i]
    if not icon then
        icon = Parts.ItemIcon(frame, size)
        icon:EnableMouse(true)
        icon:SetScript("OnEnter", OnIconEnter)
        icon:SetScript("OnLeave", OnIconLeave)
        icon:SetScript("OnMouseUp", OnIconClick)
        icons[i] = icon
    end
    icon:SetSize(size, size)
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", frame, "LEFT", (i - 1) * (size + GAP), 0)
    icon.texture:SetTexture(texture)
    icon.slot = slot
    icon:Show()
end

function Update()
    local size = S.Get("gearReminderSize")
    local here = select(INSTANCE_ID, GetInstanceInfo())
    local shown = 0
    for _, worn in ipairs(WORN) do
        local slot = worn.slot
        local id = GetInventoryItemID("player", slot)
        if dismissed[slot] ~= id then dismissed[slot] = nil end
        if unlocked then
            if S.Get(worn.setting) then
                shown = shown + 1
                ShowIcon(shown, C_Item.GetItemIconByID(worn.item or worn.sample), nil, size)
            end
        elseif id and not dismissed[slot] and S.Get(worn.setting) and WornHere(worn, here) and Wearing(worn, id) then
            shown = shown + 1
            ShowIcon(shown, C_Item.GetItemIconByID(id), slot, size)
        end
    end
    for i = shown + 1, #icons do icons[i]:Hide() end
    frame:SetSize(math.max(shown, 1) * (size + GAP) - GAP, size)
end

local function OnEvent(_, event, slot, hasCurrent)
    if event == "PLAYER_EQUIPMENT_CHANGED" and not hasCurrent then dismissed[slot] = nil end
    Update()
end

events:SetScript("OnEvent", OnEvent)

local function SavePosition(pos)
    S.Set("gearReminderPos", pos)
end

local function Build()
    frame = CreateFrame("Frame", "NaowhForeverGearReminders", UIParent)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame.mover = UI.AttachMover(frame, TEXT_MOVER, SavePosition, PAGE, CARD)
end

local function Place()
    local pos = S.Get("gearReminderPos")
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

local function Apply()
    Migrate()
    events:UnregisterAllEvents()
    if not On() then
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() end
    Place()
    frame.mover:SetShown(unlocked == true)
    frame:Show()
    events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    Update()
end

local function OnSettingChanged(key)
    if KEYS[key] then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = On() == true
    Apply()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    Apply()
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

Settings.Page(PAGE, S):Card({
    id = "gearReminders", name = "Gear Reminders", order = ORDER,
    help = "An icon while you wear gear you would want to swap out where you are.",
    rows = {
        { key = "wornReminders", label = "Worn Gear Reminder", toggle = true,
          help = "An icon while you wear Cloak of Hermitic Bliss in Wailing Caverns, so you remember to swap it." },
        { key = "fishingPoleReminder", label = "Fishing Pole Reminder", toggle = true,
          help = "An icon while you have a fishing pole equipped, so you remember to swap it." },
        { key = "fishingPoleWhere", label = "Fishing Pole Shows In", choice = POLE_WHERE, needs = "fishingPoleReminder",
          why = "Needs Fishing Pole Reminder" },
        { key = "gearReminderSize", label = "Icon Size", slider = SIZE_RANGE },
    },
})

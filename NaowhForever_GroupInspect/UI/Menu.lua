-- Menu.lua: Group Inspect on a party or raid member's right-click menu, only while it is on.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local GI = ns.GroupInspect
local UI = GI.UI

local MENU_TAGS = { "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_RAID" }
local MENU_TEXT = ns.L("Group Inspect")
local menuHandles

local function OpenFromMenu()
    ns.OpenGroupInspect()
end

local function AddToMenu(_, root)
    if not (GI.On() and IsInGroup()) then return end
    root:CreateDivider()
    root:CreateButton(MENU_TEXT, OpenFromMenu)
end

local function SyncMenu()
    local on = GI.On()
    if on and not menuHandles and Menu and Menu.ModifyMenu then
        menuHandles = {}
        for i, tag in ipairs(MENU_TAGS) do menuHandles[i] = Menu.ModifyMenu(tag, AddToMenu) end
    elseif not on and menuHandles then
        for _, handle in ipairs(menuHandles) do handle:Unregister() end
        menuHandles = nil
    end
end

UI.MENU_TAGS = MENU_TAGS

local function OnSettingChanged(key)
    if key == "groupInspect" then SyncMenu() end
end

S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", SyncMenu)

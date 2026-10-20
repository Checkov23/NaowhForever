-- Ellesmere.lua: the popup when a setting is on in both EllesmereUI and Naowh Forever, after a click here or once EllesmereUI's window closes (Settings.EllesmereClash).
local ns = _G.NaowhForever
local Settings = ns.Shared.Settings

local QOL = "EllesmereUIQoL"
local ESSENTIALS = "EllesmereUIForeverEssentials"
local QUESTS = "EllesmereUIQuestTracker"
local DB = "EllesmereUIDB"
local QUEST_DB = "_EQT_DB"
local WINDOW_OPENERS = { "Show", "Toggle", "ShowModule" }
local LIST_JOIN = ", "
local TEXT_BOTH = ns.L("%s is on in both EllesmereUI and Naowh Forever. Turn one of them off.")
local TEXT_BOTH_MANY = ns.L("%s are on in both EllesmereUI and Naowh Forever. Turn one of each off.")
local TEXT_OFF_HERE, TEXT_KEEP = ns.L("Turn Off Here"), ns.L("Keep Both")
local TRACKER_ON = { path = { QUEST_DB, "profile", "questTracker", "enabled" }, default = true }

local OVERLAPS = {
    autoRepair = { addon = QOL, path = { DB, "autoRepair" }, default = true },
    sellJunk = { addon = QOL, path = { DB, "autoSellJunk" }, default = true },
    fastLoot = { addon = QOL, path = { DB, "quickLoot" }, default = false },
    hideLootWindow = { addon = QOL, path = { DB, "quickLoot" }, default = false },
    deleteConfirm = { addon = QOL, path = { DB, "autoFillDelete" }, default = false },
    skipCinematics = { addon = QOL, path = { DB, "skipCinematicsAuto" }, default = false },
    hideErrors = { addon = QOL, path = { DB, "hideErrorMessages" }, default = false },
    hideTutorials = { addon = QOL, path = { DB, "hideTutorials" }, default = false },
    hideScreenshot = { addon = QOL, path = { DB, "hideScreenshotStatus" }, default = true },
    combatAlert = { addon = QOL, path = { DB, "combatAlertEnabled" }, default = false },
    durability = { addon = QOL, path = { DB, "repairWarning" }, default = true },
    gossipAuto = { addon = QOL, path = { DB, "autoGossip" }, default = false },
    lootFeed = { addon = ESSENTIALS, path = { DB, "lootFeed", "enabled" }, default = false },
    flightTimer = { addon = ESSENTIALS, path = { DB, "flightTimer", "enabled" }, default = true },
    questAccept = { addon = QUESTS, path = { QUEST_DB, "profile", "questTracker", "autoAccept" }, default = false,
        gate = TRACKER_ON },
    questTurnIn = { addon = QUESTS, path = { QUEST_DB, "profile", "questTracker", "autoTurnIn" }, default = false,
        gate = TRACKER_ON },
}

local function Read(entry)
    local path = entry.path
    local value = _G[path[1]]
    for i = 2, #path do
        if type(value) ~= "table" then return nil end
        value = value[path[i]]
        if value == nil then return entry.default end
    end
    return value
end

local ORDER = {}
for key in pairs(OVERLAPS) do ORDER[#ORDER + 1] = key end
table.sort(ORDER)

local before = {}
local watching, hooked

local function EllesmereOn(key)
    local entry = OVERLAPS[key]
    if not (entry and C_AddOns.IsAddOnLoaded(entry.addon)) then return false end
    local on = Read(entry)
    if on and entry.gate and Read(entry.gate) == false then on = false end
    return on == true
end

local function Find(key)
    for _, page in pairs(Settings.pages) do
        for _, card in pairs(page.cards) do
            if card.switch == key then return card.name, card end
            for _, row in ipairs(card.rows) do
                if row.key == key then return row.label, card, row end
            end
        end
    end
end

local function OnHere(key)
    local label, card, row = Find(key)
    if not (label and card.store.Get(key)) then return false end
    if row and Settings.Off(row) or not row and card.switchWhy and card.switchWhy() then return false end
    return type(card.switch) ~= "string" or card.store.Get(card.switch) == true
end

local function TurnOff(keys)
    for _, key in ipairs(keys) do
        local _, card = Find(key)
        card.store.Set(key, false)
    end
    ns.UI:RefreshPage(true)
end

local function Ask(keys)
    local labels = {}
    for i, key in ipairs(keys) do labels[i] = (Find(key)) end
    local text = #keys == 1 and TEXT_BOTH:format(labels[1]) or TEXT_BOTH_MANY:format(table.concat(labels, LIST_JOIN))
    ns.Confirm(text, function() TurnOff(keys) end, nil, TEXT_OFF_HERE, TEXT_KEEP)
end

function Settings.EllesmereClash(card, key)
    if type(key) ~= "string" then return end
    local keys = {}
    for _, overlap in ipairs(ORDER) do
        local mine = overlap == key or (key == card.switch and select(2, Find(overlap)) == card)
        if mine and EllesmereOn(overlap) and OnHere(overlap) then keys[#keys + 1] = overlap end
    end
    if #keys > 0 then Ask(keys) end
end

local function Snapshot()
    for _, key in ipairs(ORDER) do before[key] = EllesmereOn(key) end
end

local function OnWindowHidden()
    local keys = {}
    for _, key in ipairs(ORDER) do
        if not before[key] and EllesmereOn(key) and OnHere(key) then keys[#keys + 1] = key end
    end
    if #keys > 0 then Ask(keys) end
end

local function WatchWindow()
    local frame = EllesmereUI:GetMainFrame()
    if watching or not frame then return end
    watching = true
    frame:HookScript("OnShow", Snapshot)
    frame:HookScript("OnHide", OnWindowHidden)
    if frame:IsShown() then Snapshot() end
end

function Settings.WatchEllesmere()
    if hooked or not EllesmereUI then return end
    hooked = true
    for _, name in ipairs(WINDOW_OPENERS) do
        if EllesmereUI[name] then hooksecurefunc(EllesmereUI, name, WatchWindow) end
    end
    WatchWindow()
end

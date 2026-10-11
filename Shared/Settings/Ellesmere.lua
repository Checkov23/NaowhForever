-- Ellesmere.lua: the note on a setting EllesmereUI also has, saying whether it is on there, read from its settings each time the row is drawn (Settings.EllesmereNote).
local ns = _G.NaowhForever
local Settings = ns.Shared.Settings

local QOL = "EllesmereUIQoL"
local ESSENTIALS = "EllesmereUIForeverEssentials"
local QUESTS = "EllesmereUIQuestTracker"
local DB = "EllesmereUIDB"
local QUEST_DB = "_EQT_DB"
local TEXT_ON = ns.L("EllesmereUI has it on")
local TEXT_OFF = ns.L("EllesmereUI has it off")
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

function Settings.EllesmereNote(item)
    local entry = OVERLAPS[item.key or item.switch]
    if not (entry and C_AddOns.IsAddOnLoaded(entry.addon)) then return nil end
    local on = Read(entry)
    if on == nil then return nil end
    if on and entry.gate and Read(entry.gate) == false then on = false end
    return on and TEXT_ON or TEXT_OFF
end

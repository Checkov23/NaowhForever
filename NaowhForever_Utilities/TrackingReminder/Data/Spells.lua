-- Spells.lua: racial and class tracking spells for the Tracking Reminder.
local ns = _G.NaowhForever

local TR = ns.TrackingReminder

local FIND_TREASURE = 2481

local RACIAL = {
    { spell = FIND_TREASURE, race = "Dwarf", key = "treasure", label = ns.L("Treasure") },
}

local TRACK_BEASTS = 1494
local TRACK_HUMANOIDS = 19883
local TRACK_UNDEAD = 19884
local TRACK_HIDDEN = 19885
local TRACK_ELEMENTALS = 19880
local TRACK_DEMONS = 19878
local TRACK_GIANTS = 19882
local TRACK_DRAGONKIN = 19879
local TRACK_DRUID_HUMANOIDS = 5225
local SENSE_UNDEAD = 5502
local SENSE_DEMONS = 5500
local CAT_FORM = 1

local CLASS = {
    { spell = TRACK_BEASTS, class = "HUNTER", key = "beasts", label = ns.L("Beasts") },
    { spell = TRACK_HUMANOIDS, class = "HUNTER", key = "humanoids", label = ns.L("Humanoids") },
    { spell = TRACK_UNDEAD, class = "HUNTER", key = "undead", label = ns.L("Undead") },
    { spell = TRACK_HIDDEN, class = "HUNTER", key = "hidden", label = ns.L("Hidden") },
    { spell = TRACK_ELEMENTALS, class = "HUNTER", key = "elementals", label = ns.L("Elementals") },
    { spell = TRACK_DEMONS, class = "HUNTER", key = "demons", label = ns.L("Demons") },
    { spell = TRACK_GIANTS, class = "HUNTER", key = "giants", label = ns.L("Giants") },
    { spell = TRACK_DRAGONKIN, class = "HUNTER", key = "dragonkin", label = ns.L("Dragonkin") },
    { spell = TRACK_DRUID_HUMANOIDS, class = "DRUID", key = "druidHumanoids", label = ns.L("Humanoids"),
        form = CAT_FORM },
    { spell = SENSE_UNDEAD, class = "PALADIN", key = "senseUndead", label = ns.L("Undead") },
    { spell = SENSE_DEMONS, class = "WARLOCK", key = "senseDemons", label = ns.L("Demons") },
}

TR.Data = {
    FIND_TREASURE = FIND_TREASURE,
    RACIAL = RACIAL,
    CLASS = CLASS,
}

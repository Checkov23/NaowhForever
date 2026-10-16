-- Positions.lua: where your HUD sits, by settings store, kept through a profile import or a setup (ns.KeepPositions).
local ns = _G.NaowhForever

local POSITIONS = {
    qol = { "alertsPos", "bisToastPos", "gearPos", "trinketPos", "combatAlertPos", "combatTimerPos",
        "zoneInfoPos", "focusCastBarPos", "gcdTrackerPos", "healerManaPos", "stealthPos", "waypointNavPos", "bagSpacePos",
        "lootFeedPos", "lootFeedWidth", "lootFeedHeight", "groupButtonsPos", "flightTimerPos", "groupXPPos",
        "xpBarPos", "xpTickerPos", "damageMeterPos", "mapSizePos", "trainerPos", "aimPos", "quizPos", "dailyWordPos",
        "blessPos", "blessAnchor", "blessAnchorPoint", "blessAnchorRelPoint", "blessX", "blessY",
        "consumableBarPos", "consumableBarAnchor", "consumableBarAnchorPoint", "consumableBarAnchorRelPoint",
        "consumableBarX", "consumableBarY",
        "foodBarPos", "foodBarAnchor", "foodBarAnchorPoint", "foodBarAnchorRelPoint", "foodBarX", "foodBarY",
        "coTankPos", "coTankAnchor", "coTankX", "coTankY" },
    auraBuffs = { "buffsPos", "classBuffPos", "campPos", "lowHealthPos" },
    pvp = { "pos", "focusPos", "scoresPos", "timerPos", "flagButtonPos" },
    swingTimer = { "swingPos" },
    threatMeter = { "threatPos", "width", "height" },
    damageMeter = { "meterPos", "meterPos2", "meterPos3", "width", "height", "width2", "height2", "width3", "height3" },
    completo = { "rareAlertPosition" },
    discovery = { "bagTrackerPos", "trackerPos" },
    instanceTracker = { "pos" },
    journeys = { "cardPos" },
    professions = { "gatherPos", "windowPos" },
    topBar = { "pos" },
    training = { "toastPos" },
    unlockMode = { "anchoredTo", "hidden", "locked", "layouts", "layout" },
}

local function Copy(value)
    if type(value) == "table" then return CopyTable(value) end
    return value
end

function ns.KeepPositions(root)
    local kept = {}
    for db, keys in pairs(POSITIONS) do
        local values = type(root[db]) == "table" and root[db] or nil
        local saved = {}
        if values then
            for _, key in ipairs(keys) do saved[key] = Copy(values[key]) end
        end
        kept[db] = saved
    end
    return kept
end

function ns.PutPositionsBack(root, kept)
    for db, keys in pairs(POSITIONS) do
        local saved = kept[db]
        if type(root[db]) ~= "table" and next(saved) then root[db] = {} end
        local values = root[db]
        if type(values) == "table" then
            for _, key in ipairs(keys) do values[key] = saved[key] end
        end
    end
end

ns.POSITION_KEYS = POSITIONS

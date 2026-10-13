-- DamageMeter.lua: the Damage Meter's settings (ns.DamageMeterSettings) and its table (ns.DamageMeter).
local ns = _G.NaowhForever

local F = ns.FEATURES.damageMeter

local TITLE, MAX_WINDOWS = "Damage Meter", 3
local SLOTS_KEPT = 64

local S = ns.UI.ModuleSettings("damageMeter", {
    enabled = F.enabled,
    visibility = "always", locked = false, idleAlpha = 1, hoverFull = true, clickThrough = false,
    barHeight = 20, barSpacing = 2, growUp = false, reverseFill = false, barScale = "top",
    columns = "auto", showDivider = false, showIcons = true, showRanks = true, highlightPlayer = true, pinSelf = false,
    barColor = "class", barAlpha = 0.85, backgroundAlpha = 0.9,
    fontSize = 11, font = "", outline = "OUTLINE", texture = "",
    hideGameMeter = true, breakdown = true, reportLines = 5, showTime = true,
    hideInPvP = false, resetOn = "never", resetOnLeave = false, overallOutOfCombat = false,
    panelLines = 8, targetLines = 5, panelWidth = 300, panelScale = 1, panelAlpha = 1, panelSide = "auto",
    fightsShown = 10,
    showBorder = true, iconStyle = "spec",
    showColumnHeaders = true, numberUnits = "game", numberDecimals = 1, nameFormat = "full",
    showSummary = false, summaryName = true, summaryTotal = true, summaryRate = true, summaryRank = true,
    summarySize = 11, shortNames = false, titleSize = 12, timeSize = 11,
    iconSize = 0, iconGap = 5, iconSide = "left", iconZoom = 8, textPad = 6, colGap = 6, edgeWidth = 2,
    barTrack = false, trackColor = false,
    nameOwnFont = false, nameFont = "", nameOutline = "OUTLINE",
    valueOwnSize = false, valueOwnFont = false, valueFont = "", valueOutline = "OUTLINE",
    rankOwnSize = false, rankOwnFont = false, rankFont = "", rankOutline = "OUTLINE",
    titleOwnSize = false, titleOwnFont = false, titleFont = "", titleOutline = "OUTLINE",
    timeOwnSize = false, timeOwnFont = false, timeFont = "", timeOutline = "OUTLINE",
    summaryOwnSize = false, summaryOwnFont = false, summaryFont = "", summaryOutline = "OUTLINE",
    headOwnSize = false, headOwnFont = false, headFont = "", headOutline = "OUTLINE",
    headSize = 10,
    nameClassColor = false, valueClassColor = false, valueFontSize = 11, rankSize = 10, youLabel = false,
    nameMaxLetters = 0, percentDecimals = 1, rateSuffix = false,
    titleText = "list", titleX = 0, titleY = 0, timeX = 0, timeY = 0, showButtons = true,
    headerAlpha = 1, timeBrackets = false, timeByTitle = false,
    classColors = {}, raidMode = false, hideDelay = 8, ownBarStyle = "bar", edgeStyle = "accent",
    keepFights = 30,
    backgroundImage = "", backgroundPath = "", imageAlpha = 1, imageTile = false, imageTileSize = 128,
    barCustomColor = false, ownBarColor = false, edgeColor = false,
    nameColor = false, valueColor = false, rankColor = false, columnColor = false, titleColor = false,
    timeColor = false, summaryColor = false,
    windowColor = false, headerColor = false, borderColor = false,
    ownLook2 = false, ownLook3 = false,
    barHeight2 = 20, barHeight3 = 20, barSpacing2 = 2, barSpacing3 = 2, barAlpha2 = 0.85, barAlpha3 = 0.85, growUp2 = false, growUp3 = false,
    fontSize2 = 11, fontSize3 = 11, showIcons2 = true, showIcons3 = true, showRanks2 = true, showRanks3 = true, backgroundAlpha2 = 0.9, backgroundAlpha3 = 0.9,
    headerAlpha2 = 1, headerAlpha3 = 1, showBorder2 = true, showBorder3 = true, barColor2 = "class", barColor3 = "class",
    columns2 = "auto", columns3 = "auto", showDivider2 = false, showDivider3 = false,
    showColumnHeaders2 = true, showColumnHeaders3 = true,
    mode = "damage", session = "current", width = 300, height = 206, lower = "", scale = 1,
    meterPos = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -24, y = 210 },
    window2 = false, mode2 = "healing", session2 = "current", width2 = 300, height2 = 206, lower2 = "", scale2 = 1,
    meterPos2 = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -24, y = 420 },
    window3 = false, mode3 = "taken", session3 = "current", width3 = 300, height3 = 206, lower3 = "", scale3 = 1,
    meterPos3 = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -24, y = 630 },
})
ns.DamageMeterSettings = S

local DM = { Settings = S, TITLE = TITLE, MAX_WINDOWS = MAX_WINDOWS }
ns.DamageMeter = DM

function DM.LookKey(index, key)
    if index and DM.C.OWN_LOOK[key] and S.Get("ownLook" .. index) == true then
        return key .. index
    end
    return key
end

function DM.CopyLook(index)
    for _, key in ipairs(DM.C.OWN_LOOK_ORDER) do S.Set(key .. index, S.Get(key)) end
end

function DM.ResetSettings()
    local keys = {}
    for key in pairs(S.DB()) do
        if key ~= "enabled" and not key:find("^meterPos") then keys[#keys + 1] = key end
    end
    for _, key in ipairs(keys) do S.Set(key, nil) end
end

function DM.Setting(index, key)
    return S.Get(DM.LookKey(index, key))
end

local slotsOf, slotsKept = {}, 0

local function ParseColumns(value, rateFirst)
    local C = DM.C
    local slots, seen = {}, {}
    if type(value) ~= "string" or value == "auto" then
        slots = { "name", "total", "rate" }
        if rateFirst then slots[2], slots[3] = "rate", "total" end
    else
        for kind in value:gmatch("[^,]+") do
            if C.COLUMN_KINDS[kind] and #slots < C.COLUMN_SLOTS and (kind == "none" or not seen[kind]) then
                slots[#slots + 1] = kind
                seen[kind] = true
            end
        end
    end
    local named = false
    for _, kind in ipairs(slots) do
        if kind == "name" then named = true end
    end
    if not named then
        table.insert(slots, 1, "name")
        slots[C.COLUMN_SLOTS + 1] = nil
    end
    for i = #slots + 1, C.COLUMN_SLOTS do slots[i] = "none" end
    return slots
end

function DM.ColumnSlots(value, mode)
    local rateFirst = mode ~= nil and mode.rateFirst == true
    local key = (rateFirst and "r" or "n") .. tostring(value)
    local slots = slotsOf[key]
    if not slots then
        if slotsKept >= SLOTS_KEPT then slotsOf, slotsKept = {}, 0 end
        slots = ParseColumns(value, rateFirst)
        slotsOf[key] = slots
        slotsKept = slotsKept + 1
    end
    return slots
end

function DM.SetColumnSlot(index, slot, kind, mode)
    local key = DM.LookKey(index, "columns")
    local slots = {}
    for i, kept in ipairs(DM.ColumnSlots(S.Get(key), mode)) do slots[i] = kept end
    local old = slots[slot]
    if old == nil or old == kind or not DM.C.COLUMN_KINDS[kind] then return end
    local holder
    if kind ~= "none" then
        for i, other in ipairs(slots) do
            if other == kind then holder = i end
        end
    end
    if holder then
        slots[holder], slots[slot] = old, kind
    elseif old == "name" then
        local free
        for i, other in ipairs(slots) do
            if other == "none" then
                free = i
                break
            end
        end
        if kind == "none" or not free then return end
        slots[free], slots[slot] = "name", kind
    else
        slots[slot] = kind
    end
    S.Set(key, table.concat(slots, ","))
end

function DM.HasColumn(index, kind)
    for _, other in ipairs(DM.ColumnSlots(DM.Setting(index, "columns"))) do
        if other == kind then return true end
    end
    return false
end

function DM.Key(base, index)
    return index and index > 1 and base .. index or base
end

function DM.On()
    return S.Get("enabled")
end

function DM.WindowName(index, shown)
    local title = shown and ns.L(TITLE) or TITLE
    return index > 1 and title .. " " .. index or title
end

function DM.WindowOn(index)
    return index == 1 or S.Get(DM.Key("window", index)) == true
end

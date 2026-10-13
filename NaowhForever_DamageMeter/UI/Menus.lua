-- Menus.lua: a window's menus: its session and the rest.
local ns = _G.NaowhForever

local DM = ns.DamageMeter
local S = DM.Settings
local C, Key = DM.C, DM.Key

local TEXT_LIST, TEXT_LOWER, TEXT_NONE = ns.L("List"), ns.L("Second List"), ns.L("None")
local TEXT_SESSION = ns.L("Session")
local TEXT_FIGHTS, TEXT_NO_FIGHTS = ns.L("Past Fights"), ns.L("No Past Fights Yet")
local TEXT_REPORT, TEXT_RESET, TEXT_RESET_ASK = ns.L("Report To"), ns.L("Reset Data"), C.TEXT_RESET_ASK
local TEXT_ADD, TEXT_CLOSE, TEXT_LOCK, TEXT_SETTINGS = ns.L("Add Window"), ns.L("Close Window"), ns.L("Lock Window"), ns.L("Settings")
local TEXT_RAID, TEXT_BAR_COLOR = ns.L("Raid Mode"), ns.L("Bar Color")
local TEXT_HISTORY, TEXT_SHOT = ns.L("Fight History"), ns.L("Take Screenshot")
local SHOT_DELAY = 0.3

local Menus = {}
DM.Menus = Menus

local function Chosen(w, base, value)
    return function() return w.fight == nil and S.Get(Key(base, w.index)) == value end
end

local function ListChoices(menu, w, lower)
    local setting = Key(lower and "lower" or "mode", w.index)
    local function Choose(key)
        if lower then w.offset2 = 0 else w.offset = 0 end
        S.Set(setting, key)
    end
    if lower then
        menu:CreateRadio(TEXT_NONE, function() return S.Get(setting) == "" end, function() Choose("") end)
    end
    for _, key in ipairs(C.MODE_ORDER) do
        menu:CreateRadio(ns.L(C.MODE_LABELS[key]), function() return S.Get(setting) == key end,
            function() Choose(key) end)
    end
end

local function SessionChoices(menu, w)
    for _, key in ipairs(C.SESSION_ORDER) do
        menu:CreateRadio(ns.L(C.SESSION_LABELS[key]), Chosen(w, "session", key),
            function() w.fight, w.offset = nil, 0; S.Set(Key("session", w.index), key); DM.Refresh() end)
    end
    local fights = DM.Fights()
    menu:CreateDivider()
    menu:CreateTitle(#fights > 0 and TEXT_FIGHTS or TEXT_NO_FIGHTS)
    for _, fight in ipairs(fights) do
        menu:CreateRadio(DM.FightLabel(fight, true), function() return w.fight == fight.id end,
            function() w.fight, w.offset = fight.id, 0; DM.Refresh() end)
    end
end

function Menus.Session(w, owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(TEXT_SESSION)
        SessionChoices(root, w)
    end)
end

local function TakeScreenshot()
    C_Timer.After(SHOT_DELAY, function()
        if Screenshot then pcall(Screenshot) end
    end)
end

local function FirstClosed()
    for i = 2, DM.MAX_WINDOWS do
        if not DM.WindowOn(i) then return i end
    end
end

local function Report(w, channel)
    DM.Report(channel, S.Get(Key("mode", w.index)), S.Get(Key("session", w.index)), w.fight)
end

function Menus.Window(w, owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(DM.WindowName(w.index, true))
        ListChoices(root:CreateButton(TEXT_LIST), w, false)
        SessionChoices(root:CreateButton(TEXT_SESSION), w)
        ListChoices(root:CreateButton(TEXT_LOWER), w, true)
        root:CreateDivider()
        local report = root:CreateButton(TEXT_REPORT)
        for _, channel in ipairs(DM.Channels()) do
            report:CreateButton(ns.L(channel.label), function() Report(w, channel.key) end)
        end
        root:CreateButton(TEXT_HISTORY, function() DM.HistoryWindow.Toggle() end)
        root:CreateButton(TEXT_SHOT, TakeScreenshot)
        root:CreateButton(TEXT_RESET, function() ns.Confirm(TEXT_RESET_ASK, DM.Reset) end)
        root:CreateDivider()
        local free = FirstClosed()
        if free then root:CreateButton(TEXT_ADD, function() S.Set(Key("window", free), true) end) end
        if w.index > 1 then root:CreateButton(TEXT_CLOSE, function() S.Set(Key("window", w.index), false) end) end
        local bars = root:CreateButton(TEXT_BAR_COLOR)
        local setting = DM.LookKey(w.index, "barColor")
        for _, key in ipairs(C.BAR_COLORS_ORDER) do
            bars:CreateRadio(ns.L(C.BAR_COLORS[key]), function() return S.Get(setting) == key end,
                function() S.Set(setting, key) end)
        end
        root:CreateCheckbox(TEXT_RAID, function() return S.Get("raidMode") == true end,
            function() S.Set("raidMode", not S.Get("raidMode")) end)
        root:CreateCheckbox(TEXT_LOCK, function() return S.Get("locked") == true end,
            function() S.Set("locked", not S.Get("locked")) end)
        root:CreateButton(TEXT_SETTINGS, function() ns.OpenOptionsWindow(DM.TITLE) end)
    end)
end

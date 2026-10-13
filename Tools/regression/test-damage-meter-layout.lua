-- Offline behavior checks for the Damage Meter Layout (NaowhForever_QoL/Combat/DamageMeterLayout.lua) against a stub
-- of the game's Edit Mode manager and C_EditMode; they do not emulate the client. Run with Lua 5.1 from the repository root.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local function Copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = Copy(v) end
    return out
end

local E = { Visibility = 0, Style = 1, Numbers = 2, FrameWidth = 3, FrameHeight = 4, Padding = 5, Transparency = 6,
    ShowSpecIcon = 8, ShowClassColor = 9, BarHeight = 10, TextSize = 11, BackgroundTransparency = 12 }

local function Info(active)
    return { activeLayout = active or 3, layouts = {
        { layoutName = "Modern", layoutType = 0, systems = {} },
        { layoutName = "Classic", layoutType = 0, systems = {} },
        { layoutName = "Mine", layoutType = 1, systems = {
            { system = 1, settings = { { setting = 0, value = 9 } } },
            { system = 23, settings = {
                { setting = E.BarHeight, value = 5 },
                { setting = E.Padding, value = 2 },
                { setting = E.TextSize, value = 5 },
                { setting = E.Transparency, value = 50 },
                { setting = E.BackgroundTransparency, value = 0 },
                { setting = E.FrameWidth, value = 100 },
                { setting = E.Style, value = 0 },
                { setting = E.Numbers, value = 1 },
                { setting = E.Visibility, value = 0 },
                { setting = E.ShowSpecIcon, value = 1 },
                { setting = E.ShowClassColor, value = 1 } } } } },
    } }
end

local function Boot(opts)
    opts = opts or {}
    local s = { printed = {}, saves = {}, timers = {}, converts = 0, account = {}, refreshes = 0 }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Print = function(text) s.printed[#s.printed + 1] = text end,
        UI = { RefreshPage = function() s.refreshes = s.refreshes + 1 end },
        AccountSettings = function() return s.account end }
    s.manager = { layoutInfo = opts.info or Info(), IsShown = function() return s.editOpen == true end }
    local env = { ipairs = ipairs, pairs = pairs, type = type, pcall = pcall, tostring = tostring,
        tonumber = tonumber, table = table, NaowhForever = ns, CopyTable = Copy,
        Enum = { EditModeSystem = { DamageMeter = 23 }, EditModeDamageMeterSetting = E,
            EditModeLayoutType = { Preset = 0, Account = 1, Character = 2 },
            DamageMeterStyle = { Default = 0, Bordered = 1, Thin = 2 },
            DamageMeterNumbers = { Minimal = 0, Compact = 1, Complete = 2 },
            DamageMeterVisibility = { Always = 0, InCombat = 1, Hidden = 2, InGroup = 3 } },
        InCombatLockdown = function() return s.combat == true end,
        C_Timer = { After = function(_, fn) s.timers[#s.timers + 1] = fn end },
        C_EditMode = { SaveLayouts = function(info)
                if s.saveError then error(s.saveError) end
                s.saves[#s.saves + 1] = info
                if opts.apply then s.manager.layoutInfo = Copy(info) end
            end,
            ConvertLayoutInfoToString = function(layout)
                s.converts = s.converts + 1
                return "export:" .. layout.layoutName
            end } }
    env._G = env
    if not opts.noManager then env.EditModeManagerFrame = s.manager end
    local chunk = assert(loadfile("NaowhForever_QoL/Combat/DamageMeterLayout.lua"))
    setfenv(chunk, env)
    chunk("NaowhForever")
    function s.Flush()
        local list = s.timers
        s.timers = {}
        for _, fn in ipairs(list) do fn() end
    end
    s.rows = ns.DamageMeterLayout.rows
    function s.Row(label)
        for _, row in ipairs(s.rows) do
            if row.label == label then return row end
        end
    end
    function s.Stored(save, setting)
        for _, entry in ipairs(save.layouts[3].systems[2].settings) do
            if entry.setting == setting then return entry.value end
        end
    end
    return s
end

-- the rows, in the game's own order, and what they read
do
    local s = Boot()
    local labels = {}
    for _, row in ipairs(s.rows) do labels[#labels + 1] = row.label end
    check("the game's settings in its order, then Restore", table.concat(labels, "|") ==
        "Bar Style|Numbers|Window Width|Window Height|Bar Height|Bar Spacing|Window Opacity|Background Opacity|Text Size|Visibility"
        .. "|Show Spec Icon|Show Class Color|Restore Game Settings")
    check("choices: the game's names", s.Row("Bar Style").choice[1]["1"] == "Bordered"
        and s.Row("Visibility").choice[1]["3"] == "In Group" and #s.Row("Numbers").choice[2] == 3)
    check("what each reads, from what Edit Mode stores", s.Row("Bar Height").get() == 20 and s.Row("Bar Spacing").get() == 4
        and s.Row("Text Size").get() == 100 and s.Row("Window Opacity").get() == 100 and s.Row("Background Opacity").get() == 0
        and s.Row("Window Width").get() == 300 and s.Row("Bar Style").get() == "0" and s.Row("Numbers").get() == "1"
        and s.Row("Visibility").get() == "0" and s.Row("Show Spec Icon").get() == true)
    check("sliders have the game's ranges and steps", s.Row("Bar Height").slider[1] == 15 and s.Row("Bar Height").slider[2] == 40
        and s.Row("Text Size").slider[3] == 10 and s.Row("Window Opacity").slider[1] == 50
        and s.Row("Window Height").slider[2] == 400 and s.Row("Window Width").frame == true)
    for _, row in ipairs(s.rows) do
        check(row.label .. ": help is short", #row.help < 100)
    end
end

-- every kind of value is stored as Edit Mode stores it
do
    local s = Boot()
    s.Row("Bar Height").set(30)
    s.Row("Bar Spacing").set(6)
    s.Row("Text Size").set(120)
    s.Row("Window Opacity").set(80)
    s.Row("Background Opacity").set(25)
    s.Row("Window Width").set(400)
    s.Row("Bar Style").set("1")
    s.Row("Visibility").set("2")
    s.Row("Show Spec Icon").set(false)
    check("nothing is written while the sliders move", #s.saves == 0)
    s.Flush()
    check("one save per setting", #s.saves == 9)
    local last = s.saves[#s.saves]
    check("the saves are separate, as the settings are", s.Stored(s.saves[1], E.BarHeight) == 15)
    local function StoredIn(setting)
        for _, save in ipairs(s.saves) do
            local v = s.Stored(save, setting)
            local was = s.Stored(Info(), setting)
            if v ~= was then return v end
        end
    end
    check("Bar Height 30 is 15", StoredIn(E.BarHeight) == 15)
    check("Bar Spacing 6 is 4", StoredIn(E.Padding) == 4)
    check("Text Size 120 percent is 7", StoredIn(E.TextSize) == 7)
    check("Transparency 80 percent is 30", StoredIn(E.Transparency) == 30)
    check("Background 25 percent is 25", StoredIn(E.BackgroundTransparency) == 25)
    check("Frame Width 400 is 200", StoredIn(E.FrameWidth) == 200)
    check("Style Bordered is the enum's 1", StoredIn(E.Style) == 1)
    check("Visibility Hidden is the enum's 2", StoredIn(E.Visibility) == 2)
    check("Show Spec Icon off is 0", StoredIn(E.ShowSpecIcon) == 0)
    check("the others in a save stay as they were", s.Stored(last, E.Numbers) == 1 and last ~= s.manager.layoutInfo
        and #last.layouts == 3 and last.activeLayout == 3 and s.Stored(s.saves[1], E.Padding) == 2)
end

-- a pause before a save, the range held, the game's own table never written
do
    local s = Boot()
    local original = Copy(s.manager.layoutInfo)
    s.Row("Bar Height").set(24); s.Row("Bar Height").set(26); s.Row("Bar Height").set(100)
    s.Flush()
    check("three moves of one slider are one save, the last, held to the range", #s.saves == 1
        and s.Stored(s.saves[1], E.BarHeight) == 25)
    check("the game's own table is as it was", s.manager.layoutInfo.layouts[3].systems[2].settings[1].value == 5
        and original.layouts[3].systems[2].settings[1].value == 5)
    s.Row("Bar Height").set(1); s.Flush()
    check("too short is 15, stored 0", s.Stored(s.saves[2], E.BarHeight) == 0)
    s.Row("Bar Height").set(20); s.Flush()
    check("the height it already has: nothing to save", #s.saves == 2)
end

-- the slider shows where it is going, and says when the game did not take it
do
    local s = Boot({ apply = true })
    s.Row("Bar Height").set(30)
    check("shown at once, before anything is saved", s.Row("Bar Height").get() == 30 and #s.saves == 0)
    s.Flush(); s.Flush()
    check("saved and taken: the layout says it too, with no note", s.Row("Bar Height").get() == 30
        and s.Row("Bar Height").note() == nil and #s.printed == 0)
    s.manager.layoutInfo.layouts[3].systems[2].settings[1].value = 0
    check("and when the layout changes elsewhere, it follows", s.Row("Bar Height").get() == 15)
    local stale = Boot()
    stale.Row("Text Size").set(120); stale.Flush(); stale.Flush()
    check("saved but not taken: Needs a /reload under that row only", stale.Row("Text Size").note() == "Needs a /reload"
        and stale.Row("Text Size").get() == 120 and stale.Row("Bar Height").note() == nil)
end

-- what it will not do, said under the row that was moved
do
    local s = Boot()
    s.combat = true
    s.Row("Bar Spacing").set(8); s.Flush()
    check("in combat: not saved, said under the row", #s.saves == 0 and s.Row("Bar Spacing").note():find("combat", 1, true)
        and s.Row("Bar Height").note() == nil and #s.printed == 0 and s.refreshes >= 1)
    check("and the slider goes back to the layout's own", s.Row("Bar Spacing").get() == 4)
    s.combat = false
    s.editOpen = true
    s.Row("Bar Spacing").set(8); s.Flush()
    check("with Edit Mode open: said", s.Row("Bar Spacing").note():find("Edit Mode", 1, true) ~= nil and #s.saves == 0)
    s.editOpen = false
    s.manager.layoutInfo.activeLayout = 1
    s.Row("Bar Spacing").set(8); s.Flush()
    check("on one of the game's own layouts: said, with nothing backed up", #s.saves == 0
        and s.Row("Bar Spacing").note():find("copy", 1, true) ~= nil and s.converts == 0)
    s.manager.layoutInfo.activeLayout = 9
    s.Row("Bar Spacing").set(8); s.Flush()
    check("a layout that is not there: said", #s.saves == 0 and s.Row("Bar Spacing").note() ~= nil)
    s.manager.layoutInfo.activeLayout = 3
    s.manager.layoutInfo.layouts[3].systems[2] = nil
    s.Row("Bar Spacing").set(8); s.Flush()
    check("a layout without a damage meter: said", #s.saves == 0
        and s.Row("Bar Spacing").note():find("damage meter", 1, true) ~= nil)
    local none = Boot({ noManager = true })
    check("no manager: the rows read their defaults", none.Row("Bar Height").get() == 24 and none.Row("Show Class Color").get() == true)
    none.Row("Bar Height").set(30); none.Flush()
    check("and say so", #none.saves == 0 and none.Row("Bar Height").note() ~= nil)
    local refused = Boot()
    refused.saveError = "protected"
    refused.Row("Bar Height").set(30); refused.Flush()
    check("a refused save is said, with the reason", refused.Row("Bar Height").note():find("protected", 1, true) ~= nil)
end

-- a setting a layout never set is added
do
    local info = Info()
    info.layouts[3].systems[2].settings = { { setting = E.TextSize, value = 5 } }
    local s = Boot({ info = info })
    check("no entry: the game's default is shown", s.Row("Bar Height").get() == 24 and s.Row("Numbers").get() == "1")
    s.Row("Bar Height").set(28); s.Flush()
    local settings = s.saves[1].layouts[3].systems[2].settings
    check("and it is added, the others kept", #settings == 2 and settings[1].value == 5 and settings[2].setting == E.BarHeight
        and settings[2].value == 13)
end

-- Original Settings puts back what the first change found
do
    local s = Boot({ apply = true })
    s.Row("Restore Game Settings").button()
    check("nothing to restore yet: said, nothing saved", #s.saves == 0 and s.Row("Restore Game Settings").note() ~= nil)
    s.Row("Bar Height").set(30); s.Flush(); s.Flush()
    s.Row("Text Size").set(120); s.Flush(); s.Flush()
    check("two changes were saved", #s.saves == 2 and s.account.damageMeterLayoutBackup.name == "Mine"
        and s.account.damageMeterLayoutBackup.values.BarHeight == 5
        and s.account.damageMeterLayoutBackup.values.TextSize == 5 and s.converts == 1)
    s.Row("Restore Game Settings").button()
    check("the rows show the originals at once", s.Row("Bar Height").get() == 20 and s.Row("Text Size").get() == 100
        and s.Row("Restore Game Settings").note() == nil)
    s.Flush(); s.Flush()
    local last = s.saves[#s.saves]
    check("one save puts them all back, as stored", #s.saves == 3 and s.Stored(last, E.BarHeight) == 5
        and s.Stored(last, E.TextSize) == 5 and s.Stored(last, E.Style) == 0)
    local late = Boot()
    late.Row("Bar Height").set(30); late.Flush(); late.Flush()
    late.manager.layoutInfo.layouts[3].systems[2].settings[1].value = 15
    late.Row("Restore Game Settings").button()
    check("the rows show the originals before the game has taken them", late.Row("Bar Height").get() == 20)
end

print("PASS damage meter layout: " .. checks .. " checks")

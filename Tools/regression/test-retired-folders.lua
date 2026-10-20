-- Run with Lua 5.1 from the repository root: RetireOldFolders cut out of Core/Core.lua and run on stubs.
-- An old module folder that moved into QoL is switched off at login; when it loaded this session too,
-- a reload is offered at once. For that session the QoL Top Bar stays off and leaves its card to the old
-- addon, so the bar and its secure buttons are built once and the card is declared once.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local f = assert(io.open("Core/Core.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n")
f:close()

local retired = assert(loadstring("return " .. assert(source:match("\nlocal RETIRED_ADDONS = (%b{})\n"), "RETIRED_ADDONS")))()
local text = assert(source:match('\nlocal TEXT_RETIRED = "([^"]+)"\n'), "TEXT_RETIRED")
local combatText = assert(source:match('\nlocal TEXT_RETIRED_COMBAT = "([^"]+)"\n'), "TEXT_RETIRED_COMBAT")
local utilitiesText = assert(source:match('\nlocal TEXT_RETIRED_UTILITIES = "([^"]+)"\n'), "TEXT_RETIRED_UTILITIES")
local retiredText = assert(loadstring("local TEXT_RETIRED_COMBAT, TEXT_RETIRED_UTILITIES = ...\nreturn "
    .. assert(source:match("\nlocal RETIRED_TEXT = (%b{})\n"), "RETIRED_TEXT")))(combatText, utilitiesText)
local reloadText = assert(source:match('\nlocal TEXT_RETIRED_RELOAD = "([^"]+)"\n'), "TEXT_RETIRED_RELOAD")
local body = assert(source:match("\n(local function RetireOldFolders%(%)\n.-\nend)\n"), "RetireOldFolders")

local listed = {}
for _, addon in ipairs(retired) do listed[addon] = true end
check("the old Top Bar folder is retired", listed.NaowhForever_TopBar)
check("as are the old Glimmer folders", listed.NaowhForever_Glimmer and listed.NaowhForever_GlimmerData)
check("and the Top Bar ships no addon of its own", io.open("NaowhForever_TopBar/NaowhForever_TopBar.toc") == nil)
local HOSTED = { GearSets = "Combat", Blessings = "Combat", AuraBuffs = "Combat", ThreatMeter = "Combat", PvP = "Combat",
    SwingTimer = "Combat", ConsumableBar = "Combat", InstanceTracker = "Utilities", Journeys = "Utilities",
    Macros = "Utilities", GroupInspect = "Utilities", ActionBars = "Utilities" }
for name, host in pairs(HOSTED) do
    local addon = "NaowhForever_" .. name
    check(addon .. " is retired: it ships inside NaowhForever_" .. host .. " now", listed[addon]
        and io.open(addon .. "/" .. addon .. ".toc") == nil
        and io.open("NaowhForever_" .. host .. "/" .. name .. "/" .. name .. ".xml") ~= nil
        and retiredText[addon] == (host == "Combat" and combatText or utilitiesText))
end

local function Run(exists, loaded)
    local w = { disabled = {}, printed = {}, reloads = {} }
    local ns = {
        L = function(s) return s end,
        Print = function(s) w.printed[#w.printed + 1] = s end,
        ConfirmReload = function(s) w.reloads[#w.reloads + 1] = s end,
    }
    local C_AddOns = {
        DoesAddOnExist = function(addon) return exists[addon] == true end,
        IsAddOnLoaded = function(addon) return loaded[addon] == true end,
        DisableAddOn = function(addon, who) w.disabled[addon] = who == nil end,
    }
    local chunk = assert(loadstring("local ns, C_AddOns, RETIRED_ADDONS, RETIRED_TEXT, TEXT_RETIRED, "
        .. "TEXT_RETIRED_RELOAD = ...\n" .. body .. "\nRetireOldFolders()"))
    chunk(ns, C_AddOns, retired, retiredText, text, reloadText)
    return w
end

local w = Run({}, {})
check("no old folder: nothing is switched off or said", next(w.disabled) == nil and #w.printed == 0 and #w.reloads == 0)

w = Run({ NaowhForever_TopBar = true }, {})
check("an old folder that did not load is switched off", w.disabled.NaowhForever_TopBar)
check("with a line in chat and no reload", #w.printed == 1 and w.printed[1] == text:format("NaowhForever_TopBar")
    and #w.reloads == 0)

w = Run({ NaowhForever_TopBar = true }, { NaowhForever_TopBar = true })
check("an old folder that loaded is switched off too", w.disabled.NaowhForever_TopBar)
check("and a reload is offered, the chat line still said", #w.reloads == 1 and w.reloads[1] == reloadText
    and #w.printed == 1 and w.printed[1] == text:format("NaowhForever_TopBar"))

w = Run({ NaowhForever_SwingTimer = true }, {})
check("an old Combat module's folder is said to be in Combat, not Quality of Life",
    #w.printed == 1 and w.printed[1] == combatText:format("NaowhForever_SwingTimer"))
w = Run({ NaowhForever_Macros = true }, { NaowhForever_Macros = true })
check("an old Utilities module's folder is said to be in Utilities, and a reload offered",
    #w.printed == 1 and w.printed[1] == utilitiesText:format("NaowhForever_Macros")
    and w.printed[1]:find("Naowh Forever: Utilities", 1, true) and #w.reloads == 1 and w.disabled.NaowhForever_Macros)
for addon in pairs(retiredText) do check(addon .. " is one of the retired folders", listed[addon]) end

w = Run({ NaowhForever_DamageMeter = true }, { NaowhForever_DamageMeter = true })
check("an old Damage Meter folder, no longer shipped, is switched off and said to be no longer part of it",
    w.disabled.NaowhForever_DamageMeter and #w.printed == 1 and #w.reloads == 1
    and w.printed[1] == retiredText.NaowhForever_DamageMeter:format("NaowhForever_DamageMeter")
    and w.printed[1]:find("no longer part of Naowh Forever", 1, true))
check("and the release leaves the Damage Meter out", io.open(".pkgmeta", "rb"):read("*a"):find("ignore:.-NaowhForever_DamageMeter") ~= nil)

w = Run({ NaowhForever_Language = true }, { NaowhForever_Language = true })
check("the old Language folder is said to be part of Naowh Forever, and a reload offered", #w.printed == 1
    and w.printed[1] == retiredText.NaowhForever_Language:format("NaowhForever_Language")
    and w.printed[1]:find("part of Naowh Forever:", 1, true) and #w.reloads == 1 and w.disabled.NaowhForever_Language)
local tocFile = assert(io.open("NaowhForever.toc", "rb"))
local toc = tocFile:read("*a")
tocFile:close()
check("the language pick loads with Naowh Forever's own saved variables, before its first file",
    toc:find("\n## LoadSavedVariablesFirst: 1\r?\n") and not toc:find("NaowhForever_Language", 1, true)
    and io.open("NaowhForever_Language/NaowhForever_Language.toc") == nil)

w = Run({ NaowhForever_PvP = true, NaowhForever_SwingTimer = true, NaowhForever_TopBar = true },
    { NaowhForever_PvP = true, NaowhForever_SwingTimer = true, NaowhForever_TopBar = true })
check("several old folders loaded: one line each, one reload", #w.printed == 3 and #w.reloads == 1
    and w.disabled.NaowhForever_PvP and w.disabled.NaowhForever_SwingTimer and w.disabled.NaowhForever_TopBar)

-- The QoL copy of the Top Bar, its TopBar.lua and its card's file, run on stubs.
local function Guard(exists, enabled, loaded)
    local cards = {}
    local ns = {
        L = function(s) return s end,
        FEATURES = { topBar = {} },
        UI = { ModuleSettings = function() return { Get = function(k) return k == "enabled" end } end },
        Shared = {
            Parts = {},
            Style = {},
            Settings = {
                Group = function(name) return { group = name } end,
                Page = function() return { Card = function(_, spec) cards[#cards + 1] = spec end } end,
            },
        },
    }
    local old = "NaowhForever_TopBar"
    local env = setmetatable({ NaowhForever = ns, C_AddOns = {
        DoesAddOnExist = function(addon) return addon == old and exists end,
        GetAddOnEnableState = function(addon) return addon == old and enabled and 2 or 0 end,
        IsAddOnLoaded = function(addon) return addon == old and loaded end,
    } }, { __index = _G })
    env._G = env
    for _, path in ipairs({ "NaowhForever_QoL/TopBar/TopBar.lua", "NaowhForever_QoL/TopBar/UI/SettingsPage.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        if path:find("SettingsPage") then
            ns.TopBar.Layout, ns.TopBar.Preview = { Reset = function() end }, {}
        end
        chunk()
    end
    return ns.TopBar.On(), #cards
end

local on, cards = Guard(false, false, false)
check("no old folder: the QoL Top Bar runs and declares its card", on and cards == 1)
on, cards = Guard(true, false, false)
check("an old folder switched off: the same", on and cards == 1)
on, cards = Guard(true, true, true)
check("the old addon loaded this session: the QoL Top Bar stays off", not on)
check("and leaves the card to the old addon, which declares it after QoL", cards == 0)

-- The Combat and Utilities modules do the same: each asks once, as it loads, whether its old folder is
-- enabled (OLD_COPY on its table). While it is, its switch reads off and its card files declare nothing.
local function Source(path)
    local file = assert(io.open(path, "rb"))
    local s = file:read("*a"):gsub("\r\n", "\n")
    file:close()
    return s
end

local SHORT = { GearSets = "G", Blessings = "B", AuraBuffs = "A", ThreatMeter = "TM", PvP = "P", SwingTimer = "ST",
    ConsumableBar = "CB", InstanceTracker = "IT", Journeys = "Jy", Macros = "M", GroupInspect = "GI", ActionBars = "A" }
local TocFiles = dofile("Tools/regression/toc_files.lua")
for name, host in pairs(HOSTED) do
    local info, folder = { name, SHORT[name] }, "NaowhForever_" .. host .. "/" .. name .. "/"
    local main = Source(folder .. info[1] .. ".lua")
    check(name .. " asks whether its old folder is enabled", main:find('\nlocal OLD_ADDON = "NaowhForever_' .. name
        .. '"\nlocal OLD_COPY = C_AddOns.DoesAddOnExist(OLD_ADDON) and C_AddOns.GetAddOnEnableState(OLD_ADDON) > 0\n',
        1, true) and main:find("OLD_COPY = OLD_COPY", 1, true))
    local pages = 0
    for _, path in ipairs(TocFiles("^" .. folder .. ".*%.lua$")) do
        local s = Source(path)
        local at = s:find("Settings.Page(", 1, true)
        if at then
            pages = pages + 1
            local guard = s:find("\nif " .. info[2] .. ".OLD_COPY then return end\n", 1, true)
                or s:find("\nif ns." .. name .. ".OLD_COPY then return end\n", 1, true)
            check(path .. " declares nothing while the old folder is enabled", guard and guard < at)
        end
    end
    check(name .. " has its cards", pages > 0)
end

local function PvP(enabled)
    local ns = { FEATURES = { pvp = { enabled = true, auras = true } }, PvPSpells = { crowdControl = {}, debuffs = {} },
        UI = { ModuleSettings = function(_, defaults) return { Get = function(k) return defaults[k] end } end } }
    local env = setmetatable({ NaowhForever = ns, C_AddOns = {
        DoesAddOnExist = function(addon) return addon == "NaowhForever_PvP" end,
        GetAddOnEnableState = function(addon) return addon == "NaowhForever_PvP" and enabled and 2 or 0 end,
    } }, { __index = _G })
    env._G = env
    local chunk = assert(loadfile("NaowhForever_Combat/PvP/PvP.lua"))
    setfenv(chunk, env)
    chunk()
    return ns.PvP.Enabled(), ns.PvPSettings.Get("auras")
end

local pvpOn, auras = PvP(false)
check("PvP with its old folder switched off: on as its switch says", pvpOn == true and auras ~= nil)
pvpOn, auras = PvP(true)
check("PvP with its old folder enabled: its switch reads off, its other settings as saved", pvpOn == false
    and auras ~= nil)

local function ActionBars(enabled)
    local ns = { FEATURES = { actionBars = { enabled = true } },
        UI = { ModuleSettings = function(_, defaults) return { Get = function(k) return defaults[k] end } end } }
    local env = setmetatable({ NaowhForever = ns, C_AddOns = {
        DoesAddOnExist = function(addon) return addon == "NaowhForever_ActionBars" end,
        GetAddOnEnableState = function(addon) return addon == "NaowhForever_ActionBars" and enabled and 2 or 0 end,
    } }, { __index = _G })
    env._G = env
    local chunk = assert(loadfile("NaowhForever_Utilities/ActionBars/ActionBars.lua"))
    setfenv(chunk, env)
    chunk()
    return ns.ActionBars.On(), ns.ActionBarSettings.Get("importMacros")
end

local barsOn, macros = ActionBars(false)
check("Action Bars with its old folder switched off: on as its switch says", barsOn == true and macros == true)
barsOn, macros = ActionBars(true)
check("Action Bars with its old folder enabled: its switch reads off, its other settings as saved", barsOn == false
    and macros == true)

print(("test-retired-folders: %d checks passed"):format(checks))

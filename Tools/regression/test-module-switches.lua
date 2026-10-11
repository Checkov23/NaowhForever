-- Run with Lua 5.1 from the repository root: Settings > Modules and a module's own page switch read
-- and set the same state. A module switched off in its settings (a preset) reads off in both; turning
-- it on from Settings turns its setting on with no reload; a module whose addon is not loaded is
-- turned on through the reload prompt, its setting on for after the reload.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end
local NOTHING = function() end

local enabled, loaded = {}, {}
local confirms, reloads = {}, {}
local function Store(values)
    return { Get = function(key) return values[key] end, Set = function(key, value) values[key] = value end }
end
local qol = { enabled = true, groupInspect = true, bis = true }
local journal = { enabled = false }

local ns = {
    UI = { RefreshPage = NOTHING },
    L = function(text) return text end,
    QoLSettings = Store(qol),
    JournalSettings = Store(journal),
    Confirm = function(text, yes) confirms[#confirms + 1] = { text = text, yes = yes } end,
    ConfirmReload = function(text) reloads[#reloads + 1] = text end,
    AccountSettings = function() return {} end,
}
local env = setmetatable({
    NaowhForever = ns,
    ns = ns,
    C_AddOns = {
        GetAddOnEnableState = function(addon) return enabled[addon] and 2 or 0 end,
        IsAddOnLoaded = function(addon) return loaded[addon] == true end,
        EnableAddOn = function(addon) enabled[addon] = true end,
        DisableAddOn = function(addon) enabled[addon] = nil end,
    },
}, { __index = _G })
env._G = env
local modules = assert(loadstring(Read("Core/Options/Modules.lua"), "Modules"))
setfenv(modules, env)
modules()
local O = ns.Options

local page = Read("Core/Options/SettingsPage.lua")
local first = assert(page:find("local function NeedsTip(mod)", 1, true))
local last = assert(page:find("local function ModulesSection", first, true))
local rows = assert(loadstring("local MODULES, NameList, ModuleOn, SetModuleOn, O, TEXT_SWITCHES_WITH, Loaded = ...\n"
    .. page:sub(first, last - 1) .. "\nreturn ModuleRow", "SettingsPage"))
setfenv(rows, env)
local ModuleRow = rows(O.MODULES, O.NameList, O.ModuleOn, O.SetModuleOn, O, "|n|nSwitches with %s.", O.Loaded)

local function Module(name)
    for _, mod in ipairs(O.MODULES) do
        if mod.name == name then return mod end
    end
end

for _, addon in ipairs({ "NaowhForever_QoL", "NaowhForever_DungeonJournal", "NaowhForever_BiS" }) do
    enabled[addon], loaded[addon] = true, true
end

local journalMod = Module("Dungeon Journal")
local row = ModuleRow(journalMod)
check("switched off by a preset, its addon on: Settings reads off, as the page does",
    row.getValue() == false and O.ModuleOn(journalMod) == false)
row.setValue(true)
check("turned on from Settings: its setting on, no reload asked", journal.enabled == true and #confirms == 0
    and row.getValue() == true and O.ModuleOn(journalMod) == true)

local inspect = Module("Group Inspect")
row = ModuleRow(inspect)
qol.groupInspect = false
check("its addon off: reads off", row.getValue() == false)
row.setValue(true)
check("its addon not loaded: turned on through the reload prompt, nothing changed until confirmed",
    #confirms == 1 and qol.groupInspect == false and not enabled.NaowhForever_GroupInspect)
confirms[1].yes()
check("confirmed: its addon enabled, its setting on for after the reload, and a reload offered",
    enabled.NaowhForever_GroupInspect == true and qol.groupInspect == true and #reloads == 1)

local training = Module("Training Planner")
enabled.NaowhForever_Training = true
check("its addon enabled but not loaded yet: reads on until the reload", ModuleRow(training).getValue() == true)

row = ModuleRow(journalMod)
row.setValue(false)
check("turned off from Settings: its addon off through the prompt, as before", #confirms == 2)
confirms[2].yes()
check("confirmed: its addon disabled", not enabled.NaowhForever_DungeonJournal and row.getValue() == false)

print(("test-module-switches: %d checks passed"):format(checks))

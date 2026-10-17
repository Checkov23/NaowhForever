-- Run with Lua 5.1 from the repository root: a module's on/off follows the profile. The profile's
-- switches and this character's AddOn list are reconciled at login and on a profile switch (a new
-- character, an AddOn list changed by hand, a profile changed on another character), and a module
-- turned on or off writes both.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local World = dofile("Tools/regression/setup_world.lua")
local TRAINING, PROF, JOURNAL = "NaowhForever_Training", "NaowhForever_Professions", "NaowhForever_DungeonJournal"
local GEAR, COMBAT = "NaowhForever_GearSets", "NaowhForever_Combat"
local COMBAT_IDS = { "consumableBar", "gearSets", "blessings", "auraBuffs", "threatMeter", "pvp", "swingTimer" }
local MACROS, UTILITIES = "NaowhForever_Macros", "NaowhForever_Utilities"
local UTILITY_IDS = { "instanceTracker", "journeys", "macros", "groupInspect", "actionBars" }
local BIS, DISC = "NaowhForever_BiS", "NaowhForever_Discovery"
local QOL = "NaowhForever_QoL"

local function All(value)
    local out = {}
    for _, mod in ipairs(World().MODULES) do out[mod.addon] = value end
    return out
end

local function Game(root, account)
    return World({ enabled = All(true), loaded = All(true), root = root or {},
        account = account or { onboardingSeen = true } })
end

local function Writes(w)
    local list = {}
    for _, call in ipairs(w.calls) do
        if call.name == "EnableAddOn" or call.name == "DisableAddOn" then list[#list + 1] = call end
    end
    return list
end

local function Count(list, pick)
    local n = 0
    for _, call in ipairs(list) do if pick(call) then n = n + 1 end end
    return n
end

do
    local w = Game({ training = { enabled = false } }, {})
    check("an account that has not seen the onboarding is left to it", w.ns.ReconcileModules() == 0
        and #Writes(w) == 0 and w.account.moduleList == nil and #w.reloads == 0)
end

do
    local w = Game({ training = { enabled = false }, professions = { enabled = false } })
    check("a new character follows the profile: two modules off", w.ns.ReconcileModules() == 2)
    check("in its own AddOn list", not w.enabled[TRAINING] and not w.enabled[PROF] and w.enabled[JOURNAL])
    check("naming the character, never every character", #Writes(w) == 2 and Count(Writes(w), w.ForMe) == 2)
    check("the profile is as it was", w.root.training.enabled == false and w.root.professions.enabled == false)
    check("and one reload is offered", #w.reloads == 1)
    check("nothing differs at the next check: no call, no prompt", w.ns.ReconcileModules() == 0
        and #Writes(w) == 2 and #w.reloads == 1)
end

do
    local w = Game({ professions = { enabled = true } })
    w.enabled[PROF] = false
    check("an addon turned off before this change, its switch left on: adopted, not turned back on",
        w.ns.ReconcileModules() == 0 and #Writes(w) == 0 and #w.reloads == 0 and w.root.professions.enabled == false)
    w.enabled[JOURNAL] = false
    w.ns.ReconcileModules()
    check("a module that was never switched takes the list's state", w.root.journal.enabled == false)
    check("a module off by default, its addon on, is left as it is", w.root.discovery == nil
        and w.enabled.NaowhForever_Discovery)
end

do
    local w = Game()
    w.ns.ReconcileModules()
    w.enabled[JOURNAL] = false
    check("an AddOn list changed by hand since: the profile adopts it", w.ns.ReconcileModules() == 0
        and w.root.journal.enabled == false and #Writes(w) == 0)
    w.enabled[JOURNAL] = true
    w.ns.ReconcileModules()
    check("and adopts it going back on", w.root.journal.enabled == true and w.enabled[JOURNAL] and #Writes(w) == 0)
end

do
    local w = Game()
    w.ns.ReconcileModules()
    w.root.training = { enabled = false }
    check("a profile changed since (another character): applied to the list", w.ns.ReconcileModules() == 1
        and not w.enabled[TRAINING] and Count(Writes(w), w.ForMe) == 1 and #w.reloads == 1)
    check("and the next check is quiet", w.ns.ReconcileModules() == 0 and #w.reloads == 1)
end

do
    local w = Game({ qol = { groupInspect = true } })
    w.ns.ReconcileModules()
    w.root.qol.bis = false
    w.ns.ReconcileModules()
    check("a module its profile turns off takes the module that needs it", not w.enabled[BIS]
        and not w.On("groupInspect") and w.root.qol.groupInspect == false)
    w.root.qol.bis = true
    w.ns.ReconcileModules()
    check("the module that needs it stays off until it is turned on", w.enabled[BIS] and not w.On("groupInspect"))
end

do
    local w = Game({ qol = { gearSets = false } })
    check("a Combat module its profile turns off: its switch only, the Combat addon stays for the rest",
        w.ns.ReconcileModules() == 0 and w.enabled[COMBAT] and #Writes(w) == 0 and not w.On("gearSets")
        and w.On("blessings"))
    w.ns.SetModuleState(w.Item("pvp").addon, false)
    check("one switched off: its switch only, Combat stays on for the rest", w.enabled[COMBAT] and not w.On("pvp")
        and w.On("swingTimer"))
    for _, id in ipairs(COMBAT_IDS) do w.ns.SetModuleState(w.Item(id).addon, false) end
    local last = Writes(w)[#Writes(w)]
    check("all seven off: the Combat addon goes off for this character", not w.enabled[COMBAT]
        and last.name == "DisableAddOn" and last.addon == COMBAT and w.ForMe(last) and w.root.pvp.enabled == false)
    w.ns.SetModuleState(GEAR, true)
    check("one back on brings the Combat addon back", w.enabled[COMBAT] and w.On("gearSets") and not w.On("pvp"))
end

do
    local w = Game({ qol = { gearSets = false, blessings = false }, auraBuffs = { enabled = false },
        threatMeter = { enabled = false }, pvp = { enabled = false }, swingTimer = { enabled = false } })
    check("a profile with all six Combat modules off takes the Combat addon out of the list",
        w.ns.ReconcileModules() == 1 and not w.enabled[COMBAT] and #w.reloads == 1)
    check("and the next check is quiet", w.ns.ReconcileModules() == 0 and #w.reloads == 1)
    w.root.pvp.enabled = true
    check("a profile that turns one back on puts the Combat addon back", w.ns.ReconcileModules() == 1
        and w.enabled[COMBAT] and w.On("pvp") and not w.On("swingTimer"))
end

do
    local w = Game({ qol = { gearSets = false, blessings = false }, auraBuffs = { enabled = false },
        threatMeter = { enabled = false }, pvp = { enabled = false }, swingTimer = { enabled = false } })
    w.ns.ReconcileModules()
    w.enabled[COMBAT] = true
    check("the Combat addon ticked by hand with every module off: the modules on by default come on, not the rest",
        w.ns.ReconcileModules() == 0 and w.enabled[COMBAT] and w.On("gearSets") and w.On("blessings")
        and w.On("auraBuffs") and w.On("threatMeter") and w.On("swingTimer") and not w.On("pvp")
        and #w.reloads == 1)
    check("and it stays on at the next check", w.ns.ReconcileModules() == 0 and w.enabled[COMBAT])
end

do
    local w = Game({ qol = { groupInspect = true }, macros = { enabled = false } })
    check("a Utilities module its profile turns off: its switch only, the Utilities addon stays for the rest",
        w.ns.ReconcileModules() == 0 and w.enabled[UTILITIES] and #Writes(w) == 0 and not w.On("macros")
        and w.On("actionBars") and w.On("groupInspect"))
    for _, id in ipairs(UTILITY_IDS) do w.ns.SetModuleState(w.Item(id).addon, false) end
    local last = Writes(w)[#Writes(w)]
    check("all five off: the Utilities addon goes off for this character, Combat stays", not w.enabled[UTILITIES]
        and last.name == "DisableAddOn" and last.addon == UTILITIES and w.ForMe(last) and w.enabled[COMBAT])
    w.ns.SetModuleState(MACROS, true)
    check("one back on brings the Utilities addon back", w.enabled[UTILITIES] and w.On("macros")
        and not w.On("journeys"))
end

do
    local w = Game({ qol = { groupInspect = true }, instanceTracker = { enabled = false },
        journeys = { enabled = false }, macros = { enabled = false }, actionBars = { enabled = false } })
    w.root.qol.bis = false
    check("Utilities' last module on needs a module turned off: it goes off, and the Utilities addon with it",
        w.ns.ReconcileModules() == 2 and not w.enabled[UTILITIES] and not w.enabled[BIS]
        and w.root.qol.groupInspect == false)
end

do
    local w = Game({ training = { enabled = false } })
    w.ns.ReconcileModules(true)
    check("quiet: the list changes, no prompt", not w.enabled[TRAINING] and #w.reloads == 0)
end

do
    local w = Game({ training = { enabled = false } })
    w.combat = true
    w.ns.ReconcileModules()
    local watch
    for _, frame in ipairs(w.frames) do if frame.events.PLAYER_REGEN_ENABLED then watch = frame end end
    check("in combat the prompt waits", #w.reloads == 0 and watch ~= nil)
    w.combat = false
    watch.onEvent(watch, "PLAYER_REGEN_ENABLED")
    check("and comes once combat ends", #w.reloads == 1 and not watch.events.PLAYER_REGEN_ENABLED)
end

do
    local w = Game({ training = { enabled = false } })
    local login
    for _, frame in ipairs(w.frames) do if frame.events.PLAYER_LOGIN then login = frame end end
    check("the core checks once, at login", login ~= nil and #w.timers == 0)
    login.onEvent(login, "PLAYER_LOGIN")
    check("a moment after it", #w.timers == 1 and not login.events.PLAYER_LOGIN and w.enabled[TRAINING])
    w.timers[1]()
    check("the list matches the profile", not w.enabled[TRAINING] and #w.reloads == 1)
end

do
    local w = Game()
    w.ns.SetModuleState(TRAINING, false)
    check("turned off: this character's list and the profile", not w.enabled[TRAINING] and w.root.training.enabled == false
        and Writes(w)[#Writes(w)].who == "Player-4613-006EB819")
    w.ns.SetModuleState(TRAINING, true)
    check("and back on", w.enabled[TRAINING] and w.root.training.enabled == true)
    w.loaded[PROF] = false
    w.Session()
    w.ns.SetModuleState(PROF, false)
    w.ns.SetModuleState(PROF, true)
    check("a module whose addon is not loaded keeps its switch in the profile too", w.root.professions.enabled == true)
    w.ns.SetModuleState("NaowhForever_Discovery", true)
    check("including one that is off by default", w.root.discovery.enabled == true)
    w.ns.ReconcileModules()
    check("and the next check agrees", #w.reloads == 0)
end

do
    local w = Game()
    for _, addon in ipairs(w.ns.LinkedAddons(QOL, false)) do w.ns.SetModuleState(addon, false) end
    check("QoL off takes only its own addon out of the list: the Top Bar is part of it", not w.enabled[QOL]
        and #w.ns.LinkedAddons(QOL, false) == 1 and w.root.qol.enabled == false)
end

do
    local w = Game({ discovery = { enabled = true } })
    w.ns.ConfirmReload = function(text) w.reloads[#w.reloads + 1] = text end
    w.ns.UsePreset("minimalist", false)
    check("Minimalist from the Setups card also takes its modules out of the AddOn list", not w.enabled[DISC]
        and not w.On("groupInspect") and not w.On("macros") and not w.enabled[TRAINING] and w.enabled["NaowhForever_BiS"])
    check("with the one reload prompt", #w.reloads == 1)
end

do
    local w = Game({}, { welcomeSeen = true })
    local Setup = w.ns.Setup
    local picks = Setup.Fresh()
    Setup.Toggle(picks, "training", false)
    Setup.Apply(picks)
    check("the onboarding turning a module off writes the profile's switch", w.root.training.enabled == false
        and not w.enabled[TRAINING])
end

print(("test-module-state: %d checks passed"):format(checks))

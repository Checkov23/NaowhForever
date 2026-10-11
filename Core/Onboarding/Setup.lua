-- Setup.lua: the onboarding's picks (a profile, a skin, the modules), what they change, Apply and Restore, and a new character's profile.
local ns = _G.NaowhForever
local Setup = {}
ns.Setup = Setup

local KEEP = "keep"
local RECOMMENDED = "recommended"
local CUSTOM = "custom"
local PRESET_KEY = "preset"
local SKIN_NAOWH, SKIN_CLASSIC = "", "classic"
local BIS = "bis"
local PANELS = { { key = "characterPanel", pick = "characterPanelPicked" },
    { key = "inspectPanel", pick = "inspectPanelPicked" } }
local FIRST_COPY = 2
local COPY_NAME = "%s %d"

local character

Setup.KEEP = KEEP
Setup.SKIN_NAOWH, Setup.SKIN_CLASSIC = SKIN_NAOWH, SKIN_CLASSIC
Setup.SKINS = { SKIN_NAOWH, SKIN_CLASSIC }

Setup.ITEMS = {
    qol = { addon = "NaowhForever_QoL", db = "qol", key = "enabled",
        blurb = ns.L("Small tweaks that make the game smoother.") },
    journal = { addon = "NaowhForever_DungeonJournal", db = "journal", key = "enabled",
        blurb = ns.L("What drops in every dungeon and raid.") },
    instanceTracker = { addon = "NaowhForever_InstanceTracker", db = "instanceTracker", key = "enabled",
        blurb = ns.L("Dungeon and raid visits, and this hour.") },
    bis = { addon = "NaowhForever_BiS", db = "qol", key = "bis",
        blurb = ns.L("Your best gear, called out when it drops.") },
    training = { addon = "NaowhForever_Training", db = "training", key = "enabled",
        blurb = ns.L("What to train at each level, and its cost.") },
    discovery = { addon = "NaowhForever_Discovery", db = "discovery", key = "enabled",
        blurb = ns.L("Library books, and every quest and rare by zone.") },
    gearSets = { addon = "NaowhForever_GearSets", db = "qol", key = "gearSets",
        blurb = ns.L("Swap your gear sets from a bar.") },
    blessings = { addon = "NaowhForever_Blessings", db = "qol", key = "blessings",
        blurb = ns.L("Paladin blessings shared with your group.") },
    professions = { addon = "NaowhForever_Professions", db = "professions", key = "enabled",
        blurb = ns.L("Recipes, reagents and crafting in one window.") },
    macros = { addon = "NaowhForever_Macros", db = "macros", key = "enabled",
        blurb = ns.L("Your macros, checked and kept current.") },
    consumableBar = { addon = "NaowhForever_ConsumableBar", db = "qol", key = "consumableBar",
        blurb = "Your consumables on a bar you can click." },
    actionBars = { addon = "NaowhForever_ActionBars", db = "actionBars", key = "enabled",
        blurb = ns.L("Save your action bars and put them back.") },
    auraBuffs = { addon = "NaowhForever_AuraBuffs", db = "auraBuffs", key = "enabled",
        blurb = ns.L("Buff, food and campfire reminders.") },
    threatMeter = { addon = "NaowhForever_ThreatMeter", db = "threatMeter", key = "enabled",
        blurb = ns.L("Your group's threat on your target.") },
    groupInspect = { addon = "NaowhForever_GroupInspect", db = "qol", key = "groupInspect",
        blurb = ns.L("Your group's gear, talents and Naowh Score.") },
    pvp = { addon = "NaowhForever_PvP", db = "pvp", key = "enabled",
        blurb = ns.L("Your target's short buffs and crowd control.") },
    topBar = { addon = "NaowhForever_TopBar", db = "topBar", key = "enabled",
        blurb = ns.L("Your buttons and a clock along the top.") },
    swingTimer = { addon = "NaowhForever_SwingTimer", db = "swingTimer", key = "enabled",
        blurb = ns.L("Your swings, with marks to time around them.") },
}

local byAddon = {}
for id, item in pairs(Setup.ITEMS) do byAddon[item.addon] = id end

local function EnableState(addon, who)
    if who then return C_AddOns.GetAddOnEnableState(addon, who) end
    return C_AddOns.GetAddOnEnableState(addon)
end

local function SetAddOn(addon, on, who)
    local set = on and C_AddOns.EnableAddOn or C_AddOns.DisableAddOn
    if who then return set(addon, who) end
    set(addon)
end

local function Preset(key)
    for _, name in ipairs(ns.PRESETS.order) do
        if name == key then return ns.PRESETS[key] end
    end
end

local function Listed(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

local function SwitchIn(values, m)
    local value
    if type(values) == "table" then value = values[m.key] end
    if value == nil then value = ns.FEATURES[m.db][m.key] end
    return value == true
end

local function PresetOn(preset, m)
    if preset.modulesOff then return not Listed(preset.modulesOff, m.addon) end
    return SwitchIn(preset.profile[m.db], m)
end

local function SwitchOn(m)
    return SwitchIn(ns.SettingsRoot()[m.db], m)
end

local function Enabled(m)
    return EnableState(m.addon, character) > 0
end

local function IsOn(m)
    return Enabled(m) and SwitchOn(m)
end

local function SetSwitch(m, on)
    if m.store then return m.store.Set(m.key, on) end
    local root = ns.SettingsRoot()
    if type(root[m.db]) ~= "table" then root[m.db] = {} end
    root[m.db][m.key] = on
end

local function ByAddon(list)
    local by = {}
    for _, m in ipairs(list) do by[m.addon] = m end
    return by
end

local function Settle(modules, list)
    local by, changed = ByAddon(list), true
    while changed do
        changed = false
        for _, m in ipairs(list) do
            for _, addon in ipairs(modules[m.id] and ns.LinkedAddons(m.addon, true) or {}) do
                local need = by[addon]
                if need and not modules[need.id] then modules[m.id], changed = false, true end
            end
        end
    end
    return modules
end

function Setup.Modules()
    local list = {}
    for _, mod in ipairs(ns.ModuleAddons(character)) do
        local id = byAddon[mod.addon]
        local item = id and Setup.ITEMS[id]
        if item then
            list[#list + 1] = { id = id, name = mod.name, addon = mod.addon, navIcon = mod.navIcon, store = mod.store,
                db = item.db, key = item.key, blurb = item.blurb }
        end
    end
    return list
end

function Setup.ModuleDefaults(profile, list)
    list = list or Setup.Modules()
    local preset = Preset(profile)
    local modules = {}
    for _, m in ipairs(list) do
        if preset then modules[m.id] = PresetOn(preset, m) else modules[m.id] = IsOn(m) end
    end
    return Settle(modules, list)
end

function Setup.PresetSwitches(preset)
    if not preset.modulesOff then return end
    local root = ns.SettingsRoot()
    for _, item in pairs(Setup.ITEMS) do
        if type(root[item.db]) ~= "table" then root[item.db] = {} end
        root[item.db][item.key] = not Listed(preset.modulesOff, item.addon)
    end
end

function Setup.DefaultProfile()
    local account = ns.AccountSettings()
    if account.welcomeSeen or account.setupBefore or not Preset(RECOMMENDED) then return KEEP end
    return RECOMMENDED
end

function Setup.CurrentSkin()
    return ns.AccountSettings().skin == SKIN_CLASSIC and SKIN_CLASSIC or SKIN_NAOWH
end

function Setup.Fresh()
    local profile = Setup.DefaultProfile()
    return { profile = profile, skin = Setup.CurrentSkin(), modules = Setup.ModuleDefaults(profile) }
end

function Setup.PickProfile(picks, profile)
    if picks.profile == profile then return end
    picks.profile = profile
    picks.modules = Setup.ModuleDefaults(profile)
end

function Setup.Toggle(picks, id, on)
    local item = Setup.ITEMS[id]
    if not item or picks.modules[id] == nil then return end
    for _, addon in ipairs(ns.LinkedAddons(item.addon, on)) do
        local other = byAddon[addon]
        if other and picks.modules[other] ~= nil then picks.modules[other] = on end
    end
end

local function Loaded(m)
    return C_AddOns.IsAddOnLoaded(m.addon)
end

function Setup.Plan(picks)
    local list = Setup.Modules()
    local now = Setup.ModuleDefaults(KEEP, list)
    local preset = Preset(picks.profile)
    local plan = { profile = preset and preset.name or nil, skin = picks.skin,
        skinChanged = picks.skin ~= Setup.CurrentSkin(), on = {}, off = {} }
    plan.reload = preset ~= nil or plan.skinChanged
    for _, m in ipairs(list) do
        local want = picks.modules[m.id] == true
        if want ~= now[m.id] then
            local names = want and plan.on or plan.off
            names[#names + 1] = m.name
        end
        if (want and not Loaded(m)) or (not want and Loaded(m) and (preset and Enabled(m) or IsOn(m))) then
            plan.reload = true
        end
    end
    plan.changes = preset ~= nil or plan.skinChanged or #plan.on + #plan.off > 0
    return plan
end

local function AddonsNow(list)
    local states = {}
    for _, m in ipairs(list) do states[m.addon] = Enabled(m) end
    return states
end

function Setup.Backup(list)
    local account = ns.AccountSettings()
    account.setupBefore = { profile = ns.ActiveProfileName(), root = CopyTable(ns.SettingsRoot()),
        addons = AddonsNow(list or Setup.Modules()), character = character, skin = account.skin or SKIN_NAOWH }
end

function Setup.CanRestore()
    local saved = ns.AccountSettings().setupBefore
    return type(saved) == "table" and saved.profile == ns.ActiveProfileName()
end

function Setup.Restore()
    if not Setup.CanRestore() then return false end
    local account = ns.AccountSettings()
    local saved = account.setupBefore
    local root = ns.SettingsRoot()
    for k in pairs(root) do root[k] = nil end
    for k, v in pairs(saved.root) do root[k] = type(v) == "table" and CopyTable(v) or v end
    for addon, on in pairs(saved.addons) do
        if (EnableState(addon, saved.character) > 0) ~= on then SetAddOn(addon, on, saved.character) end
    end
    if saved.skin ~= nil then account.skin = saved.skin ~= SKIN_NAOWH and saved.skin or nil end
    account.setupBefore = nil
    return true
end

local function ApplyModule(m, want, preset)
    if want then
        if not Enabled(m) then SetAddOn(m.addon, true, character) end
        if not SwitchOn(m) then SetSwitch(m, true) end
        return not Loaded(m)
    end
    if not (preset and Enabled(m) or IsOn(m)) then return false end
    SetAddOn(m.addon, false, character)
    return Loaded(m)
end

local function PickPanels(picks)
    if not picks.modules[BIS] then return end
    for _, panel in ipairs(PANELS) do
        if ns.QoLSettings.Get(panel.key) == true then ns.QoLSettings.Set(panel.pick, true) end
    end
end

function Setup.Apply(picks)
    local list = Setup.Modules()
    local base = Setup.ModuleDefaults(picks.profile, list)
    Setup.Backup(list)
    local preset, reload, custom = Preset(picks.profile), false, false
    if preset then
        ns.ApplyPreset(picks.profile)
        reload = true
    end
    if picks.skin ~= Setup.CurrentSkin() then
        ns.AccountSettings().skin = picks.skin ~= SKIN_NAOWH and picks.skin or nil
        reload = true
    end
    for _, m in ipairs(list) do
        local want = picks.modules[m.id] == true
        if want ~= base[m.id] then custom = true end
        if ApplyModule(m, want, preset) then reload = true end
    end
    if custom then ns.QoLSettings.Set(PRESET_KEY, CUSTOM) end
    PickPanels(picks)
    return reload
end

function Setup.ForCharacter(on)
    character = on and UnitGUID("player") or nil
end

local function FreeName(name)
    local free, n = name, FIRST_COPY
    while ns.ProfileExists(free) do
        free, n = COPY_NAME:format(name, n), n + 1
    end
    return free
end

function Setup.ShareProfile(profile)
    if profile == ns.ActiveProfileName() then return false end
    return ns.SwitchProfile(profile) == true
end

function Setup.OwnProfile(name)
    local own = FreeName(name)
    if not ns.CopyProfile(ns.ActiveProfileName(), own) then return false end
    return ns.SwitchProfile(own) == true
end

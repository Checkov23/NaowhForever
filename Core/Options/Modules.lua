-- Modules.lua: the options window's modules and pages, and turning a module on or off (ns.Options).
local ns = _G.NaowhForever
local UI = ns.UI

local PROFILES_PAGE = "Profiles"
local QOL = "QoL"
local TEXT_QOL = ns.L("Quality of Life")
local TEXT_AND = ns.L(" and ")
local TEXT_ENABLE_ASK, TEXT_DISABLE_ASK = ns.L("Enable %s?"), ns.L("Disable %s?")
local TEXT_ENABLE, TEXT_DISABLE = ns.L("Enable"), ns.L("Disable")
local TEXT_ENABLE_BOTH, TEXT_DISABLE_BOTH = ns.L("Enable Both"), ns.L("Disable Both")
local TEXT_ENABLE_ALL, TEXT_DISABLE_ALL = ns.L("Enable All"), ns.L("Disable All")
local TEXT_NEEDS_THEM = ns.L(" It needs %s, so %s will be enabled.")
local TEXT_NEEDED_BY = ns.L(" %s needs it, so %s will be disabled.")
local TEXT_BOTH, TEXT_ALL_OF_THEM = ns.L("both"), ns.L("all of them")
local TEXT_CANCEL = ns.L("Cancel")
local TEXT_RELOAD_ON = ns.L("%s will be enabled when you reload. Reload now?")
local TEXT_RELOAD_OFF = ns.L("%s will be disabled when you reload. Reload now?")

local SYSTEM_PAGES = {
    { name = "Settings", build = "BuildSettingsPage", terms = "SettingsSearchTerms", reuse = true,
      subtitle = "Options for the whole addon, saved for this computer." },
    { name = "Patch Notes", reuse = true, subtitle = "What changed in recent builds." },
    { name = "Credits", build = "BuildCreditsPage", reuse = true, subtitle = "The people and projects behind Naowh Forever." },
    { name = PROFILES_PAGE, build = "BuildProfileSettings", terms = "ProfilesSearchTerms", reuse = true,
      subtitle = "Switch, copy and share everything these pages save." },
}

local MODULES = {
    { name = "QoL", navIcon = "checklist", settings = "QoLSettings", addon = "NaowhForever_QoL",
      subtitle = "Naowh's quality of life tweaks, trimmed to what Forever has.",
      tabs = {
          { name = "Interface", reuse = true },
          { name = "Map & Pins", reuse = true },
          { name = "Combat", reuse = true },
          { name = "Questing & Group", reuse = true },
          { name = "XP", reuse = true },
          { name = "Loot & Items", reuse = true },
          { name = "Glimmer", reuse = true },
          { name = "Travel", reuse = true },
          { name = "Cursor & Crosshair", reuse = true },
          { name = "Damage Meter", reuse = true },
      } },
    { name = "Dungeon Journal", group = "ADVENTURE", navIcon = "map", settings = "JournalSettings",
      addon = "NaowhForever_DungeonJournal",
      open = "ToggleJournalWindow",
      command = "journal", alias = "dj", short = "Journal", icon = "Interface\\Icons\\INV_Misc_Book_09",
      subtitle = "Every dungeon and raid: what drops, your quests, and more.",
      tabs = {
          { name = "Journal", reuse = true },
          { name = "Quest Tracker", reuse = true },
          { name = "Map", reuse = true },
      } },
    { name = "Instance Tracker", group = "UTILITIES", navIcon = "person", settings = "InstanceTrackerSettings",
      addon = "NaowhForever_InstanceTracker", host = "NaowhForever_Utilities",
      open = "ToggleInstanceTrackerWindow",
      command = "instance", short = "Instance", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
      subtitle = "Visits, and how many new instances this account has entered this hour.",
      tabs = {
          { name = "Settings", reuse = true },
      } },
    { name = "BiS List", group = "ADVENTURE", navIcon = "trophy", settings = "QoLSettings", enabledKey = "bis",
      addon = "NaowhForever_BiS",
      open = "ToggleBisWindow",
      command = "bis", short = "BiS", icon = "Interface\\Icons\\INV_Sword_39",
      subtitle = "Your best-in-slot list, marked on tooltips and called out when it drops.",
      tabs = {
          { name = "Settings", reuse = true },
          { name = "Character", reuse = true },
      } },
    { name = "Training Planner", group = "ADVENTURE", navIcon = "notes", settings = "TrainingSettings",
      addon = "NaowhForever_Training",
      open = "ToggleTrainingWindow",
      command = "training", short = "Training", icon = "Interface\\Icons\\INV_Misc_Book_11",
      subtitle = "What you can train now, what each level brings and what it costs.",
      tabs = {
          { name = "Settings", reuse = true },
      } },
    { name = "Journeys", group = "UTILITIES", navIcon = "compass", settings = "JourneysSettings",
      addon = "NaowhForever_Journeys", host = "NaowhForever_Utilities",
      subtitle = "The fastest way anywhere: walking, flights, boats, zeppelins, the tram, portals and your Hearthstone.",
      tabs = {
          { name = "Settings", reuse = true },
      } },
    { name = "Discovery", group = "ADVENTURE", navIcon = "compass", settings = "DiscoverySettings",
      addon = "NaowhForever_Discovery",
      open = "ToggleDiscoveryWindow",
      command = "discovery", short = "Discovery", icon = "Interface\\Icons\\INV_Misc_Book_07",
      subtitle = "Library books, the Cozy Sleeping Bag, and every quest and rare by zone.",
      tabs = {
          { name = "Library Books", reuse = true },
          { name = "Sleeping Bag", reuse = true },
          { name = "Quest List", reuse = true },
          { name = "Rares", reuse = true },
      } },
    { name = "Consumable Bar", group = "COMBAT", navIcon = "heart", settings = "QoLSettings",
      enabledKey = "consumableBar", addon = "NaowhForever_ConsumableBar", host = "NaowhForever_Combat",
      subtitle = "Your consumables on a bar you can click.",
      tabs = {
          { name = "Settings", reuse = true },
      } },
    { name = "Gear & Trinkets", group = "COMBAT", navIcon = "shield", settings = "QoLSettings", enabledKey = "gearSets",
      addon = "NaowhForever_GearSets", host = "NaowhForever_Combat",
      open = "ToggleGearSetsWindow",
      command = "gear", short = "Gear", icon = "Interface\\Icons\\INV_Chest_Plate04",
      subtitle = "Swap equipment sets from a bar, or on their own while you ride or rest.",
      tabs = {
          { name = "Settings", reuse = true },
      } },
    { name = "Blessings", group = "COMBAT", navIcon = "spark", settings = "QoLSettings", enabledKey = "blessings",
      addon = "NaowhForever_Blessings", host = "NaowhForever_Combat",
      open = "ToggleBlessingsWindow",
      command = "bless", short = "Bless", icon = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings",
      subtitle = "Paladin blessings by class and player, shared with the group's paladins.",
      tabs = {
          { name = "Settings", reuse = true },
      } },
    { name = "Professions", group = "ADVENTURE", navIcon = "hammer", settings = "ProfessionSettings",
      addon = "NaowhForever_Professions",
      subtitle = "Recipes, reagents and crafting in one window, with the recipes you have not learned yet.",
      tabs = {
          { name = "Settings", reuse = true },
      } },
    { name = "Macros", group = "UTILITIES", navIcon = "pen", settings = "MacroSettings",
      addon = "NaowhForever_Macros", host = "NaowhForever_Utilities",
      open = "OpenMacroWindow",
      command = "macros", short = "Macros", icon = "Interface\\Icons\\INV_Misc_Note_01",
      subtitle = "Your macros, checked and explained, and macros kept current for you.",
      tabs = {
          { name = "My Macros", build = "BuildForgePage", arg = "mine", terms = "ForgeSearchTerms", reuse = true },
          { name = "Smart Macros", build = "BuildForgePage", arg = "smart", reuse = true },
          { name = "Library", build = "BuildForgePage", arg = "lib", reuse = true },
          { name = "Settings", reuse = true },
      } },
    { name = "Group Inspect", group = "UTILITIES", navIcon = "group", settings = "QoLSettings",
      enabledKey = "groupInspect", addon = "NaowhForever_GroupInspect", host = "NaowhForever_Utilities",
      needs = { "NaowhForever_BiS" },
      open = "ToggleGroupInspect",
      command = "group", short = "Group", icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
      subtitle = "Everyone in your party or raid: their Naowh Score, gear, talents and stats.",
      tabs = {
          { name = "Settings", reuse = true },
      } },
    { name = "Action Bars", group = "UTILITIES", navIcon = "grid", settings = "ActionBarSettings",
      addon = "NaowhForever_ActionBars", host = "NaowhForever_Utilities",
      open = "OpenActionBarsWindow", menu = "ActionBarsMenu",
      command = "bars", short = "Bars", icon = "Interface\\Icons\\INV_Misc_Gear_01",
      subtitle = "Your action bars saved by name and put back whenever you want them.",
      tabs = {
          { name = "Bar Sets", build = "BuildActionBarsTab", terms = "ActionBarsSearchTerms", reuse = true },
          { name = "Settings", reuse = true },
      } },
    { name = "AuraBuffs", group = "COMBAT", navIcon = "aura", settings = "AuraBuffSettings",
      addon = "NaowhForever_AuraBuffs", host = "NaowhForever_Combat",
      command = "buffs", short = "Buffs", icon = "Interface\\Icons\\Spell_Holy_WordFortitude",
      subtitle = "Buff, consumable and campfire reminders, and a low health warning.",
      tabs = {
          { name = "Settings", reuse = true },
      } },
    { name = "Threat Meter", group = "COMBAT", navIcon = "bars", settings = "ThreatMeterSettings",
      addon = "NaowhForever_ThreatMeter", host = "NaowhForever_Combat",
      command = "threat", short = "Threat", icon = "Interface\\Icons\\Ability_Warrior_Sunder",
      subtitle = "Threat on your target for the whole group, and a warning before you pull.",
      tabs = {
          { name = "Settings", reuse = true },
      } },
    { name = "PvP", group = "COMBAT", navIcon = "swords", settings = "PvPSettings",
      addon = "NaowhForever_PvP", host = "NaowhForever_Combat",
      command = "pvp", short = "PvP", icon = "Interface\\Icons\\INV_Sword_27",
      subtitle = "What your target is doing in a fight: their short buffs and the crowd control on them.",
      tabs = {
          { name = "Auras", reuse = true },
          { name = "Battlegrounds", reuse = true },
          { name = "Flag", reuse = true },
      } },
    { name = "Swing Timer", group = "COMBAT", navIcon = "infinity", settings = "SwingTimerSettings",
      addon = "NaowhForever_SwingTimer", host = "NaowhForever_Combat",
      subtitle = "Your swings from the game's own swing timer, with marks for timing around them.",
      tabs = {
          { name = "Settings", reuse = true },
      } },
    { name = "Racial and Class Tracking", navIcon = "search", settings = "TrackingReminderSettings",
      addon = "NaowhForever_TrackingReminder", host = "NaowhForever_Utilities",
      subtitle = "Shows an icon for each racial or class tracking you have not turned on.",
      tabs = {} },
}

local Options = {}
ns.Options = Options
UI.PROFILES_PAGE = PROFILES_PAGE

local PAGES = {}

local function DisplayName(mod)
    return ns.L(mod.name == QOL and TEXT_QOL or mod.name)
end

local function Loaded(mod)
    if not mod.addon then return true end
    for _, need in ipairs(mod.needs or {}) do
        if not C_AddOns.IsAddOnLoaded(need) then return false end
    end
    return C_AddOns.IsAddOnLoaded(mod.host or mod.addon)
end

local function Has(list, value)
    for _, v in ipairs(list or {}) do
        if v == value then return true end
    end
    return false
end

local function LinkedTo(cur, other, on)
    if on then return Has(cur.needs, other.addon) end
    return Has(other.needs, cur.addon)
end

local function Linked(mod, on)
    local mods, seen = { mod }, { [mod.addon] = true }
    local i = 1
    while mods[i] do
        local cur = mods[i]
        for _, other in ipairs(MODULES) do
            if other.addon and not seen[other.addon] and LinkedTo(cur, other, on) then
                seen[other.addon] = true
                mods[#mods + 1] = other
            end
        end
        i = i + 1
    end
    return mods
end

local function NameList(mods)
    local names = {}
    for i, m in ipairs(mods) do names[i] = DisplayName(m) end
    if #names == 1 then return names[1] end
    return table.concat(names, ", ", 1, #names - 1) .. TEXT_AND .. names[#names]
end

local function SwitchQuestion(mod, mods, on)
    local text = (on and TEXT_ENABLE_ASK or TEXT_DISABLE_ASK):format(DisplayName(mod))
    if #mods == 1 then return text end
    local others = { unpack(mods, 2) }
    return text .. (on and TEXT_NEEDS_THEM or TEXT_NEEDED_BY)
        :format(NameList(others), #mods == 2 and TEXT_BOTH or TEXT_ALL_OF_THEM)
end

local function SwitchButton(mods, on)
    if #mods == 2 then return on and TEXT_ENABLE_BOTH or TEXT_DISABLE_BOTH end
    if #mods > 2 then return on and TEXT_ENABLE_ALL or TEXT_DISABLE_ALL end
    return on and TEXT_ENABLE or TEXT_DISABLE
end

local function SwitchModuleAddon(mod, on)
    local mods = Linked(mod, on)
    local text = SwitchQuestion(mod, mods, on)
    local yes = SwitchButton(mods, on)
    ns.Confirm(text, function()
        for _, m in ipairs(mods) do ns.SetModuleState(m.addon, on) end
        UI:RefreshPage(true)
        ns.ConfirmReload((on and TEXT_RELOAD_ON or TEXT_RELOAD_OFF):format(NameList(mods)))
    end, function() UI:RefreshPage(true) end, yes, TEXT_CANCEL)
end

local function EnableState(addon, who)
    if who then return C_AddOns.GetAddOnEnableState(addon, who) end
    return C_AddOns.GetAddOnEnableState(addon)
end

local function ModuleOn(mod, who)
    if mod.addon and EnableState(mod.host or mod.addon, who) == 0 then return false end
    if mod.settings then
        local store = ns[mod.settings]
        return store ~= nil and store.Get(mod.enabledKey or "enabled")
    end
    return true
end

function ns.ModuleSwitches()
    local list = {}
    for _, mod in ipairs(MODULES) do
        local store = mod.addon and mod.settings and ns[mod.settings]
        if store then
            list[#list + 1] = { name = DisplayName(mod), store = store, key = mod.enabledKey or "enabled",
                addon = mod.addon }
        end
    end
    return list
end

function ns.ModuleAddons(who)
    local list = {}
    for _, mod in ipairs(MODULES) do
        if mod.addon then
            list[#list + 1] = { name = DisplayName(mod), addon = mod.addon, store = mod.settings and ns[mod.settings],
                key = mod.enabledKey or "enabled", navIcon = mod.navIcon, on = ModuleOn(mod, who) }
        end
    end
    return list
end

function ns.LinkedAddons(addon, on)
    for _, mod in ipairs(MODULES) do
        if mod.addon == addon then
            local names = {}
            for i, m in ipairs(Linked(mod, on)) do names[i] = m.addon end
            return names
        end
    end
    return { addon }
end

function ns.ModuleHost(addon)
    for _, mod in ipairs(MODULES) do
        if mod.addon == addon then return mod.host end
    end
end

function ns.ModuleOn(addon)
    for _, mod in ipairs(MODULES) do
        if mod.addon == addon then return Loaded(mod) and ModuleOn(mod, UnitGUID("player")) == true end
    end
    return false
end

local function SetModuleOn(mod, on)
    if mod.host and C_AddOns.IsAddOnLoaded(mod.host) and (not on or Loaded(mod)) then
        for _, m in ipairs(on and Linked(mod, true) or { mod }) do ns.SetModuleState(m.addon, on) end
        return UI:RefreshPage(true)
    end
    if mod.addon and not on then return SwitchModuleAddon(mod, false) end
    local store = mod.settings and ns[mod.settings]
    if mod.settings and not store or not Loaded(mod) then return SwitchModuleAddon(mod, true) end
    if mod.addon then
        for _, m in ipairs(Linked(mod, true)) do ns.SetModuleState(m.addon, true) end
    end
    if store then store.Set(mod.enabledKey or "enabled", on) end
    UI:RefreshPage(true)
end

function ns.TurnOnModule(addon)
    for _, mod in ipairs(MODULES) do
        if mod.addon == addon then return SetModuleOn(mod, true) end
    end
end

local function MinimapButtonOn(mod)
    local account = ns.AccountSettings()
    return account.microMenu and account.microMenu.buttons[mod.name] == true
end

local function AddPages()
    for _, page in ipairs(SYSTEM_PAGES) do
        page.key, page.title = page.name, page.name
        PAGES[page.key] = page
    end
    for _, mod in ipairs(MODULES) do
        for _, tab in ipairs(mod.tabs) do
            tab.key, tab.module = mod.name .. "/" .. tab.name, mod
            PAGES[tab.key] = tab
        end
    end
end

AddPages()

Options.SYSTEM_PAGES, Options.MODULES, Options.PAGES = SYSTEM_PAGES, MODULES, PAGES
Options.DisplayName, Options.Loaded, Options.NameList = DisplayName, Loaded, NameList
Options.SetModuleOn, Options.SwitchModuleAddon = SetModuleOn, SwitchModuleAddon
function Options.ModuleOn(mod) return ModuleOn(mod, UnitGUID("player")) end
Options.MinimapButtonOn = MinimapButtonOn

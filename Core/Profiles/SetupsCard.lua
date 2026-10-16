-- SetupsCard.lua: the Profiles page's Setups card: Naowh's setups applied and compared, the onboarding and its Restore.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local P = ns.PRESETS
local Settings = ns.Shared.Settings

local CUSTOM = ns.L("Custom")
local RESTORE_ASK = ns.L("Put every setting back to how it was before the onboarding?")
local RESTORED = ns.L("Your settings are back. Reload now to finish?")
local RESTORE = ns.L("Restore")
local PARAGRAPH = "\n\n"

local function Tip()
    local lines = {}
    for _, key in ipairs(P.order) do
        if key ~= S.Get("preset") then lines[#lines + 1] = ns.PresetChanges(key) end
    end
    return table.concat(lines, PARAGRAPH)
end

local function DoRestore()
    if ns.Setup.Restore() then ns.ConfirmReload(RESTORED) end
end

local function Restore()
    ns.Confirm(RESTORE_ASK, DoRestore, nil, RESTORE)
end

local function KeepOn() return ns.AccountSettings().presetKeepPositions ~= false end
local function KeepSet(on) ns.AccountSettings().presetKeepPositions = on == true end

local function NoBackup()
    return not (ns.Setup and ns.Setup.CanRestore())
end

local NAMES = { custom = CUSTOM }
for _, key in ipairs(P.order) do NAMES[key] = P[key].name end

Settings.Page(ns.SETUPS_PAGE, S):Card({
    id = "setups", name = "Setups", order = 10,
    help = "Puts your settings to one of Naowh's setups, or walks you through them again.",
    summary = function() return NAMES[S.Get("preset") or "custom"] or CUSTOM end,
    rows = {
        { label = "Setup", choice = { NAMES, P.order }, always = true,
          get = function() return S.Get("preset") or "custom" end,
          set = function(key) if P[key] then ns.UsePreset(key) end end,
          tip = Tip,
          help = "Recommended turns on the essentials and nothing that spoils the game; Everything Enabled turns on every module." },
        { label = "Keep My Positions", toggle = true, get = KeepOn, set = KeepSet,
          help = "Applying a setup leaves your frames where you put them." },
        { label = "Onboarding", buttonText = "Start", button = function() ns.ShowSetup() end,
          help = "Walks you through a profile, a skin and your modules." },
        { label = "Before Onboarding", buttonText = "Restore", button = Restore, hidden = NoBackup,
          help = "Restores your settings to how they were before the onboarding." },
    },
})

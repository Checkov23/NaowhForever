-- Setups.lua: Naowh's setups applied to your profile and compared with it (ns.ApplyPreset, ns.UsePreset, ns.PresetChanges).
local ns = _G.NaowhForever

local S = ns.QoLSettings
local P = ns.PRESETS
local Settings = ns.Shared.Settings

local ASK = ns.L("Apply %s to every setting and position? Your lists, notes and saved picks stay. Cannot be undone.")
local DONE = ns.L("Every setting now follows %s. Reload now to finish?")
local ON, OFF, SAME = ns.L("%s turns on: %s"), ns.L("%s turns off: %s"), ns.L("%s is what you have now.")
local RIVALS = { "characterPanel", "inspectPanel" }
local KEEP = {
    qol = { "questRewards", "bagSpaceIgnore", "slashList", "equipEnchantRules" },
    auraBuffs = { "campHiddenBonuses" },
    unlockMode = { "layouts" },
}
local APPLY = ns.L("Apply")
local KEEP_ROOT = "tankReminder"
local LINE_BREAK, LIST_JOIN = "\n", ", "

local function Kept(root)
    local kept = {}
    for db, keys in pairs(KEEP) do
        local values = type(root[db]) == "table" and root[db]
        for _, k in ipairs(keys) do
            if values and values[k] ~= nil then kept[db] = kept[db] or {}; kept[db][k] = values[k] end
        end
    end
    return kept
end

local function PutBack(root, kept)
    for db, values in pairs(kept) do
        if type(root[db]) ~= "table" then root[db] = {} end
        for k, value in pairs(values) do root[db][k] = value end
    end
end

local function Replace(root, profile)
    for k in pairs(root) do
        if k ~= KEEP_ROOT then root[k] = nil end
    end
    for k, values in pairs(profile) do root[k] = CopyTable(values) end
    if type(root.qol) ~= "table" then root.qol = {} end
end

function ns.ApplyPreset(key)
    local root = ns.SettingsRoot()
    local qol = type(root.qol) == "table" and root.qol or {}
    local own, was = {}, {}
    for _, k in ipairs(ns.PROFILE_OWN.qol) do own[k] = qol[k] end
    local kept = Kept(root)
    for _, k in ipairs(RIVALS) do was[k] = S.Get(k) end
    Replace(root, P[key].profile)
    if ns.Setup then ns.Setup.PresetSwitches(P[key]) end
    for k, value in pairs(own) do root.qol[k] = value end
    PutBack(root, kept)
    root.qol.preset = key
    for _, k in ipairs(RIVALS) do
        if S.Get(k) ~= was[k] then S.Set(k, S.Get(k)) end
    end
end

function ns.UsePreset(key, ask)
    local name = P[key].name
    local function Go()
        ns.ApplyPreset(key)
        if ns.Setup then
            local want = ns.Setup.ModuleDefaults(key)
            for _, m in ipairs(ns.Setup.Modules()) do
                if want[m.id] then C_AddOns.EnableAddOn(m.addon) end
            end
        end
        ns.ConfirmReload(DONE:format(name))
    end
    if ask == false then return Go() end
    ns.Confirm(ASK:format(name), Go, nil, APPLY)
end

local function ByName(a, b) return a < b end

local function Listed(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

local function Compare(preset, on, off, seen, name, store, switch, addon)
    if seen[name] or not (store and store.key) then return end
    local values = preset.profile[store.key]
    local want = values and values[switch]
    if want == nil then want = store.Default(switch) end
    if addon and preset.modulesOff then want = not Listed(preset.modulesOff, addon) end
    local now = store.Get(switch)
    if want == true and now ~= true then
        on[#on + 1], seen[name] = name, true
    elseif want ~= true and now == true then
        off[#off + 1], seen[name] = name, true
    end
end

local function CompareAll(preset, on, off, seen)
    if ns.ModuleSwitches then
        for _, mod in ipairs(ns.ModuleSwitches()) do
            Compare(preset, on, off, seen, mod.name, mod.store, mod.key, mod.addon)
        end
    end
    for _, page in pairs(Settings.pages) do
        for _, card in pairs(page.cards) do
            if type(card.switch) == "string" then
                Compare(preset, on, off, seen, card.name, card.store, card.switch)
            end
        end
    end
end

function ns.PresetChanges(key)
    local on, off, seen = {}, {}, {}
    CompareAll(P[key], on, off, seen)
    if ns.Setup then
        local want = ns.Setup.ModuleDefaults(key)
        for _, m in ipairs(ns.Setup.Modules()) do
            if want[m.id] and not m.store and not seen[m.name] then on[#on + 1], seen[m.name] = m.name, true end
        end
    end
    table.sort(on, ByName)
    table.sort(off, ByName)
    local name, lines = P[key].name, {}
    if #on > 0 then lines[#lines + 1] = ON:format(name, ns.Color("accent", table.concat(on, LIST_JOIN))) end
    if #off > 0 then lines[#lines + 1] = OFF:format(name, ns.Color("muted", table.concat(off, LIST_JOIN))) end
    if #lines == 0 then lines[1] = SAME:format(name) end
    return table.concat(lines, LINE_BREAK)
end

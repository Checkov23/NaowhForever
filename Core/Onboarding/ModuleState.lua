-- ModuleState.lua: keeps this character's AddOn list the same as the profile's module switches (ns.ReconcileModules, ns.SetModuleState).
local ns = _G.NaowhForever
local Setup = ns.Setup

local LOGIN_DELAY = 8
local TEXT_MATCHED = ns.L("Your modules were changed to match your profile. Reload now?")

local modules, byAddon = {}, {}
for id, item in pairs(Setup.ITEMS) do
    local m = { id = id, addon = item.addon, host = ns.ModuleHost(item.addon), db = item.db, key = item.key }
    modules[#modules + 1], byAddon[item.addon] = m, m
end

local watch

local function Explicit(m)
    local values = ns.SettingsRoot()[m.db]
    if type(values) == "table" and type(values[m.key]) == "boolean" then return values[m.key] end
end

local function StoreOf(addon)
    for _, switch in ipairs(ns.ModuleSwitches()) do
        if switch.addon == addon then return switch.store, switch.key end
    end
end

local function SetListed(addon, on, me)
    if on then C_AddOns.EnableAddOn(addon, me) else C_AddOns.DisableAddOn(addon, me) end
end

local function HostWanted(host)
    for _, m in ipairs(modules) do
        if m.host == host and Setup.SwitchOn(m) then return true end
    end
    return false
end

local function Listed(m, me)
    local on = C_AddOns.GetAddOnEnableState(m.host or m.addon, me) > 0
    if m.host then return on and Setup.SwitchOn(m) end
    return on
end

local function Prompt()
    if not InCombatLockdown() then return ns.ConfirmReload(TEXT_MATCHED) end
    if not watch then
        watch = CreateFrame("Frame")
        watch:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            Prompt()
        end)
    end
    watch:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function ns.ModuleListed(addon)
    local me = UnitGUID("player")
    for _, name in ipairs(ns.LinkedAddons(addon, true)) do
        local m = byAddon[name]
        if m and not Listed(m, me) or not m and C_AddOns.GetAddOnEnableState(name, me) == 0 then return false end
    end
    return true
end

function ns.SetModuleState(addon, on)
    local m, me = byAddon[addon], UnitGUID("player")
    if not (m and m.host) then SetListed(addon, on, me) end
    if m then
        m.store = StoreOf(addon)
        Setup.SetSwitch(m, on)
        if m.host then SetListed(m.host, on or HostWanted(m.host), me) end
        return
    end
    local store, key = StoreOf(addon)
    if on and store then store.Set(key, true) end
end

function ns.ReconcileModules(quiet)
    local account = ns.AccountSettings()
    local me = UnitGUID("player")
    if not account.onboardingSeen or not me then return 0 end
    if type(account.moduleList) ~= "table" then account.moduleList = {} end
    local was = account.moduleList[me]
    local present, listed, want, woke = {}, {}, {}, {}
    for _, m in ipairs(modules) do
        if C_AddOns.DoesAddOnExist(m.host or m.addon) then
            present[#present + 1] = m
            local on = Listed(m, me)
            local profile, before = Explicit(m), was and was[m.addon]
            if m.host and was and was[m.host] == false and C_AddOns.GetAddOnEnableState(m.host, me) > 0 then
                woke[m.host] = true
            end
            listed[m.addon] = on
            if before == nil then
                want[m.id] = on and profile ~= false
            elseif on ~= before then
                want[m.id] = on
            elseif profile ~= nil then
                want[m.id] = profile
            else
                want[m.id] = on
            end
        end
    end
    for host in pairs(woke) do
        local any = false
        for _, m in ipairs(present) do
            if m.host == host then any = any or listed[m.addon] end
        end
        if not any then
            for _, m in ipairs(present) do
                if m.host == host and ns.FEATURES[m.db][m.key] then want[m.id] = true end
            end
        end
    end
    Setup.Settle(want, present)
    local changed, now, hosts = 0, {}, {}
    for _, m in ipairs(present) do
        local on, profile = want[m.id], Explicit(m)
        if m.host then
            hosts[m.host] = hosts[m.host] or on
        elseif on ~= listed[m.addon] then
            SetListed(m.addon, on, me)
            changed = changed + 1
        end
        local switchedOn = profile
        if switchedOn == nil then switchedOn = ns.FEATURES[m.db][m.key] end
        if on and profile == false or not on and switchedOn then
            m.store = StoreOf(m.addon)
            Setup.SetSwitch(m, on)
        end
        now[m.addon] = on
    end
    for host, on in pairs(hosts) do
        if on ~= (C_AddOns.GetAddOnEnableState(host, me) > 0) then
            SetListed(host, on, me)
            changed = changed + 1
        end
    end
    for host, on in pairs(hosts) do now[host] = on end
    account.moduleList[me] = now
    if changed > 0 and not quiet then Prompt() end
    return changed
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    C_Timer.After(LOGIN_DELAY, function() ns.ReconcileModules() end)
end)

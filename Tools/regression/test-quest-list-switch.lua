-- Run with Lua 5.1 from the repository root: the Quest List (Completo's code, in Discovery) has no
-- switch of its own. It follows Discovery's, an old profile with Completo on turns Discovery on,
-- and an old Completo folder still loaded is turned off.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local function Store(values)
    local s, listeners = {}, {}
    function s.Get(k) return values[k] end
    function s.Set(k, v)
        values[k] = v
        for _, fn in ipairs(listeners) do fn(k, v) end
    end
    function s.OnChange(fn) listeners[#listeners + 1] = fn end
    return s
end

local function Fixture(completoOn, discoveryOn, oldFolderLoaded)
    local completo, discovery = { enabled = completoOn }, { enabled = discoveryOn }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, FEATURES = { completo = {} }, Apply = function() end }
    ns.DiscoverySettings = Store(discovery)
    ns.UI = { ModuleSettings = function() return Store(completo) end }
    local boot, disabled, reloads = nil, {}, 0
    ns.ConfirmReload = function() reloads = reloads + 1 end
    local env = setmetatable({
        _G = { NaowhForever = ns },
        hooksecurefunc = function() end,
        CreateFrame = function()
            boot = { RegisterEvent = function() end, UnregisterAllEvents = function() end,
                SetScript = function(self, _, fn) self.run = fn end }
            return boot
        end,
        C_AddOns = { IsAddOnLoaded = function() return oldFolderLoaded end,
            DisableAddOn = function(name) disabled[#disabled + 1] = name end },
    }, { __index = _G })
    local chunk = assert(loadstring(Read("NaowhForever_Discovery/QuestList/Completo.lua")))
    setfenv(chunk, env)
    chunk()
    boot.run(boot)
    return ns, completo, discovery, disabled, function() return reloads end
end

do
    local ns, completo = Fixture(false, true)
    Check(completo.enabled == true, "Discovery on: the Quest List is on")
    ns.DiscoverySettings.Set("enabled", false)
    Check(completo.enabled == false, "Discovery switched off: the Quest List goes with it")
    ns.DiscoverySettings.Set("enabled", true)
    Check(completo.enabled == true, "and back")
end

do
    local _, completo, discovery = Fixture(true, false)
    Check(discovery.enabled == true and completo.enabled == true, "an old profile with Completo on turns Discovery on")
end

do
    local _, completo, discovery = Fixture(false, false)
    Check(completo.enabled == false and discovery.enabled == false, "both off stays off")
end

do
    local _, _, _, disabled, reloads = Fixture(false, true, true)
    Check(disabled[1] == "NaowhForever_Completo" and reloads() == 1,
        "an old Completo folder still loaded is turned off, with a reload prompt")
end

do
    local _, _, _, disabled, reloads = Fixture(false, true, false)
    Check(#disabled == 0 and reloads() == 0, "none loaded: nothing to do")
end

print(("test-quest-list-switch: %d checks passed"):format(checks))

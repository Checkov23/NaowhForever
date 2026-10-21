-- Run with Lua 5.1 from the repository root: the Professions module listens to merchants only
-- while a feature that reads them is on (Vendor Items on Shopping List, Crafts with Vendor Buys,
-- Crafting Profit, Buy at Vendor),
-- so a player with none of them on pays nothing at a merchant. Loads the real feature switches,
-- the module's settings and Vendors.lua against stubs, then turns the switches on and off.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local MERCHANT = { "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED" }
local registry, made = {}, 0
local function Noop() end

local frameMethods = {}
function frameMethods.RegisterEvent(f, event)
    registry[event] = registry[event] or {}
    registry[event][f] = true
end
function frameMethods.UnregisterEvent(f, event)
    if registry[event] then registry[event][f] = nil end
end
function frameMethods.UnregisterAllEvents(f)
    for _, set in pairs(registry) do set[f] = nil end
end
function frameMethods.SetScript(f, name, fn) f.scripts[name] = fn end
local frameMeta = { __index = function(_, k) return frameMethods[k] or Noop end }

local function Listening()
    local n = 0
    for _, event in ipairs(MERCHANT) do
        for _ in pairs(registry[event] or {}) do n = n + 1 end
    end
    return n
end

local function Fire(event)
    for f in pairs(registry[event] or {}) do f.scripts.OnEvent(f, event) end
end

local settings, applyHooks = {}, {}
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    UI = {
        ModuleSettings = function(_, defaults)
            local S, listeners = {}, {}
            function S.Get(k)
                if settings[k] == nil then return defaults[k] end
                return settings[k]
            end
            function S.Set(k, v)
                settings[k] = v
                for i = 1, #listeners do listeners[i](k, v) end
            end
            function S.OnChange(fn) listeners[#listeners + 1] = fn end
            function S.Raw(key) return settings[key] end
            function S.DB() return settings end
            return S
        end,
    },
    ProfWindowAPI = {},
    AccountSettings = function() return settings.account end,
}
settings.account = {}

local scanned = 0
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function()
        made = made + 1
        return setmetatable({ scripts = {} }, frameMeta)
    end,
    hooksecurefunc = function(t, name, fn)
        if t == ns and name == "Apply" then applyHooks[#applyHooks + 1] = fn end
    end,
    GetMerchantNumItems = function() scanned = scanned + 1; return 0 end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end end,
}, { __index = _G })
env._G = env

Load({ "Core/Features.lua", "NaowhForever_Professions/Professions.lua", "NaowhForever_Professions/Vendors.lua" }, env)
local S = ns.ProfessionSettings
local hidden, redraws, viewEvents = 0, 0, 0
ns.Professions.ShoppingVendorView = {
    Hide = function() hidden = hidden + 1 end,
    OnMerchantEvent = function() viewEvents = viewEvents + 1 end,
}
ns.Professions.Shopping = { Redraw = function() redraws = redraws + 1 end }

check("on its defaults, nothing listens to merchants", Listening() == 0 and made == 0)

S.Set("vendorMaterials", true)
check("Crafts with Vendor Buys listens to merchants", Listening() == #MERCHANT)
Fire("MERCHANT_SHOW")
check("and reads the merchant when one opens", scanned == 1)

S.Set("vendorMaterials", false)
check("turned off again, it stops listening", Listening() == 0)

S.Set("craftProfit", true)
check("Crafting Profit listens to merchants", Listening() == #MERCHANT)
S.Set("craftProfit", false)
S.Set("buyVendor", true)
check("Buy at Vendor listens to merchants", Listening() == #MERCHANT and made == 1)

S.Set("enabled", false)
check("with the module off, nothing listens even with Buy at Vendor on", Listening() == 0)

settings.enabled = true
for _, fn in ipairs(applyHooks) do fn() end
check("a profile that turns the module back on listens again", Listening() == #MERCHANT and made == 1)

settings.buyVendor = false
for _, fn in ipairs(applyHooks) do fn() end
check("a profile with none of them on stops listening", Listening() == 0)

S.Set("shoppingList", true)
check("Shopping List alone does not listen to merchants", Listening() == 0)
S.Set("shoppingVendor", true)
check("Vendor Items on Shopping List listens for vendor prices and matching materials",
    Listening() == #MERCHANT)
local before, redrawn, shown = scanned, redraws, viewEvents
Fire("MERCHANT_SHOW")
check("it scans a merchant when it opens, redraws the list and tells the merchant window",
    scanned == before + 1 and redraws == redrawn + 1 and viewEvents == shown + 1)
hidden = 0
S.Set("shoppingVendor", false)
check("turning it off stops its listener and hides the merchant window", Listening() == 0 and hidden == 1)
S.Set("buyVendor", true)
redrawn, shown = redraws, viewEvents
Fire("MERCHANT_SHOW")
check("with it off, a merchant never redraws the Shopping List or wakes its window",
    redraws == redrawn and viewEvents == shown)

print(("test-profession-merchant-events: %d checks passed"):format(checks))

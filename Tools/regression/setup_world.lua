-- A stub game for the onboarding tests: the real Features.lua, Options/Modules.lua, Presets.lua,
-- Setups.lua and Onboarding/Setup.lua, on stub settings stores, one profile, account settings and a
-- C_AddOns that remembers every call. A module's settings store exists only while its addon is
-- loaded, as in the game (the QoL store is the core's, so always). Not a test itself (run-all.sh
-- runs only test*.lua). Run from the repo root:
--
--   local World = dofile("Tools/regression/setup_world.lua")
--   local w = World({ enabled = { NaowhForever_PvP = true }, loaded = { ... }, root = { ... } })
--   w.ns.Setup.Apply(w.ns.Setup.Fresh())
--
-- opts: enabled (this character's addons), others (every other character's; defaults to enabled),
-- loaded, root (the profile), account, character (true: the onboarding is for this character),
-- ns (a table to build on, for the window test).
local GUID = "Player-4613-006EB819"

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n")
    f:close()
    return s
end

local function CopyTable(t)
    local out = {}
    for k, v in pairs(t) do out[k] = type(v) == "table" and CopyTable(v) or v end
    return out
end

local function Load(path, env)
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk()
end

local OWNED = {}
local function Own(addon, path)
    local dir = path:match("^(.*/)") or ""
    if path:match("%.xml$") then
        for kind, file in Read(path):gmatch("<(%a+)%s+file=\"([^\"]+)\"") do
            if kind == "Script" or kind == "Include" then Own(addon, dir .. file:gsub("\\", "/")) end
        end
    elseif path:match("%.lua$") then
        for name in Read(path):gmatch("\nns%.(%w+Settings)%s*=") do OWNED[name] = addon end
    end
end

local MODULES = assert(loadstring(Read("Core/Options/Modules.lua"):match("\n(local MODULES = {.-\n}\n)")
    .. "\nreturn MODULES"))()
for _, mod in ipairs(MODULES) do
    for line in Read(mod.addon .. "/" .. mod.addon .. ".toc"):gmatch("[^\n]+") do
        local file = line:match("^%s*(.-)%s*$")
        if not file:match("^#") and file:match("%.%a+$") then Own(mod.addon, mod.addon .. "/" .. file:gsub("\\", "/")) end
    end
end

local function Store(w, ns, db)
    local s = { key = db, sets = 0 }
    local function Values()
        if type(w.root[db]) ~= "table" then w.root[db] = {} end
        return w.root[db]
    end
    function s.Default(k) return rawget(ns.FEATURES[db] or {}, k) end
    function s.Get(k)
        local v = Values()[k]
        if v == nil then v = s.Default(k) end
        return v
    end
    function s.Set(k, v)
        Values()[k] = v
        s.sets = s.sets + 1
        w.changed[#w.changed + 1] = db .. "." .. k .. "=" .. tostring(v)
    end
    return s
end

return function(opts)
    opts = opts or {}
    local w = { root = opts.root or {}, account = opts.account or {}, enabled = {}, others = {}, loaded = {},
        calls = {}, changed = {}, profile = "Default", character = opts.character == true, GUID = GUID,
        MODULES = MODULES, OWNED = OWNED }
    for _, mod in ipairs(MODULES) do
        local addon = mod.addon
        w.enabled[addon] = (opts.enabled or {})[addon] == true
        local other = (opts.others or opts.enabled or {})[addon]
        w.others[addon] = other == true
        w.loaded[addon] = (opts.loaded or {})[addon] == true
    end
    local ns = opts.ns or {}
    ns.UI = ns.UI or {}
    local locale = dofile("Tools/regression/locale_stub.lua")
    ns.L, ns.Upper, ns.Lower = ns.L or locale.L, ns.Upper or locale.Upper, ns.Lower or locale.Lower
    ns.Color = ns.Color or function(_, text) return text end
    ns.Shared = ns.Shared or {}
    ns.Shared.Settings = ns.Shared.Settings or { pages = {} }
    ns.PROFILE_OWN = { qol = { "characterPanelAsked", "characterPanelTookOver", "inspectPanelAsked",
        "inspectPanelTookOver" } }
    ns.SettingsRoot = function() return w.root end
    ns.AccountSettings = function() return w.account end
    ns.ActiveProfileName = function() return w.profile end
    w.ns = ns
    local function Note(name, addon, ...)
        w.calls[#w.calls + 1] = { name = name, addon = addon, args = select("#", ...), who = (...) }
    end
    local function Switch(on)
        return function(addon, ...)
            Note(on and "EnableAddOn" or "DisableAddOn", addon, ...)
            w.enabled[addon] = on
            if select("#", ...) == 0 then w.others[addon] = on end
        end
    end
    local C_AddOns = {
        EnableAddOn = Switch(true),
        DisableAddOn = Switch(false),
        GetAddOnEnableState = function(addon, ...)
            Note("GetAddOnEnableState", addon, ...)
            if select("#", ...) > 0 then return w.enabled[addon] and 2 or 0 end
            if w.enabled[addon] and w.others[addon] then return 2 end
            return (w.enabled[addon] or w.others[addon]) and 1 or 0
        end,
        IsAddOnLoaded = function(addon) return w.loaded[addon] == true end,
    }
    local env = setmetatable({ C_AddOns = C_AddOns, CopyTable = CopyTable, unpack = unpack,
        UnitGUID = function(unit) return unit == "player" and GUID or nil end }, { __index = _G })
    env._G = { NaowhForever = ns }
    w.env = env
    Load("Core/Features.lua", env)
    Load("Core/Profiles/Presets.lua", env)
    ns.QoLSettings = Store(w, ns, "qol")
    Load("Core/Options/Modules.lua", env)
    Load("Core/Profiles/Setups.lua", env)
    Load("Core/Onboarding/Setup.lua", env)
    local dbOf = {}
    for _, item in pairs(ns.Setup.ITEMS) do
        for _, mod in ipairs(MODULES) do
            if mod.addon == item.addon then dbOf[mod.settings] = item.db end
        end
    end
    w.stores = {}
    for name, db in pairs(dbOf) do
        if name ~= "QoLSettings" then w.stores[name] = Store(w, ns, db) end
    end
    function w.Session()
        for name, store in pairs(w.stores) do
            ns[name] = (not OWNED[name] or w.loaded[OWNED[name]]) and store or nil
        end
    end
    w.Session()
    function w.Item(id) return ns.Setup.ITEMS[id] end
    function w.Switch(id)
        local item = ns.Setup.ITEMS[id]
        local values = w.root[item.db]
        local v
        if type(values) == "table" then v = values[item.key] end
        if v == nil then v = ns.FEATURES[item.db][item.key] end
        return v == true
    end
    function w.On(id)
        return w.enabled[ns.Setup.ITEMS[id].addon] and w.Switch(id)
    end
    function w.Reload()
        for _, mod in ipairs(MODULES) do
            local ok = w.enabled[mod.addon]
            for _, need in ipairs(mod.needs or {}) do ok = ok and w.enabled[need] end
            w.loaded[mod.addon] = ok == true
        end
        w.Session()
    end
    function w.ForEveryone(call) return call.args == 0 end
    function w.ForMe(call) return call.args == 1 and call.who == GUID end
    ns.Setup.ForCharacter(w.character)
    return w
end

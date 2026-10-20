-- Importing a profile through the installer's entry point has to be able to move every character
-- on the account, not just the one that ran the import. Covers the Core half (SetAccountProfile
-- plus the fallback a character with no assignment takes) and NaowhForever_API:ImportProfile
-- (Core/Profiles/ProfileShare.lua), including an old Reminder Pack string, which it refuses.
local core = assert(io.open(arg[1] or "Core/Core.lua", "rb"))
local coreSrc = core:read("*a"):gsub("\r\n", "\n"); core:close()
local SHARE = arg[2] or "Core/Profiles/ProfileShare.lua"

local function Slice(source, a, b)
    local first = assert(source:find(a, 1, true))
    return source:sub(first, assert(source:find(b, first + #a, true)) - 1)
end

local function Fixture(char)
    local e = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, char = char or "Main-Ravencrest", reapplied = 0 }
    local env = { ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QueueReapply = function() e.reapplied = e.reapplied + 1 end,
            STARTER = { profile = {}, account = {} } },
        activeRoot = nil,
        CharKey = function() return e.char end,
        UnitName = function() return e.char:match("^[^-]+") end, UNKNOWNOBJECT = "Unknown" }
    function env.CopyTable(t)
        local out = {}
        for k, v in pairs(t) do out[k] = type(v) == "table" and env.CopyTable(v) or v end
        return out
    end
    setmetatable(env, { __index = _G })
    local code = assert(coreSrc:match("\n(local MODULE_KEY = .-\n)\nlocal ns = {}\n"), "Core constants")
        .. Slice(coreSrc, "local function NewInstall()", "function ns.SettingsRoot()")
        .. Slice(coreSrc, "function ns.SettingsRoot()", "function ns.AccountSettings()")
        .. Slice(coreSrc, "function ns.ActiveProfileName()", "function ns.ListProfiles()")
        .. Slice(coreSrc, "function ns.SpecProfileMap()", "function ns.AutoSpecProfile(")
        .. Slice(coreSrc, "function ns.AutoSpecProfile(", "function ns.ApplySpecProfile(")
        .. Slice(coreSrc, "function ns.ApplySpecProfile(", "local function ValidName(")
        .. Slice(coreSrc, "function ns.SwitchProfile(", "local function ValidName(")
        .. Slice(coreSrc, "function ns.SetAccountProfile(", "function ns.CreateProfile(")
    local chunk = assert(loadstring(code)); setfenv(chunk, env); chunk()
    -- activeRoot is a file local in the real chunk; the slice reads it as a global here, so
    -- the cache it keeps behaves the same way without dragging the whole file in.
    e.env, e.ns = env, env.ns
    e.db = function() return _G.NaowhForeverDB end
    _G.NaowhForeverDB = nil
    return e
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("a player still named Unknown is not filed or cached", function()
    local e = Fixture("Unknown-Ravencrest")
    e.ns.SettingsRoot()
    local sv = e.db()
    assert(next(sv.charActive) == nil and e.env.activeRoot == nil)
end)

Case("a player still named Unknown reads the account default's name", function()
    local e = Fixture("Unknown-Ravencrest")
    e.ns.SettingsRoot()
    e.db().defaultProfile = "Naowh"
    assert(e.ns.ActiveProfileName() == "Naowh")
end)

Case("every known character moves, and the account default moves with them", function()
    local e = Fixture("Main-Ravencrest")
    e.ns.SettingsRoot()
    local sv = e.db()
    sv.profiles.Naowh, sv.profiles.Old = {}, {}
    sv.charActive["Alt1-Ravencrest"] = "Old"
    sv.charActive["Alt2-Draenor"] = "Old"
    assert(e.ns.SetAccountProfile("Naowh") == true)
    assert(sv.defaultProfile == "Naowh")
    for _, on in pairs(sv.charActive) do assert(on == "Naowh") end
    assert(e.reapplied > 0)
end)

Case("a character never logged in lands on it through the account default", function()
    local e = Fixture("Main-Ravencrest")
    e.ns.SettingsRoot()
    local sv = e.db()
    sv.profiles.Naowh = {}
    e.ns.SetAccountProfile("Naowh")
    -- A fresh alt has no charActive entry at all; SettingsRoot assigns one on first read.
    e.char = "NeverSeen-Ravencrest"
    e.env.activeRoot = nil
    e.ns.SettingsRoot()
    assert(sv.charActive["NeverSeen-Ravencrest"] == "Naowh")
end)

Case("a profile the import did not land is refused rather than invented", function()
    local e = Fixture()
    e.ns.SettingsRoot()
    local sv = e.db()
    sv.charActive["Alt1-Ravencrest"] = "Old"
    local ok, why = e.ns.SetAccountProfile("Missing")
    assert(ok == false and type(why) == "string")
    assert(sv.charActive["Alt1-Ravencrest"] == "Old" and sv.defaultProfile == nil)
end)

Case("switching one character afterwards leaves the rest on the account profile", function()
    local e = Fixture("Main-Ravencrest")
    e.ns.SettingsRoot()
    local sv = e.db()
    sv.profiles.Naowh, sv.profiles.Mine = {}, {}
    sv.charActive["Alt1-Ravencrest"] = "Mine"
    e.ns.SetAccountProfile("Naowh")
    sv.charActive["Alt1-Ravencrest"] = "Mine"
    assert(sv.charActive["Main-Ravencrest"] == "Naowh" and sv.defaultProfile == "Naowh")
end)

-- The bug this feature shipped with: the account choice was written correctly and then
-- undone on the alt's next login, because auto spec switching still pointed every spec at
-- the profile it replaced.
Case("auto spec switching cannot undo the account profile on the next login", function()
    local e = Fixture("Main-Ravencrest")
    e.ns.SettingsRoot()
    local sv = e.db()
    sv.profiles.Naowh, sv.profiles["Naowh New"] = {}, {}
    sv.autoSpecProfile = true
    sv.specProfile = { ["250"] = "Naowh", ["104"] = "Naowh", ["259"] = "Naowh Profile" }
    sv.charActive["Alt-Area 52"] = "Naowh"
    local ok, turnedOff = e.ns.SetAccountProfile("Naowh New")
    assert(ok == true and turnedOff == true)
    -- The alt logs in: PLAYER_LOGIN runs ApplySpecProfile for whatever spec it is on.
    e.char = "Alt-Area 52"
    e.env.activeRoot = nil
    e.ns.CurrentSpec = function() return 104 end
    assert(e.ns.ApplySpecProfile(104) == false)
    assert(sv.charActive["Alt-Area 52"] == "Naowh New")
    assert(e.ns.ActiveProfileName() == "Naowh New")
end)

Case("the spec map survives untouched and comes back if switching is re-enabled", function()
    local e = Fixture("Main-Ravencrest")
    e.ns.SettingsRoot()
    local sv = e.db()
    sv.profiles.Naowh, sv.profiles["Naowh New"] = {}, {}
    sv.autoSpecProfile = true
    sv.specProfile = { ["250"] = "Naowh", ["259"] = "Naowh Profile" }
    e.ns.SetAccountProfile("Naowh New")
    -- Hand-built per-spec choices are the user's work, not ours to overwrite.
    assert(sv.specProfile["250"] == "Naowh" and sv.specProfile["259"] == "Naowh Profile")
    e.ns.AutoSpecProfile(true)
    e.ns.CurrentSpec = function() return 250 end
    assert(e.ns.ApplySpecProfile(250) == true)
    assert(sv.charActive["Main-Ravencrest"] == "Naowh")
end)

Case("a deliberate switch afterwards still moves that one character and its spec", function()
    local e = Fixture("Main-Ravencrest")
    e.ns.SettingsRoot()
    local sv = e.db()
    sv.profiles.Naowh, sv.profiles["Naowh New"] = {}, {}
    sv.specProfile = {}
    e.ns.SetAccountProfile("Naowh New")
    e.ns.CurrentSpec = function() return 250 end
    e.ns.SwitchProfile("Naowh")
    assert(sv.charActive["Main-Ravencrest"] == "Naowh")
    assert(sv.specProfile["250"] == "Naowh", "the map learns from a deliberate switch")
    assert(sv.defaultProfile == "Naowh New", "the account default is not dragged along")
end)

Case("a profile switch checks the modules against this character's AddOn list", function()
    local e = Fixture("Main-Ravencrest")
    e.ns.SettingsRoot()
    local sv = e.db()
    sv.profiles.Naowh, sv.profiles["Naowh New"] = {}, {}
    local checked = 0
    e.ns.ReconcileModules = function() checked = checked + 1 end
    e.ns.SwitchProfile("Naowh")
    e.ns.SetAccountProfile("Naowh New")
    assert(checked == 2)
end)

Case("switching already off is reported as such rather than as a change", function()
    local e = Fixture("Main-Ravencrest")
    e.ns.SettingsRoot()
    local sv = e.db()
    sv.profiles["Naowh New"] = {}
    sv.specProfile = { ["250"] = "Old" }
    local ok, turnedOff = e.ns.SetAccountProfile("Naowh New")
    assert(ok == true and turnedOff == false)
    assert(sv.autoSpecProfile == nil and sv.specProfile["250"] == "Old")
end)

Case("a new install starts from the starter setup in Default", function()
    local e = Fixture("Main-Ravencrest")
    local starter = { profile = { qol = { fastLoot = true } }, account = { windowScale = 1.1 } }
    e.ns.STARTER = starter
    assert(e.ns.SettingsRoot().qol.fastLoot == true)
    local sv = e.db()
    assert(sv.account.windowScale == 1.1)
    assert(sv.profiles.Default ~= starter.profile and sv.account ~= starter.account)
    e.ns.SettingsRoot().qol.fastLoot = false
    assert(starter.profile.qol.fastLoot == true)
    assert(sv.charActive["Main-Ravencrest"] == "Default")
end)

Case("an account that already has settings never takes the starter", function()
    local e = Fixture("Main-Ravencrest")
    e.ns.STARTER = { profile = { qol = { fastLoot = true } }, account = { windowScale = 1.1 } }
    _G.NaowhForeverDB = { dbVersion = 1, profiles = { Default = { qol = { fastLoot = false } } } }
    assert(e.ns.SettingsRoot().qol.fastLoot == false and e.db().account == nil)
end)

Case("the shipped presets carry no reminders, and a new install starts from Minimalist", function()
    local env = { NaowhForever = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,} }; env._G = env
    local chunk = assert(loadfile("Core/Profiles/Presets.lua")); setfenv(chunk, env); chunk()
    local presets = env.NaowhForever.PRESETS
    assert(presets.newInstall == "minimalist" and env.NaowhForever.STARTER == presets.minimalist)
    assert(#presets.order >= 1 and presets.order[1] == "minimalist")
    for _, key in ipairs(presets.order) do
        local preset = presets[key]
        assert(type(preset.name) == "string" and type(preset.about) == "string", key)
        assert(type(preset.profile) == "table" and type(preset.account) == "table", key)
        assert(preset.profile.tankReminder == nil and preset.profile.customReminders == nil, key)
        local q = preset.profile.qol or {}
        assert(q.characterPanelAsked == nil and q.characterPanelTookOver == nil
            and q.inspectPanelAsked == nil and q.inspectPanelTookOver == nil,
            key .. ": a player answers EllesmereUI's questions itself, as on a first run")
    end
end)

-- The installer's public entry point, the real ProfileShare.lua on the real Core slice.
-- ImportProfile is stubbed to do what the real one does to profile state: land the profile and
-- switch to it, which maps the current spec. A profile string skips the real decoder, which has
-- its own tests; anything else goes through it.
local function WithApi(e, importProfile)
    e.env._G = e.env
    e.env.NaowhForever = e.ns
    e.printed = {}
    e.ns.Print = function(msg) e.printed[#e.printed + 1] = msg end
    local chunk = assert(loadfile(SHARE)); setfenv(chunk, e.env); chunk()
    local decode = e.ns.DecodeProfile
    e.ns.DecodeProfile = function(str)
        if str:sub(1, 11) == "NFPROFILE1:" then return { parts = {} } end
        return decode(str)
    end
    e.ns.ImportProfile = importProfile or function() error("nothing may be imported") end
    return e.env.NaowhForever_API
end

local function Lands(e, sv)
    return function(_, wanted, name, overwrite)
        e.args = { wanted = wanted, name = name, overwrite = overwrite }
        sv.profiles[name] = {}
        e.ns.SwitchProfile(name)
        return name, {}
    end
end

Case("ImportProfile lands the named profile on every character and keeps the spec choice", function()
    local e = Fixture("Main-Ravencrest")
    e.ns.SettingsRoot()
    local sv = e.db()
    sv.profiles.Mine = {}
    sv.specProfile = { ["250"] = "Mine" }
    sv.charActive["Alt-Draenor"] = "Mine"
    e.ns.CurrentSpec = function() return 250 end
    local API = WithApi(e, Lands(e, sv))
    local ok, landed = API:ImportProfile("NFPROFILE1:x", "Naowh")
    assert(ok == true and landed == "Naowh" and e.args.name == "Naowh" and e.args.overwrite == true)
    assert(sv.defaultProfile == "Naowh" and sv.charActive["Alt-Draenor"] == "Naowh")
    assert(sv.specProfile["250"] == "Mine", "the spec map is put back the way the player had it")
end)

Case("a Profiles page string replaces the named profile with every part but the acting settings", function()
    local e = Fixture("Main-Ravencrest")
    e.ns.SettingsRoot()
    local sv = e.db()
    local API = WithApi(e, Lands(e, sv))
    assert(API:ImportProfile("NFPROFILE1:x", "Naowh") == true)
    local wanted = e.args.wanted
    for _, part in ipairs({ "settings", "macros", "library", "builds", "bisLists", "questRewards", "look" }) do
        assert(wanted[part] == true, part)
    end
    assert(not wanted.acting and not wanted.reminders and not wanted.consumables)
end)

Case("an old Reminder Pack string is refused, says why, and leaves the account alone", function()
    local e = Fixture("Main-Ravencrest")
    e.ns.SettingsRoot()
    local sv = e.db()
    sv.charActive["Alt-Draenor"] = "Mine"
    local API = WithApi(e)
    local ok, why = API:ImportProfile("  NSRPACK2:abcdef\n", "Naowh")
    assert(ok == false and why == "Reminder Packs are no longer supported.", tostring(why))
    assert(e.printed[1] == "Naowh Forever import failed: Reminder Packs are no longer supported.", e.printed[1])
    assert(sv.defaultProfile == nil and sv.charActive["Alt-Draenor"] == "Mine" and sv.profiles.Naowh == nil)
end)

Case("a string that is neither says why and imports nothing", function()
    local e = Fixture("Main-Ravencrest")
    e.ns.SettingsRoot()
    local sv = e.db()
    local API = WithApi(e)
    local ok, why = API:ImportProfile("garbage", "Naowh")
    assert(ok == false and why == "This is not a Naowh Forever profile string.")
    assert(e.printed[1] and e.printed[1]:find("not a Naowh Forever", 1, true))
    ok, why = API:ImportProfile("", "Naowh")
    assert(ok == false and why == "Nothing to read." and #e.printed == 2)
    assert(sv.defaultProfile == nil)
end)

print(count .. " account profile import regressions passed")

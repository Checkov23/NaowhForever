-- Run with Lua 5.1 from the repository root: the class macros a profile string carries, and the
-- old consumables part it no longer takes, through the real LibSerialize and LibDeflate. They come
-- from another player, so each shape is checked whole before it lands, and only the fields the
-- addon reads are kept.
strmatch = string.match
dofile("Libs/LibStub/LibStub.lua")
dofile("Libs/LibDeflate/LibDeflate.lua")
dofile("Libs/LibSerialize/LibSerialize.lua")
local LS, LD = LibStub("LibSerialize"), LibStub("LibDeflate")

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

local function World()
    local w = { profiles = { Default = { tankReminder = {} } }, account = {} }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, UI = {}, CODE_BUILD = "test", Macros = { C = { LIMIT = 255 } },
        SettingsRoot = function() return w.profiles.Default end,
        AccountSettings = function() return w.account end,
        ModuleDefaults = function() return nil end,
        ActiveProfileName = function() return "Default" end,
        ProfileExists = function(name) return w.profiles[name] ~= nil end,
        ProfileRoot = function(name)
            w.profiles[name] = w.profiles[name] or { tankReminder = {} }
            return w.profiles[name]
        end,
        SwitchProfile = function(name) w.switched = name end,
    }
    local env = setmetatable({ _G = { NaowhForever = ns }, UnitName = function() return "Robin" end,
        date = os.date }, { __index = _G })
    ns.Shared = { Decode = dofile("Tools/regression/load_decode.lua")(env) }
    local chunk = assert(loadfile("Core/Profiles/ProfileShare.lua"))
    setfenv(chunk, env)
    chunk()
    w.ns = ns
    return w
end

local function Profile(parts)
    return "NFPROFILE1:" .. LD:EncodeForPrint(LD:CompressDeflate(LS:Serialize({ format = 1, name = "Theirs",
        parts = parts })))
end

local function Consumables(list) return assert(World().ns.DecodeProfile(Profile({ consumables = list }))).parts end
local function ClassMacros(macros)
    return assert(World().ns.DecodeProfile(Profile({ macros = { classMacros = macros } }))).parts.macros
end

Case("class macro definitions survive decode and import", function()
    local w = World()
    w.profiles.Default.tankReminder.utilityReminders = {
        consumables = { { category = "food", itemID = 123, auras = { 456, 789 } } },
        classMacros = { PALADIN = { { name = "Example", body = "/say example", icon = 134400, note = "Says hi" } } },
    }
    local payload = assert(w.ns.DecodeProfile(assert(w.ns.ExportProfile())))
    assert(payload.parts.consumables == nil, "Consumables are no longer exported")
    w.ns.ImportProfile(payload, { macros = true }, "Other")
    local imported = w.profiles.Other.tankReminder.utilityReminders
    assert(imported.classMacros.PALADIN[1].body == "/say example")
    assert(imported.classMacros.PALADIN[1].note == "Says hi" and imported.classMacros.PALADIN[1].icon == 134400)
    imported.classMacros.PALADIN[1].body = "/say changed"
    assert(payload.parts.macros.classMacros.PALADIN[1].body == "/say example", "a copy, not the same table")
end)

Case("a string carrying a consumables part decodes without it", function()
    local good = { category = "flask", itemID = 13510, auras = { 17628 } }
    for _, list in ipairs({ { good }, { good, { category = "food", itemID = -1 } }, "food=13510" }) do
        assert(Consumables(list).consumables == nil)
    end
    local parts = assert(World().ns.DecodeProfile(Profile({ consumables = { good },
        macros = { classMacros = { PALADIN = { { name = "Fine", body = "/say x" } } } } }))).parts
    assert(parts.consumables == nil and parts.macros.classMacros.PALADIN[1].name == "Fine",
        "the rest of the string still decodes")
end)

Case("importing with Consumables ticked writes no consumables", function()
    local w = World()
    local payload = assert(w.ns.DecodeProfile(Profile({ consumables = { { category = "food", itemID = 1 } } })))
    payload.parts.consumables = { { category = "food", itemID = 1 } }
    w.ns.ImportProfile(payload, { consumables = true }, "Mine")
    assert(w.profiles.Mine.tankReminder.utilityReminders == nil, "nothing lands in utilityReminders.consumables")
end)

Case("an invalid class macro leaves every class macro out", function()
    local fine = { name = "Fine", body = "/say x" }
    for _, macros in ipairs({
        { PALADIN = { { name = "Bad", body = string.rep("x", 256) } } },
        { PALADIN = { { name = "Bad", body = "" } } },
        { PALADIN = { { name = "", body = "/say x" } } },
        { PALADIN = { { name = string.rep("n", 17), body = "/say x" } } },
        { PALADIN = { { name = "Bad", body = "/say x", note = 5 } } },
        { PALADIN = { { name = "Bad", body = "/say x", note = string.rep("n", 201) } } },
        { PALADIN = { { name = "Bad", body = "/say x", icon = "134400" } } },
        { PALADIN = { { name = "Bad", body = "/say x", icon = 1.5 } } },
        { PALADIN = { { name = 5, body = "/say x" } } },
        { PALADIN = { [1] = fine, [3] = fine } },
        { PALADIN = { fine, x = fine } },
        { PALADIN = "fine" },
        { paladin = { fine } },
        { ["PALADIN|r"] = { fine } },
        { [1] = { fine } },
    }) do
        macros.MAGE = { fine }
        assert(ClassMacros(macros).classMacros == nil)
    end
    local many = {}
    for i = 1, 100 do many[i] = { name = "M" .. i, body = "/say x" } end
    assert(#ClassMacros({ PALADIN = many }).classMacros.PALADIN == 100, "100 a class is the limit")
    many[101] = fine
    assert(ClassMacros({ PALADIN = many }).classMacros == nil, "101 is past it")
end)

Case("a class macro keeps only its name, body, icon and note", function()
    local macro = ClassMacros({ PALADIN = { { name = "Fine", body = "/say x", icon = 7, note = "",
        pack = true, run = "x" } } }).classMacros.PALADIN[1]
    assert(macro.name == "Fine" and macro.body == "/say x" and macro.icon == 7 and macro.note == "")
    assert(macro.pack == nil and macro.run == nil)
end)

Case("a payload changed after decoding is checked again on import", function()
    local w = World()
    local payload = assert(w.ns.DecodeProfile(Profile({
        macros = { classMacros = { PALADIN = { { name = "Fine", body = "/say x" } } } } })))
    payload.parts.macros.classMacros.PALADIN[1].body = ""
    w.ns.ImportProfile(payload, { consumables = true, macros = true }, "Mine")
    assert(w.profiles.Mine.tankReminder.utilityReminders == nil)
end)

print(count .. " utility profile regressions passed")

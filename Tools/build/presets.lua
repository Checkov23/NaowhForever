-- Writes Core/Profiles/Presets.lua, the setups a player can start from or apply on QoL >
-- the Profiles page's Setups card (ns.PRESETS; a new install starts from the one NEW_INSTALL names). Builds
-- one preset at a time, out of a profile string from Export Profile (NFPROFILE1:) saved to a
-- file, or a .lua file returning a profile table (one profiles entry of NaowhForever.lua, the
-- SavedVariables) with its author's name after it; the other presets are kept as they are.
-- Takes every module's settings and positions, the Macros settings and the look; the
-- reminders' store and what the exporter answered about EllesmereUI's windows (ns.PROFILE_OWN)
-- are left out, so a player asks as on a first run. Naowh's two are kept beside it, edited there
-- and rebuilt from the repo root with Libs/:
--   lua5.1 Tools/build/presets.lua minimalist Tools/data/preset_minimalist.lua Naowh
--   lua5.1 Tools/build/presets.lua recommended Tools/data/preset_recommended.lua Naowh
-- INFO's modulesOff, when a preset has it, are the module addons it turns off: applying it switches every
-- other module on (Core/Onboarding/Setup.lua, Setup.PresetSwitches), and the build writes the same switches
-- into its profile, so a new install starting from it agrees. Without it the preset's switches decide.
local INFO = {
    minimalist = { order = 1, name = "Minimalist",
        about = "Perfect if you're a Classic player and don't want to use a lot of addons. This option is for you if you prefer opting in instead of opting out.",
        modulesOff = { "NaowhForever_InstanceTracker", "NaowhForever_Training", "NaowhForever_Journeys",
            "NaowhForever_Discovery", "NaowhForever_GearSets", "NaowhForever_Blessings", "NaowhForever_Professions",
            "NaowhForever_Macros", "NaowhForever_ConsumableBar", "NaowhForever_ActionBars", "NaowhForever_AuraBuffs",
            "NaowhForever_ThreatMeter", "NaowhForever_GroupInspect", "NaowhForever_PvP", "NaowhForever_SwingTimer" } },
    recommended = { order = 2, name = "Everything Enabled",
        about = "Loads every module and gives you the full Naowh Forever experience.", modulesOff = {} },
}
local NEW_INSTALL = "minimalist"
local OUT = "Core/Profiles/Presets.lua"
local usage = "usage: lua5.1 Tools/build/presets.lua <" .. "minimalist|recommended> <profile string file, or profile .lua> [author]"
local which, source = assert(INFO[arg[1] or ""] and arg[1], usage), assert(arg[2], usage)
-- The reminders' store, and the retired Custom Reminders settings older strings still carry.
local LEFT_OUT = { tankReminder = true, customReminders = true }

strmatch = string.match
dofile("Libs/LibStub/LibStub.lua")
dofile("Libs/LibDeflate/LibDeflate.lua")
dofile("Libs/LibSerialize/LibSerialize.lua")
local ns = { UI = {}, PlainText = function(s) return s end }
local env = setmetatable({ _G = { NaowhForever = ns }, date = os.date }, { __index = _G })
ns.Shared = { Decode = dofile("Tools/regression/load_decode.lua")(env) }
local chunk = assert(loadfile("Core/Profiles/ProfileShare.lua"))
setfenv(chunk, env)
chunk()
chunk = assert(loadfile("Core/Onboarding/Setup.lua"))
setfenv(chunk, env)
chunk()

local presets = {}
local existing = io.open(OUT, "rb")
if existing then
    existing:close()
    local kept = { NaowhForever = {} }
    kept._G = kept
    local load = assert(loadfile(OUT))
    setfenv(load, kept)
    load()
    for key, preset in pairs(kept.NaowhForever.PRESETS or {}) do
        if INFO[key] then presets[key] = preset end
    end
end

local payload
if source:match("%.lua$") then
    local settings = assert(dofile(source), "the file returns no profile table")
    local macros = settings.macros
    settings.macros = nil
    payload = { name = INFO[which].name, author = arg[3] or "?", made = os.date("%Y-%m-%d"),
        parts = { settings = settings, macros = { module = macros } } }
else
    local f = assert(io.open(source, "rb"))
    local why
    payload, why = ns.DecodeProfile(f:read("*a"))
    f:close()
    assert(payload, "not a profile string: " .. tostring(why))
end
local parts = payload.parts

-- Taken into the account by the import's own checks, which this does not repeat.
for _, part in ipairs({ "library", "builds", "bisLists" }) do
    assert(parts[part] == nil, "the string carries " .. part .. ", which this does not take yet")
end
assert(not (parts.macros and parts.macros.classMacros), "the string carries class macros, which this does not take yet")

local profile, account = {}, {}
for key, values in pairs(parts.settings or {}) do
    if not LEFT_OUT[key] then profile[key] = values end
end
for key, own in pairs(ns.PROFILE_OWN) do
    for i = 1, #own do
        if profile[key] then profile[key][own[i]] = nil end
    end
end
if parts.macros and parts.macros.module then profile.macros = parts.macros.module end
for key, value in pairs(parts.look or {}) do account[key] = value end
profile.qol = profile.qol or {}
profile.qol.preset = which
if INFO[which].modulesOff then
    local off = {}
    for _, addon in ipairs(INFO[which].modulesOff) do off[addon] = true end
    for _, item in pairs(ns.Setup.ITEMS) do
        profile[item.db] = profile[item.db] or {}
        profile[item.db][item.key] = not off[item.addon]
    end
end
presets[which] = { source = ("%s by %s, %s"):format(tostring(payload.name), tostring(payload.author),
    tostring(payload.made)), profile = profile, account = account }
assert(presets[NEW_INSTALL], "build the " .. NEW_INSTALL .. " preset first: a new install starts from it")

local function Key(k)
    if type(k) == "string" and k:match("^[%a_][%w_]*$") then return k end
    if type(k) == "string" then return "[" .. ("%q"):format(k) .. "]" end
    return "[" .. tostring(k) .. "]"
end

local function Value(v)
    if type(v) == "string" then
        -- ASCII only in the source: anything else as a decimal escape.
        return (("%q"):format(v):gsub("\\\n", "\\n"):gsub("[\128-\255]", function(c)
            return ("\\%d"):format(c:byte())
        end))
    end
    if type(v) == "number" then
        local short = ("%.14g"):format(v)
        return tonumber(short) == v and short or ("%.17g"):format(v)
    end
    return tostring(v)
end

local function Sorted(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then return a < b end
        return type(a) == "number"
    end)
    return keys
end

local lines = {}
local function Emit(t, indent)
    for _, k in ipairs(Sorted(t)) do
        local v = t[k]
        if type(v) == "table" then
            if next(v) == nil then
                lines[#lines + 1] = ("%s%s = {},"):format(indent, Key(k))
            else
                lines[#lines + 1] = ("%s%s = {"):format(indent, Key(k))
                Emit(v, indent .. "    ")
                lines[#lines + 1] = indent .. "},"
            end
        else
            lines[#lines + 1] = ("%s%s = %s,"):format(indent, Key(k), Value(v))
        end
    end
end

local keys = {}
for key in pairs(presets) do keys[#keys + 1] = key end
table.sort(keys, function(a, b) return INFO[a].order < INFO[b].order end)

-- One header line, as the house style asks; each preset's source is in its data (source = ...).
lines[#lines + 1] = "-- Presets.lua: the setups a player can start from (ns.PRESETS), generated by Tools/build/presets.lua."
lines[#lines + 1] = "local ns = _G.NaowhForever"
lines[#lines + 1] = ""
lines[#lines + 1] = "ns.PRESETS = {"
lines[#lines + 1] = "    newInstall = " .. Value(NEW_INSTALL) .. ","
local order = {}
for _, key in ipairs(keys) do order[#order + 1] = Value(key) end
lines[#lines + 1] = "    order = { " .. table.concat(order, ", ") .. " },"
for _, key in ipairs(keys) do
    lines[#lines + 1] = ("    %s = {"):format(key)
    lines[#lines + 1] = "        name = " .. Value(INFO[key].name) .. ","
    lines[#lines + 1] = "        about = " .. Value(INFO[key].about) .. ","
    lines[#lines + 1] = "        source = " .. Value(presets[key].source) .. ","
    if INFO[key].modulesOff then
        local names = {}
        for i, addon in ipairs(INFO[key].modulesOff) do names[i] = Value(addon) end
        lines[#lines + 1] = "        modulesOff = " .. (#names > 0 and "{ " .. table.concat(names, ", ") .. " }" or "{}") .. ","
    end
    lines[#lines + 1] = "        profile = {"
    Emit(presets[key].profile, "            ")
    lines[#lines + 1] = "        },"
    lines[#lines + 1] = "        account = {"
    Emit(presets[key].account, "            ")
    lines[#lines + 1] = "        },"
    lines[#lines + 1] = "    },"
end
lines[#lines + 1] = "}"
lines[#lines + 1] = "ns.STARTER = ns.PRESETS[ns.PRESETS.newInstall]"

local out = assert(io.open(OUT, "wb"))
out:write(table.concat(lines, "\r\n"), "\r\n")
out:close()
print(("%s: %s built (%d modules); presets: %s"):format(OUT, which, #Sorted(profile), table.concat(order, ", ")))

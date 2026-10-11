-- Run with Lua 5.1 from the repository root: the note on a setting EllesmereUI also has
-- (Shared/Settings/Ellesmere.lua). Nothing without EllesmereUI or with its table missing, its
-- on or off read live, a key it never saved read as its own default, and every overlap a
-- real QoL switch.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local loaded = {}
local Settings = {}
local env = setmetatable({
    NaowhForever = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Shared = { Settings = Settings } },
    C_AddOns = { IsAddOnLoaded = function(name) return loaded[name] == true end },
}, { __index = _G })
env._G = env
local source = Read("Shared/Settings/Ellesmere.lua")
local chunk = assert(loadstring(source, "Ellesmere"))
setfenv(chunk, env)
chunk()

local Note = Settings.EllesmereNote
local ON, OFF = "EllesmereUI has it on", "EllesmereUI has it off"
local repair, cinematics = { key = "autoRepair" }, { key = "skipCinematics" }

check("no note without EllesmereUI", Note(repair) == nil and Note(cinematics) == nil)

env.EllesmereUIDB = { autoRepair = true, skipCinematicsAuto = true }
check("no note while its QoL addon is not loaded", Note(repair) == nil)

loaded.EllesmereUIQoL = true
check("on there", Note(repair) == ON and Note(cinematics) == ON)
env.EllesmereUIDB.autoRepair, env.EllesmereUIDB.skipCinematicsAuto = false, false
check("off there", Note(repair) == OFF and Note(cinematics) == OFF)
env.EllesmereUIDB.skipCinematics = true
check("skipping only on a key press there is not the same as skipping", Note(cinematics) == OFF)

env.EllesmereUIDB = {}
check("a key never saved reads as EllesmereUI's default",
    Note(repair) == ON and Note(cinematics) == OFF)

env.EllesmereUIDB = nil
check("no note while its table is missing", Note(repair) == nil)
env.EllesmereUIDB = "changed"
check("no note when its table is something else", Note(repair) == nil)

check("no note for a setting EllesmereUI does not have", Note({ key = "hideZoneText" }) == nil)
check("no note for a row with no key", Note({ label = "Reset" }) == nil)

loaded.EllesmereUIForeverEssentials = true
local feed = { switch = "lootFeed" }
env.EllesmereUIDB = {}
check("a card's switch is looked up, its feature table read as default", Note(feed) == OFF)
env.EllesmereUIDB = { lootFeed = { enabled = true } }
check("a feature's own table read", Note(feed) == ON)
env.EllesmereUIDB = { lootFeed = true }
check("no note when a feature's table is something else", Note(feed) == nil)

loaded.EllesmereUIQuestTracker = true
local accept = { key = "questAccept" }
env.EllesmereUIDB = {}
check("no note before the Quest Tracker's profile is made", Note(accept) == nil)
env._EQT_DB = { profile = { questTracker = { autoAccept = true } } }
check("the Quest Tracker's profile read", Note(accept) == ON)
env._EQT_DB.profile.questTracker.autoAccept = false
check("the Quest Tracker's profile read off", Note(accept) == OFF)
env._EQT_DB.profile.questTracker.autoAccept = true
env._EQT_DB.profile.questTracker.enabled = false
check("off while the Quest Tracker itself is off, as its auto-accept then never runs", Note(accept) == OFF)

local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,}
_G.NaowhForever = ns
assert(loadstring(Read("Core/Features.lua"), "Features"))()
local count = 0
for key in source:gmatch("\n    (%w+) = { addon = ") do
    check("an overlap is a QoL switch: " .. key, ns.FEATURES.qol[key] ~= nil)
    count = count + 1
end
check("the overlaps were found", count > 0)

print("PASS ellesmere note (" .. checks .. " checks)")

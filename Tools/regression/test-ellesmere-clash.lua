-- Run with Lua 5.1 from the repository root: the popup when a setting is on in both EllesmereUI and
-- here (Shared/Settings/Ellesmere.lua). A click that turns one on while EllesmereUI has it on asks;
-- a card switch asks for its rows too; EllesmereUI's window closing with one newly on asks; Turn Off
-- Here turns ours off. EllesmereUI's values are read as before: defaults, its gate, and nothing
-- without its addon or its table. Every overlap is a real QoL switch.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local values = {}
local store = { Get = function(k) return values[k] end, Set = function(k, v) values[k] = v end }
local restock = { name = "Restock", store = store, rows = { { key = "autoRepair", label = "Auto Repair" },
    { key = "sellJunk", label = "Auto Sell Junk" } } }
local feed = { name = "Loot Feed", store = store, switch = "lootFeed", rows = {} }
local clutter = { name = "Hide Clutter", store = store, switch = "hideClutter",
    rows = { { key = "skipCinematics", label = "Skip Cinematics" } } }
local quests = { name = "Quests", store = store, rows = { { key = "questAccept", label = "Accept Quests" } } }
local Settings = { pages = { ["QoL/Loot"] = { cards = { restock = restock, lootFeed = feed } },
    ["QoL/Interface"] = { cards = { clutter = clutter } }, ["QoL/Questing"] = { cards = { quests = quests } } },
    Off = function(row) return row.held == true end }

local asked, refreshed = {}, 0
local openers = {}
local loaded = {}
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Shared = { Settings = Settings }, Apply = function() end,
    UI = { RefreshPage = function() refreshed = refreshed + 1 end },
    Confirm = function(text, yes, _, yesText, noText)
        asked[#asked + 1] = { text = text, yes = yes, yesText = yesText, noText = noText }
    end }
local env = setmetatable({
    NaowhForever = ns,
    C_AddOns = { IsAddOnLoaded = function(name) return loaded[name] == true end },
    hooksecurefunc = function(t, name, fn)
        if t ~= ns then openers[name] = fn end
    end,
}, { __index = _G })
env._G = env
local source = Read("Shared/Settings/Ellesmere.lua")
local chunk = assert(loadstring(source, "Ellesmere"))
setfenv(chunk, env)
chunk()
local Clash = Settings.EllesmereClash

local function Last() return asked[#asked] end

values.autoRepair = true
Clash(restock, "autoRepair")
check("nothing without EllesmereUI", #asked == 0)

env.EllesmereUIDB = { autoRepair = true }
Clash(restock, "autoRepair")
check("nothing while its QoL addon is not loaded", #asked == 0)

loaded.EllesmereUIQoL = true
Clash(restock, "autoRepair")
check("on in both after a click: asks", #asked == 1
    and Last().text == "Auto Repair is on in both EllesmereUI and Naowh Forever. Turn one of them off."
    and Last().yesText == "Turn Off Here" and Last().noText == "Keep Both")
Last().yes()
check("Turn Off Here turns ours off and redraws", values.autoRepair == false and refreshed == 1)

values.autoRepair = true
env.EllesmereUIDB.autoRepair = false
Clash(restock, "autoRepair")
check("off there: no popup", #asked == 1)
env.EllesmereUIDB = {}
Clash(restock, "autoRepair")
check("a key never saved reads as its default, on for Auto Repair", #asked == 2)

values.sellJunk = true
Clash(restock, "hideZoneText")
check("a setting EllesmereUI does not have never asks", #asked == 2)
env.EllesmereUIDB = nil
Clash(restock, "autoRepair")
check("nothing while its table is missing", #asked == 2)

env.EllesmereUIDB = { skipCinematicsAuto = true }
values.skipCinematics = true
Clash(clutter, "skipCinematics")
check("a row under a card switched off is not on here yet", #asked == 2)
values.hideClutter = true
Clash(clutter, "hideClutter")
check("switching the card on asks about its rows",
    #asked == 3 and Last().text:find("^Skip Cinematics is on in both"))

loaded.EllesmereUIForeverEssentials = true
env.EllesmereUIDB = { lootFeed = { enabled = true } }
values.lootFeed = true
Clash(feed, "lootFeed")
check("a card's own switch", #asked == 4 and Last().text:find("^Loot Feed"))
env.EllesmereUIDB = { lootFeed = true }
Clash(feed, "lootFeed")
check("a feature's table that is something else reads as off", #asked == 4)

loaded.EllesmereUIQuestTracker = true
values.questAccept = true
env._EQT_DB = { profile = { questTracker = { autoAccept = true, enabled = false } } }
Clash(quests, "questAccept")
check("auto-accept is off while the Quest Tracker itself is off", #asked == 4)
env._EQT_DB.profile.questTracker.enabled = true
Clash(quests, "questAccept")
check("the Quest Tracker's profile read", #asked == 5)

local frame = { scripts = {}, shown = false }
function frame:HookScript(name, fn) self.scripts[name] = fn end
function frame:IsShown() return self.shown end
env.EllesmereUI = { Show = true, Toggle = true, GetMainFrame = function() return frame.made and frame or nil end }
Settings.WatchEllesmere()
check("its window openers are hooked when watched", openers.Show and openers.Toggle and openers.ShowModule == nil)
frame.made, frame.shown = true, true
openers.Show()
openers.Toggle()
check("its window is watched once it exists", frame.scripts.OnShow and frame.scripts.OnHide)

env.EllesmereUIDB = { autoRepair = false, autoSellJunk = true, lootFeed = { enabled = true } }
values = { autoRepair = true, sellJunk = true, lootFeed = true }
frame.scripts.OnShow()
env.EllesmereUIDB.autoRepair = true
frame.scripts.OnHide()
check("closing its window with one newly on there asks about that one",
    #asked == 6 and Last().text:find("^Auto Repair is on"))
frame.scripts.OnShow()
frame.scripts.OnHide()
check("nothing new there, nothing asked", #asked == 6)
env.EllesmereUIDB.autoRepair, env.EllesmereUIDB.autoSellJunk = false, false
frame.scripts.OnShow()
env.EllesmereUIDB.autoRepair, env.EllesmereUIDB.autoSellJunk = true, true
frame.scripts.OnHide()
check("several at once in one popup", #asked == 7
    and Last().text == "Auto Repair, Auto Sell Junk are on in both EllesmereUI and Naowh Forever. Turn one of each off.")
Last().yes()
check("Turn Off Here turns each off", values.autoRepair == false and values.sellJunk == false)
values.autoRepair, restock.rows[1].held = true, true
Clash(restock, "autoRepair")
check("a row held off here, as under the Gamepad style, never asks", #asked == 7)
restock.rows[1].held = nil

local qol = {}
_G.NaowhForever = qol
assert(loadstring(Read("Core/Features.lua"), "Features"))()
local count = 0
for key in source:gmatch("\n    (%w+) = { addon = ") do
    check("an overlap is a QoL switch: " .. key, qol.FEATURES.qol[key] ~= nil)
    count = count + 1
end
check("the overlaps were found", count > 0)

print("PASS ellesmere clash (" .. checks .. " checks)")

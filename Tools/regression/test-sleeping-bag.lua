-- Regression test for the Cozy Sleeping Bag chain (NaowhForever_Discovery/Data/SleepingBag.lua and
-- the chain logic in NaowhForever_Discovery/SleepingBag.lua): each faction's steps in order, the
-- first starting its faction's quest, every later one handing one in, the chain read from the
-- quest log, step by step, and two steps of one name told apart by their zone. Then the Sleeping
-- Bag tracker on the shared tracker window (its rows, no garbage per redraw), its map pins
-- redrawn on the quest log update after a step, one name for it, and short help texts.
--   lua5.1 Tools/regression/test-sleeping-bag.lua

local checks = 0
local function Check(ok, label)
    checks = checks + 1
    assert(ok, label)
end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,}
_G.NaowhForever = ns
assert(loadstring(Read("NaowhForever_Discovery/Data/SleepingBag.lua")))()
local data = ns.SleepingBag

-- The data.
Check(data.level == 14 and data.item == 211527, "the chain needs level 14 and gives the Cozy Sleeping Bag")
for side, first in pairs({ A = 79008, H = 79007 }) do
    local steps = data.steps[side]
    Check(#steps == 7, side .. ": seven steps")
    Check(steps[1].started == first and steps[1].done == nil, side .. ": the first starts its faction's note")
    Check(steps[2].done == first, side .. ": the second hands it in")
    for i, step in ipairs(steps) do
        Check(type(step.map) == "number" and type(step.x) == "number" and type(step.y) == "number"
            and step.object and step.place, side .. ": step " .. i .. " has where it is")
        if i > 1 then Check(type(step.done) == "number", side .. ": step " .. i .. " hands in a quest") end
    end
    Check(steps[7].done == 79976, side .. ": the last hands in This Must Be The Place")
end
Check(data.steps.A[1].map == 1436 and data.steps.H[1].map == 1413,
    "the Alliance starts in Westfall, the Horde in The Barrens")
Check(data.steps.A[3] == data.steps.H[3], "the chain is the same for both from Stonetalon on")

-- The logic, loaded from its own file, against a quest log.
local logic = Read("NaowhForever_Discovery/SleepingBag.lua")
local completed, inLog, level, side = {}, {}, 20, "A"
local env = setmetatable({
    ns = ns,
    Library = { Side = function() return side end, ZoneName = function(map) return "map " .. map end },
    C_QuestLog = {
        IsQuestFlaggedCompleted = function(id) return completed[id] == true end,
        IsOnQuest = function(id) return inLog[id] == true end,
    },
    UnitLevel = function() return level end,
}, { __index = _G })
ns.Discovery = { Library = env.Library }
local chunk = assert(loadstring(logic))
setfenv(chunk, env)
chunk()
local Bag = ns.SleepingBagChain

local step, at = Bag.Current()
Check(at == 1 and step.object == "Burned-Out Remains" and step.map == 1436, "nothing done: the first remains")
inLog[79008] = true
step, at = Bag.Current()
Check(at == 2 and step.map == 1413, "the note in your log: the second remains, in The Barrens")
inLog[79008], completed[79008] = nil, true
for _, id in ipairs({ 79192, 79980, 79974 }) do completed[id] = true end
step, at = Bag.Current()
Check(at == 6 and step.object == "Messenger Bag", "four steps on: the Messenger Bag")
completed[79975], completed[79976] = true, true
Check(Bag.Current() == nil, "every step done: nothing left")
side, completed = "H", {}
step, at = Bag.Current()
Check(at == 1 and step.map == 1413, "a Horde character starts in The Barrens")
level = 13
Check(not Bag.Level(), "under level 14 it cannot start")
level = 14
Check(Bag.Level(), "at 14 it can")
Check(Bag.Where(step):find("map 1413", 1, true) ~= nil, "where a step is names its zone")

-- Two steps of one name (the Burned-Out Remains) are told apart by their zone; the rest keep
-- their own.
for _, s in ipairs({ "A", "H" }) do
    side = s
    local steps = Bag.Steps()
    Check(Bag.Name(steps[1]) == steps[1].object .. " (map " .. steps[1].map .. ")"
        and Bag.Name(steps[2]) == steps[2].object .. " (map " .. steps[2].map .. ")"
        and Bag.Name(steps[1]) ~= Bag.Name(steps[2]), s .. ": the two remains named with their zones")
    for i = 3, #steps do
        Check(Bag.Name(steps[i]) == steps[i].object, s .. ": step " .. i .. " keeps its name")
    end
end
Check(Bag.Name(data.optional) == "Firepit", "the optional step keeps its name")
local messenger = data.steps.A[6]
Check(Bag.Sub(messenger, false) == "map 1417, inside Thoradin's Wall"
    and Bag.Sub(messenger, true) == "map 1417, inside Thoradin's Wall\n" .. messenger.tip,
    "a step's line: its zone and place, and how to get there for the step to do now")
side, completed, inLog = "A", {}, {}

-------------------------------------------------------------------------------
--  Stubs for the tracker and the map pins: no garbage of their own
-------------------------------------------------------------------------------
local NOTHING = function() end
local settings = { enabled = true, bagTracker = true, bagTrackerScale = 1, bagTrackerAlpha = 1,
    bagMapPins = true, bagMapPinSize = 20 }
local S = {}
function S.Get(key) return settings[key] end
function S.Set(key, value) settings[key] = value end
local function hooksecurefunc(t, name, fn)
    local orig = t[name]
    t[name] = function(...)
        if orig then orig(...) end
        fn(...)
    end
end
local FRAME = {}
FRAME.__index = FRAME
function FRAME:SetScript(_, fn) self.onEvent = fn end
function FRAME:RegisterEvent(event) self.events[event] = true end
function FRAME:UnregisterEvent(event) self.events[event] = nil end
function FRAME:UnregisterAllEvents() for event in pairs(self.events) do self.events[event] = nil end end
local frames = {}
local function CreateFrame()
    local frame = setmetatable({ events = {} }, FRAME)
    frames[#frames + 1] = frame
    return frame
end
local timers = {}
local TIMER = { After = function(_, fn) timers[#timers + 1] = fn end }
local GREY, WHITE, BLUE = { r = 0.5, g = 0.5, b = 0.5 }, { r = 1, g = 1, b = 1 }, { r = 0, g = 0.5, b = 1 }
local waypoints = {}
local Library = env.Library
Library.Waypoint = function(title) waypoints[#waypoints + 1] = title end
local zone = 1436
Library.PlayerZone = function() return zone end
local addon = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    DiscoverySettings = S, SleepingBag = data, SleepingBagChain = Bag, Library = Library,
    THEME = { muted = GREY, fg = WHITE, accent = BLUE, accentSoft = BLUE },
    UI = { RefreshPage = NOTHING },
}

-- A tracker window as Parts.TrackerPanel makes it: the options it was given, the rows it was
-- handed.
local BAR = { SetMinMaxValues = NOTHING, SetValue = NOTHING, SetStatusBarColor = NOTHING,
    text = { SetText = NOTHING } }
local PANEL = { SetScale = NOTHING, Place = NOTHING, Paint = NOTHING, Fit = NOTHING }
PANEL.__index = PANEL
function PANEL:Show() self.shown = true end
function PANEL:Hide() self.shown = false end
function PANEL:IsShown() return self.shown end
function PANEL:SetRows(entries) self.entries = entries; return 0 end
local panel, title, mover
addon.Shared = { Style = { ROUND = "round" }, Parts = { TrackerPanel = function(name, opts)
    title = name
    panel = setmetatable({ opts = opts, bar = BAR, shown = true }, PANEL)
    panel.mover = opts.mover(panel, NOTHING)
    return panel
end } }
addon.UI.AttachMover = function(_, label, _, page)
    mover = { label, page, Show = NOTHING, Hide = NOTHING }
    return mover
end
local opened
addon.OpenDiscoveryWindow = function(tab) opened = tab end

local function Load(path, extra)
    local globals = {
        NaowhForever = addon, hooksecurefunc = hooksecurefunc, CreateFrame = CreateFrame,
        C_QuestLog = env.C_QuestLog, UnitLevel = env.UnitLevel, C_Timer = TIMER,
    }
    for k, v in pairs(extra or {}) do globals[k] = v end
    local fenv = setmetatable(globals, { __index = _G })
    globals._G = globals
    local loaded = assert(loadstring(Read(path), path))
    setfenv(loaded, fenv)
    loaded()
    return fenv
end

-------------------------------------------------------------------------------
--  The tracker
-------------------------------------------------------------------------------
addon.Discovery = { Settings = S, Bag = Bag, Library = Library }
Load("NaowhForever_Discovery/Constants.lua")
Load("NaowhForever_Discovery/View/Style.lua")
Load("NaowhForever_Discovery/UI/BagTracker.lua")
Check(panel == nil, "loaded, nothing is built")
addon.Apply()
Check(panel ~= nil and title == "SLEEPING BAG", "on, it is built on the shared tracker window, as Sleeping Bag")
local opts = panel.opts
Check(opts.bar == true and opts.settings.page == "Discovery/Sleeping Bag" and opts.settings.card == "bagtracker",
    "its bar, and its cog on the Sleeping Bag settings tab's tracker card")
Check(mover[1] == "Sleeping Bag" and mover[2] == "Discovery/Sleeping Bag", "Unlock Mode's mover on that tab")
opts.save("TOP", "TOP", 5, -7)
Check(settings.bagTrackerPos.point == "TOP" and settings.bagTrackerPos.relPoint == "TOP"
    and settings.bagTrackerPos.y == -7, "its place kept as it was saved before")
local point, relPoint, _, y = opts.load()
Check(point == "TOP" and relPoint == "TOP" and y == -7, "and read back")
opts.onTitle()
Check(opened == "bag", "its title opens the Sleeping Bag tab")
Check(opts.opacity() == 1, "its own opacity")

local rows = panel.entries
Check(#rows == 7, "a row per step")
Check(rows[1].text == "1. Burned-Out Remains (map 1436)" and rows[2].text == "2. Burned-Out Remains (map 1413)",
    "the two remains told apart by their zones")
Check(rows[1].color == nil and rows[2].color == GREY, "the step to do now in the text color, the rest muted")
Check(rows[1].sub == "map 1436, Alexston Farmstead\n" .. data.steps.A[1].tip
    and rows[2].sub == "map 1413, " .. data.steps.A[2].place, "how to get there under the step to do now only")
rows[3].waypoint(rows[3])
Check(waypoints[1] == "Pocket Litter", "a pin's waypoint is its step's")

inLog[79008] = true
addon.ShowUnlockMode()
rows = panel.entries
Check(rows[1].done == true and rows[1].sub == nil and rows[1].color == GREY and rows[2].color == nil,
    "a step done: ticked, muted, nothing under it; the next one in full")
local first = rows[1]
local Measure = dofile("Tools/regression/measure.lua")(function(label, ok) Check(ok, label) end)
Measure("the tracker redrawn", 1, function() addon.ShowUnlockMode() end)
Check(panel.entries[1] == first, "its rows' entries kept and refilled")

panel.opts.onClose()
Check(settings.bagTracker == true and panel.shown == false, "its X hides it, the setting left on")
addon.Apply()
Check(panel.shown == false, "and it stays hidden in that zone")
zone = 1413
addon.Apply()
Check(panel.shown == true, "in the next zone it is back")
panel.opts.onClose()
zone = 1436
addon.Apply()
Check(panel.shown == true, "closed again, it is back in the next zone too")

-------------------------------------------------------------------------------
--  The map pins: redrawn on the quest log update after a step, once, and only while on
-------------------------------------------------------------------------------
local redraws, pins = 0, {}
local map = {
    RemoveAllPinsByTemplate = function() redraws = redraws + 1 end,
    GetMapID = function() return 1442 end,
    AcquirePin = function(_, _, entry) pins[#pins + 1] = entry end,
}
local mapGlobals = {
    CreateFromMixins = function(...)
        local out = {}
        for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do out[k] = v end end
        return out
    end,
    MapCanvasPinMixin = {},
    MapCanvasDataProviderMixin = { GetMap = function() return map end },
    WorldMapFrame = { AddDataProvider = NOTHING, IsShown = function() return true end },
}
settings.bagMapPins = false
local before = #frames
local mapEnv = Load("NaowhForever_Discovery/UI/BagPins.lua", mapGlobals)
local boot = frames[#frames]
Check(#frames == before + 1 and boot.events.PLAYER_LOGIN, "loaded, only its login check")
addon.Apply()
Check(#frames == before + 1, "off, it listens to nothing")
settings.bagMapPins = true
addon.Apply()
local events = frames[#frames]
Check(events ~= boot and events.events.QUEST_ACCEPTED and events.events.QUEST_TURNED_IN
    and not events.events.QUEST_LOG_UPDATE, "on: a step taken or handed in, not every quest log update")
completed, inLog = { [79008] = true, [79192] = true }, {}
redraws, pins = 0, {}
local handler = events.onEvent
local function Fire(event)
    if events.events[event] then events.onEvent(events, event) end
end
Fire("QUEST_TURNED_IN")
Fire("QUEST_ACCEPTED")
Check(redraws == 0 and events.events.QUEST_LOG_UPDATE, "a step done: one redraw waits for the quest log")
Fire("QUEST_LOG_UPDATE")
Check(redraws == 1 and not events.events.QUEST_LOG_UPDATE and events.onEvent == handler and #timers == 0,
    "the quest log updated: one redraw, no timer, then it stops listening for it")
Check(#pins == 1 and pins[1].number == 4 and pins[1].now, "the pin of the step to do now, on its map")
Fire("QUEST_LOG_UPDATE")
Check(redraws == 1, "a later quest log update draws nothing")
Fire("QUEST_ACCEPTED")
settings.bagMapPins = false
addon.Apply()
Check(next(events.events) == nil, "switched off, it stops listening, the pending redraw too")

local lines = {}
mapEnv.GameTooltip = { SetOwner = NOTHING, Show = NOTHING,
    SetText = function(_, text) lines[#lines + 1] = text end,
    AddLine = function(_, text) lines[#lines + 1] = text end }
local pin = setmetatable({ entry = { step = data.steps.A[2], number = 2, now = true } },
    { __index = mapEnv.NaowhForeverSleepingBagPinMixin })
pin:OnMouseEnter()
Check(lines[1] == "Sleeping Bag, step 2" and lines[2] == "Burned-Out Remains (map 1413)",
    "a pin's tooltip: Sleeping Bag, and the step named with its zone")

-------------------------------------------------------------------------------
--  One name, and short help
-------------------------------------------------------------------------------
for _, path in ipairs({ "NaowhForever_Discovery/Discovery.lua", "NaowhForever_Discovery/SleepingBag.lua",
        "NaowhForever_Discovery/Data/SleepingBag.lua", "NaowhForever_Discovery/View/BagHero.lua",
        "NaowhForever_Discovery/View/StepRow.lua", "NaowhForever_Discovery/UI/Window.lua",
        "NaowhForever_Discovery/UI/BagTracker.lua", "NaowhForever_Discovery/UI/BagPins.lua",
        "NaowhForever_Discovery/UI/BagSettings.lua", "NaowhForever_Discovery/UI/BooksSettings.lua",
        "Core/Options/Window.lua", "Core/Options/Modules.lua" }) do
    Check(not Read(path):find("Sleeping Bags", 1, true), path .. ": one name, Sleeping Bag")
end
local bagPage = Read("NaowhForever_Discovery/UI/BagSettings.lua")
    :match('local bags = Settings%.Page%("Discovery/Sleeping Bag", S%)(.*)$')
Check(bagPage ~= nil and bagPage:find('text = "Open Sleeping Bag"', 1, true), "its tab and Open button: Sleeping Bag")
local helps = 0
for help in bagPage:gmatch('help = ("[^"\r\n]*")') do
    local text = assert(loadstring("return " .. help))()
    helps = helps + 1
    Check(#text < 100 and not text:find("%. %u") and not text:find("Unlock Mode", 1, true),
        "one short sentence: " .. text)
end
Check(helps == 5, "every help on the Sleeping Bag tab was read (" .. helps .. ")")
Check(not bagPage:find('help = "[^"\r\n]*"%s*%.%.'), "no help strung over lines")

-------------------------------------------------------------------------------
--  Both Discovery trackers on the shared tracker window, with no copy of its parts
-------------------------------------------------------------------------------
for _, path in ipairs({ "NaowhForever_Discovery/UI/BookTracker.lua",
        "NaowhForever_Discovery/UI/BagTracker.lua" }) do
    local text = Read(path)
    Check(text:find("Parts.TrackerPanel(", 1, true) and text:find("SetRows(", 1, true),
        path .. ": on Parts.TrackerPanel, its rows through SetRows")
    Check(not text:find('"StatusBar"', 1, true) and not text:find("Parts.Panel(", 1, true)
        and not text:find("RegisterForDrag", 1, true) and not text:find("row.stripe", 1, true),
        path .. ": no copy of the window, bar, drag or rows")
end

print("PASS sleeping bag: " .. checks .. " checks")

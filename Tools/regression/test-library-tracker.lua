-- Regression test for the Library Books tracker (NaowhForever_Discovery/UI/BookTracker.lua) with
-- Always Show on: its zone dropdown lists every zone with a book still to find, in the data's
-- order, each with how many, and the zone picked kept at 0 once its last book is looted. Each
-- book's state is read once per redraw, not once per zone, and a redraw stays cheap.
--   lua5.1 Tools/regression/test-library-tracker.lua

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

local NOTHING = function() end
local calls = 0
local done, held = {}, {}
local settings = { enabled = true, tracker = true, trackerAlways = true, trackerScale = 1, trackerAlpha = 1 }
local S = {}
function S.Get(key) return settings[key] end
function S.Set(key, value) settings[key] = value end
function S.Raw(key) return settings[key] end

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
local function CreateFrame() return setmetatable({ events = {} }, FRAME) end

local here = 1436
local ZONE_INFO = {}
local function MapInfo(id)
    local info = ZONE_INFO[id]
    if not info then
        info = { mapID = id, name = "Zone " .. id, mapType = 3, parentMapID = 0 }
        ZONE_INFO[id] = info
    end
    return info
end

local GREY, WHITE, BLUE = { r = 0.5, g = 0.5, b = 0.5 }, { r = 1, g = 1, b = 1 }, { r = 0, g = 0.5, b = 1 }
local BAR = { SetMinMaxValues = NOTHING, SetValue = NOTHING, SetStatusBarColor = NOTHING, EnableMouse = NOTHING,
    SetScript = NOTHING, text = { SetText = NOTHING } }
local PANEL = { SetScale = NOTHING, Place = NOTHING, Paint = NOTHING, Fit = NOTHING }
PANEL.__index = PANEL
function PANEL:Show() self.shown = true end
function PANEL:Hide() self.shown = false end
function PANEL:IsShown() return self.shown end
function PANEL:SetRows(entries) self.entries = entries; return 0 end
local panel
local PICKER = { Hide = NOTHING, SetShown = NOTHING, _refreshLabel = NOTHING }
local TITLE = { SetText = NOTHING }

local addon = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    THEME = { muted = GREY, fg = WHITE, accent = BLUE, accentSoft = BLUE },
    UI = { RefreshPage = NOTHING, AttachMover = function() return { Show = NOTHING, Hide = NOTHING } end },
    Color = function(_, text) return text end,
    ThemeTint = function() return nil end,
    Shared = { Style = { CARRIED_RGB = BLUE }, Parts = { TrackerPanel = function(_, opts)
        panel = setmetatable({ opts = opts, bar = BAR, picker = PICKER, title = TITLE, shown = false }, PANEL)
        return panel
    end } },
}
addon.UI.ModuleSettings = function() return S end

local globals = {
    NaowhForever = addon, hooksecurefunc = hooksecurefunc, CreateFrame = CreateFrame,
    C_Timer = { After = NOTHING },
    C_QuestLog = {
        IsQuestFlaggedCompleted = function(id) calls = calls + 1; return done[id] == true end,
    },
    C_Item = {
        GetItemCount = function(id) calls = calls + 1; return held[id] or 0 end,
    },
    C_Map = {
        GetBestMapForUnit = function() return here end,
        GetMapInfo = MapInfo,
    },
    Enum = { UIMapType = { Zone = 3 } },
    UnitFactionGroup = function() return "Alliance" end,
    UnitLevel = function() return 30 end,
    GetQuestDifficultyColor = function() return WHITE end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
}
globals._G = globals
local env = setmetatable(globals, { __index = _G })

local function Load(path)
    local chunk = assert(loadstring(Read(path), path))
    setfenv(chunk, env)
    chunk()
end

Load("Core/Features.lua")
Load("NaowhForever_Discovery/Discovery.lua")
Load("NaowhForever_Discovery/Constants.lua")
Load("NaowhForever_Discovery/Data/Books.lua")
Load("NaowhForever_Discovery/Library.lua")
Load("NaowhForever_Discovery/View/Style.lua")
Load("NaowhForever_Discovery/UI/BookTracker.lua")
local L = addon.Library

local function Expected(keep)
    local out, seen = {}, {}
    for _, book in ipairs(addon.LibraryBooks) do
        for _, spot in ipairs(book.spots) do
            local id = spot[1]
            if not seen[id] then
                seen[id] = true
                local n = 0
                for _, other in ipairs(addon.LibraryBooks) do
                    if L.ForMe(other) and not L.Done(other) and not L.Carried(other) then
                        for _, s in ipairs(other.spots) do
                            if s[1] == id then n = n + 1 end
                        end
                    end
                end
                if n > 0 or id == keep then out[#out + 1] = { id, n } end
            end
        end
    end
    return out
end

local function Listed()
    local order, names = panel.opts.picker.order, panel.opts.picker.values
    local out = {}
    for i, id in ipairs(order) do out[i] = { id, tonumber(names[id]:match("%((%d+)%)$")) } end
    return out
end

local function Same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i][1] ~= b[i][1] or a[i][2] ~= b[i][2] then return false end
    end
    return true
end

addon.Apply()
Check(panel ~= nil and panel.shown, "Always Show: the tracker is up")
Check(settings.trackerZone == here, "the zone you stand in is picked")
addon.Apply()
Check(Same(Listed(), Expected(here)), "every zone with a book to find, in the data's order, with how many")
local westfall
for _, z in ipairs(Listed()) do if z[1] == here then westfall = z[2] end end
Check(westfall and westfall > 0, "Westfall has books to find")

for _, book in ipairs(addon.LibraryBooks) do
    for _, spot in ipairs(book.spots) do
        if spot[1] == here then held[book.item] = 1 end
    end
end
addon.Apply()
local kept
for _, z in ipairs(Listed()) do if z[1] == here then kept = z[2] end end
Check(kept == 0, "the picked zone kept at 0 once its books are looted")
Check(Same(Listed(), Expected(here)), "and the other zones as before")
local handed = 0
for _, book in ipairs(addon.LibraryBooks) do
    if book.side == "B" and #book.spots > 0 and handed < 3 then
        done[book.quest] = true
        handed = handed + 1
    end
end
addon.Apply()
Check(Same(Listed(), Expected(here)), "handed-in books leave their zones' counts")

calls = 0
addon.Apply()
local perRedraw = calls
local books = #addon.LibraryBooks
print(("  game calls per redraw: %d, for %d books"):format(perRedraw, books))
Check(perRedraw <= books * 3 * 4, "each book's state read a few times per redraw, not once per zone")
local Measure = dofile("Tools/regression/measure.lua")(function(label, ok) Check(ok, label) end)
Measure("the tracker redrawn with Always Show", 0.2, function() addon.Apply() end)

print("PASS library tracker: " .. checks .. " checks")

-- Run with Lua 5.1 from the repository root: Fishing Levels on the world map. Each zone's pair
-- is the lowest skill that fishes there and the one no fish gets away from, 95 apart and never
-- under 1; the line is coloured by your skill with gear, sits under the level range or, with
-- none, under the game's Description, and is worked out once per hovered zone. It starts off,
-- has its own switch among the Map Options after Zone Levels, its words are in the English
-- catalog, and nothing is added to the map while both are off.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local ns = {}
_G.NaowhForever = ns
assert(loadstring(Read("Core/Features.lua"), "Features"))()
Check(ns.FEATURES.qol.mapFishing == false, "starts off")
Check(Read("Core/Settings.lua"):find("mapFishing = F.mapFishing", 1, true), "the QoL store reads its default")
local xml = Read("NaowhForever_QoL/QoL.xml")
local data, logic = xml:find("Interface\\FishingLevelsData.lua", 1, true), xml:find("Interface\\ZoneLevels.lua", 1, true)
Check(data and logic and data < logic, "the data loads before the logic")

-- The numbers.
assert(loadstring(Read("NaowhForever_QoL/Interface/FishingLevelsData.lua"), "FishingLevelsData"))()
local zones = 0
for map, pair in pairs(ns.FishingLevels) do
    Check(pair[2] - pair[1] == 95 or (pair[1] == 1 and pair[2] < 96), "95 apart, never under 1: " .. map)
    zones = zones + 1
end
Check(zones >= 40, "every zone with water (" .. zones .. ")")
local function Pair(map) return table.concat(ns.FishingLevels[map] or {}, "-") end
Check(Pair(1411) == "1-25" and Pair(1413) == "1-75" and Pair(1440) == "55-150", "Durotar, the Barrens, Ashenvale")
Check(Pair(1434) == "130-225" and Pair(1444) == "205-300" and Pair(1452) == "330-425", "Stranglethorn, Feralas, Winterspring")
Check(ns.FishingLevels[1427] == nil, "no line where there is no water")

-- The map, against stubs.
local settings = { enabled = true, zoneLevels = false, mapFishing = false }
local S = { Get = function(key) return settings[key] end, Set = function() end }
ns.QoLSettings = S
ns.Apply = function() end
ns.L = function(text) return text end
ns.Shared = { MapPins = {} }
ns.ZoneLevels = { [1411] = { 5, 10 } }

local function FontString()
    local fs = { text = "" }
    function fs:SetPoint(_, anchor) self.anchor = anchor end
    function fs:ClearAllPoints() self.anchor = nil end
    function fs:SetText(v) self.text = v end
    function fs:SetTextColor(r) self.color = r end
    return fs
end
ns.Font = function() return FontString() end

local description = {}
local hovered, reads = 1411, 0
local map = {
    dataProviders = { [{ Label = { Description = description } }] = true },
    GetCanvasContainer = function() return {} end,
    IsCanvasMouseFocus = function() return hovered ~= nil end,
    -- Each zone sits under its own cursor spot: a still cursor is not looked up again.
    GetNormalizedCursorPosition = function() return 0.5, (hovered or 0) / 10000 end,
    GetMapID = function() return 1414 end,
}
local added, onUpdate, label = 0, nil, nil
local fishing = { rank = 120, modifier = 10 }
local boot
local env = setmetatable({
    _G = { NaowhForever = ns },
    MapCanvasDataProviderMixin = { OnAdded = function(self, m) self.owningMap = m end,
        GetMap = function(self) return self.owningMap end },
    CreateFromMixins = function(mixin) local t = {}; for k, v in pairs(mixin) do t[k] = v end; return t end,
    CreateFrame = function(_, _, parent)
        if parent then
            label = { shown = true }
            function label:SetSize() end
            function label:SetFrameStrata() end
            function label:SetScript(_, fn) onUpdate = fn end
            function label:SetShown(v) self.shown = v end
            return label
        end
        return { RegisterEvent = function() end, SetScript = function(_, _, fn) boot = fn end }
    end,
    WorldMapFrame = { AddDataProvider = function(_, p) added = added + 1; p:OnAdded(map) end },
    C_Map = { GetMapInfoAtPosition = function() return { mapID = hovered } end },
    UnitLevel = function() return 12 end,
    GetQuestDifficultyColor = function(level) return { r = "quest" .. level } end,
    QuestDifficultyColors = { trivial = { r = "grey" }, impossible = { r = "red" }, difficult = { r = "yellow" },
        standard = { r = "green" } },
    GetProfessions = function() reads = reads + 1; return 1, 2, 3, fishing and 4 or nil, 5 end,
    GetProfessionInfo = function(index)
        assert(index == 4, "reads the Fishing slot")
        return "Fishing", 1, fishing.rank, 300, 0, 0, 356, fishing.modifier
    end,
    hooksecurefunc = function() end,
}, { __index = _G })
local chunk = assert(loadstring(Read("NaowhForever_QoL/Interface/ZoneLevels.lua"), "ZoneLevels"))
setfenv(chunk, env)
chunk()

local sections = {}
for _, section in ipairs(ns.Shared.MapPins) do sections[section.switch] = section end
local fishingSection, levelsSection = sections.mapFishing, sections.zoneLevels
Check(fishingSection and fishingSection.map and fishingSection.store == S, "a Map Options section of its own")
Check(levelsSection and fishingSection.order > levelsSection.order, "after Zone Levels")
local row = fishingSection.rows[1]
Check(#fishingSection.rows == 1 and row.key == "mapFishing" and row.toggle and row.label == "Fishing Levels",
    "one switch, Fishing Levels")
local catalog = Read("Core/Locales/enUS.lua")
for _, text in ipairs({ "Fishing %d-%d", "Fishing Levels", row.help }) do
    Check(catalog:find('L["' .. text .. '"] = true', 1, true), "in the English catalog: " .. text)
end
boot()
Check(added == 0, "nothing added to the map while both are off")

settings.mapFishing = true
boot()
Check(added == 1 and label.shown, "on: the map gets the label")
local function Hover(zone) hovered = zone; onUpdate() end
fishing.rank = 140
reads = 0
Hover(1440)
Check(label.fishing.text == "Fishing 55-150" and label.fishing.color == "green", "green once none get away")
Check(label.fishing.anchor == description and label.text.text == "", "under the Description with Zone Levels off")
Hover(1440); Hover(1440)
Check(reads == 1 and label.fishing.text == "Fishing 55-150", "your skill read once per zone")
fishing.rank = 40
Hover(1452)
Check(label.fishing.text == "Fishing 330-425" and label.fishing.color == "red", "red under the low end")
fishing.rank = 100
Hover(1440)
Check(label.fishing.color == "yellow", "yellow while a fish can get away")
Hover(1427)
Check(label.fishing.text == "", "nothing where there is no water")
Hover(nil)
Check(label.fishing.text == "", "nothing off the map")

settings.zoneLevels = true
boot()
Check(added == 1, "added once")
Hover(1411)
Check(label.text.text == "Level 5-10" and label.fishing.anchor == label.text, "under the level range with both on")
Check(label.fishing.text == "Fishing 1-25", "both lines at once")
fishing = nil
Hover(1440)
Check(label.fishing.text == "Fishing 55-150" and label.fishing.color == "grey", "grey without Fishing")
Check(label.fishing.anchor == description, "under the Description where the zone has no range")

settings.mapFishing = false
boot()
Hover(1411)
Check(label.fishing.text == "" and label.text.text == "Level 5-10", "Fishing off leaves Zone Levels alone")
settings.zoneInfo = true
ns.GamepadStandDown = function() return true end
boot()
Check(label.shown, "Zone Info stood down by the Gamepad style leaves Zone Levels on")
ns.GamepadStandDown = function() return false end
boot()
Check(not label.shown, "Zone Info running takes Zone Levels' place")
settings.zoneInfo, ns.GamepadStandDown = nil, nil
settings.zoneLevels = false
boot()
Check(not label.shown, "both off: the label hides")

print(("test-fishing-levels: %d checks passed"):format(checks))

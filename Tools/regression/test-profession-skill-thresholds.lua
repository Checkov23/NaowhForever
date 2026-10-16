-- Run with Lua 5.1 from the repository root: optional profession ranges and their shared bar geometry.
local checks = 0
local function Check(label, condition) assert(condition, label); checks = checks + 1 end
local settings = { enabled = true, skillThresholds = false }
local builds = 0
local ns = {
    Shared = { Parts = {} },
    THEME = { fg = { r = 1, g = 1, b = 1 } },
    Professions = {
        Settings = { Get = function(key) return settings[key] end }, State = {},
        Style = { SKILL_BAR_GAP = 8, PANE_INNER_W = 372, DIFFICULTY_RGB = {} },
        Recipes = { Profession = function() return { skill = 125, modifier = 5 } end },
    },
    RecipeData = {
        [197] = { recipes = {
            { spell = 10, skill = 75, yellow = 95, grey = 130 },
            { spell = 11, skill = 45, yellow = 30, grey = 65 },
            { spell = 12, skill = 300, yellow = 280, grey = 300 },
            { spell = 13, skill = 1 },
        } },
    },
}
_G.NaowhForever = ns
_G.CreateFrame = function() error("frames must not be built while disabled") end
dofile("NaowhForever_Professions/UI/SkillThresholds.lua")
local ranges = ns.Professions.SkillThresholds
Check("disabled feature reads nothing", ranges.Read({ recipeID = 10 }) == nil)
settings.skillThresholds = true
ns.Professions.State.linked = true
Check("linked professions read nothing", ranges.Read({ recipeID = 10 }) == nil)
ns.Professions.State.linked = false
local a, b, c, d = ranges.Read({ recipeID = 10 })
Check("orange starts at the learn skill, green at the midpoint", a == 75 and b == 95 and c == 112 and d == 130)
a, b, c, d = ranges.Read({ recipeID = 10, maxTrivialLevel = 140 })
Check("live grey also updates inferred green", a == 75 and b == 95 and c == 117 and d == 140)
a, b, c, d = ranges.Read({ recipeID = 11 })
Check("a recipe learned past its yellow is yellow from the learn skill", a == 45 and b == 45 and c == 47 and d == 65)
Check("contradictory live grey is not drawn", ranges.Read({ recipeID = 10, maxTrivialLevel = 90 }) == nil)
Check("a recipe grey once learned is not drawn", ranges.Read({ recipeID = 12 }) == nil)
Check("a recipe without a range is not guessed", ranges.Read({ recipeID = 13 }) == nil)
Check("unknown recipe is not guessed", ranges.Read({ recipeID = 20 }) == nil)
local parent = { icon = {} }
ns.Shared.Parts.ThresholdLine = function()
    builds = builds + 1
    return {
        SetPoint = function() end, SetWidth = function() end,
        Fill = function(self, first, yellow, green, grey, skill) self.bounds = { first, yellow, green, grey, skill } end,
        Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end,
    }
end
local line = ranges.Render(parent, { recipeID = 10 })
Check("current skill includes the racial modifier", line.bounds[5] == 130)
Check("line is built once and shown", builds == 1 and line.shown)
settings.skillThresholds = false
Check("turning off hides the line", ranges.Render(parent, { recipeID = 10 }) == nil and not line.shown)
settings.skillThresholds = true
ranges.Render(parent, { recipeID = 10 })
Check("re-enabling reuses the line", builds == 1 and line.shown)
settings.enabled = false
Check("module off hides the line", ranges.Render(parent, { recipeID = 10 }) == nil and not line.shown)

local function Frame()
    return {
        shown = true, width = 372,
        SetHeight = function(self, value) self.height = value end,
        SetWidth = function(self, value) self.width = value end,
        SetSize = function(self, width, height) self.width, self.height = width, height end,
        GetWidth = function(self) return self.width end,
        SetPoint = function(self, ...) self.point = { ... } end,
        ClearAllPoints = function() end, SetAllPoints = function() end,
        SetFrameLevel = function() end, GetFrameLevel = function() return 1 end,
        SetScript = function() end, SetJustifyH = function() end,
        SetShown = function(self, value) self.shown = value end,
        SetText = function(self, value) self.text = value end,
        GetStringWidth = function(self) return #self.text * 6 end,
        Paint = function() end, SetProgress = function() end,
    }
end
_G.CreateFrame = Frame
ns.Font = Frame
ns.Border = function() end
ns.Solid = Frame
ns.Shared.Parts.ProgressLine = function() local bar = Frame(); bar.fill = Frame(); return bar end
dofile("Shared/Style.lua")
dofile("Shared/UI/Thresholds.lua")
local bar = ns.Shared.Parts.ThresholdLine(Frame())
local colors = { [0] = {}, {}, {}, {} }
bar:Fill(1, 95, 112, 130, 125, colors)
Check("the line has all four bands", #bar.bands == 4)
Check("numeric boundaries stay in order", bar.labels[1].text == "1" and bar.labels[4].text == "130")
Check("ordinary ranges use one compact label row", bar.height == ns.Shared.Style.THRESHOLD_HEIGHT)
Check("the skill marker lies inside the bar", bar.marker.point[4] > 0 and bar.marker.point[4] < bar:GetWidth())
bar:Fill(1, 95, 112, 130, 0, colors)
Check("low skill marker is clamped", bar.marker.point[4] == 0)
bar:Fill(1, 95, 112, 130, 300, colors)
Check("high skill marker is clamped", bar.marker.point[4] == bar:GetWidth())
bar:Fill(1, 95, 112, 130, nil, colors)
Check("missing skill hides only the marker", not bar.marker.shown)
bar:Fill(1, 1, 2, 3, 1, colors)
Check("a missing orange band occupies no room", not bar.bands[1].shown)
Check("an empty band shows no label of its own", not bar.labels[1].shown and bar.labels[2].shown)
bar:SetWidth(180)
bar:Fill(1, 145, 147, 150, 149, colors)
for i = 1, #bar.labels do
    local label = bar.labels[i]
    Check("close thresholds all remain visible", label.shown)
    if label.shown then
        Check("visible label stays inside the line", label.point[4] >= 0 and label.point[4] + label:GetStringWidth() <= bar:GetWidth())
        for j = i + 1, #bar.labels do
            local other = bar.labels[j]
            if other.shown and other.point[5] == label.point[5] then
                Check("labels on a row never overlap", label.point[4] + label:GetStringWidth() <= other.point[4])
            end
        end
    end
end
print(("test-profession-skill-thresholds: %d checks passed"):format(checks))

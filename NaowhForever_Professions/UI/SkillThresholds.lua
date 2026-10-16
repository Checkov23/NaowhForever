-- SkillThresholds.lua: the selected recipe's difficulty boundaries and current-skill marker.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local R = P.Recipes
local W = P.State
local Parts = ns.Shared.Parts
local Style = P.Style

local HALF = 0.5

local Thresholds = {}
P.SkillThresholds = Thresholds

local function Entry(spell)
    for _, data in pairs(ns.RecipeData) do
        for _, r in ipairs(data.recipes) do
            if r.spell == spell then return r end
        end
    end
end

function Thresholds.Read(info)
    if not S.Get("enabled") or not S.Get("skillThresholds") or W.linked then return nil end
    local r = Entry(info.recipeID)
    if not r or not r.yellow then return nil end
    local learn, yellow, grey = r.skill, r.yellow, r.grey
    if type(info.maxTrivialLevel) == "number" and info.maxTrivialLevel > 0 then grey = info.maxTrivialLevel end
    if yellow >= grey or learn >= grey then return nil end
    return learn, math.max(learn, yellow), math.max(learn, math.floor((yellow + grey) * HALF)), grey
end

local function Skill()
    local profession = R.Profession()
    return profession and profession.skill + profession.modifier
end

function Thresholds.Render(parent, info)
    local first, yellow, green, grey = Thresholds.Read(info)
    local line = parent.skillThresholds
    if not first then
        if line then line:Hide() end
        return nil
    end
    if not line then
        line = Parts.ThresholdLine(parent)
        line:SetPoint("TOPLEFT", parent.icon, "BOTTOMLEFT", 0, -Style.SKILL_BAR_GAP)
        line:SetWidth(Style.PANE_INNER_W)
        parent.skillThresholds = line
    end
    line:Fill(first, yellow, green, grey, Skill(), Style.DIFFICULTY_RGB)
    line:Show()
    return line
end

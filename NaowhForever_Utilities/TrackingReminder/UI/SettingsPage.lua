-- SettingsPage.lua: the Tracking Reminder settings page, for this character's race and class.
local ns = _G.NaowhForever

local TR = ns.TrackingReminder
local S = TR.Settings
local D = TR.Data
local Look = TR.Look

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end
local Group = Settings.Group

local ICON_RANGE = { 20, 64, 1 }
local TEXT_RANGE = ns.Shared.Style.HUD_TEXT_RANGE
local ORDER_TRACKING = 10
local STAGE_H = 120
local STATES = {
    { key = "untracked", label = "Not Tracking", tip = "What shows while you know a tracking but have not turned it on." },
}

local TEXT_OFF = "Racial and Class Tracking is off"
local TEXT_NONE = "No tracking selected"
local TEXT_HELP = "Shows an icon for each racial or class tracking you have not turned on."
local TEXT_RACIAL = "Racial Tracking"
local TEXT_CLASS = "Class Tracking"
local TEXT_RACIAL_HELP = "Reminds you to turn on your race's tracking."
local TEXT_CLASS_HELP = "Reminds you to turn on your class's tracking."
local TEXT_PICK = "Reminds you while this tracking is off."
local TEXT_NEEDS_RACIAL = "Needs Racial Tracking"
local TEXT_NEEDS_CLASS = "Needs Class Tracking"
local TEXT_INSTANCES = "Also reminds you inside instances."
local TEXT_ICON = "How big the reminder icon is."

local function When(key)
    return function()
        return TR.Enabled() and S.Get(key) and true or false
    end
end

local racialOn = When("trackRacial")
local classOn = When("trackClass")

local function Summary(store)
    if not store.Get("enabled") then return TEXT_OFF end
    local parts = {}
    if store.Get("trackRacial") then parts[#parts + 1] = ns.L(TEXT_RACIAL) end
    if store.Get("trackClass") then parts[#parts + 1] = ns.L(TEXT_CLASS) end
    if #parts == 0 then return TEXT_NONE end
    return table.concat(parts, ", ")
end

local function Sample()
    local _, race = UnitRace("player")
    local _, class = UnitClass("player")
    for i = 1, #D.RACIAL do
        if D.RACIAL[i].race == race then return D.RACIAL[i] end
    end
    for i = 1, #D.CLASS do
        if D.CLASS[i].class == class then return D.CLASS[i] end
    end
    return D.RACIAL[1]
end

local function NewPreview(stage)
    local shot = CreateFrame("Frame", nil, stage)
    shot:SetPoint("CENTER")
    Look.New(shot)
    return shot
end

local function PaintPreview(shot)
    local sample = Sample()
    Look.Fill(shot, S.Get("iconSize"), C_Spell.GetSpellTexture(sample.spell), sample.label)
end

local function PickRow(t, key, needs, why)
    return {
        key = key, field = t.key, label = t.label, toggle = true, needs = needs, why = why,
        help = TEXT_PICK,
        get = function()
            return S.Get(key)[t.key] ~= false
        end,
        set = function(on)
            local picks = {}
            local cur = S.Get(key)
            for k, v in pairs(cur) do picks[k] = v end
            picks[t.key] = nil
            if not on then picks[t.key] = false end
            S.Set(key, picks)
        end,
    }
end

local function AddMatching(rows, list, token, field)
    for i = 1, #list do
        if list[i][field] == token then rows[#rows + 1] = list[i] end
    end
end

local function Rows()
    local _, race = UnitRace("player")
    local _, class = UnitClass("player")
    local racial, classSpells = {}, {}
    AddMatching(racial, D.RACIAL, race, "race")
    AddMatching(classSpells, D.CLASS, class, "class")
    local rows = {}
    if #racial > 0 then
        rows[#rows + 1] = Group(TEXT_RACIAL)
        rows[#rows + 1] = {
            key = "trackRacial", label = TEXT_RACIAL, toggle = true, needs = TR.Enabled, why = TEXT_OFF,
            help = TEXT_RACIAL_HELP,
        }
        for i = 1, #racial do rows[#rows + 1] = PickRow(racial[i], "racialPicks", racialOn, TEXT_NEEDS_RACIAL) end
    end
    if #classSpells > 0 then
        rows[#rows + 1] = Group(TEXT_CLASS)
        rows[#rows + 1] = {
            key = "trackClass", label = TEXT_CLASS, toggle = true, needs = TR.Enabled, why = TEXT_OFF,
            help = TEXT_CLASS_HELP,
        }
        for i = 1, #classSpells do
            rows[#rows + 1] = PickRow(classSpells[i], "classPicks", classOn, TEXT_NEEDS_CLASS)
        end
    end
    rows[#rows + 1] = Group("Options")
    rows[#rows + 1] = {
        key = "inInstances", label = "Show in Dungeons and Raids", toggle = true, needs = TR.Enabled,
        why = TEXT_OFF, help = TEXT_INSTANCES,
    }
    rows[#rows + 1] = Group("Size")
    rows[#rows + 1] = {
        key = "iconSize", label = "Icon Size", slider = ICON_RANGE, needs = TR.Enabled, why = TEXT_OFF,
        help = TEXT_ICON,
    }
    local look = Settings.Look("tracking", { text = true, size = TEXT_RANGE, needs = TR.Enabled, why = TEXT_OFF })
    for i = 1, #look do rows[#rows + 1] = look[i] end
    return rows
end

local page = Settings.Page(TR.PAGE, S)

page:Card({
    id = "tracking", name = "Racial and Class Tracking", order = ORDER_TRACKING, switch = "enabled",
    help = TEXT_HELP,
    summary = Summary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = Rows,
})

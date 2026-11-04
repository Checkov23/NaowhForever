-- Plan.lua: your class's spells sorted by what stands between you and each, and what they cost.
local ns = _G.NaowhForever

local Training = ns.Training
local Ignored = Training.Ignored
local ClassSpells = Training.ClassSpells
local Price = Training.Price
local Prices = Training.Prices
local Changed = Training.Changed

local SOON = Training.SOON
local LEVEL, SPELL = Training.C.ENTRY_LEVEL, Training.C.ENTRY_SPELL

local function ForMyRace(entry, race)
    if not entry.races then return true end
    for _, r in ipairs(entry.races) do
        if r == race then return true end
    end
    return false
end

local function MySpells(race)
    local mine, after = {}, {}
    for _, entry in ipairs(ClassSpells()) do
        if ForMyRace(entry, race) then
            mine[#mine + 1] = entry
            if entry.needs then after[entry.needs] = entry[SPELL] end
        end
    end
    return mine, after
end

local function Known(mine, after)
    local known = {}
    for i = #mine, 1, -1 do
        local entry = mine[i]
        local spell = entry[SPELL]
        known[spell] = C_SpellBook.IsSpellKnown(spell) or known[after[spell]]
            or entry.replacedBy and C_SpellBook.IsSpellKnown(entry.replacedBy) or false
    end
    return known
end

local function StateOf(entry, level, known, ignored)
    if ignored[entry[SPELL]] then return "ignored" end
    if entry.talent and not C_SpellBook.IsSpellKnown(entry.talent) then return "talent" end
    if entry[LEVEL] > level + SOON then return "later" end
    if entry[LEVEL] > level then return "soon" end
    if entry.needs and not (known[entry.needs] or known[entry.needs] == nil
        and C_SpellBook.IsSpellKnown(entry.needs)) then
        return "rank"
    end
    return "now"
end

function Training.BuildSkipped(spell)
    local build = Training.Followed()
    return build ~= nil and build.skip ~= nil and build.skip[spell] == true
end

function Training.Skipped(spell)
    return Ignored()[spell] == true or Training.BuildSkipped(spell)
end

local function Skips()
    local skips = {}
    for spell in pairs(Ignored()) do skips[spell] = true end
    local build = Training.Followed()
    for spell in pairs(build and build.skip or {}) do skips[spell] = true end
    return skips
end

function Training.Plan(level)
    local _, _, race = UnitRace("player")
    local ignored = Skips()
    level = level or UnitLevel("player")
    local mine, after = MySpells(race)
    local known = Known(mine, after)
    local plan = { now = {}, rank = {}, soon = {}, later = {}, talent = {}, ignored = {}, learned = {},
        byLevel = {}, known = known, level = level }
    for _, entry in ipairs(mine) do
        local group = plan.byLevel[entry[LEVEL]]
        if not group then
            group = {}
            plan.byLevel[entry[LEVEL]] = group
        end
        group[#group + 1] = entry
        if not known[entry[SPELL]] then
            local list = plan[StateOf(entry, level, known, ignored)]
            list[#list + 1] = entry
        else
            plan.learned[#plan.learned + 1] = entry
        end
    end
    return plan
end

function Training.Weapons()
    local _, _, classID = UnitClass("player")
    local out = {}
    for _, entry in ipairs(ns.TrainingWeapons[classID] or {}) do
        if not C_SpellBook.IsSpellKnown(entry[SPELL]) then out[#out + 1] = entry end
    end
    return out
end

function Training.Total(entries)
    local prices, total = Prices(), 0
    for _, entry in ipairs(entries) do total = total + Price(entry, prices) end
    return total
end

function Training.ToSixty(plan)
    return Training.Total(plan.now) + Training.Total(plan.rank) + Training.Total(plan.soon)
        + Training.Total(plan.later)
end

function Training.SetIgnored(spell, allRanks, on)
    local ignored = Ignored()
    local name = C_Spell.GetSpellName(spell)
    for _, entry in ipairs(ClassSpells()) do
        if entry[SPELL] == spell or allRanks and C_Spell.GetSpellName(entry[SPELL]) == name then
            ignored[entry[SPELL]] = on or nil
        end
    end
    Changed()
end

-- Worth.lua: what a stat is worth to your spec, in words: its yardstick, its names and the hover card's line (CP.Worth).
local ns = _G.NaowhForever

local CP = ns.CharacterPanel
local SW = ns.StatWeights
local D = CP.Stats

local YARD = 1
local ONE_POINT, ONE_PERCENT = "1", "1%"
local PERCENT_TAIL = " %%$"
local PLAIN_FORMAT = "%.3f"
local SPEC_SHORT = "^(.-) %a+$"
local WORTH_LINE = ns.L("%s %s is worth %s %s to %s.")
local YARDSTICK_LINE = ns.L("%s is the yardstick: every other stat is weighed against it.")
local UNCOUNTED_LINE = ns.L("%s does not count it.")
local UNMEASURED_LINE = ns.L("%s weighs it %s.")
local TEXT_YOUR_SPEC = ns.L("Your Spec")
local TEXT_BEST_FOR = ns.L("BEST FOR ")

local NAME = {}
for _, stat in ipairs(SW.STATS) do NAME[stat[1]] = stat[2] end

local shortNames, titles = {}, {}

local function Plain(value)
    local text = PLAIN_FORMAT:format(value):gsub("0+$", ""):gsub("%.$", "")
    return text
end

local Worth = {}
CP.Worth = Worth
Worth.NAME, Worth.YARD = NAME, YARD

function Worth.ShortName(spec)
    if not spec then return TEXT_YOUR_SPEC end
    local short = shortNames[spec.name]
    if not short then
        short = spec.name:match(SPEC_SHORT) or spec.name
        shortNames[spec.name] = short
    end
    return short
end

function Worth.Title(short)
    local title = titles[short]
    if not title then
        title = TEXT_BEST_FOR .. short:upper()
        titles[short] = title
    end
    return title
end

function Worth.Yardstick(weights)
    if not weights then return nil end
    local heaviest
    for _, stat in ipairs(D.YARDSTICKS) do
        local weight = weights[stat] or 0
        if weight == YARD then return stat end
        if weight > 0 and (not heaviest or weight > weights[heaviest]) then heaviest = stat end
    end
    return heaviest
end

function Worth.Line(stat, weight, spec, yard, yardWeight)
    if weight <= 0 then return UNCOUNTED_LINE:format(spec) end
    if stat == yard then return YARDSTICK_LINE:format(NAME[stat]) end
    if not yard then return UNMEASURED_LINE:format(spec, Plain(weight)) end
    local name = NAME[stat] or stat
    local amount = ONE_POINT
    if D.PERCENT[stat] then
        name = name:gsub(PERCENT_TAIL, "")
        amount = ONE_PERCENT
    end
    return WORTH_LINE:format(amount, name, Plain(weight / yardWeight), NAME[yard], spec)
end

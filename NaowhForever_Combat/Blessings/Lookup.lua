-- Lookup.lua: the spells looked up by key, code and spell ID, and which ranks you have learned.
local ns = _G.NaowhForever

local B = ns.Blessings

local QUESTION = 134400

local BY_KEY, BY_CODE, FAMILY, IDS, GREATER = {}, {}, {}, {}, {}

local function Index(entry)
    BY_KEY[entry.key] = entry
    if entry.code then BY_CODE[entry.code] = entry end
    IDS[entry.key] = {}
    for _, id in ipairs(entry.ranks) do FAMILY[id] = entry.key; IDS[entry.key][id] = true end
    for _, id in ipairs(entry.greater or {}) do
        FAMILY[id] = entry.key
        IDS[entry.key][id] = true
        GREATER[id] = true
    end
end

for _, entry in ipairs(B.BLESSINGS) do entry.blessing = true; Index(entry) end
for _, entry in ipairs(B.AURAS) do Index(entry) end
Index(B.SALVATION)
Index(B.FURY)

B.BY_KEY, B.BY_CODE, B.FAMILY, B.IDS, B.GREATER = BY_KEY, BY_CODE, FAMILY, IDS, GREATER
B.QUESTION = QUESTION

function B.HighestKnown(ids)
    for i = #ids, 1, -1 do
        if C_SpellBook.IsSpellKnown(ids[i]) then return ids[i] end
    end
end

function B.Learned(entry)
    return B.HighestKnown(entry.ranks) or (entry.greater and B.HighestKnown(entry.greater))
end

function B.SpellName(key)
    local entry = BY_KEY[key]
    return entry and C_Spell.GetSpellName(entry.ranks[1]) or key
end

function B.SpellIcon(key)
    local entry = BY_KEY[key]
    return entry and C_Spell.GetSpellTexture(entry.ranks[1]) or QUESTION
end

-- SpellQueue.lua: the Spell Queue card, the game's Spell Queue Window on a slider.
local ns = _G.NaowhForever

local SPELL_QUEUE = "SpellQueueWindow"
local SPELL_QUEUE_MAX = 400
local SPELL_QUEUE_RANGE = { 0, SPELL_QUEUE_MAX, 1 }

local function SpellQueueGet()
    return tonumber(C_CVar.GetCVar(SPELL_QUEUE)) or SPELL_QUEUE_MAX
end

local function SpellQueueSet(v)
    C_CVar.SetCVar(SPELL_QUEUE, v)
end

ns.Shared.Settings.Page("QoL/Combat", ns.QoLSettings):Card({
    id = "spellQueue", name = "Spell Queue", order = 120,
    help = "How early you can press your next spell, saved by the game itself.",
    rows = {
        { label = "Spell Queue Window", slider = SPELL_QUEUE_RANGE, unit = "ms", get = SpellQueueGet, set = SpellQueueSet,
          help = "How early you can press your next spell before the current one finishes, in milliseconds. "
              .. "100 to 400 suits most: lower is more responsive, higher is more forgiving of latency. Melee "
              .. "around your ping + 100, ranged around your ping + 150." },
    },
})

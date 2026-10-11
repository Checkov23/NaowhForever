-- AurasPage.lua: the PvP Auras settings page (PvP/Auras), declared as cards.
local ns = _G.NaowhForever

local P = ns.PvP
local S = P.Settings
local SPELLS = ns.PvPSpells
local Settings = ns.Shared.Settings
local Group = Settings.Group

local OFF = ns.L("Turn on PvP")
local NEEDS_TIMER = ns.L("Needs Show Time Left")
local NEEDS_WARN = ns.L("Needs Warn Before It Ends")
local NEEDS_BUFFS = ns.L("Needs Short Buffs")
local NEEDS_FOCUS = ns.L("Needs Focus Panel")
local NEEDS_FORGE = ns.L("Needs Focus Panel and the Macros module")
local TEXT_NOTHING = ns.L("Nothing shown")
local FORGE_VIEW = "smart"
local SIZE_RANGE, WARN_RANGE, LENGTH_RANGE, MAX_RANGE = { 24, 64, 1 }, { 1, 10, 1 }, { 5, 120, 5 }, { 1, 10, 1 }

local Enabled = P.Enabled
local buffsOn = P.Needs("buffs")
local timerOn, warnOn, focusOn = P.Needs("timer"), P.Needs("warn"), P.Needs("focus")
local summaryParts = {}

local function ForgeReady()
    return focusOn() and ns.OpenMacroWindow ~= nil
end

local function OpenForgeWindow()
    ns.OpenMacroWindow(FORGE_VIEW)
end

local function OpenForge()
    ns.OpenFromOptions(OpenForgeWindow)
end

local function Summary(store)
    wipe(summaryParts)
    if store.Get("buffs") then summaryParts[#summaryParts + 1] = (ns.L("buffs up to %ds")):format(store.Get("buffLength")) end
    if store.Get("cc") then summaryParts[#summaryParts + 1] = ns.L("crowd control") end
    if store.Get("debuffs") then summaryParts[#summaryParts + 1] = ns.L("your debuffs") end
    if #summaryParts == 0 then return TEXT_NOTHING end
    return ns.L("Your target's ") .. table.concat(summaryParts, ", ") .. (store.Get("focus") and ns.L(", and your focus") or "")
end

local function SetAll(entries, prefix, value)
    return function()
        for _, entry in ipairs(entries) do S.Set(prefix .. entry.key, value) end
    end
end

local function SpellRow(entry, prefix)
    local key = prefix .. entry.key
    return { label = entry.label, help = entry.group, toggle = true, hidden = true,
        get = function() return S.Get(key) end, set = function(v) S.Set(key, v) end }
end

local function SpellRows(entries, prefix)
    local rows = {}
    for i, entry in ipairs(entries) do rows[i] = SpellRow(entry, prefix) end
    return rows
end

local page = Settings.Page("PvP/Auras", S)

page:Card({
    id = "auras", name = "PvP Auras", order = 10, switch = "auras",
    help = "Your target's short buffs, the crowd control on them and the debuffs you pick, as large icons that keep working in combat.",
    summary = Summary,
    studio = P.AurasPreview,
    rows = {
        Group("Look"),
        { key = "size", label = "Icon Size", slider = SIZE_RANGE, needs = Enabled, why = OFF },
        { key = "count", label = "Show Stacks", toggle = true, needs = Enabled, why = OFF },
        Group("Time Left"),
        { key = "timer", label = "Show Time Left", toggle = true, needs = Enabled, why = OFF },
        { key = "warn", label = "Warn Before It Ends", toggle = true, needs = timerOn, why = NEEDS_TIMER,
          help = "The time left turns yellow, then red near the end, so you see crowd control about to break." },
        { key = "warnAt", label = "Red Under", slider = WARN_RANGE, unit = "s", needs = warnOn,
          why = NEEDS_WARN, help = "The seconds left when the time turns red; it turns yellow at twice that." },
        { key = "warnBlink", label = "Blink When Red", toggle = true, needs = warnOn, why = NEEDS_WARN,
          help = "The red time left blinks, to catch your eye." },
        Group("Buffs"),
        { key = "buffs", label = "Short Buffs", toggle = true, needs = Enabled, why = OFF,
          help = "Your target's buffs that last a short while, like Divine Shield, Evasion or Sprint." },
        { key = "buffLength", label = "Up To", slider = LENGTH_RANGE, unit = "s", needs = buffsOn,
          why = NEEDS_BUFFS,
          help = "The longest a buff can last to show; longer ones like Arcane Intellect stay hidden." },
        { key = "buffMagicOnly", label = "Only Magic Buffs", toggle = true, needs = buffsOn, why = NEEDS_BUFFS,
          help = "Only buffs a dispel or purge can take off." },
        { key = "buffMax", label = "Max Buffs", slider = MAX_RANGE, needs = Enabled, why = OFF },
        { key = "absorb", label = "Show Absorb", toggle = true, needs = Enabled, why = OFF,
          help = "Before the icons, a small shield and in blue how much the shields still absorb, while one is up." },
        Group("Crowd Control"),
        { key = "cc", label = "Crowd Control", toggle = true, needs = Enabled, why = OFF,
          help = "The crowd control on your target; pick which in the Crowd Control card below." },
        { key = "ccMax", label = "Max Crowd Control", slider = MAX_RANGE, needs = Enabled, why = OFF },
        Group("Debuffs"),
        { key = "debuffs", label = "Debuffs", toggle = true, needs = Enabled, why = OFF,
          help = "The debuffs on your target you pick in the Debuffs card below, like Mortal Strike." },
        { key = "debuffMax", label = "Max Debuffs", slider = MAX_RANGE, needs = Enabled, why = OFF },
        Group("Focus"),
        { key = "focus", label = "Focus Panel", toggle = true, needs = Enabled, why = OFF,
          help = "A second panel for your focus, to keep Sap or Polymorph's time on one enemy while you fight another." },
        { label = "Focus Macro", buttonText = "Open Forge", button = OpenForge, needs = ForgeReady,
          why = NEEDS_FORGE,
          help = "NF Focus in Naowh's Forge focuses the enemy under your mouse, or your target: drag it to a bar." },
        { key = "focusName", label = "Focus Name", toggle = true, needs = focusOn, why = NEEDS_FOCUS,
          help = "Your focus's name, tinted by class, with their class icon above the panel." },
        { key = "focusBuffs", label = "Focus Short Buffs", toggle = true, needs = focusOn, why = NEEDS_FOCUS },
        { key = "focusCC", label = "Focus Crowd Control", toggle = true, needs = focusOn, why = NEEDS_FOCUS },
        { key = "focusDebuffs", label = "Focus Debuffs", toggle = true, needs = focusOn, why = NEEDS_FOCUS },
    },
})

page:Card({
    id = "crowdControl", name = "Crowd Control", order = 20,
    help = "Which crowd control shows, by ability: every rank, and the same spell from items and creatures.",
    studio = P.SpellGrid.crowdControl,
    rows = {
        SpellRows(SPELLS.crowdControl, P.CC_PREFIX),
        Group("Everything Else"),
        { key = "ccOther", label = "Other Crowd Control", toggle = true, needs = Enabled, why = OFF,
          help = "Crowd control from creatures and anything not in the grid." },
        Group("All at Once"),
        { label = "Show Every Spell", buttonText = "Show All", button = SetAll(SPELLS.crowdControl, P.CC_PREFIX, true),
          needs = Enabled, why = OFF, help = "Lights every spell in the grid." },
        { label = "Hide Every Spell", buttonText = "Hide All", button = SetAll(SPELLS.crowdControl, P.CC_PREFIX, false),
          needs = Enabled, why = OFF, help = "Dims every spell, to light only the few you want." },
    },
})

page:Card({
    id = "debuffs", name = "Debuffs", order = 30,
    help = "Which debuffs show beside crowd control: off until you light them.",
    studio = P.SpellGrid.debuffs,
    rows = {
        SpellRows(SPELLS.debuffs, P.DEBUFF_PREFIX),
        Group("Your Own"),
        { key = "debuffExtra", label = "Spell IDs", text = true, wide = true, needs = Enabled, why = OFF,
          help = "More debuffs to show by spell ID, separated by spaces or commas (Wowhead has the ID)." },
        Group("All at Once"),
        { label = "Show Every Debuff", buttonText = "Show All", button = SetAll(SPELLS.debuffs, P.DEBUFF_PREFIX, true),
          needs = Enabled, why = OFF, help = "Lights every debuff in the grid." },
        { label = "Hide Every Debuff", buttonText = "Hide All", button = SetAll(SPELLS.debuffs, P.DEBUFF_PREFIX, false),
          needs = Enabled, why = OFF, help = "Dims every debuff in the grid." },
    },
})

-- SettingsPage.lua: the Raid Debuffs settings page (Raid Debuffs/Settings), declared as cards.
local ns = _G.NaowhForever

local RD = ns.RaidDebuffs
local S = RD.Settings
local SPELLS = ns.RaidDebuffSpells
local Settings = ns.Shared.Settings
local Group = Settings.Group

local OFF = ns.L("Turn on Raid Debuffs")
local NEEDS_TIMER = ns.L("Needs Show Time Left")
local NEEDS_WARN = ns.L("Needs Warn Before It Ends")
local TEXT_SUMMARY = ns.L("%d debuffs, %s")
local TEXT_LIT, TEXT_DIMMED = ns.L("missing ones lit"), ns.L("missing ones dimmed")
local SIZE_RANGE, WARN_RANGE = { 20, 64, 1 }, { 1, 10, 1 }
local ORDER_BAR, ORDER_DEBUFFS = 10, 20
local SHOW = { { raid = "In a Raid", group = "In a Group", always = "Always" }, { "raid", "group", "always" } }

local function Enabled()
    return RD.On()
end

local function Needs(key)
    return function() return RD.On() and S.Get(key) == true end
end

local function Summary(store)
    local n = 0
    for _, entry in ipairs(SPELLS) do
        if store.Get(RD.PREFIX .. entry.key) then n = n + 1 end
    end
    return TEXT_SUMMARY:format(n, store.Get("highlightMissing") and TEXT_LIT or TEXT_DIMMED)
end

local function DebuffRows()
    local rows, group = {}, nil
    for _, entry in ipairs(SPELLS) do
        if entry.group ~= group then
            group = entry.group
            rows[#rows + 1] = Group(group)
        end
        rows[#rows + 1] = { key = RD.PREFIX .. entry.key, label = entry.label, toggle = true, needs = Enabled, why = OFF }
    end
    return rows
end

local page = Settings.Page(RD.PAGE, S)

page:Card({
    id = "bar", name = "Debuff Bar", order = ORDER_BAR,
    help = "One icon per raid debuff on your target, dimmed while it is missing, and it keeps working in combat.",
    summary = Summary,
    rows = {
        { key = "show", label = "Show", choice = SHOW, needs = Enabled, why = OFF,
          help = "When the bar shows, while you target an enemy." },
        { key = "highlightMissing", label = "Highlight Missing", toggle = true, needs = Enabled, why = OFF,
          help = "Light up the missing debuffs and fade the ones already on your target." },
        Group("Look"),
        { key = "size", label = "Icon Size", slider = SIZE_RANGE, needs = Enabled, why = OFF },
        { key = "count", label = "Show Stacks", toggle = true, needs = Enabled, why = OFF },
        Group("Time Left"),
        { key = "timer", label = "Show Time Left", toggle = true, needs = Enabled, why = OFF },
        { key = "warn", label = "Warn Before It Ends", toggle = true, needs = Needs("timer"), why = NEEDS_TIMER,
          help = "The time left turns yellow, then red near the end, so you see a debuff about to drop." },
        { key = "warnAt", label = "Red Under", slider = WARN_RANGE, unit = "s", needs = Needs("warn"),
          why = NEEDS_WARN, help = "The seconds left when the time turns red; it turns yellow at twice that." },
        { key = "warnBlink", label = "Blink When Red", toggle = true, needs = Needs("warn"), why = NEEDS_WARN,
          help = "The red time left blinks, to catch your eye." },
    },
})

page:Card({
    id = "debuffs", name = "Debuffs", order = ORDER_DEBUFFS,
    help = "Which debuffs get an icon on the bar: every rank, from any caster.",
    rows = DebuffRows(),
})

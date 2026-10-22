-- SettingsPage.lua: the Druid Mana settings page (Druid Mana/Settings), declared as cards.
local ns = _G.NaowhForever

local DM = ns.DruidMana
local S = DM.Settings
local Settings = ns.Shared.Settings
local Group = Settings.Group

local OFF = DM.DRUID and ns.L("Turn on Druid Mana") or ns.L("Only for druids")
local NEEDS_FIVE = ns.L("Needs Five Second Rule")
local NEEDS_SHIFTING = ns.L("Needs Powershifting")
local TEXT_SUMMARY = ns.L("%d by %d, %s")
local TEXT_ANY_TIME, TEXT_IN_COMBAT = ns.L("any time"), ns.L("in combat")
local WIDTH_RANGE, HEIGHT_RANGE, TEXT_RANGE = { 60, 400, 1 }, { 2, 30, 1 }, { 6, 24, 1 }
local ORDER_BAR, ORDER_ANCHOR, ORDER_FIVE, ORDER_SHIFTING = 10, 20, 30, 40
local TEXT = {
    { both = "Current / Max and Percent", values = "Current / Max", current = "Current", percent = "Percent", none = "None" },
    { "both", "values", "current", "percent", "none" },
}
local ANCHOR = { store = S, prefix = DM.PREFIX, name = "Druid Mana bar", on = DM.On, frame = DM.Frame }

local function Enabled()
    return DM.On()
end

local function Needs(key)
    return function() return DM.On() and S.Get(key) == true end
end

local function Summary(store)
    return TEXT_SUMMARY:format(store.Get("width"), store.Get("height"),
        store.Get("combatOnly") and TEXT_IN_COMBAT or TEXT_ANY_TIME)
end

local page = Settings.Page(DM.PAGE, S)

page:Card({
    id = "bar", name = "Mana Bar", order = ORDER_BAR,
    help = "Your mana while you are shapeshifted, under your player frame or wherever you put it.",
    summary = Summary,
    rows = {
        Group("Show In"),
        { key = "showCat", label = "Cat Form", toggle = true, needs = Enabled, why = OFF },
        { key = "showBear", label = "Bear Form", toggle = true, needs = Enabled, why = OFF },
        { key = "showTravel", label = "Travel Form", toggle = true, needs = Enabled, why = OFF },
        { key = "showAquatic", label = "Aquatic Form", toggle = true, needs = Enabled, why = OFF },
        { key = "showMoonkin", label = "Moonkin Form", toggle = true, needs = Enabled, why = OFF },
        { key = "showCaster", label = "Caster Form", toggle = true, needs = Enabled, why = OFF,
          help = "Also shows it when you are not shapeshifted." },
        { key = "combatOnly", label = "Only in Combat", toggle = true, needs = Enabled, why = OFF },
        Group("Size"),
        { key = "width", label = "Width", slider = WIDTH_RANGE, needs = Enabled, why = OFF },
        { key = "height", label = "Height", slider = HEIGHT_RANGE, needs = Enabled, why = OFF },
        Group("Text"),
        { key = "text", label = "Format", choice = TEXT, needs = Enabled, why = OFF },
        Settings.Look("", { text = true, size = TEXT_RANGE, bar = "Naowh Gradient", background = "alpha",
            keys = { FontSize = "textSize" }, needs = Enabled, why = OFF }),
        Group("Colors"),
        { key = "manaColor", label = "Mana Color", colour = true, needs = Enabled, why = OFF },
        { key = "warnColor", label = "Shift Cost Color", colour = true, needs = Enabled, why = OFF,
          help = "The end of the bar a shift would take." },
        { key = "missingColor", label = "Missing Mana Color", colour = true, needs = Enabled, why = OFF,
          help = "The mana you still need for a shift." },
    },
})

page:Card({
    id = "anchor", name = "Anchor", order = ORDER_ANCHOR,
    help = "Attach the bar to a unit frame, or leave it where you drag it.",
    rows = ns.Shared.Anchor.Rows(ANCHOR),
})

page:Card({
    id = "five", name = "Five Second Rule", order = ORDER_FIVE, switch = "fiveSecond",
    help = "When your mana starts coming back after a spell that costs mana.",
    rows = {
        { key = "fiveLine", label = "Line Under the Bar", toggle = true, needs = Needs("fiveSecond"), why = NEEDS_FIVE,
          help = "A thin line that runs down the five seconds." },
        { key = "fiveCountdown", label = "Countdown", toggle = true, needs = Needs("fiveSecond"), why = NEEDS_FIVE },
        { key = "regenSpark", label = "Regen Spark", toggle = true, needs = Needs("fiveSecond"), why = NEEDS_FIVE,
          help = "A soft spark at the end of the bar while your mana is coming back." },
    },
})

page:Card({
    id = "shifting", name = "Powershifting", order = ORDER_SHIFTING, switch = "powershift",
    help = "What shifting back into your form costs, and how many times you can.",
    rows = {
        { key = "shiftMark", label = "Shift Cost on the Bar", toggle = true, needs = Needs("powershift"),
          why = NEEDS_SHIFTING, help = "Shows what shifting back would take off the end of your mana." },
        { key = "shiftsLeft", label = "Shifts Left", toggle = true, needs = Needs("powershift"), why = NEEDS_SHIFTING },
        { key = "warnLow", label = "Show Missing Mana", toggle = true, needs = Needs("powershift"),
          why = NEEDS_SHIFTING, help = "Below a shift, the mana you still need shows in red after your mana." },
    },
})

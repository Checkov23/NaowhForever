-- SettingsPage.lua: the Macros settings page (Macros/Settings), declared as cards.
local ns = _G.NaowhForever

local M = ns.Macros
local S = M.Settings
local Smart = M.Smart
local Settings = ns.Shared.Settings
local Group = Settings.Group

local OPACITY_RANGE, PERCENT_SCALE = ns.Shared.Style.OPACITY_RANGE, ns.Shared.Style.PERCENT_SCALE
local ORDER_KEPT, ORDER_HEALTH, ORDER_FOOD, ORDER_EXTRA, ORDER_FOCUS, ORDER_WINDOW = 5, 20, 22, 25, 30, 40
local MACROS_OFF = ns.L("Turn on Macros")
local USED_BY_BAR = ns.L("Used by Consumable Bar")
local BAR_PAGE, BAR_CARD = "Consumable Bar/Settings", "Consumable Bar/Settings:adding"
local TEXT_KEPT = ns.L("%d of %d kept current")
local TEXT_ANNOUNCES_MARKS = ns.L("Announces and marks your focus")
local TEXT_ANNOUNCES = ns.L("Announces your focus")
local TEXT_MARKS = ns.L("Marks your focus")
local TEXT_JUST_FOCUS = ns.L("Just sets your focus")

local HEALTH_ORDER_VALUES = { stone = "Healthstone First", potion = "Potion First" }
local HEALTH_ORDER_ORDER = { "stone", "potion" }
ns.HealthOrderChoices = { values = HEALTH_ORDER_VALUES, order = HEALTH_ORDER_ORDER }
local MARKER_VALUES = { [1] = "Star", [2] = "Circle", [3] = "Diamond", [4] = "Triangle",
    [5] = "Moon", [6] = "Square", [7] = "Cross", [8] = "Skull" }
local MARKER_ORDER = { 8, 7, 6, 5, 4, 3, 2, 1 }

local On = Smart.On

local function MarkOn() return On() and S.Get("focusMark") == true end

local function HealthSummary(store)
    return HEALTH_ORDER_VALUES[store.Get("healthOrder")] or ""
end

local function FocusSummary(store)
    local announce, mark = store.Get("focusAnnounce"), store.Get("focusMark")
    if announce and mark then return TEXT_ANNOUNCES_MARKS end
    if announce then return TEXT_ANNOUNCES end
    if mark then return TEXT_MARKS end
    return TEXT_JUST_FOCUS
end

local function KeptSummary(store)
    return TEXT_KEPT:format(Smart.KeptCount(store), #Smart.list)
end

local function GoToBar()
    ns.UI.GoToSetting(BAR_PAGE, nil, BAR_CARD)
end

local function Locked() return false end
local function AlwaysOn() return true end
local function Ignore() end

local function KeptRow(key, label, help)
    if Smart.UsedByBar(key) then
        return { label = label, toggle = true, needs = Locked, why = USED_BY_BAR,
            get = AlwaysOn, set = Ignore, help = "Kept on while the Consumable Bar uses it." }
    end
    return { key = key, label = label, toggle = true, needs = On, why = MACROS_OFF, help = help }
end

local function KeptRows()
    local rows = {
        KeptRow("health", "NF Health", "Your best healthstone or healing potion."),
        KeptRow("healthstone", "NF Healthstone", "Your best healthstone alone."),
        KeptRow("healthPotion", "NF Health Potion", "Your best healing potion alone."),
        KeptRow("mana", "NF Mana", "Your best mana potion."),
        KeptRow("food", "NF Food", "Your best food and drink, conjured first."),
        KeptRow("drink", "NF Drink", "Your best drink alone, conjured first."),
        KeptRow("bandage", "NF Bandage", "Your best bandage, on yourself."),
        KeptRow("trinket1", "NF Trinket 1", "Uses your top trinket."),
        KeptRow("trinket2", "NF Trinket 2", "Uses your bottom trinket."),
        KeptRow("focus", "NF Focus", "Focuses your mouseover, or your target."),
        KeptRow("acceptPopup", "NF Accept", "Accepts the popup on screen: a summons, a resurrection, a group invite."),
    }
    for key in pairs(ns.ConsumableMacros) do
        if Smart.UsedByBar(key) then
            rows[#rows + 1] = { label = "Consumable Bar", button = GoToBar, buttonText = "Options", always = true,
                help = "Opens the Consumable Bar's settings." }
            break
        end
    end
    return rows
end

local page = Settings.Page("Macros/Settings", S)

page:Window({
    text = "Open Naowh's Forge",
    open = function() ns.OpenMacroWindow() end,
    headline = Smart.Headline,
    detail = Smart.Detail,
})

page:Card({
    id = "kept", name = "Kept Current", order = ORDER_KEPT,
    help = "The macros the addon writes and keeps up to date for you, out of combat. Switch one on here, "
        .. "or take it to your bars from Smart Macros in Naowh's Forge.",
    summary = KeptSummary,
    rows = KeptRows,
    watch = { ns.QoLSettings },
})

page:Card({
    id = "health", name = "Health Macro", order = ORDER_HEALTH,
    help = "NF Health uses the best healthstone or healing potion in your bags. Switch it on in Kept Current.",
    summary = HealthSummary,
    rows = {
        { key = "healthOrder", label = "Health Priority", choice = { HEALTH_ORDER_VALUES, HEALTH_ORDER_ORDER },
          needs = On, why = MACROS_OFF,
          help = "Which the macro uses first when you carry both: a healthstone or a healing potion." },
    },
})

page:Card({
    id = "food", name = "Food Macro", order = ORDER_FOOD,
    help = "NF Food uses the best food and drink in your bags. Switch it on in Kept Current.",
    rows = {
        { key = "foodOnly", label = "Food Only", toggle = true, needs = On, why = MACROS_OFF,
          help = "NF Food uses only food, and NF Drink is the one for drink." },
    },
})

local EXTRA_HELP = "Lines added after the macro's own. Write \\n between lines, as in "
    .. "/use [@mouseover,help][]Holy Light\\n/cqs. Left out, with a message, if the macro would pass 255 characters "
    .. "or the lines run a script."

local function ExtraRows()
    local rows = {}
    for _, m in ipairs(Smart.list) do
        if Smart.bag[m.key] then
            rows[#rows + 1] = { key = m.key .. "Extra", label = m.name, text = true, wide = true, needs = On,
                why = MACROS_OFF, help = EXTRA_HELP }
        end
    end
    return rows
end

page:Card({
    id = "extra", name = "Extra Lines", order = ORDER_EXTRA,
    help = "Add your own lines to the bag macros. They are kept after the item, whatever is in your bags.",
    rows = ExtraRows(),
})

page:Card({
    id = "focus", name = "Focus Macro", order = ORDER_FOCUS,
    help = "NF Focus focuses your mouseover, or your target. Switch it on in Kept Current.",
    summary = FocusSummary,
    rows = {
        Group("Announce"),
        { key = "focusAnnounce", label = "Announce Focus", toggle = true, needs = On, why = MACROS_OFF,
          help = "Tells your group what you focused." },
        Group("Marker"),
        { key = "focusMark", label = "Mark Focus", toggle = true, needs = On, why = MACROS_OFF,
          help = "Puts a raid marker on your focus. Pressing the macro again on the same focus clears the marker." },
        { key = "focusMarker", label = "Focus Marker", choice = { MARKER_VALUES, MARKER_ORDER }, needs = MarkOn,
          why = "Needs Mark Focus", help = "The raid marker Mark Focus puts on your focus." },
    },
})

page:Card({
    id = "window", name = "Window", order = ORDER_WINDOW,
    help = "Naowh's Forge, Macros' own window: the macros kept current, and Naowh's library.",
    search = "import export macro strings",
    rows = {
        { key = "windowAlpha", label = "Window Opacity", slider = OPACITY_RANGE,
          unit = "%", scale = PERCENT_SCALE, help = "How solid the window is, in percent. Also on its title bar." },
    },
})

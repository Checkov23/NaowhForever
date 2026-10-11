-- SettingsPage.lua: the Action Bars settings page (Action Bars/Settings), declared as cards.
local ns = _G.NaowhForever

local A = ns.ActionBars
local S = A.Settings
local Sets = ns.ActionBarSets
local Settings = ns.Shared.Settings

local OPACITY_RANGE, PERCENT_SCALE = ns.Shared.Style.OPACITY_RANGE, ns.Shared.Style.PERCENT_SCALE
local ORDER_IMPORTING, ORDER_WINDOW = 10, 20
local BARS_OFF = ns.L("Turn on Action Bars")
local TEXT_HIGHEST, TEXT_SAVED = ns.L("Highest ranks"), ns.L("Saved ranks")
local TEXT_MACROS, TEXT_KEYBINDS = ns.L("macros"), ns.L("keybinds")
local TEXT_NONE = ns.L("None")
local TEXT_FILLS, TEXT_SAVES = ns.L("fills in later"), ns.L("saves on logout")

local On = A.On

local function AutoImportChoices()
    local values, order = { [""] = TEXT_NONE }, { "" }
    for _, name in ipairs(A.SortedNames()) do
        values[name] = name
        order[#order + 1] = name
    end
    return values, order
end

local function ImportingSummary(store)
    local parts = { store.Get("highestRank") and TEXT_HIGHEST or TEXT_SAVED }
    if store.Get("importMacros") then parts[#parts + 1] = TEXT_MACROS end
    if store.Get("importBindings") then parts[#parts + 1] = TEXT_KEYBINDS end
    if store.Get("fillLater") then parts[#parts + 1] = TEXT_FILLS end
    if store.Get("saveOnLogout") then parts[#parts + 1] = TEXT_SAVES end
    return table.concat(parts, ", ")
end

local page = Settings.Page("Action Bars/Settings", S)

page:Window({
    text = "Open Action Bars",
    open = function() ns.OpenActionBarsWindow() end,
    headline = Sets.Headline,
    detail = Sets.Detail,
})

page:Card({
    id = "importing", name = "Importing", order = ORDER_IMPORTING,
    help = "What a saved set brings back when you import it. Sets are saved and imported from the Action "
        .. "Bars window, out of combat.",
    search = "/nf bars nf bars /nfbars nfbars save restore import test delete list /nf ab nf ab",
    summary = ImportingSummary,
    rows = {
        { key = "highestRank", label = "Highest Rank", toggle = true, needs = On, why = BARS_OFF,
          help = "Imports the highest rank you know of each spell instead of the rank that was saved. When off, a "
              .. "rank you no longer have still falls back to your highest." },
        { key = "importMacros", label = "Import Macros", toggle = true, needs = On, why = BARS_OFF,
          help = "Makes the set's macros that this character does not have. A macro you already have, by name "
              .. "and text or by text alone, is used as it is: never copied twice or changed." },
        { key = "importBindings", label = "Import Keybinds", toggle = true, needs = On, why = BARS_OFF,
          help = "Binds every key the set has bound. Keys the set leaves free keep what they do here." },
        { key = "fillLater", label = "Fill In As You Learn", toggle = true, needs = On, why = BARS_OFF,
          help = "A spell an import could not place because you do not know it yet goes into its saved slot "
              .. "when you learn it, unless you have put something else there." },
        { label = "Import on New Character", choice = AutoImportChoices, get = A.AutoImportName,
          set = A.SetAutoImport, needs = On, why = BARS_OFF,
          help = "For your class: imports this set once on a new character, at level 1 with no experience yet." },
        { key = "saveOnLogout", label = "Save on Logout", toggle = true, needs = On, why = BARS_OFF,
          help = "When you log out, the set this character saved last is saved again with your bars, "
              .. "macros and keybinds as they are." },
    },
})

page:Card({
    id = "window", name = "Window", order = ORDER_WINDOW,
    help = "Action Bars' own window, with your class's saved sets.",
    rows = {
        { key = "windowAlpha", label = "Window Opacity", slider = OPACITY_RANGE,
          unit = "%", scale = PERCENT_SCALE, help = "How solid the window is, in percent. Also on its title bar." },
    },
})

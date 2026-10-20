-- SettingsPage.lua: the Action Bars settings page (Action Bars/Settings), declared as cards.
local ns = _G.NaowhForever

local A = ns.ActionBars
local S = A.Settings
local Sets = ns.ActionBarSets
local Settings = ns.Shared.Settings

local ORDER_IMPORTING, ORDER_NEW_SPELLS = 10, 20
local AUTO_PUSH, PUSH_OFF, PUSH_ON = "AutoPushSpellToActionBar", "0", "1"
local BARS_OFF = ns.L("Turn on Action Bars")
local TEXT_HIGHEST, TEXT_SAVED = ns.L("Highest ranks"), ns.L("Saved ranks")
local TEXT_MACROS, TEXT_KEYBINDS = ns.L("macros"), ns.L("keybinds")
local TEXT_NONE = ns.L("None")
local TEXT_FILLS, TEXT_SAVES = ns.L("fills in later"), ns.L("saves on logout")

local On = A.On

local function PushStopped()
    return C_CVar.GetCVar(AUTO_PUSH) == PUSH_OFF
end

local function StopPush(on)
    C_CVar.SetCVar(AUTO_PUSH, on and PUSH_OFF or PUSH_ON)
end

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

if A.OLD_COPY then return end

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
    id = "newSpells", name = "New Spells", order = ORDER_NEW_SPELLS,
    help = "What the game does with a spell you have just learned.",
    search = "auto push spells action bar spellbook learned",
    rows = {
        { label = "Stop Auto Push Spells to Bars", toggle = true, get = PushStopped, set = StopPush,
          help = "Keeps newly learned spells in your spellbook instead of on your bars." },
    },
})

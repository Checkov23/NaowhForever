-- SettingsPage.lua: the Action Bars settings page (Action Bars/Settings), declared as cards.
local ns = _G.NaowhForever

local A = ns.ActionBars
local S = A.Settings
local Settings = ns.Shared.Settings

local ORDER_IMPORTING, ORDER_AUTO_LOAD, ORDER_NEW_SPELLS = 10, 15, 20
local LEVEL_RANGE = { A.C.FIRST_LOAD_LEVEL, 60, 1 }
local AUTO_PUSH, PUSH_OFF, PUSH_ON = "AutoPushSpellToActionBar", "0", "1"
local BARS_OFF = ns.L("Turn on Action Bars")
local TEXT_HIGHEST, TEXT_SAVED = ns.L("Highest ranks"), ns.L("Saved ranks")
local TEXT_MACROS, TEXT_KEYBINDS = ns.L("macros"), ns.L("keybinds")
local TEXT_NONE = ns.L("None")
local TEXT_FILLS, TEXT_SAVES = ns.L("fills in later"), ns.L("saves on logout")
local TEXT_AUTO_OFF = ns.L("Off")
local TEXT_IN_DUNGEONS, TEXT_IN_BATTLEGROUNDS = ns.L("in dungeons"), ns.L("in battlegrounds")
local TEXT_AT_LEVEL = ns.L("at level %d")

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

local function RuleGet(key)
    return function() return A.AutoLoad.Rule(key) or "" end
end

local function RuleSet(key)
    return function(value) A.AutoLoad.SetRule(key, value ~= "" and value or nil) end
end

local function AutoLoadSummary()
    local Rule = A.AutoLoad.Rule
    local parts = {}
    if Rule("dungeon") then parts[#parts + 1] = TEXT_IN_DUNGEONS end
    if Rule("battleground") then parts[#parts + 1] = TEXT_IN_BATTLEGROUNDS end
    if Rule("levelSet") then parts[#parts + 1] = TEXT_AT_LEVEL:format(A.AutoLoad.Level()) end
    return #parts > 0 and table.concat(parts, ", ") or TEXT_AUTO_OFF
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

page:Card({
    id = "importing", name = "Importing", order = ORDER_IMPORTING,
    help = "What a saved set brings back when you import it. Sets are saved and imported from the Bar Sets "
        .. "tab, out of combat.",
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
    id = "autoLoad", name = "Load on Its Own", order = ORDER_AUTO_LOAD,
    help = "Loads a set by itself in an instance or at a level, after backing up your bars.",
    search = "auto load swap dungeon raid battleground instance level",
    summary = AutoLoadSummary,
    rows = {
        { label = "Entering a Dungeon or Raid", choice = AutoImportChoices, get = RuleGet("dungeon"),
          set = RuleSet("dungeon"), needs = On, why = BARS_OFF, help = "Loads this set when you enter a dungeon or raid." },
        { label = "Joining a Battleground", choice = AutoImportChoices, get = RuleGet("battleground"),
          set = RuleSet("battleground"), needs = On, why = BARS_OFF, help = "Loads this set when you join a battleground." },
        { label = "Put Back on Leaving", toggle = true, needs = On, why = BARS_OFF,
          get = function() return A.AutoLoad.Rule("back") ~= false end,
          set = function(on) A.AutoLoad.SetRule("back", on and nil or false) end,
          help = "When you leave, the bars you had before the instance come back." },
        { label = "On Reaching a Level", choice = AutoImportChoices, get = RuleGet("levelSet"),
          set = RuleSet("levelSet"), needs = On, why = BARS_OFF, help = "Loads this set once, at the level below." },
        { label = "Level", slider = LEVEL_RANGE, needs = On, why = BARS_OFF,
          get = function() return A.AutoLoad.Level() end,
          set = function(level) A.AutoLoad.SetRule("level", level) end,
          help = "The level On Reaching a Level loads its set at." },
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

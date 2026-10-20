-- Run with Lua 5.1 from the repository root: the Action Bars page's New Spells card, which turns the game's
-- AutoPushSpellToActionBar setting off and back on.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local cvars = { AutoPushSpellToActionBar = "1" }
local cards = {}
local page = {
    Window = function() end,
    Card = function(_, spec) cards[spec.id] = spec end,
}
local ns = {
    L = function(text) return text end,
    ActionBars = { Settings = {}, On = function() return true end, SortedNames = function() return {} end },
    ActionBarSets = {},
    Shared = { Settings = { Page = function() return page end } },
}
local env = setmetatable({
    _G = { NaowhForever = ns },
    C_CVar = {
        GetCVar = function(name) return cvars[name] end,
        SetCVar = function(name, value) cvars[name] = value end,
    },
}, { __index = _G })
local chunk = assert(loadfile("NaowhForever_Utilities/ActionBars/UI/SettingsPage.lua"))
setfenv(chunk, env)
chunk()

local card = cards.newSpells
check("the page has a New Spells card after Importing", card and cards.importing and card.order > cards.importing.order)
local row = card.rows[1]
check("its one row is a toggle on the game's setting, with no saved key", #card.rows == 1 and row.toggle
    and row.key == nil and row.get and row.set)
check("off while the game pushes new spells", row.get() == false)
row.set(true)
check("on stops the push", cvars.AutoPushSpellToActionBar == "0" and row.get() == true)
row.set(false)
check("off puts the push back", cvars.AutoPushSpellToActionBar == "1" and row.get() == false)
cvars.AutoPushSpellToActionBar = "0"
check("a push stopped before reads as on", row.get() == true)

print(("test-action-bars-new-spells: %d checks passed"):format(checks))

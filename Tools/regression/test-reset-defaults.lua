-- Regression: the Profiles page's Setups card is a Setup dropdown of the presets (ns.PRESETS). Picking one
-- asks, then puts the profile in use to it: every module's settings and positions, keeping the
-- reminders' store and what this player answered about EllesmereUI's windows, telling the character and
-- inspect panels so they swap back, remembering which it is, and offering the reload. Hovering
-- it lists what each other preset turns on and off, read from the modules' and the feature
-- cards' switches.
-- Run from the repo root: lua5.1 Tools/regression/test-reset-defaults.lua
local passed = 0
local function check(name, ok)
    if not ok then error("FAIL " .. name, 2) end
    passed = passed + 1
end

local function Copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = Copy(v) end
    return out
end

local root = {
    qol = { characterPanel = true, fastLoot = false, characterPanelAsked = true, characterPanelTookOver = true,
        lootFeedPos = { point = "TOP", x = 1, y = 2 } },
    topBar = { use24h = false, extra = 5 },
    tankReminder = { leadTime = 9 },
    oldModule = { x = 1 },
}
local PRESETS = {
    newInstall = "minimalist",
    order = { "minimalist", "recommended" },
    minimalist = { name = "Minimalist", about = "Almost everything off.", profile = {
        qol = { characterPanel = false, lootFeed = false, preset = "minimalist",
            lootFeedPos = { point = "CENTER", x = 0, y = -124 } },
        topBar = { use24h = true },
        threatMeter = { enabled = false },
        auraBuffs = { iconSize = 48 },
    }, account = {} },
    recommended = { name = "Recommended", about = "Naowh's setup.", profile = {
        qol = { lootFeed = true, preset = "recommended" },
    }, account = {} },
}
local QOL_DEFAULTS = { characterPanel = true, inspectPanel = true, lootFeed = false }
local sets = {}
local S = { key = "qol" }
function S.Get(k)
    local v = root.qol and root.qol[k]
    if v == nil then return QOL_DEFAULTS[k] end
    return v
end
function S.Default(k) return QOL_DEFAULTS[k] end
function S.Set(k, v)
    root.qol[k] = v
    sets[#sets + 1] = k .. "=" .. tostring(v)
end
local pages = { ["BiS List/Character"] = { cards = {
    characterPanel = { name = "Character Panel", switch = "characterPanel", store = S },
    lootFeed = { name = "Loot Feed", switch = "lootFeed", store = S },
    custom = { name = "Not A Switch", switch = { get = function() return true end }, store = S },
} } }
local T = { key = "threatMeter" }
function T.Default(k) return k == "enabled" or nil end
function T.Get(k)
    local v = root.threatMeter and root.threatMeter[k]
    if v == nil then return T.Default(k) end
    return v
end
local card, asked, reload
local account = {}
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    QoLSettings = S, PRESETS = PRESETS, AccountSettings = function() return account end,
    ModuleSwitches = function() return { { name = "Threat Meter", store = T, key = "enabled" } } end,
    PROFILE_OWN = { qol = { "characterPanelAsked", "characterPanelTookOver", "inspectPanelAsked", "inspectPanelTookOver" } },
    SettingsRoot = function() return root end,
    Confirm = function(text, yes) asked = text; yes() end,
    ConfirmReload = function(text) reload = text end,
    Color = function(_, text) return text end,
    SETUPS_PAGE = "Profiles/Setups",
    Shared = { Settings = { pages = pages, Page = function(key)
        return { Card = function(_, c) c.page = key; card = c end }
    end } },
}
local env = setmetatable({ _G = { NaowhForever = ns }, CopyTable = Copy }, { __index = _G })
for _, path in ipairs({ "Core/Profiles/Positions.lua", "Core/Profiles/Setups.lua", "Core/Profiles/SetupsCard.lua" }) do
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk()
end

local row = card and card.rows[1]
check("the card sits on the Profiles page with the Setup dropdown first", card.page == "Profiles/Setups" and #card.rows == 4
    and row.label == "Setup" and row.always == true and row.choice[2] == PRESETS.order)
local keep, tailor, before = card.rows[2], card.rows[3], card.rows[4]
check("then Keep My Positions, a switch saved for the account and on to start", keep.label == "Keep My Positions"
    and keep.toggle == true and keep.key == nil and keep.get() == true)
check("then Onboarding, which opens the onboarding", tailor.label == "Onboarding" and tailor.buttonText == "Start")
local opened = false
ns.ShowSetup = function() opened = true end
tailor.button()
check("Start opens the onboarding", opened)
check("Before Onboarding stays hidden with nothing saved", before.label == "Before Onboarding" and before.hidden() == true)
local restored = false
ns.Setup = { CanRestore = function() return true end, Restore = function() restored = true; return true end }
check("it shows once the onboarding saved your settings", before.hidden() == false)
before.button()
check("Restore asks first, puts them back and offers the reload", asked and asked:find("before the onboarding", 1, true)
    and restored and reload ~= nil)
asked, reload, ns.Setup = nil, nil, nil
check("its choices are the presets by name", row.choice[1].minimalist == "Minimalist"
    and row.choice[1].recommended == "Recommended")
check("a profile no preset was applied to reads Custom", row.get() == "custom" and card.summary() == "Custom")
local tip = row.tip()
check("hovering lists what each preset turns on and off against yours now, modules too",
    tip:find("Minimalist turns off: Character Panel, Threat Meter", 1, true) ~= nil
    and tip:find("Recommended turns on: Loot Feed", 1, true) ~= nil
    and not tip:find("Not A Switch", 1, true))
local rewards, ignore = { [123] = 456 }, { [6948] = true }
root.qol.questRewards, root.qol.bagSpaceIgnore = rewards, ignore
root.auraBuffs = root.auraBuffs or {}
root.auraBuffs.campHiddenBonuses = { [1] = true }
root.unlockMode = { layouts = { Raid = {} }, hidden = { Loot = true } }
keep.set(false)
row.set("minimalist")
check("picking one asks first, naming it", asked and asked:find("Minimalist", 1, true)
    and asked:find("Cannot be undone", 1, true) and asked:find("saved picks stay", 1, true))
check("saved quest rewards and the Bag Space ignore list stay", root.qol.questRewards == rewards
    and root.qol.bagSpaceIgnore == ignore)
check("hidden campfire bonuses and HUD layouts stay", root.auraBuffs.campHiddenBonuses[1] == true and root.unlockMode.layouts.Raid ~= nil)
check("the rest of the HUD Editor's state follows the preset", root.unlockMode.hidden == nil)
check("every module to the preset", root.qol.fastLoot == nil and root.topBar.use24h == true
    and root.topBar.extra == nil and root.auraBuffs.iconSize == 48 and root.oldModule == nil)
check("positions too", root.qol.lootFeedPos.point == "CENTER" and root.qol.lootFeedPos.y == -124)
check("the reminders' store kept", root.tankReminder.leadTime == 9)
check("what you answered about EllesmereUI's windows kept", root.qol.characterPanelAsked == true
    and root.qol.characterPanelTookOver == true)
check("the character panel told it changed, the inspect panel not", #sets == 1 and sets[1] == "characterPanel=false")
check("a reload offered", reload and reload:find("Minimalist", 1, true))
asked = nil
keep.set(true)
root.qol.lootFeedPos, root.unlockMode.hidden = { point = "TOP", x = 1, y = 2 }, { Loot = true }
row.set("minimalist")
check("with Keep My Positions on, the ask says your positions stay", asked and asked:find("Your positions", 1, true))
check("and your frames and HUD Editor state stay where they were", root.qol.lootFeedPos.point == "TOP"
    and root.unlockMode.hidden.Loot == true and root.unlockMode.layouts.Raid ~= nil)
keep.set(false)
check("the dropdown and the card now read Minimalist", row.get() == "minimalist" and card.summary() == "Minimalist")
check("and the hover leaves out the one you have", not row.tip():find("Minimalist", 1, true)
    and row.tip():find("Recommended turns on: Loot Feed, Character Panel", 1, true) == nil
    and row.tip():find("Recommended turns on: Character Panel, Loot Feed", 1, true) ~= nil)
check("a module a preset left off reads as turned back on by the other",
    row.tip():find("Loot Feed, Threat Meter", 1, true) ~= nil)
root.qol.lootFeedPos.y = 5
check("a copy: the preset itself untouched", PRESETS.minimalist.profile.qol.lootFeedPos.y == -124)
row.set("recommended")
check("another preset swaps it all again", root.qol.lootFeed == true and root.topBar == nil
    and root.qol.lootFeedPos == nil and root.tankReminder.leadTime == 9 and row.get() == "recommended")
check("and the character panel told it is back on", sets[#sets] == "characterPanel=true")
check("a choice that is no preset does nothing", pcall(row.set, "custom") and row.get() == "recommended")

print(("test-reset-defaults: %d checks passed"):format(passed))

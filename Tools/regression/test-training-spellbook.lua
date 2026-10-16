-- Run with Lua 5.1 from the repository root: the Training Planner's Spellbook Tab (UI/Spellbook.lua).
-- Off by default and free while off: no frames, no hooks, no waiting on the spellbook addon. Turned on,
-- it hooks the load-on-demand spellbook once it loads, and its tab and panel follow the book: shown with
-- it, gone with it. The panel lists what you can train now and in the next levels, without the spells
-- the build you follow skips, and names your trainer.
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local NOTHING = function() end
local frames = {}
local Frame
local METHODS = {
    SetScript = function(f, script, fn) f.scripts[script] = fn end,
    HookScript = function(f, script, fn)
        f.hooks = (rawget(f, "hooks") or 0) + 1
        local old = f.scripts[script]
        f.scripts[script] = old and function(...) old(...); fn(...) end or fn
    end,
    SetText = function(f, text) f.text = text end,
    GetText = function(f) return rawget(f, "text") or "" end,
    Show = function(f)
        local was = rawget(f, "shown")
        f.shown = true
        if was == false and f.scripts.OnShow then f.scripts.OnShow(f) end
    end,
    Hide = function(f)
        local was = rawget(f, "shown") ~= false
        f.shown = false
        if was and f.scripts.OnHide then f.scripts.OnHide(f) end
    end,
    SetShown = function(f, shown) f.shown = shown and true or false end,
    IsShown = function(f) return rawget(f, "shown") ~= false end,
    IsVisible = function(f)
        local parent = rawget(f, "parent")
        return rawget(f, "shown") ~= false and (parent == nil or parent:IsVisible())
    end,
    CreateTexture = function(f) return Frame(f) end,
}
local META = { __index = function(_, key)
    if METHODS[key] then return METHODS[key] end
    if type(key) == "string" and key:find("^%u") then return NOTHING end
end }
Frame = function(parent)
    local f = setmetatable({ scripts = {}, parent = parent }, META)
    frames[#frames + 1] = f
    return f
end

local WHITE = { r = 1, g = 1, b = 1 }
local settings, listeners = {}, {}
local timers, waiting, waypoint = {}, {}, nil
local account = {}
local followed
local combat = false

local UI = {
    RefreshPage = NOTHING,
    ModuleSettings = function(_, defaults)
        local S = {}
        function S.Get(k) if settings[k] == nil then return defaults[k] end return settings[k] end
        function S.Set(k, v)
            settings[k] = v
            for _, fn in ipairs(listeners) do fn(k) end
        end
        function S.OnChange(fn) listeners[#listeners + 1] = fn end
        return S
    end,
}
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    MEDIA = dofile("Tools/regression/core_media.lua"),
    Shared = { Style = dofile("Tools/regression/shared_style.lua") },
    THEME = setmetatable({}, { __index = function() return WHITE end }),
    UI = UI,
    Color = function(_, text) return tostring(text) end,
    Font = function(parent) return Frame(parent) end,
    Solid = function(parent) return Frame(parent) end,
    Border = function(parent) return { SetColor = NOTHING, _frame = Frame(parent) } end,
    Hairline = NOTHING,
    PixelInset = NOTHING,
    Tooltip = NOTHING,
    AccentBorder = function(b) return b end,
    Button = function(parent, text, _, _, onClick)
        local b = Frame(parent)
        b.text, b._onClick = text, onClick
        b.scripts.OnClick = function() b._onClick() end
        return b
    end,
    SetButtonText = function(b, text) b.text = text end,
    AccountSettings = function() return account end,
    TownNPCs = { [1453] = { { 38.4, 79.4, "class", "Elsharin", "Mage Trainer", "MAGE", "A" } } },
    TownCapitals = { [1453] = true },
    PlaceWaypointRoute = function(_, stops) waypoint = stops[1][1] end,
    OpenTrainingWindow = NOTHING,
    Apply = NOTHING,
    -- { level, spellID, cost, flags }: Fireball's ranks, then the rest.
    TrainingData = { [8] = {
        { 1, 133, 0 }, { 6, 143, 100, needs = 133 }, { 8, 5143, 200 }, { 10, 2136, 300 },
        { 12, 145, 600, needs = 143 }, { 14, 5144, 1500, needs = 5143 }, { 14, 1460, 900 }, { 20, 1953, 2000 },
    } },
}

local known = { [133] = true }
local env = setmetatable({
    NaowhForever = ns,
    UIParent = Frame(),
    GameTooltip = Frame(),
    CreateFrame = function(_, _, parent) return Frame(parent) end,
    hooksecurefunc = function(t, key, fn)
        local old = t[key]
        t[key] = function(...) old(...); fn(...) end
    end,
    InCombatLockdown = function() return combat end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    EventUtil = { ContinueOnAddOnLoaded = function(name, fn) waiting[#waiting + 1] = { name, fn } end },
    UnitClass = function() return "Mage", "MAGE", 8 end,
    UnitRace = function() return "Human", "Human", 1 end,
    UnitLevel = function() return 12 end,
    UnitName = function() return "Me" end,
    GetRealmName = function() return "Realm" end,
    UnitFactionGroup = function() return "Alliance" end,
    GetProfessions = NOTHING,
    CreateVector2D = NOTHING,
    C_Map = { GetBestMapForUnit = NOTHING, GetWorldPosFromMapPos = NOTHING,
        GetMapInfo = function() return { name = "Stormwind City" } end },
    C_SpellBook = { IsSpellKnown = function(id) return known[id] == true end },
    C_Spell = {
        GetSpellName = function(id) return "Spell " .. id end,
        GetSpellTexture = function() return 1 end,
        GetSpellSubtext = function() return "Rank 1" end,
        GetSpellDescription = function() return "Deals 10 Fire damage." end,
        RequestLoadSpellData = NOTHING,
    },
}, { __index = _G })
env._G = env

local DIR = "NaowhForever_Training/"
Load({ "Core/Features.lua", DIR .. "Training.lua", DIR .. "Constants.lua", DIR .. "Plan.lua", DIR .. "Upgrades.lua",
    DIR .. "Coins.lua", DIR .. "Route.lua", DIR .. "View/Style.lua", DIR .. "View/Rows.lua" }, env)
ns.Training.Followed = function() return followed end
-- The game's book: PlayerSpellsFrame, the window, holds the SpellBookFrame tab.
local window = Frame()
window.SpellBookFrame = Frame(window)
window.SpellBookFrame.shown = false

local before = #frames
Load({ DIR .. "UI/Spellbook.lua" }, env)
local boot = frames[#frames]
check("loading it makes only the login frame", #frames == before + 1)

local function RunTimers()
    while timers[1] do table.remove(timers, 1)() end
end

local function Login()
    boot.scripts.OnEvent(boot, "PLAYER_LOGIN")
    ns.Apply()
    RunTimers()
end

-- Its window shown or hidden shows or hides the book in it, as the game's frames do.
local function OpenBook()
    window.shown = true
    if window.SpellBookFrame:IsShown() then window.SpellBookFrame.scripts.OnShow(window.SpellBookFrame) end
end

local function CloseBook()
    window.shown = false
    if window.SpellBookFrame:IsShown() then window.SpellBookFrame.scripts.OnHide(window.SpellBookFrame) end
end

local function Ours()
    local tab, panel
    for i = before + 2, #frames do
        local f = frames[i]
        if rawget(f, "text") and f.text:find("^Trainable") and f.scripts.OnClick then tab = f end
        if rawget(f, "body") and rawget(f, "trainer") then panel = f end
    end
    return tab, panel
end

local function Listed(panel)
    local ids = {}
    for i = before + 2, #frames do
        local f = frames[i]
        if rawget(f, "entry") and f.parent == panel.body and f:IsShown() then ids[#ids + 1] = f.entry[2] end
    end
    return table.concat(ids, " ")
end

check("it is off by default", ns.FEATURES.training.spellbook == false and ns.TrainingSettings.Get("spellbook") == false)
Login()
env.PlayerSpellsFrame = window
window.SpellBookFrame:Show()
RunTimers()
check("off, it builds nothing", #frames == before + 1)
check("hooks nothing", rawget(window.SpellBookFrame, "hooks") == nil)
check("and does not wait on the spellbook addon", #waiting == 0)

env.PlayerSpellsFrame = nil
window.SpellBookFrame:Hide()
ns.TrainingSettings.Set("spellbook", true)
check("turned on, it waits for the load-on-demand spellbook", #waiting == 1
    and waiting[1][1] == "Blizzard_PlayerSpells")
RunTimers()
check("and builds nothing before the book opens", #frames == before + 1)
env.PlayerSpellsFrame = window
waiting[1][2]()
check("once loaded, it post-hooks the book's show and hide", window.SpellBookFrame.hooks == 2)
RunTimers()
check("with the book shut, still nothing is built", #frames == before + 1)

followed = { skip = { [143] = true } }
window.SpellBookFrame:Show()
check("the book's show draws a frame later, from a timer", Ours() == nil and #timers == 1)
RunTimers()
local tab, panel = Ours()
check("opening the book shows the tab and the panel", tab and tab:IsShown() and panel and panel:IsShown())
check("the tab counts what you can train now", tab.text == "Trainable (2)")
check("the panel lists now, then each of the next levels, without the rank the build skips, the rank that "
    .. "waits on it or later levels", Listed(panel) == "5143 2136 5144 1460")
check("it names your nearest trainer", panel.trainer:GetText() == "Nearest trainer: Elsharin, Stormwind City")
panel.waypoint.scripts.OnClick()
check("and Waypoint marks it", waypoint == "Elsharin")

ns.Training.SetIgnored(5143, false, true)
RunTimers()
check("a spell you skip leaves the list", Listed(panel) == "2136 5144 1460" and tab.text == "Trainable (1)")

tab.scripts.OnClick()
RunTimers()
check("the tab folds the panel away and keeps itself", tab:IsShown() and not panel:IsShown()
    and ns.TrainingSettings.Get("spellbookOpen") == false)
tab.scripts.OnClick()
RunTimers()
check("and opens it again", panel:IsShown())

CloseBook()
check("closing the book hides both", not tab:IsShown() and not panel:IsShown())
OpenBook()
RunTimers()
check("opening it again shows them", tab:IsShown() and panel:IsShown())
window.SpellBookFrame:Hide()
check("the talents in the same window are not the book", not tab:IsShown() and not panel:IsShown())
window.SpellBookFrame:Show()
RunTimers()

combat = true
CloseBook()
OpenBook()
RunTimers()
check("in combat it still shows: the book has no secure frames", tab:IsShown() and panel:IsShown())
combat = false

ns.TrainingSettings.Set("enabled", false)
check("the planner turned off hides it", not tab:IsShown() and not panel:IsShown())
CloseBook()
OpenBook()
check("and the book opening does no work", #timers == 0 and not tab:IsShown())
ns.TrainingSettings.Set("enabled", true)
RunTimers()
check("the planner back on shows it with the book", tab:IsShown() and panel:IsShown())

ns.TrainingSettings.Set("spellbook", false)
check("switched off, it hides", not tab:IsShown() and not panel:IsShown())
CloseBook()
OpenBook()
ns.Training.Changed()
check("and its hooks do no work", #timers == 0 and not tab:IsShown() and #waiting == 1)

print(("test-training-spellbook: %d checks passed"):format(checks))

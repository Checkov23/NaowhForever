-- /nf help, /nf move and the module commands (Core/Commands.lua), loaded with the real module list.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local function Fixture(badges)
    local s = { printed = {}, opened = {}, barArgs = {}, abArgs = {}, toggled = 0, unlock = false }
    local ns = {
        UI = {},
        FEATURE_BADGES = badges, BADGES_LIVE = 1,
        L = function(text) return text end,
        Print = function(msg) s.printed[#s.printed + 1] = msg end,
        ToggleOptionsWindow = function() s.toggled = s.toggled + 1 end,
        IsUnlockModeActive = function() return s.unlock end,
        ShowUnlockMode = function() s.unlock = true end,
        HideUnlockMode = function() s.unlock = false end,
        ActionBarsCommand = function(text) s.barArgs[#s.barArgs + 1] = text end,
        ActionBarsImportCommand = function(text) s.abArgs[#s.abArgs + 1] = text end,
    }
    local env = setmetatable({
        NaowhForever = ns,
        SlashCmdList = {},
        print = function(msg) s.printed[#s.printed + 1] = msg end,
        strtrim = function(t) return (t:gsub("^%s+", ""):gsub("%s+$", "")) end,
    }, { __index = _G })
    env._G = env
    local function Load(path)
        local chunk = assert(loadstring(Read(path), path))
        setfenv(chunk, env)
        chunk()
    end
    Load("Core/Options/Modules.lua")
    ns.Options.OpenModule = function(mod) s.opened[#s.opened + 1] = mod.command or mod.name end
    Load("Core/Commands.lua")
    s.ns, s.env = ns, env
    return s
end

local function Printed(s, text)
    for _, line in ipairs(s.printed) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

do
    local s = Fixture(0)
    local nf = s.env.SlashCmdList.NAOWHFOREVER
    nf("help")
    check("/nf help prints a list and leaves the window alone", #s.printed > 10 and s.toggled == 0)
    check("it names /nf move", Printed(s, "/nf move"))
    for _, word in ipairs({ "/nf bars", "/nf ab", "/nf xp", "/nf lockouts", "/nf ranks", "/nf trainer", "/nf profrank",
            "/nf junk", "/nf efficiency", "/nf quiz", "/nf setup" }) do
        check("it names " .. word, Printed(s, word))
    end
    for _, mod in ipairs(s.ns.Options.MODULES) do
        if mod.command then
            local name = "/nf" .. mod.command
            check("it names " .. name, Printed(s, name .. ":") or Printed(s, name .. " or"))
        end
    end
    check("an alias is on its module's line", Printed(s, "/nfjournal or /nfdj: opens Dungeon Journal"))
    check("it names /nfquests and its alias", Printed(s, "/nfquests (or /nfcompleto)"))
    check("no badge code before badges launch", not Printed(s, "badges"))
    local before = #s.printed
    nf(" ? ")
    check("/nf ? prints it too", #s.printed > before and s.toggled == 0)

    local before2 = #s.printed
    s.env.SlashCmdList.NAOWHFOREVERQUESTLIST()
    check("/nfquests with Discovery off says so, not nothing", #s.printed == before2 + 1
        and Printed(s, "Discovery is switched off"))
    check("both names are the Quest List's", s.env.SLASH_NAOWHFOREVERQUESTLIST1 == "/nfquests"
        and s.env.SLASH_NAOWHFOREVERQUESTLIST2 == "/nfcompleto")

    nf("move")
    check("/nf move opens the HUD Editor", s.unlock)
    nf("hud")
    check("/nf hud closes it again", not s.unlock)
    s.env.NaowhForever_ToggleHudEditor()
    check("its key binding opens it", s.unlock)

    local opened = 0
    s.ns.ToggleSpellEfficiencyReport = function() opened = opened + 1 end
    nf("efficiency")
    check("/nf efficiency opens the Mana Efficiency window", opened == 1 and s.toggled == 0)
    local junk = 0
    s.ns.ToggleScrapList = function() junk = junk + 1 end
    nf("junk")
    nf("scrap")
    check("/nf junk opens the Junk List, and /nf scrap still does", junk == 2 and s.toggled == 0)

    nf("nonsense")
    check("an unknown command still opens the window", s.toggled == 1)
end

do
    local s = Fixture(1)
    s.env.SlashCmdList.NAOWHFOREVER("help")
    check("with badges live, /nf help names /nf badges id", Printed(s, "/nf badges id"))
end

do
    local s = Fixture(0)
    local list = s.env.SlashCmdList
    list.NAOWHFOREVERBARS("  save Raid  ")
    check("/nfbars save Raid runs the bars command with its words", s.barArgs[1] == "save Raid" and #s.opened == 0)
    list.NAOWHFOREVERBARS("")
    check("/nfbars on its own opens the module", s.opened[1] == "bars" and #s.barArgs == 1)
    list.NAOWHFOREVERBIS("save Raid")
    check("other module commands ignore their words", s.opened[2] == "bis" and #s.barArgs == 1)
    local nf = list.NAOWHFOREVER
    nf("ab Raid")
    check("/nf ab Raid imports the set by its typed name", s.abArgs[1] == "Raid")
    nf("AB")
    check("/nf ab on its own passes no name", s.abArgs[2] == "")
    list.NAOWHFOREVERJOURNAL("")
    check("a module command opens its module", s.opened[3] == "journal")
end

local bindings = Read("Bindings.xml")
check("a key binding for the HUD Editor",
    bindings:find('<Binding name="NAOWHFOREVER_HUD" category="BINDING_HEADER_NAOWHFOREVER">'
        .. "NaowhForever_ToggleHudEditor()</Binding>", 1, true))
check("with its name", Fixture(0).env.BINDING_NAME_NAOWHFOREVER_HUD ~= nil)
check("a key binding for the Training Planner",
    bindings:find('<Binding name="NAOWHFOREVER_TRAINING" category="BINDING_HEADER_NAOWHFOREVER">'
        .. "NaowhForever_ToggleTraining()</Binding>", 1, true))
do
    local t = Fixture(0)
    check("with its name", t.env.BINDING_NAME_NAOWHFOREVER_TRAINING ~= nil)
    t.env.NaowhForever_ToggleTraining()
    check("which says so while the Training Planner is not loaded", t.printed[#t.printed]:find("Training Planner", 1, true))
end
check("no key binding for the Damage Meter, which is not shipped", not bindings:find("DAMAGEMETER", 1, true))

local KEYED = { instance = "Instance Tracker", discovery = "Discovery", gear = "Gear & Trinkets", bless = "Blessings",
    macros = "Macros", bars = "Action Bars", buffs = "AuraBuffs", threat = "Threat Meter", pvp = "PvP" }
for command, name in pairs(KEYED) do
    local key = "NAOWHFOREVER_" .. command:upper()
    check("a key binding for " .. name, bindings:find('<Binding name="' .. key
        .. '" category="BINDING_HEADER_NAOWHFOREVER">NaowhForever_ToggleModule("' .. command .. '")</Binding>', 1, true))
    local t = Fixture(0)
    check("with its name", t.env["BINDING_NAME_" .. key] == "Open " .. name)
    t.env.NaowhForever_ToggleModule(command)
    check("which opens its module", t.opened[#t.opened] == command)
end
do
    local t = Fixture(0)
    t.env.NaowhForever_ToggleModule("nonsense")
    check("an unknown command opens nothing", #t.opened == 0)
end

-- Modules with no slash command are bound by name.
local NAMED = { JOURNEYS = "Journeys", PROFESSIONS = "Professions", CONSUMABLEBAR = "Consumable Bar",
    SWINGTIMER = "Swing Timer" }
for key, name in pairs(NAMED) do
    check("a key binding for " .. name, bindings:find('<Binding name="NAOWHFOREVER_' .. key
        .. '" category="BINDING_HEADER_NAOWHFOREVER">NaowhForever_ToggleModule("' .. name .. '")</Binding>', 1, true))
    local t = Fixture(0)
    check("with its name", t.env["BINDING_NAME_NAOWHFOREVER_" .. key] == "Open " .. name)
    t.env.NaowhForever_ToggleModule(name)
    check("which opens its module", t.opened[#t.opened] == name)
end
for key in bindings:gmatch('<Binding name="(NAOWHFOREVER_[%w_]+)"[^>]*>NaowhForever_ToggleModule') do
    local id = key:match("^NAOWHFOREVER_(.+)$")
    check(key .. " is one of the keyed modules", KEYED[id:lower()] or NAMED[id])
end

-- The Top Bar has no tabs of its own: its key opens the QoL Interface page. Window features open their window.
do
    local t = Fixture(0)
    check("a key binding for the Top Bar", bindings:find('NAOWHFOREVER_TOPBAR" category="BINDING_HEADER_NAOWHFOREVER">'
        .. "NaowhForever_OpenTopBar()</Binding>", 1, true))
    check("with its name", t.env.BINDING_NAME_NAOWHFOREVER_TOPBAR == "Open Top Bar")
    local page
    t.ns.OpenOptionsWindow = function(name) page = name end
    t.ns.TopBar = nil
    t.env.NaowhForever_OpenTopBar()
    check("which says so while QoL, and the Top Bar in it, is not loaded", page == nil
        and t.printed[#t.printed]:find("Top Bar", 1, true))
    t.ns.TopBar = {}
    t.env.NaowhForever_OpenTopBar()
    check("and otherwise opens QoL > Interface", page == "QoL/Interface")
end
for key, window in pairs({ SCRAP = { "scrap", "ToggleScrapList", "Junk List", "Quality of Life" },
        DISENCHANT = { "disenchant", "ToggleDisenchant", "Disenchant", "Professions" },
        QUIZ = { "quiz", "ToggleQuiz", "Quiz", "Quality of Life" }, AIM = { "aim", "ToggleAimTrainer", "Aim Trainer", "Quality of Life" },
        EFFICIENCY = { "efficiency", "ToggleSpellEfficiencyReport", "Mana Efficiency", "Quality of Life" } }) do
    local t = Fixture(0)
    check("a key binding for the " .. window[3], bindings:find('NAOWHFOREVER_' .. key .. '" category="BINDING_HEADER_NAOWHFOREVER">'
        .. 'NaowhForever_ToggleWindow("' .. window[1] .. '")</Binding>', 1, true))
    check("with its name", t.env["BINDING_NAME_NAOWHFOREVER_" .. key] == "Open " .. window[3])
    t.env.NaowhForever_ToggleWindow(window[1])
    check("which names the addon that is off while it is not loaded",
        t.printed[#t.printed] == window[4] .. " is switched off. Turn it on under Settings > Modules.")
    local toggled = 0
    t.ns[window[2]] = function() toggled = toggled + 1 end
    t.env.NaowhForever_ToggleWindow(window[1])
    check("and otherwise toggles it", toggled == 1)
end

local toc = Read("NaowhForever.toc")
local s = Fixture(0)
for fn in toc:gmatch("## AddonCompartmentFunc%w*: (%S+)") do
    check("the compartment's " .. fn .. " is defined", type(s.env[fn]) == "function")
end
check("the compartment has a tooltip", toc:find("AddonCompartmentFuncOnEnter", 1, true))

print(("test-nf-commands: %d checks passed"):format(checks))

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
    ns.Options.OpenModule = function(mod) s.opened[#s.opened + 1] = mod.command end
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
            "/nf scrap", "/nf quiz", "/nf setup" }) do
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
check("a key binding for showing or hiding the Damage Meter",
    bindings:find('<Binding name="NAOWHFOREVER_DAMAGEMETER_TOGGLE" category="BINDING_HEADER_NAOWHFOREVER">'
        .. "NaowhForever_ToggleDamageMeter()</Binding>", 1, true))
do
    local t = Fixture(0)
    check("with its name", t.env.BINDING_NAME_NAOWHFOREVER_DAMAGEMETER_TOGGLE ~= nil)
    t.env.NaowhForever_ToggleDamageMeter()
    check("which says so while the Damage Meter is not loaded", t.printed[#t.printed]:find("Damage Meter", 1, true))
end
check("a key binding for resetting the Damage Meter",
    bindings:find('<Binding name="NAOWHFOREVER_DAMAGEMETER_RESET" category="BINDING_HEADER_NAOWHFOREVER">'
        .. "NaowhForever_ResetDamageMeter()</Binding>", 1, true))
do
    local t = Fixture(0)
    check("with its name", t.env.BINDING_NAME_NAOWHFOREVER_DAMAGEMETER_RESET ~= nil)
    t.env.NaowhForever_ResetDamageMeter()
    check("which says so while the Damage Meter is not loaded", t.printed[#t.printed]:find("Damage Meter", 1, true))
end

local toc = Read("NaowhForever.toc")
local s = Fixture(0)
for fn in toc:gmatch("## AddonCompartmentFunc%w*: (%S+)") do
    check("the compartment's " .. fn .. " is defined", type(s.env[fn]) == "function")
end
check("the compartment has a tooltip", toc:find("AddonCompartmentFuncOnEnter", 1, true))

print(("test-nf-commands: %d checks passed"):format(checks))

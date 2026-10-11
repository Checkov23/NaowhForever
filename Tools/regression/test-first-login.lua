-- Run with Lua 5.1 from the repository root: the onboarding on an account's first login
-- (Core/Onboarding/FirstLogin.lua) on stub frames. Checks that it makes one frame at load; opens
-- the onboarding a few seconds after the first login, or after a reload while it is still unseen,
-- never during a loading screen, and waits for combat to end; once seen it never opens by itself
-- again; a new character gets its page in the onboarding window (its name, its main and the main's
-- profile), out of combat, again after a reload or relog until it is answered, changing nothing
-- itself; /nf welcome and /nf setup open the onboarding. What the page's answers do is in
-- test-setup-window.lua.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local FIRST_LOGIN = "Core/Onboarding/FirstLogin.lua"

local Frame = {}
Frame.__index = Frame
local function NewFrame(made)
    local f = setmetatable({ scripts = {}, events = {} }, Frame)
    made[#made + 1] = f
    return f
end
function Frame:SetScript(name, fn) self.scripts[name] = fn end
function Frame:RegisterEvent(e) self.events[e] = true end
function Frame:UnregisterEvent(e) self.events[e] = nil end
function Frame:UnregisterAllEvents() self.events = {} end

local ME = "Die Dudu"

local function Setup(account)
    local s = { account = account or {}, made = {}, timers = {}, combat = false, onboarding = 0, opened = {},
        profiles = { Default = {}, Raid = {} }, mainProfile = "Raid",
        charActive = { [ME] = "Default", ["Die Man"] = "Raid", ["Die Pri"] = "Default" } }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        AccountSettings = function() return s.account end,
        ShowSetup = function(thisCharacter)
            s.onboarding = s.onboarding + 1
            s.opened[s.onboarding] = thisCharacter or false
        end,
        MarkSeen = function() s.marked = (s.marked or 0) + 1 end,
        ImportCandidate = function()
            if s.answered or not s.candidate then return nil end
            return s.candidate, s.mainProfile
        end,
        ActiveProfileName = function() return s.charActive[ME] end,
        ProfileExists = function(name) return s.profiles[name] ~= nil end,
        SwitchProfile = function(name)
            if not s.profiles[name] then return false end
            s.switched, s.charActive[ME] = name, name
            return true
        end,
        CopyProfile = function(src, name)
            if s.failCopy or s.profiles[name] or not s.profiles[src] then return false end
            s.profiles[name] = { copyOf = src }
            return true
        end,
        CreateProfile = function() s.created = true; return true end,
        SetAccountProfile = function() s.created = true; return true end,
        ShowNewCharacter = function(me, main, profile)
            s.asked = { me = me, main = main, profile = profile }
            s.askedCount = (s.askedCount or 0) + 1
        end,
        Print = function(text) s.printed = text end,
    }
    local env = setmetatable({
        NaowhForever = ns,
        CreateFrame = function() return NewFrame(s.made) end,
        InCombatLockdown = function() return s.combat end,
        UnitName = function() return "Die Dudu" end,
        C_Timer = { NewTimer = function(delay, fn)
            local t = { delay = delay, fn = fn }
            t.Cancel = function(self) self.cancelled = true end
            s.timers[#s.timers + 1] = t
            return t
        end },
    }, { __index = _G })
    env._G = env
    local chunk = assert(loadfile(FIRST_LOGIN))
    setfenv(chunk, env)
    chunk()
    s.ns = ns
    s.login = s.made[1]
    return s
end

local function Event(s, event, ...)
    s.login.scripts.OnEvent(s.login, event, ...)
end

local function RunTimer(s)
    for i = #s.timers, 1, -1 do
        local t = s.timers[i]
        if not t.cancelled and not t.ran then
            t.ran = true
            t.fn()
            return t
        end
    end
end

-------------------------------------------------------------------------------
--  Nothing at load
-------------------------------------------------------------------------------
do
    local s = Setup()
    check("one frame at load, for the login check", #s.made == 1)
    check("it listens for the first world entry only", s.login.events.PLAYER_ENTERING_WORLD
        and not s.login.events.PLAYER_REGEN_ENABLED and not s.login.events.PLAYER_LEAVING_WORLD)
    check("the onboarding is not opened at load", s.onboarding == 0)
end

-------------------------------------------------------------------------------
--  The first login: a few seconds in, then once
-------------------------------------------------------------------------------
do
    local s = Setup()
    Event(s, "PLAYER_ENTERING_WORLD", true, false)
    check("the first login waits a few seconds", #s.timers == 1 and s.timers[1].delay > 0 and s.onboarding == 0)
    RunTimer(s)
    check("then the onboarding opens", s.onboarding == 1)
    check("and it stops listening", next(s.login.events) == nil)
end
do
    local s = Setup()
    Event(s, "PLAYER_ENTERING_WORLD", false, true)
    RunTimer(s)
    check("a reload before it was seen (another addon's setup reloading over it): it opens again", s.onboarding == 1)
end
do
    local s = Setup({ onboardingSeen = true, welcomeSeen = true })
    Event(s, "PLAYER_ENTERING_WORLD", true, false)
    check("seen: the next login starts no timer and stops listening", #s.timers == 0
        and next(s.login.events) == nil and s.onboarding == 0)
end
do
    local s = Setup()
    Event(s, "PLAYER_ENTERING_WORLD", false, false)
    check("a world entry that is neither login nor reload does not start it", #s.timers == 0)
end

do
    local s = Setup({ welcomeSeen = true })
    Event(s, "PLAYER_ENTERING_WORLD", true, false)
    RunTimer(s)
    check("an account that saw the old welcome window still gets the onboarding, once", s.onboarding == 1)
end

-------------------------------------------------------------------------------
--  Combat and loading screens
-------------------------------------------------------------------------------
do
    local s = Setup()
    Event(s, "PLAYER_ENTERING_WORLD", true, false)
    s.combat = true
    RunTimer(s)
    check("in combat when due: nothing yet, waits for combat to end", s.onboarding == 0
        and s.login.events.PLAYER_REGEN_ENABLED)
    s.combat = false
    Event(s, "PLAYER_REGEN_ENABLED")
    check("combat over: it opens", s.onboarding == 1 and next(s.login.events) == nil)
end
do
    local s = Setup()
    Event(s, "PLAYER_ENTERING_WORLD", true, false)
    local first = s.timers[1]
    Event(s, "PLAYER_LEAVING_WORLD")
    check("a loading screen before it is due puts it off", first.cancelled == true and s.onboarding == 0)
    Event(s, "PLAYER_ENTERING_WORLD", false, false)
    check("the world entry after it starts the wait again", #s.timers == 2 and not s.timers[2].cancelled)
    RunTimer(s)
    check("and it opens after", s.onboarding == 1)
end
do
    local s = Setup()
    Event(s, "PLAYER_ENTERING_WORLD", true, false)
    s.combat = true
    RunTimer(s)
    Event(s, "PLAYER_LEAVING_WORLD")
    check("waiting on combat, a loading screen stops the wait", not s.login.events.PLAYER_REGEN_ENABLED)
    s.combat = false
    Event(s, "PLAYER_ENTERING_WORLD", false, false)
    RunTimer(s)
    check("and the next world entry opens it", s.onboarding == 1)
end

-------------------------------------------------------------------------------
--  A character's first login, the onboarding seen: its page, until it is answered
-------------------------------------------------------------------------------
local function Snapshot(s)
    local out = {}
    for char, profile in pairs(s.charActive) do out[#out + 1] = char .. "=" .. profile end
    for name in pairs(s.profiles) do out[#out + 1] = "profile:" .. name end
    table.sort(out)
    return table.concat(out, ",")
end

local function Asked(s, isInitialLogin, isReloadingUi)
    if isInitialLogin == nil then isInitialLogin = true end
    Event(s, "PLAYER_ENTERING_WORLD", isInitialLogin, isReloadingUi or false)
    RunTimer(s)
    return s.asked
end

do
    local s = Setup({ onboardingSeen = true, welcomeSeen = true })
    Event(s, "PLAYER_ENTERING_WORLD", true, false)
    check("each login notes when the character was last played", s.marked == 1)
    check("no other character, or not a new one: nothing waits", #s.timers == 0 and s.asked == nil
        and next(s.login.events) == nil)
    RunTimer(s)
    check("and nothing is asked", s.asked == nil and s.onboarding == 0)
end
do
    local s = Setup({ onboardingSeen = true, welcomeSeen = true })
    s.candidate = "Die Man-Forever"
    local before = Snapshot(s)
    Event(s, "PLAYER_ENTERING_WORLD", true, false)
    check("a new character with another around: a few seconds in", #s.timers == 1 and s.asked == nil)
    s.combat = true
    RunTimer(s)
    check("not in combat", s.asked == nil and s.login.events.PLAYER_REGEN_ENABLED)
    s.combat = false
    Event(s, "PLAYER_REGEN_ENABLED")
    check("its page opens: the character by name, its main and the main's profile", s.asked
        and s.asked.me == "Die Dudu" and s.asked.main == "Die Man" and s.asked.profile == "Raid" and s.onboarding == 0)
    check("asked once, then it stops listening", s.askedCount == 1 and next(s.login.events) == nil)
    check("opening it changes nothing yet", Snapshot(s) == before and s.switched == nil and s.printed == nil
        and not s.created)
end
do
    local s = Setup({ onboardingSeen = true, welcomeSeen = true })
    s.candidate, s.mainProfile = "Die Pri-Forever", "Default"
    check("the main on this character's profile is still asked about, with its profile",
        Asked(s) and s.asked.main == "Die Pri" and s.asked.profile == "Default")
end
do
    local account = { onboardingSeen = true, welcomeSeen = true }
    local s = Setup(account)
    s.candidate = "Die Man-Forever"
    Asked(s)
    Event(s, "PLAYER_LEAVING_WORLD")
    Asked(s, false, true)
    check("a reload with no answer: asked again", s.askedCount == 2 and s.asked.main == "Die Man")
    local relog = Setup(account)
    relog.candidate = "Die Man-Forever"
    check("a relog with no answer: asked again", Asked(relog) and relog.askedCount == 1)
    s.answered = true
    Event(s, "PLAYER_LEAVING_WORLD")
    Asked(s, false, true)
    check("answered (either tile, X or Escape): a reload does not ask again", s.askedCount == 2
        and next(s.login.events) == nil)
    relog = Setup(account)
    relog.candidate, relog.answered = "Die Man-Forever", true
    check("nor does a relog", Asked(relog) == nil and #relog.timers == 0)
end
do
    local account = {}
    local s = Setup(account)
    s.candidate = "Die Man-Forever"
    Event(s, "PLAYER_ENTERING_WORLD", true, false)
    RunTimer(s)
    check("the onboarding not seen yet: it opens for every character, not the page", s.onboarding == 1
        and s.opened[1] == false and s.asked == nil)
    account.onboardingSeen, account.welcomeSeen = true, true
    local relog = Setup(account)
    relog.candidate, relog.answered = "Die Man-Forever", true
    check("closed on that character, it counts as the answer: not asked after", Asked(relog) == nil
        and relog.onboarding == 0)
end

-------------------------------------------------------------------------------
--  /nf welcome and /nf setup
-------------------------------------------------------------------------------
do
    local s = Setup({ onboardingSeen = true, welcomeSeen = true })
    local source = Read("Core/Commands.lua")
    local body = assert(source:match('SlashCmdList%["NAOWHFOREVER"%] = function%(msg%)\n(.-)\nend\n'),
        "the /nf handler")
    local env = setmetatable({ ns = s.ns, strtrim = function(t) return (t:gsub("^%s+", ""):gsub("%s+$", "")) end },
        { __index = _G })
    local handler = assert(loadstring("return function(msg)\n" .. body .. "\nend"))
    setfenv(handler, env)
    handler = handler()
    s.ns.ToggleOptionsWindow = function() s.toggled = true end
    handler("setup")
    check("/nf setup opens the onboarding, seen or not", s.onboarding == 1 and not s.toggled)
    check("for every character, as before", s.opened[1] == false)
    handler(" Welcome ")
    check("/nf welcome too, as it did before the onboarding", s.onboarding == 2 and not s.toggled)
end

-------------------------------------------------------------------------------
--  Its words: no ask
-------------------------------------------------------------------------------
do
    local source = Read(FIRST_LOGIN):lower()
    for _, word in ipairs({ "support", "patreon", "badge", "donat" }) do
        check("no " .. word .. " anywhere in the file", not source:find(word, 1, true))
    end
end

print(("test-first-login: %d checks passed"):format(checks))

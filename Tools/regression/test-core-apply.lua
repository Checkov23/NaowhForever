-- Regression: Core itself calls ns.Apply() a second after login, and queues it again on a new
-- world, spec, spells or talents. Every module that hooks ns.Apply (the character and inspect
-- panels, the bag marks and more) paints its first time from it; a module used to make that
-- call and no longer ships, which left them unpainted after a reload.
-- Run from the repo root: lua5.1 Tools/regression/test-core-apply.lua
local passed = 0
local function check(name, ok)
    if not ok then error("FAIL " .. name, 2) end
    passed = passed + 1
end

local f = assert(io.open("Core/Core.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n")
f:close()
local function Slice(a, b)
    local first = assert(source:find(a, 1, true), a)
    local last = b and source:find(b, first + #a, true) or #source + 1
    return source:sub(first, last - 1)
end
local constants = assert(source:match("\n(local MODULE_KEY = .-\n)\nlocal ns = {}\n"), "Core constants")
local chunk = assert(loadstring(constants .. Slice("local function ApplyNow()", "\ndo\n")
    .. "\n" .. Slice("local reapplyPending")))

local frames, timers, applied, watched = {}, {}, 0, 0
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Shared = { Settings = { WatchEllesmere = function() watched = watched + 1 end } } }
local env = setmetatable({
    NaowhForever = ns,
    ns = ns,
    CreateFrame = function()
        local frame = { events = {} }
        function frame.RegisterEvent(self, e) self.events[e] = true end
        function frame.SetScript(self, _, fn) self.onEvent = fn end
        frames[#frames + 1] = frame
        return frame
    end,
    C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end },
}, { __index = _G })
setfenv(chunk, env)
chunk()
local real = ns.Apply
ns.Apply = function() applied = applied + 1; real() end

local events = frames[#frames]
check("Core listens for login, a new world and spec", events and events.events.PLAYER_LOGIN
    and events.events.PLAYER_ENTERING_WORLD and events.events.PLAYER_SPECIALIZATION_CHANGED)
check("but not spells or talents, which fire in bursts on a level up",
    not events.events.SPELLS_CHANGED and not events.events.TRAIT_CONFIG_UPDATED)
events:onEvent("PLAYER_LOGIN")
check("login: one Apply a second later", #timers == 1 and timers[1].delay == 1)
timers[1].fn()
check("which reaches the modules' hooks", applied == 1)
check("and starts watching EllesmereUI's window", watched == 1)
events:onEvent("PLAYER_ENTERING_WORLD")
events:onEvent("PLAYER_SPECIALIZATION_CHANGED")
check("a burst of world and spec events: one reapply queued", #timers == 2 and timers[2].delay == 0)
timers[2].fn()
check("and it applies", applied == 2)
events:onEvent("PLAYER_SPECIALIZATION_CHANGED")
check("a new spec queues it again", #timers == 3)

print(("test-core-apply: %d checks passed"):format(passed))

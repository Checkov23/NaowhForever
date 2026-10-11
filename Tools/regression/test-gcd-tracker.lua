-- Loads GcdTracker.lua against stubbed frames and spell APIs and checks that the
-- tracker draws a cast and its busy bar, then stops updating once nothing is left on it, wakes
-- again on the next cast, and what a frame costs while there is nothing to draw. Its busy bar
-- is flat by default and takes the Bar Texture picked.
-- Run from the repo root: lua Tools/regression/test-gcd-tracker.lua
local f = assert(io.open(arg[1] or "NaowhForever_QoL/Combat/GcdTracker.lua", "rb"))
local source = f:read("*a"); f:close()

local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end
local Measure = dofile("Tools/regression/measure.lua")(check)

local function Noop() end
local Widget
local methods = {
    SetScript = function(self, k, fn) self.scripts[k] = fn end,
    RegisterEvent = function(self, e) self.events[e] = true end,
    RegisterUnitEvent = function(self, e) self.events[e] = true end,
    UnregisterAllEvents = function(self) for k in pairs(self.events) do self.events[k] = nil end end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
    SetShown = function(self, v) self.shown = v and true or false end,
    IsShown = function(self) return self.shown end,
    CreateTexture = function(self) return Widget("Texture", self) end,
    SetTexture = function(self, path) self.texture = path end,
    SetVertexColor = function(self, r, g, b, a) self.r, self.g, self.b, self.a = r, g, b, a end,
}
local meta = { __index = function(_, k)
    local m = methods[k]
    if m then return m end
    if type(k) == "string" and k:find("^%u") then return Noop end
end }
function Widget(kind, parent)
    return setmetatable({ kind = kind, parent = parent, shown = true, scripts = {}, events = {} }, meta)
end

local values = {
    enabled = true, gcdTracker = true, gcdDuration = 5, gcdIconSize = 32, gcdSpacing = 4, gcdDirection = "RIGHT",
    gcdFadeStart = 0.5, gcdStack = true, gcdCombatOnly = false, gcdWorld = true, gcdDungeon = true,
    gcdRaid = true, gcdPvP = true, gcdBlocklist = "6603, 75", gcdTimelineColor = { r = 0, g = 0.5, b = 1 },
    gcdTimelineHeight = 4, gcdDowntime = false, gcdTexture = "",
}
local S = { Get = function(k) return values[k] end, Set = function(k, v) values[k] = v end }

local now, gcdUntil = 1000, 0
local frames = {}
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    QoLConstants = dofile("Tools/regression/qol_constants.lua"),
    QoLSettings = S, ThemeTint = function(_, c) return c end, PixelInset = Noop,
    Apply = Noop, ShowUnlockMode = Noop, HideUnlockMode = Noop,
    UI = { AttachMover = function() return Widget("Mover") end,
        TexturePath = function(name, own) if name == "" then return own end return "lsm:" .. name end },
    Shared = { Style = dofile("Tools/regression/shared_style.lua"), Settings = { Group = function() return {} end, Look = function() return {} end,
        Page = function() return { Card = Noop } end } },
}
local env = setmetatable({
    _G = { NaowhForever = ns },
    UIParent = Widget("Frame"),
    CreateFrame = function(kind, _, parent)
        local w = Widget(kind, parent)
        frames[#frames + 1] = w
        return w
    end,
    hooksecurefunc = function(t, name, post)
        local orig = t[name]
        t[name] = function(...) orig(...); post(...) end
    end,
    GetTime = function() return now end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    UnitClass = function() return "Rogue", "ROGUE" end,
    UnitCastingInfo = function() end,
    UnitChannelInfo = function() end,
    UnitAffectingCombat = function() return false end,
    IsInInstance = function() return false, "none" end,
    -- A new table per call, as the client's own returns one.
    C_Spell = {
        GetSpellCooldown = function() return { isOnGCD = now < gcdUntil, startTime = 0, duration = 0 } end,
        GetSpellTexture = function() return 136243 end,
        GetSpellName = function() return "Sinister Strike" end,
    },
    C_Timer = { NewTicker = function() return { Cancel = Noop } end },
}, { __index = _G })
local chunk = assert(loadstring(source, "GcdTracker"))
setfenv(chunk, env)
chunk()

local boot, events, tracker
for _, w in ipairs(frames) do
    if w.events.PLAYER_LOGIN then boot = w end
end
boot.scripts.OnEvent(boot, "PLAYER_LOGIN")
for _, w in ipairs(frames) do
    if w.events.UNIT_SPELLCAST_SUCCEEDED then events = w end
end
for _, w in ipairs(frames) do
    if w.kind == "Frame" and w.scripts.OnUpdate then tracker = w end
end
check("listens to your casts", events and events.events.UNIT_SPELLCAST_SENT == true)
check("the tracker runs its update", tracker ~= nil)

local function Step(seconds)
    now = now + seconds
    local tick = tracker.scripts.OnUpdate
    if tick then tick(tracker, seconds) end
end
local function Fire(event, ...) events.scripts.OnEvent(events, event, ...) end

now = now + 10
Step(0.03)
check("nothing to draw: the update stops", tracker.scripts.OnUpdate == nil)

Fire("UNIT_SPELLCAST_SENT", "player", "", "Cast-1", 1752)
check("a cast being sent wakes it", tracker.scripts.OnUpdate ~= nil)
gcdUntil = now + 1.5
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 1752)
Step(0.03)
local icons = 0
for _, w in ipairs(frames) do
    if w.tex and w.shown and w.parent == tracker then icons = icons + 1 end
end
check("the cast and its busy bar are drawn", icons >= 2)
local seg
for _, w in ipairs(frames) do
    if w.tex and not w.glow and w.parent == tracker then seg = w end
end
check("the busy bar is flat by default, in its color", seg.tex.texture == "Interface\\Buttons\\WHITE8X8"
    and seg.tex.b == 1 and seg.tex.a == 0.6)
S.Set("gcdTexture", "Smooth")
Step(0.03)
check("Bar Texture applies to the busy bar", seg.tex.texture == "lsm:Smooth" and seg.tex.b == 1)
for _ = 1, 20 do Step(0.1) end
check("still updating while the cast scrolls by", tracker.scripts.OnUpdate ~= nil)
for _ = 1, 80 do Step(0.1) end
check("once it has scrolled off, the update stops again", tracker.scripts.OnUpdate == nil)

values.gcdIconSize = 40
S.Set("gcdIconSize", 40)
check("a setting change wakes it to redraw", tracker.scripts.OnUpdate ~= nil)
Step(0.03)
check("and it goes back to sleep", tracker.scripts.OnUpdate == nil)

Measure("a frame with nothing to draw", 0.01, function() Step(0.03) end)

print(("PASS gcd tracker: %d checks"):format(checks))

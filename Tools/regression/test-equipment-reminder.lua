-- Loads EquipmentReminder.lua against stubbed frames and checks what it listens to:
-- nothing while off, and when on, gear changes for you only (UNIT_INVENTORY_CHANGED fires for every
-- group member, so a raid's gear swaps would otherwise all reach the handler).
-- Run from the repo root: lua Tools/regression/test-equipment-reminder.lua
local f = assert(io.open(arg[1] or "NaowhForever_QoL/Loot/EquipmentReminder.lua", "rb"))
local source = f:read("*a"); f:close()

local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local function Noop() end
local frames = {}
local function Frame()
    local w = { scripts = {}, events = {}, units = {} }
    function w:SetScript(k, fn) self.scripts[k] = fn end
    function w:RegisterEvent(e) self.events[e] = true end
    function w:RegisterUnitEvent(e, unit) self.events[e], self.units[e] = true, unit end
    function w:UnregisterAllEvents()
        for k in pairs(self.events) do self.events[k], self.units[k] = nil, nil end
    end
    frames[#frames + 1] = w
    return w
end

local values = { enabled = true, equipReminder = false }
local S = { Get = function(k) return values[k] end, Set = function(k, v) values[k] = v end }
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QoLConstants = dofile("Tools/regression/qol_constants.lua"), QoLSettings = S, THEME = {}, Apply = Noop,
    Shared = { Style = dofile("Tools/regression/shared_style.lua"), Settings = { Page = function() return { Card = Noop } end } } }
local env = setmetatable({
    _G = { NaowhForever = ns },
    CreateFrame = Frame,
    hooksecurefunc = function(t, name, hook)
        local orig = t[name]
        t[name] = function(...) orig(...); hook(...) end
    end,
}, { __index = _G })
local chunk = assert(loadstring(source, "EquipmentReminder"))
setfenv(chunk, env)
chunk()

local events, boot
for _, w in ipairs(frames) do
    if w.events.PLAYER_LOGIN then boot = w else events = w end
end
boot.scripts.OnEvent(boot, "PLAYER_LOGIN")
check("off: listens to nothing", next(events.events) == nil)

S.Set("equipReminder", true)
check("on: entering instances and ready checks", events.events.PLAYER_ENTERING_WORLD and events.events.READY_CHECK)
check("on: gear changes for you only", events.events.UNIT_INVENTORY_CHANGED and events.units.UNIT_INVENTORY_CHANGED == "player")

S.Set("equipReminder", false)
check("off again: listens to nothing", next(events.events) == nil)

print(("PASS equipment reminder: %d checks"):format(checks))

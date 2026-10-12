-- Run with Lua 5.1 from the repository root: Always Free for All.
-- Off it listens to nothing; on, a party you lead is set to Free for All, a raid or a party you do
-- not lead is left alone, and nothing is changed in a fight until it ends.
local NOTHING = function() end
local frames = {}
local combat, grouped, raid, leader = false, false, false, false
local method, sets = 1, 0

local function Frame()
    local f = { scripts = {}, events = {} }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    frames[#frames + 1] = f
    return f
end

local settings = { enabled = true }
local setHooks, applyHooks = {}, {}
local S = { Get = function(k) return settings[k] end }
local card
local ns = {
    QoLSettings = S,
    Apply = NOTHING,
    Shared = { Settings = { Page = function() return { Card = function(_, c) card = c end } end } },
}
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = Frame,
    InCombatLockdown = function() return combat end,
    IsInGroup = function() return grouped end,
    IsInRaid = function() return raid end,
    UnitIsGroupLeader = function() return leader end,
    Enum = { LootMethod = { Freeforall = 0, Roundrobin = 1, Group = 3 } },
    C_PartyInfo = {
        GetLootMethod = function() return method end,
        SetLootMethod = function(m) method, sets = m, sets + 1; return true end,
    },
    hooksecurefunc = function(t, name, fn)
        if t == S then setHooks[#setHooks + 1] = fn elseif name == "Apply" then applyHooks[#applyHooks + 1] = fn end
    end,
}, { __index = _G })
env._G = env
local chunk = assert(loadfile("NaowhForever_QoL/Questing/FreeForAll.lua"))
setfenv(chunk, env)
chunk()
local events, boot = frames[1], frames[2]

local function Set(k, v)
    settings[k] = v
    for _, fn in ipairs(setHooks) do fn(k) end
end

local function Fire(event)
    events.scripts.OnEvent(events, event)
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("the card is on Questing & Group, behind its own switch", function()
    assert(card and card.switch == "freeForAll")
end)

Case("off by default: no events", function()
    boot.scripts.OnEvent(boot, "PLAYER_LOGIN")
    assert(next(events.events) == nil)
end)

Case("switched on while leading a party: set at once", function()
    grouped, leader = true, true
    Set("freeForAll", true)
    assert(events.events.GROUP_ROSTER_UPDATE and events.events.PARTY_LEADER_CHANGED)
    assert(method == 0 and sets == 1)
end)

Case("already Free for All: left alone", function()
    Fire("GROUP_ROSTER_UPDATE")
    assert(sets == 1)
end)

Case("changed by someone: put back", function()
    method = 3
    Fire("PARTY_LOOT_METHOD_CHANGED")
    assert(method == 0 and sets == 2)
end)

Case("not the leader: left alone", function()
    leader, method = false, 3
    Fire("PARTY_LEADER_CHANGED")
    assert(method == 3)
end)

Case("made leader: set", function()
    leader = true
    Fire("PARTY_LEADER_CHANGED")
    assert(method == 0)
end)

Case("a raid: left alone", function()
    raid, method = true, 3
    Fire("GROUP_ROSTER_UPDATE")
    assert(method == 3)
    raid = false
end)

Case("in a fight: waits for it to end", function()
    combat = true
    Fire("GROUP_ROSTER_UPDATE")
    assert(method == 3)
    combat = false
    Fire("PLAYER_REGEN_ENABLED")
    assert(method == 0)
end)

Case("switched off: events dropped", function()
    Set("freeForAll", false)
    assert(next(events.events) == nil)
    method = 3
    for _, fn in ipairs(applyHooks) do fn() end
    assert(method == 3)
end)

print(count .. " free-for-all checks passed")

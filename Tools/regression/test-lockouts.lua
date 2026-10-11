-- The Top Bar's saved instances (NaowhForever_TopBar/Info.lua), loaded against stubbed instance APIs.

-- Saved instances as GetSavedInstanceInfo returns them: name, reset, locked, extended, total, done.
-- The list is read at `now`, its resets having last been reported at `updatedAt`.
local function Fixture(saved, now, updatedAt)
    local clock = updatedAt
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, TopBar = {}, Print = function() end }
    local env = {
        NaowhForever = ns,
        GetTime = function() return clock end,
        GetNumSavedInstances = function() return #saved end,
        GetSavedInstanceInfo = function(i)
            local s = saved[i]
            return s[1], 1, s[2], 1, s[3], s[4], 0, false, 5, "Normal", s[5], s[6]
        end,
    }
    env._G = env
    setmetatable(env, { __index = _G })
    for _, path in ipairs({ "NaowhForever_TopBar/Constants.lua", "NaowhForever_TopBar/Info.lua" }) do
        local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk()
    end
    ns.TopBar.Info.InstanceInfoUpdated()
    clock = now
    return ns.TopBar.Info.Lockouts()
end
local function Lines(list)
    local out = {}
    for _, l in ipairs(list) do out[#out + 1] = l.name .. " in " .. l.reset end
    return table.concat(out, "; ")
end
local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("soonest reset first, with boss progress", function()
    local list = Fixture({
        { "Molten Core", 5 * 86400 + 3 * 3600, true, false, 10, 4 },
        { "Zul'Gurub", 2 * 3600 + 30 * 60, true, false, 10, 10 },
    }, 100, 100)
    assert(Lines(list) == "Zul'Gurub 10/10 in 2h 30m; Molten Core 4/10 in 5d 3h", Lines(list))
end)
Case("the reset counts down from the last update", function()
    local list = Fixture({ { "Onyxia's Lair", 3 * 3600, true, false, 1, 1 } }, 100 + 3600, 100)
    assert(Lines(list) == "Onyxia's Lair 1/1 in 2h 0m", Lines(list))
end)
Case("expired and unlocked instances are left out; extended ones stay", function()
    local list = Fixture({
        { "Old", 60, true, false, 0, 0 },
        { "Released", 86400, false, false, 0, 0 },
        { "Extended", 86400, false, true, 0, 0 },
    }, 500, 0)
    assert(Lines(list) == "Extended in 23h 51m", Lines(list))
end)
Case("an instance without boss counts shows just its name", function()
    local list = Fixture({ { "Dire Maul", 600, true, false, 0, 0 } }, 0, 0)
    assert(Lines(list) == "Dire Maul in 10m", Lines(list))
end)
print(count .. " lockout regressions passed")

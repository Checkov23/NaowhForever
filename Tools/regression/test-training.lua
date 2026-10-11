local DIR = arg[1] or "NaowhForever_Training"
local Load = dofile("Tools/regression/load_files.lua")

local NAMES = { [133] = "Fireball", [143] = "Fireball", [145] = "Fireball", [10151] = "Fireball",
    [25306] = "Fireball", [11366] = "Pyroblast", [12505] = "Pyroblast", [3561] = "Teleport: Stormwind",
    [3567] = "Teleport: Orgrimmar", [1953] = "Blink", [5143] = "Arcane Missiles", [5144] = "Arcane Missiles" }
-- { level, spellID, cost, flags } as the data file writes them.
local DATA = { [8] = {
    { 1, 133, 0 }, { 6, 143, 100, needs = 133 }, { 8, 5143, 200 }, { 12, 145, 600, needs = 143 },
    { 16, 5144, 1500, needs = 5143 }, { 20, 1953, 2000 },
    { 20, 3561, 2000, races = { 1, 3 } }, { 20, 3567, 2000, races = { 2 } },
    { 24, 12505, 2500, talent = 11366 },
    { 60, 10151, 38000, needs = 145 }, { 60, 25306, 0, quest = true },
} }

-- The module's planner and trainer scan for a mage of the given level and race who knows
-- `known`, has `ignored` ignored, standing at a trainer offering `services` ({ name, level, cost }).
-- The module's own files are loaded; the scan runs as the trainer window's event starts it.
local function Fixture(o)
    local refreshes, account = 0, { trainingIgnored = { ["Me-Realm"] = o.ignored or {} } }
    local known = o.known or {}
    local frames = {}
    local S = { Get = function() return true end, OnChange = function() end }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, TrainingData = DATA, AccountSettings = function() return account end,
        UI = { ModuleSettings = function() return S end, RefreshPage = function() refreshes = refreshes + 1 end } }
    local env = {
        NaowhForever = ns,
        CreateFrame = function()
            local f = { scripts = {} }
            function f:SetScript(k, fn) self.scripts[k] = fn end
            function f.RegisterEvent() end
            function f.UnregisterEvent() end
            function f.UnregisterAllEvents() end
            frames[#frames + 1] = f
            return f
        end,
        hooksecurefunc = function() end,
        C_Timer = { After = function(_, fn)
            if o.timers then o.timers[#o.timers + 1] = fn else fn() end
        end },
        UnitClass = function() return "Mage", "MAGE", 8 end,
        UnitRace = function() return "Human", "Human", o.race or 1 end,
        UnitLevel = function() return o.level or 1 end,
        UnitName = function() return "Me" end,
        GetRealmName = function() return "Realm" end,
        C_SpellBook = { IsSpellKnown = function(id) return known[id] == true end },
        C_Spell = { GetSpellName = function(id) return NAMES[id] end },
        IsTradeskillTrainer = function() return o.tradeskill == true end,
        GetNumTrainerServices = function() return #(o.services or {}) end,
        GetTrainerServiceInfo = function(i)
            local s = o.services[i]
            return s[1], "available", 136000, s[2]
        end,
        GetTrainerServiceCost = function(i) return o.services[i][3], false end,
    }
    env._G = env
    Load({ "Core/Features.lua", DIR .. "/Training.lua", DIR .. "/Constants.lua", DIR .. "/Plan.lua",
        DIR .. "/Builds.lua", DIR .. "/Trainer.lua" }, setmetatable(env, { __index = _G }))
    local Training = ns.Training
    local plan = Training.Plan
    Training.Apply()
    local trainerEvents = frames[#frames]
    local function scan() trainerEvents.scripts.OnEvent(trainerEvents, "TRAINER_SHOW") end
    return {
        -- "state: id id; state: id" for the states that have spells.
        Plan = function()
            local p, out = plan(), {}
            for _, state in ipairs({ "now", "rank", "soon", "later", "talent", "ignored" }) do
                if #p[state] > 0 then
                    local ids = {}
                    for _, e in ipairs(p[state]) do ids[#ids + 1] = e[2] end
                    out[#out + 1] = state .. ": " .. table.concat(ids, " ")
                end
            end
            return table.concat(out, "; ")
        end,
        Scan = function() scan() end,
        Fire = function(event) trainerEvents.scripts.OnEvent(trainerEvents, event) end,
        Prices = function() return account.trainingPrices or {} end,
        Refreshes = function() return refreshes end,
    }
end
local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("a fresh level 1 sees what it can train now, later levels and talent ranks", function()
    local t = Fixture({ level = 1 })
    local want = "now: 133; later: 143 5143 145 5144 1953 3561 10151 25306; talent: 12505"
    assert(t.Plan() == want, t.Plan())
end)
Case("a rank whose rank before is not learned waits on it", function()
    local t = Fixture({ level = 12, known = { [133] = true } })
    local want = "now: 143 5143; rank: 145; later: 5144 1953 3561 10151 25306; talent: 12505"
    assert(t.Plan() == want, t.Plan())
end)
Case("a later rank known counts the ranks before it as learned", function()
    local t = Fixture({ level = 20, known = { [145] = true, [5144] = true } })
    local want = "now: 1953 3561; later: 10151 25306; talent: 12505"
    assert(t.Plan() == want, t.Plan())
end)
Case("a rank before that is not in the list counts as learned when the game knows it", function()
    DATA[8][#DATA[8] + 1] = { 30, 5145, 4000, needs = 5144 }
    DATA[8][#DATA[8] + 1] = { 30, 9999, 4000, needs = 9998 }
    local t = Fixture({ level = 30, known = { [145] = true, [5144] = true, [1953] = true, [3561] = true, [9998] = true } })
    local plan = t.Plan()
    DATA[8][#DATA[8]] = nil
    DATA[8][#DATA[8]] = nil
    assert(plan == "now: 5145 9999; later: 10151 25306; talent: 12505", plan)
end)
Case("spells two levels away or less are coming soon", function()
    local t = Fixture({ level = 14, known = { [145] = true, [5143] = true } })
    assert(t.Plan() == "soon: 5144; later: 1953 3561 10151 25306; talent: 12505", t.Plan())
end)
Case("talent ranks wait on the talent, then sort by level", function()
    local t = Fixture({ level = 30, race = 2, known = { [145] = true, [5144] = true, [1953] = true } })
    assert(t.Plan() == "now: 3567; later: 10151 25306; talent: 12505", t.Plan())
    t = Fixture({ level = 30, race = 2, known = { [145] = true, [5144] = true, [1953] = true, [11366] = true } })
    assert(t.Plan() == "now: 3567 12505; later: 10151 25306", t.Plan())
end)
Case("ignored spells leave the other lists", function()
    local t = Fixture({ level = 20, known = { [145] = true, [5144] = true }, ignored = { [1953] = true } })
    assert(t.Plan() == "now: 3561; later: 10151 25306; talent: 12505; ignored: 1953", t.Plan())
end)
Case("trainer prices are matched by name and level; a header matches nothing", function()
    local t = Fixture({ services = {
        { "Fireball", nil, 0 },
        { "Fireball", 6, 95 },
        { "Fireball", 12, 570 },
        { "Blink", 20, 1900 },
        { "Frost Nova", 10, 500 },
    } })
    t.Scan()
    local p = t.Prices()
    assert(p[143] == 95 and p[145] == 570 and p[1953] == 1900, "prices by name and level")
    assert(p[133] == nil, "the header is not a service")
    assert(t.Refreshes() == 1, "one refresh for the scan")
    t.Scan()
    assert(t.Refreshes() == 1, "an unchanged list does not refresh the page")
end)
Case("two spells of one name and level take the price for the first in the data", function()
    local t = Fixture({ services = { { "Fireball", 60, 38000 } } })
    t.Scan()
    assert(t.Prices()[10151] == 38000 and t.Prices()[25306] == nil, "first entry only")
end)
Case("a profession trainer is not read", function()
    local t = Fixture({ services = { { "Fireball", 6, 100 } }, tradeskill = true })
    t.Scan()
    assert(next(t.Prices()) == nil and t.Refreshes() == 0, "nothing recorded")
end)
Case("a level up and the spells it teaches refresh the page once, on the next frame", function()
    local timers = {}
    local t = Fixture({ timers = timers })
    t.Fire("PLAYER_LEVEL_UP")
    for _ = 1, 3 do t.Fire("LEARNED_SPELL_IN_SKILL_LINE") end
    assert(t.Refreshes() == 0 and #timers == 1, "nothing yet, one pass queued")
    timers[1]()
    assert(t.Refreshes() == 1, "one refresh")
    t.Fire("LEARNED_SPELL_IN_SKILL_LINE")
    assert(#timers == 2, "a later spell queues again")
end)
Case("buying at a trainer: the new prices and the learned spell refresh the page once", function()
    local timers = {}
    local t = Fixture({ timers = timers, services = { { "Fireball", 6, 95 } } })
    t.Scan()
    t.Fire("LEARNED_SPELL_IN_SKILL_LINE")
    local i = 1
    while timers[i] do timers[i](); i = i + 1 end
    assert(t.Prices()[143] == 95 and t.Refreshes() == 1, "one refresh, " .. t.Refreshes())
end)

-- What a rank adds, from two ranks' descriptions as the client writes them.
local upgrades = { NaowhForever = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Training = {} } }
upgrades._G = upgrades
Load({ DIR .. "/Constants.lua", DIR .. "/Upgrades.lua" }, setmetatable(upgrades, { __index = _G }))
local compare = upgrades.NaowhForever.Training.Compare
local function Upgrade(old, new)
    local up = compare(old, new)
    return up and ("+%d%% %s %s>%s"):format(up.pct, up.what, up.from, up.to) or "none"
end
Case("a damage range: the first number that grew, with what it measures", function()
    local got = Upgrade("Hurls a fiery ball that causes 16 to 24 Fire damage and an additional 2 Fire damage over 4 sec.",
        "Hurls a fiery ball that causes 33 to 47 Fire damage and an additional 3 Fire damage over 6 sec.")
    assert(got == "+100% Fire damage 16-24>33-47", got)
end)
Case("a single number named by the words before it", function()
    local got = Upgrade("Increases the target's Intellect by 2 for 1 hour.", "Increases the target's Intellect by 7 for 1 hour.")
    assert(got == "+250% Intellect 2>7", got)
end)
Case("decimals, and a slow that did not change is passed over", function()
    local got = Upgrade("causing 20 to 22 Frost damage and slowing movement speed by 40% for 5 sec.",
        "causing 33.8 to 37.8 Frost damage and slowing movement speed by 40% for 6 sec.")
    assert(got == "+70% Frost damage 20-22>33.8-37.8", got)
end)
Case("only a duration grew, or the texts do not line up: nothing to show", function()
    assert(Upgrade("Lasts 30 sec.", "Lasts 60 sec.") == "none", "a duration is not power")
    assert(Upgrade("Heals 10.", "Heals 10 to 20 and 5 more.") == "none", "different shapes")
end)
print(count .. " training regressions passed")

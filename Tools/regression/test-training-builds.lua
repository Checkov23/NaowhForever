-- Training Planner talent builds: sharing them as text and saving your own. An imported
-- string comes from another player, so everything it says is checked against the class tree.
local DIR = arg[1] or "NaowhForever_Training"
local Load = dofile("Tools/regression/load_files.lua")

-- A mage tree: two rows of Arcane, one talent in Fire, and one Naowh build.
-- node = { spell, ranks, row, column, slot, the node it needs at full rank }.
local TREE = { [8] = {
    specs = { "Arcane", "Fire", "Frost" },
    talents = { [11] = { 1001, 3, 2, 1, 1, 12 }, [12] = { 1002, 1, 1, 1, 1 }, [13] = { 1003, 5, 1, 1, 2 },
        [14] = { 1004, 2, 2, 1, 2 }, [15] = { 1005, 5, 1, 2, 1 } },
    { name = "Arcane Leveling", spec = "Arcane", points = { 13, 13, 13, 13, 12, 11 } },
} }
-- A warrior tree, so a mage node in a warrior build can be caught.
TREE[1] = { specs = { "Arms", "Fury", "Protection" }, talents = { [21] = { 2001, 5, 1, 1, 1 } } }

-- The mage's trainer spells: two ranks of Fireball, Blink, and a quest spell that no trainer sells.
local SPELLS = { [8] = { { 1, 133, 0 }, { 6, 143, 100 }, { 12, 145, 600 }, { 20, 1953, 2000 },
    { 30, 777, 0, quest = true } } }
local SPELL_NAMES = { [133] = "Fireball", [143] = "Fireball", [145] = "Fireball", [1953] = "Blink",
    [777] = "Quest Spell" }

local function Fixture(o)
    o = o or {}
    local account, printed, changes = {}, {}, 0
    local bought, commits = {}, 0
    -- A stand-in codec: what goes into the payload and what comes back out is the point here.
    local vault = {}
    local env = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
            TrainingBuilds = TREE, TrainingData = SPELLS,
            Print = function(m) printed[#printed + 1] = m end,
            Confirm = o.confirm or function(_, yes) yes() end,
        },
        UnitClass = function() return "Mage", "MAGE", 8 end,
        C_Spell = { GetSpellName = function(id) return SPELL_NAMES[id] or ("Talent " .. id) end },
        wipe = function(t) for k in pairs(t) do t[k] = nil end end,
        GetClassInfo = function(id) return ({ [1] = "Warrior", [8] = "Mage" })[id] end,
        C_ClassTalents = { GetActiveConfigID = function() return o.config end },
        C_Traits = {
            GetNodeInfo = function(_, node)
                return { activeRank = (o.ranks or {})[node] or 0, entryIDs = { node + 9000 } }
            end,
            -- Buys while points are left: o.points of them.
            PurchaseRank = function(_, node)
                if (o.points or 0) <= #bought then return false end
                bought[#bought + 1] = node
                return true
            end,
            CommitConfig = function() commits = commits + 1; return true end,
        },
        InCombatLockdown = function() return o.combat == true end,
        LibStub = function(name)
            if name == "LibSerialize" then
                return {
                    Serialize = function(_, v)
                        vault[#vault + 1] = v
                        return "S" .. #vault
                    end,
                    Deserialize = function(_, str)
                        local k = tonumber(tostring(str):match("^S(%d+)$"))
                        if not (k and vault[k]) then return false, "bad string" end
                        return true, vault[k]
                    end,
                }
            end
            local same = function(_, v) return v end
            return { CompressDeflate = same, DecompressDeflate = same, EncodeForPrint = same, DecodeForPrint = same }
        end,
    }
    setmetatable(env, { __index = _G })
    env._G = env
    env.ns.Shared = { Decode = dofile("Tools/regression/load_decode.lua")(env, true) }
    -- What Training.lua gives the build file: the account store, the character's key, the
    -- change listeners and the event wiring.
    env.ns.Training = {
        Account = function(key)
            account[key] = account[key] or {}
            return account[key]
        end,
        Changed = function() changes = changes + 1 end,
        Apply = function() end,
        CharKey = function() return "Me-Realm" end,
    }
    env.NaowhForever = env.ns
    Load({ DIR .. "/Constants.lua", DIR .. "/Builds.lua" }, env)
    local training = env.ns.Training
    -- A share string as another player's copy of the addon would write it.
    local function Pack(data)
        vault[#vault + 1] = data
        return "!NFB1!S" .. #vault
    end
    return { T = training, Pack = Pack, Saved = function(class) return (account.trainingBuilds or {})[class] or {} end,
        Printed = printed, Changes = function() return changes end,
        Bought = function() return table.concat(bought, " ") end, Commits = function() return commits end }
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

local function Import(t, text)
    local got
    t.T.ImportBuild(text, function(class, index) got = { class, index } end)
    return got
end

Case("an exported build imports as a saved build of its class, shown after Naowh's", function()
    local t = Fixture()
    local text = t.T.ExportBuild(8, TREE[8][1])
    assert(text:sub(1, 6) == "!NFB1!", text)
    local got = Import(t, text)
    assert(got and got[1] == 8 and got[2] == 2, "onAdded")
    local list = t.T.Builds(8)
    assert(#list == 2 and list[2].saved and list[2].name == "Arcane Leveling", "listed")
    assert(table.concat(list[2].points, " ") == "13 13 13 13 12 11", table.concat(list[2].points, " "))
end)

Case("strings that are not a build, or break the tree, are turned away", function()
    local t = Fixture()
    local bad = {
        "hello",
        "!NBIS1!S1",
        t.Pack({ v = 2, class = 8, points = { 13 } }),
        t.Pack({ v = 1, class = 99, points = { 13 } }),
        t.Pack({ v = 1, class = 1, points = { 13 } }),
        t.Pack({ v = 1, class = 8, points = { 12, 12 } }),
        t.Pack({ v = 1, class = 8, points = {} }),
        t.Pack({ v = 1, class = 8, points = "13" }),
        t.Pack({ v = 1, class = 8, points = { "13" } }),
        t.Pack({ v = 1, class = 8, points = { 13, 13, 13, 13, 13, 11 } }),
        t.Pack({ v = 1, class = 8, points = { 12, 14 } }),
    }
    local many = {}
    for i = 1, 52 do many[i] = 13 end
    bad[#bad + 1] = t.Pack({ v = 1, class = 8, points = many })
    for i, text in ipairs(bad) do
        assert(Import(t, text) == nil, "accepted bad string " .. i)
    end
    assert(#t.Saved(8) == 0 and #t.Saved(1) == 0, "nothing saved")
    assert(#t.Printed == #bad, "each one said so")
end)

Case("an imported name is cut to 40 letters and cannot carry escape codes or line breaks", function()
    local t = Fixture()
    Import(t, t.Pack({ v = 1, class = 8, name = "|cffff0000Red\n" .. string.rep("x", 60), points = { 12 } }))
    local name = t.Saved(8)[1].name
    assert(not name:find("[|\n]") and #name == 40 and name:sub(1, 12) == "cffff0000Red", name)
    Import(t, t.Pack({ v = 1, class = 8, name = 5, spec = {}, points = { 12 } }))
    assert(t.Saved(8)[2].name == "Imported Build" and t.Saved(8)[2].spec == "Imported", "defaults")
    Import(t, t.Pack({ v = 1, class = 8, name = "|||", points = { 12 } }))
    assert(t.Saved(8)[3].name == "Imported Build", "nothing left of it")
end)

Case("a name shared and shared again comes back as it went", function()
    local t = Fixture()
    Import(t, t.Pack({ v = 1, class = 8, name = "A|B", spec = "Fire|Frost", points = { 12 } }))
    local first = t.Saved(8)[1]
    Import(t, t.T.ExportBuild(8, first))
    Import(t, t.T.ExportBuild(8, t.Saved(8)[2]))
    local third = t.Saved(8)[3]
    assert(third.name == first.name and third.spec == first.spec, third.name .. " / " .. third.spec)
end)

Case("a followed build is the one picked, even when another has its name", function()
    local t = Fixture()
    t.T.NewBuild(8, "Same")
    local secondIndex = t.T.NewBuild(8, "Same")
    local second = t.T.Builds(8)[secondIndex]
    t.T.Follow(8, second)
    assert(t.T.Followed() == second, "the second one")
    t.T.Follow(8, TREE[8][1])
    assert(t.T.Followed() == TREE[8][1], "a built-in one")
    t.T.Follow(8, nil)
    assert(t.T.Followed() == nil, "stopped")
end)

Case("deleting a followed build stops following it, and nothing else takes its place", function()
    local t = Fixture()
    local firstIndex = t.T.NewBuild(8, "Same")
    local first = t.T.Builds(8)[firstIndex]
    local secondIndex = t.T.NewBuild(8, "Same")
    local second = t.T.Builds(8)[secondIndex]
    t.T.Follow(8, second)
    t.T.DeleteBuild(8, second)
    assert(t.T.Followed() == nil, "not the other Same")
    t.T.Follow(8, first)
    local index = t.T.NewBuild(8, "Other")
    t.T.DeleteBuild(8, t.T.Builds(8)[index])
    assert(t.T.Followed() == first, "deleting another build leaves it")
end)

Case("saving your talents lists them row by row, each up to its ranks", function()
    local t = Fixture({ config = 1, ranks = { [11] = 2, [12] = 1, [13] = 5, [14] = 0 } })
    local class, index = t.T.SaveMyTalents("Mine")
    assert(class == 8 and index == 2, "where it went")
    local build = t.Saved(8)[1]
    assert(table.concat(build.points, " ") == "12 13 13 13 13 13 11 11", table.concat(build.points, " "))
    assert(build.name == "Mine" and build.saved, "named")
end)

Case("nothing is saved without talents or a talent config", function()
    local t = Fixture({ config = 1 })
    assert(t.T.SaveMyTalents("Mine") == nil and #t.Saved(8) == 0, "no points")
    local none = Fixture()
    assert(none.T.SaveMyTalents("Mine") == nil, "no config")
end)

Case("deleting a saved build removes only that one", function()
    local t = Fixture({ config = 1, ranks = { [12] = 1 } })
    t.T.SaveMyTalents("One")
    t.T.SaveMyTalents("Two")
    local first = t.Saved(8)[1]
    t.T.DeleteBuild(8, first)
    assert(#t.Saved(8) == 1 and t.Saved(8)[1].name == "Two", "kept the other")
    assert(#t.T.Builds(8) == 2, "Naowh's stays")
end)

Case("the rules: full ranks, the talent above at full rank, five points a row, 51 at most", function()
    local t, tree = Fixture(), TREE[8]
    assert(t.T.CheckBuild(tree, { 13, 13, 13, 13, 12, 11 }) == nil, "valid")
    assert(t.T.CheckBuild(tree, { 12, 12 }) == "Already at full rank.", "ranks")
    assert(t.T.CheckBuild(tree, { 13, 13, 13, 13, 13, 11 }) == "Needs Talent 1002 at full rank first.", "needs")
    assert(t.T.CheckBuild(tree, { 12, 15, 15, 15, 15, 14 }) == "Needs 5 points in Arcane first.", "row")
    assert(t.T.CheckBuild(tree, { 21 }) == "That talent is not in this class's tree.", "tree")
end)

Case("clicking talents builds the order, and a point a later one needs cannot be given back", function()
    local t, tree = Fixture(), TREE[8]
    local index = t.T.NewBuild(8, "Mine")
    local build = t.T.Builds(8)[index]
    assert(build.saved and #build.points == 0 and build.spec == "No points yet", "empty")
    for _ = 1, 4 do assert(t.T.AddPoint(tree, build, 13) == nil) end
    assert(t.T.AddPoint(tree, build, 11) == "Needs Talent 1002 at full rank first.", "blocked")
    assert(t.T.AddPoint(tree, build, 12) == nil and t.T.AddPoint(tree, build, 11) == nil, "then allowed")
    assert(t.T.AddPoint(tree, build, 15) == nil and build.spec == "Arcane", "spec follows the points")
    assert(t.T.RemovePoint(tree, build, 12):find("^A later point needs it"), "12 is needed")
    assert(t.T.RemovePoint(tree, build, 15) == nil, "15 is not")
    assert(table.concat(build.points, " ") == "13 13 13 13 12 11", table.concat(build.points, " "))
    t.T.UndoPoint(tree, build)
    assert(#build.points == 5, "undo")
    t.T.ClearPoints(build)
    assert(#build.points == 0 and build.spec == "No points yet", "clear")
end)

Case("a copy of a built-in build is a saved build of its own", function()
    local t = Fixture()
    local index = t.T.NewBuild(8, "Arcane Leveling Copy", TREE[8][1])
    local copy = t.T.Builds(8)[index]
    assert(index == 2 and copy.saved and copy.points ~= TREE[8][1].points, "own table")
    t.T.UndoPoint(TREE[8], copy)
    assert(#TREE[8][1].points == 6, "the built-in one is untouched")
end)

Case("a saved build skips a spell by every rank, learned or not, and quest spells are not offered", function()
    local t = Fixture()
    local index = t.T.NewBuild(8, "Skips")
    local build = t.T.Builds(8)[index]
    local groups = t.T.SkipGroups(8)
    assert(#groups == 2 and groups[1].name == "Fireball" and #groups[1].spells == 3 and groups[2].name == "Blink",
        "one group per spell, ranks together, no quest spell")
    assert(table.concat(groups[1].spells, " ") == "133 143 145" and table.concat(groups[1].levels, " ") == "1 6 12",
        "ranks by level")
    assert(t.T.SkipCount(build) == 0 and not t.T.IsSkipping(build, groups[1]))
    t.T.ToggleSkip(build, groups[1])
    assert(build.skip[133] and build.skip[143] and build.skip[145] and t.T.IsSkipping(build, groups[1])
        and t.T.SkipCount(build) == 3)
    t.T.ToggleSkip(build, groups[1])
    assert(build.skip == nil and t.T.SkipCount(build) == 0, "an empty list is not kept")
end)

Case("a single rank can be skipped, and the spell's row then skips the rest", function()
    local t = Fixture()
    local index = t.T.NewBuild(8, "Skips")
    local build = t.T.Builds(8)[index]
    local fireball = t.T.SkipGroups(8)[1]
    t.T.ToggleSkip(build, fireball, 3)
    assert(build.skip[145] and not build.skip[133] and not build.skip[143] and t.T.SkipCount(build) == 1, "rank 3 only")
    assert(t.T.IsSkipping(build, fireball, 3) and not t.T.IsSkipping(build, fireball, 1)
        and not t.T.IsSkipping(build, fireball), "the spell is not skipped as a whole")
    t.T.ToggleSkip(build, fireball)
    assert(t.T.SkipCount(build) == 3 and t.T.IsSkipping(build, fireball), "the spell's row skips every rank")
    t.T.ToggleSkip(build, fireball, 2)
    assert(build.skip[133] and not build.skip[143] and build.skip[145], "rank 2 back on its own")
    t.T.ToggleSkip(build, fireball)
    assert(t.T.SkipCount(build) == 3, "a partly skipped spell's row skips the rest")
end)

Case("a build saved before skips by rank still skips every rank of its spells", function()
    local t = Fixture()
    local index = t.T.NewBuild(8, "Old")
    local build = t.T.Builds(8)[index]
    build.skip = { [133] = true, [143] = true, [145] = true }
    local fireball = t.T.SkipGroups(8)[1]
    assert(t.T.IsSkipping(build, fireball), "the spell's row is ticked")
    for rank = 1, 3 do assert(t.T.IsSkipping(build, fireball, rank), "rank " .. rank) end
    local got = Import(t, t.Pack({ v = 1, class = 8, name = "Old String", spec = "x", points = TREE[8][1].points,
        skip = { 133, 143, 145 } }))
    local imported = t.T.Builds(8)[got[2]]
    assert(t.T.IsSkipping(imported, fireball) and t.T.SkipCount(imported) == 3, "an old string imports every rank")
end)

Case("a skip of one rank goes out in an export and comes back as it went", function()
    local t = Fixture()
    local index = t.T.NewBuild(8, "Rank Three", TREE[8][1])
    local build = t.T.Builds(8)[index]
    t.T.ToggleSkip(build, t.T.SkipGroups(8)[1], 3)
    local got = Import(t, t.T.ExportBuild(8, build))
    local imported = t.T.Builds(8)[got[2]]
    assert(imported.skip[145] and t.T.SkipCount(imported) == 1, "only rank 3")
    assert(table.concat(t.T.SkipList(imported), " ") == "145", "the list")
end)

Case("a talent's trait entry is read from your talent config, for your own class only", function()
    local t = Fixture({ config = 1 })
    assert(t.T.TalentEntry(8, 13) == 9013, "your class")
    assert(t.T.TalentEntry(1, 21) == nil, "another class")
    assert(Fixture().T.TalentEntry(8, 13) == nil, "no config")
end)

Case("Select All skips every rank of every spell, Clear empties the list", function()
    local t = Fixture()
    local index = t.T.NewBuild(8, "Skips")
    local build = t.T.Builds(8)[index]
    t.T.SkipAll(8, build, true)
    assert(t.T.SkipCount(build) == 4 and build.skip[133] and build.skip[143] and build.skip[145] and build.skip[1953])
    t.T.SkipAll(8, build, false)
    assert(build.skip == nil and t.T.SkipCount(build) == 0)
end)

Case("the skip list goes with an export, an import and a copy, and only the class's spells are kept", function()
    local t = Fixture()
    local index = t.T.NewBuild(8, "Skips", TREE[8][1])
    local build = t.T.Builds(8)[index]
    t.T.ToggleSkip(build, t.T.SkipGroups(8)[2])
    local got = Import(t, t.T.ExportBuild(8, build))
    local imported = t.T.Builds(8)[got[2]]
    assert(imported.skip[1953] and t.T.SkipCount(imported) == 1, "imported")
    got = Import(t, t.Pack({ v = 1, class = 8, name = "Odd", spec = "x", points = TREE[8][1].points,
        skip = { 1953, 143, 999, "Blink" } }))
    imported = t.T.Builds(8)[got[2]]
    assert(imported.skip[1953] and imported.skip[143] and not imported.skip[999] and t.T.SkipCount(imported) == 2,
        "unknown ids and non-numbers dropped")
    local at = t.T.NewBuild(8, "Copy", build)
    local copy = t.T.Builds(8)[at]
    assert(copy.skip[1953] and copy.skip ~= build.skip, "a copy has its own list")
end)

Case("every class has its tree, and any build that ships passes the rules", function()
    local data = assert(io.open(DIR .. "/Data/TrainingBuilds.lua", "rb")):read("*a")
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,}
    local chunk = assert(loadstring(data)); setfenv(chunk, { _G = { NaowhForever = ns } }); chunk()
    local t, classes = Fixture(), 0
    for class, tree in pairs(ns.TrainingBuilds) do
        assert(#tree.specs == 3 and next(tree.talents), "specs and talents " .. class)
        for _, build in ipairs(tree) do
            local why = t.T.CheckBuild(tree, build.points)
            assert(why == nil and #build.points > 0, class .. " " .. build.name .. ": " .. tostring(why))
            assert(type(build.source) == "string", "credited " .. build.name)
        end
        classes = classes + 1
    end
    assert(classes == 9, classes)
end)

Case("learning a build buys the points not taken, in order, while points last, then commits once", function()
    local t = Fixture({ config = 1, points = 3, ranks = { [13] = 2 } })
    assert(t.T.LearnBuild(8, TREE[8][1]) == 3, "three bought")
    assert(t.Bought() == "13 13 12", t.Bought())
    assert(t.Commits() == 1, "one commit")
    local none = Fixture({ config = 1, points = 0 })
    assert(none.T.LearnBuild(8, TREE[8][1]) == 0 and none.Commits() == 0, "nothing to spend, nothing committed")
end)

Case("no learning in combat, for another class, or without a talent config", function()
    local build = TREE[8][1]
    assert(Fixture({ config = 1, points = 5, combat = true }).T.LearnBuild(8, build) == 0, "combat")
    assert(Fixture({ config = 1, points = 5 }).T.LearnBuild(1, build) == 0, "another class")
    assert(Fixture({ points = 5 }).T.LearnBuild(8, build) == 0, "no config")
end)

Case("a followed build learns new points, but a talent reset asks before spending them again", function()
    local ranks, asked = {}, {}
    local t = Fixture({ config = 1, points = 30, ranks = ranks,
        confirm = function(text, yes, no) asked[#asked + 1] = { text = text, yes = yes, no = no } end })
    t.T.Follow(8, TREE[8][1])
    t.T.LearnFollowed()
    assert(t.Commits() == 1 and #asked == 0, "first points learned without asking")
    ranks[13] = 4
    t.T.LearnFollowed()
    assert(t.Commits() == 2 and #asked == 0, "more points learned without asking")
    ranks[13] = 0
    t.T.LearnFollowed()
    assert(t.Commits() == 2 and #asked == 1, "reset asks instead of learning")
    assert(asked[1].text:find("Arcane Leveling", 1, true), asked[1].text)
    t.T.LearnFollowed()
    assert(t.Commits() == 2 and #asked == 1, "no second ask or learn while the first is open")
    asked[1].no()
    assert(t.T.Followed() == nil, "declining stops following")
    t.T.Follow(8, TREE[8][1])
    ranks[13] = 4
    t.T.LearnFollowed()
    ranks[13] = 0
    t.T.LearnFollowed()
    asked[2].yes()
    assert(t.Commits() == 4 and t.T.Followed() ~= nil, "Learn Again learns and keeps following")
end)

Case("following a build again starts from the talents you have now", function()
    local ranks, asked = { [13] = 5 }, 0
    local t = Fixture({ config = 1, points = 30, ranks = ranks, confirm = function() asked = asked + 1 end })
    t.T.Follow(8, TREE[8][1])
    t.T.LearnFollowed()
    t.T.Follow(8, nil)
    ranks[13] = 0
    t.T.Follow(8, TREE[8][1])
    t.T.LearnFollowed()
    assert(asked == 0 and t.Commits() == 2, "no ask after a reset made while not following")
end)

print(("test-training-builds: %d cases passed"):format(count))

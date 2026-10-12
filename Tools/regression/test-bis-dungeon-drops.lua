-- BiS picker: below the spec's ranking it offers every dungeon drop for the slot that the
-- player's class can use and the ranking leaves out, near the player's level unless Show
-- All is on, highest required level first. What drops where is the Dungeon Journal's, so an
-- item's source is the Journal's boss and dungeon, and wowsrc's wording only for the rest.
local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local RULES = { "Shared/Shared.lua", "Shared/Style.lua", "Shared/Game/Items.lua", "Shared/Game/Gear.lua", "NaowhForever_BiS/BiS/BiS.lua", "NaowhForever_BiS/BiS/Constants.lua", "NaowhForever_BiS/BiS/Rankings.lua",
    "NaowhForever_BiS/BiS/Sources.lua" }
local SEP = " \194\183 "

local EQUIP = {
    [1] = "INVTYPE_HEAD", [2] = "INVTYPE_HEAD", [3] = "INVTYPE_HEAD", [4] = "INVTYPE_HEAD",
    [5] = "INVTYPE_HEAD", [6] = "INVTYPE_CLOAK", [7] = "INVTYPE_SHIELD", [8] = "INVTYPE_RELIC",
    [9] = "INVTYPE_WEAPON", [10] = "INVTYPE_WEAPONMAINHAND", [11] = "INVTYPE_RANGEDRIGHT",
    [12] = "INVTYPE_FINGER", [13] = "INVTYPE_HEAD", [14] = "INVTYPE_2HWEAPON",
}

-- [itemID] = { class, subclass, item level, required level, quality }, as the Journal's
-- Data/Items.lua, and the dungeon that drops it.
local FACTS = {
    [1] = { 4, 1, 20, 15, 3 }, [2] = { 4, 2, 30, 25, 3 }, [3] = { 4, 3, 45, 40, 3 }, [4] = { 4, 3, 35, 30, 3 },
    [5] = { 4, 4, 50, 45, 3 }, [6] = { 4, 0, 25, 20, 3 }, [7] = { 4, 6, 25, 20, 3 }, [8] = { 4, 8, 55, 50, 3 },
    [9] = { 2, 15, 25, 20, 3 }, [10] = { 2, 4, 25, 20, 3 }, [11] = { 2, 19, 25, 20, 3 }, [12] = { 4, 0, 25, 20, 3 },
    [13] = { 4, 2, 32, 25, 3 }, [14] = { 2, 6, 40, 35, 3 },
}

-- A dungeon a boss, its loot; and Trash Place's trash drops item 1 likelier than its boss.
local function Dungeons()
    local dungeons = {}
    for id = 1, 14 do
        dungeons[#dungeons + 1] = { name = "Place " .. id,
            wings = { { bosses = { { name = "Boss " .. id, loot = { id }, chance = { 10 } } } } } }
    end
    dungeons[#dungeons + 1] = { name = "Trash Place", wings = { { bosses = {
        { name = "Trash", trash = true, loot = { 1 }, chance = { 50 } },
    } } } }
    return dungeons
end

local function Env(ns, class, level)
    return setmetatable({
        _G = { NaowhForever = ns },
        UnitClass = function() return class, class end,
        UnitLevel = function() return level end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        C_Item = {
            GetItemInfoInstant = function(id)
                if EQUIP[id] then return id, "", "", EQUIP[id] end
            end,
            GetItemInfo = function() return nil end,
            GetItemNameByID = function(id) return "Item " .. id end,
        },
    }, { __index = _G })
end

-- With journal false, the Journal has not loaded.
local function Fixture(class, level, sources, journal)
    local list = Dungeons()
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, BiSData = { sources = sources or {}, specs = {} }, QoLSettings = {},
        Journal = journal ~= false and { Items = FACTS, Dungeons = function() return list end } or nil }
    Load(RULES, Env(ns, class, level))
    ns.Shared.ItemFacts = FACTS
    local R = ns.BiS.Rankings
    return { Usable = R.Usable, DungeonDrops = R.DungeonDrops, R = R, ns = ns }
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

local function Can(class, id) return Fixture(class, 30).Usable(class, FACTS[id]) end

Case("armor slots offer only the class's armor type", function()
    assert(Can("MAGE", 1) and not Can("MAGE", 2) and not Can("MAGE", 3))
    assert(Can("ROGUE", 2) and not Can("ROGUE", 1) and not Can("ROGUE", 3))
    assert(Can("PRIEST", 1) and Can("WARLOCK", 1) and Can("DRUID", 2))
end)

Case("hunters and shamans wear mail from 40, warriors and paladins plate", function()
    for _, class in ipairs({ "HUNTER", "SHAMAN" }) do
        assert(Can(class, 2) and Can(class, 13), class .. " leather before 40")
        assert(Can(class, 3) and not Can(class, 4), class .. " mail from 40 only")
    end
    for _, class in ipairs({ "WARRIOR", "PALADIN" }) do
        assert(Can(class, 4) and not Can(class, 3), class .. " mail before 40 only")
        assert(Can(class, 5) and not Can(class, 2), class .. " plate from 40")
    end
end)

Case("cloaks and rings are for everyone, shields and relics are not", function()
    for _, class in ipairs({ "MAGE", "ROGUE", "WARRIOR", "DRUID" }) do
        assert(Can(class, 6) and Can(class, 12), class)
    end
    assert(Can("WARRIOR", 7) and Can("PALADIN", 7) and Can("SHAMAN", 7))
    assert(not Can("MAGE", 7) and not Can("ROGUE", 7) and not Can("DRUID", 7))
    assert(Can("DRUID", 8) and not Can("SHAMAN", 8) and not Can("PALADIN", 8))
end)

Case("weapons follow the class's weapon skills", function()
    assert(Can("MAGE", 9) and Can("MAGE", 11) and not Can("MAGE", 10) and not Can("MAGE", 14))
    assert(Can("PRIEST", 10) and Can("PRIEST", 11))
    assert(Can("ROGUE", 9) and Can("ROGUE", 10) and not Can("ROGUE", 11) and not Can("ROGUE", 14))
    assert(not Can("DRUID", 14) and Can("WARRIOR", 14) and Can("HUNTER", 14) and Can("PALADIN", 14))
    assert(not Can("PALADIN", 9) and not Can("WARRIOR", 11) and not Can("HUNTER", 10))
end)

local function List(t) return table.concat(t, ",") end

Case("the list is the slot's usable drops, highest required level first", function()
    local m = Fixture("HUNTER", 40)
    assert(List(m.DungeonDrops(1, {}, false)) == "3,13,2", List(m.DungeonDrops(1, {}, false)))
    m = Fixture("WARRIOR", 40)
    assert(List(m.DungeonDrops(1, {}, false)) == "5,4")
end)

Case("items in the ranking are left out", function()
    local m = Fixture("HUNTER", 40)
    assert(List(m.DungeonDrops(1, { 13, 99 }, false)) == "3,2")
end)

Case("near keeps drops within 10 levels of yours", function()
    local m = Fixture("HUNTER", 35)
    assert(List(m.DungeonDrops(1, {}, true)) == "3,13,2")
    m = Fixture("HUNTER", 50)
    assert(List(m.DungeonDrops(1, {}, true)) == "3")
    m = Fixture("HUNTER", 10)
    assert(List(m.DungeonDrops(1, {}, true)) == "" and List(m.DungeonDrops(1, {}, false)) == "3,13,2")
end)

Case("a drop is offered in every slot it fits", function()
    local m = Fixture("ROGUE", 20)
    assert(List(m.DungeonDrops(16, {}, true)) == "9,10", "one-hand and main-hand")
    assert(List(m.DungeonDrops(17, {}, true)) == "9", "one-hand in the off hand")
    assert(List(m.DungeonDrops(11, {}, true)) == "12" and List(m.DungeonDrops(12, {}, true)) == "12")
    assert(List(m.DungeonDrops(15, {}, true)) == "6")
    m = Fixture("WARRIOR", 20)
    assert(List(m.DungeonDrops(17, {}, true)) == "7,9")
end)

Case("only classes that dual wield get weapons in the off hand", function()
    local m = Fixture("PRIEST", 20)
    assert(List(m.DungeonDrops(16, {}, true)) == "9,10")
    assert(List(m.DungeonDrops(17, {}, true)) == "")
    m = Fixture("PALADIN", 20)
    assert(List(m.DungeonDrops(17, {}, true)) == "7", "a shield, no weapon")
end)

Case("an item's source is the Journal's boss and dungeon, a boss before trash", function()
    local m = Fixture("MAGE", 20)
    assert(m.ns.BiSSource(2) == "Boss 2" .. SEP .. "Place 2")
    assert(m.ns.BiSSource(1) == "Boss 1" .. SEP .. "Place 1", m.ns.BiSSource(1))
end)

Case("the Journal's wording wins over wowsrc's; wowsrc's for what drops nowhere", function()
    local m = Fixture("MAGE", 20, { [2] = "Boss 2" .. SEP .. "Old Name", [99] = "Crafted" })
    assert(m.ns.BiSSource(2) == "Boss 2" .. SEP .. "Place 2" and m.ns.BiSSource(99) == "Crafted")
    assert(m.ns.BiSSource(100) == nil)
end)

Case("an item not in Forever yet drops nowhere: no source, never offered", function()
    local m = Fixture("MAGE", 20, { [2] = "Boss 2" .. SEP .. "Old Name" })
    m.ns.Journal.NotYet = { [1] = FACTS[1], [2] = FACTS[2] }
    m.ns.Journal.Items = { [3] = FACTS[3] }
    m.ns.Shared.ItemFacts = m.ns.Journal.Items
    assert(m.ns.BiSSource(2) == "Boss 2" .. SEP .. "Old Name" and m.R.DropDungeon(1) == nil)
    assert(List(m.DungeonDrops(1, {}, true)) == "")
end)

Case("levels are the shared facts, with or without the Journal", function()
    local m = Fixture("MAGE", 20)
    assert(m.R.ReqLevel(3) == 40 and m.R.ItemLevel(3) == 45 and m.R.ItemLevel(100) == nil)
    m = Fixture("MAGE", 20, nil, false)
    assert(m.R.ReqLevel(3) == 40 and m.R.ItemLevel(3) == 45)
end)

Case("before the Journal loads, nothing drops and wowsrc's wording stands", function()
    local m = Fixture("MAGE", 20, { [2] = "Quest" }, false)
    assert(List(m.DungeonDrops(1, {}, false)) == "" and m.ns.BiSSource(2) == "Quest")
end)

-- Ranked items that neither wowsrc nor the Journal gives a source for.
local UNSOURCED = {}
for _, id in ipairs({ 5821, 263435, 263436, 270039, 270046, 272996, 276727, 277213, 277219,
    277227, 277257, 279392, 279393, 281264, 281290, 281309, 281323, 281660, 281675, 281926,
    284187, 284386, 284668, 285331, 286535,
    -- wowsrc's lists of 2 Oct 2026: none on Wowhead's item pages either.
    7948, 276719, 281263, 281295, 281693, 281694, 281702, 285351,
    -- wowsrc's lists of 3 Oct 2026 (the daily watch's #49): no source on wowsrc, and none on
    -- Wowhead's item pages either (build/bis_data.py --sources-only found the rest).
    2944, 7949, 7950, 7952, 7953, 8663, 213105, 270065, 270066, 270073,
    270076, 270077, 270082, 270083, 271720, 274042, 274068, 274149, 274915, 274916,
    274919, 274920, 274928, 274929, 274938, 274939, 274940, 274941, 274942, 274943,
    274944, 274946, 274948, 276102, 276897, 278019, 281308, 282642, 282658, 284382,
    284383, 284399, 284401, 284403, 284697, 285190, 285192,
    -- wowsrc's lists read again on 3 Oct 2026, with Wowhead (build/bis_data.py): no source
    -- on either.
    282653, 282710, 284459,
    -- wowsrc's lists of 11 Oct 2026 (the daily watch's #379): no source on wowsrc, nor on
    -- Wowhead's item pages (build/bis_data.py, 12 Oct).
    274955, 274957, 274963, 286987, 286988, 286989 }) do UNSOURCED[id] = true end

Case("every ranked item has a source, from the Journal's dungeons or wowsrc", function()
    local dungeons = {}
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QoLSettings = {}, Shared = {}, Journal = {
        AddDungeon = function(_, dungeon) dungeons[#dungeons + 1] = dungeon end,
        Dungeons = function() return dungeons end,
    } }
    local env = Env(ns, "MAGE", 60)
    local files = { "NaowhForever_BiS/BiS/Data/BiS.lua", "Shared/Data/ItemFacts.lua", "Shared/Data/FactionItems.lua",
        "NaowhForever_DungeonJournal/Data/Items.lua" }
    for _, path in ipairs(TocFiles("^NaowhForever_DungeonJournal/Data/Dungeons/.*%.lua$")) do files[#files + 1] = path end
    Load(files, env)
    Load(RULES, env)
    -- Each item once, in the order first met: the daily watch quotes this line.
    local missing, named = {}, {}
    for _, spec in ipairs(ns.BiSData.specs) do
        for _, ids in pairs(spec.slots) do
            for _, id in ipairs(ids) do
                if not ns.BiSSource(id) and not UNSOURCED[id] and not named[id] then
                    named[id] = true
                    missing[#missing + 1] = id
                end
            end
        end
    end
    assert(#missing == 0, "no source: " .. table.concat(missing, ", "))
    assert(#dungeons > 30, #dungeons)
end)

Case("a click on a source: the dungeon in the Journal, on the item; a faction; a quest", function()
    local f = Fixture("MAGE", 30)
    local ns, J = f.ns, f.ns.Journal
    local kirinTor = { name = "Kirin Tor", tiers = { { items = { 15 } } } }
    J.Factions = function(tab) return tab == "reputation" and { kirinTor } or {} end
    J.BiSQuestRewards = { [500] = { 16 } }
    local Sources = ns.BiS.Sources
    local kind, dungeon = Sources.Of(2)
    assert(kind == "dungeon" and dungeon == J.Dungeons()[2], kind)
    assert(Sources.Of(1) == "dungeon" and select(2, Sources.Of(1)).name == "Place 1",
        "its boss's dungeon before trash, as its source says")
    assert(Sources.Hint(2) == "Click: open it in the Dungeon Journal")
    local opened, stepped
    ns.BiS.StepAside = function(reason) stepped = reason end
    ns.BiS.BackFromJournal = function() end
    ns.OpenJournalWindow = function(page, back, text, itemID) opened = { page, back, text, itemID } end
    Sources.Go(2)
    assert(stepped == "journal" and opened[1] == dungeon and opened[2] == ns.BiS.BackFromJournal
        and opened[4] == 2, "the BiS List steps aside and the Journal opens on the item")
    kind, dungeon = Sources.Of(15)
    assert(kind == "faction" and dungeon == kirinTor and Sources.Hint(15) == "Click: open Kirin Tor in the Dungeon Journal")
    assert(Sources.Of(16) == "quest" and select(2, Sources.Of(16)) == 500)
end)

print(("%d cases passed"):format(count))

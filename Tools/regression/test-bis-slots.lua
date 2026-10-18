-- The BiS list keeps a ranked list of picks per gear slot, #1 being the BiS. Old flat lists,
-- the unordered secondary picks of the 0.5.12 test builds and version 1 to 3 share strings
-- must land in the right slots and order. A two-hander as the main hand's #1 leaves the
-- off-hand's picks unused but never removes them.
local Load = dofile("Tools/regression/load_files.lua")

-- The BiS List's rules, on what they share.
local FILES = { "Shared/Shared.lua", "Shared/Style.lua", "Shared/Game/Items.lua", "Shared/Game/Gear.lua", "NaowhForever_BiS/BiS/BiS.lua", "NaowhForever_BiS/BiS/Constants.lua", "NaowhForever_BiS/BiS/Rankings.lua",
    "NaowhForever_BiS/BiS/Lists.lua", "NaowhForever_BiS/BiS/Sharing.lua", "NaowhForever_BiS/BiS/Sources.lua" }

-- itemID -> equip location, standing in for C_Item.GetItemInfoInstant.
local EQUIP = {
    [101] = "INVTYPE_HEAD", [102] = "INVTYPE_HEAD", [103] = "INVTYPE_HEAD", [104] = "INVTYPE_HEAD",
    [105] = "INVTYPE_HEAD",
    [201] = "INVTYPE_FINGER", [202] = "INVTYPE_FINGER", [203] = "INVTYPE_FINGER",
    [301] = "INVTYPE_2HWEAPON", [302] = "INVTYPE_WEAPON", [303] = "INVTYPE_HOLDABLE",
    [304] = "INVTYPE_SHIELD",
    [401] = "INVTYPE_WAND",
}

local SPECS = {
    { class = "MAGE", key = "fire-mage", name = "Fire Mage", slots = { [1] = { 103, 102, 104 }, [11] = { 202, 201 } } },
    { class = "MAGE", key = "frost-mage", name = "Frost Mage", slots = { [1] = { 104, 103, 102 } } },
}

-- worn: slot -> item ID you wear there; carried: item ID -> how many in your bags and bank.
local function Fixture(saved, char, worn, carried)
    local e = { account = { bis = saved }, printed = {} }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,}
    ns.Print = function(m) e.printed[#e.printed + 1] = m end
    ns.AccountSettings = function() return e.account end
    ns.QoLSettings = { Get = function() return true end }
    ns.THEME = { accent = {}, muted = {}, panel = {}, line = {} }
    ns.UI = { RefreshPage = function() end }
    ns.Confirm = function(_, yes) yes() end
    ns.BiSData = { specs = SPECS, sources = {} }

    -- A stand-in codec: what these cases care about is the payload, not how it is packed.
    local vault = {}
    local frame = { SetScript = function() end, RegisterEvent = function() end }
    local env = setmetatable({ NaowhForever = ns,
        UnitName = function() return char or "Tester" end,
        UnitClass = function() return "Mage", "MAGE" end,
        GetRealmName = function() return "Realm" end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        GetInventoryItemID = function(_, slot) return worn and worn[slot] end,
        C_Item = {
            GetItemInfoInstant = function(id)
                if EQUIP[id] then return id, "", "", EQUIP[id] end
            end,
            GetItemNameByID = function(id) return "Item" .. id end,
            GetItemCount = function(id, bank) return bank and carried and carried[id] or 0 end,
        },
        TooltipDataProcessor = { AddTooltipPostCall = function() end },
        Enum = { TooltipDataType = { Item = 0 } },
        hooksecurefunc = function() end,
        CreateFrame = function() return frame end,
        LibStub = function(name)
            if name == "LibSerialize" then
                return {
                    Serialize = function(_, v)
                        local function Copy(t)
                            if type(t) ~= "table" then return t end
                            local out = {}
                            for k, x in pairs(t) do out[k] = Copy(x) end
                            return out
                        end
                        vault[#vault + 1] = Copy(v); return "S" .. #vault
                    end,
                    Deserialize = function(_, str)
                        local k = tonumber(tostring(str):match("^S(%d+)$"))
                        if not k or not vault[k] then return false end
                        return true, vault[k]
                    end,
                }
            end
            local same = function(_, v) return v end
            return { CompressDeflate = same, DecompressDeflate = same,
                EncodeForPrint = same, DecodeForPrint = same }
        end,
    }, { __index = _G })
    env._G = env
    Load(FILES, env)
    ns.Shared.Decode = dofile("Tools/regression/load_decode.lua")(env, true)
    e.ns, e.vault = ns, vault
    return e
end

-- The list this character is using, from its class's lists.
local function Saved(e)
    e.ns.IsBisItem(0)   -- any read runs the one-time moves
    for _, list in ipairs(e.account.bisLists.MAGE.lists) do
        if list.id == e.account.bisActive["Tester-Realm"] then return list end
    end
end

-- A slot's picks in order, #1 first.
local function Picks(e, slot)
    local list = Saved(e)
    local out = { list.slots[slot] }
    for _, id in ipairs(list.extra[slot] or {}) do out[#out + 1] = id end
    return table.concat(out, ",")
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("an old flat list moves into slots and names what did not fit", function()
    local e = Fixture({ ["Tester-Realm"] = { name = "Old", items = { 101, 201, 202, 203, 301, 102 } } })
    local s = Saved(e).slots
    assert(s[1] == 101 and s[11] == 201 and s[12] == 202 and s[16] == 301, "placed")
    assert(Saved(e).items == nil, "flat list dropped")
    assert(#e.printed == 1 and e.printed[1]:find("Item203") and e.printed[1]:find("Item102"), "leftovers named")
end)

Case("an old one-item-per-slot list keeps its items as BiS picks", function()
    local e = Fixture({ ["Tester-Realm"] = { name = "Mine", slots = { [1] = 101, [16] = 301 } } })
    assert(Picks(e, 1) == "101" and Picks(e, 16) == "301" and next(Saved(e).extra) == nil)
    assert(e.ns.IsBisItem(101) == 1 and e.ns.IsBisItem(301) == 1 and #e.printed == 0)
end)

Case("unordered secondary picks become ranked picks behind the BiS, once", function()
    local e = Fixture({ ["Tester-Realm"] = { name = "Mine", spec = "fire-mage",
        slots = { [1] = 101, [16] = 301 },
        extra = { [1] = { [104] = true, [105] = true, [102] = true, [103] = true },
            [11] = { [201] = true, [202] = true }, [17] = { [303] = true } } } })
    assert(Picks(e, 1) == "101,103,102,104,105", "ranked order, unranked last")
    assert(Picks(e, 11) == "202,201", "first ranked secondary becomes #1")
    assert(Picks(e, 16) == "301" and Picks(e, 17) == "303", "off-hand kept beside a two-hander")
    assert(#e.printed == 0)
    assert(e.ns.IsBisItem(101) == 1 and e.ns.IsBisItem(103) == 2 and e.ns.IsBisItem(105) == 5)
    Saved(e).extra[1][1] = 104
    e.ns.RemoveBisItem(999)   -- any change reads the list again
    assert(Picks(e, 1) == "101,104,102,104,105" and #e.printed == 0, "arrays are left alone")
end)

Case("picks append in order, #1 first, and a pick is listed once per slot", function()
    local e = Fixture()
    e.ns.AddBisPick(1, 101); e.ns.AddBisPick(1, 102); e.ns.AddBisPick(1, 103); e.ns.AddBisPick(1, 102)
    assert(Picks(e, 1) == "101,102,103")
    assert(e.ns.IsBisItem(101) == 1 and e.ns.IsBisItem(102) == 2 and e.ns.IsBisItem(103) == 3)
end)

Case("an item in two slots reports its best pick number", function()
    local e = Fixture()
    e.ns.AddBisPick(11, 201); e.ns.AddBisPick(12, 202); e.ns.AddBisPick(12, 201)
    assert(e.ns.IsBisItem(201) == 1 and e.ns.IsBisItem(202) == 1)
end)

Case("picks move up and down, and stop at the ends", function()
    local e = Fixture()
    e.ns.AddBisPick(1, 101); e.ns.AddBisPick(1, 102); e.ns.AddBisPick(1, 103)
    e.ns.MoveBisPick(1, 103, -1)
    assert(Picks(e, 1) == "101,103,102")
    e.ns.MoveBisPick(1, 103, -1)
    assert(Picks(e, 1) == "103,101,102" and e.ns.IsBisItem(103) == 1, "new BiS")
    e.ns.MoveBisPick(1, 103, -1); e.ns.MoveBisPick(1, 102, 1)
    assert(Picks(e, 1) == "103,101,102", "ends")
    e.ns.MoveBisPick(1, 103, 1)
    assert(Picks(e, 1) == "101,103,102")
end)

Case("removing a pick closes the gap, and removing #1 moves #2 up", function()
    local e = Fixture()
    e.ns.AddBisPick(1, 101); e.ns.AddBisPick(1, 102); e.ns.AddBisPick(1, 103)
    e.ns.RemoveBisPick(1, 102)
    assert(Picks(e, 1) == "101,103")
    e.ns.RemoveBisPick(1, 101)
    assert(Picks(e, 1) == "103" and Saved(e).extra[1] == nil)
    e.ns.RemoveBisPick(1, 103)
    assert(Saved(e).slots[1] == nil and Saved(e).extra[1] == nil and not e.ns.IsBisItem(103))
end)

Case("a two-hander #1 never removes the off-hand picks", function()
    local e = Fixture()
    e.ns.AddBisPick(17, 303); e.ns.AddBisPick(17, 304); e.ns.AddBisPick(16, 301)
    assert(Picks(e, 16) == "301" and Picks(e, 17) == "303,304" and #e.printed == 0)
    e.ns.AddBisPick(16, 302); e.ns.MoveBisPick(16, 302, -1)
    assert(Picks(e, 16) == "302,301" and Picks(e, 17) == "303,304", "one-hander moved up")
    e.ns.RemoveBisPick(16, 302)
    assert(Picks(e, 16) == "301" and Picks(e, 17) == "303,304", "two-hander promoted by a removal")
    assert(e.ns.IsBisItem(303) == 1 and #e.printed == 0, "still on the list, nothing said")
end)

Case("Alt+Shift fills the free ring slots, then appends to Ring 1", function()
    local e = Fixture()
    e.ns.AddBisItem(201); e.ns.AddBisItem(202); e.ns.AddBisItem(203)
    assert(Picks(e, 11) == "201,203" and Picks(e, 12) == "202")
    assert(e.ns.IsBisItem(203) == 2, "lookup follows")
    assert(e.printed[#e.printed]:find("as #2"), "said so")
end)

Case("Alt+Shift fills an empty hand even beside a two-hander", function()
    local e = Fixture()
    e.ns.AddBisItem(301); e.ns.AddBisItem(303); e.ns.AddBisItem(302)
    assert(Picks(e, 16) == "301,302" and Picks(e, 17) == "303", "one-hander appended to the main hand")
    e = Fixture()
    e.ns.AddBisItem(303); e.ns.AddBisItem(301)
    assert(Picks(e, 17) == "303" and Picks(e, 16) == "301")
end)

Case("a one-hander goes to the off-hand when the main hand is taken", function()
    local e = Fixture()
    e.ns.AddBisItem(302); e.ns.AddBisItem(303)
    assert(Picks(e, 16) == "302" and Picks(e, 17) == "303")
end)

Case("an old list with a two-hander and an off-hand keeps both", function()
    local e = Fixture({ ["Tester-Realm"] = { name = "Old", items = { 301, 303 } } })
    assert(Picks(e, 16) == "301" and Picks(e, 17) == "303" and #e.printed == 0)
end)

Case("an import keeps a two-hander and an off-hand, and can list one weapon twice", function()
    local e = Fixture()
    e.vault[1] = { v = 2, name = "Hands", slots = { [16] = 301, [17] = 303 } }
    assert(e.ns.ImportBisList("!NBIS1!S1", true))
    assert(Picks(e, 16) == "301" and Picks(e, 17) == "303", "both kept")
    e.vault[2] = { v = 2, name = "Daggers", slots = { [16] = 302, [17] = 302 } }
    assert(e.ns.ImportBisList("!NBIS1!S2", true))
    assert(Picks(e, 16) == "302" and Picks(e, 17) == "302", "same dagger in both hands")
end)

Case("adding a listed item again does nothing, even with the BiS toggle off", function()
    local e = Fixture()
    e.ns.QoLSettings.Get = function() return false end
    e.ns.AddBisItem(201); e.ns.AddBisItem(201); e.ns.AddBisItem(101); e.ns.AddBisItem(101)
    assert(Picks(e, 11) == "201" and Picks(e, 12) == "" and Picks(e, 1) == "101", "no second copy")
    assert(#e.printed == 2, "no second line")
end)

Case("an item that cannot be equipped is refused", function()
    local e = Fixture()
    e.ns.AddBisItem(999)
    assert(next(Saved(e).slots) == nil and e.printed[1]:find("not an item you can equip"))
end)

Case("export and import round-trip the ordered picks, name and spec", function()
    local e = Fixture()
    e.ns.AddBisPick(1, 104); e.ns.AddBisPick(1, 101); e.ns.AddBisPick(1, 103); e.ns.AddBisItem(201)
    local list = Saved(e)
    list.name, list.spec = "Mine", "fire-mage"
    local text = e.ns.ExportBisList()
    assert(e.vault[1].v == 4, "version 4")
    e.ns.AddBisItem(301); e.ns.RemoveBisPick(1, 101)
    list.name, list.spec = "Changed", "frost-mage"
    assert(e.ns.ImportBisList(text, true))
    list = Saved(e)
    assert(list.name == "Mine" and list.spec == "fire-mage", "name and spec")
    assert(Picks(e, 1) == "104,101,103" and Picks(e, 11) == "201" and Picks(e, 16) == "", "picks")
    assert(e.ns.IsBisItem(103) == 3)
    assert(e.printed[#e.printed]:find("4 items"), "counted")
end)

Case("a version 2 string imports its items as BiS picks", function()
    local e = Fixture()
    e.ns.AddBisPick(1, 101); e.ns.AddBisPick(1, 102)
    e.vault[1] = { v = 2, name = "Robin's", spec = "fire-mage", slots = { [1] = 101, [11] = 201, [16] = 301 } }
    assert(e.ns.ImportBisList("!NBIS1!S1", true))
    local list = Saved(e)
    assert(list.name == "Robin's" and list.spec == "fire-mage", "name and spec")
    assert(Picks(e, 1) == "101" and Picks(e, 11) == "201" and Picks(e, 16) == "301", "slots")
    assert(next(list.extra) == nil and not e.ns.IsBisItem(102), "replaced the old picks")
end)

Case("a version 2 string loses items that do not fit their slot", function()
    local e = Fixture()
    e.vault[1] = { v = 2, name = "Bad", slots = { [1] = 201, [2] = 999, [11] = 1.5, [99] = 101, [12] = 202 } }
    assert(e.ns.ImportBisList("!NBIS1!S1", true))
    local s = Saved(e).slots
    assert(s[1] == nil and s[2] == nil and s[11] == nil and s[99] == nil and s[12] == 202)
end)

Case("a version 3 string ranks its secondary picks by the string's spec and drops misfits", function()
    local e = Fixture()
    e.vault[1] = { v = 3, name = "Old", spec = "frost-mage", slots = { [1] = 101 }, extra = {
        [1] = { [101] = true, [102] = true, [103] = true, [104] = true, [201] = true, [999] = true, [1.5] = true },
        [2] = "x", [99] = { [101] = true }, [11] = { [202] = "yes", [203] = true },
    } }
    assert(e.ns.ImportBisList("!NBIS1!S1", true))
    local list = Saved(e)
    assert(Picks(e, 1) == "101,104,103,102", "frost ranking, BiS not repeated")
    assert(list.extra[2] == nil and list.extra[99] == nil, "bad slots dropped")
    assert(Picks(e, 11) == "203", "only true marks, moved up to #1")
end)

Case("a version 4 string drops misfits and repeats and fills a missing #1", function()
    local e = Fixture()
    e.vault[1] = { v = 4, name = "New", slots = { [1] = 101 }, extra = {
        [1] = { 103, 101, 201, 103, 1.5, 102 }, [12] = { 202, 201 }, [17] = { 303 }, [3] = "x",
    } }
    assert(e.ns.ImportBisList("!NBIS1!S1", true))
    assert(Picks(e, 1) == "101,103,102" and Picks(e, 12) == "202,201" and Picks(e, 17) == "303")
    assert(Saved(e).extra[3] == nil)
end)

Case("a version 1 string is placed like an old saved list", function()
    local e = Fixture()
    e.vault[1] = { v = 1, name = "Old share", items = { 101, 201, 202, 301 } }
    assert(e.ns.ImportBisList("!NBIS1!S1", true))
    local s = Saved(e).slots
    assert(s[1] == 101 and s[11] == 201 and s[12] == 202 and s[16] == 301)
end)

Case("something that is not a BiS string is refused", function()
    local e = Fixture()
    assert(e.ns.ImportBisList("hello", true) == false)
    assert(e.printed[#e.printed]:find("not a Naowh BiS list"))
end)

Case("removing takes the item out of every slot that holds it", function()
    local e = Fixture()
    e.ns.AddBisItem(201); e.ns.AddBisItem(202); e.ns.AddBisItem(203); e.ns.AddBisPick(12, 203)
    e.ns.RemoveBisItem(201); e.ns.RemoveBisItem(203)
    assert(Picks(e, 11) == "" and Picks(e, 12) == "202" and not e.ns.IsBisItem(203))
end)

Case("an item ID, a link or a Wowhead URL all read as the item", function()
    local e = Fixture()
    e.ns.AddBisItem("101"); e.ns.AddBisItem("|Hitem:102::|h[x]|h"); e.ns.AddBisItem("https://www.wowhead.com/forever/item=201/ring")
    assert(Picks(e, 1) == "101,102" and Picks(e, 11) == "201")
end)

-- Run Next, against a list and what is worn and carried.
local function RunNextFixture(sources, worn, carried)
    local e = Fixture(nil, nil, worn, carried)
    e.ns.BiSData.sources = sources
    local R = e.ns.BiS.Rankings
    return R.RunNext, R.Place
end

local DOT = " \194\183 "

Case("run next ranks a quest's reward by its gain, named by the quest; a world drop is nowhere", function()
    local e = Fixture()
    e.ns.BiSData.sources = { [101] = "Boss A" .. DOT .. "Scholomance", [102] = "The Horn of Xelthos" .. DOT .. "Quest",
        [103] = "World drop" }
    e.ns.Journal = { BiSQuestRewards = { [500] = { 102 } } }
    local list = { slots = { [1] = 101, [11] = 102, [3] = 103 } }
    local out = e.ns.BiS.Rankings.RunNext(list, { [1] = 3, [11] = 18 })
    assert(#out == 2, #out)
    assert(out[1].name == "The Horn of Xelthos" and out[1].kind == "quest" and out[1].via == 102 and out[1].gain == 18,
        "the quest first, its +18% beats the dungeon's +3%")
    assert(out[2].name == "Scholomance" and out[2].via == nil)
end)

Case("run next counts BiS picks you do not have by place, most first, at most three", function()
    local RunNext = RunNextFixture({
        [101] = "Boss A" .. DOT .. "Scholomance", [102] = "Boss B" .. DOT .. "Scholomance",
        [103] = "Boss C" .. DOT .. "Stratholme", [104] = "Crafted", [105] = "Boss D" .. DOT .. "Maraudon",
        [106] = "Boss E" .. DOT .. "Scholomance",
    }, { [3] = 103 }, { [104] = 1 })
    local list = { slots = { [1] = 101, [2] = 102, [3] = 103, [11] = 104, [12] = 105 } }
    local out = RunNext(list)
    assert(#out == 2 and out[1].name == "Scholomance" and out[1].bis == 2, "worn and carried left out")
    assert(out[2].name == "Maraudon" and out[2].bis == 1)
    list.slots[3], list.slots[11] = 106, 107   -- 107 has no source
    out = RunNext(list)
    assert(out[1].bis == 3 and #out == 2, "unlisted sources are not a place")
end)

Case("run next ties go by name and stop at three", function()
    local RunNext = RunNextFixture({ [1] = "Zul'Farrak", [2] = "Dire Maul", [3] = "Uldaman",
        [4] = "Boss" .. DOT .. "Blackrock Depths", [5] = "Gnomeregan" }, {}, {})
    local out = RunNext({ slots = { [1] = 1, [2] = 2, [3] = 3, [11] = 4, [12] = 5 } })
    assert(#out == 3 and out[1].name == "Blackrock Depths" and out[2].name == "Dire Maul"
        and out[3].name == "Gnomeregan")
    assert(#RunNext({ slots = {} }) == 0, "nothing picked, nothing shown")
end)

Case("an off-hand pick left unused by a two-hander is not a place to run", function()
    local RunNext = RunNextFixture({ [301] = "Boss" .. DOT .. "Scholomance", [302] = "Boss" .. DOT .. "Scholomance",
        [303] = "Boss" .. DOT .. "Stratholme" }, {}, {})
    local list = { slots = { [16] = 302, [17] = 303 } }
    assert(#RunNext(list) == 2)
    list.slots[16] = 301
    local out = RunNext(list)
    assert(#out == 1 and out[1].name == "Scholomance")
end)

Case("crafted, quest, world drop and reputation picks are not a place to go", function()
    local RunNext = RunNextFixture({ [1] = "Crafted", [2] = "Quest (Horde)", [3] = "World drop",
        [4] = "Ruins of Lordaeron Quest" .. DOT .. "Quest Reward", [5] = "Ratchet - Friendly" .. DOT .. "Reputation",
        [6] = "Grazlix" .. DOT .. "The Barrens" }, {}, {})
    local out = RunNext({ slots = { [1] = 1, [2] = 2, [3] = 3, [11] = 4, [12] = 5, [16] = 6 } })
    assert(#out == 1 and out[1].name == "The Barrens")
end)

Case("a ring worn in the other ring slot counts as had", function()
    local RunNext = RunNextFixture({ [201] = "Onyxia" }, { [12] = 201 }, {})
    assert(#RunNext({ slots = { [11] = 201 } }) == 0)
end)

Case("a source splits into place and boss at the last middle dot", function()
    local _, Place = RunNextFixture({}, {}, {})
    local place, detail = Place("Quest" .. DOT .. "Boss" .. DOT .. "Blackrock Spire")
    assert(place == "Blackrock Spire" and detail == "Quest" .. DOT .. "Boss")
    place, detail = Place("World Drop")
    assert(place == "World Drop" and detail == nil)
end)


Case("an old per-character list joins its class's lists, named for the character", function()
    local e = Fixture({ ["Tester-Realm"] = { name = "My BiS", slots = { [1] = 101 } } })
    local list = Saved(e)
    assert(list.name == "Tester" and list.slots[1] == 101, "moved and named")
    assert(e.account.bis["Tester-Realm"] == nil and #e.account.bisLists.MAGE.lists == 1, "moved once")
end)

Case("every character of a class sees its lists and keeps its own choice", function()
    local e = Fixture()
    e.ns.IsBisItem(0)
    assert(e.ns.NewBisList("Tank"))
    local alt = Fixture(nil, "Alt")
    alt.account = e.account
    local values, order, active = alt.ns.BisListChoices()
    assert(#order == 2 and values[order[2]] == "Tank", "shared")
    assert(active == order[1] and Saved(e).name == "Tank", "each keeps its own")
end)

Case("lists are made, renamed and deleted, and names stay unique", function()
    local e = Fixture()
    assert(e.ns.NewBisList("Raid"))
    assert(not e.ns.NewBisList(" raid "), "taken, ignoring case and spaces")
    assert(not e.ns.RenameBisList("   "), "empty")
    assert(e.ns.RenameBisList("Raid |cffff0000") and Saved(e).name == "Raid ||cffff0000", "escaped")
    e.ns.DeleteBisList()
    assert(Saved(e).name == "My BiS" and #e.account.bisLists.MAGE.lists == 1, "moved to what is left")
    e.ns.DeleteBisList()
    assert(Saved(e).name == "My BiS" and next(Saved(e).slots) == nil, "never left without one")
end)

Case("an import adds a list beside the one in use", function()
    local e = Fixture()
    e.ns.AddBisPick(1, 101)
    local mine = Saved(e)
    e.vault[1] = { v = 2, name = "Robin's", slots = { [1] = 102 } }
    assert(e.ns.ImportBisList("!NBIS1!S1", true))
    assert(Saved(e).name == "Robin's" and Picks(e, 1) == "102" and mine.slots[1] == 101, "kept both")
    assert(e.ns.ImportBisList("!NBIS1!S1", true) and Saved(e).name == "Robin's 2", "a free name")
end)

Case("switching spec swaps the picks but keeps the list's name", function()
    local e = Fixture()
    assert(e.ns.NewBisList("Keep"))
    e.ns.AddBisPick(1, 103)
    e.ns.SetBisSpec("frost-mage")
    assert(Saved(e).name == "Keep" and Picks(e, 1) == "", "frost starts empty")
    e.ns.SetBisSpec("fire-mage")
    assert(Picks(e, 1) == "103", "fire's picks came back")
end)

Case("a moved list whose name is taken gets a free one", function()
    local e = Fixture({ ["Tester-Realm"] = { name = "Raid", slots = {} } })
    e.account.bisLists = { MAGE = { lists = { { id = 1, name = "raid", slots = {}, extra = {} } }, nextID = 2 } }
    assert(Saved(e).name == "Raid 2")
end)

Case("renaming to the name as shown keeps its pipes as they are", function()
    local e = Fixture()
    assert(e.ns.RenameBisList("A|B") and Saved(e).name == "A||B")
    assert(e.ns.RenameBisList((Saved(e).name:gsub("||", "|"))) and Saved(e).name == "A||B")
end)
-- A list's ID by its name, from what the menu offers on this tab.
local function Offered(e, name)
    local values, order = e.ns.BisListChoices()
    for _, id in ipairs(order) do
        if values[id] == name then return id end
    end
end

Case("a spec-only list is offered on its own spec's tab only, after the class lists", function()
    local e = Fixture()
    e.ns.AddBisPick(1, 101)
    assert(e.ns.NewBisList("Fire AoE", true))
    assert(Saved(e).specOnly == true and Saved(e).spec == "fire-mage" and Picks(e, 1) == "", "starts empty, on fire")
    local values, order, active, shared = e.ns.BisListChoices()
    assert(#order == 2 and shared == 1 and values[order[1]] == "My BiS" and values[order[2]] == "Fire AoE"
        and active == order[2], "the class list first, then the spec's own")
    e.ns.SetBisSpec("frost-mage")
    assert(Saved(e).name == "My BiS" and Saved(e).spec == "frost-mage", "another spec goes back to the class list")
    assert(Offered(e, "My BiS") and not Offered(e, "Fire AoE"), "frost does not offer fire's list")
    e.ns.SetBisSpec("fire-mage")
    assert(Saved(e).name == "Fire AoE", "fire opens on the fire list it was left on")
end)

Case("picking a class list on a spec's tab stops that tab opening its spec-only list", function()
    local e = Fixture()
    e.ns.AddBisPick(1, 101)
    assert(e.ns.NewBisList("Fire AoE", true))
    e.ns.SelectBisList(Offered(e, "My BiS"))
    assert(Saved(e).name == "My BiS" and Picks(e, 1) == "101")
    e.ns.SetBisSpec("frost-mage")
    e.ns.SetBisSpec("fire-mage")
    assert(Saved(e).name == "My BiS" and Picks(e, 1) == "101", "fire stays on the class list")
end)

Case("picking a class list keeps the spec tab you are on, even with no picks there", function()
    local e = Fixture()
    assert(e.ns.NewBisList("A"))
    e.ns.AddBisPick(1, 103)
    e.ns.SetBisSpec("frost-mage")
    assert(e.ns.NewBisList("B"))
    e.ns.SelectBisList(Offered(e, "A"))
    assert(Saved(e).name == "A" and Saved(e).spec == "frost-mage" and Picks(e, 1) == "", "A opens on frost")
    e.ns.SetBisSpec("fire-mage")
    assert(Picks(e, 1) == "103", "A's fire pick is still there")
    e.ns.SelectBisList(Offered(e, "B"))
    assert(Saved(e).name == "B" and Saved(e).spec == "fire-mage", "B, left on frost, opens on fire")
end)

Case("leaving a spec-only list for a class list stays on that spec", function()
    local e = Fixture()
    e.ns.AddBisPick(1, 101)
    e.ns.SetBisSpec("frost-mage")
    assert(e.ns.NewBisList("Frost Only", true))
    e.ns.SelectBisList(Offered(e, "My BiS"))
    assert(Saved(e).name == "My BiS" and Saved(e).spec == "frost-mage" and Picks(e, 1) == "", "frost, not fire")
end)

Case("picking a class list left on another spec keeps that spec's own list", function()
    local e = Fixture()
    e.ns.SetBisSpec("fire-mage")
    assert(e.ns.NewBisList("Raid"))
    assert(e.ns.NewBisList("Fire AoE", true))
    e.ns.SetBisSpec("frost-mage")
    assert(Saved(e).name == "Raid")
    e.ns.SelectBisList(Offered(e, "My BiS"))
    assert(Saved(e).name == "My BiS" and Saved(e).spec == "frost-mage", "My BiS, left on fire, opens on frost")
    e.ns.SetBisSpec("fire-mage")
    assert(Saved(e).name == "Fire AoE", "fire still opens its own list")
end)

Case("leaving a spec-only list goes back to the class list used last, not the first", function()
    local e = Fixture()
    assert(e.ns.NewBisList("Raid"))
    assert(e.ns.NewBisList("Fire AoE", true))
    e.ns.SetBisSpec("frost-mage")
    assert(Saved(e).name == "Raid", "Raid, not My BiS")
end)

Case("a spec-only list keeps its picks when the tabs change, and never parks them", function()
    local e = Fixture()
    assert(e.ns.NewBisList("Fire AoE", true))
    e.ns.AddBisPick(1, 103)
    e.ns.SetBisSpec("frost-mage")
    e.ns.SetBisSpec("fire-mage")
    assert(Saved(e).name == "Fire AoE" and Picks(e, 1) == "103" and Saved(e).bySpec == nil)
end)

Case("left unticked, a new list is a class list as before", function()
    local e = Fixture()
    assert(e.ns.NewBisList("Raid"))
    assert(Saved(e).specOnly == nil)
    e.ns.SetBisSpec("frost-mage")
    assert(Saved(e).name == "Raid" and Offered(e, "Raid") and Offered(e, "My BiS"), "shown on every tab")
end)

Case("deleting a spec-only list stays on its spec, on the class list", function()
    local e = Fixture()
    e.ns.AddBisPick(1, 101)
    e.ns.SetBisSpec("frost-mage")
    assert(e.ns.NewBisList("Frost Only", true))
    e.ns.SetBisSpec("fire-mage")
    e.ns.SetBisSpec("frost-mage")
    assert(Saved(e).name == "Frost Only")
    e.ns.DeleteBisList()
    assert(Saved(e).name == "My BiS" and Saved(e).spec == "frost-mage" and Picks(e, 1) == "", "frost's picks")
end)

Case("deleting the last class list makes a new one beside the spec-only lists", function()
    local e = Fixture()
    assert(e.ns.NewBisList("Fire AoE", true))
    e.ns.SelectBisList(Offered(e, "My BiS"))
    e.ns.DeleteBisList()
    assert(Saved(e).name == "My BiS" and Saved(e).specOnly == nil and #e.account.bisLists.MAGE.lists == 2)
end)

Case("a spec-only list stays one through a share string", function()
    local e = Fixture()
    assert(e.ns.NewBisList("Fire AoE", true))
    e.ns.AddBisPick(1, 103)
    assert(e.ns.ImportBisList(e.ns.ExportBisList(), true))
    assert(Saved(e).name == "Fire AoE 2" and Saved(e).specOnly == true and Saved(e).spec == "fire-mage")
    e.ns.SelectBisList(Offered(e, "My BiS"))
    assert(e.ns.ImportBisList(e.ns.ExportBisList(), true) and Saved(e).specOnly == nil, "a class list stays one")
end)

Case("a spec-only list for a spec the class lacks is a class list", function()
    local e = Fixture()
    e.account.bisLists = { MAGE = { lists = { { id = 1, name = "Arcane", spec = "arcane-mage", specOnly = true,
        slots = {}, extra = {} } }, nextID = 2 } }
    local _, order, _, shared = e.ns.BisListChoices()
    assert(Saved(e).name == "Arcane" and #order == 1 and shared == 1, "offered with the class lists, none made")
    e.vault[1] = { v = 4, name = "Odd", spec = "arcane-mage", only = true, slots = { [1] = 102 } }
    assert(e.ns.ImportBisList("!NBIS1!S1", true) and Saved(e).specOnly == nil, "an import for it is a class list")
end)

Case("a new list started from another copies the ticked slots' picks, in order", function()
    local e = Fixture()
    e.ns.AddBisPick(1, 103)
    e.ns.AddBisPick(1, 102)
    e.ns.AddBisPick(11, 202)
    local mine = Saved(e)
    assert(e.ns.NewBisList("Copy", false, { id = mine.id, spec = "fire-mage", slots = { [1] = true, [99] = true } }))
    assert(Saved(e).name == "Copy" and Picks(e, 1) == "103,102" and Picks(e, 11) == "", "slot 1 only")
    assert(Saved(e).extra[1] ~= mine.extra[1], "the copy's picks are its own")
end)

Case("a class list's other spec is copied from where it is parked", function()
    local e = Fixture()
    e.ns.AddBisPick(1, 103)
    e.ns.AddBisPick(11, 202)
    local mine = Saved(e)
    e.ns.SetBisSpec("frost-mage")
    e.ns.AddBisPick(1, 104)
    assert(e.ns.NewBisList("Fire Copy", true, { id = mine.id, spec = "fire-mage", slots = { [1] = true, [11] = true } }))
    assert(Saved(e).spec == "frost-mage" and Saved(e).specOnly == true, "made on the tab on show")
    assert(Picks(e, 1) == "103" and Picks(e, 11) == "202", "with fire's picks")
end)

Case("starting from a list that is gone, or a spec with nothing, makes an empty list", function()
    local e = Fixture()
    e.ns.AddBisPick(1, 103)
    local mine = Saved(e)
    assert(e.ns.NewBisList("Gone", false, { id = 999, spec = "fire-mage", slots = { [1] = true } }))
    assert(next(Saved(e).slots) == nil)
    assert(e.ns.NewBisList("Frost", false, { id = mine.id, spec = "frost-mage", slots = { [1] = true } }))
    assert(next(Saved(e).slots) == nil)
    table.insert(e.account.bisLists.MAGE.lists, { id = 50, name = "Unread", items = { 101 } })
    assert(e.ns.NewBisList("From Old", false, { id = 50, spec = "fire-mage", slots = { [1] = true } }))
    assert(next(Saved(e).slots) == nil, "an old list not read yet has nothing to copy")
end)

Case("the cloak slot still reads Back on enUS, through its own key", function()
    assert(Fixture().ns.Shared.Items.SlotName(15) == "Back")
end)
print(("%d cases passed"):format(count))

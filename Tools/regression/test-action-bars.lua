-- Bar sets against a small fake of the action bars, spellbook, macros and cursor, driven
-- through the /nf bars command the way a player would.
-- The module's rules as ActionBars.xml lists them, and the saved sets' menu; not its window
-- (test-action-bars-window.lua draws that).
rawset(_G, "C_AddOns", { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end })
local FILES = { "Core/Features.lua", "Shared/Style.lua" }
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^NaowhForever_Utilities/ActionBars/.*%.lua$")) do
    if not path:find("/UI/") or path:find("/UI/SetsPage%.lua$") then
        FILES[#FILES + 1] = path
    end
end

-- Spells by id: name, rank (or the spellbook's text for a variant without one) and the level it is learned at.
local SPELLS = {
    [2054] = { "Heal", 1, 16 }, [2055] = { "Heal", 2, 22 }, [6064] = { "Heal", 4, 34 },
    [585] = { "Smite", 1, 1 }, [598] = { "Smite", 3, 14 },
    [116] = { "Frostbolt", 1, 4 }, [205] = { "Frostbolt", 2, 8 }, [837] = { "Frostbolt", 3, 14 },
    [118] = { "Polymorph", 1, 8 }, [12826] = { "Polymorph", 4, 60 }, [28272] = { "Polymorph", "Pig", 60 },
}

local function SubName(id)
    local rank = SPELLS[id][2]
    return type(rank) == "string" and rank or "Rank " .. rank
end

local function World(known)
    local w = { bars = {}, macros = {}, charMacros = {}, binds = {}, cursor = nil, opts = {}, account = {},
        printed = {}, combat = false, level = 1, guid = "Player-1", timers = {} }
    local book = {}
    for _, id in ipairs(known) do
        book[#book + 1] = { name = SPELLS[id][1], subName = SubName(id), actionID = id,
            itemType = 1, isPassive = false }
    end
    local function Known(id)
        for _, item in ipairs(book) do if item.actionID == id then return true end end
    end
    function w.learn(id)
        book[#book + 1] = { name = SPELLS[id][1], subName = SubName(id), actionID = id,
            itemType = 1, isPassive = false }
    end
    w.opts.enabled, w.opts.importMacros, w.opts.importBindings = true, true, true
    w.opts.autoImportSets = {}
    local listeners = {}
    local S = {
        Get = function(k) return w.opts[k] end,
        Set = function(k, v)
            w.opts[k] = v
            for _, fn in ipairs(listeners) do fn(k, v) end
        end,
        OnChange = function(fn) listeners[#listeners + 1] = fn end,
        Toggle = function(_, text) return { type = "toggle", text = text } end,
    }
    local fake = {}
    local function Fake(key)
        local f = fake[key]
        if f then return f end
        f = {}
        for _, m in ipairs({ "ClearAllPoints", "SetPoint", "SetShown", "SetHeight", "SetTextColor" }) do
            f[m] = function() end
        end
        f.GetStringHeight = function() return 12 end
        f.SetText = function(_, text)
            if key == "barsName" then w.lastName = text end
            if key == "barsHas" then w.lastHas = text end
        end
        fake[key] = f
        return f
    end
    local WHITE = { r = 1, g = 1, b = 1 }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        THEME = { fg = WHITE, muted = WHITE },
        Solid = function() return Fake("solid") end,
        AccentBorder = function(f) return f end,
        AccountSettings = function() return w.account end,
        Shared = { CharacterData = function(key)
            w.account[key] = w.account[key] or {}
            w.account[key][w.guid] = w.account[key][w.guid] or {}
            return w.account[key][w.guid]
        end },
        Print = function(m) w.printed[#w.printed + 1] = m end,
        Color = function(_, text) return text end,
        UI = { ModuleSettings = function() return S end, RefreshPage = function() end, CONTENT_PAD = 12,
            Keep = function(_, key) return Fake(key) end,
            KeepFont = function(_, key) return Fake(key) end,
            KeepButton = function(_, key, text, _, _, fn)
                if key == "barsMore" then w.rows[#w.rows + 1] = { name = w.lastName, more = fn }
                else w.buttons[text] = fn end
                return Fake(key)
            end,
            Widgets = {
            Note = function() return nil, 0 end,
            SectionHeader = function() return nil, 0 end,
            Button = function(_, _, text, _, fn) w.buttons[text] = fn; return nil, 0 end,
            DualRow = function(_, _, _, left, right) w.rows[#w.rows + 1] = { left, right }; return nil, 0 end,
        } },
        OpenActionBarsWindow = function() w.opened = "window" end,
        OpenActionBarsBuilder = function(key) w.opened = "builder " .. tostring(key) end,
        OpenActionBarsImport = function(key) w.opened = "import " .. tostring(key) end,
        PromptText = function(_, _, _, accept) accept(w.answer) end,
        Confirm = function(text, yes) w.confirmed = text; yes() end,
    }
    w.ns = ns
    local env = {
        Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 } },
        Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 120, MAX_CHARACTER_MACROS = 30 } },
        C_GamepadUI = {
            GetFirstGamepadActionStorageSlotIndex = function() return 181 end,
            IsValidGamepadActionStorageSlotIndex = function(slot) return slot <= 190 end,
        },
        C_SpellBook = {
            GetNumSpellBookSkillLines = function() return 1 end,
            GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #book } end,
            GetSpellBookItemInfo = function(i) return book[i] end,
        },
        C_Spell = {
            GetSpellName = function(id) return SPELLS[id][1] end,
            PickupSpell = function(id) if Known(id) then w.cursor = { kind = "spell", id = id } end end,
            GetSpellLevelLearned = function(id) return SPELLS[id][3] end,
            GetSpellSubtext = function(id) return SPELLS[id] and SubName(id) end,
        },
        C_Item = {
            PickupItem = function(id) w.cursor = { kind = "item", id = id } end,
            GetItemNameByID = function(id) return "Item " .. id end,
        },
        C_ActionBar = { GetActionText = function(slot) return w.bars[slot] and w.bars[slot].name end },
        C_EquipmentSet = { GetEquipmentSetID = function() end, PickupEquipmentSet = function() end },
        MenuUtil = { CreateContextMenu = function(_, build)
            w.menu = {}
            build(nil, { CreateButton = function(_, text, fn) w.menu[text] = fn end })
        end },
        GetActionInfo = function(slot)
            local a = w.bars[slot]
            if a then return a.kind, a.id end
        end,
        GetCursorInfo = function() return w.cursor and w.cursor.kind end,
        ClearCursor = function() w.cursor = nil end,
        PlaceAction = function(slot) w.bars[slot], w.cursor = w.cursor, w.bars[slot] end,
        PickupAction = function(slot) w.cursor, w.bars[slot] = w.bars[slot], nil end,
        GetMacroIndexByName = function(name)
            for i, m in ipairs(w.macros) do if m.name == name then return i end end
            for i, m in ipairs(w.charMacros) do if m.name == name then return 120 + i end end
            return 0
        end,
        GetMacroInfo = function(i)
            local m = i > 120 and w.charMacros[i - 120] or w.macros[i]
            if m then return m.name, m.icon, m.body end
        end,
        GetNumMacros = function() return #w.macros + (w.otherMacros or 0), #w.charMacros end,
        CreateMacro = function(name, icon, body, perCharacter)
            local list = perCharacter and w.charMacros or w.macros
            list[#list + 1] = { name = name, icon = icon, body = body }
            return (perCharacter and 120 or 0) + #list
        end,
        PickupMacro = function(i)
            -- A macro slot reports the spell it shows; this one shows nothing.
            local m = i > 120 and w.charMacros[i - 120] or w.macros[i]
            w.cursor = { kind = "macro", id = 0, name = m.name, index = i }
        end,
        GetNumBindings = function() return #w.binds end,
        GetBinding = function(i) local b = w.binds[i]; return b[1], "HEADER", b[2], b[3] end,
        GetBindingKey = function(command)
            for _, b in ipairs(w.binds) do
                if b[1] == command then return b[2], b[3] end
            end
        end,
        SetBinding = function(key, command)
            if command == "NO_SUCH_ADDON" then return false end
            for _, b in ipairs(w.binds) do
                if b[2] == key then b[2] = b[3]; b[3] = nil end
                if b[3] == key then b[3] = nil end
            end
            if command == nil then return true end
            for _, b in ipairs(w.binds) do
                if b[1] == command then
                    if b[2] then b[3] = key else b[2] = key end
                    return true
                end
            end
            w.binds[#w.binds + 1] = { command, key }
            return true
        end,
        C_KeyBindings = { GetBindingContextForAction = function() return 1 end },
        GetCurrentBindingSet = function() return 2 end,
        SaveBindings = function(set) w.savedBindings = set end,
        InCombatLockdown = function() return w.combat end,
        UnitClass = function() return "Priest", "PRIEST" end,
        UnitName = function() return w.name or "Preview" end,
        UnitLevel = function() return w.level end,
        UnitXP = function() return w.xp or 0 end,
        GetRealmName = function() return "Realm" end,
        CreateFrame = function()
            local f = { registered = {} }
            f.RegisterEvent = function(self, event) self.registered[event] = true end
            f.UnregisterEvent = function(self, event) self.registered[event] = nil end
            f.SetScript = function(self, _, fn)
                self.handler = fn
                w.events = self
            end
            return f
        end,
        strtrim = function(s) return s:match("^%s*(.-)%s*$") end,
        C_Timer = { After = function(_, fn) w.timers[#w.timers + 1] = fn end },
        time = os.time, date = os.date,
        print = function(m) w.printed[#w.printed + 1] = m end,
        _G = { NaowhForever = ns },
    }
    env._G.NaowhForever = ns
    setmetatable(env, { __index = _G })
    for _, path in ipairs(FILES) do
        local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk()
    end
    w.run = ns.ActionBarsCommand
    -- Changes the bars, lets the logout copy's timer run, then logs out.
    function w.logout(changed)
        if changed then
            w.events.handler(w.events, "ACTIONBAR_SLOT_CHANGED")
            local timers = w.timers
            w.timers = {}
            for _, fn in ipairs(timers) do fn() end
        end
        w.events.handler(w.events, "PLAYER_LOGOUT")
    end
    return w
end

local function Spell(id) return { kind = "spell", id = id } end
local function Macro(name) return { kind = "macro", id = 0, name = name } end
local function Bars(w)
    local out = {}
    for slot = 1, 190 do
        local a = w.bars[slot]
        if a then out[#out + 1] = slot .. "=" .. (a.kind == "macro" and a.name or a.kind .. a.id) end
    end
    return table.concat(out, " ")
end

-- The More menu of the named set, as its row's More button opens it.
local function More(w, name)
    w.ns.ActionBars.SetMenu(name)
    return w.menu
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("import puts every slot back and clears slots the set left empty", function()
    local w = World({ 2055, 598 })
    w.bars = { [1] = Spell(2055), [3] = Spell(598), [185] = { kind = "item", id = 6948 } }
    w.run("save Raid")
    w.bars = { [1] = Spell(598), [2] = Spell(2055) }
    w.run("import Raid")
    assert(Bars(w) == "1=spell2055 3=spell598 185=item6948", Bars(w))
    assert(w.cursor == nil, "nothing left on the cursor")
end)
Case("a rank no longer known falls back to the highest known", function()
    local w = World({ 2055 })
    w.account.barSets = { PRIEST = { Old = { saved = 0, slots = { [1] = { kind = "spell", id = 6064, name = "Heal" } } } } }
    w.run("restore Old")
    assert(Bars(w) == "1=spell2055", Bars(w))
end)
Case("Highest Rank swaps a known lower rank for the top one", function()
    local w = World({ 2054, 6064 })
    w.bars = { [1] = Spell(2054) }
    w.run("save Low")
    w.opts.highestRank = true
    w.run("restore Low")
    assert(Bars(w) == "1=spell6064", Bars(w))
end)
Case("without Highest Rank a known saved rank stays, for downranking", function()
    local w = World({ 2054, 6064 })
    w.bars = { [1] = Spell(2054), [2] = Spell(6064) }
    w.run("save Heals")
    w.bars = {}
    w.run("restore Heals")
    assert(Bars(w) == "1=spell2054 2=spell6064", Bars(w))
end)
Case("a test import changes nothing and lists what would be left empty", function()
    local w = World({ 2055 })
    w.account.barSets = { PRIEST = { Set = { saved = 0, slots = { [1] = { kind = "spell", id = 585, name = "Smite" } } } } }
    w.bars = { [5] = Spell(2055) }
    w.run("test Set")
    assert(Bars(w) == "5=spell2055", Bars(w))
    assert(w.printed[#w.printed]:find("Smite", 1, true), w.printed[#w.printed])
end)
Case("restore still imports, and macros are found by name", function()
    local w = World({})
    w.macros = { { name = "Pull", icon = 1, body = "/say pull" } }
    w.bars = { [7] = Macro("Pull") }
    w.run("save M")
    w.bars = {}
    w.run("restore M")
    assert(Bars(w) == "7=Pull", Bars(w))
end)
Case("a missing macro is made on import, and left empty with Import Macros off", function()
    local w = World({})
    w.macros = { { name = "Pull", icon = 1, body = "/say pull" } }
    w.bars = { [7] = Macro("Pull") }
    w.run("save M")
    w.macros, w.bars = {}, {}
    w.opts.importMacros = false
    w.run("import M")
    assert(Bars(w) == "" and #w.macros == 0)
    w.opts.importMacros = true
    w.run("test M")
    assert(#w.macros == 0, "a test does not make macros")
    w.run("import M")
    assert(Bars(w) == "7=Pull" and w.macros[1].body == "/say pull", Bars(w))
end)
Case("an alt gets the macros it lacks once, and keeps its own", function()
    local w = World({})
    w.macros = { { name = "Pull", icon = 1, body = "/say pull" } }
    w.charMacros = { { name = "Bop", icon = 2, body = "/cast Blessing of Protection" } }
    w.bars = { [1] = Macro("Pull"), [2] = Macro("Bop") }
    w.run("save Main")
    w.charMacros, w.bars = { { name = "Mine", icon = 3, body = "/dance" } }, {}
    w.run("import Main")
    assert(Bars(w) == "1=Pull 2=Bop", Bars(w))
    assert(#w.macros == 1, "the account macro was already there")
    assert(#w.charMacros == 2 and w.charMacros[1].name == "Mine", "the alt's own macro is kept")
    w.run("import Main")
    assert(#w.macros == 1 and #w.charMacros == 2, "a second import makes nothing")
end)
Case("a macro already here under another name is used, not copied", function()
    local w = World({})
    w.charMacros = { { name = "Bop", icon = 2, body = "/cast Blessing of Protection" } }
    w.bars = { [4] = Macro("Bop") }
    w.run("save Main")
    w.charMacros, w.bars = { { name = "BoP2", icon = 2, body = "/cast Blessing of Protection\r\n" } }, {}
    w.run("import Main")
    assert(#w.charMacros == 1 and Bars(w) == "4=BoP2", Bars(w))
end)
Case("a macro of the same name with other text is never overwritten", function()
    local w = World({})
    w.macros = { { name = "Pull", icon = 1, body = "/say pull" } }
    w.bars = { [7] = Macro("Pull") }
    w.run("save M")
    w.macros[1].body = "/yell PULLING"
    w.run("import M")
    assert(w.macros[1].body == "/yell PULLING" and w.macros[2].body == "/say pull", "made alongside")
end)
Case("a Smart Macro is found by name, since every character writes its own items into it", function()
    local w = World({})
    w.ns.MacroSmart = { list = { { key = "bandage", name = "NF Bandage" } } }
    w.macros = { { name = "NF Bandage", icon = 1, body = "#showtooltip\n/use item:6450" } }
    w.bars = { [5] = Macro("NF Bandage") }
    w.run("save M")
    w.macros[1].body = "#showtooltip\n/use item:1251"
    w.bars = {}
    w.run("import M")
    assert(#w.macros == 1 and w.macros[1].body == "#showtooltip\n/use item:1251", "no second NF Bandage")
    assert(Bars(w) == "5=NF Bandage", Bars(w))
end)
Case("a stale NF macro left by an older import is passed over for the one kept current", function()
    local w = World({})
    w.ns.MacroSmart = { list = { { key = "bandage", name = "NF Bandage" }, { key = "drink", name = "NF Drink" } } }
    w.macros = { { name = "NF Bandage", icon = 1, body = "#showtooltip\n/use item:6450" },
        { name = "NF Drink", icon = 1, body = "#showtooltip" } }
    w.bars = { [5] = Macro("NF Bandage"), [6] = Macro("NF Drink") }
    w.run("save M")
    w.macros = { { name = "NF Bandage", icon = 1, body = "#showtooltip\n/use item:1251" },
        { name = "NF Bandage", icon = 1, body = "#showtooltip\n/use item:6450" },
        { name = "NF Drink", icon = 1, body = "#showtooltip\n/use item:159" },
        { name = "NF Health", icon = 1, body = "#showtooltip" } }
    w.bars = {}
    w.run("import M")
    assert(#w.macros == 4, "nothing made")
    assert(w.bars[5].index == 1 and w.bars[6].index == 3, "the kept copy, and not NF Health for its text")
end)
Case("an NF macro switched off on this account is not made again", function()
    local w = World({})
    w.ns.MacroSmart = { list = { { key = "trinket1", name = "NF Trinket 1" } } }
    w.macros = { { name = "NF Trinket 1", icon = 1, body = "/use 13" } }
    w.bars = { [5] = Macro("NF Trinket 1") }
    w.run("save M")
    w.macros, w.bars = {}, {}
    w.run("import M")
    assert(#w.macros == 0 and Bars(w) == "", Bars(w))
end)
Case("a #showtooltip macro is made with the question mark so it follows its spell", function()
    local w = World({})
    w.charMacros = { { name = "Heal", icon = 135913, body = "#showtooltip\n/cast Heal" } }
    w.run("save M")
    w.charMacros = {}
    w.run("import M")
    assert(w.charMacros[1].icon == 134400, tostring(w.charMacros[1].icon))
end)

Case("a website layout makes every macro it lists, placed or not, each once", function()
    local w = World({})
    local pull = { kind = "macro", name = "Pull", body = "/say pull", icon = 134400, perCharacter = true }
    w.ns.Shared.Decode = { String = function()
        return { v = 1, class = 5, name = "Web", slots = { [1] = pull }, macros = {
            { name = "Pull", body = "/say pull", icon = 134400, perCharacter = true },
            { name = "Shout", body = "/yell hi", icon = 132333, perCharacter = false },
            { name = "Tip", body = "#showtooltip\n/cast Heal", icon = 132333 },
        } }
    end }
    w.ns.ImportActionBarString("!NFA1!x")
    assert(w.opened == "import Web", tostring(w.opened))
    local fates = w.ns.ActionBarSets.Preview("Web").macros
    assert(#fates == 3 and fates[2].name == "Shout" and fates[2].fate == "new", "the preview lists the unplaced ones")
    w.run("import Web")
    assert(Bars(w) == "1=Pull", Bars(w))
    assert(#w.macros == 1 and w.macros[1].name == "Shout" and w.macros[1].icon == 132333, "an account macro, with its icon")
    assert(#w.charMacros == 2 and w.charMacros[1].name == "Pull" and w.charMacros[2].name == "Tip",
        "the placed macro is made once, and character macros are the default")
    assert(w.charMacros[2].icon == 134400, "a #showtooltip macro still gets the question mark")
end)
Case("keybinds are saved and imported, keys the set leaves free keep theirs", function()
    local w = World({})
    w.binds = { { "ACTIONBUTTON1", "1" }, { "MOVEFORWARD", "W", "UP" }, { "TOGGLEBAG", "B" } }
    w.run("save Keys")
    w.binds = { { "ACTIONBUTTON1", "Q" }, { "STRAFELEFT", "1" }, { "TOGGLEMAP", "M" } }
    w.run("test Keys")
    assert(w.binds[1][2] == "Q" and not w.savedBindings, "a test binds nothing")
    w.run("import Keys")
    local keys = {}
    for _, b in ipairs(w.binds) do
        for i = 2, 3 do if b[i] then keys[b[i]] = b[1] end end
    end
    assert(keys["1"] == "ACTIONBUTTON1" and keys.W == "MOVEFORWARD" and keys.UP == "MOVEFORWARD"
        and keys.B == "TOGGLEBAG", "the set's keys")
    assert(keys.M == "TOGGLEMAP" and keys.Q == "ACTIONBUTTON1", "keys the set leaves free are kept")
    assert(w.savedBindings == 2, "saved to the binding set in use")
    assert(w.printed[#w.printed]:find("4 keybinds", 1, true), w.printed[#w.printed])
end)
Case("Import Keybinds off leaves keys alone", function()
    local w = World({})
    w.binds = { { "ACTIONBUTTON1", "1" } }
    w.run("save Keys")
    w.binds = { { "STRAFELEFT", "1" } }
    w.opts.importBindings = false
    w.run("import Keys")
    assert(w.binds[1][1] == "STRAFELEFT" and w.binds[1][2] == "1" and not w.savedBindings)
end)
Case("a key whose command is not here is not counted", function()
    local w = World({})
    w.account.barSets = { PRIEST = { Old = { saved = 0, slots = {},
        bindings = { ["1"] = "ACTIONBUTTON1", F = "NO_SUCH_ADDON" } } } }
    w.run("import Old")
    assert(w.printed[#w.printed]:find("1 keybind", 1, true), w.printed[#w.printed])
end)
Case("an action a website layout binds keeps only the layout's keys", function()
    local w = World({})
    w.binds = { { "ACTIONBUTTON4", "4" }, { "ACTIONBUTTON5", "5", "SHIFT-5" }, { "ACTIONBUTTON6", "6" } }
    w.account.barSets = { PRIEST = { Web = { saved = 0, slots = {}, choices = { skip = {}, website = true },
        bindings = { F1 = "ACTIONBUTTON4", F2 = "ACTIONBUTTON5" } } } }
    w.run("import Web")
    local keys = {}
    for _, b in ipairs(w.binds) do keys[b[1]] = (b[2] or "") .. "," .. (b[3] or "") end
    assert(keys.ACTIONBUTTON4 == "F1," and keys.ACTIONBUTTON5 == "F2,", keys.ACTIONBUTTON4 .. " " .. keys.ACTIONBUTTON5)
    assert(keys.ACTIONBUTTON6 == "6,", "a key the set leaves free keeps what it does")
end)
Case("the set row says what it holds", function()
    local w = World({ 598 })
    w.macros = { { name = "Pull", icon = 1, body = "/say pull" } }
    w.binds = { { "ACTIONBUTTON1", "1", "F1" } }
    w.bars = { [2] = Spell(598), [3] = Macro("Pull") }
    w.run("save Raid")
    local has = w.ns.ActionBars.SetContents(w.account.barSets.PRIEST.Raid)
    assert(has == "2 actions, 1 macro, 2 keybinds", has)
end)
Case("set names match whatever the case", function()
    local w = World({ 598 })
    w.bars = { [2] = Spell(598) }
    w.run("save Dungeon")
    w.bars = {}
    w.run("restore dUNGEON")
    assert(Bars(w) == "2=spell598")
    assert(w.account.barSets.PRIEST.Dungeon and not w.account.barSets.PRIEST.dUNGEON)
end)
Case("nothing saves or restores while the module is off", function()
    local w = World({ 598 })
    w.bars = { [2] = Spell(598) }
    w.run("save On")
    w.opts.enabled = false
    w.run("save Off")
    w.bars = {}
    w.run("restore On")
    assert(Bars(w) == "" and not w.account.barSets.PRIEST.Off)
    assert(w.printed[#w.printed] == "Action Bars is switched off.")
end)
Case("nothing changes in combat", function()
    local w = World({ 598 })
    w.bars = { [2] = Spell(598) }
    w.run("save C")
    w.bars, w.combat = {}, true
    w.run("restore C")
    assert(Bars(w) == "")
end)
Case("Save on Logout writes back the last set saved, only when on", function()
    local w = World({ 598, 2055 })
    w.bars = { [2] = Spell(598) }
    w.run("save Daily")
    w.bars = { [2] = Spell(2055) }
    w.logout(true)
    assert(w.account.barSets.PRIEST.Daily.slots[2].id == 598, "off: left alone")
    w.ns.ActionBarSettings.Set("saveOnLogout", true)
    w.logout(true)
    assert(w.account.barSets.PRIEST.Daily.slots[2].id == 2055, "on: saved again")
end)
Case("Save on Logout writes the bars as they were before logging out, not as the game reads them then", function()
    local w = World({ 598, 2055 })
    w.ns.ActionBarSettings.Set("saveOnLogout", true)
    w.bars = { [2] = Spell(598) }
    w.run("save Daily")
    w.bars = { [2] = Spell(598), [3] = Spell(2055) }
    w.events.handler(w.events, "ACTIONBAR_SLOT_CHANGED")
    for _, fn in ipairs(w.timers) do fn() end
    w.bars = {}
    w.events.handler(w.events, "PLAYER_LOGOUT")
    local set = w.account.barSets.PRIEST.Daily
    assert(set.slots[2].id == 598 and set.slots[3].id == 2055, "the copy from before logout")
end)
Case("Save on Logout leaves a set alone with nothing changed since it was saved", function()
    local w = World({ 598, 2055 })
    w.ns.ActionBarSettings.Set("saveOnLogout", true)
    w.bars = { [2] = Spell(2055) }
    w.logout(true)
    w.run("save Daily")
    w.bars = {}
    w.logout(false)
    assert(w.account.barSets.PRIEST.Daily.slots[2].id == 2055, "the hand save stands")
end)
Case("switching Save on Logout off drops its copy, and on takes a new one", function()
    local w = World({ 598, 2055 })
    local S = w.ns.ActionBarSettings
    S.Set("saveOnLogout", true)
    w.bars = { [2] = Spell(598) }
    w.run("save Daily")
    w.bars = { [2] = Spell(2055) }
    w.logout(true)
    S.Set("saveOnLogout", false)
    w.bars = { [3] = Spell(598) }
    S.Set("saveOnLogout", true)
    for _, fn in ipairs(w.timers) do fn() end
    w.logout(false)
    local set = w.account.barSets.PRIEST.Daily
    assert(set.slots[3] and not set.slots[2], "the bars as they are, not the copy from before")
end)
Case("a renamed set keeps its logout copy", function()
    local w = World({ 598, 2055 })
    w.ns.ActionBarSettings.Set("saveOnLogout", true)
    w.bars = { [2] = Spell(598) }
    w.run("save Daily")
    w.bars = { [2] = Spell(2055) }
    w.events.handler(w.events, "ACTIONBAR_SLOT_CHANGED")
    for _, fn in ipairs(w.timers) do fn() end
    w.ns.ActionBars.Rename("Daily", "Main")
    w.logout(false)
    assert(w.account.barSets.PRIEST.Main.slots[2].id == 2055, "saved under the new name")
end)
Case("a set last used before the saved flag existed is still written back", function()
    local w = World({ 598, 2055 })
    w.ns.ActionBarSettings.Set("saveOnLogout", true)
    w.bars = { [2] = Spell(598) }
    w.run("save Daily")
    w.account.barSetLast["Preview-Realm"].saved = nil
    w.bars = { [2] = Spell(2055) }
    w.logout(true)
    assert(w.account.barSets.PRIEST.Daily.slots[2].id == 2055, "written back as before")
end)
Case("renaming a set to its own name keeps it", function()
    local w = World({ 598 })
    w.bars = { [2] = Spell(598) }
    w.run("save Raid")
    w.answer = "Raid"
    More(w, "Raid").Rename()
    assert(w.account.barSets.PRIEST.Raid, "still there")
end)
Case("a rename moves Save on Logout only for characters of this class", function()
    local w = World({ 598 })
    w.account.barSetLast = { ["Warrior-Realm"] = { class = "WARRIOR", name = "Raid" } }
    w.bars = { [2] = Spell(598) }
    w.run("save Raid")
    w.answer = "Main"
    More(w, "Raid").Rename()
    assert(w.account.barSets.PRIEST.Main and not w.account.barSets.PRIEST.Raid)
    assert(w.account.barSetLast["Preview-Realm"].name == "Main")
    assert(w.account.barSetLast["Warrior-Realm"].name == "Raid", "the warrior keeps its own set")
end)
Case("More can edit a set in the builder", function()
    local w = World({ 598 })
    w.bars = { [2] = Spell(598) }
    w.run("save Raid")
    More(w, "Raid")["Edit and Save Again"]()
    assert(w.opened == "builder Raid", w.opened)
end)
Case("slots no set can restore are left as they are", function()
    local w = World({ 598 })
    w.bars = { [2] = Spell(598), [4] = { kind = "summonmount", id = 5 } }
    w.run("save Mount")
    w.bars = { [4] = Spell(598) }
    w.run("restore Mount")
    assert(Bars(w) == "2=spell598 4=spell598", Bars(w))
    assert(w.printed[#w.printed] == "Imported Mount: 1 of 1 actions, 0 keybinds.", w.printed[#w.printed])
end)
Case("a test counts the macros it would make against the free room", function()
    local w = World({})
    w.macros = { { name = "A", icon = 1, body = "/a" }, { name = "B", icon = 1, body = "/b" } }
    w.bars = { [1] = Macro("A"), [2] = Macro("B") }
    w.run("save M")
    w.macros, w.otherMacros = {}, 119
    w.run("test M")
    assert(w.printed[#w.printed]:find("Slot 2", 1, true), "one free slot, so the second is reported")
    assert(w.printed[#w.printed - 2]:find("No room for 1 macro: B", 1, true), w.printed[#w.printed - 2])
end)
Case("no name opens the window", function()
    local w = World({})
    w.run("")
    assert(w.opened == "window")
end)
local Sets
local function Choices(skip, keys, macros, macroOff)
    return { skip = skip or {}, keys = keys ~= false, macros = macros ~= false, macroOff = macroOff or {} }
end

Case("slots left out are not saved, and an import leaves them as they are", function()
    local w = World({ 598, 2055 })
    Sets = w.ns.ActionBarSets
    w.bars = { [1] = Spell(598), [2] = Spell(2055) }
    Sets.Save("Part", Choices({ [2] = true, [3] = true }))
    local set = w.account.barSets.PRIEST.Part
    assert(set.slots[1] and not set.slots[2], "the left-out slot is not in the set")
    w.bars = { [2] = Spell(598), [3] = Spell(2055) }
    w.run("import Part")
    assert(Bars(w) == "1=spell598 2=spell598 3=spell2055", Bars(w))
end)
Case("a whole bar left out is never touched", function()
    local w = World({ 598 })
    Sets = w.ns.ActionBarSets
    local skip = {}
    for slot = 61, 72 do skip[slot] = true end
    w.bars = { [1] = Spell(598) }
    Sets.Save("NoBar2", Choices(skip))
    w.bars = { [61] = Spell(598), [70] = { kind = "item", id = 6948 } }
    w.run("import NoBar2")
    assert(Bars(w) == "1=spell598 61=spell598 70=item6948", Bars(w))
end)
Case("keybinds switched off are not saved", function()
    local w = World({})
    Sets = w.ns.ActionBarSets
    w.binds = { { "ACTIONBUTTON1", "1" } }
    Sets.Save("NoKeys", Choices(nil, false))
    assert(w.account.barSets.PRIEST.NoKeys.bindings == nil)
end)
Case("macros left out stay out, except ones on a kept slot", function()
    local w = World({})
    Sets = w.ns.ActionBarSets
    w.macros = { { name = "Pull", icon = 1, body = "/say pull" }, { name = "Dance", icon = 1, body = "/dance" },
        { name = "Wave", icon = 1, body = "/wave" } }
    w.bars = { [1] = Macro("Pull") }
    local off = { [Sets.MacroKey("Pull", "/say pull")] = true, [Sets.MacroKey("Dance", "/dance")] = true }
    Sets.Save("M", Choices(nil, true, true, off))
    local names = {}
    for _, m in ipairs(w.account.barSets.PRIEST.M.macros) do names[#names + 1] = m.name end
    assert(table.concat(names, ",") == "Pull,Wave", table.concat(names, ","))
    Sets.Save("OnlyBars", Choices(nil, true, false))
    assert(#w.account.barSets.PRIEST.OnlyBars.macros == 1, "macros off: only the ones on the bars")
end)
Case("saving again, by hand or on logout, keeps the set's choices", function()
    local w = World({ 598, 2055 })
    Sets = w.ns.ActionBarSets
    w.bars = { [1] = Spell(598), [2] = Spell(2055) }
    Sets.Save("Keep", Choices({ [2] = true }, false))
    w.run("save Keep")
    local set = w.account.barSets.PRIEST.Keep
    assert(not set.slots[2] and set.bindings == nil, "slash save keeps the picks")
    w.ns.ActionBarSettings.Set("saveOnLogout", true)
    w.logout(true)
    set = w.account.barSets.PRIEST.Keep
    assert(not set.slots[2] and set.bindings == nil and set.choices.skip[2], "logout keeps the picks")
end)
-- The set saved on one character, then the same account on a level 20 alt who knows Smite only.
local function Alt(known)
    local w = World({ 598, 6064 })
    w.macros = { { name = "Pull", icon = 1, body = "/say pull" } }
    w.binds = { { "ACTIONBUTTON1", "1" } }
    w.bars = { [1] = Spell(598), [2] = Spell(6064), [3] = Macro("Pull"), [5] = Spell(598) }
    w.ns.ActionBarSets.Save("P", Choices({ [5] = true }))
    local alt = World(known or { 598 })
    alt.account = w.account
    alt.events.handler(alt.events, "PLAYER_LOGIN")
    return alt
end
Case("Save on Logout never writes an alt's bars over a set it only imported", function()
    local alt = Alt({ 598 })
    alt.name = "Alt"
    alt.ns.ActionBarSettings.Set("saveOnLogout", true)
    alt.run("import P")
    alt.bars[1] = nil
    alt.logout(true)
    assert(alt.account.barSets.PRIEST.P.slots[1].id == 598, "the saved set is untouched")
end)
Case("the preview says what each slot becomes and changes nothing", function()
    local alt = Alt()
    alt.bars = { [4] = Spell(598), [5] = Spell(598) }
    local r = alt.ns.ActionBarSets.Preview("P")
    assert(r.slots[1].state == "ok" and r.slots[3].state == "new", r.slots[3].state)
    assert(r.slots[2].state == "later" and r.slots[2].level == 34, r.slots[2].state)
    assert(r.slots[4].state == "clear" and r.slots[5].state == "skip")
    assert(r.placed == 2 and r.actions == 3 and r.bound == 1, r.placed .. "/" .. r.actions)
    assert(r.macros[1].fate == "new", r.macros[1].fate)
    assert(Bars(alt) == "4=spell598 5=spell598" and #alt.macros == 0 and not alt.savedBindings, Bars(alt))
end)
Case("a spell learned later goes into its slot when Fill In is on", function()
    local alt = Alt()
    alt.opts.fillLater = true
    alt.run("import P")
    assert(Bars(alt) == "1=spell598 3=Pull", Bars(alt))
    assert(alt.events.registered.LEARNED_SPELL_IN_SKILL_LINE, "waiting for the spell")
    assert(alt.printed[#alt.printed]:find("learn later", 1, true), alt.printed[#alt.printed])
    alt.learn(6064)
    alt.events.handler(alt.events, "LEARNED_SPELL_IN_SKILL_LINE", 6064)
    assert(Bars(alt) == "1=spell598 3=Pull", "not before the spellbook has it")
    alt.events.handler(alt.events, "SPELLS_CHANGED")
    assert(Bars(alt) == "1=spell598 2=spell6064 3=Pull", Bars(alt))
    assert(alt.printed[#alt.printed]:find("Heal is on your bars", 1, true), alt.printed[#alt.printed])
    assert(not alt.events.registered.LEARNED_SPELL_IN_SKILL_LINE, "nothing left to wait for")
    assert(next(alt.account.barSetPending) == nil)
end)
Case("a website layout fills in what is not learned yet, with Fill In off, and says so", function()
    local alt = Alt()
    alt.account.barSets.PRIEST.P.choices.website = true
    alt.run("import P")
    assert(alt.events.registered.LEARNED_SPELL_IN_SKILL_LINE, "waiting for the spell")
    assert(alt.printed[#alt.printed]:find("Placed when learned:", 1, true), alt.printed[#alt.printed])
    for _, line in ipairs(alt.printed) do assert(not line:find("left empty", 1, true), line) end
    alt.learn(6064)
    alt.events.handler(alt.events, "LEARNED_SPELL_IN_SKILL_LINE", 6064)
    alt.events.handler(alt.events, "SPELLS_CHANGED")
    assert(Bars(alt) == "1=spell598 2=spell6064 3=Pull", Bars(alt))
    assert(next(alt.account.barSetPending) == nil)
end)
Case("Fill In waits out combat", function()
    local alt = Alt()
    alt.opts.fillLater = true
    alt.run("import P")
    alt.learn(6064)
    alt.combat = true
    alt.events.handler(alt.events, "LEARNED_SPELL_IN_SKILL_LINE", 6064)
    alt.events.handler(alt.events, "SPELLS_CHANGED")
    assert(not alt.bars[2] and alt.events.registered.PLAYER_REGEN_ENABLED, "waits")
    alt.combat = false
    alt.events.handler(alt.events, "PLAYER_REGEN_ENABLED")
    assert(alt.bars[2] and alt.bars[2].id == 6064, Bars(alt))
end)
Case("a slot filled meanwhile is the player's", function()
    local alt = Alt()
    alt.opts.fillLater = true
    alt.run("import P")
    alt.bars[2] = Spell(598)
    alt.learn(6064)
    alt.events.handler(alt.events, "LEARNED_SPELL_IN_SKILL_LINE", 6064)
    alt.events.handler(alt.events, "SPELLS_CHANGED")
    assert(alt.bars[2].id == 598 and next(alt.account.barSetPending) == nil, Bars(alt))
end)
Case("a copy the game put in a slot the set keeps empty is taken off", function()
    local alt = Alt()
    alt.opts.fillLater = true
    alt.run("import P")
    alt.learn(6064)
    alt.bars[7] = Spell(6064)
    alt.events.handler(alt.events, "LEARNED_SPELL_IN_SKILL_LINE", 6064)
    alt.events.handler(alt.events, "SPELLS_CHANGED")
    assert(Bars(alt) == "1=spell598 2=spell6064 3=Pull", Bars(alt))
end)
Case("with Fill In off nothing waits", function()
    local alt = Alt()
    alt.run("import P")
    assert(not alt.events.registered.LEARNED_SPELL_IN_SKILL_LINE and next(alt.account.barSetPending) == nil)
    alt.opts.fillLater = true
    alt.ns.ActionBarSettings.Set("fillLater", true)
    assert(not alt.events.registered.LEARNED_SPELL_IN_SKILL_LINE, "nothing pending, so nothing to wait for")
end)
Case("a saved top rank is saved as Highest, a lower rank keeps its rank", function()
    local w = World({ 116, 205, 837 })
    w.bars = { [1] = Spell(837), [2] = Spell(116) }
    w.run("save Frost")
    local slots = w.account.barSets.PRIEST.Frost.slots
    assert(slots[1].top == true and slots[2].top == nil, "only the highest rank known is Highest")
    local alt = World({ 116, 205 })
    alt.account = w.account
    alt.run("import Frost")
    assert(Bars(alt) == "1=spell205 2=spell116", "Highest is the alt's best, Rank 1 stays Rank 1: " .. Bars(alt))
end)
Case("a slot marked Highest places the best rank known, one without it its own rank", function()
    local w = World({ 116, 205 })
    w.account.barSets = { PRIEST = { Web = { saved = 0, slots = {
        [1] = { kind = "spell", id = 837, name = "Frostbolt", top = true },
        [2] = { kind = "spell", id = 116, name = "Frostbolt" },
        [3] = { kind = "spell", id = 837, name = "Frostbolt" } } } } }
    w.run("import Web")
    assert(Bars(w) == "1=spell205 2=spell116 3=spell205", "an unknown rank still falls back: " .. Bars(w))
    w.opts.highestRank = true
    w.run("import Web")
    assert(Bars(w) == "1=spell205 2=spell205 3=spell205", "Highest Rank still forces it everywhere: " .. Bars(w))
end)
Case("the rank is found by the client's own spell name, not the one the code carries", function()
    local w = World({ 116, 205 })
    w.account.barSets = { PRIEST = { Web = { saved = 0, slots = {
        [1] = { kind = "spell", id = 837, name = "Frostblitz", top = true },
        [2] = { kind = "spell", id = 837, name = "Frostblitz" } } } } }
    w.run("import Web")
    assert(Bars(w) == "1=spell205 2=spell205", Bars(w))
end)
Case("Polymorph: Pig is its own spell, never Polymorph's top rank", function()
    local w = World({ 118, 12826, 28272 })
    w.bars = { [1] = Spell(28272), [2] = Spell(118), [3] = Spell(12826) }
    w.run("save Sheep")
    local slots = w.account.barSets.PRIEST.Sheep.slots
    assert(slots[1].top == nil and slots[2].top == nil and slots[3].top == true, "only Rank 4 is Highest")
    w.opts.highestRank = true
    w.bars = {}
    w.run("import Sheep")
    assert(Bars(w) == "1=spell28272 2=spell12826 3=spell12826", "Pig stays Pig: " .. Bars(w))
    w.opts.highestRank = false
    w.account.barSets.PRIEST.Pig = { saved = 0, slots = { [1] = { kind = "spell", id = 28272, name = "Polymorph", top = true } } }
    w.bars = {}
    w.run("import Pig")
    assert(Bars(w) == "1=spell28272", "a website Highest on Pig keeps Pig: " .. Bars(w))
    local alt = World({ 118, 12826 })
    alt.account = w.account
    alt.run("import Pig")
    assert(Bars(alt) == "", "an alt without Pig gets no sheep in its place: " .. Bars(alt))
end)
Case("pet bar keys are saved and imported with the set, and can be left out", function()
    local w = World({})
    Sets = w.ns.ActionBarSets
    w.binds = { { "BONUSACTIONBUTTON1", "CTRL-1" }, { "BONUSACTIONBUTTON10", "CTRL-0" }, { "ACTIONBUTTON1", "1" } }
    w.run("save Pets")
    local set = w.account.barSets.PRIEST.Pets
    assert(set.bindings["CTRL-1"] == "BONUSACTIONBUTTON1" and set.bindings["CTRL-0"] == "BONUSACTIONBUTTON10")
    w.binds = {}
    w.run("import Pets")
    local keys = {}
    for _, b in ipairs(w.binds) do keys[b[2]] = b[1] end
    assert(keys["CTRL-1"] == "BONUSACTIONBUTTON1" and keys["1"] == "ACTIONBUTTON1", "bound again")
    local choices = Choices()
    choices.petOff = true
    Sets.Save("NoPets", choices)
    set = w.account.barSets.PRIEST.NoPets
    assert(set.bindings["CTRL-1"] == nil and set.bindings["1"] == "ACTIONBUTTON1", "the pet bar left out keeps the rest")
end)
Case("a website layout binds pet bar keys, and never places a pet action", function()
    local w = World({})
    w.ns.Shared.Decode = { String = function()
        return { v = 1, class = 5, name = "Pet", slots = { [1] = { kind = "item", id = 6948 } },
            bindings = { ["SHIFT-1"] = "BONUSACTIONBUTTON1", F = "BONUSACTIONBUTTON2" } }
    end }
    w.ns.ImportActionBarString("!NFA1!x")
    w.run("import Pet")
    local keys = {}
    for _, b in ipairs(w.binds) do keys[b[2]] = b[1] end
    assert(keys["SHIFT-1"] == "BONUSACTIONBUTTON1" and keys.F == "BONUSACTIONBUTTON2", "the pet keys")
    assert(Bars(w) == "1=item6948", Bars(w))
end)
Case("/nf bars delete asks first, and keeps the set on No", function()
    local w = World({ 2055 })
    w.bars = { [1] = Spell(2055) }
    w.run("save Raid")
    local asked, yes
    w.ns.Confirm = function(text, onYes) asked, yes = text, onYes end
    w.run("delete Raid")
    assert(asked and asked:find("Raid", 1, true), "the delete is confirmed first")
    assert(w.account.barSets.PRIEST.Raid, "nothing is deleted before Yes")
    yes()
    assert(w.account.barSets.PRIEST.Raid == nil, "Yes deletes it")
    asked = nil
    w.run("delete %s%d|TInterface\\Icons\\X:0|t")
    assert(not asked and w.printed[#w.printed]:find("%s%d", 1, true), "an unknown name with format codes is only named")
end)

local function NewCharacter(set, level, guid)
    local w = World({ 598 })
    w.bars = { [1] = Spell(598), [3] = Macro("Pull") }
    w.macros = { { name = "Pull", icon = 1, body = "/say pull" } }
    w.run("save P")
    local n = World({ 598 })
    n.account, n.level, n.guid = w.account, level or 1, guid or "Player-2"
    n.opts.autoImportSets = set ~= "" and { PRIEST = set } or {}
    n.macros = { { name = "Pull", icon = 1, body = "/say pull" } }
    n.events.handler(n.events, "PLAYER_LOGIN")
    return n
end
local function EnterWorld(n) n.events.handler(n.events, "PLAYER_ENTERING_WORLD") end
Case("/nf ab imports the named set, and lists the sets with no name", function()
    local w = World({ 598 })
    w.bars = { [1] = Spell(598) }
    w.run("save Raid")
    w.bars = {}
    w.ns.ActionBarsImportCommand("  raid ")
    assert(Bars(w) == "1=spell598", Bars(w))
    w.ns.ActionBarsImportCommand("")
    assert(w.printed[#w.printed]:find("Raid", 1, true), w.printed[#w.printed])
    w.ns.ActionBarsImportCommand("Nope")
    assert(w.printed[#w.printed]:find("No bar set called Nope", 1, true), w.printed[#w.printed])
end)
Case("a level 1 character gets the chosen set once, after entering the world", function()
    local n = NewCharacter("P")
    assert(Bars(n) == "", "not before the world is entered")
    EnterWorld(n)
    assert(Bars(n) == "1=spell598 3=Pull", Bars(n))
    n.bars = {}
    n.events.handler(n.events, "PLAYER_LOGIN")
    EnterWorld(n)
    assert(Bars(n) == "", "a second login does not import again")
end)
Case("a character above level 1 is left alone", function()
    local n = NewCharacter("P", 2)
    EnterWorld(n)
    assert(Bars(n) == "" and next(n.account.barSetAuto or {}) == nil, Bars(n))
end)
Case("no set chosen, a missing set or Action Bars off imports nothing", function()
    local n = NewCharacter("")
    EnterWorld(n)
    assert(Bars(n) == "")
    n = NewCharacter("Gone")
    EnterWorld(n)
    assert(Bars(n) == "")
    n = NewCharacter("P")
    n.opts.enabled = false
    n.events.handler(n.events, "PLAYER_LOGIN")
    EnterWorld(n)
    assert(Bars(n) == "")
end)
Case("in combat the import waits for the end of combat", function()
    local n = NewCharacter("P")
    n.combat = true
    EnterWorld(n)
    assert(Bars(n) == "" and n.events.registered.PLAYER_REGEN_ENABLED, "waiting")
    n.combat = false
    n.events.handler(n.events, "PLAYER_REGEN_ENABLED")
    assert(Bars(n) == "1=spell598 3=Pull", Bars(n))
    assert(not n.events.registered.PLAYER_REGEN_ENABLED)
end)
Case("a level 1 character that has earned experience is left alone", function()
    local m = World({ 598 })
    m.bars = { [1] = Spell(598) }
    m.run("save P")
    local fresh = World({ 598 })
    fresh.account, fresh.level, fresh.guid, fresh.xp = m.account, 1, "Player-9", 40
    fresh.opts.autoImportSets = { PRIEST = "P" }
    fresh.events.handler(fresh.events, "PLAYER_LOGIN")
    EnterWorld(fresh)
    assert(Bars(fresh) == "", "an existing level 1 alt with experience keeps its bars: " .. Bars(fresh))
end)
Case("the choice is per class: another class's set is not imported", function()
    local n = NewCharacter("")
    n.opts.autoImportSets = { MAGE = "P" }
    n.events.handler(n.events, "PLAYER_LOGIN")
    EnterWorld(n)
    assert(Bars(n) == "", Bars(n))
end)
Case("renaming or deleting the chosen set follows it", function()
    local w = World({ 598 })
    w.bars = { [1] = Spell(598) }
    w.run("save Leveling")
    w.ns.ActionBars.SetAutoImport("Leveling")
    assert(w.opts.autoImportSets.PRIEST == "Leveling")
    w.ns.ActionBars.Rename("Leveling", "Leveling 2")
    assert(w.opts.autoImportSets.PRIEST == "Leveling 2", tostring(w.opts.autoImportSets.PRIEST))
    w.ns.ActionBars.Delete("Leveling 2")
    assert(w.opts.autoImportSets.PRIEST == nil, "deleting it clears the choice")
end)
Case("changing Fill In Later during the fight does not drop the wait for the end of combat", function()
    local n = NewCharacter("P")
    n.combat = true
    EnterWorld(n)
    n.ns.ActionBarSettings.Set("fillLater", false)
    assert(n.events.registered.PLAYER_REGEN_ENABLED, "still waiting")
    n.combat = false
    n.events.handler(n.events, "PLAYER_REGEN_ENABLED")
    assert(Bars(n) == "1=spell598 3=Pull", Bars(n))
end)
Case("an import backs up the bars first, and undo puts them back with their keys", function()
    local w = World({ 2055, 598 })
    w.bars = { [1] = Spell(2055), [2] = Macro("Pull") }
    w.macros = { { name = "Pull", icon = 1, body = "/say pull" } }
    w.binds = { { "ACTIONBUTTON1", "1" }, { "ACTIONBUTTON2", "2" } }
    w.run("save Before")
    w.bars = { [3] = Spell(598) }
    w.binds = { { "ACTIONBUTTON3", "3" } }
    w.run("save Raid")
    w.bars = { [1] = Spell(2055), [2] = Macro("Pull") }
    w.binds = { { "ACTIONBUTTON1", "1" }, { "ACTIONBUTTON2", "2" } }
    local lastBefore = w.ns.ActionBars.Last()
    w.run("import Raid")
    assert(Bars(w) == "3=spell598", Bars(w))
    local list = w.ns.ActionBars.Backups.List()
    assert(#list == 1 and list[1].why == "Before importing Raid", "one backup, named for the import")
    assert(list[1].set.macros[1].name == "Pull" and #list[1].set.macros == 1, "with the macros on its bars")
    w.macros = {}
    w.run("undo")
    assert(Bars(w) == "1=spell2055 2=Pull", Bars(w))
    assert(#w.macros == 1, "a macro on the backed-up bars is made again")
    local keys = {}
    for _, b in ipairs(w.binds) do if b[2] then keys[#keys + 1] = b[2] .. "=" .. b[1] end end
    table.sort(keys)
    assert(table.concat(keys, " ") == "1=ACTIONBUTTON1 2=ACTIONBUTTON2", table.concat(keys, " "))
    assert(w.ns.ActionBars.Last() == lastBefore, "the set it had before is its last again")
    w.run("undo")
    assert(w.printed[#w.printed] == "There is no import to undo.", w.printed[#w.printed])
end)
Case("undo puts back the exact ranks the bars had, with Highest Rank on", function()
    local w = World({ 2054, 2055, 598 })
    w.bars = { [3] = Spell(598) }
    w.run("save Raid")
    w.bars = { [1] = Spell(2054), [2] = Spell(2055) }
    w.opts.highestRank = true
    w.run("import Raid")
    assert(w.ns.ActionBars.Backups.List()[1].set.slots[2].top == true, "the backup marks the top rank it saw")
    w.learn(6064)
    w.run("undo")
    assert(Bars(w) == "1=spell2054 2=spell2055", "a Rank 1 kept and a rank learned since passed over: " .. Bars(w))
end)
Case("only the last ten backups are kept, newest first", function()
    local w = World({ 598 })
    w.bars = { [1] = Spell(598) }
    w.run("save Raid")
    for _ = 1, 12 do w.run("import Raid") end
    local list = w.ns.ActionBars.Backups.List()
    assert(#list == 10, #list)
    w.combat = true
    assert(w.ns.ActionBars.RestoreBackup(1) == nil, "never in combat")
end)
Case("an import can leave the keys or the macros out", function()
    local w = World({ 598 })
    w.bars = { [1] = Macro("Pull") }
    w.macros = { { name = "Pull", icon = 1, body = "/say pull" } }
    w.binds = { { "ACTIONBUTTON1", "1" } }
    w.run("save Raid")
    w.macros, w.bars, w.binds = {}, {}, {}
    w.ns.ActionBarSets.Import("Raid", false, { actions = true, macros = false, keys = false })
    assert(#w.macros == 0 and #w.binds == 0, "no macro made, no key bound")
    w.ns.ActionBarSets.Import("Raid", false, { actions = false, macros = true, keys = true })
    assert(#w.macros == 1 and Bars(w) == "" and w.binds[1][2] == "1", "macros and keys, bars left alone")
end)
Case("the bar check upgrades a spell below the best rank, or leaves it once asked", function()
    local w = World({ 2054, 2055 })
    w.bars = { [1] = Spell(2054), [2] = Spell(2054) }
    local list = w.ns.ActionBars.Check.Upgrades()
    assert(#list == 2 and list[1].best == 2055, "both slots listed")
    w.ns.ActionBars.Check.Upgrade({ list[1] })
    assert(Bars(w) == "1=spell2055 2=spell2054", Bars(w))
    w.ns.ActionBars.Check.Keep(w.ns.ActionBars.Check.Upgrades())
    assert(#w.ns.ActionBars.Check.Upgrades() == 0, "kept for downranking")
end)

print(count .. " action bar set regressions passed")

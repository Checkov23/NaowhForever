-- Run with Lua 5.1 from the repository root: the Profiles page's whole-profile Export and
-- Import, through the real LibSerialize and LibDeflate. What a string carries, what it
-- leaves home, and what Import lands, part by part, without touching an existing profile.
strmatch = string.match   -- LibStub's, as the game has it
dofile("Libs/LibStub/LibStub.lua")
dofile("Libs/LibDeflate/LibDeflate.lua")
dofile("Libs/LibSerialize/LibSerialize.lua")

local PlainText = dofile("Tools/regression/plain_text.lua")()
local settingsShared = { Style = dofile("Tools/regression/shared_style.lua"), Settings = {} }
local settingsStyle = assert(loadfile("Shared/Settings/Style.lua"))
setfenv(settingsStyle, { _G = { NaowhForever = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Shared = settingsShared } }, setmetatable = setmetatable })
settingsStyle()

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

local function Copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = type(v) == "table" and Copy(v) or v end
    return out
end

local DEFAULTS = {
    qol = { enabled = true, fastLoot = false, bisSlots = {} },
    macros = { enabled = true, classMacros = {}, foodBar = false },
    topBar = { enabled = true, mouseoverAlpha = 0 },
    actionBars = { enabled = false, autoImportSets = {} },
}

-- A fresh account: one profile, Default, with something in every part.
local function World()
    local w = { switched = nil, refreshed = 0 }
    w.db = {
        profiles = {
            Default = {
                qol = { fastLoot = true, bisSlots = { [1] = 6948 }, lootFeedPos = { "TOP", 10, -20 },
                    questRewards = { [100] = 111, [200] = 222 } },
                topBar = { mouseoverAlpha = 0.4 },
                macros = { foodBar = true },
                tankReminder = { leadTime = 5, presets = { { name = "Mine" } },
                    utilityReminders = { classMacros = { PALADIN = { { name = "BoP", body = "/cast BoP" } } },
                        consumables = { { category = "food", itemID = 13931 } }, other = 1 } },
                notAModule = { secret = "x" },
            },
        },
        account = {
            themePreset = "slate", uiFont = "Naowh", windowScale = 1.1,
            bisLists = { PALADIN = { lists = { { id = 1, name = "Prot", slots = { [1] = 100 } } }, nextID = 2 } },
            barSets = { PALADIN = { Raid = { saved = 100, by = "Glyadin",
                slots = { [1] = { kind = "spell", id = 635, name = "Holy Light" },
                    [2] = { kind = "macro", name = "BoP", body = "/cast BoP", icon = 134400, perCharacter = true } },
                macros = { { name = "BoP", body = "/cast BoP", icon = 134400, perCharacter = true } },
                bindings = { ["SHIFT-1"] = "ACTIONBUTTON1" },
                choices = { skip = { [3] = true }, macroOff = {}, keys = true, macros = true } } } },
            libraryMacros = { PALADIN = { { name = "Seal", body = "/cast Seal", icon = 135 },
                { name = "Packed", body = "/cast Pack", pack = true } } },
            trainingBuilds = { [2] = { { name = "Ret", spec = "Retribution", points = { 11, 12 }, saved = true,
                skip = { [20] = true, [10] = true } } } },
        },
    }
    w.active = "Default"
    w.buildsChanged = 0
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        UI = { PROFILES_PAGE = "Profiles" }, CODE_BUILD = "test", PlainText = PlainText,
        Macros = { C = { LIMIT = 255 } },
        TrainingBuilds = { [2] = { talents = {} } },
        -- Points that cannot be taken start with 0 here; the real rules are Training's own test.
        Training = {
            CheckBuild = function(_, points) return points[1] == 0 and "Already at full rank." or nil end,
            CleanSkips = function(_, list)
                local skip = {}
                for _, spell in ipairs(list or {}) do skip[spell] = true end
                return next(skip) and skip or nil
            end,
            BuildName = function(text, default) return type(text) == "string" and text ~= "" and text or default end,
            Changed = function() w.buildsChanged = w.buildsChanged + 1 end,
        },
        SettingsRoot = function() return w.db.profiles[w.active] end,
        AccountSettings = function() return w.db.account end,
        ModuleDefaults = function(key) return DEFAULTS[key] end,
        ActiveProfileName = function() return w.active end,
        ProfileExists = function(name) return w.db.profiles[name] ~= nil end,
        ProfileRoot = function(name)
            w.db.profiles[name] = w.db.profiles[name] or { tankReminder = {} }
            return w.db.profiles[name]
        end,
        SwitchProfile = function(name) w.switched, w.active = name, name end,
        RefreshRuntime = function() w.refreshed = w.refreshed + 1 end,
        ModuleOn = function(addon) return w.off[addon] ~= true end,
    }
    w.off = {}
    w.ns = ns
    local env = setmetatable({ _G = { NaowhForever = ns }, UnitName = function() return "Glyadin" end,
        date = os.date, CopyTable = Copy }, { __index = _G })
    ns.Shared = { Decode = dofile("Tools/regression/load_decode.lua")(env), Settings = settingsShared.Settings }
    for _, path in ipairs({ "Core/Profiles/Positions.lua", "Core/Profiles/ProfileShare.lua", "Core/Profiles/ProfileDialogs.lua",
        "Core/Options/ProfilesPage.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    return w
end

local ALL = { settings = true, macros = true, library = true, consumables = true, builds = true,
    bisLists = true, actionBars = true, questRewards = true, look = true }

-- What a string from before Macro Library and Consumables left the picker carries on top of today's export.
local function Payload(w)
    local payload = assert(w.ns.DecodeProfile((w.ns.ExportProfile())))
    payload.parts.consumables = { { category = "food", itemID = 13931 } }
    payload.parts.library = { PALADIN = { { name = "Seal", body = "/cast Seal", icon = 135 },
        { name = "Packed", body = "/cast Pack" } } }
    return payload
end

Case("export: one string with every part, personal data left home", function()
    local w = World()
    local text = assert(w.ns.ExportProfile())
    assert(text:sub(1, 11) == "NFPROFILE1:", text:sub(1, 20))
    local payload = assert(w.ns.DecodeProfile(text))
    local parts = payload.parts
    assert(payload.name == "Default" and payload.author == "Glyadin")
    assert(parts.settings.qol.fastLoot == true and parts.settings.qol.bisSlots[1] == 6948)
    assert(parts.settings.qol.lootFeedPos[2] == 10, "positions travel")
    assert(parts.settings.notAModule == nil and parts.settings.macros == nil and parts.settings.tankReminder == nil)
    assert(parts.macros.module.foodBar == true and parts.macros.classMacros.PALADIN[1].name == "BoP")
    assert(parts.consumables == nil and parts.library == nil, "Consumables and the Macro Library are not shared")
    assert(parts.questRewards[100] == 111 and parts.questRewards[200] == 222)
    assert(parts.settings.qol.questRewards == nil, "the picks travel as their own part")
    assert(parts.reminders == nil and parts.smartReminders == nil, "the rest of the reminders' store stays home")
    assert(parts.bisLists.PALADIN[1].name == "Prot")
    assert(parts.builds[2][1].name == "Ret" and parts.builds[2][1].points[2] == 12)
    assert(parts.builds[2][1].saved == nil)
    assert(parts.look.themePreset == "slate" and parts.look.windowScale == 1.1)
    assert(parts.actionBars.PALADIN.Raid.slots[1].id == 635 and parts.actionBars.PALADIN.Raid.bindings["SHIFT-1"])
    assert(parts.barSets == nil and parts.look.barSets == nil, "bar sets travel only as their own part")
end)

Case("export: only the ticked parts go in", function()
    local w = World()
    local text, note = w.ns.ExportProfile({ builds = true, bisLists = true })
    local parts = assert(w.ns.DecodeProfile(text)).parts
    assert(parts.builds and parts.bisLists and parts.settings == nil and parts.look == nil)
    assert(parts.questRewards == nil, "the picks stay home unless ticked")
    assert(note == nil, tostring(note))
    text, note = w.ns.ExportProfile({})
    assert(text == nil and note == "Tick a part to share.", tostring(note))
end)

Case("export: the picks follow Saved Quest Items alone", function()
    local w = World()
    local parts = assert(w.ns.DecodeProfile(assert(w.ns.ExportProfile({ settings = true, macros = true })))).parts
    assert(parts.questRewards == nil and parts.settings.qol.questRewards == nil and parts.settings.qol.fastLoot == true)
    parts = assert(w.ns.DecodeProfile(assert(w.ns.ExportProfile({ questRewards = true })))).parts
    assert(parts.questRewards[100] == 111 and parts.settings == nil)
    w.db.profiles.Default.qol.questRewards = {}
    parts = assert(w.ns.DecodeProfile(assert(w.ns.ExportProfile()))).parts
    assert(parts.questRewards == nil, "no picks, no part")
end)

Case("the string survives being wrapped and pasted with spaces", function()
    local w = World()
    local text = assert(w.ns.ExportProfile())
    local wrapped = text:sub(1, 30) .. "\n  " .. text:sub(31, 70) .. "\r\n" .. text:sub(71)
    assert(w.ns.DecodeProfile(wrapped))
end)

local function OldString(parts)
    local LS, LD = LibStub("LibSerialize"), LibStub("LibDeflate")
    return "NFPROFILE1:" .. LD:EncodeForPrint(LD:CompressDeflate(LS:Serialize({ format = 1, name = "Old",
        parts = parts })))
end

Case("an older string's reminders part brings only its consumables, under either old key", function()
    local w = World()
    for _, key in ipairs({ "smartReminders", "reminders" }) do
        local parts = assert(w.ns.DecodeProfile(OldString({ [key] = { leadTime = 9, presets = { { name = "X" } },
            utilityReminders = { other = 2, consumables = { { category = "flask", itemID = 13510, auras = { 17628 } } },
                classMacros = { MAGE = { { name = "Blink", body = "/cast Blink" } } } } } }))).parts
        assert(parts.consumables[1].itemID == 13510 and parts.consumables[1].auras[1] == 17628, key)
        assert(parts.smartReminders == nil and parts.reminders == nil and parts.macros == nil, key)
        w.ns.ImportProfile({ name = "Old", parts = parts }, ALL, "From " .. key)
        local sr = w.db.profiles["From " .. key].tankReminder
        assert(sr.utilityReminders.consumables[1].itemID == 13510, key)
        assert(sr.leadTime == nil and sr.presets == nil and sr.utilityReminders.other == nil, key)
        assert(sr.utilityReminders.classMacros == nil, "class macros travel only as Macros")
    end
    local parts = assert(w.ns.DecodeProfile(OldString({ consumables = { { category = "food", itemID = 1 } },
        smartReminders = { utilityReminders = { consumables = { { category = "food", itemID = 2 } } } } }))).parts
    assert(parts.consumables[1].itemID == 1 and #parts.consumables == 1 and parts.smartReminders == nil,
        "the new part wins over an old one")
    parts = assert(w.ns.DecodeProfile(OldString({ smartReminders = { leadTime = 9 } }))).parts
    assert(parts.consumables == nil and parts.smartReminders == nil, "an old part with no consumables brings nothing")
end)

Case("a new string carries nothing of the reminders' store", function()
    local w = World()
    local LS, LD = LibStub("LibSerialize"), LibStub("LibDeflate")
    local text = assert(w.ns.ExportProfile())
    local ok, raw = LS:Deserialize(LD:DecompressDeflate(LD:DecodeForPrint(text:sub(12))))
    assert(ok and raw.parts.consumables == nil and raw.parts.library == nil)
    assert(raw.parts.smartReminders == nil and raw.parts.reminders == nil)
end)

Case("a profile that once came from a pack shares like any other, and never names the pack", function()
    local w = World()
    w.db.profiles.Default.tankReminder.importedPack = { name = "Naowh's Pack", author = "Naowh", licensed = true }
    local text, note = w.ns.ExportProfile()
    assert(note == nil, tostring(note))
    local LD = LibStub("LibDeflate")
    assert(not LD:DecompressDeflate(LD:DecodeForPrint(text:sub(12))):find("Naowh's Pack", 1, true))
    local parts = assert(w.ns.DecodeProfile(text)).parts
    assert(parts.macros.classMacros.PALADIN[1].name == "BoP")
    assert(parts.macros.module.foodBar == true and parts.settings.qol, "the rest still goes")
end)

Case("the parts a string holds, for the import's ticks", function()
    local w = World()
    local list = w.ns.ProfileStringParts(assert(w.ns.DecodeProfile((w.ns.ExportProfile()))))
    local keys = {}
    for _, part in ipairs(list) do keys[#keys + 1] = part.key .. (part.detail and (":" .. part.detail) or "") end
    assert(table.concat(keys, ",") == "settings:2 modules,macros:1 class macros,builds:1 builds,bisLists:1 lists,"
        .. "actionBars:1 bar sets,questRewards:2 quest rewards,look", table.concat(keys, ","))
    keys = {}
    for _, part in ipairs(w.ns.ProfileStringParts(Payload(w))) do keys[#keys + 1] = part.key end
    assert(table.concat(keys, ",") == "settings,macros,builds,bisLists,actionBars,questRewards,look,library,consumables",
        "a string from an older build still offers what it carries: " .. table.concat(keys, ","))
    for _, part in ipairs(w.ns.Profiles.PARTS) do
        assert(part.key ~= "library" and part.key ~= "consumables", "the picker no longer offers " .. part.key)
    end
end)

Case("a module's on/off travels with Settings, and lands as the imported profile's switches",
    function()
    local w = World()
    local store = { Set = function() end }
    local calls = {}
    _G.UnitGUID = function() return "Player-1-1" end
    _G.C_AddOns = {
        EnableAddOn = function(addon) calls[#calls + 1] = "enable:" .. addon end,
        DisableAddOn = function(addon) calls[#calls + 1] = "disable:" .. addon end,
    }
    w.ns.Setup = { ITEMS = {
        discovery = { addon = "NaowhForever_Discovery", db = "discovery", key = "enabled" },
        gearSets = { addon = "NaowhForever_GearSets", db = "qol", key = "gearSets" },
    } }
    w.ns.ModuleAddons = function(who)
        assert(who == "Player-1-1", "the export reads this character's list")
        return {
            { addon = "NaowhForever_Discovery", store = store, key = "enabled", on = true },
            { addon = "NaowhForever_GearSets", store = store, key = "gearSets", on = false },
        }
    end
    local text = assert(w.ns.ExportProfile())
    local parts = assert(w.ns.DecodeProfile(text)).parts
    assert(parts.settings.__modules.NaowhForever_Discovery == true)
    assert(parts.settings.__modules.NaowhForever_GearSets == false)

    w.ns.ImportProfile(assert(w.ns.DecodeProfile(text)), { settings = true }, "Modules")
    local p = w.db.profiles.Modules
    assert(p.discovery.enabled == true and p.qol.gearSets == false, "each module's switch in the new profile")
    assert(#calls == 0, "the AddOn list follows when the profile is switched to, not at the import")
    _G.C_AddOns, _G.UnitGUID = nil, nil
end)

Case("import: a new profile with every part, switched to, the old one untouched", function()
    local w = World()
    local payload = Payload(w)
    local before = w.db.profiles.Default.qol.fastLoot
    w.db.account.themePreset = "midnight"
    local name, added = w.ns.ImportProfile(payload, ALL, "Default")
    assert(name == "Default 2" and w.switched == "Default 2" and w.refreshed == 1, name)
    local p = w.db.profiles["Default 2"]
    assert(p.qol.fastLoot == true and p.topBar.mouseoverAlpha == 0.4 and p.macros.foodBar == true)
    assert(p.tankReminder.utilityReminders.classMacros.PALADIN[1].name == "BoP")
    assert(p.tankReminder.utilityReminders.consumables[1].itemID == 13931)
    assert(p.qol.questRewards[100] == 111 and p.qol.questRewards[200] == 222)
    assert(p.tankReminder.leadTime == nil and p.tankReminder.presets == nil and p.tankReminder.utilityReminders.other == nil,
        "only the consumables and class macros of the store")
    assert(w.db.account.themePreset == "slate", "the look comes in")
    assert(added.bisLists == 0 and added.library == 0 and added.builds == 0 and added.actionBars == 0,
        "what you have is not added twice")
    assert(#w.db.account.libraryMacros.PALADIN == 2 and #w.db.account.trainingBuilds[2] == 1)
    assert(w.db.profiles.Default.qol.fastLoot == before)
end)

Case("import: unticked parts stay out", function()
    local w = World()
    local payload = assert(w.ns.DecodeProfile((w.ns.ExportProfile())))
    w.db.account.themePreset = "midnight"
    w.ns.ImportProfile(payload, { settings = true }, "Fresh")
    local p = w.db.profiles.Fresh
    assert(p.qol.fastLoot == true and p.macros == nil and p.tankReminder.utilityReminders == nil)
    assert(w.db.account.themePreset == "midnight", "the look stays")
end)

Case("what you answered about EllesmereUI's windows stays home, both ways", function()
    local w = World()
    local q = w.db.profiles.Default.qol
    q.characterPanelAsked, q.characterPanelTookOver, q.inspectPanelAsked, q.inspectPanelTookOver = true, true, true, true
    local payload = assert(w.ns.DecodeProfile((w.ns.ExportProfile())))
    local out = payload.parts.settings.qol
    assert(out.fastLoot == true and out.characterPanelAsked == nil and out.characterPanelTookOver == nil
        and out.inspectPanelAsked == nil and out.inspectPanelTookOver == nil, "export leaves them out")
    out.characterPanelAsked, out.characterPanelTookOver, out.inspectPanelAsked, out.inspectPanelTookOver = true, true, true, true
    w.ns.ImportProfile(payload, { settings = true }, "Theirs")
    local p = w.db.profiles.Theirs.qol
    assert(p.fastLoot == true and p.characterPanelAsked == nil and p.characterPanelTookOver == nil
        and p.inspectPanelAsked == nil and p.inspectPanelTookOver == nil, "an older string's are not taken in")
end)

Case("Macros without Consumables still brings the class macros, and the other way round", function()
    local w = World()
    local payload = Payload(w)
    w.ns.ImportProfile(payload, { macros = true }, "Macros Only")
    local sr = w.db.profiles["Macros Only"].tankReminder
    assert(sr.utilityReminders.classMacros.PALADIN[1].body == "/cast BoP" and sr.utilityReminders.consumables == nil)
    w.ns.ImportProfile(payload, { consumables = true }, "Consumables Only")
    sr = w.db.profiles["Consumables Only"].tankReminder
    assert(sr.utilityReminders.consumables[1].itemID == 13931 and sr.utilityReminders.classMacros == nil)
end)

Case("Consumables replace only the list, never the rest of the reminders' store", function()
    local w = World()
    local payload = Payload(w)
    local root = w.ns.ProfileRoot("Kept")
    local macros = { MAGE = { { name = "Blink", body = "/cast Blink" } } }
    root.tankReminder = { leadTime = 9, utilityReminders = { classMacros = macros, other = 3,
        consumables = { { category = "flask", itemID = 1 } } } }
    ---@diagnostic disable-next-line: duplicate-set-field
    w.ns.ProfileExists = function(name) return name == "Kept" end
    w.ns.ImportProfile(payload, { consumables = true }, "Kept", true)
    local sr = w.db.profiles.Kept.tankReminder
    assert(sr.utilityReminders.consumables[1].itemID == 13931 and #sr.utilityReminders.consumables == 1)
    assert(sr.leadTime == nil and sr.utilityReminders.classMacros == nil, "an overwrite still starts empty")
    w.db.profiles.Fresh = { tankReminder = { leadTime = 9, utilityReminders = { classMacros = macros, other = 3 } } }
    local fresh = w.db.profiles.Fresh
    w.ns.ProfileRoot = function() return fresh end
    ---@diagnostic disable-next-line: duplicate-set-field
    w.ns.ProfileExists = function() return false end
    w.ns.ImportProfile(payload, { consumables = true }, "Fresh")
    assert(fresh.tankReminder.leadTime == 9 and fresh.tankReminder.utilityReminders.other == 3)
    assert(fresh.tankReminder.utilityReminders.classMacros == macros)
    assert(fresh.tankReminder.utilityReminders.consumables[1].itemID == 13931)
end)

Case("import: Keep My Positions keeps where your frames sit, and only that", function()
    local w = World()
    local mine = w.db.profiles.Default
    mine.unlockMode = { layouts = { Mine = { spots = {} } }, hidden = { ["XP Bar"] = true } }
    local payload = assert(w.ns.DecodeProfile((w.ns.ExportProfile())))
    local theirs = payload.parts.settings.qol
    theirs.lootFeedPos, theirs.alertsPos, theirs.fastLoot = { "BOTTOM", 1, 2 }, { "TOP", 3, 4 }, true
    w.ns.ImportProfile(payload, { settings = true, keepPositions = true }, "Kept")
    local p = w.db.profiles.Kept
    assert(p.qol.fastLoot == true, "their settings come in")
    assert(p.qol.lootFeedPos[1] == "TOP" and p.qol.lootFeedPos[2] == 10, "your frame stays where it was")
    assert(p.qol.alertsPos == nil, "a frame you never moved keeps its default, not theirs")
    assert(p.qol.lootFeedPos ~= mine.qol.lootFeedPos, "copied, so the two profiles never share a table")
    assert(p.unlockMode.layouts.Mine and p.unlockMode.hidden["XP Bar"] == true, "your HUD Editor layouts and hidden elements")
    w.ns.ImportProfile(payload, { settings = true }, "Theirs")
    assert(w.db.profiles.Theirs.qol.lootFeedPos[1] == "BOTTOM", "unticked, their positions come in")
    w.db.profiles.Main, w.active = Copy(mine), "Main"
    w.ns.ImportProfile(payload, { settings = true, keepPositions = true }, "Main", true)
    assert(w.db.profiles.Main.qol.lootFeedPos[2] == 10 and w.db.profiles.Main.unlockMode.layouts.Mine,
        "an overwrite of the profile you are on keeps them through the wipe")
end)

Case("overwrite: a rerun empties the named profile and lands there", function()
    local w = World()
    local payload = assert(w.ns.DecodeProfile((w.ns.ExportProfile())))
    w.db.profiles.Naowh = { stale = { x = 1 }, qol = { fastLoot = false }, tankReminder = { leadTime = 9 } }
    local name = w.ns.ImportProfile(payload, { settings = true, macros = true }, " Naowh ", true)
    local p = w.db.profiles.Naowh
    assert(name == "Naowh" and w.switched == "Naowh" and w.db.profiles["Naowh 2"] == nil, name)
    assert(p.stale == nil and p.qol.fastLoot == true, "what the old one held is gone")
    assert(p.tankReminder.leadTime == nil and p.tankReminder.utilityReminders.classMacros.PALADIN[1].name == "BoP")
end)

Case("overwrite: never Default, and a name not taken is just made", function()
    local w = World()
    local payload = assert(w.ns.DecodeProfile((w.ns.ExportProfile())))
    assert(w.ns.ImportProfile(payload, ALL, "Default", true) == "Default 2")
    assert(w.db.profiles.Default.tankReminder.leadTime == 5)
    assert(w.ns.ImportProfile(payload, ALL, "Naowh", true) == "Naowh")
end)

Case("BiS lists join yours under a free name, never over them", function()
    local w = World()
    local payload = assert(w.ns.DecodeProfile((w.ns.ExportProfile())))
    payload.parts.bisLists.PALADIN[1].slots[1] = 200
    payload.parts.bisLists.MAGE = { { name = "Fire", spec = "fire-mage", specOnly = true, slots = { [5] = 300 } },
        { name = "Frost", specOnly = "yes", slots = { [5] = 300 } } }
    local _, added = w.ns.ImportProfile(payload, { bisLists = true }, "B")
    local paladin = w.db.account.bisLists.PALADIN.lists
    assert(added.bisLists == 3 and #paladin == 2 and paladin[1].slots[1] == 100, "yours kept")
    assert(paladin[2].name == "Prot 2" and paladin[2].id == 2 and w.db.account.bisLists.PALADIN.nextID == 3)
    local mage = w.db.account.bisLists.MAGE.lists
    assert(mage[1].name == "Fire" and mage[1].specOnly == true, "a spec-only list stays one")
    assert(mage[2].specOnly == nil and paladin[2].specOnly == nil, "anything but true is a class list")
end)

Case("bar sets join yours under a free name, never over them", function()
    local w = World()
    local payload = assert(w.ns.DecodeProfile((w.ns.ExportProfile({ actionBars = true }))))
    local raid = payload.parts.actionBars.PALADIN.Raid
    assert(raid.choices.skip[3] == true and raid.macros[1].body == "/cast BoP")
    raid.saved = 200
    raid.slots[1].id = 19750
    payload.parts.actionBars.MAGE = { Leveling = { saved = 300, slots = { [5] = { kind = "item", id = 5512 } } } }
    payload.parts.settings = { actionBars = { autoImportSets = { PALADIN = "Raid", MAGE = "Leveling" } } }
    local _, added = w.ns.ImportProfile(payload, { actionBars = true, settings = true }, "B")
    local paladin = w.db.account.barSets.PALADIN
    assert(added.actionBars == 2, tostring(added.actionBars))
    assert(paladin.Raid.saved == 100 and paladin.Raid.slots[1].id == 635, "yours kept")
    assert(paladin["Raid 2"].slots[1].id == 19750 and paladin["Raid 2"].bindings["SHIFT-1"] == "ACTIONBUTTON1")
    assert(paladin["Raid 2"].choices.keys == true and paladin["Raid 2"].choices.macroOff, "its choices come along")
    assert(w.db.account.barSets.MAGE.Leveling.slots[5].id == 5512, "every class's sets")
    local chosen = w.db.profiles.B.actionBars.autoImportSets
    assert(chosen.PALADIN == "Raid 2" and chosen.MAGE == "Leveling", "the auto import choice follows the rename")
    payload.parts.settings = { actionBars = { autoImportSets = { PALADIN = "Raid" } } }
    _, added = w.ns.ImportProfile(payload, { actionBars = true, settings = true }, "C")
    assert(added.actionBars == 0 and paladin["Raid 3"] == nil, "a set you already took is not added again")
    assert(w.db.account.barSets.MAGE["Leveling 2"] == nil)
    assert(w.db.profiles.C.actionBars.autoImportSets.PALADIN == "Raid 2", "and points at the one you took")
end)

Case("a bar set keeps only what an import can use", function()
    local w = World()
    w.db.account.barSets = nil
    w.ns.ImportProfile({ name = "X", parts = { actionBars = {
        PALADIN = {
            Good = { slots = { [1] = { kind = "spell", id = 635 }, [2] = { kind = "spell" },
                [3] = { kind = "Bad", id = 1 }, [4] = { kind = "macro", name = "x" }, [-1] = { kind = "item", id = 1 },
                [5] = { kind = "flyout", id = 9 } },
                macros = { { name = "A|cff", body = "/x" }, { name = "B", body = "/b" } },
                bindings = { ["CTRL-1"] = "ACTIONBUTTON1", ["X|r"] = "ACTIONBUTTON2", W = "MOVEFORWARD",
                    ENTER = "OPENCHAT", ["CTRL-F12"] = "MULTIACTIONBAR7BUTTON12", F1 = "MULTIACTIONBAR8BUTTON1",
                    F2 = "ACTIONBUTTON13", F3 = "ACTIONBUTTON0", F4 = "ACTIONBUTTON", F5 = "ACTIONBUTTON1X",
                    ["1"] = "ACTIONBUTTON3", ["2"] = "ACTIONBUTTON3", ["3"] = "ACTIONBUTTON3", [5] = "ACTIONBUTTON4" },
                choices = { skip = { [7] = true, x = true }, macroOff = { k = "yes" }, keys = "no", website = true } },
            NoSlots = { macros = {} },
            ["Bad|cname"] = { slots = {} },
        },
        lowercase = { Set = { slots = {} } },
    } } }, { actionBars = true }, "Junk")
    local sets = w.db.account.barSets.PALADIN
    local good = sets.Good
    assert(good.slots[1].id == 635 and good.slots[5].kind == "flyout")
    assert(good.slots[2] == nil and good.slots[3] == nil and good.slots[4] == nil and good.slots[-1] == nil)
    assert(#good.macros == 1 and good.macros[1].name == "B")
    assert(good.bindings["CTRL-1"] and good.bindings["X|r"] == nil)
    assert(good.bindings["CTRL-F12"] == "MULTIACTIONBAR7BUTTON12", "every bar's buttons")
    assert(good.bindings.W == nil and good.bindings.ENTER == nil, "movement and chat keys stay yours")
    for _, key in ipairs({ "F1", "F2", "F3", "F4", "F5" }) do
        assert(good.bindings[key] == nil, "no button past the bars: " .. key)
    end
    local three = 0
    for _, command in pairs(good.bindings) do
        if command == "ACTIONBUTTON3" then three = three + 1 end
    end
    assert(three == 2 and good.bindings[5] == nil, "at most 2 keys a button")
    assert(good.choices.skip[7] and good.choices.skip.x == nil and next(good.choices.macroOff) == nil)
    assert(good.choices.keys == nil and good.choices.website == true)
    assert(sets.NoSlots == nil and sets["Bad|cname"] == nil and w.db.account.barSets.lowercase == nil)
end)

Case("the installer API leaves bar sets out, both ways", function()
    local w = World()
    local ns = w.ns
    ns.ListProfiles = function() return { "Default" } end
    ns.ProfileTable = function(name) return w.db.profiles[name] end
    ns.SetAccountProfile = function() return true end
    local API = getfenv(ns.ExportProfile)._G.NaowhForever_API
    local parts = assert(ns.DecodeProfile(assert(API:ExportProfile("Default")))).parts
    assert(parts.actionBars == nil and parts.settings and parts.bisLists and parts.look, "every other part goes")
    local text = assert(ns.ExportProfile())
    w.db.account.barSets.PALADIN.Raid = nil
    assert(API:ImportProfile(text, "Naowh"))
    assert(w.switched == "Naowh" and w.db.profiles.Naowh.qol.fastLoot == true, "the rest lands")
    assert(w.db.account.barSets.PALADIN.Raid == nil, "a string with bar sets adds none through the API")
end)

Case("Library macros join yours; a name you have, or one that is no macro, stays out", function()
    local w = World()
    local payload = Payload(w)
    local paladin = payload.parts.library.PALADIN
    paladin[1].body = "/cast Theirs"
    paladin[2] = { name = "Wings|r\n", body = "/cast Wings", icon = { 1 } }
    paladin[3] = { name = "SeventeenLetters!", body = "/x" }
    paladin[4] = { name = "Empty", body = "" }
    paladin[5] = { name = "Long", body = string.rep("x", 256) }
    payload.parts.library.MAGE = { { name = "Blink", body = "/cast Blink" } }
    local _, added = w.ns.ImportProfile(payload, { library = true }, "L")
    local mine = w.db.account.libraryMacros
    assert(added.library == 2, added.library)
    assert(mine.PALADIN[1].body == "/cast Seal", "yours kept")
    assert(mine.PALADIN[3].name == "Wingsr" and mine.PALADIN[3].icon == nil and mine.PALADIN[3].pack == nil)
    assert(mine.MAGE[1].name == "Blink" and #mine.PALADIN == 3)
end)

Case("with Macros switched off, though its addon is loaded, no library macro is added", function()
    local w = World()
    local payload = Payload(w)
    payload.parts.library.MAGE = { { name = "Blink", body = "/cast Blink" } }
    w.off.NaowhForever_Macros = true
    local _, added = w.ns.ImportProfile(payload, { library = true }, "L")
    assert(added.library == 0 and w.db.account.libraryMacros.MAGE == nil, "nothing joins a switched-off Macros")
end)

Case("talent builds join yours when they can be taken; a class with no tree stays out", function()
    local w = World()
    local payload = assert(w.ns.DecodeProfile((w.ns.ExportProfile())))
    local list = payload.parts.builds[2]
    assert(table.concat(list[1].skip, " ") == "10 20", "the skip list travels as a sorted list")
    list[2] = { name = "Ret", spec = "Retribution", points = { 11, 13 }, skip = { 30 } }
    list[3] = { name = "", points = { 14 } }
    list[4] = { name = "Broken", points = { 0, 1 } }
    list[5] = { name = "Nothing", points = {} }
    payload.parts.builds[99] = { { name = "Ghost", points = { 1 } } }
    local _, added = w.ns.ImportProfile(payload, { builds = true }, "T")
    local saved = w.db.account.trainingBuilds
    assert(added.builds == 2 and #saved[2] == 3, added.builds)
    assert(saved[2][2].points[2] == 13 and saved[2][2].saved == true and saved[2][2].skip[30] == true)
    assert(saved[2][3].name == "Imported Build" and saved[2][3].spec == "Imported")
    assert(saved[99] == nil and w.buildsChanged == 1)
end)

Case("a value of the wrong type, or for no module, is not taken in", function()
    local w = World()
    local payload = Payload(w)
    payload.parts.settings.qol.fastLoot = "yes"
    payload.parts.settings.bogus = { x = 1 }
    payload.parts.consumables[1].importedPack = { name = "fake", licensed = true }
    payload.parts.importedPack = { name = "fake", licensed = true }
    payload.parts.tankReminder = { leadTime = 1 }
    w.ns.ImportProfile(payload, ALL, "Checked")
    local p = w.db.profiles.Checked
    assert(p.qol.fastLoot == nil and p.qol.bisSlots[1] == 6948 and p.bogus == nil)
    assert(p.tankReminder.importedPack == nil and p.importedPack == nil, "a string cannot claim a pack")
    assert(p.tankReminder.leadTime == nil and p.tankReminder.utilityReminders.consumables[1].importedPack == nil)
end)

Case("a string from before Death Release, Combat Logging and Summon Emote were removed still imports", function()
    local w = World()
    local payload = assert(w.ns.DecodeProfile((w.ns.ExportProfile())))
    local qol = payload.parts.settings.qol
    qol.deathRelease, qol.deathReleaseHold, qol.combatLogger, qol.combatLogRaids = true, 2, true, "always"
    qol.autoEmote, qol.autoEmoteList = true, "698: prepares a ritual of summoning"
    assert(#w.ns.ProfileActing(payload) == 0, "the removed Summon Emote is not named")
    w.ns.ImportProfile(payload, ALL, "Old")
    local p = w.db.profiles.Old
    assert(p.qol.fastLoot == true and p.qol.bisSlots[1] == 6948, "the rest of the string comes along")
end)

-- Forever raises on 1 / 0, which LibSerialize does to each 0 it writes: none may reach it.
Case("a 0 comes back as 0 and never reaches the serializer", function()
    local w = World()
    w.db.profiles.Default.topBar.mouseoverAlpha = 0
    w.db.profiles.Default.qol.lootFeedPos = { "TOP", 0, -20 }
    local LS = LibStub("LibSerialize")
    local serialize = LS.Serialize
    local function NoZero(v)
        assert(v ~= 0, "Division by zero")
        if type(v) == "table" then for k, val in pairs(v) do NoZero(k); NoZero(val) end end
    end
    LS.Serialize = function(self, ...)
        for i = 1, select("#", ...) do NoZero((select(i, ...))) end
        return serialize(self, ...)
    end
    local text = w.ns.ExportProfile()
    LS.Serialize = serialize
    local parts = assert(w.ns.DecodeProfile(assert(text))).parts
    assert(parts.settings.topBar.mouseoverAlpha == 0 and parts.settings.qol.lootFeedPos[2] == 0)
end)

Case("import: Saved Quest Items lands on its own, and not with Settings alone", function()
    local w = World()
    local payload = assert(w.ns.DecodeProfile((w.ns.ExportProfile())))
    w.ns.ImportProfile(payload, { settings = true }, "No Picks")
    assert(w.db.profiles["No Picks"].qol.fastLoot == true and w.db.profiles["No Picks"].qol.questRewards == nil)
    w.ns.ImportProfile(payload, { questRewards = true }, "Picks Only")
    local only = w.db.profiles["Picks Only"].qol
    assert(only.questRewards[100] == 111 and only.fastLoot == nil)
    w.ns.ImportProfile(payload, { settings = true, questRewards = true }, "Both")
    local both = w.db.profiles.Both.qol
    assert(both.fastLoot == true and both.questRewards[200] == 222)
    assert(w.db.profiles.Default.qol.questRewards[100] == 111, "your own picks are not touched")
end)

Case("saved quest items are checked whole: IDs, types and size", function()
    local w = World()
    local function Picks(picks)
        return assert(w.ns.DecodeProfile(OldString({ questRewards = picks }))).parts.questRewards
    end
    assert(Picks({ [100] = 111 })[100] == 111)
    assert(Picks({ [100] = "111" }) == nil and Picks({ [100] = 0 }) == nil and Picks({ [100] = -5 }) == nil)
    assert(Picks({ [0] = 111 }) == nil and Picks({ [1.5] = 111 }) == nil and Picks({ bad = 111 }) == nil)
    assert(Picks({ [100] = 111.5 }) == nil and Picks({ [100] = 2 ^ 31 }) == nil and Picks({ [100] = {} }) == nil)
    assert(Picks({ [100] = 111, [200] = "x" }) == nil, "one bad pick leaves the whole part out")
    assert(Picks("picks") == nil and Picks({}) == nil)
    local big = {}
    for i = 1, 2000 do big[i] = 1000 + i end
    assert(Picks(big)[2000] == 3000)
    big[2001] = 5
    assert(Picks(big) == nil, "more than the cap is left out")
    w.ns.ImportProfile({ name = "X", parts = { questRewards = { [100] = "x" } } }, ALL, "Raw")
    local qol = w.db.profiles.Raw.qol
    assert(qol == nil or qol.questRewards == nil, "import checks again")
end)

Case("saved quest items keep each class's picks", function()
    local w = World()
    local function Picks(picks)
        return assert(w.ns.DecodeProfile(OldString({ questRewards = picks }))).parts.questRewards
    end
    local picks = Picks({ DRUID = { [100] = 111 }, PALADIN = { [100] = 222, [200] = 333 }, [300] = 444 })
    assert(picks.DRUID[100] == 111 and picks.PALADIN[200] == 333 and picks[300] == 444)
    assert(Picks({ druid = { [100] = 111 } }) == nil and Picks({ DRUID = { [100] = "x" } }) == nil)
    assert(Picks({ DRUID = { bad = 111 } }) == nil and Picks({ DRUID = 5 }) == nil)
    assert(Picks({ DRUID = {} }) == nil, "an empty class is no part")
    assert(Picks({ DRUID = { [100] = -111 } }).DRUID[100] == -111, "a pick not confirmed is a negative ID")
    assert(Picks({ [100] = -111 }) == nil and Picks({ DRUID = { [100] = -1.5 } }) == nil)
    local big = { DRUID = {}, PALADIN = {} }
    for i = 1, 1000 do big.DRUID[i], big.PALADIN[i] = 1000 + i, 2000 + i end
    assert(Picks(big).PALADIN[1000] == 3000)
    big.PALADIN[1001] = 5
    assert(Picks(big) == nil, "the cap counts every class")

    w.db.profiles.Default.qol.questRewards = { DRUID = { [100] = 111, [300] = -333 }, PALADIN = {}, [200] = 222 }
    local parts = assert(w.ns.DecodeProfile(assert(w.ns.ExportProfile({ questRewards = true })))).parts
    assert(parts.questRewards.DRUID[100] == 111 and parts.questRewards.DRUID[300] == -333
        and parts.questRewards[200] == 222 and parts.questRewards.PALADIN == nil)
    local list = w.ns.ProfileStringParts({ parts = parts })
    assert(list[1].key == "questRewards" and list[1].detail == "3 quest rewards")
    w.db.profiles.Default.qol.questRewards = { DRUID = {} }
    local none = assert(w.ns.DecodeProfile(assert(w.ns.ExportProfile({ settings = true, questRewards = true })))).parts
    assert(none.questRewards == nil, "no picks in any class, no part")
    w.ns.ImportProfile({ name = "C", parts = parts }, ALL, "Classes")
    local got = w.db.profiles.Classes.qol.questRewards
    assert(got.DRUID[100] == 111 and got.DRUID[300] == -333 and got[200] == 222,
        "classless picks wait for the first class to log in, and one not confirmed stays so")
end)

Case("a string from before Saved Quest Items had a part still brings its picks", function()
    local w = World()
    local parts = assert(w.ns.DecodeProfile(OldString({ settings = { qol = { fastLoot = true,
        questRewards = { [7] = 70, [8] = 80 } } } }))).parts
    assert(parts.questRewards[7] == 70 and parts.settings.qol.questRewards == nil and parts.settings.qol.fastLoot == true)
    w.ns.ImportProfile({ name = "Old", parts = parts }, ALL, "Old Picks")
    assert(w.db.profiles["Old Picks"].qol.questRewards[8] == 80)
    parts = assert(w.ns.DecodeProfile(OldString({ settings = { qol = { questRewards = { [7] = "x" } } } }))).parts
    assert(parts.questRewards == nil and parts.settings.qol.questRewards == nil)
    parts = assert(w.ns.DecodeProfile(OldString({ questRewards = { [1] = 2 }, settings = { qol = {
        questRewards = { [7] = 70 } } } }))).parts
    assert(parts.questRewards[1] == 2 and parts.questRewards[7] == nil, "the part wins over the old place")
end)

Case("old pack strings say packs are gone; damaged or newer ones are refused", function()
    local w = World()
    local _, err = w.ns.DecodeProfile("NSRPACK2:abcdef")
    assert(err == "Reminder Packs are no longer supported.", tostring(err))
    _, err = w.ns.DecodeProfile("NFPROFILE1:%%%not-a-string")
    assert(err and err:find("damaged", 1, true), tostring(err))
    _, err = w.ns.DecodeProfile("hello")
    assert(err and err:find("not a Naowh Forever", 1, true), tostring(err))
    local LS, LD = LibStub("LibSerialize"), LibStub("LibDeflate")
    local newer = "NFPROFILE1:" .. LD:EncodeForPrint(LD:CompressDeflate(LS:Serialize({ format = 2, parts = {} })))
    _, err = w.ns.DecodeProfile(newer)
    assert(err and err:find("newer", 1, true), tostring(err))
    assert(w.ns.DecodeProfile("") == nil)
end)

local function Live(text)
    return (text:gsub("||", "")):find("|", 1, true) ~= nil or text:find("[\r\n]") ~= nil
end

Case("a crafted string's name, author, date and list names show as plain text", function()
    local w = World()
    local LS, LD = LibStub("LibSerialize"), LibStub("LibDeflate")
    local BADGE = "|TInterface\\AddOns\\NaowhForever\\Core\\Badges\\Media\\BadgeNaowhChat.tga:16|t"
    local text = "NFPROFILE1:" .. LD:EncodeForPrint(LD:CompressDeflate(LS:Serialize({
        format = 1, name = BADGE .. " |cffe6cc80Naowh's Official|r\nVerified by the team",
        author = "%s%d%n |Hplayer:Naowh|h[Naowh]|h", made = ("|cffff0000x|r"):rep(400),
        parts = { bisLists = { PALADIN = { { name = BADGE .. "|n Best", slots = { [1] = 100 } } } } } })))
    local payload = assert(w.ns.DecodeProfile(text))
    assert(not Live(payload.name) and not Live(payload.author) and not Live(payload.made), payload.name)
    assert(payload.name:find("TInterface", 1, true) and payload.author:find("%s%d%n", 1, true))
    assert(#payload.made <= 200, "a long field is cut")
    assert(("%s, shared by %s on %s."):format(payload.name, payload.author, payload.made), "format takes them as arguments")
    w.ns.ImportProfile(payload, { bisLists = true })
    local lists = w.db.account.bisLists.PALADIN.lists
    assert(not Live(lists[#lists].name), lists[#lists].name)
    local fresh = World()
    local clean = fresh.ns.DecodeProfile((fresh.ns.ExportProfile()))
    assert(clean.name == "Default" and clean.author == "Glyadin", "plain names are left as they are")
end)

-- The dialogs on stub frames: every method a no-op unless kept here.
Case("the dialogs: export shows the string, import ticks parts and lands what is ticked", function()
    local w = World()
    local NOTHING = function() end
    local function Frame()
        local f = { scripts = {} }
        return setmetatable(f, { __index = function(_, k)
            if k == "SetScript" then return function(self, s, fn) self.scripts[s] = fn end end
            if k == "SetText" then return function(self, t) self.text = t end end
            if k == "GetText" then return function(self) return self.text or "" end end
            if k == "GetParent" then return function() return Frame() end end
            if k == "GetWidth" then return function() return 500 end end
            if k == "GetStringHeight" then return function() return 14 end end
            if k == "Show" then return function(self) self.shown = true end end
            if k == "Hide" then return function(self) self.shown = false end end
            if k == "SetShown" then return function(self, on) self.shown = on end end
            return NOTHING
        end })
    end
    local ns, opened, reload = w.ns, nil, nil
    local buttons, boxes, toggles = {}, {}, {}
    ns.THEME = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })
    ns.MakeModal = function() return Frame(), Frame() end
    ns.UI.SlimScroll = function() return Frame() end
    ns.Solid = function() return Frame() end
    ns.Border = NOTHING
    ns.Font = function() return Frame() end
    ns.NewEditBox = function() return Frame() end
    ns.Button = function(_, text, _, _, fn)
        local b = Frame()
        b.label, b.click = text, fn
        buttons[text] = b
        return b
    end
    ns.AccentBorder = function(f) return f end
    ns.SetButtonText = function(b, t) b.label = t end
    ns.ConfirmReload = function(text) reload = text end
    local fonts = {}
    ns.UI.KeepFont = function(_, key)
        local f = Frame()
        fonts[key] = f
        return f
    end
    ns.UI.BuildToggleControl = function(_, _, get, set)
        local t = Frame()
        t._get, t._set, t._refreshValue = get, set, NOTHING
        toggles[#toggles + 1] = t
        return t
    end
    local env = getfenv(ns.ExportProfile)
    env.CreateFrame = function(kind)
        local f = Frame()
        if kind == "EditBox" then boxes[#boxes + 1] = f end
        return f
    end
    env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

    ns.ShowProfileExport({ settings = true, builds = true })
    local parts = ns.DecodeProfile(boxes[1].text).parts
    assert(parts.settings and parts.builds and parts.library == nil, "only the parts the page ticked")
    ns.ShowProfileExport()
    local text = boxes[1].text
    assert(text:sub(1, 11) == "NFPROFILE1:" and assert(ns.DecodeProfile(text)), "the export box holds the string")
    assert(not text:find("%s"), "one unbroken line, so it pastes into a quoted Lua string")

    ns.ShowProfileImport()
    local paste, import = boxes[2], buttons.Import
    assert(import.shown == false, "nothing to import yet")
    paste.text = text
    paste.scripts.OnTextChanged(paste, true)
    assert(import.shown and import.label == "Import" and #toggles == 8, #toggles)
    for _, t in ipairs(toggles) do assert(t._get() == true, "every part ticked to start") end
    toggles[7]._set(false)   -- Look
    paste.scripts.OnTextChanged(paste, true)
    assert(toggles[7]._get() == false, "an untick survives a repaint")
    w.db.account.themePreset = "midnight"
    import.click()
    assert(w.switched == "Default 2" and w.db.profiles["Default 2"].qol.fastLoot == true)
    assert(w.db.account.themePreset == "midnight", "Look left out")
    assert(reload and reload:find("Default 2", 1, true), tostring(reload))

    ns.ShowProfileImport()
    paste.text = "NSRPACK2:abcdef"
    paste.scripts.OnTextChanged(paste, true)
    assert(import.shown == false and import.label == "Import", "nothing to take in")
    assert(fonts.preview.text == "Reminder Packs are no longer supported.", fonts.preview.text)
    assert(opened == nil and #boxes == 2)

    ns.Training.ImportBuild = function(t) opened = t end
    ns.ShowProfileImport()
    paste.text = "  !NFB1!abc\n"
    paste.scripts.OnTextChanged(paste, true)
    assert(import.label == "Add Build" and import.shown)
    import.click()
    assert(opened == "  !NFB1!abc\n", "a build goes to the Training Planner's import")

    ns.ImportActionBarString = function(t) opened = t end
    ns.ShowProfileImport()
    paste.text = "!NFA1!abc"
    paste.scripts.OnTextChanged(paste, true)
    assert(import.label == "Add Bar Set" and import.shown)
    import.click()
    assert(opened == "!NFA1!abc", "a bar layout goes to the Action Bars import")
    ns.ImportActionBarString = nil

    w.active = "Default"
    w.db.profiles.Default.qol.sellJunk = true
    ns.ShowProfileImport()
    paste.text = ns.ExportProfile()
    paste.scripts.OnTextChanged(paste, true)
    assert(#toggles == 9 and toggles[8]._get() == true and toggles[9]._get() == false,
        "Keep My Positions starts ticked; Also Import is a row of its own, left unticked")
    assert(fonts.preview.text:find("act for you: Auto Sell Junk;", 1, true), fonts.preview.text)
    import.click()
    assert(w.db.profiles[w.switched].qol.sellJunk == nil, "left unticked, Auto Sell Junk stays off")
    w.active = "Default"
    ns.ShowProfileImport()
    paste.text = ns.ExportProfile()
    paste.scripts.OnTextChanged(paste, true)
    toggles[9]._set(true)
    import.click()
    assert(w.db.profiles[w.switched].qol.sellJunk == true, "ticked, it comes along")
end)

Case("settings that act for you are named, and stay off unless asked for", function()
    local w = World()
    local qol = w.db.profiles.Default.qol
    qol.lootConfirm, qol.sellJunk, qol.questAccept = true, true, false
    local payload = assert(w.ns.DecodeProfile((w.ns.ExportProfile())))
    local acting = w.ns.ProfileActing(payload)
    assert(#acting == 2 and acting[1] == "Auto Sell Junk" and acting[2] == "Skip Loot Confirmations", acting[1])
    w.ns.ImportProfile(payload, ALL)
    local landed = w.db.profiles[w.switched].qol
    assert(landed.lootConfirm == nil and landed.sellJunk == nil, "left out")
    assert(landed.fastLoot == true and landed.questAccept == false, "every other setting comes along")
    local all = { acting = true }
    for k, v in pairs(ALL) do all[k] = v end
    w.active = "Default"
    w.ns.ImportProfile(payload, all)
    landed = w.db.profiles[w.switched].qol
    assert(landed.lootConfirm == true and landed.sellJunk == true, "taken when asked for")
    assert(#w.ns.ProfileActing(assert(World().ns.DecodeProfile((World().ns.ExportProfile())))) == 0,
        "a profile that acts for nobody names nothing")
end)

-- The Profiles page on stub frames and a small stand-in for the row engine.
Case("the page: the profile in use, the others with Use, a switch per part, a paste box with Import", function()
    local w = World()
    w.db.account.trainingBuilds = nil
    w.db.profiles.Raid = { tankReminder = {} }
    local NOTHING = function() end
    local function Frame()
        return setmetatable({ scripts = {} }, { __index = function(_, k)
            if k == "SetScript" then return function(self, s, fn) self.scripts[s] = fn end end
            if k == "SetText" then return function(self, t) self.text = t end end
            if k == "GetText" then return function(self) return self.text or "" end end
            if k == "SetShown" then return function(self, on) self.shown = on end end
            if k == "SetAlpha" then return function(self, a) self.alpha = a end end
            if k == "SetTextColor" then return function(self, _, _, _, a) self.a = a end end
            if k == "EnableMouse" then return function(self, on) self.mouse = on end end
            if k == "GetWidth" or k == "GetStringWidth" then return function() return 700 end end
            if k == "GetParent" then return function(self) return self.parent end end
            if k == "CreateTexture" then return function() return Frame() end end
            if k:match("^[%l_]") then return nil end
            return NOTHING
        end })
    end
    local ns, exported, imported, links, buttons = w.ns, nil, nil, {}, {}
    ns.THEME = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })
    ns.Solid, ns.Border, ns.Font = Frame, Frame, Frame
    ns.Hairline, ns.Print, ns.Tooltip = NOTHING, NOTHING, NOTHING
    ns.UIFontPath = function() return "font" end
    ns.AccentBorder = function(f) return f end
    ns.SetButtonText = function(b, t) b.label.text = t end
    ns.Button = function(parent, text, _, _, fn)
        local b = Frame()
        b.parent, b.label, b.click = parent, Frame(), fn
        b.label.text = text
        buttons[text] = buttons[text] or {}
        table.insert(buttons[text], b)
        return b
    end
    ns.ListProfiles = function() return { "Default", "Raid" } end
    ns.KnownCharacters = function()
        return { { char = "Alt-Realm", profile = "Raid" }, { char = "Glyadin-Realm", profile = "Default" },
            { char = "Bo-Realm", profile = "Default" }, { char = "Cy-Realm", profile = "Default" },
            { char = "Di-Realm", profile = "Default" }, { char = "Ed-Realm", profile = "Default" } }
    end
    ns.UI.CONTENT_PAD = 20
    ns.UI.RefreshPage = NOTHING
    ns.UI.SlimScroll = function() return Frame() end
    ns.UI.BuildToggleControl = function(parent, _, get, set)
        local t = Frame()
        t.parent, t._get, t._set = parent, get, set
        t._refreshValue = function() t.on = get() end
        return t
    end
    local Engine = {}
    function Engine:Clear() self.cursor, self.left, self.width, self.drawn = 0, 0, 700, {} end
    function Engine:Space(h) self.cursor = self.cursor + h end
    Engine.Fit = NOTHING
    function Engine:GetHeight() return self.cursor end
    function Engine:GetWidth() return 700 end
    function Engine:GetFrameLevel() return 1 end
    function Engine:Acquire(kind)
        local list = self.drawn[kind] or {}
        self.drawn[kind] = list
        local pool = self.pools[kind] or {}
        self.pools[kind] = pool
        local row = pool[#list + 1] or self.kinds[kind].New(self)
        row.parent, row.top, row.left, row.width = self, self.cursor, self.left, self.width
        pool[#list + 1], list[#list + 1] = row, row
        return row
    end
    function Engine:Add(kind, ...)
        local row = self:Acquire(kind)
        self.cursor = self.cursor + self.kinds[kind].Set(row, ...)
        return row
    end
    local card = { New = function()
        local c = Frame()
        c.SetHeight = function(self, h) self.height = h end
        return c
    end }
    ns.Shared = {
        Style = { CARD_FILL = 0.025, CARD_GAP = 10, BORDER_RGB = { r = 0, g = 0, b = 0 },
            RED_RGB = { r = 1, g = 0.4, b = 0.4 }, WARN_RGB = { r = 1, g = 0.5, b = 0 } },
        Parts = { SetLink = NOTHING, LinkColor = NOTHING, Tip = function() return true end,
            RowBands = function(row) row.stripe, row.hover = Frame(), Frame() end,
            Link = function(parent, fn)
                local l = Frame()
                l.parent, l.click = parent, fn
                links[#links + 1] = l
                return l
            end },
        View = { NewKinds = function() return { card = card } end,
            New = function(_, kinds, mixin)
                local view = setmetatable({ kinds = kinds, pools = {} }, { __index = function(_, k)
                    return mixin[k] or Engine[k] or NOTHING
                end })
                return view
            end },
    }
    local env = getfenv(ns.ExportProfile)
    env.CreateFrame = function(_, _, parent)
        local f = Frame()
        f.parent = parent
        return f
    end
    env.GetRealmName = function() return "Realm" end
    env.ns = ns
    function ns.ShowProfileExport(ticks) exported = ticks end
    function ns.ShowProfileImport(text) imported = text end

    local parent = Frame()
    parent.profilesView = false
    assert(ns.BuildProfileSettings(parent, -10) < -10)
    local view = parent.profilesView
    local heads, cards = view.drawn.head, view.drawn.card
    assert(#cards == 3 and #heads == 3, "three cards, each with a head")
    assert(heads[1].name.text == "Profiles" and heads[1].summary.text == "2 profiles on this account")
    assert(heads[1].button.shown == true and heads[1].button.label.text == "New Profile")
    for _, c in ipairs(cards) do assert(c.height and c.height > 44, "each card as tall as what it holds") end
    assert(cards[2].top > cards[1].top + cards[1].height, "the cards do not overlap")

    local mine = view.drawn.active[1]
    assert(mine.profile == "Default" and mine.name.text == "Default")
    assert(mine.line.text == "In use on this character and on Bo, Cy and 2 more", mine.line.text)
    assert(mine.who.names and #mine.who.names == 4, "the whole list on hover")
    assert(mine.delete.alone == false and mine.delete.alpha == 1)
    assert(#view.drawn.profile == 1, "the profile in use is listed once")
    local raid = view.drawn.profile[1]
    assert(raid.profile == "Raid" and raid.line.text == "In use on Alt", raid.line.text)
    assert(raid.who.names == nil, "nothing more to show")
    raid.use.click()
    assert(w.switched == "Raid", tostring(w.switched))
    w.active = "Default"

    local tiles = view.drawn.part
    assert(#tiles == 7 and tiles[1].key == "settings" and tiles[1].switch.on == true)
    assert(tiles[1].detail.text == "2 modules", tostring(tiles[1].detail.text))
    assert(tiles[6].key == "questRewards" and tiles[6].name.text == "Saved Quest Items" and tiles[6].ready == true)
    assert(tiles[6].detail.text == "2 quest rewards", tiles[6].detail.text)
    assert(tiles[5].key == "actionBars" and tiles[5].detail.text == "1 bar sets", tiles[5].detail.text)
    assert(tiles[3].key == "builds" and tiles[3].ready == false and tiles[3].detail.text == "Nothing saved yet")
    assert(tiles[3].switch.on == false and tiles[3].switch.mouse == false and tiles[3].name.a < 1)
    assert(tiles[1].tip:find("frames sit", 1, true))
    assert(tiles[1].left == 16 and tiles[2].left > tiles[1].left and tiles[2].top == tiles[1].top, "two columns")
    assert(tiles[3].top > tiles[1].top and tiles[1].width == tiles[2].width, "rows of the same size")
    local send = view.drawn.send[1]
    assert(send.count.text == "6 of 6 parts of Default go in the string.", send.count.text)
    assert(heads[2].name.text == "Share" and heads[2].link.shown == true)

    tiles[6].scripts.OnClick(tiles[6])   -- Saved Quest Items
    send = view.drawn.send[1]
    assert(send.count.text == "5 of 6 parts of Default go in the string.", send.count.text)
    assert(view.drawn.part[6].switch.on == false)
    tiles[6].switch._set(true)
    assert(view.drawn.send[1].count.text == "6 of 6 parts of Default go in the string.")
    tiles[6].switch._set(false)
    tiles[3].scripts.OnClick(tiles[3])   -- builds: nothing to share, so nothing happens
    assert(view.drawn.send[1].count.text == "5 of 6 parts of Default go in the string.")
    buttons["Export"][1].click()
    assert(exported.questRewards == nil and exported.settings == true and exported.look == true)

    local pick = view.drawn.head[2].link
    pick.click(pick)
    assert(view.drawn.send[1].count.text == "6 of 6 parts of Default go in the string.")
    pick.click(pick)
    assert(view.drawn.send[1].count.text == "Pick a part to share.")
    assert(view.drawn.send[1].send.mouse == false, "nothing to share, the button rests")

    local box = view.drawn.paste[1].box
    assert(heads[3].name.text == "Import" and box.go.mouse == false and box.hint.shown == true)
    box.text = "NFPROFILE1:abc"
    box.scripts.OnTextChanged(box, true)
    assert(imported == nil, "typing or pasting opens nothing")
    assert(box.go.mouse == true and box.hint.shown == false)
    box.go.click()
    assert(imported == "NFPROFILE1:abc" and box.text == "" and box.go.mouse == false, "Import takes it on")

    w.db.profiles.Default.tankReminder.importedPack = { name = "Naowh's Pack" }
    ns.BuildProfileSettings(parent, -10)
    tiles = view.drawn.part
    assert(#tiles == 7 and tiles[6].key == "questRewards" and tiles[6].switch.mouse == true,
        "a profile from a pack shares like any other")

    ---@diagnostic disable-next-line: duplicate-set-field
    ns.ListProfiles = function() return { "Default" } end
    ns.BuildProfileSettings(parent, -10)
    mine = view.drawn.active[1]
    assert(mine.delete.alone == true and mine.delete.alpha < 1, "the last profile stays")
    assert(view.drawn.profile == nil and view.drawn.group == nil, "no other profiles, no list")
    local deleted
    ns.Confirm = function() deleted = true end
    mine.delete.click()
    assert(not deleted, "Delete on the last profile asks nothing")
end)

print(count .. " profile share regressions passed")

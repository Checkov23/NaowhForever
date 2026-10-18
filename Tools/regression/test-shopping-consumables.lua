-- Run with Lua 5.1 from the repository root: the Shopping List's Consumables picker. What it
-- offers suits your class (stats), mana and level (usable now and the next tier up), each kind's
-- best for your level is marked, "Only for my class" off shows everything, items whose data has
-- not loaded wait, and a pick lands on the list as an other item. The picker itself is driven
-- against stub frames: amounts of four digits, the box after Enter, one redraw per frame, a
-- recount (not a re-pick) when the list changes, a re-pick on level up, the saved toggle, favourites
-- kept in the profile and shown first, and the search box.
-- The module's real data, rules, plan and picker files are loaded and run.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local Load = dofile("Tools/regression/load_files.lua")
local function Noop() end

-- Required levels, as the game answers them once each item has loaded.
local LV = {
    [3391] = 20, [13453] = 45, [250349] = 45, [9206] = 48, [250351] = 55, [250350] = 55,  -- strength elixirs
    [8949] = 27, [9187] = 38, [13452] = 46, [250328] = 55,                               -- agility elixirs
    [9179] = 37, [13454] = 47, [250341] = 55, [20007] = 40,                              -- caster and mana
    [13445] = 43, [8951] = 29,                                                           -- armor, for everyone
    [13446] = 45, [3928] = 35, [929] = 15, [118] = 1,                                    -- healing potions
    [13444] = 49, [6149] = 31, [2455] = 5,                                               -- mana potions
    [14530] = 0, [14529] = 0, [1251] = 0,                                                -- bandages
    [12404] = 35, [18262] = 50, [20750] = 40, [20748] = 45,                              -- stones, oils
    [3012] = 10, [1477] = 25, [4425] = 40,                                               -- agility scrolls
    [13512] = 50,                                                                        -- the one spell flask
}

-- A frame that answers what the picker asks of it and records what it was told.
local widgetMeta = { __index = function() return Noop end }
local frames, registry = {}, {}
local function Widget(parent)
    local w = setmetatable({ shown = true, parent = parent }, widgetMeta)
    frames[#frames + 1] = w
    return w
end
local methods = {}
function methods.Show(self)
    if self.shown then return end
    self.shown = true
    for _, fn in ipairs(self.hooks and self.hooks.OnShow or {}) do fn(self) end
end
function methods.Hide(self)
    if not self.shown then return end
    self.shown = false
    for _, fn in ipairs(self.hooks and self.hooks.OnHide or {}) do fn(self) end
end
function methods.SetShown(self, on) if on then self:Show() else self:Hide() end end
function methods.IsShown(self) return self.shown end
function methods.GetParent(self) return self.parent end
function methods.SetText(self, v)
    v = tostring(v)
    local most = rawget(self, "maxLetters")
    if most and #v > most then v = v:sub(1, most) end
    self.text = v
end
function methods.GetText(self) return self.text or "" end
function methods.SetMaxLetters(self, n) self.maxLetters = n end
function methods.SetFocus(self) self.focused = true end
function methods.ClearFocus(self) self.focused = false end
function methods.HasFocus(self) return self.focused == true end
function methods.SetChecked(self, v) self.checked = v end
function methods.GetChecked(self) return self.checked end
function methods.SetEnabled(self, on) self.enabled = on end
function methods.SetScript(self, name, fn) self.scripts = self.scripts or {}; self.scripts[name] = fn end
function methods.HookScript(self, name, fn)
    self.hooks = self.hooks or {}
    self.hooks[name] = self.hooks[name] or {}
    table.insert(self.hooks[name], fn)
end
function methods.CreateTexture(self) return Widget(self) end
function methods.RegisterEvent(self, event) registry[event] = self end
function methods.UnregisterAllEvents(self)
    for event, frame in pairs(registry) do if frame == self then registry[event] = nil end end
end
-- Methods are capitalised; any other one is a no-op, and a field not set reads nil.
widgetMeta.__index = function(_, k) return methods[k] or (k:match("^%u") and Noop) or nil end

local function NewEnv(withModules)
    local account, levels, timers, profile = {}, {}, {}, {}
    local function CharacterData(store, create)
        account[store] = account[store] or {}
        local mine = account[store]["Player-Grim"]
        if mine or not create then return mine end
        mine = {}
        account[store]["Player-Grim"] = mine
        return mine, true, false
    end
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Lower = string.lower,
        Professions = { CharacterData = CharacterData,
            Settings = { DB = function() return profile end, Get = function() return false end } },
        THEME = { muted = {} },
        HEALING_POTIONS = { 13446, 3928, 929, 118 },
        MANA_POTIONS = { 13444, 6149, 2455 },
        AccountSettings = function() return account end,
        UsesMana = function() return false end,
        Button = function(parent, text, w, h, onClick)
            local b = Widget(parent); b.label, b.click = text, onClick; return b
        end,
        Font = function(parent) return Widget(parent) end,
        Tooltip = Noop,
        Shared = { Items = {
            Name = function(id) return levels[id] and ("item" .. id) or ("item " .. id) end,
            QualityHex = function() return "|cffffffff" end,
            OnLoaded = Noop,
        }, Parts = {
            SearchBox = function(parent, hint, onSearch)
                local box = Widget(parent); box.hint, box.onSearch = hint, onSearch; return box
            end,
        } },
    }
    if withModules then
        ns.Macros = { Items = { BANDAGES = { 14530, 14529, 8545, 1251 } } }
        ns.BuffReminderData = { WEAPON_ITEMS = { 20750, 20748, 3829, 12404, 18262 } }
    end
    local env = {
        UnitName = function() return "Grim" end,
        GetRealmName = function() return "Realm" end,
        UnitClass = function() return "Warrior", "WARRIOR" end,
        UnitLevel = function() return 45 end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        CreateFrame = function(_, _, parent) return Widget(parent) end,
        C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
        C_Item = {
            GetItemNameByID = function(id) return levels[id] and ("item" .. id) end,
            GetItemInfo = function(id)
                if not levels[id] then return nil end
                return "item" .. id, "link", 1, 1, levels[id]
            end,
            GetItemCount = function() return 2 end,
            GetItemIconByID = function() return 1 end,
            RequestLoadItemDataByID = Noop,
        },
        GameTooltip = Widget(),
        GameTooltip_Hide = Noop,
        NaowhForever = ns,
    }
    env._G = env
    Load({ "NaowhForever_Professions/Constants.lua", "NaowhForever_Professions/Text.lua",
        "NaowhForever_Professions/Data/CooldownRecipes.lua", "NaowhForever_Professions/Data/ConsumableItems.lua",
        "NaowhForever_Professions/ShoppingPlan.lua", "NaowhForever_Professions/Consumables.lua" },
        setmetatable(env, { __index = _G }))
    local P = ns.Professions
    P.Style = { ROW_ICON_SHRINK = 4, ICON_NAME_GAP = 6, FONT = 12, FONT_SMALL = 11,
        GOLD_RGB = { r = 1, g = 1, b = 0 }, RED_RGB = { r = 1, g = 0, b = 0 }, READY_RGB = { r = 0, g = 1, b = 0 },
        PANEL_HEADER = 30, PANEL_INSET = 4, PANEL_PAD = 10, SEARCH_H = 24 }
    P.Widgets = {
        Crop = function(t) return t end,
        EnableButton = function(b, on) b.enabled = on end,
        QtyBox = function(parent) local box = Widget(parent); box.maxLetters = 3; return box end,
        CheckBox = function(parent) return Widget(parent) end,
        StarButton = function(parent) local b = Widget(parent); b.tex = Widget(b); return b end,
        Star = function(texture, on) texture.on = on end,
    }
    ns.Shared.Parts.SidePanel = function(_, newView)
        local panel = Widget()
        panel.close, panel.title, panel.scroll = Widget(panel), Widget(panel), Widget(panel)
        panel.view = newView(panel.scroll)
        return panel
    end
    ns.Shared.Parts.ShowBeside = function(panel) panel:Show() end
    for id, lv in pairs(LV) do levels[id] = lv end
    return env, ns, levels, timers, account, profile
end

local _, ns, levels = NewEnv(true)
local P = ns.Professions
local D, C, SL = P.ConsumableItems, P.Consumables, P.Shopping

local function Picked(level, class, mine, mana)
    local by, best, later, order = {}, {}, {}, {}
    for _, group in ipairs(C.Pick(level, class, mine, mana)) do
        order[#order + 1] = group.key
        for _, row in ipairs(group.rows) do
            by[row.id] = group.key
            best[row.id] = row.best
            later[row.id] = row.later
        end
    end
    return by, best, later, order
end

-- The data: every ID once, every stat one a class can want or mana, every class has its stats.
local seen, stats = {}, { mana = true }
for _, s in pairs(D.CLASS_STATS) do for k in pairs(s) do stats[k] = true end end
for _, group in ipairs(D.GROUPS) do
    for _, e in ipairs(D.ITEMS[group] or {}) do
        check("item listed once: " .. e[1], not seen[e[1]])
        seen[e[1]] = true
        for i = 2, #e do check("known stat on " .. e[1] .. ": " .. e[i], stats[e[i]]) end
    end
end
for _, s in pairs(D.WEAPON_STATS) do check("known weapon stat " .. s, stats[s]) end
for _, class in ipairs({ "WARRIOR", "ROGUE", "HUNTER", "MAGE", "WARLOCK", "PRIEST", "PALADIN", "SHAMAN", "DRUID" }) do
    check("stats for " .. class, D.CLASS_STATS[class] ~= nil)
end
check("weapons and bandages are not item groups of the data", D.ITEMS.weapon == nil and D.ITEMS.bandage == nil)

-- The fallback copies match the lists their modules own.
local owners = { NaowhForever = { Macros = {} } }
owners._G = owners
Load({ "NaowhForever_Combat/AuraBuffs/Data/BuffReminders.lua", "NaowhForever_Utilities/Macros/Data/Items.lua" },
    setmetatable(owners, { __index = _G }))
local function Same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end
check("weapon copy in step with the Buff Reminders", Same(D.WEAPON_ITEMS, owners.NaowhForever.BuffReminderData.WEAPON_ITEMS))
check("bandage copy in step with the Smart Macros", Same(D.BANDAGES, owners.NaowhForever.Macros.Items.BANDAGES))

-- A level 45 warrior: strength and agility up to 45 and the next tier, nothing for casters or mana.
local by, best, later = Picked(45, "WARRIOR", true, false)
check("warrior: strength elixirs usable now", by[3391] == "elixir" and by[13453] and by[250349])
check("warrior: the next strength tier (48) shows", by[9206] and later[9206])
check("warrior: two tiers up (55) does not", not by[250351] and not by[250350])
check("warrior: the best strength elixirs are the level 45 ones", best[13453] and best[250349] and not best[3391])
check("warrior: agility's next tier (46) shows, marked later", by[13452] and later[13452])
check("warrior: no intellect or spell power", not by[9179] and not by[13454])
check("warrior: no mana potions or mana elixirs", not by[13444] and not by[6149] and not by[20007])
check("warrior: armor elixirs and healing potions", by[13445] and by[8951] and by[13446] and by[118])
check("warrior: the best healing potion is the level 45 one", best[13446] and not best[929])
check("warrior: stones from the Buff Reminders' list, no wizard or mana oil",
    by[12404] == "weapon" and by[18262] and not by[20750] and not by[20748])
check("warrior: bandages from the Smart Macros' list, none marked best (no levels)",
    by[14530] == "bandage" and by[1251] and not best[14530])

-- The lowest tier is Best while it is the highest you can use (a level 15 warrior).
by, best = Picked(15, "WARRIOR", true, false)
check("level 15: Scroll of Agility (10) is Best", by[3012] and best[3012])
check("level 15: Scroll of Agility II (25) is the next tier, not Best", by[1477] and not best[1477])
check("level 15: Minor Healing Potion (1) is not Best beside the level 15 one", by[118] and not best[118] and best[929])
-- A line of one item (the only spell power flask) has nothing to compare: no Best.
by, best = Picked(50, "MAGE", true, true)
check("a line of one item: shown, not Best", by[13512] == "flask" and not best[13512])

-- An item with two stats counts in the line of each stat you use, not only its first.
by, _, later = Picked(45, "ROGUE", true, false)
check("rogue 45: agility's next tier is 46", by[13452] and later[13452])
check("rogue 45: the level 55 strength-and-agility elixir is two tiers up", not by[250350])
check("rogue 45: the level 55 agility-and-intellect elixir too", not by[250328])
by = Picked(50, "ROGUE", true, false)
check("rogue 50: both are the next agility tier now", by[250350] and by[250328])
check("rogue 50: strength alone still not offered", not by[250351])
by, _, later = Picked(45, "MAGE", true, true)
check("mage 45: agility-and-intellect elixir is intellect's next tier", by[250328] and later[250328])
check("mage 45: no strength-and-agility elixir", not by[250350])

-- A level 45 mage: intellect, spell power and mana; no strength.
by, best = Picked(45, "MAGE", true, true)
check("mage: intellect and spell power", by[9179] and by[13454])
check("mage: mana potions and the next tier", by[6149] and by[13444] and best[6149] and not best[2455])
check("mage: mageblood", by[20007])
check("mage: no strength or agility, no stones", not by[3391] and not by[8949] and not by[12404])
check("mage: wizard oil and mana oil", by[20750] and by[20748])
check("mage: everyone's items too", by[13445] and by[13446])

-- A class the table does not know sees what suits everyone.
by = Picked(45, "MONK", true, false)
check("unknown class: armor and healing potions only", by[13445] and by[13446] and not by[3391] and not by[9179])

-- Only for my class off: everything, every level, the best still marked.
local order
by, _, later, order = Picked(45, "WARRIOR", false, false)
check("everything: caster and mana items too", by[9179] and by[13444] and by[20750])
check("everything: every tier up", by[250351] and later[250351])
local last = 0
for _, key in ipairs(order) do
    local at
    for i, g in ipairs(D.GROUPS) do if g == key then at = i end end
    check("group order kept: " .. key, at > last)
    last = at
end

-- Rows run from the highest level down.
for _, group in ipairs(C.Pick(60, "WARRIOR", false, false)) do
    for i = 2, #group.rows do
        check("highest level first in " .. group.key, group.rows[i - 1].level >= group.rows[i].level)
    end
end

-- An item whose data has not loaded is left out until it has.
by = Picked(45, "WARRIOR", true, false)
check("unloaded item waits", not by[2454])
levels[2454] = 1
by = Picked(45, "WARRIOR", true, false)
check("loaded later, it shows", by[2454])

-- Every ID the picker can show is asked for, once.
local ids, once = C.IDs(), {}
for _, id in ipairs(ids) do
    check("ID asked for once: " .. id, not once[id])
    once[id] = true
end
check("potions, weapons and bandages asked for", once[13446] and once[2455] and once[12404] and once[14530])

-- With the Smart Macros and Buff Reminders off, their groups come from the copy in the data.
local _, nsOff = NewEnv(false)
local off = {}
for _, group in ipairs(nsOff.Professions.Consumables.Pick(45, "WARRIOR", false, false)) do off[group.key] = true end
check("modules off: weapon and bandage groups still show, from the copy", off.weapon and off.bandage and off.elixir)
local offIDs = {}
for _, id in ipairs(nsOff.Professions.Consumables.IDs()) do offIDs[id] = true end
check("modules off: the copy's stones and bandages", offIDs[7964] and offIDs[3239] and offIDs[8544] and offIDs[2581])
local onIDs = {}
for _, id in ipairs(C.IDs()) do onIDs[id] = true end
check("modules on: their live lists are read, not the copy",
    onIDs[3829] and onIDs[8545] and not onIDs[7964] and not onIDs[8544])

-- Picks land on the list as other items: added, set, stepped down, taken off at zero, and every
-- change is told to whoever listens.
local told = 0
SL.OnChange(function() told = told + 1 end)
SL.AddItem(13453, 1)
SL.AddItem(13453, 1)
check("plus adds one each", SL.Manual()[13453] == 2)
check("each add is told", told == 2)
SL.SetItem(13453, 5)
check("typed amount sets it", SL.Manual()[13453] == 5)
check("a set is told", told >= 3)
SL.SetItem(13453, 99999)
check("capped at the most an item can be", SL.Manual()[13453] == P.C.MAX_ITEMS)
SL.SetItem(13453, 1)
SL.SetItem(13453, 0)
check("zero takes it off", SL.Manual()[13453] == nil)
SL.SetItem(13446, 3)
local materials = SL.Materials()
check("a pick is bought at the auction house like any other item",
    #materials == 1 and materials[1].item == 13446 and materials[1].qty == 3)
SL.Drop(13446, 3)
check("what was bought counts against it", #SL.Materials() == 0)
local before = told
for k in pairs(SL.Manual()) do SL.Manual()[k] = nil end
SL.Trim()
check("a list emptied after buying is told", told > before)
check("taking it off forgets what was bought for it", SL.Have()[13446] == nil)

-------------------------------------------------------------------------------
--  The picker
-------------------------------------------------------------------------------
local uiEnv, uiNs, _, timers, account, profile = NewEnv(true)
Load({ "NaowhForever_Professions/UI/ShoppingConsumables.lua" }, uiEnv)
local UP = uiNs.Professions
local picks, pickedLevel = 0, nil
local realPick = UP.Consumables.Pick
UP.Consumables.Pick = function(level, ...)
    picks, pickedLevel = picks + 1, level
    return realPick(level, ...)
end
local function RunTimers()
    local due = {}
    for i = #timers, 1, -1 do due[#due + 1] = table.remove(timers, i) end
    for _, fn in ipairs(due) do fn() end
end

local owner = Widget()
UP.Shopping.ToggleConsumables(owner)
check("opening picks once", picks == 1 and pickedLevel == 45)
check("bag changes and level up heard while it shows",
    registry.BAG_UPDATE_DELAYED ~= nil and registry.PLAYER_LEVEL_UP ~= nil)

local function RowOf(id)
    for _, f in ipairs(frames) do
        if f.id == id and f.qty and f.shown then return f end
    end
end
local row = RowOf(13453)
check("a warrior's strength elixir has a row", row ~= nil)
check("the amount box takes four digits", row.qty.maxLetters == 4 and #tostring(UP.C.MAX_ITEMS) == 4)

-- Typing an amount: 1500 is kept whole, and the box shows what is stored.
row.qty:SetFocus()
row.qty:SetText("1500")
row.qty.scripts.OnEnterPressed(row.qty)
check("1500 typed: 1500 on the list", UP.Shopping.Manual()[13453] == 1500)
check("1500 typed: the box shows 1500", row.qty:GetText() == "1500" and not row.qty:HasFocus())
row.qty:SetFocus()
row.qty:SetText("007")
row.qty.scripts.OnEnterPressed(row.qty)
check("007 typed: the box shows 7", UP.Shopping.Manual()[13453] == 7 and row.qty:GetText() == "7")
row.qty:SetFocus()
row.qty:SetText("")
row.qty.scripts.OnEnterPressed(row.qty)
check("emptied: off the list, the box shows 0", UP.Shopping.Manual()[13453] == nil and row.qty:GetText() == "0")

-- List changes recount the rows once a frame; they never pick again.
RunTimers()
picks = 0
UP.Shopping.AddItem(13453, 1)
UP.Shopping.AddItem(13453, 1)
UP.Shopping.SetItem(13446, 4)
check("three changes in a frame: one redraw queued", #timers == 1)
RunTimers()
check("a list change does not pick again", picks == 0)
check("the row shows the new amount", row.qty:GetText() == "2" and row.minus.enabled)
registry.BAG_UPDATE_DELAYED.scripts.OnEvent(registry.BAG_UPDATE_DELAYED, "BAG_UPDATE_DELAYED")
RunTimers()
check("a bag change does not pick again", picks == 0)

-- A level up picks again, at the new level.
registry.PLAYER_LEVEL_UP.scripts.OnEvent(registry.PLAYER_LEVEL_UP, "PLAYER_LEVEL_UP", 46)
RunTimers()
check("level up picks again at the new level", picks == 1 and pickedLevel == 46)
check("level 46: the agility elixir at 46 is no longer later", not RowOf(13452).entry.later)

-- Only for my class is saved, account-wide like the window's other choices.
local box
for _, f in ipairs(frames) do if f.scripts and f.scripts.OnClick and f.checked ~= nil then box = f end end
check("only for my class starts on", box and box.checked == true)
box:SetChecked(false)
box.scripts.OnClick(box)
check("switched off: saved", account.profShopAllConsumables == true)
check("switched off: everything shows", RowOf(9179) ~= nil and RowOf(9179):IsShown())
box:SetChecked(true)
box.scripts.OnClick(box)
check("switched on again: nothing saved", account.profShopAllConsumables == nil)

-- A star makes a pick a favourite: kept in the profile, shown first under Favorites, out of its kind.
local function Rows()
    local list = {}
    for _, f in ipairs(frames) do if f.qty then list[#list + 1] = f end end
    return list
end
local function Shown(id)
    local n = 0
    for _, f in ipairs(Rows()) do if f.id == id and f.shown then n = n + 1 end end
    return n
end
local function ShownText(text)
    for _, f in ipairs(frames) do if f.text == text and f.shown then return f end end
end
check("no favourites at first: no Favorites heading", not ShownText("Favorites") and next(profile.shopFavorites) == nil)
check("no favourites at first: every star off", RowOf(13453).star.tex.on == false)
local potion = RowOf(13446)
check("a healing potion lists after the elixirs", Rows()[1].id ~= 13446)
picks = 0
potion.star.scripts.OnClick(potion.star)
check("starred: kept in the profile by item ID", profile.shopFavorites[13446] == true)
check("starred: Favorites heads the list", ShownText("Favorites") ~= nil)
check("starred: it is the first row, star on", Rows()[1].id == 13446 and Rows()[1].shown and Rows()[1].star.tex.on)
check("starred: shown once, not again in its kind", Shown(13446) == 1)
check("starred: a star picks nothing again", picks == 0)
Rows()[1].star.scripts.OnClick(Rows()[1].star)
check("unstarred: gone from the profile", profile.shopFavorites[13446] == nil)
check("unstarred: back in its kind, no Favorites heading", Rows()[1].id ~= 13446 and Shown(13446) == 1
    and not ShownText("Favorites"))

-- The search box keeps the rows whose name holds what is typed, any case, without picking again.
local search
for _, f in ipairs(frames) do if f.onSearch then search = f end end
check("a search box with its hint", search and search.hint == "Search consumables")
picks = 0
search.onSearch("ITEM1344")
check("search: a matching name shows", Shown(13446) == 1 and Shown(13445) == 1)
check("search: any other name is hidden", Shown(13453) == 0 and Shown(3391) == 0)
check("search: lays out again with no new pick", picks == 0)
search.onSearch("item3391")
check("search: one item left", Shown(3391) == 1 and #Rows() > 1 and Shown(13446) == 0)
search.onSearch("nothing like it")
check("search: no match shows its message", Shown(3391) == 0
    and ShownText("No consumable matches your search.") ~= nil)
search.onSearch("")
check("search cleared: every row back, no message", Shown(13453) == 1 and Shown(13446) == 1
    and not ShownText("No consumable matches your search."))
RowOf(13446).star.scripts.OnClick(RowOf(13446).star)
search.onSearch("item3391")
check("search: a favourite that does not match hides with its heading", Shown(13446) == 0
    and not ShownText("Favorites"))
search.onSearch("item1344")
check("search: a favourite that matches stays first", Rows()[1].id == 13446 and ShownText("Favorites") ~= nil)

-- Closed: nothing listens and a list change queues nothing.
UP.Shopping.ToggleConsumables(owner)
check("closed: no events", registry.BAG_UPDATE_DELAYED == nil and registry.PLAYER_LEVEL_UP == nil)
UP.Shopping.AddItem(13453, 1)
check("closed: a list change queues nothing", #timers == 0)
account.profShopAllConsumables = true
UP.Shopping.ToggleConsumables(owner)
check("reopened: the saved choice is used", RowOf(9179) ~= nil and RowOf(9179):IsShown())
check("reopened: the search is cleared", search:GetText() == "" and Shown(13453) == 1)
check("reopened: the favourite is still first", Rows()[1].id == 13446 and ShownText("Favorites") ~= nil)
UP.Shopping.ToggleConsumables(owner)
search.onSearch("item")
check("closed: typing lays nothing out", #timers == 0 and Rows()[1].id == 13446)

print(("test-shopping-consumables: %d checks passed"):format(checks))

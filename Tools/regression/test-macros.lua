-- Loads the shared food lists, QoL's Food & Drink Bar and the Macros module's rules (Macros.lua through Smart.lua)
-- against stubbed macro, bag and item APIs and checks what they write. Run from the repo root:
-- lua Tools/regression/test-macros.lua
rawset(_G, "C_AddOns", { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end })
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a"); f:close()
    return text
end
local foodSource = Read("NaowhForever_QoL/Loot/FoodBar.lua")
local MACRO_FILES = { "Macros.lua", "Constants.lua", "Data/Items.lua", "Commands.lua", "Smart.lua",
    "UI/SettingsPage.lua" }
local sources = { Read("Core/Features.lua"), Read("Shared/Game/Consumables.lua"), Read("Shared/Game/ActionKeys.lua"),
    Read("Shared/UI/ItemBar.lua"), Read("Shared/UI/Anchor.lua"), foodSource }

-- The Food & Drink Bar's defaults, as Core/Settings.lua declares them.
local FOOD_DEFAULTS = (function()
    local settings = Read("Core/Settings.lua"):gsub("\r\n", "\n")
    local block = settings:match("\n(    foodBar = F%.foodBar.-)\n    consumableBar = ")
    local chunk = assert(loadstring("return {\n" .. block .. "\n}"))
    setfenv(chunk, { F = { foodBar = false } })
    return chunk()
end)()
for _, file in ipairs(MACRO_FILES) do sources[#sources + 1] = Read("NaowhForever_Utilities/Macros/" .. file) end

local FOOD, DRINK = "Food", "Drink"
-- itemID -> { spell, required level }
local ITEMS = {
    [8079] = { DRINK, 45 },   -- Conjured Crystal Water
    [8766] = { DRINK, 45 },   -- Morning Glory Dew
    [1179] = { DRINK, 5 },    -- Ice Cold Milk
    [8932] = { FOOD, 45 },    -- Alterac Swiss
    [5349] = { FOOD, 1 },     -- Conjured Muffin
    [4599] = { FOOD, 35 },    -- Cured Ham Steak
}

local function Fixture(opts)
    local settings = opts.settings or {}
    local qol = opts.qol or {}
    local bags = opts.bags or {}            -- flat list of item IDs, one per slot
    local macros, created, edited, deleted, printed = opts.macros or {}, 0, 0, 0, {}
    local account = {}
    local combat, group = false, opts.group
    local level = opts.level or 60
    local missing = opts.missing or {}
    local levels = opts.levels or {}
    local consts = { MAX_ACCOUNT_MACROS = opts.max or 30 }
    local frames = {}
    local globals = {}
    local bindings, actions, timers = {}, {}, {}
    local function Noop() end
    local frameMeta = { __index = function() return Noop end }
    local function Frame(name)
        local fr = { name = name, events = {}, attrs = {}, shown = true, level = 1 }
        setmetatable(fr, frameMeta)
        function fr:SetScript(k, fn) if k == "OnEvent" then self.handler = fn end end
        function fr:RegisterEvent(event) self.events[event] = true end
        function fr:UnregisterEvent(event) self.events[event] = nil end
        function fr:UnregisterAllEvents() self.events = {} end
        function fr:SetAttribute(k, v) self.attrs[k] = v end
        function fr:Show() self.shown = true end
        function fr:Hide() self.shown = false end
        function fr:SetShown(v) self.shown = v end
        function fr:SetSize(w, h) self.width, self.height = w, h end
        function fr:IsShown() return self.shown end
        function fr:SetTexture(v) self.texture = v end
        function fr:SetDesaturated(v) self.desaturated = v end
        function fr:SetText(v) self.text = v end
        function fr:CreateTexture() return Frame() end
        function fr:GetFrameLevel() return self.level end
        function fr:ClearAllPoints() self.point = nil end
        function fr:SetPoint(...) self.point = { ... } end
        function fr:IsVisible() return self.shown end
        function fr:GetName() return self.name end
        function fr:GetAttribute(k) return self.attrs[k] end
        frames[#frames + 1] = fr
        if name then globals[name] = fr end
        return fr
    end

    local S = {}
    local QOL_DEFAULTS = setmetatable({ enabled = true }, { __index = FOOD_DEFAULTS })
    local cards = {}
    local Q = {}
    function Q.Get(k)
        if qol[k] ~= nil then return qol[k] end
        return QOL_DEFAULTS[k]
    end
    function Q.Set(k, v) qol[k] = v end
    function Q.DB() return qol end
    function Q.OnChange() end
    local mover
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        -- The Consumable Bar module, loaded before QoL (its OptionalDeps) when it is on.
        ConsumableBar = opts.consumableBarLoaded and {} or nil,
        QoLSettings = Q,
        Shared = {
            Style = dofile("Tools/regression/shared_style.lua"),
            Parts = { Press = function(button) button.pressed = true end },
            -- The settings kit, keeping the cards each page declares.
            Settings = {
                Group = function(title) return { group = title } end,
                Page = function(key)
                    return {
                        Card = function(_, spec) cards[key .. ":" .. spec.id] = spec; return spec end,
                        Window = function(_, spec) return spec end,
                    }
                end,
            },
        },
        THEME = { fg = { r = 1, g = 1, b = 1 }, accent = { r = 0, g = 0.6, b = 1 }, muted = { r = 0.5, g = 0.5, b = 0.5 } },
        SettingsRoot = function() return { macros = settings, qol = qol } end,
        Print = function(msg) printed[#printed + 1] = msg end,
        AccountSettings = function() return account end,
        Apply = function() end,
        ShowUnlockMode = function() end,
        HideUnlockMode = function() end,
        Font = function() return Frame() end,
        Border = function() end,
        PixelInset = function() end,
        UI = {
            FontPath = function(name) return name ~= "" and name or "font.ttf" end,
            AttachMover = function(_, label, onMoved, page, feature)
                mover = { label = label, page = page, feature = feature, onMoved = onMoved }
                return Frame()
            end,
            STATUS = setmetatable({}, { __index = function() return "" end }),
            ModuleSettings = function(_, given)
                -- Written against every macro starting off, the original defaults.
                local defaults = setmetatable({ health = false, healthOrder = "stone", mana = false, food = false,
                    bandage = false, trinket1 = false, trinket2 = false, focus = false, focusMark = false,
                    focusAnnounce = false, acceptPopup = false }, { __index = given })
                function S.Get(k)
                    if settings[k] ~= nil then return settings[k] end
                    return defaults[k]
                end
                function S.Set(k, v) settings[k] = v end
                function S.DB() return settings end
                return S
            end,
        },
    }
    local function Count(id)
        local n = 0
        for _, b in ipairs(bags) do if b == id then n = n + 1 end end
        return n
    end
    local function Find(name)
        for i, m in ipairs(macros) do if m.name == name then return i end end
        return 0
    end
    local env = {
        NUM_BAG_SLOTS = 0,
        Constants = { MacroConsts = consts },
        IsInRaid = function() return group == "raid" end,
        IsInGroup = function() return group ~= nil end,
        UnitClass = function() return "Class", opts.class or "MAGE" end,
        UnitLevel = function() return level end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        C_Container = {
            GetContainerNumSlots = function() return #bags end,
            GetContainerItemID = function(_, slot) return bags[slot] end,
        },
        C_Item = {
            GetItemCount = Count,
            GetItemIconByID = function(id) return "icon" .. id end,
            GetItemSpell = function(id) return ITEMS[id] and ITEMS[id][1] end,
            GetItemInfo = function(id)
                if missing[id] then return end
                return "item", nil, nil, nil, levels[id] or (ITEMS[id] and ITEMS[id][2]) or 0
            end,
        },
        C_Spell = { GetSpellName = function(id) return id == 433 and FOOD or DRINK end },
        PickupMacro = function(index) assert(index > 0) end,
        GetMacroIndexByName = function(name) return opts.lookupMisses and 0 or Find(name) end,
        GetMacroBody = function(i) return macros[i].body end,
        GetNumMacros = function()
            local numAccount, numCharacter = 0, 0
            for _, m in ipairs(macros) do
                if m.perChar then numCharacter = numCharacter + 1 else numAccount = numAccount + 1 end
            end
            return numAccount, numCharacter
        end,
        CreateMacro = function(name, icon, body, perChar)
            assert(type(perChar) == "boolean")
            assert(#name <= 16, "macro name too long: " .. name)
            assert(#body <= 255, "macro body too long")
            created = created + 1
            macros[#macros + 1] = { name = name, body = body, icon = icon, perChar = perChar }
        end,
        EditMacro = function(i, _, icon, body)
            edited = edited + 1
            if icon then macros[i].icon = icon end
            if body then macros[i].body = body end
        end,
        DeleteMacro = function(i) deleted = deleted + 1; table.remove(macros, i) end,
        InCombatLockdown = function() return combat end,
        C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
        GetBindingKey = function(command) return bindings[command] end,
        GetBindingText = function(key) return "*" .. key end,
        GetActionInfo = function(slot) local a = actions[slot]; if a then return a[1], a[2] end end,
        ActionBarButtonEventsFrame = { frames = {} },
        RANGE_INDICATOR = "RANGE",
        CreateFrame = function(_, name) return Frame(name) end,
        hooksecurefunc = function(tbl, key, fn)
            local orig = tbl[key]
            tbl[key] = function(...) orig(...); fn(...) end
        end,
    }
    env.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
    env._G = { NaowhForever = ns, SLASH_SAY1 = "/say", SLASH_CAST1 = "/cast", SLASH_SCRIPT1 = "/run",
        SLASH_TARGET_MARKER1 = "/tm", EMOTE1_CMD1 = "/wave" }
    setmetatable(env._G, { __index = globals })
    setmetatable(env, { __index = function(_, k) if globals[k] ~= nil then return globals[k] end return _G[k] end })
    local foodFirst
    for _, text in ipairs(sources) do
        if text == foodSource then foodFirst = #frames + 1 end
        local chunk
        if setfenv then
            chunk = assert(loadstring(text)); setfenv(chunk, env)
        else
            chunk = assert(load(text, "Macros", "t", env))
        end
        chunk()
    end

    local t = { ns = ns, cards = cards, bindings = bindings, actions = actions, frame = Frame }
    -- The Food & Drink Bar's own event frame: the first frame its file makes.
    function t.FoodEvents() return frames[foodFirst] end
    -- Timers run when the test lets a frame pass.
    function t.Tick()
        local due = {}
        for i, fn in ipairs(timers) do due[i] = fn end
        for i = #timers, 1, -1 do timers[i] = nil end
        for _, fn in ipairs(due) do fn() end
    end
    -- An action button on the game's own bars: its slot, and the key text it shows.
    function t.ActionButton(slot, hotkey)
        local btn = Frame()
        btn.action = slot
        btn.HotKey = Frame()
        btn.HotKey.text = hotkey
        function btn.HotKey:GetText() return self.text end
        local list = env.ActionBarButtonEventsFrame.frames
        list[#list + 1] = btn
        return btn
    end
    function t.Fire(event, ...)
        for _, fr in ipairs(frames) do
            if fr.events[event] then fr.handler(fr, event, ...) end
        end
    end
    function t.FoodBar()
        for _, fr in ipairs(frames) do
            if fr.name == "NaowhForeverFoodBar" then return fr end
        end
    end
    function t.Set(k, v) S.Set(k, v) end
    function t.SetQoL(k, v) Q.Set(k, v) end
    function t.Mover() return mover end
    t.settings, t.qol = settings, qol
    function t.Listening(event)
        for _, fr in ipairs(frames) do
            if fr.events[event] then return true end
        end
        return false
    end
    function t.Body(name) local i = Find(name); return i > 0 and macros[i].body or nil end
    function t.Macro(name) local i = Find(name); return i > 0 and macros[i] or nil end
    function t.Combat(on) combat = on end
    function t.Level(value) level = value end
    function t.Bags(list) bags = list end
    function t.Counts() return created, edited, deleted end
    function t.Profile(new) settings = new; ns.Apply() end
    function t.Group(kind) group = kind end
    function t.SetMax(n) consts.MAX_ACCOUNT_MACROS = n end
    t.printed, t.macros = printed, macros
    return t
end

local failures = 0
local function Check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(("FAIL %s\n  got:  %s\n  want: %s"):format(label, tostring(got), tostring(want)))
    end
end

-- Nothing is written before the world loads, then the chosen macros appear.
do
    local t = Fixture({ settings = { health = true, trinket1 = true }, bags = { 929, 5509 } })
    t.Fire("BAG_UPDATE_DELAYED")
    Check("no writes before PLAYER_ENTERING_WORLD", #t.macros, 0)
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("health, healthstone then potion", t.Body("NF Health"),
        "#showtooltip\n/castsequence reset=combat item:5509, item:929")
    Check("trinket 1", t.Body("NF Trinket 1"), "#showtooltip 13\n/use 13")
    Check("mana not made while off", t.Body("NF Mana"), nil)
end

-- Potion First, with a fallback to the other list when the preferred one is empty.
do
    local t = Fixture({ settings = { health = true, healthOrder = "potion" }, bags = { 929, 5509 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("health, potion then healthstone", t.Body("NF Health"),
        "#showtooltip\n/castsequence reset=combat item:929, item:5509")
    t.Bags({ 5509 })
    t.Fire("BAG_UPDATE_DELAYED")
    Check("potion first falls back to a stone", t.Body("NF Health"), "#showtooltip\n/use item:5509")
end

-- Forever's Discolored potions count; battleground draughts and Whipper Root Tuber do not.
do
    local t = Fixture({ settings = { health = true, healthOrder = "potion" }, bags = { 17348, 11951, 247241, 858 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("health, Discolored over a lower potion", t.Body("NF Health"),
        "#showtooltip\n/castsequence reset=combat item:247241, item:858")
    t = Fixture({ settings = { health = true, healthOrder = "potion" }, bags = { 17348, 11951 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("health, no draught or tuber", t.Body("NF Health"), "#showtooltip")
end

-- One step per potion carried, so running out of one kind mid-fight moves on to the next.
do
    local bags = { 13446, 3928, 3928, 3928, 3928, 3928, 3928, 3928, 3928, 3928, 5509 }
    local superiors = string.rep(", item:3928", 7)
    local t = Fixture({ settings = { health = true }, bags = bags })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("health, stone then eight potion steps", t.Body("NF Health"),
        "#showtooltip\n/castsequence reset=combat item:5509, item:13446" .. superiors)
    t = Fixture({ settings = { health = true, healthOrder = "potion" }, bags = bags })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("health, potion first puts the stone second", t.Body("NF Health"),
        "#showtooltip\n/castsequence reset=combat item:13446, item:5509" .. superiors)
end

-- Level 12 carrying a level-14 potion: all generated item paths exclude it.
do
    local t = Fixture({ level = 12, levels = { [929] = 14, [858] = 3, [3385] = 14, [2455] = 5,
        [5509] = 20, [5512] = 1, [2581] = 14, [1251] = 1 },
        settings = { health = true, healthPotion = true, healthstone = true, mana = true, bandage = true },
        bags = { 929, 858, 3385, 2455, 5509, 5512, 2581, 1251 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("under-level potion omitted from combined sequence", t.Body("NF Health"),
        "#showtooltip\n/castsequence reset=combat item:5512, item:858")
    Check("under-level healing potion omitted", t.Body("NF Health Potion"), "#showtooltip\n/use item:858")
    Check("under-level healthstone omitted", t.Body("NF Healthstone"), "#showtooltip\n/use item:5512")
    Check("under-level mana potion omitted", t.Body("NF Mana"), "#showtooltip\n/use item:2455")
    Check("under-level bandage omitted", t.Body("NF Bandage"), "#showtooltip\n/use [@player] item:1251")
    t.Level(14)
    t.Fire("UNIT_LEVEL", "target")
    Check("another unit leveling is ignored", t.Body("NF Health Potion"), "#showtooltip\n/use item:858")
    t.Fire("UNIT_LEVEL", "player")
    Check("exact required level adds higher rank without bag change", t.Body("NF Health Potion"),
        "#showtooltip\n/castsequence reset=combat item:929, item:858")
end

-- A reload replaces an old unusable macro even if there is no eligible fallback.
do
    local t = Fixture({ level = 12, levels = { [929] = 14 }, settings = { healthPotion = true },
        bags = { 929 }, macros = { { name = "NF Health Potion", body = "#showtooltip\n/use item:929" } } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("old over-level macro cleared", t.Body("NF Health Potion"), "#showtooltip")
end

-- Food/drink bars share the same eligibility and preserve conjured priority only among eligible items.
do
    local t = Fixture({ level = 12, settings = { food = true, drink = true }, qol = { foodBar = true },
        bags = { 8932, 4599, 5349, 8079, 8766, 1179 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("low-level food and drink", t.Body("NF Food"), "#showtooltip\n/use item:5349\n/use item:1179")
    Check("low-level drink macro", t.Body("NF Drink"), "#showtooltip\n/use item:1179")
    Check("food bar avoids over-level drink", t.FoodBar().buttons[2].attrs.item1, "item:1179")
    t.Combat(true)
    t.Level(45)
    t.Fire("UNIT_LEVEL", "player")
    Check("level change does not write macros in combat", t.Body("NF Drink"), "#showtooltip\n/use item:1179")
    Check("level change does not change secure bar in combat", t.FoodBar().buttons[2].attrs.item1, "item:1179")
    t.Combat(false)
    t.Fire("PLAYER_REGEN_ENABLED")
    Check("eligible conjured drink after combat", t.Body("NF Drink"), "#showtooltip\n/use item:8079")
    Check("bar catches up after combat", t.FoodBar().buttons[2].attrs.item1, "item:8079")
end

-- Unknown requirements are skipped and the successful cache event updates without a bag change.
do
    local missing = { [929] = true, [8079] = true }
    local t = Fixture({ settings = { healthPotion = true, drink = true }, qol = { foodBar = true },
        levels = { [929] = 14 }, missing = missing, bags = { 929, 858, 8079, 1179 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("unknown potion requirement skipped", t.Body("NF Health Potion"), "#showtooltip\n/use item:858")
    Check("unknown conjured drink requirement skipped", t.Body("NF Drink"), "#showtooltip\n/use item:1179")
    missing[929], missing[8079] = nil, nil
    t.Fire("GET_ITEM_INFO_RECEIVED", 929, false)
    Check("failed cache event ignored", t.Body("NF Health Potion"), "#showtooltip\n/use item:858")
    t.Fire("GET_ITEM_INFO_RECEIVED", 929, true)
    Check("loaded potion becomes eligible", t.Body("NF Health Potion"),
        "#showtooltip\n/castsequence reset=combat item:929, item:858")
    t.Fire("GET_ITEM_INFO_RECEIVED", 8079, true)
    Check("loaded drink updates macro", t.Body("NF Drink"), "#showtooltip\n/use item:8079")
    Check("loaded drink updates bar", t.FoodBar().buttons[2].attrs.item1, "item:8079")
end

-- Food and drink: conjured wins over a higher level, the best level wins otherwise.
do
    local t = Fixture({ settings = { food = true }, bags = { 1179, 8766, 8079, 4599, 8932 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("food and drink", t.Body("NF Food"), "#showtooltip\n/use item:8932\n/use item:8079")
    t.Bags({ 5349, 8932 })
    t.Fire("BAG_UPDATE_DELAYED")
    Check("conjured food first, no drink", t.Body("NF Food"), "#showtooltip\n/use item:5349")
end

-- Nothing carried: a bare #showtooltip macro is made to place on a bar, and an existing one is left as it was.
do
    local t = Fixture({ settings = { bandage = true }, bags = {} })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("placeholder bandage macro without bandages", t.Body("NF Bandage"), "#showtooltip")
    t.Bags({ 14529 })
    t.Fire("BAG_UPDATE_DELAYED")
    Check("bandage on self", t.Body("NF Bandage"), "#showtooltip\n/use [@player] item:14529")
    t.Bags({})
    t.Fire("BAG_UPDATE_DELAYED")
    Check("bandage kept after the last is used", t.Body("NF Bandage"),
        "#showtooltip\n/use [@player] item:14529")
end

-- Health split in two: the stone alone, the potions alone, NF Health unchanged.
do
    local t = Fixture({ settings = { health = true, healthstone = true, healthPotion = true },
        bags = { 929, 929, 5509 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("NF Health still mixes", t.Body("NF Health"),
        "#showtooltip\n/castsequence reset=combat item:5509, item:929, item:929")
    Check("NF Healthstone is the stone", t.Body("NF Healthstone"), "#showtooltip\n/use item:5509")
    Check("NF Health Potion is the potions", t.Body("NF Health Potion"),
        "#showtooltip\n/castsequence reset=combat item:929, item:929")
    t.Bags({ 929 })
    t.Fire("BAG_UPDATE_DELAYED")
    Check("stone macro keeps its item once the stone is gone", t.Body("NF Healthstone"), "#showtooltip\n/use item:5509")
    Check("one potion is a plain use", t.Body("NF Health Potion"), "#showtooltip\n/use item:929")
    t = Fixture({ settings = { healthstone = true, healthPotion = true } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("healthstone placeholder", t.Body("NF Healthstone"), "#showtooltip")
    Check("health potion placeholder", t.Body("NF Health Potion"), "#showtooltip")
    Check("NF Health stays off", t.Body("NF Health"), nil)
    t.Bags({ 5509 })
    t.Fire("BAG_UPDATE_DELAYED")
    Check("placeholder filled when the stone arrives", t.Body("NF Healthstone"), "#showtooltip\n/use item:5509")
    Check("potion macro ignores a stone", t.Body("NF Health Potion"), "#showtooltip")
end

-- Food apart from drink.
do
    local t = Fixture({ settings = { food = true, drink = true }, bags = { 8932, 8079 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("food with drink as before", t.Body("NF Food"), "#showtooltip\n/use item:8932\n/use item:8079")
    Check("NF Drink is the drink", t.Body("NF Drink"), "#showtooltip\n/use item:8079")
    t.Set("foodOnly", true)
    Check("food only drops the drink", t.Body("NF Food"), "#showtooltip\n/use item:8932")
    Check("drink unaffected by food only", t.Body("NF Drink"), "#showtooltip\n/use item:8079")
    t = Fixture({ settings = { food = true, drink = true, foodOnly = true } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("food placeholder", t.Body("NF Food"), "#showtooltip")
    Check("drink placeholder", t.Body("NF Drink"), "#showtooltip")
    t = Fixture({ settings = { mana = true } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("mana placeholder", t.Body("NF Mana"), "#showtooltip")
    Check("trinket needs no placeholder", t.Body("NF Trinket 1"), nil)
end

-- Extra lines follow the generated ones, \n splits them, and 255 characters is the cap.
do
    local extra = "/use [@mouseover,help][]Holy Light\n/cqs"
    local t = Fixture({ settings = { mana = true, manaExtra = extra }, bags = { 3827 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("extra lines appended", t.Body("NF Mana"),
        "#showtooltip\n/use item:3827\n/use [@mouseover,help][]Holy Light\n/cqs")
    t.Set("manaExtra", "")
    Check("clearing the extra lines edits the macro", t.Body("NF Mana"), "#showtooltip\n/use item:3827")
    t.Set("manaExtra", extra)
    t.Bags({})
    t.Set("mana", false)
    t.Set("mana", true)
    Check("extra lines on the placeholder", t.Body("NF Mana"),
        "#showtooltip\n/use [@mouseover,help][]Holy Light\n/cqs")
    local long = "/say " .. string.rep("x", 250)
    t.Set("manaExtra", long)
    Check("over the cap: extra lines left out", t.Body("NF Mana"), "#showtooltip")
    Check("over the cap: said once", #t.printed, 1)
    t.Set("manaExtra", long)
    Check("over the cap: not repeated", #t.printed, 1)
    Check("over the cap: names the macro", t.printed[1]:find("NF Mana", 1, true) ~= nil, true)
    t = Fixture({ settings = { food = true, foodExtra = "/say " .. string.rep("x", 222) }, bags = { 8932 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    local body = t.Body("NF Food")
    Check("exactly 255 is kept", body ~= nil and #body == 255, true)
end

-- Extra lines that run a script are left out; a change reaches a placeholder or a stale body at once.
do
    local t = Fixture({ settings = { mana = true, manaExtra = "/run print(1)" }, bags = { 3827 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("script extra lines left out", t.Body("NF Mana"), "#showtooltip\n/use item:3827")
    Check("script extra lines: said once", #t.printed, 1)
    t.Fire("BAG_UPDATE_DELAYED")
    Check("script extra lines: not repeated", #t.printed, 1)
    t.Set("manaExtra", "/cqs\n/script print(1)")
    Check("a script on a later line is caught too", t.Body("NF Mana"), "#showtooltip\n/use item:3827")
    t = Fixture({ settings = { mana = true } })
    t.Fire("PLAYER_ENTERING_WORLD")
    t.Set("manaExtra", "/cqs")
    Check("extra lines reach the placeholder at once", t.Body("NF Mana"), "#showtooltip\n/cqs")
    t.Set("manaExtra", "")
    Check("clearing them reaches the placeholder", t.Body("NF Mana"), "#showtooltip")
    t = Fixture({ settings = { food = true }, bags = { 8079 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("food with only drink", t.Body("NF Food"), "#showtooltip\n/use item:8079")
    t.Set("foodOnly", true)
    Check("food only with no food drops the drink", t.Body("NF Food"), "#showtooltip")
end

-- Combat defers the write until it ends; an unchanged body is not rewritten.
do
    local t = Fixture({ settings = { mana = true }, bags = { 3827 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    t.Combat(true)
    t.Bags({ 3827, 13444 })
    t.Fire("BAG_UPDATE_DELAYED")
    Check("no edit in combat", t.Body("NF Mana"), "#showtooltip\n/use item:3827")
    t.Combat(false)
    t.Fire("PLAYER_REGEN_ENABLED")
    Check("edited after combat", t.Body("NF Mana"), "#showtooltip\n/use item:13444")
    local _, before = t.Counts()
    t.Fire("BAG_UPDATE_DELAYED")
    local _, after = t.Counts()
    Check("unchanged body not rewritten", after, before)
end

-- Turning a macro or the module off deletes it.
do
    local t = Fixture({ settings = { trinket1 = true, trinket2 = true }, bags = {} })
    t.Fire("PLAYER_ENTERING_WORLD")
    t.Set("trinket1", false)
    Check("toggle off deletes", t.Body("NF Trinket 1"), nil)
    Check("other macro stays", t.Body("NF Trinket 2"), "#showtooltip 14\n/use 14")
    t.Set("enabled", false)
    Check("module off deletes", t.Body("NF Trinket 2"), nil)
end

-- Focus body follows its options; the announce channel follows the group.
do
    local t = Fixture({ settings = { focus = true, focusMark = true, focusMarker = 7,
        focusAnnounce = true } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("focus solo, no announce", t.Body("NF Focus"),
        "/focus [@mouseover,exists,nodead][]\n/tm [@focus] 7")
    t.Group("party")
    t.Fire("GROUP_ROSTER_UPDATE")
    Check("focus in a party", t.Body("NF Focus"),
        "/focus [@mouseover,exists,nodead][]\n/tm [@focus] 7\n/p Focus: %f")
    t.Group("raid")
    t.Fire("GROUP_ROSTER_UPDATE")
    Check("focus in a raid", t.Body("NF Focus"),
        "/focus [@mouseover,exists,nodead][]\n/tm [@focus] 7\n/ra Focus: %f")
end

-- A profile switch that turns a macro off keeps it; its own switch deletes it.
do
    local t = Fixture({ settings = { health = true, trinket1 = true }, bags = { 5509 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    t.Profile({})
    Check("profile switch keeps the macro", t.Body("NF Trinket 1"), "#showtooltip 13\n/use 13")
    t.Bags({ 929 })
    t.Fire("BAG_UPDATE_DELAYED")
    Check("macro off in this profile is not updated", t.Body("NF Health"),
        "#showtooltip\n/use item:5509")
    t.Profile({ trinket1 = true })
    t.Set("trinket1", false)
    Check("its own switch deletes it", t.Body("NF Trinket 1"), nil)
end

-- Turned off in combat: deleted once combat ends.
do
    local t = Fixture({ settings = { trinket2 = true } })
    t.Fire("PLAYER_ENTERING_WORLD")
    t.Combat(true)
    t.Set("trinket2", false)
    Check("not deleted in combat", t.Body("NF Trinket 2"), "#showtooltip 14\n/use 14")
    t.Combat(false)
    t.Fire("PLAYER_REGEN_ENABLED")
    Check("deleted after combat", t.Body("NF Trinket 2"), nil)
end

-- Full General macros: warned once, nothing made; made once a slot frees up.
do
    local t = Fixture({ settings = { trinket1 = true, trinket2 = true }, max = 0 })
    t.Fire("PLAYER_ENTERING_WORLD")
    t.Fire("BAG_UPDATE_DELAYED")
    Check("nothing made when full", #t.macros, 0)
    Check("warned once", #t.printed, 1)
    t.SetMax(2)
    t.Fire("UPDATE_MACROS")
    Check("made after a macro is deleted", t.Body("NF Trinket 1"), "#showtooltip 13\n/use 13")
end

-- A client whose name lookup misses new macros: made once and warned, not again on every UPDATE_MACROS.
do
    local t = Fixture({ settings = { healthPotion = true, mana = true }, lookupMisses = true })
    t.Fire("PLAYER_ENTERING_WORLD")
    for _ = 1, 5 do t.Fire("UPDATE_MACROS") end
    Check("each lost macro made once", #t.macros, 2)
    Check("each lost macro warned once", #t.printed, 2)
end

do
    local t = Fixture({})
    t.Fire("PLAYER_ENTERING_WORLD")
    t.Combat(true)
    t.ns.PickupManagedMacro("trinket1")
    Check("click in combat does not create", t.Body("NF Trinket 1"), nil)
    t.Combat(false)
    t.ns.PickupManagedMacro("trinket1")
    Check("click creates macro", t.Body("NF Trinket 1"), "#showtooltip 13\n/use 13")
    Check("managed macro stays a General macro", t.Macro("NF Trinket 1").perChar, false)
end

-- Food & Drink bar: built only once switched on, best food and drink, updates after combat.
do
    local t = Fixture({ bags = { 1179, 8766, 5349, 4599 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("food bar not built while off", t.FoodBar(), nil)
    t.SetQoL("foodBar", true)
    local bar = t.FoodBar()
    local food, drink = bar.buttons[1], bar.buttons[2]
    Check("food bar shown", bar.shown, true)
    Check("conjured food first", food.attrs.item1, "item:5349")
    Check("highest level drink", drink.attrs.item1, "item:8766")
    Check("food button uses an item", food.attrs.type1, "item")
    Check("drink icon", drink.icon.texture, "icon8766")
    Check("food count", food.count.text, 1)
    Check("food button named for its binding", food.name, "NaowhForeverFoodBarFood")
    Check("drink button named for its binding", drink.name, "NaowhForeverFoodBarDrink")
    Check("drink shown", drink.shown, true)
    Check("two buttons wide", bar.width, 36 * 2 + 4)
    Check("HUD Editor opens QoL", t.Mover().page, "QoL/Loot & Items")
    Check("HUD Editor opens its card", t.Mover().feature, "QoL/Loot & Items:foodBar")

    t.Combat(true)
    t.Bags({ 4599, 4599 })
    t.Fire("BAG_UPDATE_DELAYED")
    Check("no change in combat", food.attrs.item1, "item:5349")
    t.Combat(false)
    t.Fire("PLAYER_REGEN_ENABLED")
    Check("food after combat", food.attrs.item1, "item:4599")
    Check("count after combat", food.count.text, 2)
    Check("no drink: button does nothing", drink.attrs.type1, nil)
    Check("no drink: icon greyed", drink.icon.desaturated, true)

    t.Set("enabled", false)
    Check("Macros off leaves the bar up", bar.shown, true)
    t.SetQoL("foodBar", false)
    Check("food bar hidden when off", bar.shown, false)
    local heard = 0
    for _ in pairs(t.FoodEvents().events) do heard = heard + 1 end
    Check("off, it listens to nothing, not even loading screens", heard, 0)
    t.Bags({ 1179 })
    t.Fire("BAG_UPDATE_DELAYED")
    Check("bag changes ignored while off", food.attrs.item1, "item:4599")
end

-- Show Count and Show Keybinds, on the same rows as the Consumable Bar's.
do
    local t = Fixture({ qol = { foodBar = true }, bags = { 8766, 5349 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    t.Tick()
    local bar = t.FoodBar()
    local food, drink = bar.buttons[1], bar.buttons[2]
    local before = food.attrs.item1
    t.ns.FoodBarPoint(4599, 1179)
    Check("shown on its own, it keeps its own search", food.attrs.item1, before)
    Check("and listens to the bags itself", t.Listening("BAG_UPDATE_DELAYED"), true)
    local foodEvents, registers = t.FoodEvents(), 0
    local register = foodEvents.RegisterEvent
    function foodEvents:RegisterEvent(event)
        registers = registers + 1
        register(self, event)
    end
    t.SetQoL("foodBarTextX", 3)
    t.SetQoL("foodBarKeySize", 14)
    Check("its look restyles without applying the bar", registers, 0)
    Check("the count follows at once", food.count.point[4], 3 - t.ns.Shared.ItemBar.TEXT_INSET)
    Check("the count shows by default, as it always has", food.count.shown, true)
    Check("keys are off by default", food.key.shown, false)
    Check("off, nothing listens for binding changes", t.Listening("UPDATE_BINDINGS"), false)
    t.SetQoL("foodBarShowCount", false)
    Check("Show Count off hides it", food.count.shown, false)
    t.bindings["CLICK NaowhForeverFoodBarFood:LeftButton"] = "CTRL-F"
    t.actions[25] = { "item", 8766 }
    t.ActionButton(25, "5")
    t.SetQoL("foodBarKeybinds", true)
    t.Tick()
    Check("the key bound to its button", food.key.text, "*CTRL-F")
    Check("or the key of an action button holding its item", drink.key.text, "5")
    Check("keys follow binding changes", t.Listening("UPDATE_BINDINGS"), true)
    t.actions[25] = nil
    t.Fire("ACTIONBAR_SLOT_CHANGED")
    Check("it waits a frame for the game to redraw its own keys", drink.key.text, "5")
    t.Tick()
    Check("then follows the bars", drink.key.shown, false)
    local rows, labels = t.cards["QoL/Loot & Items:foodBar"].rows, {}
    for _, row in ipairs(rows) do
        if row.label then labels[row.label] = row end
    end
    Check("Show Count with its cog", labels["Show Count"].cog.title, "Count Text")
    Check("its rows behind it", labels["Count Size"].under, "Show Count")
    Check("Show Keybinds with its cog", labels["Show Keybinds"].cog.title, "Keybind Text")
    Check("on the Food & Drink Bar's own keys", labels["Count Size"].key, "foodBarFontSize")
    Check("the same rows as the Consumable Bar's", #t.ns.Shared.ItemBar.TextRows(t.ns.QoLSettings, "x"), 16)
    Check("an Anchor section", labels["Anchor to a Unit Frame"].buttonText, "Choose")
    local studio = t.cards["QoL/Loot & Items:foodBar"].studio
    local preview = studio.new(t.frame())
    studio.paint(preview, "stocked")
    Check("the preview shows the key you bound", preview.buttons[1].key.text, "*CTRL-F")
    Check("and a sample where none is bound", preview.buttons[2].key.text, "F2")
    Check("with the HUD Editor's anchoring for elements", labels["Anchor to an Element"].buttonText, "HUD Editor")
    Check("its points wait for a frame", labels["Bar Point"].needs(), false)
end

-- Anchored to a unit frame; Naowh Forever's own elements are the HUD Editor's to anchor to.
do
    local t = Fixture({ qol = { foodBar = true }, bags = { 5349 } })
    local unit = t.frame("PlayerFrame")
    function unit:IsProtected() return true end
    unit.attrs.unit = "player"
    t.Fire("PLAYER_ENTERING_WORLD")
    local bar = t.FoodBar()
    Check("on the screen at first", bar.point[3], "CENTER")
    t.SetQoL("foodBarAnchor", "PlayerFrame")
    t.SetQoL("foodBarAnchorPoint", "TOPLEFT")
    t.SetQoL("foodBarAnchorRelPoint", "BOTTOMLEFT")
    t.SetQoL("foodBarY", -4)
    Check("anchored to the unit frame", bar.point[2], unit)
    Check("at the points and offset chosen", bar.point[1] .. bar.point[3] .. bar.point[5], "TOPLEFTBOTTOMLEFT-4")
    t.Mover().onMoved({ point = "TOP", relPoint = "TOP", x = 1, y = 2 })
    Check("dragged in the HUD Editor, it is on the screen again", t.qol.foodBarAnchor, "UIParent")
    Check("where it was dropped", bar.point[1] .. bar.point[5], "TOP2")
    local other = t.frame("SomeAddonFrame")
    t.SetQoL("foodBarAnchor", "SomeAddonFrame")
    Check("another addon's frame cannot hold it", bar.point[2] ~= other, true)
    local consumable = t.frame("NaowhForeverConsumableBar")
    t.SetQoL("foodBarAnchor", "NaowhForeverConsumableBar")
    Check("nor the Consumable Bar: the HUD Editor anchors elements", bar.point[2] ~= consumable, true)
end

-- With the Consumable Bar on, its card sits under the Consumable Bar; search still finds it.
do
    local fresh = Fixture({ consumableBarLoaded = true, qol = { foodBar = true }, bags = { 5349 } })
    Check("loaded but switched off, as on a fresh install: the card stays on Loot & Items",
        fresh.cards["QoL/Loot & Items:foodBar"] ~= nil and fresh.cards["Consumable Bar/Settings:foodBar"] == nil, true)
    local missing = Fixture({ qol = { foodBar = true, consumableBar = true }, bags = { 5349 } })
    Check("switched on but not loaded: on Loot & Items too", missing.cards["QoL/Loot & Items:foodBar"] ~= nil, true)
    local t = Fixture({ consumableBarLoaded = true, qol = { foodBar = true, consumableBar = true }, bags = { 5349 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    local card = t.cards["Consumable Bar/Settings:foodBar"]
    Check("the card moves under the Consumable Bar", card ~= nil and t.cards["QoL/Loot & Items:foodBar"], nil)
    Check("its name still says food", card.name:find("Food") ~= nil, true)
    Check("the same switch", card.switch, "foodBar")
    Check("the HUD Editor opens it there", t.Mover().feature, "Consumable Bar/Settings:foodBar")
end

-- While its buttons are on the Consumable Bar, the Food & Drink Bar steps aside, and its card says why.
do
    local t = Fixture({ consumableBarLoaded = true, qol = { foodBar = true, consumableBar = true }, bags = { 5349 } })
    local onMain = false
    t.ns.ConsumableBarUsesFood = function() return onMain end
    t.Fire("PLAYER_ENTERING_WORLD")
    local bar = t.FoodBar()
    local card = t.cards["Consumable Bar/Settings:foodBar"]
    Check("up while its buttons are not on the main bar", bar.shown, true)
    Check("its switch is its own", card.switchWhy(), nil)
    onMain = true
    t.SetQoL("consumableBarItems", { "smart:food", "smart:drink" })
    Check("their being put on the main bar hides it", bar.shown, false)
    Check("its switch is held, saying why", card.switchWhy(), "Its buttons are on the Consumable Bar")
    Check("its own setting is kept for later", t.qol.foodBar, true)
    onMain = false
    t.SetQoL("consumableBarItems", {})
    Check("taken off the main bar, it is back", bar.shown, true)
end

-- Hidden for the Consumable Bar, it is still kept on your best food and drink: the keys both bars
-- share click its buttons. That holds with the Food & Drink Bar itself switched off.
do
    local t = Fixture({ qol = { foodBar = false }, bags = { 5349, 8766 } })
    local onMain = true
    t.ns.ConsumableBarUsesFood = function() return onMain end
    t.Fire("PLAYER_ENTERING_WORLD")
    local bar = t.FoodBar()
    Check("built for the Consumable Bar's keys", bar ~= nil, true)
    Check("but hidden", bar.shown, false)
    Check("its buttons on your best food and drink", bar.buttons[1].attrs.item1 .. bar.buttons[2].attrs.item1,
        "item:5349item:8766")
    Check("it leaves the bags to the Consumable Bar, so they are searched once", t.Listening("BAG_UPDATE_DELAYED"),
        false)
    t.ns.FoodBarPoint(4599, 8766)
    Check("kept current while hidden, on what that bar found", bar.buttons[1].attrs.item1, "item:4599")
    t.ns.ShowUnlockMode()
    Check("nor shown in the HUD Editor", bar.mover.shown, false)
    t.ns.HideUnlockMode()
    Check("the bindings both bars use", t.ns.FoodBarBindings.food, "CLICK NaowhForeverFoodBarFood:LeftButton")
    local rows = t.cards["QoL/Loot & Items:foodBar"].rows
    local food
    for _, row in ipairs(rows) do if row.label == "Use Best Food" then food = row end end
    Check("the same as its own Use Best Food row", food.binding, t.ns.FoodBarBindings.food)
    onMain = false
    t.SetQoL("consumableBarItems", {})
    Check("taken off the main bar with its own switch off, it rests", t.Listening("BAG_UPDATE_DELAYED"), false)
end

-- The Consumable Bar is its own switch, so the keys stay with QoL's switch off too.
do
    local t = Fixture({ qol = { enabled = false, foodBar = true }, bags = { 5349 } })
    t.ns.ConsumableBarUsesFood = function() return true end
    t.Fire("PLAYER_ENTERING_WORLD")
    local bar = t.FoodBar()
    Check("with QoL off, its buttons are kept for the Consumable Bar", bar ~= nil and bar.buttons[1].attrs.item1,
        "item:5349")
end

-- No mana (warriors and rogues): the food button alone, and the drink button does nothing.
do
    local t = Fixture({ class = "WARRIOR", qol = { foodBar = true }, bags = { 8766, 4599 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    local bar = t.FoodBar()
    local food, drink = bar.buttons[1], bar.buttons[2]
    Check("no mana: food", food.attrs.item1, "item:4599")
    Check("no mana: food shown", food.shown, true)
    Check("no mana: drink hidden", drink.shown, false)
    Check("no mana: drink not used", drink.attrs.type1, nil)
    Check("no mana: one button wide", bar.width, 36)
end

-- Settings from when the bar was on the Macros page move to QoL once; QoL's own win.
do
    local pos = { point = "TOP", relPoint = "TOP", x = 1, y = 2 }
    local t = Fixture({ settings = { foodBar = true, foodBarSize = 40, foodBarPos = pos },
        qol = { foodBarSize = 50 }, bags = { 4599 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("switch moved", t.qol.foodBar, true)
    Check("position moved", t.qol.foodBarPos, pos)
    Check("QoL's own size kept", t.qol.foodBarSize, 50)
    Check("old switch cleared", t.settings.foodBar, nil)
    Check("old size cleared", t.settings.foodBarSize, nil)
    Check("bar up after the move", t.FoodBar().shown, true)
end

-- Free while off: bag, macro, group and combat events only while a kept macro needs them.
do
    local t = Fixture({ bags = { 929 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    local function Heard()
        local list = {}
        for _, e in ipairs({ "BAG_UPDATE_DELAYED", "UPDATE_MACROS", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED" }) do
            if t.Listening(e) then list[#list + 1] = e end
        end
        return table.concat(list, ",")
    end
    Check("nothing kept: no events", Heard(), "")
    Check("nothing kept: no level events", t.Listening("UNIT_LEVEL"), false)
    Check("nothing kept: no item-data events", t.Listening("GET_ITEM_INFO_RECEIVED"), false)
    t.Set("trinket1", true)
    Check("a trinket macro: macro changes only", Heard(), "UPDATE_MACROS")
    Check("a trinket macro needs no level events", t.Listening("UNIT_LEVEL"), false)
    t.Set("food", true)
    Check("a food macro: bag changes too", Heard(), "BAG_UPDATE_DELAYED,UPDATE_MACROS")
    Check("a food macro listens for levels", t.Listening("UNIT_LEVEL"), true)
    Check("a food macro listens for item data", t.Listening("GET_ITEM_INFO_RECEIVED"), true)
    t.Set("focus", true)
    t.Set("focusAnnounce", true)
    Check("an announced focus: group changes too", Heard(), "BAG_UPDATE_DELAYED,UPDATE_MACROS,GROUP_ROSTER_UPDATE")
    t.Combat(true)
    t.Fire("BAG_UPDATE_DELAYED")
    Check("a change in combat waits for its end", t.Listening("PLAYER_REGEN_ENABLED"), true)
    t.Combat(false)
    t.Fire("PLAYER_REGEN_ENABLED")
    Check("and stops listening after it", t.Listening("PLAYER_REGEN_ENABLED"), false)
    t.Set("enabled", false)
    Check("module off: no events", Heard(), "")
    Check("module off: no level events", t.Listening("UNIT_LEVEL"), false)
    Check("module off: no item-data events", t.Listening("GET_ITEM_INFO_RECEIVED"), false)
    t.Profile({ health = true })
    Check("a profile switch listens for what it keeps", Heard(), "BAG_UPDATE_DELAYED,UPDATE_MACROS")
end

-- A bag change with NF Food, NF Health and the food bar on: no garbage.
do
    local t = Fixture({ settings = { food = true, health = true }, qol = { foodBar = true },
        bags = { 1179, 8766, 5349, 4599, 929, 5509 } })
    t.Fire("PLAYER_ENTERING_WORLD")
    local Measure = dofile("Tools/regression/measure.lua")(function(label, ok) Check(label, ok, true) end)
    Measure("a bag change", 0.05, function() t.Fire("BAG_UPDATE_DELAYED") end)
end

-- The Consumable Bar runs these macros by name: one it uses is written and kept current
-- whatever its switch or the module's, and cannot be removed from here.
do
    local t = Fixture({ settings = { enabled = false }, bags = { 5509 } })
    local used = {}
    t.ns.ConsumableBarUsesMacro = function(key) return used[key] == true end
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("nothing written with the module off", t.Body("NF Health"), nil)
    used.health = true
    t.ns.UpdateManagedMacros()
    Check("a macro the bar uses is written anyway", t.Body("NF Health"), "#showtooltip\n/use item:5509")
    t.Bags({ 929 })
    t.Fire("BAG_UPDATE_DELAYED")
    Check("and kept current", t.Body("NF Health"), "#showtooltip\n/use item:929")
    used.health = nil
    t.ns.UpdateManagedMacros()
    Check("written only for the bar, it goes when the bar stops using it", t.Body("NF Health"), nil)
    Check("the bar's macros are this module's", t.ns.ConsumableMacros.health.name, "NF Health")
    Check("and what it noted is cleared", t.settings.barOnly.health, nil)
end

-- What only the bar wanted is saved, so it still goes when the bar stops using it after a /reload.
do
    local settings = { enabled = false }
    local t = Fixture({ settings = settings, bags = { 5509 } })
    t.ns.ConsumableBarUsesMacro = function(key) return key == "health" end
    t.Fire("PLAYER_ENTERING_WORLD")
    Check("written for the bar alone, that is saved", settings.barOnly.health, true)
    local after = Fixture({ settings = settings, bags = { 5509 }, macros = t.macros })
    after.ns.ConsumableBarUsesMacro = function() return false end
    after.Fire("PLAYER_ENTERING_WORLD")
    Check("after a reload, the bar no longer using it removes it", after.Body("NF Health"), nil)
    local mine = Fixture({ settings = { health = true }, bags = { 5509 } })
    mine.ns.ConsumableBarUsesMacro = function(key) return key == "health" end
    mine.Fire("PLAYER_ENTERING_WORLD")
    Check("one you switched on is not the bar's alone", mine.settings.barOnly.health, nil)
end

do
    local t = Fixture({ settings = { health = true }, bags = { 5509 } })
    local used = { health = true }
    t.ns.ConsumableBarUsesMacro = function(key) return used[key] == true end
    t.Fire("PLAYER_ENTERING_WORLD")
    t.Set("health", false)
    Check("switching it off keeps it while the bar uses it", t.Body("NF Health"), "#showtooltip\n/use item:5509")
    t.Set("enabled", false)
    Check("so does switching the module off", t.Body("NF Health"), "#showtooltip\n/use item:5509")
    t.Set("enabled", true)
    t.Set("health", true)
    used.health = nil
    t.ns.UpdateManagedMacros()
    Check("one you switched on yourself stays when the bar stops using it", t.Body("NF Health"),
        "#showtooltip\n/use item:5509")
end

-- Kept Current: a macro the bar uses is locked on there, and a row leads to the bar's settings.
do
    local t = Fixture({ settings = { health = false } })
    local used = {}
    t.ns.ConsumableBarUsesMacro = function(key) return used[key] == true end
    local function Row(label)
        for _, row in ipairs(t.cards["Macros/Settings:kept"].rows()) do
            if row.label == label then return row end
        end
    end
    Check("a macro the bar does not use is its own switch", Row("NF Health").key, "health")
    Check("no bar row while the bar uses none", Row("Consumable Bar"), nil)
    used.health = true
    local health = Row("NF Health")
    Check("used by the bar, it shows on", health.get(), true)
    Check("and is locked, saying why", health.needs(), false)
    Check("the why", health.why, "Used by Consumable Bar")
    health.set(false)
    Check("switching it from here does nothing", t.settings.health, false)
    Check("a row leads to the bar's settings", Row("Consumable Bar").buttonText, "Options")
    Check("other macros keep their own switch", Row("NF Mana").key, "mana")
    Check("the card is drawn again when the bar's items change", t.cards["Macros/Settings:kept"].watch[1],
        t.ns.QoLSettings)
    Check("the bar's Health cog offers the same priority", t.ns.HealthOrderChoices.values.potion, "Potion First")
    Check("counted as kept current", t.cards["Macros/Settings:kept"].summary(t.ns.MacroSettings), "1 of 11 kept current")
end

-- A warrior on a profile shared with a caster whose bar carries NF Mana: the account-wide macro stays.
do
    local mana = { name = "NF Mana", body = "#showtooltip\n/use item:13444" }
    local t = Fixture({ class = "WARRIOR", settings = { barOnly = { mana = true } }, macros = { mana } })
    t.ns.ConsumableBarUsesMacro = function(key) return key == "mana" end
    t.Fire("PLAYER_ENTERING_WORLD")
    local _, _, deleted = t.Counts()
    Check("the warrior deletes nothing", deleted, 0)
    Check("the caster's NF Mana is kept as it was", t.Body("NF Mana"), "#showtooltip\n/use item:13444")
end

if failures > 0 then
    print(failures .. " failure(s)")
    os.exit(1)
end
print("test-macros: all passed")

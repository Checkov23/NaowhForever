-- Loads the AuraBuffs Buffs & Consumables files and their data against stubbed aura, bag and group APIs
-- and checks which reminder icons show. Run from the repo root:
-- lua Tools/regression/test-buff-reminders.lua
-- Stands in for a secret value: any field or method use raises, as the client does.
local SECRET = setmetatable({}, { __index = function() error("attempt to index a secret value") end })
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local source = f:read("*a"); f:close()
    return source
end
local MODULE = {}
for i, path in ipairs({ "Core/Features.lua", "NaowhForever_AuraBuffs/AuraBuffs.lua",
    "NaowhForever_AuraBuffs/Constants.lua", "Shared/Game/Consumables.lua",
        "NaowhForever_AuraBuffs/Data/BuffReminders.lua", "NaowhForever_AuraBuffs/BuffReminders.lua",
    "NaowhForever_AuraBuffs/View/Style.lua", "NaowhForever_AuraBuffs/View/BuffCell.lua",
    "NaowhForever_AuraBuffs/UI/BuffMenu.lua", "NaowhForever_AuraBuffs/UI/BuffReminders.lua" }) do
    MODULE[i] = Read(path)
end
local CARD = Read("NaowhForever_AuraBuffs/UI/BuffsCard.lua")
local SETTINGS = Read("Shared/Settings/Settings.lua")

-- itemID -> use spell, for the food scan.
local ITEM_SPELLS = { [13931] = 1249513, [2679] = 433, [21023] = 25660 }
local SPELL_NAMES = { [1248406] = "Well Fed", [1249520] = "Well Fed", [1243969] = "Well Fed XP Boost" }

local function Recorder(props)
    return setmetatable(props or {}, { __index = function() return function() end end })
end

local function Fixture(opts)
    local settings = opts.settings or {}
    if settings.consumableEntries == nil then
        settings.consumableEntries = {
            { category = "food", itemID = 13931, auras = { 1249520 } },
            { category = "flask", itemID = 13510, auras = { 17626 } },
            { category = "battle", itemID = 13454, auras = { 17539 } },
        }
    end
    local state = {
        now = 1000, secret = false, combat = false, resting = false,
        instance = opts.instance or "none",
        bags = opts.bags or {},                     -- flat list of item IDs
        -- unit -> list of { spellID, seconds left at the start, duration }
        auras = opts.auras or { player = {} },
        group = opts.group,                         -- nil solo, "party" or "raid"
        units = opts.units or {},                   -- unit -> class; player included
        known = opts.known or {},
        weapons = opts.weapons or {},               -- slot -> enchant seconds left, false for none
        target = opts.target,                       -- nil, or the target's classification
        itemSpells = opts.itemSpells or {},         -- itemID -> use spell, once the item is cached
        requested = {},
        reads = 0,
    }
    local timers, frames = {}, {}

    local function NewFrame(template)
        local f
        f = Recorder({ shown = true, events = {}, scripts = {}, attributes = {}, template = template })
        function f:SetAttribute(k, v) f.attributes[k] = v end
        function f:IsShown() return f.shown end
        function f:GetWidth() return 400 end
        function f:GetHeight() return 120 end
        function f:Show() f.shown = true end
        function f:Hide() f.shown = false end
        function f:SetShown(v) f.shown = v and true or false end
        function f:SetScript(key, fn) f.scripts[key] = fn; if key == "OnEvent" then f.handler = fn end end
        function f:RegisterEvent(e) f.events[e] = true end
        function f:RegisterUnitEvent(e) f.events[e] = true end
        function f:UnregisterAllEvents() f.events = {} end
        function f:SetPoint(_, relativeTo) f.anchor = relativeTo end
        function f:ClearAllPoints() f.anchor = nil end
        function f:CreateTexture()
            local t = Recorder()
            function t:SetTexture(tex) t.texture = tex end
            return t
        end
        if template == "CooldownFrameTemplate" then
            function f:SetCooldown(start, duration) f.cooldown = { start, duration } end
        end
        frames[#frames + 1] = f
        return f
    end

    local defaults = {
        enabled = true,
        consumablesWhere = "instance", consumablesMinutes = 2,
        onlyIfCarried = true, hideResting = true,
        raidBuffs = false, raidBuffsOwn = true, iconSize = 36,
        buffsFont = "", buffsFontSize = 14, buffsOutline = "OUTLINE",
        raidBuffPicks = { intellect = true, stamina = true, spirit = true, wild = true, blessing = false },
        personalBuffs = true, personalBuffPicks = {},
    }
    local S = {}
    function S.Get(k)
        if settings[k] == nil then return defaults[k] end
        return settings[k]
    end
    function S.Set(k, v) settings[k] = v end
    function S.Raw(k) return settings[k] end
    function S.Default(k) return defaults[k] end

    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"),
        AuraBuffSettings = S,
        Apply = function() end,
        ShowUnlockMode = function() end,
        HideUnlockMode = function() end,
        Border = function() end, THEME = { bg = {} },
        Solid = function() return Recorder() end,
        Font = function()
            local fs = Recorder()
            function fs:SetText(v) fs.text = v end
            return fs
        end,
        UI = { AttachMover = function() return NewFrame() end, ModuleSettings = function() return S end },
        Shared = { Style = dofile("Tools/regression/shared_style.lua"), Parts = { HUD_OUTLINES = { { NONE = "None", [""] = "Shadow", OUTLINE = "Outline" }, { "NONE", "", "OUTLINE" } },
            HudFont = function(fs, font, size, outline) fs.font, fs.size, fs.outline = font, size, outline end } },
    }

    local function Count(id)
        local n = 0
        for _, b in ipairs(state.bags) do if b == id then n = n + 1 end end
        return n
    end
    local function Roster()
        local list = {}
        for unit in pairs(state.units) do list[#list + 1] = unit end
        return list
    end
    local env = {
        NUM_BAG_SLOTS = 0,
        UIParent = {},
        GetTime = function() return state.now end,
        InCombatLockdown = function() return state.combat end,
        IsResting = function() return state.resting end,
        IsInInstance = function() return state.instance ~= "none", state.instance end,
        IsInRaid = function() return state.group == "raid" end,
        GetNumGroupMembers = function() return state.group and #Roster() or 0 end,
        UnitClass = function(unit) return "x", state.units[unit] end,
        UnitIsConnected = function() return true end,
        UnitIsDeadOrGhost = function() return false end,
        UnitIsVisible = function() return true end,
        UnitIsUnit = function(a, b) return a == b end,
        UnitExists = function(unit) return unit ~= "target" or state.target ~= nil end,
        UnitCanAttack = function() return true end,
        UnitClassification = function() return state.target end,
        GetInventoryItemID = function(_, slot) return state.weapons[slot] ~= nil and 1000 + slot or nil end,
        GetWeaponEnchantInfo = function()
            local mh, oh = state.weapons[16], state.weapons[17]
            return mh and true or false, mh and mh * 1000 or 0, 0, 0, oh and true or false, oh and oh * 1000 or 0
        end,
        C_Secrets = { ShouldAurasBeSecret = function() return state.secret end },
        issecretvalue = function(v) return v == SECRET end,
        C_UnitAuras = {
            GetAuraDataByIndex = function(unit, i)
                if state.secret then error("Auras cannot be accessed when secret while tainted") end
                state.reads = state.reads + 1
                local a = (state.auras[unit] or {})[i]
                if not a then return nil end
                return { spellId = a[1], name = SPELL_NAMES[a[1]], duration = a[3] or 0,
                    expirationTime = a[2] and 1000 + a[2] or 0 }
            end,
        },
        C_Container = {
            GetContainerNumSlots = function() return #state.bags end,
            GetContainerItemID = function(_, slot) return state.bags[slot] end,
        },
        C_Item = {
            GetItemCount = Count,
            GetItemIconByID = function(id) return "item:" .. id end,
            GetItemSpell = function(id)
                local spell = state.itemSpells[id] or ITEM_SPELLS[id]
                if spell then return "spell", spell end
            end,
            RequestLoadItemDataByID = function(id) state.requested[id] = true end,
        },
        C_Spell = {
            GetSpellTexture = function(id) return "spell:" .. id end,
            GetSpellName = function(id) return SPELL_NAMES[id] end,
        },
        C_SpellBook = { IsSpellKnown = function(id) return state.known[id] == true end },
        C_Timer = {
            After = function(delay, fn) timers[#timers + 1] = { at = state.now + delay, fn = fn } end,
            NewTimer = function(delay, fn)
                local t = { at = state.now + delay, fn = fn }
                function t:Cancel() self.cancelled = true end
                timers[#timers + 1] = t
                return t
            end,
        },
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        MAX_PARTY_MEMBERS = 4, MAX_RAID_MEMBERS = 40,
        CreateFrame = function(_, _, _, template) return NewFrame(template) end,
        hooksecurefunc = function(tbl, key, fn)
            local orig = tbl[key]
            tbl[key] = function(...) orig(...); fn(...) end
        end,
    }
    env._G = { NaowhForever = ns }
    setmetatable(env, { __index = _G })
    local sources = {}
    if opts.page then sources[1] = SETTINGS end
    for _, source in ipairs(MODULE) do sources[#sources + 1] = source end
    if opts.page then sources[#sources + 1] = CARD end
    for _, source in ipairs(sources) do
        local chunk
        if setfenv then
            chunk = assert(loadstring(source)); setfenv(chunk, env)
        else
            chunk = assert(load(source, "module", "t", env))
        end
        chunk()
    end

    local t = { state = state, frames = frames, ns = ns }
    function t.Fire(event, ...)
        for _, f in ipairs(frames) do
            if f.events[event] and f.handler then f.handler(f, event, ...) end
        end
    end
    -- Runs every timer due within `seconds`, in order, including ones they add.
    function t.Advance(seconds)
        local stop = state.now + seconds
        while true do
            table.sort(timers, function(a, b) return a.at < b.at end)
            local nextTimer = timers[1]
            if not nextTimer or nextTimer.at > stop then break end
            table.remove(timers, 1)
            state.now = nextTimer.at
            if not nextTimer.cancelled then nextTimer.fn() end
        end
        state.now = stop
    end
    function t.Pending()
        local n = 0
        for _, timer in ipairs(timers) do if not timer.cancelled then n = n + 1 end end
        return n
    end
    function t.Set(k, v) S.Set(k, v) end
    function t.Login() t.Fire("PLAYER_LOGIN") end
    -- The textures of the visible reminder icons, left to right, with counts and timers.
    function t.Shown()
        local root
        for _, f in ipairs(frames) do if rawget(f, "mover") then root = f end end
        if not (root and root.shown) then return "" end
        local out = {}
        for _, f in ipairs(frames) do
            if rawget(f, "icon") and rawget(f, "count") and f.shown then
                local s = f.icon.texture
                if rawget(f.count, "text") and f.count.text ~= "" then s = s .. "x" .. f.count.text end
                if rawget(f.timer, "shown") then s = s .. "(t)" end
                out[#out + 1] = s
            end
        end
        return table.concat(out, " ")
    end
    function t.Listening(event)
        for _, f in ipairs(frames) do if f.events[event] and f.handler then return true end end
        return false
    end
    return t
end

local failures = 0
local function Check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(("FAIL %s\n  got:  %s\n  want: %s"):format(label, tostring(got), tostring(want)))
    end
end

-- In a dungeon with buff food, a flask and an elixir carried and nothing up.
do
    local t = Fixture({ instance = "party", bags = { 2679, 13931, 13510, 13454 } })
    t.Login()
    Check("carried consumables", t.Shown(), "item:13931 item:13510 item:13454")
    t.state.auras.player = { { 1249513 }, { 1249520, 1800, 3600 }, { 17626, 7000, 7200 }, { 17539, 3000, 3600 } }
    t.Fire("UNIT_AURA", "player")
    t.Advance(0.5)
    Check("all up", t.Shown(), "")
end

-- The count keeps today's outlined Addon Font at 14 until Font, Font Size or Outline change it.
do
    local t = Fixture({ instance = "party", bags = { 13931 } })
    t.Login()
    local count
    for _, f in ipairs(t.frames) do
        if rawget(f, "count") and f.shown then count = f.count end
    end
    Check("count font by default", count and (count.font .. count.size .. count.outline), "14OUTLINE")
    t.Set("buffsFont", "Naowh")
    t.Set("buffsFontSize", 18)
    t.Set("buffsOutline", "")
    Check("count font set", count.font .. count.size .. count.outline, "Naowh18")
end

-- Show In: Dungeons & Raids keeps them out of the open world; Everywhere does not.
do
    local t = Fixture({ bags = { 13931, 13510 } })
    t.Login()
    Check("open world, dungeons only", t.Shown(), "")
    t.Set("consumablesWhere", "always")
    Check("everywhere", t.Shown(), "item:13931 item:13510")
    t.Set("consumablesWhere", "raid")
    t.state.instance = "party"
    t.Fire("PLAYER_ENTERING_WORLD")
    t.Advance(0.5)
    Check("raids only, in a dungeon", t.Shown(), "")
    t.state.instance = "raid"
    t.Fire("PLAYER_ENTERING_WORLD")
    t.Advance(0.5)
    Check("raids only, in a raid", t.Shown(), "item:13931 item:13510")
    t.state.resting = true
    t.Fire("PLAYER_UPDATE_RESTING")
    t.Advance(0.5)
    Check("hidden while resting", t.Shown(), "")
end

-- Only If I Carry One: nothing carried shows nothing; off, a generic icon per kind.
do
    local t = Fixture({ instance = "raid", bags = { 2679 } })
    t.Login()
    Check("nothing carried", t.Shown(), "")
    t.Set("onlyIfCarried", false)
    Check("not carried, shown anyway", t.Shown(), "item:13931 item:13510 item:13454")
end

-- Battle and guardian elixirs remain separate, even while one category is active.
do
    local t = Fixture({ instance = "raid", settings = { consumableEntries = {
        { category = "battle", itemID = 13454, auras = { 17539 } },
        { category = "guardian", itemID = 13452, auras = { 17538 } },
    } }, bags = { 13452, 13454 }, auras = { player = { { 17539, 3000, 3600 } } } })
    t.Login()
    Check("guardian missing, battle up", t.Shown(), "item:13452")
end

-- Item IDs alone: food counts any Well Fed, other items their use spell once the item is cached.
do
    local t = Fixture({ instance = "raid", bags = { 13931, 13510, 13454 }, itemSpells = { [13510] = 17626 },
        settings = { consumableEntries = {
            { category = "food", itemID = 13931 },
            { category = "flask", itemID = 13510 },
            { category = "battle", itemID = 13454 },
        } }, auras = { player = { { 1243969, 600, 900 }, { 17626, 7000, 7200 } } } })
    t.Login()
    Check("XP boost alone is not Well Fed; uncached elixir shows", t.Shown(), "item:13931 item:13454")
    Check("uncached elixir requested", t.state.requested[13454], true)
    t.state.auras.player = { { 1248406, 600, 900 }, { 17626, 7000, 7200 }, { 17539, 3000, 3600 } }
    t.state.itemSpells[13454] = 17539
    local before = t.Pending()
    t.Fire("ITEM_DATA_LOAD_RESULT", 2589)
    Check("another item loading queues nothing", t.Pending(), before)
    t.Fire("ITEM_DATA_LOAD_RESULT", 13454)
    t.Advance(0.5)
    Check("Well Fed, flask and loaded elixir up", t.Shown(), "")
end

-- An item with no use spell is asked for once, so its load result cannot refresh forever.
do
    local t = Fixture({ instance = "raid", bags = { 6948 }, settings = { consumableEntries = {
        { category = "flask", itemID = 6948 } } } })
    t.Login()
    t.state.requested[6948] = nil
    t.Fire("ITEM_DATA_LOAD_RESULT", 6948)
    t.Advance(0.5)
    Check("no use spell: not asked again after it loads", t.state.requested[6948], nil)
    t.Fire("ITEM_DATA_LOAD_RESULT", 6948)
    t.Advance(0.5)
    Check("no use spell: a second load result asks nothing more", t.state.requested[6948], nil)
end

-- Warn With Minutes Left: a buff under the time shows with its timer; one over it is
-- woken up when it crosses.
do
    local t = Fixture({ instance = "raid", settings = {},
        bags = { 13931 }, auras = { player = { { 1249520, 60, 900 } } } })
    t.Login()
    Check("under two minutes", t.Shown(), "item:13931(t)")
    t.state.auras.player = { { 1249520, 300, 900 } }
    t.Fire("UNIT_AURA", "player")
    t.Advance(0.5)
    Check("five minutes left", t.Shown(), "")
    t.Advance(185)
    Check("woken at two minutes", t.Shown(), "item:13931(t)")
    t.Set("consumablesMinutes", 0)
    Check("0 waits until it is gone", t.Shown(), "")
end

-- Aura bursts keep one wake timer, not one per refresh; in combat they queue nothing.
do
    local t = Fixture({ instance = "raid", settings = {},
        bags = { 13931 }, auras = { player = { { 1249520, 300, 900 } } } })
    t.Login()
    for _ = 1, 50 do
        t.Fire("UNIT_AURA", "player")
        t.Advance(0.5)
    end
    Check("bursts leave one wake timer", t.Pending(), 1)
    t.Advance(185)
    Check("the kept timer still wakes", t.Shown(), "item:13931(t)")
    t.state.combat = true
    t.Fire("UNIT_AURA", "player")
    t.Fire("UNIT_AURA", "raid3")
    Check("combat aura events queue nothing", t.Pending(), 0)
    t.Fire("UNIT_AURA", "nameplate4")
    t.state.combat = false
    t.Fire("UNIT_AURA", "nameplate4")
    t.Fire("UNIT_AURA", "partypet1")
    Check("non-member units queue nothing", t.Pending(), 0)
end

-- Frozen while auras are secret or in combat: no read, the icons keep what they showed.
do
    local t = Fixture({ instance = "raid", settings = {},
        bags = { 13931 } })
    t.Login()
    Check("before the pull", t.Shown(), "item:13931")
    t.state.secret = true
    t.state.auras.player = { { 1249520, 900, 900 } }
    local reads = t.state.reads
    t.Fire("UNIT_AURA", "player")
    t.Fire("UNIT_AURA", SECRET)
    t.Advance(0.5)
    Check("secret: no aura read", t.state.reads, reads)
    Check("secret: frozen", t.Shown(), "item:13931")
    t.state.secret = false
    t.state.combat = true
    t.Fire("BAG_UPDATE_DELAYED")
    t.Advance(0.5)
    Check("combat: no aura read", t.state.reads, reads)
    Check("combat: frozen", t.Shown(), "item:13931")
    t.state.combat = false
    t.Fire("PLAYER_REGEN_ENABLED")
    t.Advance(0.5)
    Check("after combat", t.Shown(), "")
end

-- An empty profile never invents reminders from items in bags.
do
    local t = Fixture({ settings = { consumableEntries = {}, personalBuffs = false }, instance = "raid",
        bags = { 13931, 13510, 13454, 10306 } })
    t.Login()
    Check("empty profile has no automatic reminders", t.Shown(), "")
    Check("empty profile has no aura listener", t.Listening("UNIT_AURA"), false)
    t.Set("consumableEntries", { { category = "scroll", itemID = 10306, auras = { 12176 } } })
    Check("manual scroll added", t.Shown(), "item:10306")
    t.state.auras.player = { { 12176, 1000, 1800 } }
    t.Fire("UNIT_AURA", "player"); t.Advance(0.5)
    Check("manual scroll buff suppresses reminder", t.Shown(), "")
    t.Set("consumableEntries", {})
    Check("removed configuration stays empty", t.Shown(), "")
end

-- Raid buffs: how many are missing each buff you can cast, or any class in the group can.
do
    local t = Fixture({ settings = { raidBuffs = true },
        group = "party", units = { player = "MAGE", party1 = "WARRIOR", party2 = "PRIEST" },
        known = { [1460] = true },
        auras = { player = {}, party1 = {}, party2 = { { 10938, 3000, 3600 } } } })
    t.Login()
    Check("own: arcane intellect, the warrior skipped", t.Shown(), "spell:10157x2")
    t.Set("raidBuffsOwn", false)
    Check("any class: fortitude too, not divine spirit", t.Shown(), "spell:10157x2 spell:10938x2")
    t.state.auras.party1 = { { 21564, 3000, 3600 } }
    t.state.auras.player = { { 10938, 3000, 3600 }, { 23028, 3000, 3600 } }
    t.state.auras.party2 = { { 10938, 3000, 3600 }, { 10157, 3000, 3600 } }
    t.Fire("UNIT_AURA", "party1")
    t.Advance(0.5)
    Check("everyone buffed", t.Shown(), "")
end

-- Picked raid buffs: paladin blessings start off, the rest on; a buff switched off never reminds.
do
    local t = Fixture({ settings = { raidBuffs = true, raidBuffsOwn = false },
        group = "party", units = { player = "MAGE", party1 = "PALADIN", party2 = "PRIEST", party3 = "DRUID" },
        auras = { player = {}, party1 = {}, party2 = {}, party3 = {} } })
    t.Login()
    Check("default picks: no blessing", t.Shown(), "spell:10157x4 spell:10938x4 spell:9885x4")
    t.Set("raidBuffPicks", { intellect = true, stamina = false, spirit = true, wild = true, blessing = false })
    Check("fortitude switched off", t.Shown(), "spell:10157x4 spell:9885x4")
    t.Set("raidBuffPicks", { intellect = true, stamina = true, spirit = true, wild = true, blessing = true })
    Check("blessings switched on", t.Shown(), "spell:10157x4 spell:10938x4 spell:9885x4 spell:25291x4")
    t.Set("raidBuffPicks", { intellect = false })
    Check("a buff the picks do not name follows its class", t.Shown(), "spell:10938x4 spell:9885x4")
    t.state.known = { [1460] = true }
    t.Set("raidBuffsOwn", true)
    Check("own and not picked: nothing", t.Shown(), "")
end

-- The card has a switch per raid buff, each with its own changed dot and reset.
do
    local t = Fixture({ page = true })
    local Settings = t.ns.Shared.Settings
    local card = Settings.pages["AuraBuffs/Settings"].cards.buffs
    local picks = {}
    for _, row in ipairs(card.rows) do
        if row.field then picks[row.field] = row end
    end
    Check("blessings switch starts off", picks.blessing.get(), false)
    Check("fortitude switch starts on", picks.stamina.get(), true)
    picks.stamina.set(false)
    Check("switching one off keeps the rest", picks.blessing.get(), false)
    Check("only the switched row is changed", Settings.ChangedCount(card), 1)
    Check("its dot", Settings.Changed(picks.stamina), true)
    picks.blessing.set(true)
    Settings.ResetRow(picks.stamina)
    Check("row reset: back on", picks.stamina.get(), true)
    Check("row reset leaves the other", picks.blessing.get(), true)
    Settings.Reset(card)
    Check("card reset: blessings off again", picks.blessing.get(), false)
    Check("card reset: nothing changed", Settings.ChangedCount(card), 0)
end

-- Disabled means inactive; Unlock Mode shows a preview to drag.
do
    local t = Fixture({ settings = { enabled = false }, instance = "raid", bags = { 13931 } })
    t.Login()
    Check("disabled: nothing shown", t.Shown(), "")
    Check("disabled: no aura events", t.Listening("UNIT_AURA"), false)
    t.Set("enabled", true)
    Check("enabled: listening", t.Listening("UNIT_AURA"), true)
    Check("enabled: shown", t.Shown(), "item:13931")
end

-- Hover menus offer only carried configured alternatives as secure item buttons.
do
    local t = Fixture({ instance = "raid", bags = { 111, 222, 999 }, settings = { consumableEntries = {
        { category = "food", itemID = 111, auras = { 11 } },
        { category = "food", itemID = 222, auras = { 22 } },
        { category = "food", itemID = 333, auras = { 33 } },
    } } })
    t.Login()
    local cell
    for _, f in ipairs(t.frames) do if rawget(f, "items") then cell = f end end
    cell.scripts.OnEnter(cell)
    local popup
    for _, f in ipairs(t.frames) do if rawget(f, "owner") == cell then popup = f end end
    Check("only carried configured choices", #popup.buttons, 2)
    Check("menu buttons are secure", popup.buttons[1].template, "SecureActionButtonTemplate")
    Check("menu button uses its item", popup.buttons[2].attributes.item1, "item:222")
    Check("menu button action type", popup.buttons[2].attributes.type1, "item")
    t.state.bags = { 999, 111 }
    t.Fire("BAG_UPDATE_DELAYED")
    t.Advance(0.5)
    Check("refresh keeps the menu open", popup.shown, true)
    Check("refresh drops items no longer carried", popup.buttons[2].shown, false)
    popup.buttons[1].scripts.PostClick(popup.buttons[1])
    Check("using an item closes the menu", popup.shown, false)
    cell.scripts.OnEnter(cell)
    Check("open menu hangs under its cell", popup.anchor, cell)
    t.Fire("PLAYER_REGEN_DISABLED")
    Check("combat entry closes hover menu", popup.shown, false)
    Check("closed menu lets go of its cell, so the cell stays movable in combat", rawget(popup, "anchor"), nil)
    t.state.combat = true
    cell.scripts.OnEnter(cell)
    Check("no menu in combat", popup.shown, false)
end

-- Personal buffs: the best armor you know shows until any armor is up; resting and a pick hide it.
do
    local t = Fixture({ units = { player = "MAGE" }, known = { [168] = true, [7302] = true } })
    t.Login()
    Check("mage: ice armor missing", t.Shown(), "spell:7302")
    t.state.auras.player = { { 168, 1700, 1800 } }
    t.Fire("UNIT_AURA", "player")
    t.Advance(0.5)
    Check("frost armor counts", t.Shown(), "")
    t.state.auras.player = {}
    t.state.resting = true
    t.Fire("PLAYER_UPDATE_RESTING")
    t.Advance(0.5)
    Check("hidden while resting", t.Shown(), "")
    t.state.resting = false
    t.Set("personalBuffPicks", { mageArmor = false })
    Check("picked off", t.Shown(), "")
    t.Set("personalBuffPicks", {})
    t.Set("personalBuffs", false)
    Check("switched off", t.Shown(), "")
end

-- A talent buff only once it is known; buffs of another class never show.
do
    local t = Fixture({ units = { player = "PRIEST" }, known = { [588] = true, [168] = true } })
    t.Login()
    Check("priest without shadowform", t.Shown(), "spell:588")
    t.state.known[15473] = true
    t.Fire("SPELLS_CHANGED")
    t.Advance(0.5)
    Check("shadowform talented", t.Shown(), "spell:588 spell:15473")
end

-- Poisons: every equipped weapon needs one; an expiring poison wakes the row.
do
    local t = Fixture({ units = { player = "ROGUE" }, known = { [2842] = true }, weapons = { [16] = false } })
    t.Login()
    Check("no poison", t.Shown(), "spell:2842")
    Check("listens for weapon changes", t.Listening("UNIT_INVENTORY_CHANGED"), true)
    t.state.weapons[16] = 600
    t.Fire("UNIT_INVENTORY_CHANGED", "player")
    t.Advance(0.5)
    Check("poisoned main hand", t.Shown(), "")
    t.state.weapons[17] = false
    t.Fire("UNIT_INVENTORY_CHANGED", "player")
    t.Advance(0.5)
    Check("off hand unpoisoned", t.Shown(), "spell:2842")
    t.state.weapons[17] = 60
    t.Fire("UNIT_INVENTORY_CHANGED", "player")
    t.Advance(0.5)
    Check("off hand under Warn With Minutes Left", t.Shown(), "spell:2842")
    t.state.weapons[17] = 300
    t.Fire("UNIT_INVENTORY_CHANGED", "player")
    t.Advance(0.5)
    Check("both poisoned", t.Shown(), "")
    t.state.weapons[17] = 115
    t.Advance(185)
    Check("woken at two minutes left", t.Shown(), "spell:2842")
end

-- An enchant the game reports with no time left counts as up and arms no wake timer.
do
    local t = Fixture({ units = { player = "SHAMAN" }, known = { [8017] = true }, weapons = { [16] = 0 } })
    t.Login()
    Check("untimed imbue counts", t.Shown(), "")
    Check("untimed imbue arms nothing", t.Pending(), 0)
end

-- Warn With Minutes Left covers personal buffs, but not one shorter than the warning.
do
    local t = Fixture({ units = { player = "MAGE" }, known = { [168] = true },
        auras = { player = { { 168, 60, 1800 } } } })
    t.Login()
    Check("armor running out, with its timer", t.Shown(), "spell:168(t)")
    t.state.auras.player = { { 168, 300, 1800 } }
    t.Fire("UNIT_AURA", "player")
    t.Advance(0.5)
    Check("armor with time left", t.Shown(), "")
    t.Advance(185)
    Check("woken at two minutes left", t.Shown(), "spell:168(t)")
    local w = Fixture({ units = { player = "WARRIOR" }, known = { [6673] = true },
        auras = { player = { { 6673, 60, 120 } } } })
    w.Login()
    Check("two minute shout is not nagged early", w.Shown(), "")
end

-- A class with no personal buff: the default profile keeps the row off and the card shows no group.
do
    local t = Fixture({ page = true, settings = { consumableEntries = {} }, units = { player = "PALADIN" },
        known = { [19740] = true } })
    t.Login()
    Check("paladin default: no aura listener", t.Listening("UNIT_AURA"), false)
    local card = t.ns.Shared.Settings.pages["AuraBuffs/Settings"].cards.buffs
    local found
    for _, row in ipairs(card.rows) do
        if row.key == "personalBuffs" then found = true end
    end
    Check("paladin default: no personal buffs group", found, nil)
end

-- Hunter's Mark: only for a hostile elite target without the mark.
do
    local t = Fixture({ units = { player = "HUNTER" }, known = { [1130] = true, [19506] = true },
        auras = { player = { { 19506, 1700, 1800 } } } })
    t.Login()
    Check("no target", t.Shown(), "")
    Check("listens for target changes", t.Listening("PLAYER_TARGET_CHANGED"), true)
    t.state.target = "elite"
    t.Fire("PLAYER_TARGET_CHANGED")
    t.Advance(0.5)
    Check("elite unmarked", t.Shown(), "spell:1130")
    t.state.auras.target = { { 14323, 100, 120 } }
    t.Fire("UNIT_AURA", "target")
    t.Advance(0.5)
    Check("elite marked", t.Shown(), "")
    t.state.auras.target = {}
    t.state.target = "normal"
    t.Fire("PLAYER_TARGET_CHANGED")
    t.Advance(0.5)
    Check("normal target", t.Shown(), "")
    t.state.auras.player = {}
    t.Fire("UNIT_AURA", "player")
    t.Advance(0.5)
    Check("trueshot missing", t.Shown(), "spell:19506")
end

-- The card lists the personal buffs of the player's class only.
do
    local t = Fixture({ page = true, units = { player = "SHAMAN" } })
    local card = t.ns.Shared.Settings.pages["AuraBuffs/Settings"].cards.buffs
    local fields = {}
    for _, row in ipairs(card.rows) do
        if row.key == "personalBuffPicks" then fields[#fields + 1] = row.field end
    end
    Check("shaman picks", table.concat(fields, " "), "imbue shield")
    local shot = card.studio.new(t.ns.Shared.Settings)
    local function Preview(state)
        card.studio.paint(shot, state)
        local out = {}
        for _, cell in ipairs(shot.cells) do
            if cell.shown then out[#out + 1] = cell.icon.texture end
        end
        if shot.personal.shown then out[#out + 1] = "personal:" .. shot.personal.icon.texture end
        return table.concat(out, " ")
    end
    Check("preview in the world", Preview("world"), "personal:spell:16362")
    Check("preview resting", Preview("resting"), "")
end

if failures > 0 then
    print(failures .. " failure(s)")
    os.exit(1)
end
print("test-buff-reminders: all passed")

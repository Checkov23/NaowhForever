-- Loads the AuraBuffs Buffs & Consumables files and their data against stubbed aura, bag and group APIs
-- and checks which reminder icons show. Run from the repo root:
-- lua Tools/regression/test-buff-reminders.lua
-- Stands in for a secret value: any field or method use raises, as the client does.
rawset(_G, "C_AddOns", { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end })
local SECRET = setmetatable({}, { __index = function() error("attempt to index a secret value") end })
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local source = f:read("*a"); f:close()
    return source
end
local MODULE = {}
for i, path in ipairs({ "Core/Features.lua", "NaowhForever_Combat/AuraBuffs/AuraBuffs.lua",
    "NaowhForever_Combat/AuraBuffs/Constants.lua", "Shared/Game/Consumables.lua",
        "NaowhForever_Combat/AuraBuffs/Data/BuffReminders.lua", "NaowhForever_Combat/AuraBuffs/BuffReminders.lua",
    "NaowhForever_Combat/AuraBuffs/View/Style.lua", "NaowhForever_Combat/AuraBuffs/View/Glow.lua",
    "NaowhForever_Combat/AuraBuffs/View/BuffCell.lua",
    "NaowhForever_Combat/AuraBuffs/UI/BuffMenu.lua", "NaowhForever_Combat/AuraBuffs/UI/BuffReminders.lua" }) do
    MODULE[i] = Read(path)
end
local CARD = Read("NaowhForever_Combat/AuraBuffs/UI/GlowRows.lua") .. "\n" .. Read("NaowhForever_Combat/AuraBuffs/UI/BuffsCard.lua")
local SETTINGS = Read("Shared/Settings/Settings.lua")

-- itemID -> use spell, for the food scan.
local ITEM_SPELLS = { [13931] = 1249513, [2679] = 433, [21023] = 25660 }
local SPELL_NAMES = { [1248406] = "Well Fed", [1249520] = "Well Fed", [1243969] = "Well Fed XP Boost" }

-- Methods (capitalised) are no-ops; an unset field reads nil, as on a real frame.
local function Recorder(props)
    return setmetatable(props or {}, { __index = function(_, key)
        if key:find("^%u") then return function() end end
    end })
end

local function Fixture(opts)
    local settings = opts.settings or {}
    local state = {
        now = 1000, secret = false, combat = false, resting = false,
        instance = opts.instance or "none",
        bags = opts.bags or {},                     -- flat list of item IDs
        -- unit -> list of { spellID, seconds left at the start, duration, caster (default player) }
        auras = opts.auras or { player = {} },
        group = opts.group,                         -- nil solo, "party" or "raid"
        units = opts.units or {},                   -- unit -> class; player included
        known = opts.known or {},
        roles = opts.roles or {},                   -- unit -> its assigned group role
        mainTanks = opts.mainTanks or {},           -- unit -> true when flagged main tank
        shields = opts.shields or {},               -- slot -> true for a shield in that slot
        weapons = opts.weapons or {},               -- slot -> enchant seconds left, false for none
        worn = opts.worn or {},                     -- slot -> item ID worn there
        subclasses = opts.subclasses or {},         -- itemID -> its subclass
        classes = opts.classes or {},               -- itemID -> its class, when not a weapon
        instanceID = opts.instanceID,               -- GetInstanceInfo's instance ID
        target = opts.target,                       -- nil, or the target's classification
        itemSpells = opts.itemSpells or {},         -- itemID -> use spell, once the item is cached
        levels = opts.levels or {},                 -- itemID -> required level
        icons = opts.icons or {},                   -- itemID -> its icon, once the item is cached
        level = 60,
        slotReads = 0,
        requested = {},
        glows = {},
        presses = {},
        reads = 0,
        ranges = opts.ranges or {}, rangeReads = 0, tickers = {}, rangePaints = 0,
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
        function f:SetPoint(point, relativeTo, relativePoint, x, y)
            f.anchor, f.point, f.relativePoint, f.x, f.y = relativeTo, point, relativePoint, x, y
        end
        function f:ClearAllPoints() f.anchor = nil end
        function f:SetSize(w, h) f.width, f.height = w, h end
        function f:GetBottom() return rawget(f, "bottom") or 500 end
        function f:GetEffectiveScale() return 1 end
        function f:CreateTexture()
            local t = Recorder()
            function t:SetTexture(tex) t.texture = tex end
            function t:SetAlpha(alpha) t.alpha = alpha; state.rangePaints = state.rangePaints + 1 end
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
        consumablesWorld = false, consumablesDungeon = true, consumablesRaid = true, consumablesMinutes = 2,
        onlyIfCarried = true, carriedPicks = {}, hideResting = true,
        raidBuffsWorld = true, raidBuffsDungeon = true, raidBuffsRaid = true,
        personalBuffsWorld = true, personalBuffsDungeon = true, personalBuffsRaid = true,
        consumablesMaxHide = false, raidBuffsMaxHide = false, personalBuffsMaxHide = false,
        raidBuffs = false, raidBuffsOwn = true, raidBuffRange = false, iconSize = 36, buffIconMode = "default",
        buffsFont = "", buffsFontSize = 14, buffsOutline = "OUTLINE",
        raidBuffPicks = { intellect = true, stamina = true, spirit = true, wild = true, blessing = false },
        personalBuffs = true, personalBuffPicks = {}, weaponEnhancements = false,
        buffGlow = false, buffGlowType = "standard", buffGlowColor = { r = 1, g = 0.82, b = 0.2 },
        buffGlowLines = 8, buffGlowThickness = 2, buffGlowSpeed = 5,
    }
    local S = {}
    function S.Get(k)
        if settings[k] == nil then return defaults[k] end
        return settings[k]
    end
    function S.Set(k, v) settings[k] = v end
    function S.Raw(k) return settings[k] end
    function S.DB() return settings end
    function S.Default(k) return defaults[k] end

    local account = {}
    local ns = { AccountSettings = function() return account end, L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"),
        AuraBuffSettings = S,
        OnePixel = function() return opts.pixel or 1 end,
        Apply = function() end,
        ShowUnlockMode = function() end,
        HideUnlockMode = function() end,
        Border = function(frame, color)
            rawset(frame, "edge", color)
            return { SetColor = function(_, r, g, b) rawset(frame, "edge", { r = r, g = g, b = b }) end }
        end, THEME = { bg = {} },
        ThemeTint = function(key, literal) return key == "line" and opts.themeLine or literal end,
        Solid = function() return Recorder() end,
        Font = function()
            local fs = Recorder()
            function fs:SetText(v) fs.text = v end
            function fs:SetFormattedText(format, ...)
                fs.text = format:format(...)
                state.rangePaints = state.rangePaints + 1
            end
            return fs
        end,
        UI = { AttachMover = function() return NewFrame() end, ModuleSettings = function() return S end },
        Shared = { Style = dofile("Tools/regression/shared_style.lua"),
            ItemBar = { SetItem = function(button, itemID)
                button.itemID, button.weaponSlot = itemID, nil
                button:SetAttribute("type1", itemID and "item" or nil)
                button:SetAttribute("item1", itemID and ("item:" .. itemID) or nil)
                button:SetAttribute("macrotext1", nil)
            end, SetWeapon = function(button, itemID, slot)
                button.itemID, button.weaponSlot = itemID, slot
                button:SetAttribute("type1", "macro")
                button:SetAttribute("item1", nil)
                button:SetAttribute("macrotext1", "/use item:" .. itemID .. "\n/use " .. slot)
            end },
            Parts = { HUD_OUTLINES = { { NONE = "None", [""] = "Shadow", OUTLINE = "Outline" }, { "NONE", "", "OUTLINE" } },
            Press = function(button) rawset(button, "pressLook", true) end,
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
        LibStub = function()
            return {
                PixelGlow_Start = function(frame, _, _, _, _, _, _, _, _, key)
                    if key then state.presses[frame] = key else state.glows[frame] = "pixel" end
                end,
                PixelGlow_Stop = function(frame, key)
                    if key then state.presses[frame] = nil else state.glows[frame] = nil end
                end,
                ButtonGlow_Start = function(frame) state.glows[frame] = "standard" end,
                ButtonGlow_Stop = function(frame) state.glows[frame] = nil end }
        end,
        RAID_CLASS_COLORS = setmetatable({}, { __index = function(colors, class)
            local color = { r = 0.5, g = 0.5, b = 0.5 }
            function color.WrapTextInColorCode(_, text) return "|c" .. class .. "|" .. text end
            colors[class] = color
            return color
        end }),
        LOCALIZED_CLASS_NAMES_MALE = setmetatable({}, { __index = function(_, class) return class:lower() end }),
        Enum = { ItemClass = { Weapon = 2 } },
        GetTime = function() return state.now end,
        InCombatLockdown = function() return state.combat end,
        IsResting = function() return state.resting end,
        IsInInstance = function() return state.instance ~= "none", state.instance end,
        IsInRaid = function() return state.group == "raid" end,
        GetNumGroupMembers = function() return state.group and #Roster() or 0 end,
        UnitClass = function(unit) return "x", state.units[unit] end,
        UnitLevel = function() return state.level end,
        UnitIsConnected = function() return true end,
        UnitIsDeadOrGhost = function() return false end,
        UnitGroupRolesAssigned = function(unit) return state.roles[unit] or "NONE" end,
        GetPartyAssignment = function(_, unit) return state.mainTanks[unit] end,
        UnitIsVisible = function() return true end,
        UnitIsUnit = function(a, b) return a == b end,
        UnitExists = function(unit) return unit ~= "target" or state.target ~= nil end,
        UnitCanAttack = function() return true end,
        UnitClassification = function() return state.target end,
        GetInventoryItemID = function(_, slot)
            if state.worn[slot] then return state.worn[slot] end
            return state.weapons[slot] ~= nil and 1000 + slot or nil
        end,
        GetInstanceInfo = function() return "x", state.instance, nil, nil, nil, nil, nil, state.instanceID end,
        C_Secrets = { ShouldAurasBeSecret = function() return state.secret end },
        issecretvalue = function(v) return v == SECRET end,
        C_UnitAuras = {
            GetAuraDataByIndex = function(unit, i)
                if state.secret then error("Auras cannot be accessed when secret while tainted") end
                state.reads = state.reads + 1
                local a = (state.auras[unit] or {})[i]
                if not a then return nil end
                return { spellId = a[1], name = SPELL_NAMES[a[1]], duration = a[3] or 0,
                    expirationTime = a[2] and 1000 + a[2] or 0, sourceUnit = a[4] or "player" }
            end,
        },
        C_Container = {
            GetContainerNumSlots = function() return #state.bags end,
            GetContainerItemID = function(_, slot)
                state.slotReads = state.slotReads + 1
                return state.bags[slot]
            end,
        },
        C_Item = {
            GetItemCount = Count,
            GetItemIconByID = function(id) return "item:" .. id end,
            GetItemSpell = function(id)
                local spell = state.itemSpells[id] or ITEM_SPELLS[id]
                if spell then return "spell", spell end
            end,
            RequestLoadItemDataByID = function(id) state.requested[id] = true end,
            GetItemInfo = function(id)
                return "item", nil, nil, nil, state.levels[id], nil, nil, nil, nil, state.icons[id]
            end,
            GetWeaponEnchantInfo = function(weaponSlot)
                local left = state.weapons[weaponSlot == 0 and 16 or 17]
                return { { hasEnchant = false, timeLeft = 0 },
                    { hasEnchant = left and true or false, timeLeft = left and left * 1000 or 0 } }
            end,
            GetItemInfoInstant = function(id)
                local class = state.classes[id] or state.shields[id - 1000] and 4 or 2
                return id, nil, nil, nil, nil, class, state.subclasses[id]
            end,
        },
        C_Spell = {
            GetSpellTexture = function(id) return "spell:" .. id end,
            GetSpellName = function(id) return SPELL_NAMES[id] end,
            IsSpellInRange = function(id, unit)
                state.rangeReads = state.rangeReads + 1
                state.rangeSpell = id
                return state.ranges[unit]
            end,
        },
        C_SpellBook = { IsSpellKnown = function(id) return state.known[id] == true end },
        C_Timer = {
            NewTicker = function(delay, fn)
                local ticker = { at = state.now + delay, fn = fn, interval = delay }
                function ticker:Cancel() self.cancelled = true end
                timers[#timers + 1] = ticker
                state.tickers[#state.tickers + 1] = ticker
                return ticker
            end,
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
            if nextTimer.interval and not nextTimer.cancelled then
                nextTimer.at = state.now + nextTimer.interval
                timers[#timers + 1] = nextTimer
            end
        end
        state.now = stop
    end
    function t.Pending()
        local n = 0
        for _, timer in ipairs(timers) do if not timer.cancelled then n = n + 1 end end
        return n
    end
    t.env = env
    function t.Set(k, v) S.Set(k, v) end
    function t.Get(k) return S.Get(k) end
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

local ICONS = "Interface\\Icons\\"
local ROUGH = ICONS .. "inv_stone_sharpeningstone_01"

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

-- Glow: off by default, then a Standard or Pixel glow on each shown reminder, gone when they are.
do
    local t = Fixture({ instance = "raid", bags = { 13931, 13510 } })
    local function Glowing()
        local out = {}
        for frame, kind in pairs(t.state.glows) do
            if frame.shown then out[#out + 1] = kind end
        end
        table.sort(out)
        return table.concat(out, " ")
    end
    t.Login()
    Check("no glow by default", Glowing(), "")
    t.Set("buffGlow", true)
    Check("Standard Glow on each reminder", Glowing(), "standard standard")
    t.Set("buffGlowType", "pixel")
    Check("Pixel Glow instead", Glowing(), "pixel pixel")
    t.Set("buffGlow", false)
    Check("Glow off stops them", Glowing(), "")
end

-- Where to show: consumables stay out of the world by default; each place is its own switch.
do
    local t = Fixture({ bags = { 13931, 13510 } })
    t.Login()
    Check("open world, off by default", t.Shown(), "")
    t.Set("consumablesWorld", true)
    Check("shown in the world", t.Shown(), "item:13931 item:13510")
    t.state.instance = "pvp"
    t.Fire("PLAYER_ENTERING_WORLD")
    t.Advance(0.5)
    Check("a battleground counts as the world", t.Shown(), "item:13931 item:13510")
    t.Set("consumablesDungeon", false)
    t.state.instance = "party"
    t.Fire("PLAYER_ENTERING_WORLD")
    t.Advance(0.5)
    Check("dungeons off, in a dungeon", t.Shown(), "")
    t.state.instance = "raid"
    t.Fire("PLAYER_ENTERING_WORLD")
    t.Advance(0.5)
    Check("raids on, in a raid", t.Shown(), "item:13931 item:13510")
    t.Set("consumablesRaid", false)
    Check("raids off, in a raid", t.Shown(), "")
    t.Set("consumablesRaid", true)
    t.state.resting = true
    t.Fire("PLAYER_UPDATE_RESTING")
    t.Advance(0.5)
    Check("hidden while resting", t.Shown(), "")
end

-- The old Show In choice becomes the three switches once, and is gone after.
do
    for _, case in ipairs({
        { "always", true, true, true }, { "instance", false, true, true }, { "raid", false, false, true },
    }) do
        local t = Fixture({ settings = { consumablesWhere = case[1] } })
        t.Login()
        Check(case[1] .. " moved", tostring(t.Get("consumablesWorld")) .. tostring(t.Get("consumablesDungeon"))
            .. tostring(t.Get("consumablesRaid")), tostring(case[2]) .. tostring(case[3]) .. tostring(case[4]))
        Check(case[1] .. " old key gone", t.Get("consumablesWhere"), nil)
        t.Set("consumablesWorld", not case[2])
        t.ns.Apply()
        Check(case[1] .. " a later change kept", t.Get("consumablesWorld"), not case[2])
    end
end

-- Raid and personal buff reminders each have their own places to show.
do
    local t = Fixture({ settings = { raidBuffs = true },
        group = "party", units = { player = "MAGE", party1 = "WARRIOR", party2 = "PRIEST" },
        known = { [1460] = true, [7302] = true },
        auras = { player = {}, party1 = {}, party2 = {} } })
    t.Login()
    Check("both shown in the world", t.Shown(), "spell:7302 spell:10157x2")
    t.Set("raidBuffsWorld", false)
    Check("raid buffs off in the world", t.Shown(), "spell:7302")
    t.Set("personalBuffsWorld", false)
    Check("personal buffs off in the world", t.Shown(), "")
    t.Set("personalBuffsDungeon", false)
    t.state.instance = "party"
    t.Fire("PLAYER_ENTERING_WORLD")
    t.Advance(0.5)
    Check("in a dungeon, raid buffs only", t.Shown(), "spell:10157x2")
end

-- Hide in the World at Level 60: each kind can leave the world once you reach 60, and shows while levelling.
do
    local t = Fixture({ settings = { raidBuffs = true, consumablesWorld = true }, bags = { 13510 },
        group = "party", units = { player = "MAGE", party1 = "WARRIOR", party2 = "PRIEST" },
        known = { [1460] = true, [7302] = true },
        auras = { player = {}, party1 = {}, party2 = {} } })
    t.state.level = 59
    t.Login()
    Check("off: no level event", t.Listening("PLAYER_LEVEL_UP"), false)
    t.Set("consumablesMaxHide", true)
    t.Set("raidBuffsMaxHide", true)
    t.Set("personalBuffsMaxHide", true)
    Check("on: the level up is listened for", t.Listening("PLAYER_LEVEL_UP"), true)
    Check("levelling: all shown in the world", t.Shown(), "item:13510 spell:7302 spell:10157x2")
    t.Fire("PLAYER_LEVEL_UP", 60)
    t.Advance(0.5)
    Check("at 60, before the client's level catches up: none in the world", t.Shown(), "")
    t.state.level = 60
    t.Set("iconSize", 40)
    Check("at 60 the level event is no longer listened for", t.Listening("PLAYER_LEVEL_UP"), false)
    t.Set("raidBuffsMaxHide", false)
    Check("each kind on its own", t.Shown(), "spell:10157x2")
    t.state.instance = "pvp"
    t.Fire("PLAYER_ENTERING_WORLD")
    t.Advance(0.5)
    Check("at 60 in a battleground: the World switches as before", t.Shown(), "item:13510 spell:7302 spell:10157x2")
    t.state.instance = "raid"
    t.Fire("PLAYER_ENTERING_WORLD")
    t.Advance(0.5)
    Check("at 60 in a raid: shown as before", t.Shown(), "item:13510 spell:7302 spell:10157x2")
end

-- Only If I Carry One: nothing carried shows nothing; off, a generic icon per kind.
do
    local t = Fixture({ instance = "raid", bags = { 2679 } })
    t.Login()
    Check("nothing carried", t.Shown(), "")
    t.Set("onlyIfCarried", false)
    Check("not carried, shown anyway", t.Shown(), "spell:1248406 item:13510 item:13452")
end

-- Only If I Carry One, per kind: food can remind you with none carried while flasks and elixirs wait for one.
do
    local t = Fixture({ instance = "raid", bags = { 2679 } })
    t.Login()
    t.Set("carriedPicks", { food = false })
    Check("food not carried, shown alone", t.Shown(), "spell:1248406")
    Check("listening for the food eaten", t.Listening("UNIT_SPELLCAST_SUCCEEDED"), true)
    t.Set("onlyIfCarried", false)
    t.Set("carriedPicks", { food = true })
    Check("old switch off, food kept to carried", t.Shown(), "item:13510 item:13452")
    t.Set("carriedPicks", {})
    Check("unset kinds follow the old switch", t.Shown(), "spell:1248406 item:13510 item:13452")
end

-- A carried item shows its own icon once cached, and its load draws the row and the menu again.
do
    local t = Fixture({ instance = "raid", bags = { 13454 } })
    t.Login()
    Check("uncached: the icon the game has for its ID", t.Shown(), "item:13454")
    Check("and the item asked for", t.state.requested[13454], true)
    t.state.icons[13454] = "own:13454"
    t.Fire("ITEM_DATA_LOAD_RESULT", 13454)
    t.Advance(0.5)
    Check("loaded: its own icon", t.Shown(), "own:13454")
    local cell
    for _, f in ipairs(t.frames) do if rawget(f, "items") then cell = f end end
    cell.scripts.OnEnter(cell)
    local popup
    for _, f in ipairs(t.frames) do if rawget(f, "owner") == cell then popup = f end end
    Check("the menu shows the same icon", popup.buttons[1].icon.texture, "own:13454")
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

-- Only If I Carry One: a flask, elixir, scroll or buff food in your bags reminds you.
do
    local t = Fixture({ settings = { personalBuffs = false }, instance = "raid",
        bags = { 13510 } })
    t.Login()
    Check("empty profile, flask carried", t.Shown(), "item:13510")
    Check("empty profile listens for auras", t.Listening("UNIT_AURA"), true)
    t.state.bags = { 13510, 13931, 13454, 10306 }
    t.Fire("BAG_UPDATE_DELAYED"); t.Advance(0.5)
    Check("buff food, scroll and elixir too", t.Shown(), "item:13931 item:13510 item:10306 item:13454")
    t.state.auras.player = { { 17626, 7000, 7200 }, { 1249520, 1800, 3600 }, { 11334, 3000, 3600 } }
    t.Fire("UNIT_AURA", "player"); t.Advance(0.5)
    Check("any flask, Well Fed and elixir counts, the scroll still missing", t.Shown(), "item:10306")
end

-- Nothing carried: no reminder.
do
    local t = Fixture({ settings = { personalBuffs = false }, instance = "raid",
        bags = { 2679 } })
    t.Login()
    Check("empty profile, nothing carried", t.Shown(), "")
end

-- A carried scroll reminds one stat at a time, the class buff it does not stack with counts as
-- its buff, and a scroll you do not carry never reminds, with Only If I Carry One on or off.
do
    local t = Fixture({ settings = { personalBuffs = false }, instance = "raid",
        bags = { 1712 } })
    t.Login()
    Check("a carried Scroll of Spirit II reminds", t.Shown(), "item:1712")
    t.state.bags = { 1711, 1712 }
    t.state.auras.player = { { 8100, 1700, 1800 } }
    t.Fire("BAG_UPDATE_DELAYED"); t.Advance(0.5)
    Check("Stamina up, Spirit still reminds", t.Shown(), "item:1712")
    t.state.auras.player = { { 8100, 1700, 1800 }, { 27841, 1700, 1800 } }
    t.Fire("UNIT_AURA", "player"); t.Advance(0.5)
    Check("Divine Spirit counts for the Spirit scroll", t.Shown(), "")
    t.state.auras.player = { { 10938, 1700, 1800 } }
    t.Fire("UNIT_AURA", "player"); t.Advance(0.5)
    Check("Fortitude counts for Stamina, Spirit reminds", t.Shown(), "item:1712")
    t.Set("onlyIfCarried", false)
    t.state.bags = {}
    t.Fire("BAG_UPDATE_DELAYED"); t.Advance(0.5)
    Check("Only If I Carry One off: food, flask and elixir, no scroll", t.Shown(), "spell:1248406 item:13510 item:13452")
end

-- Of one stat's scrolls the highest level is offered, even when another stat's scroll is the best in the bags.
do
    local t = Fixture({ settings = { personalBuffs = false }, instance = "raid",
        bags = { 10307, 1181, 1712 }, levels = { [10307] = 55, [1181] = 1, [1712] = 15 },
        auras = { player = { { 12178, 1700, 1800 } } } })
    t.Login()
    Check("Stamina IV up, Spirit II offered over Spirit I", t.Shown(), "item:1712")
end

-- The built-in item offered is the highest level one you can use, with every carried one in its menu.
do
    local t = Fixture({ instance = "raid", bags = { 9187, 13452, 9264 }, levels = { [9187] = 38, [13452] = 46, [9264] = 40 },
        settings = { personalBuffs = false } })
    t.Login()
    Check("highest level elixir", t.Shown(), "item:13452")
    local cell
    for _, f in ipairs(t.frames) do if rawget(f, "items") and f.shown then cell = f end end
    Check("menu lists the carried elixirs, best first", table.concat(cell.items, " "), "13452 9187 9264")
    t.state.level = 40
    t.Fire("BAG_UPDATE_DELAYED"); t.Advance(0.5)
    Check("one too high for you is skipped", t.Shown(), "item:9264")
    t.ns.AccountSettings().lastIcons = { battle = "item:9187" }
    t.Set("buffIconMode", "last")
    Check("Last Used icon kept", t.Shown(), "item:9187")
end

-- Off is unchanged: a reminder per kind, carried or not.
do
    local t = Fixture({ instance = "raid", settings = { onlyIfCarried = false,
        personalBuffs = false } })
    t.Login()
    Check("off, nothing carried", t.Shown(), "spell:1248406 item:13510 item:13452")
end

-- Bags are read once per bag change, not on every refresh; combat and secret auras still freeze the row.
do
    local t = Fixture({ settings = { personalBuffs = false }, instance = "raid",
        bags = { 13510, 13931 } })
    t.Login()
    local reads = t.state.slotReads
    for _ = 1, 5 do
        t.Fire("UNIT_AURA", "player"); t.Advance(0.5)
    end
    Check("aura refreshes reuse the scan", t.state.slotReads, reads)
    t.state.combat = true
    t.state.bags = {}
    t.Fire("BAG_UPDATE_DELAYED"); t.Advance(0.5)
    Check("combat: frozen", t.Shown(), "item:13931 item:13510")
    t.state.combat = false
    t.state.secret = true
    t.Fire("PLAYER_REGEN_ENABLED"); t.Advance(0.5)
    Check("secret: frozen", t.Shown(), "item:13931 item:13510")
    t.state.secret = false
    t.Fire("PLAYER_REGEN_ENABLED"); t.Advance(0.5)
    Check("after combat, nothing carried", t.Shown(), "")
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

-- Middle-click hides that reminder until reload, on the click's up only, and holds in combat like the row.
do
    local t = Fixture({ instance = "raid", bags = { 13931, 13510 }, settings = { raidBuffs = true },
        group = "party", units = { player = "MAGE", party1 = "WARRIOR", party2 = "PRIEST" },
        known = { [1460] = true }, auras = { player = {}, party1 = {}, party2 = {} } })
    local function Cell(texture)
        for _, f in ipairs(t.frames) do
            if rawget(f, "icon") and f.shown and f.icon.texture == texture and rawget(f, "scripts").PostClick then
                return f
            end
        end
    end
    local function Middle(cell, down) cell.scripts.PostClick(cell, "MiddleButton", down); t.Advance(0.5) end
    t.Login()
    Check("food, flask and a raid buff", t.Shown(), "item:13931 item:13510 spell:10157x2")
    local food = Cell("item:13931")
    food.scripts.PostClick(food, "LeftButton", true)
    Check("a left click starts no glow", t.state.presses[food], nil)
    t.Advance(0.5)
    Middle(food, true)
    Check("a middle press alone hides nothing", t.Shown(), "item:13931 item:13510 spell:10157x2")
    Middle(food, false)
    Check("letting go hides that reminder", t.Shown(), "item:13510 spell:10157x2")
    Check("and glows nothing", next(t.state.presses), nil)
    t.Fire("BAG_UPDATE_DELAYED"); t.Advance(0.5)
    Check("it stays hidden on a refresh", t.Shown(), "item:13510 spell:10157x2")
    Middle(Cell("spell:10157"), false)
    Check("a raid buff hides the same way", t.Shown(), "item:13510")
    local flask = Cell("item:13510")
    t.state.combat = true
    Middle(flask, false)
    Check("in combat the row holds", t.Shown(), "item:13510")
    t.state.combat = false
    t.Fire("PLAYER_REGEN_ENABLED"); t.Advance(0.5)
    Check("and drops it once combat ends", t.Shown(), "")
end

-- Range follows the learned rank, treats unavailable results as out, and never rescans auras on a tick.
do
    local t = Fixture({ settings = { raidBuffs = true, personalBuffs = false }, group = "party",
        units = { player = "MAGE", party1 = "PRIEST", party2 = "DRUID" }, known = { [1460] = true },
        auras = { player = { { 1460 } } }, ranges = { party1 = true, party2 = false } })
    local function Icon()
        for _, frame in ipairs(t.frames) do if rawget(frame, "icon") and frame.shown then return frame.icon end end
    end
    t.Login()
    Check("range off: original missing count", t.Shown(), "spell:10157x2")
    Check("range off: no checks or ticker", t.state.rangeReads + #t.state.tickers, 0)
    t.Set("raidBuffRange", true)
    Check("range shows reachable over missing", t.Shown(), "spell:10157x1/2")
    Check("range checks the learned rank", t.state.rangeSpell, 1460)
    Check("reachable: full brightness", Icon().alpha, 1)
    local paints = t.state.rangePaints
    t.Advance(0.5)
    Check("unchanged range results do not repaint", t.state.rangePaints, paints)
    t.Fire("UNIT_AURA", "party1"); t.Advance(0.5)
    Check("a full refresh restores the ratio after placing the cell", t.Shown(), "spell:10157x1/2")
    local reads = t.state.reads
    t.state.ranges.party1 = nil
    t.Advance(0.5)
    Check("unknown range counts as unconfirmed", t.Shown(), "spell:10157x0/2")
    Check("unknown and out of range: dim", Icon().alpha, t.ns.AuraBuffs.Style.BUFF_RANGE_DIM)
    Check("range ticks do not scan buffs", t.state.reads, reads)
    t.state.ranges.party1, t.state.ranges.party2 = SECRET, true
    t.Advance(0.5)
    Check("secret range results are not compared", t.Shown(), "spell:10157x1/2")
    Check("returning to range brightens the icon", Icon().alpha, 1)
    local rangeReads = t.state.rangeReads
    t.state.secret = true
    t.Advance(0.5)
    Check("restricted transition freezes range checks", t.state.rangeReads, rangeReads)
    t.state.secret, t.state.combat = false, true
    t.Fire("PLAYER_REGEN_DISABLED")
    Check("combat cancels the range ticker", t.state.tickers[#t.state.tickers].cancelled, true)
    t.Advance(1)
    Check("combat performs no range reads", t.state.rangeReads, rangeReads)
    t.state.combat = false
    t.Fire("PLAYER_REGEN_ENABLED"); t.Advance(0.5)
    t.Set("raidBuffRange", false)
    Check("disabling range restores the original count", t.Shown(), "spell:10157x2")
    Check("disabling range cancels its ticker", t.state.tickers[#t.state.tickers].cancelled, true)
    Check("disabling range restores brightness", Icon().alpha, 1)
    t.Set("raidBuffRange", true)
    t.state.auras.party1, t.state.auras.party2 = { { 1460 } }, { { 1460 } }
    t.Fire("UNIT_AURA", "party1"); t.Advance(0.5)
    Check("buffing everyone removes the icon", t.Shown(), "")
    Check("no missing buffs leaves no running range ticker", t.state.tickers[#t.state.tickers].cancelled, true)
    t.state.auras.party1 = {}
    t.Fire("UNIT_AURA", "party1"); t.Advance(0.5)
    t.ns.ShowUnlockMode()
    Check("Unlock Mode cancels live range tracking", t.state.tickers[#t.state.tickers].cancelled, true)
    t.ns.HideUnlockMode()
    t.Set("enabled", false)
    Check("disabling reminders cancels range tracking", t.state.tickers[#t.state.tickers].cancelled, true)
    rangeReads = t.state.rangeReads
    t.Advance(1)
    Check("disabled reminders have no range checks", t.state.rangeReads, rangeReads)
end

-- Hide Out of Range drops a raid buff nobody missing it can be reached for, and brings it back in range.
do
    local t = Fixture({ settings = { raidBuffs = true, raidBuffRange = true, raidBuffRangeHide = true,
        personalBuffs = false }, group = "party", units = { player = "MAGE", party1 = "PRIEST" },
        known = { [1460] = true }, auras = { player = { { 1460 } } }, ranges = { party1 = false } })
    t.Login()
    Check("out of range: hidden", t.Shown(), "")
    Check("hidden buff keeps the range ticker", t.state.tickers[#t.state.tickers].cancelled, nil)
    local reads = t.state.reads
    t.Advance(1)
    Check("still out of range: no rescans", t.state.reads, reads)
    t.state.ranges.party1 = true
    t.Advance(1)
    Check("coming into range shows it", t.Shown(), "spell:10157x1/1")
    t.state.ranges.party1 = false
    t.Advance(1)
    Check("leaving range hides it again", t.Shown(), "")
    t.Set("raidBuffRangeHide", false)
    Check("hide off: dimmed instead", t.Shown(), "spell:10157x0/1")
    t.Set("raidBuffRangeHide", true)
    t.state.auras.player = {}
    t.Fire("UNIT_AURA", "player"); t.Advance(0.5)
    Check("missing on yourself is always in range", t.Shown(), "spell:10157x1/2")
    local other = Fixture({ settings = { raidBuffs = true, raidBuffRange = true, raidBuffRangeHide = true,
        raidBuffsOwn = false, personalBuffs = false }, group = "party", units = { player = "WARRIOR", party1 = "MAGE" } })
    other.Login()
    Check("uncastable buff is not hidden", other.Shown(), "spell:10157x0/1")
end

-- Self needs no moving-range ticker; a buff we cannot cast stays dim without a fake range result.
do
    local solo = Fixture({ settings = { raidBuffs = true, raidBuffRange = true, personalBuffs = false },
        units = { player = "MAGE" }, known = { [1460] = true } })
    solo.Login()
    Check("self is confirmed in range", solo.Shown(), "spell:10157x1/1")
    Check("self-only range requires no ticker", #solo.state.tickers, 0)
    local other = Fixture({ settings = { raidBuffs = true, raidBuffRange = true, raidBuffsOwn = false,
        personalBuffs = false }, group = "party", units = { player = "WARRIOR", party1 = "MAGE" } })
    other.Login()
    Check("uncastable buff has no confirmed recipients", other.Shown(), "spell:10157x0/1")
    Check("unknown spell range requires no repeated checks", other.state.rangeReads + #other.state.tickers, 0)
    for _, cell in ipairs(other.frames) do
        if rawget(cell, "icon") and cell.shown then
            Check("uncastable buff stays dim", cell.icon.alpha, other.ns.AuraBuffs.Style.BUFF_RANGE_DIM)
        end
    end
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

-- Salvation is its own raid buff, separate from the blessings, off until picked, and never asked of a tank.
do
    local t = Fixture({ settings = { raidBuffs = true, raidBuffsOwn = false },
        group = "party", units = { player = "MAGE", party1 = "PALADIN", party2 = "WARRIOR", party3 = "DRUID" },
        auras = { player = {}, party1 = {}, party2 = {}, party3 = {} } })
    t.Login()
    Check("salvation is off until picked", t.Shown(), "spell:10157x3 spell:9885x4")
    t.Set("raidBuffPicks", { intellect = false, stamina = false, spirit = false, wild = false, blessing = false,
        salvation = true })
    Check("salvation picked: everyone is missing it", t.Shown(), "spell:1038x4")
    t.state.roles.party2 = "TANK"
    t.Fire("UNIT_AURA", "party1"); t.Advance(0.5)
    Check("a tank is not asked to have it", t.Shown(), "spell:1038x3")
    t.state.roles.party2 = nil
    t.state.mainTanks.party2 = true
    t.Fire("UNIT_AURA", "party1"); t.Advance(0.5)
    Check("a player flagged main tank is not asked either", t.Shown(), "spell:1038x3")
    t.state.auras.party3 = { { 1038 } }
    t.Fire("UNIT_AURA", "party3"); t.Advance(0.5)
    Check("one who has it is not missing it", t.Shown(), "spell:1038x2")
    t.state.auras.party3 = { { 25895 } }
    t.Fire("UNIT_AURA", "party3"); t.Advance(0.5)
    Check("the Greater one counts too", t.Shown(), "spell:1038x2")
    t.Set("raidBuffPicks", { intellect = false, stamina = false, spirit = false, wild = false, blessing = true,
        salvation = false })
    Check("Salvation does not stand in for a blessing", t.Shown(), "spell:25291x4")
    t.state.auras.party3 = { { 19740 } }
    t.Fire("UNIT_AURA", "party3"); t.Advance(0.5)
    t.Set("raidBuffPicks", { intellect = false, stamina = false, spirit = false, wild = false, blessing = true,
        salvation = true })
    Check("and a blessing does not stand in for Salvation", t.Shown(), "spell:25291x3 spell:1038x3")
end

-- Grouped paladins can leave blessing reminders to their own tab without losing their saved picks.
do
    local picks = { intellect = true, stamina = false, spirit = false, wild = false, blessing = true, salvation = true }
    local t = Fixture({ settings = { raidBuffs = true, raidBuffsOwn = true, raidBuffPicks = picks },
        group = "party", units = { player = "PALADIN", party1 = "MAGE" },
        known = { [19740] = true, [1038] = true }, auras = { player = {}, party1 = {} } })
    t.Login()
    Check("paladin default: selected blessings remain shown", t.Shown(), "spell:25291x2 spell:1038x2")
    t.Set("hideBlessingsOnPaladin", true)
    Check("grouped paladin: both blessing reminders hide immediately", t.Shown(), "")
    Check("grouped paladin: preview hides the blessings too", t.ns.AuraBuffs.Buffs.RaidSample(), nil)
    Check("hiding keeps the blessing pick", t.Get("raidBuffPicks").blessing, true)
    Check("hiding keeps the Salvation pick", t.Get("raidBuffPicks").salvation, true)
    t.Set("hideBlessingsOnPaladin", false)
    Check("switch off: both reminders return", t.Shown(), "spell:25291x2 spell:1038x2")
    t.Set("hideBlessingsOnPaladin", true)
    t.state.group = nil
    t.Fire("GROUP_ROSTER_UPDATE"); t.Advance(0.5)
    Check("leaving the group restores solo reminders", t.Shown(), "spell:25291 spell:1038")
    t.state.group = "party"
    t.Fire("GROUP_ROSTER_UPDATE"); t.Advance(0.5)
    Check("joining the group hides them again", t.Shown(), "")
    t.state.units.player = "MAGE"
    t.state.units.party1 = "PALADIN"
    t.state.known = { [1460] = true }
    t.Set("raidBuffsOwn", false)
    Check("another class keeps all selected reminders", t.Shown(), "spell:10157x2 spell:25291x2 spell:1038x2")
    local p = Fixture({ page = true, units = { player = "PALADIN" } })
    local rows = p.ns.Shared.Settings.pages["AuraBuffs/Settings"].cards.buffs.rows
    local option
    for _, row in ipairs(rows) do if row.key == "hideBlessingsOnPaladin" then option = row end end
    Check("the option is available to paladins", option and not option.hidden(), true)
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
    t.state.combat = true
    t.ns.Apply()
    Check("disabled: a profile apply in combat waits for nothing", t.Listening("PLAYER_REGEN_ENABLED"), false)
    t.state.combat = false
    t.Set("enabled", true)
    Check("enabled: listening", t.Listening("UNIT_AURA"), true)
    Check("enabled: shown", t.Shown(), "item:13931")
end

-- The preview shows a raid buff only when it is one you track: no Arcane Intellect on a warrior.
do
    local SAMPLES = "spell:1248406 item:13510 item:13454 item:10306x2"
    local function Unlocked(t)
        t.ns.ShowUnlockMode()
        local shown = t.Shown()
        t.ns.HideUnlockMode()
        return shown
    end
    local w = Fixture({ page = true, units = { player = "WARRIOR" } })
    w.Login()
    Check("warrior, raid buffs off: consumables only", Unlocked(w), SAMPLES)
    w.Set("raidBuffs", true)
    Check("warrior, only buffs I can cast: no arcane intellect", Unlocked(w), SAMPLES)
    w.Set("raidBuffsOwn", false)
    Check("warrior, any class's buff: arcane intellect", Unlocked(w), SAMPLES .. " spell:10157x3")
    local card = w.ns.Shared.Settings.pages["AuraBuffs/Settings"].cards.buffs
    local shot = card.studio.new(w.ns.Shared.Settings)
    card.studio.paint(shot, "raid")
    Check("warrior card: arcane intellect", shot.cells[#shot.cells].icon.texture, "spell:10157")
    w.Set("raidBuffsOwn", true)
    card.studio.paint(shot, "raid")
    Check("warrior card, only buffs I can cast: no raid buff", shot.cells[#shot.cells].shown, false)
    local m = Fixture({ settings = { raidBuffs = true }, units = { player = "MAGE" }, known = { [1460] = true } })
    m.Login()
    Check("mage: arcane intellect", Unlocked(m), SAMPLES .. " spell:10157x3")
end

-- Hover menus offer only the carried items of a kind as secure item buttons.
do
    local t = Fixture({ instance = "raid", bags = { 13510, 13511, 999 } })
    t.Login()
    local cell
    for _, f in ipairs(t.frames) do if rawget(f, "items") then cell = f end end
    cell.scripts.OnEnter(cell)
    local popup
    for _, f in ipairs(t.frames) do if rawget(f, "owner") == cell then popup = f end end
    Check("only carried choices", #popup.buttons, 2)
    Check("menu buttons are secure", popup.buttons[1].template, "SecureActionButtonTemplate")
    Check("menu button uses its item", popup.buttons[2].attributes.item1, "item:13511")
    Check("menu button action type", popup.buttons[2].attributes.type1, "item")
    t.state.bags = { 999, 13510 }
    t.Fire("BAG_UPDATE_DELAYED")
    t.Advance(0.5)
    Check("refresh keeps the menu open", popup.shown, true)
    Check("refresh drops items no longer carried", popup.buttons[2].shown, false)
    Check("menu icons take the hover and pressed look", popup.buttons[1].pressLook, true)
    popup.buttons[1].scripts.PostClick(popup.buttons[1], "LeftButton", true)
    Check("pressing an item starts no glow", next(t.state.presses), nil)
    Check("the menu stays while the item is held", popup.shown, true)
    popup.buttons[1].scripts.PostClick(popup.buttons[1], "LeftButton", false)
    Check("letting go closes the menu", popup.shown, false)
    Check("menu icons keep the black edge by default", popup.buttons[1].edge.r, 0)
    Check("row icon is a secure button", cell.template, "SecureActionButtonTemplate")
    Check("row icon uses the item it shows", (cell.attributes.type1 or "") .. " " .. (cell.attributes.item1 or ""),
        "item item:13510")
    Check("row icons take the hover and pressed look", cell.pressLook, true)
    cell.scripts.PostClick(cell, "LeftButton", false)
    Check("a left click on a row icon runs nothing after the item", next(t.state.presses), nil)
    cell.scripts.OnEnter(cell)
    Check("open menu hangs under its cell", popup.anchor, cell)
    Check("menu sits centred under its cell", popup.point .. ">" .. popup.relativePoint, "TOP>BOTTOM")
    Check("menu icons are their own small size", popup.buttons[1].width .. "x" .. popup.buttons[1].height, "32x32")
    Check("one item sits in the middle", popup.buttons[1].point .. " " .. popup.buttons[1].x, "TOP 0")
    Check("menu fits one icon", popup.width .. "x" .. popup.height, "40x40")
    t.Set("iconSize", 96)
    cell.scripts.OnEnter(cell)
    Check("menu icons stay small with a big Icon Size", popup.buttons[1].width, 32)
    Check("and the menu with them", popup.width .. "x" .. popup.height, "40x40")
    cell.bottom = 30
    cell.scripts.OnEnter(cell)
    Check("no room under the cell: menu opens above it", popup.point .. ">" .. popup.relativePoint, "BOTTOM>TOP")
    cell.bottom = nil
    t.Set("iconSize", 36)
    t.Fire("PLAYER_REGEN_DISABLED")
    Check("combat entry closes hover menu", popup.shown, false)
    Check("closed menu lets go of its cell, so the cell stays movable in combat", rawget(popup, "anchor"), nil)
    t.state.combat = true
    cell.scripts.OnEnter(cell)
    Check("no menu in combat", popup.shown, false)
    t.state.bags = { 13511 }
    t.Fire("BAG_UPDATE_DELAYED")
    t.Advance(0.5)
    t.Set("iconSize", 50)
    Check("in combat the row's item stays", cell.attributes.item1, "item:13510")
    Check("in combat the row's size stays", cell.width, 36)
    t.state.combat = false
    t.Fire("PLAYER_REGEN_ENABLED")
    t.Advance(0.5)
    Check("after combat the row takes the carried item", cell.attributes.item1, "item:13511")
    Check("after combat the row takes its new size", cell.width, 50)
end

-- The row and menu icon edges follow the theme's Borders & Lines colour; Last Used uses the item it shows.
do
    local line = { r = 0.2, g = 0.4, b = 0.6 }
    local t = Fixture({ instance = "raid", bags = { 13510, 13511 }, themeLine = line,
        settings = { buffIconMode = "last" } })
    t.ns.AccountSettings().lastIcons = { flask = "item:13511" }
    t.Login()
    local cell
    for _, f in ipairs(t.frames) do if rawget(f, "items") then cell = f end end
    Check("Last Used shows the last flask", cell.icon.texture, "item:13511")
    Check("and clicking it drinks that one", cell.attributes.item1, "item:13511")
    Check("row icon edge follows Borders & Lines", cell.edge, line)
    cell.scripts.OnEnter(cell)
    local popup
    for _, f in ipairs(t.frames) do if rawget(f, "owner") == cell then popup = f end end
    Check("menu icon edge follows Borders & Lines", popup.buttons[1].edge, line)
    t.state.bags = { 13510 }
    t.Fire("BAG_UPDATE_DELAYED")
    t.Advance(0.5)
    Check("with the last flask gone the row shows the carried one", cell.icon.texture, "item:13510")
    Check("and clicking it drinks the one it shows", cell.attributes.item1, "item:13510")
end

-- A picked Border Color replaces the theme's on the row and menu icons, and clearing it brings the theme back.
do
    local line = { r = 0.2, g = 0.4, b = 0.6 }
    local t = Fixture({ instance = "raid", bags = { 13510 }, themeLine = line })
    t.Login()
    local cell
    for _, f in ipairs(t.frames) do if rawget(f, "items") then cell = f end end
    t.Set("buffsBorderColor", { r = 1, g = 0, b = 0 })
    t.Advance(0.5)
    local edge = cell.edge
    Check("picked row edge", edge.r .. edge.g .. edge.b, "100")
    cell.scripts.OnEnter(cell)
    local popup
    for _, f in ipairs(t.frames) do if rawget(f, "owner") == cell then popup = f end end
    edge = popup.buttons[1].edge
    Check("picked menu edge", edge.r .. edge.g .. edge.b, "100")
    t.Set("buffsBorderColor", false)
    t.Advance(0.5)
    Check("cleared row edge follows the theme", cell.edge.b, line.b)
end

-- A full menu spreads out from the middle, each line centred under the hovered icon.
do
    local bags = { 13452, 9187, 13453, 9206, 13454, 9155, 9264, 21546, 6373 }
    local t = Fixture({ instance = "raid", bags = bags })
    t.Login()
    local cell
    for _, f in ipairs(t.frames) do if rawget(f, "items") then cell = f end end
    cell.scripts.OnEnter(cell)
    local popup
    for _, f in ipairs(t.frames) do if rawget(f, "owner") == cell then popup = f end end
    local xs = {}
    for i = 1, 9 do xs[i] = popup.buttons[i].x .. "," .. popup.buttons[i].y end
    Check("full line centred, the ninth alone under it", table.concat(xs, " "),
        "-126,-4 -90,-4 -54,-4 -18,-4 18,-4 54,-4 90,-4 126,-4 0,-40")
    Check("menu fits eight across, two lines", popup.width .. "x" .. popup.height, "292x76")
end

-- At a UI scale where a pixel is not a whole unit, the menu's icons are a whole number of pixels,
-- a whole number of pixels from the hovered icon, so they draw as crisply as the row's do.
do
    local t = Fixture({ instance = "raid", bags = { 13452, 9187 }, pixel = 0.75, settings = { iconSize = 37 } })
    t.Login()
    local cell
    for _, f in ipairs(t.frames) do if rawget(f, "items") then cell = f end end
    cell.scripts.OnEnter(cell)
    local popup
    for _, f in ipairs(t.frames) do if rawget(f, "owner") == cell then popup = f end end
    local function Whole(v) return math.abs(v / 0.75 - math.floor(v / 0.75 + 0.5)) < 1e-9 end
    Check("the row icon is whole pixels", cell.width == 36.75 and Whole(cell.width), true)
    Check("the menu icons are whole pixels", popup.buttons[1].width .. "x" .. popup.buttons[2].height, "32.25x32.25")
    local a, b = popup.buttons[1], popup.buttons[2]
    Check("each a whole number of pixels from the middle", Whole(a.x) and Whole(b.x) and Whole(a.y), true)
    Check("and from the icon", Whole(popup.y), true)
end

-- Personal buffs: the best armor you know shows until any armor is up; resting and a pick hide it.
do
    local t = Fixture({ units = { player = "MAGE" }, known = { [168] = true, [7302] = true } })
    t.Login()
    Check("mage: ice armor missing", t.Shown(), "spell:7302")
    for _, f in ipairs(t.frames) do
        if rawget(f, "items") == nil and rawget(f, "count") and f.shown then
            Check("a spell reminder casts its spell, with no item", (f.attributes.type1 or "") .. " "
                .. tostring(f.attributes.spell1) .. " " .. tostring(f.attributes.item1), "spell 7302 nil")
        end
    end
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

-- Every reminder does something on a click: a poison or stone goes on the weapon that lacks one, a buff is cast.
do
    local function Clicks(t)
        for _, f in ipairs(t.frames) do
            if rawget(f, "count") and f.shown and rawget(f, "attributes") then
                local a = f.attributes
                return (a.type1 or "") .. " " .. tostring(a.macrotext1 or a.spell1 or a.item1) .. " " .. tostring(a.unit1)
            end
        end
    end
    local t = Fixture({ units = { player = "ROGUE" }, known = { [2842] = true }, bags = { 6947, 8928 },
        weapons = { [16] = 600, [17] = false } })
    t.Login()
    Check("a poison goes on the unpoisoned hand, the best one carried first", Clicks(t),
        "macro /use item:8928\n/use 17 nil")
    t = Fixture({ units = { player = "ROGUE" }, known = { [2842] = true }, weapons = { [16] = false } })
    t.Login()
    Check("no poison carried: nothing to use", Clicks(t), " nil nil")
    t = Fixture({ units = { player = "MAGE" }, known = { [168] = true } })
    t.Login()
    Check("a personal buff is cast", Clicks(t), "spell 168 nil")
    t = Fixture({ settings = { raidBuffs = true }, units = { player = "MAGE", party1 = "PRIEST" }, group = "party",
        known = { [10157] = true },
        auras = { player = { { 10157, 3000, 3600 } } } })
    t.Login()
    Check("a raid buff is cast on the first one missing it", Clicks(t), "spell 10157 party1")
end

-- An enchant the game reports with no time left counts as up and arms no wake timer.
do
    local t = Fixture({ units = { player = "SHAMAN" }, known = { [8017] = true }, weapons = { [16] = 0 } })
    t.Login()
    Check("untimed imbue counts", t.Shown(), "")
    Check("untimed imbue arms nothing", t.Pending(), 0)
end

-- Weapon Imbue shows the one actually cast, not just the first one trained.
do
    local t = Fixture({ units = { player = "SHAMAN" }, known = { [8024] = true, [8017] = true },
        weapons = { [16] = false } })
    t.Login()
    Check("defaults to the first trained imbue", t.Shown(), "spell:8024")
    Check("listens for the cast", t.Listening("UNIT_SPELLCAST_SUCCEEDED"), true)
    t.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast1", 8017)
    t.Advance(0.5)
    Check("switches to the cast imbue", t.Shown(), "spell:8017")
    t.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast2", 2842)
    t.Advance(0.5)
    Check("casting something else leaves it alone", t.Shown(), "spell:8017")
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

-- A class with no personal buff: the card still lists other classes'.
do
    local t = Fixture({ page = true, units = { player = "PALADIN" },
        known = { [19740] = true } })
    t.Login()
    Check("paladin default: listens, a carried flask can remind", t.Listening("UNIT_AURA"), true)
    local card = t.ns.Shared.Settings.pages["AuraBuffs/Settings"].cards.buffs
    local found
    for _, row in ipairs(card.rows) do
        if row.key == "personalBuffs" then found = true end
    end
    Check("paladin: the group lists the other classes", found, true)
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

-- Aspect: any aspect the hunter cast counts, one from another hunter does not, once one is known.
do
    local t = Fixture({ units = { player = "HUNTER" } })
    t.Login()
    Check("no aspect known", t.Shown(), "")
    t.state.known[13163] = true
    t.Fire("SPELLS_CHANGED")
    t.Advance(0.5)
    Check("monkey known, none up", t.Shown(), "spell:13163")
    t.state.known[13165] = true
    t.Fire("SPELLS_CHANGED")
    t.Advance(0.5)
    Check("the best known aspect is the icon", t.Shown(), "spell:13165")
    t.state.auras.player = { { 5118 } }
    t.Fire("UNIT_AURA", "player")
    t.Advance(0.5)
    Check("own untimed cheetah counts", t.Shown(), "")
    Check("an untimed aspect arms nothing", t.Pending(), 0)
    t.state.auras.player = { { 13159, nil, nil, "party1" } }
    t.Fire("UNIT_AURA", "player")
    t.Advance(0.5)
    Check("another hunter's pack does not count", t.Shown(), "spell:13165")
    t.state.auras.player = { { 13159, nil, nil, "party1" }, { 13165 } }
    t.Fire("UNIT_AURA", "player")
    t.Advance(0.5)
    Check("own hawk beside their pack counts", t.Shown(), "")
    t.state.auras.player = {}
    t.Fire("UNIT_AURA", "player")
    t.Advance(0.5)
    t.state.combat = true
    t.state.auras.player = { { 13165 } }
    t.Fire("UNIT_AURA", "player")
    t.Advance(0.5)
    Check("combat: held", t.Shown(), "spell:13165")
    t.state.combat = false
    t.state.secret = true
    t.Fire("PLAYER_REGEN_ENABLED")
    t.Advance(0.5)
    Check("secret auras: held", t.Shown(), "spell:13165")
    t.state.secret = false
    t.Fire("PLAYER_REGEN_ENABLED")
    t.Advance(0.5)
    Check("after combat, own hawk counts", t.Shown(), "")
    t.state.auras.player = { { 13161, nil, nil, SECRET } }
    t.Fire("UNIT_AURA", "player")
    t.Advance(0.5)
    Check("a secret caster is not read and does not nag", t.Shown(), "")
    t.Set("personalBuffPicks", { aspect = false })
    t.state.auras.player = {}
    t.Fire("UNIT_AURA", "player")
    t.Advance(0.5)
    Check("aspect picked off", t.Shown(), "")
    local m = Fixture({ units = { player = "MAGE" }, known = { [13165] = true } })
    m.Login()
    Check("another class never gets it", m.Shown(), "")
end

-- The card lists every class's personal buffs, the player's first and the rest in grey.
do
    local t = Fixture({ page = true, units = { player = "SHAMAN" } })
    local card = t.ns.Shared.Settings.pages["AuraBuffs/Settings"].cards.buffs
    local fields = {}
    for _, row in ipairs(card.rows) do
        if row.key == "personalBuffPicks" then fields[#fields + 1] = row.field end
    end
    Check("shaman picks come first, then every other class", table.concat(fields, " "),
        "imbue shield demonArmor mageArmor poisons battleShout innerFire shadowform aspect trueshot huntersMark thorns")
    local byField = {}
    for _, row in ipairs(card.rows) do
        if row.key == "personalBuffPicks" then byField[row.field] = row end
    end
    Check("own class in its colour", byField.imbue.labelColor, t.env.RAID_CLASS_COLORS.SHAMAN)
    Check("another class in grey", byField.demonArmor.labelColor, t.ns.THEME.muted)
    Check("its class named in its colour", byField.demonArmor.note(), "|cWARLOCK|warlock")
    byField.demonArmor.set(false)
    Check("switched off for a class that is not played", byField.demonArmor.get(), false)
    Check("stored by the buff's own key", t.Get("personalBuffPicks").demonArmor, false)
    byField.demonArmor.set(true)
    local intellect
    for _, row in ipairs(card.rows) do
        if row.key == "raidBuffPicks" and row.field == "intellect" then intellect = row end
    end
    Check("another class's raid buff is not grey", intellect.labelColor, nil)
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
    t.Set("personalBuffsWorld", false)
    Check("preview in the world, personal buffs kept out", Preview("world"), "")
    Check("preview in a raid", Preview("raid"),
        "spell:1248406 item:13510 item:13454 item:10306 personal:spell:16362")
end

-- Only If I Carry One off: food shows with none carried, with the Well Fed icon until a food is eaten.
do
    local t = Fixture({ instance = "raid", bags = { 13931 }, settings = { onlyIfCarried = false } })
    t.Login()
    Check("none carried", t.Shown(), "spell:1248406 item:13510 item:13452")
    t.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast1", 5)
    t.Advance(0.5)
    Check("other spell ignored", t.Shown(), "spell:1248406 item:13510 item:13452")
    t.state.bags = {}
    t.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast2", 1249513)
    t.Advance(0.5)
    Check("food eaten, item already gone", t.Shown(), "spell:1249513 item:13510 item:13452")
    t.state.bags = { 13931 }
    t.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast3", 1249513)
    t.Advance(0.5)
    t.state.bags = {}
    t.Fire("BAG_UPDATE_DELAYED")
    t.Advance(0.5)
    Check("last food eaten icon", t.Shown(), "item:13931 item:13510 item:13452")
    t.Set("onlyIfCarried", true)
    Check("only carried, nothing carried", t.Shown(), "")
end

-- With nothing carried, nothing shows until Only If I Carry One goes off.
do
    local t = Fixture({ instance = "raid", units = { player = "MAGE" }, settings = { personalBuffs = false } })
    t.Login()
    Check("nothing carried, nothing shown", t.Shown(), "")
    t.Set("onlyIfCarried", false)
    Check("switch off, kinds shown", t.Shown(), "spell:1248406 item:13510 item:13452")
    t.Set("onlyIfCarried", true)
    Check("switch back on, nothing shown", t.Shown(), "")
end

-- Weapon Enhancement Reminder: stone or oil missing on a weapon, off by default.
do
    local t = Fixture({ instance = "raid", units = { player = "MAGE" }, bags = { 20750 },
        weapons = { [16] = false, [17] = false }, shields = { [17] = true } })
    t.Login()
    Check("off by default", t.Shown(), "")
    t.Set("weaponEnhancements", true)
    Check("oil carried, main hand bare, its classic icon", t.Shown(), ICONS .. "inv_potion_104")
    local cell
    for _, f in ipairs(t.frames) do if rawget(f, "items") and f.shown then cell = f end end
    cell.scripts.OnEnter(cell)
    local popup
    for _, f in ipairs(t.frames) do if rawget(f, "owner") == cell then popup = f end end
    Check("the hover menu's oil has its classic icon", popup.buttons[1].icon.texture, ICONS .. "inv_potion_104")
    t.state.bags = {}
    t.Fire("BAG_UPDATE_DELAYED")
    t.Advance(0.5)
    Check("none carried", t.Shown(), "")
    t.Set("carriedPicks", { weapon = false })
    Check("none carried, weapon kind off: a rough sharpening stone", t.Shown(), ROUGH)
    t.Set("carriedPicks", {})
    t.Set("onlyIfCarried", false)
    Check("none carried, switch off: a rough sharpening stone", t.Shown(), "spell:1248406 item:13510 item:13452 " .. ROUGH)
    t.state.weapons[16] = 1800
    t.Fire("UNIT_INVENTORY_CHANGED", "player")
    t.Advance(0.5)
    Check("main hand enchanted, shield ignored", t.Shown(), "spell:1248406 item:13510 item:13452")
    t.state.shields[17] = nil
    t.Fire("UNIT_INVENTORY_CHANGED", "player")
    t.Advance(0.5)
    Check("off hand weapon bare", t.Shown(), "spell:1248406 item:13510 item:13452 " .. ROUGH)
end

-- Icon: Last Used shows the flask, elixir or weapon item used last, and only listens while it is chosen.
do
    local t = Fixture({ instance = "raid", units = { player = "MAGE" }, weapons = { [16] = false },
        itemSpells = { [13511] = 17627, [20749] = 28898 },
        settings = { onlyIfCarried = false, weaponEnhancements = true, personalBuffs = false } })
    t.Login()
    Check("default icons", t.Shown(), "spell:1248406 item:13510 item:13452 " .. ROUGH)
    Check("off-mode listens for the food icon", t.Listening("UNIT_SPELLCAST_SUCCEEDED"), true)
    t.Set("onlyIfCarried", true)
    Check("not listening for casts", t.Listening("UNIT_SPELLCAST_SUCCEEDED"), false)
    t.Set("buffIconMode", "last")
    Check("listening once Last Used is chosen", t.Listening("UNIT_SPELLCAST_SUCCEEDED"), true)
    t.Set("onlyIfCarried", false)
    t.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast1", 17627)
    t.Advance(0.5)
    Check("a flask used", t.Shown(), "spell:1248406 item:13511 item:13452 " .. ROUGH)
    t.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast2", 28898)
    t.Advance(0.5)
    Check("a weapon oil used, its classic icon", t.Shown(), "spell:1248406 item:13511 item:13452 " .. ICONS .. "inv_potion_105")
    t.Set("buffIconMode", "default")
    Check("Default again", t.Shown(), "spell:1248406 item:13510 item:13452 " .. ROUGH)
    local account = t.ns.AccountSettings()
    account.lastIcons.weapon = "item:20749"
    t.Set("buffIconMode", "last")
    Check("an oil saved by an older version shows its classic icon", t.Shown(),
        "spell:1248406 item:13511 item:13452 " .. ICONS .. "inv_potion_105")
    Check("and is saved as that", account.lastIcons.weapon, ICONS .. "inv_potion_105")
    t.Set("buffIconMode", "default")
    account.lastIcons.weapon = 123456
    t.Set("buffIconMode", "last")
    Check("an old icon of no stone or oil falls back", t.Shown(), "spell:1248406 item:13511 item:13452 " .. ROUGH)
    Check("and is forgotten", account.lastIcons.weapon, nil)
end

-- Last Used with weapon items: the row picks the carried one with that classic icon and uses it, and
-- every weapon icon on the row and in the menu is the classic one.
do
    local WIZARD, BRILLIANT = ICONS .. "inv_potion_104", ICONS .. "inv_potion_105"
    local t = Fixture({ instance = "raid", units = { player = "MAGE" }, bags = { 20750, 20749 }, weapons = { [16] = false },
        settings = { weaponEnhancements = true, personalBuffs = false, buffIconMode = "last" } })
    local account = t.ns.AccountSettings()
    account.lastIcons = { weapon = BRILLIANT }
    t.Login()
    local cell
    for _, f in ipairs(t.frames) do if rawget(f, "items") and f.shown then cell = f end end
    Check("Last Used oil shown with its classic icon", t.Shown(), BRILLIANT)
    Check("and clicking it uses that oil", (cell.attributes.macrotext1 or ""):match("^/use (item:%d+)"), "item:20749")
    cell.scripts.OnEnter(cell)
    local popup
    for _, f in ipairs(t.frames) do if rawget(f, "owner") == cell then popup = f end end
    Check("menu oils have classic icons", popup.buttons[1].icon.texture .. " " .. popup.buttons[2].icon.texture,
        WIZARD .. " " .. BRILLIANT)
    t.state.bags = { 20750 }
    t.Fire("BAG_UPDATE_DELAYED")
    t.Advance(0.5)
    Check("Last Used oil gone: the carried one's classic icon", t.Shown(), WIZARD)
    Check("and clicking it uses the carried one", (cell.attributes.macrotext1 or ""):match("^/use (item:%d+)"), "item:20750")
    t.state.bags = { 20750, 20749 }
    t.Set("buffIconMode", "default")
    account.lastIcons.weapon = "item:20749"
    t.Set("buffIconMode", "last")
    Check("an oil saved by an older version picks that oil", t.Shown(), BRILLIANT)
    Check("and clicking it uses that oil too", (cell.attributes.macrotext1 or ""):match("^/use (item:%d+)"), "item:20749")
end

-- The gear reminders moved to QoL (test-gear-reminders.lua): an old profile's switches add nothing to the row.
do
    local t = Fixture({ instance = "party", instanceID = 43, units = { player = "MAGE" },
        worn = { [15] = 273084, [16] = 6256 }, subclasses = { [6256] = 20 },
        settings = { wornReminders = true, fishingPoleReminder = true } })
    t.Login()
    Check("old gear switches: no icons in the buff row", t.Shown(), "")
    Check("and no gear events", t.Listening("PLAYER_EQUIPMENT_CHANGED"), false)
end

-- A class with its own poison reminder does not get the generic one.
do
    local t = Fixture({ instance = "raid", units = { player = "ROGUE" }, known = { [2842] = true },
        bags = { 20750 }, weapons = { [16] = false }, settings = { weaponEnhancements = true } })
    t.Login()
    Check("rogue keeps poisons only", t.Shown(), "spell:2842")
end

-- Where poisons do not show, the generic weapon reminder does.
do
    local t = Fixture({ instance = "party", units = { player = "ROGUE" }, known = { [2842] = true },
        bags = { 20750 }, weapons = { [16] = false },
        settings = { weaponEnhancements = true, personalBuffsDungeon = false } })
    t.Login()
    Check("poisons off in dungeons, weapon reminder shown", t.Shown(), ICONS .. "inv_potion_104")
end

if failures > 0 then
    print(failures .. " failure(s)")
    os.exit(1)
end
print("test-buff-reminders: all passed")

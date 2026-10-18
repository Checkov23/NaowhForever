-- Combat-time cost in a 20-player raid, on stubs that allocate nothing: the Threat Meter's
-- update and unit filter, the Buff Reminders aura burst and refresh, and the Blessings bar's
-- aura reads. Run from the repo root. An optional first argument is a folder holding older
-- copies of the modules (same layout), to print their numbers for comparison.
rawset(_G, "C_AddOns", { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end })
local ROOT = arg[1] or ""
local RUNS = 1000
local checks, failures = 0, 0
local function check(label, ok)
    checks = checks + 1
    if not ok then failures = failures + 1; print("FAIL " .. label) end
end

local function Source(path)
    local f = assert(io.open(ROOT .. path, "rb"))
    local text = f:read("*a"):gsub("\r\n", "\n")
    f:close()
    return text
end

local function Run(text, name, env)
    local chunk = assert(loadstring(text, "@" .. name))
    setfenv(chunk, setmetatable(env, { __index = _G }))
    return chunk()
end

-- Average ms and KB of garbage per call, over RUNS calls after one warm-up, collector stopped.
local function Cost(fn)
    collectgarbage("collect")
    collectgarbage("stop")
    fn()
    local before, start = collectgarbage("count"), os.clock()
    for _ = 1, RUNS do fn() end
    local ms = (os.clock() - start) * 1000 / RUNS
    local kb = (collectgarbage("count") - before) / RUNS
    collectgarbage("restart")
    return ms, kb
end

local function Report(label, ms, kb, msBudget, kbBudget)
    print(("  %s: %.4f ms, %.3f KB"):format(label, ms, kb))
    check(label .. " under " .. msBudget .. " ms", ms < msBudget)
    check(label .. " under " .. kbBudget .. " KB", kb < kbBudget)
end

-- Frames: shared methods, widget calls counted, nothing allocated per call.
local calls = { SetPoint = 0, SetFont = 0 }
local methods = {}
local meta = { __index = function(_, k)
    local m = methods[k]
    if m then return m end
    if type(k) == "string" and k:find("^%u") then return methods.Nothing end
end }
local frames, named = {}, {}
local function New(kind, name, parent)
    local f = setmetatable({ kind = kind, parent = parent, scripts = {}, events = {}, shown = true,
        w = 0, h = 0 }, meta)
    frames[#frames + 1] = f
    if name then named[name] = f end
    return f
end
function methods.Nothing() end
function methods:SetScript(k, fn) self.scripts[k] = fn end
function methods:RegisterEvent(e) self.events[e] = true end
methods.RegisterUnitEvent = methods.RegisterEvent
function methods:UnregisterEvent(e) self.events[e] = nil end
function methods:UnregisterAllEvents() for k in pairs(self.events) do self.events[k] = nil end end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(v) self.shown = v and true or false end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown end
function methods:SetSize(w, h) self.w, self.h = w, h end
function methods:GetWidth() return self.w end
function methods:GetHeight() return self.h end
function methods:GetFrameLevel() return 1 end
function methods:GetEffectiveScale() return 1 end
function methods:SetPoint() calls.SetPoint = calls.SetPoint + 1 end
function methods:SetFont() calls.SetFont = calls.SetFont + 1 end
function methods:SetText(t) self.text = t end
function methods:CreateTexture() return New("Texture", nil, self) end
function methods:CreateFontString() return New("FontString", nil, self) end

local function Fire(event, ...)
    for i = 1, #frames do
        local f = frames[i]
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

local function Settings(values, defaults)
    local S = {}
    function S.Get(k) local v = values[k]; if v == nil and defaults then return defaults[k] end return v end
    function S.Set(k, v) values[k] = v end
    function S.DB() return values end
    return S
end

local THEME = { bg = { r = 0, g = 0, b = 0 }, fg = { r = 1, g = 1, b = 1 }, muted = { r = 0.6, g = 0.6, b = 0.6 },
    accent = { r = 0, g = 0.57, b = 0.93 } }
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local RAID = 20
local NAMEPLATES = {}
for i = 1, RAID do NAMEPLATES[i] = "nameplate" .. i end
local RAID_UNITS = {}
for i = 1, RAID do RAID_UNITS[i] = "raid" .. i end

local function BaseEnv(ns, extra)
    local env = {
        _G = { NaowhForever = ns }, UIParent = New("Frame"), MAX_RAID_MEMBERS = 40, MAX_PARTY_MEMBERS = 4,
        CreateFrame = function(kind, name, parent) return New(kind, name, parent) end,
        hooksecurefunc = function(t, k, fn)
            local orig = t[k]
            t[k] = function(...) orig(...); fn(...) end
        end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        issecretvalue = function() return false end,
        RAID_CLASS_COLORS = {},
    }
    for _, class in ipairs(CLASSES) do env.RAID_CLASS_COLORS[class] = { r = 1, g = 1, b = 1 } end
    for k, v in pairs(extra) do env[k] = v end
    return env
end

-------------------------------------------------------------------------------
--  Threat Meter: 20 in a raid, on a boss, in combat
-------------------------------------------------------------------------------
do
    local units = { target = { name = "Boss", guid = "Creature-1", hostile = true } }
    for i = 1, RAID do
        units[RAID_UNITS[i]] = { name = "Member" .. i, class = CLASSES[i % 9 + 1], tanking = i == 1,
            raw = 50000 - i * 1700, scaled = 100 - i * 3, rawPct = 100 - i * 3 }
    end
    local values = { enabled = true, visibility = "always", height = 700 }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"), THEME = THEME, Print = function() end, Apply = function() end,
        ShowUnlockMode = function() end, HideUnlockMode = function() end,
        Font = function(parent) return New("FontString", nil, parent) end,
        Border = function(parent) return { _frame = New("Frame", nil, parent) } end,
        AllowOffscreen = function() end, Tooltip = function() end,
        Solid = function(parent) return New("Texture", nil, parent) end,
        ThemeTint = function(_, literal) return literal end,
        OpenOptionsWindow = function() end,
        Button = function(parent)
            local b = New("Button", nil, parent)
            b.label = New("FontString", nil, b)
            return b
        end,
        UI = { FontPath = function() return "font" end, AttachMover = function() return New("Mover") end,
            TexturePath = function(_, fallback) return fallback end,
            SoundPathFor = function() return "sound" end, _PlayLSMSound = function() end },
        Shared = { Parts = { HudFont = function(fs, _, size, outline) fs:SetFont("font", size, outline) end },
            Style = setmetatable({ RED_RGB = {}, HAVE_RGB = {}, WARN_RGB = {} },
                { __index = dofile("Tools/regression/shared_style.lua") }) },
    }
    ns.UI.ModuleSettings = function(_, defaults) return Settings(values, defaults) end
    local env = BaseEnv(ns, {
        UnitExists = function(u) return units[u] ~= nil end,
        UnitCanAttack = function(_, u) return units[u] ~= nil and units[u].hostile == true end,
        UnitName = function(u) return units[u] and units[u].name end,
        UnitGUID = function(u) return units[u] and units[u].guid end,
        UnitClass = function(u) return "Class", units[u] and units[u].class end,
        UnitIsUnit = function(a, b) if b == "player" then return a == "raid5" end return a == b end,
        UnitDetailedThreatSituation = function(u)
            local d = units[u]
            if not (d and d.raw) then return nil end
            return d.tanking, d.tanking and 3 or 1, d.scaled, d.rawPct, d.raw
        end,
        UnitAffectingCombat = function() return true end, InCombatLockdown = function() return true end,
        IsInGroup = function() return true end, IsInRaid = function() return true end,
        GetNumGroupMembers = function() return RAID end, GetNumSubgroupMembers = function() return 4 end,
        UnitGroupRolesAssigned = function() return "DAMAGER" end, GetShapeshiftFormID = function() return nil end,
        C_Timer = { After = function() end, NewTicker = function() return { Cancel = function() end } end },
    })
    for _, file in ipairs({ "Core/Features.lua", "NaowhForever_Combat/ThreatMeter/ThreatMeter.lua",
        "NaowhForever_Combat/ThreatMeter/Constants.lua", "NaowhForever_Combat/ThreatMeter/Data/Samples.lua",
        "NaowhForever_Combat/ThreatMeter/Threat.lua", "NaowhForever_Combat/ThreatMeter/View/Meter.lua",
        "NaowhForever_Combat/ThreatMeter/UI/Meter.lua", "NaowhForever_Combat/ThreatMeter/UI/SettingsPage.lua" }) do
        Run(Source(file), file, env)
    end
    Fire("PLAYER_LOGIN")
    local meter = named.NaowhForeverThreatMeter
    local wheel = meter.scripts.OnMouseWheel
    local function Update() wheel(meter, 0) end

    print("Threat Meter, 20 in a raid:")
    calls.SetPoint, calls.SetFont = 0, 0
    Update()
    print(("  widget calls per update: %d SetPoint, %d SetFont"):format(calls.SetPoint, calls.SetFont))
    check("an update with nothing moved re-anchors no rows", calls.SetPoint == 0 and calls.SetFont == 0)
    local ms, kb = Cost(Update)
    Report("update with 20 bars", ms, kb, 0.5, 0.01)

    local events
    for i = 1, #frames do if frames[i].events.UNIT_THREAT_SITUATION_UPDATE then events = frames[i] end end
    local onEvent = events.scripts.OnEvent
    onEvent(events, "UNIT_THREAT_SITUATION_UPDATE", "raid3")
    local function Burst()
        for i = 1, RAID do
            onEvent(events, "UNIT_THREAT_SITUATION_UPDATE", RAID_UNITS[i])
            onEvent(events, "UNIT_THREAT_SITUATION_UPDATE", NAMEPLATES[i])
        end
    end
    ms, kb = Cost(Burst)
    Report("40 threat situation events", ms, kb, 0.2, 0.01)

    units.raid7.raw = 1500
    Update()
    local repainted
    for _, row in ipairs(meter.rows) do
        if row.name.text == "Member7" then repainted = row.value.text == "1.5k" end
    end
    check("a changed value still repaints", repainted)
end

-------------------------------------------------------------------------------
--  Buff Reminders: raid buffs on, 20 in a raid, out of combat
-------------------------------------------------------------------------------
do
    frames = {}
    local state = { combat = false, reads = 0, now = 1000 }
    local auras = {}
    local FILLER = 400000
    for i = 1, RAID do
        local list = {}
        for k = 1, 20 do
            list[k] = { spellId = FILLER + k, expirationTime = 4000, duration = 3600 }
        end
        list[5] = { spellId = 10938, expirationTime = 4000, duration = 3600 }
        if i % 4 ~= 0 then list[9] = { spellId = 10157, expirationTime = 4000, duration = 3600 } end
        auras[RAID_UNITS[i]] = list
    end
    auras.player = auras.raid1
    auras.player[12] = { spellId = 17626, expirationTime = 1500, duration = 7200 }
    local unitClass = { player = CLASSES[2] }
    for i = 1, RAID do unitClass[RAID_UNITS[i]] = CLASSES[i % 9 + 1] end
    local values = { enabled = true, raidBuffs = true, raidBuffsOwn = false,
        consumablesWhere = "always", consumablesMinutes = 2, onlyIfCarried = true, carriedPicks = {}, hideResting = true,
        iconSize = 36, buffsFont = "", buffsFontSize = 14, buffsOutline = "OUTLINE",
        raidBuffPicks = { intellect = true, stamina = true, spirit = true, wild = true, blessing = true },
        consumableEntries = {
            { category = "food", itemID = 13931, auras = { 1249520 } },
            { category = "flask", itemID = 13510, auras = { 17626 } },
        } }
    local bags = { [13931] = 2, [13510] = 1 }
    local ns = { AccountSettings = function() return {} end, L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"), AuraBuffSettings = Settings(values), THEME = THEME, Apply = function() end,
        OnePixel = function() return 1 end,
        ShowUnlockMode = function() end, HideUnlockMode = function() end,
        Border = function() end, Solid = function(parent) return New("Texture", nil, parent) end,
        ThemeTint = function(_, literal) return literal end,
        Font = function(parent) return New("FontString", nil, parent) end,
        UI = { AttachMover = function() return New("Mover") end },
        Shared = { Parts = { HudFont = function(fs, _, size, outline) fs:SetFont("font", size, outline) end },
            ItemBar = { SetItem = function(button, itemID) button.itemID = itemID end } } }
    local lastAfter
    local timer = { Cancel = function() end }
    local env = BaseEnv(ns, {
        GetTime = function() return state.now end,
        InCombatLockdown = function() return state.combat end,
        IsResting = function() return false end,
        IsInInstance = function() return true, "raid" end,
        IsInRaid = function() return true end,
        GetNumGroupMembers = function() return RAID end,
        UnitClass = function(u) return "Class", unitClass[u] end,
        UnitIsConnected = function() return true end,
        UnitIsDeadOrGhost = function() return false end,
        UnitIsVisible = function() return true end,
        UnitIsUnit = function(a, b) return a == b or (b == "player" and a == "raid1") end,
        C_Secrets = { ShouldAurasBeSecret = function() return false end },
        C_UnitAuras = { GetAuraDataByIndex = function(unit, i)
            state.reads = state.reads + 1
            local list = auras[unit]
            return list and list[i]
        end },
        C_Item = { GetItemCount = function(id) return bags[id] or 0 end, GetItemIconByID = function(id) return id end,
            GetItemSpell = function() end, GetItemInfo = function() end, RequestLoadItemDataByID = function() end },
        C_Container = { GetContainerNumSlots = function() return 2 end,
            GetContainerItemID = function(_, slot) return slot == 1 and 13931 or 13510 end },
        NUM_BAG_SLOTS = 0,
        UnitLevel = function() return 60 end,
        C_Spell = { GetSpellTexture = function(id) return id end },
        C_SpellBook = { IsSpellKnown = function() return false end },
        C_Timer = { After = function(_, fn) lastAfter = fn end, NewTimer = function() return timer end },
    })
    ns.UI.ModuleSettings = function() return ns.AuraBuffSettings end
    for _, file in ipairs({ "Core/Features.lua", "NaowhForever_Combat/AuraBuffs/AuraBuffs.lua",
        "NaowhForever_Combat/AuraBuffs/Constants.lua", "Shared/Game/Consumables.lua",
        "NaowhForever_Combat/AuraBuffs/Data/BuffReminders.lua", "NaowhForever_Combat/AuraBuffs/BuffReminders.lua",
        "NaowhForever_Combat/AuraBuffs/View/Style.lua", "NaowhForever_Combat/AuraBuffs/View/Glow.lua",
        "NaowhForever_Combat/AuraBuffs/View/BuffCell.lua",
        "NaowhForever_Combat/AuraBuffs/UI/BuffMenu.lua", "NaowhForever_Combat/AuraBuffs/UI/BuffReminders.lua" }) do
        Run(Source(file), file, env)
    end
    Fire("PLAYER_LOGIN")
    Fire("UNIT_AURA", "raid3")
    local Refresh = lastAfter

    print("Buff Reminders, raid buffs on, 20 in a raid:")
    state.reads = 0
    Refresh()
    print(("  aura reads per refresh: %d"):format(state.reads))
    local ms, kb = Cost(Refresh)
    Report("refresh", ms, kb, 1, 3)

    local events
    for i = 1, #frames do if frames[i].events.UNIT_AURA then events = frames[i] end end
    local onEvent = events.scripts.OnEvent
    local function Burst()
        for i = 1, RAID do
            onEvent(events, "UNIT_AURA", RAID_UNITS[i])
            onEvent(events, "UNIT_AURA", NAMEPLATES[i])
        end
    end
    Fire("UNIT_AURA", "raid3")
    ms, kb = Cost(Burst)
    Report("40 aura events, refresh queued", ms, kb, 0.2, 0.01)
    state.combat = true
    ms, kb = Cost(Burst)
    Report("40 aura events in combat", ms, kb, 0.2, 0.01)
end

-------------------------------------------------------------------------------
--  Blessings: every ask in one bar refresh reads a member's buffs once
-------------------------------------------------------------------------------
do
    local source = Source("NaowhForever_Combat/Blessings/Buffs.lua")
    local first = source:find("local memoAt", 1, true) or source:find("-- Present, with the time left", 1, true)
    local last = assert(source:find("local function InRange(member, spell)", first, true))
    local SECRET = {}
    local state = { reads = 0, now = 500, secretAuras = false }
    local auras = {}
    local env = {
        B = { HiddenAuras = function() return false end },
        MAX_AURAS = tonumber((assert(source:match("\nlocal MAX_AURAS = (%d+)\n"), "MAX_AURAS is missing"))),
        FAMILY = { [19740] = "might", [25291] = "might", [20217] = "kings", [25898] = "kings",
            [19742] = "wisdom", [465] = "devotion" },
        Secret = function(v) return v == SECRET end,
        GetTime = function() return state.now end,
        C_Secrets = { ShouldAurasBeSecret = function() return state.secretAuras end },
        C_UnitAuras = { GetAuraDataByIndex = function(unit, i)
            state.reads = state.reads + 1
            local list = auras[unit]
            return list and list[i]
        end },
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    }
    local BuffState, Begin, End = Run(source:sub(first, last - 1)
        .. "\nreturn BuffState, BeginAuraMemo, EndAuraMemo", "Blessings", env)
    for i = 1, RAID do
        local list = {}
        for k = 1, 24 do list[k] = { spellId = 400000 + k, expirationTime = 0 } end
        if i % 5 ~= 0 then list[14] = { spellId = 25291, expirationTime = 800 } end
        list[18] = { spellId = 20217, expirationTime = 0 }
        auras[RAID_UNITS[i]] = list
    end
    local function Pass()
        for i = 1, RAID do
            local unit = RAID_UNITS[i]
            BuffState(unit, "might")
            BuffState(unit, "might")
            BuffState(unit, "might")
            if i <= 5 then BuffState(unit, "might") end
        end
    end
    print("Blessings, 20 in a raid:")
    state.reads = 0
    if Begin then Begin() end
    Pass()
    if End then End() end
    print(("  aura reads per bar refresh: %d"):format(state.reads))
    check("one refresh reads each member's buffs once", state.reads <= 16 * 14 + 4 * 25)

    local function Answers(unit, key)
        local a, b = BuffState(unit, key)
        return tostring(a) .. ":" .. tostring(b)
    end
    auras.raid1 = { { spellId = 465, expirationTime = 0 }, { spellId = SECRET, expirationTime = 0 },
        { spellId = 25291, expirationTime = 700 } }
    auras.raid2 = { { spellId = 25291, expirationTime = SECRET }, { spellId = 20217, expirationTime = 650 } }
    auras.raid3 = {}
    local cases = { { "raid1", "devotion" }, { "raid1", "might" }, { "raid1", "kings" },
        { "raid2", "might" }, { "raid2", "kings" }, { "raid2", "wisdom" }, { "raid3", "might" },
        { "raid4", "might" }, { "raid5", "might" }, { "raid5", "kings" } }
    local plain = {}
    for i, c in ipairs(cases) do plain[i] = Answers(c[1], c[2]) end
    if Begin then Begin() end
    for i, c in ipairs(cases) do
        check("memo answers " .. c[1] .. " " .. c[2] .. " as a plain read does", Answers(c[1], c[2]) == plain[i])
    end
    for i = #cases, 1, -1 do
        local c = cases[i]
        check("memo answers " .. c[1] .. " " .. c[2] .. " in any order", Answers(c[1], c[2]) == plain[i])
    end
    if End then End() end
    auras.raid4 = {}
    check("a read after the refresh is fresh", Answers("raid4", "might") == "false:nil")
    if Begin then
        Begin()
        check("an empty unit reads missing", Answers("raid4", "might") == "false:nil")
        auras.raid4 = { { spellId = 25291, expirationTime = 0 } }
        state.now = state.now + 1
        check("a memo left open past its frame is not used", Answers("raid4", "might") == "true:nil")
        End()
    end
    state.secretAuras = true
    check("restricted auras read as unknown", Answers("raid5", "might") == "nil:nil")
end

print(("test-combat-perf: %d checks, %d failed"):format(checks, failures))
if failures > 0 then os.exit(1) end

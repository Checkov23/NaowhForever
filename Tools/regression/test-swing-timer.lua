-- The module's files in SwingTimer.xml's order, after the feature switches; a first argument names
-- one older single-file copy to run instead.
local FILES = arg[1] and { arg[1] } or dofile("Tools/regression/toc_files.lua")("^NaowhForever_SwingTimer/.*%.lua$")
if not arg[1] then table.insert(FILES, 1, "Core/Features.lua") end
local sources = {}
for i, path in ipairs(FILES) do
    local f = assert(io.open(path, "rb"))
    sources[i] = f:read("*a"):gsub("\r\n", "\n"); f:close()
end

local function Compile(env)
    local chunks = {}
    for i, source in ipairs(sources) do
        if setfenv then
            chunks[i] = assert(loadstring(source)); setfenv(chunks[i], env)
        else
            chunks[i] = assert(load(source, "=SwingTimer", "t", env))
        end
    end
    return function()
        for _, chunk in ipairs(chunks) do chunk() end
    end
end

-- The real house colours, which some bar defaults come from.
local SHARED = {}
dofile("Tools/regression/load_files.lua")({ "Shared/Style.lua" }, { _G = { NaowhForever = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Shared = SHARED } } })

local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })

-- A widget that accepts any method; the few the module's behaviour hangs on are recorded.
local function Widget(kind, log)
    local w = { kind = kind, shown = true, events = {} }
    -- Widget methods are PascalCase; lower-case keys are the module's own fields.
    setmetatable(w, { __index = function(_, k)
        if k:match("^%u") then return function() end end
    end })
    function w:RegisterEvent(e) self.events[e] = true end
    function w:RegisterUnitEvent(e, ...) self.events[e] = { ... } end
    function w:UnregisterEvent(e) self.events[e] = nil end
    function w:UnregisterAllEvents() self.events = {} end
    function w:SetScript(_, fn) self.onEvent = fn end
    function w:Show() self.shown = true end
    function w:Hide() self.shown = false end
    function w:SetShown(v) self.shown = v and true or false end
    function w:IsShown() return self.shown end
    function w:GetFrameLevel() return 1 end
    function w:SetTimerDuration(obj, _, dir) self.obj, self.dir = obj, dir end
    function w:GetStatusBarTexture()
        self.tex = self.tex or Widget("Texture", log)
        return self.tex
    end
    function w:SetVertexColor(r, g, b) self.color = { r, g, b } end
    function w:SetTextColor(r, g, b) self.textColor = { r, g, b } end
    function w:SetText(t) self.text = t end
    function w:SetAlpha(a) self.alpha = a end
    function w:CreateTexture() return Widget("Texture", log) end
    function w:CreateFontString() return Widget("FontString", log) end
    log.frames[#log.frames + 1] = w
    return w
end

-- Loads the module against a fresh session and logs in.
local function Session(settings, opts)
    opts = opts or {}
    local log = { frames = {}, bars = {}, now = 100, timers = {}, later = {}, rangeCalls = {} }
    local defaults
    local S = {}
    local UI = {
        ModuleSettings = function(_, d)
            -- Written against the timer's original defaults.
            defaults = setmetatable({ enabled = false, texture = "", showOH = true, showR = true, sealColors = false,
                swingWindow = false }, { __index = d })
            function S.Get(k) local v = settings[k]; if v == nil then return defaults[k] end; return v end
            function S.Set(k, v) settings[k] = v end
            return S
        end,
        AttachMover = function() return Widget("Mover", log) end,
        TexturePath = function(name, fallback)
            log.texture = name
            return name == "" and fallback or name
        end,
        STATUS = {},
    }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, UI = UI, THEME = { bg = { r = 0, g = 0, b = 0 }, fg = { r = 1, g = 1, b = 1 } } }
    function ns.Apply() end
    function ns.ShowUnlockMode() end
    log.unlock = function() ns.ShowUnlockMode() end
    function ns.HideUnlockMode() end
    log.lock = function() ns.HideUnlockMode() end
    ns.Solid = function() return Widget("Texture", log) end
    ns.Border = function() return {} end
    ns.PixelInset = function(region) return region end
    ns.Font = function() return Widget("FontString", log) end
    ns.UIFontPath = function() return "font" end
    ns.Shared = { Style = SHARED.Style, Parts = {
        HudFont = function(fs, font, size, outline)
            fs.font, fs.size, fs.outline = font, size, outline
        end,
        StopTimer = function(bar, dur, full)
            dur:SetTimeFromStart(log.now - 1, 1)
            bar:SetTimerDuration(dur, 0, full and 0 or 1)
        end,
    } }
    local speeds = opts.speeds or { 2.6, nil, nil }
    local env = setmetatable({
        _G = { NaowhForever = ns },
        CreateFrame = function(kind, _, parent)
            local w = Widget(kind, log)
            w.parent = parent
            if kind == "StatusBar" then log.bars[#log.bars + 1] = w end
            return w
        end,
        hooksecurefunc = function(t, name, post)
            local orig = t[name]
            t[name] = function(...) orig(...); post(...) end
        end,
        issecretvalue = function(v) return v == SECRET end,
        GetTime = function() return log.now end,
        GetNetStats = function() return 0, 0, 20, 60 end,
        UnitClass = function() return "Class", opts.class or "WARRIOR" end,
        UnitAttackSpeed = function(unit)
            if unit == "target" then
                if opts.targetSpeedFn then return opts.targetSpeedFn() end
                return opts.targetSpeed or 2.0
            end
            return speeds[1], speeds[2], speeds[3]
        end,
        UnitCanAttack = function() return true end,
        UnitIsDead = function() return opts.dead == true end,
        UnitIsUnit = function() return opts.onMe ~= false end,
        UnitAffectingCombat = function() return false end,
        UnitCastingInfo = function() return nil end,
        UnitChannelInfo = function() return nil end,
        IsPlayerMoving = function() return false end,
        RAID_CLASS_COLORS = {},
        C_Timer = {
            NewTimer = function(sec, fn)
                local t = { at = log.now + sec, fn = fn }
                function t:Cancel() self.cancelled = true end
                log.timers[#log.timers + 1] = t
                return t
            end,
            After = function(_, fn) log.later[#log.later + 1] = fn end,
        },
        C_StringUtil = { CreateNumericRuleFormatter = function()
            return { AddBreakpoint = function(self, b) self.breakpoint = b end }
        end },
        C_Spell = {
            GetSpellName = function(id) return (opts.names or {})[id] or ("Spell" .. tostring(id)) end,
            IsCurrentSpell = function(name) return (opts.current or {})[name] or false end,
        },
        C_Secrets = { ShouldAurasBeSecret = function() return opts.secretAuras == true end },
        C_UnitAuras = { GetAuraDataByIndex = function(_, i) return (opts.auras or {})[i] end },
        C_SwingTimer = {
            EnableRangeCheck = function(t, on)
                log.range = log.range or {}; log.range[t] = on
                log.rangeCalls[#log.rangeCalls + 1] = on
            end,
            IsTargetWithinSwingRange = function(t) return (opts.within or {})[t] end,
        },
        C_DurationUtil = {
            CreateDuration = function()
                local d = {}
                function d:SetTimeFromStart(start, dur) self.start, self.dur = start, dur end
                return d
            end,
            CreateDurationTextBinding = function()
                local b = {}
                setmetatable(b, { __index = function(_, k) if k:match("^%u") then return function() end end end })
                function b:SetEnabled(on) self.enabled = on end
                return b
            end,
        },
        Enum = {
            PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 },
            StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
            StatusBarInterpolation = { Immediate = 0 },
            NumericRuleFormatRounding = { Nearest = 0, Up = 1, Down = 2 },
        },
        UIParent = {},
        pairs = pairs,
    }, { __index = _G })
    Compile(env)()
    -- File scope makes the event frame, then the login frame; Build comes after.
    log.events, log.boot = log.frames[1], log.frames[2]
    log.boot.onEvent(log.boot, "PLAYER_LOGIN")
    function log.Fire(...) log.events.onEvent(log.events, ...) end
    -- Setting changes apply on the next frame.
    function log.Flush()
        local later = log.later
        log.later = {}
        for i = 1, #later do later[i]() end
    end
    function log.Set(k, v) S.Set(k, v); log.Flush() end
    -- Runs every end-of-swing timer due by `t`.
    function log.Advance(t)
        log.now = t
        for i = 1, #log.timers do
            local tm = log.timers[i]
            if not tm.cancelled and not tm.fired and tm.at <= t then tm.fired = true; tm.fn() end
        end
    end
    function log.Live()
        local n = 0
        for i = 1, #log.timers do
            local tm = log.timers[i]
            if not tm.cancelled and not tm.fired then n = n + 1 end
        end
        return n
    end
    return S, log
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("off by default: nothing registered, nothing built", function()
    local _, log = Session({})
    assert(next(log.events.events) == nil)
    assert(#log.bars == 0)
end)

Case("on: the swing events are registered, the timing aids' are not", function()
    local _, log = Session({ enabled = true })
    local e = log.events.events
    assert(e.PLAYER_SWING and e.PLAYER_SWING_RANGE_UPDATE and e.UNIT_ATTACK_SPEED)
    assert(not e.UNIT_COMBAT and not e.UNIT_SPELLCAST_START and not e.PLAYER_STARTED_MOVING)
    assert(e.ACTIONBAR_UPDATE_STATE, "a warrior has queued attacks to watch")
end)

Case("a main hand swing runs its bar for the swing's duration", function()
    local _, log = Session({ enabled = true })
    log.Fire("PLAYER_SWING", 2.6, 0)
    local mh = log.bars[1]
    assert(mh.obj.start == 100 and mh.obj.dur == 2.6 and log.Live() == 1)
    log.Advance(102.7)
    assert(mh.obj.dur == 2.6, "still in the grace after the predicted end")
    log.Advance(102.9)
    assert(mh.obj.dur == 1 and log.Live() == 0, "parked once the grace runs out")
end)

Case("each swing reuses its bar's end callback instead of making a new one", function()
    local _, log = Session({ enabled = true })
    log.Fire("PLAYER_SWING", 2.6, 0)
    log.Fire("PLAYER_SWING", 2.6, 0)
    local first, second = log.timers[#log.timers - 1], log.timers[#log.timers]
    assert(first.cancelled and second.fn == first.fn and log.Live() == 1)
    log.Advance(103)
    assert(log.bars[1].obj.dur == 1 and log.Live() == 0, "the reused callback still parks the bar")
end)

Case("a mage with a wand and no off-hand weapon gets no Off Hand bar", function()
    local _, log = Session({ enabled = true }, { class = "MAGE", speeds = { 2.2, nil, 1.5 } })
    local b = log.bars
    assert(b[1].parent.shown and not b[2].parent.shown and b[3].parent.shown)
end)

Case("a restricted swing payload is ignored", function()
    local _, log = Session({ enabled = true })
    log.Fire("PLAYER_SWING", SECRET, 0)
    assert(log.bars[1].obj.dur == 1, "still parked on the idle duration")
end)

Case("the target bar never reaches the swing API's range check", function()
    local _, log = Session({ enabled = true, targetSwing = true })
    assert(log.range[0] == true and log.range.target == nil)
end)

Case("range checks are never switched off, so Blizzard's own timer keeps its flag", function()
    local _, log = Session({ enabled = true, showR = false })
    log.Set("rangeCheck", false)
    log.Set("enabled", false)
    for i = 1, #log.rangeCalls do assert(log.rangeCalls[i] == true) end
end)

Case("Unlock Mode parks a running swing so the sample stays put", function()
    local _, log = Session({ enabled = true })
    log.Fire("PLAYER_SWING", 2.6, 0)
    log.unlock()
    assert(log.Live() == 0 and log.bars[1].dir == 0, "full sample, no end timer left")
end)

Case("a restricted target speed keeps the bar and times it from the last readable one", function()
    local speed = 2.0
    local _, log = Session({ enabled = true, targetSwing = true }, { targetSpeedFn = function() return speed end })
    speed = SECRET
    log.Fire("UNIT_ATTACK_SPEED", "player")
    local tgt = log.bars[4]
    assert(tgt.parent.shown, "still shown")
    log.Fire("UNIT_COMBAT", "player", "WOUND", "", 120, 1)
    assert(tgt.obj.dur == 2.0)
end)

Case("target bar: a physical hit taken while targeted restarts it", function()
    local _, log = Session({ enabled = true, targetSwing = true })
    assert(log.events.events.UNIT_COMBAT)
    local tgt = log.bars[4]
    log.Fire("UNIT_COMBAT", "player", "WOUND", "", 120, 4)
    assert(tgt.obj.dur == 1, "a spell hit does not count")
    log.Fire("UNIT_COMBAT", "player", "DODGE", "", 0, 1)
    assert(tgt.obj.start == 100 and tgt.obj.dur == 2.0)
end)

Case("target bar: hits while the target is on someone else do not count", function()
    local _, log = Session({ enabled = true, targetSwing = true }, { onMe = false })
    log.Fire("UNIT_COMBAT", "player", "WOUND", "", 120, 1)
    assert(log.bars[4].obj.dur == 1)
end)

Case("target bar: parry haste takes 40% off, then floors at 20%", function()
    local _, log = Session({ enabled = true, targetSwing = true })
    local tgt = log.bars[4]
    log.Fire("UNIT_COMBAT", "player", "WOUND", "", 120, 1)   -- swing 100 -> 102
    log.now = 100.2
    log.Fire("UNIT_COMBAT", "target", "PARRY", "", 0, 1)     -- 1.8 left -> 1.0
    assert(math.abs(tgt.obj.start + tgt.obj.dur - 101.2) < 1e-9)
    log.now = 100.3
    log.Fire("UNIT_COMBAT", "target", "PARRY", "", 0, 1)     -- 0.9 left -> 0.4
    assert(math.abs(tgt.obj.start + tgt.obj.dur - 100.7) < 1e-9)
end)

Case("turning an aid off drops its events", function()
    local _, log = Session({ enabled = true, castClip = true })
    assert(log.events.events.UNIT_SPELLCAST_START)
    log.Set("castClip", false)
    assert(not log.events.events.UNIT_SPELLCAST_START)
end)

Case("the Auto Shot window registers movement for hunters only", function()
    local _, war = Session({ enabled = true, autoShotWindow = true })
    assert(not war.events.events.PLAYER_STARTED_MOVING)
    local _, hunter = Session({ enabled = true, autoShotWindow = true }, { class = "HUNTER" })
    assert(hunter.events.events.PLAYER_STARTED_MOVING)
end)

Case("turning the module off stops everything", function()
    local _, log = Session({ enabled = true })
    log.Fire("PLAYER_SWING", 2.6, 0)
    log.Set("enabled", false)
    assert(next(log.events.events) == nil and log.Live() == 0)
    assert(log.bars[1].obj.dur == 1, "the running swing is parked")
end)

Case("a weapon swap mid-swing restarts the swing at the new weapon's speed", function()
    local speeds = { 3.8, nil, nil }
    local _, log = Session({ enabled = true }, { speeds = speeds })
    log.Fire("PLAYER_SWING", 3.8, 0)
    log.now = 101
    speeds[1] = 2.6
    log.Fire("WEAPON_SLOT_CHANGED")
    local mh = log.bars[1]
    assert(mh.obj.start == 101 and mh.obj.dur == 2.6)
end)

Case("Hide When Idle hides when a target change stops the only running bar", function()
    local _, log = Session({ enabled = true, targetSwing = true, hideWhenIdle = true,
        visibility = "combat" })
    local container = log.bars[1].parent.parent
    log.Fire("PLAYER_REGEN_DISABLED")
    log.Fire("UNIT_COMBAT", "player", "WOUND", "", 120, 1)
    assert(container.shown)
    log.Fire("PLAYER_TARGET_CHANGED")
    assert(not container.shown)
end)

Case("Show Always keeps idle bars up even with Hide When Idle on", function()
    local _, log = Session({ enabled = true, hideWhenIdle = true, visibility = "always" })
    assert(log.bars[1].parent.parent.shown)
end)

Case("turning the module off during Unlock Mode takes its sample bars away", function()
    local _, log = Session({ enabled = true })
    log.unlock()
    local container = log.bars[1].parent.parent
    assert(container.shown)
    log.Set("enabled", false)
    assert(not container.shown)
end)

Case("a dead target has no Target bar", function()
    local _, log = Session({ enabled = true, targetSwing = true }, { dead = true })
    assert(not log.bars[4].parent.shown)
end)

-- A paladin's seals: every rank of a seal shares its name.
local SEAL_NAMES = { [20375] = "Seal of Command", [20915] = "Seal of Command", [20154] = "Seal of Righteousness",
    [20271] = "Judgement", [407798] = "Seal of Martyrdom" }

local function BarColor(log)
    local c = log.bars[1].tex.color
    return ("%.2f %.2f %.2f"):format(c[1], c[2], c[3])
end

Case("seal colors are off by default and listen to nothing", function()
    local _, log = Session({ enabled = true }, { class = "PALADIN", names = SEAL_NAMES })
    local e = log.events.events
    assert(not e.UNIT_SPELLCAST_SUCCEEDED and not e.UNIT_AURA)
end)

Case("a seal cast colors the melee bars, any rank, and a Judgement leaves it up", function()
    local _, log = Session({ enabled = true, sealColors = true }, { class = "PALADIN", names = SEAL_NAMES })
    local e = log.events.events
    assert(e.UNIT_SPELLCAST_SUCCEEDED and e.UNIT_AURA)
    assert(BarColor(log) == "0.40 0.85 0.94", "main hand color at first: " .. BarColor(log))
    log.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 20915)
    assert(BarColor(log) == "0.75 0.35 0.95", "Seal of Command, rank 2: " .. BarColor(log))
    log.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 20271)
    assert(BarColor(log) == "0.75 0.35 0.95", "Judgement kept it: " .. BarColor(log))
end)

Case("a restricted spell ID changes nothing", function()
    local _, log = Session({ enabled = true, sealColors = true }, { class = "PALADIN", names = SEAL_NAMES })
    log.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 20154)
    log.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", SECRET)
    assert(BarColor(log) == "0.95 0.85 0.40", "still Righteousness: " .. BarColor(log))
end)

Case("out of combat the buffs say which seal is up, unless they are kept secret", function()
    local auras = { { name = "Blessing of Might" }, { name = "Seal of Command" } }
    local _, log = Session({ enabled = true, sealColors = true },
        { class = "PALADIN", names = SEAL_NAMES, auras = auras })
    assert(BarColor(log) == "0.75 0.35 0.95", "read at login: " .. BarColor(log))
    local _, hidden = Session({ enabled = true, sealColors = true },
        { class = "PALADIN", names = SEAL_NAMES, auras = auras, secretAuras = true })
    assert(BarColor(hidden) == "0.40 0.85 0.94", "not read while secret: " .. BarColor(hidden))
end)

Case("Seal of Martyrdom has a color of its own", function()
    local _, log = Session({ enabled = true, sealColors = true }, { class = "PALADIN", names = SEAL_NAMES })
    log.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 407798)
    assert(BarColor(log) == "0.90 0.40 0.70", "Martyrdom: " .. BarColor(log))
end)

Case("a seal that runs out in combat takes its color with it", function()
    local _, log = Session({ enabled = true, sealColors = true }, { class = "PALADIN", names = SEAL_NAMES })
    log.Fire("PLAYER_REGEN_DISABLED")
    local cast = log.now
    log.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 20375)
    log.Advance(cast + 29)
    assert(BarColor(log) == "0.75 0.35 0.95", "still up at 29s: " .. BarColor(log))
    log.Advance(cast + 30.1)
    assert(BarColor(log) == "0.40 0.85 0.94", "gone at 30s: " .. BarColor(log))
end)

Case("a Judgement in combat keeps the seal and its count", function()
    local _, log = Session({ enabled = true, sealColors = true }, { class = "PALADIN", names = SEAL_NAMES })
    log.Fire("PLAYER_REGEN_DISABLED")
    local cast = log.now
    log.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 20375)
    log.now = cast + 5
    log.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 20271)
    log.Advance(cast + 29)
    assert(BarColor(log) == "0.75 0.35 0.95", "still up at 29s: " .. BarColor(log))
    log.Advance(cast + 30.1)
    assert(BarColor(log) == "0.40 0.85 0.94", "gone at 30s: " .. BarColor(log))
end)

Case("recasting a seal starts its count again, and a new seal replaces it", function()
    local _, log = Session({ enabled = true, sealColors = true }, { class = "PALADIN", names = SEAL_NAMES })
    log.Fire("PLAYER_REGEN_DISABLED")
    local cast = log.now
    log.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 20375)
    log.now = cast + 20
    log.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 20375)
    log.Advance(cast + 40)
    assert(BarColor(log) == "0.75 0.35 0.95", "recast at 20s, up at 40s: " .. BarColor(log))
    log.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 20154)
    log.Advance(cast + 50.5)
    assert(BarColor(log) == "0.95 0.85 0.40", "the old count did not clear the new seal: " .. BarColor(log))
end)

Case("a seal buff that can be read sets how long seals last", function()
    local auras = { { name = "Seal of Command", duration = 34 } }
    local _, log = Session({ enabled = true, sealColors = true },
        { class = "PALADIN", names = SEAL_NAMES, auras = auras })
    auras[1].expirationTime = log.now + 10
    log.Fire("UNIT_AURA", "player")
    local read = log.now
    log.Advance(read + 10.1)
    assert(BarColor(log) == "0.40 0.85 0.94", "ran out when its buff said: " .. BarColor(log))
    auras[1] = nil
    log.Fire("PLAYER_REGEN_DISABLED")
    local cast = log.now
    log.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 20375)
    log.Advance(cast + 32)
    assert(BarColor(log) == "0.75 0.35 0.95", "34s learned from the buff: " .. BarColor(log))
    log.Advance(cast + 34.1)
    assert(BarColor(log) == "0.40 0.85 0.94", "gone at 34s: " .. BarColor(log))
end)

Case("seal colors on a warrior listen to nothing", function()
    local _, log = Session({ enabled = true, sealColors = true }, { names = SEAL_NAMES })
    assert(not log.events.events.UNIT_AURA and not log.events.events.UNIT_SPELLCAST_SUCCEEDED)
end)

Case("the bar text keeps today's look until a setting changes it", function()
    local _, log = Session({ enabled = true })
    local tag = log.bars[1].parent.tag
    assert(tag.font == "" and tag.size == 11 and tag.outline == "OUTLINE")
    assert(log.texture == "", "the flat fill by default")
    log.Set("font", "Naowh")
    log.Set("outline", "")
    log.Set("textSize", 14)
    assert(tag.font == "Naowh" and tag.size == 14 and tag.outline == "")
    log.Set("texture", "Solid")
    assert(log.texture == "Solid")
end)

Case("a queued attack colors the melee bars and names itself on them", function()
    local current = {}
    local _, log = Session({ enabled = true }, { speeds = { 2.6, 1.8, nil }, current = current })
    local mh, oh = log.bars[1], log.bars[2]
    current.Spell78 = true
    log.Fire("ACTIONBAR_UPDATE_STATE")
    assert(BarColor(log) == "1.00 0.70 0.20", "Heroic Strike: " .. BarColor(log))
    assert(mh.parent.tag.text == "MH - Spell78" and oh.parent.tag.text == "OH - Spell78")
    current.Spell78, current.Spell845 = nil, true
    log.Fire("ACTIONBAR_UPDATE_STATE")
    assert(BarColor(log) == "0.97 0.44 0.44", "Cleave has its own: " .. BarColor(log))
    current.Spell845 = nil
    log.Fire("ACTIONBAR_UPDATE_STATE")
    assert(BarColor(log) == "0.40 0.85 0.94" and mh.parent.tag.text == "MH")
end)

Case("a restricted queued answer is not a queued attack", function()
    local _, log = Session({ enabled = true }, { current = { Spell78 = SECRET } })
    log.Fire("ACTIONBAR_UPDATE_STATE")
    assert(BarColor(log) == "0.40 0.85 0.94" and log.bars[1].parent.tag.text == "MH")
end)

Case("out of range fades the bar and reds its text; no answer is not out of range", function()
    local _, log = Session({ enabled = true }, { within = { [0] = false } })
    local mh = log.bars[1].parent
    assert(mh.alpha == 0.4, "dimmed at login")
    assert(mh.time.textColor[1] > 0.9 and mh.time.textColor[2] < 0.5)
    log.Fire("PLAYER_SWING_RANGE_UPDATE", 0, true, true)
    assert(mh.alpha == 1 and mh.time.textColor[2] == 1)
    log.Fire("PLAYER_SWING_RANGE_UPDATE", 0, false, true)
    assert(mh.alpha == 0.4)
    log.Fire("PLAYER_SWING_RANGE_UPDATE", 0, false, false)
    assert(mh.alpha == 1, "no range checked")
    local _, none = Session({ enabled = true })
    assert(none.bars[1].parent.alpha == 1, "nil from the API")
end)

Case("an off hand swing shows its bar while its speed reads restricted", function()
    local _, log = Session({ enabled = true }, { speeds = { 2.6, SECRET, nil } })
    local oh = log.bars[2]
    assert(not oh.parent.shown)
    log.Fire("PLAYER_SWING", 1.8, 1)
    assert(oh.parent.shown and oh.obj.dur == 1.8)
end)

print(("%d cases passed"):format(count))

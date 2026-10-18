-- Run with Lua 5.1 from the repository root: the campfire reminder's two looks, loaded from the
-- real Shared files, AuraBuffs and Campfire against stubs that measure text in the Naowh font's
-- own widths. Round stays the default and the Simple bar is built only once picked. The bonuses
-- come from the camp features' own auras, else from Camp Benefits' tooltip, read once per Camp
-- Benefits and matched by the client's own feature names, with every amount (the Lute's three,
-- the Mana Well's mana and period). The bar is one rectangle with the fire inside it, sized from
-- its height; every state keeps the fire and the words in one place; the width never drops under
-- what four wide bonuses need at the text size, nor the text under 11; the card's preview edits
-- the bar from a fixed spot; its rows follow the style; and a refresh makes no garbage. The Camp
-- Nearby alert is the same bar, fading in, breathing while shown and stopping when hidden, with
-- an editable preview. Both looks share one saved spot, the Round icon's centre on the bar's fire,
-- converted from the settings when placed, so switching styles never drifts. With Simple the alert
-- shows while the camp is still up and low, and the bar's own pill covers it once gone. While
-- resting, every bar setting repaints the live bar at once. A feature's own aura and the tooltip
-- merge, and an empty tooltip is tried again every few seconds until it lists something. The bare
-- alert is sized to its words with the time inline, at the bottom of the Alerts group, and a right-click hides
-- it until you leave the campfire while left clicks pass through.
rawset(_G, "C_AddOns", { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end })

local Load = dofile("Tools/regression/load_files.lua")
-- The AuraBuffs files the Campfire reminder and its cards are made of, in AuraBuffs.xml's order.
local CAMP_FILES = { "Core/Features.lua", "NaowhForever_Combat/AuraBuffs/AuraBuffs.lua",
    "NaowhForever_Combat/AuraBuffs/Constants.lua", "NaowhForever_Combat/AuraBuffs/Data/Campfire.lua", "NaowhForever_Combat/AuraBuffs/CampReader.lua",
    "NaowhForever_Combat/AuraBuffs/View/Style.lua", "NaowhForever_Combat/AuraBuffs/View/Glow.lua", "NaowhForever_Combat/AuraBuffs/View/CampIcon.lua",
    "NaowhForever_Combat/AuraBuffs/View/CampBar.lua", "NaowhForever_Combat/AuraBuffs/View/CampAlert.lua",
    "NaowhForever_Combat/AuraBuffs/UI/SettingsPage.lua", "NaowhForever_Combat/AuraBuffs/UI/GlowRows.lua", "NaowhForever_Combat/AuraBuffs/UI/Campfire.lua",
    "NaowhForever_Combat/AuraBuffs/UI/CampfireCards.lua" }
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Measure = dofile("Tools/regression/measure.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local CAMP, NEARBY, SITTING, SITTING_CRAFT = 1229741, 1283391, 1229739, 1289723
local TENT, WHEEL, KIT, CANDLE, BANNER, BOWL = 1229451, 1230172, 1230124, 1229513, 1229718, 1230098
local LUTE, LODESTONE, SPELL, CHAIR, WELL, DISENCHANT = 1230653, 1230164, 1230552, 1229519, 1230587, 1283701
local SECRET_TEXT = "Secret: hidden text"
local WIDE_COLON = "\239\188\154"

-- The Naowh font's advance widths, characters 32 to 126, per 1000 units of its size
-- (Core/Media/Fonts/Naowh.ttf).
local ADVANCE = {
    295, 277, 325, 555, 555, 837, 684, 218, 407, 407, 573, 600, 208, 353, 208, 499, 537, 316, 527, 544,
    570, 550, 553, 476, 534, 553, 208, 208, 583, 579, 583, 518, 760, 683, 580, 782, 738, 530, 492, 837,
    671, 258, 483, 611, 450, 935, 738, 846, 570, 837, 604, 501, 407, 646, 684, 906, 649, 590, 465, 407,
    499, 407, 600, 500, 555, 692, 687, 627, 686, 642, 277, 697, 624, 236, 240, 529, 236, 970, 624, 674,
    685, 685, 320, 432, 282, 623, 527, 785, 530, 574, 425, 333, 555, 333, 650,
}
local DOT_ADVANCE = 277

local function Plain(text)
    return (text:gsub("{%a+:", ""):gsub("}", ""))
end

local function W(text, size)
    local units, plain, i = 0, Plain(text), 1
    while i <= #plain do
        local byte = plain:byte(i)
        if byte == 194 then
            units, i = units + DOT_ADVANCE, i + 2
        else
            units, i = units + (ADVANCE[byte - 31] or 600), i + 1
        end
    end
    return units * (size or 12) / 1000
end

local NAMES = { [TENT] = "Tent", [WHEEL] = "Sharpening Wheel", [KIT] = "First Aid Kit", [CANDLE] = "Incense Candle",
    [BANNER] = "Faction Banner", [BOWL] = "Fish Bowl", [LUTE] = "Enchanted Lute", [LODESTONE] = "Lodestone",
    [SPELL] = "Boosted Spell Power", [CHAIR] = "Camp Chair", [WELL] = "Mana Well",
    [DISENCHANT] = "Boosted Disenchanting" }

local TEMPLATE = {
    "Gained the following camp benefits:",
    "Tent: You received a small amount of rest experience. You can only receive this effect once per 1 hour.",
    "Sharpening Wheel: Strength increased by 34.",
    "First Aid Kit: Stamina increased by 56.",
    "Incense Candle: Intellect increased by 25.",
    "Faction Banner: Spirit increased by 32.",
    "Fish Bowl: All stats increased by 8%.",
    "Enchanted Lute: Armor increased by 308, all attributes increased by 13, and all resistances increased by 22.",
    "Lodestone: Melee attack power increased by 90.",
    "Boosted Spell Power: Spell damage increased by 23 and healing increased by 23.",
    "Camp Chair: Critical strike chance with all spells and attacks increased by 2%.",
    "Mana Well: Restores 29 Mana every 5 seconds.",
    "Boosted Disenchanting: Disenchanting gives more materials.",
}

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

local function Fixture(settings)
    local state = { now = 1000, auras = {}, frames = {}, named = {}, timers = {}, bars = 0, tips = {},
        emotes = {}, glows = {}, tooltipReads = 0, secret = false, combat = false, cursorX = 0, cursorY = 0, shift = false, menus = 0,
        groups = {},
        tooltip = { lines = { { leftText = "Camp Benefits" } } }, spellNames = {} }
    for id, name in pairs(NAMES) do state.spellNames[id] = name end
    local widths = {}
    local function Width(text, size)
        local bySize = widths[size]
        if not bySize then bySize = {}; widths[size] = bySize end
        local w = bySize[text]
        if not w then w = W(text, size); bySize[text] = w end
        return w
    end
    local NOTHING = function() end
    local Frame
    local METHODS = {
        SetScript = function(f, script, fn) f.scripts[script] = fn end,
        GetScript = function(f, script) return f.scripts[script] end,
        HookScript = function(f, script, fn) f.scripts[script] = fn end,
        RegisterEvent = function(f, event) f.events[event] = true end,
        RegisterUnitEvent = function(f, event) f.events[event] = true end,
        UnregisterEvent = function(f, event) f.events[event] = nil end,
        UnregisterAllEvents = function(f) for event in pairs(f.events) do f.events[event] = nil end end,
        GetParent = function(f) return rawget(f, "parent") end,
        SetWidth = function(f, w) f.w = w end,
        SetHeight = function(f, h) f.h = h end,
        SetSize = function(f, w, h) f.w, f.h = w, h end,
        RegisterForClicks = function(f, ...) f.clicks = { ... } end,
        SetScale = function(f, scale) f.scale = scale end,
        GetScale = function(f) return rawget(f, "scale") or 1 end,
        SetPassThroughButtons = function(f, ...) f.passThrough = { ... } end,
        GetWidth = function(f) return rawget(f, "w") or 600 end,
        GetHeight = function(f) return rawget(f, "h") or 230 end,
        SetPoint = function(f, a, rel, _, d, e) f.pt[a], f.pty[a], f.rel[a] = d or 0, e or 0, rel end,
        ClearAllPoints = function() end,
        SetAllPoints = function(f, rel) f.all = rel or true end,
        SetTexCoord = function(f, l, r, t, b) f.coords = { l, r, t, b } end,
        GetTexCoord = function(f) return unpack(f.coords or { 0, 1, 0, 1 }) end,
        SetBlendMode = function(f, mode) f.blend = mode end,
        SetShadowColor = function(f, _, _, _, a) f.shadow = a end,
        GetCenter = function(f) return rawget(f, "cx"), rawget(f, "cy") end,
        GetLeft = function(f) return rawget(f, "left") end,
        SetText = function(f, text) f.text = text end,
        GetText = function(f) return rawget(f, "text") or "" end,
        SetTextColor = function(f, r, g, b) f.r, f.g, f.b = r, g, b end,
        GetStringWidth = function(f) return Width(rawget(f, "text") or "", rawget(f, "size") or 12) end,
        SetFont = function(f, path, size, outline) f.font, f.path, f.size, f.outline, f.flags = path, path, size, outline, outline end,
        SetAlpha = function(f, a) f.alpha = a end,
        SetCooldownFromExpirationTime = function(f, expiry, duration)
            f.cooldownExpiry, f.cooldownDuration = expiry, duration
        end,
        SetDesaturated = function(f, on) f.desaturated = on end,
        SetVertexColor = function(f, r, g, b, a) f.r, f.g, f.b, f.a = r, g, b, a end,
        SetColorTexture = function(f, r, g, b, a) f.r, f.g, f.b, f.a = r, g, b, a end,
        SetGradient = function(f, _, from, to) f.from, f.to = from, to end,
        SetTexture = function(f, texture) f.texture = texture end,
        Show = function(f) f.shown = true end,
        Hide = function(f) f.shown = false end,
        SetShown = function(f, shown) f.shown = shown and true or false end,
        IsShown = function(f) return rawget(f, "shown") ~= false end,
        IsVisible = function(f) return rawget(f, "shown") ~= false end,
        IsMouseOver = function(f) return rawget(f, "over") == true end,
        EnableMouse = function(f, on) f.mouse = on end,
        GetFrameLevel = function(f) return rawget(f, "level") or 1 end,
        SetFrameLevel = function(f, level) f.level = level end,
        GetEffectiveScale = function() return 1 end,
        SetValue = function(f, v) f.value = v end,
        SetTimerDuration = function(f, dur, _, direction) f.dur, f.direction = dur, direction end,
        GetValue = function(f)
            local dur = rawget(f, "dur")
            if not dur then return rawget(f, "value") or 0 end
            local left = math.max(0, dur.start + dur.length - state.now) / dur.length
            return f.direction == 1 and left or 1 - left
        end,
        GetStatusBarTexture = function(f)
            local fill = rawget(f, "fill")
            if not fill then fill = Frame(f); f.fill = fill end
            return fill
        end,
        CreateTexture = function(f) return Frame(f) end,
        CreateMaskTexture = function(f) return Frame(f) end,
        CreateFontString = function(f) return Frame(f) end,
        CreateAnimationGroup = function(f)
            local group = { owner = f, playing = false, plays = 0, scripts = {} }
            function group.CreateAnimation(g)
                g.anim = setmetatable({}, { __index = function(anim, key)
                    return function(_, v) anim[key .. "Value"] = v end
                end })
                return g.anim
            end
            function group.SetLooping(g, mode) g.looping = mode end
            function group.SetToFinalAlpha(g, on) g.final = on end
            function group.SetScript(g, script, fn) g.scripts[script] = fn end
            function group.IsPlaying(g) return g.playing end
            function group.Stop(g) g.playing = false end
            function group.Play(g)
                g.plays = g.plays + 1
                g.playing = true
                if not g.looping and g.scripts.OnFinished then
                    g.playing = false
                    g.scripts.OnFinished(g)
                end
            end
            state.groups[#state.groups + 1] = group
            return group
        end,
    }
    setmetatable(METHODS, { __index = function(_, key)
        if type(key) == "string" and key:find("^%u") then return NOTHING end
    end })
    local META = { __index = METHODS }
    function Frame(parent, name)
        local f = setmetatable({ scripts = {}, events = {}, parent = parent, pt = {}, pty = {}, rel = {} }, META)
        state.frames[#state.frames + 1] = f
        if name then state.named[name] = f end
        return f
    end

    local COLOR_META = { __index = { SetRGBA = function(c, r, g, b, a) c.r, c.g, c.b, c.a = r, g, b, a end } }
    local DURATION_META = { __index = { SetTimeFromStart = function(d, start, length)
        d.start, d.length = start, length
    end } }
    local BINDING_META = { __index = function(_, key)
        if key == "SetFontString" then return function(b, fs) b.fontString = fs end end
        if key == "SetEnabled" then return function(b, on) b.enabled = on end end
        if key == "SetFormatter" then return function(b, fmt) b.formatter = fmt end end
        return NOTHING
    end }

    local T = { fg = { r = 0.9, g = 0.9, b = 0.9 }, muted = { r = 0.6, g = 0.6, b = 0.6 },
        accent = { r = 0, g = 0.5, b = 0.9 }, accentSoft = { r = 0.3, g = 0.7, b = 0.9 },
        line = { r = 0.2, g = 0.2, b = 0.2 }, panel = { r = 0.1, g = 0.1, b = 0.1 },
        bg = { r = 0.05, g = 0.05, b = 0.05 }, grey = { r = 0.2, g = 0.2, b = 0.2 } }
    local values, defaults = settings or {}, {}
    -- Written against the camp icon's original defaults.
    for k, v in pairs({ campShowUnder = false, campIconSize = 64, campBuffSide = "below" }) do
        if values[k] == nil then values[k] = v end
    end
    local S = { Get = function(k) return values[k] end, Set = function(k, v) values[k] = v end,
        Raw = function(k) return values[k] end, Default = function(k) return defaults[k] end }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"),
        THEME = T,
        Color = function(token, text) return "{" .. token .. ":" .. tostring(text) .. "}" end,
        Font = function(parent, size, flags, color)
            local fs = Frame(parent)
            fs.flags, fs.size = flags, size
            local c = color or T.fg
            fs.r, fs.g, fs.b = c.r, c.g, c.b
            return fs
        end,
        Solid = function(parent, _, color) local t = Frame(parent); t.color = color; return t end,
        ThemeTint = function(_, literal) return literal end,
        Hairline = function(region) return region end,
        PixelInset = function(region) return region end,
        OnePixel = function() return 1 end,
        Border = function(frame) return { _frame = Frame(frame), SetColor = NOTHING } end,
        AccentBorder = function() return { SetColor = NOTHING } end,
        Button = function(parent) return Frame(parent) end,
        UIFontPath = function() return "font" end,
        AccountSettings = function() return {} end,
        Apply = NOTHING, ShowUnlockMode = NOTHING, HideUnlockMode = NOTHING,
        AlertStack = function(frame, order) state.stacked = { frame = frame, order = order } end,
        UI = {
            Keep = function(parent, key, make)
                local kept = rawget(parent, key)
                if not kept then kept = make(parent); parent[key] = kept end
                return kept
            end,
            AttachMover = function(frame, _, onMoved)
                local mover = Frame(frame)
                mover.onMoved = onMoved
                return mover
            end,
            ModuleSettings = function(_, given)
                for key, value in pairs(given) do
                    defaults[key] = value
                    if values[key] == nil then values[key] = value end
                end
                return S
            end,
            _PlayLSMSound = NOTHING, SoundPathFor = NOTHING,
            FontPath = function(name) return name and name ~= "" and "lsm:" .. name or "font" end,
        },
    }
    local tooltip = Frame()
    tooltip.SetOwner = function(_, owner) state.tips = { owner = owner } end
    tooltip.SetText = function(_, text) state.tips[#state.tips + 1] = { text } end
    tooltip.AddLine = function(_, text) state.tips[#state.tips + 1] = { text } end
    tooltip.AddDoubleLine = function(_, left, right) state.tips[#state.tips + 1] = { left, right } end
    local env = setmetatable({
        NaowhForever = ns,
        CreateFrame = function(kind, name, parent)
            if kind == "StatusBar" then state.bars = state.bars + 1 end
            return Frame(parent, name)
        end,
        Mixin = function(target, ...)
            for i = 1, select("#", ...) do
                for k, v in pairs((select(i, ...))) do target[k] = v end
            end
            return target
        end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        hooksecurefunc = function(t, key, callback)
            local orig = t[key]; t[key] = function(...) orig(...); callback(...) end
        end,
        CreateColor = function(r, g, b, a) return setmetatable({ r = r, g = g, b = b, a = a }, COLOR_META) end,
        GetTime = function() return state.now end,
        GetCursorPosition = function() return state.cursorX, state.cursorY end,
        IsShiftKeyDown = function() return state.shift end,
        IsControlKeyDown = function() return state.ctrl end,
        InCombatLockdown = function() return state.combat end,
        IsInInstance = function() return false end,
        issecretvalue = function(v) return v == SECRET_TEXT or (state.secret and v == 2) end,
        C_Secrets = { ShouldAurasBeSecret = function() return false end },
        C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return state.auras[id] end },
        C_ChatInfo = { PerformEmote = function(token) state.emotes[#state.emotes + 1] = token end },
        LibStub = function()
            return {
                PixelGlow_Start = function(frame, color, lines, frequency, length, thickness)
                    state.glows[frame] = { kind = "pixel", color = color, lines = lines, frequency = frequency,
                        length = length, thickness = thickness }
                end,
                PixelGlow_Stop = function(frame) state.glows[frame] = nil end,
                ButtonGlow_Start = function(frame, color) state.glows[frame] = { kind = "standard", color = color } end,
                ButtonGlow_Stop = function(frame) state.glows[frame] = nil end }
        end,
        C_Spell = { GetSpellTexture = function(id) return id end,
            GetSpellName = function(id) return state.spellNames[id] end },
        C_TooltipInfo = { GetUnitBuffByAuraInstanceID = function()
            state.tooltipReads = state.tooltipReads + 1
            return state.tooltip
        end },
        C_Timer = { After = function(delay, fn)
            state.timers[#state.timers + 1] = { at = state.now + delay, fn = fn }
        end },
        C_DurationUtil = {
            CreateDuration = function() return setmetatable({}, DURATION_META) end,
            CreateDurationTextBinding = function() return setmetatable({}, BINDING_META) end,
        },
        C_StringUtil = { CreateNumericRuleFormatter = function()
            return { SetBreakpoints = function(fmt, points) fmt.points = points end }
        end },
        C_Item = {},
        Enum = {
            StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
            StatusBarInterpolation = { Immediate = 0 },
            NumericRuleFormatRounding = { Nearest = 0, Up = 1, Down = 2 },
        },
        Menu = { GetManager = function() return { IsAnyMenuOpen = function() return false end } end },
        MenuUtil = { CreateContextMenu = function(owner, generator)
            state.menus = state.menus + 1
            state.menu = { owner = owner, generator = generator }
        end },
        GameTooltip = tooltip,
        GameTooltip_Hide = NOTHING,
        UIParent = Frame(),
    }, { __index = _G })
    env._G = env
    local files = TocFiles("^Shared/.*%.lua$")
    for _, file in ipairs(CAMP_FILES) do files[#files + 1] = file end
    Load(files, env)
    state.ns, state.S, state.T, state.values, state.Frame = ns, ns.AuraBuffSettings, T, values, Frame
    state.St = ns.Shared.Style
    function state.fire(event)
        for i = 1, #state.frames do
            local f = state.frames[i]
            if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event) end
        end
    end
    function state.listener(event)
        for i = 1, #state.frames do
            local f = state.frames[i]
            if f.events[event] and f.scripts.OnEvent then return f, f.scripts.OnEvent end
        end
    end
    function state.advance(seconds)
        state.now = state.now + seconds
        local due = true
        while due do
            due = false
            for i, t in ipairs(state.timers) do
                if t.at <= state.now then
                    table.remove(state.timers, i)
                    t.fn()
                    due = true
                    break
                end
            end
        end
    end
    function state.bar()
        for i = 1, #state.frames do
            local f = state.frames[i]
            if rawget(f, "line") and rawget(f, "labels") and f.parent == state.named.NaowhForeverCampfire then
                return f
            end
        end
    end
    function state.labels(bar, raw)
        local out = {}
        for i = 1, bar.labels.count do
            local text = bar.labels.labels[i].text
            out[i] = raw and text or Plain(text)
        end
        return table.concat(out, " ")
    end
    function state.tipText()
        local out = {}
        for i, line in ipairs(state.tips) do out[i] = line[1] .. (line[2] and " | " .. line[2] or "") end
        return table.concat(out, "\n")
    end
    function state.camp(lines, instance)
        local tip = { { leftText = "Camp Benefits" } }
        for i, text in ipairs(lines) do tip[i + 1] = { leftText = text } end
        tip[#tip + 1] = { leftText = "56 minutes remaining" }
        state.tooltip = { lines = tip }
        state.auras[CAMP] = { duration = 3600, expirationTime = state.now + 3360, auraInstanceID = instance or 1 }
        state.fire("UNIT_AURA")
    end
    function state.menuEntries()
        local entries = {}
        local function Root()
            local root = {}
            local function Add(kind)
                return function(_, text) entries[#entries + 1] = kind .. ":" .. text; return Root() end
            end
            root.CreateTitle, root.CreateRadio, root.CreateCheckbox = Add("title"), Add("radio"), Add("check")
            root.CreateButton, root.CreateDivider = Add("button"), function() end
            return root
        end
        state.menu.generator(state.menu.owner, Root())
        return table.concat(entries, "\n")
    end
    return state
end

local function Same(c, want) return c.r == want.r and c.g == want.g and c.b == want.b end
local function Aura(points) return { points = points } end

-- An existing two-hour buff can have begun before the current clock's origin after a relog.
do
    local s = Fixture()
    s.auras[CAMP] = { duration = 7200, expirationTime = s.now + 1320, auraInstanceID = 1 }
    s.fire("PLAYER_LOGIN")
    local icon = s.named.NaowhForeverCampfire
    check("relog: the old buff would have a negative reconstructed start",
        s.auras[CAMP].expirationTime - s.auras[CAMP].duration < 0)
    check("relog: the countdown uses the aura deadline, with 22 minutes left",
        icon.timer.cooldownExpiry == s.now + 1320 and icon.timer.cooldownDuration == 7200)
    check("relog: the ring uses the same deadline and full duration",
        icon.drain.cooldownExpiry == icon.timer.cooldownExpiry and icon.drain.cooldownDuration == 7200)
    s.auras[CAMP].expirationTime = 0
    s.fire("UNIT_AURA")
    check("an unavailable deadline does not invent a full-duration timer", not icon.timer.shown and not icon.drain.shown)
    s.auras[CAMP].expirationTime = nil
    s.fire("UNIT_AURA")
    check("a missing deadline leaves the countdown hidden", not icon.timer.shown)
    s.auras[CAMP].expirationTime = s.now + 1200
    s.fire("UNIT_AURA")
    check("the timer recovers when the aura's deadline arrives",
        icon.timer.shown and icon.timer.cooldownExpiry - s.now == 1200)
    s.auras[CAMP].expirationTime = s.now - 1
    s.fire("UNIT_AURA")
    check("an expired deadline does not restart a two-hour timer", not icon.timer.shown)
end

-- Round: the default, its tags from the same reader as the bar.
do
    local s = Fixture()
    s.auras[CAMP] = { duration = 3600, expirationTime = s.now + 2400, auraInstanceID = 1 }
    s.auras[TENT], s.auras[KIT], s.auras[CHAIR] = Aura({ 5 }), Aura({ 56 }), Aura({ 2 })
    s.fire("PLAYER_LOGIN")
    local icon = s.named.NaowhForeverCampfire
    check("the default look is Round", s.S.Get("campStyle") == "round")
    check("Round: no Simple bar built", s.bars == 0 and s.bar() == nil)
    check("Round: the camp icon shows its bonuses, from the features' auras",
        icon.shown and icon.buffs.text == "+Rested\n+STA\n+Crit" and s.tooltipReads == 1)
    do
        local frame, onEvent = s.listener("UNIT_AURA")
        Measure(check)("a Round refresh", 1, function() onEvent(frame, "UNIT_AURA") end)
    end
    s.auras[TENT], s.auras[KIT], s.auras[CHAIR] = nil, nil, nil
    local cases = {
        { { "Camp Tent: You received a small amount of rest experience. You can only receive this effect once per 1 hour.",
            "Target Dummy: Critical strike chance with all spells and attacks increased by 2%." }, "+Rested\n+Crit" },
        { { "Dummy: Critical strike chance increased by 2.5%." }, "+Crit" },
        { { "Mana Well: Mana regeneration increased by 5%." }, "+MP5" },
        { { "Mystery Totem: An unfamiliar effect with a very long description." }, "Mystery Totem" },
        { { "Incense Candle: An unfamiliar effect with a very long description." }, "+INT" },
        { { "Faction Banner: Spirit increased by 27." }, "+Spirit" },
        { { "Lodestone: Melee attack power increased by 49." }, "+ATK" },
        { { "Enchanted Lute: Armor increased by 114 and all stats by 7." }, "+MotW" },
        { { "Fish Bowl: All stats increased by 8%." }, "+Stats" },
        { { "Fish Bowl: Strength, Agility, Stamina, Intellect and Spirit increased by 8%." }, "+Stats" },
        { { "Anvil: Strength increased by 20.", "Toxin Study: Stamina increased by 34." }, "+STR\n+STA" },
        { { "|cffffffffCamp Tent: You gained rested experience.|r", "Chair: Rested experience granted." }, "+Rested" },
        { { "Benefits:", "Spell ID: 1229741", "24 |4minute:minutes; remaining", SECRET_TEXT }, "" },
        { { "Mana Well: 10 MP5" }, "+MP5" },
        { { "Mystery Totem: +5 Luck" }, "+5 Luck" },
    }
    for i, case in ipairs(cases) do
        s.camp(case[1], 100 + i)
        check("Round tags " .. i .. ": " .. case[2]:gsub("\n", " "), icon.buffs.text == case[2])
    end
    s.tooltip = nil
    s.auras[CAMP].auraInstanceID = 200
    s.fire("UNIT_AURA")
    check("Round tags: no tooltip data, no tags", icon.buffs.text == "")
end

-- Font and Outline: the Addon Font with no outline until set, on both looks.
do
    local s = Fixture()
    s.auras[CAMP] = { duration = 3600, expirationTime = s.now + 2400, auraInstanceID = 1 }
    s.auras[TENT], s.auras[KIT], s.auras[CHAIR] = Aura({ 5 }), Aura({ 56 }), Aura({ 2 })
    s.fire("PLAYER_LOGIN")
    local icon = s.named.NaowhForeverCampfire
    check("Round: today's text, shadowed", icon.buffs.path == "font" and icon.buffs.flags == ""
        and icon.buffs.size == 16 and icon.label.size == 16 and icon.buffs.shadow > 0)
    s.S.Set("campFont", "Naowh")
    s.S.Set("campOutline", "OUTLINE")
    check("Round: Font and Outline on the bonuses and the label", icon.buffs.path == "lsm:Naowh"
        and icon.buffs.flags == "OUTLINE" and icon.label.path == "lsm:Naowh" and icon.buffs.shadow == 0)
    s.S.Set("campStyle", "simple")
    local bar = s.bar()
    check("Simple: the Font but its own Outline, plain by default", bar.time.path == "lsm:Naowh"
        and bar.time.flags == "" and bar.time.shadow == 0 and bar.labels.labels[1].path == "lsm:Naowh")
    s.S.Set("campBarOutline", "OUTLINE")
    check("Simple: the bar's words and bonuses take its Outline", bar.time.path == "lsm:Naowh"
        and bar.time.flags == "OUTLINE" and bar.labels.labels[1].path == "lsm:Naowh"
        and bar.labels.labels[3].flags == "OUTLINE")
    s.S.Set("campFont", "")
    s.S.Set("campOutline", "")
    s.S.Set("campBarOutline", "")
    check("Simple: Shadow shadows the bar", bar.time.shadow > 0 and bar.labels.labels[1].shadow > 0)
    s.S.Set("campBarOutline", "NONE")
    check("Simple: back to the Addon Font, unoutlined", bar.time.path == "font" and bar.time.flags == ""
        and bar.labels.labels[1].path == "font" and bar.labels.labels[1].flags == "")
end

-- Simple, from the features' own auras: the amounts, the seat, the time and its colors.
do
    local s = Fixture()
    s.auras[CAMP] = { duration = 3600, expirationTime = s.now + 2400, auraInstanceID = 1 }
    s.auras[TENT], s.auras[KIT], s.auras[CHAIR] = Aura({ 5 }), Aura({ 56 }), Aura({ 2 })
    s.fire("PLAYER_LOGIN")
    local icon = s.named.NaowhForeverCampfire
    s.S.Set("campStyle", "simple")
    local bar = s.bar()
    check("Simple: built once picked, with one time line", bar ~= nil and s.bars == 1)
    check("Simple: the round art hidden, the bar shown", icon.tex.shown == false and icon.timer.shown == false
        and bar.shown ~= false)
    check("Simple: each bonus with its amount, Rested with none", s.labels(bar) == "Rested +56 Sta +2% Crit"
        and s.tooltipReads == 1)
    check("Simple: the amount in the text color, the stat muted", s.labels(bar, true)
        == "Rested +56 {muted:Sta} +2% {muted:Crit}" and Same(bar.labels.labels[1], s.T.fg))
    local labels = bar.labels.labels
    check("Simple: no dots between bonuses, a named gap instead", bar.labels.seps[2] == nil
        and math.abs(labels[2].pt.LEFT - (W("Rested") + 10)) < 1e-9
        and math.abs(labels[3].pt.LEFT - labels[2].pt.LEFT - W("+56 Sta") - 10) < 1e-9)

    local function Inside(f)
        local half = f.campSize / 2
        local bottom, top = 1 + 2 + 2, f.height - 1 - 2
        local cy = f.height / 2 + f.camp.pty.CENTER
        return f.camp.rel.CENTER == f.bar and f.camp.pt.CENTER - half == 1 + 2
            and cy - half == bottom and cy + half == top and f.camp.parent == f.bar
    end
    check("the fire sits inside the bar at the left, framed, padded and centred above the line",
        bar.campSize == 18 and bar.campX == 12 and Inside(bar) and bar.camp.tex.texture ~= nil)
    check("one plain rectangle: four full edges, no notch, nothing above it", bar.top.pt.TOPLEFT == 0
        and bar.top.pt.TOPRIGHT == 0 and bar.left.pt.TOPLEFT == 0 and rawget(bar, "cap") == nil
        and rawget(bar, "halo") == nil and rawget(bar, "notch") == nil)
    check("the words start a named gap after the fire, a pixel above the line's middle", bar.labelX == 29
        and bar.labels.pt.LEFT == 29 and bar.labels.pty.LEFT == 2 and bar.note.pt.LEFT == 29)
    check("the time sits on the right, inside the bar's padding, level with the words",
        bar.time.pt.RIGHT == -10 and bar.time.pty.RIGHT == 2 and bar.time.rel.RIGHT == bar.bar)
    check("the host is the bar: same width and height, the bar fills it", icon.w == 360 and icon.h == 26
        and bar.all == true and bar.bar.all == true and next(bar.bar.pt) == nil)

    check("the house backdrop and black edge, no custom alpha", bar.backdrop and rawget(bar, "bg") == nil
        and bar.top.color == s.St.BORDER_RGB and s.St.BACKDROP_ALPHA
        and not (function()
            for _, file in ipairs(CAMP_FILES) do
                if Read(file):find("BAR%.ALPHA") then return true end
            end
        end)())
    local behind = 0
    for _, f in ipairs(s.frames) do if f.parent == bar.camp then behind = behind + 1 end end
    local c = bar.camp.tex.coords
    check("the fire is only its art on the bar's backdrop: no plate, mask or ring", behind == 1
        and rawget(bar.camp, "plate") == nil and rawget(bar.camp, "mask") == nil and rawget(bar.camp, "ring") == nil
        and bar.camp.tex.texture ~= nil)
    check("the art's empty margin is cropped to its fire, square", c and c[1] > 0 and c[2] < 1 and c[3] > 0
        and c[4] < 1 and math.abs((c[2] - c[1]) - (c[4] - c[3])) < 1e-3)
    check("panel text: no HUD shadow on the bar's words", (bar.time.shadow or 0) == 0 and (bar.note.shadow or 0) == 0)
    local track
    for _, f in ipairs(s.frames) do if f.parent == bar.line and f.color == s.T.line then track = f end end
    check("the time line runs on a full-width track in the line color", track ~= nil)

    local line = bar.line
    local early = line:GetValue()
    check("the time line runs on its own, counting down what is left",
        line.direction == 1 and math.abs(early - 2400 / 3600) < 1e-6)
    check("the time text is bound to the same timer", line.binding.fontString == bar.time
        and line.binding.enabled == true and bar.time.shown ~= false)
    check("plenty of time: a green line and ring, the time in the text color, no glow",
        Same(line.to, s.St.TIME_OK_RGB) and Same(bar.time, s.T.fg))
    s.advance(700)
    check("the line has shrunk", line:GetValue() < early)
    check("running low: the line, ring and time in yellow, a soft glow", Same(line.to, s.St.TIME_LOW_RGB)
        and Same(bar.time, s.St.TIME_LOW_RGB))
    s.tips = {}
    bar.scripts.OnEnter(bar)
    local text = s.tipText()
    check("tooltip: a title, then each bonus with its amount and its feature", s.tips[1][1] == "Camp Benefits"
        and text:find("+56 Stamina | First Aid Kit", 1, true) and text:find("+2% Critical Strike | Camp Chair", 1, true)
        and text:find("Rested experience | Tent", 1, true))
    check("tooltip: the time left and when to refresh", text:find("Time left | 29 min", 1, true)
        and text:find("Refresh in 24 min", 1, true))
    s.advance(1500)
    check("nearly out: red", Same(line.to, s.St.TIME_OUT_RGB) and Same(bar.time, s.St.TIME_OUT_RGB))
    s.tips = {}
    bar.scripts.OnEnter(bar)
    check("tooltip: refresh now once under five minutes", s.tipText():find("Refresh now", 1, true))
    s.secret = true
    s.fire("UNIT_AURA")
    s.tips = {}
    bar.scripts.OnEnter(bar)
    check("a secret amount is never shown or compared", s.labels(bar) == "Rested +56 Sta Crit"
        and s.tipText():find("Critical Strike | Camp Chair", 1, true) and not s.tipText():find("+2%", 1, true))
    s.secret = false
    s.fire("UNIT_AURA")

    s.S.Set("campSimpleHeight", 30)
    check("the fire grows with Bar Height and stays inside", bar.campSize == 22 and bar.labelX == 33
        and Inside(bar) and icon.h == 30)
    s.S.Set("campSimpleHeight", 20)
    check("the smallest bar still holds the fire inside", bar.campSize == 12 and Inside(bar) and icon.h == 20)
    s.S.Set("campSimpleHeight", 26)

    s.S.Set("campHiddenBonuses", { [CHAIR] = true })
    check("a hidden bonus never draws in game", s.labels(bar) == "Rested +56 Sta")
    s.S.Set("campHiddenBonuses", {})
    s.S.Set("campBonusIcons", true)
    local icons = bar.labels.icons
    check("bonus icons: the feature's own spell icon before each bonus", icons[1].shown ~= false
        and icons[1].texture.texture == TENT and icons[3].texture.texture == CHAIR)
    s.S.Set("campBonusIcons", false)
    check("bonus icons off by default and hidden", icons[1].shown == false)

    local editing = 0
    for _, f in ipairs(s.frames) do if f.scripts.OnMouseWheel then editing = editing + 1 end end
    check("nothing on the live HUD takes the wheel or clicks", editing == 0)

    do
        local frame, onEvent = s.listener("UNIT_AURA")
        Measure(check)("a Simple refresh from the features' auras", 1, function() onEvent(frame, "UNIT_AURA") end)
    end

    s.auras[CAMP], s.auras[TENT], s.auras[KIT], s.auras[CHAIR] = nil, nil, nil, nil
    s.fire("UNIT_AURA")
    check("down: Refresh Camp, the key word in the accent", s.labels(bar) == "" and bar.note.text
        == "{accent:Refresh} Camp" and bar.note.shown ~= false and Same(bar.note, s.T.fg))
    check("down: the bar keeps its full width, the fire and the words where the bonuses start",
        bar.pill and icon.w == 360 and bar.camp.pt.CENTER == 12
        and Inside(bar) and bar.note.pt.LEFT == 29 and icon.h == 26)
    check("down: the fire grey, the time's place empty, no time line", bar.camp.tex.desaturated == true
        and bar.line.shown == false and bar.time.shown == false)
    check("Simple, camp gone: no big Camp Nearby alert", s.named.NaowhForeverCampNearby == nil)
    s.tips = {}
    bar.scripts.OnEnter(bar)
    check("down tooltip: what to do", s.tipText():find("No Camp Benefits", 1, true)
        and s.tipText():find("Sit at a campfire to refresh", 1, true))
    s.auras[NEARBY] = {}
    s.fire("UNIT_AURA")
    check("down with a campfire in range: the same pattern and size, a muted hint after a dot",
        bar.note.text == "{accent:Camp Nearby}{muted:" .. s.St.PLACE_DOT .. "click to sit}"
        and bar.note.pt.LEFT == 29 and icon.w == 360 and icon.h == 26 and bar.time.shown == false)
    check("in range, the bar's fire lights up and takes the click", bar.camp.sitSpot and bar.camp.sitSpot.shown
        and bar.camp.tex.desaturated == false and not (icon.sitSpot and icon.sitSpot.shown))
    check("the whole bar takes the click, not only the fire", bar.camp.sitSpot.all == bar)
    local barSpot = bar.camp.sitSpot
    s.tips = {}
    barSpot.scripts.OnEnter(barSpot)
    local tipped = s.tipText()
    check("hovering it still shows the bar's Camp Benefits tooltip, then how to sit",
        tipped:find("^Camp Benefits") and tipped:find("Click to sit at the campfire.$"))
    local before = #s.emotes
    s.combat = true
    barSpot.scripts.OnClick(barSpot, "LeftButton")
    s.combat = false
    check("in combat a click on it never sits you down", #s.emotes == before)
    barSpot.scripts.OnClick(barSpot, "LeftButton")
    check("out of combat it does", #s.emotes == before + 1)
    s.auras[NEARBY] = nil
    s.fire("UNIT_AURA")

    s.S.Set("campPos", { point = "LEFT", relPoint = "BOTTOMLEFT", x = 288, y = 500 })
    s.S.Set("campStyle", "round")
    local pos = s.S.Get("campPos")
    check("switching to Round centres the icon on the bar's fire", pos.point == "CENTER" and pos.x == 300
        and pos.y == 500 and icon.pt.CENTER == 300)
    check("Round again: the bar hidden, the round art back", bar.shown == false and icon.tex.shown == true
        and icon.label.text == "Refresh Camp")
    check("Round: Refresh Camp in the house text style, a shadow and no outline",
        (icon.label.flags or "") == "" and icon.label.shadow == s.St.HUD_SHADOW_ALPHA)
    s.ns.ShowUnlockMode()
    local alert = s.named.NaowhForeverCampNearby
    local ab = alert and alert.bar
    check("Camp Nearby is the bar's own component: same builder, the click hint after a dot, same sizes", ab
        and ab.backdrop and ab.line and ab.labels
        and Plain(ab.note.text) == "Camp Nearby" .. s.St.PLACE_DOT .. "click to sit"
        and ab.note.size == bar.note.size and ab.campSize == bar.campSize and ab.labelX == bar.labelX
        and rawget(ab.camp, "plate") == nil and rawget(alert, "text") == nil)
    check("Camp Nearby is drawn bare: no backdrop, edge or line, the fire and words alone", ab.bare == true
        and ab.edges.shown == false and ab.line.shown == false)
    check("Camp Nearby is sized to what it says, the bar's height, at the bottom of the Alerts group",
        alert.w == math.ceil(ab.labelX + W(ab.note.text) + 10) and alert.w < bar.width and alert.h == 26
        and s.stacked.frame == alert and s.stacked.order == 1 and rawget(alert, "mover") == nil)
    check("Unlock Mode: the alert takes no clicks, its mover does", alert.click.mouse == false)
    s.ns.HideUnlockMode()
    check("leaving Unlock Mode fades it out, then hides it, its animations stopped", alert.shown == false
        and not alert.breathe.playing and not alert.fadeIn.playing and alert.fadeOut.plays > 0)
    local fadeIns = alert.fadeIn.plays
    s.auras[NEARBY] = {}
    s.fire("UNIT_AURA")
    check("Round: Camp Nearby shows, fading in, then breathing softly while shown", alert.shown == true
        and alert.fadeIn.plays == fadeIns + 1 and alert.breathe.playing and alert.breathe.looping == "BOUNCE"
        and alert.breathe.anim.SetToAlphaValue == 0.6 and alert.fadeIn.anim.SetFromAlphaValue == 0
        and alert.click.mouse == true)
    s.fire("UNIT_AURA")
    check("an aura change while shown does not restart the fade", alert.fadeIn.plays == fadeIns + 1)
    local timers = 0
    for _, f in ipairs(s.frames) do if f.scripts.OnUpdate then timers = timers + 1 end end
    check("no OnUpdate: the client runs the fade", timers == 0)
    check("no camp time to show: the time's place empty, the fire lit to click", ab.time.shown == false
        and ab.camp.tex.desaturated == false and ab.camp.sitSpot and ab.camp.sitSpot.shown)
    s.auras[CAMP] = { duration = 3600, expirationTime = s.now + 90, auraInstanceID = 9 }
    s.fire("UNIT_AURA")
    check("camp still running: its time left in red, inline after a muted dot, the fire lit",
        alert.shown == true and ab.time.shown ~= false and ab.line.binding.enabled == true and ab.slot == ab.timeW
        and Same(ab.time, s.St.TIME_OUT_RGB) and ab.camp.tex.desaturated == false
        and ab.time.rel.LEFT == ab.dot and ab.dot.rel.LEFT == ab.note and ab.dot.shown ~= false
        and ab.dot.text == s.St.PLACE_DOT and Same(ab.dot, s.T.muted)
        and alert.w == math.ceil(ab.labelX + W(ab.note.text) + W(s.St.PLACE_DOT) + ab.timeW + 10))
    check("the Simple bar keeps its time at the right", bar.time.rel.RIGHT == bar.bar and rawget(bar, "dot") == nil)
    s.auras[CAMP] = nil
    s.fire("UNIT_AURA")
    alert.scripts.OnHide(alert)
    check("hidden: every animation stops", not alert.breathe.playing and not alert.fadeIn.playing)
    alert.shown = true
    s.S.Set("campAlertFade", false)
    local played = alert.fadeOut.plays
    s.auras[NEARBY] = nil
    s.fire("UNIT_AURA")
    check("Fade off: it goes at once, no animation", alert.shown == false and alert.fadeOut.plays == played)
    s.auras[NEARBY] = {}
    s.fire("UNIT_AURA")
    check("Fade off: it comes back at once, no breathing", alert.shown == true and not alert.breathe.playing)
    s.S.Set("campAlertFade", true)
    s.S.Set("campStyle", "simple")
    check("Simple: the alert hides, the bar's own pill covers it", alert.shown == false and bar.pill
        and Plain(bar.note.text) == "Camp Nearby" .. s.St.PLACE_DOT .. "click to sit")
    pos = s.S.Get("campPos")
    check("switching to Simple puts the bar's fire where the icon was", pos.point == "LEFT" and pos.x == 288
        and pos.y == 500)
end

do
    local function Fire(s)
        local pos = s.S.Get("campPos")
        if pos.point == "LEFT" then return pos.x + 3 + (s.S.Get("campSimpleHeight") - 8) / 2, pos.y end
        return pos.x, pos.y
    end
    local s = Fixture({ campStyle = "simple", campPos = { point = "CENTER", relPoint = "BOTTOMLEFT", x = 300, y = 500 } })
    s.fire("PLAYER_LOGIN")
    local icon = s.named.NaowhForeverCampfire
    local pos = s.S.Get("campPos")
    check("an old CENTER spot loads in Simple with the fire on it, saved once as LEFT", pos.point == "LEFT"
        and pos.x == 288 and pos.y == 500 and pos.relPoint == "BOTTOMLEFT" and icon.pt.LEFT == 288
        and icon.pty.LEFT == 500 and icon.pt.LEFT + s.bar().campX == 300)
    local drift = false
    for _ = 1, 5 do
        s.S.Set("campStyle", "round")
        local x, y = Fire(s)
        drift = drift or x ~= 300 or y ~= 500 or icon.pt.CENTER ~= 300
        s.S.Set("campStyle", "simple")
        x, y = Fire(s)
        drift = drift or x ~= 300 or y ~= 500 or icon.pt.LEFT ~= 288
    end
    check("Simple, Round, Simple again and again: the same spot, no drift", not drift)
    s.S.Set("campSimpleHeight", 31)
    check("a Bar Height change keeps the bar's left, the fire moving with its size", s.S.Get("campPos").x == 288
        and icon.pt.LEFT + s.bar().campX == 302.5)
    s.S.Set("campStyle", "round")
    check("the next switch centres the icon on the fire at its new height", s.S.Get("campPos").x == 302.5
        and icon.pt.CENTER == 302.5)
    s.S.Set("campStyle", "simple")
    check("and back, the bar's left where it was", s.S.Get("campPos").x == 288 and icon.pt.LEFT == 288)

    local off = Fixture({ campfire = false, campPos = { point = "CENTER", relPoint = "BOTTOMLEFT", x = 300, y = 500 } })
    off.fire("PLAYER_LOGIN")
    off.S.Set("campStyle", "simple")
    check("switching style while the reminder is off builds nothing and keeps the spot",
        off.named.NaowhForeverCampfire == nil and off.S.Get("campPos").point == "CENTER")
    off.S.Set("campfire", true)
    local oicon = off.named.NaowhForeverCampfire
    check("turned on later: the bar's fire lands where the icon was", off.S.Get("campPos").point == "LEFT"
        and off.S.Get("campPos").x == 288 and oicon.pt.LEFT + off.bar().campX == 300)

    local old = Fixture({ campStyle = "simple", campIconSize = 64,
        campPos = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 40, y = -40 } })
    old.fire("PLAYER_LOGIN")
    pos = old.S.Get("campPos")
    check("an older corner spot is read as the Round icon's, its centre the fire", pos.point == "LEFT"
        and pos.relPoint == "TOPLEFT" and pos.x == 72 - 12 and pos.y == -72)

    local fresh = Fixture({ campStyle = "simple" })
    fresh.fire("PLAYER_LOGIN")
    local ficon = fresh.named.NaowhForeverCampfire
    check("no saved spot: the fire lands on the default spot's centre",
        fresh.S.Get("campPos").relPoint == "BOTTOMRIGHT" and ficon.pt.LEFT + fresh.bar().campX == -223
        and ficon.pty.LEFT == 61)
end

-- The tooltip reader: every feature line of Camp Benefits' description, matched by name, with amounts.
do
    local s = Fixture({ campStyle = "simple" })
    s.fire("PLAYER_LOGIN")
    s.camp(TEMPLATE)
    local bar = s.bar()
    local WANT = { "Rested", "+34 Str", "+56 Sta", "+25 Int", "+32 Spi", "+8% Stats", "+308 Armor", "+90 AP",
        "+23 SP", "+2% Crit", "+29 MP5", "Disenchant" }
    local shown = bar.labels.count - 1
    local inOrder = bar.more == #WANT - shown and Plain(bar.labels.labels[shown + 1].text) == "+" .. bar.more .. " more"
    for i = 1, shown do inOrder = inOrder and Plain(bar.labels.labels[i].text) == WANT[i] end
    check("every feature line read with its amount, Rested first, the rest as +N more", inOrder and shown >= 4
        and s.tooltipReads == 1)
    s.tips = {}
    bar.scripts.OnEnter(bar)
    local text, last, ordered = s.tipText(), 0, true
    for _, line in ipairs({ "Rested experience | Tent", "+34 Strength | Sharpening Wheel", "+56 Stamina | First Aid Kit",
        "+25 Intellect | Incense Candle", "+32 Spirit | Faction Banner", "+8% all stats | Fish Bowl",
        "+308 Armor, +13 all stats, +22 resistances | Enchanted Lute", "+90 Melee Attack Power | Lodestone",
        "+23 spell damage, +23 healing | Boosted Spell Power", "+2% Critical Strike | Camp Chair",
        "+29 Mana every 5 sec | Mana Well", "Better disenchanting | Boosted Disenchanting" }) do
        local at = text:find(line, 1, true)
        ordered = ordered and at ~= nil and at > last
        last = at or last
    end
    check("the tooltip lists every bonus in full, the Lute's three numbers and the Mana Well's period", ordered)
    check("the description's header and the time line are not bonuses", not text:find("Gained", 1, true)
        and not text:find("remaining", 1, true))

    for _ = 1, 5 do s.fire("UNIT_AURA") end
    check("read once per Camp Benefits, not on every aura change", s.tooltipReads == 1)
    do
        local frame, onEvent = s.listener("UNIT_AURA")
        Measure(check)("a Simple refresh from the tooltip", 1, function() onEvent(frame, "UNIT_AURA") end)
    end
    s.auras[CAMP] = { duration = 3600, expirationTime = s.now + 3600, auraInstanceID = 2 }
    s.fire("UNIT_AURA")
    check("a new Camp Benefits is read again", s.tooltipReads == 2)

    s.camp({ "Fish Bowl: All stats increased by 8%.", "Enchanted Lute: Armor increased by 308, all attributes "
        .. "increased by 13, and all resistances increased by 22.", "Camp Chair: Critical strike chance with all "
        .. "spells and attacks increased by 2%.", "Mana Well: Restores 29 Mana every 5 seconds." }, 3)
    check("the widest common four fit at the default width beside the time",
        s.labels(bar) == "+8% Stats +308 Armor +2% Crit +29 MP5" and bar.more == 0 and s.named.NaowhForeverCampfire.w == 360
        and bar.group <= 360 - 29 - 10 - bar.timeW - 12)
    local minimum = math.ceil(29 + W("+8% Stats") + W("+308 Armor") + W("+2% Crit") + W("+29 MP5") + 3 * 10 + 12
        + math.ceil(W("44m")) + 10)
    check("the minimum width is what those four need beside the time, well under the default",
        bar.minW == minimum and minimum <= 330)
    s.S.Set("campSimpleWidth", 255)
    check("a saved width under the minimum draws at the minimum, the saved value kept",
        bar.width == minimum and s.named.NaowhForeverCampfire.w == minimum and s.S.Get("campSimpleWidth") == 255
        and bar.more == 0 and s.labels(bar) == "+8% Stats +308 Armor +2% Crit +29 MP5")
    s.S.Set("campSimpleTextSize", 14)
    check("a larger text size raises the minimum, and the four still fit", bar.minW > minimum and bar.more == 0
        and bar.width == bar.minW and bar.labels.size == 14)
    s.S.Set("campSimpleTextSize", 10)
    check("text size never draws under 11", bar.labels.size == 11 and bar.time.size == 11 and bar.note.size == 11)
    s.S.Set("campSimpleTextSize", 12)
    s.S.Set("campBonusIcons", true)
    check("bonus icons widen the minimum by four icons", bar.minW == minimum + 4 * (12 + 1 + 3))
    s.S.Set("campBonusIcons", false)
    s.S.Set("campSimpleWidth", 360)
    s.camp({ "Tent: rest experience.", "First Aid Kit: Stamina increased by 56.", "Incense Candle: Intellect "
        .. "increased by 25.", "Faction Banner: Spirit increased by 32.", "Camp Chair: Critical strike chance "
        .. "increased by 2%." }, 4)
    check("five common bonuses fit at the default width too", s.labels(bar) == "Rested +56 Sta +25 Int +32 Spi +2% Crit"
        and bar.more == 0)
    s.S.Set("campSimpleWidth", 220)
    s.camp(TEMPLATE, 5)
    check("at the minimum, the rest as +N more, never under the time", bar.width == bar.minW and bar.more > 0
        and s.labels(bar):find("+" .. bar.more .. " more$") and bar.group <= bar.minW - 29 - 10 - bar.timeW - 12)
    s.S.Set("campSimpleWidth", 400)
    local timedMore, timedMin = bar.more, bar.minW
    s.S.Set("campTimer", false)
    local untimed = bar.more
    check("without the timer the time's room goes to the bonuses", untimed < timedMore and bar.time.shown == false
        and bar.group <= 400 - 29 - 10 and bar.minW == timedMin - bar.timeW - 12)

    s.S.Set("campTimer", true)
    s.S.Set("campSimpleWidth", 360)

    s.spellNames[BANNER], s.spellNames[WELL], s.spellNames[CHAIR] = "Fraktionsbanner", "Manabrunnen", "Zhuozi"
    local l = Fixture({ campStyle = "simple" })
    l.spellNames[BANNER], l.spellNames[WELL], l.spellNames[CHAIR] = "Fraktionsbanner", "Manabrunnen", "Zhuozi"
    l.spellNames[KIT] = "Verbandskasten"
    l.fire("PLAYER_LOGIN")
    l.camp({ "Fraktionsbanner: Willenskraft um 32 erhoeht.", "Manabrunnen: Stellt alle 5 Sek. 29 Mana wieder her.",
        "Zhuozi" .. WIDE_COLON .. "Baoji 2,5%", "Verbandskasten: Ausdauer um 1.056 erhoeht." })
    local lbar = l.bar()
    check("another language: matched by the client's own feature names, amounts in order",
        l.labels(lbar) == "+1056 Sta +32 Spi +2.5% Crit +29 MP5")
    l.tips = {}
    lbar.scripts.OnEnter(lbar)
    check("another language: the tooltip names each feature as the client does",
        l.tipText():find("+32 Spirit | Fraktionsbanner", 1, true)
        and l.tipText():find("+29 Mana every 5 sec | Manabrunnen", 1, true)
        and l.tipText():find("+2.5% Critical Strike | Zhuozi", 1, true))
end

-- No bonuses read, Resting, and every state sharing one layout.
do
    local s = Fixture({ campStyle = "simple" })
    s.fire("PLAYER_LOGIN")
    s.tooltip = { lines = { { leftText = "Camp Benefits" } } }
    s.auras[CAMP] = { duration = 3600, expirationTime = s.now + 3000, auraInstanceID = 1 }
    s.fire("UNIT_AURA")
    local bar, icon = s.bar(), s.named.NaowhForeverCampfire
    s.fire("UNIT_AURA")
    check("no description yet: not read again on every aura change", s.tooltipReads == 1)
    s.advance(5)
    check("no description yet: tried again a few seconds later", s.tooltipReads == 2)
    s.camp({ "Gained the following camp benefits:" })
    check("no bonuses read: Camp Active, then no bonuses muted, with its time", bar.note.text
        == "Camp Active{muted:" .. s.St.PLACE_DOT .. "no bonuses}"
        and bar.note.shown ~= false and Same(bar.note, s.T.fg) and s.labels(bar) == "" and bar.time.shown ~= false
        and bar.line.shown ~= false and icon.w == 360 and not bar.pill)
    s.tips = {}
    bar.scripts.OnEnter(bar)
    check("no bonuses read: the tooltip says why, and still gives the time",
        s.tipText():find("Camp Benefits is up, but it lists no bonuses: this camp may have no features, or they "
        .. "can't be read yet.", 1, true)
        and s.tipText():find("Time left | 56 min", 1, true))
    local reads = s.tooltipReads
    for _ = 1, 3 do s.fire("UNIT_AURA") end
    check("an empty list is not read again on every aura change", s.tooltipReads == reads)
    s.advance(5)
    check("an empty list is tried again a few seconds later", s.tooltipReads == reads + 1)
    s.tooltip = { lines = { { leftText = "Camp Benefits" }, { leftText = "Tent: rest experience." },
        { leftText = "Camp Chair: Critical strike chance increased by 2%." } } }
    s.advance(5)
    check("a full tooltip on a later try brings the bonuses back", s.tooltipReads == reads + 2
        and s.labels(bar) == "Rested +2% Crit")
    s.advance(30)
    for _ = 1, 3 do s.fire("UNIT_AURA") end
    check("a full read is not repeated", s.tooltipReads == reads + 2)

    s.camp({ "Tent: rest experience.", "Camp Chair: Critical strike chance increased by 2%." }, 2)
    local layout = {}
    local function Snap(name)
        layout[#layout + 1] = { name = name, campX = bar.camp.pt.CENTER, campY = bar.camp.pty.CENTER,
            note = bar.note.pt.LEFT, noteY = bar.note.pty.LEFT, h = icon.h, w = icon.w,
            time = bar.time.pt.RIGHT, timeY = bar.time.pty.RIGHT, labels = bar.labels.pt.LEFT - bar.lead,
            labelsY = bar.labels.pty.LEFT }
    end
    Snap("active")
    s.auras[CAMP] = nil
    s.auras[SITTING] = { duration = 60, expirationTime = s.now + 35 }
    s.fire("UNIT_AURA")
    check("resting, nothing new readable: Resting, then the last bonuses muted after a gap",
        bar.note.text == "Resting" and Same(bar.note, s.T.accentSoft) and s.labels(bar) == "Rested +2% Crit"
        and Same(bar.labels.labels[1], s.T.muted) and bar.lead == math.ceil(W("Resting")) + 10)
    check("resting: the countdown reads in 35s, in the accent", bar.line.binding.formatter.points[1].format == "in %ds"
        and Same(bar.line.to, s.T.accent))
    s.tips = {}
    bar.scripts.OnEnter(bar)
    check("resting tooltip: when it lands", s.tipText():find("Resting at a campfire", 1, true)
        and s.tipText():find("Camp Benefits in | 35 sec", 1, true))
    Snap("resting")
    s.auras[SITTING] = nil
    s.fire("UNIT_AURA")
    Snap("refresh")
    s.auras[NEARBY] = {}
    s.fire("UNIT_AURA")
    Snap("nearby")
    s.auras[NEARBY] = nil
    s.auras[TENT], s.auras[CHAIR] = Aura({ 5 }), Aura({ 2 })
    s.auras[SITTING_CRAFT] = { duration = 60, expirationTime = s.now + 40 }
    s.fire("UNIT_AURA")
    check("the crafting Welcoming Campfire counts as resting; readable bonuses show as upcoming",
        bar.note.shown == false and s.labels(bar) == "Rested +2% Crit" and Same(bar.labels.labels[1], s.T.accentSoft)
        and bar.lead == 0)
    s.tips = {}
    bar.scripts.OnEnter(bar)
    check("upcoming tooltip: what you'll get", s.tipText():find("You'll get:", 1, true)
        and s.tipText():find("+2% Critical Strike | Camp Chair", 1, true))
    Snap("upcoming")
    local upcomingX = bar.labels.labels[2].pt.LEFT
    s.auras[SITTING_CRAFT] = nil
    s.auras[CAMP] = { duration = 3600, expirationTime = s.now + 3600, auraInstanceID = 3 }
    s.fire("UNIT_AURA")
    check("landing: the same bonuses in the text color, nothing moves", Same(bar.labels.labels[1], s.T.fg)
        and bar.labels.labels[2].pt.LEFT == upcomingX and bar.line.binding.formatter.points[1].format == "%ds")
    Snap("landed")
    local same = true
    for _, snap in ipairs(layout) do
        local first = layout[1]
        for _, key in ipairs({ "campX", "campY", "note", "noteY", "h", "w", "time", "timeY", "labels", "labelsY" }) do
            if snap[key] ~= first[key] then same = false; print("  moved in " .. snap.name .. ": " .. key) end
        end
    end
    check("every state keeps the fire, the words, the time and the height in one place", same and #layout == 6)
end

-- Off, the card's preview, and its rows.
do
    local s = Fixture({ campfire = false })
    s.fire("PLAYER_LOGIN")
    check("off: nothing built, nothing listened to", s.named.NaowhForeverCampfire == nil and s.bars == 0)
    local listening = false
    for _, f in ipairs(s.frames) do if f.events.UNIT_AURA then listening = true end end
    check("off: no aura events", not listening)

    local card = s.ns.Shared.Settings.pages["AuraBuffs/Settings"].cards.campfire
    local shot = card.studio.new(s.Frame())
    card.studio.paint(shot, "up")
    check("preview: Round by default, no bar", s.bars == 0 and shot.icon.shown ~= false)
    local tabs = {}
    for _, state in ipairs(card.studio.states) do
        local needs = state.needs
        if type(needs) ~= "function" or needs() then tabs[#tabs + 1] = state.key end
    end
    check("preview: No Bonuses is a Simple-only tab", not table.concat(tabs, " "):find("unread", 1, true))
    s.values.campShowUnder, s.values.campShowUnderMinutes = true, 2
    card.studio.paint(shot, "up")
    check("preview Active with Show Only When Low: the reminder still drawn, dimmed, with the note",
        shot.icon.shown ~= false and shot.icon.alpha < 1
        and shot.note.text:find("hidden until under 2 min", 1, true))
    card.studio.paint(shot, "missing")
    check("preview Refresh: the reminder at full strength", shot.icon.shown ~= false and shot.icon.alpha == 1)
    s.values.campShowUnder = nil
    s.values.campStyle = "simple"
    card.studio.paint(shot, "low")
    local f = shot.bar
    check("preview: the Simple bar once picked, Running Low in yellow", s.bars == 1 and shot.barHost.shown ~= false
        and shot.icon.shown == false and Same(f.line.to, s.St.TIME_LOW_RGB))
    check("preview: four sample bonuses with amounts", s.labels(f) == "Rested +56 Sta +25 Int +2% Crit"
        and f.more == 0)
    check("preview: not editable while the reminder is off", shot.widthZone.shown == false
        and shot.hint.text:find("Turn on", 1, true))
    s.values.campfire = true
    card.studio.paint(shot, "up")
    check("preview: editable, with its hint", shot.widthZone.shown ~= false
        and shot.hint.text:find("Drag the right edge", 1, true) and Same(f.line.to, s.St.TIME_OK_RGB))
    check("preview: the time's zone covers the time and its padding", shot.timeZone.w == f.timeW + 10)

    local edge = shot.widthZone
    s.cursorX = 100
    edge.scripts.OnMouseDown(edge, "LeftButton")
    s.cursorX = 130
    edge.scripts.OnUpdate(edge)
    check("drag: the bar grows live", shot.barHost.w == 420)
    edge.scripts.OnMouseUp(edge, "LeftButton")
    check("drag: the right edge sets the width", s.S.Get("campSimpleWidth") == 420)
    s.cursorX = 100
    edge.scripts.OnMouseDown(edge, "LeftButton")
    s.cursorX = -200
    edge.scripts.OnUpdate(edge)
    check("drag: it stops at the width four bonuses need", shot.barHost.w == math.ceil(f.minW / 5) * 5
        and shot.barHost.w >= f.minW)
    edge.scripts.OnMouseUp(edge, "LeftButton")
    check("drag: the stop is what is saved", s.S.Get("campSimpleWidth") == math.ceil(f.minW / 5) * 5)
    s.S.Set("campSimpleWidth", 360)

    local body = shot.zones[1]
    body.scripts.OnMouseWheel(body, 1)
    check("wheel: text size", s.S.Get("campSimpleTextSize") == 13)
    s.shift = true
    body.scripts.OnMouseWheel(body, 1)
    s.shift = false
    check("shift-wheel: bar height", s.S.Get("campSimpleHeight") == 27)

    local crit = shot.bonusZones[4]
    crit.over = true
    crit.scripts.OnMouseUp(crit, "LeftButton")
    card.studio.paint(shot, "up")
    check("click a bonus: hidden, and dimmed in the preview", s.S.Get("campHiddenBonuses")[CHAIR] == true
        and f.labels.labels[4].alpha < 1 and f.labels.labels[1].alpha == 1)
    crit.scripts.OnMouseUp(crit, "LeftButton")
    check("click it again: shown", s.S.Get("campHiddenBonuses")[CHAIR] == nil)
    local critRow, bonusRows = nil, 0
    for _, row in ipairs(card.rows) do
        if row.key == "campHiddenBonuses" and row.field then
            bonusRows = bonusRows + 1
            if row.field == CHAIR then critRow = row end
        end
    end
    check("a row per bonus on the card, Simple only", bonusRows == #s.ns.AuraBuffs.CampData.FEATURES
        and critRow and critRow.label:find("Camp Chair", 1, true) and critRow.hidden() == false)
    check("on while the bonus shows", critRow.get() == true and not s.ns.Shared.Settings.Changed(critRow))
    critRow.set(false)
    check("off hides it, as a click on the preview does, and counts as changed",
        s.S.Get("campHiddenBonuses")[CHAIR] == true and critRow.get() == false
        and s.ns.Shared.Settings.Changed(critRow))
    s.ns.Shared.Settings.ResetRow(critRow)
    check("its reset shows it again, leaving the others", s.S.Get("campHiddenBonuses")[CHAIR] == nil)

    shot.timeZone.over = true
    shot.timeZone.scripts.OnMouseUp(shot.timeZone, "LeftButton")
    check("click the time: Show Camp Timer off", s.S.Get("campTimer") == false)
    s.S.Set("campTimer", true)

    body.over = true
    body.scripts.OnMouseUp(body, "RightButton")
    local entries = s.menuEntries()
    check("right-click: the house menu with the bar's choices", s.menus == 1
        and entries:find("radio:Round", 1, true) and entries:find("radio:Simple", 1, true)
        and entries:find("check:Bonus Icons", 1, true) and entries:find("check:Show Timer", 1, true)
        and entries:find("button:Bonuses", 1, true) and entries:find("button:Reset Bar", 1, true))

    shot.w, shot.h = 700, 98
    card.studio.paint(shot, "up")
    local left, leftY = shot.barHost.pt.LEFT, shot.barHost.pty.LEFT
    check("preview: the bar's left is fixed, centred on the stage for the default width",
        shot.barHost.rel.LEFT == shot and left == -360 / 2 and leftY == 15)
    local stage = card.studio.height
    check("the stage is the bar's tallest, its padding and the hint: no dead space", type(stage) == "function"
        and stage() == 16 * 2 + 36 + 30)
    s.values.campStyle = "round"
    check("the Round style keeps its taller stage", stage() == 230)
    s.values.campStyle = "simple"
    s.S.Set("campSimpleWidth", 440)
    card.studio.paint(shot, "up")
    check("preview: a wider bar keeps its place", shot.barHost.pt.LEFT == left and shot.barHost.pty.LEFT == leftY)
    s.S.Set("campSimpleWidth", 360)

    card.studio.paint(shot, "sitting")
    check("preview Resting: Resting, then the bonuses muted", f.note.text == "Resting"
        and Same(f.labels.labels[1], s.T.muted) and Same(f.line.to, s.T.accent) and shot.barHost.pt.LEFT == left)
    card.studio.paint(shot, "unread")
    check("preview No Bonuses: Camp Active, no bonus zones", Plain(f.note.text) == "Camp Active"
        .. s.St.PLACE_DOT .. "no bonuses" and shot.barHost.pt.LEFT == left
        and f.labels.count == 0 and shot.bonusZones[1].shown == false and f.time.shown ~= false)
    card.studio.paint(shot, "nearby")
    local stateW = shot.barHost.w
    check("preview Camp Nearby: the same rectangle, only the body editable", f.pill and shot.barHost.w == stateW
        and Plain(f.note.text) == "Camp Nearby" .. s.St.PLACE_DOT .. "click to sit"
        and shot.widthZone.shown == false and shot.zones[1].shown ~= false)
    card.studio.paint(shot, "missing")
    check("preview Refresh: the same rectangle, the fire in the same seat", f.pill
        and Plain(f.note.text) == "Refresh Camp" and shot.barHost.w == stateW and shot.barHost.h == f.height
        and f.camp.pt.CENTER == f.campX and shot.barHost.pt.LEFT == left and shot.barHost.pty.LEFT == leftY)


    local byKey, groups = {}, {}
    for _, row in ipairs(card.rows) do
        if row.key then byKey[row.key] = row end
        if row.group then groups[row.group] = row end
    end
    local function Hides(row) return type(row.hidden) == "function" and row.hidden() end
    check("rows: Simple shows the bar's rows and hides the Round icon's", not Hides(byKey.campSimpleWidth)
        and not Hides(groups["Simple Bar"]) and Hides(byKey.campIconSize) and Hides(byKey.campBuffMode)
        and Hides(groups["Round Icon"]))
    s.values.campStyle = "round"
    check("rows: Round hides the bar's rows", Hides(byKey.campSimpleWidth) and Hides(byKey.campBonusIcons)
        and Hides(groups["Simple Bar"]) and not Hides(byKey.campIconSize))
    local short = true
    for _, row in ipairs(card.rows) do
        if row.help and (#row.help > 100 or row.help:find("%. %u")) then short = false; print("  long: " .. row.key) end
    end
    check("rows: every help is one short sentence", short)
end

-- The Camp Nearby card's preview: the alert in the bar's style, breathing, sized by the wheel.
do
    local s = Fixture()
    s.fire("PLAYER_LOGIN")
    local card = s.ns.Shared.Settings.pages["AuraBuffs/Settings"].cards.campNearby
    local shot = card.studio.new(s.Frame())
    shot.w, shot.h = 700, 120
    card.studio.paint(shot, "nearby")
    local a = shot.alert
    check("alert preview: the shared bar, Camp Nearby and the click hint, the fire lit and no time",
        a.bar.pill and Plain(a.bar.note.text) == "Camp Nearby" .. s.St.PLACE_DOT .. "click to sit"
        and a.bar.time.shown == false and a.bar.camp.tex.desaturated == false)
    check("alert preview: it breathes while shown", a.breathe.playing and a.breathe.looping == "BOUNCE")
    check("alert preview: no dismiss button taking the mouse", rawget(a, "click") == nil)
    local left = a.pt.LEFT
    card.studio.paint(shot, "low")
    check("alert preview Running Low: the time on the right, the same left edge", a.bar.time.shown ~= false
        and a.bar.slot == a.bar.timeW and a.pt.LEFT == left and a.w > math.ceil(29 + W("Camp Nearby") + 10))
    check("alert preview: editable, with its hint", shot.zone.shown ~= false and shot.hint.text:find("Wheel", 1, true))
    shot.zone.scripts.OnMouseWheel(shot.zone, 1)
    check("wheel: the alert grows a step", math.abs(s.S.Get("campAlertScale") - 1.5) < 1e-9)
    for _ = 1, 20 do shot.zone.scripts.OnMouseWheel(shot.zone, 1) end
    check("wheel: never past its largest", math.abs(s.S.Get("campAlertScale") - 2.5) < 1e-9)
    shot.zone.over = true
    shot.zone.scripts.OnMouseUp(shot.zone, "RightButton")
    local entries = s.menuEntries()
    check("right-click: Fade and Reset", entries:find("check:Fade", 1, true) and entries:find("button:Reset", 1, true))
    s.S.Set("campAlertFade", false)
    card.studio.paint(shot, "nearby")
    check("alert preview with Fade off: still, at full strength", not a.breathe.playing and a.alpha == 1)
    local rows = {}
    for _, row in ipairs(card.rows) do rows[#rows + 1] = row.key end
    check("alert card: Alert Under, Fade, Alert Size, then its Font, Outline and Background", table.concat(rows, " ")
        == "campNearbyMinutes campAlertFade campAlertScale campAlertFont campAlertOutline campAlertBackground")
    s.values.campStyle = "simple"
    card.studio.paint(shot, "nearby")
    check("alert preview: editable with the Simple style too", shot.zone.shown ~= false
        and shot.hint.text:find("Wheel", 1, true))
    local live = true
    for _, row in ipairs(card.rows) do live = live and (row.kind == "group" or row.needs()) end
    check("alert card: its rows work with either style", live and #card.help < 100
        and not card.help:find("Round", 1, true))
end

-- Camp Nearby's Font, Outline and Background: today's look until one is set, each applied at once,
-- and the card's preview drawn with them.
do
    local s = Fixture()
    s.fire("PLAYER_LOGIN")
    s.auras[NEARBY] = {}
    s.fire("UNIT_AURA")
    local ab = s.named.NaowhForeverCampNearby.bar
    local St = s.St
    check("Camp Nearby by default: the addon font, no outline, the card's shadow and no background",
        ab.note.font == "font" and ab.note.outline == "" and ab.dot.outline == "" and ab.time.outline == ""
        and ab.note.shadow == St.HUD_SHADOW_ALPHA and ab.plate.mode == "none")
    s.S.Set("campAlertFont", "Friz")
    s.S.Set("campAlertOutline", "THICKOUTLINE")
    check("its Font and Outline apply at once, the outline in place of the shadow", ab.note.font == "lsm:Friz"
        and ab.time.font == "lsm:Friz" and ab.dot.font == "lsm:Friz" and ab.note.outline == "THICKOUTLINE"
        and ab.note.shadow == 0)
    s.S.Set("campAlertOutline", "")
    s.S.Set("campAlertBackground", "soft")
    check("Background Soft: the soft fade, the words with its stronger shadow", ab.plate.mode == "soft"
        and ab.note.shadow == St.HUD_SOFT_SHADOW_ALPHA)
    s.S.Set("campAlertBackground", "card")
    check("Background Card: the card behind it", ab.plate.mode == "card" and ab.plate.fill.shown ~= false
        and ab.note.shadow == St.HUD_SHADOW_ALPHA)
    local card = s.ns.Shared.Settings.pages["AuraBuffs/Settings"].cards.campNearby
    local shot = card.studio.new(s.Frame())
    shot.w, shot.h = 700, 120
    card.studio.paint(shot, "nearby")
    check("the card's preview draws them too", shot.alert.bar.note.font == "lsm:Friz"
        and shot.alert.bar.plate.mode == "card")
end

do
    local s = Fixture({ campStyle = "simple" })
    s.fire("PLAYER_LOGIN")
    local bar = s.bar()
    s.auras[NEARBY] = {}
    s.auras[CAMP] = { duration = 3600, expirationTime = s.now + 90, auraInstanceID = 1 }
    s.fire("UNIT_AURA")
    local alert = s.named.NaowhForeverCampNearby
    check("Simple, camp low and a campfire in range: the Camp Nearby alert, with the time left", alert
        and alert.shown == true and alert.bar.time.shown ~= false and not bar.pill)
    s.auras[CAMP] = nil
    s.fire("UNIT_AURA")
    check("Simple, camp gone and a campfire in range: the bar's own pill, no alert", alert.shown == false
        and bar.pill and Plain(bar.note.text) == "Camp Nearby" .. s.St.PLACE_DOT .. "click to sit")
    s.auras[CAMP] = { duration = 3600, expirationTime = s.now + 1800, auraInstanceID = 2 }
    s.fire("UNIT_AURA")
    check("Simple, plenty of camp left: no alert yet", alert.shown == false)
    s.advance(1800 - 120 + 1)
    check("Simple: the alert comes once the camp drops under Alert Under", alert.shown == true)
    s.auras[NEARBY] = nil
    s.fire("UNIT_AURA")
    check("Simple: out of range, the alert goes", alert.shown == false)
    s.ns.ShowUnlockMode()
    check("Simple: Unlock Mode shows the alert to move", alert.shown == true)
    s.ns.HideUnlockMode()
end

do
    local s = Fixture()
    s.fire("PLAYER_LOGIN")
    s.camp({ "Tent: rest experience.", "First Aid Kit: Stamina increased by 56.",
        "Camp Chair: Critical strike chance increased by 2%." })
    s.auras[CAMP] = nil
    s.auras[SITTING] = { duration = 60, expirationTime = s.now + 35 }
    s.fire("UNIT_AURA")
    check("Round, resting", s.named.NaowhForeverCampfire.label.text == "Resting")
    s.S.Set("campStyle", "simple")
    local bar = s.bar()
    check("switching to Simple while resting: the last bonuses at once", bar.note.text == "Resting"
        and s.labels(bar) == "Rested +56 Sta +2% Crit")
    s.S.Set("campHiddenBonuses", { [KIT] = true })
    check("hiding a bonus while resting: gone at once", s.labels(bar) == "Rested +2% Crit")
    s.S.Set("campBonusIcons", true)
    check("bonus icons while resting: shown at once", bar.labels.icons[1].shown ~= false
        and bar.labels.icons[1].texture.texture == TENT and bar.labels.icons[2].texture.texture == CHAIR)
    s.S.Set("campBonusIcons", false)
    check("bonus icons off while resting: gone at once", bar.labels.icons[1].shown == false)

    local t = Fixture({ campBuffMode = "off" })
    t.fire("PLAYER_LOGIN")
    t.camp({ "Tent: rest experience.", "Camp Chair: Critical strike chance increased by 2%." })
    check("Round without camp buffs reads no tooltip", t.tooltipReads == 0)
    t.auras[SITTING] = { duration = 60, expirationTime = t.now + 35 }
    t.fire("UNIT_AURA")
    t.S.Set("campStyle", "simple")
    local tbar = t.bar()
    check("resting with Camp Benefits still up: its tooltip read, the bonuses shown as upcoming",
        t.tooltipReads == 1 and t.labels(tbar) == "Rested +2% Crit" and Same(tbar.labels.labels[1], t.T.accentSoft))
end

do
    local s = Fixture({ campStyle = "simple" })
    s.fire("PLAYER_LOGIN")
    s.auras[CHAIR] = Aura({ 3 })
    s.camp({ "Tent: rest experience.", "First Aid Kit: Stamina increased by 56.",
        "Incense Candle: Intellect increased by 25.", "Camp Chair: Critical strike chance increased by 2%." })
    local bar = s.bar()
    check("one feature's own aura plus three more on the tooltip: all four, in order, none twice",
        s.labels(bar) == "Rested +56 Sta +25 Int +3% Crit" and bar.labels.count == 4 and s.tooltipReads == 1)
    s.S.Set("campStyle", "round")
    local icon = s.named.NaowhForeverCampfire
    check("Round lists the same four", icon.buffs.text == "+Rested\n+STA\n+INT\n+Crit")
    s.camp({ "Tent: rest experience.", "Mystery Totem: +5 Luck" }, 7)
    check("an unknown tooltip line joins the merged list", icon.buffs.text == "+Rested\n+Crit\n+5 Luck")
    s.auras[CHAIR] = nil
    s.fire("UNIT_AURA")
    check("a feature aura going away updates the list, the tooltip unread again",
        icon.buffs.text == "+Rested\n+5 Luck" and s.tooltipReads == 2)
end

do
    local saved = { point = "LEFT", relPoint = "CENTER", x = -252, y = 210 }
    local s = Fixture({ campAlertPos = saved })
    s.fire("PLAYER_LOGIN")
    s.auras[NEARBY] = {}
    s.fire("UNIT_AURA")
    local alert = s.named.NaowhForeverCampNearby
    check("its old spot is left for the Alerts group to start from", s.S.Get("campAlertPos") == saved
        and s.stacked.frame == alert)

    local click = alert.click
    check("only right clicks, the left ones and camera drags pass through", #click.clicks == 1
        and click.clicks[1] == "RightButtonUp" and #click.passThrough == 1 and click.passThrough[1] == "LeftButton"
        and click.mouse == true and click.all == true and click.parent == alert)
    s.tips = {}
    click.scripts.OnEnter(click)
    check("hovering it: how to dismiss it", s.tipText() == "Right-click to dismiss until you leave the campfire.")
    click.scripts.OnClick(click, "LeftButton")
    check("a left click does nothing", alert.shown == true)
    local sit = alert.bar.camp.sitSpot
    check("the whole alert is the click to sit, above the dismiss click", sit and sit.shown and sit.all == alert
        and sit:GetFrameLevel() > click:GetFrameLevel())
    s.tips = {}
    sit.scripts.OnEnter(sit)
    check("hovering it: how to sit, then how to dismiss", s.tipText()
        == "Click to sit at the campfire.\nRight-click to dismiss until you leave the campfire.")
    local emotes = #s.emotes
    sit.scripts.OnClick(sit, "LeftButton")
    check("a left click anywhere on it sits", #s.emotes == emotes + 1 and s.emotes[#s.emotes] == "SIT"
        and alert.shown == true)
    local fades = alert.fadeOut.plays
    click.scripts.OnClick(click, "RightButton")
    check("right-click: it fades out and stops taking the mouse", alert.shown == false
        and alert.fadeOut.plays == fades + 1 and click.mouse == false)
    s.fire("UNIT_AURA")
    check("dismissed: it stays away while in range", alert.shown == false and click.mouse == false)
    s.auras[NEARBY] = nil
    s.fire("UNIT_AURA")
    s.auras[NEARBY] = {}
    s.fire("UNIT_AURA")
    check("back in range after leaving: it shows again", alert.shown == true and click.mouse == true)
    local fadesAgain, emotesAgain = alert.fadeOut.plays, #s.emotes
    sit.scripts.OnClick(sit, "RightButton")
    check("right-click on it still dismisses it, no sitting", alert.shown == false
        and alert.fadeOut.plays == fadesAgain + 1 and #s.emotes == emotesAgain)
    s.auras[NEARBY] = nil
    s.fire("UNIT_AURA")
    s.auras[NEARBY] = {}
    s.fire("UNIT_AURA")
    s.ctrl = true
    sit.scripts.OnClick(sit, "LeftButton")
    s.ctrl = false
    check("Ctrl-click still dismisses it too", alert.shown == false and #s.emotes == emotesAgain)
end

do
    local s = Fixture()
    s.fire("PLAYER_LOGIN")
    local icon = s.named.NaowhForeverCampfire
    check("no camp: no glow by default, the grey fire says it", not s.glows[icon] and icon.tex.desaturated == true)
    s.S.Set("campGlow", true)
    check("no camp, none nearby: with Glow on it glows, no click, Refresh Camp", s.glows[icon]
        and not (icon.sitSpot and icon.sitSpot.shown) and icon.label.text == "Refresh Camp")
    s.auras[NEARBY] = {}
    s.fire("UNIT_AURA")
    local spot = icon.sitSpot
    check("a campfire in range: the fire lights up and takes the click, Click to sit", spot and spot.shown
        and icon.tex.desaturated == false and icon.label.text == "Click to sit")
    spot.scripts.OnEnter(spot)
    check("under the mouse the fire glows brighter", icon.hot and icon.hot.shown ~= false
        and icon.hot.blend == "ADD")
    spot.scripts.OnLeave(spot)
    check("and settles when the mouse leaves", icon.hot.shown == false)
    spot.scripts.OnClick(spot, "LeftButton")
    check("clicking the fire performs the /sit emote", #s.emotes == 1 and s.emotes[1] == "SIT")
    check("the click covers the icon and its Click to sit under it", spot.rel.TOP == icon
        and spot.rel.BOTTOM == icon.label and spot.w == math.max(icon.w, icon.label:GetStringWidth()))
    spot.scripts.OnClick(spot, "RightButton")
    check("a right click doesn't", #s.emotes == 1)
    s.auras[CAMP] = { duration = 3600, expirationTime = s.now + 2400, auraInstanceID = 1 }
    s.fire("UNIT_AURA")
    check("camp up: no glow, no click", not s.glows[icon] and spot.shown == false)
    s.auras[CAMP] = nil
    s.S.Set("campGlow", false)
    s.S.Set("campSitButton", false)
    check("the options turn the glow and the click off", not s.glows[icon] and spot.shown == false
        and icon.label.text == "Refresh Camp")
    s.S.Set("campGlow", true)
    s.S.Set("campSitButton", true)
    check("and on again", s.glows[icon] and spot.shown and icon.label.text == "Click to sit")
    s.auras[NEARBY] = nil
    s.fire("UNIT_AURA")
    check("out of range again: the fire greys and stops taking the click", spot.shown == false
        and icon.tex.desaturated == true and icon.label.text == "Refresh Camp")
    local glow = s.glows[icon]
    check("the default glow is today's: red pixel lines, eight, two thick, a four second march",
        glow.kind == "pixel" and glow.color[1] == 0.97 and glow.color[2] == 0.27 and glow.lines == 8
        and glow.thickness == 2 and glow.frequency == 0.25 and glow.length == nil)
    s.S.Set("campGlowColor", { r = 0, g = 1, b = 0 })
    s.S.Set("campGlowLines", 4)
    s.S.Set("campGlowSpeed", 7)
    glow = s.glows[icon]
    check("a new color, lines and speed restart the pixel glow",
        glow.color[2] == 1 and glow.lines == 4 and glow.frequency == 0.5)
    s.S.Set("campGlowType", "standard")
    check("Standard Glow replaces it, in the chosen color", s.glows[icon].kind == "standard"
        and s.glows[icon].color[2] == 1)
    s.fire("UNIT_AURA")
    check("a refresh keeps the same glow", s.glows[icon].kind == "standard")
    s.S.Set("campGlowType", "pixel")
    check("and back to pixel", s.glows[icon].kind == "pixel")
    s.S.Set("campGlow", false)
    check("Enable Glow off stops either", s.glows[icon] == nil)
end

print(checks .. " campfire look checks passed")

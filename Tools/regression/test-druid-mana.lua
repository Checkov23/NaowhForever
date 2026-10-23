-- Run with Lua 5.1 from the repository root: Druid Mana. Off, or for any class but druid, it builds
-- nothing and listens to nothing. On, it shows in the forms picked (in combat by default), puts the
-- mana on the bar and in its text, marks the cost of shifting back and counts the shifts left,
-- warns below a shift, and runs the five second rule after a spell that costs mana. The shift cost
-- hangs off the end of the fill whether the mana is secret or not, and stays through a move or a
-- new texture, and the mana still missing for a shift shows in red up to the cost. With the mana
-- secret it never compares it: only shifts left goes.

local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local none = function() end
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
local registry = {}

local function Widget(kind, parent)
    local f = { kind = kind, shown = true, events = {}, points = {}, parent = parent }
    registry[#registry + 1] = f
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(on) self.shown = on and true or false end
    function f:IsShown() return self.shown end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:SetWidth(w) self.w = w end
    function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function f:ClearAllPoints() self.points = {} end
    function f:SetScript(k, fn) self[k] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:RegisterUnitEvent(e, unit) self.events[e] = unit end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetMinMaxValues(lo, hi) self.min, self.max = lo, hi end
    function f:SetValue(v) self.value = v end
    function f:SetStatusBarColor(r, g, b) self.color = { r, g, b } end
    function f:GetStatusBarTexture()
        self.fill = self.fill or Widget("Fill", self)
        return self.fill
    end
    function f:SetStatusBarTexture(path)
        self.fill = Widget("Fill", self)
        self.fill.texture = path
    end
    function f:SetTexture(path) self.texture = path end
    function f:SetText(t) self.text = t end
    function f:SetFormattedText(fmt, ...)
        for i = 1, select("#", ...) do
            if select(i, ...) == SECRET then self.text, self.secretText = fmt, true return end
        end
        self.text, self.secretText = fmt:format(...), false
    end
    function f:GetFrameLevel() return 1 end
    function f:CreateTexture() return Widget("Texture", self) end
    function f:CreateFontString() return Widget("FontString", self) end
    function f:CreateAnimationGroup()
        local group = Widget("AnimationGroup", self)
        function group.Play(g) g.playing = true; g.plays = (g.plays or 0) + 1 end
        function group.Stop(g) g.playing = false end
        function group.IsPlaying(g) return g.playing == true end
        function group.CreateAnimation(g) return Widget("Animation", g) end
        return group
    end
    return setmetatable(f, { __index = function(_, key)
        if type(key) == "string" and key:find("^%u") then return none end
    end })
end

local function Fixture(saved, game)
    local env = { pairs = pairs, ipairs = ipairs, type = type, math = math, table = table, next = next,
        setmetatable = setmetatable, select = select, tostring = tostring, string = string }
    registry = {}
    local frames, timers, after = {}, {}, {}
    env.CreateFrame = function(kind, name, parent)
        local f = Widget(kind, parent)
        f.frameName = name
        frames[#frames + 1] = f
        return f
    end
    env.Named = function(name)
        for _, f in ipairs(frames) do
            if f.frameName == name then return f end
        end
    end
    env.Listening = function(event)
        for _, f in ipairs(frames) do
            if event and f.events[event] then return true end
            if not event and next(f.events) and not f.events.PLAYER_LOGIN then return true end
        end
        return false
    end
    env.Fire = function(event, ...)
        for _, f in ipairs(frames) do
            if f.events[event] and f.OnEvent then f.OnEvent(f, event, ...) end
        end
    end
    env.hooksecurefunc = function(t, key, fn)
        local orig = t[key]
        t[key] = function(...) orig(...); fn(...) end
    end
    env.C_Timer = {
        After = function(_, fn) after[#after + 1] = fn end,
        NewTimer = function(seconds, fn)
            local t = { seconds = seconds, fn = fn }
            function t.Cancel(self) self.cancelled = true end
            timers[#timers + 1] = t
            return t
        end,
    }
    env.Flush = function()
        while #after > 0 do table.remove(after, 1)() end
    end
    env.Expire = function()
        local t = timers[#timers]
        if t and not t.cancelled then t.cancelled = true; t.fn() end
    end
    env.issecretvalue = function(v) return v == SECRET end
    env.game = game
    env.UnitClass = function() return "Druid", game.class end
    env.InCombatLockdown = function() return game.combat end
    env.UnitAffectingCombat = function() return game.combat end
    env.GetShapeshiftFormID = function() return game.form end
    env.GetShapeshiftForm = function() return game.formIndex end
    env.GetShapeshiftFormInfo = function() return 1, true, true, game.formSpell end
    env.UnitPower = function() return game.mana end
    env.UnitPowerMax = function() return game.max end
    env.UnitPowerPercent = function() return game.pct end
    env.C_Spell = { GetSpellPowerCost = function(id) return game.costs[id] end }
    env.C_CurveUtil = { CreateCurve = function() return setmetatable({}, { __index = function() return none end }) end }
    env.GetTime = function() return 100 end
    env.Enum = { PowerType = { Mana = 0 }, LuaCurveType = { Linear = 1 } }
    env.UIParent = Widget("Frame")
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Apply = none,
        ShowUnlockMode = none, HideUnlockMode = none, THEME = { bg = { r = 0, g = 0, b = 0 } } }
    ns.Solid = function(parent) return parent:CreateTexture() end
    ns.PixelInset = none
    ns.OnePixel = function() return game.px or 1 end
    ns.Font = function(parent) return parent:CreateFontString() end
    ns.Border = function(frame)
        local b = {}
        frame.border = b
        function b.SetColor(_, r, g, b2) b.color = { r, g, b2 } end
        return b
    end
    env.placed = 0
    ns.UI = { TexturePath = function(_, fallback) return fallback end, HasAnchor = function() return false end,
        ModuleSettings = function(key, defaults)
            assert(key == "druidMana", "Druid Mana's settings are its own")
            local listeners = {}
            local S = { Get = function(k) if saved[k] == nil then return defaults[k] end return saved[k] end }
            function S.Set(k, v) saved[k] = v; for i = 1, #listeners do listeners[i](k, v) end end
            function S.OnChange(fn) listeners[#listeners + 1] = fn end
            return S
        end }
    env.pages = {}
    ns.Shared = { Style = dofile("Tools/regression/shared_style.lua"),
        Parts = {
            HudFont = none,
            TimerLine = function(parent, _, text)
                local line = env.CreateFrame("StatusBar", "TimerLine", parent)
                line.text = text
                function line.Run(self, start, duration) self.running = { start, duration } end
                function line.Stop(self) self.running = nil end
                function line.Paint(self, color) self.paint = color end
                return line
            end,
        },
        ItemBar = {
            Frame = function(name)
                local f = env.CreateFrame("Frame", name, env.UIParent)
                f.mover = Widget("Mover", f)
                return f
            end,
            Anchored = function(S, prefix) return S.Get(prefix .. "Anchor") ~= "UIParent" end,
            Put = function() env.placed = env.placed + 1 end,
        },
        Anchor = { Rows = function() return { { label = "Anchor rows" } } end },
        Settings = { Group = function(title) return { group = title } end,
            Look = function() return {} end,
            Page = function(key)
                local page = { key = key, cards = {} }
                function page.Card(p, spec) p.cards[#p.cards + 1] = spec end
                env.pages[key] = page
                return page
            end } }
    env.NaowhForever = ns
    env._G = env
    Load({ "Core/Features.lua" }, env)
    Load(TocFiles("^NaowhForever_Combat/DruidMana/.*%.lua$"), env)
    env.Fire("PLAYER_LOGIN")
    env.Flush()
    return env, ns
end

local CAT_SPELL, BEAR_SPELL, REJUV, CLAW = 768, 5487, 774, 1082
local function Game(over)
    local g = { class = "DRUID", combat = true, form = 1, formIndex = 3, formSpell = CAT_SPELL,
        mana = 1016, max = 1639, pct = 62,
        costs = { [CAT_SPELL] = { { type = 0, cost = 340 } }, [BEAR_SPELL] = { { type = 0, cost = 380 } },
            [REJUV] = { { type = 0, cost = 120 } }, [CLAW] = { { type = 3, cost = 40 } } } }
    for k, v in pairs(over or {}) do g[k] = v end
    return g
end

local function Find(kind, parent, test)
    for _, w in ipairs(registry) do
        if w.kind == kind and (parent == nil or w.parent == parent) and (test == nil or test(w)) then return w end
    end
end

local function Point(w, name)
    return w.points[1] ~= nil and w.points[1][1] == name
end

local function All(kind, parent)
    local out = {}
    for _, w in ipairs(registry) do
        if w.kind == kind and w.parent == parent then out[#out + 1] = w end
    end
    return out
end

local function Bar(env)
    local holder = env.Named("NaowhForeverDruidMana")
    local bar = Find("StatusBar", holder, function(w) return w.frameName == nil end)
    local frames = All("Frame", bar)
    local clip, miss, over = frames[1], frames[2], frames[3]
    local costs, misses = All("Texture", clip), All("Texture", miss)
    return {
        holder = holder, bar = bar, cost = costs[1], tick = costs[2],
        missClip = miss, missing = misses[1], missTick = misses[2], spark = Find("Texture", over),
        left = Find("FontString", over, function(w) return Point(w, "LEFT") end),
        right = Find("FontString", over, function(w) return Point(w, "RIGHT") end),
        info = Find("FontString", holder, function(w) return Point(w, "TOPLEFT") end),
        line = env.Named("TimerLine"),
    }
end

-- Off, and for other classes: nothing.
do
    local env, ns = Fixture({}, Game())
    Check(ns.FEATURES.druidMana.enabled == false, "off by default")
    Check(env.Named("NaowhForeverDruidMana") == nil and not env.Listening(), "off, nothing is built or listened to")
    Check(env.pages["Druid Mana/Settings"] ~= nil, "its settings page is declared")
    local warrior = Fixture({ enabled = true }, Game({ class = "WARRIOR" }))
    Check(warrior.Named("NaowhForeverDruidMana") == nil and not warrior.Listening(), "a warrior gets nothing")
end

-- Cat Form in combat: the mana, its text, the shift cost and shifts left.
do
    local env = Fixture({ enabled = true }, Game())
    local b = Bar(env)
    Check(b.holder.shown, "in Cat Form in combat the bar shows")
    Check(env.placed == 0, "in combat, placing it waits")
    Check(env.Listening("UNIT_POWER_UPDATE"), "while shown it follows your mana")
    Check(b.bar.value == 1016 and b.bar.max == 1639, "the bar holds your mana")
    Check(b.left.text == "1016 / 1639" and b.right.text == "62%", "the text says current / max and percent")
    Check(b.cost.shown and b.tick.shown, "the shift cost is shown")
    Check(math.abs(b.cost.w - (220 - 2) * 340 / 1639) < 0.01, "as wide as its share of your mana")
    Check(b.cost.points[1][2] == b.bar.fill and b.cost.points[1][3] == "TOPRIGHT",
        "hanging off the end of the fill")
    Check(b.tick.points[1][2] == b.cost and b.tick.points[1][3] == "LEFT", "with the line where your mana would land")
    Check(b.info.text == "2 shifts left", "and the shifts left are counted")
    Check(b.missClip.points[1][2] == b.bar.fill and b.missClip.points[1][3] == "TOPRIGHT"
        and b.missClip.points[2][2] == b.bar and b.missClip.points[2][3] == "BOTTOMRIGHT",
        "the missing mana is clipped from the end of the fill to the end of the bar")
    Check(b.missing.shown and math.abs(b.missing.w - 218 * 340 / 1639) < 0.01 and b.missing.points[1][2] == b.bar,
        "inside it, red from the start of the bar to the cost")
    Check(b.missTick.points[1][2] == b.missing and b.missTick.points[1][3] == "RIGHT", "with its line at the cost")
    Check(b.spark.shown, "the regen spark shows outside the five second rule")
    local pulse = b.spark.pulse
    local plays = pulse.plays
    env.Fire("UNIT_POWER_UPDATE", "player", "MANA")
    Check(pulse.plays == plays, "a mana update leaves a running pulse alone")

    env.game.mana = 230
    env.Fire("UNIT_POWER_UPDATE", "player", "MANA")
    Check(b.info.text == "0 shifts left", "below a shift, none left")
    Check(b.missing.shown and b.cost.shown, "the missing mana and the cost both stay up for the clip to cut")

    env.game.mana = 400
    env.Fire("UNIT_POWER_UPDATE", "player", "ENERGY")
    Check(b.bar.value == 230, "energy updates are not mana")
    env.Fire("UNIT_POWER_UPDATE", "player", "MANA")
    Check(b.info.text == "1 shift left", "one shift left reads as one")
    env.game.combat = false
    env.Fire("PLAYER_REGEN_ENABLED")
    Check(env.placed == 1, "the wait ends with combat")
end

-- Secret mana: never compared.
do
    local env = Fixture({ enabled = true }, Game({ mana = SECRET, pct = SECRET }))
    local b = Bar(env)
    Check(b.bar.value == SECRET, "a secret mana still goes on the bar")
    Check(b.left.secretText and b.right.secretText, "and into the text, unread")
    Check(b.info.text == "", "shifts left needs a readable mana")
    Check(b.cost.shown and math.abs(b.cost.w - 218 * 340 / 1639) < 0.01, "the shift cost shows all the same")
    Check(b.missing.shown and math.abs(b.missing.w - 218 * 340 / 1639) < 0.01, "and so does the missing mana")
    Check(b.spark.shown, "the spark still shows")
end

-- The forms and combat.
do
    local env = Fixture({ enabled = true }, Game({ combat = false }))
    local b = Bar(env)
    Check(not b.holder.shown and not env.Listening("UNIT_MAXPOWER"), "out of combat it waits, unlistened")
    Check(env.Listening("UNIT_POWER_UPDATE"), "but follows your mana for the five second rule")
    Check(env.placed == 1, "out of combat it is placed at once")
    env.game.combat = true
    env.Fire("PLAYER_REGEN_DISABLED")
    Check(b.holder.shown, "combat shows it")
    env.game.form, env.game.formIndex, env.game.formSpell = 3, 4, 783
    env.Fire("UPDATE_SHAPESHIFT_FORM")
    Check(not b.holder.shown, "Travel Form is off by default")
    env.game.form, env.game.formIndex, env.game.formSpell = 31, 5, nil
    env.Fire("UPDATE_SHAPESHIFT_FORM")
    env.NaowhForever.DruidManaSettings.Set("showCaster", true)
    env.Flush()
    Check(not b.holder.shown, "Moonkin Form has its own toggle, off by default, apart from caster form")
    env.NaowhForever.DruidManaSettings.Set("showCaster", false)
    env.NaowhForever.DruidManaSettings.Set("showMoonkin", true)
    env.Flush()
    Check(b.holder.shown, "and shows when it is on")
    env.game.form, env.game.formIndex, env.game.formSpell = 8, 1, BEAR_SPELL
    env.Fire("UPDATE_SHAPESHIFT_FORM")
    Check(b.holder.shown and math.abs(b.cost.w - 218 * 380 / 1639) < 0.01,
        "Dire Bear shows, with its own shift cost")
    env.game.form, env.game.formIndex = nil, 0
    env.Fire("UPDATE_SHAPESHIFT_FORM")
    Check(not b.holder.shown, "caster form is off by default")
    env.NaowhForever.DruidManaSettings.Set("showCaster", true)
    env.Flush()
    Check(b.holder.shown and not b.cost.shown and not b.tick.shown and not b.missing.shown,
        "on, it shows with no shift cost")
    env.game.combat = false
    env.Fire("PLAYER_REGEN_ENABLED")
    env.NaowhForever.DruidManaSettings.Set("combatOnly", false)
    env.Flush()
    Check(b.holder.shown, "Only in Combat off keeps it out of combat")
end

-- Moving it, or a new texture, keeps the shift cost on the end of the fill.
do
    local env, ns = Fixture({ enabled = true, combatOnly = false }, Game({ combat = false }))
    local b = Bar(env)
    Check(b.cost.shown, "out of combat, with readable mana, the shift cost shows")
    ns.ShowUnlockMode()
    ns.HideUnlockMode()
    Check(b.cost.shown and math.abs(b.cost.w - 218 * 340 / 1639) < 0.01, "after the HUD Editor it is still there")
    ns.DruidManaSettings.Set("druidManaAnchor", "UIParent")
    env.Flush()
    Check(b.cost.shown, "and after an anchor change")
    ns.DruidManaSettings.Set("texture", "Smooth")
    env.Flush()
    Check(b.cost.points[1][2] == b.bar.fill and b.spark.points[1][2] == b.bar.fill
        and b.missClip.points[1][2] == b.bar.fill, "a new texture moves the segments and the spark onto the new fill")
    ns.DruidManaSettings.Set("warnLow", false)
    env.Flush()
    Check(not b.missing.shown and not b.missTick.shown and b.cost.shown, "Show Missing Mana off hides only the red")
end

-- The five second rule.
do
    local env = Fixture({ enabled = true }, Game())
    local b = Bar(env)
    env.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", REJUV)
    env.Fire("UNIT_POWER_UPDATE", "player", "MANA")
    Check(b.line.running == nil, "a spell that spent no mana, like a Clearcasting one, does not start it")
    env.game.mana = 1100
    env.Fire("UNIT_POWER_UPDATE", "player", "MANA")
    Check(b.line.running == nil, "mana coming back does not start it")
    env.game.mana = 980
    env.Fire("UNIT_POWER_UPDATE", "player", "MANA")
    Check(b.line.running and b.line.running[2] == 5, "spending mana runs it for five seconds")
    Check(not b.spark.shown, "the spark waits")
    env.Expire()
    Check(b.line.running == nil and b.spark.shown, "when it ends the line stops and the spark is back")
    env.NaowhForever.DruidManaSettings.Set("fiveSecond", false)
    env.Flush()
    env.game.mana = 900
    env.Fire("UNIT_POWER_UPDATE", "player", "MANA")
    Check(b.line.running == nil and not b.line.shown and not b.spark.shown, "switched off, none of it")
end

-- The five second rule with secret mana: it goes by the spell instead.
do
    local env = Fixture({ enabled = true }, Game({ mana = SECRET, pct = SECRET }))
    local b = Bar(env)
    env.Fire("UNIT_POWER_UPDATE", "player", "MANA")
    Check(b.line.running == nil, "a secret mana is never compared")
    env.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", CLAW)
    Check(b.line.running == nil, "an energy ability does not start it")
    env.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", REJUV)
    Check(b.line.running and b.line.running[2] == 5, "a spell that costs mana runs it")
    env.Expire()
    env.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", SECRET)
    Check(b.line.running == nil, "a secret spell is passed over")
end

-- Turning it off in the HUD Editor.
do
    local env, ns = Fixture({ enabled = true }, Game())
    local b = Bar(env)
    ns.ShowUnlockMode()
    Check(b.holder.shown and b.holder.mover.shown, "the HUD Editor shows the bar and its mover")
    ns.DruidManaSettings.Set("enabled", false)
    env.Flush()
    Check(not b.holder.shown and not b.holder.mover.shown and not env.Listening(),
        "turned off with the editor open, it goes")
    ns.DruidManaSettings.Set("enabled", true)
    env.Flush()
    Check(b.holder.mover.shown, "back on with the editor still open, the mover returns")
    ns.HideUnlockMode()
    Check(not b.holder.mover.shown, "and closing the editor hides it")
end

-- The shift cost sits inside the one-pixel border at any scale.
do
    local env = Fixture({ enabled = true }, Game({ px = 0.75 }))
    local b = Bar(env)
    Check(math.abs(b.cost.w - (220 - 1.5) * 340 / 1639) < 0.01, "the inner width is the bar less one pixel a side")
end

-- Turning it off.
do
    local env = Fixture({ enabled = true }, Game())
    local b = Bar(env)
    env.NaowhForever.DruidManaSettings.Set("enabled", false)
    env.Flush()
    Check(not b.holder.shown and not env.Listening(), "turned off, it hides and stops listening")
end

-- The settings page.
do
    local env, ns = Fixture({}, Game())
    local page = env.pages["Druid Mana/Settings"]
    local ids = {}
    for i, card in ipairs(page.cards) do ids[i] = card.id end
    Check(table.concat(ids, ",") == "bar,anchor,five,shifting", "four cards")
    Check(page.cards[3].switch == "fiveSecond" and ns.FEATURES.druidMana.fiveSecond == true,
        "the five second rule's switch is a feature")
    Check(page.cards[4].switch == "powershift" and ns.FEATURES.druidMana.powershift == true,
        "and so is powershifting's")
    Check(page.cards[1].summary(ns.DruidManaSettings) == "220 by 16, in combat", "the summary")
end

print(("test-druid-mana: %d checks passed"):format(checks))

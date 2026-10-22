-- Run with Lua 5.1 from the repository root: the PvP module's PvP Auras, and Cooldown at Cursor
-- (QoL). Off, neither builds a frame, hooks UseAction or listens to an event. PvP Auras hands
-- Blizzard's AuraContainer three rows for your target: short buffs, by length (and Magic only,
-- on request), crowd control and debuffs by spell ID, from the abilities switched on and IDs
-- typed in; each row and ability follows its setting, a new target rebuilds it, and nothing is
-- shown, hidden or resized in combat: that waits for the fight's end. Cooldown at Cursor shows its card for a pressed action that fails
-- on cooldown, not for other errors, the global cooldown alone or an action with no cooldown,
-- and moves the card only when the cursor moves.

local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")

local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end

local none = function() end
local NOOP = { __index = function() return none end }

-- A frame: what the tests read is recorded, every other method (a capital first letter) does nothing.
local function Frame(kind)
    local f = { kind = kind, shown = true, events = {}, points = 0, groups = {}, order = {} }
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(on) self.shown = on and true or false end
    function f:IsShown() return self.shown end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:SetPoint() self.points = self.points + 1 end
    function f:SetScript(k, fn) self[k] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:RegisterUnitEvent(e, unit) self.events[e] = unit end
    function f:SetValue(v) self.value = v end
    function f:GetStatusBarTexture()
        self.fill = self.fill or Frame("Texture")
        return self.fill
    end
    function f:SetFormattedText(fmt, ...) self.text = fmt:format(...) end
    function f:SetAlpha(a) self.alpha = a end
    function f:SetDesaturated(on) self.desaturated = on end
    function f:SetColor(r, g, b) self.color = { r, g, b } end
    function f:GetParent() return self.parent end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetEnabled(on) self.enabled = on end
    function f:SetUnit(unit) self.unit = unit end
    function f:UpdateAllAuras() self.rebuilt = (self.rebuilt or 0) + 1 end
    function f:AddAuraGroup(key, filter, opts)
        self.groups[key] = { filter = filter, max = opts.maxFrameCount, filters = opts.candidateFilters, enabled = true }
        self.order[#self.order + 1] = key
        -- The container makes its buttons up front and hands each to initializeFrame.
        local button = Frame("AuraButton")
        opts.initializeFrame(button)
        self.buttons = self.buttons or {}
        self.buttons[#self.buttons + 1] = button
    end
    function f:SetDurationText(_, options) self.timerOptions = options end
    function f:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
    function f:SetAuraGroupEnabled(key, on) self.groups[key].enabled = on end
    function f:SetAuraGroupMaxFrameCount(key, n) self.groups[key].max = n end
    function f:SetAuraGroupCandidateFilters(key, filters)
        self.groups[key].filters = filters
        self.groups[key].sets = (self.groups[key].sets or 0) + 1
    end
    function f:SetText(t) self.text = t end
    function f:SetTexture(t) self.texture = t end
    function f:GetStringWidth() return #(self.text or "") * 6 end
    function f:GetWidth() return 29 end
    function f:GetFrameLevel() return 1 end
    function f:CreateTexture() return Frame("Texture") end
    function f:CreateFontString() return Frame("FontString") end
    function f:CreateAnimationGroup()
        return setmetatable({ CreateAnimation = function() return setmetatable({}, NOOP) end }, NOOP)
    end
    return setmetatable(f, { __index = function(_, key)
        if type(key) == "string" and key:find("^%u") then return none end
    end })
end

-- A settings store as UI.ModuleSettings and QoLSettings give: Get, Set, OnChange.
local function Store(values)
    local listeners = {}
    local S = { Get = function(k) return values[k] end }
    function S.Set(k, v)
        values[k] = v
        for i = 1, #listeners do listeners[i](k, v) end
    end
    function S.OnChange(fn) listeners[#listeners + 1] = fn end
    return S
end

local function Fixture(qol, pvp)
    local env = { pairs = pairs, ipairs = ipairs, type = type, math = math, table = table, next = next,
        setmetatable = setmetatable, error = error,
        select = select, tostring = tostring, tonumber = tonumber, string = string, wipe = function(t)
            for k in pairs(t) do t[k] = nil end
            return t
        end }
    local frames, hooks = {}, {}
    env.CreateFrame = function(kind, name, parent)
        local f = Frame(kind)
        f.frameName, f.parent = name, parent
        frames[#frames + 1] = f
        return f
    end
    env.All = function(kind)
        local out = {}
        for _, f in ipairs(frames) do
            if f.kind == kind then out[#out + 1] = f end
        end
        return out
    end
    env.Fire = function(event, ...)
        for _, f in ipairs(frames) do
            if f.events[event] and f.OnEvent then f.OnEvent(f, event, ...) end
        end
    end
    env.Listening = function(event)
        for _, f in ipairs(frames) do
            if f.events[event] then return true end
        end
        return false
    end
    env.hooksecurefunc = function(t, key, fn)
        if type(t) == "string" then
            hooks[t] = key
            return
        end
        local orig = t[key]
        t[key] = function(...) orig(...); fn(...) end
    end
    env.UseAction = function(slot) if hooks.UseAction then hooks.UseAction(slot) end end
    env.Hooked = function(name) return hooks[name] ~= nil end
    env.combat = false
    env.InCombatLockdown = function() return env.combat end
    env.C_AddOns = { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end }
    local now = 100
    env.GetTime = function() return now end
    env.Advance = function(s) now = now + s end
    env.cursor = { 500, 300 }
    env.GetCursorPosition = function() return env.cursor[1], env.cursor[2] end
    env.UIParent = Frame("Frame")
    env.UIParent.GetEffectiveScale = function() return 1 end
    env.ERR_SPELL_COOLDOWN, env.ERR_ITEM_COOLDOWN = "Spell is not ready yet.", "Item is not ready yet."
    env.Enum = { SecondsFormatterAbbreviation = {}, SecondsFormatterIntervalWhitespace = {},
        SecondsFormatterInterval = {}, SecondsFormatterRounding = { RoundUp = 0 }, LuaCurveType = { Step = 1 },
        DurationTextBindingProperty = { RemainingDuration = 0 } }
    env.C_StringUtil = { CreateSecondsFormatter = function()
        return setmetatable({ Format = function(_, seconds) return seconds .. "s" end }, NOOP)
    end }
    env.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
    env.C_CurveUtil = { CreateColorCurve = function()
        local curve = { points = {} }
        function curve.SetType(c, kind) c.kind = kind end
        function curve.AddPoint(c, x, color) c.points[#c.points + 1] = { x = x, color = color } end
        return curve
    end }
    env.binding = setmetatable({}, NOOP)
    env.binding.SetEnabled = function(b, on) b.enabled = on end
    env.binding.SetDuration = function(b, d) b.duration = d end
    env.C_DurationUtil = { CreateDurationTextBinding = function() return env.binding end }
    env.durations, env.cooldowns = {}, {}
    env.C_ActionBar = { GetActionCooldownDuration = function(slot) return env.durations[slot] end,
        GetActionCooldown = function(slot) return env.cooldowns[slot] end }
    env.GetActionTexture = function(slot) return 1000 + slot end
    env.GetActionInfo = function(slot) return "spell", 2000 + slot end
    env.C_Spell = { GetSpellName = function(id) return "Spell " .. id end }
    env.C_Item = { GetItemNameByID = none }
    env.GetMacroSpell = none
    env.GetActionText = none
    env.absorbs, env.hasTarget, env.hasFocus = {}, true, false
    env.focusName, env.focusClass = "Kalerith", "MAGE"
    env.UnitExists = function(unit)
        return (unit == "target" and env.hasTarget) or (unit == "focus" and env.hasFocus)
    end
    env.UnitGetTotalAbsorbs = function(unit) return env.absorbs[unit] or 0 end
    env.UnitName = function(unit) return unit == "focus" and env.focusName or "Someone" end
    env.sameUnit = false
    env.UnitIsUnit = function(a, b) return (a == "focus" and b == "target") and env.sameUnit end
    env.UnitClass = function(unit) return "Mage", unit == "focus" and env.focusClass or "WARRIOR" end
    env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    env.CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.49, 0, 0.25 } }
    env.tip = {}
    env.GameTooltip = { SetOwner = function() env.tip = {} end, Show = none, Hide = none,
        SetSpellByID = function(_, id) env.tip.spell = id end,
        AddLine = function(_, text) env.tip[#env.tip + 1] = text end }

    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QoLConstants = dofile("Tools/regression/qol_constants.lua"), QoLSettings = Store(qol), THEME = { panel = {}, fg = {}, accentSoft = { r = 0, g = 0, b = 1 },
        accent = { r = 0, g = 0.5, b = 1 }, muted = {} }, Apply = none,
        ShowUnlockMode = none, HideUnlockMode = none }
    ns.UIFontPath = function() return "font" end
    env.opened = {}
    ns.OpenFromOptions = function(open) env.opened[#env.opened + 1] = "from options"; open() end
    ns.OpenMacroWindow = function(view) env.opened[#env.opened + 1] = view end
    env.macrosOn = true
    ns.ModuleOn = function(addon) return addon == "NaowhForever_Macros" and env.macrosOn end
    ns.Solid = function() return Frame("Texture") end
    ns.Border = function() return Frame("Border") end
    ns.Font = function() return Frame("FontString") end
    ns.UI = { AttachMover = function() return Frame("Mover") end,
        ModuleSettings = function(key, defaults)
            assert(key == "pvp", "the PvP module's settings are its own")
            for k, v in pairs(defaults) do
                if pvp[k] == nil then pvp[k] = v end
            end
            return Store(pvp)
        end }
    env.cards = {}
    local page = { Card = function(_, spec) env.cards[spec.id] = spec end }
    ns.Shared = { Style = dofile("Tools/regression/shared_style.lua"), Parts = { ClassCrop = function() end },
        Settings = { Page = function() return page end, Group = function(title) return { group = title } end,
        EditZone = function(parent, opts)
            local zone = Frame("Zone")
            zone.parent, zone.click, zone.enter, zone.leave = parent, opts.click, opts.enter, opts.leave
            return zone
        end } }
    env.NaowhForever = ns
    env._G = env
    Load({ "Core/Features.lua", "Shared/UI/AuraIcon.lua" }, env)
    local files = TocFiles("^NaowhForever_Combat/PvP/.*%.lua$")
    files[#files + 1] = "NaowhForever_QoL/Combat/CursorCooldown.lua"
    Load(files, env)
    env.Fire("PLAYER_LOGIN")
    return env, ns
end

local function QoL()
    return { enabled = true, cursorCooldown = false, cursorCooldownSize = 29, cursorCooldownTime = 0.75 }
end

-- The spell lists
do
    local _, ns = Fixture(QoL(), {})
    local spells = ns.PvPSpells
    local function Entry(list, key)
        for _, entry in ipairs(spells[list]) do
            if entry.key == key then return entry end
        end
    end
    local function Has(list, key, id)
        local entry = Entry(list, key)
        return entry ~= nil and entry.ids[id] == true and type(entry.icon) == "number" and entry.group ~= nil
    end
    Check(Has("crowdControl", "kidneyShot", 408) and Has("crowdControl", "hammerOfJustice", 853)
        and Has("crowdControl", "cheapShot", 1833), "stuns: Kidney Shot, Hammer of Justice, Cheap Shot")
    Check(Has("crowdControl", "sap", 2070) and Has("crowdControl", "sap", 6770) and Has("crowdControl", "sap", 11297),
        "Sap, every rank")
    Check(Has("crowdControl", "gouge", 1776) and Has("crowdControl", "gouge", 1777), "Gouge, both ranks (seen working in game)")
    Check(Has("crowdControl", "polymorph", 118) and Has("crowdControl", "polymorph", 12826)
        and Has("crowdControl", "polymorph", 28270), "Polymorph, every rank and the cow")
    Check(Has("crowdControl", "kickSilence", 18425) and Has("crowdControl", "shieldBashSilence", 18498),
        "the silences Forever names plainly, found by ID")
    Check(Has("crowdControl", "grenades", 19769) and Has("crowdControl", "netOMatic", 13099),
        "engineering: Thorium Grenade, Net-o-Matic")
    Check(Entry("crowdControl", "sap").group == "Rogue" and Entry("crowdControl", "warStomp").group == "Racials & Items",
        "grouped by class, racials and items on their own")
    Check(Has("debuffs", "mortalStrike", 12294) and Has("debuffs", "woundPoison", 13218)
        and Has("debuffs", "curseOfTongues", 1714), "debuffs: Mortal Strike, Wound Poison, Curse of Tongues")
    Check(spells.otherCrowdControl[408] == nil and next(spells.otherCrowdControl) ~= nil,
        "other crowd control: none of the listed abilities, but more")
    local keys, total = {}, 0
    for _, list in ipairs({ "crowdControl", "debuffs" }) do
        for _, entry in ipairs(spells[list]) do
            assert(not keys[list .. entry.key], "a key once: " .. entry.key)
            keys[list .. entry.key] = true
            for id in pairs(entry.ids) do
                assert(type(id) == "number" and id > 0, "spell IDs are numbers")
                total = total + 1
            end
        end
    end
    Check(total > 400, "hundreds of spells, every key once")
end

-- Off: free
do
    local env, ns = Fixture(QoL(), {})
    Check(#env.All("AuraContainer") == 0, "PvP off: no container")
    Check(not env.Hooked("UseAction"), "Cooldown at Cursor off: UseAction is not hooked")
    Check(not env.Listening("UI_ERROR_MESSAGE") and not env.Listening("PLAYER_TARGET_CHANGED"), "off: no events")
    env.combat = true
    ns.Apply()
    Check(not env.Listening("PLAYER_REGEN_ENABLED"), "off, a reapply in combat waits for nothing")
end

-- PvP Auras
do
    local env, ns = Fixture(QoL(), {})
    local S = ns.PvPSettings
    Check(S.Get("cc_sap") == true and S.Get("debuff_mortalStrike") == false and S.Get("debuffs") == false,
        "every crowd control ability on, every debuff off, the debuff row off")
    S.Set("enabled", true)
    local containers = env.All("AuraContainer")
    local c, fc
    for _, container in ipairs(containers) do
        if container.unit == "target" then c = container elseif container.unit == "focus" then fc = container end
    end
    Check(#containers == 2 and c and fc and c.enabled and fc.enabled, "on: a container for your target, one for your focus")
    local buffs, cc, debuffs = c.groups.buffs, c.groups.cc, c.groups.debuffs
    Check(c.order[1] == "buffs" and c.order[2] == "cc" and c.order[3] == "debuffs", "buffs, crowd control, debuffs")
    Check(buffs.filter == "HELPFUL" and buffs.filters.maxDuration == 30 and buffs.filters.includeDispelTypes == nil,
        "buffs: helpful ones lasting 30 seconds at most")
    Check(cc.filter == "HARMFUL" and cc.filters.includeSpellIDs[408] and cc.filters.includeSpellIDs[6770],
        "crowd control: harmful ones, by spell ID")
    Check(debuffs.filter == "HARMFUL" and debuffs.enabled == false and next(debuffs.filters.includeSpellIDs) == nil,
        "debuffs: off, and none picked")
    Check(fc.groups.buffs.enabled == false and fc.groups.cc.enabled and fc.groups.debuffs.enabled == false
        and fc.groups.cc.filters.includeSpellIDs[6770], "your focus: crowd control only, from the same list")

    env.Fire("PLAYER_TARGET_CHANGED")
    Check(c.rebuilt == 1 and not fc.rebuilt, "a new target rebuilds the target's panel")
    env.Fire("PLAYER_FOCUS_CHANGED")
    Check(fc.rebuilt == 1 and c.rebuilt == 1, "a new focus the focus's")

    S.Set("buffLength", 60)
    S.Set("buffMagicOnly", true)
    Check(buffs.filters.maxDuration == 60 and buffs.filters.includeDispelTypes.Magic, "Up To and Only Magic Buffs")
    local sets = cc.sets or 0
    S.Set("buffMax", 3)
    Check(buffs.max == 3 and (cc.sets or 0) == sets, "Max Buffs; the crowd control list is not rebuilt for it")
    local focusSets = fc.groups.cc.sets or 0
    S.Set("cc_sap", false)
    Check(not cc.filters.includeSpellIDs[6770] and cc.filters.includeSpellIDs[408] and cc.sets == sets + 1
        and fc.groups.cc.sets == focusSets + 1, "an ability switched off leaves both panels' lists, the others stay")
    local other = next(ns.PvPSpells.otherCrowdControl)
    Check(cc.filters.includeSpellIDs[other], "other crowd control is in by default")
    S.Set("ccOther", false)
    Check(not cc.filters.includeSpellIDs[other] and cc.filters.includeSpellIDs[408], "and out when switched off")

    S.Set("debuffs", true)
    S.Set("debuff_mortalStrike", true)
    S.Set("debuffExtra", "11597, 99999 12345")
    Check(debuffs.enabled and debuffs.filters.includeSpellIDs[12294] and debuffs.filters.includeSpellIDs[11597]
        and debuffs.filters.includeSpellIDs[99999] and debuffs.filters.includeSpellIDs[12345],
        "debuffs: the ones picked, and spell IDs typed in by hand")
    Check(not debuffs.filters.includeSpellIDs[13218], "not the ones left off")

    local holder, focusHolder
    for _, f in ipairs(env.All("Frame")) do
        if f.frameName == "NaowhForeverPvPAuras" then holder = f end
        if f.frameName == "NaowhForeverPvPAurasFocus" then focusHolder = f end
    end
    Check(holder and holder.h == 36 * 3 + 4 * 2, "three rows: the holder is three icons tall")
    Check(focusHolder and focusHolder.h == 36, "the focus: one row")
    S.Set("cc", false)
    S.Set("debuffs", false)
    Check(cc.enabled == false and holder.h == 36 and fc.groups.cc.enabled, "rows switched off: one icon tall; the focus keeps its own")
    S.Set("cc", true)

    -- The focus's name and class above its panel.
    local header
    for _, f in ipairs(env.All("Frame")) do
        if f.parent == focusHolder and f.class then header = f end
    end
    Check(header and not header.shown, "no focus: no name")
    env.hasFocus = true
    env.Fire("PLAYER_FOCUS_CHANGED")
    Check(header.shown and header.name.text == "Kalerith" and header.name.textColor[1] == 0.25 and header.class.shown,
        "a focus: their name in their class's color, and their class icon")
    env.focusClass = nil
    env.Fire("PLAYER_FOCUS_CHANGED")
    Check(header.name.textColor[1] == 1 and not header.class.shown, "a class the game does not give: white, no icon")
    S.Set("focusName", false)
    Check(not header.shown, "Focus Name off: hidden")
    S.Set("focusName", true)

    -- Your focus is your target: the focus panel steps aside, the target's shows it all.
    Check(focusHolder.alpha == 1, "a focus that is not your target: shown")
    env.sameUnit = true
    env.Fire("PLAYER_TARGET_CHANGED")
    Check(focusHolder.alpha == 0 and holder.alpha ~= 0, "targeting your focus: the focus panel fades out")
    env.sameUnit = {}
    env.issecretvalue = function(v) return type(v) == "table" end
    env.Fire("PLAYER_FOCUS_CHANGED")
    Check(focusHolder.alpha == 1, "where the game keeps it secret, the panel stays")
    env.issecretvalue = nil
    env.sameUnit = false
    env.Fire("PLAYER_TARGET_CHANGED")
    Check(focusHolder.alpha == 1, "a new target: the focus panel is back")

    -- The time left: compact, and coloured by the game's curve near the end.
    local button = c.buttons[1]
    local options = button.timerOptions
    Check(options and options.textFormatter and options.textColor and options.textColor.property == 0,
        "each icon's time left: our compact format and a color curve on the time remaining")
    local points = options.textColor.curve.points
    local function At(x)
        for _, point in ipairs(points) do
            if point.x == x then return point.color end
        end
    end
    Check(options.textColor.curve.kind == 1 and At(0).g < 0.5 and At(0.5).a < 0.5 and At(1).a == 1
        and At(3).g > 0.8 and At(3).b == 0 and At(6).b == 1, "red under 3s and blinking, yellow under 6s, white above")
    S.Set("warnBlink", false)
    points = button.timerOptions.textColor.curve.points
    Check(button.timerOptions ~= options and At(0.5) == nil, "Blink When Red off: red, no blink")
    S.Set("warnAt", 5)
    points = button.timerOptions.textColor.curve.points
    Check(At(5) and At(10), "Red Under 5s: yellow from 10s")
    S.Set("warn", false)
    Check(button.timerOptions.textColor == nil and button.timerOptions.textFormatter, "Warn off: white, still compact")
    S.Set("warn", true)
    S.Set("warnAt", 3)
    S.Set("warnBlink", true)

    env.combat = true
    S.Set("auras", false)
    Check(c.enabled and holder.shown and env.Listening("PLAYER_REGEN_ENABLED"),
        "switched off in combat: left alone until the fight ends")
    env.combat = false
    env.Fire("PLAYER_REGEN_ENABLED")
    Check(c.enabled == false and fc.enabled == false and not holder.shown and not focusHolder.shown
        and not env.Listening("PLAYER_TARGET_CHANGED"), "after the fight: both disabled, hidden, no events")
    S.Set("auras", true)
    Check(#env.All("AuraContainer") == 2 and c.enabled and holder.shown, "back on: the same containers")
    S.Set("focus", false)
    Check(fc.enabled == false and not focusHolder.shown and not env.Listening("PLAYER_FOCUS_CHANGED") and c.enabled,
        "Focus Panel off: the focus's hidden and not followed, the target's stays")
    S.Set("focus", true)

    -- How to set a focus: NF Focus, on Macros' Smart Macros tab.
    local forge
    for _, row in ipairs(env.cards.auras.rows) do
        if row.buttonText == "Smart Macros" then forge = row end
    end
    Check(forge and forge.needs() and forge.help:find("NF Focus", 1, true), "the Focus group points to NF Focus")
    forge.button()
    Check(env.opened[1] == "smart" and #env.opened == 1, "the button opens Macros on its Smart Macros tab")
    env.macrosOn = false
    Check(not forge.needs(), "with the Macros module off, though its addon is loaded, the button is greyed out")
    env.macrosOn = true

    local function Keys(card)
        local keys, groups = {}, {}
        for _, row in ipairs(card.rows) do
            if row.key then keys[row.key] = row end
            if row.group then groups[row.group] = true end
        end
        return keys, groups
    end
    local keys = Keys(env.cards.auras)
    Check(env.cards.auras.switch == "auras" and keys.buffLength and keys.ccMax and keys.debuffMax and keys.timer,
        "the PvP Auras card: look, buffs, and each row's switch and size")
    local ccKeys = Keys(env.cards.crowdControl)
    Check(ccKeys.ccOther and not ccKeys.cc_sap, "the Crowd Control card: Other Crowd Control as a switch, abilities in its grid")
    local grid = env.cards.crowdControl.studio
    local tiles = grid.new(Frame("Frame")).tiles
    Check(#tiles == #ns.PvPSpells.crowdControl, "the grid: a tile for every crowd control ability")
    local sap
    for _, tile in ipairs(tiles) do
        if tile.key == "cc_sap" then sap = tile end
    end
    S.Set("cc_sap", true)
    grid.paint(sap.parent, "spells")
    Check(sap and sap.icon.texture == sap.entry.icon and not sap.icon.desaturated and sap.alpha == 1,
        "Sap's tile: its icon, lit while it shows")
    sap.enter(sap)
    Check(env.tip.spell == sap.entry.spell and env.tip[1]:find("click to hide", 1, true), "hover: the spell, and what a click does")
    sap.click(sap)
    Check(S.Get("cc_sap") == false and sap.icon.desaturated and sap.alpha < 0.5 and not cc.filters.includeSpellIDs[6770],
        "a click hides Sap: dimmed, and out of the row")
    sap.click(sap)
    Check(S.Get("cc_sap") == true and cc.filters.includeSpellIDs[6770], "a second click shows it again")
    local hideAll, showAll
    for _, row in ipairs(env.cards.crowdControl.rows) do
        if row.buttonText == "Hide All" then hideAll = row.button elseif row.buttonText == "Show All" then showAll = row.button end
    end
    hideAll()
    Check(S.Get("cc_sap") == false and S.Get("cc_polymorph") == false, "Hide All dims every ability")
    showAll()
    Check(S.Get("cc_sap") == true and S.Get("cc_polymorph") == true, "Show All lights them again")
    local function SpellRow(card, label)
        for _, row in ipairs(card.rows) do
            for _, inner in ipairs(row[1] and row or {}) do
                if inner.label == label then return inner end
            end
        end
    end
    local sapRow, polyRow = SpellRow(env.cards.crowdControl, "Sap"), SpellRow(env.cards.crowdControl, "Polymorph")
    Check(sapRow and polyRow and sapRow.hidden and polyRow.hidden and not sapRow.key,
        "each ability is a hidden row too, so the search finds it, never drawn and never a changed setting")
    Check(sapRow.help == "Rogue" and sapRow.get() == true, "found by its class too, and reads the grid's setting")
    sapRow.set(false)
    Check(S.Get("cc_sap") == false, "and writes the same setting as its tile")
    sapRow.set(true)
    local msRow = SpellRow(env.cards.debuffs, "Mortal Strike")
    Check(msRow and msRow.hidden and msRow.get() == S.Get("debuff_mortalStrike"), "the debuffs as well")
    local Search = dofile("Tools/regression/settings_search.lua")({
        ["PvP/Auras"] = { env.cards.crowdControl, env.cards.debuffs } })
    for query, card in pairs({ polymorph = "crowdControl", sap = "crowdControl", ["mortal strike"] = "debuffs" }) do
        local hit = Search(query)[1]
        Check(hit and hit.card == "PvP/Auras:" .. card, "the options search finds " .. query)
    end
    local debuffKeys = Keys(env.cards.debuffs)
    Check(debuffKeys.debuffExtra and debuffKeys.debuffExtra.text and #env.cards.debuffs.studio.new(Frame("Frame")).tiles
        == #ns.PvPSpells.debuffs, "the Debuffs card: a grid of every debuff, and spell IDs by hand")

    -- The absorb before the rows: shown as given, the clip doing the hiding.
    local bar, focusBar
    for _, f in ipairs(env.All("StatusBar")) do
        if f.parent == holder then bar = f elseif f.parent == focusHolder then focusBar = f end
    end
    Check(bar and focusBar and env.Listening("UNIT_ABSORB_AMOUNT_CHANGED") and bar.shown,
        "Show Absorb: on, the shields followed")
    env.absorbs.target = 1240
    env.Fire("UNIT_ABSORB_AMOUNT_CHANGED", "target")
    Check(bar.value == 1240 and bar.text.text:find("|T", 1, true) and bar.text.text:find("1240", 1, true)
        and focusBar.value ~= 1240, "a shield on your target: its bar full, a small shield and the number; the focus's untouched")
    env.absorbs.focus = 300
    env.Fire("UNIT_ABSORB_AMOUNT_CHANGED", "focus")
    Check(focusBar.value == 300 and bar.value == 1240, "a shield on your focus: its own number")
    Check(focusBar.text.text:find("|T", 1, true) and focusBar.text.text:find("300", 1, true),
        "the focus's looks the same: a small shield and the number")
    env.absorbs.target = 0
    env.Fire("PLAYER_TARGET_CHANGED")
    Check(bar.value == 0, "a new target without a shield: the bar empties, hiding the number")
    S.Set("absorb", false)
    Check(not bar.shown and not env.Listening("UNIT_ABSORB_AMOUNT_CHANGED"), "Show Absorb off: hidden, and not followed")
    S.Set("absorb", true)

    -- The card's preview: sample icons by the same settings.
    local studio = env.cards.auras.studio
    local shot = studio.new(Frame("Frame"))
    local function Shown(row)
        local n = 0
        for _, f in ipairs(shot.rows[row]) do
            if f.shown then n = n + 1 end
        end
        return n
    end
    S.Set("buffLength", 30)
    S.Set("buffMagicOnly", false)
    S.Set("buffMax", 6)
    S.Set("cc_sap", true)
    S.Set("debuffs", false)
    studio.paint(shot, "target")
    Check(Shown(1) == 6 and Shown(2) == 4 and Shown(3) == 0, "preview: six short buffs, four crowd control, no debuffs")
    Check(shot.rows[2][1].timeText.text == "38s" and type(shot.rows[2][1].icon.texture) == "number",
        "Sap first, with its time left and its icon from the spell list")
    Check(shot.rows[2][1].timeText.textColor[3] == 1 and shot.rows[1][4].timeText.textColor[3] < 0.5,
        "its time white, Blessing of Protection's 2s red")
    Check(not shot.name.shown, "the target's preview: no name")
    studio.paint(shot, "focus")
    Check(Shown(1) == 0 and Shown(2) == 4 and shot.name.shown and shot.name.text == "Kalerith",
        "the focus's preview: crowd control only, under a sample name")
    Check(shot.absorb.text:find("|T", 1, true), "its sample shield number with the shield icon")
    Check(studio.states[2].key == "focus" and studio.states[2].needs == "focus", "a Focus tab while the focus panel is on")
    S.Set("buffMagicOnly", true)
    S.Set("cc_sap", false)
    S.Set("debuffs", true)
    studio.paint(shot, "target")
    Check(Shown(1) == 4 and shot.rows[2][1].timeText.text ~= "38s" and Shown(3) == 1,
        "Only Magic Buffs, Sap off, and the one debuff picked show in the preview too")
    S.Set("buffLength", 10)
    studio.paint(shot, "target")
    Check(Shown(1) == 1, "Up To 10s: only Blessing of Protection is short enough")
    S.Set("buffs", false)
    S.Set("cc", false)
    S.Set("debuffs", false)
    studio.paint(shot, "target")
    Check(Shown(1) + Shown(2) + Shown(3) == 0 and shot.note.text:find("off", 1, true),
        "every row off: an empty stage that says so")
    Check(type(studio.height) == "function" and studio.height() > 36 * 3, "the stage fits three rows of icons")
end

-- Cooldown at Cursor
do
    local env, ns = Fixture(QoL(), {})
    local S = ns.QoLSettings
    S.Set("cursorCooldown", true)
    Check(env.Hooked("UseAction") and env.Listening("UI_ERROR_MESSAGE"), "on: the press and the error are heard")
    local card
    for _, f in ipairs(env.All("Frame")) do
        if f.frameName == "NaowhForeverCursorCooldown" then card = f end
    end
    Check(card and not card.shown, "the card is made, hidden")

    env.durations[5] = { left = 12 }
    env.cooldowns[5] = { isActive = true, isOnGCD = false }
    env.UseAction(5)
    env.Fire("UI_ERROR_MESSAGE", 0, "Not enough mana")
    Check(not card.shown, "another error brings no card")

    env.UseAction(5)
    env.Fire("UI_ERROR_MESSAGE", 0, env.ERR_SPELL_COOLDOWN)
    Check(card.shown and card.name.text == "Spell 2005" and card.icon.texture == 1005,
        "pressed on cooldown: the card, with its icon and name")
    Check(env.binding.enabled and env.binding.duration == env.durations[5], "the game counts its time down")
    local moved = card.points
    card.OnUpdate(card)
    Check(card.points == moved, "a frame with the cursor still does not move the card")
    env.cursor[1] = 520
    card.OnUpdate(card)
    Check(card.points == moved + 1, "the cursor moving does")
    env.Advance(1)
    card.OnUpdate(card)
    Check(not card.shown and rawget(card, "OnUpdate") == nil and not env.binding.enabled,
        "gone after its time, nothing left running")

    env.Advance(5)
    env.UseAction(6)
    env.Fire("UI_ERROR_MESSAGE", 0, env.ERR_SPELL_COOLDOWN)
    Check(not card.shown, "an action with no cooldown to show brings no card")

    env.Advance(5)
    env.durations[7], env.cooldowns[7] = { left = 1 }, { isActive = true, isOnGCD = true }
    env.UseAction(7)
    env.Fire("UI_ERROR_MESSAGE", 0, env.ERR_SPELL_COOLDOWN)
    Check(not card.shown, "the global cooldown alone (Sinister Strike spammed) brings no card")
    env.Advance(5)
    env.cooldowns[7] = { isActive = false }
    env.UseAction(7)
    env.Fire("UI_ERROR_MESSAGE", 0, env.ERR_SPELL_COOLDOWN)
    Check(not card.shown, "nor does an action whose cooldown is not running")

    S.Set("cursorCooldown", false)
    env.Advance(5)
    env.UseAction(5)
    Check(not env.Listening("UI_ERROR_MESSAGE"), "off again: the error is not heard and the press is ignored")
end

print(("test-pvp-auras: %d checks passed"):format(checks))

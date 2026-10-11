-- Run with Lua 5.1 from the repository root: the QoL text alerts' look settings (Combat Alert,
-- Combat Timer, Stealth Reminder, Talent Points, Durability, Restock, Pet Tracker), loaded from
-- the real Shared files against stubs and shown through the HUD Editor. Each draws today's look
-- until a setting is touched: its font and size, outlined text, no background. Font, Font Size,
-- Outline and Background then apply at once; a background fits the frame to its words. Combat
-- Timer's old on/off background is saved as Card (its black panel) and None; Talent Points and
-- Durability can take the theme's accent colour. Each card shows the new rows.

local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Width(text, size) return #text * size * 0.5 end

local function Fixture(saved)
    local state = { frames = {}, named = {}, movers = {} }
    local NOTHING = function() end
    local Frame
    local METHODS = {
        SetScript = function(f, script, fn) f.scripts[script] = fn end,
        HookScript = NOTHING,
        RegisterEvent = function(f, event) f.events[event] = true end,
        RegisterUnitEvent = function(f, event) f.events[event] = true end,
        UnregisterAllEvents = function(f) for event in pairs(f.events) do f.events[event] = nil end end,
        SetWidth = function(f, w) f.w = w end,
        SetHeight = function(f, h) f.h = h end,
        SetSize = function(f, w, h) f.w, f.h = w, h end,
        GetWidth = function(f) return rawget(f, "w") or 0 end,
        GetHeight = function(f) return rawget(f, "h") or 0 end,
        GetEffectiveScale = function() return 1 end,
        GetFrameLevel = function() return 1 end,
        SetPoint = function(f, a, rel, _, x) f.pt[a], f.rel[a] = x or 0, rel end,
        ClearAllPoints = function(f) f.pt, f.rel = {}, {} end,
        SetFont = function(f, path, size, outline) f.font, f.size, f.outline = path, size, outline end,
        SetShadowColor = function(f, _, _, _, a) f.shadow = a end,
        SetText = function(f, text) f.text = text end,
        GetStringWidth = function(f) return Width(rawget(f, "text") or "", rawget(f, "size") or 12) end,
        GetStringHeight = function(f) return rawget(f, "size") or 12 end,
        SetTextColor = function(f, r, g, b) f.r, f.g, f.b = r, g, b end,
        SetColorTexture = function(f, r, g, b, a) f.r, f.g, f.b, f.a = r, g, b, a end,
        Show = function(f) f.shown = true end,
        Hide = function(f) f.shown = false end,
        SetShown = function(f, on) f.shown = on and true or false end,
        IsShown = function(f) return rawget(f, "shown") ~= false end,
        CreateTexture = function(f) return Frame(f) end,
        CreateFontString = function(f) return Frame(f) end,
        CreateAnimationGroup = function()
            local group = setmetatable({}, { __index = function() return NOTHING end })
            group.CreateAnimation = function() return setmetatable({}, { __index = function() return NOTHING end }) end
            return group
        end,
    }
    setmetatable(METHODS, { __index = function(_, key)
        if type(key) == "string" and key:find("^%u") then return NOTHING end
    end })
    local META = { __index = METHODS }
    function Frame(parent, name)
        local f = setmetatable({ scripts = {}, events = {}, parent = parent, pt = {}, rel = {} }, META)
        state.frames[#state.frames + 1] = f
        if name then state.named[name] = f end
        return f
    end

    local T = { fg = { r = 0.9, g = 0.9, b = 0.9 }, muted = { r = 0.6, g = 0.6, b = 0.6 },
        accent = { r = 0, g = 0.5, b = 0.9 }, accentSoft = { r = 0.3, g = 0.7, b = 0.9 },
        line = { r = 0.2, g = 0.2, b = 0.2 }, panel = { r = 0.1, g = 0.1, b = 0.1 },
        bg = { r = 0.05, g = 0.05, b = 0.05 }, grey = { r = 0.2, g = 0.2, b = 0.2 } }
    local values, defaults = saved or {}, {}
    local S = {
        DB = function() return values end,
        Get = function(k)
            local v = values[k]
            if v == nil then return defaults[k] end
            return v
        end,
        Raw = function(k) return values[k] end,
        Default = function(k) return defaults[k] end,
    }
    function S.Set(k, v) values[k] = v end
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        QoLConstants = dofile("Tools/regression/qol_constants.lua"),
        THEME = T,
        Color = function(_, text) return text end,
        Font = function(parent, size, flags, color)
            local fs = Frame(parent)
            fs.flags, fs.size = flags, size
            local c = color or T.fg
            fs.r, fs.g, fs.b = c.r, c.g, c.b
            return fs
        end,
        Solid = function(parent, _, color, alpha)
            local t = Frame(parent)
            t.color, t.alpha = color, alpha
            return t
        end,
        ThemeTint = function(_, literal) return literal end,
        Hairline = function(region) return region end,
        PixelInset = function(region) return region end,
        OnePixel = function() return 1 end,
        Border = function(frame) return { _frame = Frame(frame), SetColor = NOTHING } end,
        AccentBorder = function() return { SetColor = NOTHING } end,
        Button = function(parent) return Frame(parent) end,
        UIFontPath = function() return "font" end,
        AccountSettings = function() return {} end,
        Print = NOTHING,
        TTSVoiceChoices = function() return {}, {} end,
        Apply = NOTHING, ShowUnlockMode = NOTHING, HideUnlockMode = NOTHING,
        UI = {
            Keep = function(parent, key, make)
                local kept = rawget(parent, key)
                if not kept then kept = make(parent); parent[key] = kept end
                return kept
            end,
            AttachMover = function(frame, label, _, page, feature)
                local mover = Frame(frame)
                mover.shown = false
                state.movers[label] = { frame = frame, page = page, feature = feature }
                mover.label = label
                return mover
            end,
            SetMoverChoices = function(mover, choices) state.movers[mover.label].choices = choices end,
            ModuleSettings = function(_, given)
                for key, value in pairs(given) do defaults[key] = value end
                return S
            end,
            FontPath = function(name) return name and name ~= "" and "lsm:" .. name or "font" end,
            _PlayLSMSound = NOTHING, SoundPathFor = NOTHING,
        },
    }
    local env = setmetatable({
        NaowhForever = ns,
        CreateFrame = function(_, name, parent) return Frame(parent, name) end,
        hooksecurefunc = function(t, key, callback)
            local orig = t[key]; t[key] = function(...) orig(...); callback(...) end
        end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } },
        UnitClass = function() return "Warrior", "WARRIOR" end,
        UnitAffectingCombat = function() return false end,
        UnitIsDeadOrGhost = function() return false end,
        UnitOnTaxi = function() return false end,
        IsMounted = function() return false end,
        IsResting = function() return false end,
        IsInInstance = function() return false end,
        InCombatLockdown = function() return false end,
        GetTime = function() return 100 end,
        GetShapeshiftFormID = function() return nil end,
        INVSLOT_FIRST_EQUIPPED = 1, INVSLOT_LAST_EQUIPPED = 19,
        GetInventoryItemDurability = function() return nil end,
        C_Timer = { After = NOTHING, NewTicker = function() return { Cancel = NOTHING } end },
        C_ClassTalents = { HasUnspentTalentPoints = function() return false end },
        C_CurveUtil = { CreateCurve = function()
            return setmetatable({}, { __index = function() return NOTHING end })
        end },
        C_Item = { RequestLoadItemDataByID = NOTHING },
        C_SpellBook = { IsSpellKnown = function() return false end },
        Enum = { LuaCurveType = { Step = 1 } },
        Menu = { GetManager = function() return { IsAnyMenuOpen = function() return false end } end },
        GameTooltip = Frame(),
        UIParent = Frame(),
    }, { __index = _G })
    env._G = env
    local files = TocFiles("^Shared/.*%.lua$")
    for _, path in ipairs({ "Core/Features.lua", "Core/Settings.lua", "Core/AlertStack.lua",
        "NaowhForever_QoL/Combat/CombatAlert.lua", "NaowhForever_QoL/Combat/CombatTimer.lua",
        "NaowhForever_QoL/Combat/StealthReminder.lua", "NaowhForever_QoL/Questing/TalentPoints.lua",
        "NaowhForever_QoL/Loot/Durability.lua", "NaowhForever_QoL/Loot/Restock.lua",
        "NaowhForever_QoL/Combat/PetTracker.lua" }) do
        files[#files + 1] = path
    end
    Load(files, env)
    state.ns, state.S, state.T, state.values, state.St = ns, S, T, values, ns.Shared.Style
    function state.fire(event)
        for i = 1, #state.frames do
            local f = state.frames[i]
            if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event) end
        end
    end
    function state.rows(page, id)
        local card = ns.Shared.Settings.pages[page].cards[id]
        local keys = {}
        for _, row in ipairs(ns.Shared.Settings.Rows(card)) do
            if row.key then keys[row.key] = row end
        end
        return keys
    end
    return state
end

local ON = { combatAlert = true, combatTimer = true, stealthReminder = true, talentPoints = true,
    durability = true, restock = true, petTracker = true }

local function Shown(saved)
    local values = {}
    for k, v in pairs(ON) do values[k] = v end
    for k, v in pairs(saved or {}) do values[k] = v end
    local s = Fixture(values)
    s.fire("PLAYER_LOGIN")
    s.ns.ShowUnlockMode()
    return s
end

-- name, prefix, frame, today's size, the frame's width and its height over that size, card.
local ELEMENTS = {
    { "Combat Alert", "combatAlert", function(s) return s.named.NaowhForeverCombatAlert end, 32, 300, 16,
      "QoL/Combat", "combatAlert" },
    { "Combat Timer", "combatTimer", function(s) return s.named.NaowhForeverCombatTimer end, 32, 32 * 7, 16,
      "QoL/Combat", "combatTimer" },
    { "Stealth Reminder", "stealth", function(s) return s.movers["Stealth Reminder"].frame end, 22, 300, 12,
      "QoL/Combat", "stealthReminder" },
    { "Talent Points", "talentPoints", function(s) return s.named.NaowhForeverTalentPoints end, 22, 300, 10,
      "QoL/XP", "talentPoints" },
    { "Durability", "durability", function(s) return s.named.NaowhForeverDurability end, 22, 300, 10,
      "QoL/Loot & Items", "durability" },
    { "Pet Tracker", "pet", function(s) return s.named.NaowhForeverPetTracker end, 20, 220, 16,
      "QoL/Combat", "petTracker" },
}

for _, e in ipairs(ELEMENTS) do
    local name, prefix, Get, size, width, room, page, id = unpack(e)
    local s = Shown()
    local f = Get(s)
    check(name .. ": today's look by default, the addon font outlined at its size, no background", f
        and f.shown and f.text.font == "font" and f.text.size == size and f.text.outline == "OUTLINE"
        and f.text.shadow == 0 and f.backdrop.mode == "none" and f.w == width and f.h == size + room)

    s.S.Set(prefix .. "Font", "Friz")
    s.S.Set(prefix .. "FontSize", size + 6)
    s.ns.ShowUnlockMode()
    check(name .. ": Font and Font Size apply at once", f.text.font == "lsm:Friz" and f.text.size == size + 6
        and f.h == size + 6 + room)

    s.S.Set(prefix .. "Outline", "")
    s.ns.ShowUnlockMode()
    check(name .. ": no outline, the shadow for no background", f.text.outline == ""
        and f.text.shadow == s.St.HUD_BARE_SHADOW_ALPHA)

    s.S.Set(prefix .. "Background", "card")
    s.ns.ShowUnlockMode()
    check(name .. ": Card puts the card behind it, the text with the card's shadow", f.backdrop.mode == "card"
        and f.backdrop.fill.shown ~= false and f.text.shadow == s.St.HUD_SHADOW_ALPHA)
    s.S.Set(prefix .. "Background", "soft")
    s.ns.ShowUnlockMode()
    check(name .. ": Soft fades in behind it", f.backdrop.mode == "soft" and f.backdrop.fill.shown == false)

    local rows = s.rows(page, id)
    check(name .. ": its card has Font, Font Size, Outline and Background", rows[prefix .. "Font"]
        and rows[prefix .. "FontSize"] and rows[prefix .. "Outline"] and rows[prefix .. "Background"])
end

-- A background fits the frame to its words; without one the frame keeps its width, so what is
-- anchored to it stays put.
do
    local s = Shown({ combatAlertBackground = "card", stealthBackground = "soft", talentPointsBackground = "card",
        durabilityBackground = "card" })
    local pad = s.St.CARD_PAD
    local alert = s.named.NaowhForeverCombatAlert
    check("Combat Alert: the card fits its text", alert.w == Width("+Combat", 32) + 2 * pad)
    local stealth = s.movers["Stealth Reminder"].frame
    check("Stealth Reminder: the soft fade fits its text", stealth.w == Width("RESTEALTH", 22) + 2 * pad)
    local talent = s.named.NaowhForeverTalentPoints
    check("Talent Points: the card fits its text", talent.w == Width("2 Unspent Talent Points", 22) + 2 * pad)
    local dura = s.named.NaowhForeverDurability
    check("Durability: the card fits its text", dura.w == Width("Low Durability: 20%", 22) + 2 * pad)
end

do
    local s = Shown({ petBackground = "card" })
    local pet, pad = s.named.NaowhForeverPetTracker, s.St.CARD_PAD
    check("Pet Tracker with a card: the icon inside its edge, the card round icon and text", pet.icon.pt.LEFT == pad
        and pet.w == Width("Pet Missing", 20) + pet.icon.w + 8 + 2 * pad)
    s = Shown()
    pet = s.named.NaowhForeverPetTracker
    check("Pet Tracker by default: the icon at the frame's edge", pet.icon.pt.LEFT == 0)
end

-- Combat Timer: the old Show Background toggle becomes Card (the same black panel) or None.
do
    local s = Shown({ combatTimerBackground = true })
    local f = s.named.NaowhForeverCombatTimer
    check("Combat Timer: Show Background on is saved as Card", s.values.combatTimerBackground == "card")
    check("Combat Timer: its card is the black panel it always had, the timer's size",
        f.backdrop.mode == "card" and f.backdrop.fill.alpha == 0.8 and f.backdrop.fill.color.r == 0
        and f.backdrop.fill.color.g == 0 and f.backdrop.fill.color.b == 0 and f.w == 32 * 7)
    s = Shown({ combatTimerBackground = false })
    check("Combat Timer: Show Background off is saved as None", s.values.combatTimerBackground == "none"
        and s.named.NaowhForeverCombatTimer.backdrop.mode == "none")
    s = Shown()
    check("Combat Timer: an untouched profile stays untouched", s.values.combatTimerBackground == nil)
end

-- Restock: one size for the list, the title a step larger, as today at 16 and 22.
do
    local s = Shown()
    local r = s.named.NaowhForeverRestock
    check("Restock: today's sizes, outlined, the title in the accent", r.title.size == 22 and r.text.size == 16
        and r.title.outline == "OUTLINE" and r.text.outline == "OUTLINE" and r.backdrop.mode == "none"
        and r.title.r == s.T.accent.r and r.title.b == s.T.accent.b)
    s.S.Set("restockFontSize", 20)
    s.S.Set("restockFont", "Friz")
    s.S.Set("restockBackground", "card")
    s.ns.ShowUnlockMode()
    check("Restock: Font Size sets the list, the title follows", r.text.size == 20 and r.title.size == 26
        and r.text.font == "lsm:Friz" and r.backdrop.mode == "card")
    local rows = s.rows("QoL/Loot & Items", "restock")
    check("Restock: its card has the look rows", rows.restockFont and rows.restockFontSize
        and rows.restockOutline and rows.restockBackground)
end

-- Apply Theme where the colour was fixed.
do
    local s = Shown()
    s.S.Set("durabilityBelow", 25)
    local talent = s.named.NaowhForeverTalentPoints
    check("Talent Points: gold by default", talent.text.r == 1 and talent.text.g == 0.82 and talent.text.b == 0)
    s.S.Set("talentPointsTheme", true)
    s.ns.ShowUnlockMode()
    check("Talent Points: Apply Theme shows it in the accent", talent.text.r == s.T.accent.r
        and talent.text.g == s.T.accent.g and talent.text.b == s.T.accent.b)

    -- 20% with Warn Below 25 sits halfway from red to the top colour.
    local dura = s.named.NaowhForeverDurability
    check("Durability: pink shading to red by default", dura.text.r == 1 and math.abs(dura.text.g - 0.205) < 1e-9
        and math.abs(dura.text.b - 0.355) < 1e-9)
    s.S.Set("durabilityTheme", true)
    s.ns.ShowUnlockMode()
    check("Durability: Apply Theme shades from the accent instead", math.abs(dura.text.r - 0.5) < 1e-9
        and math.abs(dura.text.g - 0.25) < 1e-9 and math.abs(dura.text.b - 0.45) < 1e-9)
end

-- The Alerts group's Settings opens a card.
do
    local s = Shown()
    local mover = s.movers.Alerts
    check("Alerts group: HUD Editor > Settings opens Durability", mover.page == "QoL/Loot & Items"
        and mover.feature == "QoL/Loot & Items:durability"
        and s.ns.Shared.Settings.pages["QoL/Loot & Items"].cards.durability ~= nil)
    local listed = {}
    for _, choice in ipairs(mover.choices) do
        local page, id = choice.feature:match("^(.+):([^:]+)$")
        listed[#listed + 1] = choice.page == page and s.ns.Shared.Settings.pages[page].cards[id] ~= nil and choice.name
    end
    check("its Settings lists each loaded alert, each opening a card that exists",
        table.concat(listed, ",") == "Talent Points,Durability,Restock Reminder,Pet Tracker")
end

print(checks .. " text alert look checks passed")

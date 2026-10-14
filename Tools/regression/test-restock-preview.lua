-- Run with Lua 5.1 from the repository root: the Restock Reminder card's preview draws the real
-- reminder (the same view and look code as the on-screen list) with sample lines. Running Low lists
-- one line per check that is on (a class reagent or a generic one, ammo, food and drink, junk and
-- bags), each check off drops its line, Hunter Ammo shows only a hunter's equipped-ammo line at its
-- own amount, All Stocked shows nothing but a note, and the card's Font, Font Size, Outline and
-- Background apply. Sample numbers only, never the bags; nothing is built before the card opens and
-- a repaint makes no frames. Frames are stubs: this does not emulate the game's renderer.
local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local NAMES = { [17020] = "Arcane Powder", [2512] = "Rough Arrow", [17034] = "Maple Seed",
    [17021] = "Wild Berries" }
local PAGE, CARD = "QoL/Loot & Items", "restock"

local function Fixture(class, saved)
    local state = { frames = {}, named = {} }
    local NOTHING = function() end
    local function Forbidden() error("the preview read the bags") end
    local Frame
    local METHODS = {
        SetScript = function(f, script, fn) f.scripts[script] = fn end,
        RegisterEvent = function(f, event) f.events[event] = true end,
        RegisterUnitEvent = function(f, event) f.events[event] = true end,
        UnregisterAllEvents = function(f) for event in pairs(f.events) do f.events[event] = nil end end,
        SetSize = function(f, w, h) f.w, f.h = w, h end,
        SetHeight = function(f, h) f.h = h end,
        GetWidth = function(f) return rawget(f, "w") or 0 end,
        GetHeight = function(f) return rawget(f, "h") or 0 end,
        SetScale = function(f, s) f.scale = s end,
        SetPoint = function(f, a, rel, _, x, y) f.pt[a], f.rel[a], f.y = x or 0, rel, y end,
        ClearAllPoints = function(f) f.pt, f.rel = {}, {} end,
        SetFont = function(f, path, size, outline) f.font, f.size, f.outline = path, size, outline end,
        SetShadowColor = function(f, _, _, _, a) f.shadow = a end,
        SetText = function(f, text) f.text = text end,
        GetStringWidth = function(f) return #(rawget(f, "text") or "") * (rawget(f, "size") or 12) * 0.5 end,
        GetStringHeight = function(f)
            local text, n = rawget(f, "text") or "", 1
            for _ in text:gmatch("\n") do n = n + 1 end
            return n * (rawget(f, "size") or 12)
        end,
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
            AttachMover = function(frame) return Frame(frame) end,
            SetMoverChoices = NOTHING,
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
        UnitClass = function() return class, class end,
        IsResting = function() return false end,
        IsInInstance = function() return false end,
        InCombatLockdown = function() return false end,
        GetTime = function() return 100 end,
        C_Timer = { After = NOTHING, NewTicker = function() return { Cancel = NOTHING } end },
        C_Item = { RequestLoadItemDataByID = NOTHING, GetItemNameByID = function(id) return NAMES[id] end,
            GetItemCount = Forbidden, GetItemInfo = Forbidden },
        C_Container = setmetatable({}, { __index = Forbidden }),
        GetInventoryItemID = Forbidden,
        C_SpellBook = { IsSpellKnown = function() return false end },
        Enum = { LuaCurveType = { Step = 1 } },
        Menu = { GetManager = function() return { IsAnyMenuOpen = function() return false end } end },
        GameTooltip = Frame(),
        UIParent = Frame(),
    }, { __index = _G })
    env._G = env
    local files = TocFiles("^Shared/.*%.lua$")
    for _, path in ipairs({ "Core/Features.lua", "Core/Settings.lua", "Core/AlertStack.lua",
        "NaowhForever_QoL/Loot/LootCard.lua", "NaowhForever_QoL/Loot/Restock.lua" }) do
        files[#files + 1] = path
    end
    Load(files, env)
    state.ns, state.S, state.T, state.St = ns, S, T, ns.Shared.Style
    state.card = ns.Shared.Settings.pages[PAGE].cards[CARD]
    function state.open()
        local stage = Frame()
        stage.w, stage.h = 600, state.card.studio.height
        state.preview = state.card.studio.new(stage)
        state.preview.w, state.preview.h = stage.w, stage.h
        return state.preview
    end
    function state.paint(key)
        state.card.studio.paint(state.preview, key)
        local view = state.preview.view
        return view.shown ~= false and view.text.text or "", state.preview.note.text
    end
    function state.state(key)
        for _, s in ipairs(state.card.studio.states) do
            if s.key == key then return s end
        end
    end
    return state
end

local function Lines(...) return table.concat({ ... }, "\n") end

local s = Fixture("MAGE")
check("the card has a preview with Running Low, Hunter Ammo and All Stocked", s.card.studio
    and s.state("low") and s.state("hunter") and s.state("stocked"))
local before = #s.frames
check("nothing of the preview is built before the card opens", s.named.NaowhForeverRestock == nil)
s.open()
local text, note = s.paint("low")
check("Running Low: a mage's reagent, ammo, food and drink, junk and bags, from the settings' amounts",
    text == Lines("Arcane Powder  5 / 20", "Rough Arrow  250 / 1000", "Food  2 left", "Drink  5 left",
        "Junk to sell  6", "Bags nearly full  3 free") and note == "")
local built = #s.frames
check("the preview is built when the card opens", built > before)
s.paint("low")
s.paint("stocked")
s.paint("low")
check("a repaint makes no frames", #s.frames == built)
check("the reminder itself stays unbuilt", s.named.NaowhForeverRestock == nil)

local OFF = {
    { "restockReagents", "Arcane Powder" },
    { "restockAmmo", "Rough Arrow" },
    { "restockFood", "Food  2 left" },
    { "restockFood", "Drink  5 left" },
    { "restockVendor", "Junk to sell" },
    { "restockVendor", "Bags nearly full" },
}
for _, pair in ipairs(OFF) do
    s = Fixture("MAGE", { [pair[1]] = false })
    s.open()
    text = s.paint("low")
    check("Running Low: " .. pair[1] .. " off drops " .. pair[2], not text:find(pair[2], 1, true) and text ~= "")
end

s = Fixture("MAGE", { restockAmmoTarget = 400, restockFoodBelow = 20, restockBagsBelow = 10, restockTarget17020 = 40 })
s.open()
text = s.paint("low")
check("the sliders set the sample amounts", text == Lines("Arcane Powder  10 / 40", "Rough Arrow  100 / 400",
    "Food  5 left", "Drink  10 left", "Junk to sell  6", "Bags nearly full  9 free"))

s = Fixture("MAGE", { restockReagents = false, restockAmmo = false, restockFood = false, restockVendor = false })
s.open()
text, note = s.paint("low")
check("every check off: no list, the card's Nothing to check note", text == "" and note == "Nothing to check"
    and s.preview.view.shown == false)

s = Fixture("WARRIOR")
s.open()
text = s.paint("low")
check("a class with no reagents shows a generic one, and no drink", text:find("Arcane Powder  5 / 20", 1, true)
    and not text:find("Drink", 1, true))

s = Fixture("DRUID", { restockTarget17034 = 0 })
s.open()
text = s.paint("low")
check("a reagent set to carry 0 is skipped for the next one", text:find("Wild Berries  5 / 20", 1, true)
    and not text:find("Maple Seed", 1, true))

s = Fixture("MAGE", { restockHunterAmmo = true })
check("the Hunter Ammo tab is there on every class, to set a profile up anywhere", s.state("hunter").needs == nil)
s.open()
text = s.paint("hunter")
check("on a non-hunter it previews the ammo line too", text == "Rough Arrow  125 / 500")
text = s.paint("low")
check("but Running Low keeps a non-hunter's carry target", not text:find("125 / 500", 1, true))
s = Fixture("HUNTER")
s.open()
text, note = s.paint("hunter")
check("with the reminder off the tab still shows the ammo line, with a note to turn it on",
    text == "Rough Arrow  125 / 500" and note == "Turn on Hunter Ammo Reminder below to get it.")
s = Fixture("HUNTER", { restockHunterAmmo = true })
s.open()
text = s.paint("hunter")
check("Hunter Ammo: only the equipped ammo, at its own amount", text == "Rough Arrow  125 / 500")
text = s.paint("low")
check("Running Low: the hunter's ammo at its own amount replaces the carry target",
    text == Lines("Arcane Powder  5 / 20", "Rough Arrow  125 / 500", "Food  2 left", "Drink  5 left",
        "Junk to sell  6", "Bags nearly full  3 free"))
s.S.Set("restockHunterAmmoBelow", 200)
text = s.paint("hunter")
check("Remind Me When Ammo Falls To sets its amount", text == "Rough Arrow  50 / 200")

s = Fixture("MAGE")
s.open()
text, note = s.paint("stocked")
check("All Stocked: nothing shows, with a note", text == "" and s.preview.view.shown == false
    and note == "Nothing shows while you carry what you need.")

s = Fixture("MAGE")
s.open()
s.paint("low")
local view = s.preview.view
check("the preview draws today's look: outlined, the title in the accent and larger, no background",
    view.title.text == "Restock" and view.title.size == 22 and view.text.size == 16
    and view.text.outline == "OUTLINE" and view.backdrop.mode == "none" and view.title.r == s.T.accent.r)
s.S.Set("restockFont", "Friz")
s.S.Set("restockFontSize", 20)
s.S.Set("restockOutline", "")
s.S.Set("restockBackground", "card")
s.paint("low")
check("Font, Font Size, Outline and Background apply to the preview", view.text.font == "lsm:Friz"
    and view.text.size == 20 and view.title.size == 26 and view.text.outline == ""
    and view.backdrop.mode == "card" and view.text.shadow == s.St.HUD_SHADOW_ALPHA)
s.ns.ShowUnlockMode()
local alert = s.named.NaowhForeverRestock
check("the reminder on screen draws with the same look", alert and alert.text.size == view.text.size
    and alert.text.font == view.text.font and alert.backdrop.mode == view.backdrop.mode)

s = Fixture("MAGE", { restockFontSize = 32 })
s.open()
s.paint("low")
view = s.preview.view
check("a list too big for the stage is scaled to fit", view.scale < 1
    and view.h * view.scale <= s.preview.h - s.St.STAGE_MARGIN * 2)
s.S.Set("restockFontSize", 10)
s.paint("hunter")
s.paint("stocked")
s.S.Set("restockReagents", false)
s.paint("low")
check("a small list is drawn at full size", view.scale == 1)

print(checks .. " restock preview checks passed")

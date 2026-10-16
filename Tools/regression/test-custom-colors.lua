-- Settings > COLORS: theme presets and Custom colors. The real Core is loaded; presets are
-- written into ns.THEME in place on our ADDON_LOADED. Run with Lua 5.1 from the repository root.
local file = assert(io.open("Core/Core.lua", "rb"))
local source = file:read("*a"); file:close()

local frames = {}
local function NewFrame()
    local f = { events = {} }
    setmetatable(f, { __index = function() return function() end end })
    function f:SetScript(name, fn) self[name] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    frames[#frames + 1] = f
    return f
end

local function Load(account, libStub)
    frames = {}
    local env = { CreateFrame = NewFrame, LibStub = libStub,
        NaowhForeverDB = { account = account, profiles = {}, charActive = {} } }
    env._G = env
    setmetatable(env, { __index = _G })
    local chunk = assert(loadstring(source, "Core"))
    setfenv(chunk, env)
    chunk("NaowhForever")
    local handler
    for _, f in ipairs(frames) do
        if f.events.ADDON_LOADED and f.OnEvent then handler = f end
    end
    return env.NaowhForever, handler
end
local function Fire(handler, event, name) handler.OnEvent(handler, event, name) end

local cases = 0
local function Check(ok, label) assert(ok, label); cases = cases + 1 end

local function Float(hex, i) return tonumber(hex:sub(i, i + 1), 16) / 255 end
local function Is(t, hex) return t.r == Float(hex, 1) and t.g == Float(hex, 3) and t.b == Float(hex, 5) end
local function Bytes(t)
    return ("%02x%02x%02x"):format(math.floor(t.r * 255 + 0.5), math.floor(t.g * 255 + 0.5),
        math.floor(t.b * 255 + 0.5))
end
local function Snapshot(ns)
    local out = {}
    for key, t in pairs(ns.THEME) do out[key] = { t.r, t.g, t.b } end
    return out
end
local function Unchanged(ns, snap)
    for key, t in pairs(ns.THEME) do
        if t.r ~= snap[key][1] or t.g ~= snap[key][2] or t.b ~= snap[key][3] then return false end
    end
    return true
end

-- WCAG 2.x contrast.
local function Lin(c) return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
local function Lum(t) return 0.2126 * Lin(t.r) + 0.7152 * Lin(t.g) + 0.0722 * Lin(t.b) end
local function Ratio(a, b)
    local la, lb = Lum(a), Lum(b)
    if la < lb then la, lb = lb, la end
    return (la + 0.05) / (lb + 0.05)
end

-- The default theme as shipped, and the presets as designed, pinned here on purpose: an edit
-- to either in Core has to be an edit to this list as well.
local SHIPPED = { bg = "191b1e", panel = "25282c", line = "3a3e44", fg = "f0f1f3", muted = "9a9ea6",
    grey = "40444a", accent = "0091ed", accentSoft = "4db5f5" }
local PRESETS = {
    midnight  = { "Midnight",  "0b1020", "151c30", "2a3550", "eef2ff", "9ba7c8", "5b8cff", "91b2ff", "303b55" },
    slate     = { "Slate",     "12161c", "1e242d", "36404d", "f0f3f5", "9aa7b4", "2bb8a8", "71cfc5", "3c4652" },
    obsidian  = { "Obsidian",  "070708", "131417", "2b2d32", "f5f5f4", "a1a1a6", "f5a524", "f8c36c", "313338" },
    aubergine = { "Aubergine", "130d18", "1f1626", "3a2c46", "f3eef7", "a89bb8", "b57bff", "cda7ff", "40324c" },
    forest    = { "Forest",    "0c1310", "162019", "2c3b31", "eef4ef", "9aae9f", "36c58a", "78d8b1", "324137" },
    crimson   = { "Crimson",   "140a0c", "201316", "3d2429", "f6eff0", "ac9a9e", "ef4b56", "f4868e", "432b2f" },
    rosenoir  = { "Rose Noir", "1a0b14", "27121d", "4a2438", "fdeef5", "c9a3b6", "ff5fa2", "ff94c1", "4f2b3e" },
    cottoncandy = { "Cotton Candy", "1c1832", "272245", "463f70", "f8f2ff", "bbb2dc", "f78fc8", "fab4da", "4c4574" },
    classic   = { "Classic",   "15100b", "221a12", "4d3c26", "f4e8cc", "a89a7c", "d68e35", "e4b378", "52422d" },
}
local ORDER = { "midnight", "slate", "obsidian", "aubergine", "forest", "crimson", "rosenoir", "cottoncandy", "classic" }
local KEYS = { "bg", "panel", "line", "fg", "muted", "accent" }

-- The default theme applies nothing, whatever else is saved.
do
    local ns, handler = Load({ themeColors = { bg = { r = 1, g = 0, b = 0 } } })
    local snap = Snapshot(ns)
    for key, hex in pairs(SHIPPED) do Check(Is(ns.THEME[key], hex), "shipped " .. key) end
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    Check(Unchanged(ns, snap), "no preset: nothing changes, picks or not")
    for _, bad in ipairs({ "", "bogus", "order", "Midnight", 5, true, {} }) do
        ns, handler = Load({ themePreset = bad, themeColors = { bg = { r = 1, g = 0, b = 0 } } })
        snap = Snapshot(ns)
        Fire(handler, "ADDON_LOADED", "NaowhForever")
        Check(Unchanged(ns, snap), "invalid preset falls back to the default theme")
        Check(ns.ThemePresetKey() == "", "invalid preset reads as the default")
    end
    ns, handler = Load({ themePreset = "custom" })
    snap = Snapshot(ns)
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    Check(Unchanged(ns, snap), "custom with no picks changes nothing")
    ns, handler = Load(nil)
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    Check(Is(ns.THEME.bg, SHIPPED.bg), "no account table is fine")
end

-- Each preset applies exactly its values, in place, and the two derived colors follow.
for _, key in ipairs(ORDER) do
    local p = PRESETS[key]
    local ns, handler = Load({ themePreset = key })
    local table_bg = ns.THEME.bg
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    Check(ns.THEME.bg == table_bg, key .. ": the table identity survives")
    for i, tokenKey in ipairs(KEYS) do
        Check(Is(ns.THEME[tokenKey], p[i + 1]), key .. ": " .. tokenKey .. " is exactly the preset's")
    end
    Check(Bytes(ns.THEME.accentSoft) == p[8], key .. ": accentSoft follows the accent")
    Check(Bytes(ns.THEME.grey) == p[9], key .. ": grey follows the line")
    Check(ns.ThemePresetKey() == key, key .. ": the dropdown reads it back")
    Check(ns.THEME_PRESETS[key].name == p[1], key .. ": name")

    -- The accessibility rule: fg 4.5:1, muted and accent 3:1, against the preset's own bg and
    -- panel; the toggle knob stays visible and the lighter accent is readable.
    local T = ns.THEME
    Check(Ratio(T.fg, T.bg) >= 4.5 and Ratio(T.fg, T.panel) >= 4.5, key .. ": fg contrast")
    Check(Ratio(T.muted, T.bg) >= 3 and Ratio(T.muted, T.panel) >= 3, key .. ": muted contrast")
    Check(Ratio(T.accent, T.bg) >= 3 and Ratio(T.accent, T.panel) >= 3, key .. ": accent contrast")
    Check(Ratio(T.accentSoft, T.bg) >= 3 and Ratio(T.accentSoft, T.panel) >= 3, key .. ": accentSoft contrast")
    Check(Ratio({ r = 1, g = 1, b = 1 }, T.accent) >= 2, key .. ": the toggle knob stays visible")
    Check(#ns.THEME_PRESET_ORDER == #ORDER and ns.THEME_PRESET_ORDER[_] == key, key .. ": order")
end

-- The colors are written once, on our ADDON_LOADED only.
do
    local ns, handler = Load({ themePreset = "midnight" })
    local snap = Snapshot(ns)
    Fire(handler, "ADDON_LOADED", "SomeOtherAddon")
    Check(Unchanged(ns, snap), "another addon's event does nothing")
    Fire(handler, "PLAYER_LOGIN")
    Check(Unchanged(ns, snap), "PLAYER_LOGIN does not apply")
end

-- Custom: the player's picks, clamped, with bad entries ignored.
do
    local ns, handler = Load({ themePreset = "custom", themeColors = {
        bg = { r = 0.1, g = 0.2, b = 0.3 }, panel = { r = 5, g = -2, b = "0.5" },
        line = { r = "x", g = 0, b = 0 }, fg = 7, accent = { r = 0.9, g = 0.8, b = 0.1 } } })
    local T = ns.THEME
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    Check(T.bg.r == 0.1 and T.bg.g == 0.2 and T.bg.b == 0.3, "custom: a pick applies")
    Check(T.panel.r == 1 and T.panel.g == 0 and T.panel.b == 0.5, "custom: out-of-range channels clamp")
    Check(Is(T.line, SHIPPED.line) and Is(T.fg, SHIPPED.fg) and Is(T.muted, SHIPPED.muted),
        "custom: bad or missing picks keep the shipped color")
    Check(T.accent.r == 0.9, "custom: the accent applies")
    Check(T.accentSoft.r == 0.9 + (1 - 0.9) * 0.33, "custom: accentSoft derives from the accent")
    Check(Is(T.grey, SHIPPED.grey), "custom: grey keeps its color while the line is unchanged")
end

-- SetThemePreset: validation, and the palette Custom starts from.
do
    local account = {}
    local ns = Load(account)
    ns.SetThemePreset("slate")
    Check(account.themePreset == "slate", "a preset is stored")
    ns.SetThemePreset("")
    Check(account.themePreset == nil, "the default clears it")
    ns.SetThemePreset("bogus")
    Check(account.themePreset == nil, "an unknown name clears it")

    -- From the default theme: Custom starts from the shipped colors.
    ns.SetThemePreset("custom")
    Check(account.themePreset == "custom", "custom is stored")
    for _, key in ipairs(KEYS) do
        Check(Is(account.themeColors[key], SHIPPED[key]), "default -> custom prefills " .. key)
    end

    -- From a preset: Custom starts from that preset.
    account = {}
    ns = Load(account)
    ns.SetThemePreset("aubergine")
    ns.SetThemePreset("custom")
    for i, key in ipairs(KEYS) do
        Check(Is(account.themeColors[key], PRESETS.aubergine[i + 1]), "aubergine -> custom prefills " .. key)
    end

    -- Picks saved from before stay.
    account = { themePreset = "forest", themeColors = { bg = { r = 0.5, g = 0.5, b = 0.5 } } }
    ns = Load(account)
    ns.SetThemePreset("custom")
    Check(account.themeColors.bg.r == 0.5 and account.themeColors.panel == nil, "existing picks are kept")
    ns.SetThemePreset("slate")
    Check(account.themeColors.bg.r == 0.5, "leaving Custom keeps the picks")

    -- Junk in themeColors counts as nothing saved.
    account = { themePreset = "slate", themeColors = { bg = 7 } }
    ns = Load(account)
    ns.SetThemePreset("custom")
    Check(Is(account.themeColors.bg, PRESETS.slate[2]), "junk picks are replaced by the prefill")

    -- The palette is the pristine one even after a preset was applied this session.
    account = { themePreset = "midnight" }
    local handler
    ns, handler = Load(account)
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    ns.SetThemePreset("")
    account.themeColors = nil
    ns.SetThemePreset("custom")
    Check(Is(account.themeColors.bg, SHIPPED.bg) and Is(account.themeColors.accent, SHIPPED.accent),
        "default -> custom starts from the shipped colors, not the applied preset")
end

-- CopyThemeToCustom: the way back to a good palette, whatever the picks were.
do
    local account = { themePreset = "custom", themeColors = { bg = { r = 0.5, g = 0.5, b = 0.5 } } }
    local ns = Load(account)
    ns.CopyThemeToCustom("slate")
    for i, key in ipairs(KEYS) do
        Check(Is(account.themeColors[key], PRESETS.slate[i + 1]), "start from slate: " .. key)
    end
    Check(account.themePreset == "custom", "starting from a theme keeps Custom selected")
    ns.CopyThemeToCustom("")
    for _, key in ipairs(KEYS) do
        Check(Is(account.themeColors[key], SHIPPED[key]), "start from the default: " .. key)
    end
    ns.CopyThemeToCustom("bogus")
    Check(Is(account.themeColors.accent, SHIPPED.accent), "an unknown name is the default")

    -- Still the shipped colors, not a preset applied this session.
    account = { themePreset = "midnight" }
    local handler
    ns, handler = Load(account)
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    ns.CopyThemeToCustom("")
    Check(Is(account.themeColors.bg, SHIPPED.bg) and Is(account.themeColors.accent, SHIPPED.accent),
        "start from the default is pristine after a preset was applied")
end

-- Swatches show the saved pick, else the shipped color.
do
    local account = { themePreset = "custom", themeColors = { bg = { r = 0.1, g = 0.2, b = 0.3 } } }
    local ns, handler = Load(account)
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    local r, g, b = ns.ThemeSwatchColor("bg")
    Check(r == 0.1 and g == 0.2 and b == 0.3, "swatch: the saved pick")
    r = ns.ThemeSwatchColor("fg")
    Check(r == Float(SHIPPED.fg, 1), "swatch: the shipped color when nothing is saved")
    account.themeColors = nil
    r = ns.ThemeSwatchColor("bg")
    Check(r == Float(SHIPPED.bg, 1), "swatch: the shipped color after a reset, though the pick is still applied")
end

-- ns.ThemeTint: the shipped literal untouched unless the theme changed that token.
do
    local lit = { bg = { r = 0.025 }, panel = { r = 0.065 }, line = { r = 0.1 }, accent = { r = 0 }, fg = { r = 1 } }
    local ns, handler = Load({ themePreset = "midnight" })
    Check(rawequal(ns.ThemeTint("bg", lit.bg), lit.bg), "before the apply, the literal")
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    for key, l in pairs(lit) do
        Check(rawequal(ns.ThemeTint(key, l), ns.THEME[key]), "preset: " .. key .. " returns the token")
    end
    ns, handler = Load({ themePreset = "custom", themeColors = { bg = { r = 0.1, g = 0.2, b = 0.3 } } })
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    Check(rawequal(ns.ThemeTint("bg", lit.bg), ns.THEME.bg), "custom: a picked token returns the token")
    Check(rawequal(ns.ThemeTint("panel", lit.panel), lit.panel), "custom: an unpicked token keeps the literal")
    ns, handler = Load({ themeColors = { bg = { r = 0.1, g = 0.2, b = 0.3 } } })
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    for key, l in pairs(lit) do
        Check(rawequal(ns.ThemeTint(key, l), l), "default theme: " .. key .. " returns the literal itself")
    end

    -- A saved pick that is the shipped color, or within a picker's rounding of it, is no change:
    -- what Custom copied from the default theme, or a swatch opened and closed, leaves it alone.
    local function Hex(hex, off) return { r = Float(hex, 1) + off, g = Float(hex, 3), b = Float(hex, 5) } end
    local copied = {}
    for _, key in ipairs({ "bg", "panel", "line", "fg", "muted", "accent" }) do copied[key] = Hex(SHIPPED[key], 0) end
    copied.accent = Hex(SHIPPED.accent, 0.5 / 255)
    ns, handler = Load({ themePreset = "custom", themeColors = copied })
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    for key, l in pairs(lit) do
        Check(rawequal(ns.ThemeTint(key, l), l), "custom at the shipped colors: " .. key .. " keeps the literal")
    end
    Check(Is(ns.THEME.accent, SHIPPED.accent) and Is(ns.THEME.accentSoft, SHIPPED.accentSoft),
        "custom at the shipped colors: the accents stay as shipped")
    copied.accent = Hex(SHIPPED.accent, 2 / 255)
    ns, handler = Load({ themePreset = "custom", themeColors = copied })
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    Check(rawequal(ns.ThemeTint("accent", lit.accent), ns.THEME.accent), "custom: an accent moved off the shipped one is a change")
    Check(rawequal(ns.ThemeTint("bg", lit.bg), lit.bg), "custom: the rest still at the shipped colors keep the literal")
end

-- ns.Color: cached per token, and the cache is cleared when the theme is applied.
do
    local ns, handler = Load({ themePreset = "crimson" })
    Check(ns.Color("accent") == "|cff0091ed", "the default accent before the apply")
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    Check(ns.Color("accent") == "|cffef4b56", "the cache follows the applied accent")
    Check(ns.Color("accent", "x") == "|cffef4b56x|r", "wrapped text")
    Check(ns.Color("fg") == "|cfff6eff0" and ns.Color("muted") == "|cffac9a9e", "fg and muted follow too")
end

-- The preview's colors.
do
    local ns = Load({})
    local default = ns.ThemePalette("")
    Check(#default == 6 and Is(default[1], SHIPPED.bg) and Is(default[6], SHIPPED.accent), "default palette")
    for i, token in ipairs(KEYS) do Check(Is(default[i], SHIPPED[token]), "default palette: " .. token) end
    for _, key in ipairs(ORDER) do
        local palette = ns.ThemePalette(key)
        Check(#palette == 6, key .. ": six colors")
        for i, token in ipairs(KEYS) do
            Check(Is(palette[i], PRESETS[key][i + 1]), key .. " palette: " .. token)
        end
    end
    Check(#ns.ThemePalette("bogus") == 6 and Is(ns.ThemePalette("bogus")[1], SHIPPED.bg), "an unknown key is the default palette")
    ns = Load({ themeColors = { fg = { r = 1, g = 0, b = 0 } } })
    local custom = ns.ThemePalette("custom")
    Check(Is(custom[4], "ff0000") and Is(custom[1], SHIPPED.bg), "custom palette: the saved pick, shipped for the rest")
    Check(#Load(nil).ThemePalette("custom") == 6, "custom with no account table still gives six")
end

-- The retired Classic+ skin is saved as Forever on load, with Forever's colors over the saved theme.
do
    local ns, handler = Load({ skin = "classic", themePreset = "midnight" })
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    Check(ns.AccountSettings().skin == "forever" and ns.foreverSkin == true and ns.Skin() == "forever",
        "Classic+ is moved to Forever on load")
    for _, key in ipairs(ns.THEME_EDITABLE) do
        local c = ns.FOREVER_SKIN[key]
        Check(ns.THEME[key].r == c.r and ns.THEME[key].g == c.g and ns.THEME[key].b == c.b,
            "Forever " .. key .. " for a Classic+ player")
    end
end
do
    local ns, handler = Load({})
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    Check(ns.foreverSkin == false and ns.Skin() == "", "no skin saved: the default")
    Check(ns.AccountSettings().skin == nil, "and none is saved for it")
end

-- The Forever skin: its own colors over any saved theme, readable, and an unknown skin is the default.
do
    local ns, handler = Load({ skin = "forever", themePreset = "crimson" })
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    Check(ns.foreverSkin == true and ns.Skin() == "forever", "Forever is read on load")
    for _, key in ipairs(ns.THEME_EDITABLE) do
        local c = ns.FOREVER_SKIN[key]
        Check(ns.THEME[key].r == c.r and ns.THEME[key].g == c.g and ns.THEME[key].b == c.b,
            "Forever " .. key .. " over the saved theme")
    end
    Check(Ratio(ns.THEME.fg, ns.THEME.bg) >= 4.5 and Ratio(ns.THEME.fg, ns.THEME.panel) >= 4.5, "its text is readable")
    Check(Ratio(ns.THEME.muted, ns.THEME.panel) >= 3 and Ratio(ns.THEME.accent, ns.THEME.panel) >= 3,
        "and its secondary text and accent")
    ns, handler = Load({ skin = "nonsense" })
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    Check(ns.Skin() == "" and not ns.foreverSkin, "an unknown skin is the default")
end
do
    local fonts = { ["Friz Quadrata TT"] = "friz", ["Arial Narrow"] = "arial", Naowh = "naowh", Morpheus = "morpheus",
        Expressway = "expressway" }
    local lsm = { LOCALE_BIT_ruRU = 1, LOCALE_BIT_western = 2 }
    function lsm:Register() end
    function lsm:Fetch(_, name) return fonts[name] end
    local function Stub() return lsm end
    local ns, handler = Load({ skin = "forever" }, Stub)
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    Check(ns.AddonFontPath() == "friz" and ns.HeadingFontPath() == "friz" and ns.DataFontPath() == "arial",
        "Forever: Friz Quadrata text and headings, Arial Narrow numbers, as Forever's own windows set them")
    Check(ns.AddonFontPath(false) == "naowh" and ns.HeadingFontPath(false) == "naowh",
        "asked for Naowh's fonts on Forever (the onboarding's preview): Naowh")
    ns.AccountSettings().uiFont = "Expressway"
    Check(ns.AddonFontPath() == "expressway" and ns.HeadingFontPath() == "expressway" and ns.DataFontPath() == "expressway",
        "a picked Addon Font is used for all of it")
    ns, handler = Load({}, Stub)
    Fire(handler, "ADDON_LOADED", "NaowhForever")
    Check(ns.AddonFontPath() == "naowh" and ns.HeadingFontPath() == "naowh" and ns.DataFontPath() == "naowh",
        "the default skin keeps Naowh for all of it")
    Check(ns.AddonFontPath(true) == "friz" and ns.HeadingFontPath(true) == "friz",
        "asked for Forever's fonts on the default skin (the onboarding's preview): the game's")
    Check(ns.AddonFontPath(false) == "naowh" and ns.HeadingFontPath(false) == "naowh", "and Naowh's: Naowh")
end

print("PASS custom colors: " .. cases .. " checks")

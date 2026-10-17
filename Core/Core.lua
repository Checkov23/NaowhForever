-- Core.lua: the namespace, the theme, the chrome primitives, the DB and its profiles.
local ADDON_NAME = ...

local MODULE_KEY = "NaowhForever"
local MEDIA = "Interface\\AddOns\\NaowhForever\\Core\\Media\\"
local NAOWH_FONT = MEDIA .. "Fonts\\Naowh.ttf"
local NAOWH_GRADIENT = MEDIA .. "NaowhGradient.tga"
local NAOWH_REVERSE_GRADIENT = MEDIA .. "NaowhReverseGradient.tga"
local PRINT_LOGO_PATH = MEDIA .. "LogoAddon.tga"
local PRINT_LOGO_DROP = 1
local BYTE = 255
local ROUND = 0.5
local PICK_TOLERANCE = 1 / 255
local ACCENT_SOFT_STEP, GREY_STEP = 0.33, 0.03
local CUSTOM = "custom"
local WARNING = { r = 1, g = 0.35, b = 0.35 }
local BLACK = { r = 0, g = 0, b = 0 }
local NO_OPTS, BORDER_EDGES = {}, 4
local LIBRARIES = { "CallbackHandler-1.0", "LibDataBroker-1.1", "LibDBIcon-1.0", "LibSharedMedia-3.0",
    "LibCustomGlow-1.0", "LibDeflate", "LibSerialize" }
local RELOAD_GLOW_ALPHA = 0.08
local STEM_INSET = 0.075
local MAX_FRAME_LEVEL = 9999
local OFFSCREEN = 0.9
local BUTTON_TEXT_SIZE, BUTTON_REST_ALPHA = 12, 0.9
local SKIN_CLASSIC, SKIN_FOREVER = "classic", "forever"
local FONT_NAOWH, FONT_CLASSIC, FONT_DATA = "Naowh", "Friz Quadrata TT", "Arial Narrow"
local FONT_HEADING = FONT_CLASSIC
local LOCALE_ADDON, ENGLISH = "NaowhForever_Locales", "enUS"
local GLYPH_FONTS = { koKR = "Fonts\\2002.TTF", zhCN = "Fonts\\ARKai_T.ttf", zhTW = "Fonts\\bLEI00D.ttf" }
local FRIZ_CYRILLIC = "Fonts\\FRIZQT___CYR.TTF"
local LANGUAGES = { "enUS", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
local LANGUAGE_NAMES = { enUS = "English", deDE = "Deutsch", esES = "Espa\195\177ol (Espa\195\177a)",
    esMX = "Espa\195\177ol (M\195\169xico)", frFR = "Fran\195\167ais", itIT = "Italiano",
    ptBR = "Portugu\195\170s (Brasil)", ruRU = "\208\160\209\131\209\129\209\129\208\186\208\184\208\185",
    koKR = "Korean", zhCN = "Chinese (Simplified)", zhTW = "Chinese (Traditional)" }
local MODAL_LEVEL_BASE, MODAL_LEVEL_STEP, MODAL_LEVEL_CAP, MODAL_PANEL_RAISE = 10, 10, 150, 5
local EDIT_INSET = 6
local SEARCH_HINT_SIZE, SEARCH_CLEAR_SIZE, SEARCH_CLEAR_TEXT = 12, 18, 13
local SEARCH_CLEAR_ROOM, SEARCH_CLEAR_X = 22, -2
local DIALOG_BUTTON_W, DIALOG_BUTTON_H, DIALOG_BUTTON_SHIFT, DIALOG_PAD = 96, 26, 52, 14
local DIALOG_HEAD_SIZE = 14
local PROMPT_W, PROMPT_H, PROMPT_TEXT_W, PROMPT_ROOM = 360, 130, 330, 110
local PROMPT_BOX_W, PROMPT_BOX_H, PROMPT_BOX_GAP, PROMPT_MAX_LETTERS = 320, 28, 12, 60
local COPY_W, COPY_H, COPY_TEXT_W, COPY_HEAD_Y = 520, 260, 460, 12
local COPY_HINT_SIZE, COPY_HINT_GAP, COPY_CLOSE_SIZE, COPY_CLOSE_INSET = 11, 6, 22, 8
local COPY_BODY_TOP, COPY_SCROLLBAR_ROOM, COPY_BOX_INSET = 54, 32, 4
local CONFIRM_W, CONFIRM_WIDE = 96, 150
local CONFIRM_H, CONFIRM_ROOM = 110, 74
local CONFIRM_PANEL_W, CONFIRM_TEXT_W, CONFIRM_TEXT_SIZE, CONFIRM_TEXT_Y, CONFIRM_BUTTON_GAP = 340, 310, 13, 18, 4
local DEFAULT_PROFILE = "Default"
local DB_VERSION = 1
local GUID_PATTERN, HEX = "^Player%-(%d+)%-(%x+)$", 16
local SCALE_DEFAULT, SCALE_MIN, SCALE_MAX, PERCENT = 100, 50, 200, 100
local LOGIN_APPLY_DELAY = 1
local DAMAGE_METER_ADDON, GAME_METER_CVAR, GAME_METER_SAVED = "NaowhForever_DamageMeter", "damageMeterEnabled",
    "damageMeterGameWas"
local GLIMMER_ADDON, GLIMMER_SAVED = "NaowhForever_QoL", { "glimmerSoftCVars", "glimmerSparkleCVars" }
local RETIRED_ADDONS = { "NaowhForever_Glimmer", "NaowhForever_GlimmerData", "NaowhForever_TopBar", "NaowhForever_GearSets",
    "NaowhForever_Blessings", "NaowhForever_AuraBuffs", "NaowhForever_ThreatMeter", "NaowhForever_PvP", "NaowhForever_SwingTimer",
    "NaowhForever_Language", "NaowhForever_ConsumableBar", "NaowhForever_InstanceTracker", "NaowhForever_Journeys",
    "NaowhForever_Macros", "NaowhForever_GroupInspect", "NaowhForever_ActionBars" }
local TEXT_RETIRED = "%s is now part of Quality of Life: delete its old folder from your AddOns folder."
local TEXT_RETIRED_COMBAT = "%s is now part of Naowh Forever: Combat: delete its old folder from your AddOns folder."
local TEXT_RETIRED_UTILITIES = "%s is now part of Naowh Forever: Utilities: delete its old folder from your AddOns folder."
local RETIRED_TEXT = { NaowhForever_GearSets = TEXT_RETIRED_COMBAT, NaowhForever_Blessings = TEXT_RETIRED_COMBAT,
    NaowhForever_AuraBuffs = TEXT_RETIRED_COMBAT, NaowhForever_ThreatMeter = TEXT_RETIRED_COMBAT,
    NaowhForever_PvP = TEXT_RETIRED_COMBAT, NaowhForever_SwingTimer = TEXT_RETIRED_COMBAT,
    NaowhForever_ConsumableBar = TEXT_RETIRED_COMBAT, NaowhForever_InstanceTracker = TEXT_RETIRED_UTILITIES,
    NaowhForever_Journeys = TEXT_RETIRED_UTILITIES, NaowhForever_Macros = TEXT_RETIRED_UTILITIES,
    NaowhForever_GroupInspect = TEXT_RETIRED_UTILITIES, NaowhForever_ActionBars = TEXT_RETIRED_UTILITIES,
    NaowhForever_Language = "%s is now part of Naowh Forever: delete its old folder from your AddOns folder." }
local TEXT_RETIRED_RELOAD = "Old Naowh Forever folders were switched off. Reload now to finish?"
local ERR_NO_PROFILE = "no such profile"
local TEXT_SECRET = "(withheld: this line contained a secret value)"
local TEXT_LIBRARIES_MISSING = "Libraries missing (%s), so parts of the addon will not work. Download Naowh "
    .. "Forever from the Releases page or the Naowh Discord, not with the green Code button on GitHub."
local TEXT_RELOAD_BLOCKED = "Can't reload from a button in combat. Type /reload."
local TEXT_COPY_HINT = "Ctrl+A, Ctrl+C to copy"
local TEXT_GAME_DEFAULT = "Game Default"
local UTF8_LATIN = "\195"
local LATIN_CAPITAL, LATIN_SMALL = "\195([\128-\158])", "\195([\160-\190])"
local LATIN_CASE_STEP, LATIN_TIMES, LATIN_DIVIDE = 32, 151, 183
local SHARP_S, SHARP_S_UPPER = "\195\159", "SS"

local ns = {}
_G.NaowhForever = ns
ns.MODULE_KEY = MODULE_KEY
ns.MEDIA = MEDIA

local function PickLocale()
    local sv = _G.NaowhForeverDB
    local account = type(sv) == "table" and sv.account
    local pick = type(account) == "table" and account.language or nil
    ns.LANGUAGE_PICK = pick
    if LANGUAGE_NAMES[pick or ""] then return pick end
    local client = GetLocale and GetLocale() or ENGLISH
    return LANGUAGE_NAMES[client] and client or ENGLISH
end

ns.LOCALE = PickLocale()
ns.LANGUAGES, ns.LANGUAGE_NAMES = LANGUAGES, LANGUAGE_NAMES
if ns.LOCALE ~= ENGLISH then
    C_AddOns.LoadAddOn(LOCALE_ADDON)
end

local catalog = {}
for key, text in pairs(_G.NaowhForeverLocale or {}) do
    if text ~= true then catalog[key] = text end
end
_G.NaowhForeverLocale = nil
local translation = _G.NaowhForeverTranslation or {}
function ns.L(key, ...)
    local text = translation[key]
    if text == nil or text == true then text = catalog[key] end
    if text == nil or text == true then text = key end
    if select("#", ...) > 0 then return text:format(...) end
    return text
end

local function LatinUpper(byte)
    local b = byte:byte()
    if b == LATIN_DIVIDE then return nil end
    return UTF8_LATIN .. string.char(b - LATIN_CASE_STEP)
end

local function LatinLower(byte)
    local b = byte:byte()
    if b == LATIN_TIMES then return nil end
    return UTF8_LATIN .. string.char(b + LATIN_CASE_STEP)
end

function ns.Upper(text)
    return (text:upper():gsub(LATIN_SMALL, LatinUpper):gsub(SHARP_S, SHARP_S_UPPER))
end

function ns.Lower(text)
    return (text:lower():gsub(LATIN_CAPITAL, LatinLower))
end

ns.CODE_BUILD = "1.1.28"

ns.THEME = {
    bg     = { r = 0x19 / 255, g = 0x1b / 255, b = 0x1d / 255 },
    panel  = { r = 0x1e / 255, g = 0x20 / 255, b = 0x22 / 255 },
    line   = { r = 0x37 / 255, g = 0x3b / 255, b = 0x40 / 255 },
    fg     = { r = 0xf0 / 255, g = 0xf1 / 255, b = 0xf3 / 255 },
    muted  = { r = 0x9a / 255, g = 0x9e / 255, b = 0xa6 / 255 },
    grey   = { r = 0x3d / 255, g = 0x41 / 255, b = 0x46 / 255 },
    accent     = { r = 0x00 / 255, g = 0x91 / 255, b = 0xed / 255 },
    accentSoft = { r = 0x4d / 255, g = 0xb5 / 255, b = 0xf5 / 255 },
}

ns.THEME_EDITABLE = { "bg", "panel", "line", "fg", "muted", "accent" }
ns.THEME_PRESET_ORDER = { "midnight", "slate", "obsidian", "aubergine", "forest", "crimson", "rosenoir",
    "cottoncandy", "classic" }
ns.THEME_PRESETS = {
    midnight = { name = "Midnight",
        bg     = { r = 0x0b / 255, g = 0x10 / 255, b = 0x20 / 255 },
        panel  = { r = 0x15 / 255, g = 0x1c / 255, b = 0x30 / 255 },
        line   = { r = 0x2a / 255, g = 0x35 / 255, b = 0x50 / 255 },
        fg     = { r = 0xee / 255, g = 0xf2 / 255, b = 0xff / 255 },
        muted  = { r = 0x9b / 255, g = 0xa7 / 255, b = 0xc8 / 255 },
        accent = { r = 0x5b / 255, g = 0x8c / 255, b = 0xff / 255 } },
    slate = { name = "Slate",
        bg     = { r = 0x12 / 255, g = 0x16 / 255, b = 0x1c / 255 },
        panel  = { r = 0x1e / 255, g = 0x24 / 255, b = 0x2d / 255 },
        line   = { r = 0x36 / 255, g = 0x40 / 255, b = 0x4d / 255 },
        fg     = { r = 0xf0 / 255, g = 0xf3 / 255, b = 0xf5 / 255 },
        muted  = { r = 0x9a / 255, g = 0xa7 / 255, b = 0xb4 / 255 },
        accent = { r = 0x2b / 255, g = 0xb8 / 255, b = 0xa8 / 255 } },
    obsidian = { name = "Obsidian",
        bg     = { r = 0x07 / 255, g = 0x07 / 255, b = 0x08 / 255 },
        panel  = { r = 0x13 / 255, g = 0x14 / 255, b = 0x17 / 255 },
        line   = { r = 0x2b / 255, g = 0x2d / 255, b = 0x32 / 255 },
        fg     = { r = 0xf5 / 255, g = 0xf5 / 255, b = 0xf4 / 255 },
        muted  = { r = 0xa1 / 255, g = 0xa1 / 255, b = 0xa6 / 255 },
        accent = { r = 0xf5 / 255, g = 0xa5 / 255, b = 0x24 / 255 } },
    aubergine = { name = "Aubergine",
        bg     = { r = 0x13 / 255, g = 0x0d / 255, b = 0x18 / 255 },
        panel  = { r = 0x1f / 255, g = 0x16 / 255, b = 0x26 / 255 },
        line   = { r = 0x3a / 255, g = 0x2c / 255, b = 0x46 / 255 },
        fg     = { r = 0xf3 / 255, g = 0xee / 255, b = 0xf7 / 255 },
        muted  = { r = 0xa8 / 255, g = 0x9b / 255, b = 0xb8 / 255 },
        accent = { r = 0xb5 / 255, g = 0x7b / 255, b = 0xff / 255 } },
    forest = { name = "Forest",
        bg     = { r = 0x0c / 255, g = 0x13 / 255, b = 0x10 / 255 },
        panel  = { r = 0x16 / 255, g = 0x20 / 255, b = 0x19 / 255 },
        line   = { r = 0x2c / 255, g = 0x3b / 255, b = 0x31 / 255 },
        fg     = { r = 0xee / 255, g = 0xf4 / 255, b = 0xef / 255 },
        muted  = { r = 0x9a / 255, g = 0xae / 255, b = 0x9f / 255 },
        accent = { r = 0x36 / 255, g = 0xc5 / 255, b = 0x8a / 255 } },
    crimson = { name = "Crimson",
        bg     = { r = 0x14 / 255, g = 0x0a / 255, b = 0x0c / 255 },
        panel  = { r = 0x20 / 255, g = 0x13 / 255, b = 0x16 / 255 },
        line   = { r = 0x3d / 255, g = 0x24 / 255, b = 0x29 / 255 },
        fg     = { r = 0xf6 / 255, g = 0xef / 255, b = 0xf0 / 255 },
        muted  = { r = 0xac / 255, g = 0x9a / 255, b = 0x9e / 255 },
        accent = { r = 0xef / 255, g = 0x4b / 255, b = 0x56 / 255 } },
    rosenoir = { name = "Rose Noir",
        bg     = { r = 0x1a / 255, g = 0x0b / 255, b = 0x14 / 255 },
        panel  = { r = 0x27 / 255, g = 0x12 / 255, b = 0x1d / 255 },
        line   = { r = 0x4a / 255, g = 0x24 / 255, b = 0x38 / 255 },
        fg     = { r = 0xfd / 255, g = 0xee / 255, b = 0xf5 / 255 },
        muted  = { r = 0xc9 / 255, g = 0xa3 / 255, b = 0xb6 / 255 },
        accent = { r = 0xff / 255, g = 0x5f / 255, b = 0xa2 / 255 } },
    cottoncandy = { name = "Cotton Candy",
        bg     = { r = 0x1c / 255, g = 0x18 / 255, b = 0x32 / 255 },
        panel  = { r = 0x27 / 255, g = 0x22 / 255, b = 0x45 / 255 },
        line   = { r = 0x46 / 255, g = 0x3f / 255, b = 0x70 / 255 },
        fg     = { r = 0xf8 / 255, g = 0xf2 / 255, b = 0xff / 255 },
        muted  = { r = 0xbb / 255, g = 0xb2 / 255, b = 0xdc / 255 },
        accent = { r = 0xf7 / 255, g = 0x8f / 255, b = 0xc8 / 255 } },
    classic = { name = "Classic",
        bg     = { r = 0x15 / 255, g = 0x10 / 255, b = 0x0b / 255 },
        panel  = { r = 0x22 / 255, g = 0x1a / 255, b = 0x12 / 255 },
        line   = { r = 0x4d / 255, g = 0x3c / 255, b = 0x26 / 255 },
        fg     = { r = 0xf4 / 255, g = 0xe8 / 255, b = 0xcc / 255 },
        muted  = { r = 0xa8 / 255, g = 0x9a / 255, b = 0x7c / 255 },
        accent = { r = 0xd6 / 255, g = 0x8e / 255, b = 0x35 / 255 } },
}

ns.FOREVER_SKIN = {
    bg     = { r = 0x11 / 255, g = 0x10 / 255, b = 0x0e / 255 },
    panel  = { r = 0x1b / 255, g = 0x19 / 255, b = 0x16 / 255 },
    line   = { r = 0x6e / 255, g = 0x51 / 255, b = 0x26 / 255 },
    fg     = { r = 0xe8 / 255, g = 0xda / 255, b = 0xb4 / 255 },
    muted  = { r = 0x9a / 255, g = 0x8f / 255, b = 0x7a / 255 },
    accent = { r = 0xff / 255, g = 0xd1 / 255, b = 0x00 / 255 },
}

local colorPrefix = {}

local function Byte(v)
    return math.floor(v * BYTE + ROUND)
end

function ns.Color(token, text)
    local prefix = colorPrefix[token]
    if not prefix then
        local c = type(token) == "table" and token or ns.THEME[token]
        prefix = ("|cff%02x%02x%02x"):format(Byte(c.r), Byte(c.g), Byte(c.b))
        if type(token) == "string" then colorPrefix[token] = prefix end
    end
    if text == nil then return prefix end
    return prefix .. text .. "|r"
end

function ns.PlainText(text, max)
    if type(text) ~= "string" then return nil end
    if max and #text > max then text = text:sub(1, max) end
    return (text:gsub("%c", " "):gsub("||", "\1"):gsub("|", "||"):gsub("\1", "||"))
end

local themeShipped = {}

local function Channel(v)
    v = tonumber(v)
    if not v then return nil end
    return math.min(1, math.max(0, v))
end

local function Pick(source, key)
    local c = type(source) == "table" and source[key]
    if type(c) ~= "table" then return nil end
    local r, g, b = Channel(c.r), Channel(c.g), Channel(c.b)
    if r and g and b then return r, g, b end
end

local function ThemeSource()
    if ns.foreverSkin then return ns.FOREVER_SKIN end
    local account = ns.AccountSettings()
    local preset = account.themePreset
    if preset == CUSTOM then return account.themeColors end
    return type(preset) == "string" and ns.THEME_PRESETS[preset] or nil
end

local function Paint(key, r, g, b)
    local t = ns.THEME[key]
    if not themeShipped[key] then themeShipped[key] = { r = t.r, g = t.g, b = t.b } end
    t.r, t.g, t.b = r, g, b
end

local function Lightened(t, amount)
    return t.r + (1 - t.r) * amount, t.g + (1 - t.g) * amount, t.b + (1 - t.b) * amount
end

local function Shipped(key, r, g, b)
    local t = themeShipped[key] or ns.THEME[key]
    return math.abs(r - t.r) <= PICK_TOLERANCE and math.abs(g - t.g) <= PICK_TOLERANCE
        and math.abs(b - t.b) <= PICK_TOLERANCE
end

local function ShippedColor(key)
    local t = themeShipped[key] or ns.THEME[key]
    return t.r, t.g, t.b
end

function ns.ApplyThemeColors()
    local account = ns.AccountSettings()
    if account.skin == SKIN_CLASSIC then account.skin = SKIN_FOREVER end
    ns.skin = account.skin == SKIN_FOREVER and SKIN_FOREVER or ""
    ns.foreverSkin = ns.skin == SKIN_FOREVER
    local source = ThemeSource()
    if not source then return end
    for _, key in ipairs(ns.THEME_EDITABLE) do
        local r, g, b = Pick(source, key)
        if r and not Shipped(key, r, g, b) then Paint(key, r, g, b) end
    end
    if themeShipped.accent then Paint("accentSoft", Lightened(ns.THEME.accent, ACCENT_SOFT_STEP)) end
    if themeShipped.line then Paint("grey", Lightened(ns.THEME.line, GREY_STEP)) end
    for key in pairs(colorPrefix) do colorPrefix[key] = nil end
end

function ns.Skin()
    return ns.skin or ""
end

function ns.ThemePresetKey()
    local preset = ns.AccountSettings().themePreset
    if preset == CUSTOM or (type(preset) == "string" and ns.THEME_PRESETS[preset]) then
        return preset
    end
    return ""
end

local function HasPicks(colors)
    for _, key in ipairs(ns.THEME_EDITABLE) do
        if Pick(colors, key) then return true end
    end
    return false
end

local function PalettePicks(name)
    local from = ns.THEME_PRESETS[name]
    local picks = {}
    for _, key in ipairs(ns.THEME_EDITABLE) do
        local r, g, b = Pick(from, key)
        if not r then r, g, b = ShippedColor(key) end
        picks[key] = { r = r, g = g, b = b }
    end
    return picks
end

function ns.SetThemePreset(name)
    local account = ns.AccountSettings()
    local previous = ns.ThemePresetKey()
    if name == CUSTOM then
        if previous ~= CUSTOM and not HasPicks(account.themeColors) then
            account.themeColors = PalettePicks(previous)
        end
        account.themePreset = CUSTOM
    elseif type(name) == "string" and ns.THEME_PRESETS[name] then
        account.themePreset = name
    else
        account.themePreset = nil
    end
end

function ns.CopyThemeToCustom(name)
    ns.AccountSettings().themeColors = PalettePicks(name)
end

function ns.ThemePalette(key)
    local out = {}
    for i, token in ipairs(ns.THEME_EDITABLE) do
        local r, g, b
        if key == CUSTOM then
            r, g, b = ns.ThemeSwatchColor(token)
        else
            local c = PalettePicks(key)[token]
            r, g, b = c.r, c.g, c.b
        end
        out[i] = { r = r, g = g, b = b }
    end
    return out
end

function ns.ThemeSwatchColor(key)
    local r, g, b = Pick(ns.AccountSettings().themeColors, key)
    if r then return r, g, b end
    return ShippedColor(key)
end

function ns.ThemeTint(key, literal)
    if themeShipped[key] then return ns.THEME[key] end
    return literal
end

ns.PRINT_LOGO = ("|T%s:0:0:0:%d|t"):format(PRINT_LOGO_PATH, -PRINT_LOGO_DROP)

function ns.Print(msg)
    if issecretvalue and issecretvalue(msg) then
        msg = ns.Color("accent", ns.L(TEXT_SECRET))
    end
    print(ns.PRINT_LOGO .. " " .. ns.Color("accent", "Naowh") .. " Forever: " .. tostring(msg))
end

local function OnLibraryCheck()
    local missing = {}
    for _, name in ipairs(LIBRARIES) do
        if not (LibStub and LibStub(name, true)) then missing[#missing + 1] = name end
    end
    if #missing == 0 then return end
    ns.Print(ns.Color(WARNING, ns.L(TEXT_LIBRARIES_MISSING, table.concat(missing, ", "))))
end

local libCheck = CreateFrame("Frame")
libCheck:RegisterEvent("PLAYER_LOGIN")
libCheck:SetScript("OnEvent", OnLibraryCheck)

local function RestoreGameMeter()
    local account = ns.AccountSettings()
    if account[GAME_METER_SAVED] == nil or C_AddOns.IsAddOnLoaded(DAMAGE_METER_ADDON) or InCombatLockdown() then
        return
    end
    C_CVar.SetCVar(GAME_METER_CVAR, account[GAME_METER_SAVED])
    account[GAME_METER_SAVED] = nil
end

local function RestoreGlimmerSettings()
    if C_AddOns.IsAddOnLoaded(GLIMMER_ADDON) or InCombatLockdown() then return end
    local account = ns.AccountSettings()
    for _, slot in ipairs(GLIMMER_SAVED) do
        for name, value in pairs(account[slot] or {}) do C_CVar.SetCVar(name, value) end
        account[slot] = nil
    end
end

local function RetireOldFolders()
    local reload = false
    for _, addon in ipairs(RETIRED_ADDONS) do
        if C_AddOns.DoesAddOnExist(addon) then
            C_AddOns.DisableAddOn(addon)
            ns.Print(ns.L(RETIRED_TEXT[addon] or TEXT_RETIRED):format(addon))
            reload = reload or C_AddOns.IsAddOnLoaded(addon)
        end
    end
    if reload then ns.ConfirmReload(ns.L(TEXT_RETIRED_RELOAD)) end
end

local meterCheck = CreateFrame("Frame")
meterCheck:RegisterEvent("PLAYER_LOGIN")
meterCheck:SetScript("OnEvent", function()
    local oldLanguage, account = _G.NaowhForeverLanguageDB, ns.AccountSettings()
    if type(oldLanguage) == "table" and account.language == nil then account.language = oldLanguage.locale end
    RetireOldFolders()
    RestoreGameMeter()
    RestoreGlimmerSettings()
end)

do
local reloader
local reloadButtons = {}
local reloadReason
local TEXT_RELOAD_REQUIRED = "Reload required"
local TEXT_RELOAD_PENDING = "%s *"

local function HideReloaderOnLeave(self)
    if not InCombatLockdown() then self:Hide() end
end

local function Reloader()
    if reloader then return reloader end
    reloader = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    reloader:SetFrameStrata("TOOLTIP")
    reloader:RegisterForClicks("AnyUp", "AnyDown")
    reloader:SetAttribute("type", "macro")
    reloader:SetAttribute("macrotext", "/reload")
    local glow = reloader:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, RELOAD_GLOW_ALPHA)
    reloader:SetScript("OnLeave", HideReloaderOnLeave)
    reloader:RegisterEvent("PLAYER_REGEN_DISABLED")
    reloader:SetScript("OnEvent", reloader.Hide)
    reloader:Hide()
    return reloader
end

local function CoverWithReload(btn)
    if InCombatLockdown() then return end
    local cover = Reloader()
    local scale = btn:GetEffectiveScale() / UIParent:GetEffectiveScale()
    cover:ClearAllPoints()
    cover:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", btn:GetLeft() * scale, btn:GetBottom() * scale)
    cover:SetSize(btn:GetWidth() * scale, btn:GetHeight() * scale)
    if reloadReason then ns.Tooltip(cover, TEXT_RELOAD_REQUIRED, function() return reloadReason end) end
    cover:Show()
end

local function ReloadBlocked()
    ns.Print(ns.L(TEXT_RELOAD_BLOCKED))
end

function ns.MakeReloadButton(btn)
    btn._onClick = ReloadBlocked
    if not btn._reload then
        btn._reload = true
        btn:HookScript("OnEnter", CoverWithReload)
    end
    return btn
end

local function PaintReloadButton(btn)
    if not reloadReason then return end
    ns.AccentBorder(btn)
    ns.SetButtonText(btn, ns.L(TEXT_RELOAD_PENDING, ns.L(btn._reloadText)))
    ns.Tooltip(btn, TEXT_RELOAD_REQUIRED, function() return reloadReason end)
end

function ns.MarkReloadRequired(text)
    reloadReason = ns.L(text)
    for _, btn in ipairs(reloadButtons) do PaintReloadButton(btn) end
end

function ns.ReloadButton(parent, text, w, h)
    local btn = ns.MakeReloadButton(ns.Button(parent, text, w, h))
    btn._reloadText = text
    reloadButtons[#reloadButtons + 1] = btn
    PaintReloadButton(btn)
    return btn
end

end

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
if LSM then
    LSM:Register("font", "Naowh", NAOWH_FONT, LSM.LOCALE_BIT_ruRU + LSM.LOCALE_BIT_western)
    LSM:Register("statusbar", "Naowh Gradient", NAOWH_GRADIENT)
    LSM:Register("statusbar", "Naowh Reverse Gradient", NAOWH_REVERSE_GRADIENT)
end

ns.BLIZZARD_FONT = "__blizzard"
function ns.LocaleFont(name, path)
    if GLYPH_FONTS[ns.LOCALE] then return GLYPH_FONTS[ns.LOCALE] end
    if ns.LOCALE == "ruRU" and name == FONT_CLASSIC then return FRIZ_CYRILLIC end
    return path
end

local function FontPath(name)
    if name == nil or name == ns.BLIZZARD_FONT or not LSM then return nil end
    return ns.LocaleFont(name, LSM:Fetch("font", name, true) or LSM:Fetch("font", "Naowh", true))
end

local uiFontPath

function ns.FontInset(size)
    return size * STEM_INSET
end

function ns.AddonFontPath(classic)
    if classic == nil then classic = ns.foreverSkin end
    local default = classic and FONT_CLASSIC or FONT_NAOWH
    return FontPath(ns.AccountSettings().uiFont or default) or ns.LocaleFont(default, STANDARD_TEXT_FONT)
end

function ns.HeadingFontPath(classic)
    if classic ~= nil then
        if not classic or ns.AccountSettings().uiFont then return ns.AddonFontPath(classic) end
        return FontPath(FONT_HEADING) or ns.AddonFontPath(classic)
    end
    if not ns.foreverSkin or ns.AccountSettings().uiFont then return ns.UIFontPath() end
    return FontPath(FONT_HEADING) or ns.UIFontPath()
end

function ns.DataFontPath()
    if not ns.foreverSkin or ns.AccountSettings().uiFont then return ns.UIFontPath() end
    return FontPath(FONT_DATA) or ns.UIFontPath()
end

function ns.UIFontPath()
    if not uiFontPath then uiFontPath = ns.AddonFontPath() end
    return uiFontPath
end

local function SetGameFontObjects(game)
    local fonts = GetFonts()
    for i = 1, #fonts do
        local obj = _G[fonts[i]]
        if type(obj) == "table" and obj.GetFont then
            local _, size, flags = obj:GetFont()
            if size and size > 0 then obj:SetFont(game, size, flags) end
        end
    end
end

local function SetFontObjects(game, combat)
    local combatObjects = { CombatTextFont, CombatTextFontOutline }
    local combatFonts = {}
    for i, obj in ipairs(combatObjects) do combatFonts[i] = { obj:GetFont() } end
    if game then SetGameFontObjects(game) end
    for i, obj in ipairs(combatObjects) do
        local path, size, flags = unpack(combatFonts[i])
        if size and size > 0 then obj:SetFont(combat or path, size, flags) end
    end
end

local function OnGameFontEvent(self, event, name)
    if event == "ADDON_LOADED" and name ~= ADDON_NAME then return end
    if event == "ADDON_LOADED" then ns.ApplyThemeColors() end
    local account = ns.AccountSettings()
    local game, combat = FontPath(account.gameFont), FontPath(account.combatFont)
    if not (game or combat) then
        self:UnregisterAllEvents()
        return
    end
    if game then STANDARD_TEXT_FONT, UNIT_NAME_FONT = game, game end
    if combat then DAMAGE_TEXT_FONT = combat end
    if event == "ADDON_LOADED" then return end
    self:UnregisterAllEvents()
    SetFontObjects(game, combat)
end

local gameFontEvents = CreateFrame("Frame")
gameFontEvents:RegisterEvent("ADDON_LOADED")
gameFontEvents:RegisterEvent("PLAYER_LOGIN")
gameFontEvents:SetScript("OnEvent", OnGameFontEvent)

function ns.Font(parent, size, flags, color, heading)
    local c = color or ns.THEME.fg
    local fs = parent:CreateFontString(nil, "OVERLAY")
    if heading and ns.foreverSkin then
        local St = ns.Shared.Style
        size = size + St.CLASSIC_HEADING_STEP
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(St.CLASSIC_HEADING_SHADOW, -St.CLASSIC_HEADING_SHADOW)
    end
    fs:SetFont(heading and ns.HeadingFontPath() or ns.UIFontPath(), size, flags or "")
    fs:SetTextColor(c.r, c.g, c.b, 1)
    return fs
end

local fitters = setmetatable({}, { __mode = "k" })

local function OnePixel(region)
    return PixelUtil.GetPixelToUIUnitFactor() / region:GetEffectiveScale()
end
ns.OnePixel = OnePixel

local function FitOwner(owner)
    for region, fit in pairs(fitters[owner]) do fit(OnePixel(region)) end
end

local function Register(region, fit)
    local owner = region:GetObjectType() == "Texture" and region:GetParent() or region
    if not fitters[owner] then
        fitters[owner] = setmetatable({}, { __mode = "k" })
        local watch = CreateFrame("Frame", nil, owner)
        watch:SetScript("OnShow", function() FitOwner(owner) end)
    end
    fitters[owner][region] = fit
    fit(OnePixel(region))
end

function ns.Hairline(tex, axis)
    Register(tex, function(px)
        if axis == "h" then tex:SetHeight(px) else tex:SetWidth(px) end
    end)
    return tex
end

function ns.PixelInset(region, n, relativeTo)
    Register(region, function(px)
        local d = n * px
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", relativeTo or region:GetParent(), "TOPLEFT", d, -d)
        region:SetPoint("BOTTOMRIGHT", relativeTo or region:GetParent(), "BOTTOMRIGHT", -d, d)
    end)
    return region
end

function ns.RefitPixels()
    for owner in pairs(fitters) do
        if owner:IsVisible() then FitOwner(owner) end
    end
end

local pixelEvents = CreateFrame("Frame")
pixelEvents:RegisterEvent("UI_SCALE_CHANGED")
pixelEvents:RegisterEvent("DISPLAY_SIZE_CHANGED")
pixelEvents:SetScript("OnEvent", function() ns.RefitPixels() end)

function ns.Border(frame, color, alpha)
    local c = color or ns.THEME.line
    local a = alpha or 1
    local bf = CreateFrame("Frame", nil, frame)
    bf:SetAllPoints()
    bf:SetFrameLevel(math.min(frame:GetFrameLevel() + 1, MAX_FRAME_LEVEL))
    local edges = {}
    for i = 1, BORDER_EDGES do
        local t = bf:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(c.r, c.g, c.b, a)
        edges[i] = t
    end
    local border = { _frame = bf, pixels = 1 }
    local function Fit(edge, axis)
        Register(edge, function(px)
            local size = border.pixels * px
            if axis == "h" then edge:SetHeight(size) else edge:SetWidth(size) end
        end)
    end
    edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); Fit(edges[1], "h")
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); Fit(edges[2], "h")
    edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); Fit(edges[3], "v")
    edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); Fit(edges[4], "v")
    function border.SetColor(_, r, g, b, a2)
        for i = 1, BORDER_EDGES do edges[i]:SetColorTexture(r, g, b, a2 or 1) end
    end
    function border.SetPixels(self, pixels)
        if self.pixels == pixels then return end
        self.pixels = pixels
        FitOwner(bf)
    end
    return border
end

function ns.Solid(parent, layer, color, alpha)
    local c = color or ns.THEME.panel
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(c.r, c.g, c.b, alpha or 1)
    return t
end

local function ClampOffscreen(frame, w, h)
    frame:SetClampRectInsets(w * OFFSCREEN, -w * OFFSCREEN, 0, h * OFFSCREEN)
end

function ns.AllowOffscreen(frame)
    ClampOffscreen(frame, frame:GetWidth(), frame:GetHeight())
    frame:HookScript("OnSizeChanged", ClampOffscreen)
end

function ns.Button(parent, text, w, h, onClick, template)
    local T = ns.THEME
    local btn = CreateFrame("Button", nil, parent, template)
    btn:SetSize(w, h)
    local bg = ns.Solid(btn, "BACKGROUND", T.panel, BUTTON_REST_ALPHA)
    bg:SetAllPoints()
    local rest = ns.foreverSkin and BLACK or T.line
    local border = ns.Border(btn, rest)
    btn._border, btn._rest = border, rest
    btn._bg = bg
    local lbl = ns.Font(btn, BUTTON_TEXT_SIZE, nil, nil, true)
    lbl:SetPoint("CENTER")
    lbl:SetText(ns.L(text))
    btn.label = lbl
    btn._onClick = onClick
    if not template then btn:SetScript("OnClick", function() if btn._onClick then btn._onClick() end end) end
    if ns.foreverSkin then
        ns.Shared.Parts.ForeverButton(btn, bg, border, lbl)
        return btn
    end
    btn:SetScript("OnEnter", function()
        local fill = btn._primary and T.accentSoft or T.panel
        bg:SetColorTexture(fill.r, fill.g, fill.b, 1)
        border:SetColor(T.accent.r, T.accent.g, T.accent.b, 1)
    end)
    btn:SetScript("OnLeave", function()
        local fill = btn._primary and T.accent or T.panel
        bg:SetColorTexture(fill.r, fill.g, fill.b, btn._primary and 1 or BUTTON_REST_ALPHA)
        border:SetColor(btn._rest.r, btn._rest.g, btn._rest.b, 1)
    end)
    return btn
end

function ns.AccentBorder(frame)
    if frame and frame._forever then return frame end
    if not (frame and frame._border) or frame._art then return frame end
    local accent = ns.THEME.accent
    frame._rest = accent
    frame._border:SetColor(accent.r, accent.g, accent.b, 1)
    return frame
end

function ns.PrimaryButton(btn)
    if not btn or btn._forever then return btn end
    ns.AccentBorder(btn)
    btn._primary = true
    local T = ns.THEME
    btn._bg:SetColorTexture(T.accent.r, T.accent.g, T.accent.b, 1)
    btn.label:SetTextColor(T.bg.r, T.bg.g, T.bg.b, 1)
    return btn
end

function ns.SetButtonText(btn, text)
    if not (btn and btn.label) then return end
    btn.label:SetText(ns.L(text))
end

local function ComposeTooltip(frame)
    local b = frame._tipBody
    if type(b) == "function" then b = b() end
    local title = ns.L(frame._tipTitle)
    if b and b ~= "" then
        return ns.Color("accent", title) .. "\n" .. ns.L(b)
    end
    return title
end

local TOOLTIP_OPTS = { anchor = "cursor", justify = "LEFT" }

local function OnTooltipEnter(self)
    local UI = ns.UI
    if UI and UI.ShowWidgetTooltip then
        UI.ShowWidgetTooltip(self, function() return ComposeTooltip(self) end, TOOLTIP_OPTS)
    end
end

local function OnTooltipLeave()
    local UI = ns.UI
    if UI and UI.HideWidgetTooltip then UI.HideWidgetTooltip() end
end

function ns.Tooltip(frame, title, body)
    frame._tipTitle, frame._tipBody = title, body
    if frame._tipHooked then return end
    frame._tipHooked = true
    frame:HookScript("OnEnter", OnTooltipEnter)
    frame:HookScript("OnLeave", OnTooltipLeave)
end

local nextModalLevel = MODAL_LEVEL_BASE

local shells = {}

local function ReuseShell(shell, width, height)
    shell.dimmer:Hide()
    shell.dimmer.onClose = nil
    local panel = shell.panel
    panel:SetSize(width, height)
    panel:SetScale(ns.UIScale())
    panel:ClearAllPoints()
    panel:SetPoint("CENTER")
    ns.UI.BeginReusableRows(panel)
    return shell.dimmer, panel
end

local function OnModalKeyDown(self, key)
    if InCombatLockdown() then return end
    if key == "ESCAPE" then
        self:Hide()
        self:SetPropagateKeyboardInput(false)
        C_Timer.After(0, function()
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
        end)
    else
        self:SetPropagateKeyboardInput(true)
    end
end

local function OnModalHide(self)
    local fn = self.onClose
    self.onClose = nil
    if fn then fn() end
end

local function StartMoving(self) self:StartMoving() end
local function StopMoving(self) self:StopMovingOrSizing() end

local function ModalPanel(dimmer, width, height)
    local panel = CreateFrame("Frame", nil, dimmer)
    panel:SetSize(width, height)
    panel:SetPoint("CENTER")
    panel:SetScale(ns.UIScale())
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:EnableMouse(true)
    local bg = ns.Solid(panel, "BACKGROUND", ns.THEME.panel, 1)
    bg:SetAllPoints()
    ns.Border(panel)

    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", StartMoving)
    panel:SetScript("OnDragStop", StopMoving)
    return panel
end

function ns.MakeModal(width, height, key)
    local shell = key and shells[key]
    if shell then return ReuseShell(shell, width, height) end
    local dimmer = CreateFrame("Frame", nil, UIParent)
    dimmer:SetAllPoints(UIParent)
    dimmer:SetFrameStrata("FULLSCREEN_DIALOG")
    dimmer:EnableMouse(false)
    local panel = ModalPanel(dimmer, width, height)

    dimmer:SetScript("OnKeyDown", OnModalKeyDown)

    dimmer:SetScript("OnShow", function(self)
        if not InCombatLockdown() then
            self:EnableKeyboard(true)
            self:SetPropagateKeyboardInput(true)
        end
        if nextModalLevel > MODAL_LEVEL_CAP then nextModalLevel = MODAL_LEVEL_BASE end
        nextModalLevel = nextModalLevel + MODAL_LEVEL_STEP
        self:SetFrameLevel(nextModalLevel)
        panel:SetFrameLevel(nextModalLevel + MODAL_PANEL_RAISE)
    end)
    dimmer:Hide()
    dimmer:SetScript("OnHide", OnModalHide)

    ns.UI.BeginReusableRows(panel)
    if key then shells[key] = { dimmer = dimmer, panel = panel } end
    return dimmer, panel
end

function ns.NewEditBox(parent, opts)
    opts = opts or NO_OPTS
    local box = CreateFrame("EditBox", nil, parent)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlight")
    local inset = opts.inset or EDIT_INSET
    box:SetTextInsets(inset, inset, 0, 0)
    box._fill = ns.Solid(box, "BACKGROUND", ns.THEME.bg, 1)
    box._fill:SetAllPoints()
    local edge = opts.border or BLACK
    box._border = ns.Border(box, edge)
    box.border = box._border
    if opts.hover ~= false and not ns.foreverSkin then
        box:HookScript("OnEnter", function()
            local a = ns.THEME.accent
            box._border:SetColor(a.r, a.g, a.b, 1)
        end)
        box:HookScript("OnLeave", function() box._border:SetColor(edge.r, edge.g, edge.b, 1) end)
    end
    if ns.foreverSkin and opts.sunken ~= false then ns.Shared.Parts.ForeverField(box) end
    return box
end

local function ClearSearch(box)
    box:SetText("")
    box:ClearFocus()
end

local function SearchClearButton(box, T)
    local clear = CreateFrame("Button", nil, box)
    clear:SetSize(SEARCH_CLEAR_SIZE, SEARCH_CLEAR_SIZE)
    clear:SetPoint("RIGHT", SEARCH_CLEAR_X, 0)
    clear.text = ns.Font(clear, SEARCH_CLEAR_TEXT, nil, T.muted)
    clear.text:SetPoint("CENTER")
    clear.text:SetText("X")
    clear:SetScript("OnClick", function() ClearSearch(box) end)
    clear:SetScript("OnEnter", function() clear.text:SetTextColor(T.accent.r, T.accent.g, T.accent.b, 1) end)
    clear:SetScript("OnLeave", function() clear.text:SetTextColor(T.muted.r, T.muted.g, T.muted.b, 1) end)
    clear:Hide()
    return clear
end

function ns.NewSearchBox(parent, hint, onChange)
    local T = ns.THEME
    local box = ns.NewEditBox(parent)
    box.hint = ns.Font(box, SEARCH_HINT_SIZE, nil, T.muted)
    box.hint:SetPoint("LEFT", EDIT_INSET, 0)
    box.hint:SetText(ns.L(hint))
    box:SetTextInsets(EDIT_INSET, SEARCH_CLEAR_ROOM, 0, 0)
    local clear = SearchClearButton(box, T)
    box:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        self.hint:SetShown(text == "")
        clear:SetShown(text ~= "")
        if onChange then onChange(text) end
    end)
    box:SetScript("OnEscapePressed", ClearSearch)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    return box
end

local function DialogButton(UI, panel, key, text, w, onClick, x)
    local button = UI.KeepButton(panel, key, text, w, DIALOG_BUTTON_H, onClick)
    button:SetPoint("BOTTOM", panel, "BOTTOM", x, DIALOG_PAD)
    return button
end

function ns.PromptText(title, text, maxLetters, onAccept)
    local UI = ns.UI
    local dimmer, panel = ns.MakeModal(PROMPT_W, PROMPT_H, "promptText")
    local head = UI.KeepFont(panel, "head", DIALOG_HEAD_SIZE, "OUTLINE")
    head:SetPoint("TOP", 0, -DIALOG_PAD)
    head:SetWidth(PROMPT_TEXT_W)
    head:SetText(ns.L(title))
    panel:SetHeight(math.max(PROMPT_H, head:GetStringHeight() + PROMPT_ROOM))
    local box = UI.Keep(panel, "box", ns.NewEditBox)
    box:SetPoint("TOP", head, "BOTTOM", 0, -PROMPT_BOX_GAP)
    box:SetSize(PROMPT_BOX_W, PROMPT_BOX_H)
    box:SetMaxLetters(maxLetters or PROMPT_MAX_LETTERS)
    box:SetText(text or "")
    local function Accept()
        local value = strtrim(box:GetText())
        if value == "" then return end
        dimmer:Hide()
        onAccept(value)
    end
    local function Cancel() dimmer:Hide() end
    DialogButton(UI, panel, "save", "Save", DIALOG_BUTTON_W, Accept, -DIALOG_BUTTON_SHIFT)
    DialogButton(UI, panel, "cancel", "Cancel", DIALOG_BUTTON_W, Cancel, DIALOG_BUTTON_SHIFT)
    box:SetScript("OnEnterPressed", Accept)
    box:SetScript("OnEscapePressed", Cancel)
    dimmer:Show()
    box:SetFocus()
    box:HighlightText()
end

local function NewCopyScroll(p)
    local T = ns.THEME
    local sf = ns.UI.SlimScroll(p)
    ns.Solid(sf, "BACKGROUND", T.bg, 1):SetAllPoints()
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject("GameFontHighlight")
    eb:SetWidth(COPY_TEXT_W)
    eb:SetTextInsets(COPY_BOX_INSET, COPY_BOX_INSET, COPY_BOX_INSET, COPY_BOX_INSET)
    sf:SetScrollChild(eb)
    sf.box = eb
    return sf
end

function ns.ShowCopyBox(title, text, onClose)
    local UI, T = ns.UI, ns.THEME
    local dimmer, panel = ns.MakeModal(COPY_W, COPY_H, "copyBox")
    local head = UI.KeepFont(panel, "head", DIALOG_HEAD_SIZE, "OUTLINE", T.accent)
    head:SetPoint("TOPLEFT", DIALOG_PAD, -COPY_HEAD_Y)
    head:SetText(ns.L(title))
    local hint = UI.KeepFont(panel, "hint", COPY_HINT_SIZE, nil, T.muted)
    hint:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -COPY_HINT_GAP)
    hint:SetText(ns.L(TEXT_COPY_HINT))
    UI.KeepButton(panel, "close", "X", COPY_CLOSE_SIZE, COPY_CLOSE_SIZE, function() dimmer:Hide() end)
        :SetPoint("TOPRIGHT", -COPY_CLOSE_INSET, -COPY_CLOSE_INSET)

    local scroll = UI.Keep(panel, "scroll", NewCopyScroll)
    scroll:SetPoint("TOPLEFT", DIALOG_PAD, -COPY_BODY_TOP)
    scroll:SetPoint("BOTTOMRIGHT", -COPY_SCROLLBAR_ROOM, DIALOG_PAD)
    local box = scroll.box
    box:SetText(text)
    box:SetScript("OnEscapePressed", function() dimmer:Hide() end)
    dimmer.onClose = function()
        box:ClearFocus()
        if onClose then onClose() end
    end
    dimmer:Show()
    box:SetFocus()
    box:HighlightText()
end

local function ConfirmHead(UI, panel, text)
    local head = UI.KeepFont(panel, "head", CONFIRM_TEXT_SIZE, nil)
    head:SetPoint("TOP", 0, -CONFIRM_TEXT_Y)
    head:SetWidth(CONFIRM_TEXT_W)
    head:SetText(ns.L(text))
    return head
end

function ns.ConfirmReload(text)
    ns.MarkReloadRequired(text)
    local UI = ns.UI
    local dimmer, panel = ns.MakeModal(CONFIRM_PANEL_W, CONFIRM_H, "confirmReload")
    ConfirmHead(UI, panel, text)
    ns.MakeReloadButton(DialogButton(UI, panel, "yes", "Reload UI", CONFIRM_W, nil, -DIALOG_BUTTON_SHIFT))
    DialogButton(UI, panel, "no", "Later", CONFIRM_W, function() dimmer:Hide() end, DIALOG_BUTTON_SHIFT)
    dimmer:Show()
end

function ns.Confirm(text, onYes, onNo, yesText, noText)
    local UI = ns.UI
    local dimmer, panel = ns.MakeModal(CONFIRM_PANEL_W, CONFIRM_H, "confirm")
    local head = ConfirmHead(UI, panel, text)
    panel:SetHeight(math.max(CONFIRM_H, head:GetStringHeight() + CONFIRM_ROOM))
    local w = (yesText or noText) and CONFIRM_WIDE or CONFIRM_W
    local shift = w / 2 + CONFIRM_BUTTON_GAP
    local yes = DialogButton(UI, panel, "yes", yesText or "Yes", w, function()
        dimmer.onClose = nil
        dimmer:Hide()
        onYes()
    end, -shift)
    DialogButton(UI, panel, "no", noText or "No", w, function() dimmer:Hide() end, shift)
    dimmer.onClose = onNo
    dimmer:Show()
    return yes, dimmer
end

local activeRoot, provisional

local function CharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

local function NewInstall()
    return { dbVersion = DB_VERSION, profiles = { [DEFAULT_PROFILE] = CopyTable(ns.STARTER.profile) },
        account = CopyTable(ns.STARTER.account) }
end

local function DB()
    local sv = _G.NaowhForeverDB
    if type(sv) ~= "table" then
        sv = NewInstall()
        _G.NaowhForeverDB = sv
    end
    if type(sv.profiles) ~= "table" then sv.profiles = {} end
    if type(sv.charActive) ~= "table" then sv.charActive = {} end
    return sv
end

local function ProvisionalRoot(sv)
    local default = sv.defaultProfile or DEFAULT_PROFILE
    if type(sv.profiles[default]) ~= "table" then sv.profiles[default] = {} end
    provisional = sv.profiles[default]
    return provisional
end

local function AssignedProfile(sv)
    local name = sv.charActive[CharKey()]
    if type(name) == "string" and type(sv.profiles[name]) == "table" then return name end
    if name == nil and next(sv.charActive) ~= nil then
        if type(sv.charAsk) ~= "table" then sv.charAsk = {} end
        sv.charAsk[CharKey()] = true
    end
    name = type(name) == "string" and name or sv.defaultProfile or DEFAULT_PROFILE
    if type(sv.profiles[name]) ~= "table" and type(sv.defaultProfile) == "string" then
        name = sv.defaultProfile
    end
    sv.charActive[CharKey()] = name
    return name
end

function ns.SettingsRoot()
    if activeRoot then return activeRoot end
    local sv = DB()
    if UnitName("player") == UNKNOWNOBJECT then return ProvisionalRoot(sv) end
    local name = AssignedProfile(sv)
    if type(sv.profiles[name]) ~= "table" then sv.profiles[name] = {} end
    activeRoot = sv.profiles[name]
    return activeRoot
end

function ns.DB()
    local root = ns.SettingsRoot()
    if type(root.tankReminder) ~= "table" then root.tankReminder = {} end
    return root.tankReminder
end

function ns.AccountSettings()
    local sv = DB()
    if type(sv.account) ~= "table" then sv.account = {} end
    return sv.account
end

function ns.UIScale()
    local pct = tonumber(ns.AccountSettings().windowScale) or SCALE_DEFAULT
    if pct < SCALE_MIN then pct = SCALE_MIN elseif pct > SCALE_MAX then pct = SCALE_MAX end
    return pct / PERCENT
end

function ns.GamepadOwnsPanels()
    return InputUtil.IsGamepadUIEnabled() or CanAutoSetGamePadCursorControl(true)
        or CanAutoSetGamePadCursorControl(false)
end

local function OnNameKnown(self)
    if UnitName("player") == UNKNOWNOBJECT then return end
    self:UnregisterAllEvents()
    if provisional and ns.SettingsRoot() ~= provisional then ns.QueueReapply() end
    provisional = nil
end

local nameWatch = CreateFrame("Frame")
nameWatch:RegisterEvent("PLAYER_LOGIN")
nameWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
nameWatch:RegisterUnitEvent("UNIT_NAME_UPDATE", "player")
nameWatch:SetScript("OnEvent", OnNameKnown)

function ns.CurrentSpec()
    local index = C_SpecializationInfo.GetSpecialization()
    if not index then return 0, false end
    local id, _, _, _, role = C_SpecializationInfo.GetSpecializationInfo(index)
    return id or 0, role == "TANK"
end

local specWatch = CreateFrame("Frame")
specWatch:RegisterEvent("PLAYER_LOGIN")
specWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
specWatch:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
specWatch:SetScript("OnEvent", function() ns.ApplySpecProfile((ns.CurrentSpec())) end)

local function ApplyNow()
    ns.Shared.Settings.WatchEllesmere()
    ns.Apply()
end

local function OnReapplyEvent(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(LOGIN_APPLY_DELAY, ApplyNow)
    else
        ns.QueueReapply()
    end
end

local reapplyEvents = CreateFrame("Frame")
reapplyEvents:RegisterEvent("PLAYER_LOGIN")
reapplyEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
reapplyEvents:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
reapplyEvents:SetScript("OnEvent", OnReapplyEvent)

do
    local cachedWant, cachedID

    function ns.InvalidateTTSVoice()
        cachedWant, cachedID = nil, nil
    end

    local voiceWatch = CreateFrame("Frame")
    voiceWatch:RegisterEvent("PLAYER_LOGIN")
    voiceWatch:RegisterEvent("VOICE_CHAT_TTS_VOICES_UPDATE")
    voiceWatch:SetScript("OnEvent", function(self, event)
        if event == "VOICE_CHAT_TTS_VOICES_UPDATE" then return ns.InvalidateTTSVoice() end
        self:UnregisterEvent("PLAYER_LOGIN")
        for _, panel in ipairs({ _G.SettingsPanel, _G.TextToSpeechFrame }) do
            panel:HookScript("OnHide", ns.InvalidateTTSVoice)
        end
    end)

    local function Installed(voices, want)
        if not (want and voices) then return nil end
        for i = 1, #voices do
            if voices[i].voiceID == want then return want end
        end
    end

    local function GameVoice()
        if not TextToSpeech_GetSelectedVoice then return nil end
        local ok, voice = pcall(TextToSpeech_GetSelectedVoice, Enum.TtsVoiceType.Standard)
        if ok and voice and voice.voiceID then return voice.voiceID end
    end

    function ns.TTSVoiceID()
        local want = ns.DB().ttsVoiceID
        if cachedID and cachedWant == want then return cachedID end
        if not (C_VoiceChat and C_VoiceChat.GetTtsVoices) then return 0 end
        local voices = C_VoiceChat.GetTtsVoices()
        local resolved = Installed(voices, want) or GameVoice()
            or (voices and voices[1] and voices[1].voiceID) or 0
        if voices and #voices > 0 then cachedWant, cachedID = want, resolved end
        return resolved
    end
end

function ns.TTSVoiceChoices()
    local values, order = { [""] = TEXT_GAME_DEFAULT }, { "" }
    if C_VoiceChat and C_VoiceChat.GetTtsVoices then
        local voices = C_VoiceChat.GetTtsVoices()
        for i = 1, #(voices or {}) do
            local v = voices[i]
            if v and v.voiceID and v.name then
                values[v.voiceID] = v.name
                order[#order + 1] = v.voiceID
            end
        end
    end
    return values, order
end

function ns.ActiveProfileName()
    if ns.SettingsRoot() == provisional then return DB().defaultProfile or DEFAULT_PROFILE end
    return DB().charActive[CharKey()]
end

local function ByCharacter(a, b) return a.char:lower() < b.char:lower() end
local function ByName(a, b) return a:lower() < b:lower() end

function ns.KnownCharacters()
    local sv = DB()
    local out = {}
    for char, profile in pairs(sv.charActive) do
        out[#out + 1] = { char = char, profile = profile }
    end
    table.sort(out, ByCharacter)
    return out
end

function ns.MarkSeen()
    if UnitName("player") == UNKNOWNOBJECT then return end
    local sv = DB()
    if type(sv.charSeen) ~= "table" then sv.charSeen = {} end
    sv.charSeen[CharKey()] = time()
    local guid = UnitGUID("player")
    if type(guid) ~= "string" then return end
    if type(sv.charGuid) ~= "table" then sv.charGuid = {} end
    sv.charGuid[CharKey()] = guid
end

function ns.MarkAsked()
    if UnitName("player") == UNKNOWNOBJECT then return end
    local sv = DB()
    if type(sv.charAsk) ~= "table" then return end
    sv.charAsk[CharKey()] = nil
    if next(sv.charAsk) == nil then sv.charAsk = nil end
end

local function ProfileUses(sv, me)
    local uses = {}
    for char, profile in pairs(sv.charActive) do
        if char ~= me then uses[profile] = (uses[profile] or 0) + 1 end
    end
    return uses
end

local function Better(char, when, count, best, bestSeen, bestUses)
    if not best or when > bestSeen then return true end
    if when ~= bestSeen then return false end
    return count > bestUses or (count == bestUses and char < best)
end

local function GuidOrder(guid)
    if type(guid) ~= "string" then return nil end
    local server, counter = guid:match(GUID_PATTERN)
    counter = counter and tonumber(counter, HEX)
    if not counter then return nil end
    return server, counter
end

local function Offerable(sv, char, me, profile)
    return char ~= me and char:sub(1, #UNKNOWNOBJECT + 1) ~= UNKNOWNOBJECT .. "-"
        and type(sv.profiles[profile]) == "table"
end

local function FirstMade(sv, me)
    local server = GuidOrder(UnitGUID("player"))
    if not server or type(sv.charGuid) ~= "table" then return nil end
    local best, bestProfile, bestCounter
    for char, profile in pairs(sv.charActive) do
        local theirs, counter = GuidOrder(sv.charGuid[char])
        if theirs == server and Offerable(sv, char, me, profile)
            and (not best or counter < bestCounter or (counter == bestCounter and char < best)) then
            best, bestProfile, bestCounter = char, profile, counter
        end
    end
    return best, bestProfile
end

function ns.ImportCandidate()
    local sv = DB()
    local me = CharKey()
    if type(sv.charAsk) ~= "table" or not sv.charAsk[me] then return nil end
    local first, firstProfile = FirstMade(sv, me)
    if first then return first, firstProfile end
    local seen = type(sv.charSeen) == "table" and sv.charSeen or {}
    local uses = ProfileUses(sv, me)
    local best, bestProfile, bestSeen, bestUses
    for char, profile in pairs(sv.charActive) do
        if Offerable(sv, char, me, profile) then
            local when, count = seen[char] or 0, uses[profile]
            if Better(char, when, count, best, bestSeen, bestUses) then
                best, bestProfile, bestSeen, bestUses = char, profile, when, count
            end
        end
    end
    return best, bestProfile
end

function ns.ListProfiles()
    local out = {}
    for name in pairs(DB().profiles) do out[#out + 1] = name end
    table.sort(out, ByName)
    return out
end

function ns.SpecProfileMap()
    local sv = DB()
    if type(sv.specProfile) ~= "table" then sv.specProfile = {} end
    return sv.specProfile
end

function ns.SetSpecProfile(specID, name)
    if not specID or specID == 0 then return end
    ns.SpecProfileMap()[tostring(specID)] = name
end

function ns.AutoSpecProfile(set)
    local sv = DB()
    if set ~= nil then sv.autoSpecProfile = set and true or nil end
    return sv.autoSpecProfile == true
end

function ns.ApplySpecProfile(specID)
    if not ns.AutoSpecProfile() then return false end
    if not specID or specID == 0 then return false end
    local sv = DB()
    local want = ns.SpecProfileMap()[tostring(specID)]
    if not want or type(sv.profiles[want]) ~= "table" then return false end
    if sv.charActive[CharKey()] == want then return false end
    return (ns.SwitchProfile(want)) and true or false
end

function ns.EnsureProfile(name)
    local sv = DB()
    if type(sv.profiles[name]) ~= "table" then sv.profiles[name] = {} end
    if type(sv.profiles[name].tankReminder) ~= "table" then
        sv.profiles[name].tankReminder = {}
    end
    return sv.profiles[name].tankReminder
end

function ns.ProfileTable(name)
    local p = DB().profiles[name]
    return type(p) == "table" and p or nil
end

function ns.ProfileRoot(name)
    ns.EnsureProfile(name)
    return DB().profiles[name]
end

function ns.SwitchProfile(name)
    local sv = DB()
    if type(sv.profiles[name]) ~= "table" then return false, ns.L(ERR_NO_PROFILE) end
    sv.charActive[CharKey()] = name
    activeRoot = nil
    local spec = ns.CurrentSpec and ns.CurrentSpec()
    if spec and spec > 0 then ns.SetSpecProfile(spec, name) end
    ns.QueueReapply()
    if ns.ReconcileModules then ns.ReconcileModules() end
    return true
end

local function Trimmed(name)
    return type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
end

local function ValidName(name, allowExisting)
    name = Trimmed(name)
    if name == "" then return nil, ns.L("the name is empty") end
    if not allowExisting and DB().profiles[name] then return nil, ns.L("that name is taken") end
    return name
end

function ns.ProfileExists(name)
    name = Trimmed(name)
    return name ~= "" and type(DB().profiles[name]) == "table"
end

function ns.SetAccountProfile(name)
    local sv = DB()
    if type(sv.profiles[name]) ~= "table" then return false, ns.L(ERR_NO_PROFILE) end
    sv.defaultProfile = name
    for char in pairs(sv.charActive) do sv.charActive[char] = name end
    sv.charActive[CharKey()] = name
    local turnedOff = sv.autoSpecProfile == true
    sv.autoSpecProfile = nil
    activeRoot = nil
    ns.QueueReapply()
    if ns.ReconcileModules then ns.ReconcileModules() end
    return true, turnedOff
end

function ns.CreateProfile(name, overwrite)
    local err
    name, err = ValidName(name, overwrite)
    if not name then return false, err end
    local sv = DB()
    sv.profiles[name] = {}
    sv.defaultProfile = name
    for char in pairs(sv.charActive) do sv.charActive[char] = name end
    activeRoot = nil
    ns.QueueReapply()
    return true
end

local function DeepCopy(t)
    local out = {}
    for k, v in pairs(t) do
        out[k] = type(v) == "table" and DeepCopy(v) or v
    end
    return out
end

function ns.CopyProfile(src, name, overwrite)
    local sv = DB()
    if type(sv.profiles[src]) ~= "table" then return false, ns.L(ERR_NO_PROFILE) end
    local err
    name, err = ValidName(name, overwrite)
    if not name then return false, err end
    sv.profiles[name] = DeepCopy(sv.profiles[src])
    if name == sv.charActive[CharKey()] then
        activeRoot = nil
        ns.QueueReapply()
    end
    return true
end

function ns.ResetProfileNamed(name)
    local sv = DB()
    if type(sv.profiles[name]) ~= "table" then return false, ns.L(ERR_NO_PROFILE) end
    if name == sv.charActive[CharKey()] then
        ns.SettingsRoot().tankReminder = nil
        return true
    end
    sv.profiles[name].tankReminder = nil
    return true
end

local function CountProfiles(sv)
    local count = 0
    for _ in pairs(sv.profiles) do count = count + 1 end
    return count
end

local function FallbackProfile(sv)
    local fallback = sv.defaultProfile or DEFAULT_PROFILE
    if type(sv.profiles[fallback]) ~= "table" then
        fallback = next(sv.profiles)
        sv.defaultProfile = fallback
    end
    return fallback
end

function ns.DeleteProfile(name)
    local sv = DB()
    if type(sv.profiles[name]) ~= "table" then return false, ns.L(ERR_NO_PROFILE) end
    if CountProfiles(sv) <= 1 then return false, ns.L("the last profile cannot be deleted") end
    local wasMine = sv.charActive[CharKey()] == name
    sv.profiles[name] = nil
    local fallback = FallbackProfile(sv)
    for char, active in pairs(sv.charActive) do
        if active == name then sv.charActive[char] = fallback end
    end
    if wasMine then
        activeRoot = nil
        ns.QueueReapply()
    end
    return true
end

local reapplyPending

function ns.Apply() end

local function RunReapply()
    reapplyPending = false
    ns.Apply()
end

function ns.QueueReapply()
    if reapplyPending then return end
    reapplyPending = true
    C_Timer.After(0, RunReapply)
end

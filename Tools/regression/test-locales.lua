-- Offline checks for the language Naowh Forever runs in: the client's or the one picked in Settings
-- (NaowhForeverDB.account.language, loaded before the first file), the translation addon Core.lua loads, and the fonts for
-- CJK and Cyrillic text. Run from the repo root: lua Tools/regression/test-locales.lua

local FONT_CLASSIC = "Friz Quadrata TT"

local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

local function Exists(path)
    local f = io.open(path, "rb")
    if f then f:close() end
    return f ~= nil
end

-- The translations are one load-on-demand addon, NaowhForever_Locales, whose TOC lists every
-- <code>.lua. Loading it runs every file; each one returns at once unless it is the active language.
local function Load(client, picked)
    local loaded, filesRead = {}, {}
    local env = setmetatable({
        GetLocale = function() return client end,
        NaowhForeverDB = picked and { account = { language = picked } } or nil,
        STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF",
        CreateFrame = function()
            return setmetatable({}, { __index = function() return function() end end })
        end,
    }, { __index = _G })
    env._G = env
    env.C_AddOns = { LoadAddOn = function(name)
        loaded[#loaded + 1] = name
        for path in Read(name .. "/" .. name .. ".toc"):gmatch("([%w]+%.lua)") do
            local full = name .. "/" .. path
            filesRead[#filesRead + 1] = full
            local chunk = assert(loadstring(Read(full), full))
            setfenv(chunk, env)
            chunk()
        end
    end }
    for _, path in ipairs({ "Core/Locales/enUS.lua", "Core/Core.lua" }) do
        local chunk = assert(loadstring(Read(path), path))
        setfenv(chunk, env)
        chunk("NaowhForever", {})
    end
    return env.NaowhForever, loaded, filesRead
end

local ns, loaded, read = Load("enUS")
check("an English client loads no translation addon", ns.LOCALE == "enUS" and #loaded == 0 and #read == 0)
check("and shows the English text", ns.L("Language") == "Language" and ns.L("Back (slot)") == "Back")
check("its fonts are its own", ns.LocaleFont("Naowh", "Interface\\naowh.ttf") == "Interface\\naowh.ttf")

ns, loaded = Load("enGB")
check("a British client is English", ns.LOCALE == "enUS" and #loaded == 0)

ns, loaded, read = Load("deDE")
check("a German client loads exactly one addon, once", ns.LOCALE == "deDE" and #loaded == 1
    and loaded[1] == "NaowhForever_Locales")
check("the addon lists all ten language files", #read == 10)
check("and shows German", ns.L("Language") == "Sprache")
check("a key with context shows its translation", ns.L("Back (slot)") ~= "Back (slot)")
check("an untranslated key falls back to English", ns.L("No such string %d", 3) == "No such string 3")

ns = Load("enUS", "deDE")
check("a language picked in Settings wins over the client's", ns.LOCALE == "deDE" and ns.L("Language") == "Sprache")
ns = Load("deDE", "enUS")
check("English can be picked on a German client", ns.LOCALE == "enUS" and ns.L("Language") == "Language")
ns = Load("deDE", "auto")
check("Game Language follows the client", ns.LOCALE == "deDE")
ns = Load("frFR", "xxXX")
check("an unknown pick follows the client", ns.LOCALE == "frFR")

check("only the picked language's strings are active", Load("enUS", "frFR").L("Language") ~= Load("enUS", "deDE").L("Language"))

ns = Load("enUS", "koKR")
check("Korean uses the game's Korean font everywhere", ns.LocaleFont("Naowh", "Interface\\naowh.ttf") == "Fonts\\2002.TTF")
ns = Load("enUS", "zhTW")
check("Traditional Chinese has its own font", ns.LocaleFont("Naowh", "x") == "Fonts\\bLEI00D.ttf")
ns = Load("enUS", "ruRU")
check("Russian swaps Friz Quadrata for its Cyrillic cut, by name, not by the resolved path",
    ns.LocaleFont(FONT_CLASSIC, "Fonts\\FRIZQT__.TTF") == "Fonts\\FRIZQT___CYR.TTF"
    and ns.LocaleFont(FONT_CLASSIC, "Interface\\SomeOtherRegisteredPath.ttf") == "Fonts\\FRIZQT___CYR.TTF")
check("a different font name does not swap, even at the same path",
    ns.LocaleFont("Naowh", "Fonts\\FRIZQT__.TTF") == "Fonts\\FRIZQT__.TTF")

for _, code in ipairs(ns.LANGUAGES) do
    check(code .. " has a name in the picker", type(ns.LANGUAGE_NAMES[code]) == "string")
    if code ~= "enUS" then
        check(code .. " has its file, listed in the TOC", Exists("NaowhForever_Locales/" .. code .. ".lua")
            and Read("NaowhForever_Locales/NaowhForever_Locales.toc"):find(code .. ".lua", 1, true) ~= nil)
        check(code .. " can be picked", Load("enUS", code).LOCALE == code)
    end
end

-- Settings' Language dropdown: UI.KeepMissing keeps a stale saved pick visible and selectable,
-- the same way the other LSM-backed dropdowns in that file do (UI.FontChoices, UI.TextureChoices).
local function LoadWidgets()
    local env = setmetatable({
        GetLocale = function() return "enUS" end,
        CreateFrame = function() return setmetatable({}, { __index = function() return function() end end }) end,
    }, { __index = _G })
    env._G = env
    env.C_AddOns = { LoadAddOn = function() end }
    for _, path in ipairs({ "Core/Locales/enUS.lua", "Core/Core.lua", "Core/Options/Widgets.lua" }) do
        local chunk = assert(loadstring(Read(path), path))
        setfenv(chunk, env)
        chunk("NaowhForever", {})
    end
    return env.NaowhForever
end
local wui = LoadWidgets().UI
local values, order = wui.KeepMissing({ en = "English" }, { "en" }, "ghostCode")
check("KeepMissing adds a stale saved value back in", values.ghostCode ~= nil and order[#order] == "ghostCode")
local _, order2 = wui.KeepMissing({ en = "English" }, { "en" }, "en")
check("and leaves a known value alone", order2[#order2] == "en" and #order2 == 1)

-- An old NaowhForever_Language folder left behind loads after Naowh Forever; at login its pick is
-- copied into the account once, when none is saved there yet.
local login = assert((Read("Core/Core.lua"):gsub("\r\n", "\n")):match("\n    (local oldLanguage, account = .-\n    if .- end)\n"),
    "the old pick's copy at login")
local function Migrate(old, saved)
    local account = { language = saved }
    local chunk = assert(loadstring("local _G, ns = ...\n" .. login))
    chunk({ NaowhForeverLanguageDB = old }, { AccountSettings = function() return account end })
    return account.language
end
check("an old Language folder's pick moves into the account", Migrate({ locale = "deDE" }, nil) == "deDE")
check("a pick already saved in the account stays", Migrate({ locale = "deDE" }, "frFR") == "frFR")
check("no old folder: nothing changes", Migrate(nil, nil) == nil and Migrate(nil, "itIT") == "itIT")

-- Every translation keeps its English text's placeholders: string.format raises on a missing or
-- swapped %d. The game's format takes numbered placeholders (%2$s), so those may change places.
local function Catalog(path, code)
    local env = { NaowhForever = { LOCALE = code } }
    env._G = env
    local chunk = assert(loadstring(Read(path), path))
    setfenv(chunk, env)
    chunk()
    return env.NaowhForeverTranslation or env.NaowhForeverLocale
end

local function Placeholders(text)
    local list, n = {}, 0
    for slot, kind in (text:gsub("%%%%", "")):gmatch("%%(%d*%$?)[-+#0]*%d*%.?%d*([cdeEfgGioqsuxX])") do
        if slot:sub(-1) == "$" then
            slot = tonumber(slot:sub(1, -2))
        else
            n = n + 1
            slot = n
        end
        list[slot] = kind == "i" and "d" or kind
    end
    return list
end

local function SamePlaceholders(a, b)
    a, b = Placeholders(a), Placeholders(b)
    for slot, kind in pairs(a) do
        if b[slot] ~= kind then return false end
    end
    for slot in pairs(b) do
        if a[slot] == nil then return false end
    end
    return true
end

check("numbered placeholders may change places", SamePlaceholders("Sold %d for %s.", "%2$s: %1$d"))
check("plain ones may not", not SamePlaceholders("Sold %d for %s.", "%s: %d"))
check("none may go missing", not SamePlaceholders("%d of %d", "%d"))
check("a percent sign in text is not a placeholder", SamePlaceholders("40% off, 5%% cut", "-40 % de 5%%"))

local english = Catalog("Core/Locales/enUS.lua", "enUS")
for _, code in ipairs(ns.LANGUAGES) do
    if code ~= "enUS" then
        local wrong = {}
        for key, text in pairs(Catalog("NaowhForever_Locales/" .. code .. ".lua", code)) do
            local source = english[key]
            if type(text) == "string" and source ~= nil
                and not SamePlaceholders(source == true and key or source, text) then
                wrong[#wrong + 1] = key
            end
        end
        table.sort(wrong)
        check(code .. " keeps every placeholder: " .. table.concat(wrong, " | "), #wrong == 0)
    end
end

print(checks .. " locale checks passed")

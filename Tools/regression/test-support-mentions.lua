-- Run with Lua 5.1 from the repository root: while ns.FEATURE_BADGES is 0, no text a player can
-- see names Patreon, supporters, patrons or the Legendary or Epic Supporters; the team's badges may show.
-- Every string in the files the TOC loads is scanned; the few that carry those words must sit in
-- a file whose gate is checked here, by loading it with the flag at 0 (none shown) and at 1.
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Load = dofile("Tools/regression/load_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local WORDS = { "patreon", "supporter", "legendary supporters", "epic supporters", "patron" }

local function Mentions(text)
    local lower = tostring(text):lower()
    for _, word in ipairs(WORDS) do
        if lower:find(word, 1, true) then return word end
    end
end

-- Files with those words in their strings, each loaded below with the flag both ways.
local GATED = {
    ["Core/Badges/Badges.lua"] = true,
    ["CharacterPanel/UI/SettingsPage.lua"] = true,
    ["InspectPanel/UI/SettingsPage.lua"] = true,
    ["Core/Pages/Credits.lua"] = true,
    ["Core/Pages/PatchNotes.lua"] = true,
}
-- The same words meaning something else: the patrons of a dungeon's bar.
local UNRELATED = {
    ["DungeonJournal/Data/Tips.lua"] = "killing patrons turns the bar hostile",
}

-------------------------------------------------------------------------------
--  Every string literal in a Lua file, comments skipped.
-------------------------------------------------------------------------------
local function Literals(src)
    local out, i, n = {}, 1, #src
    while true do
        local at = src:find("[%-\"'%[]", i)
        if not at then break end
        local c = src:sub(at, at)
        if c == "-" then
            if src:sub(at, at + 1) == "--" then
                local eq = src:match("^%[(=*)%[", at + 2)
                local close = eq and ("]" .. eq .. "]")
                local stop = close and src:find(close, at + 4 + #eq, true) or src:find("\n", at, true)
                i = (stop or n) + (close and #close or 1)
            else
                i = at + 1
            end
        elseif c == "[" then
            local eq = src:match("^%[(=*)%[", at)
            if eq then
                local close = "]" .. eq .. "]"
                local first = at + 2 + #eq
                local stop = src:find(close, first, true) or (n + 1)
                out[#out + 1] = src:sub(first, stop - 1)
                i = stop + #close
            else
                i = at + 1
            end
        else
            local j, buf = at + 1, {}
            while j <= n do
                local d = src:sub(j, j)
                if d == "\\" then
                    buf[#buf + 1] = src:sub(j, j + 1)
                    j = j + 2
                elseif d == c then
                    break
                else
                    buf[#buf + 1] = d
                    j = j + 1
                end
            end
            out[#out + 1] = table.concat(buf)
            i = j + 1
        end
    end
    return out
end

check("the scanner skips comments and finds strings", #Literals("-- 'no'\n--[[ \"no\" ]]\nx = 'a' .. \"b\" .. [[c]]") == 3)

-- A module may sit in its own addon folder: NaowhForever_BiS/CharacterPanel/... for CharacterPanel/...,
-- NaowhForever_DungeonJournal/... for DungeonJournal/...
local TOC_LUA = TocFiles("%.lua$")
local function EndsWith(path, suffix)
    return path == suffix or path == "NaowhForever_" .. suffix or path:match("^NaowhForever_%w+/(.+)$") == suffix
end
local function Gated(path)
    for suffix in pairs(GATED) do
        if EndsWith(path, suffix) then return suffix end
    end
end
local function Unrelated(path, literal)
    for suffix, text in pairs(UNRELATED) do
        if EndsWith(path, suffix) and literal:find(text, 1, true) then return true end
    end
    return false
end
local function Located(suffix)
    for _, path in ipairs(TOC_LUA) do
        if Gated(path) == suffix then return path end
    end
    return suffix
end

local scanned, hitFiles = 0, {}
for _, path in ipairs(TOC_LUA) do
    local f = not path:find("^Libs/") and not path:find("^Core/Locales/") and io.open(path, "rb")
    if f then
        local src = f:read("*a")
        f:close()
        scanned = scanned + 1
        for _, literal in ipairs(Literals(src)) do
            local word = Mentions(literal)
            if word then
                local ok = Gated(path) or Unrelated(path, literal)
                check(("%s: %q in %q is not behind ns.FEATURE_BADGES"):format(path, word, literal), ok)
                hitFiles[Gated(path) or path] = true
            end
        end
    end
end
check("the TOC's files were scanned", scanned > 100)
for path in pairs(GATED) do
    check(path .. " still has words to gate (else drop it from GATED)", hitFiles[path])
end

-------------------------------------------------------------------------------
--  The gated files, loaded with the flag at 0 and at 1: what each puts on screen.
-------------------------------------------------------------------------------
local NOTHING = function() end
local texts

local Stub
local STUB = { __index = function(_, key)
    if key == "SetText" then return function(_, text) texts[#texts + 1] = tostring(text) end end
    if key == "GetStringWidth" or key == "GetStringHeight" or key == "GetWidth" or key == "GetHeight" then
        return function() return 100 end
    end
    if key:find("^Create") then return function() return Stub() end end
    return NOTHING
end }
function Stub() return setmetatable({}, STUB) end

local COLOR = { r = 1, g = 1, b = 1 }
local TEAM_GUID = "Player-1-TEAM"

-- What a player can read with the flag at a value: the settings, patch notes and credits pages,
-- then everything the badges show (every tier's lines, a hover card for each, the test toast)
-- and what /nf badges prints, for a team member trying them.
local function Shown(flag)
    texts = {}
    local cards, infos, registered = {}, {}, {}
    local store = { Get = function() return true end, Default = function() return true end, OnChange = NOTHING }
    local ns
    ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        FEATURE_BADGES = flag, BADGES_LIVE = 1, LINKS = {}, MEDIA = dofile("Tools/regression/core_media.lua"), CODE_BUILD = "test", THEME = setmetatable({}, { __index = function() return COLOR end }),
        QoLSettings = store, Apply = NOTHING,
        BADGE_STAFF = { [1] = { [TEAM_GUID] = "developer" } },
        BADGE_PATRONS = { [1] = { ["Player-1-PATRON"] = { since = "2026-03" } } },
        CharacterPanel = { EllesmereSheet = function() return false end },
        InspectPanel = { EllesmereSheet = function() return false end },
        Solid = function() return Stub() end, Border = function() return Stub() end,
        Font = function() return Stub() end, Color = function(_, text) return text end,
        FontInset = function() return 0 end,
        Print = function(text) texts[#texts + 1] = text end,
        AccountSettings = function() return {} end,
        MakeModal = function() return Stub(), Stub() end,
        UI = { CONTENT_PAD = 10, KeepFont = function() return Stub() end, Keep = function() return Stub() end,
            KeepButton = function() return Stub() end },
        Shared = {
            Style = { WINDOW_CARD_FILL = 0.05, BORDER_RGB = COLOR, LOGO = "logo" },
            Settings = { Page = function()
                return {
                    Card = function(_, def) cards[#cards + 1] = def end,
                    Info = function(_, def) infos[#infos + 1] = def end,
                }
            end },
            View = {
                NewKinds = function() return {} end,
                New = function(_, kinds, draw)
                    local view = { kinds = kinds }
                    for key, fn in pairs(draw) do view[key] = fn end
                    function view.Add(self, kind, data) kinds[kind].Set(kinds[kind].New(self), data) end
                    function view.Section(_, title) texts[#texts + 1] = title end
                    function view.Gather(self, person) self:DrawCard(person, nil, nil, nil, 0, 400) end
                    function view.Acquire(self, kind) return kinds[kind].New(self) end
                    function view.GetWidth() return 800 end
                    function view.GetHeight() return 500 end
                    return setmetatable(view, { __index = function() return NOTHING end })
                end,
            },
        },
    }
    local uiParent = Stub()
    uiParent.GetEffectiveScale = function() return 1 end
    local env = setmetatable({
        _G = { NaowhForever = ns },
        UIParent = uiParent,
        CreateFrame = function() return Stub() end,
        CreateColor = function() return COLOR end,
        GetCursorPosition = function() return 0, 0 end,
        GetCurrentRegion = function() return 1 end,
        UnitGUID = function() return TEAM_GUID end,
        UnitFullName = function() return "Team", "Member" end,
        IsInRaid = function() return false end,
        hooksecurefunc = function(_, key) registered[#registered + 1] = key end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
        date = os.date,
    }, { __index = _G })
    Load({ Located("Core/Badges/Badges.lua"), Located("CharacterPanel/UI/SettingsPage.lua"),
        Located("InspectPanel/UI/SettingsPage.lua"),
        Located("Core/Pages/Credits.lua"), Located("Core/Pages/PatchNotes.lua") }, env)
    ns.BuildCreditsPage({ GetWidth = function() return 800 end }, 0)
    for _, link in ipairs(ns.LINKS) do
        texts[#texts + 1] = link[1]
        texts[#texts + 1] = link[3]()
    end

    for _, def in ipairs(cards) do
        texts[#texts + 1] = def.name
        texts[#texts + 1] = def.help
        if def.summary then texts[#texts + 1] = def.summary(store) end
        for _, row in ipairs(def.rows or {}) do
            texts[#texts + 1] = row.label
            texts[#texts + 1] = row.help
        end
    end
    for _, def in ipairs(infos) do
        texts[#texts + 1] = def.name
        texts[#texts + 1] = def.summary
        for _, line in ipairs(def.lines) do
            texts[#texts + 1] = line.title
            texts[#texts + 1] = line.where
            texts[#texts + 1] = line.text
        end
    end
    local pages = #texts

    for key, tier in pairs(ns.BADGE_TIERS) do
        for _, field in ipairs({ "title", "about", "label", "tooltipLine" }) do
            if tier[field] then texts[#texts + 1] = tier[field] end
        end
        ns.ShowBadgeCard(key, "Someone")
    end
    texts[#texts + 1] = ns.BadgeSince({ tier = "legendary", since = "2026-03" })
    for _, command in ipairs({ "", "preview", "toast", "preview none", "preview off", "id" }) do
        ns.BadgesCommand(command)
    end
    return texts, ns, registered, pages
end

local off, offNs, offHooks, offPages = Shown(0)
check("flag 0: the pages have words", offPages > 100 and #off > offPages + 10)
for _, text in ipairs(off) do
    local word = Mentions(text)
    check(("flag 0: %q shows %q"):format(text, tostring(word)), word == nil)
    check(("flag 0: %q mentions support"):format(text), not text:lower():find("support", 1, true))
end
check("flag 0: no badge mention left on the pages",
    not table.concat(off, " ", 1, offPages):lower():find("badge", 1, true))
check("flag 0: no settings card for the badges", not table.concat(off, " ", 1, offPages):find("Badges", 1, true))
check("flag 0: the team's badges are there, the patron tier is not", #offHooks > 0
    and offNs.BADGE_TIERS.developer ~= nil and offNs.BADGE_TIERS.legendary == nil
    and offNs.BadgeOf(TEAM_GUID) ~= nil and offNs.BadgeOf("Player-1-PATRON") == nil)

local on, onNs = Shown(1)
local joined = table.concat(on, "\n"):lower()
for _, word in ipairs(WORDS) do
    check("flag 1: the words are back (" .. word .. ")", joined:find(word, 1, true) ~= nil)
end
check("flag 1: the patron tiers are back", onNs.BadgeOf("Player-1-PATRON") == onNs.BADGE_TIERS.legendary
    and onNs.BADGE_TIERS.epic ~= nil)
check("flag 1: one more patch note line, and the Supporter Badges card", #on > #off)

print(("test-support-mentions: %d checks passed"):format(checks))

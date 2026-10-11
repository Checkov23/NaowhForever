-- A card's or setting's search words (search = "...") are found by the sidebar search (real
-- Search.lua over Shared/Settings/Settings.lua) but never shown: help stays as it was written.
-- Run with Lua 5.1 from the repository root.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local cases = 0
local function Check(ok, label) assert(ok, label); cases = cases + 1 end

local ns = { THEME = { bg = {}, panel = {}, line = {}, fg = {}, muted = {}, accent = {}, grey = {} },
    L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Color = function(_, text) return text end,
    Shared = { Style = dofile("Tools/regression/shared_style.lua") }, UI = { PROFILES_PAGE = "Profiles" } }
ns.Options = { DisplayName = function(mod) return ns.L(mod.display or mod.name) end }
local env = { _G = { NaowhForever = ns }, CreateFrame = function() return {} end }
setmetatable(env, { __index = _G })
local function Load(path)
    local chunk = assert(loadstring(Read(path), path))
    setfenv(chunk, env)
    chunk()
end
Load("Shared/Settings/Settings.lua")
Load("Shared/Settings/Style.lua")
Load("Core/Options/Search.lua")
local UI, Settings = ns.UI, ns.Shared.Settings

local store = { Get = function() end, Set = function() end, Default = function() end, OnChange = function() end }
local card = Settings.Page("Planner/Settings", store):Card({ id = "window", name = "Window",
    help = "The planner's own window.", search = "/nf trainer nf trainer waypoint",
    rows = {
        { key = "skip", label = "Mini Bar", toggle = true, help = "A small bar.", search = "right-click skip spell" },
        { key = "plain", label = "Opacity", toggle = true },
        { key = "quiet", label = "Quiet", toggle = true, search = "hush" },
    } })

local planner = { name = "Planner" }
local pages = { { key = "Planner/Settings", name = "Settings", module = planner } }
planner.tabs = pages
---@diagnostic disable-next-line: duplicate-set-field
function UI.SearchPages() return pages end

local list = UI.Search.Collect()
local function Names(query)
    local out = {}
    for i, t in ipairs(UI.Search.Find(list, query)) do out[i] = t.label or "[page]" end
    return table.concat(out, "|")
end

Check(Names("waypoint") == "Window", "a word only in a card's search finds the card")
Check(Names("/nf trainer") == "Window" and Names("nf trainer") == "Window", "with or without the slash")
Check(Names("skip") == "Mini Bar" and Names("right click") == "Mini Bar", "a word only in a setting's search finds it")
Check(Names("hush") == "Quiet", "a setting with search and no help is found")
Check(Names("small bar") == "Mini Bar" and Names("own window") == "Window", "help still counts")
Check(Names("opacity") == "Opacity", "a setting without search is found as before")

Check(card.help == "The planner's own window." and card.rows[1].help == "A small bar."
    and card.rows[3].help == nil, "help is left as written")
Check(not card.help:find("waypoint", 1, true) and not card.rows[1].help:find("skip", 1, true),
    "search words never reach help")

for _, path in ipairs({ "Shared/Settings/Rows.lua", "Shared/Settings/Controls.lua", "Shared/Settings/Page.lua",
        "Shared/UI/SettingsCard.lua", "Core/Options/Widgets.lua" }) do
    Check(not Read(path):find("%.search[^%w_]"), path .. " never shows search")
end

print(("test-settings-search-field: %d checks passed"):format(cases))

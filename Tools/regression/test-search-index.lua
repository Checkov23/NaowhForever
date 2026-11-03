-- The sidebar search's list, matching, filter and lit words (real Search.lua over the real
-- settings declarations in Shared/Settings/Settings.lua), and that the old builder scan is gone.
-- Run with Lua 5.1 from the repository root.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

local cases = 0
local function Check(ok, label) assert(ok, label); cases = cases + 1 end

local frames = 0
local ns
ns = { THEME = { bg = {}, panel = {}, line = {}, fg = {}, muted = {}, accent = {}, grey = {} },
    L = function(text) return ns.translations and ns.translations[text] or text end,
    Upper = string.upper, Lower = string.lower,
    Color = function(token, text) return "<" .. token .. ":" .. (text or "") .. ">" end, Shared = { Style = dofile("Tools/regression/shared_style.lua") }, UI = { PROFILES_PAGE = "Profiles" } }
ns.Options = { DisplayName = function(mod) return ns.L(mod.display or mod.name) end }
local env = { _G = { NaowhForever = ns }, CreateFrame = function() frames = frames + 1; return {} end }
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
local bars = Settings.Page("Meter/Bars", store)
bars:Card({ id = "timer", name = "Swing Timer", help = "A bar for your next swing.", rows = {
    Settings.Group("Look"),
    { key = "size", label = "Bar Size", slider = { 1, 10, 1 }, help = "How tall the bar is." },
    { key = "sound", label = "Timer Sound", toggle = true, help = "Plays a ping on a parry." },
} })
bars:Card({ id = "alert", name = "Parry Alert", help = "Flashes when you parry.", rows = {
    { key = "alertSound", label = "Alert Sound", toggle = true },
    { key = "colour", label = "Alert Color", colour = true },
} })
Settings.Page("Meter/Other", store):Card({ id = "misc", name = "Odds and Ends", rows = {
    { key = "naowh", label = "Naowh's Tips", toggle = true },
} })
Settings.Page("Meter/Other", store):Window({ text = "Open Swing Log", open = function() end, headline = "Swing History",
    detail = function() return "Changes as you play" end })
Settings.Page("Solo/Settings", store):Window({ headline = "No button", detail = "Just a preview" })
Settings.Page("Meter/Other", store):Info({ id = "notes", name = "Release Notes", lines = { { text = "Fixed a bug" } } })
Settings.Page("QoL/Bags", store):Card({ id = "bags", name = "Bag Space", rows = {
    { key = "free", label = "Free Slots", toggle = true },
} })

Settings.Page("Solo/Settings", store):Card({ id = "solo", name = "Solo Card", rows = {
    { key = "solo", label = "Solo Toggle", toggle = true },
} })

local meter, solo, qol = { name = "Meter" }, { name = "Solo" }, { name = "QoL", display = "Quality of Life" }
local pages = {
    { key = "Settings", name = "Settings", title = "Settings" },
    { key = "Meter/Bars", name = "Bars", module = meter },
    { key = "Meter/Other", name = "Other", module = meter },
    { key = "Solo/Settings", name = "Settings", module = solo },
    { key = "QoL/Bags", name = "Bags", module = qol },
}
meter.tabs = { pages[2], pages[3] }
solo.tabs = { pages[4] }
qol.tabs = { pages[5] }
---@diagnostic disable-next-line: duplicate-set-field
function UI.SearchPages() return pages end
---@diagnostic disable-next-line: duplicate-set-field
function UI.SearchOffPages() return {} end

local list = UI.Search.Collect()
Check(frames == 0, "collecting builds no frames")
local function Names(query)
    local out = {}
    for i, t in ipairs(UI.Search.Find(list, query)) do out[i] = t.label or ("[" .. t.trail .. "]") end
    return table.concat(out, "|")
end

-- What each target says about itself.
local first, size
for _, t in ipairs(list) do
    if t.label == "Swing Timer" then first = t end
    if t.label == "Bar Size" then size = t end
end
Check(first.card == "Meter/Bars:timer" and first.page == "Meter/Bars" and first.isCard, "a card is a target, with its page")
Check(not size.isCard, "a setting is not a card")
Check(size.card == "Meter/Bars:timer" and size.tag == "Meter" and size.trail == "Bars / Swing Timer",
    "a setting knows its module, tab and card")
Check(list[1].page == "Settings" and list[1].tag == "Settings" and list[1].trail == "" and not list[1].label,
    "a window page is a target, named by itself")
local trails = table.concat({ list[1].trail, size.trail }, "")
Check(not trails:find(">", 1, true), "no > in a trail")

-- Matching: every typed word starts a word of the target's own.
Check(Names("bar size") == "Bar Size", "every word must match")
Check(Names("preview") == "", "a window card with no button is not a target")
Check(Names("BAR SIZE") == "Bar Size", "case does not matter")
Check(Names("siz") == "Bar Size", "a word's start is enough")
Check(Names("ize") == "", "but not its middle")
Check(Names("sound") == "Timer Sound|Alert Sound", "matches come in window order")
Check(Names("ping") == "Timer Sound", "a setting's help counts")
Check(Names("look") == "Bar Size|Timer Sound", "and its group")
Check(Names("parry") == "Timer Sound|Parry Alert|Alert Sound|Alert Color",
    "a card's name finds the card and the settings in it")
Check(Names("meter") == "[Bars]|[Other]", "a module's name finds its pages")
Check(Names("bars ping") == "Timer Sound" and Names("meter naowh") == "Naowh's Tips",
    "a module or tab name narrows the settings under it")
Check(Names("bars") == "[Bars]" and Names("solo bars") == "", "but finds no setting on its own, nor one elsewhere")
Check(Names("quality") == "[]" and Names("qol") == "[]" and UI.Search.Find(list, "quality")[1].page == "QoL/Bags"
    and Names("quality free") == "Free Slots",
    "a module is found by the name the sidebar shows, and by its short name")
Check(UI.Search.Find(list, "free")[1].tag == "Quality of Life", "and its settings are placed under that name")

-- A window card is found by its button and its fixed text, but not by text that changes; info cards are not searched.
Check(Names("swing history") == "Open Swing Log" and Names("open swing") == "Open Swing Log", "a window card is found")
Check(Names("changes") == "" and Names("release") == "" and Names("fixed") == "", "but not its live text, nor an info card")
Check(Names("naowh's") == "Naowh's Tips" and Names("naowh") == "Naowh's Tips", "punctuation splits words")
Check(Names("zzz") == "" and Names("   ") == "", "nothing typed or nothing found, no matches")

-- A typed word close to a word of a target's name (its letters in order) still finds it.
Check(Names("sze") == "Bar Size" and Names("sond") == "Timer Sound|Alert Sound", "a letter left out still finds the name")
Check(Names("alrt") == "Parry Alert|Alert Sound|Alert Color", "a card's name too")
Check(Names("ound") == "" and Names("sz") == "" and Names("sd") == "",
    "a close word starts with the same letter and has three letters or more")
Check(Names("pg") == "" and Names("plys") == "", "help is matched only by a word's start")
Check(Names("sizzz") == "", "every letter typed is in the word")
Check(UI.Search.Mark(UI.Search.Build(list, "sze"), "Bar Size") == "Bar <accent:S>i<accent:ze>",
    "the letters a close word matched are lit")
do
    local Search = dofile("Tools/regression/settings_search.lua")({ ["Misc/Page"] = { { id = "talk", name = "Talk",
        rows = { { key = "cheat", label = "Cheat Sheet", toggle = true }, { key = "frame", label = "Chat Frame", toggle = true } } } } })
    local function Labels(query)
        local out = {}
        for i, hit in ipairs(Search(query)) do out[i] = hit.label end
        return table.concat(out, "|")
    end
    Check(Labels("chat frame") == "Chat Frame", "each word matches exactly or closely")
    Check(Labels("chat") == "Chat Frame|Cheat Sheet", "exact matches come before close ones")
    Check(Labels("cht") == "Chat Frame|Cheat Sheet", "and close ones rank by how close they are")
end

-- A module that is turned off is searched from the generated index (ns.SEARCH_INDEX) through its pages.
do
    local planner = { name = "Planner" }
    local offPage = { key = "Planner/Settings", name = "Settings", module = planner }
    planner.tabs = { offPage }
    ns.SEARCH_INDEX = { ["Planner/Settings"] = {
        { "toast", false, "A toast when you level.", "Level-Up Toast", false },
        { "toast", "Toast Sound", "Plays a sound with the toast.", "Level-Up Toast", "Sound" },
    } }
    UI.SearchOffPages = function() return { offPage } end
    local offList = UI.Search.Collect()
    UI.SearchOffPages, ns.SEARCH_INDEX = function() return {} end, nil
    local Build, OffRows = UI.Search.Build, UI.Search.OffRows
    local f = Build(offList, "toast sound")
    local rows = OffRows(f, "Planner/Settings")
    Check(f.count["Planner/Settings"] == 1 and #rows == 1 and rows[1].label == "Toast Sound"
        and rows[1].trail == "Level-Up Toast" and not rows[1].isCard, "a setting of a module that is off is found")
    rows = OffRows(Build(offList, "level"), "Planner/Settings")
    Check(#rows == 2 and rows[1].isCard and rows[1].label == "Level-Up Toast", "and its card, by the card's name")
    rows = OffRows(Build(offList, "planner"), "Planner/Settings")
    Check(#rows == 2, "the module's name lists all of its settings")
    Check(#OffRows(Build(offList, "zzz"), "Planner/Settings") == 0, "nothing found, nothing listed")
end

-- Translated names are found and shown.
do
    ns.translations = { Meter = "Anzeige", Bars = "Balken" }
    local translated = UI.Search.Collect()
    ns.translations = nil
    local hit = UI.Search.Find(translated, "balken")[1]
    Check(hit and hit.tag == "Anzeige" and hit.trail == "Balken", "ns.L names are matched and shown")
end

-- The filter the window draws with: which pages have a match and how many, which cards show
-- whole, and which settings of the rest.
do
    local Build = UI.Search.Build
    Check(Build(list, "") == nil and Build(list, "  ") == nil, "nothing typed, no filter")
    local f = Build(list, "sound")
    Check(f.count["Meter/Bars"] == 2 and not f.count["Meter/Other"] and not f.count.Settings,
        "a page counts its matches; pages without one are not in it")
    local timer = f.cards["Meter/Bars:timer"]
    Check(type(timer) == "table" and timer["Timer Sound"] and not timer["Bar Size"],
        "a card keeps only its matching settings")
    Check(f.cards["Meter/Bars:alert"]["Alert Sound"] and not f.cards["Meter/Other:misc"], "card by card")
    Check(f.first["Meter/Bars"] == "Meter/Bars:timer" and f.order[1] == "Meter/Bars", "the first card and page, in window order")
    f = Build(list, "parry")
    Check(f.cards["Meter/Bars:alert"] == true and f.count["Meter/Bars"] == 4,
        "a card matched by name shows whole, and its own settings still count")
    f = Build(list, "meter")
    Check(f.all["Meter/Bars"] and f.all["Meter/Other"] and f.count["Meter/Other"] == 0,
        "a page matched by name shows whole, though it counts nothing")
    f = Build(list, "set")
    Check(f.all.Settings and not f.count["Solo/Settings"],
        "a lone tab's name (mostly Settings) does not match its module's page")
    Check(Build(list, "solo").all["Solo/Settings"], "its module's name still does")
    f = Build(list, "zzz")
    Check(f and #f.order == 0 and next(f.count) == nil, "nothing found is a filter with no pages")
    f = Build(list, "swing log")
    Check(f.cards["Meter/Other:Open Swing Log"] == true and f.count["Meter/Other"] == 1 and not f.all["Meter/Other"],
        "a window card found shows on its page, counted there")
end

-- A page its own builder draws names what is on it (page.terms): each is counted and keeps the
-- page whole, and a module found turned off is handed to the page.
do
    local off = { name = "Planner" }
    ns.TestTerms = function(add)
        add("Window Scale", "How big this window is.", "OPTIONS WINDOW")
        add("Planner", nil, "MODULES", off)
    end
    local shown = UI.SearchPages
    local settings = { key = "Settings", name = "Settings", title = "Settings", terms = "TestTerms" }
    ---@diagnostic disable-next-line: duplicate-set-field
    UI.SearchPages = function() return { settings, pages[2] } end
    local termed = UI.Search.Collect()
    local f = UI.Search.Build(termed, "scale")
    Check(f.count.Settings == 1 and f.all.Settings and #f.off == 0, "a page's own term is found and counted, the page whole")
    f = UI.Search.Build(termed, "big window")
    Check(f.count.Settings == 1, "by its help too")
    Check(UI.Search.Build(termed, "settings window").count.Settings == 1, "and the page's name narrows it")
    f = UI.Search.Build(termed, "planner")
    Check(f.off[1] == off and f.count.Settings == 1, "a module that is off is handed to the page that turns it on")
    Check(#UI.Search.Build(termed, "settings").off == 0 and UI.Search.Build(termed, "settings").count.Settings == 0,
        "the page's name alone finds the page, not each thing on it")
    UI.SearchPages, ns.TestTerms = shown, nil
end

-- The Profiles page is drawn by its own builder and carries the Setups card, a declared settings
-- page of its own (the real ProfilesPage.lua and SetupsCard.lua): the card and its settings are
-- found on the Profiles page, which then shows that card alone, its words lit.
do
    ns.QoLSettings = store
    ns.PRESETS = { order = { "minimalist" }, minimalist = { name = "Minimalist" } }
    Load("Core/Options/ProfilesPage.lua")
    Load("Core/Profiles/SetupsCard.lua")
    local profiles = { key = "Profiles", name = "Profiles", title = "Profiles", terms = "ProfilesSearchTerms" }
    local shown = UI.SearchPages
    ---@diagnostic disable-next-line: duplicate-set-field
    UI.SearchPages = function() return { pages[1], profiles, pages[2] } end
    local carried = UI.Search.Collect()
    local function Hit(query)
        local hits = UI.Search.Find(carried, query)
        return hits[1], #hits
    end
    for _, query in ipairs({ "setups", "setup", "onboarding", "before onboarding", "restore" }) do
        local hit = Hit(query)
        Check(hit and hit.page == "Profiles" and hit.card == "Profiles/Setups:setups" and hit.tag == "Profiles",
            "'" .. query .. "' is found on the Profiles page, in the Setups card")
    end
    local card, n = Hit("setups")
    Check(card.isCard and card.trail == "" and n == 4, "the card itself is a target, named by its page, then its three settings")
    local row = Hit("skin")
    Check(row.label == "Onboarding" and not row.isCard and row.trail == "Setups", "a row names its card")
    local f = UI.Search.Build(carried, "skin")
    Check(f.count.Profiles == 1 and f.first.Profiles == "Profiles/Setups:setups" and f.order[1] == "Profiles"
        and f.cards["Profiles/Setups:setups"]["Onboarding"], "the filter counts it on the Profiles page")
    Check(UI.Search.Build(carried, "profiles").all.Profiles, "the page's own name still keeps all of it")
    for _, query in ipairs({ "new profile", "copy", "reset", "delete", "use", "export", "share", "import", "paste" }) do
        local hit = Hit(query)
        Check(hit and hit.page == "Profiles" and not hit.card, "'" .. query .. "' finds a Profiles page action")
    end
    f = UI.Search.Build(carried, "export")
    Check(f.all.Profiles and f.count.Profiles == 1, "an action found keeps the whole page, counted")

    local rendered, built = {}, 0
    local render, view = Settings.Render, ns.Shared.View
    Settings.Render = function(_, key, _, filter)
        rendered[#rendered + 1] = { key = key, filter = filter }
        return 50
    end
    local profilesView = { Hide = function(self) self.hidden = true end }
    ns.Shared.View = { New = function() built = built + 1; return profilesView end }
    local host = { GetWidth = function() return 700 end }
    local function Frame()
        return { ClearAllPoints = function() end, SetPoint = function() end, SetWidth = function() end,
            SetHeight = function() end }
    end
    env.CreateFrame = Frame
    UI.filter = UI.Search.Build(carried, "skin")
    local y = ns.BuildProfileSettings(host, -10)
    Check(rendered[1].key == "Profiles/Setups" and rendered[1].filter == UI.filter,
        "found, the Setups card draws with the search's filter")
    Check(y == -60 and built == 0, "and the rest of the Profiles page is left out")
    host.profilesView = profilesView
    ns.BuildProfileSettings(host, -10)
    Check(profilesView.hidden, "a profiles list drawn before hides while the search narrows the page")
    UI.filter = UI.Search.Build(carried, "profiles")
    Check(UI.Search.Narrowed("Profiles") == nil, "the page found by its name is not narrowed")
    UI.filter = UI.Search.Build(carried, "bar size")
    Check(UI.Search.Narrowed("Profiles") == nil, "nor the page with no match on it")
    UI.filter = nil
    Check(UI.Search.Narrowed("Profiles") == nil, "nor with no search")

    local refreshed = 0
    function UI.RefreshPage() refreshed = refreshed + 1 end
    local input
    local function Region()
        return setmetatable({ GetFrameLevel = function() return 0 end }, { __index = function() return function() end end })
    end
    env.CreateFrame = Region
    ns.Solid, ns.Font, ns.Border = Region, Region, Region
    ns.Shared.Parts = { SearchBox = function(_, _, onText)
        input = onText
        return Region()
    end }
    function UI.RegisterOnHide() end
    UI.AttachSearchBox({}, function() end)
    input("bar size")
    Check(refreshed == 0, "a search that does not touch the Profiles page redraws nothing more")
    input("onboard")
    Check(refreshed == 1, "one that finds the Setups card redraws the Profiles page with it")
    input("onboarding")
    Check(refreshed == 2, "and again as the words change")
    input("")
    Check(refreshed == 3 and UI.filter == nil, "cleared, the Profiles page is drawn whole again")
    input("bar")
    Check(refreshed == 3, "then a search elsewhere redraws nothing more")

    Settings.Render, ns.Shared.View, UI.SearchPages = render, view, shown
end

-- The typed words, lit in the accent where they start a word.
do
    local Mark, f = UI.Search.Mark, UI.Search.Build(list, "tim sou")
    Check(Mark(f, "Timer Sound") == "<accent:Tim>er <accent:Sou>nd", "each typed word is lit where it starts a word")
    Check(Mark(f, "Untimely") == "Untimely", "but not in a word's middle")
    Check(Mark(nil, "Timer Sound") == "Timer Sound" and Mark(f, nil) == nil, "no filter, no change")
    Check(Mark(UI.Search.Build(list, "naowh s"), "Naowh's Tips") == "<accent:Naowh>'<accent:s> Tips",
        "punctuation starts a word")
end

-- The builder scan, its row tags, the jump's glow and the old bar are gone for good.
do
    local widgets = Read("Core/Options/Widgets.lua")
    local window = Read("Core/Options/Window.lua")
    Check(not widgets:find("searchScan", 1, true) and not widgets:find("_searchL", 1, true), "no scan in the widgets")
    Check(not window:find("noscan", 1, true) and not window:find("Flash", 1, true), "no scan flags or glow in the window")
    Check(window:find("searchBox = UI.AttachSearchBox(sidebar", 1, true), "the sidebar holds the search box")
    Check(not window:find("AttachSearchBar", 1, true) and not window:find("searchOpen", 1, true), "the bar is gone")
end
print("PASS sidebar search: " .. cases .. " checks")

-- Run with Lua 5.1 from the repository root: what the modules share (Shared/), loaded from the
-- files Shared.xml loads, in order, against stubs. Checks that nothing is made or listened to
-- at load, the item helpers, the Forever mark, and the row engine a page is drawn with: rows
-- pooled and reused, a burst of events making one redraw and none while hidden, a redraw that
-- makes no garbage, and a tracker's window (Parts.TrackerPanel).
local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Measure = dofile("Tools/regression/measure.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

-------------------------------------------------------------------------------
--  Stubs: a frame keeps its scripts, events, size, text and shown state; every other method
--  is one shared do-nothing function, so the stubs make no garbage of their own.
-------------------------------------------------------------------------------
local NOTHING = function() end
local Frame
local made = 0   -- frames made, all told
local METHODS = {
    SetScript = function(f, script, fn) f.scripts[script] = fn end,
    GetScript = function(f, script) return f.scripts[script] end,
    HookScript = function(f, script, fn) f.scripts[script] = fn end,
    RegisterEvent = function(f, event) f.events[event] = true end,
    UnregisterAllEvents = function(f) for event in pairs(f.events) do f.events[event] = nil end end,
    GetParent = function(f) return rawget(f, "parent") end,
    IsForbidden = function() return false end,
    SetWidth = function(f, w) f.w = w end,
    SetHeight = function(f, h) f.h = h end,
    SetSize = function(f, w, h) f.w, f.h = w, h end,
    GetWidth = function(f) return rawget(f, "w") or 600 end,
    GetHeight = function(f) return rawget(f, "h") or 24 end,
    SetText = function(f, text) f.text = text end,
    SetTextColor = function(f, r, g, b) f.r, f.g, f.b = r, g, b end,
    GetText = function(f) return rawget(f, "text") or "" end,
    GetStringWidth = function() return 40 end,
    GetStringHeight = function() return 12 end,
    Show = function(f) f.shown = true end,
    Hide = function(f) f.shown = false end,
    SetShown = function(f, shown) f.shown = shown and true or false end,
    IsShown = function(f) return rawget(f, "shown") ~= false end,
    IsVisible = function(f) return rawget(f, "shown") ~= false end,
    GetEffectiveScale = function() return 1 end,
    CreateTexture = function(f) return Frame(f) end,
    CreateFontString = function(f) return Frame(f) end,
    CreateAnimationGroup = function(f) return Frame(f) end,
    CreateAnimation = function(f) return Frame(f) end,
}
local META = { __index = function(_, key)
    if METHODS[key] then return METHODS[key] end
    if type(key) == "string" and key:find("^%u") then return NOTHING end
end }
function Frame(parent)
    made = made + 1
    return setmetatable({ scripts = {}, events = {}, parent = parent }, META)
end

local WHITE = { r = 1, g = 1, b = 1 }
local timers = {}
local coinCalls = 0
local tooltip = Frame()
tooltip.GetOwner = function() return nil end

local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    THEME = setmetatable({}, { __index = function() return WHITE end }),
    Color = function(_, text) return tostring(text) end,
    Font = function(parent) return Frame(parent) end,
    Solid = function(parent, _, color)
        local solid = Frame(parent)
        solid.color = color
        return solid
    end,
    ThemeTint = function(_, literal) return literal end,
    -- As ns.Hairline and ns.PixelInset: whole-pixel sizing has no effect on these stubs.
    Hairline = function(region) return region end,
    PixelInset = function(region) return region end,
    Border = function() return { SetColor = NOTHING } end,
    AllowOffscreen = NOTHING,
    AccentBorder = function() return { SetColor = NOTHING } end,
    Button = function(parent) return Frame(parent) end,
    UIFontPath = function() return "font" end,
    AccountSettings = function() return {} end,
    UI = { Keep = function(parent, key, make)
        local kept = rawget(parent, key)
        if not kept then kept = make(parent); parent[key] = kept end
        return kept
    end },
}
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function(_, _, parent) return Frame(parent) end,
    Mixin = function(target, ...)
        for i = 1, select("#", ...) do
            for k, v in pairs((select(i, ...))) do target[k] = v end
        end
        return target
    end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    C_Item = {
        GetItemInfoInstant = function(id)
            if id == 19019 then return id, "", "", "INVTYPE_WEAPONMAINHAND", 135349, 2, 7 end
            if id == 18348 then return id, "", "", "INVTYPE_2HWEAPON", 135349, 2, 8 end
        end,
        GetItemNameByID = function(id) return id == 19019 and "Thunderfury" or nil end,
        GetItemQualityByID = function(id) return id == 19019 and 5 or nil end,
        GetItemCount = function() return 0 end,
        IsItemDataCachedByID = function() return true end,
        IsEquippedItem = function() return false end,
    },
    ITEM_QUALITY_COLORS = { [5] = { hex = "|cffff8000", r = 1, g = 0.5, b = 0 } },
    GameTooltip = tooltip,
    GameTooltip_Hide = NOTHING,
    InCombatLockdown = function() return false end,
    CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end,
    UIParent = Frame(),
    C_CurrencyInfo = { GetCoinTextureString = function(copper)
        coinCalls = coinCalls + 1
        return "<" .. copper .. ">"
    end },
}, { __index = _G })
env._G = env

-------------------------------------------------------------------------------
--  Loading: everything Shared.xml lists, in its order, and nothing made or listened to.
-------------------------------------------------------------------------------
local files = TocFiles("^Shared/.*%.lua$")
check("the TOC loads Shared.xml, and it lists the files", #files >= 9 and files[1] == "Shared/Shared.lua")
local before = made
Load(files, env)
local Shared = ns.Shared
check("everything there: Style, Items, Parts, View, Kinds", Shared.Style and Shared.Items and Shared.Parts
    and Shared.View and Shared.Kinds and Shared.ForeverNew)
check("nothing made at load", made == before and #timers == 0)

-------------------------------------------------------------------------------
--  Items
-------------------------------------------------------------------------------
local Items = Shared.Items
check("an ID from a number, a link, a Wowhead URL or its digits",
    Items.IDFrom(19019) == 19019 and Items.IDFrom("|cffff8000|Hitem:19019::::|h[Thunderfury]|h|r") == 19019
    and Items.IDFrom("https://www.wowhead.com/forever/item=19019/thunderfury") == 19019
    and Items.IDFrom(" 19019 ") == 19019)
check("nothing from what names no item", Items.IDFrom("Thunderfury") == nil)
check("a name, or what it is while it loads", Items.Name(19019) == "Thunderfury" and Items.Name(1) == "item 1")
check("its quality's color, white while unknown", Items.QualityHex(19019) == "|cffff8000"
    and Items.QualityHex(1) == "|cffffffff")
check("a two-hander is one; a one-hander is not", Items.IsTwoHand(18348) and not Items.IsTwoHand(19019))

-------------------------------------------------------------------------------
--  The Forever mark: what is new in Forever, by kind and ID.
-------------------------------------------------------------------------------
local Parts = Shared.Parts
local newItem = next(Shared.ForeverNew.items)
check("an item new in Forever has the mark; one from the original game not", Parts.IsForever("items", newItem)
    and not Parts.IsForever("items", 19019))

local partsSource = assert(io.open("Shared/UI/Text.lua", "rb")):read("*a")
local COINS_KEPT = tonumber(partsSource:match("local COINS_KEPT = (%d+)"))
check("a price in coins, asked for again, is made once", Parts.Coins(12345) == "<12345>"
    and Parts.Coins(12345) == "<12345>" and coinCalls == 1)
for copper = 1, COINS_KEPT * 3 do Parts.Coins(copper) end
local calls = coinCalls
Parts.Coins(COINS_KEPT * 3)
check("the prices kept are bounded: the newest are still there", coinCalls == calls)
Parts.Coins(1)
check("and the oldest go", coinCalls == calls + 1)

-------------------------------------------------------------------------------
--  The row engine: a page of rows of its own kind, under a shared section title.
-------------------------------------------------------------------------------
local View = Shared.View
local kinds = View.NewKinds()
local madeRows = 0
kinds.line = {
    New = function(view)
        madeRows = madeRows + 1
        local row = Frame(view)
        row.label = Frame(row)
        return row
    end,
    Set = function(row, text, waiting)
        row.label:SetText(text)
        return 20, waiting
    end,
}
local TEXTS = {}
for i = 1, 50 do TEXTS[i] = "line " .. i end
local EVENTS = { "BAG_UPDATE_DELAYED" }
local page = { count = 50, waitOn = nil }
function page:Redraw()
    self:Clear()
    self:Section("Loot", self.count)
    for i = 1, self.count do self:Add("line", TEXTS[i], i == self.waitOn) end
    if self.waitOn then self.waitingFor[self.waitOn] = true end
    self:Fit(EVENTS)
end
local view = View.New(Frame(), kinds, page)
view:Redraw()
check("a page drawn: each row under the last, as tall as all of them", madeRows == 50
    and view.h == view.cursor and view.cursor > 50 * 20)
check("listening for what it asked for", view.events.BAG_UPDATE_DELAYED
    and not view.events.GET_ITEM_INFO_RECEIVED)
view.count = 10
view:Redraw()
local shownRows = 0
for i = 1, view.pools.line.used do if view.pools.line[i]:IsShown() then shownRows = shownRows + 1 end end
check("drawn again shorter: rows reused, none made, the rest hidden", madeRows == 50 and shownRows == 10
    and view.pools.line[11].shown == false)
local row = view:Find("line", function(r, text) return r.label.text == text end, "line 7")
check("a drawn row found by what it shows", row and row.top == view.pools.line[7].top)
local forbidden = setmetatable({}, { __index = function(_, key)
    if key == "IsForbidden" then return function() return true end end
    error("touched a forbidden frame: " .. key)
end })
---@diagnostic disable-next-line: duplicate-set-field
tooltip.GetOwner = function() return forbidden end
tooltip.shown = true
check("a redraw leaves a tooltip on a forbidden frame (a nameplate aura in combat) alone",
    pcall(view.Redraw, view) and tooltip.shown == true)
---@diagnostic disable-next-line: duplicate-set-field
tooltip.GetOwner = function() return view.pools.line[1] end
view:Redraw()
check("and still closes its own row's tooltip", tooltip.shown == false)
---@diagnostic disable-next-line: duplicate-set-field
tooltip.GetOwner = function() return nil end
view.waitOn = 3
view:Redraw()
check("a row waiting on an item's name: listened for", view.events.GET_ITEM_INFO_RECEIVED)
view:OnEvent("GET_ITEM_INFO_RECEIVED", 999)
check("another item's name is not its business", #timers == 0)
view:OnEvent("GET_ITEM_INFO_RECEIVED", 3)
view:OnEvent("BAG_UPDATE_DELAYED")
view:OnEvent("BAG_UPDATE_DELAYED")
check("a burst of events: one redraw queued", #timers == 1)
view.waitOn = nil
local drawn = 0
local redraw = view.Redraw
view.Redraw = function(self) drawn = drawn + 1; redraw(self) end
timers[1](); timers[1] = nil
check("and drawn once", drawn == 1)
view.waitOn = 4
redraw(view)
view:OnEvent("GET_ITEM_INFO_RECEIVED", 4, false)
check("an item the server will not send: no redraw for it", #timers == 0)
check("nor waited on any more", view.waitingFor[4] == nil)
check("and remembered for the session, alone", Items.Refused(4) and not Items.Refused(3))
view:OnEvent("GET_ITEM_INFO_RECEIVED", 4, false)
check("told again: still nothing to do", #timers == 0)
view.waitOn = nil
view:Hide()
view.scripts.OnHide(view)
check("hidden: listening to nothing", next(view.events) == nil)
view:QueueRedraw()
timers[1](); timers[1] = nil
check("and not drawn while hidden", drawn == 1)
view:Show()

local columns, width = View.Columns(600)
check("cards across: as many as fit, each as wide as shares the width", columns >= 1
    and width * columns <= 600 and View.Columns(10) == 1)

-- A module's window opened from /nf the first time, as the game does it: a frame is made
-- shown, Show() runs OnShow only on a hidden frame and Hide() runs OnHide only on a shown one.
local function GameShow(f)
    if f:IsShown() then return end
    f.shown = true
    if f.scripts.OnShow then f.scripts.OnShow(f) end
end
local function GameHide(f)
    if not f:IsShown() then return end
    f.shown = false
    if f.scripts.OnHide then f.scripts.OnHide(f) end
end
local window
local function OpenWindow()
    if not window then window = Parts.Window(400, 300, "testWindow") end
    GameShow(window)
end
local backs = 0
Parts.OpenWithBack(OpenWindow, Frame(), function() backs = backs + 1 end, "Back to Settings")
check("a window opened from another one the first time knows its way back", window.onBack ~= nil)
GameHide(window)
check("and closing it brings that one back", backs == 1)
Parts.OpenWithBack(OpenWindow, Frame(), function() backs = backs + 1 end, "Back to Settings")
GameHide(window)
check("the second time too", backs == 2)

view.Redraw = redraw
view.count = 50
Measure(check)("a page of 50 rows redrawn", 1, function() view:Redraw() end)

-------------------------------------------------------------------------------
--  A declared settings page, drawn again after a change: no garbage.
-------------------------------------------------------------------------------
local function Control(parent)
    local control = Frame(parent)
    control._refreshValue, control._refreshLabel = NOTHING, NOTHING
    return control
end
METHODS.GetFrameLevel = function() return 1 end
ns.UI.BuildToggleControl = Control
ns.UI.BuildSliderCore = function(parent) return Control(parent), Frame(parent) end
ns.UI.SetSliderRange = NOTHING
ns.UI.CHEVRON, ns.UI.CONTENT_PAD = "chevron", 20
local values = { on = true, size = 12 }
local store = {
    Get = function(k) return values[k] end,
    Raw = function(k) return values[k] end,
    Default = function() return nil end,
    Set = function(k, v) values[k] = v end,
    OnChange = NOTHING,
}
local Settings = Shared.Settings
Settings.Page("Test/Costs", store):Card({ id = "costs", name = "Costs", switch = "on", rows = {
    Settings.Group("Look"),
    { key = "shown", label = "Shown", toggle = true },
    { key = "size", label = "Size", slider = { 8, 32, 1 }, unit = "px", needs = "shown" },
    { key = "alpha", label = "Opacity", slider = { 0, 100, 5 }, unit = "%" },
} })
local settingsParent = Frame()
Settings.Render(settingsParent, "Test/Costs", NOTHING)
local settingsView = settingsParent.settingsView
check("the settings page drew its card", settingsView.pools.setting.used == 3 and settingsView.pools.group.used == 1)
Measure(check)("a settings page redrawn", 1, function() settingsView:Redraw() end)

do
    local switched, defaults = {}, { on = true }
    local switchStore = {
        Get = function(k) if switched[k] == nil then return defaults[k] end return switched[k] end,
        Raw = function(k) return switched[k] end,
        Default = function(k) return defaults[k] end,
        Set = function(k, v) switched[k] = v end,
        OnChange = NOTHING,
    }
    Settings.Page("Test/Switch", switchStore):Card({ id = "switch", name = "Switch", switch = "on", rows = {
        { key = "shown", label = "Shown", toggle = true },
    } })
    local parent = Frame()
    Settings.Render(parent, "Test/Switch", NOTHING)
    local head = parent.settingsView.pools.cardHead[1]
    check("a card switch at its default has no changed dot", head.dot.shown == false)
    switched.on = false
    parent.settingsView:Redraw()
    check("switched off from its default, the card head shows the dot", head.dot.shown == true)
    check("and it has no click, so a stray click never switches a feature on", head.dot.scripts.OnClick == nil)
end

-------------------------------------------------------------------------------
--  A tracker's window (Parts.TrackerPanel): built only when asked, its parts where the
--  options ask for them, rows pooled, the body scrolling past its height, its place kept.
-------------------------------------------------------------------------------
local opened, wentTo, titled, saved, moved
ns.OpenOptionsWindow = function(name) opened = name end
ns.UI.GoToSetting = function(_, _, feature) wentTo = feature end
ns.UI.COGS_ICON = "cog"
ns.UI.SlimScroll = function(parent) return Frame(parent) end
ns.UI.BuildDropdownControl = function(parent) return Frame(parent) end
env.Menu = { GetManager = function() return { IsAnyMenuOpen = function() return false end } end }
local createFrame = env.CreateFrame
local function Level() return 1 end
env.CreateFrame = function(kind, name, parent)
    local frame = createFrame(kind, name, parent)
    frame.GetFrameLevel = Level
    return frame
end
local where
local tracker = Parts.TrackerPanel("BOOKS", {
    width = 320, titleRoom = 74, maxHeight = function() return 300 end,
    onTitle = function() titled = true end, titleTip = "Books", titleHint = "Click for its settings.",
    bar = true,
    picker = { values = {}, order = {}, get = NOTHING, set = NOTHING },
    settings = { page = "Discovery/Library Books", card = "tracker", tip = "Settings" },
    load = function() if where then return where[1], where[2], where[3], where[4] end end,
    save = function(point, relativePoint, x, y) saved = { point, relativePoint, x, y } end,
    place = { "RIGHT", "RIGHT", -60, 60 },
    mover = function(frame, onMoved) moved = onMoved; return Frame(frame) end,
})
check("a tracker: its bar, dropdown, cog, body and mover", tracker.bar and tracker.picker and tracker.settings
    and tracker.body and tracker.mover and tracker.footer > 0)
check("its body starts under the title, the bar and the dropdown", tracker:Top() == 30 + 4 + 24 + 6 + 24 + 6)
tracker.picker:Hide()
check("a hidden dropdown leaves no room", tracker:Top() == 30 + 4 + 24 + 6)
tracker.picker:Show()
check("as wide as asked, its body inside the padding", tracker.w == 320 and tracker.body.w == 300)
tracker.settings.scripts.OnClick(tracker.settings)
check("its cog opens its settings, at its card", opened == "Discovery/Library Books"
    and wentTo == "Discovery/Library Books:tracker")
tracker.titleButton.scripts.OnClick(tracker.titleButton)
check("its title is clicked through to the module", titled)
tracker.GetPoint = function() return "TOP", nil, "TOP", 5, -7 end
tracker.scripts.OnDragStop(tracker)
check("dragged, its place is saved", saved and saved[1] == "TOP" and saved[4] == -7)
moved({ point = "LEFT", relPoint = "LEFT", x = 1, y = 2 })
check("and Unlock Mode's mover saves through the same", saved[1] == "LEFT" and saved[4] == 2)
local placed
tracker.SetPoint = function(_, point, _, _, x) placed = { point, x } end
tracker:Place()
check("placed at its default before it has a place", placed[1] == "RIGHT" and placed[2] == -60)
where = { "TOP", "TOP", 9, 9 }
tracker:Place()
check("then where it was left", placed[1] == "TOP" and placed[2] == 9)

check("its bar on the tracker bar's shade, the theme's panel once changed",
    tracker.bar.bg.color == Shared.Style.TRACKER_BAR_RGB)

local pinned, pinnedEntry = 0, nil
local function Waypoint(entry) pinned, pinnedEntry = pinned + 1, entry end
local GREY = { r = 0.5, g = 0.5, b = 0.5 }
local ENTRIES = {
    { text = "Book one", sub = "In a crate", waypoint = Waypoint },
    { text = "Book two", waypoint = Waypoint },
    { text = "Book three", done = true, color = GREY },
}
local height = tracker:SetRows(ENTRIES)
local rows = tracker.rows
check("a row each, every other one striped", #rows == 3 and rows[2].stripe:IsShown()
    and not rows[1].stripe:IsShown())
check("a pin where there is a waypoint, a tick once done", rows[1].pin:IsShown() and not rows[3].pin:IsShown()
    and rows[3].tick:IsShown() and not rows[1].tick:IsShown())
check("a line under each but the last", rows[1].divider:IsShown() and not rows[3].divider:IsShown())
check("as tall as its rows", height == (6 + 12 + 8) * 3 + 3 + 12 and tracker.body.h == height)
rows[1].pin.scripts.OnClick(rows[1].pin)
check("a pin's click is the row's waypoint, handed its entry", pinned == 1 and pinnedEntry == ENTRIES[1])
check("a row's text in its color, else the theme's text", rows[3].text.r == 0.5 and rows[1].text.r == 1)
local madeBefore = made
tracker:SetRows({ ENTRIES[1], ENTRIES[2] })
check("fewer rows: reused, none made, the rest hidden", made == madeBefore and #rows == 3 and rows[3].shown == false)
check("short: no scrollbar", tracker:Fit(100) == false and tracker.h == tracker:Top() + 100 + tracker.footer + 10
    and tracker:ScrollGap() == 0)
check("past its height it scrolls, and says so once", tracker:Fit(1000) == true and tracker.h == 300
    and tracker:ScrollGap() == 20 and tracker:Fit(1000) == false)
tracker:SetTrackerWidth(320)
check("its body leaves the scrollbar room", tracker.body.w == 280)
check("and stops", tracker:Fit(100) == true and tracker:ScrollGap() == 0)
Measure(check)("a tracker's rows laid out", 1, function() tracker:SetRows(ENTRIES) end)

local plain = Parts.TrackerPanel("PLAIN", {})
check("with no options: no bar, dropdown or cog, its body under the title", not plain.bar and not plain.picker
    and not plain.settings and plain.footer == 0 and plain:Top() == 34 and plain:Fit(100) == false)
check("and a tracker's width", plain.w == Shared.Style.TRACKER_W)

-------------------------------------------------------------------------------
--  The look standard: Settings.Look's rows, a card holding them, the texture and outline
--  choices, and Parts.HudFont.
-------------------------------------------------------------------------------
local widgets = assert(io.open("Core/Options/Widgets.lua", "rb")):read("*a"):gsub("\r\n", "\n")
-- The media helpers, from the LibSharedMedia lookup (when Widgets has one) to TexturePath, with
-- the file's text constants before them, since the helpers read those.
local helpers = assert(widgets:match("\n(local function SharedMedia%(%).-\nfunction UI%.TexturePath%(name, fallback%).-\nend)\n")
    or widgets:match("\n(function UI%.FontPath%(name%).-\nfunction UI%.TexturePath%(name, fallback%).-\nend)\n"),
    "Widgets: FontPath to TexturePath")
local texts = {}
for line in widgets:gmatch("[^\n]+") do
    local open, close = select(2, line:gsub("%(", "")), select(2, line:gsub("%)", ""))
    if line:match("^local TEXT_[%w_, ]+ = ") and line:match("[\"%)]$") and open == close then
        texts[#texts + 1] = line
    end
end
helpers = table.concat(texts, "\n") .. "\n" .. helpers
local MEDIA = { font = { Naowh = "naowh.ttf" },
    statusbar = { Blizzard = "bar.blp", Solid = "solid", ["Naowh Gradient"] = "gradient.tga" } }
local LSM = {
    List = function(_, kind)
        local names = {}
        for name in pairs(MEDIA[kind]) do names[#names + 1] = name end
        table.sort(names)
        return names
    end,
    Fetch = function(_, kind, name) return MEDIA[kind][name] end,
}
local helperEnv = setmetatable({ UI = ns.UI, ns = ns, LibStub = function() return LSM end }, { __index = _G })
local chunk = assert(loadstring(helpers))
setfenv(chunk, helperEnv)
chunk()
local UI = ns.UI

local textures, list = UI.TextureChoices("", "Flat")
check("texture choices: the element's own texture first, under its name", list[1] == "" and textures[""] == "Flat")
check("then every SharedMedia statusbar", textures.Solid == "Solid" and textures["Naowh Gradient"] == "Naowh Gradient"
    and #list == 4)
textures, list = UI.TextureChoices("Gone", "Naowh Gradient")
check("an entry named as the element's own is not listed twice", textures["Naowh Gradient"] == nil and #list == 4)
check("a saved texture that has gone stays listed", textures.Gone == "Gone (unavailable)" and list[#list] == "Gone")
check("texture path: a SharedMedia name", UI.TexturePath("Solid", "own") == "solid")
check("texture path: the element's own for empty or missing", UI.TexturePath("", "own") == "own"
    and UI.TexturePath("Gone", "own") == "own" and UI.TexturePath(nil, "own") == "own")
local core = assert(io.open("Core/Core.lua", "rb")):read("*a")
check("the Naowh Gradient is a SharedMedia statusbar",
    core:find('LSM:Register("statusbar", "Naowh Gradient", NAOWH_GRADIENT)', 1, true)
    and core:find('local MEDIA = "Interface\\\\AddOns\\\\NaowhForever\\\\Core\\\\Media\\\\"', 1, true)
    and core:find('local NAOWH_GRADIENT = MEDIA .. "NaowhGradient.tga"', 1, true))

local function Keys(entries)
    local out = {}
    for _, r in ipairs(entries) do out[#out + 1] = r.group and ("[" .. r.group .. "]") or r.key end
    return table.concat(out, " ")
end
local function Needs() return true end
local look = Settings.Look("combatTimer", { text = true, background = "card", needs = Needs, why = "Off" })
check("text and card rows keyed by the prefix", Keys(look)
    == "[Text] combatTimerFont combatTimerFontSize combatTimerOutline [Background] combatTimerBackground")
check("every row takes needs and why", look[2].needs == Needs and look[6].why == "Off")
check("the card background is the HUD backgrounds choice", look[6].choice == Parts.HUD_BACKGROUNDS)
check("the outline row is the shared outline choice", look[4].choice == Parts.HUD_OUTLINES
    and Parts.HUD_OUTLINES[2][1] == "NONE" and Parts.HUD_OUTLINES[2][2] == "" and Parts.HUD_OUTLINES[2][4] == "THICKOUTLINE")
look = Settings.Look("", { text = true, size = { 6, 24, 1 }, bar = "Flat", background = "alpha",
    keys = { FontSize = "textSize", Outline = false } })
check("no prefix: plain keys; an existing key kept; a row left out", Keys(look)
    == "[Text] font textSize [Bar] texture bgAlpha")
check("the size range given, the texture's own name, opacity in percent", look[3].slider[2] == 24
    and look[5].texture == "Flat" and look[6].unit == "%" and look[6].scale == 0.01)
look = Settings.Look("bag", { background = "alpha", keys = { BgAlpha = false } })
check("a part with every row left out has no group", #look == 0)
look = Settings.Look("bag", { background = "alpha" })
check("opacity without a bar has its own group", Keys(look) == "[Background] bagBgAlpha")

local picked
---@diagnostic disable-next-line: duplicate-set-field
ns.UI.BuildDropdownControl = function(parent)
    local control = Control(parent)
    control._refreshLabel = function() picked = control._values end
    return control
end
local lookValues = { on = true, texture = "Solid" }
local lookStore = {
    Get = function(k) return lookValues[k] end,
    Raw = function(k) return lookValues[k] end,
    Default = function(k) return ({ on = true, texture = "", outline = "OUTLINE" })[k] end,
    Set = function(k, v) lookValues[k] = v end,
    OnChange = NOTHING,
}
local card = Settings.Page("Test/Look", lookStore):Card({ id = "look", name = "Look", rows = {
    Settings.Group("Behaviour"),
    { key = "on", label = "On", toggle = true },
    Settings.Look("", { bar = "Flat" }),
    { key = "barAlpha", label = "Bar Opacity", slider = { 0, 100, 5 } },
} })
check("a card takes Look's rows in place", Keys(card.rows) == "[Behaviour] on [Bar] texture barAlpha")
check("its rows are set up like any other", card.rows[4].kind == "texture" and card.rows[4].get() == "Solid"
    and card.rows[4].card == card)
card.rows[4].set("Blizzard")
check("and save to the store", lookValues.texture == "Blizzard" and Settings.ChangedCount(card) == 1)
Settings.Render(Frame(), "Test/Look", NOTHING)
check("a texture row lists SharedMedia's statusbars", picked and picked[""] == "Flat" and picked.Blizzard == "Blizzard")
local fnCard = Settings.Page("Test/Look", lookStore):Card({ id = "fn", name = "Fn", rows = function()
    return { Settings.Look("", { text = true, keys = { Font = false, FontSize = false } }) }
end })
check("rows from a function are flattened too", Keys(Settings.Rows(fnCard)) == "[Text] outline"
    and fnCard.rows[2].kind == "choice")

local fs = Frame()
function fs:SetFont(path, size, flags) self.font, self.size, self.flags = path, size, flags end
function fs:SetShadowColor(_, _, _, a) self.shadowAlpha = a end
function fs:SetShadowOffset(x, y) self.shadowX, self.shadowY = x, y end
ns.UI.FontPath = function(name) return name == "" and "addon.ttf" or name .. ".ttf" end
local St = Shared.Style
check("hud font: face, size and outline, and returns the string", Parts.HudFont(fs, "Naowh", 14, "OUTLINE") == fs
    and fs.font == "Naowh.ttf" and fs.size == 14 and fs.flags == "OUTLINE")
check("an outline takes the shadow off", fs.shadowAlpha == 0 and fs.shadowX == 0)
Parts.HudFont(fs, "", 12, "")
check("no outline: the Addon Font with the card's shadow", fs.font == "addon.ttf" and fs.flags == ""
    and fs.shadowAlpha == St.HUD_SHADOW_ALPHA and fs.shadowX == St.HUD_SHADOW_X)
Parts.HudFont(fs, "", 12, "", "soft")
check("or the shadow for its background", fs.shadowAlpha == St.HUD_SOFT_SHADOW_ALPHA)
Parts.HudFont(fs, "", 12, "THICKOUTLINE", "none")
check("a thick outline has no shadow either", fs.flags == "THICKOUTLINE" and fs.shadowAlpha == 0)
Parts.HudFont(fs, "", 12, "NONE")
check("None: no outline and no shadow", fs.flags == "" and fs.shadowAlpha == 0 and fs.shadowX == 0)

-------------------------------------------------------------------------------
--  A row's cog and icons: the rows set in a cog's panel are hidden card rows, still counted,
--  reset, searched and jumped to; the panel follows the cog, and closes with a second click or
--  the cogPage going away. A card's watch, and a cogPage changed while hidden.
-------------------------------------------------------------------------------
local function RunTimers()
    while #timers > 0 do table.remove(timers, 1)() end
end
METHODS.SetVertexColor = function(f, r, g, b) f.tint = { r, g, b } end
METHODS.SetTexture = function(f, texture) f.texture = texture end
METHODS.EnableMouse = function(f, on) f.mouse = on end
METHODS.SetAlpha = function(f, a) f.alpha = a end
METHODS.SetPoint = function(f, ...) f.point = { ... } end
METHODS.ClearAllPoints = function(f) f.point = nil end
ns.UI.COGS_ICON = "cog"
ns.UI.ShowWidgetTooltip, ns.UI.HideWidgetTooltip = NOTHING, NOTHING
ns.UI.Search = { Mark = function(_, text) return text end }
local SOFT = { r = 0.3, g = 0.7, b = 0.96 }
rawset(ns.THEME, "accentSoft", SOFT)

local cogDefaults = { showCount = true, countSize = 14, countX = 0, other = false }
local cogValues = { showCount = true }
local listeners = {}
local cogStore = {
    Get = function(k) if cogValues[k] ~= nil then return cogValues[k] end return cogDefaults[k] end,
    Raw = function(k) return cogValues[k] end,
    Default = function(k) return cogDefaults[k] end,
    Set = function(k, v)
        cogValues[k] = v
        for _, fn in ipairs(listeners) do fn() end
    end,
    OnChange = function(fn) listeners[#listeners + 1] = fn end,
}
local backed, anchored = 0, false
local cogCard = Settings.Page("Test/Cogs", cogStore):Card({ id = "bar", name = "Bar", rows = {
    { key = "showCount", label = "Show Count", toggle = true, cog = { title = "Count Text", tip = "Its text." } },
    { key = "countSize", label = "Count Size", slider = { 8, 32, 1 }, under = "Show Count" },
    { key = "countX", label = "Count X", slider = { -50, 50, 1 }, under = "Show Count" },
    { key = "other", label = "Other", toggle = true, icons = {
        { texture = "back", tip = "Back.", open = function() backed = backed + 1 end,
          enabled = function() return anchored end } } },
} })
check("a row set in a cog is a hidden card row", cogCard.rows[2].hidden == true and cogCard.rows[2].under == "Show Count")
check("the cog is the row's first icon", cogCard.rows[1].icons[1].cogFor == cogCard.rows[1])

local cogParent = Frame()
Settings.Render(cogParent, "Test/Cogs", NOTHING)
local cogPage = cogParent.settingsView
local function PageRow(label)
    for i = 1, cogPage.pools.setting.used do
        local cogRow = cogPage.pools.setting[i]
        if cogRow.setting.label == label then return cogRow end
    end
end
check("the cogPage draws the list's rows only", cogPage.pools.setting.used == 2 and PageRow("Show Count")
    and PageRow("Other") and not PageRow("Count Size"))
local cogIcon = PageRow("Show Count").icons[1]
check("the cog is drawn left of the row's control", cogIcon.shown ~= false and cogIcon.tex.texture == "cog")
local back = PageRow("Other").icons[1]
check("an icon greyed out while it cannot be used", back.tex.texture == "back" and back.mouse == false)
anchored = true
cogPage:Redraw()
check("and lit once it can", back.mouse == true)
back.scripts.OnClick(back)
check("its click does its one thing", backed == 1)

cogIcon.scripts.OnClick(cogIcon)
local panel = Settings.CogPanel()
local function PanelRow(label)
    for i = 1, panel.view.pools.setting.used do
        local cogRow = panel.view.pools.setting[i]
        if cogRow.setting.label == label then return cogRow end
    end
end
check("the cog opens its panel under itself", panel.shown and panel.point[2] == cogIcon and panel.point[1] == "TOP")
check("titled, with the rows set under it", panel.title.text == "Count Text" and PanelRow("Count Size")
    and PanelRow("Count X") and panel.view.pools.setting.used == 2)
check("drawn like the cogPage's rows", PanelRow("Count Size").setting.kind == "slider")

PanelRow("Count Size").setting.set(20)
RunTimers()
check("a change shows its dot in the panel", PanelRow("Count Size").dot.shown == true)
check("the card counts it", Settings.ChangedCount(cogCard) == 1)
-- The redraw lays the cogPage out anew; the panel is put back under the cog wherever it is now.
panel:ClearAllPoints()
cogPage:Redraw()
check("and the cog shows one of its settings changed", cogIcon.tex.tint[1] == SOFT.r)
check("the panel stays open through the cogPage's redraw, still under the cog", panel.shown
    and panel.point[2] == PageRow("Show Count").icons[1])
PanelRow("Count Size").dot.scripts.OnClick(PanelRow("Count Size").dot)
check("its dot puts that setting back", cogValues.countSize == 14)
cogStore.Set("countX", 9)
Settings.Reset(cogCard)
check("the card's Reset puts back what is set in the cog", cogValues.countX == 0 and Settings.ChangedCount(cogCard) == 0)

cogIcon = PageRow("Show Count").icons[1]
cogIcon.scripts.OnClick(cogIcon)
check("a second click on the cog closes it", not panel.shown)

-- The sidebar's search: a match set in a cog's panel.
Settings.Render(cogParent, "Test/Cogs", NOTHING, { all = {}, cards = { [cogCard.uid] = { ["Count Size"] = true } } })
check("a search hit in a cog keeps the row with the cog", PageRow("Show Count") ~= nil)
check("and opens the cog", panel.shown and panel.label == "Show Count")
panel:Hide()
Settings.Render(cogParent, "Test/Cogs", NOTHING)
local jumped, top = Settings.FindRow(cogParent, "Count X", cogCard.uid)
check("a jump to a setting in a cog goes to its row and opens the cog", jumped == PageRow("Show Count")
    and top ~= nil and panel.shown)

-- The cogPage going away closes the panel; its own redraw does not.
cogPage.scripts.OnHide(cogPage)
RunTimers()
check("the panel stays while the cogPage is still there", panel.shown)
cogPage:Hide()
cogPage.scripts.OnHide(cogPage)
RunTimers()
check("and closes once the cogPage has gone", not panel.shown)

-- A change while the cogPage is hidden draws it again as it shows.
cogStore.Set("other", true)
check("a cogPage hidden during a change is marked to draw again", cogPage.stale == true)
cogPage:Show()
cogPage.scripts.OnShow(cogPage)
check("and queues it as it shows", cogPage.settingsQueued == true and cogPage.stale == nil)
RunTimers()

-- A card drawn from another module's settings watches them too.
local otherListeners = {}
local otherStore = { Get = NOTHING, OnChange = function(fn) otherListeners[#otherListeners + 1] = fn end }
Settings.Page("Test/Watch", cogStore):Card({ id = "w", name = "W", watch = { otherStore }, rows = {
    { key = "other", label = "Other", toggle = true } } })
local watchParent = Frame()
Settings.Render(watchParent, "Test/Watch", NOTHING)
check("a card's watch listens to that store", #otherListeners == 1)
otherListeners[1]()
check("and a change there draws the cogPage again", watchParent.settingsView.settingsQueued == true)
RunTimers()

-- The stubs that remember their calls make tables of their own: measure the cogPage alone.
METHODS.SetPoint, METHODS.SetVertexColor = NOTHING, NOTHING
Settings.Render(cogParent, "Test/Cogs", NOTHING)
Measure(check)("a page with cogs and icons redrawn", 1, function() cogPage:Redraw() end)

print(("test-shared: %d checks passed"):format(checks))

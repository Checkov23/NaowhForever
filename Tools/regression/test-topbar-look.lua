-- Top Bar text: the clock keeps its own font with no outline, the FPS / MS readout and the online
-- counts keep the outlined Addon Font, until Font, Outline or Clock Outline is picked; and the card's
-- rows in the standard groups. Its look (NaowhForever_TopBar/View/Look.lua) is loaded and the card's rows cut out
-- of NaowhForever_TopBar/UI/SettingsPage.lua, run on stubs. Run from the repo root.

-- The Top Bar's files as TopBar.xml lists them, read as one source.
local parts = {}
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^NaowhForever_TopBar/.*%.lua$")) do
    local f = assert(io.open(path, "rb"))
    parts[#parts + 1] = f:read("*a"):gsub("\r\n", "\n")
    f:close()
end
local source = table.concat(parts, "\n")
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local function Slice(a, b)
    local first = assert(source:find(a, 1, true), a)
    return source:sub(first, assert(source:find(b, first + #a, true), b) - 1)
end

local code = table.concat({
    "local S, Parts, UI, ns, Group, ResetLayout = ...",
    Slice("local ROWS = {", "\nns.Shared.Settings.Page("),
    "return { ROWS = ROWS }",
}, "\n")

local defaults = {}
for key, value in source:match("UI%.ModuleSettings%(\"topBar\", (%b{})"):gmatch("(%w+) = (\"[^\"]*\")") do
    defaults[key] = loadstring("return " .. value)()
end
defaults.iconSize, defaults.sysSize, defaults.clockSize = 22, 13, 27
defaults.iconColor = { r = 1, g = 1, b = 1 }
local settings = {}
local S = { Get = function(k) if settings[k] == nil then return defaults[k] end return settings[k] end }

local OUTLINES = { { NONE = "None", [""] = "Shadow", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline" },
    { "NONE", "", "OUTLINE", "THICKOUTLINE" } }
local Parts = { HUD_OUTLINES = OUTLINES }
function Parts.HudText(fs, shadow) fs.shadow = shadow; return fs end
function Parts.HudFlags(outline) return (outline == "NONE" or type(outline) ~= "string") and "" or outline end
function Parts.HudFont(fs, font, size, outline, background)
    fs:SetFont("path:" .. font, size, outline)
    fs.shadow = outline == "" and (background or "card") or false
    return fs
end
local UI = { FontPath = function(name) return "path:" .. name end }
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, UIFontPath = function() return "path:" end,
    ThemeTint = function() return { r = 0, g = 0, b = 0 } end }

local function Text()
    return {
        SetFont = function(self, path, size, flags) self.path, self.size, self.flags = path, size, flags; return true end,
        SetTextColor = function() end,
    }
end
local function Button()
    local b = { icon = { SetSize = function() end, SetVertexColor = function() end }, badge = Text() }
    function b.SetSize() end
    function b.ClearAllPoints() end
    function b.SetPoint() end
    function b.Show() end
    return b
end

local chunk = assert(loadstring(code))
local api = chunk(S, Parts, UI, ns, function(name) return { group = name } end, function() end)

-- The real look and its constants, on the stubs above.
ns.TopBar = { Settings = S }
ns.Shared = { Style = {}, Parts = Parts }
ns.THEME = { accent = { r = 0, g = 0, b = 0 } }
ns.UI = UI
do
    local env = setmetatable({ NaowhForever = ns }, { __index = _G })
    env._G = env
    for _, path in ipairs({ "NaowhForever_TopBar/Constants.lua", "NaowhForever_TopBar/View/Style.lua", "NaowhForever_TopBar/View/Look.lua" }) do
        local fileChunk = assert(loadfile(path))
        setfenv(fileChunk, env)
        fileChunk()
    end
end
local Look = ns.TopBar.Look
local clock, sys = Text(), Text()
local group = { SetSize = function() end }
local friends, journal = Button(), Button()
journal.badge = nil
local function Paint()
    Look.ClockFont(clock)
    Look.SystemFont(sys)
    Look.Row(group, { friends, journal }, 2)
end

Paint()
check("today's clock: its own font, no outline", clock.path == "path:Gotham Narrow Ultra" and clock.size == 27
    and clock.flags == "")
check("today's readout: the Addon Font, outlined, no shadow", sys.path == "path:" and sys.size == 13
    and sys.flags == "OUTLINE" and sys.shadow == false)
check("today's counts: the Addon Font at 10, outlined", friends.badge.path == "path:" and friends.badge.size == 10
    and friends.badge.flags == "OUTLINE" and friends.badge.shadow == false)

settings.font, settings.outline = "Expressway", "THICKOUTLINE"
Paint()
check("Font and Outline reach the readout", sys.path == "path:Expressway" and sys.flags == "THICKOUTLINE")
check("and the counts", friends.badge.path == "path:Expressway" and friends.badge.flags == "THICKOUTLINE")
check("not the clock", clock.path == "path:Gotham Narrow Ultra" and clock.flags == "" and clock.shadow == false)
settings.outline = ""
Paint()
check("Shadow: the HUD shadow on the readout and counts", sys.flags == "" and sys.shadow == "card"
    and friends.badge.shadow == "card")
settings.clockOutline, settings.sysSize = "OUTLINE", 16
Paint()
check("Clock Outline outlines the clock", clock.flags == "OUTLINE")
check("FPS / MS Size sizes the readout", sys.size == 16)

local rows, groupOf, groups, current = {}, {}, {}, nil
for _, row in ipairs(api.ROWS) do
    if row.group then
        current = row.group
        groups[#groups + 1] = current
    elseif row.key then
        rows[row.key], groupOf[row.key] = row, current
    end
end
check("the standard groups after its own", table.concat(groups, ", ")
    == "Clock, Buttons, FPS / MS, Size, Text, Background, Colors, Visibility")
check("Font, Outline and the clock's under Text", groupOf.font == "Text" and groupOf.outline == "Text"
    and groupOf.clockFont == "Text" and groupOf.clockSize == "Text" and groupOf.clockOutline == "Text"
    and groupOf.sysSize == "Text")
check("Outline is the shared choice", rows.outline.choice == OUTLINES)
check("Clock Outline is the shared choice too", rows.clockOutline.choice == OUTLINES)
check("Hide In Combat and the mouseover fade under Visibility", groupOf.hideInCombat == "Visibility"
    and groupOf.mouseover == "Visibility" and groupOf.mouseoverAlpha == "Visibility")
check("the defaults are today's look", defaults.font == "" and defaults.outline == "OUTLINE"
    and defaults.clockOutline == "NONE")

-- Without the clock: one row centred as a whole, the two sides a button's gap apart in one pill.
local function Box(w)
    local b = { w = w, points = {} }
    function b.GetWidth(self) return self.w end
    function b.SetWidth(self, v) self.w = v end
    function b.ClearAllPoints(self) self.points = {} end
    function b.SetPoint(self, point, _, _, x) self.points[point] = x end
    return b
end
local frame, left, right = Box(0), Box(60), Box(90)
local clockText = { GetStringWidth = function() return 70 end }
local features = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, }
do
    local env = setmetatable({ NaowhForever = features }, { __index = _G })
    env._G = env
    local fileChunk = assert(loadfile("Core/Features.lua"))
    setfenv(fileChunk, env)
    fileChunk()
end
check("the clock is off by default", features.FEATURES.topBar.showClock == false
    and source:find("enabled = F.enabled,%s+showClock = F.showClock,") ~= nil)
Look.Fit(frame, left, right, clockText, 2, 3)
check("no clock: the row is both sides and a button's gap, no clock-sized hole", frame.w == 2 * 14 + 60 + 4 + 90
    and left.points.LEFT == 14 and right.points.RIGHT == -14)
Look.Fit(frame, left, Box(1), clockText, 2, 0)
check("no clock, one side empty: that side alone, centred", frame.w == 2 * 14 + 60 and left.points.LEFT == 14)
settings.showClock = true
Look.Fit(frame, left, right, clockText, 2, 3)
check("with the clock: both sides the widest's width round it", frame.w == 2 * (14 + 90 + 22) + 78
    and left.points.LEFT == 14 + 90 - 60 and right.points.RIGHT == -14)
settings.showClock = nil
local function Seg()
    local s = { line = {}, points = {} }
    function s.SetColorTexture() end
    function s.ClearAllPoints(self) self.points = {} end
    function s.SetPoint(self, point, rel) self.points[point] = rel end
    function s.SetShown(self, on) self.shown = on end
    function s.line.SetShown(self, on) self.shown = on end
    return s
end
defaults.bgAlpha = 85
local segs = { Seg(), Seg(), Seg() }
Look.PaintPills(frame, segs, left, right, clockText, 2, 3)
check("no clock: one pill from the left buttons to the right ones", segs[1].shown == true
    and segs[1].points.BOTTOMRIGHT == right and segs[3].shown == false and not segs[2].shown)
settings.showClock = true
Look.PaintPills(frame, segs, left, right, clockText, 2, 3)
check("with the clock: a pill each side of it", segs[1].points.BOTTOMRIGHT == left and segs[3].shown == true
    and segs[2].shown == true)
settings.showClock = nil
check("Show Clock heads the Clock group, its settings wait on it", groupOf.showClock == "Clock"
    and rows.use24h.needs == "showClock" and rows.clockFont.needs == "showClock"
    and rows.clockSize.needs == "showClock" and rows.clockOutline.needs == "showClock")

print("PASS top bar look: " .. checks .. " checks")

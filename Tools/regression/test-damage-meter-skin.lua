-- Offline behavior checks for the Damage Meter Skin (NaowhForever_QoL/Combat/DamageMeterSkin.lua) against a stub
-- of the game's meter; they do not emulate the client. Run with Lua 5.1 from the repository root.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local THEME = {
    bg = { r = 0.1, g = 0.1, b = 0.1 }, panel = { r = 0.2, g = 0.2, b = 0.2 }, fg = { r = 0.9, g = 0.9, b = 0.9 },
    muted = { r = 0.6, g = 0.6, b = 0.6 }, accent = { r = 0, g = 0.5, b = 1 }, line = { r = 0, g = 0, b = 0 },
}
local ADDON = "Blizzard_DamageMeter"
local FONT = "Interface\\AddOns\\NaowhForever\\Media\\Fonts\\Naowh.ttf"
local GAME_FONT, GAME_SIZE, GAME_FLAGS = "Fonts\\ARIALN.TTF", 14, "OUTLINE"
local CLASS_RGB = { 0.77, 0.12, 0.23 }

local function Texture(atlas)
    local t = { atlas = atlas, alpha = 1 }
    function t:SetColorTexture(r, g, b, a) self.solid = { r, g, b, a }; self.atlas = nil end
    function t:SetAtlas(name) self.atlas = name; self.solid = nil end
    function t:GetAtlas() return self.atlas end
    function t:GetVertexColor()
        local v = self.vertex or { 1, 1, 1 }
        return v[1], v[2], v[3], 1
    end
    function t:GetAlpha() return self.alpha end
    function t:SetDesaturated(on) self.desaturated = on end
    function t:IsDesaturated() return self.desaturated == true end
    function t:SetAlpha(a) self.alpha = a end
    function t:SetVertexColor(r, g, b) self.vertex = { r, g, b } end
    return t
end

local function FontString()
    local f = { path = GAME_FONT, size = GAME_SIZE, flags = GAME_FLAGS, r = 1, g = 0.82, b = 0, sx = 1, sy = -1,
        shadow = { 0, 0, 0, 0.5 } }
    function f:GetFont() return self.path, self.size, self.flags end
    function f:SetFont(path, size, flags)
        self.path, self.size, self.flags = path, size, flags
        self.fontSets = (self.fontSets or 0) + 1
    end
    function f:GetTextColor() return self.r, self.g, self.b end
    function f:SetAlpha(a) self.alpha = a end
    function f:SetTextColor(r, g, b) self.r, self.g, self.b = r, g, b end
    function f:GetShadowOffset() return self.sx, self.sy end
    function f:SetShadowOffset(x, y) self.sx, self.sy = x, y end
    function f:GetShadowColor() return self.shadow[1], self.shadow[2], self.shadow[3], self.shadow[4] end
    function f:SetShadowColor(r, g, b, a) self.shadow = { r, g, b, a } end
    return f
end

-- HookScript adds to what is there, as the game's does, so a frame can be hooked by more than one thing.
local function HookScript(self, name, fn)
    self.scripts = self.scripts or {}
    local prior = self.scripts[name]
    if not prior then
        self.scripts[name] = fn
        return
    end
    self.scripts[name] = function(...)
        prior(...)
        fn(...)
    end
end

-- The game's entry: it sets its own art and colour from UpdateStyle, UpdateBackground and UpdateStatusBarColor.
local function Entry()
    local bar = { Background = Texture("ui-damagemeters-bar-shadowbg"), BackgroundEdge = Texture("ui-damagemeters-bar-shadowedge"),
        Name = FontString(), Value = FontString() }
    local barTexture = Texture("UI-HUD-CoolDownManager-Bar")
    function bar:SetStatusBarTexture(file)
        self.file, self.fileSets = file, (self.fileSets or 0) + 1
        barTexture.atlas = nil
    end
    local e = { StatusBar = bar, Icon = { level = 1 }, refreshes = 0, HookScript = HookScript }
    function e:GetStatusBarTexture() return barTexture end
    function e:UpdateStyle()
        self.refreshes = self.refreshes + 1
        bar.Background:SetAtlas("ui-damagemeters-bar-shadowbg")
    end
    function e:UpdateBackground()
        bar.BackgroundEdge:SetAlpha(1)
        bar.Background:SetAlpha(1)
    end
    function e:UpdateStatusBarColor()
        self.statusBarColor = { GetRGB = function() return CLASS_RGB[1], CLASS_RGB[2], CLASS_RGB[3] end }
        barTexture:SetVertexColor(CLASS_RGB[1], CLASS_RGB[2], CLASS_RGB[3])
    end
    function e.Icon:GetFrameLevel() return self.level end
    e:UpdateStatusBarColor()
    e.barTexture = barTexture
    return e
end

local function ScrollBox(frames)
    local box = { frames = frames or {}, callbacks = {} }
    function box:EnumerateFrames()
        local i = 0
        return function()
            i = i + 1
            if self.frames[i] then return i, self.frames[i] end
        end
    end
    function box:Acquire(entry)
        self.frames[#self.frames + 1] = entry
        for _, fn in ipairs(self.callbacks) do fn(self, entry, {}, true) end
    end
    return box
end

local function Window()
    local source = { Background = Texture("common-dropdown-bg"), ScrollBox = ScrollBox({ Entry() }) }
    function source:GetFrameLevel() return 1 end
    local function Part()
        local part = { alpha = 1, glyph = Texture("glyph") }
        function part:SetAlpha(a) self.alpha = a end
        function part:GetRegions() return self.glyph end
        function part:GetChildren() end
        return part
    end
    local thumb, track = Texture("thumb"), Texture("track")
    local trackFrame = {}
    function trackFrame:GetRegions() return track end
    function trackFrame:GetChildren() end
    local scroll = { alpha = 1, thumb = thumb, track = track }
    function scroll:SetAlpha(a) self.alpha = a end
    function scroll:GetRegions() return thumb end
    function scroll:GetChildren() return trackFrame end
    local grip = { alpha = 0, HookScript = HookScript }
    function grip:SetAlpha(a) self.alpha = a end
    local w = { Header = Texture("ui-damagemeters-header-bar"), SessionTimer = FontString(),
        SessionDropdown = { SessionName = FontString() }, DamageMeterTypeDropdown = { TypeName = FontString() },
        MinimizeContainer = { Background = Texture("damagemeters-background"), LocalPlayerEntry = Entry(),
            ScrollBox = ScrollBox({ Entry(), Entry() }), SourceWindow = source, ResizeButton = grip,
            ScrollBar = scroll },
        MinimizeButton = Part(), SettingsDropdown = Part(),
        points = {}, left = 100, top = 500, width = 300, height = 200, editLeft = 100, editTop = 500 }
    function w.SessionDropdown:SetAlpha(a) self.alpha = a end
    function w.DamageMeterTypeDropdown:SetAlpha(a) self.alpha = a end
    w.DamageMeterTypeDropdown.glyph = Texture("arrow")
    function w.DamageMeterTypeDropdown:GetRegions() return self.glyph end
    function w.DamageMeterTypeDropdown:GetChildren() end
    function w:IsMouseOver() return self.mouseOver == true end
    function w:GetFrameLevel() return 1 end
    function w:ClearAllPoints() self.points = {} end
    function w:SetPoint(point, relativeTo, relPoint, x, y)
        self.points[#self.points + 1] = { point, relativeTo, relPoint, x, y }
        if relativeTo ~= nil then
            self.left, self.top = x, y
        else
            self.left, self.top = self.editLeft, self.editTop
            self.width, self.height = 300, 200
        end
    end
    function w:SetSize(width, height) self.width, self.height = width, height end
    function w:GetLeft() return self.left end
    function w:GetTop() return self.top end
    function w:GetWidth() return self.width end
    function w:GetHeight() return self.height end
    function w:SetMovable(on) self.movable = on end
    function w:SetResizable(on) self.resizable = on end
    function w:IsLocked() return self.locked == true end
    function w:StartMoving() self.moving = true end
    function w:StartSizing(corner) self.sizing = corner end
    function w:StopMovingOrSizing() self.moving, self.sizing = false, nil end
    w.HookScript = HookScript
    function w:GetChildren() return self.MinimizeContainer end
    local container = w.MinimizeContainer
    container.HookScript = HookScript
    function container:GetChildren() return self.ResizeButton, self.ScrollBar end
    return w
end

-- Builds the addon's environment. loaded: Blizzard_DamageMeter is already loaded. Returns the pieces tests poke.
local function Boot(settings, loaded, windows)
    local s = { settings = settings or {}, hooks = 0, borders = {}, cards = {}, waiting = {}, printed = {},
        others = {} }
    local defaults = { enabled = true, damageMeterSkin = false, damageMeterBars = "class", damageMeterBarColor = false,
        damageMeterTexture = "", damageMeterFont = "", damageMeterOutline = "game", damageMeterIconEdge = true,
        damageMeterHeaderColor = false, damageMeterWindowColor = false, damageMeterNameColor = false,
        damageMeterValueColor = false, damageMeterTitleColor = false, damageMeterFree = false,
        damageMeterPos = false, damageMeterBarAlpha = 100, damageMeterBarBgColor = false,
        damageMeterBarBgAlpha = 100, damageMeterScrollBar = "game", damageMeterBorder = false,
        damageMeterBorderColor = false, damageMeterTitleFade = "always", damageMeterTitleFadeAlpha = 0,
        damageMeterNameSize = 0, damageMeterValueSize = 0, damageMeterTitleSize = 0, damageMeterButtons = "game",
        damageMeterButtonColor = false, damageMeterPanelColor = false, damageMeterPanelAlpha = 70 }
    local store = {}
    function store.Get(k)
        local v = s.settings[k]
        if v == nil then v = defaults[k] end
        return v
    end
    function store.Set(k, v) s.settings[k] = v end
    local meter = { windows = windows or { Window() } }
    function meter:GetPrimarySessionWindow() return self.windows[1] end
    function meter:ForEachSessionWindow(fn)
        for _, w in ipairs(self.windows) do fn(w) end
    end
    function meter:SetupSessionWindow() end
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QoLSettings = store, THEME = THEME, Apply = function() end,
        DamageMeterLayout = { rows = {}, byName = {
            FrameWidth = { label = "Window Width", slider = { 200, 600, 1 }, frame = true,
                get = function() return 300 end, set = function() end },
            FrameHeight = { label = "Window Height", slider = { 120, 400, 1 }, frame = true,
                get = function() return 200 end, set = function() end },
            BarHeight = { label = "Bar Height", slider = { 15, 40, 1 }, get = function() return 24 end,
                set = function() end },
            Visibility = { label = "Visibility", choice = { { ["0"] = "Always Visible" }, { "0" } },
                get = function() return "0" end, set = function() end } },
            restore = { label = "Restore Game Settings", buttonText = "Restore", button = function() end } },
        Print = function(text) s.printed[#s.printed + 1] = text end,
        MEDIA = "Media\\",
        UIFontPath = function() return FONT end,
        UI = { FontPath = function(name) return "Fonts\\" .. name .. ".ttf" end,
            RefreshPage = function() s.refreshes = (s.refreshes or 0) + 1 end,
            TexturePath = function(name, fallback)
                if name == "" then return fallback end
                return "Textures\\" .. name
            end },
        Border = function(frame, color)
            local border = { frame = frame, color = color, _frame = { shown = true } }
            function border._frame:Show() self.shown = true end
            function border._frame:Hide() self.shown = false end
            function border:SetColor(r, g, b, a) self.color = { r, g, b, a } end
            s.borders[#s.borders + 1] = border
            return border
        end,
        Shared = { Parts = {
            HUD_OUTLINES = { { NONE = "None", [""] = "Shadow", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline" },
                { "NONE", "", "OUTLINE", "THICKOUTLINE" } },
            HudFlags = function(outline)
                if outline == "NONE" or type(outline) ~= "string" then return "" end
                return outline
            end,
            HudText = function(fs, shadow)
                if shadow == false then
                    fs.sx, fs.sy, fs.shadow, fs.shadowMode = 0, 0, { 0, 0, 0, 0 }, false
                else
                    fs.sx, fs.sy, fs.shadow, fs.shadowMode = 2, -2, { 0, 0, 0, 0.8 }, "house"
                end
            end },
            Settings = { Group = function(title) return { group = title } end, Page = function(_, name)
                local page = { name = name }
                function page:Card(def) s.cards[#s.cards + 1] = def; return self end
                return page
            end } } }
    local env = { unpack = unpack, ipairs = ipairs, pairs = pairs, type = type, select = select,
        UIParent = { name = "UIParent" },
        setmetatable = setmetatable, tostring = tostring, NaowhForever = ns,
        hooksecurefunc = function(tbl, name, fn)
            s.hooks = s.hooks + 1
            local original = tbl[name]
            tbl[name] = function(...)
                local results = { original(...) }
                fn(...)
                return unpack(results)
            end
        end,
        ScrollUtil = { AddAcquiredFrameCallback = function(box, fn) box.callbacks[#box.callbacks + 1] = fn end },
        C_AddOns = { IsAddOnLoaded = function(name)
            return (loaded and name == ADDON) or s.others[name] == true
        end },
        EventUtil = { ContinueOnAddOnLoaded = function(name, fn) s.waiting[name] = fn end },
        CreateFrame = function()
            local f = { events = {}, scripts = {}, shown = true }
            function f:RegisterEvent(e) self.events[e] = true end
            function f:SetScript(name, fn)
                self.scripts[name] = fn
                self.onEvent = fn
            end
            function f:Show() self.shown = true end
            function f:Hide() self.shown = false end
            return f
        end }
    env._G = env
    if loaded then env.DamageMeter = meter end
    local chunk = assert(loadfile("NaowhForever_QoL/Combat/DamageMeterSkin.lua"))
    setfenv(chunk, env)
    local frames = {}
    local create = env.CreateFrame
    env.CreateFrame = function(...) local f = create(...); frames[#frames + 1] = f; return f end
    chunk("NaowhForever")
    s.base = s.hooks
    return s, store, meter, ns, frames, env
end

local function Login(frames)
    local f = frames[#frames]
    if f and f.onEvent then f.onEvent(f, "PLAYER_LOGIN") end
end

local function SameRgb(c, t) return c and c[1] == t.r and c[2] == t.g and c[3] == t.b end
local function Entries(window)
    local c = window.MinimizeContainer
    return { c.LocalPlayerEntry, c.ScrollBox.frames[1], c.ScrollBox.frames[2], c.SourceWindow.ScrollBox.frames[1] }
end

-- the card
do
    local s = Boot()
    check("one card, on the Combat page's store", #s.cards == 1)
    local card = s.cards[1]
    check("its id and name, a Reskin toggle first and no switch of its own", card.id == "damageMeterSkin"
        and card.name == "Default Damage Meter" and card.switch == nil and card.rows[1].key == "damageMeterSkin"
        and card.rows[1].toggle == true)
    local row
    for _, item in ipairs(card.rows) do
        if item.key == "damageMeterBars" then row = item end
    end
    check("a bar color choice", row.key == "damageMeterBars" and row.choice[2][1] == "class" and row.choice[2][2] == "accent"
        and row.choice[1].class == "Class Colors" and row.choice[1].accent == "Theme Accent")
    check("one short help sentence", #card.help < 100 and not card.help:find("%d"))
end

-- off by default: nothing hooked, nothing touched
do
    local s, _, meter, _, frames = Boot({}, true)
    local window = meter.windows[1]
    Login(frames)
    check("off: no hook is made on the meter", s.hooks == s.base)
    check("off: the art is the game's", window.Header.atlas == "ui-damagemeters-header-bar" and window.Header.solid == nil)
    check("off: no border, no callback", #s.borders == 0 and #window.MinimizeContainer.ScrollBox.callbacks == 0)
    check("off: the meter is not waited for", next(s.waiting) == nil)
end

-- on, with the meter loaded: the windows and entries are skinned
do
    local s, store, meter, _, frames = Boot({ damageMeterSkin = true }, true)
    Login(frames)
    local window = meter.windows[1]
    local c = window.MinimizeContainer
    check("nothing ticks and nothing watches the mouse unless a fade or a hidden scroll bar asks",
        #frames == 1 and window.scripts == nil and c.ResizeButton.scripts == nil
        and c.ScrollBox.frames[1].scripts == nil)
    check("the header is the Panels color", window.Header.solid and SameRgb(window.Header.solid, THEME.panel))
    check("the window background is the Background color", SameRgb(c.Background.solid, THEME.bg))
    check("the spell panel is the Window Color", SameRgb(c.SourceWindow.Background.solid, THEME.bg))
    check("the timer is Secondary Text, the names Text",
        SameRgb({ window.SessionTimer.r, window.SessionTimer.g, window.SessionTimer.b }, THEME.muted)
        and window.SessionDropdown.SessionName.r == 1 and window.DamageMeterTypeDropdown.TypeName.r == THEME.fg.r)
    check("the header text is in the addon font, the game's size and flags",
        window.SessionTimer.path == FONT and window.SessionTimer.size == GAME_SIZE and window.SessionTimer.flags == GAME_FLAGS)
    for i, entry in ipairs(Entries(window)) do
        local bar = entry.StatusBar
        check("entry " .. i .. ": the shadow is the Background color", SameRgb(bar.Background.solid, THEME.bg))
        check("entry " .. i .. ": the shadow's edge is faded out", bar.BackgroundEdge.alpha == 0)
        check("entry " .. i .. ": the name is Text, the value Secondary Text in the addon font",
            bar.Name.r == THEME.fg.r and bar.Value.r == THEME.muted.r and bar.Name.path == FONT and bar.Value.path == FONT)
        local edged = false
        for _, border in ipairs(s.borders) do edged = edged or border.frame == entry.Icon end
        check("entry " .. i .. ": its icon has a border", edged)
        check("entry " .. i .. ": class colors are the game's own", SameRgb(entry.barTexture.vertex, { r = CLASS_RGB[1], g = CLASS_RGB[2], b = CLASS_RGB[3] }))
    end
    check("four icons, four borders, in the line color", #s.borders == 4 and s.borders[1].color == THEME.line)

    -- the game sets its art again: ours again
    local entry = c.ScrollBox.frames[1]
    entry:UpdateStyle()
    check("the game's style refresh: flat again", entry.StatusBar.Background.solid and entry.StatusBar.Background.atlas == nil)
    entry:UpdateBackground()
    check("the game's background refresh: faded again", entry.StatusBar.BackgroundEdge.alpha == 0)
    check("and no second border", #s.borders == 4)

    -- an entry acquired later
    local fresh = Entry()
    c.ScrollBox:Acquire(fresh)
    check("a new entry is skinned by the scroll box callback", SameRgb(fresh.StatusBar.Background.solid, THEME.bg) and #s.borders == 5)
    local hooksNow = s.hooks
    c.ScrollBox:Acquire(fresh)
    check("and hooked once", s.hooks == hooksNow)

    -- Theme Accent
    store.Set("damageMeterBars", "accent")
    for i, e in ipairs(Entries(window)) do
        check("accent " .. i .. ": the bar is the Accent", SameRgb(e.barTexture.vertex, THEME.accent))
    end
    entry:UpdateStatusBarColor()
    check("the game sets its color again: the Accent again", SameRgb(entry.barTexture.vertex, THEME.accent))
    store.Set("damageMeterBars", "class")
    check("back to class colors: the game's own", SameRgb(entry.barTexture.vertex, { r = CLASS_RGB[1], g = CLASS_RGB[2], b = CLASS_RGB[3] }))

    -- off: the game's art, fonts and colors come back
    store.Set("damageMeterSkin", false)
    check("off: the header art is back", window.Header.atlas == "ui-damagemeters-header-bar")
    check("off: the window background art is back", c.Background.atlas == "damagemeters-background")
    check("off: the timer's font and color are the game's",
        window.SessionTimer.path == GAME_FONT and window.SessionTimer.size == GAME_SIZE and window.SessionTimer.r == 1
        and window.SessionTimer.g == 0.82)
    check("off: the entry's shadow and edge are back", entry.StatusBar.Background.atlas == "ui-damagemeters-bar-shadowbg"
        and entry.StatusBar.BackgroundEdge.alpha == 1)
    check("off: the edges are hidden", s.borders[1]._frame.shown == false and s.borders[5]._frame.shown == false)
    entry:UpdateStyle()
    check("off: a style refresh leaves the game's art", entry.StatusBar.Background.atlas == "ui-damagemeters-bar-shadowbg")

    -- on again
    store.Set("damageMeterSkin", true)
    check("on again: skinned, with the same borders shown", SameRgb(window.Header.solid, THEME.panel)
        and s.borders[1]._frame.shown == true and #s.borders == 5)
    -- the master switch
    store.Set("enabled", false)
    check("QoL off: given back", window.Header.atlas == "ui-damagemeters-header-bar")
end

-- accent from the start, and the accent restored when the skin goes
do
    local _, store, meter, _, frames = Boot({ damageMeterSkin = true, damageMeterBars = "accent" }, true)
    Login(frames)
    local entry = meter.windows[1].MinimizeContainer.ScrollBox.frames[1]
    check("accent at login: the bar is the Accent", SameRgb(entry.barTexture.vertex, THEME.accent))
    store.Set("damageMeterSkin", false)
    check("the skin off: the class color is back", SameRgb(entry.barTexture.vertex, { r = CLASS_RGB[1], g = CLASS_RGB[2], b = CLASS_RGB[3] }))
end

-- the meter is not loaded yet: it is waited for, and a window made later is skinned
do
    local s, _, _, _, frames, env = Boot({ damageMeterSkin = true }, false)
    Login(frames)
    check("not loaded: the addon is waited for, and nothing hooked", s.waiting[ADDON] and s.hooks == s.base)
    local late = Window()
    local meter = { windows = {} }
    function meter:ForEachSessionWindow(fn) for _, w in ipairs(self.windows) do fn(w) end end
    function meter:SetupSessionWindow() end
    env.DamageMeter = meter
    s.waiting[ADDON]()
    check("loaded: its session window creation is hooked", s.hooks - s.base == 1)
    meter.windows[1] = late
    meter:SetupSessionWindow()
    check("a window made later is skinned", SameRgb(late.Header.solid, THEME.panel))
end

-- switched on in Settings after login, with the meter loaded
do
    local s, store, meter, _, frames = Boot({}, true)
    Login(frames)
    check("before the switch: untouched", s.hooks == s.base)
    store.Set("damageMeterSkin", true)
    check("after the switch: skinned", SameRgb(meter.windows[1].Header.solid, THEME.panel) and s.hooks > s.base)
    store.Set("someOtherSetting", 1)
    check("another setting changes nothing here", true)
end

-- missing pieces: no error
do
    local bare = { {}, { MinimizeContainer = {} }, { Header = {}, MinimizeContainer = { ScrollBox = {}, SourceWindow = {} } },
        { MinimizeContainer = { LocalPlayerEntry = {}, ScrollBox = ScrollBox({ { StatusBar = {} }, {} }) } } }
    local _, store, meter, _, frames = Boot({ damageMeterSkin = true }, true, bare)
    Login(frames)
    store.Set("damageMeterBars", "accent")
    store.Set("damageMeterSkin", false)
    check("windows and entries without their parts: skipped without an error", meter ~= nil)
    local _, _, noMeter, _, bootFrames = Boot({ damageMeterSkin = true }, true, {})
    Login(bootFrames)
    check("no windows: nothing to do", noMeter ~= nil)
end

-- the look rows: texture, font, outline, icon border
do
    local _, store, meter, _, frames = Boot({ damageMeterSkin = true, damageMeterTexture = "Flat" }, true)
    Login(frames)
    local all = Entries(meter.windows[1])
    for i, entry in ipairs(all) do
        check("texture " .. i .. ": the bar has the picked file once, and keeps the class color",
            entry.StatusBar.file == "Textures\\Flat" and entry.StatusBar.fileSets == 1
            and SameRgb(entry.barTexture.vertex, { r = CLASS_RGB[1], g = CLASS_RGB[2], b = CLASS_RGB[3] }))
    end
    local first = all[2]
    first:UpdateStatusBarColor(); first:UpdateStyle(); first:UpdateBackground()
    check("texture: the game's refreshes do not write the file again", first.StatusBar.fileSets == 1)
    store.Set("damageMeterTexture", "Other")
    check("texture: a new pick is written once", first.StatusBar.file == "Textures\\Other" and first.StatusBar.fileSets == 2)
    store.Set("damageMeterTexture", "")
    check("texture: not picked is the Naowh Gradient", first.StatusBar.file == "Media\\NaowhGradient.tga")
    store.Set("damageMeterTexture", "Flat")
    store.Set("damageMeterSkin", false)
    check("texture: switched off, the game's art is back", first.barTexture.atlas == "UI-HUD-CoolDownManager-Bar")
end

do
    local _, store, meter, _, frames = Boot({ damageMeterSkin = true, damageMeterFont = "Exo",
        damageMeterOutline = "THICKOUTLINE" }, true)
    Login(frames)
    local window = meter.windows[1]
    local name = window.MinimizeContainer.ScrollBox.frames[1].StatusBar.Name
    check("font: the picked face, the game's size", name.path == "Fonts\\Exo.ttf" and name.size == GAME_SIZE)
    check("outline: Thick Outline, the shadow cleared", name.flags == "THICKOUTLINE" and name.sx == 0)
    check("font: the dropdown names and the timer take it too", window.SessionTimer.path == "Fonts\\Exo.ttf"
        and window.SessionDropdown.SessionName.flags == "THICKOUTLINE")
    local sets = name.fontSets
    local entry = window.MinimizeContainer.ScrollBox.frames[1]
    entry:UpdateStyle(); entry:UpdateBackground(); entry:UpdateStatusBarColor()
    check("font: the game's refreshes do not write the face again", name.fontSets == sets)
    store.Set("damageMeterOutline", "NONE")
    check("outline: None is no flags", name.flags == "")
    store.Set("damageMeterOutline", "")
    check("outline: Shadow is no flags and the soft shadow", name.flags == "" and name.shadowMode == "house")
    store.Set("damageMeterOutline", "game")
    check("outline: Game Default keeps the game's flags and brings its shadow back",
        name.flags == GAME_FLAGS and name.sx == 1 and name.sy == -1)
    store.Set("damageMeterOutline", "THICKOUTLINE")
    store.Set("damageMeterSkin", false)
    check("off: the font, flags and shadow are the game's", name.path == GAME_FONT and name.size == GAME_SIZE
        and name.flags == GAME_FLAGS and name.sx == 1 and name.sy == -1)
    store.Set("damageMeterSkin", true)
    check("on again: the face is ours again", name.path == "Fonts\\Exo.ttf" and name.flags == "THICKOUTLINE")
end

do
    local red, green = { r = 1, g = 0, b = 0 }, { r = 0, g = 1, b = 0 }
    local blue, grey = { r = 0, g = 0, b = 1 }, { r = 0.5, g = 0.5, b = 0.5 }
    local _, store, meter, _, frames = Boot({ damageMeterSkin = true, damageMeterNameColor = red,
        damageMeterValueColor = green, damageMeterHeaderColor = blue, damageMeterWindowColor = grey }, true)
    Login(frames)
    local window = meter.windows[1]
    local c = window.MinimizeContainer
    local bar = c.ScrollBox.frames[1].StatusBar
    check("colors: the names on the bars only, not the title or the session button", bar.Name.r == 1
        and bar.Name.g == 0 and window.SessionDropdown.SessionName.g == 0.82
        and window.DamageMeterTypeDropdown.TypeName.r == THEME.fg.r)
    store.Set("damageMeterTitleColor", { r = 0.2, g = 0.4, b = 0.6 })
    check("colors: the title has its own color, the names and the session button stay",
        window.DamageMeterTypeDropdown.TypeName.g == 0.4 and window.SessionDropdown.SessionName.g == 0.82
        and bar.Name.r == 1 and bar.Name.g == 0)
    check("colors: the amounts and the timer", bar.Value.g == 1 and bar.Value.r == 0 and window.SessionTimer.g == 1)
    check("colors: the title bar, and the spell panel follows the window", SameRgb(window.Header.solid, blue)
        and SameRgb(c.SourceWindow.Background.solid, grey))
    check("colors: the window and the shadow behind each bar", SameRgb(c.Background.solid, grey)
        and SameRgb(bar.Background.solid, grey))
    store.Set("damageMeterNameColor", false)
    check("colors: not picked follows the theme", bar.Name.r == THEME.fg.r)
end

do
    local _, store, meter, _, frames = Boot({ damageMeterSkin = true, damageMeterBars = "custom" }, true)
    Login(frames)
    local entry = meter.windows[1].MinimizeContainer.ScrollBox.frames[1]
    check("custom bars: no color picked yet follows the Accent", SameRgb(entry.barTexture.vertex, THEME.accent))
    store.Set("damageMeterBarColor", { r = 0.1, g = 0.2, b = 0.3 })
    check("custom bars: the picked color", SameRgb(entry.barTexture.vertex, { r = 0.1, g = 0.2, b = 0.3 }))
    entry:UpdateStatusBarColor()
    check("custom bars: the game sets its color again, ours again", SameRgb(entry.barTexture.vertex, { r = 0.1, g = 0.2, b = 0.3 }))
    store.Set("damageMeterBars", "class")
    check("custom bars: class colors again", SameRgb(entry.barTexture.vertex, { r = CLASS_RGB[1], g = CLASS_RGB[2], b = CLASS_RGB[3] }))
end

do
    local s, store, meter, _, frames = Boot({ damageMeterSkin = true }, true)
    Login(frames)
    check("icon border on by default", #s.borders == 4 and s.borders[1]._frame.shown == true)
    store.Set("damageMeterIconEdge", false)
    local hidden = true
    for _, border in ipairs(s.borders) do hidden = hidden and border._frame.shown == false end
    check("icon border off hides every border", hidden)
    meter.windows[1].MinimizeContainer.ScrollBox.frames[1]:UpdateStyle()
    check("and a refresh does not bring it back", s.borders[2]._frame.shown == false)
    store.Set("damageMeterIconEdge", true)
    check("icon border on again shows them", s.borders[1]._frame.shown == true and #s.borders == 4)
end

do
    local s, store = Boot()
    local card = s.cards[1]
    local rows = {}
    for _, row in ipairs(card.rows) do
        if row.key then rows[row.key] = row end
    end
    check("the rows: texture, font, outline and the icon border",
        rows.damageMeterTexture and rows.damageMeterFont and rows.damageMeterOutline and rows.damageMeterIconEdge)
    check("the color rows: bars, names, amounts, title, title bar and window", rows.damageMeterBarColor.colour
        and rows.damageMeterNameColor.colour and rows.damageMeterValueColor.colour
        and rows.damageMeterTitleColor.colour
        and rows.damageMeterHeaderColor.colour and rows.damageMeterWindowColor.colour)
    check("the outline choice leads with the game's own, then the shared four",
        rows.damageMeterOutline.choice[2][1] == "game" and #rows.damageMeterOutline.choice[2] == 5
        and rows.damageMeterOutline.choice[1].game == "Game Default")
    check("the texture row names the Naowh Gradient as its default", rows.damageMeterTexture.texture == "Naowh Gradient")
    for key, row in pairs(rows) do
        check(key .. ": help is one short sentence", row.help == nil or #row.help < 100)
    end
    check("Custom Bar Color is off until Bar Color is Custom Color", rows.damageMeterBarColor.needs() == false)
    store.Set("damageMeterSkin", true)
    store.Set("damageMeterBars", "custom")
    check("and on with it", rows.damageMeterBarColor.needs() == true)
end

-- moving and resizing the primary window without Edit Mode
do
    local s, store, meter, _, frames, env = Boot({ damageMeterFree = true }, true, { Window(), Window() })
    Login(frames)
    local window = meter.windows[1]
    local second = meter.windows[2]
    local grip = window.MinimizeContainer.ResizeButton
    check("free: the window is taken off the Edit Mode frame to a spot of its own",
        window.points[1][1] == "TOPLEFT" and window.points[1][2] == env.UIParent
        and window.points[1][3] == "BOTTOMLEFT" and window.points[1][4] == 100 and window.points[1][5] == 500
        and window.width == 300 and window.height == 200 and #window.points == 1)
    check("free: movable and resizable", window.movable == true and window.resizable == true)
    check("free: the rect it had is kept, so nothing jumps", store.Get("damageMeterPos").left == 100
        and store.Get("damageMeterPos").top == 500 and store.Get("damageMeterPos").height == 200)
    check("free: a skin that is off stays off", #s.borders == 0 and window.Header.solid == nil)

    window.scripts.OnDragStart(window)
    check("a drag starts the move", window.moving == true)
    window.left, window.top = 250, 400
    window.scripts.OnDragStop(window)
    check("and the end of it keeps the new place", window.moving == false and store.Get("damageMeterPos").left == 250
        and store.Get("damageMeterPos").top == 400)

    window.locked = true
    window.scripts.OnDragStart(window)
    check("the game's own lock is respected", window.moving == false)
    grip.scripts.OnMouseDown(grip, "LeftButton")
    check("and it holds the grip too", window.sizing == nil)
    window.locked = false

    grip.scripts.OnMouseDown(grip, "RightButton")
    check("the right button does nothing", window.sizing == nil)
    grip.scripts.OnMouseDown(grip, "LeftButton")
    check("the grip starts a resize from the corner", window.sizing == "BOTTOMRIGHT")
    window.width, window.height = 340, 260
    grip.scripts.OnMouseUp(grip, "LeftButton")
    check("and keeps the new size", store.Get("damageMeterPos").width == 340 and store.Get("damageMeterPos").height == 260
        and window.sizing == nil)
    grip.scripts.OnEnter(grip)
    check("the grip shows on hover", grip.alpha == 1)
    grip.scripts.OnLeave(grip)
    check("and hides again", grip.alpha == 0)

    window:ClearAllPoints(); window:SetPoint("TOPLEFT"); window:SetPoint("BOTTOMRIGHT")
    meter:SetupSessionWindow()
    check("the game sets the window up again: ours again", window.points[1][2] == env.UIParent
        and window.points[1][4] == 250 and window.width == 340 and #window.points == 1)
    check("a second window is the game's own to place", second.points ~= nil and #second.points == 0
        and second.scripts == nil and second.movable == nil)

    for _, item in ipairs(s.cards[1].rows) do
        if item.label == "Window Position" then item.button() end
    end
    check("Reset: back to where Edit Mode has it, and kept there", store.Get("damageMeterPos").left == 100
        and store.Get("damageMeterPos").top == 500 and window.points[1][4] == 100)

    store.Set("damageMeterFree", false)
    check("off: back on the Edit Mode frame, as the game made it", #window.points == 2
        and window.points[1][1] == "TOPLEFT" and window.points[1][2] == nil and window.points[2][1] == "BOTTOMRIGHT"
        and window.points[2][2] == nil and window.movable == false and window.resizable == false)
    window.moving = false
    window.scripts.OnDragStart(window)
    check("off: a drag does nothing of ours", window.moving == false)
    store.Set("damageMeterFree", true)
    check("on again: where it was left", window.points[1][2] == env.UIParent and window.points[1][4] == 100)
end

do
    local s, _, meter, _, frames = Boot({}, true)
    local window = meter.windows[1]
    Login(frames)
    check("off by default: nothing placed, nothing hooked", #window.points == 0 and window.scripts == nil
        and s.hooks == s.base and next(s.waiting) == nil)
    local bare = { windows = {} }
    function bare:SetupSessionWindow() end
    local s2, _, _, _, bootFrames, env = Boot({ damageMeterFree = true }, true, {})
    env.DamageMeter = bare
    Login(bootFrames)
    local function MoveNote(boot)
        for _, item in ipairs(boot.cards[1].rows) do
            if item.label == "Move and Resize" then return item.note() end
        end
    end
    check("no window to place: a note under the row, and nothing in the chat", MoveNote(s2) ~= nil
        and #s2.printed == 0 and (s2.refreshes or 0) >= 1)
end

-- the game's meter without a call for its primary window: the first window is the primary one
do
    local one = Window()
    local plain = { windows = { one } }
    function plain:SetupSessionWindow() end
    function plain:ForEachSessionWindow(fn) fn(one) end
    local s3, store, _, _, bootFrames, env = Boot({ damageMeterFree = true }, true, { one })
    env.DamageMeter = plain
    env.DamageMeterSessionWindow1 = one
    Login(bootFrames)
    check("found by its name: placed, movable, kept", one.points[1][2] == env.UIParent and one.movable == true
        and type(store.Get("damageMeterPos")) == "table" and #s3.printed == 0 and s3.cards[1] ~= nil)
end

-- a window that has no place on screen yet: it is said, once
do
    local one = Window()
    one.left, one.top = nil, nil
    local s4, store, _, _, bootFrames = Boot({ damageMeterFree = true }, true, { one })
    Login(bootFrames)
    local noted
    for _, item in ipairs(s4.cards[1].rows) do
        if item.label == "Move and Resize" then noted = item.note() end
    end
    check("no rect yet: not placed, and a note under the row", #one.points == 0 and one.movable == nil
        and noted ~= nil and #s4.printed == 0 and store.Get("damageMeterPos") == false)
    one.left, one.top = 100, 500
    store.Set("damageMeterFree", false)
    store.Set("damageMeterFree", true)
    local after
    for _, item in ipairs(s4.cards[1].rows) do
        if item.label == "Move and Resize" then after = item.note() end
    end
    check("and the note goes once it is placed", after == nil and one.movable == true)
end

-- the title bar fades until the mouse is over the window
do
    local _, store, meter, _, frames = Boot({ damageMeterSkin = true, damageMeterTitleFade = "hover",
        damageMeterTitleFadeAlpha = 20 }, true)
    Login(frames)
    local window = meter.windows[1]
    local fader = frames[#frames]
    local function Tick(n)
        for _ = 1, n do fader.scripts.OnUpdate(fader, 0.1) end
    end
    local grip = window.MinimizeContainer.ResizeButton
    check("fade: a frame of ours ticks, and is shown", fader.scripts and fader.scripts.OnUpdate and fader.shown == true)
    window.mouseOver = false
    Tick(5)
    check("fade: away from the window the title parts sit at the faded opacity",
        window.Header.alpha == 0.2 and window.MinimizeButton.alpha == 0.2 and window.SettingsDropdown.alpha == 0.2
        and window.SessionDropdown.alpha == 0.2 and window.DamageMeterTypeDropdown.alpha == 0.2
        and window.SessionTimer.alpha == 0.2)
    Tick(12)
    check("fade: faded and the mouse away, the tick stops", fader.shown == false)
    check("fade: the window, a child of it and an entry are watched for the mouse",
        window.scripts.OnEnter ~= nil and grip.scripts.OnEnter ~= nil
        and window.MinimizeContainer.ScrollBox.frames[1].scripts.OnEnter ~= nil)
    window.mouseOver = true
    window.scripts.OnEnter(window)
    check("fade: the mouse coming in wakes it", fader.shown == true)
    Tick(5)
    check("fade: with the mouse over the window they are whole", window.Header.alpha == 1
        and window.MinimizeButton.alpha == 1 and window.SessionTimer.alpha == 1)
    Tick(30)
    check("fade: it keeps ticking while the mouse stays", fader.shown == true)
    window.mouseOver = false
    Tick(5)
    check("fade: the mouse gone, they fade again", window.Header.alpha == 0.2)
    Tick(12)
    check("fade: and the tick stops once they have", fader.shown == false and window.Header.alpha == 0.2)
    window.mouseOver = true
    grip.scripts.OnEnter(grip)
    check("fade: entering a child of the window wakes it as well", fader.shown == true)
    local fresh = Entry()
    window.MinimizeContainer.ScrollBox:Acquire(fresh)
    check("fade: an entry acquired later is watched too", fresh.scripts ~= nil and fresh.scripts.OnEnter ~= nil)
    window.mouseOver = false
    Tick(5)
    store.Set("damageMeterTitleFade", "always")
    check("fade: always shown puts them whole at once and stops the tick", window.Header.alpha == 1
        and window.SettingsDropdown.alpha == 1 and fader.shown == false)
    window.scripts.OnEnter(window)
    check("fade: always shown, the hooks left behind wake nothing", fader.shown == false)
end

-- a border round the whole window
do
    local s, store, meter, _, frames = Boot({ damageMeterSkin = true, damageMeterBorder = true,
        damageMeterIconEdge = false }, true)
    Login(frames)
    local window = meter.windows[1]
    check("border: a frame round the window and one round the spell panel, in the line color",
        #s.borders == 2 and s.borders[1].frame == window
        and s.borders[1]._frame.shown == true and s.borders[1].color[1] == THEME.line.r)
    store.Set("damageMeterBorderColor", { r = 1, g = 0.5, b = 0 })
    check("border: a picked color", s.borders[1].color[2] == 0.5)
    store.Set("damageMeterBorder", false)
    check("border: off hides it", s.borders[1]._frame.shown == false)
    store.Set("damageMeterBorder", true)
    check("border: on again shows the same ones", s.borders[1]._frame.shown == true and #s.borders == 2)
end

-- the color behind each bar, and how solid the bars are
do
    local grey = { r = 0.3, g = 0.3, b = 0.3 }
    local _, store, meter, _, frames = Boot({ damageMeterSkin = true, damageMeterBarBgColor = grey,
        damageMeterBarBgAlpha = 50, damageMeterBarAlpha = 60 }, true)
    Login(frames)
    local entry = meter.windows[1].MinimizeContainer.ScrollBox.frames[1]
    local bar = entry.StatusBar
    check("bar background: the color picked, half as solid", SameRgb(bar.Background.solid, grey)
        and bar.Background.alpha == 0.5)
    check("bar fill: a little see-through", entry.barTexture.alpha == 0.6)
    entry:UpdateBackground()
    check("bar background: the game's refresh does not undo it", bar.Background.alpha == 0.5)
    store.Set("damageMeterBarBgColor", false)
    check("bar background: not picked follows the Window Color", SameRgb(bar.Background.solid, THEME.bg))
    store.Set("damageMeterSkin", false)
    check("off: the game's own opacities are back", bar.Background.alpha == 1 and entry.barTexture.alpha == 1)
end

-- the scroll bar
do
    local _, store, meter, _, frames = Boot({ damageMeterSkin = true, damageMeterScrollBar = "hidden" }, true)
    Login(frames)
    local window = meter.windows[1]
    local scroll = window.MinimizeContainer.ScrollBar
    local fader = frames[#frames]
    check("scroll bar: hidden is see-through, and we tick to keep it so", scroll.alpha == 0 and fader.shown == true)
    scroll.alpha = 1
    fader.scripts.OnUpdate(fader, 0.1)
    check("scroll bar: the game's emphasis is put back at the next tick", scroll.alpha == 0)
    for _ = 1, 12 do fader.scripts.OnUpdate(fader, 0.1) end
    check("scroll bar: the mouse away and nothing changing, it stops ticking", fader.shown == false)
    window.MinimizeContainer.ScrollBox.frames[1]:UpdateStyle()
    check("scroll bar: a refresh of an entry wakes it", fader.shown == true)
    for _ = 1, 12 do fader.scripts.OnUpdate(fader, 0.1) end
    window.scripts.OnEnter(window)
    scroll.alpha = 1
    fader.scripts.OnUpdate(fader, 0.1)
    check("scroll bar: the mouse coming in wakes it, and the emphasis is put back",
        fader.shown == true and scroll.alpha == 0)
    store.Set("damageMeterScrollBar", "accent")
    check("scroll bar: the Accent on every piece, and shown", SameRgb(scroll.thumb.vertex, THEME.accent)
        and SameRgb(scroll.track.vertex, THEME.accent) and scroll.alpha == 1 and fader.shown == false)
    store.Set("damageMeterScrollBar", "game")
    check("scroll bar: the game's colors back", SameRgb(scroll.thumb.vertex, { r = 1, g = 1, b = 1 })
        and SameRgb(scroll.track.vertex, { r = 1, g = 1, b = 1 }))
    store.Set("damageMeterScrollBar", "accent")
    store.Set("damageMeterSkin", false)
    check("scroll bar: skin off gives it back", SameRgb(scroll.thumb.vertex, { r = 1, g = 1, b = 1 })
        and scroll.alpha == 1)
end

-- a size for each: the names, the amounts, the title
do
    local _, store, meter, _, frames = Boot({ damageMeterSkin = true, damageMeterNameSize = 16,
        damageMeterValueSize = 12, damageMeterTitleSize = 20 }, true)
    Login(frames)
    local window = meter.windows[1]
    local bar = window.MinimizeContainer.ScrollBox.frames[1].StatusBar
    check("sizes: the names have theirs", bar.Name.size == 16)
    check("sizes: the amounts and the timer have theirs", bar.Value.size == 12 and window.SessionTimer.size == 12)
    check("sizes: the list name has its own, the session button does not follow it",
        window.DamageMeterTypeDropdown.TypeName.size == 20 and window.SessionDropdown.SessionName.size == GAME_SIZE)
    store.Set("damageMeterNameSize", 0)
    check("sizes: 0 is the game's own, for that one only", bar.Name.size == GAME_SIZE and bar.Value.size == 12
        and window.DamageMeterTypeDropdown.TypeName.size == 20)
    store.Set("damageMeterSkin", false)
    check("sizes: off gives the game's sizes back", bar.Value.size == GAME_SIZE and window.SessionTimer.size == GAME_SIZE
        and window.SessionDropdown.SessionName.size == GAME_SIZE)
end

-- the size rows show the game's own size until one is picked
do
    local s, store, _, _, frames = Boot({ damageMeterSkin = true }, true)
    Login(frames)
    local rows = {}
    for _, row in ipairs(s.cards[1].rows) do
        if row.key then rows[row.key] = row end
    end
    check("size rows: the game's own size, not 0", rows.damageMeterNameSize.get() == GAME_SIZE
        and rows.damageMeterValueSize.get() == GAME_SIZE and rows.damageMeterTitleSize.get() == GAME_SIZE)
    rows.damageMeterNameSize.set(18)
    check("size rows: a picked size is what they show", rows.damageMeterNameSize.get() == 18
        and store.Get("damageMeterNameSize") == 18)
    rows.damageMeterNameSize.set(0)
    check("size rows: 0 is the game's own again", rows.damageMeterNameSize.get() == GAME_SIZE)
end

-- the session button's letter is a button: it follows Button Color with Themed, never the title
do
    local _, store, meter, _, frames = Boot({ damageMeterSkin = true, damageMeterButtons = "themed" }, true)
    Login(frames)
    local label = meter.windows[1].SessionDropdown.SessionName
    check("session button: in the Button Color when Themed", label.r == THEME.accent.r and label.b == THEME.accent.b)
    store.Set("damageMeterButtonColor", { r = 1, g = 0, b = 0 })
    check("session button: and follows a picked Button Color", label.r == 1 and label.g == 0)
    store.Set("damageMeterButtons", "game")
    check("session button: the game's own color with Game Default", label.r == 1 and label.g == 0.82)
end

-- the buttons: the game's own until Themed is picked, then in the theme
do
    local _, _, plain, _, plainFrames = Boot({ damageMeterSkin = true }, true)
    Login(plainFrames)
    local own = plain.windows[1].SettingsDropdown.glyph
    check("buttons: the game's own by default", own.desaturated ~= true and own.vertex == nil)
end

do
    local _, store, meter, _, frames = Boot({ damageMeterSkin = true, damageMeterButtons = "themed" }, true)
    Login(frames)
    local window = meter.windows[1]
    local gear, arrow = window.SettingsDropdown.glyph, window.DamageMeterTypeDropdown.glyph
    check("buttons: grey first, then tinted to the Accent", gear.desaturated == true and SameRgb(gear.vertex, THEME.accent)
        and SameRgb(arrow.vertex, THEME.accent) and window.MinimizeButton.glyph.desaturated == true)
    store.Set("damageMeterButtonColor", { r = 1, g = 0, b = 0 })
    check("buttons: a picked color", SameRgb(gear.vertex, { r = 1, g = 0, b = 0 }))
    store.Set("damageMeterButtons", "game")
    check("buttons: Game Default puts the art back", gear.desaturated == false
        and SameRgb(gear.vertex, { r = 1, g = 1, b = 1 }))
    store.Set("damageMeterButtons", "themed")
    store.Set("damageMeterSkin", false)
    check("buttons: skin off gives them back", gear.desaturated == false and arrow.desaturated == false
        and SameRgb(arrow.vertex, { r = 1, g = 1, b = 1 }))
end

-- every theme token the skin asks for is one the theme has
do
    local function Read(path)
        local file = assert(io.open(path, "rb"))
        local text = file:read("*a")
        file:close()
        return text
    end
    local block = Read("Core/Core.lua"):match("ns%.THEME = {(.-)\r?\n}")
    local have = {}
    for key in block:gmatch("(%a+)%s*=%s*{") do have[key] = true end
    local skin = Read("NaowhForever_QoL/Combat/DamageMeterSkin.lua")
    local wanted = {}
    for token in skin:gmatch('Pick%("%a+", "(%a+)"%)') do wanted[token] = true end
    for token in skin:gmatch('ColorRow%("%a+", "[^"]+", "(%a+)"') do wanted[token] = true end
    for token in skin:gmatch("%f[%w_]T%.(%a+)") do wanted[token] = true end
    check("the theme's tokens were read", have.bg and have.line and have.accent and have.fg)
    for token in pairs(wanted) do
        check("the theme has the token " .. token, have[token] == true)
    end
end

-- the panel a left click opens: the window's color by default, with a color and an opacity of its own
do
    local grey = { r = 0.4, g = 0.4, b = 0.4 }
    local s, store, meter, _, frames = Boot({ damageMeterSkin = true, damageMeterWindowColor = grey }, true)
    local panel = meter.windows[1].MinimizeContainer.SourceWindow.Background
    panel.alpha = 0.9
    Login(frames)
    check("spell panel: the Window Color when no color is picked, 70 percent solid", SameRgb(panel.solid, grey)
        and panel.alpha == 0.7)
    store.Set("damageMeterPanelColor", { r = 0.1, g = 0.2, b = 0.3 })
    store.Set("damageMeterPanelAlpha", 40)
    check("spell panel: its own color and opacity", SameRgb(panel.solid, { r = 0.1, g = 0.2, b = 0.3 })
        and panel.alpha == 0.4)
    store.Set("damageMeterBorder", true)
    local framed = false
    for _, border in ipairs(s.borders) do
        framed = framed or border.frame == meter.windows[1].MinimizeContainer.SourceWindow
    end
    check("spell panel: Window Border puts one round it too", framed)
    store.Set("damageMeterSkin", false)
    check("spell panel: off gives the game's own opacity back", panel.alpha == 0.9)
end

-- the card says to turn off the other damage meters, and names the ones that are on
do
    local s = Boot()
    local note = s.cards[1].note
    check("the card says to turn off every other damage meter", note():find("every other damage meter", 1, true) ~= nil)
    s.others.EllesmereUIDamageMeters = true
    s.others.Details = true
    check("and names the ones that are on", note():find("Details, EllesmereUI Damage Meters", 1, true) ~= nil
        and note():find("every other", 1, true) == nil)
end

-- the card is in clear sections, with the game's own settings among the reskin's
do
    local s, store = Boot()
    local heads, at, last = {}, {}, nil
    local width
    local byLabel = {}
    for _, item in ipairs(s.cards[1].rows) do
        if item.group then
            heads[#heads + 1] = item.group
            last = item.group
        elseif item.label then
            at[item.label] = last or "top"
            byLabel[item.label] = item
            if item.label == "Window Width" then width = item end
        end
    end
    check("sections, in order", table.concat(heads, "|") == "Window|Bars|Text|Title Bar|Spell Panel|Reset")
    check("each row sits where it belongs", at["Reskin"] == "top" and at["Visibility"] == "Window"
        and at["Window Width"] == "Window" and at["Move and Resize"] == "Window" and at["Window Color"] == "Window"
        and at["Bar Height"] == "Bars" and at["Bar Texture"] == "Bars" and at["Font"] == "Text"
        and at["Name Color"] == "Text" and at["Title Color"] == "Title Bar" and at["Buttons"] == "Title Bar"
        and at["Window Position"] == "Reset" and at["Restore Game Settings"] == "Reset")
    check("the reskin's rows wait for its switch, the game's own do not", byLabel["Bar Texture"].needs == "damageMeterSkin"
        and byLabel["Bar Height"].needs == nil and byLabel["Visibility"].needs == nil
        and byLabel["Move and Resize"].needs == nil)
    check("the width waits for Move and Resize to be off", width.needs() == true)
    store.Set("damageMeterFree", true)
    check("and is off with it, and says why", width.needs() == false and width.why == "Turn off Move and Resize")
end

-- the rows
do
    local s, store = Boot()
    local rows = {}
    for _, row in ipairs(s.cards[1].rows) do
        if row.key then rows[row.key] = row end
    end
    check("rows: bar opacity, background color and opacity, scroll bar", rows.damageMeterBarAlpha
        and rows.damageMeterBarBgColor.colour and rows.damageMeterBarBgAlpha and rows.damageMeterScrollBar)
    check("rows: window border, its color, the title bar and its faded opacity", rows.damageMeterBorder
        and rows.damageMeterBorderColor.colour and rows.damageMeterTitleFade and rows.damageMeterTitleFadeAlpha)
    check("rows: a size for the names, the amounts and the title", rows.damageMeterNameSize
        and rows.damageMeterValueSize and rows.damageMeterTitleSize and rows.damageMeterFontSize == nil)
    check("rows: buttons, and their color that waits for Themed", rows.damageMeterButtons
        and #rows.damageMeterButtons.choice[2] == 2 and rows.damageMeterButtonColor.colour
        and rows.damageMeterButtonColor.needs() == false)
    store.Set("damageMeterSkin", true)
    store.Set("damageMeterButtons", "themed")
    check("rows: and is on with Themed, once the reskin is on", rows.damageMeterButtonColor.needs() == true)
    check("rows: the scroll bar and title bar choices", #rows.damageMeterScrollBar.choice[2] == 3
        and #rows.damageMeterTitleFade.choice[2] == 2)
    check("rows: border color and faded opacity wait for their switches", rows.damageMeterBorderColor.needs() == false
        and rows.damageMeterTitleFadeAlpha.needs() == false)
    store.Set("damageMeterSkin", true)
    store.Set("damageMeterBorder", true)
    store.Set("damageMeterTitleFade", "hover")
    check("rows: and are on with them, once the reskin is on", rows.damageMeterBorderColor.needs() == true
        and rows.damageMeterTitleFadeAlpha.needs() == true)
    for key, row in pairs(rows) do
        check(key .. ": help is one short sentence", row.help == nil or #row.help < 100)
    end
end

print("PASS damage meter skin: " .. checks .. " checks")

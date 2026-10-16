-- The Naowh guide window for RestedXP (Core/Integrations/RestedXP/Window.lua), run against the real Core with
-- RestedXP stood in for by plain tables. Run with Lua 5.1 from the repository root.
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"); f:close()
    return s
end
local coreSource = Read("Core/Core.lua")
local featuresSource = Read("Core/Features.lua")
local themesSource = Read("Core/Integrations/RestedXP/Themes.lua")
local settingsSource = Read("Core/Integrations/RestedXP/WindowSettings.lua")
local modelSource = Read("Core/Integrations/RestedXP/WindowModel.lua")
local windowSource = Read("Core/Integrations/RestedXP/Window.lua")
local iconsSource = Read("Core/Integrations/RestedXP/Icons.lua")

local cases = 0
local function Check(ok, label) assert(ok, label); cases = cases + 1 end

-- A frame, a font string or a texture: it keeps what it was told, and every other method does nothing.
local function Object(everything)
    local o = { shown = true, points = {}, scripts = {}, kids = {}, width = 0, height = 0 }
    setmetatable(o, { __index = function(_, key)
        if type(key) == "string" and key:find("^%u") then return function() end end
    end })
    function o:SetText(text) self.text = text end
    function o:GetText() return self.text end
    function o:GetStringHeight() return 12 end
    function o:SetWidth(w) self.width = w end
    function o:SetHeight(h) self.height = h end
    function o:SetSize(w, h) self.width, self.height = w, h end
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false end
    function o:IsShown() return self.shown end
    function o:SetParent(parent) self.parent = parent end
    function o:ClearAllPoints() self.points = {} end
    function o:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function o:GetPoint(i)
        local p = self.points[i or 1]
        if p then return unpack(p) end
    end
    function o:SetScript(name, fn) self.scripts[name] = fn end
    function o:SetTextColor(r, g, b) self.color = { r, g, b } end
    function o:SetColorTexture(r, g, b, a) self.solid = { r, g, b, a } end
    function o:SetTexture(path) self.texture = path end
    function o:RegisterForClicks(...) self.clicksFor = { ... } end
    function o:RegisterEvent(event)
        self.events = self.events or {}
        self.events[event] = true
    end
    function o:UnregisterEvent(event)
        if self.events then self.events[event] = nil end
    end
    function o:SetNormalTexture(path) self.normalPath = path end
    function o:SetHighlightTexture(path) self.highlightPath = path end
    function o:GetNormalTexture()
        self.normalTexture = self.normalTexture or Object(everything)
        return self.normalTexture
    end
    function o:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a } end
    function o:SetFont(path, size, flags)
        self.font, self.fontSize, self.fontFlags = path, size, flags
        self.fonts = (self.fonts or 0) + 1
    end
    function o:SetShown(on) self.shown = on and true or false end
    function o:SetShadowOffset(x, y) self.shadowX, self.shadowY = x, y end
    function o:SetValue(v) self.value = v end
    function o:SetMinMaxValues(lo, hi) self.range = { lo, hi } end
    function o:SetStatusBarTexture(path) self.barTexture = path end
    function o:SetStatusBarColor(r, g, b, a) self.barColor = { r, g, b, a } end
    function o:GetHeight() return self.height end
    function o:SetAlpha(a) self.alpha = a end
    function o:GetAlpha() return self.alpha or 1 end
    function o:EnableMouse(on) self.mouse = on end
    function o:EnableMouseWheel(on) self.wheelOn = on end
    function o:IsMouseEnabled() return self.mouse ~= false end
    function o:IsForbidden() return false end
    function o:GetFrameLevel() return self.level or 1 end
    function o:SetFrameLevel(level) self.level = level end
    function o:GetChildren() return unpack(self.kids) end
    function o:CreateFontString()
        local fs = Object(everything)
        fs.parent = self
        everything[#everything + 1] = fs
        return fs
    end
    function o:CreateTexture()
        local t = Object(everything)
        t.parent = self
        everything[#everything + 1] = t
        return t
    end
    function o:Click() self.clicks = (self.clicks or 0) + 1 end
    function o:SetScale(scale) self.scale = scale end
    function o:GetScale() return self.scale or 1 end
    function o:StartMoving() self.moving = true end
    function o:StartSizing(corner) self.sizing = corner end
    function o:SetResizable(on) self.resizable = on and true or false end
    function o:SetResizeBounds(a, b, c, d) self.resizeBounds = { a, b, c, d } end
    function o:GetWidth() return self.width end
    function o:StopMovingOrSizing() self.moving = false end
    return o
end

-- The game, RestedXP's pieces and our window; each call builds a fresh one.
local function World(account, opts)
    opts = opts or {}
    local w = { everything = {}, timers = {}, frames = {}, menus = 0, picks = 0, links = {} }
    local env = { hooked = {} }
    env._G = env
    env.UIParent = Object(w.everything)
    env.GameTooltip = Object(w.everything)
    function env.GameTooltip:GetOwner() return self.owner end
    function env.GameTooltip:SetText(text, r, g, b)
        self.text, self.titleColor = text, { r, g, b }
    end
    function env.GameTooltip:SetOwner(owner)
        self.owner = owner
        self.lines = {}
    end
    function env.GameTooltip:AddLine(text)
        self.lines = self.lines or {}
        self.lines[#self.lines + 1] = text
    end
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    env.CreateColor = function(r, g, b, a) return { r, g, b, a } end
    env.InCombatLockdown = function() return false end
    w.reported = {}
    env.geterrorhandler = function() return function(e) w.reported[#w.reported + 1] = tostring(e) end end
    env.IsShiftKeyDown = function() return w.shift == true end
    env.C_AddOns = { DoesAddOnExist = function(name) return opts.installed ~= false and name == "RXPGuides" end }
    env.C_Timer = { After = function(_, fn) w.timers[#w.timers + 1] = fn end }
    env.SetItemRef = function(link) w.links[#w.links + 1] = link end
    w.items = {}
    env.C_Item = { GetItemCount = function(id)
        if w.itemsRaise then error("items") end
        return w.items[id] or 0
    end }
    env.NaowhForeverDB = { account = account, profiles = {}, charActive = {} }
    env.CreateFrame = function(_, name, parent)
        local f = Object(w.everything)
        f.name, f.parent = name, parent
        if parent and parent.kids then parent.kids[#parent.kids + 1] = f end
        w.frames[#w.frames + 1] = f
        if name then env[name] = f end
        return f
    end
    env.hooksecurefunc = function(tbl, name, fn)
        local original = tbl[name]
        tbl[name] = function(...)
            local results = { original(...) }
            fn(...)
            return unpack(results)
        end
    end
    setmetatable(env, { __index = _G })
    for _, part in ipairs({ { coreSource, "Core" }, { featuresSource, "Features" } }) do
        local chunk = assert(loadstring(part[1], part[2]))
        setfenv(chunk, env)
        chunk("NaowhForever")
    end
    local ns = env.NaowhForever
    -- what draws needs the client's pixel fitting, which the stand-ins have none of
    w.solids, w.borders = {}, {}
    ns.Solid = function(parent, layer)
        local o = Object(w.everything)
        o.parent, o.layer = parent, layer
        w.solids[#w.solids + 1] = o
        return o
    end
    ns.Border = function(parent)
        w.borders[#w.borders + 1] = parent
        local border = { _frame = Object(w.everything), parent = parent }
        function border:SetColor(r, g, b, a) self.color = { r, g, b, a } end
        function border:SetPixels(pixels) self.pixels = pixels end
        parent.borderObject = border
        return border
    end
    ns.UI = { FontPath = function(name) return "Fonts\\" .. name .. ".ttf" end,
        TexturePath = function(name) return "Textures\\" .. name end }
    ns.Hairline = function() end
    ns.OnePixel = function() return 1 end
    ns.Shared = { Style = { FOREVER_FIELD_RGB = { r = 0, g = 0, b = 0 } }, Parts = {
        ForeverInset = function(parent)
            local inset = Object(w.everything)
            inset.fill, inset.of = Object(w.everything), parent
            return inset
        end,
        ForeverBox = function(frame)
            local rim = { frame = frame, _frame = Object(w.everything) }
            function rim:SetColor() end
            return rim
        end,
        ForeverAtlas = function() return false end } }
    ns.AddonFontPath = function(classic) return classic and "Fonts\\Forever.ttf" or "Fonts\\Naowh.ttf" end
    for _, part in ipairs({ { themesSource, "Themes" }, { settingsSource, "WindowSettings" },
            { modelSource, "WindowModel" }, { windowSource, "Window" } }) do
        local chunk = assert(loadstring(part[1], part[2]))
        setfenv(chunk, env)
        chunk("NaowhForever")
    end
    local make = env.CreateFrame
    env.CreateFrame = function() return Object(w.everything) end
    local icons = assert(loadstring(iconsSource, "Icons"))
    setfenv(icons, env)
    icons("NaowhForever")
    env.CreateFrame = make
    w.env, w.ns = env, ns
    return w
end

-- RestedXP as v2 leaves it: a guide, its progress, an active step with live rows, and the steps that follow.
local function Rxp(w, opts)
    opts = opts or {}
    local env = w.env
    local steps = {}
    for i = 1, 66 do steps[i] = { index = i, elements = {} } end
    local function Row(text, tag, icon, done)
        local frame = { text = Object(w.everything), icon = Object(w.everything), button = Object(w.everything) }
        frame.text:SetText(text)
        frame.icon:SetText(icon)
        function frame.button:GetChecked() return done == true end
        return frame
    end
    local talk = { text = "Talk to Duokna", tag = "target", frame = Row("Talk to |cff00ff00Duokna|r", "target", "|Ttalk|t", false) }
    local buy = { text = "Buy", tag = "buy", frame = Row("Buy [Refreshing Spring Water] from her", "buy", "|Tbuy|t", false) }
    local vendor = { text = "Vendor Trash", tag = "vendor", frame = Row("Vendor Trash", "vendor", "|Tv|t", true) }
    local active = { active = true, index = 36, title = "Step 36", elements = { talk, buy, vendor } }
    local tipOnly = { active = true, index = 37, hidewindow = true, elements = { { text = "A tip" } } }
    local idle = { active = false, index = 38, elements = { { text = "Not active" } } }
    local rows = {}
    for i = 37, 50 do
        rows[#rows + 1] = { index = i, text = "Step " .. i .. " line one\nline two", hidden = false, complete = false }
    end
    table.insert(rows, 1, { index = 36, text = "Talk to Duokna", hidden = false, complete = false, current = true })
    table.insert(rows, 1, { index = 35, text = "Done", hidden = false, complete = true })
    rows[4].hidden = true   -- 38 is a step RestedXP hides
    rows[7].complete = true   -- and 41 is done already
    rows[5].text = "|TInterface\\Icons\\Talk:0|t |cff00ff00Talk to Gornek|r\nline two"   -- 39 has an icon and a color
    local rxp = {
        currentGuide = { name = "1-6 Durotar", steps = steps },
        player = { name = "Tester" },
        icons = {},
        locale = { Get = function(text) return text end },
        RXPFrame = { activeSteps = { active, tipOnly, idle }, DropDownMenu = function() w.menus = w.menus + 1 end },
        v2 = { snapshots = 0 },
        SetStep = function() end,
    }
    function rxp.GetGuideProgress() return 36, "id" end
    function rxp.GetGuideName(guide) return guide.name end
    function rxp.v2:IsGuideWindowEnabled() return opts.v2 ~= false end
    function rxp.v2:BuildGuideStepsSnapshot()
        self.snapshots = self.snapshots + 1
        if opts.snapshotRaises then error("snapshot") end
        return { title = "", rows = rows }
    end
    function rxp.v2:UpdateGuideWindow() end
    function rxp.v2:ShowGuideSelectionMenu()
        assert(self == rxp.v2, "a method of v2")
        w.picks = w.picks + 1
    end
    function rxp.v2:UpdateActiveStepsFrame() end
    function rxp.v2:UpdatePlayerActiveStepItem() end
    env.RXP = rxp
    -- RestedXP's two v2 windows, with children that take the mouse
    local guide = { frame = Object(w.everything) }
    local button = Object(w.everything)
    guide.frame.kids[1] = button
    guide.frame:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 12, -240)
    local stepsFrame = { frame = Object(w.everything) }
    local checkbox = Object(w.everything)
    stepsFrame.frame.kids[1] = checkbox
    if not opts.later then
        env.RXPV2GuideWindow = guide
        env.RXPActiveStepsFrameTester = stepsFrame
    end
    w.rxp, w.guide, w.steps, w.rows, w.active, w.button, w.checkbox = rxp, guide, stepsFrame, rows, active, button, checkbox
    w.talk, w.buy, w.vendor = talk, buy, vendor
    return rxp
end

-- The module's own boot frame is the last one made at load: the game tells it the addon loaded, then that
-- the player is in.
local function Start(account, opts)
    local w = World(account, opts)
    Rxp(w, opts)
    local boot
    for _, f in ipairs(w.frames) do boot = f end
    w.boot = boot
    boot.scripts.OnEvent(boot, "ADDON_LOADED", "NaowhForever")
    boot.scripts.OnEvent(boot, "PLAYER_LOGIN")
    return w
end

local function Flush(w)
    local timers = w.timers
    w.timers = {}
    for _, fn in ipairs(timers) do fn() end
end

local function Window(w) return w.env.NaowhRXPWindow end

-- shown, and everything it hangs from shown
local function Seen(o)
    while o do
        if o.shown == false then return false end
        o = o.parent
    end
    return true
end

-- off by default: nothing is built, and RestedXP's windows are as they were
do
    local w = Start({})
    Flush(w)
    Check(Window(w) == nil, "the window is off by default: nothing is built")
    Check(w.guide.frame.alpha == nil and w.steps.frame.alpha == nil and w.guide.frame.mouse == nil,
        "and RestedXP's windows are left alone")
    Check(w.ns.RXPWindowEnabled() == false and w.ns.RXPWindowWidth() == 380 and w.ns.RXPWindowSteps() == 6
        and w.ns.RXPWindowScale() == 100, "the defaults: off, 380 wide, six steps after the active one, full size")
    local wild = Start({ rxpWindowWidth = 9999, rxpWindowSteps = -5, rxpWindowScale = 900 })
    Check(wild.ns.RXPWindowWidth() == 640 and wild.ns.RXPWindowSteps() == 0 and wild.ns.RXPWindowScale() == 200,
        "a width, a count and a scale out of range are held")
    local odd = Start({ rxpWindowWidth = "wide", rxpWindowSteps = "many", rxpWindowScale = "big" })
    Check(odd.ns.RXPWindowWidth() == 380 and odd.ns.RXPWindowSteps() == 6 and odd.ns.RXPWindowScale() == 100,
        "and what is no number is the default")
end

-- on: the heading, the progress, the active step and the steps after it
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local f = Window(w)
    Check(f ~= nil and f.shown and f.width == 380 and f.scale == 1, "on: the window is built, shown, at its width and size")
    Check(w.ns.RXPWindowReady() == true, "RestedXP's V2 interface is on: ready")
    local heading, progress
    for _, o in ipairs(w.everything) do
        if o.parent == f and o.text then
            if o.text:find("Durotar", 1, true) then heading = o end
            if o.text:find("36/66", 1, true) then progress = o end
        end
    end
    local accent = w.ns.THEME.accent
    local accentHex = ("%02x%02x%02x"):format(math.floor(accent.r * 255 + 0.5), math.floor(accent.g * 255 + 0.5),
        math.floor(accent.b * 255 + 0.5))
    Check(heading and heading.text:find("|cff" .. accentHex .. "1-6", 1, true) and not heading.text:find("^1%-6"),
        "the place, then its level range in the theme's accent")
    Check(progress and progress.text:find("36/66", 1, true) and progress.text:find("55%%"),
        "the step and the percent of the guide")
    local labels, rowTexts, lines = {}, {}, {}
    local seenTip
    for _, o in ipairs(w.everything) do
        if o.text and o.shown then
            if o.text == "A tip" or o.text == "Not active" then seenTip = true end
            if o.text == "STEP 36" then labels[#labels + 1] = o end
            if o.text:find("^Talk to") or o.text:find("^Buy") or o.text:find("^Vendor") then rowTexts[#rowTexts + 1] = o.text end
            if o.text:find("^%d+  ") then lines[#lines + 1] = o.text end
        end
    end
    Check(#labels == 1, "the active step is labelled in capitals, as RestedXP titles it")
    Check(#rowTexts == 3 and rowTexts[1] == "Talk to |cff00ff00Duokna|r", "its rows are RestedXP's own, as they read now")
    Check(#lines == 6 and lines[1] == "37  Step 37 line one" and lines[2] == "39  Talk to Gornek"
        and lines[3] == "40  Step 40 line one" and lines[4] == "41  Step 41 line one"
        and lines[5] == "42  Step 42 line one" and lines[6] == "43  Step 43 line one",
        "six steps after it, one line each, without the one RestedXP hides")
    Check(progress.text:find(string.char(194, 183), 1, true), "the step and the percent are joined by a dot")
    Check(f.menu == nil, "there is no menu button: the right click is the menu")
    local panel
    for _, o in ipairs(w.solids) do
        if o.parent == f and o.layer == "BACKGROUND" then panel = o end
    end
    Check(panel and panel.shown == false and f.borderObject._frame.shown == false,
        "the window has a panel and a border to turn on, and both are off to start")
    local boxed = 0
    for _, o in ipairs(w.frames) do
        if o.label and o.logo and Seen(o) then boxed = boxed + 1 end
    end
    Check(boxed == 1, "only the active step is in a box")
    Check(not seenTip, "a step that is a tip only, or not active, is not a box")
    Check(f.height > 0, "the window is as tall as what it shows")

    -- the steps listed are a setting
    w.ns.SetRXPWindowSteps(2)
    Flush(w)
    local count = 0
    for _, o in ipairs(w.everything) do
        if o.text and o.shown and o.text:find("^%d+  ") then count = count + 1 end
    end
    Check(count == 2 and account.rxpWindowSteps == 2, "two steps after it: two lines, stored")
    w.ns.SetRXPWindowSteps(6)
    Check(account.rxpWindowSteps == nil, "the default is not stored")
    w.ns.SetRXPWindowSteps(40)
    Check(w.ns.RXPWindowSteps() == 12 and account.rxpWindowSteps == 12, "and the most is held to its range")
end

-- every text of the window is in the Addon Font
do
    local w = Start({ rxpWindow = true })
    local texts, other = 0, 0
    for _, o in ipairs(w.everything) do
        if o.font ~= nil then
            texts = texts + 1
            if o.font ~= "Fonts\\Naowh.ttf" then other = other + 1 end
        end
    end
    Check(texts >= 10 and other == 0, "every text the window makes is in the Addon Font")
end

-- RestedXP's two windows are kept alive, and out of sight and out of the way
do
    local w = Start({ rxpWindow = true })
    Check(w.guide.frame.alpha == 0 and w.steps.frame.alpha == 0, "RestedXP's guide and steps windows are see-through")
    Check(w.guide.frame.mouse == false and w.button.mouse == false and w.steps.frame.mouse == false
        and w.checkbox.mouse == false, "and take no clicks, with what is in them")
    w.guide.frame:SetAlpha(1)
    Check(w.guide.frame.alpha == 0, "RestedXP showing it again leaves it see-through")
    w.ns.SetRXPWindow(false)
    Check(w.guide.frame.alpha == 1 and w.steps.frame.alpha == 1 and w.guide.frame.mouse == true
        and w.button.mouse == true and w.checkbox.mouse == true, "off: both windows are given back as they were")
    Check(Window(w).shown == false, "and the Naowh window is hidden")
    w.ns.SetRXPWindow(true)
    Check(Window(w).shown == true and w.guide.frame.alpha == 0, "on again: the other way")
    w.guide.frame:SetAlpha(0.5)
    Check(w.guide.frame.alpha == 0, "and it is held there")
end

-- live: a row's text and a step's progress follow RestedXP
do
    local w = Start({ rxpWindow = true })
    Check(#w.timers == 0, "nothing waits after the first draw")
    w.talk.frame.text:SetText("Talk to Duokna 1/1")
    w.buy.frame.text:SetText("Buy [Refreshing Spring Water] 5/5")
    Check(#w.timers == 1, "a burst of changes is one redraw")
    Flush(w)
    local seen = {}
    for _, o in ipairs(w.everything) do
        if o.text then seen[o.text] = true end
    end
    Check(seen["Talk to Duokna 1/1"] and seen["Buy [Refreshing Spring Water] 5/5"], "the rows read what RestedXP's say now")
    w.rxp.v2:UpdateGuideWindow()
    Check(#w.timers == 1, "and RestedXP laying its windows out again redraws it")
    Flush(w)
    w.rxp.SetStep(37)
    Check(#w.timers == 1, "and so does a step being set")
end

-- the header folds, and the position is kept
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local f = Window(w)
    local fold = f.fold
    local expanded = f.height
    fold.scripts.OnClick(fold)
    Check(account.rxpWindowCollapsed == true and f.height < expanded, "folded: the header only, and it is kept")
    local leftShown = 0
    for _, o in ipairs(w.everything) do
        if Seen(o) and o.text and (o.text == "STEP 36" or o.text:find("^%d+  ")) then leftShown = leftShown + 1 end
    end
    Check(leftShown == 0, "and neither the active step nor the steps after it are shown")
    fold.scripts.OnClick(fold)
    Check(account.rxpWindowCollapsed == nil and f.height == expanded, "unfolded: as before")
    Check(f.points[1][1] == "TOPLEFT" and f.points[1][4] == 12 and f.points[1][5] == -240,
        "first placed where RestedXP's guide window was")
    f.points = { { "TOPLEFT", w.env.UIParent, "TOPLEFT", 300, -100 } }
    f.scripts.OnDragStop(f)
    Check(account.rxpWindowPos and account.rxpWindowPos[1] == "TOPLEFT" and account.rxpWindowPos[3] == 300
        and account.rxpWindowPos[4] == -100, "dragged: the place is kept")
    local again = Start(account)
    local g = Window(again)
    Check(g.points[1][1] == "TOPLEFT" and g.points[1][4] == 300 and g.points[1][5] == -100,
        "and it comes back there")
    f.scripts.OnMouseUp(f, "RightButton")
    Check(w.menus == 1, "a right click opens RestedXP's own menu")
    f.scripts.OnMouseUp(f, "LeftButton")
    Check(w.menus == 1, "a left click does not")
end

-- the size: the window scales as a whole and stays in the same place on the screen
do
    local account = { rxpWindow = true, rxpWindowPos = { "TOPLEFT", "TOPLEFT", 300, -100 } }
    local w = Start(account)
    local f = Window(w)
    Check(f.scale == 1 and f.points[1][4] == 300 and f.points[1][5] == -100, "at full size: where it was kept")
    w.ns.SetRXPWindowScale(150)
    Check(f.scale == 1.5 and account.rxpWindowScale == 150, "bigger: scaled, and stored")
    Check(math.abs(f.points[1][4] - 200) < 1e-9 and math.abs(f.points[1][5] + 100 / 1.5) < 1e-9,
        "and held in the same place on the screen")
    Check(math.abs(account.rxpWindowPos[3] - 200) < 1e-9, "and the place is kept in the new size's units")
    w.ns.SetRXPWindowScale(100)
    Check(f.scale == 1 and account.rxpWindowScale == nil and math.abs(f.points[1][4] - 300) < 1e-9,
        "back to full size: the default is not stored")
    w.ns.SetRXPWindowScale(900)
    Check(account.rxpWindowScale == 200 and f.scale == 2, "and the biggest is held to its range")
    local off = { rxpWindowPos = { "TOPLEFT", "TOPLEFT", 300, -100 } }
    local o = Start(off)
    o.ns.SetRXPWindowScale(200)
    Check(off.rxpWindowScale == 200 and off.rxpWindowPos[3] == 150 and off.rxpWindowPos[4] == -50,
        "with the window off the place that was kept follows the size")
    local sized = Start({ rxpWindow = true, rxpWindowScale = 125 })
    Check(Window(sized).scale == 1.25, "a saved size is the size it is built at")
end

-- a click on the step skips it, and a click on a step of the list goes to it, with shift to start
do
    local w = Start({ rxpWindow = true })
    local rxp = w.rxp
    local ns = w.ns
    local f = Window(w)
    local went = {}
    rxp.SetStep = function(n) went[#went + 1] = n end
    local row, box, sub
    for _, o in ipairs(w.frames) do
        if o.icon and o.text and o.bar and o.scripts.OnClick then
            if not row then row = o elseif not sub then sub = o end
        end
        if o.label and o.logo then box = o end
    end
    Check(row ~= nil and box ~= nil and sub ~= nil, "a first line, a sub task and a box to click")
    row.scripts.OnClick(row)
    Check(#went == 0, "a click without shift is not a skip: it is a misclick")
    w.shift = true
    row.scripts.OnClick(row)
    Check(#went == 1 and went[1] == 37 and w.talk.frame.button.clicks == nil,
        "with shift the first line skips the step: to the one after the guide's 36th, and not the objective")
    sub.scripts.OnClick(sub)
    box.scripts.OnClick(box)
    Check(#went == 3 and went[2] == 37 and went[3] == 37, "so does a sub task, and the box round the rows")
    w.shift = false
    row.scripts.OnHyperlinkClick(row, "quest:1", "[Quest]", "LeftButton")
    Check(w.links[1] == "quest:1", "and a link in a row opens as RestedXP's would")

    w.env.GameTooltip.text = nil
    sub.scripts.OnEnter(sub)
    Check(w.env.GameTooltip.text == "Skip step", "a sub task says it skips the step")
    box.scripts.OnEnter(box)
    Check(w.env.GameTooltip.owner == box, "the box says it too, and it is the box's tooltip wherever it was said")
    row.scripts.OnEnter(row)
    local tip = w.env.GameTooltip
    Check(tip.text == "Skip step" and tip.lines[1] == "Shift-click" and tip.lines[2] == "Right-click: menu"
        and tip.owner == box, "a row says it skips the step, that it takes shift, and where the menu is")
    ns.SetRXPWindowOption("rxpWindowTips", false)
    w.env.GameTooltip.text = nil
    w.env.GameTooltip.owner = nil
    row.scripts.OnEnter(row)
    box.scripts.OnEnter(box)
    Check(w.env.GameTooltip.text == nil and w.env.GameTooltip.owner == nil,
        "with tooltips off neither the rows nor the box say anything")
    w.shift = true
    row.scripts.OnClick(row)
    Check(#went == 4, "and a click still does what it does")
    w.shift = false
    ns.SetRXPWindowOption("rxpWindowTips", true)

    -- the menu is the right click, on a row, on the box and on a line of the list
    local function RegistersRight(o)
        for _, click in ipairs(o.clicksFor or {}) do
            if click == "RightButtonUp" then return true end
        end
        return false
    end
    Check(RegistersRight(row) and RegistersRight(box), "a row and the box are given the right click")
    local menus = w.menus
    row.scripts.OnClick(row, "RightButton")
    box.scripts.OnClick(box, "RightButton")
    sub.scripts.OnClick(sub, "RightButton")
    Check(w.menus == menus + 3 and #went == 4, "a right click on a row or the box is the menu, and no skip")

    local hits = {}
    for _, o in ipairs(w.frames) do
        if o.index and o.shade and Seen(o) then hits[#hits + 1] = o end
    end
    Check(#hits == 6 and hits[1].index == 37 and hits[2].index == 39 and hits[6].index == 43,
        "each line of the list has a button for its step")
    Check(hits[2].width == 380 - 20 and hits[2].height == 12 + 6, "as big as the line")
    hits[2].scripts.OnClick(hits[2])
    Check(#went == 4, "a click on one without shift goes nowhere")
    w.shift = true
    hits[2].scripts.OnClick(hits[2])
    Check(#went == 5 and went[5] == 39, "with shift it goes to that step")
    w.shift = false
    hits[2].scripts.OnEnter(hits[2])
    Check(w.env.GameTooltip.text == "Go to step 39" and hits[2].shade.shown, "it says so, and is lit")
    Check(#w.env.GameTooltip.lines == 1 and w.env.GameTooltip.lines[1] == "Shift-click",
        "and it does not say where the menu is, nor that the list scrolls")
    hits[2].scripts.OnLeave(hits[2])
    Check(hits[2].shade.shown == false, "and not when the mouse leaves")
    Check(hits[1].scripts.OnDragStart ~= nil, "a line is still where the window is dragged from")
    Check(not RegistersRight(hits[1]), "and a line of the list is not: the menu is of the current step")
    hits[1].scripts.OnClick(hits[1], "RightButton")
    Check(w.menus == menus + 3 and #went == 5, "a right click on a line is no menu, and no step")

    -- how it is done is a setting
    ns.SetRXPWindowOption("rxpWindowSkip", "click")
    row.scripts.OnEnter(row)
    Check(#w.env.GameTooltip.lines == 1 and w.env.GameTooltip.lines[1] == "Right-click: menu",
        "click: and it does not say shift")
    row.scripts.OnClick(row)
    hits[1].scripts.OnClick(hits[1])
    Check(#went == 7 and went[6] == 37 and went[7] == 37, "click: a plain click does both")
    ns.SetRXPWindowOption("rxpWindowSkip", "off")
    w.shift = true
    row.scripts.OnClick(row)
    box.scripts.OnClick(box)
    hits[1].scripts.OnClick(hits[1])
    Check(#went == 7, "off: no click does either")
    hits[1].shade:Hide()
    hits[1].scripts.OnEnter(hits[1])
    Check(hits[1].shade.shown == false, "and a line is not lit")
    row.scripts.OnEnter(row)
    Check(w.env.GameTooltip.text == "Right-click: menu" and #w.env.GameTooltip.lines == 0,
        "and a row says only where the menu is")
    w.shift = false
    ns.SetRXPWindowOption("rxpWindowSkip", "shift")

    -- the guide's progress is read when it is skipped, and what is missing is left out
    w.shift = true
    rxp.GetGuideProgress = function() return 40, "id" end
    w.active.index = 40
    row.scripts.OnClick(row)
    Check(went[8] == 41, "it is from the guide's progress as it is now")
    rxp.GetGuideProgress = function() error("progress") end
    row.scripts.OnClick(row)
    Check(#went == 8 and #w.reported == 1 and w.reported[1]:find("progress", 1, true),
        "progress that raises: no step, and reported")
    row.scripts.OnClick(row)
    Check(#w.reported == 1, "once")
    rxp.SetStep = function() error("step") end
    hits[1].scripts.OnClick(hits[1])
    Check(#w.reported == 2 and w.reported[2]:find("step", 1, true) and f.shown, "a step that raises: reported, and not raised")

    -- a button that is lit when the line under it is drawn for another step is not
    rxp.GetGuideProgress = function() return 36, "id" end
    w.active.index = 36
    w.shift = false
    hits[3].scripts.OnEnter(hits[3])
    Check(hits[3].shade.shown == true, "lit under the mouse")
    local accent = w.ns.THEME.accent
    local solid = hits[3].shade.solid
    Check(solid and solid[1] == accent.r and solid[2] == accent.g and solid[3] == accent.b and solid[4] == 0.25,
        "in the accent, a little see-through, not the text's color")
    local title = w.env.GameTooltip.titleColor
    Check(title and title[1] == accent.r and title[2] == accent.g and title[3] == accent.b,
        "and its tooltip's title is in the accent, not the game's gold")
    rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(hits[3].shade.shown == false, "and not when it is drawn again")
end

-- the rows after the first are set in
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local function Rows()
        local out = {}
        for _, o in ipairs(w.frames) do
            if o.icon and o.text and o.bar and Seen(o) then out[#out + 1] = o end
        end
        return out
    end
    local rows = Rows()
    Check(#rows == 3, "three rows in the active step")
    Check(rows[1].points[1][4] == 7 and rows[2].points[1][4] == 7 + 12 and rows[3].points[1][4] == 7 + 12,
        "the first starts at the start of the box, the others are set in")
    Check(rows[1].width == 380 - 20 - 14 and rows[2].width == 380 - 20 - 14 - 12,
        "and are that much narrower")
end

-- a line of words that is not a task has no icon and no bar of its own
do
    local w = Start({ rxpWindow = true })
    local function Rows()
        local out = {}
        for _, o in ipairs(w.frames) do
            if o.icon and o.text and o.bar and Seen(o) then out[#out + 1] = o end
        end
        return out
    end
    local function Line(text, icon, shown)
        local frame = { text = Object(w.everything), icon = Object(w.everything), button = Object(w.everything) }
        frame.text:SetText(text)
        frame.icon:SetText(icon)
        if shown == false then frame.icon:Hide() end
        function frame.button:GetChecked() return true end
        return frame
    end
    local elements = w.rxp.RXPFrame.activeSteps[1].elements
    table.insert(elements, 2, { text = "x", textOnly = true, frame = Line("|cffffd100Do not go out of your way|r", "|Tstale|t", false) })
    table.insert(elements, 3, { text = "x", textOnly = true,
        frame = Line("|Tinterface/worldmap/chatbubble_64grey.blp:20|t Talk to Duokna", "", false) })
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    local rows = Rows()
    Check(#rows == 5, "the step's five lines")
    Check(rows[2].icon.text == "" and rows[2].bar.shown == false,
        "a line that is only words: no icon, though its frame kept one from another use, and no bar")
    Check(rows[3].bar.shown == true and rows[3].icon.text ~= "",
        "a line that starts with a marker is a row like the others: the bubble and its bar")
    Check(rows[4].bar.shown == true and rows[5].bar.shown == true, "and the objectives after it have theirs")
    Check(rows[2].points[1][4] == 7 + 12 and rows[2].text.points[1][4] == rows[4].text.points[1][4],
        "the words are set in as a row is, and start where the others' do")
    elements[2].textOnly = false
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    rows = Rows()
    Check(rows[2].bar.shown == true, "the same line as an objective has its bar")
    elements[2].textOnly = true
    elements[2].frame.icon:Show()
    elements[2].frame.icon:SetText("|Tshown|t")
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    rows = Rows()
    Check(rows[2].icon.text == "|Tshown|t", "an icon RestedXP shows is still shown")
end

-- a text that changes is no new guide: nothing is read again, walked again or set again; a step set is
do
    local w = Start({ rxpWindow = true })
    local ns, rxp = w.ns, w.rxp
    Flush(w)
    local walks = 0
    for _, frame in ipairs({ w.guide.frame, w.steps.frame, w.button, w.checkbox }) do
        local get = frame.GetChildren
        frame.GetChildren = function(self)
            walks = walks + 1
            return get(self)
        end
    end
    local function Fonts()
        local n = 0
        for _, o in ipairs(w.everything) do n = n + (o.fonts or 0) end
        return n
    end
    local function Lines()
        local out = {}
        for _, o in ipairs(w.everything) do
            if o.text and Seen(o) and o.text:find("^%d+  ") then out[#out + 1] = o end
        end
        return out
    end
    local function Row(text)
        for _, o in ipairs(w.frames) do
            if o.icon and o.text and o.bar and Seen(o) and o.text.text == text then return o end
        end
    end
    local snapshots, fonts = rxp.v2.snapshots, Fonts()
    w.rows[3].text = "Step 37 renamed\nline two"
    w.talk.frame.text:SetText("Talk to Duokna 1/2")
    Flush(w)
    Check(rxp.v2.snapshots == snapshots, "a text changing: the steps after the active one are not read again")
    Check(Lines()[1].text == "37  Step 37 line one", "and are the list RestedXP's own window has, until it is laid out again")
    Check(walks == 0, "RestedXP's windows are not walked again for it")
    Check(Fonts() == fonts, "and no font is set that is set already, the first row's bigger one included")
    Check(Row("Talk to Duokna 1/2") ~= nil, "while the row reads the text")

    rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(rxp.v2.snapshots == snapshots + 1 and Lines()[1].text == "37  Step 37 renamed",
        "RestedXP laying its window out: they are read, once, and the list follows")
    Check(walks > 0, "and its windows are walked, for what it made")
    local late = Object(w.everything)
    w.guide.frame.kids[#w.guide.frame.kids + 1] = late
    rxp.v2:UpdateActiveStepsFrame()
    Flush(w)
    Check(late.mouse == false, "a frame it made then is out of the mouse's way")

    snapshots, fonts = rxp.v2.snapshots, Fonts()
    ns.SetRXPWindowSteps(3)
    Flush(w)
    Check(#Lines() == 3 and rxp.v2.snapshots == snapshots, "fewer steps listed: taken from what was read")
    ns.SetRXPWindowSteps(12)
    Flush(w)
    Check(#Lines() == 12 and rxp.v2.snapshots == snapshots, "and more, up to the most")
    ns.SetRXPWindowSteps(6)
    Flush(w)
    ns.SetRXPWindowOption("rxpWindowListSize", 14)
    ns.SetRXPWindowOption("rxpWindowTextSize", 15)
    Flush(w)
    local sized = true
    for _, o in ipairs(Lines()) do
        if o.fontSize ~= 14 then sized = false end
    end
    Check(Fonts() > fonts and sized and #Lines() == 6, "a size changed: the lines are set in it")
    Check(Row("Talk to Duokna 1/2").text.fontSize == 17 and Row("Vendor Trash").text.fontSize == 15,
        "and so are the rows, the first one bigger")
    Check(rxp.v2.snapshots == snapshots, "none of it reads the steps")

    snapshots = rxp.v2.snapshots
    rxp.currentGuide = { name = "1-5 Mulgore", steps = rxp.currentGuide.steps }
    w.talk.frame.text:SetText("Talk to Duokna 2/2")
    Flush(w)
    Check(rxp.v2.snapshots == snapshots + 1, "another guide is not listed from the last one's steps")
    snapshots = rxp.v2.snapshots
    rxp.GetGuideProgress = function() return 40, "id" end
    w.talk.frame.text:SetText("Talk to Duokna 0/2")
    Flush(w)
    Check(rxp.v2.snapshots == snapshots and Lines()[1].text == "41  Step 41 line one",
        "the guide on another step is the same list, from the step after it, and is not read again")

    walks = 0
    ns.SetRXPWindow(false)
    ns.SetRXPWindow(true)
    Check(walks > 0 and w.guide.frame.alpha == 0 and w.button.mouse == false,
        "off and on: its windows are taken again, whatever RestedXP did meanwhile")
end

-- the list is the guide's steps, scrolled with the wheel: the ones done above, the ones to come below
do
    local account = { rxpWindow = true, rxpWindowScrollBar = true }
    local w = Start(account)
    local ns, rxp = w.ns, w.rxp
    local f = Window(w)
    local went = {}
    rxp.SetStep = function(n) went[#went + 1] = n end
    local function Lines()
        local out = {}
        for _, o in ipairs(w.everything) do
            if o.text and Seen(o) and o.text:find("^%d+  ") then out[#out + 1] = o end
        end
        return out
    end
    local function First(of)
        local line = Lines()[of or 1]
        return line and line.text:match("^(%d+)")
    end
    local function Wheel(ticks)
        for _ = 1, math.abs(ticks) do f.wheel.scripts.OnMouseWheel(f.wheel, ticks > 0 and 1 or -1) end
        Flush(w)
    end
    local function Hit(index)
        for _, o in ipairs(w.frames) do
            if o.index == index and o.shade and Seen(o) then return o end
        end
    end
    local accent = ns.RXPWindowColor("accent")

    Check(#Lines() == 6 and First() == "37", "to start: the six steps after the active one, as before")
    Check(f.track.shown == true and f.thumb.shown == true, "and a bar says there are more of them")
    Check(f.scripts.OnMouseWheel == nil and f.wheel.wheelOn == true and Seen(f.wheel)
        and f.wheel.points[1][5] == f.track.points[1][5] and f.wheel.width == 380 - 20,
        "the wheel is the list's alone, over its lines, not the whole window's: the camera still zooms elsewhere")
    Check(f.track.points[1][2] == f and f.track.points[1][3] == "TOPRIGHT" and f.track.points[1][4] == -10
        and f.thumb.points[1][4] == -10, "at the step box's right edge, not the window's: as wide as the step it follows")
    Check(Lines()[1].width == 380 - 20 - 2 - 4, "and the lines end before it, not under it")

    Wheel(1)
    Check(First() == "35" and First(2) == "36" and First(3) == "37" and #Lines() == 6,
        "a tick up: the steps behind it, from the first of the guide RestedXP lists")
    Check(Lines()[1].alpha == 0.5 and Lines()[3].alpha == 1, "a step that is done is dimmer")
    Check(Lines()[2].color and math.abs(Lines()[2].color[1] - accent) < 1e-6 and Lines()[3].color[1] ~= accent,
        "and the one the guide is on has the accent")
    local thumb = f.thumb.points[1][5]
    Check(f.track.points[1][5] == f.thumb.points[1][5], "the bar's thumb is at the top of its track")
    Wheel(3)
    Check(First() == "35", "no further up than the first step")

    Wheel(-3)
    Check(First() == "42" and #Lines() == 6, "three ticks down: further in the guide")
    Check(f.thumb.points[1][5] < thumb, "and the bar's thumb has moved down")
    Wheel(-30)
    Check(First() == "45" and #Lines() == 6 and First(6) == "50", "no further down than the last step, at the bottom of the list")

    w.shift = true
    Wheel(30)
    Hit(35).scripts.OnClick(Hit(35))
    Check(#went == 1 and went[1] == 35, "a step done is gone back to like any other: with shift, a click goes to it")
    w.shift = false
    Hit(35).scripts.OnEnter(Hit(35))
    Check(w.env.GameTooltip.text == "Go to step 35" and #w.env.GameTooltip.lines == 1,
        "and its tooltip says so, and no more")
    ns.SetRXPWindowOption("rxpWindowSkip", "off")
    Flush(w)
    local before = #went
    Hit(35).scripts.OnClick(Hit(35))
    Check(#went == before, "with Skipping Steps off it goes nowhere")
    ns.SetRXPWindowOption("rxpWindowSkip", "shift")

    rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(First() == "35", "RestedXP laying its window out again does not take the list from where it is scrolled")
    rxp.GetGuideProgress = function() return 40, "id" end
    rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(First() == "41", "the guide moving on takes it back to the steps after it")

    ns.SetRXPWindowSteps(12)
    Flush(w)
    Check(#Lines() == 10 and f.track.shown == true, "twelve lines of the ten steps after it, and the rest above them")
    Wheel(5)
    Check(First() == "35" and #Lines() == 12, "all twelve lines are the guide's now")
    ns.SetRXPWindowSteps(0)
    Wheel(1)
    Check(#Lines() == 0 and f.track.shown == false and f.thumb.shown == false, "none listed: nothing to scroll and no bar")
    ns.SetRXPWindowSteps(6)
    Flush(w)

    account.rxpWindowCollapsed = true
    ns.RXPWindowRefresh()
    Flush(w)
    Check(f.track.shown == false and f.thumb.shown == false and f.wheel.shown == false,
        "folded: no bar either, and the wheel is free")
    account.rxpWindowCollapsed = nil
    ns.RXPWindowRefresh()
    Flush(w)

    ns.SetRXPWindowSteps(0)
    Flush(w)
    Check(f.wheel.shown == false and f.wheel.wheelOn == false, "with no steps listed the wheel is free too")
    ns.SetRXPWindowSteps(6)
    Flush(w)
    Check(f.wheel.shown == true and f.wheel.wheelOn == true, "and it scrolls again when they are back")

    rxp.GetGuideProgress = function() return 66, "id" end
    rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(#Lines() == 0, "at the end of the guide there is nothing after it")
    Wheel(1)
    Check(#Lines() == 2 and First() == "49", "and a tick up shows the last steps")

    local plain = Start({ rxpWindow = true })
    local p = Window(plain)
    local function PlainLines()
        local out = {}
        for _, o in ipairs(plain.everything) do
            if o.text and Seen(o) and o.text:find("^%d+  ") then out[#out + 1] = o end
        end
        return out
    end
    Check(p.track.shown == false and p.thumb.shown == false, "the scroll bar is off to start: no bar")
    Check(#PlainLines() == 6 and PlainLines()[1].width == 380 - 20, "and the lines are as wide as the step box, with no room kept for it")
    p.wheel.scripts.OnMouseWheel(p.wheel, 1)
    Flush(plain)
    Check(PlainLines()[1].text:find("^35") ~= nil, "while the wheel scrolls the list as it does with it")
    for _, o in ipairs(plain.frames) do
        if o.index == 35 and o.shade and Seen(o) then
            o.scripts.OnEnter(o)
            Check(plain.env.GameTooltip.text == "Go to step 35" and #plain.env.GameTooltip.lines == 1,
                "and a line's tooltip says nothing of the scroll")
        end
    end
    plain.ns.SetRXPWindowOption("rxpWindowScrollBar", true)
    Flush(plain)
    Check(p.track.shown == true and p.thumb.shown == true and PlainLines()[1].width == 380 - 20 - 2 - 4,
        "Show Scroll Bar shows it, and the lines end before it")
    plain.ns.SetRXPWindowOption("rxpWindowScrollBar", false)
    Flush(plain)
    Check(p.track.shown == false and p.thumb.shown == false and PlainLines()[1].width == 380 - 20,
        "and off again hides it")

    local small = Start({ rxpWindow = true, rxpWindowScrollBar = true })
    local g = Window(small)
    for _, row in ipairs(small.rows) do
        if row.index > 40 then row.hidden = true end
    end
    small.rxp.v2:UpdateGuideWindow()
    Flush(small)
    local shown = 0
    for _, o in ipairs(small.everything) do
        if o.text and Seen(o) and o.text:find("^%d+  ") then shown = shown + 1 end
    end
    Check(shown == 3 and g.track.shown == false, "a guide with no more steps than lines has no bar to show")
    local full = true
    for _, o in ipairs(small.everything) do
        if o.text and Seen(o) and o.text:find("^%d+  ") and o.width ~= 380 - 20 then full = false end
    end
    Check(full, "and its lines are as wide as the step box")
end

-- the step box and the bars have a border, black to start, and its size and color are the player's in any theme
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local ns = w.ns
    local f = Window(w)
    local function Box()
        for _, o in ipairs(w.frames) do
            if o.label and o.logo then return o end
        end
    end
    local function Meters()
        local out = {}
        for _, o in ipairs(w.frames) do
            if o.track and o ~= f and o ~= f.bar and o.parent ~= f and Seen(o) then out[#out + 1] = o end
        end
        return out
    end
    local function Black(r, g, b, a) return r == 0 and g == 0 and b == 0 and a == 1 end

    Check(Black(ns.RXPWindowColor("boxBorder")) and Black(ns.RXPWindowColor("barBorder")),
        "both borders are black to start")
    Check(ns.RXPWindowOption("rxpWindowBoxBorderSize") == 1 and ns.RXPWindowOption("rxpWindowBarBorderSize") == 1,
        "and one pixel")
    Check(Box().edge.pixels == 1 and f.bar.edge and f.bar.edge.pixels == 1 and Black(unpack(f.bar.edge.color)),
        "as drawn: the step's box and the guide's bar")
    Check(select(4, ns.RXPWindowColor("barBack")) == 0.5 and select(1, ns.RXPWindowColor("barBack"))
        == select(1, ns.RXPWindowColor("line")), "the bar's background is the line's color to start")

    local function Is(line, ...)
        local r, g, b, a = ...
        return r == line.r and g == line.g and b == line.b and a == 1
    end
    local preset = ns.THEME_PRESET_ORDER[1]
    ns.SetRXPWindowTheme(preset)
    Check(Is(ns.THEME_PRESETS[preset].line, ns.RXPWindowColor("boxBorder"))
        and Is(ns.THEME_PRESETS[preset].line, ns.RXPWindowColor("barBorder")),
        "a preset's is its own line color: themed, and black only in the Naowh theme")
    ns.SetRXPWindowTheme("forever")
    Check(Is(ns.FOREVER_SKIN.line, ns.RXPWindowColor("boxBorder")) and Is(ns.FOREVER_SKIN.line, ns.RXPWindowColor("barBorder")),
        "and the Forever skin's its bronze")
    ns.SetRXPWindowTheme("")
    Check(Black(ns.RXPWindowColor("boxBorder")), "the addon's own theme is black again")
    account.themePreset = preset
    ns.ApplyThemeColors()
    local painted = ns.THEME.line
    Check(Is(painted, ns.RXPWindowColor("boxBorder")) and not Black(ns.RXPWindowColor("boxBorder")),
        "and a theme picked for the whole addon is the window's, as its line color")
    account.themePreset = nil

    local tall = f.height
    ns.SetRXPWindowOption("rxpWindowBoxBorderSize", 3)
    ns.SetRXPWindowOption("rxpWindowBarBorderSize", 2)
    ns.SetRXPWindowColor("boxBorder", 1, 0, 0, 1)
    ns.SetRXPWindowColor("barBorder", 0, 1, 0, 0.5)
    ns.SetRXPWindowColor("barBack", 0, 0, 1, 0.25)
    Flush(w)
    Check(f.height == tall + 2, "the window is as tall as the bar's border makes it, the step box's being inside its own")
    local box = Box()
    Check(box.edge.pixels == 3 and box.edge.color[1] == 1 and box.edge._frame.shown == true,
        "a size and a color for the step's box, in the addon's own theme")
    Check(box.edge.parent == box and f.bar.edge.parent == f.bar,
        "drawn by the shared border (ns.Border), sized in whole pixels")
    Check(f.bar.edge.pixels == 2 and f.bar.edge.color[2] == 1 and f.bar.edge.color[4] == 0.5 and f.bar.height == 5 + 2 * 2,
        "and for the bar: the size, the color, and room for it, so the fill is as thick as it was")
    Check(f.bar.track.solid[3] == 1 and f.bar.track.solid[4] == 0.25, "and the bar's background its own")
    Check(account.rxpWindowBoxBorderSize == 3 and account.rxpWindowBarBorderSize == 2
        and account.rxpWindowColors.boxBorder ~= nil, "kept")

    ns.SetRXPWindowOption("rxpWindowBarBorderSize", 0)
    Flush(w)
    Check(f.bar.edge._frame.shown == false and f.bar.height == 5 and account.rxpWindowBarBorderSize == 0,
        "none: no border and no room for it")
    ns.SetRXPWindowOption("rxpWindowBarBorderSize", 9)
    ns.SetRXPWindowOption("rxpWindowBoxBorderSize", 0)
    Check(ns.RXPWindowOption("rxpWindowBarBorderSize") == 4 and ns.RXPWindowOption("rxpWindowBoxBorderSize") == 1,
        "the sizes are held to 4 at most, and the box's to 1 at least")
    ns.SetRXPWindowOption("rxpWindowBarBorderSize", 2.4)
    Check(ns.RXPWindowOption("rxpWindowBarBorderSize") == 2, "and are whole pixels: a size between two is the nearer")
    ns.SetRXPWindowOption("rxpWindowBarBorderSize", 0.4)
    Check(ns.RXPWindowOption("rxpWindowBarBorderSize") == 0, "down to none")

    ns.SetRXPWindowOption("rxpWindowBarBorderSize", 1)
    w.talk.frame.text:SetText("Boar Meat: 3/8")
    Flush(w)
    local meters = Meters()
    Check(#meters >= 1 and meters[1].edge and meters[1].edge.pixels == 1 and meters[1].edge.color[2] == 1,
        "a row that counts has the bar's border too, in the same color")

    ns.SetRXPWindowTheme("forever")
    Flush(w)
    Check(f.bar.edge._frame.shown == false and f.bar.rim._frame.shown == true,
        "the Forever skin has its own rim, not this border")
    ns.SetRXPWindowTheme("")

    ns.ResetRXPWindowStyle()
    Flush(w)
    Check(ns.RXPWindowOption("rxpWindowBoxBorderSize") == 1 and Black(ns.RXPWindowColor("boxBorder"))
        and f.bar.edge.pixels == 1, "Reset puts the sizes and colors back")

    local accent = { ns.RXPWindowColor("accent") }
    local fill = { ns.RXPWindowColor("barFill") }
    Check(fill[1] == accent[1] and fill[2] == accent[2] and fill[3] == accent[3] and f.bar.barColor[1] == accent[1],
        "the bar's color is the accent's to start: it follows the theme")
    ns.SetRXPWindowColor("barFill", 1, 0, 1, 1)
    w.talk.frame.text:SetText("Boar Meat: 3/8")
    Flush(w)
    Check(f.bar.barColor[1] == 1 and f.bar.barColor[2] == 0 and f.bar.barColor[3] == 1, "a bar color is the guide's bar's")
    meters = Meters()
    Check(#meters >= 1 and meters[1].barColor[1] == 1 and meters[1].barColor[2] == 0, "and a row's bar's, in any theme")
    Check(ns.RXPWindowColor("accent") == accent[1] and select(2, ns.RXPWindowColor("accent")) == accent[2],
        "while the accent is the accent's still, for the text and the icons")
    ns.SetRXPWindowColor("barFill")
    ns.SetRXPWindowTheme("custom")
    ns.SetRXPWindowColor("accent", 0, 1, 0, 1)
    Flush(w)
    Check(f.bar.barColor[1] == 0 and f.bar.barColor[2] == 1,
        "no bar color of its own: the accent's, as the Custom theme has it")
    ns.SetRXPWindowTheme("")
end

-- RestedXP's windows that are not there yet are taken when they are, at whatever redraw is first
do
    local w = Start({ rxpWindow = true }, { later = true })
    Flush(w)
    Check(w.guide.frame.alpha == nil, "not there: nothing is taken")
    w.env.RXPV2GuideWindow = w.guide
    w.talk.frame.text:SetText("Talk to Duokna 1/3")
    Flush(w)
    Check(w.guide.frame.alpha == 0 and w.button.mouse == false and w.steps.frame.alpha == nil,
        "one is there: it is taken, with what is in it, and the other is asked for again")
    w.env.RXPActiveStepsFrameTester = w.steps
    w.talk.frame.text:SetText("Talk to Duokna 2/3")
    Flush(w)
    Check(w.steps.frame.alpha == 0 and w.checkbox.mouse == false, "and when it is there too, it is taken")
end

-- what is missing is left out, and a call into RestedXP that fails is reported
do
    local w = Start({ rxpWindow = true }, { snapshotRaises = true })
    local lines = 0
    for _, o in ipairs(w.everything) do
        if o.text and o.shown and o.text:find("^%d+  ") then lines = lines + 1 end
    end
    Check(Window(w) and lines == 0 and #w.reported == 1 and w.reported[1]:find("snapshot", 1, true),
        "the steps after it failing: none listed, reported, and the rest is drawn")
    w = Start({ rxpWindow = true }, { v2 = false })
    Check(Window(w) == nil and w.ns.RXPWindowReady() == false and w.guide.frame.alpha == nil,
        "RestedXP's V2 interface off: no window, and RestedXP's own is left alone")
    w = Start({ rxpWindow = true })
    w.rxp.currentGuide = { empty = true, steps = {} }
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(Window(w).shown == true and Window(w).title.text:find("No guide selected", 1, true) ~= nil
        and w.guide.frame.alpha == 0, "no guide: the window says so, and RestedXP's welcome is taken")
    w = Start({ rxpWindow = true }, { installed = false })
    Check(Window(w) == nil, "RestedXP not installed: nothing")
end

-- everything the window can be changed in: each setting is kept only when it is not the default
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local ns = w.ns
    local options = ns.RXPWindowOptions()
    Check(#options >= 15, "the window lists what it can be changed in")
    for _, option in ipairs(options) do
        local label = option.key .. ": "
        local default = ns.RXPWindowOption(option.key)
        Check(option.label and option.tip and option.group, label .. "named, with a tip, in a group")
        ns.SetRXPWindowOption(option.key, default)
        Check(account[option.key] == nil, label .. "the default is not kept")
        if option.kind == "number" then
            ns.SetRXPWindowOption(option.key, option.max + 100)
            Check(ns.RXPWindowOption(option.key) == option.max and account[option.key] == option.max,
                label .. "held to its largest")
            ns.SetRXPWindowOption(option.key, option.min - 100)
            Check(ns.RXPWindowOption(option.key) == option.min, label .. "and its smallest")
            ns.SetRXPWindowOption(option.key, "many")
            Check(account[option.key] == nil and ns.RXPWindowOption(option.key) == option.default,
                label .. "what is no number is the default")
        elseif option.kind == "toggle" then
            ns.SetRXPWindowOption(option.key, not default)
            Check(ns.RXPWindowOption(option.key) == (not default) and account[option.key] == (not default),
                label .. "flipped is kept")
        elseif option.kind == "choice" then
            for _, value in ipairs(option.order) do
                ns.SetRXPWindowOption(option.key, value)
                Check(ns.RXPWindowOption(option.key) == value, label .. value)
            end
            ns.SetRXPWindowOption(option.key, "bogus")
            Check(account[option.key] == nil and ns.RXPWindowOption(option.key) == option.default,
                label .. "what is not a choice is the default")
        else
            ns.SetRXPWindowOption(option.key, "Some Name")
            Check(ns.RXPWindowOption(option.key) == "Some Name" and account[option.key] == "Some Name",
                label .. "a name is kept")
            ns.SetRXPWindowOption(option.key, "")
            Check(account[option.key] == nil and ns.RXPWindowOption(option.key) == "", label .. "and none is not")
        end
        account[option.key] = nil
    end
    account.rxpWindowTitleSize, account.rxpWindowOutline, account.rxpWindowLine = 999, "bogus", 7
    Check(ns.RXPWindowOption("rxpWindowTitleSize") == 28 and ns.RXPWindowOption("rxpWindowOutline") == "shadow"
        and ns.RXPWindowOption("rxpWindowLine") == "bar", "a saved value that is out of range or no choice is held")
    account.rxpWindowPanel = "no"
    Check(ns.RXPWindowOption("rxpWindowPanel") == false, "and what is not true is off")
end

-- the colors: the theme's, until one is picked
do
    local account = { rxpWindow = true, rxpWindowTheme = "custom" }
    local w = Start(account)
    local ns = w.ns
    local T = ns.THEME
    local r, g, b, a = ns.RXPWindowColor("title")
    Check(r == T.fg.r and g == T.fg.g and b == T.fg.b and a == 1, "the title is the theme's text color")
    r, g, b, a = ns.RXPWindowColor("accent")
    Check(r == T.accent.r and g == T.accent.g and b == T.accent.b and a == 1, "the accent is the theme's accent")
    r, g, b, a = ns.RXPWindowColor("muted")
    Check(r == T.muted.r and g == T.muted.g and b == T.muted.b and a == 0.9,
        "the muted text is the theme's muted, a little see-through")
    r, g, b, a = ns.RXPWindowColor("panel")
    Check(r == T.panel.r and g == T.panel.g and b == T.panel.b and a == 0.92,
        "the panel is the theme's panel color")
    Check(#ns.RXPWindowColors() == 13, "the thirteen colors it lists, each for several things")
    ns.SetRXPWindowColor("title", 0.1, 0.2, 0.3, 0.4)
    r, g, b, a = ns.RXPWindowColor("title")
    Check(r == 0.1 and g == 0.2 and b == 0.3 and a == 0.4 and account.rxpWindowColors.title.a == 0.4,
        "a color picked is kept whole")
    ns.SetRXPWindowColor("title", 0.5, 0.5, 0.5)
    Check(select(4, ns.RXPWindowColor("title")) == 1, "with no opacity it is solid")
    ns.SetRXPWindowColor("title", nil)
    Check(account.rxpWindowColors == nil and ns.RXPWindowColor("title") == T.fg.r, "and none puts the theme's back")
    ns.SetRXPWindowColor("nothing", 1, 1, 1, 1)
    Check(account.rxpWindowColors == nil, "a color that is not one of them is not kept")
    ns.SetRXPWindowColor("title", 0.1, 0.2, 0.3, 1)
    Check(ns.RXPWindowThemeKey() == "custom" and ns.RXPWindowOwnColors() == true and ns.RXPWindowColor("title") == 0.1,
        "Custom: a color picked is the window's")
    ns.SetRXPWindowTheme("midnight")
    local midnight = ns.THEME_PRESETS.midnight
    Check(account.rxpWindowTheme == "midnight" and ns.RXPWindowOwnColors() == false
        and ns.RXPWindowColor("title") == midnight.fg.r and account.rxpWindowColors.title.r == 0.1,
        "a theme of the presets: its color, and the one picked is kept")
    local accent = { ns.RXPWindowColor("accent") }
    Check(accent[1] == midnight.accent.r and accent[2] == midnight.accent.g and accent[3] == midnight.accent.b,
        "every color of the window is the preset's")
    local box = { ns.RXPWindowColor("box") }
    Check(box[1] == midnight.bg.r and box[4] == 1, "the box has the preset's background, solid")
    Check(account.themePreset == nil and ns.ThemePresetKey() == "", "and the addon's own theme is not touched")
    ns.SetRXPWindowTheme("forever")
    local gold = ns.FOREVER_SKIN
    Check(account.rxpWindowTheme == "forever" and ns.RXPWindowOwnColors() == false
        and ns.RXPWindowColor("accent") == gold.accent.r and select(2, ns.RXPWindowColor("accent")) == gold.accent.g
        and ns.RXPWindowColor("title") == gold.fg.r and ns.RXPWindowColor("box") == gold.bg.r,
        "Forever: the skin's gold, its text and its brown, for the window alone")
    Check(account.themePreset == nil and ns.Skin() == "" and ns.foreverSkin ~= true,
        "and the addon is not in the skin: it is not set by it")
    ns.SetRXPWindowTheme(nil)
    Check(account.rxpWindowTheme == nil and ns.RXPWindowThemeKey() == "" and ns.RXPWindowColor("title") == T.fg.r,
        "the addon's own: the addon's colors, and nothing stored")
    ns.SetRXPWindowTheme("not a theme")
    Check(account.rxpWindowTheme == nil, "a theme that is none is not kept")
    account.rxpWindowTheme = "junk"
    Check(ns.RXPWindowThemeKey() == "" and ns.RXPWindowColor("title") == T.fg.r, "and one saved wrongly is the addon's")
    account.rxpWindowTheme = nil
    ns.SetRXPWindowTheme("custom")
    Check(ns.RXPWindowColor("title") == 0.1, "and Custom again: the one picked is back")
    account.themePreset = "crimson"
    Check(ns.RXPWindowColor("title") == 0.1, "the addon's theme picked after changes nothing of Custom")
    ns.SetRXPWindowTheme("forest")
    Check(account.themePreset == "crimson" and ns.RXPWindowColor("accent") == ns.THEME_PRESETS.forest.accent.r,
        "a window theme is not the addon's: it does not set it")
    account.themePreset = nil
    ns.SetRXPWindowTheme("custom")
    ns.SetRXPWindowColor("title", nil)
    ns.SetRXPWindowTheme(nil)
    account.rxpWindowColors = { text = { r = "x" } }
    Check(ns.RXPWindowColor("text") == T.fg.r, "a color saved wrongly is the theme's")
    account.rxpWindowColors = nil
    ns.SetRXPWindowOption("rxpWindowPanel", true)
    ns.SetRXPWindowColor("accent", 1, 0, 0, 1)
    ns.SetRXPWindowTheme("midnight")
    ns.ResetRXPWindowStyle()
    Check(account.rxpWindowPanel == nil and account.rxpWindowColors == nil and account.rxpWindowTheme == nil,
        "reset puts the look back, the window's theme with it")
    account.rxpWindowWidth, account.rxpWindowSteps, account.rxpWindowScale = 400, 3, 120
    ns.ResetRXPWindowStyle()
    Check(account.rxpWindowWidth == 400 and account.rxpWindowSteps == 3 and account.rxpWindowScale == 120,
        "and leaves its size, its width and its steps")
end

-- the bars
do
    local account = { rxpWindow = true, rxpWindowTheme = "custom" }
    local w = Start(account)
    local f = Window(w)
    local T = w.ns.THEME
    Check(f.bar.shown == true and f.rule.shown == false, "under the title: the guide's progress bar to start")
    Check(math.abs(f.bar.value - 36 / 66) < 1e-9 and f.bar.range[1] == 0 and f.bar.range[2] == 1,
        "full as far as the guide is, steps 36 of 66")
    Check(f.bar.height == 5 + 2 and f.bar.barTexture == w.ns.MEDIA .. "NaowhGradient.tga",
        "5 thick inside its border, in the Naowh Gradient")
    Check(f.bar.barColor[1] == T.accent.r and f.bar.barColor[4] == 1, "in the accent")
    Check(f.bar.track.solid[1] == T.fg.r and f.bar.track.solid[4] == 0.5, "over a track of the line's color")
    local box
    for _, o in ipairs(w.frames) do
        if o.label and o.logo then box = o end
    end
    local bars = 0
    for _, o in ipairs(w.frames) do
        if o.track and o.parent == f then bars = bars + 1 end
    end
    Check(box and box.bar == nil and bars == 1 and w.ns.RXPWindowOption("rxpWindowStepBar") == nil,
        "the guide's is the only bar of the window: none between the active step and the list")
    local activeSteps = w.rxp.RXPFrame.activeSteps
    w.rxp.RXPFrame.activeSteps = {}
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(box.shown == false, "with no active step the box goes")
    w.rxp.RXPFrame.activeSteps = activeSteps
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(box.shown == true, "and comes back")
    w.ns.SetRXPWindowOption("rxpWindowLine", "rule")
    Flush(w)
    Check(f.bar.shown == false and f.rule.shown == true and f.rule.solid[4] == 0.5, "a line instead: the bar is not drawn")
    w.ns.SetRXPWindowOption("rxpWindowLine", "none")
    Flush(w)
    Check(f.bar.shown == false and f.rule.shown == false, "or nothing")
    w.ns.SetRXPWindowOption("rxpWindowLine", "bar")
    w.ns.SetRXPWindowOption("rxpWindowBarTexture", "Flat Name")
    Flush(w)
    Check(f.bar.barTexture == "Textures\\Flat Name", "another texture picked is the bar's")
    w.ns.SetRXPWindowOption("rxpWindowBarTexture", "")
    Flush(w)
    Check(f.bar.barTexture == w.ns.MEDIA .. "NaowhGradient.tga", "and none is the Naowh Gradient again")
    w.ns.SetRXPWindowOption("rxpWindowBarTexture", "Flat Name")
    w.ns.SetRXPWindowColor("accent", 1, 0, 0, 0.5)
    w.ns.SetRXPWindowColor("line", 0, 0, 1, 1)
    Flush(w)
    Check(f.bar.height == 5 + 2 and f.bar.barTexture == "Textures\\Flat Name" and f.bar.barColor[1] == 1
        and f.bar.barColor[4] == 0.5 and f.bar.track.solid[3] == 1,
        "the height is fixed, the texture and the colors are its own, and the track follows the line's")
    w.rows[1].complete = true
    w.rxp.GetGuideProgress = function() return 66, "id" end
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(f.bar.value == 1, "the last step is a full bar")
    w.rxp.GetGuideProgress = function() return 0, "id" end
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(f.bar.value == 0, "and none an empty one")
end

-- the arrow has a color of its own with Custom, and is painted again when it or the theme is changed
do
    local account = { rxpWindow = true, rxpWindowTheme = "custom" }
    local w = Start(account)
    local ns = w.ns
    local paints = 0
    ns.RXPPaintArrow = function() paints = paints + 1 end
    ns.SetRXPWindowColor("arrow", 1, 0, 0.5, 1)
    Check(paints == 1 and account.rxpWindowColors.arrow.b == 0.5, "a color picked for the arrow: kept, and the arrow painted")
    Check(select(3, ns.RXPWindowColor("arrow")) == 0.5, "and the arrow's color is that")
    ns.SetRXPWindowTheme("midnight")
    Check(paints == 2, "a theme picked paints it again")
    Check(select(3, ns.RXPWindowColor("arrow")) == ns.THEME_PRESETS.midnight.accent.b, "and the arrow's color is the theme's accent")
    ns.ResetRXPWindowStyle()
    Check(paints == 3, "and so does the reset")
end

-- on the Forever skin: the bronze inset on the box and the window, the skin's rim and field on the bars, its sign
do
    local account = { rxpWindow = true, rxpWindowTheme = "forever" }
    local w = Start(account)
    local f = Window(w)
    local ns = w.ns
    local known = true
    ns.Shared = { Style = { FOREVER_FIELD_RGB = { r = 0.1, g = 0.2, b = 0.3 }, FOREVER_PLUS_ATLAS = "plus",
            FOREVER_MINUS_ATLAS = "minus" },
        Parts = {
            ForeverInset = function(parent)
                local inset = Object(w.everything)
                inset.fill = Object(w.everything)
                inset.of = parent
                return inset
            end,
            ForeverBox = function(frame)
                local rim = { frame = frame, _frame = Object(w.everything) }
                function rim:SetColor() end
                return rim
            end,
            ForeverAtlas = function(texture, name)
                if known then texture.atlas = name end
                return known
            end } }
    local function Boxes()
        local out = {}
        for _, o in ipairs(w.frames) do
            if o.label and o.logo and Seen(o) then out[#out + 1] = o end
        end
        return out
    end
    ns.SetRXPWindowOption("rxpWindowBoxOpacity", 40)
    Flush(w)
    local box = Boxes()[1]
    Check(box.inset and box.inset.shown ~= false and box.inset.of == box, "the box has the skin's inset")
    local solid = box.inset.fill.solid
    Check(solid and math.abs(solid[4] - 0.4) < 1e-9, "its fill has the box's color and opacity")
    Check(box.back.shown == false and box.edge._frame.shown == false, "and the flat back and line are not drawn")
    ns.SetRXPWindowOption("rxpWindowBoxBorder", false)
    Flush(w)
    Check(box.inset.shown == false and box.back.shown ~= false and math.abs(box.back.solid[4] - 0.4) < 1e-9,
        "no border: the inset is not drawn, and the box is the flat back as before")
    ns.SetRXPWindowOption("rxpWindowBoxBorder", true)
    Flush(w)

    local bar = f.bar
    Check(bar.rim and bar.rim.frame == bar and bar.rim._frame.shown ~= false, "the guide's bar has the skin's rim")
    Check(bar.track.solid[1] == 0.1 and bar.track.solid[2] == 0.2 and bar.track.solid[4] == 1, "and the skin's field for its track")

    Check(f.fold.sign.atlas == "minus" and f.fold.sign.shown ~= false and f.fold.text.shown == false,
        "the fold has the skin's minus, not the text")
    f.fold.scripts.OnClick(f.fold)
    Flush(w)
    Check(f.fold.sign.atlas == "plus", "and its plus when folded")
    f.fold.scripts.OnClick(f.fold)
    Flush(w)

    ns.SetRXPWindowOption("rxpWindowBorder", true)
    ns.SetRXPWindowOption("rxpWindowPanel", true)
    Flush(w)
    Check(f.inset and f.inset.shown ~= false and f.back.shown == false and f.borderObject._frame.shown == false,
        "a window with a border: the inset in place of the flat back and line")
    local pr = f.inset.fill.solid
    Check(pr and pr[4] > 0, "with its panel's color")
    ns.SetRXPWindowOption("rxpWindowPanel", false)
    Flush(w)
    Check(f.inset.fill.solid[4] == 0, "no panel: the inset's fill is clear")
    ns.SetRXPWindowOption("rxpWindowBorder", false)
    Flush(w)
    Check(f.inset.shown == false, "no border: no inset")

    known = false
    Flush(w)
    f.fold.scripts.OnClick(f.fold)
    f.fold.scripts.OnClick(f.fold)
    Flush(w)
    Check(f.fold.text.shown ~= false and f.fold.sign.shown == false, "a client without the sign: the text stays")

    ns.SetRXPWindowTheme(nil)
    Flush(w)
    Check(box.inset.shown == false and bar.rim._frame.shown == false and f.fold.sign.shown == false,
        "with the addon's theme and the addon not in the skin: none of it")
    ns.foreverSkin = true
    ns.SetRXPWindowTheme(nil)
    Flush(w)
    Check(box.inset.shown ~= false and bar.rim._frame.shown ~= false,
        "the addon in the skin and the window's theme the addon's: all of it")
    ns.SetRXPWindowTheme("midnight")
    Flush(w)
    Check(box.inset.shown == false and bar.rim._frame.shown == false,
        "and a theme of the presets is not the skin")
    ns.foreverSkin = nil
end

-- the look: panel, borders, menu, spacing and the colors of every text
do
    local account = { rxpWindow = true, rxpWindowTheme = "custom" }
    local w = Start(account)
    local ns = w.ns
    local f = Window(w)
    ns.SetRXPWindowOption("rxpWindowPanel", true)
    ns.SetRXPWindowColor("panel", 0.1, 0.2, 0.3, 0.4)
    ns.SetRXPWindowOption("rxpWindowBorder", true)
    ns.SetRXPWindowColor("border", 0.9, 0.8, 0.7, 0.6)
    Flush(w)
    Check(f.back.shown == true and f.back.solid[1] == 0.1 and f.back.solid[4] == 0.4, "a panel behind the window, in its color")
    Check(f.borderObject._frame.shown == true and f.borderObject.color[1] == 0.9 and f.borderObject.color[4] == 0.6,
        "a border round it, in its color")
    local box
    for _, o in ipairs(w.frames) do
        if o.label and o.logo then box = o end
    end
    Check(box.edge._frame.shown == true and box.edge.color[1] == 0 and box.edge.color[2] == 0
        and box.edge.color[3] == 0 and box.edge.color[4] == 1 and box.edge.pixels == 1,
        "the step's box has its border, black and one pixel: it is not the window's")
    Check(math.abs(box.back.solid[4] - 0.55) < 1e-9, "the box is a little see-through to start")
    ns.SetRXPWindowOption("rxpWindowBoxBorder", false)
    ns.SetRXPWindowColor("box", 0.3, 0.3, 0.3, 0.3)
    ns.SetRXPWindowColor("border", 1, 1, 0, 1)
    Flush(w)
    Check(box.edge._frame.shown == false and box.back.solid[1] == 0.3 and f.borderObject.color[1] == 1,
        "which can be turned off, and has its color, the window's border its own")
    Check(math.abs(box.back.solid[4] - 0.55) < 1e-9 and select(4, ns.RXPWindowColor("box")) == 1,
        "the opacity of the box is not part of its color")
    ns.SetRXPWindowOption("rxpWindowBoxOpacity", 100)
    Flush(w)
    Check(box.back.solid[4] == 1, "its opacity: solid")
    ns.SetRXPWindowOption("rxpWindowBoxOpacity", 0)
    Flush(w)
    Check(box.back.solid[4] == 0, "and none")
    ns.SetRXPWindowOption("rxpWindowBoxOpacity", 30)
    Flush(w)
    Check(math.abs(box.back.solid[4] - 0.3) < 1e-9, "and in between")
    local before = f.height
    ns.SetRXPWindowOption("rxpWindowSpacing", 12)
    Flush(w)
    Check(f.height > before, "more spacing, a taller window")
    ns.SetRXPWindowOption("rxpWindowSpacing", 0)
    Flush(w)
    Check(f.height < before, "less, a shorter one")

    -- every text has its color
    ns.SetRXPWindowColor("title", 1, 0, 0, 1)
    ns.SetRXPWindowColor("accent", 0, 1, 0, 1)
    ns.SetRXPWindowColor("text", 0, 0, 1, 1)
    ns.SetRXPWindowColor("muted", 0, 1, 1, 1)
    Flush(w)
    Check(f.title.color[1] == 1 and f.title.color[2] == 0, "the title's color")
    Check(box.label.color[2] == 1 and box.label.color[1] == 0, "the step label's")
    local rowText, doneText, listText
    for _, o in ipairs(w.everything) do
        if o.text == "Talk to |cff00ff00Duokna|r" then rowText = o end
        if o.text == "Vendor Trash" then doneText = o end
        if o.text and o.text:find("^37  ") then listText = o end
    end
    Check(rowText and rowText.color[3] == 1, "a row's")
    Check(doneText and doneText.color[1] == 0 and doneText.color[2] == 1 and doneText.color[3] == 1,
        "a done row's, the muted color")
    Check(listText and listText.color[1] == 0 and listText.color[2] == 1 and listText.color[3] == 1,
        "and a line in the list, the same")
end

-- the text: its face, its size and how it is kept readable
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local ns = w.ns
    local f = Window(w)
    local function Texts(of)
        local out = {}
        for _, o in ipairs(w.everything) do
            if o.font ~= nil and (of == nil or o.sizeKey == of) then out[#out + 1] = o end
        end
        return out
    end
    local all = Texts()
    Check(#all >= 10, "texts to look at")
    local plain = 0
    for _, o in ipairs(all) do
        if o.font == "Fonts\\Naowh.ttf" and o.fontFlags == "" and o.shadowX == 1 and o.shadowY == -1 then
            plain = plain + 1
        end
    end
    Check(plain == #all, "every text is in the Addon Font with a shadow to start")
    ns.SetRXPWindowOption("rxpWindowFont", "Fira")
    ns.SetRXPWindowOption("rxpWindowOutline", "outline")
    ns.SetRXPWindowOption("rxpWindowTitleSize", 20)
    ns.SetRXPWindowOption("rxpWindowTextSize", 15)
    ns.SetRXPWindowOption("rxpWindowListSize", 9)
    Flush(w)
    for _, size in ipairs({ { "rxpWindowTitleSize", 20 }, { "rxpWindowTextSize", 15 }, { "rxpWindowListSize", 9 } }) do
        local group = Texts(size[1])
        Check(#group > 0, size[1] .. " has texts")
        for _, o in ipairs(group) do
            local bonus = size[1] == "rxpWindowTextSize" and o.fontSize == size[2] + 2
            Check(o.font == "Fonts\\Fira.ttf" and (o.fontSize == size[2] or bonus) and o.fontFlags == "OUTLINE"
                and o.shadowX == 0, size[1] .. ": its face, size (a first line's with its bonus) and outline")
        end
    end
    ns.SetRXPWindowOption("rxpWindowOutline", "thick")
    Flush(w)
    local thick = Texts()[1]
    Check(thick.fontFlags == "THICKOUTLINE" and thick.shadowX == 0, "a thick outline, with no shadow")
    ns.SetRXPWindowOption("rxpWindowOutline", "none")
    Flush(w)
    Check(Texts("rxpWindowListSize")[1].fontFlags == "" and Texts("rxpWindowListSize")[1].shadowX == 0,
        "with none, neither outline nor shadow")
    ns.SetRXPWindowOption("rxpWindowFont", "")
    ns.SetRXPWindowOption("rxpWindowOutline", "shadow")
    Flush(w)
    ns.SetRXPWindowTheme("forever")
    Flush(w)
    Check(f.title.font == "Fonts\\Forever.ttf", "the Forever window theme: the skin's face, with no font picked")
    ns.SetRXPWindowOption("rxpWindowFont", "Fira")
    Flush(w)
    Check(f.title.font == "Fonts\\Fira.ttf", "a font picked is the window's still")
    ns.SetRXPWindowOption("rxpWindowFont", "")
    ns.SetRXPWindowTheme(nil)
    Flush(w)
    Check(f.title.font == "Fonts\\Naowh.ttf", "and the addon's own face again with the addon's theme")
    Check(Texts("rxpWindowTitleSize")[1].font == "Fonts\\Naowh.ttf" and Texts("rxpWindowTitleSize")[1].shadowX == 1,
        "back to the Addon Font and the shadow")
    Check(f.title.fontSize == 20, "the sizes stay")
end

-- the window is resized from its corner: the width, and the steps listed from how tall it is made
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local f = Window(w)
    local ns = w.ns
    local function Lines()
        local count = 0
        for _, o in ipairs(w.everything) do
            if Seen(o) and o.text and o.text:find("^%d+  ") then count = count + 1 end
        end
        return count
    end
    Check(f.resizable == true and f.grip ~= nil and f.grip.shown == true, "resizable, with a grip in its corner")
    local base, line = f.chrome, f.lineHeight
    Check(base > 0 and line > 0 and math.abs((f.height - base) / line - 6) < 1e-9,
        "the height without the list and the height of a line are known: six lines drawn")
    Check(f.resizeBounds[1] == 260 and f.resizeBounds[2] == base and f.resizeBounds[3] == 640
        and f.resizeBounds[4] == base + 12 * line, "its smallest has no steps listed and its biggest all of them")
    f.grip.scripts.OnMouseDown(f.grip)
    Check(f.sizing == "BOTTOMRIGHT", "the grip starts the sizing from its corner")

    -- while it is dragged the window follows, with nothing kept until the grip is let go
    local snapshots = w.rxp.v2.snapshots
    f.width, f.height = 450, base + 2 * line
    f.scripts.OnSizeChanged(f, 450, base + 2 * line)
    Check(Lines() == 2 and account.rxpWindowSteps == nil and account.rxpWindowWidth == nil,
        "dragged to two lines: two are listed, and nothing is kept yet")
    local box
    for _, o in ipairs(w.frames) do
        if o.label and o.logo then box = o end
    end
    Check(box.width == 450 - 20 and f.title.width == 450 - 20 - 16 - 5 - 120,
        "and everything is laid out to the width it has now")
    f.scripts.OnSizeChanged(f, 520, base + 5 * line)
    Check(Lines() == 5 and box.width == 520 - 20, "bigger again: five lines, and wider")
    f.scripts.OnSizeChanged(f, 100, 3)
    Check(Lines() == 0 and box.width == 260 - 20, "smaller than it can be: none, and the narrowest")
    f.scripts.OnSizeChanged(f, 900, base + 40 * line)
    Check(Lines() == 12 and box.width == 640 - 20, "bigger than it can be: all of them, and the widest")
    Check(f.width == 450 and f.height == base + 2 * line, "the size is the dragged one's: the window does not set its own meanwhile")
    Check(w.rxp.v2.snapshots == snapshots, "and what it lists is not read again: it was, once, when the grip was pressed")
    f.width, f.height = 500, base + 3 * line + line / 2
    f.points = { { "TOPLEFT", w.env.UIParent, "TOPLEFT", 40, -60 } }
    f.grip.scripts.OnMouseUp(f.grip)
    Check(f.moving == false and account.rxpWindowWidth == 500 and account.rxpWindowSteps == 3,
        "let go: the width and the steps that fit, and a part of a line is not one")
    Check(f.width == 500 and Lines() == 3 and math.abs(f.height - (base + 3 * line)) < 1e-9,
        "and the window is drawn at that size")
    Check(account.rxpWindowPos and account.rxpWindowPos[3] == 40 and account.rxpWindowPos[4] == -60,
        "the place it ended up in is kept")
    f.width, f.height = 900, base + 40 * line
    f.grip.scripts.OnMouseUp(f.grip)
    Check(account.rxpWindowWidth == 640 and account.rxpWindowSteps == 12 and f.width == 640 and Lines() == 12,
        "bigger than it can be: held to the most")
    f.width, f.height = 100, 5
    f.grip.scripts.OnMouseUp(f.grip)
    Check(account.rxpWindowWidth == 260 and account.rxpWindowSteps == 0 and Lines() == 0,
        "smaller than it can be: held to the least, with no steps listed")
    f.width, f.height = 380, base + 6 * line
    f.grip.scripts.OnMouseUp(f.grip)
    Check(account.rxpWindowWidth == nil and account.rxpWindowSteps == nil, "back to the start: nothing is kept")

    -- locked, and the grip left out
    ns.SetRXPWindowOption("rxpWindowLock", true)
    Flush(w)
    f.sizing = nil
    f.moving = nil
    f.grip.scripts.OnMouseDown(f.grip)
    f.scripts.OnDragStart(f)
    Check(f.sizing == nil and f.moving == nil and f.resizable == false,
        "locked: it is not sized or moved, and is not resizable")
    Check(f.grip.shown == false, "and the grip in the corner is not shown")
    ns.SetRXPWindowOption("rxpWindowLock", false)
    Flush(w)
    Check(f.grip.shown == true, "unlocked: it is back")
    local grips = 0
    for _, option in ipairs(ns.RXPWindowOptions()) do
        if option.label == "Show Resize Grip" or option.key == "rxpWindowGrip" then grips = grips + 1 end
    end
    Check(grips == 0, "there is no setting for the grip: it is how the window is sized")
    account.rxpWindowGrip = false
    ns.RXPWindowRefresh()
    Flush(w)
    Check(f.grip.shown == true and f.resizable == true, "one an older version left off is shown, and the window is resizable")
    account.rxpWindowCollapsed = true
    ns.RXPWindowRefresh()
    Flush(w)
    Check(f.grip.shown == false and f.resizable == false, "folded: there is no list to size, and no grip")
end

-- RestedXP's Active Targets and Active Items windows take the look of the active step
do
    local RXP_EDGE = "Textures\\RXPEdge"
    local RXP_FONT = "Fonts\\RXP.ttf"

    local function Box(w)
        local part = Object(w.everything)
        local fill = Object(w.everything)
        function fill:SetVertexColor(r, g, b, a)
            self.vertex, self.sets = { r, g, b, a }, (self.sets or 0) + 1
        end
        part.rxpBackground = Object(w.everything)
        part.rxpBackground.textures = { fill }
        part.rxpBorder = Object(w.everything)
        part.rxpBorder.textures = {}
        for i = 1, 4 do
            local edge = Object(w.everything)
            function edge:SetTexture(path) self.texture, self.solid = path, nil end
            function edge:SetVertexColor(r, g, b, a) self.vertex = { r, g, b, a } end
            part.rxpBorder.textures[i] = edge
        end
        return part
    end

    -- RestedXP's frame: what its UpdateVisuals paints is its own, each time it is called
    local function Placeholder(w, id)
        local button = Object(w.everything)
        local texture = Object(w.everything)
        texture.id = id
        function texture:GetTexture() return self.id end
        function texture:SetTexture(value) self.id = value end
        button.placeholder = texture
        return button
    end

    local function Satellite(w, title)
        local f = Box(w)
        f.paints = 0
        f.buttons = { Placeholder(w, 2056011), Placeholder(w, 135274), Placeholder(w, 135999) }
        function f:GetChildren() return unpack(self.buttons) end
        f.title = Box(w)
        local text = Object(w.everything)
        text:SetText(title)
        text:SetFont(RXP_FONT, 9, "")
        function text:GetFont() return self.font, self.fontSize, self.fontFlags end
        function text:GetStringWidth() return self.font == RXP_FONT and 60 or 80 end
        f.title.text = text
        local function Paint(part)
            part.rxpBackground.textures[1]:SetVertexColor(0.1, 0.2, 0.3, 0.9)
            for _, edge in ipairs(part.rxpBorder.textures) do
                edge:SetTexture(RXP_EDGE)
                edge:SetVertexColor(0.7, 0.6, 0.5, 1)
            end
        end
        function f:UpdateVisuals()
            self.paints = self.paints + 1
            Paint(self)
            Paint(self.title)
            self.title.text:SetFont(RXP_FONT, 9, "")
            self.title.text:SetTextColor(0.9, 0.9, 0.9)
            self.title:SetSize(70, 19)
        end
        f:UpdateVisuals()
        return f
    end

    local function Begin(account, make)
        local w = World(account)
        local rxp = Rxp(w)
        make(w, rxp)
        for _, f in ipairs(w.frames) do w.boot = f end
        w.boot.scripts.OnEvent(w.boot, "ADDON_LOADED", "NaowhForever")
        w.boot.scripts.OnEvent(w.boot, "PLAYER_LOGIN")
        Flush(w)
        return w
    end

    local function Both(w, rxp)
        rxp.targeting = { activeTargetFrame = Satellite(w, "Active Targets") }
        function rxp.targeting:UpdateTargetFrame() self.updates = (self.updates or 0) + 1 end
        function rxp.targeting:RenderTargetFrameBackground()
            self.activeTargetFrame.rxpBackground.textures[1]:SetVertexColor(0.1, 0.2, 0.3, 0.9)
            self.renders = (self.renders or 0) + 1
        end
        rxp.activeItemFrame = Satellite(w, "Active Items")
    end

    local function Fill(part) return part.rxpBackground.textures[1].vertex end

    local function Is(color, r, g, b, a)
        return color and math.abs(color[1] - r) < 1e-6 and math.abs(color[2] - g) < 1e-6
            and math.abs(color[3] - b) < 1e-6 and math.abs(color[4] - a) < 1e-6
    end

    -- the window off: they are as RestedXP paints them, and are not hooked
    local off = Begin({}, Both)
    local target, items = off.rxp.targeting.activeTargetFrame, off.rxp.activeItemFrame
    Check(Is(Fill(target), 0.1, 0.2, 0.3, 0.9) and target.rxpBorder.textures[1].texture == RXP_EDGE
        and target.title.text.font == RXP_FONT, "the window is off: RestedXP's windows are left as RestedXP paints them")
    target:UpdateVisuals()
    Check(Is(Fill(target), 0.1, 0.2, 0.3, 0.9) and items.paints == 1, "and are painted that way again")

    -- the window on: both take its look, and keep it when RestedXP paints them again
    local account = { rxpWindow = true, rxpWindowTheme = "custom" }
    local w = Begin(account, Both)
    local ns = w.ns
    target, items = w.rxp.targeting.activeTargetFrame, w.rxp.activeItemFrame
    local function Look(frame, name)
        local r, g, b = ns.RXPWindowColor("box")
        local opacity = ns.RXPWindowOption("rxpWindowBoxOpacity") / 100
        local er, eg, eb, ea = ns.RXPWindowColor("boxBorder")
        local label = { ns.RXPWindowColor("title") }
        Check(Is(Fill(frame), r, g, b, opacity), name .. ": the background is the active step's color and opacity")
        Check(Fill(frame.title) and Is(Fill(frame.title), r, g, b, opacity), name .. ": and so is its title's")
        for i, edge in ipairs(frame.rxpBorder.textures) do
            Check(Is(edge.solid, er, eg, eb, ea), name .. ": border " .. i .. " is the active step's border color")
        end
        Check(frame.rxpBorder.shown == true and frame.title.rxpBorder.shown == true, name .. ": the border is shown")
        local text = frame.title.text
        Check(text.font == "Fonts\\Naowh.ttf" and text.fontSize == 9 and text.fontFlags == "" and text.shadowX == 1,
            name .. ": the title is in the window's face and RestedXP's size, with the window's shadow")
        Check(text.color and math.abs(text.color[1] - label[1]) < 1e-6 and math.abs(text.color[3] - label[3]) < 1e-6,
            name .. ": and in the title's color, not the accent")
        Check(frame.title.width == 90 and frame.title.height == 19,
            name .. ": the title is as wide as its text in the window's face, and RestedXP's height")
    end
    Look(target, "targets")
    Look(items, "items")

    local unset = Begin({ rxpWindow = true }, function(world, rxp)
        Both(world, rxp)
        for _, frame in ipairs({ rxp.targeting.activeTargetFrame, rxp.activeItemFrame }) do
            local text = frame.title.text
            text.bad = 0
            function text:SetFont(path, size, flags)
                if type(size) ~= "number" or size <= 0 then self.bad = self.bad + 1 end
                self.font, self.fontSize, self.fontFlags = path, size, flags
            end
            function text:GetFont() return nil, -1566.511841, nil end
        end
    end)
    local broken = unset.rxp.targeting.activeTargetFrame.title.text
    local huge = unset.rxp.activeItemFrame.title.text
    Check(broken.bad == 0 and huge.bad == 0, "a title with no font to read, and a size that is no size, is never given one")
    Check(broken.font == "Fonts\\Naowh.ttf" and broken.fontSize == 9 and huge.fontSize == 9,
        "it is set in the window's face at RestedXP's size, 9")
    huge.GetFont = function() return "Fonts\\RXP.ttf", 5e30, "" end
    unset.rxp.activeItemFrame:UpdateVisuals()
    Flush(unset)
    Check(huge.bad == 0 and huge.fontSize == 9, "and so is one that answers a size out of any range")
    huge.GetFont = function() return nil, 14, nil end
    unset.rxp.activeItemFrame:UpdateVisuals()
    Flush(unset)
    Check(huge.bad == 0 and huge.fontSize == 9, "and one with no face, whatever size it answers")
    huge.GetFont = function() return "Fonts\\RXP.ttf", 12, "" end
    unset.rxp.activeItemFrame:UpdateVisuals()
    Flush(unset)
    Check(huge.bad == 0 and huge.fontSize == 9, "and a readable size gets RestedXP's 9 as well")

    target:UpdateVisuals()
    Look(target, "targets painted again")
    local read = target.title.text.GetFont
    function target.title.text:GetFont() return self.font, -1566.5, self.fontFlags end
    target:UpdateVisuals()
    Look(target, "targets with a junk size from the game")
    target.title.text.GetFont = read
    w.rxp.targeting:RenderTargetFrameBackground()
    local r, g, b = ns.RXPWindowColor("box")
    Check(Is(Fill(target), r, g, b, 0.55) and w.rxp.targeting.renders == 1,
        "RestedXP rendering the background of the targets again does not undo it")

    -- what is set for the window is what they follow
    ns.SetRXPWindowOption("rxpWindowBoxOpacity", 80)
    ns.SetRXPWindowColor("box", 1, 0, 0)
    ns.SetRXPWindowColor("boxBorder", 0, 1, 0, 0.5)
    ns.SetRXPWindowOption("rxpWindowOutline", "outline")
    ns.SetRXPWindowOption("rxpWindowFont", "Fancy")
    Flush(w)
    Check(Is(Fill(target), 1, 0, 0, 0.8) and Is(Fill(items.title), 1, 0, 0, 0.8), "a color and an opacity set for the box")
    Check(Is(target.rxpBorder.textures[3].solid, 0, 1, 0, 0.5), "a border color set for the box")
    Check(items.title.text.font == "Fonts\\Fancy.ttf" and items.title.text.fontFlags == "OUTLINE"
        and items.title.text.shadowX == 0, "a face and an outline set for the window")
    ns.SetRXPWindowOption("rxpWindowBoxBorder", false)
    Flush(w)
    Check(target.rxpBorder.shown == false and items.title.rxpBorder.shown == false, "no border: none is shown")
    ns.SetRXPWindowOption("rxpWindowBoxBorder", true)
    Flush(w)
    Check(target.rxpBorder.shown == true, "and shown again")

    -- hooked once, however often it is drawn
    for _ = 1, 3 do
        ns.SetRXPWindowOption("rxpWindowSpacing", 6)
        Flush(w)
    end
    local fill = target.rxpBackground.textures[1]
    fill.sets = 0
    target:UpdateVisuals()
    Check(fill.sets == 2, "RestedXP paints it once and the window once, however often the window was drawn")
    ns.SetRXPWindowOption("rxpWindowSpacing", 5)
    Flush(w)

    -- RestedXP hides the background of a window: the border is not shown without it
    target.rxpBackground:Hide()
    target.rxpBorder:Hide()
    target:UpdateVisuals()
    Check(target.rxpBorder.shown == false and Is(Fill(target), 1, 0, 0, 0.8),
        "a background RestedXP hides keeps its border hidden")
    target.rxpBackground:Show()
    target.rxpBorder:Show()

    -- a frame RestedXP makes later is taken at the next draw
    local late = Begin({ rxpWindow = true }, function(world, rxp)
        rxp.targeting = { activeTargetFrame = Satellite(world, "Active Targets") }
    end)
    local lr, lg, lb = late.ns.RXPWindowColor("box")
    Check(late.rxp.activeItemFrame == nil and Is(Fill(late.rxp.targeting.activeTargetFrame), lr, lg, lb, 0.55),
        "one of the two is not there yet, and the other has the look")
    late.rxp.activeItemFrame = Satellite(late, "Active Items")
    Check(Is(Fill(late.rxp.activeItemFrame), 0.1, 0.2, 0.3, 0.9), "it is painted as RestedXP paints it")
    late.rxp.SetStep()
    Flush(late)
    Check(Is(Fill(late.rxp.activeItemFrame), lr, lg, lb, 0.55), "and has the look of the window at the next draw")

    -- a border the window hid is shown again when RestedXP's own look is
    ns.SetRXPWindowOption("rxpWindowBoxBorder", false)
    Flush(w)
    Check(items.rxpBorder.shown == false and items.title.rxpBorder.shown == false, "the border is hidden to begin with")
    ns.SetRXPWindow(false)
    Flush(w)
    Check(items.rxpBorder.shown == true and items.title.rxpBorder.shown == true and target.title.rxpBorder.shown == true,
        "a border the window hid is shown again with RestedXP's own look")
    ns.SetRXPWindow(true)
    ns.SetRXPWindowOption("rxpWindowBoxBorder", true)
    Flush(w)
    Check(Is(Fill(items), 1, 0, 0, 0.8), "the window on again: the look is back")

    -- the window turned off: they are RestedXP's again, and RestedXP paints its own, then not hooked into any more
    ns.SetRXPWindow(false)
    Flush(w)
    Check(target.paints >= 3 and Is(Fill(target), 0.1, 0.2, 0.3, 0.9) and target.rxpBorder.textures[1].texture == RXP_EDGE
        and target.rxpBorder.textures[1].solid == nil and target.title.text.font == RXP_FONT
        and target.rxpBorder.shown == true, "turned off: RestedXP's own look is back, border and all")
    local paints = items.paints
    items:UpdateVisuals()
    Check(items.paints == paints + 1 and Is(Fill(items), 0.1, 0.2, 0.3, 0.9) and items.title.text.font == RXP_FONT,
        "and what RestedXP paints is left as it is")
    Check(Is(Fill(items), 0.1, 0.2, 0.3, 0.9) and Is(Fill(target.title), 0.1, 0.2, 0.3, 0.9)
        and items.title.text.font == RXP_FONT and items.rxpBorder.textures[2].texture == RXP_EDGE,
        "the window turned off: RestedXP's own look is back")
    target:UpdateVisuals()
    Check(Is(Fill(target), 0.1, 0.2, 0.3, 0.9), "and stays")

    -- the placeholders of the target buttons are the new icons, with the window on and a style picked
    local buttons = target.buttons
    ns.RXPIconTexture = function(glyph) return "Ours\\" .. glyph end
    ns.SetRXPWindow(true)
    Flush(w)
    Check(buttons[1].placeholder.id == "Ours\\gossip" and buttons[2].placeholder.id == "Ours\\combat",
        "RestedXP's chat bubble and sword placeholders are ours")
    Check(buttons[3].placeholder.id == 135999, "and any other picture is left as it is")
    buttons[1].placeholder:SetTexture(2056011)
    w.rxp.targeting:UpdateTargetFrame()
    Check(buttons[1].placeholder.id == "Ours\\gossip", "RestedXP putting its placeholder back is put right again")
    ns.RXPIconTexture = function() return nil end
    buttons[2].placeholder:SetTexture(135274)
    target:UpdateVisuals()
    Check(buttons[2].placeholder.id == 135274, "no style picked: RestedXP's own placeholder stays")
    ns.RXPIconTexture = function(glyph) return "Ours\\" .. glyph end
    target:UpdateVisuals()
    ns.SetRXPWindow(false)
    Flush(w)
    Check(buttons[1].placeholder.id == 2056011 and buttons[2].placeholder.id == 135274,
        "the window off: RestedXP's placeholders are back")
end

-- the icons of ours are drawn as a texture in the window's accent, as it is now
do
    local account = { rxpWindow = true, rxpWindowTheme = "custom" }
    local w = Start(account)
    local ns = w.ns
    local T = ns.THEME
    T.accent = { r = 0.1, g = 0.8, b = 0.4 }
    local function Rows()
        local out = {}
        for _, o in ipairs(w.frames) do
            if o.glyph and Seen(o) then out[#out + 1] = o end
        end
        return out
    end
    local function Row(text)
        for _, o in ipairs(Rows()) do
            if o.text and o.text.text == text then return o end
        end
    end
    local function Is(color, r, g, b)
        return color and math.abs(color[1] - r) < 1e-9 and math.abs(color[2] - g) < 1e-9
            and math.abs(color[3] - b) < 1e-9
    end
    local before = Row("Talk to |cff00ff00Duokna|r")
    Check(before and before.glyph.shown == false and before.icon.text == "|Ttalk|t",
        "RestedXP's own icon is its text, and no texture is shown")

    w.talk.frame.icon:SetText(("|T%s:0:0:0:0:64:64:0:64:0:64:1:2:3|t"):format(ns.RXPIconPath("line", "goto")))
    w.buy.frame.icon:SetText(("|T%s:0|t"):format(ns.RXPIconPath("filled", "vendor")))
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    local talk, buy, vendor = Row("Talk to |cff00ff00Duokna|r"), Row("Buy [Refreshing Spring Water] from her"), Row("Vendor Trash")
    Check(talk.glyph.shown and talk.glyph.texture == ns.RXPIconPath("line", "goto") and talk.icon.text == "",
        "an icon of ours: its texture, and no text")
    Check(Is(talk.glyph.vertex, 0.1, 0.8, 0.4), "in the accent")
    Check(talk.glyph.width == 22 and talk.glyph.height == 22, "as big as the row's icon is: the title's, 18 and the bonus twice")
    Check(talk.glyph.alpha == 1, "whole when the row is not done")
    local r, g, b = ns.RXPIconColor()
    Check(buy.glyph.texture == ns.RXPIconPath("filled", "vendor") and Is(buy.glyph.vertex, r, g, b),
        "in the other style as well")
    Check(vendor.glyph.shown == false and vendor.icon.text == "|Tv|t", "and a row with RestedXP's own is as it was")

    ns.SetRXPWindowColor("accent", 1, 0, 0)
    Flush(w)
    Check(Is(Row("Talk to |cff00ff00Duokna|r").glyph.vertex, 1, 0, 0), "the window's Accent Color picked is drawn as it is")
    ns.SetRXPWindowColor("accent", nil)
    Flush(w)
    Check(Is(Row("Talk to |cff00ff00Duokna|r").glyph.vertex, 0.1, 0.8, 0.4), "and put back")

    w.talk.frame.button.GetChecked = function() return true end
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(Row("Talk to |cff00ff00Duokna|r").glyph.alpha == 0.5, "a row that is done has its icon dimmed")

    ns.SetRXPWindowOption("rxpWindowTextSize", 20)
    Flush(w)
    Check(Row("Talk to |cff00ff00Duokna|r").glyph.width == 22, "the text's size is not its size")
    local big = Row("Talk to |cff00ff00Duokna|r")
    Check(big.glyph.width == 22 and big.glyph.height == 22, "it is as big as the icon size, and the bonus twice")
    ns.SetRXPWindowOption("rxpWindowTextSize", 13)

    w.talk.frame.icon:SetText("|Ttalk|t")
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    local back = Row("Talk to |cff00ff00Duokna|r")
    Check(back.glyph.shown == false and back.icon.text == "|Ttalk|t", "a row that is RestedXP's own again is its text again")

    -- the speech bubble in the text of a row is ours as well
    w.talk.frame.icon:SetText("|Ttalk|t")
    w.talk.frame.text:SetText("|Tinterface/worldmap/chatbubble_64grey.blp:20|t Talk to Duokna")
    ns.SetRXPIconStyle("line")
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    local function Spoken()
        for _, o in ipairs(w.everything) do
            if o.text and o.text:find("Talk to Duokna", 1, true) and Seen(o) then return o.text end
        end
    end
    local bubble = Spoken()
    Check(bubble and bubble:find(ns.RXPIconPath("line", "gossip"), 1, true) and not bubble:find("chatbubble", 1, true),
        "the speech bubble in a row's text is ours")
    ns.SetRXPIconStyle(nil)
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    local kept = Spoken()
    Check(kept and kept:find("chatbubble", 1, true), "and RestedXP's own with no style")

    w.talk.frame.text:SetText("Talk to |cff00ff00Duokna|r")
end

-- a row that counts has a bar of its own: the items in the bags for a buy, the numbers in a counted line
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local f = Window(w)
    local ns = w.ns
    local BAGS = "BAG_UPDATE_DELAYED"
    local function Row(text)
        for _, o in ipairs(w.frames) do
            if o.meter and o.text and o.text.text == text and Seen(o) then return o end
        end
    end
    local function Meters()
        local count = 0
        for _, o in ipairs(w.frames) do
            if o.meter and Seen(o) and o.meter.shown then count = count + 1 end
        end
        return count
    end
    local BUY = "Buy [Refreshing Spring Water] from her"
    Check(Meters() == 0 and (f.events == nil or f.events[BAGS] == nil), "nothing counts to start: no bar, and no event")

    w.buy.id, w.buy.qty = 159, 5
    w.items[159] = 2
    ns.RXPWindowRefresh()
    Flush(w)
    local buy = Row(BUY)
    Check(buy.meter.shown and math.abs(buy.meter.value - 0.4) < 1e-9, "buy five with two in the bags: two fifths")
    Check(buy.meter.points[1][4] == 2 + 5 + 23 and buy.meter.width == buy.width - 2 - 5 - 23 and buy.height == 18 + 2 + 5 + 2,
        "under the text as wide as it, and the row is as tall as both")
    Check(f.events and f.events[BAGS] == true, "and the bags are listened to")

    w.items[159] = 4
    f.scripts.OnEvent(f, BAGS)
    Flush(w)
    Check(math.abs(Row(BUY).meter.value - 0.8) < 1e-9, "a bag update draws it again: four fifths")
    w.items[159] = 9
    f.scripts.OnEvent(f, BAGS)
    Flush(w)
    Check(Row(BUY).meter.value == 1, "more than needed is a full bar")

    w.buy.frame.button.GetChecked = function() return true end
    w.items[159] = 0
    f.scripts.OnEvent(f, BAGS)
    Flush(w)
    Check(Row(BUY).meter.value == 1, "a buy that is done is full whatever is left in the bags: they were used or sold")
    w.buy.frame.button.GetChecked = function() return false end
    w.items[159] = 9

    w.buy.qty = 1
    ns.RXPWindowRefresh()
    Flush(w)
    Check(Meters() == 0 and f.events[BAGS] == nil, "one of something is not a count: no bar, and the bags are let go")

    w.talk.frame.text:SetText("|cff00ff00Boar Meat|r: |cffffd1003/8|r")
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    local talk = Row("|cff00ff00Boar Meat|r: |cffffd1003/8|r")
    Check(talk and talk.meter.shown and math.abs(talk.meter.value - 3 / 8) < 1e-9, "a line that counts: three of eight")
    Check(f.events[BAGS] == nil, "and needs no bags: RestedXP changes its text")
    w.talk.frame.button.GetChecked = function() return true end
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(math.abs(talk.meter.value - 3 / 8) < 1e-9,
        "a row RestedXP says is done keeps what its text counts: three of eight, not a full bar")
    w.talk.frame.text:SetText("|cff00ff00Boar Meat|r: |cffffd1008/8|r")
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(Row("|cff00ff00Boar Meat|r: |cffffd1008/8|r").meter.value == 1, "and eight of eight is full")
    w.talk.frame.text:SetText("|cff00ff00Boar Meat|r: |cffffd1000/8|r")
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(Row("|cff00ff00Boar Meat|r: |cffffd1000/8|r").meter.value == 0, "none of eight is an empty bar, done or not")
    w.talk.frame.button.GetChecked = function() return false end
    w.talk.frame.text:SetText("Kill 12/10 Boars")
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(Row("Kill 12/10 Boars").meter.value == 1, "past its count is full")
    w.talk.frame.text:SetText("Talk to 1/1 Duokna")
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(Meters() == 0, "1/1 is not a count")

    w.buy.id, w.buy.qty = "Refreshing Spring Water", 5
    ns.RXPWindowRefresh()
    Flush(w)
    Check(Meters() == 0, "a buy that is of an item by name has nothing to count in the bags")
    w.buy.id = 159

    w.talk.frame.text:SetText("Talk to |cff00ff00Duokna|r")
    w.vendor.tag, w.vendor.id, w.vendor.qty = "vendor", 5, 9
    w.buy.qty = 5
    w.items[159] = 1
    Flush(w)
    Check(Meters() == 1 and Row(BUY).meter.shown, "the buy only, and not a row that is not a buy with an id")
    Check(f.events[BAGS] == true, "and the bags are listened to again")

    ns.SetRXPWindow(false)
    Flush(w)
    Check(f.events[BAGS] == nil, "the window turned off: the bags are let go")
end

-- RestedXP's logo in the corner of the current step's box
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local f = Window(w)
    local LOGO = "Interface\\AddOns\\RXPGuides\\Textures\\rxp_logo-64"
    local function Boxes()
        local out = {}
        for _, o in ipairs(w.frames) do
            if o.label and o.logo and Seen(o) then out[#out + 1] = o end
        end
        return out
    end
    local boxes = Boxes()
    Check(#boxes == 1 and boxes[1].logo.shown and boxes[1].logo.texture == LOGO,
        "RestedXP's logo, from RestedXP's own files, is in the current step's box")
    local logo = boxes[1].logo
    Check(logo.points[1][1] == "TOPRIGHT" and logo.points[1][2] == boxes[1] and logo.points[1][3] == "TOPRIGHT"
        and logo.points[1][4] == -7 and logo.points[1][5] == -7, "in its top right corner")
    Check(logo.width == 24 and logo.height == 24, "24 to start, bigger than the step's text")
    Check(f.title.points[1][4] == 31 and f.title.width == 380 - 10 - 31 - 120,
        "and the guide's name has all its room")
    local firstRow
    for _, o in ipairs(w.frames) do
        if o.icon and o.text and o.bar and o.parent == boxes[1] and not firstRow then firstRow = o end
    end
    Check(firstRow.points[1][5] == -7 - 24 - 5, "the rows start below it")

    -- with a second active step, only the first has it
    local second = { active = true, index = 37, title = "Step 37", elements = { w.buy } }
    local steps = w.rxp.RXPFrame.activeSteps
    w.rxp.RXPFrame.activeSteps = { steps[1], second }
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    boxes = Boxes()
    Check(#boxes == 2 and boxes[1].logo.shown and boxes[2].logo.shown == false, "with two steps, it is the first one's")
    local second_row
    for _, o in ipairs(w.frames) do
        if o.icon and o.text and o.bar and o.parent == boxes[2] and not second_row then second_row = o end
    end
    Check(second_row.points[1][5] == -7 - 13 - 5, "and the rows of the other start below the label")
    w.rxp.RXPFrame.activeSteps = steps
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    boxes = Boxes()
    Check(#boxes == 1 and boxes[1].logo.shown, "and back with one")
end

-- the icon at the start of a row has a size of its own, and the text is set against it
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local ns = w.ns
    local function First()
        local seen = 0
        for _, o in ipairs(w.frames) do
            if o.icon and o.text and o.bar and Seen(o) then
                seen = seen + 1
                if seen == 2 then return o end
            end
        end
    end
    Flush(w)
    local row = First()
    Check(row.icon.fontSize == 18, "18 to start, bigger than the text")
    Check(row.text.points[1][4] == 2 + 5 + 18 + 5 and row.text.points[1][5] == -2,
        "the text starts after it, and is dropped to the middle of it")
    Check(row.height >= 18, "and the row is as tall as it")
    Check(row.text.width == row.width - 2 - 5 - 23, "and has that much less room")
    ns.SetRXPWindowOption("rxpWindowTextSize", 24)
    Flush(w)
    row = First()
    Check(row.icon.fontSize == 18 and row.text.points[1][4] == 2 + 5 + 18 + 5 and row.text.points[1][5] == 0,
        "the icon keeps its size when the text is bigger than it: not dropped")
end

-- the first line of a step is bigger than its sub tasks by a little
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local ns = w.ns
    local function Rows()
        local out = {}
        for _, o in ipairs(w.frames) do
            if o.icon and o.text and o.bar and Seen(o) then out[#out + 1] = o end
        end
        return out
    end
    local rows = Rows()
    Check(#rows == 3 and rows[1].text.fontSize == 15 and rows[2].text.fontSize == 13 and rows[3].text.fontSize == 13,
        "the first is two bigger than the text of its sub tasks to start")
    Check(rows[1].icon.fontSize == 22 and rows[2].icon.fontSize == 18, "and its icon is bigger: the bonus twice")
    ns.SetRXPWindowOption("rxpWindowTextSize", 16)
    Flush(w)
    rows = Rows()
    Check(rows[1].text.fontSize == 18 and rows[2].text.fontSize == 16, "and it follows the text's size")

    -- a row that was the first and is not is the text's size again
    local steps = w.rxp.RXPFrame.activeSteps
    w.rxp.RXPFrame.activeSteps = { { active = true, index = 37, title = "Step 37", elements = { w.buy } }, steps[1] }
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    rows = Rows()
    Check(#rows == 4 and rows[1].text.fontSize == 18 and rows[2].text.fontSize == 18 and rows[3].text.fontSize == 16
        and rows[4].text.fontSize == 16, "each step has its first line bigger")
    w.rxp.RXPFrame.activeSteps = steps
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    rows = Rows()
    Check(#rows == 3 and rows[1].text.fontSize == 18 and rows[2].text.fontSize == 16 and rows[3].text.fontSize == 16,
        "and back to one step: the others are the text's size again")
end

-- the title of a step has no bar at its side, and its icon is bigger
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local function Rows()
        local out = {}
        for _, o in ipairs(w.frames) do
            if o.icon and o.text and o.bar and Seen(o) then out[#out + 1] = o end
        end
        return out
    end
    local rows = Rows()
    Check(#rows == 3 and rows[1].bar.shown == false and rows[2].bar.shown == true and rows[3].bar.shown == true,
        "the first line has no bar at its side, the sub tasks have theirs")
    Check(rows[1].icon.fontSize == 22 and rows[2].icon.fontSize == 18 and rows[3].icon.fontSize == 18,
        "and its icon is bigger: the bonus twice over")
    Check(rows[1].text.points[1][4] == 2 + 5 + 22 + 5 and rows[1].height >= 22, "the text and the row make room for it")
    local steps = w.rxp.RXPFrame.activeSteps
    w.rxp.RXPFrame.activeSteps = { { active = true, index = 37, title = "Step 37", elements = { w.buy } }, steps[1] }
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    rows = Rows()
    Check(#rows == 4 and rows[1].bar.shown == false and rows[2].bar.shown == false and rows[3].bar.shown == true
        and rows[4].bar.shown == true, "each step's first line has none")
    w.rxp.RXPFrame.activeSteps = steps
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    rows = Rows()
    Check(#rows == 3 and rows[1].bar.shown == false and rows[2].bar.shown == true and rows[3].bar.shown == true,
        "and a row that was a first and is not has its bar again")
end

-- a step that stays active beside the guide's own (a trainer to see) is skipped by its objectives
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local rxp = w.rxp
    local went = {}
    rxp.SetStep = function(n) went[#went + 1] = n end
    rxp.updateSteps = false
    local completes, mapped = 0, 0
    rxp.UpdateMap = function() mapped = mapped + 1 end
    local function Element(text)
        local frame = { text = Object(w.everything), icon = Object(w.everything), button = Object(w.everything) }
        frame.text:SetText(text)
        frame.icon:SetText("|Ttrain|t")
        function frame.button:GetChecked() return false end
        return { text = text, tag = "trainer", frame = frame,
            OnComplete = function() completes = completes + 1 end }
    end
    local train, learn = Element("Train your pet skills"), Element("Learn the skills")
    local optional = Element("An optional thing")
    optional.optional = true
    local sticky = { active = true, index = 20, sticky = true, title = "Step 20", elements = { train, learn, optional } }
    rxp.RXPFrame.activeSteps = { sticky, w.active }
    rxp.v2:UpdateGuideWindow()
    Flush(w)
    local rows = {}
    for _, o in ipairs(w.frames) do
        if o.icon and o.text and o.bar and o.scripts.OnClick and Seen(o) then
            local first = true
            for _, r in ipairs(rows) do
                if r.step == o.step then first = false end
            end
            if first then rows[#rows + 1] = o end
        end
    end
    Check(#rows == 2, "two steps, each with a first line")
    w.shift = true
    rows[1].scripts.OnClick(rows[1])
    Check(#went == 0, "the step that stays is not a step to go to")
    Check(train.skip == true and learn.skip == true and optional.skip == nil,
        "its objectives are skipped, and one that is optional is not")
    Check(completes == 2 and rxp.updateSteps == true and mapped == 1,
        "as RestedXP's checkbox does it: each completes once, and the steps are asked to be looked at")
    rows[1].scripts.OnClick(rows[1])
    Check(completes == 2, "and not again")
    rows[2].scripts.OnClick(rows[2])
    Check(#went == 1 and went[1] == 37, "the guide's own step goes to the next one as it did")
    Check(w.active.elements[1].skip == nil, "and its objectives are not touched")

    -- the box of the step that stays does it as well
    train.skip, learn.skip = nil, nil
    completes = 0
    sticky.elements = { train, learn, optional }
    local boxes = {}
    for _, o in ipairs(w.frames) do
        if o.label and o.logo and Seen(o) then boxes[#boxes + 1] = o end
    end
    local stickyBox
    for _, b in ipairs(boxes) do
        if b.step == sticky then stickyBox = b end
    end
    Check(stickyBox ~= nil and #boxes == 2, "each box knows its step")
    stickyBox.scripts.OnClick(stickyBox)
    Check(train.skip == true and learn.skip == true and #went == 1, "a click on the box is that step's, and not the guide's")

    -- an objective that has nothing to run and a step with none
    sticky.elements = { { text = "Nothing to run" } }
    rows[1].scripts.OnClick(rows[1])
    Check(sticky.elements[1].skip == true, "an element without anything to run is skipped too")
    sticky.elements = { { text = "Raises", OnComplete = function() error("complete") end } }
    rows[1].scripts.OnClick(rows[1])
    Check(#w.reported == 1 and w.reported[1]:find("complete", 1, true), "an objective that raises is reported and not raised")
end

-- the window and the old theme are never both on
do
    local account = { rxpThemes = true }
    local w = Start(account)
    local ns = w.ns
    Check(ns.RXPThemesEnabled() == true and ns.RXPWindowEnabled() == false, "the theme on, the window off")
    ns.SetRXPWindow(true)
    Check(account.rxpWindow == true and account.rxpThemes == nil and ns.RXPThemesEnabled() == false,
        "the window turned on turns the old theme off")
    ns.SetRXPThemes(true)
    Check(account.rxpThemes == true and account.rxpWindow == nil and ns.RXPWindowEnabled() == false
        and ns.RXPThemesEnabled() == true, "and the theme turned on turns the window off")
    account.rxpWindow, account.rxpThemes = true, true
    Check(ns.RXPThemesEnabled() == false and ns.RXPWindowEnabled() == true, "saved both on: the window is used")

    -- the arrow was the theme's to follow: it stays as it was when the window takes the theme's place
    local kept = { rxpThemes = true }
    local keptWorld = Start(kept)
    Check(keptWorld.ns.RXPArrowEnabled() == true, "the arrow follows the theme that is on")
    keptWorld.ns.SetRXPWindow(true)
    Check(kept.rxpThemes == nil and kept.rxpArrowOn == true and keptWorld.ns.RXPArrowEnabled() == true,
        "the window turned on: the theme is off and the arrow is still on")
end

-- with no guide (a character that has not picked one) ours says so, has the list of guides, and RestedXP's welcome is not shown twice
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local f = Window(w)
    local ns = w.ns
    Check(f.shown and w.guide.frame.alpha == 0 and w.guide.frame.mouse == false, "with a guide: RestedXP's window is taken")
    local guide = w.rxp.currentGuide
    w.rxp.currentGuide = nil
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(f.shown and f.title.text:find("No guide selected", 1, true), "no guide: the window says so")
    Check(w.guide.frame.alpha == 0 and w.guide.frame.mouse == false,
        "and RestedXP's own welcome is taken too: it would say the same twice")
    local pick
    for _, o in ipairs(w.frames) do
        if o.shade and o.menu == true and Seen(o) then pick = o end
    end
    local lineText
    for _, o in ipairs(w.everything) do
        if o.text == "Pick a guide" and Seen(o) then lineText = o end
    end
    Check(pick ~= nil and lineText ~= nil, "with a line, and a button over it, to pick one")
    local menus, picks = w.menus, w.picks
    pick.scripts.OnClick(pick, "LeftButton")
    Check(w.picks == picks + 1 and w.menus == menus,
        "which opens RestedXP's list of guides, with no shift: there is nothing to skip")
    local list = w.rxp.v2.ShowGuideSelectionMenu
    w.rxp.v2.ShowGuideSelectionMenu = nil
    pick.scripts.OnClick(pick, "LeftButton")
    Check(w.menus == menus + 1, "and its menu when it has no such list")
    w.rxp.v2.ShowGuideSelectionMenu = function() error("pick") end
    pick.scripts.OnClick(pick, "LeftButton")
    Check(#w.reported == 1 and w.reported[1]:find("pick", 1, true), "a list that raises is reported and not raised")
    w.rxp.v2.ShowGuideSelectionMenu = list
    pick.scripts.OnEnter(pick)
    Check(w.env.GameTooltip.text == "Pick a guide" and pick.shade.shown, "and says so")
    local lit = w.ns.THEME.accent
    Check(w.env.GameTooltip.titleColor[1] == lit.r and w.env.GameTooltip.titleColor[2] == lit.g,
        "in the accent, as the others' are")
    ns.SetRXPWindowOption("rxpWindowSkip", "off")
    pick.scripts.OnLeave(pick)
    pick.scripts.OnEnter(pick)
    Check(pick.shade.shown == true, "also with skipping off")
    ns.SetRXPWindowOption("rxpWindowSkip", "shift")
    w.rxp.currentGuide = guide
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(f.shown and w.guide.frame.alpha == 0 and w.guide.frame.mouse == false and f.title.text:find("Durotar", 1, true),
        "and with a guide again it is the guide's, and RestedXP's is taken again")
    local lines = 0
    for _, o in ipairs(w.everything) do
        if o.text == "Pick a guide" and Seen(o) then lines = lines + 1 end
    end
    Check(lines == 0 and pick.menu == false, "and the line to pick one is gone")
end

-- a line that begins with an icon has it in the icon column, as a row with an icon of its own does
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local ns = w.ns
    local function Row(text)
        for _, o in ipairs(w.frames) do
            if o.glyph and o.text and o.text.text == text and Seen(o) then return o end
        end
    end
    local function Draw()
        w.rxp.v2:UpdateGuideWindow()
        Flush(w)
    end
    local BUBBLE = "|Tinterface/worldmap/chatbubble_64grey.blp:20|t"

    w.talk.frame.icon:SetText("")
    w.talk.frame.text:SetText(BUBBLE .. " Talk to Duokna")
    Draw()
    local row = Row("Talk to Duokna")
    Check(row and row.icon.text == "|Tinterface/worldmap/chatbubble_64grey.blp:0|t" and row.glyph.shown == false,
        "the icon a line begins with is the row's, as tall as the text, and the line is without it")

    ns.SetRXPIconStyle("line")
    Draw()
    row = Row("Talk to Duokna")
    Check(row.glyph.shown and row.glyph.texture == ns.RXPIconPath("line", "gossip") and row.icon.text == "",
        "and ours when there is a style, drawn as a texture in the column")

    w.talk.frame.text:SetText("  |T134419:0|t Talk to Duokna")
    Draw()
    row = Row("Talk to Duokna")
    Check(row and row.icon.text == "|T134419:0|t", "whatever room there is before it and after it")

    w.talk.frame.text:SetText("|TInterface/x.blp:0:0:0:0:64:64:0:64:0:64:1:2:3|t Talk to Duokna")
    Draw()
    row = Row("Talk to Duokna")
    Check(row and row.icon.text == "|TInterface/x.blp:0:0:0:0:64:64:0:64:0:64:1:2:3|t", "an icon with more to it is as it was")

    w.talk.frame.icon:SetText("|Ttalk|t")
    w.talk.frame.text:SetText("|T134419:0|t Talk to Duokna")
    Draw()
    row = Row("|T134419:0|t Talk to Duokna")
    Check(row and row.icon.text == "|Ttalk|t", "a row that has an icon of its own keeps the one in its line where it is")

    w.talk.frame.icon:SetText("")
    w.talk.frame.text:SetText("Kill |T134419:0|t the boars")
    Draw()
    row = Row("Kill |T134419:0|t the boars")
    Check(row and row.icon.text == "" and row.glyph.shown == false, "and an icon in the middle of a line is left there")
    ns.SetRXPIconStyle(nil)
end

-- the items listed under a line are set in under its text, as an item is not the marker of a row
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local function Rows()
        local out = {}
        for _, o in ipairs(w.frames) do
            if o.icon and o.text and o.bar and Seen(o) then out[#out + 1] = o end
        end
        return out
    end
    local function Draw()
        w.rxp.v2:UpdateGuideWindow()
        Flush(w)
    end
    w.talk.frame.text:SetText("Buy the following items:")
    w.buy.frame.icon:SetText("")
    w.buy.frame.text:SetText("|T135641:0|t (Darkshore Grouper)")
    w.vendor.frame.icon:SetText("")
    w.vendor.frame.text:SetText("|TInterface\\Icons\\INV_Misc_Food_01:0|t (Strider Meat)")
    Draw()
    local rows = Rows()
    Check(#rows == 3 and rows[2].points[1][4] == 7 + 12 + 23 and rows[3].points[1][4] == 7 + 12 + 23,
        "an item's icon at the start of a line: the line is set in as far as the icon column")
    Check(rows[1].points[1][4] == 7 and rows[2].width == 380 - 20 - 14 - 12 - 23,
        "the first line is not, and a nested one is that much narrower")
    Check(rows[2].icon.text == "|T135641:0|t" and rows[2].text.text == "(Darkshore Grouper)",
        "and the icon is lifted into the column of the line as it is")
    Check(rows[2].bar.shown == false and rows[3].bar.shown == false,
        "and such a line has no bar at its side: what RestedXP tracks there is not what is in the bags")

    w.vendor.frame.text:SetText("|Tinterface/worldmap/chatbubble_64grey.blp:20|t Talk to him")
    Draw()
    rows = Rows()
    Check(rows[3].points[1][4] == 7 + 12, "the speech bubble of a Talk to is a marker: set in as a sub task is")
    Check(rows[3].bar.shown == true, "and it has its bar, as a sub task has")

    w.vendor.frame.text:SetText("|T135641:0|t (Strider Meat)")
    w.vendor.frame.icon:SetText("|Ttalk|t")
    Draw()
    rows = Rows()
    Check(rows[3].points[1][4] == 7 + 12, "a row with an icon of its own keeps its place")

    w.talk.frame.icon:SetText("")
    w.talk.frame.text:SetText("|T135641:0|t (First)")
    Draw()
    rows = Rows()
    Check(rows[1].points[1][4] == 7, "and the first line of a step is never set in")
    w.vendor.frame.icon:SetText("")
    Draw()
    rows = Rows()
    Check(rows[3].points[1][4] == 7 + 12 + 23, "the column it is set in by is the icon's, and its gap")
end

-- a step that lists items under a line has the bars of its counts, and not the bar at the side of the items
do
    local account = { rxpWindow = true }
    local w = Start(account)
    local function Meters()
        local count = 0
        for _, o in ipairs(w.frames) do
            if o.meter and Seen(o) and o.meter.shown then count = count + 1 end
        end
        return count
    end
    w.buy.id, w.buy.qty = 159, 5
    w.items[159] = 2
    w.talk.frame.text:SetText("Strider Meat: 5/5")
    w.vendor.frame.icon:SetText("")
    w.vendor.frame.text:SetText("|T135641:0|t (Darkshore Grouper)")
    w.rxp.v2:UpdateGuideWindow()
    Flush(w)
    Check(Meters() == 2, "the counted line and the buy have their bars with an item listed in the step")
    local sides = {}
    for _, o in ipairs(w.frames) do
        if o.icon and o.text and o.bar and Seen(o) then sides[#sides + 1] = o.bar.shown end
    end
    Check(#sides == 3 and sides[1] == false and sides[2] == true and sides[3] == false,
        "while the item's line has no bar at its side")
end

print("PASS rxp window: " .. cases .. " checks")

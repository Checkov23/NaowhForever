-- The onboarding window on stub frames, driving the real engine (Core/Onboarding/Setup.lua on
-- Tools/regression/setup_world.lua): the welcome, each step's tiles and defaults, Back and Next, the
-- skin previews in each skin's own colors and fonts, the summary's lines, Apply in and out of
-- combat, closing changes nothing, and a new character's page (same as its main, or set up on its
-- own). From the repo root: lua5.1 Tools/regression/test-setup-window.lua
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local World = dofile("Tools/regression/setup_world.lua")
local St = dofile("Tools/regression/shared_style.lua")

local function Noop() end
local META = { __index = function(_, k) if type(k) == "string" and k:match("^%u") then return Noop end end }
local made = {}

local function Frame()
    local f = setmetatable({ shown = true, scripts = {} }, META)
    made[#made + 1] = f
    local function Children(self, script)
        for _, c in ipairs(made) do
            if c.parent == self and c.shown then
                if c.scripts[script] then c.scripts[script](c) end
                c.Spread(c, script)
            end
        end
    end
    f.Spread = Children
    function f:Show()
        local was = self.shown
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
        if not was then Children(self, "OnShow") end
    end
    function f:Hide()
        local was = self.shown
        self.shown = false
        if was and self.scripts.OnHide then self.scripts.OnHide(self) end
        if was then Children(self, "OnHide") end
    end
    function f:SetPoint(...) self.point = { ... } end
    function f:SetShown(v) if v then self:Show() else self:Hide() end end
    function f:IsShown() return self.shown end
    function f:SetText(t) self.text = t end
    function f:SetTextColor(r, g, b) self.color = { r, g, b } end
    function f:SetFont(path, size) self.fontPath, self.fontSize = path, size end
    function f:SetGradient(_, bottom, top) self.gradient = { bottom, top } end
    function f:GetWidth() return self.w or 400 end
    function f:GetHeight() return self.h or 50 end
    function f:SetWidth(w) self.w = w end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:SetHeight(h) self.h = h end
    function f:GetStringHeight() return 14 end
    function f:GetStringWidth() return 100 end
    function f:SetAlpha(a) self.alpha = a end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:HookScript(k, fn)
        local old = self.scripts[k]
        self.scripts[k] = function(...) if old then old(...) end fn(...) end
    end
    function f:RegisterEvent(e)
        local events = rawget(self, "registered") or {}
        events[e] = true
        rawset(self, "registered", events)
    end
    function f:UnregisterAllEvents() rawset(self, "registered", {}) end
    function f:CreateTexture() local tx = Frame(); tx.parent = self; return tx end
    function f:CreateAnimationGroup()
        local owner = self
        local group = setmetatable({ plays = 0 }, META)
        function group.CreateAnimation() return setmetatable({}, META) end
        function group.Play() group.plays = group.plays + 1; owner.played = (owner.played or 0) + 1 end
        return group
    end
    function f:SetTexture(path) self.texture = path end
    function f:EnableMouse(on) self.mouse = on end
    return f
end

local T = { fg = { r = 1, g = 1, b = 1 }, muted = { r = 0.5, g = 0.5, b = 0.5 }, accent = { r = 0, g = 0.5, b = 1 },
    accentSoft = { r = 0.3, g = 0.7, b = 1 }, line = { r = 0.2, g = 0.2, b = 0.2 }, bg = { r = 0.05, g = 0.05, b = 0.05 },
    panel = { r = 0.1, g = 0.1, b = 0.1 } }
local EDITABLE = { "bg", "panel", "line", "fg", "muted", "accent" }
local NAOWH_PALETTE = { { r = 0.01, g = 0.02, b = 0.03 }, { r = 0.11, g = 0.12, b = 0.13 }, { r = 0.21, g = 0.22, b = 0.23 },
    { r = 0.91, g = 0.92, b = 0.93 }, { r = 0.51, g = 0.52, b = 0.53 }, { r = 0, g = 0.57, b = 0.93 } }
local CLASSIC_PLUS = { bg = { r = 0.04, g = 0.04, b = 0.03 }, panel = { r = 0.09, g = 0.07, b = 0.04 },
    line = { r = 0.37, g = 0.29, b = 0.11 }, fg = { r = 0.93, g = 0.89, b = 0.8 }, muted = { r = 0.66, g = 0.6, b = 0.49 },
    accent = { r = 1, g = 0.82, b = 0 } }
local ME = "Die Dudu"
local s = { combat = false, profiles = { Default = {} }, charActive = { [ME] = "Default" } }
local buttons, fonts = {}, {}

local Parts = {}
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"), THEME = T, UI = {},
    Shared = { Style = St, Parts = Parts },
    THEME_EDITABLE = EDITABLE, CLASSIC_PLUS = CLASSIC_PLUS,
    ThemePresetKey = function() return "" end,
    ThemePalette = function(key) s.paletteKey = key; return NAOWH_PALETTE end,
    AddonFontPath = function(classic) return classic and "arial" or "naowh" end,
    HeadingFontPath = function(classic) return classic and "friz" or "naowh" end,
    Font = function(parent, size, _, color)
        local f = Frame()
        f.parent, f.size, f.fontColor = parent, size, color
        fonts[#fonts + 1] = f
        return f
    end,
    Solid = function(parent, _, color)
        local t = Frame()
        t.parent, t.solid = parent, color
        return t
    end,
    Hairline = Noop,
    GameButtonArt = function(f) f.gameArt = true end,
    Border = function(f, color)
        local edge = { color = color }
        f.border = color
        function edge.SetColor(_, r, g, b) f.edgeColor = { r, g, b } end
        return edge
    end,
    Print = function(msg) s.printed = msg end,
    ConfirmReload = function(msg) s.reloadAsked = msg end,
    ShowCopyLine = function(title, text) s.copied = { title = title, text = text } end,
    LINKS = { { "Discord", "discord", function() return "https://discord.gg/x" end },
        { "GitHub", "github", function() return "https://github.com/x" end } },
    LINK_ICONS = "Interface\\AddOns\\NaowhForever\\Core\\Media\\Links\\",
    VersionText = function() return "v1.0.6" end,
    StashOptionsWindow = function() s.optionsClosed = (s.optionsClosed or 0) + 1 end,
    MarkAsked = function() s.pending = nil end,
    ProfileExists = function(name) return s.profiles[name] ~= nil end,
    SwitchProfile = function(name)
        if not s.profiles[name] then return false end
        s.switched, s.charActive[ME] = name, name
        return true
    end,
    CopyProfile = function(src, name)
        if s.failCopy or s.profiles[name] or not s.profiles[src] then return false end
        s.profiles[name] = { copyOf = src }
        return true
    end,
    CreateProfile = function() s.created = true; return true end,
    SetAccountProfile = function() s.created = true; return true end,
    Color = function(c, text)
        local function Byte(v) return math.floor(v * 255 + 0.5) end
        local prefix = ("|cff%02x%02x%02x"):format(Byte(c.r), Byte(c.g), Byte(c.b))
        if text == nil then return prefix end
        return prefix .. text .. "|r"
    end,
}
function ns.Button(parent, text, _, _, onClick)
    local b = Frame()
    b.parent = parent
    b.label = Frame()
    b.label.text = text
    b._onClick = onClick
    b.Click = function() b._onClick() end
    buttons[#buttons + 1] = b
    return b
end
function ns.AccentBorder(b) b.accent = true; return b end
function ns.SetButtonText(b, text) b.label.text = text end
function Parts.Window()
    local w = Frame()
    w.shown = false
    w.backdrop = { Paint = Noop }
    return w
end
function Parts.TitleBar(w, title)
    w.title = Frame()
    w.title.text = title
    w.subtitle = Frame()
    w.logo = Frame()
    w.logo.icon = Frame()
end
function Parts.IconButton(parent, onClick, texture, _, tip)
    local b = Frame()
    b.parent, b.tip, b.Click = parent, tip, onClick
    b.icon = Frame()
    b.icon.texture = texture
    return b
end
function Parts.Link(parent, onClick)
    local l = Frame()
    l.parent = parent
    l.Click = onClick
    return l
end
function Parts.SetLink(l, text) l.text = text end

local ALL = {}
for _, mod in ipairs(World().MODULES) do ALL[mod.addon] = true end
local w = World({ ns = ns, enabled = ALL, loaded = ALL, root = { discovery = { enabled = true } } })
ns.ActiveProfileName = function() return s.charActive[ME] end
local env = setmetatable({ _G = { NaowhForever = ns }, CreateFrame = function(_, _, parent)
        local f = Frame()
        f.parent = parent
        return f
    end, InCombatLockdown = function() return s.combat end, UnitName = function() return ME end,
    CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end },
    { __index = _G })
local chunk = assert(loadfile("Core/Onboarding/SetupWindow.lua"))
setfenv(chunk, env)
chunk()

local function Shown(f)
    while f do
        if not f.shown then return false end
        f = f.parent
    end
    return true
end
local function Find(label)
    for i = #buttons, 1, -1 do
        if buttons[i].label.text == label and Shown(buttons[i]) then return buttons[i] end
    end
end
local function Said(text)
    for _, f in ipairs(fonts) do
        if f.text == text and Shown(f) then return f end
    end
end
local function Saying(part)
    for _, f in ipairs(fonts) do
        if type(f.text) == "string" and f.text:find(part, 1, true) and Shown(f) then return f end
    end
end
local function Link(text)
    for _, f in ipairs(made) do
        if f.text == text and f.Click and Shown(f) then return f end
    end
end
local function Tile(label)
    for _, f in ipairs(made) do
        if f.name and f.name.text == label and f.onPick and Shown(f) then return f end
    end
end
local function Tiles()
    local out = {}
    for _, f in ipairs(made) do
        if f.name and f.onPick and f.check and Shown(f) then out[#out + 1] = f end
    end
    return out
end
local function Tip(tip)
    for _, f in ipairs(made) do
        if f.tip == tip and f.Click and Shown(f) then return f end
    end
end
local function Clicked(f) f.scripts.OnClick(f) end
local function Picked()
    local out = {}
    for _, tile in ipairs(Tiles()) do
        if tile.on then out[#out + 1] = tile.name.text end
    end
    return table.concat(out, ",")
end
local function Snapshot()
    local function Flat(t, prefix, out)
        local keys = {}
        for k in pairs(t) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local v = t[k] == nil and t[tonumber(k)] or t[k]
            if type(v) == "table" then Flat(v, prefix .. k .. ".", out) else out[#out + 1] = prefix .. k .. "=" .. tostring(v) end
        end
        return out
    end
    return table.concat(Flat(w.root, "root.", {}), ";") .. "|" .. table.concat(Flat(w.enabled, "on.", {}), ";")
        .. "|" .. table.concat(Flat(w.others, "others.", {}), ";") .. "|skin=" .. tostring(w.account.skin)
        .. "|backup=" .. tostring(w.account.setupBefore ~= nil)
end

ns.ShowSetup()
check("opening it closes the options window", s.optionsClosed == 1)
check("it opens on the welcome", Saying("One addon") and Saying("to rule") and Saying("them all.")
    and Said("Welcome, and thank you for joining us") ~= nil)
check("the thanks: a small, dedicated team with a lot of passion", Saying("small, dedicated team with")
    and Saying("a lot of passion"))
local welcomeHead, welcomeBody = Said("Welcome, and thank you for joining us"), Saying("small, dedicated team with")
check("the welcome promises four quick steps, a review and an undo", Said("Four quick steps") and Said("Review it all")
    and Said("Undo any time") and Said("Seven quick questions") == nil)
check("the welcome has its own start, no footer", Find("Let's start") and Find("Back") == nil)
check("it points to the website", Said("New here? Every feature is shown on our website:") ~= nil)
local sign
for _, f in ipairs(made) do if f.dots then sign = f end end
check("the infinity sign animates while the welcome shows", sign and sign.scripts.OnUpdate ~= nil and #sign.dots > 10)
local before = sign.dots[1].point[4]
sign.scripts.OnUpdate(sign, 0.5)
check("its glowing head travels along the loop", sign.dots[1].point[4] ~= before)
Link("naowh.gg/forever").Click()
check("the website link shows the address to copy", s.copied and s.copied.text == "https://naowh.gg/forever/")
local window = Find("Let's start").parent.parent
check("the title says what this is, and its logo opens nothing", window.title.text == "Naowh Forever: Onboarding"
    and window.logo.mouse == false)
check("the start button points on", Find("Let's start").arrow.texture:find("next.tga", 1, true) ~= nil)
check("the version sits at the bottom right", Said("v1.0.6") ~= nil)
Tip("Discord").Click()
check("our socials at the bottom left, each showing its address", Tip("GitHub") ~= nil
    and s.copied.text == "https://discord.gg/x")
window.scripts.OnHide(window)
check("the whole UI hidden with it is not a close: not seen yet", w.account.onboardingSeen == nil
    and w.account.welcomeSeen == nil)

local fresh = Snapshot()
Find("Let's start").Click()
check("past the welcome the animation stops", sign.scripts.OnUpdate == nil)
check("step 1 of 4, its segments lit", window.subtitle.text == "Step 1 of 4" and #window.segments == 4
    and window.segments[1].shown)
check("step 1 asks where to start", Said("Where do you want to start?") ~= nil)
local minimal, recommended, keep = Tile("Minimalist"), Tile("Recommended"), Tile("Keep mine")
check("three profiles: Naowh's two, with their own words, and Keep mine", #Tiles() == 3 and minimal and recommended
    and keep and minimal.blurb.text == w.ns.PRESETS.minimalist.about
    and recommended.blurb.text == w.ns.PRESETS.recommended.about and keep.blurb.text == "Your settings stay as they are.")
local function Ours(texture, name)
    return texture:find("NaowhForever", 1, true) and texture:find("Setup", 1, true)
        and texture:sub(-#name - 5) == "\\" .. name .. ".tga"
end
check("each draws our own icon", Ours(minimal.icon.tex.texture, "essentials")
    and Ours(recommended.icon.tex.texture, "everything") and Ours(keep.icon.tex.texture, "purist"))
check("one row of cards, centred in the window", minimal.point[5] == keep.point[5]
    and math.abs(minimal.point[4] - (780 - (keep.point[4] + keep.w))) < 0.01)
check("an account never set up starts on Recommended, with its check", Picked() == "Recommended"
    and recommended.check.shown and not minimal.check.shown)
check("Back and Next carry arrows", Find("Back").arrow.texture:find("back.tga", 1, true)
    and Find("Next").arrow.texture:find("next.tga", 1, true))
Clicked(minimal)
check("a pick glows on the card and pops its check", minimal.glow and minimal.glow.plays == 1
    and minimal.check.pop and minimal.check.pop.plays == 1)
check("one pick: the check moves", Picked() == "Minimalist")
local skinPage = window.skin
local fades = skinPage.fadeIn and skinPage.fadeIn.plays or 0
Find("Next").Click()
check("each new step fades in", skinPage.fadeIn.plays == fades + 1)
check("step 2: the skin", window.subtitle.text == "Step 2 of 4" and Said("How should Naowh Forever look?") ~= nil
    and Said("For every character on this computer.") ~= nil)
local naowh, classic = Tile("Naowh"), Tile("Classic+")
check("two skins, the one in use picked", #Tiles() == 2 and naowh and classic and Picked() == "Naowh")
check("each tile shows a small window, not an icon", naowh.preview and classic.preview and not naowh.icon.shown
    and naowh.preview.title.text == "Naowh Forever" and naowh.preview.body.text == "Every window looks like this."
    and naowh.preview.button.label.text == "Start")
local np, cp = naowh.preview, classic.preview
check("Naowh's preview: the theme's own colors", s.paletteKey == "" and np.bg.solid == NAOWH_PALETTE[1]
    and np.bar.solid == NAOWH_PALETTE[2] and np.rule.solid == NAOWH_PALETTE[3] and np.title.fontColor == NAOWH_PALETTE[4]
    and np.body.fontColor == NAOWH_PALETTE[5] and np.button.border == NAOWH_PALETTE[6])
check("its black edge, its font, its accent-edged button", np.border == St.BORDER_RGB and np.title.fontPath == "naowh"
    and np.body.fontPath == "naowh" and np.button.label.fontColor == NAOWH_PALETTE[4]
    and np.button.fill.gradient[1].r == NAOWH_PALETTE[2].r)
check("Classic+'s preview: its own palette", cp.bg.solid == CLASSIC_PLUS.bg and cp.bar.solid == CLASSIC_PLUS.panel
    and cp.rule.solid == CLASSIC_PLUS.line and cp.body.fontColor == CLASSIC_PLUS.muted
    and cp.title.fontColor == CLASSIC_PLUS.accent)
check("its gold edge, the game's fonts, the game's own button", cp.border == St.CLASSIC_GOLD_RGB
    and cp.title.fontPath == "friz" and cp.body.fontPath == "arial" and cp.button.gameArt
    and cp.button.fill == nil and cp.button.border == nil and cp.button.label.fontColor == CLASSIC_PLUS.accent)
Clicked(classic)
check("Classic+ picked", Picked() == "Classic+")
Find("Next").Click()
check("step 3: the modules", window.subtitle.text == "Step 3 of 4" and Said("Which modules do you want?") ~= nil
    and Said("Click a module to turn it on or off.") ~= nil)
local tiles = Tiles()
check("one tile per module, in the options' order", #tiles == #w.MODULES and tiles[1].name.text == "Quality of Life"
    and tiles[2].name.text == "Dungeon Journal")
for i, mod in ipairs(w.MODULES) do
    local tile = tiles[i]
    check(mod.addon .. ": its icon and its line", tile.icon.tex.texture == ns.MEDIA .. "Navigation\\" .. mod.navIcon .. ".tga"
        and tile.blurb.text == w.ns.Setup.ITEMS[tile.key].blurb)
end
local MINIMALIST = "Quality of Life,Dungeon Journal,BiS List,Training Planner,Blessings,Professions,Macros,Action Bars,"
    .. "AuraBuffs,Threat Meter,PvP,Top Bar"
local MINIMALIST_ON = #w.MODULES - #w.ns.PRESETS.minimalist.modulesOff
check("Minimalist: all but its seven", Picked() == MINIMALIST
    and Said(MINIMALIST_ON .. " of " .. #w.MODULES .. " on") ~= nil)
check("three to a row", tiles[1].point[5] == tiles[3].point[5] and tiles[4].point[5] ~= tiles[1].point[5])
local completo, topBar, qol = Tile("Discovery"), Tile("Top Bar"), Tile("Quality of Life")
Clicked(completo)
check("a click flips it, glowing", completo.on and completo.glow.plays == 1
    and Said(MINIMALIST_ON + 1 .. " of " .. #w.MODULES .. " on") ~= nil)
Clicked(qol)
check("Quality of Life off takes the Top Bar with it", not qol.on and not topBar.on)
Clicked(topBar)
check("the Top Bar on brings Quality of Life", qol.on and topBar.on)
Clicked(Tile("Professions"))
check("Professions off takes the Training Planner with it", not Tile("Training Planner").on)
Clicked(Tile("Training Planner"))
check("the Training Planner brings Professions", Tile("Professions").on)
Find("Back").Click()
Find("Back").Click()
check("Back goes a step back, the pick kept", window.subtitle.text == "Step 1 of 4" and Picked() == "Minimalist")
Find("Next").Click()
check("the skin kept too", Picked() == "Classic+")
Find("Next").Click()
check("the same profile: the module flips kept", Tile("Discovery").on and Tile("Professions").on)
Find("Back").Click()
Find("Back").Click()
Clicked(Tile("Recommended"))
Clicked(Tile("Minimalist"))
Find("Next").Click()
Find("Next").Click()
check("another profile picked: its modules again", Picked() == MINIMALIST)
Find("Next").Click()
check("step 4: the summary", window.subtitle.text == "Step 4 of 4" and Said("Here's your setup") ~= nil
    and Said("Nothing changes until you apply it.") ~= nil)
check("it names the profile and the new skin", Said("Profile") and Said("Minimalist") and Said("Skin") and Said("Classic+"))
local off = Saying("Discovery")
check("and the modules it turns off, in red", Said("Turns off") and off and off.color[1] == St.RED_RGB.r
    and not off.text:find("BiS List", 1, true))
check("and the ones it turns on", Said("Turns on") and Said("PvP"))
check("Apply, accented, with a check", Find("Apply") and Find("Apply").accent
    and Find("Apply").arrow.texture:find("check.tga", 1, true))
s.combat = true
Find("Apply").Click()
check("in combat: nothing applied, it says to wait", Snapshot() == fresh and Said("Apply after your fight.") ~= nil
    and Find("Apply").alpha == 0.5)
s.combat = false
window.events.scripts.OnEvent(window.events, "PLAYER_REGEN_ENABLED")
check("after the fight it is ready again", Said("Apply after your fight.") == nil and Find("Apply").alpha == 1)
Find("Apply").Click()
check("applied: the window closes and the reload is offered", not window.shown and s.reloadAsked ~= nil)
check("its modules on, the rest off, Classic+, Minimalist", w.enabled.NaowhForever_QoL and w.enabled.NaowhForever_BiS
    and w.enabled.NaowhForever_ThreatMeter and w.enabled.NaowhForever_PvP and not w.enabled.NaowhForever_Discovery
    and not w.enabled.NaowhForever_GroupInspect
    and not w.enabled.NaowhForever_SwingTimer and not w.enabled.NaowhForever_ConsumableBar
    and w.account.skin == "classic" and w.root.qol.preset == "minimalist" and w.account.setupBefore ~= nil)
check("closed: the onboarding is seen, so it never opens by itself again", w.account.onboardingSeen == true
    and w.account.welcomeSeen == true)
w.ns.Setup.Restore()
w.account.setupBefore = nil

ns.ShowSetup()
Find("Let's start").Click()
check("seen before: it starts on Keep mine", Picked() == "Keep mine")
local kept = Snapshot()
Find("Next").Click()
Clicked(Tile("Naowh"))
Find("Next").Click()
Clicked(Tile("PvP"))
Clicked(Tile("Threat Meter"))
window:Hide()
check("X or Escape partway: nothing changes", Snapshot() == kept)

ns.ShowSetup()
Find("Let's start").Click()
Find("Next").Click()
Find("Next").Click()
local before3 = Picked()
Find("Next").Click()
check("keep mine and change nothing: your settings stay, the skin as now, no module lines",
    Said("Your settings stay.") and Said("Naowh, as now") and Said("Turns on") == nil and Said("Turns off") == nil)
s.printed, s.reloadAsked = nil, nil
Find("Apply").Click()
check("Apply with nothing to change just closes, writing nothing", not window.shown and Snapshot() == kept
    and s.printed == nil and s.reloadAsked == nil and before3 ~= "")

ns.ShowSetup()
Find("Let's start").Click()
Find("Next").Click()
Find("Next").Click()
Clicked(Tile("PvP"))
Find("Next").Click()
check("a module switched on is listed", Said("Turns on") and Said("PvP"))
Find("Apply").Click()
check("a loaded module, switched on live: no reload, just the done line", s.printed == "Your setup is ready."
    and s.reloadAsked == nil and w.root.pvp.enabled == true)
w.ns.Setup.Restore()

local function NewCharacter(mainProfile)
    s.profiles = { Default = {}, Raid = {} }
    s.charActive = { [ME] = "Default", ["Die Man"] = "Raid", ["Die Pri"] = "Default" }
    s.switched, s.printed, s.created, s.failCopy, s.pending, s.optionsClosed = nil, nil, nil, nil, true, 0
    ns.ShowNewCharacter(ME, "Die Man", mainProfile or "Raid")
end
local function Profiles()
    local out = {}
    for char, profile in pairs(s.charActive) do out[#out + 1] = char .. "=" .. profile end
    for name in pairs(s.profiles) do out[#out + 1] = "profile:" .. name end
    table.sort(out)
    return table.concat(out, ",")
end

NewCharacter()
local same, own = Tile("Same as Die Man"), Tile("Set Up Die Dudu")
check("a new character: the onboarding's own window, closing the options window", window.shown
    and window.title.text == "Naowh Forever: Onboarding" and s.optionsClosed == 1 and window.subtitle.text == "Welcome")
local head = Said("Welcome, Die Dudu!")
local body = Said("You've played Naowh Forever on Die Man. Share Die Man's settings, or give Die Dudu its own?")
check("welcomed by name, the main named", head ~= nil and body ~= nil)
local choiceSign = window.choice.sign
check("the welcome's infinity sign above the welcome, animating while the page shows", choiceSign ~= sign
    and #choiceSign.dots == #sign.dots and choiceSign.scripts.OnUpdate ~= nil and head.point[2] == choiceSign)
check("the welcome's tagline on top, the sign under it", window.choice.tagline.text:find("One addon", 1, true)
    and choiceSign.point[2] == window.choice.tagline)
check("in the welcome's look: its head and its muted body", head.size == welcomeHead.size
    and head.fontColor == welcomeHead.fontColor and body.size == welcomeBody.size and body.fontColor == T.muted
    and body.w == welcomeBody.w)
check("two answer tiles, each with a line about it", same and own
    and same.blurb.text == "Die Dudu uses Die Man's settings; a change on one shows on both."
    and own.blurb.text == "A few quick steps for Die Dudu only, its own modules included.")
check("the tiles are the profile step's, at its size", same.h == minimal.h and own.w == same.w
    and not same.check.shown and not own.check.shown)
check("a chain for the same settings, the wand to set it up", same.icon.tex.texture == ns.MEDIA .. "chain.tga"
    and own.icon.tex.texture == ns.MEDIA .. "wand.tga")
same.scripts.OnEnter(same)
check("a tile lights under the mouse", same.edgeColor[1] == T.accentSoft.r and same.lit.shown)
same.scripts.OnLeave(same)
check("and goes back after", same.edgeColor[1] == 0 and not same.lit.shown)
check("the welcome's bottom row: our socials and the version", Tip("Discord") ~= nil and Said("v1.0.6") ~= nil
    and Said("New here? Every feature is shown on our website:") == nil)
check("no Back or Next", Find("Back") == nil and Find("Next") == nil)
Clicked(same)
check("same: this character switches to the main's profile, and it says so", s.switched == "Raid"
    and s.charActive[ME] == "Raid" and s.printed == "Die Dudu now uses the same settings as Die Man.")
check("then the window closes, the question answered", not window.shown and s.pending == nil)

NewCharacter("Default")
local profilesBefore = Profiles()
Clicked(Tile("Same as Die Man"))
check("same, the main already on this profile: nothing changes, it just closes", s.switched == nil
    and s.printed == nil and Profiles() == profilesBefore and not window.shown)

NewCharacter()
w.calls = {}
Clicked(Tile("Set Up Die Dudu"))
check("set up: a copy of this character's profile, named after it, only it switched", s.profiles[ME]
    and s.profiles[ME].copyOf == "Default" and s.charActive[ME] == ME and s.charActive["Die Man"] == "Raid")
check("then straight on to step 1, in the same window, on Keep mine", window.shown and window.subtitle.text == "Step 1 of 4"
    and Picked() == "Keep mine" and s.pending == nil)
Find("Next").Click()
Find("Next").Click()
check("the modules hint says whose they are", Said("Click a module to turn it on or off, for Die Dudu only.") ~= nil)
Clicked(Tile("PvP"))
Clicked(Tile("Threat Meter"))
Find("Next").Click()
Find("Apply").Click()
check("applied for this character: PvP on, Threat Meter off", w.enabled.NaowhForever_PvP
    and not w.enabled.NaowhForever_ThreatMeter and w.others.NaowhForever_ThreatMeter)
local named = #w.calls > 0
for _, c in ipairs(w.calls) do named = named and w.ForMe(c) end
check("every C_AddOns call named this character", named)
w.ns.Setup.Restore()
ns.ShowSetup()
check("opened as usual afterwards: for every character again", window.subtitle.text == "Welcome")
window:Hide()

NewCharacter()
s.profiles[ME] = {}
Clicked(Tile("Set Up Die Dudu"))
check("its name taken: the same name with 2", s.profiles[ME .. " 2"] and s.charActive[ME] == ME .. " 2")
window:Hide()

NewCharacter()
s.failCopy = true
profilesBefore = Profiles()
Clicked(Tile("Set Up Die Dudu"))
check("a copy that fails: nothing changes and the page stays", Profiles() == profilesBefore and window.shown
    and Tile("Set Up Die Dudu") ~= nil and s.pending == true)
window.scripts.OnHide(window)
check("the whole UI hidden with it: still waiting for an answer", s.pending == true)
window:Hide()
check("X or Escape: nothing changes, and it is not asked again", Profiles() == profilesBefore and s.pending == nil)

math.randomseed(20261009)
local clicks = 0
for _ = 1, 4000 do
    if not window.shown then
        if math.random() < 0.3 then ns.ShowNewCharacter(ME, "Die Man", "Raid") else ns.ShowSetup() end
    end
    local targets = {}
    for _, f in ipairs(made) do
        if Shown(f) and (f.Click or f.scripts.OnClick) and f ~= window then targets[#targets + 1] = f end
    end
    local f = targets[math.random(#targets)]
    s.combat = math.random() < 0.1
    if f.Click then f.Click() else Clicked(f) end
    clicks = clicks + 1
    if window.shown then
        local pages = 0
        for _, page in ipairs({ window.choice, window.welcome, window.profile, window.skin, window.modules, window.summary }) do
            if page.shown then pages = pages + 1 end
        end
        if pages ~= 1 then error("random clicks: " .. pages .. " pages shown after " .. clicks .. " clicks") end
    end
end
s.combat = false
check("4000 random clicks: always one page, never an error", clicks == 4000)

print("PASS setup window: " .. checks .. " checks")

-- Run with Lua 5.1 from the repository root: the Shopping List docks beside the profession window,
-- Detach floats it where it is and Dock puts it back, and it comes back with the profession window
-- only if it was docked and open when that window closed. All of it only with Dock Shopping List on:
-- off, the window builds no Detach button, never docks and the profession window is not hooked.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local f = assert(io.open("NaowhForever_Professions/UI/ShoppingWindow.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local first = assert(source:find("local function ProfessionOpen()", 1, true))
local last = assert(source:find("\nlocal function OnSized(", first, true))
local chunk = "local window, events, profession, docked, detach, grip, closingWithProfession\n"
    .. "local function FitPicker() end\nlocal function RenderWindow() end\n"
    .. source:sub(first, last)
    .. "return function(w, e, p, d, g) window, events, profession, detach, grip = w, e, p, d, g end,"
    .. " function() return docked end, Dock, OnDetach, OnHide, OnDragStart, OnProfessionShow, OnProfessionHide"

local function Frame()
    local frame = { shown = false, points = {} }
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetShown(on) self.shown = on and true or false end
    function frame:IsShown() return self.shown end
    return frame
end

local account, opened, moved
local function Setup(off)
    account, opened, moved = { windowSizes = { shoppingList = { 380, 400 } } }, 0, 0
    local window = Frame()
    window.positionKey = "shoppingListWindow"
    window.left, window.top, window.height = 600, 700, 520
    function window:ClearAllPoints() self.points = {} end
    function window:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function window:SetHeight(h) self.height = h end
    function window:SetFrameStrata(s) self.strata = s end
    function window:GetLeft() return self.left end
    function window:GetTop() return self.top end
    function window:GetHeight() return self.height end
    function window:StartMoving() moved = moved + 1 end
    local OnHide
    function window:Hide() self.shown = false; OnHide() end
    local profession = Frame()
    profession.shown, profession.alpha = true, 1
    function profession:IsVisible() return self.shown end
    function profession:GetAlpha() return self.alpha end
    function profession:GetFrameStrata() return "DIALOG" end
    local detach = Frame()
    function detach:SetShown(on) self.shown = on and true or false end
    local env = setmetatable({
        MIN_H = 300, HEIGHT = 520, DOCK_GAP = 2, FLOAT_STRATA = "HIGH", PANEL_KEY = "shoppingListPanel",
        EVENTS = {}, TEXT_DETACH = "Detach", TEXT_ATTACH = "Dock", TIP_DETACH_HELP = "d", TIP_ATTACH_HELP = "a",
        UIParent = {},
        On = function() return true end,
        Parts = { Place = function(w) w:SetPoint("SAVED") end },
        ns = {
            AccountSettings = function() return account end,
            SetButtonText = function(b, t) b.text = t end,
            Tooltip = function() end,
            OpenShoppingList = function() opened = opened + 1 end,
        },
    }, { __index = _G })
    local fn = assert(loadstring(chunk))
    setfenv(fn, env)
    local set, Docked, Dock, OnDetach, Hidden, OnDragStart, OnProfessionShow, OnProfessionHide = fn()
    OnHide = Hidden
    local events = { UnregisterAllEvents = function() end }
    local grip = Frame()
    if off then detach = nil end
    set(window, events, profession, detach, grip)
    return { window = window, profession = profession, detach = detach, grip = grip, Docked = Docked,
        Dock = Dock, OnDetach = OnDetach, OnDragStart = OnDragStart, OnProfessionShow = OnProfessionShow,
        OnProfessionHide = OnProfessionHide }
end

local t = Setup()
t.window.shown = true
t.Dock()
local p = t.window.points
check("docked on the profession window's right edge, top and bottom",
    #p == 2 and p[1][1] == "TOPLEFT" and p[1][2] == t.profession and p[1][3] == "TOPRIGHT"
    and p[2][1] == "BOTTOMLEFT" and p[2][3] == "BOTTOMRIGHT")
check("docked: the profession window's strata, no size grip, the button says Detach",
    t.window.strata == "DIALOG" and not t.grip.shown and t.detach.shown and t.detach.text == "Detach")
t.OnDragStart(t.window)
check("a docked panel does not drag", moved == 0)

account.shoppingListPanel = true
t.OnDetach()
p = t.window.points
check("Detach floats it where it was", not t.Docked() and #p == 1 and p[1][4] == 600 and p[1][5] == 700)
check("Detach saves that place", account.shoppingListWindow[3] == 600 and account.shoppingListWindow[4] == 700)
check("floating: high strata, the size grip, the button says Dock",
    t.window.strata == "HIGH" and t.grip.shown and t.detach.text == "Dock")
check("a detached panel does not come back with the profession window", account.shoppingListPanel == nil)
t.OnDragStart(t.window)
check("a floating window drags", moved == 1)

t.OnDetach()
check("Dock puts it back beside the profession window", t.Docked() and t.window.points[1][2] == t.profession)

t.OnProfessionHide()
check("closing the profession window hides the docked panel and remembers it",
    not t.window.shown and account.shoppingListPanel == true)
check("hidden, it leaves the dock for its saved place and size",
    not t.Docked() and t.window.points[1][1] == "SAVED" and t.window.height == 400)
t.OnProfessionShow()
check("the profession window opening brings a remembered panel back", opened == 1)

t = Setup()
t.window.shown = true
t.Dock()
t.window:Hide()
check("closing the docked panel yourself forgets it", account.shoppingListPanel == nil)
t.OnProfessionShow()
check("so it stays shut when the profession window opens again", opened == 0)

t = Setup()
t.window.shown = true
t.Dock()
t.OnDetach()
t.profession.shown = false
t.OnProfessionHide()
check("a floating window stays open when the profession window closes", t.window.shown)
check("with nothing to dock to, the Dock button hides", not t.detach.shown)

t = Setup(true)
t.window.shown = true
t.OnDetach()
check("off: a window built without Detach never docks", not t.Docked() and #t.window.points == 0)
t.window:Hide()
check("off: closing it leaves its place and size alone", #t.window.points == 0 and t.window.height == 520)

local function Read(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a"):gsub("\r\n", "\n"); file:close()
    return text
end
local bar = source:sub(assert(source:find("local function BuildBar(", 1, true)),
    assert(source:find("\nlocal function Build()", 1, true)))
check("off: the title bar builds no Detach button", bar:find("if dock then\n        detach = ns.Button(", 1, true))
check("off: the title bar keeps the shared close button",
    source:find("BuildBar(Parts.TitleBar(window, TEXT_TITLE, TEXT_SUBTITLE, PAGE))", 1, true))
local add = Read("NaowhForever_Professions/UI/ShoppingAdd.lua")
check("off: the profession window is not hooked", add:find("if dock then ns.ShoppingListDockTo(win) end", 1, true))
check("off: the Shopping List button keeps its place",
    add:find("opener:SetPoint(\"TOPRIGHT\", -OPEN_RIGHT, -OPEN_DROP)", 1, true))
check("Dock Shopping List is off by default",
    Read("Core/Features.lua"):find("\n        shoppingListDock = false,\n", 1, true))

print("shopping list dock: " .. checks .. " checks passed")

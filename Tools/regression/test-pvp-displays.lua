-- PvP Battleground Displays: the game's scores and start countdown in the HUD Editor. Loads
-- NaowhForever_PvP/Displays.lua and its settings card on stub frames; does not emulate taint or rendering.
-- From the repo root: lua5.1 Tools/regression/test-pvp-displays.lua
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local function Frame(name)
    local f = { name = name, points = {}, shown = true, events = {} }
    function f:ClearAllPoints() self.points = {}; self.all = nil end
    function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function f:SetAllPoints(rel) self.points = {}; self.all = rel end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:SetShown(v) self.shown = v and true or false end
    function f:SetScript(k, fn) self[k] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    return f
end

local screen = { w = 1920, h = 1080 }
local UIParent = Frame("UIParent")
function UIParent:GetWidth() return screen.w end
function UIParent:GetHeight() return screen.h end

local function Load(withFrames)
    local settings = { enabled = false, scoresPos = false, timerPos = false }
    local s = { built = {}, movers = {}, placed = 0, settings = settings }
    local S = { Get = function(k) return settings[k] end }
    function S.Set(k, v) settings[k] = v end
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, PvPSettings = S, Apply = function() end,
        ShowUnlockMode = function() end, HideUnlockMode = function() end,
        PlaceTopCentreWidgets = function() s.placed = s.placed + 1 end,
        UI = { AttachMover = function(holder, label, save, page, feature)
            local m = Frame("mover")
            m.shown = false
            m.label, m.save, m.page, m.feature = label, save, page, feature
            s.movers[label] = m
            return m
        end },
        Shared = { Settings = { Page = function() return { Card = function(_, card) s.card = card end } end } } }
    s.scores = Frame("UIWidgetTopCenterContainerFrame")
    s.scores:SetPoint("TOP", UIParent, "TOP", 0, -15)
    s.timer = Frame("TimerTracker")
    s.timer:SetAllPoints(UIParent)
    local env = setmetatable({ _G = { NaowhForever = ns }, UIParent = UIParent,
        UIWidgetTopCenterContainerFrame = withFrames ~= false and s.scores or nil,
        TimerTracker = withFrames ~= false and s.timer or nil,
        CreateFrame = function()
            local f = Frame()
            s.built[#s.built + 1] = f
            return f
        end,
        hooksecurefunc = function(t, k, fn)
            local old = t[k]
            t[k] = function(...) local r = old(...); fn(...); return r end
        end }, { __index = _G })
    for _, path in ipairs({ "NaowhForever_PvP/Displays.lua", "NaowhForever_PvP/UI/BattlegroundsPage.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    s.resize, s.boot = s.built[1], s.built[2]
    s.boot.OnEvent(s.boot, "PLAYER_LOGIN")
    s.S, s.ns = S, ns
    return s
end

local function Is(point, want)
    for i = 1, #want do if point[i] ~= want[i] then return false end end
    return true
end

do -- off: nothing built, the game's frames untouched
    local s = Load()
    check("off: no holders or movers", #s.built == 2 and next(s.movers) == nil)
    check("off: the scores and countdown where the game put them",
        Is(s.scores.points[1], { "TOP", UIParent, "TOP", 0, -15 }) and s.timer.all == UIParent)
    check("off: the boot frame stops listening", next(s.boot.events) == nil)
end

do -- on, nothing dragged: holders over the game's frames, which do not move
    local s = Load()
    s.S.Set("enabled", true)
    local scores, timer = s.movers["Battleground Scores"], s.movers["Battleground Countdown"]
    check("on: a mover for each, on the Battlegrounds page", scores and timer
        and scores.page == "PvP/Battlegrounds" and timer.feature == "PvP/Battlegrounds:displays")
    local holderOfScores, holderOfTimer = s.built[3], s.built[4]
    check("unmoved: the scores holder follows the scores",
        Is(holderOfScores.points[1], { "TOP", s.scores, "TOP" }))
    check("unmoved: the countdown holder sits on its first bar",
        Is(holderOfTimer.points[1], { "TOP", s.timer, "TOP", 0, -155 }))
    check("unmoved: the game's frames are untouched",
        Is(s.scores.points[1], { "TOP", UIParent, "TOP", 0, -15 }) and s.timer.all == UIParent)
    check("the movers show only in the HUD Editor", not scores.shown and not timer.shown)
    s.ns.ShowUnlockMode()
    check("in the HUD Editor: both movers show", scores.shown and timer.shown)
    s.ns.HideUnlockMode()
    check("out of it: hidden again", not scores.shown and not timer.shown)

    -- Dragged: the holder takes the saved spot and the game's frame hangs from it.
    scores.save({ point = "CENTER", relPoint = "CENTER", x = 0, y = 300 })
    check("dragged scores: the holder at the saved spot",
        Is(holderOfScores.points[1], { "CENTER", UIParent, "CENTER", 0, 300 }))
    check("dragged scores: the scores hang from it", #s.scores.points == 1
        and Is(s.scores.points[1], { "TOP", holderOfScores, "TOP" }))
    timer.save({ point = "CENTER", relPoint = "CENTER", x = 0, y = 100 })
    check("dragged countdown: screen-sized, its first bar at the holder", s.timer.all == nil
        and s.timer.w == 1920 and s.timer.h == 1080 and Is(s.timer.points[1], { "TOP", holderOfTimer, "TOP", 0, 155 }))
    check("dragged countdown: a screen change sizes it again", s.resize.events.UI_SCALE_CHANGED
        and s.resize.events.DISPLAY_SIZE_CHANGED)
    screen.w, screen.h = 2560, 1440
    s.resize.OnEvent(s.resize, "DISPLAY_SIZE_CHANGED")
    check("a bigger screen: the countdown follows it", s.timer.w == 2560 and s.timer.h == 1440)
    screen.w, screen.h = 1920, 1080

    -- Reset: back where the game shows them, and the Top Bar may place the scores again.
    local placed = s.placed
    s.settings.timerPos = false
    s.S.Set("scoresPos", false)
    check("reset: the scores back at the game's spot, the Top Bar asked to place them",
        Is(s.scores.points[1], { "TOP", UIParent, "TOP", 0, -15 }) and s.placed == placed + 1)
    check("reset: the countdown fills the screen again", s.timer.all == UIParent)
    check("reset: no screen-change events left", next(s.resize.events) == nil)
    check("reset: the holders follow the game's frames again",
        Is(holderOfScores.points[1], { "TOP", s.scores, "TOP" }))

    -- Switched off while dragged: the game's frames go home.
    scores.save({ point = "CENTER", relPoint = "CENTER", x = 0, y = 300 })
    s.S.Set("enabled", false)
    check("off while dragged: the scores back home", Is(s.scores.points[1], { "TOP", UIParent, "TOP", 0, -15 }))
    check("off: the movers hidden", not scores.shown)
end

do -- the settings card
    local s = Load()
    local row = s.card.rows[1]
    s.settings.scoresPos = { point = "CENTER" }
    s.settings.timerPos = { point = "CENTER" }
    row.button()
    check("Reset Positions clears both", s.settings.scoresPos == false and s.settings.timerPos == false)
end

do -- a client without the frames
    local s = Load(false)
    check("no frames: no error and no holders", pcall(s.S.Set, "enabled", true) and #s.built == 2)
end

print("PASS pvp displays: " .. checks .. " checks")

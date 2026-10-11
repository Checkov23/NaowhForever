-- Offline behavior checks for the Flight Timer's Request Stop fade, its display, and Flight Games
-- (what opens on a flight, and the one-time move from the old toggles), its look, and the flight
-- time on the flight master's map; these do not emulate client taint or rendering.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end
local function fixture(settings, extra)
    local s = { now = 0, frames = {}, tickers = {}, taxi = false, combat = false, settings = settings or {},
        offers = {}, dismissed = {} }
    local any = setmetatable({}, { __index = function(t) return function() return t end end })
    local function frame()
        local f = { events = {}, scripts = {}, shown = false }
        setmetatable(f, { __index = function() return function() return any end end })
        function f:SetScript(k, fn) self.scripts[k] = fn end
        function f:RegisterEvent(k) self.events[k] = true end
        function f:UnregisterEvent(k) self.events[k] = nil end
        function f:Show() self.shown = true end
        function f:Hide() self.shown = false end
        function f:SetShown(v) self.shown = v and true or false end
        function f:IsShown() return self.shown end
        function f:GetScale() return 1 end
        function f:GetFrameLevel() return 1 end
        function f:CreateTexture() return frame() end
        function f:SetText(v) self.text = v end
        function f:GetStringWidth() return 40 end
        function f:SetAlpha(a) self.alpha = a end
        function f:SetFont(path, size, flags) self.font = path .. " " .. size .. " " .. flags end
        function f:SetTexture(path) self.texture = path end
        function f:SetTextColor(r) self.red = r end
        s.frames[#s.frames + 1] = f
        return f
    end
    local leave = frame()
    leave.alpha, leave.mouse, leave.mouseCalls = 1, true, 0
    function leave:SetAlpha(a) self.alpha = a end
    function leave:EnableMouse(v) self.mouse = v; self.mouseCalls = self.mouseCalls + 1 end
    s.leave = leave
    local defaults = { enabled = true, flightTimer = true, flightEarlyLanding = false, flightTimerScale = 1,
        flightTimerAlpha = 1, flightTimerMapTime = false, flightGame = 'aim', flightTimerFont = '', flightTimerOutline = 'NONE', flightTimerTexture = '' }
    local S = { Get = function(k) if s.settings[k] ~= nil then return s.settings[k] end return defaults[k] end,
        Set = function(k, v) s.settings[k] = v end, DB = function() return s.settings end,
        Raw = function(k) return s.settings[k] end }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QoLConstants = dofile("Tools/regression/qol_constants.lua"), QoLSettings = S, THEME = { accent = {}, bg = {}, muted = { r = 0.5 }, accentSoft = {}, fg = { r = 1 },
            line = {} },
        Font = function() return frame() end, Solid = function() return frame() end,
        Border = function() return { _frame = frame() } end,
        Button = function(_, text)
            local b = frame()
            b.name, b.label = text, frame()
            b._bg, b._border, b._art = frame(), { _frame = frame() }, false
            return b
        end,
        AccentBorder = function(f) return f end, PixelInset = function() end,
        Tooltip = function() end, AccountSettings = function() return {} end, FLIGHT_ROUTES = {},
        Apply = function() end, ShowUnlockMode = function() end, HideUnlockMode = function() end,
        UI = { AttachMover = function() return frame() end, FontPath = function(name) return 'font:' .. name end,
            TexturePath = function(name, own) if name == '' then return own end return 'lsm:' .. name end },
        Shared = { Style = setmetatable({ ROUND = 'round', BORDER_RGB = { r = 0, g = 0, b = 0 }, PLACE_DOT = ' . ' },
                { __index = dofile('Tools/regression/shared_style.lua') }),
            Parts = { Arrow = function() return frame() end, HudText = function(fs, shadow) fs.shadow = shadow end,
                HudFlags = function(o) return (o == "NONE" or type(o) ~= "string") and "" or o end } },
        QuizOffer = function(reason) s.offers[#s.offers + 1] = 'quiz:' .. reason end,
        AimOffer = function(reason) s.offers[#s.offers + 1] = 'aim:' .. reason end,
        QuizDismiss = function(reason) s.dismissed.quiz = reason end,
        AimDismiss = function(reason) s.dismissed.aim = reason end }
    local env = { _G = { NaowhForever = ns }, UIParent = frame(), CreateFrame = frame,
        MainMenuBarVehicleLeaveButton = leave,
        GetTime = function() return s.now end, UnitOnTaxi = function() return s.taxi end,
        InCombatLockdown = function() return s.combat end,
        TakeTaxiNode = function() end, TaxiRequestEarlyLanding = function() s.landRequests = (s.landRequests or 0) + 1 end,
        CreateColor = function() return {} end, UnitFactionGroup = function() return 'Alliance' end,
        GetFileIDFromPath = function() return 1 end,
        C_Timer = { NewTicker = function(_, fn) local t = { fn = fn }; function t:Cancel() self.cancelled = true end
            s.tickers[#s.tickers + 1] = t; return t end },
    }
    env.hooksecurefunc = function(t, k, fn)
        if type(t) == 'string' then t, k, fn = env, t, k end
        local old = t[k]; t[k] = function(...) old(...); fn(...) end
    end
    for k, v in pairs(extra or {}) do env[k] = v end
    setmetatable(env, { __index = _G })
    local chunk = assert(loadfile('NaowhForever_QoL/Travel/Flight.lua')); setfenv(chunk, env); chunk()
    function s.fire(event)
        local all = {}; for i, f in ipairs(s.frames) do all[i] = f end
        for _, f in ipairs(all) do if f.events[event] then f.scripts.OnEvent(f, event) end end
    end
    s.ns, s.env = ns, env
    function s.set(k, v) S.Set(k, v) end
    function s.board() s.taxi = true; s.fire('PLAYER_ENTERING_WORLD') end
    function s.land()
        s.taxi = false
        for _, t in ipairs(s.tickers) do if not t.cancelled then t.fn() end end
    end
    function s.find(pred)
        for _, f in ipairs(s.frames) do if pred(f) then return f end end
    end
    function s.text(v) return s.find(function(f) return rawget(f, 'text') == v end) end
    function s.button(label) return s.find(function(f) return rawget(f, 'name') == label end) end
    function s.tick()
        local bar = s.find(function(f) return f.scripts.OnUpdate end)
        bar.scripts.OnUpdate(bar)
    end
    s.fire('PLAYER_LOGIN'); s.fire('PLAYER_ENTERING_WORLD')
    return s
end

do
    local s = fixture()
    check('login leaves the button alone', s.leave.alpha == 1 and s.leave.mouseCalls == 0)
    s.board()
    check('without Land Early the button stays', s.leave.alpha == 1 and s.leave.mouse)
    s.land()
    check('landing without Land Early touches nothing', s.leave.mouseCalls == 0)
end
do
    local s = fixture({ flightEarlyLanding = true })
    check('no flight, no fade', s.leave.alpha == 1)
    s.board()
    check('flying with Land Early fades the button', s.leave.alpha == 0 and not s.leave.mouse)
    s.land()
    check('landing restores the button', s.leave.alpha == 1 and s.leave.mouse)
end
do
    local s = fixture({ flightEarlyLanding = true })
    s.board()
    s.set('flightEarlyLanding', false)
    check('turning Land Early off mid-flight restores', s.leave.alpha == 1 and s.leave.mouse)
    s.set('flightEarlyLanding', true)
    check('turning it back on fades again', s.leave.alpha == 0)
    s.set('flightTimer', false)
    check('turning the timer off restores', s.leave.alpha == 1 and s.leave.mouse)
end
do
    local s = fixture({ flightEarlyLanding = true })
    s.board()
    s.combat = true
    s.land()
    check('a combat landing leaves the protected button alone', s.leave.alpha == 0 and not s.leave.mouse)
    s.combat = false
    s.fire('PLAYER_REGEN_ENABLED')
    check('combat end restores the button', s.leave.alpha == 1 and s.leave.mouse)
    s.fire('PLAYER_REGEN_ENABLED')
    check('the combat-end listener is one-shot', s.leave.mouseCalls == 2)
end
do
    local s = fixture({ flightEarlyLanding = true })
    s.ns.ShowUnlockMode()
    check('the Unlock Mode sample flight does not fade', s.leave.alpha == 1 and s.leave.mouseCalls == 0)
    s.ns.HideUnlockMode()
    check('leaving Unlock Mode touches nothing', s.leave.mouseCalls == 0)
end
-- Landing early on a timed route: the flight now ends at the first stop still ahead.
do
    local s = fixture({ flightEarlyLanding = true })
    local env = s.env
    local NAMES = { 'Southshore', 'Refuge Pointe', 'Menethil Harbor' }
    env.GetTaxiMapID = function() return 1415 end
    env.C_TaxiMap = { GetAllTaxiNodes = function()
        return { { slotIndex = 1, nodeID = 1 }, { slotIndex = 2, nodeID = 2 }, { slotIndex = 3, nodeID = 3 } }
    end }
    env.C_Traits = { GetConfigIDByTreeID = function() return nil end }
    env.GetNumRoutes = function() return 2 end
    env.TaxiGetNodeSlot = function(_, hop, from) return from and hop or hop + 1 end
    env.TaxiNodeName = function(slot) return NAMES[slot] end
    env.NumTaxiNodes = function() return 3 end
    env.TaxiNodeGetType = function(i) return i == 1 and 'CURRENT' or 'REACHABLE' end
    s.ns.FLIGHT_ROUTES[10002] = 30.4 * 50
    s.ns.FLIGHT_ROUTES[20003] = 30.4 * 50
    env.TakeTaxiNode(3)
    s.taxi = true
    for _, t in ipairs(s.tickers) do if not t.cancelled then t.fn() end end
    local to = s.text('Menethil Harbor')
    check('a timed three-stop flight runs to its end', to ~= nil and s.text('1:40') ~= nil)
    s.now = 20
    env.TaxiRequestEarlyLanding()
    check('landing early ends the flight at the next stop', to.text == 'Refuge Pointe' and s.text('0:30') ~= nil)
end
do
    local s = fixture({ flightEarlyLanding = true })
    s.ns.ShowUnlockMode()
    local key, name = s.text('Next'), s.text('Refuge Pointe')
    check('the sample flight names its next stop', key and key.shown and name and name.shown)
    check('with the time to it', s.text('0:50') and s.text('2:30'))
    check('the sample has no Land or Games button', not s.button('Land').shown and not s.button('Games').shown)
    s.now = 60
    s.tick()
    check('a passed stop hands over to the next one', s.text('Menethil Harbor').shown and s.text('0:35'))
    check('the time left counts down', s.text('1:30'))
    s.now = 160
    s.tick()
    check('the looping sample starts its stops again', s.text('Refuge Pointe') and s.text('0:40'))
end
do
    local s = fixture({ flightEarlyLanding = true })
    s.board()
    local land, games = s.button('Land'), s.button('Games')
    check('a flight shows the Land and Games buttons', land.shown and games.shown)
    land._onClick()
    check('Land asks to land early', s.landRequests == 1)
    check('an unknown route is just in flight', s.text('In flight'))
    s.now = 5
    s.tick()
    check('an unknown route counts up', s.text('0:05'))
    check('with no next stop', not s.text('Next') or not s.text('Next').shown)
end
do
    local s = fixture()
    s.board()
    check('by default a flight offers the Aim Trainer, once', #s.offers == 1 and s.offers[1] == 'aim:flight')
    s.land()
    check('landing closes what a flight opened', s.dismissed.quiz == 'flight' and s.dismissed.aim == 'flight')
end
do
    local s = fixture({ flightGame = 'quiz' })
    s.board()
    check('Quiz: a flight offers only the Quiz', #s.offers == 1 and s.offers[1] == 'quiz:flight')
end
do
    local s = fixture({ flightGame = 'none' })
    s.board()
    check('Nothing: a flight offers no game', #s.offers == 0)
    check('Nothing: the Games button still shows', s.button('Games').shown)
end
do
    local s = fixture({ flightGame = 'bogus' })
    s.board()
    check('an unknown choice falls back to the Aim Trainer', #s.offers == 1 and s.offers[1] == 'aim:flight')
end
do
    local s = fixture({ quizFlight = false, aimAutoFlight = true })
    check('Quiz While Flying off and Open on Flights on become Aim Trainer', s.settings.flightGame == 'aim'
        and s.settings.flightGameMigrated == true and s.settings.quizFlight == nil and s.settings.aimAutoFlight == nil)
    s.board()
    check('and a flight offers the Aim Trainer', #s.offers == 1 and s.offers[1] == 'aim:flight')
end
do
    local s = fixture({ quizFlight = false, aimAutoFlight = false })
    check('Quiz While Flying off alone becomes Nothing', s.settings.flightGame == 'none')
end
do
    local s = fixture({ quizFlight = true, aimAutoFlight = true })
    check('Quiz While Flying on keeps the default', s.settings.flightGame == nil
        and s.settings.quizFlight == nil and s.settings.aimAutoFlight == nil)
end
do
    local s = fixture()
    check('a fresh profile is only marked as migrated', s.settings.flightGame == nil
        and s.settings.flightGameMigrated == true)
end
do
    local s = fixture({ flightGameMigrated = true, quizFlight = false })
    check('the migration runs once', s.settings.flightGame == nil and s.settings.quizFlight == false)
    s.ns.Apply()
    check('and not again on Apply', s.settings.flightGame == nil)
end
do
    local s = fixture({ flightGame = 'quiz', quizFlight = false })
    check('a choice already made is kept', s.settings.flightGame == 'quiz' and s.settings.quizFlight == nil)
end
do
    local function read(path)
        local f = assert(io.open(path, 'rb'))
        local text = f:read('*a')
        f:close()
        return text
    end
    local qol, quiz = read('Core/Settings.lua'), read('NaowhForever_QoL/Travel/Quiz.lua')
    check('Flight Games defaults to the Aim Trainer', qol:find('flightGame = "aim"', 1, true) ~= nil)
    check('the old flight toggles are gone', not qol:find('quizFlight', 1, true) and not qol:find('aimAutoFlight', 1, true)
        and not quiz:find('quizFlight', 1, true))
    check('the quiz card puts its position back to the default', quiz:find('label = "Quiz Position", buttonText = "Reset"', 1, true)
        and quiz:find('S.Set("quizPos", nil)', 1, true))
end
do -- the look: today's card by default, then Font, Outline, Bar Texture and Background Opacity
    local s = fixture({ flightEarlyLanding = true })
    s.board()
    local bar = s.find(function(f) return f.scripts.OnUpdate end)
    local land = s.button('Land')
    check('default: the Addon Font, no outline or shadow', bar.time.font == 'font: 20 ' and bar.time.shadow == false
        and bar.to.font == 'font: 14 ')
    check('default: the flat fill and a solid card', bar.fill.texture == 'Interface\\Buttons\\WHITE8X8'
        and bar.bg.alpha == 1 and land._bg.alpha == 1 and bar.from.red == 0.5)
    s.set('flightTimerFont', 'Arial')
    s.set('flightTimerOutline', 'OUTLINE')
    s.set('flightTimerTexture', 'Smooth')
    check('Font, Outline and Bar Texture apply', bar.time.font == 'font:Arial 20 OUTLINE'
        and bar.nextKey.font == 'font:Arial 12 OUTLINE' and bar.fill.texture == 'lsm:Smooth')
    s.set('flightTimerAlpha', 0.3)
    check('Background Opacity fades the card and its buttons', bar.bg.alpha == 0.3 and bar.border._frame.alpha == 0.3
        and land._bg.alpha == 0.3 and land._border._frame.alpha == 0.3)
    check('an outline needs no shadow; muted labels go bright', bar.time.shadow == false and bar.from.red == 1)
    s.set('flightTimerOutline', 'NONE')
    check('plain text over a faded card gets a shadow', bar.time.shadow == 'none' and bar.time.font == 'font:Arial 20 ')
    s.set('flightTimerAlpha', 1)
    check('and loses it on a solid card', bar.time.shadow == false and bar.from.red == 0.5)
    s.set('flightTimerOutline', '')
    check('Shadow keeps one on a solid card', bar.time.shadow == 'card')
end
do -- Flight Time on Map: a destination's time joins its tooltip on the flight master's map
    local tip = { lines = {} }
    function tip:AddDoubleLine(left, right) self.lines[#self.lines + 1] = left .. ' ' .. right end
    function tip:Show() self.shown = true end
    local types = { 'CURRENT', 'REACHABLE', 'REACHABLE', 'UNREACHABLE' }
    local names = { 'Ironforge', 'Thelsamar', 'Menethil Harbor', 'Far Away' }
    local entered = 0
    local s = fixture({}, { GameTooltip = tip, TaxiNodeOnButtonEnter = function() entered = entered + 1 end,
        NumTaxiNodes = function() return #types end, TaxiNodeGetType = function(i) return types[i] end,
        TaxiNodeName = function(i) return names[i] end, GetTaxiMapID = function() return 1 end,
        C_TaxiMap = { GetAllTaxiNodes = function()
            return { { slotIndex = 1, nodeID = 6 }, { slotIndex = 2, nodeID = 8 }, { slotIndex = 3, nodeID = 7 } }
        end },
        C_Traits = { GetConfigIDByTreeID = function() end }, GetNumRoutes = function() return 1 end,
        TaxiGetNodeSlot = function(slot, _, source) return source and 1 or slot end })
    local account = { flightTimes = { ['Ironforge|Menethil Harbor'] = 75 } }
    s.ns.AccountSettings = function() return account end
    s.ns.FLIGHT_ROUTES = { [60008] = 3040 }
    local function hover(slot)
        tip.lines, tip.shown = {}, false
        s.env.TaxiNodeOnButtonEnter({ GetID = function() return slot end })
        return tip.lines[1]
    end
    check('off by default: no line, and the map is not even hooked', hover(2) == nil and entered == 1
        and s.env.TaxiNodeOnButtonEnter ~= nil and not tip.shown)
    s.set('flightTimerMapTime', true)
    check('a destination with route data shows its estimate', hover(2) == 'Flight Time 1:40' and tip.shown)
    check('one without falls back to the learned time', hover(3) == 'Flight Time 1:15')
    check('where you stand and what you cannot reach get none', hover(1) == nil and hover(4) == nil)
    account.flightTimes = {}
    check('no route data and nothing learned: no line', hover(3) == nil)
    s.set('flightTimerMapTime', false)
    check('Flight Time on Map off: no line', hover(2) == nil)
    s.set('flightTimerMapTime', true)
    s.set('flightTimer', false)
    check('the Flight Timer off: no line', hover(2) == nil)
end

print(checks .. ' flight request-stop checks passed')

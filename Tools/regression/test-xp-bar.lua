-- Run with Lua 5.1 from the repository root: the XP Bar's settings. A colour swatch that is
-- only opened, or cancelled, leaves the colour unset so it keeps following the theme; a text
-- shows in one spot at a time, the level's three forms counting as one; the texts are
-- measured again only when one of them changed; and its Played text comes from Shared.Played.
-- Its look: the defaults draw today's flat bar and outlined texts, and Font, Font Size, Outline,
-- Bar Texture and Background Opacity each apply. It hides in battlegrounds and arenas.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n")
    f:close()
    return s
end

-- The plain values at the top of the XP Bar's file (numbers, texts, its spots), which the
-- functions loaded below on their own read. The QoL constants it names come from NaowhForever_QoL/Constants.lua.
local function Consts(source)
    local block = assert(source:match("\n(local MINUTE, HOUR = .-)\n\n"))
    return "local QOL_CONSTANTS = dofile(\"Tools/regression/qol_constants.lua\")\n"
        .. "local ns = setmetatable({ L = dofile(\"Tools/regression/locale_stub.lua\").L }, { __index = ns })\n"
        .. (block:gsub("ns%.QoLConstants%.", "QOL_CONSTANTS.")) .. "\n"
end

-- Runs source with env as its globals and hands back what it returns.
local function Load(source, env)
    local fn = assert(loadstring(source))
    setfenv(fn, setmetatable(env, { __index = _G }))
    return fn()
end

local function Settings(defaults)
    local db = {}
    local S = { db = db }
    function S.DB() return db end
    function S.Get(k)
        if db[k] == nil then return defaults[k] end
        return db[k]
    end
    function S.Set(k, v) db[k] = v end
    return S
end

-- A colour swatch: opening the picker reports the colour it opens with, and so does cancel.
do
    local source = Read("NaowhForever_QoL/XP/XPBar.lua")
    local chunk = "local SAME_COLOUR = 1 / 255\n"
        .. assert(source:match("(local function SetColour%(.-\nend\n\nlocal function ColourRow%(.-\nend)\n"))
    local S = Settings({})
    local accent = { r = 0, g = 0x91 / 255, b = 0xed / 255 }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, XPBarDefaultColor = function() return accent end }
    function ns.XPBarColor(k) return S.Get(k) or accent end
    local ColourRow = Load(chunk .. "\nreturn ColourRow", { S = S, ns = ns })
    local row = ColourRow("xpBarFillColor", "Fill Color")
    row.getValue, row.setValue = row.get, row.set

    row.setValue(row.getValue())
    check("opening a swatch on the default saves nothing", S.db.xpBarFillColor == nil)
    row.setValue(accent.r + 0.5 / 255, accent.g, accent.b - 0.5 / 255)
    check("a color within 1/255 of the default is the default", S.db.xpBarFillColor == nil)
    row.setValue(0.2, 0.8, 0.4)
    check("a real pick is saved", S.db.xpBarFillColor and S.db.xpBarFillColor.g == 0.8)
    row.setValue(0.2, 0.8, 0.4)
    check("cancelling reports the pick back, which stays", S.db.xpBarFillColor.r == 0.2)
    row.setValue(accent.r, accent.g, accent.b)
    check("picking the default again goes back to following the theme", S.db.xpBarFillColor == nil)
end

-- One spot per text.
do
    local source = Read("NaowhForever_QoL/XP/XPBar.lua")
    local chunk = Consts(source)
        .. assert(source:match("(local function TextOf%(which%).-\nlocal function OneEach%(spots%).-\nend)\n"))
    local spots = { { key = "a" }, { key = "b" }, { key = "c" } }

    local S = Settings({ a = "played", b = "xphour", c = "none" })
    local env = { S = S }
    Load(chunk .. "\nClaimFn, OneEachFn = Claim, OneEach", env)

    S.db.c = "xphour"
    env.OneEachFn(spots)
    check("a text saved in two spots keeps the first", S.Get("b") == "xphour" and S.Get("c") == "none")

    env.ClaimFn(spots, "c", "played")
    check("picking a text for a spot clears the spot that had it", S.Get("a") == "none")

    S.db.a, S.db.b = "level", "none"
    env.ClaimFn(spots, "b", "levelnum")
    check("the level's forms count as one text", S.Get("a") == "none")

    S.db.a, S.db.b = "level", "levelshort"
    env.OneEachFn(spots)
    check("a profile with two level forms keeps the first", S.Get("a") == "level" and S.Get("b") == "none")

    S.db.a, S.db.b = "none", "none"
    env.ClaimFn(spots, "a", "none")
    check("None is never claimed", S.Get("b") == "none")
end

-- The texts are measured again only when one of them changed.
do
    local source = Read("NaowhForever_QoL/XP/XPBar.lua")
    local chunk = assert(source:match("(local function TextsChanged%(list%).-\nend)\n"))
    local TextsChanged = Load(chunk .. "\nreturn TextsChanged", {})
    local function FS(text) return { text = text, GetText = function(self) return self.text end } end
    local list = { FS("Level 20"), FS("2509 / 23200"), FS("10.8%") }
    check("the first look counts as a change", TextsChanged(list))
    check("nothing changed", not TextsChanged(list))
    list[2].text = "2510 / 23200"
    check("one text changed", TextsChanged(list))
    check("and is remembered", not TextsChanged(list))
end

-- Played time, from the shared helper: nothing made or asked for at load, one muted /played for
-- whoever wants it first, the chat given it back, the clock running on through a ding, and the
-- bar's Played text drawn from it the same way as before.
do
    local now, requests, made, timers, level = 1000, 0, 0, {}, 20
    local function Events(f) return f.events end
    local META = { __index = {
        RegisterEvent = function(f, e) f.events[e] = true end,
        UnregisterEvent = function(f, e) f.events[e] = nil end,
        UnregisterAllEvents = function(f) for e in pairs(f.events) do f.events[e] = nil end end,
        IsEventRegistered = function(f, e) return f.events[e] == true end,
        SetScript = function(f, _, fn) f.onEvent = fn end,
    } }
    local function Frame() return setmetatable({ events = {} }, META) end
    local chat1, chat2 = Frame(), Frame()
    chat1.events.TIME_PLAYED_MSG = true
    local frame
    local env = {
        NaowhForever = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Shared = {} },
        GetTime = function() return now end,
        UnitLevel = function() return level end,
        CreateFrame = function() made = made + 1; frame = Frame(); return frame end,
        C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
        RequestTimePlayed = function() requests = requests + 1 end,
        NUM_CHAT_WINDOWS = 2, ChatFrame1 = chat1, ChatFrame2 = chat2,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    }
    env._G = env
    Load(Read("Shared/Game/Played.lua"), env)
    local Played = env.NaowhForever.Shared.Played
    check("nothing made or asked for at load", made == 0 and requests == 0 and #timers == 0)
    check("nothing known yet", Played.Total() == nil and Played.Level() == nil)
    Played.Drop("xpBar")
    check("dropping what was never wanted is fine", made == 0)

    local answers, dings = 0, 0
    local hooked = { Answered = Played.Answered, LeveledUp = Played.LeveledUp }
    Played.Answered = function(...) hooked.Answered(...); answers = answers + 1 end
    Played.LeveledUp = function(...) hooked.LeveledUp(...); dings = dings + 1 end

    Played.Want("xpBar")
    check("the first want listens and asks once", made == 1 and Events(frame).TIME_PLAYED_MSG
        and Events(frame).PLAYER_LEVEL_UP and requests == 1)
    check("with the chat print muted", chat1.events.TIME_PLAYED_MSG == nil and chat2.events.TIME_PLAYED_MSG == nil)
    Played.Want("xpTicker")
    check("a second want does not ask again", made == 1 and requests == 1)

    now = now + 2
    frame.onEvent(frame, "TIME_PLAYED_MSG", 368520, 12540)
    check("the answer is heard", answers == 1 and Played.Total() == 368520 and Played.Level() == 12540)
    for _, fn in ipairs(timers) do fn() end
    check("the chat frames get the event back", chat1.events.TIME_PLAYED_MSG == true
        and chat2.events.TIME_PLAYED_MSG == nil)
    now = now + 30
    check("the clock runs on", Played.Total() == 368550 and Played.Level() == 12570)
    level = 21
    frame.onEvent(frame, "PLAYER_LEVEL_UP", 21)
    check("a ding: the total keeps running, this level starts again", dings == 1
        and Played.Total() == 368550 and Played.Level() == 0)
    now = now + 10
    check("and counts up", Played.Total() == 368560 and Played.Level() == 10)

    local source = Read("NaowhForever_QoL/XP/XPBar.lua")
    local chunk = Consts(source) .. assert(source:match("(local function Duration%(seconds%).-\nend)\n"))
        .. "\n" .. assert(source:match("(local function SlotText%(which, maxed, max%).-\nend)\n"))
    local SlotText = Load(chunk .. "\nreturn SlotText", { Played = Played, sessionStart = 0,
        time = function() return 0 end, ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Color = function() return "" end } })
    check("the bar's Played text, from the helper", SlotText("played", false, 1)
        == "Played:|r 4d 6h 22m|r - This Level:|r 0m|r")

    Played.Drop("xpBar")
    check("still listening while someone wants it", Events(frame).TIME_PLAYED_MSG)
    Played.Drop("xpTicker")
    check("nobody wants it: nothing listening", next(Events(frame)) == nil)
    Played.Want("xpBar")
    check("wanted again at the level it knows: no new /played", requests == 1 and Events(frame).TIME_PLAYED_MSG)
    Played.Drop("xpBar")
    level = 22
    Played.Want("xpBar")
    check("a ding missed while nobody listened asks again", requests == 2)
    check("the bar asks only while its Played text shows", source:find(
        'if ShowsText("played") then Played.Want("xpBar") else Played.Drop("xpBar") end', 1, true))
end

-- The bar's texture and background: flat and 85% by default, then the picked ones.
do
    local source = Read("NaowhForever_QoL/XP/XPBar.lua")
    local chunk = assert(source:match("(local FILL_FROM = .-\nlocal function PaintBar%(b%).-\nend)\n"))
    local S = Settings({ xpBarTexture = "", xpBarBgAlpha = 0.85 })
    local function Tex()
        local t = {}
        function t.SetTexture(self, path) self.texture = path end
        function t.SetVertexColor(self, r, g, b, a) self.color = { r, g, b, a } end
        function t.SetColorTexture(self, r, g, b, a) self.color = { r, g, b, a } end
        function t.SetGradient() end
        function t.SetColor() end
        return t
    end
    local b = { fill = Tex(), done = Tex(), open = Tex(), rested = Tex(), bg = Tex(), edge = Tex() }
    local env = { S = S, T = { accent = { r = 0, g = 0.5, b = 1 }, bg = { r = 0.1, g = 0.1, b = 0.1 } },
        CreateColor = function(r, g, bl, a) return { r = r, g = g, b = bl, a = a } end,
        ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, ThemeTint = function(_, c) return c end, Shared = { Style = dofile("Tools/regression/shared_style.lua") },
            UI = { TexturePath = function(name, own) if name == "" then return own end return "lsm:" .. name end } } }
    local PaintBar = Load(chunk .. "\nreturn PaintBar", env)
    PaintBar(b)
    local FLAT = "Interface\\Buttons\\WHITE8X8"
    check("default: every segment flat", b.fill.texture == FLAT and b.done.texture == FLAT and b.open.texture == FLAT
        and b.rested.texture == FLAT)
    check("default: quest XP in full, incomplete faded", b.done.color[4] == 1 and b.open.color[4] == 0.4)
    check("default: the background at 85%", b.bg.color[4] == 0.85 and b.bg.color[1] == 0.1)
    S.Set("xpBarTexture", "Smooth")
    S.Set("xpBarBgAlpha", 0.5)
    PaintBar(b)
    check("Bar Texture applies to the fill and every segment", b.fill.texture == "lsm:Smooth"
        and b.done.texture == "lsm:Smooth" and b.rested.texture == "lsm:Smooth")
    check("Background Opacity applies", b.bg.color[4] == 0.5)
end

-- The texts' font: the Addon Font outlined at 13 by default, then the picked font, size and outline.
do
    local source = Read("NaowhForever_QoL/XP/XPBar.lua")
    local chunk = Consts(source)
        .. assert(source:match("(local function Natural%(fs%).-\nlocal function FitSlots%(slots, w, placeMid%).-\nend)\n"))
    local S = Settings({ xpBarFont = "", xpBarFontSize = 13, xpBarOutline = "OUTLINE" })
    local set = 0
    local Parts = { HudFont = function(fs, font, size, outline) fs.font = font .. " " .. size .. " " .. outline; set = set + 1 end }
    local FitSlots = Load(chunk .. "\nreturn FitSlots", { S = S, Parts = Parts, BESIDE = { 4, 5 },
        TOP_LEFT = 1, TOP = 2, TOP_RIGHT = 3, BOTTOM_LEFT = 6, BOTTOM = 7, BOTTOM_RIGHT = 8 })
    local slots = {}
    for i = 1, 8 do
        slots[i] = { GetText = function() return "" end, SetWidth = function() end, GetStringWidth = function() return 0 end }
    end
    FitSlots(slots, 500, function() end)
    check("default: the Addon Font, outlined, at 13", slots[1].font == " 13 OUTLINE" and slots[4].font == " 13 OUTLINE")
    set = 0
    FitSlots(slots, 500, function() end)
    check("an unchanged font is not set again", set == 0)
    S.Set("xpBarFont", "Arial")
    S.Set("xpBarOutline", "")
    S.Set("xpBarFontSize", 16)
    FitSlots(slots, 500, function() end)
    check("Font, Outline and Font Size apply around the bar", slots[2].font == "Arial 16 " and slots[5].font == "Arial 16 ")
end

-- Battlegrounds and arenas: the bar is hidden there, checked again on every loading screen and
-- when it is turned on.
do
    local source = Read("NaowhForever_QoL/XP/XPBar.lua")
    local chunk = assert(source:match("\n(local PVP_INSTANCES = .-)\n"))
        .. "\n" .. assert(source:match("(local function InPvP%(%).-\nend)\n"))
    local kind
    local env = { IsInInstance = function() return kind ~= "none", kind end }
    Load(chunk .. "\nInPvPFn = InPvP", env)
    for where, hidden in pairs({ pvp = true, arena = true, none = false, party = false, raid = false,
        scenario = false }) do
        kind = where
        check(("%s: hidden is %s"):format(where, tostring(hidden)), env.InPvPFn() == hidden)
    end
    check("every loading screen checks again", source:match("local EVENTS = {[^}]-\"PLAYER_ENTERING_WORLD\"")
        and source:find('if event == "PLAYER_ENTERING_WORLD" then\n        inPvP = InPvP()', 1, true))
    check("turning it on checks too", source:match("local function Apply%(%).-inPvP = InPvP%(%).-\nend\n"))
    check("in PvP it hides, except in the HUD Editor",
        source:find('if not unlocked and (inPvP or (maxed and not S.Get("xpBarMaxLevel"))) then', 1, true))
end

print(("test-xp-bar: %d checks passed"):format(checks))

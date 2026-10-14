-- Run with Lua 5.1 from the repository root: the XP Bar's settings. A colour swatch that is
-- only opened, or cancelled, leaves the colour unset so it keeps following the theme; a text
-- shows in one spot at a time, the level's three forms counting as one; the texts are
-- measured again only when one of them changed; and its Played text comes from Shared.Played.
-- Its look: the defaults draw today's flat bar and outlined texts, and Font, Font Size, Outline,
-- Bar Texture and Background Opacity each apply. It hides in battlegrounds and arenas.
-- Its preview fills the stage with the bar, marks empty spots with + chips that never cover a
-- text, and keeps both resets in the bar's right-click menu.
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
    local chunk = Consts(source) .. assert(source:match("(local function Short%(n%).-\nend)\n"))
        .. "\n" .. assert(source:match("(local function Duration%(seconds%).-\nend)\n"))
        .. "\n" .. assert(source:match("(local function SlotText%(which, maxed, max%).-\nend)\n"))
    local clock, xp = 0, 2000
    local slotEnv = { Played = Played, sessionStart = 0, sessionXP = 0,
        time = function() return clock end, UnitXP = function() return xp end,
        ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
            Color = function() return "" end } }
    local SlotText = Load(chunk .. "\nreturn SlotText", slotEnv)
    check("the bar's Played text, from the helper, in its two largest units", SlotText("played", false, 1)
        == "Played:|r 4d 6h|r   This Level:|r 0m|r")
    check("no XP yet this session: Time to Level and XP/Hour stay blank, not -- and 0",
        SlotText("leveling", false, 10000) == "" and SlotText("xphour", false, 10000) == ""
        and SlotText("pace", false, 10000) == "")
    clock, slotEnv.sessionXP = 3600, 4000
    check("with a rate they show, with short labels", SlotText("leveling", false, 10000) == "To Level:|r 2h 0m|r"
        and SlotText("xphour", false, 10000) == "XP/h:|r 4.0k|r")
    check("Leveling Pace says both in one text", SlotText("pace", false, 10000) == "2h 0m|r to level at 4.0k|r/h|r")
    check("and hides at max level", SlotText("pace", true, 10000) == "")

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
    local b = { fill = Tex(), done = Tex(), open = Tex(), rested = Tex(), restedEdge = Tex(), bg = Tex(), edge = Tex() }
    local env = { S = S, T = { accent = { r = 0, g = 0.5, b = 1 }, bg = { r = 0.1, g = 0.1, b = 0.1 } },
        CreateColor = function(r, g, bl, a) return { r = r, g = g, b = bl, a = a } end,
        ns = { XPBarFX = { Paint = function(bar, q, r) bar.painted = { q, r } end },
            L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, ThemeTint = function(_, c) return c end, Shared = { Style = dofile("Tools/regression/shared_style.lua") },
            UI = { TexturePath = function(name, own) if name == "" then return own end return "lsm:" .. name end } } }
    local PaintBar = Load(chunk .. "\nreturn PaintBar", env)
    PaintBar(b)
    local FLAT = "Interface\\Buttons\\WHITE8X8"
    check("default: every segment flat", b.fill.texture == FLAT and b.done.texture == FLAT and b.open.texture == FLAT
        and b.rested.texture == FLAT)
    check("default: quest XP in full, incomplete faded", b.done.color[4] == 1 and b.open.color[4] == 0.4)
    check("default: the background at 85%", b.bg.color[4] == 0.85 and b.bg.color[1] == 0.1)
    check("the effects and the rested band are painted in the quest and rested colors", b.painted
        and b.painted[1].r == b.done.color[1] and b.painted[2].b ~= nil)
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

-- The preview: the bar scaled up to fill the stage, its empty spots marked by small + chips that
-- show only while the stage is hovered and never sit on a text or on each other, whatever the
-- texts say; the texts in a row never run into each other; both resets in the bar's right-click
-- menu, none of them a row.
do
    local source = Read("NaowhForever_QoL/XP/XPBar.lua")
    local chunk = Consts(source)
        .. assert(source:match("(local function Natural%(fs%).-\nlocal function FitSlots%(slots, w, placeMid%).-\nend)\n"))
        .. "\n" .. assert(source:match("(local STAGE = {.-\nSTAGE%.TEXT_ROOM = [^\n]*)\n"))
        .. "\n" .. assert(source:match("(local function Reveal%(preview, on%).-\nlocal function StageLeave%(frame%).-\nend)\n"))
        .. "\n" .. assert(source:match("(local function Seen%(fs%).-\nlocal function RowChips%(w, l, m, r%).-\nend)\n"))
        .. "\n" .. assert(source:match("(local function PreviewScale%(.-\nlocal function FitStage%(preview, w, h%).-\nend)\n"))
    local S = Settings({ xpBarFont = "", xpBarFontSize = 13, xpBarOutline = "OUTLINE" })
    local Parts = { HudFont = function(fs, _, size) fs.size = size end }
    local env = { S = S, Parts = Parts, THIRDS = tonumber(source:match("\nlocal THIRDS = (%d+)")),
        ns = { Shared = { Style = dofile("Tools/regression/shared_style.lua") } } }
    Load(chunk .. "\nFns = { FitSlotRow = FitSlotRow, RowChips = RowChips, Seen = Seen, Reveal = Reveal, "
        .. "StageEnter = StageEnter, StageLeave = StageLeave, PreviewScale = PreviewScale, FitStage = FitStage, "
        .. "STAGE = STAGE, TEXT_GAP = TEXT_GAP, SIDE_GAP = SIDE_GAP, SLOT_DROP = SLOT_DROP }", env)
    local F = env.Fns
    local CHIP, GAP = F.STAGE.CHIP, F.TEXT_GAP

    local FS = {}
    FS.__index = FS
    function FS:GetText() return self.text end
    function FS:GetUnboundedStringWidth() return #self.text * self.size * 0.5 end
    function FS:GetStringWidth() return self:GetUnboundedStringWidth() end
    function FS:SetWidth(w) self.width = w end
    function FS:GetWidth() return self.width or self:GetUnboundedStringWidth() end
    function FS:GetPoint() return "CENTER", nil, "CENTER", self.dx, 0 end
    local function Row(a, b, c)
        return { setmetatable({ text = a, size = 13, dx = 0 }, FS), setmetatable({ text = b, size = 13, dx = 0 }, FS),
            setmetatable({ text = c, size = 13, dx = 0 }, FS) }
    end
    local function Lay(texts, w, base)
        F.FitSlotRow(texts, w, function(i, dx) texts[i].dx = dx end, base, 1, 2, 3)
        return F.RowChips(w, texts[1], texts[2], texts[3])
    end
    local function Spans(texts, w, lx, mx, rx)
        local spans, chips = {}, {}
        local l, m, r = F.Seen(texts[1]), F.Seen(texts[2]), F.Seen(texts[3])
        if l > 0 then spans[#spans + 1] = { 0, l } end
        if m > 0 then
            local c = w / 2 + texts[2].dx
            spans[#spans + 1] = { c - m / 2, c + m / 2 }
        end
        if r > 0 then spans[#spans + 1] = { w - r, w } end
        for _, x in ipairs({ lx or false, mx or false, rx or false }) do
            if x then chips[#chips + 1] = { x, x + CHIP } end
        end
        return spans, chips
    end
    local function Apart(a, b, gap) return a[2] + gap <= b[1] + 1e-6 or b[2] + gap <= a[1] + 1e-6 end

    local texts = Row("", "", "")
    local lx, mx, rx = Lay(texts, 520, 13)
    check("an empty row gets a + at each end and in the middle", lx == 0 and rx == 520 - CHIP
        and mx == (520 - CHIP) / 2)
    texts = Row("Played: 4d 6h 22m - This Level: 3h 29m", "", "")
    lx, mx, rx = Lay(texts, 520, 13)
    local _, chips = Spans(texts, 520, lx, mx, rx)
    check("a long text on the left: the middle + still has room, clear of it", not lx and mx and rx
        and mx >= F.Seen(texts[1]) + GAP and #chips == 2)
    texts = Row(("x"):rep(60), "", "")
    lx, mx, rx = Lay(texts, 400, 13)
    local spans
    spans, chips = Spans(texts, 400, lx, mx, rx)
    check("a text past the middle pushes the middle + along, never onto it", mx == nil or Apart(spans[1], chips[1], GAP))

    math.randomseed(1)
    local runs, placed = 0, 0
    for _ = 1, 3000 do
        local w = ({ 400, 520, 800, 1200 })[math.random(4)]
        local base = ({ 8, 13, 20 })[math.random(3)]
        local function Text() return math.random(3) == 1 and "" or ("x"):rep(math.random(1, 90)) end
        texts = Row(Text(), Text(), Text())
        lx, mx, rx = Lay(texts, w, base)
        spans, chips = Spans(texts, w, lx, mx, rx)
        local ok = true
        for i = 1, #spans do
            for j = i + 1, #spans do ok = ok and Apart(spans[i], spans[j], GAP) end
            for _, chip in ipairs(chips) do ok = ok and Apart(spans[i], chip, GAP) end
        end
        for i = 1, #chips do
            ok = ok and chips[i][1] >= 0 and chips[i][2] <= w
            for j = i + 1, #chips do ok = ok and Apart(chips[i], chips[j], 0) end
        end
        assert(ok, ("texts %d/%d/%d at %d, size %d"):format(#texts[1].text, #texts[2].text, #texts[3].text, w, base))
        runs, placed = runs + 1, placed + #chips
    end
    check("3000 rows of any length: texts never touch, a + never sits on a text or another +", runs == 3000
        and placed > 0)

    local function Chip(at) return { placed = at, SetShown = function(self, on) self.shown = on end } end
    local over = true
    local preview = { chips = { Chip(true), Chip(false), Chip(true) }, IsMouseOver = function() return over end }
    preview.preview = preview
    F.Reveal(preview, false)
    check("the + chips are hidden while the stage is not hovered", not preview.chips[1].shown
        and not preview.chips[3].shown)
    F.StageEnter({ preview = preview })
    check("hovering the stage shows the placed ones only", preview.chips[1].shown and preview.chips[3].shown
        and not preview.chips[2].shown)
    F.StageLeave(preview)
    check("moving onto a text on the stage keeps them", preview.chips[1].shown)
    over = false
    F.StageLeave({ preview = preview })
    check("leaving the stage hides them", not preview.chips[1].shown and not preview.chips[3].shown)

    local stage = F.STAGE
    local roomH = stage.H - stage.MARGIN * 2 - stage.TEXT_ROOM
    local function Footprint(w, h, side)
        return w + (math.max(side, CHIP) + F.SIDE_GAP) * 2, h + (math.max(13, CHIP) + F.SLOT_DROP) * 2
    end
    local footW, footH = Footprint(520, 26, 0)
    local scale = F.PreviewScale(1098 - stage.MARGIN * 2, roomH, footW, footH)
    check("the default bar shows at its real size, never blown up", scale == 1 and stage.MAX_SCALE == 1)
    footW, footH = Footprint(1200, 48, 240)
    check("the tallest bar fits the stage's height", footH <= roomH)
    scale = F.PreviewScale(700 - stage.MARGIN * 2, roomH, footW, footH)
    check("a wide bar with long side texts shrinks to fit a narrow stage", scale < 1
        and footW * scale <= 700 - stage.MARGIN * 2 + 1e-6)
    footW, footH = Footprint(400, 14, 0)
    check("a small bar stops at the largest scale", F.PreviewScale(3000, 3000, footW, footH) == stage.MAX_SCALE)

    local bar = { slots = {} }
    for i = 1, 8 do bar.slots[i] = setmetatable({ text = "", size = 13, dx = 0 }, FS) end
    function bar.SetScale(self, s) self.scale = s end
    function bar.ClearAllPoints() end
    function bar.SetPoint(self, _, _, _, x, y) self.x, self.y = x, y end
    local shot = { bar = bar, GetWidth = function() return 1098 end, GetHeight = function() return stage.H end }
    F.FitStage(shot, 520, 26)
    check("the stage centres the bar above its note", bar.x == 0 and bar.y > 0 and bar.scale == 1)

    check("no Reset rows on the card", not source:find("button = ns.ResetXPBar", 1, true))
    check("both resets in the bar's right-click menu", source:find(
        "root:CreateButton(TEXT.RESET_LAYOUT_LABEL, ns.ResetXPBarLayout)", 1, true)
        and source:find("root:CreateButton(TEXT.RESET_COLORS_LABEL, ns.ResetXPBarColors)", 1, true)
        and source:find("EditZone(b, { menu = BarMenu", 1, true)
        and source:find("MenuUtil.CreateContextMenu(zone, BarMenu)", 1, true))
    check("the empty spots are no longer written into the texts", not source:find("TEXT.ADD", 1, true))
end

-- Show Texts On Mouseover: the texts stay up while it is Off; Around the Bar hides only the texts
-- around it and All Texts those on it too, until the mouse is over the bar or the texts round it;
-- the HUD Editor shows them all; the bar never takes a click unless Ctrl is held.
do
    local source = Read("NaowhForever_QoL/XP/XPBar.lua")
    local chunk = Consts(source)
        .. assert(source:match("(local function Natural%(fs%).-\nend)\n"))
        .. "\nlocal bar, unlocked, hovered\n"
        .. assert(source:match("(local Hover = .-\nend)\n\nlocal function Update%(%)"))
    local S = Settings({ xpBarTextsHover = "off", xpBarFontSize = 13 })
    local ctrl = false
    local shown, hidden = nil, 0
    local env = { S = S, IsControlKeyDown = function() return ctrl end,
        FX = { ShowBreakdown = function(_, d) shown = d end, HideBreakdown = function() hidden = hidden + 1 end },
        UnitXP = function() return 11941 end, UnitXPMax = function() return 23200 end,
        UnitLevel = function() return 20 end, GetXPExhaustion = function() return 3596 end,
        AtMaxLevel = function() return false end, time = function() return 3600 end,
        Duration = function(s) return math.floor(s) .. "s" end }
    env.questDone, env.questOpen, env.sessionStart, env.sessionXP = 11300, 1856, 0, 4000
    Load(chunk .. "\nfunction Set(b) bar = b end\nfunction Unlock(on) unlocked = on end\n"
        .. "Enter, Leave, Mouse = Hover.Enter, Hover.Leave, Hover.Mouse", env)

    local function Layer() return { alpha = 1, SetAlpha = function(self, a) self.alpha = a end } end
    local function FS(text, w)
        return { GetText = function() return text end, GetStringWidth = function() return w end }
    end
    local b = { around = Layer(), text = Layer(), slots = {} }
    for i = 1, 8 do b.slots[i] = FS("", 0) end
    b.slots[1], b.slots[8], b.slots[5] = FS("Played: 6d", 120), FS("XP/Hour: 0", 80), FS("Rested", 49)
    function b.SetHitRectInsets(self, l, r, t, bt) self.l, self.r, self.t, self.b = l, r, t, bt end
    function b.SetMouseClickEnabled(self, on) self.click = on end
    function b.SetMouseMotionEnabled(self, on) self.motion = on end
    env.Set(b)

    env.Mouse()
    env.Leave()
    check("Off: the texts stay up and the bar takes no mouse", b.around.alpha == 1 and b.text.alpha == 1
        and not b.click and not b.motion)

    S.db.xpBarTextsHover = "around"
    env.Mouse()
    env.Leave()
    check("Around the Bar hides the texts around it only", b.around.alpha == 0 and b.text.alpha == 1)
    check("it follows the mouse without taking clicks", b.motion and not b.click)
    check("the hover area reaches the texts round the bar", b.t == -(13 + 4) and b.b == -(13 + 4)
        and b.l == 0 and b.r == -(50 + 6))
    env.Enter()
    check("hovering shows them", b.around.alpha == 1)

    S.db.xpBarTextsHover = "all"
    env.Leave()
    check("All Texts hides those on the bar too", b.around.alpha == 0 and b.text.alpha == 0)
    env.Unlock(true)
    env.Leave()
    check("the HUD Editor shows every text", b.around.alpha == 1 and b.text.alpha == 1)
    env.Unlock(false)

    ctrl = true
    env.Mouse()
    check("Ctrl still lets the bar take its right-click", b.click and b.motion)
    ctrl = false
    S.db.xpBarTextsHover = "off"
    env.Enter()
    env.Mouse()
    env.Leave()
    check("turned Off, nothing stays hidden", b.around.alpha == 1 and b.text.alpha == 1 and not b.motion)
    check("no breakdown unless it is on", shown == nil)

    S.db.xpBarBreakdown = true
    env.Mouse()
    check("Hover Breakdown alone still follows the mouse, without taking clicks", b.motion and not b.click)
    env.Enter()
    check("hovering shows the breakdown: XP to level, quests, rested and the pace", shown and shown.left == 11259
        and shown.level == 20 and shown.done == 11300 and shown.open == 1856 and shown.rested == 3596
        and shown.pace == "10133s")
    check("completed quests that cover the rest are ready", shown.ready == true)
    local before = hidden
    env.Leave()
    check("leaving hides it", hidden == before + 1)
    S.db.xpBarBreakdown = nil
    check("the texts around the bar sit on their own layer",
        source:find('ns.Font(b.around, S.Get("xpBarFontSize"), "OUTLINE")', 1, true) ~= nil)
end

print(("test-xp-bar: %d checks passed"):format(checks))

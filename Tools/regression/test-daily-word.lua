-- Offline checks for the Daily Word (NaowhForever_QoL/Travel/DailyWord.lua) and its words (DailyWordData.lua):
-- the word lists' shape, nothing built while off, the day's word from the server day, typing, short and unknown
-- words, repeated-letter colors, solving, missing, the share line, streaks across days, combat and flights.
-- These do not emulate client taint or rendering. Run with Lua 5.1 from the repository root.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local DAY = 86400
local FIRST_DAY = 20741

local function fixture(settings)
    local s = { created = 0, frames = {}, settings = settings or {}, account = {}, combat = false,
        now = (FIRST_DAY + 1) * DAY + 100, wait = 3600, shared = nil }
    local any
    local function noop() return any end
    any = setmetatable({}, { __index = function() return noop end })
    local M = {}
    local meta = { __index = function(_, k)
        if M[k] then return M[k] end
        if k:match("^%u") then return noop end
    end }
    local function new(kind, parent)
        return setmetatable({ kind = kind, parent = parent, scripts = {}, events = {}, shown = true, text = "" }, meta)
    end
    function M:SetScript(k, fn) self.scripts[k] = fn end
    function M:RegisterEvent(e) self.events[e] = true end
    function M:UnregisterAllEvents() self.events = {} end
    function M:Show()
        if self.shown then return end
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function M:Hide()
        if not self.shown then return end
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function M:SetShown(v) if v then self:Show() else self:Hide() end end
    function M:IsShown() return self.shown end
    function M:SetText(t) self.text = t end
    function M:GetText() return self.text end
    function M:SetFocus() self.focus = true end
    function M:ClearFocus() self.focus = false end
    function M:SetColorTexture(r, g, b) self.color = { r, g, b } end
    function M:SetColor(r, g, b) self.color = { r, g, b } end
    function M:CreateTexture() return new("Texture", self) end
    local function frame(kind, _, parent)
        s.created = s.created + 1
        local f = new(kind, parent)
        s.frames[#s.frames + 1] = f
        return f
    end
    local S = {
        Get = function(k) local v = s.settings[k]; if v == nil and k == "enabled" then return true end; return v end,
        Set = function(k, v) s.settings[k] = v end,
    }
    local ns = {
        L = dofile("Tools/regression/locale_stub.lua").L, QoLSettings = S,
        QoLConstants = dofile("Tools/regression/qol_constants.lua"),
        THEME = { bg = {}, panel = { r = 0, g = 0, b = 0 }, line = { r = 0.2, g = 0.2, b = 0.2 },
            muted = { r = 0.5, g = 0.5, b = 0.5 }, accent = {}, fg = {} },
        Shared = { Style = dofile("Tools/regression/shared_style.lua"),
            Parts = { ShareMenu = function(_, _, line) s.shared = line end },
            Settings = { Page = function() return { Card = function(_, card) s.card = card end } end } },
        AccountSettings = function() return s.account end,
        AllowOffscreen = function() end,
        Solid = function(parent) return new("Texture", parent) end,
        Border = function(parent) return new("Border", parent) end,
        Font = function(parent) return new("FontString", parent) end,
        Button = function(parent, text, _, _, onClick)
            local b = frame("Button", nil, parent)
            b.label, b._onClick = text, onClick
            return b
        end,
        AccentBorder = function(f) return f end,
        RegisterMinimapFeature = function(feature) s.minimap = feature end,
        FlightGameHideButton = function(parent)
            local b = frame("Button", nil, parent)
            b.shown = false
            s.hide = b
            return b
        end,
        FlightGameOffered = function(reason) return reason == "flight" end,
    }
    local env = setmetatable({
        _G = { NaowhForever = ns },
        CreateFrame = frame, UIParent = new("Frame"),
        GetServerTime = function() return s.now end,
        C_DateAndTime = { GetSecondsUntilDailyReset = function() return s.wait end },
        C_Timer = { NewTicker = function(_, fn) s.tick = fn; return { Cancel = function() s.tick = nil end } end },
        InCombatLockdown = function() return s.combat end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        hooksecurefunc = function(t, k, fn) local old = t[k]; t[k] = function(...) old(...); fn(...) end end,
    }, { __index = _G })
    for _, path in ipairs({ "NaowhForever_QoL/Travel/DailyWordData.lua", "NaowhForever_QoL/Travel/DailyWord.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    s.ns = ns
    function s.window()
        for _, f in ipairs(s.frames) do if f.tiles then return f end end
    end
    function s.type(word)
        local input = s.window().input
        input:SetText(word)
        input.scripts.OnTextChanged(input, true)
    end
    function s.enter()
        local input = s.window().input
        input.scripts.OnEnterPressed(input)
    end
    function s.guess(word) s.type(word); s.enter() end
    function s.watching()
        for _, f in ipairs(s.frames) do if f.events.PLAYER_REGEN_DISABLED then return true end end
        return false
    end
    function s.row(row)
        local out = {}
        for i = 1, 5 do out[i] = s.window().tiles[row][i].fill.color end
        return out
    end
    return s
end

local St = dofile("Tools/regression/shared_style.lua")
local HIT, NEAR, MISS = St.WORD_HIT_RGB, St.WORD_NEAR_RGB, St.WORD_MISS_RGB
local function same(c, rgb) return c and c[1] == rgb.r and c[2] == rgb.g and c[3] == rgb.b end

do
    local ns = {}
    local chunk = assert(loadfile("NaowhForever_QoL/Travel/DailyWordData.lua"))
    setfenv(chunk, { _G = { NaowhForever = ns } })
    chunk()
    local answers, words = ns.DailyWordAnswers, ns.DailyWordWords
    check("the answers are five letters each", #answers % 5 == 0 and not answers:find("[^a-z]"))
    check("the accepted words are five letters each", #words % 5 == 0 and not words:find("[^a-z]"))
    local sorted, prev = true, ""
    for i = 1, #words, 5 do
        local w = words:sub(i, i + 4)
        if w <= prev then sorted = false end
        prev = w
    end
    check("the accepted words are sorted with no repeats", sorted)
    local seen, unique, all = {}, true, {}
    for i = 1, #words, 5 do all[words:sub(i, i + 4)] = true end
    local accepted = true
    for i = 1, #answers, 5 do
        local w = answers:sub(i, i + 4)
        if seen[w] then unique = false end
        seen[w] = true
        if not all[w] then accepted = false end
    end
    check("no answer comes up twice before the list starts over", unique)
    check("every answer is an accepted guess", accepted)
    check("about two thousand days of answers", #answers / 5 > 1500)
end

do
    local s = fixture({ dailyWord = false })
    check("off: nothing is built at load", s.created == 0)
    s.ns.DailyWordPlay(nil)
    check("off: Play does nothing", s.created == 0)
    check("the card and the minimap entry are registered", s.card and s.card.switch == "dailyWord" and s.minimap)
end

do
    local s = fixture({ dailyWord = true })
    s.ns.DailyWordPlay(nil)
    local w = s.window()
    check("on: Play opens it with the keyboard on the grid", w and w.shown and w.input.focus)
    check("day one is #1", w.number.text == "#1")
    check("the countdown is to the daily reset", w.clock.text:find("1:00:00", 1, true) ~= nil)
    s.type("bo1o")
    check("only letters are typed", s.window().input.text == "boo")
    s.enter()
    check("too short is refused", w.message.text == "Not enough letters")
    s.guess("zzzzz")
    check("a word not in the list is refused", w.message.text == "Not in the word list"
        and #s.account.dailyWord.guesses == 0)
    s.guess("booth")
    local row = s.row(1)
    check("against ABOUT, BOOTH: B and T in the word, the first O already counted, O in place, H out",
        same(row[1], NEAR) and same(row[2], MISS) and same(row[3], HIT) and same(row[4], NEAR) and same(row[5], MISS))
    check("the keys take each letter's best color", same(w.keys.o.mark.color, HIT) and same(w.keys.b.mark.color, NEAR)
        and w.keys.h.mark.shown and not w.keys.z.mark.shown)
    check("no share before the end", not w.share.shown)
    w.keys.a._onClick()
    w.keys.b._onClick()
    w.keys.x._onClick()
    check("the on-screen keys type too", w.input.text == "abx")
    for _, b in ipairs(s.frames) do if b.label == "<" then b._onClick() end end
    check("and take a letter back", w.input.text == "ab")
    s.type("about")
    for _, b in ipairs(s.frames) do if b.label == "Enter" then b._onClick() end end
    check("solved in 2", w.message.text == "Solved in 2/6" and w.share.shown and not w.input.focus)
    local d = s.account.dailyWord
    check("the result is saved for the account", d.played == 1 and d.won == 1 and d.streak == 1 and d.best == 1)
    check("the stats line", w.stats.text == "Played 1   Win 100%   Streak 1   Best 1")
    w.share._onClick()
    check("the share line marks each guess with raid icons",
        s.shared == "Naowh Daily Word #1 2/6 {rt1}{rt5}{rt4}{rt1}{rt5} {rt4}{rt4}{rt4}{rt4}{rt4}")
    s.guess("crane")
    check("no more guesses once solved", #d.guesses == 2)
    check("the card's summary", s.card.summary() == "Solved today in 2/6, streak 1")

    check("opened by hand, no Don't Show on Flights eye", not s.hide.shown)
    w:Hide()
    check("closing stops the clock and the combat watch", s.tick == nil and not s.watching())
    local opened = s.ns.DailyWordOffer("flight")
    check("a flight does not reopen a word already played", not w.shown and opened == false)

    s.now = s.now + DAY
    opened = s.ns.DailyWordOffer("flight")
    check("the next day's word opens for a flight, without taking the keyboard", w.shown and not w.input.focus
        and w.number.text == "#2" and opened == true)
    check("a flight opening it shows the Don't Show on Flights eye", s.hide.shown)
    for _ = 1, 6 do s.guess("crane") end
    check("six misses end the game with the word", w.message.text == "The word was SPIRE")
    check("a miss ends the streak and keeps the best", d.played == 2 and d.won == 1 and d.streak == 0 and d.best == 1)
    check("the summary says so", s.card.summary() == "Missed today's word")
    s.ns.DailyWordDismiss("camp")
    check("a dismiss for something else leaves it open", w.shown)
    s.ns.DailyWordDismiss("flight")
    check("landing closes what a flight opened", not w.shown)
end

do
    local s = fixture({ dailyWord = true })
    s.ns.DailyWordPlay(nil)
    local w = s.window()
    s.guess("crane")
    check("a game in progress", s.card.summary() == "1 of 6 guesses used today")
    check("open, it watches for combat", s.watching())
    for _, f in ipairs(s.frames) do
        if f.events.PLAYER_REGEN_DISABLED and f.scripts.OnEvent then f.scripts.OnEvent(f, "PLAYER_REGEN_DISABLED") end
    end
    check("combat closes it", not w.shown)
    s.combat = true
    s.ns.DailyWordPlay(nil)
    check("and it does not open in combat", not w.shown)
    s.combat = false
    s.now = s.now + DAY
    s.ns.DailyWordPlay(nil)
    check("a new day starts a fresh grid", #s.account.dailyWord.guesses == 0 and w.tiles[1][1].letter.text == "")
    s.account.dailyWord.lastWon, s.account.dailyWord.streak = FIRST_DAY, 3
    s.guess("spire")
    check("a win the day after a win adds to the streak", s.account.dailyWord.streak == 4)
    s.now = s.now + 2 * DAY
    check("the card sees the new day", s.card.summary() == "Today's word is waiting")
    s.tick()
    check("the open window moves to the new day at the reset, the streak broken by the skipped day",
        w.number.text == "#4" and w.tiles[1][1].letter.text == "" and w.stats.text:find("Streak 0", 1, true))
    s.settings.dailyWord = false
    s.ns.QoLSettings.Set("dailyWord", false)
    check("switching it off closes it", not w.shown)
end

do
    local s = fixture({ dailyWord = true })
    local handed = 0
    s.ns.FlightWordClosed = function() handed = handed + 1 end
    s.ns.DailyWordOffer("flight")
    local w = s.window()
    local close
    for _, b in ipairs(s.frames) do if not close and b.label == "X" and b.parent == w then close = b end end
    close._onClick()
    check("closing a word a flight opened hands over to the flight's game", not w.shown and handed == 1)
    s.ns.DailyWordPlay(nil)
    close._onClick()
    check("closing one opened by hand does not", handed == 1)
    s.ns.DailyWordPlay(nil)
    check("a word already open by hand is not offered again", s.ns.DailyWordOffer("flight") == false and w.shown)
    w:Hide()
    s.ns.DailyWordOffer("flight")
    s.ns.DailyWordDismiss("flight")
    check("nor does landing", not w.shown and handed == 1)
    s.combat = true
    check("in combat the offer says no", s.ns.DailyWordOffer("flight") == false)
end

print(("test-daily-word: %d checks passed"):format(checks))

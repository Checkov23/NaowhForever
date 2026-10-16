-- DailyWord.lua: the Daily Word, the same five-letter word for everyone each day, for flights and any time with /naowh word.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local St = ns.Shared.Style
local Parts = ns.Shared.Parts

local LETTERS, TRIES = 5, 6
local C = ns.QoLConstants
local SECONDS_PER_DAY, SECONDS_PER_HOUR, SECONDS_PER_MINUTE = C.SECONDS_PER_DAY, C.SECONDS_PER_HOUR, C.SECONDS_PER_MINUTE
local PERCENT, ROUND = C.PERCENT, C.ROUND
local FIRST_DAY = 20741
local CLOCK_EVERY = 1
local WORD_W, WORD_H = 300, 500
local WORD_ALPHA = 0.95
local PAD, CLOSE_SIZE, CLOSE_INSET = 12, 22, 10
local LOGO_SIZE, LOGO_TOP, TITLE_GAP, NUMBER_GAP = 26, 8, 8, 6
local TITLE_SIZE, NUMBER_SIZE, CLOCK_SIZE, MESSAGE_SIZE, STATS_SIZE = 16, 13, 11, 13, 11
local CLOCK_TOP = 42
local TILE, TILE_GAP, TILE_TEXT, GRID_TOP = 40, 5, 20, 62
local MESSAGE_TOP = GRID_TOP + TRIES * TILE + (TRIES - 1) * TILE_GAP + 10
local KEY_W, KEY_WIDE, KEY_H, KEY_GAP = 24, 38, 30, 4
local KEYS_TOP = MESSAGE_TOP + 26
local SHARE_W, SHARE_H, FOOT = 80, 22, 12
local EMPTY_ALPHA = 0.6
local KEY_ROWS = { "qwertyuiop", "asdfghjkl", "zxcvbnm" }
local ENTER, BACK = "enter", "back"
local HIT, NEAR, MISS = "hit", "near", "miss"
local RANK = { [MISS] = 1, [NEAR] = 2, [HIT] = 3 }
local FILL = { [HIT] = St.WORD_HIT_RGB, [NEAR] = St.WORD_NEAR_RGB, [MISS] = St.WORD_MISS_RGB }
local MARKS = { [HIT] = "{rt4}", [NEAR] = "{rt1}", [MISS] = "{rt5}" }
local DEFAULT_Y = 120

local TEXT_TITLE = ns.L("Daily Word")
local TEXT_NUMBER = "#%d"
local TEXT_CLOCK = ns.L("Next word in %d:%02d:%02d")
local TEXT_SHORT = ns.L("Not enough letters")
local TEXT_UNKNOWN = ns.L("Not in the word list")
local TEXT_SOLVED = ns.L("Solved in %d/%d")
local TEXT_MISSED = ns.L("The word was %s")
local TEXT_STATS = ns.L("Played %d   Win %d%%   Streak %d   Best %d")
local TEXT_SHARE = ns.L("Share")
local TEXT_SHARE_TITLE = ns.L("Share Your Daily Word")
local TEXT_SHARE_LINE = ns.L("Naowh Daily Word #%d %s/%d")
local TEXT_LOST_SCORE = "X"
local TEXT_ENTER, TEXT_BACK = ns.L("Enter"), "<"
local TEXT_CLOSE = "X"
local TEXT_WAITING = ns.L("Today's word is waiting")
local TEXT_SUMMARY_SOLVED = ns.L("Solved today in %d/%d, streak %d")
local TEXT_SUMMARY_MISSED = ns.L("Missed today's word")
local TEXT_SUMMARY_PLAYING = ns.L("%d of %d guesses used today")

local word, ticker, openedFor, today, events
local current = ""
local scored, left = {}, {}

local function On()
    return (S.Get("enabled") and S.Get("dailyWord")) and true or false
end

local function Today()
    return math.floor((GetServerTime() + C_DateAndTime.GetSecondsUntilDailyReset()) / SECONDS_PER_DAY) - 1
end

local function WordAt(list, i)
    return list:sub((i - 1) * LETTERS + 1, i * LETTERS)
end

local function Answer(day)
    local list = ns.DailyWordAnswers
    return WordAt(list, (day - FIRST_DAY) % (#list / LETTERS) + 1)
end

local function Accepted(guess)
    local list = ns.DailyWordWords
    local low, high = 1, #list / LETTERS
    while low <= high do
        local mid = math.floor((low + high) / 2)
        local at = WordAt(list, mid)
        if at == guess then return true end
        if at < guess then low = mid + 1 else high = mid - 1 end
    end
    return false
end

local function Score(guess, answer, out)
    wipe(left)
    for i = 1, LETTERS do
        local a = answer:sub(i, i)
        if guess:sub(i, i) == a then
            out[i] = HIT
        else
            out[i] = MISS
            left[a] = (left[a] or 0) + 1
        end
    end
    for i = 1, LETTERS do
        local g = guess:sub(i, i)
        if out[i] ~= HIT and (left[g] or 0) > 0 then
            out[i] = NEAR
            left[g] = left[g] - 1
        end
    end
    return out
end

local function Saved()
    local account = ns.AccountSettings()
    account.dailyWord = account.dailyWord or { played = 0, won = 0, streak = 0, best = 0 }
    local d = account.dailyWord
    if d.day ~= today then d.day, d.guesses = today, {} end
    return d
end

local function Done(d)
    local n = #d.guesses
    return n > 0 and (d.guesses[n] == Answer(today) or n == TRIES)
end

local function Streak(d)
    return (d.lastWon and d.lastWon >= today - 1) and d.streak or 0
end

local function Finish(d, won)
    d.played = d.played + 1
    if won then
        d.won = d.won + 1
        d.streak = d.lastWon == today - 1 and d.streak + 1 or 1
        d.lastWon = today
        d.best = math.max(d.best, d.streak)
    else
        d.streak = 0
    end
end

local function PaintTile(tile, letter, state)
    tile.letter:SetText(letter and letter:upper() or "")
    local c = state and FILL[state]
    if c then
        tile.fill:SetColorTexture(c.r, c.g, c.b, 1)
        tile.edge:SetColor(c.r, c.g, c.b, 1)
    else
        tile.fill:SetColorTexture(T.panel.r, T.panel.g, T.panel.b, EMPTY_ALPHA)
        local e = letter and T.muted or T.line
        tile.edge:SetColor(e.r, e.g, e.b, 1)
    end
end

local function PaintRow(row, guess, answer)
    if guess and answer then Score(guess, answer, scored) end
    for i = 1, LETTERS do
        local letter = guess and guess:sub(i, i)
        PaintTile(word.tiles[row][i], letter ~= "" and letter or nil, answer and scored[i] or nil)
    end
end

local function PaintKeys(d, answer)
    for _, key in pairs(word.keys) do key.best = nil end
    for _, guess in ipairs(d.guesses) do
        Score(guess, answer, scored)
        for i = 1, LETTERS do
            local key = word.keys[guess:sub(i, i)]
            if not key.best or RANK[scored[i]] > RANK[key.best] then key.best = scored[i] end
        end
    end
    for _, key in pairs(word.keys) do
        local c = key.best and FILL[key.best]
        key.mark:SetShown(c ~= nil)
        if c then key.mark:SetColorTexture(c.r, c.g, c.b, 1) end
    end
end

local function UpdateStats(d)
    local rate = d.played > 0 and math.floor(d.won / d.played * PERCENT + ROUND) or 0
    word.stats:SetText(TEXT_STATS:format(d.played, rate, Streak(d), d.best))
end

local function Result(d)
    local n = #d.guesses
    if d.guesses[n] == Answer(today) then return TEXT_SOLVED:format(n, TRIES) end
    return TEXT_MISSED:format(Answer(today):upper())
end

local function Paint()
    local d = Saved()
    local answer = Answer(today)
    for row = 1, TRIES do
        local guess = d.guesses[row]
        if guess then
            PaintRow(row, guess, answer)
        elseif row == #d.guesses + 1 and not Done(d) then
            PaintRow(row, current, nil)
        else
            PaintRow(row, nil, nil)
        end
    end
    PaintKeys(d, answer)
    word.number:SetText(TEXT_NUMBER:format(today - FIRST_DAY + 1))
    local done = Done(d)
    word.message:SetText(done and Result(d) or "")
    word.share:SetShown(done)
    UpdateStats(d)
end

local function Say(text)
    word.message:SetText(text)
end

local function Submit()
    local d = Saved()
    if Done(d) then return end
    if #current < LETTERS then return Say(TEXT_SHORT) end
    if not Accepted(current) then return Say(TEXT_UNKNOWN) end
    d.guesses[#d.guesses + 1] = current
    current = ""
    word.input:SetText("")
    if Done(d) then
        Finish(d, d.guesses[#d.guesses] == Answer(today))
        word.input:ClearFocus()
    end
    Paint()
end

local function Type(letter)
    if Done(Saved()) then return end
    if letter == BACK then
        current = current:sub(1, -2)
    elseif #current < LETTERS then
        current = current .. letter
    end
    word.input:SetText(current)
    Paint()
end

local function OnTextChanged(self, byUser)
    if not byUser then return end
    local text = self:GetText():lower():gsub("[^a-z]", ""):sub(1, LETTERS)
    if text ~= self:GetText() then self:SetText(text) end
    if Done(Saved()) then return self:SetText("") end
    current = text
    Paint()
end

local function ShareLine()
    local d = Saved()
    local n = #d.guesses
    local won = d.guesses[n] == Answer(today)
    local line = TEXT_SHARE_LINE:format(today - FIRST_DAY + 1, won and tostring(n) or TEXT_LOST_SCORE, TRIES)
    for _, guess in ipairs(d.guesses) do
        Score(guess, Answer(today), scored)
        line = line .. " "
        for i = 1, LETTERS do line = line .. MARKS[scored[i]] end
    end
    return line
end

local function OnShare(btn)
    local line = ShareLine()
    Parts.ShareMenu(btn, TEXT_SHARE_TITLE, line, TEXT_TITLE, line)
end

local function UpdateClock()
    if Today() ~= word.day then
        today, current = Today(), ""
        word.day = today
        word.input:SetText("")
        Paint()
    end
    local wait = C_DateAndTime.GetSecondsUntilDailyReset()
    word.clock:SetText(TEXT_CLOCK:format(math.floor(wait / SECONDS_PER_HOUR),
        math.floor(wait % SECONDS_PER_HOUR / SECONDS_PER_MINUTE), wait % SECONDS_PER_MINUTE))
end

local function OnDragStop(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    S.Set("dailyWordPos", { point = point, relPoint = relPoint, x = x, y = y })
end

local function OnShow()
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", function() ns.DailyWordDismiss() end)
    end
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    ticker = C_Timer.NewTicker(CLOCK_EVERY, UpdateClock)
end

local function OnHide()
    if events then events:UnregisterAllEvents() end
    if ticker then ticker:Cancel(); ticker = nil end
    word.input:ClearFocus()
end

local function BuildFrame()
    word = CreateFrame("Frame", "NaowhForeverDailyWord", UIParent)
    word:SetSize(WORD_W, WORD_H)
    word:SetFrameStrata("HIGH")
    word:SetMovable(true)
    word:SetClampedToScreen(true)
    ns.AllowOffscreen(word)
    word:EnableMouse(true)
    word:RegisterForDrag("LeftButton")
    word:SetScript("OnDragStart", word.StartMoving)
    word:SetScript("OnDragStop", OnDragStop)
    word:SetScript("OnShow", OnShow)
    word:SetScript("OnHide", OnHide)
    ns.Solid(word, "BACKGROUND", T.bg, WORD_ALPHA):SetAllPoints()
    ns.Border(word)
end

local function BuildTitle()
    local logo = word:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(St.LOGO_SMALL, nil, nil, "TRILINEAR")
    logo:SetSize(LOGO_SIZE, LOGO_SIZE)
    logo:SetPoint("TOPLEFT", PAD, -LOGO_TOP)
    local title = ns.Font(word, TITLE_SIZE, "OUTLINE", T.accent)
    title:SetPoint("LEFT", logo, "RIGHT", TITLE_GAP, 0)
    title:SetText(TEXT_TITLE)
    word.number = ns.Font(word, NUMBER_SIZE, nil, T.muted)
    word.number:SetPoint("LEFT", title, "RIGHT", NUMBER_GAP, 0)
    local close = ns.Button(word, TEXT_CLOSE, CLOSE_SIZE, CLOSE_SIZE, function() word:Hide() end)
    close:SetPoint("TOPRIGHT", -CLOSE_INSET, -CLOSE_INSET)
    word.clock = ns.Font(word, CLOCK_SIZE, nil, T.muted)
    word.clock:SetPoint("TOP", 0, -CLOCK_TOP)
end

local function NewTile(x, y)
    local tile = CreateFrame("Frame", nil, word)
    tile:SetSize(TILE, TILE)
    tile:SetPoint("TOPLEFT", x, -y)
    tile.fill = ns.Solid(tile, "BACKGROUND", T.panel, EMPTY_ALPHA)
    tile.fill:SetAllPoints()
    tile.edge = ns.Border(tile)
    tile.letter = ns.Font(tile, TILE_TEXT, "OUTLINE")
    tile.letter:SetPoint("CENTER")
    return tile
end

local function BuildGrid()
    local left0 = (WORD_W - LETTERS * TILE - (LETTERS - 1) * TILE_GAP) / 2
    word.tiles = {}
    for row = 1, TRIES do
        word.tiles[row] = {}
        for i = 1, LETTERS do
            word.tiles[row][i] = NewTile(left0 + (i - 1) * (TILE + TILE_GAP), GRID_TOP + (row - 1) * (TILE + TILE_GAP))
        end
    end
    local input = CreateFrame("EditBox", nil, word)
    input:SetPoint("TOPLEFT", word.tiles[1][1], "TOPLEFT")
    input:SetPoint("BOTTOMRIGHT", word.tiles[TRIES][LETTERS], "BOTTOMRIGHT")
    input:SetFontObject("GameFontHighlight")
    input:SetAutoFocus(false)
    input:SetMaxLetters(LETTERS)
    input:SetAlpha(0)
    input:SetScript("OnTextChanged", OnTextChanged)
    input:SetScript("OnEnterPressed", Submit)
    input:SetScript("OnEscapePressed", input.ClearFocus)
    word.input = input
    word.message = ns.Font(word, MESSAGE_SIZE, "OUTLINE")
    word.message:SetPoint("TOP", 0, -MESSAGE_TOP)
end

local function NewKey(name, w, x, y)
    local text = name == ENTER and TEXT_ENTER or name == BACK and TEXT_BACK or name:upper()
    local key = ns.Button(word, text, w, KEY_H, function()
        if name == ENTER then Submit() else Type(name) end
    end)
    key:SetPoint("TOPLEFT", x, -y)
    key.mark = ns.Solid(key, "BORDER", T.panel, 1)
    key.mark:SetAllPoints()
    key.mark:Hide()
    return key
end

local function BuildKeys()
    word.keys = {}
    for r, letters in ipairs(KEY_ROWS) do
        local y = KEYS_TOP + (r - 1) * (KEY_H + KEY_GAP)
        local wide = r == #KEY_ROWS and 2 * (KEY_WIDE + KEY_GAP) or 0
        local w = #letters * KEY_W + (#letters - 1) * KEY_GAP + wide
        local x = (WORD_W - w) / 2
        if wide > 0 then
            NewKey(ENTER, KEY_WIDE, x, y)
            x = x + KEY_WIDE + KEY_GAP
        end
        for i = 1, #letters do
            local letter = letters:sub(i, i)
            word.keys[letter] = NewKey(letter, KEY_W, x, y)
            x = x + KEY_W + KEY_GAP
        end
        if wide > 0 then NewKey(BACK, KEY_WIDE, x, y) end
    end
end

local function BuildFoot()
    word.stats = ns.Font(word, STATS_SIZE, nil, T.muted)
    word.stats:SetPoint("BOTTOMLEFT", PAD, FOOT + (SHARE_H - STATS_SIZE) / 2)
    word.share = ns.Button(word, TEXT_SHARE, SHARE_W, SHARE_H)
    word.share._onClick = function() OnShare(word.share) end
    word.share:SetPoint("BOTTOMRIGHT", -PAD, FOOT)
    ns.AccentBorder(word.share)
end

local function Place()
    local pos = S.Get("dailyWordPos")
    word:ClearAllPoints()
    if pos then
        word:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        word:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_Y)
    end
end

local function Open(reason, focus)
    if not word then
        BuildFrame()
        BuildTitle()
        BuildGrid()
        BuildKeys()
        BuildFoot()
        word:Hide()
    end
    if not word:IsShown() then
        openedFor = reason
        today, current = Today(), ""
        word.day = today
        word.input:SetText("")
        Place()
        Paint()
        UpdateClock()
        word:Show()
    end
    if focus and not Done(Saved()) then word.input:SetFocus() end
end

function ns.DailyWordOn()
    return On()
end

function ns.DailyWordPlay(reason)
    if On() and not InCombatLockdown() then Open(reason, true) end
end

function ns.DailyWordOffer(reason)
    if not On() or InCombatLockdown() then return end
    today = Today()
    if not Done(Saved()) then Open(reason, false) end
end

function ns.DailyWordDismiss(reason)
    if not (word and word:IsShown()) then return end
    if reason and openedFor ~= reason then return end
    word:Hide()
end

function ns.ToggleDailyWord()
    if word and word:IsShown() then word:Hide() else ns.DailyWordPlay(nil) end
end

hooksecurefunc(S, "Set", function(key)
    if (key == "enabled" or key == "dailyWord") and not On() then ns.DailyWordDismiss() end
end)

local function ResetPosition()
    S.Set("dailyWordPos", nil)
    if word then Place() end
end

local function Summary()
    today = Today()
    local d = Saved()
    if Done(d) then
        if d.guesses[#d.guesses] == Answer(today) then return TEXT_SUMMARY_SOLVED:format(#d.guesses, TRIES, Streak(d)) end
        return TEXT_SUMMARY_MISSED
    end
    if #d.guesses > 0 then return TEXT_SUMMARY_PLAYING:format(#d.guesses, TRIES) end
    return TEXT_WAITING
end

ns.Shared.Settings.Page("QoL/Travel", S):Card({
    id = "dailyWord", name = "Daily Word", order = 25, switch = "dailyWord",
    help = "Guess the day's five-letter word in six tries; everyone gets the same word.",
    summary = Summary,
    rows = {
        { label = "Play Now", buttonText = "Play", button = function() ns.DailyWordPlay(nil) end,
          help = "Opens today's Daily Word." },
        { label = "Daily Word Position", buttonText = "Reset", button = ResetPosition,
          help = "Puts the Daily Word back where it first opened." },
    },
})

ns.RegisterMinimapFeature({
    id = "DailyWord", name = "Daily Word", icon = "Interface\\Icons\\INV_Misc_Note_01",
    open = ns.ToggleDailyWord, tooltip = "Click to open or close the Daily Word.",
})

-- XPTicker.lua: the QoL XP per hour ticker and its settings card.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local Parts, St = ns.Shared.Parts, ns.Shared.Style
local CharacterData, Played = ns.Shared.CharacterData, ns.Shared.Played
local SPLITS_KEY, WANT_KEY, CHARACTER_PREFIX = "levelSplits", "xpTicker", "Player-"

local PAD, UNIT_GAP, LABEL_GAP, HEAD_GAP, COL_GAP = 8, 4, 4, 10, 16
local SECTION_GAP, ROW_GAP, CONTROL_GAP, CONTROLS_INSET = 6, 3, 2, 6
local ROW_SHARE, ROW_MIN, HISTORY_MAX = 0.5, 9, 10
local DESCENT_SHARE, PERCENT_ROUNDING = 0.2, 1e-9
local WIDTH_PER_SIZE, WIDTH_STEP = 6, 8
local LINE_H, TREND_SHARE, TREND_MIN, TREND_GAP = 2, 0.5, 8, 4
local TREND_WINDOW, TREND_MIN_SHARE, DING_SOON = 180, 0.05, 600
local PACE_SHARE, PACE_GAP, PACE_MAX, DROP_SHARE = 0.75, 2, 8, 0.1
local MINUTE, HOUR = ns.QoLConstants.SECONDS_PER_MINUTE, ns.QoLConstants.SECONDS_PER_HOUR
local DAY, HOUR_TENTH = ns.QoLConstants.SECONDS_PER_DAY, 360
local THOUSAND, MILLION = ns.QoLConstants.THOUSAND, ns.QoLConstants.MILLION
local SHARE_TO_PERCENT, ROUND, ROW_KEY = 100, 0.5, 16
local KEY_TIME, KEY_CURRENT, KEY_PLAYED = 2, 4, 8
local TICK_FAST, TICK_SLOW = 1, 5
local HISTORY_RANGE = { 1, HISTORY_MAX, 1 }
local DEFAULT_POS = { x = -811, y = 3 }
local FORMAT = { MILLIONS = "%.1fm", THOUSANDS = "%.1fk", HOURS = "%.1fh", MINUTES = "m",
    CLOCK_DAYS = "%dd %dh %dm", CLOCK_HOURS = "%d:%02d:%02d", CLOCK_MINUTES = "%d:%02d", REACHED = 1 }
local UNIT, PAUSED, EMPTY, NONE = ns.L("xp/hr"), ns.L("paused"), ns.L("no XP yet"), "--"
local DING, LEVEL, PERCENT, DOT, PARTIAL = ns.L("Ding"), ns.L("Level %d"), "%d%%", St.PLACE_DOT, "+"
local PLAYED = ns.L("Played")
local TIP_TITLE = ns.L("XP per Hour")
local PACE_TIP = { you = ns.L("You"), ahead = ns.L("%s ahead"), behind = ns.L("%s behind"), unknown = ns.L("Unknown"),
    head = ns.L("Your characters at level %d"), headPart = ns.L("Your characters at level %d (%s)"), atLevel = ns.L(" at level %d"),
    none = ns.L("None of your other characters has reached level %d yet.") }
local PAUSE_TIP, PAUSE_HINT = ns.L("Pause"), ns.L("Stops the clock and the XP count.")
local START_TIP, START_HINT = ns.L("Start"), ns.L("Carries on from where you paused.")
local RESET_TIP, RESET_HINT = ns.L("Reset"), ns.L("Starts the session again from zero.")

local ticker, clock, clockRate, unlocked
local sessionStart, sessionXP = 0, 0
local paused, pausedAt, pausedTotal = false, nil, 0
local lastXP, lastXPMax
local cur, anchor
local historyKeys = {}
local running = { level = 0, time = 0, partial = false }
local trendBase, trendAt, trendDir = 0, 0, 0
local LEGACY_BACKGROUND = { [true] = "card", [false] = "soft" }
local LEGACY_OUTLINE = { [true] = "OUTLINE", [false] = "" }

local function On()
    return S.Get("enabled") and S.Get("xpTicker")
end

local function Background()
    local mode = S.Get("xpTickerBackground")
    return LEGACY_BACKGROUND[mode] or mode
end

local function Outline()
    local outline = S.Get("xpTickerOutline")
    return LEGACY_OUTLINE[outline] or outline
end

local function MigrateLegacy()
    local db = S.DB()
    local mode = LEGACY_BACKGROUND[db.xpTickerBackground]
    if mode then db.xpTickerBackground = mode end
    local outline = LEGACY_OUTLINE[db.xpTickerOutline]
    if outline then db.xpTickerOutline = outline end
end

local function AtMaxLevel()
    return UnitLevel("player") >= GetMaxLevelForPlayerExpansion() or IsXPUserDisabled()
end

local function Hidden()
    if unlocked then return false end
    return AtMaxLevel() or (S.Get("xpTickerHideResting") and IsResting())
end

local function Short(n)
    if n >= MILLION then return FORMAT.MILLIONS:format(n / MILLION) end
    if n >= THOUSAND then return FORMAT.THOUSANDS:format(n / THOUSAND) end
    return tostring(math.floor(n))
end

local function Duration(seconds)
    if seconds >= HOUR then return FORMAT.HOURS:format(seconds / HOUR) end
    return math.max(math.floor(seconds / MINUTE), 1) .. FORMAT.MINUTES
end

local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds + ROUND))
    if seconds >= DAY then
        return FORMAT.CLOCK_DAYS:format(math.floor(seconds / DAY), math.floor(seconds / HOUR) % (DAY / HOUR),
            math.floor(seconds / MINUTE) % (HOUR / MINUTE))
    end
    if seconds >= HOUR then
        return FORMAT.CLOCK_HOURS:format(math.floor(seconds / HOUR), math.floor(seconds / MINUTE) % (HOUR / MINUTE),
            seconds % MINUTE)
    end
    return FORMAT.CLOCK_MINUTES:format(math.floor(seconds / MINUTE), seconds % MINUTE)
end

local function ClockKey(seconds)
    return seconds >= DAY and -math.floor(seconds / MINUTE) or seconds
end

local Look = {}
local Pace = { rows = {}, order = {}, tones = {}, dirty = true }
local percents = {}

local function Percent(share)
    local n = math.max(0, math.floor(share * SHARE_TO_PERCENT + PERCENT_ROUNDING))
    local text = percents[n]
    if not text then
        text = PERCENT:format(n)
        percents[n] = text
    end
    return text
end

local function NewText(f, color)
    local fs = ns.Font(f, ROW_MIN, nil, color)
    f.texts[#f.texts + 1] = fs
    return fs
end

local function NewRow(f, label, valueColor)
    local row = { label = NewText(f, T.muted), value = NewText(f, valueColor or T.fg), on = false }
    row.value:SetJustifyH("RIGHT")
    row.label:Hide()
    row.value:Hide()
    if label then row.label:SetText(label) end
    return row
end

function Pace.ClassColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c and class and C_ClassColor then c = C_ClassColor.GetClassColor(class) end
    return c or T.fg
end

function Pace.Faster(a, b)
    return a.delta < b.delta
end

function Pace.Row(n, name, class, theirs, delta, atLevel, you)
    local row = Pace.rows[n]
    if not row then
        row = {}
        Pace.rows[n] = row
    end
    row.name, row.class, row.theirs, row.delta = name or PACE_TIP.unknown, class, theirs, delta
    row.atLevel, row.you = atLevel and true or false, you and true or false
    Pace.order[n] = row
end

function Pace.Line(row, level)
    local time = Clock(row.theirs) .. (row.atLevel and PACE_TIP.atLevel:format(level) or "")
    local c, v = row.you and T.accent or Pace.ClassColor(row.class), T.fg
    if not row.you then
        local gap = math.abs(row.delta)
        local ahead = row.delta >= 0
        time = time .. DOT .. ns.Color(ahead and St.HAVE_RGB or St.RED_RGB,
            (ahead and PACE_TIP.ahead or PACE_TIP.behind):format(Duration(gap)))
    end
    GameTooltip:AddDoubleLine(row.name, time, c.r, c.g, c.b, v.r, v.g, v.b)
end

function Pace.Tip(f)
    local n, level, share, interpolated = f.fillPace()
    local m = T.muted
    if n == 0 then
        GameTooltip:AddLine(PACE_TIP.none:format(level), m.r, m.g, m.b, true)
        return
    end
    GameTooltip:AddLine(interpolated and PACE_TIP.headPart:format(level, Percent(share)) or PACE_TIP.head:format(level),
        m.r, m.g, m.b)
    local you = 1
    for i = 1, n do
        if Pace.order[i].you then you = i end
    end
    local first = math.max(1, math.min(you - math.floor(PACE_MAX / 2), n - PACE_MAX + 1))
    for i = first, math.min(n, first + PACE_MAX - 1) do Pace.Line(Pace.order[i], level) end
end

local function ShowTip(f)
    if not (f.fillPace and S.Get("xpTickerPace")) then return end
    if not Parts.Tip(f, "ANCHOR_TOP") then return end
    GameTooltip:SetText(TIP_TITLE, T.fg.r, T.fg.g, T.fg.b)
    Pace.Tip(f)
    GameTooltip:Show()
end

local function CardEnter(f)
    f.controls:Show()
    ShowTip(f)
end

local function CardLeave(f)
    if not f:IsMouseOver() then f.controls:Hide() end
    if GameTooltip:IsOwned(f) then GameTooltip:Hide() end
end

local function ButtonLeave(button)
    CardLeave(button.card)
end

local function Tone(fs, color)
    if fs.tone == color then return end
    fs.tone = color
    fs:SetTextColor(color.r, color.g, color.b)
end

local function NewButton(f, texture, tip, hint)
    local button = Parts.BarButton(f.controls, texture, tip, hint)
    button.card = f
    button:HookScript("OnLeave", ButtonLeave)
    return button
end

function Look.New(f)
    f.texts = {}
    f.backdrop = Parts.HudBackdrop(f)
    f.rate = NewText(f, T.fg)
    f.rate:SetPoint("TOPLEFT", PAD, -PAD)
    f.unit = NewText(f, T.muted)
    f.unit:SetText(UNIT)
    f.trend = f:CreateTexture(nil, "OVERLAY")
    f.trend:SetTexture(St.UP)
    f.trend:SetPoint("LEFT", f.unit, "RIGHT", TREND_GAP, 0)
    f.trend:Hide()
    f.trendDir = 0
    f.played = NewRow(f, PLAYED)
    f.paceIcon = f:CreateTexture(nil, "OVERLAY")
    f.paceIcon:SetTexture(St.UP)
    f.paceIcon:Hide()
    f.paceText = NewText(f, St.HAVE_RGB)
    f.paceText:Hide()
    f.paceDir = 0
    f.current = NewRow(f, nil, T.muted)
    f.history = {}
    for i = 1, HISTORY_MAX do
        local row = NewRow(f)
        row.played = NewText(f, T.muted)
        row.played:SetJustifyH("RIGHT")
        row.played:Hide()
        f.history[i] = row
    end
    f.ding = NewRow(f, DING)
    f.ding.value:SetJustifyH("LEFT")
    f.ding.value:SetPoint("LEFT", f.ding.label, "RIGHT", LABEL_GAP, 0)
    f.dot = NewText(f, T.muted)
    f.dot:SetText(DOT)
    f.dot:SetPoint("LEFT", f.ding.value, "RIGHT")
    f.dot:Hide()
    f.time = { value = NewText(f, T.fg), on = false }
    f.time.value:Hide()
    f.percent = NewText(f, T.muted)
    f.percent:SetJustifyH("RIGHT")

    f.controls = CreateFrame("Frame", nil, f)
    f.toggle = NewButton(f, St.PAUSE, PAUSE_TIP, PAUSE_HINT)
    f.toggle:SetPoint("LEFT")
    f.reset = NewButton(f, St.RESET, RESET_TIP, RESET_HINT)
    f.reset:SetPoint("LEFT", f.toggle, "RIGHT", CONTROL_GAP, 0)
    f.controls:SetSize(f.toggle:GetWidth() + CONTROL_GAP + f.reset:GetWidth(), f.toggle:GetHeight())
    f.controls:Hide()
    f.inner = ns.PixelInset(CreateFrame("Frame", nil, f), 1)
    f.line = Parts.ProgressLine(f.inner, LINE_H)
    f.line:SetPoint("BOTTOMLEFT")
    f.line:SetPoint("BOTTOMRIGHT")
    f.line:Paint(T.accent, T.accentSoft)
    f:EnableMouse(true)
    f:SetScript("OnEnter", CardEnter)
    f:SetScript("OnLeave", CardLeave)
end

local function RowFont(row, font, size, flags)
    if row.label then row.label:SetFont(font, size, flags) end
    row.value:SetFont(font, size, flags)
end

function Look.Fonts(f)
    local font, size = ns.UI.FontPath(S.Get("xpTickerFont")), S.Get("xpTickerFontSize")
    local mode = f.backdrop:SetMode(Background())
    local outline = Outline()
    local flags = Parts.HudFlags(outline)
    local small = math.max(ROW_MIN, math.floor(size * ROW_SHARE))
    f.rate:SetFont(font, size, flags)
    f.unit:SetFont(font, small, flags)
    f.unit:ClearAllPoints()
    f.unit:SetPoint("BOTTOMLEFT", f.rate, "BOTTOMRIGHT", UNIT_GAP, (size - small) * DESCENT_SHARE)
    f.trendSize = math.max(TREND_MIN, math.floor(size * TREND_SHARE))
    f.trend:SetSize(f.trendSize, f.trendSize)
    RowFont(f.played, font, small, flags)
    f.paceText:SetFont(font, small, flags)
    f.paceSize = math.max(TREND_MIN, math.floor(small * PACE_SHARE))
    f.paceIcon:SetSize(f.paceSize, f.paceSize)
    local drop = math.floor(small * DROP_SHARE + ROUND)
    f.paceIcon:ClearAllPoints()
    f.paceIcon:SetPoint("LEFT", f.played.label, "RIGHT", LABEL_GAP, -drop)
    f.paceText:ClearAllPoints()
    f.paceText:SetPoint("LEFT", f.paceIcon, "RIGHT", PACE_GAP, drop)
    RowFont(f.current, font, small, flags)
    for i = 1, HISTORY_MAX do
        RowFont(f.history[i], font, small, flags)
        f.history[i].played:SetFont(font, small, flags)
    end
    RowFont(f.ding, font, small, flags)
    RowFont(f.time, font, small, flags)
    f.dot:SetFont(font, small, flags)
    f.percent:SetFont(font, small, flags)
    local shadow = outline == "" and mode
    for i = 1, #f.texts do Parts.HudText(f.texts[i], shadow) end
    f.line.track:SetShown(mode == "card")
    f.controls:ClearAllPoints()
    f.controls:SetPoint("RIGHT", f, "TOPRIGHT", -CONTROLS_INSET, -(PAD + size / 2))
    f.minW = size * WIDTH_PER_SIZE
    f.arranged = nil
end

local function PlaceRow(f, row, y)
    row.y = y
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -y)
    row.value:ClearAllPoints()
    row.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -y)
    return y + row.label:GetStringHeight()
end

local function ShowRow(row, on)
    row.on = on
    if row.label then row.label:SetShown(on) end
    row.value:SetShown(on)
end

local function PlaceFooter(f, showDing, showTime, y)
    ShowRow(f.ding, showDing)
    ShowRow(f.time, showTime)
    f.dot:SetShown(showDing and showTime)
    f.ding.label:ClearAllPoints()
    f.ding.label:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -y)
    f.time.value:ClearAllPoints()
    if showDing then
        f.time.value:SetPoint("LEFT", f.dot, "RIGHT")
    else
        f.time.value:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -y)
    end
    f.percent:ClearAllPoints()
    f.percent:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -y)
    return y + f.percent:GetStringHeight()
end

local function Arrange(f, showDing, showTime, showCurrent, count, showPlayed)
    local key = (showDing and 1 or 0) + (showTime and KEY_TIME or 0) + (showCurrent and KEY_CURRENT or 0)
        + (showPlayed and KEY_PLAYED or 0)
        + count * ROW_KEY
    if f.arranged == key then return false end
    f.arranged, f.fitW = key, nil
    local rateH = f.rate:GetStringHeight()
    local y = math.ceil(PAD + math.max(rateH, (rateH + f.controls:GetHeight()) / 2))
    local gap = SECTION_GAP
    ShowRow(f.played, showPlayed)
    if showPlayed then y, gap = PlaceRow(f, f.played, y + gap), ROW_GAP end
    ShowRow(f.current, showCurrent)
    if showCurrent then y, gap = PlaceRow(f, f.current, y + gap), ROW_GAP end
    for i = 1, HISTORY_MAX do
        local row = f.history[i]
        ShowRow(row, i <= count)
        if i <= count then
            y, gap = PlaceRow(f, row, y + gap), ROW_GAP
        end
    end
    y = PlaceFooter(f, showDing, showTime, y + SECTION_GAP)
    f.height = math.ceil(y) + PAD
    return true
end

local function RowWidth(w, row, column)
    if not row.on then return w end
    return math.max(w, row.label:GetStringWidth() + COL_GAP + row.value:GetStringWidth() + (column or 0))
end

function Look.PlayedWidth(w, f)
    local row = f.played
    if not row.on then return w end
    local mark = f.paceDir ~= 0 and LABEL_GAP + f.paceSize + PACE_GAP + f.paceText:GetStringWidth() or 0
    return math.max(w, row.label:GetStringWidth() + mark + COL_GAP + row.value:GetStringWidth())
end

local function FooterWidth(f)
    local w = 0
    if f.ding.on then w = f.ding.label:GetStringWidth() + LABEL_GAP + f.ding.value:GetStringWidth() end
    if f.ding.on and f.time.on then w = w + f.dot:GetStringWidth() end
    if f.time.on then w = w + f.time.value:GetStringWidth() end
    return w + COL_GAP + f.percent:GetStringWidth()
end

function Look.Fit(f)
    if not f.height then return end
    local head = f.rate:GetStringWidth() + UNIT_GAP + f.unit:GetStringWidth()
        + (f.trendDir ~= 0 and TREND_GAP + f.trendSize or 0)
    local w = math.max(f.minW, head + HEAD_GAP + f.controls:GetWidth(), FooterWidth(f))
    w = Look.PlayedWidth(w, f)
    local column = f.colOffset
    w = RowWidth(w, f.current, column)
    for i = 1, HISTORY_MAX do w = RowWidth(w, f.history[i], column) end
    w = math.max(w, f.fitW or 0)
    f.fitW = w
    f:SetSize(math.ceil(w / WIDTH_STEP) * WIDTH_STEP + 2 * PAD, f.height)
end

local function SetValue(fs, text)
    if fs.drawn == text then return false end
    fs.drawn = text
    fs:SetText(text)
    return true
end

local function ShowPaused(f, isPaused)
    if f.paused == isPaused then return end
    f.paused = isPaused
    local toggle = f.toggle
    toggle.icon:SetTexture(isPaused and St.PLAY or St.PAUSE)
    toggle.tip = isPaused and START_TIP or PAUSE_TIP
    toggle.hint = isPaused and START_HINT or PAUSE_HINT
    f.line:Paint(isPaused and T.muted or T.accent, isPaused and T.muted or T.accentSoft)
end

function Look.Arrow(arrow, dir)
    arrow:SetShown(dir ~= 0)
    if dir > 0 then
        arrow:SetTexCoord(0, 1, 0, 1)
        arrow:SetVertexColor(St.HAVE_RGB.r, St.HAVE_RGB.g, St.HAVE_RGB.b)
    elseif dir < 0 then
        arrow:SetTexCoord(0, 1, 1, 0)
        arrow:SetVertexColor(St.RED_RGB.r, St.RED_RGB.g, St.RED_RGB.b)
    end
end

local function ShowTrend(f, dir)
    if f.trendDir == dir then return false end
    f.trendDir = dir
    Look.Arrow(f.trend, dir)
    return true
end

function Look.Pace(f, delta)
    local dir = delta and (delta >= 0 and 1 or -1) or 0
    local changed = false
    if f.paceDir ~= dir then
        f.paceDir = dir
        Look.Arrow(f.paceIcon, dir)
        f.paceText:SetShown(dir ~= 0)
        if dir ~= 0 then Tone(f.paceText, dir > 0 and St.HAVE_RGB or St.RED_RGB) end
        changed = true
    end
    if dir == 0 then return changed end
    local gap = math.abs(delta)
    local key = gap >= HOUR and -math.floor(gap / HOUR_TENTH + ROUND) or math.max(math.floor(gap / MINUTE), 1)
    if f.paceKey ~= key then
        f.paceKey = key
        f.paceText:SetText(Duration(gap))
        changed = true
    end
    return changed
end

function Look.Played(row, total)
    local sec = total and math.max(0, math.floor(total + ROUND)) or false
    local key = sec and ClockKey(sec)
    if row.sec == key then return false end
    row.sec = key
    row.value:SetText(sec and Clock(sec) or NONE)
    Tone(row.value, sec and T.fg or T.muted)
    return true
end

function Look.Columns(f, count, show, arranged)
    local w = 0
    if show then
        for i = 1, count do w = math.max(w, f.history[i].played:GetStringWidth()) end
    end
    local offset = (show and count > 0) and w + COL_GAP or 0
    if not arranged and f.colOffset == offset then return false end
    f.colOffset = offset
    local rows = f.history
    if f.current.on then
        f.current.value:ClearAllPoints()
        f.current.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD - offset, -f.current.y)
    end
    for i = 1, HISTORY_MAX do
        local row = rows[i]
        row.played:SetShown(show and i <= count)
        if i <= count then
            row.value:ClearAllPoints()
            row.value:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD - offset, -row.y)
            row.played:ClearAllPoints()
            row.played:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -row.y)
        end
    end
    return true
end

function Look.Progress(f, value, rested, level)
    f.line:SetProgress(value, rested)
    if SetValue(f.percent, Percent(value)) then Look.Fit(f) end
end

local function ShowCurrent(row, run)
    local changed = false
    if row.level ~= run.level then
        row.level = run.level
        row.label:SetText(LEVEL:format(run.level + FORMAT.REACHED))
        changed = true
    end
    local sec, partial = math.max(0, math.floor(run.time + ROUND)), run.partial == true
    if row.sec ~= sec or row.partial ~= partial then
        row.sec, row.partial = sec, partial
        row.value:SetText(partial and Clock(sec) .. PARTIAL or Clock(sec))
        changed = true
    end
    return changed
end

function Look.Paint(f, rate, ding, elapsed, isPaused, keys, levels, trend, xp, run, played, pace)
    isPaused = isPaused and true or false
    local empty = rate <= 0
    local changed = SetValue(f.rate, empty and NONE or Short(rate))
    if SetValue(f.unit, isPaused and PAUSED or empty and EMPTY or UNIT) then changed = true end
    ShowPaused(f, isPaused)
    local earning = not empty and not isPaused
    Tone(f.rate, earning and T.accent or T.muted)
    if ShowTrend(f, earning and trend or 0) then changed = true end
    local showDing = (S.Get("xpTickerLevel") and ding) and true or false
    local showTime = S.Get("xpTickerElapsed") and true or false
    if showDing then
        if SetValue(f.ding.value, Duration(ding)) then changed = true end
        Tone(f.ding.value, ding < DING_SOON and T.accentSoft or T.fg)
    end
    if showTime then
        local sec = math.max(0, math.floor(elapsed + ROUND))
        if f.time.sec ~= sec then
            f.time.sec = sec
            f.time.value:SetText(Clock(sec))
            changed = true
        end
    end
    local showPlayed = S.Get("xpTickerPlayed") and true or false
    if showPlayed and Look.Played(f.played, played) then changed = true end
    if Look.Pace(f, showPlayed and pace or nil) then changed = true end
    local showCurrent = (run and S.Get("xpTickerSplits") and run.level < GetMaxLevelForPlayerExpansion()) and true
        or false
    if showCurrent and ShowCurrent(f.current, run) then changed = true end
    local count = math.min(#keys, S.Get("xpTickerHistoryCount") or HISTORY_MAX, HISTORY_MAX)
    local showAt = S.Get("xpTickerSplitPlayed") and true or false
    local tones, reached, columns = f.tones, f.reached, false
    for i = 1, count do
        local row, level = f.history[i], keys[i]
        local total = levels[level].total
        if row.level ~= level then
            row.level = level
            row.label:SetText(LEVEL:format(level + FORMAT.REACHED))
            changed = true
        end
        if row.total ~= total then
            row.total = total
            row.value:SetText(Clock(total))
            changed = true
        end
        Tone(row.value, tones and tones[level] or T.fg)
        local at = showAt and reached and reached[level + 1]
        at = type(at) == "number" and math.floor(at + ROUND) or false
        if showAt and row.at ~= at then
            row.at = at
            row.played:SetText(at and Clock(at) or NONE)
            columns = true
        end
    end
    local arranged = Arrange(f, showDing, showTime, showCurrent, count, showPlayed)
    if (arranged or columns) and Look.Columns(f, count, showAt, arranged) then changed = true end
    if arranged then changed = true end
    if changed then Look.Fit(f) end
end

local function NameEntry()
    local name, realm = UnitName("player"), GetRealmName()
    if not (name and realm) then return end
    local all = ns.AccountSettings()[SPLITS_KEY]
    local old = type(all) == "table" and all[name .. "-" .. realm]
    return type(old) == "table" and old or nil
end

local function Inherit(mine, old, guid)
    local c = old.current
    if old.claimedBy or (type(c) == "table" and c.level ~= UnitLevel("player")) then return end
    old.claimedBy = guid
    if type(old.levels) == "table" then
        for level, record in pairs(old.levels) do
            if type(level) == "number" and type(record) == "table" then
                mine.levels[level] = { total = record.total }
            end
        end
    end
    if type(c) == "table" then mine.current = { level = c.level, base = c.base, partial = c.partial } end
    mine.migrated = true
end

local function Splits()
    local mine = CharacterData(SPLITS_KEY)
    if mine then
        if type(mine.levels) ~= "table" then mine.levels = {} end
        return mine
    end
    mine = CharacterData(SPLITS_KEY, true)
    if not mine then return end
    mine.levels = {}
    local old = NameEntry()
    if old then Inherit(mine, old, UnitGUID("player")) end
    return mine
end

local function LevelTime()
    return cur.base + (anchor and GetTime() - anchor or 0)
end

local function StartLevel(splits, fromStart, level)
    cur = { level = level or UnitLevel("player"), base = 0, partial = not fromStart }
    anchor = not paused and GetTime() or nil
    splits.current = cur
end

local function TrackSplits(newLevel)
    local splits = Splits()
    if not splits then return end
    if not cur then
        local saved = splits.current
        if saved and saved.level == UnitLevel("player") then
            cur, anchor = saved, not paused and GetTime() or nil
        else
            StartLevel(splits, UnitXP("player") == 0)
        end
    end
    local level = newLevel or UnitLevel("player")
    if level > cur.level then
        splits.levels[cur.level] = { total = not cur.partial and LevelTime() or nil }
        StartLevel(splits, true, level)
    elseif not anchor and not paused then
        anchor = GetTime()
    end
end

function Pace.Record(level, at)
    local splits = Splits()
    if not splits then return end
    if type(splits.reached) ~= "table" then splits.reached = {} end
    local name = UnitName("player")
    splits.name, splits.class = name and name:match("^[^-]+") or name, select(2, UnitClass("player"))
    splits.reached[1] = 0
    splits.reached[level] = at
end

function Pace.Share()
    local max = UnitXPMax("player")
    return max > 0 and UnitXP("player") / max or 0
end

function Pace.ReachedAt(record, level)
    local reached = type(record) == "table" and record.reached
    local at = type(reached) == "table" and reached[level]
    return type(at) == "number" and at or nil
end

function Pace.IsOther(key, other, guid)
    return key ~= guid and type(key) == "string" and key:find(CHARACTER_PREFIX, 1, true) == 1
        and type(other) == "table"
end

function Pace.Gap(other, level, share, total, mineAt)
    local at, nextAt = Pace.ReachedAt(other, level), Pace.ReachedAt(other, level + 1)
    if not at then return end
    if total and nextAt then
        local theirs = at + share * (nextAt - at)
        return theirs - total, theirs, false
    end
    if mineAt then return at - mineAt, at, true end
end

function Pace.Fastest(total)
    local all, guid = ns.AccountSettings()[SPLITS_KEY], UnitGUID("player")
    if type(all) ~= "table" or not guid then return end
    local level, share = UnitLevel("player"), Pace.Share()
    local mineAt, best = Pace.ReachedAt(all[guid], level), nil
    for key, other in pairs(all) do
        if Pace.IsOther(key, other, guid) then
            local delta = Pace.Gap(other, level, share, total, mineAt)
            if delta and (not best or delta < best) then best = delta end
        end
    end
    return best
end

function Pace.Live()
    wipe(Pace.order)
    local all, guid = ns.AccountSettings()[SPLITS_KEY], UnitGUID("player")
    local level, share, total = UnitLevel("player"), Pace.Share(), Played.Total()
    if type(all) ~= "table" or not guid then return 0, level, share, false end
    local mineAt, n, interpolated = Pace.ReachedAt(all[guid], level), 0, false
    for key, other in pairs(all) do
        if Pace.IsOther(key, other, guid) then
            local delta, theirs, atLevel = Pace.Gap(other, level, share, total, mineAt)
            if delta then
                n = n + 1
                Pace.Row(n, other.name, other.class, theirs, delta, atLevel)
                if not atLevel then interpolated = true end
            end
        end
    end
    if n == 0 then return 0, level, share, false end
    n = n + 1
    Pace.Row(n, PACE_TIP.you, nil, interpolated and total or mineAt, 0, not interpolated, true)
    table.sort(Pace.order, Pace.Faster)
    return n, level, share, interpolated
end

function Pace.LevelTime(record, level)
    local at, nextAt = Pace.ReachedAt(record, level), Pace.ReachedAt(record, level + 1)
    if at and nextAt then return nextAt - at end
    local levels = record.levels
    local split = type(levels) == "table" and type(levels[level]) == "table" and levels[level].total
    return type(split) == "number" and split or nil
end

function Pace.Tones(levels)
    local tones = Pace.tones
    wipe(tones)
    local all, guid = ns.AccountSettings()[SPLITS_KEY], UnitGUID("player")
    if not (levels and S.Get("xpTickerPace") and type(all) == "table" and guid) then return end
    for level, record in pairs(levels) do
        local mine = type(level) == "number" and type(record) == "table" and record.total
        if type(mine) == "number" then
            local best
            for key, other in pairs(all) do
                if Pace.IsOther(key, other, guid) then
                    local theirs = Pace.LevelTime(other, level)
                    if theirs and (not best or theirs < best) then best = theirs end
                end
            end
            if best then tones[level] = mine <= best and St.HAVE_RGB or St.RED_RGB end
        end
    end
end

local function Newest(a, b)
    return a > b
end

local function History()
    wipe(historyKeys)
    local splits = cur and S.Get("xpTickerSplits") and Splits()
    if not splits then return historyKeys end
    local levels = splits.levels
    if Pace.dirty then
        Pace.dirty = false
        Pace.Tones(levels)
    end
    for level, record in pairs(levels) do
        if type(level) == "number" and level < cur.level and record.total then
            historyKeys[#historyKeys + 1] = level
        end
    end
    table.sort(historyKeys, Newest)
    return historyKeys, levels, splits.reached
end

local function Update()
    if not ticker then return end
    if Hidden() then
        ticker:Hide()
        return
    end
    local now = GetTime()
    local elapsed = now - sessionStart - pausedTotal - (paused and now - pausedAt or 0)
    local rate = sessionXP / (math.max(elapsed, MINUTE) / HOUR)
    local ding
    if rate > 0 then
        ding = (UnitXPMax("player") - UnitXP("player")) / rate * HOUR
    end
    if not paused and now - trendAt >= TREND_WINDOW then
        local diff = rate - trendBase
        trendDir = (trendBase > 0 and math.abs(diff) > trendBase * TREND_MIN_SHARE) and (diff > 0 and 1 or -1) or 0
        trendBase, trendAt = rate, now
    end
    local keys, levels, reached = History()
    ticker.reached = reached
    local run
    if cur then
        running.level, running.time, running.partial = cur.level, LevelTime(), cur.partial == true
        run = running
    end
    local played = Played.Total()
    local pace = S.Get("xpTickerPace") and S.Get("xpTickerPlayed") and Pace.Fastest(played) or nil
    Look.Paint(ticker, rate, ding, elapsed, paused, keys, levels, trendDir, sessionXP, run, played, pace)
    ticker:Show()
end

local function Progress()
    if not ticker then return end
    local max = UnitXPMax("player")
    if max <= 0 then return end
    Look.Progress(ticker, UnitXP("player") / max, (GetXPExhaustion() or 0) / max, UnitLevel("player"))
end

function ns.ResetXPTicker()
    sessionStart, sessionXP, pausedTotal = GetTime(), 0, 0
    trendBase, trendAt, trendDir = 0, sessionStart, 0
    if paused then pausedAt = sessionStart end
    Update()
    ns.ResetXPBarSession()
end

function ns.PauseXPTicker()
    if paused then return end
    paused, pausedAt = true, GetTime()
    if cur and anchor then cur.base, anchor = LevelTime(), nil end
    Update()
end

function ns.StartXPTicker()
    if not paused then return end
    pausedTotal = pausedTotal + GetTime() - pausedAt
    paused, pausedAt = false, nil
    if cur then anchor = GetTime() end
    Update()
end

local function PlayedAnswered(total, levelTime)
    if not On() then return end
    Pace.Record(UnitLevel("player"), total - levelTime)
    Pace.dirty = true
    Update()
end

local function PlayedLeveledUp(level, total)
    if total and On() then
        Pace.Record(level, total)
        Pace.dirty = true
    end
end

local function WantPlayed()
    if On() and (S.Get("xpTickerPlayed") or S.Get("xpTickerPace")) and (unlocked or not AtMaxLevel()) then
        Played.Want(WANT_KEY)
    else
        Played.Drop(WANT_KEY)
    end
end

local function TogglePause()
    if paused then ns.StartXPTicker() else ns.PauseXPTicker() end
end

local function ResetClicked()
    ns.ResetXPTicker()
end

function ns.XPTickerCommand(arg)
    local run = ({ start = ns.StartXPTicker, pause = ns.PauseXPTicker, reset = ns.ResetXPTicker })[arg]
    if run then run() else ns.Print("/naowh xp start, pause or reset") end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGOUT" then
        if cur then cur.base = LevelTime() end
        return
    end
    if event == "PLAYER_XP_UPDATE" then
        local xp, max = UnitXP("player"), UnitXPMax("player")
        local gained = xp >= lastXP and xp - lastXP or (lastXPMax - lastXP) + xp
        lastXP, lastXPMax = xp, max
        if not paused then sessionXP = sessionXP + gained end
        Progress()
    end
    if event == "PLAYER_LEVEL_UP" then Pace.dirty = true end
    TrackSplits(event == "PLAYER_LEVEL_UP" and arg1 or nil)
    Update()
end)

local function Place()
    local pos = S.Get("xpTickerPos")
    ticker:ClearAllPoints()
    if pos then
        ticker:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        ticker:SetPoint("LEFT", UIParent, "CENTER", DEFAULT_POS.x, DEFAULT_POS.y)
    end
end

local function Apply()
    MigrateLegacy()
    if not On() then
        if cur and anchor then cur.base, anchor = LevelTime(), nil end
        events:UnregisterAllEvents()
        Played.Drop(WANT_KEY)
        if clock then clock:Cancel(); clock = nil end
        if ticker then ticker:Hide() end
        return
    end
    if not ticker then
        ticker = CreateFrame("Frame", "NaowhForeverXPTicker", UIParent)
        ticker:SetMovable(true)
        ticker:SetClampedToScreen(true)
        Look.New(ticker)
        ticker.fillPace, ticker.tones = Pace.Live, Pace.tones
        ticker.toggle:SetScript("OnClick", TogglePause)
        ticker.reset:SetScript("OnClick", ResetClicked)
        ticker.mover = ns.UI.AttachMover(ticker, "XP per Hour", function(pos) S.Set("xpTickerPos", pos) end,
            "QoL/XP", "QoL/XP:xpTicker")
        sessionStart, sessionXP = GetTime(), 0
        trendAt = sessionStart
    end
    Look.Fonts(ticker)
    Place()
    lastXP, lastXPMax = UnitXP("player"), UnitXPMax("player")
    events:RegisterEvent("PLAYER_XP_UPDATE")
    events:RegisterEvent("PLAYER_UPDATE_RESTING")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:RegisterEvent("PLAYER_LOGOUT")
    TrackSplits()
    Progress()
    WantPlayed()
    Pace.dirty = true
    local rate = (S.Get("xpTickerSplits") or S.Get("xpTickerPlayed")) and TICK_FAST or TICK_SLOW
    if AtMaxLevel() and not unlocked then rate = nil end
    if clock and clockRate ~= rate then clock:Cancel(); clock = nil end
    if rate and not clock then clock, clockRate = C_Timer.NewTicker(rate, Update), rate end
    ticker.mover:SetShown(unlocked == true)
    Update()
end

hooksecurefunc(S, "Set", function(key, value)
    if key == "enabled" or (key:find("^xpTicker") and key ~= "xpTickerPos") then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(Played, "Answered", PlayedAnswered)
hooksecurefunc(Played, "LeveledUp", PlayedLeveledUp)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = S.Get("enabled") == true
    Apply()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    if ticker then
        ticker.mover:Hide()
        Apply()
    end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Group = ns.Shared.Settings.Group
local STAGE_H, STAGE_MARGIN, TEXT_ROOM = 210, St.STAGE_MARGIN, 44
local NOTE_Y, NOTE_SIZE, NOTE_GAP = 8, St.STAGE_NOTE_SIZE, 4
local HOVER_ALPHA, HIT_PAD = 0.12, 1
local SIZE_RANGE = { 8, 32, 1 }
local SAMPLE_RATE, SAMPLE_DING, SAMPLE_TIME = 48200, 8 * 60, 72 * 60 + 40
local SAMPLE_PROGRESS, SAMPLE_RESTED, SAMPLE_RESTING_RESTED = 0.62, 0.15, 0.3
local SAMPLE_PAUSED_TIME, SAMPLE_RESTING_RATE, SAMPLE_RESTING_DING = 41 * 60 + 5, 31600, 35 * 60
local SAMPLE_LEVEL, SAMPLE_START_TIME = 23, 3 * MINUTE + 12
local SAMPLE_RUN = { level = SAMPLE_LEVEL, time = 14 * 60 + 2, partial = false }
local SAMPLE_START_RUN = { level = SAMPLE_LEVEL, time = 9 * 60 + 47, partial = true }
local SAMPLE_PLAYED = DAY + 4 * HOUR + 12 * MINUTE + 33
local SAMPLE_PACE = {
    { name = "Thornwick", class = "WARRIOR", delta = 12 * MINUTE + 20 },
    { name = "Maelis", class = "MAGE", delta = 27 * MINUTE + 5 },
    { name = "Brakka", class = "SHAMAN", delta = 74 * MINUTE + 40 },
}
local SAMPLE_KEYS = { 22, 21, 20, 19, 18 }
local SAMPLE_LEVELS = { [22] = { total = 3125 }, [21] = { total = 2864 }, [20] = { total = 2702 },
    [19] = { total = 2391 }, [18] = { total = 2248 } }
SAMPLE_PACE.tones = { [22] = St.HAVE_RGB, [21] = St.RED_RGB, [20] = St.HAVE_RGB, [19] = St.RED_RGB,
    [18] = St.HAVE_RGB }
SAMPLE_PACE.reached = { [SAMPLE_LEVEL] = SAMPLE_PLAYED - SAMPLE_RUN.time }
for i = 1, #SAMPLE_KEYS do
    local level = SAMPLE_KEYS[i]
    SAMPLE_PACE.reached[level] = SAMPLE_PACE.reached[level + 1] - SAMPLE_LEVELS[level].total
end
local NO_KEYS = {}
local HINT = ns.L("Wheel: text size. Click a line to hide it. Right-click for more.")
local OFF_HINT = ns.L("Turn on XP per Hour to edit it here.")
local HIDDEN_NOTE = ns.L("Hide While Resting is on: hidden in cities and inns.")
local SUMMARY = { base = ns.L("Rate and time to level"), some = ns.L("Rate, time to level and %s"),
    splits = ns.L("Rate, time to level%s, this level and the last %d"), played = ns.L("played time"),
    pace = ns.L("played time against your characters") }
local STATES = {
    { key = "levelling", label = "Leveling", tip = "Out in the world, earning experience." },
    { key = "starting", label = "Starting", tip = "A new session, before any experience." },
    { key = "paused", label = "Paused", tip = "Paused from its header: the clock and the count stop." },
    { key = "resting", label = "Resting", tip = "In a city or an inn." },
}
local BACKGROUNDS, OUTLINES = Parts.HUD_BACKGROUNDS, Parts.HUD_OUTLINES
local LINE_TOGGLES = {
    { "xpTickerPlayed", ns.L("Show Played Time") },
    { "xpTickerPace", ns.L("Compare Characters") },
    { "xpTickerLevel", ns.L("Show Ding Time") },
    { "xpTickerElapsed", ns.L("Show Time") },
    { "xpTickerSplits", ns.L("Level History") },
    { "xpTickerSplitPlayed", ns.L("Show Played at Ding") },
}

local function Toggled(key)
    return S.Get(key) == true
end

local function Toggle(key)
    S.Set(key, not S.Get(key))
end

local function AddToggles(root, list)
    for i = 1, #list do root:CreateCheckbox(list[i][2], Toggled, Toggle, list[i][1]) end
end

local function PickedBackground(mode)
    return Background() == mode
end

local function SetBackground(mode)
    S.Set("xpTickerBackground", mode)
end

local function PickedOutline(outline)
    return Outline() == outline
end

local function SetOutline(outline)
    S.Set("xpTickerOutline", outline)
end

local function CardMenu(_, root)
    root:CreateTitle(ns.L("XP per Hour"))
    AddToggles(root, LINE_TOGGLES)
    root:CreateDivider()
    root:CreateTitle(ns.L("Background"))
    local order = BACKGROUNDS[2]
    for i = 1, #order do root:CreateRadio(BACKGROUNDS[1][order[i]], PickedBackground, SetBackground, order[i]) end
    root:CreateTitle(ns.L("Outline"))
    order = OUTLINES[2]
    for i = 1, #order do root:CreateRadio(OUTLINES[1][order[i]], PickedOutline, SetOutline, order[i]) end
    root:CreateDivider()
    root:CreateButton(ns.L("Reset XP per Hour"), ResetClicked)
end

local function Wheel(f, delta)
    if not f.preview.editable then return end
    local size = S.Get("xpTickerFontSize")
    local v = math.max(SIZE_RANGE[1], math.min(SIZE_RANGE[2], size + delta * SIZE_RANGE[3]))
    if v ~= size then S.Set("xpTickerFontSize", v) end
end

local function CardUp(f, button)
    if f.preview.editable and button == "RightButton" then MenuUtil.CreateContextMenu(f, CardMenu) end
end

local function HitEnter(hit)
    CardEnter(hit.card)
    if hit.card.preview.editable then hit.wash:Show() end
end

local function HitLeave(hit)
    hit.wash:Hide()
    CardLeave(hit.card)
end

local function HitUp(hit, button)
    if not hit.card.preview.editable then return end
    if button == "RightButton" then
        CardUp(hit.card, button)
    elseif button == "LeftButton" and hit:IsMouseOver() then
        Toggle(hit.key)
    end
end

local function HitWheel(hit, delta)
    Wheel(hit.card, delta)
end

local function NewHit(preview, row, key)
    local f = preview.ticker
    local hit = CreateFrame("Frame", nil, f)
    hit:SetPoint("TOPLEFT", row.label or row.value, "TOPLEFT", -HIT_PAD, HIT_PAD)
    hit:SetPoint("BOTTOMRIGHT", row.played or row.value, "BOTTOMRIGHT", HIT_PAD, -HIT_PAD)
    hit.wash = ns.Solid(hit, "BACKGROUND", T.accent, HOVER_ALPHA)
    hit.wash:SetAllPoints()
    hit.wash:Hide()
    hit.card, hit.row, hit.key = f, row, key
    hit:EnableMouse(true)
    hit:EnableMouseWheel(true)
    hit:SetScript("OnEnter", HitEnter)
    hit:SetScript("OnLeave", HitLeave)
    hit:SetScript("OnMouseUp", HitUp)
    hit:SetScript("OnMouseWheel", HitWheel)
    hit:Hide()
    preview.hits[#preview.hits + 1] = hit
end

function Pace.Sample()
    wipe(Pace.order)
    for i = 1, #SAMPLE_PACE do
        local c = SAMPLE_PACE[i]
        Pace.Row(i, c.name, c.class, SAMPLE_PLAYED + c.delta, c.delta, false)
    end
    local n = #SAMPLE_PACE + 1
    Pace.Row(n, PACE_TIP.you, nil, SAMPLE_PLAYED, 0, false, true)
    table.sort(Pace.order, Pace.Faster)
    return n, SAMPLE_LEVEL, SAMPLE_PROGRESS, true
end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.area = CreateFrame("Frame", nil, preview)
    preview.area:SetPoint("TOPLEFT", STAGE_MARGIN, -STAGE_MARGIN)
    preview.area:SetPoint("BOTTOMRIGHT", -STAGE_MARGIN, TEXT_ROOM)
    local f = CreateFrame("Frame", nil, preview)
    preview.ticker, f.preview = f, preview
    Look.New(f)
    f.fillPace = Pace.Sample
    f.toggle:EnableMouse(false)
    f.reset:EnableMouse(false)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", Wheel)
    f:SetScript("OnMouseUp", CardUp)
    preview.hits = {}
    NewHit(preview, f.played, "xpTickerPlayed")
    NewHit(preview, f.ding, "xpTickerLevel")
    NewHit(preview, f.time, "xpTickerElapsed")
    NewHit(preview, f.current, "xpTickerSplits")
    for i = 1, HISTORY_MAX do NewHit(preview, f.history[i], "xpTickerSplits") end
    preview.hint = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.hint:SetPoint("BOTTOMLEFT", STAGE_MARGIN, NOTE_Y)
    preview.hint:SetPoint("BOTTOMRIGHT", -STAGE_MARGIN, NOTE_Y)
    preview.note = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.note:SetPoint("BOTTOM", preview.hint, "TOP", 0, NOTE_GAP)
    return preview
end

local function FitPreview(preview)
    local f, area = preview.ticker, preview.area
    local w, h = f:GetWidth(), f:GetHeight()
    local roomW, roomH = area:GetWidth(), area:GetHeight()
    local scale = 1
    if roomW > 0 and w > roomW then scale = roomW / w end
    if roomH > 0 and h > 0 and h * scale > roomH then scale = roomH / h end
    f:SetScale(scale)
    f:ClearAllPoints()
    f:SetPoint("CENTER", area, "CENTER", 0, 0)
end

local function PaintPreview(preview, state)
    local f = preview.ticker
    Look.Fonts(f)
    local keys = S.Get("xpTickerSplits") and SAMPLE_KEYS or NO_KEYS
    local pace = S.Get("xpTickerPace") and SAMPLE_PACE[1].delta or nil
    f.tones, f.reached = pace and SAMPLE_PACE.tones, SAMPLE_PACE.reached
    if state == "paused" then
        Look.Paint(f, SAMPLE_RATE, SAMPLE_DING, SAMPLE_PAUSED_TIME, true, keys, SAMPLE_LEVELS, 1,
            SAMPLE_RATE * SAMPLE_PAUSED_TIME / HOUR, SAMPLE_RUN, SAMPLE_PLAYED, pace)
        Look.Progress(f, SAMPLE_PROGRESS, SAMPLE_RESTED, SAMPLE_LEVEL)
    elseif state == "resting" then
        Look.Paint(f, SAMPLE_RESTING_RATE, SAMPLE_RESTING_DING, SAMPLE_TIME, false, keys, SAMPLE_LEVELS, -1,
            SAMPLE_RESTING_RATE * SAMPLE_TIME / HOUR, SAMPLE_RUN, SAMPLE_PLAYED, pace)
        Look.Progress(f, SAMPLE_PROGRESS, SAMPLE_RESTING_RESTED, SAMPLE_LEVEL)
    elseif state == "starting" then
        Look.Paint(f, 0, nil, SAMPLE_START_TIME, false, keys, SAMPLE_LEVELS, 0, 0, SAMPLE_START_RUN,
            SAMPLE_PLAYED, pace)
        Look.Progress(f, SAMPLE_PROGRESS, SAMPLE_RESTED, SAMPLE_LEVEL)
    else
        Look.Paint(f, SAMPLE_RATE, SAMPLE_DING, SAMPLE_TIME, false, keys, SAMPLE_LEVELS, 1,
            SAMPLE_RATE * SAMPLE_TIME / HOUR, SAMPLE_RUN, SAMPLE_PLAYED, pace)
        Look.Progress(f, SAMPLE_PROGRESS, SAMPLE_RESTED, SAMPLE_LEVEL)
    end
    FitPreview(preview)
    local hidden = state == "resting" and S.Get("xpTickerHideResting") and true or false
    f:SetShown(not hidden)
    preview.note:SetText(hidden and HIDDEN_NOTE or "")
    local editable = (On() and not hidden) and true or false
    preview.editable = editable
    preview.hint:SetText(editable and HINT or hidden and "" or OFF_HINT)
    local hits = preview.hits
    for i = 1, #hits do
        local hit = hits[i]
        hit:SetShown(editable and hit.row.on)
        if not editable then hit.wash:Hide() end
    end
end

local function Summary(store)
    local played = store.Get("xpTickerPlayed") and (store.Get("xpTickerPace") and SUMMARY.pace or SUMMARY.played)
    if store.Get("xpTickerSplits") then
        return SUMMARY.splits:format(played and ", " .. played or "", store.Get("xpTickerHistoryCount"))
    end
    return played and SUMMARY.some:format(played) or SUMMARY.base
end

ns.Shared.Settings.Page("QoL/XP", S):Card({
    id = "xpTicker", name = "XP per Hour", order = 20, switch = "xpTicker",
    help = "Your experience per hour on a small card, with time to level, played time, session length and "
        .. "recent level times. Hidden at max level. Hover it for Start, Pause and Reset (also /naowh xp start, pause "
        .. "or reset). Move it in the HUD Editor.",
    summary = Summary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        Group("Shown"),
        { key = "xpTickerPlayed", label = "Show Played Time", toggle = true,
          help = "Your total played time on this character, from level 1." },
        { key = "xpTickerPace", label = "Compare Characters", toggle = true,
          help = "Shows if you're ahead of or behind your other characters, and colors past levels by it." },
        { key = "xpTickerLevel", label = "Show Ding Time", toggle = true,
          help = "How long the next level takes at your current rate." },
        { key = "xpTickerElapsed", label = "Show Time", toggle = true, help = "How long this session has run." },
        { label = "Reset XP per Hour", buttonText = "Reset", button = ns.ResetXPTicker,
          help = "Starts the session again: its time, XP and rate. The XP Bar's XP/Hour starts again with it." },
        Group("Level History"),
        { key = "xpTickerSplits", label = "Level History", toggle = true,
          help = "The level you are on as it runs, then completed levels, newest first." },
        { key = "xpTickerHistoryCount", label = "Levels Shown", slider = HISTORY_RANGE, needs = "xpTickerSplits",
          help = "The most recent completed levels." },
        { key = "xpTickerSplitPlayed", label = "Show Played at Ding", toggle = true, needs = "xpTickerSplits",
          help = "Your played time when you reached each level, beside how long it took." },
        ns.Shared.Settings.Look("xpTicker", { text = true, size = SIZE_RANGE, background = "card" }),
        Group("Visibility"),
        { key = "xpTickerHideResting", label = "Hide While Resting", toggle = true, help = "Hidden in cities and inns." },
    },
})

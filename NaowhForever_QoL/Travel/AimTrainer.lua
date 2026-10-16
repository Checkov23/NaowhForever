-- AimTrainer.lua: the Aim Trainer, a click-the-targets minigame for flights (/nfaim).
local ns = _G.NaowhForever

local GetTime, GetCursorPosition = GetTime, GetCursorPosition
local random, floor, min, max = math.random, math.floor, math.min, math.max

local S = ns.QoLSettings
local T = ns.THEME
local UI = ns.UI
local Parts, St = ns.Shared.Parts, ns.Shared.Style
local BORDER_RGB = St.BORDER_RGB

local ROUND = St.ROUND
local MODE_ICON = ns.MEDIA .. "Navigation\\grid.tga"
local BOARD_ICON = ns.MEDIA .. "Navigation\\trophy.tga"
local PAGE = "QoL/Travel"
local FACE_PATH = "Interface\\Icons\\Achievement_Character_"

local ENEMY_FACES = {
    Alliance = { FACE_PATH .. "Orc_Male", FACE_PATH .. "Orc_Female", FACE_PATH .. "Undead_Male",
        FACE_PATH .. "Undead_Female", FACE_PATH .. "Tauren_Male", FACE_PATH .. "Tauren_Female",
        FACE_PATH .. "Troll_Male", FACE_PATH .. "Troll_Female" },
    Horde = { FACE_PATH .. "Human_Male", FACE_PATH .. "Human_Female", FACE_PATH .. "Dwarf_Male",
        FACE_PATH .. "Dwarf_Female", FACE_PATH .. "Nightelf_Male", FACE_PATH .. "Nightelf_Female",
        FACE_PATH .. "Gnome_Male", FACE_PATH .. "Gnome_Female" },
}

local MODE_GRID, MODE_HEXA, MODE_REFLEX = "gridshot", "hexakill", "reflex"
local MODE_NAMES = { gridshot = "Gridshot", hexakill = "Hexakill", reflex = "Reflex" }
local MODE_ORDER = { MODE_GRID, MODE_HEXA, MODE_REFLEX }
local MODES = { MODE_NAMES, MODE_ORDER }
local MODE_TARGETS = { gridshot = 3, hexakill = 6, reflex = 1 }
local MODE_NEXT = { gridshot = MODE_HEXA, hexakill = MODE_REFLEX, reflex = MODE_GRID }
local IDLE, RUNNING, RESULTS = 1, 2, 3

local MAX_TARGETS = 6
local BASE_POINTS = 100
local MISS_PENALTY = 50
local FAST_TIME = 1
local COMBO_STEP, COMBO_CAP = 0.05, 20
local MIN_SHOTS = 10
local MIN_SIZE = 4
local PLACE_TRIES = 8
local TARGET_GAP = 6
local REFLEX_FIRST = 0.6
local REFLEX_GAP_MIN, REFLEX_GAP_MAX = 0.25, 0.75
local ROUND_TIME, TARGET_SIZE, REFLEX_LIFETIME, AREA_W = 30, 44, 1.5, 480
local HUMAN_CLICKS_PER_SECOND = 20
local RESULTS_LOCK, LOCK_ALPHA = 1, 0.35

local PAD = 10
local HEADER_H, HUD_TOP, HUD_H = St.WINDOW_HEADER, 6, 40
local AREA_RATIO = 0.625
local PANEL_ALPHA, CARD_ALPHA = 0.96, 0.97
local LABEL_SIZE, VALUE_SIZE, LABEL_GAP = 10, 16, 2
local HINT_SIZE, SUB_SIZE, LINE_GAP, HINT_Y = 20, 12, 6, 16
local RIM = 2
local HIDE_GAP = 4
local FACE_LAYER = 2
local ICON_CROP = ns.QoLConstants.ICON_CROP
local RING_SCALE, RING_ALPHA = 1.35, 0.55
local PULSE_FROM, PULSE_TIME = 0.75, 0.9
local POP_SCALE, POP_TIME = 1.8, 0.18
local MISS_POPS, MISS_SIZE, MISS_RISE, MISS_TIME = 4, 14, 18, 0.6
local MISS_RGB = St.RED_RGB
local MISS_TEXT = "-" .. MISS_PENALTY
local TARGET_LEVEL, CARD_LEVEL = 3, 10
local CARD_W, CARD_PAD, CARD_TITLE_H, CARD_TITLE_SIZE = 240, 12, 24, 15
local ROW_H, ROW_SIZE, CARD_GAP = 16, 12, 8
local CARD_BTN_W, BTN_H = 104, 24
local DEFAULT_Y = -60
local HALF = 0.5
local PERCENT = ns.QoLConstants.PERCENT
local MS_PER_SECOND = 1000
local TENTHS = ns.QoLConstants.TENTHS
local TEXT = {
    NO_VALUE = "--",
    IN_COMBAT = ns.L("The Aim Trainer can't open in combat."),
    TITLE = "Aim Trainer",
    MODE = "Mode",
    TIP_MODE = ns.L("Switch between Gridshot, Hexakill and Reflex."),
    BOARD = "Leaderboard",
    TIP_BOARD = ns.L("The best scores of the players you have met, in this mode."),
    AGAIN = "Play Again",
    CLOSE = "Close",
    START = ns.L("Click to Start"),
    REFLEX = ns.L("Reflex: one target at a time, gone in %.2gs. %ds rounds."),
    HEXA = ns.L("Hexakill: six targets at once. %ds rounds."),
    GRID = ns.L("Gridshot: three targets at once. %ds rounds."),
    NO_BEST = ns.L("No best yet"),
    BEST = "Best ",
    BEST_ACCURACY = ns.L("Best %s, best accuracy %d%%"),
    NEW_BEST = ns.L("New Best!"),
    ROUND_OVER = ns.L("Round Over"),
    TIME = "%.1f",
    COUNT = "%d",
    PERCENT = "%d%%",
    MS = "%d ms",
    COMBO = "x%d",
    BEST_LINE = "%s, %d%%",
    OFF = ns.L("The Aim Trainer is off. Turn it on in /nf, QoL, Travel."),
    RESET = "Clear your Aim Trainer records?",
    CLEAR_BOARD = "Clear the Aim Trainer leaderboard? Your own records stay.",
    SUMMARY = "%s, %s",
    SUMMARY_BEST = "best ",
    SUMMARY_NO_BEST = ns.L("no best yet"),
    FLIGHT = "flight",
    NO_SOUND = "none",
}

local HUD_LABELS = { ns.L("Time"), ns.L("Score"), ns.L("Accuracy"), ns.L("Combo") }
local RESULT_LABELS = { ns.L("Hits"), ns.L("Misses"), ns.L("Accuracy"), ns.L("Reaction"), ns.L("Best Combo"), ns.L("Score"), ns.L("Best") }
local CARD_H = CARD_PAD + CARD_TITLE_H + ROW_H + #RESULT_LABELS * ROW_H + CARD_GAP + 2 * BTN_H + CARD_GAP + CARD_PAD

local GAME_SOUNDS = { ["game:click"] = SOUNDKIT.IG_MAINMENU_OPTION, ["game:ping"] = SOUNDKIT.MAP_PING }
local GAME_SOUND_NAMES = { ["game:click"] = ns.L("Click (game)"), ["game:ping"] = ns.L("Ping (game)") }

local panel, openedFor, faceIDs, lockTimer
local state = IDLE
local mode, pulse, soundKey, faces, faceCount = MODE_HEXA, false, nil, nil, 0
local areaW, areaH, endAt, lastTenth, nextSpawn, active = 0, 0, 0, nil, 0, 0
local hits, misses, combo, bestCombo, score, reactionSum = 0, 0, 0, 0, 0, 0

local function ModeOf(value)
    return MODE_TARGETS[value] and value or MODE_HEXA
end

local function On()
    return (S.Get("enabled") and S.Get("aimTrainer")) and true or false
end

local function Records(key)
    local account = ns.AccountSettings()
    if type(account[key]) ~= "table" then account[key] = {} end
    return account[key]
end

local function Faces(faction)
    if not faceIDs then
        faceIDs = {}
        for side, paths in pairs(ENEMY_FACES) do
            local ids = {}
            for i = 1, #paths do
                local id = GetFileIDFromPath and GetFileIDFromPath(paths[i])
                if id and id > 0 then ids[#ids + 1] = id end
            end
            faceIDs[side] = ids
        end
    end
    local ids = faction and faceIDs[faction]
    if ids and #ids > 0 then return ids end
end

local function Points(reaction, streak)
    local speed = max(0, 1 - reaction / FAST_TIME)
    return floor(BASE_POINTS * (1 + speed) * (1 + COMBO_STEP * min(streak - 1, COMBO_CAP)) + HALF)
end

local function Ceiling(m)
    local most = m == MODE_REFLEX and floor((ROUND_TIME - REFLEX_FIRST) / REFLEX_GAP_MIN) + 1
        or ROUND_TIME * HUMAN_CLICKS_PER_SECOND
    return most * Points(0, COMBO_CAP + 1)
end

ns.AimRules = { order = MODE_ORDER, names = MODE_NAMES, Ceiling = Ceiling }

local Look = {}

local function Disc(parent, layer, sub, color, alpha)
    local tex = Parts.Smooth(parent:CreateTexture(nil, layer, nil, sub), ROUND)
    tex:SetVertexColor(color.r, color.g, color.b, alpha or 1)
    return tex
end

local function PopDone(anim)
    anim.tex:Hide()
end

local function Fade(group, from, to, duration)
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(from)
    fade:SetToAlpha(to)
    fade:SetDuration(duration)
end

local function Grow(group, from, to, duration)
    local grow = group:CreateAnimation("Scale")
    grow:SetScaleFrom(from, from)
    grow:SetScaleTo(to, to)
    grow:SetDuration(duration)
end

function Look.LiveTarget(t, area)
    t.pulse = t.ring:CreateAnimationGroup()
    t.pulse:SetLooping("REPEAT")
    Grow(t.pulse, PULSE_FROM, 1, PULSE_TIME)
    Fade(t.pulse, RING_ALPHA, 0, PULSE_TIME)
    t.pop = Disc(area, "OVERLAY", 0, T.accentSoft)
    t.pop:Hide()
    t.popAnim = t.pop:CreateAnimationGroup()
    t.popAnim.tex = t.pop
    Grow(t.popAnim, 1, POP_SCALE, POP_TIME)
    Fade(t.popAnim, 1, 0, POP_TIME)
    t.popAnim:SetScript("OnFinished", PopDone)
end

function Look.Target(area, live)
    local t = CreateFrame("Button", nil, area)
    t:SetFrameLevel(area:GetFrameLevel() + TARGET_LEVEL)
    t.ring = Disc(t, "BACKGROUND", 0, T.accentSoft, RING_ALPHA)
    t.ring:SetPoint("CENTER")
    t.rim = Disc(t, "ARTWORK", 0, T.accentSoft)
    t.rim:SetAllPoints()
    t.body = Disc(t, "ARTWORK", 1, T.accent)
    t.body:SetPoint("TOPLEFT", RIM, -RIM)
    t.body:SetPoint("BOTTOMRIGHT", -RIM, RIM)
    t.face = Parts.Smooth(t:CreateTexture(nil, "ARTWORK", nil, FACE_LAYER))
    t.face:SetAllPoints(t.body)
    t.face:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    t.mask = t:CreateMaskTexture()
    t.mask:SetAllPoints(t.body)
    t.mask:SetTexture(ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    t.face:AddMaskTexture(t.mask)
    t.face:Hide()
    t:EnableMouse(live)
    t:Hide()
    if live then Look.LiveTarget(t, area) end
    return t
end

local function NewMissPop(area)
    local text = ns.Font(area, MISS_SIZE, "OUTLINE", MISS_RGB)
    text:SetText(MISS_TEXT)
    text:Hide()
    local anim = text:CreateAnimationGroup()
    anim.tex = text
    local rise = anim:CreateAnimation("Translation")
    rise:SetOffset(0, MISS_RISE)
    rise:SetDuration(MISS_TIME)
    Fade(anim, 1, 0, MISS_TIME)
    anim:SetScript("OnFinished", PopDone)
    text.anim = anim
    return text
end

function Look.Size(t, s)
    t.size = s
    t:SetSize(s, s)
    t.ring:SetSize(s * RING_SCALE, s * RING_SCALE)
end

function Look.Face(t, id)
    if id then
        t.face:SetTexture(id)
        t.face:Show()
    else
        t.face:Hide()
    end
end

function Look.Put(t, x, y)
    t.x, t.y = x, y
    t:ClearAllPoints()
    t:SetPoint("CENTER", t:GetParent(), "TOPLEFT", x, -y)
end

function Look.Miss(f, x, y)
    local i = f.missNext % MISS_POPS + 1
    f.missNext = i
    local text = f.missPops[i]
    text.anim:Stop()
    text:ClearAllPoints()
    text:SetPoint("CENTER", f.area, "TOPLEFT", x, -y)
    text:Show()
    text.anim:Play()
end

local function Quiet(button)
    button:EnableMouse(false)
    return button
end

function Look.CardRows(card)
    card.values = {}
    for i, name in ipairs(RESULT_LABELS) do
        local y = -(CARD_PAD + CARD_TITLE_H + i * ROW_H)
        local label = ns.Font(card, ROW_SIZE, nil, T.muted)
        label:SetPoint("TOPLEFT", CARD_PAD, y)
        label:SetText(name)
        local value = ns.Font(card, ROW_SIZE, nil)
        value:SetPoint("TOPRIGHT", -CARD_PAD, y)
        card.values[i] = value
    end
end

local function NewCard(f, area, live)
    local card = CreateFrame("Frame", nil, area)
    card:SetSize(CARD_W, CARD_H)
    card:SetPoint("CENTER")
    card:SetFrameLevel(area:GetFrameLevel() + CARD_LEVEL)
    card:EnableMouse(live)
    Parts.Backdrop(card):Paint(CARD_ALPHA)
    ns.Border(card, BORDER_RGB)
    card.title = ns.Font(card, CARD_TITLE_SIZE, nil, T.accent)
    card.title:SetPoint("TOP", 0, -CARD_PAD)
    card.rank = ns.Font(card, ROW_SIZE, nil, T.accentSoft)
    card.rank:SetPoint("TOP", 0, -(CARD_PAD + CARD_TITLE_H))
    Look.CardRows(card)
    card.again = ns.AccentBorder(ns.Button(card, TEXT.AGAIN, CARD_BTN_W, BTN_H))
    card.again:SetPoint("BOTTOMLEFT", CARD_PAD, CARD_PAD)
    card.close = ns.Button(card, TEXT.CLOSE, CARD_BTN_W, BTN_H)
    card.close:SetPoint("BOTTOMRIGHT", -CARD_PAD, CARD_PAD)
    card.board = ns.Button(card, TEXT.BOARD, CARD_W - 2 * CARD_PAD, BTN_H)
    card.board:SetPoint("BOTTOMLEFT", card.again, "TOPLEFT", 0, CARD_GAP)
    card.buttons = { card.again, card.close, card.board }
    if not live then
        Quiet(card.again)
        Quiet(card.close)
        Quiet(card.board)
    end
    card:Hide()
    f.card = card
end

function Look.Header(f, live)
    local rule = ns.Solid(f, "ARTWORK", BORDER_RGB, 1)
    rule:SetPoint("TOPLEFT", 0, -HEADER_H)
    rule:SetPoint("TOPRIGHT", 0, -HEADER_H)
    ns.Hairline(rule, "h")
    f.close = Parts.TitleBar(f, TEXT.TITLE, "", PAGE)
    f.modeButton = Parts.BarButton(f, MODE_ICON, TEXT.MODE, TEXT.TIP_MODE, nil, TEXT.MODE)
    f.modeButton:SetPoint("RIGHT", f.close, "LEFT", -St.BAR_GAP, 0)
    f.boardButton = Parts.BarButton(f, BOARD_ICON, TEXT.BOARD, TEXT.TIP_BOARD, nil, TEXT.BOARD)
    f.boardButton:SetPoint("RIGHT", f.modeButton, "LEFT", -St.BAR_GAP, 0)
    if live then
        local hideButton = ns.FlightGameHideButton
        if not hideButton then return end
        f.notOnFlights = hideButton(f, f.close:GetHeight())
        f.notOnFlights:SetPoint("RIGHT", f.close, "LEFT", -HIDE_GAP, 0)
        return
    end
    Quiet(f.logo)
    Quiet(f.close)
    Quiet(f.modeButton)
    Quiet(f.boardButton)
end

function Look.Hud(f)
    f.cells = {}
    for i, name in ipairs(HUD_LABELS) do
        local label = ns.Font(f, LABEL_SIZE, nil, T.muted)
        label:SetText(name)
        local value = ns.Font(f, VALUE_SIZE)
        value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -LABEL_GAP)
        f.cells[i] = { label = label, value = value }
    end
    f.time, f.score, f.accuracy, f.combo = f.cells[1].value, f.cells[2].value, f.cells[3].value, f.cells[4].value
end

function Look.New(f, live)
    f.backdrop = Parts.Backdrop(f)
    f.backdrop:Card(PAD, HEADER_H + HUD_H, PAD, PAD)
    f.backdrop:Paint(PANEL_ALPHA)
    ns.Border(f, BORDER_RGB)
    Look.Header(f, live)
    Look.Hud(f)
    local area = CreateFrame("Frame", nil, f)
    area:SetPoint("TOPLEFT", PAD, -(HEADER_H + HUD_H))
    area:SetClipsChildren(true)
    area:EnableMouse(live)
    area.hint = ns.Font(area, HINT_SIZE)
    area.hint:SetPoint("CENTER", 0, HINT_Y)
    area.sub = ns.Font(area, SUB_SIZE, nil, T.muted)
    area.sub:SetPoint("TOP", area.hint, "BOTTOM", 0, -LINE_GAP)
    area.best = ns.Font(area, SUB_SIZE, nil, T.accentSoft)
    area.best:SetPoint("TOP", area.sub, "BOTTOM", 0, -LINE_GAP)
    f.area = area
    f.targets = {}
    for i = 1, MAX_TARGETS do f.targets[i] = Look.Target(area, live) end
    NewCard(f, area, live)
    if live then
        f.missPops, f.missNext = {}, 0
        for i = 1, MISS_POPS do f.missPops[i] = NewMissPop(area) end
        f.board = ns.AimBoard.NewView(area, CARD_LEVEL)
    end
end

function Look.Layout(f, width)
    local height = floor(width * AREA_RATIO + HALF)
    f:SetSize(width + 2 * PAD, HEADER_H + HUD_H + height + PAD)
    f.area:SetSize(width, height)
    local cellW = width / #f.cells
    for i, cell in ipairs(f.cells) do
        cell.label:ClearAllPoints()
        cell.label:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + (i - 1) * cellW, -(HEADER_H + HUD_TOP))
    end
    return width, height
end

function Look.Mode(f, m)
    f.subtitle:SetText(MODE_NAMES[m] or MODE_NAMES[MODE_HEXA])
end

function Look.Time(f, left)
    f.time:SetFormattedText(TEXT.TIME, max(0, left))
end

function Look.Stats(f, points, hit, missed, streak)
    f.score:SetFormattedText(TEXT.COUNT, points)
    local shots = hit + missed
    if shots > 0 then
        f.accuracy:SetFormattedText(TEXT.PERCENT, floor(hit * PERCENT / shots + HALF))
    else
        f.accuracy:SetText(TEXT.NO_VALUE)
    end
    f.combo:SetFormattedText(TEXT.COMBO, streak)
end

local function Best(m)
    local best = ns.AccountSettings().aimBest
    return type(best) == "table" and best[m] or nil
end

local function BestText(m)
    local best = Best(m)
    if not best then return TEXT.NO_BEST end
    local accuracy = ns.AccountSettings().aimBestAccuracy
    accuracy = type(accuracy) == "table" and accuracy[m]
    if accuracy then return TEXT.BEST_ACCURACY:format(BreakUpLargeNumbers(best), accuracy) end
    return TEXT.BEST .. BreakUpLargeNumbers(best)
end

function Look.ModeLine(m)
    if m == MODE_REFLEX then return TEXT.REFLEX:format(REFLEX_LIFETIME, ROUND_TIME) end
    if m == MODE_HEXA then return TEXT.HEXA:format(ROUND_TIME) end
    return TEXT.GRID:format(ROUND_TIME)
end

function Look.Idle(f, m)
    local area = f.area
    area.hint:SetText(TEXT.START)
    area.sub:SetText(Look.ModeLine(m))
    area.best:SetText(BestText(m))
    area.hint:Show()
    area.sub:Show()
    area.best:Show()
end

function Look.Busy(f)
    f.area.hint:Hide()
    f.area.sub:Hide()
    f.area.best:Hide()
end

function Look.Lock(f, locked)
    local card, alpha = f.card, locked and LOCK_ALPHA or 1
    for _, button in ipairs(card.buttons) do
        button:EnableMouse(not locked)
        button:SetAlpha(alpha)
    end
end

function Look.Results(f, record, hit, missed, accuracy, reaction, streak, points, best, bestAccuracy, rank)
    local card, v = f.card, f.card.values
    card.title:SetText(record and TEXT.NEW_BEST or TEXT.ROUND_OVER)
    card.rank:SetText(rank or "")
    v[1]:SetFormattedText(TEXT.COUNT, hit)
    v[2]:SetFormattedText(TEXT.COUNT, missed)
    if accuracy then v[3]:SetFormattedText(TEXT.PERCENT, accuracy) else v[3]:SetText(TEXT.NO_VALUE) end
    if reaction then v[4]:SetFormattedText(TEXT.MS, reaction) else v[4]:SetText(TEXT.NO_VALUE) end
    v[5]:SetFormattedText(TEXT.COMBO, streak)
    v[6]:SetText(BreakUpLargeNumbers(points))
    if bestAccuracy then
        v[7]:SetText(TEXT.BEST_LINE:format(BreakUpLargeNumbers(best or 0), bestAccuracy))
    else
        v[7]:SetText(BreakUpLargeNumbers(best or 0))
    end
    card:Show()
end

local function Stats()
    Look.Stats(panel, score, hits, misses, combo)
end

local function PlayHit()
    local kit = GAME_SOUNDS[soundKey]
    if kit then
        PlaySound(kit, "SFX")
    else
        UI.PlaySoundKey(soundKey)
    end
end

local function Clear(t, x, y, r)
    local targets = panel.targets
    for i = 1, active do
        local o = targets[i]
        if o ~= t and o.on then
            local dx, dy, reach = o.x - x, o.y - y, o.size / 2 + r + TARGET_GAP
            if dx * dx + dy * dy < reach * reach then return false end
        end
    end
    return true
end

local function Spawn(t, now)
    t.on, t.born = true, now
    Look.Size(t, TARGET_SIZE)
    Look.Face(t, faces and faces[random(faceCount)])
    local r = TARGET_SIZE / 2
    local x, y
    for _ = 1, PLACE_TRIES do
        x, y = r + random() * (areaW - TARGET_SIZE), r + random() * (areaH - TARGET_SIZE)
        if Clear(t, x, y, r) then break end
    end
    Look.Put(t, x, y)
    t:Show()
    if pulse then
        t.ring:Show()
        t.pulse:Play()
    else
        t.ring:Hide()
    end
end

local function Retire(t)
    t.on = false
    t.pulse:Stop()
    t:Hide()
end

local function Pop(t)
    local pop = t.pop
    pop:ClearAllPoints()
    pop:SetPoint("CENTER", panel.area, "TOPLEFT", t.x, -t.y)
    pop:SetSize(t.size, t.size)
    pop:Show()
    t.popAnim:Stop()
    t.popAnim:Play()
end

local function Gap()
    return REFLEX_GAP_MIN + random() * (REFLEX_GAP_MAX - REFLEX_GAP_MIN)
end

local function Miss(x, y)
    misses, combo = misses + 1, 0
    score = max(0, score - MISS_PENALTY)
    Look.Miss(panel, x, y)
    Stats()
end

local function CursorInArea()
    local area = panel.area
    local left, top = area:GetLeft(), area:GetTop()
    if not (left and top) then return areaW / 2, areaH / 2 end
    local x, y = GetCursorPosition()
    local scale = area:GetEffectiveScale()
    return x / scale - left, top - y / scale
end

local function Hit(t)
    local now = GetTime()
    local reaction = now - t.born
    hits, combo = hits + 1, combo + 1
    if combo > bestCombo then bestCombo = combo end
    reactionSum = reactionSum + reaction
    score = score + Points(reaction, combo)
    Pop(t)
    if soundKey then PlayHit() end
    if mode == MODE_REFLEX then
        Retire(t)
        nextSpawn = now + Gap()
    else
        Spawn(t, now)
    end
    Stats()
end

local function Inside(t)
    local x, y = GetCursorPosition()
    local scale = t:GetEffectiveScale()
    local cx, cy = t:GetCenter()
    if not cx then return false end
    local dx, dy, r = x / scale - cx, y / scale - cy, t:GetWidth() / 2
    return dx * dx + dy * dy <= r * r
end

local function StopTargets()
    local targets = panel.targets
    for i = 1, #targets do
        local t = targets[i]
        if t.on then Retire(t) end
    end
end

local function CancelLock()
    if lockTimer then
        lockTimer:Cancel()
        lockTimer = nil
    end
end

local function Unlock()
    lockTimer = nil
    Look.Lock(panel, false)
    panel.modeButton:Show()
    panel.boardButton:Show()
end

local function SaveRecords(accuracy, shots)
    local best, bestAccuracy = Records("aimBest"), Records("aimBestAccuracy")
    local record = score > 0 and score > (best[mode] or 0)
    if record then best[mode] = score end
    if accuracy and shots >= MIN_SHOTS and accuracy > (bestAccuracy[mode] or 0) then bestAccuracy[mode] = accuracy end
    if record then ns.AimBoard.Record(mode) end
    return record, best[mode], bestAccuracy[mode]
end

local function Finish()
    panel:SetScript("OnUpdate", nil)
    StopTargets()
    state = RESULTS
    local shots = hits + misses
    local accuracy = shots > 0 and floor(hits * PERCENT / shots + HALF) or nil
    local record, best, bestAccuracy = SaveRecords(accuracy, shots)
    Look.Time(panel, 0)
    Look.Lock(panel, true)
    CancelLock()
    lockTimer = C_Timer.NewTimer(RESULTS_LOCK, Unlock)
    Look.Results(panel, record, hits, misses, accuracy,
        hits > 0 and floor(reactionSum / hits * MS_PER_SECOND + HALF) or nil,
        bestCombo, score, best, bestAccuracy, ns.AimBoard.RankLine(mode, record))
end

local function TickReflex(t, now)
    if t.on then
        local shrink = 1 - (now - t.born) / REFLEX_LIFETIME
        if shrink <= 0 then
            Retire(t)
            nextSpawn = now + Gap()
            Miss(t.x, t.y)
        else
            Look.Size(t, max(MIN_SIZE, TARGET_SIZE * shrink))
        end
    elseif now >= nextSpawn then
        Spawn(t, now)
    end
end

local function Tick(self)
    local now = GetTime()
    local left = endAt - now
    if left <= 0 then
        Finish()
        return
    end
    local tenth = floor(left * TENTHS)
    if tenth ~= lastTenth then
        lastTenth = tenth
        Look.Time(self, left)
    end
    if mode == MODE_REFLEX then TickReflex(self.targets[1], now) end
end

local function Settle()
    areaW, areaH = Look.Layout(panel, AREA_W)
end

local function ReadOptions()
    mode = ModeOf(S.Get("aimMode"))
    pulse = S.Get("aimPulse") and true or false
    soundKey = S.Get("aimSound") and S.Get("aimSoundKey") or nil
    if soundKey == TEXT.NO_SOUND then soundKey = nil end
    faces = Faces(UnitFactionGroup("player"))
    faceCount = faces and #faces or 0
end

local function PaintHide(reason)
    local hide, offered = panel.notOnFlights, ns.FlightGameOffered
    if not (hide and offered) then return end
    local shown = offered(reason)
    hide:SetShown(shown)
    panel.modeButton:ClearAllPoints()
    panel.modeButton:SetPoint("RIGHT", shown and hide or panel.close, "LEFT", -St.BAR_GAP, 0)
end

local function Start()
    if state == RUNNING then return end
    CancelLock()
    ReadOptions()
    Settle()
    hits, misses, combo, bestCombo, score, reactionSum = 0, 0, 0, 0, 0, 0
    local now = GetTime()
    endAt, lastTenth = now + ROUND_TIME, nil
    state = RUNNING
    panel.card:Hide()
    panel.board:Hide()
    panel.modeButton:Hide()
    panel.boardButton:Hide()
    PaintHide(nil)
    Look.Busy(panel)
    Look.Time(panel, ROUND_TIME)
    Stats()
    local targets = panel.targets
    for i = 1, #targets do targets[i].on = false end
    if mode == MODE_REFLEX then
        active = 1
        nextSpawn = now + REFLEX_FIRST
    else
        active = MODE_TARGETS[mode]
        for i = 1, active do Spawn(targets[i], now) end
    end
    panel:SetScript("OnUpdate", Tick)
end

local function Idle()
    if panel:GetScript("OnUpdate") then panel:SetScript("OnUpdate", nil) end
    StopTargets()
    CancelLock()
    Look.Lock(panel, false)
    state = IDLE
    Settle()
    local m = ModeOf(S.Get("aimMode"))
    panel.card:Hide()
    panel.board:Hide()
    panel.modeButton:Show()
    panel.boardButton:Show()
    PaintHide(openedFor)
    Look.Mode(panel, m)
    Look.Time(panel, ROUND_TIME)
    Look.Stats(panel, 0, 0, 0, 0)
    Look.Idle(panel, m)
end

local function TargetDown(t, button)
    if button ~= "LeftButton" or state ~= RUNNING or not t.on then return end
    if Inside(t) then Hit(t) else Miss(CursorInArea()) end
end

local function AreaDown(_, button)
    if button ~= "LeftButton" then return end
    if state == RUNNING then
        Miss(CursorInArea())
    elseif state == IDLE then
        Start()
    end
end

local function SwitchMode()
    S.Set("aimMode", MODE_NEXT[ModeOf(S.Get("aimMode"))])
end

local function CloseBoard()
    panel.board:Hide()
    if state == RESULTS then panel.card:Show() else Idle() end
end

local function ToggleBoard()
    if state == RUNNING then return end
    if panel.board:IsShown() then return CloseBoard() end
    panel.card:Hide()
    Look.Busy(panel)
    ns.AimBoard.Show(panel.board, ModeOf(S.Get("aimMode")))
end

local function Close()
    panel:Hide()
end

local function DragStart()
    panel:StartMoving()
end

local function DragStop()
    panel:StopMovingOrSizing()
    S.Set("aimPos", UI.CenterPosition(panel))
end

local function Shown(self)
    if not InCombatLockdown() then
        self:EnableKeyboard(true)
        self:SetPropagateKeyboardInput(true)
    end
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
end

local function Hidden(self)
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    openedFor = nil
    Idle()
end

local function Build()
    panel = CreateFrame("Frame", nil, UIParent)
    panel:SetFrameStrata("HIGH")
    panel:SetToplevel(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    ns.AllowOffscreen(panel)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    Look.New(panel, true)
    panel:SetScript("OnDragStart", DragStart)
    panel:SetScript("OnDragStop", DragStop)
    panel.modeButton:SetScript("OnClick", SwitchMode)
    panel.boardButton:SetScript("OnClick", ToggleBoard)
    panel.card.again._onClick = Start
    panel.card.close._onClick = Close
    panel.card.board._onClick = ToggleBoard
    panel.board.back._onClick = CloseBoard
    panel.area:SetScript("OnMouseDown", AreaDown)
    for _, t in ipairs(panel.targets) do t:SetScript("OnMouseDown", TargetDown) end
    panel:SetScript("OnKeyDown", UI.CloseOnEscape)
    panel:SetScript("OnShow", Shown)
    panel:SetScript("OnHide", Hidden)
    panel:SetScript("OnEvent", Close)
    panel:Hide()
end

local function Place()
    local pos = S.Get("aimPos")
    panel:ClearAllPoints()
    if type(pos) == "table" and pos.point then
        panel:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_Y)
    end
end

local function Open(reason)
    if not On() then return end
    if InCombatLockdown() then
        ns.Print(TEXT.IN_COMBAT)
        return
    end
    if not panel then Build() end
    if panel:IsShown() then return end
    openedFor = reason
    Place()
    Idle()
    panel:Show()
end

function ns.AimTrainerOn()
    return On()
end

function ns.AimPlay(m, reason)
    if not On() then return end
    S.Set("aimMode", ModeOf(m))
    if panel and panel:IsShown() then
        if state ~= RUNNING then Idle() end
        return
    end
    Open(reason)
end

function ns.AimDismiss(reason)
    if not (panel and panel:IsShown()) then return end
    if reason and openedFor ~= reason then return end
    panel:Hide()
end

function ns.AimOffer(reason)
    if On() and not InCombatLockdown() then Open(reason) end
end

function ns.ToggleAimTrainer()
    if panel and panel:IsShown() then
        panel:Hide()
    else
        Open(UnitOnTaxi("player") and TEXT.FLIGHT or nil)
    end
end

local function Apply()
    if not panel then return end
    if not On() then
        panel:Hide()
    elseif panel:IsShown() then
        Place()
        if state ~= RUNNING then Idle() end
    end
end

local REDRAW = { aimMode = true, aimPulse = true }

local function OnSettingChanged(key)
    if key == "enabled" or key == "aimTrainer" then
        Apply()
    elseif REDRAW[key] and panel and panel:IsShown() then
        local board = key == "aimMode" and panel.board:IsShown()
        Idle()
        if board then ToggleBoard() end
    end
end

local function AimSlash()
    if not On() then
        ns.Print(TEXT.OFF)
        return
    end
    ns.ToggleAimTrainer()
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

SLASH_NAOWHFOREVERAIM1 = "/nfaim"
SlashCmdList.NAOWHFOREVERAIM = AimSlash

local Settings = ns.Shared.Settings
local Group = Settings.Group

local STAGE_H, STAGE_MARGIN = 280, 12
local SAMPLE_SPOTS = { { 0.22, 0.32 }, { 0.62, 0.62 }, { 0.8, 0.26 }, { 0.4, 0.78 }, { 0.12, 0.7 },
    { 0.5, 0.2 } }
local SAMPLE_REFLEX_SHRINK = 0.7
local SAMPLE_RANK = ns.L("Rank #3 of 42")
local SAMPLE = { left = 18.4, score = 2350, hits = 14, misses = 2, combo = 7, reaction = 412, bestCombo = 11 }
local STATES = {
    { key = "playing", label = "Playing", tip = "A round in progress." },
    { key = "results", label = "Results", tip = "The card at the end of a round." },
}

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.panel = CreateFrame("Frame", nil, preview)
    Look.New(preview.panel, false)
    return preview
end

function Look.PreviewTargets(f, m, shown, w, h)
    local ids = Faces(UnitFactionGroup("player"))
    local count = MODE_TARGETS[m]
    local s = TARGET_SIZE
    for i, t in ipairs(f.targets) do
        local on = shown ~= "results" and i <= count
        t:SetShown(on)
        if on then
            Look.Size(t, m == MODE_REFLEX and s * SAMPLE_REFLEX_SHRINK or s)
            Look.Face(t, ids and ids[(i - 1) % #ids + 1])
            t.ring:SetShown(S.Get("aimPulse") and true or false)
            Look.Put(t, SAMPLE_SPOTS[i][1] * w, SAMPLE_SPOTS[i][2] * h)
        end
    end
end

function Look.PreviewResults(f, m, shown)
    if shown ~= "results" then
        f.card:Hide()
        return
    end
    local hit, missed = SAMPLE.hits, SAMPLE.misses
    Look.Results(f, false, hit, missed, floor(hit * PERCENT / (hit + missed) + HALF), SAMPLE.reaction,
        SAMPLE.bestCombo, SAMPLE.score, Best(m) or SAMPLE.score, nil, SAMPLE_RANK)
end

local function PaintPreview(preview, shown)
    local f = preview.panel
    local w, h = Look.Layout(f, AREA_W)
    local m = ModeOf(S.Get("aimMode"))
    Look.Mode(f, m)
    Look.Busy(f)
    Look.Time(f, SAMPLE.left)
    Look.Stats(f, SAMPLE.score, SAMPLE.hits, SAMPLE.misses, SAMPLE.combo)
    Look.PreviewTargets(f, m, shown, w, h)
    Look.PreviewResults(f, m, shown)
    local scale = 1
    local fw, fh = f:GetWidth(), f:GetHeight()
    local roomW, roomH = preview:GetWidth() - STAGE_MARGIN * 2, preview:GetHeight() - STAGE_MARGIN * 2
    if roomW > 0 and fw > roomW then scale = roomW / fw end
    if roomH > 0 and fh * scale > roomH then scale = roomH / fh end
    f:SetScale(scale)
    f:ClearAllPoints()
    f:SetPoint("CENTER", preview, "CENTER", 0, 0)
end

local function Sounds()
    local _, names, order = ns.SoundChoices()
    local values, keys = { ["game:click"] = GAME_SOUND_NAMES["game:click"], ["game:ping"] = GAME_SOUND_NAMES["game:ping"] },
        { "game:click", "game:ping" }
    for _, key in ipairs(order) do
        values[key] = names[key]
        keys[#keys + 1] = key
    end
    return values, keys
end

local function SoundPicked(v)
    S.Set("aimSoundKey", v)
    local kit = GAME_SOUNDS[v]
    if kit then PlaySound(kit, "SFX") else UI.PlaySoundKey(v) end
end

local function PlayNow()
    if InCombatLockdown() then
        ns.Print(TEXT.IN_COMBAT)
        return
    end
    if ns.StashOptionsWindow then ns.StashOptionsWindow() end
    Open(UnitOnTaxi("player") and TEXT.FLIGHT or nil)
end

local function ForgetRecords()
    local account = ns.AccountSettings()
    account.aimBest, account.aimBestAccuracy = nil, nil
    ns.AimBoard.Sync()
    if panel and panel:IsShown() and state == IDLE then Idle() end
end

local function ResetRecords()
    ns.Confirm(TEXT.RESET, ForgetRecords)
end

local function ClearBoard()
    ns.Confirm(TEXT.CLEAR_BOARD, ns.AimBoard.Clear)
end

local function Summary(store)
    local m = ModeOf(store.Get("aimMode"))
    local best = Best(m)
    return TEXT.SUMMARY:format(MODE_NAMES[m], best and (TEXT.SUMMARY_BEST .. BreakUpLargeNumbers(best)) or TEXT.SUMMARY_NO_BEST)
end

Settings.Page("QoL/Travel", S):Card({
    id = "aimTrainer", name = "Aim Trainer", order = 30, switch = "aimTrainer",
    help = "A shooting game for flights: click the other faction's races as fast as you can.",
    summary = Summary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        Group("Game"),
        { key = "aimMode", label = "Mode", choice = MODES,
          help = "Gridshot keeps three targets up, Hexakill six, and Reflex one that shrinks away." },
        { label = "Play Now", buttonText = "Play", button = PlayNow,
          help = "Opens the Aim Trainer now, out of combat." },
        Group("Look and Sound"),
        { key = "aimPulse", label = "Pulsing Targets", toggle = true,
          help = "A soft ring pulses around each target." },
        { key = "aimSound", label = "Hit Sound", toggle = true },
        { key = "aimSoundKey", label = "Sound", choice = Sounds, needs = "aimSound",
          get = function() return S.Get("aimSoundKey") end, set = SoundPicked },
        Group("Scores"),
        { key = "aimShare", label = "Share My Scores", toggle = true,
          help = "Swaps your best scores with your group and guild for the leaderboard." },
        { label = "Clear Leaderboard", buttonText = "Clear", button = ClearBoard, always = true,
          help = "Forgets the scores other players shared, keeping your own." },
        { label = "Reset Records", buttonText = "Reset", button = ResetRecords, always = true,
          help = "Clears your own best scores on every character." },
    },
})

ns.RegisterMinimapFeature({
    id = "AimTrainer", name = "Aim Trainer", icon = "Interface\\Icons\\Ability_Marksmanship",
    open = ns.ToggleAimTrainer, tooltip = "Click to open or close the Aim Trainer.",
})

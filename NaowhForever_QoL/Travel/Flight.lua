-- Flight.lua: the Flight Timer, its card and track, Flight Games, and flight times on the flight map.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local Parts, St = ns.Shared.Parts, ns.Shared.Style

local WHITE = St.WHITE
local CIRCLE = St.ROUND
local MOUNT_ICONS = { Alliance = "Interface\\Icons\\Ability_Mount_Gryphon_01",
    Horde = "Interface\\Icons\\Ability_Mount_Wyvern_01" }
local ICON_CROP = ns.QoLConstants.ICON_CROP
local BORDER_RGB = St.BORDER_RGB

local WIDTH, PAD, ROW_GAP, CARD_ALPHA = 380, 10, 6, St.HUD_CARD_ALPHA
local HEAD_H, ROUTE_SIZE, TIME_SIZE, TIME_ROOM = 22, 14, 20, 70
local TRACK_H, ZONE_H, MOUNT, STOP, STOP_HOLE = 6, 22, 20, 10, 6
local HOLE_LAYER = 2
local LABEL_SIZE, LABEL_H, LABEL_GAP, LABEL_SPACE = 11, 12, 3, 8
local FOOT_SIZE, NEXT_ROOM, BTN_H, BTN_GAP = 12, 90, 22, 6
local ICON_SIZE, ICON_GAP, GAME_OFF_ALPHA = 16, 4, 0.35
local ICON_MEDIA = "Interface\\AddOns\\NaowhForever_QoL\\Media\\Flight\\"
local CHEVRON_SIZE, TEXT_GAP, TEXT_DROP = 10, 5, 1
local TRAIL_W, TRAIL_ALPHA, FILL_MIN = 48, 0.45, 0.01
local HALOS = { { size = 32, alpha = 0.14 }, { size = 26, alpha = 0.22 } }
local SHADOW_BELOW = 0.5
local SPAN = WIDTH - TRACK_H
local ZONE_TOP = PAD + HEAD_H + ROW_GAP
local LABEL_TOP = ZONE_TOP + ZONE_H + LABEL_GAP
local ROUTE_CAP = (WIDTH - TIME_ROOM - CHEVRON_SIZE - 2 * TEXT_GAP) / 2
local FLIGHT_SPEED = 30.4
local ADVENTURE_LEGACY_TREE, FREQUENT_FLIER_NODE = 1188, 110300
local FREQUENT_FLIER_SPEED = 1.2
local ROUTE_KEY = 10000
local SECONDS_PER_MINUTE = ns.QoLConstants.SECONDS_PER_MINUTE
local ROUND = ns.QoLConstants.ROUND
local MIN_LEARNED = 10
local BOARD_WAIT = 10
local POLL_EVERY = 0.5
local DEFAULT_TOP = -140
local EDGE_OUT = ns.QoLConstants.EDGE_OUT
local MOUNT_ABOVE = 2
local LAND_USED_ALPHA = 0.4
local SAMPLE_KNOWN = 150
local PERCENT = ns.QoLConstants.PERCENT
local SCALE_RANGE, PERCENT_SCALE = { 50, 200, 5 }, St.PERCENT_SCALE
local KEY_JOIN = "|"
local TIP_GOLD = { r = 1, g = 0.82, b = 0 }
local WHITE_RGB = ns.QoLConstants.WHITE_RGB
local CLOCK = "%d:%02d"
local TEXT_FLIGHT_TIME = ns.L("Flight Time")
local TEXT_IN_FLIGHT = ns.L("In flight")
local TEXT_VIA, TEXT_NEXT = ns.L("Via"), ns.L("Next")
local LIST_JOIN = ", "
local TIP_LAND_TITLE, TIP_LAND = ns.L("Land Early"), ns.L("Come down at the next stop on the way.")
local AIM_OFF = ns.L("Turn on the Aim Trainer in QoL > Travel")
local WORD_OFF = ns.L("Turn on the Daily Word in QoL > Travel")
local GAME_BUTTONS = {
    { id = "quiz", title = ns.L("Quiz"), tip = ns.L("WoW questions until you land.") },
    { id = "gridshot", aim = true, title = ns.L("Aim Trainer: Gridshot"), tip = ns.L("Three targets at once.") },
    { id = "hexakill", aim = true, title = ns.L("Aim Trainer: Hexakill"), tip = ns.L("Six targets at once.") },
    { id = "reflex", aim = true, title = ns.L("Aim Trainer: Reflex"), tip = ns.L("One target at a time that shrinks away.") },
    { id = "word", word = true, title = ns.L("Daily Word"), tip = ns.L("Guess the day's five-letter word.") },
}
local NEXT_CAP = WIDTH - (#GAME_BUTTONS + 1) * BTN_H - (#GAME_BUTTONS - 1) * ICON_GAP - BTN_GAP - NEXT_ROOM
local MOVER_LABEL = "Flight Timer"
local SETTINGS_PAGE, SETTINGS_CARD = "QoL/Travel", "QoL/Travel:flightTimer"
local SUMMARY = ns.L("Scale %d%%%s%s")
local SUMMARY_BACKGROUND = ns.L(", %d%% background")
local SUMMARY_LAND = ns.L(", Land Early button")
local GAMES_OFF = ns.L("Off: no game buttons")
local GAMES_BUTTON = ns.L("Game buttons, nothing opens by itself")
local GAMES_AIM_OFF = ns.L("Aim Trainer, but it is off: nothing opens")
local GAMES_WORD_OFF = ns.L("Daily Word, but it is off: nothing opens")
local GAMES_WHEN = ns.L(" when a flight starts")
local TEXT_NOT_ON_FLIGHTS = ns.L("Don't Show on Flights")
local TIP_NOT_ON_FLIGHTS = ns.L("Stops the games opening by themselves; the Flight Timer's buttons still have them.")
local TEXT_STOPPED = ns.L("Flight Games won't open by themselves now; the Flight Timer's game buttons still have them.")
local OPENS_BY_ITSELF = { quiz = true, aim = true, word = true }
local HIDE_KIND = "notOnFlights"

local bar, poll, unlocked, Apply, FadeBlizzardStop, StyleText
local stopFaded = false
local mapHooked = false
local settingsHooked, settingsOpen = false, false
local pending
local flight

local function On()
    return S.Get("enabled") and S.Get("flightTimer")
end

local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds + ROUND))
    return CLOCK:format(math.floor(seconds / SECONDS_PER_MINUTE), seconds % SECONDS_PER_MINUTE)
end

local function Times()
    local account = ns.AccountSettings()
    account.flightTimes = account.flightTimes or {}
    return account.flightTimes
end

local function RouteKey(from, to)
    if from and to then return from .. KEY_JOIN .. to end
end

local function CurrentNodeName()
    for i = 1, NumTaxiNodes() do
        if TaxiNodeGetType(i) == "CURRENT" then return TaxiNodeName(i) end
    end
end

local function SpeedMultiplier()
    local config = C_Traits.GetConfigIDByTreeID(ADVENTURE_LEGACY_TREE)
    local node = config and C_Traits.GetNodeInfo(config, FREQUENT_FLIER_NODE)
    return node and node.activeRank > 0 and FREQUENT_FLIER_SPEED or 1
end

local function Route(slot)
    local nodeAt = {}
    for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(GetTaxiMapID())) do
        nodeAt[node.slotIndex] = node.nodeID
    end
    local speed = FLIGHT_SPEED * SpeedMultiplier()
    local stops = { { name = TaxiNodeName(TaxiGetNodeSlot(slot, 1, true)), at = 0 } }
    local seconds = 0
    for hop = 1, GetNumRoutes(slot) do
        local stopSlot = TaxiGetNodeSlot(slot, hop, false)
        local leg = nodeAt[TaxiGetNodeSlot(slot, hop, true)]
        leg = leg and nodeAt[stopSlot] and ns.FLIGHT_ROUTES[leg * ROUTE_KEY + nodeAt[stopSlot]]
        seconds = seconds and leg and seconds + leg / speed or nil
        stops[hop + 1] = { name = TaxiNodeName(stopSlot), at = seconds }
    end
    local total = stops[#stops].at
    return stops, total and total > 0 and total or nil
end

local function AddMapTime(slot)
    if not (On() and S.Get("flightTimerMapTime")) or TaxiNodeGetType(slot) ~= "REACHABLE" then return end
    local _, estimate = Route(slot)
    local seconds = estimate or Times()[RouteKey(CurrentNodeName(), TaxiNodeName(slot))]
    if not seconds then return end
    GameTooltip:AddDoubleLine(TEXT_FLIGHT_TIME, Clock(seconds), TIP_GOLD.r, TIP_GOLD.g, TIP_GOLD.b,
        WHITE_RGB.r, WHITE_RGB.g, WHITE_RGB.b)
    GameTooltip:Show()
end

local function OnTaxiButtonEnter(button)
    AddMapTime(button:GetID())
end

local function OnFlightPinEnter(pin)
    AddMapTime(pin.taxiNodeData.slotIndex)
end

local function HookFlightMap()
    hooksecurefunc(FlightMap_FlightPointPinMixin, "OnMouseEnter", OnFlightPinEnter)
end

local function HookMap()
    if mapHooked or not (On() and S.Get("flightTimerMapTime")) then return end
    mapHooked = true
    if TaxiNodeOnButtonEnter then
        hooksecurefunc("TaxiNodeOnButtonEnter", OnTaxiButtonEnter)
    end
    if EventUtil and EventUtil.ContinueOnAddOnLoaded then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_FlightMap", HookFlightMap)
    end
end

local Look = {}

local function Short(name)
    return name and name:match("^[^,]+") or name
end

local function Disc(parent, layer, sublevel, size, c, alpha)
    local t = parent:CreateTexture(nil, layer, nil, sublevel)
    t:SetTexture(CIRCLE, nil, nil, "TRILINEAR")
    t:SetSize(size, size)
    t:SetVertexColor(c.r, c.g, c.b, alpha or 1)
    return t
end

local function HalfDisc(parent, layer, side, c)
    local t = parent:CreateTexture(nil, layer)
    t:SetTexture(CIRCLE, nil, nil, "TRILINEAR")
    t:SetSize(TRACK_H / 2, TRACK_H)
    t:SetPoint(side)
    if side == "LEFT" then t:SetTexCoord(0, 0.5, 0, 1) else t:SetTexCoord(0.5, 1, 0, 1) end
    t:SetVertexColor(c.r, c.g, c.b, 1)
    return t
end

local function Fit(fs, cap)
    fs:SetWidth(0)
    if fs:GetStringWidth() > cap then fs:SetWidth(cap) end
end

local function NewStop(f)
    local m = {}
    m.ring = Disc(f.marks, "ARTWORK", 1, STOP, T.fg)
    m.edge = Disc(f.marks, "ARTWORK", 0, STOP, BORDER_RGB)
    ns.PixelInset(m.edge, EDGE_OUT, m.ring)
    m.hole = Disc(f.marks, "ARTWORK", HOLE_LAYER, STOP_HOLE, T.bg)
    m.hole:SetPoint("CENTER", m.ring)
    m.label = ns.Font(f, LABEL_SIZE)
    m.label:SetWordWrap(false)
    f.texts[#f.texts + 1] = { m.label, LABEL_SIZE }
    if f.font then StyleText(f, m.label, LABEL_SIZE) end
    return m
end

local function PaintStop(m, passed)
    local c = passed and T.accent or T.fg
    m.ring:SetVertexColor(c.r, c.g, c.b, 1)
    m.hole:SetShown(not passed)
    local t = passed and T.muted or T.fg
    m.label:SetTextColor(t.r, t.g, t.b, 1)
end

local function RoundMask(owner, texture)
    local mask = owner:CreateMaskTexture()
    mask:SetAllPoints(texture)
    mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    texture:AddMaskTexture(mask)
end

local function MountIcon(icon)
    local id = GetFileIDFromPath and GetFileIDFromPath(MOUNT_ICONS[UnitFactionGroup("player")] or MOUNT_ICONS.Alliance)
    if id and id > 0 then
        icon:SetTexture(id)
        icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    else
        icon:SetColorTexture(T.accent.r, T.accent.g, T.accent.b, 1)
    end
end

local function NewMount(f)
    local mount = CreateFrame("Frame", nil, f)
    mount:SetSize(MOUNT, MOUNT)
    mount:SetPoint("CENTER", f.fill, "RIGHT")
    mount:SetFrameLevel(f.track:GetFrameLevel() + MOUNT_ABOVE)
    local icon = mount:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    MountIcon(icon)
    RoundMask(mount, icon)
    local ring = mount:CreateTexture(nil, "BACKGROUND")
    ns.PixelInset(ring, EDGE_OUT)
    ring:SetColorTexture(BORDER_RGB.r, BORDER_RGB.g, BORDER_RGB.b, 1)
    RoundMask(mount, ring)
    return mount
end

local function NewTrackBody(track)
    HalfDisc(track, "BACKGROUND", "LEFT", T.line)
    HalfDisc(track, "BACKGROUND", "RIGHT", T.line)
    local body = track:CreateTexture(nil, "BACKGROUND")
    body:SetColorTexture(T.line.r, T.line.g, T.line.b, 1)
    body:SetPoint("TOPLEFT", TRACK_H / 2, 0)
    body:SetPoint("BOTTOMRIGHT", -TRACK_H / 2, 0)
end

local function NewTrack(f)
    local track = CreateFrame("Frame", nil, f)
    track:SetPoint("TOPLEFT", PAD, -(ZONE_TOP + (ZONE_H - TRACK_H) / 2))
    track:SetSize(WIDTH, TRACK_H)
    f.track = track
    NewTrackBody(track)
    f.lit = { HalfDisc(track, "BORDER", "LEFT", T.accent) }
    f.fill = track:CreateTexture(nil, "BORDER")
    f.fill:SetPoint("LEFT", TRACK_H / 2, 0)
    f.fill:SetHeight(TRACK_H)
    f.lit[2] = f.fill
    f.trail = track:CreateTexture(nil, "ARTWORK")
    f.trail:SetTexture(WHITE)
    f.trail:SetBlendMode("ADD")
    f.trail:SetPoint("RIGHT", f.fill, "RIGHT")
    f.trail:SetHeight(TRACK_H)
    f.trail:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, TRAIL_ALPHA))
    f.lit[3] = f.trail
    for i, halo in ipairs(HALOS) do
        local t = Disc(track, "ARTWORK", i, halo.size, T.accentSoft, halo.alpha)
        t:SetBlendMode("ADD")
        t:SetPoint("CENTER", f.fill, "RIGHT")
        f.lit[#f.lit + 1] = t
    end
    f.marks = CreateFrame("Frame", nil, f)
    f.marks:SetAllPoints(track)
    f.marks:SetFrameLevel(track:GetFrameLevel() + 1)
    f.mount = NewMount(f)
    f.lit[#f.lit + 1] = f.mount
end

local function NewHead(f)
    f.time = ns.Font(f, TIME_SIZE, nil, T.accent)
    f.time:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -PAD, -PAD - HEAD_H)
    f.from = ns.Font(f, ROUTE_SIZE, nil, T.muted)
    f.from:SetPoint("BOTTOMLEFT", f, "TOPLEFT", PAD, -PAD - HEAD_H)
    f.from:SetWordWrap(false)
    f.arrow = Parts.Arrow(f, CHEVRON_SIZE, T.muted)
    f.arrow:SetPoint("LEFT", f.from, "RIGHT", TEXT_GAP, -TEXT_DROP)
    f.to = ns.Font(f, ROUTE_SIZE)
    f.to:SetWordWrap(false)
end

local function NewFoot(f)
    f.nextKey = ns.Font(f, FOOT_SIZE, nil, T.muted)
    f.nextName = ns.Font(f, FOOT_SIZE)
    f.nextName:SetWordWrap(false)
    f.nextName:SetPoint("LEFT", f.nextKey, "RIGHT", TEXT_GAP, 0)
    f.sep = ns.Font(f, FOOT_SIZE, nil, T.muted)
    f.sep:SetText(St.PLACE_DOT)
    f.sep:SetPoint("LEFT", f.nextName, "RIGHT", 0, 0)
    f.nextTime = ns.Font(f, FOOT_SIZE, nil, T.accentSoft)
    f.nextTime:SetPoint("LEFT", f.sep, "RIGHT", 0, 0)
end

local function IconButton(f, kind, texture, size)
    local b = ns.Button(f, "", size or BTN_H, size or BTN_H)
    b.kind = kind
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexture(texture or ICON_MEDIA .. kind, nil, nil, "TRILINEAR")
    b.icon:SetSize(ICON_SIZE, ICON_SIZE)
    b.icon:SetPoint("CENTER")
    b.icon:SetVertexColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    b:SetMotionScriptsWhileDisabled(true)
    return b
end

function Look.New(f)
    f:SetSize(WIDTH + 2 * PAD, 2 * PAD + HEAD_H)
    f.bg = ns.Solid(f, "BACKGROUND", T.bg, CARD_ALPHA)
    f.bg:SetAllPoints()
    f.border = ns.Border(f, BORDER_RGB)
    f.texts = {}
    NewHead(f)
    NewTrack(f)
    f.stops = {}
    f.via = {}
    NewFoot(f)
    for _, t in ipairs({ { f.time, TIME_SIZE }, { f.from, ROUTE_SIZE }, { f.to, ROUTE_SIZE }, { f.nextKey, FOOT_SIZE },
        { f.nextName, FOOT_SIZE }, { f.sep, FOOT_SIZE }, { f.nextTime, FOOT_SIZE } }) do
        f.texts[#f.texts + 1] = t
    end
    f.land = IconButton(f, "land")
    f.games = {}
    for i, game in ipairs(GAME_BUTTONS) do f.games[i] = IconButton(f, game.id) end
end

function StyleText(f, fs, size)
    fs:SetFont(f.font, size, Parts.HudFlags(f.outline))
    Parts.HudText(fs, f.shadow)
end

function Look.Style(f)
    local alpha = S.Get("flightTimerAlpha")
    f.bg:SetAlpha(alpha)
    f.border._frame:SetAlpha(alpha)
    for i = 0, #f.games do
        local b = i == 0 and f.land or f.games[i]
        b._bg:SetAlpha(alpha)
        b._border._frame:SetAlpha(alpha)
        if b._art then
            for _, piece in ipairs(b._art) do piece:SetAlpha(alpha) end
            b:GetHighlightTexture():SetAlpha(alpha)
        end
    end
    local bare = alpha < SHADOW_BELOW
    f.font, f.outline = ns.UI.FontPath(S.Get("flightTimerFont")), S.Get("flightTimerOutline")
    if f.outline == "" then
        f.shadow = bare and "none" or "card"
    else
        f.shadow = bare and f.outline == "NONE" and "none"
    end
    for _, t in ipairs(f.texts) do StyleText(f, t[1], t[2]) end
    local c = bare and T.fg or T.muted
    for _, fs in ipairs({ f.from, f.nextKey, f.sep }) do fs:SetTextColor(c.r, c.g, c.b, 1) end
    f.fill:SetTexture(ns.UI.TexturePath(S.Get("flightTimerTexture"), WHITE))
    f.fill:SetGradient("HORIZONTAL", CreateColor(T.accent.r, T.accent.g, T.accent.b, 1),
        CreateColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b, 1))
end

local function ShowNext(f, m)
    local on = m and true or false
    if m then
        f.nextName:SetText(m.name)
        Fit(f.nextName, NEXT_CAP)
    end
    f.nextKey:SetShown(on)
    f.nextName:SetShown(on)
    f.sep:SetShown(on)
    f.nextTime:SetShown(on)
end

local function Placed(fl, n)
    if not (fl.known and fl.known > 0 and n > 2) then return false end
    for i = 2, n do
        if not fl.points[i].at then return false end
    end
    return true
end

local function HideStop(m)
    m.ring:Hide()
    m.edge:Hide()
    m.hole:Hide()
    m.label:Hide()
end

local function PlaceStop(f, m, p, known, lastRight)
    local x = TRACK_H / 2 + math.min(p.at / known, 1) * SPAN
    m.at, m.name = p.at, Short(p.name)
    m.ring:ClearAllPoints()
    m.ring:SetPoint("CENTER", f.track, "LEFT", x, 0)
    m.label:SetText(m.name)
    m.label:SetWidth(0)
    local half = m.label:GetStringWidth() / 2
    local cx = math.max(half, math.min(WIDTH - half, x))
    local room = cx - half >= lastRight + LABEL_SPACE
    m.label:ClearAllPoints()
    m.label:SetPoint("TOP", f, "TOPLEFT", PAD + cx, -LABEL_TOP)
    m.ring:Show()
    m.edge:Show()
    m.label:SetShown(room)
    PaintStop(m, false)
    if room then return cx + half end
end

local function LayoutStops(f, fl, n, placed)
    local points = fl.points
    local count = placed and n - 2 or 0
    local lastRight, labelled = -LABEL_SPACE, false
    for k = 1, math.max(count, #f.stops) do
        local m = f.stops[k]
        if k <= count then
            if not m then
                m = NewStop(f)
                f.stops[k] = m
            end
            local right = PlaceStop(f, m, points[k + 1], fl.known, lastRight)
            if right then lastRight, labelled = right, true end
        elseif m then
            HideStop(m)
        end
    end
    f.count = count
    return labelled
end

local function LayoutRoute(f, fl, points, n)
    local from = Short(n > 0 and points[1].name or fl.from)
    f.from:SetText(from or "")
    Fit(f.from, ROUTE_CAP)
    f.from:SetShown(from and true or false)
    f.arrow:SetShown(from and true or false)
    f.to:SetText(Short(n > 0 and points[n].name or fl.to) or TEXT_IN_FLIGHT)
    Fit(f.to, ROUTE_CAP)
    f.to:ClearAllPoints()
    if from then
        f.to:SetPoint("LEFT", f.arrow, "RIGHT", TEXT_GAP, TEXT_DROP)
    else
        f.to:SetPoint("BOTTOMLEFT", f, "TOPLEFT", PAD, -PAD - HEAD_H)
    end
end

local function LayoutFoot(f, points, n, footTop)
    f.nextKey:ClearAllPoints()
    f.nextKey:SetPoint("LEFT", f, "TOPLEFT", PAD, -footTop - BTN_H / 2)
    ShowNext(f, nil)
    if f.foot ~= "via" then
        f.nextKey:SetText(TEXT_NEXT)
        return
    end
    wipe(f.via)
    for i = 2, n - 1 do f.via[#f.via + 1] = Short(points[i].name) end
    f.nextKey:SetText(TEXT_VIA)
    f.nextName:SetText(table.concat(f.via, LIST_JOIN))
    Fit(f.nextName, NEXT_CAP)
    f.nextKey:Show()
    f.nextName:Show()
end

function Look.Layout(f, fl, land, games)
    local points = fl.points
    local n = points and #points or 0
    LayoutRoute(f, fl, points, n)
    local known = (fl.known and fl.known > 0) and true or false
    for _, part in ipairs(f.lit) do part:SetShown(known) end
    local placed = Placed(fl, n)
    local labelled = LayoutStops(f, fl, n, placed)
    local footTop = ZONE_TOP + ZONE_H + (labelled and LABEL_GAP + LABEL_H or 0) + ROW_GAP
    f.foot = placed and "next" or n > 2 and "via" or nil
    LayoutFoot(f, points, n, footTop)
    local right = PAD + WIDTH
    for i = #f.games, 1, -1 do
        local b = f.games[i]
        b:SetShown(games)
        b:ClearAllPoints()
        if games then
            b:SetPoint("TOPRIGHT", f, "TOPLEFT", right, -footTop)
            right = right - BTN_H - ICON_GAP
        end
    end
    if games then right = right + ICON_GAP - BTN_GAP end
    f.land:SetShown(land)
    f.land:ClearAllPoints()
    f.land:SetPoint("TOPRIGHT", f, "TOPLEFT", right, -footTop)
    f.land:SetEnabled(not fl.early)
    f.land:SetAlpha(fl.early and LAND_USED_ALPHA or 1)
    local foot = f.foot or land or games
    f:SetHeight((foot and footTop + BTN_H or footTop - ROW_GAP) + PAD)

    f.sec, f.nextSec, f.shown, f.at, f.passed = nil, nil, nil, math.huge, 0
end

local function Advance(f, elapsed)
    if elapsed < f.at then
        for k = 1, f.count do PaintStop(f.stops[k], false) end
        f.passed = 0
    end
    f.at = elapsed
    local passed = f.passed
    while passed < f.count and f.stops[passed + 1].at <= elapsed do
        passed = passed + 1
        PaintStop(f.stops[passed], true)
    end
    f.passed = passed
    local m = passed < f.count and f.stops[passed + 1] or nil
    if m ~= f.shown then
        f.shown, f.nextSec = m, nil
        ShowNext(f, m)
    end
    if m then
        local left = m.at - elapsed
        local sec = math.floor(left + ROUND)
        if sec ~= f.nextSec then
            f.nextSec = sec
            f.nextTime:SetText(Clock(left))
        end
    end
end

function Look.Progress(f, fl, elapsed)
    local known = fl.known and fl.known > 0 and fl.known
    local shown = known and known - elapsed or elapsed
    local sec = math.floor(math.max(0, shown) + ROUND)
    if sec ~= f.sec then
        f.sec = sec
        f.time:SetText(Clock(shown))
    end
    if not known then return end
    local w = math.max(FILL_MIN, math.min(elapsed / known, 1) * SPAN)
    f.fill:SetWidth(w)
    f.trail:SetWidth(math.min(TRAIL_W, w))
    if f.foot == "next" then Advance(f, elapsed) end
end

local function Play(game)
    if InCombatLockdown() then return end
    if flight then flight.wordFirst = nil end
    if game.id ~= "quiz" and ns.QuizDismiss then ns.QuizDismiss() end
    if not game.aim and ns.AimDismiss then ns.AimDismiss() end
    if not game.word and ns.DailyWordDismiss then ns.DailyWordDismiss() end
    if game.aim then
        if ns.AimPlay then ns.AimPlay(game.id, "flight") end
    elseif game.word then
        if ns.DailyWordPlay then ns.DailyWordPlay("flight") end
    elseif ns.QuizPlay then
        ns.QuizPlay("flight")
    end
end

local function GameOn(game)
    if game.aim then return ns.AimTrainerOn and ns.AimTrainerOn() end
    if game.word then return ns.DailyWordOn and ns.DailyWordOn() end
    return true
end

local function PaintGames(f)
    for i, game in ipairs(GAME_BUTTONS) do
        local b, on = f.games[i], GameOn(game) and true or false
        b:SetEnabled(on)
        b.icon:SetAlpha(on and 1 or GAME_OFF_ALPHA)
        ns.Tooltip(b, game.title, on and game.tip or game.aim and AIM_OFF or WORD_OFF)
    end
end

local function Layout()
    local land = S.Get("flightEarlyLanding") and not flight.sample
    local games = S.Get("enabled") and S.Get("flightGame") ~= "off" and not flight.sample
    Look.Layout(bar, flight, land and true or false, games and true or false)
    PaintGames(bar)
end

local function Update()
    if not (bar and flight and bar:IsShown()) then return end
    local elapsed = GetTime() - flight.start
    if flight.sample then elapsed = elapsed % flight.known end
    Look.Progress(bar, flight, elapsed)
end

local function Show()
    if settingsOpen then return end
    Layout()
    Update()
    bar:Show()
end

local function StopPoll()
    if poll then poll:Cancel(); poll = nil end
end

local function Land()
    local elapsed = GetTime() - flight.start
    local key = RouteKey(flight.from, flight.to)
    if key and elapsed > MIN_LEARNED and not flight.early then Times()[key] = math.floor(elapsed + ROUND) end
    flight = nil
    StopPoll()
    bar:Hide()
    FadeBlizzardStop()
    if unlocked then Apply() end
    if ns.QuizDismiss then ns.QuizDismiss("flight") end
    if ns.AimDismiss then ns.AimDismiss("flight") end
    if ns.DailyWordDismiss then ns.DailyWordDismiss("flight") end
end

local FLIGHT_GAMES = { off = true, none = true, quiz = true, aim = true, word = true }

local function MigrateGame()
    local db = S.DB()
    if db.flightGameMigrated then return end
    db.flightGameMigrated = true
    if db.flightGame == nil and S.Raw("quizFlight") == false then
        db.flightGame = S.Raw("aimAutoFlight") == true and "aim" or "none"
    end
    db.quizFlight, db.aimAutoFlight = nil, nil
end

local function Game()
    MigrateGame()
    local game = S.Get("flightGame")
    return FLIGHT_GAMES[game] and game or "aim"
end

local function WordFirst(game)
    return S.Get("flightWordFirst") and OPENS_BY_ITSELF[game] and game ~= "word"
end

local function OfferChosen(game)
    if game == "quiz" then
        if ns.QuizOffer then ns.QuizOffer("flight") end
    elseif game == "aim" then
        if ns.AimOffer then ns.AimOffer("flight") end
    elseif game == "word" then
        if ns.DailyWordOffer then ns.DailyWordOffer("flight") end
    end
end

local function OfferGame()
    local game = Game()
    if WordFirst(game) and ns.DailyWordOffer and ns.DailyWordOffer("flight") then
        flight.wordFirst = true
        return
    end
    OfferChosen(game)
end

local function StopOffering()
    S.Set("flightGame", "none")
    if ns.QuizDismiss then ns.QuizDismiss("flight") end
    if ns.AimDismiss then ns.AimDismiss("flight") end
    if ns.DailyWordDismiss then ns.DailyWordDismiss("flight") end
    ns.Print(TEXT_STOPPED)
end

function ns.FlightGameHideButton(parent, size)
    local button = IconButton(parent, HIDE_KIND, St.EYE_OFF, size)
    button._onClick = StopOffering
    ns.Tooltip(button, TEXT_NOT_ON_FLIGHTS, TIP_NOT_ON_FLIGHTS)
    button:Hide()
    return button
end

function ns.FlightGameOffered(reason)
    return reason == "flight" and OPENS_BY_ITSELF[Game()] == true
end

function ns.FlightWordClosed()
    if not (flight and flight.wordFirst) then return end
    flight.wordFirst = nil
    local game = Game()
    if WordFirst(game) then OfferChosen(game) end
end

local function Board(route)
    local key = route and RouteKey(route.from, route.to)
    flight = { from = route and route.from, to = route and route.to, start = GetTime(),
        points = route and route.points,
        known = route and route.estimate or key and Times()[key] }
    pending = nil
    if On() then Show() end
    FadeBlizzardStop()
    OfferGame()
end

local function Retarget()
    if not flight or flight.early or flight.sample then return end
    flight.early = true
    local elapsed, kept = GetTime() - flight.start, {}
    for _, stop in ipairs(flight.points or {}) do
        kept[#kept + 1] = stop
        if stop.at and stop.at > elapsed then
            flight.points, flight.known = kept, stop.at
            break
        end
    end
    if bar and bar:IsShown() then Show() end
end

local function Tick()
    if flight and not flight.sample then
        if not UnitOnTaxi("player") then Land() else Update() end
    elseif pending then
        if UnitOnTaxi("player") then
            Board(pending)
        elseif GetTime() - pending.at > BOARD_WAIT then
            pending = nil
            StopPoll()
        end
    else
        StopPoll()
    end
end

local function StartPoll()
    if not poll then poll = C_Timer.NewTicker(POLL_EVERY, Tick) end
end

local function LandEarly()
    TaxiRequestEarlyLanding()
end

local function SavePosition(pos)
    local scale = bar:GetScale()
    S.Set("flightTimerPos", { point = pos.point, relPoint = pos.relPoint,
        x = pos.x * scale, y = pos.y * scale })
end

local function Build()
    bar = CreateFrame("Frame", "NaowhForeverFlightTimer", UIParent)
    bar:SetFrameStrata("HIGH")
    Look.New(bar)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar.land._onClick = LandEarly
    ns.Tooltip(bar.land, TIP_LAND_TITLE, TIP_LAND)
    for i, game in ipairs(GAME_BUTTONS) do
        bar.games[i]._onClick = function() Play(game) end
    end
    bar:SetScript("OnUpdate", Update)
    bar.mover = ns.UI.AttachMover(bar, MOVER_LABEL, SavePosition, SETTINGS_PAGE, SETTINGS_CARD)
    bar:Hide()
end

local function Place()
    local pos, scale = S.Get("flightTimerPos"), bar:GetScale()
    bar:ClearAllPoints()
    if pos then
        bar:SetPoint(pos.point, UIParent, pos.relPoint, pos.x / scale, pos.y / scale)
    else
        bar:SetPoint("TOP", UIParent, "TOP", 0, DEFAULT_TOP / scale)
    end
end

local function OnTakeTaxi(index)
    local points, estimate = Route(index)
    pending = { from = CurrentNodeName(), to = TaxiNodeName(index), points = points,
        estimate = estimate, at = GetTime() }
    StartPoll()
end

local function OnEvent(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent(event)
        FadeBlizzardStop()
    elseif UnitOnTaxi("player") and not flight then
        Board(nil)
        StartPoll()
    end
end

hooksecurefunc("TakeTaxiNode", OnTakeTaxi)
hooksecurefunc("TaxiRequestEarlyLanding", Retarget)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", OnEvent)

function FadeBlizzardStop()
    local fade = (On() and S.Get("flightEarlyLanding") and flight and not flight.sample) == true
    if fade == stopFaded then return end
    if InCombatLockdown() then events:RegisterEvent("PLAYER_REGEN_ENABLED") return end
    stopFaded = fade
    MainMenuBarVehicleLeaveButton:SetAlpha(fade and 0 or 1)
    MainMenuBarVehicleLeaveButton:EnableMouse(not fade)
end

local function OnSettingsShow()
    settingsOpen = true
    if bar then bar:Hide() end
end

local function OnSettingsHide()
    settingsOpen = false
    if bar and flight and (flight.sample or On()) then Show() end
end

local function HookSettings()
    local panel = _G.SettingsPanel
    if settingsHooked or not panel or not On() then return end
    settingsHooked = true
    settingsOpen = panel:IsShown()
    panel:HookScript("OnShow", OnSettingsShow)
    panel:HookScript("OnHide", OnSettingsHide)
end

local SAMPLE = { { name = ns.L("Southshore"), at = 0 }, { name = ns.L("Refuge Pointe"), at = 50 },
    { name = ns.L("Menethil Harbor"), at = 95 }, { name = ns.L("Thelsamar"), at = 150 } }

function Apply()
    MigrateGame()
    HookMap()
    HookSettings()
    if not bar then Build() end
    bar:SetScale(S.Get("flightTimerScale"))
    Look.Style(bar)
    Place()
    if unlocked then
        bar.mover:Show()
        if not flight then
            flight = { start = GetTime(), known = SAMPLE_KNOWN, points = SAMPLE, sample = true }
            Show()
        end
    elseif flight and flight.sample then
        flight = nil
        bar:Hide()
    end
    if flight and not flight.sample then
        if On() then Show() else bar:Hide() end
    end
    FadeBlizzardStop()
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "flightEarlyLanding" or key == "flightGame"
        or (key:find("^flightTimer") and key ~= "flightTimerPos") or key == "aimTrainer" or key == "dailyWord" then
        Apply()
    end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = On() == true
    Apply()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    if bar then
        bar.mover:Hide()
        Apply()
    end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local STAGE_H, STAGE_MARGIN = 150, St.STAGE_MARGIN
local PREVIEW_ELAPSED = 66
local PREVIEW = { from = "Darkshire", to = "Stormwind", known = 150,
    points = { { name = ns.L("Darkshire"), at = 0 }, { name = ns.L("Lakeshire"), at = 95 }, { name = ns.L("Stormwind"), at = 150 } } }
local STATES = {
    { key = "flying", label = "Flying", tip = "Partway through a flight to Stormwind, 1:24 from landing." },
}

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.bar = CreateFrame("Frame", nil, preview)
    Look.New(preview.bar)
    preview.bar.land:EnableMouse(false)
    for _, b in ipairs(preview.bar.games) do b:EnableMouse(false) end
    return preview
end

local function PaintPreview(preview)
    local f = preview.bar
    local games = S.Get("enabled") and S.Get("flightGame") ~= "off"
    Look.Style(f)
    Look.Layout(f, PREVIEW, S.Get("flightEarlyLanding") and true or false, games and true or false)
    Look.Progress(f, PREVIEW, PREVIEW_ELAPSED)
    PaintGames(f)
    local w, h = f:GetWidth(), f:GetHeight()
    local scale = S.Get("flightTimerScale")
    local roomW = preview:GetWidth() - STAGE_MARGIN * 2
    local roomH = preview:GetHeight() - STAGE_MARGIN * 2
    if roomW > 0 and w * scale > roomW then scale = roomW / w end
    if roomH > 0 and h * scale > roomH then scale = roomH / h end
    f:SetScale(scale)
    f:ClearAllPoints()
    f:SetPoint("CENTER")
end

local function Summary(store)
    local alpha = store.Get("flightTimerAlpha")
    return SUMMARY:format(math.floor(store.Get("flightTimerScale") * PERCENT + ROUND),
        alpha < 1 and SUMMARY_BACKGROUND:format(math.floor(alpha * PERCENT + ROUND)) or "",
        store.Get("flightEarlyLanding") and SUMMARY_LAND or "")
end

Settings.Page("QoL/Travel", S):Card({
    id = "flightTimer", name = "Flight Timer", order = 10, switch = "flightTimer",
    help = "Your flight on a card: time left, the stops on a track, and the next stop.",
    summary = Summary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        { key = "flightEarlyLanding", label = "Land Early Button", toggle = true,
          help = "Adds a Land button to come down at the next stop on the way." },
        { key = "flightTimerMapTime", label = "Flight Time on Map", toggle = true,
          help = "The flight time to each destination when you hover it on the flight master's map." },
        Settings.Group("Size"),
        { key = "flightTimerScale", label = "Scale", slider = SCALE_RANGE, unit = "%", scale = PERCENT_SCALE },
        Settings.Look("flightTimer", { text = true, bar = "Flat", background = "alpha",
            keys = { FontSize = false, BgAlpha = "flightTimerAlpha" } }),
    },
})

local GAME_NAMES = { off = "Off", none = "Buttons only", quiz = "Quiz", aim = "Aim Trainer", word = "Daily Word" }
local GAMES = { GAME_NAMES, { "off", "none", "quiz", "aim", "word" } }

local function GamesSummary()
    local game = Game()
    if game == "off" then return GAMES_OFF end
    if game == "none" then return GAMES_BUTTON end
    if game == "aim" and not (ns.AimTrainerOn and ns.AimTrainerOn()) then
        return GAMES_AIM_OFF
    end
    if game == "word" and not (ns.DailyWordOn and ns.DailyWordOn()) then
        return GAMES_WORD_OFF
    end
    return ns.L(GAME_NAMES[game]) .. GAMES_WHEN
end

Settings.Page("QoL/Travel", S):Card({
    id = "flightGames", name = "Flight Games", order = 15,
    help = "A game that opens when a flight starts and closes when you land.",
    summary = GamesSummary,
    rows = {
        { key = "flightGame", label = "On Flights", choice = GAMES,
          get = Game, set = function(v) S.Set("flightGame", v) end,
          help = "What opens when a flight starts; Off hides the game buttons." },
        { key = "flightWordFirst", label = "Daily Word First", toggle = true,
          needs = function() return S.Get("dailyWord") and (Game() == "quiz" or Game() == "aim") end,
          help = "Opens the Daily Word first until today's is done; closing it opens your game." },
    },
})

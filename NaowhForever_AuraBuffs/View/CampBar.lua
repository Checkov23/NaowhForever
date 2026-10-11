-- CampBar.lua: the Simple look, a bar with the campfire, the camp's bonuses and the time left over a line.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local S = A.Settings
local T = ns.THEME
local St = A.Style
local Parts = ns.Shared.Parts
local Look = A.CampIcon

local BAR = St.CAMP_BAR
local MIN_LABELS = St.CAMP_MIN_LABELS
local TIME_SAMPLE, SIT_SAMPLE = St.CAMP_TIME_SAMPLE, St.CAMP_SIT_PREFIX .. "44s"

local TEXT_CAMP = ns.L("Camp Active")
local TEXT_NO_BONUSES = ns.L("no bonuses")
local TEXT_RESTING = ns.L("Resting")
local TEXT_REFRESH, TEXT_REFRESH_CAMP = ns.L("Refresh (camp)"), ns.L("%s Camp")
local TEXT_NEARBY, TEXT_SIT = ns.L("Camp Nearby"), ns.L("sit to refresh")
local TEXT_MORE = ns.L("+%d more")

local moreTexts = {}

local Bar = {}
A.CampBar = Bar

local function Edge(f, axis)
    local edge = ns.Solid(f.edges, "OVERLAY", St.BORDER_RGB, 1)
    ns.Hairline(edge, axis)
    return edge
end

local function NewEdges(f)
    f.edges = CreateFrame("Frame", nil, f.bar)
    f.edges:SetAllPoints()
    f.edges:SetFrameLevel(f.line:GetFrameLevel() + 1)
    f.top, f.bottom, f.left, f.right = Edge(f, "h"), Edge(f, "h"), Edge(f, "v"), Edge(f, "v")
    f.top:SetPoint("TOPLEFT")
    f.top:SetPoint("TOPRIGHT")
    f.bottom:SetPoint("BOTTOMLEFT")
    f.bottom:SetPoint("BOTTOMRIGHT")
    f.left:SetPoint("TOPLEFT")
    f.left:SetPoint("BOTTOMLEFT")
    f.right:SetPoint("TOPRIGHT")
    f.right:SetPoint("BOTTOMRIGHT")
end

local function TextWidth(f, text)
    f.probe:SetText(text)
    return f.probe:GetStringWidth()
end

local function MinWidth(f, size)
    local text = 0
    for i = 1, #MIN_LABELS do text = text + TextWidth(f, MIN_LABELS[i]) end
    local icons = S.Get("campBonusIcons") and #MIN_LABELS * (size + BAR.BONUS_ICON_GROW + BAR.BONUS_ICON_GAP) or 0
    local time = S.Get("campTimer") and BAR.TIME_GAP + f.timeW or 0
    return math.ceil(f.labelX + text + icons + (#MIN_LABELS - 1) * BAR.BONUS_GAP + time + BAR.PAD)
end

local function BareFonts(f, size)
    local font, outline = S.Get("campAlertFont"), S.Get("campAlertOutline")
    local mode = f.plate:SetMode(S.Get("campAlertBackground"))
    local shadow = mode ~= "none" and mode or nil
    Parts.HudFont(f.note, font, size, outline, shadow)
    Parts.HudFont(f.time, font, size, outline, shadow)
    Parts.HudFont(f.dot, font, size, outline, shadow)
    Parts.HudFont(f.probe, font, size, outline, shadow)
end

local function BarFonts(f, size)
    local font, outline, shadow = ns.UIFontPath(), "", nil
    if not f.bare then
        local o = S.Get("campBarOutline")
        font, outline = ns.UI.FontPath(S.Get("campFont")), Parts.HudFlags(o)
        shadow = o == "" and "card" or false
    end
    f.font, f.outline, f.shadow = font, outline, shadow
    for _, fs in ipairs(f.texts) do
        fs:SetFont(font, size, outline)
        if shadow ~= nil then Parts.HudText(fs, shadow) end
    end
    if f.bare then BareFonts(f, size) end
end

local function PlaceTexts(f)
    f.camp:ClearAllPoints()
    f.camp:SetSize(f.campSize, f.campSize)
    f.camp:SetPoint("CENTER", f.bar, "LEFT", f.campX, BAR.LINE_H / 2)
    f.note:ClearAllPoints()
    f.note:SetPoint("LEFT", f.bar, "LEFT", f.labelX, f.textY)
    f.time:ClearAllPoints()
    if f.bare then
        f.dotW = TextWidth(f, St.PLACE_DOT)
        f.dot:ClearAllPoints()
        f.dot:SetPoint("LEFT", f.note, "RIGHT")
        f.time:SetPoint("LEFT", f.dot, "RIGHT")
    else
        f.time:SetPoint("RIGHT", f.bar, "RIGHT", -BAR.PAD, f.textY)
    end
end

local function MoreText(n)
    local text = moreTexts[n]
    if not text then
        text = ns.Color("muted", TEXT_MORE:format(n))
        moreTexts[n] = text
    end
    return text
end

local function LabelFont(f)
    local labels = f.labels.labels
    for i = 1, #labels do
        labels[i]:SetFont(f.font, f.size, f.outline)
        if f.shadow ~= nil then Parts.HudText(labels[i], f.shadow) end
    end
end

local function PlaceLabels(f)
    f.labels:ClearAllPoints()
    f.labels:SetPoint("LEFT", f.bar, "LEFT", f.labelX + f.lead, f.textY)
end

local function Fold(f, labels, icons, n, room)
    local kept = n - 1
    while f.group > room and kept >= 1 do
        local list, marks = f.moreLabels, f.moreIcons
        for i = 1, kept do list[i], marks[i] = labels[i], icons and icons[i] or false end
        list[kept + 1], marks[kept + 1] = MoreText(n - kept), false
        f.labels:SetLabels(list, kept + 1, marks)
        LabelFont(f)
        f.group = f.labels:Pack()
        f.more = n - kept
        kept = kept - 1
    end
end

local function BarFit(f, labels, icons, n, slot)
    f.pill, f.slot = false, slot
    local room = f.width - f.labelX - f.lead - BAR.PAD
    if slot > 0 then room = room - slot - BAR.TIME_GAP end
    f.labels:SetLabels(labels, n, icons)
    LabelFont(f)
    f.group = f.labels:Pack()
    f.more = 0
    Fold(f, labels, icons, n, room)
    PlaceLabels(f)
    Bar.Size(f)
end

local function BarNote(f, text, color)
    f.note:SetText(text)
    f.note:SetTextColor(color.r, color.g, color.b)
    f.note:Show()
end

local function BarLit(f, on)
    f.lit = on
    f.camp.tex:SetDesaturated(not on)
end

local function NewTexts(f)
    f.time = ns.Font(f.bar, BAR.TEXT, nil, T.fg)
    f.time:SetJustifyH("RIGHT")
    f.line = Parts.TimerLine(f.inner, BAR.LINE_H, f.time)
    f.line:SetPoint("BOTTOMLEFT")
    f.line:SetPoint("BOTTOMRIGHT")
    NewEdges(f)
    f.edges:SetShown(not f.bare)
    f.labels = Parts.LabelRow(f.bar, BAR.TEXT, nil, T.fg, { gap = BAR.BONUS_GAP, iconGrow = BAR.BONUS_ICON_GROW,
        iconGap = BAR.BONUS_ICON_GAP, iconDrop = BAR.BONUS_ICON_DROP })
    f.note = ns.Font(f.bar, BAR.TEXT, nil, T.fg)
    f.note:SetWordWrap(false)
    f.probe = ns.Font(f.bar, BAR.TEXT)
    f.probe:Hide()
    f.texts = { f.time, f.note, f.probe }
end

local function NewBare(f)
    Parts.HudText(f.note)
    Parts.HudText(f.time)
    f.time:SetJustifyH("LEFT")
    f.dot = Parts.HudText(ns.Font(f.bar, BAR.TEXT, nil, T.muted))
    f.dot:SetText(St.PLACE_DOT)
    f.plate = Parts.HudBackdrop(f.bar, { mode = "none" })
end

local function NewWords(f)
    f.campText = TEXT_CAMP .. ns.Color("muted", St.PLACE_DOT .. TEXT_NO_BONUSES)
    f.restText = TEXT_RESTING
    f.refreshText = TEXT_REFRESH_CAMP:format(ns.Color("accent", TEXT_REFRESH))
    f.nearbyText = f.bare and ns.Color("accent", TEXT_NEARBY)
        or ns.Color("accent", TEXT_NEARBY) .. ns.Color("muted", St.PLACE_DOT .. TEXT_SIT)
end

function Bar.CampSize(height)
    return height - 2 * (BAR.EDGE + BAR.ICON_PAD) - BAR.LINE_H
end

function Bar.FireX(height)
    return BAR.EDGE + BAR.ICON_PAD + Bar.CampSize(height) / 2
end

function Bar.Layout(f)
    local size = math.max(BAR.TEXT_MIN, S.Get("campSimpleTextSize"))
    local height = S.Get("campSimpleHeight")
    f.height, f.size = height, size
    f.campSize = Bar.CampSize(height)
    f.campX = Bar.FireX(height)
    f.labelX = f.campX + f.campSize / 2 + BAR.CAMP_GAP
    f.textY = BAR.FONT_LIFT + BAR.LINE_H / 2
    BarFonts(f, size)
    f.labels:SetTextSize(size)
    f.timeW, f.sitW = math.ceil(TextWidth(f, TIME_SAMPLE)), math.ceil(TextWidth(f, SIT_SAMPLE))
    f.minW = MinWidth(f, size)
    f.width = math.max(S.Get("campSimpleWidth"), f.minW)
    PlaceTexts(f)
end

function Bar.New(host, opts)
    local f = CreateFrame("Frame", nil, host)
    f:SetAllPoints()
    f.host = host
    f.bare = opts and opts.bare or false
    f.bar = CreateFrame("Frame", nil, f)
    f.bar:SetAllPoints()
    f.backdrop = Parts.Backdrop(f.bar)
    f.backdrop:Paint(f.bare and 0 or St.BACKDROP_ALPHA)
    f.inner = ns.PixelInset(CreateFrame("Frame", nil, f.bar), 1)
    NewTexts(f)
    if f.bare then NewBare(f) end
    NewWords(f)
    f.moreLabels, f.moreIcons, f.more = {}, {}, 0
    f.camp = CreateFrame("Frame", nil, f.bar)
    f.camp:SetFrameLevel(f.edges:GetFrameLevel() + 1)
    Look.Art(f.camp, true)
    f.lit, f.low, f.lead, f.group, f.pill, f.slot = true, false, 0, 0, false, 0
    Bar.Layout(f)
    Bar.Paint(f, T.accent, false)
    return f
end

function Bar.Size(f)
    local w = f.width
    if f.bare then
        w = f.labelX + f.note:GetStringWidth() + BAR.PAD
        if f.slot > 0 then w = w + f.dotW + f.slot end
    end
    f.host:SetSize(math.ceil(w), f.height)
end

function Bar.Paint(f, color, low)
    f.low = low and true or false
    f.line:Paint(color, f.low and color or T.fg)
end

function Bar.Timed(f, on)
    on = on and true or false
    if not on then f.line:Stop() end
    f.line:SetShown(on and not f.bare)
    f.time:SetShown(on)
    if f.dot then f.dot:SetShown(on) end
end

function Bar.Up(f, labels, icons, n, timed)
    BarLit(f, true)
    f.lead = 0
    f.labels:SetColor(T.fg)
    if n > 0 then f.note:Hide() else BarNote(f, f.campText, T.fg) end
    BarFit(f, labels, icons, n, timed and f.timeW or 0)
end

function Bar.Sitting(f, labels, icons, n, timed, upcoming)
    BarLit(f, true)
    f.lead = 0
    if upcoming then
        f.note:Hide()
        f.labels:SetColor(T.accentSoft)
    else
        BarNote(f, f.restText, T.accentSoft)
        f.labels:SetColor(T.muted)
        if n > 0 then f.lead = math.ceil(f.note:GetStringWidth()) + BAR.BONUS_GAP end
    end
    BarFit(f, labels, icons, n, timed and f.sitW or 0)
end

function Bar.Missing(f, nearby, lit)
    BarLit(f, lit and true or false)
    f.lead, f.more, f.group = 0, 0, 0
    f.labels:SetLabels(nil, 0)
    PlaceLabels(f)
    BarNote(f, nearby and f.nearbyText or f.refreshText, T.fg)
    Bar.Timed(f, false)
    f.pill, f.slot = true, 0
    Bar.Size(f)
end

function Bar.Nearby(f, start, duration)
    Bar.Missing(f, true, start ~= nil)
    if not start then
        f.runStart, f.runLength = nil, nil
        return
    end
    Bar.Paint(f, Look.Step(start + duration - GetTime())[2], true)
    if f.runStart ~= start or f.runLength ~= duration then
        f.runStart, f.runLength = start, duration
        f.line:Run(start, duration)
    end
    Bar.Timed(f, true)
    f.slot = f.timeW
    Bar.Size(f)
end

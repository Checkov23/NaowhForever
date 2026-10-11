-- CampfireCards.lua: the Campfire and Camp Nearby cards on the AuraBuffs/Settings page, with their editable previews.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local S = A.Settings
local T = ns.THEME
local St = A.Style
local Parts = ns.Shared.Parts
local D, Camp = A.CampData, A.Camp
local Look, Bar, Alert = A.CampIcon, A.CampBar, A.CampAlert

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end
local Group = Settings.Group

local BAR = St.CAMP_BAR
local TIME_STEPS = St.CAMP_TIME_STEPS
local SIT_PREFIX = St.CAMP_SIT_PREFIX
local FEATURES, SAMPLE_BONUSES = D.FEATURES, D.SAMPLE_BONUSES
local Simple = Camp.Simple
local STAGE_H, ALERT_H, NOTE_Y, NOTE_SIZE, NOTE_GAP_Y, STAGE_MARGIN, HINT_ROOM = 230, 120, St.STAGE_NOTE_Y, St.STAGE_NOTE_SIZE, 4, St.STAGE_MARGIN, 30
local CAMP_HOUR, SIT_TIME, BUFF_GAP = 3600, 60, 12
local EDGE_HIT, HIDDEN_ALPHA, DRAG_FACTOR = 8, 0.35, 2
local WIDTH_RANGE, TEXT_RANGE, HEIGHT_RANGE = { 200, 480, 5 }, { BAR.TEXT_MIN, 16, 1 }, { 20, 36, 1 }
local MINUTES_RANGE, ICON_RANGE, BUFF_TEXT_RANGE = { 1, 59, 1 }, { 24, 110, 1 }, { 8, 28, 1 }
local TO_FRACTION = St.PERCENT_SCALE
local ORDER_CAMPFIRE, ORDER_NEARBY = 20, 30
local SAMPLE_BUFFS = ns.L("+Rested\n+Crit")
local SIMPLE_HINT = ns.L("Drag the right edge for width. Wheel: text size (Shift: height). Click a bonus or the time "
    .. "to show or hide it. Right-click for more.")
local SIMPLE_OFF_HINT = ns.L("Turn on the Campfire reminder to edit the bar here.")
local SAMPLES = { up = 2400, low = 720, sitting = 35, unread = 2400, alert = 100 }
local STYLES = { { round = "Round", simple = "Simple" }, { "round", "simple" } }
local BUFF_MODES = { { off = "Off", always = "Always", hover = "On Mouseover" }, { "off", "always", "hover" } }
local SIDES = { { below = "Below", above = "Above", left = "Left", right = "Right" },
    { "below", "above", "left", "right" } }
local PERCENT, SECONDS = A.C.PERCENT, A.C.SECONDS
local ALERT_KEYS = { campAlertScale = true, campAlertFade = true }

local OFF = ns.L("Turn on AuraBuffs")
local NEEDS_CAMP = ns.L("Needs the Campfire reminder")
local ALERT_HINT = ns.L("Wheel: size. Right-click for more.")
local TEXT_HIDDEN = ns.L("Show Only When Low: hidden until under %d min.")
local TEXT_HOVER = ns.L("The buffs show while you hover the icon.")
local TEXT_BONUS_HELP = ns.L("Shows this bonus on the bar: %s.")

local BAR_KEYS = { campSimpleWidth = true, campSimpleHeight = true, campSimpleTextSize = true,
    campBarOutline = true, campBonusIcons = true, campHiddenBonuses = true }

local function NearbyState() return Simple() and S.Get("campShowMissing") and true or false end

local STATES = {
    { key = "up", label = "Active", tip = "Camp Benefits with most of its hour left." },
    { key = "low", label = "Running Low", tip = "Camp Benefits running down." },
    { key = "sitting", label = "Resting", tip = "Sitting at a campfire, before Camp Benefits lands." },
    { key = "missing", label = "Refresh", tip = "No Camp Benefits, out in the world.", needs = "campShowMissing" },
    { key = "nearby", label = "Camp Nearby", tip = "No Camp Benefits, with a campfire in range.", needs = NearbyState },
    { key = "unread", label = "No Bonuses", tip = "Camp Benefits up, with no bonuses listed on it.", needs = Simple },
}
local ALERT_STATES = {
    { key = "nearby", label = "Camp Nearby", tip = "A campfire in range and no Camp Benefits." },
    { key = "low", label = "Running Low", tip = "A campfire in range and Camp Benefits about to run out." },
}
local ALERT_SCALE = { 100, 250, 10 }

local campCard

local Enabled, Needs = A.Enabled, A.Needs
local CampOn = A.Needs("campfire")
local function RoundStyle() return not Simple() end
local function PickBuffMode(v) S.Set("campBuffMode", v) end

local function HiddenNote(state)
    if (state == "up" or state == "unread") and S.Get("campShowUnder")
        and SAMPLES.up > S.Get("campShowUnderMinutes") * SECONDS then
        return TEXT_HIDDEN:format(S.Get("campShowUnderMinutes"))
    end
end

local function ToggleBonus(feature)
    local copy = {}
    for id, on in pairs(S.Get("campHiddenBonuses") or {}) do copy[id] = on end
    if copy[feature.id] then copy[feature.id] = nil else copy[feature.id] = true end
    S.Set("campHiddenBonuses", copy)
end

local function ShowAllBonuses() S.Set("campHiddenBonuses", {}) end
local function BonusShown(feature) return not Camp.Hidden(feature) end
local function Toggled(key) return S.Get(key) == true end
local function Toggle(key) S.Set(key, not S.Get(key)) end
local function StylePicked(style) return S.Get("campStyle") == style end
local function PickStyle(style) S.Set("campStyle", style) end
local function BonusClicked(zone) ToggleBonus(zone.feature) end
local function TimeClicked() Toggle("campTimer") end
local function WidthSet(v) S.Set("campSimpleWidth", v) end

local function ResetBar()
    for _, row in ipairs(campCard.rows) do
        if BAR_KEYS[row.key] then Settings.ResetRow(row) end
    end
end

local function BarWheel(_, delta)
    local key, range = "campSimpleTextSize", TEXT_RANGE
    if IsShiftKeyDown() then key, range = "campSimpleHeight", HEIGHT_RANGE end
    local v = Settings.Snap(S.Get(key) + delta * range[3], range)
    if v ~= S.Get(key) then S.Set(key, v) end
end

local function BarMenu(_, root)
    root:CreateTitle(ns.L("Style"))
    root:CreateRadio(ns.L("Round"), StylePicked, PickStyle, "round")
    root:CreateRadio(ns.L("Simple"), StylePicked, PickStyle, "simple")
    root:CreateDivider()
    root:CreateCheckbox(ns.L("Bonus Icons"), Toggled, Toggle, "campBonusIcons")
    root:CreateCheckbox(ns.L("Show Timer"), Toggled, Toggle, "campTimer")
    local list = root:CreateButton(ns.L("Bonuses"))
    for _, feature in ipairs(FEATURES) do
        list:CreateCheckbox(feature.name and feature.short .. St.PLACE_DOT .. feature.name or feature.short,
            BonusShown, ToggleBonus, feature)
    end
    root:CreateDivider()
    root:CreateButton(ns.L("Reset Bar"), ResetBar)
end

local function NewPreview(stage)
    local shot = CreateFrame("Frame", nil, stage)
    shot:SetAllPoints()
    shot.icon = CreateFrame("Frame", nil, shot)
    Look.New(shot.icon)
    shot.hint = ns.Font(shot, NOTE_SIZE, nil, T.muted)
    shot.hint:SetPoint("BOTTOMLEFT", STAGE_MARGIN, NOTE_Y)
    shot.hint:SetPoint("BOTTOMRIGHT", -STAGE_MARGIN, NOTE_Y)
    shot.note = ns.Font(shot, NOTE_SIZE, nil, T.muted)
    return shot
end

local function Fit(shot)
    local f = shot.icon
    local reach = f:GetHeight() + (S.Get("campBuffTextSize") + BUFF_GAP) * 2
    local room = shot:GetHeight() - STAGE_MARGIN * 2 - NOTE_Y * 2
    local scale = 1
    if room > 0 and reach > room then scale = room / reach end
    f:SetScale(scale)
    f:ClearAllPoints()
    f:SetPoint("CENTER", shot, "CENTER", 0, NOTE_Y / scale)
end

local function Run(f, left, duration)
    local start = GetTime() - (duration - left)
    f.timer:SetCooldown(start, duration)
    f.drain:SetCooldown(start, duration)
    Look.Timed(f, S.Get("campTimer"))
end

local function Zone(shot, opts)
    opts.wheel, opts.menu = BarWheel, BarMenu
    local zone = Settings.EditZone(shot.bar, opts)
    zone:SetFrameLevel(shot.bar.camp:GetFrameLevel() + #shot.zones + 1)
    shot.zones[#shot.zones + 1] = zone
    return zone
end

local function PreviewBar(shot)
    if shot.bar then return shot.bar end
    shot.barHost = CreateFrame("Frame", nil, shot)
    local f = Bar.New(shot.barHost)
    shot.bar, shot.zones, shot.bonusZones = f, {}, {}
    local body = Zone(shot, {})
    body:SetAllPoints(f.bar)
    f.labels:SetLabels(Camp.sampleLabels, Camp.FillSamples(false))
    for i = 1, #SAMPLE_BONUSES do
        local zone = Zone(shot, { click = BonusClicked, wash = true })
        zone.feature = SAMPLE_BONUSES[i][1]
        zone:SetAllPoints(f.labels.labels[i])
        shot.bonusZones[i] = zone
    end
    shot.timeZone = Zone(shot, { click = TimeClicked, wash = true })
    shot.timeZone:SetPoint("TOPRIGHT", f.bar, "TOPRIGHT")
    shot.timeZone:SetPoint("BOTTOMRIGHT", f.bar, "BOTTOMRIGHT")
    shot.dragRange = { WIDTH_RANGE[1], WIDTH_RANGE[2], WIDTH_RANGE[3] }
    shot.widthZone = Zone(shot, { edge = true, drag = { get = function() return f.width end, set = WidthSet,
        range = shot.dragRange,
        factor = DRAG_FACTOR, live = function(v) f.width = v; Bar.Size(f) end } })
    shot.widthZone:SetPoint("TOP", f.bar, "TOPRIGHT")
    shot.widthZone:SetPoint("BOTTOM", f.bar, "BOTTOMRIGHT")
    shot.widthZone:SetWidth(EDGE_HIT)
    return f
end

local function FitBar(shot)
    local host, f = shot.barHost, shot.bar
    local half = S.Default("campSimpleWidth") / 2
    local reach, h = WIDTH_RANGE[2] - half, f.height
    local roomW = shot:GetWidth() / 2 - STAGE_MARGIN
    local roomH = shot:GetHeight() - STAGE_MARGIN * 2 - HINT_ROOM
    local scale = 1
    if roomW > 0 and reach > roomW then scale = roomW / reach end
    if roomH > 0 and h * scale > roomH then scale = roomH / h end
    host:SetScale(scale)
    host:ClearAllPoints()
    host:SetPoint("LEFT", shot, "CENTER", -half, HINT_ROOM / 2 / scale)
end

local function RunBar(f, left, duration, timed, prefix)
    if timed then f.line:Run(GetTime() - (duration - left), duration, prefix) end
    Bar.Timed(f, timed)
end

local function PaintBarPreview(shot, state, hidden)
    local f = PreviewBar(shot)
    Bar.Layout(f)
    local timed = S.Get("campTimer") and true or false
    local n = Camp.FillSamples(false)
    local pill = state == "missing" or state == "nearby"
    if pill then
        Bar.Missing(f, state == "nearby")
    elseif state == "sitting" then
        Bar.Sitting(f, Camp.sampleLabels, Camp.sampleIcons, n, timed, false)
        Bar.Paint(f, T.accent, false)
        RunBar(f, SAMPLES.sitting, SIT_TIME, timed, SIT_PREFIX)
    else
        Bar.Up(f, Camp.sampleLabels, Camp.sampleIcons, state == "unread" and 0 or n, timed)
        local step = Look.Step(SAMPLES[state])
        Bar.Paint(f, step[2], step ~= TIME_STEPS[1])
        RunBar(f, SAMPLES[state], CAMP_HOUR, timed)
    end
    local editable = CampOn()
    for _, zone in ipairs(shot.zones) do zone:SetShown(editable and (not pill or zone == shot.zones[1])) end
    local bonuses = f.labels.count - (f.more > 0 and 1 or 0)
    for i, zone in ipairs(shot.bonusZones) do
        local alpha = Camp.Hidden(zone.feature) and HIDDEN_ALPHA or 1
        f.labels.labels[i]:SetAlpha(alpha)
        if f.labels.icons[i] then f.labels.icons[i]:SetAlpha(alpha) end
        if i > bonuses then zone:Hide() end
    end
    shot.timeZone:SetWidth(f.timeW + BAR.PAD)
    local step = WIDTH_RANGE[3]
    shot.dragRange[1] = math.max(WIDTH_RANGE[1], math.ceil(f.minW / step) * step)

    FitBar(shot)
    shot.barHost:SetShown(not hidden)
    shot.hint:SetText(editable and SIMPLE_HINT or SIMPLE_OFF_HINT)
    shot.note:ClearAllPoints()
    shot.note:SetPoint("BOTTOM", shot.hint, "TOP", 0, NOTE_GAP_Y)
    shot.note:SetText(hidden or "")
end

local function PaintPreview(shot, state)
    local f = shot.icon
    local hidden = HiddenNote(state)
    if Simple() then
        f:Hide()
        PaintBarPreview(shot, state, hidden)
        return
    end
    if shot.barHost then shot.barHost:Hide() end
    shot.hint:SetText("")
    shot.note:ClearAllPoints()
    shot.note:SetPoint("BOTTOM", shot, "BOTTOM", 0, NOTE_Y)
    Look.Layout(f)
    Fit(shot)
    local mode = ns.CampBuffMode()
    local note = hidden
    if state == "missing" then
        Look.Missing(f)
    elseif state == "sitting" then
        Look.Sitting(f)
        f.drain:SetSwipeColor(T.accent.r, T.accent.g, T.accent.b, 1)
        Run(f, SAMPLES.sitting, SIT_TIME)
    else
        Look.Up(f, mode ~= "off" and SAMPLE_BUFFS or "")
        f.buffs:SetAlpha(1)
        local color = Look.Step(SAMPLES[state] or SAMPLES.up)[2]
        f.drain:SetSwipeColor(color.r, color.g, color.b, 1)
        Run(f, SAMPLES[state] or SAMPLES.up, CAMP_HOUR)
        if not note and mode == "hover" then note = TEXT_HOVER end
    end
    f:SetShown(not hidden)
    shot.note:SetText(note or "")
end

local alertCard

local function AlertWheel(_, delta)
    local v = Settings.Snap(S.Get("campAlertScale") * PERCENT + delta * ALERT_SCALE[3], ALERT_SCALE) / PERCENT
    if v ~= S.Get("campAlertScale") then S.Set("campAlertScale", v) end
end

local function ResetAlert()
    for _, row in ipairs(alertCard.rows) do
        if ALERT_KEYS[row.key] then Settings.ResetRow(row) end
    end
end

local function AlertMenu(_, root)
    root:CreateTitle(ns.L("Camp Nearby"))
    root:CreateCheckbox(ns.L("Fade"), Toggled, Toggle, "campAlertFade")
    root:CreateDivider()
    root:CreateButton(ns.L("Reset"), ResetAlert)
end

local function NewAlert(stage)
    local shot = CreateFrame("Frame", nil, stage)
    shot:SetAllPoints()
    shot.alert = CreateFrame("Frame", nil, shot)
    Alert.Look(shot.alert)
    shot.zone = Settings.EditZone(shot.alert, { wheel = AlertWheel, menu = AlertMenu })
    shot.zone:SetAllPoints()
    shot.hint = ns.Font(shot, NOTE_SIZE, nil, T.muted)
    shot.hint:SetPoint("BOTTOMLEFT", STAGE_MARGIN, NOTE_Y)
    shot.hint:SetPoint("BOTTOMRIGHT", -STAGE_MARGIN, NOTE_Y)
    return shot
end

local function PaintAlert(shot, state)
    local a, f = shot.alert, shot.alert.bar
    Bar.Layout(f)
    if state == "low" then
        Bar.Nearby(f, GetTime() - (CAMP_HOUR - SAMPLES.alert), CAMP_HOUR)
    else
        Bar.Nearby(f)
    end
    local scale = S.Get("campAlertScale")
    local half = (f.labelX + f.note:GetStringWidth() + BAR.PAD) / 2
    a:SetScale(scale)
    a:ClearAllPoints()
    a:SetPoint("LEFT", shot, "CENTER", -half, HINT_ROOM / 2 / scale)
    Alert.Stop(a)
    a:SetAlpha(1)
    if S.Get("campAlertFade") then a.breathe:Play() end
    local editable = CampOn() and S.Get("campNearbyAlert") and true or false
    shot.zone:SetShown(editable)
    shot.hint:SetText(editable and ALERT_HINT or "")
end

local function CampSummary(store)
    if store.Get("campStyle") == "simple" then
        local parts = { ns.L("Simple bar"), store.Get("campTimer") and "timer" or ns.L("no timer") }
        if store.Get("campBonusIcons") then parts[#parts + 1] = ns.L("bonus icons") end
        if store.Get("campSound") then parts[#parts + 1] = ns.L("a sound to refresh") end
        return table.concat(parts, ", ")
    end
    local parts = { store.Get("campTimer") and ns.L("Timer") or ns.L("No timer") }
    local mode = ns.CampBuffMode()
    if mode == "always" then parts[#parts + 1] = ns.L("camp buffs")
    elseif mode == "hover" then parts[#parts + 1] = ns.L("camp buffs on mouseover") end
    if store.Get("campSound") then parts[#parts + 1] = ns.L("a sound to refresh") end
    return table.concat(parts, ", ")
end

local function AlertSummary(store)
    return (ns.L("Under %d min")):format(store.Get("campNearbyMinutes"))
end

local function StageHeight()
    if Simple() then return STAGE_MARGIN * 2 + HEIGHT_RANGE[2] + HINT_ROOM end
    return STAGE_H
end

local function Only(group, hidden)
    group.hidden = hidden
    return group
end

local function BonusRow(feature)
    return { key = "campHiddenBonuses", field = feature.id, toggle = true, needs = Enabled, why = OFF,
        hidden = RoundStyle, help = TEXT_BONUS_HELP:format(feature.stat), search = feature.aliases and table.concat(feature.aliases, " "),
        label = feature.name and feature.short .. St.PLACE_DOT .. feature.name or feature.short,
        get = function() return BonusShown(feature) end,
        set = function(on) if on ~= BonusShown(feature) then ToggleBonus(feature) end end }
end

local function BonusRows()
    local rows = { Only(Group("Bonuses"), RoundStyle) }
    for _, feature in ipairs(FEATURES) do rows[#rows + 1] = BonusRow(feature) end
    return rows
end

local page = Settings.Page("AuraBuffs/Settings", S)

campCard = page:Card({
    id = "campfire", name = "Campfire", order = ORDER_CAMPFIRE, switch = "campfire",
    help = "Your camp's bonuses and time left on screen, and a reminder when Camp Benefits runs out.",
    summary = CampSummary,
    studio = { height = StageHeight, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        { key = "campStyle", label = "Style", choice = STYLES, needs = Enabled, why = OFF,
          help = "Round shows the camp icon; Simple shows a slim bar with your camp's bonuses." },
        Group("Reminder"),
        { key = "campTimer", label = "Show Camp Timer", toggle = true, needs = Enabled, why = OFF,
          help = "The time left, turning yellow, then red, as the camp runs down." },
        { key = "campShowMissing", label = "Show Refresh Reminder", toggle = true, needs = Enabled, why = OFF,
          help = "Stays on screen, greyed out, while you have no Camp Benefits." },
        { key = "campShowUnder", label = "Show Only When Low", toggle = true, needs = Enabled, why = OFF,
          help = "Hides it until the camp drops under Show Under." },
        { key = "campShowUnderMinutes", label = "Show Under", slider = MINUTES_RANGE, unit = " min",
          needs = Needs("campShowUnder"), why = "Needs Show Only When Low" },
        Only(Group("Simple Bar"), RoundStyle),
        { key = "campSimpleWidth", label = "Bar Width", slider = WIDTH_RANGE, needs = Enabled, why = OFF,
          hidden = RoundStyle, help = "Bonuses that do not fit show as +N more." },
        { key = "campSimpleHeight", label = "Bar Height", slider = HEIGHT_RANGE, needs = Enabled, why = OFF,
          hidden = RoundStyle },
        { key = "campSimpleTextSize", label = "Text Size", slider = TEXT_RANGE, needs = Enabled, why = OFF,
          hidden = RoundStyle },
        { key = "campBonusIcons", label = "Bonus Icons", toggle = true, needs = Enabled, why = OFF,
          hidden = RoundStyle, help = "Each camp feature's own icon before its bonus." },
        { label = "Hidden Bonuses", buttonText = "Show All", button = ShowAllBonuses,
          needs = Enabled, why = OFF, hidden = RoundStyle,
          help = "Shows every bonus again; click one on the preview to hide it." },
        BonusRows(),
        Only(Group("Round Icon"), Simple),
        { key = "campIconSize", label = "Icon Size", slider = ICON_RANGE, needs = Enabled, why = OFF,
          hidden = Simple },
        { key = "campBuffMode", label = "Show Active Camp Buffs", choice = BUFF_MODES, get = ns.CampBuffMode,
          set = PickBuffMode, needs = Enabled, why = OFF, hidden = Simple,
          help = "Your camp's bonuses by the icon, always or while you hover it." },
        { key = "campBuffTextSize", label = "Buff Text Size", slider = BUFF_TEXT_RANGE, needs = Enabled, why = OFF,
          hidden = Simple },
        { key = "campBuffSide", label = "Buff Text Position", choice = SIDES, needs = Enabled, why = OFF,
          hidden = Simple },
        Settings.Look("camp", { text = true, keys = { FontSize = false, Outline = false }, needs = Enabled, why = OFF }),
        { key = "campOutline", label = "Outline", choice = Parts.HUD_OUTLINES, needs = Enabled, why = OFF,
          hidden = Simple },
        { key = "campBarOutline", label = "Bar Outline", choice = Parts.HUD_OUTLINES, needs = Enabled, why = OFF,
          hidden = RoundStyle },
        Group("Sound"),
        { key = "campSound", label = "Play a Sound to Refresh", toggle = true, needs = Enabled, why = OFF,
          help = "Plays when it is time to refresh the camp." },
        { key = "campSoundKey", label = "Sound", sound = true, needs = Needs("campSound"),
          why = "Needs Play a Sound to Refresh" },
    },
})

alertCard = page:Card({
    id = "campNearby", name = "Camp Nearby", order = ORDER_NEARBY, switch = "campNearbyAlert",
    help = "Camp Nearby on screen when a campfire is in range and your camp needs a refresh.",
    search = "ctrl click ctrl-click dismiss hide",
    summary = AlertSummary,
    studio = { height = ALERT_H, states = ALERT_STATES, new = NewAlert, paint = PaintAlert },
    rows = {
        { key = "campNearbyMinutes", label = "Alert Under", slider = MINUTES_RANGE, unit = " min",
          needs = CampOn, why = NEEDS_CAMP,
          help = "How little Camp Benefits time counts as needing a refresh." },
        { key = "campAlertFade", label = "Fade", toggle = true,
          needs = CampOn, why = NEEDS_CAMP,
          help = "Fades the alert in and out, breathing softly while it shows." },
        Group("Size"),
        { key = "campAlertScale", label = "Alert Size", slider = ALERT_SCALE, unit = "%", scale = TO_FRACTION,
          needs = CampOn, why = NEEDS_CAMP },
        Settings.Look("campAlert", { text = true, background = "card", keys = { FontSize = false },
            needs = CampOn, why = NEEDS_CAMP }),
    },
})

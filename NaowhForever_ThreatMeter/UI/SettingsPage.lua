-- SettingsPage.lua: the Threat Meter's settings page, declared as cards, with its editable preview.
local ns = _G.NaowhForever

local T = ns.THEME
local TM = ns.ThreatMeter
local S = TM.Settings
local C, Look = TM.C, TM.Look

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end
local Group, Snap = Settings.Group, Settings.Snap

local OFF = ns.L("Turn on the Threat Meter")
local STAGE_H, STAGE_MARGIN = 300, ns.Shared.Style.STAGE_MARGIN
local NOTE_ROOM, NOTE_BOTTOM, NOTE_SIZE = 28, 8, ns.Shared.Style.STAGE_NOTE_SIZE
local HINT = ns.L("Drag the corner to resize. Wheel: row height (Shift: spacing, Ctrl: text). Right-click a row "
    .. "for what it shows. Click the name or status line to change them.")
local OFF_HINT = ns.L("Turn on the Threat Meter to edit it here.")
local EDIT_LEVEL, TOP_LEVEL = 10, 12
local HOVER_ALPHA = 0.12
local GRIP_SIZE, GRIP_INSET = 16, 2
local HEADER_STUB = 8
local WIDTH_RANGE, HEIGHT_RANGE = { C.MIN_WIDTH, C.MAX_WIDTH, 1 }, { C.MIN_HEIGHT, C.MAX_HEIGHT, 1 }
local ROW_H_RANGE, SPACING_RANGE = { C.MIN_BAR, C.MAX_BAR, 1 }, { 0, C.MAX_SPACING, 1 }
local TEXT_RANGE = { C.MIN_FONT, C.MAX_FONT, 1 }
local ENTRIES_RANGE, WARN_RANGE = { 1, 80, 1 }, { 50, C.PERCENT, 1 }
local PERCENT_STEP, TO_FRACTION = ns.Shared.Style.OPACITY_STEP, ns.Shared.Style.PERCENT_SCALE
local BACKGROUND_RANGE, BAR_ALPHA_RANGE = ns.Shared.Style.ALPHA_RANGE, { 10, C.PERCENT, PERCENT_STEP }
local ORDER_METER, ORDER_WARNING = 10, 20
local STATES = {
    { key = "solo", label = "Solo", tip = "On your own, holding the mob." },
    { key = "tanking", label = "Tanking", tip = "Your group on a boss you are tanking." },
    { key = "pulling", label = "Pulling Aggro", tip = "Close to pulling aggro off the tank." },
}
local VISIBILITY = { always = "Always", threat = "With Threat", combat = "In Combat", group = "In a Group" }
local SHOWN = { always = ns.L("Shown always"), threat = ns.L("Shown with threat"), combat = ns.L("Shown in combat"),
    group = ns.L("Shown in a group") }
local WHEN = { always = ns.L("always"), threat = ns.L("with threat"), combat = ns.L("in combat"),
    group = ns.L("in a group") }
local SHOW = { VISIBILITY, { "always", "threat", "combat", "group" } }
local SOURCE = { { target = "Target", focus = "Focus" }, { "target", "focus" } }
local PERCENT = { { pull = "Aggro Line", tank = "Tank Threat" }, { "pull", "tank" } }
local STATUS = { { bottom = "Bottom", top = "Top" }, { "bottom", "top" } }
local ROW_TOGGLES = {
    { "showValue", ns.L("Show Threat") },
    { "showPercent", ns.L("Show Percent") },
    { "showIcons", ns.L("Class Icons") },
    { "showRanks", ns.L("Rank Numbers") },
    { "highlightPlayer", ns.L("Highlight Your Row") },
}
local TIPS = {
    { "grip", ns.L("Drag the corner"), ns.L("Width and Height") },
    { "header", ns.L("Click the name"), ns.L("Show Target Name") },
    { "status", ns.L("Click the status line"), ns.L("Status Line") },
    { "rows", ns.L("Wheel on the rows"), ns.L("Row Height") },
    { "rows", ns.L("Shift + wheel"), ns.L("Row Spacing") },
    { "rows", ns.L("Ctrl + wheel"), ns.L("Font Size") },
    { "rows", ns.L("Right-click a row"), ns.L("What Rows Show") },
}

local function Enabled() return TM.On() and true or false end
local function Needs(key) return function() return TM.On() and S.Get(key) and true or false end end
local function OwnBar() return TM.On() and S.Get("playerColorOn") and not S.Get("themeColors") end

local function Shade(key)
    return function()
        local c = Look.BarColor(key)
        return c.r, c.g, c.b, 1
    end
end

local function Picked(key)
    return function(r, g, b) S.Set(key, { r = r, g = g, b = b }) end
end

local function HideTip(shot)
    if GameTooltip:GetOwner() == shot.meter then GameTooltip:Hide() end
end

local function ShowTip(shot)
    local part, fg = shot.part, T.fg
    GameTooltip:SetOwner(shot.meter, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ns.L("Edit the Meter"), fg.r, fg.g, fg.b)
    for i = 1, #TIPS do
        local tip = TIPS[i]
        local c = tip[1] == part and T.accent or T.muted
        GameTooltip:AddDoubleLine(tip[2], tip[3], c.r, c.g, c.b, c.r, c.g, c.b)
    end
    GameTooltip:Show()
end

local function Unhover(shot)
    shot.part = nil
    shot.grip:Hide()
    HideTip(shot)
end

local function PartEnter(hit)
    local shot = hit.shot
    shot.part = hit.part
    if hit.wash then hit.wash:Show() end
    shot.grip:Show()
    if not shot.sizing then ShowTip(shot) end
end

local function PartLeave(hit)
    if hit.wash then hit.wash:Hide() end
    local shot = hit.shot
    if not shot.sizing and not shot.meter:IsMouseOver() then Unhover(shot) end
end

local function HeaderClick()
    S.Set("showHeader", not S.Get("showHeader"))
end

local function StatusClick()
    local order, current = STATUS[2], S.Get("statusPos")
    local picked = order[1]
    for i = 1, #order do
        if order[i] == current then
            picked = order[i % #order + 1]
            break
        end
    end
    S.Set("statusPos", picked)
end

local function RowsWheel(_, delta)
    local key, range = "barHeight", ROW_H_RANGE
    if IsControlKeyDown() then
        key, range = "fontSize", TEXT_RANGE
    elseif IsShiftKeyDown() then
        key, range = "barSpacing", SPACING_RANGE
    end
    local v = Snap(S.Get(key) + delta * range[3], range)
    if v ~= S.Get(key) then S.Set(key, v) end
end

local function Toggled(key)
    return S.Get(key) == true
end

local function Toggle(key)
    S.Set(key, not S.Get(key))
end

local function RowMenu(_, root)
    root:CreateTitle(ns.L("Rows Show"))
    for i = 1, #ROW_TOGGLES do
        local t = ROW_TOGGLES[i]
        root:CreateCheckbox(t[2], Toggled, Toggle, t[1])
    end
end

local function RowsUp(hit, button)
    if button ~= "RightButton" then return end
    HideTip(hit.shot)
    MenuUtil.CreateContextMenu(hit, RowMenu)
end

local function Fit(shot)
    local f, area = shot.meter, shot.area
    local w, h = f:GetWidth(), f:GetHeight()
    local roomW, roomH = area:GetWidth(), area:GetHeight()
    local scale = 1
    if roomW > 0 and w > roomW then scale = roomW / w end
    if roomH > 0 and h > 0 and h * scale > roomH then scale = roomH / h end
    f:SetScale(scale)
    f:ClearAllPoints()
    f:SetPoint("CENTER", area, "CENTER", 0, 0)
end

local function PlaceHits(shot, shown)
    local f, header, rows = shot.meter, shot.headerHit, shot.rowsHit
    header:ClearAllPoints()
    if S.Get("showHeader") then
        header:SetAllPoints(f.header)
    else
        header:SetPoint("TOPLEFT", f, "TOPLEFT")
        header:SetPoint("TOPRIGHT", f, "TOPRIGHT")
        header:SetHeight(HEADER_STUB)
    end
    rows:ClearAllPoints()
    rows:SetShown(shown > 0)
    if shown == 0 then return end
    local first, last = f.rows[1], f.rows[shown]
    if S.Get("growUp") then first, last = last, first end
    rows:SetPoint("TOPLEFT", first, "TOPLEFT")
    rows:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT")
end

local function EndSize(shot)
    if not shot.sizing then return false end
    shot.grip:SetScript("OnUpdate", nil)
    shot.sizing, shot.meter.sizing = false, false
    return true
end

local function SizeUpdate(grip)
    local shot = grip.shot
    local f = shot.meter
    local scale = f:GetEffectiveScale()
    local x, y = GetCursorPosition()
    local least = math.ceil(Look.HeaderHeight() + C.FOOTER + 2 * C.INSET + S.Get("barHeight"))
    local w = Snap(shot.fromW + x / scale - shot.fromX, WIDTH_RANGE)
    local h = math.max(least, Snap(shot.fromH + shot.fromY - y / scale, HEIGHT_RANGE))
    if w == shot.sizeW and h == shot.sizeH then return end
    shot.sizeW, shot.sizeH, shot.resized = w, h, true
    f:SetSize(w, h)
    local shown = Look.Layout(f, shot.total, 0, S.Get("barHeight"), S.Get("barSpacing"), S.Get("fontSize"))
    if shown ~= shot.shown then
        shot.shown = shown
        Look.Paint(f, shot.list, 0, shown, shot.title, shot.status)
        PlaceHits(shot, shown)
    end
end

local function SizeStart(grip, button)
    local shot = grip.shot
    if button ~= "LeftButton" or shot.sizing then return end
    local f = shot.meter
    local scale = f:GetEffectiveScale()
    local x, y = GetCursorPosition()
    shot.fromX, shot.fromY = x / scale, y / scale
    shot.fromW, shot.fromH = f:GetWidth(), f:GetHeight()
    shot.sizeW, shot.sizeH, shot.resized = shot.fromW, shot.fromH, false
    shot.sizing, f.sizing = true, true
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", shot.area, "CENTER", -shot.fromW / 2, shot.fromH / 2)
    HideTip(shot)
    grip:SetScript("OnUpdate", SizeUpdate)
end

local function SizeStop(grip)
    local shot = grip.shot
    if not EndSize(shot) then return end
    Fit(shot)
    if shot.resized then
        if shot.sizeW ~= S.Get("width") then S.Set("width", shot.sizeW) end
        if shot.sizeH ~= S.Get("height") then S.Set("height", shot.sizeH) end
    end
    if not shot.meter:IsMouseOver() then Unhover(shot) end
end

local function PreviewHidden(shot)
    EndSize(shot)
    Unhover(shot)
end

local function NewHit(shot, kind, part, wash)
    local hit = CreateFrame(kind, nil, shot.edit)
    hit.shot, hit.part = shot, part
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", PartEnter)
    hit:SetScript("OnLeave", PartLeave)
    if wash then
        hit.wash = ns.Solid(hit, "OVERLAY", T.accent, HOVER_ALPHA)
        hit.wash:SetAllPoints()
        hit.wash:Hide()
    end
    return hit
end

local function NewPreview(stage)
    local shot = CreateFrame("Frame", nil, stage)
    shot:SetAllPoints()
    shot.area = CreateFrame("Frame", nil, shot)
    shot.area:SetPoint("TOPLEFT", STAGE_MARGIN, -STAGE_MARGIN)
    shot.area:SetPoint("BOTTOMRIGHT", -STAGE_MARGIN, STAGE_MARGIN + NOTE_ROOM)
    local f = CreateFrame("Frame", nil, shot)
    shot.meter = f
    Look.New(f)
    shot.list, shot.pool = {}, {}
    f.shot, f.part = shot, "meter"
    f:SetScript("OnEnter", PartEnter)
    f:SetScript("OnLeave", PartLeave)
    shot.edit = CreateFrame("Frame", nil, f)
    shot.edit:SetAllPoints()
    shot.headerHit = NewHit(shot, "Button", "header", true)
    shot.headerHit:SetScript("OnClick", HeaderClick)
    shot.statusHit = NewHit(shot, "Button", "status", true)
    shot.statusHit:SetAllPoints(f.footer)
    shot.statusHit:SetScript("OnClick", StatusClick)
    shot.rowsHit = NewHit(shot, "Frame", "rows", true)
    shot.rowsHit:EnableMouseWheel(true)
    shot.rowsHit:SetScript("OnMouseWheel", RowsWheel)
    shot.rowsHit:SetScript("OnMouseUp", RowsUp)
    local grip = NewHit(shot, "Button", "grip", false)
    grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    grip:SetPoint("BOTTOMRIGHT", -GRIP_INSET, GRIP_INSET)
    grip:SetNormalTexture(C.GRIP_UP)
    grip:SetHighlightTexture(C.GRIP_HIGHLIGHT)
    grip:SetPushedTexture(C.GRIP_DOWN)
    grip:SetScript("OnMouseDown", SizeStart)
    grip:SetScript("OnMouseUp", SizeStop)
    grip:Hide()
    shot.grip = grip
    shot.note = ns.Font(shot, NOTE_SIZE, nil, T.muted)
    shot.note:SetPoint("BOTTOMLEFT", STAGE_MARGIN, NOTE_BOTTOM)
    shot.note:SetPoint("BOTTOMRIGHT", -STAGE_MARGIN, NOTE_BOTTOM)
    shot:SetScript("OnHide", PreviewHidden)
    return shot
end

local function PaintPreview(shot, state)
    EndSize(shot)
    local f = shot.meter
    local me = TM.FillSample(TM.SAMPLES[state], shot.list, shot.pool)
    local title = TM.SAMPLES[state].title
    local total = math.min(#shot.list, S.Get("maxBars"))
    local shown = Look.Layout(f, total, 0, S.Get("barHeight"), S.Get("barSpacing"), S.Get("fontSize"))
    local status = Look.State(me)
    Look.Paint(f, shot.list, 0, shown, title, status)
    shot.title, shot.status, shot.total, shot.shown = title, status, total, shown
    Fit(shot)
    local editable = Enabled()
    f:EnableMouse(editable)
    shot.edit:SetShown(editable)
    shot.note:SetText(editable and HINT or OFF_HINT)
    if not editable then
        Unhover(shot)
        return
    end
    local level = f:GetFrameLevel()
    shot.edit:SetFrameLevel(level + EDIT_LEVEL)
    shot.headerHit:SetFrameLevel(level + TOP_LEVEL)
    shot.grip:SetFrameLevel(level + TOP_LEVEL)
    PlaceHits(shot, shown)
end

local function Headline()
    if not TM.On() then return ns.L("Threat Meter is off") end
    return TM.Watched() == "focus" and ns.L("Tracking threat on your focus") or ns.L("Tracking threat on your target")
end

local function Detail()
    local shown = SHOWN[S.Get("visibility")] or SHOWN.threat
    if S.Get("warnSound") then return (ns.L("%s, warns at %d%% of pulling aggro.")):format(shown, S.Get("warnAt")) end
    return shown .. ns.L(". Unlock its window to drag and resize it, or place it in the HUD Editor.")
end

local function MeterSummary(store)
    return (ns.L("%d by %d, %s")):format(store.Get("width"), store.Get("height"),
        WHEN[store.Get("visibility")] or WHEN.threat)
end

local function WarningSummary(store)
    return ("At %d%%"):format(store.Get("warnAt"))
end

local page = Settings.Page(C.PAGE, S)

page:Window({
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "meter", name = "Meter", order = ORDER_METER,
    help = "Threat on your target or focus for everyone in your group, one bar each. A friendly target "
        .. "shows the enemy it is fighting. Scroll the meter for more entries; unlock its window to drag "
        .. "and resize it, or place it in the HUD Editor.",
    summary = MeterSummary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        Group("Tracking"),
        { key = "focusEnabled", label = "Focus Tracking", toggle = true, needs = Enabled, why = OFF,
          help = "Adds target and focus switching to the meter's title bar." },
        { key = "source", label = "Track", choice = SOURCE, needs = Needs("focusEnabled"),
          why = "Needs Focus Tracking" },
        { key = "visibility", label = "Show", choice = SHOW, needs = Enabled, why = OFF,
          help = "With Threat: hidden until someone in your group has threat on the mob." },
        { key = "percentMode", label = "Percent Of", choice = PERCENT, needs = Enabled, why = OFF,
          help = "Aggro Line: 100% takes aggro. Tank Threat: 100% equals the current tank's threat." },
        { key = "ignorePets", label = "Ignore Pets", toggle = true, needs = Enabled, why = OFF,
          help = "Leave hunter and warlock pets off the meter." },
        { key = "maxBars", label = "Maximum Entries", slider = ENTRIES_RANGE, needs = Enabled, why = OFF },
        Group("Window"),
        { key = "width", label = "Width", slider = WIDTH_RANGE, needs = Enabled, why = OFF },
        { key = "height", label = "Window Height", slider = HEIGHT_RANGE, needs = Enabled, why = OFF },
        { key = "locked", label = "Lock Window", toggle = true, needs = Enabled, why = OFF,
          help = "Off: drag the title bar or resize with the corner grip, outside combat. The HUD Editor "
              .. "works either way." },
        { key = "showHeader", label = "Show Target Name", toggle = true, needs = Enabled, why = OFF,
          help = "A title bar naming the mob the threat is on." },
        { key = "statusPos", label = "Status Line", choice = STATUS, needs = Enabled, why = OFF,
          help = "Where your distance to pulling aggro and the entry count sit: under the bars, or between "
              .. "the title bar and the bars." },
        { key = "growUp", label = "Grow Upward", toggle = true, needs = Enabled, why = OFF,
          help = "New bars stack above the first instead of below." },
        { key = "backgroundAlpha", label = "Background Opacity", slider = BACKGROUND_RANGE, unit = "%",
          scale = TO_FRACTION, needs = Enabled, why = OFF, help = "The window's border fades with it." },
        { key = "backgroundColor", label = "Background Color", colour = true, needs = Enabled, why = OFF,
          get = function()
              local c = Look.BackgroundColor()
              return c.r, c.g, c.b, 1
          end,
          set = Picked("backgroundColor"), help = "Follows your theme until you pick one." },
        Group("Rows"),
        { key = "barHeight", label = "Row Height", slider = ROW_H_RANGE, needs = Enabled, why = OFF },
        { key = "barSpacing", label = "Row Spacing", slider = SPACING_RANGE, needs = Enabled, why = OFF },
        { key = "showValue", label = "Show Threat", toggle = true, needs = Enabled, why = OFF },
        { key = "showPercent", label = "Show Percent", toggle = true, needs = Enabled, why = OFF,
          help = "Uses the Percent Of setting: Aggro Line or Tank Threat." },
        { key = "showIcons", label = "Class Icons", toggle = true, needs = Enabled, why = OFF,
          help = "Pets use their owner's class icon, desaturated." },
        { key = "showRanks", label = "Rank Numbers", toggle = true, needs = Enabled, why = OFF },
        { key = "highlightPlayer", label = "Highlight Your Row", toggle = true, needs = Enabled, why = OFF },
        Settings.Look("", { text = true, size = TEXT_RANGE, bar = "Naowh Gradient", needs = Enabled, why = OFF }),
        { key = "barAlpha", label = "Bar Opacity", slider = BAR_ALPHA_RANGE, unit = "%", scale = TO_FRACTION,
          needs = Enabled, why = OFF },
        Group("Colors"),
        { key = "playerColorOn", label = "Color Your Bar", toggle = true, needs = Enabled, why = OFF,
          help = "Your own bar in one color instead of your class color." },
        { key = "playerColor", label = "Your Color", colour = true, get = Shade("playerColor"),
          set = Picked("playerColor"), needs = OwnBar, why = "Needs Color Your Bar, theme off" },
        { key = "themeColors", label = "Apply Theme to Your Bar", toggle = true, needs = Needs("playerColorOn"),
          why = "Needs Color Your Bar",
          help = "Your bar in a darker shade of your theme's Accent instead of the color picked above. The "
              .. "tank and aggro line colors stay as picked." },
        { key = "tankColorOn", label = "Color the Tank", toggle = true, needs = Enabled, why = OFF,
          help = "Whoever holds aggro in one color." },
        { key = "tankColor", label = "Tank Color", colour = true, needs = Needs("tankColorOn"),
          why = "Needs Color the Tank" },
        { key = "pullBar", label = "Aggro Line", toggle = true, needs = Enabled, why = OFF,
          help = "A bar at the threat where you would pull aggro, so the gap to it is easy to read." },
        { key = "pullColor", label = "Aggro Line Color", colour = true, needs = Needs("pullBar"),
          why = "Needs Aggro Line" },
        { label = "Show It on Screen", buttonText = "Preview", needs = Enabled, why = OFF,
          button = function() ns.PreviewThreatMeter() end,
          help = "Shows the meter with sample bars where it sits on your screen, for ten seconds. Out of "
              .. "combat only." },
    },
})

page:Card({
    id = "warning", name = "Warning Sound", order = ORDER_WARNING, switch = "warnSound",
    help = "Plays once when your threat climbs past the threshold, and again only after it drops back below.",
    summary = WarningSummary,
    rows = {
        { key = "warnAt", label = "Warn At", slider = WARN_RANGE, unit = "%", needs = Enabled, why = OFF },
        { key = "warnSoundKey", label = "Sound", sound = true, needs = Enabled, why = OFF },
        { key = "warnSkipTank", label = "Not While Tanking", toggle = true, needs = Enabled, why = OFF,
          help = "No warning in a tank role, Bear Form or Defensive Stance." },
    },
})

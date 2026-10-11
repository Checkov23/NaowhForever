-- SettingsPage.lua: the Swing Timer's settings page, declared as cards, with its previews.
local ns = _G.NaowhForever

local T = ns.THEME
local ST = ns.SwingTimer
local S = ST.Settings
local C, Look, SPELLS = ST.C, ST.Look, ST.SPELLS
local Color, Plain, On = ST.Color, ST.Plain, ST.On

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end
local Group = Settings.Group

local TEXT_HEROIC_STRIKE = "Heroic Strike"
local OFF = ns.L("Turn on the Swing Timer")
local STAGE_H = 120
local NOTE_Y, NOTE_SIZE = ns.Shared.Style.STAGE_NOTE_Y, ns.Shared.Style.STAGE_NOTE_SIZE
local STAGE_MARGIN = ns.Shared.Style.STAGE_MARGIN
local SAMPLE_LATENCY = 0.06
local SAMPLES = {
    melee = { MH = { 0.55, "1.2" }, OH = { 0.3, "1.3" } },
    ranged = { R = { 0.75, "0.7" } },
    range = { MH = { 0.55, "1.2" }, OH = { 0.3, "1.3" }, oor = true },
    queued = { MH = { 0.7, "0.8" }, OH = { 0.45, "1.0" }, queued = true },
    target = { MH = { 0.55, "1.2" }, TGT = { 0.4, "1.2" } },
    parry = { MH = { 0.55, "1.2" }, TGT = { 0.8, "0.4" } },
    window = { MH = { 0.8, "0.5" }, OH = { 0.6, "0.7" }, window = true },
    standing = { R = { 0.85, "0.4" }, autoShot = true },
    moving = { R = { 0.85, "0.4" }, autoShot = true, moving = true },
    castOk = { MH = { 0.3, "1.8" }, cast = 0.75 },
    castBad = { MH = { 0.6, "1.0" }, cast = 1.3 },
}
local SAMPLE_SWING = 2.6
local WIDTH_RANGE, HEIGHT_RANGE, SPACING_RANGE = { 80, 600, 1 }, { 4, 40, 1 }, { 0, 20, 1 }
local TEXT_RANGE, WINDOW_RANGE = { 6, 24, 1 }, { 0.1, 2, 0.05 }
local OPACITY_RANGE, TO_FRACTION = ns.Shared.Style.ALPHA_RANGE, ns.Shared.Style.PERCENT_SCALE
local ORDER_BARS, ORDER_QUEUED, ORDER_SEALS, ORDER_TARGET = 10, 20, 30, 40
local ORDER_WINDOW, ORDER_AUTO_SHOT, ORDER_CAST_CLIP = 50, 60, 70

local function Enabled() return On() and true or false end
local function ClassIs(token) return select(2, UnitClass("player")) == token end
local function Hunter() return ClassIs("HUNTER") end
local function Paladin() return ClassIs("PALADIN") end
local function Needs(key) return function() return On() and S.Get(key) and true or false end end
local function NotThemed() return On() and not S.Get("themeColors") end
local function WhenIdle() return On() and S.Get("visibility") ~= "always" end
local function HunterOn() return On() and Hunter() end
local function PaladinOn() return On() and Paladin() end

local function Themed(key)
    return function() return Color(key) end
end

local function Picked(key)
    return function(r, g, b) S.Set(key, { r = r, g = g, b = b }) end
end

local function QueueName()
    local ids = SPELLS.NEXT_SWING[select(2, UnitClass("player"))]
    local name = C_Spell.GetSpellName(ids and ids[1] or SPELLS.HEROIC_STRIKE)
    return Plain(name) and name or TEXT_HEROIC_STRIKE
end

local function PreviewWindow(row, sample)
    local sec, key
    if sample.window and row.hand and S.Get("swingWindow") then
        sec, key = S.Get("swingWindowTime"), "swingWindowColor"
    elseif sample.autoShot and row.slot == ST.SWING.Ranged and S.Get("autoShotWindow") and Hunter() then
        sec, key = C.AUTO_SHOT_CAST, sample.moving and "autoShotMovingColor" or "autoShotStandColor"
    end
    if not sec then
        row.window:Hide()
        return
    end
    if S.Get("windowLatency") then sec = sec + SAMPLE_LATENCY end
    Look.Window(row, sec / SAMPLE_SWING, Color(key))
end

local function PaintSampleRow(row, part, sample)
    local fill = part[1]
    row.bar:SetValue(S.Get("depleteFill") and 1 - fill or fill)
    row.time:SetText(part[2])
    row.spark:SetShown(S.Get("showSpark"))
    local queuedName = sample.queued and row.hand and QueueName()
    if queuedName then
        row.bar:GetStatusBarTexture():SetVertexColor(Color("queueColor"))
    else
        row.bar:GetStatusBarTexture():SetVertexColor(Look.BarColor(row))
    end
    Look.Tag(row, queuedName)
    Look.Range(row, sample.oor and S.Get("rangeCheck") and row.slot ~= ST.TARGET)
    PreviewWindow(row, sample)
    if row.tick then
        if sample.cast then
            Look.Tick(row, sample.cast, Color(sample.cast > 1 and "castBadColor" or "castOkColor"))
        else
            row.tick:Hide()
        end
    end
end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.bars = CreateFrame("Frame", nil, preview)
    preview.rows = {}
    for i, label in ipairs(C.BAR_LABELS) do preview.rows[i] = Look.Row(preview.bars, label) end
    preview.note = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.note:SetPoint("BOTTOM", 0, NOTE_Y)
    return preview
end

local function Fit(preview, n)
    local holder = preview.bars
    local w = S.Get("width")
    local h = math.max(n * S.Get("rowHeight") + (n - 1) * S.Get("spacing"), 1)
    holder:SetSize(w, h)
    local roomW = preview:GetWidth() - STAGE_MARGIN * 2
    local roomH = preview:GetHeight() - STAGE_MARGIN * 2 - NOTE_Y * 2
    local scale = 1
    if roomW > 0 and w > roomW then scale = roomW / w end
    if roomH > 0 and h * scale > roomH then scale = roomH / h end
    holder:SetScale(scale)
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", preview, "CENTER", 0, NOTE_Y / scale)
end

local function PaintPreview(preview, state)
    local sample = SAMPLES[state]
    local tex = ns.UI.TexturePath(S.Get("texture"), C.FLAT_TEX)
    local h, sp, w = S.Get("rowHeight"), S.Get("spacing"), S.Get("width")
    local n = 0
    for _, row in ipairs(preview.rows) do
        local part = sample[row.label]
        if part and (row.slot == ST.TARGET or S.Get(row.switch)) then
            Look.Style(row, tex)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", preview.bars, "TOPLEFT", 0, -n * (h + sp))
            row:SetSize(w, h)
            PaintSampleRow(row, part, sample)
            row:Show()
            n = n + 1
        else
            row:Hide()
        end
    end
    Fit(preview, math.max(n, 1))
    local note = ""
    if n == 0 then
        note = ns.L("No bar for this is switched on.")
    elseif sample.autoShot and not Hunter() then
        note = ns.L("Hunters only.")
    elseif state == "parry" then
        note = ns.L("A parry by your target took 40% off its swing.")
    end
    preview.note:SetText(note)
end

local function Studio(states)
    return { height = STAGE_H, states = states, new = NewPreview, paint = PaintPreview }
end

local BAR_STATES = {
    { key = "melee", label = "Melee", tip = "Your weapons mid-swing." },
    { key = "ranged", label = "Ranged", tip = "Your ranged weapon between shots." },
    { key = "range", label = "Out of Range", tip = "Your target out of your weapons' reach.", needs = "rangeCheck" },
}
local QUEUE_STATES = {
    { key = "queued", label = "Queued", tip = "An on-next-swing attack queued on the melee bars." },
}
local TARGET_STATES = {
    { key = "target", label = "Target Swing", tip = "Your target's swing, restarted by its last hit on you." },
    { key = "parry", label = "Parry Haste", tip = "Your target parried, which cut its swing short." },
}
local WINDOW_STATES = {
    { key = "window", label = "Swing End", tip = "The last part of each melee swing, shaded." },
}
local AUTO_SHOT_STATES = {
    { key = "standing", label = "Standing", tip = "Auto Shot's cast while you stand still." },
    { key = "moving", label = "Moving", tip = "Moving holds the shot, so the window turns red." },
}
local CAST_STATES = {
    { key = "castOk", label = "Cast Fits", tip = "Your cast ends before the swing comes due." },
    { key = "castBad", label = "Cast Clips", tip = "Your cast will still be going as the swing comes due." },
}

local function Shown()
    local names = {}
    if S.Get("showMH") then names[#names + 1] = ns.L("Main Hand") end
    if S.Get("showOH") then names[#names + 1] = ns.L("Off Hand") end
    if S.Get("showR") then names[#names + 1] = ns.L("Ranged") end
    if S.Get("targetSwing") then names[#names + 1] = ns.L("Target") end
    return names
end

local function Headline()
    if not ST.SUPPORTED then return ns.L("This client has no swing event") end
    if not S.Get("enabled") then return ns.L("Swing Timer is off") end
    local names = Shown()
    if #names == 0 then return ns.L("No bars switched on") end
    return ns.L("Bars for ") .. table.concat(names, ", ")
end

local function Detail()
    if not ST.SUPPORTED then return ns.L("The swing timer needs WoW: Forever's own swing event.") end
    local aids = {}
    if S.Get("swingWindow") then aids[#aids + 1] = ns.L("Swing End Window") end
    if S.Get("autoShotWindow") then aids[#aids + 1] = ns.L("Auto Shot Window") end
    if S.Get("castClip") then aids[#aids + 1] = ns.L("Cast Clip Marker") end
    local shown = S.Get("visibility") == "always" and ns.L("Shown all the time.") or ns.L("Shown in combat.")
    if #aids == 0 then return shown .. ns.L(" Move the bars in the HUD Editor.") end
    return shown .. ns.L(" With ") .. table.concat(aids, ", ") .. "."
end

local function BarsSummary(store)
    return (ns.L("%d by %d, %s")):format(store.Get("width"), store.Get("rowHeight"),
        store.Get("visibility") == "always" and ns.L("always shown") or ns.L("in combat"))
end

local SHOW = { { always = "Always", combat = "In Combat" }, { "always", "combat" } }

local page = Settings.Page(C.PAGE, S)

page:Window({
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "bars", name = "Bars", order = ORDER_BARS,
    help = "One bar per weapon, timed by the game's own swing event, so parry haste, swing resets and "
        .. "haste are always right. Move them in the HUD Editor.",
    summary = BarsSummary,
    studio = ST.SUPPORTED and Studio(BAR_STATES) or nil,
    rows = {
        Group("Bars"),
        { key = "showMH", label = "Main Hand", toggle = true, needs = Enabled, why = OFF },
        { key = "showOH", label = "Off Hand", toggle = true, needs = Enabled, why = OFF,
          help = "Shown while you have a weapon in your off hand." },
        { key = "showR", label = "Ranged", toggle = true, needs = Enabled, why = OFF,
          help = "Shown while you have a bow, gun, crossbow, wand or thrown weapon." },
        { key = "visibility", label = "Show", choice = SHOW, needs = Enabled, why = OFF },
        { key = "hideWhenIdle", label = "Hide When Idle", toggle = true, needs = WhenIdle,
          why = "Only with Show In Combat", help = "Hide the bars while no swing is running." },
        Group("Size"),
        { key = "width", label = "Width", slider = WIDTH_RANGE, needs = Enabled, why = OFF },
        { key = "rowHeight", label = "Bar Height", slider = HEIGHT_RANGE, needs = Enabled, why = OFF },
        { key = "spacing", label = "Bar Spacing", slider = SPACING_RANGE, needs = Enabled, why = OFF },
        Settings.Look("", { text = true, size = TEXT_RANGE, bar = "Flat", background = "alpha",
            keys = { FontSize = "textSize" }, needs = Enabled, why = OFF }),
        Group("Shown"),
        { key = "depleteFill", label = "Deplete Fill", toggle = true, needs = Enabled, why = OFF,
          help = "Start each bar full and drain it, instead of filling it up." },
        { key = "showTime", label = "Show Time", toggle = true, needs = Enabled, why = OFF,
          help = "Seconds left to the next swing." },
        { key = "showLabel", label = "Show Weapon Label", toggle = true, needs = Enabled, why = OFF,
          help = "MH, OH, R or TGT on each bar." },
        { key = "showSpark", label = "Show Spark", toggle = true, needs = Enabled, why = OFF,
          help = "A glow on the moving edge of the fill." },
        Group("Range"),
        { key = "rangeCheck", label = "Range Check", toggle = true, needs = Enabled, why = OFF,
          help = "Dim a bar and turn its text red while your target is out of that weapon's range." },
        { key = "outOfRangeAlpha", label = "Out of Range Opacity", slider = OPACITY_RANGE, unit = "%",
          scale = TO_FRACTION, needs = Needs("rangeCheck"), why = "Needs Range Check" },
        Group("Colors"),
        { key = "classColored", label = "Class Colors", toggle = true, needs = Enabled, why = OFF,
          help = "Color the weapon bars in your class color." },
        { key = "themeColors", label = "Apply Theme to Bar Colors", toggle = true, needs = Enabled, why = OFF,
          help = "Color the main hand bar with your theme's Accent, the off hand bar with its lighter Accent "
              .. "and the ranged bar with a deeper shade of it, instead of the colors picked here." },
        { key = "mhColor", label = "Main Hand Color", colour = true, get = Themed("mhColor"),
          set = Picked("mhColor"), needs = NotThemed, why = "Apply Theme to Bar Colors is on" },
        { key = "ohColor", label = "Off Hand Color", colour = true, get = Themed("ohColor"),
          set = Picked("ohColor"), needs = NotThemed, why = "Apply Theme to Bar Colors is on" },
        { key = "rColor", label = "Ranged Color", colour = true, get = Themed("rColor"),
          set = Picked("rColor"), needs = NotThemed, why = "Apply Theme to Bar Colors is on" },
    },
})

page:Card({
    id = "queued", name = "Queued Attacks", order = ORDER_QUEUED, switch = "queueHighlight",
    help = "While Heroic Strike, Cleave, Maul or Raptor Strike is queued, the melee bars take its color "
        .. "and name.",
    studio = ST.SUPPORTED and Studio(QUEUE_STATES) or nil,
    rows = {
        { key = "queueColor", label = "Queued Attack Color", colour = true, needs = Enabled, why = OFF,
          help = "Heroic Strike, Maul or Raptor Strike." },
        { key = "cleaveColor", label = "Cleave Color", colour = true, needs = Enabled, why = OFF },
    },
})

page:Card({
    id = "seals", name = "Seal Colors", order = ORDER_SEALS, switch = "sealColors",
    help = "Paladins only. The melee bars take the color of the seal you have up. In combat that is the "
        .. "last seal you cast until it runs out, as the game keeps your buffs "
        .. "from addons there; out of combat it is read from your buffs.",
    rows = {
        { key = "sealRighteousColor", label = "Seal of Righteousness", colour = true, needs = PaladinOn,
          why = "Paladins only" },
        { key = "sealCrusaderColor", label = "Seal of the Crusader", colour = true, needs = PaladinOn,
          why = "Paladins only" },
        { key = "sealCommandColor", label = "Seal of Command", colour = true, needs = PaladinOn,
          why = "Paladins only" },
        { key = "sealJusticeColor", label = "Seal of Justice", colour = true, needs = PaladinOn,
          why = "Paladins only" },
        { key = "sealLightColor", label = "Seal of Light", colour = true, needs = PaladinOn,
          why = "Paladins only" },
        { key = "sealWisdomColor", label = "Seal of Wisdom", colour = true, needs = PaladinOn,
          why = "Paladins only" },
        { key = "sealFuryColor", label = "Seal of Fury", colour = true, needs = PaladinOn,
          why = "Paladins only" },
        { key = "sealMartyrdomColor", label = "Seal of Martyrdom", colour = true, needs = PaladinOn,
          why = "Paladins only" },
    },
})

page:Card({
    id = "target", name = "Target Swing Timer", order = ORDER_TARGET, switch = "targetSwing",
    help = "A bar for your target's swings, restarted by each physical hit you take while it is targeting "
        .. "you, and shortened when it parries. It is an estimate: the game does not say who hit you or "
        .. "with what, so other attackers, physical specials and bleed ticks restart it too.",
    studio = ST.SUPPORTED and Studio(TARGET_STATES) or nil,
    rows = {
        { key = "tgtColor", label = "Target Color", colour = true, needs = Enabled, why = OFF },
    },
})

page:Card({
    id = "swingWindow", name = "Swing End Window", order = ORDER_WINDOW, switch = "swingWindow",
    help = "Shade the last part of each melee swing: when to twist a seal, finish a weave or queue an "
        .. "attack before the hit.",
    studio = ST.SUPPORTED and Studio(WINDOW_STATES) or nil,
    rows = {
        { key = "swingWindowTime", label = "Window Length", slider = WINDOW_RANGE, unit = "s",
          needs = Enabled, why = OFF },
        { key = "swingWindowColor", label = "Window Color", colour = "alpha", needs = Enabled, why = OFF },
        { key = "windowLatency", label = "Add Latency", toggle = true, always = true, needs = Enabled, why = OFF,
          help = "Widen the swing and Auto Shot windows by your world latency, so they show when to press "
              .. "rather than when the server acts." },
    },
})

page:Card({
    id = "autoShot", name = "Auto Shot Window", order = ORDER_AUTO_SHOT, switch = "autoShotWindow",
    help = "Hunters only. Shade Auto Shot's cast at the end of the Ranged bar. It turns red while you move, "
        .. "since moving holds the shot.",
    studio = ST.SUPPORTED and Studio(AUTO_SHOT_STATES) or nil,
    rows = {
        { key = "autoShotStandColor", label = "Standing Color", colour = "alpha", needs = HunterOn,
          why = "Hunters only" },
        { key = "autoShotMovingColor", label = "Moving Color", colour = "alpha", needs = HunterOn,
          why = "Hunters only" },
    },
})

page:Card({
    id = "castClip", name = "Cast Clip Marker", order = ORDER_CAST_CLIP, switch = "castClip",
    help = "While you cast, mark where the cast ends on the Main Hand bar. It turns red when the cast will "
        .. "still be going as the swing comes due.",
    studio = ST.SUPPORTED and Studio(CAST_STATES) or nil,
    rows = {
        { key = "castOkColor", label = "Cast Fits Color", colour = "alpha", needs = Enabled, why = OFF },
        { key = "castBadColor", label = "Cast Clips Color", colour = "alpha", needs = Enabled, why = OFF },
    },
})

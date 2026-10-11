-- SettingsPage.lua: the Top Bar's card on the QoL Interface page, with its live preview, declared once.
local ns = _G.NaowhForever

local TB = ns.TopBar
local S = TB.Settings
local Layout = TB.Layout
local Preview = TB.Preview
local Parts = ns.Shared.Parts
local Group = ns.Shared.Settings.Group

local ResetLayout = Layout.Reset
local STUDIO_H = 120
local ICON_RANGE, TOOLTIP_RANGE = { 12, 32, 1 }, { 80, 160, 5 }
local SYSTEM_TEXT_RANGE, CLOCK_TEXT_RANGE = { 6, 24, 1 }, { 10, 36, 1 }
local ALPHA_RANGE = ns.Shared.Style.ALPHA_RANGE

local TEXT_NO_CLOCK, TEXT_24H, TEXT_12H = ns.L("No clock"), ns.L("24-hour clock"), ns.L("12-hour clock")
local TEXT_SUMMARY = ns.L("%s, %d buttons%s")
local TEXT_FADES = ns.L(", fades until hovered")
local TEXT_CLASSIC_ICONS = ns.L("Classic+ icons are in full color")

local STATES = {
    { key = "normal", label = "Normal", tip = "The bar as it sits on your screen." },
    { key = "faded", label = "Faded", tip = "While the mouse is away, with Show On Mouseover on.",
      needs = "mouseover" },
    { key = "combat", label = "In Combat", tip = "In a fight, with Hide In Combat on: FPS / MS stays up.",
      needs = "hideInCombat" },
}

local function Summary(store)
    local layout = Layout.Saved()
    local clock = not store.Get("showClock") and TEXT_NO_CLOCK or store.Get("use24h") and TEXT_24H or TEXT_12H
    return TEXT_SUMMARY:format(clock, #layout.left + #layout.right, store.Get("mouseover") and TEXT_FADES or "")
end

local function NotClassic()
    return not ns.classicSkin
end

local ROWS = {
    Group("Clock"),
    { key = "showClock", label = "Show Clock", toggle = true,
      help = "The time between the two sides. Click it for the calendar (not with a gamepad).",
      search = "lockouts saved instances /nf lockouts nf lockouts" },
    { key = "use24h", label = "24-Hour Clock", toggle = true, needs = "showClock" },
    Group("Buttons"),
    { key = "layout", label = "Reset Layout", button = ResetLayout, buttonText = "Reset",
      help = "Puts the bar's buttons back as they came: the Dungeon Journal and Discovery on the left, "
          .. "the BiS List and Training Planner on the right." },
    Group("FPS / MS"),
    { key = "showSystem", label = "Show FPS / MS", toggle = true },
    { key = "systemTooltip", label = "Tooltip", toggle = true, needs = "showSystem",
      help = "Latency and addon memory when you hover the readout." },
    Group("Size"),
    { key = "iconSize", label = "Icon Size", slider = ICON_RANGE },
    { key = "tooltipScale", label = "Tooltip Size", slider = TOOLTIP_RANGE, unit = "%",
      help = "Size of the friends, guild, Hearthstone, clock and FPS tooltips." },
    Group("Text"),
    { key = "font", label = "Font", font = true, help = "The FPS / MS readout and the online counts on the buttons." },
    { key = "outline", label = "Outline", choice = Parts.HUD_OUTLINES,
      help = "A black outline round the FPS / MS readout and the counts, in place of the soft shadow." },
    { key = "sysSize", label = "FPS / MS Size", slider = SYSTEM_TEXT_RANGE, needs = "showSystem" },
    { key = "clockFont", label = "Clock Font", font = true, needs = "showClock" },
    { key = "clockSize", label = "Clock Size", slider = CLOCK_TEXT_RANGE, needs = "showClock" },
    { key = "clockOutline", label = "Clock Outline", choice = Parts.HUD_OUTLINES, needs = "showClock",
      help = "A black outline round the clock." },
    Group("Background"),
    { key = "bgAlpha", label = "Bar Opacity", slider = ALPHA_RANGE, unit = "%" },
    Group("Colors"),
    { key = "iconColor", label = "Icon Color", colour = true, needs = NotClassic, why = TEXT_CLASSIC_ICONS,
      help = "The tint on every button's icon: Naowh's own and any addon's." },
    Group("Visibility"),
    { key = "hideInCombat", label = "Hide In Combat", toggle = true, help = "The FPS / MS readout stays up." },
    { key = "mouseover", label = "Show On Mouseover", toggle = true,
      help = "The bar and the FPS / MS readout fade to Faded Opacity until you hover them. Their "
          .. "buttons still click while faded." },
    { key = "mouseoverAlpha", label = "Faded Opacity", slider = ALPHA_RANGE, unit = "%", needs = "mouseover",
      help = "How visible the bar and the FPS / MS readout stay while the mouse is away. At 0 they "
          .. "are invisible." },
}

ns.Shared.Settings.Page("QoL/Interface", S):Card({
    id = "topBar", name = "Top Bar", order = 10, switch = "enabled",
    help = "Your buttons on either side of an optional clock, with FPS and latency underneath. Arrange the "
        .. "buttons in the preview: drag one to move it, its x removes it, a side's + adds one. Move "
        .. "the bar in the HUD Editor.",
    summary = Summary,
    studio = { height = STUDIO_H, states = STATES, new = Preview.New, paint = Preview.Paint },
    rows = ROWS,
})

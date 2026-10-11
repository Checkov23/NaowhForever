-- SettingsPage.lua: the Gear & Trinkets settings page, declared as cards, with the bars' previews.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local G = ns.GearSets
local C, Look = G.C, G.Look

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local PREVIEW_NOTE_GAP = 10
local ADD_TEXT_SIZE, NOTE_SIZE = 14, 12
local BAR_STAGE_H, TRINKET_STAGE_H = 100, 110
local PERCENT, ROUND = C.PERCENT, C.ROUND
local BAR_SIZE_RANGE, TRINKET_SIZE_RANGE, SPACING_RANGE = { 20, 48, 1 }, { 20, 70, 1 }, { 0, 30, 1 }
local OPACITY_RANGE, TO_FRACTION = ns.Shared.Style.OPACITY_RANGE, ns.Shared.Style.PERCENT_SCALE
local ORDER_GEAR_BAR, ORDER_SWAPS, ORDER_TRINKETS, ORDER_WINDOW = 10, 20, 30, 40
local SHOW = { { always = "Always", combat = "In Combat", nocombat = "Out of Combat" },
    { "always", "combat", "nocombat" } }
local PREVIEW_STATE = { { key = "bar", label = "Bar" } }

local GEAR_OFF = ns.L("Turn on Gear & Trinkets")
local TEXT_NO_SETS = ns.L("No gear sets yet: + saves what you wear as one.")
local TEXT_NONE = ns.L("None")
local TEXT_NO_SETS_HEAD = ns.L("No gear sets yet")
local TEXT_DETAIL = ns.L("The same sets as the character sheet's: equip, save, rename or delete them in the Gear Sets window.")

local function GearOn() return S.Get("gearSets") == true end

local function PreviewButton(parent)
    local btn = CreateFrame("Frame", nil, parent)
    btn.icon, btn.border = Look.Dress(btn)
    return btn
end

local function NewBarPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.row = CreateFrame("Frame", nil, preview)
    preview.row:SetPoint("CENTER")
    preview.buttons = {}
    local add = CreateFrame("Frame", nil, preview.row)
    ns.Solid(add, "BACKGROUND", T.panel, 1):SetAllPoints()
    ns.Border(add, G.Style.BLACK)
    add.text = ns.Font(add, ADD_TEXT_SIZE, nil, T.fg)
    add.text:SetPoint("CENTER")
    add.text:SetText("+")
    preview.add = add
    preview.note = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.note:SetPoint("TOP", preview.row, "BOTTOM", 0, -PREVIEW_NOTE_GAP)
    preview.note:SetText(TEXT_NO_SETS)
    return preview
end

local function PaintBarPreview(preview)
    local size, gap = S.Get("gearBarSize"), S.Get("gearBarSpacing")
    local sets = G.Sets()
    for i, set in ipairs(sets) do
        local btn = preview.buttons[i] or PreviewButton(preview.row)
        preview.buttons[i] = btn
        Look.SetButton(btn, set, i, size, gap)
    end
    for i = #sets + 1, #preview.buttons do preview.buttons[i]:Hide() end
    Look.Fit(preview.row, preview.add, #sets, size, gap)
    preview.note:SetShown(#sets == 0)
end

local function NewTrinketPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.row = CreateFrame("Frame", nil, preview)
    preview.row:SetPoint("CENTER")
    preview.slots = {}
    for i = 1, #C.TRINKET_SLOTS do preview.slots[i] = PreviewButton(preview.row) end
    return preview
end

local function PaintTrinketPreview(preview)
    Look.Trinkets(preview.row, preview.slots, S.Get("trinketSize"), S.Get("trinketSpacing"))
end

local function SetChoices()
    local values, order = { [""] = TEXT_NONE }, { "" }
    for _, set in ipairs(G.Sets()) do
        values[set.name] = set.name
        order[#order + 1] = set.name
    end
    return values, order
end

local TEXT_GEAR_SET, TEXT_GEAR_SETS = ns.L("%d gear set"), ns.L("%d gear sets")
local TEXT_OPACITY = ns.L("%d%% opacity")

local function SetsText(n)
    return (n == 1 and TEXT_GEAR_SET or TEXT_GEAR_SETS):format(n)
end

local function Headline()
    local sets = G.Sets()
    if #sets == 0 then return TEXT_NO_SETS_HEAD end
    for _, set in ipairs(sets) do
        if set.equipped then return SetsText(#sets) .. ns.L(", wearing ") .. ns.Color("accentSoft", set.name) end
    end
    return SetsText(#sets)
end

local function Detail()
    return TEXT_DETAIL
end

local function SwapSummary(store)
    local mounted, resting = store.Get("gearMounted"), store.Get("gearResting")
    if mounted ~= "" and resting ~= "" then return mounted .. ns.L(" mounted, ") .. resting .. ns.L(" resting") end
    if mounted ~= "" then return mounted .. ns.L(" while mounted") end
    if resting ~= "" then return resting .. ns.L(" while resting") end
    return TEXT_NONE
end

local function SizeSummary(key)
    return function(store) return store.Get(key) .. " px" end
end

local function WindowSummary(store)
    return TEXT_OPACITY:format(math.floor((store.Get("gearWindowAlpha") or 1) * PERCENT + ROUND))
end

local function OpenWindow()
    ns.OpenGearSetsWindow()
end

local page = Settings.Page(C.PAGE, S)

page:Window({
    text = "Open Gear Sets",
    open = OpenWindow,
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "gearBar", name = "Gear Set Bar", order = ORDER_GEAR_BAR, switch = "gearBarVisible",
    help = "A button per set: click to equip, Shift-click to save what you wear into it, Ctrl-click to rename "
        .. "it, right-click to change its icon, and + to save a new one. The set you wear is outlined. Move it "
        .. "in the HUD Editor.",
    summary = SizeSummary("gearBarSize"),
    studio = { height = BAR_STAGE_H, states = PREVIEW_STATE, new = NewBarPreview, paint = PaintBarPreview },
    rows = {
        Settings.Group("Size"),
        { key = "gearBarSize", label = "Button Size", slider = BAR_SIZE_RANGE, unit = " px", needs = GearOn,
          why = GEAR_OFF, help = "How big each set's button is." },
        { key = "gearBarSpacing", label = "Spacing", slider = SPACING_RANGE, unit = " px", needs = GearOn,
          why = GEAR_OFF, help = "The gap between two buttons." },
        Settings.Group("Visibility"),
        { key = "gearBarShow", label = "Show", choice = SHOW, needs = GearOn, why = GEAR_OFF,
          help = "Always, only in combat, or only out of combat." },
    },
})

page:Card({
    id = "autoSwap", name = "Automatic Swaps", order = ORDER_SWAPS,
    help = "A set that goes on by itself while you ride or rest, and the set you had on goes back afterwards.",
    summary = SwapSummary,
    rows = {
        { key = "gearMounted", label = "Wear While Mounted", choice = SetChoices, needs = GearOn, why = GEAR_OFF,
          help = "Put on while you ride, and the set you had on goes back when you dismount." },
        { key = "gearResting", label = "Wear While Resting", choice = SetChoices, needs = GearOn, why = GEAR_OFF,
          help = "Put on in cities and inns, and taken off again when you leave." },
    },
})

page:Card({
    id = "trinketBar", name = "Trinket Bar", order = ORDER_TRINKETS, switch = "trinketBar",
    help = "Your two trinket slots, movable: left-click to use one, right-click to equip a trinket from your "
        .. "bags outside combat. Move it in the HUD Editor.",
    summary = SizeSummary("trinketSize"),
    studio = { height = TRINKET_STAGE_H, states = PREVIEW_STATE, new = NewTrinketPreview, paint = PaintTrinketPreview },
    rows = {
        { key = "trinketSize", label = "Icon Size", slider = TRINKET_SIZE_RANGE, unit = " px", needs = GearOn,
          why = GEAR_OFF, help = "How big each trinket is." },
        { key = "trinketSpacing", label = "Spacing", slider = SPACING_RANGE, unit = " px", needs = GearOn,
          why = GEAR_OFF, help = "The gap between the two." },
    },
})

page:Card({
    id = "window", name = "Window", order = ORDER_WINDOW,
    help = "The Gear Sets window, with every set and what you can do with it.",
    summary = WindowSummary,
    rows = {
        { key = "gearWindowAlpha", label = "Window Opacity", slider = OPACITY_RANGE,
          unit = "%", scale = TO_FRACTION, help = "How solid the Gear Sets window is, in percent. Also on its title bar." },
    },
})

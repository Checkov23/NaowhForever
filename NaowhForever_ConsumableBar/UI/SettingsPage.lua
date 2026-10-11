-- SettingsPage.lua: the Consumable Bar's settings page: Edit Items, the bar's look with a preview, adding items and its Smart Macros, its anchor and its window.
local ns = _G.NaowhForever

local CB = ns.ConsumableBar
local S, C, D = CB.S, CB.C, CB.Data
local T = ns.THEME
local Shared = ns.Shared
local Settings, St, ItemBar = Shared.Settings, Shared.Style, Shared.ItemBar

local Group = Settings.Group
local STAGE_MIN, STAGE_PAD = 90, 24
local NOTE_FONT = 12
local ASK = "Ask to Add New Consumables"
local HEALTH, FOOD = "NF Health", "NF Food"
local TEXT_NO_MANA = ns.L("You don't use mana")
local BAR_NAME = "Consumable Bar"
local TEXT_EMPTY = ns.L("No items yet. Open Edit Items to add some.")
local TEXT_NONE, TEXT_ONE, TEXT_MANY = ns.L("No items on the bar yet"), ns.L("1 item on the bar"), ns.L("%d items on the bar")
local TEXT_DETAIL = ns.L("Add consumables, put them in order, and set each one up.")
local TEXT_OFF = ns.L("Off")
local DIRECTION = { { RIGHT = "Right", LEFT = "Left", UP = "Up", DOWN = "Down" }, { "RIGHT", "LEFT", "UP", "DOWN" } }
local SIZE_RANGE, SPACING_RANGE, PER_ROW_RANGE = { 20, 64, 1 }, { 0, 20, 1 }, { 1, 24, 1 }
local BG_RANGE = { 0, 100, 5 }
local PERCENT_SCALE = 0.01
local STATES = {
    { key = "rest", label = "Out of Combat", tip = "The bar as it shows outside a fight." },
    { key = "combat", label = "In Combat",
      tip = "Icons set to Hide in Combat are gone, and Hide Bar in Combat hides the whole bar." },
}

local function NewPreview(stage)
    local holder = CreateFrame("Frame", nil, stage)
    holder:SetPoint("CENTER")
    holder.cells = {}
    holder.note = ns.Font(stage, NOTE_FONT, nil, T.muted)
    holder.note:SetPoint("CENTER")
    holder.note:SetText(TEXT_EMPTY)
    return holder
end

local function PaintPreview(holder, state)
    local items = CB.Items()
    local size, gap, grow, perRow = CB.Grid()
    local map = CB.KeyMap()
    local combat = state == "combat"
    for i, entry in ipairs(items) do
        local cell = holder.cells[i]
        if not cell then
            cell = CB.NewCell(holder)
            holder.cells[i] = cell
        end
        cell.entry, cell.itemID = entry, CB.Resolve(entry)
        ItemBar.Place(cell, holder, i, size, gap, grow, perRow)
        CB.PlaceBackground(cell, i, #items, gap, grow, perRow)
        CB.StyleCell(cell, entry, size)
        CB.ShowCount(cell, cell.itemID, 0)
        CB.ShowCooldown(cell, cell.itemID)
        CB.ShowKey(cell, map)
        cell:SetShown(not (combat and (S.Get("consumableBarHideCombat") or CB.Flags(entry).combat)))
    end
    for i = #items + 1, #holder.cells do holder.cells[i]:Hide() end
    holder:SetSize(ItemBar.Size(#items, size, gap, grow, perRow))
    holder.note:SetShown(#items == 0)
end

local function StageHeight()
    local size, gap, grow, perRow = CB.Grid()
    local _, h = ItemBar.Size(#CB.Items(), size, gap, grow, perRow)
    return math.max(STAGE_MIN, h + 2 * C.BG_PAD + STAGE_PAD)
end

local function Headline()
    local n = #CB.Items()
    if n == 0 then return TEXT_NONE end
    return n == 1 and TEXT_ONE or TEXT_MANY:format(n)
end

local function Detail()
    return TEXT_DETAIL
end

local function BarSummary(store)
    if not store.Get("consumableBar") then return TEXT_OFF end
    return Headline()
end

local function OpenEditor()
    CB.OpenEditor()
end

local function Filter(category)
    return { key = "consumableBarSkip", field = category, label = D.NAMES[category], toggle = true,
        under = ASK, help = "Scan Bags adds this kind, and Ask to Add asks about it.",
        get = function() return not (S.Get("consumableBarSkip") or {})[category] end,
        set = function(v)
            local skip = {}
            for k in pairs(S.Get("consumableBarSkip") or {}) do skip[k] = true end
            skip[category] = not v or nil
            S.Set("consumableBarSkip", skip)
        end }
end

local function WindowOpacity()
    return S.Get("consumableBarWindowAlpha") or 1
end

local ANCHOR = { store = S, prefix = CB.PREFIX, name = BAR_NAME, on = CB.On, frame = CB.BarFrame,
    opacity = WindowOpacity }

local barRows = {
    Group("Layout"),
    { key = "consumableBarSize", label = "Icon Size", slider = SIZE_RANGE },
    { key = "consumableBarSpacing", label = "Spacing", slider = SPACING_RANGE },
    { key = "consumableBarGrow", label = "Growth Direction", choice = DIRECTION },
    { key = "consumableBarPerRow", label = "Icons Per Row", slider = PER_ROW_RANGE,
      help = "How many icons fit in a row before the next row starts." },
    { key = "consumableBarCooldown", label = "Show Cooldowns", toggle = true,
      help = "The item's cooldown sweeps over its icon." },
    { key = "consumableBarTooltip", label = "Item Tooltips", toggle = true,
      help = "Hover an icon for the item's tooltip." },
}
for _, row in ipairs(ItemBar.TextRows(S, CB.PREFIX)) do barRows[#barRows + 1] = row end
for _, row in ipairs({
    Group("Showing"),
    { key = "consumableBarHideEmpty", label = "Hide When Out", toggle = true,
      help = "Hides an item you have run out of instead of showing NONE." },
    { key = "consumableBarHideCombat", label = "Hide Bar in Combat", toggle = true,
      help = "Hides the whole bar while you are in combat." },
    { key = "consumableBarBackground", label = "Show Background", toggle = true,
      help = "A dark panel behind the icons." },
    { key = "consumableBarBgAlpha", label = "Background Opacity", slider = BG_RANGE, unit = "%",
      scale = PERCENT_SCALE, needs = "consumableBarBackground" },
}) do barRows[#barRows + 1] = row end

local addingRows = {
    { key = "consumableBarAskNew", label = ASK, toggle = true,
      cog = { title = "Scan Filters", tip = "Which kinds of consumable Scan Bags adds and Ask to Add asks about." },
      help = "Asks whether to add a new consumable when it lands in your bags." },
    { label = "Ask Again for Declined Items", button = CB.ForgetDeclined, buttonText = "Reset",
      help = "Asks again about the items you said no to." },
}
for _, category in ipairs(D.ORDER) do addingRows[#addingRows + 1] = Filter(category) end

local function MacroRow(key, label, help)
    return { label = label, toggle = true, help = help,
        get = function() return CB.HasMacro(key) end,
        set = function(v) CB.SetMacro(key, v) end }
end

local M = ns.MacroSettings
local choices = ns.HealthOrderChoices
if ns.ConsumableMacros and M and choices then
    addingRows[#addingRows + 1] = Group("Smart Macros")
    local health = MacroRow("health", HEALTH, "Your best healthstone or healing potion, through NF Health.")
    health.cog = { title = "Health Priority", tip = "Whether a healthstone or a potion comes first." }
    local mana = MacroRow("mana", "NF Mana", "Your best mana potion, through NF Mana.")
    mana.needs, mana.why = ns.UsesMana, TEXT_NO_MANA
    local food = MacroRow("food", FOOD, "Your best food and drink in one macro, through NF Food.")
    food.cog = { title = "Food Only", tip = "Whether NF Food leaves drinks to NF Drink." }
    local drink = MacroRow("drink", "NF Drink", "Your best drink alone, through NF Drink.")
    drink.needs, drink.why = ns.UsesMana, TEXT_NO_MANA
    for _, row in ipairs({
        health,
        { label = "Use First", choice = { choices.values, choices.order }, under = HEALTH,
          help = "Whether a healthstone or a potion comes first.",
          get = function() return M.Get("healthOrder") end,
          set = function(v) M.Set("healthOrder", v) end },
        MacroRow("healthstone", "NF Healthstone", "Your best healthstone alone, through NF Healthstone."),
        MacroRow("healthPotion", "NF Health Potion", "Your best healing potion alone, through NF Health Potion."),
        mana,
        food,
        { label = "Food Only", toggle = true, under = FOOD,
          help = "NF Food uses only food, and NF Drink is the one for drink.",
          get = function() return M.Get("foodOnly") == true end,
          set = function(v) M.Set("foodOnly", v) end },
        drink,
        MacroRow("bandage", "NF Bandage", "Your best bandage on yourself, through NF Bandage."),
    }) do addingRows[#addingRows + 1] = row end
end

local page = Settings.Page("Consumable Bar/Settings", S)

page:Window({
    text = "Edit Items",
    open = OpenEditor,
    headline = Headline,
    detail = Detail,
})

page:Card({
    id = "bar", name = "Bar", order = 10,
    help = "How the bar looks and when it shows.",
    summary = BarSummary,
    studio = { height = StageHeight, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = barRows,
})

page:Card({
    id = "adding", name = "Adding Items", order = 20,
    help = "What the bar offers to add, and the Smart Macros that pick your best item.",
    watch = M and { M } or nil,
    rows = addingRows,
})

page:Card({
    id = "anchor", name = "Anchor", order = 30,
    help = "Attach the bar to a unit frame, or leave it where you drag it.",
    rows = Shared.Anchor.Rows(ANCHOR),
})

page:Card({
    id = "window", name = "Window", order = 40,
    help = "The Edit Items window.",
    rows = {
        { key = "consumableBarWindowAlpha", label = "Window Opacity", slider = St.OPACITY_RANGE,
          unit = "%", scale = PERCENT_SCALE, help = "How solid the window is." },
    },
})

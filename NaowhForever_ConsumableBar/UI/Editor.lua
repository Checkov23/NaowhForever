-- Editor.lua: Edit Items, the Consumable Bar's own window: the bar at its real size to add to, order and right-click, and an item's settings beside it.
local ns = _G.NaowhForever

local CB = ns.ConsumableBar
local S, C = CB.S, CB.C
local UI = ns.UI
local T = ns.THEME
local Shared = ns.Shared
local Parts, Settings, St, ItemBar = Shared.Parts, Shared.Settings, Shared.Style, Shared.ItemBar

local WIDTH = 620
local HEADER, FOOTER, PAD, INSET = St.WINDOW_HEADER, St.WINDOW_FOOTER, St.WINDOW_PAD, St.CONTENT_INSET
local CARD = 6
local BUTTON_W, BUTTON_H, BUTTON_GAP = 120, 24, 8
local HINT_FONT, HINT_TOP = 12, -8
local PLUS_FONT, PLUS_SHARE, PLUS_MIN = 24, 0.6, 10
local PREVIEW_TOP, PREVIEW_PAD = 30, 12
local PREVIEW_INSET = 10
local WHEEL_STEP = 40
local GHOST = 0.35
local DRAG_FADE = 0.4
local PERCENT = 100
local ITEM_PAGE = "Consumable Bar/Item"
local POSITION_KEY = "consumableBarWindow"
local TEXT_TITLE = ns.L("Consumable Bar")
local TEXT_SUBTITLE = ns.L("Add your consumables, put them in order, set each one up.")
local TEXT_HINT = ns.L("Drag items onto it or click +; drag an icon to move it; right-click for its settings.")
local TEXT_WIDE_HINT = ns.L("Scroll the mouse wheel to see the rest; right-click an icon for its settings.")
local TEXT_PLUS = "+"
local TEXT_ADD_TITLE = ns.L("Add Items")
local TEXT_ADD_TIP = ns.L("Consumables by item ID or name, or dragged from your bags.")
local TEXT_HIDDEN_COMBAT = ns.L("Hidden in combat")
local TEXT_HIDDEN_USED = ns.L("Hidden after use, out of combat")
local TEXT_RIGHT_CLICK = ns.L("Right-click for its settings")
local TEXT_RUNS = ns.L("Runs %s from Macros")
local TEXT_ONE_ITEM, TEXT_ITEMS = ns.L("1 item on the bar"), ns.L("%d items on the bar")
local TEXT_REMOVE = ns.L("Remove From Bar")
local TEXT_SAME_FONT = ns.L("Same as Count")
local BUTTONS = {
    { "Scan Bags", "ScanBags", ns.L("Adds the consumables in your bags that are not on the bar yet.") },
    { "Remove All", "Clear", ns.L("Takes every item off the bar, after asking.") },
}
local DEFAULTS = {
    combat = false, used = false, track = "buff", early = false, earlySeconds = C.EARLY_DEFAULT,
    textOn = false, text = "", textFont = "", textSize = C.CUSTOM_FONT, textColor = T.fg, textPoint = "TOP",
    textOutside = false, textX = 0, textY = 0,
}
local TRACK = { { buff = "Its Buff", mainhand = "Main Hand Enchant", offhand = "Off Hand Enchant" },
    { "buff", "mainhand", "offhand" } }
local POINT = { ItemBar.POINT_VALUES, ItemBar.POINT_ORDER }
local EARLY_RANGE = { 15, 1800, 15 }
local SIZE_RANGE = { 6, 40, 1 }
local OFFSET_RANGE = { -50, 50, 1 }

local window, preview, side, ghost
local selected, dragging

local function Opacity()
    return math.floor((S.Get("consumableBarWindowAlpha") or 1) * PERCENT + 0.5)
end

local function SetOpacity(value)
    S.Set("consumableBarWindowAlpha", value / PERCENT)
end

local function SideOpacity()
    return Opacity() / PERCENT
end

local function Drop(before)
    local entry = CB.EntryOf(GetCursorInfo())
    if entry == nil then return false end
    if type(entry) == "number" and not CB.Category(entry) then
        CB.SayNotConsumable({ CB.ItemName(entry) })
        return true
    end
    local why = CB.Blocked(entry)
    if why then
        ns.Print(why)
        return true
    end
    ClearCursor()
    if type(entry) == "number" then CB.AddAsked({ entry }, before) else CB.PlaceItem(entry, before) end
    return true
end

local OpenItem, Render

local function CellClick(cell, mouse)
    if Drop(not cell.isPlus and cell.entry or nil) then return end
    if cell.isPlus then CB.PromptAdd()
    elseif mouse == "RightButton" then OpenItem(cell) end
end

local function CellDrop(cell)
    Drop(not cell.isPlus and cell.entry or nil)
end

local function CellEnter(cell)
    GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
    if cell.isPlus then
        GameTooltip:SetText(TEXT_ADD_TITLE)
        GameTooltip:AddLine(TEXT_ADD_TIP, 1, 1, 1, true)
    else
        if cell.itemID then GameTooltip:SetItemByID(cell.itemID) else GameTooltip:SetText(CB.EntryName(cell.entry)) end
        local flags, a, m = CB.Flags(cell.entry), T.accent, T.muted
        local info = CB.MacroInfo(cell.entry)
        if info then GameTooltip:AddLine(TEXT_RUNS:format(info.name), a.r, a.g, a.b) end
        if flags.combat then GameTooltip:AddLine(TEXT_HIDDEN_COMBAT, a.r, a.g, a.b) end
        if flags.used then GameTooltip:AddLine(TEXT_HIDDEN_USED, a.r, a.g, a.b) end
        GameTooltip:AddLine(TEXT_RIGHT_CLICK, m.r, m.g, m.b)
    end
    GameTooltip:Show()
end

local function CellLeave()
    GameTooltip:Hide()
end

local function FollowCursor(self)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

local function Ghost()
    if ghost then return ghost end
    ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetFrameStrata("TOOLTIP")
    ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
    ghost.icon:SetAllPoints()
    ItemBar.CropIcon(ghost.icon)
    ghost:SetScript("OnUpdate", FollowCursor)
    ghost:Hide()
    return ghost
end

local function CellUnderCursor()
    local node = GetMouseFoci()[1]
    while node do
        if CB.Has(preview.cells, node) and node:IsShown() then return node end
        node = node:GetParent()
    end
end

local function CellDragStart(cell)
    if cell.isPlus or GetCursorInfo() then return end
    dragging = cell
    GameTooltip:Hide()
    local g = Ghost()
    g:SetSize(cell:GetWidth(), cell:GetHeight())
    g.icon:SetTexture(cell.icon:GetTexture())
    FollowCursor(g)
    g:Show()
    cell:SetAlpha(DRAG_FADE)
end

local function CellDragStop(cell)
    if dragging ~= cell then return end
    dragging = nil
    ghost:Hide()
    local target = CellUnderCursor()
    if target and target ~= cell then
        CB.MoveItem(cell.entry, not target.isPlus and target.entry or nil)
    else
        Render()
    end
end

local function Cell(i)
    local cell = preview.cells[i]
    if cell then return cell end
    cell = CB.NewCell(preview.bar)
    cell.plus = ns.Font(cell.overlay, PLUS_FONT, "OUTLINE", T.accent)
    cell.plus:SetPoint("CENTER")
    cell.plus:SetText(TEXT_PLUS)
    cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    cell:SetScript("OnClick", CellClick)
    cell:SetScript("OnReceiveDrag", CellDrop)
    cell:RegisterForDrag("LeftButton")
    cell:SetScript("OnDragStart", CellDragStart)
    cell:SetScript("OnDragStop", CellDragStop)
    cell:SetScript("OnEnter", CellEnter)
    cell:SetScript("OnLeave", CellLeave)
    preview.cells[i] = cell
    return cell
end

local function PreviewHeight()
    local size, gap, grow, perRow = CB.Grid()
    local _, h = ItemBar.Size(#CB.Items() + 1, size, gap, grow, perRow)
    return PREVIEW_TOP + h + 2 * C.BG_PAD + PREVIEW_PAD
end

local function DrawItems(items, size, gap, grow, perRow)
    local map = CB.KeyMap()
    for i, entry in ipairs(items) do
        local cell = Cell(i)
        cell.isPlus, cell.entry, cell.itemID = nil, entry, CB.Resolve(entry)
        ItemBar.Place(cell, preview.bar, i, size, gap, grow, perRow)
        CB.PlaceBackground(cell, i, #items, gap, grow, perRow)
        CB.StyleCell(cell, entry, size)
        CB.ShowCount(cell, cell.itemID, GHOST)
        CB.ShowCooldown(cell, cell.itemID)
        CB.ShowKey(cell, map)
        cell.plus:Hide()
        cell:Show()
    end
end

local function DrawPlus(index, size, gap, grow, perRow)
    local plus = Cell(index)
    plus.isPlus, plus.entry, plus.itemID, plus.empty = true, nil, nil, nil
    ItemBar.Place(plus, preview.bar, index, size, gap, grow, perRow)
    plus:SetSize(size, size)
    plus:SetAlpha(1)
    plus.icon:SetColorTexture(T.panel.r, T.panel.g, T.panel.b, 1)
    plus.icon:SetDesaturated(false)
    plus.count:Hide()
    plus.custom:Hide()
    plus.none:Hide()
    plus.key:Hide()
    plus.timer:Hide()
    plus.bg:Hide()
    plus.plus:SetFont(UI.FontPath(S.Get("consumableBarFont")), math.max(PLUS_MIN, math.floor(size * PLUS_SHARE)), "OUTLINE")
    plus.plus:Show()
    plus:Show()
end

local function Fit(count, size, gap, grow, perRow)
    local w, h = ItemBar.Size(count, size, gap, grow, perRow)
    preview.bar:SetSize(w, h)
    local viewW = preview.view:GetWidth() or 0
    local fullW = w + 2 * C.BG_PAD
    local wide = viewW > 0 and fullW > viewW
    preview.child:SetSize(math.max(fullW, viewW), h + 2 * C.BG_PAD)
    preview.bar:ClearAllPoints()
    preview.bar:SetPoint("CENTER", preview.child, "CENTER")
    preview.view:EnableMouseWheel(wide)
    if not wide then preview.view:SetHorizontalScroll(0) end
    preview.hint:SetText(wide and TEXT_WIDE_HINT or TEXT_HINT)
end

function Render()
    if not (window and window:IsShown()) then return end
    local items = CB.Items()
    local size, gap, grow, perRow = CB.Grid()
    DrawItems(items, size, gap, grow, perRow)
    DrawPlus(#items + 1, size, gap, grow, perRow)
    for i = #items + 2, #preview.cells do preview.cells[i]:Hide() end
    Fit(#items + 1, size, gap, grow, perRow)
    preview:SetHeight(PreviewHeight())
    window:SetHeight(HEADER + CARD + PAD + PreviewHeight() + PAD + BUTTON_H + PAD + FOOTER + CARD)
    window.note.text:SetText(#items == 1 and TEXT_ONE_ITEM or TEXT_ITEMS:format(#items))
    window.note:SetWidth(math.max(1, math.ceil(window.note.text:GetStringWidth())))
    window.backdrop:Paint(Opacity() / PERCENT)
    window.opacity._refreshValue()
end

local function BoxDrop()
    Drop()
end

local function Wheel(self, delta)
    local range = self:GetHorizontalScrollRange() or 0
    self:SetHorizontalScroll(math.max(0, math.min(range, (self:GetHorizontalScroll() or 0) - delta * WHEEL_STEP)))
end

local function NewPreview(parent)
    local box = CreateFrame("Frame", nil, parent)
    box.hint = ns.Font(box, HINT_FONT, nil, T.muted)
    box.hint:SetPoint("TOPLEFT", PREVIEW_INSET, HINT_TOP)
    box:EnableMouse(true)
    box:SetScript("OnReceiveDrag", BoxDrop)
    box:SetScript("OnMouseUp", BoxDrop)
    box.view = CreateFrame("ScrollFrame", nil, box)
    box.view:SetPoint("TOPLEFT", PREVIEW_INSET, -PREVIEW_TOP)
    box.view:SetPoint("BOTTOMRIGHT", -PREVIEW_INSET, PREVIEW_PAD - C.BG_PAD)
    box.child = CreateFrame("Frame", nil, box.view)
    box.view:SetScrollChild(box.child)
    box.view:SetScript("OnMouseWheel", Wheel)
    box.view:SetScript("OnSizeChanged", Render)
    box.bar = CreateFrame("Frame", nil, box.child)
    box.cells = {}
    return box
end

local itemStore = {
    Get = function(key)
        local f = CB.Flags(selected)
        if key == "textOn" then return CB.CustomOn(f) end
        local v = f[key]
        if v == nil then return DEFAULTS[key] end
        return v
    end,
    Set = function(key, value) CB.SetFlag(selected, key, value) end,
    Raw = function(key) return CB.Flags(selected)[key] end,
    Default = function(key) return DEFAULTS[key] end,
    OnChange = function(fn) CB.OnChange(fn) end,
}

local function Uses() return itemStore.Get("used") == true end
local function NotUsed() return not Uses() end
local function NotEarly() return not (Uses() and itemStore.Get("early")) end
local function NoText() return not itemStore.Get("textOn") end

local function NoEffect()
    local item = selected and CB.Resolve(selected)
    return not (item and CB.ItemSpell(item))
end

local function TextFonts()
    local values, order = UI.FontChoices(itemStore.Get("textFont"))
    values[""] = TEXT_SAME_FONT
    return values, order
end

local function SelectedKey()
    return CB.BindAction(selected)
end

local itemCard = Settings.Page(ITEM_PAGE, itemStore):Card({
    id = "item", name = "Item",
    help = "This item's own settings on the bar.",
    rows = {
        { label = "Key", binding = SelectedKey, help = "A key that uses this item." },
        { key = "combat", label = "Hide in Combat", toggle = true, help = "Hides it while you fight." },
        { key = "used", label = "Hide After Use", toggle = true, hidden = NoEffect,
          help = "Hides it while its effect is on you, out of combat." },
        { key = "track", label = "Tracks", choice = TRACK, hidden = NotUsed,
          help = "What it puts on you: a buff, or an enchant on a weapon." },
        { key = "early", label = "Show Before It Ends", toggle = true, hidden = NotUsed,
          help = "Shows it again a little before its effect runs out." },
        { key = "earlySeconds", label = "Show With", slider = EARLY_RANGE, unit = " s", hidden = NotEarly,
          help = "How long before the effect runs out it shows again." },
        Settings.Group("Its Own Text"),
        { key = "textOn", label = "Custom Text", toggle = true, help = "A word of your own on the icon." },
        { key = "text", label = "Text", text = true, hidden = NoText, help = "The word itself." },
        { key = "textFont", label = "Font", choice = TextFonts, hidden = NoText },
        { key = "textSize", label = "Font Size", slider = SIZE_RANGE, hidden = NoText },
        { key = "textColor", label = "Color", colour = true, hidden = NoText },
        { key = "textPoint", label = "Position", choice = POINT, hidden = NoText },
        { key = "textOutside", label = "Outside the Icon", toggle = true, hidden = NoText,
          help = "Puts the text just past the icon's edge." },
        { key = "textX", label = "X Offset", slider = OFFSET_RANGE, hidden = NoText },
        { key = "textY", label = "Y Offset", slider = OFFSET_RANGE, hidden = NoText },
    },
})

local function SideView(scroll)
    local holder = CreateFrame("Frame", nil, scroll)
    holder:SetHeight(1)
    return holder
end

local function DrawSide()
    if not (side and side:IsShown() and selected) then return end
    itemCard.name = CB.EntryName(selected)
    local holder = side.view
    holder:SetWidth(side.view:GetWidth())
    holder:SetHeight(Settings.Render(holder, ITEM_PAGE, function(h) holder:SetHeight(h + UI.CONTENT_PAD) end))
end

local function RemoveSelected()
    local entry = selected
    side:Hide()
    if entry then CB.RemoveItem(entry) end
end

function OpenItem(cell)
    if not side then side = Parts.SidePanel({ { TEXT_REMOVE, RemoveSelected } }, SideView, SideOpacity) end
    selected = cell.entry
    Parts.ShowBeside(side, cell)
    DrawSide()
end

local function Build()
    window = Parts.Window(WIDTH, HEADER + CARD + FOOTER + CARD, POSITION_KEY)
    window.backdrop:Card(CARD, HEADER + CARD, CARD, FOOTER + CARD)
    local close = Parts.TitleBar(window, TEXT_TITLE, TEXT_SUBTITLE, CB.PAGE)
    local _, opacity = Parts.Opacity(window, close, Opacity, SetOpacity)
    window.opacity = opacity
    Parts.FooterBrand(window, CB.PAGE)
    window.note = Parts.FooterNote(window, "")
    local left = CARD + INSET
    preview = NewPreview(window)
    preview:SetPoint("TOPLEFT", left, -(HEADER + CARD + PAD))
    preview:SetPoint("TOPRIGHT", -left, -(HEADER + CARD + PAD))
    local x = left
    for _, spec in ipairs(BUTTONS) do
        local button = ns.Button(window, spec[1], BUTTON_W, BUTTON_H, CB[spec[2]])
        button:SetPoint("BOTTOMLEFT", x, FOOTER + CARD + PAD)
        ns.Tooltip(button, spec[1], spec[3])
        x = x + BUTTON_W + BUTTON_GAP
    end
    window:Hide()
end

local function OnBarChanged()
    Render()
    if side and side:IsShown() and not CB.Has(CB.Items(), selected) then side:Hide() end
end

CB.OnChange(OnBarChanged)

function CB.OpenEditor()
    if not window then Build() end
    window:Show()
    window:Raise()
    Render()
end
ns.OpenConsumableBarEditor = CB.OpenEditor

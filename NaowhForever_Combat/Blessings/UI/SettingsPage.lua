-- SettingsPage.lua: the Blessings settings page, declared as cards, with a preview that edits the bar.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local St = ns.Shared.Style
local ItemBar = ns.Shared.ItemBar
local Parts = ns.Shared.Parts
local B = ns.Blessings
local Look = B.Look

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end
local Group = Settings.Group

local BLESSINGS_OFF = ns.L("Turn on Blessings")
local LABELS_OFF = ns.L("Turn on Blessings and Class Labels")
local BORDERS = { values = { black = ns.L("Black"), accent = ns.L("Accent"), none = ns.L("None") },
    order = { "black", "accent", "none" } }
local OPACITY_RANGE, WINDOW_RANGE = { 10, 100, 5 }, { 60, 150, 5 }
local WHY_BACKGROUND = ns.L("Pick a background texture")
local LABEL_STYLES = { values = { name = ns.L("Name"), icon = "Class Icon" }, order = { "name", "icon" } }
local STAGE_H, STAGE_MARGIN, LABEL_ROOM, LABEL_SIDE = 160, St.STAGE_MARGIN, 14, 46
local NOTE_Y, NOTE_SIZE, NOTE_LINE = St.STAGE_NOTE_Y, St.STAGE_NOTE_SIZE, 15
local TEXT_ROOM = NOTE_Y + NOTE_LINE * 2
local REMOVE_SIZE, REMOVE_ICON, REMOVE_INSET = 12, 8, 3
local PLUS_ICON, PLUS_BG_ALPHA = 12, 0.6
local GRIP_MIN, GRIP_LINE = 6, 2
local EDIT_LEVEL = 10
local BLACK = St.BORDER_RGB
local ROUND = B.ROUND
local ICON_DROP, ICON_SIDE = 2, 3
local SIZE_SLIDER, SPACING_SLIDER, GROUP_SLIDER = { 20, 70, 1 }, { 0, 30, 1 }, { 0, 40, 1 }
local FONT_SLIDER = St.HUD_TEXT_RANGE
local ORDER_BAR, ORDER_ANCHOR = 10, 15
local AURA_LABEL, FURY_LABEL, GROUP_LABEL = ns.L("Aura Button"), ns.L("Righteous Fury Button"), "Aura / Class Gap"
local HINT = ns.L("Right-click a class for its blessing. Wheel: size, Shift-wheel: spacing. x hides a button.")
local HINT_OFF = ns.L("Turn on Blessings to edit the bar here.")
local ADD_TITLE = ns.L("Add a Button")
local ADD_AURA, ADD_FURY, ADD_BOTH = ns.L("Brings back the Aura button."), ns.L("Brings back the Righteous Fury button."),
    ns.L("Choose which button to bring back.")
local GAP_TIP = ns.L("Drag left or right to change the gap between your aura and the class buttons.")
local GAP_TIP_VERTICAL = ns.L("Drag up or down to change the gap between your aura and the class buttons.")
local LAYOUT = ns.Shared.ItemBar.GrowChoice("horizontal", "vertical")
local ANCHOR = { store = S, prefix = "bless", name = "Blessing Bar", frame = B.BarFrame,
    on = function() return S.Get("blessings") == true and B.IsPaladin() end }
local NO_BAR = ns.L("Turn on Blessings on a paladin")
local AURA_HERE = ns.L("Here: click to choose your aura. Its x hides the button.")
local SELF_HERE = ns.L("Here: its x hides the button.")
local CLASS_TIP = ns.L("On the bar, left-click blesses the next %s who needs it, missing first, skipping anyone "
    .. "dead or out of range.")
local CLASS_HERE = ns.L("Here: right-click to choose its blessing.")
local STATES = {
    { key = "group", label = "In a Group", tip = "Your group in range: who is missing a blessing, who is running out, "
        .. "and who only needs their own." },
    { key = "range", label = "Out of Range", tip = "Nobody of a class you can reach: dead, offline or too far away." },
}
local SAMPLE = {
    { class = "WARRIOR", blessing = "might", colour = Look.RED, missing = 2, far = true },
    { class = "PRIEST", blessing = "wisdom", colour = Look.YELLOW, missing = 0, left = 4 * 60 },
    { class = "ROGUE", blessing = "might", colour = Look.BLUE, missing = 1, far = true },
    { class = "MAGE", blessing = "wisdom", missing = 0, left = 12 * 60 },
}
local NOTES = {
    group = ns.L("Red: missing the class blessing. Yellow: running out. Blue: only players with their own."),
    range = ns.L("Grey: nobody of that class in range. The number still counts who is missing it."),
}
local THEMED_GROUP = ns.L("Accent: missing the class blessing. Lighter: running out. Deeper: only players with their own.")
local NONE = "none"
local WHY_THEMED = ns.L("Turn off Apply Theme to Status Colors")
local TEXT_NONE = ns.L("None")
local TEXT_CLASS_HELP = ns.L("Which blessing you give this class: Might, Wisdom, Kings or Light.")
local TEXT_SALV_HELP = ns.L("Gives Salvation, on top of the class blessing, to everyone but tanks.")
local TEXT_SALV_GIVE = ns.L("Everyone but tanks")
local SALV_GIVE = "give"
local TEXT_CLASS_SEARCH = ns.L("blessing blessings greater")

local function On() return S.Get("blessings") == true end
local function OpenWindow() ns.OpenBlessingsWindow() end
local function LabelsOn() return On() and S.Get("blessShowLabels") == true end
local function NotPaladin() return not B.IsPaladin() end
local function HasBar() return ANCHOR.on() and B.BarFrame() ~= nil end

local function BlessingChoices(class)
    local values, order = { [NONE] = TEXT_NONE }, {}
    local current = B.Store().classes[class]
    for _, entry in ipairs(B.BLESSINGS) do
        if entry.key == current or (B.Learned(entry) and B.Allowed(class, entry.key)) then
            values[entry.key] = B.SpellName(entry.key)
            order[#order + 1] = entry.key
        end
    end
    order[#order + 1] = NONE
    return values, order
end

local function ClassRow(class)
    return { label = B.ClassName(class), help = TEXT_CLASS_HELP, search = TEXT_CLASS_SEARCH, needs = On, why = BLESSINGS_OFF,
        hidden = NotPaladin,
        choice = function() return BlessingChoices(class) end,
        get = function() return B.Store().classes[class] or NONE end,
        set = function(key) B.SetOwn(class, key ~= NONE and key or nil) end }
end

local function SalvationRow()
    return { label = B.SpellName(B.SALVATION.key), help = TEXT_SALV_HELP, search = TEXT_CLASS_SEARCH, needs = On,
        why = BLESSINGS_OFF, hidden = function() return NotPaladin() or not B.Learned(B.SALVATION) end,
        choice = function() return { [NONE] = TEXT_NONE, [SALV_GIVE] = TEXT_SALV_GIVE }, { SALV_GIVE, NONE } end,
        get = function() return B.Store().salv and SALV_GIVE or NONE end,
        set = function(key) B.SetOwn(B.SALV_COLUMN, key == SALV_GIVE and B.SALVATION.key or nil) end }
end

local function ClassRows()
    local header = Group("Blessings by Class")
    header.hidden = NotPaladin
    local rows = { header }
    for _, class in ipairs(B.CLASSES) do rows[#rows + 1] = ClassRow(class) end
    rows[#rows + 1] = SalvationRow()
    return rows
end

local function RoleChoices()
    local values, order = { [NONE] = TEXT_NONE }, {}
    for _, entry in ipairs(B.BLESSINGS) do
        if B.Learned(entry) then
            values[entry.key] = B.SpellName(entry.key)
            order[#order + 1] = entry.key
        end
    end
    order[#order + 1] = NONE
    return values, order
end

local function RoleRow(key, label, help)
    return { label = label, help = help, search = TEXT_CLASS_SEARCH, needs = On, why = BLESSINGS_OFF,
        hidden = NotPaladin, choice = RoleChoices,
        get = function() return S.Get(key) end, set = function(value) S.Set(key, value) end }
end

local function CustomColors() return On() and not S.Get("blessThemeColors") end
local function Backdropped() return On() and S.Get("blessBackground") ~= NONE end

local function BackgroundChoices()
    local values, order = { [NONE] = TEXT_NONE }, { NONE }
    local LSM = LibStub("LibSharedMedia-3.0", true)
    for _, name in ipairs(LSM and LSM:List("statusbar") or {}) do
        values[name] = name
        order[#order + 1] = name
    end
    return values, order
end

local function Wheel(_, delta)
    if not On() then return end
    local key, range = "blessBarSize", SIZE_SLIDER
    if IsShiftKeyDown() then key, range = "blessSpacing", SPACING_SLIDER end
    local value = S.Get(key) + (delta > 0 and range[3] or -range[3])
    value = math.min(range[2], math.max(range[1], value))
    if value ~= S.Get(key) then S.Set(key, value) end
end

local function SelfEnter(button)
    local preview = button.preview
    if not preview.editable or preview.grip.dragging then return end
    local x = preview.remove
    x.owner = button
    x:ClearAllPoints()
    x:SetPoint("CENTER", button, "TOPRIGHT", -REMOVE_INSET, -REMOVE_INSET)
    x:Show()
end

local function SelfLeave(button)
    local x = button.preview.remove
    if x.owner == button and not x:IsMouseOver() then x:Hide() end
end

local function SelfClick(button)
    if button.preview.editable and button.menu then button.menu(button) end
end

local function ClassClick(cell, mouse)
    local preview = cell.preview
    if mouse == "RightButton" and preview.editable and preview.paladin then B.ClassMenu(cell, cell.class, true) end
end

local function RemoveEnter(x)
    x.icon:SetVertexColor(T.accent.r, T.accent.g, T.accent.b)
end

local function RemoveLeave(x)
    x.icon:SetVertexColor(T.fg.r, T.fg.g, T.fg.b)
    if not (x.owner and x.owner:IsMouseOver()) then x:Hide() end
end

local function RemoveClick(x)
    x:Hide()
    if x.owner then S.Set(x.owner.setting, false) end
end

local function ShowAura() S.Set("blessShowAura", true) end
local function ShowFury() S.Set("blessShowFury", true) end

local function AddMenu(_, root)
    root:CreateTitle(ADD_TITLE)
    root:CreateButton(AURA_LABEL, ShowAura)
    root:CreateButton(FURY_LABEL, ShowFury)
end

local function PlusClick(plus)
    local aura, fury = S.Get("blessShowAura"), S.Get("blessShowFury")
    if not (aura or fury) then
        if ns.UI.HideWidgetTooltip then ns.UI.HideWidgetTooltip() end
        MenuUtil.CreateContextMenu(plus, AddMenu)
    elseif not aura then
        ShowAura()
    elseif not fury then
        ShowFury()
    end
end

local function PlusEnter(plus)
    plus.icon:SetVertexColor(T.accent.r, T.accent.g, T.accent.b)
end

local function PlusLeave(plus)
    plus.icon:SetVertexColor(T.muted.r, T.muted.g, T.muted.b)
end

local function GripUpdate(grip)
    local cursorX, cursorY = GetCursorPosition()
    local moved = (grip.vertical and (grip.fromY - cursorY) or (cursorX - grip.fromX)) * grip.sign
    local value = grip.from + math.floor(moved / grip.scale + ROUND)
    value = math.min(GROUP_SLIDER[2], math.max(GROUP_SLIDER[1], value))
    if value ~= S.Get("blessGroupSpacing") then S.Set("blessGroupSpacing", value) end
end

local function GripEnter(grip)
    if grip.preview.editable then grip.line:Show() end
end

local function GripLeave(grip)
    if not grip.dragging then grip.line:Hide() end
end

local function GripDown(grip, mouse)
    if mouse ~= "LeftButton" or not grip.preview.editable then return end
    grip.fromX, grip.fromY = GetCursorPosition()
    grip.scale, grip.from = grip:GetEffectiveScale(), S.Get("blessGroupSpacing")
    grip.vertical = Look.vertical
    grip.sign = (Look.grow == "LEFT" or Look.grow == "UP") and -1 or 1
    grip.dragging = true
    grip.preview.remove:Hide()
    grip.line:Show()
    grip:SetScript("OnUpdate", GripUpdate)
end

local function GripStop(grip)
    if not grip.dragging then return end
    grip.dragging = nil
    grip:SetScript("OnUpdate", nil)
    grip.line:SetShown(grip:IsMouseOver())
end

local function GripUp(grip, mouse)
    if mouse == "LeftButton" then GripStop(grip) end
end

local function GripHidden(grip)
    GripStop(grip)
    grip.line:Hide()
end

local function NewButton(preview, onClick)
    local button = CreateFrame("Button", nil, preview.bar)
    button.preview = preview
    Look.Icon(button)
    Parts.Hover(button)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", onClick)
    button:SetScript("OnMouseWheel", Wheel)
    preview.wheels[#preview.wheels + 1] = button
    return button
end

local function NewSelf(preview, setting, title, tip, here)
    local button = NewButton(preview, SelfClick)
    button.setting, button.title = setting, title
    button.tipOn = tip .. "\n\n" .. ns.Color("muted", here)
    button.tipOff = tip .. "\n\n" .. ns.Color("muted", HINT_OFF)
    button:SetScript("OnEnter", SelfEnter)
    button:SetScript("OnLeave", SelfLeave)
    return button
end

local function NewClass(preview, class)
    local cell = NewButton(preview, ClassClick)
    cell.class, cell.title = class, B.ClassName(class)
    Look.Label(cell, class)
    local tip = CLASS_TIP:format(cell.title)
    cell.tipOn = preview.paladin and (tip .. "\n\n" .. ns.Color("muted", CLASS_HERE)) or tip
    cell.tipOff = tip .. "\n\n" .. ns.Color("muted", HINT_OFF)
    return cell
end

local function NewPlus(preview)
    local plus = CreateFrame("Button", nil, preview.bar)
    plus.preview = preview
    ns.Solid(plus, "BACKGROUND", T.bg, PLUS_BG_ALPHA):SetAllPoints()
    ns.Border(plus, BLACK)
    plus.icon = plus:CreateTexture(nil, "ARTWORK")
    plus.icon:SetTexture(St.PLUS)
    plus.icon:SetSize(PLUS_ICON, PLUS_ICON)
    plus.icon:SetPoint("CENTER")
    PlusLeave(plus)
    Parts.Hover(plus)
    plus:SetScript("OnEnter", PlusEnter)
    plus:SetScript("OnLeave", PlusLeave)
    plus:SetScript("OnClick", PlusClick)
    plus:SetScript("OnMouseWheel", Wheel)
    preview.wheels[#preview.wheels + 1] = plus
    return plus
end

local function NewRemove(preview)
    local x = CreateFrame("Button", nil, preview)
    x:SetFrameLevel(preview:GetFrameLevel() + EDIT_LEVEL)
    x:SetSize(REMOVE_SIZE, REMOVE_SIZE)
    ns.Solid(x, "BACKGROUND", T.bg, 1):SetAllPoints()
    ns.Border(x, BLACK)
    x.icon = x:CreateTexture(nil, "ARTWORK")
    x.icon:SetTexture(St.CROSS)
    x.icon:SetSize(REMOVE_ICON, REMOVE_ICON)
    x.icon:SetPoint("CENTER")
    RemoveLeave(x)
    x:SetScript("OnEnter", RemoveEnter)
    x:SetScript("OnLeave", RemoveLeave)
    x:SetScript("OnClick", RemoveClick)
    x:Hide()
    return x
end

local function NewGrip(preview)
    local grip = CreateFrame("Frame", nil, preview.bar)
    grip.preview = preview
    grip:SetFrameLevel(preview.bar:GetFrameLevel())
    grip.line = ns.Solid(grip, "OVERLAY", T.accent, 1)
    grip.line:SetPoint("TOP")
    grip.line:SetPoint("BOTTOM")
    grip.line:SetWidth(GRIP_LINE)
    grip.line:Hide()
    grip:EnableMouse(true)
    grip:SetScript("OnEnter", GripEnter)
    grip:SetScript("OnLeave", GripLeave)
    grip:SetScript("OnMouseDown", GripDown)
    grip:SetScript("OnMouseUp", GripUp)
    grip:SetScript("OnHide", GripHidden)
    grip:SetScript("OnMouseWheel", Wheel)
    ns.Tooltip(grip, GROUP_LABEL, GAP_TIP)
    preview.wheels[#preview.wheels + 1] = grip
    return grip
end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.paladin = B.IsPaladin()
    preview.bar = CreateFrame("Frame", nil, preview)
    preview.bar:SetScript("OnMouseWheel", Wheel)
    preview.wheels = { preview.bar }
    preview.grip = NewGrip(preview)
    preview.plus = NewPlus(preview)
    preview.aura = NewSelf(preview, "blessShowAura", "Aura", B.AURA_TIP, preview.paladin and AURA_HERE or SELF_HERE)
    preview.aura.menu = preview.paladin and B.AuraMenu or nil
    preview.fury = NewSelf(preview, "blessShowFury", B.FuryName(), B.FURY_TIP, SELF_HERE)
    preview.cells = {}
    for i, sample in ipairs(SAMPLE) do preview.cells[i] = NewClass(preview, sample.class) end
    preview.remove = NewRemove(preview)
    preview.note = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.note:SetPoint("BOTTOM", 0, NOTE_Y + NOTE_LINE)
    preview.hint = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.hint:SetPoint("BOTTOM", 0, NOTE_Y)
    return preview
end

local function Fit(preview)
    local bar = preview.bar
    local labels, icon = Look.labels, Look.icons and Look.IconSize()
    local below = labels and not Look.vertical and (icon and icon + ICON_DROP or LABEL_ROOM) or 0
    local side = labels and Look.vertical and (icon and icon + ICON_SIDE or LABEL_SIDE) or 0
    local w, h = bar:GetWidth() + side, bar:GetHeight() + below
    local roomW = preview:GetWidth() - STAGE_MARGIN * 2
    local roomH = preview:GetHeight() - STAGE_MARGIN * 2 - TEXT_ROOM
    local scale = 1
    if roomW > 0 and w > roomW then scale = roomW / w end
    if roomH > 0 and h * scale > roomH then scale = roomH / h end
    bar:SetScale(scale)
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", preview, "CENTER", -side / 2 / scale, (TEXT_ROOM / 2 + below / 2) / scale)
end

local function Tip(button, editable)
    ns.Tooltip(button, button.title, editable and button.tipOn or button.tipOff)
end

local function PaintSelf(button, shown, key, missing, x, bar, editable)
    if not shown then
        button:Hide()
        return x
    end
    button.icon:SetTexture(B.SpellIcon(key))
    Look.Self(button, missing)
    Tip(button, editable)
    return Look.Place(button, bar, x)
end

local function PlaceGrip(grip, shown, x, bar)
    grip:SetShown(shown)
    if not shown then return end
    local span = Look.gap + Look.groupGap
    local width = math.max(GRIP_MIN, span)
    local at = x - Look.gap - (width - span) / 2
    local line = grip.line
    line:ClearAllPoints()
    Look.Pin(grip, bar, at)
    if Look.vertical then
        grip:SetSize(Look.size, width)
        line:SetPoint("LEFT")
        line:SetPoint("RIGHT")
        line:SetHeight(GRIP_LINE)
    else
        grip:SetSize(width, Look.size)
        line:SetPoint("TOP")
        line:SetPoint("BOTTOM")
        line:SetWidth(GRIP_LINE)
    end
    ns.Tooltip(grip, GROUP_LABEL, Look.vertical and GAP_TIP_VERTICAL or GAP_TIP)
end

local function PaintPreview(preview, state)
    Look.Read()
    local editable = On()
    preview.editable = editable
    local bar, plus = preview.bar, preview.plus
    local showAura, showFury = S.Get("blessShowAura"), S.Get("blessShowFury")
    local x = 0
    local adding = editable and not (showAura and showFury)
    plus:SetShown(adding)
    if adding then
        plus:SetSize(Look.size, Look.size)
        Look.Pin(plus, bar, 0)
        x = Look.size + Look.gap
        ns.Tooltip(plus, ADD_TITLE, showAura and ADD_FURY or showFury and ADD_AURA or ADD_BOTH)
    end
    local start = x
    x = PaintSelf(preview.aura, showAura, preview.paladin and B.CurrentAura() or "devotion", false, x, bar, editable)
    x = PaintSelf(preview.fury, showFury, "fury", true, x, bar, editable)
    PlaceGrip(preview.grip, editable and x > start, x, bar)
    if x > start then x = Look.Gap(x) end
    local classes = preview.paladin and B.Store().classes
    for i, sample in ipairs(SAMPLE) do
        local cell = preview.cells[i]
        local gone = state == "range" and sample.far
        local key = sample.blessing
        if classes then key = classes[sample.class] end
        cell.icon:SetTexture(B.SpellIcon(key))
        Look.Class(cell, not gone and sample.colour or nil, not gone, sample.missing, sample.left)
        Tip(cell, editable)
        x = Look.Place(cell, bar, x)
    end
    Look.Fit(bar, x)
    Fit(preview)
    preview.note:SetText(state == "group" and S.Get("blessThemeColors") and THEMED_GROUP or NOTES[state])
    preview.hint:SetText(editable and HINT or HINT_OFF)
    local wheels = preview.wheels
    for i = 1, #wheels do wheels[i]:EnableMouseWheel(editable) end
    local remove = preview.remove
    if not (editable and remove.owner and remove.owner:IsShown()) then remove:Hide() end
end

local function BarSummary(store)
    return (ns.L("%d px buttons%s%s%s")):format(store.Get("blessBarSize"),
        ItemBar.Vertical(ItemBar.GrowOf(store.Get("blessLayout"))) and ns.L(", vertical") or "",
        store.Get("blessShowAura") and ns.L(", aura") or "", store.Get("blessTimers") and ns.L(", minutes left") or "")
end

if B.OLD_COPY then return end

local page = Settings.Page(B.PAGE, S)

page:Window({
    text = "Open Blessings",
    open = OpenWindow,
    headline = B.Headline,
    detail = B.Detail,
})

page:Card({
    id = "bar", name = "Blessing Bar", order = ORDER_BAR,
    help = "For paladins, a button per class in your group. Left-click blesses the next member of that class "
        .. "who needs it, missing first, skipping anyone dead or out of range. Right-click a class to choose "
        .. "its blessing or open its player list. Move it in the HUD Editor. The preview edits it: right-click a "
        .. "class for its blessing, click the aura to choose it, wheel for size and Shift-wheel for spacing, drag "
        .. "the gap after the aura, x hides a button and + brings it back.",
    summary = BarSummary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        Group("Buttons"),
        { key = "blessShowAura", label = AURA_LABEL, toggle = true, needs = On, why = BLESSINGS_OFF,
          help = "Casts your aura. Right-click it to choose which." },
        { key = "blessShowFury", label = FURY_LABEL, toggle = true, needs = On, why = BLESSINGS_OFF,
          help = "Casts Righteous Fury on yourself. A red ! means it is not up." },
        { key = "blessShowAuto", label = "Auto Buff Button", toggle = true, needs = On, why = BLESSINGS_OFF,
          help = "Left-click blesses the next player in need, right-click the next Greater Blessing." },
        { key = "blessShowSeal", label = "Seal Button", toggle = true, needs = On, why = BLESSINGS_OFF,
          help = "Casts your seal. Right-click it to choose which, wheel to cycle." },
        { key = "blessAutoGreater", label = "Auto Buff Greater First", toggle = true, needs = On, why = BLESSINGS_OFF,
          help = "Swaps the Auto Buff button: left-click casts a Greater Blessing, right-click a single one." },
        { key = "blessPlayerList", label = "Player List", toggle = true, needs = On, why = BLESSINGS_OFF,
          help = "Off removes the class buttons' player list." },
        { key = "blessTooltips", label = "Show Tooltips", toggle = true, needs = On, why = BLESSINGS_OFF,
          help = "A tooltip on each bar button." },
        { key = "blessShowClasses", label = "Class Buttons", toggle = true, needs = On, why = BLESSINGS_OFF,
          help = "Off leaves only the Auto Buff button and the key bindings." },
        { key = "blessShowLabels", label = "Class Labels", toggle = true, needs = On, why = BLESSINGS_OFF,
          help = "Each class's name or icon, under its button or beside it when the bar is vertical." },
        { key = "blessLabelStyle", label = "Class Label Style", choice = LABEL_STYLES, needs = LabelsOn,
          why = LABELS_OFF, help = "The class's name, or its class icon, which fits however small the buttons are." },
        { key = "blessTimers", label = "Minutes Left", toggle = true, needs = On, why = BLESSINGS_OFF,
          help = "Minutes left on each class's shortest blessing, and on each player's." },
        ClassRows(),
        Group("Rules"),
        { key = "blessSmart", label = "Smart Blessings", toggle = true, needs = On, why = BLESSINGS_OFF,
          help = "No Wisdom for warriors and rogues, no Might for priests, mages and warlocks in the menus." },
        { key = "blessRespect", label = "Respect Blessing Time", toggle = true, needs = On, why = BLESSINGS_OFF,
          help = "Only bless players who are missing a blessing or running out." },
        { key = "blessWait", label = "Wait for Players", toggle = true, needs = On, why = BLESSINGS_OFF,
          help = "Cast a Greater Blessing only when the whole class is in range." },
        RoleRow("blessTank", "Tanks Get", "The blessing tanks get instead of their class blessing."),
        RoleRow("blessAssist", "Main Assist Gets", "The blessing a Main Assist gets instead of their class blessing."),
        Group("Visibility"),
        { key = "blessInParty", label = "Use in Party", toggle = true, needs = On, why = BLESSINGS_OFF,
          help = "Show the bar in a party. It always shows in a raid." },
        { key = "blessSolo", label = "Use When Solo", toggle = true, needs = On, why = BLESSINGS_OFF,
          help = "Show the bar when you are not in a group." },
        { key = "blessBench", label = "Hide the Bench", toggle = true, needs = On, why = BLESSINGS_OFF,
          help = "In a raid dungeon, hide the players outside its usual groups." },
        Group("Size"),
        { key = "blessBarSize", label = "Button Size", slider = SIZE_SLIDER, needs = On, why = BLESSINGS_OFF,
          help = "How big each button is." },
        { key = "blessSpacing", label = "Button Spacing", slider = SPACING_SLIDER, needs = On, why = BLESSINGS_OFF,
          help = "The gap between two buttons." },
        { key = "blessGroupSpacing", label = GROUP_LABEL, slider = GROUP_SLIDER, needs = On,
          why = BLESSINGS_OFF, help = "The extra gap between your aura and Righteous Fury and the class buttons." },
        Settings.Look("bless", { text = true, size = FONT_SLIDER, keys = { FontSize = "blessTimerSize" }, needs = On,
            why = BLESSINGS_OFF }),
        Group("Colors"),
        { key = "blessThemeColors", label = "Apply Theme to Status Colors", toggle = true, needs = On,
          why = BLESSINGS_OFF, help = "Missing, running out and other blessings in your theme's Accent shades." },
        { key = "blessColorMissing", label = "Missing Color", colour = true, needs = CustomColors, why = WHY_THEMED,
          help = "A class button when someone is missing the class blessing." },
        { key = "blessColorExpiring", label = "Running Out Color", colour = true, needs = CustomColors,
          why = WHY_THEMED, help = "A class button when a blessing is running out." },
        { key = "blessColorOwn", label = "Own Blessing Color", colour = true, needs = CustomColors, why = WHY_THEMED,
          help = "A class button when only players on their own blessing need theirs." },
        Group("Look"),
        { key = "blessBorder", label = "Button Border", choice = BORDERS, needs = On, why = BLESSINGS_OFF,
          help = "The edge of every button." },
        { label = "Bar Background", choice = BackgroundChoices, needs = On, why = BLESSINGS_OFF,
          help = "A texture behind the whole bar.",
          get = function() return S.Get("blessBackground") end,
          set = function(value) S.Set("blessBackground", value) end },
        { key = "blessBackgroundAlpha", label = "Background Opacity", slider = OPACITY_RANGE, unit = "%",
          scale = St.PERCENT_SCALE, needs = Backdropped, why = WHY_BACKGROUND,
          help = "How solid the bar's background is." },
        { key = "blessWindowScale", label = "Window Size", slider = WINDOW_RANGE, unit = "%",
          scale = St.PERCENT_SCALE, needs = On, why = BLESSINGS_OFF,
          help = "The size of the Blessings window. Dragging its corner changes it too." },
        Group("Key Bindings"),
        { label = "Next Blessing", binding = "CLICK NaowhForeverBlessNext:LeftButton",
          help = "Blesses the next player who needs it, most urgent first. In combat each press steps through "
              .. "the players who needed it when the fight began." },
        { label = "Next Greater Blessing", binding = "CLICK NaowhForeverBlessNextGreater:LeftButton",
          help = "The same with a Greater Blessing, for a class that shares one blessing, while you carry "
              .. "Symbols of Kings." },
    },
})

local function AnchorRows()
    local rows = ns.Shared.Anchor.Rows(ANCHOR)
    table.insert(rows, 1, { key = "blessLayout", label = "Growth Direction", choice = LAYOUT, needs = On,
        why = BLESSINGS_OFF, help = "Which way the bar grows from its first button. A column puts the class labels "
            .. "beside the buttons." })
    rows[#rows + 1] = { label = "Reset Position", button = B.ResetPosition, buttonText = "Reset", needs = HasBar,
        why = NO_BAR, help = "Puts the bar back above Buff Reminders, anchored to them." }
    return rows
end

page:Card({
    id = "anchor", name = "Anchor", order = ORDER_ANCHOR,
    help = "Where the bar sits: above Buff Reminders at first, then on another element, a unit frame or where you "
        .. "drag it.",
    rows = AnchorRows(),
})

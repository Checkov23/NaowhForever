-- Keys.lua: the Bar Sets tab's keybind map: a set's keys on a keyboard and mouse, coloured by the bar each one presses, with the keys an import changes ringed (ns.ActionBars.Keys).
local ns = _G.NaowhForever
local T = ns.THEME

local A = ns.ActionBars
local St = A.Style
local P = A.Parts
local Sets = ns.ActionBarSets
local Parts = ns.Shared.Parts

local VIEW_TOP, GAP, GLASS_PAD = St.VIEW_TOP, St.CARD_GAP, St.GLASS_PAD
local KEY, KEY_GAP, KEY_INSET, KEY_ICON, ROW_GAP = 50, 4, 4, 16, 4
local TABS_W, BOARD_TOP, SIDE_W = 360, 40, 260
local MOUSE_GAP = 24
local LIST_SHOWN, LIST_GAP = 8, 4
local RING_PIXELS = 2
local WIDE = { TAB = 1.5, CAPSLOCK = 1.75, SHIFT = 2.25, SPACE = 6 }
local ROWS = {
    { "ESCAPE", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12" },
    { "`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" },
    { "TAB", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]" },
    { "CAPSLOCK", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'" },
    { "SHIFT", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/" },
    { "SPACE" },
}
local MOUSE = { "BUTTON3", "BUTTON4", "BUTTON5", "MOUSEWHEELUP", "MOUSEWHEELDOWN" }
local NEAR = { "1", "2", "3", "4", "5", "6", "Q", "E", "R", "T", "F", "G", "Z", "X", "C", "V" }
local MODIFIER_KEYS = { SHIFT = true }
local MODIFIERS = {
    { key = "", label = "No Modifier" },
    { key = "SHIFT-", label = "Shift" },
    { key = "CTRL-", label = "Ctrl" },
    { key = "ALT-", label = "Alt" },
}
local GROUPS = {
    { prefix = "^ACTIONBUTTON", color = St.KEY_MAIN_RGB, label = ns.L("Action Bar 1") },
    { prefix = "^MULTIACTIONBAR1BUTTON", color = St.KEY_SECOND_RGB, label = ns.L("Action Bar 2") },
    { prefix = "^MULTIACTIONBAR[23]BUTTON", color = St.KEY_SIDE_RGB, label = ns.L("Action Bars 3 and 4") },
    { prefix = "^MULTIACTIONBAR%dBUTTON", color = St.KEY_BAR_RGB, label = ns.L("Other bars and the pet bar") },
    { prefix = "^BONUSACTIONBUTTON", color = St.KEY_BAR_RGB },
}

local TEXT_TITLE = ns.L("Keybind Map")
local TEXT_TITLE_SET = ns.L("Keybinds of %s")
local TEXT_SUBTITLE = ns.L("Each key coloured by what it presses. A ringed key does something else on this character now.")
local TEXT_SUBTITLE_NOW = ns.L("Your keys as they are now, coloured by what they press.")
local TEXT_NO_KEYS = ns.L("This set keeps no keybinds: these are your keys as they are now.")
local TEXT_OTHER, TEXT_FREE, TEXT_CHANGES = ns.L("Other commands"), ns.L("Free"), ns.L("Changes on import")
local TEXT_NOW = ns.L("On this character now: %s")
local TEXT_NOTHING = ns.L("nothing")
local TEXT_FREE_HEAD = ns.L("FREE NEAR WASD")
local TEXT_NONE_FREE = ns.L("None: every key near WASD is taken.")
local TEXT_NO_KEY_HEAD = ns.L("ON NO KEY")
local TEXT_ALL_KEYED = ns.L("Every action on your main bars has a key.")
local TEXT_MORE = ns.L("and %d more")

local Keys = {}
A.Keys = Keys

local W, setKey, modifier = nil, nil, ""
local pages, slotOf = nil, {}
local freeKeys, unkeyed = {}, {}

local function Group(command)
    for _, group in ipairs(GROUPS) do
        if command:find(group.prefix) then return group end
    end
end

local function CommandName(shown, command)
    local entry = shown.slots[slotOf[command] or 0]
    if entry then return Sets.Describe(entry), P.EntryTexture(entry) end
    return _G["BINDING_NAME_" .. command] or command
end

local function KeyEnter(cap)
    if not Parts.Tip(cap, "ANCHOR_TOP") then return end
    GameTooltip:SetText(ns.Shared.ActionKeys.Text(cap.full), 1, 1, 1)
    if cap.what then GameTooltip:AddLine(cap.what, T.fg.r, T.fg.g, T.fg.b, true) end
    if cap.changed then
        local now = GetBindingAction(cap.full)
        GameTooltip:AddLine(TEXT_NOW:format(now ~= "" and (_G["BINDING_NAME_" .. now] or now) or TEXT_NOTHING),
            St.LATER_RGB.r, St.LATER_RGB.g, St.LATER_RGB.b, true)
    end
    GameTooltip:Show()
end

local function NewCap(parent, name)
    local cap = CreateFrame("Button", nil, parent)
    cap:SetSize(KEY * (WIDE[name] or 1) + KEY_GAP * ((WIDE[name] or 1) - 1), KEY)
    cap.fill = ns.Solid(cap, "BACKGROUND", St.KEY_FREE_RGB, 1)
    cap.fill:SetAllPoints()
    cap.edge = ns.Border(cap, St.BORDER_RGB)
    cap.ring = CreateFrame("Frame", nil, cap)
    cap.ring:SetAllPoints()
    ns.Border(cap.ring, St.LATER_RGB):SetPixels(RING_PIXELS)
    cap.label = P.Mono(cap, St.MONO_SIZE, T.fg)
    cap.label:SetPoint("TOPLEFT", KEY_INSET, -KEY_INSET)
    cap.icon = cap:CreateTexture(nil, "ARTWORK")
    cap.icon:SetSize(KEY_ICON, KEY_ICON)
    cap.icon:SetPoint("TOPRIGHT", -KEY_INSET, -KEY_INSET)
    cap.icon:SetTexCoord(St.ICON_CROP, 1 - St.ICON_CROP, St.ICON_CROP, 1 - St.ICON_CROP)
    cap.text = P.Label(cap, St.TINY_SIZE, T.fg)
    cap.text:SetPoint("BOTTOMLEFT", KEY_INSET, KEY_INSET)
    cap.text:SetPoint("BOTTOMRIGHT", -KEY_INSET, KEY_INSET)
    cap.text:SetMaxLines(2)
    cap.name = name
    cap:SetScript("OnEnter", KeyEnter)
    cap:SetScript("OnLeave", GameTooltip_Hide)
    return cap
end

local function PaintCap(cap, shown, bindings, ring)
    local full = MODIFIER_KEYS[cap.name] and cap.name or (modifier .. cap.name)
    local command = bindings[full]
    cap.full = full
    cap.label:SetText(ns.Shared.ActionKeys.Text(cap.name))
    local group = command and Group(command)
    local color = (group and group.color) or (command and St.KEY_OTHER_RGB) or St.KEY_FREE_RGB
    cap.fill:SetColorTexture(color.r, color.g, color.b, 1)
    local what, texture
    if command then what, texture = CommandName(shown, command) end
    cap.what = what
    cap.text:SetText(what or "")
    cap.icon:SetTexture(texture)
    cap.icon:SetShown(texture ~= nil)
    cap.changed = ring and command ~= nil and GetBindingAction(full) ~= command
    cap.ring:SetShown(cap.changed)
end

local function NewListLine(panel, i, top)
    local line = P.Label(panel, St.NOTE_SIZE, T.fg)
    line:SetPoint("TOPLEFT", GLASS_PAD, -(top + (i - 1) * (St.NOTE_SIZE + LIST_GAP)))
    line:SetPoint("RIGHT", -GLASS_PAD, 0)
    line:SetWordWrap(false)
    return line
end

local function NewSide(parent, head, top)
    local panel = P.GlassPanel(parent, "")
    panel.title:SetText("")
    panel.head = P.Mono(panel, St.MONO_SIZE, St.GOLD_RGB)
    panel.head:SetPoint("TOPLEFT", GLASS_PAD, -GLASS_PAD)
    panel.head:SetText(head)
    panel.lines = {}
    for i = 1, LIST_SHOWN do panel.lines[i] = NewListLine(panel, i, top) end
    return panel
end

local function PaintList(panel, list, empty)
    for i, line in ipairs(panel.lines) do
        local text = list[i]
        if i == 1 and #list == 0 then text = empty end
        if i == LIST_SHOWN and #list > LIST_SHOWN then text = TEXT_MORE:format(#list - LIST_SHOWN + 1) end
        line:SetShown(text ~= nil)
        line:SetText(text or "")
    end
end

local function Free(bindings)
    wipe(freeKeys)
    for _, mod in ipairs(MODIFIERS) do
        for _, key in ipairs(NEAR) do
            local full = mod.key .. key
            if not bindings[full] then freeKeys[#freeKeys + 1] = ns.Shared.ActionKeys.Text(full) end
        end
    end
    return freeKeys
end

local function Unkeyed(shown, bindings)
    wipe(unkeyed)
    local keyed = {}
    for _, command in pairs(bindings) do keyed[command] = true end
    for _, page in ipairs(P.STRIP_PAGES) do
        local entry = pages[page]
        for i, command in ipairs(entry.commands) do
            local action = shown.slots[entry.list[i]]
            if action and not keyed[command] then unkeyed[#unkeyed + 1] = Sets.Describe(action) end
        end
    end
    return unkeyed
end

local function Draw(v)
    local set = setKey and Sets.Get(setKey)
    local shown = set or { slots = Sets.Capture() }
    local bindings = set and set.bindings or Sets.CaptureBindings()
    Parts.PaintTabs(v.tabs, modifier)
    for _, cap in ipairs(v.caps) do PaintCap(cap, shown, bindings, set ~= nil and set.bindings ~= nil) end
    PaintList(v.free, Free(bindings), TEXT_NONE_FREE)
    PaintList(v.unkeyed, Unkeyed(shown, bindings), TEXT_ALL_KEYED)
    v.note:SetText(set and not set.bindings and TEXT_NO_KEYS or "")
end

local function SetModifier(key)
    modifier = key
    W.Redraw()
end

local function LegendChip(parent, after, text, color)
    local chip = P.Chip(parent)
    if after then chip:SetPoint("LEFT", after, "RIGHT", LIST_GAP, 0) else chip:SetPoint("BOTTOMLEFT") end
    P.PaintChip(chip, ns.Upper(text), color)
    return chip
end

local function BuildBoard(v, board)
    v.caps = {}
    local y = 0
    for _, row in ipairs(ROWS) do
        local x = 0
        for _, name in ipairs(row) do
            local cap = NewCap(board, name)
            cap:SetPoint("TOPLEFT", x, -y)
            x = x + cap:GetWidth() + KEY_GAP
            v.caps[#v.caps + 1] = cap
        end
        y = y + KEY + ROW_GAP
    end
    local mouseX = #ROWS[2] * (KEY + KEY_GAP) + MOUSE_GAP
    for i, name in ipairs(MOUSE) do
        local cap = NewCap(board, name)
        cap:SetPoint("TOPLEFT", mouseX, -(i - 1) * (KEY + ROW_GAP))
        v.caps[#v.caps + 1] = cap
    end
    local after
    for _, group in ipairs(GROUPS) do
        if group.label then after = LegendChip(board, after, group.label, group.color) end
    end
    after = LegendChip(board, after, TEXT_OTHER, St.KEY_OTHER_RGB)
    after = LegendChip(board, after, TEXT_FREE, St.KEY_FREE_RGB)
    LegendChip(board, after, TEXT_CHANGES, St.LATER_RGB)
end

function Keys.SetKey(key)
    setKey = key
end

function Keys.Build(window)
    W = window
    local v = { cards = {} }
    v.frame = CreateFrame("Frame", nil, W.frame)
    v.frame:SetAllPoints()
    local items = {}
    for i, mod in ipairs(MODIFIERS) do items[i] = { key = mod.key, label = ns.L(mod.label) } end
    v.tabs = Parts.Tabs(v.frame, TABS_W, items, SetModifier)
    v.tabs:SetPoint("TOPLEFT", 0, -VIEW_TOP)
    v.note = P.Label(v.frame, St.NOTE_SIZE, St.LATER_RGB)
    v.note:SetPoint("LEFT", v.tabs, "RIGHT", GAP * 2, 0)
    local board = CreateFrame("Frame", nil, v.frame)
    board:SetPoint("TOPLEFT", 0, -(VIEW_TOP + BOARD_TOP))
    board:SetPoint("BOTTOMRIGHT", -(SIDE_W + GAP), 0)
    BuildBoard(v, board)
    local listTop = GLASS_PAD + St.MONO_SIZE + GAP
    v.free = NewSide(v.frame, TEXT_FREE_HEAD, listTop)
    v.free:SetPoint("TOPRIGHT", 0, -(VIEW_TOP + BOARD_TOP))
    v.free:SetSize(SIDE_W, listTop + LIST_SHOWN * (St.NOTE_SIZE + LIST_GAP) + GLASS_PAD)
    v.unkeyed = NewSide(v.frame, TEXT_NO_KEY_HEAD, listTop)
    v.unkeyed:SetPoint("TOPRIGHT", v.free, "BOTTOMRIGHT", 0, -GAP)
    v.unkeyed:SetSize(SIDE_W, listTop + LIST_SHOWN * (St.NOTE_SIZE + LIST_GAP) + GLASS_PAD)
    function v.Open()
        pages = P.Pages()
        wipe(slotOf)
        for _, bar in ipairs(A.BARS) do
            local entry = pages[bar.page]
            for i, command in ipairs(entry.commands) do slotOf[command] = slotOf[command] or entry.list[i] end
        end
        v.title = setKey and TEXT_TITLE_SET:format(setKey) or TEXT_TITLE
        v.subtitle = setKey and TEXT_SUBTITLE or TEXT_SUBTITLE_NOW
    end
    function v.Draw() Draw(v) end
    v.events = { "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED" }
    return v
end

-- Builder.lua: the Action Bars window's set builder: your bars as they are, each slot in or out, then keybinds, macros and a name (ns.ActionBars.Builder).
local ns = _G.NaowhForever
local T = ns.THEME

local A = ns.ActionBars
local St = A.Style
local P = A.Parts
local Sets = ns.ActionBarSets

local WIDTH, HEIGHT, CARD, SIDE_W, GAP = St.WIDTH, St.HEIGHT, St.CARD, St.SIDE_W, St.CARD_GAP
local HEADER, FOOTER = St.WINDOW_HEADER, St.WINDOW_FOOTER
local ROW_GAP, ROW_FILL, ICON_CROP, OUT_ALPHA = St.ROW_GAP, St.ROW_FILL, St.ICON_CROP, St.OUT_ALPHA
local SWITCH_W, BUTTON_H, LINE_GAP, HEADING_H = St.SWITCH_W, St.BUTTON_H, St.LINE_GAP, St.HEADING_H
local BLACK, SLOTS_PER_BAR = St.BORDER_RGB, A.C.SLOTS_PER_BAR
local SMALL_SIZE, NOTE_SIZE, NAME_SIZE, TITLE_SIZE = St.SMALL_SIZE, St.NOTE_SIZE, St.NAME_SIZE, St.TITLE_SIZE
local KEEP_H = 330
local OFF_BAR_ALPHA, OFF_MACRO_ALPHA = 0.55, 0.45
local BOX_GAP = 8
local MACRO_ROW_H, MACRO_GAP, MACRO_INSET, MACRO_ICON_PAD = 38, 4, 8, 12
local CHIP_INSET_X, CHIP_INSET_Y, STACK_GAP, TEXT_GAP = 8, 6, St.STACK_GAP, 6
local SWITCH_GAP, SWITCH_DROP, OPTION_H, DIVIDER_GAP = 10, 4, 44, 10
local NAME_LABEL_TOP, NAME_H, NAME_MAX, SUMMARY_GAP, FILL_W = 24, 26, 40, 10, St.FILL_W

local TEXT_TITLE, TEXT_EDIT = ns.L("New Bar Set"), ns.L("Edit ")
local TEXT_SUBTITLE = ns.L("Pick what goes in, then import it on any %s.")
local TEXT_PICK = ns.L("1. PICK YOUR BARS")
local TEXT_PICK_HINT = ns.L("Click a slot to leave it out, or a bar's box for the whole bar.")
local TEXT_KEEP, TEXT_NAME_SAVE = ns.L("2. ALSO KEEP"), ns.L("3. NAME AND SAVE")
local TEXT_KEYBINDS, TEXT_MACROS, TEXT_SET_NAME = ns.L("Keybinds"), ns.L("Macros"), ns.L("Set name")
local TEXT_SAVE_SET = ns.L("Save Set")
local TEXT_COUNT = "%d / %d"
local TEXT_LEAVE_BAR, TEXT_PUT_BAR = ns.L("Leave this bar out"), ns.L("Put this bar back in")
local TEXT_BAR_HINT = ns.L("A bar left out is not touched by an import.")
local TEXT_EMPTY_SLOT = ns.L("Empty slot")
local TEXT_KEPT = ns.L("In the set. Click to leave it out.")
local TEXT_KEPT_EMPTY = ns.L("In the set as empty: an import clears it. Click to leave it out.")
local TEXT_LEFT_OUT = ns.L("Left out: an import leaves this slot as it is. Click to put it back in.")
local TEXT_CHARACTER, TEXT_ACCOUNT, TEXT_ON_BARS = ns.L("Character"), ns.L("Account"), ns.L("On bars")
local TEXT_ON_BARS_TIP = ns.L("On a slot in the set, so it always comes along.")
local TEXT_REUSE_TIP = ns.L("An alt that already has this macro, by name and text or text alone, uses its own.")
local TEXT_NO_NAME = ns.L("Give the set a name first.")
local TEXT_REPLACE = ns.L("Replace %s with these bars?")
local TEXT_KEYS_ON = ns.L("All %d bound keys come along.")
local TEXT_KEYS_OFF = ns.L("Off: an import leaves your keys alone.")
local TEXT_MACROS_ON = ns.L("%d of %d come along. An alt reuses the ones it has.")
local TEXT_MACROS_OFF = ns.L("Only the macros on your kept slots come along.")
local TEXT_SUMMARY = ns.L("This set holds %s.")
local TEXT_ACTIONS, TEXT_KEYBIND_COUNT, TEXT_MACRO_COUNT = ns.L("%d actions"), ns.L("%d keybinds"), ns.L("%d macros")
local BODY_JOIN = "  "

local Builder = {}
A.Builder = Builder

local W, draft
local onBars = {}

local function Copy(t)
    local out = {}
    for k, val in pairs(t or {}) do out[k] = val end
    return out
end

local function Flip(t, key)
    t[key] = not t[key] or nil
    W.Redraw()
end

local function SlotTip(slot, kept)
    return function(tip)
        if GetActionInfo(slot) then tip:SetAction(slot) else tip:SetText(TEXT_EMPTY_SLOT, 1, 1, 1) end
        tip:AddLine(" ")
        local line = kept and (GetActionInfo(slot) and TEXT_KEPT or TEXT_KEPT_EMPTY) or TEXT_LEFT_OUT
        tip:AddLine(line, T.muted.r, T.muted.g, T.muted.b, true)
    end
end

local function BoxEnter(box)
    P.Hint(box, box.barOn and TEXT_LEAVE_BAR or TEXT_PUT_BAR, TEXT_BAR_HINT)
end

local function Counts(list, skip)
    local used, total, out = 0, 0, 0
    for _, slot in ipairs(list) do
        if GetActionInfo(slot) then
            total = total + 1
            if not skip[slot] then used = used + 1 end
        end
        if skip[slot] then out = out + 1 end
    end
    return used, total, out
end

local function PaintBarBox(row, list, skip, barOn)
    row.box:Show()
    P.PaintBox(row.box, barOn)
    row.box.barOn = barOn
    row.box.onClick = function()
        for _, slot in ipairs(list) do skip[slot] = barOn or nil end
        W.Redraw()
    end
    row.box:SetScript("OnEnter", BoxEnter)
    row.box:SetScript("OnLeave", GameTooltip_Hide)
end

local function PaintBarTiles(row, bar, list, skip)
    for i, slot in ipairs(list) do
        local kept = not skip[slot]
        P.PaintTile(row.tiles[i], {
            texture = GetActionTexture(slot),
            key = GetActionInfo(slot) and P.KeyText(bar.button .. i) or "",
            alpha = kept and 1 or OUT_ALPHA, grey = not kept,
            edge = (not kept) and T.muted or nil,
            tip = SlotTip(slot, kept),
            onClick = function() Flip(skip, slot) end,
        })
    end
end

local function DrawBar(content, y, bar, list, skip, used, total, out)
    local row = ns.UI.Keep(content, "bar", P.NewBarRow)
    row:SetPoint("TOPLEFT", 0, y)
    row:SetPoint("TOPRIGHT", 0, y)
    local barOn = out < SLOTS_PER_BAR
    row:SetAlpha(barOn and 1 or OFF_BAR_ALPHA)
    PaintBarBox(row, list, skip, barOn)
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row.box, "RIGHT", BOX_GAP, 0)
    row.name:SetText(bar.name)
    row.count:SetText(TEXT_COUNT:format(used, total))
    PaintBarTiles(row, bar, list, skip)
    return y - row:GetHeight() - ROW_GAP
end

local function DrawBars(v)
    local content, skip = v.content, draft.choices.skip
    ns.UI.BeginReusableRows(content)
    local y, actions = 0, 0
    for _, bar in ipairs(Sets.BARS) do
        local list = P.BarSlots(bar)
        local used, total, out = Counts(list, skip)
        if total > 0 or out > 0 then
            actions = actions + used
            y = DrawBar(content, y, bar, list, skip, used, total, out)
        end
    end
    content:SetHeight(math.max(1, -y))
    return actions
end

local function MacroEnter(row)
    P.Hint(row, row.tipTitle, row.tipLine)
end

local function NewMacroRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(MACRO_ROW_H)
    ns.Solid(row, "BACKGROUND", T.bg, ROW_FILL):SetAllPoints()
    ns.Border(row, BLACK)
    row.box = P.Box(row)
    row.box:SetPoint("LEFT", MACRO_INSET, 0)
    row.box:EnableMouse(false)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(MACRO_ROW_H - MACRO_ICON_PAD, MACRO_ROW_H - MACRO_ICON_PAD)
    row.icon:SetPoint("LEFT", row.box, "RIGHT", MACRO_INSET, 0)
    row.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    row.scope = P.Chip(row)
    row.scope:SetPoint("TOPRIGHT", -CHIP_INSET_X, -CHIP_INSET_Y)
    row.onBars = P.Chip(row)
    row.onBars:SetPoint("TOPRIGHT", row.scope, "BOTTOMRIGHT", 0, -STACK_GAP)
    row.name = P.Label(row, NAME_SIZE, T.fg)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", MACRO_INSET, 0)
    row.name:SetPoint("RIGHT", row.scope, "LEFT", -TEXT_GAP, 0)
    row.name:SetWordWrap(false)
    row.body = P.Label(row, St.TAG_SIZE, T.muted)
    row.body:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -STACK_GAP)
    row.body:SetPoint("RIGHT", row.scope, "LEFT", -TEXT_GAP, 0)
    row.body:SetWordWrap(false)
    row:SetScript("OnClick", P.Clicked)
    row:SetScript("OnEnter", MacroEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function OnBars(slots, skip)
    wipe(onBars)
    for slot, entry in pairs(slots) do
        if entry.kind == "macro" and not skip[slot] then onBars[Sets.MacroKey(entry.name, entry.body)] = true end
    end
    return onBars
end

local function PaintMacro(row, macro, key, locked, on, choices)
    row:SetAlpha((choices.macros or locked) and 1 or OFF_MACRO_ALPHA)
    P.PaintBox(row.box, on, locked)
    row.icon:SetTexture(macro.icon)
    row.name:SetText(macro.name)
    row.body:SetText((macro.body or ""):gsub("[\r\n]+", BODY_JOIN))
    P.PaintChip(row.scope, macro.perCharacter and TEXT_CHARACTER or TEXT_ACCOUNT,
        macro.perCharacter and St.CHARACTER_RGB or St.ACCOUNT_RGB)
    if locked then P.PaintChip(row.onBars, TEXT_ON_BARS, T.grey) else row.onBars:Hide() end
    row.tipTitle = macro.name
    row.tipLine = locked and TEXT_ON_BARS_TIP or TEXT_REUSE_TIP
    row.onClick = function()
        if locked or not choices.macros then return end
        Flip(choices.macroOff, key)
    end
end

local function DrawMacros(v, slots)
    local choices, content = draft.choices, v.macroContent
    local bars, all = OnBars(slots, choices.skip), Sets.CaptureMacros()
    ns.UI.BeginReusableRows(content)
    local y, kept = 0, 0
    for _, macro in ipairs(all) do
        local key = Sets.MacroKey(macro.name, macro.body)
        local locked = bars[key]
        local on = locked or (choices.macros and not choices.macroOff[key])
        if on then kept = kept + 1 end
        local row = ns.UI.Keep(content, "macro", NewMacroRow)
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", 0, y)
        PaintMacro(row, macro, key, locked, on, choices)
        y = y - MACRO_ROW_H - MACRO_GAP
    end
    content:SetHeight(math.max(1, -y))
    return kept, #all
end

local function BindingCount()
    local n = 0
    for _ in pairs(Sets.CaptureBindings()) do n = n + 1 end
    return n
end

local function SaveDraft()
    local name = strtrim(draft.box:GetText() or "")
    if name == "" then
        ns.Print(TEXT_NO_NAME)
        return
    end
    local function Done()
        if Sets.Save(name, draft.choices) then W.Show("sets") end
    end
    local existing = Sets.Find(name)
    if existing and existing ~= draft.key then
        ns.Confirm(TEXT_REPLACE:format(existing), Done)
    else
        Done()
    end
end

local function Option(pane, y, title, get, set)
    local label = P.Label(pane, TITLE_SIZE, T.fg)
    label:SetPoint("TOPLEFT", 0, y)
    label:SetText(title)
    local line = P.Label(pane, SMALL_SIZE, T.muted)
    line:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -STACK_GAP)
    line:SetPoint("RIGHT", -(SWITCH_W + SWITCH_GAP), 0)
    local switch = P.Switch(pane, get, set)
    switch:SetPoint("TOPRIGHT", 0, y - SWITCH_DROP)
    return line, switch
end

local function KeysOn() return draft.choices.keys end
local function SetKeys(on) draft.choices.keys = on; W.Redraw() end
local function MacrosOn() return draft.choices.macros end
local function SetMacros(on) draft.choices.macros = on; W.Redraw() end

local function BuildKeep(v, rightX, top)
    local keep = P.Pane(W.frame, rightX, top, CARD, HEIGHT - top - KEEP_H)
    keep:SetParent(v.frame)
    P.Heading(keep, TEXT_KEEP)
    local y = -HEADING_H
    v.keysLine, v.keysSwitch = Option(keep, y, TEXT_KEYBINDS, KeysOn, SetKeys)
    y = y - OPTION_H
    P.Divider(keep, y)
    y = y - DIVIDER_GAP
    v.macrosLine, v.macrosSwitch = Option(keep, y, TEXT_MACROS, MacrosOn, SetMacros)
    v.macroScroll, v.macroContent = P.List(keep, -(y - OPTION_H))
end

local function UnFocus(box) box:ClearFocus() end

local function BuildSave(v, rightX, top, bottom)
    local save = P.Pane(W.frame, rightX, top + KEEP_H + GAP, CARD, bottom)
    save:SetParent(v.frame)
    P.Heading(save, TEXT_NAME_SAVE)
    local label = P.Label(save, SMALL_SIZE, T.muted)
    label:SetPoint("TOPLEFT", 0, -NAME_LABEL_TOP)
    label:SetText(TEXT_SET_NAME)
    v.box = ns.NewEditBox(save)
    v.box:SetHeight(NAME_H)
    v.box:SetMaxLetters(NAME_MAX)
    v.box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -LINE_GAP)
    v.box:SetPoint("RIGHT")
    v.box:SetScript("OnEnterPressed", UnFocus)
    v.box:SetScript("OnEscapePressed", UnFocus)
    v.summary = P.Label(save, NOTE_SIZE, T.fg)
    v.summary:SetPoint("TOPLEFT", v.box, "BOTTOMLEFT", 0, -SUMMARY_GAP)
    v.summary:SetPoint("RIGHT")
    v.button = ns.AccentBorder(ns.Button(save, TEXT_SAVE_SET, FILL_W, BUTTON_H, SaveDraft))
    v.button:SetPoint("BOTTOMLEFT")
    v.button:SetPoint("BOTTOMRIGHT")
end

local function Summary(actions, keys, kept)
    local parts = { TEXT_ACTIONS:format(actions) }
    if draft.choices.keys then parts[#parts + 1] = TEXT_KEYBIND_COUNT:format(keys) end
    parts[#parts + 1] = TEXT_MACRO_COUNT:format(kept)
    return TEXT_SUMMARY:format(table.concat(parts, ", "))
end

local function Draw(v)
    local slots = Sets.Capture()
    local actions = DrawBars(v)
    local kept, all = DrawMacros(v, slots)
    local choices = draft.choices
    local keys = choices.keys and BindingCount() or 0
    v.keysLine:SetText(choices.keys and TEXT_KEYS_ON:format(keys) or TEXT_KEYS_OFF)
    v.macrosLine:SetText(choices.macros and TEXT_MACROS_ON:format(kept, all) or TEXT_MACROS_OFF)
    v.keysSwitch._refreshValue()
    v.macrosSwitch._refreshValue()
    v.summary:SetText(Summary(actions, keys, kept))
end

function Builder.NewDraft(key)
    local set = key and Sets.Get(key)
    local choices = set and set.choices or {}
    draft = {
        key = set and key or nil, name = set and key or "",
        choices = { skip = Copy(choices.skip), macroOff = Copy(choices.macroOff),
            keys = choices.keys ~= false, macros = choices.macros ~= false },
    }
end

function Builder.HasDraft()
    return draft ~= nil
end

function Builder.Build(window)
    W = window
    local v = { cards = {} }
    local top, bottom = HEADER + CARD, FOOTER + CARD
    local rightX = WIDTH - CARD - SIDE_W
    P.Cards(W.frame, v.cards, CARD, top, SIDE_W + CARD + GAP, bottom)
    P.Cards(W.frame, v.cards, rightX, top, CARD, HEIGHT - top - KEEP_H)
    P.Cards(W.frame, v.cards, rightX, top + KEEP_H + GAP, CARD, bottom)
    v.frame = CreateFrame("Frame", nil, W.frame)
    v.frame:SetAllPoints()
    local bars = P.Pane(W.frame, CARD, top, SIDE_W + CARD + GAP, bottom)
    bars:SetParent(v.frame)
    P.Heading(bars, TEXT_PICK, TEXT_PICK_HINT)
    v.scroll, v.content = P.List(bars, HEADING_H)
    BuildKeep(v, rightX, top)
    BuildSave(v, rightX, top, bottom)
    v.title = TEXT_TITLE
    v.subtitle = TEXT_SUBTITLE:format(UnitClass("player"))
    function v.Open()
        v.box:SetText(draft.name)
        draft.box = v.box
        v.title = draft.key and (TEXT_EDIT .. draft.key) or TEXT_TITLE
    end
    function v.Draw() Draw(v) end
    v.events = { "ACTIONBAR_SLOT_CHANGED", "UPDATE_BINDINGS", "UPDATE_MACROS" }
    return v
end

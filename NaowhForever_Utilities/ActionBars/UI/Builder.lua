-- Builder.lua: the Bar Sets tab's set builder: a name, icon and tags, your bars on the scene's strip with each bar and slot in or out, what goes in, the macros or keybinds, and a summary to save (ns.ActionBars.Builder).
local ns = _G.NaowhForever
local T = ns.THEME

local A = ns.ActionBars
local S = A.Settings
local St = A.Style
local P = A.Parts
local Sets = ns.ActionBarSets
local Capture = A.Capture
local Parts = ns.Shared.Parts

local VIEW_TOP, GAP, GLASS_PAD = St.VIEW_TOP, St.CARD_GAP, St.GLASS_PAD
local OUT_ALPHA, ICON_CROP = St.OUT_ALPHA, St.ICON_CROP
local BUTTON_H, LINE_GAP = St.BUTTON_H, St.LINE_GAP
local SLOTS_PER_BAR = A.C.SLOTS_PER_BAR
local SMALL_SIZE, NOTE_SIZE = St.SMALL_SIZE, St.NOTE_SIZE
local PET_BAR, PET_CLASSES = A.PET_BAR, A.PET_CLASSES
local DOT = St.PLACE_DOT
local MAIN_PAGE, LEFT_PAGE, TOP_PAGE, RIGHT_PAGE, MAIN_VIEW = P.MAIN_PAGE, P.LEFT_PAGE, P.TOP_PAGE, P.RIGHT_PAGE, P.MAIN_VIEW
local SUMMARY_BAR, IDENT_H, LEFT_W = 60, 54, 300
local PART_H, PART_GAP, PART_PAD, LIST_TABS_W, LIST_HEAD = 52, 6, 8, 240, 34
local SWATCH, LEGEND_H, LEGEND_GAP, LEGEND_TEXT_GAP = 12, 20, 18, 6
local COUNT_NUMBER, COUNT_GAP, SAVE_CODE_W = 22, 22, 150
local ICON_BUTTON, PICKER_TILE, PICKER_GAP, PICKER_COLUMNS, PICKER_MAX, PICKER_LEVEL = 44, 28, 3, 10, 40, 20
local MAX_TAGS, TAG_MAX, TAG_PAD, TAG_H, TAGS_X, ADD_TAG_W = 3, 16, 8, 20, 18, 60
local OFF_MACRO_ALPHA = 0.45
local MACRO_ROW_H, MACRO_GAP, MACRO_INSET, MACRO_ICON = 40, 6, 8, 24
local KEY_ROW_H, KEY_W, KEY_H = 30, 72, 20
local WORD_GAP, TAG_GAP = 8, 4
local NAME_H, NAME_MAX, NAME_W, SUMMARY_GAP, SAVE_W = 30, 40, 300, 18, 120

local TEXT = {
    TITLE = ns.L("New Bar Set"),
    EDIT = ns.L("Edit "),
    SUBTITLE = ns.L("Pick what goes in, then import it on any %s."),
    PICK_HINT = ns.L("Click a bar's name to leave it out, or a button to skip just that slot."),
    MAIN = ns.L("Main"),
    MAIN_BARS = ns.L("Main bars"),
    PET_BAR = ns.L("Pet Bar"),
    PICKED_BAR = "%s (%d)",
    CHIP = "%s %d",
    KEYBINDS = ns.L("Keybinds"),
    MACROS = ns.L("Macros"),
    SET_NAME = ns.L("Set name"),
    SAVE_SET = ns.L("Save Set"),
    ICON = ns.L("Set icon"),
    ICON_TIP = ns.L("Pick one from your bars. Auto shows the set's first spell."),
    AUTO = ns.L("Auto"),
    TAGS = ns.L("Tags"),
    ADD_TAG = ns.L("+ Tag"),
    NEW_TAG = ns.L("A tag for this set, such as Dungeon or PvP"),
    TAG_TIP = ns.L("Click to take this tag off."),
    ACTION_UNIT = ns.L("action"),
    ACTIONS_UNIT = ns.L("actions"),
    KEYBIND_UNIT = ns.L("keybind"),
    KEYBINDS_UNIT = ns.L("keybinds"),
    MACRO_UNIT = ns.L("macro"),
    MACROS_UNIT = ns.L("macros"),
    WHAT_GOES_IN = ns.L("WHAT GOES IN"),
    ACTIONS_PART = ns.L("Actions"),
    ACTIONS_LINE = ns.L("%d on your bars, %d left out"),
    HIGHEST = ns.L("Highest rank on import"),
    HIGHEST_LINE = ns.L("Imports the best rank you know of each spell."),
    PET_PART = ns.L("Pet bar keys"),
    PET_ON = ns.L("The pet bar's keys come along."),
    PET_OFF = ns.L("Left out: an import leaves them alone."),
    GOES_IN = ns.L("Goes in"),
    LEFT_OUT_LEGEND = ns.L("Left out"),
    KEPT_EMPTY_LEGEND = ns.L("Kept empty"),
    LIST_MACROS = ns.L("Macros %d"),
    LIST_KEYS = ns.L("Keybinds %d"),
    SCOPE = ns.L("Account %d, Character %d"),
    SELECT_ALL = ns.L("Select All"),
    SELECT_NONE = ns.L("Select None"),
    SAVE_CODE = ns.L("Save and Get Code"),
    SLOT_OUT = ns.L("%d slot left out"),
    SLOTS_OUT = ns.L("%d slots left out"),
    BARS_OUT = ns.L("%s not in the set"),
    TAG_CHIP = "%s  x",
    LEAVE_BAR = ns.L("Leave this bar out"),
    PUT_BAR = ns.L("Put this bar back in"),
    BAR_HINT = ns.L("A bar left out is not touched by an import."),
    LEAVE_PET = ns.L("Leave the pet bar's keys out"),
    PUT_PET = ns.L("Put the pet bar's keys back in"),
    PET_HINT = ns.L("Only the pet bar's keys go in a set, never your pet's actions."),
    PET_TIP = ns.L("Only this button's keys go in the set."),
    EMPTY_SLOT = ns.L("Empty slot"),
    KEPT = ns.L("In the set. Click to leave it out."),
    KEPT_EMPTY = ns.L("In the set as empty: an import clears it. Click to leave it out."),
    LEFT_OUT = ns.L("Left out: an import leaves this slot as it is. Click to put it back in."),
    CHARACTER = ns.L("Character"),
    ACCOUNT = ns.L("Account"),
    ON_BARS = ns.L("On bars"),
    ON_BARS_TIP = ns.L("On a slot in the set, so it always comes along."),
    REUSE_TIP = ns.L("An alt that already has this macro, by name and text or text alone, uses its own."),
    NO_NAME = ns.L("Give the set a name first."),
    REPLACE = ns.L("Replace %s with these bars?"),
    KEYS_ON = ns.L("All %d come along: %d on your bars, %d for other commands."),
    KEYS_OFF = ns.L("Off: an import leaves your keys alone."),
    MACROS_ON = ns.L("%d of %d come along. An alt reuses the ones it has."),
    MACROS_OFF = ns.L("Only the macros on your kept slots come along."),
}
local BODY_JOIN = "  "
local BAR_COMMAND = "^(.-)%d+$"

local Plural = A.Plural

local Builder = {}
A.Builder = Builder

local W, draft, listTab
local viewPage, formPage = MAIN_VIEW, MAIN_PAGE
local onBars, look, parts, barButtons, keyList, slotOf = {}, {}, {}, {}, {}, {}
local pages, order, petCommands, forms
local model = { regions = { left = {}, top = {}, bottom = {}, right = {} }, single = nil, chips = {},
    pet = nil }
local single, chipPool = {}, {}
local picker = { values = {}, order = {} }

for _, bar in ipairs(A.BARS) do barButtons[bar.button] = true end
barButtons[PET_BAR.button] = true

local function Copy(t)
    local out = {}
    for k, val in pairs(t or {}) do out[k] = val end
    return out
end

local function Flip(t, key)
    t[key] = not t[key] or nil
    W.Redraw()
end

local function SlotTip(tip, tile)
    local slot = tile.slot
    if GetActionInfo(slot) then tip:SetAction(slot) else tip:SetText(TEXT.EMPTY_SLOT, 1, 1, 1) end
    tip:AddLine(" ")
    local line = tile.kept and (GetActionInfo(slot) and TEXT.KEPT or TEXT.KEPT_EMPTY) or TEXT.LEFT_OUT
    tip:AddLine(line, T.muted.r, T.muted.g, T.muted.b, true)
end

local function SlotClicked(tile)
    Flip(draft.choices.skip, tile.slot)
end

local function PetAction(i)
    if not GetPetActionInfo then return nil end
    local name, texture, isToken = GetPetActionInfo(i)
    if isToken and texture then texture = _G[texture] end
    return name, texture
end

local function PetTip(tip, tile)
    if PetAction(tile.slot) then tip:SetPetAction(tile.slot) else tip:SetText(TEXT.EMPTY_SLOT, 1, 1, 1) end
    tip:AddLine(" ")
    tip:AddLine(TEXT.PET_TIP, T.muted.r, T.muted.g, T.muted.b, true)
end

local function BarHint(label)
    P.Hint(label, label.out and TEXT.PUT_BAR or TEXT.LEAVE_BAR, TEXT.BAR_HINT)
end

local function PetHint(label)
    P.Hint(label, label.out and TEXT.PUT_PET or TEXT.LEAVE_PET, TEXT.PET_HINT)
end

local function BarClicked(label)
    local skip = draft.choices.skip
    for _, slot in ipairs(label.entry.list) do skip[slot] = (not label.out) or nil end
    W.Redraw()
end

local function PetClicked()
    local choices = draft.choices
    if not choices.keys then return end
    choices.petOff = not choices.petOff or nil
    W.Redraw()
end

local function Counts(list, skip)
    local used, out = 0, 0
    for _, slot in ipairs(list) do
        if GetActionInfo(slot) and not skip[slot] then used = used + 1 end
        if skip[slot] then out = out + 1 end
    end
    return used, out
end

local function PaintSlot(tile, region, i)
    local entry, skip = region.entry, draft.choices.skip
    local slot = entry.list[i]
    local kept = not skip[slot]
    local dim = not kept and not region.out
    wipe(look)
    look.texture = GetActionTexture(slot)
    look.key = GetActionInfo(slot) and P.KeyText(entry.commands[i]) or ""
    look.alpha, look.grey, look.mark = dim and OUT_ALPHA or 1, not kept, dim
    look.edge = dim and T.muted or nil
    look.tip, look.onClick = SlotTip, SlotClicked
    P.PaintTile(tile, look)
    tile.slot, tile.kept = slot, kept
end

local function Region(region, entry, label)
    local _, out = Counts(entry.list, draft.choices.skip)
    region.entry, region.label = entry, label or entry.bar.name
    region.out = out == SLOTS_PER_BAR
    region.onClick, region.hint = BarClicked, BarHint
    return region
end

local function DrawChips()
    wipe(model.chips)
    if not forms then return end
    local skip = draft.choices.skip
    for i, page in ipairs(forms) do
        local entry = pages[page]
        local used, out = Counts(entry.list, skip)
        local chip = chipPool[i] or {}
        chipPool[i] = chip
        chip.text = TEXT.CHIP:format(page == MAIN_PAGE and TEXT.MAIN or entry.form, used)
        chip.picked, chip.out, chip.page = page == formPage, out == SLOTS_PER_BAR, page
        chip.onClick = Builder.PickForm
        model.chips[i] = chip
    end
end

local function DrawPet()
    if not PET_CLASSES[A.Class()] then
        model.pet = nil
        return
    end
    local pet = model.petLook or { keys = {} }
    model.petLook, model.pet = pet, pet
    local choices = draft.choices
    pet.label, pet.out = TEXT.PET_BAR, not (choices.keys and not choices.petOff)
    pet.tip, pet.onClick, pet.hint = PetTip, PetClicked, PetHint
    for i = 1, PET_BAR.buttons do pet.keys[i] = P.KeyText(petCommands[i]) end
end

local function DrawPicker()
    local values, list, skip = picker.values, picker.order, draft.choices.skip
    wipe(values)
    wipe(list)
    values[MAIN_VIEW], list[1] = TEXT.MAIN_BARS, MAIN_VIEW
    for _, entry in ipairs(order) do
        if entry.other then
            local used = Counts(entry.list, skip)
            values[entry.bar.page] = TEXT.PICKED_BAR:format(entry.bar.name, used)
            list[#list + 1] = entry.bar.page
        end
    end
end

local function DrawScene(v)
    local regions = model.regions
    if not forms then formPage = MAIN_PAGE end
    local bottom = pages[formPage]
    local formName = formPage == MAIN_PAGE and TEXT.MAIN or bottom.form
    Region(regions.left, pages[LEFT_PAGE])
    Region(regions.top, pages[TOP_PAGE])
    Region(regions.right, pages[RIGHT_PAGE])
    Region(regions.bottom, bottom, pages[MAIN_PAGE].bar.name .. DOT .. formName)
    model.single = viewPage ~= MAIN_VIEW and pages[viewPage] and Region(single, pages[viewPage]) or nil
    DrawChips()
    DrawPet()
    DrawPicker()
    model.caption = TEXT.PICK_HINT
    model.Paint = PaintSlot
    P.DrawScene(v.scene, model)
end

local function MacroEnter(row)
    P.Hint(row, row.tipTitle, row.tipLine)
end

local function MacroClicked(row)
    if row.locked or not draft.choices.macros then return end
    Flip(draft.choices.macroOff, row.key)
end

local function NewMacroRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(MACRO_ROW_H)
    ns.Solid(row, "BACKGROUND", T.bg, St.ROW_FILL):SetAllPoints()
    ns.Border(row, St.BORDER_RGB)
    row.box = P.Box(row)
    row.box:SetPoint("LEFT", MACRO_INSET, 0)
    row.box:EnableMouse(false)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(MACRO_ICON, MACRO_ICON)
    row.icon:SetPoint("LEFT", row.box, "RIGHT", MACRO_INSET, 0)
    row.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    row.scope = P.Chip(row)
    row.scope:SetPoint("RIGHT", -MACRO_INSET, 0)
    row.onBars = P.Chip(row)
    row.onBars:SetPoint("RIGHT", row.scope, "LEFT", -TAG_GAP, 0)
    row.name = P.Label(row, NOTE_SIZE, T.fg)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", MACRO_INSET, 0)
    row.name:SetPoint("RIGHT", row.onBars, "LEFT", -WORD_GAP, 0)
    row.name:SetWordWrap(false)
    row.body = P.Mono(row, St.MONO_SIZE, T.muted)
    row.body:SetJustifyH("LEFT")
    row.body:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -LINE_GAP)
    row.body:SetPoint("RIGHT", row.onBars, "LEFT", -WORD_GAP, 0)
    row.body:SetWordWrap(false)
    row.onClick = MacroClicked
    row:SetScript("OnClick", P.Clicked)
    row:SetScript("OnEnter", MacroEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function NewKeyRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(KEY_ROW_H)
    ns.Solid(row, "BACKGROUND", T.bg, St.ROW_FILL):SetAllPoints()
    ns.Border(row, St.BORDER_RGB)
    local box = CreateFrame("Frame", nil, row)
    box:SetSize(KEY_W, KEY_H)
    box:SetPoint("LEFT", MACRO_INSET, 0)
    ns.Solid(box, "BACKGROUND", St.SLOT_BOTTOM_RGB, 1):SetAllPoints()
    ns.Border(box, St.BORDER_RGB)
    row.keyText = P.Mono(box, St.MONO_SIZE, T.fg)
    row.keyText:SetPoint("CENTER")
    row.what = P.Label(row, NOTE_SIZE, T.fg)
    row.what:SetPoint("LEFT", box, "RIGHT", MACRO_INSET, 0)
    row.what:SetPoint("RIGHT", -MACRO_INSET, 0)
    row.what:SetWordWrap(false)
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
    row.body:SetText((((macro.body or ""):gsub("[\r\n]+", BODY_JOIN))))
    P.PaintChip(row.scope, macro.perCharacter and TEXT.CHARACTER or TEXT.ACCOUNT,
        macro.perCharacter and St.CHARACTER_RGB or St.ACCOUNT_RGB)
    if locked then P.PaintChip(row.onBars, TEXT.ON_BARS, T.grey) else row.onBars:Hide() end
    local right = locked and row.onBars or row.scope
    row.name:SetPoint("RIGHT", right, "LEFT", -WORD_GAP, 0)
    row.body:SetPoint("RIGHT", right, "LEFT", -WORD_GAP, 0)
    row.tipTitle = macro.name
    row.tipLine = locked and TEXT.ON_BARS_TIP or TEXT.REUSE_TIP
    row.key, row.locked = key, locked
end

local function DrawMacros(v, slots, all, draw)
    local choices, content = draft.choices, v.macroContent
    local bars = OnBars(slots, choices.skip)
    local kept, scope = 0, { account = 0, character = 0 }
    local width = (content:GetWidth() - MACRO_GAP) / 2
    for i, macro in ipairs(all) do
        local key = Sets.MacroKey(macro.name, macro.body)
        local locked = bars[key]
        local on = locked or (choices.macros and not choices.macroOff[key])
        if on then kept = kept + 1 end
        local kind = macro.perCharacter and "character" or "account"
        scope[kind] = scope[kind] + 1
        if draw then
            local row = ns.UI.Keep(content, "macro", NewMacroRow)
            local column = (i - 1) % 2
            row:SetPoint("TOPLEFT", column * (width + MACRO_GAP), -math.floor((i - 1) / 2) * (MACRO_ROW_H + MACRO_GAP))
            row:SetWidth(width)
            PaintMacro(row, macro, key, locked, on, choices)
        end
    end
    if draw then content:SetHeight(math.max(1, math.ceil(#all / 2) * (MACRO_ROW_H + MACRO_GAP))) end
    return kept, scope
end

local function KeyLabel(command)
    local slot = slotOf[command]
    local kind, id = GetActionInfo(slot or 0)
    if kind == "spell" then return C_Spell.GetSpellName(id) end
    if kind == "macro" then return C_ActionBar.GetActionText(slot) end
    if kind == "item" then return C_Item.GetItemNameByID(id) end
    return _G["BINDING_NAME_" .. command] or command
end

local function ByKey(a, b) return a.key < b.key end

local function DrawKeyList(v, bindings)
    local content, petOff = v.macroContent, draft.choices.petOff
    wipe(keyList)
    for key, command in pairs(bindings) do
        if not (petOff and Capture.PetKey(command)) then keyList[#keyList + 1] = { key = key, command = command } end
    end
    table.sort(keyList, ByKey)
    local width = (content:GetWidth() - MACRO_GAP) / 2
    for i, bind in ipairs(keyList) do
        local row = ns.UI.Keep(content, "keybind", NewKeyRow)
        local column = (i - 1) % 2
        row:SetPoint("TOPLEFT", column * (width + MACRO_GAP), -math.floor((i - 1) / 2) * (KEY_ROW_H + MACRO_GAP))
        row:SetWidth(width)
        row:SetAlpha(draft.choices.keys and 1 or OFF_MACRO_ALPHA)
        row.keyText:SetText(ns.Shared.ActionKeys.Text(bind.key))
        row.what:SetText(KeyLabel(bind.command) or bind.command)
    end
    content:SetHeight(math.max(1, math.ceil(#keyList / 2) * (KEY_ROW_H + MACRO_GAP)))
end

local function BindingCount(bindings)
    local n, onBar, petOff = 0, 0, draft.choices.petOff
    for _, command in pairs(bindings) do
        if not (petOff and Capture.PetKey(command)) then
            n = n + 1
            if barButtons[command:match(BAR_COMMAND) or command] then onBar = onBar + 1 end
        end
    end
    return n, onBar
end

local function SaveDraft(thenCode)
    local name = strtrim(draft.box:GetText() or "")
    if name == "" then
        ns.Print(TEXT.NO_NAME)
        return
    end
    local function Done()
        local style = { icon = draft.icon, tags = #draft.tags > 0 and draft.tags or nil }
        local key = Sets.Save(name, draft.choices, style)
        if not key then return end
        W.Show("sets")
        if thenCode then A.Sharing.ShowExport(key) end
    end
    local existing = Sets.Find(name)
    if existing and existing ~= draft.key then
        ns.Confirm(TEXT.REPLACE:format(existing), Done)
    else
        Done()
    end
end

local function KeysOn() return draft.choices.keys end
local function SetKeys(on) draft.choices.keys = on; W.Redraw() end
local function MacrosOn() return draft.choices.macros end
local function SetMacros(on) draft.choices.macros = on; W.Redraw() end
local function HighestOn() return S.Get("highestRank") end
local function SetHighest(on) S.Set("highestRank", on) end
local function PetOn() return draft.choices.keys and not draft.choices.petOff end
local function SetPet(on)
    if not draft.choices.keys then return end
    draft.choices.petOff = not on or nil
    W.Redraw()
end
local function ViewPage() return viewPage end
local function SetViewPage(page) viewPage = page; W.Redraw() end

local function SetList(key)
    listTab = key
    W.Redraw()
end

local function SelectAll()
    local choices = draft.choices
    if next(choices.macroOff) then
        wipe(choices.macroOff)
    else
        for _, macro in ipairs(Sets.CaptureMacros()) do choices.macroOff[Sets.MacroKey(macro.name, macro.body)] = true end
    end
    W.Redraw()
end

local function BuildScene(v, top)
    v.scene = P.NewScene(v.frame)
    v.scene:SetPoint("TOPLEFT", 0, -top)
    v.scene:SetPoint("TOPRIGHT", 0, -top)
    P.ScenePicker(v.scene, picker.values, picker.order, ViewPage, SetViewPage)
end

local function Swatch(parent, after, text, edge, fill, mark)
    local swatch = CreateFrame("Frame", nil, parent)
    swatch:SetSize(SWATCH, SWATCH)
    if after then swatch:SetPoint("LEFT", after, "RIGHT", LEGEND_GAP, 0) else swatch:SetPoint("LEFT") end
    ns.Solid(swatch, "BACKGROUND", fill, 1):SetAllPoints()
    ns.Border(swatch, edge)
    if mark then
        local cross = swatch:CreateTexture(nil, "OVERLAY")
        cross:SetTexture(St.CROSS)
        cross:SetAllPoints()
    end
    local label = P.Label(parent, SMALL_SIZE, T.fg)
    label:SetPoint("LEFT", swatch, "RIGHT", LEGEND_TEXT_GAP, 0)
    label:SetText(text)
    return label
end

local function BuildLegend(v)
    local row = CreateFrame("Frame", nil, v.frame)
    row:SetPoint("TOPLEFT", v.scene, "BOTTOMLEFT", 0, -LINE_GAP)
    row:SetPoint("TOPRIGHT", v.scene, "BOTTOMRIGHT", 0, -LINE_GAP)
    row:SetHeight(LEGEND_H)
    local after = Swatch(row, nil, TEXT.GOES_IN, St.BORDER_RGB, T.accent)
    after = Swatch(row, after, TEXT.LEFT_OUT_LEGEND, T.muted, St.SLOT_TOP_RGB, true)
    Swatch(row, after, TEXT.KEPT_EMPTY_LEGEND, St.BORDER_RGB, St.SLOT_BOTTOM_RGB)
    v.legend = row
end

local function NewPart(panel, above, name, get, set)
    local part = CreateFrame("Frame", nil, panel)
    part:SetHeight(PART_H)
    part:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, above == panel.head and -PART_GAP or 0)
    part:SetPoint("RIGHT", -GLASS_PAD, 0)
    part.title = P.Label(part, St.NAME_SIZE, T.fg)
    part.title:SetPoint("TOPLEFT", 0, -PART_PAD)
    part.title:SetPoint("RIGHT", -(St.SWITCH_W + PART_PAD), 0)
    part.title:SetText(name)
    part.line = P.Label(part, SMALL_SIZE, T.muted)
    part.line:SetPoint("TOPLEFT", part.title, "BOTTOMLEFT", 0, -LINE_GAP)
    part.line:SetPoint("RIGHT", -(St.SWITCH_W + PART_PAD), 0)
    local rule = ns.Solid(part, "ARTWORK", St.BORDER_RGB, 1)
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    rule:SetHeight(1)
    if get then
        part.switch = P.Switch(part, get, set)
        part.switch:SetPoint("RIGHT")
    end
    return part
end

local function BuildParts(v, bottom)
    local panel = P.Glass(CreateFrame("Frame", nil, v.frame))
    panel:SetPoint("TOPLEFT", v.legend, "BOTTOMLEFT", 0, -LINE_GAP)
    panel:SetPoint("BOTTOMLEFT", 0, bottom)
    panel:SetWidth(LEFT_W)
    panel.head = P.Mono(panel, St.MONO_SIZE, St.GOLD_RGB)
    panel.head:SetPoint("TOPLEFT", GLASS_PAD, -GLASS_PAD)
    panel.head:SetText(TEXT.WHAT_GOES_IN)
    v.actions = NewPart(panel, panel.head, TEXT.ACTIONS_PART)
    v.keys = NewPart(panel, v.actions, TEXT.KEYBINDS, KeysOn, SetKeys)
    v.macros = NewPart(panel, v.keys, TEXT.MACROS, MacrosOn, SetMacros)
    v.highest = NewPart(panel, v.macros, TEXT.HIGHEST, HighestOn, SetHighest)
    v.highest.line:SetText(TEXT.HIGHEST_LINE)
    v.pet = NewPart(panel, v.highest, TEXT.PET_PART, PetOn, SetPet)
    v.keysSwitch, v.macrosSwitch = v.keys.switch, v.macros.switch
    v.parts = panel
end

local function BuildList(v, bottom)
    local list = P.Glass(CreateFrame("Frame", nil, v.frame))
    list:SetPoint("TOPLEFT", v.parts, "TOPRIGHT", GAP, 0)
    list:SetPoint("BOTTOMRIGHT", 0, bottom)
    v.listTabs = Parts.Tabs(list, LIST_TABS_W, { { key = "macros", label = TEXT.MACROS }, { key = "keys", label = TEXT.KEYBINDS } },
        SetList)
    v.listTabs:SetPoint("TOPLEFT", GLASS_PAD, -GLASS_PAD)
    v.selectAll = Parts.Link(list, SelectAll)
    v.selectAll:SetPoint("TOPRIGHT", -GLASS_PAD, -(GLASS_PAD + LINE_GAP))
    v.scopeText = P.Label(list, SMALL_SIZE, T.muted)
    v.scopeText:SetPoint("RIGHT", v.selectAll, "LEFT", -SUMMARY_GAP, 0)
    local inner = CreateFrame("Frame", nil, list)
    P.Place(inner, GLASS_PAD, GLASS_PAD + LIST_HEAD, GLASS_PAD, GLASS_PAD)
    v.macroScroll, v.macroContent = P.List(inner, 0)
end

local function UnFocus(box) box:ClearFocus() end

local function AutoIcon()
    for _, page in ipairs(P.STRIP_PAGES) do
        for i = 1, SLOTS_PER_BAR do
            local texture = GetActionTexture((page - 1) * SLOTS_PER_BAR + i)
            if texture then return texture end
        end
    end
    return A.C.QUESTION
end

local function PickIcon(tile)
    draft.icon = tile.texture
    tile:GetParent():Hide()
    W.Redraw()
end

local function IconTip(tile)
    if tile.texture then return end
    P.Hint(tile, TEXT.AUTO, TEXT.ICON_TIP)
end

local function NewPickerTile(grid, i)
    local tile = CreateFrame("Button", nil, grid)
    tile:SetSize(PICKER_TILE, PICKER_TILE)
    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetAllPoints()
    tile.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    ns.Border(tile, St.BORDER_RGB)
    local column, row = (i - 1) % PICKER_COLUMNS, math.floor((i - 1) / PICKER_COLUMNS)
    tile:SetPoint("TOPLEFT", GLASS_PAD + column * (PICKER_TILE + PICKER_GAP), -(GLASS_PAD + row * (PICKER_TILE + PICKER_GAP)))
    tile:SetScript("OnClick", PickIcon)
    tile:SetScript("OnEnter", IconTip)
    tile:SetScript("OnLeave", GameTooltip_Hide)
    return tile
end

local function FillPicker(grid)
    local seen, textures = {}, { false }
    for _, slot in ipairs(Sets.SlotList()) do
        local texture = GetActionTexture(slot)
        if texture and not seen[texture] and #textures < PICKER_MAX then
            seen[texture] = true
            textures[#textures + 1] = texture
        end
    end
    for i, texture in ipairs(textures) do
        local tile = grid.tiles[i] or NewPickerTile(grid, i)
        grid.tiles[i] = tile
        tile.texture = texture or nil
        tile.icon:SetTexture(texture or A.C.QUESTION)
        tile:Show()
    end
    for i = #textures + 1, #grid.tiles do grid.tiles[i]:Hide() end
    local rows = math.ceil(#textures / PICKER_COLUMNS)
    grid:SetSize(GLASS_PAD * 2 + PICKER_COLUMNS * (PICKER_TILE + PICKER_GAP) - PICKER_GAP,
        GLASS_PAD * 2 + rows * (PICKER_TILE + PICKER_GAP) - PICKER_GAP)
end

local function TogglePicker(v)
    local grid = v.iconGrid
    if grid:IsShown() then grid:Hide() return end
    FillPicker(grid)
    grid:Show()
end

local function RemoveTag(chip)
    table.remove(draft.tags, chip.index)
    W.Redraw()
end

local function AddTag()
    ns.PromptText(TEXT.NEW_TAG, "", TAG_MAX, function(text)
        local tag = strtrim(text or "")
        if tag == "" or #draft.tags >= MAX_TAGS then return end
        for _, have in ipairs(draft.tags) do if have:lower() == tag:lower() then return end end
        draft.tags[#draft.tags + 1] = tag
        W.Redraw()
    end)
end

local function TagEnter(chip)
    P.Hint(chip, chip.tag, TEXT.TAG_TIP)
end

local function NewTagChip(parent)
    local chip = CreateFrame("Button", nil, parent)
    chip:SetHeight(TAG_H)
    ns.Solid(chip, "BACKGROUND", St.SCENE_RGB, 1):SetAllPoints()
    ns.Border(chip, St.GOLD_RGB)
    chip.text = P.Mono(chip, St.MONO_SIZE, St.GOLD_RGB)
    chip.text:SetPoint("CENTER")
    chip:SetScript("OnClick", RemoveTag)
    chip:SetScript("OnEnter", TagEnter)
    chip:SetScript("OnLeave", GameTooltip_Hide)
    return chip
end

local function IconEnter(icon)
    P.Hint(icon, TEXT.ICON, TEXT.ICON_TIP)
end

local function BuildIdentity(v)
    v.icon = CreateFrame("Button", nil, v.frame)
    v.icon:SetSize(ICON_BUTTON, ICON_BUTTON)
    v.icon:SetPoint("TOPLEFT", 0, -VIEW_TOP)
    v.icon.texture = v.icon:CreateTexture(nil, "ARTWORK")
    v.icon.texture:SetAllPoints()
    v.icon.texture:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    ns.Border(v.icon, St.GOLD_RGB)
    v.icon:SetScript("OnClick", function() TogglePicker(v) end)
    v.icon:SetScript("OnEnter", IconEnter)
    v.icon:SetScript("OnLeave", GameTooltip_Hide)
    v.iconGrid = CreateFrame("Frame", nil, v.frame)
    v.iconGrid:SetPoint("TOPLEFT", v.icon, "BOTTOMLEFT", 0, -LINE_GAP)
    v.iconGrid:SetFrameLevel(v.frame:GetFrameLevel() + PICKER_LEVEL)
    v.iconGrid:EnableMouse(true)
    ns.Solid(v.iconGrid, "BACKGROUND", T.panel, 1):SetAllPoints()
    ns.Border(v.iconGrid, St.BORDER_RGB)
    v.iconGrid.tiles = {}
    v.iconGrid:Hide()
    local label = P.Mono(v.frame, St.MONO_SIZE, St.GOLD_RGB)
    label:SetPoint("TOPLEFT", v.icon, "TOPRIGHT", SUMMARY_GAP, 0)
    label:SetText(ns.Upper(TEXT.SET_NAME))
    v.box = ns.NewEditBox(v.frame)
    v.box:SetSize(NAME_W, NAME_H)
    v.box:SetMaxLetters(NAME_MAX)
    v.box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -LINE_GAP)
    v.box:SetScript("OnEnterPressed", UnFocus)
    v.box:SetScript("OnEscapePressed", UnFocus)
    v.tagsAt = P.Mono(v.frame, St.MONO_SIZE, St.GOLD_RGB)
    v.tagsAt:SetPoint("LEFT", label, "LEFT", NAME_W + TAGS_X, 0)
    v.tagsAt:SetText(ns.Upper(TEXT.TAGS))
    v.tagChips = {}
    v.addTag = ns.Button(v.frame, TEXT.ADD_TAG, ADD_TAG_W, TAG_H, AddTag)
end

local function NewCount(bar, after)
    local group = CreateFrame("Frame", nil, bar)
    group:SetHeight(COUNT_NUMBER)
    if after then group:SetPoint("LEFT", after, "RIGHT", COUNT_GAP, 0) else group:SetPoint("LEFT", GLASS_PAD, 0) end
    group.number = ns.Font(group, COUNT_NUMBER, nil, T.fg)
    group.number:SetPoint("LEFT")
    group.unit = P.Label(group, NOTE_SIZE, T.muted)
    group.unit:SetPoint("BOTTOMLEFT", group.number, "BOTTOMRIGHT", LINE_GAP * 2, 0)
    return group
end

local function PaintCount(group, n, one, many)
    group.number:SetText(n)
    group.unit:SetText(n == 1 and one or many)
    group:SetWidth(math.ceil(group.number:GetStringWidth() + group.unit:GetStringWidth()) + LINE_GAP * 2)
end

local function BuildSummary(v)
    local bar = P.Glass(CreateFrame("Frame", nil, v.frame))
    bar:SetPoint("BOTTOMLEFT")
    bar:SetPoint("BOTTOMRIGHT")
    bar:SetHeight(SUMMARY_BAR)
    v.button = P.Primary(ns.Button(bar, TEXT.SAVE_SET, SAVE_W, BUTTON_H, function() SaveDraft(false) end))
    v.button:SetPoint("RIGHT", -GLASS_PAD, 0)
    v.saveCode = ns.Button(bar, TEXT.SAVE_CODE, SAVE_CODE_W, BUTTON_H, function() SaveDraft(true) end)
    v.saveCode:SetPoint("RIGHT", v.button, "LEFT", -TAG_GAP * 2, 0)
    v.counts = {}
    v.counts.actions = NewCount(bar)
    v.counts.keys = NewCount(bar, v.counts.actions)
    v.counts.macros = NewCount(bar, v.counts.keys)
    v.leftOut = P.Label(bar, SMALL_SIZE, T.muted)
    v.leftOut:SetPoint("LEFT", v.counts.macros, "RIGHT", COUNT_GAP, 0)
    v.leftOut:SetPoint("RIGHT", v.saveCode, "LEFT", -SUMMARY_GAP, 0)
    v.leftOut:SetWordWrap(false)
end

local function PaintIdentity(v)
    v.icon.texture:SetTexture(draft.icon or AutoIcon())
    local after
    for i, tag in ipairs(draft.tags) do
        local chip = v.tagChips[i] or NewTagChip(v.frame)
        v.tagChips[i] = chip
        chip.index, chip.tag = i, tag
        chip.text:SetText(TEXT.TAG_CHIP:format(ns.Upper(tag)))
        chip:SetWidth(math.ceil(chip.text:GetStringWidth()) + TAG_PAD * 2)
        chip:ClearAllPoints()
        if after then
            chip:SetPoint("LEFT", after, "RIGHT", TAG_GAP, 0)
        else
            chip:SetPoint("TOPLEFT", v.tagsAt, "BOTTOMLEFT", 0, -LINE_GAP * 2)
        end
        chip:Show()
        after = chip
    end
    for i = #draft.tags + 1, #v.tagChips do v.tagChips[i]:Hide() end
    v.addTag:ClearAllPoints()
    if after then
        v.addTag:SetPoint("LEFT", after, "RIGHT", TAG_GAP, 0)
    else
        v.addTag:SetPoint("TOPLEFT", v.tagsAt, "BOTTOMLEFT", 0, -LINE_GAP * 2)
    end
    v.addTag:SetShown(#draft.tags < MAX_TAGS)
end

local function LeftOut()
    local skip, slots, bars = draft.choices.skip, 0, {}
    for _, entry in ipairs(order) do
        local _, out = Counts(entry.list, skip)
        if out == SLOTS_PER_BAR then
            if Counts(entry.list, {}) > 0 then bars[#bars + 1] = entry.bar.name end
        else
            slots = slots + out
        end
    end
    wipe(parts)
    if slots > 0 then parts[1] = Plural(slots, TEXT.SLOT_OUT, TEXT.SLOTS_OUT) end
    if #bars > 0 then parts[#parts + 1] = TEXT.BARS_OUT:format(table.concat(bars, ", ")) end
    return table.concat(parts, DOT)
end

local function ActionsLine()
    local skip, kept, out = draft.choices.skip, 0, 0
    for _, entry in ipairs(order) do
        local used, left = Counts(entry.list, skip)
        kept, out = kept + used, out + left
    end
    return TEXT.ACTIONS_LINE:format(kept, out), kept
end

local function DrawParts(v, keys, onBar, kept, all)
    local choices = draft.choices
    local line, actions = ActionsLine()
    v.actions.line:SetText(line)
    v.keys.line:SetText(choices.keys and TEXT.KEYS_ON:format(keys, onBar, keys - onBar) or TEXT.KEYS_OFF)
    v.macros.line:SetText(choices.macros and TEXT.MACROS_ON:format(kept, all) or TEXT.MACROS_OFF)
    v.pet:SetShown(PET_CLASSES[A.Class()] == true)
    v.pet.line:SetText(PetOn() and TEXT.PET_ON or TEXT.PET_OFF)
    for _, part in ipairs({ v.keys, v.macros, v.highest, v.pet }) do part.switch._refreshValue() end
    return actions
end

local function DrawCounts(v, actions, keys, kept)
    PaintCount(v.counts.actions, actions, TEXT.ACTION_UNIT, TEXT.ACTIONS_UNIT)
    PaintCount(v.counts.keys, keys, TEXT.KEYBIND_UNIT, TEXT.KEYBINDS_UNIT)
    v.counts.keys:SetShown(draft.choices.keys)
    v.counts.macros:ClearAllPoints()
    v.counts.macros:SetPoint("LEFT", draft.choices.keys and v.counts.keys or v.counts.actions, "RIGHT", COUNT_GAP, 0)
    PaintCount(v.counts.macros, kept, TEXT.MACRO_UNIT, TEXT.MACROS_UNIT)
    v.leftOut:SetText(LeftOut())
end

local function Draw(v)
    local slots, all, bindings = Sets.Capture(), Sets.CaptureMacros(), Sets.CaptureBindings()
    DrawScene(v)
    ns.UI.BeginReusableRows(v.macroContent)
    local kept, scope = DrawMacros(v, slots, all, listTab == "macros")
    if listTab == "keys" then DrawKeyList(v, bindings) end
    local keys, onBar = 0, 0
    if draft.choices.keys then keys, onBar = BindingCount(bindings) end
    Parts.SetTabs(v.listTabs, { { key = "macros", label = TEXT.LIST_MACROS:format(#all) },
        { key = "keys", label = TEXT.LIST_KEYS:format(keys) } })
    Parts.PaintTabs(v.listTabs, listTab)
    v.selectAll:SetShown(listTab == "macros" and draft.choices.macros)
    Parts.SetLink(v.selectAll, next(draft.choices.macroOff) and TEXT.SELECT_ALL or TEXT.SELECT_NONE)
    v.scopeText:SetShown(listTab == "macros")
    v.scopeText:SetText(TEXT.SCOPE:format(scope.account, scope.character))
    local actions = DrawParts(v, keys, onBar, kept, #all)
    DrawCounts(v, actions, keys, kept)
    PaintIdentity(v)
end

local function Order()
    pages, petCommands = P.Pages()
    forms = P.FormPages(pages)
    order = {}
    wipe(slotOf)
    for _, bar in ipairs(Sets.BARS) do
        local entry = pages[bar.page]
        entry.other = P.IsOther(bar.page, forms)
        order[#order + 1] = entry
        for i, command in ipairs(entry.commands) do slotOf[command] = slotOf[command] or entry.list[i] end
    end
end

function Builder.PickForm(chip)
    formPage = chip.page
    W.Redraw()
end

function Builder.NewDraft(key)
    local set = key and Sets.Get(key)
    local choices = set and set.choices or {}
    local tags = {}
    for i, tag in ipairs(set and set.tags or {}) do tags[i] = tag end
    draft = {
        key = set and key or nil, name = set and key or "", icon = set and set.icon, tags = tags,
        choices = { skip = Copy(choices.skip), macroOff = Copy(choices.macroOff),
            keys = choices.keys ~= false, macros = choices.macros ~= false, petOff = choices.petOff or nil },
    }
end

function Builder.HasDraft()
    return draft ~= nil
end

function Builder.Build(window)
    W = window
    local v = { cards = {} }
    v.frame = CreateFrame("Frame", nil, W.frame)
    v.frame:SetAllPoints()
    BuildIdentity(v)
    BuildScene(v, VIEW_TOP + IDENT_H + GAP)
    BuildLegend(v)
    BuildParts(v, SUMMARY_BAR + GAP)
    BuildList(v, SUMMARY_BAR + GAP)
    BuildSummary(v)
    v.title = TEXT.TITLE
    function v.Open()
        Order()
        viewPage, formPage, listTab = MAIN_VIEW, MAIN_PAGE, "macros"
        v.box:SetText(draft.name)
        draft.box = v.box
        v.iconGrid:Hide()
        v.title = draft.key and (TEXT.EDIT .. draft.key) or TEXT.TITLE
        v.subtitle = TEXT.SUBTITLE:format(UnitClass("player"))
    end
    function v.Draw() Draw(v) end
    v.events = { "ACTIONBAR_SLOT_CHANGED", "UPDATE_BINDINGS", "UPDATE_MACROS", "PET_BAR_UPDATE" }
    return v
end

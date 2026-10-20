-- Preview.lua: the Bar Sets tab's import preview: what changes, counted; your bars on the scene's strip now or as the import would leave them; then what comes across, what fills in later and the keys that change (ns.ActionBars.Preview).
local ns = _G.NaowhForever
local T = ns.THEME

local A = ns.ActionBars
local S = A.Settings
local St = A.Style
local P = A.Parts
local Sets = ns.ActionBarSets
local Import = A.Import
local Parts = ns.Shared.Parts

local VIEW_TOP, GAP, GLASS_PAD = St.VIEW_TOP, St.CARD_GAP, St.GLASS_PAD
local OUT_ALPHA, BUTTON_H, LINE_GAP = St.OUT_ALPHA, St.BUTTON_H, St.LINE_GAP
local NEW_RGB, LATER_RGB, GREEN_RGB, RED_RGB = St.NEW_RGB, St.LATER_RGB, St.GREEN_RGB, St.RED_RGB
local SMALL_SIZE, NOTE_SIZE, MONO_SIZE = St.SMALL_SIZE, St.NOTE_SIZE, St.MONO_SIZE
local MAIN_PAGE, LEFT_PAGE, TOP_PAGE, RIGHT_PAGE, MAIN_VIEW = P.MAIN_PAGE, P.LEFT_PAGE, P.TOP_PAGE, P.RIGHT_PAGE, P.MAIN_VIEW
local PET_BAR, PET_CLASSES = A.PET_BAR, A.PET_CLASSES
local DOT = St.PLACE_DOT
local LATER_ALPHA, SAME_ALPHA, LATER_FILL_ALPHA = 0.45, 0.35, 0.35
local PANELS, TILES = 3, 5
local STAT_H, STAT_STRIPE, STAT_NUMBER = 58, 3, 22
local MODE_W, MODE_H, MODE_GAP = 240, 26, 8
local LEGEND_H, SWATCH, SWATCH_EDGE, LEGEND_GAP, LEGEND_TEXT_GAP = 22, 12, 2, 18, 6
local ACTION_BAR = 52
local PANEL_HEAD_GAP, ROW_H, ROW_GAP, ROWS_SHOWN = 10, 28, 4, 6
local KEY_W, KEY_H = 64, 18
local BUTTON_GAP, CANCEL_W, TEST_W, IMPORT_W = 8, 100, 110, 170
local SAVED_DATE = "%d %b %Y"
local BODY_GREY = 0.8

local TEXT = {
    NOW = ns.L("Your bars now"),
    AFTER = ns.L("After import"),
    DIM = ns.L("Dim the slots that stay the same"),
    CAPTION = ns.L("Nothing changes until you press Import."),
    SLOTS_CHANGE = ns.L("slots change"),
    ADDED_TILE = ns.L("added to empty buttons"),
    CLEARED_TILE = ns.L("cleared"),
    LATER_TILE = ns.L("fill in as you learn"),
    MACROS_TILE = ns.L("macros made, %d already here"),
    MACROS_FULL = ns.L(", %d no room"),
    MACROS_OUT = ns.L("macros left out"),
    NEW_HERE = ns.L("New here"),
    SWAPPED = ns.L("Swapped"),
    CLEARED = ns.L("Cleared"),
    LATER_LEGEND = ns.L("Fills in when learned"),
    SAME_LEGEND = ns.L("Stays the same"),
    MACRO_LEGEND = ns.L("A macro made here"),
    CLEARED_TIP = ns.L("The set keeps this slot empty, so the import takes this off."),
    SWAPPED_TIP = ns.L("Something else is here now: the import swaps it."),
    BRING = ns.L("BRING ACROSS"),
    LATER_HEAD = ns.L("FILLS IN AS YOU LEARN"),
    KEYS_HEAD = ns.L("KEYS THAT CHANGE"),
    ACTIONS = ns.L("Actions"),
    MACROS = ns.L("Macros"),
    KEYBINDS = ns.L("Keybinds"),
    FILL = ns.L("Fill in as you learn them"),
    FILL_ALWAYS = ns.L("A website layout always fills in"),
    NONE_KEPT = ns.L("none in the set"),
    ALL_KNOWN = ns.L("Every spell in the set is known here."),
    FILL_OFF = ns.L("Fill in as you learn is off: these stay empty."),
    KEYS_SAME = ns.L("Every key already does what the set binds."),
    KEYS_OFF = ns.L("Off: your keys stay as they are."),
    NO_KEYS = ns.L("This set keeps no keybinds: your keys stay as they are."),
    KEY_CHANGE = "%s  ->  %s",
    UNBOUND = ns.L("nothing"),
    MORE = ns.L("and %d more"),
    BACKED_UP = ns.L("Your bars now are backed up first. Undo puts them back."),
    TEST = ns.L("Test Only"),
    CANCEL = ns.L("Cancel"),
    IMPORT = ns.L("Import"),
    IMPORT_N = ns.L("Import %d changes"),
    IMPORT_ONE = ns.L("Import 1 change"),
    TITLE = "Import",
    TITLE_KEY = ns.L("Import "),
    SUBTITLE = ns.L("Onto %s, level %d %s. Saved %s%s."),
    BY = ns.L(" by "),
    MAIN = ns.L("Main"),
    MAIN_BARS = ns.L("Main bars"),
    PET_BAR = ns.L("Pet Bar"),
    PICKED_BAR = "%s (%d)",
    CHIP = "%s %d",
    EMPTY_SLOT = ns.L("Empty slot"),
    NOT_IN_SET = ns.L("Not in the set: stays as it is."),
    PET_KEYS = ns.L("Only this button's keys come across."),
    LEVEL = ns.L("You learn this at level %d."),
    TRAIN = ns.L("Not known yet: train it, or take its talent."),
    GONE = ns.L("Cannot come back here, so the slot is left empty."),
    NEW_MACRO = ns.L("A macro this character does not have yet: the import makes it."),
    LVL = "LVL %d",
}
local BADGE_NEW, BADGE_LEVEL, BADGE_TRAIN, BADGE_GONE = "NEW", "LV", "TRAIN", "GONE"
local MODES = { { key = "now", label = TEXT.NOW }, { key = "after", label = TEXT.AFTER } }

local Preview = {}
A.Preview = Preview

local W, importKey, preview, keyFor, opts
local mode, dimSame = "after", true
local later, byCommand, slotOf, keyChanges = {}, {}, {}, {}
local counts = { added = 0, swapped = 0, cleared = 0, later = 0 }
local pages, petCommands, forms
local viewPage, formPage = MAIN_VIEW, MAIN_PAGE
local model = { regions = { left = {}, top = {}, bottom = {}, right = {} }, chips = {}, pet = nil }
local single, petLook, chipPool = {}, { keys = {} }, {}
local picker = { values = {}, order = {} }

local function MutedLine(tip, line)
    tip:AddLine(" ")
    tip:AddLine(line, T.muted.r, T.muted.g, T.muted.b, true)
end

local function EntryTip(entry, line)
    return function(tip)
        if entry.kind == "spell" then
            tip:SetSpellByID(entry.id)
        elseif entry.kind == "item" then
            tip:SetItemByID(entry.id)
        else
            tip:SetText(Sets.Describe(entry), 1, 1, 1)
            if entry.kind == "macro" and entry.body then tip:AddLine(entry.body, BODY_GREY, BODY_GREY, BODY_GREY, true) end
        end
        if line then MutedLine(tip, line) end
    end
end

local function PetTip(tip)
    tip:SetText(TEXT.PET_BAR, 1, 1, 1)
    MutedLine(tip, TEXT.PET_KEYS)
end

local function ActionTip(slot, line)
    return function(tip)
        if GetActionInfo(slot) then tip:SetAction(slot) else tip:SetText(TEXT.EMPTY_SLOT, 1, 1, 1) end
        if line then MutedLine(tip, line) end
    end
end

local function SetKey(command)
    local key = byCommand[command]
    return key and ns.Shared.ActionKeys.Text(key) or ""
end

local function PreviewKeys(set)
    if mode == "now" or not (set.bindings and opts.keys) then return P.KeyText end
    wipe(byCommand)
    for key, command in pairs(set.bindings) do
        if not byCommand[command] or #key < #byCommand[command] then byCommand[command] = key end
    end
    return SetKey
end

local function SameAction(slot, entry)
    local kind, id = GetActionInfo(slot)
    if kind ~= entry.kind then return false end
    if kind == "macro" then return C_ActionBar.GetActionText(slot) == entry.name end
    if kind == "spell" then return id == entry.id or C_Spell.GetSpellName(id) == A.Capture.SpellName(entry) end
    return id == entry.id
end

local function Change(slot, row)
    local state = row.state
    if state == "skip" then return nil end
    local here = GetActionInfo(slot) ~= nil
    if state == "clear" or state == "gone" or state == "later" then return here and "cleared" or nil end
    if not here then return "added" end
    return not SameAction(slot, row.entry) and "swapped" or nil
end

local function SameAlpha()
    return dimSame and SAME_ALPHA or 1
end

local function NowLook(slot, row, key)
    local change = Change(slot, row)
    local edge = (change == "cleared" and RED_RGB) or (change == "swapped" and T.accent) or nil
    local line = (change == "cleared" and TEXT.CLEARED_TIP) or (change == "swapped" and TEXT.SWAPPED_TIP) or nil
    return { texture = GetActionTexture(slot), key = key, edge = edge, alpha = change and 1 or SameAlpha(),
        tip = ActionTip(slot, line) }
end

local function LaterLook(entry, row, key)
    local level = row.level or 0
    local mine = UnitLevel("player")
    return { texture = P.EntryTexture(entry), key = key, alpha = LATER_ALPHA, grey = true, edge = LATER_RGB,
        badge = level > mine and (BADGE_LEVEL .. level) or BADGE_TRAIN, badgeColor = LATER_RGB,
        tip = EntryTip(entry, level > mine and TEXT.LEVEL:format(level) or TEXT.TRAIN) }
end

local function AfterLook(slot, row, key)
    local entry, state = row.entry, row.state
    local change = Change(slot, row)
    if state == "skip" then
        return { texture = GetActionTexture(slot), key = key, alpha = OUT_ALPHA, grey = true,
            tip = ActionTip(slot, TEXT.NOT_IN_SET) }
    end
    if state == "clear" then
        if not change then return { key = key } end
        return { texture = GetActionTexture(slot), key = key, alpha = OUT_ALPHA, grey = true, mark = true, edge = RED_RGB,
            tip = ActionTip(slot, TEXT.CLEARED_TIP) }
    end
    if state == "later" then return LaterLook(entry, row, key) end
    if state == "gone" then
        return { texture = P.EntryTexture(entry), key = key, alpha = OUT_ALPHA, grey = true,
            badge = BADGE_GONE, badgeColor = T.grey, tip = EntryTip(entry, TEXT.GONE) }
    end
    local edge = (change == "added" and GREEN_RGB) or (change == "swapped" and T.accent) or nil
    local line = (state == "new" and TEXT.NEW_MACRO) or (change == "swapped" and TEXT.SWAPPED_TIP) or nil
    return { texture = P.EntryTexture(entry), key = key, edge = edge, alpha = change and 1 or SameAlpha(),
        badge = state == "new" and BADGE_NEW or nil, badgeColor = NEW_RGB, tip = EntryTip(entry, line) }
end

local function Count()
    for k in pairs(counts) do counts[k] = 0 end
    for slot, row in pairs(preview.slots) do
        local change = Change(slot, row)
        if row.state == "later" then counts.later = counts.later + 1 end
        if change then counts[change] = counts[change] + 1 end
    end
    return counts.added + counts.swapped + counts.cleared
end

local function PaintSlot(tile, region, i)
    local slot = region.entry.list[i]
    local key = keyFor(region.entry.commands[i])
    local row = preview.slots[slot]
    P.PaintTile(tile, mode == "now" and NowLook(slot, row, key) or AfterLook(slot, row, key))
    tile.slot = slot
end

local function Placed(list)
    local placed = 0
    for _, slot in ipairs(list) do
        local row = preview.slots[slot]
        if row and (row.state == "ok" or row.state == "new") then placed = placed + 1 end
    end
    return placed
end

local function Region(region, entry, label, form)
    region.entry, region.label, region.form, region.out = entry, label or ns.L(entry.bar.name), form, false
    return region
end

local function DrawChips()
    wipe(model.chips)
    for i, page in ipairs(forms or {}) do
        local entry = pages[page]
        local chip = chipPool[i] or {}
        chipPool[i] = chip
        chip.text = TEXT.CHIP:format(page == MAIN_PAGE and TEXT.MAIN or entry.form, Placed(entry.list))
        chip.picked, chip.page, chip.onClick = page == formPage, page, Preview.PickForm
        model.chips[i] = chip
    end
end

local function DrawPet(set)
    if not PET_CLASSES[A.Class()] then
        model.pet = nil
        return
    end
    model.pet = petLook
    local off = set.choices and set.choices.petOff
    petLook.label, petLook.out = TEXT.PET_BAR, off or false
    petLook.tip = PetTip
    local keys = off and P.KeyText or keyFor
    for i = 1, PET_BAR.buttons do petLook.keys[i] = keys(petCommands[i]) end
end

local function DrawPicker()
    local values, list = picker.values, picker.order
    wipe(values)
    wipe(list)
    values[MAIN_VIEW], list[1] = TEXT.MAIN_BARS, MAIN_VIEW
    for _, bar in ipairs(A.BARS) do
        if P.IsOther(bar.page, forms) then
            values[bar.page] = TEXT.PICKED_BAR:format(ns.L(bar.name), Placed(pages[bar.page].list))
            list[#list + 1] = bar.page
        end
    end
end

local function DrawScene(v, set)
    keyFor = PreviewKeys(set)
    local regions = model.regions
    if not forms then formPage = MAIN_PAGE end
    local formName = formPage == MAIN_PAGE and TEXT.MAIN or pages[formPage].form
    Region(regions.left, pages[LEFT_PAGE])
    Region(regions.top, pages[TOP_PAGE])
    Region(regions.right, pages[RIGHT_PAGE])
    Region(regions.bottom, pages[formPage], ns.L(pages[MAIN_PAGE].bar.name) .. DOT .. formName, forms ~= nil)
    model.single = viewPage ~= MAIN_VIEW and pages[viewPage] and Region(single, pages[viewPage]) or nil
    DrawChips()
    DrawPet(set)
    DrawPicker()
    model.caption, model.Paint = TEXT.CAPTION, PaintSlot
    P.DrawScene(v.scene, model)
end

local function NewTile(parent, color)
    local tile = CreateFrame("Frame", nil, parent)
    tile:SetHeight(STAT_H)
    ns.Solid(tile, "BACKGROUND", T.panel, 1):SetAllPoints()
    ns.Border(tile, St.BORDER_RGB)
    local stripe = ns.Solid(tile, "ARTWORK", color, 1)
    stripe:SetPoint("TOPLEFT")
    stripe:SetPoint("TOPRIGHT")
    stripe:SetHeight(STAT_STRIPE)
    tile.number = ns.Font(tile, STAT_NUMBER, nil, T.fg)
    tile.number:SetPoint("TOPLEFT", GLASS_PAD, -(GLASS_PAD - LINE_GAP))
    tile.label = P.Label(tile, SMALL_SIZE, T.muted)
    tile.label:SetPoint("BOTTOMLEFT", GLASS_PAD, GLASS_PAD - LINE_GAP)
    tile.label:SetPoint("RIGHT", -GLASS_PAD, 0)
    tile.label:SetWordWrap(false)
    return tile
end

local function Swatch(parent, after, text, edge, fill, fillAlpha)
    local swatch = CreateFrame("Frame", nil, parent)
    swatch:SetSize(SWATCH, SWATCH)
    if after then swatch:SetPoint("LEFT", after, "RIGHT", LEGEND_GAP, 0) else swatch:SetPoint("LEFT") end
    ns.Solid(swatch, "BACKGROUND", fill or St.SLOT_TOP_RGB, fillAlpha or 1):SetAllPoints()
    if edge then ns.Border(swatch, edge):SetPixels(SWATCH_EDGE) end
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
    local after = Swatch(row, nil, TEXT.NEW_HERE, GREEN_RGB)
    after = Swatch(row, after, TEXT.SWAPPED, T.accent)
    after = Swatch(row, after, TEXT.CLEARED, RED_RGB)
    after = Swatch(row, after, TEXT.LATER_LEGEND, LATER_RGB, LATER_RGB, LATER_FILL_ALPHA)
    after = Swatch(row, after, TEXT.SAME_LEGEND, nil, T.accent, SAME_ALPHA)
    local chip = P.Chip(row)
    chip:SetPoint("LEFT", after, "RIGHT", LEGEND_GAP, 0)
    P.PaintChip(chip, BADGE_NEW, NEW_RGB)
    local text = P.Label(row, SMALL_SIZE, T.fg)
    text:SetPoint("LEFT", chip, "RIGHT", LEGEND_TEXT_GAP, 0)
    text:SetText(TEXT.MACRO_LEGEND)
    return row
end

local function Repreview()
    preview = Sets.Preview(importKey, opts)
    W.Redraw()
end

local function SetMode(key)
    mode = key
    W.Redraw()
end

local function ToggleDim()
    dimSame = not dimSame
    W.Redraw()
end

local function BuildModes(v, top)
    v.mode = Parts.Tabs(v.frame, MODE_W, MODES, SetMode)
    v.mode:SetPoint("TOPLEFT", 0, -top)
    v.dimText = P.Label(v.frame, SMALL_SIZE, T.fg)
    v.dimText:SetPoint("TOPRIGHT", 0, -(top + (MODE_H - SMALL_SIZE) / 2))
    v.dimText:SetText(TEXT.DIM)
    v.dim = P.Box(v.frame)
    v.dim:SetPoint("RIGHT", v.dimText, "LEFT", -MODE_GAP, 0)
    v.dim.onClick = ToggleDim
end

local function PanelHead(panel, text)
    local head = P.Mono(panel, MONO_SIZE, St.GOLD_RGB)
    head:SetPoint("TOPLEFT", GLASS_PAD, -GLASS_PAD)
    head:SetText(text)
    return head
end

local function RowY(i)
    return -(GLASS_PAD + MONO_SIZE + PANEL_HEAD_GAP + (i - 1) * (ROW_H + ROW_GAP))
end

local function PlaceRow(row, panel, i)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", GLASS_PAD, RowY(i))
    row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -GLASS_PAD, RowY(i))
    return row
end

local function NewChoiceRow(panel, i, onClick)
    local row = PlaceRow(CreateFrame("Button", nil, panel), panel, i)
    ns.Solid(row, "BACKGROUND", T.bg, St.ROW_FILL):SetAllPoints()
    ns.Border(row, St.BORDER_RGB)
    row.box = P.Box(row)
    row.box:SetPoint("LEFT", MODE_GAP, 0)
    row.box.onClick = onClick
    row.onClick = onClick
    row:SetScript("OnClick", P.Clicked)
    row.name = P.Label(row, NOTE_SIZE, T.fg)
    row.name:SetPoint("LEFT", row.box, "RIGHT", MODE_GAP, 0)
    row.count = P.Label(row, SMALL_SIZE, T.muted)
    row.count:SetPoint("RIGHT", -MODE_GAP, 0)
    return row
end

local function NewListRow(panel, i)
    local row = PlaceRow(CreateFrame("Frame", nil, panel), panel, i)
    row.chip = P.Chip(row)
    row.chip:SetPoint("RIGHT")
    row.name = P.Label(row, NOTE_SIZE, T.fg)
    row.name:SetPoint("LEFT")
    row.name:SetPoint("RIGHT", row.chip, "LEFT", -MODE_GAP, 0)
    row.name:SetWordWrap(false)
    return row
end

local function NewKeyRow(panel, i)
    local row = PlaceRow(CreateFrame("Frame", nil, panel), panel, i)
    local box = CreateFrame("Frame", nil, row)
    box:SetSize(KEY_W, KEY_H)
    box:SetPoint("LEFT")
    ns.Solid(box, "BACKGROUND", St.SLOT_BOTTOM_RGB, 1):SetAllPoints()
    ns.Border(box, St.BORDER_RGB)
    row.key = P.Mono(box, MONO_SIZE, T.fg)
    row.key:SetPoint("CENTER")
    row.text = P.Label(row, NOTE_SIZE, T.fg)
    row.text:SetPoint("LEFT", box, "RIGHT", MODE_GAP, 0)
    row.text:SetPoint("RIGHT")
    row.text:SetWordWrap(false)
    return row
end

local function ListPanel(v, after, head, newRow)
    local panel = P.Glass(CreateFrame("Frame", nil, v.frame))
    panel:SetPoint("TOPLEFT", after, "TOPRIGHT", GAP, 0)
    panel:SetPoint("BOTTOMLEFT", after, "BOTTOMRIGHT", GAP, 0)
    PanelHead(panel, head)
    panel.rows = {}
    for i = 1, ROWS_SHOWN do panel.rows[i] = newRow(panel, i) end
    panel.note = P.Label(panel, SMALL_SIZE, T.muted)
    panel.more = P.Label(panel, SMALL_SIZE, T.muted)
    panel.more:SetPoint("TOPLEFT", panel.rows[ROWS_SHOWN], "BOTTOMLEFT", 0, -LINE_GAP)
    return panel
end

local function Choice(key)
    return function()
        opts[key] = not opts[key]
        Repreview()
    end
end

local function ToggleFill()
    S.Set("fillLater", not S.Get("fillLater"))
end

local function BuildPanels(v)
    v.bring = P.Glass(CreateFrame("Frame", nil, v.frame))
    v.bring:SetPoint("TOPLEFT", v.legend, "BOTTOMLEFT", 0, -LINE_GAP)
    v.bring:SetPoint("BOTTOMLEFT", 0, ACTION_BAR + GAP)
    PanelHead(v.bring, TEXT.BRING)
    v.bring.rows = { NewChoiceRow(v.bring, 1, Choice("actions")), NewChoiceRow(v.bring, 2, Choice("macros")),
        NewChoiceRow(v.bring, 3, Choice("keys")), NewChoiceRow(v.bring, 4, ToggleFill) }
    v.later = ListPanel(v, v.bring, TEXT.LATER_HEAD, NewListRow)
    v.keys = ListPanel(v, v.later, TEXT.KEYS_HEAD, NewKeyRow)
end

local function ImportNow()
    if Sets.Import(importKey, false, opts) then W.Show("sets") end
end

local function TestNow()
    Sets.Import(importKey, true, opts)
end

local function Cancel()
    W.Show("sets")
end

local function BuildActionBar(v)
    local bar = P.Glass(CreateFrame("Frame", nil, v.frame))
    bar:SetPoint("BOTTOMLEFT")
    bar:SetPoint("BOTTOMRIGHT")
    bar:SetHeight(ACTION_BAR)
    local note = P.Label(bar, NOTE_SIZE, T.fg)
    note:SetPoint("LEFT", GLASS_PAD, 0)
    note:SetText(TEXT.BACKED_UP)
    v.import = P.Primary(ns.Button(bar, TEXT.IMPORT, IMPORT_W, BUTTON_H, ImportNow))
    v.import:SetPoint("RIGHT", -GLASS_PAD, 0)
    local cancel = ns.Button(bar, TEXT.CANCEL, CANCEL_W, BUTTON_H, Cancel)
    cancel:SetPoint("RIGHT", v.import, "LEFT", -BUTTON_GAP, 0)
    local test = ns.Button(bar, TEXT.TEST, TEST_W, BUTTON_H, TestNow)
    test:SetPoint("RIGHT", cancel, "LEFT", -BUTTON_GAP, 0)
end

local function BuildTiles(v)
    v.tiles = {}
    for i, color in ipairs({ T.accent, GREEN_RGB, RED_RGB, LATER_RGB, T.grey }) do
        local tile = NewTile(v.frame, color)
        if i == 1 then tile:SetPoint("TOPLEFT", 0, -VIEW_TOP) else tile:SetPoint("LEFT", v.tiles[i - 1], "RIGHT", GAP, 0) end
        v.tiles[i] = tile
    end
end

local function Widths(v, w)
    local tile = (w - GAP * (TILES - 1)) / TILES
    for _, t in ipairs(v.tiles) do t:SetWidth(tile) end
    local panel = (w - GAP * (PANELS - 1)) / PANELS
    v.bring:SetWidth(panel)
    v.later:SetWidth(panel)
    v.keys:SetWidth(panel)
end

local function Fates(fates)
    local new, have, full = 0, 0, 0
    for _, m in ipairs(fates) do
        if m.fate == "new" then new = new + 1 elseif m.fate == "have" then have = have + 1 else full = full + 1 end
    end
    return new, have, full
end

local function PaintStat(tile, number, label)
    tile.number:SetText(number)
    tile.label:SetText(label)
end

local function DrawTiles(v, changed)
    local tiles = v.tiles
    PaintStat(tiles[1], changed, TEXT.SLOTS_CHANGE)
    PaintStat(tiles[2], counts.added, TEXT.ADDED_TILE)
    PaintStat(tiles[3], counts.cleared, TEXT.CLEARED_TILE)
    PaintStat(tiles[4], counts.later, TEXT.LATER_TILE)
    if not opts.macros then
        PaintStat(tiles[5], 0, TEXT.MACROS_OUT)
        return
    end
    local new, have, full = Fates(preview.macros)
    local label = TEXT.MACROS_TILE:format(have)
    if full > 0 then label = label .. TEXT.MACROS_FULL:format(full) end
    PaintStat(tiles[5], new, label)
end

local function Size(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function PaintChoice(row, name, on, count, locked)
    row.name:SetText(name)
    row.count:SetText(count)
    P.PaintBox(row.box, on, locked)
end

local function DrawBring(v, set)
    local rows = v.bring.rows
    PaintChoice(rows[1], TEXT.ACTIONS, opts.actions, Size(set.slots))
    PaintChoice(rows[2], TEXT.MACROS, opts.macros, set.macros and #set.macros or TEXT.NONE_KEPT)
    PaintChoice(rows[3], TEXT.KEYBINDS, opts.keys, set.bindings and Size(set.bindings) or TEXT.NONE_KEPT)
    local always = set.choices and set.choices.website
    PaintChoice(rows[4], always and TEXT.FILL_ALWAYS or TEXT.FILL, always or S.Get("fillLater"), "", always)
    rows[4]:EnableMouse(not always)
end

local function PaintNote(panel, text, below)
    panel.note:SetShown(text ~= nil)
    panel.note:SetText(text or "")
    panel.note:ClearAllPoints()
    if below then
        panel.note:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -LINE_GAP)
    else
        panel.note:SetPoint("TOPLEFT", GLASS_PAD, RowY(1))
    end
    panel.note:SetPoint("RIGHT", -GLASS_PAD, 0)
end

local function PaintMore(panel, total)
    local more = total - ROWS_SHOWN
    panel.more:SetShown(more > 0)
    if more > 0 then panel.more:SetText(TEXT.MORE:format(more)) end
end

local function DrawLater(v, set)
    wipe(later)
    for _, slot in ipairs(Sets.SlotList()) do
        local row = preview.slots[slot]
        if row.state == "later" or row.state == "gone" then later[#later + 1] = row end
    end
    local panel, mine = v.later, UnitLevel("player")
    for i, line in ipairs(panel.rows) do
        local row = later[i]
        line:SetShown(row ~= nil)
        if row then
            line.name:SetText(Sets.Describe(row.entry))
            local level = row.level or 0
            if row.state == "gone" then
                P.PaintChip(line.chip, BADGE_GONE, T.grey)
            elseif level > mine then
                P.PaintChip(line.chip, TEXT.LVL:format(level), LATER_RGB)
            else
                P.PaintChip(line.chip, BADGE_TRAIN, LATER_RGB)
            end
        end
    end
    local filling = (set.choices and set.choices.website) or S.Get("fillLater")
    if #later == 0 then
        PaintNote(panel, TEXT.ALL_KNOWN)
    else
        PaintNote(panel, not filling and TEXT.FILL_OFF or nil, panel.rows[math.min(#later, ROWS_SHOWN)])
    end
    PaintMore(panel, #later)
end

local function ActionName(command, entry)
    if entry then return Sets.Describe(entry) end
    local slot = slotOf[command]
    local kind, id = GetActionInfo(slot or 0)
    if kind == "spell" then return C_Spell.GetSpellName(id) end
    if kind == "macro" then return C_ActionBar.GetActionText(slot) end
    if kind == "item" then return C_Item.GetItemNameByID(id) end
    return _G["BINDING_NAME_" .. command] or command
end

local function KeyChanges(set)
    wipe(keyChanges)
    if not (set.bindings and opts.keys) then return end
    for key, command in pairs(set.bindings) do
        local was = GetBindingAction(key)
        if was ~= command then
            keyChanges[#keyChanges + 1] = { key = key, was = was ~= "" and was or nil, now = command }
        end
    end
    table.sort(keyChanges, function(a, b) return a.key < b.key end)
end

local function DrawKeys(v, set)
    KeyChanges(set)
    local panel = v.keys
    for i, line in ipairs(panel.rows) do
        local change = keyChanges[i]
        line:SetShown(change ~= nil)
        if change then
            line.key:SetText(ns.Shared.ActionKeys.Text(change.key))
            local was = change.was and ActionName(change.was) or TEXT.UNBOUND
            line.text:SetText(TEXT.KEY_CHANGE:format(was, ActionName(change.now, set.slots[slotOf[change.now] or 0])))
        end
    end
    PaintNote(panel, (not set.bindings and TEXT.NO_KEYS) or (not opts.keys and TEXT.KEYS_OFF)
        or (#keyChanges == 0 and TEXT.KEYS_SAME) or nil)
    PaintMore(panel, #keyChanges)
end

local function ViewPage() return viewPage end
local function SetViewPage(page) viewPage = page; W.Redraw() end

local function Draw(v)
    local set = Sets.Get(importKey)
    if not set then W.Show("sets") return end
    local changed = Count()
    Parts.PaintTabs(v.mode, mode)
    P.PaintBox(v.dim, dimSame)
    DrawScene(v, set)
    DrawTiles(v, changed)
    DrawBring(v, set)
    DrawLater(v, set)
    DrawKeys(v, set)
    ns.SetButtonText(v.import, changed == 1 and TEXT.IMPORT_ONE or changed > 1 and TEXT.IMPORT_N:format(changed)
        or TEXT.IMPORT)
end

local function Open(v)
    local set = Sets.Get(importKey)
    v.title = TEXT.TITLE_KEY .. importKey
    v.subtitle = TEXT.SUBTITLE:format(UnitName("player"), UnitLevel("player"),
        UnitClass("player"), date(ns.L(SAVED_DATE), set.saved), set.by and (TEXT.BY .. set.by) or "")
    opts = Import.Options()
    preview = Sets.Preview(importKey, opts)
    pages, petCommands = P.Pages()
    forms = P.FormPages(pages)
    wipe(slotOf)
    for _, bar in ipairs(A.BARS) do
        local entry = pages[bar.page]
        for i, command in ipairs(entry.commands) do slotOf[command] = slotOf[command] or entry.list[i] end
    end
    viewPage, formPage, mode = MAIN_VIEW, MAIN_PAGE, "after"
end

function Preview.SetKey(key)
    importKey = key
end

function Preview.PickForm(chip)
    formPage = chip.page
    W.Redraw()
end

function Preview.Build(window)
    W = window
    local v = { cards = {} }
    v.frame = CreateFrame("Frame", nil, W.frame)
    v.frame:SetAllPoints()
    BuildTiles(v)
    local modeTop = VIEW_TOP + STAT_H + GAP
    BuildModes(v, modeTop)
    v.scene = P.NewScene(v.frame)
    v.scene:SetPoint("TOPLEFT", 0, -(modeTop + MODE_H + GAP))
    v.scene:SetPoint("TOPRIGHT", 0, -(modeTop + MODE_H + GAP))
    P.ScenePicker(v.scene, picker.values, picker.order, ViewPage, SetViewPage)
    v.legend = BuildLegend(v)
    BuildPanels(v)
    BuildActionBar(v)
    v.frame:SetScript("OnSizeChanged", function(_, w) Widths(v, w) end)
    v.title = TEXT.TITLE
    function v.Open() Open(v) end
    function v.Draw() Draw(v) end
    return v
end

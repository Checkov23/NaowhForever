-- Preview.lua: the Action Bars window's import preview: your bars on the scene's strip as an import would leave them, then what comes across (ns.ActionBars.Preview).
local ns = _G.NaowhForever
local T = ns.THEME

local A = ns.ActionBars
local S = A.Settings
local St = A.Style
local P = A.Parts
local Sets = ns.ActionBarSets

local WIDTH, CARD, GAP, GLASS_PAD = St.WIDTH, St.CARD, St.CARD_GAP, St.GLASS_PAD
local HEADER, FOOTER = St.WINDOW_HEADER, St.WINDOW_FOOTER
local OUT_ALPHA, BUTTON_H, LINE_GAP, CHIP_H = St.OUT_ALPHA, St.BUTTON_H, St.LINE_GAP, St.CHIP_H
local NEW_RGB, LATER_RGB = St.NEW_RGB, St.LATER_RGB
local SMALL_SIZE, NOTE_SIZE, NAME_SIZE = St.SMALL_SIZE, St.NOTE_SIZE, St.NAME_SIZE
local MAIN_PAGE, LEFT_PAGE, TOP_PAGE, RIGHT_PAGE, MAIN_VIEW = P.MAIN_PAGE, P.LEFT_PAGE, P.TOP_PAGE, P.RIGHT_PAGE, P.MAIN_VIEW
local PET_BAR, PET_CLASSES = A.PET_BAR, A.PET_CLASSES
local DOT = St.PLACE_DOT
local LATER_ALPHA = 0.45
local PANELS = 3
local ACTION_BAR = 46
local LEGEND_TEXT_GAP, LEGEND_GAP = 6, 18
local PANEL_LIST_TOP = 52
local FILL_H, FILL_GAP = 46, 10
local MACROS_SHOWN, NAMES_SHOWN, MACRO_LINE_PAD = 6, 6, 4
local BUTTON_GAP, CANCEL_W, IMPORT_W = 8, 110, 160
local SAVED_DATE = "%d %b %Y"
local BODY_GREY = 0.8

local TEXT_CAPTION = ns.L("Your bars after the import; nothing changes until you press Import.")
local TEXT_NEW_LEGEND = ns.L("a macro made on this character")
local TEXT_LATER_LEGEND = ns.L("not learned yet")
local TEXT_FILL = ns.L("Fill in as you learn them")
local TEXT_FILL_LINE = ns.L("A trained spell drops into its saved slot.")
local TEXT_FILL_ALWAYS = ns.L("Fills in as you learn them")
local TEXT_FILL_ALWAYS_LINE = ns.L("A website layout always does: each spell drops into its slot when learned.")
local TEXT_CANCEL, TEXT_IMPORT = ns.L("Cancel"), ns.L("Import")
local TEXT_TITLE = "Import"
local TEXT_TITLE_KEY = ns.L("Import ")
local TEXT_SUBTITLE = ns.L("Onto %s, level %d %s. Saved %s%s.")
local TEXT_BY = ns.L(" by ")
local TEXT_MAIN, TEXT_MAIN_BARS, TEXT_PET_BAR = ns.L("Main"), ns.L("Main bars"), ns.L("Pet Bar")
local TEXT_PICKED_BAR = "%s (%d)"
local TEXT_CHIP = "%s %d"
local TEXT_EMPTY_SLOT = ns.L("Empty slot")
local TEXT_NOT_IN_SET = ns.L("Not in the set: stays as it is.")
local TEXT_PET_KEYS = ns.L("Only this button's keys come across.")
local TEXT_LEVEL = ns.L("You learn this at level %d.")
local TEXT_TRAIN = ns.L("Not known yet: train it, or take its talent.")
local TEXT_GONE = ns.L("Cannot come back here, so the slot is left empty.")
local TEXT_NEW_MACRO = ns.L("A macro this character does not have yet: the import makes it.")
local TEXT_ACTION, TEXT_ACTIONS = ns.L("%d of %d action"), ns.L("%d of %d actions")
local TEXT_LATER_LINE = ns.L("%d you have not learned yet: %s.")
local TEXT_GONE_LINE = ns.L("%d cannot come back: %s.")
local TEXT_ALL_BACK = ns.L("Everything goes back where it was.")
local TEXT_MACROS = ns.L("Macros")
local TEXT_MACROS_OFF = ns.L("Import Macros is off: a macro this character lacks stays missing.")
local TEXT_MACRO, TEXT_MACROS_N = ns.L("%d macro"), ns.L("%d macros")
local TEXT_MACRO_FATES = ns.L("%s: %d new, %d already here")
local TEXT_NO_ROOM_COUNT = ns.L(", %d no room")
local TEXT_NO_MACROS = ns.L("No macros in this set")
local TEXT_MACROS_SAFE = ns.L("Your macros are never changed or copied twice.")
local TEXT_NEW, TEXT_HERE, TEXT_NO_ROOM = ns.L("New"), ns.L("Already here"), ns.L("No room")
local TEXT_MORE = ns.L("and %d more")
local TEXT_MORE_NAMES = ns.L(", and %d more")
local TEXT_NO_KEYS = ns.L("No keybinds in this set")
local TEXT_KEYS_STAY = ns.L("Your keys stay as they are.")
local TEXT_KEYBINDS = ns.L("Keybinds")
local TEXT_KEYS_OFF = ns.L("Import Keybinds is off: your keys stay as they are.")
local TEXT_KEYBIND, TEXT_KEYBINDS_N = ns.L("%d keybind"), ns.L("%d keybinds")
local TEXT_KEYS_FREE = ns.L("Keys the set leaves free keep what they do here.")
local BADGE_NEW, BADGE_LEVEL, BADGE_TRAIN, BADGE_GONE = "NEW", "LV", "TRAIN", "GONE"

local Plural = A.Plural

local Preview = {}
A.Preview = Preview

local W, importKey, preview, keyFor
local later, gone, byCommand = {}, {}, {}
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
    tip:SetText(TEXT_PET_BAR, 1, 1, 1)
    MutedLine(tip, TEXT_PET_KEYS)
end

local function SetKey(command)
    local key = byCommand[command]
    return key and ns.Shared.ActionKeys.Text(key) or ""
end

local function PreviewKeys(set)
    if not (set.bindings and S.Get("importBindings")) then return P.KeyText end
    wipe(byCommand)
    for key, command in pairs(set.bindings) do
        if not byCommand[command] or #key < #byCommand[command] then byCommand[command] = key end
    end
    return SetKey
end

local function SkipLook(slot, key)
    return { texture = GetActionTexture(slot), key = key, alpha = OUT_ALPHA, grey = true,
        tip = function(tip)
            if GetActionInfo(slot) then tip:SetAction(slot) else tip:SetText(TEXT_EMPTY_SLOT, 1, 1, 1) end
            MutedLine(tip, TEXT_NOT_IN_SET)
        end }
end

local function LaterLook(entry, row, key)
    local level = row.level or 0
    local mine = UnitLevel("player")
    return { texture = P.EntryTexture(entry), key = key, alpha = LATER_ALPHA, grey = true, edge = LATER_RGB,
        badge = level > mine and (BADGE_LEVEL .. level) or BADGE_TRAIN, badgeColor = LATER_RGB,
        tip = EntryTip(entry, level > mine and TEXT_LEVEL:format(level) or TEXT_TRAIN) }
end

local function PreviewLook(slot, row, key)
    local entry, state = row.entry, row.state
    if state == "skip" then return SkipLook(slot, key) end
    if state == "clear" then return { key = key } end
    if state == "later" then return LaterLook(entry, row, key) end
    if state == "gone" then
        return { texture = P.EntryTexture(entry), key = key, alpha = OUT_ALPHA, grey = true,
            badge = BADGE_GONE, badgeColor = T.grey, tip = EntryTip(entry, TEXT_GONE) }
    end
    return { texture = P.EntryTexture(entry), key = key, edge = state == "new" and T.accent or nil,
        badge = state == "new" and BADGE_NEW or nil, badgeColor = NEW_RGB,
        tip = EntryTip(entry, state == "new" and TEXT_NEW_MACRO or nil) }
end

local function PaintSlot(tile, region, i)
    local slot = region.entry.list[i]
    P.PaintTile(tile, PreviewLook(slot, preview.slots[slot], keyFor(region.entry.commands[i])))
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
        chip.text = TEXT_CHIP:format(page == MAIN_PAGE and TEXT_MAIN or entry.form, Placed(entry.list))
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
    petLook.label, petLook.out = TEXT_PET_BAR, off or false
    petLook.tip = PetTip
    local keys = off and P.KeyText or keyFor
    for i = 1, PET_BAR.buttons do petLook.keys[i] = keys(petCommands[i]) end
end

local function DrawPicker()
    local values, list = picker.values, picker.order
    wipe(values)
    wipe(list)
    values[MAIN_VIEW], list[1] = TEXT_MAIN_BARS, MAIN_VIEW
    for _, bar in ipairs(A.BARS) do
        if P.IsOther(bar.page, forms) then
            values[bar.page] = TEXT_PICKED_BAR:format(ns.L(bar.name), Placed(pages[bar.page].list))
            list[#list + 1] = bar.page
        end
    end
end

local function DrawScene(v, set)
    keyFor = PreviewKeys(set)
    local regions = model.regions
    if not forms then formPage = MAIN_PAGE end
    local formName = formPage == MAIN_PAGE and TEXT_MAIN or pages[formPage].form
    Region(regions.left, pages[LEFT_PAGE])
    Region(regions.top, pages[TOP_PAGE])
    Region(regions.right, pages[RIGHT_PAGE])
    Region(regions.bottom, pages[formPage], ns.L(pages[MAIN_PAGE].bar.name) .. DOT .. formName, forms ~= nil)
    model.single = viewPage ~= MAIN_VIEW and pages[viewPage] and Region(single, pages[viewPage]) or nil
    DrawChips()
    DrawPet(set)
    DrawPicker()
    model.caption, model.Paint = TEXT_CAPTION, PaintSlot
    P.DrawScene(v.scene, model)
end

local function Names(list, shown)
    local text = table.concat(list, ", ", 1, math.min(#list, shown))
    if #list > shown then text = text .. TEXT_MORE_NAMES:format(#list - shown) end
    return text
end

local function FillLater() return S.Get("fillLater") end
local function SetFillLater(on) S.Set("fillLater", on) end

local function BuildFill(v, panel)
    v.fill = CreateFrame("Frame", nil, panel)
    v.fill:SetHeight(FILL_H)
    ns.Solid(v.fill, "BACKGROUND", T.bg, St.ROW_FILL):SetAllPoints()
    ns.Border(v.fill, St.BORDER_RGB)
    v.fillName = P.Label(v.fill, NAME_SIZE, T.fg)
    v.fillName:SetPoint("TOPLEFT", GLASS_PAD, -GLASS_PAD + LINE_GAP)
    v.fillName:SetPoint("TOPRIGHT", -(GLASS_PAD * 2 + St.SWITCH_W), -GLASS_PAD + LINE_GAP)
    v.fillLine = P.Label(v.fill, SMALL_SIZE, T.muted)
    v.fillLine:SetPoint("TOPLEFT", v.fillName, "BOTTOMLEFT", 0, -St.STACK_GAP)
    v.fillLine:SetPoint("TOPRIGHT", v.fillName, "BOTTOMRIGHT", 0, -St.STACK_GAP)
    v.fillSwitch = P.Switch(v.fill, FillLater, SetFillLater)
    v.fillSwitch:SetPoint("RIGHT", -GLASS_PAD, 0)
end

local function BuildMacroRows(v, panel)
    v.macroRows = {}
    for i = 1, MACROS_SHOWN do
        local line = CreateFrame("Frame", nil, panel)
        line:SetHeight(CHIP_H + MACRO_LINE_PAD)
        local y = -(PANEL_LIST_TOP + (i - 1) * (CHIP_H + MACRO_LINE_PAD + LINE_GAP))
        line:SetPoint("TOPLEFT", GLASS_PAD, y)
        line:SetPoint("TOPRIGHT", -GLASS_PAD, y)
        line.name = P.Label(line, NOTE_SIZE, T.fg)
        line.name:SetPoint("LEFT")
        line.chip = P.Chip(line)
        line.chip:SetPoint("RIGHT")
        v.macroRows[i] = line
    end
    v.macroMore = P.Label(panel, SMALL_SIZE, T.muted)
    v.macroMore:SetPoint("TOPLEFT", v.macroRows[MACROS_SHOWN], "BOTTOMLEFT", 0, -LINE_GAP)
end

local function ImportNow()
    if Sets.Import(importKey) then W.Show("sets") end
end

local function Cancel()
    W.Show("sets")
end

local function Legend(bar)
    local newChip = P.Chip(bar)
    newChip:SetPoint("LEFT", GLASS_PAD, 0)
    P.PaintChip(newChip, BADGE_NEW, NEW_RGB)
    local newText = ns.Font(bar, SMALL_SIZE, nil, T.muted)
    newText:SetPoint("LEFT", newChip, "RIGHT", LEGEND_TEXT_GAP, 0)
    newText:SetText(TEXT_NEW_LEGEND)
    local laterChip = P.Chip(bar)
    laterChip:SetPoint("LEFT", newText, "RIGHT", LEGEND_GAP, 0)
    P.PaintChip(laterChip, BADGE_LEVEL, LATER_RGB)
    local laterText = ns.Font(bar, SMALL_SIZE, nil, T.muted)
    laterText:SetPoint("LEFT", laterChip, "RIGHT", LEGEND_TEXT_GAP, 0)
    laterText:SetText(TEXT_LATER_LEGEND)
end

local function BuildActionBar(v)
    local bar = P.Glass(CreateFrame("Frame", nil, v.frame))
    bar:SetPoint("BOTTOMLEFT", CARD, FOOTER + CARD)
    bar:SetPoint("BOTTOMRIGHT", -CARD, FOOTER + CARD)
    bar:SetHeight(ACTION_BAR)
    Legend(bar)
    v.import = P.Primary(ns.Button(bar, TEXT_IMPORT, IMPORT_W, BUTTON_H, ImportNow))
    v.import:SetPoint("RIGHT", -GLASS_PAD, 0)
    local cancel = ns.Button(bar, TEXT_CANCEL, CANCEL_W, BUTTON_H, Cancel)
    cancel:SetPoint("RIGHT", v.import, "LEFT", -BUTTON_GAP, 0)
end

local function BuildPanels(v)
    local bottom = FOOTER + CARD + ACTION_BAR + GAP
    local width = (WIDTH - CARD * 2 - GAP * (PANELS - 1)) / PANELS
    v.actions = P.GlassPanel(v.frame)
    v.actions:SetPoint("TOPLEFT", v.scene, "BOTTOMLEFT", 0, -GAP)
    v.actions:SetPoint("BOTTOMLEFT", CARD, bottom)
    v.actions:SetWidth(width)
    v.macros = P.GlassPanel(v.frame)
    v.macros:SetPoint("TOPLEFT", v.actions, "TOPRIGHT", GAP, 0)
    v.macros:SetPoint("BOTTOMLEFT", v.actions, "BOTTOMRIGHT", GAP, 0)
    v.macros:SetWidth(width)
    v.keys = P.GlassPanel(v.frame)
    v.keys:SetPoint("TOPLEFT", v.macros, "TOPRIGHT", GAP, 0)
    v.keys:SetPoint("BOTTOMLEFT", v.macros, "BOTTOMRIGHT", GAP, 0)
    v.keys:SetWidth(width)
    BuildFill(v, v.actions)
    BuildMacroRows(v, v.macros)
end

local function Collect()
    wipe(later)
    wipe(gone)
    for _, slot in ipairs(Sets.SlotList()) do
        local row = preview.slots[slot]
        if row.state == "later" then later[#later + 1] = Sets.Describe(row.entry) end
        if row.state == "gone" then gone[#gone + 1] = Sets.Describe(row.entry) end
    end
end

local function DrawActions(v)
    Collect()
    local total = preview.actions
    v.actions.title:SetText((total == 1 and TEXT_ACTION or TEXT_ACTIONS):format(preview.placed, total))
    local lines = {}
    if #later > 0 then lines[#lines + 1] = TEXT_LATER_LINE:format(#later, Names(later, NAMES_SHOWN)) end
    if #gone > 0 then lines[#lines + 1] = TEXT_GONE_LINE:format(#gone, Names(gone, NAMES_SHOWN)) end
    v.actions.line:SetText(#lines > 0 and table.concat(lines, " ") or TEXT_ALL_BACK)
end

local function DrawFill(v, set)
    local always = set.choices and set.choices.website
    v.fillName:SetText(always and TEXT_FILL_ALWAYS or TEXT_FILL)
    v.fillLine:SetText(always and TEXT_FILL_ALWAYS_LINE or TEXT_FILL_LINE)
    v.fillSwitch:SetShown(not always)
    v.fill:SetShown(#later > 0)
    v.fill:ClearAllPoints()
    v.fill:SetPoint("TOPLEFT", v.actions.line, "BOTTOMLEFT", 0, -FILL_GAP)
    v.fill:SetPoint("TOPRIGHT", v.actions.line, "BOTTOMRIGHT", 0, -FILL_GAP)
    v.fillSwitch._refreshValue()
end

local function Fates(fates)
    local new, have, full = 0, 0, 0
    for _, m in ipairs(fates) do
        if m.fate == "new" then new = new + 1 elseif m.fate == "have" then have = have + 1 else full = full + 1 end
    end
    return new, have, full
end

local function DrawMacroTitle(v, fates)
    if not S.Get("importMacros") then
        v.macros.title:SetText(TEXT_MACROS)
        v.macros.line:SetText(TEXT_MACROS_OFF)
        return
    end
    local new, have, full = Fates(fates)
    local title = TEXT_MACRO_FATES:format(Plural(#fates, TEXT_MACRO, TEXT_MACROS_N), new, have)
    if full > 0 then title = title .. TEXT_NO_ROOM_COUNT:format(full) end
    v.macros.title:SetText(#fates > 0 and title or TEXT_NO_MACROS)
    v.macros.line:SetText(TEXT_MACROS_SAFE)
end

local function PaintFate(line, m)
    line.name:SetText(m.name)
    if m.fate == "new" then
        P.PaintChip(line.chip, TEXT_NEW, NEW_RGB)
    elseif m.fate == "have" then
        P.PaintChip(line.chip, TEXT_HERE, T.grey)
    else
        P.PaintChip(line.chip, TEXT_NO_ROOM, St.RED_RGB)
    end
end

local function DrawMacroRows(v, fates)
    local on = S.Get("importMacros")
    for i, line in ipairs(v.macroRows) do
        local m = on and fates[i]
        line:SetShown(m and true or false)
        if m then PaintFate(line, m) end
    end
    local more = on and #fates - MACROS_SHOWN or 0
    v.macroMore:SetShown(more > 0)
    if more > 0 then v.macroMore:SetText(TEXT_MORE:format(more)) end
end

local function DrawKeys(v, set)
    if not set.bindings then
        v.keys.title:SetText(TEXT_NO_KEYS)
        v.keys.line:SetText(TEXT_KEYS_STAY)
    elseif not S.Get("importBindings") then
        v.keys.title:SetText(TEXT_KEYBINDS)
        v.keys.line:SetText(TEXT_KEYS_OFF)
    else
        v.keys.title:SetText(Plural(preview.bound or 0, TEXT_KEYBIND, TEXT_KEYBINDS_N))
        v.keys.line:SetText(TEXT_KEYS_FREE)
    end
end

local function ViewPage() return viewPage end
local function SetViewPage(page) viewPage = page; W.Redraw() end

local function Draw(v)
    local set = Sets.Get(importKey)
    if not set then W.Show("sets") return end
    DrawScene(v, set)
    DrawActions(v)
    DrawFill(v, set)
    DrawMacroTitle(v, preview.macros)
    DrawMacroRows(v, preview.macros)
    DrawKeys(v, set)
end

local function Open(v)
    local set = Sets.Get(importKey)
    v.title = TEXT_TITLE_KEY .. importKey
    v.subtitle = TEXT_SUBTITLE:format(UnitName("player"), UnitLevel("player"),
        UnitClass("player"), date(ns.L(SAVED_DATE), set.saved), set.by and (TEXT_BY .. set.by) or "")
    preview = Sets.Preview(importKey)
    pages, petCommands = P.Pages()
    forms = P.FormPages(pages)
    viewPage, formPage = MAIN_VIEW, MAIN_PAGE
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
    local top = HEADER + CARD
    v.frame = CreateFrame("Frame", nil, W.frame)
    v.frame:SetAllPoints()
    v.scene = P.NewScene(v.frame)
    v.scene:SetPoint("TOPLEFT", CARD, -top)
    v.scene:SetPoint("TOPRIGHT", -CARD, -top)
    P.ScenePicker(v.scene, picker.values, picker.order, ViewPage, SetViewPage)
    BuildPanels(v)
    BuildActionBar(v)
    v.title = TEXT_TITLE
    function v.Open() Open(v) end
    function v.Draw() Draw(v) end
    return v
end

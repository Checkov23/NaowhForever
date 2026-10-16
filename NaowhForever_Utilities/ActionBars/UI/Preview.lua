-- Preview.lua: the Action Bars window's import preview: your bars as an import would leave them, then what comes across (ns.ActionBars.Preview).
local ns = _G.NaowhForever
local T = ns.THEME

local A = ns.ActionBars
local S = A.Settings
local St = A.Style
local P = A.Parts
local Sets = ns.ActionBarSets

local WIDTH, CARD, SIDE_W, GAP, INNER = St.WIDTH, St.CARD, St.SIDE_W, St.CARD_GAP, St.INNER
local HEADER, FOOTER = St.WINDOW_HEADER, St.WINDOW_FOOTER
local ROW_PAD, ROW_GAP, ROW_FILL, OUT_ALPHA = St.ROW_PAD, St.ROW_GAP, St.ROW_FILL, St.OUT_ALPHA
local BUTTON_H, LINE_GAP, HEADING_H, CHIP_H = St.BUTTON_H, St.LINE_GAP, St.HEADING_H, St.CHIP_H
local NEW_RGB, LATER_RGB, GOOD_RGB, BLACK = St.NEW_RGB, St.LATER_RGB, St.GOOD_RGB, St.BORDER_RGB
local SMALL_SIZE, NOTE_SIZE, NAME_SIZE, TITLE_SIZE = St.SMALL_SIZE, St.NOTE_SIZE, St.NAME_SIZE, St.TITLE_SIZE
local QUESTION = A.C.QUESTION
local LATER_ALPHA = 0.45
local NAME_DROP = 2
local LEGEND_RISE, LEGEND_TEXT_GAP, LEGEND_GAP = 4, 6, 18
local MARK, MARK_FILL, MARK_ICON_PAD = 24, 0.35, 10
local TEXT_X, FACT_GAP, FACTS_TOP, TITLE_RISE, STACK_GAP = MARK + 10, 14, 28, 1, St.STACK_GAP
local FILL_H, FILL_INSET_X, FILL_INSET_Y = 46, 10, 8
local MACROS_SHOWN, NAMES_SHOWN, MACRO_LINE_PAD = 5, 6, 4
local BUTTON_GAP, CANCEL_SHARE, FILL_W = 8, 3, St.FILL_W
local SAVED_DATE = "%d %b %Y"
local BODY_GREY = 0.8

local TEXT_HEADING = ns.L("YOUR BARS AFTER THE IMPORT")
local TEXT_HEADING_HINT = ns.L("Nothing changes until you press Import.")
local TEXT_NEW_LEGEND = ns.L("a macro made on this character")
local TEXT_LATER_LEGEND = ns.L("not learned yet")
local TEXT_SIDE = ns.L("WHAT COMES ACROSS")
local TEXT_FILL = ns.L("Fill in as you learn them")
local TEXT_FILL_LINE = ns.L("A trained spell drops into its saved slot.")
local TEXT_KEY_LETTER = "K"
local TEXT_CANCEL, TEXT_IMPORT = ns.L("Cancel"), ns.L("Import")
local TEXT_TITLE = "Import"
local TEXT_TITLE_KEY = ns.L("Import ")
local TEXT_SUBTITLE = ns.L("Onto %s, level %d %s. Saved %s%s.")
local TEXT_BY = ns.L(" by ")
local TEXT_EMPTY_SLOT = ns.L("Empty slot")
local TEXT_NOT_IN_SET = ns.L("Not in the set: stays as it is.")
local TEXT_LEVEL = ns.L("You learn this at level %d.")
local TEXT_TRAIN = ns.L("Not known yet: train it, or take its talent.")
local TEXT_GONE = ns.L("Cannot come back here, so the slot is left empty.")
local TEXT_NEW_MACRO = ns.L("A macro this character does not have yet: the import makes it.")
local TEXT_COUNT = "%d / %d"
local TEXT_ACTIONS = ns.L("%d of %d actions")
local TEXT_LATER_LINE = ns.L("%d you have not learned yet: %s.")
local TEXT_GONE_LINE = ns.L("%d cannot come back: %s.")
local TEXT_ALL_BACK = ns.L("Everything goes back where it was.")
local TEXT_MACROS = ns.L("Macros")
local TEXT_MACROS_OFF = ns.L("Import Macros is off: a macro this character lacks stays missing.")
local TEXT_MACRO_FATES = ns.L("%d macros: %d new, %d already here")
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
local TEXT_KEY_COUNT = ns.L("%d keybinds")
local TEXT_KEYS_FREE = ns.L("Keys the set leaves free keep what they do here.")
local BADGE_NEW, BADGE_LEVEL, BADGE_TRAIN, BADGE_GONE = "NEW", "LV", "TRAIN", "GONE"

local Preview = {}
A.Preview = Preview

local W, importKey, preview
local later, gone, byCommand = {}, {}, {}

local function EntryTexture(entry)
    if entry.kind == "spell" then return C_Spell.GetSpellTexture(entry.id) end
    if entry.kind == "macro" then return entry.icon end
    if entry.kind == "item" then return C_Item.GetItemIconByID(entry.id) end
    return QUESTION
end

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
    return { texture = EntryTexture(entry), key = key, alpha = LATER_ALPHA, grey = true, edge = LATER_RGB,
        badge = level > mine and (BADGE_LEVEL .. level) or BADGE_TRAIN, badgeColor = LATER_RGB,
        tip = EntryTip(entry, level > mine and TEXT_LEVEL:format(level) or TEXT_TRAIN) }
end

local function PreviewLook(slot, row, key)
    local entry, state = row.entry, row.state
    if state == "skip" then return SkipLook(slot, key) end
    if state == "clear" then return { key = key } end
    if state == "later" then return LaterLook(entry, row, key) end
    if state == "gone" then
        return { texture = EntryTexture(entry), key = key, alpha = OUT_ALPHA, grey = true,
            badge = BADGE_GONE, badgeColor = T.grey, tip = EntryTip(entry, TEXT_GONE) }
    end
    return { texture = EntryTexture(entry), key = key, edge = state == "new" and T.accent or nil,
        badge = state == "new" and BADGE_NEW or nil, badgeColor = NEW_RGB,
        tip = EntryTip(entry, state == "new" and TEXT_NEW_MACRO or nil) }
end

local function BarShown(list)
    for _, slot in ipairs(list) do
        local row = preview.slots[slot]
        if row and (row.entry or (row.state == "skip" and GetActionInfo(slot))) then return true end
    end
    return false
end

local function PaintBar(row, bar, list, keyFor)
    local placed, total = 0, 0
    for i, slot in ipairs(list) do
        local result = preview.slots[slot]
        if result.entry and result.state ~= "skip" then
            total = total + 1
            if result.state == "ok" or result.state == "new" then placed = placed + 1 end
        end
        P.PaintTile(row.tiles[i], PreviewLook(slot, result, keyFor(bar.button .. i)))
    end
    row.count:SetText(TEXT_COUNT:format(placed, total))
end

local function DrawBars(v, set)
    local content = v.content
    ns.UI.BeginReusableRows(content)
    local keyFor, y = PreviewKeys(set), 0
    for _, bar in ipairs(Sets.BARS) do
        local list = P.BarSlots(bar)
        if BarShown(list) then
            local row = ns.UI.Keep(content, "bar", P.NewBarRow)
            row:SetPoint("TOPLEFT", 0, y)
            row:SetPoint("TOPRIGHT", 0, y)
            row:SetAlpha(1)
            row.box:Hide()
            row.name:ClearAllPoints()
            row.name:SetPoint("TOPLEFT", ROW_PAD, -ROW_PAD - NAME_DROP)
            row.name:SetText(bar.name)
            PaintBar(row, bar, list, keyFor)
            y = y - row:GetHeight() - ROW_GAP
        end
    end
    content:SetHeight(math.max(1, -y))
end

local function NewMarker(parent, texture, color)
    local mark = CreateFrame("Frame", nil, parent)
    mark:SetSize(MARK, MARK)
    mark.fill = ns.Solid(mark, "BACKGROUND", color, MARK_FILL)
    mark.fill:SetAllPoints()
    ns.Border(mark, BLACK)
    mark.icon = mark:CreateTexture(nil, "ARTWORK")
    mark.icon:SetTexture(texture)
    mark.icon:SetSize(MARK - MARK_ICON_PAD, MARK - MARK_ICON_PAD)
    mark.icon:SetPoint("CENTER")
    mark.icon:SetVertexColor(color.r, color.g, color.b, 1)
    return mark
end

local function NewFact(pane, texture, color)
    local fact = { mark = NewMarker(pane, texture, color) }
    fact.title = P.Label(pane, TITLE_SIZE, T.fg)
    fact.title:SetPoint("TOPLEFT", fact.mark, "TOPRIGHT", TEXT_X - MARK, TITLE_RISE)
    fact.title:SetPoint("RIGHT")
    fact.line = P.Label(pane, SMALL_SIZE, T.muted)
    fact.line:SetPoint("TOPLEFT", fact.title, "BOTTOMLEFT", 0, -STACK_GAP)
    fact.line:SetPoint("RIGHT")
    return fact
end

local function Names(list, shown)
    local text = table.concat(list, ", ", 1, math.min(#list, shown))
    if #list > shown then text = text .. TEXT_MORE_NAMES:format(#list - shown) end
    return text
end

local function Legend(bars)
    local newChip = P.Chip(bars)
    newChip:SetPoint("BOTTOMLEFT", 0, LEGEND_RISE)
    P.PaintChip(newChip, BADGE_NEW, NEW_RGB)
    local newText = ns.Font(bars, SMALL_SIZE, nil, T.muted)
    newText:SetPoint("LEFT", newChip, "RIGHT", LEGEND_TEXT_GAP, 0)
    newText:SetText(TEXT_NEW_LEGEND)
    local laterChip = P.Chip(bars)
    laterChip:SetPoint("LEFT", newText, "RIGHT", LEGEND_GAP, 0)
    P.PaintChip(laterChip, BADGE_LEVEL, LATER_RGB)
    local laterText = ns.Font(bars, SMALL_SIZE, nil, T.muted)
    laterText:SetPoint("LEFT", laterChip, "RIGHT", LEGEND_TEXT_GAP, 0)
    laterText:SetText(TEXT_LATER_LEGEND)
end

local function FillLater() return S.Get("fillLater") end
local function SetFillLater(on) S.Set("fillLater", on) end

local function BuildFill(v, side)
    v.fill = CreateFrame("Frame", nil, side)
    v.fill:SetHeight(FILL_H)
    v.fill:SetPoint("LEFT")
    v.fill:SetPoint("RIGHT")
    ns.Solid(v.fill, "BACKGROUND", T.bg, ROW_FILL):SetAllPoints()
    ns.Border(v.fill, BLACK)
    local fillName = P.Label(v.fill, NAME_SIZE, T.fg)
    fillName:SetPoint("TOPLEFT", FILL_INSET_X, -FILL_INSET_Y)
    fillName:SetText(TEXT_FILL)
    local fillLine = P.Label(v.fill, SMALL_SIZE, T.muted)
    fillLine:SetPoint("TOPLEFT", fillName, "BOTTOMLEFT", 0, -STACK_GAP)
    fillLine:SetText(TEXT_FILL_LINE)
    v.fillSwitch = P.Switch(v.fill, FillLater, SetFillLater)
    v.fillSwitch:SetPoint("RIGHT", -FILL_INSET_X, 0)
end

local function BuildMacroRows(v, side)
    v.macroRows = {}
    for i = 1, MACROS_SHOWN do
        local line = CreateFrame("Frame", nil, side)
        line:SetHeight(CHIP_H + MACRO_LINE_PAD)
        line.name = P.Label(line, NOTE_SIZE, T.fg)
        line.name:SetPoint("LEFT")
        line.chip = P.Chip(line)
        line.chip:SetPoint("RIGHT")
        v.macroRows[i] = line
    end
    v.macroMore = P.Label(side, SMALL_SIZE, T.muted)
end

local function ImportNow()
    if Sets.Import(importKey) then W.Show("sets") end
end

local function Cancel()
    W.Show("sets")
end

local function BuildButtons(v, side)
    local cancel = ns.Button(side, TEXT_CANCEL, (SIDE_W - 2 * INNER - BUTTON_GAP) / CANCEL_SHARE, BUTTON_H, Cancel)
    v.import = ns.AccentBorder(ns.Button(side, TEXT_IMPORT, FILL_W, BUTTON_H, ImportNow))
    cancel:SetPoint("BOTTOMLEFT")
    v.import:SetPoint("BOTTOMRIGHT")
    v.import:SetPoint("LEFT", cancel, "RIGHT", BUTTON_GAP, 0)
end

local function BuildSide(v, side)
    P.Heading(side, TEXT_SIDE)
    v.actions = NewFact(side, St.TICK, GOOD_RGB)
    v.actions.mark:SetPoint("TOPLEFT", 0, -FACTS_TOP)
    BuildFill(v, side)
    v.macros = NewFact(side, St.PLUS, T.accentSoft)
    BuildMacroRows(v, side)
    v.keys = NewFact(side, St.TICK, T.muted)
    v.keys.mark.icon:Hide()
    v.keys.letter = ns.Font(v.keys.mark, SMALL_SIZE, nil, T.fg)
    v.keys.letter:SetPoint("CENTER")
    v.keys.letter:SetText(TEXT_KEY_LETTER)
    BuildButtons(v, side)
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
    v.actions.title:SetText(TEXT_ACTIONS:format(preview.placed, preview.actions))
    local lines = {}
    if #later > 0 then lines[#lines + 1] = TEXT_LATER_LINE:format(#later, Names(later, NAMES_SHOWN)) end
    if #gone > 0 then lines[#lines + 1] = TEXT_GONE_LINE:format(#gone, Names(gone, NAMES_SHOWN)) end
    v.actions.line:SetText(#lines > 0 and table.concat(lines, " ") or TEXT_ALL_BACK)
end

local function DrawFill(v)
    v.fill:SetShown(#later > 0)
    v.macros.mark:ClearAllPoints()
    if #later == 0 then
        v.macros.mark:SetPoint("TOPLEFT", v.actions.line, "BOTTOMLEFT", -TEXT_X, -FACT_GAP)
        return
    end
    v.fill:ClearAllPoints()
    v.fill:SetPoint("TOPLEFT", v.actions.line, "BOTTOMLEFT", -TEXT_X, -FACT_GAP)
    v.fill:SetPoint("RIGHT", v.actions.title, "RIGHT")
    v.fillSwitch._refreshValue()
    v.macros.mark:SetPoint("TOPLEFT", v.fill, "BOTTOMLEFT", 0, -FACT_GAP)
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
    local title = TEXT_MACRO_FATES:format(#fates, new, have)
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
    local last = v.macros.line
    for i, line in ipairs(v.macroRows) do
        local m = S.Get("importMacros") and fates[i]
        line:SetShown(m and true or false)
        if m then
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -LINE_GAP)
            line:SetPoint("RIGHT", v.macros.title, "RIGHT")
            PaintFate(line, m)
            last = line
        end
    end
    local more = S.Get("importMacros") and #fates - MACROS_SHOWN or 0
    v.macroMore:SetShown(more > 0)
    if more <= 0 then return last end
    v.macroMore:ClearAllPoints()
    v.macroMore:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -LINE_GAP)
    v.macroMore:SetText(TEXT_MORE:format(more))
    return v.macroMore
end

local function DrawKeys(v, set, last)
    v.keys.mark:ClearAllPoints()
    v.keys.mark:SetPoint("TOPLEFT", last, "BOTTOMLEFT", -TEXT_X, -FACT_GAP)
    if not set.bindings then
        v.keys.title:SetText(TEXT_NO_KEYS)
        v.keys.line:SetText(TEXT_KEYS_STAY)
    elseif not S.Get("importBindings") then
        v.keys.title:SetText(TEXT_KEYBINDS)
        v.keys.line:SetText(TEXT_KEYS_OFF)
    else
        v.keys.title:SetText(TEXT_KEY_COUNT:format(preview.bound or 0))
        v.keys.line:SetText(TEXT_KEYS_FREE)
    end
end

local function Draw(v)
    local set = Sets.Get(importKey)
    if not set then W.Show("sets") return end
    DrawBars(v, set)
    DrawActions(v)
    DrawFill(v)
    DrawMacroTitle(v, preview.macros)
    DrawKeys(v, set, DrawMacroRows(v, preview.macros))
end

local function Open(v)
    local set = Sets.Get(importKey)
    v.title = TEXT_TITLE_KEY .. importKey
    v.subtitle = TEXT_SUBTITLE:format(UnitName("player"), UnitLevel("player"),
        UnitClass("player"), date(ns.L(SAVED_DATE), set.saved), set.by and (TEXT_BY .. set.by) or "")
    preview = Sets.Preview(importKey)
end

function Preview.SetKey(key)
    importKey = key
end

function Preview.Build(window)
    W = window
    local v = { cards = {} }
    local top, bottom = HEADER + CARD, FOOTER + CARD
    local rightX = WIDTH - CARD - SIDE_W
    P.Cards(W.frame, v.cards, CARD, top, SIDE_W + CARD + GAP, bottom)
    P.Cards(W.frame, v.cards, rightX, top, CARD, bottom)
    v.frame = CreateFrame("Frame", nil, W.frame)
    v.frame:SetAllPoints()
    local bars = P.Pane(W.frame, CARD, top, SIDE_W + CARD + GAP, bottom)
    bars:SetParent(v.frame)
    P.Heading(bars, TEXT_HEADING, TEXT_HEADING_HINT)
    v.scroll, v.content = P.List(bars, HEADING_H, HEADING_H)
    Legend(bars)
    local side = P.Pane(W.frame, rightX, top, CARD, bottom)
    side:SetParent(v.frame)
    BuildSide(v, side)
    v.title = TEXT_TITLE
    function v.Open() Open(v) end
    function v.Draw() Draw(v) end
    return v
end

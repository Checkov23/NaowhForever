-- SetsPage.lua: the window's home: Save Current Bars, Import Website Code and Export to Website as cards, then your class's saved sets, a row each with a small strip of its bars, Import and More (ns.BuildActionBarsPage).
local ns = _G.NaowhForever
local T = ns.THEME
local UI = ns.UI

local A = ns.ActionBars
local St = A.Style
local P = A.Parts

local SLOTS_PER_BAR, GLASS_PAD = A.C.SLOTS_PER_BAR, St.GLASS_PAD
local CARD_H, CARD_GAP, CARD_BUTTON_W, BUTTON_H = 96, 10, 120, 26
local ACTIONS = 3
local ROW_H, ROW_GAP, ROW_BUTTON_W, BUTTON_GAP = 74, 8, 84, 8
local NAME_W, STRIP_GAP, EXTRAS_GAP = 250, 10, 3
local HEAD_GAP, HEAD_H, LINE_GAP = 22, 22, 3
local DOT = St.PLACE_DOT
local NO_FORMS = {}
local NEW_NAME_MAX = 40
local SAVED_DATE = "%d %b %Y"
local TEXT_ACTION, TEXT_ACTIONS = ns.L("%d action"), ns.L("%d actions")
local TEXT_MACRO, TEXT_MACROS = ns.L("%d macro"), ns.L("%d macros")
local TEXT_KEYBIND, TEXT_KEYBINDS = ns.L("%d keybind"), ns.L("%d keybinds")

local TEXT_SAVE = ns.L("Save Current Bars")
local TEXT_SAVE_LINE = ns.L("Bars, macros and keybinds, for every %s.")
local TEXT_SAVE_BUTTON = ns.L("Save")
local TEXT_WEBSITE = ns.L("Import Website Code")
local TEXT_WEBSITE_LINE = ns.L("Bring a layout from naowh.gg into a new set.")
local TEXT_WEBSITE_BUTTON = ns.L("Paste code")
local TEXT_EXPORT = ns.L("Export to Website")
local TEXT_EXPORT_LINE = ns.L("Your bars now, as a code for naowh.gg.")
local TEXT_EXPORT_BUTTON = ns.L("Get code")
local TEXT_PLUS_FORM = ns.L("+ %s")
local TEXT_PLUS_FORMS = ns.L("+ %d forms")
local TEXT_PLUS_BARS = ns.L("+ %d more bars")
local TEXT_PLUS_BAR = ns.L("+ 1 more bar")
local TEXT_PLUS_PET = ns.L("+ pet keys")
local TEXT_HEADER = ns.L("Saved Sets")
local TEXT_EMPTY = ns.L("Nothing saved yet. Save your bars, macros and keybinds as they are now, then "
    .. "import them on a fresh character, for another spec or a dungeon set-up.")
local TEXT_SAVED = ns.L("Saved ")
local TEXT_BY = ns.L(" by ")
local TEXT_IMPORT, TEXT_MORE = ns.L("Import"), ns.L("More")
local TEXT_EDIT, TEXT_RENAME, TEXT_DELETE = ns.L("Edit and Save Again"), ns.L("Rename"), ns.L("Delete")
local TEXT_NEW_NAME = ns.L("New name for ")
local CONTENTS_JOIN = ", "

local function OpenBuilder() ns.OpenActionBarsBuilder() end
local function ExportNow() A.Sharing.ShowExport() end

local ACTION_CARDS = {
    { title = TEXT_SAVE, line = TEXT_SAVE_LINE, button = TEXT_SAVE_BUTTON, primary = true, onClick = OpenBuilder },
    { title = TEXT_WEBSITE, line = TEXT_WEBSITE_LINE, button = TEXT_WEBSITE_BUTTON,
        onClick = function() A.Sharing.Prompt() end },
    { title = TEXT_EXPORT, line = TEXT_EXPORT_LINE, button = TEXT_EXPORT_BUTTON, onClick = ExportNow },
}
local extras, formPages = {}, {}

local function HasPage(set, page)
    local first = (page - 1) * SLOTS_PER_BAR
    for i = 1, SLOTS_PER_BAR do
        if set.slots[first + i] then return true end
    end
    return false
end

local function HasPetKeys(set)
    for _, command in pairs(set.bindings or NO_FORMS) do
        if A.Capture.PetKey(command) then return true end
    end
    return false
end

function A.SetExtras(set)
    wipe(extras)
    local forms, count, named = A.FORMS[A.Class()] or NO_FORMS, 0, nil
    wipe(formPages)
    for _, form in ipairs(forms) do
        formPages[#formPages + 1] = form.page
        if HasPage(set, form.page) then count, named = count + 1, form.name end
    end
    if count == 1 then extras[#extras + 1] = TEXT_PLUS_FORM:format(ns.L(named)) end
    if count > 1 then extras[#extras + 1] = TEXT_PLUS_FORMS:format(count) end
    local others = 0
    for _, bar in ipairs(A.BARS) do
        if P.IsOther(bar.page, formPages) and HasPage(set, bar.page) then others = others + 1 end
    end
    if others == 1 then extras[#extras + 1] = TEXT_PLUS_BAR end
    if others > 1 then extras[#extras + 1] = TEXT_PLUS_BARS:format(others) end
    if A.PET_CLASSES[A.Class()] and HasPetKeys(set) then extras[#extras + 1] = TEXT_PLUS_PET end
    return table.concat(extras, DOT)
end

function A.SetMenu(key)
    MenuUtil.CreateContextMenu(UIParent, function(_, root)
        root:CreateButton(TEXT_EDIT, function() ns.OpenActionBarsBuilder(key) end)
        root:CreateButton(TEXT_EXPORT, function() A.Sharing.ShowExport(key) end)
        root:CreateButton(TEXT_RENAME, function()
            ns.PromptText(TEXT_NEW_NAME .. key, key, NEW_NAME_MAX, function(new) A.Rename(key, new) end)
        end)
        root:CreateButton(TEXT_DELETE, function() A.ConfirmDelete(key) end)
    end)
end

function A.SetContents(set)
    local actions, keys = 0, 0
    for _ in pairs(set.slots) do actions = actions + 1 end
    local parts = { A.Plural(actions, TEXT_ACTION, TEXT_ACTIONS) }
    if set.macros then parts[#parts + 1] = A.Plural(#set.macros, TEXT_MACRO, TEXT_MACROS) end
    if set.bindings then
        for _ in pairs(set.bindings) do keys = keys + 1 end
        parts[#parts + 1] = A.Plural(keys, TEXT_KEYBIND, TEXT_KEYBINDS)
    end
    return table.concat(parts, CONTENTS_JOIN)
end

local function NewAction(parent)
    local card = P.GlassPanel(parent)
    card:SetHeight(CARD_H)
    card.button = ns.Button(card, "", CARD_BUTTON_W, BUTTON_H)
    card.button:SetPoint("BOTTOMLEFT", GLASS_PAD, GLASS_PAD)
    return card
end

local function PaintAction(card, action)
    card.title:SetText(action.title)
    card.line:SetText(action.line:format(UnitClass("player")))
    ns.SetButtonText(card.button, action.button)
    card.button._onClick = action.onClick
    if action.primary then P.Primary(card.button) end
end

local function NewSetRow(parent)
    local row = P.Glass(CreateFrame("Frame", nil, parent))
    row:SetHeight(ROW_H)
    row.name = P.Label(row, St.NAME_SIZE, T.fg)
    row.name:SetPoint("TOPLEFT", GLASS_PAD, -GLASS_PAD)
    row.name:SetWidth(NAME_W)
    row.name:SetWordWrap(false)
    row.saved = P.Label(row, St.SMALL_SIZE, T.muted)
    row.saved:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -LINE_GAP)
    row.has = P.Label(row, St.SMALL_SIZE, T.muted)
    row.has:SetPoint("TOPLEFT", row.saved, "BOTTOMLEFT", 0, -LINE_GAP)
    row.strip = P.NewMiniStrip(row)
    row.strip:SetPoint("TOPLEFT", GLASS_PAD + NAME_W + STRIP_GAP, -GLASS_PAD)
    row.extras = P.Label(row, St.SMALL_SIZE, T.muted)
    row.extras:SetPoint("TOPLEFT", row.strip, "BOTTOMLEFT", 0, -EXTRAS_GAP)
    row.more = ns.Button(row, TEXT_MORE, ROW_BUTTON_W, BUTTON_H, function() A.SetMenu(row.key) end)
    row.more:SetPoint("RIGHT", -GLASS_PAD, 0)
    row.import = P.Primary(ns.Button(row, TEXT_IMPORT, ROW_BUTTON_W, BUTTON_H,
        function() ns.OpenActionBarsImport(row.key) end))
    row.import:SetPoint("RIGHT", row.more, "LEFT", -BUTTON_GAP, 0)
    return row
end

local function PaintSetRow(row, key, set)
    row.key = key
    row.name:SetText(key)
    row.saved:SetText(TEXT_SAVED .. date(ns.L(SAVED_DATE), set.saved) .. (set.by and (TEXT_BY .. set.by) or ""))
    row.has:SetText(A.SetContents(set))
    P.PaintMiniStrip(row.strip, set.slots)
    row.extras:SetText(A.SetExtras(set))
end

local function Heading(parent, y)
    local head = UI.Keep(parent, "barsHeading", function(p) return P.Mono(p, St.MONO_SIZE, St.GOLD_RGB) end)
    head:SetPoint("TOPLEFT", 0, y)
    head:SetText(ns.Upper(TEXT_HEADER))
    return y - HEAD_H
end

function ns.BuildActionBarsPage(parent, y)
    local width = parent:GetWidth()
    local cardW = (width - CARD_GAP * (ACTIONS - 1)) / ACTIONS
    for i, action in ipairs(ACTION_CARDS) do
        local card = UI.Keep(parent, "barsAction", NewAction)
        card:SetPoint("TOPLEFT", (i - 1) * (cardW + CARD_GAP), y)
        card:SetWidth(cardW)
        PaintAction(card, action)
    end
    y = Heading(parent, y - CARD_H - HEAD_GAP)
    local names = A.SortedNames()
    if #names == 0 then
        local _, h = UI.Widgets:Note(parent, TEXT_EMPTY, y)
        return y - h
    end
    local sets = A.Sets()
    for _, key in ipairs(names) do
        local row = UI.Keep(parent, "barsRow", NewSetRow)
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", 0, y)
        PaintSetRow(row, key, sets[key])
        y = y - ROW_H - ROW_GAP
    end
    return y
end

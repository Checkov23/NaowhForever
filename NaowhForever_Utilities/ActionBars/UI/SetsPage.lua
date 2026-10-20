-- SetsPage.lua: the Bar Sets tab's home: Paste Code, Get Code and Save Current Bars over it, an Undo after an import, the bar check, then your class's saved sets as cards with a small strip of their bars and a filter by tag, and the backups taken before each import (ns.BuildActionBarsPage, A.BuildSetsHeader), and the launcher's quick menu (ns.ActionBarsMenu).
local ns = _G.NaowhForever
local T = ns.THEME
local UI = ns.UI

local A = ns.ActionBars
local S = A.Settings
local St = A.Style
local P = A.Parts
local Check = A.Check

local SLOTS_PER_BAR, GLASS_PAD = A.C.SLOTS_PER_BAR, St.GLASS_PAD
local CARD_GAP, BUTTON_H, HEADER_BUTTON_W, SAVE_BUTTON_W, PILL_GAP = 10, 26, 110, 170, 12
local SET_H, SET_COLUMNS, ROW_BUTTON_W, BUTTON_GAP = 172, 3, 70, 6
local ICON, ICON_GAP, LINE_GAP, TAG_GAP, TAGS_TOP, STRIP_TOP = 36, 10, 3, 4, 58, 80
local NEW_CARD_TEXT = 16
local HEAD_GAP, HEAD_H, SECTION_GAP = 22, 22, 18
local BANNER_H, CHECK_H, CHECK_ICON, CHECK_ICONS, CHECK_BUTTON_W, CHECKS = 44, 96, 26, 8, 104, 3
local NAMES_SHOWN = 3
local BACKUP_H, BACKUP_GAP, BACKUP_BUTTON_W, BACKUP_BUTTON_H = 34, 4, 96, 22
local FILTER_H, FILTER_PAD, FILTER_GAP = 26, 12, 6
local BANNER_ALPHA = 0.16
local DOT = St.PLACE_DOT
local NO_FORMS = {}
local NEW_NAME_MAX = 40
local SAVED_DATE = "%d %b %Y"
local BACKUP_DATE = "%d %b %H:%M"
local WEBSITE = "website"
local SETTINGS_PAGE = "Action Bars/Settings"

local TEXT = {
    ACTION = ns.L("%d action"), ACTIONS = ns.L("%d actions"),
    MACRO = ns.L("%d macro"), MACROS = ns.L("%d macros"),
    KEYBIND = ns.L("%d keybind"), KEYBINDS = ns.L("%d keybinds"),
    SAVE = ns.L("Save Current Bars"),
    SAVE_BUTTON = ns.L("+ Save Current Bars"),
    SAVE_LINE = ns.L("Bars, macros and keybinds, for every %s."),
    WEBSITE = ns.L("Import Website Code"),
    WEBSITE_BUTTON = ns.L("Paste Code"),
    WEBSITE_LINE = ns.L("Bring a layout from naowh.gg into a new set."),
    EXPORT = ns.L("Export to Website"),
    EXPORT_BUTTON = ns.L("Get Code"),
    EXPORT_LINE = ns.L("Your bars now, as a code for naowh.gg."),
    PILL = ns.L("%s%s%d SETS"),
    PILL_ONE = ns.L("%s%s1 SET"),
    PLUS_FORM = ns.L("+ %s"),
    PLUS_FORMS = ns.L("+ %d forms"),
    PLUS_BARS = ns.L("+ %d more bars"),
    PLUS_BAR = ns.L("+ 1 more bar"),
    PLUS_PET = ns.L("+ pet keys"),
    HEADER = ns.L("Saved Sets"),
    EMPTY = ns.L("Nothing saved yet. Save your bars, macros and keybinds as they are now, then "
        .. "import them on a fresh character, for another spec or a dungeon set-up."),
    NO_MATCH = ns.L("No saved set has this tag."),
    NEW_CARD = ns.L("Save your bars as a new set"),
    SAVED = ns.L("Saved "),
    BY = ns.L(" by "),
    IMPORT = ns.L("Import"), MORE = ns.L("More"),
    EDIT = ns.L("Edit and Save Again"), RENAME = ns.L("Rename"), DELETE = ns.L("Delete"),
    NEW_NAME = ns.L("New name for "),
    ON_BARS = ns.L("ON YOUR BARS"),
    ALL = ns.L("All %d"),
    FROM_WEBSITE = ns.L("From naowh.gg"),
    IMPORTED = ns.L("%s is on your bars. Your bars from before it are kept as a backup."),
    UNDO = ns.L("Undo Import"),
    RANKS_HEAD = ns.L("BAR CHECK"),
    RANKS = ns.L("%d spells below your best rank"), RANKS_ONE = ns.L("1 spell below your best rank"),
    UPGRADE = ns.L("Upgrade All"), KEEP = ns.L("Leave as Is"),
    KEEP_TIP = ns.L("Keeps these ranks, for downranking, and stops asking about them."),
    RANK_NAME = "%s %s",
    MORE_NAMES = ns.L(", and %d more"),
    SPELLS_HEAD = ns.L("NEW SPELLS"),
    SPELLS = ns.L("%d spells you know are on no bar"), SPELLS_ONE = ns.L("1 spell you know is on no bar"),
    SPELLS_LINE = ns.L("Drag one onto your bars."),
    HIDE = ns.L("Hide These"),
    HIDE_TIP = ns.L("Stops listing these spells as new."),
    CURRENT_HEAD = ns.L("KEEPING CURRENT"),
    CURRENT = ns.L("%s saves on logout"),
    CURRENT_LINE = ns.L("Last saved %s"),
    CHANGE = ns.L("Change"),
    CHANGE_TIP = ns.L("Opens Save on Logout on the Settings tab."),
    BACKUPS = ns.L("Backups"),
    RESTORE = ns.L("Put Back"), SAVE_AS = ns.L("Save as Set"),
    RESTORE_ASK = ns.L("Put back your bars, keybinds and macros from %s?"),
    BACKUP_NAME = ns.L("Name for the set made from this backup"),
    REPLACE = ns.L("Replace %s with these bars?"),
    KEY_MAP = ns.L("Keybind Map"),
    MENU_TITLE = ns.L("Load a Bar Set"),
    MENU_ON = ns.L("%s (on your bars)"),
    MENU_SAVE = ns.L("Save Bars into %s"),
    MENU_OPEN = ns.L("Open Bar Sets"),
}
local CONTENTS_JOIN = ", "

local function OpenBuilder() ns.OpenActionBarsBuilder() end
local function ExportNow() A.Sharing.ShowExport() end
local function PasteCode() A.Sharing.Prompt() end

local HEADER_BUTTONS = {
    { text = TEXT.SAVE_BUTTON, title = TEXT.SAVE, line = TEXT.SAVE_LINE, width = SAVE_BUTTON_W, primary = true,
        onClick = OpenBuilder },
    { text = TEXT.EXPORT_BUTTON, title = TEXT.EXPORT, line = TEXT.EXPORT_LINE, width = HEADER_BUTTON_W,
        onClick = ExportNow },
    { text = TEXT.WEBSITE_BUTTON, title = TEXT.WEBSITE, line = TEXT.WEBSITE_LINE, width = HEADER_BUTTON_W,
        onClick = PasteCode },
}
local extras, formPages = {}, {}
local tagFilter

local function OnBars(key)
    local last = A.Last()
    return last ~= nil and last.class == A.Class() and last.name == key
end

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
    if count == 1 then extras[#extras + 1] = TEXT.PLUS_FORM:format(ns.L(named)) end
    if count > 1 then extras[#extras + 1] = TEXT.PLUS_FORMS:format(count) end
    local others = 0
    for _, bar in ipairs(A.BARS) do
        if P.IsOther(bar.page, formPages) and HasPage(set, bar.page) then others = others + 1 end
    end
    if others == 1 then extras[#extras + 1] = TEXT.PLUS_BAR end
    if others > 1 then extras[#extras + 1] = TEXT.PLUS_BARS:format(others) end
    if A.PET_CLASSES[A.Class()] and HasPetKeys(set) then extras[#extras + 1] = TEXT.PLUS_PET end
    return table.concat(extras, DOT)
end

function A.SetMenu(key)
    MenuUtil.CreateContextMenu(UIParent, function(_, root)
        root:CreateButton(TEXT.EDIT, function() ns.OpenActionBarsBuilder(key) end)
        root:CreateButton(TEXT.KEY_MAP, function() ns.OpenActionBarsKeys(key) end)
        root:CreateButton(TEXT.EXPORT, function() A.Sharing.ShowExport(key) end)
        root:CreateButton(TEXT.RENAME, function()
            ns.PromptText(TEXT.NEW_NAME .. key, key, NEW_NAME_MAX, function(new) A.Rename(key, new) end)
        end)
        root:CreateButton(TEXT.DELETE, function() A.ConfirmDelete(key) end)
    end)
end

function ns.ActionBarsMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(TEXT.MENU_TITLE)
        for _, key in ipairs(A.SortedNames()) do
            local text = OnBars(key) and TEXT.MENU_ON:format(key) or key
            root:CreateButton(text, function() A.ImportSet(key) end)
        end
        root:CreateDivider()
        if A.lastImport then root:CreateButton(TEXT.UNDO, function() A.Undo() end) end
        local last = A.Last()
        if last and last.class == A.Class() and A.Sets()[last.name] then
            root:CreateButton(TEXT.MENU_SAVE:format(last.name), function() ns.ActionBarSets.Save(last.name) end)
        end
        root:CreateButton(TEXT.MENU_OPEN, function() ns.OpenActionBarsWindow() end)
    end)
end

function A.SetContents(set)
    local actions, keys = 0, 0
    for _ in pairs(set.slots) do actions = actions + 1 end
    local parts = { A.Plural(actions, TEXT.ACTION, TEXT.ACTIONS) }
    if set.macros then parts[#parts + 1] = A.Plural(#set.macros, TEXT.MACRO, TEXT.MACROS) end
    if set.bindings then
        for _ in pairs(set.bindings) do keys = keys + 1 end
        parts[#parts + 1] = A.Plural(keys, TEXT.KEYBIND, TEXT.KEYBINDS)
    end
    return table.concat(parts, CONTENTS_JOIN)
end

function A.SetIcon(set)
    if set.icon then return set.icon end
    for _, page in ipairs(P.STRIP_PAGES) do
        local first = (page - 1) * SLOTS_PER_BAR
        for i = 1, SLOTS_PER_BAR do
            local texture = P.EntryTexture(set.slots[first + i])
            if texture then return texture end
        end
    end
    return A.C.QUESTION
end

local function Tip(owner)
    P.Hint(owner, owner.tipTitle, owner.tipLine)
end

local function PaintPill(header, title)
    local _, class = UnitClass("player")
    local color = RAID_CLASS_COLORS[class] or T.fg
    local count = 0
    for _ in pairs(A.Sets()) do count = count + 1 end
    local name = ns.Upper(UnitClass("player"))
    header.pill.text:SetText(count == 1 and TEXT.PILL_ONE:format(name, DOT) or TEXT.PILL:format(name, DOT, count))
    header.pill.text:SetTextColor(color.r, color.g, color.b)
    header.pill.edge:SetColor(color.r, color.g, color.b, 1)
    header.pill:SetWidth(math.ceil(header.pill.text:GetStringWidth()) + FILTER_PAD * 2)
    header.pill:ClearAllPoints()
    header.pill:SetPoint("LEFT", title, "LEFT", math.ceil(title:GetStringWidth()) + PILL_GAP, 0)
end

function A.BuildSetsHeader(frame)
    local header = { buttons = {} }
    local after
    for _, look in ipairs(HEADER_BUTTONS) do
        local button = ns.Button(frame, look.text, look.width, BUTTON_H, look.onClick)
        if look.primary then P.Primary(button) end
        if after then button:SetPoint("RIGHT", after, "LEFT", -BUTTON_GAP, 0) else button:SetPoint("TOPRIGHT", 0, 0) end
        button.tipTitle, button.tipLine = look.title, look.line:format(UnitClass("player"))
        button:HookScript("OnEnter", Tip)
        button:HookScript("OnLeave", GameTooltip_Hide)
        header.buttons[#header.buttons + 1] = button
        after = button
    end
    header.pill = CreateFrame("Frame", nil, frame)
    header.pill:SetHeight(St.CHIP_H + LINE_GAP * 2)
    header.pill.edge = ns.Border(header.pill, T.fg)
    header.pill.text = P.Mono(header.pill, St.MONO_SIZE, T.fg)
    header.pill.text:SetPoint("CENTER")
    header.Paint = PaintPill
    return header
end

local function NewBanner(parent)
    local banner = CreateFrame("Frame", nil, parent)
    banner:SetHeight(BANNER_H)
    ns.Solid(banner, "BACKGROUND", St.GREEN_RGB, BANNER_ALPHA):SetAllPoints()
    ns.Border(banner, St.GREEN_RGB)
    banner.text = P.Label(banner, St.NOTE_SIZE, T.fg)
    banner.text:SetPoint("LEFT", GLASS_PAD, 0)
    banner.undo = ns.Button(banner, TEXT.UNDO, HEADER_BUTTON_W, BUTTON_H, function() A.Undo() end)
    banner.undo:SetPoint("RIGHT", -GLASS_PAD, 0)
    return banner
end

local function SpellEnter(icon)
    if not ns.Shared.Parts.Tip(icon, "ANCHOR_TOP") then return end
    GameTooltip:SetSpellByID(icon.spell)
    GameTooltip:Show()
end

local function PickUpSpell(icon)
    if InCombatLockdown() then return end
    C_Spell.PickupSpell(icon.spell)
end

local function NewSpellIcon(card)
    local icon = CreateFrame("Button", nil, card)
    icon:SetSize(CHECK_ICON, CHECK_ICON)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(St.ICON_CROP, 1 - St.ICON_CROP, St.ICON_CROP, 1 - St.ICON_CROP)
    ns.Border(icon, St.BORDER_RGB)
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnDragStart", PickUpSpell)
    icon:SetScript("OnClick", PickUpSpell)
    icon:SetScript("OnEnter", SpellEnter)
    icon:SetScript("OnLeave", GameTooltip_Hide)
    return icon
end

local function NewCheck(parent)
    local card = P.Glass(CreateFrame("Frame", nil, parent))
    card:SetHeight(CHECK_H)
    card.head = P.Mono(card, St.MONO_SIZE, St.GOLD_RGB)
    card.head:SetPoint("TOPLEFT", GLASS_PAD, -GLASS_PAD)
    card.title = P.Label(card, St.NAME_SIZE, T.fg)
    card.title:SetPoint("TOPLEFT", card.head, "BOTTOMLEFT", 0, -LINE_GAP * 2)
    card.title:SetPoint("RIGHT", -(GLASS_PAD * 2 + CHECK_BUTTON_W), 0)
    card.title:SetWordWrap(false)
    card.line = P.Label(card, St.SMALL_SIZE, T.muted)
    card.line:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -LINE_GAP)
    card.line:SetPoint("RIGHT", -(GLASS_PAD * 2 + CHECK_BUTTON_W), 0)
    card.line:SetWordWrap(false)
    card.first = ns.Button(card, "", CHECK_BUTTON_W, BUTTON_H)
    card.first:SetPoint("TOPRIGHT", -GLASS_PAD, -GLASS_PAD)
    card.first:SetScript("OnEnter", Tip)
    card.first:SetScript("OnLeave", GameTooltip_Hide)
    card.second = ns.Button(card, "", CHECK_BUTTON_W, BUTTON_H)
    card.second:SetPoint("TOPRIGHT", card.first, "BOTTOMRIGHT", 0, -BUTTON_GAP)
    card.second:SetScript("OnEnter", Tip)
    card.second:SetScript("OnLeave", GameTooltip_Hide)
    card.icons = {}
    for i = 1, CHECK_ICONS do
        local icon = NewSpellIcon(card)
        icon:SetPoint("BOTTOMLEFT", GLASS_PAD + (i - 1) * (CHECK_ICON + TAG_GAP), GLASS_PAD)
        card.icons[i] = icon
    end
    return card
end

local function RankNames(list)
    local names = {}
    for i = 1, math.min(#list, NAMES_SHOWN) do
        local id = list[i].id
        names[i] = TEXT.RANK_NAME:format(C_Spell.GetSpellName(id) or "", C_Spell.GetSpellSubtext(id) or "")
    end
    local text = table.concat(names, CONTENTS_JOIN)
    if #list > NAMES_SHOWN then text = text .. TEXT.MORE_NAMES:format(#list - NAMES_SHOWN) end
    return text
end

local function PaintCheck(card, look)
    card.head:SetText(look.head)
    card.title:SetText(look.title)
    card.line:SetText(look.line)
    ns.SetButtonText(card.first, look.first)
    card.first._onClick = look.onFirst
    card.first.tipTitle, card.first.tipLine = look.first, look.firstTip
    card.second:SetShown(look.second ~= nil)
    ns.SetButtonText(card.second, look.second or "")
    card.second._onClick = look.onSecond
    card.second.tipTitle, card.second.tipLine = look.second, look.tip
    for i, icon in ipairs(card.icons) do
        local row = look.spells and look.spells[i]
        icon:SetShown(row ~= nil)
        if row then
            icon.spell = row.id
            icon.texture:SetTexture(C_Spell.GetSpellTexture(row.id))
        end
    end
end

local function CurrentLook()
    local last = A.Last()
    local set = last and last.class == A.Class() and last.saved ~= false and A.Sets()[last.name]
    if not (S.Get("saveOnLogout") and set) then return nil end
    return { head = TEXT.CURRENT_HEAD, title = TEXT.CURRENT:format(last.name),
        line = TEXT.CURRENT_LINE:format(date(ns.L(BACKUP_DATE), set.saved)),
        first = TEXT.CHANGE, firstTip = TEXT.CHANGE_TIP, onFirst = function() ns.OpenOptionsWindow(SETTINGS_PAGE) end }
end

local function CheckLooks()
    local looks = {}
    local upgrades = Check.Upgrades()
    if #upgrades > 0 then
        looks[#looks + 1] = { head = TEXT.RANKS_HEAD, line = RankNames(upgrades),
            title = #upgrades == 1 and TEXT.RANKS_ONE or TEXT.RANKS:format(#upgrades),
            first = TEXT.UPGRADE, onFirst = function() Check.Upgrade(upgrades) end,
            second = TEXT.KEEP, onSecond = function() Check.Keep(upgrades) end, tip = TEXT.KEEP_TIP }
    end
    local missing = Check.Missing()
    if missing and #missing > 0 then
        looks[#looks + 1] = { head = TEXT.SPELLS_HEAD, line = TEXT.SPELLS_LINE, spells = missing,
            title = #missing == 1 and TEXT.SPELLS_ONE or TEXT.SPELLS:format(#missing),
            first = TEXT.HIDE, onFirst = function() Check.Hide(missing) end, firstTip = TEXT.HIDE_TIP }
    end
    looks[#looks + 1] = CurrentLook()
    return looks
end

local function NewFilter(parent)
    local chip = CreateFrame("Button", nil, parent)
    chip:SetHeight(FILTER_H)
    chip.fill = ns.Solid(chip, "BACKGROUND", T.fg, 1)
    chip.fill:SetAllPoints()
    chip.edge = ns.Border(chip, T.fg)
    chip.text = P.Label(chip, St.SMALL_SIZE, T.fg)
    chip.text:SetPoint("CENTER")
    chip:SetScript("OnClick", P.Clicked)
    return chip
end

local function PaintFilter(chip, text, tag)
    local picked = tagFilter == tag
    chip.text:SetText(text)
    local c = picked and T.bg or T.fg
    chip.text:SetTextColor(c.r, c.g, c.b)
    chip.fill:SetShown(picked)
    local edge = picked and T.fg or St.BORDER_RGB
    chip.edge:SetColor(edge.r, edge.g, edge.b, 1)
    chip:SetWidth(math.ceil(chip.text:GetStringWidth()) + FILTER_PAD * 2)
    chip.onClick = function()
        tagFilter = tag
        A.Refresh()
    end
end

local function NewSetCard(parent)
    local row = P.Glass(CreateFrame("Frame", nil, parent))
    row:SetHeight(SET_H)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("TOPLEFT", GLASS_PAD, -GLASS_PAD)
    row.icon:SetTexCoord(St.ICON_CROP, 1 - St.ICON_CROP, St.ICON_CROP, 1 - St.ICON_CROP)
    row.on = P.Chip(row)
    row.on:SetPoint("TOPRIGHT", -GLASS_PAD, -GLASS_PAD)
    row.name = P.Label(row, St.NAME_SIZE, T.fg)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", ICON_GAP, -LINE_GAP)
    row.name:SetPoint("RIGHT", row.on, "LEFT", -ICON_GAP, 0)
    row.name:SetWordWrap(false)
    row.saved = P.Label(row, St.SMALL_SIZE, T.muted)
    row.saved:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -LINE_GAP)
    row.saved:SetPoint("RIGHT", -GLASS_PAD, 0)
    row.saved:SetWordWrap(false)
    row.tags = {}
    row.strip = P.NewMiniStrip(row)
    row.strip:SetPoint("TOPLEFT", GLASS_PAD, -STRIP_TOP)
    row.extras = P.Label(row, St.SMALL_SIZE, T.muted)
    row.extras:SetPoint("TOPLEFT", row.strip, "BOTTOMLEFT", 0, -LINE_GAP)
    row.more = ns.Button(row, TEXT.MORE, ROW_BUTTON_W, BUTTON_H, function() A.SetMenu(row.key) end)
    row.more:SetPoint("BOTTOMRIGHT", -GLASS_PAD, GLASS_PAD)
    row.import = P.Primary(ns.Button(row, TEXT.IMPORT, ROW_BUTTON_W, BUTTON_H,
        function() ns.OpenActionBarsImport(row.key) end))
    row.import:SetPoint("RIGHT", row.more, "LEFT", -BUTTON_GAP, 0)
    row.has = P.Label(row, St.SMALL_SIZE, T.fg)
    row.has:SetPoint("LEFT", row, "BOTTOMLEFT", GLASS_PAD, GLASS_PAD + BUTTON_H / 2)
    row.has:SetPoint("RIGHT", row.import, "LEFT", -BUTTON_GAP, 0)
    row.has:SetWordWrap(false)
    return row
end

local function PaintTags(row, set)
    local after
    for i, tag in ipairs(set.tags or NO_FORMS) do
        local chip = row.tags[i] or P.Chip(row)
        row.tags[i] = chip
        P.PaintChip(chip, ns.Upper(tag), St.ACCOUNT_RGB)
        chip:ClearAllPoints()
        if after then chip:SetPoint("LEFT", after, "RIGHT", TAG_GAP, 0) else chip:SetPoint("TOPLEFT", GLASS_PAD, -TAGS_TOP) end
        after = chip
    end
    for i = #(set.tags or NO_FORMS) + 1, #row.tags do row.tags[i]:Hide() end
end

local function PaintSetRow(row, key, set)
    row.key = key
    row.icon:SetTexture(A.SetIcon(set))
    row.name:SetText(key)
    row.saved:SetText(TEXT.SAVED .. date(ns.L(SAVED_DATE), set.saved) .. (set.by and (TEXT.BY .. set.by) or ""))
    row.has:SetText(A.SetContents(set))
    if OnBars(key) then P.PaintChip(row.on, TEXT.ON_BARS, T.accent) else row.on:Hide() end
    PaintTags(row, set)
    P.PaintMiniStrip(row.strip, set.slots)
    row.extras:SetText(A.SetExtras(set))
end

local function NewSetCardButton(parent)
    local card = CreateFrame("Button", nil, parent)
    card:SetHeight(SET_H)
    ns.Border(card, St.FAINT_RGB)
    card.plus = ns.Font(card, NEW_CARD_TEXT * 2, nil, T.muted)
    card.plus:SetPoint("BOTTOM", card, "CENTER", 0, LINE_GAP)
    card.plus:SetText("+")
    card.text = P.Label(card, St.NOTE_SIZE, T.muted)
    card.text:SetPoint("TOP", card, "CENTER", 0, -LINE_GAP)
    card.text:SetText(TEXT.NEW_CARD)
    card.onClick = OpenBuilder
    card:SetScript("OnClick", P.Clicked)
    return card
end

local function Heading(parent, y, key, text)
    local head = UI.Keep(parent, key, function(p) return P.Mono(p, St.MONO_SIZE, St.GOLD_RGB) end)
    head:SetPoint("TOPLEFT", 0, y)
    head:SetText(ns.Upper(text))
    return head
end

local function HasTag(set, tag)
    if tag == WEBSITE then return set.choices ~= nil and set.choices.website == true end
    for _, t in ipairs(set.tags or NO_FORMS) do if t == tag then return true end end
    return false
end

local function Filters(sets)
    local seen, list, website, count = {}, {}, false, 0
    for _, set in pairs(sets) do
        count = count + 1
        website = website or HasTag(set, WEBSITE)
        for _, tag in ipairs(set.tags or NO_FORMS) do
            if not seen[tag] then
                seen[tag] = true
                list[#list + 1] = tag
            end
        end
    end
    table.sort(list)
    for i, tag in ipairs(list) do list[i] = { text = tag, tag = tag } end
    if website then list[#list + 1] = { text = TEXT.FROM_WEBSITE, tag = WEBSITE } end
    table.insert(list, 1, { text = TEXT.ALL:format(count) })
    return list
end

local function DrawFilters(parent, head, sets)
    local filters = Filters(sets)
    local known = false
    for _, f in ipairs(filters) do known = known or f.tag == tagFilter end
    if not known then tagFilter = nil end
    local after = head
    for i, f in ipairs(filters) do
        local chip = UI.Keep(parent, "barsFilter", NewFilter)
        PaintFilter(chip, f.text, f.tag)
        chip:SetPoint("LEFT", after, "RIGHT", i == 1 and SECTION_GAP or FILTER_GAP, 0)
        after = chip
    end
end

local function DrawBanner(parent, y)
    if not (A.lastImport and A.Sets()[A.lastImport.key]) then return y end
    local banner = UI.Keep(parent, "barsBanner", NewBanner)
    banner:SetPoint("TOPLEFT", 0, y)
    banner:SetPoint("TOPRIGHT", 0, y)
    banner.text:SetText(TEXT.IMPORTED:format(A.lastImport.key))
    return y - BANNER_H - CARD_GAP
end

local function DrawChecks(parent, y, width)
    local looks = CheckLooks()
    if #looks == 0 then return y end
    local cardW = (width - CARD_GAP * (CHECKS - 1)) / CHECKS
    for i, look in ipairs(looks) do
        local card = UI.Keep(parent, "barsCheck", NewCheck)
        card:SetPoint("TOPLEFT", (i - 1) * (cardW + CARD_GAP), y)
        card:SetWidth(cardW)
        PaintCheck(card, look)
    end
    return y - CHECK_H - CARD_GAP
end

local function Place(frame, index, y, cardW)
    local column = index % SET_COLUMNS
    frame:SetPoint("TOPLEFT", column * (cardW + CARD_GAP), y - math.floor(index / SET_COLUMNS) * (SET_H + CARD_GAP))
    frame:SetWidth(cardW)
end

local function DrawSets(parent, y, width)
    local head = Heading(parent, y - HEAD_GAP + CARD_GAP, "barsHeading", TEXT.HEADER)
    local sets = A.Sets()
    DrawFilters(parent, head, sets)
    y = y - HEAD_GAP + CARD_GAP - HEAD_H - LINE_GAP * 2
    local names = A.SortedNames()
    local cardW = (width - CARD_GAP * (SET_COLUMNS - 1)) / SET_COLUMNS
    local shown = 0
    for _, key in ipairs(names) do
        if not tagFilter or HasTag(sets[key], tagFilter) then
            local row = UI.Keep(parent, "barsRow", NewSetCard)
            Place(row, shown, y, cardW)
            PaintSetRow(row, key, sets[key])
            shown = shown + 1
        end
    end
    if #names > 0 and shown == 0 then
        local _, h = UI.Widgets:Note(parent, TEXT.NO_MATCH, y)
        y = y - h
    end
    Place(UI.Keep(parent, "barsNewCard", NewSetCardButton), shown, y, cardW)
    y = y - math.ceil((shown + 1) / SET_COLUMNS) * (SET_H + CARD_GAP)
    if #names == 0 then
        local _, h = UI.Widgets:Note(parent, TEXT.EMPTY, y)
        y = y - h
    end
    return y
end

local function NewBackupRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(BACKUP_H)
    ns.Solid(row, "BACKGROUND", T.bg, St.ROW_FILL):SetAllPoints()
    ns.Border(row, St.BORDER_RGB)
    row.when = P.Mono(row, St.MONO_SIZE, St.INK_RGB)
    row.when:SetPoint("LEFT", GLASS_PAD, 0)
    row.why = P.Label(row, St.NOTE_SIZE, T.fg)
    row.why:SetPoint("LEFT", row.when, "RIGHT", GLASS_PAD, 0)
    row.save = ns.Button(row, TEXT.SAVE_AS, BACKUP_BUTTON_W, BACKUP_BUTTON_H)
    row.save:SetPoint("RIGHT", -GLASS_PAD / 2, 0)
    row.restore = ns.Button(row, TEXT.RESTORE, BACKUP_BUTTON_W, BACKUP_BUTTON_H)
    row.restore:SetPoint("RIGHT", row.save, "LEFT", -BUTTON_GAP, 0)
    return row
end

local function SaveBackup(index, name)
    local existing = A.Find(name)
    if existing then
        ns.Confirm(TEXT.REPLACE:format(existing), function() A.SaveBackup(index, name) end)
    else
        A.SaveBackup(index, name)
    end
end

local function DrawBackups(parent, y)
    local list = A.Backups.List()
    if #list == 0 then return y end
    y = y - SECTION_GAP
    Heading(parent, y, "barsBackupsHeading", TEXT.BACKUPS)
    y = y - HEAD_H
    for i, backup in ipairs(list) do
        local row = UI.Keep(parent, "barsBackup", NewBackupRow)
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", 0, y)
        local when = date(ns.L(BACKUP_DATE), backup.saved)
        row.when:SetText(when)
        row.why:SetText(backup.why or "")
        row.restore._onClick = function()
            ns.Confirm(TEXT.RESTORE_ASK:format(when), function() A.RestoreBackup(i) end)
        end
        row.save._onClick = function()
            ns.PromptText(TEXT.BACKUP_NAME, backup.why or "", NEW_NAME_MAX, function(name) SaveBackup(i, name) end)
        end
        y = y - BACKUP_H - BACKUP_GAP
    end
    return y
end

function ns.ActionBarsSearchTerms(add)
    for _, look in ipairs(HEADER_BUTTONS) do add(look.title, look.line:format(UnitClass("player"))) end
    add(TEXT.UNDO)
    add(TEXT.BACKUPS)
    add(TEXT.UPGRADE, TEXT.RANKS_HEAD)
end

function ns.BuildActionBarsPage(parent, y)
    local width = parent:GetWidth()
    y = DrawBanner(parent, y)
    y = DrawChecks(parent, y, width)
    y = DrawSets(parent, y, width)
    return DrawBackups(parent, y)
end

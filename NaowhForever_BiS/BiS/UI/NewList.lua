-- NewList.lua: the New List dialog: its name, Only for your spec, and a list to start from (B.OpenNewList).
local ns = _G.NaowhForever

local T = ns.THEME
local UI = ns.UI
local B = ns.BiS
local L, R = B.Lists, B.Rankings
local Shared = ns.Shared
local Items, Parts = Shared.Items, Shared.Parts
local Cells = B.View.Cells
local St = B.Style

local SLOTS = Items.GEAR_SLOTS
local NAME_MAX, PLACE_DOT = B.C.NAME_MAX, St.PLACE_DOT
local W, PAD, GAP = 480, 14, 10
local TITLE_SIZE, TEXT_SIZE, TITLE_H = 14, 12, 18
local LABEL_W, FIELD_H = 100, 24
local FIELD_W = W - PAD * 2 - LABEL_W
local TOGGLE_W, TOGGLE_H, TOGGLE_TEXT_GAP = 32, 16, 8
local SLOT_ROW_H, SLOT_ROWS, COLUMN_GAP, HEAD_H, LINK_GAP = 22, 9, 14, 16, 12
local COLUMN_W = (W - PAD * 2 - COLUMN_GAP) / 2
local SLOTS_H = HEAD_H + GAP + SLOT_ROWS * SLOT_ROW_H
local FIELDS_Y = PAD + TITLE_H + GAP
local SPEC_Y = FIELDS_Y + (FIELD_H + GAP) + (TOGGLE_H + GAP) + (FIELD_H + GAP)
local BUTTON_W, BUTTON_H, BUTTON_GAP = 120, 26, 4
local MIN_H = SPEC_Y + BUTTON_H + PAD
local EMPTY = 0
local NONE = {}
local TEXT_TITLE = ns.L("New List")
local TEXT_NAME = ns.L("Name")
local TEXT_ONLY_FOR = ns.L("Only for %s")
local TEXT_FROM, TEXT_SPEC = ns.L("Start From"), ns.L("Spec's Picks")
local TEXT_EMPTY, TEXT_CLASS_LISTS, TEXT_SPEC_ONLY = ns.L("Empty"), ns.L("Class lists"), ns.L("%s only")
local TEXT_SLOT_COUNT, TEXT_NOTHING = ns.L("%d slots"), ns.L("nothing picked")
local TEXT_COPY = ns.L("Copy %d of %d slots")
local TEXT_SLOT = "%s (%s)"
local TEXT_ALL, TEXT_NONE = "All", "None"
local TEXT_CREATE, TEXT_CANCEL = ns.L("Create"), ns.L("Cancel")
local TEXT_NOT_SAVED = ns.L("BiS list not saved: %s.")

local dialog
local chosen = { only = false, from = EMPTY, off = {} }
local fromNames, specNames = {}, {}
local loading = {}
local Paint

local function Source()
    if chosen.from == EMPTY then return nil end
    for _, l in ipairs(L.All()) do
        if l.id == chosen.from then return l end
    end
end

local function SourceSpec(source)
    return L.SpecOnly(source) and source.spec or chosen.spec
end

local function Count(slots)
    local n = 0
    for _ in pairs(slots or NONE) do n = n + 1 end
    return n
end

local function SpecCount(source, key)
    return Count((L.PicksOn(source.id, key)))
end

local function DefaultSpec(source)
    local current = L.CurrentSpec()
    if current and SpecCount(source, current.key) > 0 then return current.key end
    for _, spec in ipairs(R.ClassSpecs()) do
        if SpecCount(source, spec.key) > 0 then return spec.key end
    end
    return current and current.key
end

local function GetFrom() return chosen.from end
local function IsFrom(id) return chosen.from == id end

local function SetFrom(id)
    chosen.from, chosen.spec = id, nil
    wipe(chosen.off)
    Paint()
end

local function FromMenu(desc)
    desc:CreateRadio(TEXT_EMPTY, IsFrom, SetFrom, EMPTY)
    desc:CreateTitle(TEXT_CLASS_LISTS)
    for _, l in ipairs(L.All()) do
        if not L.SpecOnly(l) then desc:CreateRadio(fromNames[l.id], IsFrom, SetFrom, l.id) end
    end
    for _, spec in ipairs(R.ClassSpecs()) do
        local titled = false
        for _, l in ipairs(L.All()) do
            if L.SpecOnly(l) and l.spec == spec.key then
                if not titled then desc:CreateTitle(TEXT_SPEC_ONLY:format(L.SpecShort(spec))) end
                titled = true
                desc:CreateRadio(fromNames[l.id], IsFrom, SetFrom, l.id)
            end
        end
    end
end

local function GetSpec() return chosen.spec end
local function IsSpec(key) return chosen.spec == key end

local function SetSpec(key)
    chosen.spec = key
    wipe(chosen.off)
    Paint()
end

local function SpecMenu(desc)
    for _, spec in ipairs(R.ClassSpecs()) do
        local radio = desc:CreateRadio(specNames[spec.key], IsSpec, SetSpec, spec.key)
        if SpecCount(Source(), spec.key) == 0 then radio:SetEnabled(false) end
    end
end

local function FillSpecNames(source)
    wipe(specNames)
    for _, spec in ipairs(R.ClassSpecs()) do
        local count = SpecCount(source, spec.key)
        specNames[spec.key] = L.SpecShort(spec) .. PLACE_DOT
            .. (count > 0 and TEXT_SLOT_COUNT:format(count) or TEXT_NOTHING)
    end
end

local function SlotEnter(row)
    if row.itemID then Cells.ItemTip(row, row.itemID) end
end

local function SlotLeave()
    GameTooltip:Hide()
end

local function PaintCount()
    local on, total = 0, 0
    for _, row in ipairs(dialog.rows) do
        if row.itemID then
            total = total + 1
            if not chosen.off[row.slot] then on = on + 1 end
        end
    end
    dialog.count:SetText(TEXT_COPY:format(on, total))
end

local function SlotClick(row)
    if not row.itemID then return end
    chosen.off[row.slot] = not chosen.off[row.slot] or nil
    row.toggle._refreshValue()
    PaintCount()
end

local function SlotRow(i)
    local row = CreateFrame("Button", nil, dialog.slots)
    row:SetSize(COLUMN_W, SLOT_ROW_H)
    row.slot = SLOTS[i][1]
    row.toggle = UI.BuildToggleControl(row, nil, function() return not chosen.off[row.slot] end,
        function(on)
            chosen.off[row.slot] = not on or nil
            PaintCount()
        end, TOGGLE_W, TOGGLE_H)
    row.toggle:SetPoint("LEFT", 0, 0)
    row.text = ns.Font(row, TEXT_SIZE, nil, T.fg)
    row.text:SetPoint("LEFT", row.toggle, "RIGHT", TOGGLE_TEXT_GAP, 0)
    row.text:SetPoint("RIGHT", 0, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row:SetScript("OnEnter", SlotEnter)
    row:SetScript("OnLeave", SlotLeave)
    row:SetScript("OnClick", SlotClick)
    local column, line = math.floor((i - 1) / SLOT_ROWS), (i - 1) % SLOT_ROWS
    row:SetPoint("TOPLEFT", column * (COLUMN_W + COLUMN_GAP), -(HEAD_H + GAP + line * SLOT_ROW_H))
    return row
end

local function PaintRow(row, picked)
    local id = picked and picked[row.slot]
    local name = Items.SlotName(row.slot)
    row.itemID = id
    row.toggle:SetShown(id ~= nil)
    if id then
        if not C_Item.IsItemDataCachedByID(id) then loading[#loading + 1] = id end
        row.text:SetText(TEXT_SLOT:format(name, Cells.Named(id, Items.Name(id))))
        row.text:SetTextColor(T.fg.r, T.fg.g, T.fg.b, 1)
        row.toggle._refreshValue()
    else
        row.text:SetText(TEXT_SLOT:format(name, TEXT_NOTHING))
        row.text:SetTextColor(T.muted.r, T.muted.g, T.muted.b, 1)
    end
end

local function PaintRows()
    local source = Source()
    local picked = source and L.PicksOn(source.id, SourceSpec(source))
    wipe(loading)
    for _, row in ipairs(dialog.rows) do PaintRow(row, picked) end
    PaintCount()
    if #loading > 0 then Items.OnLoaded(loading, PaintRows) end
end

local function AllSlots(on)
    for _, row in ipairs(dialog.rows) do chosen.off[row.slot] = not on or nil end
    PaintRows()
end

local function All() AllSlots(true) end
local function None() AllSlots(false) end

local function Field(label, widget, y)
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", PAD + LABEL_W, -y)
    label:ClearAllPoints()
    label:SetPoint("LEFT", widget, "LEFT", -LABEL_W, 0)
end

function Paint()
    local spec = L.CurrentSpec()
    local source = Source()
    local classSource = source ~= nil and not L.SpecOnly(source)
    if classSource and not chosen.spec then chosen.spec = DefaultSpec(source) end
    dialog.onlyText:SetText(spec and TEXT_ONLY_FOR:format(L.SpecShort(spec)) or "")
    dialog.only._refreshValue()
    dialog.from._refreshLabel()
    local y = SPEC_Y
    dialog.spec:SetShown(classSource)
    dialog.specLabel:SetShown(classSource)
    if classSource then
        FillSpecNames(source)
        Field(dialog.specLabel, dialog.spec, y)
        dialog.spec._refreshLabel()
        y = y + FIELD_H + GAP
    end
    dialog.slots:SetShown(source ~= nil)
    if source then
        dialog.slots:ClearAllPoints()
        dialog.slots:SetPoint("TOPLEFT", PAD, -y)
        PaintRows()
        y = y + SLOTS_H + GAP
    end
    dialog.panel:SetHeight(y + BUTTON_H + PAD)
end

local function Create()
    local source = Source()
    local from
    if source then
        local picked = L.PicksOn(source.id, SourceSpec(source)) or NONE
        from = { id = source.id, spec = SourceSpec(source), slots = {} }
        for slot in pairs(picked) do
            if not chosen.off[slot] then from.slots[slot] = true end
        end
    end
    local ok, err = ns.NewBisList(dialog.name:GetText(), chosen.only, from)
    if not ok then return ns.Print(TEXT_NOT_SAVED:format(err)) end
    dialog.dimmer:Hide()
end

local function Cancel()
    dialog.dimmer:Hide()
end

local function Label(text)
    local label = ns.Font(dialog.panel, TEXT_SIZE, nil, T.muted)
    label:SetText(text)
    return label
end

local function Dropdown(values, get, set, menu)
    local dropdown = UI.BuildDropdownControl(dialog.panel, FIELD_W, nil, values, nil, get, set)
    dropdown._menuFill = menu
    return dropdown
end

local function Fields()
    local y = FIELDS_Y
    dialog.name = ns.NewEditBox(dialog.panel)
    dialog.name:SetSize(FIELD_W, FIELD_H)
    dialog.name:SetMaxLetters(NAME_MAX)
    dialog.name:SetScript("OnEnterPressed", Create)
    dialog.name:SetScript("OnEscapePressed", Cancel)
    Field(Label(TEXT_NAME), dialog.name, y)
    y = y + FIELD_H + GAP
    dialog.only = UI.BuildToggleControl(dialog.panel, nil, function() return chosen.only end,
        function(on) chosen.only = on == true end, TOGGLE_W, TOGGLE_H)
    dialog.only:SetPoint("TOPLEFT", PAD + LABEL_W, -y)
    dialog.onlyText = ns.Font(dialog.panel, TEXT_SIZE, nil, T.fg)
    dialog.onlyText:SetPoint("LEFT", dialog.only, "RIGHT", TOGGLE_TEXT_GAP, 0)
    y = y + TOGGLE_H + GAP
    dialog.from = Dropdown(fromNames, GetFrom, SetFrom, FromMenu)
    Field(Label(TEXT_FROM), dialog.from, y)
    dialog.spec = Dropdown(specNames, GetSpec, SetSpec, SpecMenu)
    dialog.specLabel = Label(TEXT_SPEC)
end

local function Slots()
    dialog.slots = CreateFrame("Frame", nil, dialog.panel)
    dialog.slots:SetSize(W - PAD * 2, SLOTS_H)
    dialog.count = ns.Font(dialog.slots, TEXT_SIZE, nil, T.muted)
    dialog.count:SetPoint("TOPLEFT", 0, 0)
    local none = Parts.Link(dialog.slots, None)
    Parts.SetLink(none, TEXT_NONE)
    none:SetPoint("TOPRIGHT", 0, 0)
    local all = Parts.Link(dialog.slots, All)
    Parts.SetLink(all, TEXT_ALL)
    all:SetPoint("RIGHT", none, "LEFT", -LINK_GAP, 0)
    dialog.rows = {}
    for i = 1, #SLOTS do dialog.rows[i] = SlotRow(i) end
end

local function Build()
    local dimmer, panel = ns.MakeModal(W, MIN_H, "bisNewList")
    dialog = { dimmer = dimmer, panel = panel }
    local title = ns.Font(panel, TITLE_SIZE, "OUTLINE")
    title:SetPoint("TOP", 0, -PAD)
    title:SetText(TEXT_TITLE)
    Fields()
    Slots()
    local create = ns.AccentBorder(ns.Button(panel, TEXT_CREATE, BUTTON_W, BUTTON_H, Create))
    create:SetPoint("BOTTOMRIGHT", panel, "BOTTOM", -BUTTON_GAP, PAD)
    local cancel = ns.Button(panel, TEXT_CANCEL, BUTTON_W, BUTTON_H, Cancel)
    cancel:SetPoint("BOTTOMLEFT", panel, "BOTTOM", BUTTON_GAP, PAD)
end

local function FillFromNames()
    wipe(fromNames)
    fromNames[EMPTY] = TEXT_EMPTY
    for _, l in ipairs(L.All()) do fromNames[l.id] = l.name end
end

function B.OpenNewList()
    if not dialog then Build() end
    chosen.only, chosen.from, chosen.spec = false, EMPTY, nil
    wipe(chosen.off)
    FillFromNames()
    dialog.name:SetText("")
    Paint()
    dialog.dimmer:Show()
    dialog.name:SetFocus()
end

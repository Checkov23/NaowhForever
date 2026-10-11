-- Window.lua: the Stat Weights window (ns.OpenStatWeightsWindow).
local ns = _G.NaowhForever

local T = ns.THEME
local SW = ns.StatWeights

local WIDTH, MIN_H, MAX_H = 860, 440, 760
local CARD, CARD_GAP = 6, 10
local CARD_TITLE_H, CARD_INSET, CARD_BOTTOM = 40, 16, 12
local COUNT_DROP = 2
local SCROLL_TUCK = 6
local ROW_H, GROUP_H, ADD_H = 28, 30, 34
local GROUP_DROP = 8
local NAME_X, NAME_W, VALUE_W, VALUE_GAP, BAR_H = 14, 140, 52, 10, 6
local BOX_PAD = 6
local RESET_SIZE, RESET_GAP = 16, 6
local DOT_SIZE = 6
local UP_ROW_H, UP_ICON, UP_GAP, UP_MAX = 44, 30, 10, 10
local GAIN_W, GAIN_BAR_W, GAIN_BAR_H = 70, 60, 4
local NOTE_GAP = 16
local FIRST_BUTTON_GAP = 18
local OFF_ALPHA = 0.35
local HOVER_ALPHA = 0.04
local TITLE_SIZE, LABEL_SIZE, SMALL_SIZE = 13, 12, 11
local MAX_WORTH = SW.MAX_WORTH
local SAMPLE_GAIN = 9
local PERCENT = SW.PERCENT
local ROUND = 0.5
local ANY_LENGTH = 0
local NO_TAB_W = 1
local FILTER = "TRILINEAR"
local BOX_FONT = "GameFontHighlightSmall"

local PAGE = "BiS List/Settings"
local DOT = "  \194\183  "
local WEIGHT = "%g"
local SPEC_SHORT = "^(.-)%s+%S+$"
local TEXT_WORTH = ns.L("1 %s is worth %g to %s.")
local TEXT_DEFAULT = ns.L("Default %g. Type a new number, or 0 to leave it out.")
local TEXT_RESET_STAT = ns.L("Back to the default")
local TEXT_IMPORT_FOR = ns.L("Import weights for %s\n%s")
local TEXT_IMPORT_HELP = ns.L("A Naowh weights line, or a WoWSims EP export (in WoWSims: Stat Weights, Copy to Current EP, Export)")
local TEXT_YOUR_WEIGHTS = ns.L("Your %s weights")
local TEXT_RESET_ASK = ns.L("Put every %s weight back to the defaults?")
local TEXT_ADD_TITLE = ns.L("Add a stat")
local TEXT_ADD_LINK = ns.L("+ Add a stat")
local TEXT_ALL_YOURS = ns.L("Everything on your BiS list is yours, or no better.")
local TEXT_TURN_ON_BIS = ns.L("Turn on the BiS List and pick your BiS to see your best upgrades here.")
local TEXT_SHOWN_OF = ns.L("%d of %d")
local TEXT_SPEC_TIP = ns.L("The weights for %s.")
local TEXT_SAMPLE = ns.L("On gear that is an upgrade:  ")
local TEXT_CHANGED = ns.L("Your weights") .. DOT .. ns.L("%d changed")
local TEXT_DEFAULTS = ns.L("Default weights") .. DOT
local TEXT_TITLE, TEXT_ABOUT = ns.L("Stat Weights"), ns.L("What a point of each stat is worth to your spec.")
local TEXT_RESET, TEXT_RESET_TIP = ns.L("Reset to Default"), ns.L("Puts every weight of this spec back to the defaults. Asks first.")
local TEXT_EXPORT, TEXT_EXPORT_TIP = ns.L("Export these weights"), ns.L("A line to share them with.")
local TEXT_IMPORT, TEXT_IMPORT_TIP = ns.L("Import weights"), ns.L("A Naowh weights line, or a WoWSims EP export.")
local TEXT_WEIGHTS_CARD, TEXT_UPGRADES_CARD = ns.L("Weights"), ns.L("Best Upgrades")
local BIG = { hit = true, shit = true, crit = true, haste = true, scrit = true, dodge = true, block = true,
    threat = true, dps = true, dmg = true }
local GROUP_TITLES = { ns.L("PER POINT"), ns.L("PER 1% OR WEAPON DPS") }
local UPGRADE_RGB = { r = 0.12, g = 1, b = 0 }
local TITLE_RGB = ns.Shared.Style.TIP_TITLE_RGB

local byStat = {}
for _, stat in ipairs(SW.STATS) do byStat[stat[1]] = stat end

local window, editing, boxLook
local adding = {}
local focus
local queued = false
local points, big, rest = {}, {}, {}
local upgrades, gainOf, slotOf = {}, {}, {}
local Draw, QueueDraw

local function Apply(box)
    local row = box:GetParent()
    local value = tonumber((box:GetText():gsub(",", ".")))
    if value and value >= 0 and value < MAX_WORTH then
        adding[row.stat] = nil
        SW.Set(row.spec, row.stat, value)
        QueueDraw()
    else
        box:SetText(WEIGHT:format(row.value))
    end
end

local function BoxEnter(box) box:ClearFocus() end

local function BoxEscape(box)
    box:SetText(WEIGHT:format(box:GetParent().value))
    box:ClearFocus()
end

local function RowEnter(row)
    local spec = SW.Spec(row.spec)
    if not ns.Shared.Parts.Tip(row, "ANCHOR_RIGHT") then return end
    local w = TITLE_RGB
    GameTooltip:SetText(TEXT_WORTH:format(byStat[row.stat][2], row.value, spec.name), w.r, w.g, w.b)
    GameTooltip:AddLine(TEXT_DEFAULT:format(SW.Default(row.spec, row.stat)), T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function ResetStat(button)
    local row = button:GetParent()
    SW.Set(row.spec, row.stat, nil)
end

local function ValueBox(row)
    boxLook = boxLook or { inset = 0, border = T.line, hover = false, sunken = false }
    local box = ns.NewEditBox(row, boxLook)
    box:SetSize(VALUE_W, ROW_H - BOX_PAD)
    box:SetPoint("RIGHT", -(RESET_SIZE + RESET_GAP), 0)
    box:SetFontObject(BOX_FONT)
    box:SetJustifyH("CENTER")
    box:SetScript("OnEnterPressed", BoxEnter)
    box:SetScript("OnEscapePressed", BoxEscape)
    box:SetScript("OnEditFocusLost", Apply)
    return box
end

local function NewRow(parent)
    local Parts = ns.Shared.Parts
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_H)
    row:EnableMouse(true)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row.dot = row:CreateTexture(nil, "ARTWORK")
    row.dot:SetTexture(ns.Shared.Style.ROUND, nil, nil, FILTER)
    row.dot:SetVertexColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b, 1)
    row.dot:SetSize(DOT_SIZE, DOT_SIZE)
    row.dot:SetPoint("LEFT", 0, 0)
    row.name = ns.Font(row, LABEL_SIZE, nil, T.fg)
    row.name:SetPoint("LEFT", NAME_X, 0)
    row.name:SetWidth(NAME_W)
    row.name:SetJustifyH("LEFT")
    row.reset = Parts.IconButton(row, ResetStat, ns.Shared.Style.CROSS, 0, TEXT_RESET_STAT)
    row.reset:SetSize(RESET_SIZE, RESET_SIZE)
    row.reset.icon:SetSize(RESET_SIZE, RESET_SIZE)
    row.reset:SetPoint("RIGHT", 0, 0)
    row.box = ValueBox(row)
    row.track = ns.Solid(row, "BACKGROUND", T.line, 1)
    row.track:SetPoint("LEFT", NAME_X + NAME_W, 0)
    row.track:SetPoint("RIGHT", row.box, "LEFT", -VALUE_GAP, 0)
    row.track:SetHeight(BAR_H)
    row.bar = ns.Solid(row, "ARTWORK", T.accent, 1)
    row.bar:SetPoint("LEFT", row.track, "LEFT")
    row.bar:SetHeight(BAR_H)
    return row
end

local function Import()
    local key = editing
    ns.PromptText(TEXT_IMPORT_FOR:format(SW.Spec(key).name, ns.Color("muted", TEXT_IMPORT_HELP)), "", ANY_LENGTH,
        function(text)
            local _, message = SW.Import(text, key)
            ns.Print(message)
        end)
end

local function Export()
    ns.ShowCopyLine(TEXT_YOUR_WEIGHTS:format(SW.Spec(editing).name), SW.Export(editing))
end

local function Reset()
    local key = editing
    ns.Confirm(TEXT_RESET_ASK:format(SW.Spec(key).name), function()
        SW.Reset(key)
    end)
end

local function AddStat(key)
    adding[key], focus = true, key
    Draw()
end

local function Split(weights)
    wipe(points)
    wipe(big)
    wipe(rest)
    for _, stat in ipairs(SW.STATS) do
        local key = stat[1]
        if (weights[key] or 0) > 0 or adding[key] then
            local list = BIG[key] and big or points
            list[#list + 1] = key
        else
            rest[#rest + 1] = key
        end
    end
end

local function AddMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(TEXT_ADD_TITLE)
        for _, key in ipairs(rest) do
            root:CreateButton(byStat[key][2], function() AddStat(key) end)
        end
    end)
end

local function ByGain(a, b) return gainOf[a] > gainOf[b] end

local function BestUpgrades(weights)
    wipe(upgrades)
    wipe(gainOf)
    wipe(slotOf)
    local B = ns.BiS
    local list = B and B.On and B.On() and B.Lists.List()
    if not list then return upgrades end
    local Items = ns.Shared.Items
    local power = SW.Power(weights)
    for _, gear in ipairs(Items.GEAR_SLOTS) do
        local slot = gear[1]
        local id = list.slots[slot]
        if id and not gainOf[id] and not Items.Wearing(slot, id) then
            local gain = SW.Gain(id, slot, weights, power)
            if gain and gain >= SW.MIN_GAIN then
                gainOf[id], slotOf[id] = gain, slot
                upgrades[#upgrades + 1] = id
            end
        end
    end
    table.sort(upgrades, ByGain)
    return upgrades
end

local function ItemLink(id)
    local _, link = C_Item.GetItemInfo(id)
    return link
end

local function UpgradeEnter(row)
    row.hover:Show()
    if not ns.Shared.Parts.Tip(row, "ANCHOR_RIGHT") then return end
    GameTooltip:SetItemByID(row.id)
    GameTooltip:Show()
end

local function UpgradeLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function UpgradeClick(row)
    if not IsModifiedClick() then return end
    local link = ItemLink(row.id)
    if link then HandleModifiedItemClick(link) end
end

local function UpgradeGain(row)
    local inset = (UP_ROW_H - UP_ICON) / 2
    row.gain = ns.Font(row, LABEL_SIZE, nil, UPGRADE_RGB)
    row.gain:SetPoint("TOPRIGHT", 0, -inset)
    row.gain:SetWidth(GAIN_W)
    row.gain:SetJustifyH("RIGHT")
    row.track = ns.Solid(row, "BACKGROUND", T.line, 1)
    row.track:SetPoint("BOTTOMRIGHT", 0, inset)
    row.track:SetSize(GAIN_BAR_W, GAIN_BAR_H)
    row.bar = ns.Solid(row, "ARTWORK", UPGRADE_RGB, 1)
    row.bar:SetPoint("LEFT", row.track, "LEFT")
    row.bar:SetHeight(GAIN_BAR_H)
end

local function NewUpgrade(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(UP_ROW_H)
    row.hover = ns.Solid(row, "BACKGROUND", T.fg, HOVER_ALPHA)
    row.hover:SetAllPoints()
    row.hover:Hide()
    row.icon = ns.Shared.Parts.ItemIcon(row, UP_ICON)
    row.icon:SetPoint("LEFT", 0, 0)
    UpgradeGain(row)
    row.name = ns.Font(row, LABEL_SIZE, nil, T.fg)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", UP_GAP, 0)
    row.name:SetPoint("RIGHT", row.gain, "LEFT", -UP_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.slot = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.slot:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", UP_GAP, 0)
    row:SetScript("OnEnter", UpgradeEnter)
    row:SetScript("OnLeave", UpgradeLeave)
    row:SetScript("OnClick", UpgradeClick)
    return row
end

local function Group(card, i, title, y)
    local text = card.groups[i]
    if not text then
        text = ns.Font(card.child, SMALL_SIZE, nil, T.accentSoft)
        card.groups[i] = text
    end
    text:SetText(title)
    text:ClearAllPoints()
    text:SetPoint("BOTTOMLEFT", card.child, "TOPLEFT", 0, -(y + GROUP_H - GROUP_DROP))
    text:Show()
    return y + GROUP_H
end

local function PaintStat(row, key, value, changed, track, top)
    row.name:SetText(byStat[key][2])
    row.bar:SetWidth(math.max(1, top > 0 and track * value / top or 1))
    row.dot:SetShown(changed)
    row.reset:SetShown(changed)
    local color = changed and T.accent or T.fg
    row.box:SetText(WEIGHT:format(value))
    row.box:SetTextColor(color.r, color.g, color.b)
    row:Show()
    if focus ~= key then return end
    focus = nil
    row.box:SetFocus()
    row.box:HighlightText()
end

local function FillStats(card, keys, weights, used, y)
    local spec = editing
    local top = 0
    for _, key in ipairs(keys) do top = math.max(top, weights[key] or 0) end
    local width = card.child:GetWidth()
    local track = width - NAME_X - NAME_W - VALUE_GAP - VALUE_W - RESET_SIZE - RESET_GAP
    for _, key in ipairs(keys) do
        used = used + 1
        local row = card.rows[used] or NewRow(card.child)
        card.rows[used] = row
        local value = weights[key] or 0
        row.spec, row.stat, row.value = spec, key, value
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetWidth(width)
        PaintStat(row, key, value, SW.Changed(spec, key), track, top)
        y = y + ROW_H
    end
    return used, y
end

local function FillWeights(card, weights)
    Split(weights)
    for _, text in ipairs(card.groups) do text:Hide() end
    local used, y, g = 0, 0, 0
    for i, keys in ipairs({ points, big }) do
        if #keys > 0 then
            g = g + 1
            y = Group(card, g, GROUP_TITLES[i], y)
            used, y = FillStats(card, keys, weights, used, y)
        end
    end
    for i = used + 1, #card.rows do card.rows[i]:Hide() end
    card.add:ClearAllPoints()
    card.add:SetPoint("LEFT", card.child, "TOPLEFT", 0, -(y + ADD_H / 2))
    card.add:SetShown(#rest > 0)
    return y + ADD_H
end

local function PaintUpgrade(row, id, i, width, most)
    local Items = ns.Shared.Items
    row.id = id
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -((i - 1) * UP_ROW_H))
    row:SetWidth(width)
    row.icon.texture:SetTexture(C_Item.GetItemIconByID(id))
    ns.Shared.Parts.MarkForever(row.icon, id)
    row.name:SetText(Items.QualityHex(id) .. Items.Name(id) .. "|r")
    row.slot:SetText(Items.SlotName(slotOf[id]) or "")
    row.gain:SetText("+" .. math.floor(gainOf[id] + ROUND) .. "%")
    row.bar:SetWidth(math.max(1, GAIN_BAR_W * gainOf[id] / most))
    row:Show()
end

local function CountText(shown, total)
    if shown == 0 then return "" end
    return total > shown and TEXT_SHOWN_OF:format(shown, total) or tostring(shown)
end

local function FillUpgrades(card, weights)
    local ids = BestUpgrades(weights)
    local shown = math.min(#ids, UP_MAX)
    local most = shown > 0 and gainOf[ids[1]] or 1
    local width = card.child:GetWidth()
    for i = 1, shown do
        local row = card.rows[i] or NewUpgrade(card.child)
        card.rows[i] = row
        PaintUpgrade(row, ids[i], i, width, most)
    end
    for i = shown + 1, #card.rows do card.rows[i]:Hide() end
    card.note:SetShown(shown == 0)
    card.note:SetText(ns.BiS and ns.BiS.On and ns.BiS.On() and TEXT_ALL_YOURS or TEXT_TURN_ON_BIS)
    card.count:SetText(CountText(shown, #ids))
    return shown > 0 and shown * UP_ROW_H or UP_ROW_H
end

local function SpecTabs()
    local items = {}
    for _, spec in ipairs(SW.ClassSpecs()) do
        items[#items + 1] = { key = spec.key, label = spec.name:match(SPEC_SHORT) or spec.name,
            tip = TEXT_SPEC_TIP:format(spec.name) }
    end
    return items
end

local function Opacity()
    return math.floor((ns.QoLSettings.Get("bisWindowAlpha") or 1) * PERCENT + ROUND)
end

local function SetOpacity(value)
    ns.QoLSettings.Set("bisWindowAlpha", value / PERCENT)
end

local function Paint()
    local alpha = ns.QoLSettings and ns.QoLSettings.Get("bisWindowAlpha") or 1
    window.backdrop:Paint(alpha)
    window.opacity._refreshValue()
end

local function Changes()
    local changed = 0
    for _, stat in ipairs(SW.STATS) do
        if SW.Changed(editing, stat[1]) then changed = changed + 1 end
    end
    return changed
end

local function PaintNote(changed)
    window.note.text:SetText(changed > 0 and TEXT_CHANGED:format(changed)
        or TEXT_DEFAULTS .. ns.StatWeightDefaultsUpdated)
    window.note:SetWidth(math.max(1, math.ceil(window.note.text:GetStringWidth())))
end

function Draw()
    local Parts = ns.Shared.Parts
    local spec = SW.Spec(editing)
    local weights = SW.For(editing)
    local changed = Changes()
    Parts.PaintTabs(window.specs, editing)
    window.reset:SetAlpha(changed > 0 and 1 or OFF_ALPHA)
    window.reset:EnableMouse(changed > 0)
    local listH = FillWeights(window.weights, weights)
    local upH = FillUpgrades(window.upgrades, weights)
    local id = upgrades[1]
    window.sample:SetText(TEXT_SAMPLE .. Parts.UpgradeLine(id and gainOf[id] or SAMPLE_GAIN, spec.name))
    PaintNote(changed)
    window.weights.child:SetHeight(listH)
    window.upgrades.child:SetHeight(upH)
    local h = window.cardsTop + CARD_TITLE_H + math.max(listH, upH) + CARD_BOTTOM + window.footerH
    window:SetHeight(math.min(MAX_H, math.max(MIN_H, h)))
end

local function Flush()
    queued = false
    if window and window:IsShown() then Draw() end
end

function QueueDraw()
    if queued or not (window and window:IsShown()) then return end
    queued = true
    C_Timer.After(0, Flush)
end

local function PickSpec(key)
    editing = key
    wipe(adding)
    Draw()
end

local function Card(left, right, top, bottom, title)
    local St = ns.Shared.Style
    window.backdrop:Card(left, top, right, bottom)
    local card = { rows = {}, groups = {} }
    card.title = ns.Font(window, TITLE_SIZE, nil, T.fg)
    card.title:SetPoint("TOPLEFT", left + CARD_INSET, -(top + CARD_INSET))
    card.title:SetText(title)
    card.count = ns.Font(window, SMALL_SIZE, nil, T.muted)
    card.count:SetPoint("TOPRIGHT", -(right + CARD_INSET), -(top + CARD_INSET + COUNT_DROP))
    card.scroll = ns.UI.SlimScroll(window)
    card.scroll:SetPoint("TOPLEFT", left + CARD_INSET, -(top + CARD_TITLE_H))
    card.scroll:SetPoint("BOTTOMRIGHT", -(right + CARD_INSET + St.SCROLLBAR - SCROLL_TUCK), bottom + CARD_BOTTOM)
    card.child = CreateFrame("Frame", nil, card.scroll)
    card.child:SetWidth(WIDTH - left - right - CARD_INSET * 2 - St.SCROLLBAR + SCROLL_TUCK)
    card.scroll:SetScrollChild(card.child)
    card.note = ns.Font(card.child, LABEL_SIZE, nil, T.muted)
    card.note:SetPoint("TOPLEFT", 0, -NOTE_GAP / 2)
    card.note:SetPoint("RIGHT")
    card.note:SetJustifyH("LEFT")
    card.note:Hide()
    return card
end

local function TitleBar(Parts, St)
    local close = Parts.TitleBar(window, TEXT_TITLE, TEXT_ABOUT, PAGE)
    local opacityIcon
    opacityIcon, window.opacity = Parts.Opacity(window, close, Opacity, SetOpacity)
    window.reset = Parts.BarButton(window, St.CROSS, TEXT_RESET, TEXT_RESET_TIP, Reset)
    window.reset:SetPoint("RIGHT", opacityIcon, "LEFT", -FIRST_BUTTON_GAP, 0)
    local export = Parts.BarButton(window, St.EXPORT, TEXT_EXPORT, TEXT_EXPORT_TIP, Export)
    export:SetPoint("RIGHT", window.reset, "LEFT", -St.BAR_GAP, 0)
    local import = Parts.BarButton(window, St.IMPORT, TEXT_IMPORT, TEXT_IMPORT_TIP, Import)
    import:SetPoint("RIGHT", export, "LEFT", -St.BAR_GAP, 0)
end

local function Specs(Parts, top, pad)
    local specs = SpecTabs()
    window.specs = Parts.Tabs(window, NO_TAB_W, specs, PickSpec)
    Parts.FitTabs(window.specs, specs, CARD_INSET)
    window.specs:SetPoint("TOPLEFT", CARD + pad, -top)
    window.sample = ns.Font(window, SMALL_SIZE, nil, T.muted)
    window.sample:SetPoint("LEFT", window.specs, "RIGHT", NOTE_GAP, 0)
    window.sample:SetPoint("RIGHT", -(CARD + pad), 0)
    window.sample:SetJustifyH("RIGHT")
    window.sample:SetWordWrap(false)
end

local function OnSetting(key)
    if key == "bisWindowAlpha" and window:IsShown() then Paint() end
end

local function Build()
    local Shared = ns.Shared
    local Parts, St = Shared.Parts, Shared.Style
    local HEADER, FOOTER, PAD = St.WINDOW_HEADER, St.WINDOW_FOOTER, St.WINDOW_PAD
    window = Parts.Window(WIDTH, MIN_H, "statWeightsWindow")
    TitleBar(Parts, St)
    Parts.FooterBrand(window, PAGE)
    window.note = Parts.FooterNote(window, "")
    local top = HEADER + PAD
    Specs(Parts, top, PAD)
    window.cardsTop = top + St.TAB_H + PAD
    window.footerH = FOOTER + CARD
    local half = math.floor((WIDTH - CARD * 2 - CARD_GAP) / 2)
    window.weights = Card(CARD, WIDTH - CARD - half, window.cardsTop, window.footerH, TEXT_WEIGHTS_CARD)
    window.weights.add = Parts.Link(window.weights.child, AddMenu)
    Parts.SetLink(window.weights.add, TEXT_ADD_LINK)
    window.upgrades = Card(CARD + half + CARD_GAP, CARD, window.cardsTop, window.footerH, TEXT_UPGRADES_CARD)
    SW.OnChange(QueueDraw)
    if ns.BiS and ns.BiS.OnListChange then ns.BiS.OnListChange(QueueDraw) end
    ns.QoLSettings.OnChange(OnSetting)
end

function ns.OpenStatWeightsWindow()
    if not window then Build() end
    editing = editing or SW.ActiveSpec()
    window:SetScale(ns.UIScale())
    window:Show()
    Paint()
    Draw()
end

function ns.ToggleStatWeightsWindow()
    if window and window:IsShown() then window:Hide() else ns.OpenStatWeightsWindow() end
end

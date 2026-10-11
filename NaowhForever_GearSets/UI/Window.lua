-- Window.lua: the Gear Sets window (/nfgear), every set with Equip, Save, Rename, Icon and Delete.
local ns = _G.NaowhForever

local T = ns.THEME
local S = ns.QoLSettings
local G = ns.GearSets
local C, Look = G.C, G.Look
local Shared = ns.Shared
local Parts, St = Shared.Parts, G.Style

local WIDTH, HEIGHT = 680, 560
local HEADER, FOOTER, PAD = St.WINDOW_HEADER, St.WINDOW_FOOTER, St.WINDOW_PAD
local INSET, SCROLLBAR = St.CONTENT_INSET, St.SCROLLBAR
local CARD = 6
local SCROLL_GAP = 4
local NEW_W, NEW_H = 150, 26
local ROW_H, ICON, ICON_GAP = 52, 36, 12
local ACTION_W, ACTION_H, ACTION_GAP = 64, 22, 4
local NAME_SIZE, STATUS_SIZE, LINE_GAP = 13, 11, 3
local PERCENT = C.PERCENT
local ROUND = C.ROUND
local BLACK, MISSING_RGB = St.BLACK, St.MISSING_RGB
local EVENTS = { "EQUIPMENT_SETS_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "EQUIPMENT_SWAP_FINISHED" }
local WINDOW_KEY = "gearSetsWindow"

local TEXT_TITLE = ns.L("Gear Sets")
local TEXT_TITLE_TIP = ns.L("Your equipment sets, the same ones the character sheet keeps.")
local TEXT_NEW = ns.L("New Gear Set")
local TEXT_NEW_TIP = ns.L("Saves what you are wearing now as a new set.")
local TEXT_NO_SETS = ns.L("No gear sets yet. New Gear Set saves what you wear now as one.")
local TEXT_EQUIPPED = ns.L("Equipped")

local window, scroll, view, kinds

local ACTIONS = {
    { "Equip", function(set) G.EquipByHand(set.id) end },
    { "Save", function(set) ns.SaveGearSet(set.id, set.name) end },
    { "Rename", function(set) ns.RenameGearSet(set.id, set.name) end },
    { "Icon", function(set) ns.ChangeGearSetIcon(set.id, set.name) end },
    { "Delete", function(set) ns.DeleteGearSet(set.id, set.name) end },
}
local ACTION_TIPS = {
    Equip = ns.L("Puts this set on. In combat, it goes on when the fight ends."),
    Save = ns.L("Saves what you are wearing now into this set."),
    Rename = ns.L("Renames the set; Wear While Mounted and Resting follow it."),
    Icon = ns.L("Picks a new icon for the set."),
    Delete = ns.L("Deletes the set. Asks first."),
}

local function Opacity()
    return math.floor((S.Get("gearWindowAlpha") or 1) * PERCENT + ROUND)
end

local function SetOpacity(value)
    S.Set("gearWindowAlpha", value / PERCENT)
end

local TEXT_ITEM, TEXT_ITEMS = ns.L("%d item"), ns.L("%d items")
local TEXT_SET, TEXT_SETS = ns.L("%d set"), ns.L("%d sets")
local TEXT_MISSING = ns.L("%d missing")

local function Count(n, one, many)
    return (n == 1 and one or many):format(n)
end

local function NewActions(row)
    row.actions = {}
    local right = nil
    for i = #ACTIONS, 1, -1 do
        local action = ACTIONS[i]
        local button = ns.Button(row, action[1], ACTION_W, ACTION_H, function() action[2](row.set) end)
        ns.Tooltip(button, action[1], ACTION_TIPS[action[1]])
        if right then
            button:SetPoint("RIGHT", right, "LEFT", -ACTION_GAP, 0)
        else
            button:SetPoint("RIGHT", -St.INDENT, 0)
        end
        right = button
        row.actions[i] = button
    end
    return right
end

local function NewSet(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.stripe = ns.Solid(row, "BACKGROUND", T.fg, St.STRIPE)
    row.stripe:SetAllPoints()
    row.icon = CreateFrame("Frame", nil, row)
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("LEFT", St.INDENT, 0)
    row.icon.texture, row.icon.edge = Look.Dress(row.icon)
    local right = NewActions(row)
    row.name = ns.Font(row, NAME_SIZE, nil, T.fg)
    row.name:SetPoint("BOTTOMLEFT", row.icon, "RIGHT", ICON_GAP, LINE_GAP / 2)
    row.name:SetPoint("RIGHT", right, "LEFT", -ICON_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.status = ns.Font(row, STATUS_SIZE, nil, T.muted)
    row.status:SetPoint("TOPLEFT", row.icon, "RIGHT", ICON_GAP, -LINE_GAP / 2)
    row.status:SetJustifyH("LEFT")
    return row
end

local function Status(set)
    if set.lost > 0 then return TEXT_MISSING:format(set.lost), MISSING_RGB end
    if set.equipped then return TEXT_EQUIPPED, St.HAVE_RGB end
    return Count(set.items, TEXT_ITEM, TEXT_ITEMS), T.muted
end

local function SetSet(row, set, stripe)
    row.set = set
    row.stripe:SetShown(stripe)
    row.icon.texture:SetTexture(set.icon)
    row.icon.texture:SetDesaturated(set.lost > 0)
    local edge = set.equipped and T.accent or BLACK
    row.icon.edge:SetColor(edge.r, edge.g, edge.b, 1)
    row.name:SetText(set.name)
    local status, color = Status(set)
    row.status:SetText(status)
    row.status:SetTextColor(color.r, color.g, color.b)
    return ROW_H
end

local Draw = {}

function Draw:Redraw()
    self:Clear()
    local sets = G.Sets()
    for i, set in ipairs(sets) do self:Add("set", set, i % 2 == 0) end
    if #sets == 0 then self:Note(TEXT_NO_SETS) end
    window.note.text:SetText(Count(#sets, TEXT_SET, TEXT_SETS))
    window.note:SetWidth(math.max(1, math.ceil(window.note.text:GetStringWidth())))
    self:Fit(EVENTS)
end

local function Kinds()
    if kinds then return kinds end
    kinds = Shared.View.NewKinds()
    kinds.set = { New = NewSet, Set = SetSet }
    return kinds
end

local function Build()
    window = Parts.Window(WIDTH, HEIGHT, WINDOW_KEY)
    window.backdrop:Card(CARD, HEADER + CARD, CARD, FOOTER + CARD)
    local close = Parts.TitleBar(window, TEXT_TITLE, TEXT_TITLE_TIP, C.PAGE)
    local _, opacity = Parts.Opacity(window, close, Opacity, SetOpacity)
    window.opacity = opacity
    Parts.FooterBrand(window, C.PAGE)
    window.note = Parts.FooterNote(window, "")

    local left, top = CARD + INSET, HEADER + CARD + PAD
    local new = ns.AccentBorder(ns.Button(window, TEXT_NEW, NEW_W, NEW_H, ns.NewGearSet))
    ns.Tooltip(new, TEXT_NEW, TEXT_NEW_TIP)
    new:SetPoint("TOPLEFT", left, -top)
    top = top + NEW_H + PAD
    scroll = ns.UI.SlimScroll(window)
    scroll:SetPoint("TOPLEFT", left, -top)
    scroll:SetPoint("BOTTOMRIGHT", -(CARD + SCROLLBAR + SCROLL_GAP), FOOTER + CARD + PAD)
    view = Shared.View.New(scroll, Kinds(), Draw)
    view:SetWidth(WIDTH - left - CARD - SCROLLBAR - INSET)
    scroll:SetScrollChild(view)
end

local function Paint()
    window.backdrop:Paint(Opacity() / PERCENT)
    window.opacity._refreshValue()
end

local function OnSettingChanged(key)
    if key == "gearWindowAlpha" and window and window:IsShown() then Paint() end
end

local function OnApply()
    if not (window and window:IsShown()) then return end
    Paint()
    view:Redraw()
end

function ns.OpenGearSetsWindow()
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window:Show()
    Paint()
    view:Redraw()
end

function ns.ToggleGearSetsWindow()
    if window and window:IsShown() then window:Hide() else ns.OpenGearSetsWindow() end
end

S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", OnApply)

-- Picker.lua: a slot's picker, in a side panel beside the window it was opened from.
local ns = _G.NaowhForever

local B = ns.BiS
local L = B.Lists
local Shared = ns.Shared
local Items, Parts = Shared.Items, Shared.Parts
local St = B.Style

local PANEL_PAD, PANEL_W, PICKER_BOX_W, PLACE_DOT = St.PANEL_PAD, St.PANEL_W, St.PICKER_BOX_W, St.PLACE_DOT
local BOX_H = 24
local PADS = 3
local HINT_X = 7
local FULL_OPACITY = 1
local TEXT_ADD = "Add"
local TEXT_HINT = "Item ID, link or Wowhead URL"
local TEXT_NO_ITEM = "There is no item with that ID."
local TEXT_WRONG_SLOT = "%s does not go in the %s slot."

local panel, box

local function Opacity()
    return B.Settings.Get("bisWindowAlpha") or FULL_OPACITY
end

local function Title(slot)
    local spec = L.CurrentSpec()
    return Items.SlotName(slot) .. (spec and ns.Color("muted", PLACE_DOT .. spec.name) or "")
end

local function AddFromBox()
    local slot = panel.view.slot
    local id = Items.IDFrom(box:GetText())
    if not (id and C_Item.GetItemInfoInstant(id)) then return ns.Print(TEXT_NO_ITEM) end
    if not Items.Fits(id, slot) then
        return ns.Print(TEXT_WRONG_SLOT:format(Items.Name(id), Items.SlotName(slot)))
    end
    box:SetText("")
    box:ClearFocus()
    ns.AddBisPick(slot, id)
end

local function Hint(self)
    self.hint:SetShown(self:GetText() == "" and not self:HasFocus())
end

local function Box()
    box = ns.NewEditBox(panel)
    box:SetSize(PICKER_BOX_W, BOX_H)
    box:SetPoint("BOTTOMLEFT", PANEL_PAD, PANEL_PAD)
    box.hint = ns.Font(box, St.TEXT_SIZE, nil, ns.THEME.muted)
    box.hint:SetPoint("LEFT", HINT_X, 0)
    box.hint:SetText(TEXT_HINT)
    box:SetScript("OnTextChanged", Hint)
    box:SetScript("OnEditFocusGained", Hint)
    box:SetScript("OnEditFocusLost", Hint)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEnterPressed", AddFromBox)
end

local function Build()
    panel = Parts.SidePanel({ { TEXT_ADD, AddFromBox } }, B.View.New, Opacity)
    local add = panel.buttons[TEXT_ADD]
    add:SetWidth(PANEL_W - PANEL_PAD * PADS - PICKER_BOX_W)
    Box()
    add:ClearAllPoints()
    add:SetPoint("BOTTOMRIGHT", -PANEL_PAD, PANEL_PAD)
end

local function ListChanged()
    if panel and panel:IsShown() then panel.title:SetText(Title(panel.view.slot)) end
end

function B.OpenPicker(slot, from)
    if not panel then Build() end
    panel.title:SetText(Title(slot))
    box:SetText("")
    Parts.ShowBeside(panel, from)
    panel.view:DrawPicker(slot)
end

B.OnListChange(ListChanged)

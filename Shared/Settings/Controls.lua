-- Controls.lua: the control on a settings row for each kind of setting, made once per row and bound to its setting (Settings.Control).
local ns = _G.NaowhForever
local T = ns.THEME
local Settings = ns.Shared.Settings
local SS = Settings.Style

local PAD, CONTROL_GAP, CONTROL_LEVEL = SS.PAD, SS.CONTROL_GAP, SS.CONTROL_LEVEL
local TRACK_W, BOX_W, BOX_H, BOX_ALPHA = 110, 44, 20, 1
local SLIDER_MIN, SLIDER_MAX, SLIDER_STEP = 0, 1, 1
local CHOICE_W, TEXT_W, BUTTON_W, BUTTON_H = 170, 200, 110, 24
local BINDING_W = 170
local TEXT_GROW, TEXT_INSET = 2, 6
local TEXT_BOX = { inset = TEXT_INSET, border = SS.BORDER_RGB, hover = false }
local NO_SOUND = "none"
local CHOICE_KINDS = { choice = true, font = true, texture = true, sound = true }
local TEXT_NONE = ns.L("None")
local TEXT_ON, TEXT_OFF = ns.L("On"), ns.L("Off")
local TEXT_EMPTY = ns.L("empty")
local TEXT_GO = ns.L("Go")
local NO_ORDER = {}

local Makers = {}
local soundValues, soundOrder
local unitFormats = {}

local function Nothing() end

local function TextCommit(box)
    box:ClearFocus()
    local row = box:GetParent()
    if row.setting then row.setting.set(box:GetText()) end
end

local function TextReset(box)
    local row = box:GetParent()
    if row.setting then box:SetText(row.setting.get() or "") end
    box:ClearFocus()
end

local function ButtonText(setting)
    local text = setting.buttonText
    if type(text) == "function" then text = text() end
    return text or TEXT_GO
end

local function ButtonClicked(row)
    local setting = row.setting
    if not setting then return end
    setting.button()
    if type(setting.buttonText) == "function" then ns.SetButtonText(row.controls.button, ButtonText(setting)) end
end

function Makers.toggle(row)
    return ns.UI.BuildToggleControl(row, row:GetFrameLevel() + CONTROL_LEVEL, row.Get, row.Set)
end

function Makers.slider(row)
    local track, box = ns.UI.BuildSliderCore(row, TRACK_W, SS.SLIDER_H, SS.KNOB, BOX_W, BOX_H, SS.TEXT_SIZE,
        BOX_ALPHA, SLIDER_MIN, SLIDER_MAX, SLIDER_STEP, row.Get, row.Set)
    box:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
    track:SetPoint("RIGHT", box, "LEFT", -CONTROL_GAP, 0)
    track.leftEdge = track
    return track
end

function Makers.choice(row)
    return (ns.UI.BuildDropdownControl(row, CHOICE_W, row:GetFrameLevel() + CONTROL_LEVEL, {}, {}, row.Get, row.Set))
end

Makers.font = Makers.choice
Makers.texture = Makers.choice
Makers.sound = Makers.choice

function Makers.binding(row)
    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(BINDING_W, BUTTON_H)
    holder.fields = {}
    holder._refreshValue = Nothing
    return holder
end

function Makers.colour(row)
    return ns.UI.BuildColorSwatchControl(row, row.Get, row.Set, false)
end

function Makers.text(row)
    local box = ns.NewEditBox(row, TEXT_BOX)
    box:SetSize(TEXT_W, BOX_H + TEXT_GROW)
    box:SetFont(ns.UIFontPath(), SS.TEXT_SIZE, "")
    box:SetTextColor(T.fg.r, T.fg.g, T.fg.b, 1)
    box:SetScript("OnEnterPressed", TextCommit)
    box:SetScript("OnEditFocusLost", TextCommit)
    box:SetScript("OnEscapePressed", TextReset)
    box._refreshValue = function()
        if not box:HasFocus() and row.setting then box:SetText(row.setting.get() or "") end
    end
    return box
end

function Makers.button(row)
    return ns.Button(row, "", BUTTON_W, BUTTON_H, function() ButtonClicked(row) end)
end

local function SoundValues()
    if soundValues then return soundValues, soundOrder end
    local _, names, order = nil, nil, nil
    if ns.SoundChoices then _, names, order = ns.SoundChoices() end
    soundValues, soundOrder = { [NO_SOUND] = TEXT_NONE }, { NO_SOUND }
    for _, key in ipairs(order or NO_ORDER) do
        soundValues[key] = names[key]
        soundOrder[#soundOrder + 1] = key
    end
    return soundValues, soundOrder
end

local function ChoiceValues(setting)
    local kind = setting.kind
    if kind == "font" then return ns.UI.FontChoices(setting.get()) end
    if kind == "texture" then return ns.UI.TextureChoices(setting.get(), setting.texture) end
    if kind == "sound" then return SoundValues() end
    if type(setting.choice) == "function" then return setting.choice() end
    return setting.choice[1] or setting.choice.values, setting.choice[2] or setting.choice.order
end

local function UnitFormat(unit)
    local format = unitFormats[unit]
    if not format then
        format = function(v) return v .. unit end
        unitFormats[unit] = format
    end
    return format
end

local function BindingField(control, setting)
    for _, field in pairs(control.fields) do field:Hide() end
    local field = control.fields[setting.binding]
    if not field then
        field = CreateFrame("Frame", nil, control)
        field:SetAllPoints()
        ns.UI.KeyField(field, setting.binding, setting.label)
        control.fields[setting.binding] = field
    end
    field:Show()
end

local function BindSlider(control, setting)
    local range = setting.slider
    ns.UI.SetSliderRange(control, range[1], range[2], range[3])
    local unit = setting.unit
    control._format = unit and UnitFormat(unit) or nil
    control._refreshValue()
end

local function BindValue(control, setting)
    local kind = setting.kind
    if kind == "slider" then return BindSlider(control, setting) end
    if CHOICE_KINDS[kind] then
        control._values, control._order = ChoiceValues(setting)
        control._refreshLabel()
    elseif kind == "colour" then
        control._hasAlpha = setting.colour == "alpha"
        control._refreshValue()
    elseif kind == "toggle" or kind == "text" then
        control._refreshValue()
    elseif kind == "button" then
        ns.SetButtonText(control, ButtonText(setting))
        if setting.help then ns.Tooltip(control, setting.label, setting.help) end
    elseif kind == "binding" then
        BindingField(control, setting)
    end
end

local Control = {}
Settings.Control = Control

function Control.For(row, kind)
    local control = row.controls[kind]
    if control then return control end
    control = Makers[kind](row)
    if kind ~= "slider" then control:SetPoint("RIGHT", row, "RIGHT", -PAD, 0) end
    row.controls[kind] = control
    return control
end

function Control.Bind(control, setting)
    BindValue(control, setting)
    if setting.tip then
        ns.Tooltip(control, setting.label, setting.tip)
    elseif setting.kind ~= "button" and control._tipHooked then
        control._tipTitle, control._tipBody = nil, nil
    end
end

function Control.Dim(row, control, off)
    local alpha = off and SS.DIM_ALPHA or 1
    row.label:SetAlpha(alpha)
    if control._dim then control._dim(control, off) else control:SetAlpha(alpha) end
    control:EnableMouse(not off)
    local box = control._valBox
    if box then
        box:SetAlpha(alpha)
        box:EnableMouse(not off)
        if off then box:ClearFocus() end
    end
    if off and control._menu then
        control._menu:Close()
        control._menu = nil
    end
end

function Control.Store(setting, v, ...)
    if setting.kind ~= "sound" then
        setting.set(v, ...)
        return
    end
    setting.set(v)
    if v ~= NO_SOUND and ns.UI.PlaySoundKey then ns.UI.PlaySoundKey(v) end
end

function Control.Shown(setting, v)
    local kind = setting.kind
    if kind == "toggle" then return ns.L(v and TEXT_ON or TEXT_OFF) end
    if kind == "slider" and type(v) == "number" then
        if setting.scale then v = math.floor(v / setting.scale + 0.5) end
        return tostring(v) .. (setting.unit or "")
    end
    if CHOICE_KINDS[kind] then
        local values = ChoiceValues(setting)
        local label = values and values[v]
        return label and ns.L(tostring(label)) or nil
    end
    if kind == "text" and type(v) == "string" then return v == "" and ns.L(TEXT_EMPTY) or ('"' .. v .. '"') end
end

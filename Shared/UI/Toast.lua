-- Toast.lua: a toast (Parts.Toast): a banner like the game's level-up one you can drag, a line over a title, icons and buttons under it, shown after the game's banner and gone by itself after a while.
local ns = _G.NaowhForever
local T = ns.THEME
local UI = ns.UI
local Parts = ns.Shared.Parts
local St = ns.Shared.Style

local BANNER_W = 640
local BAND_PAD, TEXT_GAP = 8, 2
local LINE_H = 2
local FILL_ALPHA = 0.6
local SHADOW = 1
local ICON, ICON_GAP = 26, 6
local ICONS_GAP, BUTTONS_GAP = 10, 10
local BUTTON_H, BUTTON_GAP = 26, 8
local FONT_TITLE, FONT_LINE = 26, 14
local HOME_DROP = -140
local NEXT_DELAY = 0

local waiting = {}
local toasts = {}
local gameHooked = false

local function Place(toast)
    local pos = toast.store.Get(toast.posKey)
    toast:ClearAllPoints()
    if pos then
        toast:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        toast:SetPoint("TOP", UIParent, "TOP", 0, HOME_DROP)
    end
end

local function DragStart(toast)
    toast.dragging = true
    toast:StartMoving()
end

local function DragStop(toast)
    toast:StopMovingOrSizing()
    toast.dragging = false
    toast.store.Set(toast.posKey, UI.CenterPosition(toast))
    if toast.expired then toast:Hide() end
end

local function AddButton(toast, spec, i)
    local button = ns.Button(toast, spec.text, spec.width, BUTTON_H, function() spec.click(toast) end)
    if spec.accent then ns.AccentBorder(button) end
    toast.buttons[i] = button
    toast.buttonsW = toast.buttonsW + spec.width + (i > 1 and BUTTON_GAP or 0)
end

local function Fade(toast, layer, color, alpha)
    local edge = CreateColor(color.r, color.g, color.b, 0)
    local middle = CreateColor(color.r, color.g, color.b, alpha)
    local halves = {}
    for i = 1, 2 do
        local half = toast:CreateTexture(nil, layer)
        half:SetColorTexture(1, 1, 1, 1)
        halves[i] = half
    end
    halves[1]:SetGradient("HORIZONTAL", edge, middle)
    halves[2]:SetGradient("HORIZONTAL", middle, edge)
    return halves
end

local function Span(toast, halves, top, bottom)
    halves[1]:ClearAllPoints()
    halves[1]:SetPoint("TOPLEFT", toast, "TOPLEFT", 0, top)
    halves[1]:SetPoint("BOTTOMRIGHT", toast, "TOP", 0, bottom)
    halves[2]:ClearAllPoints()
    halves[2]:SetPoint("TOPLEFT", toast, "TOP", 0, top)
    halves[2]:SetPoint("BOTTOMRIGHT", toast, "TOPRIGHT", 0, bottom)
end

local function Shadowed(fs, width)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(SHADOW, -SHADOW)
    fs:SetJustifyH("CENTER")
    fs:SetWidth(width)
    return fs
end

function Parts.Toast(spec)
    local toast = CreateFrame("Frame", spec.name, UIParent)
    toast.store, toast.posKey, toast.width, toast.on = spec.store, spec.posKey, spec.width, spec.on
    toast:SetWidth(BANNER_W)
    toast:SetFrameStrata("DIALOG")
    toast:SetClampedToScreen(true)
    toast:SetMovable(true)
    toast:EnableMouse(true)
    toast:RegisterForDrag("LeftButton")
    toast:SetScript("OnDragStart", DragStart)
    toast:SetScript("OnDragStop", DragStop)
    toast.fill = Fade(toast, "BACKGROUND", T.bg, FILL_ALPHA)
    toast.top = Fade(toast, "ARTWORK", T.accent, 1)
    toast.bottom = Fade(toast, "ARTWORK", T.accent, 1)
    Span(toast, toast.top, 0, -LINE_H)
    toast.line = Shadowed(ns.Font(toast, FONT_LINE, nil), spec.width)
    toast.line:SetPoint("TOP", 0, -(LINE_H + BAND_PAD))
    toast.line:SetWordWrap(true)
    toast.title = Shadowed(ns.Font(toast, FONT_TITLE, nil, T.accent, true), BANNER_W)
    toast.title:SetPoint("TOP", toast.line, "BOTTOM", 0, -TEXT_GAP)
    toast.title:SetWordWrap(false)
    toast.icons = {}
    for i = 1, spec.icons do
        local icon = toast:CreateTexture(nil, "ARTWORK")
        icon:SetTexCoord(St.ICON_CROP, St.ICON_CROP_HIGH, St.ICON_CROP, St.ICON_CROP_HIGH)
        icon:SetSize(ICON, ICON)
        toast.icons[i] = icon
    end
    toast.buttons, toast.buttonsW = {}, 0
    for i, button in ipairs(spec.buttons) do AddButton(toast, button, i) end
    toast.generation = 0
    Place(toast)
    toast:Hide()
    return toast
end

local function PlaceIcons(toast, textures, y)
    local shown = math.min(#textures, #toast.icons)
    local x = -(shown * ICON + (shown - 1) * ICON_GAP) / 2
    for i, icon in ipairs(toast.icons) do
        local texture = textures[i]
        icon:SetShown(texture ~= nil)
        if texture then
            icon:SetTexture(texture)
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", toast, "TOP", x + (i - 1) * (ICON + ICON_GAP), y)
        end
    end
    return shown > 0 and y - ICON - BUTTONS_GAP or y
end

local function PlaceButtons(toast, y)
    for i, button in ipairs(toast.buttons) do
        button:ClearAllPoints()
        if i == 1 then
            button:SetPoint("TOPLEFT", toast, "TOP", -toast.buttonsW / 2, y)
        else
            button:SetPoint("LEFT", toast.buttons[i - 1], "RIGHT", BUTTON_GAP, 0)
        end
    end
end

function Parts.FillToast(toast, title, line, textures)
    toast.title:SetText(title)
    toast.line:SetText(line)
    local band = LINE_H + BAND_PAD + math.ceil(toast.line:GetStringHeight()) + TEXT_GAP
        + math.ceil(toast.title:GetStringHeight()) + BAND_PAD
    Span(toast, toast.fill, 0, -(band + LINE_H))
    Span(toast, toast.bottom, -band, -(band + LINE_H))
    local y = PlaceIcons(toast, textures, -(band + LINE_H + ICONS_GAP))
    PlaceButtons(toast, y)
    toast:SetHeight(-y + BUTTON_H)
end

local function Start(toast, seconds)
    if toast.on and not toast.on() then return false end
    toast:Show()
    toast.expired = false
    toast.generation = toast.generation + 1
    local generation = toast.generation
    C_Timer.After(seconds, function()
        if generation ~= toast.generation then return end
        toast.expired = true
        if not toast.dragging then toast:Hide() end
    end)
    return true
end

local function Busy()
    local banner = EventToastManagerFrame
    if banner and banner:IsShown() then return true end
    for toast in pairs(toasts) do
        if toast:IsShown() then return true end
    end
    return false
end

local function Next()
    if Busy() then return end
    while waiting[1] do
        local turn = table.remove(waiting, 1)
        if Start(turn.toast, turn.seconds) then return end
    end
end

local function SoonNext()
    C_Timer.After(NEXT_DELAY, Next)
end

local function Wait(toast, seconds)
    for _, turn in ipairs(waiting) do
        if turn.toast == toast then
            turn.seconds = seconds
            return
        end
    end
    waiting[#waiting + 1] = { toast = toast, seconds = seconds }
    if not toasts[toast] then
        toasts[toast] = true
        toast:HookScript("OnHide", SoonNext)
    end
    if not gameHooked and EventToastManagerFrame then
        gameHooked = true
        EventToastManagerFrame:HookScript("OnHide", SoonNext)
    end
end

function Parts.ShowToast(toast, seconds)
    if toast:IsShown() then return Start(toast, seconds) end
    Wait(toast, seconds)
    Next()
end

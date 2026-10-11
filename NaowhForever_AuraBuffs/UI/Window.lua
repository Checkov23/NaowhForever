-- Window.lua: the AuraBuffs window (/nfbuffs): the consumables the reminders watch.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local S = A.Settings
local Shared = ns.Shared
local Parts, St = Shared.Parts, Shared.Style

local WIDTH, HEIGHT = 1000, 700
local HEADER, FOOTER, PAD = St.WINDOW_HEADER, St.WINDOW_FOOTER, St.WINDOW_PAD
local INSET, SCROLLBAR, TAB_H, TAB_GAP = St.CONTENT_INSET, St.SCROLLBAR, St.TAB_H, St.TAB_GAP
local CARD = 6
local TABS_W = 260
local TABS_DROP = 8
local TOP_DROP = 4
local SCROLL_GAP = 4
local TOP_Y = -6
local PERCENT, ROUND = A.C.PERCENT, A.C.ROUND
local WINDOW_KEY = "auraBuffsWindow"

local TEXT_TITLE = ns.L("AuraBuffs")
local TEXT_TITLE_TIP = ns.L("The consumables your reminders watch.")

local TABS = {
    { key = "consumables", label = "Consumables", tip = "The items the Buffs & Consumables reminders watch." },
}
local BUILD = { consumables = "BuildAuraBuffConsumables" }

local window, scroll
local contents = {}
local shown = "consumables"
local queued

local function Opacity()
    return math.floor((S.Get("windowAlpha") or 1) * PERCENT + ROUND)
end

local function SetOpacity(value)
    S.Set("windowAlpha", value / PERCENT)
end

local function Note()
    local n = #(S.Get("consumableEntries") or {})
    return n == 1 and ns.L("1 consumable watched") or (n .. ns.L(" consumables watched"))
end

local function Paint()
    window.backdrop:Paint(Opacity() / PERCENT)
    window.opacity._refreshValue()
    window.note.text:SetText(Note())
    window.note:SetWidth(math.max(1, math.ceil(window.note.text:GetStringWidth())))
    Parts.PaintTabs(window.tabs, shown)
end

local function Redraw()
    queued = false
    if not (window and window:IsShown()) then return end
    for key, content in pairs(contents) do content:SetShown(key == shown) end
    local content = contents[shown]
    scroll:SetScrollChild(content)
    ns.UI.BeginReusableRows(content)
    local y = ns[BUILD[shown]](content, TOP_Y)
    content:SetHeight(math.abs(y) + PAD)
    Paint()
end

local function RedrawSoon()
    if queued or not (window and window:IsShown()) then return end
    queued = true
    C_Timer.After(0, Redraw)
end

local function PickTab(key)
    shown = key
    scroll:SetVerticalScroll(0)
    Redraw()
end

local function Build()
    window = Parts.Window(WIDTH, HEIGHT, WINDOW_KEY)
    window.backdrop:Card(CARD, HEADER + CARD, CARD, FOOTER + CARD)
    local close = Parts.TitleBar(window, TEXT_TITLE, TEXT_TITLE_TIP, A.PAGE)
    local _, opacity = Parts.Opacity(window, close, Opacity, SetOpacity)
    window.opacity = opacity
    Parts.FooterBrand(window, A.PAGE)
    window.note = Parts.FooterNote(window, "")

    local left, top = CARD + INSET, HEADER + CARD + PAD + TOP_DROP
    window.tabs = Parts.Tabs(window, TABS_W, TABS, PickTab)
    window.tabs:SetPoint("TOPLEFT", left, -top)
    top = top + TAB_H + TAB_GAP + TABS_DROP
    scroll = ns.UI.SlimScroll(window)
    scroll:SetPoint("TOPLEFT", left, -top)
    scroll:SetPoint("BOTTOMRIGHT", -(CARD + SCROLLBAR + SCROLL_GAP), FOOTER + CARD + PAD)
    for _, tab in ipairs(TABS) do
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(WIDTH - left - CARD - SCROLLBAR - INSET, 1)
        content:Hide()
        contents[tab.key] = content
    end
end

local function OnSettingChanged(key)
    if key == "windowAlpha" and window and window:IsShown() then Paint() end
end

function ns.OpenAuraBuffsWindow(tab)
    if not window then Build() end
    if tab and BUILD[tab] then shown = tab end
    window:SetScale(ns.UIScale())
    window:Show()
    Redraw()
end

function ns.ToggleAuraBuffsWindow()
    if window and window:IsShown() then window:Hide() else ns.OpenAuraBuffsWindow() end
end

S.OnChange(OnSettingChanged)
hooksecurefunc(ns.UI, "RefreshPage", RedrawSoon)
hooksecurefunc(ns, "Apply", RedrawSoon)

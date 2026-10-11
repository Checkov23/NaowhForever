-- Window.lua: the Action Bars window (/nfbars, /nf bars) and its three views: the saved sets, the builder and the import preview.
local ns = _G.NaowhForever
local UI = ns.UI

local A = ns.ActionBars
local S = A.Settings
local St = A.Style
local Builder = A.Builder
local Preview = A.Preview
local Sets = ns.ActionBarSets
local Parts = ns.Shared.Parts

local WIDTH, HEIGHT, CARD = St.WIDTH, St.HEIGHT, St.CARD
local HEADER, FOOTER, PAD = St.WINDOW_HEADER, St.WINDOW_FOOTER, St.WINDOW_PAD
local INSET, SCROLLBAR = St.CONTENT_INSET, St.SCROLLBAR
local PAGE = "Action Bars/Settings"
local TOP_Y = -6
local SCROLL_RIGHT = 4
local PERCENT = 100
local ROUND = 0.5

local TEXT_TITLE = "Action Bars"
local TEXT_SUBTITLE = ns.L("Save your bars, macros and keybinds, then import them on any character.")
local TEXT_BACK = ns.L("Saved Sets")

local W = {}
local window, views, view
local queued

local function Opacity()
    return math.floor((S.Get("windowAlpha") or 1) * PERCENT + ROUND)
end

local function SetOpacity(value)
    S.Set("windowAlpha", value / PERCENT)
end

local function Paint()
    window.backdrop:Paint(Opacity() / PERCENT)
    window.opacity._refreshValue()
    window.note.text:SetText(Sets.Headline())
    window.note:SetWidth(math.max(1, math.ceil(window.note.text:GetStringWidth())))
end

local function Redraw()
    queued = false
    if not (window and window:IsShown()) then return end
    views[view].Draw()
    Paint()
end

local function RedrawSoon()
    if queued or not (window and window:IsShown()) then return end
    queued = true
    C_Timer.After(0, Redraw)
end

local function ShowView(v, on)
    v.frame:SetShown(on)
    for _, part in ipairs(v.cards) do part:SetShown(on) end
    for _, event in ipairs(v.events or {}) do
        if on then window:RegisterEvent(event) else window:UnregisterEvent(event) end
    end
end

local function Show(name)
    view = name
    for key, v in pairs(views) do ShowView(v, key == name) end
    local v = views[name]
    if v.Open then v.Open() end
    window.title:SetText(v.title)
    window.subtitle:SetText(v.subtitle)
    window.backLink:SetShown(name ~= "sets")
    Redraw()
end

local function DrawSets(v)
    UI.BeginReusableRows(v.content)
    local y = ns.BuildActionBarsPage(v.content, TOP_Y)
    v.content:SetHeight(math.abs(y) + PAD)
end

local function BuildSets()
    local v = { cards = window.backdrop:Card(CARD, HEADER + CARD, CARD, FOOTER + CARD) }
    v.frame = CreateFrame("Frame", nil, window)
    v.frame:SetAllPoints()
    local left, top = CARD + INSET, HEADER + CARD + PAD
    v.scroll = UI.SlimScroll(v.frame)
    v.scroll:SetPoint("TOPLEFT", left, -top)
    v.scroll:SetPoint("BOTTOMRIGHT", -(CARD + SCROLLBAR + SCROLL_RIGHT), FOOTER + CARD + PAD)
    v.content = CreateFrame("Frame", nil, v.scroll)
    v.content:SetSize(WIDTH - left - CARD - SCROLLBAR - INSET, 1)
    v.scroll:SetScrollChild(v.content)
    v.title, v.subtitle = TEXT_TITLE, TEXT_SUBTITLE
    function v.Draw() DrawSets(v) end
    return v
end

local function OnHide()
    for _, v in pairs(views) do
        for _, event in ipairs(v.events or {}) do window:UnregisterEvent(event) end
    end
end

local function Build()
    window = Parts.Window(WIDTH, HEIGHT, "actionBarsWindow")
    W.frame = window
    local close = Parts.TitleBar(window, TEXT_TITLE, "", PAGE)
    local _, opacity = Parts.Opacity(window, close, Opacity, SetOpacity)
    window.opacity = opacity
    Parts.FooterBrand(window, PAGE)
    window.note = Parts.FooterNote(window, "")
    Parts.SetLink(window.backLink, TEXT_BACK)
    window.backLink:SetScript("OnClick", function() Show("sets") end)
    if not Builder.HasDraft() then Builder.NewDraft() end
    window:SetScript("OnEvent", RedrawSoon)
    window:HookScript("OnHide", OnHide)
    views = { sets = BuildSets(), build = Builder.Build(W), import = Preview.Build(W) }
end

local function Open(name)
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window:Show()
    Show(name)
end

W.Show, W.Redraw = Show, Redraw

function ns.OpenActionBarsWindow()
    Open("sets")
end

function ns.ToggleActionBarsWindow()
    if window and window:IsShown() then window:Hide() else Open("sets") end
end

function ns.OpenActionBarsBuilder(key)
    Builder.NewDraft(key)
    Open("build")
end

function ns.OpenActionBarsImport(key)
    if not Sets.Get(key) then return end
    Preview.SetKey(key)
    Open("import")
end

S.OnChange(function(key)
    if not (window and window:IsShown()) then return end
    if key == "windowAlpha" then Paint() else RedrawSoon() end
end)

hooksecurefunc(ns.UI, "RefreshPage", function()
    if view == "sets" then RedrawSoon() end
end)
hooksecurefunc(ns, "Apply", RedrawSoon)

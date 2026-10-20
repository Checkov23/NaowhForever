-- Window.lua: the Action Bars page's Bar Sets tab (/nfbars, /nf bars), its views (the saved sets, the builder, the import preview and the keybind map) and its link back to the saved sets.
local ns = _G.NaowhForever
local T = ns.THEME
local UI = ns.UI

local A = ns.ActionBars
local S = A.Settings
local St = A.Style
local Builder = A.Builder
local Preview = A.Preview
local Keys = A.Keys
local Sets = ns.ActionBarSets
local P = A.Parts
local Parts = ns.Shared.Parts

local VIEW_TOP, SCROLLBAR, PAD = St.VIEW_TOP, St.SCROLLBAR, St.WINDOW_PAD
local PAGE = "Action Bars/Bar Sets"
local SCROLL_RIGHT = 4
local SUBTITLE_GAP = 4

local TEXT_BACK = ns.L("Saved Sets")
local TEXT_SETS = ns.L("Bar Sets")

local W = {}
local window, views
local view = "sets"
local queued

local function Paint()
    local v = views[view]
    window.title:SetText(v.title)
    window.subtitle:SetText(v.subtitle)
    window.back:SetShown(view ~= "sets")
    if v.header then v.header:Paint(window.title) end
end

local function Redraw()
    queued = false
    if not (window and window:IsVisible()) then return end
    views[view].Draw()
    Paint()
end

local function RedrawSoon()
    if queued or not (window and window:IsVisible()) then return end
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
    Redraw()
end

local function DrawSets(v)
    v.title, v.subtitle = TEXT_SETS, Sets.Detail()
    v.content:SetWidth(v.scroll:GetWidth())
    UI.BeginReusableRows(v.content)
    local y = ns.BuildActionBarsPage(v.content, 0)
    v.content:SetHeight(math.abs(y) + PAD)
end

local function BuildSets()
    local v = { cards = {} }
    v.frame = CreateFrame("Frame", nil, window)
    v.frame:SetAllPoints()
    v.scroll = UI.SlimScroll(v.frame)
    v.scroll:SetPoint("TOPLEFT", 0, -VIEW_TOP)
    v.scroll:SetPoint("BOTTOMRIGHT", -(SCROLLBAR + SCROLL_RIGHT), 0)
    v.scroll:SetScript("OnSizeChanged", RedrawSoon)
    v.content = CreateFrame("Frame", nil, v.scroll)
    v.content:SetSize(1, 1)
    v.scroll:SetScrollChild(v.content)
    v.header = A.BuildSetsHeader(v.frame)
    function v.Draw() DrawSets(v) end
    v.events = { "ACTIONBAR_SLOT_CHANGED", "SPELLS_CHANGED" }
    return v
end

local function OnShow()
    ShowView(views[view], true)
    Redraw()
end

local function OnHide()
    for _, v in pairs(views) do
        for _, event in ipairs(v.events or {}) do window:UnregisterEvent(event) end
    end
end

local function Build(parent)
    window = CreateFrame("Frame", nil, parent)
    W.frame = window
    window.title = P.Label(window, St.PANEL_TITLE_SIZE, T.fg)
    window.title:SetPoint("TOPLEFT")
    window.subtitle = P.Label(window, St.NOTE_SIZE, T.muted)
    window.subtitle:SetPoint("TOPLEFT", window.title, "BOTTOMLEFT", 0, -SUBTITLE_GAP)
    window.back = Parts.Link(window, function() Show("sets") end, true)
    window.back:SetPoint("TOPRIGHT")
    Parts.FlipLink(window.back)
    Parts.SetLink(window.back, TEXT_BACK)
    if not Builder.HasDraft() then Builder.NewDraft() end
    window:SetScript("OnEvent", RedrawSoon)
    window:SetScript("OnShow", OnShow)
    window:SetScript("OnHide", OnHide)
    views = { sets = BuildSets(), build = Builder.Build(W), import = Preview.Build(W), keys = Keys.Build(W) }
    window:Hide()
    Show(view)
end

local function Host(page)
    local scroll = page:GetParent():GetParent()
    window:SetParent(page)
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", page, "TOPLEFT", 0, page.barsY)
    window:SetPoint("RIGHT", page, "RIGHT")
    window:SetPoint("BOTTOM", scroll, "BOTTOM", 0, PAD)
    window:Show()
end

function ns.BuildActionBarsTab(page, y)
    if not window then Build(page) end
    page.barsY = y
    if not page.barsHooked then
        page.barsHooked = true
        page:HookScript("OnShow", Host)
    end
    Host(page)
    return y
end

local function Open(name)
    if window then Show(name) else view = name end
    ns.OpenOptionsWindow(PAGE)
end

W.Show, W.Redraw = Show, Redraw

function ns.OpenActionBarsWindow()
    Open("sets")
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

function ns.OpenActionBarsKeys(key)
    Keys.SetKey(key)
    Open("keys")
end

S.OnChange(RedrawSoon)

hooksecurefunc(ns.UI, "RefreshPage", function()
    if view == "sets" then RedrawSoon() end
end)
hooksecurefunc(ns, "Apply", RedrawSoon)

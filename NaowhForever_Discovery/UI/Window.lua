-- Window.lua: Discovery's own window (/nfdiscovery): the Library Books and Sleeping Bag tabs.
local ns = _G.NaowhForever

local Discovery = ns.Discovery
local C = Discovery.C
local S = Discovery.Settings
local Library = Discovery.Library
local Bag = Discovery.Bag
local Style = Discovery.Style
local V = Discovery.View
local Shared = ns.Shared
local Parts = Shared.Parts

local WIDTH, HEIGHT = 760, 720
local CARD = 6
local PERCENT = C.PERCENT
local ROUND_HALF = 0.5
local TABS_W = 260
local TABS_TOP_GAP = 4
local SCROLL_TOP_GAP = 8
local SCROLL_GAP = 4
local PAGE = "Discovery/Library Books"
local EVENTS = { "BAG_UPDATE_DELAYED", "QUEST_TURNED_IN", "QUEST_ACCEPTED", "PLAYERBANKSLOTS_CHANGED" }
local FILTERS = {
    { key = "books", label = "Library Books", tip = "Every book for your faction, a tick on those handed in." },
    { key = "bag", label = "Sleeping Bag", tip = "The Cozy Sleeping Bag's hidden quest chain, step by step." },
}
local TEXT_TITLE = ns.L("Discovery")
local TEXT_ABOUT = ns.L("Library books to find around Azeroth, and who to hand them to.")
local TEXT_STEPS = ns.L("Steps")
local TEXT_OPTIONAL = ns.L("Optional")
local TEXT_NOT_FOUND = ns.L("Not found yet")
local TEXT_NOBODY = ns.L("Nobody has found this one on Forever yet.")
local TEXT_NO_BOOKS = ns.L("No books for your faction yet.")
local TEXT_SEPARATOR = "  -  "
local TEXT_FOR_FACTION = ns.L(" books for your faction")

local window, scroll, view
local filter = "books"
local zones
local zoneBooks = {}

local Draw = {}

local function Opacity()
    return math.floor((S.Get("windowAlpha") or 1) * PERCENT + ROUND_HALF)
end

local function SetOpacity(value)
    S.Set("windowAlpha", value / PERCENT)
end

local function ZoneOrder()
    local order, seen = {}, {}
    for _, book in ipairs(ns.LibraryBooks) do
        for _, spot in ipairs(book.spots) do
            if not seen[spot[C.SPOT_MAP]] then
                seen[spot[C.SPOT_MAP]] = true
                order[#order + 1] = spot[C.SPOT_MAP]
            end
        end
    end
    return order
end

local function StepState(i, at)
    if not at or i < at then return "done" end
    if i == at then return "now" end
    return "later"
end

local function DrawBag(self)
    self:Add("bagHero")
    self:Space(Style.SECTION_GAP)
    local steps = Bag.Steps()
    local _, at = Bag.Current()
    self:Section(TEXT_STEPS, #steps)
    for i, step in ipairs(steps) do self:Add("step", step, i, StepState(i, at), i % 2 == 0) end
    local side = ns.SleepingBag.optional
    self:Section(TEXT_OPTIONAL)
    local sideDone = C_QuestLog.IsQuestFlaggedCompleted(side.done)
    self:Add("step", side, "", sideDone and "done" or "optional", false)
    self:Fit(EVENTS)
end

local function GatherZone(mapID)
    wipe(zoneBooks)
    for _, book in ipairs(ns.LibraryBooks) do
        if Library.ForMe(book) then
            for _, spot in ipairs(book.spots) do
                if spot[C.SPOT_MAP] == mapID then
                    zoneBooks[#zoneBooks + 1] = book
                    zoneBooks[#zoneBooks + 1] = spot
                end
            end
        end
    end
    return #zoneBooks / 2
end

local function DrawZone(self, mapID)
    local n = GatherZone(mapID)
    if n == 0 then return 0 end
    self:Section(Library.ZoneName(mapID), n)
    for j = 1, n do
        local book, spot = zoneBooks[j * 2 - 1], zoneBooks[j * 2]
        local sub = Library.Where(spot) .. TEXT_SEPARATOR .. Library.TurnIn(book).name
        self:Add("book", book, spot, sub, j % 2 == 0)
    end
    return n
end

local function DrawUnplaced(self)
    local unplaced = 0
    for _, book in ipairs(ns.LibraryBooks) do
        if book.unplaced and Library.ForMe(book) then
            unplaced = unplaced + 1
            if unplaced == 1 then self:Section(TEXT_NOT_FOUND) end
            self:Add("book", book, nil, TEXT_NOBODY, unplaced % 2 == 0)
        end
    end
    return unplaced
end

local function DrawBooks(self)
    self:Add("hero")
    self:Space(Style.SECTION_GAP)
    local shown = 0
    for i = 1, #zones do shown = shown + DrawZone(self, zones[i]) end
    if shown + DrawUnplaced(self) == 0 then self:Note(TEXT_NO_BOOKS) end
    self:Fit(EVENTS)
end

function Draw:Redraw()
    zones = zones or ZoneOrder()
    self:Clear()
    if filter == "bag" then return DrawBag(self) end
    DrawBooks(self)
end

local function PickFilter(key)
    filter = key
    Parts.PaintTabs(window.filters, filter)
    scroll:SetVerticalScroll(0)
    view:Redraw()
end

local function Build()
    local header, footer = Style.WINDOW_HEADER, Style.WINDOW_FOOTER
    window = Parts.Window(WIDTH, HEIGHT, "discoveryWindow")
    window.backdrop:Card(CARD, header + CARD, CARD, footer + CARD)
    local close = Parts.TitleBar(window, TEXT_TITLE, TEXT_ABOUT, PAGE)
    local _, opacity = Parts.Opacity(window, close, Opacity, SetOpacity)
    window.opacity = opacity
    Parts.FooterBrand(window, PAGE)
    window.note = Parts.FooterNote(window, "")
    local left, top = CARD + Style.CONTENT_INSET, header + CARD + Style.WINDOW_PAD + TABS_TOP_GAP
    window.filters = Parts.Tabs(window, TABS_W, FILTERS, PickFilter)
    window.filters:SetPoint("TOPLEFT", left, -top)
    top = top + Style.TAB_H + Style.TAB_GAP + SCROLL_TOP_GAP
    scroll = ns.UI.SlimScroll(window)
    scroll:SetPoint("TOPLEFT", left, -top)
    scroll:SetPoint("BOTTOMRIGHT", -(CARD + Style.SCROLLBAR + SCROLL_GAP), footer + CARD + Style.WINDOW_PAD)
    view = Shared.View.New(scroll, V.Kinds, Draw)
    view:SetWidth(WIDTH - left - CARD - Style.SCROLLBAR - Style.CONTENT_INSET)
    scroll:SetScrollChild(view)
end

local function Paint()
    window.backdrop:Paint(Opacity() / PERCENT)
    window.opacity._refreshValue()
    local _, total = Library.Progress()
    window.note.text:SetText(total .. TEXT_FOR_FACTION)
    window.note:SetWidth(math.max(1, math.ceil(window.note.text:GetStringWidth())))
    Parts.PaintTabs(window.filters, filter)
end

local function IsShown()
    return window ~= nil and window:IsShown()
end

local function OnSettingChanged(key)
    if key == "windowAlpha" and IsShown() then Paint() end
end

local function OnApply()
    if not IsShown() then return end
    Paint()
    view:Redraw()
end

function ns.OpenDiscoveryWindow(tab)
    if tab then filter = tab end
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window:Show()
    Paint()
    view:Redraw()
end

function ns.ToggleDiscoveryWindow()
    if IsShown() then window:Hide() else ns.OpenDiscoveryWindow() end
end

S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", OnApply)

-- Window.lua: the BiS List's own window (ns.OpenBisWindow, /nfbis, its key binding).
local ns = _G.NaowhForever

local T = ns.THEME
local B = ns.BiS
local S = B.Settings
local L, R, A, Q = B.Lists, B.Rankings, B.Actions, B.Quests
local Parts = ns.Shared.Parts
local St = B.Style

local WIDTH, HEIGHT, HEADER, PAD, FOOTER = St.WINDOW_W, St.WINDOW_H, St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER
local SIDE_W, DOLL_W, SCROLLBAR, CONTENT_INSET = St.SIDE_W, St.DOLL_W, St.SCROLLBAR, St.CONTENT_INSET
local TAB_H, TAB_GAP, LIST_BUTTON_H = St.TAB_H, St.TAB_GAP, St.LIST_BUTTON_H
local BAR_GAP, BORDER_RGB = St.BAR_GAP, St.BORDER_RGB
local SIDE_INNER = SIDE_W - 8
local CONTENT_LEFT = SIDE_W + PAD + 14
local CARD_IN = 6
local CONTENT_RIGHT = 4
local DOLL_GAP = 12
local PAGES_W = 240
local PAGES_TOP = 4
local PAGES_GAP = 8
local SCROLL_IN = 4
local VIEW_IN = 8
local WEIGHTS_GAP = 18
local LIST_TEXT_X, LIST_TEXT_RIGHT = 10, 24
local LIST_ARROW, LIST_ARROW_X = 12, 8
local LIST_ARROW_TURN = -math.pi / 2
local PAGE = "BiS List"
local TEXT_TITLE = ns.L("BiS List")
local TEXT_ABOUT = ns.L("Your best gear for every slot, where it drops, and where to go next.")
local TEXT_WEIGHTS = ns.L("Stat Weights")
local TEXT_WEIGHTS_TIP = ns.L("What each stat is worth to your spec: the upgrade percents and enchants come from them. Set your own.")
local TEXT_EXPORT, TEXT_EXPORT_TIP = ns.L("Export this list"), ns.L("A string to share it with.")
local TEXT_IMPORT, TEXT_IMPORT_TIP = ns.L("Import a list"), ns.L("Paste a shared list: it is added as a new list.")
local TEXT_RANKED_FOR = ns.L("Ranked for %s. Each spec keeps its own picks on this list.")
local TEXT_UPDATED = ns.L("Rankings updated ")
local TEXT_QUESTS, TEXT_QUESTS_COUNT = ns.L("Quests"), ns.L("Quests (%d)")
local TEXT_TURNED_ON = ns.L("BiS List turned on. Turn it off in its settings page.")
local PAGES = {
    { key = "list", label = "Your List", tip = "Your picks for every slot, and where to run next." },
    { key = "quests", label = "Quests", tip = "The quests that reward a pick you do not have yet." },
}

local window, view, doll
local scroll, questsView
local scrollLeft, scrollTop
local page = "list"
local questsLabels = {}
local awayFor
local mapWatched

local function DataDate(text)
    local day, month, year = tostring(text or ""):match("^(%d+) (%a+) (%d+)$")
    if not day then return text end
    return ns.L("%d %s %d"):format(tonumber(day), ns.L(month), tonumber(year))
end

local function SpecTabs()
    local items = {}
    for _, spec in ipairs(R.ClassSpecs()) do
        items[#items + 1] = { key = spec.key, label = L.SpecShort(spec),
            tip = TEXT_RANKED_FOR:format(spec.name) }
    end
    return items
end

local function ListEnter(button)
    button.edge:SetColor(T.accent.r, T.accent.g, T.accent.b, 1)
end

local function ListLeave(button)
    button.edge:SetColor(BORDER_RGB.r, BORDER_RGB.g, BORDER_RGB.b, 1)
end

local function ListButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(SIDE_INNER, LIST_BUTTON_H)
    ns.Solid(button, "BACKGROUND", T.panel, 1):SetAllPoints()
    button.edge = ns.Border(button, BORDER_RGB)
    button.text = ns.Font(button, St.TEXT_SIZE, nil, T.fg)
    button.text:SetPoint("LEFT", LIST_TEXT_X, 0)
    button.text:SetPoint("RIGHT", -LIST_TEXT_RIGHT, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)
    local arrow = Parts.Arrow(button, LIST_ARROW, T.muted)
    arrow:SetRotation(LIST_ARROW_TURN)
    arrow:SetPoint("RIGHT", -LIST_ARROW_X, 0)
    button:SetScript("OnClick", A.ListMenu)
    button:SetScript("OnEnter", ListEnter)
    button:SetScript("OnLeave", ListLeave)
    return button
end

local function PaintUpdated(spec)
    local note = window.updated
    note.text:SetText(spec and spec.updated and TEXT_UPDATED .. DataDate(spec.updated) or "")
    note:SetWidth(math.max(1, math.ceil(note.text:GetStringWidth())))
end

local function QuestsLabel(count)
    local label = questsLabels[count]
    if not label then
        label = count > 0 and TEXT_QUESTS_COUNT:format(count) or TEXT_QUESTS
        questsLabels[count] = label
    end
    return label
end

local function PaintPages(list)
    local count = Q.Available() and Q.Count(list) or 0
    PAGES[2].label = QuestsLabel(count)
    Parts.SetTabs(window.pages, PAGES)
    Parts.PaintTabs(window.pages, page)
end

local function DrawPage()
    if page ~= "quests" then
        view:DrawList()
    elseif questsView then
        questsView:Redraw()
    else
        view:DrawQuestsOff()
    end
end

local function ShowPage(key)
    page = key
    if key == "quests" and not questsView and Q.Available() then
        questsView = B.View.QuestsPage(scroll)
        questsView:SetWidth(view:GetWidth())
    end
    local shown = key == "quests" and questsView or view
    view.page = (key == "quests" and not questsView) and "questsOff" or "list"
    local hidden = shown == view and questsView or view
    if hidden then hidden:Hide() end
    shown:Show()
    view.summary:SetShown(shown == view)
    scroll:SetPoint("TOPLEFT", scrollLeft, -(scrollTop + (shown == view and B.View.SUMMARY_H or 0)))
    scroll:SetScrollChild(shown)
    scroll:SetVerticalScroll(0)
    Parts.PaintTabs(window.pages, page)
    DrawPage()
end

local function IsQuest(row, questID)
    local quest = row.quest
    if not quest then return false end
    if quest[1] == questID then return true end
    local alt = quest.alt
    if alt then
        for i = 1, #alt do
            if alt[i] == questID then return true end
        end
    end
    return false
end

local function PaintSide()
    local list, spec = view.list, L.CurrentSpec()
    Parts.PaintTabs(window.specs, spec and spec.key)
    window.list.text:SetText((list.name:gsub("||", "|")))
    doll:Paint(list)
    PaintUpdated(spec)
    PaintPages(list)
end

local function DollHover(slot)
    view:Light(slot)
    if slot and page == "list" then view:ScrollTo(slot) end
end

local function DollClicked(slot, button)
    B.OpenPicker(slot, button)
end

local function TitleBar()
    local close = Parts.TitleBar(window, TEXT_TITLE, TEXT_ABOUT, PAGE)
    local weights = Parts.BarButton(window, St.SCALES, TEXT_WEIGHTS, TEXT_WEIGHTS_TIP, A.StatWeights)
    weights:SetPoint("RIGHT", close, "LEFT", -WEIGHTS_GAP, 0)
    local export = Parts.BarButton(window, St.EXPORT, TEXT_EXPORT, TEXT_EXPORT_TIP, A.Export)
    export:SetPoint("RIGHT", weights, "LEFT", -BAR_GAP, 0)
    local import = Parts.BarButton(window, St.IMPORT, TEXT_IMPORT, TEXT_IMPORT_TIP, A.Import)
    import:SetPoint("RIGHT", export, "LEFT", -BAR_GAP, 0)
end

local function Side()
    local y = HEADER + PAD
    window.specs = Parts.Tabs(window, SIDE_INNER, SpecTabs(), ns.SetBisSpec)
    window.specs:SetPoint("TOPLEFT", PAD, -y)
    window.specs:SetShown(#R.ClassSpecs() > 0)
    y = y + TAB_H + TAB_GAP
    window.list = ListButton(window)
    window.list:SetPoint("TOPLEFT", PAD, -y)
    y = y + LIST_BUTTON_H + DOLL_GAP
    doll = B.View.Paperdoll(window, DollHover, DollClicked)
    doll:SetPoint("TOPLEFT", PAD + (SIDE_INNER - DOLL_W) / 2, -y)
end

local function Pages()
    local left = CONTENT_LEFT + CONTENT_INSET
    local top = HEADER + PAD + PAGES_TOP
    window.pages = Parts.Tabs(window, PAGES_W, PAGES, ShowPage)
    window.pages:SetPoint("TOPLEFT", left, -top)
    top = top + TAB_H + TAB_GAP + PAGES_GAP
    scrollLeft, scrollTop = left, top
    scroll = ns.UI.SlimScroll(window)
    scroll:SetPoint("TOPLEFT", left, -(top + B.View.SUMMARY_H))
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR - SCROLL_IN, FOOTER + PAD)
    view = B.View.New(scroll)
    view:SetWidth(WIDTH - left - SCROLLBAR - PAD - VIEW_IN)
    scroll:SetScrollChild(view)
    view.summary = B.View.Summary(window, view)
    view.summary:SetPoint("TOPLEFT", left, -top)
    view.summary:SetWidth(view:GetWidth())
    view.onDrawn = PaintSide
end

local function Build()
    window = Parts.Window(WIDTH, HEIGHT, "bisWindow")
    window.backdrop:Card(CARD_IN, HEADER + CARD_IN, WIDTH - SIDE_W - PAD - CARD_IN, FOOTER + CARD_IN)
    window.backdrop:Card(CONTENT_LEFT, HEADER + CARD_IN, CONTENT_RIGHT, FOOTER + CARD_IN)
    TitleBar()
    Parts.FooterBrand(window, PAGE)
    window.updated = Parts.FooterNote(window, "")
    Side()
    Pages()
end

local function Paint()
    window.backdrop:Paint(1)
end

local function OnSetting(key)
    if key == "bis" and window and not B.On() then window:Hide() end
end

local function Reapply()
    if window and window:IsShown() then
        Paint()
        DrawPage()
    end
end

local function Back(reason)
    if awayFor ~= reason then return end
    awayFor = nil
    if B.On() then ns.OpenBisWindow() end
end

local function BackFromMap() Back("map") end

function B.ShowQuest(questID)
    if not (window and window:IsShown()) then return false end
    ShowPage("quests")
    local row = questsView:Find("quest", IsQuest, questID)
    if not row then return false end
    questsView:ScrollToRow(scroll, row)
    return true
end

function B.BackFromJournal() Back("journal") end

function B.StepAside(reason)
    if not (window and window:IsShown()) then return end
    window.stepAside = true
    window:Hide()
    window.stepAside = nil
    awayFor = reason
    if reason == "map" and not mapWatched and WorldMapFrame then
        mapWatched = true
        WorldMapFrame:HookScript("OnHide", BackFromMap)
    end
end

function ns.OpenBisWindow()
    awayFor = nil
    if not B.On() then
        S.Set("bis", true)
        ns.Print(TEXT_TURNED_ON)
    end
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window:Show()
    Paint()
    DrawPage()
end

function ns.ToggleBisWindow()
    if window and window:IsShown() then window:Hide() else ns.OpenBisWindow() end
end

function NaowhForever_ToggleBis()
    ns.ToggleBisWindow()
end

S.OnChange(OnSetting)
hooksecurefunc(ns, "Apply", Reapply)

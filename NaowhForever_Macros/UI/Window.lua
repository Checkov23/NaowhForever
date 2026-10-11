-- Window.lua: Naowh's Forge, the Macros module's own window (/nfmacros): its tabs, title bar and footer.
local ns = _G.NaowhForever
local T = ns.THEME
local UI = ns.UI

local M = ns.Macros
local S = M.Settings
local St = M.Style
local Store = M.Store
local Sharing = M.Sharing
local P = M.Parts
local F = M.Forge
local Parts = ns.Shared.Parts

local NAME = "Naowh's Forge"
local PAGE = "Macros/Settings"
local WIDTH, HEIGHT = 1100, 720
local HEADER, FOOTER = St.WINDOW_HEADER, St.WINDOW_FOOTER
local PAD, SECTION_H, INSPECTOR_W = St.PAD, St.SECTION_H, St.INSPECTOR_W
local SMALL_SIZE, NOTE_SIZE, TEXT_SIZE = St.SMALL_SIZE, St.NOTE_SIZE, St.TEXT_SIZE
local CARD_INSET, GAP, TOOL_GAP = 6, 6, 10
local TOP = HEADER + TOOL_GAP + St.TAB_H + TOOL_GAP
local SWITCH_W, CLASS_W = 220, 200
local SCROLLBAR_ROOM, SCROLL_BOTTOM = St.SCROLLBAR_ROOM, 4
local METER_W, METER_H, METER_GAP, METER_SPACE, METER_LABEL_GAP = 54, 3, 12, 14, 6
local EXPORT_GAP = 6
local SMART_TOP, SIDE_TOP, SIDE_GAP, SIDE_SPACING = 10, 12, 10, 3
local CLASS_TOP = 4
local LIB_TITLE_SIZE, LIB_LEAD_GAP, LIB_TOP = 22, 6, 64
local SAVE_W, NEW_W, TOOL_BUTTON_GAP = 120, 100, 6
local PERCENT = 100
local ROUND = 0.5

local TEXT_NEW_MACRO = ns.L("New Macro")
local TEXT_NEW_TIP = ns.L("Write a macro: a name and its text, kept in the Library under your class.")
local TEXT_SAVE_MACRO = ns.L("Save a Macro")
local TEXT_SAVE_TIP = ns.L("Keeps a copy of one of your game macros in the Library under your class, for every character of that class.")
local TEXT_EXPORT_TIP = ns.L("Your game macros, not the Smart Macros, as one string to share.")
local TEXT_IMPORT_TIP = ns.L("Add macros someone shared with you.")
local TEXT_NOTHING_TO_EXPORT = ns.L("You have no macros to export yet.")
local TEXT_YOUR_MACROS = ns.L("Your macros")
local TEXT_SMART_NOTE = ns.L("They keep themselves up to date from your bags and gear")
local TEXT_SMART_HOW = ns.L("Each one is an account macro. Put it on a bar once and it keeps itself current: loot a "
    .. "better potion, conjure fresh food or pick up bandages and the macro is rewritten to use the best "
    .. "you carry.\n\nThe game does not let macros change mid-fight, so a change during combat waits "
    .. "until it ends.")
local TEXT_FOOTER = ns.L("Smart Macros are account macros, for every character. A Library macro you add is for this character only.")
local TEXT_ACCOUNT = ns.L("Account ")

local TABS = {
    { key = "smart", label = "Smart Macros", tip = "Macros that keep themselves up to date." },
    { key = "lib", label = "Library", tip = "Macros by class, for every character." },
}

local window

local function Count(n, max)
    local text = n .. "/" .. max
    return n >= max and ns.Color("accent", text) or text
end

local function PaintMeter(meter, n, max)
    meter.fill:SetWidth(math.max(1, METER_W * math.min(1, n / max)))
end

local function Subtitle()
    local accountCount, characterCount = GetNumMacros()
    local maxAccount, maxCharacter = Store.Limits()
    local _, class = UnitClass("player")
    local className = LOCALIZED_CLASS_NAMES_MALE[class] or class
    local classColor = RAID_CLASS_COLORS[class]
    window.subtitle:SetText(classColor:WrapTextInColorCode(UnitName("player") .. ", " .. className))
    local meters = window.meters
    PaintMeter(meters[1], accountCount, maxAccount)
    meters[1].label:SetText(TEXT_ACCOUNT .. Count(accountCount, maxAccount))
    PaintMeter(meters[2], characterCount, maxCharacter)
    meters[2].fill:SetColorTexture(classColor.r, classColor.g, classColor.b, 1)
    meters[2].label:SetText(className .. " " .. Count(characterCount, maxCharacter))
end

local function Render()
    if not (window and window:IsShown()) then return end
    Subtitle()
    if F.tab == "smart" then
        F.DrawSmart()
    else
        F.DrawLibrary()
    end
end

local function ShowCard(card, shown)
    for _, part in ipairs(card) do part:SetShown(shown) end
end

local function SetTab(key)
    F.tab = key
    Parts.PaintTabs(window.switch, key)
    window.smartView:SetShown(key == "smart")
    window.libView:SetShown(key == "lib")
    for name, cards in pairs(window.cards) do
        for _, card in ipairs(cards) do ShowCard(card, name == key) end
    end
    if window:IsShown() then Render() end
end

local function Area(left, right, parent)
    local f = CreateFrame("Frame", nil, window)
    f:SetPoint("TOPLEFT", left, -TOP)
    f:SetPoint("BOTTOMRIGHT", -right, FOOTER + CARD_INSET)
    f:SetParent(parent)
    return f
end

local function BodySized(scroll, w)
    scroll.body:SetWidth(w)
end

local function Scroller(parent, top)
    local scroll = UI.SlimScroll(parent)
    scroll:SetPoint("TOPLEFT", 0, -(top or 0))
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR_ROOM, SCROLL_BOTTOM)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(1, 1)
    scroll:SetScrollChild(body)
    scroll.body = body
    scroll:SetScript("OnSizeChanged", BodySized)
    return scroll, body
end

local function View()
    local view = CreateFrame("Frame", nil, window)
    view:SetAllPoints()
    return view
end

local function Section(parent, title, note)
    local h = P.NewSection(parent)
    h:SetPoint("TOPLEFT")
    h:SetPoint("TOPRIGHT")
    P.SetSection(h, title, nil, note)
    return h
end

local function OpacityGet() return math.floor((S.Get("windowAlpha") or 1) * PERCENT + ROUND) end
local function OpacitySet(value) S.Set("windowAlpha", value / PERCENT) end
ns.MacroOpacityGet, ns.MacroOpacitySet = OpacityGet, OpacitySet

local function ExportAll()
    local all, smart = {}, {}
    for _, m in ipairs(ns.MacroSmart.list) do smart[m.name] = true end
    for _, m in ipairs(Store.GameMacros()) do
        if not smart[m.name] then all[#all + 1] = m end
    end
    if #all == 0 then ns.Print(TEXT_NOTHING_TO_EXPORT) return end
    ns.ShowCopyBox(TEXT_YOUR_MACROS, Sharing.Export(all))
end

local function BuildMeters()
    window.meters = {}
    local after = window.subtitle
    for i = 1, 2 do
        local track = ns.Solid(window, "ARTWORK", T.line, 1)
        track:SetSize(METER_W, METER_H)
        track:SetPoint("LEFT", after, "RIGHT", i == 1 and METER_GAP or METER_SPACE, 0)
        local fill = ns.Solid(window, "OVERLAY", T.accent, 1)
        fill:SetPoint("TOPLEFT", track)
        fill:SetHeight(METER_H)
        local label = P.Text(window, SMALL_SIZE, T.muted)
        label:SetPoint("LEFT", track, "RIGHT", METER_LABEL_GAP, 0)
        window.meters[i] = { fill = fill, label = label }
        after = label
    end
end

local function BuildBar(opacityIcon)
    local exportButton = Parts.BarButton(window, St.EXPORT, "Export", TEXT_EXPORT_TIP, ExportAll, "Export")
    exportButton:SetPoint("RIGHT", opacityIcon, "LEFT", -St.BAR_GAP - EXPORT_GAP, 0)
    local importButton = Parts.BarButton(window, St.IMPORT, "Import", TEXT_IMPORT_TIP, Sharing.Prompt, "Import")
    importButton:SetPoint("RIGHT", exportButton, "LEFT", -St.BAR_GAP, 0)
end

local function BuildTabs()
    window.switch = Parts.Tabs(window, SWITCH_W, TABS, SetTab)
    window.switch:SetPoint("TOPLEFT", CARD_INSET, -(HEADER + TOOL_GAP))
end

local function BuildCards()
    local backdrop, bottom = window.backdrop, FOOTER + CARD_INSET
    local inspectorLeft = WIDTH - CARD_INSET - INSPECTOR_W
    window.cards = {
        smart = { backdrop:Card(CARD_INSET, TOP, CARD_INSET + INSPECTOR_W + GAP, bottom),
            backdrop:Card(inspectorLeft, TOP, CARD_INSET, bottom) },
        lib = { backdrop:Card(CARD_INSET, TOP, WIDTH - CARD_INSET - CLASS_W, bottom),
            backdrop:Card(CARD_INSET + CLASS_W + GAP, TOP, CARD_INSET, bottom) },
    }
end

local function BuildSmartSide(sideArea)
    Section(sideArea, ns.L("How They Work"))
    window.smartSummary = P.Text(sideArea, TEXT_SIZE)
    window.smartSummary:SetPoint("TOPLEFT", PAD, -(SECTION_H + SIDE_TOP))
    window.smartSummary:SetPoint("RIGHT", -PAD, 0)
    window.smartSummary:SetJustifyH("LEFT")
    local sideNote = P.Text(sideArea, NOTE_SIZE, T.muted)
    sideNote:SetPoint("TOPLEFT", window.smartSummary, "BOTTOMLEFT", 0, -SIDE_GAP)
    sideNote:SetPoint("RIGHT", -PAD, 0)
    sideNote:SetJustifyH("LEFT")
    sideNote:SetSpacing(SIDE_SPACING)
    sideNote:SetText(TEXT_SMART_HOW)
end

local function BuildSmart()
    window.smartView = View()
    local smartArea = Area(CARD_INSET, CARD_INSET + INSPECTOR_W + GAP, window.smartView)
    Section(smartArea, "Smart Macros", TEXT_SMART_NOTE)
    local smart = {}
    smart.scroll, smart.body = Scroller(smartArea, SECTION_H + SMART_TOP)
    smart.scroll:SetPoint("TOPLEFT", PAD, -(SECTION_H + SMART_TOP))
    smart.cards = P.Pool(function() return F.NewSmartCard(smart.body) end)
    window.smart = smart
    BuildSmartSide(Area(WIDTH - CARD_INSET - INSPECTOR_W, CARD_INSET, window.smartView))
end

local function BuildLibrary()
    window.libView = View()
    local classArea = Area(CARD_INSET, WIDTH - CARD_INSET - CLASS_W, window.libView)
    local lib = {}
    Section(classArea, "Classes")
    lib.classScroll, lib.classBody = Scroller(classArea, SECTION_H + CLASS_TOP)
    lib.classes = P.Pool(function() return F.NewClassRow(lib.classBody) end)
    local libArea = Area(CARD_INSET + CLASS_W + GAP, CARD_INSET, window.libView)
    lib.title = ns.Font(libArea, LIB_TITLE_SIZE)
    lib.title:SetPoint("TOPLEFT", PAD, -PAD)
    lib.lead = P.Text(libArea, NOTE_SIZE, T.muted)
    lib.lead:SetPoint("TOPLEFT", lib.title, "BOTTOMLEFT", 0, -LIB_LEAD_GAP)
    lib.save = ns.Button(libArea, TEXT_SAVE_MACRO, SAVE_W, St.BUTTON_H, function() F.SavePicker(lib.save) end)
    lib.save:SetPoint("TOPRIGHT", libArea, "TOPRIGHT", -PAD, -PAD)
    ns.Tooltip(lib.save, TEXT_SAVE_MACRO, TEXT_SAVE_TIP)
    lib.new = ns.Button(libArea, TEXT_NEW_MACRO, NEW_W, St.BUTTON_H, function() F.NewMacro() end)
    lib.new:SetPoint("RIGHT", lib.save, "LEFT", -TOOL_BUTTON_GAP, 0)
    ns.Tooltip(lib.new, TEXT_NEW_MACRO, TEXT_NEW_TIP)
    lib.scroll, lib.body = Scroller(libArea, LIB_TOP)
    lib.scroll:SetPoint("TOPLEFT", PAD, -LIB_TOP)
    lib.cards = P.Pool(function() return F.NewLibCard(lib.body) end)
    window.lib = lib
end

local function OnShow(self)
    self:RegisterEvent("UPDATE_MACROS")
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self.backdrop:Paint(S.Get("windowAlpha") or 1)
    Render()
end

local function OnHide(self)
    self:UnregisterAllEvents()
end

local function Build()
    window = Parts.Window(WIDTH, HEIGHT, "macroWindow")
    F.window = window
    local close = Parts.TitleBar(window, NAME, "", PAGE)
    local opacityIcon, slider = Parts.Opacity(window, close, OpacityGet, OpacitySet)
    window.opacity = slider
    BuildMeters()
    BuildBar(opacityIcon)
    BuildTabs()
    BuildCards()
    BuildSmart()
    BuildLibrary()
    Parts.FooterBrand(window, PAGE, CARD_INSET)
    Parts.FooterNote(window, TEXT_FOOTER)
    window:HookScript("OnShow", OnShow)
    window:HookScript("OnHide", OnHide)
    window:SetScript("OnEvent", Render)
    SetTab(F.tab)
    window:Hide()
end

local function SettingChanged(key)
    if not window then return end
    if key == "windowAlpha" then
        window.backdrop:Paint(S.Get("windowAlpha") or 1)
        window.opacity._refreshValue()
    elseif window:IsShown() then
        Render()
    end
end

F.Render = Render
F.SetTab = SetTab
M.Redraw = Render

function ns.OpenMacroWindow(view)
    if not window then Build() end
    if view then SetTab(view) end
    window:SetScale(ns.UIScale())
    if window:IsShown() then Render() else window:Show() end
end

function ns.ToggleMacroWindow()
    if window and window:IsShown() then window:Hide() else ns.OpenMacroWindow() end
end

hooksecurefunc(ns, "Apply", function() Render() end)
hooksecurefunc(S, "Set", SettingChanged)

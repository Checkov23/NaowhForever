-- Window.lua: Group Inspect's window (/nfgroup): your party as cards, your raid as rows, or a note.
local ns = _G.NaowhForever

local T = ns.THEME
local S = ns.QoLSettings
local GI = ns.GroupInspect
local UI = GI.UI
local St = UI.Style
local Parts = ns.Shared.Parts

local HEADER, PAD, FOOTER, INSET = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER, St.CONTENT_INSET
local SCROLLBAR, TAB_H, BAR_GAP, SCROLL_GAP = St.SCROLLBAR, St.TAB_H, St.BAR_GAP, St.SCROLL_GAP
local CARD = 6
local REFRESH_GAP = BAR_GAP * 2
local SUMMARY_SHRINK = 2
local PERCENT, ROUND = GI.C.PERCENT, GI.C.ROUND
local WINDOW_KEY = "groupInspectWindow"

local MODE_WORDS = UI.MODE_WORDS
local NF_COUNT = ns.L("%d of %d run Naowh Forever")
local TEXT_TITLE = ns.L("Group Inspect")
local TEXT_TITLE_TIP = ns.L("Your group's Naowh Score, gear, talents and stats.")
local TEXT_REFRESH = ns.L("Inspect everyone again")
local TEXT_REFRESH_TIP = ns.L("Reads every member's gear and talents again.")
local TEXT_REFRESH_LABEL = ns.L("Refresh")
local TURNED_ON = ns.L("Group Inspect turned on. Turn it off on its settings page.")

local window, board, list, raidBar
local listening = false

local function Opacity()
    return math.floor((S.Get("groupInspectAlpha") or 1) * PERCENT + ROUND)
end

local function SetOpacity(value)
    S.Set("groupInspectAlpha", value / PERCENT)
end

local function PaintBackdrop()
    window.backdrop:Paint(Opacity() / PERCENT)
    window.opacity._refreshValue()
end

local function PaintTop()
    local t = UI.Tally()
    local mode = window.mode
    local words = MODE_WORDS[mode]
    window.summary:SetText(words and words:format(t.total) or "")
    window.progress:SetText(words and UI.ProgressText(t) or "")
    local note = window.note
    note.text:SetText(words and NF_COUNT:format(t.nf, t.total) or "")
    note:SetWidth(math.max(1, math.ceil(note.text:GetStringWidth())))
end

local function ShowMode(mode)
    window.mode = mode
    board:SetShown(mode == "party")
    list.header:SetShown(mode == "raid")
    window.scroll:SetShown(mode == "raid")
    raidBar:SetShown(mode == "raid")
    window.solo:SetShown(mode ~= "party" and mode ~= "raid")
end

local function PaintAll()
    local mode = GI.Mode()
    ShowMode(mode)
    if mode == "party" then
        board:Paint()
    elseif mode == "raid" then
        list:Draw()
    end
    PaintTop()
end

function UI.PaintWindow()
    if window and window:IsShown() then PaintAll() end
end

local function WindowChanged(guid)
    if guid == nil or window.mode ~= GI.Mode() then
        PaintAll()
        return
    end
    if window.mode == "party" then
        if not board:PaintGuid(guid) then board:Paint() end
    elseif window.mode == "raid" then
        list:PaintGuid(guid)
    end
    PaintTop()
end

local function Changed(guid)
    if window and window:IsShown() then WindowChanged(guid) end
    local preview = UI.preview
    if preview and preview:IsVisible() then preview:Repaint(guid) end
end

function UI.Listen()
    if listening then return end
    listening = true
    GI.OnChange(Changed)
end

local function Shown()
    GI.Open()
end

local function Hidden()
    GI.Close()
end

local function RefreshAll()
    GI.RefreshAll()
end

local function Build()
    local W, H = St.WINDOW_W, St.WINDOW_H
    window = Parts.Window(W, H, WINDOW_KEY)
    window.backdrop:Card(CARD, HEADER + CARD, CARD, FOOTER + CARD)
    local close = Parts.TitleBar(window, TEXT_TITLE, TEXT_TITLE_TIP, UI.PAGE)
    local opacityIcon
    opacityIcon, window.opacity = Parts.Opacity(window, close, Opacity, SetOpacity)
    local refresh = Parts.BarButton(window, St.RESET, TEXT_REFRESH, TEXT_REFRESH_TIP, RefreshAll, TEXT_REFRESH_LABEL)
    refresh:SetPoint("RIGHT", opacityIcon, "LEFT", -REFRESH_GAP, 0)
    Parts.FooterBrand(window, UI.PAGE)
    window.note = Parts.FooterNote(window, "")

    window.summary = ns.Font(window, St.CARD_NAME_SIZE - SUMMARY_SHRINK, nil, T.fg)
    window.summary:SetPoint("LEFT", window, "TOPLEFT", INSET, -(UI.TOOLBAR_TOP + TAB_H / 2))
    window.progress = ns.Font(window, St.LINE_SIZE, nil, T.muted)
    window.progress:SetPoint("LEFT", window.summary, "RIGHT", PAD, 0)
    raidBar = UI.RaidBar(window)
    raidBar:SetPoint("TOPRIGHT", -INSET, -UI.TOOLBAR_TOP)

    board = UI.PartyBoard(window)
    board:SetPoint("TOPLEFT", INSET, -UI.CONTENT_TOP)

    local scroll = ns.UI.SlimScroll(window)
    scroll:SetPoint("TOPLEFT", INSET, -(UI.CONTENT_TOP + St.COLUMNS_H))
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR - SCROLL_GAP, FOOTER + PAD)
    window.scroll = scroll
    list = UI.RaidList(window, scroll)
    list.header:SetPoint("TOPLEFT", INSET, -UI.CONTENT_TOP)
    scroll:SetScrollChild(list.view)

    window.solo = UI.SoloNote(window)
    window.board, window.list = board, list
    window:HookScript("OnShow", Shown)
    window:HookScript("OnHide", Hidden)
    UI.Listen()
end

function ns.OpenGroupInspect()
    if not GI.On() then
        S.Set("groupInspect", true)
        ns.Print(TURNED_ON)
    end
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window:Show()
    PaintBackdrop()
    PaintAll()
end

function ns.ToggleGroupInspect()
    if window and window:IsShown() then window:Hide() else ns.OpenGroupInspect() end
end

function NaowhForever_ToggleGroupInspect()
    ns.ToggleGroupInspect()
end

function UI.Window()
    return window
end

local function OnSettingChanged(key)
    if key == "naowhScoreCompare" then UI.ForgetScores() end
    if not window then return end
    if key == "groupInspect" and not GI.On() then
        window:Hide()
    elseif key == "groupInspectAlpha" then
        if window:IsShown() then PaintBackdrop() end
    elseif key == "groupInspectView" or key == "groupInspectSort" or key == "naowhScoreCompare" then
        if window:IsShown() then PaintAll() end
    end
end

local function OnApply()
    if window and window:IsShown() then
        PaintBackdrop()
        PaintAll()
    end
end

S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", OnApply)

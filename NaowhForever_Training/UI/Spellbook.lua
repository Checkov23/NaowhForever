-- Spellbook.lua: the Trainable tab under the spellbook, and its panel of what you can train now and soon.
local ns = _G.NaowhForever

local T = ns.THEME

local Training = ns.Training
local S = Training.Settings
local Style = Training.Style
local Rows = Training.Rows

local LEVEL = Training.C.ENTRY_LEVEL
local BOOK_ADDON = "Blizzard_PlayerSpells"
local TAB_W, TAB_H = 150, 26
local TAB_X, TAB_Y = 22, 2
local PANEL_W, PANEL_PAD, PANEL_GAP = 360, 10, 8
local HEADER_H, LOGO, TITLE_GAP = 40, 20, 8
local CLOSE = 20
local LIST_GAP, LIST_END = 4, 8
local MAX_ROWS = 14
local MORE_H = 20
local EMPTY_H = 44
local FOOTER_H = 72
local TRAINER_DROP = 10
local BUTTON_H, BUTTON_GAP = 26, 8
local FONT, FONT_ROW, FONT_TITLE = Style.FONT, Style.FONT_ROW, 15
local TEXT_TAB = ns.L("Trainable")
local TEXT_TAB_COUNT = ns.L("Trainable (%d)")
local TEXT_TAB_TIP = ns.L("The spells you can train now and in the next few levels.")
local TEXT_CLOSE = "x"
local TEXT_NOW = ns.L("TRAIN NOW")
local TEXT_LEVEL = ns.L("LEVEL ")
local TEXT_NOTHING = ns.L("Nothing to train in the next few levels.")
local TEXT_MORE = ns.L("and %d more in the planner")
local TEXT_TRAINER = ns.L("Nearest trainer: %s")
local TEXT_WAYPOINT = ns.L("Waypoint")
local TEXT_OPEN = ns.L("Open Planner")

local tab, panel
local rows, headers = {}, {}
local rowCount, headerCount = 0, 0
local queued, hookAsked = false, false

local function On()
    return Training.On() and S.Get("spellbook")
end

local function HideAll()
    if not tab then return end
    tab:Hide()
    panel:Hide()
end

local function Toggle()
    S.Set("spellbookOpen", not S.Get("spellbookOpen"))
end

local function Close()
    S.Set("spellbookOpen", false)
end

local function OpenPlanner()
    ns.OpenTrainingWindow()
end

local function BuildPanel(book)
    panel = CreateFrame("Frame", nil, UIParent)
    panel:SetWidth(PANEL_W)
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:SetPoint("TOPLEFT", book, "TOPRIGHT", PANEL_GAP, 0)
    ns.Solid(panel, "BACKGROUND", T.bg, Style.BACKDROP_ALPHA):SetAllPoints()
    ns.Border(panel, Style.BORDER_RGB)
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(Style.LOGO_FILE, nil, nil, "TRILINEAR")
    logo:SetSize(LOGO, LOGO)
    logo:SetPoint("LEFT", panel, "TOPLEFT", PANEL_PAD, -HEADER_H / 2)
    local title = ns.Font(panel, FONT_TITLE, nil)
    title:SetPoint("LEFT", logo, "RIGHT", TITLE_GAP, 0)
    title:SetText(TEXT_TAB)
    local close = ns.Button(panel, TEXT_CLOSE, CLOSE, CLOSE, Close)
    close:SetPoint("RIGHT", panel, "TOPRIGHT", -PANEL_PAD, -HEADER_H / 2)
    local rule = ns.Solid(panel, "ARTWORK", T.line, 1)
    rule:SetPoint("TOPLEFT", 0, -HEADER_H)
    rule:SetPoint("TOPRIGHT", 0, -HEADER_H)
    ns.Hairline(rule, "h")
    panel.body = CreateFrame("Frame", nil, panel)
    panel.body:SetPoint("TOPLEFT", PANEL_PAD, -(HEADER_H + LIST_GAP))
    panel.body:SetPoint("TOPRIGHT", -PANEL_PAD, -(HEADER_H + LIST_GAP))
    panel.body:SetHeight(1)
    panel.note = ns.Font(panel, FONT, nil, T.muted)
    panel.note:SetJustifyH("LEFT")
end

local function BuildFooter()
    local footer = CreateFrame("Frame", nil, panel)
    footer:SetPoint("BOTTOMLEFT")
    footer:SetPoint("BOTTOMRIGHT")
    footer:SetHeight(FOOTER_H)
    local rule = ns.Solid(footer, "ARTWORK", T.line, 1)
    rule:SetPoint("TOPLEFT")
    rule:SetPoint("TOPRIGHT")
    ns.Hairline(rule, "h")
    panel.trainer = ns.Font(footer, FONT_ROW, nil)
    panel.trainer:SetPoint("TOPLEFT", PANEL_PAD, -TRAINER_DROP)
    panel.trainer:SetPoint("RIGHT", -PANEL_PAD, 0)
    panel.trainer:SetJustifyH("LEFT")
    panel.trainer:SetWordWrap(false)
    local half = (PANEL_W - 2 * PANEL_PAD - BUTTON_GAP) / 2
    panel.waypoint = ns.Button(footer, TEXT_WAYPOINT, half, BUTTON_H, Training.WaypointToTrainer)
    panel.waypoint:SetPoint("BOTTOMLEFT", PANEL_PAD, PANEL_PAD)
    panel.open = ns.AccentBorder(ns.Button(footer, TEXT_OPEN, half, BUTTON_H, OpenPlanner))
    panel.open:SetPoint("BOTTOMRIGHT", -PANEL_PAD, PANEL_PAD)
end

local function Build(book)
    tab = ns.Button(UIParent, TEXT_TAB, TAB_W, TAB_H, Toggle)
    tab:SetFrameStrata("DIALOG")
    tab:SetPoint("TOPLEFT", book, "BOTTOMLEFT", TAB_X, TAB_Y)
    ns.Tooltip(tab, TEXT_TAB, TEXT_TAB_TIP)
    BuildPanel(book)
    BuildFooter()
end

local function AddHeader(y, title, entries)
    headerCount = headerCount + 1
    local h = headers[headerCount]
    if not h then
        h = Rows.NewHeader(panel.body)
        headers[headerCount] = h
    end
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", panel.body, "TOPLEFT", 0, y)
    h:SetPoint("TOPRIGHT", panel.body, "TOPRIGHT", 0, y)
    Rows.FillHeader(h, title, #entries, Training.Coins(Training.Total(entries)))
    h:Show()
    return y - Style.SECTION_H - Style.SECTION_SPACE
end

local function AddRow(y, entry, state)
    rowCount = rowCount + 1
    local r = rows[rowCount]
    if not r then
        r = Rows.NewRow(panel.body)
        rows[rowCount] = r
    end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", panel.body, "TOPLEFT", 0, y)
    r:SetPoint("TOPRIGHT", panel.body, "TOPRIGHT", 0, y)
    Rows.FillRow(r, entry, state)
    r.icon:SetDesaturated(state ~= "now")
    r.stripe:SetShown(rowCount % 2 == 0)
    r:Show()
    return y - Style.ROW_H
end

local function Section(y, title, state, entries)
    if #entries == 0 or rowCount >= MAX_ROWS then return y end
    y = AddHeader(y, title, entries)
    for _, entry in ipairs(entries) do
        if rowCount >= MAX_ROWS then break end
        y = AddRow(y, entry, state)
    end
    return y - Style.SECTION_GAP
end

local function SoonByLevel(plan)
    local groups = {}
    for _, entry in ipairs(plan.soon) do
        local group = groups[#groups]
        if not group or group[1][LEVEL] ~= entry[LEVEL] then
            group = {}
            groups[#groups + 1] = group
        end
        group[#group + 1] = entry
    end
    return groups
end

local function Fill(plan)
    rowCount, headerCount = 0, 0
    local y = Section(0, TEXT_NOW, "now", plan.now)
    for _, group in ipairs(SoonByLevel(plan)) do
        y = Section(y, TEXT_LEVEL .. group[1][LEVEL], "soon", group)
    end
    for i = rowCount + 1, #rows do rows[i]:Hide() end
    for i = headerCount + 1, #headers do headers[i]:Hide() end
    local left = #plan.now + #plan.soon - rowCount
    local listH = rowCount > 0 and (LIST_END - y) or EMPTY_H
    panel.note:ClearAllPoints()
    panel.note:SetPoint("TOPLEFT", panel.body, "TOPLEFT", 0, rowCount > 0 and y or 0)
    panel.note:SetText(rowCount == 0 and TEXT_NOTHING or left > 0 and TEXT_MORE:format(left) or "")
    local noteH = (rowCount > 0 and left > 0) and MORE_H or 0
    panel.trainer:SetText(TEXT_TRAINER:format(Training.TrainerPlace()))
    panel:SetHeight(HEADER_H + LIST_GAP + listH + noteH + FOOTER_H)
end

local function Render()
    queued = false
    local book = PlayerSpellsFrame
    if not (On() and book and book.SpellBookFrame:IsVisible()) then return HideAll() end
    if not tab then Build(book) end
    local plan = Training.Plan()
    ns.SetButtonText(tab, #plan.now > 0 and TEXT_TAB_COUNT:format(#plan.now) or TEXT_TAB)
    tab:Show()
    if not S.Get("spellbookOpen") then return panel:Hide() end
    Fill(plan)
    panel:Show()
end

local function Queue()
    if queued then return end
    queued = true
    C_Timer.After(0, Render)
end

local function OnBookShow()
    if On() then Queue() end
end

local function OnPlanChanged()
    if tab and tab:IsShown() then Queue() end
end

local function HookBook()
    local book = PlayerSpellsFrame.SpellBookFrame
    book:HookScript("OnShow", OnBookShow)
    book:HookScript("OnHide", HideAll)
    OnBookShow()
end

local function Apply()
    if not On() then return HideAll() end
    if hookAsked then return Queue() end
    hookAsked = true
    EventUtil.ContinueOnAddOnLoaded(BOOK_ADDON, HookBook)
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "spellbook" or key == "spellbookOpen" then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

Training.OnChange(OnPlanChanged)
S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)

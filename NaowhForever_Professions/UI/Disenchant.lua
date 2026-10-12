-- Disenchant.lua: the Disenchant window: every item in your bags Disenchant can take, right-click to keep one, Disenchant All for the rest.
local ns = _G.NaowhForever

local T = ns.THEME
local Shared = ns.Shared
local Parts, St = Shared.Parts, Shared.Style

local P = ns.Professions
local S = P.Settings
local D = P.Disenchant
local R = P.Recipes

local PAGE = "Professions/Settings"
local COLUMNS, ICON, GAP = 8, 36, 4
local GRID_W = COLUMNS * ICON + (COLUMNS - 1) * GAP
local HEADER, PAD, FOOTER, SCROLLBAR = St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER, St.SCROLLBAR
local INSET = St.CONTENT_INSET
local SCROLL_GAP = 4
local WIDTH, HEIGHT = INSET * 2 + GRID_W + SCROLLBAR + SCROLL_GAP, 440
local CARD_INSET = 6
local BOTTOM_H = 34
local ALL_W, ALL_H = 150, 24
local SUMMARY_SIZE = 12
local MARK_SIZE, MARK_IN, MARK_LEVEL = 10, 2, 5
local KEPT_ALPHA = 0.35
local HIGHLIGHT_ALPHA = 0.15
local OPEN_W, OPEN_H, OPEN_RIGHT, OPEN_DROP = 90, 22, 36, 7
local EVENTS = { "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }

local TEXT_TITLE = ns.L("Disenchant")
local TEXT_SUBTITLE = ns.L("Right-click keeps one, Shift keeps every copy.")
local TEXT_ALL, TEXT_ALL_COUNT = ns.L("Disenchant All"), ns.L("Disenchant All (%d)")
local TEXT_OPEN = ns.L("Disenchant")
local TEXT_SUMMARY = ns.L("%d to disenchant, %d kept")
local TEXT_EMPTY = ns.L("Nothing in your bags to disenchant.")
local TEXT_KEEP_MARK = ns.L("Keep")
local TEXT_NEXT_TIP = ns.L("Disenchants %s.")
local TEXT_ONE_CLICK = ns.L("One item per click: the game needs a click for every disenchant.")
local TEXT_NOTHING_LEFT = ns.L("Nothing left to disenchant.")
local TEXT_KEEP_HINT = ns.L("Right-click: keep this one")
local TEXT_KEEP_ALL_HINT = ns.L("Shift-right-click: keep every copy")
local TEXT_KEPT_COPY = ns.L("Kept: this one only. Right-click: disenchant it again")
local TEXT_KEPT_ALL = ns.L("Kept: every copy. Right-click: disenchant them again")
local TEXT_REFUSED = ns.L("The game would not disenchant this (skill too low?). Skipped until you reload.")
local TEXT_REFUSED_CHAT = ns.L("%s could not be disenchanted, skipped until you reload.")
local TEXT_COMBAT = ns.L("The Disenchant window cannot open in combat.")
local TEXT_UNKNOWN = ns.L("You do not know Disenchant.")
local TEXT_OFF = ns.L("Turn on the Disenchant Window in the Professions settings first.")

local window, scroll, grid, summary, all, empty, events
local slots = {}
local armed

local function On()
    return S.Get("enabled") and S.Get("disenchant")
end

local function PaintSlot(b, r)
    b.record = r
    b.icon.texture:SetTexture(r.icon)
    local kept, refused = D.Kept(r), D.Failed(r.itemID)
    b.icon.texture:SetDesaturated(kept or refused or r.locked)
    b.icon:SetAlpha((kept or refused) and KEPT_ALPHA or 1)
    b.mark:SetShown(kept)
    local edge = r == armed and T.accent or ITEM_QUALITY_COLORS[r.quality] or T.line
    b.icon.edge:SetColor(edge.r, edge.g, edge.b, 1)
    Parts.MarkForever(b.icon, r.itemID)
    b:Show()
end

local function OnSlotEnter(self)
    local r = self.record
    if not r then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetBagItem(r.bag, r.slot)
    if D.Failed(r.itemID) then
        local red = St.RED_RGB
        GameTooltip:AddLine(TEXT_REFUSED, red.r, red.g, red.b, true)
    elseif D.KeptAll(r) then
        GameTooltip:AddLine(TEXT_KEPT_ALL, T.accent.r, T.accent.g, T.accent.b, true)
    elseif D.KeptCopy(r) then
        GameTooltip:AddLine(TEXT_KEPT_COPY, T.accent.r, T.accent.g, T.accent.b, true)
    else
        if r.guid then GameTooltip:AddLine(TEXT_KEEP_HINT, T.accent.r, T.accent.g, T.accent.b) end
        GameTooltip:AddLine(TEXT_KEEP_ALL_HINT, T.accent.r, T.accent.g, T.accent.b)
    end
    GameTooltip:Show()
end

local Redraw

local function OnSlotClick(self, button)
    local r = self.record
    if not r then return end
    if button == "RightButton" then
        D.ToggleKeep(r, IsShiftKeyDown())
        Redraw()
        if GameTooltip:IsOwned(self) then OnSlotEnter(self) end
    elseif r.link then
        HandleModifiedItemClick(r.link)
    end
end

local function NewSlot(i)
    local b = CreateFrame("Button", nil, grid)
    b:SetSize(ICON, ICON)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.icon = Parts.ItemIcon(b, ICON)
    b.icon:SetPoint("CENTER")
    local over = CreateFrame("Frame", nil, b)
    over:SetAllPoints()
    over:SetFrameLevel(b.icon:GetFrameLevel() + MARK_LEVEL)
    b.mark = ns.Font(over, MARK_SIZE, "OUTLINE", St.RED_RGB)
    b.mark:SetPoint("BOTTOM", 0, MARK_IN)
    b.mark:SetText(TEXT_KEEP_MARK)
    local light = b:CreateTexture(nil, "HIGHLIGHT")
    light:SetAllPoints()
    light:SetColorTexture(1, 1, 1, HIGHLIGHT_ALPHA)
    local column, row = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
    b:SetPoint("TOPLEFT", column * (ICON + GAP), -row * (ICON + GAP))
    b:SetScript("OnEnter", OnSlotEnter)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", OnSlotClick)
    slots[i] = b
    return b
end

local function Arm()
    if InCombatLockdown() then return end
    armed = D.Next()
    all:SetAttribute("target-bag", armed and armed.bag or nil)
    all:SetAttribute("target-slot", armed and armed.slot or nil)
    all:SetAttribute("type", armed and "spell" or nil)
    all:SetAlpha(armed and 1 or KEPT_ALPHA)
end

function Redraw()
    if not (window and window:IsShown()) then return end
    local list, n = D.Collect()
    Arm()
    for i = 1, n do PaintSlot(slots[i] or NewSlot(i), list[i]) end
    for i = n + 1, #slots do
        slots[i].record = nil
        slots[i]:Hide()
    end
    local rows = math.ceil(n / COLUMNS)
    grid:SetHeight(math.max(rows * (ICON + GAP) - GAP, 1))
    empty:SetShown(n == 0)
    local ready, kept = D.Counts()
    summary:SetText(TEXT_SUMMARY:format(ready, kept))
    ns.SetButtonText(all, ready > 0 and TEXT_ALL_COUNT:format(ready) or TEXT_ALL)
end

local function OnAllEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(armed and TEXT_NEXT_TIP:format(armed.link or TEXT_ALL) or TEXT_NOTHING_LEFT, 1, 1, 1)
    GameTooltip:AddLine(TEXT_ONE_CLICK, T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function OnAllPostClick(self, _, down)
    if down or not SpellIsTargeting() then return end
    SpellStopTargeting()
    if armed then
        D.MarkFailed(armed.itemID)
        ns.Print(TEXT_REFUSED_CHAT:format(armed.link or TEXT_ALL))
    end
    Redraw()
    if GameTooltip:IsOwned(self) then OnAllEnter(self) end
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        window:Hide()
        return
    end
    Redraw()
end

local function BuildAll()
    all = ns.Button(window, TEXT_ALL, ALL_W, ALL_H, nil, "SecureActionButtonTemplate")
    all:SetPoint("BOTTOMRIGHT", -INSET, FOOTER + PAD)
    all:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    all:SetAttribute("useOnKeyDown", false)
    all:SetAttribute("spell", D.SPELL)
    all:HookScript("OnEnter", OnAllEnter)
    all:HookScript("OnLeave", GameTooltip_Hide)
    all:SetScript("PostClick", OnAllPostClick)
end

local function BuildFooter()
    BuildAll()
    summary = ns.Font(window, SUMMARY_SIZE, nil, T.muted)
    summary:SetPoint("LEFT", window, "BOTTOMLEFT", INSET, FOOTER + PAD + ALL_H / 2)
    summary:SetPoint("RIGHT", all, "LEFT", -PAD, 0)
    summary:SetJustifyH("LEFT")
end

local function BuildGrid()
    local top = HEADER + PAD
    scroll = ns.UI.SlimScroll(window)
    scroll:SetPoint("TOPLEFT", INSET, -top)
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR - SCROLL_GAP, FOOTER + PAD + BOTTOM_H)
    grid = CreateFrame("Frame", nil, scroll)
    grid:SetSize(GRID_W, 1)
    scroll:SetScrollChild(grid)
    empty = ns.Font(window, SUMMARY_SIZE, nil, T.muted)
    empty:SetPoint("CENTER", scroll, "CENTER")
    empty:SetText(TEXT_EMPTY)
end

local function OnShow()
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    Redraw()
end

local function OnHide()
    events:UnregisterAllEvents()
end

local function Build()
    window = Parts.Window(WIDTH, HEIGHT, "disenchantWindow")
    window.backdrop:Card(CARD_INSET, HEADER + CARD_INSET, CARD_INSET, FOOTER + CARD_INSET)
    Parts.TitleBar(window, TEXT_TITLE, TEXT_SUBTITLE, PAGE)
    Parts.FooterBrand(window, PAGE)
    BuildGrid()
    BuildFooter()
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
    window:HookScript("OnShow", OnShow)
    window:HookScript("OnHide", OnHide)
end

function ns.OpenDisenchant()
    if not On() then return ns.Print(TEXT_OFF) end
    if not D.Known() then return ns.Print(TEXT_UNKNOWN) end
    if InCombatLockdown() then return ns.Print(TEXT_COMBAT) end
    if not window then Build() end
    window:SetScale(ns.UIScale())
    window:Show()
    window.backdrop:Paint(1)
end

function ns.ToggleDisenchant()
    if window and window:IsShown() then
        if not InCombatLockdown() then window:Hide() end
    else
        ns.OpenDisenchant()
    end
end

local opener

local function PlaceOpener()
    local win = P.State.frame
    if not win then return end
    if not opener then
        opener = ns.Button(win, TEXT_OPEN, OPEN_W, OPEN_H, ns.ToggleDisenchant)
        opener:SetPoint("TOPRIGHT", -OPEN_RIGHT, -OPEN_DROP)
    end
    local prof = R.Profession()
    opener:SetShown(On() and R.Own() and prof ~= nil and prof.id == D.ENCHANTING and D.Known())
end

hooksecurefunc(P.Window, "Render", PlaceOpener)

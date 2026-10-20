-- Takeover.lua: Naowh's window over Blizzard's profession window: when it shows, what of Blizzard's it docks, and the events.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local W = P.State
local R = P.Recipes
local Links = P.Links
local Style = P.Style

local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG" }
local FALLBACK_STRATA = "HIGH"
local TABS_DROP = -60
local UNLEARN_GAP = 6
local UNLEARN_ATLAS = "Profession-button-red-crossmark"
local UNLEARN_FALLBACK = "Interface/RAIDFRAME/ReadyCheck-NotReady"
local UNLEARN_SIZE = 20
local CARD_LEVEL, UNLEARN_LEVEL = 3, 10
local RANK_INSET = 2
local BURST = 0.1
local CARD_ART = { "Background", "ProfessionName", "specialization", "missingHeader", "missingText", "StatusBar" }
local QUIET = { ITEM_DATA_LOAD_RESULT = true, BAG_UPDATE_DELAYED = true, PLAYERBANKSLOTS_CHANGED = true,
    AUCTION_HOUSE_SHOW = true, AUCTION_HOUSE_CLOSED = true, TRACKED_RECIPE_UPDATE = true,
    GROUP_ROSTER_UPDATE = true }
local REREAD = { APPLY = true, ADDON_LOADED = true, TRADE_SKILL_SHOW = true, TRADE_SKILL_CLOSE = true,
    TRADE_SKILL_DATA_SOURCE_CHANGED = true, TRADE_SKILL_NAME_UPDATE = true, NEW_RECIPE_LEARNED = true,
    SKILL_LINES_CHANGED = true, TRADE_SKILL_FAVORITES_CHANGED = true }
local EVENTS = { "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE",
    "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_NAME_UPDATE", "NEW_RECIPE_LEARNED",
    "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED", "ITEM_DATA_LOAD_RESULT", "PLAYER_REGEN_ENABLED",
    "PLAYERBANKSLOTS_CHANGED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
    "TRACKED_RECIPE_UPDATE", "GROUP_ROSTER_UPDATE", "TRADE_SKILL_FAVORITES_CHANGED" }
local REDRAW_KEYS = { vendorMaterials = true, bagReagents = true, bankReagents = true, ahSearch = true,
    skillThresholds = true,
    craftProfit = true, craftProfitList = true, buyMaterials = true, buyVendor = true, craftOrders = true,
    orderTip = true, ownedAuctions = true }
local PROFESSIONS_ADDON = "Blizzard_Professions"

local EMPTY = {}
local waiting = R.waiting
local win, hooked, lastMode
local queued = false
local savedTabPoints
local docked = {}
local outlines = setmetatable({}, { __mode = "k" })
local bookDocked, bookPending = false, nil
local events = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and not ns.GamepadStandDown()
end

local function NextStrata(strata)
    for i, s in ipairs(STRATA) do
        if s == strata then return STRATA[math.min(i + 1, #STRATA)] end
    end
    return FALLBACK_STRATA
end

local function OutlineTab(tab, on)
    if on and not outlines[tab] then outlines[tab] = ns.Border(tab, ns.THEME.accent) end
    if outlines[tab] then outlines[tab]._frame:SetShown(on) end
end

local function ShowUnlearn(button)
    local icon = button.Icon
    if not icon then return end
    if not C_Texture.GetAtlasInfo(UNLEARN_ATLAS) then icon:SetTexture(UNLEARN_FALLBACK) end
    icon:SetSize(UNLEARN_SIZE, UNLEARN_SIZE)
    icon:SetAlpha(1)
    if button.Overlay then button.Overlay:SetSize(UNLEARN_SIZE, UNLEARN_SIZE) end
end

local function DockTabs(on)
    local head = ProfessionsFrame.ProfessionsOverviewTab
    if not head then return end
    if on then
        if not savedTabPoints then
            savedTabPoints = {}
            for i = 1, head:GetNumPoints() do savedTabPoints[i] = { head:GetPoint(i) } end
        end
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", win, "TOPRIGHT", 0, TABS_DROP)
    elseif savedTabPoints then
        head:ClearAllPoints()
        for _, pt in ipairs(savedTabPoints) do head:SetPoint(unpack(pt)) end
        savedTabPoints = nil
    end
    if head.SetIgnoreParentAlpha then head:SetIgnoreParentAlpha(on) end
    OutlineTab(head, on)
    for _, tab in ipairs(ProfessionsFrame.rightProfessionTabs or EMPTY) do
        if tab.SetIgnoreParentAlpha then tab:SetIgnoreParentAlpha(on) end
        OutlineTab(tab, on)
    end
end

local function Place(frame, place, level)
    frame:ClearAllPoints()
    place(frame)
    frame:SetFrameStrata(win:GetFrameStrata())
    frame:SetFrameLevel(level)
end

local function HideCardArt(frame, saved)
    for _, key in ipairs(CARD_ART) do
        local region = frame[key]
        if type(region) == "table" and region.SetAlpha then
            local art = { region = region, alpha = region:GetAlpha() }
            if region.IsMouseEnabled then
                art.mouse = region:IsMouseEnabled()
                region:EnableMouse(false)
            end
            region:SetAlpha(0)
            saved.art[#saved.art + 1] = art
        end
    end
end

local function Dock(frame, place, level, parent)
    local saved = docked[frame]
    if not saved then
        local points = {}
        for i = 1, frame:GetNumPoints() do points[i] = { frame:GetPoint(i) } end
        saved = { points = points, parent = frame:GetParent(), strata = frame:GetFrameStrata(),
            level = frame:GetFrameLevel(), art = {} }
        docked[frame] = saved
        if parent then
            frame:SetParent(parent)
            HideCardArt(frame, saved)
        end
    end
    saved.place, saved.onLevel = place, level
    Place(frame, place, level)
end

local function Redock()
    if not bookDocked or InCombatLockdown() then return end
    for frame, saved in pairs(docked) do Place(frame, saved.place, saved.onLevel) end
end

local function Undock()
    for frame, saved in pairs(docked) do
        frame:SetParent(saved.parent)
        frame:ClearAllPoints()
        for _, pt in ipairs(saved.points) do frame:SetPoint(unpack(pt)) end
        frame:SetFrameStrata(saved.strata)
        frame:SetFrameLevel(saved.level)
        for _, art in ipairs(saved.art) do
            art.region:SetAlpha(art.alpha)
            if art.mouse ~= nil then art.region:EnableMouse(art.mouse) end
        end
    end
    wipe(docked)
end

local function DockCards(content)
    for i, key in ipairs(P.Book.ORDER) do
        local blizz, card = content[key], win.book.cards[i]
        if blizz then
            Dock(blizz, function(f) f:SetAllPoints(card) end, card:GetFrameLevel() + CARD_LEVEL, card)
            if type(blizz.UnlearnButton) == "table" then
                Dock(blizz.UnlearnButton, function(f) f:SetPoint("LEFT", card.bar, "RIGHT", UNLEARN_GAP, 0) end,
                    card:GetFrameLevel() + UNLEARN_LEVEL)
                ShowUnlearn(blizz.UnlearnButton)
            end
        end
    end
end

local function DockBook(on)
    if on == bookDocked then
        bookPending = nil
        return
    end
    if InCombatLockdown() then
        bookPending = on
        return
    end
    bookPending, bookDocked = nil, on
    if not on then return Undock() end
    local content = ProfessionsFrame.BookPage and ProfessionsFrame.BookPage.ProfessionsContentFrame
    if not content then return end
    DockCards(content)
end

local function Deactivate()
    wipe(waiting)
    ns.ProfBagChanges = ns.ProfBagChanges + 1
    if win and InCombatLockdown() and win:IsProtected() then
        win:SetAlpha(0)
    elseif win then
        win:Hide()
    end
    if ProfessionsFrame and hooked then
        DockTabs(false)
        DockBook(false)
        ProfessionsFrame:SetAlpha(1)
    end
end

local Drag = {}

function Drag.Follow()
    local pos = S.Get("windowPos")
    if not (win and win:IsShown() and pos) then return end
    if InCombatLockdown() then
        Drag.pending = true
        return
    end
    Drag.pending, Drag.following = nil, true
    local scale = win:GetEffectiveScale() / ProfessionsFrame:GetEffectiveScale()
    local x, y = pos.x * scale, pos.y * scale
    local eui = _G.EllesmereUIDB
    if type(eui) == "table" and eui.shifterEnabled then
        eui.shifterPositions = eui.shifterPositions or {}
        eui.shifterPositions.ProfessionsFrame = { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = x, y = y }
    end
    ProfessionsFrame:ClearAllPoints()
    ProfessionsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    Drag.following = false
    Drag.Place()
end

function Drag.Place()
    win:ClearAllPoints()
    win:SetPoint("TOPLEFT", ProfessionsFrame, "TOPLEFT", 0, 0)
end

function Drag.Save()
    S.Set("windowPos", { x = win:GetLeft(), y = win:GetTop() })
end

local function OnDragStart(self)
    if InCombatLockdown() then return end
    local x, y = self:GetLeft(), self:GetTop()
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    self:StartMoving()
end

local function OnDragStop(self)
    self:StopMovingOrSizing()
    Drag.Save()
    Drag.Follow()
end

local function FirstBuild(strata)
    win = P.Window.Build()
    if ns.ShoppingListAttach then ns.ShoppingListAttach(win) end
    win:SetFrameStrata(NextStrata(strata))
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    ns.AllowOffscreen(win)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", OnDragStart)
    win:SetScript("OnDragStop", OnDragStop)
    Drag.Place()
end

local function ShowParts(book, linked)
    win.rank:SetShown(not book)
    win.search:SetShown(not book)
    win.search:SetWidth(linked and Style.LEFT_W or (Style.LEFT_W - Style.FILTER_W - Style.FILTER_GAP))
    win.filter:SetShown(not book and not linked)
    win.list:SetShown(not book)
    win.mid:SetShown(not book)
end

local function Activate(mode)
    local pf = ProfessionsFrame
    if not win then FirstBuild(pf:GetFrameStrata()) end
    pf:SetAlpha(0)
    win:SetAlpha(1)
    local linked = mode == "linked"
    local wide = linked
    local width = wide and Style.WINDOW_W + Style.ORDER_W + Style.PAD or Style.WINDOW_W
    if not InCombatLockdown() then
        win:SetSize(math.max(width, pf:GetWidth()), math.max(Style.MIN_H, pf:GetHeight()))
    end
    if not win:IsShown() or linked ~= W.linked or mode ~= lastMode then W.stale = true end
    lastMode = mode
    if not win:IsShown() or linked ~= W.linked then
        W.selectedID, W.selectedUnlearned, W.offset = nil, nil, 0
        win:Show()
        Drag.Follow()
    end
    W.linked = linked
    win.rank:SetWidth(width - Style.PAD * 2 - RANK_INSET * 2)
    win.order:SetShown(linked)
    DockTabs(true)
    local book = mode == "book"
    ShowParts(book, linked)
    if book then win.rankBanner:Hide() end
    if not (bookDocked and InCombatLockdown()) then win.book:SetShown(book) end
    DockBook(book)
    if book then
        P.Book.Render()
        Redock()
    else
        P.Window.Render()
    end
end

local function BookOpen()
    local book = ProfessionsFrame.BookPage
    return book and book:IsShown()
end

local function Update()
    if not (On() and ProfessionsFrame and ProfessionsFrame:IsShown()) then return Deactivate() end
    if BookOpen() and not Links.Viewing() and not C_TradeSkillUI.IsTradeSkillGuild() then
        return Activate("book")
    end
    if R.Linked() then
        if R.Profession() then return Activate("linked") end
        return Deactivate()
    end
    if not R.Own() then return Deactivate() end
    if BookOpen() then return Activate("book") end
    if R.Profession() then return Activate("craft") end
    Deactivate()
end

local function Flush()
    queued = false
    Update()
end

local function Queue()
    if queued then return end
    queued = true
    C_Timer.After(0, Flush)
end

local function Soon()
    if queued then return end
    queued = true
    C_Timer.After(BURST, Flush)
end

local function Refresh(reread)
    if reread then W.stale = true end
    Queue()
end

local function OnBlizzardHide()
    Links.End()
    Deactivate()
end

local function OnBlizzardPlaced()
    if not Drag.following then Drag.Follow() end
end

local function HookBlizzard()
    hooked = true
    ProfessionsFrame:HookScript("OnShow", Queue)
    ProfessionsFrame:HookScript("OnHide", OnBlizzardHide)
    ProfessionsFrame:HookScript("OnSizeChanged", Queue)
    hooksecurefunc(ProfessionsFrame, "SetPoint", OnBlizzardPlaced)
    local book = ProfessionsFrame.BookPage
    if not book then return end
    book:HookScript("OnShow", Queue)
    book:HookScript("OnHide", Queue)
    if book.Update then hooksecurefunc(book, "Update", Redock) end
    if book.FormatProfession then hooksecurefunc(book, "FormatProfession", Redock) end
end

local function OnEvent(_, event, name, loaded)
    if event == "BAG_UPDATE_DELAYED" then ns.ProfBagChanges = ns.ProfBagChanges + 1 end
    if event == "ITEM_DATA_LOAD_RESULT" then
        if not waiting[name] then return end
        waiting[name] = nil
        if not loaded then return end
    end
    if QUIET[event] and not (win and win:IsShown()) then return end
    if event == "GROUP_ROSTER_UPDATE" and not W.linked then return end
    if event == "ADDON_LOADED" then
        if name ~= PROFESSIONS_ADDON then return end
        events:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_REGEN_ENABLED" then
        if bookPending ~= nil then DockBook(bookPending) end
        if Drag.pending then Drag.Follow() end
    end
    if not hooked and ProfessionsFrame then HookBlizzard() end
    if REREAD[event] then W.stale = true end
    if event == "TRADE_SKILL_LIST_UPDATE" then W.listChanged = true end
    if QUIET[event] or event == "TRADE_SKILL_LIST_UPDATE" then return Soon() end
    Queue()
end

local function Apply()
    events:UnregisterAllEvents()
    if not On() then return Deactivate() end
    for _, event in ipairs(EVENTS) do pcall(events.RegisterEvent, events, event) end
    if not C_AddOns.IsAddOnLoaded(PROFESSIONS_ADDON) then events:RegisterEvent("ADDON_LOADED") end
    OnEvent(events, "APPLY")
end

local function OnSettingChanged(key)
    if key == "enabled" then Apply() end
    if REDRAW_KEYS[key] then Queue() end
end

ns.ProfWindowRefresh = Refresh

events:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

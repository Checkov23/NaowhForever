-- Window.lua: the options window, a module's own window, and the lifecycle half of ns.UI.
local ns = _G.NaowhForever
local T = ns.THEME
local UI = ns.UI
local O = ns.Options

local SYSTEM_PAGES, MODULES, PAGES = O.SYSTEM_PAGES, O.MODULES, O.PAGES
local DisplayName, Loaded, ModuleOn, SetModuleOn = O.DisplayName, O.Loaded, O.ModuleOn, O.SetModuleOn

local MEDIA = ns.MEDIA
local LINK_ICONS = MEDIA .. "Links\\"
local NAV_ICONS = MEDIA .. "Navigation\\"
local BRAND_LOGO = MEDIA .. "BrandLogo.tga"
local NAV_DOT_TEXTURE = MEDIA .. "circle_mask.tga"
local NAV_OPEN_TEXTURE = NAV_ICONS .. "window.tga"
local SIDEBAR_W, CONTENT_W, WINDOW_W, WINDOW_H = 240, 1000, 1440, 852
local MIN_WINDOW_H = 620
local TOP_H, PAGE_HEADER_H = 64, 128
local HEADER_H, TAB_H, NAV_H = 76, 32, 32
local TAB_TUCK = 12
local NAV_INSET, NAV_GUTTER, NAV_ICON_X, NAV_ICON_SIZE, NAV_LABEL_X = 8, 12, 14, 20, 42
local SEARCH = { h = 26, top = 10, gap = 4, left = NAV_INSET, right = NAV_INSET + NAV_GUTTER,
    columns = { icon = NAV_ICON_X + NAV_ICON_SIZE / 2, text = NAV_LABEL_X } }
local SCROLL_BAR_GAP = 12
local NAV_STEP = 30
local NAV_DOT, NAV_OPEN, NAV_OPEN_ICON = 6, 22, 14
local NAV_COUNT_SIZE = 12
-- 28 keeps every module inside the default 852-high window (test-navigation.lua).
local NAV_ROW, NAV_OFF_ALPHA = 28, 0.45
local MISS_ALPHA = 0.3
local NAV_BUTTON_EXTRA, NAV_FILL_ALPHA, NAV_MARKER_W = 6, 0.16, 3
local NAV_TEXT_SIZE, NAV_TEXT_X, NAV_TEXT_RIGHT, NAV_COUNT_RIGHT = 14, 18, 10, 14
local NAV_OPEN_RIGHT, NAV_OPEN_ROOM = 6, 8
local NAV_OPEN_DIM = 0.5
local GROUP_ORDER = { [""] = 0, ADVENTURE = 1, COMBAT = 2, UTILITIES = 3 }
local FOOTER_H_SIDEBAR = 28
local BRAND = { artW = 448, artH = 139, texW = 512, texH = 256, height = 56, inset = 8 }
local CONTENT_X, CONTENT_RIGHT = 26, 30
local SCROLL_X, SCROLL_Y, SCROLL_BOTTOM, CHILD_ROOM = 6, 8, 14, 36
local TAB_MARGIN = 28
local PAGE_TOP, PAGE_ROOM = 6, 30
local SETTING_AT = 1 / 3
local SCREEN_MARGIN, MIN_FIT = 32, 0.25
local DEFAULT_SCALE = 100
local NAV_BAR = { w = 10, inset = 1 }
local SOON = { titleSize = 16, textSize = 12, top = 60, gap = 12, inset = 60, height = 180 }
local HEAD = { crumbSize = 12, crumbY = 24, titleSize = 24, titleY = 51, titleRoom = 300, subSize = 12, subY = 94,
    switchW = 52, switchH = 26, switchY = 54, labelGap = 14, labelSize = 14, tabDrop = 14 }
local SIDE = { groupSize = 11, groupX = 20, groupY = 10, groupStep = 28, utilityRow = 28, utilityTop = 4,
    utilityRoom = 6, versionSize = 10, versionX = 20, versionY = 10, linksRight = 14, linksY = 8, linkSize = 16,
    linkGap = 10 }
local TOP = { gap = 18, close = 28, hudW = 140, reloadW = 110, buttonH = 32 }
local MW = { titleSize = 20, titleX = 30, titleY = 18, subSize = 12, subX = 1, subGap = 6, close = 26,
    closeInset = 12, switchGap = 14, tabX = 30, tabDrop = 2, tabRoom = 60, scrollX = 10, scrollY = 5,
    scrollRight = 30, scrollBottom = 22, childRoom = 40, h = 560, minH = 360, switchRaise = 2 }
local OPTIONS_NAME = "NaowhForeverOptions"
local FIRST_PAGE = "QoL/Interface"
local SETTINGS_PAGE = "Settings"
local LINKS = {
    { "Discord", "discord", function() return "https://discord.gg/V2eSJMBynn" end },
    { "Website", "website", function() return "https://naowh.gg" end },
    { "GitHub", "github", function() return "https://github.com/naowh-gaming/NaowhForever" end },
}
local SYSTEM_NAV = { { "Settings", "settings" }, { UI.PROFILES_PAGE, "person" }, { "Patch Notes", "notes" }, { "Credits", "heart" } }
local TEXT_VERSION, TEXT_UNKNOWN = "v", "unknown"
local TEXT_COMING_SOON = "Coming soon"
local TEXT_ENABLE = "Enable %s"
local TEXT_OPEN = "Open %s"
local TEXT_BRAND = "Naowh Forever"
local TEXT_CLOSE = "X"
local TEXT_HUD_EDITOR = "HUD Editor"
local TEXT_SUB_COMMAND = "%s  (/nf%s)"
local TEXT_HUD_HELP = "Place and size each display. Exit Config returns to this window."
local TEXT_RELOAD = "Reload UI"
local TEXT_MODULE, TEXT_MODULE_HELP = "Module", "Turn this module on or off. Your settings are kept."
local TEXT_BACK = "Back to Settings"
local TEXT_ON = "On. Click to turn the whole module off."
local TEXT_OFF = "Off. Click to turn it back on."
local TEXT_SWITCHED_OFF = "%s is switched off. Turn it on under Settings > Modules."
local TEXT_NO_MATCH = "Nothing on this page matches the search."

ns.LINKS, ns.LINK_ICONS = LINKS, LINK_ICONS

local window, scrollFrame, scrollChild, tabLine, headerTitle, headerSub
local contentHeader, searchBox, breadcrumb, moduleSwitch, moduleLabel
local lastPages = {}
local navButtons, tabStrips, navBlocks = {}, {}, {}
local wrappers = {}
local currentPage = FIRST_PAGE
local pendingRefresh
local onShowCallbacks, onHideCallbacks = {}, {}
local moduleWindows = {}
local refreshQueued
local lastFilter, searchJump
local NO_TABS = {}

function ns.VersionText()
    return TEXT_VERSION .. (ns.CODE_BUILD or C_AddOns.GetAddOnMetadata(ns.MODULE_KEY, "Version") or TEXT_UNKNOWN)
end

function UI:RegisterOnShow(fn) onShowCallbacks[#onShowCallbacks + 1] = fn end
function UI:RegisterOnHide(fn) onHideCallbacks[#onHideCallbacks + 1] = fn end
function UI:ClearContentHeader() end

local function SoonPage(parent, text)
    local head, body = parent.soonHead, parent.soonBody
    if not head then
        head = ns.Font(parent, SOON.titleSize, "OUTLINE", T.muted)
        head:SetPoint("TOP", parent, "TOP", 0, -SOON.top)
        body = ns.Font(parent, SOON.textSize, nil, T.muted)
        body:SetPoint("TOP", head, "BOTTOM", 0, -SOON.gap)
        body:SetPoint("LEFT", parent, "LEFT", SOON.inset, 0)
        body:SetPoint("RIGHT", parent, "RIGHT", -SOON.inset, 0)
        body:SetJustifyH("CENTER")
        body:SetWordWrap(true)
        parent.soonHead, parent.soonBody = head, body
    end
    head:SetText(ns.L(TEXT_COMING_SOON))
    body:SetText(text)
    return -SOON.height
end

local function BuildPageInto(page, parent, filter)
    if page.soon then return SoonPage(parent, page.soon) end
    local Settings = ns.Shared and ns.Shared.Settings
    if Settings and Settings.pages[page.key] then
        return -Settings.Render(parent, page.key, function(height)
            parent:SetHeight(height + PAGE_ROOM)
            local child = parent:GetParent()
            if child and parent:IsShown() then child:SetHeight(parent:GetHeight()) end
        end, filter)
    end
    local fn = ns[page.build]
    if not fn then return -PAGE_TOP end
    local y = -PAGE_TOP
    if filter and not filter.count[page.key] then
        local _, h = UI.Widgets:Note(parent, TEXT_NO_MATCH, y)
        y = y - h
    end
    return fn(parent, y, page.arg)
end

local function ActiveNav()
    local page = PAGES[currentPage]
    return page.module and page.module.name or page.key
end

local function PaintTabs(bar, shown, filter)
    ns.Shared.Parts.PaintTabs(bar, shown)
    for _, button in ipairs(bar.buttons) do
        local page = PAGES[button.key]
        local alpha = 1
        if page and page.soon then
            alpha = NAV_OFF_ALPHA
        elseif filter and not filter.count[button.key] then
            alpha = MISS_ALPHA
        end
        button.text:SetAlpha(alpha)
    end
end

local function LayoutBlock(block)
    local y = block.top
    for pass = 1, 2 do
        for _, mod in ipairs(block.mods) do
            if (not ModuleOn(mod)) == (pass == 2) then
                local btn = navButtons[mod.name]
                btn:SetPoint("TOPLEFT", NAV_INSET, y)
                btn:SetPoint("TOPRIGHT", -NAV_INSET, y)
                y = y - NAV_ROW
            end
        end
    end
end

local function LayoutNav()
    for _, block in ipairs(navBlocks) do LayoutBlock(block) end
end

local function PaintNavButton(btn, hover)
    local active = btn.fill:IsShown()
    local found = UI.filter and btn.found
    local off = btn.mod ~= nil and not ModuleOn(btn.mod)
    local c = (active or hover) and T.fg or (ns.classicSkin and T.accent or T.muted)
    local a = (off and not active and not hover) and NAV_OFF_ALPHA or 1
    if found == false and not active and not hover then a = MISS_ALPHA end
    btn.label:SetTextColor(c.r, c.g, c.b, a)
    if btn.fullColor then
        btn.icon:SetAlpha(a)
    elseif btn.icon then
        btn.icon:SetVertexColor(c.r, c.g, c.b, a)
    end
    if btn.open then btn.open:SetAlpha((active or hover) and 1 or NAV_OPEN_DIM) end
    if btn.dot then btn.dot:SetShown(off and not UI.filter) end
    btn.count:SetText(found and found > 0 and found or "")
end

local function Found(filter, name, btn)
    local n = filter.count[name]
    for _, tab in ipairs(btn.mod and btn.mod.tabs or NO_TABS) do
        local c = filter.count[tab.key]
        if c then n = (n or 0) + c end
    end
    return n or false
end

local function PaintNav()
    local nav = ActiveNav()
    local filter = UI.filter
    LayoutNav()
    for name, btn in pairs(navButtons) do
        local active = name == nav
        btn.fill:SetShown(active)
        btn.marker:SetShown(active)
        btn.found = nil
        if filter then btn.found = Found(filter, name, btn) end
        PaintNavButton(btn, btn:IsMouseOver())
    end
    for _, bar in pairs(tabStrips) do PaintTabs(bar, currentPage, filter) end
end

local function LayoutHeader(page, mod, headerH)
    headerTitle:SetText(mod and DisplayName(mod) or ns.L(page.title))
    breadcrumb:SetText(mod and (DisplayName(mod) .. " / " .. ns.L(page.name)) or TEXT_BRAND)
    headerSub:SetText(mod and (mod.command and TEXT_SUB_COMMAND:format(ns.L(mod.subtitle), mod.command)
        or ns.L(mod.subtitle)) or ns.L(page.subtitle))
    contentHeader:ClearAllPoints()
    contentHeader:SetPoint("TOPLEFT", window, "TOPLEFT", SIDEBAR_W, -TOP_H)
    contentHeader:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, -TOP_H)
    contentHeader:SetHeight(headerH)
    moduleSwitch:SetShown(mod ~= nil and not page.soon)
    moduleLabel:SetShown(mod ~= nil and not page.soon)
    if mod and not page.soon then
        moduleLabel:SetText(ns.L(TEXT_ENABLE, ns.L(mod.name)))
        moduleSwitch._refreshValue()
    end
end

local function LayoutContent()
    local page = PAGES[currentPage]
    local mod = page.module
    local nested = mod and #mod.tabs > 1
    local left, top = SIDEBAR_W, TOP_H
    local headerH = PAGE_HEADER_H + (nested and TAB_H - TAB_TUCK or 0)
    LayoutHeader(page, mod, headerH)
    for name, strip in pairs(tabStrips) do strip:SetShown(nested and name == mod.name or false) end
    tabLine:ClearAllPoints()
    tabLine:SetPoint("TOPLEFT", window, "TOPLEFT", left + CONTENT_X, -(top + headerH))
    tabLine:SetPoint("TOPRIGHT", window, "TOPRIGHT", -CONTENT_RIGHT, -(top + headerH))
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", window, "TOPLEFT", left + SCROLL_X, -(top + headerH + SCROLL_Y))
    scrollFrame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -CONTENT_RIGHT, SCROLL_BOTTOM)
    scrollChild:SetWidth(window:GetWidth() - left - CHILD_ROOM)
end

local function NewWrapper(child)
    local wrapper = CreateFrame("Frame", nil, child)
    wrapper:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    wrapper:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, 0)
    wrapper:SetHeight(1)
    wrapper._dirty = true
    return wrapper
end

local function BuildWrapper(wrapper, child, key, filter)
    wrapper._builtWidth = child:GetWidth()
    wrapper._dirty = nil
    wrapper._pageKey, wrapper._collapsible, wrapper._nsuiCollapsed = key, PAGES[key].collapse, nil
    wrapper._nsuiFeatureId = nil
    if PAGES[key].reuse then UI.BeginReusableRows(wrapper) end
    local usedY = BuildPageInto(PAGES[key], wrapper, filter)
    wrapper:SetHeight(math.abs(usedY) + PAGE_ROOM)
end

local function ShowWrapper(pageWrappers, child, key, filter)
    for name, w in pairs(pageWrappers) do
        w:SetShown(name == key)
    end
    if not pageWrappers[key] then pageWrappers[key] = NewWrapper(child) end
    local wrapper = pageWrappers[key]
    if wrapper._builtWidth ~= child:GetWidth() then wrapper._dirty = true end
    if wrapper._dirty then BuildWrapper(wrapper, child, key, filter) end
    child:SetHeight(wrapper:GetHeight())
end

local function ShowPage(key)
    if PAGES[key].module and not Loaded(PAGES[key].module) then key = SETTINGS_PAGE end
    currentPage = key
    if PAGES[key].module then lastPages[PAGES[key].module.name] = key end
    LayoutContent()
    ShowWrapper(wrappers, scrollChild, key, UI.filter)
    scrollFrame:SetVerticalScroll(0)
    PaintNav()
end

function UI.SearchPages()
    local pages = {}
    for _, page in ipairs(SYSTEM_PAGES) do pages[#pages + 1] = page end
    for _, mod in ipairs(MODULES) do
        for _, tab in ipairs(mod.tabs) do
            if not tab.soon and Loaded(mod) then pages[#pages + 1] = tab end
        end
    end
    return pages
end

local function ScrollToSetting(key, label, card)
    local Settings = ns.Shared.Settings
    if not (card and Settings.pages[key]) then return end
    local _, top = Settings.FindRow(wrappers[key], label, card)
    if not top then return end
    scrollFrame:UpdateScrollChildRect()
    local y = top - scrollFrame:GetHeight() * SETTING_AT
    scrollFrame:SetVerticalScroll(math.min(scrollFrame:GetVerticalScrollRange(), math.max(0, y)))
end

function UI.GoToSetting(key, label, card)
    if not (window and PAGES[key]) then return end
    if UI.SearchTyped() then
        searchJump = true
        UI.ClearSearch()
        searchJump = false
    end
    if card then ns.Shared.Settings.Reveal(card) end
    if wrappers[key] then wrappers[key]._dirty = true end
    ShowPage(key)
    ScrollToSetting(key, label, card)
end

local function ShowModulePage(win, key)
    win.page = key
    ShowWrapper(win.wrappers, win.scrollChild, key)
    win.scrollFrame:SetVerticalScroll(0)
    win.switch._refreshValue()
    PaintTabs(win.tabs, key)
end

local function InvalidatePages(pageWrappers)
    for name, w in pairs(pageWrappers) do
        if PAGES[name].reuse or PAGES[name].soon then
            w._dirty = true
        else
            w:Hide()
            w:SetParent(nil)
            pageWrappers[name] = nil
        end
    end
end

local function RebuildModuleWindow(win)
    if not win:IsShown() then
        win.pendingRefresh = true
        return
    end
    local scroll = win.scrollFrame:GetVerticalScroll()
    InvalidatePages(win.wrappers)
    ShowModulePage(win, win.page)
    win.scrollFrame:UpdateScrollChildRect()
    win.scrollFrame:SetVerticalScroll(scroll)
end

local function RebuildPages()
    refreshQueued = false
    if UI.HideWidgetTooltip then UI.HideWidgetTooltip() end
    if window and window:IsShown() then
        local scroll = scrollFrame:GetVerticalScroll()
        InvalidatePages(wrappers)
        ShowPage(currentPage)
        scrollFrame:UpdateScrollChildRect()
        scrollFrame:SetVerticalScroll(scroll)
    else
        pendingRefresh = true
    end
    for _, win in pairs(moduleWindows) do RebuildModuleWindow(win) end
end

local function InvalidateFiltered()
    for _, w in pairs(wrappers) do w._dirty = true end
end

local function FirstMatch(filter, key)
    for _, k in ipairs(filter.order) do
        if PAGES[k].module then key = k break end
    end
    if not filter.count[key] and filter.order[1] then key = filter.order[1] end
    return key
end

local function RevealFound(last, key)
    for uid in pairs(last.cards) do
        local card = ns.Shared.Settings.CardOf(uid)
        if card and card.page.key == key then ns.Shared.Settings.Reveal(uid) end
    end
    return last.first[key]
end

local function OnSearch()
    local filter, last = UI.filter, lastFilter
    lastFilter = filter
    if not (window and window:IsShown()) then
        pendingRefresh = true
        return
    end
    if searchJump then
        InvalidateFiltered()
        return
    end
    local key, found = currentPage, nil
    if filter and not filter.count[key] then
        key = FirstMatch(filter, key)
    elseif not filter and last and last.first[key] and not last.all[key] then
        found = RevealFound(last, key)
    end
    InvalidateFiltered()
    ShowPage(key)
    if found then ScrollToSetting(key, nil, found) end
end

local function AnyWindowShown()
    if window and window:IsShown() then return true end
    for _, win in pairs(moduleWindows) do
        if win:IsShown() then return true end
    end
    return false
end

function UI:RefreshPage(force)
    if not AnyWindowShown() then
        pendingRefresh = true
        for _, win in pairs(moduleWindows) do win.pendingRefresh = true end
        return
    end
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, RebuildPages)
end

local function OnEquipmentChanged(_, _, slot)
    if slot == INVSLOT_TRINKET1 or slot == INVSLOT_TRINKET2 then UI:RefreshPage(true) end
end

local equipWatcher = CreateFrame("Frame")
equipWatcher:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
equipWatcher:SetScript("OnEvent", OnEquipmentChanged)

local function FitMainWindow()
    if not window then return end
    local fit = math.min((UIParent:GetWidth() - SCREEN_MARGIN) / window:GetWidth(),
        (UIParent:GetHeight() - SCREEN_MARGIN) / window:GetHeight())
    window:SetScale(math.min(ns.UIScale(), math.max(MIN_FIT, fit)))
    ns.RefitPixels()
end

function ns.SetWindowScale(pct)
    ns.AccountSettings().windowScale = tonumber(pct) or DEFAULT_SCALE
    FitMainWindow()
    for _, win in pairs(moduleWindows) do win:SetScale(ns.UIScale()) end
    ns.RefitPixels()
end

local function EnterUnlockMode()
    if ns.ShowUnlockMode then ns.ShowUnlockMode() end
end

local function DragRegion(frame, target)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() target:StartMoving() end)
    frame:SetScript("OnDragStop", function() target:StopMovingOrSizing() end)
    ns.AllowOffscreen(target)
end

local function Resizable(frame, key, child, inset, minW, minH)
    local function Fit()
        child:SetWidth(frame:GetWidth() - (type(inset) == "function" and inset() or inset))
    end
    local function Released()
        local width = child:GetWidth()
        Fit()
        if frame == window then FitMainWindow() end
        if child:GetWidth() ~= width then UI:RefreshPage(true) end
    end
    ns.Shared.Parts.Resizable(frame, key, minW, minH, nil, Released)
    Fit()
end

local function CloseOnEscape(self, key)
    if InCombatLockdown() then return end
    if key == "ESCAPE" then
        self:Hide()
        self:SetPropagateKeyboardInput(false)
        C_Timer.After(0, function()
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
        end)
    else
        self:SetPropagateKeyboardInput(true)
    end
end
UI.CloseOnEscape = CloseOnEscape

local function TabStrip(parent, mod, onPick, maxW)
    local items = {}
    for i, tab in ipairs(mod.tabs) do items[i] = { key = tab.key, label = ns.L(tab.name) } end
    local Parts = ns.Shared.Parts
    local bar = Parts.Tabs(parent, 1, items, onPick)
    Parts.FitTabs(bar, items, TAB_MARGIN, maxW)
    return bar
end

local function ClampNav(scroll)
    local range = scroll:GetVerticalScrollRange()
    scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScroll(), range)))
end

local function RefreshNavRange(scroll)
    scroll:GetScript("OnScrollRangeChanged")(scroll)
    ClampNav(scroll)
end

local function RefitNav(scroll)
    scroll:UpdateScrollChildRect()
    RefreshNavRange(scroll)
end

local function NavigationScroll(parent, top, bottom, width)
    local scroll = UI.SlimScroll(parent, NAV_BAR.w, NAV_BAR.inset)
    scroll:SetPoint("TOPLEFT", 0, -top)
    scroll:SetPoint("BOTTOMRIGHT", -NAV_GUTTER, bottom)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(width - NAV_GUTTER, 1)
    scroll:SetScrollChild(child)
    scroll:HookScript("OnScrollRangeChanged", ClampNav)
    scroll:SetScript("OnShow", RefreshNavRange)
    scroll:SetScript("OnSizeChanged", RefitNav)
    UI.SmoothWheel(scroll, NAV_H)
    return child
end

local function NavEnter(btn)
    PaintNavButton(btn, true)
end

local function NavLeave(btn)
    if btn:IsMouseOver() then return end
    PaintNavButton(btn, false)
end

local function NavIcon(btn, icon)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(NAV_ICON_SIZE, NAV_ICON_SIZE)
    btn.icon:SetPoint("LEFT", NAV_ICON_X, 0)
    btn.fullColor = ns.Shared.Parts.ClassicIcon(btn.icon, icon)
    if not btn.fullColor then
        btn.icon:SetTexture(NAV_ICONS .. icon .. ".tga")
        btn.icon:SetVertexColor(T.muted.r, T.muted.g, T.muted.b, 1)
    end
end

local function NavigationButton(parent, label, y, onClick, icon)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetPoint("TOPLEFT", NAV_INSET, y)
    btn:SetPoint("TOPRIGHT", -NAV_INSET, y)
    btn:SetHeight(NAV_ROW + NAV_BUTTON_EXTRA)
    btn.fill = ns.Solid(btn, "BACKGROUND", T.accent, NAV_FILL_ALPHA)
    btn.fill:SetAllPoints()
    btn.fill:Hide()
    btn.marker = ns.Solid(btn, "ARTWORK", T.accent, 1)
    btn.marker:SetPoint("TOPLEFT"); btn.marker:SetPoint("BOTTOMLEFT"); btn.marker:SetWidth(NAV_MARKER_W)
    btn.marker:Hide()
    if ns.classicSkin then
        local St = ns.Shared.Style
        local c = St.CLASSIC_PICK_RGB
        btn.fill:SetColorTexture(1, 1, 1, 1)
        btn.fill:SetGradient("HORIZONTAL", CreateColor(c.r, c.g, c.b, St.CLASSIC_PICK_ALPHA),
            CreateColor(c.r, c.g, c.b, St.CLASSIC_PICK_FADE))
        local line = St.CLASSIC_PICK_LINE_RGB
        btn.marker:SetColorTexture(line.r, line.g, line.b, St.CLASSIC_PICK_LINE_ALPHA)
        btn.marker:ClearAllPoints()
        btn.marker:SetPoint("TOPLEFT"); btn.marker:SetPoint("TOPRIGHT")
        ns.Hairline(btn.marker, "h")
    end
    btn.label = ns.Font(btn, NAV_TEXT_SIZE, nil, T.muted, true)
    btn.label:SetPoint("LEFT", icon and NAV_LABEL_X or NAV_TEXT_X, 0)
    btn.label:SetPoint("RIGHT", -NAV_TEXT_RIGHT, 0)
    btn.label:SetJustifyH("LEFT")
    btn.label:SetWordWrap(false)
    btn.label:SetText(label)
    btn.count = ns.Font(btn, NAV_COUNT_SIZE, nil, T.accent)
    btn.count:SetPoint("RIGHT", -NAV_COUNT_RIGHT, 0)
    if icon then NavIcon(btn, icon) end
    btn:SetScript("OnClick", onClick)
    btn:SetScript("OnEnter", NavEnter)
    btn:SetScript("OnLeave", NavLeave)
    return btn
end

local function OpenEnter(open)
    PaintNavButton(open:GetParent(), true)
    open.icon:SetVertexColor(T.accent.r, T.accent.g, T.accent.b, 1)
    GameTooltip:SetOwner(open, "ANCHOR_RIGHT")
    GameTooltip:SetText(ns.L(TEXT_OPEN, DisplayName(open:GetParent().mod)), 1, 1, 1)
    GameTooltip:Show()
end

local function OpenLeave(open)
    open.icon:SetVertexColor(T.muted.r, T.muted.g, T.muted.b, 1)
    GameTooltip:Hide()
    local btn = open:GetParent()
    PaintNavButton(btn, btn:IsMouseOver())
end

local function OpenClicked(open)
    local fn = ns[open:GetParent().mod.open]
    if fn then ns.OpenFromOptions(fn) end
end

local function NavOpenButton(btn)
    local open = CreateFrame("Button", nil, btn)
    open:SetSize(NAV_OPEN, NAV_OPEN)
    open:SetPoint("RIGHT", -NAV_OPEN_RIGHT, 0)
    open.icon = open:CreateTexture(nil, "ARTWORK")
    open.icon:SetTexture(NAV_OPEN_TEXTURE, nil, nil, "TRILINEAR")
    open.icon:SetSize(NAV_OPEN_ICON, NAV_OPEN_ICON)
    open.icon:SetPoint("CENTER")
    open.icon:SetVertexColor(T.muted.r, T.muted.g, T.muted.b, 1)
    open:SetScript("OnClick", OpenClicked)
    open:SetScript("OnEnter", OpenEnter)
    open:SetScript("OnLeave", OpenLeave)
    return open
end

local function NavExtras(btn, mod)
    btn.mod = mod
    btn.dot = btn:CreateTexture(nil, "ARTWORK")
    btn.dot:SetTexture(NAV_DOT_TEXTURE, nil, nil, "TRILINEAR")
    btn.dot:SetSize(NAV_DOT, NAV_DOT)
    btn.dot:SetPoint("RIGHT", -NAV_COUNT_RIGHT, 0)
    btn.dot:SetVertexColor(T.muted.r, T.muted.g, T.muted.b, NAV_OFF_ALPHA)
    btn.dot:Hide()
    if not mod.open then return end
    btn.open = NavOpenButton(btn)
    btn.label:SetPoint("RIGHT", -(NAV_OPEN + NAV_OPEN_ROOM), 0)
    btn.count:ClearAllPoints()
    btn.count:SetPoint("RIGHT", btn.open, "LEFT")
    btn.dot:ClearAllPoints()
    btn.dot:SetPoint("RIGHT", btn.open, "LEFT")
end

local function OnWindowKeyDown(self, key)
    if InCombatLockdown() then return end
    local open = key == "F" and IsControlKeyDown()
    if not (open or (key == "ESCAPE" and UI.SearchTyped())) then return CloseOnEscape(self, key) end
    self:SetPropagateKeyboardInput(false)
    if open then UI.FocusSearch() else UI.ClearSearch() end
    C_Timer.After(0, function()
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
    end)
end

local function WindowFrame()
    window = CreateFrame("Frame", OPTIONS_NAME, UIParent)
    window:SetSize(WINDOW_W, WINDOW_H)
    window:SetScale(ns.UIScale())
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    ns.Shared.Parts.Backdrop(window):Paint(1)
    ns.Shared.Parts.Shadow(window)
    local border = ns.Border(window, ns.Shared.Style.BORDER_RGB)
    if ns.classicSkin then
        ns.Shared.Parts.ClassicTrim(window)
        ns.Shared.Parts.TitlePlate(window, TEXT_BRAND)
    end
    window:SetScript("OnKeyDown", OnWindowKeyDown)
    return border
end

local function Brand(top, border)
    local brand = CreateFrame("Frame", nil, top)
    brand:SetPoint("TOPLEFT")
    brand:SetSize(SIDEBAR_W, TOP_H)
    ns.Solid(brand, "BACKGROUND", T.panel, 1):SetAllPoints()
    local brandEdge = ns.Solid(brand, "ARTWORK", T.line, 1)
    brandEdge:SetPoint("TOPRIGHT"); brandEdge:SetPoint("BOTTOMRIGHT"); ns.Hairline(brandEdge, "v")
    local logo = brand:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(BRAND_LOGO, nil, nil, "TRILINEAR")
    logo:SetTexCoord(0, BRAND.artW / BRAND.texW, 0, BRAND.artH / BRAND.texH)
    logo:SetSize(BRAND.height * BRAND.artW / BRAND.artH, BRAND.height)
    logo:SetPoint("TOPLEFT", brand, "TOPLEFT", BRAND.inset, -BRAND.inset)
    border._frame:SetFrameLevel(brand:GetFrameLevel() + 1)
end

local function TopBar(border)
    local top = CreateFrame("Frame", nil, window)
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(TOP_H)
    DragRegion(top, window)
    local topLine = ns.Solid(top, "ARTWORK", T.line, 1)
    topLine:SetPoint("BOTTOMLEFT"); topLine:SetPoint("BOTTOMRIGHT"); ns.Hairline(topLine, "h")
    Brand(top, border)
    local close = ns.Button(top, TEXT_CLOSE, TOP.close, TOP.close, function() window:Hide() end)
    close:SetPoint("RIGHT", -TOP.gap, 0)
    local unlock = ns.Button(top, TEXT_HUD_EDITOR, TOP.hudW, TOP.buttonH, EnterUnlockMode)
    ns.AccentBorder(unlock)
    unlock:SetPoint("RIGHT", close, "LEFT", -TOP.gap, 0)
    ns.Tooltip(unlock, TEXT_HUD_EDITOR, TEXT_HUD_HELP)
    local reload = ns.ReloadButton(top, TEXT_RELOAD, TOP.reloadW, TOP.buttonH)
    reload:SetPoint("RIGHT", unlock, "LEFT", -TOP.gap, 0)
end

local function ByGroupOrder(a, b) return GROUP_ORDER[a] < GROUP_ORDER[b] end

local function Ready(mod)
    for _, tab in ipairs(mod.tabs) do
        if not tab.soon then return true end
    end
    return false
end

local function NavGroups()
    local groups, grouped = {}, {}
    for _, mod in ipairs(MODULES) do
        if Ready(mod) and Loaded(mod) then
            local group = mod.group or ""
            if not grouped[group] then
                grouped[group] = {}
                groups[#groups + 1] = group
            end
            table.insert(grouped[group], mod)
        end
    end
    table.sort(groups, ByGroupOrder)
    return groups, grouped
end

local function ModuleNav(nav)
    local groups, grouped = NavGroups()
    local ny = 0
    for _, group in ipairs(groups) do
        if group ~= "" then
            local label = ns.Font(nav, SIDE.groupSize, nil, T.muted, true)
            label:SetPoint("TOPLEFT", SIDE.groupX, ny - SIDE.groupY); label:SetText(ns.L(group))
            ny = ny - SIDE.groupStep
        end
        navBlocks[#navBlocks + 1] = { top = ny, mods = grouped[group] }
        for _, mod in ipairs(grouped[group]) do
            local btn = NavigationButton(nav, DisplayName(mod), ny,
                function() ShowPage(lastPages[mod.name] or mod.tabs[1].key) end, mod.navIcon)
            btn:SetHeight(NAV_ROW)
            NavExtras(btn, mod)
            navButtons[mod.name] = btn
            ny = ny - NAV_ROW
        end
    end
    nav:SetHeight(-ny)
end

local function SystemNav(sidebar)
    local utility = CreateFrame("Frame", nil, sidebar)
    utility:SetPoint("BOTTOMLEFT", 0, FOOTER_H_SIDEBAR); utility:SetPoint("BOTTOMRIGHT", 0, FOOTER_H_SIDEBAR)
    utility:SetHeight(NAV_STEP * #SYSTEM_NAV + SIDE.utilityRoom)
    local utilityLine = ns.Solid(utility, "ARTWORK", T.line, 1)
    utilityLine:SetPoint("TOPLEFT"); utilityLine:SetPoint("TOPRIGHT"); ns.Hairline(utilityLine, "h")
    for i, entry in ipairs(SYSTEM_NAV) do
        local key = entry[1]
        local btn = NavigationButton(utility, ns.L(key), -SIDE.utilityTop - (i - 1) * NAV_STEP, function() ShowPage(key) end,
            entry[2])
        btn:SetHeight(SIDE.utilityRow)
        navButtons[key] = btn
    end
end

local function SidebarFooter(sidebar)
    local version = ns.Font(sidebar, SIDE.versionSize, nil, T.muted)
    version:SetPoint("BOTTOMLEFT", SIDE.versionX, SIDE.versionY)
    version:SetText(ns.VersionText())
    local Parts = ns.Shared.Parts
    local right = -SIDE.linksRight
    for i = #LINKS, 1, -1 do
        local name, icon, url = LINKS[i][1], LINKS[i][2], LINKS[i][3]
        local link = Parts.IconButton(sidebar, function() ns.ShowCopyLine(name, url()) end, LINK_ICONS .. icon .. ".tga",
            nil, name)
        link:SetSize(SIDE.linkSize, SIDE.linkSize)
        link.icon:SetSize(SIDE.linkSize, SIDE.linkSize)
        link:SetPoint("BOTTOMRIGHT", right, SIDE.linksY)
        right = right - SIDE.linkSize - SIDE.linkGap
    end
end

local function Sidebar()
    local sidebar = CreateFrame("Frame", nil, window)
    sidebar:SetPoint("TOPLEFT", 0, -TOP_H); sidebar:SetPoint("BOTTOMLEFT"); sidebar:SetWidth(SIDEBAR_W)
    local edge = ns.Solid(sidebar, "ARTWORK", T.line, 1)
    edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); ns.Hairline(edge, "v")
    searchBox = UI.AttachSearchBox(sidebar, OnSearch, SEARCH.columns)
    searchBox:SetPoint("TOPLEFT", SEARCH.left, -SEARCH.top)
    searchBox:SetPoint("TOPRIGHT", -SEARCH.right, -SEARCH.top)
    searchBox:SetHeight(SEARCH.h)
    local nav = NavigationScroll(sidebar, SEARCH.top + SEARCH.h + SEARCH.gap,
        FOOTER_H_SIDEBAR + SIDE.utilityRoom + NAV_STEP * #SYSTEM_NAV, SIDEBAR_W)
    ModuleNav(nav)
    SystemNav(sidebar)
    SidebarFooter(sidebar)
end

local function CurrentModuleOn()
    local mod = PAGES[currentPage].module
    return mod and ModuleOn(mod)
end

local function SetCurrentModuleOn(v)
    local mod = PAGES[currentPage].module
    if mod then SetModuleOn(mod, v) end
end

local function ContentHeader()
    contentHeader = CreateFrame("Frame", nil, window)
    contentHeader:SetHeight(PAGE_HEADER_H)
    breadcrumb = ns.Font(contentHeader, HEAD.crumbSize, nil, T.muted)
    breadcrumb:SetPoint("TOPLEFT", CONTENT_X, -HEAD.crumbY)
    headerTitle = ns.Font(contentHeader, HEAD.titleSize, nil, ns.classicSkin and T.accent or nil, true)
    headerTitle:SetPoint("TOPLEFT", CONTENT_X, -HEAD.titleY)
    headerTitle:SetPoint("TOPRIGHT", contentHeader, "TOPRIGHT", -HEAD.titleRoom, -HEAD.titleY)
    headerTitle:SetJustifyH("LEFT"); headerTitle:SetWordWrap(false)
    headerSub = ns.Font(contentHeader, HEAD.subSize, nil, T.muted)
    headerSub:SetPoint("TOPLEFT", CONTENT_X, -HEAD.subY)
    headerSub:SetPoint("TOPRIGHT", -CONTENT_RIGHT, -HEAD.subY); headerSub:SetJustifyH("LEFT"); headerSub:SetWordWrap(false)
    moduleSwitch = UI.BuildToggleControl(contentHeader, nil, CurrentModuleOn, SetCurrentModuleOn, HEAD.switchW, HEAD.switchH)
    moduleSwitch:SetPoint("TOPRIGHT", -CONTENT_RIGHT, -HEAD.switchY)
    moduleLabel = ns.Font(contentHeader, HEAD.labelSize, nil, nil, true)
    moduleLabel:SetPoint("RIGHT", moduleSwitch, "LEFT", -HEAD.labelGap, 0)
    ns.Tooltip(moduleSwitch, TEXT_MODULE, TEXT_MODULE_HELP)
    for _, mod in ipairs(MODULES) do
        if #mod.tabs > 1 then
            local bar = TabStrip(contentHeader, mod, ShowPage, WINDOW_W - SIDEBAR_W - CONTENT_X - CONTENT_RIGHT)
            bar:SetPoint("TOPLEFT", contentHeader, "TOPLEFT", CONTENT_X, -(PAGE_HEADER_H - HEAD.tabDrop))
            bar:Hide()
            tabStrips[mod.name] = bar
        end
    end
    tabLine = ns.Solid(window, "ARTWORK", T.line, 1); ns.Hairline(tabLine, "h")
end

local function OnWindowShow(self)
    FitMainWindow()
    if not InCombatLockdown() then
        self:EnableKeyboard(true)
        self:SetPropagateKeyboardInput(true)
    end
    if pendingRefresh then
        pendingRefresh = nil
        InvalidatePages(wrappers)
    end
    ShowPage(currentPage)
    for i = 1, #onShowCallbacks do onShowCallbacks[i]() end
end

local function OnWindowHide()
    if UI.HideWidgetTooltip then UI.HideWidgetTooltip() end
    for i = 1, #onHideCallbacks do onHideCallbacks[i]() end
    ns.HideUnlockMode(true)
end

local function CreateWindow()
    local border = WindowFrame()
    TopBar(border)
    Sidebar()
    ContentHeader()
    scrollFrame = UI.SlimScroll(window, nil, SCROLL_BAR_GAP)
    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(WINDOW_W - SIDEBAR_W - CHILD_ROOM, 1)
    scrollFrame:SetScrollChild(scrollChild)
    Resizable(window, "main", scrollChild, SIDEBAR_W + CHILD_ROOM, WINDOW_W, MIN_WINDOW_H)
    window:SetScript("OnShow", OnWindowShow)
    window:SetScript("OnHide", OnWindowHide)
    FitMainWindow()
    window:Hide()
end

local function PageNamed(pageName)
    if PAGES[pageName] then return pageName end
    local found
    for _, mod in ipairs(MODULES) do
        if mod.name == pageName then return mod.tabs[1].key end
        for _, tab in ipairs(mod.tabs) do
            if tab.name == pageName then found = tab.key break end
        end
    end
    return found
end

function ns.OpenOptionsWindow(pageName)
    if pageName then currentPage = PageNamed(pageName) or currentPage end
    if not window then CreateWindow() end
    if window:IsShown() and pageName then
        ShowPage(currentPage)
    end
    window:Show()
end

function ns.OpenFromOptions(open)
    if not (window and window:IsShown()) then return open() end
    local page = currentPage
    ns.Shared.Parts.OpenWithBack(open, window, function() ns.OpenOptionsWindow(page) end, TEXT_BACK)
end

function ns.StashOptionsWindow()
    if window and window:IsShown() then
        window:Hide()
        return true
    end
    return false
end

function ns.ToggleOptionsWindow(pageName)
    if window and window:IsShown() then
        window:Hide()
    else
        ns.OpenOptionsWindow(pageName)
    end
end

local function ModuleWindowFrame()
    local win = CreateFrame("Frame", nil, UIParent)
    win:Hide()
    win:SetSize(CONTENT_W, MW.h)
    win:SetScale(ns.UIScale())
    win:SetPoint("CENTER")
    win:SetFrameStrata("MEDIUM")
    win:SetToplevel(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    ns.Shared.Parts.Backdrop(win):Paint(1)
    ns.Border(win, ns.Shared.Style.BORDER_RGB)
    if ns.classicSkin then ns.Shared.Parts.ClassicTrim(win) end
    win:SetScript("OnKeyDown", CloseOnEscape)
    return win
end

local function ModuleSwitchTip(mod)
    return function() return ModuleOn(mod) and TEXT_ON or TEXT_OFF end
end

local function ModuleHeader(win, mod)
    local header = CreateFrame("Frame", nil, win)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER_H)
    DragRegion(header, win)
    local title = ns.Font(header, MW.titleSize, nil, ns.classicSkin and T.accent or nil, true)
    title:SetPoint("TOPLEFT", header, "TOPLEFT", MW.titleX, -MW.titleY)
    title:SetText(ns.L(mod.name))
    local sub = ns.Font(header, MW.subSize, nil, T.muted)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", MW.subX, -MW.subGap)
    sub:SetText(ns.L(mod.subtitle))
    local close = ns.Button(header, TEXT_CLOSE, MW.close, MW.close, function() win:Hide() end)
    close:SetPoint("TOPRIGHT", header, "TOPRIGHT", -MW.closeInset, -MW.closeInset)
    local switch = UI.BuildToggleControl(header, header:GetFrameLevel() + MW.switchRaise,
        function() return ModuleOn(mod) end,
        function(v) SetModuleOn(mod, v) end)
    switch:SetPoint("RIGHT", close, "LEFT", -MW.switchGap, 0)
    ns.Tooltip(switch, mod.name, ModuleSwitchTip(mod))
    win.switch = switch
end

local function ModuleBody(win, mod)
    win.tabs = TabStrip(win, mod, function(key) ShowModulePage(win, key) end, CONTENT_W - MW.tabRoom)
    win.tabs:SetPoint("TOPLEFT", win, "TOPLEFT", MW.tabX, -(HEADER_H + MW.tabDrop))
    local offset = HEADER_H + TAB_H
    local line = ns.Solid(win, "ARTWORK", T.line, 1)
    line:SetPoint("TOPLEFT", win, "TOPLEFT", 0, -offset)
    line:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, -offset)
    ns.Hairline(line, "h")
    win.scrollFrame = UI.SlimScroll(win, nil, SCROLL_BAR_GAP)
    win.scrollFrame:SetPoint("TOPLEFT", win, "TOPLEFT", MW.scrollX, -(offset + MW.scrollY))
    win.scrollFrame:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -MW.scrollRight, MW.scrollBottom)
    win.scrollChild = CreateFrame("Frame", nil, win.scrollFrame)
    win.scrollChild:SetSize(CONTENT_W - MW.childRoom, 1)
    win.scrollFrame:SetScrollChild(win.scrollChild)
    Resizable(win, "module:" .. mod.name, win.scrollChild, MW.childRoom, CONTENT_W, MW.minH)
end

local function OnModuleWindowShow(self)
    if not InCombatLockdown() then
        self:EnableKeyboard(true)
        self:SetPropagateKeyboardInput(true)
    end
    if self.pendingRefresh then
        self.pendingRefresh = nil
        InvalidatePages(self.wrappers)
    end
    ShowModulePage(self, self.page)
end

local function OnModuleWindowHide()
    if UI.HideWidgetTooltip then UI.HideWidgetTooltip() end
end

local function CreateModuleWindow(mod)
    local win = ModuleWindowFrame()
    ModuleHeader(win, mod)
    ModuleBody(win, mod)
    win.wrappers = {}
    win.page = mod.tabs[1].key
    win:SetScript("OnShow", OnModuleWindowShow)
    win:SetScript("OnHide", OnModuleWindowHide)
    return win
end

local function ToggleModuleWindow(mod)
    local win = moduleWindows[mod.name]
    if not win then
        win = CreateModuleWindow(mod)
        moduleWindows[mod.name] = win
    end
    win:SetShown(not win:IsShown())
end

local function OpenModule(mod)
    if not Loaded(mod) then return ns.Print(TEXT_SWITCHED_OFF:format(DisplayName(mod))) end
    if mod.open and ns[mod.open] then ns[mod.open]() else ToggleModuleWindow(mod) end
end

O.OpenModule = OpenModule

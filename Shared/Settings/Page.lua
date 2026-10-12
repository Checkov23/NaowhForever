-- Page.lua: draws a declared settings page on the row engine, one card per feature, for the options window (Settings.Render), and the panel a row's cog opens.
local ns = _G.NaowhForever
local Shared = ns.Shared
local Settings, View, Parts = Shared.Settings, Shared.View, Shared.Parts
local SS = Settings.Style

local BORDER_RGB, CARD_GAP, CONTROL_GAP = SS.BORDER_RGB, SS.CARD_GAP, SS.CONTROL_GAP
local PANEL_HEADER, PANEL_PAD = SS.PANEL_HEADER, SS.PANEL_PAD
local COG_W = 380
local TWO_COLUMNS_W = SS.TWO_COLUMNS_W
local DRAG_WAIT = 0.05
local NO_EVENTS = {}
local TEXT_NO_MATCH = ns.L("Nothing on this page matches the search.")

local Draw = {}
local watched = {}
local findLabel, findCard
local cog
local CogDraw = {}

local function Hidden(row)
    local hidden = row.hidden
    if type(hidden) == "function" then hidden = hidden() end
    return hidden
end

local function IsGroup(row)
    return row ~= nil and row.kind == "group"
end

local function KeepRows(rows, card, only)
    for _, row in ipairs(Settings.Rows(card)) do
        local group = row.kind == "group"
        local keep = not Hidden(row) and (not only or group or only[row.label])
        if keep and only and group and IsGroup(rows[#rows]) then
            rows[#rows] = row
        elseif keep then
            rows[#rows + 1] = row
        end
    end
    if only and IsGroup(rows[#rows]) then rows[#rows] = nil end
    return rows
end

local function AddPair(view, row, second, w)
    local half = math.floor(w / 2)
    local top = view.cursor
    local pair = second and second.kind ~= "group" and not second.wide
    view.width = half
    view:Add("setting", row, true)
    if not pair then return 1 end
    view.cursor = top
    view.left, view.width = half, w - half
    view:Add("setting", second, false)
    return 2
end

local function OnlyOf(card, found)
    local only, cogOwner = found ~= true and found or nil, nil
    for _, row in ipairs(only and Settings.Rows(card) or NO_EVENTS) do
        if only[row.label] and row.under ~= nil then
            only[row.under], cogOwner = true, row.under
        elseif only[row.label] and Hidden(row) then
            return nil, cogOwner
        end
    end
    return only, cogOwner
end

local function OpenCardFrame(view)
    view.left, view.width = 0, view:GetWidth()
    local frame = view:Acquire("card")
    frame:SetFrameLevel(view:GetFrameLevel())
    frame.edge:SetColor(BORDER_RGB.r, BORDER_RGB.g, BORDER_RGB.b, 1)
    frame.note:Hide()
    return frame
end

local function FlushSettings(view)
    if ns.UI.sliderDrag then
        C_Timer.After(DRAG_WAIT, view.settingsRedrawFn)
        return
    end
    view.settingsQueued = false
    if view:IsVisible() then
        view.stale = nil
        view:Redraw()
        if view.onResize then view.onResize(view:GetHeight()) end
    else
        view.stale = true
    end
end

local function Watch(store, view)
    local views = watched[store]
    if not views then
        views = {}
        watched[store] = views
        store.OnChange(function()
            for v in pairs(views) do
                if v:IsVisible() then v:QueueSettingsRedraw() else v.stale = true end
            end
        end)
    end
    views[view] = true
end

local function WatchPage(view, page)
    for _, item in ipairs(page and page.items or NO_EVENTS) do
        if item.store then Watch(item.store, view) end
        for _, store in ipairs(item.watch or NO_EVENTS) do Watch(store, view) end
        for _, row in ipairs(item.rowsFn and Settings.Rows(item) or item.rows or NO_EVENTS) do
            if row.store and row.store ~= item.store then Watch(row.store, view) end
        end
    end
end

local function ShownAgain(view)
    if not view.stale then return end
    view.stale = nil
    view:QueueSettingsRedraw()
end

local function PageGone(view)
    if not (cog and cog:IsShown() and cog.page == view) then return end
    C_Timer.After(0, view.goneFn)
end

local function NewView(parent)
    local view = View.New(parent, Settings.kinds, Draw)
    view.settingsRedrawFn = function() FlushSettings(view) end
    view.goneFn = function()
        if cog and cog.page == view and not view:IsVisible() then cog:Hide() end
    end
    view.shownRows = {}
    view:HookScript("OnShow", ShownAgain)
    view:HookScript("OnHide", PageGone)
    return view
end

local function CogShows(card, label)
    return cog and cog:IsShown() and cog.card == card and cog.label == label
end

local function FitCog(height)
    cog:SetHeight(PANEL_HEADER + height + PANEL_PAD)
end

local function CogPanel()
    if cog then return cog end
    for k, v in pairs(Draw) do if CogDraw[k] == nil then CogDraw[k] = v end end
    cog = Parts.Panel("")
    cog:SetFrameStrata("DIALOG")
    cog:SetToplevel(true)
    cog:SetWidth(COG_W)
    cog.view = View.New(cog, Settings.kinds, CogDraw)
    cog.view.settingsRedrawFn = function() FlushSettings(cog.view) end
    cog.view.shownRows = {}
    cog.view.onResize = FitCog
    cog.view:SetPoint("TOPLEFT", PANEL_PAD, -PANEL_HEADER)
    cog.view:SetWidth(COG_W - PANEL_PAD * 2)
    cog:Hide()
    return cog
end

local function OpenCog(icon, setting)
    CogPanel()
    cog.card, cog.label, cog.page = setting.card, setting.label, icon:GetParent():GetParent()
    cog.title:SetText(ns.L((setting.cog and setting.cog.title) or setting.label))
    Watch(setting.card.store, cog.view)
    cog:Show()
    Settings.CogAnchored(icon, setting)
    cog.view:Redraw()
    FitCog(cog.view:GetHeight())
end

local function IsSetting(row)
    return row.setting.label == findLabel and (not findCard or row.setting.card.uid == findCard)
end

local function IsHead(head)
    return (findLabel == nil or head.card.name == findLabel) and (not findCard or head.card.uid == findCard)
end

function Draw:Settings(card, only)
    local w = self:GetWidth()
    local columns = w >= TWO_COLUMNS_W and 2 or 1
    local rows = KeepRows(wipe(self.shownRows), card, only)
    local i = 1
    while i <= #rows do
        local row = rows[i]
        self.left, self.width = 0, w
        if row.kind == "group" then
            self:Add("group", row.group)
            i = i + 1
        elseif row.wide or columns == 1 then
            self:Add("setting", row, false)
            i = i + 1
        else
            i = i + AddPair(self, row, rows[i + 1], w)
            self.left, self.width = 0, w
        end
    end
end

function Draw:CardBody(card, found)
    if card.info then
        for _, line in ipairs(card.rows) do
            if line.group then self:Add("group", line.group) else self:Add("infoLine", line) end
        end
        return
    end
    local only, cogOwner = OnlyOf(card, found)
    if card.studio and self.kinds.studio and not only then self:Add("studio", card) end
    self:Settings(card, only)
    if cogOwner then self:OpenCogOn(card, cogOwner) end
    local changed = Settings.ChangedCount(card)
    if changed > 0 and not only then self:Add("cardFoot", card, changed) end
end

function Draw:Card(card, found)
    local top = self.cursor
    local frame = OpenCardFrame(self)
    local isOpen = (found ~= nil or Settings.IsOpen(card)) and Settings.Openable(card)
    if not isOpen and cog and cog:IsShown() and cog.card == card then cog:Hide() end
    self:Add("cardHead", card, isOpen, found ~= nil)
    if isOpen then self:CardBody(card, found) end
    frame:SetHeight(self.cursor - top)
    self:Space(CARD_GAP)
end

function Draw:Redraw()
    self:Clear()
    local page = Settings.pages[self.pageKey]
    local f = self.filter
    if f and f.all[self.pageKey] then f = nil end
    if page then
        local drawn = false
        for _, item in ipairs(page.items) do
            if not f then
                if item.window then
                    self:Add("window", item)
                    self:Space(CARD_GAP)
                else
                    self:Card(item)
                end
            elseif item.window and f.cards[item.uid] then
                self:Add("window", item)
                self:Space(CARD_GAP)
                drawn = true
            elseif f.cards[item.uid] then
                self:Card(item, f.cards[item.uid])
                drawn = true
            end
        end
        if f and not drawn then self:Note(TEXT_NO_MATCH) end
    end
    self:Fit(NO_EVENTS)
end

function Draw:OpenCogOn(card, label)
    for i = 1, self.pools.setting.used do
        local row = self.pools.setting[i]
        local setting = row.setting
        if setting and setting.card == card and setting.label == label then
            for _, icon in ipairs(row.icons) do
                if icon:IsShown() and icon.spec and icon.spec.cogFor then
                    if not CogShows(card, label) then OpenCog(icon, setting) end
                    return
                end
            end
        end
    end
end

function CogDraw:Redraw()
    self:Clear()
    local w = self:GetWidth()
    if cog.card then
        for _, row in ipairs(Settings.Rows(cog.card)) do
            if row.under == cog.label then
                self.left, self.width = 0, w
                self:Add("setting", row, false)
            end
        end
    end
    self:Fit(NO_EVENTS)
end

function Draw:QueueSettingsRedraw()
    if self.settingsQueued then return end
    self.settingsQueued = true
    C_Timer.After(0, self.settingsRedrawFn)
end

function Settings.Render(parent, pageKey, onResize, filter)
    local view = parent.settingsView
    if not view then
        view = NewView(parent)
        parent.settingsView = view
    end
    view:ClearAllPoints()
    view:SetPoint("TOPLEFT", parent, "TOPLEFT", ns.UI.CONTENT_PAD, -ns.UI.CONTENT_PAD / 2)
    view:SetWidth(math.max(1, parent:GetWidth() - ns.UI.CONTENT_PAD * 2))
    view.pageKey, view.onResize, view.filter = pageKey, onResize, filter
    WatchPage(view, Settings.pages[pageKey])
    view:Show()
    view:Redraw()
    return view:GetHeight() + ns.UI.CONTENT_PAD
end

function Settings.FindRow(parent, label, cardUid)
    local view = parent.settingsView
    if not view then return nil end
    local card = cardUid and label and Settings.CardOf(cardUid)
    local owner = card and Settings.UnderOf(card, label)
    if owner then
        label = owner
        view:OpenCogOn(card, owner)
    end
    findLabel, findCard = label, cardUid
    local row = (label and view:Find("setting", IsSetting)) or view:Find("cardHead", IsHead)
    findLabel, findCard = nil, nil
    if not row then return nil end
    return row, row.top + ns.UI.CONTENT_PAD / 2
end

function Settings.Reveal(cardUid)
    local card = cardUid and Settings.CardOf(cardUid)
    if card then Settings.SetOpen(card, true) end
end

function Settings.CogPanel()
    return cog
end

function Settings.CogAnchored(icon, setting)
    if not CogShows(setting.card, setting.label) then return end
    cog.icon = icon
    cog:ClearAllPoints()
    cog:SetPoint("TOP", icon, "BOTTOM", 0, -CONTROL_GAP)
end

function Settings.ToggleCog(icon, setting)
    if CogShows(setting.card, setting.label) then
        cog:Hide()
        return
    end
    OpenCog(icon, setting)
end

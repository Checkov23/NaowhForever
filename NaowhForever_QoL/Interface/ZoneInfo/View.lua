-- View.lua: Zone Info's themed map summary, pinned details and compact current-zone HUD.
local ns = _G.NaowhForever
local Z = ns.ZoneInfo
local S = ns.QoLSettings
local T = ns.THEME
local Parts, View, St = ns.Shared.Parts, ns.Shared.View, ns.Shared.Style
local WIDTH, HEIGHT, PAD, HEADER = 350, 450, 14, 100
local HOVER_W, HOVER_H = 260, 98
local HUD_W, HUD_H, HUD_ICON, HUD_TEXT_X = 280, 102, 24, 46
local TITLE_SIZE, TEXT_SIZE, SMALL_SIZE = 14, 12, 11
local ROW_TOP, ROW_GAP, ROW_BOTTOM = 8, 5, 9
local BUTTON_W, BUTTON_H, BUTTON_GAP = 100, 24, 8
local MAP_INSET, PANEL_LEVEL, SCROLL_ROOM, HUD_META_Y = 12, 100, 22, 56
local TABS_Y = 64
local MIN_PANEL_H, MIN_PANEL_W, DOCK_GAP = 190, 220, 8
local EMPTY = {}
local OVERVIEW = { { key = "overview", label = "Overview" } }
local BOTH = { OVERVIEW[1], { key = "gathering", label = "Gathering" } }
local TEXT_PIN, TEXT_MARK, TEXT_JOURNAL = ns.L("Pin details"), ns.L("Set waypoint"), ns.L("Open Journal")
local TEXT_DETAILS, TEXT_SETTINGS = ns.L("Details"), ns.L("Zone Info settings")
local TEXT_MARK_HELP = ns.L("Marks this known location on your map.")
local TEXT_FISH = ns.L("Fishing %d / %d reliable")
local TEXT_PINNED = ns.L("Pinned zone")
local TEXT_UNKNOWN, TEXT_SAMPLE_SUBZONE = ns.L("Unknown zone"), ns.L("Sentinel Hill")
local TEXT_MANAGE = ns.L("Manage Zone Info in Map & Pins.")
local hover, panel, hud
local kinds = View.NewKinds()
local Draw = {}

local function MarkClicked(row)
    local e = row.entry
    if not e or not e.map or InCombatLockdown() then return end
    ns.PlaceWaypoint(e.title, e.map, e.x, e.y)
end

local function JournalClicked(row)
    local e = row.entry
    if e and e.dungeon and ns.OpenJournalWindow and not InCombatLockdown() then ns.OpenJournalWindow(e.dungeon) end
end

local function NewRow(view)
    local row = CreateFrame("Frame", nil, view)
    row.title = ns.Font(row, TEXT_SIZE, nil, T.fg, true)
    row.title:SetPoint("TOPLEFT", 0, -ROW_TOP)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(true)
    row.detail = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.detail:SetJustifyH("LEFT")
    row.detail:SetWordWrap(true)
    row.mark = ns.Button(row, TEXT_MARK, BUTTON_W, BUTTON_H, function() MarkClicked(row) end)
    row.journal = ns.Button(row, TEXT_JOURNAL, BUTTON_W, BUTTON_H, function() JournalClicked(row) end)
    ns.Tooltip(row.mark, TEXT_MARK, TEXT_MARK_HELP)
    return row
end

local function SetRow(row, entry)
    row.entry = entry
    row.title:SetWidth(row:GetWidth())
    row.title:SetText(entry.title)
    local color = entry.color or T.fg
    row.title:SetTextColor(color.r, color.g, color.b)
    local h = ROW_TOP + math.ceil(row.title:GetStringHeight())
    row.detail:ClearAllPoints()
    row.detail:SetPoint("TOPLEFT", 0, -h - ROW_GAP)
    row.detail:SetWidth(row:GetWidth())
    row.detail:SetText(entry.detail or "")
    row.detail:SetShown(entry.detail ~= nil)
    if entry.detail then h = h + ROW_GAP + math.ceil(row.detail:GetStringHeight()) end
    row.journal:SetShown(entry.dungeon ~= nil and ns.OpenJournalWindow ~= nil)
    row.mark:SetShown(entry.map ~= nil)
    local blocked = InCombatLockdown()
    row.journal:SetEnabled(not blocked)
    row.mark:SetEnabled(not blocked)
    if entry.dungeon or entry.map then
        h = h + ROW_GAP
        row.journal:ClearAllPoints()
        row.journal:SetPoint("TOPLEFT", 0, -h)
        row.mark:ClearAllPoints()
        local stacked = entry.dungeon and row:GetWidth() < BUTTON_W * 2 + BUTTON_GAP
        if stacked then
            row.mark:SetPoint("TOPLEFT", 0, -h - BUTTON_H - ROW_GAP)
            h = h + BUTTON_H + ROW_GAP
        else
            row.mark:SetPoint("TOPLEFT", entry.dungeon and BUTTON_W + BUTTON_GAP or 0, -h)
        end
        h = h + BUTTON_H
    end
    return h + ROW_BOTTOM
end
kinds.zoneEntry = { New = NewRow, Set = SetRow }

function Draw:Redraw()
    self:Clear()
    for i = 1, self.data.count do
        local e = self.data.rows[i]
        if e.kind == "section" then self:Section(e.title)
        elseif e.kind == "note" then self:Note(e.title)
        else self:Add("zoneEntry", e) end
    end
    self:Fit(EMPTY)
end

local function PickTab(key)
    if not panel then return end
    panel.tab = key
    Z.PaintDetails()
end

local function CloseDetails()
    Z.detached = false
    S.Set("zoneInfoPinned", 0)
    if panel then panel:Hide() end
end

local function DetailsPanel()
    if panel then return panel end
    panel = Parts.Panel("Zone Info", false, 1)
    panel:SetWidth(WIDTH)
    panel:SetHeight(HEIGHT)
    panel:Hide()
    panel.close:SetScript("OnClick", CloseDetails)
    panel.meta = ns.Font(panel, SMALL_SIZE, nil, T.muted)
    panel.meta:SetPoint("TOPLEFT", PAD, -PAD - TITLE_SIZE - ROW_GAP)
    panel.meta:SetPoint("RIGHT", -PAD, 0)
    panel.meta:SetJustifyH("LEFT")
    panel.meta:SetWordWrap(false)
    panel.territory = ns.Font(panel, SMALL_SIZE, nil, T.muted)
    panel.territory:SetPoint("TOPLEFT", PAD, -PAD - TITLE_SIZE - ROW_GAP * 2 - SMALL_SIZE)
    panel.territory:SetPoint("RIGHT", -PAD, 0)
    panel.territory:SetJustifyH("LEFT")
    panel.territory:SetWordWrap(false)
    panel.tabs = Parts.Tabs(panel, WIDTH - PAD * 2, OVERVIEW, PickTab, true)
    panel.tabs:SetPoint("TOPLEFT", PAD, -TABS_Y)
    panel.scroll = ns.UI.SlimScroll(panel)
    panel.scroll:SetPoint("TOPLEFT", PAD, -HEADER)
    panel.scroll:SetPoint("BOTTOMRIGHT", -SCROLL_ROOM, PAD)
    panel.view = View.New(panel.scroll, kinds, Draw)
    panel.view.data = { rows = {}, count = 0 }
    panel.view:SetWidth(WIDTH - PAD - SCROLL_ROOM)
    panel.scroll:SetScrollChild(panel.view)
    panel.tab = "overview"
    return panel
end

function Z.PaintDetails()
    if not (panel and panel:IsShown()) then return end
    local mapID = S.Get("zoneInfoPinned")
    if not Z.MapInfo(mapID) then panel:Hide(); return end
    if not S.Get("zoneInfoGathering") then panel.tab = "overview" end
    Z.Fill(panel.view.data, mapID, panel.tab == "gathering")
    local data = panel.view.data
    panel.title:SetText(data.name)
    panel.meta:SetText((data.range ~= "" and data.range .. " / " or "") .. (data.rating or data.territory or TEXT_PINNED))
    panel.territory:SetText(data.territory or "")
    panel.territory:SetShown(data.territory ~= nil)
    Parts.SetTabs(panel.tabs, S.Get("zoneInfoGathering") and BOTH or OVERVIEW)
    Parts.PaintTabs(panel.tabs, panel.tab)
    panel.view:Redraw()
end

local function Dock(frame, preferred, top)
    local scale = WorldMapFrame:GetEffectiveScale()
    local screenRight = UIParent:GetRight() * UIParent:GetEffectiveScale() / scale
    local rightRoom = screenRight - WorldMapFrame:GetRight() - DOCK_GAP
    local leftRoom = WorldMapFrame:GetLeft() - DOCK_GAP
    local left = rightRoom < MIN_PANEL_W and leftRoom >= MIN_PANEL_W
    local width = math.max(MIN_PANEL_W, math.min(preferred, left and leftRoom or rightRoom))
    frame:ClearAllPoints()
    if left then frame:SetPoint("TOPRIGHT", WorldMapFrame, "TOPLEFT", -DOCK_GAP, -top)
    else frame:SetPoint("TOPLEFT", WorldMapFrame, "TOPRIGHT", DOCK_GAP, -top) end
    frame:SetWidth(width)
    return width
end

function Z.ShowDetails(detached)
    if S.Get("zoneInfoOnMap") then if panel then panel:Hide() end; return end
    local mapID = S.Get("zoneInfoPinned")
    if not Z.MapInfo(mapID) then return end
    local frame = DetailsPanel()
    if frame.map ~= mapID then frame.scroll:SetVerticalScroll(0); frame.map = mapID end
    frame:ClearAllPoints()
    Z.detached = detached == true
    local width = WIDTH
    if Z.detached then
        frame:SetPoint("CENTER", UIParent)
        frame:SetHeight(HEIGHT)
    else
        local canvas = WorldMapFrame:GetCanvasContainer()
        frame:SetParent(WorldMapFrame)
        local top = hover and hover:IsShown() and HOVER_H + DOCK_GAP or 0
        width = Dock(frame, WIDTH, top)
        frame:SetHeight(math.max(MIN_PANEL_H, math.min(HEIGHT, canvas:GetHeight() - MAP_INSET * 2 - top)))
    end
    if Z.detached then frame:SetParent(UIParent) end
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(Z.detached and PANEL_LEVEL or WorldMapFrame:GetCanvas():GetFrameLevel() + PANEL_LEVEL)
    frame:SetWidth(width)
    frame.tabs:SetWidth(width - PAD * 2)
    frame.view:SetWidth(width - PAD - SCROLL_ROOM)
    frame:Show()
    Z.PaintDetails()
end

local function PinHovered()
    if hover and hover.map then Z.Pin(hover.map, false) end
end

function Z.Hover(mapID)
    if S.Get("zoneInfoOnMap") then if hover then hover:Hide() end; return end
    if not mapID then
        if hover and hover:IsShown() then
            hover:Hide()
            if panel and panel:IsShown() and not Z.detached then Z.ShowDetails(false) end
        end
        return
    end
    local info = Z.MapInfo(mapID)
    if not info then return end
    if not hover then
        hover = Parts.Panel("Zone Info", false, 1)
        hover:SetParent(WorldMapFrame)
        hover:SetFrameStrata("DIALOG")
        hover:SetFrameLevel(WorldMapFrame:GetCanvas():GetFrameLevel() + PANEL_LEVEL)
        hover:SetSize(HOVER_W, HOVER_H)
        hover.close:Hide()
        hover.meta = ns.Font(hover, SMALL_SIZE, nil, T.muted)
        hover.meta:SetPoint("TOPLEFT", PAD, -PAD - TITLE_SIZE - ROW_GAP)
        hover.meta:SetPoint("RIGHT", -PAD, 0)
        hover.meta:SetJustifyH("LEFT")
        hover.pin = ns.Button(hover, TEXT_PIN, BUTTON_W, BUTTON_H, PinHovered)
        hover.pin:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    end
    hover.map = mapID
    hover.title:SetText(info.name)
    local range, rating = Z.Levels(mapID)
    hover.meta:SetText(range .. (rating and " / " .. rating or ""))
    Dock(hover, HOVER_W, 0)
    hover:Show()
    if panel and panel:IsShown() and not Z.detached then Z.ShowDetails(false) end
end

function Z.HoverFocused()
    return hover and hover:IsShown() and hover:IsMouseOver()
end

function Z.HideMap()
    Z.HideMapText()
    if hover then hover:Hide() end
    if panel and not Z.detached then panel:Hide() end
end

local function HUDDetails(frame)
    if frame.map and not InCombatLockdown() then Z.Pin(frame.map, (not WorldMapFrame or not WorldMapFrame:IsShown())) end
end

function Z.NewHUD(parent, preview)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(HUD_W, HUD_H)
    frame:SetFrameStrata("MEDIUM")
    frame.backdrop = Parts.HudBackdrop(frame, { alpha = 1 })
    frame.icon = Parts.BarIcon(frame, St.LOGO)
    frame.icon:SetSize(HUD_ICON, HUD_ICON)
    frame.icon:SetPoint("TOPLEFT", PAD, -PAD)
    frame.title = ns.Font(frame, TITLE_SIZE, nil, T.fg, true)
    frame.title:SetPoint("TOPLEFT", HUD_TEXT_X, -PAD)
    frame.title:SetPoint("RIGHT", -PAD, 0)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetWordWrap(false)
    frame.sub = ns.Font(frame, SMALL_SIZE, nil, T.muted)
    frame.sub:SetPoint("TOPLEFT", HUD_TEXT_X, -PAD - TITLE_SIZE - ROW_GAP)
    frame.sub:SetPoint("RIGHT", -PAD, 0)
    frame.sub:SetJustifyH("LEFT")
    frame.sub:SetWordWrap(false)
    frame.detail = ns.Font(frame, SMALL_SIZE, nil, T.muted)
    frame.detail:SetPoint("TOPLEFT", PAD, -HUD_META_Y)
    frame.detail:SetPoint("RIGHT", -PAD, 0)
    frame.detail:SetJustifyH("LEFT")
    frame.button = ns.Button(frame, TEXT_DETAILS, BUTTON_W, BUTTON_H, function() HUDDetails(frame) end)
    frame.button:SetPoint("BOTTOMRIGHT", -PAD, ROW_BOTTOM)
    ns.Tooltip(frame.icon, TEXT_SETTINGS, TEXT_MANAGE)
    if preview then frame.button:EnableMouse(false) end
    return frame
end

function Z.PaintHUD(frame, mapID, preview)
    frame.map = mapID
    local info = Z.MapInfo(mapID)
    frame.title:SetText(info and info.name or TEXT_UNKNOWN)
    local range = Z.Levels(mapID)
    local subzone = preview and TEXT_SAMPLE_SUBZONE or mapID == Z.current and Z.subzone
    frame.sub:SetText(range .. (subzone and subzone ~= "" and " / " .. subzone or ""))
    local fishing = ns.FishingLevels[ns.Shared.Places.SameMap(mapID)]
    local skill = preview and fishing and fishing[2] or Z.fishing
    local text = fishing and S.Get("zoneInfoFishing") and skill and TEXT_FISH:format(skill, fishing[2]) or ""
    frame.detail:SetText(text)
    local color = text == "" and T.muted or skill < fishing[1] and St.TIME_OUT_RGB or skill < fishing[2] and St.TIME_LOW_RGB or St.HAVE_RGB
    frame.detail:SetTextColor(color.r, color.g, color.b)
    frame.button:SetEnabled(not InCombatLockdown())
end

function Z.HUD()
    if not hud then hud = Z.NewHUD(UIParent, false) end
    return hud
end

function Z.RefreshPanels()
    if panel and panel:IsShown() then Z.PaintDetails() end
    if hud and hud:IsShown() then Z.PaintHUD(hud, Z.current) end
end

function Z.HideAll()
    Z.HideMap()
    if panel then panel:Hide() end
    if hud then hud:Hide(); if hud.mover then hud.mover:Hide() end end
end

-- BookTracker.lua: the Library Books tracker: the books still to find in your zone, each with a waypoint.
local ns = _G.NaowhForever

local T = ns.THEME
local Discovery = ns.Discovery
local C = Discovery.C
local S = Discovery.Settings
local L = Discovery.Library
local Style = Discovery.Style
local Parts = ns.Shared.Parts

local HINT, HAND_IN = Style.HINT_RGB, Style.HAND_IN_RGB
local QUIET, GOLD, READY = Style.QUIET_RGB, Style.GOLD_RGB, Style.READY_RGB
local WHITE = { r = 1, g = 1, b = 1 }
local SETTINGS_PAGE = "Discovery/Library Books"
local PLACE = { "RIGHT", "RIGHT", -260, -120 }
local FALLBACK_ZONE = { H = 1413, A = 1436 }
local TURN_INS = { "librarian", "trainer" }
local STORES = { "bags", "bank" }
local OWN_KEYS = { enabled = true, tracker = true, trackerAlways = true, trackerZone = true }
local TEXT_TITLE = ns.L("LIBRARY BOOKS")
local TEXT_BOOKS = ns.L("Library Books")
local TEXT_HANDED_IN = ns.L("%d of %d books handed in")
local TEXT_CLAIMED = ns.L("Claimed")
local TEXT_READY = ns.L("Ready to hand in")
local TEXT_AT_LEVEL = ns.L("At level %d")
local TEXT_TO_GO = ns.L("%d to go")
local TEXT_GOAL = "%s (%d)"
local TEXT_OR = ns.L(" or ")
local TEXT_HAND_IN = ns.L("Hand in to %s, %s")
local TEXT_IN_BAGS = ns.L(" waiting in your bags")
local TEXT_IN_BANK = ns.L(" waiting in your bank")
local TEXT_READY_GOAL = ns.L("%s ready to hand in")
local TEXT_PROGRESS = "%d / %d  %s"
local TEXT_ALL_HANDED = ns.L("%d / %d books handed in")
local TEXT_ONE_BOOK = ns.L("1 book")
local TEXT_N_BOOKS = ns.L("%d books")
local TEXT_IN_YOUR = { bags = ns.L("%s in your bags"), bank = ns.L("%s in your bank") }
local TEXT_NO_MORE = ns.L("No more books in this area.")
local TEXT_TRAINER = ns.L(", mage trainer")
local TEXT_LEVEL = ns.L("Level %d")
local TEXT_COUNT = "(%d)"

local panel, zoneEvents, shownEvents
local dismissedZone, pickedZone, shownZone, lastZone
local redrawQueued
local zoneNames, zoneOrder = {}, {}
local entries, pool, count = {}, {}, 0
local carried = {}
local toFind, doneHere, hereList = {}, {}, {}
local names = {}
local zonesLeft, zonePool, zoneAt = {}, {}, {}

local function SoftBlue(r, g, b)
    local c = ns.ThemeTint("accentSoft", nil)
    if c then return c.r, c.g, c.b end
    return r, g, b
end

local function On()
    return S.Get("enabled") and S.Get("tracker")
end

local function GoalWords(goal, done)
    local now = L.GoalState(goal, done)
    if now == "claimed" then return TEXT_CLAIMED, QUIET end
    if now == "ready" then return TEXT_READY, READY end
    if now == "level" then return TEXT_AT_LEVEL:format(goal.level), GOLD end
    return TEXT_TO_GO:format(goal.books - done), WHITE
end

local function RewardNames(goal)
    wipe(names)
    for _, reward in ipairs(goal.rewards) do
        names[#names + 1] = C_Item.GetItemNameByID(reward[1]) or reward[2]
    end
    return table.concat(names, TEXT_OR)
end

local function AddGoal(goal, done)
    local state, c = GoalWords(goal, done)
    GameTooltip:AddLine(" ")
    local sr, sg, sb = SoftBlue(HINT.r, HINT.g, HINT.b)
    GameTooltip:AddDoubleLine(TEXT_GOAL:format(goal.name, goal.books), state, sr, sg, sb, c.r, c.g, c.b)
    GameTooltip:AddLine(RewardNames(goal), QUIET.r, QUIET.g, QUIET.b, true)
end

local function StoredCounts()
    local bags, bank = 0, 0
    for _, book in ipairs(ns.LibraryBooks) do
        local stored = L.ForMe(book) and L.Stored(book)
        if stored == "bags" then bags = bags + 1 elseif stored == "bank" then bank = bank + 1 end
    end
    return bags, bank
end

local function BarTooltip(bar)
    local done, total = L.Progress()
    GameTooltip:SetOwner(bar, "ANCHOR_LEFT")
    GameTooltip:SetText(TEXT_BOOKS)
    GameTooltip:AddLine(TEXT_HANDED_IN:format(done, total), 1, 1, 1)
    for _, goal in ipairs(ns.LibraryGoals) do AddGoal(goal, done) end
    local librarian = L.Librarian()
    GameTooltip:AddLine(" ")
    local hr, hg, hb = SoftBlue(HAND_IN.r, HAND_IN.g, HAND_IN.b)
    GameTooltip:AddLine(TEXT_HAND_IN:format(librarian.name, librarian.place), hr, hg, hb, true)
    local bags, bank = StoredCounts()
    if bags > 0 then GameTooltip:AddLine(bags .. TEXT_IN_BAGS, GOLD.r, GOLD.g, GOLD.b) end
    if bank > 0 then GameTooltip:AddLine(bank .. TEXT_IN_BANK, GOLD.r, GOLD.g, GOLD.b) end
    GameTooltip:Show()
end

local function Opacity()
    return S.Get("trackerAlpha") or 1
end

local function LoadPosition()
    local pos = S.Get("trackerPos")
    if type(pos) == "table" then return pos.point, pos.relPoint, pos.x, pos.y end
end

local function SavePosition(point, relPoint, x, y)
    S.Set("trackerPos", { point = point, relPoint = relPoint, x = x, y = y })
end

local function Mover(frame, onMoved)
    return ns.UI.AttachMover(frame, TEXT_BOOKS, onMoved, SETTINGS_PAGE, SETTINGS_PAGE .. ":tracker")
end

local function Close()
    dismissedZone = L.PlayerZone()
    panel:Hide()
    if not S.Get("trackerAlways") then return end
    S.Set("trackerAlways", false)
    ns.UI:RefreshPage(true)
end

local function OpenBooks()
    ns.OpenDiscoveryWindow("books")
end

local function PickedZone()
    return pickedZone
end

local function PickZone(id)
    S.Set("trackerZone", id)
end

local function BuildPanel()
    panel = Parts.TrackerPanel(TEXT_TITLE, {
        onTitle = OpenBooks, titleTip = TEXT_BOOKS, titleHint = ns.L("Click to open the Books page."),
        onClose = Close,
        bar = true,
        picker = { values = zoneNames, order = zoneOrder, get = PickedZone, set = PickZone },
        settings = { page = SETTINGS_PAGE, card = "tracker", tip = ns.L("Library Books settings"),
            hint = ns.L("Opens the Library Books tracker's settings.") },
        opacity = Opacity,
        load = LoadPosition, save = SavePosition, place = PLACE,
        mover = Mover,
    })
    panel:SetScale(S.Get("trackerScale"))
    panel.bar:EnableMouse(true)
    panel.bar:SetScript("OnEnter", BarTooltip)
    panel.bar:SetScript("OnLeave", GameTooltip_Hide)
    panel.picker:Hide()
    panel:Place()
    panel:Paint()
    panel:Hide()
end

local function CarriedByTurnIn()
    wipe(carried)
    for _, book in ipairs(ns.LibraryBooks) do
        local stored = L.ForMe(book) and L.Stored(book)
        if stored then
            local key = (book.turnIn or C.TURN_IN) .. "/" .. stored
            carried[key] = (carried[key] or 0) + 1
        end
    end
    return carried
end

local function RenderBar()
    local bar = panel.bar
    local done, total = L.Progress()
    local goal = L.NextGoal()
    if not goal then
        bar:SetMinMaxValues(0, math.max(total, 1))
        bar:SetValue(done)
        bar:SetStatusBarColor(READY.r, READY.g, READY.b, Style.BAR_ALPHA)
        bar.text:SetText(TEXT_ALL_HANDED:format(done, total))
        return
    end
    local ready = L.GoalState(goal, done) == "ready"
    bar:SetMinMaxValues(0, goal.books)
    bar:SetValue(math.min(done, goal.books))
    local c = ready and READY or T.accent
    bar:SetStatusBarColor(c.r, c.g, c.b, Style.BAR_ALPHA)
    bar.text:SetText(ready and TEXT_READY_GOAL:format(goal.name) or TEXT_PROGRESS:format(done, goal.books, goal.name))
end

local function ZoneEntry(zones, id)
    local zone = zoneAt[id]
    if zone then return zone, zones end
    zones = zones + 1
    zone = zonePool[zones] or {}
    zonePool[zones] = zone
    zone[1], zone[2] = id, 0
    zoneAt[id] = zone
    return zone, zones
end

local function ZonesLeft(keep)
    wipe(zoneAt)
    local zones = 0
    for _, book in ipairs(ns.LibraryBooks) do
        local find = L.ToFind(book)
        for _, spot in ipairs(book.spots) do
            local zone
            zone, zones = ZoneEntry(zones, spot[C.SPOT_MAP])
            if find then zone[2] = zone[2] + 1 end
        end
    end
    local n = 0
    for i = 1, zones do
        local zone = zonePool[i]
        if zone[2] > 0 or zone[1] == keep then
            n = n + 1
            zonesLeft[n] = zone
        end
    end
    for i = n + 1, #zonesLeft do zonesLeft[i] = nil end
    return zonesLeft
end

local function Pick(left)
    local saved = S.Get("trackerZone")
    wipe(zoneNames)
    wipe(zoneOrder)
    pickedZone = nil
    for i, z in ipairs(left) do
        zoneNames[z[1]] = L.ZoneName(z[1]) .. "  " .. ns.Color("muted", TEXT_COUNT:format(z[2]))
        zoneOrder[i] = z[1]
        if z[1] == saved then pickedZone = saved end
    end
    pickedZone = pickedZone or left[1][1]
    panel.picker._refreshLabel()
    return pickedZone
end

local function Add(text, color)
    count = count + 1
    local entry = pool[count]
    if entry then wipe(entry) else entry = {}; pool[count] = entry end
    entry.text, entry.color = text, color
    entries[count] = entry
    return entry
end

local function NpcWaypoint(entry)
    L.WaypointNpc(entry.npc)
end

local function BookWaypoint(entry)
    L.WaypointBook(entry.book, entry.spot)
end

local function BookTip(row)
    local book, spot = row.entry.book, row.entry.spot
    GameTooltip:SetText(book.name)
    local c = GetQuestDifficultyColor(book.tier)
    GameTooltip:AddLine(TEXT_LEVEL:format(book.tier), c.r, c.g, c.b)
    if spot[C.SPOT_NOTE] then GameTooltip:AddLine(spot[C.SPOT_NOTE], 1, 1, 1, true) end
    local npc = L.TurnIn(book)
    local hr, hg, hb = SoftBlue(HAND_IN.r, HAND_IN.g, HAND_IN.b)
    GameTooltip:AddLine(TEXT_HAND_IN:format(npc.name, npc.place), hr, hg, hb, true)
end

local function AddCarried()
    CarriedByTurnIn()
    for _, kind in ipairs(TURN_INS) do
        for _, place in ipairs(STORES) do
            local n = carried[kind .. "/" .. place]
            if n then
                local npc = ns.LibraryTurnIns[kind][L.Side()]
                local books = n == 1 and TEXT_ONE_BOOK or TEXT_N_BOOKS:format(n)
                local entry = Add(TEXT_IN_YOUR[place]:format(books), Style.CARRIED_RGB)
                entry.sub = TEXT_HAND_IN:format(npc.name, npc.place)
                entry.npc, entry.waypoint = npc, NpcWaypoint
            end
        end
    end
end

local function AddToFind(listZone)
    L.OnMap(listZone, toFind)
    if #toFind == 0 then Add(TEXT_NO_MORE, T.muted) end
    for _, item in ipairs(toFind) do
        local book, spot = item[1], item[2]
        local sub = L.Where(spot)
        if book.turnIn == "trainer" then sub = sub .. TEXT_TRAINER end
        local entry = Add(book.name)
        entry.sub, entry.book, entry.spot = sub, book, spot
        entry.waypoint, entry.tip = BookWaypoint, BookTip
    end
end

local function Render(zone, left)
    local listZone = left and Pick(left) or zone
    panel.picker:SetShown(left ~= nil)
    count = 0
    AddCarried()
    AddToFind(listZone)
    for _, item in ipairs(L.DoneOnMap(listZone, doneHere)) do
        Add(item[1].name, T.muted).done = true
    end
    for i = count + 1, #entries do entries[i] = nil end
    panel.title:SetText(TEXT_TITLE .. "  " .. ns.Color("muted", L.ZoneName(zone)))
    RenderBar()
    panel:Fit(panel:SetRows(entries))
end

local function Hide()
    shownZone = nil
    if shownEvents then shownEvents:UnregisterAllEvents() end
    if panel then panel:Hide() end
end

local function ZonesForPicker(zone, always)
    local left = zone and always and ZonesLeft(S.Get("trackerZone")) or nil
    if left and #left == 0 then return nil end
    return left
end

local function Refresh()
    if not On() then return Hide() end
    local zone = L.PlayerZone()
    if zone ~= dismissedZone then dismissedZone = nil end
    local here = zone and #L.OnMap(zone, hereList) > 0
    local always = S.Get("trackerAlways")
    local entered = zone ~= lastZone
    lastZone = zone
    if always and here and entered and S.Get("trackerZone") ~= zone then
        S.Set("trackerZone", zone)
        return
    end
    local left = ZonesForPicker(zone, always)
    local stay = panel and panel:IsShown() and shownZone == zone
    local show = zone and not dismissedZone and (always or here or stay)
    if not show then return Hide() end
    if not panel then BuildPanel() end
    Render(zone, left)
    panel:Show()
    shownZone = zone
    shownEvents:RegisterEvent("BAG_UPDATE_DELAYED")
    shownEvents:RegisterEvent("QUEST_TURNED_IN")
end

local function QueuedRefresh()
    redrawQueued = false
    Refresh()
end

local function QueueRefresh()
    if redrawQueued then return end
    redrawQueued = true
    C_Timer.After(C.REFRESH_DELAY, QueuedRefresh)
end

local function Apply()
    if On() then
        if not zoneEvents then
            zoneEvents = CreateFrame("Frame")
            zoneEvents:SetScript("OnEvent", QueueRefresh)
            shownEvents = CreateFrame("Frame")
            shownEvents:SetScript("OnEvent", QueueRefresh)
        end
        zoneEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
        zoneEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    elseif zoneEvents then
        zoneEvents:UnregisterAllEvents()
    end
    Refresh()
end

local function OnSet(key, value)
    if key == "trackerScale" and panel then panel:SetScale(value) end
    if key == "trackerAlpha" and panel then panel:Paint() end
    if not OWN_KEYS[key] then return end
    if key == "trackerAlways" then
        if value then dismissedZone, lastZone = nil, nil else shownZone = nil end
    end
    Apply()
end

local function ShowMover()
    if not On() then return end
    if not panel then BuildPanel() end
    local zone = L.PlayerZone()
    if not zone or #L.OnMap(zone, hereList) == 0 then zone = FALLBACK_ZONE[L.Side()] end
    Render(zone)
    panel.mover:Show()
    panel:Show()
end

local function HideMover()
    if not panel then return end
    panel.mover:Hide()
    Refresh()
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", ShowMover)
hooksecurefunc(ns, "HideUnlockMode", HideMover)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)

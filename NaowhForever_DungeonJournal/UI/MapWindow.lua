-- MapWindow.lua: a dungeon's map in a window beside the Journal: the map, its bosses in a list, the picked boss's page.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local S = J.Settings
local Map = J.DungeonMap
local List = Map.List
local KeyOf, EachBoss = Map.KeyOf, Map.EachBoss
local C = J.C
local St = J.Style
local PANEL_PAD, PANEL_HEADER, FLOOR_H, TEXT_SIZE = St.PANEL_PAD, St.PANEL_HEADER, St.MAP_FLOOR_H, St.TEXT_SIZE

local WINDOW_SCALE = 0.7
local MAP_SHOWN_H = C.MAP_H * WINDOW_SCALE
local MAP_SHOWN_W = C.MAP_W * WINDOW_SCALE
local LIST_W = 210
local LIST_GAP = 10
local LIST_BAR, LIST_BAR_GAP = 4, 4
local LIST_INNER_W = LIST_W - LIST_BAR - LIST_BAR_GAP
local PAGE_W = MAP_SHOWN_W + LIST_GAP + LIST_W
local CARD_INSET = 4
local COPY_W = 52
local STEP_SHRINK = 2
local BUTTON = 20
local BUTTON_ICON = 14
local BUTTON_GAP = 2
local PIN_GAP = 4
local TITLE_GAP = 8
local TITLE_ROOM = St.CLOSE_ROOM + BUTTON * 3 + TITLE_GAP
local NAME_PAD = 4
local JOURNAL_REST = 0.8
local LOWER_GAP = St.BOSS_PAGE_GAP
local LOWER_MIN = 292
local SCROLL_GAP = 16
local UNDER_MAP_GAP = 6
local BESIDE_GAP = 4
local OVER_INSET = 40
local OPEN_TURN = St.OPEN_TURN
local MOVE_BUTTON = "LeftButton"

local TEXT_COPY = ns.L("Copy")
local TEXT_HINT = ns.L("Click a boss for its loot.")
local TEXT_PLACING = ns.L("   PLACING PINS")
local TEXT_PINNED = ns.L("Pinned")
local TEXT_PIN = ns.L("Pin the map")
local TEXT_PINNED_HELP = ns.L("It stays open when the Journal closes. Click to unpin.")
local TEXT_PIN_HELP = ns.L("Keeps it open when the Journal closes.")
local TEXT_OPEN_JOURNAL = ns.L("Open in the Dungeon Journal")
local TEXT_OPEN_HELP = ns.L("Its page: quests, bosses and loot.")
local TEXT_SHOW_PAGE = ns.L("Show the boss's page")
local TEXT_FOLD_PAGE = ns.L("Map and bosses only")
local TEXT_SHOW_PAGE_HELP = ns.L("The picked boss's loot and abilities, under the map.")
local TEXT_FOLD_PAGE_HELP = ns.L("Folds the boss's page away, to keep the map on screen.")

local window, windowView, list, listView, page, lootView
local owners = {}
local firstFound

local function Pinned()
    return ns.AccountSettings().journalMapPinned == true
end

local function Folded()
    return ns.AccountSettings().journalMapFolded == true
end

local function Owner(frame)
    while frame:GetParent() and frame:GetParent() ~= UIParent do frame = frame:GetParent() end
    return frame
end

local function OwnerHidden()
    if not window:IsShown() then return end
    if not Pinned() then
        window:Hide()
        return
    end
    local x, y = window:GetCenter()
    window:ClearAllPoints()
    window:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

local function PlaceBeside(owner)
    local scale = owner:GetEffectiveScale()
    local need = (window:GetWidth() + BESIDE_GAP) * scale
    local right = UIParent:GetRight() * UIParent:GetEffectiveScale() - (owner:GetRight() or 0) * scale
    local left = (owner:GetLeft() or 0) * scale
    if right >= need then
        window:SetPoint("TOPLEFT", owner, "TOPRIGHT", BESIDE_GAP, 0)
    elseif left >= need then
        window:SetPoint("TOPRIGHT", owner, "TOPLEFT", -BESIDE_GAP, 0)
    else
        window:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -OVER_INSET / 2, -OVER_INSET)
    end
end

local function Place(from)
    window:ClearAllPoints()
    local owner = from and Owner(from)
    if not owner then
        window:SetFrameStrata("HIGH")
        window:SetScale(ns.UIScale())
        window:SetPoint("CENTER")
        return
    end
    if not owners[owner] then
        owners[owner] = true
        owner:HookScript("OnHide", OwnerHidden)
    end
    window:SetFrameStrata(owner:GetFrameStrata())
    window:SetScale(owner:GetScale())
    PlaceBeside(owner)
end

local function Paint()
    window.backdrop:Paint(S.Get("mapAlpha") or 1)
end

local function PaintPin(button)
    local color = button:IsMouseOver() and T.fg or Pinned() and T.accent or T.muted
    button.icon:SetVertexColor(color.r, color.g, color.b)
end

local function PinButtonEnter(button)
    PaintPin(button)
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
    GameTooltip:SetText(Pinned() and TEXT_PINNED or TEXT_PIN, 1, 1, 1)
    GameTooltip:AddLine(Pinned() and TEXT_PINNED_HELP or TEXT_PIN_HELP, T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function PinButtonLeave(button)
    PaintPin(button)
    GameTooltip:Hide()
end

local function PinButtonClicked(button)
    ns.AccountSettings().journalMapPinned = not Pinned() or nil
    PinButtonEnter(button)
end

local function FloorLine()
    return #windowView.floors > 1 or Map.placing
end

local function MapFoot()
    return PANEL_HEADER + MAP_SHOWN_H + (FloorLine() and UNDER_MAP_GAP + FLOOR_H or 0)
end

local function PageRoom()
    return window:GetHeight() - MapFoot() - LOWER_GAP - PANEL_PAD
end

local function PinOf(key)
    for i = 1, windowView.used do
        if windowView.pins[i].key == key then return windowView.pins[i] end
    end
end

local function ShowRow(row)
    local top, shown = list:GetVerticalScroll(), list:GetHeight()
    if row.top < top or row.top + List.ROW_H > top + shown then listView:ScrollToRow(list, row) end
end

local function Pick(boss)
    local again = boss == Map.picked
    Map.picked = boss
    windowView:Pick(boss and KeyOf(boss))
    local pool = listView.pools.bossRow
    for i = 1, pool.used do List.PaintRow(pool[i]) end
    local row = boss and List.RowOf(KeyOf(boss))
    if row then ShowRow(row) end
    window.hint:SetShown(boss == nil and not Folded())
    if not boss then
        lootView:Hide()
        return
    end
    lootView:Show()
    if not again then page:SetVerticalScroll(0) end
    lootView.fitHeight = PageRoom()
    lootView:DrawBossPage(boss, windowView.dungeon)
end

local function PageDrawn(height)
    local scrolls = height > PageRoom()
    local want = scrolls and PAGE_W - SCROLL_GAP or PAGE_W
    if math.abs(lootView:GetWidth() - want) < 1 then return end
    page:SetPoint("BOTTOMRIGHT", -(PANEL_PAD + (scrolls and SCROLL_GAP or 0)), PANEL_PAD)
    lootView:SetWidth(want)
    lootView:Redraw()
end

local function Size(owner)
    local folded = Folded()
    local foot = MapFoot()
    page:SetShown(not folded)
    window.hint:SetShown(not folded and Map.picked == nil)
    window.fold:SetRotation(folded and 0 or OPEN_TURN)
    page:SetPoint("TOPLEFT", PANEL_PAD, -(foot + LOWER_GAP))
    if folded then
        window:SetHeight(foot + PANEL_PAD)
    else
        window:SetHeight(owner and owner:GetHeight() or foot + LOWER_GAP + LOWER_MIN)
    end
end

local function WindowDrawn()
    Size(window.owner)
    local down = List.Draw()
    window.title:SetText(windowView.dungeon.name:upper() .. down
        .. (Map.placing and ns.Color("muted", TEXT_PLACING) or ""))
    window.copy:SetShown(Map.placing)
    local picked = Map.picked
    if not picked then return end
    local row = List.RowOf(KeyOf(picked))
    if row then ShowRow(row) end
    if not Folded() then PageDrawn(lootView:GetHeight()) end
end

local function OpenJournalPage()
    if windowView.dungeon then ns.OpenJournalWindow(windowView.dungeon) end
end

local function JournalEnter(button)
    if button.icon then button.icon:SetAlpha(1) end
    window.title:SetTextColor(T.accent.r, T.accent.g, T.accent.b)
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
    GameTooltip:SetText(TEXT_OPEN_JOURNAL, 1, 1, 1)
    GameTooltip:AddLine(TEXT_OPEN_HELP, T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Show()
end

local function JournalLeave(button)
    if button.icon then button.icon:SetAlpha(JOURNAL_REST) end
    window.title:SetTextColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    GameTooltip:Hide()
end

local function FoldEnter(button)
    button.icon:SetVertexColor(T.fg.r, T.fg.g, T.fg.b)
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
    GameTooltip:SetText(Folded() and TEXT_SHOW_PAGE or TEXT_FOLD_PAGE, 1, 1, 1)
    GameTooltip:AddLine(Folded() and TEXT_SHOW_PAGE_HELP or TEXT_FOLD_PAGE_HELP, T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function FoldLeave(button)
    button.icon:SetVertexColor(T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Hide()
end

local function FoldClicked(button)
    ns.AccountSettings().journalMapFolded = not Folded() or nil
    WindowDrawn()
    if not Folded() then Pick(Map.picked) end
    FoldEnter(button)
end

local function WindowPicked(boss)
    if not Folded() then return Pick(boss) end
    Map.lootFrom = windowView
    windowView:Pick(KeyOf(boss))
    J.View.OpenBossLoot(boss, windowView.dungeon)
end

local function WindowHidden()
    Map.ViewHidden(windowView)
end

local function CopyClicked()
    Map.Copy(windowView.dungeon)
end

local function StartMoving()
    window:StartMoving()
end

local function StopMoving()
    window:StopMovingOrSizing()
end

local ListMixin = {}

function ListMixin:Redraw()
    if windowView.dungeon then List.Draw() end
end

local function IconButton(texture, onEnter, onLeave, onClick)
    local button = CreateFrame("Button", nil, window)
    button:SetSize(BUTTON, BUTTON)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(texture, nil, nil, "TRILINEAR")
    button.icon:SetSize(BUTTON_ICON, BUTTON_ICON)
    button.icon:SetPoint("CENTER")
    button:SetScript("OnEnter", onEnter)
    button:SetScript("OnLeave", onLeave)
    button:SetScript("OnClick", onClick)
    return button
end

local function BuildFrame()
    window = J.View.Parts.Panel("", true)
    window:SetSize(PAGE_W + PANEL_PAD * 2, PANEL_HEADER + MAP_SHOWN_H + PANEL_PAD)
    window.backdrop:Card(CARD_INSET, PANEL_HEADER, CARD_INSET, CARD_INSET)
    window.title:SetTextColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    window:SetToplevel(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    ns.AllowOffscreen(window)
    window:RegisterForDrag(MOVE_BUTTON)
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
end

local function BuildMap()
    windowView = Map.NewView(window, window, true)
    Map.windowView = windowView
    window:HookScript("OnHide", WindowHidden)
    windowView.scale = WINDOW_SCALE
    windowView.onDraw = WindowDrawn
    local canvas = windowView.canvas
    canvas:SetScale(WINDOW_SCALE)
    canvas:SetPoint("TOPLEFT", PANEL_PAD / WINDOW_SCALE, -PANEL_HEADER / WINDOW_SCALE)
    local underMap = -(PANEL_HEADER + MAP_SHOWN_H + UNDER_MAP_GAP)
    windowView.down:SetPoint("TOPLEFT", PANEL_PAD, underMap)
    window.copy = ns.Button(window, TEXT_COPY, COPY_W, FLOOR_H - STEP_SHRINK, CopyClicked)
    window.copy:SetPoint("TOPLEFT", PANEL_PAD + MAP_SHOWN_W - COPY_W, underMap)
    windowView.onPick = WindowPicked
    windowView.onPinHover = Map.Light
end

local function BuildList()
    list = ns.UI.SlimScroll(window, LIST_BAR, LIST_BAR_GAP)
    list:SetPoint("TOPLEFT", PANEL_PAD + MAP_SHOWN_W + LIST_GAP, -PANEL_HEADER)
    list:SetSize(LIST_INNER_W, MAP_SHOWN_H)
    listView = ns.Shared.View.New(list, List.Kinds, ListMixin)
    Map.listView = listView
    listView:SetWidth(LIST_INNER_W)
    list:SetScrollChild(listView)
end

local function BuildPage()
    page = ns.UI.SlimScroll(window)
    page:SetPoint("BOTTOMRIGHT", -PANEL_PAD, PANEL_PAD)
    lootView = J.View.New(page)
    lootView:SetWidth(PAGE_W)
    lootView.onResize = PageDrawn
    page:SetScrollChild(lootView)
    window.hint = ns.Font(window, TEXT_SIZE, nil, T.muted)
    window.hint:SetPoint("CENTER", page, "CENTER", 0, 0)
    window.hint:SetText(TEXT_HINT)
end

local function BuildButtons()
    local fold = IconButton(St.ARROW, FoldEnter, FoldLeave, FoldClicked)
    fold.icon:SetVertexColor(T.muted.r, T.muted.g, T.muted.b)
    window.fold = fold.icon
    local pin = IconButton(St.PIN, PinButtonEnter, PinButtonLeave, PinButtonClicked)
    pin:SetPoint("RIGHT", window.close, "LEFT", -PIN_GAP, 0)
    PaintPin(pin)
    window.pin = pin
    fold:SetPoint("RIGHT", pin, "LEFT", -BUTTON_GAP, 0)
    local journal = IconButton(St.LOGO_SMALL, JournalEnter, JournalLeave, OpenJournalPage)
    journal:SetPoint("RIGHT", fold, "LEFT", -BUTTON_GAP, 0)
    journal.icon:SetAlpha(JOURNAL_REST)
end

local function BuildName()
    window.title:SetPoint("RIGHT", -TITLE_ROOM, 0)
    local name = CreateFrame("Button", nil, window)
    name:SetPoint("TOPLEFT", window.title, "TOPLEFT", -NAME_PAD, NAME_PAD)
    name:SetPoint("BOTTOMRIGHT", window.title, "BOTTOMRIGHT", 0, -NAME_PAD)
    name:RegisterForDrag(MOVE_BUTTON)
    name:SetScript("OnDragStart", StartMoving)
    name:SetScript("OnDragStop", StopMoving)
    name:SetScript("OnEnter", JournalEnter)
    name:SetScript("OnLeave", JournalLeave)
    name:SetScript("OnClick", OpenJournalPage)
end

local function Build()
    BuildFrame()
    BuildMap()
    BuildList()
    BuildPage()
    BuildButtons()
    BuildName()
end

local function FindFirst(boss, number)
    if not firstFound and number and not (windowView.inside and J.Kills.ThisRun(boss)) then firstFound = boss end
end

local function FirstToGo(dungeon)
    firstFound = nil
    EachBoss(dungeon, FindFirst)
    return firstFound
end

local function ShowDungeon(dungeon)
    windowView:Open(dungeon)
    Size(window.owner)
    Map.picked = nil
    windowView:Draw()
    if not Folded() then Pick(FirstToGo(dungeon)) end
end

local function SettingChanged(key)
    if key == "enabled" and not S.Get("enabled") then
        if window then window:Hide() end
    elseif key == "mapAlpha" and window then
        Paint()
    elseif window and window:IsShown() then
        windowView:Draw()
        if Map.picked and not Folded() then lootView:QueueRedraw() end
    end
end

function Map.Light(key, on)
    local pin = PinOf(key)
    if pin then pin.glow:SetShown(on) end
    local row = List.RowOf(key)
    if not row then return end
    row.lit = on
    List.PaintRow(row)
end

function Map.WindowShown()
    return window ~= nil and window:IsShown()
end

function Map.RedrawPlacing()
    if not Map.WindowShown() then return end
    windowView:FillFloors()
    windowView:Draw()
end

function J.OpenDungeonMap(dungeon, from)
    if not J.Maps[dungeon.key] then return end
    local owner = from and Owner(from)
    if owner and owner.onWorldMap then return J.ShowMapOnWorldMap(dungeon) end
    if not window then Build() end
    if window:IsShown() and windowView.dungeon == dungeon then
        window:Hide()
        return
    end
    Paint()
    Place(from)
    window.owner = from and Owner(from)
    window:Show()
    window:Raise()
    ShowDungeon(dungeon)
end

function J.FollowDungeonMap(view, dungeon)
    if not Map.WindowShown() or windowView.dungeon == dungeon then return end
    if not window.owner or Owner(view) ~= window.owner then return end
    if not J.Maps[dungeon.key] then
        window:Hide()
        return
    end
    ShowDungeon(dungeon)
end

function J.DrawDungeonMap()
    if Map.WindowShown() then windowView:Draw() end
end

S.OnChange(SettingChanged)

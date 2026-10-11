-- MapPanel.lua: the Dungeon Journal beside the world map: a dungeon's page inside one, a faction's in its zone.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local S = J.Settings
local St = J.Style
local PANEL_W, PANEL_PAD, PANEL_HEADER = St.PANEL_W, St.PANEL_PAD, St.PANEL_HEADER

local SCROLL_GAP = 20
local PANEL_LEVEL = 100
local CARD_INSET = 4
local VIEW_TOP = 4
local BUTTON_W, BACK_W, BUTTON_H = 90, 50, 20
local BUTTON_GAP = 6
local BESIDE_GAP = 4
local INSIDE_RIGHT, INSIDE_TOP, INSIDE_BOTTOM = 8, 70, 8
local SCREEN_ROOM = 8
local QUEST_LOG = "questLogOpen"
local QUEST_LOG_SHOWN, QUEST_LOG_FOLDED = "1", "0"

local TEXT_TITLE = ns.L("DUNGEON JOURNAL")
local TEXT_OTHER_HALF = ns.L("Other half")
local TEXT_OTHER_FACTION = ns.L("Other faction")
local TEXT_BACK = ns.L("Back")
local TEXT_MY_CLASS = ns.L("My class")
local TEXT_ALL_CLASSES = ns.L("All classes")

local panel, view
local hooked, waitingForMap = false, false
local placeQueued = false
local pages, pagesAreFactions, shownIndex = nil, false, 1
local factionsHere = {}
local shownBoss
local folder

local function On()
    return S.Get("enabled") and (S.Get("mapPanel") or S.Get("mapFactions"))
end

local function DrawShown()
    local page = pages[shownIndex]
    if pagesAreFactions then
        view:DrawFaction(page)
    elseif shownBoss then
        view:DrawBossLoot(shownBoss, page)
    else
        view:Draw(page)
    end
    J.ShowMapOnWorldMap(not pagesAreFactions and page or nil)
end

local function OtherHalf()
    if not pages then return end
    shownIndex = shownIndex % #pages + 1
    shownBoss = nil
    J.UnpickOnWorldMap()
    DrawShown()
    panel.scroll:SetVerticalScroll(0)
end

local function Back()
    J.ShowBossBesideMap(nil)
    J.UnpickOnWorldMap()
end

local function ToggleClass()
    S.Set("usableOnly", not S.Get("usableOnly"))
end

local function Paint()
    panel.backdrop:Paint(S.Get("mapAlpha") or 1)
end

local function Widen(wide)
    local gap = wide and 0 or SCROLL_GAP
    panel.scroll:SetPoint("BOTTOMRIGHT", -PANEL_PAD - gap, PANEL_PAD)
    view:SetWidth(PANEL_W - PANEL_PAD * 2 - gap)
    if panel:IsShown() then view:Redraw() end
end

local function Narrow()
    Widen(false)
end

local function WidenAll()
    Widen(true)
end

local function BuildButtons()
    panel.switch = ns.Button(panel, TEXT_OTHER_HALF, BUTTON_W, BUTTON_H, OtherHalf)
    panel.switch:SetPoint("RIGHT", panel.close, "LEFT", -BUTTON_GAP, 0)
    panel.classOnly = ns.Button(panel, "", BUTTON_W, BUTTON_H, ToggleClass)
    panel.back = ns.Button(panel, TEXT_BACK, BACK_W, BUTTON_H, Back)
    panel.back:SetPoint("RIGHT", panel.classOnly, "LEFT", -BUTTON_GAP, 0)
end

local function Build()
    panel = J.View.Parts.Panel(TEXT_TITLE, true)
    panel.onWorldMap = true
    panel.backdrop:Card(CARD_INSET, PANEL_HEADER, CARD_INSET, CARD_INSET)
    panel.title:SetTextColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    BuildButtons()
    local scroll = ns.UI.SlimScroll(panel)
    scroll:SetPoint("TOPLEFT", PANEL_PAD, -PANEL_HEADER - VIEW_TOP)
    view = J.View.New(scroll)
    view.onWorldMap = true
    scroll:SetScrollChild(view)
    panel.scroll = scroll
    Widen(true)
    scroll.bar:HookScript("OnShow", Narrow)
    scroll.bar:HookScript("OnHide", WidenAll)
end

local function Place()
    local map = WorldMapFrame
    panel:SetFrameStrata(map:GetFrameStrata())
    panel:SetFrameLevel(map:GetFrameLevel() + PANEL_LEVEL)
    panel:SetScale(ns.UIScale())
    panel:ClearAllPoints()
    local mapRight = (map:GetRight() or 0) * map:GetEffectiveScale()
    local screenRight = UIParent:GetRight() * UIParent:GetEffectiveScale()
    if screenRight - mapRight >= (PANEL_W + SCREEN_ROOM) * panel:GetEffectiveScale() then
        panel:SetPoint("TOPLEFT", map, "TOPRIGHT", BESIDE_GAP, 0)
        panel:SetPoint("BOTTOMLEFT", map, "BOTTOMRIGHT", BESIDE_GAP, 0)
    else
        panel:SetPoint("TOPRIGHT", map, "TOPRIGHT", -INSIDE_RIGHT, -INSIDE_TOP)
        panel:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", -INSIDE_RIGHT, INSIDE_BOTTOM)
    end
end

local function PaintButtons()
    local two = #pages > 1
    panel.switch:SetShown(two)
    ns.SetButtonText(panel.switch, pagesAreFactions and TEXT_OTHER_FACTION or TEXT_OTHER_HALF)
    panel.classOnly:ClearAllPoints()
    panel.classOnly:SetPoint("RIGHT", two and panel.switch or panel.close, "LEFT", -BUTTON_GAP, 0)
    ns.SetButtonText(panel.classOnly, S.Get("usableOnly") and TEXT_MY_CLASS or TEXT_ALL_CLASSES)
    panel.back:SetShown(shownBoss ~= nil)
end

local function Pick()
    pages, pagesAreFactions = nil, false
    if not (On() and WorldMapFrame:IsShown()) then return end
    local here = S.Get("mapPanel") and J.Current()
    if here then
        pages = here
    elseif S.Get("mapFactions") and #J.FactionsHere(factionsHere) > 0 then
        pages, pagesAreFactions = factionsHere, true
    end
end

local function Refresh()
    Pick()
    if not pages then
        if panel then panel:Hide() end
        J.ShowMapOnWorldMap(nil)
        return
    end
    if not panel then Build() end
    if shownIndex > #pages then shownIndex = 1 end
    Paint()
    PaintButtons()
    Place()
    panel:Show()
    DrawShown()
    panel.scroll:SetVerticalScroll(0)
end

local function Hide()
    shownBoss = nil
    if panel then panel:Hide() end
    J.ShowMapOnWorldMap(nil)
end

local function MapResized()
    if panel and panel:IsShown() then Place() end
    J.FitMapOnWorldMap()
end

local function PlaceAfterMove()
    placeQueued = false
    if panel and panel:IsShown() then Place() end
end

local function MapMoved()
    if placeQueued or not (panel and panel:IsShown()) then return end
    placeQueued = true
    C_Timer.After(0, PlaceAfterMove)
end

local function FoldQuestLog()
    if InCombatLockdown() then
        if folder then folder:RegisterEvent("PLAYER_REGEN_ENABLED") end
        return
    end
    if folder then folder:UnregisterEvent("PLAYER_REGEN_ENABLED") end
    local account = ns.AccountSettings()
    if On() and S.Get("mapPanel") and J.Current() then
        if account.journalQuestLogWas == nil then
            account.journalQuestLogWas = GetCVar(QUEST_LOG) or QUEST_LOG_SHOWN
            SetCVar(QUEST_LOG, QUEST_LOG_FOLDED)
        end
    elseif account.journalQuestLogWas ~= nil then
        SetCVar(QUEST_LOG, account.journalQuestLogWas)
        account.journalQuestLogWas = nil
    end
end

local function MapShown()
    J.WindowAwayForMap(true)
    Refresh()
end

local function MapHidden()
    Hide()
    J.WindowAwayForMap(false)
end

local function MapChanged()
    if not (panel and panel:IsShown()) then return end
    local away = J.DungeonMapAway()
    J.WorldMapChanged()
    if J.DungeonMapAway() == away then return end
    if shownBoss and J.DungeonMapAway() then
        shownBoss = nil
        PaintButtons()
        view:Draw(pages[shownIndex])
    else
        view:Redraw()
    end
end

local function Hook()
    if hooked then return end
    hooked = true
    folder = CreateFrame("Frame")
    folder:SetScript("OnEvent", FoldQuestLog)
    WorldMapFrame:HookScript("OnShow", MapShown)
    WorldMapFrame:HookScript("OnHide", MapHidden)
    hooksecurefunc(WorldMapFrame, "OnMapChanged", MapChanged)
    WorldMapFrame:HookScript("OnSizeChanged", MapResized)
    hooksecurefunc(WorldMapFrame, "SetPoint", MapMoved)
    hooksecurefunc(WorldMapFrame, "SetScale", MapMoved)
end

local function HookAndRefresh()
    Hook()
    folder:RegisterEvent("PLAYER_ENTERING_WORLD")
    FoldQuestLog()
    Refresh()
end

local function Sync()
    if folder then
        if On() then folder:RegisterEvent("PLAYER_ENTERING_WORLD") else folder:UnregisterAllEvents() end
    end
    FoldQuestLog()
    if not On() then
        Hide()
        return
    end
    if WorldMapFrame then
        HookAndRefresh()
    elseif not waitingForMap then
        waitingForMap = true
        EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", HookAndRefresh)
    end
end

local function SettingChanged(key)
    if key == "enabled" or key == "mapPanel" or key == "mapFactions" then
        Sync()
        if hooked then Refresh() end
    elseif key == "mapAlpha" then
        if panel then Paint() end
    elseif panel and panel:IsShown() then
        PaintButtons()
        view:Redraw()
    end
end

function J.ShowBossBesideMap(boss)
    if not (panel and panel:IsShown() and pages) or pagesAreFactions then return end
    shownBoss = boss
    PaintButtons()
    DrawShown()
    panel.scroll:SetVerticalScroll(0)
end

S.OnChange(SettingChanged)
hooksecurefunc(ns, "Apply", Sync)

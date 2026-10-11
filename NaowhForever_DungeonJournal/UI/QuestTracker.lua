-- QuestTracker.lua: a dungeon's quests in a small window, one line each (J.QuestTracker).
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local S = J.Settings
local Parts = ns.Shared.Parts
local ID = J.C.QUEST.ID
local St = J.Style
local PANEL_PAD, HEADING_SIZE, SMALL_SIZE = St.PANEL_PAD, St.HEADING_SIZE, St.SMALL_SIZE

local MIN_W, MAX_W = 420, 640
local MIN_MAX_H, SCREEN_SHARE = 420, 0.7
local SHARE_W, SHARE_H = 70, 20
local SHARE_GAP = 4
local NEXT_FRAME = 0
local PLACE = { "RIGHT", "RIGHT", -60, 60 }
local SETTINGS_PAGE = "Dungeon Journal/Quest Tracker"
local EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS" }

local TEXT_TITLE = ns.L("DUNGEON QUEST TRACKER")
local TEXT_TITLE_TIP = ns.L("Dungeon Quest Tracker")
local TEXT_TITLE_HINT = ns.L("Click to open the Dungeon Journal settings.")
local TEXT_SETTINGS_TIP = ns.L("Dungeon Quest Tracker settings")
local TEXT_SETTINGS_HINT = ns.L("Opens the Dungeon Journal's Quest Tracker settings.")
local TEXT_SHARE_ALL = ns.L("Share All")
local TEXT_SHARE = ns.L("Share Quests")
local TEXT_SHARE_HELP = ns.L("Shares your quests for this dungeon with your group, one at a time.")
local TEXT_NO_GROUP = ns.L("You are not in a group.")
local TEXT_NONE = ns.L("None of your quests here can be shared.")
local TEXT_COUNT = ns.L("%d to share.")
local TEXT_RANGE = "%s  %s"

local panel, view
local shown
local lastHere
local measured, measurePool = {}, {}

local Tracker = {}
J.QuestTracker = Tracker

local function Scale()
    return ns.UIScale() * (S.Get("trackerScale") or 1)
end

local function MaxH()
    local screen = (UIParent:GetHeight() or 0) * SCREEN_SHARE / Scale()
    return math.max(MIN_MAX_H, math.floor(screen))
end

local function SavePosition(point, relativePoint, x, y)
    ns.AccountSettings().journalTracker = { point, relativePoint, x, y }
end

local function LoadPosition()
    local saved = ns.AccountSettings().journalTracker
    if type(saved) == "table" then return saved[1], saved[2], saved[3], saved[4] end
end

local function NameWidth(entry)
    local name = entry.name
    if entry.quest and Parts.IsForever("quests", entry.quest[ID]) then
        name = name .. Parts.ForeverInline(SMALL_SIZE, Parts.CARD_DROP)
    end
    panel.measure:SetText(name)
    local w = panel.measure.GetUnboundedStringWidth and panel.measure:GetUnboundedStringWidth()
        or panel.measure:GetStringWidth()
    return math.ceil(w) + 1
end

local function WidthFor(dungeon)
    local widest = 0
    if dungeon.quests then
        for _, entry in ipairs(J.Quests.List(dungeon.quests, measured, measurePool)) do
            widest = math.max(widest, NameWidth(entry))
        end
    end
    return math.max(MIN_W, math.min(MAX_W, J.View.QuestRowWidth(widest) + PANEL_PAD * 2 + panel:ScrollGap()))
end

local function Labels()
    for _, dungeon in ipairs(J.Dungeons()) do
        local range = J.ColoredLevelRange(dungeon)
        panel.dungeonNames[dungeon.key] = range and TEXT_RANGE:format(dungeon.name, range) or dungeon.name
    end
end

local function Draw(dungeon)
    shown = dungeon
    Labels()
    panel.picker._refreshLabel()
    panel:SetTrackerWidth(WidthFor(dungeon))
    view:DrawTracker(dungeon)
end

local function Redraw()
    if panel:IsShown() and shown then Draw(shown) end
end

local function Fit(height)
    if panel:Fit(height) then C_Timer.After(NEXT_FRAME, Redraw) end
end

local function OnEvent()
    local here = J.Current()
    local dungeon = here and here[1]
    if dungeon ~= lastHere then
        lastHere = dungeon
        if dungeon and dungeon ~= shown then Draw(dungeon) end
    end
    Tracker.SyncGameTracker()
end

local function OnShow(frame)
    lastHere = J.Current() and J.Current()[1]
    for _, event in ipairs(EVENTS) do frame:RegisterEvent(event) end
end

local function OnHide(frame)
    frame:UnregisterAllEvents()
    local here = J.Current()
    if here and here[1] == shown then Tracker.closedIn = shown end
    if not here then Tracker.closedOutside = true end
    Tracker.SyncGameTracker()
end

local function Opacity()
    return S.Get("trackerAlpha") or 1
end

local function Paint()
    panel:Paint()
end

local function OpenSettings()
    ns.OpenOptionsWindow(SETTINGS_PAGE)
end

local function NewView(scroll)
    view = J.View.New(scroll)
    view.tracker = true
    return view
end

local function PickedKey()
    return shown and shown.key
end

local function Pick(key)
    Draw(J.Get(key))
end

local function MenuHeight()
    return UIParent:GetHeight()
end

local function ShareAll()
    J.Sharing.ShareAll(shown)
end

local function ShareEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(TEXT_SHARE)
    GameTooltip:AddLine(TEXT_SHARE_HELP, 1, 1, 1, true)
    local count = #J.Sharing.Shareable(shown)
    if not IsInGroup() then
        GameTooltip:AddLine(TEXT_NO_GROUP, T.muted.r, T.muted.g, T.muted.b)
    elseif count == 0 then
        GameTooltip:AddLine(TEXT_NONE, T.muted.r, T.muted.g, T.muted.b)
    else
        GameTooltip:AddLine(TEXT_COUNT:format(count), T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    end
    GameTooltip:Show()
end

local function DungeonsWithQuests()
    local values, order = {}, {}
    for _, dungeon in ipairs(J.Dungeons()) do
        if dungeon.quests and #dungeon.quests.quests > 0 then order[#order + 1] = dungeon.key end
    end
    return values, order
end

local function BuildShare()
    panel.share = ns.Button(panel, TEXT_SHARE_ALL, SHARE_W, SHARE_H, ShareAll)
    panel.share:SetPoint("RIGHT", panel.close, "LEFT", -SHARE_GAP, 0)
    panel.share:HookScript("OnEnter", ShareEnter)
    panel.share:HookScript("OnLeave", GameTooltip_Hide)
end

local function Build()
    local values, order = DungeonsWithQuests()
    panel = Parts.TrackerPanel(TEXT_TITLE, {
        width = MIN_W, titleRoom = SHARE_W + SHARE_GAP, maxHeight = MaxH,
        onTitle = OpenSettings, titleTip = TEXT_TITLE_TIP, titleHint = TEXT_TITLE_HINT,
        picker = { values = values, order = order, get = PickedKey, set = Pick, menuHeight = MenuHeight },
        newBody = NewView,
        settings = { page = SETTINGS_PAGE, card = "quests", tip = TEXT_SETTINGS_TIP, hint = TEXT_SETTINGS_HINT },
        opacity = Opacity,
        load = LoadPosition, save = SavePosition, place = PLACE,
    })
    view.onResize = Fit
    panel.dungeonNames = values
    BuildShare()
    panel.measure = ns.Font(panel, HEADING_SIZE)
    panel.measure:Hide()
    panel:SetScript("OnEvent", OnEvent)
    panel:SetScript("OnShow", OnShow)
    panel:SetScript("OnHide", OnHide)
end

local function OnSettingChanged(key)
    if not panel then return end
    if key == "enabled" and not S.Get("enabled") then
        panel:Hide()
    elseif key == "trackerAlpha" then
        Paint()
    elseif key == "trackerScale" then
        panel:SetScale(Scale())
        Redraw()
    end
end

function Tracker.Show(dungeon)
    if not panel then Build() end
    panel:SetScale(Scale())
    Paint()
    panel:Place()
    panel:Show()
    Draw(dungeon)
    Tracker.SyncGameTracker()
end

function Tracker.IsShown()
    return panel ~= nil and panel:IsShown()
end

function Tracker.Showing()
    return shown
end

function ns.OpenQuestTracker(dungeon)
    if panel and panel:IsShown() and shown == dungeon then
        panel:Hide()
        return
    end
    Tracker.Show(dungeon)
end

S.OnChange(OnSettingChanged)

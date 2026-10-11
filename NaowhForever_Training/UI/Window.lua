-- Window.lua: the Training Planner's window (/nftraining): its cards, title bar, Spells and Builds tabs, drawing.
local ns = _G.NaowhForever

local T = ns.THEME
local UI = ns.UI

local Training = ns.Training
local S = Training.Settings
local Style = Training.Style
local Rows = Training.Rows
local Place = Training.Place
local Spells = Training.Spells
local V = Training.View
local Parts = ns.Shared.Parts

local WIDTH, HEIGHT = 940, 850
local POSITION_KEY = "trainingWindow"
local PAGE = "Training Planner"
local HEADER, FOOTER = Style.WINDOW_HEADER, Style.WINDOW_FOOTER
local CARD_INSET = 6
local INSET = Style.CONTENT_INSET
local BODY_PAD = 14
local TOOL_GAP = 10
local SWITCH_W = 180
local TOP = HEADER + TOOL_GAP + Style.TAB_H + TOOL_GAP
local GAP = 6
local HERO_H = 140
local LABEL_Y = 18
local BAR_W, BAR_H = Style.BAR_W, 6
local ROAD_H = 108
local TRACK_Y = 64
local TRACK_H = 2
local DOT_MAX = Style.DOT_MAX
local YOU_GAP = Style.YOU_GAP
local ROAD_TICKS = { 1, 10, 20, 30, 40, 50, 60 }
local ROAD_TOP = TOP + HERO_H + GAP
local BODY_TOP = ROAD_TOP + ROAD_H + GAP
local ROAD_X = CARD_INSET + INSET + DOT_MAX / 2
local SCROLL_ROOM = 12
local SEARCH_W = 180
local LEARNED_W, BACK_W = 110, 100
local TOOL_SPACE = 8
local MINI_GAP = 6
local LOAD_SETTLE = 0.1
local PERCENT, ROUND = Training.C.PERCENT, Training.C.ROUND
local LINK_GAP = 12
local COST_GAP, COUNT_GAP, COUNT_LIFT = 10, 14, 4
local BAR_GAP, NOTE_GAP = 14, 10
local GOLD_GAP, SIXTY_GAP, SIXTY_TEXT_GAP = 10, 14, 6
local FONT_LABEL, FONT_COUNT, FONT_SIXTY, FONT_GOLD, FONT_COST = 12, 13, 16, 22, 30
local FONT_TICK = 11
local TEXT_TITLE = ns.L("Training Planner")
local TEXT_SUBTITLE = ns.L("%s, level %d")
local TEXT_MINI = ns.L("Mini")
local TIP_MINI = ns.L("Swap the window for a small bar with your next visit and your gold, to leave up while you level. "
    .. "Move it by dragging.")
local TEXT_SPELLS, TIP_SPELLS = "Spells", ns.L("What you can train now and what each level brings.")
local TEXT_BUILDS, TIP_BUILDS = "Builds", ns.L("Talent builds, level by level.")
local TEXT_SEARCH = ns.L("Search spells")
local TEXT_SHOW_LEARNED, TEXT_HIDE_LEARNED = ns.L("Show Learned"), ns.L("Hide Learned")
local TEXT_ALL_LEVELS = ns.L("All Levels")
local TEXT_IMPORT, TIP_IMPORT = ns.L("Import a Build"), ns.L("Paste a build someone shared with you.")
local TEXT_IMPORT_LABEL = ns.L("Import")
local TEXT_PASTE = ns.L("Paste a Naowh Forever talent build")
local TEXT_SAVE, TIP_SAVE = ns.L("Save My Talents"), ns.L("Keep the talents you have now as a build "
    .. "you can export. The game does not keep the order you took them in, so it lists them row by row.")
local TEXT_NAME_TALENTS = ns.L("Name for your current talents")
local TEXT_NEW, TIP_NEW = ns.L("New Build"), ns.L("Start an empty build for the class shown and "
    .. "click its talents in the order they are taken, level by level.")
local TEXT_NAME_BUILD = ns.L("Name the new build")
local TEXT_WAYPOINT = ns.L("Waypoint to nearest trainer")
local TEXT_VISIT = ns.L("NEXT TRAINER VISIT")
local TEXT_GOLD = ns.L("YOUR GOLD")
local TEXT_TO_SIXTY = ns.L("LEFT TO 60")
local TEXT_ROAD = ns.L("YOUR ROAD TO 60")
local TEXT_ROAD_HINT = ns.L("Click a level to see what it brings")
local TEXT_YOU = ns.L("YOU")
local TEXT_NOTHING_LEFT, TEXT_NOTHING_NOTE = ns.L("NOTHING LEFT TO LEARN"), ns.L("You know every spell your class trains")
local TEXT_FOOTER = ns.L("Prices from your trainer")
local WINDOW_EVENTS = { "PLAYER_MONEY", "SPELL_DATA_LOAD_RESULT", "TRAIT_CONFIG_UPDATED" }

local window
local loadQueued = false

local function Text(parent, size, color)
    return Rows.Text(parent, size, nil, color)
end

local function Label(parent, text)
    local fs = Text(parent, FONT_LABEL, T.muted)
    fs:SetText(text)
    return fs
end

local function PaintToggle(btn, on)
    btn._rest = on and T.accent or Style.BORDER_RGB
    btn._border:SetColor(btn._rest.r, btn._rest.g, btn._rest.b, 1)
end

local function Nothing(plan)
    return #plan.now + #plan.rank + #plan.soon + #plan.later + #plan.talent + #plan.ignored == 0
end

local function DrawSpells(plan)
    Spells.DrawHero(plan)
    Spells.DrawRoad(plan)
    window.back:SetShown(V.selected ~= nil)
    local query = strtrim(window.search:GetText() or ""):lower()
    if query ~= "" then return Spells.DrawSearch(plan, query, 0) end
    if V.selected then return Spells.DrawLevel(plan, 0) end
    if Nothing(plan) then return Rows.Header(0, TEXT_NOTHING_LEFT, nil, TEXT_NOTHING_NOTE) end
    return Spells.DrawAll(plan, 0)
end

local function Render()
    if not (window and window:IsShown()) then return end
    Rows.ReleaseAll()
    local plan = Training.Plan()
    local className, classFile = UnitClass("player")
    local color = RAID_CLASS_COLORS[classFile]
    window.subtitle:SetText(TEXT_SUBTITLE:format(color and color:WrapTextInColorCode(className) or className,
        plan.level))
    if V.tab == "builds" then
        V.body:SetHeight(math.max(1, -Training.BuildsView.Draw(plan.level, 0)))
        return
    end
    V.body:SetHeight(math.max(1, -DrawSpells(plan)))
end
V.Render = Render

local function MakeCards()
    local backdrop = window.backdrop
    window.heroCard = backdrop:Card(CARD_INSET, TOP, CARD_INSET, HEIGHT - TOP - HERO_H)
    window.roadCard = backdrop:Card(CARD_INSET, ROAD_TOP, CARD_INSET, HEIGHT - ROAD_TOP - ROAD_H)
    window.bodyCard = backdrop:Card(CARD_INSET, BODY_TOP, CARD_INSET, FOOTER + CARD_INSET)
end

local function BuildHeroRight(hero)
    local goldLabel = Label(hero, TEXT_GOLD)
    goldLabel:SetPoint("TOPRIGHT", -INSET, -LABEL_Y)
    hero.gold = Text(hero, FONT_GOLD)
    hero.gold:SetPoint("TOPRIGHT", goldLabel, "BOTTOMRIGHT", 0, -GOLD_GAP)
    local sixtyLabel = Label(hero, TEXT_TO_SIXTY)
    sixtyLabel:SetPoint("TOPRIGHT", hero.gold, "BOTTOMRIGHT", 0, -SIXTY_GAP)
    hero.sixty = Text(hero, FONT_SIXTY)
    hero.sixty:SetPoint("TOPRIGHT", sixtyLabel, "BOTTOMRIGHT", 0, -SIXTY_TEXT_GAP)
end

local function BuildHero()
    local hero = CreateFrame("Frame", nil, window)
    hero:SetPoint("TOPLEFT", CARD_INSET, -TOP)
    hero:SetPoint("TOPRIGHT", -CARD_INSET, -TOP)
    hero:SetHeight(HERO_H)
    hero.label = Label(hero, TEXT_VISIT)
    hero.label:SetPoint("TOPLEFT", INSET, -LABEL_Y)
    hero.trainer = Parts.Link(hero, function() Training.WaypointToTrainer() end, true)
    Parts.SetLink(hero.trainer, TEXT_WAYPOINT)
    hero.trainer:SetPoint("LEFT", hero.label, "RIGHT", LINK_GAP, 0)
    hero.cost = Text(hero, FONT_COST)
    hero.cost:SetPoint("TOPLEFT", hero.label, "BOTTOMLEFT", 0, -COST_GAP)
    hero.count = Text(hero, FONT_COUNT, T.muted)
    hero.count:SetPoint("BOTTOMLEFT", hero.cost, "BOTTOMRIGHT", COUNT_GAP, COUNT_LIFT)
    hero.track = ns.Solid(hero, "ARTWORK", T.line, 1)
    hero.track:SetSize(BAR_W, BAR_H)
    hero.track:SetPoint("TOPLEFT", hero.cost, "BOTTOMLEFT", 0, -BAR_GAP)
    hero.fill = hero:CreateTexture(nil, "OVERLAY")
    hero.fill:SetPoint("TOPLEFT", hero.track)
    hero.fill:SetHeight(BAR_H)
    hero.note = Text(hero, FONT_LABEL, T.muted)
    hero.note:SetPoint("TOPLEFT", hero.track, "BOTTOMLEFT", 0, -NOTE_GAP)
    BuildHeroRight(hero)
    window.hero = hero
end

local function BuildRoad()
    local road = CreateFrame("Frame", nil, window)
    road:SetPoint("TOPLEFT", ROAD_X, -ROAD_TOP)
    road:SetPoint("TOPRIGHT", -ROAD_X, -ROAD_TOP)
    road:SetHeight(ROAD_H)
    local label = Label(road, TEXT_ROAD)
    label:SetPoint("TOPLEFT", -DOT_MAX / 2, -LABEL_Y)
    local hint = Label(road, TEXT_ROAD_HINT)
    hint:SetPoint("TOPRIGHT", DOT_MAX / 2, -LABEL_Y)
    road.track = ns.Solid(road, "BORDER", T.line, 1)
    road.track:SetPoint("TOPLEFT", 0, -TRACK_Y)
    road.track:SetPoint("TOPRIGHT", 0, -TRACK_Y)
    road.track:SetHeight(TRACK_H)
    road.done = ns.Solid(road, "ARTWORK", T.accent, 1)
    road.done:SetPoint("LEFT", road.track)
    road.done:SetHeight(TRACK_H)
    road.you = Text(road, FONT_TICK, T.accent)
    road.you:SetText(TEXT_YOU)
    for _, level in ipairs(ROAD_TICKS) do
        local tick = Text(road, FONT_TICK, T.muted)
        tick:SetText(level)
        tick:SetPoint("TOP", road.track, "LEFT", (level - 1) / (Training.C.MAX_LEVEL - 1) * (WIDTH - 2 * ROAD_X),
            -(DOT_MAX / 2 + YOU_GAP))
    end
    window.road = road
end

local function ShowCard(card, shown)
    for _, part in ipairs(card) do part:SetShown(shown) end
end

local function SetTab(key)
    V.tab = key
    local spells = key == "spells"
    Parts.PaintTabs(window.switch, key)
    window.hero:SetShown(spells)
    window.road:SetShown(spells)
    ShowCard(window.heroCard, spells)
    ShowCard(window.roadCard, spells)
    window.search:SetShown(spells)
    window.learned:SetShown(spells)
    window.back:SetShown(spells and V.selected ~= nil)
    window.import:SetShown(not spells)
    window.save:SetShown(not spells)
    window.new:SetShown(not spells)
    local top = spells and BODY_TOP or TOP
    window.bodyCard[1]:SetPoint("TOPLEFT", CARD_INSET, -top)
    V.scroll:SetPoint("TOPLEFT", CARD_INSET + BODY_PAD, -(top + BODY_PAD))
end

local function OpacityGet()
    return math.floor((S.Get("windowAlpha") or 1) * PERCENT + ROUND)
end

local function OpacitySet(value)
    S.Set("windowAlpha", value / PERCENT)
end
Training.OpacityGet, Training.OpacitySet = OpacityGet, OpacitySet

local function RedrawTop()
    Render()
    V.scroll:SetVerticalScroll(0)
end

local function ShowBuild(classID, index)
    V.buildClass, V.buildIndex, V.editing = classID, index, false
    Render()
end

local function Import()
    ns.PromptText(TEXT_PASTE, "", 0, function(text) Training.ImportBuild(text, ShowBuild) end)
end

local function SaveTalents()
    ns.PromptText(TEXT_NAME_TALENTS, "", Training.C.BUILD_NAME_MAX, function(name)
        local classID, index = Training.SaveMyTalents(name)
        if classID then ShowBuild(classID, index) end
    end)
end

local function NewBuild()
    ns.PromptText(TEXT_NAME_BUILD, "", Training.C.BUILD_NAME_MAX, function(name)
        local _, _, myClass = UnitClass("player")
        local classID = V.buildClass or myClass
        V.buildClass, V.buildIndex, V.editing = classID, Training.NewBuild(classID, name), true
        Render()
    end)
end

local function ToMini()
    window:Hide()
    S.Set("miniShown", true)
end

local function BuildTitleBar()
    local close = Parts.TitleBar(window, TEXT_TITLE, "", PAGE)
    local opacityIcon, slider = Parts.Opacity(window, close, OpacityGet, OpacitySet)
    window.opacity = slider
    local miniButton = Parts.BarButton(window, Style.LOGO_SMALL, TEXT_MINI, TIP_MINI, ToMini, TEXT_MINI)
    miniButton:SetPoint("RIGHT", opacityIcon, "LEFT", -Style.BAR_GAP - MINI_GAP, 0)
end

local function OnTab(key)
    SetTab(key)
    RedrawTop()
end

local function OnSearch()
    if window:IsShown() then RedrawTop() end
end

local function BuildTools()
    window.switch = Parts.Tabs(window, SWITCH_W, {
        { key = "spells", label = TEXT_SPELLS, tip = TIP_SPELLS },
        { key = "builds", label = TEXT_BUILDS, tip = TIP_BUILDS },
    }, OnTab)
    window.switch:SetPoint("TOPLEFT", CARD_INSET, -(HEADER + TOOL_GAP))
    local toolMiddle = -(HEADER + TOOL_GAP + Style.TAB_H / 2)
    window.search = Parts.SearchBox(window, TEXT_SEARCH, OnSearch)
    window.search:SetSize(SEARCH_W, Style.SEARCH_H)
    window.search:SetPoint("RIGHT", window, "TOPRIGHT", -CARD_INSET, toolMiddle)
    window.learned = ns.Button(window, TEXT_SHOW_LEARNED, LEARNED_W, Style.SEARCH_H, function()
        S.Set("showLearned", not S.Get("showLearned"))
    end)
    window.learned:SetPoint("RIGHT", window.search, "LEFT", -TOOL_SPACE, 0)
    window.back = ns.Button(window, TEXT_ALL_LEVELS, BACK_W, Style.SEARCH_H, function() Spells.Select(nil) end)
    window.back:SetPoint("RIGHT", window.learned, "LEFT", -TOOL_SPACE, 0)
    window.import = Parts.BarButton(window, Style.IMPORT, TEXT_IMPORT, TIP_IMPORT, Import, TEXT_IMPORT_LABEL)
    window.import:SetPoint("RIGHT", window, "TOPRIGHT", -CARD_INSET, toolMiddle)
    window.save = Parts.BarButton(window, Style.WAND, TEXT_SAVE, TIP_SAVE, SaveTalents, TEXT_SAVE)
    window.save:SetPoint("RIGHT", window.import, "LEFT", -Style.BAR_GAP, 0)
    window.new = Parts.BarButton(window, Style.PLUS, TEXT_NEW, TIP_NEW, NewBuild, TEXT_NEW)
    window.new:SetPoint("RIGHT", window.save, "LEFT", -Style.BAR_GAP, 0)
end

local function BuildBody()
    local scroll = UI.SlimScroll(window)
    scroll:SetPoint("TOPLEFT", CARD_INSET + BODY_PAD, -(BODY_TOP + BODY_PAD))
    scroll:SetPoint("BOTTOMRIGHT", -(CARD_INSET + BODY_PAD + SCROLL_ROOM), FOOTER + CARD_INSET + BODY_PAD)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(WIDTH - 2 * (CARD_INSET + BODY_PAD) - SCROLL_ROOM, 1)
    scroll:SetScrollChild(body)
    V.scroll, V.body = scroll, body
end

local function OnShow(self)
    for _, event in ipairs(WINDOW_EVENTS) do self:RegisterEvent(event) end
    self.backdrop:Paint(S.Get("windowAlpha") or 1)
    Render()
end

local function OnHide(self)
    for _, event in ipairs(WINDOW_EVENTS) do self:UnregisterEvent(event) end
end

local function LoadSettled()
    loadQueued = false
    Render()
end

local function OnEvent(_, event, spell, success)
    if event ~= "SPELL_DATA_LOAD_RESULT" then return Render() end
    if not (success and Training.Waiting()) then return end
    Training.Loaded(spell)
    if loadQueued then return end
    loadQueued = true
    C_Timer.After(LOAD_SETTLE, LoadSettled)
end

local function OnDragStop(self)
    self:StopMovingOrSizing()
    Place.Save(self, WIDTH, HEIGHT, POSITION_KEY)
end

local function Build()
    window = Parts.Window(WIDTH, HEIGHT, POSITION_KEY)
    V.window = window
    window:SetScript("OnDragStop", OnDragStop)
    MakeCards()
    BuildTitleBar()
    BuildTools()
    BuildHero()
    BuildRoad()
    BuildBody()
    Parts.FooterBrand(window, PAGE, CARD_INSET)
    Parts.FooterNote(window, TEXT_FOOTER)
    window:HookScript("OnShow", OnShow)
    window:HookScript("OnHide", OnHide)
    window:SetScript("OnEvent", OnEvent)
    SetTab(V.tab)
    window:Hide()
end

local function PaintLearned()
    PaintToggle(window.learned, S.Get("showLearned"))
    ns.SetButtonText(window.learned, S.Get("showLearned") and TEXT_HIDE_LEARNED or TEXT_SHOW_LEARNED)
end

function ns.OpenTrainingWindow(level, tab)
    if not S.Get("enabled") then S.Set("enabled", true) end
    if not window then Build() end
    V.selected = level
    if level then SetTab("spells") elseif tab then SetTab(tab) end
    window:SetScale(ns.UIScale())
    Place.Snap(window, WIDTH, HEIGHT)
    PaintLearned()
    if window:IsShown() then Render() else window:Show() end
end

function ns.ToggleTrainingWindow()
    if window and window:IsShown() then window:Hide() else ns.OpenTrainingWindow() end
end

function NaowhForever_ToggleTraining()
    ns.ToggleTrainingWindow()
end

local function OnSettingChanged(key)
    if key == "enabled" then
        if not S.Get("enabled") and window then window:Hide() end
    elseif key == "windowAlpha" and window then
        window.backdrop:Paint(S.Get("windowAlpha") or 1)
        window.opacity._refreshValue()
    elseif key == "showLearned" and window then
        PaintLearned()
        Render()
    end
end

Training.OnChange(Render)
S.OnChange(OnSettingChanged)

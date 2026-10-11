-- BooksHero.lua: the Library Books card: your books as a road to each reward, and who takes them.
local ns = _G.NaowhForever

local T = ns.THEME
local Discovery = ns.Discovery
local C = Discovery.C
local Parts = ns.Shared.Parts
local Style = Discovery.Style
local Library = Discovery.Library
local V = Discovery.View

local HERO_H = 166
local BAR_H = 4
local SEGMENT_GAP = 2
local YOU_GAP = 4
local DOT, DOT_EDGE = 12, 2
local REWARD, REWARD_GAP = 26, 4
local DOT_LEVEL = 2
local DOT_LABEL_GAP = 3
local REWARD_DROP = 6
local GOAL_GAP, GOAL_DROP = 10, 3
local TRACK_DROP = 26
local PIN_RIGHT = 10
local WHO_GAP = 4
local GREYED_ALPHA = 0.5
local GOAL_STATE = {
    claimed = { ns.L("Handed in"), T.muted }, ready = { ns.L("Ready to hand in"), Style.HAVE_RGB },
    level = { ns.L("Enough books; at level %d"), Style.STORED_RGB }, ahead = { ns.L("%d to go"), T.fg },
}
local TEXT_KICKER = ns.L("FRIEND OF THE LIBRARY")
local TEXT_YOU = ns.L("YOU")
local TEXT_WAYPOINT = ns.L("Waypoint")
local TEXT_PIN_HINT = ns.L("To who takes the books.")
local TEXT_COUNT = "%d / %d"
local TEXT_TO_GO = ns.L("%d to go for %s")
local TEXT_ALL_EARNED = ns.L("Every reward earned")
local TEXT_HAND_TO = ns.L("Hand them to ")
local TEXT_BOOKS = ns.L("%d books")
local TEXT_NEEDS_LEVEL = ns.L("Needs level %d")
local TEXT_REPORTED = ns.L("The book count is what players report; not confirmed yet.")
local TEXT_PICK = ns.L("Pick one of the rewards under it.")

local function LibrarianClicked()
    Library.WaypointNpc(Library.Librarian())
end

local function StateWords(goal, done)
    local state = Library.GoalState(goal, done)
    local words, color = GOAL_STATE[state][1], GOAL_STATE[state][2]
    if state == "level" then words = words:format(goal.level) end
    if state == "ahead" then words = words:format(goal.books - done) end
    return words, color
end

local function DotEnter(dot)
    local goal, done, m = dot.goal, dot.done, T.muted
    GameTooltip:SetOwner(dot, "ANCHOR_TOP")
    GameTooltip:SetText(goal.name, 1, 1, 1)
    GameTooltip:AddLine(TEXT_BOOKS:format(goal.books), m.r, m.g, m.b)
    if goal.level then GameTooltip:AddLine(TEXT_NEEDS_LEVEL:format(goal.level), m.r, m.g, m.b) end
    local words, c = StateWords(goal, done)
    GameTooltip:AddLine(words, c.r, c.g, c.b)
    if goal.reported then GameTooltip:AddLine(TEXT_REPORTED, m.r, m.g, m.b, true) end
    local soft = T.accentSoft
    GameTooltip:AddLine(TEXT_PICK, soft.r, soft.g, soft.b, true)
    GameTooltip:Show()
end

local function RewardEnter(icon)
    GameTooltip:SetOwner(icon, "ANCHOR_TOP")
    GameTooltip:SetItemByID(icon.item)
    GameTooltip:Show()
end

local function Disc(parent, layer, sublevel)
    local tex = parent:CreateTexture(nil, layer, nil, sublevel)
    tex:SetTexture(Style.ROUND, "CLAMP", "CLAMP", "TRILINEAR")
    tex:SetTexelSnappingBias(0)
    tex:SetSnapToPixelGrid(false)
    return tex
end

local function NewDot(hero, goal)
    local dot = CreateFrame("Frame", nil, hero)
    dot:SetSize(DOT, DOT)
    dot:SetFrameLevel(hero:GetFrameLevel() + DOT_LEVEL)
    dot.edge = Disc(dot, "ARTWORK", 1)
    dot.edge:SetAllPoints()
    dot.fill = Disc(dot, "ARTWORK", 2)
    dot.fill:SetPoint("TOPLEFT", DOT_EDGE, -DOT_EDGE)
    dot.fill:SetPoint("BOTTOMRIGHT", -DOT_EDGE, DOT_EDGE)
    dot.goal = goal
    dot:EnableMouse(true)
    dot:SetScript("OnEnter", DotEnter)
    dot:SetScript("OnLeave", GameTooltip_Hide)
    return dot
end

local function NewReward(hero, item)
    local icon = Parts.ItemIcon(hero, REWARD)
    icon.texture:SetTexture(C_Item.GetItemIconByID(item) or C.FALLBACK_ICON)
    icon.item = item
    icon:EnableMouse(true)
    icon:SetScript("OnEnter", RewardEnter)
    icon:SetScript("OnLeave", GameTooltip_Hide)
    return icon
end

local function NewMilestone(hero, goal)
    local m = { goal = goal }
    m.dot = NewDot(hero, goal)
    m.label = ns.Font(hero, Style.KICKER_SIZE, nil, T.muted)
    m.label:SetPoint("TOP", m.dot, "BOTTOM", 0, -DOT_LABEL_GAP)
    m.label:SetText(goal.books)
    m.icons = {}
    for i, reward in ipairs(goal.rewards) do m.icons[i] = NewReward(hero, reward[1]) end
    return m
end

local function NewHeader(hero)
    hero.kicker = ns.Font(hero, Style.KICKER_SIZE, nil, T.accentSoft)
    hero.kicker:SetPoint("TOPLEFT", Style.HERO_PAD, -Style.HERO_TOP)
    hero.kicker:SetText(TEXT_KICKER)
    hero.count = ns.Font(hero, Style.COUNT_SIZE, nil, T.fg)
    hero.count:SetPoint("TOPLEFT", hero.kicker, "BOTTOMLEFT", 0, -Style.COUNT_GAP)
    hero.goal = ns.Font(hero, Style.TEXT_SIZE, nil, T.muted)
    hero.goal:SetPoint("BOTTOMLEFT", hero.count, "BOTTOMRIGHT", GOAL_GAP, GOAL_DROP)
end

local function NewRoad(hero)
    hero.track = CreateFrame("Frame", nil, hero)
    hero.track:SetPoint("TOPLEFT", hero.count, "BOTTOMLEFT", 0, -TRACK_DROP)
    hero.track:SetPoint("RIGHT", -Style.HERO_PAD, 0)
    hero.track:SetHeight(BAR_H)
    hero.segments = {}
    hero.you = ns.Font(hero, Style.SMALL_SIZE, nil, T.accent)
    hero.you:SetText(TEXT_YOU)
    hero.marks = {}
    for i, goal in ipairs(ns.LibraryGoals) do hero.marks[i] = NewMilestone(hero, goal) end
end

local function NewWho(hero)
    hero.pin = Parts.IconButton(hero, LibrarianClicked, Style.PIN, 0, TEXT_WAYPOINT)
    hero.pin.hint = TEXT_PIN_HINT
    hero.pin:SetPoint("TOPRIGHT", -PIN_RIGHT, -Style.HERO_TOP)
    hero.who = ns.Font(hero, Style.SMALL_SIZE, nil, T.muted)
    hero.who:SetPoint("TOPRIGHT", hero.pin, "TOPLEFT", -WHO_GAP, 0)
    hero.who:SetJustifyH("RIGHT")
end

local function NewHero(parent)
    local hero = CreateFrame("Frame", nil, parent)
    ns.Solid(hero, "BACKGROUND", T.fg, Style.CARD_FILL):SetAllPoints()
    ns.Border(hero, Style.BORDER_RGB)
    NewHeader(hero)
    NewRoad(hero)
    NewWho(hero)
    return hero
end

local function Segment(hero, i)
    local seg = hero.segments[i]
    if seg then return seg end
    seg = hero:CreateTexture(nil, "ARTWORK")
    seg:SetHeight(BAR_H)
    hero.segments[i] = seg
    return seg
end

local function SetSegments(hero, done, total, step)
    for i = 1, total do
        local seg = Segment(hero, i)
        seg:ClearAllPoints()
        seg:SetPoint("LEFT", hero.track, "LEFT", (i - 1) * step, 0)
        seg:SetWidth(math.max(1, step - SEGMENT_GAP))
        local c = i <= done and T.accent or T.line
        seg:SetColorTexture(c.r, c.g, c.b, 1)
        seg:Show()
    end
    for i = total + 1, #hero.segments do hero.segments[i]:Hide() end
end

local function DotColors(state)
    if state == "claimed" then return T.line, T.line end
    if state == "ready" or state == "level" then return T.accent, T.accent end
    return T.muted, T.bg
end

local function SetRewards(m, state)
    local n = #m.icons
    local rowW = n * REWARD + (n - 1) * REWARD_GAP
    for i, icon in ipairs(m.icons) do
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", m.label, "BOTTOM", -rowW / 2 + (i - 1) * (REWARD + REWARD_GAP), -REWARD_DROP)
        local grey = state == "claimed" and C_Item.GetItemCount(icon.item, true) <= 0
        icon.texture:SetDesaturated(grey)
        icon.texture:SetAlpha(grey and GREYED_ALPHA or 1)
    end
end

local function SetMilestone(hero, m, done, total, width)
    local x = total > 0 and width * math.min(1, m.goal.books / total) or 0
    m.dot.done = done
    m.dot:ClearAllPoints()
    m.dot:SetPoint("CENTER", hero.track, "LEFT", x, 0)
    local state = Library.GoalState(m.goal, done)
    local edge, inside = DotColors(state)
    m.dot.edge:SetVertexColor(edge.r, edge.g, edge.b, 1)
    m.dot.fill:SetVertexColor(inside.r, inside.g, inside.b, 1)
    V.Paint(m.label, state == "ahead" and T.muted or T.accentSoft)
    SetRewards(m, state)
end

local function SetHeader(hero, done, total)
    local goal = Library.NextGoal()
    hero.count:SetText(TEXT_COUNT:format(done, total))
    hero.goal:SetText(goal and TEXT_TO_GO:format(math.max(0, goal.books - done), goal.name) or TEXT_ALL_EARNED)
    local librarian = Library.Librarian()
    hero.who:SetText(TEXT_HAND_TO .. ns.Color("fg", librarian.name) .. "\n" .. librarian.place)
end

local function SetHero(hero)
    local done, total = Library.Progress()
    SetHeader(hero, done, total)
    local width = hero:GetWidth() - Style.HERO_PAD * 2
    local step = total > 0 and width / total or 0
    SetSegments(hero, done, total, step)
    hero.you:ClearAllPoints()
    hero.you:SetPoint("BOTTOM", hero.track, "LEFT", math.max(0, done * step - SEGMENT_GAP / 2), DOT / 2 + YOU_GAP)
    for _, m in ipairs(hero.marks) do SetMilestone(hero, m, done, total, width) end
    return HERO_H
end

V.Kinds.hero = { New = NewHero, Set = SetHero }
V.RewardEnter = RewardEnter

-- Spells.lua: the Spells tab: the next trainer visit, the road to 60, and the spell lists under them.
local ns = _G.NaowhForever

local T = ns.THEME

local Training = ns.Training
local C = Training.C
local Style = Training.Style
local Rows = Training.Rows
local V = Training.View
local Header, Row, Cards, Take, Paint = Rows.Header, Rows.Row, Rows.Cards, Rows.Take, Rows.Paint

local LEVEL, SPELL = C.ENTRY_LEVEL, C.ENTRY_SPELL
local MAX_LEVEL = C.MAX_LEVEL
local DOT_MIN, DOT_MAX = 10, Style.DOT_MAX
local DOT_EVEN, ROUND = 2, C.ROUND
local DOT_EDGE = 2
local YOU_GAP = Style.YOU_GAP
local RING_GROW = 10
local RING_ALPHA = 0.25
local BAR_W = Style.BAR_W
local MAX_LATER = 12
local STATES = { "now", "rank", "soon", "later", "talent", "ignored" }
local TEXT_LEVEL = ns.L("Level ")
local TEXT_SEE = ns.L("Click to see them.")
local TEXT_DOT_ONE, TEXT_DOT = ns.L("%d spell, %s; %d learned"), ns.L("%d spells, %s; %d learned")
local TEXT_VISIT, TEXT_VISIT_AT = ns.L("NEXT TRAINER VISIT"), ns.L("NEXT TRAINER VISIT, LEVEL ")
local TEXT_NOTHING_LEFT = ns.L("Nothing left to learn")
local TEXT_ONE_SPELL, TEXT_SPELLS = ns.L("1 spell"), ns.L(" spells")
local TEXT_READY = ns.L(" ready to train")
local TEXT_ENOUGH_AT, TEXT_ENOUGH = ns.L("You have enough already, with "), ns.L("Enough for all of it, with ")
local TEXT_SPARE = ns.L(" to spare.")
local TEXT_SHORT = ns.L(" short.")
local TEXT_PANEL_HELPS = ns.L(" The trainer panel learns what you can afford.")
local TEXT_LEVEL_HEAD = ns.L("LEVEL ")
local TEXT_AVAILABLE, TEXT_AVAILABLE_NOTE = ns.L("AVAILABLE NOW"), ns.L("Skip one to leave it out of your totals")
local TEXT_RANK, TEXT_RANK_NOTE = ns.L("NEEDS AN EARLIER RANK"), ns.L("Train the rank before it first")
local TEXT_LEARN_FIRST = ns.L("Learn %s first")
local TEXT_RANK_BEFORE = ns.L("the rank before")
local TEXT_SOON, TEXT_SOON_NOTE = ns.L("COMING SOON"), ns.L("Within %d levels, %s")
local TEXT_LATER, TEXT_LATER_NOTE = ns.L("LATER"), ns.L("Click a level, or a dot above")
local TEXT_MORE_LEVELS = ns.L("and %d more levels on the road above")
local TEXT_TALENT, TEXT_TALENT_NOTE = ns.L("NEEDS A TALENT"), ns.L("Shows up once you take the talent")
local TEXT_SKIPPED, TEXT_SKIPPED_NOTE = ns.L("SKIPPED"), ns.L("Skipping these saves ")
local TEXT_LEARNED, TEXT_LEARNED_NOTE = ns.L("LEARNED"), ns.L("About %s spent")
local TEXT_NO_MATCH, TEXT_NO_MATCH_NOTE = ns.L("NO SPELLS MATCH"), ns.L("Try part of a spell's name")
local TEXT_RESULTS, TEXT_RESULTS_NOTE = ns.L("RESULTS"), ns.L("Learned ones are dimmed")

local Spells = {}
Training.Spells = Spells

local function Select(level)
    V.selected = level
    V.Render()
    V.scroll:SetVerticalScroll(0)
end
Spells.Select = Select

local function DotEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(TEXT_LEVEL .. self.level, 1, 1, 1)
    GameTooltip:AddLine(self.summary, T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:AddLine(TEXT_SEE, T.muted.r, T.muted.g, T.muted.b)
    GameTooltip:Show()
end

local function DotClick(self)
    Select(self.level ~= V.selected and self.level or nil)
end

local function Disc(parent, layer, sublevel)
    local tex = parent:CreateTexture(nil, layer, nil, sublevel)
    tex:SetTexture(Style.ROUND, "CLAMP", "CLAMP", "TRILINEAR")
    tex:SetTexelSnappingBias(0)
    tex:SetSnapToPixelGrid(false)
    return tex
end

local function NewDot()
    local d = CreateFrame("Button", nil, V.window.road)
    d.edge = Disc(d, "ARTWORK", 1)
    d.edge:SetAllPoints()
    d.fill = Disc(d, "ARTWORK", 2)
    d.fill:SetPoint("TOPLEFT", DOT_EDGE, -DOT_EDGE)
    d.fill:SetPoint("BOTTOMRIGHT", -DOT_EDGE, DOT_EDGE)
    d.ring = Disc(d, "BORDER")
    d.ring:SetPoint("CENTER")
    d.ring:SetVertexColor(T.fg.r, T.fg.g, T.fg.b, RING_ALPHA)
    d:SetScript("OnEnter", DotEnter)
    d:SetScript("OnLeave", GameTooltip_Hide)
    d:SetScript("OnClick", DotClick)
    return d
end

local function RoadX(level)
    return (level - 1) / (MAX_LEVEL - 1) * V.window.road:GetWidth()
end

local function DotColors(learned, count, level, plan)
    if learned == count then return T.line, T.line end
    if level <= plan.level then return T.accent, T.accent end
    if level <= plan.level + Training.SOON then return T.accent, T.bg end
    return T.muted, T.bg
end

local function DrawDot(plan, level, group, most)
    local d = Take("dot", NewDot)
    local cost = Training.Total(group)
    local size = DOT_EVEN * math.floor((DOT_MIN + (DOT_MAX - DOT_MIN) * math.sqrt(cost / most)) / DOT_EVEN + ROUND)
    local learned = 0
    for _, entry in ipairs(group) do
        if plan.known[entry[SPELL]] then learned = learned + 1 end
    end
    d.level = level
    d.summary = (#group == 1 and TEXT_DOT_ONE or TEXT_DOT):format(#group, Training.Coins(cost), learned)
    d:SetSize(size, size)
    d:SetPoint("CENTER", V.window.road.track, "LEFT", RoadX(level), 0)
    local edge, inside = DotColors(learned, #group, level, plan)
    d.edge:SetVertexColor(edge.r, edge.g, edge.b, 1)
    d.fill:SetVertexColor(inside.r, inside.g, inside.b, 1)
    d.ring:SetSize(size + RING_GROW, size + RING_GROW)
    d.ring:SetShown(level == V.selected)
end

function Spells.DrawRoad(plan)
    local road = V.window.road
    local most = 1
    for _, group in pairs(plan.byLevel) do most = math.max(most, Training.Total(group)) end
    road.done:SetWidth(math.max(1, RoadX(math.min(plan.level, MAX_LEVEL))))
    for level, group in pairs(plan.byLevel) do DrawDot(plan, level, group, most) end
    road.you:ClearAllPoints()
    road.you:SetPoint("BOTTOM", road.track, "LEFT", RoadX(math.min(plan.level, MAX_LEVEL)), DOT_MAX / 2 + YOU_GAP)
end

function Spells.NextVisit(plan)
    if #plan.now > 0 then return plan.now end
    local first = plan.soon[1] or plan.later[1]
    if not first then return {}, nil end
    local list = {}
    for _, entry in ipairs(plan.soon[1] and plan.soon or plan.later) do
        if entry[LEVEL] == first[LEVEL] then list[#list + 1] = entry end
    end
    return list, first[LEVEL]
end

local function HeroNote(hero, cost, gold, atLevel)
    local enough = gold >= cost
    if cost == 0 then
        hero.note:SetText("")
    elseif enough then
        hero.note:SetText((atLevel and TEXT_ENOUGH_AT or TEXT_ENOUGH) .. Training.Coins(gold - cost) .. TEXT_SPARE)
    else
        hero.note:SetText(Training.Coins(cost - gold) .. TEXT_SHORT .. (atLevel and "" or TEXT_PANEL_HELPS))
    end
    Paint(hero.note, enough and T.muted or Style.WARN_RGB)
end

function Spells.DrawHero(plan)
    local hero = V.window.hero
    local list, atLevel = Spells.NextVisit(plan)
    local cost, gold = Training.Total(list), GetMoney()
    hero.label:SetText(atLevel and (TEXT_VISIT_AT .. atLevel) or TEXT_VISIT)
    hero.cost:SetText(#list > 0 and Training.Coins(cost) or TEXT_NOTHING_LEFT)
    local spells = #list == 1 and TEXT_ONE_SPELL or (#list .. TEXT_SPELLS)
    hero.count:SetText(#list == 0 and "" or atLevel and spells or (spells .. TEXT_READY))
    hero.gold:SetText(Training.Coins(gold))
    hero.sixty:SetText(Training.Coins(Training.ToSixty(plan)))
    local fill = cost > 0 and math.min(1, gold / cost) or 0
    hero.track:SetShown(cost > 0)
    hero.fill:SetWidth(math.max(1, BAR_W * fill))
    hero.fill:SetShown(fill > 0)
    local c = gold >= cost and T.accent or Style.WARN_RGB
    hero.fill:SetColorTexture(c.r, c.g, c.b, 1)
    HeroNote(hero, cost, gold, atLevel)
end

local function States(plan)
    local states = {}
    for _, state in ipairs(STATES) do
        for _, entry in ipairs(plan[state]) do states[entry[SPELL]] = state end
    end
    return states
end

function Spells.DrawLevel(plan, y)
    local group = plan.byLevel[V.selected] or {}
    y = Header(y, TEXT_LEVEL_HEAD .. V.selected, #group, Training.Coins(Training.Total(group)))
    local states = States(plan)
    return Cards(group, y, function(entry) return states[entry[SPELL]] or "learned" end)
end

local function Now()
    return "now"
end

local function LaterGroups(plan)
    local levels, groups = {}, {}
    for _, entry in ipairs(plan.later) do
        if not groups[entry[LEVEL]] then
            groups[entry[LEVEL]] = {}
            levels[#levels + 1] = entry[LEVEL]
        end
        local g = groups[entry[LEVEL]]
        g[#g + 1] = entry
    end
    return levels, groups
end

local function LaterRow(level, group, y)
    local names = {}
    for _, entry in ipairs(group) do names[#names + 1] = C_Spell.GetSpellName(entry[SPELL]) or "" end
    local b = Take("later", Rows.NewLater)
    b:SetPoint("TOPLEFT", V.body, "TOPLEFT", 0, y)
    b:SetPoint("TOPRIGHT", V.body, "TOPRIGHT", 0, y)
    b.level:SetText(TEXT_LEVEL .. level)
    b.names:SetText(table.concat(names, ", "))
    for n, icon in ipairs(b.icons) do
        local entry = group[n]
        icon:SetShown(entry ~= nil)
        icon.edge:SetShown(entry ~= nil)
        if entry then icon:SetTexture(C_Spell.GetSpellTexture(entry[SPELL])) end
    end
    b.price:SetText(Training.Coins(Training.Total(group)))
    b:SetScript("OnClick", function() Select(level) end)
    Rows.Stripe(b)
    return y - Style.ROW_H
end

local function DrawLater(plan, y)
    y = Header(y, TEXT_LATER, nil, TEXT_LATER_NOTE)
    local levels, groups = LaterGroups(plan)
    for i = 1, math.min(#levels, MAX_LATER) do y = LaterRow(levels[i], groups[levels[i]], y) end
    if #levels > MAX_LATER then
        y = Header(y, "", nil, TEXT_MORE_LEVELS:format(#levels - MAX_LATER))
    end
    return y - Style.SECTION_GAP
end

local function DrawRows(plan, state, y, why)
    for _, entry in ipairs(plan[state]) do y = Row(entry, state, y, why(entry)) end
    return y
end

local function RankWhy(entry)
    return TEXT_LEARN_FIRST:format(C_Spell.GetSpellSubtext(entry.needs) or TEXT_RANK_BEFORE)
end

local function LevelWhy(entry)
    return TEXT_LEVEL .. entry[LEVEL]
end

local function NoWhy()
    return nil
end

function Spells.DrawAll(plan, y)
    if #plan.now > 0 then
        y = Header(y, TEXT_AVAILABLE, #plan.now, TEXT_AVAILABLE_NOTE)
        y = Cards(plan.now, y, Now) - Style.SECTION_GAP
    end
    if #plan.rank > 0 then
        y = Header(y, TEXT_RANK, #plan.rank, TEXT_RANK_NOTE)
        y = DrawRows(plan, "rank", y, RankWhy) - Style.SECTION_GAP
    end
    if #plan.soon > 0 then
        y = Header(y, TEXT_SOON, #plan.soon, TEXT_SOON_NOTE:format(Training.SOON, Training.Coins(Training.Total(plan.soon))))
        y = DrawRows(plan, "soon", y, LevelWhy) - Style.SECTION_GAP
    end
    if #plan.later > 0 then y = DrawLater(plan, y) end
    if #plan.talent > 0 then
        y = Header(y, TEXT_TALENT, #plan.talent, TEXT_TALENT_NOTE)
        y = DrawRows(plan, "talent", y, LevelWhy) - Style.SECTION_GAP
    end
    if #plan.ignored > 0 then
        y = Header(y, TEXT_SKIPPED, #plan.ignored, TEXT_SKIPPED_NOTE .. Training.Coins(Training.Total(plan.ignored)))
        y = DrawRows(plan, "ignored", y, NoWhy) - Style.SECTION_GAP
    end
    if Training.Settings.Get("showLearned") and #plan.learned > 0 then
        y = Header(y, TEXT_LEARNED, #plan.learned, TEXT_LEARNED_NOTE:format(Training.Coins(Training.Total(plan.learned))))
        y = DrawRows(plan, "learned", y, LevelWhy)
    end
    return y
end

function Spells.DrawSearch(plan, query, y)
    local states, found = States(plan), {}
    local levels = {}
    for level in pairs(plan.byLevel) do levels[#levels + 1] = level end
    table.sort(levels)
    for _, level in ipairs(levels) do
        for _, entry in ipairs(plan.byLevel[level]) do
            local name = (C_Spell.GetSpellName(entry[SPELL]) or ""):lower()
            if name:find(query, 1, true) then found[#found + 1] = entry end
        end
    end
    if #found == 0 then return Header(y, TEXT_NO_MATCH, nil, TEXT_NO_MATCH_NOTE) end
    y = Header(y, TEXT_RESULTS, #found, TEXT_RESULTS_NOTE)
    return Cards(found, y, function(entry) return states[entry[SPELL]] or "learned" end)
end

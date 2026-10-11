-- MapList.lua: the bosses beside the map window in kill order: each pin's mark, its quests and your BiS there (J.DungeonMap.List).
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Map = J.DungeonMap
local St = J.Style
local PIN, TEXT_SIZE, SMALL_SIZE = St.MAP_PIN, St.TEXT_SIZE, St.SMALL_SIZE
local TAG_WORDS = Map.TAG_WORDS
local NEED_RGB = St.GOLD_NAME_RGB

local LIST_ROW_H = 28
local LIST_SCALE = 0.52
local LIST_BADGE_GROW = 1.2
local ROW_PAD = 4
local ROW_NAME_X = 36
local ROW_TAG_GAP = 5
local ROW_STAR_GAP = 2
local ROW_MARK_GAP = 6
local ROW_ICON = 13
local TAG_SIZE = 9
local WING_SIZE = 9
local WING_H = 20
local WING_BOTTOM = 4
local DOWN_KEY = 100

local TEXT_KILLED = ns.L("Killed this run")
local TEXT_INDENT = "  "
local TEXT_BIS = ns.L("%d of your BiS, %d of them yours")
local TEXT_NOT_PLACED = ns.L("Not on the map yet.")
local TEXT_CLICK = ns.L("Click for its loot.")
local TEXT_BOSSES = ns.L("Bosses")
local TEXT_DOWN = ns.L("   %d of %d down")

local NO_EVENTS = {}
local quests = {}
local wingTexts = {}
local downTexts = {}
local lists, needs = {}, {}
local listsUsed, needsUsed = 0, 0
local matchLower, matchQuest, matchText, matchDone
local drawKilled, drawTotal, drawInside, drawGrouped, lastWing

local List = {}
Map.List = List

local function MatchBoss(boss)
    if not (boss.npc and matchLower:find(boss.name:lower(), 1, true)) then return end
    local need = quests[boss]
    if not need then
        listsUsed = listsUsed + 1
        need = lists[listsUsed] or {}
        lists[listsUsed] = need
        wipe(need)
        quests[boss] = need
    end
    needsUsed = needsUsed + 1
    local entry = needs[needsUsed] or {}
    needs[needsUsed] = entry
    entry[1], entry[2], entry[3] = J.Quests.Name(matchQuest), matchText, matchDone
    need[#need + 1] = entry
end

local function MatchObjectives(dungeon, quest, objectives)
    for _, objective in ipairs(objectives) do
        local text = objective.text
        if text and not issecretvalue(text) and text ~= "" then
            matchLower, matchQuest, matchText, matchDone = text:lower(), quest, text, objective.finished
            Map.EachBoss(dungeon, MatchBoss)
        end
    end
end

local function FillQuests(dungeon)
    wipe(quests)
    listsUsed, needsUsed = 0, 0
    local all = dungeon.quests and dungeon.quests.quests
    if not all then return end
    for _, quest in ipairs(all) do
        local id = J.Quests.LoggedID(quest)
        local objectives = id and C_QuestLog.GetQuestObjectives(id)
        if objectives then MatchObjectives(dungeon, quest, objectives) end
    end
end

local function NeedLines(boss)
    for _, need in ipairs(quests[boss] or NO_EVENTS) do
        GameTooltip:AddLine(need[1], NEED_RGB.r, NEED_RGB.g, NEED_RGB.b)
        local done = need[3]
        GameTooltip:AddLine(TEXT_INDENT .. need[2], done and T.muted.r or 1, done and T.muted.g or 1,
            done and T.muted.b or 1, true)
    end
end

local function RowEnter(row)
    Map.Light(row.key, true)
    local boss = row.boss
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(boss.name, 1, 1, 1)
    local tag = J.BossTag(boss)
    if tag then GameTooltip:AddLine(TAG_WORDS[tag], T.muted.r, T.muted.g, T.muted.b) end
    if row.killed then GameTooltip:AddLine(TEXT_KILLED, St.HAVE_RGB.r, St.HAVE_RGB.g, St.HAVE_RGB.b) end
    NeedLines(boss)
    if row.bis > 0 then
        GameTooltip:AddLine(TEXT_BIS:format(row.bis, row.haveBis), St.BIS_RGB.r, St.BIS_RGB.g, St.BIS_RGB.b)
    end
    if not Map.Spot(Map.windowView.dungeon, row.key) then
        GameTooltip:AddLine(TEXT_NOT_PLACED, T.muted.r, T.muted.g, T.muted.b)
    end
    GameTooltip:AddLine(TEXT_CLICK, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    GameTooltip:Show()
end

local function RowLeave(row)
    Map.Light(row.key, false)
    GameTooltip:Hide()
end

local function RowClicked(row)
    local windowView = Map.windowView
    local spot = Map.Spot(windowView.dungeon, row.key)
    if type(spot) == "table" and spot[1] ~= windowView.floor and windowView:FloorAt(spot[1]) then
        windowView.floor = spot[1]
        windowView:Draw()
    end
    windowView.onPick(row.boss)
end

local function Mark(row, texture)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ROW_ICON, ROW_ICON)
    icon:SetTexture(texture, nil, nil, "TRILINEAR")
    return icon
end

local function NewMark(row)
    row.mark = CreateFrame("Frame", nil, row)
    row.mark:SetSize(PIN, PIN)
    row.mark:SetScale(LIST_SCALE)
    row.mark:SetPoint("LEFT", row, "LEFT", ROW_PAD / LIST_SCALE, 0)
    Map.BuildMark(row.mark)
    row.mark.badge:SetScale(LIST_BADGE_GROW)
end

local function NewText(row)
    row.name = ns.Font(row, TEXT_SIZE, nil, T.fg)
    row.name:SetPoint("LEFT", row, "LEFT", ROW_NAME_X, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.tag = ns.Font(row, TAG_SIZE, nil, T.muted)
    row.tag:SetPoint("LEFT", row.name, "RIGHT", ROW_TAG_GAP, 0)
    row.bisText = ns.Font(row, SMALL_SIZE, nil, T.fg)
    row.bisText:SetPoint("RIGHT", row, "RIGHT", -ROW_PAD, 0)
    row.star = Mark(row, St.STAR)
    row.star:SetVertexColor(St.BIS_RGB.r, St.BIS_RGB.g, St.BIS_RGB.b)
    row.star:SetPoint("RIGHT", row.bisText, "LEFT", -ROW_STAR_GAP, 0)
    row.quest = Mark(row, St.BANG)
end

local function SetRight(row, boss)
    row.bis, row.haveBis = J.Loot.BossBis(boss)
    row.bisText:SetText(row.bis > 0 and row.bis or "")
    row.bisText:SetShown(row.bis > 0)
    row.star:SetShown(row.bis > 0)
    local right = row.bis > 0 and ROW_PAD + math.ceil(row.bisText:GetStringWidth()) + ROW_STAR_GAP + ROW_ICON
        or ROW_PAD - ROW_MARK_GAP
    local needed = quests[boss] ~= nil
    row.quest:SetShown(needed)
    if not needed then return right end
    row.quest:ClearAllPoints()
    row.quest:SetPoint("RIGHT", row, "RIGHT", -(right + ROW_MARK_GAP), 0)
    return right + ROW_MARK_GAP + ROW_ICON
end

local function ListRow(boss, number, key, wing)
    local listView = Map.listView
    if drawGrouped and wing ~= lastWing then
        lastWing = wing
        listView:Add("wing", wing)
    end
    local killed = drawInside and J.Kills.ThisRun(boss) or false
    if number then
        drawTotal = drawTotal + 1
        if killed then drawKilled = drawKilled + 1 end
    end
    listView.rows = listView.rows + 1
    listView:Add("bossRow", boss, number, key, killed)
end

local function CountRow()
    Map.listView.rows = Map.listView.rows + 1
end

local function DownText(killed, total)
    local key = killed * DOWN_KEY + total
    local text = downTexts[key]
    if not text then
        text = ns.Color("muted", TEXT_DOWN:format(killed, total))
        downTexts[key] = text
    end
    return text
end

local function NamedWings(dungeon)
    local named = 0
    for _, wing in ipairs(dungeon.wings) do
        if wing.name then named = named + 1 end
    end
    return named
end

List.Kinds = ns.Shared.View.NewKinds()

List.Kinds.wing = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.text = ns.Font(row, WING_SIZE, nil, T.muted)
        row.text:SetPoint("BOTTOMLEFT", ROW_PAD, WING_BOTTOM)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        return row
    end,
    Set = function(row, wing)
        local text = wingTexts[wing]
        if not text then
            text = wing.name and wing.name:upper() or ""
            wingTexts[wing] = text
        end
        row.text:SetWidth(row:GetWidth() - ROW_PAD)
        row.text:SetText(text)
        return WING_H
    end,
}

List.Kinds.bossRow = {
    New = function(view)
        local row = CreateFrame("Button", nil, view)
        row.hover = ns.Solid(row, "BACKGROUND", T.fg, St.ITEM_HOVER)
        row.hover:SetAllPoints()
        row.fill = ns.Solid(row, "BORDER", T.accent, St.TAB_FILL)
        row.fill:SetAllPoints()
        NewMark(row)
        NewText(row)
        row:SetScript("OnEnter", RowEnter)
        row:SetScript("OnLeave", RowLeave)
        row:SetScript("OnClick", RowClicked)
        return row
    end,
    Set = function(row, boss, number, key, killed)
        row.boss, row.key, row.lit, row.killed = boss, key, false, killed
        Map.SetMark(row.mark, boss, number, 1 / LIST_SCALE, killed)
        local tag = J.BossTag(boss)
        row.tag:SetText(tag or "")
        row.tag:SetShown(tag ~= nil)
        local tagW = tag and ROW_TAG_GAP + math.ceil(row.tag:GetStringWidth()) or 0
        local right = SetRight(row, boss)
        row.name:SetWidth(0)
        row.name:SetText(boss.name)
        local room = row:GetWidth() - ROW_NAME_X - tagW - right - ROW_MARK_GAP
        row.name:SetWidth(math.max(1, math.min(math.ceil(row.name:GetStringWidth()) + 1, room)))
        List.PaintRow(row)
        return LIST_ROW_H
    end,
}

List.ROW_H = LIST_ROW_H

function List.PaintRow(row)
    local on = row.boss == Map.picked
    local c = ns.ThemeTint("accent", St.PICKED_RGB)
    row.fill:SetColorTexture(c.r, c.g, c.b, St.TAB_FILL)
    row.fill:SetShown(on)
    row.hover:SetShown(row.lit == true and not on)
    Map.ShowPicked(row.mark, on, true)
    local color = row.killed and not on and T.muted or T.fg
    row.name:SetTextColor(color.r, color.g, color.b)
end

function List.RowOf(key)
    local pool = Map.listView.pools.bossRow
    for i = 1, pool.used do
        if pool[i].key == key then return pool[i] end
    end
end

function List.Draw()
    local listView = Map.listView
    local dungeon = Map.windowView.dungeon
    FillQuests(dungeon)
    drawKilled, drawTotal, drawInside = 0, 0, Map.windowView.inside
    drawGrouped, lastWing = NamedWings(dungeon) > 1, nil
    listView:Clear()
    listView.tightTitles = true
    listView.rows = 0
    Map.EachBoss(dungeon, CountRow)
    listView:Section(TEXT_BOSSES, listView.rows)
    listView.rows = 0
    Map.EachBoss(dungeon, ListRow)
    listView:Fit(NO_EVENTS)
    return drawInside and drawTotal > 0 and DownText(drawKilled, drawTotal) or ""
end

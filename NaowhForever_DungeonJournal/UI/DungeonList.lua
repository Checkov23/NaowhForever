-- DungeonList.lua: the dungeon list down the left of the Journal's window (J.DungeonList).
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Loot = J.Loot
local Quests = J.Quests
local S = J.Settings
local Parts = ns.Shared.Parts
local LP = J.ListParts
local St = J.Style
local BIS_RGB, BIS_CODE, LOOK_CODE, TERRITORY_CODE = St.BIS_RGB, St.BIS_CODE, St.LOOK_CODE, St.TERRITORY_CODE
local LIST_ROW, GROUP_H, UNUSABLE = St.LIST_ROW, St.GROUP_H, St.UNUSABLE
local NAME_SIZE, COUNT_SIZE, PEOPLE = St.LIST_NAME_SIZE, St.LIST_COUNT_SIZE, St.PEOPLE
local TERRITORY_ICON, TERRITORY_GAP, FACTION_ATLAS, CONTESTED = St.TERRITORY_ICON, St.TERRITORY_GAP,
    St.FACTION_ATLAS, St.CONTESTED
local STAR_TAG, DONE_MARK = St.STAR_TAG, St.DONE_MARK
local NAME_LEFT, ICON_DROP, GROUP_GAP, STRIPE_EVERY = LP.NAME_LEFT, LP.ICON_DROP, LP.GROUP_GAP, LP.STRIPE_EVERY

local SIZE_ICON, SIZE_GAP = 12, 3
local HERE_DOT = 5
local HERE_LEFT = LP.SELECTED_BAR + (LP.MARK_GAP - HERE_DOT) / 2
local NAME_GAP, BIS_GAP, ICON_RIGHT = 8, 8, 8
local CONTESTED_RGB = { r = 0xe6 / 255, g = 0xcc / 255, b = 0x80 / 255 }
local GROUPS = { "For your level", "Coming up", "Raids", "Low level" }
local CLOSED_KEYS = { "closedGroup1", "closedGroup2", "closedGroup4", "closedGroup3" }
local FOR_YOUR_LEVEL, COMING_UP, RAIDS, LOW_LEVEL = 1, 2, 3, 4
local ORDER = { LOW_LEVEL, FOR_YOUR_LEVEL, COMING_UP, RAIDS }
local CONTESTED_SIDE = "Contested"

local TEXT_HERE = ns.L("You are here")
local TEXT_ZONE = "%s  %s%s|r"
local TEXT_RAID = ns.L("A raid for %d players")
local TEXT_LEVEL = ns.L("Level ")
local TEXT_NO_BOSSES = ns.L("No boss data for it yet.")
local TEXT_TO_PICK_UP = ns.L("%d |4quest:quests; to pick up")
local TEXT_IN_LOG = ns.L("%d in your log")
local TEXT_BIS = ns.L("%s%d of your %d BiS here are yours|r")
local TEXT_LOOKS = ns.L("%s%d new |4look:looks;|r")
local TEXT_DONE_GAP = "  "

local rows, groups = {}, {}
local onSelect
local filters = {}
local scroll, content

local function Group(dungeon)
    if dungeon.raid then return RAIDS end
    local levels = J.Levels(dungeon)
    local level = UnitLevel("player")
    if not levels or level < levels[1] then return COMING_UP end
    if level > levels[2] then return LOW_LEVEL end
    return FOR_YOUR_LEVEL
end

local function Closed(g)
    return S.Get(CLOSED_KEYS[g]) == true
end

local function LevelCells(row, text, icon)
    local cells = J.View.Parts.Cells(row, COUNT_SIZE, T.muted, #text)
    cells[1]:SetPoint("RIGHT", icon, "LEFT", -TERRITORY_GAP, ICON_DROP)
    return cells:SetText(text)
end

local function WhereLines(dungeon)
    if dungeon.zone then
        local territory = dungeon.territory or CONTESTED_SIDE
        GameTooltip:AddLine(TEXT_ZONE:format(dungeon.zone, TERRITORY_CODE[territory], territory), 1, 1, 1)
    end
    if dungeon.raid then
        GameTooltip:AddLine(TEXT_RAID:format(dungeon.raid), 1, 1, 1)
        return
    end
    local range = J.LevelRange(dungeon)
    if range then GameTooltip:AddLine(TEXT_LEVEL .. range, 1, 1, 1) end
end

local function QuestLines(dungeon)
    if not dungeon.quests then return end
    local toPickUp, inLog = Quests.Count(dungeon.quests)
    if toPickUp > 0 then GameTooltip:AddLine(TEXT_TO_PICK_UP:format(toPickUp), 1, 1, 1) end
    if inLog > 0 then GameTooltip:AddLine(TEXT_IN_LOG:format(inLog), 1, 1, 1) end
end

local function LootLines(dungeon)
    Loot.ReadFilters(filters)
    local bis, haveBis = Loot.DungeonBis(dungeon, filters)
    if bis > 0 then GameTooltip:AddLine(TEXT_BIS:format(BIS_CODE, haveBis, bis)) end
    if not filters.showAppearance then return end
    local looks = Loot.DungeonNewLooks(dungeon, filters)
    if looks > 0 then GameTooltip:AddLine(TEXT_LOOKS:format(LOOK_CODE, looks)) end
end

local function RowEnter(row)
    local dungeon = row.dungeon
    LP.Hover(row)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(dungeon.name)
    if row.here:IsShown() then GameTooltip:AddLine(TEXT_HERE, T.accent.r, T.accent.g, T.accent.b) end
    if dungeon.new then GameTooltip:AddLine(Parts.ForeverLine()) end
    WhereLines(dungeon)
    if not J.HasBosses(dungeon) then
        GameTooltip:AddLine(TEXT_NO_BOSSES, T.muted.r, T.muted.g, T.muted.b, true)
    else
        QuestLines(dungeon)
        LootLines(dungeon)
    end
    GameTooltip:Show()
end

local function TerritoryIcon(row, territory)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(TERRITORY_ICON, TERRITORY_ICON)
    icon:SetPoint("RIGHT", -ICON_RIGHT, -ICON_DROP)
    if FACTION_ATLAS[territory] then
        icon:SetAtlas(FACTION_ATLAS[territory])
    else
        icon:SetTexture(CONTESTED)
        icon:SetVertexColor(CONTESTED_RGB.r, CONTESTED_RGB.g, CONTESTED_RGB.b)
    end
    return icon
end

local function RowClicked(row)
    onSelect(row.dungeon)
end

local function RaidIcon(row, leftmost)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(PEOPLE)
    icon:SetSize(SIZE_ICON, SIZE_ICON)
    icon:SetVertexColor(T.muted.r, T.muted.g, T.muted.b)
    icon:SetPoint("RIGHT", leftmost, "LEFT", -SIZE_GAP, -ICON_DROP)
    return icon
end

local function RightColumns(row, dungeon)
    row.territory = TerritoryIcon(row, dungeon.territory or CONTESTED_SIDE)
    local range = dungeon.raid and tostring(dungeon.raid) or J.LevelRange(dungeon)
    local leftmost = range and LevelCells(row, range, row.territory)
    if dungeon.raid and leftmost then leftmost = RaidIcon(row, leftmost) end
    row.bis = ns.Font(row, COUNT_SIZE, nil, BIS_RGB)
    if leftmost then
        row.bis:SetPoint("RIGHT", leftmost, "LEFT", -BIS_GAP, 0)
    else
        row.bis:SetPoint("RIGHT", row.territory, "LEFT", -BIS_GAP, ICON_DROP)
    end
end

local function Row(parent, dungeon)
    local row = LP.Row(parent)
    row.dungeon = dungeon
    row.here = ns.Solid(row, "ARTWORK", T.accent, 1)
    row.here:SetSize(HERE_DOT, HERE_DOT)
    row.here:SetPoint("LEFT", HERE_LEFT, 0)
    RightColumns(row, dungeon)
    row.name = ns.Font(row, NAME_SIZE)
    row.name:SetPoint("LEFT", NAME_LEFT, 0)
    row.name:SetPoint("RIGHT", row.bis, "LEFT", -NAME_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetText(dungeon.name)
    if dungeon.new then LP.ForeverMark(row) end
    row:SetScript("OnClick", RowClicked)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", LP.Leave)
    return row
end

local function GroupClicked(header)
    S.Set(CLOSED_KEYS[header.group], not Closed(header.group))
end

local function LayoutGroup(g, header, y)
    local count, closed = 0, Closed(g)
    for _, row in ipairs(rows) do
        local inGroup = Group(row.dungeon) == g
        local listed = inGroup and J.FactionShown(row.dungeon)
        if listed then
            if count == 0 then
                header:ClearAllPoints()
                header:SetPoint("TOPLEFT", 0, -y)
                y = y + GROUP_H
            end
            count = count + 1
        end
        if inGroup then
            row:SetShown(listed and not closed)
            if listed and not closed then
                row.stripe:SetShown(count % STRIPE_EVERY == 0)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -y)
                row.top = y
                y = y + LIST_ROW
            end
        end
    end
    header:SetShown(count > 0)
    LP.Fold(header, closed, count)
    if count > 0 then y = y + GROUP_GAP end
    return y
end

local function Finished(dungeon, bis, haveBis)
    local any = false
    local done, total = Quests.Progress(dungeon.quests)
    if total > 0 then
        if done < total then return false end
        any = true
    end
    if bis > 0 then
        if haveBis < bis then return false end
        any = true
    end
    if filters.showAppearance then
        local new, looks = Loot.DungeonNewLooks(dungeon, filters)
        if new > 0 then return false end
        any = any or looks > 0
    end
    return any
end

local function PaintCounts(row, dungeon)
    local bis, haveBis = Loot.DungeonBis(dungeon, filters)
    local missing = bis - haveBis
    if missing ~= row.missing then
        row.missing = missing
        row.bis:SetText(missing > 0 and STAR_TAG .. missing or "")
    end
    local finished = Finished(dungeon, bis, haveBis)
    if finished ~= row.finished then
        row.finished = finished
        row.name:SetText(finished and dungeon.name .. TEXT_DONE_GAP .. DONE_MARK or dungeon.name)
    end
end

local function PaintRow(row, selected, current)
    local dungeon = row.dungeon
    local chosen = dungeon == selected
    LP.Select(row, chosen)
    if chosen then LP.ShowRow(scroll, row) end
    local color = (chosen or Group(dungeon) == FOR_YOUR_LEVEL) and T.fg or T.muted
    row.name:SetTextColor(color.r, color.g, color.b)
    row:SetAlpha((J.HasBosses(dungeon) or chosen) and 1 or UNUSABLE)
    row.here:SetShown(dungeon == current)
    PaintCounts(row, dungeon)
end

local List = {}
J.DungeonList = List

function List.Build(parent, select)
    onSelect = select
    scroll, content = LP.NewScroll(parent)
    for g, text in ipairs(GROUPS) do
        groups[g] = LP.Header(content, ns.L(text), GroupClicked)
        groups[g].group = g
    end
    for i, dungeon in ipairs(J.Dungeons()) do rows[i] = Row(content, dungeon) end
end

function List.Layout()
    local y = 0
    for _, g in ipairs(ORDER) do y = LayoutGroup(g, groups[g], y) end
    content:SetHeight(math.max(1, y))
end

function List.Paint(selected)
    local here = J.Current()
    local current = here and here[1]
    Loot.ReadFilters(filters)
    for _, row in ipairs(rows) do PaintRow(row, selected, current) end
end

function List.Next(from, by)
    local dungeons = J.Dungeons()
    local n = #dungeons
    for i, dungeon in ipairs(dungeons) do
        if dungeon == from then
            for step = 1, n do
                local after = dungeons[(i - 1 + by * step) % n + 1]
                if J.FactionShown(after) then return after end
            end
            return from
        end
    end
    return dungeons[1]
end

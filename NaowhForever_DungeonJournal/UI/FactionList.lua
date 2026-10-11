-- FactionList.lua: the faction list on the window's Reputation and PvP tabs (J.FactionList).
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Loot = J.Loot
local Rep = J.Reputation
local S = J.Settings
local Parts = ns.Shared.Parts
local LP = J.ListParts
local St = J.Style
local BIS_RGB, BIS_CODE, TERRITORY_CODE, PLACE_DOT = St.BIS_RGB, St.BIS_CODE, St.TERRITORY_CODE, St.PLACE_DOT
local LIST_ROW, GROUP_H, NAME_SIZE, COUNT_SIZE = St.LIST_ROW, St.GROUP_H, St.LIST_NAME_SIZE, St.LIST_COUNT_SIZE
local STANDING_W, ROUND, TERRITORY_ICON, FACTION_ATLAS = St.LIST_STANDING_W, St.ROUND, St.TERRITORY_ICON,
    St.FACTION_ATLAS
local STAR_TAG, DONE_MARK = St.STAR_TAG, St.DONE_MARK
local NAME_LEFT, ICON_DROP, GROUP_GAP, STRIPE_EVERY = LP.NAME_LEFT, LP.ICON_DROP, LP.GROUP_GAP, LP.STRIPE_EVERY

local GAP, RIGHT = 8, 8
local PILL = 4
local MIN_FILL = 0.1
local UNMET = 0.45
local UNLOCKED_W, STANDING_NAME_W = 30, 56

local TEXT_UNRELEASED = ns.L("Not in Forever yet")
local TEXT_YOUR_RANK = ns.L("Your Rank")
local TEXT_BATTLEGROUNDS = ns.L("Battlegrounds")
local TEXT_NEW = ns.L("New in Forever")
local TEXT_CLASSIC = ns.L("Classic")
local GROUPS = {
    reputation = { TEXT_NEW, TEXT_CLASSIC, ns.L("Cities"), "Steamwheedle Cartel", TEXT_UNRELEASED },
    pvp = { TEXT_YOUR_RANK, TEXT_BATTLEGROUNDS },
}
local TEXT_YOUR_PVP_RANK = ns.L("Your PvP Rank")
local TEXT_PVP_RANK = ns.L("PvP Rank")
local TEXT_RANK = ns.L("Rank ")
local TEXT_RANK_HELP = ns.L("Your rank this season, and what each rank gives.")
local TEXT_QUARTERMASTER = ns.L("Quartermaster in ")
local TEXT_NOT_MET = ns.L("Not met yet")
local TEXT_VALUE = "  %s / %s"
local TEXT_UNLOCKED = ns.L("%d of its %d rewards for you unlocked")
local TEXT_NO_REWARDS = ns.L("No rewards for you in this build yet")
local TEXT_BIS = ns.L("%s%d of your %d BiS among its rewards are yours|r")
local TEXT_NOT_ANNOUNCED = ns.L("Its raids are not announced for WoW Forever yet.")
local TEXT_FRACTION = "%s/%s"
local TEXT_CODE_END = "|r"
local TEXT_DONE_GAP = "  "

local rows, headers = {}, {}
local onSelect, shownTab
local filters = {}
local order = {}
local counted = {}
local scroll, content

local function GroupOf(page)
    if page.rank then return TEXT_YOUR_RANK end
    if page.tab == "pvp" then return TEXT_BATTLEGROUNDS end
    if page.unreleased then return TEXT_UNRELEASED end
    return page.group or (page.new and TEXT_NEW or TEXT_CLASSIC)
end

local function Dot(row, layer, color)
    local dot = row:CreateTexture(nil, layer)
    dot:SetTexture(ROUND, nil, nil, "TRILINEAR")
    dot:SetSize(PILL, PILL)
    dot:SetVertexColor(color.r, color.g, color.b, 1)
    return dot
end

local function Pill(row, right)
    local track = ns.Solid(row, "BORDER", T.line, 1)
    track:SetPoint("RIGHT", right - PILL / 2, 0)
    track:SetSize(STANDING_W - PILL, PILL)
    Dot(row, "BORDER", T.line):SetPoint("CENTER", track, "LEFT")
    Dot(row, "BORDER", T.line):SetPoint("CENTER", track, "RIGHT")
    row.fill = row:CreateTexture(nil, "ARTWORK")
    row.fill:SetColorTexture(1, 1, 1, 1)
    row.fill:SetPoint("LEFT", track)
    row.fill:SetHeight(PILL)
    row.fillStart = Dot(row, "ARTWORK", T.fg)
    row.fillStart:SetPoint("CENTER", row.fill, "LEFT")
    row.fillEnd = Dot(row, "ARTWORK", T.fg)
    row.fillEnd:SetPoint("CENTER", row.fill, "RIGHT")
    row.track = track
end

local function SetPill(row, share, color)
    local any = share > 0
    row.fill:SetShown(any)
    row.fillStart:SetShown(any)
    row.fillEnd:SetShown(any)
    if not any then return end
    row.fill:SetWidth(math.max(MIN_FILL, (STANDING_W - PILL) * math.min(1, share)))
    row.fill:SetVertexColor(color.r, color.g, color.b, 1)
    row.fillStart:SetVertexColor(color.r, color.g, color.b, 1)
    row.fillEnd:SetVertexColor(color.r, color.g, color.b, 1)
end

local function RankLines()
    local info = Rep.Rank()
    if info then
        GameTooltip:AddLine(TEXT_RANK .. info.renownLevel .. PLACE_DOT .. Rep.RankTitle(info.renownLevel), 1, 1, 1)
    end
    GameTooltip:AddLine(TEXT_RANK_HELP, T.muted.r, T.muted.g, T.muted.b, true)
end

local function StandingLine(reaction, value, max)
    if not reaction then
        GameTooltip:AddLine(TEXT_NOT_MET, T.muted.r, T.muted.g, T.muted.b)
        return
    end
    local color = Rep.Color(reaction)
    local far = reaction < Rep.EXALTED and TEXT_VALUE:format(BreakUpLargeNumbers(value), BreakUpLargeNumbers(max)) or ""
    GameTooltip:AddLine(Rep.Label(reaction) .. far, color.r, color.g, color.b)
end

local function RewardLines(page, reaction)
    Loot.ReadFilters(filters)
    local unlocked, total = Rep.Unlocked(page, reaction, filters)
    if total > 0 then
        GameTooltip:AddLine(TEXT_UNLOCKED:format(unlocked, total), 1, 1, 1)
    else
        GameTooltip:AddLine(TEXT_NO_REWARDS, T.muted.r, T.muted.g, T.muted.b)
    end
    local bis, haveBis = Rep.Bis(page)
    if bis > 0 then GameTooltip:AddLine(TEXT_BIS:format(BIS_CODE, haveBis, bis)) end
end

local function FactionLines(page)
    if page.new then GameTooltip:AddLine(Parts.ForeverLine()) end
    if page.side then
        GameTooltip:AddLine(TERRITORY_CODE[page.side] .. page.side .. TEXT_CODE_END
            .. (page.battleground and PLACE_DOT .. page.battleground or ""), 1, 1, 1)
    end
    if page.zone then GameTooltip:AddLine(TEXT_QUARTERMASTER .. page.zone, 1, 1, 1) end
    local reaction, value, max = Rep.Standing(page)
    StandingLine(reaction, value, max)
    RewardLines(page, reaction)
    if page.unreleased then GameTooltip:AddLine(TEXT_NOT_ANNOUNCED, T.muted.r, T.muted.g, T.muted.b, true) end
end

local function RowEnter(row)
    local page = row.page
    LP.Hover(row)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(page.rank and TEXT_YOUR_PVP_RANK or page.name)
    if page.rank then RankLines() else FactionLines(page) end
    GameTooltip:Show()
end

local function RowClicked(row)
    onSelect(row.page)
end

local function Crest(row, side)
    local crest = row:CreateTexture(nil, "ARTWORK")
    crest:SetSize(TERRITORY_ICON, TERRITORY_ICON)
    crest:SetPoint("RIGHT", -RIGHT, -ICON_DROP)
    crest:SetAtlas(FACTION_ATLAS[side])
end

local function CountFont(row, width)
    local font = ns.Font(row, COUNT_SIZE, nil, T.muted)
    font:SetWidth(width)
    font:SetJustifyH("RIGHT")
    return font
end

local function RightColumns(row, page)
    local right = -RIGHT
    if page.side and page.tab == "pvp" then
        Crest(row, page.side)
        right = right - TERRITORY_ICON - GAP
    end
    Pill(row, right)
    row.standing = CountFont(row, STANDING_NAME_W)
    row.standing:SetPoint("RIGHT", row.track, "LEFT", -GAP - PILL / 2, 0)
    row.unlocked = CountFont(row, UNLOCKED_W)
    row.unlocked:SetPoint("RIGHT", row.standing, "LEFT", -GAP, 0)
    row.bis = ns.Font(row, COUNT_SIZE, nil, BIS_RGB)
    row.bis:SetPoint("RIGHT", row.unlocked, "LEFT", -GAP, 0)
end

local function Row(parent, page)
    local row = LP.Row(parent)
    row.page, row.group = page, GroupOf(page)
    row.tab = page.tab
    RightColumns(row, page)
    row.name = ns.Font(row, NAME_SIZE)
    row.name:SetPoint("LEFT", NAME_LEFT, 0)
    row.name:SetPoint("RIGHT", row.bis, "LEFT", -GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.label = page.rank and TEXT_PVP_RANK or page.name
    row.name:SetText(row.label)
    if page.new then LP.ForeverMark(row) end
    row:SetScript("OnClick", RowClicked)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", LP.Leave)
    return row
end

local function HeaderClicked()
    S.Set("openUnreleased", not S.Get("openUnreleased"))
end

local function Listed(row, tab)
    return row.tab == tab and Rep.Shown(row.page)
end

local function LayoutGroup(title, tab, y)
    local count, header = 0, headers[title]
    local closed = title == TEXT_UNRELEASED and not S.Get("openUnreleased")
    for _, row in ipairs(rows) do
        if row.group == title and Listed(row, tab) then
            if count == 0 then
                header:ClearAllPoints()
                header:SetPoint("TOPLEFT", 0, -y)
                header:Show()
                y = y + GROUP_H
            end
            count = count + 1
            if not closed then
                row.stripe:SetShown(count % STRIPE_EVERY == 0)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -y)
                row:Show()
                row.top = y
                y = y + LIST_ROW
            end
        end
    end
    if header.arrow then LP.Fold(header, closed, count) end
    if count > 0 then y = y + GROUP_GAP end
    return y
end

local function SkillsKey()
    local key = 0
    for line in pairs(filters.skills) do key = key + line end
    return key
end

local function Unlocked(faction, reaction)
    if filters.missingBis or filters.upgradesOnly then return Rep.Unlocked(faction, reaction, filters) end
    local c = counted[faction]
    if not c then
        c = {}
        counted[faction] = c
    end
    local skills = SkillsKey()
    if c.total == nil or c.reaction ~= reaction or c.usable ~= filters.usableOnly or c.mine ~= filters.myRecipes
        or c.skills ~= skills then
        c.reaction, c.usable, c.mine, c.skills = reaction, filters.usableOnly, filters.myRecipes, skills
        c.unlocked, c.total = Rep.Unlocked(faction, reaction, filters)
    end
    return c.unlocked, c.total
end

local function PaintRank(row)
    local info = Rep.Rank()
    local level = info and info.renownLevel or 0
    row.standing:SetText(level > 0 and TEXT_RANK .. level or Rep.RankTitle(0))
    row.standing:SetTextColor(T.fg.r, T.fg.g, T.fg.b)
    local share = 0
    if info then
        share = level >= info.maxLevel and 1 or info.renownReputationEarned / math.max(1, info.renownLevelThreshold)
    end
    SetPill(row, share, T.accent)
    row.bis:SetText("")
    row.name:SetTextColor(T.fg.r, T.fg.g, T.fg.b)
end

local function PaintMarks(row, page, reaction)
    local bis, haveBis = Rep.Bis(page)
    local missing = bis - haveBis
    if missing ~= row.missing then
        row.missing = missing
        row.bis:SetText(missing > 0 and STAR_TAG .. missing or "")
    end
    local exalted = reaction == Rep.EXALTED
    if exalted ~= row.exalted then
        row.exalted = exalted
        row.name:SetText(exalted and row.label .. TEXT_DONE_GAP .. DONE_MARK or row.label)
    end
end

local function PaintFaction(row, page, chosen)
    local reaction, value, max = Rep.Standing(page)
    local color = reaction and Rep.Color(reaction) or T.muted
    row.standing:SetText(reaction and Rep.Label(reaction) or "")
    local unlocked, total = Unlocked(page, reaction)
    row.unlocked:SetText(TEXT_FRACTION:format(unlocked, total))
    row.standing:SetTextColor(color.r, color.g, color.b)
    SetPill(row, reaction and value / max or 0, color)
    local name = (chosen or reaction) and T.fg or T.muted
    row.name:SetTextColor(name.r, name.g, name.b)
    row:SetAlpha((reaction or chosen) and 1 or UNMET)
    PaintMarks(row, page, reaction)
end

local function PaintRow(row, selected)
    local page = row.page
    local chosen = page == selected
    LP.Select(row, chosen)
    if chosen then LP.ShowRow(scroll, row) end
    if page.rank then PaintRank(row) else PaintFaction(row, page, chosen) end
end

local List = {}
J.FactionList = List

function List.Build(parent, select)
    onSelect = select
    scroll, content = LP.NewScroll(parent)
    for _, titles in pairs(GROUPS) do
        for _, title in ipairs(titles) do
            headers[title] = LP.Header(content, title, title == TEXT_UNRELEASED and HeaderClicked or nil)
        end
    end
    rows[1] = Row(content, J.RANK)
    for _, tab in ipairs(J.TABS) do
        for _, faction in ipairs(J.Factions(tab)) do rows[#rows + 1] = Row(content, faction) end
    end
end

function List.Layout(tab)
    shownTab = tab
    for _, header in pairs(headers) do header:Hide() end
    for _, row in ipairs(rows) do row:Hide() end
    local y = 0
    for _, title in ipairs(GROUPS[tab]) do y = LayoutGroup(title, tab, y) end
    content:SetHeight(math.max(1, y))
    scroll.bar:SetValue(0)
end

function List.Paint(selected)
    if not shownTab then return end
    Loot.ReadFilters(filters)
    for _, row in ipairs(rows) do
        if row:IsShown() then PaintRow(row, selected) end
    end
end

function List.Next(from, by)
    local n, at = 0, nil
    for _, title in ipairs(GROUPS[shownTab]) do
        for _, row in ipairs(rows) do
            if row.group == title and row:IsShown() then
                n = n + 1
                order[n] = row.page
                if row.page == from then at = n end
            end
        end
    end
    if n == 0 then return from end
    if not at then return order[1] end
    return order[(at - 1 + by) % n + 1]
end

function List.First(tab)
    for _, title in ipairs(GROUPS[tab]) do
        for _, row in ipairs(rows) do
            if row.group == title and Listed(row, tab) then return row.page end
        end
    end
end

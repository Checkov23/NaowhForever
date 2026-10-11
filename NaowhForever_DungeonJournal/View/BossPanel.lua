-- BossPanel.lua: a boss's history in the side panel: each kill, your group, the loot and the rolls (J.View.BossPanel).
local ns = _G.NaowhForever

local J = ns.Journal
local Kills, Looted, Team = J.Kills, J.Looted, J.Team
local View = J.View
local Parts = View.Parts
local FightLength = Parts.FightLength
local St = J.Style
local SECTION_SPACE, KILL_DATE, BORDER_RGB = St.SECTION_SPACE, St.KILL_DATE, St.BORDER_RGB
local CARD_PAD, CARD_GAP, GOLD_CODE = St.CARD_PAD, St.CARD_GAP, St.GOLD_CODE

local MINUTE = J.C.SECONDS_PER_MINUTE
local LOOT_WINDOW = 15 * MINUTE
local STRIPE_EVERY = J.C.STRIPE_EVERY
local ITEM_ID = "|Hitem:(%d+)"

local TEXT_GROUP = ns.L("Group")
local TEXT_NOT_KEPT = ns.L("Not kept for this one.")
local TEXT_NO_ROLL = ns.L("Picked up without a roll")
local TEXT_ALL_PASSED = ns.L("Everyone passed")
local TEXT_LOOT = ns.L("Loot")
local TEXT_TOOK = ns.L("took ")
local TEXT_RECORD = ns.L("Record|r  ")
local TEXT_LOOTED = ns.L("looted")
local TEXT_KILLS = ns.L("Kills")
local TEXT_NOTHING_YET = ns.L("Nothing yet on this character. Kills and loot count while the Dungeon Journal is on.")
local TEXT_LATEST = ns.L("The latest %d kills. First counted: %s.")
local TEXT_RAID_NOT_OPEN = ns.L("The game does not name this fight yet: its kills count once the raid opens.")
local TEXT_NOT_A_FIGHT = ns.L("In a dungeon the game keeps secret which creature died, and only names boss fights. "
    .. "This one is no boss fight to the game, so its kills cannot be counted.")

local EMPTY = {}
local panel, view
local shown = {}
local entries, spare = {}, {}
local items = {}
local members, rolls, byName = {}, {}, {}
local dropIDs, dropRolls, dropped = {}, {}, {}

local function Entry(at, kill)
    local entry = table.remove(spare) or { items = {} }
    entry.at, entry.kill = at, kill
    wipe(entry.items)
    entries[#entries + 1] = entry
    return entry
end

local function Newer(a, b)
    return a.at > b.at
end

local function KillBefore(at)
    local best
    for _, entry in ipairs(entries) do
        if entry.kill and entry.at <= at and at - entry.at <= LOOT_WINDOW and (not best or entry.at > best.at) then
            best = entry
        end
    end
    return best
end

local function Build(boss, record)
    for i = #entries, 1, -1 do
        spare[#spare + 1] = entries[i]
        entries[i] = nil
    end
    local at = record and record.at or EMPTY
    for i = 1, #at do
        if type(at[i]) == "number" then Entry(at[i], i) end
    end
    Looted.AllFrom(boss, items)
    for i = #items, 1, -1 do
        local item = items[i]
        local entry = KillBefore(item.at) or Entry(item.at, nil)
        entry.items[#entry.items + 1] = item
    end
    table.sort(entries, Newer)
end

local function ItemID(link)
    return tonumber(link:match(ITEM_ID))
end

local function DrawTeam(team)
    Team.Read(team, members)
    wipe(byName)
    view:Add("label", TEXT_GROUP, #members > 0 and #members or nil)
    if #members == 0 then
        view:Add("rolls", TEXT_NOT_KEPT)
        return
    end
    for _, member in ipairs(members) do byName[member.name] = member end
    view:Add("team", members)
end

local function IsMe(name)
    local member = byName[name]
    if member then return member.me end
    return name == UnitName("player")
end

local function DrawRolls(text)
    Team.ReadRolls(text, rolls)
    if #rolls == 0 then
        view:Add("rolls", TEXT_NO_ROLL)
        return
    end
    local won = false
    for _, roll in ipairs(rolls) do
        local member = byName[roll.name]
        roll.class = roll.class or (member and member.class)
        won = won or roll.winner
    end
    if not won then view:Add("rolls", TEXT_ALL_PASSED) end
    view:Add("rollGrid", rolls, IsMe)
end

local function KeepDrop(link, rollText)
    local id = ItemID(link)
    if not id then return end
    dropIDs[#dropIDs + 1], dropRolls[#dropRolls + 1] = id, rollText
    dropped[id] = true
end

local function DrawDrop(n, id, rollText)
    view.striped = n % STRIPE_EVERY == 1
    view:Add("item", id, nil, nil, false)
    DrawRolls(rollText)
end

local function CountLoot(own)
    local count = #dropIDs
    for _, item in ipairs(own) do
        if not dropped[item.id] then count = count + 1 end
    end
    return count
end

local function DrawLoot(dropsText, own)
    wipe(dropIDs)
    wipe(dropRolls)
    wipe(dropped)
    Kills.EachDrop(dropsText, KeepDrop)
    local count = CountLoot(own)
    if count == 0 then return end
    view:Add("label", TEXT_LOOT, count)
    local n = 0
    for i, id in ipairs(dropIDs) do
        n = n + 1
        DrawDrop(n, id, dropRolls[i])
    end
    for _, item in ipairs(own) do
        if not dropped[item.id] then
            n = n + 1
            DrawDrop(n, item.id, item.rolls)
        end
    end
    view.striped = false
end

local function KillLength(record, i, at, bestAt)
    local took = type(record.took) == "table" and record.took[i]
    local length = type(took) == "number" and TEXT_TOOK .. FightLength(took) or nil
    if length and at == bestAt then length = GOLD_CODE .. TEXT_RECORD .. length end
    return length
end

local function DrawKill(entry, record, bestAt)
    local i = entry.kill
    view:Add("historyHead", record.n - (#record.at - i), date(KILL_DATE, entry.at), KillLength(record, i, entry.at, bestAt))
    local teams = type(record.team) == "table" and record.team or nil
    local first = entry.items[1]
    DrawTeam(teams and teams[i] or (first and first.team))
    DrawLoot(type(record.drops) == "table" and record.drops[i] or nil, entry.items)
end

local function DrawLooted(entry)
    view:Add("historyHead", nil, date(KILL_DATE, entry.at), TEXT_LOOTED)
    DrawTeam(entry.items[1].team)
    DrawLoot(nil, entry.items)
end

local function DrawEntry(entry, record, bestAt)
    local top, width = view.cursor, view:GetWidth()
    local card = view:Acquire("card")
    card:SetFrameLevel(view:GetFrameLevel())
    card.edge:SetColor(BORDER_RGB.r, BORDER_RGB.g, BORDER_RGB.b, 1)
    view.left, view.width = CARD_PAD, width - CARD_PAD * 2
    if entry.kill then DrawKill(entry, record, bestAt) else DrawLooted(entry) end
    view:Space(CARD_PAD)
    view.left, view.width = 0, width
    card:SetHeight(view.cursor - top)
    view:Space(CARD_GAP)
end

local function BestAt(record)
    if not record then return nil end
    local _, at = Kills.Best(record)
    return at
end

local BossPanel = {}
View.BossPanel = BossPanel

function BossPanel.NotCounted(dungeon)
    if dungeon and dungeon.raid and dungeon.note then return TEXT_RAID_NOT_OPEN end
    return TEXT_NOT_A_FIGHT
end

local function Draw()
    local boss = shown.boss
    Kills.Gather(boss)
    local record = Kills.Record(boss)
    panel.title:SetText(boss.name:upper())
    view:Begin(nil, nil, nil)
    view.showChance = false
    view.bare = true
    Build(boss, record)
    if not Kills.Counted(boss) then view:Note(BossPanel.NotCounted(shown.dungeon)) end
    view:Section(TEXT_KILLS, record and record.n or 0)
    view:Space(SECTION_SPACE)
    if #entries == 0 then view:Note(TEXT_NOTHING_YET) end
    local bestAt = BestAt(record)
    for _, entry in ipairs(entries) do DrawEntry(entry, record, bestAt) end
    if record and record.n > #record.at and type(record.first) == "number" then
        view:Note(TEXT_LATEST:format(#record.at, date(KILL_DATE, record.first)))
    end
    view:Space(SECTION_SPACE)
    view:Finish()
end

function BossPanel.Show(boss, from, dungeon)
    if not panel then
        panel = Parts.SidePanel(EMPTY)
        view = panel.view
        view.Redraw = Draw
    end
    if panel:IsShown() and shown.boss == boss then
        panel:Hide()
        return
    end
    shown.boss, shown.dungeon = boss, dungeon
    Parts.ShowBeside(panel, from)
    Draw()
end

function BossPanel.Refresh()
    if panel and panel:IsShown() then Draw() end
end

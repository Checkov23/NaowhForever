-- BossHeader.lua: the top of a boss's own page: its name and kill count, its title, level and kind.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Kinds, Parts = J.View.Kinds, J.View.Parts
local St = J.Style
local TITLE_SIZE, TITLE_H, TITLE_GAP = St.TITLE_SIZE, St.TITLE_H, St.TITLE_GAP
local WHERE_H, HEADER_PAD, PLACE_DOT, TEXT_SIZE = St.WHERE_H, St.HEADER_PAD, St.PLACE_DOT, St.TEXT_SIZE

local HEADER_TOP = 8
local KILLS_GAP = 10
local TITLE_LINE_TOP = 2
local TITLE_LINE_PAD = 4
local ABOUT_GAP = 10
local ABOUT_RISE = 2
local INFO_LOW, INFO_HIGH, INFO_KIND, INFO_TYPE, INFO_TITLE = 1, 2, 3, 4, 5
local CLASSIFICATION = { [1] = ns.L("Elite"), [2] = ns.L("Rare Elite"), [3] = ns.L("Boss"), [4] = ns.L("Rare") }
local CREATURE_TYPE = {
    [1] = "Beast", [2] = "Dragonkin", [3] = "Demon", [4] = "Elemental", [5] = "Giant", [6] = "Undead",
    [7] = "Humanoid", [8] = "Critter", [9] = "Mechanical", [11] = "Totem", [15] = "Aberration",
}

local TEXT_UNKNOWN_LEVEL = "??"
local TEXT_LEVEL = ns.L("Level ")
local TEXT_RANGE = "%s-%s"
local TEXT_RARE = ns.L("Rare spawn")
local TEXT_OPTIONAL = ns.L("Optional")
local TEXT_QUEST_BOSS = ns.L("Quest boss")

local parts = {}

local function LevelText(info)
    local low, high = info[INFO_LOW], info[INFO_HIGH]
    local level = (high < 0 or low < 0) and TEXT_UNKNOWN_LEVEL or low == high and tostring(low)
        or TEXT_RANGE:format(low, high)
    local kind = CLASSIFICATION[info[INFO_KIND]]
    return TEXT_LEVEL .. ns.Color("fg", level) .. (kind and " " .. kind or "")
end

local function BossKind(boss)
    if boss.rare then return TEXT_RARE end
    if boss.optional then return TEXT_OPTIONAL end
    if boss.quest then return TEXT_QUEST_BOSS end
end

local function AboutText(boss)
    local info = boss.npc and J.BossInfo[boss.npc]
    wipe(parts)
    if info then
        if info[INFO_TITLE] then parts[#parts + 1] = ns.Color("fg", info[INFO_TITLE]) end
        parts[#parts + 1] = LevelText(info)
        local creature = CREATURE_TYPE[info[INFO_TYPE]]
        if creature then parts[#parts + 1] = creature end
    end
    local kind = BossKind(boss)
    if kind then parts[#parts + 1] = kind end
    return table.concat(parts, PLACE_DOT)
end

local function SetKills(row, boss)
    local showKills = row:GetParent().showKills and not boss.trash and not boss.chest
    row.kills:SetShown(showKills)
    if not showKills then return 0 end
    Parts.SetKillCount(row.kills, boss)
    return row.kills:GetWidth() + KILLS_GAP
end

local function NewTitle(row, top)
    local title = ns.Font(row, TITLE_SIZE, nil, T.fg)
    title:SetPoint("TOPLEFT", 0, -top)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    return title
end

local function NewAbout(row)
    local about = ns.Font(row, TEXT_SIZE, nil, T.muted)
    about:SetJustifyH("LEFT")
    about:SetWordWrap(false)
    return about
end

Kinds.bossHeader = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.title = NewTitle(row, HEADER_TOP)
        row.kills = Parts.KillCount(row)
        row.kills:SetPoint("RIGHT", row, "TOPRIGHT", 0, -HEADER_TOP - TITLE_H / 2)
        row.about = NewAbout(row)
        row.about:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -TITLE_GAP)
        row.about:SetPoint("RIGHT")
        return row
    end,
    Set = function(row, boss)
        local kills = SetKills(row, boss)
        row.title:SetText(boss.name)
        row.title:SetWidth(math.max(1, row:GetWidth() - kills))
        row.about:SetText(AboutText(boss))
        return HEADER_TOP + TITLE_H + TITLE_GAP + WHERE_H + HEADER_PAD
    end,
}

Kinds.bossTitle = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.title = NewTitle(row, TITLE_LINE_TOP)
        row.about = NewAbout(row)
        row.about:SetPoint("BOTTOMLEFT", row.title, "BOTTOMRIGHT", ABOUT_GAP, ABOUT_RISE)
        row.kills = Parts.KillCount(row)
        row.kills:SetPoint("RIGHT", row, "TOPRIGHT", 0, -TITLE_LINE_TOP - TITLE_H / 2)
        return row
    end,
    Set = function(row, boss)
        local room = row:GetWidth() - SetKills(row, boss)
        row.title:SetWidth(0)
        row.title:SetText(boss.name)
        local nameW = math.min(math.ceil(row.title:GetStringWidth()) + 1, room)
        row.title:SetWidth(nameW)
        row.about:SetText(AboutText(boss))
        local aboutW = room - nameW - ABOUT_GAP
        row.about:SetShown(aboutW > 0)
        row.about:SetWidth(math.max(1, aboutW))
        return TITLE_LINE_TOP + TITLE_H + TITLE_LINE_PAD
    end,
}

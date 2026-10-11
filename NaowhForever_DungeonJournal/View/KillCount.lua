-- KillCount.lua: the skull and a boss's kill count, its tooltip, and the history it opens (Parts.KillCount, SetKillCount).
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Kills = J.Kills
local Parts = J.View.Parts
local Tip = Parts.Tip
local FightLength = Parts.FightLength
local St = J.Style
local SKULL, KILL_DATE, GOLD_CODE, SMALL_SIZE = St.SKULL, St.KILL_DATE, St.GOLD_CODE, St.SMALL_SIZE

local KILL_ICON = 14
local KILL_PAD = 4
local KILL_GAP = 3

local TEXT_NOT_COUNTED = "-"
local TEXT_LOOTED_HINT = ns.L("Click for what you looted from it.")
local TEXT_NOT_KILLED = ns.L("Not killed yet on this character.")
local TEXT_KILLED_ONCE = ns.L("Killed once on this character.")
local TEXT_KILLED_TIMES = ns.L("Killed %d times on this character.")
local TEXT_RECORD = ns.L("Record|r ")
local TEXT_LATEST = ns.L("The latest %d. First counted: %s.")
local TEXT_WHILE_ON = ns.L("Kills count while the Dungeon Journal is on.")
local TEXT_OPEN_HISTORY = ns.L("Click for each kill: who was with you, what dropped and who won it.")
local TEXT_BLANK = " "

local function PaintKills(button)
    local color = button.kills > 0 and T.fg or T.muted
    button.icon:SetVertexColor(color.r, color.g, color.b)
    button.count:SetTextColor(color.r, color.g, color.b)
end

local function Muted(text, wrap)
    GameTooltip:AddLine(text, T.muted.r, T.muted.g, T.muted.b, wrap)
end

local function Dungeon(button)
    return button:GetParent():GetParent().dungeon
end

local function NotCountedLines(button)
    Muted(J.View.BossPanel.NotCounted(Dungeon(button)), true)
    GameTooltip:AddLine(TEXT_LOOTED_HINT, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b, true)
end

local function KillLines(record)
    local muted = T.muted
    GameTooltip:AddLine(record.n == 1 and TEXT_KILLED_ONCE or TEXT_KILLED_TIMES:format(record.n), 1, 1, 1)
    local best, bestAt = Kills.Best(record)
    if best then
        GameTooltip:AddDoubleLine(GOLD_CODE .. TEXT_RECORD .. FightLength(best), date(KILL_DATE, bestAt),
            1, 1, 1, muted.r, muted.g, muted.b)
    end
    local at, took = record.at, record.took
    GameTooltip:AddLine(TEXT_BLANK)
    for i = #at, 1, -1 do
        if type(at[i]) == "number" then
            local length = took[i]
            GameTooltip:AddDoubleLine(date(KILL_DATE, at[i]),
                type(length) == "number" and FightLength(length) or "", 1, 1, 1, muted.r, muted.g, muted.b)
        end
    end
    if record.n > #at and type(record.first) == "number" then
        Muted(TEXT_LATEST:format(#at, date(KILL_DATE, record.first)))
    end
end

local function KillsEnter(button)
    local accent = T.accent
    button.icon:SetVertexColor(accent.r, accent.g, accent.b)
    local boss = button.boss
    local record = Kills.Record(boss)
    if not Tip(button, "ANCHOR_RIGHT") then return end
    GameTooltip:SetText(boss.name, 1, 1, 1)
    if not Kills.Counted(boss) then
        NotCountedLines(button)
        GameTooltip:Show()
        return
    end
    if record then KillLines(record) else Muted(TEXT_NOT_KILLED) end
    GameTooltip:AddLine(TEXT_BLANK)
    Muted(TEXT_WHILE_ON, true)
    GameTooltip:AddLine(TEXT_OPEN_HISTORY, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b, true)
    GameTooltip:Show()
end

local function OpenHistory(button)
    J.View.BossPanel.Show(button.boss, button, Dungeon(button))
end

local function KillsLeave(button)
    PaintKills(button)
    GameTooltip:Hide()
end

function Parts.KillCount(row)
    local kills = CreateFrame("Button", nil, row)
    kills:SetHeight(KILL_ICON + KILL_PAD)
    kills.icon = kills:CreateTexture(nil, "ARTWORK")
    kills.icon:SetTexture(SKULL)
    kills.icon:SetSize(KILL_ICON, KILL_ICON)
    kills.icon:SetPoint("LEFT")
    kills.count = ns.Font(kills, SMALL_SIZE)
    kills.count:SetPoint("LEFT", kills.icon, "RIGHT", KILL_GAP, 0)
    kills:SetScript("OnEnter", KillsEnter)
    kills:SetScript("OnLeave", KillsLeave)
    kills:SetScript("OnClick", OpenHistory)
    return kills
end

function Parts.SetKillCount(kills, boss)
    kills.boss, kills.kills = boss, Kills.Count(boss)
    kills.count:SetText(Kills.Counted(boss) and kills.kills or TEXT_NOT_COUNTED)
    PaintKills(kills)
    kills:SetWidth(KILL_ICON + KILL_GAP + math.ceil(kills.count:GetStringWidth()))
end

-- Texts.lua: Group Inspect's texts, made once each, and what a member's state and stats read as.
local ns = _G.NaowhForever

local T = ns.THEME
local GI = ns.GroupInspect
local C = GI.C
local UI = GI.UI
local St = UI.Style
local Parts = ns.Shared.Parts

local KEPT = 600
local TENTHS, ROUND = C.TENTHS, C.ROUND
local SCORE_LEVELS = 256
local TREE_COUNT, TREE_BASE = C.TREE_COUNT, 64
local ENCHANT_BASE = 64
local BYTE = 255
local STATE_WORDS = { queued = ns.L("Queued"), inspecting = "Inspecting...", out_of_range = ns.L("Out of range"),
    offline = ns.L("Offline"), self = ns.L("You") }
local AWAY = { out_of_range = true, offline = true }
local PERCENT, LEVEL = "%.1f%%", ns.L("Level %d %s")
local TREES, POINTS = "%d/%d/%d", ns.L("%d points")
local FROM_NF, FROM_GEAR, YOURS = ns.L("From their Naowh Forever"), ns.L("From gear"), ns.L("Yours")
local EVERYONE, INSPECTED = ns.L("Everyone inspected"), ns.L("Inspected %d of %d")
local OUT_N, OFFLINE_N = ns.L(", %d out of range"), ns.L(", %d offline")
local ENCHANTED = " " .. ns.Color("muted", "enchanted")
local HAVE_CODE = ("|cff%02x%02x%02x"):format(St.HAVE_RGB.r * BYTE, St.HAVE_RGB.g * BYTE, St.HAVE_RGB.b * BYTE)

local scoreTexts, scoreKept = {}, 0
local levelTexts, talentTexts, statTexts, inlineTexts, keptTexts = {}, {}, {}, {}, 0
local enchantTexts = {}
local tally = { total = 0, done = 0, waiting = 0, out = 0, offline = 0, nf = 0 }
for _, stat in ipairs(UI.STATS) do
    statTexts[stat.key], inlineTexts[stat.key] = {}, {}
end

local function Keep()
    if keptTexts < KEPT then
        keptTexts = keptTexts + 1
        return
    end
    keptTexts = 1
    wipe(levelTexts)
    wipe(talentTexts)
    for _, stat in ipairs(UI.STATS) do
        wipe(statTexts[stat.key])
        wipe(inlineTexts[stat.key])
    end
end

function UI.ScoreText(score, level)
    if not score then return UI.WAITING end
    local key = math.floor(score * TENTHS + ROUND) * SCORE_LEVELS + (level or 0)
    local text = scoreTexts[key]
    if text then return text end
    if scoreKept >= KEPT then
        wipe(scoreTexts)
        scoreKept = 0
    end
    text = ns.NaowhScore.Colored(score, level)
    scoreTexts[key] = text
    scoreKept = scoreKept + 1
    return text
end

function UI.ForgetScores()
    wipe(scoreTexts)
    scoreKept = 0
end

function UI.LevelText(level, classFile)
    local class = classFile or ""
    local byLevel = levelTexts[class]
    if not byLevel then
        byLevel = {}
        levelTexts[class] = byLevel
    end
    local key = level or 0
    local text = byLevel[key]
    if text then return text end
    Keep()
    local name = UI.CLASS_NAMES[class] or ""
    text = level and LEVEL:format(level, name) or name
    byLevel[key] = text
    return text
end

function UI.TalentText(spent)
    if type(spent) ~= "table" then return "" end
    local a, b, c = spent[1] or 0, spent[2] or 0, spent[3] or 0
    local trees = #spent == TREE_COUNT
    local key = trees and ((a * TREE_BASE + b) * TREE_BASE + c) or -(a + b + c)
    local text = talentTexts[key]
    if text then return text end
    Keep()
    text = trees and TREES:format(a, b, c) or POINTS:format(a + b + c)
    talentTexts[key] = text
    return text
end

function UI.StatValue(stat, value)
    local byValue = statTexts[stat.key]
    local text = byValue[value]
    if text then return text end
    Keep()
    text = stat.percent and PERCENT:format(value) or tostring(math.floor(value + ROUND))
    byValue[value] = text
    return text
end

function UI.StatInline(stat, value)
    local byValue = inlineTexts[stat.key]
    local text = byValue[value]
    if text then return text end
    Keep()
    text = ns.Color("muted", stat.short) .. " " .. UI.StatValue(stat, value)
    byValue[value] = text
    return text
end

function UI.StateText(state)
    return STATE_WORDS[state] or ""
end

function UI.Away(rec)
    return AWAY[rec.state] == true
end

function UI.ClassColor(classFile)
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    return color or T.fg
end

function UI.MissingEnchants(rec)
    local gear = rec.gear
    if not gear then return 0 end
    local n = 0
    for _, entry in pairs(gear) do
        if entry.enchanted == false then n = n + 1 end
    end
    return n
end

function UI.EnchantText(rec)
    local gear = rec.gear
    if not gear then return UI.WAITING end
    local have, total = 0, 0
    for _, entry in pairs(gear) do
        if entry.enchanted ~= nil then
            total = total + 1
            if entry.enchanted then have = have + 1 end
        end
    end
    if total == 0 then return "" end
    local key = have * ENCHANT_BASE + total
    local text = enchantTexts[key]
    if text then return text end
    text = (have < total and St.WARN_CODE or HAVE_CODE) .. Parts.Fraction(have, total) .. "|r" .. ENCHANTED
    enchantTexts[key] = text
    return text
end

function UI.StatsFrom(rec)
    if not rec.stats then return "", T.muted end
    if rec.state == "self" then return YOURS, T.accentSoft end
    if rec.statsShared then return FROM_NF, T.accentSoft end
    return FROM_GEAR, T.muted
end

function UI.Tally()
    local members = GI.Members()
    local done, waiting, out, offline, nf = 0, 0, 0, 0, 0
    for i = 1, #members do
        local state = members[i].state
        if state == "ready" or state == "self" then
            done = done + 1
        elseif state == "out_of_range" then
            out = out + 1
        elseif state == "offline" then
            offline = offline + 1
        else
            waiting = waiting + 1
        end
        if members[i].hasNF then nf = nf + 1 end
    end
    tally.total, tally.done, tally.waiting, tally.out, tally.offline, tally.nf = #members, done, waiting, out, offline, nf
    return tally
end

function UI.ProgressText(t)
    if t.total == 0 then return "" end
    local text = (t.waiting + t.out + t.offline == 0) and EVERYONE or INSPECTED:format(t.done, t.total)
    if t.out > 0 then text = text .. OUT_N:format(t.out) end
    if t.offline > 0 then text = text .. OFFLINE_N:format(t.offline) end
    return text
end

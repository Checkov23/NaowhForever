-- Kills.lua: this character's kills of each boss, when, how long and with whom (J.Kills).
local ns = _G.NaowhForever

local J = ns.Journal
local S = J.Settings
local Team = J.Team

local KEEP = 10
local MINUTE, HOUR = J.C.SECONDS_PER_MINUTE, 3600
local RUN_GRACE = 15 * MINUTE
local RUN_MAX = 4 * HOUR
local DROP_WINDOW = 15 * MINUTE
local MILLISECONDS = 1000
local ROUND = J.C.ROUND_HALF
local KILLED = 1
local INSTANCE_ID = 8
local KILLS_KEY, RUN_KEY = "journalKills", "journalRun"
local DROP_LINE, DROP_FIELD = "\n", "\t"
local EACH_LINE = "[^\n]+"
local LINK_AND_ROLLS = "^(.-)\t(.*)$"
local EVENTS = { "ENCOUNTER_START", "ENCOUNTER_END", "PLAYER_ENTERING_WORLD" }

local TEXT_RECORD = ns.L("New record on %s: %s, was %s.")

local byEncounter, dungeonOf
local spare = {}
local pulled = {}
local lines, linePool = {}, {}
local EMPTY = {}
local frame

local function IndexEncounters()
    byEncounter, dungeonOf = {}, {}
    for _, dungeon in ipairs(J.Dungeons()) do
        for _, wing in ipairs(dungeon.wings) do
            for _, boss in ipairs(wing.bosses) do
                local ids = not boss.with and boss.encounters
                for i = 1, ids and #ids or 0 do byEncounter[ids[i]] = boss end
                dungeonOf[boss] = dungeon
            end
        end
    end
end

local function BossFor(encounterID)
    if not byEncounter then IndexEncounters() end
    return byEncounter[encounterID]
end

local function Mine(create)
    return J.CharacterData(KILLS_KEY, create)
end

local function Place(out, n, boss, at, took)
    local count = #out
    if count == n and at <= out[n].at then return end
    local kill
    if count == n then
        kill = out[n]
        out[n] = nil
        count = count - 1
    else
        kill = table.remove(spare) or {}
    end
    kill.boss, kill.dungeon, kill.at = boss, dungeonOf[boss], at
    kill.took = type(took) == "number" and took or false
    local i = count
    while i > 0 and out[i].at < at do
        out[i + 1] = out[i]
        i = i - 1
    end
    out[i + 1] = kill
end

local function PlaceRecord(out, n, boss, record)
    local at = boss and type(record) == "table" and record.at
    if type(at) ~= "table" then return end
    local took = type(record.took) == "table" and record.took or nil
    for i = 1, #at do
        if type(at[i]) == "number" then Place(out, n, boss, at[i], took and took[i]) end
    end
end

local function Alongside(record, key)
    local list = record[key]
    if type(list) ~= "table" then
        list = {}
        record[key] = list
    end
    for i = #list + 1, #record.at do list[i] = false end
    return list
end

local function KillNear(at, when)
    local best, gap
    for i = 1, #at do
        local d = type(at[i]) == "number" and math.abs(when - at[i])
        if d and d <= DROP_WINDOW and (not gap or d < gap) then best, gap = i, d end
    end
    return best
end

local function LinesFor(i)
    local list = lines[i]
    if list then return list end
    list = table.remove(linePool) or {}
    lines[i] = list
    return list
end

local function GatherDrop(record, drop, offset)
    local link, started = drop.itemHyperlink, drop.startTime
    if type(link) ~= "string" or issecretvalue(link) or type(started) ~= "number" then return end
    if not (drop.winner or drop.allPassed) then return end
    local i = KillNear(record.at, started / MILLISECONDS + offset)
    if not i then return end
    local list = LinesFor(i)
    list[#list + 1] = link .. DROP_FIELD .. (Team.KeepRolls(drop) or "")
end

local function Gather(encounterID)
    local boss = BossFor(encounterID)
    local record = boss and J.Kills.Record(boss)
    if not (record and C_LootHistory) or #record.at == 0 then return end
    local offset = time() - GetTime()
    wipe(lines)
    for _, drop in ipairs(C_LootHistory.GetSortedDropsForEncounter(encounterID) or EMPTY) do
        GatherDrop(record, drop, offset)
    end
    local drops = Alongside(record, "drops")
    for i, list in pairs(lines) do
        drops[i] = table.concat(list, DROP_LINE)
        wipe(list)
        linePool[#linePool + 1] = list
    end
end

local Kills = { KEEP = KEEP }
J.Kills = Kills

function Kills.Counted(boss)
    return boss.encounters ~= nil
end

function Kills.Record(boss)
    local id = boss.encounters and boss.encounters[1]
    local mine = id and Mine(false)
    local record = mine and mine[id]
    if type(record) == "table" and type(record.n) == "number" then return record end
end

local function RunOver(run, map, now, login)
    if run.map ~= map or not run.at or now - run.at > RUN_MAX then return true end
    return run.left ~= nil and (login or now - run.left > RUN_GRACE)
end

function Kills.NoteRun(here, login)
    local run = J.CharacterData(RUN_KEY, true)
    if not run then return end
    local now = time()
    if here then
        local map = select(INSTANCE_ID, GetInstanceInfo())
        if RunOver(run, map, now, login) then run.map, run.at = map, now end
        run.left = nil
    elseif login then
        run.map, run.at, run.left = nil, nil, nil
    elseif run.at and not run.left then
        run.left = now
    end
end

function Kills.ThisRun(boss)
    local run = J.CharacterData(RUN_KEY)
    local record = run and run.at and not run.left and Kills.Record(boss)
    local at = record and record.at
    local last = at and at[#at]
    return type(last) == "number" and last >= run.at
end

function Kills.Count(boss)
    local record = Kills.Record(boss)
    return record and record.n or 0
end

function Kills.Latest(n, out)
    for i = #out, 1, -1 do
        spare[#spare + 1] = out[i]
        out[i] = nil
    end
    local mine = Mine(false)
    if not mine then return out end
    for key, record in pairs(mine) do PlaceRecord(out, n, BossFor(key), record) end
    return out
end

function Kills.Best(record)
    local best, at = record.best, record.bestAt
    if type(best) ~= "number" then best, at = nil, nil end
    local took = type(record.took) == "table" and record.took or EMPTY
    for i = 1, #record.at do
        local length = took[i]
        if type(length) == "number" and (not best or length < best) then best, at = length, record.at[i] end
    end
    return best, at
end

function Kills.EachDrop(text, each)
    if type(text) ~= "string" then return end
    for line in text:gmatch(EACH_LINE) do
        local link, rolls = line:match(LINK_AND_ROLLS)
        if link and link ~= "" then each(link, rolls) end
    end
end

function Kills.Forget()
    local mine = Mine(false)
    if mine then wipe(mine) end
end

local function NewRecord(record, boss, length, now)
    local best = Kills.Best(record)
    if not length or (best and length >= best) then return end
    if best then
        local Length = J.View.Parts.FightLength
        ns.Print(TEXT_RECORD:format(boss.name, Length(length), Length(best)))
    end
    record.best, record.bestAt = length, now
end

local function RecordFor(mine, key, now)
    local record = mine[key]
    if type(record) == "table" then return record end
    record = { n = 0, first = now, at = {}, took = {} }
    mine[key] = record
    return record
end

local function Add(boss, took, team)
    local mine = Mine(true)
    if not mine then return end
    local now = time()
    local record = RecordFor(mine, boss.encounters[1], now)
    local at, lengths = record.at, record.took
    local teams, drops = Alongside(record, "team"), Alongside(record, "drops")
    local length = took and math.floor(took + ROUND)
    NewRecord(record, boss, length, now)
    if #at >= KEEP then
        table.remove(at, 1)
        table.remove(lengths, 1)
        table.remove(teams, 1)
        table.remove(drops, 1)
    end
    if Kills.ThisRun(boss) then
        local run = J.CharacterData(RUN_KEY)
        if run then run.at = now end
    end
    record.n = record.n + 1
    at[#at + 1] = now
    lengths[#lengths + 1] = length or false
    teams[#teams + 1] = team or false
    drops[#drops + 1] = false
    J.RedrawDungeonMaps()
end
Kills.Add = Add

function Kills.Gather(boss)
    local ids = boss.encounters
    for i = 1, ids and #ids or 0 do Gather(ids[i]) end
end

local function OnEncounter(event, encounterID, success)
    if issecretvalue(encounterID) or issecretvalue(success) then return end
    if event == "ENCOUNTER_START" then
        pulled[encounterID] = GetTime()
        return
    end
    local started = pulled[encounterID]
    pulled[encounterID] = nil
    local boss = success == KILLED and BossFor(encounterID)
    if boss then Add(boss, started and GetTime() - started, Team.Now()) end
end

local function OnEvent(_, event, encounterID, _, _, _, success)
    if event == "PLAYER_ENTERING_WORLD" then
        Kills.NoteRun(J.Current(), encounterID == true)
        return
    end
    if event == "LOOT_HISTORY_UPDATE_DROP" then
        if not issecretvalue(encounterID) then Gather(encounterID) end
        return
    end
    OnEncounter(event, encounterID, success)
end

local function Sync()
    local on = S.Get("enabled")
    if not (on or frame) then return end
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", OnEvent)
    end
    if not on then
        frame:UnregisterAllEvents()
        wipe(pulled)
        return
    end
    for _, event in ipairs(EVENTS) do frame:RegisterEvent(event) end
    if C_LootHistory then frame:RegisterEvent("LOOT_HISTORY_UPDATE_DROP") end
end

local function OnSettingChanged(key)
    if key == "enabled" then Sync() end
end

S.OnChange(OnSettingChanged)
hooksecurefunc(ns, "Apply", Sync)

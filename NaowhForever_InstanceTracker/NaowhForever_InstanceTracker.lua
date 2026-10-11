-- InstanceTracker.lua: each dungeon or raid visit, and how many new instances this account entered this hour.
local ns = _G.NaowhForever
local UI = ns.UI
local T = ns.THEME

local S = UI.ModuleSettings("instanceTracker", {
    enabled = false,
    showFrame = false,
    enterChat = false,
    -- Party, raid, or instance chat when this character leads a reset. Off still
    -- tells Nova Instance Tracker users in the group, and sends no chat line.
    resetChat = false,
    leaveChat = false,
    leaveWhere = "self",
    leaveTime = false,
    leaveXP = false,
    leaveGold = false,
    leaveDeaths = false,
    leaveRep = false,
    leaveAverage = false,
    leaveRunsLevel = false,
    leaveRunsToLevel = false,
    -- Skip the leave summary when the visit gained nothing.
    leaveActivity = false,
    -- Dungeons only until this is on. Raid chat is a separate choice.
    leaveRaids = false,
    leavePrintRaid = false,
    -- Other characters' visits, and the rest and durability sheet. Not the hourly cap.
    trackAlts = false,
    -- How many entries short of the account's 10-per-hour cap to warn. 1 warns at 9 of 10.
    hourlyWarn = 1,
    -- The module window, 0 to 1. The slider shows it as a percent.
    windowAlpha = 1,
})
ns.InstanceTrackerSettings = S

local MAX_RUNS = 80
local HOUR = 3600
local HOURLY_CAP = 10

-- Run timer. Sizes are pixels at the addon's UI scale.
local TIME_GAP = 2           -- between the clock and the lines under it
local LINE_GAP = 1           -- between the loot and hour lines
local TIME_SIZE = 16
local BODY_SIZE = 12         -- the loot and hour lines
local TIME_LINE = 20         -- the clock's line, taller than its font
local BODY_LINE = 16         -- a stat line
local DEFAULT_Y = -180       -- where the timer first sits, under the top of the screen
local COIN_ICON = 12         -- the coin textures beside a loot amount
local BODY_H = TIME_LINE + TIME_GAP + BODY_LINE + LINE_GAP + BODY_LINE
local SETTINGS_PAGE = "Instance Tracker/Settings"
local TIMER_CARD = "timer"

local CAP_RGB = ns.Shared.Style.RED_RGB
local WARN_RGB = ns.Shared.Style.WARN_RGB

local frame, clock, unlocked
local dismissedAt             -- the visit whose X hid the timer, until the next one
local goldPattern, silverPattern, copperPattern, repPattern
local events

local UpdateFrame, CloseRun, BeginRun

local function On()
    return S.Get("enabled")
end

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

-- Each character is account.instanceTrackerChars[UnitGUID]. The old name-keyed
-- instanceTracker blob is left unread: a name cannot tell two alts apart.
local CHARS_KEY = "instanceTrackerChars"
local GUID_PREFIX = "Player-"

local function PlayerGUID()
    local guid = UnitGUID("player")
    if Secret(guid) or type(guid) ~= "string" or guid == "" then return nil end
    return guid
end

local function AllChars()
    local all = ns.AccountSettings()[CHARS_KEY]
    if type(all) ~= "table" then return nil end
    return all
end

local function IsCharKey(key)
    return type(key) == "string" and key:find(GUID_PREFIX, 1, true) == 1
end

-- This character's record. Nil before the game knows who you are, or when the
-- GUID comes back secret. create writes the record.
local function Mine(create)
    if not PlayerGUID() then return end
    return ns.Shared.CharacterData(CHARS_KEY, create)
end

local function OpenRun()
    local row = Mine(false)
    local open = row and row.open
    if type(open) ~= "table" then return nil end
    return open
end

local function RealmKey()
    local realm = GetRealmName()
    if not realm or Secret(realm) then realm = "" end
    local faction = UnitFactionGroup("player")
    if not faction or Secret(faction) then faction = "" end
    return realm .. "-" .. faction
end

-- UnitName, and a "Name-Realm" glued into one string, both stop at the hyphen.
local function BareName(name)
    if Secret(name) or type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then
        return ""
    end
    return name:match("^[^-]+") or name
end

-- UnitName is the first name ("Glyadin"). Nova messages arrive under a name.
local function FirstName()
    return BareName(UnitName("player"))
end

-- UnitFullName is the whole name ("Glyadin Skywolf"). A realm glued on the end is stripped.
local function FullName()
    return BareName(UnitFullName("player"))
end

-- Shown on the sheet, the history line and the hourly warning. The GUID is the key.
local function DisplayName()
    local full = FullName()
    if full ~= "" then return full end
    return FirstName()
end

local function WholeNumber(v)
    if Secret(v) or type(v) ~= "number" then return nil end
    return v
end

-- Equipped pieces that have durability, as one percentage. A secret read keeps the old one.
local function DurabilityPct()
    if not GetInventoryItemDurability then return nil end
    local first = INVSLOT_FIRST_EQUIPPED or 1
    local last = INVSLOT_LAST_EQUIPPED or 19
    local current, full = 0, 0
    for slot = first, last do
        local cur, max = GetInventoryItemDurability(slot)
        if Secret(cur) or Secret(max) then return nil end
        if type(cur) == "number" and type(max) == "number" and max > 0 then
            current, full = current + cur, full + max
        end
    end
    if full <= 0 then return nil end
    return math.floor(current / full * 100 + 0.5)
end

-- Experience, level and rest. Durability is a separate scan: it only changes on
-- UPDATE_INVENTORY_DURABILITY, so a kill does not walk every equipped slot.
local function SnapshotXP(row)
    local level = WholeNumber(UnitLevel("player"))
    if level then row.level = level end
    local _, class = UnitClass("player")
    if not Secret(class) and type(class) == "string" then row.class = class end
    local xp = WholeNumber(UnitXP("player"))
    if xp then row.xp = xp end
    local xpMax = WholeNumber(UnitXPMax("player"))
    if xpMax then row.xpMax = xpMax end
    if GetXPExhaustion then
        local rested = GetXPExhaustion()
        if not Secret(rested) then
            row.rested = type(rested) == "number" and rested or 0
        end
    end
    row.seen = time()
end

-- Rest and durability from this login. A failed read leaves the previous number in
-- place, so a secret combat value does not wipe the sheet. Gold stays with Mail & Alts.
local function SnapshotChar(row)
    SnapshotXP(row)
    local durability = DurabilityPct()
    if durability ~= nil then row.durability = durability end
end

local function TouchChar()
    local row = Mine(true)
    if not row then return end
    local name = DisplayName()
    if name ~= "" then row.name = name end
    row.realm = RealmKey()
    SnapshotChar(row)
    return row
end

-- Experience and level-up. A record that does not exist yet still gets the full sheet,
-- durability included, so the first write is complete.
local function TouchXP()
    local row = Mine(false)
    if type(row) ~= "table" then
        TouchChar()
        return
    end
    SnapshotXP(row)
end

local function FormatDuration(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds < 0 then seconds = 0 end
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor(seconds % 3600 / 60)
    local secs = seconds % 60
    if hours > 0 then return string.format("%d:%02d:%02d", hours, minutes, secs) end
    return string.format("%d:%02d", minutes, secs)
end

-- Time inside the visit. skipped is the gap while logged out, reloading, or outside
-- this copy, so a resumed visit does not count the time spent away. seen is that
-- gap while it is still open, so the timer stays put at a graveyard.
local function Elapsed(open, now)
    now = now or time()
    local skipped = tonumber(open.skipped) or 0
    local seen = tonumber(open.seen)
    if seen and seen < now then skipped = skipped + (now - seen) end
    local elapsed = now - (tonumber(open.entered) or now) - skipped
    if elapsed < 0 then return 0 end
    return elapsed
end

-- Plain coins for a line sent to the group. Textures from the coin API are for this client.
local function PlainCoins(copper)
    copper = math.floor(tonumber(copper) or 0)
    if copper < 0 then copper = 0 end
    return string.format("%dg %ds %dc", math.floor(copper / 10000),
        math.floor(copper / 100) % 100, copper % 100)
end

local function Coins(copper)
    copper = math.floor(tonumber(copper) or 0)
    if copper < 0 then copper = 0 end
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(copper, COIN_ICON)
    end
    return PlainCoins(copper)
end

-- "%d Gold" and the silver and copper phrases, so a loot line can be summed in any locale.
local function CoinPattern(phrase)
    return phrase:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%d", "(%%d+)")
end

local function LootedCopper(text)
    if type(text) ~= "string" or Secret(text) then return 0 end
    if not goldPattern then
        if type(GOLD_AMOUNT) ~= "string" or type(SILVER_AMOUNT) ~= "string"
            or type(COPPER_AMOUNT) ~= "string" then
            return 0
        end
        goldPattern = CoinPattern(GOLD_AMOUNT)
        silverPattern = CoinPattern(SILVER_AMOUNT)
        copperPattern = CoinPattern(COPPER_AMOUNT)
    end
    return (tonumber(text:match(goldPattern)) or 0) * 10000
        + (tonumber(text:match(silverPattern)) or 0) * 100
        + (tonumber(text:match(copperPattern)) or 0)
end

local function CurrentInstance()
    local inInstance, kind = IsInInstance()
    if Secret(inInstance) or Secret(kind) then return nil, "secret" end
    if not inInstance or (kind ~= "party" and kind ~= "raid") then return nil, "out" end
    local name, _, _, difficultyName, _, _, _, mapID = GetInstanceInfo()
    if Secret(name) or Secret(difficultyName) or Secret(mapID) then return nil, "secret" end
    if type(name) ~= "string" or name == "" then return nil, "out" end
    if type(difficultyName) ~= "string" then difficultyName = "" end
    if type(mapID) ~= "number" then mapID = 0 end
    return name, "in", kind, difficultyName, mapID
end

-- Dead or a ghost. nil when that read is secret, so the visit stays open
-- rather than being announced as a leave.
local function PlayerGhost()
    if not UnitIsDeadOrGhost then return false end
    local dead = UnitIsDeadOrGhost("player")
    if Secret(dead) then return nil end
    return dead and true or false
end

local function SamePlace(open, name, mapID, difficulty)
    if open.instance ~= name or (open.difficulty or "") ~= difficulty then return false end
    local saved = open.mapID or 0
    return saved == 0 or mapID == 0 or saved == mapID
end

local function LastRun(instance)
    local row = Mine(false)
    local runs = row and row.runs
    if type(runs) ~= "table" then return end
    for i = 1, #runs do
        local run = runs[i]
        if type(run) == "table" and run.instance == instance then
            return run
        end
    end
end

-- Experience and level stay registered while the module is on, so the alt sheet
-- keeps up outside a dungeon. These only matter during a visit.
local RUN_EVENTS = {
    "CHAT_MSG_MONEY", "CHAT_MSG_COMBAT_FACTION_CHANGE", "PLAYER_DEAD",
    "PLAYER_ALIVE", "PLAYER_UNGHOST", "GROUP_ROSTER_UPDATE",
    "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED",
    "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START",
}

local function SetRunEvents(active)
    for i = 1, #RUN_EVENTS do
        if active then
            events:RegisterEvent(RUN_EVENTS[i])
        else
            events:UnregisterEvent(RUN_EVENTS[i])
        end
    end
end

-- Baseline on enter; later calls add the gain, including the bar that a level-up clears.
local function NoteXP(baseline)
    local open = OpenRun()
    if not open then return end
    local xp, maxXP = UnitXP("player"), UnitXPMax("player")
    if Secret(xp) or Secret(maxXP) or type(xp) ~= "number" then return end
    if type(maxXP) ~= "number" then maxXP = 0 end
    if baseline or not open.lastXP then
        open.lastXP, open.lastMax = xp, maxXP
        return
    end
    if xp >= open.lastXP then
        open.xp = (open.xp or 0) + (xp - open.lastXP)
    else
        local span = (open.lastMax or 0) - open.lastXP
        if span < 0 then span = 0 end
        open.xp = (open.xp or 0) + span + xp
    end
    open.lastXP, open.lastMax = xp, maxXP
end

local function AddLoot(text)
    local open = OpenRun()
    if not open then return end
    local copper = LootedCopper(text)
    if copper <= 0 then return end
    open.loot = (open.loot or 0) + copper
    UpdateFrame()
end

-- "Reputation with %s increased by %d." Recorded while a visit is open; printed only
-- when that line is turned on.
local function NoteRep(text)
    local open = OpenRun()
    if not open or type(text) ~= "string" or Secret(text) then return end
    if not repPattern then
        if type(FACTION_STANDING_INCREASED) ~= "string" then return end
        repPattern = "^" .. FACTION_STANDING_INCREASED:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
            :gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)") .. "$"
    end
    local faction, amount = text:match(repPattern)
    amount = tonumber(amount)
    if not faction or not amount or amount <= 0 then return end
    if type(open.rep) ~= "table" then open.rep = {} end
    open.rep[faction] = (open.rep[faction] or 0) + amount
end

-- "Deadmines" or "Deadmines (Heroic)". The history page uses the same line.
local function PlaceName(name, difficulty)
    if type(difficulty) == "string" and difficulty ~= "" then
        return (name or "") .. " (" .. difficulty .. ")"
    end
    return name or ""
end

local function Where(open)
    return PlaceName(open.instance, open.difficulty)
end

local function AnnounceResume(open)
    if not S.Get("enterChat") or not open.instance then return end
    ns.Print(ns.L("Resumed %s.", Where(open)))
end

local function AnnounceEnter(open)
    if not S.Get("enterChat") or not open.instance then return end
    ns.Print(ns.L("Entered %s.", Where(open)))
    local last = LastRun(open.instance)
    if last and last.left and last.entered then
        ns.Print(ns.L("Last visit: %s, looted %s.",
            FormatDuration(last.left - last.entered), Coins(last.loot)))
    end
end

local function VisitActive(open)
    if (open.xp or 0) > 0 or (open.loot or 0) > 0 or (open.deaths or 0) > 0 then
        return true
    end
    if type(open.rep) ~= "table" then return false end
    for _, amount in pairs(open.rep) do
        if (amount or 0) > 0 then return true end
    end
    return false
end

-- Faction, then the amount, factions in order. Nil when none was gained. The history
-- page prints the same words.
local function Reputation(rep)
    if type(rep) ~= "table" then return end
    local parts = {}
    for faction, amount in pairs(rep) do
        if type(faction) == "string" and (amount or 0) > 0 then
            parts[#parts + 1] = faction .. " +" .. BreakUpLargeNumbers(amount)
        end
    end
    if #parts == 0 then return end
    table.sort(parts)
    return table.concat(parts, ", ")
end

local function RunsFor(open, instanceOnly)
    local row = Mine(false)
    local runs = row and row.runs
    local list = {}
    if type(runs) ~= "table" then return list end
    for i = 1, #runs do
        local run = runs[i]
        if type(run) == "table" and (not instanceOnly or run.instance == open.instance) then
            list[#list + 1] = run
        end
    end
    return list
end

-- Raid when raidChat is set, else nothing while in a raid, so a leave summary stays
-- out of raid chat unless that option is on. Then the instance group, then the party.
-- Alone, nothing is sent.
local function GroupChannel(raidChat)
    if IsInRaid then
        local raid = IsInRaid()
        if not Secret(raid) and raid then
            if raidChat then return "RAID" end
            return nil
        end
    end
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup then
        local instance = IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
        if not Secret(instance) and instance then return "INSTANCE_CHAT" end
    end
    if IsInGroup then
        local group = IsInGroup()
        if not Secret(group) and group then return "PARTY" end
    end
end

-- One chat message. Longer summaries become a second complete message, split between
-- facts, rather than cut in the middle of one.
local CHAT_LIMIT = 255

local function LeaveFacts(open, span, plain)
    local facts = {}
    local function add(text) facts[#facts + 1] = text end
    if S.Get("leaveTime") then add(FormatDuration(span)) end
    if S.Get("leaveXP") then
        add(ns.L("%s XP", BreakUpLargeNumbers(open.xp or 0)))
    end
    if S.Get("leaveGold") then
        add(plain and PlainCoins(open.loot) or Coins(open.loot))
    end
    if S.Get("leaveDeaths") then
        local n = open.deaths or 0
        add(n == 1 and ns.L("1 death") or ns.L("%d deaths", n))
    end
    if S.Get("leaveRep") then
        local rep = Reputation(open.rep)
        if rep then add(ns.L("%s reputation", rep)) end
    end
    if S.Get("leaveAverage") then
        local runs = RunsFor(open, true)
        local total, n = 0, 0
        for i = 1, #runs do
            if (runs[i].xp or 0) > 0 then
                total = total + runs[i].xp
                n = n + 1
            end
        end
        if n > 0 then
            add(ns.L("%s XP on average", BreakUpLargeNumbers(math.floor(total / n + 0.5))))
        end
    end
    if S.Get("leaveRunsLevel") and open.level then
        local runs = RunsFor(open, false)
        local n = 0
        for i = 1, #runs do
            if runs[i].level == open.level then n = n + 1 end
        end
        add(ns.L("%d runs this level", n))
    end
    if S.Get("leaveRunsToLevel") and (open.xp or 0) > 0
        and (open.lastMax or 0) > (open.lastXP or 0) then
        local more = math.ceil((open.lastMax - open.lastXP) / open.xp)
        if more > 0 then add(ns.L("about %d more to the next level", more)) end
    end
    return facts
end

local function Sentence(place, facts)
    if #facts == 0 then return end
    return place .. " " .. table.concat(facts, ", ") .. "."
end

local function SendAccepted(ok, result, success)
    if not ok then return false end
    if result == nil or result == true then return true end
    return result == success
end

-- A secret answer is treated as locked, so a leave summary is printed here instead of
-- erroring after the visit has already been closed.
local function ChatLocked()
    local locked = C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
    if Secret(locked) or locked then return true end
    return false
end

local function SendLine(text, channel)
    if type(text) ~= "string" or text == "" or #text > CHAT_LIMIT then return false end
    local ok, result = pcall(C_ChatInfo.SendChatMessage, text, channel)
    local success = Enum and Enum.SendChatMessageResult and Enum.SendChatMessageResult.Success
    return SendAccepted(ok, result, success)
end

-- Complete facts, joined by commas, with a period on each message.
local function SendFacts(channel, facts, fallback)
    local chunk = ""
    local function flush()
        if chunk == "" then return true end
        local line = chunk .. "."
        chunk = ""
        if SendLine(line, channel) then return true end
        ns.Print(fallback)
        return false
    end
    for i = 1, #facts do
        local joined = chunk == "" and facts[i] or (chunk .. ", " .. facts[i])
        if #joined + 1 > CHAT_LIMIT and chunk ~= "" then
            if not flush() then return end
            joined = facts[i]
        end
        chunk = joined
    end
    flush()
end

local function Deliver(shown, place, facts)
    if S.Get("leaveWhere") ~= "group" then
        ns.Print(shown)
        return
    end
    local channel = GroupChannel(S.Get("leavePrintRaid"))
    if not channel or ChatLocked() then
        ns.Print(shown)
        return
    end
    local body = table.concat(facts, ", ") .. "."
    local group = place .. " " .. body
    if #group <= CHAT_LIMIT then
        if not SendLine(group, channel) then ns.Print(shown) end
        return
    end
    if not SendLine(place, channel) then
        ns.Print(shown)
        return
    end
    SendFacts(channel, facts, shown)
end

local function AnnounceLeave(open, span)
    if not S.Get("leaveChat") or not open.instance then return end
    if open.kind == "raid" and not S.Get("leaveRaids") then return end
    if S.Get("leaveActivity") and not VisitActive(open) then return end
    local place = ns.L("Left %s.", Where(open))
    local shown = Sentence(place, LeaveFacts(open, span, false))
    if not shown then return end
    if S.Get("leaveWhere") ~= "group" then
        ns.Print(shown)
        return
    end
    Deliver(shown, place, LeaveFacts(open, span, true))
end

-- A group member, as a short name, or Name-Realm when they are from somewhere else.
-- Forever has been seen to hand back "Name-Realm" in the first return.
local function MemberName(unit)
    local name, realm = UnitFullName(unit)
    if Secret(name) or Secret(realm) or type(name) ~= "string" then return end
    name = name:match("^[^-]+") or name
    if name == "" or name == UNKNOWNOBJECT then return end
    local mine = (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName()
    if Secret(mine) then mine = nil end
    if type(realm) == "string" and realm ~= "" and realm ~= mine then
        name = name .. "-" .. realm
    end
    return name
end

-- Unit prefix and how many, or nothing when the group is secret or we are alone.
-- count can be 0. Callers decide whether that is an empty roster.
local function GroupShape()
    if not IsInGroup then return end
    local grouped = IsInGroup()
    if Secret(grouped) or not grouped then return end
    local raid = false
    if IsInRaid then
        local inRaid = IsInRaid()
        if not Secret(inRaid) and inRaid then raid = true end
    end
    local count = raid and GetNumGroupMembers() or GetNumSubgroupMembers()
    if Secret(count) or type(count) ~= "number" then return end
    return (raid and "raid" or "party"), count
end

-- Everyone else currently in the group. The visit already names this character.
local function CurrentGroup()
    local list = {}
    local prefix, count = GroupShape()
    if not prefix or count < 1 then return list end
    for i = 1, count do
        local unit = prefix .. i
        local mine = UnitIsUnit(unit, "player")
        if not Secret(mine) and not mine then
            local name = MemberName(unit)
            if name then list[#list + 1] = { name = name } end
        end
    end
    return list
end

-- Write the group onto the visit, names only. Someone who leaves before the end
-- stays, so a later return can tell this group from a new one. A name that has
-- not loaded yet is filled in later. The Journal lists who was there on a kill.
local function NoteGroup(open)
    if type(open) ~= "table" then return false end
    local members = CurrentGroup()
    if #members == 0 then return false end
    local group = type(open.group) == "table" and open.group or nil
    local known = {}
    if group then
        for i = 1, #group do
            local row = group[i]
            if type(row) == "table" and type(row.name) == "string" then
                known[row.name] = row
            end
        end
    end
    local changed = false
    for i = 1, #members do
        local member = members[i]
        if member.name ~= open.name then
            local row = known[member.name]
            if not row then
                if not group then
                    group = {}
                    open.group = group
                end
                row = { name = member.name }
                group[#group + 1] = row
                known[member.name] = row
                changed = true
            end
        end
    end
    return changed
end

-- This character keeps MAX_RUNS of their own.
local function TrimRuns(runs)
    for i = #runs, MAX_RUNS + 1, -1 do runs[i] = nil end
end

-- at is a logout stamp, used when the leave itself was not seen live. quiet skips the
-- display refresh when the caller is about to start another visit immediately.
CloseRun = function(announce, at, quiet)
    local row = Mine(false)
    local open = row and row.open
    if type(open) ~= "table" then
        SetRunEvents(false)
        return
    end
    row.open = nil
    SetRunEvents(false)
    if type(row.runs) ~= "table" then row.runs = {} end
    local left = at or time()
    if left < (open.entered or left) then left = time() end
    local span = Elapsed(open, left)
    local start = open.entered or left
    local repGain = false
    if type(open.rep) == "table" then
        for _, amount in pairs(open.rep) do
            if (amount or 0) > 0 then repGain = true end
        end
    end
    NoteGroup(open)
    local group = open.group
    if type(group) ~= "table" or #group == 0 then group = nil end
    local worth = span >= 1 or (open.loot or 0) > 0 or (open.xp or 0) > 0
        or (open.deaths or 0) > 0 or repGain
    if worth then
        local runs = row.runs
        table.insert(runs, 1, {
            name = open.name, class = open.class,
            instance = open.instance, mapID = open.mapID, kind = open.kind,
            difficulty = open.difficulty or "",
            entered = start, left = start + span, level = open.level,
            loot = open.loot or 0, xp = open.xp or 0, deaths = open.deaths or 0,
            rep = open.rep, group = group,
        })
        TrimRuns(runs)
        if announce then AnnounceLeave(open, span) end
    end
    if quiet then return end
    UpdateFrame()
    UI:RefreshPage(true)
end

-- A new dungeon or raid counts toward one account cap of 10 in a rolling hour.
-- A ghost, or a death the client kept secret, does not close the visit. A reload
-- while still inside does not count. A different group does. A later matching
-- zone id can take that count back.
local expiryGen = 0
local hourSnap

local function CopyKey(mapID, difficulty, name)
    if type(mapID) ~= "number" or mapID == 0 then
        return "name:" .. (name or "") .. ":" .. (difficulty or "")
    end
    return tostring(mapID) .. ":" .. (difficulty or "")
end

-- Copies this character has not reset, on their own record.
local function LiveCopies(create)
    local row = Mine(create)
    if not row then return end
    if type(row.live) ~= "table" then
        if not create then return end
        row.live = {}
    end
    return row.live
end

local function ByAt(a, b)
    return a.at < b.at
end

-- Drops hour entries older than an hour. Oldest first. Any removal drops the
-- cached account count, because that count is the sum of every character.
local function PruneHour(row)
    if type(row) ~= "table" then return {} end
    local list = row.hour
    if type(list) ~= "table" then
        row.hour = {}
        return row.hour
    end
    local now = time()
    local count, write, ordered, prev, removed = #list, 1, true, nil, false
    for i = 1, count do
        local entry = list[i]
        if type(entry) == "table" and type(entry.at) == "number" and now - entry.at < HOUR then
            if prev and prev.at > entry.at then ordered = false end
            prev = entry
            if write ~= i then list[write] = entry end
            write = write + 1
        else
            removed = true
        end
    end
    for i = count, write, -1 do list[i] = nil end
    if removed then hourSnap = nil end
    if not ordered then table.sort(list, ByAt) end
    return list
end

local function WarnDistance()
    local n = math.floor(tonumber(S.Get("hourlyWarn")) or 1)
    if n < 1 then return 1 end
    if n > 5 then return 5 end
    return n
end

-- Entries still inside the hour, across every character's list. A stamp an hour
-- old or older drops out. The next free time is the oldest stamp that remains.
-- The regression loads this function. Track Alts is not an input.
local function AccountHour(lists, now, hour)
    local count, oldest = 0, nil
    if type(lists) ~= "table" or type(now) ~= "number" or type(hour) ~= "number" then
        return 0, 0, nil
    end
    for i = 1, #lists do
        local list = lists[i]
        if type(list) == "table" then
            for j = 1, #list do
                local entry = list[j]
                local at = type(entry) == "table" and entry.at or nil
                if type(at) == "number" and now - at < hour then
                    count = count + 1
                    if not oldest or at < oldest then oldest = at end
                end
            end
        end
    end
    local frees = 0
    if oldest then
        frees = oldest + hour - now
        if frees < 0 then frees = 0 end
    end
    return count, frees, oldest
end

local function HourLists()
    local lists, all = {}, AllChars()
    if not all then return lists end
    for guid, row in pairs(all) do
        if IsCharKey(guid) and type(row) == "table" then
            lists[#lists + 1] = PruneHour(row)
        end
    end
    return lists
end

local function HourSnapshot()
    local now = time()
    if hourSnap and (not hourSnap.oldest or now < hourSnap.oldest + HOUR) then
        local frees = 0
        if hourSnap.oldest then
            frees = hourSnap.oldest + HOUR - now
            if frees < 0 then frees = 0 end
        end
        return hourSnap.count, HOURLY_CAP, frees
    end
    if not AllChars() and not PlayerGUID() then return 0, HOURLY_CAP, 0 end
    local lists = HourLists()
    local count, frees, oldest = AccountHour(lists, time(), HOUR)
    hourSnap = { count = count, oldest = oldest }
    return count, HOURLY_CAP, frees
end

-- The note sits on this character, so an alt already warned does not swallow it.
-- The numbers are the account's, and the line does not say who used one.
local function WarnHour()
    if not On() then return end
    local row = Mine(false)
    if not row then return end
    local count, cap, frees = HourSnapshot()
    local left = cap - count
    if left < 0 then left = 0 end
    if count <= 0 or left > WarnDistance() then
        row.hourNoted = nil
        return
    end
    local state = left <= 0 and "cap" or "close"
    if row.hourNoted == state then return end
    row.hourNoted = state
    local when = FormatDuration(frees)
    if left <= 0 then
        ns.Print(ns.L("This account has used %d of %d instances this hour. A new instance will not let you in. The next one frees in %s.",
            count, cap, when))
    else
        ns.Print(ns.L("This account has used %d of %d instances this hour. %d left before a new instance will not let you in. The next one frees in %s.",
            count, cap, left, when))
    end
end

local function StopExpiry()
    expiryGen = expiryGen + 1
end

local function ScheduleExpiry()
    StopExpiry()
    if not On() then return end
    HourSnapshot()
    if not hourSnap or not hourSnap.oldest then return end
    local delay = hourSnap.oldest + HOUR - time()
    if delay < 1 then delay = 1 end
    local gen = expiryGen
    C_Timer.After(delay, function()
        if gen ~= expiryGen then return end
        hourSnap = nil
        WarnHour()
        UpdateFrame()
        UI:RefreshPage(true)
        ScheduleExpiry()
    end)
end

-- A stamp inside the hour is still this copy. An older stamp is not. A login
-- does not count. The block through CopyParts is loaded by the regression.
local function CopyFresh(stored, now, hour)
    if type(stored) ~= "table" or type(stored.at) ~= "number" then return false end
    if type(now) ~= "number" or type(hour) ~= "number" then return false end
    local age = now - stored.at
    return age >= 0 and age < hour
end

-- True when this zone-in adds an hourly entry. A login or reload does not.
local function CountsEntry(stored, now, hour, countIt)
    if not countIt then return false end
    return not CopyFresh(stored, now, hour)
end

-- True when the people zoning in are not the visit's group. One shared name keeps
-- the visit. Two empty groups are the same solo copy. An empty roster while still
-- grouped has not loaded, so it does not split the visit.
local function GroupsDiffer(saved, current, inGroup)
    local function names(group)
        local set, n = {}, 0
        if type(group) ~= "table" then return set, 0 end
        for i = 1, #group do
            local row = group[i]
            local who = type(row) == "table" and row.name or nil
            if type(who) == "string" and who ~= "" and not set[who] then
                set[who] = true
                n = n + 1
            end
        end
        return set, n
    end
    local savedSet, savedN = names(saved)
    local hereSet, hereN = names(current)
    for who in pairs(savedSet) do
        if hereSet[who] then return false end
    end
    if savedN == 0 and hereN == 0 then return false end
    if hereN == 0 and inGroup then return false end
    return true
end

-- A closed visit reopens only while the hour still treats the stamp as this copy,
-- and the saved run was left inside that same hour.
local function CanResume(stored, left, now, hour)
    if not CopyFresh(stored, now, hour) then return false end
    if type(left) ~= "number" then return false end
    local away = now - left
    return away >= 0 and away < hour
end

-- A ghost, or a death the client kept secret, is still this visit. A plain
-- false is a living player outside, and that leave can close it.
local function KeepsVisit(ghost)
    return ghost ~= false
end

-- unitType-0-server-instanceID-zoneUID-id-spawn. instanceID is the map and is
-- 0 outdoors, so it cannot tell one reset from the next. zoneUID is the copy.
-- A player GUID has neither. A secret value is not split and is not saved.
local COPY_KINDS = {
    Creature = true, Pet = true, GameObject = true, Vehicle = true, Cast = true,
}

local function PlainGuid(guid)
    if type(guid) ~= "string" or guid == "" then return false end
    if issecretvalue and issecretvalue(guid) then return false end
    if canaccessvalue and not canaccessvalue(guid) then return false end
    return true
end

local function CopyParts(guid)
    if not PlainGuid(guid) then return end
    local kind, _, _, instanceID, zoneUID = strsplit("-", guid)
    if not COPY_KINDS[kind] then return end
    instanceID = tonumber(instanceID)
    zoneUID = tonumber(zoneUID)
    if not instanceID or instanceID == 0 or not zoneUID or zoneUID == 0 then return end
    return zoneUID
end
-- end copy memory

-- countIt is false for a login or reload: that copy already existed. An existing
-- stamp stays put on that path, so a resume does not push the hour forward.
local function NoteInstanceEntry(name, mapID, difficulty, countIt)
    local row = Mine(true)
    if not row then return end
    if type(row.live) ~= "table" then row.live = {} end
    local lives = row.live
    local key = CopyKey(mapID, difficulty, name)
    local now = time()
    if not CountsEntry(lives[key], now, HOUR, countIt) then
        if lives[key] == nil then
            lives[key] = { name = name or "", at = now }
        end
        return
    end
    lives[key] = { name = name or "", at = now }
    if type(row.hour) ~= "table" then row.hour = {} end
    row.hour[#row.hour + 1] = { at = now, name = name or "", map = mapID }
    hourSnap = nil
    PruneHour(row)
    WarnHour()
    ScheduleExpiry()
end

-- Nova Instance Tracker, prefix "NIT". A reset is "<command> <version> <instance>"
-- (the name keeps its spaces), then LibSerialize, LibDeflate at level 9, and the
-- addon-channel encoding. Version 1 is the oldest Nova still reads.
-- instanceReset rides with a "[NIT] " chat line, which is what the group sees.
-- instanceResetNoMsg leaves that line out, and Nova prints it. instanceResetOther
-- is that print from Nova World Buffs. The block through ClearNamedCopy is loaded
-- by the regression.
local NIT_PREFIX = "NIT"
local NIT_VERSION = "1"
local NIT_STILL_INSIDE = "has been reset (Players still inside old instance can zone out and enter new)."
local NIT_RESET = {
    instanceReset = true,
    instanceResetNoMsg = true,
    instanceResetOther = true,
}
local NIT_CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true }

local function NitCodec()
    local LS = LibStub and LibStub("LibSerialize", true)
    local LD = LibStub and LibStub("LibDeflate", true)
    if not LS or not LD then return end
    return LS, LD
end

-- One addon message. AceComm treats a leading control byte as its own framing, so a
-- reset that starts with one is sent with the escape byte in front.
local function NitEncode(plain)
    if type(plain) ~= "string" or plain == "" then return end
    local LS, LD = NitCodec()
    if not LS then return end
    local serialized = LS:Serialize(plain)
    if type(serialized) ~= "string" then return end
    local compressed = LD:CompressDeflate(serialized, { level = 9 })
    if type(compressed) ~= "string" then return end
    local encoded = LD:EncodeForWoWAddonChannel(compressed)
    if type(encoded) ~= "string" or encoded == "" or #encoded > 255 then return end
    return encoded
end

local function NitWire(plain)
    local encoded = NitEncode(plain)
    if not encoded then return end
    local lead = encoded:byte(1)
    if lead >= 1 and lead <= 9 then
        if #encoded >= 255 then return end
        return "\004" .. encoded
    end
    return encoded
end

local function NitDecode(payload)
    if type(payload) ~= "string" or payload == "" then return end
    local lead = payload:byte(1)
    if lead == 4 then
        payload = payload:sub(2)
        if payload == "" then return end
    elseif lead == 1 or lead == 2 or lead == 3 then
        return
    end
    local LS, LD = NitCodec()
    if not LS then return end
    local decoded = LD:DecodeForWoWAddonChannel(payload)
    if type(decoded) ~= "string" then return end
    local compressed = LD:DecompressDeflate(decoded)
    if type(compressed) ~= "string" then return end
    local ok, value = LS:Deserialize(compressed)
    if not ok or type(value) ~= "string" then return end
    return value
end

-- The first two words are the command and the version. The instance keeps its spaces.
local function NitFields(text)
    if type(text) ~= "string" then return end
    local cmd, version, rest = text:match("^(%S+)%s+(%S+)%s*(.*)$")
    if not cmd then return end
    if rest == "" then rest = nil end
    return cmd, version, rest
end

local function NitVersionOk(version)
    local n = tonumber(version)
    return n ~= nil and n >= 1
end

-- The name Nova prints: the sender, without a realm glued on the end.
local function NitWho(sender)
    if type(sender) ~= "string" or sender == "" then return end
    local name = sender:match("^([^%-]+)")
    if not name or name == "" then return end
    return name
end

-- A realm that is not ours is ignored. A roster match who is not the leader is
-- ignored. A name that matches no unit is still taken: Forever's addon sender is
-- often a full name no unit API returns, and Nova only sends this as the leader.
local function NitSenderOk(sender, realm, normalized, roster)
    if type(sender) ~= "string" or sender == "" then return false end
    local _, theirs = sender:match("^([^%-]+)%-(.+)$")
    if theirs and theirs ~= realm and theirs ~= normalized then return false end
    if type(roster) ~= "table" then return true end
    local who = NitWho(sender)
    local saw, leads = false, false
    for name, leader in pairs(roster) do
        if name == sender or name == who then
            saw = true
            if leader then leads = true end
        end
    end
    if saw then return leads end
    return true
end

-- The instance to forget, and a line to print when Nova sent no chat line.
local function NitIncoming(text, sender, realm, normalized, roster)
    local cmd, version, instance = NitFields(text)
    if not NIT_RESET[cmd] or not NitVersionOk(version) then return end
    if not NitSenderOk(sender, realm, normalized, roster) then return end
    if type(instance) ~= "string" or instance == "" then return end
    local line
    if cmd ~= "instanceReset" then
        line = instance .. ns.L(" has been reset by the group leader (") .. (NitWho(sender) or sender) .. ")."
    end
    return instance, line
end

-- kind is "success", "inside", "zoning" or "offline". chatOk is whether the group
-- line can go out. A failed chat send of a real reset uses instanceResetNoMsg, so
-- Nova still prints it. Zoning and offline are the chat line only.
local function NitOutbound(kind, instance, systemText, chatOk)
    if type(instance) ~= "string" or instance == "" then return end
    local body
    if kind == "inside" then
        body = instance .. " " .. NIT_STILL_INSIDE
    elseif kind == "success" or kind == "zoning" or kind == "offline" then
        body = systemText
    else
        return
    end
    if type(body) ~= "string" or body == "" then return end
    local chat = chatOk and ("[NIT] " .. body) or nil
    if kind ~= "success" and kind ~= "inside" then return chat end
    local cmd = chat and "instanceReset" or "instanceResetNoMsg"
    return chat, cmd .. " " .. NIT_VERSION .. " " .. instance
end

-- "chat" is the group line plus instanceReset. "addon" is instanceResetNoMsg and no
-- line, so Nova still prints the reset. nil sends nothing: Nova Instance Tracker is
-- loaded and posts the same line itself.
local function NitAnnounce(settingOn, nitLoaded, locked)
    if nitLoaded then return end
    if settingOn and not locked then return "chat" end
    return "addon"
end

-- Drops every live copy stored under this instance name. The hour list is left as
-- it is: a reset does not give an entry back.
local function ClearNamedCopy(lives, name)
    if type(lives) ~= "table" or type(name) ~= "string" or name == "" then return false end
    local cleared = false
    for key, stored in pairs(lives) do
        if type(stored) == "table" and stored.name == name then
            lives[key] = nil
            cleared = true
        end
    end
    return cleared
end
-- end Nova reset wire format

local function ForgetCopy(name)
    local mine = LiveCopies(false)
    if not mine then return end
    if name then
        ClearNamedCopy(mine, name)
    else
        for key in pairs(mine) do mine[key] = nil end
    end
end

local function ResetPattern(global)
    if type(global) ~= "string" or not global:find("%s", 1, true) then return end
    local pattern = global:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    return "^" .. pattern:gsub("%%%%s", "(.+)") .. "$"
end

local resetPatterns
local resetOrder = { "zoning", "offline", "inside", "success" }
local function ClassifyReset(text)
    if type(text) ~= "string" or Secret(text) then return end
    if not resetPatterns then
        resetPatterns = {
            zoning = ResetPattern(INSTANCE_RESET_FAILED_ZONING),
            offline = ResetPattern(INSTANCE_RESET_FAILED_OFFLINE),
            inside = ResetPattern(INSTANCE_RESET_FAILED),
            success = ResetPattern(INSTANCE_RESET_SUCCESS),
        }
    end
    for i = 1, #resetOrder do
        local kind = resetOrder[i]
        local pattern = resetPatterns[kind]
        if pattern then
            local name = text:match(pattern)
            if name then return kind, name end
        elseif kind == "success" and type(INSTANCE_RESET_SUCCESS) == "string"
            and text == INSTANCE_RESET_SUCCESS then
            return "success"
        end
    end
end

local function WeAreLeader()
    if not UnitIsGroupLeader then return false end
    local leader = UnitIsGroupLeader("player")
    if Secret(leader) or not leader then return false end
    return true
end

local function SendResetAddon(plain, channel)
    local encoded = NitWire(plain)
    if not encoded then return false end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, NIT_PREFIX, encoded, channel)
    local success = Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success
    return SendAccepted(ok, result, success)
end

-- Nova posts the same reset line. A secret answer is treated as loaded, so this
-- addon does not add a second one.
local function NitLoaded()
    if not C_AddOns or not C_AddOns.IsAddOnLoaded then return false end
    local loaded = C_AddOns.IsAddOnLoaded("NovaInstanceTracker")
    if Secret(loaded) then return true end
    return loaded and true or false
end

local function AnnounceReset(kind, name, text)
    if not WeAreLeader() then return end
    local channel = GroupChannel(true)
    if not channel then return end
    local locked = ChatLocked()
    local how = NitAnnounce(S.Get("resetChat"), NitLoaded(), locked)
    if not how then return end
    local chat, plain = NitOutbound(kind, name or "", text, how == "chat")
    if chat and not SendLine(chat, channel) then
        plain = select(2, NitOutbound(kind, name or "", text, false))
    end
    if plain then SendResetAddon(plain, channel) end
end

local function OnResetMessage(text)
    local kind, name = ClassifyReset(text)
    if not kind then return end
    if kind == "success" or kind == "inside" then ForgetCopy(name) end
    AnnounceReset(kind, name, text)
end

local function OurRealm()
    local realm = GetRealmName()
    if Secret(realm) or type(realm) ~= "string" then realm = "" end
    local normalized = (GetNormalizedRealmName and GetNormalizedRealmName()) or realm
    if Secret(normalized) or type(normalized) ~= "string" then normalized = realm end
    return realm, normalized
end

local function IsOwnSender(sender)
    if type(sender) ~= "string" or sender == "" then return true end
    local full, first = FullName(), FirstName()
    local realm, normalized = OurRealm()
    if sender == full or sender == first then return true end
    if full ~= "" and (sender == full .. "-" .. realm or sender == full .. "-" .. normalized) then
        return true
    end
    if first ~= "" and (sender == first .. "-" .. realm or sender == first .. "-" .. normalized) then
        return true
    end
    return false
end

-- Names that match a group unit, and whether that unit leads. No match is absent,
-- which the incoming check treats as still worth taking.
local function LeaderRoster()
    local roster = {}
    local prefix, count = GroupShape()
    if not prefix then return roster end
    local function note(unit)
        local leader = UnitIsGroupLeader and UnitIsGroupLeader(unit)
        if Secret(leader) then leader = false end
        leader = leader and true or false
        local name = MemberName(unit)
        if name then roster[name] = leader end
        local full = UnitFullName(unit)
        if not Secret(full) and type(full) == "string" and full ~= "" then roster[full] = leader end
    end
    note("player")
    for i = 1, count do
        local unit = prefix .. i
        local mine = UnitIsUnit(unit, "player")
        if Secret(mine) or not mine then note(unit) end
    end
    return roster
end

local function OnNovaReset(prefix, payload, channel, sender)
    if Secret(prefix) or prefix ~= NIT_PREFIX then return end
    if Secret(payload) or Secret(channel) or Secret(sender) then return end
    if not NIT_CHANNELS[channel] or IsOwnSender(sender) then return end
    local text = NitDecode(payload)
    if not text then return end
    local realm, normalized = OurRealm()
    local instance, line = NitIncoming(text, sender, realm, normalized, LeaderRoster())
    if not instance then return end
    ForgetCopy(instance)
    if line then ns.Print(line) end
end

-- ReadZone is filled in once the unit reads exist. The regression passes the
-- zone id into TakeSameCopy instead, so this stays unset there.
local ReadZone

-- seen is the regression's zone id: a number to compare, or false when every
-- sample was secret, missing, or outdoors. Otherwise read one from the client.
local function ObservedZone(seen)
    if seen == false then return nil end
    if type(seen) == "number" and seen ~= 0 then return seen end
    if ReadZone then return ReadZone() end
end

-- The copy this zone-in replaced, so a plain zone id later in the visit can
-- take the hour entry back. Without a stored id there is nothing to match.
local function RememberReentry(row, stored, run, key)
    if type(row) ~= "table" then return end
    if type(stored) ~= "table" or type(stored.copy) ~= "number" then return end
    row.reentry = { copy = stored.copy, at = stored.at, key = key, run = run }
end

local function AddRep(prior, gained)
    if type(gained) ~= "table" then return end
    if type(prior.rep) ~= "table" then prior.rep = {} end
    for faction, amount in pairs(gained) do
        if type(amount) == "number" and amount > 0 then
            prior.rep[faction] = (prior.rep[faction] or 0) + amount
        end
    end
end

-- This zone-in was already counted, and the zone id now matches the visit it
-- replaced. Drop that hour entry and continue the earlier visit.
local function TakeCountBack(row, open)
    local back = type(open) == "table" and open.reentry or nil
    if type(row) ~= "table" or type(back) ~= "table" then return false end
    if type(back.copy) ~= "number" then return false end
    local list = row.hour
    if type(list) == "table" then
        for i = #list, 1, -1 do
            local entry = list[i]
            if type(entry) == "table" and entry.at == open.entered then
                table.remove(list, i)
                hourSnap = nil
                break
            end
        end
    end
    if type(row.live) ~= "table" then row.live = {} end
    if type(back.key) == "string" then
        row.live[back.key] = { name = open.instance or "", at = back.at, copy = back.copy }
    end
    local prior = back.run
    if type(prior) ~= "table" then
        open.copy = back.copy
        open.reentry = nil
        return true
    end
    prior.loot = (prior.loot or 0) + (open.loot or 0)
    prior.xp = (prior.xp or 0) + (open.xp or 0)
    prior.deaths = (prior.deaths or 0) + (open.deaths or 0)
    AddRep(prior, open.rep)
    local gap = (open.entered or 0) - (prior.left or open.entered or 0)
    if gap > 0 then prior.skipped = (prior.skipped or 0) + gap end
    prior.left = nil
    prior.copy = back.copy
    prior.reentry = nil
    if open.lastXP ~= nil then prior.lastXP = open.lastXP end
    if open.lastMax ~= nil then prior.lastMax = open.lastMax end
    local runs = row.runs
    if type(runs) == "table" then
        for i = 1, #runs do
            if runs[i] == prior then
                table.remove(runs, i)
                break
            end
        end
    end
    row.open = prior
    return true
end

local function TakeSameCopy(name, mapID, difficulty, seen)
    local row = Mine(false)
    local runs = row and row.runs
    if type(runs) ~= "table" then return end
    row.reentry = nil
    local mine = LiveCopies(false)
    local key = CopyKey(mapID, difficulty, name)
    local stored = mine and mine[key]
    if not stored then return end
    local now = time()
    local grouped = false
    if IsInGroup then
        local inGroup = IsInGroup()
        if not Secret(inGroup) and inGroup then grouped = true end
    end
    local current = CurrentGroup()
    for i = 1, #runs do
        local run = runs[i]
        if type(run) == "table" and SamePlace(run, name, mapID, difficulty) then
            if not CanResume(stored, run.left, now, HOUR) then return end
            -- A different group is a new copy. Drop the stamp so this zone-in counts,
            -- and leave the old visit in the history.
            if GroupsDiffer(run.group, current, grouped) then
                mine[key] = nil
                return
            end
            local zone = ObservedZone(seen)
            local saved = type(stored.copy) == "number" and stored.copy or nil
            -- The same zone id is this copy. Resume it, and do not count again.
            if zone and saved and zone == saved then
                table.remove(runs, i)
                return run
            end
            -- No readable zone id, or a different one. A real leave already closed
            -- this visit, so the zone-in counts. A matching id later can undo it.
            RememberReentry(row, stored, run, key)
            mine[key] = nil
            return
        end
    end
end

-- A plain zone id learned while the visit is open. A match for the copy this
-- zone-in replaced takes that hour entry back. Anything else is recorded on
-- the stamp, so the next leave can tell this copy from the one after a reset.
local function NoteZone(zone)
    if type(zone) ~= "number" or zone == 0 then return end
    local row = Mine(false)
    local open = row and row.open
    if type(open) ~= "table" then return end
    local back = open.reentry
    if type(back) == "table" and back.copy == zone then
        if TakeCountBack(row, open) then
            if WarnHour then WarnHour() end
            if UpdateFrame then UpdateFrame() end
            if UI and UI.RefreshPage then UI:RefreshPage(true) end
        end
        return
    end
    if type(back) == "table" then open.reentry = nil end
    local lives = LiveCopies(true)
    local place = CopyKey(open.mapID or 0, open.difficulty, open.instance)
    local stored = type(lives) == "table" and lives[place] or nil
    if type(stored) == "table" then stored.copy = zone end
    open.copy = zone
end

BeginRun = function(name, kind, difficulty, mapID, announce)
    local row = TouchChar()
    if not row then return end
    local open = row.open
    if type(open) == "table" and SamePlace(open, name, mapID, difficulty) then
        -- Drop the time passed while logged out or reloading, then keep counting.
        -- A long absence is still time away, so the timer does not count it.
        if open.seen then
            local away = time() - open.seen
            if away > 0 then
                open.skipped = (open.skipped or 0) + away
            end
            open.seen = nil
        end
        NoteInstanceEntry(name, mapID, difficulty, false)
        NoteGroup(open)
        SetRunEvents(true)
        if ReadZone then NoteZone(ReadZone()) end
        UpdateFrame()
        return
    end
    if type(open) == "table" then
        CloseRun(announce, (not announce) and open.seen or nil, true)
    end
    local prior = TakeSameCopy(name, mapID, difficulty)
    local who = row.name or ""
    if prior then
        row.reentry = nil
        local now = time()
        local skipped = now - (tonumber(prior.left) or now)
        if skipped < 0 then skipped = 0 end
        row.open = {
            name = prior.name or who,
            class = prior.class or row.class, level = prior.level or row.level,
            instance = name, mapID = mapID ~= 0 and mapID or prior.mapID,
            kind = kind, difficulty = difficulty,
            entered = prior.entered or now, skipped = skipped,
            loot = prior.loot or 0, xp = prior.xp or 0, deaths = prior.deaths or 0,
            rep = prior.rep, group = prior.group, copy = prior.copy,
        }
        NoteGroup(row.open)
        NoteInstanceEntry(name, mapID, difficulty, false)
        NoteXP(true)
        SetRunEvents(true)
        if ReadZone then NoteZone(ReadZone()) end
        if announce then AnnounceResume(row.open) end
        UpdateFrame()
        UI:RefreshPage(true)
        return
    end
    local back = row.reentry
    row.reentry = nil
    local now = time()
    row.open = {
        name = who, class = row.class, level = row.level,
        instance = name, mapID = mapID, kind = kind, difficulty = difficulty,
        entered = now, loot = 0, xp = 0, deaths = 0,
    }
    if type(back) == "table" then row.open.reentry = back end
    NoteGroup(row.open)
    local countIt = announce and true or false
    NoteInstanceEntry(name, mapID, difficulty, countIt)
    if countIt then
        local lives = row.live
        local stamped = type(lives) == "table" and lives[CopyKey(mapID, difficulty, name)]
        if type(stamped) == "table" and type(stamped.at) == "number" then
            row.open.entered = stamped.at
        end
    end
    NoteXP(true)
    SetRunEvents(true)
    if ReadZone then NoteZone(ReadZone()) end
    if announce then AnnounceEnter(row.open) end
    UpdateFrame()
    UI:RefreshPage(true)
end

local function SyncZone(announce)
    if not On() then return end
    local name, state, kind, difficulty, mapID = CurrentInstance()
    if state == "secret" then return end
    if state ~= "in" then
        local open = OpenRun()
        -- A ghost, or a death the client kept secret, is still this visit.
        if open and KeepsVisit(PlayerGhost()) then
            if not open.seen then open.seen = time() end
            SetRunEvents(true)
            UpdateFrame()
            return
        end
        if open then CloseRun(announce, (not announce) and open.seen or nil)
        else UpdateFrame() end
        return
    end
    BeginRun(name, kind, difficulty, mapID, announce)
end

-- Target, mouseover, and nameplates. A cast GUID arrives on its own event.
-- Outdoor GUIDs and secrets return nothing, and this does not poll.
local function UnitCopy(unit)
    if type(unit) ~= "string" or unit == "" or not UnitGUID then return end
    if Secret(unit) then return end
    return CopyParts(UnitGUID(unit))
end

ReadZone = function()
    local zone = UnitCopy("target")
    if zone then return zone end
    zone = UnitCopy("mouseover")
    if zone then return zone end
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local plates = C_NamePlate.GetNamePlates()
    if type(plates) ~= "table" or Secret(plates) then return end
    for i = 1, #plates do
        local plate = plates[i]
        local unit = type(plate) == "table" and plate.namePlateUnitToken or nil
        zone = UnitCopy(unit)
        if zone then return zone end
    end
end

-- Run timer. A shared tracker panel, shown while a visit is in progress.
local function FrameWanted()
    if not On() or not S.Get("showFrame") then return false end
    if unlocked then return true end
    local open = OpenRun()
    if not open then return false end
    -- The X hides this visit. The next one, with its own entered time, shows again.
    if dismissedAt and open.entered == dismissedAt then return false end
    return true
end

local function StopClock()
    if clock then clock:Cancel(); clock = nil end
end

local function LoadPosition()
    local pos = S.Get("pos")
    if type(pos) == "table" then return pos.point, pos.relPoint, pos.x, pos.y end
end

local function SavePosition(point, relPoint, x, y)
    S.Set("pos", { point = point, relPoint = relPoint, x = x, y = y })
end

local function Mover(panel, onMoved)
    return UI.AttachMover(panel, "Instance Tracker", onMoved,
        SETTINGS_PAGE, SETTINGS_PAGE .. ":" .. TIMER_CARD)
end

local function OpenWindow()
    if ns.OpenInstanceTrackerWindow then ns.OpenInstanceTrackerWindow() end
end

-- The X hides the timer for this visit and leaves Show Run Timer on.
local function CloseTimer()
    local open = OpenRun()
    dismissedAt = open and open.entered or true
    StopClock()
    if frame then frame:Hide() end
end

local function AddLine(body, size, y)
    local line = ns.Font(body, size, nil, T.fg)
    line:SetJustifyH("LEFT")
    line:SetWordWrap(false)
    line:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    line:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -y)
    return line
end

local function NewBody(scroll)
    local body = CreateFrame("Frame", nil, scroll)
    local y = 0
    body.time = AddLine(body, TIME_SIZE, y)
    y = y + TIME_LINE + TIME_GAP
    body.stats = AddLine(body, BODY_SIZE, y)
    y = y + BODY_LINE + LINE_GAP
    body.hour = AddLine(body, BODY_SIZE, y)
    body:SetHeight(BODY_H)
    return body
end

local function HourLine()
    local count, cap, frees = HourSnapshot()
    local text = string.format(ns.L("Account this hour: %d of %d"), count, cap)
    if count > 0 then text = text .. "   " .. FormatDuration(frees) end
    local left = cap - count
    if count > 0 and left <= WarnDistance() then
        return ns.Color(left <= 0 and CAP_RGB or WARN_RGB, text)
    end
    return text
end

local function Paint()
    local open = OpenRun()
    local body = frame.body
    if open then
        frame.title:SetText(Where(open))
        body.time:SetText(FormatDuration(Elapsed(open)))
        body.stats:SetText(Coins(open.loot) .. "   " .. BreakUpLargeNumbers(open.xp or 0) .. ns.L(" XP"))
    else
        frame.title:SetText(ns.L("Instance"))
        body.time:SetText("0:00")
        body.stats:SetText(Coins(0) .. ns.L("   0 XP"))
    end
    body.hour:SetText(HourLine())
    body:SetHeight(BODY_H)
    frame:Fit(BODY_H)
    frame:Paint()
end

-- The visit clock and the hour countdown move each second. Loot, experience, scale,
-- fit, and the backdrop stay on UpdateFrame, which runs when those actually change.
local function Tick()
    local open = OpenRun()
    if not (open and frame and frame:IsShown()) then
        UpdateFrame()
        return
    end
    frame.body.time:SetText(FormatDuration(Elapsed(open)))
    frame.body.hour:SetText(HourLine())
end

local function Build()
    frame = ns.Shared.Parts.TrackerPanel(ns.L("Instance"), {
        onTitle = OpenWindow,
        titleTip = "Instance Tracker",
        titleHint = ns.L("Click to open this hour and history."),
        onClose = CloseTimer,
        newBody = NewBody,
        settings = { page = SETTINGS_PAGE, card = TIMER_CARD, tip = ns.L("Instance Tracker settings"),
            hint = ns.L("Opens the Run Timer settings.") },
        load = LoadPosition, save = SavePosition,
        place = { "TOP", "TOP", 0, DEFAULT_Y },
        mover = Mover,
    })
    frame:Hide()
end

UpdateFrame = function()
    if not FrameWanted() then
        StopClock()
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() end
    frame:SetScale(ns.UIScale())
    if not frame.placed then frame:Place(); frame.placed = true end
    Paint()
    if frame.mover then frame.mover:SetShown(unlocked == true) end
    frame:Show()
    if OpenRun() then
        if not clock then clock = C_Timer.NewTicker(1, Tick) end
    else
        StopClock()
    end
end

ns.InstanceTracker = {
    PAGE_RUNS = 40,
    Enabled = On,
    Open = OpenRun,
    Duration = FormatDuration,
    Elapsed = Elapsed,
    PlaceName = PlaceName,
    Reputation = Reputation,
    Coins = Coins,
    WarnDistance = WarnDistance,
    CapRGB = CAP_RGB,
    WarnRGB = WARN_RGB,
}

function ns.InstanceTracker.Characters()
    local list, all = {}, AllChars()
    if not all then return list end
    local mineGUID, myRealm = PlayerGUID(), RealmKey()
    local track = S.Get("trackAlts")
    for guid, row in pairs(all) do
        local mine = guid == mineGUID
        if IsCharKey(guid) and type(row) == "table" and (track or mine) then
            list[#list + 1] = {
                guid = guid, realm = row.realm or "", name = row.name or "",
                class = row.class, level = row.level or 0, mine = mine,
                xp = row.xp, xpMax = row.xpMax, rested = row.rested,
                durability = row.durability, seen = row.seen,
            }
        end
    end
    table.sort(list, function(a, b)
        local aHome, bHome = a.realm == myRealm, b.realm == myRealm
        if aHome ~= bHome then return aHome end
        if a.realm ~= b.realm then return a.realm < b.realm end
        if a.mine ~= b.mine then return a.mine end
        if a.level ~= b.level then return a.level > b.level end
        return a.name < b.name
    end)
    return list
end

local function ByLeave(a, b)
    return (a.left or a.entered or 0) > (b.left or b.entered or 0)
end

function ns.InstanceTracker.Runs()
    local row = Mine(false)
    local mine = row and row.runs
    if type(mine) ~= "table" then mine = {} end
    if not S.Get("trackAlts") then return mine end
    local all = AllChars()
    if not all then return mine end
    local list = {}
    for guid, char in pairs(all) do
        if IsCharKey(guid) and type(char) == "table" and type(char.runs) == "table" then
            for i = 1, #char.runs do
                local run = char.runs[i]
                if type(run) == "table" then list[#list + 1] = run end
            end
        end
    end
    table.sort(list, ByLeave)
    return list
end

function ns.InstanceTracker.ClearHistory()
    local all = AllChars()
    if not all then return end
    if S.Get("trackAlts") then
        for guid, row in pairs(all) do
            if IsCharKey(guid) and type(row) == "table" then row.runs = {} end
        end
        return
    end
    local row = Mine(false)
    if row then row.runs = {} end
end

function ns.InstanceTracker.Hour()
    return HourSnapshot()
end

function ns.InstanceTracker.HourEntries()
    local rows, lists = {}, HourLists()
    for i = 1, #lists do
        local list = lists[i]
        for j = 1, #list do rows[#rows + 1] = list[j] end
    end
    table.sort(rows, function(a, b) return (a.at or 0) > (b.at or 0) end)
    return rows
end

function ns.InstanceTracker.EntryLeft(row)
    if type(row) ~= "table" or type(row.at) ~= "number" then return 0 end
    local left = row.at + HOUR - time()
    if left < 0 then return 0 end
    return left
end

-- Events stay registered while the module is on. Loot, reputation, and deaths only
-- while a visit is open. Rest and durability update the whole time.
-- The sheet is written immediately. The open page follows a moment later, so a bag
-- update does not rebuild it on every slot.
local sheetQueued
local function QueueSheet(xpOnly)
    if xpOnly then TouchXP() else TouchChar() end
    if sheetQueued then return end
    sheetQueued = true
    C_Timer.After(1, function()
        sheetQueued = nil
        if On() then UI:RefreshPage(true) end
    end)
end

events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        local login, reload = ...
        SyncZone(not login and not reload)
        QueueSheet()
    elseif event == "PLAYER_LOGOUT" then
        TouchChar()
        local open = OpenRun()
        if open then
            NoteGroup(open)
            if not open.seen then open.seen = time() end
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        OnResetMessage(...)
    elseif event == "CHAT_MSG_ADDON" then
        OnNovaReset(...)
    elseif event == "CHAT_MSG_MONEY" then
        AddLoot(...)
    elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        NoteRep(...)
    elseif event == "PLAYER_DEAD" then
        local open = OpenRun()
        if open then open.deaths = (open.deaths or 0) + 1 end
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        local open = OpenRun()
        if open and PlayerGhost() == false then
            local _, zoneState = CurrentInstance()
            if zoneState == "out" then CloseRun(true) end
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        local open = OpenRun()
        if open then NoteGroup(open) end
    elseif event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" then
        if ReadZone then NoteZone(ReadZone()) end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        if type(unit) == "string" and not Secret(unit) and UnitGUID then
            NoteZone(CopyParts(UnitGUID(unit)))
        end
    elseif event == "UNIT_SPELLCAST_SENT" then
        local _, _, castGUID = ...
        NoteZone(CopyParts(castGUID))
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local _, castGUID = ...
        NoteZone(CopyParts(castGUID))
    elseif event == "UPDATE_INVENTORY_DURABILITY" then
        QueueSheet()
    elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
        if event == "PLAYER_LEVEL_UP" then
            local newLevel = ...
            local open = OpenRun()
            if open and not Secret(newLevel) and type(newLevel) == "number" then
                open.level = newLevel
            end
        end
        NoteXP(false)
        QueueSheet(true)
        UpdateFrame()
    end
end)

local function Apply()
    events:UnregisterAllEvents()
    StopClock()
    StopExpiry()
    if not On() then
        if OpenRun() then CloseRun(false) end
        if frame then frame:Hide(); frame.placed = nil end
        return
    end
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_LOGOUT")
    events:RegisterEvent("CHAT_MSG_SYSTEM")
    events:RegisterEvent("CHAT_MSG_ADDON")
    if C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(NIT_PREFIX)
    end
    events:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    events:RegisterEvent("PLAYER_XP_UPDATE")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    TouchChar()
    if frame then frame.placed = nil end
    SyncZone(false)
    ScheduleExpiry()
    WarnHour()
end

S.OnChange(function(key)
    if key == "pos" then return end
    if key == "enabled" then Apply()
    elseif key == "showFrame" then
        -- Turning it back on brings the timer back for the visit the X hid.
        if S.Get("showFrame") then dismissedAt = nil end
        UpdateFrame()
    elseif key == "hourlyWarn" then WarnHour() end
end)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = On() and S.Get("showFrame") and true or false
    UpdateFrame()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    UpdateFrame()
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    Apply()
end)

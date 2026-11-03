-- Probe.lua: /nf groupfinder probe and /nf groupfinder ping <name>, for checking the Group Finder in game with a second player.
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local Comms, Listings = GF.Comms, GF.Listings

local lower, match, concat, floor, min = string.lower, string.match, table.concat, math.floor, math.min

local FINDER = "Blizzard_GroupFinder_VanillaStyle"
local LISTED_SHOWN = 5
local SECONDS_PER_MINUTE, MS_PER_SECOND, ROUND = 60, 1000, 0.5
local SCORE_TENTHS = 10
local ROLE_WORDS = { [0] = ns.L("none"), ns.L("damage"), ns.L("healer"), ns.L("healer, damage"), ns.L("tank"),
    ns.L("tank, damage"), ns.L("tank, healer"), ns.L("tank, healer, damage") }
local YES, NO = ns.L("yes"), ns.L("no")
local TEXT_PROBE = ns.L("Group Finder probe:")
local TEXT_STATE = ns.L("  On: %s. Listening: %s. Listed: %s. Chat lockdown: %s. %s loaded: %s.")
local TEXT_LOCKED = ns.L("  Listings: not read during chat lockdown.")
local TEXT_FAILED = ns.L("  Listings: your last search failed.")
local TEXT_LISTINGS = ns.L("  Listings from your last search: %d. Search in the game's Group Finder first.")
local TEXT_LISTING = ns.L("  %d. %s: activity %s \"%s\" map %s -> %s, %d member(s), listed %dm ago%s")
local TEXT_NO_MATCH = ns.L("no Journal match")
local TEXT_DELISTED = ns.L(", delisted")
local TEXT_ROLES = ns.L("roles %s")
local TEXT_SPEC = ns.L("spec %s")
local TEXT_SCORE = ns.L("score %.1f")
local TEXT_NO_SCORE = ns.L("score not shared")
local TEXT_BIS = ns.L("BiS %d/%d")
local TEXT_NO_BIS = ns.L("BiS not shared")
local TEXT_KILLS = ns.L("kills %s")
local TEXT_QUESTS = ns.L("quests %d in log, %d needed")
local TEXT_ANSWERED = ns.L("Group Finder: %s answered in %d ms: %s.")
local TEXT_NO_ANSWER = ns.L("Group Finder: no answer from %s in %d seconds. They need Naowh Forever with the Group Finder on, and a listing in the game's Group Finder.")
local TEXT_OFFLINE = ns.L("Group Finder: %s is not online, or the name is spelled differently.")
local TEXT_PING_USAGE = ns.L("Group Finder: /nf groupfinder ping <name>")
local TEXT_OFF = ns.L("Group Finder is off: turn it on in its settings page first.")
local TEXT_SELF = ns.L("Group Finder: that is you. Ping a second player.")
local TEXT_COULD_NOT = ns.L("Group Finder: could not ask %s (%s).")
local TEXT_ASKED = ns.L("Group Finder: asked %s for their card.")
local TEXT_ASKED_FOR = ns.L("Group Finder: asked %s for their card for %s.")
local TEXT_USAGE = ns.L("Group Finder: /nf groupfinder probe, or /nf groupfinder ping <name>.")

local asked = {}

local function YesNo(value)
    return value and YES or NO
end

local function Activity(id)
    local info = id and C_LFGList.GetActivityInfoTable(id)
    if not info or issecretvalue(info.fullName) then return "?", "?" end
    return tostring(info.fullName), tostring(info.mapID)
end

local function ListingLines()
    if C_ChatInfo.InChatMessagingLockdown() then return ns.Print(TEXT_LOCKED) end
    if Listings.state == "failed" then return ns.Print(TEXT_FAILED) end
    local n = Listings.Read(true)
    ns.Print(TEXT_LISTINGS:format(n))
    for i = 1, min(n, LISTED_SHOWN) do
        local entry = Listings.entries[i]
        local name, map = Activity(entry.activity)
        ns.Print(TEXT_LISTING:format(i, entry.leader or "?", tostring(entry.activity), name, map,
            entry.dungeon or TEXT_NO_MATCH, entry.numMembers, floor(entry.age / SECONDS_PER_MINUTE),
            entry.delisted and TEXT_DELISTED or ""))
    end
end

local function Probe()
    ns.Print(TEXT_PROBE)
    ns.Print(TEXT_STATE:format(YesNo(GF.On()), YesNo(Comms.On()), YesNo(C_LFGList.HasActiveEntryInfo()),
        YesNo(C_ChatInfo.InChatMessagingLockdown()), FINDER, YesNo(C_AddOns.IsAddOnLoaded(FINDER))))
    ListingLines()
end

local function Describe(card)
    local class = card.class and GetClassInfo(card.class) or tostring(card.class)
    local parts = { tostring(class) .. " " .. tostring(card.level), TEXT_ROLES:format(ROLE_WORDS[card.roles]) }
    if card.spec then parts[#parts + 1] = TEXT_SPEC:format(card.spec) end
    parts[#parts + 1] = card.score and TEXT_SCORE:format(card.score / SCORE_TENTHS) or TEXT_NO_SCORE
    parts[#parts + 1] = card.bisTotal and TEXT_BIS:format(card.bisHave, card.bisTotal) or TEXT_NO_BIS
    if card.dungeon then
        parts[#parts + 1] = card.dungeon
        if card.hasKills then parts[#parts + 1] = TEXT_KILLS:format(concat(card.kills, ",", 1, card.nKills)) end
        if card.hasQuests then parts[#parts + 1] = TEXT_QUESTS:format(card.nHave, card.nNeed) end
    end
    return concat(parts, "; ")
end
GF.Describe = Describe

GF.Listen("card", function(sender, card, ping, seconds)
    if not asked[ping.id] then return end
    asked[ping.id] = nil
    ns.Print(TEXT_ANSWERED:format(sender, floor(seconds * MS_PER_SECOND + ROUND), Describe(card)))
end)

GF.Listen("noreply", function(ping)
    if not asked[ping.id] then return end
    asked[ping.id] = nil
    ns.Print(TEXT_NO_ANSWER:format(ping.name, Comms.PING_WAIT))
end)

GF.Listen("offline", function(ping)
    if not asked[ping.id] then return end
    asked[ping.id] = nil
    ns.Print(TEXT_OFFLINE:format(ping.name))
end)

local function Ping(name)
    name = strtrim(name or "")
    if name == "" then return ns.Print(TEXT_PING_USAGE) end
    if not GF.On() then return ns.Print(TEXT_OFF) end
    if lower(name) == lower(GetUnitName("player", true)) then return ns.Print(TEXT_SELF) end
    local J = ns.Journal
    local suggested = J and J.Suggested()
    local nonce, why = Comms.Ping(name, suggested and suggested.key)
    if not nonce then return ns.Print(TEXT_COULD_NOT:format(name, why)) end
    asked[nonce] = true
    if suggested then
        ns.Print(TEXT_ASKED_FOR:format(name, suggested.name))
    else
        ns.Print(TEXT_ASKED:format(name))
    end
end

function ns.GroupFinderCommand(rest)
    local command, arg = match(rest or "", "^(%S*)%s*(.-)$")
    command = lower(command)
    if command == "probe" then
        Probe()
    elseif command == "ping" then
        Ping(arg)
    else
        ns.Print(TEXT_USAGE)
    end
end

-- DungeonJournal.lua: the Dungeon Journal's settings, its dungeon and faction registry and its public API (ns.Journal).
local ns = _G.NaowhForever

local F = ns.FEATURES.journal

local INSTANCE_ID = 8
local BYTE = 255
local ZONE = Enum.UIMapType.Zone
local COLORED = "|cff%02x%02x%02x%s|r"
local FACTION_TABS = { "reputation", "pvp" }
local SPLIT_OPACITY = { "trackerAlpha", "mapAlpha" }
local SUBZONES = {
    ["Chamber of Atonement"] = "ScarletMonasteryGraveyard",
    ["Forlorn Cloister"] = "ScarletMonasteryGraveyard",
    ["Honor's Tomb"] = "ScarletMonasteryGraveyard",
    ["Huntsman's Cloister"] = "ScarletMonasteryLibrary",
    ["Gallery of Treasures"] = "ScarletMonasteryLibrary",
    ["Athenaeum"] = "ScarletMonasteryLibrary",
    ["Training Grounds"] = "ScarletMonasteryArmory",
    ["Footman's Armory"] = "ScarletMonasteryArmory",
    ["Crusader's Armory"] = "ScarletMonasteryArmory",
    ["Hall of Champions"] = "ScarletMonasteryArmory",
    ["Chapel Gardens"] = "ScarletMonasteryCathedral",
    ["Crusader's Chapel"] = "ScarletMonasteryCathedral",
}

local TEXT_TURNED_ON = ns.L("Dungeon Journal turned on. Turn it off in its settings page.")
local TEXT_ENTRANCE = ns.L(" (entrance)")

local S = ns.UI.ModuleSettings("journal", {
    enabled = F.enabled,
    mapPanel = F.mapPanel,
    mapFactions = F.mapFactions,
    mapEntrances = F.mapEntrances,
    mapEntranceScale = 1,
    usableOnly = true,
    myRecipes = true,
    openUnreleased = false,
    upgradesOnly = false,
    showCosmetic = true,
    questsOpen = false,
    bossTipOpen = true,
    bossQuestsOpen = true,
    bossAbilitiesOpen = true,
    repQuestsOpen = true,
    missingBisOnly = false,
    windowAlpha = 1,
    trackerAlpha = 1,
    trackerScale = 1,
    mapAlpha = 1,
    listHidden = false,
    closedGroup1 = false,
    closedGroup2 = false,
    closedGroup3 = false,
    closedGroup4 = false,
    showAlliance = true,
    showHorde = true,
    shareRequests = true,
    acceptShared = false,
    trackerAuto = true,
    hideGameTracker = false,
    trackerOutside = false,
})
ns.JournalSettings = S

local J = { Settings = S }
ns.Journal = J

J.OPTION_GROUPS = {
    { title = ns.L("What it lists"), options = {
        { key = "usableOnly", label = "My Class Only", hides = true,
          tooltip = "Only the loot your class can use. Off, the rest is listed faded." },
        { key = "myRecipes", label = "My Professions Only", hides = true,
          tooltip = "Only the recipes for the professions you have. Off, every recipe is listed." },
        { key = "missingBisOnly", label = "Missing BiS Only", hides = true, needsBis = true,
          tooltip = "Only the loot you still need from your BiS list: higher on it than what "
              .. "you wear, and not in your bags or bank." },
        { key = "upgradesOnly", label = "Upgrades Only", hides = true,
          tooltip = "Only the gear that beats what you wear: a higher pick on your BiS list, or a higher "
              .. "item level you can wear." },
        { key = "showCosmetic", label = "Show Cosmetic Items", hides = false,
          tooltip = "Cosmetic items too: looks for transmog that any class can wear, with no stats." },
    } },
}
J.NEEDS_BIS = ns.L("Needs the BiS List module, which is off.")
J.NOT_YET = ns.L("Not in Forever yet")
J.CLOSED_NOTE = "Not open on Forever yet."
J.FACT = { CLASS = 1, SUBCLASS = 2, ITEM_LEVEL = 3, REQUIRED = 4, QUALITY = 5, ICON = 6, NAME = 7 }
J.RANK = { key = "PvPRank", name = ns.L("PvP Rank"), tab = "pvp", rank = true }
J.TABS = FACTION_TABS
J.NotYet = {}
J.CharacterData = ns.Shared.CharacterData

local ordered, byKey = {}, {}
local newBosses = {}
local byNpc, dungeonOf
local byMap, byName
local factions, factionByKey = { reputation = {}, pvp = {} }, {}
local byZone, byBattleground
local inFront = {}

local function SplitOpacity()
    local was = S.Raw("windowAlpha")
    if was == nil then return end
    for _, key in ipairs(SPLIT_OPACITY) do
        if S.Raw(key) == nil then S.Set(key, was) end
    end
end

local function AddTo(index, id, faction)
    local list = index[id] or {}
    list[#list + 1] = faction
    index[id] = list
end

local function TurninQuests(faction)
    local quests = {}
    for _, turnin in ipairs(faction.turnins) do
        for _, q in ipairs(turnin.quests) do
            quests[#quests + 1] = { q[1], turnin.name, turnin.level, q[2], true, q[3], q[4], q[5], q[6],
                turnin = turnin }
        end
    end
    return { quests = quests }
end

local function LinkDungeons(faction)
    for _, key in ipairs(faction.dungeons or {}) do
        local dungeon = byKey[key]
        if dungeon then
            faction.linked[#faction.linked + 1] = dungeon
            dungeon.factions = dungeon.factions or {}
            dungeon.factions[#dungeon.factions + 1] = faction
        end
    end
end

local function JoinFaction(faction)
    faction.linked = {}
    if faction.turnins then faction.questData = TurninQuests(faction) end
    if not faction.unreleased then
        for _, id in ipairs(faction.maps or {}) do AddTo(byZone, id, faction) end
        if faction.instance then AddTo(byBattleground, faction.instance, faction) end
    end
    LinkDungeons(faction)
end

local function JoinQuests()
    local quests = {}
    for _, entry in ipairs(J.QuestData) do quests[entry.name] = entry end
    for _, dungeon in ipairs(ordered) do
        local entry = quests[dungeon.name]
        dungeon.quests = entry
        byName[dungeon.name] = { dungeon }
        if entry and entry.map then AddTo(byMap, entry.map, dungeon) end
    end
end

local function Join()
    byMap, byName, byZone, byBattleground = {}, {}, {}, {}
    for _, tab in ipairs(FACTION_TABS) do
        for _, faction in ipairs(factions[tab]) do JoinFaction(faction) end
    end
    JoinQuests()
end

local function Joined()
    if not byMap then Join() end
end

local function IndexBosses()
    byNpc, dungeonOf = {}, {}
    for _, dungeon in ipairs(ordered) do
        for _, wing in ipairs(dungeon.wings) do
            for _, boss in ipairs(wing.bosses) do
                if boss.npc then byNpc[boss.npc], dungeonOf[boss] = boss, dungeon end
            end
        end
    end
end

local function InFront(key, list)
    local front = inFront[key]
    if front then return front end
    front = { byKey[key] }
    for _, dungeon in ipairs(list) do
        if dungeon.key ~= key then front[#front + 1] = dungeon end
    end
    inFront[key] = front
    return front
end

local function ZoneHere()
    local id = C_Map.GetBestMapForUnit("player")
    local info = id and C_Map.GetMapInfo(id)
    while info and info.mapType > ZONE and info.parentMapID and info.parentMapID > 0 do
        info = C_Map.GetMapInfo(info.parentMapID)
    end
    return info and info.mapType == ZONE and info.mapID
end

local function FactionsAtHere()
    local inInstance, kind = IsInInstance()
    if not inInstance then
        local zone = ZoneHere()
        return zone and byZone[zone]
    end
    if kind ~= "pvp" then return nil end
    return byBattleground[select(INSTANCE_ID, GetInstanceInfo())]
end

function J.Colored(color, text)
    return COLORED:format(color.r * BYTE, color.g * BYTE, color.b * BYTE, text)
end

function J.Facts(itemID)
    return J.Items[itemID] or J.NotYet[itemID]
end

function J.IsNotYet(itemID)
    return J.NotYet[itemID] ~= nil
end

function J.AddDungeon(key, dungeon)
    dungeon.key = key
    ordered[#ordered + 1] = dungeon
    byKey[key] = dungeon
    if not dungeon.new then return end
    for _, wing in ipairs(dungeon.wings) do
        for _, boss in ipairs(wing.bosses) do newBosses[boss] = true end
    end
end

function J.IsForeverBoss(boss)
    if boss.trash or boss.chest then return false end
    return newBosses[boss] == true or ns.Shared.Parts.IsForever("npcs", boss.npc)
end

function J.AddFaction(key, faction)
    faction.key = key
    for _, tier in ipairs(faction.tiers) do tier.faction = faction end
    local list = factions[faction.tab]
    list[#list + 1] = faction
    factionByKey[key] = faction
end

function J.Dungeons()
    Joined()
    return ordered
end

function J.Get(key)
    Joined()
    return byKey[key]
end

function J.Factions(tab)
    Joined()
    return factions[tab]
end

function J.GetFaction(key)
    Joined()
    return factionByKey[key]
end

function J.Levels(dungeon)
    return dungeon.quests and dungeon.quests.levels
end

function J.Boss(npc)
    if not byNpc then IndexBosses() end
    local boss = byNpc[npc]
    if boss then return boss, dungeonOf[boss] end
end

function J.Current()
    local inInstance, kind = IsInInstance()
    if not (inInstance and (kind == "party" or kind == "raid")) then return end
    Joined()
    local name, _, _, _, _, _, _, id = GetInstanceInfo()
    local list = byMap[id] or byName[name]
    if not list or not list[2] then return list end
    local key = SUBZONES[GetSubZoneText()]
    if not key or list[1].key == key then return list end
    return InFront(key, list)
end

function J.FactionsHere(out)
    wipe(out)
    Joined()
    local list = FactionsAtHere()
    if not list then return out end
    local side = UnitFactionGroup("player")
    for i = 1, #list do
        local faction = list[i]
        if not faction.side or faction.side == side then out[#out + 1] = faction end
    end
    return out
end

function J.Suggested()
    local here = J.Current()
    if here then return here[1] end
    local level = UnitLevel("player")
    for _, dungeon in ipairs(J.Dungeons()) do
        local levels = J.Levels(dungeon)
        if levels and level >= levels[1] and level <= levels[2] then return dungeon end
    end
    return ordered[1]
end

function J.LevelRange(dungeon)
    local levels = J.Levels(dungeon)
    if not levels then return nil end
    if levels[1] == levels[2] then return tostring(levels[1]) end
    return levels[1] .. "-" .. levels[2]
end

function J.ColoredLevelRange(dungeon)
    local range = J.LevelRange(dungeon)
    if not range then return nil end
    local levels, mine = J.Levels(dungeon), UnitLevel("player")
    local level = mine < levels[1] and levels[1] or mine > levels[2] and levels[2] or mine
    return J.Colored(GetQuestDifficultyColor(level), range)
end

function J.Numbered(boss)
    return not (boss.rare or boss.optional or boss.quest or boss.chest or boss.trash)
end

function J.BossTag(boss)
    return boss.rare and "RARE" or boss.optional and "OPTIONAL" or boss.quest and "QUEST"
        or boss.chest and "CHEST" or nil
end

function J.Tip(boss)
    return boss.npc and J.Tips[boss.npc] or nil
end

function J.FactionShown(dungeon)
    if dungeon.raid then return true end
    local territory = dungeon.territory
    if territory == "Alliance" then return S.Get("showAlliance") end
    if territory == "Horde" then return S.Get("showHorde") end
    return true
end

function J.HasBosses(dungeon)
    return #dungeon.wings > 0
end

function J.NpcID(guid)
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

function J.ShowEntrance(dungeon)
    local entrance = dungeon.entrance
    if not entrance then return false end
    ns.PlaceWaypoint(dungeon.name, entrance.map, entrance.x, entrance.y, TEXT_ENTRANCE)
    if not InCombatLockdown() then C_Map.OpenWorldMap(entrance.map) end
    return true
end

function J.TurnOn()
    if S.Get("enabled") then return end
    S.Set("enabled", true)
    ns.Print(TEXT_TURNED_ON)
end

hooksecurefunc(ns, "Apply", SplitOpacity)

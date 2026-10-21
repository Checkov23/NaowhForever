-- MapTools.lua: /nf mappins (placing the bosses' pins, and Copy for Data/Maps.lua) and /nf mapcheck (the client's map art).
local ns = _G.NaowhForever

local J = ns.Journal
local Map = J.DungeonMap
local ART = J.C.MAP_ART

local MAX_FLOORS = 10
local FIRST_TILE = 1
local DECIMALS = "%.3f"
local TRAILING_ZEROS, TRAILING_DOT = "0+$", "%.$"
local ENTRANCE_KEY = "entrance"
local LINE_BREAK = "\n"
local LIST = ", "
local MAYBE_ART = {
    ZulFarrak = { "ZulFarrak", "ZulFarak", "ZulFarrakDungeon", "ZulFarrak1" },
    SunkenTemple = { "TheTempleOfAtalHakkar", "TempleOfAtalHakkar", "SunkenTemple", "TheSunkenTemple",
        "AtalHakkar", "TempleOfAtalHakkar1" },
    UpperBlackrockSpire = { "UpperBlackrockSpire", "BlackrockSpireUpper", "UpperBlackrock", "BlackrockSpire2" },
}

local SPOT = "{ %d, %s, %s }"
local IMAGE_SOURCE = "image = %q"
local ART_SOURCE = "art = %q"
local FIRST_LINE = "    %s = { %s, floors = %d,%s%s"
local FLOOR_FIELD = " floor = %d,"
local ORDER_FIELD = " order = { %s },"
local NAMED = "[%d] = %q"
local NAMES_LINE = "        names = { %s },"
local IMAGES_LINE = "        images = { %s },"
local IMAGE_BOTTOM_LINE = "        imageBottom = %s,"
local ENTRANCE_LINE = "        entrance = %s,"
local PINS_OPEN = "        pins = {"
local PIN_LINE = "            [%d] = %s,   -- %s"
local PINS_CLOSE = "        },"
local MAP_CLOSE = "    },"
local COPY_TITLE = "%s: Data/Maps.lua"

local TEXT_OWN_PICTURE = ns.L("%s: the addon's own picture, until the game has art for it")
local TEXT_ART = ns.L("%s (%s): %s, data says %d")
local TEXT_FLOORS = ns.L("floors ")
local TEXT_NO_ART = ns.L("no art")
local TEXT_OTHER_NAMES = ns.L("%s, other names tried: %s")
local TEXT_FOUND = ns.L("%s (floors %s)")
local TEXT_NONE_FOUND = ns.L("none found")
local TEXT_PORTRAITS = ns.L("Portraits: %s. Your position in here: %s.")
local TEXT_YES, TEXT_NO = ns.L("yes"), ns.L("no")
local TEXT_PLACING_ON = ns.L("Placing map pins: drag them, then Copy. /nf mappins again to stop.")
local TEXT_PLACING_OFF = ns.L("Placing map pins: off.")
local MAPCHECK = "mapcheck"

local probe
local lines = {}
local copying

local function Number(v)
    local text = DECIMALS:format(v):gsub(TRAILING_ZEROS, "")
    return (text:gsub(TRAILING_DOT, ""))
end

local function SpotText(spot)
    return SPOT:format(spot[1], Number(spot[2]), Number(spot[3]))
end

local function Named(floors, list, line)
    local parts = {}
    for i = 1, floors do
        if list[i] then parts[#parts + 1] = NAMED:format(i, list[i]) end
    end
    return line:format(table.concat(parts, LIST))
end

local function FirstLine(dungeon, map)
    local source = map.image and IMAGE_SOURCE:format(map.image) or ART_SOURCE:format(map.art)
    return FIRST_LINE:format(dungeon.key, source, map.floors,
        map.floor and FLOOR_FIELD:format(map.floor) or "",
        map.order and ORDER_FIELD:format(table.concat(map.order, LIST)) or "")
end

local function PinLine(boss, _, key)
    local spot = Map.Spot(copying, key)
    if spot then lines[#lines + 1] = PIN_LINE:format(key, SpotText(spot), boss.name) end
end

local function FloorsOf(art)
    local found = {}
    for n = 1, MAX_FLOORS do
        probe:SetTexture(ART:format(art, art, n, FIRST_TILE))
        local id = probe:GetTextureFileID()
        if type(id) == "number" and id > 0 then found[#found + 1] = n end
    end
    return found
end

local function CheckArt(seen, key, map)
    if map.image then
        ns.Print(TEXT_OWN_PICTURE:format(key))
        return
    end
    if seen[map.art] then return end
    seen[map.art] = true
    local found = FloorsOf(map.art)
    ns.Print(TEXT_ART:format(map.art, key, #found > 0 and TEXT_FLOORS .. table.concat(found, ",") or TEXT_NO_ART,
        map.floors))
end

local function CheckOtherNames(key, names)
    local hits = {}
    for _, art in ipairs(names) do
        local found = FloorsOf(art)
        if #found > 0 then hits[#hits + 1] = TEXT_FOUND:format(art, table.concat(found, ",")) end
    end
    ns.Print(TEXT_OTHER_NAMES:format(key, #hits > 0 and table.concat(hits, LIST) or TEXT_NONE_FOUND))
end

local function MapCheck()
    probe = probe or CreateFrame("Frame"):CreateTexture()
    local seen = {}
    for key, map in pairs(J.Maps) do CheckArt(seen, key, map) end
    for key, names in pairs(MAYBE_ART) do CheckOtherNames(key, names) end
    probe:SetTexture(nil)
    ns.Print(TEXT_PORTRAITS:format(SetPortraitTextureFromCreatureDisplayID and TEXT_YES or TEXT_NO,
        UnitPosition("player") and TEXT_YES or TEXT_NO))
end

function Map.Copy(dungeon)
    local map = J.Maps[dungeon.key]
    wipe(lines)
    lines[1] = FirstLine(dungeon, map)
    if map.imageBottom then lines[#lines + 1] = IMAGE_BOTTOM_LINE:format(Number(map.imageBottom)) end
    if map.names then lines[#lines + 1] = Named(map.floors, map.names, NAMES_LINE) end
    if map.images then lines[#lines + 1] = Named(map.floors, map.images, IMAGES_LINE) end
    local door = Map.Spot(dungeon, ENTRANCE_KEY)
    if door then lines[#lines + 1] = ENTRANCE_LINE:format(SpotText(door)) end
    lines[#lines + 1] = PINS_OPEN
    copying = dungeon
    Map.EachBoss(dungeon, PinLine)
    lines[#lines + 1] = PINS_CLOSE
    lines[#lines + 1] = MAP_CLOSE
    ns.ShowCopyBox(COPY_TITLE:format(dungeon.name), table.concat(lines, LINE_BREAK))
end

function ns.DungeonMapCommand(cmd)
    if cmd == MAPCHECK then return MapCheck() end
    Map.placing = not Map.placing
    ns.Print(Map.placing and TEXT_PLACING_ON or TEXT_PLACING_OFF)
    Map.RedrawPlacing()
end

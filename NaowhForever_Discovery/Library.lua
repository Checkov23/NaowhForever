-- Library.lua: the library book rules: yours to find, carried or handed in, the rewards and waypoints (ns.Library).
local ns = _G.NaowhForever

local Discovery = ns.Discovery
local C = Discovery.C
local S = Discovery.Settings

local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t"
local TIER_TITLE = "|cff%02x%02x%02x(%d)|r %s"
local COLOR_MAX = 255
local TEXT_MAP = ns.L("map ")
local TEXT_COORDS = "(%.1f, %.1f)"

local Library = {}
ns.Library = Library
Discovery.Library = Library

local function State(book)
    if Library.Done(book) then return "done" end
    if C_Item.GetItemCount(book.item, true) > 0 then return "carried" end
    return "find"
end

local function AddSpots(out, n, book, mapID)
    for _, spot in ipairs(book.spots) do
        if spot[C.SPOT_MAP] == mapID then
            n = n + 1
            local pair = out[n] or {}
            pair[1], pair[2] = book, spot
            out[n] = pair
        end
    end
    return n
end

local function Spots(mapID, state, out)
    out = out or {}
    local n = 0
    if mapID then
        for _, book in ipairs(ns.LibraryBooks) do
            if Library.ForMe(book) and State(book) == state then n = AddSpots(out, n, book, mapID) end
        end
    end
    for i = n + 1, #out do out[i] = nil end
    return out
end

local function Note(place)
    return place and (" (" .. place .. ")")
end

function Library.Side()
    return UnitFactionGroup("player") == "Horde" and "H" or "A"
end

function Library.ForMe(book)
    return not book.missing and (book.side == "B" or book.side == Library.Side())
end

function Library.Done(book)
    return C_QuestLog.IsQuestFlaggedCompleted(book.quest)
end

function Library.Stored(book)
    if Library.Done(book) then return nil end
    if C_Item.GetItemCount(book.item) > 0 then return "bags" end
    if C_Item.GetItemCount(book.item, true) > 0 then return "bank" end
end

function Library.Carried(book)
    return Library.Stored(book) ~= nil
end

function Library.Title(book)
    if Library.Done(book) then return CHECK .. " " .. ns.Color("muted", book.name) end
    local c = GetQuestDifficultyColor(book.tier)
    return TIER_TITLE:format(c.r * COLOR_MAX, c.g * COLOR_MAX, c.b * COLOR_MAX, book.tier, book.name)
end

function Library.PlayerZone()
    local id = C_Map.GetBestMapForUnit("player")
    local info = id and C_Map.GetMapInfo(id)
    while info and info.mapType and info.mapType > Enum.UIMapType.Zone
        and info.parentMapID and info.parentMapID ~= 0 do
        id = info.parentMapID
        info = C_Map.GetMapInfo(id)
    end
    return id
end

function Library.TurnIn(book)
    return ns.LibraryTurnIns[book.turnIn or C.TURN_IN][Library.Side()]
end

function Library.Librarian()
    return ns.LibraryTurnIns[C.TURN_IN][Library.Side()]
end

function Library.Progress()
    local done, total = 0, 0
    for _, book in ipairs(ns.LibraryBooks) do
        if book.turnIn == C.TURN_IN and Library.ForMe(book) then
            total = total + 1
            if Library.Done(book) then done = done + 1 end
        end
    end
    return done, total
end

function Library.NextGoal()
    for _, goal in ipairs(ns.LibraryGoals) do
        if not C_QuestLog.IsQuestFlaggedCompleted(goal.quest) then return goal end
    end
end

function Library.GoalState(goal, done)
    if C_QuestLog.IsQuestFlaggedCompleted(goal.quest) then return "claimed" end
    if done < goal.books then return "ahead" end
    if goal.level and UnitLevel("player") < goal.level then return "level" end
    return "ready"
end

function Library.OnMap(mapID, out) return Spots(mapID, "find", out) end
function Library.DoneOnMap(mapID, out) return Spots(mapID, "done", out) end

function Library.ToFind(book)
    return Library.ForMe(book) and State(book) == "find"
end

function Library.Waypoint(title, map, x, y, note, icon)
    if ns.PlaceWaypoint(title, map, x, y, note, icon) and S.Get("openMap") then ns.Shared.Places.ShowMap(map) end
end

function Library.PlaceBook(book, spot)
    return ns.PlaceWaypoint(book.name, spot[C.SPOT_MAP], spot[C.SPOT_X], spot[C.SPOT_Y], Note(spot[C.SPOT_PLACE]), C_Item.GetItemIconByID(book.item))
end

function Library.WaypointBook(book, spot)
    Library.Waypoint(book.name, spot[C.SPOT_MAP], spot[C.SPOT_X], spot[C.SPOT_Y], Note(spot[C.SPOT_PLACE]), C_Item.GetItemIconByID(book.item))
end

function Library.WaypointNpc(npc)
    Library.Waypoint(npc.name, npc.map, npc.x, npc.y)
end

function Library.ZoneName(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or (TEXT_MAP .. mapID)
end

function Library.Where(spot)
    local coords = TEXT_COORDS:format(spot[C.SPOT_X], spot[C.SPOT_Y])
    return spot[C.SPOT_PLACE] and (spot[C.SPOT_PLACE] .. " " .. coords) or coords
end

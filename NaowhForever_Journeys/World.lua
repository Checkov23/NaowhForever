-- World.lua: where the player is, the ways they can travel, and the flight points and landings they learn.
local ns = _G.NaowhForever

local UnitPosition = UnitPosition
local issecretvalue = issecretvalue

local Jy = ns.Journeys
local C = Jy.C
local S = Jy.Settings

local PERCENT = 100
local GCD = 1.5
local LANDING_DELAY = 10
local MOVED = 100
local PLAYER = "player"
local EVENTS = { "TAXIMAP_OPENED", "HEARTHSTONE_BOUND", "PLAYER_ENTERING_WORLD" }

local World = {}
Jy.World = World

local events, landing, castFrom
local knownVersion = 0
local teleportBySpell = {}
for _, tp in ipairs(ns.JourneyTeleports) do teleportBySpell[tp.spell] = tp end

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

function World.Player()
    local x, y, _, c = UnitPosition(PLAYER)
    if not x or Secret(x) then return nil end
    return { c = c, x = x, y = y }
end

function World.FromMap(map, x, y)
    local c, pos = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x / PERCENT, y / PERCENT))
    if not c then return nil end
    return { c = c, x = pos.x, y = pos.y }
end

function World.ToMap(spot)
    local where = CreateVector2D(spot.x, spot.y)
    local map, pos = C_Map.GetMapPosFromWorldPos(spot.c, where)
    if not map then return nil end
    local info = C_Map.GetMapInfo(map)
    if info and info.mapType == Enum.UIMapType.Continent then
        local zone = C_Map.GetMapInfoAtPosition(map, pos.x, pos.y)
        if zone then map, pos = C_Map.GetMapPosFromWorldPos(spot.c, where, zone.mapID) end
    end
    return map, pos.x * PERCENT, pos.y * PERCENT
end

function World.Faction()
    return UnitFactionGroup(PLAYER) == "Horde" and "H" or "A"
end

function World.Known()
    return Jy.CharStore("journeyFlights"), knownVersion
end

local function Ready(start, duration)
    return duration <= GCD or start + duration <= GetTime()
end

local function Hearth(list)
    local home = Jy.CharStore("journeyLandings").hearth
    if not home or C_Item.GetItemCount(C.HEARTHSTONE) == 0 then return end
    if not Ready(C_Item.GetItemCooldown(C.HEARTHSTONE)) then return end
    list[#list + 1] = { mode = "hearth", name = home.name, cast = C.HEARTH_CAST, bias = S.Get("hearthSaving"),
        item = C.HEARTHSTONE, c = home.c, x = home.x, y = home.y }
end

local function Teleports(list, faction)
    local seen = Jy.CharStore("journeyLandings")
    for _, tp in ipairs(ns.JourneyTeleports) do
        local cd = tp.side:find(faction, 1, true) and C_SpellBook.IsSpellKnown(tp.spell) and C_Spell.GetSpellCooldown(tp.spell)
        if cd and Ready(cd.startTime, cd.duration) and (not tp.reagent or C_Item.GetItemCount(tp.reagent) > 0) then
            local spot = seen[tp.spell] or tp
            list[#list + 1] = { mode = "teleport", name = tp.name, cast = C.TELEPORT_CAST, spell = tp.spell,
                c = spot.c, x = spot.x, y = spot.y }
        end
    end
end

function World.Jumps(faction)
    local list = {}
    if S.Get("hearth") then Hearth(list) end
    if S.Get("teleports") then Teleports(list, faction) end
    return list
end

local function LearnFlights()
    local known = Jy.CharStore("journeyFlights")
    for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(GetTaxiMapID())) do
        known[node.nodeID] = node.state ~= Enum.FlightPathState.Unreachable or nil
    end
    knownVersion = knownVersion + 1
end

local function LearnLanding()
    local spell, spot = landing, World.Player()
    if not spell or not spot then return end
    if castFrom and spot.c == castFrom.c and (spot.x - castFrom.x) ^ 2 + (spot.y - castFrom.y) ^ 2 < MOVED * MOVED then return end
    landing, castFrom = nil, nil
    local seen = Jy.CharStore("journeyLandings")
    if spell == C.HEARTH_SPELL then
        seen.hearth = { name = GetBindLocation(), c = spot.c, x = spot.x, y = spot.y }
    else
        seen[spell] = spot
    end
end

local function OnEvent(_, event, unit, _, spellID)
    if event == "TAXIMAP_OPENED" then
        LearnFlights()
    elseif event == "HEARTHSTONE_BOUND" then
        landing, castFrom = C.HEARTH_SPELL, nil
        LearnLanding()
    elseif event == "PLAYER_ENTERING_WORLD" then
        LearnLanding()
    elseif unit == PLAYER and not Secret(spellID) and (spellID == C.HEARTH_SPELL or teleportBySpell[spellID]) then
        landing, castFrom = spellID, World.Player()
        C_Timer.After(LANDING_DELAY, LearnLanding)
    end
end

function World.Apply()
    if not Jy.On() then
        if events then events:UnregisterAllEvents() end
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", PLAYER)
end

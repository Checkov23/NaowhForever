-- Guide.lua: the journey being followed, one step at a time on the game's waypoint, planned again as you go.
local ns = _G.NaowhForever

local Jy = ns.Journeys
local C = Jy.C
local S = Jy.Settings
local World = Jy.World
local Planner = Jy.Planner
local Walk = Jy.Walk

local PERCENT = 100
local SAME_SPOT = 0.05
local REPLAN_DELAY = 0.5
local FIRST_CORNER = 2
local EVENTS = { "NAVIGATION_DESTINATION_REACHED", "USER_WAYPOINT_UPDATED", "PLAYER_CONTROL_GAINED",
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }
local TEXT_WALK = { flight = ns.L("Flight Master: %s"), dock = ns.L("%s dock"), link = "%s", goal = "%s", jump = "%s" }
local TEXT_FLY = ns.L("Fly to %s")
local TEXT_SHIP = ns.L("%s to %s")
local TEXT_TRAM = ns.L("Deeprun Tram to %s")
local TEXT_PORTAL = ns.L("Portal to %s")
local TEXT_LIFT = ns.L("Lift to %s")
local TEXT_HEARTH = ns.L("Hearthstone to %s")
local TEXT_TELEPORT = ns.L("Teleport to %s")
local TEXT_NO_WAY = ns.L("No way found to %s from here; placed a plain waypoint.")
local TEXT_NO_PLACE = ns.L("That journey ends where the game takes no waypoints.")
local TEXT_NO_FLIGHTS = ns.L("Journeys knows none of your flight points yet. Open a flight master's map once and it will plan with your flights.")

local Guide = {}
Jy.Guide = Guide

local journey, events, step, working, driver, dismissed, hinted
local replanQueued = false
local reachedAt
local ticker, ticks
local listeners = {}

local function Changed()
    for i = 1, #listeners do listeners[i]() end
end

function Guide.OnChange(fn)
    listeners[#listeners + 1] = fn
end

local function Close(a, b)
    return a.c == b.c and (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 <= C.ARRIVED * C.ARRIVED
end

function Guide.LegText(leg)
    local mode, name = leg.mode, leg.name or ""
    if mode == "walk" then return (TEXT_WALK[leg.kind] or "%s"):format(name) end
    if mode == "fly" then return TEXT_FLY:format(name) end
    if mode == "ship" then return TEXT_SHIP:format(ns.L(leg.shipKind or ""), name) end
    if mode == "tram" then return TEXT_TRAM:format(name) end
    if mode == "portal" then return TEXT_PORTAL:format(name) end
    if mode == "lift" then return TEXT_LIFT:format(name) end
    if mode == "hearth" then return TEXT_HEARTH:format(name) end
    return TEXT_TELEPORT:format(name)
end

local function Stop()
    return journey.stops[journey.at]
end

local function PlainWaypoint(stop)
    local title, map, x, y, note, icon = unpack(stop, 1, 6)
    journey = nil
    if events then events:UnregisterAllEvents() end
    Changed()
    ns.Print(TEXT_NO_WAY:format(title))
    ns.ShowJourneyStep(title, map, x, y, note, icon)
end

local function Action(legs)
    local first, second = legs[1], legs[2]
    if first and first.mode == "walk" and second then return second, first, 3 end
    return first, first, 2
end

local function Boarding(legs)
    local first, second = legs[1], legs[2]
    if first and first.mode == "ship" then return true end
    return second ~= nil and second.mode == "ship" and first.seconds * C.RUN_SPEED <= C.ARRIVED
end

local function Corner()
    local corners, at = journey.corners, journey.corner
    if not corners or at * 2 > #corners then return nil end
    return { c = journey.plan.legs[1].c, x = corners[at * 2 - 1], y = corners[at * 2] }
end

local function StopStep()
    local stop = Stop()
    step = { title = stop[1], map = stop[2], x = stop[3], y = stop[4], note = stop[5], icon = stop[6] }
    return ns.ShowJourneyStep(step.title, step.map, step.x, step.y, step.note, step.icon)
end

local function OnStep(point)
    return point ~= nil and step ~= nil and point.uiMapID == step.map
        and math.abs(point.position.x * PERCENT - step.x) < SAME_SPOT
        and math.abs(point.position.y * PERCENT - step.y) < SAME_SPOT
end

local function ShowStep()
    local stop = Stop()
    local action, spot = Action(journey.plan.legs)
    local new = { title = stop[1], map = stop[2], x = stop[3], y = stop[4], note = stop[5], icon = stop[6] }
    if action and action.mode ~= "walk" then new.title, new.note = Guide.LegText(action), nil end
    spot = not S.Get("stepEnds") and Corner() or spot
    if spot then
        local map, x, y = World.ToMap(spot)
        if map then new.map, new.x, new.y = map, x, y end
    end
    local same = step and OnStep(C_Map.GetUserWaypoint()) and step.title == new.title and step.map == new.map
        and step.x == new.x and step.y == new.y
    step = new
    if same then return Changed() end
    if not ns.ShowJourneyStep(step.title, step.map, step.x, step.y, step.note, step.icon) and not StopStep() then
        ns.Print(TEXT_NO_PLACE)
        return Guide.Cancel()
    end
    Changed()
end

local function WalkCost(a, b)
    local ea, eb = a.walkKey or a.reach, b.walkKey or b.reach
    if ea == false or eb == false then return false end
    if not ea or not eb then return nil end
    return Walk.Cost(a.c, ea, eb)
end

local function Context(from, to)
    local faction = World.Faction()
    local known, version = World.Known()
    return { faction = faction, known = known, knownVersion = version, from = from, to = to,
        speed = C.RUN_SPEED, now = GetServerTime(), jumps = World.Jumps(faction), walk = WalkCost }
end

local function Reach(spot)
    spot.reach = Walk.From(spot, journey.scratch)
    return spot
end

local function FixedReach(spot)
    local key = ("%d:%.1f,%.1f"):format(spot.c, spot.x, spot.y)
    local reach = journey.reaches[key]
    if reach == nil then
        reach = Walk.From(spot)
        journey.reaches[key] = reach
    end
    spot.reach = reach
    return spot
end

local function Planned(plan)
    if not journey then return end
    if not plan then
        if journey.plan and journey.planAt == journey.at then return end
        return PlainWaypoint(Stop())
    end
    local before = journey.plan
    if before then
        local finished = journey.planAt == journey.at and math.max(0, #before.legs - #plan.legs) or #before.legs
        journey.done = journey.done + finished
    end
    journey.plan, journey.planAt = plan, journey.at
    journey.ride = Boarding(plan.legs)
    journey.corners, journey.corner = plan.corners, FIRST_CORNER
    ShowStep()
end

local function Thin(points)
    if not points then return nil end
    local out = { points[1], points[2] }
    local n = #points
    for i = 3, n - 2, 2 do
        local dx, dy = points[i] - out[#out - 1], points[i + 1] - out[#out]
        if dx * dx + dy * dy >= C.CORNER_GAP * C.CORNER_GAP then out[#out + 1], out[#out + 2] = points[i], points[i + 1] end
    end
    if n > 2 then out[#out + 1], out[#out + 2] = points[n - 1], points[n] end
    return out
end

local function LaterWalks(plan, from)
    local cache = journey.paths
    for i, leg in ipairs(plan.legs) do
        if i > 1 and leg.mode == "walk" and not leg.corners and from.c == leg.c then
            local key = ("%d:%.0f,%.0f>%.0f,%.0f"):format(leg.c, from.x, from.y, leg.x, leg.y)
            local corners = cache[key]
            if corners == nil then
                local a, b = Walk.From(from), Walk.From(leg)
                if a ~= nil and b ~= nil then
                    corners = a and b and Thin(Walk.Path(a, b)) or false
                    cache[key] = corners
                end
            end
            leg.corners = corners or nil
        end
        from = leg
    end
end

local function Work(here, to)
    local ctx = Context(Reach(here), FixedReach(to))
    for _, jump in ipairs(ctx.jumps) do FixedReach(jump) end
    if journey.plan and journey.planAt == journey.at then ctx.keep = journey.plan end
    local plan = Planner.Plan(ctx)
    local first = plan and plan.legs[1]
    if first and first.mode == "walk" and here.reach then
        local there = FixedReach({ c = first.c, x = first.x, y = first.y, z = first.z }).reach
        plan.corners = there and Thin(Walk.Path(here.reach, there))
    end
    if plan then LaterWalks(plan, here) end
    return plan
end

local function Abandon()
    working = nil
    if driver then driver:SetScript("OnUpdate", nil) end
end

local function Drive()
    if not working then return Abandon() end
    Walk.StartBudget()
    local ok, plan = coroutine.resume(working)
    if coroutine.status(working) ~= "dead" then return end
    driver:SetScript("OnUpdate", nil)
    working = nil
    if not ok then
        geterrorhandler()(plan)
        return
    end
    Planned(plan)
end

local function Replan()
    if not journey then return end
    Abandon()
    if InCombatLockdown() then
        journey.waiting = true
        if not journey.plan then StopStep() end
        return
    end
    journey.waiting = false
    local here = World.Player()
    if not here then return end
    if not C.CONTINENTS[here.c] then
        journey.waiting = true
        if not journey.plan and not step then StopStep() end
        return
    end
    if journey.ride and not Walk.Ashore(here) then return end
    while Close(here, Stop().spot) do
        if journey.at == #journey.stops then
            local quest = journey.quest
            journey = nil
            if events then events:UnregisterAllEvents() end
            Changed()
            if quest then ns.TrackQuest(quest) else ns.ClearWaypoint() end
            return
        end
        journey.at = journey.at + 1
    end
    journey.from = here
    local stop = Stop()
    local to = { c = stop.spot.c, x = stop.spot.x, y = stop.spot.y, name = stop[1] }
    working = coroutine.create(Work)
    driver = driver or CreateFrame("Frame")
    Walk.StartBudget()
    local ok, plan = coroutine.resume(working, here, to)
    if coroutine.status(working) ~= "dead" then
        driver:SetScript("OnUpdate", Drive)
        return
    end
    working = nil
    if not ok then return geterrorhandler()(plan) end
    Planned(plan)
end

local function QueuedReplan()
    replanQueued = false
    Replan()
end

local function QueueReplan()
    if replanQueued then return end
    replanQueued = true
    C_Timer.After(REPLAN_DELAY, QueuedReplan)
end

local function Tick()
    if not journey then
        ticker:Cancel()
        ticker = nil
        return
    end
    if working or replanQueued or InCombatLockdown() or UnitOnTaxi("player") then return end
    ticks = ticks + 1
    local here = World.Player()
    if not here then return end
    local from = journey.from
    local moved = not from or from.c ~= here.c or (from.x - here.x) ^ 2 + (from.y - here.y) ^ 2 > C.REPLAN_MOVED ^ 2
    if Close(here, Stop().spot) or ticks >= C.REPLAN_TICKS and moved then
        ticks = 0
        Replan()
    end
end

local function OnLearned()
    if journey then QueueReplan() end
end

local function Cleared(at)
    if not journey or C_Map.GetUserWaypoint() then return end
    local here = World.Player()
    if reachedAt == at or not here or not C.CONTINENTS[here.c] then return QueueReplan() end
    Guide.Cancel()
end

local function OnEvent(_, event, isWaypoint)
    if event == "USER_WAYPOINT_UPDATED" then
        local point = C_Map.GetUserWaypoint()
        if point and not OnStep(point) then return Guide.Cancel() end
        if not point then
            local at = GetTime()
            C_Timer.After(0, function() Cleared(at) end)
        end
    elseif event == "NAVIGATION_DESTINATION_REACHED" then
        reachedAt = GetTime()
        if isWaypoint then return end
        if not S.Get("stepEnds") and journey.corners and (journey.corner + 1) * 2 <= #journey.corners then
            journey.corner = journey.corner + 1
            ShowStep()
        else
            journey.ride = false
            QueueReplan()
        end
    elseif event ~= "PLAYER_REGEN_ENABLED" or journey.waiting then
        QueueReplan()
    end
end

function Guide.Start(title, stops, quest)
    if not Jy.On() or not World.Player() then return false end
    local own = {}
    for i, stop in ipairs(stops) do
        local spot = World.FromMap(stop[2], stop[3], stop[4])
        if not spot then return false end
        own[i] = { stop[1], stop[2], stop[3], stop[4], stop[5], stop[6], spot = spot }
    end
    journey, step = { title = title, stops = own, at = 1, done = 0, quest = quest, paths = {}, reaches = {},
        scratch = Walk.Scratch() }, nil
    if not hinted and next((World.Known())) == nil then
        hinted = true
        ns.Print(TEXT_NO_FLIGHTS)
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    ticks = 0
    ticker = ticker or C_Timer.NewTicker(C.TICK, Tick)
    Replan()
    return true
end

function Guide.Cancel()
    if not journey then return end
    dismissed = journey.quest
    journey, step = nil, nil
    Abandon()
    events:UnregisterAllEvents()
    Changed()
end

function Guide.Current()
    return journey
end

function Guide.Points()
    if not journey or not journey.plan then return nil end
    local legs = journey.plan.legs
    if #legs == 0 then return nil end
    local list, first = {}, 1
    local corners = journey.corners
    if corners then
        for i = (journey.corner or 1) * 2 - 1, #corners, 2 do
            list[#list + 1] = { c = legs[1].c, x = corners[i], y = corners[i + 1], walk = true }
        end
        first = 2
    end
    for i = first, #legs do
        local leg = legs[i]
        if leg.corners then
            for k = 3, #leg.corners, 2 do
                list[#list + 1] = { c = leg.c, x = leg.corners[k], y = leg.corners[k + 1], walk = true }
            end
        else
            local stops = leg.stops
            if stops then
                for k = 1, #stops, 2 do list[#list + 1] = { c = leg.c, x = stops[k], y = stops[k + 1], mode = leg.mode } end
            end
            list[#list + 1] = { c = leg.c, x = leg.x, y = leg.y, walk = leg.mode == "walk", mode = leg.mode }
        end
    end
    return list
end

function Guide.Dismissed()
    return dismissed
end

function Guide.Undismiss()
    dismissed = nil
end

function Guide.Step()
    if not journey or not journey.plan then return end
    local legs = journey.plan.legs
    local _, _, after = Action(legs)
    local nextLeg = legs[after]
    return journey.title, journey.done + 1, journey.done + math.max(#legs, 1), nextLeg and Guide.LegText(nextLeg)
end

ns.JourneyTo = Guide.Start
ns.JourneyCancel = Guide.Cancel
ns.JourneyStep = Guide.Step

local function Apply()
    World.Apply()
    if not Jy.On() then Guide.Cancel() end
end

World.OnLearned(OnLearned)
Jy.Settings.OnChange(Apply)
hooksecurefunc(ns, "Apply", Apply)
Apply()

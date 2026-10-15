-- Planner.lua: the fastest way from one spot to another over walking, flights, ships and jumps.
local ns = _G.NaowhForever

local Jy = ns.Journeys
local C = Jy.C

local sqrt = math.sqrt
local huge = math.huge

local START, GOAL = 1, 2
local LINK_MODE = { Tram = "tram", Lift = "lift" }

local Planner = {}
Jy.Planner = Planner

local function Has(side, faction)
    return side:find(faction, 1, true) ~= nil
end

local function Distance(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return sqrt(dx * dx + dy * dy)
end

local function AddNode(nodes, node)
    nodes[#nodes + 1] = node
    node.index = #nodes
    return node
end

local network = { key = nil }

local function Network(ctx, net)
    local key = ctx.knownVersion and ctx.faction .. ":" .. ctx.knownVersion
    if key and network.key == key then return network end
    local nodes, flights, docks = { false, false }, {}, {}
    for id, f in pairs(net.flights) do
        if Has(f[6], ctx.faction) and ctx.known[id] then
            flights[id] = AddNode(nodes, { kind = "flight", id = id, name = f[1], c = f[2], x = f[3], y = f[4], z = f[5],
                walkKey = "f" .. id })
        end
    end
    for s, ship in ipairs(net.ships) do
        if Has(ship[2], ctx.faction) then
            docks[s] = {}
            for i = 3, #ship do
                local d = ship[i]
                docks[s][i - 2] = AddNode(nodes, { kind = "dock", ship = s, dock = i - 2, name = d[5],
                    shipKind = ship[1], c = d[1], x = d[2], y = d[3], walkKey = "s" .. s .. "." .. i - 2 })
            end
        end
    end
    for l, link in ipairs(net.links) do
        if Has(link[2], ctx.faction) then
            local a, b = link[4], link[5]
            local here = AddNode(nodes, { kind = "link", link = l, name = a[4], linkKind = link[1], c = a[1], x = a[2], y = a[3],
                z = a[5], walkKey = "l" .. l .. ".1" })
            local there = AddNode(nodes, { kind = "link", link = l, name = b[4], linkKind = link[1], c = b[1], x = b[2], y = b[3],
                z = b[5], walkKey = "l" .. l .. ".2" })
            here.other, there.other = there.index, here.index
        end
    end
    network = { key = key, nodes = nodes, flights = flights, docks = docks }
    return network
end

local function Nodes(ctx, net)
    local nodes = {}
    AddNode(nodes, { kind = "start", key = "start", c = ctx.from.c, x = ctx.from.x, y = ctx.from.y, reach = ctx.from.reach })
    AddNode(nodes, { kind = "goal", key = "goal", c = ctx.to.c, x = ctx.to.x, y = ctx.to.y, name = ctx.to.name,
        reach = ctx.to.reach })
    local fixed = Network(ctx, net)
    for i = GOAL + 1, #fixed.nodes do nodes[i] = fixed.nodes[i] end
    for _, jump in ipairs(ctx.jumps or {}) do
        AddNode(nodes, { kind = "jump", key = "j" .. (jump.spell or jump.item), mode = jump.mode, name = jump.name, cast = jump.cast,
            bias = jump.bias, spell = jump.spell, item = jump.item, c = jump.c, x = jump.x, y = jump.y, reach = jump.reach })
    end
    return nodes, fixed.flights, fixed.docks
end

local function TaxiGraph(net, flights)
    local graph = {}
    for _, hop in ipairs(net.hops) do
        local a, b = hop[1], hop[2]
        if flights[a] and flights[b] then
            graph[a] = graph[a] or {}
            graph[a][#graph[a] + 1] = { b, hop[3] / C.FLIGHT_SPEED }
        end
    end
    return graph
end

local function FlightsFrom(graph, from)
    local times, prev, done = { [from] = 0 }, {}, {}
    while true do
        local best, bestTime = nil, huge
        for id, t in pairs(times) do
            if not done[id] and t < bestTime then best, bestTime = id, t end
        end
        if not best then return times, prev end
        done[best] = true
        for _, edge in ipairs(graph[best] or {}) do
            local t = bestTime + edge[2]
            if t < (times[edge[1]] or huge) then times[edge[1]], prev[edge[1]] = t, best end
        end
    end
end

local cache = { key = nil, from = {}, prev = {} }

local function FlightTimes(ctx, net, flights, from)
    local key = ctx.faction .. ":" .. (ctx.knownVersion or "")
    if cache.key ~= key or not ctx.knownVersion then
        cache.key, cache.from, cache.prev, cache.graph = key, {}, {}, TaxiGraph(net, flights)
    end
    local times = cache.from[from]
    if not times then
        times, cache.prev[from] = FlightsFrom(cache.graph, from)
        cache.from[from] = times
    end
    return times, cache.prev[from]
end

local function Period(net, ship)
    local total = 0
    local speed = C.SHIP_SPEED[ship[1]]
    for i = 3, #ship do total = total + ship[i][6] + ship[i][7] / speed end
    return total
end

local function Sail(net, ship, from, to)
    local speed = C.SHIP_SPEED[ship[1]]
    local count = #ship - 2
    local t, i = 0, from
    while i ~= to do
        t = t + ship[i + 2][7] / speed
        i = i % count + 1
        if i ~= to then t = t + ship[i + 2][6] end
    end
    return t
end

local function ExpectedWait(net, ship)
    return Period(net, ship) / 2
end

local function Relax(state, from, to, cost)
    local t = state.time[from] + cost
    if t >= state.time[to] then return false end
    state.time[to] = t
    state.prev[to] = from
    return true
end

local function RelaxWalks(ctx, state, nodes, u)
    local a = nodes[u]
    for v = GOAL, #nodes do
        local b = nodes[v]
        if v ~= u and b.c == a.c and b.kind ~= "jump" and not state.done[v] then
            local yards = ctx.walk and ctx.walk(a, b)
            if yards == nil then yards = Distance(a, b) * C.WALK_DETOUR end
            if yards then
                local seconds = yards / ctx.speed
                if Relax(state, u, v, seconds) then state.leg[v] = { mode = "walk", seconds = seconds } end
            end
        end
    end
end

local function RelaxFlights(ctx, state, nodes, u, net)
    local times, prev = FlightTimes(ctx, net, state.flights, nodes[u].id)
    for id, flown in pairs(times) do
        local v = state.flights[id].index
        if v ~= u and not state.done[v] then
            local seconds = flown + C.TAXI_OVERHEAD + C.TRANSFER
            if Relax(state, u, v, seconds) then state.leg[v] = { mode = "fly", seconds = seconds, prev = prev } end
        end
    end
end

local function RelaxShip(ctx, state, nodes, u, net)
    local a = nodes[u]
    local ship = net.ships[a.ship]
    local arrive = ctx.now + state.time[u]
    local wait = ctx.shipWait and ctx.shipWait(a.ship, a.dock, arrive) or ExpectedWait(net, ship)
    for j, b in ipairs(state.docks[a.ship]) do
        if j ~= a.dock and not state.done[b.index] then
            local ride = Sail(net, ship, a.dock, j) + C.BOARD + C.TRANSFER
            if b.c ~= a.c then ride = ride + C.LOADING end
            if Relax(state, u, b.index, wait + ride) then
                state.leg[b.index] = { mode = "ship", seconds = wait + ride, wait = wait }
            end
        end
    end
end

local function RelaxLink(state, nodes, u, net)
    local a = nodes[u]
    if state.done[a.other] then return end
    local seconds = net.links[a.link][3] + C.TRANSFER
    if Relax(state, u, a.other, seconds) then
        state.leg[a.other] = { mode = LINK_MODE[a.linkKind] or "portal", seconds = seconds }
    end
end

local function RelaxJumps(state, nodes)
    for v = GOAL + 1, #nodes do
        local b = nodes[v]
        if b.kind == "jump" then
            local seconds = b.cast + C.LOADING
            if Relax(state, START, v, seconds + (b.bias or 0)) then
                state.leg[v] = { mode = b.mode, seconds = seconds, spell = b.spell, item = b.item }
            end
        end
    end
end

local function Stops(state, prev, from, to)
    local stops, at = {}, prev[to]
    while at and at ~= from do
        local node = state.flights[at]
        table.insert(stops, 1, node.y)
        table.insert(stops, 1, node.x)
        at = prev[at]
    end
    return stops
end

local function Legs(state, nodes, v)
    local legs = {}
    while state.prev[v] do
        local leg = state.leg[v]
        local node = nodes[v]
        leg.name, leg.kind, leg.key, leg.c, leg.x, leg.y = node.name, node.kind, node.walkKey or node.key, node.c, node.x, node.y
        leg.shipKind, leg.z = node.shipKind, node.z
        if leg.prev then
            leg.stops = Stops(state, leg.prev, nodes[state.prev[v]].id, node.id)
            leg.prev = nil
        end
        if leg.mode ~= "walk" or leg.seconds >= C.MIN_WALK then table.insert(legs, 1, leg) end
        v = state.prev[v]
    end
    return legs
end

local function Same(a, b)
    if #a.legs ~= #b.legs then return false end
    for i, leg in ipairs(a.legs) do
        if leg.key ~= b.legs[i].key or leg.mode ~= b.legs[i].mode then return false end
    end
    return true
end

local function Kept(old, state, nodes)
    local first = old.legs[1]
    if not first then return nil end
    for v = GOAL, #nodes do
        if (nodes[v].walkKey or nodes[v].key) == first.key and state.time[v] < huge then
            local legs, seconds = Legs(state, nodes, v), state.time[v]
            for i = 2, #old.legs do
                legs[#legs + 1] = old.legs[i]
                seconds = seconds + old.legs[i].seconds
            end
            return { seconds = seconds, legs = legs }
        end
    end
end

local function Better(best, kept)
    if Same(best, kept) then return true end
    return best.seconds <= kept.seconds - C.SWITCH_GAIN and best.seconds <= kept.seconds * (1 - C.SWITCH_SHARE)
end

function Planner.Plan(ctx)
    local net = ns.JourneyNetwork
    local nodes, flights, docks = Nodes(ctx, net)
    local state = { time = {}, prev = {}, leg = {}, done = {}, docks = docks, flights = flights }
    for i = 1, #nodes do state.time[i] = huge end
    state.time[START] = 0
    while true do
        local u, best = nil, huge
        for i = 1, #nodes do
            if not state.done[i] and state.time[i] < best then u, best = i, state.time[i] end
        end
        if not u or u == GOAL then break end
        state.done[u] = true
        local kind = nodes[u].kind
        RelaxWalks(ctx, state, nodes, u)
        if kind == "start" then RelaxJumps(state, nodes) end
        if kind == "flight" then RelaxFlights(ctx, state, nodes, u, net) end
        if kind == "dock" then RelaxShip(ctx, state, nodes, u, net) end
        if kind == "link" then RelaxLink(state, nodes, u, net) end
    end
    local best
    if state.time[GOAL] < huge then
        local legs, seconds = Legs(state, nodes, GOAL), 0
        for _, leg in ipairs(legs) do seconds = seconds + leg.seconds end
        best = { seconds = seconds, legs = legs }
    end
    local kept = ctx.keep and Kept(ctx.keep, state, nodes)
    if kept and not (best and Better(best, kept)) then return kept end
    return best
end

Planner.Period = Period
Planner.Sail = Sail

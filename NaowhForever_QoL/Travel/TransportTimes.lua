-- TransportTimes.lua: saved server-clock sightings and ride timings for each transport stop, per realm.
local ns = _G.NaowhForever

local ARRIVAL, DEPARTURE = "arrival", "departure"
local EMPTY = {}
local SECONDS_PER_WEEK = 7 * ns.QoLConstants.SECONDS_PER_DAY
local STALE_CYCLES = 6
local SCHEDULE_CYCLES = 300
local REFINE_BAND = 0.15
local RIDE_MISS = 3
local RIDE_BAND = 0.02

local Times = {}
ns.TransportTimes = Times

local docks = {}
for name, route in pairs(ns.TransportRoutes) do
    for index, dock in ipairs(route.docks) do docks[dock.stop] = { name = name, index = index } end
end

local function Saved(slot)
    local account = ns.AccountSettings()
    account[slot] = account[slot] or {}
    local realm = GetRealmName()
    account[slot][realm] = account[slot][realm] or {}
    return account[slot][realm]
end

local function Rows()
    return Saved("transportSightings")
end

local function Rides()
    return Saved("transportRides")
end

local function Refine(elapsed, period)
    local cycles = math.ceil(elapsed / (period * (1 + REFINE_BAND)))
    if cycles < 1 or cycles ~= math.floor(elapsed / (period * (1 - REFINE_BAND))) then return nil end
    return elapsed / cycles
end

function Times.Prune(now)
    local reset = now + C_DateAndTime.GetSecondsUntilWeeklyReset() - SECONDS_PER_WEEK
    local rows = Rows()
    for key, row in pairs(rows) do
        if row.last < reset or not ns.TransportData[key] then rows[key] = nil end
    end
    local rides = Rides()
    for name in pairs(rides) do
        if not ns.TransportRoutes[name] then rides[name] = nil end
    end
end

function Times.RouteAt(key)
    local dock = docks[key]
    if dock then return dock.name, dock.index end
end

local function InBand(period, route)
    return math.abs(period - route.period) <= RIDE_BAND * route.period
end

local function Store(name, route, since, period, shared)
    local rides = Rides()
    local row = rides[name]
    if row and since == row.at then return false end
    if row then
        local cycles = math.floor((since - row.base) / (row.period or route.period) + 0.5)
        local measured = cycles >= 1 and (since - row.base) / cycles
        if cycles >= 0 and math.abs(since - row.base - cycles * (row.period or route.period)) <= RIDE_MISS then
            if measured and InBand(measured, route) then
                row.period = measured
            end
            row.at = since
            row.shared = shared
            return true
        end
    end
    rides[name] = { base = since, at = since, period = period, shared = shared }
    return true
end

function Times.Ride(name, since)
    local route = ns.TransportRoutes[name]
    if not route or not Store(name, route, since) then return false end
    if Times.OnTimed then Times.OnTimed(name) end
    return true
end

function Times.Shared(name, at, period, now)
    local route = ns.TransportRoutes[name]
    if not route or at > now + RIDE_MISS then return false end
    if period and not InBand(period, route) then return false end
    local row = Rides()[name]
    if row and row.at >= at then return false end
    return Store(name, route, at, period, true)
end

function Times.Latest(name)
    local row = Rides()[name]
    if row and not row.shared then return row.at, row.period end
end

function Times.Dock(name, index, now)
    local route = ns.TransportRoutes[name]
    local ride = route and Rides()[name]
    local row = ride or route and (ns.TransportSchedule or EMPTY)[name]
    if not row then return nil, "new" end
    if now < row.at then return nil, "stale" end
    local dock = route.docks[index]
    local period = row.period or route.period
    if not ride and now - row.at > SCHEDULE_CYCLES * period then return nil, "expired" end
    local phase = (now - row.at) % period
    if phase >= dock.arrive and phase < dock.leave then return dock.leave - phase, DEPARTURE end
    return (dock.arrive - phase) % period, ARRIVAL
end

function Times.Record(key, kind, now)
    local timing = ns.TransportData[key]
    if not timing or (kind ~= ARRIVAL and kind ~= DEPARTURE) then return false end
    local name, index = Times.RouteAt(key)
    if name then
        local dock = ns.TransportRoutes[name].docks[index]
        return Times.Ride(name, now - (kind == ARRIVAL and dock.arrive or dock.leave))
    end
    local rows = Rows()
    local row = rows[key]
    if row and now == row.last then return false end
    local period = row and row.period
    if row and row.kind == kind and now > row.last then
        period = Refine(now - row.last, timing.period) or period
    end
    rows[key] = { arrival = kind == ARRIVAL and now or now - timing.dwell, last = now, kind = kind,
        period = period }
    return true
end

function Times.Next(key, now)
    local name, index = Times.RouteAt(key)
    if name then return Times.Dock(name, index, now) end
    local timing = ns.TransportData[key]
    local row = timing and Rows()[key]
    if not row then return nil, "new" end
    if now < row.last then return nil, "stale" end
    local period = row.period or timing.period
    if now - row.last > STALE_CYCLES * period then return nil, "expired" end
    local phase = (now - row.arrival) % period
    if phase < timing.dwell then return timing.dwell - phase, DEPARTURE end
    return period - phase, ARRIVAL
end

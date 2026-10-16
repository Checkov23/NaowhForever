-- TransportTimes.lua: saved server-clock sightings and estimates for each transport stop, per realm.
local ns = _G.NaowhForever

local ARRIVAL, DEPARTURE = "arrival", "departure"
local SECONDS_PER_WEEK = 7 * ns.QoLConstants.SECONDS_PER_DAY
local STALE_CYCLES = 6
local REFINE_BAND = 0.15

local Times = {}
ns.TransportTimes = Times

local function Rows()
    local account = ns.AccountSettings()
    account.transportSightings = account.transportSightings or {}
    local realm = GetRealmName()
    account.transportSightings[realm] = account.transportSightings[realm] or {}
    return account.transportSightings[realm]
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
end

function Times.Record(key, kind, now)
    local timing = ns.TransportData[key]
    if not timing or (kind ~= ARRIVAL and kind ~= DEPARTURE) then return false end
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

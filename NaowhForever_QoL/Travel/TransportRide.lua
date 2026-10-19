-- TransportRide.lua: times a boat or zeppelin from where the player rides past one of its trigger points (ns.TransportRide).
local ns = _G.NaowhForever

local GetServerTime, GetTime, UnitPosition = GetServerTime, GetTime, UnitPosition
local Times = ns.TransportTimes
local Routes = ns.TransportRoutes

local PLAYER = "player"
local POLL = 0.8
local TRIGGER_RADIUS = 20
local SPEED_BAND = 0.35
local HEADING_MATCH = 0.9
local LOCKOUT = 30

local Ride = {}
ns.TransportRide = Ride

local watched = {}
for _, route in pairs(Routes) do
    for _, dock in ipairs(route.docks) do watched[ns.TransportData[dock.stop].map] = true end
end

local ticker, last
local timed = {}

local function Check(x, y, continent, dx, dy, elapsed, now)
    local moved = math.sqrt(dx * dx + dy * dy)
    if moved <= 0 then return end
    for name, route in pairs(Routes) do
        if not timed[name] or now - timed[name] >= LOCKOUT then
            for _, trigger in ipairs(route.triggers) do
                local sx, sy = trigger.bx - trigger.ax, trigger.by - trigger.ay
                local length = math.sqrt(sx * sx + sy * sy)
                local fx, fy = x - trigger.bx, y - trigger.by
                if trigger.continent == continent and fx * fx + fy * fy <= TRIGGER_RADIUS * TRIGGER_RADIUS then
                    local speed = length / trigger.span
                    local ours = moved / elapsed
                    if math.abs(ours - speed) <= SPEED_BAND * speed
                        and (dx * sx + dy * sy) / (moved * length) >= HEADING_MATCH then
                        local along = ((x - trigger.ax) * sx + (y - trigger.ay) * sy) / (length * length)
                        timed[name] = now
                        Times.Ride(name, GetServerTime() - (trigger.at + trigger.span * along))
                        return
                    end
                end
            end
        end
    end
end

local function Tick()
    if UnitOnTaxi(PLAYER) or IsSwimming() then
        last = nil
        return
    end
    local x, y, _, continent = UnitPosition(PLAYER)
    if not x then
        last = nil
        return
    end
    local now = GetTime()
    if last and last.continent == continent and now > last.time then
        Check(x, y, continent, x - last.x, y - last.y, now - last.time, now)
    end
    last = last or {}
    last.x, last.y, last.continent, last.time = x, y, continent, now
end

local function AtSea(map)
    local info = C_Map.GetMapInfo(map)
    return info ~= nil and info.mapType == Enum.UIMapType.Continent
end

function Ride.Watch(map)
    local wanted = map and (watched[map] or AtSea(map))
    if wanted and not ticker then
        ticker = C_Timer.NewTicker(POLL, Tick)
    elseif not wanted and ticker then
        ticker:Cancel()
        ticker, last = nil, nil
    end
end

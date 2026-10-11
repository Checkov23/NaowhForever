-- Info.lua: what the Top Bar shows live: friends and guild online, the Hearthstone's cooldown, and your saved instances (ns.TopBar.Info).
local ns = _G.NaowhForever

local TB = ns.TopBar
local C = TB.C

local HEARTHSTONE = C.HEARTHSTONE
local SECONDS_PER_MINUTE, SECONDS_PER_HOUR, SECONDS_PER_DAY = 60, 3600, 86400
local HOURS_PER_DAY, MINUTES_PER_HOUR = 24, 60
local ROUND = C.ROUND

local TEXT_HOURS = "%d:%02d:%02d"
local TEXT_MINUTES = "%d:%02d"
local TEXT_PROGRESS = "%s %d/%d"
local TEXT_DAYS_LEFT, TEXT_HOURS_LEFT, TEXT_MINUTES_LEFT = ns.L("%dd %dh"), "%dh %dm", "%dm"
local TEXT_NOT_SAVED = ns.L("You are not saved to any instance.")
local TEXT_SAVED = ns.L("Saved instances:")
local TEXT_RESETS = ns.L("   %s: resets in %s")

local lockoutsAt = 0

local function SoonestFirst(a, b) return a.left < b.left end

local function FriendsOnline()
    local _, bn = BNGetNumFriends()
    return (bn or 0) + (C_FriendList.GetNumOnlineFriends() or 0)
end

local function GuildOnline()
    if not IsInGuild() then return end
    local _, online = GetNumGuildMembers()
    return online or 0
end

local function HearthCooldown()
    local start, dur = C_Container.GetItemCooldown(HEARTHSTONE)
    if not (dur and dur > 0) then return end
    local left = start + dur - GetTime()
    if left > 0 then return left end
end

local function FmtCD(sec)
    sec = math.floor(sec + ROUND)
    if sec >= SECONDS_PER_HOUR then
        return TEXT_HOURS:format(sec / SECONDS_PER_HOUR, (sec % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE,
            sec % SECONDS_PER_MINUTE)
    end
    return TEXT_MINUTES:format(sec / SECONDS_PER_MINUTE, sec % SECONDS_PER_MINUTE)
end

local function ResetText(left)
    local d = math.floor(left / SECONDS_PER_DAY)
    local h = math.floor(left / SECONDS_PER_HOUR) % HOURS_PER_DAY
    local m = math.floor(left / SECONDS_PER_MINUTE) % MINUTES_PER_HOUR
    if d > 0 then return TEXT_DAYS_LEFT:format(d, h) end
    if h > 0 then return TEXT_HOURS_LEFT:format(h, m) end
    return TEXT_MINUTES_LEFT:format(m)
end

local function Lockouts()
    local out, elapsed = {}, GetTime() - lockoutsAt
    for i = 1, GetNumSavedInstances() do
        local name, _, reset, _, locked, extended, _, _, _, _, total, done = GetSavedInstanceInfo(i)
        local left = (reset or 0) - elapsed
        if (locked or extended) and left > 0 then
            out[#out + 1] = {
                left = left,
                name = (total and total > 0) and TEXT_PROGRESS:format(name, done or 0, total) or name,
                reset = ResetText(left),
            }
        end
    end
    table.sort(out, SoonestFirst)
    return out
end

local function InstanceInfoUpdated()
    lockoutsAt = GetTime()
end

TB.Info = { FriendsOnline = FriendsOnline, GuildOnline = GuildOnline, HearthCooldown = HearthCooldown,
    FmtCD = FmtCD, Lockouts = Lockouts, InstanceInfoUpdated = InstanceInfoUpdated }

function ns.LockoutsCommand()
    local list = Lockouts()
    if #list == 0 then ns.Print(TEXT_NOT_SAVED) return end
    ns.Print(TEXT_SAVED)
    for _, l in ipairs(list) do print(TEXT_RESETS:format(l.name, l.reset)) end
end

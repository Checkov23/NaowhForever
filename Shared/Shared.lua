-- Shared.lua: the namespace every module shares (ns.Shared), the Map & Pins sections and pin scale, what a character keeps by its GUID, and how long ago a time was.
local ns = _G.NaowhForever

local MINUTE, HOUR, DAY = 60, 3600, 86400
local WEEK_DAYS = 7
local DATE_FORMAT = "%d %b %Y"
local TEXT_JUST_NOW = ns.L("just now")
local TEXT_MINUTES = ns.L("%d min ago")
local TEXT_HOURS = ns.L("%d h ago")
local TEXT_YESTERDAY = ns.L("yesterday")
local TEXT_DAYS = ns.L("%d days ago")
local PIN_SCALE = 1.5
local FULL_SCREEN_PIN_SCALE = 1.5
local LAST_PIN_ORDER = 50

local Shared = { Parts = {}, Kinds = {}, Items = {}, View = {}, MapPins = {} }
ns.Shared = Shared

local function Child(parent, key, create)
    local child = parent[key]
    if type(child) == "table" then return child end
    if not create then return nil end
    child = {}
    parent[key] = child
    return child
end

function Shared.CharacterData(key, create)
    local guid = UnitGUID("player")
    if not guid then return end
    local all = Child(ns.AccountSettings(), key, create)
    if not all then return end
    return Child(all, guid, create)
end

function Shared.ScalePin(pin, factor)
    local map = pin:GetMap()
    local canvas = map and map.GetCanvasScale and map:GetCanvasScale()
    if not canvas or canvas <= 0 then return end
    local scale = PIN_SCALE * (factor or 1) / canvas
    if map.IsMaximized and map:IsMaximized() then scale = scale * FULL_SCREEN_PIN_SCALE end
    if map.GetGlobalPinScale and not (pin.IsIgnoringGlobalPinScale and pin:IsIgnoringGlobalPinScale()) then
        scale = scale * map:GetGlobalPinScale()
    end
    pin:SetScale(scale)
    pin:ApplyCurrentPosition()
end

function Shared.MapPinSections()
    local list, seq = {}, {}
    for i, section in ipairs(Shared.MapPins) do
        seq[section] = i
        list[i] = section
    end
    table.sort(list, function(a, b)
        local x, y = a.order or LAST_PIN_ORDER, b.order or LAST_PIN_ORDER
        if x ~= y then return x < y end
        return seq[a] < seq[b]
    end)
    return list
end

function Shared.Ago(when)
    local seconds = time() - when
    if seconds < MINUTE then return TEXT_JUST_NOW end
    if seconds < HOUR then return TEXT_MINUTES:format(math.floor(seconds / MINUTE)) end
    if seconds < DAY then return TEXT_HOURS:format(math.floor(seconds / HOUR)) end
    local days = math.floor(seconds / DAY)
    if days == 1 then return TEXT_YESTERDAY end
    if days < WEEK_DAYS then return TEXT_DAYS:format(days) end
    return date(DATE_FORMAT, when)
end

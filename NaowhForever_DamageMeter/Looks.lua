-- Looks.lua: a look is the visual settings of the meter, kept by name and shared as text.
local ns = _G.NaowhForever

local DM = ns.DamageMeter
local S, C = DM.Settings, DM.C

local KEPT_KEY, HEADER = "damageMeterLooks", "NFDM1"
local NAME_MAX = C.LOOK_NAME_MAX

local colorKeys = {}
for _, entry in ipairs(C.COLORS) do colorKeys[entry.key] = true end

local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Copy(v) end
    return out
end

local function IsColor(value)
    if type(value) ~= "table" then return false end
    for _, channel in ipairs({ "r", "g", "b" }) do
        local v = value[channel]
        if type(v) ~= "number" or v ~= v or v < 0 or v > 1 then return false end
    end
    return true
end

local function Fits(key, value)
    if key == "classColors" then
        if type(value) ~= "table" then return false end
        for class, color in pairs(value) do
            if type(class) ~= "string" or not IsColor(color) then return false end
        end
        return true
    end
    if colorKeys[key] then return value == false or IsColor(value) end
    local default = S.Default(key)
    if type(value) ~= type(default) then return false end
    if type(value) == "number" then return value == value and value > -1e9 and value < 1e9 end
    return true
end

function DM.CaptureLook()
    local look = {}
    for _, key in ipairs(C.LOOK_KEYS) do look[key] = Copy(S.Get(key)) end
    return look
end

function DM.ApplyLook(look)
    local count = 0
    for _, key in ipairs(C.LOOK_KEYS) do
        local value = look[key]
        if value ~= nil and Fits(key, value) then
            S.Set(key, Copy(value))
            count = count + 1
        end
    end
    return count
end

local function Kept()
    local account = ns.AccountSettings()
    local all = account[KEPT_KEY]
    if type(all) ~= "table" then
        all = {}
        account[KEPT_KEY] = all
    end
    return all
end

function DM.LookName(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("%c", ""):match("^%s*(.-)%s*$")
    if text == "" then return nil end
    return text:sub(1, NAME_MAX)
end

function DM.LookNames()
    local names = {}
    for name in pairs(Kept()) do names[#names + 1] = name end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

function DM.SavedLook(name)
    return Kept()[name]
end

function DM.SaveLook(text)
    local name = DM.LookName(text)
    if not name then return false, "name" end
    local all = Kept()
    if all[name] == nil and #DM.LookNames() >= C.MAX_LOOKS then return false, "full" end
    all[name] = DM.CaptureLook()
    return true, name
end

function DM.DeleteLook(name)
    Kept()[name] = nil
end

function DM.CopyLookToWindows()
    for index = 2, DM.MAX_WINDOWS do
        S.Set("ownLook" .. index, true)
    end
end

local function Escape(text)
    return (text:gsub("[%c|=;:,%%\128-\255]", function(c) return ("%%%02X"):format(c:byte()) end))
end

local function Unescape(text)
    return (text:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function Number(n)
    return ("%.6g"):format(n)
end

local function ColorText(c)
    return Number(c.r) .. "," .. Number(c.g) .. "," .. Number(c.b)
end

local function EncodeValue(key, value)
    local kind = type(value)
    if kind == "boolean" then return value and "bt" or "bf" end
    if kind == "number" then return "n" .. Number(value) end
    if kind == "string" then return "s" .. Escape(value) end
    if kind ~= "table" then return nil end
    if key == "classColors" then
        local parts = {}
        for class, color in pairs(value) do parts[#parts + 1] = Escape(class) .. ":" .. ColorText(color) end
        table.sort(parts)
        return "m" .. table.concat(parts, ";")
    end
    return "c" .. ColorText(value)
end

function DM.EncodeLook(look)
    local parts = { HEADER }
    for _, key in ipairs(C.LOOK_KEYS) do
        local value = look[key]
        if value ~= nil then
            local text = EncodeValue(key, value)
            if text then parts[#parts + 1] = key .. "=" .. text end
        end
    end
    return table.concat(parts, "|")
end

local function DecodeColor(text)
    local r, g, b = text:match("^([%d%.eE%+%-]+),([%d%.eE%+%-]+),([%d%.eE%+%-]+)$")
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    if r and g and b then return { r = r, g = g, b = b } end
end

local function DecodeValue(body)
    local kind, rest = body:sub(1, 1), body:sub(2)
    if kind == "b" then
        if rest == "t" then return true end
        if rest == "f" then return false end
    elseif kind == "n" then
        return tonumber(rest)
    elseif kind == "s" then
        return Unescape(rest)
    elseif kind == "c" then
        return DecodeColor(rest)
    elseif kind == "m" then
        local map = {}
        for part in rest:gmatch("[^;]+") do
            local class, color = part:match("^([^:]+):(.+)$")
            color = class and DecodeColor(color)
            if not color then return nil end
            map[Unescape(class)] = color
        end
        return map
    end
    return nil
end

function DM.DecodeLook(text)
    if type(text) ~= "string" then return nil end
    text = text:match("^%s*(.-)%s*$")
    local head, rest = text:match("^(%w+)|(.*)$")
    if head ~= HEADER then return nil end
    local known = {}
    for _, key in ipairs(C.LOOK_KEYS) do known[key] = true end
    local look, found = {}, false
    for entry in rest:gmatch("[^|]+") do
        local key, body = entry:match("^([%w_]+)=(.*)$")
        if key and known[key] then
            local value = DecodeValue(body)
            if value ~= nil and Fits(key, value) then
                look[key] = value
                found = true
            end
        end
    end
    return found and look or nil
end

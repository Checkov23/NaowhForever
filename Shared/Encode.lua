-- Encode.lua: plain data written as a code the Naowh website reads back: LibSerialize's version 1 format without its short forms, deflated and printable (ns.Shared.Encode).
local ns = _G.NaowhForever

local char, floor, type, pairs, concat = string.char, math.floor, type, pairs, table.concat

local VERSION = 1
local SMALL_INT, SMALL_STEP = 128, 2
local BYTE, TWO_BYTES, THREE_BYTES, FOUR_BYTES = 256, 65536, 16777216, 4294967296
local WIDE, WIDER, WIDEST = 2, 3, 4
local NUMBER_TYPES = { [WIDE] = 1, [WIDER] = 3, [WIDEST] = 5 }
local TYPE_SHIFT = 8
local STRING_TYPE, MAP_TYPE, ARRAY_TYPE = 14, 17, 20
local TRUE_TYPE, FALSE_TYPE = 12, 13
local MAX_DEPTH = 12

local Encode = {}

local out, n

local function Put(text)
    n = n + 1
    out[n] = text
end

local function Integer(value, width)
    local bytes = {}
    for i = width, 1, -1 do
        bytes[i] = value % BYTE
        value = floor(value / BYTE)
    end
    Put(char(unpack(bytes)))
end

local function Width(value)
    if value < BYTE then return 1 end
    if value < TWO_BYTES then return WIDE end
    return WIDER
end

local function Length(base, count)
    local width = Width(count)
    Put(char((base + width - 1) * TYPE_SHIFT))
    Integer(count, width)
end

local function Number(value)
    if value % 1 ~= 0 or value < 0 or value >= FOUR_BYTES then return false end
    if value < SMALL_INT then
        Put(char(value * SMALL_STEP + 1))
        return true
    end
    local width = value < TWO_BYTES and WIDE or value < THREE_BYTES and WIDER or WIDEST
    Put(char(NUMBER_TYPES[width] * TYPE_SHIFT))
    Integer(value, width)
    return true
end

local function IsList(t)
    local count, keys = #t, 0
    if count == 0 then return false end
    for key in pairs(t) do
        if type(key) ~= "number" or key < 1 or key > count or key % 1 ~= 0 then return false end
        keys = keys + 1
    end
    return keys == count
end

local Write

local function Table(t, depth)
    if IsList(t) then
        Length(ARRAY_TYPE, #t)
        for i = 1, #t do
            if not Write(t[i], depth + 1) then return false end
        end
        return true
    end
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    Length(MAP_TYPE, count)
    for key, value in pairs(t) do
        if not (Write(key, depth + 1) and Write(value, depth + 1)) then return false end
    end
    return true
end

function Write(value, depth)
    if depth > MAX_DEPTH then return false end
    local kind = type(value)
    if kind == "string" then
        Length(STRING_TYPE, #value)
        Put(value)
        return true
    end
    if kind == "number" then return Number(value) end
    if kind == "boolean" then
        Put(char((value and TRUE_TYPE or FALSE_TYPE) * TYPE_SHIFT))
        return true
    end
    if kind == "table" then return Table(value, depth) end
    return false
end

function Encode.Serialize(value)
    out, n = {}, 0
    Put(char(VERSION))
    local ok = Write(value, 0)
    local text = ok and concat(out) or nil
    out = nil
    return text
end

function Encode.String(prefix, value)
    local LD = LibStub and LibStub("LibDeflate", true)
    local raw = LD and Encode.Serialize(value)
    if not raw then return nil end
    return prefix .. LD:EncodeForPrint(LD:CompressDeflate(raw))
end

if ns and ns.Shared then ns.Shared.Encode = Encode end
return Encode

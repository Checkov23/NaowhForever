-- Sharing.lua: a BiS list as a string to share, and back (ns.ExportBisList, ns.ImportBisList).
local ns = _G.NaowhForever

local B = ns.BiS
local C = B.C
local R, L = B.Rankings, B.Lists
local Items = ns.Shared.Items
local SLOT_NAME, Fits = Items.SLOT_NAME, Items.Fits

local PREFIX = "!NBIS1!"
local FLAT, BIS_ONLY, UNORDERED, ORDERED = 1, 2, 3, 4
local VERSION = ORDERED
local LIMITS = { maxChars = 100000, maxBytes = 1048576, maxDepth = 8, maxValues = 20000 }
local MAX_ID = 2 ^ 31
local NAME_MAX = C.NAME_MAX
local BODY_PATTERN = "^%s*" .. PREFIX:gsub("!", "%%!") .. "(%S+)%s*$"
local TEXT_IMPORTED_NAME = ns.L("Imported BiS")
local TEXT_NOT_A_LIST = ns.L("That is not a Naowh BiS list.")
local TEXT_IMPORTED = ns.L("Imported %s: %d items.")
local TEXT_ASK = ns.L("Add %s (%d items) as a new BiS list?")
local NONE = {}

local function Codec()
    return LibStub("LibSerialize"), LibStub("LibDeflate")
end

local function ValidID(id)
    return type(id) == "number" and id > 0 and id < MAX_ID and id == math.floor(id)
end

local function ReadFlat(data, list)
    for _, id in ipairs(data.items) do
        local slot = ValidID(id) and L.FreeSlot(list.slots, id)
        if slot then list.slots[slot] = id end
    end
end

local function RankedSet(more, spec, slot)
    local set = {}
    for id, on in pairs(more) do
        if on == true and ValidID(id) then set[id] = true end
    end
    return R.Ranked(set, R.Ranking(spec, slot))
end

local function AddMore(list, slot, more)
    local picks = B.Picks(list, slot)
    local seen = {}
    for _, id in ipairs(picks) do seen[id] = true end
    for _, id in ipairs(more) do
        if ValidID(id) and Fits(id, slot) and not seen[id] then
            seen[id] = true
            picks[#picks + 1] = id
        end
    end
    B.Store(list, slot, picks)
end

local function ReadSlots(data, list, spec)
    for slot, id in pairs(data.slots) do
        if SLOT_NAME[slot] and ValidID(id) and Fits(id, slot) then list.slots[slot] = id end
    end
    for slot, more in pairs(data.v > BIS_ONLY and type(data.extra) == "table" and data.extra or NONE) do
        if SLOT_NAME[slot] and type(more) == "table" then
            if data.v == UNORDERED then more = RankedSet(more, spec, slot) end
            AddMore(list, slot, more)
        end
    end
end

local function Slotted(version)
    return version == BIS_ONLY or version == UNORDERED or version == ORDERED
end

local function Decode(text)
    local body = type(text) == "string" and text:match(BODY_PATTERN)
    local data = body and ns.Shared.Decode.String(body, LIMITS)
    if type(data) ~= "table" then return end
    local name = ns.Shared.Decode.Text(data.name, NAME_MAX)
    if not name or name == "" then name = TEXT_IMPORTED_NAME end
    local spec = ns.Shared.Decode.Text(data.spec, NAME_MAX)
    local list = { slots = {}, extra = {} }
    if data.v == FLAT and type(data.items) == "table" then
        ReadFlat(data, list)
    elseif Slotted(data.v) and type(data.slots) == "table" then
        ReadSlots(data, list, spec)
    else
        return
    end
    return name, list.slots, list.extra, spec, data.only == true
end

local function Count(slots, extra)
    local count = 0
    for _ in pairs(slots) do count = count + 1 end
    for _, rest in pairs(extra) do count = count + #rest end
    return count
end

function ns.ExportBisList()
    local LS, LD = Codec()
    local list = L.List()
    return PREFIX .. LD:EncodeForPrint(LD:CompressDeflate(LS:Serialize({
        v = VERSION, name = list.name, spec = list.spec, slots = list.slots, extra = list.extra,
        only = list.specOnly,
    })))
end

function ns.ImportBisList(text, quiet)
    local name, slots, extra, spec, only = Decode(text)
    if not name then
        ns.Print(TEXT_NOT_A_LIST)
        return false
    end
    local count = Count(slots, extra)
    local function Apply()
        local list = L.AddList(name, spec, slots, extra, only)
        ns.Print(TEXT_IMPORTED:format(list.name, count))
    end
    if quiet then
        Apply()
    else
        ns.Confirm(TEXT_ASK:format(name, count), Apply)
    end
    return true
end

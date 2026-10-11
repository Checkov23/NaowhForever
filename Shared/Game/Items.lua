-- Items.lua: item helpers (ns.Shared.Items): an ID from what names it, its name and quality color, where you keep it, your loot lines, and waiting on its data.
local ns = _G.NaowhForever

local GetItemNameByID = C_Item.GetItemNameByID
local GetItemQualityByID = C_Item.GetItemQualityByID
local GetItemCount = C_Item.GetItemCount
local IsItemDataCachedByID = C_Item.IsItemDataCachedByID

local Items = ns.Shared.Items
local St = ns.Shared.Style

local KEPT_SHADE = 200
local UNKNOWN_QUALITY_CODE = "|cffffffff"
local LINK_ID = "item[:=](%d+)"
local BARE_ID = "^%s*(%d+)%s*$"
local LOOT_LINK = "(|c[^|]*|Hitem:(%d+).-|h|r)"
local LINE_START = "^(.-)%%s"
local TEXT_UNLOADED = ns.L("item ")
local TEXT_IN_BAG = ns.L("In Bag")
local TEXT_IN_BANK = ns.L("In Bank")

local KEPT_CODE = ("|cff%02x%02x%02x"):format(St.HAVE_RGB.r * KEPT_SHADE, St.HAVE_RGB.g * KEPT_SHADE,
    St.HAVE_RGB.b * KEPT_SHADE)
local IN_BAG, IN_BANK = KEPT_CODE .. TEXT_IN_BAG .. "|r", KEPT_CODE .. TEXT_IN_BANK .. "|r"

local refused = {}

local function LineStart(format)
    local start = type(format) == "string" and format:match(LINE_START)
    return start ~= "" and start or nil
end

local LOOTED, HANDED = LineStart(LOOT_ITEM_SELF), LineStart(LOOT_ITEM_PUSHED_SELF)

local function Starts(text, start)
    return start ~= nil and text:find(start, 1, true) == 1
end

Items.KEPT_CODE = KEPT_CODE
Items.READS_LOOT = LOOTED ~= nil

function Items.IDFrom(value)
    if type(value) == "number" then return value end
    local text = tostring(value)
    return tonumber(text:match(LINK_ID) or text:match(BARE_ID))
end

function Items.Refuse(itemID)
    refused[itemID] = true
end

function Items.Refused(itemID)
    return refused[itemID] == true
end

function Items.Name(itemID)
    return GetItemNameByID(itemID) or (TEXT_UNLOADED .. itemID)
end

function Items.QualityHex(itemID)
    local quality = GetItemQualityByID(itemID)
    local color = quality and ITEM_QUALITY_COLORS[quality]
    return color and color.hex or UNKNOWN_QUALITY_CODE
end

function Items.QualityColor(itemID)
    local quality = GetItemQualityByID(itemID)
    return quality and ITEM_QUALITY_COLORS[quality]
end

function Items.Kept(itemID)
    if GetItemCount(itemID) > 0 then return IN_BAG end
    if GetItemCount(itemID, true) > 0 then return IN_BANK end
    return ""
end

function Items.Owned(itemID)
    return GetItemCount(itemID, true) > 0 or C_Item.IsEquippedItem(itemID)
end

function Items.YourLoot(text, handed)
    if issecretvalue(text) or type(text) ~= "string" then return end
    if not (Starts(text, LOOTED) or (handed and Starts(text, HANDED))) then return end
    local link, id = text:match(LOOT_LINK)
    return link, tonumber(id)
end

function Items.OnLoaded(ids, fn)
    local queued
    local function Run()
        queued = false
        fn()
    end
    local function Refresh()
        if queued then return end
        queued = true
        C_Timer.After(0, Run)
    end
    for i = 1, #ids do
        if not IsItemDataCachedByID(ids[i]) then ItemEventListener:AddCallback(ids[i], Refresh) end
    end
end

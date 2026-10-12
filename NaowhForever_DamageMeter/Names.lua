-- Names.lua: how a player's name is written in the window: in full, first name, last name or initials.
local ns = _G.NaowhForever

local DM = ns.DamageMeter
local S = DM.Settings

local CACHE_MAX = 256
local FIRST_CHAR = "^[\1-\127\194-\244][\128-\191]*"
local GROUP_UNITS = 4

local FOREVER = C_PlayerInfo ~= nil and C_PlayerInfo.ShouldDisplaySurname ~= nil
local SEPARATOR = Constants and Constants.CharacterNameSeparatorConsts
    and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or " "
local SEPARATOR_PATTERN = SEPARATOR ~= " " and SEPARATOR:gsub("%W", "%%%0") or nil

local roster = {}
local cache, cacheCount = {}, {}

local function WithSurname(name, surname, own)
    if not FOREVER or type(name) ~= "string" or type(surname) ~= "string" then return name end
    if own and not C_PlayerInfo.ShouldDisplaySurname() then return name end
    local tail = SEPARATOR .. surname
    if name:sub(-#tail) == tail then return name end
    return name .. tail
end

local function Words(name)
    if Ambiguate then name = Ambiguate(name, "short") or name end
    if SEPARATOR_PATTERN then name = name:gsub(SEPARATOR_PATTERN, " ") end
    local words = {}
    for word in name:gmatch("%S+") do words[#words + 1] = word end
    return words
end

local function Initial(word)
    return word:match(FIRST_CHAR) or word
end

local WRITE = {
    full = function(words) return table.concat(words, " ") end,
    first = function(words) return words[1] end,
    last = function(words) return words[#words] end,
    initials = function(words)
        local out = {}
        for i, word in ipairs(words) do out[i] = Initial(word) .. "." end
        return table.concat(out)
    end,
    firstInitial = function(words)
        if #words < 2 then return words[1] end
        return words[1] .. " " .. Initial(words[#words]) .. "."
    end,
}

local function Write(name, format)
    local write = WRITE[format] or WRITE.full
    local byFormat = cache[format]
    if not byFormat then byFormat = {}; cache[format] = byFormat; cacheCount[format] = 0 end
    local text = byFormat[name]
    if text then return text end
    local words = Words(name)
    text = #words > 0 and write(words) or name
    if cacheCount[format] >= CACHE_MAX then
        cache[format] = {}; byFormat = cache[format]; cacheCount[format] = 0
    end
    byFormat[name] = text
    cacheCount[format] = cacheCount[format] + 1
    return text
end

function DM.ScanRoster()
    for class in pairs(roster) do roster[class] = nil end
    local function Add(unit)
        if not (UnitExists(unit) and UnitIsPlayer(unit)) then return end
        if unit ~= "player" and UnitIsUnit(unit, "player") then return end
        local class = select(2, UnitClass(unit))
        local name, surname = UnitName(unit)
        if type(class) ~= "string" or type(name) ~= "string" or DM.IsSecret(name) then return end
        local full = WithSurname(name, surname, unit == "player")
        if roster[class] == nil then roster[class] = full else roster[class] = false end
    end
    Add("player")
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do Add("raid" .. i) end
    elseif IsInGroup() then
        for i = 1, GROUP_UNITS do Add("party" .. i) end
    end
end

local function IsPlayer(source)
    local class = source.classFilename
    return type(class) == "string" and class ~= ""
end

function DM.DisplayName(source)
    local name = source.name
    if not IsPlayer(source) then return name end
    local format = S.Get("nameFormat")
    local plain
    if source.isLocalPlayer == true then
        local own, surname = UnitName("player")
        plain = WithSurname(own, surname, true)
    elseif type(name) == "string" and not DM.IsSecret(name) then
        plain = name
    else
        local found = roster[source.classFilename]
        if type(found) == "string" then plain = found end
    end
    if type(plain) ~= "string" then return name end
    return Write(plain, format)
end

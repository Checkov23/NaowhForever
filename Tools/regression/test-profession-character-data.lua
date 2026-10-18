-- Profession character state is keyed by GUID even when Forever characters share a first name.
local account = {}
local playerName, playerGUID = "Vykorin", "Player-Blackwind"

local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = Copy(child) end
    return out
end

local settings = {}
local ns = {
    L = function(text) return text end,
    FEATURES = { professions = {} },
    AccountSettings = function() return account end,
    UI = { ModuleSettings = function()
        return { Get = function(key) return settings[key] end }
    end },
}
local env = setmetatable({
    NaowhForever = ns,
    UnitName = function() return playerName end,
    UnitGUID = function() return playerGUID end,
    GetRealmName = function() return "Realm" end,
    UNKNOWNOBJECT = "Unknown",
    CopyTable = Copy,
}, { __index = _G })
env._G = env

local Load = dofile("Tools/regression/load_files.lua")
Load({ "Shared/Shared.lua", "NaowhForever_Professions/Professions.lua" }, env)
local CharacterData = ns.Professions.CharacterData

local mage = CharacterData("profShopping", true)
mage[100] = true
playerGUID = "Player-Blackwhisper"
local paladin = CharacterData("profShopping", true)
assert(paladin[100] == nil, "characters with the same first name shared new profession state")
paladin[200] = true
playerGUID = "Player-Blackwind"
assert(CharacterData("profShopping", true)[100] and not CharacterData("profShopping", true)[200],
    "the second same-name character changed the first character's profession state")

account.profCraftQueue = {
    ["Vykorin-Realm"] = { crafts = { [300] = { count = 1 } }, prerequisites = {} },
}
local first, created, migrated = CharacterData("profCraftQueue", true)
assert(created and migrated and first.crafts[300], "legacy name-and-realm state was not migrated")
first.crafts[400] = { count = 1 }
playerGUID = "Player-Blackwhisper"
local second = CharacterData("profCraftQueue", true)
assert(second.crafts[300] and not second.crafts[400],
    "a change after legacy migration reached another same-name character")
second.crafts[500] = { count = 1 }
playerGUID = "Player-Blackwind"
assert(first.crafts[400] and not first.crafts[500], "migrated GUID stores were not independent")

playerGUID = nil
local temporary = CharacterData("profTemporary", true)
temporary.value = true
assert(account.profTemporary == nil, "profession state was saved before the player GUID was known")
playerGUID = "Player-Late"
assert(CharacterData("profTemporary", true).value == nil,
    "temporary pre-GUID profession state leaked into the saved character state")

print("Profession GUID character-state regression test: PASS")

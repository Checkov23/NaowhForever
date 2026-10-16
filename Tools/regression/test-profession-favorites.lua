-- Recipe favorites are independent per character and every character starts from the former profile store.
local account = {}
local profile = { craftFavorites = { [100] = true } }
local playerName

local ns = {
    AccountSettings = function() return account end,
    Professions = {
        Settings = { DB = function() return profile end },
    },
}
local env = setmetatable({
    NaowhForever = ns,
    UNKNOWNOBJECT = "Unknown",
    UnitName = function() return playerName end,
    GetRealmName = function() return "Realm" end,
    C_TradeSkillUI = { SetRecipeFavorite = function() end },
}, { __index = _G })
env._G = env

local Load = dofile("Tools/regression/load_files.lua")
local function LoadAs(name)
    playerName = name
    Load({ "NaowhForever_Professions/Favorites.lua" }, env)
    return assert(ns.Professions.Favorites)
end

local tester = LoadAs("Tester")
assert(tester.Store()[100] == true, "profile favorites were not copied to the current character")
assert(profile.craftFavorites and profile.craftFavorites[100] == true,
    "copying the profile favorites removed them for the profile's other characters")
tester.Toggle({ spell = 101 })
assert(tester.Store()[101] == true, "the current character's favorite was not saved")

local alt = LoadAs("Alt")
assert(alt.Store()[100] == true and alt.Store()[101] == nil,
    "a second character did not start from the profile favorites alone")
alt.Toggle({ spell = 100 })
alt.Toggle({ spell = 102 })
assert(alt.Store()[100] == false and alt.Store()[102] == true,
    "the second character's favorites were not saved")
assert(tester.Store()[100] and tester.Store()[101] and not tester.Store()[102],
    "the second character's favorites changed the first character's")
assert(profile.craftFavorites[100] == true, "a character's change reached the profile favorites")

local unknown = LoadAs("Unknown")
assert(next(unknown.Store()) == nil, "an unknown character identity exposed another character's favorites")
assert(account.profFavorites["Unknown-Realm"] == nil, "favorites were saved under an unknown character")
playerName = "Late"
assert(unknown.Store()[100] == true and account.profFavorites["Late-Realm"],
    "favorites did not pick up the character once its name was known")

print("Profession favorites character-state regression test: PASS")

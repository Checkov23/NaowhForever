-- Favorites.lua: favourite recipes, learned or not, kept per character by spell ID (ns.ProfFavorites).
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings

local unavailable = {}

local Favorites = {}
P.Favorites = Favorites
ns.ProfFavorites = Favorites

function Favorites.Store()
    local mine, created, migrated = P.CharacterData("profFavorites", true)
    if not mine then return unavailable end
    if not created or migrated then return mine end
    local db = S.DB()
    if type(db.craftFavorites) == "table" then
        for spell, on in pairs(db.craftFavorites) do
            if type(spell) == "number" and on == true then mine[spell] = true end
        end
    end
    return mine
end

function Favorites.Is(info)
    if not info then return false end
    local own = Favorites.Store()[info.recipeID or info.spell]
    if own ~= nil then return own end
    return info.favorite == true
end

function Favorites.Toggle(info)
    if not info then return end
    local on = not Favorites.Is(info)
    Favorites.Store()[info.recipeID or info.spell] = on
    if not info.recipeID then return end
    info.favorite = on
    if C_TradeSkillUI.SetRecipeFavorite then pcall(C_TradeSkillUI.SetRecipeFavorite, info.recipeID, on) end
end

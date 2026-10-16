-- Consumables.lua: your best food and drink (ns.BestFoodAndDrink), the food and drink buttons' names and what an empty one shows, healthstones, healing and mana potions, best first, the food spells and Well Fed buffs, and whether you use mana.
local ns = _G.NaowhForever

local CONJURED = {
    [8079] = true, [8078] = true, [8077] = true, [3772] = true, [2136] = true, [2288] = true,
    [5350] = true, [22895] = true, [8076] = true, [8075] = true, [1487] = true, [1114] = true,
    [1113] = true, [5349] = true,
}
local FOOD_SPELL, DRINK_SPELL = 433, 430
local NO_MANA = { WARRIOR = true, ROGUE = true }
local CONJURED_BONUS = 1000
local REQUIRED_LEVEL = 5
local TEXT_NO_FOOD = ns.L("No food in your bags")
local TEXT_NO_DRINK = ns.L("No drink in your bags")

ns.NO_FOOD = { icon = 133971, text = TEXT_NO_FOOD }
ns.NO_DRINK = { icon = 132794, text = TEXT_NO_DRINK }
ns.FOOD_BUTTONS = { food = "NaowhForeverFoodBarFood", drink = "NaowhForeverFoodBarDrink" }

ns.HEALTHSTONES = { 9421, 19012, 19013, 5510, 19010, 19011, 5509, 19008, 19009, 5511, 19006, 19007, 5512, 19004,
    19005 }
ns.HEALING_POTIONS = { 13446, 3928, 18839, 247242, 1710, 247241, 929, 247240, 858, 247239, 118, 4596 }
ns.MANA_POTIONS = { 13444, 13443, 6149, 3827, 3385, 2455 }

function ns.UsesMana()
    return not NO_MANA[select(2, UnitClass("player"))]
end

function ns.IsDrink(itemID)
    local spell = C_Item.GetItemSpell(itemID)
    return spell ~= nil and spell == C_Spell.GetSpellName(DRINK_SPELL)
end

ns.WELL_FED = {
    1248406, 1248420, 1248421, 1248422, 1248688, 1249519, 1249520, 1249521, 1249523,
    19705, 19706, 19708, 19709, 19710, 19711, 24799, 24870, 25694, 25941, 25661, 18125,
}

ns.FOOD_SPELLS = {}
for _, range in ipairs({ { 1248377, 1248384 }, { 1248386, 1248401 }, { 1248687, 1248687 },
    { 1249500, 1249517 }, { 1249522, 1249522 } }) do
    for id = range[1], range[2] do ns.FOOD_SPELLS[id] = true end
end
for _, id in ipairs({ 5004, 5006, 18124, 21149, 24869, 25660 }) do ns.FOOD_SPELLS[id] = true end

function ns.ConsumableLevelAllowed(id)
    local required = select(REQUIRED_LEVEL, C_Item.GetItemInfo(id))
    local level = UnitLevel("player")
    if issecretvalue and (issecretvalue(required) or issecretvalue(level)) then return false end
    return type(required) == "number" and type(level) == "number" and level > 0 and required <= level, required
end

local function Score(id)
    local allowed, required = ns.ConsumableLevelAllowed(id)
    if allowed then return (CONJURED[id] and CONJURED_BONUS or 0) + required end
end

local function BestFoodAndDrink()
    local foodName, drinkName = C_Spell.GetSpellName(FOOD_SPELL), C_Spell.GetSpellName(DRINK_SPELL)
    local food, drink, foodScore, drinkScore
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local id = C_Container.GetContainerItemID(bag, slot)
            local spell = id and C_Item.GetItemSpell(id)
            if spell and (spell == foodName or spell == drinkName) then
                local s = Score(id)
                if s and spell == foodName then
                    if not foodScore or s > foodScore then food, foodScore = id, s end
                elseif s and spell == drinkName and (not drinkScore or s > drinkScore) then
                    drink, drinkScore = id, s
                end
            end
        end
    end
    return food, drink
end
ns.BestFoodAndDrink = BestFoodAndDrink

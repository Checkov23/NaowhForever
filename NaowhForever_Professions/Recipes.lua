-- Recipes.lua: the open profession and its recipes: reagents, what each makes, and what your bags hold.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local W = P.State
local Links = P.Links

local NO_ITEM = 0
local DEFAULT_BAGS = 4
local TEXT_CRAFT_FAILED = ns.L("Could not craft: ")
local TEXT_ITEM = ns.L("Item ")

local EMPTY = {}
local prof = {}
local reagentCache, outputCache, bagCounts = {}, {}, {}
local bagCountChanges = -1
local waiting = {}

local function IsNPCCrafting()
    return C_TradeSkillUI.IsNPCCrafting and C_TradeSkillUI.IsNPCCrafting()
end

local function Own()
    if Links.Viewing() then return false end
    if C_TradeSkillUI.IsTradeSkillLinked() or C_TradeSkillUI.IsTradeSkillGuild() then return false end
    if IsNPCCrafting() then return false end
    return true
end

local function Linked()
    if not S.Get("craftOrders") then return false end
    if C_TradeSkillUI.IsTradeSkillGuild() then return false end
    if IsNPCCrafting() then return false end
    return C_TradeSkillUI.IsTradeSkillLinked() == true
end

local function Profession()
    local child, base = C_TradeSkillUI.GetChildProfessionInfo(), C_TradeSkillUI.GetBaseProfessionInfo()
    local src = (child and (child.maxSkillLevel or 0) > 0) and child or base
    if not src then return end
    prof.id = base and base.professionID or src.professionID
    prof.name = (base and base.professionName) or src.professionName or ""
    prof.skill = src.skillLevel or 0
    prof.max = src.maxSkillLevel or 0
    prof.modifier = src.skillModifier or 0
    return prof
end

local function SchematicReagents(schematic)
    local out
    for _, slot in ipairs(schematic.reagentSlotSchematics) do
        local reagent = slot.reagents and slot.reagents[1]
        if slot.required ~= false and reagent and reagent.itemID then
            out = out or {}
            out[#out + 1] = { itemID = reagent.itemID, need = slot.quantityRequired or 1 }
        end
    end
    return out
end

local function OldReagents(recipeID)
    local out
    for i = 1, C_TradeSkillUI.GetRecipeNumReagents(recipeID) or 0 do
        local _, _, need = C_TradeSkillUI.GetRecipeReagentInfo(recipeID, i)
        local link = C_TradeSkillUI.GetRecipeReagentItemLink(recipeID, i)
        local itemID = link and C_Item.GetItemInfoInstant(link)
        if itemID then
            out = out or {}
            out[#out + 1] = { itemID = itemID, need = need or 1 }
        end
    end
    return out
end

local function Reagents(recipeID)
    local cached = reagentCache[recipeID]
    if cached then return cached end
    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    if ok and schematic and schematic.reagentSlotSchematics then
        local out = SchematicReagents(schematic) or EMPTY
        reagentCache[recipeID] = out
        return out
    end
    if not C_TradeSkillUI.GetRecipeNumReagents then return EMPTY end
    return OldReagents(recipeID) or EMPTY
end

local function OutputItem(recipeID)
    local cached = outputCache[recipeID]
    if cached ~= nil then
        if cached then return cached[1], cached[2] end
        return
    end
    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    local id = ok and schematic and schematic.outputItemID
    if id and id > NO_ITEM then
        outputCache[recipeID] = { id, math.max(1, schematic.quantityMin or 1) }
        return outputCache[recipeID][1], outputCache[recipeID][2]
    end
    local okData, data = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID)
    id = okData and type(data) == "table" and data.itemID
    if id and id > NO_ITEM then
        outputCache[recipeID] = { id, 1 }
        return id, 1
    end
    if ok and schematic then outputCache[recipeID] = false end
end

local function Request(itemID)
    waiting[itemID] = true
    C_Item.RequestLoadItemDataByID(itemID)
end

local function ItemName(itemID)
    local name = itemID and C_Item.GetItemNameByID(itemID)
    if itemID and not name and not waiting[itemID] then Request(itemID) end
    return name
end

local function ItemCount(itemID)
    return C_Item.GetItemCount(itemID, false, false, true) or 0
end

local function ReadBagCounts()
    local changes = ns.ProfBagChanges or 0
    if bagCountChanges == changes then return end
    wipe(bagCounts)
    local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or DEFAULT_BAGS
    for bag = 0, lastBag do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                bagCounts[info.itemID] = (bagCounts[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end
    bagCountChanges = changes
end

local function BagCount(itemID)
    ReadBagCounts()
    return bagCounts[itemID] or 0
end

local function BankCount(itemID)
    return math.max(0, (C_Item.GetItemCount(itemID, true, false, true) or 0) - ItemCount(itemID))
end

local function Craftable(info)
    if (info.numAvailable or 0) > 0 then return info.numAvailable end
    local reagents = Reagents(info.recipeID)
    if #reagents == 0 then return 0 end
    local n = math.huge
    for _, r in ipairs(reagents) do
        n = math.min(n, math.floor(ItemCount(r.itemID) / math.max(r.need, 1)))
    end
    return n
end

local function Owned()
    local db = S.DB()
    if type(db.craftOwned) ~= "table" then db.craftOwned = {} end
    return db.craftOwned
end

local function SelectedInfo()
    return not W.selectedUnlearned and W.selectedID and C_TradeSkillUI.GetRecipeInfo(W.selectedID)
end

local function Link(itemID, fallback)
    local _, link = C_Item.GetItemInfo(itemID)
    return link or ("[" .. (C_Item.GetItemNameByID(itemID) or fallback or (TEXT_ITEM .. itemID)) .. "]")
end

local function Craft(count)
    local info = SelectedInfo()
    if not info or count < 1 then return end
    local ok, err = pcall(C_TradeSkillUI.CraftRecipe, info.recipeID, count)
    if not ok then ns.Print(TEXT_CRAFT_FAILED .. tostring(err)) end
end

local function WindowLinked()
    return W.linked
end

P.Recipes = {
    waiting = waiting,
    Own = Own,
    Linked = Linked,
    Profession = Profession,
    Reagents = Reagents,
    OutputItem = OutputItem,
    Request = Request,
    ItemName = ItemName,
    ItemCount = ItemCount,
    BagCount = BagCount,
    BankCount = BankCount,
    Craftable = Craftable,
    Owned = Owned,
    SelectedInfo = SelectedInfo,
    Link = Link,
    Craft = Craft,
}

ns.ProfRequestItem = Request
ns.ProfWindowAPI = { SelectedInfo = SelectedInfo, Reagents = Reagents, Owned = Owned, Linked = WindowLinked,
    Own = Own }

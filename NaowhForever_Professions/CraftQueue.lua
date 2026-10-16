-- CraftQueue.lua: saved profession crafts, their prerequisites, missing materials, and ordered execution.
local ns = _G.NaowhForever

local P = ns.Professions
local S = P.Settings
local C = P.C
local R = P.Recipes
local W = P.State
local Shopping = P.Shopping
local V = P.Vendors

local MAX_DEPTH = 4
local PLAN_VERSION = 2
local QUEUE_DELAY = C.QUEUE_DELAY
local TEXT_NOTHING = ns.L("Nothing in the crafting queue can be crafted with the materials in your bags.")
local TEXT_OPEN_REQUIRED = ns.L("Open the required profession manually, then click Craft Next again.")
local TEXT_REQUIRES = ns.L("Requires: %s")
local EMPTY = {}
local BUCKET_ORDER = { true, false }
local APPLY_KEYS = { enabled = true, shoppingList = true, craftQueue = true }
local orderedEntries = {}
local missingEntries = {}
local orderedRecipes = {}
local unmetNames = {}

local Queue = {}
P.CraftQueue = Queue

local running, active
local runID = 0
local ownerKey
local events
local hooked = false
local applied
local SyncShopping, Apply

local function On()
    return S.Get("enabled") and S.Get("shoppingList") and S.Get("craftQueue")
end

local function ShoppingOn()
    return S.Get("shoppingList")
end

local function Mine()
    if not ownerKey then
        local name, realm = UnitName("player"), GetRealmName()
        if not name or name == _G.UNKNOWNOBJECT or not realm then return { prerequisites = {}, crafts = {} } end
        ownerKey = name .. "-" .. realm
    end
    local account = ns.AccountSettings()
    if type(account.profCraftQueue) ~= "table" then account.profCraftQueue = {} end
    local mine = account.profCraftQueue[ownerKey]
    if type(mine) ~= "table" then
        mine = { prerequisites = {}, crafts = {} }
        account.profCraftQueue[ownerKey] = mine
    end
    if type(mine.prerequisites) ~= "table" then mine.prerequisites = {} end
    if type(mine.crafts) ~= "table" then mine.crafts = {} end
    return mine
end

local function Redraw()
    if Queue.Render then Queue.Render() end
    if P.List and P.List.UpdateQueueMarkers then P.List.UpdateQueueMarkers() end
end

local function OpenProfessionID()
    local frame = _G.ProfessionsFrame
    if not (frame and frame:IsShown()) or W.linked then return end
    local profession = R.Profession()
    return profession and profession.id
end

local function CopyNeed(recipeID)
    local need = {}
    local ok, reagents = pcall(R.Reagents, recipeID)
    for _, reagent in ipairs(ok and reagents or EMPTY) do
        if reagent.itemID then need[reagent.itemID] = reagent.need or 1 end
    end
    return need
end

local function RecipeData(recipeID, fallback)
    local okInfo, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
    if not okInfo then info = nil end
    local output, made = R.OutputItem(recipeID)
    local known = Shopping.Makes()[output or 0]
    local need = CopyNeed(recipeID)
    return {
        recipeID = recipeID,
        name = (info and info.name) or (fallback and fallback.name) or C_Spell.GetSpellName(recipeID)
            or ("Recipe " .. recipeID),
        icon = (info and info.icon) or (fallback and fallback.icon) or C_Spell.GetSpellTexture(recipeID),
        need = next(need) and need or (fallback and fallback.need) or {},
        output = output,
        made = made or (known and known.made) or 1,
        prof = (known and known.prof) or (fallback and fallback.prof) or OpenProfessionID(),
    }
end

local function AddEntry(bucket, recipeID, count, fallback)
    count = math.max(1, math.min(C.MAX_CRAFTS, tonumber(count) or 1))
    local entry = bucket[recipeID]
    if entry then
        entry.count = math.min(C.MAX_CRAFTS, (tonumber(entry.count) or 0) + count)
        return entry
    end
    entry = RecipeData(recipeID, fallback)
    entry.count = count
    bucket[recipeID] = entry
    return entry
end

local function MergeDuplicateRecipes(mine)
    for recipeID, prerequisite in pairs(mine.prerequisites) do
        local craft = mine.crafts[recipeID]
        if craft then
            local room = math.max(0, C.MAX_CRAFTS - (tonumber(prerequisite.count) or 0))
            local standalone = math.min(room, tonumber(craft.count) or 0)
            prerequisite.count = (tonumber(prerequisite.count) or 0) + standalone
            prerequisite.standalone = (tonumber(prerequisite.standalone) or 0) + standalone
            for _, key in ipairs({ "name", "icon", "need", "output", "made", "prof" }) do
                if prerequisite[key] == nil then prerequisite[key] = craft[key] end
            end
            mine.crafts[recipeID] = nil
        end
    end
end

local function RequirementPlan(recipeID, count, bucket, inventory, visiting, depth)
    if depth >= MAX_DEPTH or visiting[recipeID] then return end
    visiting[recipeID] = true
    for _, reagent in ipairs(R.Reagents(recipeID) or EMPTY) do
        local want = (reagent.need or 1) * count
        if inventory[reagent.itemID] == nil then inventory[reagent.itemID] = R.ItemCount(reagent.itemID) end
        local have = math.min(want, inventory[reagent.itemID] or 0)
        inventory[reagent.itemID] = (inventory[reagent.itemID] or 0) - have
        local missing = want - have
        local make = Shopping.Makes()[reagent.itemID]
        if missing > 0 and make and not make.cooldown then
            local plan = { cost = {}, make = {}, craft = {}, busy = {}, owned = R.Owned() }
            local _, cheaper = Shopping.Cheapest(reagent.itemID, plan, 0)
            if cheaper then
                local crafts = math.ceil(missing / math.max(1, make.made or 1))
                RequirementPlan(make.recipe, crafts, bucket, inventory, visiting, depth + 1)
                AddEntry(bucket, make.recipe, crafts, { need = make.need, made = make.made })
                inventory[reagent.itemID] = (inventory[reagent.itemID] or 0) + crafts * (make.made or 1) - missing
            end
        end
    end
    visiting[recipeID] = nil
end

local function RebuildPrerequisites(mine)
    for recipeID, prerequisite in pairs(mine.prerequisites) do
        local standalone = tonumber(prerequisite.standalone) or 0
        if standalone > 0 then AddEntry(mine.crafts, recipeID, standalone, prerequisite) end
    end
    wipe(mine.prerequisites)
    local crafts = {}
    for _, entry in pairs(mine.crafts) do crafts[#crafts + 1] = entry end
    table.sort(crafts, function(a, b) return (a.name or "") < (b.name or "") end)
    local inventory = {}
    for _, entry in ipairs(crafts) do
        RequirementPlan(entry.recipeID, tonumber(entry.count) or 1, mine.prerequisites, inventory, {}, 0)
    end
    MergeDuplicateRecipes(mine)
    mine.planVersion = PLAN_VERSION
end

local function EnsurePlan(mine)
    if mine.planVersion ~= PLAN_VERSION then RebuildPrerequisites(mine) end
end

local function Add(info, count, prerequisite, defer)
    if not (info and info.recipeID) then return end
    local mine = Mine()
    EnsurePlan(mine)
    count = math.max(1, math.min(C.MAX_CRAFTS, tonumber(count) or 1))
    AddEntry(prerequisite and mine.prerequisites or mine.crafts, info.recipeID, count, info)
    if prerequisite then MergeDuplicateRecipes(mine) else RebuildPrerequisites(mine) end
    if not defer then Redraw() end
end

local function Bucket(prerequisite)
    local mine = Mine()
    return prerequisite and mine.prerequisites or mine.crafts
end

local function Step(recipeID, prerequisite, by)
    local mine = Mine()
    EnsurePlan(mine)
    local bucket = prerequisite and mine.prerequisites or mine.crafts
    local entry = bucket[recipeID]
    if not entry then return end
    local old = tonumber(entry.count) or 1
    entry.count = math.max(1, math.min(C.MAX_CRAFTS, old + by))
    local delta = entry.count - old
    if prerequisite then
        entry.standalone = math.max(0, math.min(entry.count, (tonumber(entry.standalone) or 0) + delta))
    end
    if active and not active.started and active.recipeID == recipeID and active.prerequisite == prerequisite then
        active.requested = entry.count
        local frame = W.frame
        if frame and frame.qty then frame.qty:SetText(tostring(entry.count)) end
    end
    if not prerequisite then RebuildPrerequisites(mine) end
    SyncShopping()
end

local function Remove(recipeID, prerequisite)
    local mine = Mine()
    EnsurePlan(mine)
    local bucket = prerequisite and mine.prerequisites or mine.crafts
    bucket[recipeID] = nil
    if active and active.recipeID == recipeID and active.prerequisite == prerequisite then
        running, active = nil, nil
        runID = runID + 1
        if events then events:UnregisterAllEvents() end
    end
    if not prerequisite then RebuildPrerequisites(mine) end
    SyncShopping()
end

local function RemoveCraft(recipeID)
    local prerequisite = Mine().prerequisites[recipeID]
    if prerequisite then prerequisite.standalone = nil end
    Remove(recipeID, false)
end

local function Requirements(entry)
    local rows, missing, vendorCost = {}, false, 0
    for itemID, per in pairs(entry.need or EMPTY) do
        local need = per * (tonumber(entry.count) or 1)
        local have = R.ItemCount(itemID)
        local short = math.max(0, need - have)
        local vendor = V.IsVendorItem(itemID) and true or false
        local price = vendor and V.Prices()[itemID]
        if short > 0 then
            missing = true
            if price then vendorCost = vendorCost + price * short end
        end
        rows[#rows + 1] = { itemID = itemID, name = R.ItemName(itemID) or ("Item " .. itemID),
            need = need, have = have, missing = short, vendor = vendor, vendorPrice = price }
    end
    table.sort(rows, function(a, b) return a.name < b.name end)
    return rows, missing, vendorCost
end

local function Missing(entry)
    for itemID, per in pairs(entry.need or EMPTY) do
        if R.ItemCount(itemID) < per * (tonumber(entry.count) or 1) then return true end
    end
    return false
end

local function ProfessionOpen(entry)
    local id = OpenProfessionID()
    return id ~= nil and (not entry.prof or id == entry.prof)
end

local function CanCraft(entry)
    if Missing(entry) then return false end
    if not ProfessionOpen(entry) then return true end
    local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, entry.recipeID)
    if not ok then return false end
    if not (info and info.learned ~= false) then return false end
    local okCooldown, cooldown = pcall(C_TradeSkillUI.GetRecipeCooldown, entry.recipeID)
    if okCooldown and cooldown and cooldown > 0 then return false end
    local okRequirements, requirements = pcall(C_TradeSkillUI.GetRecipeRequirements, entry.recipeID)
    if okRequirements and requirements then
        local unmet = false
        wipe(unmetNames)
        for _, requirement in ipairs(requirements) do
            if requirement.met == false then
                unmet = true
                if requirement.name then unmetNames[#unmetNames + 1] = requirement.name end
            end
        end
        if #unmetNames > 0 then return false, table.concat(unmetNames, ", ") end
        if unmet then return false end
    end
    return true
end

local function ByEntryName(a, b)
    if (a.name or "") ~= (b.name or "") then return (a.name or "") < (b.name or "") end
    return (a.recipeID or 0) < (b.recipeID or 0)
end

local function Order(mine, prerequisite)
    if type(mine.order) ~= "table" then mine.order = {} end
    local key = prerequisite and "prerequisites" or "crafts"
    local order = mine.order[key]
    if type(order) ~= "table" then
        order = {}
        mine.order[key] = order
    end
    local bucket = prerequisite and mine.prerequisites or mine.crafts
    wipe(orderedRecipes)
    local write = 0
    for _, recipeID in ipairs(order) do
        if bucket[recipeID] and not orderedRecipes[recipeID] then
            write = write + 1
            order[write] = recipeID
            orderedRecipes[recipeID] = true
        end
    end
    for i = write + 1, #order do order[i] = nil end
    wipe(missingEntries)
    for recipeID, entry in pairs(bucket) do
        if not orderedRecipes[recipeID] then missingEntries[#missingEntries + 1] = entry end
    end
    table.sort(missingEntries, ByEntryName)
    for _, entry in ipairs(missingEntries) do order[#order + 1] = entry.recipeID end
    return order, bucket
end

local function Ordered()
    local mine = Mine()
    EnsurePlan(mine)
    wipe(orderedEntries)
    for _, prerequisite in ipairs(BUCKET_ORDER) do
        local order, bucket = Order(mine, prerequisite)
        for _, recipeID in ipairs(order) do
            local entry = bucket[recipeID]
            entry.prerequisite = prerequisite
            orderedEntries[#orderedEntries + 1] = entry
        end
    end
    return orderedEntries
end

local PrepareNext

local function Move(recipeID, prerequisite, targetID)
    if active and active.started then return false end
    local mine = Mine()
    EnsurePlan(mine)
    local order, bucket = Order(mine, prerequisite)
    if not (bucket[recipeID] and bucket[targetID]) or recipeID == targetID then return false end
    local from, target
    for i, id in ipairs(order) do
        if id == recipeID then from = i end
        if id == targetID then target = i end
    end
    if not (from and target) then return false end
    table.remove(order, from)
    table.insert(order, target, recipeID)
    if running and active then PrepareNext() else Redraw() end
    return true
end

local function FinishActive()
    if not active then return end
    local bucket = Bucket(active.prerequisite)
    local entry = bucket[active.recipeID]
    if entry then
        local count = tonumber(entry.count) or 1
        local standalone = tonumber(entry.standalone) or 0
        if standalone > 0 and count - standalone <= 0 then entry.standalone = standalone - 1 end
        entry.count = count - 1
        if entry.count <= 0 then bucket[active.recipeID] = nil end
    end
    active.done = active.done + 1
    SyncShopping()
end

local function Stop()
    running, active = nil, nil
    runID = runID + 1
    if events then events:UnregisterAllEvents() end
    Redraw()
end

local function Continue()
    if not running then return end
    local expectedRun = runID
    active = nil
    C_Timer.After(QUEUE_DELAY, function()
        if running and runID == expectedRun then PrepareNext() end
    end)
end

local function OnCraftEvent(_, event, unit, _, spellID)
    if not (running and active) then return end
    if event == "BAG_UPDATE_DELAYED" then return SyncShopping() end
    if event == "TRADE_SKILL_CLOSE" then
        if active.started then
            local entry = Bucket(active.prerequisite)[active.recipeID]
            active.requested = entry and (tonumber(entry.count) or 1) or active.requested
            active.done, active.started = 0, false
        end
        return Redraw()
    end
    if not active.started then return end
    if unit ~= "player" or spellID ~= active.recipeID then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        FinishActive()
        if active.done >= active.requested then Continue() end
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        Stop()
    end
end

local function SelectForCrafting(entry)
    if not ProfessionOpen(entry) then return end
    W.selectedID, W.selectedUnlearned = entry.recipeID, nil
    if P.List and P.List.Render then P.List.Render() end
    if P.Detail and P.Detail.Render then P.Detail.Render() end
    local frame = W.frame
    if frame and frame.qty then frame.qty:SetText(tostring(entry.count)) end
end

local function CraftContextReady(entry)
    if not ProfessionOpen(entry) then return false end
    local selected = R.SelectedInfo()
    return selected and selected.recipeID == entry.recipeID
end

local function PrepareCraftContext(entry)
    SelectForCrafting(entry)
    if CraftContextReady(entry) then return true end
    ns.Print(TEXT_OPEN_REQUIRED)
    return false
end

function PrepareNext()
    if not running then return end
    local entries = Ordered()
    if #entries == 0 then return Stop() end
    local chosen, blockedRequirement
    for _, entry in ipairs(entries) do
        local canCraft, requirement = CanCraft(entry)
        if canCraft then chosen = entry break end
        blockedRequirement = blockedRequirement or requirement
    end
    if not chosen then
        Stop()
        return ns.Print(blockedRequirement and TEXT_REQUIRES:format(blockedRequirement) or TEXT_NOTHING)
    end
    local count = tonumber(chosen.count) or 1
    active = { recipeID = chosen.recipeID, prerequisite = chosen.prerequisite,
        requested = count, done = 0, started = false }
    SelectForCrafting(chosen)
    Redraw()
end

local function OnCraftRequested(recipeID, count)
    if not (running and active and recipeID == active.recipeID) then return end
    local entry = Bucket(active.prerequisite)[active.recipeID]
    if not entry then return Stop() end
    if not CraftContextReady(entry) then return end
    active.requested = math.min(tonumber(count) or 1, tonumber(entry.count) or 1)
    active.done, active.started = 0, true
    Redraw()
end

local function EnableRuntime()
    if not On() then return false end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnCraftEvent)
    end
    if not hooked then
        hooksecurefunc(C_TradeSkillUI, "CraftRecipe", OnCraftRequested)
        hooksecurefunc(ns, "Apply", Apply)
        hooked = true
    end
    return true
end

local function Start()
    if running then return end
    if not EnableRuntime() then return end
    runID = runID + 1
    running = true
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("TRADE_SKILL_CLOSE")
    Redraw()
    PrepareNext()
end

local function Click()
    if not On() then return end
    if InCombatLockdown() then return end
    if not running then
        Start()
        if running and active then
            local entry = Bucket(active.prerequisite)[active.recipeID]
            if entry and not CraftContextReady(entry) then PrepareCraftContext(entry) end
        end
        return
    end
    if not (active and not active.started) then return end
    local entry = Bucket(active.prerequisite)[active.recipeID]
    if not entry then return Stop() end
    if not PrepareCraftContext(entry) then return end
    R.Craft(active.requested)
end

local function DropShopping()
    local changed = false
    for recipeID, craft in pairs(Shopping.List()) do
        local queued = tonumber(craft.queueCount) or (craft.fromQueue and tonumber(craft.count)) or 0
        if queued > 0 then
            craft.count = math.max(0, (tonumber(craft.count) or 0) - queued)
            craft.queueCount, craft.fromQueue, craft.got = nil, nil, nil
            if craft.count == 0 then Shopping.List()[recipeID] = nil end
            changed = true
        end
    end
    return changed
end

SyncShopping = function()
    local mine = Mine()
    EnsurePlan(mine)
    DropShopping()

    local entries = {}
    for _, entry in pairs(mine.crafts) do
        entries[#entries + 1] = { entry = entry, count = tonumber(entry.count) or 1 }
    end
    for _, entry in pairs(mine.prerequisites) do
        if (tonumber(entry.standalone) or 0) > 0 then
            entries[#entries + 1] = { entry = entry, count = tonumber(entry.standalone) }
        end
    end
    table.sort(entries, function(a, b) return (a.entry.name or "") < (b.entry.name or "") end)

    local inventory = {}
    local purchased = Shopping.Have()
    for _, candidate in ipairs(entries) do
        local entry = candidate.entry
        for itemID in pairs(entry.need or EMPTY) do
            if inventory[itemID] == nil then
                inventory[itemID] = math.max(0, R.ItemCount(itemID) - (purchased[itemID] or 0))
            end
        end
    end
    for _, candidate in ipairs(entries) do
        local entry = candidate.entry
        local count = candidate.count
        local got = {}
        for itemID, per in pairs(entry.need or EMPTY) do
            local want = per * count
            local have = math.min(want, inventory[itemID] or 0)
            inventory[itemID] = (inventory[itemID] or 0) - have
            if have > 0 then got[itemID] = have end
        end
        local info = { recipeID = entry.recipeID, name = entry.name, icon = entry.icon }
        Shopping.Add(info, count, next(got) and got or nil, true, true, true)
    end
    Shopping.Trim()
    Redraw()
    Shopping.Redraw()
end

local function Clear()
    local mine = Mine()
    running, active = nil, nil
    runID = runID + 1
    if events then events:UnregisterAllEvents() end
    wipe(mine.prerequisites)
    wipe(mine.crafts)
    mine.order = nil
    SyncShopping()
end

local function AddWithShopping(info, count)
    if not On() then return end
    Add(info, count, nil, true)
    if ShoppingOn() then SyncShopping() else Redraw() end
end

local function AddMissingToShopping()
    if not (On() and ShoppingOn()) then return false end
    EnsurePlan(Mine())
    SyncShopping()
    return true
end

local function Count(recipeID)
    if not On() then return 0 end
    local mine = Mine()
    EnsurePlan(mine)
    local craft = mine.crafts[recipeID]
    local prerequisite = mine.prerequisites[recipeID]
    return math.max(0, tonumber(craft and craft.count) or 0)
        + math.max(0, tonumber(prerequisite and prerequisite.count) or 0)
end

Apply = function(key)
    if key and not APPLY_KEYS[key] then return end
    local on = On() and true or false
    if on == applied then return end
    applied = on
    if on then
        local mine = Mine()
        if next(mine.crafts) or next(mine.prerequisites) then SyncShopping() end
    else
        if running or active then Stop() end
        if DropShopping() then
            Shopping.Trim()
            Shopping.Redraw()
        end
        if P.CraftQueueView then P.CraftQueueView.Hide() end
        Redraw()
    end
    if ns.ProfWindowRefresh then ns.ProfWindowRefresh() end
end

Queue.List = Mine
Queue.Add = Add
Queue.AddWithShopping = AddWithShopping
Queue.AddMissingToShopping = AddMissingToShopping
Queue.Count = Count
Queue.Step = Step
Queue.Remove = Remove
Queue.RemoveCraft = RemoveCraft
Queue.Clear = Clear
Queue.Requirements = Requirements
Queue.Missing = Missing
Queue.Ordered = Ordered
Queue.Move = Move
Queue.Click = Click
Queue.Running = function() return running and true or false end
Queue.Active = function() return active end
Queue.Ready = function()
    if not active then return false end
    local entry = Bucket(active.prerequisite)[active.recipeID]
    return entry and CraftContextReady(entry) and true or false
end
Queue.EnableRuntime = EnableRuntime

S.OnChange(Apply)

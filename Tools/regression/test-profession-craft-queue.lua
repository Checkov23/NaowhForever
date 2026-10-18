-- Crafting queue regression coverage: prerequisites, shopping demand, and ordered execution.
local frames = {}
local inventory = { [2000] = 0, [3000] = 0, [4000] = 0, [5000] = 0 }
local crafts = {}
local account = {}
local shoppingList, shoppingHave = {}, {}
local shoppingAdds = {}
local selected, quantity
local craftHook, applyHook
local openProfession = 1
local protectedOpenCalls = 0
local settings = { enabled = true, shoppingList = true, craftQueue = false }
local settingChanged
local printed
local recipeRequirements = {}
local playerName = "Tester"
local bagRoom = 999

local function Wipe(t) for key in pairs(t) do t[key] = nil end return t end
local function Noop() end
local frameMethods = {}
for _, name in ipairs({ "RegisterUnitEvent", "RegisterEvent", "UnregisterAllEvents", "SetHeight", "SetWidth",
    "SetSize", "SetPoint", "ClearAllPoints", "EnableMouse", "RegisterForDrag", "SetText", "SetTexture",
    "SetJustifyH", "SetWordWrap", "SetScrollChild", "SetScale" }) do
    frameMethods[name] = Noop
end
local frameMeta = { __index = frameMethods }
local function CreateFrame(_, _, parent)
    local frame = setmetatable({ scripts = {}, hooks = {}, parent = parent, shown = true }, frameMeta)
    frames[#frames + 1] = frame
    return frame
end
function frameMethods:SetScript(name, fn)
    self.scripts[name] = fn
    if name == "OnEvent" then self.onEvent = fn end
end
function frameMethods:HookScript(name, fn) self.hooks[name] = fn end
function frameMethods:GetParent() return self.parent end
function frameMethods:GetWidth() return 0 end
function frameMethods:IsShown() return self.shown end
function frameMethods:Hide() self.shown = false end
function frameMethods:SetShown(shown) self.shown = shown and true or false end
function frameMethods:CreateTexture() return CreateFrame(nil, nil, self) end
function frameMethods:Show()
    self.shown = true
    if self.hooks.OnShow then self.hooks.OnShow(self) end
end

local timer = { After = function(_, fn) fn() end }
local professionsFrame = { shown = true, IsShown = function(self) return self.shown end }
local spell = {
    GetSpellName = function(id) return "Recipe " .. id end,
    GetSpellTexture = function(id) return id end,
}
local tradeSkill = {
    GetRecipeInfo = function(id)
        local name = id == 100 and "Main Craft" or id == 101 and "Second Main Craft" or "Prerequisite"
        return { recipeID = id, name = name, icon = id, learned = true }
    end,
    GetRecipeCooldown = function() return nil end,
    GetRecipeRequirements = function() return recipeRequirements end,
    CraftRecipe = function(id, count)
        crafts[#crafts + 1] = { id = id, count = count }
        if craftHook then craftHook(id, count) end
    end,
    OpenRecipe = function() protectedOpenCalls = protectedOpenCalls + 1 end,
}

local makes = {
    [1000] = { recipe = 100, made = 1, need = { [2000] = 1, [3000] = 2, [4000] = 1 } },
    [1001] = { recipe = 101, made = 1, need = { [2000] = 1 } },
    [2000] = { recipe = 200, made = 1, need = { [5000] = 2 } },
}
local reagents = {
    [100] = { { itemID = 2000, need = 1 }, { itemID = 3000, need = 2 }, { itemID = 4000, need = 1 } },
    [101] = { { itemID = 2000, need = 1 } },
    [200] = { { itemID = 5000, need = 2 } },
}

local ns
ns = {
    L = function(text) return text end,
    Print = function(text) printed = text end,
    AccountSettings = function() return account end,
    CraftBagRoom = function(_, _, _, limit) return math.min(bagRoom, limit) end,
    Professions = {
        Settings = {
            Get = function(key) return settings[key] end,
            OnChange = function(fn) settingChanged = fn end,
        },
        C = { MAX_CRAFTS = 999, QUEUE_DELAY = 0 },
        State = { frame = { qty = { SetText = function(_, value) quantity = value end } } },
        List = { Render = function() end },
        Detail = { Render = function() end },
        Recipes = {
            Profession = function() return { id = openProfession } end,
            Reagents = function(id) return reagents[id] or {} end,
            OutputItem = function(id)
                return id == 100 and 1000 or id == 101 and 1001 or id == 300 and 3001 or 2000, 1
            end,
            ItemCount = function(id) return inventory[id] or 0 end,
            ItemName = function(id) return "Item " .. id end,
            Owned = function() return {} end,
            SelectedInfo = function()
                local id = ns.Professions.State.selectedID
                return id and tradeSkill.GetRecipeInfo(id)
            end,
            Craft = function(count)
                local id = ns.Professions.State.selectedID
                if id then tradeSkill.CraftRecipe(id, count) end
            end,
        },
        Shopping = {
            Makes = function() return makes end,
            Cheapest = function(item) return item == 2000 and 40 or 20, item == 2000 end,
            List = function() return shoppingList end,
            Have = function() return shoppingHave end,
            Materials = function() return {}, {} end,
            Trim = function() end,
            Redraw = function() end,
            Add = function(info, count, got, _, fromQueue)
                shoppingAdds[info.recipeID] = count
                local craft = shoppingList[info.recipeID]
                if craft then
                    craft.count = craft.count + count
                    if fromQueue then craft.queueCount = (craft.queueCount or 0) + count end
                    craft.fromQueue = craft.queueCount == craft.count
                    craft.got = got
                else
                    shoppingList[info.recipeID] = { name = info.name, count = count, got = got,
                        fromQueue = fromQueue and true or false, queueCount = fromQueue and count or nil }
                end
            end,
        },
        Vendors = {
            IsVendorItem = function(id) return id == 4000 end,
            Prices = function() return { [4000] = 25 } end,
        },
    },
}
local env = setmetatable({
    NaowhForever = ns,
    C_Timer = timer,
    C_Item = {},
    C_Spell = spell,
    C_TradeSkillUI = tradeSkill,
    ProfessionsFrame = professionsFrame,
    CreateFrame = CreateFrame,
    GetRealmName = function() return "Realm" end,
    UnitName = function() return playerName end,
    hooksecurefunc = function(_, name, fn)
        if name == "CraftRecipe" then craftHook = fn elseif name == "Apply" then applyHook = fn end
    end,
    InCombatLockdown = function() return false end,
    UNKNOWNOBJECT = "Unknown",
    wipe = Wipe,
}, { __index = _G })
env._G = env
local Load = dofile("Tools/regression/load_files.lua")
Load({ "NaowhForever_Professions/CraftQueue.lua" }, env)
local queue = assert(ns.Professions.CraftQueue)
assert(#frames == 0 and craftHook == nil, "loading the disabled runtime created a frame or hook")
settings.craftQueue = true

queue.Add(tradeSkill.GetRecipeInfo(100), 2)
local list = queue.List()
assert(list.crafts[100] and list.crafts[100].count == 2, "main craft was not queued")
assert(list.prerequisites[200] and list.prerequisites[200].count == 2, "prerequisite craft was not queued")
queue.Add(tradeSkill.GetRecipeInfo(101), 1)
local ordered = queue.Ordered()
assert(ordered[1].prerequisite and ordered[2].recipeID == 100 and ordered[3].recipeID == 101,
    "the initial queue order did not keep prerequisites first and crafts alphabetical")
assert(queue.Move(100, false, 101), "a craft could not be moved within its section")
ordered = queue.Ordered()
assert(ordered[1].prerequisite and ordered[2].recipeID == 101 and ordered[3].recipeID == 100,
    "the moved craft order was not saved")
assert(not queue.Move(200, true, 100) and queue.Ordered()[1].recipeID == 200,
    "a prerequisite moved into the regular craft section")
queue.Remove(101, false)

local _, missing, vendorCost = queue.Requirements(list.crafts[100])
assert(missing == true, "missing materials were not detected")
assert(vendorCost == 50, "vendor price was not calculated for the missing quantity")

inventory[5000], inventory[3000], inventory[4000] = 4, 4, 2
queue.Click()
selected = ns.Professions.State.selectedID
assert(selected == 200 and quantity == "2", "prerequisites must be prepared first")
assert(#crafts == 0, "Start Queue must only prepare, not craft")
queue.Step(200, true, -1)
assert(queue.Active().requested == 1 and quantity == "1",
    "editing a prepared craft did not synchronize its active quantity")
queue.Step(200, true, 1)
assert(queue.Active().requested == 2 and quantity == "2",
    "increasing a prepared craft did not synchronize its active quantity")

local event = assert(frames[1].onEvent)
queue.Click()
assert(crafts[1] and crafts[1].id == 200 and crafts[1].count == 2,
    "Craft Next did not request the prepared prerequisite batch")
event(frames[1], "UNIT_SPELLCAST_SUCCEEDED", "player", nil, 200)
inventory[2000] = 2
event(frames[1], "UNIT_SPELLCAST_SUCCEEDED", "player", nil, 200)
assert(ns.Professions.State.selectedID == 100 and quantity == "2", "main craft was not prepared after prerequisites")

queue.Click()
assert(crafts[2] and crafts[2].id == 100 and crafts[2].count == 2,
    "Craft Next did not request the prepared main batch")
event(frames[1], "UNIT_SPELLCAST_SUCCEEDED", "player", nil, 100)
event(frames[1], "UNIT_SPELLCAST_SUCCEEDED", "player", nil, 100)
assert(next(queue.List().prerequisites) == nil and next(queue.List().crafts) == nil,
    "completed crafts remained in the queue")

shoppingList[101] = { name = "Waiting", icon = 101, count = 1, need = { [6000] = 1 } }
shoppingList[102] = { name = "Queued", count = 1, fromQueue = true }
queue.Clear()
assert(next(queue.List().prerequisites) == nil and next(queue.List().crafts) == nil,
    "Clear did not empty the crafting queue")
assert(shoppingList[102] == nil, "Clear did not remove queue-generated shopping entries")
assert(shoppingList[101] ~= nil, "Clear removed an unrelated Shopping List entry")

queue.Add(tradeSkill.GetRecipeInfo(100), 1)
professionsFrame.shown = false
local craftedBefore = #crafts
queue.Click()
assert(protectedOpenCalls == 0, "Start Queue attempted a protected profession-opening call")
assert(#crafts == craftedBefore and queue.Running() and not queue.Active().started,
    "a closed profession incorrectly started or stuck the craft")
professionsFrame.shown = true
queue.Click()
assert(#crafts == craftedBefore + 1 and queue.Active().started,
    "Craft Next did not craft after the player opened the profession")
professionsFrame.shown = false
event(frames[1], "TRADE_SKILL_CLOSE")
assert(queue.Running() and not queue.Active().started,
    "closing the profession did not return the active batch to a ready state")
craftedBefore = #crafts
queue.Click()
assert(protectedOpenCalls == 0 and #crafts == craftedBefore and not queue.Active().started,
    "Craft Next attempted a protected call or stale craft while the profession was closed")
queue.Clear()

shoppingList[100] = { name = "Manual", count = 3, need = { [3000] = 2 } }
queue.AddWithShopping(tradeSkill.GetRecipeInfo(100), 1)
assert(shoppingList[100].count == 4 and shoppingList[100].queueCount == 1 and not shoppingList[100].fromQueue,
    "queue demand did not merge safely with a manual Shopping List entry")
settings.craftQueue = false
settingChanged("craftQueue")
assert(shoppingList[100].count == 3 and queue.List().crafts[100],
    "turning the feature off did not detach its Shopping List demand")
settings.craftQueue = true
settingChanged("craftQueue")
assert(shoppingList[100].count == 4 and shoppingList[100].queueCount == 1,
    "turning the feature back on did not restore its Shopping List demand")
queue.Clear()
assert(shoppingList[100] and shoppingList[100].count == 3 and shoppingList[100].queueCount == nil,
    "clearing the queue removed manual Shopping List demand")
shoppingList[100] = nil

inventory[2000], inventory[5000] = 1, 4
queue.Add(tradeSkill.GetRecipeInfo(100), 1)
queue.Add(tradeSkill.GetRecipeInfo(101), 1)
assert(queue.List().prerequisites[200] and queue.List().prerequisites[200].count == 1,
    "the same bag reagent was counted twice across dependent queued crafts")
queue.Clear()

inventory[2000], inventory[5000] = 0, 4
Wipe(shoppingAdds)
queue.AddWithShopping(tradeSkill.GetRecipeInfo(200), 1)
queue.AddWithShopping(tradeSkill.GetRecipeInfo(100), 1)
local merged = queue.List()
assert(merged.prerequisites[200] and merged.prerequisites[200].count == 2,
    "standalone and prerequisite demand for the same recipe was not combined")
assert(merged.prerequisites[200].standalone == 1 and merged.crafts[200] == nil,
    "combined recipe did not preserve its standalone demand")
assert(shoppingAdds[200] == 1,
    "combined prerequisite lost the shopping materials for its standalone craft")
Wipe(shoppingAdds)
assert(queue.AddMissingToShopping(), "missing-material refresh did not run")
assert(shoppingAdds[100] == 1 and shoppingAdds[200] == 1,
    "missing-material refresh did not rebuild queue-backed shopping entries")
queue.Clear()

Wipe(shoppingList)
professionsFrame.shown = true
inventory[2000], inventory[3000], inventory[4000], inventory[5000] = 0, 4, 2, 4
queue.AddWithShopping(tradeSkill.GetRecipeInfo(100), 2)
assert(shoppingList[100] and shoppingList[100].queueCount == 2, "queued craft did not reach the Shopping List")
queue.Click()
queue.Click()
event(frames[1], "UNIT_SPELLCAST_SUCCEEDED", "player", nil, 200)
inventory[2000] = 2
event(frames[1], "UNIT_SPELLCAST_SUCCEEDED", "player", nil, 200)
queue.Click()
event(frames[1], "UNIT_SPELLCAST_SUCCEEDED", "player", nil, 100)
assert(shoppingList[100] and shoppingList[100].count == 1 and shoppingList[100].queueCount == 1,
    "finishing a craft did not lower its Shopping List demand")
event(frames[1], "UNIT_SPELLCAST_SUCCEEDED", "player", nil, 100)
assert(next(queue.List().crafts) == nil and not queue.Running(), "the crafted queue did not empty and stop")
assert(next(shoppingList) == nil, "crafting the whole queue left its demand on the Shopping List")

makes[3001] = { recipe = 300, made = 1, need = { [7000] = 1 }, prof = 2 }
reagents[300] = { { itemID = 7000, need = 1 } }
inventory[7000] = 1
queue.Add(tradeSkill.GetRecipeInfo(300), 1)
ns.Professions.State.selectedID = 999
local craftedBefore2 = #crafts
queue.Click()
assert(queue.Running() and queue.Active().recipeID == 300,
    "an entry for a closed profession was skipped instead of waiting to be opened")
assert(ns.Professions.State.selectedID == 999 and not queue.Ready(),
    "Start Queue changed the open profession's selection for another profession's craft")
queue.Click()
assert(ns.Professions.State.selectedID == 999 and #crafts == craftedBefore2,
    "Craft Next touched the open profession while another one was needed")
openProfession = 2
queue.Click()
assert(ns.Professions.State.selectedID == 300 and #crafts == craftedBefore2 + 1,
    "Craft Next did not craft once the right profession was open")
queue.Clear()
openProfession = 1

inventory[2000] = 1
recipeRequirements = {
    { name = "Forge", met = false },
    { name = "Blacksmith Hammer", met = false },
}
queue.Add(tradeSkill.GetRecipeInfo(101), 1)
queue.Click()
assert(printed == "Requires: Forge, Blacksmith Hammer",
    "an unmet tool or location reported the missing-material message")
assert(not queue.Running(), "a queue blocked by a tool or location remained stuck as running")
recipeRequirements = {}
inventory[2000] = 2
queue.Clear()

bagRoom = 0
queue.Add(tradeSkill.GetRecipeInfo(101), 1)
local beforeBagBlock = #crafts
queue.Click()
assert(printed == "Your bags do not have room for Item 1001.",
    "a full bag did not report the blocked queue output")
assert(not queue.Running() and #crafts == beforeBagBlock,
    "a queue batch started or stayed running without bag room")
queue.Clear()

bagRoom = 1
inventory[2000] = 3
queue.Add(tradeSkill.GetRecipeInfo(101), 3)
queue.Click()
assert(queue.Active().requested == 1 and quantity == "1",
    "the prepared batch was not capped to the available bag room")
queue.Click()
assert(crafts[#crafts].id == 101 and crafts[#crafts].count == 1,
    "Craft Next ignored the bag-room batch cap")
queue.Clear()
bagRoom = 999

queue.Add(tradeSkill.GetRecipeInfo(100), 1)
Wipe(shoppingAdds)
assert(applyHook, "the profile hook was not installed with the runtime")
applyHook()
applyHook()
assert(next(shoppingAdds) == nil, "a profile apply with nothing changed rebuilt the queue's Shopping List entries")
settings.craftQueue = false
applyHook()
local listed = shoppingList[100]
applyHook()
assert(next(shoppingAdds) == nil and shoppingList[100] == listed, "the profile hook did work while the queue was off")
settings.craftQueue = true
applyHook()
assert(shoppingAdds[100] == 1, "turning the queue back on through a profile did not restore its demand")
queue.Clear()

queue.Add(tradeSkill.GetRecipeInfo(100), 1)
playerName = "Alt"
Load({ "NaowhForever_Professions/CraftQueue.lua" }, env)
local alt = ns.Professions.CraftQueue
assert(next(alt.List().crafts) == nil and next(alt.List().prerequisites) == nil,
    "another character inherited the first character's crafting queue")
alt.Add(tradeSkill.GetRecipeInfo(101), 1)
assert(alt.List().crafts[101] and not alt.List().crafts[100],
    "the second character did not get an independent crafting queue")
assert(queue.List().crafts[100] and not queue.List().crafts[101],
    "the first character's crafting queue changed with the second character's")
alt.Clear()

playerName = "Unknown"
Load({ "NaowhForever_Professions/CraftQueue.lua" }, env)
local unknown = ns.Professions.CraftQueue
unknown.Add(tradeSkill.GetRecipeInfo(101), 1)
assert(account.profCraftQueue["Unknown-Realm"] == nil, "the queue was saved under an unknown character")
playerName = "Late"
assert(next(unknown.List().crafts) == nil and account.profCraftQueue["Late-Realm"],
    "the queue did not pick up the character once its name was known")

playerName = "Tester"
Load({ "NaowhForever_Professions/CraftQueue.lua" }, env)
queue = ns.Professions.CraftQueue

queue.Add(tradeSkill.GetRecipeInfo(101), 1)
assert(next(queue.List().prerequisites) == nil, "a craft with its materials in the bags queued a prerequisite")

local Zero = { __index = function() return 0 end }
local rgb = { r = 0, g = 0, b = 0 }
local tooltipLines = {}
local focus
ns.THEME = { muted = rgb, fg = rgb, accent = rgb }
ns.UI = { SlimScroll = function(parent) return CreateFrame(nil, nil, parent) end }
ns.Shared = {
    Style = setmetatable({}, Zero),
    Parts = {
        Window = function()
            local window = CreateFrame()
            window.backdrop = { Card = Noop, Paint = Noop }
            window.subtitle = CreateFrame(nil, nil, window)
            window.shown = false
            return window
        end,
        TitleBar = function(window) return CreateFrame(nil, nil, window) end,
        FooterBrand = Noop,
        Resizable = Noop,
    },
}
ns.Font = function(parent) return CreateFrame(nil, nil, parent) end
ns.Button = function(parent) return CreateFrame(nil, nil, parent) end
ns.Tooltip, ns.AccentBorder, ns.SetButtonText = Noop, Noop, Noop
ns.UIScale = function() return 1 end
ns.Professions.Text = {}
ns.Professions.Style = setmetatable({}, Zero)
ns.Professions.Widgets = { Crop = function(texture) return texture end, EnableButton = Noop }
env.GetMouseFoci = function() return { focus } end
env.GameTooltip_Hide = Noop
env.GameTooltip = {
    SetOwner = function() Wipe(tooltipLines) end,
    SetRecipeResultItem = Noop,
    AddLine = function(_, text) tooltipLines[#tooltipLines + 1] = text end,
    Show = Noop,
}
Load({ "NaowhForever_Professions/UI/CraftQueue.lua" }, env)
ns.OpenCraftQueue()

local function Row(recipeID)
    for _, frame in ipairs(frames) do
        if frame.scripts.OnDragStart and frame.shown and frame.entry and frame.entry.recipeID == recipeID then
            return frame
        end
    end
end

local function Drag(recipeID, targetID)
    local row = assert(Row(recipeID), "a queued craft has no row")
    focus = assert(Row(targetID), "a queued craft has no row").remove
    row.scripts.OnDragStart(row)
    row.scripts.OnDragStop(row)
end

local function CraftOrder()
    local ids = {}
    for _, entry in ipairs(queue.Ordered()) do ids[#ids + 1] = entry.recipeID end
    return table.concat(ids, ",")
end

local function HintShown(recipeID)
    local row = Row(recipeID)
    row.scripts.OnEnter(row)
    return tooltipLines[#tooltipLines] == "Drag to reorder within this section."
end

assert(CraftOrder() == "100,101" and HintShown(100), "the queue rows did not offer reordering")
Drag(100, 101)
assert(CraftOrder() == "101,100", "dropping a row on another row did not reorder the queue")

queue.Click()
assert(queue.Active().recipeID == 101 and ns.Professions.State.selectedID == 101,
    "Start Queue did not prepare the first craft in the dragged order")
Drag(100, 101)
assert(CraftOrder() == "100,101" and queue.Active().recipeID == 100 and not queue.Active().started,
    "reordering a prepared queue did not re-pick its next craft")
assert(ns.Professions.State.selectedID == 100, "reordering a prepared queue left the old craft selected")
local craftedBefore3 = #crafts
queue.Click()
assert(#crafts == craftedBefore3 + 1 and crafts[#crafts].id == 100,
    "Craft Next crafted the pick from before the reorder")

assert(queue.Active().started and not HintShown(101), "a started craft still offered dragging")
Drag(101, 100)
assert(CraftOrder() == "100,101", "a row was reordered while a craft was running")
queue.Clear()

print("Crafting queue regression test: PASS")

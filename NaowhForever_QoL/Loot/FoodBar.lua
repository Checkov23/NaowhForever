-- FoodBar.lua: the Food & Drink Bar, your best food and drink on two buttons.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local Shared = ns.Shared
local ItemBar, ActionKeys = Shared.ItemBar, Shared.ActionKeys

local PREFIX = "foodBar"
local DEFAULT_Y = -210
local BAR_BUTTONS = 2
local GAP = 4
local GROW, PER_ROW = "RIGHT", 2
local MOVER_LABEL = ns.L("Food & Drink")
local CONSUMABLE_PAGE, LOOT_PAGE = "Consumable Bar/Settings", "QoL/Loot & Items"
local CARD_ID = "foodBar"
local ORDER_CONSUMABLE, ORDER_LOOT = 35, 55
local SUMMARY = ns.L("%d px buttons")
local BAR_NAME = ns.L("Food & Drink Bar")

local EMPTY = { { icon = 133971, text = ns.L("No food in your bags") },
    { icon = 132794, text = ns.L("No drink in your bags") } }
local STAGE_H = 100
local ICON_RANGE = { 20, 70, 1 }
local BUTTON_NAMES = { "NaowhForeverFoodBarFood", "NaowhForeverFoodBarDrink" }
local BINDINGS = { "CLICK NaowhForeverFoodBarFood:LeftButton", "CLICK NaowhForeverFoodBarDrink:LeftButton" }
local MOVED = { "foodBar", "foodBarSize", "foodBarPos" }
local LOOK = { foodBarShowCount = true, foodBarFont = true, foodBarFontSize = true, foodBarTextColor = true,
    foodBarTextPoint = true, foodBarTextOutside = true, foodBarTextX = true, foodBarTextY = true,
    foodBarKeyFont = true, foodBarKeySize = true, foodBarKeyColor = true, foodBarKeyPoint = true,
    foodBarKeyOutside = true, foodBarKeyX = true, foodBarKeyY = true }

local page = (ns.ConsumableBar ~= nil and S.Get("consumableBar")) and CONSUMABLE_PAGE or LOOT_PAGE
local card = page .. ":" .. CARD_ID
local order = page == CONSUMABLE_PAGE and ORDER_CONSUMABLE or ORDER_LOOT

local bar, moving, pending
local events = CreateFrame("Frame")

local function Drinks()
    local class = select(2, UnitClass("player"))
    return class ~= "WARRIOR" and class ~= "ROGUE"
end

local function On()
    return S.Get("enabled") and S.Get("foodBar")
end

local function Migrate()
    local old, db = ns.SettingsRoot().macros, S.DB()
    if type(old) ~= "table" then return end
    for _, key in ipairs(MOVED) do
        if old[key] ~= nil and db[key] == nil then db[key] = old[key] end
        old[key] = nil
    end
end

local Look = {}

function Look.Layout(frame, size)
    local shown = Drinks() and BAR_BUTTONS or 1
    frame:SetSize(ItemBar.Size(shown, size, GAP, GROW, PER_ROW))
    for i, button in ipairs(frame.buttons) do
        button:SetSize(size, size)
        ItemBar.Place(button, frame, i, size, GAP, GROW, PER_ROW)
        ItemBar.StyleTexts(button, S, PREFIX)
        button:SetShown(i <= shown)
    end
end

function Look.Fill(button, i, icon, count)
    ItemBar.Fill(button, icon or EMPTY[i].icon, count, not icon)
    button.count:SetShown(S.Get("foodBarShowCount") ~= false)
end

local function FillButton(button, i, id)
    ItemBar.SetItem(button, id)
    Look.Fill(button, i, id and (C_Item.GetItemIconByID(id) or EMPTY[i].icon), id and C_Item.GetItemCount(id))
end

local function Fill()
    local food, drink = ns.BestFoodAndDrink()
    FillButton(bar.buttons[1], 1, food)
    FillButton(bar.buttons[2], 2, Drinks() and drink or nil)
end

local function ItemOfSlot(slot, item)
    if not slot then return item end
    local kind, id = GetActionInfo(slot)
    if kind == "item" then return id end
end

local keyMap = ActionKeys.NewMap(ItemOfSlot)

local function UpdateKeys()
    if not bar then return end
    local on = S.Get("foodBarKeybinds")
    local keyOf = on and keyMap.Read() or keyMap.Clear()
    for i, button in ipairs(bar.buttons) do
        local key = on and (ActionKeys.Bound(BINDINGS[i]) or (button.itemID and keyOf[button.itemID]))
        ItemBar.ShowKey(button, key or nil)
    end
end

local QueueKeys = ActionKeys.NewQueue(UpdateKeys)

local function SavePosition(pos)
    S.Set("foodBarPos", pos)
    if ItemBar.Anchored(S, PREFIX) then S.Set("foodBarAnchor", "UIParent") end
end

local function Build()
    bar = ItemBar.Frame("NaowhForeverFoodBar", MOVER_LABEL, SavePosition, page, card)
    ItemBar.Outline(bar, 0)
    bar.buttons = {}
    for i = 1, BAR_BUTTONS do
        local button = ItemBar.SecureButton(bar, BUTTON_NAMES[i])
        button.emptyTip = EMPTY[i].text
        bar.buttons[i] = button
    end
end

local function Apply()
    Migrate()
    if InCombatLockdown() then
        pending = true
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    pending = false
    if not On() then
        events:UnregisterAllEvents()
        if bar then bar:Hide() end
        return
    end
    ActionKeys.Listen(events, false)
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    ActionKeys.Listen(events, S.Get("foodBarKeybinds"))
    if not bar then Build() end
    Look.Layout(bar, S.Get("foodBarSize"))
    ItemBar.Put(bar, S, PREFIX, DEFAULT_Y)
    Fill()
    QueueKeys()
    bar.mover:SetShown(moving == true)
    bar:Show()
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        events:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if not pending then return end
    elseif event == "BAG_UPDATE_DELAYED" then
        if bar and bar:IsShown() and not InCombatLockdown() then
            Fill()
            QueueKeys()
            return
        end
    elseif event ~= "PLAYER_ENTERING_WORLD" then
        QueueKeys()
        return
    end
    Apply()
end

local function Restyle()
    if not (bar and On()) then return end
    if InCombatLockdown() then
        Apply()
        return
    end
    for _, button in ipairs(bar.buttons) do
        ItemBar.StyleTexts(button, S, PREFIX)
        button.count:SetShown(S.Get("foodBarShowCount") ~= false)
    end
    QueueKeys()
end

local function OnSettingChanged(key)
    if LOOK[key] then
        Restyle()
    elseif key == "enabled" or (key:find("^foodBar") and key ~= "foodBarPos") then
        Apply()
    end
end

events:SetScript("OnEvent", OnEvent)
events:RegisterEvent("PLAYER_ENTERING_WORLD")
hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function() moving = true; Apply() end)
hooksecurefunc(ns, "HideUnlockMode", function() moving = false; Apply() end)

local Settings = Shared.Settings
if not Settings then return end

local Group = Settings.Group
local SAMPLE_COUNTS = { 12, 20 }
local SAMPLE_KEYS = { "F1", "F2" }
local STATES = {
    { key = "stocked", label = "Stocked", tip = "Your best food and drink, with how many you carry." },
    { key = "empty", label = "Nothing Carried", tip = "Greyed out while your bags hold no food or drink." },
}

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetPoint("CENTER")
    preview.buttons = { ItemBar.NewButton(preview), ItemBar.NewButton(preview) }
    return preview
end

local function PaintPreview(preview, state)
    Look.Layout(preview, S.Get("foodBarSize"))
    local stocked = state == "stocked"
    for i, button in ipairs(preview.buttons) do
        Look.Fill(button, i, stocked and EMPTY[i].icon or nil, stocked and SAMPLE_COUNTS[i] or nil)
        local key = S.Get("foodBarKeybinds") and (ActionKeys.Bound(BINDINGS[i]) or SAMPLE_KEYS[i])
        ItemBar.ShowKey(button, key or nil)
    end
end

local function NoDrinks()
    return not Drinks()
end

local function Summary(store)
    return SUMMARY:format(store.Get("foodBarSize"))
end

local ANCHOR = { store = S, prefix = PREFIX, name = BAR_NAME, on = On, frame = function() return bar end }

local rows = {
    { key = "foodBarSize", label = "Icon Size", slider = ICON_RANGE,
      help = "How big each button is." },
}
for _, row in ipairs(ItemBar.TextRows(S, PREFIX)) do rows[#rows + 1] = row end
rows[#rows + 1] = Group("Key Bindings")
rows[#rows + 1] = { label = "Use Best Food", binding = BINDINGS[1], help = "Eats the food on the bar." }
rows[#rows + 1] = { label = "Use Best Drink", binding = BINDINGS[2], hidden = NoDrinks,
    help = "Drinks the drink on the bar." }
rows[#rows + 1] = Group("Anchor")
for _, row in ipairs(Shared.Anchor.Rows(ANCHOR)) do rows[#rows + 1] = row end

Settings.Page(page, S):Card({
    id = "foodBar", name = "Food & Drink Bar", order = order, switch = "foodBar",
    help = "Buttons for the best food and drink in your bags, conjured first; food only if you have "
        .. "no mana. Move it in the HUD Editor.",
    summary = Summary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = rows,
})

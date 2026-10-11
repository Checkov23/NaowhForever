-- Smart.lua: the Smart Macros, written and kept on the best item or spell you have, out of combat (ns.Macros.Smart).
local ns = _G.NaowhForever

local M = ns.Macros
local S = M.Settings
local C = M.C
local Items = M.Items

local QUESTION = C.QUESTION
local TRINKET_TOP, TRINKET_BOTTOM = 13, 14

local TEXT_FULL_CHARACTER = ns.L("Character macros are full, so %s could not be made. Delete one and it will be added.")
local TEXT_FULL_GENERAL = ns.L("General macros are full, so %s could not be made. Delete one and it will be added.")
local TEXT_IN_COMBAT = ns.L("Move macros outside combat.")
local TEXT_ENABLE_FIRST = ns.L("Enable Macros first.")
local TEXT_NO_ROOM = ns.L("Make room in General macros first.")
local TEXT_TOO_LONG = ns.L("%s with your extra lines is over %d characters, so they were left out.")
local TEXT_EXTRA_SCRIPT = ns.L("%s's extra lines run a script, so they were left out. Write scripts in /macro.")
local TEXT_REMOVE_IN_COMBAT = ns.L("Remove macros outside combat.")
local TEXT_HEADLINE = ns.L("%d of %d macros kept current for you")
local TEXT_OFF = ns.L("Turn on Macros to keep them current.")
local TEXT_NO_CLASS_MACROS = ns.L("Your profile has no class macros for your %s.")
local TEXT_CLASS_MACROS = ns.L("%d class macro%s from your profile for your %s.")
local TEXT_ON_BAR = ns.L("%s is on the Consumable Bar. Take it off the bar first (Consumable Bar > Settings).")

local MACROS = {
    { key = "health", name = "NF Health" },
    { key = "healthstone", name = "NF Healthstone" },
    { key = "healthPotion", name = "NF Health Potion" },
    { key = "mana", name = "NF Mana" },
    { key = "food", name = "NF Food" },
    { key = "drink", name = "NF Drink" },
    { key = "bandage", name = "NF Bandage" },
    { key = "trinket1", name = "NF Trinket 1" },
    { key = "trinket2", name = "NF Trinket 2" },
    { key = "focus", name = "NF Focus" },
    { key = "acceptPopup", name = "NF Accept", icon = C.ACCEPT_ICON },
}

local BAG_MACROS = { health = true, healthstone = true, healthPotion = true, mana = true, food = true,
    drink = true, bandage = true }
local POTION_STEPS = 8
local PLACEHOLDER = "#showtooltip"
local EXTRA_SUFFIX = "Extra"
local LINE_BREAK = "\\n"

local ready, pending
local warnedFull = {}
local warnedLong, warnedScript = {}, {}
local refresh = {}
local toDelete = {}
local steps = {}
local events = CreateFrame("Frame")

local function UsedByBar(key)
    return ns.ConsumableBarUsesMacro ~= nil and ns.ConsumableBarUsesMacro(key)
end

local function BarOnly()
    local db = S.DB()
    if type(db.barOnly) ~= "table" then db.barOnly = {} end
    return db.barOnly
end

local function FirstCarried(list)
    for _, id in ipairs(list) do
        if C_Item.GetItemCount(id) > 0 then return id end
    end
end

local function UseLines(first, second)
    if first and second then return "#showtooltip\n" .. first .. "\n" .. second end
    local line = first or second
    if line then return "#showtooltip\n" .. line end
end

local function ItemLine(id, prefix)
    return id and ("/use " .. (prefix or "") .. "item:" .. id)
end

local function Sequence(list)
    if #list < 2 then return UseLines(ItemLine(list[1])) end
    return "#showtooltip\n/castsequence reset=combat item:" .. table.concat(list, ", item:")
end

local function PotionSteps()
    wipe(steps)
    for _, id in ipairs(ns.HEALING_POTIONS) do
        for _ = 1, math.min(C_Item.GetItemCount(id), POTION_STEPS - #steps) do steps[#steps + 1] = id end
    end
end

local function TrinketLines(slot)
    return "#showtooltip " .. slot .. "\n/use " .. slot
end

local function FocusChannel()
    return (IsInRaid() and "/ra") or (IsInGroup() and "/p")
end

local BODIES = {
    health = function()
        PotionSteps()
        local stone = FirstCarried(ns.HEALTHSTONES)
        if stone then
            table.insert(steps, (S.Get("healthOrder") == "potion" and steps[1]) and 2 or 1, stone)
        end
        return Sequence(steps)
    end,
    healthstone = function() return UseLines(ItemLine(FirstCarried(ns.HEALTHSTONES))) end,
    healthPotion = function()
        PotionSteps()
        return Sequence(steps)
    end,
    mana = function() return UseLines(ItemLine(FirstCarried(ns.MANA_POTIONS))) end,
    food = function()
        local food, drink = ns.BestFoodAndDrink()
        if S.Get("foodOnly") then drink = nil end
        return UseLines(ItemLine(food), ItemLine(drink))
    end,
    drink = function() return UseLines(ItemLine((select(2, ns.BestFoodAndDrink())))) end,
    bandage = function() return UseLines(ItemLine(FirstCarried(Items.BANDAGES), "[@player] ")) end,
    trinket1 = function() return TrinketLines(TRINKET_TOP) end,
    trinket2 = function() return TrinketLines(TRINKET_BOTTOM) end,
    acceptPopup = function() return "/click StaticPopup1Button1" end,
    focus = function()
        local body = "/focus [@mouseover,exists,nodead][]"
        if S.Get("focusMark") then body = body .. "\n/tm [@focus] " .. S.Get("focusMarker") end
        local channel = FocusChannel()
        if S.Get("focusAnnounce") and channel then body = body .. "\n" .. channel .. " Focus: %f" end
        return body
    end,
}

local function WithExtra(m, body)
    local extra = S.Get(m.key .. EXTRA_SUFFIX)
    if not extra or extra == "" then return body end
    local lines = extra:gsub(LINE_BREAK, "\n")
    if M.Commands.RunsScript(lines) then
        if warnedScript[m.key] ~= extra then
            warnedScript[m.key] = extra
            ns.Print(TEXT_EXTRA_SCRIPT:format(m.name))
        end
        return body
    end
    local full = body .. "\n" .. lines
    if #full <= C.LIMIT then return full end
    if warnedLong[m.key] ~= extra then
        warnedLong[m.key] = extra
        ns.Print(TEXT_TOO_LONG:format(m.name, C.LIMIT))
    end
    return body
end

local function Named(key)
    for _, macro in ipairs(MACROS) do
        if macro.key == key then return macro end
    end
end

local function Body(key) return BODIES[key]() end

local function Full(m)
    local body = Body(m.key)
    if body then return WithExtra(m, body) end
end

local function IsFull(perCharacter)
    local accountCount, characterCount = GetNumMacros()
    if perCharacter then return characterCount >= Constants.MacroConsts.MAX_CHARACTER_MACROS end
    return accountCount >= Constants.MacroConsts.MAX_ACCOUNT_MACROS
end

local function WarnFull(m, perCharacter)
    local scope = perCharacter and "character" or "general"
    if warnedFull[scope] then return end
    warnedFull[scope] = true
    ns.Print((perCharacter and TEXT_FULL_CHARACTER or TEXT_FULL_GENERAL):format(m.name))
end

local function Write(m, body, perCharacter)
    local index = GetMacroIndexByName(m.name)
    if index > 0 then
        if GetMacroBody(index) ~= body then EditMacro(index, m.name, QUESTION, body) end
        return
    end
    if IsFull(perCharacter) then
        WarnFull(m, perCharacter)
        return
    end
    CreateMacro(m.name, m.icon or QUESTION, body, perCharacter or false)
end

local function Wanted()
    local any, bags = false, false
    local on = S.Get("enabled")
    for _, m in ipairs(MACROS) do
        if (on and S.Get(m.key)) or UsedByBar(m.key) then
            any = true
            if BAG_MACROS[m.key] then bags = true end
        end
    end
    return any, bags
end

local function Listen(event, on)
    if on then events:RegisterEvent(event) else events:UnregisterEvent(event) end
end

local function SyncEvents()
    local any, bags = Wanted()
    Listen("BAG_UPDATE_DELAYED", bags)
    Listen("UPDATE_MACROS", any)
    Listen("GROUP_ROSTER_UPDATE", S.Get("enabled") and S.Get("focus") and S.Get("focusAnnounce"))
end

local function Keep(m)
    toDelete[m.name] = nil
    local body = Full(m)
    if not body and BAG_MACROS[m.key] then
        local index = GetMacroIndexByName(m.name)
        local current = index > 0 and GetMacroBody(index) or ""
        if index == 0 or refresh[m.key] or not current:find("item:", 1, true) then body = WithExtra(m, PLACEHOLDER) end
    end
    refresh[m.key] = nil
    if body then Write(m, body) end
end

local function Update()
    if not ready then return end
    if InCombatLockdown() then
        pending = true
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    pending = false
    events:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local on = S.Get("enabled")
    local barOnly = BarOnly()
    for _, m in ipairs(MACROS) do
        local wanted = on and S.Get(m.key)
        if wanted or UsedByBar(m.key) then
            barOnly[m.key] = not wanted or nil
            Keep(m)
        elseif toDelete[m.name] or barOnly[m.key] then
            toDelete[m.name], barOnly[m.key] = nil, nil
            local index = GetMacroIndexByName(m.name)
            if index > 0 then DeleteMacro(index) end
        end
    end
end

local function Refresh()
    if ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
end

local function SettingChanged(key, value)
    for _, m in ipairs(MACROS) do
        if key == m.key .. EXTRA_SUFFIX or (key == "foodOnly" and m.key == "food") then refresh[m.key] = true end
    end
    if value == false then
        for _, m in ipairs(MACROS) do
            if key == "enabled" or key == m.key then toDelete[m.name] = true end
        end
    end
    SyncEvents()
    Update()
end

local function Reapply()
    SyncEvents()
    Update()
end

local function OnEvent(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        ready = true
        SyncEvents()
    elseif event == "PLAYER_REGEN_ENABLED" and not pending then
        return
    elseif event == "GROUP_ROSTER_UPDATE" and not (S.Get("focus") and S.Get("focusAnnounce")) then
        return
    end
    Update()
end

local function On() return S.Get("enabled") == true end

local function KeptCount(store)
    local n = 0
    for _, m in ipairs(MACROS) do
        if store.Get(m.key) or UsedByBar(m.key) then n = n + 1 end
    end
    return n
end

local function Headline()
    return TEXT_HEADLINE:format(KeptCount(S), #MACROS)
end

local function Detail()
    if not On() then return TEXT_OFF end
    local name, class = UnitClass("player")
    local count = #((S.Get("classMacros") or {})[class] or {})
    if count == 0 then return TEXT_NO_CLASS_MACROS:format(name) end
    return TEXT_CLASS_MACROS:format(count, count == 1 and "" or "s", name)
end

local Smart = { list = MACROS, bag = BAG_MACROS, Body = Body, Write = Write, On = On, KeptCount = KeptCount,
    Headline = Headline, Detail = Detail, UsedByBar = UsedByBar }
M.Smart = Smart

function Smart.Ready() return ready end

ns.MacroSmart = { list = MACROS, Body = Body }
ns.MacroStatus = { Headline = Headline, Detail = Detail }

function ns.PickupManagedMacro(key)
    if InCombatLockdown() then ns.Print(TEXT_IN_COMBAT) return end
    if not ready or not S.Get("enabled") then ns.Print(TEXT_ENABLE_FIRST) return end
    S.Set(key, true)
    Refresh()
    Update()
    local macro = Named(key)
    if not macro then return end
    local index = GetMacroIndexByName(macro.name)
    if index > 0 then PickupMacro(index) else ns.Print(TEXT_NO_ROOM) end
end

function ns.UpdateManagedMacros()
    SyncEvents()
    Update()
end

function ns.RemoveManagedMacro(key)
    if InCombatLockdown() then ns.Print(TEXT_REMOVE_IN_COMBAT) return end
    if UsedByBar(key) then
        ns.Print(TEXT_ON_BAR:format(Named(key).name))
        return
    end
    if not S.Get(key) then return end
    S.Set(key, false)
    Refresh()
end

events:SetScript("OnEvent", OnEvent)
events:RegisterEvent("PLAYER_ENTERING_WORLD")

hooksecurefunc(S, "Set", SettingChanged)
hooksecurefunc(ns, "Apply", Reapply)

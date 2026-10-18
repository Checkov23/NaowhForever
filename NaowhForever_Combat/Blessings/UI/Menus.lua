-- Menus.lua: the right-click menus: a class's blessing, your aura, a player's own blessing, and your plan's setter.
local ns = _G.NaowhForever

local B = ns.Blessings
local BLESSINGS, AURAS = B.BLESSINGS, B.AURAS
local Store, Learned, SpellName, ClassName, Roster = B.Store, B.Learned, B.SpellName, B.ClassName, B.Roster

local AURA_COLUMN, SALV_COLUMN = B.AURA_COLUMN, B.SALV_COLUMN
local TEXT_AURA, TEXT_DEFAULT, TEXT_NONE = ns.L("Aura"), ns.L("Default"), ns.L("None")
local TEXT_PLAYERS, TEXT_ASSIGNMENTS = ns.L("Players"), ns.L("Assignments")
local TEXT_OWN_ONE, TEXT_OWN_MANY = ns.L("1 player has their own blessing"), ns.L("%d players have their own blessing")
local TEXT_CLEAR_OWN = ns.L("Give them the class blessing")
local TEXT_SALV = ns.L("Give Salvation")

local function OwnAura()
    return Store().aura
end

local function OwnBlessings(class)
    local players, guids = Store().players, {}
    for _, member in ipairs(Roster()) do
        if member.class == class and players[member.guid] then guids[#guids + 1] = member.guid end
    end
    return guids
end

local function ClearOwn(guids)
    local players = Store().players
    for _, guid in ipairs(guids) do players[guid] = nil end
    B.BroadcastSoon()
    B.Changed()
end

local function OpenWindow()
    ns.OpenBlessingsWindow()
end

function B.SetOwn(column, key)
    local store = Store()
    if column == AURA_COLUMN then
        store.aura = key
    elseif column == SALV_COLUMN then
        store.salv = key and true or nil
    else
        store.classes[column] = key
    end
    B.BroadcastSoon()
    B.Changed()
end

function B.OpenMenu(owner, title, list, current, choose, noneText, can)
    can = can or Learned
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(title)
        for _, entry in ipairs(list) do
            if can(entry) then
                root:CreateRadio(SpellName(entry.key), function() return current() == entry.key end,
                    function() choose(entry.key) end)
            end
        end
        root:CreateRadio(noneText, function() return current() == nil end, function() choose(nil) end)
    end)
end

local function SetAura(key)
    B.SetOwn(AURA_COLUMN, key)
end

function B.AuraMenu(owner)
    B.OpenMenu(owner, TEXT_AURA, AURAS, OwnAura, SetAura, TEXT_DEFAULT)
end

local function SalvOn()
    return Store().salv == true
end

local function ToggleSalv()
    B.SetOwn(SALV_COLUMN, not SalvOn() and B.SALVATION.key or nil)
end

function B.SalvMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(SpellName(B.SALVATION.key))
        root:CreateCheckbox(TEXT_SALV, SalvOn, ToggleSalv)
        root:CreateDivider()
        root:CreateButton(TEXT_ASSIGNMENTS, OpenWindow)
    end)
end

function B.ClassMenu(owner, class, inSettings)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(ClassName(class))
        for _, entry in ipairs(BLESSINGS) do
            if Learned(entry) then
                root:CreateRadio(SpellName(entry.key), function() return Store().classes[class] == entry.key end,
                    function() B.SetOwn(class, entry.key) end)
            end
        end
        root:CreateRadio(TEXT_NONE, function() return Store().classes[class] == nil end,
            function() B.SetOwn(class, nil) end)
        local own = OwnBlessings(class)
        if #own > 0 then
            root:CreateDivider()
            root:CreateTitle(#own == 1 and TEXT_OWN_ONE or TEXT_OWN_MANY:format(#own))
            root:CreateButton(TEXT_CLEAR_OWN, function() ClearOwn(own) end)
        end
        root:CreateDivider()
        if Learned(B.SALVATION) then root:CreateCheckbox(TEXT_SALV, SalvOn, ToggleSalv) end
        if not inSettings then
            root:CreateCheckbox(TEXT_PLAYERS, function() return B.PlayerList.Showing() == class end,
                function() B.PlayerList.Toggle(class) end)
        end
        root:CreateButton(TEXT_ASSIGNMENTS, OpenWindow)
    end)
end

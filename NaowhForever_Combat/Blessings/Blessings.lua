-- Blessings.lua: the Blessings module's table (ns.Blessings), your saved plan, and what every file shares.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local OLD_ADDON = "NaowhForever_Blessings"
local OLD_COPY = C_AddOns.DoesAddOnExist(OLD_ADDON) and C_AddOns.GetAddOnEnableState(OLD_ADDON) > 0
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local VALID_CLASS = {}
for _, class in ipairs(CLASSES) do VALID_CLASS[class] = true end

local B = {
    Settings = S,
    CLASSES = CLASSES,
    PAGE = "Blessings/Settings",
    AURA_COLUMN = "AURA",
    SALV_COLUMN = "SALV",
    NOBODY = "-",
    ROUND = 0.5,
    AURA_TIP = ns.L("Left-click: cast your aura.\nRight-click: choose it."),
    FURY_TIP = ns.L("Left-click: cast it on yourself."),
    others = {},
    OLD_COPY = OLD_COPY,
}
ns.Blessings = B

function B.On()
    return S.Get("blessings") and not OLD_COPY
end

function B.IsPaladin()
    return select(2, UnitClass("player")) == "PALADIN"
end

function B.Secret(v)
    return issecretvalue and issecretvalue(v)
end

function B.MyName()
    return (UnitFullName("player"))
end

function B.ClassName(class)
    return LOCALIZED_CLASS_NAMES_MALE[class] or class
end

function B.Others()
    return B.others
end

function B.Changed() end

local function SplitSalvation(store)
    if store.salvSplit then return end
    store.salvSplit = true
    for class, key in pairs(store.classes) do
        if key == "salvation" then store.classes[class], store.salv = nil, true end
    end
    for guid, key in pairs(store.players) do
        if key == "salvation" then store.players[guid], store.salv = nil, true end
    end
end

function B.Store()
    local account = ns.AccountSettings()
    account.blessings = account.blessings or {}
    local key = UnitName("player") .. "-" .. GetRealmName()
    local store = account.blessings[key]
    if not (store and store.classes) then
        local classes = {}
        for class, blessing in pairs(store or {}) do
            if VALID_CLASS[class] and B.BY_KEY[blessing] then classes[class] = blessing end
        end
        store = { classes = classes, players = {} }
        account.blessings[key] = store
    end
    SplitSalvation(store)
    return store
end

-- ActionBars.lua: the Action Bars module's settings, the saved sets of this class, and the module table (ns.ActionBars).
local ns = _G.NaowhForever

local F = ns.FEATURES.actionBars

local S = ns.UI.ModuleSettings("actionBars", {
    enabled = F.enabled, highestRank = false, importMacros = true, importBindings = true, saveOnLogout = false,
    fillLater = false, autoImportSets = {}, autoLoad = {},
})

local OLD_ADDON = "NaowhForever_ActionBars"
local OLD_COPY = C_AddOns.DoesAddOnExist(OLD_ADDON) and C_AddOns.GetAddOnEnableState(OLD_ADDON) > 0
local GetSetting = S.Get

function S.Get(key)
    if key == "enabled" and OLD_COPY then return false end
    return GetSetting(key)
end

ns.ActionBarSettings = S

local A = { Settings = S, OLD_COPY = OLD_COPY }
ns.ActionBars = A

local function ByName(a, b) return a:lower() < b:lower() end

function A.Account(key)
    local account = ns.AccountSettings()
    account[key] = account[key] or {}
    return account[key]
end

function A.Class()
    local _, class = UnitClass("player")
    return class
end

function A.Sets()
    local all = A.Account("barSets")
    all[A.Class()] = all[A.Class()] or {}
    return all[A.Class()]
end

function A.CharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

function A.SetLast(name, saved)
    local store, key = A.Account("barSetLast"), A.CharKey()
    local last = store[key]
    if last and last.class == A.Class() and last.name == name and last.saved ~= false then saved = true end
    store[key] = { class = A.Class(), name = name, saved = saved }
end

function A.Last()
    return A.Account("barSetLast")[A.CharKey()]
end

function A.Find(name)
    local sets = A.Sets()
    if sets[name] then return name end
    local lower = name:lower()
    for key in pairs(sets) do
        if key:lower() == lower then return key end
    end
end

function A.SortedNames()
    local names = {}
    for name in pairs(A.Sets()) do names[#names + 1] = name end
    table.sort(names, ByName)
    return names
end

function A.Plural(n, one, many)
    return (n == 1 and one or many):format(n)
end

function A.Refresh()
    if ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
end

function A.On()
    return S.Get("enabled") == true
end

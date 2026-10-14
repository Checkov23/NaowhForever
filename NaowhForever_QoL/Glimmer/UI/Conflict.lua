-- Conflict.lua: the question when another addon that changes the same game settings is on as well (G.CheckOthers).
local ns = _G.NaowhForever

local G = ns.Glimmer
local C = G.C

local TEXT_ASK = ns.L("%s changes the same game settings as Glimmer, so they undo each other. Disable %s?")
local TEXT_YES = ns.L("Disable")
local TEXT_RELOAD = ns.L("%s will be off after a reload. Reload now?")
local TEXT_NO = ns.L("Keep Both")
local TEXT_AND = ns.L(" and ")

local asked = false

function G.CheckOthers()
    if asked then return end
    local found = {}
    for _, addon in ipairs(C.OTHER_ADDONS) do
        if C_AddOns.IsAddOnLoaded(addon) then found[#found + 1] = addon end
    end
    if #found == 0 then return end
    asked = true
    local titles = {}
    for i, addon in ipairs(found) do titles[i] = select(2, C_AddOns.GetAddOnInfo(addon)) or addon end
    local names = table.concat(titles, TEXT_AND)
    ns.Confirm(TEXT_ASK:format(names, names), function()
        for _, addon in ipairs(found) do C_AddOns.DisableAddOn(addon) end
        ns.ConfirmReload(TEXT_RELOAD:format(names))
    end, nil, TEXT_YES, TEXT_NO)
end

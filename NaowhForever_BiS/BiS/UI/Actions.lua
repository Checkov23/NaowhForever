-- Actions.lua: what you can do with your lists, from the window and the settings page (B.Actions).
local ns = _G.NaowhForever

local B = ns.BiS
local L = B.Lists

local NAME_MAX = B.C.NAME_MAX
local ANY_LENGTH = 0
local TEXT_NOT_SAVED = ns.L("BiS list not saved: %s.")
local TEXT_RENAME = ns.L("Rename this BiS list")
local TEXT_DELETE = ns.L("Delete the BiS list %s? Every character of your class using it moves to another list.")
local TEXT_PASTE = ns.L("Paste a Naowh BiS list")
local TEXT_COPY = ns.L("Copy this to share your list")
local TEXT_PICK_FIRST = ns.L("Pick your BiS first: the test plays with your list's first one.")
local TEXT_MENU_TITLE = ns.L("Your class's BiS lists")
local TEXT_MENU_NEW, TEXT_MENU_RENAME, TEXT_MENU_DELETE = ns.L("New List"), ns.L("Rename This List"), ns.L("Delete This List")
local TEXT_SPEC_ONLY = ns.L("%s only")

local function NamePrompt(title, text, save)
    ns.PromptText(title, text, NAME_MAX, function(name)
        local ok, err = save(name)
        if not ok then ns.Print(TEXT_NOT_SAVED:format(err)) end
    end)
end

local function ShownName()
    return (L.List().name:gsub("||", "|"))
end

local function Import(text)
    ns.ImportBisList(text)
end

local A = {}
B.Actions = A

function A.New()
    B.OpenNewList()
end

function A.Rename()
    NamePrompt(TEXT_RENAME, ShownName(), ns.RenameBisList)
end

function A.Delete()
    ns.Confirm(TEXT_DELETE:format(L.List().name), ns.DeleteBisList)
end

function A.Import()
    ns.PromptText(TEXT_PASTE, "", ANY_LENGTH, Import)
end

function A.StatWeights()
    ns.OpenStatWeightsWindow()
end

function A.Export()
    ns.ShowCopyBox(TEXT_COPY, ns.ExportBisList())
end

function A.TestAlert()
    if not B.Alerts.Test() then ns.Print(TEXT_PICK_FIRST) end
end

function A.ListMenu(owner)
    local values, order, active, shared = ns.BisListChoices()
    local spec = L.CurrentSpec()
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(TEXT_MENU_TITLE)
        for i, id in ipairs(order) do
            if i == shared + 1 then root:CreateTitle(TEXT_SPEC_ONLY:format(L.SpecShort(spec))) end
            root:CreateRadio(values[id], function() return id == active end, function() ns.SelectBisList(id) end)
        end
        root:CreateDivider()
        root:CreateButton(TEXT_MENU_NEW, A.New)
        root:CreateButton(TEXT_MENU_RENAME, A.Rename)
        root:CreateButton(TEXT_MENU_DELETE, A.Delete)
    end)
end

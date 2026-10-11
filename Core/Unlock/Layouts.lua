-- Layouts.lua: the HUD Editor's layouts: every element's spot and anchor kept under a name.
local ns = _G.NaowhForever
local H = ns.HudEditor

local placement = H.placement
local Grouped, Anchors, Marks, ReapplyAll = H.Grouped, H.Anchors, H.Marks, H.ReapplyAll
local Snapshot, Checkpoint, Restore, ShowSelection = H.Snapshot, H.Checkpoint, H.Restore, H.ShowSelection

local LAYOUT_LETTERS = 20
local TEXT_LAYOUTS = ns.L("Layouts")
local TEXT_NEW_NAME = ns.L("Name the new layout")
local TEXT_RENAME = ns.L("Rename this layout")
local TEXT_REPLACE = ns.L("Replace the layout %s with where everything is now?")
local TEXT_NAME_TAKEN = ns.L("There is already a layout named %s.")
local TEXT_DELETE = ns.L("Delete the layout %s? Everything stays where it is now.")
local TEXT_SAVE_TO, TEXT_SAVE_NEW = ns.L("Save to "), ns.L("Save as New Layout")
local TEXT_RENAME_ITEM, TEXT_DELETE_ITEM = ns.L("Rename "), ns.L("Delete ")

local function ByLower(a, b) return a:lower() < b:lower() end

local function Layouts()
    local db = ns.UnlockModeSettings.DB()
    if type(db.layouts) ~= "table" then db.layouts = {} end
    return db.layouts
end

local function CurrentLayout()
    local name = ns.UnlockModeSettings.Get("layout")
    return name and Layouts()[name] and name
end

local function SaveLayout(name)
    Layouts()[name] = Snapshot()
    ns.UnlockModeSettings.Set("layout", name)
    H.PaintLayout()
end

local function Unlocked(saved)
    local locked, snap = Marks("locked"), { spots = {}, anchors = {} }
    for label, spot in pairs(saved.spots) do
        if not locked[label] then snap.spots[label] = spot end
    end
    for label, info in pairs(saved.anchors) do
        if not locked[label] then snap.anchors[label] = info end
    end
    for label, info in pairs(Anchors()) do
        if locked[label] and type(info) == "table" then snap.anchors[label] = info end
    end
    return snap
end

local function LoadLayout(name)
    local saved = Layouts()[name]
    if InCombatLockdown() or placement.dragging or not saved then return end
    local snap = Unlocked(saved)
    Checkpoint()
    Restore(snap)
    ReapplyAll()
    if Grouped() then ShowSelection() end
    ns.UnlockModeSettings.Set("layout", name)
    H.PaintLayout()
end

local function NamePrompt(title, text, save)
    ns.PromptText(title, text, LAYOUT_LETTERS, function(name)
        name = strtrim((name:gsub("|", "")))
        if name ~= "" then save(name) end
    end)
end

local function NewLayout()
    NamePrompt(TEXT_NEW_NAME, "", function(name)
        if not Layouts()[name] then return SaveLayout(name) end
        ns.Confirm(TEXT_REPLACE:format(name), function() SaveLayout(name) end)
    end)
end

local function RenameLayout()
    local current = CurrentLayout()
    NamePrompt(TEXT_RENAME, current, function(name)
        local layouts = Layouts()
        if name == current then return end
        if layouts[name] then return ns.Print(TEXT_NAME_TAKEN:format(name)) end
        layouts[name], layouts[current] = layouts[current], nil
        ns.UnlockModeSettings.Set("layout", name)
        H.PaintLayout()
    end)
end

local function DeleteLayout()
    local current = CurrentLayout()
    ns.Confirm(TEXT_DELETE:format(current), function()
        Layouts()[current] = nil
        ns.UnlockModeSettings.Set("layout", nil)
        H.PaintLayout()
    end)
end

local function LayoutNames()
    local names = {}
    for name in pairs(Layouts()) do names[#names + 1] = name end
    table.sort(names, ByLower)
    return names
end

local function LayoutMenu(owner)
    local names = LayoutNames()
    local current = CurrentLayout()
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(TEXT_LAYOUTS)
        for _, name in ipairs(names) do
            root:CreateRadio(name, function() return name == CurrentLayout() end, LoadLayout, name)
        end
        root:CreateDivider()
        if current then root:CreateButton(TEXT_SAVE_TO .. current, function() SaveLayout(current) end) end
        root:CreateButton(TEXT_SAVE_NEW, NewLayout)
        if current then
            root:CreateButton(TEXT_RENAME_ITEM .. current, RenameLayout)
            root:CreateButton(TEXT_DELETE_ITEM .. current, DeleteLayout)
        end
    end)
end

H.CurrentLayout, H.LayoutMenu = CurrentLayout, LayoutMenu

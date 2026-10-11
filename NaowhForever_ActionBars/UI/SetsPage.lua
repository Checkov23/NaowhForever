-- SetsPage.lua: your class's saved bar sets, a row each with Import and More, drawn into the window's first view (ns.BuildActionBarsPage).
local ns = _G.NaowhForever
local UI = ns.UI

local A = ns.ActionBars

local SAVE_W, BUTTON_H, ROW_BUTTON_W, ROW_PAD, ROW_GAP = 170, 26, 80, 8, 8
local HINT_GAP, LINE_GAP = 12, 3
local SAVE_ROW_GAP = ROW_PAD * 3
local STRIPE_ALPHA = 0.025
local NAME_SIZE, SMALL_SIZE = 13, 11
local NEW_NAME_MAX = 40
local SAVED_DATE = "%d %b %Y"
local TEXT_ACTION, TEXT_ACTIONS = ns.L("%d action"), ns.L("%d actions")
local TEXT_MACRO, TEXT_MACROS = ns.L("%d macro"), ns.L("%d macros")
local TEXT_KEYBIND, TEXT_KEYBINDS = ns.L("%d keybind"), ns.L("%d keybinds")

local TEXT_SAVE = ns.L("Save Current Bars")
local TEXT_HINT = ns.L("Bars, macros and keybinds, for every %s.")
local TEXT_HEADER = ns.L("SAVED SETS")
local TEXT_EMPTY = ns.L("Nothing saved yet. Save your bars, macros and keybinds as they are now, then "
    .. "import them on a fresh character, for another spec or a dungeon set-up.")
local TEXT_SAVED = ns.L("Saved ")
local TEXT_BY = ns.L(" by ")
local TEXT_EDIT, TEXT_RENAME, TEXT_DELETE = ns.L("Edit and Save Again"), ns.L("Rename"), ns.L("Delete")
local TEXT_NEW_NAME = ns.L("New name for ")

local function NewStripe(parent)
    return ns.Solid(parent, "BACKGROUND", ns.THEME.fg, STRIPE_ALPHA)
end

local function SetMenu(key)
    MenuUtil.CreateContextMenu(UIParent, function(_, root)
        root:CreateButton(TEXT_EDIT, function() ns.OpenActionBarsBuilder(key) end)
        root:CreateButton(TEXT_RENAME, function()
            ns.PromptText(TEXT_NEW_NAME .. key, key, NEW_NAME_MAX, function(new) A.Rename(key, new) end)
        end)
        root:CreateButton(TEXT_DELETE, function() A.ConfirmDelete(key) end)
    end)
end

local function Contents(set)
    local actions, keys = 0, 0
    for _ in pairs(set.slots) do actions = actions + 1 end
    local parts = { A.Plural(actions, TEXT_ACTION, TEXT_ACTIONS) }
    if set.macros then parts[#parts + 1] = A.Plural(#set.macros, TEXT_MACRO, TEXT_MACROS) end
    if set.bindings then
        for _ in pairs(set.bindings) do keys = keys + 1 end
        parts[#parts + 1] = A.Plural(keys, TEXT_KEYBIND, TEXT_KEYBINDS)
    end
    return table.concat(parts, ", ")
end

local function Line(parent, key, size, color, under, text)
    local fs = UI.KeepFont(parent, key, size, nil, color)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", under, "BOTTOMLEFT", 0, -LINE_GAP)
    fs:SetText(text)
    return fs
end

local function SetRow(parent, y, key, set, stripe)
    local T, x = ns.THEME, UI.CONTENT_PAD
    local band = UI.Keep(parent, "barsStripe", NewStripe)
    band:ClearAllPoints()
    band:SetPoint("TOPLEFT", parent, "TOPLEFT", x - ROW_PAD, y)
    band:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(x - ROW_PAD), y)
    band:SetShown(stripe)
    local name = UI.KeepFont(parent, "barsName", NAME_SIZE, nil, T.fg)
    name:ClearAllPoints()
    name:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - ROW_PAD)
    name:SetText(key)
    local saved = Line(parent, "barsSaved", SMALL_SIZE, T.muted, name,
        TEXT_SAVED .. date(ns.L(SAVED_DATE), set.saved) .. (set.by and (TEXT_BY .. set.by) or ""))
    local has = Line(parent, "barsHas", SMALL_SIZE, T.muted, saved, Contents(set))
    local h = ROW_PAD * 2 + math.ceil(name:GetStringHeight()) + LINE_GAP + math.ceil(saved:GetStringHeight())
        + LINE_GAP + math.ceil(has:GetStringHeight())
    local more = UI.KeepButton(parent, "barsMore", "More", ROW_BUTTON_W, BUTTON_H, function() SetMenu(key) end)
    more:ClearAllPoints()
    more:SetPoint("RIGHT", parent, "TOPRIGHT", -x, y - h / 2)
    local import = UI.KeepButton(parent, "barsImport", "Import", ROW_BUTTON_W, BUTTON_H,
        function() ns.OpenActionBarsImport(key) end)
    import:ClearAllPoints()
    import:SetPoint("RIGHT", more, "LEFT", -ROW_GAP, 0)
    band:SetHeight(h)
    return h
end

function ns.BuildActionBarsPage(parent, y)
    local W = UI.Widgets
    local T, x = ns.THEME, UI.CONTENT_PAD
    local _, h
    local save = UI.KeepButton(parent, "barsSave", TEXT_SAVE, SAVE_W, BUTTON_H, function() ns.OpenActionBarsBuilder() end)
    ns.AccentBorder(save)
    save:ClearAllPoints()
    save:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - ROW_PAD)
    local hint = UI.KeepFont(parent, "barsHint", SMALL_SIZE, nil, T.muted)
    hint:ClearAllPoints()
    hint:SetPoint("LEFT", save, "RIGHT", HINT_GAP, 0)
    hint:SetText(TEXT_HINT:format(UnitClass("player")))
    y = y - BUTTON_H - SAVE_ROW_GAP
    local names = A.SortedNames()
    _, h = W:SectionHeader(parent, TEXT_HEADER, y); y = y - h
    if #names == 0 then
        _, h = W:Note(parent, TEXT_EMPTY, y)
        return y - h
    end
    local sets = A.Sets()
    for i, key in ipairs(names) do
        y = y - SetRow(parent, y, key, sets[key], i % 2 == 0)
    end
    return y
end

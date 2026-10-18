-- Assignments.lua: the Blessings window's grid, a row per paladin and a column per class and the aura.
local ns = _G.NaowhForever

local B = ns.Blessings
local T = ns.THEME

local CELL, GAP, NAME_WIDTH = 32, 6, 170
local ROW_GAP, NAME_PAD, NAME_Y, NOTE_Y = 10, 10, 9, 10
local NAME_SIZE, NOTE_SIZE = 13, 12
local DIM_ALPHA = 0.35
local ICON_CROP = B.Look.ICON_CROP
local EMPTY = 134400
local ICON_BORDER = B.Look.ICON_BORDER
local CLASS_ICON_PATH = B.Look.CLASS_ICON_PATH
local AURA_COLUMN, SALV_COLUMN = B.AURA_COLUMN, B.SALV_COLUMN
local AURA_ICON = "devotion"

local TEXT_INTRO = ns.L("Every paladin in your group running Naowh Forever, and the blessing "
    .. "they give each class. Click an icon to change it: your own row always, anyone's while "
    .. "you lead the group or are an assistant. Only what that paladin has learned is offered, "
    .. "and changes reach them straight away.")
local TEXT_LEAD_ONLY = ns.L("Only the group leader or an assistant can plan every paladin's blessings.")
local TEXT_REPLACE = ns.L("Replace every paladin's blessings and auras with an automatic plan?")
local TEXT_NO_PRESET = ns.L("No preset saved yet.")
local TEXT_LOAD = ns.L("Load the saved preset for the paladins here now?")
local TEXT_NOBODY = ns.L("Nobody in the preset is in your group.")
local TEXT_SAVED = ns.L("Blessings preset saved.")
local TEXT_NO_PALADINS = ns.L("No paladins running Naowh Forever to save a plan for.")
local TEXT_REPLACE_PRESET = ns.L("Replace the saved preset?")
local TEXT_NO_GROUP_PALADINS = ns.L("No paladins in your group.")
local TEXT_NO_ADDON = ns.L("Not running Naowh Forever")
local TEXT_YOU = ns.L("  (you)")
local TEXT_AURA = ns.L("Aura")
local TEXT_SALV = ns.L("Salvation")
local TEXT_SALV_ON = ns.L("Gives Salvation to everyone but tanks")
local TEXT_NOTHING = ns.L("Nothing assigned")
local TEXT_CHANGE = ns.L("\nClick to change.")
local TEXT_NONE = ns.L("None")

local function NewCell(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(CELL, CELL)
    btn.tex = btn:CreateTexture(nil, "ARTWORK")
    ns.PixelInset(btn.tex, 1)
    btn.tex:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    ns.Border(btn, ICON_BORDER)
    return btn
end

local function Cell(parent, x, y, icon, lit, title, body, onClick)
    local btn = ns.UI.Keep(parent, "cell", NewCell)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local tex = btn.tex
    tex:SetTexture(icon)
    tex:SetDesaturated(not lit)
    tex:SetAlpha(lit and 1 or DIM_ALPHA)
    btn:SetScript("OnClick", onClick)
    ns.Tooltip(btn, title, body)
    return btn
end

local function Allowed()
    if B.CanPlanAll() then return true end
    ns.Print(TEXT_LEAD_ONLY)
end

local function AutoAssign()
    if Allowed() then ns.Confirm(TEXT_REPLACE, B.AutoAssign) end
end

local function LoadNow()
    if not B.LoadPreset() then ns.Print(TEXT_NOBODY) end
end

local function LoadPreset()
    if not B.HasPreset() then return ns.Print(TEXT_NO_PRESET) end
    if Allowed() then ns.Confirm(TEXT_LOAD, LoadNow) end
end

local function SaveNow()
    if B.SavePreset() then
        ns.Print(TEXT_SAVED)
    else
        ns.Print(TEXT_NO_PALADINS)
    end
end

local function SavePreset()
    if not B.HasPaladins() then return ns.Print(TEXT_NO_PALADINS) end
    if B.HasPreset() then ns.Confirm(TEXT_REPLACE_PRESET, SaveNow) else SaveNow() end
end

local function Planning(parent, y)
    local W = ns.UI.Widgets
    local _, h = W:SectionHeader(parent, "PLANNING", y)
    y = y - h
    _, h = W:DualRow(parent, y,
        { type = "button", text = "Auto-Assign", buttonText = "Assign", onClick = AutoAssign },
        { type = "button", text = "Preset", buttonText = "Load", onClick = LoadPreset })
    y = y - h
    _, h = W:DualRow(parent, y,
        { type = "button", text = "Save the plan below as the preset", buttonText = "Save", onClick = SavePreset },
        { type = "label", text = "" })
    return y - h
end

local function Columns()
    local columns = {}
    for _, class in ipairs(B.CLASSES) do columns[#columns + 1] = class end
    columns[#columns + 1] = AURA_COLUMN
    columns[#columns + 1] = SALV_COLUMN
    return columns
end

local function Headers(parent, y, left, columns)
    for i, column in ipairs(columns) do
        local aura, salv = column == AURA_COLUMN, column == SALV_COLUMN
        Cell(parent, left + NAME_WIDTH + (i - 1) * (CELL + GAP), y,
            aura and B.SpellIcon(AURA_ICON) or salv and B.SpellIcon(B.SALVATION.key) or CLASS_ICON_PATH .. column,
            true, aura and TEXT_AURA or salv and TEXT_SALV or B.ClassName(column))
    end
    return y - CELL - ROW_GAP
end

local function Rows(roster)
    local lead = B.CanAssign("player")
    local rows = {}
    if B.IsPaladin() then
        local store = B.Store()
        rows[1] = { who = B.MyName(), you = true, plan = store, players = store.players, can = B.Learned,
            set = B.SetOwn }
    end
    local others = B.Others()
    local names = {}
    for who in pairs(others) do names[#names + 1] = who end
    table.sort(names)
    for _, who in ipairs(names) do
        local plan = others[who]
        rows[#rows + 1] = { who = who, plan = plan, players = plan.players,
            can = function(entry) return plan.known[entry.key] end,
            set = lead and function(column, key)
                B.SetFor(who, column, key)
                ns.UI:RefreshPage(true)
            end }
    end
    for _, member in ipairs(roster) do
        if member.class == "PALADIN" and member.guid ~= UnitGUID("player") and not others[member.who] then
            rows[#rows + 1] = { who = member.who }
        end
    end
    return rows
end

local function Own(roster, players, class)
    local out = {}
    for _, member in ipairs(roster) do
        local key = member.class == class and players and players[member.guid]
        if key then out[#out + 1] = Ambiguate(member.who, "short") .. ": " .. B.SpellName(key) end
    end
    return #out > 0 and ("\n" .. table.concat(out, "\n")) or ""
end

local function SalvCell(parent, x, y, row)
    local on = row.plan.salv == true
    local can = row.set and row.can(B.SALVATION)
    Cell(parent, x, y, B.SpellIcon(B.SALVATION.key), on, TEXT_SALV,
        (on and TEXT_SALV_ON or TEXT_NOTHING) .. (can and TEXT_CHANGE or ""),
        can and function() row.set(SALV_COLUMN, not on and B.SALVATION.key or nil) end)
end

local function PlanCell(parent, x, y, column, row, roster)
    local aura = column == AURA_COLUMN
    local key = aura and row.plan.aura or row.plan.classes[column]
    local title = aura and TEXT_AURA or B.ClassName(column)
    local onClick = row.set and function(btn)
        B.OpenMenu(btn, title, aura and B.AURAS or B.BLESSINGS,
            function() return aura and row.plan.aura or row.plan.classes[column] end,
            function(choice) row.set(column, choice) end, TEXT_NONE, row.can)
    end
    Cell(parent, x, y, key and B.SpellIcon(key) or EMPTY, key ~= nil, title,
        (key and B.SpellName(key) or TEXT_NOTHING)
            .. (aura and "" or Own(roster, row.players, column))
            .. (onClick and TEXT_CHANGE or ""), onClick)
end

local function PlanCells(parent, y, left, columns, row, roster)
    for i, column in ipairs(columns) do
        local x = left + NAME_WIDTH + (i - 1) * (CELL + GAP)
        if column == SALV_COLUMN then
            SalvCell(parent, x, y, row)
        else
            PlanCell(parent, x, y, column, row, roster)
        end
    end
end

local function Row(parent, y, left, columns, row, roster)
    local UI = ns.UI
    local label = UI.KeepFont(parent, "name", NAME_SIZE, "OUTLINE", RAID_CLASS_COLORS.PALADIN)
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", left, y - NAME_Y)
    label:SetWidth(NAME_WIDTH - NAME_PAD)
    label:SetJustifyH("LEFT")
    label:SetText(Ambiguate(row.who, "short") .. (row.you and TEXT_YOU or ""))
    if row.plan then return PlanCells(parent, y, left, columns, row, roster) end
    local note = UI.KeepFont(parent, "noAddon", NOTE_SIZE, nil, T.muted)
    note:SetPoint("TOPLEFT", parent, "TOPLEFT", left + NAME_WIDTH, y - NOTE_Y)
    note:SetText(TEXT_NO_ADDON)
end

local function PaladinCount()
    local n = 0
    for _, member in ipairs(B.Roster()) do
        if member.class == "PALADIN" then n = n + 1 end
    end
    return n
end

function ns.BuildBlessingAssignmentsPage(parent, y)
    local UI = ns.UI
    local W = UI.Widgets
    local _, h = W:Note(parent, TEXT_INTRO, y)
    y = Planning(parent, y - h)
    _, h = W:SectionHeader(parent, "ASSIGNMENTS", y)
    y = y - h
    local left = UI.CONTENT_PAD
    local columns = Columns()
    y = Headers(parent, y, left, columns)
    local roster = B.Roster()
    local rows = Rows(roster)
    if #rows == 0 then
        _, h = W:Note(parent, TEXT_NO_GROUP_PALADINS, y)
        return y - h
    end
    for _, row in ipairs(rows) do
        Row(parent, y, left, columns, row, roster)
        y = y - CELL - GAP
    end
    return y - ROW_GAP
end

function B.Headline()
    if not IsInGroup() then return B.IsPaladin() and ns.L("Just you for now") or ns.L("Not in a group") end
    local n = PaladinCount()
    if n == 0 then return ns.L("No paladins in your group") end
    return n == 1 and ns.L("1 paladin in your group") or (ns.L("%d paladins in your group")):format(n)
end

function B.Detail()
    if not B.IsPaladin() then return ns.L("The group's paladins and the blessing each gives every class.") end
    local planned, classes = 0, B.Store().classes
    for _, class in ipairs(B.CLASSES) do
        if classes[class] then planned = planned + 1 end
    end
    return ("Your blessings: %d of %d classes planned%s"):format(planned, #B.CLASSES,
        B.HasPreset() and ns.L(", preset saved") or "")
end

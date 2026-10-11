-- Dialogs.lua: new, rename, save and delete a gear set, and the icon picker they use.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local G = ns.GearSets
local St = G.Style
local NAME_MAX = G.C.NAME_MAX

local ICON_COLS, ICON_ROWS, ICON_SIZE, ICON_GAP = 10, 6, 36, 4
local GRID_LEFT, GRID_TOP, GRID_PAD = 14, 44, 40
local SLIDER_RIGHT, SLIDER_W, THUMB_H = 12, 8, 24
local WHEEL_ROWS = 3
local PANEL_ROOM = 100
local TITLE_SIZE, TITLE_Y = 14, -14
local CANCEL_W, CANCEL_H, CANCEL_Y = 96, 26, 14
local ICON_CROP, ICON_INSET, BLACK = St.ICON_CROP, St.ICON_INSET, St.BLACK
local CELL_STEP = ICON_SIZE + ICON_GAP
local DIALOG = "gearIcon"

local TEXT_NEW = ns.L("Name the new gear set")
local TEXT_PICK = ns.L("Pick an icon for ")
local TEXT_RENAME = ns.L("Rename ")
local TEXT_EXISTS = ns.L("A gear set called %s already exists.")
local TEXT_SAVE = ns.L("Save what you are wearing now into %s?")
local TEXT_DELETE = ns.L("Delete the gear set %s?")
local TEXT_CANCEL = ns.L("Cancel")

local function CellEnter(cell)
    cell.border:SetColor(T.accent.r, T.accent.g, T.accent.b, 1)
end

local function CellLeave(cell)
    cell.border:SetColor(BLACK.r, BLACK.g, BLACK.b, 1)
end

local function CellClick(cell)
    local grid = cell.grid
    local icon = grid.provider:GetIconForSaving(cell.index)
    local onPick = grid.onPick
    grid.dimmer:Hide()
    onPick(icon)
end

local function NewCell(grid, i)
    local cell = CreateFrame("Button", nil, grid)
    cell:SetSize(ICON_SIZE, ICON_SIZE)
    cell:SetPoint("TOPLEFT", GRID_LEFT + ((i - 1) % ICON_COLS) * CELL_STEP,
        -GRID_TOP - math.floor((i - 1) / ICON_COLS) * CELL_STEP)
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    ns.PixelInset(cell.icon, ICON_INSET)
    cell.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    cell.border = ns.Border(cell, BLACK)
    cell.grid = grid
    cell:SetScript("OnEnter", CellEnter)
    cell:SetScript("OnLeave", CellLeave)
    cell:SetScript("OnClick", CellClick)
    return cell
end

local function NewSlider(grid)
    local slider = CreateFrame("Slider", nil, grid)
    slider:SetOrientation("VERTICAL")
    slider:SetPoint("TOPRIGHT", -SLIDER_RIGHT, -GRID_TOP)
    slider:SetSize(SLIDER_W, ICON_ROWS * CELL_STEP - ICON_GAP)
    ns.Solid(slider, "BACKGROUND", T.bg, 1):SetAllPoints()
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(T.accent.r, T.accent.g, T.accent.b, 1)
    thumb:SetSize(SLIDER_W, THUMB_H)
    slider:SetThumbTexture(thumb)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    return slider
end

local function RefreshGrid(grid)
    local first = math.floor(grid.slider:GetValue()) * ICON_COLS
    for i, cell in ipairs(grid.cells) do
        local index = first + i
        if index <= grid.count then
            cell.index = index
            cell.icon:SetTexture(grid.provider:GetIconByIndex(index))
            cell:Show()
        else
            cell:Hide()
        end
    end
end

local function BuildIconGrid(panel)
    local grid = CreateFrame("Frame", nil, panel)
    grid:SetAllPoints()
    local slider = NewSlider(grid)
    grid.slider = slider
    grid.cells = {}
    for i = 1, ICON_COLS * ICON_ROWS do grid.cells[i] = NewCell(grid, i) end
    grid.Refresh = RefreshGrid
    slider:SetScript("OnValueChanged", function() grid:Refresh() end)
    grid:EnableMouseWheel(true)
    grid:SetScript("OnMouseWheel", function(_, delta) slider:SetValue(slider:GetValue() - delta * WHEEL_ROWS) end)
    return grid
end

local function OnDimmerShow(self)
    if not self.gearProvider then self:Hide() end
end

local function PickIcon(title, onPick)
    local UI = ns.UI
    local width = ICON_COLS * CELL_STEP + GRID_PAD
    local dimmer, panel = ns.MakeModal(width, ICON_ROWS * CELL_STEP + PANEL_ROOM, DIALOG)
    local provider = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.Equipment)
    dimmer.onClose = function()
        provider:Release()
        dimmer.gearProvider = nil
    end
    dimmer.gearProvider = provider
    if not dimmer._gearHooked then
        dimmer._gearHooked = true
        dimmer:HookScript("OnShow", OnDimmerShow)
    end

    local head = UI.KeepFont(panel, "head", TITLE_SIZE, "OUTLINE")
    head:SetPoint("TOP", 0, TITLE_Y)
    head:SetText(title)

    local grid = UI.Keep(panel, "grid", BuildIconGrid)
    grid:SetAllPoints()
    grid.provider, grid.onPick, grid.dimmer = provider, onPick, dimmer
    grid.count = provider:GetNumIcons()
    grid.slider:SetMinMaxValues(0, math.max(0, math.ceil(grid.count / ICON_COLS) - ICON_ROWS))
    grid.slider:SetValue(0)
    grid:Refresh()

    UI.KeepButton(panel, "cancel", TEXT_CANCEL, CANCEL_W, CANCEL_H, function() dimmer:Hide() end)
        :SetPoint("BOTTOM", panel, "BOTTOM", 0, CANCEL_Y)
    dimmer:Show()
end

function ns.NewGearSet()
    ns.PromptText(TEXT_NEW, "", NAME_MAX, function(name)
        if C_EquipmentSet.GetEquipmentSetID(name) then
            ns.Print(TEXT_EXISTS:format(name))
            return
        end
        PickIcon(TEXT_PICK .. name, function(icon)
            C_EquipmentSet.CreateEquipmentSet(name, icon)
        end)
    end)
end

function ns.ChangeGearSetIcon(setID, name)
    PickIcon(TEXT_PICK .. name, function(icon)
        C_EquipmentSet.ModifyEquipmentSet(setID, name, icon)
    end)
end

function ns.RenameGearSet(setID, name)
    ns.PromptText(TEXT_RENAME .. name, name, NAME_MAX, function(newName)
        if newName == name then return end
        local other = C_EquipmentSet.GetEquipmentSetID(newName)
        if other and other ~= setID then
            ns.Print(TEXT_EXISTS:format(newName))
            return
        end
        local _, icon = C_EquipmentSet.GetEquipmentSetInfo(setID)
        C_EquipmentSet.ModifyEquipmentSet(setID, newName, icon)
        for _, key in ipairs(G.SWAP_KEYS) do
            if S.Get(key) == name then S.Set(key, newName) end
        end
    end)
end

function ns.SaveGearSet(setID, name)
    ns.Confirm(TEXT_SAVE:format(name), function()
        C_EquipmentSet.SaveEquipmentSet(setID)
    end)
end

function ns.DeleteGearSet(setID, name)
    ns.Confirm(TEXT_DELETE:format(name), function()
        C_EquipmentSet.DeleteEquipmentSet(setID)
    end)
end

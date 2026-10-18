-- BuffCell.lua: a Buffs & Consumables reminder icon, the same on screen and on the card's preview.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local S = A.Settings
local St = A.Style
local Parts = ns.Shared.Parts

local GAP = St.BUFF_GAP
local CROP = St.BUFF_CROP
local COUNT_SIZE, COUNT_INSET = St.BUFF_COUNT_SIZE, St.BUFF_COUNT_INSET
local RANGE_COUNT = "%d/%d"

local Cell = {}
A.BuffCell = Cell

function Cell.New(parent, template)
    local cell = CreateFrame(template and "Button" or "Frame", nil, parent, template)
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetAllPoints()
    cell.icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
    ns.Border(cell, ns.ThemeTint("line", St.BLACK))
    cell.count = ns.Font(cell, COUNT_SIZE, "OUTLINE")
    cell.count:SetPoint("BOTTOMRIGHT", -COUNT_INSET, COUNT_INSET)
    return cell
end

function Cell.Snap(region, value)
    local pixel = ns.OnePixel(region)
    return math.floor(value / pixel + 0.5) * pixel
end

function Cell.Place(cell, parent, i, size, icon, count)
    size = Cell.Snap(parent, size)
    cell:SetSize(size, size)
    cell:ClearAllPoints()
    cell:SetPoint("LEFT", parent, "LEFT", (i - 1) * Cell.Snap(parent, size + GAP), 0)
    cell.icon:SetTexture(icon)
    Parts.HudFont(cell.count, S.Get("buffsFont"), S.Get("buffsFontSize"), S.Get("buffsOutline"))
    cell.count:SetText(count or "")
end

function Cell.Fit(parent, n, size)
    size = Cell.Snap(parent, size)
    parent:SetSize((math.max(n, 1) - 1) * Cell.Snap(parent, size + GAP) + size, size)
end

function Cell.Range(cell, inRange, missing)
    local alpha = missing and inRange == 0 and St.BUFF_RANGE_DIM or 1
    if cell.rangeAlpha ~= alpha then
        cell.icon:SetAlpha(alpha)
        cell.rangeAlpha = alpha
    end
    if missing and (cell.rangeIn ~= inRange or cell.rangeMissing ~= missing) then
        cell.count:SetFormattedText(RANGE_COUNT, inRange, missing)
    end
    cell.rangeIn, cell.rangeMissing = inRange, missing
end

-- Cell.lua: one icon of the Consumable Bar as the bar, Edit Items and the settings preview draw it.
local ns = _G.NaowhForever

local GetItemCount = C_Item.GetItemCount
local GetItemCooldown = C_Container.GetItemCooldown

local CB = ns.ConsumableBar
local S, C = CB.S, CB.C
local T = ns.THEME
local St = ns.Shared.Style
local ItemBar = ns.Shared.ItemBar
local UI = ns.UI
local Secret = CB.Secret

local NONE_COLOR = St.RED_RGB
local BG_COLOR = St.BORDER_RGB
local TIMER_LIFT = 2
local TEXT_NONE = ns.L("NONE")
local CUSTOM_POINT = "TOP"

function CB.Decorate(cell)
    cell.bg = cell:CreateTexture(nil, "BACKGROUND")
    cell.bg:SetColorTexture(BG_COLOR.r, BG_COLOR.g, BG_COLOR.b, 1)
    cell.timer = CreateFrame("Cooldown", nil, cell, "CooldownFrameTemplate")
    cell.timer:SetAllPoints()
    cell.timer:SetDrawEdge(false)
    cell.overlay = CreateFrame("Frame", nil, cell)
    cell.overlay:SetAllPoints()
    cell.overlay:SetFrameLevel(cell.timer:GetFrameLevel() + TIMER_LIFT)
    cell.count:SetParent(cell.overlay)
    cell.key:SetParent(cell.overlay)
    cell.custom = ns.Font(cell.overlay, C.CUSTOM_FONT, "OUTLINE")
    cell.none = ns.Font(cell.overlay, C.NONE_FONT, "OUTLINE", NONE_COLOR)
    cell.none:SetPoint("CENTER")
    cell.none:SetText(TEXT_NONE)
    return cell
end

function CB.NewCell(parent)
    return CB.Decorate(ItemBar.NewButton(parent))
end

function CB.CustomOn(f)
    if f.textOn ~= nil then return f.textOn end
    return (f.text or "") ~= ""
end

local function PlaceCustom(cell, entry)
    local f = CB.Flags(entry)
    if not CB.CustomOn(f) or not f.text or f.text == "" then
        cell.custom:Hide()
        return
    end
    local face = f.textFont
    if not face or face == "" then face = S.Get("consumableBarFont") end
    ItemBar.PlaceText(cell.custom, cell, f.textPoint or CUSTOM_POINT, f.textOutside, f.textX or 0, f.textY or 0,
        UI.FontPath(face), f.textSize or C.CUSTOM_FONT)
    local c = f.textColor or T.fg
    cell.custom:SetText(f.text)
    cell.custom:SetTextColor(c.r, c.g, c.b, 1)
    cell.custom:Show()
end

local function FitNone(cell, size, height)
    local path = UI.FontPath(S.Get("consumableBarFont"))
    local short = math.min(size, height)
    local guess = math.max(C.NONE_MIN, math.floor(short * C.NONE_GUESS))
    cell.none:SetFont(path, guess, "OUTLINE")
    local width = cell.none:GetStringWidth()
    if width and width > 0 then
        local fit = math.floor(guess * (size - 2 * C.TEXT_INSET) / width)
        cell.none:SetFont(path, math.max(C.NONE_MIN, math.min(fit, math.floor(short * C.NONE_MAX))), "OUTLINE")
    end
end

function CB.StyleCell(cell, entry, size, height)
    height = height or size
    ItemBar.Shape(cell, size, height)
    cell.icon:SetTexture(CB.EntryIcon(entry))
    ItemBar.StyleTexts(cell, S, CB.PREFIX)
    PlaceCustom(cell, entry)
    FitNone(cell, size, height)
end

function CB.ShowCount(cell, itemID, faded)
    local count = itemID and GetItemCount(itemID) or 0
    local hideEmpty = S.Get("consumableBarHideEmpty") and not CB.unlocked
    cell.count:SetText(count)
    cell.count:SetShown(count > 0 and S.Get("consumableBarShowCount") ~= false)
    cell.none:SetShown(count == 0 and not hideEmpty)
    cell.icon:SetDesaturated(count == 0)
    cell.empty = count == 0 and hideEmpty
    cell:SetAlpha(cell.empty and faded or 1)
end

function CB.Out(entry)
    if not S.Get("consumableBarHideEmpty") or CB.unlocked then return false end
    local itemID = CB.Resolve(entry)
    return not itemID or GetItemCount(itemID) == 0
end

function CB.ShownItems()
    local shown = {}
    for _, entry in ipairs(CB.Items()) do
        if not CB.Out(entry) then shown[#shown + 1] = entry end
    end
    return shown
end

function CB.ShowCooldown(cell, itemID)
    if not (itemID and S.Get("consumableBarCooldown")) then
        cell.timer:Hide()
        return
    end
    local start, duration, enable = GetItemCooldown(itemID)
    if Secret(start) or Secret(duration) or Secret(enable) then return end
    if enable == 1 and duration and duration > 0 then
        cell.timer:SetCooldown(start, duration)
        cell.timer:Show()
    else
        cell.timer:Hide()
    end
end

function CB.ShowKey(cell, map)
    ItemBar.ShowKey(cell, CB.KeyFor(cell, map))
end

function CB.IconSize()
    local size = S.Get("consumableBarSize")
    return size, S.Get("consumableBarRect") and S.Get("consumableBarHeight") or size
end

function CB.Grid()
    local size, height = CB.IconSize()
    return size, S.Get("consumableBarSpacing"), S.Get("consumableBarGrow"),
        math.max(1, S.Get("consumableBarPerRow") or 1), height, S.Get("consumableBarFlipRows") == true
end

local function Reach(hasNeighbour, half)
    return hasNeighbour and half or C.BG_PAD
end

function CB.PlaceBackground(cell, index, count, gap, grow, perRow, flip)
    local k = index - 1
    local along, lane = k % perRow, math.floor(k / perRow)
    local half = gap / 2
    local back, ahead = Reach(along > 0, half), Reach(along < perRow - 1 and k + 1 < count, half)
    local before, after = Reach(lane > 0, half), Reach(k + perRow < count, half)
    if flip then before, after = after, before end
    local left, right, top, bottom
    if grow == "LEFT" then left, right, top, bottom = ahead, back, before, after
    elseif grow == "UP" then left, right, top, bottom = before, after, ahead, back
    elseif grow == "DOWN" then left, right, top, bottom = before, after, back, ahead
    else left, right, top, bottom = back, ahead, before, after end
    cell.bg:ClearAllPoints()
    cell.bg:SetPoint("TOPLEFT", cell, "TOPLEFT", -left, top)
    cell.bg:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", right, -bottom)
    cell.bg:SetShown(S.Get("consumableBarBackground"))
    cell.bg:SetAlpha(S.Get("consumableBarBgAlpha"))
end

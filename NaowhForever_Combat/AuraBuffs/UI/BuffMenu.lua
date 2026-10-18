-- BuffMenu.lua: hovering a reminder lists the carried items it watches, as secure buttons to use one.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local S = A.Settings
local St = A.Style
local R, Cell = A.Buffs, A.BuffCell
local Glow = A.Glow

local COLS, PAD, GAP = St.MENU_COLS, St.MENU_PAD, St.MENU_GAP
local ICON_GAP, CROP = St.BUFF_GAP, St.BUFF_CROP
local LEAVE_DELAY = 0.15

local popup
local seen = {}

local Menu = { unlocked = false }
A.BuffMenu = Menu

function Menu.Hide()
    if popup and not InCombatLockdown() then
        popup:Hide()
        popup:ClearAllPoints()
    end
end

local function LeftMenu()
    if popup and popup:IsShown() and not popup:IsMouseOver()
        and not (popup.owner and popup.owner:IsMouseOver()) then Menu.Hide() end
end

function Menu.Leave()
    C_Timer.After(LEAVE_DELAY, LeftMenu)
end

local function OnItemEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.itemID)
    GameTooltip:Show()
end

local function OnItemLeave()
    GameTooltip:Hide()
    Menu.Leave()
end

local function OnItemUsed(self)
    Glow.Press(self, "buffGlow")
    local owner = popup.owner
    C_Timer.After(Glow.PRESS_TIME, function()
        if popup.owner == owner then Menu.Hide() end
    end)
end

local function Build()
    popup = CreateFrame("Frame", nil, UIParent)
    popup:SetFrameStrata("DIALOG")
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:SetScript("OnLeave", Menu.Leave)
    ns.Solid(popup, "BACKGROUND", ns.THEME.bg, 1):SetAllPoints()
    ns.Border(popup)
    popup.buttons = {}
end

local function Button(count)
    local button = popup.buttons[count]
    if button then return button end
    button = CreateFrame("Button", nil, popup, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type1", "item")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
    Cell.Edge(button)
    button:SetScript("PostClick", OnItemUsed)
    button:SetScript("OnEnter", OnItemEnter)
    button:SetScript("OnLeave", OnItemLeave)
    popup.buttons[count] = button
    return button
end

local function Fill(items)
    local count = 0
    wipe(seen)
    for _, id in ipairs(items) do
        if not seen[id] and C_Item.GetItemCount(id) > 0 then
            seen[id] = true
            count = count + 1
            local button = Button(count)
            button.itemID = id
            button:SetAttribute("item1", "item:" .. id)
            button.icon:SetTexture(R.ItemIcon(id))
            Cell.PaintEdge(button)
            button:Show()
        end
    end
    for i = count + 1, #popup.buttons do popup.buttons[i]:Hide() end
    return count
end

local function Lay(count, size)
    size = Cell.Snap(popup, size)
    local step, pad = Cell.Snap(popup, size + ICON_GAP), Cell.Snap(popup, PAD)
    for i = 1, count do
        local row, col = math.floor((i - 1) / COLS), (i - 1) % COLS
        local across = math.min(COLS, count - row * COLS)
        local button = popup.buttons[i]
        button:SetSize(size, size)
        button:ClearAllPoints()
        button:SetPoint("TOP", popup, "TOP", Cell.Snap(popup, (col - (across - 1) / 2) * step), -pad - row * step)
    end
    local cols, rows = math.max(1, math.min(count, COLS)), math.max(1, math.ceil(count / COLS))
    local height = (rows - 1) * step + size + pad * 2
    popup:SetSize((cols - 1) * step + size + pad * 2, height)
    return height
end

local function Anchor(cell, height)
    local below = (cell:GetBottom() or 0) * cell:GetEffectiveScale() / popup:GetEffectiveScale()
    local gap = Cell.Snap(popup, GAP)
    popup:ClearAllPoints()
    if below - gap < height then
        popup:SetPoint("BOTTOM", cell, "TOP", 0, gap)
    else
        popup:SetPoint("TOP", cell, "BOTTOM", 0, -gap)
    end
end

function Menu.Open(cell)
    if Menu.unlocked or InCombatLockdown() or C_Secrets.ShouldAurasBeSecret() or not cell.items then return end
    if not popup then Build() end
    popup.owner = cell
    local count = Fill(cell.items)
    Anchor(cell, Lay(count, S.Get("iconSize")))
    popup:SetShown(count > 0)
end

function Menu.Owner()
    return popup and popup:IsShown() and popup.owner or nil
end

function Menu.OwnedBy(cell)
    return popup ~= nil and popup.owner == cell
end

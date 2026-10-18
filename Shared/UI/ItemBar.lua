-- ItemBar.lua: an item bar (ns.Shared.ItemBar): secure item buttons in a grid with their count and key, the bar's mover, its place or anchor, and its text rows.
local ns = _G.NaowhForever
local Shared = ns.Shared
local St = Shared.Style
local T = ns.THEME

local ICON_INSET = 1
local ICON_CROP = St.ICON_CROP
local COUNT_SIZE, KEY_SIZE = 12, 10
local TEXT_INSET = 2
local OUTLINE_GAP = 2
local OUTLINE_LEVEL = 30
local SCREEN = "UIParent"
local TEXT_RANGE = { 6, 32, 1 }
local COUNT_RANGE = { 8, 32, 1 }
local OFFSET_RANGE = { -50, 50, 1 }
local ITEM_LINK = "item:"
local LABEL_COUNT, LABEL_KEYS = "Show Count", "Show Keybinds"

local OUTSIDE = {
    TOPLEFT = "BOTTOMLEFT", TOP = "BOTTOM", TOPRIGHT = "BOTTOMRIGHT",
    LEFT = "RIGHT", CENTER = "CENTER", RIGHT = "LEFT",
    BOTTOMLEFT = "TOPLEFT", BOTTOM = "TOP", BOTTOMRIGHT = "TOPRIGHT",
}
local POINT_VALUES = { TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right", LEFT = "Left",
    CENTER = "Center", RIGHT = "Right", BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom",
    BOTTOMRIGHT = "Bottom Right" }
local POINT_ORDER = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT",
    "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local POINT = { POINT_VALUES, POINT_ORDER }
local GROW_OF = { horizontal = "RIGHT", row = "RIGHT", vertical = "DOWN", stacked = "DOWN" }
local GROW_NAMES = { RIGHT = "Right", LEFT = "Left", UP = "Up", DOWN = "Down" }
local CORNER = { RIGHT = "TOPLEFT", LEFT = "TOPRIGHT", UP = "BOTTOMLEFT", DOWN = "TOPLEFT" }
local FLIPPED_CORNER = { RIGHT = "BOTTOMLEFT", LEFT = "BOTTOMRIGHT", UP = "BOTTOMRIGHT", DOWN = "TOPRIGHT" }
local HALF = 0.5

local ItemBar = {}
Shared.ItemBar = ItemBar
ItemBar.POINT_VALUES, ItemBar.POINT_ORDER = POINT_VALUES, POINT_ORDER
ItemBar.TEXT_INSET = TEXT_INSET
ItemBar.ONE_LINE = 1000

function ItemBar.GrowOf(value)
    return GROW_OF[value] or value
end

function ItemBar.Vertical(grow)
    return grow == "UP" or grow == "DOWN"
end

function ItemBar.GrowChoice(right, down)
    right, down = right or "RIGHT", down or "DOWN"
    return { { [right] = GROW_NAMES.RIGHT, LEFT = GROW_NAMES.LEFT, UP = GROW_NAMES.UP, [down] = GROW_NAMES.DOWN },
        { right, "LEFT", "UP", down } }
end

function ItemBar.CropIcon(texture, crop, width, height)
    crop = crop or ICON_CROP
    if not (width and height and width > 0 and height > 0) or width == height then
        texture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
        return
    end
    local spanX, spanY = 1 - 2 * crop, 1 - 2 * crop
    if width > height then spanY = spanY * height / width else spanX = spanX * width / height end
    texture:SetTexCoord(HALF - spanX * HALF, HALF + spanX * HALF, HALF - spanY * HALF, HALF + spanY * HALF)
end

function ItemBar.NewButton(parent, template, name)
    local button = CreateFrame("Button", name, parent, template)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    ns.PixelInset(button.icon, ICON_INSET)
    ItemBar.CropIcon(button.icon)
    button.count = ns.Font(button, COUNT_SIZE, "OUTLINE")
    button.count:SetPoint("BOTTOMRIGHT", -TEXT_INSET, TEXT_INSET)
    button.key = ns.Font(button, KEY_SIZE, "OUTLINE")
    button.key:Hide()
    ns.Border(button, St.BORDER_RGB)
    return button
end

local function TipEnter(button)
    if button.tipOff and button.tipOff(button) then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if button.itemID then
        GameTooltip:SetItemByID(button.itemID)
    else
        GameTooltip:SetText(ns.L(button.emptyTip) or "")
    end
    GameTooltip:Show()
end

local function TipLeave()
    GameTooltip:Hide()
end

function ItemBar.SecureButton(parent, name)
    local button = ItemBar.NewButton(parent, "SecureActionButtonTemplate", name)
    button:RegisterForClicks("AnyUp", "AnyDown")
    Shared.Parts.Press(button)
    button:SetScript("OnEnter", TipEnter)
    button:SetScript("OnLeave", TipLeave)
    return button
end

function ItemBar.SetItem(button, itemID)
    if itemID == button.itemID then return end
    button.itemID = itemID
    button:SetAttribute("type1", itemID and "item" or nil)
    button:SetAttribute("item1", itemID and (ITEM_LINK .. itemID) or nil)
end

function ItemBar.Shape(button, width, height)
    button:SetSize(width, height)
    ItemBar.CropIcon(button.icon, nil, width - 2 * ICON_INSET, height - 2 * ICON_INSET)
end

function ItemBar.Fill(button, texture, count, empty)
    button.icon:SetTexture(texture)
    button.icon:SetDesaturated(empty and true or false)
    button.count:SetText(count or "")
end

local function Steps(size, gap, grow, height)
    height = height or size
    if ItemBar.Vertical(grow) then return height + gap, size + gap end
    return size + gap, height + gap
end

function ItemBar.Corner(grow, flip)
    return (flip and FLIPPED_CORNER or CORNER)[grow] or CORNER.RIGHT
end

function ItemBar.Place(button, parent, index, size, gap, grow, perRow, height, flip)
    local alongStep, acrossStep = Steps(size, gap, grow, height)
    local along = (index - 1) % perRow * alongStep
    local across = math.floor((index - 1) / perRow) * acrossStep
    if flip then across = -across end
    local x, y
    if grow == "LEFT" then x, y = -along, -across
    elseif grow == "UP" then x, y = across, along
    elseif grow == "DOWN" then x, y = across, -along
    else x, y = along, -across end
    local corner = ItemBar.Corner(grow, flip)
    button:ClearAllPoints()
    button:SetPoint(corner, parent, corner, x, y)
end

function ItemBar.Size(count, size, gap, grow, perRow, height)
    count = math.max(count, 1)
    local alongStep, acrossStep = Steps(size, gap, grow, height)
    local long = math.min(count, perRow) * alongStep - gap
    local short = math.ceil(count / perRow) * acrossStep - gap
    if ItemBar.Vertical(grow) then return short, long end
    return long, short
end

function ItemBar.Frame(name, label, onMoved, page, card)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame.mover = ns.UI.AttachMover(frame, label, onMoved, page, card)
    return frame
end

function ItemBar.Outline(frame, reach)
    local edge = reach + OUTLINE_GAP
    frame.outline = CreateFrame("Frame", nil, frame)
    frame.outline:SetPoint("TOPLEFT", -edge, edge)
    frame.outline:SetPoint("BOTTOMRIGHT", edge, -edge)
    frame.outline:SetFrameLevel(frame:GetFrameLevel() + OUTLINE_LEVEL)
    ns.Border(frame.outline, T.accent)
    frame.outline:Hide()
end

function ItemBar.Anchorable(target, name, bar)
    if type(target) ~= "table" or not target.GetObjectType then return false end
    local node = target
    while node do
        if node == bar then return false end
        node = node.GetParent and node:GetParent()
    end
    return target.IsProtected ~= nil and target:IsProtected() and target:GetAttribute("unit") ~= nil
end

function ItemBar.Anchored(S, prefix)
    return S.Get(prefix .. "Anchor") ~= SCREEN
end

function ItemBar.Put(frame, S, prefix, homeY)
    local name = S.Get(prefix .. "Anchor")
    local anchor = name ~= SCREEN and _G[name]
    frame:ClearAllPoints()
    if anchor and ItemBar.Anchorable(anchor, name, frame) then
        local ok = pcall(frame.SetPoint, frame, S.Get(prefix .. "AnchorPoint"), anchor,
            S.Get(prefix .. "AnchorRelPoint"), S.Get(prefix .. "X"), S.Get(prefix .. "Y"))
        if ok then return end
        frame:ClearAllPoints()
    end
    local pos = S.Get(prefix .. "Pos")
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, homeY)
    end
end

function ItemBar.PlaceText(fs, cell, point, outside, x, y, path, size)
    if not OUTSIDE[point] then point = "BOTTOMRIGHT" end
    fs:ClearAllPoints()
    if outside then
        fs:SetPoint(OUTSIDE[point], cell, point, x, y)
    else
        local dx = point:find("LEFT") and TEXT_INSET or point:find("RIGHT") and -TEXT_INSET or 0
        local dy = point:find("TOP") and -TEXT_INSET or point:find("BOTTOM") and TEXT_INSET or 0
        fs:SetPoint(point, cell, point, x + dx, y + dy)
    end
    fs:SetJustifyH(point:find("LEFT") and "LEFT" or point:find("RIGHT") and "RIGHT" or "CENTER")
    fs:SetFont(path, size, "OUTLINE")
end

function ItemBar.StyleTexts(button, S, prefix)
    local FontPath = ns.UI.FontPath
    ItemBar.PlaceText(button.count, button, S.Get(prefix .. "TextPoint"), S.Get(prefix .. "TextOutside"),
        S.Get(prefix .. "TextX"), S.Get(prefix .. "TextY"), FontPath(S.Get(prefix .. "Font")),
        S.Get(prefix .. "FontSize"))
    local c = S.Get(prefix .. "TextColor")
    button.count:SetTextColor(c.r, c.g, c.b, 1)
    ItemBar.PlaceText(button.key, button, S.Get(prefix .. "KeyPoint"), S.Get(prefix .. "KeyOutside"),
        S.Get(prefix .. "KeyX"), S.Get(prefix .. "KeyY"), FontPath(S.Get(prefix .. "KeyFont")), S.Get(prefix .. "KeySize"))
    c = S.Get(prefix .. "KeyColor")
    button.key:SetTextColor(c.r, c.g, c.b, 1)
end

function ItemBar.ShowKey(button, key)
    button.key:SetText(key or "")
    button.key:SetShown(key ~= nil)
end

function ItemBar.TextRows(S, prefix)
    return {
        { key = prefix .. "ShowCount", label = LABEL_COUNT, toggle = true,
          cog = { title = "Count Text", tip = "Font, size, color and position of the count." },
          help = "Shows how many of each you carry." },
        { key = prefix .. "Font", label = "Count Font", font = true, under = LABEL_COUNT },
        { key = prefix .. "FontSize", label = "Count Size", slider = COUNT_RANGE, under = LABEL_COUNT },
        { key = prefix .. "TextColor", label = "Count Color", colour = true, under = LABEL_COUNT },
        { key = prefix .. "TextPoint", label = "Count Position", choice = POINT, under = LABEL_COUNT },
        { key = prefix .. "TextOutside", label = "Count Outside the Icon", toggle = true, under = LABEL_COUNT,
          help = "Puts the count just past the icon's edge." },
        { key = prefix .. "TextX", label = "Count X Offset", slider = OFFSET_RANGE, under = LABEL_COUNT },
        { key = prefix .. "TextY", label = "Count Y Offset", slider = OFFSET_RANGE, under = LABEL_COUNT },
        { key = prefix .. "Keybinds", label = LABEL_KEYS, toggle = true,
          cog = { title = "Keybind Text", tip = "Font, size, color and position of the key." },
          help = "Shows the key that uses each button." },
        { key = prefix .. "KeyFont", label = "Keybind Font", font = true, under = LABEL_KEYS },
        { key = prefix .. "KeySize", label = "Keybind Size", slider = TEXT_RANGE, under = LABEL_KEYS },
        { key = prefix .. "KeyColor", label = "Keybind Color", colour = true, under = LABEL_KEYS },
        { key = prefix .. "KeyPoint", label = "Keybind Position", choice = POINT, under = LABEL_KEYS },
        { key = prefix .. "KeyOutside", label = "Keybind Outside the Icon", toggle = true, under = LABEL_KEYS,
          help = "Puts the key just past the icon's edge." },
        { key = prefix .. "KeyX", label = "Keybind X Offset", slider = OFFSET_RANGE, under = LABEL_KEYS },
        { key = prefix .. "KeyY", label = "Keybind Y Offset", slider = OFFSET_RANGE, under = LABEL_KEYS },
    }
end

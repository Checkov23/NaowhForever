-- Parts.lua: the Action Bars window's small parts: labels, chips, tick boxes, slot tiles, a bar's row and its panes (ns.ActionBars.Parts).
local ns = _G.NaowhForever
local T = ns.THEME
local UI = ns.UI

local A = ns.ActionBars
local St = A.Style
local Parts = ns.Shared.Parts

local BLACK = St.BORDER_RGB
local SLOTS_PER_BAR = A.C.SLOTS_PER_BAR
local ROW_PAD, ROW_FILL, ICON_CROP = St.ROW_PAD, St.ROW_FILL, St.ICON_CROP
local CHIP_H, CHIP_PAD = St.CHIP_H, 8
local BOX, TICK, LOCKED_ALPHA = 18, 12, 0.5
local TILE, TILE_GAP, KEY_INSET, BADGE_RISE, BADGE_LEVEL = 42, 5, 2, 1, 3
local ROW_HEAD, TILES_DROP, BOX_RISE, COUNT_DROP = 20, 4, 1, 2
local SCROLL_GAP = 6
local INNER = St.INNER

local P = {}
A.Parts = P

local function TileEnter(tile)
    if not tile.tip then return end
    if not Parts.Tip(tile, "ANCHOR_TOP") then return end
    tile.tip(GameTooltip)
    GameTooltip:Show()
end

local function Clicked(frame)
    if frame.onClick then frame.onClick() end
end

local function ContentSized(scroll, w)
    scroll.content:SetWidth(w)
end

P.Clicked = Clicked

function P.Label(parent, size, color)
    local fs = ns.Font(parent, size, nil, color)
    fs:SetJustifyH("LEFT")
    return fs
end

function P.Chip(parent)
    local chip = CreateFrame("Frame", nil, parent)
    chip:SetHeight(CHIP_H)
    chip.fill = ns.Solid(chip, "BACKGROUND", St.NEW_RGB, 1)
    chip.fill:SetAllPoints()
    ns.Border(chip, BLACK)
    chip.text = ns.Font(chip, St.TINY_SIZE, nil, T.fg)
    chip.text:SetPoint("CENTER", 0, 0)
    return chip
end

function P.PaintChip(chip, text, color)
    chip.text:SetText(text)
    chip.fill:SetColorTexture(color.r, color.g, color.b, 1)
    chip:SetWidth(math.ceil(chip.text:GetStringWidth()) + CHIP_PAD)
    chip:Show()
end

function P.Box(parent)
    local box = CreateFrame("Button", nil, parent)
    box:SetSize(BOX, BOX)
    box.fill = ns.Solid(box, "BACKGROUND", T.bg, 1)
    box.fill:SetAllPoints()
    ns.Border(box, BLACK)
    box.tick = box:CreateTexture(nil, "ARTWORK")
    box.tick:SetTexture(St.TICK)
    box.tick:SetSize(TICK, TICK)
    box.tick:SetPoint("CENTER")
    box:SetScript("OnClick", Clicked)
    return box
end

function P.PaintBox(box, on, locked)
    local c = on and T.accent or T.bg
    box.fill:SetColorTexture(c.r, c.g, c.b, locked and LOCKED_ALPHA or 1)
    box.tick:SetShown(on)
end

function P.Switch(parent, get, set)
    return UI.BuildToggleControl(parent, nil, get, set, St.SWITCH_W, St.SWITCH_H)
end

function P.Hint(owner, title, line)
    if not Parts.Tip(owner, "ANCHOR_TOP") then return end
    GameTooltip:SetText(title, 1, 1, 1)
    if line then GameTooltip:AddLine(line, T.muted.r, T.muted.g, T.muted.b, true) end
    GameTooltip:Show()
end

function P.NewTile(parent)
    local tile = CreateFrame("Button", nil, parent)
    tile:SetSize(TILE, TILE)
    tile.back = ns.Solid(tile, "BACKGROUND", T.bg, 1)
    tile.back:SetAllPoints()
    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetPoint("TOPLEFT", 1, -1)
    tile.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    tile.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    tile.edge = ns.Border(tile, BLACK)
    tile.key = ns.Font(tile, St.TINY_SIZE, "OUTLINE", T.fg)
    tile.key:SetPoint("TOPRIGHT", -KEY_INSET, -KEY_INSET)
    tile.badge = P.Chip(tile)
    tile.badge:SetPoint("CENTER", tile, "BOTTOM", 0, BADGE_RISE)
    tile.badge:SetFrameLevel(tile:GetFrameLevel() + BADGE_LEVEL)
    tile:SetScript("OnEnter", TileEnter)
    tile:SetScript("OnLeave", GameTooltip_Hide)
    tile:SetScript("OnClick", Clicked)
    return tile
end

function P.PaintTile(tile, look)
    tile.icon:SetTexture(look.texture)
    tile.icon:SetShown(look.texture ~= nil)
    tile.icon:SetDesaturated(look.grey or false)
    tile.icon:SetAlpha(look.alpha or 1)
    local edge = look.edge or BLACK
    tile.edge:SetColor(edge.r, edge.g, edge.b, 1)
    tile.key:SetText(look.key or "")
    if look.badge then P.PaintChip(tile.badge, look.badge, look.badgeColor) else tile.badge:Hide() end
    tile.tip, tile.onClick = look.tip, look.onClick
end

function P.NewBarRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_PAD * 2 + ROW_HEAD + TILE)
    ns.Solid(row, "BACKGROUND", T.bg, ROW_FILL):SetAllPoints()
    ns.Border(row, BLACK)
    row.box = P.Box(row)
    row.box:SetPoint("TOPLEFT", ROW_PAD, -ROW_PAD + BOX_RISE)
    row.name = P.Label(row, St.NAME_SIZE, T.fg)
    row.count = ns.Font(row, St.SMALL_SIZE, nil, T.muted)
    row.count:SetPoint("TOPRIGHT", -ROW_PAD, -ROW_PAD - COUNT_DROP)
    row.tiles = {}
    for i = 1, SLOTS_PER_BAR do
        local tile = P.NewTile(row)
        tile:SetPoint("TOPLEFT", ROW_PAD + (i - 1) * (TILE + TILE_GAP), -(ROW_PAD + ROW_HEAD + TILES_DROP))
        row.tiles[i] = tile
    end
    return row
end

function P.KeyText(command)
    local key = command and GetBindingKey(command)
    return key and ns.Shared.ActionKeys.Text(key) or ""
end

function P.BarSlots(bar)
    local first = (bar.page - 1) * SLOTS_PER_BAR
    local list = {}
    for i = 1, SLOTS_PER_BAR do list[i] = first + i end
    return list
end

function P.List(pane, top, bottom)
    local scroll = UI.SlimScroll(pane)
    scroll:SetPoint("TOPLEFT", 0, -top)
    scroll:SetPoint("BOTTOMRIGHT", -(SCROLL_GAP * 2), bottom or 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll.content = content
    scroll:SetScript("OnSizeChanged", ContentSized)
    return scroll, content
end

function P.Pane(window, left, top, right, bottom)
    local pane = CreateFrame("Frame", nil, window)
    pane:SetPoint("TOPLEFT", left + INNER, -(top + INNER))
    pane:SetPoint("BOTTOMRIGHT", -(right + INNER), bottom + INNER)
    return pane
end

function P.Heading(pane, text, hint)
    local title = P.Label(pane, St.NOTE_SIZE, T.fg)
    title:SetPoint("TOPLEFT")
    title:SetText(text)
    if not hint then return title end
    local line = ns.Font(pane, St.SMALL_SIZE, nil, T.muted)
    line:SetPoint("TOPRIGHT")
    line:SetText(hint)
    return title, line
end

function P.Divider(pane, y)
    local line = ns.Solid(pane, "ARTWORK", BLACK, 1)
    line:SetPoint("TOPLEFT", 0, y)
    line:SetPoint("TOPRIGHT", 0, y)
    ns.Hairline(line, "h")
    return line
end

function P.Cards(window, list, left, top, right, bottom)
    for _, part in ipairs(window.backdrop:Card(left, top, right, bottom)) do list[#list + 1] = part end
end

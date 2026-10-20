-- Parts.lua: the Action Bars window's parts: labels, chips, tick boxes, slot tiles, glass panels, the bar strip at any size (the scene's and a set row's), the scene, and its panes (ns.ActionBars.Parts).
local ns = _G.NaowhForever
local T = ns.THEME
local UI = ns.UI

local A = ns.ActionBars
local St = A.Style
local Parts = ns.Shared.Parts

local BLACK, PICK, WHITE = St.BORDER_RGB, St.PICK_RGB, St.WHITE_RGB
local GOLD, GOLD_SOFT, FAINT, INK = St.GOLD_RGB, St.GOLD_SOFT_RGB, St.FAINT_RGB, St.INK_RGB
local SLOTS_PER_BAR = A.C.SLOTS_PER_BAR
local ICON_CROP, MONO_FONT, MONO_SIZE = St.ICON_CROP, St.MONO_FONT, St.MONO_SIZE
local TILE, PET_TILE, PET_GAP, INSET = St.TILE, St.PET_TILE, St.PET_GAP, St.STRIP_INSET
local MINI_TILE, MINI_GAP, MINI_INSET = St.MINI_TILE, St.MINI_GAP, St.MINI_INSET
local PICKER_W, GLASS_PAD = St.PICKER_W, St.GLASS_PAD
local CHIP_H, CHIP_PAD = St.CHIP_H, 8
local BOX, TICK, LOCKED_ALPHA = 18, 12, 0.5
local KEY_INSET, BADGE_RISE, BADGE_LEVEL, MARK, MARK_INSET = 2, 1, 3, 10, 2
local SCROLL_GAP = 6
local INNER = St.INNER
local HALF, SIDE_COLUMNS, ROWS, SIDE_MIDDLE = 6, 6, 2, 3
local COLUMNS = SIDE_COLUMNS * 2 + SLOTS_PER_BAR
local SCENE_PAD, LABEL_H, LABEL_GAP, LABEL_PAD = 10, 16, 4, 4
local PET_LABEL_GAP, PET_AFTER = 3, 8
local PET_ROW_H = PET_TILE + INSET * 2
local PET_BLOCK = LABEL_H + PET_LABEL_GAP + PET_ROW_H + PET_AFTER
local GRID_H = ROWS * TILE + INSET * 2
local MAIN_W = COLUMNS * TILE + INSET * 2
local DOCK_GAP, DOCK_H, CAPTION_GAP, CAPTION_H = 6, 24, 6, 12
local DOCK_Y = LABEL_H + LABEL_GAP + GRID_H + LABEL_GAP + LABEL_H + DOCK_GAP
local SCENE_H = SCENE_PAD + DOCK_Y + DOCK_H + CAPTION_GAP + CAPTION_H + SCENE_PAD
local FORM_CHIP_H, FORM_CHIP_PAD, FORM_CHIP_GAP = 20, 10, 6
local OUTLINE_OUT, OUTLINE_PIXELS, OUTLINE_LEVEL = 2, 2, 6
local GLASS_TITLE_GAP = 2
local MAX_CHIPS = 6
local TEXT_LEFT_OUT = ns.L("LEFT OUT")
local DOT = St.PLACE_DOT

local NO_FORMS = {}
local REGIONS = { "left", "top", "bottom", "right" }
local FIRST_COLUMN = { left = 1, top = SIDE_COLUMNS + 1, bottom = SIDE_COLUMNS + 1, right = SIDE_COLUMNS + SLOTS_PER_BAR + 1 }

local P = {}
A.Parts = P
P.MAIN_PAGE, P.LEFT_PAGE, P.TOP_PAGE, P.RIGHT_PAGE, P.MAIN_VIEW = 1, 5, 6, 3, 0
P.STRIP_PAGES = { P.MAIN_PAGE, P.LEFT_PAGE, P.TOP_PAGE, P.RIGHT_PAGE }
P.REGION_PAGES = { left = P.LEFT_PAGE, top = P.TOP_PAGE, bottom = P.MAIN_PAGE, right = P.RIGHT_PAGE }
P.SCENE_H, P.PET_SCENE_H = SCENE_H, SCENE_H + PET_BLOCK

local function TileEnter(tile)
    if tile.scene then P.ShowOutline(tile.scene, tile.region) end
    if not tile.tip then return end
    if not Parts.Tip(tile, "ANCHOR_TOP") then return end
    tile.tip(GameTooltip, tile)
    GameTooltip:Show()
end

local function TileLeave(tile)
    if tile.scene then tile.scene.outline:Hide() end
    GameTooltip_Hide()
end

local function Clicked(frame)
    if frame.onClick then frame.onClick(frame) end
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

function P.Mono(parent, size, color, flags)
    local fs = ns.Font(parent, size or MONO_SIZE, flags, color)
    fs:SetFont(MONO_FONT, size or MONO_SIZE, flags or "")
    return fs
end

function P.Gradient(frame, top, bottom, topAlpha, bottomAlpha, layer)
    local fill = frame:CreateTexture(nil, layer or "BACKGROUND")
    fill:SetTexture(St.WHITE)
    fill:SetAllPoints()
    fill:SetGradient("VERTICAL", CreateColor(bottom.r, bottom.g, bottom.b, bottomAlpha),
        CreateColor(top.r, top.g, top.b, topAlpha))
    return fill
end

function P.Glass(frame)
    P.Gradient(frame, St.GLASS_TOP_RGB, St.GLASS_BOTTOM_RGB, St.GLASS_TOP_ALPHA, St.GLASS_BOTTOM_ALPHA)
    ns.Border(frame, WHITE, St.GLASS_EDGE_ALPHA)
    return frame
end

function P.GlassPanel(parent, title, room)
    local panel = P.Glass(CreateFrame("Frame", nil, parent))
    panel.title = P.Label(panel, St.PANEL_TITLE_SIZE, T.fg)
    panel.title:SetPoint("TOPLEFT", GLASS_PAD, -GLASS_PAD)
    panel.title:SetPoint("TOPRIGHT", -(GLASS_PAD + (room or 0)), -GLASS_PAD)
    panel.title:SetText(title or "")
    panel.line = P.Label(panel, St.SMALL_SIZE, T.muted)
    panel.line:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -GLASS_TITLE_GAP)
    panel.line:SetPoint("TOPRIGHT", panel.title, "BOTTOMRIGHT", 0, -GLASS_TITLE_GAP)
    return panel
end

function P.PanelSwitch(panel, get, set)
    local switch = P.Switch(panel, get, set)
    switch:SetPoint("TOPRIGHT", -GLASS_PAD, -GLASS_PAD)
    panel.title:SetPoint("TOPRIGHT", -(GLASS_PAD * 2 + St.SWITCH_W), -GLASS_PAD)
    return switch
end

function P.Primary(button)
    return ns.PrimaryButton(button, St.ON_ACCENT_RGB)
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
    box.tick:SetVertexColor(T.bg.r, T.bg.g, T.bg.b)
    box:SetScript("OnClick", Clicked)
    return box
end

function P.PaintBox(box, on, locked)
    local c = on and PICK or T.bg
    box.fill:SetColorTexture(c.r, c.g, c.b, locked and LOCKED_ALPHA or 1)
    box.tick:SetShown(on)
end

function P.Switch(parent, get, set)
    return UI.BuildToggleControl(parent, nil, get, set, St.SWITCH_W, St.SWITCH_H, nil, St.GREEN_RGB)
end

function P.Hint(owner, title, line)
    if not Parts.Tip(owner, "ANCHOR_TOP") then return end
    GameTooltip:SetText(title, 1, 1, 1)
    if line then GameTooltip:AddLine(line, T.muted.r, T.muted.g, T.muted.b, true) end
    GameTooltip:Show()
end

function P.EntryTexture(entry)
    if not entry then return nil end
    if entry.kind == "spell" then return C_Spell.GetSpellTexture(entry.id) end
    if entry.kind == "macro" then return entry.icon end
    if entry.kind == "item" then return C_Item.GetItemIconByID(entry.id) end
    return A.C.QUESTION
end

function P.NewTile(parent, size)
    local tile = CreateFrame("Button", nil, parent)
    tile:SetSize(size or TILE, size or TILE)
    tile.back = P.Gradient(tile, St.SLOT_TOP_RGB, St.SLOT_BOTTOM_RGB, St.SLOT_ALPHA, St.SLOT_ALPHA)
    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetPoint("TOPLEFT", 1, -1)
    tile.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    tile.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    tile.edge = ns.Border(tile, BLACK)
    tile.key = ns.Font(tile, St.TAG_SIZE, "OUTLINE", T.fg)
    tile.key:SetPoint("TOPRIGHT", -KEY_INSET, -KEY_INSET)
    tile.mark = tile:CreateTexture(nil, "OVERLAY")
    tile.mark:SetTexture(St.CROSS)
    tile.mark:SetSize(MARK, MARK)
    tile.mark:SetPoint("BOTTOMLEFT", MARK_INSET, MARK_INSET)
    tile.badge = P.Chip(tile)
    tile.badge:SetPoint("CENTER", tile, "BOTTOM", 0, BADGE_RISE)
    tile.badge:SetFrameLevel(tile:GetFrameLevel() + BADGE_LEVEL)
    tile:SetScript("OnEnter", TileEnter)
    tile:SetScript("OnLeave", TileLeave)
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
    tile.mark:SetShown(look.mark or false)
    if look.badge then P.PaintChip(tile.badge, look.badge, look.badgeColor) else tile.badge:Hide() end
    tile.tip, tile.onClick = look.tip, look.onClick
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

function P.Pages()
    local pages, pet = {}, {}
    for _, bar in ipairs(A.BARS) do
        local entry = { bar = bar, list = P.BarSlots(bar), commands = {} }
        for i = 1, SLOTS_PER_BAR do entry.commands[i] = bar.button .. i end
        pages[bar.page] = entry
    end
    for i = 1, A.PET_BAR.buttons do pet[i] = A.PET_BAR.button .. i end
    return pages, pet
end

function P.FormPages(pages)
    local forms = A.FORMS[A.Class()]
    if not forms then return nil end
    local list = { P.MAIN_PAGE }
    for _, form in ipairs(forms) do
        if pages[form.page] then
            pages[form.page].form = ns.L(form.name)
            list[#list + 1] = form.page
        end
    end
    return list
end

function P.IsOther(page, forms)
    for _, shown in ipairs(P.STRIP_PAGES) do if shown == page then return false end end
    for _, form in ipairs(forms or NO_FORMS) do if form == page then return false end end
    return true
end

local function Cell(region, i, single)
    if single then return i, 1 end
    if region == "top" then return FIRST_COLUMN.top + i - 1, 1 end
    if region == "bottom" then return FIRST_COLUMN.bottom + i - 1, ROWS end
    local row = i <= HALF and 1 or ROWS
    return FIRST_COLUMN[region] + (i - 1) % HALF, row
end

function P.PlaceStrip(grid, cells, size, gap, inset, single)
    local columns, rows = single and SLOTS_PER_BAR or COLUMNS, single and 1 or ROWS
    grid:SetSize(columns * size + (columns - 1) * gap + inset * 2, rows * size + (rows - 1) * gap + inset * 2)
    for _, region in ipairs(REGIONS) do
        for i, cell in ipairs(cells[region]) do
            local column, row = Cell(region, i, single)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", grid, "TOPLEFT", inset + (column - 1) * (size + gap), -(inset + (row - 1) * (size + gap)))
        end
    end
end

function P.NewMiniStrip(parent)
    local strip = CreateFrame("Frame", nil, parent)
    ns.Solid(strip, "BACKGROUND", BLACK, St.STRIP_ALPHA):SetAllPoints()
    strip.cells = {}
    for _, region in ipairs(REGIONS) do
        strip.cells[region] = {}
        for i = 1, SLOTS_PER_BAR do
            local cell = strip:CreateTexture(nil, "ARTWORK")
            cell:SetSize(MINI_TILE, MINI_TILE)
            cell:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
            strip.cells[region][i] = cell
        end
    end
    P.PlaceStrip(strip, strip.cells, MINI_TILE, MINI_GAP, MINI_INSET, false)
    return strip
end

function P.PaintMiniStrip(strip, slots)
    local slot = St.SLOT_TOP_RGB
    for region, page in pairs(P.REGION_PAGES) do
        local first = (page - 1) * SLOTS_PER_BAR
        for i, cell in ipairs(strip.cells[region]) do
            local texture = P.EntryTexture(slots[first + i])
            if texture then
                cell:SetTexture(texture)
            else
                cell:SetColorTexture(slot.r, slot.g, slot.b, 1)
            end
            cell.empty = texture == nil
        end
    end
end

local function LabelEnter(label)
    P.ShowOutline(label.scene, label.region)
    label.text:SetTextColor(GOLD_SOFT.r, GOLD_SOFT.g, GOLD_SOFT.b)
    if label.hint then label.hint(label) end
end

local function LabelLeave(label)
    label.scene.outline:Hide()
    local c = label.out and FAINT or GOLD
    label.text:SetTextColor(c.r, c.g, c.b)
    GameTooltip_Hide()
end

local function NewLabel(scene, region)
    local label = CreateFrame("Button", nil, scene)
    label:SetHeight(LABEL_H)
    label.text = P.Mono(label, MONO_SIZE, GOLD)
    label.text:SetPoint("CENTER")
    label.scene, label.region = scene, region
    label:SetScript("OnEnter", LabelEnter)
    label:SetScript("OnLeave", LabelLeave)
    label:SetScript("OnClick", Clicked)
    return label
end

local function PaintLabel(label, look)
    local text = ns.Upper(look.label or "")
    label.out = look.out
    if look.out then text = text .. DOT .. TEXT_LEFT_OUT end
    label.text:SetText(text)
    local c = look.out and FAINT or GOLD
    label.text:SetTextColor(c.r, c.g, c.b)
    label:SetWidth(math.ceil(label.text:GetStringWidth()) + LABEL_PAD * 2)
    label.onClick, label.hint, label.entry = look.onClick, look.hint, look.entry
    label:EnableMouse(look.onClick ~= nil or look.hint ~= nil)
end

local function AnchorLabel(label, tiles, middle, below)
    if below then
        label:SetPoint("TOP", tiles[middle], "BOTTOMRIGHT", 0, -LABEL_GAP)
    else
        label:SetPoint("BOTTOM", tiles[middle], "TOPRIGHT", 0, LABEL_GAP)
    end
    label.first, label.last = tiles[1], tiles[#tiles]
end

local function NewPet(scene)
    local pet = CreateFrame("Frame", nil, scene)
    pet:SetSize(PET_TILE * A.PET_BAR.buttons + PET_GAP * (A.PET_BAR.buttons - 1) + INSET * 2, PET_ROW_H)
    pet:SetPoint("TOP", 0, -(SCENE_PAD + LABEL_H + PET_LABEL_GAP))
    ns.Solid(pet, "BACKGROUND", BLACK, St.STRIP_ALPHA):SetAllPoints()
    ns.Border(pet, BLACK)
    pet.tiles = {}
    for i = 1, A.PET_BAR.buttons do
        local tile = P.NewTile(pet, PET_TILE)
        tile.scene, tile.region = scene, "pet"
        tile:SetPoint("TOPLEFT", INSET + (i - 1) * (PET_TILE + PET_GAP), -INSET)
        tile.key:ClearAllPoints()
        tile.key:SetPoint("CENTER")
        pet.tiles[i] = tile
    end
    pet.label = NewLabel(scene, "pet")
    pet.label:SetPoint("TOP", 0, -SCENE_PAD)
    pet.label.first, pet.label.last = pet.tiles[1], pet.tiles[A.PET_BAR.buttons]
    scene.labels.pet = pet.label
    return pet
end

local function ChipEnter(chip)
    if chip.hint then chip.hint(chip) end
end

local function NewFormChip(scene)
    local chip = CreateFrame("Button", nil, scene)
    chip:SetHeight(FORM_CHIP_H)
    ns.Solid(chip, "BACKGROUND", BLACK, St.CHIP_FILL_ALPHA):SetAllPoints()
    chip.edge = ns.Border(chip, GOLD, St.CHIP_EDGE_ALPHA)
    chip.text = P.Mono(chip, MONO_SIZE, GOLD)
    chip.text:SetPoint("CENTER")
    chip:SetScript("OnClick", Clicked)
    chip:SetScript("OnEnter", ChipEnter)
    chip:SetScript("OnLeave", GameTooltip_Hide)
    return chip
end

local function PaintChips(scene, chips)
    local list = scene.chips
    local count = chips and #chips or 0
    local width = 0
    for i = 1, MAX_CHIPS do
        local chip, look = list[i], chips and chips[i]
        if look and not chip then
            chip = NewFormChip(scene)
            list[i] = chip
        end
        if chip then chip:SetShown(look ~= nil) end
        if look then
            chip.text:SetText(ns.Upper(look.text))
            local c = look.picked and GOLD_SOFT or (look.out and FAINT or GOLD)
            chip.text:SetTextColor(c.r, c.g, c.b)
            local edge = look.picked and GOLD_SOFT or GOLD
            chip.edge:SetColor(edge.r, edge.g, edge.b, look.picked and 1 or St.CHIP_EDGE_ALPHA)
            chip:SetWidth(math.ceil(chip.text:GetStringWidth()) + FORM_CHIP_PAD * 2)
            chip:SetAlpha(look.out and St.DIM_ALPHA or 1)
            chip.page, chip.onClick, chip.hint = look.page, look.onClick, look.hint
            width = width + chip:GetWidth() + (i > 1 and FORM_CHIP_GAP or 0)
        end
    end
    local x = -width / 2
    for i = 1, count do
        local chip = list[i]
        chip:ClearAllPoints()
        chip:SetPoint("LEFT", scene.dock, "CENTER", x, 0)
        x = x + chip:GetWidth() + FORM_CHIP_GAP
    end
end

function P.ShowOutline(scene, region)
    local label = region and scene.labels[region]
    local first, last = label and label.first, label and label.last
    if not (first and first:IsShown()) then return end
    local outline = scene.outline
    outline:ClearAllPoints()
    outline:SetPoint("TOPLEFT", first, "TOPLEFT", -OUTLINE_OUT, OUTLINE_OUT)
    outline:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", OUTLINE_OUT, -OUTLINE_OUT)
    outline:Show()
end

local function PlaceScene(scene, pet)
    if scene.hasPet == pet then return end
    scene.hasPet = pet
    local top = SCENE_PAD + (pet and PET_BLOCK or 0)
    scene:SetHeight(pet and P.PET_SCENE_H or SCENE_H)
    scene.grid:ClearAllPoints()
    scene.grid:SetPoint("TOP", 0, -(top + LABEL_H + LABEL_GAP))
    scene.dock:ClearAllPoints()
    scene.dock:SetPoint("TOPLEFT", scene, "TOP", -MAIN_W / 2, -(top + DOCK_Y))
    scene.dock:SetSize(MAIN_W, DOCK_H)
end

function P.NewScene(parent)
    local scene = CreateFrame("Frame", nil, parent)
    P.Gradient(scene, St.SCENE_GLOW_RGB, St.SCENE_RGB, 1, 1)
    ns.Border(scene, WHITE, St.SCENE_EDGE_ALPHA)
    scene.grid = CreateFrame("Frame", nil, scene)
    ns.Solid(scene.grid, "BACKGROUND", BLACK, St.STRIP_ALPHA):SetAllPoints()
    ns.Border(scene.grid, BLACK)
    scene.dock = CreateFrame("Frame", nil, scene)
    scene.tiles, scene.labels, scene.chips = {}, {}, {}
    for _, region in ipairs(REGIONS) do
        scene.tiles[region] = {}
        for i = 1, SLOTS_PER_BAR do
            local tile = P.NewTile(scene.grid, TILE)
            tile.scene, tile.region, tile.index = scene, region, i
            scene.tiles[region][i] = tile
        end
        scene.labels[region] = NewLabel(scene, region)
    end
    P.PlaceStrip(scene.grid, scene.tiles, TILE, 0, INSET, false)
    local tiles, labels = scene.tiles, scene.labels
    AnchorLabel(labels.left, tiles.left, SIDE_MIDDLE)
    AnchorLabel(labels.top, tiles.top, HALF)
    AnchorLabel(labels.right, tiles.right, SIDE_MIDDLE)
    AnchorLabel(labels.bottom, tiles.bottom, HALF, true)
    scene.outline = CreateFrame("Frame", nil, scene.grid)
    scene.outline:SetFrameLevel(scene.grid:GetFrameLevel() + OUTLINE_LEVEL)
    ns.Border(scene.outline, GOLD_SOFT):SetPixels(OUTLINE_PIXELS)
    scene.outline:Hide()
    scene.pet = NewPet(scene)
    scene.caption = P.Mono(scene, MONO_SIZE, INK)
    scene.caption:SetPoint("BOTTOM", 0, SCENE_PAD)
    PlaceScene(scene, false)
    return scene
end

function P.ScenePicker(scene, values, order, get, set)
    scene.picker = UI.BuildDropdownControl(scene.dock, PICKER_W, nil, values, order, get, set)
    scene.picker:SetPoint("LEFT")
    return scene.picker
end

local function PaintPet(scene, pet)
    local frame = scene.pet
    frame:SetShown(pet ~= nil)
    frame.label:SetShown(pet ~= nil)
    if not pet then return end
    PaintLabel(frame.label, pet)
    for i, tile in ipairs(frame.tiles) do
        wipe(scene.look)
        scene.look.key = pet.keys[i]
        scene.look.alpha, scene.look.tip = pet.out and St.DIM_ALPHA or 1, pet.tip
        P.PaintTile(tile, scene.look)
        tile:SetAlpha(pet.out and St.DIM_ALPHA or 1)
        tile.slot = i
    end
end

function P.DrawScene(scene, model)
    scene.look = scene.look or {}
    local single = model.single ~= nil
    PlaceScene(scene, model.pet ~= nil)
    if scene.single ~= single then
        scene.single = single
        P.PlaceStrip(scene.grid, scene.tiles, TILE, 0, INSET, single)
    end
    scene.outline:Hide()
    for _, region in ipairs(REGIONS) do
        local look = single and (region == "top" and model.single) or (not single and model.regions[region])
        local label = scene.labels[region]
        label:SetShown(look and true or false)
        for i, tile in ipairs(scene.tiles[region]) do
            tile:SetShown(look and true or false)
            if look then
                tile:SetAlpha(look.out and St.DIM_ALPHA or 1)
                model.Paint(tile, look, i)
            end
        end
        if look then PaintLabel(label, look) end
    end
    PaintPet(scene, model.pet)
    PaintChips(scene, not single and model.chips or nil)
    scene.caption:SetText(model.caption or "")
    if scene.picker then scene.picker._refreshValue() end
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

function P.Place(frame, left, top, right, bottom)
    frame:SetPoint("TOPLEFT", left, -top)
    frame:SetPoint("BOTTOMRIGHT", -right, bottom)
    return frame
end

function P.Divider(pane, y)
    local line = ns.Solid(pane, "ARTWORK", BLACK, 1)
    line:SetPoint("TOPLEFT", 0, y)
    line:SetPoint("TOPRIGHT", 0, y)
    ns.Hairline(line, "h")
    return line
end

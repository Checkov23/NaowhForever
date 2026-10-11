-- SpellGrid.lua: the crowd control and debuff grids, one icon per spell, lit while it shows.
local ns = _G.NaowhForever

local P = ns.PvP
local S = P.Settings
local T = ns.THEME
local SPELLS = ns.PvPSpells
local St = P.Style
local Settings = ns.Shared.Settings

local BORDER, ICON_CROP, BLACK = St.BORDER, St.ICON_CROP, St.BLACK
local GRID_MARGIN, NOTE_SIZE = St.STAGE_MARGIN, St.STAGE_NOTE_SIZE
local TILE, TILE_GAP, GRID_ROW, GRID_LABEL_W, GRID_NOTE = 30, 4, 36, 120, 22
local LABEL_SIZE, NOTE_Y = 12, 8
local LIT_ALPHA, IDLE_ALPHA, OFF_ALPHA = 1, 0.6, 0.3
local STATES = { { key = "spells", label = "Spells" } }

local TEXT_SHOWN = ns.L("Shown: click to hide it.")
local TEXT_HIDDEN = ns.L("Hidden: click to show it.")
local TEXT_NOTE = ns.L("%d of %d shown. Click a spell to show or hide it; hover for the spell.")

local function Groups(entries)
    local groups, last = {}, nil
    for _, entry in ipairs(entries) do
        if not last or last.name ~= entry.group then
            last = { name = entry.group, entries = {} }
            groups[#groups + 1] = last
        end
        last.entries[#last.entries + 1] = entry
    end
    return groups
end

local function PaintTile(tile)
    local on = S.Get(tile.key) == true
    tile.icon:SetDesaturated(not on)
    tile:SetAlpha(on and (tile.needs() and LIT_ALPHA or IDLE_ALPHA) or OFF_ALPHA)
    local c = on and T.accent or BLACK
    tile.edge:SetColor(c.r, c.g, c.b, 1)
end

local function TileEnter(tile)
    GameTooltip:SetOwner(tile, "ANCHOR_TOP")
    GameTooltip:SetSpellByID(tile.entry.spell)
    GameTooltip:AddLine(S.Get(tile.key) and TEXT_SHOWN or TEXT_HIDDEN, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    GameTooltip:Show()
end

local function TileLeave()
    GameTooltip:Hide()
end

local function GridNote(shot)
    local on, total = 0, #shot.tiles
    for _, tile in ipairs(shot.tiles) do
        if S.Get(tile.key) then on = on + 1 end
    end
    shot.note:SetText(TEXT_NOTE:format(on, total))
end

local function TileClick(tile)
    S.Set(tile.key, not S.Get(tile.key))
    PaintTile(tile)
    GridNote(tile:GetParent())
    TileEnter(tile)
end

local TILE_SCRIPTS = { click = TileClick, enter = TileEnter, leave = TileLeave }

local function NewTile(shot, entry, x, y)
    local tile = Settings.EditZone(shot, TILE_SCRIPTS)
    tile:SetSize(TILE, TILE)
    tile:SetPoint("TOPLEFT", shot, "TOPLEFT", x, -y)
    ns.Solid(tile, "BACKGROUND", BLACK, 1):SetAllPoints()
    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetPoint("TOPLEFT", BORDER, -BORDER)
    tile.icon:SetPoint("BOTTOMRIGHT", -BORDER, BORDER)
    tile.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    tile.icon:SetTexture(entry.icon)
    tile.edge = ns.Border(tile, BLACK)
    return tile
end

local function AddGroup(shot, group, i, prefix, needs)
    local y = GRID_MARGIN + (i - 1) * GRID_ROW
    local label = ns.Font(shot, LABEL_SIZE, nil, T.muted)
    label:SetPoint("LEFT", shot, "TOPLEFT", GRID_MARGIN, -(y + TILE / 2))
    label:SetText(group.name)
    for j, entry in ipairs(group.entries) do
        local tile = NewTile(shot, entry, GRID_MARGIN + GRID_LABEL_W + (j - 1) * (TILE + TILE_GAP), y)
        tile.entry, tile.key, tile.needs = entry, prefix .. entry.key, needs
        shot.tiles[#shot.tiles + 1] = tile
    end
end

local function NewGrid(groups, prefix, needs)
    return function(stage)
        local shot = CreateFrame("Frame", nil, stage)
        shot:SetAllPoints()
        shot.tiles = {}
        for i, group in ipairs(groups) do AddGroup(shot, group, i, prefix, needs) end
        shot.note = ns.Font(shot, NOTE_SIZE, nil, T.muted)
        shot.note:SetPoint("BOTTOMLEFT", GRID_MARGIN, NOTE_Y)
        return shot
    end
end

local function PaintGrid(shot)
    for _, tile in ipairs(shot.tiles) do PaintTile(tile) end
    GridNote(shot)
end

local function GridHeight(groups)
    return function() return GRID_MARGIN * 2 + #groups * GRID_ROW + GRID_NOTE end
end

local function Studio(entries, prefix)
    local groups = Groups(entries)
    return { height = GridHeight(groups), states = STATES, new = NewGrid(groups, prefix, P.Enabled), paint = PaintGrid }
end

P.SpellGrid = {
    crowdControl = Studio(SPELLS.crowdControl, P.CC_PREFIX),
    debuffs = Studio(SPELLS.debuffs, P.DEBUFF_PREFIX),
}

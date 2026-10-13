-- Unexplored.lua: the world map's unexplored areas drawn darkened instead of left blank.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local TEMPLATE = "NaowhForeverUnexploredPinTemplate"
local TILE = 256
local SMALLEST_FILE = 16
local AREA_FIELDS = 4
local MAP_CENTRE = 0.5
local DARK_RANGE = { 10, 90, 5 }
local PERCENT_SCALE = ns.Shared.Style.PERCENT_SCALE
local EMPTY = {}
local SECTION_ORDER = 11
local TEXT_SECTION = ns.L("Map")
local TEXT_OFF = ns.L("Unexplored Areas off")

local explored = {}
local added
local provider = CreateFromMixins(MapCanvasDataProviderMixin)
local events = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and S.Get("mapUnexplored")
end

local function Span(index, count, size)
    if index < count then return TILE, TILE end
    local pixels = size % TILE
    if pixels == 0 then pixels = TILE end
    local file = SMALLEST_FILE
    while file < pixels do file = file * 2 end
    return pixels, file
end

NaowhForeverUnexploredPinMixin = CreateFromMixins(MapCanvasPinMixin)

function NaowhForeverUnexploredPinMixin:OnLoad()
    self:SetIgnoreGlobalPinScale(true)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_MAP_EXPLORATION")
    self.textures = CreateTexturePool(self, "ARTWORK", 0)
end

function NaowhForeverUnexploredPinMixin:CheckMouseButtonPassthrough() end

local function DrawTile(pin, area, row, col, wide, tall, shade)
    local width, height, x, y = area[1], area[2], area[3], area[4]
    local rowPixels, rowFile = Span(row, tall, height)
    local colPixels, colFile = Span(col, wide, width)
    local tex = pin.textures:Acquire()
    tex:SetSize(colPixels, rowPixels)
    tex:SetTexCoord(0, colPixels / colFile, 0, rowPixels / rowFile)
    tex:SetPoint("TOPLEFT", x + TILE * (col - 1), -(y + TILE * (row - 1)))
    tex:SetTexture(area[AREA_FIELDS + (row - 1) * wide + col], nil, nil, "TRILINEAR")
    tex:SetDesaturated(true)
    tex:SetVertexColor(shade, shade, shade)
    tex:Show()
end

local function DrawArea(pin, area, shade)
    local wide, tall = math.ceil(area[1] / TILE), math.ceil(area[2] / TILE)
    for row = 1, tall do
        for col = 1, wide do DrawTile(pin, area, row, col, wide, tall, shade) end
    end
end

local function NoteExplored(mapID)
    wipe(explored)
    for _, info in ipairs(C_MapExplorationInfo.GetExploredMapTextures(mapID) or EMPTY) do
        explored[info.textureWidth .. ":" .. info.textureHeight .. ":" .. info.offsetX .. ":" .. info.offsetY] = true
    end
end

function NaowhForeverUnexploredPinMixin:Refresh()
    self.textures:ReleaseAll()
    local map = self:GetMap()
    local mapID = map:GetMapID()
    local overlays = On() and ns.MapOverlays[mapID]
    if not overlays then return end
    self:SetSize(map:DenormalizeHorizontalSize(1), map:DenormalizeVerticalSize(1))
    self:SetAlpha(map:GetGlobalAlpha())
    local shade = 1 - S.Get("mapUnexploredDark")
    NoteExplored(mapID)
    for _, area in ipairs(overlays) do
        if not explored[area[1] .. ":" .. area[2] .. ":" .. area[3] .. ":" .. area[4]] then DrawArea(self, area, shade) end
    end
end

local function OnExplored()
    provider.pin:Refresh()
end

events:SetScript("OnEvent", OnExplored)

function provider:OnAdded(map)
    MapCanvasDataProviderMixin.OnAdded(self, map)
    self.pin = map:AcquirePin(TEMPLATE)
    self.pin:SetPosition(MAP_CENTRE, MAP_CENTRE)
end

function provider:OnShow()
    if On() then events:RegisterEvent("MAP_EXPLORATION_UPDATED") end
end

function provider:OnHide()
    events:UnregisterEvent("MAP_EXPLORATION_UPDATED")
end

function provider:RemoveAllData()
    self.pin.textures:ReleaseAll()
end

function provider:RefreshAllData()
    self.pin:Refresh()
end

function provider:OnGlobalAlphaChanged()
    self.pin:SetAlpha(self:GetMap():GetGlobalAlpha())
end

local function Apply()
    if not added then
        if not On() then return end
        WorldMapFrame:AddDataProvider(provider)
        added = true
    end
    if WorldMapFrame:IsShown() then
        if On() then
            events:RegisterEvent("MAP_EXPLORATION_UPDATED")
        else
            events:UnregisterEvent("MAP_EXPLORATION_UPDATED")
        end
        provider:RefreshAllData()
    end
end

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key:find("^mapUnexplored") then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

table.insert(ns.Shared.MapPins, {
    map = true,
    title = TEXT_SECTION, order = SECTION_ORDER, store = S, switch = "mapUnexplored",
    rows = {
        { key = "mapUnexplored", label = "Unexplored Areas", toggle = true, store = S,
          help = "Shows the parts of the world map you have not explored yet, darkened." },
        { key = "mapUnexploredDark", label = "Unexplored Darkness", slider = DARK_RANGE, unit = "%",
          scale = PERCENT_SCALE, store = S, needs = "mapUnexplored", why = TEXT_OFF },
    },
})

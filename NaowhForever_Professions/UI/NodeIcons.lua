-- NodeIcons.lua: Minimap Node Icons: each herb and vein the minimap tracks shows its item, ringed red when your skill is too low, and its tooltip the skill it needs.
local ns = _G.NaowhForever

local GetBestMapForUnit = C_Map.GetBestMapForUnit
local GetPlayerMapPosition = C_Map.GetPlayerMapPosition
local GetMapWorldSize = C_Map.GetMapWorldSize
local GetItemIconByID = C_Item.GetItemIconByID
local cos, sin = math.cos, math.sin

local P = ns.Professions
local S = P.Settings
local Style = P.Style
local Scan = P.NodeScan
local C = P.C
local Parts = ns.Shared.Parts

local CHECK_SECONDS = 0.5
local RESCAN_SECONDS = 5
local RESCAN_YARDS = 20
local MAX_ICONS = 40
local MATCH_UNITS = 12
local COVER_YARDS = 8
local REFINES_PER_FRAME = 2
local RING_WIDTH = 1.5
local LEVEL_UP = 5
local TIER_ORANGE, TIER_YELLOW, TIER_GREEN, TIER_GREY = 0, 1, 2, 3
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local SQUARE_SHAPE = "SQUARE"
local ROTATE_CVAR = "rotateMinimap"
local CROP_LOW, CROP_HIGH = Style.ICON_CROP, Style.ICON_CROP_HIGH
local EVENTS = { "MINIMAP_UPDATE_TRACKING", "SKILL_LINES_CHANGED", "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA" }
local TEXT_REQUIRES = ns.L("Requires %s %d")
local TEXT_NAMED = "%s: %s"
local TEXT_PROFESSION = { herb = ns.L("Herbalism"), ore = ns.L("Mining") }

local events, layer, hooked
local scanning = false
local wait, since = 0, 0
local scanX, scanY
local anchorMap, anchorFacing, anchorScale = nil, 0, 1
local anchorEast, anchorNorth = 0, 0
local mapWidth, mapHeight = 1, 1
local nodes, pending = {}, {}
local shown = 0
local found, said = {}, {}

local function On()
    return S.Get("enabled") and S.Get("nodeIcons") and true or false
end

local function Plain(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Tracking()
    for i = 1, C_Minimap.GetNumTrackingTypes() do
        local info = C_Minimap.GetTrackingInfo(i)
        if info and info.active and (info.spellID == C.FIND_SPELL.herb or info.spellID == C.FIND_SPELL.ore) then
            return true
        end
    end
    return false
end

local function PlayerYards()
    local mapID = GetBestMapForUnit("player")
    local pos = mapID and GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    local width, height = GetMapWorldSize(mapID)
    return mapID, pos.x * width, -pos.y * height, width, height
end

local function Facing()
    return C_CVar.GetCVarBool(ROTATE_CVAR) and GetPlayerFacing() or 0
end

local function UnitsPerYard()
    return Minimap:GetWidth() / 2 / C_Minimap.GetViewRadius()
end

local function Square()
    return GetMinimapShape ~= nil and GetMinimapShape() == SQUARE_SHAPE
end

local function IconSize()
    return math.max(S.Get("nodeIconSize"), C.NODE_ICON_MIN)
end

local function Unsnap(texture)
    texture:SetSnapToPixelGrid(false)
    texture:SetTexelSnappingBias(0)
end

local function NewIcon()
    local pin = CreateFrame("Frame", nil, Minimap)
    pin:SetFrameLevel(Minimap:GetFrameLevel() + LEVEL_UP)
    pin.ring = pin:CreateTexture(nil, "ARTWORK")
    pin.ring:SetTexture(ROUND)
    pin.ring:SetPoint("CENTER")
    pin.art = pin:CreateTexture(nil, "OVERLAY")
    pin.art:SetPoint("CENTER")
    pin.art:SetTexCoord(CROP_LOW, CROP_HIGH, CROP_LOW, CROP_HIGH)
    pin.mask = pin:CreateMaskTexture()
    pin.mask:SetTexture(ROUND, MASK_WRAP, MASK_WRAP)
    pin.mask:SetAllPoints(pin.art)
    pin.art:AddMaskTexture(pin.mask)
    Unsnap(pin.ring)
    Unsnap(pin.art)
    return pin
end

local function Paint(pin, list, i)
    local node = list[i].node
    local size = IconSize()
    pin:SetSize(size + 2 * RING_WIDTH, size + 2 * RING_WIDTH)
    pin.ring:SetSize(size + 2 * RING_WIDTH, size + 2 * RING_WIDTH)
    pin.art:SetSize(size, size)
    local item = Scan.Item(node)
    pin.art:SetTexture(item and GetItemIconByID(item) or C_Spell.GetSpellTexture(C.FIND_SPELL[Scan.Kind(node)]))
    local c = Scan.TooHard(node) and Style.RED_RGB or Style.BORDER_RGB
    pin.ring:SetVertexColor(c.r, c.g, c.b)
end

local function XY(list, i)
    local spot = list[i]
    return spot.east / mapWidth, -spot.north / mapHeight
end

local function Show()
    layer = layer or Parts.MinimapLayer({ max = MAX_ICONS, new = NewIcon, paint = Paint, xy = XY })
    layer:Set(anchorMap, nodes, shown)
    ns.NodeIconsChanged()
end

local function Clear()
    for i = 1, shown do nodes[i].live = false end
    shown, anchorMap = 0, nil
    wipe(pending)
    if layer then layer:Set(nil) end
    ns.NodeIconsChanged()
end

local function Repaint()
    if layer then layer:Repaint() end
end

local function ToMinimap(spot, east, north, c, s, scale)
    local dx, dy = spot.east - east, spot.north - north
    return (dx * c - dy * s) * scale, (dx * s + dy * c) * scale
end

local function ToWorld(x, y, east, north, facing, scale)
    local c, s = cos(facing), sin(facing)
    x, y = x / scale, y / scale
    return east + x * c - y * s, north + x * s + y * c
end

local function Ready()
    return Minimap:IsVisible() and Minimap:GetLeft() ~= nil and not InCombatLockdown()
        and not Minimap:IsMouseOver()
end

local function Moved()
    local x, y = UnitPosition("player")
    return x ~= nil and scanX ~= nil and (x - scanX) ^ 2 + (y - scanY) ^ 2 > RESCAN_YARDS * RESCAN_YARDS
end

local function StartScan()
    if not Ready() then return end
    local mapID, east, north, width, height = PlayerYards()
    if anchorMap and mapID ~= anchorMap then Clear() end
    if not mapID then return end
    anchorMap, anchorEast, anchorNorth, mapWidth, mapHeight = mapID, east, north, width, height
    anchorScale, anchorFacing = UnitsPerYard(), Facing()
    scanX, scanY = UnitPosition("player")
    since = 0
    Scan.Start(Minimap:GetWidth(), Square())
    scanning = true
end

local function Match(name, east, north, reach)
    local best, bestDistance
    for i = 1, shown do
        local spot = nodes[i]
        if not spot.seen and spot.name == name then
            local dx, dy = spot.east - east, spot.north - north
            local distance = dx * dx + dy * dy
            if distance <= reach * reach and (not best or distance < bestDistance) then
                best, bestDistance = spot, distance
            end
        end
    end
    return best
end

local function Track(name, east, north)
    shown = shown + 1
    local spot = nodes[shown]
    if not spot then
        spot = {}
        nodes[shown] = spot
    end
    spot.name, spot.node = name, Scan.Node(name)
    spot.east, spot.north = east, north
    spot.seen, spot.live, spot.refined = true, true, false
    pending[#pending + 1] = spot
end

local function DropUnseen()
    local kept = 0
    for i = 1, shown do
        local spot = nodes[i]
        if spot.seen then
            kept = kept + 1
            nodes[i], nodes[kept] = nodes[kept], spot
        else
            spot.live = false
        end
    end
    shown = kept
end

local function FinishScan()
    scanning = false
    local places, count = Scan.Places()
    local half = Minimap:GetWidth() / 2
    local reach = MATCH_UNITS / anchorScale
    for i = 1, shown do nodes[i].seen = false end
    for i = 1, count do
        local place = places[i]
        local east, north = ToWorld(place.x - half, place.y - half, anchorEast, anchorNorth, anchorFacing,
            anchorScale)
        local spot = Match(place.name, east, north, reach)
        if spot then
            spot.seen = true
            if not spot.refined then spot.east, spot.north = east, north end
        elseif shown < MAX_ICONS then
            Track(place.name, east, north)
        end
    end
    DropUnseen()
    Show()
end

local function RefineSome()
    local mapID, east, north = PlayerYards()
    if mapID ~= anchorMap or not Ready() then
        wipe(pending)
        return
    end
    local scale = UnitsPerYard()
    local facing = Facing()
    local c, s = cos(-facing), sin(-facing)
    local half = Minimap:GetWidth() / 2
    local left, bottom, ui = Minimap:GetLeft(), Minimap:GetBottom(), Minimap:GetEffectiveScale()
    for _ = 1, REFINES_PER_FRAME do
        local spot = pending[#pending]
        if not spot then break end
        pending[#pending] = nil
        if spot.live then
            local x, y = ToMinimap(spot, east, north, c, s, scale)
            x, y = Scan.Refine(left, bottom, ui, spot.name, x + half, y + half)
            spot.east, spot.north = ToWorld(x - half, y - half, east, north, facing, scale)
            spot.refined = true
        end
    end
    layer:Place()
    if not pending[1] then ns.NodeIconsChanged() end
end

local function OnUpdate(_, elapsed)
    if scanning then
        if not Ready() then
            scanning = false
        elseif Scan.Step(Minimap:GetLeft(), Minimap:GetBottom(), Minimap:GetEffectiveScale()) then
            FinishScan()
        end
    elseif pending[1] then
        RefineSome()
    else
        wait = wait - elapsed
        if wait > 0 then return end
        wait = CHECK_SECONDS
        since = since + CHECK_SECONDS
        if since >= RESCAN_SECONDS or Moved() then StartScan() end
    end
end

local function Watch()
    scanning = false
    wait, since = 0, RESCAN_SECONDS
    events:SetScript("OnUpdate", Tracking() and OnUpdate or nil)
end

local function Tier(over)
    if over < C.SKILL_ORANGE then return TIER_ORANGE end
    if over < C.SKILL_YELLOW then return TIER_YELLOW end
    if over < C.SKILL_GREEN then return TIER_GREEN end
    return TIER_GREY
end

local function AddNeed(tooltip, name, named)
    local node = Scan.Node(name)
    local kind, need = Scan.Kind(node), Scan.Need(node)
    local over = Scan.Skill(kind) - need
    local c = over < 0 and Style.RED_RGB or Style.DIFFICULTY_RGB[Tier(over)]
    local text = TEXT_REQUIRES:format(TEXT_PROFESSION[kind], need)
    if named then text = TEXT_NAMED:format(name, text) end
    tooltip:AddLine(text, c.r, c.g, c.b)
end

local function OnMinimapTooltip(tooltip, data)
    if not On() or not (data and Plain(data)) then return end
    local lines = data.lines
    if not (lines and Plain(lines)) then return end
    wipe(found)
    wipe(said)
    for _, line in ipairs(lines) do
        local text = line.leftText
        if text and Plain(text) then
            for _, name in ipairs(Scan.Known(text)) do
                if not said[name] then
                    said[name] = true
                    found[#found + 1] = name
                end
            end
        end
    end
    if #found == 0 then return end
    for _, name in ipairs(found) do AddNeed(tooltip, name, #found > 1) end
    tooltip:Show()
end

local function OnEvent(_, event)
    if event == "SKILL_LINES_CHANGED" then
        Scan.ReadSkills()
        return Repaint()
    end
    if event ~= "MINIMAP_UPDATE_TRACKING" then Scan.ReadSkills() end
    Clear()
    Watch()
end

local function Apply()
    if not On() or not Scan.Usable() then
        if events then
            events:UnregisterAllEvents()
            events:SetScript("OnUpdate", nil)
            Clear()
        end
        scanning = false
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    if not hooked then
        hooked = true
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.MinimapMouseover, OnMinimapTooltip)
    end
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    Scan.ReadSkills()
    Watch()
    Repaint()
end

function ns.NodeIconAt(mapID, x, y)
    if mapID ~= anchorMap then return false end
    local east, north = x * mapWidth, -y * mapHeight
    for i = 1, shown do
        local spot = nodes[i]
        if (spot.east - east) ^ 2 + (spot.north - north) ^ 2 <= COVER_YARDS * COVER_YARDS then return true end
    end
    return false
end

function ns.NodeIconsChanged() end

local function OnSettingChanged(key)
    if key == "enabled" or key:find("^nodeIcon") then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

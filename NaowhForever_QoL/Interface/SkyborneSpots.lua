-- SkyborneSpots.lua: Skyborne Spots: the ley lines and Elemental Convergences pinned on the world map.
local ns = _G.NaowhForever

local S = ns.QoLSettings

local TEMPLATE = "NaowhForeverSkybornePinTemplate"
local SAME_SPOT = 40
local MIN_BUFF = 60
local MAP_CONTINENT = 2
local PERCENT = ns.QoLConstants.PERCENT
local PERMILLE, TENTHS = ns.QoLConstants.PERMILLE, ns.QoLConstants.TENTHS
local ROUND = ns.QoLConstants.ROUND
local FIRST_LOOK, RETRY_DELAY, MAX_TRIES = 0.2, 0.5, 4
local CAST_SLACK = 1
local DEFAULT_SIZE = 20
local CONTINENT_SCALE = 0.75
local MAXIMIZED_SHRINK = 2
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local HELP_RGB = { r = 0.61, g = 0.64, b = 0.69 }
local HINT_RGB = ns.QoLConstants.HINT_RGB
local PIN_RANGE = ns.Shared.Style.PIN_SIZE_RANGE
local SKYBORNE = "Skyborne"

local KINDS = {
    leyline = { name = ns.L("Ley Line"), faction = "Alliance", racial = 1259705, buff = 1259691,
        help = ns.L("Stand on it and cast Read Ley Line."),
        icon = "Interface\\Icons\\Spell_Arcane_Arcane04" },
    convergence = { name = ns.L("Elemental Convergence"), faction = "Horde", racial = 1259686, buff = 1270893,
        help = ns.L("Cast Skysight here for Elemental Blessing."),
        icon = "Interface\\Icons\\Spell_Nature_LightningShield" },
}

local TEXT_SAVED = ns.L("%s saved on your map: %s %.1f, %.1f.")
local TEXT_UNKNOWN_MAP = "?"
local TEXT_CLICK = ns.L("Click for a waypoint.")
local TEXT_FORGET = ns.L("Right-click to forget this spot.")
local SECTION_ORDER = 60
local TEXT_SECTION = "Skyborne"

local waiting
local events
local provider, added
local waitingForMap = false
local watch = CreateFrame("Frame")
local Redraw

local function On()
    return S.Get("enabled") and S.Get("mapSkyborne")
end

local function MyKind()
    if select(2, UnitRace("player")) ~= SKYBORNE then return nil end
    local faction = UnitFactionGroup("player")
    for key, kind in pairs(KINDS) do
        if kind.faction == faction then return key end
    end
end

local function Found(kind)
    local account = ns.AccountSettings()
    account.skyborneSpots = account.skyborneSpots or {}
    account.skyborneSpots[kind] = account.skyborneSpots[kind] or {}
    return account.skyborneSpots[kind]
end

local function AnyFound()
    local all = ns.AccountSettings().skyborneSpots
    for _, list in pairs(all or {}) do
        if #list > 0 then return true end
    end
    return false
end

local function World(map, x, y)
    local continent, pos = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x / PERCENT, y / PERCENT))
    if not (continent and pos) then return nil end
    local wx, wy = pos:GetXY()
    return continent, wx, wy
end

local function Near(spot, continent, wx, wy)
    local c, sx, sy = World(spot[1], spot[2], spot[3])
    if c ~= continent then return false end
    return (sx - wx) ^ 2 + (sy - wy) ^ 2 <= SAME_SPOT * SAME_SPOT
end

local function AnyNear(list, continent, wx, wy)
    for _, spot in ipairs(list) do
        if Near(spot, continent, wx, wy) then return true end
    end
    return false
end

local function Save(kind, map, x, y)
    local continent, wx, wy = World(map, x, y)
    if not continent then return end
    if AnyNear(ns.SkyborneSpots[kind], continent, wx, wy) or AnyNear(Found(kind), continent, wx, wy) then return end
    local found = Found(kind)
    found[#found + 1] = { map, x, y }
    local info = C_Map.GetMapInfo(map)
    ns.Print(TEXT_SAVED:format(KINDS[kind].name, info and info.name or TEXT_UNKNOWN_MAP, x, y))
    Redraw()
end

local function Readable()
    return not (InCombatLockdown() or C_Secrets.ShouldAurasBeSecret())
end

local function HasBuff(cast)
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(KINDS[cast.kind].buff)
    return aura and aura.duration >= MIN_BUFF and aura.expirationTime - aura.duration >= cast.time
end

local function Check(cast)
    cast.tries = cast.tries + 1
    local ok, has = false, nil
    if Readable() then ok, has = pcall(HasBuff, cast) end
    if ok and has then
        Save(cast.kind, cast.map, cast.x, cast.y)
    elseif ok and cast.tries < MAX_TRIES then
        C_Timer.After(RETRY_DELAY, function() Check(cast) end)
    elseif not ok or InCombatLockdown() then
        waiting = cast
        watch:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
end

local function Tenths(share)
    return math.floor(share * PERMILLE + ROUND) / TENTHS
end

local function Cast(kind)
    local map = C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    local cast = { kind = kind, map = map, tries = 0, time = GetTime() - CAST_SLACK, x = Tenths(x), y = Tenths(y) }
    C_Timer.After(FIRST_LOOK, function() Check(cast) end)
end

local function OnCombatEnd()
    watch:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local cast = waiting
    waiting = nil
    if not (cast and Readable()) then return end
    local ok, has = pcall(HasBuff, cast)
    if ok and has then Save(cast.kind, cast.map, cast.x, cast.y) end
end

local function OnWatchEvent(_, event, _, _, spellID)
    if event == "PLAYER_REGEN_ENABLED" then
        OnCombatEnd()
        return
    end
    local kind = MyKind()
    if kind and not (issecretvalue and issecretvalue(spellID)) and spellID == KINDS[kind].racial then Cast(kind) end
end

local function Watch()
    watch:UnregisterAllEvents()
    if On() and MyKind() then watch:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player") end
end

local function InRange(px, py)
    return px >= 0 and px <= 1 and py >= 0 and py <= 1
end

local function SpotOn(mapID, spot)
    local x, y = spot[2] / PERCENT, spot[3] / PERCENT
    if spot[1] == mapID then return x, y end
    local continent, world = C_Map.GetWorldPosFromMapPos(spot[1], CreateVector2D(x, y))
    local pos = continent and world and select(2, C_Map.GetMapPosFromWorldPos(continent, world, mapID))
    if not pos then return nil end
    local px, py = pos:GetXY()
    if not InRange(px, py) then return nil end
    return px, py
end

local function PinSize(map)
    local info = C_Map.GetMapInfo(map:GetMapID())
    local size = S.Get("mapSkyborneSize") or DEFAULT_SIZE
    if info and info.mapType and info.mapType <= MAP_CONTINENT then size = size * CONTINENT_SCALE end
    if map:IsMaximized() then size = size / MAXIMIZED_SHRINK end
    return size
end

local function Forget(entry)
    if not entry.found then return end
    local list = Found(entry.kind)
    for i = #list, 1, -1 do
        if list[i] == entry.spot then table.remove(list, i) end
    end
    GameTooltip:Hide()
    Redraw()
end

local function MakePinMixin()
    NaowhForeverSkybornePinMixin = CreateFromMixins(MapCanvasPinMixin)
    local Pin = NaowhForeverSkybornePinMixin

    function Pin:OnLoad()
        self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
        self.Icon:SetMask(MASK)
    end

    function Pin:CheckMouseButtonPassthrough() end

    function Pin:OnAcquired(entry, x, y)
        self.entry = entry
        local size = PinSize(self:GetMap())
        self:SetSize(size, size)
        self.Icon:SetTexture(KINDS[entry.kind].icon)
        self:SetPosition(x, y)
    end

    function Pin:OnMouseEnter()
        local kind = KINDS[self.entry.kind]
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(kind.name, 1, 1, 1)
        GameTooltip:AddLine(kind.help, HELP_RGB.r, HELP_RGB.g, HELP_RGB.b)
        local c = ns.ThemeTint("accentSoft", nil) or HINT_RGB
        GameTooltip:AddLine(TEXT_CLICK, c.r, c.g, c.b)
        if self.entry.found then GameTooltip:AddLine(TEXT_FORGET, c.r, c.g, c.b) end
        GameTooltip:Show()
    end

    function Pin:OnMouseLeave()
        GameTooltip:Hide()
    end

    function Pin:OnClick(button)
        local entry = self.entry
        if button == "RightButton" then
            Forget(entry)
        elseif button == "LeftButton" then
            local spot = entry.spot
            ns.PlaceWaypoint(KINDS[entry.kind].name, spot[1], spot[2], spot[3])
        end
    end
end

local function AcquireAll(map, mapID, kind, list, found)
    for _, spot in ipairs(list) do
        local x, y = SpotOn(mapID, spot)
        if x then map:AcquirePin(TEMPLATE, { kind = kind, spot = spot, found = found }, x, y) end
    end
end

local function MakeProvider()
    provider = CreateFromMixins(MapCanvasDataProviderMixin)

    function provider:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
    end

    function provider:RefreshAllData()
        self:RemoveAllData()
        local kind = On() and MyKind()
        if not kind then return end
        local map = self:GetMap()
        local mapID = map:GetMapID()
        if not mapID then return end
        AcquireAll(map, mapID, kind, ns.SkyborneSpots[kind], false)
        AcquireAll(map, mapID, kind, Found(kind), true)
    end
end

Redraw = function()
    if not (added and WorldMapFrame:IsShown()) then return end
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    provider:RefreshAllData()
end

local function Resize()
    if not (added and WorldMapFrame:IsShown()) then return end
    for pin in WorldMapFrame:EnumeratePinsByTemplate(TEMPLATE) do
        local size = PinSize(WorldMapFrame)
        pin:SetSize(size, size)
    end
end

local function OnRedrawEvent(_, event)
    events:UnregisterEvent(event)
    Redraw()
end

local function Install()
    MakePinMixin()
    MakeProvider()
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnRedrawEvent)
    WorldMapFrame:HookScript("OnSizeChanged", Resize)
end

local function Apply()
    Watch()
    if not On() then
        Redraw()
        return
    end
    if not WorldMapFrame then
        if not waitingForMap then
            waitingForMap = true
            EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", Apply)
        end
        return
    end
    if not provider then Install() end
    if not added then
        WorldMapFrame:AddDataProvider(provider)
        added = true
    end
    Redraw()
end

local function ForgetAll()
    ns.AccountSettings().skyborneSpots = nil
    Redraw()
end

watch:SetScript("OnEvent", OnWatchEvent)

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "mapSkyborne" then
        Apply()
    elseif key == "mapSkyborneSize" then
        Resize()
    end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

table.insert(ns.Shared.MapPins, {
    title = TEXT_SECTION, order = SECTION_ORDER, store = S, switch = "mapSkyborne",
    rows = {
        { key = "mapSkyborne", label = "Skyborne Spots", toggle = true, store = S,
          help = "For Skyborne characters: ley lines (Alliance, for Read Ley Line) or Elemental "
              .. "Convergences (Horde, for Skysight) pinned on the world map. The game does not mark "
              .. "them: the addon knows the ones players have found, and saves each new one you cast "
              .. "your racial on. Other races see no pins." },
        { key = "mapSkyborneSize", label = "Skyborne Pin Size", slider = PIN_RANGE, store = S,
          needs = "mapSkyborne" },
        { label = "Forget Found Spots", buttonText = "Forget All", button = ForgetAll, store = S,
          needs = AnyFound, why = "No spots found yet",
          help = "Forgets every spot this account found. The addon's own list stays.",
          search = "right-click right click pin forget one spot" },
    },
})

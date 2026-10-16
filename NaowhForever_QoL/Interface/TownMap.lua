-- TownMap.lua: the QoL town map: service NPCs, mailboxes and spirit healers on the world map and minimap.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local ScalePin = ns.Shared.ScalePin

local TEMPLATE = "NaowhForeverTownPinTemplate"
local LINK_TEMPLATE = "NaowhForeverZoneLinkPinTemplate"
local TRAVEL_ATLAS = "vehicle-templeofkotmogu-cyanball"
local EXIT_ATLAS = "house-reward-green-arrow-up"
local EXIT_LENGTH = 1.8
local EXIT_SHRINK = 0.6
local CAPITALS = ns.TownCapitals
local PERCENT = ns.QoLConstants.PERCENT
local PERMILLE, TENTHS, ROUND = ns.QoLConstants.PERMILLE, ns.QoLConstants.TENTHS, ns.QoLConstants.ROUND
local ICON_CROP_LOW, ICON_CROP_HIGH = ns.QoLConstants.ICON_CROP, ns.QoLConstants.ICON_CROP_HIGH
local CLASS_ICON = "Interface\\Icons\\ClassIcon_"
local TRACKING = "Interface\\Minimap\\Tracking\\"
local GOSSIP = "Interface\\GossipFrame\\"
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"
local FILE_MARK = "\\"
local ICON_FOLDER = "\\Icons\\"
local FULL_LOW, FULL_HIGH = 0, 1
local HINT = ns.QoLConstants.HINT_RGB
local EMPTY = {}
local MINI_SCALE = 0.9
local MINI_INTERVAL = 0.05
local PIN_RANGE = ns.Shared.Style.PIN_SIZE_RANGE
local TOWN_PIN_SCALE = 0.5625
local MINI_EVENTS = { "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_ENTERING_WORLD" }
local MOVE_EVENTS = { "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "MINIMAP_UPDATE_ZOOM" }
local AUDIT_EVENTS = { "GOSSIP_SHOW", "MERCHANT_SHOW", "TRAINER_SHOW", "TAXIMAP_OPENED",
    "BANKFRAME_OPENED", "AUCTION_HOUSE_SHOW", "PET_STABLE_SHOW" }
local TOWN_SHOW = { "townSpiritHealers", "townZoneLinks", "townTravel", "townClass", "townProfession", "townFlight",
    "townInn", "townBank", "townRepair", "townSupplies", "townStable", "townVendors", "townMail" }

local CATEGORIES = {
    spirit     = { "townSpiritHealers", "Interface\\Icons\\Spell_Holy_GuardianSpirit", ns.L("Spirit Healer") },
    class      = { "townClass", nil, ns.L("Class Trainer") },
    profession = { "townProfession", "Interface\\Icons\\INV_Misc_Book_09", ns.L("Trainer") },
    flight     = { "townFlight", "Interface\\Icons\\Ability_Mount_Gryphon_01", ns.L("Flight Master") },
    inn        = { "townInn", "Interface\\Icons\\INV_Misc_Rune_01", ns.L("Innkeeper") },
    bank       = { "townBank", "Interface\\Icons\\INV_Misc_Bag_10", ns.L("Banker") },
    auction    = { "townBank", "Interface\\Icons\\INV_Misc_Coin_01", ns.L("Auctioneer") },
    stable     = { "townStable", "Interface\\Icons\\Ability_Hunter_BeastTaming", ns.L("Stable Master") },
    repair     = { "townRepair", "Interface\\Icons\\Trade_BlackSmithing", ns.L("Repairs") },
    reagents   = { "townSupplies", "Interface\\Icons\\INV_Misc_Dust_01", ns.L("Reagents") },
    ammo       = { "townSupplies", "Interface\\Icons\\INV_Ammo_Arrow_01", ns.L("Ammunition") },
    food       = { "townSupplies", "Interface\\Icons\\INV_Misc_Food_14", ns.L("Food & Drink") },
    trade      = { "townVendors", "Interface\\Icons\\INV_Fabric_Linen_01", ns.L("Trade Goods") },
    vendor     = { "townVendors", "Interface\\Icons\\INV_Misc_Bag_07", ns.L("Vendor") },
    mail       = { "townMail", "Interface\\Icons\\INV_Letter_15", ns.L("Send and collect mail") },
}
local EVERYWHERE = { flight = true, inn = true, stable = true }
local STABLE_CLASS = "HUNTER"
local PIN_ROWS = {
    { header = ns.L("TOWN OPTIONS") },
    { key = "townCapitalsOnly", text = ns.L("Vendors & Trainers Only in Cities"),
      tip = ns.L("Keeps vendors, trainers and the bank off questing maps.") },
    { key = "townMinimap", text = ns.L("Mailboxes on Minimap"), tip = ns.L("Pins the mailboxes near you on the minimap.") },
    { key = "townMinimapSpirit", text = ns.L("Spirit Healers on Minimap"),
      tip = ns.L("Pins the spirit healers near you on the minimap.") },
    { header = ns.L("SHOW IN TOWN") },
    { key = "townFlight", text = ns.L("Flight Masters") },
    { key = "townInn", text = ns.L("Innkeepers") },
    { key = "townMail", text = ns.L("Mailboxes"), tip = ns.L("Every mailbox, in towns and out in the world.") },
    { key = "townSpiritHealers", text = ns.L("Spirit Healers"),
      tip = ns.L("Every graveyard's spirit healer, in towns and out in the world.") },
    { key = "townZoneLinks", text = ns.L("Zone Exits"), tip = ns.L("Click an exit to open the adjoining zone map.") },
    { key = "townTravel", text = ns.L("Boats & Zeppelins"),
      tip = ns.L("Every dock and zeppelin tower; click one to open where it goes.") },
    { key = "townClass", text = ns.L("Class Trainers"), tip = ns.L("Your class's trainers only.") },
    { key = "townProfession", text = ns.L("Profession Trainers") },
    { key = "townBank", text = ns.L("Bank & Auction House") },
    { key = "townRepair", text = ns.L("Repairs") },
    { key = "townSupplies", text = ns.L("Reagents, Ammo & Food") },
    { key = "townStable", text = ns.L("Stable Masters"), tip = ns.L("Hunters only."), class = STABLE_CLASS },
    { key = "townVendors", text = ns.L("Other Vendors"), tip = ns.L("Trade goods and every other merchant.") },
}

local MAP_ART = {
    spirit     = { "poi-soulspiritghost" },
    class      = { "Class", TRACKING .. "Class", GOSSIP .. "TrainerGossipIcon" },
    profession = { "Profession", TRACKING .. "Profession", GOSSIP .. "TrainerGossipIcon" },
    flight     = { "Taxi_Frame_Green", "TaxiNode_Neutral", "FlightMaster", TRACKING .. "FlightMaster" },
    inn        = { "Innkeeper", TRACKING .. "Innkeeper" },
    bank       = { "Banker", TRACKING .. "Banker" },
    auction    = { "Auctioneer", TRACKING .. "Auctioneer" },
    stable     = { "StableMaster", TRACKING .. "StableMaster" },
    repair     = { "Repair", TRACKING .. "Repair" },
    reagents   = { "Reagents", TRACKING .. "Reagents" },
    ammo       = { "Ammunition", TRACKING .. "Ammunition" },
    food       = { "Food", TRACKING .. "Food" },
    trade      = { "Banker", GOSSIP .. "VendorGossipIcon" },
    vendor     = { "Banker", GOSSIP .. "VendorGossipIcon" },
    mail       = { "Mailbox", TRACKING .. "Mailbox" },
}
local ROUND_ART = { spirit = true }
local TRAVEL_ART = {
    Boat = { "FlightMasterFerry", "Islands-AllianceBoat", "Islands-HordeBoat" },
    Zeppelin = { "TaxiNode_Continent_Neutral", "Interface\\Icons\\INV_ZeppelinMount", "Vehicle-Air-Horde" },
}

local TEXT_LEFT = ns.L("Left-click: ")
local TEXT_RIGHT = ns.L("Right-click: ")
local TEXT_OPEN_ZONE = ns.L("Click to open this zone")
local TEXT_AUDIT_NEAR = ns.L("%s: you %.1f, %.1f / data %.1f, %.1f, %.1f apart")
local TEXT_AUDIT_MISSING = ns.L("%s: you %.1f, %.1f on map %d, not in the data")
local TEXT_AUDIT = ns.L("Town audit %s. %d NPCs recorded so far.")
local TEXT_AUDIT_ON = ns.L("on: open an NPC's window while standing next to them")
local TEXT_AUDIT_OFF = ns.L("off")
local TEXT_TOWN, TEXT_TOWN_PINS = "Town", "Town Pins"
local TEXT_TOWN_TIP = ns.L("Service NPCs, mailboxes, spirit healers, exits and docks; the rows below pick which.")
local TEXT_TOWN_OFF = ns.L("Town pins off")
local TEXT_SUMMARY = ns.L("Town pins: %d of %d shown%s")
local TEXT_CAPITALS = ns.L(", vendors and trainers in cities only")
local TEXT_ON_MAP = ns.L(" Which town pins show is switched on the map, from the button at its top right.")
local MAP_CARD_ORDER, PIN_CARD_ORDER = 10, 20
local TEXT_MAP_CARD, TEXT_PIN_CARD = ns.L("Map Options"), ns.L("Map Pins")
local TEXT_MAP_HELP = ns.L("How the world map looks.")
local TEXT_PIN_HELP = ns.L("Every pin on the world map: town pins for your faction and each module's own.")
local TEXT_PINS_SEARCH = "vendor vendors trainer trainers mailbox graveyard npc npcs"

local miniPins, miniSpots = {}, {}
local miniMap, miniWidth, miniHeight
local miniCont, miniOX, miniOY, miniUX, miniUY, miniVX, miniVY, miniDet
local moving, elapsed = false, 0
local added
local auditing = false
local mini = CreateFrame("Frame")
local audit = CreateFrame("Frame")

local function SoftBlue(r, g, b)
    local c = ns.ThemeTint("accentSoft", nil)
    if c then return c.r, c.g, c.b end
    return r, g, b
end

local function On()
    return S.Get("enabled") and S.Get("townMap")
end

local function Tenths(share)
    return math.floor(share * PERMILLE + ROUND) / TENTHS
end

local function ClassIcon(token)
    return CLASS_ICON .. token:lower():gsub("^%l", string.upper)
end

local function IsFile(art)
    return art:find(FILE_MARK, 1, true) ~= nil
end

local function SetRound(pin, round)
    if round and not pin.roundMask then
        pin.roundMask = pin:CreateMaskTexture()
        pin.roundMask:SetTexture(ROUND_MASK, MASK_WRAP, MASK_WRAP)
        pin.roundMask:SetAllPoints(pin.Icon)
    end
    if not pin.roundMask or (pin.isRound or false) == round then return end
    if round then pin.Icon:AddMaskTexture(pin.roundMask) else pin.Icon:RemoveMaskTexture(pin.roundMask) end
    pin.isRound = round
end

local function TryArt(icon, art)
    if IsFile(art) then return icon:SetTexture(art) end
    if not C_Texture.GetAtlasInfo(art) then return false end
    icon:SetAtlas(art)
    return true
end

local function SetPinArt(pin, npc)
    local icon, kind = pin.Icon, npc[3]
    SetRound(pin, false)
    for _, art in ipairs(MAP_ART[kind] or EMPTY) do
        if TryArt(icon, art) then
            icon:SetTexCoord(FULL_LOW, FULL_HIGH, FULL_LOW, FULL_HIGH)
            pin.Border:Hide()
            return
        end
    end
    if ROUND_ART[kind] then
        SetRound(pin, true)
        icon:SetTexture(CATEGORIES[kind][2])
        icon:SetTexCoord(FULL_LOW, FULL_HIGH, FULL_LOW, FULL_HIGH)
        pin.Border:Hide()
        return
    end
    icon:SetTexture(CATEGORIES[kind][2] or ClassIcon(npc[6]))
    icon:SetTexCoord(ICON_CROP_LOW, ICON_CROP_HIGH, ICON_CROP_LOW, ICON_CROP_HIGH)
    pin.Border:Show()
end

local probe
local function TravelArt(label)
    for _, art in ipairs(TRAVEL_ART[label:match("^(%a+)")] or EMPTY) do
        if IsFile(art) then
            probe = probe or UIParent:CreateTexture()
            if probe:SetTexture(art) then return art end
        elseif C_Texture.GetAtlasInfo(art) then
            return art
        end
    end
    return TRAVEL_ATLAS
end

local function ScaleTownPin(pin)
    ScalePin(pin, TOWN_PIN_SCALE)
end

NaowhForeverTownPinMixin = CreateFromMixins(MapCanvasPinMixin)
NaowhForeverTownPinMixin.ApplyCurrentScale = ScaleTownPin

function NaowhForeverTownPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
end

function NaowhForeverTownPinMixin:CheckMouseButtonPassthrough() end

function NaowhForeverTownPinMixin:OnAcquired(npc)
    self.npc = npc
    local size = S.Get("townPinSize")
    self:SetSize(size, size)
    SetPinArt(self, npc)
    self:SetPosition(npc[1] / PERCENT, npc[2] / PERCENT)
    self:ApplyCurrentScale()
end

function NaowhForeverTownPinMixin:OnMouseEnter()
    local npc = self.npc
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(npc[4], 1, 1, 1)
    local title = npc[5] ~= "" and npc[5] or CATEGORIES[npc[3]][3]
    GameTooltip:AddLine(title, SoftBlue(HINT.r, HINT.g, HINT.b))
    if npc[3] == "flight" and ns.FlightPointReminderForPin then
        local reminder = ns.FlightPointReminderForPin(self:GetMap():GetMapID(), npc)
        if reminder then GameTooltip:AddLine(reminder, SoftBlue(HINT.r, HINT.g, HINT.b)) end
    end
    GameTooltip:Show()
end

function NaowhForeverTownPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

NaowhForeverZoneLinkPinMixin = CreateFromMixins(MapCanvasPinMixin)
NaowhForeverZoneLinkPinMixin.ApplyCurrentScale = ScaleTownPin

function NaowhForeverZoneLinkPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
end

function NaowhForeverZoneLinkPinMixin:CheckMouseButtonPassthrough() end

function NaowhForeverZoneLinkPinMixin:OnAcquired(link)
    self.link = link
    local size = S.Get("townPinSize")
    local length = size
    if link.atlasName == EXIT_ATLAS then
        size = size * EXIT_SHRINK
        length = size * EXIT_LENGTH
    end
    self:SetSize(length, length)
    local art = link.atlasName
    local itemIcon = art:find(ICON_FOLDER, 1, true) ~= nil
    SetRound(self, itemIcon)
    if not IsFile(art) then
        self.Icon:SetAtlas(art)
    else
        self.Icon:SetTexture(art)
        local low, high = FULL_LOW, FULL_HIGH
        if itemIcon then low, high = ICON_CROP_LOW, ICON_CROP_HIGH end
        self.Icon:SetTexCoord(low, high, low, high)
    end
    self.Icon:SetSize(size, length)
    self.Icon:SetRotation(link.rotation or 0)
    self:SetPosition(link.position:GetXY())
    self:ApplyCurrentScale()
end

function NaowhForeverZoneLinkPinMixin:OnClick(button)
    local link = self.link
    if button == "RightButton" and link.rightUiMapID then
        C_Map.OpenWorldMap(link.rightUiMapID)
    elseif button == "LeftButton" then
        C_Map.OpenWorldMap(link.linkedUiMapID)
    end
end

function NaowhForeverZoneLinkPinMixin:OnMouseEnter()
    local link = self.link
    local r, g, b = SoftBlue(HINT.r, HINT.g, HINT.b)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(link.name)
    if link.rightUiMapID then
        GameTooltip:AddLine(link.rightName, 1, 1, 1)
        GameTooltip:AddLine(TEXT_LEFT .. C_Map.GetMapInfo(link.linkedUiMapID).name, r, g, b)
        GameTooltip:AddLine(TEXT_RIGHT .. C_Map.GetMapInfo(link.rightUiMapID).name, r, g, b)
    elseif link.linkedUiMapID ~= self:GetMap():GetMapID() then
        GameTooltip:AddLine(TEXT_OPEN_ZONE, r, g, b)
    end
    GameTooltip:Show()
end

function NaowhForeverZoneLinkPinMixin:OnMouseLeave() GameTooltip:Hide() end

local provider = CreateFromMixins(MapCanvasDataProviderMixin)

function provider:RemoveAllData()
    self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
    self:GetMap():RemoveAllPinsByTemplate(LINK_TEMPLATE)
end

local function AddExits(map, mapID)
    for _, exit in ipairs(ns.ZoneExits[mapID] or EMPTY) do
        map:AcquirePin(LINK_TEMPLATE, { name = C_Map.GetMapInfo(exit[4]).name,
            atlasName = EXIT_ATLAS, position = CreateVector2D(exit[1] / PERCENT, exit[2] / PERCENT),
            rotation = exit[3], linkedUiMapID = exit[4] })
    end
end

local function AddDocks(map, mapID, faction)
    for _, dock in ipairs(ns.TownTravel[mapID] or EMPTY) do
        if dock[3]:find(faction, 1, true) then
            map:AcquirePin(LINK_TEMPLATE, { name = ns.L(dock[4]), atlasName = TravelArt(dock[4]),
                position = CreateVector2D(dock[1] / PERCENT, dock[2] / PERCENT), linkedUiMapID = dock[5],
                rightName = dock[6] and ns.L(dock[6]), rightUiMapID = dock[7] })
        end
    end
end

local function AddNPCs(map, list, faction, class, shops)
    for _, npc in ipairs(list or EMPTY) do
        local kind = npc[3]
        if (shops or EVERYWHERE[kind]) and npc[7]:find(faction, 1, true) and S.Get(CATEGORIES[kind][1])
            and (kind ~= "class" or npc[6] == class) and (kind ~= "stable" or class == STABLE_CLASS) then
            map:AcquirePin(TEMPLATE, npc)
        end
    end
end

local function AddAll(map, list)
    for _, entry in ipairs(list or EMPTY) do
        map:AcquirePin(TEMPLATE, entry)
    end
end

function provider:RefreshAllData()
    self:RemoveAllData()
    if not On() then return end
    local map = self:GetMap()
    local mapID = map:GetMapID()
    local shops = not S.Get("townCapitalsOnly") or CAPITALS[mapID]
    if S.Get("townZoneLinks") then AddExits(map, mapID) end
    local faction = UnitFactionGroup("player") == "Horde" and "H" or "A"
    local _, class = UnitClass("player")
    if S.Get("townTravel") then AddDocks(map, mapID, faction) end
    AddNPCs(map, ns.TownNPCs[mapID], faction, class, shops)
    if S.Get("townMail") then
        AddAll(map, ns.TownMailboxes[mapID])
    end
    if S.Get("townSpiritHealers") then
        AddAll(map, ns.TownSpiritHealers[mapID])
    end
end

local function MiniOn()
    return On() and (S.Get("townMinimap") or S.Get("townMinimapSpirit"))
end

local function MiniFit(map)
    local cont, o = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(0, 0))
    local _, u = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(1, 0))
    local _, v = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(0, 1))
    if not (o and u and v) then return false end
    miniCont, miniOX, miniOY = cont, o:GetXY()
    local ux, uy = u:GetXY()
    local vx, vy = v:GetXY()
    miniUX, miniUY, miniVX, miniVY = ux - miniOX, uy - miniOY, vx - miniOX, vy - miniOY
    miniDet = miniUX * miniVY - miniUY * miniVX
    return miniDet ~= 0
end

local function HideMiniPins()
    for _, pin in ipairs(miniPins) do pin:Hide() end
end

local function Inside(dx, dy, radius, square)
    if square then return math.abs(dx) <= radius and math.abs(dy) <= radius end
    return dx * dx + dy * dy <= radius * radius
end

local function MiniPlace()
    local wx, wy, _, cont = UnitPosition("player")
    if not wx or cont ~= miniCont then
        HideMiniPins()
        return
    end
    local rx, ry = wx - miniOX, wy - miniOY
    local px = (rx * miniVY - ry * miniVX) / miniDet
    local py = (miniUX * ry - miniUY * rx) / miniDet
    local radius = C_Minimap.GetViewRadius()
    local facing = C_CVar.GetCVarBool("rotateMinimap") and GetPlayerFacing() or 0
    local sin, cos = math.sin(facing), math.cos(facing)
    local square = GetMinimapShape and GetMinimapShape() == "SQUARE"
    local scaleX, scaleY = Minimap:GetWidth() / 2 / radius, Minimap:GetHeight() / 2 / radius
    for i, spot in ipairs(miniSpots) do
        local dx = (spot[1] / PERCENT - px) * miniWidth
        local dy = (py - spot[2] / PERCENT) * miniHeight
        dx, dy = dx * cos + dy * sin, dy * cos - dx * sin
        local pin = miniPins[i]
        pin:SetPoint("CENTER", Minimap, "CENTER", dx * scaleX, dy * scaleY)
        pin:SetShown(Inside(dx, dy, radius, square))
    end
end

local function MiniTick(_, delta)
    elapsed = elapsed + delta
    if elapsed < MINI_INTERVAL then return end
    elapsed = 0
    MiniPlace()
end

local function MiniUpdate()
    local live = #miniSpots > 0 and (moving or C_CVar.GetCVarBool("rotateMinimap"))
    mini:SetScript("OnUpdate", live and MiniTick or nil)
end

local function AddSpots(list)
    for _, spot in ipairs(list or EMPTY) do miniSpots[#miniSpots + 1] = spot end
end

local function MiniPin(i)
    local pin = miniPins[i]
    if pin then return pin end
    pin = CreateFrame("Frame", nil, Minimap, TEMPLATE)
    pin:SetScript("OnEnter", pin.OnMouseEnter)
    pin:SetScript("OnLeave", pin.OnMouseLeave)
    miniPins[i] = pin
    return pin
end

local function WatchMoving(on)
    for _, event in ipairs(MOVE_EVENTS) do
        if on then mini:RegisterEvent(event) else mini:UnregisterEvent(event) end
    end
end

local function MiniRefresh()
    wipe(miniSpots)
    miniMap = MiniOn() and C_Map.GetBestMapForUnit("player")
    if miniMap and MiniFit(miniMap) then
        if S.Get("townMinimap") then AddSpots(ns.TownMailboxes[miniMap]) end
        if S.Get("townMinimapSpirit") then AddSpots(ns.TownSpiritHealers[miniMap]) end
        miniWidth, miniHeight = C_Map.GetMapWorldSize(miniMap)
    end
    for i = #miniSpots + 1, #miniPins do miniPins[i]:Hide() end
    local size = S.Get("townPinSize") * MINI_SCALE
    for i, spot in ipairs(miniSpots) do
        local pin = MiniPin(i)
        pin:SetSize(size, size)
        pin.npc = spot
        SetPinArt(pin, spot)
    end
    WatchMoving(#miniSpots > 0)
    if #miniSpots > 0 then
        moving = IsPlayerMoving()
        MiniPlace()
    end
    MiniUpdate()
end

local function OnMiniEvent(_, event)
    if event == "PLAYER_STARTED_MOVING" or event == "PLAYER_STOPPED_MOVING" then
        moving = event == "PLAYER_STARTED_MOVING"
        MiniPlace()
        MiniUpdate()
    elseif event == "MINIMAP_UPDATE_ZOOM" then
        MiniPlace()
    else
        MiniRefresh()
    end
end

local function MiniApply()
    for _, event in ipairs(MINI_EVENTS) do
        if MiniOn() then mini:RegisterEvent(event) else mini:UnregisterEvent(event) end
    end
    MiniRefresh()
end

local function Apply()
    if not added then
        WorldMapFrame:AddDataProvider(provider)
        added = true
    end
    if WorldMapFrame:IsShown() then provider:RefreshAllData() end
    MiniApply()
end

local function Record(map, name, x, y)
    local log = ns.AccountSettings()
    log.townAudit = log.townAudit or {}
    log.townAudit[map] = log.townAudit[map] or {}
    log.townAudit[map][name] = { x, y }
end

local function OnAuditEvent()
    local name = UnitName("npc")
    local map = C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    if not (name and pos) then return end
    local x, y = pos:GetXY()
    x, y = Tenths(x), Tenths(y)
    Record(map, name, x, y)
    for _, npc in ipairs(ns.TownNPCs[map] or EMPTY) do
        if npc[4] == name then
            ns.Print(TEXT_AUDIT_NEAR:format(name, x, y, npc[1], npc[2], math.sqrt((x - npc[1]) ^ 2 + (y - npc[2]) ^ 2)))
            return
        end
    end
    ns.Print(TEXT_AUDIT_MISSING:format(name, x, y, map))
end

function ns.TownAudit()
    auditing = not auditing
    for _, event in ipairs(AUDIT_EVENTS) do
        if auditing then audit:RegisterEvent(event) else audit:UnregisterEvent(event) end
    end
    local count = 0
    for _, names in pairs(ns.AccountSettings().townAudit or EMPTY) do
        for _ in pairs(names) do count = count + 1 end
    end
    ns.Print(TEXT_AUDIT:format(auditing and TEXT_AUDIT_ON or TEXT_AUDIT_OFF, count))
end

local function AddSectionRows(rows, section, titled)
    if titled and section.title then rows[#rows + 1] = ns.Shared.Settings.Group(section.title) end
    for _, row in ipairs(section.rows) do
        row.lent = row.store ~= S
        rows[#rows + 1] = row
    end
end

local function PinCardRows()
    local rows = {
        ns.Shared.Settings.Group(TEXT_TOWN),
        { key = "townPinSize", label = "Town Pin Size", slider = PIN_RANGE, needs = "townMap", why = TEXT_TOWN_OFF },
    }
    for _, section in ipairs(ns.Shared.MapPinSections()) do
        if not section.map and not (section.hidden and section.hidden()) then AddSectionRows(rows, section, true) end
    end
    return rows
end

local function MapCardRows()
    local rows = {}
    for _, section in ipairs(ns.Shared.MapPinSections()) do
        if section.map then AddSectionRows(rows, section, false) end
    end
    return rows
end

local function PinSearch()
    local words = { TEXT_PINS_SEARCH }
    for _, row in ipairs(PIN_ROWS) do
        if row.text then words[#words + 1] = row.text:lower() end
    end
    return table.concat(words, " ")
end

local function TownSummary(store)
    if not store.Get("townMap") then return TEXT_TOWN_OFF end
    local shown = 0
    for i = 1, #TOWN_SHOW do
        if store.Get(TOWN_SHOW[i]) then shown = shown + 1 end
    end
    return TEXT_SUMMARY:format(shown, #TOWN_SHOW, store.Get("townCapitalsOnly") and TEXT_CAPITALS or "")
end

mini:SetScript("OnEvent", OnMiniEvent)
audit:SetScript("OnEvent", OnAuditEvent)

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key:find("^town") then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

ns.TownPinRows = PIN_ROWS
ns.TownPinRange = PIN_RANGE
ns.TownPinTexts = { group = TEXT_TOWN, switch = TEXT_TOWN_PINS, tip = TEXT_TOWN_TIP }

local page = ns.Shared.Settings.Page("QoL/Map & Pins", S)

page:Card({
    id = "mapOptions", name = TEXT_MAP_CARD, order = MAP_CARD_ORDER,
    help = TEXT_MAP_HELP,
    rows = MapCardRows,
})

page:Card({
    id = "townMap", name = TEXT_PIN_CARD, order = PIN_CARD_ORDER,
    help = TEXT_PIN_HELP .. TEXT_ON_MAP,
    search = PinSearch(),
    summary = TownSummary,
    rows = PinCardRows,
})

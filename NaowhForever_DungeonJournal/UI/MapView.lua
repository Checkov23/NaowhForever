-- MapView.lua: a dungeon's map drawn into a frame: its art, its bosses' pins, the entrance and the floor switch (J.DungeonMap).
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local C = J.C
local St = J.Style
local PIN, FLOOR_H, TEXT_SIZE = St.MAP_PIN, St.MAP_FLOOR_H, St.TEXT_SIZE
local MAP_W, MAP_H, ART = C.MAP_W, C.MAP_H, C.MAP_ART

local TILE = 256
local TILES, TILES_ACROSS = 12, 4
local IMAGE_BOTTOM = 683 / 1024
local BADGE = 20
local BADGE_IN = 6
local BADGE_SIZE = 11
local BADGE_TICK = 14
local BADGE_ALPHA = 0.9
local BIG_SIZE = 18
local DOOR_SIZE = 16
local LIT_RING, LIT_ALPHA = 12, 0.9
local ENTRANCE = 28
local MAP_EDGE = 8
local TRAY_STEP = PIN + 10
local TRAY_ROW = math.floor((MAP_W - MAP_EDGE * 2) / TRAY_STEP)
local FLOOR_STEP_W = 22
local FLOOR_GAP = 8
local STEP_SHRINK = 2
local LABEL_GAP = 4
local LABEL_CLEAR = 8
local LABEL_SIDES = { "RIGHT", "LEFT", "BELOW", "ABOVE" }
local LABEL_ANCHOR = {
    RIGHT = { "LEFT", "RIGHT", LABEL_GAP, 0 }, LEFT = { "RIGHT", "LEFT", -LABEL_GAP, 0 },
    BELOW = { "TOP", "BOTTOM", 0, -LABEL_GAP }, ABOVE = { "BOTTOM", "TOP", 0, LABEL_GAP },
}
local KILLED_ALPHA = 0.45
local UNPLACED_ALPHA = 0.7
local PICKED_RING = 8
local PICKED_GLOW = 24
local GLOW_LOW, GLOW_HIGH, GLOW_PULSE = 0.15, 0.55, 0.9
local HALO_LEVEL, GLOW_LEVEL, GOLD_LEVEL = -3, -2, -1
local PLACE_ROUND = 1000
local ROUND_HALF = C.ROUND_HALF
local ENTRANCE_KEY = "entrance"
local TAG_SHORT = { RARE = "R", OPTIONAL = "O", QUEST = "Q" }
local TAG_WORDS = { RARE = ns.L("Rare"), OPTIONAL = ns.L("Optional"), QUEST = ns.L("Quest boss"), CHEST = ns.L("Chest") }
local MASK = ns.MEDIA .. "circle_mask.tga"
local MASK_WRAP = "CLAMPTOBLACKADDITIVE"

local TEXT_ENTRANCE = ns.L("Entrance")
local TEXT_CLICK_LOOT = ns.L("Click for its loot.")
local TEXT_ELSEWHERE = ns.L("On %s: drag it here to move it.")
local TEXT_MOVE = ns.L("Drag to move it, right-click to take it off.")
local TEXT_PLACE = ns.L("Drag to place it.")
local TEXT_FLOOR = ns.L("Floor %d")
local TEXT_DOWN, TEXT_UP = "<", ">"

local Map = { placing = false, TAG_WORDS = TAG_WORDS }
J.DungeonMap = Map

local View = {}
View.__index = View

local sorting, filling

local function Placed(dungeon)
    local all = ns.AccountSettings().journalMapPins
    return type(all) == "table" and all[dungeon.key] or nil
end

local function Spot(dungeon, key)
    local placed = Placed(dungeon)
    local spot = placed and placed[key]
    if type(spot) == "table" then return spot end
    if spot == false then return nil end
    local map = J.Maps[dungeon.key]
    if key == ENTRANCE_KEY then return map.entrance end
    return map.pins[key]
end

local function Keep(dungeon, key, spot)
    local account = ns.AccountSettings()
    account.journalMapPins = account.journalMapPins or {}
    account.journalMapPins[dungeon.key] = account.journalMapPins[dungeon.key] or {}
    account.journalMapPins[dungeon.key][key] = spot
end

local function KeyOf(boss)
    return boss.npc or (boss.chest and -boss.chest) or nil
end

local function EachBoss(dungeon, fn)
    for _, wing in ipairs(dungeon.wings) do
        local number = 0
        for _, boss in ipairs(wing.bosses) do
            local key = KeyOf(boss)
            local ordered = J.Numbered(boss)
            if ordered then number = number + 1 end
            if key then fn(boss, ordered and number or nil, key, wing) end
        end
    end
end

local function PinHint(pin)
    if not pin.view:Placing() then return TEXT_CLICK_LOOT end
    if pin.elsewhere then return TEXT_ELSEWHERE:format(pin.elsewhere) end
    return Spot(pin.view.dungeon, pin.key) and TEXT_MOVE or TEXT_PLACE
end

local function PinEnter(pin)
    local boss = pin.boss
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:SetText(boss.name, 1, 1, 1)
    local tag = J.BossTag(boss)
    if tag then GameTooltip:AddLine(TAG_WORDS[tag], T.muted.r, T.muted.g, T.muted.b) end
    GameTooltip:AddLine(PinHint(pin), T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    GameTooltip:Show()
    if pin.view.onPinHover then pin.view.onPinHover(pin.key, true) end
end

local function PinLeave(pin)
    GameTooltip:Hide()
    if pin.view.onPinHover then pin.view.onPinHover(pin.key, false) end
end

local function PickAgain(view)
    if Map.lootFrom ~= view then return end
    Map.lootFrom = nil
    J.View.CloseBossLoot()
end

local function PickPin(pin)
    local view = pin.view
    if view.onPick then return view.onPick(pin.boss) end
    local again = view.picked == pin.key
    view:Pick(not again and pin.key or nil)
    J.ShowBossBesideMap(not again and pin.boss or nil)
    if again then return PickAgain(view) end
    if not WorldMapFrame:IsMaximized() then return end
    Map.lootFrom = view
    J.View.OpenBossLoot(pin.boss, view.dungeon)
end

local function PinClicked(pin, button)
    if button == "RightButton" and pin.view:Placing() then
        Keep(pin.view.dungeon, pin.key, false)
        GameTooltip:Hide()
        pin.view:Draw()
        return
    end
    if button == "RightButton" then
        if pin.view.onRightClick then pin.view.onRightClick() end
        return
    end
    if pin.view:Placing() then return end
    PickPin(pin)
end

local function Rounded(value)
    return math.floor(value * PLACE_ROUND + ROUND_HALF) / PLACE_ROUND
end

local function DragStop(frame)
    frame:StopMovingOrSizing()
    local view = frame.view
    if not view:Placing() then return end
    local x, y = frame:GetCenter()
    local left, top = view.canvas:GetLeft(), view.canvas:GetTop()
    if x and left then
        x = math.min(1, math.max(0, (x - left) / MAP_W))
        y = math.min(1, math.max(0, (top - y) / MAP_H))
        Keep(view.dungeon, frame.key, { view.floor, Rounded(x), Rounded(y) })
    end
    view:Draw()
end

local function DragStart(frame)
    if frame.view:Placing() then frame:StartMoving() end
end

local function Draggable(frame)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", DragStart)
    frame:SetScript("OnDragStop", DragStop)
end

local function Round(frame, texture)
    local mask = frame:CreateMaskTexture()
    mask:SetAllPoints(texture)
    mask:SetTexture(MASK, MASK_WRAP, MASK_WRAP)
    texture:AddMaskTexture(mask)
end

local function RoundLayer(frame, size, sublevel)
    local texture = frame:CreateTexture(nil, "BACKGROUND", nil, sublevel)
    texture:SetPoint("CENTER")
    texture:SetSize(PIN + size, PIN + size)
    texture:SetColorTexture(1, 1, 1, 1)
    Round(frame, texture)
    texture:Hide()
    return texture
end

local function BuildPulse(frame)
    frame.pulse = frame.halo:CreateAnimationGroup()
    frame.pulse:SetLooping("BOUNCE")
    local fade = frame.pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(GLOW_LOW)
    fade:SetToAlpha(GLOW_HIGH)
    fade:SetDuration(GLOW_PULSE)
    fade:SetSmoothing("IN_OUT")
end

local function BuildFace(frame)
    frame.ring = frame:CreateTexture(nil, "BACKGROUND")
    frame.ring:SetPoint("CENTER")
    Round(frame, frame.ring)
    frame.plate = frame:CreateTexture(nil, "BORDER")
    frame.plate:SetAllPoints()
    frame.plate:SetColorTexture(T.bg.r, T.bg.g, T.bg.b, 1)
    Round(frame, frame.plate)
    frame.face = frame:CreateTexture(nil, "ARTWORK")
    frame.face:SetAllPoints()
    Round(frame, frame.face)
    frame.big = ns.Font(frame, BIG_SIZE, nil, T.fg)
    frame.big:SetPoint("CENTER")
end

local function BuildBadge(frame)
    local badge = CreateFrame("Frame", nil, frame)
    badge:SetSize(BADGE, BADGE)
    badge:SetPoint("CENTER", frame, "BOTTOMRIGHT", -BADGE_IN, BADGE_IN)
    badge.disc = badge:CreateTexture(nil, "ARTWORK")
    badge.disc:SetAllPoints()
    badge.disc:SetColorTexture(0, 0, 0, BADGE_ALPHA)
    Round(badge, badge.disc)
    badge.text = ns.Font(badge, BADGE_SIZE, nil, T.fg)
    badge.text:SetPoint("CENTER")
    badge.tick = badge:CreateTexture(nil, "OVERLAY")
    badge.tick:SetTexture(St.CHECK, nil, nil, "TRILINEAR")
    badge.tick:SetSize(BADGE_TICK, BADGE_TICK)
    badge.tick:SetPoint("CENTER")
    frame.badge = badge
end

local function BuildMark(frame)
    frame.halo = RoundLayer(frame, PICKED_GLOW, HALO_LEVEL)
    frame.halo:SetBlendMode("ADD")
    BuildPulse(frame)
    frame.gold = RoundLayer(frame, PICKED_RING, GOLD_LEVEL)
    frame.glow = RoundLayer(frame, LIT_RING, GLOW_LEVEL)
    frame.glow:SetColorTexture(T.accent.r, T.accent.g, T.accent.b, LIT_ALPHA)
    BuildFace(frame)
    BuildBadge(frame)
end

local function SetFace(mark, boss, killed)
    local face = boss.model and SetPortraitTextureFromCreatureDisplayID
    if boss.chest then
        mark.face:SetTexture(St.CHEST_ICON)
    elseif face then
        SetPortraitTextureFromCreatureDisplayID(mark.face, boss.model)
    end
    local drawn = boss.chest ~= nil or face ~= nil
    mark.face:SetShown(drawn)
    mark.face:SetDesaturated(killed == true)
    mark.big:SetShown(not drawn)
    return drawn
end

local function SetMark(mark, boss, number, ring, killed)
    mark.ring:SetSize(PIN + ring * 2, PIN + ring * 2)
    local edge = number and St.BORDER_RGB or T.muted
    mark.ring:SetColorTexture(edge.r, edge.g, edge.b, 1)
    local drawn = SetFace(mark, boss, killed)
    local tag = J.BossTag(boss)
    local glyph = not boss.chest and tag and TAG_SHORT[tag] or nil
    mark.big:SetText(number or glyph or "")
    mark.badge:SetShown(killed or drawn and (number or glyph) ~= nil)
    mark.badge.tick:SetShown(killed == true)
    mark.badge.text:SetShown(not killed)
    mark.badge.text:SetText(number or glyph or "")
    local color = number and T.fg or T.muted
    mark.badge.text:SetTextColor(color.r, color.g, color.b)
    mark:SetAlpha(killed and KILLED_ALPHA or 1)
end

local function ShowPicked(mark, on, ringOnly)
    mark.gold:SetShown(on)
    mark.halo:SetShown(on and not ringOnly)
    if on then
        local c = ns.ThemeTint("accent", St.PICKED_RGB)
        mark.gold:SetColorTexture(c.r, c.g, c.b, 1)
        mark.halo:SetColorTexture(c.r, c.g, c.b, 1)
    end
    if on and not ringOnly then
        if not mark.pulse:IsPlaying() then mark.pulse:Play() end
    else
        mark.pulse:Stop()
    end
end

local function Walked(map, n)
    if not map.order then return n end
    for i = 1, #map.order do
        if map.order[i] == n then return i end
    end
    return n
end

local function ByWalk(a, b)
    return Walked(sorting, a) < Walked(sorting, b)
end

local function OfferBoss(_, _, key)
    filling:Offer(Spot(filling.dungeon, key))
end

local function FirstFloor(_, _, key)
    local spot = Spot(filling.dungeon, key)
    if not filling.floor and type(spot) == "table" then filling.floor = spot[1] end
end

local function FloorName(map, n)
    return map.names and map.names[n] or TEXT_FLOOR:format(Walked(map, n))
end

local function LabelBox(side, cx, cy, w, h)
    local half = ENTRANCE / 2
    if side == "RIGHT" then return cx + half + LABEL_GAP, cy - h / 2 end
    if side == "LEFT" then return cx - half - LABEL_GAP - w, cy - h / 2 end
    if side == "BELOW" then return cx - w / 2, cy + half + LABEL_GAP end
    return cx - w / 2, cy - half - LABEL_GAP - h
end

local function DrawPinOf(view)
    return function(boss, number, key) view:DrawPin(boss, number, key) end
end

local function Inside(dungeon)
    local here = J.Current()
    if not here then return false end
    for i = 1, #here do
        if here[i] == dungeon then return true end
    end
    return false
end

local function NewTiles(view, canvas)
    view.tiles = {}
    for i = 1, TILES do
        local tile = canvas:CreateTexture(nil, "BACKGROUND")
        tile:SetSize(TILE, TILE)
        tile:SetPoint("TOPLEFT", (i - 1) % TILES_ACROSS * TILE, -math.floor((i - 1) / TILES_ACROSS) * TILE)
        view.tiles[i] = tile
    end
    view.picture = canvas:CreateTexture(nil, "BACKGROUND")
    view.picture:SetAllPoints()
    view.picture:SetTexCoord(0, 1, 0, IMAGE_BOTTOM)
    view.picture:Hide()
end

local function NewDoor(view, canvas)
    local door = CreateFrame("Button", nil, canvas)
    door:SetSize(ENTRANCE, ENTRANCE)
    door.icon = door:CreateTexture(nil, "ARTWORK")
    door.icon:SetAllPoints()
    door.icon:SetAtlas("dungeon")
    door.text = ns.Font(door, DOOR_SIZE, "OUTLINE", T.fg)
    door.text:SetText(TEXT_ENTRANCE)
    door.key, door.view = ENTRANCE_KEY, view
    Draggable(door)
    return door
end

local function NewSwitch(view, holder)
    view.down = ns.Button(holder, TEXT_DOWN, FLOOR_STEP_W, FLOOR_H - STEP_SHRINK, function() view:Step(-1) end)
    view.floorName = ns.Font(holder, TEXT_SIZE, nil, T.fg)
    view.floorName:SetPoint("LEFT", view.down, "RIGHT", FLOOR_GAP, 0)
    view.up = ns.Button(holder, TEXT_UP, FLOOR_STEP_W, FLOOR_H - STEP_SHRINK, function() view:Step(1) end)
    view.up:SetPoint("LEFT", view.floorName, "RIGHT", FLOOR_GAP, 0)
end

function View:NewPin()
    local pin = CreateFrame("Button", nil, self.canvas)
    pin.view = self
    pin:SetSize(PIN, PIN)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    BuildMark(pin)
    pin:SetScript("OnEnter", PinEnter)
    pin:SetScript("OnLeave", PinLeave)
    pin:SetScript("OnClick", PinClicked)
    Draggable(pin)
    return pin
end

function View:Pick(key)
    self.picked = key
    for i = 1, self.used do
        local pin = self.pins[i]
        ShowPicked(pin, key ~= nil and pin.key == key and not self:Placing())
    end
end

function View:Placing()
    return Map.placing and self.editable
end

function View:FloorAt(n)
    for i = 1, #self.floors do
        if self.floors[i] == n then return i end
    end
end

function View:Offer(spot)
    if type(spot) == "table" and not self:FloorAt(spot[1]) then self.floors[#self.floors + 1] = spot[1] end
end

function View:AllFloors()
    local map, floors = J.Maps[self.dungeon.key], self.floors
    if map.floor then
        floors[1] = map.floor
        return
    end
    for n = 1, map.order and #map.order or map.floors do floors[n] = map.order and map.order[n] or n end
end

function View:FillFloors()
    local dungeon, floors = self.dungeon, self.floors
    wipe(floors)
    if not self:Placing() then
        self:Offer(Spot(dungeon, ENTRANCE_KEY))
        filling = self
        EachBoss(dungeon, OfferBoss)
        sorting = J.Maps[dungeon.key]
        table.sort(floors, ByWalk)
    end
    if #floors == 0 then self:AllFloors() end
    if not self:FloorAt(self.floor) then self.floor = floors[1] end
end

function View:Open(dungeon)
    self.dungeon, self.floor, self.picked = dungeon, nil, nil
    filling = self
    EachBoss(dungeon, FirstFloor)
    self:FillFloors()
end

function View:At(frame, x, y)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", self.canvas, "TOPLEFT", x * MAP_W, -y * MAP_H)
end

function View:ToTray(pin)
    self.tray = self.tray + 1
    local row, col = math.floor((self.tray - 1) / TRAY_ROW), (self.tray - 1) % TRAY_ROW
    pin:ClearAllPoints()
    pin:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", col * TRAY_STEP + MAP_EDGE, -MAP_EDGE - row * TRAY_STEP)
    pin:SetAlpha(UNPLACED_ALPHA)
end

function View:DrawPin(boss, number, key)
    local spot = Spot(self.dungeon, key)
    local here = type(spot) == "table" and spot[1] == self.floor
    if not here and not self:Placing() then return end
    self.used = self.used + 1
    local pin = self.pins[self.used] or self:NewPin()
    self.pins[self.used] = pin
    pin.boss, pin.key = boss, key
    local killed = self.inside and J.Kills.ThisRun(boss) or false
    SetMark(pin, boss, number, 1 / self.scale, killed)
    pin.elsewhere = not here and type(spot) == "table" and FloorName(J.Maps[self.dungeon.key], spot[1]) or nil
    pin.glow:Hide()
    ShowPicked(pin, self.picked ~= nil and key == self.picked and not self:Placing())
    pin.atX = here and spot[2] * MAP_W or nil
    pin.atY = here and spot[3] * MAP_H or nil
    if here then self:At(pin, spot[2], spot[3]) else self:ToTray(pin) end
    pin:Show()
end

function View:LabelFree(left, top, w, h)
    if left < 0 or top < 0 or left + w > MAP_W or top + h > MAP_H then return false end
    local reach = PIN / 2 + LABEL_CLEAR
    for i = 1, self.used do
        local pin = self.pins[i]
        local x, y = pin.atX, pin.atY
        if x and left < x + reach and left + w > x - reach and top < y + reach and top + h > y - reach then
            return false
        end
    end
    return true
end

function View:PlaceDoorLabel(cx, cy)
    local text = self.door.text
    local w, h = math.ceil(text:GetStringWidth()), math.ceil(text:GetStringHeight())
    local side
    for i = 1, #LABEL_SIDES do
        local left, top = LabelBox(LABEL_SIDES[i], cx, cy, w, h)
        if self:LabelFree(left, top, w, h) then
            side = LABEL_SIDES[i]
            break
        end
    end
    self.door.side = side
    text:SetShown(side ~= nil)
    if not side then return end
    local anchor = LABEL_ANCHOR[side]
    text:ClearAllPoints()
    text:SetPoint(anchor[1], self.door, anchor[2], anchor[3], anchor[4])
end

function View:DrawArt(map)
    local image = map.images and map.images[self.floor]
    if not image and map.image then image = self.floor > 1 and map.image .. self.floor or map.image end
    self.picture:SetShown(image ~= nil)
    if image then self.picture:SetTexture(image, nil, nil, "TRILINEAR") end
    for i = 1, TILES do
        self.tiles[i]:SetShown(image == nil)
        if not image then self.tiles[i]:SetTexture(ART:format(map.art, map.art, self.floor, i)) end
    end
end

function View:DrawDoor(dungeon)
    local door = Spot(dungeon, ENTRANCE_KEY)
    local here = type(door) == "table" and door[1] == self.floor
    self.door:SetShown(here or self:Placing())
    if here then
        self:At(self.door, door[2], door[3])
        self:PlaceDoorLabel(door[2] * MAP_W, door[3] * MAP_H)
    elseif self:Placing() then
        self.door:ClearAllPoints()
        self.door:SetPoint("TOPRIGHT", self.canvas, "TOPRIGHT", -MAP_EDGE, -MAP_EDGE)
        self:PlaceDoorLabel(MAP_W - MAP_EDGE - ENTRANCE / 2, MAP_EDGE + ENTRANCE / 2)
    end
end

function View:Draw()
    local dungeon = self.dungeon
    if not dungeon then return end
    self.inside = Inside(dungeon)
    local map = J.Maps[dungeon.key]
    self:DrawArt(map)
    for i = 1, self.used do
        self.pins[i]:Hide()
        ShowPicked(self.pins[i], false)
    end
    self.used, self.tray = 0, 0
    self.drawPin = self.drawPin or DrawPinOf(self)
    EachBoss(dungeon, self.drawPin)
    self:DrawDoor(dungeon)
    local several = #self.floors > 1
    self.floorName:SetShown(several)
    self.down:SetShown(several)
    self.up:SetShown(several)
    self.floorName:SetText(FloorName(map, self.floor))
    if self.onDraw then self.onDraw() end
end

function View:Step(by)
    local at = self:FloorAt(self.floor) or 1
    self.floor = self.floors[(at - 1 + by) % #self.floors + 1]
    self:Draw()
end

function Map.ViewHidden(view)
    view:Pick(nil)
    PickAgain(view)
end

function Map.NewView(parent, holder, editable)
    local view = setmetatable({ pins = {}, used = 0, tray = 0, floors = {}, editable = editable }, View)
    local canvas = CreateFrame("Frame", nil, parent)
    canvas:SetSize(MAP_W, MAP_H)
    canvas:SetClipsChildren(true)
    view.canvas = canvas
    NewTiles(view, canvas)
    view.door = NewDoor(view, canvas)
    NewSwitch(view, holder)
    return view
end

function Map.Spot(dungeon, key)
    return Spot(dungeon, key)
end

Map.KeyOf = KeyOf
Map.EachBoss = EachBoss
Map.BuildMark = BuildMark
Map.SetMark = SetMark
Map.ShowPicked = ShowPicked

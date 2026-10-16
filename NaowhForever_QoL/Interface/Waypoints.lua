-- Waypoints.lua: the Waypoint Pin: the game's waypoint in the world, at the edge and in a navigator.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local Parts, St = ns.Shared.Parts, ns.Shared.Style
local SameMap = ns.Shared.Places.SameMap

local MEDIA = ns.MEDIA
local SHAPES = {
    hex = { fill = MEDIA .. "waypoint_hex", ring = MEDIA .. "waypoint_hex_ring" },
    diamond = { fill = MEDIA .. "waypoint_diamond", ring = MEDIA .. "waypoint_diamond_ring" },
    dot = { fill = MEDIA .. "circle_mask", ring = MEDIA .. "circle_ring" },
}
local CHEVRON, CHECK, CROSS = MEDIA .. "chevron", MEDIA .. "check", MEDIA .. "cross"

local PIN, MARK, ARROW = 36, 12, 18
local DOWN_COUNT, DOWN_SIZE, DOWN_GAP = 3, 14, 2
local OBJECTIVE_W, OBJECTIVE_SIZE, OBJECTIVE_MAX = 240, 13, 6
local OBJECTIVE_HEIGHT_MAX = 150
local MARK_LAYER = 2
local FILL_ALPHA = 0.2
local CARD_W, CARD_PAD, CARD_GAP = 180, 8, 8
local NAME_SIZE, NOTE_SIZE, DIST_SIZE, TIME_SIZE, LINE_GAP, TIME_GAP = 14, 11, 18, 11, 3, 8
local CARD_H = 2 * CARD_PAD + NAME_SIZE + LINE_GAP + DIST_SIZE
local CARD_ICON, ICON_GAP, ICON_CROP = NAME_SIZE + LINE_GAP + DIST_SIZE, 8, St.ICON_CROP
local BEAM_W, BEAM_H, BEAM_ALPHA = 2, 80, 0.55
local GROUND_W, GROUND_H = 44, 12
local EDGE_RING, EDGE_BACK, EDGE_NEAR = 0.3, 0.9, 40
local BEHIND = math.rad(30)
local BEHIND_Y, BEHIND_SIZE = 60, 13
local FAR, FAR_SCALE = 400, 0.65
local FADE_FLOOR = 0.25
local RUN_SPEED = 7
local SAMPLE_EVERY, SMOOTH, MIN_CLOSING, MAX_CLOSING = 1, 0.5, 1, 60
local NAV_W, NAV_H, NAV_PAD, NAV_ICON, NAV_ARROW = 320, 40, 10, 20, 14
local STRIP = 2
local NAV_NAME, NAV_SUB, NAV_DIST = 14, 11, 16
local NAV_Y = -70
local NAV_NAME_LIFT, NAV_SUB_GAP, CUE_TEXT_GAP = 2, 1, 2
local ARRIVED_HOLD = ns.WAYPOINT_HOLD
local REACHED, LEAVE_MARGIN = 5, 2
local QUEST_NEAR, QUEST_LEAVE = 40, 55
local CHECK_SHARE = 0.6
local ROUND = ns.QoLConstants.ROUND
local MINUTE = ns.QoLConstants.SECONDS_PER_MINUTE
local PERCENT = ns.QoLConstants.PERCENT
local SAME_SPOT = 0.05
local DOWN = -math.pi / 2
local NO_TIME = -1
local STAGE_H = 190
local SCALE_RANGE, FADE_NEAR_RANGE, ARRIVE_RANGE = St.SCALE_RANGE, { 0, 100, 5 }, { 5, 100, 5 }
local PERCENT_SCALE = St.PERCENT_SCALE
local GAME_PARTS = { "Icon", "Arrow", "DistanceText", "IconBorder" }
local SHAPE_CHOICES = { { hex = "Hex", diamond = "Diamond", dot = "Dot" }, { "hex", "diamond", "dot" } }
local SAMPLE = { name = ns.L("Mage Trainer"), yards = 312, seconds = 45 }
local STATES = {
    { key = "world", label = "On Screen", tip = "The spot ahead of you, 312 yards away." },
    { key = "edge", label = "Off Screen", tip = "The spot off to your right." },
    { key = "arrived", label = "Arrived", tip = "You reached it." },
}

local TEXT_YARDS = ns.L(" yd")
local TEXT_WALK = ns.L("about %d:%02d")
local TEXT_ARRIVED = ns.L("Arrived")
local TEXT_CLEAR = ns.L("Clear the waypoint")
local TEXT_MAP_PIN = ns.L("Map Pin")
local TEXT_QUEST = ns.L("Quest")
local TEXT_CORPSE = ns.L("Your Corpse")
local TEXT_WAYPOINT = ns.L("Waypoint")
local TEXT_NAVIGATOR = "Waypoint Navigator"
local TEXT_BEHIND = ns.L("Behind you")
local TEXT_STOP = ns.L("%s%s%d of %d")
local TEXT_NEXT = ns.L("Next: ")
local TEXT_DONE = ns.L(" done")
local TEXT_NO_NAVIGATION = ns.L("Waypoint Pin needs the game's navigation, which this client does not have.")
local TEXT_PIN = ns.L(" pin")

local function On()
    return S.Get("enabled") and S.Get("waypoints")
end
ns.WaypointPinOn = On

local function Yards(yards)
    return BreakUpLargeNumbers(math.floor(yards + ROUND)) .. TEXT_YARDS
end

local function Walk(seconds)
    seconds = math.floor(seconds + ROUND)
    return TEXT_WALK:format(math.floor(seconds / MINUTE), seconds % MINUTE)
end

local function Whole(n)
    if n >= 0 then return math.floor(n) end
    return math.ceil(n)
end

local function Trilinear(texture, path)
    texture:SetTexture(path, nil, nil, "TRILINEAR")
    return texture
end

local Look = {}

local function Card(parent, width)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(width, CARD_H)
    Parts.HudBackdrop(card)
    return card
end

function Look.NewPin(parent)
    local pin = CreateFrame("Frame", nil, parent)
    pin:SetSize(PIN, PIN)
    pin.fill = pin:CreateTexture(nil, "ARTWORK")
    pin.fill:SetAllPoints()
    pin.ring = pin:CreateTexture(nil, "ARTWORK", nil, 1)
    pin.ring:SetAllPoints()
    pin.mark = Trilinear(pin:CreateTexture(nil, "ARTWORK", nil, MARK_LAYER), St.ROUND)
    pin.mark:SetSize(MARK, MARK)
    pin.mark:SetPoint("CENTER")
    pin.check = Trilinear(pin:CreateTexture(nil, "ARTWORK", nil, MARK_LAYER), CHECK)
    pin.check:SetSize(PIN * CHECK_SHARE, PIN * CHECK_SHARE)
    pin.check:SetPoint("CENTER")
    pin.check:SetVertexColor(T.bg.r, T.bg.g, T.bg.b)
    pin.arrow = Trilinear(pin:CreateTexture(nil, "ARTWORK", nil, MARK_LAYER), CHEVRON)
    pin.arrow:SetSize(ARROW, ARROW)
    pin.arrow:SetPoint("CENTER")
    pin.beam = ns.Solid(pin, "BACKGROUND", T.accent, BEAM_ALPHA)
    pin.beam:SetSize(BEAM_W, BEAM_H)
    pin.beam:SetPoint("TOP", pin, "BOTTOM")
    pin.ground = Trilinear(pin:CreateTexture(nil, "BACKGROUND"), SHAPES.dot.ring)
    pin.ground:SetSize(GROUND_W, GROUND_H)
    pin.ground:SetPoint("CENTER", pin.beam, "BOTTOM")

    local card = Card(pin, CARD_W)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(CARD_ICON, CARD_ICON)
    card.icon:SetPoint("TOPLEFT", CARD_PAD, -CARD_PAD)
    card.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    card.name = Parts.HudText(ns.Font(card, NAME_SIZE))
    card.name:SetJustifyH("CENTER")
    card.name:SetWordWrap(false)
    card.note = Parts.HudText(ns.Font(card, NOTE_SIZE, nil, T.muted))
    card.note:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -LINE_GAP)
    card.note:SetPoint("RIGHT", card.name, "RIGHT")
    card.note:SetJustifyH("CENTER")
    card.note:SetWordWrap(false)
    card.dist = Parts.HudText(ns.Font(card, DIST_SIZE, nil, T.accent))
    card.time = Parts.HudText(ns.Font(card, TIME_SIZE, nil, T.muted))
    card.time:SetPoint("BOTTOMLEFT", card.dist, "BOTTOMRIGHT", TIME_GAP, 0)
    pin.card = card
    return pin
end

local function NewDownArrows(pin)
    pin.down = {}
    for i = 1, DOWN_COUNT do
        local arrow = Trilinear(pin:CreateTexture(nil, "ARTWORK"), CHEVRON)
        arrow:SetSize(DOWN_SIZE, DOWN_SIZE)
        arrow:SetPoint("BOTTOM", pin, "TOP", 0, CARD_GAP + (i - 1) * (DOWN_SIZE + DOWN_GAP))
        arrow:SetRotation(DOWN)
        pin.down[i] = arrow
    end
end

local function NewObjectives(pin)
    local objectives = Card(pin, OBJECTIVE_W)
    objectives.text = Parts.HudText(ns.Font(objectives, OBJECTIVE_SIZE))
    objectives.text:SetPoint("TOPLEFT", CARD_PAD, -CARD_PAD)
    objectives.text:SetPoint("RIGHT", -CARD_PAD, 0)
    objectives.text:SetJustifyH("LEFT")
    objectives.text:SetWordWrap(true)
    objectives:SetClipsChildren(true)
    objectives:Hide()
    pin.objectives = objectives
end

function Look.PaintPin(pin, o)
    local a = T.accent
    local shape = SHAPES[o.shape] or SHAPES.hex
    local arrived, edge = o.mode == "arrived", o.mode == "edge"
    Trilinear(pin.fill, shape.fill):SetVertexColor(a.r, a.g, a.b, arrived and 1 or FILL_ALPHA)
    Trilinear(pin.ring, shape.ring):SetVertexColor(a.r, a.g, a.b, 1)
    pin.mark:SetVertexColor(a.r, a.g, a.b, 1)
    pin.mark:SetShown(o.mode == "world")
    pin.check:SetShown(arrived)
    pin.arrow:SetShown(edge)
    pin.arrow:SetRotation(o.angle or 0)
    pin.beam:SetShown(o.beam and not edge)
    pin.ground:SetShown(o.beam and not edge)
    pin.ground:SetVertexColor(a.r, a.g, a.b, 1)

    local down = o.down and not edge and not arrived
    if down and not pin.down then NewDownArrows(pin) end
    if pin.down then
        for _, arrow in ipairs(pin.down) do
            arrow:SetShown(down)
            arrow:SetVertexColor(a.r, a.g, a.b, 1)
        end
    end
    local card = pin.card
    card.downHeight = down and DOWN_COUNT * (DOWN_SIZE + DOWN_GAP) or 0
    Look.PlaceCard(pin, card, edge, o.angle or 0)
    if o.objectives and not pin.objectives then NewObjectives(pin) end
    local objectives = pin.objectives
    if objectives then objectives:SetShown(o.objectives ~= nil and not edge and not arrived) end
    if o.objectives then
        objectives.text:SetText(o.objectives)
        objectives:SetHeight(math.min(OBJECTIVE_HEIGHT_MAX, objectives.text:GetStringHeight() + CARD_PAD * 2))
        objectives:ClearAllPoints()
        objectives:SetPoint("BOTTOM", o.card and card or pin, "TOP", 0, CARD_GAP + (not o.card and card.downHeight or 0))
    end
    card:SetShown(o.card)
    if not o.card then return end
    card.icon:SetShown(o.icon ~= nil)
    if o.icon then card.icon:SetTexture(o.icon) end
    card.name:ClearAllPoints()
    if o.icon then
        card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", ICON_GAP, 0)
    else
        card.name:SetPoint("TOPLEFT", CARD_PAD, -CARD_PAD)
    end
    card.name:SetPoint("RIGHT", -CARD_PAD, 0)
    card.name:SetText(o.name)
    card.note:SetShown(o.note ~= nil)
    card.note:SetText(o.note or "")
    card:SetHeight(CARD_H + (o.note and NOTE_SIZE + LINE_GAP or 0))
    local walk = o.seconds and not arrived and Walk(o.seconds) or ""
    card.dist:SetText(arrived and TEXT_ARRIVED or Yards(o.yards))
    card.time:SetText(walk)
    local row = card.dist:GetStringWidth() + (walk ~= "" and TIME_GAP + card.time:GetStringWidth() or 0)
    local left = o.icon and CARD_PAD + CARD_ICON + ICON_GAP or CARD_PAD
    card.dist:ClearAllPoints()
    card.dist:SetPoint("TOPLEFT", o.note and card.note or card.name, "BOTTOMLEFT",
        math.floor(math.max(CARD_W - left - CARD_PAD - row, 0) / 2 + ROUND), -LINE_GAP)
    Look.PlaceCard(pin, card, edge, o.angle or 0)
end

function Look.PlaceCard(pin, card, edge, angle)
    card:ClearAllPoints()
    local cos, sin = math.cos(angle), math.sin(angle)
    if not edge then
        card:SetPoint("BOTTOM", pin, "TOP", 0, CARD_GAP + (card.downHeight or 0))
    elseif math.abs(cos) >= math.abs(sin) then
        if cos > 0 then card:SetPoint("RIGHT", pin, "LEFT", -CARD_GAP, 0) else card:SetPoint("LEFT", pin, "RIGHT", CARD_GAP, 0) end
    elseif sin > 0 then
        card:SetPoint("TOP", pin, "BOTTOM", 0, -CARD_GAP)
    else
        card:SetPoint("BOTTOM", pin, "TOP", 0, CARD_GAP)
    end
end

function Look.NewNav(parent, onClear)
    local nav = CreateFrame("Frame", nil, parent)
    nav:SetSize(NAV_W, NAV_H)
    Parts.HudBackdrop(nav)
    local strip = ns.Solid(nav, "ARTWORK", T.accent, 1)
    strip:SetPoint("TOPLEFT")
    strip:SetPoint("TOPRIGHT")
    strip:SetHeight(STRIP)
    nav.fill = nav:CreateTexture(nil, "ARTWORK")
    nav.fill:SetSize(NAV_ICON, NAV_ICON)
    nav.fill:SetPoint("LEFT", NAV_PAD, 0)
    nav.ring = nav:CreateTexture(nil, "ARTWORK", nil, 1)
    nav.ring:SetAllPoints(nav.fill)
    nav.icon = nav:CreateTexture(nil, "ARTWORK")
    nav.icon:SetAllPoints(nav.fill)
    nav.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    nav.clear = Parts.IconButton(nav, onClear, CROSS, 0, TEXT_CLEAR)
    nav.clear:SetPoint("RIGHT", -NAV_PAD / 2, 0)
    nav.dist = Parts.HudText(ns.Font(nav, NAV_DIST, nil, T.accent))
    nav.dist:SetPoint("RIGHT", nav.clear, "LEFT", -NAV_PAD / 2, 0)
    nav.arrow = Trilinear(nav:CreateTexture(nil, "ARTWORK"), CHEVRON)
    nav.arrow:SetSize(NAV_ARROW, NAV_ARROW)
    nav.arrow:SetPoint("RIGHT", nav.dist, "LEFT", -NAV_PAD / 2, 0)
    nav.name = Parts.HudText(ns.Font(nav, NAV_NAME))
    nav.name:SetPoint("TOPLEFT", nav.fill, "TOPRIGHT", NAV_PAD, NAV_NAME_LIFT)
    nav.name:SetPoint("RIGHT", nav.arrow, "LEFT", -NAV_PAD / 2, 0)
    nav.name:SetJustifyH("LEFT")
    nav.name:SetWordWrap(false)
    nav.sub = Parts.HudText(ns.Font(nav, NAV_SUB, nil, T.muted))
    nav.sub:SetPoint("TOPLEFT", nav.name, "BOTTOMLEFT", 0, -NAV_SUB_GAP)
    nav.sub:SetPoint("RIGHT", nav.name, "RIGHT")
    nav.sub:SetJustifyH("LEFT")
    nav.sub:SetWordWrap(false)
    return nav
end

function Look.PaintNav(nav, o)
    local a = T.accent
    local shape = SHAPES[o.shape] or SHAPES.hex
    Trilinear(nav.fill, shape.fill):SetVertexColor(a.r, a.g, a.b, FILL_ALPHA)
    Trilinear(nav.ring, shape.ring):SetVertexColor(a.r, a.g, a.b, 1)
    nav.fill:SetShown(o.icon == nil)
    nav.ring:SetShown(o.icon == nil)
    nav.icon:SetShown(o.icon ~= nil)
    if o.icon then nav.icon:SetTexture(o.icon) end
    nav.name:SetText(o.name)
    nav.sub:SetText(o.sub or "")
    nav.arrow:SetShown(o.mode ~= "arrived" and o.angle ~= nil)
    nav.arrow:SetRotation(o.angle or 0)
    nav.dist:SetText(o.mode == "arrived" and TEXT_ARRIVED or Yards(o.yards))
end

local pin, nav, cue, driver, navFrame, unlocked, gameHidden, warned
local arrived, arrivals = false, 0
local Arrived
local selfCleared, seenAway, seenFar
local mapHooked, trackOnMapClose
local reached
local lastX, lastY
local outside = false
local shown = {}
local dirty = true
local paintedMode, paintedSide, paintedYards, paintedSeconds
local knownSpeed = 0
local sampleYards, sampleAt, closing
local NavSample = { name = ns.L("Mage Trainer"), sub = "Thunder Bluff", yards = 312, mode = "world", angle = math.pi / 2 }
local events = CreateFrame("Frame")

local function NoteText(note)
    if not note then return nil end
    local text = note:match("^%s*%((.-)%)%s*$") or note:match("^%s*(.-)%s*$")
    if text == "" then return nil end
    return text:sub(1, 1):upper() .. text:sub(2)
end

local function IsPlaced(placed, point)
    return placed and point and placed.map == point.uiMapID
        and math.abs(placed.x - point.position.x * PERCENT) < SAME_SPOT
        and math.abs(placed.y - point.position.y * PERCENT) < SAME_SPOT
end

local function UserTarget()
    local point, placed = C_Map.GetUserWaypoint(), ns.placedWaypoint
    local info = point and C_Map.GetMapInfo(point.uiMapID)
    local where = info and info.name
    if IsPlaced(placed, point) then
        return placed.details and placed.details.title or placed.title, where, NoteText(placed.note), placed.icon, true, placed.details
    end
    return TEXT_MAP_PIN, where
end

local function Target(kind)
    local types = Enum.SuperTrackingType
    if kind == types.UserWaypoint then
        return UserTarget()
    elseif kind == types.Quest then
        return C_QuestLog.GetTitleForQuestID(C_SuperTrack.GetSuperTrackedQuestID()) or TEXT_QUEST
    elseif kind == types.Corpse then
        return TEXT_CORPSE
    end
    return TEXT_WAYPOINT
end

local function SaveNavPos(pos)
    S.Set("waypointNavPos", { point = pos.point, relPoint = pos.relPoint, x = pos.x, y = pos.y })
end

local function Build()
    pin = Look.NewPin(UIParent)
    pin:SetFrameStrata("LOW")
    pin:Hide()
    nav = Look.NewNav(UIParent, ns.ClearWaypoint)
    nav:SetFrameStrata("MEDIUM")
    nav:SetClampedToScreen(true)
    nav.mover = ns.UI.AttachMover(nav, TEXT_NAVIGATOR, SaveNavPos, "QoL/Interface", "QoL/Interface:waypoints")
    nav:Hide()
    cue = CreateFrame("Frame", nil, UIParent)
    cue:SetSize(NAV_W, BEHIND_Y)
    cue:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, BEHIND_Y)
    cue.arrow = Trilinear(cue:CreateTexture(nil, "ARTWORK"), CHEVRON)
    cue.arrow:SetSize(ARROW, ARROW)
    cue.arrow:SetPoint("TOP")
    cue.arrow:SetRotation(DOWN)
    cue.arrow:SetVertexColor(T.accent.r, T.accent.g, T.accent.b)
    cue.text = Parts.HudText(ns.Font(cue, BEHIND_SIZE))
    cue.text:SetPoint("TOP", cue.arrow, "BOTTOM", 0, -CUE_TEXT_GAP)
    cue.text:SetText(TEXT_BEHIND)
    cue:Hide()
    driver = CreateFrame("Frame")
end

local function PlaceNav()
    local pos = S.Get("waypointNavPos")
    nav:ClearAllPoints()
    if pos then
        nav:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        nav:SetPoint("TOP", UIParent, "TOP", 0, NAV_Y)
    end
end

local function SizePin(mode, yards)
    local scale = S.Get("waypointScale")
    local near = S.Get("waypointFadeNear")
    local alpha = 1
    if mode == "world" then
        scale = scale * (1 - (1 - FAR_SCALE) * math.min(yards / FAR, 1))
        if near > 0 and yards < near then alpha = FADE_FLOOR + (1 - FADE_FLOOR) * yards / near end
    end
    pin:SetScale(scale)
    pin:SetAlpha(alpha)
    return scale
end

local function PlaceAtEdge(cx, cy, dx, dy, scale, ring)
    local t = ring > 0 and 1 / ring or 0
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", UIParent, "CENTER", dx * t / scale, dy * t / scale)
    pin.onNav = false
    lastX, lastY = cx + dx * t, cy + dy * t
    return math.abs(dx) >= math.abs(dy) and (dx > 0 and "right" or "left") or (dy > 0 and "top" or "bottom")
end

local function PlaceOnSpot(nx, ny, scale)
    local lift = shown.beam and PIN / 2 + BEAM_H or 0
    if not pin.onNav then
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", navFrame, "CENTER", 0, lift)
        pin.onNav = true
    end
    lastX, lastY = nx, ny + lift * scale
end

local function OnWaypointMap()
    local point = C_Map.GetUserWaypoint()
    if not point then return false end
    local map = SameMap(C_Map.GetBestMapForUnit("player"))
    while map and map ~= 0 do
        if map == SameMap(point.uiMapID) then return true end
        local info = C_Map.GetMapInfo(map)
        map = info and info.parentMapID
    end
    return false
end

local function CheckReached(yards, near)
    local leave = near + LEAVE_MARGIN
    if shown.quest and shown.objectives then reached = false return end
    if shown.quest then near, leave = QUEST_NEAR, QUEST_LEAVE end
    if shown.ground or yards > leave then
        reached = false
    elseif yards <= near then
        reached = true
    end
end

local function Sample(yards)
    local now = GetTime()
    if sampleAt and now - sampleAt < SAMPLE_EVERY then return end
    if sampleAt then
        local rate = (sampleYards - yards) / (now - sampleAt)
        if rate < MIN_CLOSING or rate > MAX_CLOSING then
            closing = nil
        else
            closing = closing and closing + (rate - closing) * SMOOTH or rate
        end
    end
    sampleYards, sampleAt = yards, now
end

local function WalkSeconds(yards)
    if not S.Get("waypointTime") then return nil end
    Sample(yards)
    if closing then return yards / closing end
    local speed = GetUnitSpeed("player")
    if not (issecretvalue and issecretvalue(speed)) then knownSpeed = speed end
    return yards / (knownSpeed > 0 and knownSpeed or RUN_SPEED)
end

local function Changed(mode, side, yards, seconds)
    local wholeYards, wholeSeconds = Whole(yards + ROUND), Whole((seconds or NO_TIME) + ROUND)
    if not dirty and mode == paintedMode and side == paintedSide and wholeYards == paintedYards
        and wholeSeconds == paintedSeconds then
        return false
    end
    dirty = false
    paintedMode, paintedSide, paintedYards, paintedSeconds = mode, side, wholeYards, wholeSeconds
    return true
end

local function Paint(mode, side, yards, seconds, angle)
    shown.angle = angle
    if Changed(mode, side or "", yards, seconds) then
        shown.yards, shown.seconds, shown.mode = yards, seconds, mode
        Look.PaintPin(pin, shown)
        if nav:IsShown() then Look.PaintNav(nav, shown) end
    else
        pin.arrow:SetRotation(angle)
        nav.arrow:SetRotation(angle)
    end
end

local function Update()
    if not C_Navigation.HasValidScreenPosition() then
        pin:Hide()
        cue:Hide()
        return
    end
    local yards = C_Navigation.GetDistance()
    local cx, cy = UIParent:GetCenter()
    local nx, ny = navFrame:GetCenter()
    local dx, dy = nx - cx, ny - cy
    local angle = math.atan2(dy, dx)
    local ring = math.sqrt((dx / (UIParent:GetWidth() * EDGE_RING)) ^ 2 + (dy / (UIParent:GetHeight() * EDGE_RING)) ^ 2)
    local clamped, edgeOn = C_Navigation.WasClampedToScreen(), S.Get("waypointEdge")
    outside = edgeOn and yards > EDGE_NEAR and ring > (outside and EDGE_BACK or 1)
    local mode = (clamped or outside) and "edge" or "world"
    local behind = clamped and math.abs(angle - DOWN) < BEHIND
    local scale = SizePin(mode, yards)
    local side
    if mode == "edge" then
        side = PlaceAtEdge(cx, cy, dx, dy, scale, ring)
    else
        PlaceOnSpot(nx, ny, scale)
    end
    local near = S.Get("waypointArrive")
    CheckReached(yards, near)
    if yards > REACHED + LEAVE_MARGIN then seenAway = true end
    if yards > near + LEAVE_MARGIN then seenFar = true end
    local reach = seenFar and near or REACHED
    if shown.user and not shown.guide and not shown.onRoute and not selfCleared and seenAway and yards <= reach and OnWaypointMap() then
        selfCleared = true
        Arrived()
        ns.ClearWaypoint()
        return
    end
    pin:SetShown(not (behind or reached) and (mode ~= "edge" or edgeOn))
    cue:SetShown(behind and not reached and edgeOn)
    Paint(mode, side, yards, WalkSeconds(yards), angle)
end

local objectiveLines = {}

local function Objectives(quest, details)
    if not S.Get("waypointObjectives") then return end
    if issecretvalue and issecretvalue(quest) then return end
    if quest and C_QuestLog.GetQuestObjectives then
        local list = C_QuestLog.GetQuestObjectives(quest)
        if list and not (issecrettable and issecrettable(list)) and #list > 0 then
            wipe(objectiveLines)
            for _, objective in ipairs(list) do
                if not (issecrettable and issecrettable(objective)) then
                    local text, finished = objective.text, objective.finished
                    if not (issecretvalue and (issecretvalue(text) or issecretvalue(finished)))
                        and not finished and type(text) == "string" and text ~= "" then
                        objectiveLines[#objectiveLines + 1] = text
                        if #objectiveLines == OBJECTIVE_MAX then break end
                    end
                end
            end
            return #objectiveLines > 0 and table.concat(objectiveLines, "\n") or nil
        end
    end
    return details and details.objectives
end

local function Retitle()
    dirty = true
    sampleAt, closing = nil, nil
    local where, placed, details
    local kind, types = C_SuperTrack.GetHighestPrioritySuperTrackingType(), Enum.SuperTrackingType
    shown.name, where, shown.note, shown.icon, placed, details = Target(kind)
    local quest = kind == types.Quest and C_SuperTrack.GetSuperTrackedQuestID() or details and details.quest
    shown.objectives = Objectives(quest, details)
    shown.down = S.Get("waypointDownArrows")
    shown.sub = shown.note and where and (shown.note .. St.PLACE_DOT .. where) or shown.note or where
    local route, at, n = ns.WaypointRoute()
    shown.onRoute = placed and route ~= nil
    if shown.onRoute then shown.sub = TEXT_STOP:format(route, St.PLACE_DOT, at, n) end
    shown.shape = S.Get("waypointShape")
    shown.user = kind == types.UserWaypoint
    shown.quest = kind == types.Quest
    shown.guide = details and details.guide == true
    shown.ground = shown.user or kind == types.Corpse
    shown.card, shown.beam = S.Get("waypointCard"), S.Get("waypointBeam") and shown.ground
    pin.onNav, reached = false, false
end

function ns.RefreshWaypointPin()
    if On() and navFrame and not arrived then Retitle() end
end

local function Detach()
    navFrame, selfCleared = nil, false
    if not driver then return end
    driver:SetScript("OnUpdate", nil)
    if arrived then return end
    pin:Hide()
    cue:Hide()
    if unlocked and On() then
        PlaceNav()
        Look.PaintNav(nav, NavSample)
        nav:Show()
    else
        nav:Hide()
    end
end

local function Attach()
    if arrived then
        arrived = false
        arrivals = arrivals + 1
    end
    navFrame = C_Navigation.GetFrame()
    if not navFrame then Detach() return end
    if not driver then Build() end
    seenAway, seenFar = false, false
    PlaceNav()
    Retitle()
    lastX, lastY = nil, nil
    nav:SetShown(S.Get("waypointNav") or unlocked)
    driver:SetScript("OnUpdate", Update)
    Update()
end

local function OnArrivalOver(this)
    if this ~= arrivals then return end
    arrived = false
    if navFrame then Attach() else Detach() end
end

function Arrived()
    if not driver then return end
    if shown.user and not shown.onRoute then
        driver:SetScript("OnUpdate", nil)
        pin:Hide()
        cue:Hide()
        nav:Hide()
        ns.UI._PlayLSMSound(ns.UI.SoundPathFor(S.Get("waypointSound")))
        return
    end
    if not lastX then return end
    arrived = true
    arrivals = arrivals + 1
    local this = arrivals
    driver:SetScript("OnUpdate", nil)
    local scale = S.Get("waypointScale")
    pin:SetScale(scale)
    pin:SetAlpha(1)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", UIParent, "BOTTOMLEFT", lastX / scale, lastY / scale)
    pin.onNav = false
    shown.mode = "arrived"
    if shown.onRoute then
        local route, _, _, nextTitle = ns.WaypointRoute()
        shown.note = nextTitle and (TEXT_NEXT .. nextTitle) or (route .. TEXT_DONE)
        shown.sub = shown.note
    end
    Look.PaintPin(pin, shown)
    pin:Show()
    cue:Hide()
    if S.Get("waypointNav") then
        Look.PaintNav(nav, shown)
        nav:Show()
    end
    ns.UI._PlayLSMSound(ns.UI.SoundPathFor(S.Get("waypointSound")))
    C_Timer.After(ARRIVED_HOLD, function() OnArrivalOver(this) end)
end

local function TrackPlaced()
    trackOnMapClose = false
    if C_Map.HasUserWaypoint() and not C_SuperTrack.IsSuperTrackingUserWaypoint() then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
end

local function OnMapHide()
    if trackOnMapClose then TrackPlaced() end
end

local function WatchPlaced()
    if not C_Map.HasUserWaypoint() then return end
    if WorldMapFrame and WorldMapFrame:IsVisible() then
        if not mapHooked then
            WorldMapFrame:HookScript("OnHide", OnMapHide)
            mapHooked = true
        end
        trackOnMapClose = true
    else
        C_Timer.After(0, TrackPlaced)
    end
end

local function OnEvent(_, event, isWaypoint)
    if event == "USER_WAYPOINT_UPDATED" then
        seenAway, seenFar = false, false
        WatchPlaced()
    end
    if event == "NAVIGATION_FRAME_CREATED" then
        Attach()
    elseif event == "NAVIGATION_FRAME_DESTROYED" then
        Detach()
    elseif event == "NAVIGATION_DESTINATION_REACHED" then
        if not isWaypoint and not shown.guide and not (shown.quest and shown.objectives) then Arrived() end
    elseif not C_SuperTrack.GetHighestPrioritySuperTrackingType() then
        if navFrame then Detach() end
    elseif not navFrame then
        if C_Navigation.GetFrame() then Attach() end
    elseif not arrived then
        selfCleared = false
        Retitle()
    end
end

local function FadeGameMarker()
    local hide = (On() and S.Get("waypointHideGame")) == true
    if hide == gameHidden or not SuperTrackedFrame then return end
    gameHidden = hide
    for _, key in ipairs(GAME_PARTS) do SuperTrackedFrame[key]:SetAlpha(hide and 0 or 1) end
end

local function Apply()
    FadeGameMarker()
    if not On() then
        events:UnregisterAllEvents()
        arrived = false
        arrivals = arrivals + 1
        Detach()
        return
    end
    if not C_Navigation then
        if not warned then ns.Print(TEXT_NO_NAVIGATION) end
        warned = true
        return
    end
    events:RegisterEvent("NAVIGATION_FRAME_CREATED")
    events:RegisterEvent("NAVIGATION_FRAME_DESTROYED")
    events:RegisterEvent("NAVIGATION_DESTINATION_REACHED")
    events:RegisterEvent("SUPER_TRACKING_CHANGED")
    events:RegisterEvent("USER_WAYPOINT_UPDATED")
    if S.Get("waypointObjectives") then
        events:RegisterEvent("QUEST_LOG_UPDATE")
    else
        events:UnregisterEvent("QUEST_LOG_UPDATE")
    end
    if not driver then Build() end
    if C_Navigation.GetFrame() then Attach() else Detach() end
    if unlocked then nav.mover:Show() end
end

events:SetScript("OnEvent", OnEvent)

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or (type(key) == "string" and key:find("^waypoint") and key ~= "waypointNavPos") then
        Apply()
    end
end)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = On() == true
    if unlocked and not driver then Build() end
    Apply()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    if nav then
        nav.mover:Hide()
        Apply()
    end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.pin = Look.NewPin(preview)
    return preview
end

local function PaintPreview(preview, state)
    local o = preview.o or {}
    preview.o = o
    o.name, o.yards = SAMPLE.name, SAMPLE.yards
    o.seconds = S.Get("waypointTime") and SAMPLE.seconds or nil
    o.shape, o.card, o.beam = S.Get("waypointShape"), S.Get("waypointCard"), S.Get("waypointBeam")
    o.mode, o.angle = state, 0
    o.down = S.Get("waypointDownArrows")
    o.objectives = S.Get("waypointObjectives") and ns.L("0/10 Highlands Bandit slain\n0/1 Badwind Bennic slain") or nil
    local sample = preview.pin
    sample:SetScale(S.Get("waypointScale"))
    sample:ClearAllPoints()
    if state == "edge" then
        sample:SetPoint("RIGHT", preview, "RIGHT", -PIN, 0)
    else
        sample:SetPoint("CENTER", preview, "CENTER", 0, -CARD_H / 2)
    end
    Look.PaintPin(sample, o)
end

local function Summary(store)
    return SHAPE_CHOICES[1][store.Get("waypointShape")] .. TEXT_PIN
end

Settings.Page("QoL/Interface", S):Card({
    id = "waypoints", name = "Waypoint Pin", order = 42, switch = "waypoints",
    help = "Marks the spot you are heading to in the world, with its distance. A waypoint you place on the map is tracked for you.",
    summary = Summary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        { key = "waypointRestedXP", label = "Follow RestedXP", toggle = true,
          help = "Uses your active RestedXP guide destination for the world pin." },
        { key = "waypointObjectives", label = "Quest Objectives", toggle = true,
          help = "Shows unfinished quest objectives above the destination." },
        { key = "waypointDownArrows", label = "Downward Arrows", toggle = true,
          help = "Adds three downward arrows pointing to the destination pin." },
        { key = "waypointShape", label = "Pin Shape", choice = SHAPE_CHOICES },
        { key = "waypointScale", label = "Pin Size", slider = SCALE_RANGE, unit = "%", scale = PERCENT_SCALE },
        { key = "waypointCard", label = "Name and Distance", toggle = true,
          help = "A card over the pin with what it is and how far." },
        { key = "waypointTime", label = "Walking Time", toggle = true, needs = "waypointCard",
          help = "How long it takes to get there at your speed." },
        { key = "waypointBeam", label = "Line to the Ground", toggle = true,
          help = "A line from the pin down to a map pin's or corpse's spot." },
        { key = "waypointFadeNear", label = "Fade Up Close", slider = FADE_NEAR_RANGE, unit = "yd",
          help = "Fades the pin as you get this close, so it does not cover what you came for." },
        { key = "waypointArrive", label = "Arrival Distance", slider = ARRIVE_RANGE, unit = "yd",
          help = "How close counts as there: a map waypoint clears." },
        { key = "waypointEdge", label = "Edge Arrow Off Screen", toggle = true,
          help = "Keeps the pin near the middle of the screen, pointing the way, when the spot is off screen or far to one side." },
        { key = "waypointNav", label = "Navigator Bar", toggle = true,
          help = "A bar with the name, a turn arrow and the distance, while a waypoint is set." },
        { key = "waypointSound", label = "Arrival Sound", sound = true },
        { key = "waypointHideGame", label = "Hide the Game's Marker", toggle = true,
          help = "Hides the game's own marker so only the pin shows." },
    },
})

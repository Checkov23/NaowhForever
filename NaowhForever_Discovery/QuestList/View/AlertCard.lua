-- AlertCard.lua: the Rare Alert's card, live or in its settings preview: portrait, name and a line (Completo.AlertCard).
local ns = _G.NaowhForever

local T = ns.THEME
local Completo = ns.Completo
local S = Completo.Settings
local Parts = ns.Shared.Parts
local Style = Completo.Style
local R = Completo.Rares

local W, H, ICON, PAD = 300, 54, 38, 8
local NAME_SIZE, DETAIL_SIZE = 13, 11
local DETAIL_SMALLER = 2
local PIN_ROOM = 20
local NAME_PADS = 3
local PIN_INSET = 2
local TEXT_NUDGE = 2
local GLOW, GLOW_ALPHA = 3, 0.35
local STAR_SHARE = 0.6
local PORTRAIT_ZOOM = 1
local MODEL_EDGE = 1
local STAR_ATLAS = Style.STAR_ATLAS
local DOT = "  \194\183  "
local TEXT_WAYPOINT = ns.L("Waypoint")
local TEXT_PIN_HINT = ns.L("To the rare: where it was seen, else its nearest spot.")
local TEXT_TAPPED = ns.L("Tapped by someone else")
local TEXT_NOT_KILLED = ns.L("Not killed yet")
local TEXT_KILLED_TIMES = ns.L("Killed %d times")
local TEXT_KILLED_BEFORE = ns.L("Killed before")
local TEXT_LEVEL = ns.L("Level %d")
local TEXT_RARE = ns.L("Rare")
local TEXT_ELITE = ns.L("Rare elite")

local parts = {}

local Card = { W = W, H = H, GLOW = GLOW }
Completo.AlertCard = Card

local function Zoom(model)
    model:SetPortraitZoom(PORTRAIT_ZOOM)
end

local function PinClicked(button)
    local card = button:GetParent()
    local spot = card.spot
    if spot.map then ns.PlaceWaypoint(card.name:GetText(), spot.map, spot.x, spot.y) end
end

local function GlowSide(glow, c)
    return ns.Solid(glow, "BACKGROUND", c, GLOW_ALPHA)
end

local function NewGlow(f)
    local glow = CreateFrame("Frame", nil, f)
    glow:SetPoint("TOPLEFT", -GLOW, GLOW)
    glow:SetPoint("BOTTOMRIGHT", GLOW, -GLOW)
    local c = T.accent
    local top = GlowSide(glow, c)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(GLOW)
    local bottom = GlowSide(glow, c)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(GLOW)
    local left = GlowSide(glow, c)
    left:SetPoint("TOPLEFT", 0, -GLOW)
    left:SetPoint("BOTTOMLEFT", 0, GLOW)
    left:SetWidth(GLOW)
    local right = GlowSide(glow, c)
    right:SetPoint("TOPRIGHT", 0, -GLOW)
    right:SetPoint("BOTTOMRIGHT", 0, GLOW)
    right:SetWidth(GLOW)
    glow.sides = { top, bottom, left, right }
    return glow
end

local function NewPortrait(f)
    local black = Style.BLACK_RGB
    local icon = CreateFrame("Frame", nil, f)
    icon:SetSize(ICON, ICON)
    icon:SetPoint("LEFT", PAD, 0)
    ns.Solid(icon, "BACKGROUND", black, 1):SetAllPoints()
    ns.Border(icon, black)
    f.model = CreateFrame("PlayerModel", nil, icon)
    f.model:SetPoint("TOPLEFT", MODEL_EDGE, -MODEL_EDGE)
    f.model:SetPoint("BOTTOMRIGHT", -MODEL_EDGE, MODEL_EDGE)
    f.model:SetScript("OnModelLoaded", Zoom)
    f.star = icon:CreateTexture(nil, "ARTWORK")
    f.star:SetPoint("CENTER")
    f.star:SetSize(ICON * STAR_SHARE, ICON * STAR_SHARE)
    f.star:SetAtlas(STAR_ATLAS)
    f.icon = icon
    return icon
end

local function NewText(f, icon)
    f.name = ns.Font(f, NAME_SIZE, nil, T.fg)
    f.name:SetPoint("TOPLEFT", icon, "TOPRIGHT", PAD, -TEXT_NUDGE)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.detail = ns.Font(f, DETAIL_SIZE, nil, T.muted)
    f.detail:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", PAD, TEXT_NUDGE)
    f.detail:SetPoint("RIGHT", -PAD, 0)
    f.detail:SetJustifyH("LEFT")
    f.detail:SetWordWrap(false)
end

local function KillNote(record)
    if record == nil then return nil end
    if not record then return TEXT_NOT_KILLED end
    if record.n > 1 then return ns.Color(Style.HAVE_RGB, TEXT_KILLED_TIMES:format(record.n)) end
    return ns.Color(Style.HAVE_RGB, TEXT_KILLED_BEFORE)
end

local function Detail(seen)
    wipe(parts)
    if seen.level and seen.level > 0 then parts[#parts + 1] = TEXT_LEVEL:format(seen.level) end
    parts[#parts + 1] = seen.elite and TEXT_ELITE or TEXT_RARE
    local note = seen.tapped and ns.Color(Style.WARN_RGB, TEXT_TAPPED) or KillNote(seen.record)
    if note then parts[#parts + 1] = note end
    return table.concat(parts, DOT)
end

local function PaintLook(f)
    local mode = f.backdrop:SetMode(S.Get("rareAlertBackground"))
    local font, size, outline = S.Get("rareAlertFont"), S.Get("rareAlertFontSize"), S.Get("rareAlertOutline")
    Parts.HudFont(f.name, font, size, outline, mode)
    Parts.HudFont(f.detail, font, size - DETAIL_SMALLER, outline, mode)
    local glow = S.Get("rareAlertGlow") == true
    f.glow:SetShown(glow)
    if not glow then return end
    local c = T.accent
    for _, side in ipairs(f.glow.sides) do side:SetColorTexture(c.r, c.g, c.b, GLOW_ALPHA) end
end

local function PaintName(f, seen)
    local room = W - PAD * NAME_PADS - ICON - PIN_ROOM
    f.name:SetWidth(0)
    f.name:SetText(seen.name)
    f.name:SetWidth(math.min(f.name:GetStringWidth() + 1, room))
end

local function PaintSpot(f, seen)
    local spot = f.spot
    spot.map, spot.x, spot.y = seen.map, seen.x, seen.y
    if not spot.map and seen.npc and R.Known(seen.npc) then spot.map, spot.x, spot.y = R.Spot(seen.npc) end
    f.pin:SetShown(spot.map ~= nil)
end

function Card.New(parent, name)
    local f = CreateFrame("Button", name, parent)
    f:SetSize(W, H)
    f.glow = NewGlow(f)
    f.backdrop = Parts.HudBackdrop(f)
    f.spot = {}
    local icon = NewPortrait(f)
    f.pin = Parts.IconButton(f, PinClicked, Style.PIN, 0, TEXT_WAYPOINT)
    f.pin.hint = TEXT_PIN_HINT
    f.pin:SetPoint("TOPRIGHT", -PAD + PIN_INSET, -PAD + PIN_INSET)
    NewText(f, icon)
    return f
end

function Card.SetPortrait(f, unit, npc)
    local model = f.model
    model:ClearModel()
    local shown = false
    if unit and UnitExists(unit) then
        model:SetUnit(unit)
        shown = true
    elseif npc then
        model:SetCreature(npc)
        shown = true
    end
    model:SetShown(shown)
    if shown then Zoom(model) end
    f.star:SetShown(not shown)
end

function Card.Paint(f, seen)
    PaintLook(f)
    PaintName(f, seen)
    f.detail:SetText(Detail(seen))
    PaintSpot(f, seen)
end

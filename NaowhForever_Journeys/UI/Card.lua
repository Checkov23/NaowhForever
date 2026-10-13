-- Card.lua: the Journey card: the journey you are on, a line a step with the time each takes.
local ns = _G.NaowhForever

local T = ns.THEME
local Jy = ns.Journeys
local S = Jy.Settings
local Guide = Jy.Guide
local Parts = ns.Shared.Parts
local St = ns.Shared.Style

local MEDIA = "Interface\\AddOns\\NaowhForever_Journeys\\Media\\"
local COG = ns.UI.COGS_ICON
local CROSS = ns.MEDIA .. "cross"
local SETTINGS_PAGE = "Journeys/Settings"
local PLACE = { "RIGHT", "RIGHT", -260, 40 }
local MODE_ICON = { walk = "walk", fly = "fly", ship = "ship", tram = "tram", portal = "portal", hearth = "hearth",
    teleport = "teleport", lift = "lift" }
local CARD_W, PAD, HEADER_H, STRIP_H = 280, 12, 34, 2
local SEG_H, SEG_GAP, SEG_BELOW = 3, 3, 6
local ROW_H, ROW_ICON, ROW_GAP, EDGE_W = 30, 16, 9, 2
local FOOT = 4
local TITLE_SIZE, TOTAL_SIZE, ROW_SIZE, TIME_SIZE, WAIT_SIZE = 15, 16, 13, 12, 11
local BUTTON_GAP = 6
local CURRENT_SEG = 0.5
local HIGHLIGHT_ALPHA = 0.35
local MINUTE = 60
local TEXT_TIME = "%d:%02d"
local TEXT_WAIT = ns.L("wait %s")
local TEXT_COG = ns.L("Journey settings")
local TEXT_CLOSE = ns.L("Stop the journey")
local TEXT_NAME = "Journey Card"

local card
local rows, segs = {}, {}

local function On()
    return Jy.On() and S.Get("card")
end

local function Clock(seconds)
    seconds = math.floor(seconds + 0.5)
    return TEXT_TIME:format(math.floor(seconds / MINUTE), seconds % MINUTE)
end

local function LoadPosition()
    local pos = S.Get("cardPos")
    if type(pos) == "table" then return pos.point, pos.relPoint, pos.x, pos.y end
end

local function SavePosition(point, relPoint, x, y)
    S.Set("cardPos", { point = point, relPoint = relPoint, x = x, y = y })
end

local function Place()
    card:ClearAllPoints()
    local point, relPoint, x, y = LoadPosition()
    if type(point) ~= "string" then point, relPoint, x, y = PLACE[1], PLACE[2], PLACE[3], PLACE[4] end
    card:SetPoint(point, UIParent, relPoint, x, y)
end

local function DragStop(frame)
    frame:StopMovingOrSizing()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    SavePosition(point, relPoint, x, y)
end

local function Paint()
    card.backdrop.fill:SetAlpha(S.Get("cardAlpha") * St.HUD_CARD_ALPHA)
end

local function OpenSettings()
    ns.OpenOptionsWindow(SETTINGS_PAGE)
    ns.UI.GoToSetting(SETTINGS_PAGE, nil, SETTINGS_PAGE .. ":card")
end

local function Header()
    local strip = ns.Solid(card, "ARTWORK", T.accent, 1)
    strip:SetPoint("TOPLEFT")
    strip:SetPoint("TOPRIGHT")
    strip:SetHeight(STRIP_H)
    card.close = Parts.IconButton(card, ns.ClearWaypoint, CROSS, 0, TEXT_CLOSE)
    card.close:SetPoint("TOPRIGHT", -PAD / 2, -(HEADER_H - St.ACTION) / 2)
    card.cog = Parts.IconButton(card, OpenSettings, COG, 0, TEXT_COG)
    card.cog:SetPoint("RIGHT", card.close, "LEFT", -BUTTON_GAP, 0)
    card.total = ns.Font(card, TOTAL_SIZE, nil, T.accent)
    card.total:SetPoint("RIGHT", card.cog, "LEFT", -BUTTON_GAP, 0)
    card.total:SetJustifyH("RIGHT")
    card.title = ns.Font(card, TITLE_SIZE)
    card.title:SetPoint("TOPLEFT", PAD, -(HEADER_H - TITLE_SIZE) / 2)
    card.title:SetPoint("RIGHT", card.total, "LEFT", -BUTTON_GAP, 0)
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(false)
end

local function Build()
    card = CreateFrame("Frame", nil, UIParent)
    card:SetSize(CARD_W, HEADER_H)
    card:SetFrameStrata("MEDIUM")
    card:SetClampedToScreen(true)
    card:EnableMouse(true)
    card:SetMovable(true)
    ns.AllowOffscreen(card)
    card:RegisterForDrag("LeftButton")
    card:SetScript("OnDragStart", card.StartMoving)
    card:SetScript("OnDragStop", DragStop)
    card.backdrop = Parts.HudBackdrop(card)
    Header()
    card.mover = ns.UI.AttachMover(card, TEXT_NAME, function(pos)
        SavePosition(pos.point, pos.relPoint, pos.x, pos.y)
    end, SETTINGS_PAGE, SETTINGS_PAGE .. ":card")
    card:SetScale(S.Get("cardScale"))
    Place()
    Paint()
    card:Hide()
end

local function Segment(i)
    local seg = segs[i]
    if seg then return seg end
    seg = { track = ns.Solid(card, "ARTWORK", T.line, 1), fill = ns.Solid(card, "OVERLAY", T.accent, 1) }
    segs[i] = seg
    return seg
end

local function Segments(done, total)
    local width = (CARD_W - PAD * 2 - SEG_GAP * (total - 1)) / total
    for i = 1, total do
        local seg = Segment(i)
        seg.track:ClearAllPoints()
        seg.track:SetPoint("TOPLEFT", card, "TOPLEFT", PAD + (i - 1) * (width + SEG_GAP), -HEADER_H)
        seg.track:SetSize(width, SEG_H)
        seg.track:Show()
        local lit = i <= done and 1 or i == done + 1 and CURRENT_SEG or 0
        seg.fill:ClearAllPoints()
        seg.fill:SetPoint("TOPLEFT", seg.track, "TOPLEFT")
        seg.fill:SetSize(math.max(width * lit, 0.001), SEG_H)
        seg.fill:SetShown(lit > 0)
    end
    for i = total + 1, #segs do
        segs[i].track:Hide()
        segs[i].fill:Hide()
    end
end

local function Row(i)
    local row = rows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, card)
    row:SetHeight(ROW_H)
    row.hi = ns.Solid(row, "BACKGROUND", T.line, HIGHLIGHT_ALPHA)
    row.hi:SetAllPoints()
    row.edge = ns.Solid(row, "ARTWORK", T.accent, 1)
    row.edge:SetPoint("TOPLEFT")
    row.edge:SetPoint("BOTTOMLEFT")
    row.edge:SetWidth(EDGE_W)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_ICON, ROW_ICON)
    row.icon:SetPoint("LEFT", PAD, 0)
    row.time = ns.Font(row, TIME_SIZE)
    row.time:SetPoint("RIGHT", -PAD, 0)
    row.time:SetJustifyH("RIGHT")
    row.wait = ns.Font(row, WAIT_SIZE, nil, St.WARN_RGB)
    row.wait:SetJustifyH("RIGHT")
    row.text = ns.Font(row, ROW_SIZE)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    rows[i] = row
    return row
end

local function IconFor(leg)
    if leg.mode == "walk" and leg.kind == "goal" then return "goal" end
    return MODE_ICON[leg.mode] or "walk"
end

local function Fill(i, leg, current)
    local row = Row(i)
    local text = current and T.fg or T.muted
    local top = -(HEADER_H + SEG_H + SEG_BELOW + (i - 1) * ROW_H)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", card, "TOPLEFT", 0, top)
    row:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, top)
    row.hi:SetShown(current)
    row.edge:SetShown(current)
    local tint = current and T.accent or T.muted
    row.icon:SetTexture(MEDIA .. IconFor(leg))
    row.icon:SetVertexColor(tint.r, tint.g, tint.b)
    row.text:SetText(Guide.LegText(leg))
    row.text:SetTextColor(text.r, text.g, text.b)
    row.time:SetText(Clock(leg.seconds))
    row.time:SetTextColor(text.r, text.g, text.b)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", row.icon, "RIGHT", ROW_GAP, 0)
    row.wait:ClearAllPoints()
    if leg.wait and leg.wait > 0 then
        row.wait:SetText(TEXT_WAIT:format(Clock(leg.wait)))
        row.wait:SetPoint("RIGHT", row.time, "LEFT", -ROW_GAP, 0)
        row.wait:Show()
        row.text:SetPoint("RIGHT", row.wait, "LEFT", -ROW_GAP, 0)
    else
        row.wait:Hide()
        row.text:SetPoint("RIGHT", row.time, "LEFT", -ROW_GAP, 0)
    end
    row:Show()
end

local function Render(journey)
    local legs = journey.plan and journey.plan.legs or {}
    local total = journey.done + #legs
    card.title:SetText(journey.title)
    card.total:SetText(journey.plan and Clock(journey.plan.seconds) or "")
    Segments(journey.done, math.max(total, 1))
    for i, leg in ipairs(legs) do Fill(i, leg, i == 1) end
    for i = #legs + 1, #rows do rows[i]:Hide() end
    card:SetHeight(HEADER_H + SEG_H + SEG_BELOW + #legs * ROW_H + FOOT)
end

local function Refresh()
    local journey = Guide.Current()
    if not (On() and journey) then
        if card and not card.mover:IsShown() then card:Hide() end
        return
    end
    if not card then Build() end
    Render(journey)
    card:Show()
end

local function OnSet(key, value)
    if not card then return Refresh() end
    if key == "cardScale" then card:SetScale(value) end
    if key == "cardAlpha" then Paint() end
    Refresh()
end

local function ShowMover()
    if not On() then return end
    if not card then Build() end
    card.mover:Show()
    card:Show()
end

local function HideMover()
    if not card then return end
    card.mover:Hide()
    Refresh()
end

Guide.OnChange(Refresh)
hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Refresh)
hooksecurefunc(ns, "ShowUnlockMode", ShowMover)
hooksecurefunc(ns, "HideUnlockMode", HideMover)

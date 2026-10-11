-- ZoneRow.lua: a zone on All Zones: its name and levels, its count and bar; click to open it.
local ns = _G.NaowhForever

local T = ns.THEME
local Completo = ns.Completo
local Parts = ns.Shared.Parts
local Style = Completo.Style
local V = Completo.View

local ZONE_H = 44
local ZONE_BAR_W = 180
local BAR_GAP = 8
local TEXT_COUNT = "%d / %d  (%d%%)"
local TEXT_RARES = ns.L("%d of %d rares killed")
local TEXT_QUESTS = ns.L("%d of %d quests done")
local TEXT_SEE_RARES = ns.L("Click to see its rares.")
local TEXT_SEE_QUESTS = ns.L("Click to see its quests.")

local function ZoneEnter(row)
    row.hover:Show()
    if not Parts.Tip(row, "ANCHOR_RIGHT") then return end
    local view = row:GetParent()
    local n, total = view:Progress(row.zone)
    local rares, m = view:OnRares(), T.muted
    GameTooltip:SetText(row.zone.name, 1, 1, 1)
    GameTooltip:AddLine((rares and TEXT_RARES or TEXT_QUESTS):format(n, total), m.r, m.g, m.b)
    GameTooltip:AddLine(rares and TEXT_SEE_RARES or TEXT_SEE_QUESTS, V.Soft())
    GameTooltip:Show()
end

local function ZoneMouseUp(row, button)
    if button == "LeftButton" then row:GetParent():OpenZone(row.zone) end
end

function V.ProgressRow(parent, onEnter, onMouseUp)
    local row = V.NewRow(parent)
    row.title = ns.Font(row, Style.TITLE_SIZE, nil, T.fg)
    row.title:SetPoint("TOPLEFT", Style.INDENT, -Style.ROW_TOP)
    row.levels = ns.Font(row, Style.SMALL_SIZE, nil, T.muted)
    row.levels:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -Style.LINE_GAP)
    row.count = ns.Font(row, Style.TEXT_SIZE, nil, T.fg)
    row.count:SetPoint("TOPRIGHT", -Style.PIN_RIGHT, -Style.ROW_TOP)
    row.count:SetJustifyH("RIGHT")
    row.bar = Parts.ProgressLine(row, Style.BAR_H)
    row.bar:SetPoint("TOPRIGHT", row.count, "BOTTOMRIGHT", 0, -BAR_GAP)
    row.bar:SetWidth(ZONE_BAR_W)
    row:SetScript("OnEnter", onEnter)
    row:SetScript("OnLeave", V.RowLeave)
    row:SetScript("OnMouseUp", onMouseUp)
    return row
end

function V.SetProgress(row, title, line, n, total, stripe)
    V.Reset(row, stripe)
    row.title:SetText(title)
    row.levels:SetText(line)
    local finished = total > 0 and n == total
    row.count:SetText(TEXT_COUNT:format(n, total, V.Percent(n, total)))
    V.Paint(row.count, finished and Style.HAVE_RGB or T.fg)
    row.bar:SetProgress(V.Share(n, total))
    return ZONE_H
end

local function NewZone(parent)
    return V.ProgressRow(parent, ZoneEnter, ZoneMouseUp)
end

local function SetZone(row, zone, stripe)
    row.zone = zone
    local n, total, low, high = row:GetParent():Progress(zone)
    return V.SetProgress(row, zone.name, V.Levels(low, high), n, total, stripe)
end

V.Kinds.zone = { New = NewZone, Set = SetZone }

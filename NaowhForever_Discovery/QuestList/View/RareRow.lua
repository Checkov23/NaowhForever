-- RareRow.lua: a rare: its level or tick, its name, whether you killed it, a waypoint pin and its drops' chevron.
local ns = _G.NaowhForever

local T = ns.THEME
local Completo = ns.Completo
local Parts = ns.Shared.Parts
local Style = Completo.Style
local R = Completo.Rares
local V = Completo.View

local LEVEL_EXTRA = 12
local ICON_DROP = Style.ROW_ICON_DROP
local DATE_FORMAT = "%d %b %Y"
local TEXT_WAYPOINT = ns.L("Waypoint")
local TEXT_PIN_HINT = ns.L("To where it spawns nearest you.")
local TEXT_NOT_KILLED = ns.L("Not killed")
local TEXT_LEVEL = ns.L("Level")
local TEXT_KIND = ns.L("Kind")
local TEXT_RARE = ns.L("Rare")
local TEXT_ELITE = ns.L("Rare elite")
local TEXT_LAST_KILLED = ns.L("Last killed")
local TEXT_STATUS = ns.L("Status")
local TEXT_BY_HAND = ns.L("Ticked off by hand")
local TEXT_MOVES = ns.L("Moves")
local TEXT_PATROLS = ns.L("Patrols, its way on the map")
local TEXT_SPAWNS_AT = ns.L("Spawns at")
local TEXT_SPOTS = ns.L("%d spots")
local TEXT_CLOSE_DROPS = ns.L("Click: close its drops")
local TEXT_OPEN_DROPS = ns.L("Click: its drops")
local TEXT_PIN_TIP = ns.L("    Pin: waypoint, the nearest spot")
local TEXT_SHIFT_NOT_KILLED = ns.L("Shift-click: not killed")
local TEXT_SHIFT_KILLED = ns.L("Shift-click: killed")
local TEXT_WOWHEAD = ns.L("Right-click: Wowhead link")

local function RareColor(npc)
    local low = R.Levels(npc)
    if low <= 0 then return Style.RED_RGB end
    return GetQuestDifficultyColor(low)
end

local function RareStatus(npc)
    local record = R.Record(npc)
    if not record then return TEXT_NOT_KILLED, T.fg end
    return R.KilledText(record), Style.HAVE_RGB
end

local function RarePinClicked(button)
    R.Waypoint(button:GetParent().rare)
end

local function AddRecord(npc, m)
    local record = R.Record(npc)
    if record and record.n > 0 then
        GameTooltip:AddDoubleLine(TEXT_LAST_KILLED, date(DATE_FORMAT, record.at), m.r, m.g, m.b, 1, 1, 1)
    elseif record then
        GameTooltip:AddDoubleLine(TEXT_STATUS, TEXT_BY_HAND, m.r, m.g, m.b, 1, 1, 1)
    end
    return record
end

local function AddWhere(npc, m)
    local spots = R.SpotCount(npc)
    if R.Trail(npc) then
        GameTooltip:AddDoubleLine(TEXT_MOVES, TEXT_PATROLS, m.r, m.g, m.b, 1, 1, 1)
    elseif spots > 1 then
        GameTooltip:AddDoubleLine(TEXT_SPAWNS_AT, TEXT_SPOTS:format(spots), m.r, m.g, m.b, 1, 1, 1)
    end
    return spots
end

local function RareEnter(row)
    row.hover:Show()
    if not Parts.Tip(row, "ANCHOR_RIGHT") then return end
    local npc, m = row.rare, T.muted
    GameTooltip:SetText(R.Name(npc), 1, 1, 1)
    GameTooltip:AddDoubleLine(TEXT_LEVEL, R.LevelText(npc), m.r, m.g, m.b, 1, 1, 1)
    GameTooltip:AddDoubleLine(TEXT_KIND, R.Elite(npc) and TEXT_ELITE or TEXT_RARE, m.r, m.g, m.b, 1, 1, 1)
    local record = AddRecord(npc, m)
    local spots = AddWhere(npc, m)
    R.AddLoot(GameTooltip, npc)
    GameTooltip:AddLine(" ")
    local open = row:GetParent():IsOpened(npc)
    GameTooltip:AddLine((open and TEXT_CLOSE_DROPS or TEXT_OPEN_DROPS) .. (spots > 0 and TEXT_PIN_TIP or ""),
        V.Soft())
    GameTooltip:AddLine(record and TEXT_SHIFT_NOT_KILLED or TEXT_SHIFT_KILLED, V.Soft())
    GameTooltip:AddLine(TEXT_WOWHEAD, V.Soft())
    GameTooltip:Show()
end

local function RareMouseUp(row, button)
    if button == "RightButton" then
        Parts.CopyWowhead("npc", row.rare, R.Name(row.rare))
    elseif button == "LeftButton" and IsShiftKeyDown() then
        R.SetKilled(row.rare, not R.Killed(row.rare))
    elseif button == "LeftButton" then
        row:GetParent():ToggleOpened(row.rare)
    end
end

local function NewRare(parent)
    local row = V.NewRow(parent)
    local top = -(Style.ROW_TOP + ICON_DROP)
    row.pin = Parts.IconButton(row, RarePinClicked, Style.PIN, 0, TEXT_WAYPOINT)
    row.pin.hint = TEXT_PIN_HINT
    row.pin:SetPoint("RIGHT", -Style.PIN_RIGHT, 0)
    row.tick = V.Tick(row)
    row.tick:SetPoint("TOPLEFT", Style.INDENT, top)
    row.level = ns.Font(row, Style.TEXT_SIZE)
    row.level:SetWidth(Style.LEVEL_W + LEVEL_EXTRA)
    row.level:SetJustifyH("LEFT")
    row.level:SetPoint("TOPLEFT", Style.INDENT, top)
    row.title = V.Line(row, Style.TITLE_SIZE, T.fg)
    row.title:SetPoint("TOPLEFT", V.NAME_X, -Style.ROW_TOP)
    row.where = V.Line(row, Style.SMALL_SIZE, T.muted)
    row.where:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -Style.LINE_GAP)
    row.arrow = row:CreateTexture(nil, "ARTWORK")
    row.arrow:SetTexture(Style.ARROW, nil, nil, "TRILINEAR")
    row.arrow:SetSize(Style.ARROW_SIZE, Style.ARROW_SIZE)
    row.arrow:SetPoint("RIGHT", row.pin, "LEFT", -Style.ARROW_GAP, 0)
    row.arrow:SetVertexColor(T.muted.r, T.muted.g, T.muted.b)
    row.status = ns.Font(row, Style.SMALL_SIZE, nil, T.fg)
    row.status:SetPoint("RIGHT", row.arrow, "LEFT", -Style.ARROW_GAP, 0)
    row.status:SetJustifyH("RIGHT")
    row:SetScript("OnEnter", RareEnter)
    row:SetScript("OnLeave", V.RowLeave)
    row:SetScript("OnMouseUp", RareMouseUp)
    return row
end

local function SubLine(npc, withZone)
    local sub = R.Elite(npc) and TEXT_ELITE or ""
    local home = withZone and R.Zone(npc)
    if home then sub = V.Join(sub, home.name) end
    return sub
end

local function SetRare(row, npc, withZone, stripe)
    row.rare = npc
    V.Reset(row, stripe)
    local killed = R.Killed(npc)
    row.tick:SetShown(killed)
    row.level:SetShown(not killed)
    row.level:SetText(R.LevelText(npc))
    V.Paint(row.level, RareColor(npc))
    row.pin:SetShown(R.SpotCount(npc) > 0)
    row.arrow:SetRotation(row:GetParent():IsOpened(npc) and V.OPEN_ROTATION or 0)
    local text, color = RareStatus(npc)
    row.status:SetText(text)
    V.Paint(row.status, color)
    local textW = row:GetWidth() - V.NAME_X - Style.PIN_RIGHT - Style.STATUS_W - Style.STATUS_GAP
    row.title:SetWidth(textW)
    row.title:SetText(R.Name(npc))
    V.Paint(row.title, killed and T.muted or T.fg)
    row.where:SetWidth(textW)
    local sub = V.SubHeight(row, SubLine(npc, withZone))
    return Style.ROW_TOP + math.ceil(row.title:GetStringHeight()) + Style.ROW_BOTTOM + sub
end

V.Kinds.rare = { New = NewRare, Set = SetRare }

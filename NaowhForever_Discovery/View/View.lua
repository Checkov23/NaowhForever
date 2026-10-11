-- View.lua: the Discovery window's row kinds (Discovery.View.Kinds) and the row a book and a step share.
local ns = _G.NaowhForever

local T = ns.THEME
local Discovery = ns.Discovery
local Shared = ns.Shared
local Parts = Shared.Parts
local Style = Discovery.Style

local ICON_DROP = 1
local TITLE_GAP = 4
local BAG_GAP = 4
local TEXT_WAYPOINT = ns.L("Waypoint")
local TEXT_PIN_HINT = ns.L("Right-click to share it in chat.")

local V = { Kinds = Shared.View.NewKinds() }
Discovery.View = V

V.TEXT_X = Style.INDENT + Style.LEVEL_W + TITLE_GAP

local function RowLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

local function NewMarks(row)
    local top = -(Style.ROW_TOP + ICON_DROP)
    local have = Style.HAVE_RGB
    row.tick = row:CreateTexture(nil, "ARTWORK")
    row.tick:SetTexture(Style.TICK, nil, nil, "TRILINEAR")
    row.tick:SetSize(Style.TICK_SIZE, Style.TICK_SIZE)
    row.tick:SetPoint("TOPLEFT", Style.INDENT, top)
    row.tick:SetVertexColor(have.r, have.g, have.b)
    row.level = ns.Font(row, Style.TEXT_SIZE)
    row.level:SetPoint("TOPLEFT", Style.INDENT, top)
    row.level:SetWidth(Style.LEVEL_W)
    row.level:SetJustifyH("LEFT")
end

local function NewText(row)
    row.title = ns.Font(row, Style.TITLE_SIZE, nil, T.fg)
    row.title:SetPoint("TOPLEFT", V.TEXT_X, -Style.ROW_TOP)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    row.where = ns.Font(row, Style.SMALL_SIZE, nil, T.muted)
    row.where:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -Style.LINE_GAP)
    row.where:SetJustifyH("LEFT")
    row.where:SetWordWrap(true)
end

local function NewStatus(row)
    row.status = ns.Font(row, Style.SMALL_SIZE, nil, T.fg)
    row.status:SetPoint("RIGHT", row.pin, "LEFT", -Style.STATUS_GAP, 0)
    row.status:SetJustifyH("RIGHT")
    row.bag = row:CreateTexture(nil, "ARTWORK")
    row.bag:SetTexture(Style.BAG, nil, nil, "TRILINEAR")
    row.bag:SetSize(Style.TICK_SIZE, Style.TICK_SIZE)
    row.bag:SetPoint("RIGHT", row.status, "LEFT", -BAG_GAP, 0)
end

function V.NewRow(parent, onPin, onEnter)
    local row = CreateFrame("Frame", nil, parent)
    Parts.RowBands(row, Style.INDENT)
    row.pin = Parts.IconButton(row, onPin, Style.PIN, 0, TEXT_WAYPOINT)
    row.pin.hint = TEXT_PIN_HINT
    row.pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.pin:SetPoint("RIGHT", -Style.PIN_RIGHT, 0)
    NewMarks(row)
    NewText(row)
    NewStatus(row)
    row:EnableMouse(true)
    row:SetScript("OnEnter", onEnter)
    row:SetScript("OnLeave", RowLeave)
    return row
end

function V.Reset(row, stripe)
    row.stripe:SetShown(stripe)
    row.hover:Hide()
end

function V.Paint(fs, color)
    fs:SetTextColor(color.r, color.g, color.b)
end

function V.Soft()
    local c = T.accentSoft
    return c.r, c.g, c.b
end

function V.TextWidth(row)
    return row:GetWidth() - V.TEXT_X - Style.PIN_RIGHT - Style.STATUS_W
end

function V.Height(row)
    return Style.ROW_TOP + math.ceil(row.title:GetStringHeight()) + Style.LINE_GAP
        + math.ceil(row.where:GetStringHeight()) + Style.ROW_BOTTOM
end

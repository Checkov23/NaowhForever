-- View.lua: the Completo window's row kinds (Completo.View.Kinds) and what its rows share.
local ns = _G.NaowhForever

local T = ns.THEME
local Completo = ns.Completo
local Shared = ns.Shared
local Parts = Shared.Parts
local Style = Completo.Style

local HALF_TURN = math.pi / 2
local PERCENT = Completo.C.PERCENT
local TEXT_LEVEL = ns.L("Level %d")
local TEXT_LEVELS = ns.L("Levels %d-%d")
local TEXT_SEPARATOR = "  -  "

local V = { Kinds = Shared.View.NewKinds() }
Completo.View = V

V.NAME_X = Style.INDENT + Style.LEVEL_W + Style.RARE_GAP
V.OPEN_ROTATION = -HALF_TURN

function V.NewRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    Parts.RowBands(row, Style.INDENT)
    row:EnableMouse(true)
    return row
end

function V.Reset(row, stripe)
    row.stripe:SetShown(stripe)
    row.hover:Hide()
end

function V.RowLeave(row)
    row.hover:Hide()
    GameTooltip:Hide()
end

function V.Tick(row)
    local tick = row:CreateTexture(nil, "ARTWORK")
    tick:SetTexture(Style.TICK, nil, nil, "TRILINEAR")
    tick:SetSize(Style.TICK_SIZE, Style.TICK_SIZE)
    tick:SetVertexColor(Style.HAVE_RGB.r, Style.HAVE_RGB.g, Style.HAVE_RGB.b)
    return tick
end

function V.Line(row, size, color)
    local fs = ns.Font(row, size, nil, color)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

function V.Paint(fs, color)
    fs:SetTextColor(color.r, color.g, color.b)
end

function V.Soft()
    local c = T.accentSoft
    return c.r, c.g, c.b
end

function V.Percent(n, total)
    return total > 0 and math.floor(n / total * PERCENT) or 0
end

function V.Share(n, total)
    return total > 0 and n / total or 0
end

function V.Levels(low, high)
    if not low then return "" end
    if low == high then return TEXT_LEVEL:format(low) end
    return TEXT_LEVELS:format(low, high)
end

function V.Join(sub, more)
    if sub == "" then return more end
    return sub .. TEXT_SEPARATOR .. more
end

function V.SubHeight(row, sub)
    row.where:SetText(sub)
    row.where:SetShown(sub ~= "")
    if sub == "" then return 0 end
    return Style.LINE_GAP + math.ceil(row.where:GetStringHeight())
end

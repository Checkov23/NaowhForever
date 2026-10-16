-- Thresholds.lua: a proportional difficulty line with numeric boundaries and a current-value marker.
local ns = _G.NaowhForever

local Parts = ns.Shared.Parts
local St = ns.Shared.Style
local T = ns.THEME

local HALF = 0.5
local BANDS = 4

local function Clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function Layout(line)
    local values = line.values
    if not values[4] then return end
    local width = math.max(1, line:GetWidth())
    local span = (values[4] - values[1]) * (1 + St.THRESHOLD_GREY_SHARE)
    local usedRows = 1
    for i = 1, St.THRESHOLD_LABEL_ROWS do line.rowRights[i] = -St.THRESHOLD_LABEL_GAP end
    for i = 1, BANDS do
        local x = (values[i] - values[1]) / span * width
        local nextX = i < BANDS and (values[i + 1] - values[1]) / span * width or width
        local band = line.bands[i]
        band:ClearAllPoints()
        band:SetPoint("TOPLEFT", line.track, "TOPLEFT", x, 0)
        band:SetWidth(math.max(1, nextX - x))
        band:SetShown(nextX > x)
        local label = line.labels[i]
        label:SetShown(nextX > x)
        if nextX > x then
            local labelWidth = label:GetStringWidth()
            local left = Clamp(x - labelWidth * HALF, 0, math.max(0, width - labelWidth))
            local row = 1
            while row < St.THRESHOLD_LABEL_ROWS and left < line.rowRights[row] + St.THRESHOLD_LABEL_GAP do
                row = row + 1
            end
            label:SetShown(left >= line.rowRights[row] + St.THRESHOLD_LABEL_GAP)
            line.rowRights[row] = left + labelWidth
            usedRows = math.max(usedRows, row)
            local drop = St.THRESHOLD_BAR_HEIGHT + St.THRESHOLD_LABEL_GAP + (row - 1) * St.THRESHOLD_LABEL_HEIGHT
            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", line, "TOPLEFT", left, -drop)
        end
    end
    local height = St.THRESHOLD_HEIGHT + (usedRows - 1) * St.THRESHOLD_LABEL_HEIGHT
    if line.drawnHeight ~= height then
        line.drawnHeight = height
        line:SetHeight(height)
    end
    line.marker:SetShown(line.skill ~= nil)
    if line.skill then
        local x = Clamp((line.skill - values[1]) / span, 0, 1) * width
        line.marker:ClearAllPoints()
        line.marker:SetPoint("CENTER", line.track, "LEFT", x, 0)
    end
end

local function Fill(line, first, yellow, green, grey, skill, colors)
    line.values[1], line.values[2], line.values[3], line.values[4] = first, yellow, green, grey
    line.skill = skill
    for i = 1, BANDS do
        line.labels[i]:SetText(tostring(line.values[i]))
        line.bands[i]:Paint(colors[i - 1])
    end
    Layout(line)
end

function Parts.ThresholdLine(parent)
    local line = CreateFrame("Frame", nil, parent)
    line:SetHeight(St.THRESHOLD_HEIGHT)
    line.values, line.bands, line.labels, line.rowRights = {}, {}, {}, {}
    line.track = CreateFrame("Frame", nil, line)
    line.track:SetPoint("TOPLEFT")
    line.track:SetPoint("TOPRIGHT")
    line.track:SetHeight(St.THRESHOLD_BAR_HEIGHT)
    ns.Border(line.track, St.BORDER_RGB)
    for i = 1, BANDS do
        local band = Parts.ProgressLine(line.track, St.THRESHOLD_BAR_HEIGHT)
        band:SetProgress(1)
        line.bands[i] = band
        local label = ns.Font(line, St.THRESHOLD_FONT_SIZE)
        label:SetJustifyH("LEFT")
        line.labels[i] = label
    end
    line.marker = CreateFrame("Frame", nil, line.track)
    line.marker:SetSize(St.THRESHOLD_MARKER_WIDTH, St.THRESHOLD_BAR_HEIGHT + St.THRESHOLD_MARKER_OUT * 2)
    line.marker:SetFrameLevel(line.bands[BANDS].fill:GetFrameLevel() + 1)
    ns.Solid(line.marker, "OVERLAY", T.fg, 1):SetAllPoints()
    line.Fill = Fill
    line:SetScript("OnSizeChanged", Layout)
    return line
end

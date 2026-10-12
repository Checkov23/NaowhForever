-- History.lua: the fights kept, listed in a window of their own.
local ns = _G.NaowhForever

local T = ns.THEME
local Parts = ns.Shared.Parts
local DM = ns.DamageMeter
local S = DM.Settings
local C, Look, Format, History = DM.C, DM.Look, DM.Format, DM.History

local FRAME_NAME = "NaowhForeverDamageMeterHistory"
local OPTIONS_NAME = "NaowhForeverOptions"
local SIDE_GAP = 8
local HEADER, TITLE_SIZE, TEXT_SIZE, PAD, GAP = C.HEADER, 12, 11, 8, 4
local ROW_H, VISIBLE, HEAD_H = 18, 12, 18
local BUTTON_H, CLOSE_W, CLEAR_W, BUTTON_GAP = 18, 22, 52, 4
local DATE_FORMAT = "%m/%d %H:%M"
local TEXT_TITLE, TEXT_CLEAR, TEXT_CLOSE = "Fight History", "Clear", "X"
local TEXT_EMPTY = "No fights kept yet"
local TEXT_ASK = "Clear the fight history?"

local COLUMNS = {
    { key = "when", title = "Time", width = 84, left = true },
    { key = "name", title = "Fight", width = 150, left = true },
    { key = "length", title = "Length", width = 50 },
    { key = "dps", title = "DPS", width = 66 },
    { key = "raidDps", title = "Raid DPS", width = 70 },
    { key = "hps", title = "HPS", width = 66 },
    { key = "raidHps", title = "Raid HPS", width = 70 },
}
local WIDTH = 2 * PAD
for _, column in ipairs(COLUMNS) do WIDTH = WIDTH + column.width + GAP end
local HEIGHT = HEADER + HEAD_H + VISIBLE * ROW_H + 2 * PAD

local Window = {}
DM.HistoryWindow = Window

local frame, offset = nil, 0

local function Values(entry)
    return {
        when = date(DATE_FORMAT, entry.at),
        name = entry.boss or entry.place or "",
        length = DM.Clock(entry.seconds),
        dps = Format(entry.damage.perSecond),
        raidDps = Format(entry.damage.totalPerSecond),
        hps = Format(entry.healing.perSecond),
        raidHps = Format(entry.healing.totalPerSecond),
    }
end

local function Place(fs, column, x, parent, y, rowHeight)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetSize(column.width, rowHeight)
    fs:SetJustifyH(column.left and "LEFT" or "RIGHT")
end

local function NewRow(i)
    local row = { cells = {} }
    local x = PAD
    local y = -(HEADER + HEAD_H + PAD) - (i - 1) * ROW_H
    for n, column in ipairs(COLUMNS) do
        local fs = ns.Font(frame, TEXT_SIZE, "OUTLINE", T.fg)
        Place(fs, column, x, frame, y, ROW_H)
        fs:SetWordWrap(false)
        row.cells[n] = fs
        x = x + column.width + GAP
    end
    frame.rows[i] = row
    return row
end

local function Paint()
    local list = History.List()
    local last = math.max(0, #list - VISIBLE)
    offset = math.max(0, math.min(offset, last))
    local window, header, border = Look.Color("windowColor"), Look.Color("headerColor"), Look.Color("borderColor")
    local title, name, value = Look.Color("titleColor"), Look.Color("nameColor"), Look.Color("valueColor")
    local column, rank = Look.Color("columnColor"), Look.Color("rankColor")
    local font, outline = S.Get("font"), S.Get("outline")
    frame.background:SetColorTexture(window.r, window.g, window.b, 1)
    frame.headerBackground:SetColorTexture(header.r, header.g, header.b, 1)
    frame.border:SetColor(border.r, border.g, border.b, 1)
    frame.border._frame:SetShown(S.Get("showBorder"))
    Parts.HudFont(frame.title, font, TITLE_SIZE, outline)
    frame.title:SetTextColor(title.r, title.g, title.b)
    for _, fs in ipairs(frame.titles) do
        Parts.HudFont(fs, font, TEXT_SIZE, outline)
        fs:SetTextColor(column.r, column.g, column.b)
    end
    frame.empty:SetTextColor(rank.r, rank.g, rank.b)
    frame.empty:SetShown(#list == 0)
    for i = 1, VISIBLE do
        local row = frame.rows[i] or NewRow(i)
        local entry = list[offset + i]
        for n, fs in ipairs(row.cells) do
            fs:SetShown(entry ~= nil)
            if entry then
                local c = COLUMNS[n].left and name or value
                Parts.HudFont(fs, font, TEXT_SIZE, outline)
                fs:SetTextColor(c.r, c.g, c.b)
            end
        end
        if entry then
            local values = Values(entry)
            for n, spec in ipairs(COLUMNS) do row.cells[n]:SetText(values[spec.key]) end
        end
    end
end

local function PlaceWindow()
    if frame.moved then return end
    frame:ClearAllPoints()
    local options = _G[OPTIONS_NAME]
    if options and options:IsShown() and options:GetLeft() then
        local ratio = options:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local left, right = options:GetLeft() * ratio, options:GetRight() * ratio
        if UIParent:GetWidth() - right >= WIDTH + SIDE_GAP then
            frame:SetPoint("TOPLEFT", options, "TOPRIGHT", SIDE_GAP, 0)
            return
        elseif left >= WIDTH + SIDE_GAP then
            frame:SetPoint("TOPRIGHT", options, "TOPLEFT", -SIDE_GAP, 0)
            return
        end
    end
    frame:SetPoint("CENTER")
end

local function Build()
    frame = CreateFrame("Frame", FRAME_NAME, UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("FULLSCREEN")
    frame:SetToplevel(true)
    frame:SetMovable(true); frame:SetClampedToScreen(true); frame:EnableMouseWheel(true)
    frame.rows, frame.titles = {}, {}
    frame.background = ns.Solid(frame, "BACKGROUND", T.bg, 1)
    frame.background:SetAllPoints()
    frame.border = ns.Border(frame)
    frame.header = CreateFrame("Frame", nil, frame)
    frame.header:SetPoint("TOPLEFT"); frame.header:SetPoint("TOPRIGHT"); frame.header:SetHeight(HEADER)
    frame.header:EnableMouse(true); frame.header:RegisterForDrag("LeftButton")
    frame.header:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame.header:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); frame.moved = true end)
    frame.headerBackground = ns.Solid(frame.header, "BACKGROUND", T.panel, 1)
    frame.headerBackground:SetAllPoints()
    frame.title = ns.Font(frame.header, TITLE_SIZE, "OUTLINE", T.fg)
    frame.title:SetPoint("LEFT", PAD, 0)
    frame.title:SetText(TEXT_TITLE)
    frame.close = ns.Button(frame.header, TEXT_CLOSE, CLOSE_W, BUTTON_H, function() frame:Hide() end)
    frame.close:SetPoint("RIGHT", -PAD, 0)
    frame.clear = ns.Button(frame.header, TEXT_CLEAR, CLEAR_W, BUTTON_H, function() Window.AskClear() end)
    frame.clear:SetPoint("RIGHT", frame.close, "LEFT", -BUTTON_GAP, 0)
    local x = PAD
    for n, column in ipairs(COLUMNS) do
        local fs = ns.Font(frame, TEXT_SIZE, "OUTLINE", T.muted)
        Place(fs, column, x, frame, -(HEADER + PAD / 2), HEAD_H)
        fs:SetText(column.title)
        frame.titles[n] = fs
        x = x + column.width + GAP
    end
    frame.empty = ns.Font(frame, TEXT_SIZE, "OUTLINE", T.muted)
    frame.empty:SetPoint("CENTER", 0, -HEADER / 2)
    frame.empty:SetText(TEXT_EMPTY)
    frame:SetScript("OnMouseWheel", function(_, delta)
        offset = offset - delta
        Paint()
    end)
    frame:Hide()
end

function Window.AskClear()
    ns.Confirm(TEXT_ASK, History.Clear)
end

function Window.Refresh()
    if frame and frame:IsShown() then Paint() end
end

function Window.Toggle()
    if not frame then Build() end
    if frame:IsShown() then
        frame:Hide()
    else
        offset = 0
        Paint()
        PlaceWindow()
        frame:Show()
    end
end

History.OnChanged = Window.Refresh

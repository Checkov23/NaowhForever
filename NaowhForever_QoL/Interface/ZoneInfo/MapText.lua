-- MapText.lua: a compact, noninteractive zone summary drawn directly over the world map.
local ns = _G.NaowhForever
local Z, S, T = ns.ZoneInfo, ns.QoLSettings, ns.THEME
local St = ns.Shared.Style
local TOP, INSET, TITLE_SIZE, TEXT_SIZE, GAP, LEVEL = 18, 24, 22, 14, 3, 100
local MAX_DUNGEONS, MAX_NAMES, MAX_LINES = 3, 5, 9
local TEXT_MORE, TEXT_GROUP = ns.L("%s and %d more"), ns.L("%s: %s")
local HERBS, MINING, TRAVEL = ns.L("Herbs"), ns.L("Mining"), ns.L("Travel")
local overview, gathering = { rows = {} }, { rows = {} }
local names, frame, count = {}, nil, 0
local areaLabel, areaAlpha
local EMPTY = {}

local function Line(text, color)
    if count >= MAX_LINES then return end
    count = count + 1
    local line = frame.lines[count]
    line:SetWidth(frame:GetWidth())
    line:SetText(text)
    line:SetTextColor(color.r, color.g, color.b)
    line:ClearAllPoints()
    if count == 1 then line:SetPoint("TOP", frame)
    else line:SetPoint("TOP", frame.lines[count - 1], "BOTTOM", 0, -GAP) end
    line:Show()
end

local function Names(data, group, nodeKind)
    wipe(names)
    local category, total = nil, 0
    for i = 1, data.count do
        local row = data.rows[i]
        if row.kind == "section" then category = row.title end
        if row.kind == "entry" and (nodeKind and row.nodeKind == nodeKind or not nodeKind and category == group) then
            total = total + 1
            if total <= MAX_NAMES then names[#names + 1] = row.title end
        end
    end
    local text = table.concat(names, ", ")
    if total > MAX_NAMES then text = TEXT_MORE:format(text, total - MAX_NAMES) end
    return total > 0 and text or nil
end

function Z.HideMapText()
    if frame then frame:Hide() end
    if areaLabel then areaLabel:SetAlpha(areaAlpha); areaLabel, areaAlpha = nil, nil end
end

function Z.MapText(mapID)
    if not (S.Get("enabled") and S.Get("zoneInfo") and S.Get("zoneInfoOnMap")
        and WorldMapFrame and WorldMapFrame:IsShown() and Z.MapInfo(mapID)) then Z.HideMapText(); return end
    if not frame then
        frame = CreateFrame("Frame", nil, WorldMapFrame)
        frame:EnableMouse(false)
        frame.lines = {}
        for i = 1, MAX_LINES do
            local line = ns.Font(frame, i == 1 and TITLE_SIZE or TEXT_SIZE, "OUTLINE", T.fg, i == 1)
            line:SetJustifyH("CENTER")
            line:SetWordWrap(true)
            line:SetShadowColor(St.HUD_SHADOW_RGB.r, St.HUD_SHADOW_RGB.g, St.HUD_SHADOW_RGB.b, 1)
            line:SetShadowOffset(St.HUD_SHADOW_X, St.HUD_SHADOW_Y)
            frame.lines[i] = line
        end
    end
    if not areaLabel then
        for provider in pairs(WorldMapFrame.dataProviders or EMPTY) do
            if provider.Label and provider.Label.Description then
                areaLabel, areaAlpha = provider.Label, provider.Label:GetAlpha()
                areaLabel:SetAlpha(0)
                break
            end
        end
    end
    local canvas = WorldMapFrame:GetCanvasContainer()
    frame:ClearAllPoints()
    frame:SetPoint("TOP", canvas, "TOP", 0, -TOP)
    frame:SetWidth(math.max(1, canvas:GetWidth() - INSET * 2))
    frame:SetHeight(math.max(1, canvas:GetHeight() - TOP))
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(WorldMapFrame:GetCanvas():GetFrameLevel() + LEVEL)
    count = 0
    Z.Fill(overview, mapID, false)
    Line(overview.name .. (overview.range ~= "" and " / " .. overview.range or ""), T.fg)
    local dungeons, extra = 0, 0
    for i = 1, overview.count do
        local row = overview.rows[i]
        if row.kind == "entry" and row.dungeon then
            dungeons = dungeons + 1
            if dungeons <= MAX_DUNGEONS then
                Line(row.title .. (row.detail and " / " .. row.detail or ""), St.TIME_LOW_RGB)
            else extra = extra + 1 end
        elseif row.kind == "entry" and not row.map then Line(row.title, T.fg) end
    end
    if extra > 0 then Line(TEXT_MORE:format(ns.L("Dungeons & Raids"), extra), St.TIME_LOW_RGB) end
    local travel = Names(overview, "Travel")
    if travel then Line(TEXT_GROUP:format(TRAVEL, travel), T.accent) end
    if S.Get("zoneInfoGathering") then
        Z.Fill(gathering, mapID, true)
        local herbs, ore = Names(gathering, nil, "herb"), Names(gathering, nil, "ore")
        if herbs then Line(TEXT_GROUP:format(HERBS, herbs), St.HAVE_RGB) end
        if ore then Line(TEXT_GROUP:format(MINING, ore), St.TIME_LOW_RGB) end
    end
    for i = count + 1, MAX_LINES do frame.lines[i]:Hide() end
    frame:Show()
end

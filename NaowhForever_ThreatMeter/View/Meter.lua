-- Meter.lua: the Threat Meter's look, the same on screen and on the card's editable preview.
local ns = _G.NaowhForever

local UI = ns.UI
local T = ns.THEME
local Parts = ns.Shared.Parts
local TM = ns.ThreatMeter
local S = TM.Settings
local C = TM.C

local WINDOW_BG = { r = 0.025, g = 0.04, b = 0.055 }
local WINDOW_EDGE = { r = 0.10, g = 0.19, b = 0.24 }
local HEADER_BG = { r = 0.04, g = 0.075, b = 0.095 }
local ROW_BG = { r = 0.065, g = 0.085, b = 0.105 }
local OWN_ROW = { r = 0.04, g = 0.19, b = 0.25 }
local NAME_RGB = { r = 1, g = 1, b = 1 }
local FALLBACK_COLOR = { r = 0.6, g = 0.6, b = 0.6 }
local OWN_DARKEN = 0.27
local DANGER_G, DANGER_B = 0.35, 0.25
local YOUR_SHADE = 0.75
local GRADIENT_TEX = ns.MEDIA .. "NaowhGradient.tga"
local ICON_PATH = "Interface\\Icons\\ClassIcon_"
local LINE_ICON = "Interface\\Icons\\Ability_Warrior_Challange"
local PET_ICON = "Interface\\Icons\\Ability_Hunter_BeastCall"
local INSET, FOOTER, HEADER = C.INSET, C.FOOTER, C.HEADER
local MIN_WIDTH, MIN_HEIGHT = C.MIN_WIDTH, C.MIN_HEIGHT
local TEXT_PAD = 8
local ACCENT_LINE, ACCENT_ALPHA = 2, 0.8
local KICKER_SIZE, TITLE_SIZE, FOOT_SIZE, EMPTY_SIZE, ROW_TEXT = 9, 13, 10, 12, 12
local KICKER_X, KICKER_Y, TITLE_Y, TITLE_RIGHT = 10, -7, 7, -82
local RANGE_RIGHT, STATE_GAP, EMPTY_Y = -12, -4, -10
local EDGE_W, RANK_SIZE, RANK_W, RANK_ROOM = 2, 10, 16, 18
local ICON_CROP, ICON_MAX, ICON_PAD, ICON_GAP = ns.Shared.Style.ICON_CROP, 32, 6, 6
local PERCENT_W, VALUE_W, NAME_GAP, NAME_MIN = 45, 54, 5, 48
local MIN_FONT = C.MIN_FONT
local SHORT_M, SHORT_K = 1000000, 1000
local ROUND = C.ROUND

local TEXT_KICKER = ns.L("THREAT")
local TEXT_EMPTY = ns.L("Waiting for threat")
local TEXT_HOLDING = ns.L("HOLDING AGGRO")
local TEXT_TO_PULL = ns.L("YOU %.0f%% TO PULL")
local TEXT_NO_THREAT = ns.L("NO PLAYER THREAT")
local TEXT_LINE_RANK = "-"
local SHORT_M_TEXT, SHORT_K_TEXT, PERCENT_TEXT = "%.1fm", "%.1fk", "%.0f%%"

local classIcons = {}
local yourShade

local Look = {}
TM.Look = Look

local function ShortThreat(v)
    if v >= SHORT_M then return SHORT_M_TEXT:format(v / SHORT_M) end
    if v >= SHORT_K then return SHORT_K_TEXT:format(v / SHORT_K) end
    return tostring(math.floor(v + ROUND))
end

local function ThemedColor(key)
    if key ~= "playerColor" then return nil end
    yourShade = yourShade or { r = T.accent.r * YOUR_SHADE, g = T.accent.g * YOUR_SHADE, b = T.accent.b * YOUR_SHADE }
    return yourShade
end

local function BarColor(key)
    return S.Get("themeColors") and ThemedColor(key) or S.Get(key)
end

local function RowColor(e)
    if e.isLine then return BarColor("pullColor") end
    if e.isPlayer and S.Get("playerColorOn") then return BarColor("playerColor") end
    if e.tanking and S.Get("tankColorOn") then return BarColor("tankColor") end
    return e.class and RAID_CLASS_COLORS[e.class] or FALLBACK_COLOR
end

local function ClassIcon(class)
    local path = classIcons[class]
    if not path then path = ICON_PATH .. class; classIcons[class] = path end
    return path
end

local function NewHeader(frame)
    frame.header = CreateFrame("Frame", nil, frame)
    frame.header:SetPoint("TOPLEFT")
    ns.Solid(frame.header, "BACKGROUND", ns.ThemeTint("panel", HEADER_BG), 1):SetAllPoints()
    local line = ns.Solid(frame.header, "OVERLAY", T.accent, ACCENT_ALPHA)
    line:SetPoint("TOPLEFT"); line:SetPoint("TOPRIGHT"); line:SetHeight(ACCENT_LINE)
    frame.header.kicker = ns.Font(frame.header, KICKER_SIZE, "OUTLINE", T.accent)
    frame.header.kicker:SetPoint("TOPLEFT", KICKER_X, KICKER_Y); frame.header.kicker:SetText(TEXT_KICKER)
    frame.header.text = ns.Font(frame.header, TITLE_SIZE, "OUTLINE")
    frame.header.text:SetPoint("BOTTOMLEFT", KICKER_X, TITLE_Y)
    frame.header.text:SetPoint("RIGHT", TITLE_RIGHT, 0)
    frame.header.text:SetJustifyH("LEFT"); frame.header.text:SetWordWrap(false)
end

local function NewFooter(frame)
    frame.footer = CreateFrame("Frame", nil, frame)
    frame.footer:SetHeight(FOOTER)
    frame.footer.state = ns.Font(frame.footer, FOOT_SIZE, "OUTLINE", T.muted)
    frame.footer.state:SetPoint("LEFT"); frame.footer.state:SetJustifyH("LEFT")
    frame.footer.state:SetWordWrap(false)
    frame.footer.range = ns.Font(frame.footer, FOOT_SIZE, "OUTLINE", T.muted)
    frame.footer.range:SetPoint("RIGHT", RANGE_RIGHT, 0)
    frame.footer.state:SetPoint("RIGHT", frame.footer.range, "LEFT", STATE_GAP, 0)
end

local function PlaceFooter(f, statusTop, top)
    f.footer:ClearAllPoints()
    if statusTop then
        f.footer:SetPoint("TOPLEFT", INSET, -top); f.footer:SetPoint("TOPRIGHT", -INSET, -top)
    else
        f.footer:SetPoint("BOTTOMLEFT", INSET, 0); f.footer:SetPoint("BOTTOMRIGHT", -INSET, 0)
    end
end

local function Changed(last, w, h, bh, gap, fontSize, iconSize, growUp, above, below, texture, font, outline)
    return last.w ~= w or last.h ~= h or last.bh ~= bh or last.gap ~= gap or last.fontSize ~= fontSize
        or last.iconSize ~= iconSize or last.growUp ~= growUp or last.above ~= above or last.below ~= below
        or last.texture ~= texture or last.font ~= font or last.outline ~= outline
        or last.showRanks ~= S.Get("showRanks") or last.showIcons ~= S.Get("showIcons")
        or last.showPercent ~= S.Get("showPercent") or last.showValue ~= S.Get("showValue")
end

local function LayRow(row, f, i, m)
    row.laid = m.gen
    row:ClearAllPoints()
    if m.growUp then
        row:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", INSET, m.below + INSET + (i - 1) * (m.bh + m.gap))
    else
        row:SetPoint("TOPLEFT", f, "TOPLEFT", INSET, -m.above - INSET - (i - 1) * (m.bh + m.gap))
    end
    row:SetSize(m.w - 2 * INSET, m.bh)
    row:SetStatusBarTexture(UI.TexturePath(m.texture, GRADIENT_TEX))
    local left = TEXT_PAD
    row.rank:ClearAllPoints(); row.rank:SetPoint("LEFT", left, 0); row.rank:SetWidth(RANK_W)
    row.rank:SetShown(m.showRanks)
    if m.showRanks then left = left + RANK_ROOM end
    row.icon:ClearAllPoints(); row.icon:SetPoint("LEFT", left, 0); row.icon:SetSize(m.iconSize, m.iconSize)
    row.icon:SetShown(m.showIcons)
    left = left + m.iconWidth
    local percentWidth = m.showPercent and PERCENT_W * m.fontSize / ROW_TEXT or 0
    local valueWidth = m.showValue and VALUE_W * m.fontSize / ROW_TEXT or 0
    row.percent:ClearAllPoints(); row.percent:SetPoint("RIGHT", -TEXT_PAD, 0); row.percent:SetWidth(math.max(1, percentWidth))
    row.value:ClearAllPoints(); row.value:SetPoint("RIGHT", -TEXT_PAD - percentWidth, 0); row.value:SetWidth(math.max(1, valueWidth))
    row.name:ClearAllPoints(); row.name:SetPoint("LEFT", left, 0)
    row.name:SetPoint("RIGHT", -TEXT_PAD - percentWidth - valueWidth - NAME_GAP, 0)
    Parts.HudFont(row.name, m.font, m.fontSize, m.outline)
    Parts.HudFont(row.value, m.font, m.fontSize, m.outline)
    Parts.HudFont(row.percent, m.font, m.fontSize, m.outline)
end

local function Remember(last, w, h, bh, gap, fontSize, iconSize, growUp, above, below, texture, font, outline)
    last.w, last.h, last.bh, last.gap, last.fontSize, last.iconSize = w, h, bh, gap, fontSize, iconSize
    last.growUp, last.above, last.below, last.texture, last.font = growUp, above, below, texture, font
    last.outline = outline
    last.showRanks, last.showIcons = S.Get("showRanks"), S.Get("showIcons")
    last.showPercent, last.showValue = S.Get("showPercent"), S.Get("showValue")
    last.gen = last.gen + 1
end

local function FitFont(w, fontSize, iconWidth, rankWidth)
    local columns = (S.Get("showPercent") and PERCENT_W or 0) + (S.Get("showValue") and VALUE_W or 0)
    if columns <= 0 then return fontSize end
    local available = w - 2 * INSET - 2 * TEXT_PAD - iconWidth - rankWidth - NAME_GAP - NAME_MIN
    return math.max(MIN_FONT, math.min(fontSize, available * ROW_TEXT / columns))
end

local function PaintRange(f, last, total, first, shown)
    if last.total == total and last.first == first and last.shown == shown then return end
    last.total, last.first, last.shown = total, first, shown
    f.footer.range:SetText(total > 0 and ((first + 1) .. "-" .. (first + shown) .. " / " .. total) or "")
end

local function PaintBackground(f, shown)
    local bg, bgAlpha = Look.BackgroundColor(), S.Get("backgroundAlpha")
    f.background:SetColorTexture(bg.r, bg.g, bg.b, 1)
    f.background:SetAlpha(bgAlpha)
    f.border._frame:SetAlpha(bgAlpha)
    f.empty:SetShown(shown == 0)
end

local function PaintRow(row, e, top, rowBg, share, showValue, showPercent)
    local c = RowColor(e)
    row:SetStatusBarColor(c.r, c.g, c.b, S.Get("barAlpha"))
    row.bg:SetColorTexture(rowBg.r, rowBg.g, rowBg.b, 1)
    local own = e.isPlayer and S.Get("highlightPlayer")
    row.edge:SetColorTexture(own and T.accent.r or c.r, own and T.accent.g or c.g, own and T.accent.b or c.b, 1)
    row:SetValue(top > 0 and e.threat / top or 0)
    row.rank:SetText(e.isLine and TEXT_LINE_RANK or tostring(e.rank))
    row.name:SetText(e.name)
    row.name:SetTextColor(NAME_RGB.r, NAME_RGB.g, NAME_RGB.b)
    if own then
        local mark = ns.ThemeTint("accent", nil)
        if mark then row.bg:SetColorTexture(mark.r * OWN_DARKEN, mark.g * OWN_DARKEN, mark.b * OWN_DARKEN, 1)
        else row.bg:SetColorTexture(OWN_ROW.r, OWN_ROW.g, OWN_ROW.b, 1) end
    end
    row.icon:SetTexture(e.isLine and LINE_ICON or e.class and ClassIcon(e.class) or PET_ICON)
    row.icon:SetDesaturated(e.isPet == true)
    local value = showValue and e.threat or false
    if row.shownValue ~= value then
        row.shownValue = value
        row.value:SetText(value and ShortThreat(value) or "")
    end
    local percent = showPercent and e[share] or false
    if row.shownPercent ~= percent then
        row.shownPercent = percent
        row.percent:SetText(percent and PERCENT_TEXT:format(percent) or "")
    end
    local danger = not e.isLine and not e.tanking and e.pullPct >= S.Get("warnAt")
    row.percent:SetTextColor(1, danger and DANGER_G or 1, danger and DANGER_B or 1)
end

Look.BarColor = BarColor

function Look.BackgroundColor()
    return S.Get("backgroundColor") or ns.ThemeTint("bg", WINDOW_BG)
end

function Look.HeaderHeight()
    return S.Get("showHeader") and HEADER or 0
end

function Look.New(frame)
    frame.rows = {}
    frame.background = ns.Solid(frame, "BACKGROUND", ns.ThemeTint("bg", WINDOW_BG), 1)
    frame.background:SetAllPoints()
    frame.border = ns.Border(frame, ns.ThemeTint("line", WINDOW_EDGE))
    NewHeader(frame)
    NewFooter(frame)
    frame.empty = ns.Font(frame, EMPTY_SIZE, "OUTLINE", T.muted)
    frame.empty:SetPoint("CENTER", 0, EMPTY_Y); frame.empty:SetText(TEXT_EMPTY)
end

function Look.Row(f, i)
    local row = CreateFrame("StatusBar", nil, f)
    row:SetMinMaxValues(0, 1)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.edge = row:CreateTexture(nil, "OVERLAY")
    row.edge:SetPoint("TOPLEFT"); row.edge:SetPoint("BOTTOMLEFT"); row.edge:SetWidth(EDGE_W)
    row.rank = ns.Font(row, RANK_SIZE, "OUTLINE", T.muted)
    row.icon = row:CreateTexture(nil, "OVERLAY")
    row.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    row.value = ns.Font(row, ROW_TEXT, "OUTLINE")
    row.value:SetJustifyH("RIGHT")
    row.percent = ns.Font(row, ROW_TEXT, "OUTLINE")
    row.percent:SetJustifyH("RIGHT")
    row.name = ns.Font(row, ROW_TEXT, "OUTLINE")
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    f.rows[i] = row
    return row
end

local metrics = {}

function Look.Layout(f, total, first, bh, gap, fontSize)
    local w, top = math.max(MIN_WIDTH, S.Get("width")), Look.HeaderHeight()
    local minHeight = math.max(MIN_HEIGHT, top + FOOTER + 2 * INSET + bh)
    local h = math.max(minHeight, S.Get("height"))
    if not f.sizing then f:SetSize(w, h) else w, h = f:GetWidth(), f:GetHeight() end
    local iconSize = math.min(ICON_MAX, bh - ICON_PAD)
    local iconWidth = S.Get("showIcons") and iconSize + ICON_GAP or 0
    fontSize = FitFont(w, fontSize, iconWidth, S.Get("showRanks") and RANK_ROOM or 0)
    local capacity = math.max(1, math.floor((h - top - FOOTER - 2 * INSET + gap) / (bh + gap)))
    first = math.max(0, math.min(first, total - capacity))
    local shown = math.min(total - first, capacity)
    local growUp = S.Get("growUp")
    local statusTop = S.Get("statusPos") == "top"
    local above, below = top + (statusTop and FOOTER or 0), statusTop and 0 or FOOTER
    local texture, font, outline = S.Get("texture"), S.Get("font"), S.Get("outline")
    local last = f.laid
    if not last then last = { gen = 0 }; f.laid = last end
    if f.sizing or Changed(last, w, h, bh, gap, fontSize, iconSize, growUp, above, below, texture, font, outline) then
        Remember(last, w, h, bh, gap, fontSize, iconSize, growUp, above, below, texture, font, outline)
        f.header:SetSize(w, math.max(top, 1))
        f.header:SetShown(top > 0)
        PlaceFooter(f, statusTop, top)
    end
    local m = metrics
    m.gen, m.w, m.bh, m.gap, m.fontSize, m.iconSize, m.iconWidth = last.gen, w, bh, gap, fontSize, iconSize, iconWidth
    m.growUp, m.above, m.below, m.texture, m.font, m.outline = growUp, above, below, texture, font, outline
    m.showRanks, m.showIcons = last.showRanks, last.showIcons
    m.showPercent, m.showValue = last.showPercent, last.showValue
    local rows = f.rows
    for i = 1, shown do
        local row = rows[i] or Look.Row(f, i)
        if row.laid ~= last.gen then LayRow(row, f, i, m) end
        row:Show()
    end
    for i = shown + 1, #rows do rows[i]:Hide() end
    PaintBackground(f, shown)
    PaintRange(f, last, total, first, shown)
    return shown, first
end

function Look.State(me)
    if me and me.tanking then return TEXT_HOLDING end
    if me then return TEXT_TO_PULL:format(me.pullPct) end
    return TEXT_NO_THREAT
end

function Look.Paint(f, shownList, first, shown, title, state)
    local top = shownList[1] and shownList[1].threat or 0
    f.header.text:SetText(title)
    local rank = 0
    for _, e in ipairs(shownList) do
        if not e.isLine then rank = rank + 1 end
        e.rank = rank
    end
    local rowBg = ns.ThemeTint("panel", ROW_BG)
    local showValue, showPercent = S.Get("showValue"), S.Get("showPercent")
    local share = S.Get("percentMode") == "tank" and "tankPct" or "pullPct"
    for i = 1, shown do
        PaintRow(f.rows[i], shownList[first + i], top, rowBg, share, showValue, showPercent)
    end
    f.footer.state:SetText(state)
end

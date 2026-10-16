-- Hud.lua: the HUD look (ns.Shared.Parts): text shadows and fonts, a HUD card's background, a window's soft shadow and a progress line.
local ns = _G.NaowhForever
local T = ns.THEME
local Shared = ns.Shared
local Parts = Shared.Parts
local St = Shared.Style

local BORDER_RGB = St.BORDER_RGB
local HUD_SHADOW = St.HUD_SHADOW_RGB
local HOUSE_SHADOW = { x = St.HUD_SHADOW_X, y = St.HUD_SHADOW_Y, a = St.HUD_SHADOW_ALPHA }
local SHADOWS = {
    card = HOUSE_SHADOW,
    soft = { x = St.HUD_SHADOW_X, y = St.HUD_SHADOW_Y, a = St.HUD_SOFT_SHADOW_ALPHA },
    none = { x = St.HUD_BARE_SHADOW_X, y = St.HUD_BARE_SHADOW_Y, a = St.HUD_BARE_SHADOW_ALPHA },
}
local OUTLINE_NAMES = {
    NONE = "None", [""] = "Shadow", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline", ["OUTLINE, SLUG"] = "Slug Outline",
}
local OUTLINE_ORDER = { "NONE", "", "OUTLINE", "THICKOUTLINE", "OUTLINE, SLUG" }
local BACKGROUND_NAMES = { card = "Card", soft = "Soft", none = "None" }
local BACKGROUND_ORDER = { "card", "soft", "none" }
local NO_OUTLINE = "NONE"
local SHADOW_OUTLINE = ""
local DEFAULT_MODE = "card"
local SOFT_CORNERS = {
    { "TOPLEFT", -1, 1, 0, 0.5, 0, 0.5 },
    { "TOPRIGHT", 1, 1, 0.5, 1, 0, 0.5 },
    { "BOTTOMLEFT", -1, -1, 0, 0.5, 0.5, 1 },
    { "BOTTOMRIGHT", 1, -1, 0.5, 1, 0.5, 1 },
}
local SOFT_SPANS = {
    { 1, "TOPRIGHT", 2, "BOTTOMLEFT", 0.5, 0.5, 0, 0.5 },
    { 3, "TOPRIGHT", 4, "BOTTOMLEFT", 0.5, 0.5, 0.5, 1 },
    { 1, "BOTTOMLEFT", 3, "TOPRIGHT", 0, 0.5, 0.5, 0.5 },
    { 2, "BOTTOMLEFT", 4, "TOPRIGHT", 0.5, 1, 0.5, 0.5 },
    { 1, "BOTTOMRIGHT", 4, "TOPLEFT", 0.5, 0.5, 0.5, 0.5 },
}
local SOFT_SIDES = 4
local PROGRESS_TRACK_ALPHA, PROGRESS_FROM_SHARE, PROGRESS_AHEAD_ALPHA = 1, 0.45, 0.45
local NO_OPTS = {}

local function SoftPiece(pieces, frame, color, alpha, l, r, t, b)
    local tex = Parts.Smooth(frame:CreateTexture(nil, "BACKGROUND"), St.SOFT_SHADE)
    tex:SetTexCoord(l, r, t, b)
    tex:SetVertexColor(color.r, color.g, color.b, alpha)
    pieces[#pieces + 1] = tex
    return tex
end

local function SoftPieces(frame, color, alpha, fade, out, hollow)
    local pieces = {}
    for i = 1, #SOFT_CORNERS do
        local c = SOFT_CORNERS[i]
        local tex = SoftPiece(pieces, frame, color, alpha, c[4], c[5], c[6], c[7])
        tex:SetSize(fade, fade)
        tex:SetPoint(c[1], frame, c[1], c[2] * out, c[3] * out)
    end
    for i = 1, hollow and SOFT_SIDES or #SOFT_SPANS do
        local s = SOFT_SPANS[i]
        local tex = SoftPiece(pieces, frame, color, alpha, s[5], s[6], s[7], s[8])
        tex:SetPoint("TOPLEFT", pieces[s[1]], s[2])
        tex:SetPoint("BOTTOMRIGHT", pieces[s[3]], s[4])
    end
    return pieces
end

local function BuildSoft(backdrop)
    backdrop.soft = SoftPieces(backdrop.frame, backdrop.color, backdrop.softAlpha, backdrop.fade,
        backdrop.fade - backdrop.inset)
end

local function BackdropMode(backdrop, mode)
    if not BACKGROUND_NAMES[mode] then mode = DEFAULT_MODE end
    if backdrop.mode == mode then return mode end
    backdrop.mode = mode
    local card, soft = mode == "card", mode == "soft"
    backdrop.fill:SetShown(card)
    backdrop.border._frame:SetShown(card)
    if soft and not backdrop.soft then BuildSoft(backdrop) end
    local pieces = backdrop.soft
    if pieces then
        for i = 1, #pieces do pieces[i]:SetShown(soft) end
    end
    return mode
end

local function ProgressBar(line)
    local bar = CreateFrame("StatusBar", nil, line)
    bar:SetAllPoints()
    bar:SetStatusBarTexture(St.WHITE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

local function ProgressSet(line, value, ahead)
    value = math.max(0, math.min(1, value))
    line.fill:SetValue(value)
    line.ahead:SetValue(math.min(1, value + math.max(0, ahead or 0)))
end

local function ProgressPaint(line, color, aheadColor)
    local share = PROGRESS_FROM_SHARE
    line.from:SetRGBA(color.r * share, color.g * share, color.b * share, 1)
    line.to:SetRGBA(color.r, color.g, color.b, 1)
    line.fill:GetStatusBarTexture():SetGradient("HORIZONTAL", line.from, line.to)
    local c = aheadColor or color
    line.ahead:SetStatusBarColor(c.r, c.g, c.b, PROGRESS_AHEAD_ALPHA)
end

Parts.HUD_OUTLINES = { OUTLINE_NAMES, OUTLINE_ORDER }
Parts.HUD_BACKGROUNDS = { BACKGROUND_NAMES, BACKGROUND_ORDER }

function Parts.HudText(fs, shadow)
    if shadow == false then
        fs:SetShadowOffset(0, 0)
        fs:SetShadowColor(HUD_SHADOW.r, HUD_SHADOW.g, HUD_SHADOW.b, 0)
        return fs
    end
    local s = SHADOWS[shadow] or HOUSE_SHADOW
    fs:SetShadowOffset(s.x, s.y)
    fs:SetShadowColor(HUD_SHADOW.r, HUD_SHADOW.g, HUD_SHADOW.b, s.a)
    return fs
end

function Parts.HudFlags(outline)
    if outline == NO_OUTLINE or type(outline) ~= "string" then return "" end
    return outline
end

function Parts.HudFont(fs, font, size, outline, background)
    fs:SetFont(ns.UI.FontPath(font), size, Parts.HudFlags(outline))
    return Parts.HudText(fs, outline == SHADOW_OUTLINE and (background or DEFAULT_MODE) or false)
end

function Parts.HudBackdrop(frame, opts)
    opts = opts or NO_OPTS
    local color = opts.color or T.bg
    local backdrop = { frame = frame, color = color, SetMode = BackdropMode,
        softAlpha = opts.softAlpha or St.HUD_SOFT_ALPHA, fade = opts.fade or St.HUD_SOFT_FADE,
        inset = opts.inset or St.HUD_SOFT_INSET }
    backdrop.fill = ns.Solid(frame, "BACKGROUND", color, opts.alpha or St.HUD_CARD_ALPHA)
    backdrop.fill:SetAllPoints()
    backdrop.border = ns.Border(frame, BORDER_RGB)
    BackdropMode(backdrop, opts.mode)
    return backdrop
end

function Parts.Shadow(frame, size, alpha)
    size = size or St.SHADOW_SIZE
    return SoftPieces(frame, BORDER_RGB, alpha or St.SHADOW_ALPHA, size, size, true)
end

function Parts.ProgressLine(parent, height)
    local line = CreateFrame("Frame", nil, parent)
    line:SetHeight(height)
    line.track = ns.Solid(line, "BACKGROUND", T.line, PROGRESS_TRACK_ALPHA)
    line.track:SetAllPoints()
    line.ahead = ProgressBar(line)
    line.fill = ProgressBar(line)
    line.fill:SetFrameLevel(line.ahead:GetFrameLevel() + 1)
    line.from, line.to = CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1)
    line.SetProgress, line.Paint = ProgressSet, ProgressPaint
    ProgressPaint(line, T.accent)
    return line
end

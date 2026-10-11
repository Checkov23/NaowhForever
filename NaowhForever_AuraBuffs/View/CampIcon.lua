-- CampIcon.lua: the campfire art, and the Round look: the camp icon with its time ring and words.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local S = A.Settings
local T = ns.THEME
local St = A.Style
local Parts = ns.Shared.Parts

local PLATE = { r = 0.14, g = 0.15, b = 0.16 }
local RING_RGB = { r = 0, g = 0, b = 0 }
local MASK, RING, ART, ART_CROP = St.CAMP_MASK, St.CAMP_RING, St.CAMP_ART, St.CAMP_ART_CROP
local CLAMP = "CLAMPTOBLACKADDITIVE"
local TEXT_SIZE, LABEL_GAP, BUFF_GAP = St.CAMP_TEXT_SIZE, St.CAMP_LABEL_GAP, St.CAMP_BUFF_GAP
local TRACK_OUT, DRAIN_OUT, RING_OUT = St.CAMP_TRACK_OUT, St.CAMP_DRAIN_OUT, St.CAMP_RING_OUT
local TIME_STEPS = St.CAMP_TIME_STEPS
local ROUND_ART = { "tex", "plate", "ring" }
local ROUND_EXTRAS = { "timer", "drain", "track", "label", "buffs" }
local JUSTIFY = { right = "LEFT", left = "RIGHT" }

local TEXT_REFRESH = ns.L("Refresh Camp")
local TEXT_RESTING = ns.L("Resting")

local Look = {}
A.CampIcon = Look

local function Ring(icon)
    icon.ring = icon:CreateTexture(nil, "BACKGROUND")
    ns.PixelInset(icon.ring, -RING_OUT)
    icon.ring:SetColorTexture(RING_RGB.r, RING_RGB.g, RING_RGB.b, 1)
    icon.ringMask = icon:CreateMaskTexture()
    icon.ringMask:SetAllPoints(icon.ring)
    icon.ringMask:SetTexture(MASK, CLAMP, CLAMP)
    icon.ring:AddMaskTexture(icon.ringMask)
end

function Look.Art(icon, bare)
    icon.tex = Parts.Smooth(icon:CreateTexture(nil, "ARTWORK"), ART)
    icon.tex:SetAllPoints()
    if bare then
        icon.tex:SetTexCoord(ART_CROP[1], ART_CROP[2], ART_CROP[3], ART_CROP[4])
        return
    end
    icon.plate = icon:CreateTexture(nil, "BACKGROUND", nil, 1)
    icon.plate:SetAllPoints()
    local plate = ns.ThemeTint("panel", PLATE)
    icon.plate:SetColorTexture(plate.r, plate.g, plate.b, 1)
    icon.mask = icon:CreateMaskTexture()
    icon.mask:SetAllPoints()
    icon.mask:SetTexture(MASK, CLAMP, CLAMP)
    icon.tex:AddMaskTexture(icon.mask)
    icon.plate:AddMaskTexture(icon.mask)
    Ring(icon)
end

local function NewTimers(icon)
    icon.timer = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.timer:SetAllPoints()
    icon.timer:SetSwipeTexture(MASK)
    icon.timer:SetDrawSwipe(false)
    icon.timer:SetDrawBling(false)
    icon.timer:SetDrawEdge(false)
    icon.timer:SetReverse(true)
    icon.track = icon:CreateTexture(nil, "BACKGROUND")
    icon.track:SetPoint("TOPLEFT", -TRACK_OUT, TRACK_OUT)
    icon.track:SetPoint("BOTTOMRIGHT", TRACK_OUT, -TRACK_OUT)
    icon.track:SetTexture(MASK)
    icon.track:SetVertexColor(RING_RGB.r, RING_RGB.g, RING_RGB.b, 1)
    icon.drain = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.drain:SetPoint("TOPLEFT", -DRAIN_OUT, DRAIN_OUT)
    icon.drain:SetPoint("BOTTOMRIGHT", DRAIN_OUT, -DRAIN_OUT)
    icon.drain:SetSwipeTexture(RING)
    icon.drain:SetDrawEdge(false)
    icon.drain:SetDrawBling(false)
    icon.drain:SetHideCountdownNumbers(true)
end

function Look.New(icon)
    Look.Art(icon)
    NewTimers(icon)
    icon.label = Parts.HudText(ns.Font(icon, TEXT_SIZE, nil, T.accentSoft))
    icon.label:SetPoint("TOP", icon, "BOTTOM", 0, -LABEL_GAP)
    icon.label:SetText(TEXT_REFRESH)
    icon.buffs = Parts.HudText(ns.Font(icon, TEXT_SIZE))
    icon.buffs:SetPoint("TOP", icon, "BOTTOM", 0, -LABEL_GAP)
    icon.buffs:SetJustifyH("CENTER")
end

local function PlaceBuffs(icon, side)
    icon.buffs:SetJustifyH(JUSTIFY[side] or "CENTER")
    if side == "right" then
        icon.buffs:SetPoint("LEFT", icon, "RIGHT", BUFF_GAP, 0)
    elseif side == "left" then
        icon.buffs:SetPoint("RIGHT", icon, "LEFT", -BUFF_GAP, 0)
    elseif side == "above" then
        icon.buffs:SetPoint("BOTTOM", icon, "TOP", 0, BUFF_GAP)
    else
        icon.buffs:SetPoint("TOP", icon, "BOTTOM", 0, -BUFF_GAP)
    end
end

function Look.Layout(icon)
    local size = S.Get("campIconSize")
    icon:SetSize(size, size)
    local font, outline = S.Get("campFont"), S.Get("campOutline")
    Parts.HudFont(icon.label, font, TEXT_SIZE, outline)
    Parts.HudFont(icon.buffs, font, S.Get("campBuffTextSize"), outline)
    icon.buffs:ClearAllPoints()
    PlaceBuffs(icon, S.Get("campBuffSide"))
end

function Look.Shown(icon, on)
    for i = 1, #ROUND_ART do icon[ROUND_ART[i]]:SetShown(on) end
    if on then return end
    for i = 1, #ROUND_EXTRAS do icon[ROUND_EXTRAS[i]]:Hide() end
end

function Look.Step(left)
    for _, step in ipairs(TIME_STEPS) do
        if left > step[1] or step[1] == 0 then return step end
    end
end

function Look.Timed(icon, on)
    icon.timer:SetShown(on)
    icon.drain:SetShown(on)
    icon.track:SetShown(on)
end

function Look.Up(icon, buffs)
    icon.tex:SetDesaturated(false)
    icon.label:Hide()
    icon.buffs:SetText(buffs)
    icon.buffs:Show()
end

function Look.Sitting(icon)
    icon.tex:SetDesaturated(false)
    icon.label:SetText(TEXT_RESTING)
    icon.label:Show()
    icon.buffs:Hide()
end

function Look.Missing(icon)
    icon.tex:SetDesaturated(true)
    icon.label:SetText(TEXT_REFRESH)
    icon.label:Show()
    icon.buffs:Hide()
    Look.Timed(icon, false)
end

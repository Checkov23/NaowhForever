-- CampIcon.lua: the campfire art, and the Round look: the camp icon with its time ring and words, and the Sleeping Bag beside it.
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
local LABEL_DROP = TRACK_OUT + LABEL_GAP
local SIT_HOT = St.CAMP_SIT_HOT
local BAG_SCALE, BAG_GAP, BAG_TEXT_SIZE, BAG_CROP = St.CAMP_BAG_SCALE, St.CAMP_BAG_GAP, St.CAMP_BAG_TEXT_SIZE,
    St.CAMP_BAG_CROP
local BAG_COUNT_SIZE, BAG_COUNT_INSET = St.CAMP_BAG_COUNT_SIZE, St.CAMP_BAG_COUNT_INSET
local ROUND_ART = { "tex", "plate", "ring" }
local ROUND_EXTRAS = { "timer", "drain", "track", "label", "buffs" }
local JUSTIFY = { right = "LEFT", left = "RIGHT" }

local TEXT_REFRESH = ns.L("Refresh Camp")
local TEXT_CLICK_SIT = ns.L("Click to sit")
local TEXT_RESTING = ns.L("Resting")
local TEXT_SLEEPING_BAG = ns.L("Sleeping Bag")

local Look = { LABEL_DROP = LABEL_DROP }
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

function Look.Art(icon, bare, art)
    icon.tex = Parts.Smooth(icon:CreateTexture(nil, "ARTWORK"), not art and ART or nil)
    if art then icon.tex:SetTexture(art) end
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

function Look.Hot(fire, on)
    if not fire.hot then
        if not on then return end
        fire.hot = Parts.Smooth(fire:CreateTexture(nil, "OVERLAY"), ART)
        fire.hot:SetAllPoints(fire.tex)
        fire.hot:SetTexCoord(fire.tex:GetTexCoord())
        fire.hot:SetBlendMode("ADD")
        fire.hot:SetAlpha(SIT_HOT)
        if fire.mask then fire.hot:AddMaskTexture(fire.mask) end
    end
    fire.hot:SetShown(on)
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
    icon.label:SetPoint("TOP", icon, "BOTTOM", 0, -LABEL_DROP)
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

function Look.NewBag(bag, art)
    Look.Art(bag, nil, art)
    bag.tex:SetTexCoord(BAG_CROP, 1 - BAG_CROP, BAG_CROP, 1 - BAG_CROP)
    bag.label = Parts.HudText(ns.Font(bag, BAG_TEXT_SIZE, nil, T.accentSoft))
    bag.label:SetPoint("TOP", bag, "BOTTOM", 0, -LABEL_DROP)
    bag.label:SetText(TEXT_SLEEPING_BAG)
    bag.cooldown = CreateFrame("Cooldown", nil, bag, "CooldownFrameTemplate")
    bag.cooldown:SetAllPoints()
    bag.cooldown:SetSwipeTexture(MASK)
    bag.cooldown:SetDrawBling(false)
    bag.cooldown:SetDrawEdge(false)
    bag.cooldown:Hide()
    NewTimers(bag)
    bag.count = Parts.HudText(ns.Font(bag.timer, BAG_COUNT_SIZE, "OUTLINE"))
    bag.count:SetPoint("BOTTOMRIGHT", bag, "BOTTOMRIGHT", BAG_COUNT_INSET, -BAG_COUNT_INSET)
    bag.count:Hide()
    Look.Timed(bag, false)
end

function Look.BagCooldown(bag, start, duration)
    local on = start ~= nil
    bag.tex:SetDesaturated(on)
    if on then bag.cooldown:SetCooldown(start, duration) end
    bag.cooldown:SetShown(on)
end

function Look.BagRested(bag, expiry, duration, stacks)
    local on = expiry ~= nil
    Look.Timed(bag, on)
    bag.count:SetShown(on and stacks > 0)
    bag.cooldown:SetHideCountdownNumbers(on)
    if not on then
        bag.restedEnd = nil
        return
    end
    bag.count:SetText(stacks)
    if bag.restedEnd == expiry then return end
    bag.restedEnd = expiry
    bag.timer:SetCooldownFromExpirationTime(expiry, duration)
    bag.drain:SetCooldownFromExpirationTime(expiry, duration)
    bag.drain:SetSwipeColor(T.accent.r, T.accent.g, T.accent.b, 1)
end

function Look.BagLayout(bag)
    local size = S.Get("campIconSize") * BAG_SCALE
    bag:SetSize(size, size)
    Parts.HudFont(bag.label, S.Get("campFont"), BAG_TEXT_SIZE, S.Get("campOutline"))
end

function Look.BagSpot(icon, bag)
    local x, y = icon:GetCenter()
    if not x then return end
    local reach = (icon:GetWidth() + bag:GetWidth()) / 2 + TRACK_OUT * 2 + BAG_GAP
    if S.Get("campBuffSide") == "right" and ns.CampBuffMode() == "always" and icon:IsShown() and icon.buffs:IsShown() then
        reach = -reach
    end
    return x + reach, y - icon:GetHeight() / 2
end

function Look.Missing(icon, sit)
    icon.tex:SetDesaturated(not sit)
    icon.label:SetText(sit and TEXT_CLICK_SIT or TEXT_REFRESH)
    icon.label:Show()
    icon.buffs:Hide()
    Look.Timed(icon, false)
end

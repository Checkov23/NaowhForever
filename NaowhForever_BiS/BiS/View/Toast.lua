-- Toast.lua: Drop Alert's on-screen alert, live and in its preview (B.Toast).
local ns = _G.NaowhForever

local T = ns.THEME
local B = ns.BiS
local S = B.Settings
local Shared = ns.Shared
local Items, Parts = Shared.Items, Shared.Parts
local St = B.Style

local W, H = St.TOAST_W, 54
local ICON, PAD, STAR = 38, 8, 16
local DETAIL_SMALLER = 2
local STAR_LIFT = 5
local STAR_GAP = St.STAR_GAP
local STAR_IN = 2
local NAME_DROP = 2
local DETAIL_Y = 2
local GLOW_OUT = 3
local GLOW_LAYER = -2
local GLOW_ALPHA = 0.35
local ROUND = B.C.ROUND
local STACK_GAP = 6
local MAX_SHOWN = 3
local FADE = 0.3
local HOLDER_TOP = 160
local BLACK = St.BORDER_RGB
local DOT = "  \194\183  "
local GLOW_TEXTURE = St.WHITE
local HOLDER_NAME = "NaowhForeverBiSDropAlert"
local MOVER_LABEL = "BiS Drop Alert"
local PAGE, CARD = "BiS List/Settings", "BiS List/Settings:dropAlert"
local TEXT_PICK = "Your #%d pick"
local RANK_WORDS = { "Your BiS", "Your second pick" }
local EVENTS = {
    roll = { "Up for a roll", T.accentSoft }, dropped = { "Dropped", T.fg }, yours = { "Yours!", St.HAVE_RGB },
}

local parts = {}
local holder, shown, pool = nil, {}, {}

local function Gain(id, slot)
    local SW, spec = ns.StatWeights, B.Lists.CurrentSpec()
    local weights = SW and spec and SW.For(spec.key)
    if not (weights and slot) then return nil end
    local gain = SW.Gain(id, slot, weights, SW.Power(weights))
    return gain and gain >= SW.MIN_GAIN and gain or nil
end

local function AddSource(id)
    local source = ns.BiSSource(id)
    if source then parts[#parts + 1] = Parts.Plain(source) end
end

local function Detail(id, rank, event, slot)
    wipe(parts)
    if S.Get("bisToastEvent") then
        local what = EVENTS[event]
        parts[#parts + 1] = ns.Color(what[2], what[1])
    end
    if S.Get("bisToastRank") then
        parts[#parts + 1] = ns.Color(Parts.RankColor(rank), RANK_WORDS[rank] or TEXT_PICK:format(rank))
    end
    if S.Get("bisToastSlot") and slot then parts[#parts + 1] = Items.SlotName(slot) end
    if S.Get("bisToastSource") then AddSource(id) end
    local gain = S.Get("bisToastGain") and Gain(id, slot)
    if gain then parts[#parts + 1] = St.UPGRADE_CODE .. "+" .. math.floor(gain + ROUND) .. "%|r" end
    return table.concat(parts, DOT)
end

local function BorderColor(id, rank)
    local border = S.Get("bisToastBorder")
    if border == "quality" then return Items.QualityColor(id) or BLACK end
    if border == "rank" then return Parts.RankColor(rank) end
    if border == "black" then return BLACK end
    return nil
end

local function PlaceStar(f, place)
    f.star:SetShown(place ~= "none")
    f.star:ClearAllPoints()
    f.name:ClearAllPoints()
    if place == "name" then
        f.star:SetPoint("TOPLEFT", f.iconFrame, "TOPRIGHT", PAD, 0)
        f.name:SetPoint("LEFT", f.star, "RIGHT", STAR_GAP, 0)
    else
        if place == "iconRight" then
            f.star:SetPoint("CENTER", f.iconFrame, "TOPRIGHT", -STAR_IN, -STAR_IN)
        else
            f.star:SetPoint("CENTER", f.iconFrame, "TOPLEFT", STAR_IN, -STAR_IN)
        end
        f.name:SetPoint("TOPLEFT", f.iconFrame, "TOPRIGHT", PAD, -NAME_DROP)
    end
    f.name:SetPoint("RIGHT", -PAD, 0)
end

local function PaintLook(f, id, rank)
    f:SetScale(S.Get("bisToastScale"))
    f.bg:SetAlpha(S.Get("bisToastAlpha"))
    local font, size, outline = S.Get("bisToastFont"), S.Get("bisToastFontSize"), S.Get("bisToastOutline")
    Parts.HudFont(f.name, font, size, outline)
    Parts.HudFont(f.detail, font, size - DETAIL_SMALLER, outline)
    local border = BorderColor(id, rank) or BLACK
    f.edge:SetColor(border.r, border.g, border.b, S.Get("bisToastBorder") == "none" and 0 or 1)
    local glow = S.Get("bisToastGlow") and Parts.RankColor(rank)
    f.glow:SetShown(glow ~= nil and glow ~= false)
    if glow then f.glow:SetVertexColor(glow.r, glow.g, glow.b, GLOW_ALPHA) end
end

local function Place()
    local pos = S.Get("bisToastPos")
    holder:ClearAllPoints()
    if pos then
        holder:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        holder:SetPoint("TOP", UIParent, "TOP", 0, -HOLDER_TOP)
    end
    holder:SetScale(S.Get("bisToastScale"))
end

local function Restack()
    for i, f in ipairs(shown) do
        f:ClearAllPoints()
        f:SetPoint("TOP", holder, "TOP", 0, -(i - 1) * (H + STACK_GAP))
    end
end

local function Release(f)
    f:Hide()
    for i, other in ipairs(shown) do
        if other == f then
            table.remove(shown, i)
            break
        end
    end
    pool[#pool + 1] = f
    Restack()
end

local function Finished(group)
    Release(group:GetParent())
end

local function Fade(group, from, to, order)
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(from)
    fade:SetToAlpha(to)
    fade:SetDuration(FADE)
    fade:SetOrder(order)
    return fade
end

local function SaveSpot(pos)
    S.Set("bisToastPos", pos)
end

local function Holder()
    if holder then return holder end
    holder = CreateFrame("Frame", HOLDER_NAME, UIParent)
    holder:SetSize(W, H)
    holder:SetFrameStrata("HIGH")
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    holder.mover = ns.UI.AttachMover(holder, MOVER_LABEL, SaveSpot, PAGE, CARD)
    return holder
end

local function Unlock(on)
    if not (on and B.On() and S.Get("bisLootAlert") and S.Get("bisToast")) then
        if holder then holder.mover:Hide() end
        return
    end
    Holder()
    Place()
    holder.mover:Show()
end

local function Glow(f)
    f.glow = f:CreateTexture(nil, "BACKGROUND", nil, GLOW_LAYER)
    f.glow:SetTexture(GLOW_TEXTURE)
    f.glow:SetPoint("TOPLEFT", -GLOW_OUT, GLOW_OUT)
    f.glow:SetPoint("BOTTOMRIGHT", GLOW_OUT, -GLOW_OUT)
end

local function Star(f, icon)
    f.overlay = CreateFrame("Frame", nil, f)
    f.overlay:SetAllPoints()
    f.overlay:SetFrameLevel(icon:GetFrameLevel() + STAR_LIFT)
    f.star = f.overlay:CreateTexture(nil, "OVERLAY")
    f.star:SetTexture(St.STAR)
    f.star:SetSize(STAR, STAR)
end

local Toast = {}
B.Toast = Toast
Toast.EVENTS = EVENTS

function Toast.New(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(W, H)
    Glow(f)
    f.bg = ns.Solid(f, "BACKGROUND", T.bg, 1)
    f.bg:SetAllPoints()
    f.edge = ns.Border(f, BLACK)
    local icon = Parts.ItemIcon(f, ICON)
    icon:SetPoint("LEFT", PAD, 0)
    f.iconFrame, f.icon = icon, icon.texture
    Star(f, icon)
    f.name = ns.Font(f, St.NAME_SIZE)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.detail = ns.Font(f, St.SMALL_SIZE, nil, T.muted)
    f.detail:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", PAD, DETAIL_Y)
    f.detail:SetPoint("RIGHT", -PAD, 0)
    f.detail:SetJustifyH("LEFT")
    f.detail:SetWordWrap(false)
    return f
end

function Toast.Paint(f, item, rank, event)
    local id = Items.IDFrom(item)
    local slot = B.Lists.SlotOf(id)
    PaintLook(f, id, rank)
    f.icon:SetTexture(C_Item.GetItemIconByID(id))
    Parts.MarkForever(f.iconFrame, id)
    local color = Parts.RankColor(rank)
    f.star:SetVertexColor(color.r, color.g, color.b)
    PlaceStar(f, S.Get("bisToastStar"))
    f.name:SetText(Items.QualityHex(id) .. Items.Name(id) .. "|r")
    f.detail:SetText(Detail(id, rank, event, slot))
end

local function NewLive()
    local f = Toast.New(holder)
    f:SetScale(1)
    f.fade = f:CreateAnimationGroup()
    Fade(f.fade, 0, 1, 1)
    f.fadeOut = Fade(f.fade, 1, 0, 2)
    f.fade:SetScript("OnFinished", Finished)
    return f
end

function Toast.Show(item, rank, event)
    Holder()
    Place()
    local f = table.remove(pool) or NewLive()
    if #shown >= MAX_SHOWN then
        shown[1].fade:Stop()
        Release(shown[1])
    end
    Toast.Paint(f, item, rank, event)
    f:SetScale(1)
    shown[#shown + 1] = f
    Restack()
    f.fadeOut:SetStartDelay(S.Get("bisToastTime"))
    f:Show()
    f.fade:Stop()
    f.fade:Play()
end

hooksecurefunc(ns, "ShowUnlockMode", function() Unlock(true) end)
hooksecurefunc(ns, "HideUnlockMode", function() Unlock(false) end)

-- LowHealthLook.lua: the Low Health icon and its warning, the same on screen and on the card's preview.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local S = A.Settings
local St = A.Style
local Parts = ns.Shared.Parts

local CROP = St.LOW_CROP
local COUNT_SIZE, COUNT_INSET = St.LOW_COUNT_SIZE, St.LOW_COUNT_INSET
local LABEL_SIZE, LABEL_GAP = St.LOW_LABEL_SIZE, St.LOW_LABEL_GAP
local FALLBACK_ICON = St.LOW_FALLBACK_ICON
local TEXT_LOW = ns.L("LOW HEALTH")

local Look = {}
A.LowHealthLook = Look

function Look.New(frame)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints()
    frame.icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
    ns.Border(frame, St.BLACK)
    frame.count = ns.Font(frame, COUNT_SIZE, "OUTLINE")
    frame.count:SetPoint("BOTTOMRIGHT", -COUNT_INSET, COUNT_INSET)
    frame.label = ns.Font(frame, LABEL_SIZE, "OUTLINE", St.LOW_RGB)
    frame.label:SetPoint("TOP", frame, "BOTTOM", 0, -LABEL_GAP)
    frame.label:SetText(TEXT_LOW)
end

function Look.Style(frame)
    local font, outline = S.Get("lowHealthFont"), S.Get("lowHealthOutline")
    Parts.HudFont(frame.label, font, S.Get("lowHealthFontSize"), outline)
    Parts.HudFont(frame.count, font, COUNT_SIZE, outline)
end

function Look.Count(frame, count)
    frame.count:SetText(count > 1 and count or "")
end

function Look.Item(frame, id, count)
    Look.Count(frame, count)
    frame.icon:SetTexture(id and C_Item.GetItemIconByID(id) or FALLBACK_ICON)
    frame.icon:SetDesaturated(id == nil)
end

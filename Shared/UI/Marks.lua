-- Marks.lua: an item's marks (ns.Shared.Parts): rank stars and lines, the upgrade line, Forever's mark, the item icon, its slot marks and its corner badge.
local ns = _G.NaowhForever
local T = ns.THEME
local Shared = ns.Shared
local Parts = Shared.Parts
local St = Shared.Style

local Inline, Smooth = Parts.Inline, Parts.Smooth

local STAR, PLACE_DOT, BORDER_RGB = St.STAR, St.PLACE_DOT, St.BORDER_RGB
local FOREVER, FOREVER_RGB = St.FOREVER, St.FOREVER_RGB
local RANK_RGB = { St.BIS_RGB, St.SECOND_RGB, St.THIRD_RGB }
local COLOR_SCALE = 255
local COLOR_TEXT = "|cff%02x%02x%02x%s|r"
local RANK_NUMBER = "#"
local FOREVER_TEXT = " |T%s:%d:%d:0:%d:32:16:0:32:0:16:%d:%d:%d|t"
local FOREVER_WIDE = 2
local FOREVER_KEY = 100
local FOREVER_LINE_SIZE = 12
local UPGRADE_ICON = "|A:%s:0:0:0:%d|a"
local ICON_CROP_IN, ICON_CROP_OUT = St.ICON_CROP, St.ICON_CROP_HIGH
local CLASS_CROP = St.CLASS_CROP
local ICON_OVER_LEVEL = 3
local ICON_EDGE = 1
local FOREVER_MIN, FOREVER_SHARE = 7, 0.32
local MARK_SIZE, MARK_IN = 13, 2
local MARK_LEVEL = 4
local SHADE_SHARE, SHADE_ALPHA = 0.5, 0.8
local MARK_STAR_DROP = -1
local MARK_UP = 14
local BADGE_SIZE, BADGE_ART, BADGE_ALPHA, BADGE_IN = 14, 12, 0.75, 1
local TEXT_BIS = ns.L("Your BiS")
local TEXT_SECOND = ns.L("Your second pick")
local TEXT_RANKED = ns.L("#%d on your BiS list")
local TEXT_UPGRADE = ns.L("% upgrade|r")
local TEXT_NEW = ns.L("New in WoW Forever|r")

local marks = {}
local foreverText = {}
local upgradeArrow, foreverLine

local function RankWords(rank)
    if rank == 1 then return TEXT_BIS end
    if rank == 2 then return TEXT_SECOND end
    return TEXT_RANKED:format(rank)
end

local function Colored(color, text)
    return COLOR_TEXT:format(color.r * COLOR_SCALE, color.g * COLOR_SCALE, color.b * COLOR_SCALE, text)
end

local function MarksAt(drop)
    local byRank = marks[drop]
    if byRank then return byRank end
    byRank = {}
    marks[drop] = byRank
    return byRank
end

local function IconForever(over, size)
    local h = math.max(FOREVER_MIN, math.floor(size * FOREVER_SHARE))
    local sign = Smooth(over:CreateTexture(nil, "OVERLAY"), St.FOREVER_ICON)
    sign:SetVertexColor(FOREVER_RGB.r, FOREVER_RGB.g, FOREVER_RGB.b)
    sign:SetSize(h * FOREVER_WIDE, h)
    sign:SetPoint("TOPLEFT", ICON_EDGE, -ICON_EDGE)
    sign:Hide()
    return sign
end

local function Shade(set, size)
    local shade = set:CreateTexture(nil, "ARTWORK")
    shade:SetColorTexture(1, 1, 1, 1)
    shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, SHADE_ALPHA), CreateColor(0, 0, 0, 0))
    shade:SetPoint("BOTTOMLEFT", ICON_EDGE, ICON_EDGE)
    shade:SetPoint("BOTTOMRIGHT", -ICON_EDGE, ICON_EDGE)
    shade:SetHeight(size * SHADE_SHARE)
    return shade
end

local function UpgradeArrow(set)
    local up = set:CreateTexture(nil, "OVERLAY")
    up:SetAtlas(St.UPGRADE_ATLAS)
    up:SetSize(MARK_UP, MARK_UP)
    up:SetPoint("TOPRIGHT", -ICON_EDGE, -ICON_EDGE)
    up:Hide()
    return up
end

Parts.MARK_IN = MARK_IN

function Parts.RankColor(rank)
    return RANK_RGB[rank] or T.muted
end

function Parts.RankMark(rank, drop)
    if not rank then return "" end
    drop = drop or Parts.TOOLTIP_DROP
    local byRank = MarksAt(drop)
    local mark = byRank[rank]
    if mark then return mark end
    mark = RANK_RGB[rank] and Inline(STAR, RANK_RGB[rank], drop) or ns.Color("muted", RANK_NUMBER .. rank)
    byRank[rank] = mark
    return mark
end

function Parts.RankLine(rank, listName)
    local mark = RANK_RGB[rank] and Parts.RankMark(rank) .. " " or ""
    return mark .. Colored(Parts.RankColor(rank), RankWords(rank))
        .. (listName and ns.Color("muted", PLACE_DOT .. listName) or "")
end

function Parts.UpgradeLine(gain, specName)
    upgradeArrow = upgradeArrow or UPGRADE_ICON:format(St.UPGRADE_ATLAS, -Parts.TOOLTIP_DROP)
    return upgradeArrow .. " " .. St.UPGRADE_CODE .. "+" .. math.floor(gain + 0.5) .. TEXT_UPGRADE
        .. (specName and ns.Color("muted", PLACE_DOT .. specName) or "")
end

function Parts.IsForever(kind, id)
    local new = Shared.ForeverNew
    return id ~= nil and new ~= nil and new[kind][id] == true
end

function Parts.ForeverInline(height, drop)
    drop = drop or Parts.TOOLTIP_DROP
    local key = height * FOREVER_KEY + drop
    local text = foreverText[key]
    if text then return text end
    text = FOREVER_TEXT:format(FOREVER, height, height * FOREVER_WIDE, -drop,
        FOREVER_RGB.r * COLOR_SCALE, FOREVER_RGB.g * COLOR_SCALE, FOREVER_RGB.b * COLOR_SCALE)
    foreverText[key] = text
    return text
end

function Parts.ForeverMark(parent, height)
    local mark = Smooth(parent:CreateTexture(nil, "OVERLAY"), FOREVER)
    mark:SetVertexColor(FOREVER_RGB.r, FOREVER_RGB.g, FOREVER_RGB.b)
    mark:SetSize(height * FOREVER_WIDE, height)
    return mark
end

function Parts.ForeverLine()
    if not foreverLine then
        foreverLine = Parts.ForeverInline(FOREVER_LINE_SIZE):sub(2) .. " " .. St.FOREVER_CODE .. TEXT_NEW
    end
    return foreverLine
end

function Parts.ItemIcon(parent, size)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size, size)
    frame.edge = ns.Border(frame, BORDER_RGB)
    frame.texture = Smooth(frame:CreateTexture(nil, "ARTWORK"))
    ns.PixelInset(frame.texture, ICON_EDGE)
    frame.texture:SetTexCoord(ICON_CROP_IN, ICON_CROP_OUT, ICON_CROP_IN, ICON_CROP_OUT)
    local over = CreateFrame("Frame", nil, frame)
    over:SetAllPoints()
    over:SetFrameLevel(frame:GetFrameLevel() + ICON_OVER_LEVEL)
    frame.forever = IconForever(over, size)
    return frame
end

function Parts.ClassCrop(texture, coords)
    texture:SetTexCoord(coords[1] + CLASS_CROP, coords[2] - CLASS_CROP, coords[3] + CLASS_CROP, coords[4] - CLASS_CROP)
end

function Parts.MarkForever(icon, itemID)
    icon.forever:SetShown(Parts.IsForever("items", itemID))
end

function Parts.ItemMarks(icon, size)
    local set = CreateFrame("Frame", nil, icon)
    set:SetAllPoints()
    set:SetFrameLevel(icon:GetFrameLevel() + MARK_LEVEL)
    set.shade = Shade(set, size)
    set.level = ns.Font(set, MARK_SIZE, "OUTLINE", T.fg)
    set.level:SetPoint("BOTTOMRIGHT", -MARK_IN, MARK_IN)
    set.rank = ns.Font(set, MARK_SIZE, "OUTLINE", T.fg)
    set.rank:SetPoint("BOTTOMLEFT", MARK_IN, MARK_IN)
    set.forever = icon.forever or IconForever(set, size)
    set.up = UpgradeArrow(set)
    return set
end

function Parts.PaintItemMarks(set, level, rank, forever, upgrade)
    local shown = level and level > 1 or false
    set.level:SetText(shown and level or "")
    set.rank:SetText(rank and Parts.RankMark(rank, MARK_STAR_DROP) or "")
    set.forever:SetShown(forever == true)
    set.up:SetShown(upgrade == true)
    set.shade:SetShown(shown or rank ~= nil)
    return shown
end

function Parts.SizeItemMarks(set, size)
    set.shade:SetHeight(size * SHADE_SHARE)
end

function Parts.ItemBadge(set, corner, atlas, color)
    local badge = CreateFrame("Frame", nil, set)
    badge:SetSize(BADGE_SIZE, BADGE_SIZE)
    badge:SetPoint(corner, corner == "TOPLEFT" and BADGE_IN or -BADGE_IN, -BADGE_IN)
    badge.back = Smooth(badge:CreateTexture(nil, "BACKGROUND"), St.ROUND)
    badge.back:SetAllPoints()
    badge.back:SetVertexColor(BORDER_RGB.r, BORDER_RGB.g, BORDER_RGB.b, BADGE_ALPHA)
    badge.art = Smooth(badge:CreateTexture(nil, "ARTWORK"))
    badge.art:SetAtlas(atlas)
    badge.art:SetSize(BADGE_ART, BADGE_ART)
    badge.art:SetPoint("CENTER")
    if color then badge.art:SetVertexColor(color.r, color.g, color.b) end
    badge:Hide()
    return badge
end

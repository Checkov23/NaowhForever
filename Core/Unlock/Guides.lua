-- Guides.lua: the HUD Editor's guides, drag outline and anchor line, drawn over the screen.
local ns = _G.NaowhForever
local T = ns.THEME
local H = ns.HudEditor

local placement = H.placement
local Pixel, Box, Grouped = H.Pixel, H.Box, H.Grouped
local IsHidden, Follows, AnchorOf, Gap = H.IsHidden, H.Follows, H.AnchorOf, H.Gap

local ROUND = H.C.ROUND
local GUIDE_SNAP = 6
local GUIDE_LEVEL = 220
local LABEL_PAD, LABEL_H, LABEL_SIZE = 4, 16, 11
local OUTLINE_ALPHA = 0.45
local TAB_W, TAB_H, TAB_HIT = 10, 7, 4
local TAB_SIDES = { "TOP", "LEFT", "RIGHT", "BOTTOM" }
local EDGE_PAIRS_FIRST, EDGE_PAIRS_LAST, EDGE_PAIRS_STEP = 1, 4, 3
local TEXT_TAB_HELP = ns.L("Anchors to this side.")

local overlay, tabs

local function NewLayer() return { lines = {}, labels = {}, used = 0, usedLabels = 0 } end
local dragLayer, anchorLayer, groupLayer = NewLayer(), NewLayer(), NewLayer()

local function Overlay()
    if not overlay then
        overlay = CreateFrame("Frame", nil, UIParent)
        overlay:SetAllPoints(UIParent)
        overlay:SetFrameStrata("FULLSCREEN_DIALOG")
        overlay:SetFrameLevel(GUIDE_LEVEL)
    end
    return overlay
end

local function Clear(layer)
    for i = 1, layer.used do layer.lines[i]:Hide() end
    for i = 1, layer.usedLabels do layer.labels[i]:Hide() end
    layer.used, layer.usedLabels = 0, 0
end

local function DrawLine(layer, x1, y1, x2, y2, c, alpha)
    layer.used = layer.used + 1
    local tex = layer.lines[layer.used]
    if not tex then
        tex = Overlay():CreateTexture(nil, "OVERLAY")
        layer.lines[layer.used] = tex
    end
    local px = Pixel()
    tex:SetColorTexture(c.r, c.g, c.b, alpha or 1)
    tex:ClearAllPoints()
    tex:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", math.min(x1, x2), math.min(y1, y2))
    tex:SetSize(math.max(px, math.abs(x2 - x1)), math.max(px, math.abs(y2 - y1)))
    tex:Show()
end

local function NewLabel()
    local label = CreateFrame("Frame", nil, Overlay())
    label.fill = ns.Solid(label, "BACKGROUND", T.bg, 1)
    label.fill:SetAllPoints()
    label.text = ns.Font(label, LABEL_SIZE)
    label.text:SetPoint("CENTER")
    return label
end

local function DrawLabel(layer, x, y, length, c, textColor)
    layer.usedLabels = layer.usedLabels + 1
    local label = layer.labels[layer.usedLabels]
    if not label then
        label = NewLabel()
        layer.labels[layer.usedLabels] = label
    end
    label.fill:SetColorTexture(c.r, c.g, c.b, 1)
    label.text:SetTextColor(textColor.r, textColor.g, textColor.b, 1)
    label.text:SetText(tostring(math.floor(length / Pixel() + ROUND)))
    label:SetSize(label.text:GetStringWidth() + 2 * LABEL_PAD, LABEL_H)
    label:ClearAllPoints()
    label:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    label:Show()
end

local function GuidesOn() return ns.UnlockModeSettings.Get("guides") ~= false end

local function Guiding(item, other)
    return other ~= item and other.handle:IsVisible() and not IsHidden(other) and not Follows(other.label, item.label)
        and not (other.selected and Grouped())
end

local function Middle(a1, a2, b1, b2)
    local lo, hi = math.max(a1, b1), math.min(a2, b2)
    if lo <= hi then return (lo + hi) / 2 end
    return (a1 + a2) / 2
end

local function Nearer(best, ours, theirs, reach)
    local d = theirs - ours
    if math.abs(d) <= reach and (not best or math.abs(d) < math.abs(best)) then return d end
    return best
end

local function Pull(best, reach, a1, a2, a3, b1, b2, b3)
    best = Nearer(Nearer(Nearer(best, a1, b1, reach), a1, b2, reach), a1, b3, reach)
    best = Nearer(Nearer(Nearer(best, a2, b1, reach), a2, b2, reach), a2, b3, reach)
    return Nearer(Nearer(Nearer(best, a3, b1, reach), a3, b2, reach), a3, b3, reach)
end

local function InLine(item, a1, a2, horizontal)
    local line = {}
    for _, other in ipairs(placement.items) do
        if Guiding(item, other) then
            local l, r, t, b = Box(other)
            if l then
                local o = horizontal and { l, r, b, t } or { b, t, l, r }
                if o[3] < a2 and o[4] > a1 then line[#line + 1] = o end
            end
        end
    end
    return line
end

local function MirrorSpot(spots, p, mid, size, across)
    if p[2] < mid then
        local at = 2 * mid - p[2]
        spots[#spots + 1] = { at = at, p[2], mid, across, mid, at, across }
    elseif p[1] > mid then
        local at = 2 * mid - p[1] - size
        spots[#spots + 1] = { at = at, at + size, mid, across, mid, p[1], across }
    end
end

local function PairSpots(spots, p, q, size, a1, a2, across)
    local gap = q[1] - p[2]
    if gap <= 0 then return end
    local pair = Middle(p[3], p[4], q[3], q[4])
    local qAcross = Middle(a1, a2, q[3], q[4])
    if gap > size then
        local at = (p[2] + q[1] - size) / 2
        spots[#spots + 1] = { at = at, p[2], at, across, at + size, q[1], qAcross }
    end
    spots[#spots + 1] = { at = q[2] + gap, p[2], q[1], pair, q[2], q[2] + gap, qAcross }
    spots[#spots + 1] = { at = p[1] - gap - size, p[2], q[1], pair, p[1] - gap, p[1], across }
end

local function EvenSpots(item, lo, hi, a1, a2, horizontal)
    local size = hi - lo
    local mid = (horizontal and UIParent:GetWidth() or UIParent:GetHeight()) / 2
    local line, spots = InLine(item, a1, a2, horizontal), {}
    for _, p in ipairs(line) do
        local across = Middle(a1, a2, p[3], p[4])
        MirrorSpot(spots, p, mid, size, across)
        for _, q in ipairs(line) do PairSpots(spots, p, q, size, a1, a2, across) end
    end
    return spots
end

local function SnapBy(item, l, r, t, b)
    local reach = GUIDE_SNAP * Pixel()
    local cx, cy = (l + r) / 2, (t + b) / 2
    local dx = Nearer(nil, cx, UIParent:GetWidth() / 2, reach)
    local dy = Nearer(nil, cy, UIParent:GetHeight() / 2, reach)
    for _, other in ipairs(placement.items) do
        if Guiding(item, other) then
            local ol, oright, ot, ob = Box(other)
            if ol then
                dx = Pull(dx, reach, l, cx, r, ol, (ol + oright) / 2, oright)
                dy = Pull(dy, reach, b, cy, t, ob, (ot + ob) / 2, ot)
            end
        end
    end
    for _, spot in ipairs(EvenSpots(item, l, r, b, t, true)) do dx = Nearer(dx, l, spot.at, reach) end
    for _, spot in ipairs(EvenSpots(item, b, t, l, r, false)) do dy = Nearer(dy, b, spot.at, reach) end
    return dx, dy
end

local function OnOne(near, a1, a2, a3, b1, b2, b3)
    for i = 1, 3 do
        local a = i == 1 and a1 or i == 2 and a2 or a3
        if math.abs(a - b1) <= near or math.abs(a - b2) <= near or math.abs(a - b3) <= near then return a end
    end
end

local function DrawEdgeGuides(l, r, t, b, ol, oright, ot, ob, c, near)
    local cx, cy = (l + r) / 2, (t + b) / 2
    local x = OnOne(near, l, cx, r, ol, (ol + oright) / 2, oright)
    if x then
        DrawLine(dragLayer, x, math.min(b, ob), x, math.max(t, ot), c)
        if ob - t > near then DrawLabel(dragLayer, x, (t + ob) / 2, ob - t, c, T.bg)
        elseif b - ot > near then DrawLabel(dragLayer, x, (ot + b) / 2, b - ot, c, T.bg) end
    end
    local y = OnOne(near, b, cy, t, ob, (ot + ob) / 2, ot)
    if y then
        DrawLine(dragLayer, math.min(l, ol), y, math.max(r, oright), y, c)
        if ol - r > near then DrawLabel(dragLayer, (r + ol) / 2, y, ol - r, c, T.bg)
        elseif l - oright > near then DrawLabel(dragLayer, (oright + l) / 2, y, l - oright, c, T.bg) end
    end
end

local function DrawSpacing(item, l, r, t, b, c, near)
    for _, spot in ipairs(EvenSpots(item, l, r, b, t, true)) do
        if math.abs(spot.at - l) <= near then
            for i = EDGE_PAIRS_FIRST, EDGE_PAIRS_LAST, EDGE_PAIRS_STEP do
                local from, to, y = spot[i], spot[i + 1], spot[i + 2]
                DrawLine(dragLayer, from, y, to, y, c)
                DrawLabel(dragLayer, (from + to) / 2, y, to - from, c, T.bg)
            end
            break
        end
    end
    for _, spot in ipairs(EvenSpots(item, b, t, l, r, false)) do
        if math.abs(spot.at - b) <= near then
            for i = EDGE_PAIRS_FIRST, EDGE_PAIRS_LAST, EDGE_PAIRS_STEP do
                local from, to, x = spot[i], spot[i + 1], spot[i + 2]
                DrawLine(dragLayer, x, from, x, to, c)
                DrawLabel(dragLayer, x, (from + to) / 2, to - from, c, T.bg)
            end
            break
        end
    end
end

local function DrawGuides(item)
    local l, r, t, b = Box(item)
    if not l then return end
    local St, px = ns.Shared.Style, Pixel()
    local c, near = St.GUIDE_RGB, px / 2
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local cx, cy = (l + r) / 2, (t + b) / 2
    if math.abs(cx - w / 2) <= near then DrawLine(dragLayer, w / 2, 0, w / 2, h, c) end
    if math.abs(cy - h / 2) <= near then DrawLine(dragLayer, 0, h / 2, w, h / 2, c) end
    for _, other in ipairs(placement.items) do
        if Guiding(item, other) then
            local ol, oright, ot, ob = Box(other)
            if ol then DrawEdgeGuides(l, r, t, b, ol, oright, ot, ob, c, near) end
        end
    end
    DrawSpacing(item, l, r, t, b, c, near)
end

local function DrawBox(layer, l, r, t, b, c, alpha)
    DrawLine(layer, l, t, r, t, c, alpha)
    DrawLine(layer, l, b, r, b, c, alpha)
    DrawLine(layer, l, b, l, t, c, alpha)
    DrawLine(layer, r, b, r, t, c, alpha)
end

local function DrawOutline(item)
    local box = item.startBox
    DrawBox(dragLayer, box.l, box.r, box.t, box.b, T.fg, OUTLINE_ALPHA)
end

local function BuildTabs()
    tabs = {}
    for _, side in ipairs(TAB_SIDES) do
        local tab = CreateFrame("Button", nil, Overlay())
        tab.fill = ns.Solid(tab, "ARTWORK", T.bg, 1)
        tab.fill:SetAllPoints()
        tab.border = ns.Border(tab, T.accentSoft)
        tab:SetScript("OnClick", function() H.SetSide(placement.selected, side) end)
        ns.Tooltip(tab, side:sub(1, 1) .. side:sub(2):lower(), TEXT_TAB_HELP)
        tabs[side] = tab
    end
end

local function PlaceTab(tab, side, used, tl, tr, tt, tb, px)
    local across = side == "TOP" or side == "BOTTOM"
    local hit = -TAB_HIT * px
    tab:SetSize((across and TAB_W or TAB_H) * px, (across and TAB_H or TAB_W) * px)
    tab:SetHitRectInsets(hit, hit, hit, hit)
    tab:ClearAllPoints()
    if side == "TOP" then tab:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (tl + tr) / 2, tt)
    elseif side == "BOTTOM" then tab:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (tl + tr) / 2, tb)
    elseif side == "LEFT" then tab:SetPoint("CENTER", UIParent, "BOTTOMLEFT", tl, (tt + tb) / 2)
    else tab:SetPoint("CENTER", UIParent, "BOTTOMLEFT", tr, (tt + tb) / 2) end
    local fill = side == used and T.accent or T.bg
    local edge = side == used and T.accent or T.accentSoft
    tab.fill:SetColorTexture(fill.r, fill.g, fill.b, 1)
    tab.border:SetColor(edge.r, edge.g, edge.b, 1)
end

local function PlaceSideTabs(used, tl, tr, tt, tb)
    if not tabs then
        if not used then return end
        BuildTabs()
    end
    local px = Pixel()
    for side, tab in pairs(tabs) do
        if used then PlaceTab(tab, side, used, tl, tr, tt, tb, px) end
        tab:SetShown(used ~= nil)
    end
end

local function AnchorLine(side, tl, tr, tt, tb, cl, cr, ct, cb)
    if side == "TOP" or side == "BOTTOM" then
        local x = Middle(tl, tr, cl, cr)
        if side == "TOP" then return x, tt, x, cb end
        return x, tb, x, ct
    end
    local y = Middle(tb, tt, cb, ct)
    if side == "RIGHT" then return tr, y, cl, y end
    return tl, y, cr, y
end

local function DrawAnchor(item)
    Clear(anchorLayer)
    PlaceSideTabs(nil)
    local info = item and not item.ownAnchor and AnchorOf(item.label)
    local target = info and placement.byLabel[info.target]
    if not target then return end
    local tl, tr, tt, tb = Box(target)
    local cl, cr, ct, cb = Box(item)
    if not (tl and cl) then return end
    PlaceSideTabs(info.side, tl, tr, tt, tb)
    local x1, y1, x2, y2 = AnchorLine(info.side, tl, tr, tt, tb, cl, cr, ct, cb)
    DrawLine(anchorLayer, x1, y1, x2, y2, T.accent)
    DrawLabel(anchorLayer, (x1 + x2) / 2, (y1 + y2) / 2, Gap(info), T.accent, T.fg)
end

H.dragLayer, H.anchorLayer, H.groupLayer = dragLayer, anchorLayer, groupLayer
H.Clear, H.DrawLine, H.DrawBox, H.GuidesOn, H.SnapBy = Clear, DrawLine, DrawBox, GuidesOn, SnapBy
H.DrawGuides, H.DrawOutline, H.DrawAnchor = DrawGuides, DrawOutline, DrawAnchor

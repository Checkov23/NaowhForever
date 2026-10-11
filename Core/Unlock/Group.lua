-- Group.lua: several elements selected: their outline, and the bar that aligns, spaces and locks them.
local ns = _G.NaowhForever
local T = ns.THEME
local UI = ns.UI
local H = ns.HudEditor

local placement = H.placement
local Grouped, Pixel, Box, MoveTo, Moved, Marks, IsLocked = H.Grouped, H.Pixel, H.Box, H.MoveTo, H.Moved, H.Marks,
    H.IsLocked
local Clear, DrawBox, Moves, Checkpoint, Refresh, SetBox = H.Clear, H.DrawBox, H.Moves, H.Checkpoint, H.Refresh,
    H.SetBox

local C = H.C
local GROUP_PAD = 6
local GROUP_ALPHA = 0.6
local SEL_H, SEL_PAD, SEL_GAP, SEL_SEP = 30, 8, 4, 10
local SEL_ICON = 18
local SEL_COUNT_W = 78
local SEL_OFFSET = 6
local VERTICAL_FIRST = 4
local EDGES = { "left", "hcenter", "right", "top", "vcenter", "bottom" }
local EDGE_TIPS = { left = ns.L("Line up left edges"), hcenter = ns.L("Line up middles, left to right"),
    right = ns.L("Line up right edges"), top = ns.L("Line up top edges"), vcenter = ns.L("Line up middles, top to bottom"),
    bottom = ns.L("Line up bottom edges") }
local ACROSS, DOWN = "across", "down"
local TEXT_SELECTED = ns.L(" selected")
local TEXT_ACROSS, TEXT_DOWN = ns.L("Space evenly across"), ns.L("Space evenly down")
local TEXT_GAP = ns.L("Gap")
local TEXT_LOCK_ALL, TEXT_UNLOCK_ALL = ns.L("Lock all"), ns.L("Unlock all")

local function GroupBox()
    local l, r, t, b
    for _, item in ipairs(placement.group) do
        local il, ir, it, ib = Box(item)
        if il then
            l, r = l and math.min(l, il) or il, r and math.max(r, ir) or ir
            t, b = t and math.max(t, it) or it, b and math.min(b, ib) or ib
        end
    end
    return l, r, t, b
end

local function Arranged(moved)
    for _, item in ipairs(moved) do Moved(item) end
    for _, item in ipairs(placement.group) do Refresh(item) end
    H.ShowSelection()
end

local function AlignedCenter(edge, l, r, t, b, il, ir, it, ib)
    local w, h = ir - il, it - ib
    local cx, cy = (il + ir) / 2, (it + ib) / 2
    if edge == "left" then cx = l + w / 2
    elseif edge == "hcenter" then cx = (l + r) / 2
    elseif edge == "right" then cx = r - w / 2
    elseif edge == "top" then cy = t - h / 2
    elseif edge == "vcenter" then cy = (t + b) / 2
    else cy = b + h / 2 end
    return cx, cy
end

function UI.AlignSelection(edge)
    if InCombatLockdown() or not Grouped() then return end
    local l, r, t, b = GroupBox()
    if not l then return end
    Checkpoint()
    local moved = {}
    for _, item in ipairs(placement.group) do
        local il, ir, it, ib = Box(item)
        if il and Moves(item) then
            MoveTo(item, AlignedCenter(edge, l, r, t, b, il, ir, it, ib))
            moved[#moved + 1] = item
        end
    end
    Arranged(moved)
end

local spreadAcross

local function InSpreadOrder(a, c)
    local al, ar, at, ab = Box(a)
    local cl, cr, ct, cb = Box(c)
    if spreadAcross then return al + ar < cl + cr end
    return at + ab > ct + cb
end

local function Spreadable()
    local list = {}
    for _, item in ipairs(placement.group) do
        if Moves(item) and Box(item) then list[#list + 1] = item end
    end
    return list
end

local function TotalSize(list, across)
    local total = 0
    for _, item in ipairs(list) do
        local il, ir, it, ib = Box(item)
        total = total + (across and ir - il or it - ib)
    end
    return total
end

local function SpreadGap(list, across, pixels)
    if pixels then return math.floor(pixels + C.ROUND) * Pixel() end
    if #list <= 2 then return nil end
    local fl, _, ft = Box(list[1])
    local _, lr, _, lb = Box(list[#list])
    return ((across and lr - fl or ft - lb) - TotalSize(list, across)) / (#list - 1)
end

local function LayOut(list, across, gap)
    local fl, _, ft = Box(list[1])
    local pos = across and fl or ft
    for _, item in ipairs(list) do
        local il, ir, it, ib = Box(item)
        if across then
            MoveTo(item, pos + (ir - il) / 2, (it + ib) / 2)
            pos = pos + (ir - il) + gap
        else
            MoveTo(item, (il + ir) / 2, pos - (it - ib) / 2)
            pos = pos - (it - ib) - gap
        end
    end
end

function UI.SpreadSelection(axis, pixels)
    if InCombatLockdown() or not Grouped() then return end
    local list = Spreadable()
    if #list < 2 then return end
    local l, r, t, b = GroupBox()
    axis = axis or placement.spreadAxis or ((r - l) >= (t - b) and ACROSS or DOWN)
    placement.spreadAxis = axis
    local across = axis == ACROSS
    spreadAcross = across
    table.sort(list, InSpreadOrder)
    local gap = SpreadGap(list, across, pixels)
    if not gap then return end
    Checkpoint()
    LayOut(list, across, gap)
    placement.spreadGap = gap
    Arranged(list)
end

function UI.LockSelection()
    local marks, all = Marks("locked"), true
    for _, item in ipairs(placement.group) do
        if not marks[item.label] then all = false end
    end
    for _, item in ipairs(placement.group) do
        marks[item.label] = not all or nil
        H.PaintMarks(item)
        Refresh(item)
    end
    H.ShowSelection()
end

local function BarIcon(bar, x, texture, tip, onClick)
    local button = ns.Shared.Parts.IconButton(bar, onClick, texture, nil, tip)
    button:SetSize(SEL_ICON, SEL_ICON)
    button.icon:SetSize(SEL_ICON, SEL_ICON)
    button.icon:SetVertexColor(T.fg.r, T.fg.g, T.fg.b)
    button:SetPoint("LEFT", x, 0)
    return button, x + SEL_ICON + SEL_GAP
end

local function OnGapEntered(box)
    local v = tonumber(box:GetText())
    box:ClearFocus()
    if v then UI.SpreadSelection(nil, v) end
end

local function GapBox(bar, x)
    local gap = ns.NewEditBox(bar)
    gap:SetSize(C.BOX_W, C.BOX_H)
    gap:SetPoint("LEFT", x, 0)
    gap:SetFont(ns.UIFontPath(), C.VALUE_SIZE, "")
    gap:SetJustifyH("CENTER")
    gap:SetMaxLetters(C.GAP_LETTERS)
    gap:SetScript("OnEnterPressed", OnGapEntered)
    gap:SetScript("OnEscapePressed", gap.ClearFocus)
    gap:SetScript("OnEditFocusGained", function() gap.border:SetColor(T.accent.r, T.accent.g, T.accent.b, 1) end)
    gap:SetScript("OnEditFocusLost", function()
        gap.border:SetColor(C.BLACK.r, C.BLACK.g, C.BLACK.b, 1)
        gap.value = nil
        H.ShowSelection()
    end)
    return gap
end

local function AlignIcons(bar, x)
    local St = ns.Shared.Style
    bar.align = {}
    for i, edge in ipairs(EDGES) do
        if i == VERTICAL_FIRST then x = x + SEL_SEP end
        bar.align[edge], x = BarIcon(bar, x, St["ALIGN_" .. edge:upper()], EDGE_TIPS[edge],
            function() UI.AlignSelection(edge) end)
    end
    x = x + SEL_SEP
    bar.across, x = BarIcon(bar, x, St.ALIGN_ACROSS, TEXT_ACROSS, function() UI.SpreadSelection(ACROSS) end)
    bar.down, x = BarIcon(bar, x, St.ALIGN_DOWN, TEXT_DOWN, function() UI.SpreadSelection(DOWN) end)
    return x + SEL_SEP
end

local function BuildSelectionBar()
    local bar = CreateFrame("Frame", nil, UIParent)
    bar:SetHeight(SEL_H)
    bar:SetFrameStrata("FULLSCREEN_DIALOG")
    bar:SetFrameLevel(C.TAG_LEVEL)
    bar:SetClampedToScreen(true)
    bar:EnableMouse(true)
    ns.Solid(bar, "BACKGROUND", T.panel, C.PLATE_ALPHA):SetAllPoints()
    ns.Border(bar, C.BLACK)
    bar.count = ns.Font(bar, C.VALUE_SIZE)
    bar.count:SetPoint("LEFT", SEL_PAD, 0)
    local x = AlignIcons(bar, SEL_PAD + SEL_COUNT_W)
    local gapLabel = ns.Font(bar, C.LABEL_SIZE, nil, T.muted)
    gapLabel:SetText(TEXT_GAP)
    gapLabel:SetPoint("LEFT", x, 0)
    x = x + C.GAP_LABEL_W
    bar.gap = GapBox(bar, x)
    x = x + C.BOX_W + SEL_SEP
    bar.lock, x = BarIcon(bar, x, ns.Shared.Style.LOCK, TEXT_LOCK_ALL, function() UI.LockSelection() end)
    bar:SetWidth(x - SEL_GAP + SEL_PAD)
    bar:Hide()
    return bar
end

local function PlaceBar(bar, l, r, t, b)
    bar:ClearAllPoints()
    if t + SEL_OFFSET + SEL_H <= UIParent:GetHeight() then
        bar:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", (l + r) / 2, t + SEL_OFFSET)
    else
        bar:SetPoint("TOP", UIParent, "BOTTOMLEFT", (l + r) / 2, b - SEL_OFFSET)
    end
end

local function PaintLockAll(bar)
    local all = true
    for _, item in ipairs(placement.group) do
        if not IsLocked(item) then all = false end
    end
    local c = all and T.accent or T.fg
    bar.lock.icon:SetVertexColor(c.r, c.g, c.b)
    bar.lock.tip = all and TEXT_UNLOCK_ALL or TEXT_LOCK_ALL
end

local function ShowSelection()
    Clear(H.groupLayer)
    local bar = placement.bar
    local l, r, t, b
    if Grouped() then l, r, t, b = GroupBox() end
    if not l then
        if bar then bar:Hide() end
        return
    end
    local pad = GROUP_PAD * Pixel()
    l, r, t, b = l - pad, r + pad, t + pad, b - pad
    DrawBox(H.groupLayer, l, r, t, b, T.accent, GROUP_ALPHA)
    if not bar then
        bar = BuildSelectionBar()
        placement.bar = bar
    end
    bar.count:SetText(#placement.group .. TEXT_SELECTED)
    PlaceBar(bar, l, r, t, b)
    if placement.spreadGap then SetBox(bar.gap, math.floor(placement.spreadGap / Pixel() + C.ROUND)) end
    PaintLockAll(bar)
    bar:Show()
end

H.ShowSelection = ShowSelection

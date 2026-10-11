-- Tag.lua: the selected element's tag: its X and Y, Center, Anchor, its side and gap, Settings.
local ns = _G.NaowhForever
local T = ns.THEME
local H = ns.HudEditor

local placement = H.placement
local Grouped, Pixel, Bounds, Position = H.Grouped, H.Pixel, H.Bounds, H.Position
local Anchors, AnchorOf, SideOf, Gap, SetGap = H.Anchors, H.AnchorOf, H.SideOf, H.Gap, H.SetGap
local Capture, Apply, Propagate = H.Capture, H.Apply, H.Propagate
local DrawAnchor, Checkpoint, Change, Nudge, Refresh = H.DrawAnchor, H.Checkpoint, H.Change, H.Nudge, H.Refresh

local C = H.C
local BOX_W, BOX_H, GAP_LABEL_W = C.BOX_W, C.BOX_H, C.GAP_LABEL_W
local TAG_PAD, TAG_GAP = 3, 4
local LETTER_W, AXIS_GAP, PAIR_GAP = 8, 3, 8
local CENTER_W, ANCHOR_W, SETTINGS_W = 52, 66, 74
local SIDE_W, SIDE_LABEL_W = 50, 28
local ROW_GAP = 4
local SIDE_COUNT = 4
local TAG_H = BOX_H + 2 * TAG_PAD
local TAG_H_ANCHORED = 2 * BOX_H + ROW_GAP + 2 * TAG_PAD
local POSITION_LETTERS = 6
local AXES = { "X", "Y" }
local SIDES = { "TOP", "LEFT", "RIGHT", "BOTTOM" }
local SIDE_NAMES = { TOP = "Top", LEFT = "Left", RIGHT = "Right", BOTTOM = "Bottom" }
local ACROSS = { TOP = "y", BOTTOM = "y", LEFT = "x", RIGHT = "x" }
local TEXT_MOVES_WITH = "%s already moves with %s."
local TEXT_ANCHOR, TEXT_UNANCHOR = "Anchor", "Unanchor"
local TEXT_ANCHORED = "Anchored to %s. Lets go of it; it stays where it is."
local TEXT_ANCHOR_HELP = "Click another element to anchor to. It then moves with that element."
local TEXT_CENTER, TEXT_CENTER_HELP = "Center", "Moves it to the middle of the screen, left to right."
local TEXT_SETTINGS, TEXT_SETTINGS_HELP = "Settings", "Opens its settings and leaves the HUD Editor."
local TEXT_SIDE, TEXT_GAP = "Side", "Gap"
local TEXT_SIDE_HELP = "Sits off this side of what it is anchored to, keeping the gap."

local function CenterAcross(item)
    local x = Position(item)
    if x and x ~= 0 and Change(item) then Nudge(item, -x * Pixel(), 0) end
end

local function OpenPage(page, feature)
    ns.HideUnlockMode()
    ns.OpenOptionsWindow(page)
    if feature then ns.UI.GoToSetting(page, nil, feature) end
end

local function OpenSettings(item, owner)
    local choices = item.choices
    if not (choices and #choices > 1) then return OpenPage(item.page, item.feature) end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(TEXT_SETTINGS)
        for _, choice in ipairs(choices) do
            root:CreateButton(ns.L(choice.name), function() OpenPage(choice.page, choice.feature) end)
        end
    end)
end

local function SetBox(box, v)
    if box:HasFocus() or box.value == v then return end
    box.value = v
    box:SetText(tostring(v))
end

local function Typed(box)
    local v = tonumber(box:GetText())
    box:ClearFocus()
    local item = placement.selected
    if not (item and v) then return end
    local x, y = Position(item)
    if not x then return end
    local d = math.floor(v + C.ROUND) - (box.axis == "X" and x or y)
    if d == 0 or not Change(item) then return end
    if box.axis == "X" then Nudge(item, d * Pixel(), 0) else Nudge(item, 0, d * Pixel()) end
end

local function Revert(box)
    box.border:SetColor(C.BLACK.r, C.BLACK.g, C.BLACK.b, 1)
    box.value = nil
    H.ShowTag()
end

local function Reanchor(item)
    Apply(item)
    Propagate(item.label)
    Refresh(item)
end

local function SetSide(item, side)
    local info = item and AnchorOf(item.label)
    if not info or info.side == side or not Change(item) then return end
    local gap = Gap(info)
    if ACROSS[side] ~= ACROSS[info.side] then info.x, info.y = 0, 0 end
    info.side = side
    SetGap(info, gap)
    Reanchor(item)
end

local function TypedGap(box)
    local v = tonumber(box:GetText())
    box:ClearFocus()
    local item = placement.selected
    local info = item and AnchorOf(item.label)
    if not (info and v) or not Change(item) then return end
    SetGap(info, math.floor(v + C.ROUND) * Pixel())
    Reanchor(item)
end

local function AlreadyFollows(target, item)
    local walk, depth = target.label, 0
    while walk and depth < C.MAX_DEPTH do
        if walk == item.label then return true end
        local info = AnchorOf(walk)
        walk, depth = info and info.target, depth + 1
    end
    return false
end

local function PickTarget(target)
    local item = placement.picking
    placement.picking = nil
    if target ~= item then
        if AlreadyFollows(target, item) then
            ns.Print(ns.L(TEXT_MOVES_WITH, ns.L(target.label), ns.L(item.label)))
            H.ShowTag()
            return
        end
        local info = { target = target.label, side = SideOf(item, target) }
        Capture(item, info)
        Checkpoint()
        Anchors()[item.label] = info
    end
    H.ShowTag()
end

local function AnchorClicked(tag)
    local item = tag.item
    if not item then return end
    if AnchorOf(item.label) then
        Checkpoint()
        Anchors()[item.label] = nil
    else
        placement.picking = placement.picking ~= item and item or nil
    end
    H.ShowTag()
end

function ns.UI.PickAnchorFor(handle)
    local item = handle and handle._placement
    if not item or item.ownAnchor then return end
    ns.UI.SelectMover(handle)
    if placement.selected ~= item then return end
    placement.picking = item
    H.ShowTag()
end

function ns.UI.DropAnchor(handle)
    local item = handle and handle._placement
    if not (item and AnchorOf(item.label)) then return end
    Anchors()[item.label] = nil
    if placement.active then H.ShowTag() end
end

local function PaintLit(button, on)
    local edge, text = on and T.accent or C.BLACK, on and T.accent or T.fg
    button._rest = edge
    button._border:SetColor(edge.r, edge.g, edge.b, 1)
    button.label:SetTextColor(text.r, text.g, text.b, 1)
end

local function PaintAnchor(button, item)
    local info = AnchorOf(item.label)
    ns.SetButtonText(button, info and TEXT_UNANCHOR or TEXT_ANCHOR)
    if info then
        ns.Tooltip(button, TEXT_UNANCHOR, TEXT_ANCHORED:format(info.target))
    else
        ns.Tooltip(button, TEXT_ANCHOR, TEXT_ANCHOR_HELP)
    end
    PaintLit(button, placement.picking == item)
end

local function LightBorder(box)
    box.border:SetColor(T.accent.r, T.accent.g, T.accent.b, 1)
end

local function ValueBox(parent, letters, onEnter)
    local box = ns.NewEditBox(parent)
    box:SetSize(BOX_W, BOX_H)
    box:SetFont(ns.UIFontPath(), C.VALUE_SIZE, "")
    box:SetJustifyH("CENTER")
    box:SetMaxLetters(letters)
    box:SetScript("OnEnterPressed", onEnter)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEditFocusGained", LightBorder)
    box:SetScript("OnEditFocusLost", Revert)
    return box
end

local function AxisBoxes(tag)
    local left
    for _, axis in ipairs(AXES) do
        local letter = ns.Font(tag, C.LABEL_SIZE, nil, T.muted)
        letter:SetText(axis)
        letter:SetSize(LETTER_W, BOX_H)
        if left then
            letter:SetPoint("LEFT", left, "RIGHT", PAIR_GAP, 0)
        else
            letter:SetPoint("TOPLEFT", tag, "TOPLEFT", TAG_PAD, -TAG_PAD)
        end
        local box = ValueBox(tag, POSITION_LETTERS, Typed)
        box.axis = axis
        box:SetPoint("LEFT", letter, "RIGHT", AXIS_GAP, 0)
        box:HookScript("OnLeave", function()
            if box:HasFocus() then LightBorder(box) end
        end)
        tag[axis:lower()] = box
        left = box
    end
    tag.x:SetScript("OnTabPressed", function() tag.y:SetFocus() end)
    tag.y:SetScript("OnTabPressed", function() tag.x:SetFocus() end)
    return left
end

local function TagButtons(tag, left)
    tag.center = ns.Button(tag, TEXT_CENTER, CENTER_W, BOX_H, function()
        if tag.item then CenterAcross(tag.item) end
    end)
    tag.center:SetPoint("LEFT", left, "RIGHT", PAIR_GAP, 0)
    ns.Tooltip(tag.center, TEXT_CENTER, TEXT_CENTER_HELP)
    tag.anchor = ns.Button(tag, TEXT_ANCHOR, ANCHOR_W, BOX_H, function() AnchorClicked(tag) end)
    tag.anchor:SetPoint("LEFT", tag.center, "RIGHT", AXIS_GAP, 0)
    tag.settings = ns.Button(tag, TEXT_SETTINGS, SETTINGS_W, BOX_H, function()
        if tag.item then OpenSettings(tag.item, tag.settings) end
    end)
    ns.Tooltip(tag.settings, TEXT_SETTINGS, TEXT_SETTINGS_HELP)
end

local function SideRow(tag)
    local sides = CreateFrame("Frame", nil, tag)
    sides:SetPoint("TOPLEFT", tag, "TOPLEFT", TAG_PAD, -(TAG_PAD + BOX_H + ROW_GAP))
    sides:SetPoint("TOPRIGHT", tag, "TOPRIGHT", -TAG_PAD, -(TAG_PAD + BOX_H + ROW_GAP))
    sides:SetHeight(BOX_H)
    local sideLabel = ns.Font(sides, C.LABEL_SIZE, nil, T.muted)
    sideLabel:SetText(TEXT_SIDE)
    sideLabel:SetSize(SIDE_LABEL_W, BOX_H)
    sideLabel:SetPoint("LEFT")
    local prev = sideLabel
    tag.side = {}
    for _, side in ipairs(SIDES) do
        local button = ns.Button(sides, SIDE_NAMES[side], SIDE_W, BOX_H, function()
            if tag.item then SetSide(tag.item, side) end
        end)
        button:SetPoint("LEFT", prev, "RIGHT", AXIS_GAP, 0)
        ns.Tooltip(button, SIDE_NAMES[side], TEXT_SIDE_HELP)
        tag.side[side] = button
        prev = button
    end
    local gapLabel = ns.Font(sides, C.LABEL_SIZE, nil, T.muted)
    gapLabel:SetText(TEXT_GAP)
    gapLabel:SetSize(GAP_LABEL_W, BOX_H)
    gapLabel:SetPoint("LEFT", prev, "RIGHT", PAIR_GAP, 0)
    local gap = ValueBox(sides, C.GAP_LETTERS, TypedGap)
    gap:SetPoint("LEFT", gapLabel, "RIGHT", AXIS_GAP, 0)
    tag.gap = gap
    tag.sides = sides
end

local function BuildTag()
    local tag = CreateFrame("Frame", nil, UIParent)
    tag:SetHeight(TAG_H)
    tag:SetFrameStrata("FULLSCREEN_DIALOG")
    tag:SetFrameLevel(C.TAG_LEVEL)
    tag:SetClampedToScreen(true)
    tag:EnableMouse(true)
    ns.Solid(tag, "BACKGROUND", T.panel, C.PLATE_ALPHA):SetAllPoints()
    ns.Border(tag, C.BLACK)
    TagButtons(tag, AxisBoxes(tag))
    SideRow(tag)
    return tag
end

local function PaintSides(tag, info)
    for side, button in pairs(tag.side) do PaintLit(button, info.side == side) end
end

local function TagWidth(item, anchored)
    local w = 2 * (LETTER_W + AXIS_GAP + BOX_W) + 2 * PAIR_GAP + CENTER_W + 2 * TAG_PAD
    if not item.ownAnchor then w = w + AXIS_GAP + ANCHOR_W end
    if item.page then w = w + AXIS_GAP + SETTINGS_W end
    if anchored then
        local sidesW = SIDE_LABEL_W + SIDE_COUNT * (AXIS_GAP + SIDE_W) + PAIR_GAP + GAP_LABEL_W + AXIS_GAP + BOX_W
        w = math.max(w, sidesW + 2 * TAG_PAD)
    end
    return w
end

local function LayoutTag(tag, item, above, anchored, height)
    tag.item, tag.above, tag.anchored = item, above, anchored
    tag.x.value, tag.y.value, tag.gap.value = nil, nil, nil
    tag:SetHeight(height)
    tag.sides:SetShown(anchored)
    tag.anchor:SetShown(not item.ownAnchor)
    tag.settings:SetShown(item.page ~= nil)
    tag.settings:ClearAllPoints()
    tag.settings:SetPoint("LEFT", item.ownAnchor and tag.center or tag.anchor, "RIGHT", AXIS_GAP, 0)
    tag:SetWidth(TagWidth(item, anchored))
    tag:ClearAllPoints()
    if above then
        tag:SetPoint("BOTTOM", item.handle, "TOP", 0, TAG_GAP)
    else
        tag:SetPoint("TOP", item.handle, "BOTTOM", 0, -TAG_GAP)
    end
end

local function HideTag(tag)
    if tag then
        tag:Hide()
        tag.item = nil
    end
    DrawAnchor(nil)
end

local function ShowTag()
    local item = not Grouped() and placement.selected or nil
    local x, y
    if item then x, y = Position(item) end
    local tag = placement.tag
    if not x then return HideTag(tag) end
    if not tag then
        tag = BuildTag()
        placement.tag = tag
    end
    local info = not item.ownAnchor and AnchorOf(item.label)
    local anchored = info and true or false
    local height = anchored and TAG_H_ANCHORED or TAG_H
    local _, _, _, bottom = Bounds(item.handle)
    local above = bottom ~= nil and bottom - TAG_GAP - height < 0
    if tag.item ~= item or tag.above ~= above or tag.anchored ~= anchored then
        LayoutTag(tag, item, above, anchored, height)
    end
    tag:Show()
    SetBox(tag.x, x)
    SetBox(tag.y, y)
    if not item.ownAnchor then PaintAnchor(tag.anchor, item) end
    if info then
        SetBox(tag.gap, math.floor(Gap(info) / Pixel() + C.ROUND))
        PaintSides(tag, info)
    end
    DrawAnchor(item)
end

H.SetBox, H.SetSide, H.PickTarget, H.ShowTag = SetBox, SetSide, PickTarget, ShowTag

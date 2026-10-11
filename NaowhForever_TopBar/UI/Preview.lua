-- Preview.lua: the Top Bar's live preview on its settings card, which edits its layout: drag a button to move it, its x removes it, a side's + adds one (ns.TopBar.Preview).
local ns = _G.NaowhForever
local T = ns.THEME

local TB = ns.TopBar
local S = TB.Settings
local C = TB.C
local St = TB.Style
local Layout = TB.Layout
local Look = TB.Look
local Tooltips = TB.Tooltips
local Buttons = TB.Buttons

local Tone, Accent, IconColor = Look.Tone, Look.Accent, Look.IconColor
local GAP, SEG_PAD, PERCENT, LDB_PREFIX, SIDES = C.GAP, C.SEG_PAD, C.PERCENT, C.LDB_PREFIX, C.SIDES
local BUILTIN, BUILTIN_ORDER = Layout.BUILTIN, Layout.BUILTIN_ORDER
local WHITE, LABEL_GREY, BLACK = St.WHITE, St.LABEL_GREY, St.BORDER_RGB
local SAMPLE_FRIENDS, SAMPLE_GUILD, SAMPLE_FPS, SAMPLE_MS = 12, 31, 144, 38
local PREVIEW_TOP = 26
local NOTE_BOTTOM, NOTE_SIZE = St.STAGE_NOTE_Y, St.STAGE_NOTE_SIZE
local HOVER_ALPHA = 0.18
local DRAGGED_ALPHA = 0.3
local GHOST_ALPHA = 0.85
local MARKER_W = 2
local REMOVE_SIZE, REMOVE_ICON = 12, 8
local REMOVE_INSET = 3
local PLUS_GAP = 6
local PLUS_ICON = 12
local PLUS_BG_ALPHA = 0.6
local DROP_SLOP = 12
local EDIT_LEVEL = 10
local SYS_DROP = C.SYS_DROP

local HINT = ns.L("Drag to move, x to remove, + to add.")
local TIP_HINT = ns.L("Drag to move. Click x to remove.")
local TEXT_ADD_LEFT, TEXT_ADD_RIGHT = ns.L("Add to the Left Side"), ns.L("Add to the Right Side")
local TEXT_ALL_ON = ns.L("Everything is on the bar already.")
local TEXT_ON_BAR = ns.L("Already on the bar")
local TEXT_ADD = ns.L("Add a Button")
local TEXT_LEFT_SIDE, TEXT_RIGHT_SIDE = ns.L("On the left side."), ns.L("On the right side.")

local addKeys, addBrokers, addLabels, onBar = {}, {}, {}, {}
local used

local function Unhover(preview)
    local b = preview.hover
    if not b then return end
    preview.hover = nil
    b.icon:SetVertexColor(IconColor())
    b.wash:Hide()
    preview.remove:Hide()
    GameTooltip:Hide()
end

local function Hover(preview, b)
    if preview.hover ~= b then Unhover(preview) end
    preview.hover = b
    b.icon:SetVertexColor(Accent())
    b.wash:Show()
    local x = preview.remove
    x.owner = b
    x:ClearAllPoints()
    x:SetPoint("CENTER", b, "TOPRIGHT", -REMOVE_INSET, -REMOVE_INSET)
    x:Show()
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    GameTooltip:AddLine(Layout.Name(b.key), Tone("fg", WHITE))
    GameTooltip:AddLine(TIP_HINT, Tone("muted", LABEL_GREY))
    GameTooltip:Show()
end

local function PreviewEnter(b)
    if not b.preview.drag then Hover(b.preview, b) end
end

local function PreviewLeave(b)
    local preview = b.preview
    if preview.hover == b and not preview.remove:IsMouseOver() then Unhover(preview) end
end

local function RemoveEnter(x)
    x.icon:SetVertexColor(Accent())
end

local function RemoveLeave(x)
    x.icon:SetVertexColor(Tone("fg", WHITE))
    if not (x.owner and x.owner:IsMouseOver()) then Unhover(x.preview) end
end

local function RemoveClick(x)
    local key = x.owner and x.owner.key
    Unhover(x.preview)
    if key then Layout.Remove(key) end
end

local function DropTarget(preview, x)
    local side = x < preview.clock:GetCenter() and "left" or "right"
    local list = preview.lists[side]
    for i = 1, #list do
        local b = list[i]
        if b ~= preview.drag and x < b:GetCenter() then return side, b end
    end
    return side, nil
end

local function LastKept(preview, side)
    local list = preview.lists[side]
    for i = #list, 1, -1 do
        if list[i] ~= preview.drag then return list[i] end
    end
end

local function PlaceMarker(preview, side, before)
    local marker = preview.marker
    marker:ClearAllPoints()
    local last = not before and LastKept(preview, side)
    if before then
        marker:SetPoint("CENTER", before, "LEFT", -GAP / 2, 0)
    elseif last then
        marker:SetPoint("CENTER", last, "RIGHT", GAP / 2, 0)
    else
        marker:SetPoint("CENTER", side == "left" and preview.left or preview.right, "CENTER")
    end
    marker:Show()
end

local function DragUpdate(edit)
    local preview = edit.preview
    local scale = preview:GetEffectiveScale()
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    local ghost = preview.ghost
    ghost:ClearAllPoints()
    ghost:SetPoint("CENTER", preview, "BOTTOMLEFT", x - preview:GetLeft(), y - preview:GetBottom())
    if preview:IsMouseOver(DROP_SLOP, -DROP_SLOP, -DROP_SLOP, DROP_SLOP) then
        local side, before = DropTarget(preview, x)
        if side ~= preview.dropSide or before ~= preview.dropBefore then
            preview.dropSide, preview.dropBefore = side, before
            PlaceMarker(preview, side, before)
        end
    elseif preview.dropSide then
        preview.dropSide, preview.dropBefore = nil, nil
        preview.marker:Hide()
    end
end

local function DragStart(b)
    local preview = b.preview
    if preview.drag then return end
    Unhover(preview)
    preview.drag, preview.dropSide, preview.dropBefore = b, nil, nil
    b:SetAlpha(DRAGGED_ALPHA)
    local size, icon = Look.BtnSize(), S.Get("iconSize")
    local ghost = preview.ghost
    local c = b.coords
    ghost:SetSize(size, size)
    ghost.icon:SetSize(icon, icon)
    ghost.icon:SetTexture(b.texture)
    ghost.icon:SetDesaturated(not b.glyph)
    ghost.icon:SetTexCoord(c[1], c[2], c[3], c[4])
    ghost.icon:SetVertexColor(Accent())
    ghost:Show()
    preview.marker:SetHeight(size)
    local edit = preview.edit
    if not InCombatLockdown() then
        edit:EnableKeyboard(true)
        edit:SetPropagateKeyboardInput(true)
    end
    edit:SetScript("OnUpdate", DragUpdate)
    DragUpdate(edit)
end

local function EndDrag(preview, commit)
    local b = preview.drag
    if not b then return end
    local edit = preview.edit
    edit:SetScript("OnUpdate", nil)
    C_Timer.After(0, edit.release)
    preview.drag = nil
    b:SetAlpha(1)
    preview.ghost:Hide()
    preview.marker:Hide()
    local side, before = preview.dropSide, preview.dropBefore
    preview.dropSide, preview.dropBefore = nil, nil
    if commit and side then Layout.Move(b.key, side, before and before.key) end
end

local function DragStop(b)
    EndDrag(b.preview, true)
end

local function DragKey(edit, key)
    if InCombatLockdown() then return end
    if key == "ESCAPE" and edit.preview.drag then
        edit:SetPropagateKeyboardInput(false)
        EndDrag(edit.preview, false)
    else
        edit:SetPropagateKeyboardInput(true)
    end
end

local function PreviewHidden(preview)
    EndDrag(preview, false)
    Unhover(preview)
end

local function ByAddLabel(a, b)
    return addLabels[a]:lower() < addLabels[b]:lower()
end

local function CollectAddable(layout, ldb)
    wipe(addKeys)
    wipe(addBrokers)
    wipe(addLabels)
    for _, key in ipairs(BUILTIN_ORDER) do
        if not Layout.InLayoutOf(layout, key) then addKeys[#addKeys + 1] = key end
    end
    local fixed = #addKeys
    if ldb then
        for name, obj in ldb:DataObjectIterator() do
            local key = LDB_PREFIX .. name
            if obj.icon and not Layout.InLayoutOf(layout, key) then
                addBrokers[#addBrokers + 1] = key
                addLabels[key] = obj.label or name
            end
        end
    end
    table.sort(addBrokers, ByAddLabel)
    for i = 1, #addBrokers do addKeys[fixed + i] = addBrokers[i] end
    return fixed
end

local function CollectOnBar(layout, ldb)
    wipe(onBar)
    for _, list in ipairs({ layout.left, layout.right }) do
        for _, key in ipairs(list) do
            local obj = not BUILTIN[key] and ldb and ldb:GetDataObjectByName(Layout.BrokerName(key))
            local label = BUILTIN[key] or (obj and (obj.label or Layout.BrokerName(key)))
            if label then onBar[#onBar + 1] = label end
        end
    end
    table.sort(onBar)
end

local function AddMenu(plus)
    local side, layout, ldb = plus.side, Layout.Saved(), TB.LDB()
    local fixed = CollectAddable(layout, ldb)
    CollectOnBar(layout, ldb)
    GameTooltip:Hide()
    MenuUtil.CreateContextMenu(plus, function(_, root)
        root:CreateTitle(side == "left" and TEXT_ADD_LEFT or TEXT_ADD_RIGHT)
        if #addKeys == 0 then root:CreateTitle(TEXT_ALL_ON) end
        for i = 1, #addKeys do
            local key = addKeys[i]
            if i == fixed + 1 and fixed > 0 then root:CreateDivider() end
            root:CreateButton(BUILTIN[key] or addLabels[key], function() Layout.Add(side, key) end)
        end
        if #onBar == 0 then return end
        root:CreateDivider()
        root:CreateTitle(TEXT_ON_BAR)
        for i = 1, #onBar do root:CreateButton(onBar[i]):SetEnabled(false) end
    end)
end

local function PlusEnter(plus)
    plus.icon:SetVertexColor(Accent())
    GameTooltip:SetOwner(plus, "ANCHOR_TOP")
    GameTooltip:AddLine(TEXT_ADD, Tone("fg", WHITE))
    GameTooltip:AddLine(plus.side == "left" and TEXT_LEFT_SIDE or TEXT_RIGHT_SIDE, Tone("muted", LABEL_GREY))
    GameTooltip:Show()
end

local function PlusLeave(plus)
    plus.icon:SetVertexColor(Tone("muted", LABEL_GREY))
    GameTooltip:Hide()
end

local function HideTooltip() GameTooltip:Hide() end

local function SystemEnter(hit)
    if S.Get("systemTooltip") then Tooltips.System(hit) end
end

local function NewPreviewButton(preview)
    local b = CreateFrame("Frame", nil, preview)
    b.preview = preview
    b.wash = ns.Solid(b, "BACKGROUND", T.accent, HOVER_ALPHA)
    b.wash:SetAllPoints()
    b.wash:Hide()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("CENTER")
    b:EnableMouse(true)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnEnter", PreviewEnter)
    b:SetScript("OnLeave", PreviewLeave)
    b:SetScript("OnDragStart", DragStart)
    b:SetScript("OnDragStop", DragStop)
    preview.pool[#preview.pool + 1] = b
    return b
end

local function NewPlus(preview, side)
    local plus = CreateFrame("Button", nil, preview)
    plus.preview, plus.side = preview, side
    ns.Solid(plus, "BACKGROUND", T.bg, PLUS_BG_ALPHA):SetAllPoints()
    ns.Border(plus, BLACK)
    plus.icon = plus:CreateTexture(nil, "ARTWORK")
    plus.icon:SetTexture(St.PLUS)
    plus.icon:SetSize(PLUS_ICON, PLUS_ICON)
    plus.icon:SetPoint("CENTER")
    plus.icon:SetVertexColor(Tone("muted", LABEL_GREY))
    plus:SetScript("OnEnter", PlusEnter)
    plus:SetScript("OnLeave", PlusLeave)
    plus:SetScript("OnClick", AddMenu)
    local group = side == "left" and preview.left or preview.right
    if side == "left" then
        plus:SetPoint("RIGHT", group, "LEFT", -(SEG_PAD + PLUS_GAP), 0)
    else
        plus:SetPoint("LEFT", group, "RIGHT", SEG_PAD + PLUS_GAP, 0)
    end
    return plus
end

local function NewRemove(preview, edit)
    local x = CreateFrame("Button", nil, edit)
    x.preview = preview
    x:SetSize(REMOVE_SIZE, REMOVE_SIZE)
    ns.Solid(x, "BACKGROUND", T.bg, 1):SetAllPoints()
    ns.Border(x, BLACK)
    x.icon = x:CreateTexture(nil, "ARTWORK")
    x.icon:SetTexture(St.CROSS)
    x.icon:SetSize(REMOVE_ICON, REMOVE_ICON)
    x.icon:SetPoint("CENTER")
    x.icon:SetVertexColor(Tone("fg", WHITE))
    x:SetScript("OnEnter", RemoveEnter)
    x:SetScript("OnLeave", RemoveLeave)
    x:SetScript("OnClick", RemoveClick)
    x:Hide()
    return x
end

local function NewEditLayer(preview)
    local edit = CreateFrame("Frame", nil, preview)
    edit.preview = preview
    edit:SetAllPoints()
    edit:SetFrameLevel(preview:GetFrameLevel() + EDIT_LEVEL)
    edit:SetScript("OnKeyDown", DragKey)
    edit:EnableKeyboard(false)
    edit.release = function()
        if not preview.drag and not InCombatLockdown() then edit:EnableKeyboard(false) end
    end
    preview.edit = edit

    preview.marker = ns.Solid(edit, "OVERLAY", T.accent, 1)
    preview.marker:SetWidth(MARKER_W)
    preview.marker:Hide()

    local ghost = CreateFrame("Frame", nil, edit)
    ghost:SetAlpha(GHOST_ALPHA)
    ns.Solid(ghost, "BACKGROUND", T.accent, HOVER_ALPHA):SetAllPoints()
    ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
    ghost.icon:SetPoint("CENTER")
    ghost:Hide()
    preview.ghost = ghost

    preview.remove = NewRemove(preview, edit)
end

local function HitFrame(preview, over, onEnter)
    local hit = CreateFrame("Frame", nil, preview)
    hit:SetAllPoints(over)
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", onEnter)
    hit:SetScript("OnLeave", HideTooltip)
    return hit
end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetPoint("TOP", 0, -PREVIEW_TOP)
    preview.segs = Look.NewPills(preview)
    preview.clock = preview:CreateFontString(nil, "OVERLAY")
    preview.clock:SetPoint("CENTER")
    preview.left = CreateFrame("Frame", nil, preview)
    preview.right = CreateFrame("Frame", nil, preview)
    preview.pool, preview.lists = {}, { left = {}, right = {} }
    preview.sys = preview:CreateFontString(nil, "OVERLAY")
    preview.clockHit = HitFrame(preview, preview.clock, Tooltips.Clock)
    preview.sysHit = HitFrame(preview, preview.sys, SystemEnter)
    preview.plusLeft = NewPlus(preview, "left")
    preview.plusRight = NewPlus(preview, "right")
    NewEditLayer(preview)
    preview:SetScript("OnHide", PreviewHidden)
    preview.note = preview:CreateFontString(nil, "OVERLAY")
    preview.note:SetPoint("BOTTOM", stage, "BOTTOM", 0, NOTE_BOTTOM)
    preview.note:SetFont(ns.UIFontPath(), NOTE_SIZE, "")
    preview.note:SetTextColor(T.muted.r, T.muted.g, T.muted.b, 1)
    return preview
end

local function PaintBadge(b, key)
    if not b.badge then Buttons.Badge(b, St.FRIENDS_RGB) end
    local count = key == "friends" and SAMPLE_FRIENDS or key == "guild" and SAMPLE_GUILD
    b.badge:SetText(count or "")
    local c = key == "guild" and St.GUILD_RGB or St.FRIENDS_RGB
    b.badge:SetTextColor(c.r, c.g, c.b)
end

local function PlaceSample(preview, side, key, texture, glyph, coords)
    used = used + 1
    local b = preview.pool[used] or NewPreviewButton(preview)
    b.key = key
    b.texture, b.glyph, b.coords = texture, glyph, coords or Look.GLYPH_COORDS
    b:SetParent(side == "left" and preview.left or preview.right)
    b:SetAlpha(1)
    b.icon:SetTexture(texture)
    b.icon:SetDesaturated(not glyph)
    b.icon:SetTexCoord(b.coords[1], b.coords[2], b.coords[3], b.coords[4])
    PaintBadge(b, key)
    local list = preview.lists[side]
    list[#list + 1] = b
end

local function PaintBar(preview)
    local lists = preview.lists
    preview:SetHeight(Look.BarHeight())
    Look.ClockFont(preview.clock)
    preview.clock:SetText(Look.ClockText())
    preview.clock:SetShown(S.Get("showClock"))
    Look.Row(preview.left, lists.left, #lists.left)
    Look.Row(preview.right, lists.right, #lists.right)
    Look.Fit(preview, preview.left, preview.right, preview.clock, #lists.left, #lists.right)
    Look.PaintPills(preview, preview.segs, preview.left, preview.right, preview.clock, #lists.left, #lists.right)
end

local function PaintSystem(preview)
    local sys = preview.sys
    Look.SystemFont(sys)
    Look.SystemText(sys, SAMPLE_FPS, SAMPLE_MS)
    sys:ClearAllPoints()
    sys:SetPoint("TOP", preview, "BOTTOM", 0, -SYS_DROP)
    sys:SetShown(S.Get("showSystem"))
    preview.sysHit:SetShown(S.Get("showSystem"))
end

local function StateAlpha(preview, state)
    if state == "faded" and S.Get("mouseover") then return S.Get("mouseoverAlpha") / PERCENT end
    if state == "combat" and S.Get("hideInCombat") then
        preview.sys:ClearAllPoints()
        preview.sys:SetPoint("CENTER", preview, "CENTER")
        return 0
    end
    return 1
end

local function PaintEditable(preview, editable)
    for i = 1, #preview.pool do preview.pool[i]:EnableMouse(editable) end
    preview.clockHit:EnableMouse(editable and S.Get("showClock"))
    local size = Look.BtnSize()
    preview.plusLeft:SetSize(size, size)
    preview.plusRight:SetSize(size, size)
    preview.plusLeft:SetShown(editable)
    preview.plusRight:SetShown(editable)
end

local function HoverUnderMouse(preview)
    for s = 1, #SIDES do
        local list = preview.lists[SIDES[s]]
        for i = 1, #list do
            if list[i]:IsMouseOver() then Hover(preview, list[i]) return end
        end
    end
end

local function PaintPreview(preview, state)
    EndDrag(preview, false)
    Unhover(preview)
    wipe(preview.lists.left)
    wipe(preview.lists.right)
    used = 0
    Look.Buttons(function(side, key, texture, glyph, coords)
        PlaceSample(preview, side, key, texture, glyph, coords)
    end)
    for i = used + 1, #preview.pool do preview.pool[i]:Hide() end
    PaintBar(preview)
    PaintSystem(preview)
    local alpha = StateAlpha(preview, state)
    local editable = alpha > 0
    preview:SetAlpha(alpha)
    PaintEditable(preview, editable)
    preview.sys:SetAlpha(state == "faded" and alpha or 1)
    preview.note:SetText(HINT)
    if editable then HoverUnderMouse(preview) end
end

TB.Preview = { New = NewPreview, Paint = PaintPreview }

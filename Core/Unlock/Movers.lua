-- Movers.lua: the HUD Editor's movers: a plate over each element, bound to it, and its marks.
local ns = _G.NaowhForever
local T = ns.THEME
local UI = ns.UI
local H = ns.HudEditor

local placement = H.placement
local Grouped, Bounds, IsHidden, IsLocked = H.Grouped, H.Bounds, H.IsHidden, H.IsLocked
local Queue, Moved, ReapplyAll = H.Queue, H.Moved, H.ReapplyAll
local StopDrag, Refresh, PickTarget = H.StopDrag, H.Refresh, H.PickTarget

local C = H.C
local LOCK_BADGE, LOCK_INSET = 12, 4
local MOVER_RAISE = 20
local MOVER_TEXT_SIZE = 12

local function PaintMarks(item)
    local hidden, h = IsHidden(item), item.handle
    h:SetAlpha(hidden and 0 or 1)
    h:EnableMouse(not hidden)
    if h._lock then
        if not h._lockSet then
            h._lock:SetTexture(ns.Shared.Style.LOCK, nil, nil, "TRILINEAR")
            h._lock:SetVertexColor(T.fg.r, T.fg.g, T.fg.b, 1)
            h._lockSet = true
        end
        h._lock:SetShown(IsLocked(item))
    end
    if hidden and placement.selected == item then UI.ClearMoverSelection() end
end

local function Register(item)
    local old = placement.byLabel[item.label]
    if old then
        for i, other in ipairs(placement.items) do
            if other == old then table.remove(placement.items, i); break end
        end
    end
    placement.items[#placement.items + 1] = item
    placement.byLabel[item.label] = item
end

local function WatchFrame(item, frame, handle, label)
    frame:HookScript("OnSizeChanged", function() Queue(label, "size") end)
    handle:HookScript("OnSizeChanged", function() Queue(label, "size") end)
    hooksecurefunc(frame, "SetPoint", function()
        if not item.dragging then Queue(label) end
    end)
    hooksecurefunc(frame, "StartSizing", function() item.sizing = true end)
    hooksecurefunc(frame, "StopMovingOrSizing", function()
        item.sizing = nil
        C_Timer.After(0, function() Moved(item) end)
    end)
end

local function Clicked(item, handle, button)
    if not placement.active or InCombatLockdown() or item.dragging or item.dragged then return end
    if button ~= "LeftButton" then return end
    if placement.picking then
        PickTarget(item)
    elseif IsShiftKeyDown() then
        UI.SelectMover(handle, true)
    elseif placement.selected == item and not Grouped() then
        UI.ClearMoverSelection()
    else
        UI.SelectMover(handle)
    end
end

local function HandleScripts(item, handle)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnEnter", function()
        if not placement.active then return end
        item.hovered = true
        Refresh(item)
    end)
    handle:SetScript("OnLeave", function()
        item.hovered = false
        Refresh(item)
    end)
    handle:SetScript("OnMouseDown", function() item.dragged = nil end)
    handle:SetScript("OnMouseUp", function(_, button) Clicked(item, handle, button) end)
    handle:SetScript("OnDragStart", function() UI.StartMoverDrag(handle) end)
    handle:SetScript("OnDragStop", function() UI.StopMoverDrag(handle) end)
    handle:HookScript("OnHide", function()
        StopDrag(item)
        item.hovered = false
        if placement.selected == item then UI.ClearMoverSelection() end
        H.RefreshPanel()
    end)
    handle:HookScript("OnShow", function() H.RefreshPanel() end)
end

function UI.BindMover(handle, frame, label, onMoved, page, feature, ownAnchor)
    local item = { handle = handle, frame = frame, label = label, save = onMoved, page = page, feature = feature,
        ownAnchor = ownAnchor }
    item.baseLevel = handle:GetFrameLevel()
    handle._placement = item
    Register(item)
    WatchFrame(item, frame, handle, label)
    Queue(label, "size")
    HandleScripts(item, handle)
    Refresh(item)
end

function UI.AttachMover(frame, label, onMoved, page, feature, ownAnchor)
    local mover = CreateFrame("Frame", nil, frame)
    mover:SetAllPoints()
    mover:SetFrameLevel(frame:GetFrameLevel() + MOVER_RAISE)
    mover._fill = ns.Solid(mover, "BACKGROUND", T.bg, C.MOVER_FILL)
    mover._fill:SetAllPoints()
    local strip = ns.Solid(mover, "ARTWORK", T.accent, 1)
    strip:SetPoint("TOPLEFT")
    strip:SetPoint("TOPRIGHT")
    strip:SetHeight(C.MOVER_STRIP)
    mover._border = ns.Border(mover, C.BLACK)
    local text = ns.Shared.Parts.HudText(ns.Font(mover, MOVER_TEXT_SIZE))
    text:SetPoint("CENTER", mover, "CENTER")
    text:SetText(ns.L(label))
    mover.text = text
    mover._lock = mover:CreateTexture(nil, "OVERLAY")
    mover._lock:SetSize(LOCK_BADGE, LOCK_BADGE)
    mover._lock:SetPoint("TOPRIGHT", -LOCK_INSET, -LOCK_INSET)
    mover._lock:Hide()
    UI.BindMover(mover, frame, label, onMoved, page, feature, ownAnchor)
    mover:Hide()
    return mover
end

function UI.SetMoverChoices(mover, choices)
    mover._placement.choices = choices
end

function UI.CenterPosition(frame)
    local l, r, t, b, ratio = Bounds(frame)
    if not l then return end
    local x = ((l + r) / 2 - UIParent:GetWidth() / 2) / ratio
    local y = ((t + b) / 2 - UIParent:GetHeight() / 2) / ratio
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
    return { point = "CENTER", relPoint = "CENTER", x = x, y = y }
end

local function OnApplied()
    local db = ns.UnlockModeSettings.DB()
    db.anchors, db.snap = nil, nil
    C_Timer.After(0, ReapplyAll)
end

local function OnWatchEvent(_, event)
    if event == "PLAYER_LOGIN" then
        hooksecurefunc(ns, "Apply", OnApplied)
    elseif event == "PLAYER_ENTERING_WORLD" or placement.parked then
        placement.parked = nil
        C_Timer.After(0, ReapplyAll)
    end
end

H.PaintMarks = PaintMarks

local watch = CreateFrame("Frame")
watch:RegisterEvent("PLAYER_LOGIN")
watch:RegisterEvent("PLAYER_ENTERING_WORLD")
watch:RegisterEvent("PLAYER_REGEN_ENABLED")
watch:SetScript("OnEvent", OnWatchEvent)

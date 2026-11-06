-- Mode.lua: the HUD Editor's shared state, its geometry and its anchors (ns.HudEditor).
local ns = _G.NaowhForever

local MAX_DEPTH = 20
local ROUND = 0.5
local HELD_EDGE = { RIGHT = { -1, 0 }, LEFT = { 1, 0 }, UP = { 0, -1 }, DOWN = { 0, 1 } }
local NO_EDGE = { 0, 0 }

local H = {}
ns.HudEditor = H

H.C = {
    BLACK = { r = 0, g = 0, b = 0 },
    MOVER_FILL = 0.55,
    MOVER_FILL_LIT = 0.75,
    MOVER_STRIP = 2,
    MAX_DEPTH = MAX_DEPTH,
    ROUND = ROUND,
    PLATE_ALPHA = 0.98,
    TAG_LEVEL = 230,
    BOX_W = 46,
    BOX_H = 18,
    GAP_LABEL_W = 26,
    LABEL_SIZE = 11,
    VALUE_SIZE = 12,
    GAP_LETTERS = 5,
}

local placement = { active = false, items = {}, byLabel = {}, unsaved = {}, group = {}, groupKey = {} }
local queued, batchQueued = {}, false

local function Grouped() return #placement.group > 1 end

local function Pixel() return PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale() end

local function Bounds(frame)
    local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not (l and r and t and b) then return end
    local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return l * ratio, r * ratio, t * ratio, b * ratio, ratio
end

local function Box(item)
    local fl, fr, ft, fb, ratio = Bounds(item.frame)
    if not fl then return end
    local hl, hr, ht, hb = Bounds(item.handle)
    if hl then return hl, hr, ht, hb, ratio end
    return fl, fr, ft, fb, ratio
end

local function Place(item, x, y)
    local es = item.frame:GetEffectiveScale()
    x, y = PixelUtil.GetNearestPixelSize(x, es), PixelUtil.GetNearestPixelSize(y, es)
    item.frame:ClearAllPoints()
    item.frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
    return x, y
end

local function AtCenter(frame, x, y)
    local point, rel, relPoint, px, py = frame:GetPoint(1)
    return point == "CENTER" and rel == UIParent and relPoint == "CENTER" and px == x and py == y
end

local function MoveTo(item, cx, cy)
    local bl, br, bt, bb = Box(item)
    local fl, fr, ft, fb, ratio = Bounds(item.frame)
    if not (bl and fl) then return end
    local es = item.frame:GetEffectiveScale()
    local x = PixelUtil.GetNearestPixelSize((cx - ((bl + br) - (fl + fr)) / 2 - UIParent:GetWidth() / 2) / ratio, es)
    local y = PixelUtil.GetNearestPixelSize((cy - ((bt + bb) - (ft + fb)) / 2 - UIParent:GetHeight() / 2) / ratio, es)
    if AtCenter(item.frame, x, y) then return end
    Place(item, x, y)
    if placement.dragging then
        placement.unsaved[item] = true
    else
        item.save({ point = "CENTER", relPoint = "CENTER", x = x, y = y })
    end
end

local function Position(item)
    local l, r, t, b = Bounds(item.frame)
    if not l then return end
    local px = Pixel()
    return math.floor((l + r - UIParent:GetWidth()) / 2 / px + ROUND),
        math.floor((t + b - UIParent:GetHeight()) / 2 / px + ROUND)
end

local function CopyAnchor(info)
    return { target = info.target, side = info.side, x = info.x, y = info.y }
end

local function Anchors()
    local db = ns.UnlockModeSettings.DB()
    if type(db.anchoredTo) ~= "table" then
        db.anchoredTo = {}
        for label, info in pairs(ns.UnlockModeSettings.Default("anchoredTo")) do
            db.anchoredTo[label] = CopyAnchor(info)
        end
    end
    if not db.lootFeedOffAlerts then
        db.lootFeedOffAlerts = true
        local sets = { db.anchoredTo }
        if type(db.layouts) == "table" then
            for _, saved in pairs(db.layouts) do
                if type(saved) == "table" and type(saved.anchors) == "table" then sets[#sets + 1] = saved.anchors end
            end
        end
        for _, set in ipairs(sets) do
            local info = set["Loot Feed"]
            if type(info) == "table" and info.target == "Alerts" then set["Loot Feed"] = nil end
        end
    end
    return db.anchoredTo
end

local function AnchorOf(label)
    local info = Anchors()[label]
    if type(info) == "table" and type(info.target) == "string" then return info end
end

local function Marks(key)
    local db = ns.UnlockModeSettings.DB()
    if type(db[key]) ~= "table" then db[key] = {} end
    return db[key]
end

local function IsHidden(item) return Marks("hidden")[item.label] == true end
local function IsLocked(item) return Marks("locked")[item.label] == true end

local function SideOf(item, target)
    local cl, cr, ct, cb = Box(item)
    local tl, tr, tt, tb = Box(target)
    if not (cl and tl) then return "BOTTOM" end
    local dx = (cl + cr - tl - tr) / math.max(1, cr - cl + tr - tl)
    local dy = (ct + cb - tt - tb) / math.max(1, ct - cb + tt - tb)
    if math.abs(dx) > math.abs(dy) then return dx > 0 and "RIGHT" or "LEFT" end
    return dy > 0 and "TOP" or "BOTTOM"
end

local function Gap(info)
    local side = info.side
    if side == "LEFT" then return -(info.x or 0) end
    if side == "RIGHT" then return info.x or 0 end
    if side == "TOP" then return info.y or 0 end
    return -(info.y or 0)
end

local function SetGap(info, gap)
    local side = info.side
    if side == "LEFT" then info.x = -gap
    elseif side == "RIGHT" then info.x = gap
    elseif side == "TOP" then info.y = gap
    else info.y = -gap end
end

local function Leader(label)
    local info = AnchorOf(label)
    if info then return info.target end
    local item = placement.byLabel[label]
    return item and item.follows and item.follows()
end

local function Follows(label, root)
    local leader, depth = Leader(label), 0
    while leader and depth < MAX_DEPTH do
        if leader == root then return true end
        leader, depth = Leader(leader), depth + 1
    end
    return false
end

local function Held(item)
    return HELD_EDGE[item.grow] or NO_EDGE
end

local function Capture(item, info)
    local target = placement.byLabel[info.target]
    if not target then return end
    local tl, tr, tt, tb = Box(target)
    local cl, cr, ct, cb = Box(item)
    if not (tl and cl) then return end
    local fl, fr, ft, fb = Bounds(target.frame)
    local held, side = Held(item), info.side
    local alongX = (cl + cr + held[1] * (cr - cl) - fl - fr) / 2
    local alongY = (ct + cb + held[2] * (ct - cb) - ft - fb) / 2
    if side == "LEFT" then info.x, info.y = cr - tl, alongY
    elseif side == "RIGHT" then info.x, info.y = cl - tr, alongY
    elseif side == "TOP" then info.x, info.y = alongX, cb - tt
    else info.x, info.y = alongX, ct - tb end
end

local function Apply(item)
    local info = not item.ownAnchor and AnchorOf(item.label)
    local target = info and placement.byLabel[info.target]
    if not target then return end
    local tl, tr, tt, tb = Box(target)
    local cl, cr, ct, cb = Box(item)
    if not (tl and cl) then return end
    if InCombatLockdown() and item.frame:IsProtected() then
        placement.parked = true
        return
    end
    local fl, fr, ft, fb = Bounds(target.frame)
    local w, h, x, y, side = cr - cl, ct - cb, info.x or 0, info.y or 0, info.side
    local held = Held(item)
    local cx, cy = (fl + fr - held[1] * w) / 2 + x, (ft + fb - held[2] * h) / 2 + y
    if side == "LEFT" then MoveTo(item, tl + x - w / 2, cy)
    elseif side == "RIGHT" then MoveTo(item, tr + x + w / 2, cy)
    elseif side == "TOP" then MoveTo(item, cx, tt + y + h / 2)
    else MoveTo(item, cx, tb + y - h / 2) end
end

local function Propagate(label, visited)
    visited = visited or {}
    if visited[label] then return end
    visited[label] = true
    for child, info in pairs(Anchors()) do
        if type(info) == "table" and info.target == label then
            local item = placement.byLabel[child]
            if item and item ~= placement.dragging then
                Apply(item)
                Propagate(child, visited)
            end
        end
    end
end

local function Depth(label)
    local depth, info = 0, AnchorOf(label)
    while info and depth < MAX_DEPTH do
        depth = depth + 1
        info = AnchorOf(info.target)
    end
    return depth
end

local function ByDepth(a, b) return a.depth < b.depth end

local function ReapplyAll()
    local list = {}
    for label in pairs(Anchors()) do
        local item = placement.byLabel[label]
        if item then list[#list + 1] = { item = item, depth = Depth(label) } end
    end
    table.sort(list, ByDepth)
    for _, e in ipairs(list) do Apply(e.item) end
end

local function Moved(item)
    local info = not item.ownAnchor and AnchorOf(item.label)
    if info then Capture(item, info) end
    Propagate(item.label)
end

local function RunBatch()
    batchQueued = false
    local labels = queued
    queued = {}
    for label, kind in pairs(labels) do
        local item = placement.byLabel[label]
        if kind == "size" and item and item ~= placement.dragging and not item.sizing then Apply(item) end
        Propagate(label)
    end
end

local function Queue(label, kind)
    if queued[label] ~= "size" then queued[label] = kind or "move" end
    if batchQueued then return end
    batchQueued = true
    C_Timer.After(0, RunBatch)
end

H.placement = placement
H.Grouped, H.Pixel, H.Bounds, H.Box = Grouped, Pixel, Bounds, Box
H.Place, H.AtCenter, H.MoveTo, H.Position = Place, AtCenter, MoveTo, Position
H.CopyAnchor, H.Anchors, H.AnchorOf, H.Marks = CopyAnchor, Anchors, AnchorOf, Marks
H.IsHidden, H.IsLocked, H.SideOf, H.Gap, H.SetGap = IsHidden, IsLocked, SideOf, Gap, SetGap
H.Follows, H.Capture, H.Apply, H.Propagate = Follows, Capture, Apply, Propagate
H.ReapplyAll, H.Moved, H.Queue = ReapplyAll, Moved, Queue

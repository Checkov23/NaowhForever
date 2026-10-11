-- Run with Lua 5.1 from the repository root: The HUD Editor's movers, run against frame stubs
-- with real geometry. Drags, arrow keys, typed X and Y and Center save the element CENTER on
-- the screen centre; a drag lines up on guides and even gaps; Anchor ties an element to another
-- so it follows from the side picked on the tag or the target's tabs, keeping a typed gap; the Elements panel finds, hides and locks
-- them; every change can be undone; Shift-click selects several to move, align and space
-- together; layouts keep every position under a name; and the anchors and snap switch from
-- before are dropped without moving anything.
local checks = 0
local function Check(ok, label) assert(ok, label); checks = checks + 1 end
local function Near(a, b) return a and b and math.abs(a - b) < 0.01 end

local W, H = 1920, 1080
local FRACTION = { TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 },
    CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 } }
local NOOP = function() end

local made = {}
local Frame = {}
-- Methods the code only calls for looks (SetFrameStrata, SetAlpha...) do nothing.
local FrameMeta = { __index = function(_, k)
    if Frame[k] then return Frame[k] end
    if type(k) == "string" and k:match("^%u") then return NOOP end
end }
local UIParent

local function NewFrame(kind, parent)
    local f = setmetatable({ kind = kind, parent = parent, scripts = {}, hooks = {}, shown = true, points = {},
        events = {}, level = 1, w = 0, h = 0 }, FrameMeta)
    made[#made + 1] = f
    return f
end

-- Left, bottom, right, top on the screen.
local function Rect(f)
    if f == UIParent then return 0, 0, W, H end
    if f.allRel then return Rect(f.allRel) end
    local p = f.points[1]
    if not p then return end
    local rl, rb, rr, rt = Rect(p[2])
    if not rl then return end
    local ax = rl + (rr - rl) * FRACTION[p[3]][1] + p[4]
    local ay = rb + (rt - rb) * FRACTION[p[3]][2] + p[5]
    local w, h = f:GetWidth(), f:GetHeight()
    local l, b = ax - w * FRACTION[p[1]][1], ay - h * FRACTION[p[1]][2]
    return l, b, l + w, b + h
end

local function Fire(f, name, ...)
    if f.scripts[name] then f.scripts[name](f, ...) end
    for _, fn in ipairs(f.hooks[name] or {}) do fn(f, ...) end
end

function Frame:SetScript(name, fn) self.scripts[name] = fn; self.hooks[name] = nil end
function Frame:GetScript(name) return self.scripts[name] end
function Frame:HookScript(name, fn)
    self.hooks[name] = self.hooks[name] or {}
    table.insert(self.hooks[name], fn)
end
function Frame:Show()
    if self.shown then return end
    self.shown = true
    Fire(self, "OnShow")
end
function Frame:Hide()
    if not self.shown then return end
    self.shown = false
    Fire(self, "OnHide")
end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent == UIParent or self.parent:IsVisible()) end
function Frame:IsMouseOver() return self.mouseOver == true end
function Frame:ClearAllPoints() self.points = {}; self.allRel = nil end
function Frame:SetPoint(point, rel, relPoint, x, y)
    if type(rel) == "number" then rel, relPoint, x, y = nil, point, rel, relPoint end
    self.allRel = nil
    self.points[#self.points + 1] = { point, rel or self.parent, relPoint or point, x or 0, y or 0 }
    local a, b = self.points[1], self.points[2]
    if b and a[1] == "TOPLEFT" and b[1] == "BOTTOMRIGHT" and a[2] == b[2] then self:SetAllPoints(a[2]) end
end
function Frame:SetAllPoints(rel) self.points = {}; self.allRel = rel or self.parent end
function Frame:GetNumPoints()
    if self.allRel then return 2 end
    return #self.points
end
function Frame:GetPoint(i)
    if self.allRel then
        if i == 2 then return "BOTTOMRIGHT", self.allRel, "BOTTOMRIGHT", 0, 0 end
        return "TOPLEFT", self.allRel, "TOPLEFT", 0, 0
    end
    local p = self.points[i or 1]
    if p then return p[1], p[2], p[3], p[4], p[5] end
end
function Frame:SetSize(w, h)
    local changed = w ~= self.w or h ~= self.h
    self.w, self.h = w, h
    if changed then Fire(self, "OnSizeChanged", w, h) end
end
function Frame:SetWidth(w) self:SetSize(w, self.h) end
function Frame:SetHeight(h) self:SetSize(self.w, h) end
function Frame:GetWidth()
    if self.allRel then return self.allRel:GetWidth() end
    return self.w
end
function Frame:GetHeight()
    if self.allRel then return self.allRel:GetHeight() end
    return self.h
end
function Frame:GetLeft() local l = Rect(self); return l end
function Frame:GetBottom() local _, b = Rect(self); return b end
function Frame:GetRight() local _, _, r = Rect(self); return r end
function Frame:GetTop() local _, _, _, t = Rect(self); return t end
function Frame:GetCenter()
    local l, b, r, t = Rect(self)
    if l then return (l + r) / 2, (b + t) / 2 end
end
function Frame:GetEffectiveScale() return 1 end
function Frame:GetFrameLevel() return self.level end
function Frame:SetFrameLevel(v) self.level = v end
function Frame:RegisterEvent(e) self.events[e] = true end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:EnableKeyboard(v) self.keyboard = v end
function Frame:SetPropagateKeyboardInput(v) self.propagate = v end
function Frame:IsProtected() return self.protected == true end
function Frame:SetText(text) self.text_ = text end
function Frame:GetText() return self.text_ end
function Frame:HasFocus() return false end
function Frame:CreateTexture() return NewFrame("Texture", self) end
function Frame:SetColorTexture(r, g, b, a) self.colorTex = { r, g, b, a } end
function Frame:CreateLine() return NewFrame("Line", self) end
function Frame:CreateFontString() return NewFrame("FontString", self) end
function Frame:GetStringWidth() return #(self.text_ or "") * 6 end
function Frame:GetStringHeight() return 12 end
function Frame:SetTextColor(r, g, b, a) self.color = { r, g, b, a } end
function Frame:SetAlpha(a) self.alpha = a end
function Frame:EnableMouse(v) self.mouse = v end
function Frame:SetTexture(t) self.texture = t end

UIParent = NewFrame("Frame")
UIParent.w, UIParent.h = W, H
function UIParent:GetWidth() return W end
function UIParent:GetHeight() return H end

local timers = {}
local function Flush()
    for _ = 1, 20 do
        if #timers == 0 then return end
        local run = timers
        timers = {}
        for _, fn in ipairs(run) do fn() end
    end
end

local cursor = { x = 0, y = 0 }
local combat, shift, alt, ctrl = false, false, false, false
local settings = {}
local printed = {}
local menu, prompt, confirm
local T = { accent = { r = 0, g = 0.5, b = 1 }, accentSoft = { r = 0.3, g = 0.7, b = 1 }, fg = { r = 1, g = 1, b = 1 },
    muted = { r = 0.6, g = 0.6, b = 0.6 }, line = { r = 0.2, g = 0.2, b = 0.2 }, grey = { r = 0.2, g = 0.2, b = 0.2 },
    panel = { r = 0.1, g = 0.1, b = 0.1 }, bg = { r = 0, g = 0, b = 0 } }
local ns = {
    THEME = T,
    UnlockModeSettings = {
        DB = function() return settings end,
        Get = function(k) return settings[k] end,
        Set = function(k, v) settings[k] = v end,
        Default = function() return {} end,
    },
    Solid = function(parent) return parent:CreateTexture() end,
    Border = function(frame)
        local b = { _frame = NewFrame("Frame", frame) }
        function b.SetColor(_, r, g, bl, a) b.color = { r, g, bl, a } end
        return b
    end,
    Font = function(parent) return parent:CreateFontString() end,
    NewEditBox = function(parent)
        local box = NewFrame("EditBox", parent)
        box.border = { SetColor = NOOP }
        function box:SetFocus() self.focus = true end
        function box:HasFocus() return self.focus == true end
        function box:ClearFocus()
            if not self.focus then return end
            self.focus = false
            Fire(self, "OnEditFocusLost")
        end
        return box
    end,
    Tooltip = NOOP,
    Button = function(parent, text, w, h, onClick)
        local b = NewFrame("Button", parent)
        b:SetSize(w, h)
        b.text_ = text
        b.label = b:CreateFontString()
        b._border = { SetColor = function(self, r, g, bl) self.color = { r, g, bl } end }
        b:SetScript("OnClick", onClick)
        return b
    end,
    SetButtonText = function(b, text) b.text_ = text end,
    Shared = {
        Parts = {
            HudText = function(fs) return fs end,
            Backdrop = function() return { Paint = NOOP } end,
            SearchBox = function(parent, _, onChange)
                local box = NewFrame("EditBox", parent)
                box.text_ = ""
                function box:SetText(t) self.text_ = t; onChange(t) end
                return box
            end,
            IconButton = function(parent, onClick, _, _, tip)
                local b = NewFrame("Button", parent)
                b.icon = b:CreateTexture()
                b.tip = tip
                b:SetScript("OnClick", onClick)
                return b
            end,
        },
        Style = { GUIDE_RGB = { r = 0.95, g = 0.64, b = 0.23 }, LOCK = "lock", EYE = "eye", EYE_OFF = "eye_off",
            SEARCH_H = 24, BACKDROP_ALPHA = 1, BORDER_RGB = { r = 0, g = 0, b = 0 }, PLACE_DOT = " . ", LOGO = "logo" },
    },
    AllowOffscreen = NOOP,
    Hairline = NOOP,
    AccentBorder = function(b) return b end,
    StashOptionsWindow = function() return false end,
    UIFontPath = function() return "font" end,
    L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    Color = function(_, text) return text end,
    Print = function(msg) printed[#printed + 1] = msg end,
    PromptText = function(title, text, maxLetters, onAccept)
        prompt = { title = title, text = text, maxLetters = maxLetters, accept = onAccept }
    end,
    Confirm = function(text, onYes) confirm = { text = text, yes = onYes } end,
    HideUnlockMode = function() printed[#printed + 1] = "left HUD Editor" end,
    OpenOptionsWindow = function(page) printed[#printed + 1] = "opened " .. page end,
    Apply = NOOP,
}
local UI = {}
ns.UI = UI
UI.SlimScroll = function(parent) return NewFrame("ScrollFrame", parent) end
UI.BuildToggleControl = function(parent)
    local switch = NewFrame("Button", parent)
    switch._refreshValue = NOOP
    return switch
end

local env = setmetatable({
    NaowhForever = ns,
    UIParent = UIParent,
    CreateFrame = function(kind, _, parent) return NewFrame(kind, parent) end,
    PixelUtil = {
        GetPixelToUIUnitFactor = function() return 1 end,
        GetNearestPixelSize = function(v, scale) return math.floor(v * scale + 0.5) / scale end,
    },
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    InCombatLockdown = function() return combat end,
    IsShiftKeyDown = function() return shift end,
    IsAltKeyDown = function() return alt end,
    IsControlKeyDown = function() return ctrl end,
    GetCurrentKeyBoardFocus = function() return nil end,
    MenuUtil = { CreateContextMenu = function(owner, gen) menu = { owner = owner, gen = gen } end },
    strtrim = function(text) return (text:gsub("^%s+", ""):gsub("%s+$", "")) end,
    GetCursorPosition = function() return cursor.x, cursor.y end,
    GetTime = function() return 0 end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    hooksecurefunc = function(tbl, name, fn)
        local orig = tbl[name]
        tbl[name] = function(...)
            orig(...)
            fn(...)
        end
    end,
}, { __index = _G })
env._G = env
-- The HUD Editor is several files (Core/Options.xml lists them in load order).
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^Core/Unlock/.-%.lua$")) do
    local f = assert(io.open(path, "rb"))
    local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
    local chunk = assert(loadstring(source, path))
    setfenv(chunk, env)
    chunk()
end

local function Display(label, w, h, x, y, ownAnchor)
    local frame = NewFrame("Frame", UIParent)
    frame:SetSize(w, h)
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
    local saved = {}
    local mover = UI.AttachMover(frame, label, function(pos) saved[#saved + 1] = pos end, "QoL/General", nil, ownAnchor)
    mover:Show()
    return frame, mover, saved
end

local function Center(frame) return frame:GetCenter() end
local function Last(saved) return saved[#saved] end

local function Click(handle, button)
    Fire(handle, "OnMouseDown", button)
    Fire(handle, "OnMouseUp", button)
end

-- The drag driver's frame update.
local function Drive()
    for _, fr in ipairs(made) do
        if fr.scripts.OnUpdate and fr.kind == "Frame" and fr.parent == nil then fr.scripts.OnUpdate(fr, 0) end
    end
end

local meter, meterMover, meterSaved = Display("Threat Meter", 200, 20, 0, -200)
local swing, swingMover, swingSaved = Display("Swing Timer", 100, 40, -40, 25)
UI.BeginMoverMode()
local keys
for _, fr in ipairs(made) do
    if fr.scripts.OnKeyDown then keys = fr end
end
Check(keys and keys.keyboard and keys.events.PLAYER_REGEN_DISABLED, "HUD Editor takes the arrow keys and watches combat")

-- Hovering lights the mover up and leaves its size alone.
local dura, duraMover = Display("Durability", 40, 40, 500, 300)
Check(duraMover._border.color[1] == 0 and duraMover._border.color[2] == 0 and duraMover._border.color[3] == 0,
    "a mover at rest has a black edge")
Fire(duraMover, "OnEnter")
Flush()
Check(duraMover._placement.hovered and duraMover:GetWidth() == 40 and duraMover:GetLeft() == dura:GetLeft(),
    "hovering lights a mover without growing it")
Fire(duraMover, "OnLeave")
duraMover:Hide()

-- Arrow keys move it a pixel, Shift + arrow 10, saved CENTER on the screen centre.
UI.SelectMover(swingMover)
Fire(keys, "OnKeyDown", "RIGHT")
Check(Near(Center(swing), 921), "an arrow nudges it a pixel")
Check(Last(swingSaved).point == "CENTER" and Last(swingSaved).relPoint == "CENTER" and Near(Last(swingSaved).x, -39)
    and Near(Last(swingSaved).y, 25), "and saves it CENTER on the screen centre")
shift = true
Fire(keys, "OnKeyDown", "UP")
shift = false
Check(Near(Last(swingSaved).y, 35), "Shift + arrow nudges by 10")
for _ = 1, 10 do Fire(keys, "OnKeyDown", "DOWN") end
Check(Near(Last(swingSaved).y, 25), "and back")
Check(settings.anchors == nil, "nothing is anchored")

-- The X and Y tag on the selected mover: its centre from the screen centre, kept up by the
-- arrow keys, and typed to move it. Just below the mover, above it at the screen's bottom.
local function Tag()
    for _, fr in ipairs(made) do
        if fr.x and fr.y and fr.x.axis == "X" then return fr end
    end
end
local tag = Tag()
local function Reads(x, y) return tag.x:GetText() == x and tag.y:GetText() == y end
local function Type(box, text)
    box:SetFocus()
    box:SetText(text)
    Fire(box, "OnEnterPressed")
end
local function Below(handle) return tag:IsShown() and tag:GetTop() < handle:GetBottom() and tag:GetTop() > handle:GetBottom() - 10 end
Check(tag and tag.parent == UIParent and tag:GetPoint() == "TOP" and select(2, tag:GetPoint()) == swingMover and Below(swingMover),
    "the tag sits just below the selected mover")
Check(Reads("-39", "25"), "and shows its centre from the screen centre")
Fire(keys, "OnKeyDown", "LEFT")
Check(Reads("-40", "25") and Below(swingMover), "an arrow key updates it and it moves along")
Type(tag.x, "25")
Check(Near(Center(swing), 985) and Near(Last(swingSaved).x, 25) and Reads("25", "25"), "a typed X moves it there and saves it")
Type(tag.y, "abc")
Check(Reads("25", "25") and not tag.y:HasFocus(), "what is not a number goes back")

UI.SelectMover(meterMover)
Check(select(2, tag:GetPoint()) == meterMover and Reads("0", "-200"), "selecting another element moves the tag to it")
cursor.x, cursor.y = 960, 340
UI.StartMoverDrag(meterMover)
cursor.x, cursor.y = 1000, 330
Drive()
Check(Reads("40", "-210") and Below(meterMover), "and it follows a drag as it happens")
UI.StopMoverDrag(meterMover)
Check(Last(meterSaved).point == "CENTER" and Near(Last(meterSaved).x, 40) and Near(Last(meterSaved).y, -210),
    "the drop saves it CENTER on the screen centre")
Check(Near(Center(swing), 985), "and nothing else moves with it")
Type(tag.x, "0")
Type(tag.y, "-200")
Check(Near(Center(meter), 960) and Near(select(2, Center(meter)), 340) and Near(Last(meterSaved).y, -200),
    "typed numbers move it there and save it")
Type(tag.y, "-525")
Check(tag:GetPoint() == "BOTTOM" and tag:GetBottom() > meterMover:GetTop() and tag:GetBottom() < meterMover:GetTop() + 10,
    "with no room below it flips above the mover")
Type(tag.y, "-200")
Check(tag:GetPoint() == "TOP" and Below(meterMover), "and back below with room again")
Click(meterMover, "RightButton")
Check(Below(meterMover) and meterMover._placement.selected, "a right-click does nothing")
Fire(keys, "OnKeyDown", "ESCAPE")
Check(not tag:IsShown(), "Escape lets the selection go and the tag with it")

-- The tag's Center and Settings: Center moves it across to the middle and saves it, Settings
-- leaves the HUD Editor for the element's page.
Click(swingMover, "LeftButton")
Check(tag.center:IsShown() and tag.settings:IsShown(), "the tag has Center and Settings")
Fire(tag.center, "OnClick")
Check(Near(Center(swing), 960) and Near(Last(swingSaved).x, 0) and Near(Last(swingSaved).y, 25),
    "Center moves it across to the middle and keeps its height")
Fire(tag.settings, "OnClick")
Check(not tag:IsShown() and printed[#printed] == "opened QoL/General",
    "Settings leaves the HUD Editor, then opens its page")
UI.BeginMoverMode()
local _, bareMover = Display("Loose", 60, 20, 300, 0)
bareMover._placement.page = nil
Click(bareMover, "LeftButton")
Check(tag.item == bareMover._placement and not tag.settings:IsShown(), "an element with no page has no Settings")
bareMover:Hide()
Check(not tag:IsShown(), "hiding the selected mover lets it go")

-- Guides: a drag within a few pixels of another element's edge, or of the screen centre, lands
-- on it, the guide drawn with the gap to that element; Alt, or the Guides switch off, lets it
-- go where it is dropped. Where the drag started shows as a faint outline until the drop.
local overlayFrame
local function Overlay()
    for _, fr in ipairs(made) do
        if fr.level == 220 and fr.allRel == UIParent then return fr end
    end
end
local function Shown(kind)
    local out = {}
    local o = Overlay()
    for _, fr in ipairs(made) do
        if fr.parent == o and fr.kind == kind and fr:IsShown() then out[#out + 1] = fr end
    end
    return out
end
local function Gaps()
    local out = {}
    for _, plate in ipairs(Shown("Frame")) do out[#out + 1] = plate.text:GetText() end
    return table.concat(out, " ")
end
local function DragBy(handle, frame, dx, dy, keep)
    local cx, cy = Center(frame)
    cursor.x, cursor.y = cx, cy
    UI.StartMoverDrag(handle)
    cursor.x, cursor.y = cx + dx, cy + dy
    Drive()
    if not keep then UI.StopMoverDrag(handle) end
end
-- swing is 100 x 40 at (0, 25) after Center; meter is 200 x 20 at (0, -200): line swing's left up
-- 4 pixels off meter's left, well off the screen centre.
local mL = meter:GetLeft()
swing:ClearAllPoints()
swing:SetPoint("CENTER", UIParent, "CENTER", -300, 25)
Flush()
DragBy(swingMover, swing, mL - swing:GetLeft() + 4, 0, true)
overlayFrame = Overlay()
Check(Near(swing:GetLeft(), mL), "a drag a few pixels off another element's edge lands on it")
local lines = Shown("Texture")
Check(#lines >= 5 and overlayFrame and overlayFrame.level > swingMover.level, "the guide is drawn, with the start's outline, over the movers")
Check(Gaps() == tostring(math.floor(swing:GetBottom() - meter:GetTop() + 0.5)), "with the gap to the element it lines up with")
UI.StopMoverDrag(swingMover)
Check(#Shown("Texture") == 0 and Gaps() == "", "the drop clears the guides and the outline")
Check(Near(Last(swingSaved).x, (mL + 50) - 960), "and saves where it landed")

DragBy(swingMover, swing, 0, 0, true)
cursor.x = cursor.x + (960 - Center(swing)) - 3
Drive()
Check(Near(Center(swing), 960), "the screen centre pulls it too")
UI.StopMoverDrag(swingMover)

alt = true
DragBy(swingMover, swing, mL - swing:GetLeft() + 4, 0)
alt = false
Check(Near(swing:GetLeft(), mL + 4), "with Alt held it stays where it is dropped")
settings.guides = false
DragBy(swingMover, swing, -8, 0, true)
Check(Near(swing:GetLeft(), mL - 4) and #Shown("Texture") == 4, "and with the Guides switch off, only the outline shows")
UI.StopMoverDrag(swingMover)
settings.guides = nil

-- Anchor on the tag: lit while it waits for a target, the next element clicked becomes the
-- target, and from then on the element follows it, keeping its gap.
local boss, bossMover = Display("Boss Bar", 100, 20, 0, 300)
local add, addMover, addSaved = Display("Add Bar", 60, 20, 20, 270)
Flush()
Click(addMover, "LeftButton")
Check(tag.anchor:IsShown() and tag.anchor:GetText() == "Anchor", "the tag has Anchor")
Fire(tag.anchor, "OnClick")
Check(tag.anchor._border.color[3] == T.accent.b and tag.anchor.label.color[3] == T.accent.b,
    "Anchor lights up while it waits for a target")
Click(bossMover, "LeftButton")
local link = settings.anchoredTo["Add Bar"]
Check(link and link.target == "Boss Bar" and link.side == "BOTTOM" and Near(link.x, 20) and Near(link.y, -10),
    "clicking another element anchors to its nearest side, where it is")
Check(tag.item == addMover._placement and tag.anchor:GetText() == "Unanchor"
    and tag.anchor._border.color[3] == 0, "the element stays selected and its button reads Unanchor")

UI.SelectMover(bossMover)
shift = true
Fire(keys, "OnKeyDown", "RIGHT")
shift = false
Check(Near(Center(add), 990) and Near(Last(addSaved).x, 30) and Near(Last(addSaved).y, 270),
    "moving the target takes the anchored element along and saves it")
local addSaves = #addSaved
cursor.x, cursor.y = Center(boss)
UI.StartMoverDrag(bossMover)
cursor.x = cursor.x + 50
Drive()
Check(Near(Center(add), 1040) and #addSaved == addSaves, "it follows a drag as it happens")
UI.StopMoverDrag(bossMover)
Check(Near(Last(addSaved).x, 80), "and is saved on the drop")
boss:SetHeight(40)
Flush()
Check(Near(add:GetTop(), boss:GetBottom() - 10), "a target that grows pushes it out, keeping the gap")

UI.SelectMover(addMover)
Fire(keys, "OnKeyDown", "DOWN")
Check(Near(link.y, -11), "moving the element itself keeps the anchor with the new gap")
boss:ClearAllPoints()
boss:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
Flush()
Check(Near(add:GetTop(), boss:GetBottom() - 11) and Near(Last(addSaved).y, -41),
    "a target the module moves itself takes it along too")

UI.SelectMover(bossMover)
Fire(tag.anchor, "OnClick")
Click(addMover, "LeftButton")
Check(settings.anchoredTo["Boss Bar"] == nil and printed[#printed]:find("Boss Bar", 1, true),
    "an element cannot anchor to one that already follows it")
Fire(tag.anchor, "OnClick")
Fire(keys, "OnKeyDown", "ESCAPE")
Check(tag:IsShown() and tag.item == bossMover._placement and tag.anchor._border.color[3] == 0,
    "Escape calls a pick off and keeps the selection")
Fire(tag.anchor, "OnClick")
Click(bossMover, "LeftButton")
Check(settings.anchoredTo["Boss Bar"] == nil and tag.item == bossMover._placement, "so does clicking the element itself")
Fire(tag.anchor, "OnClick")
Fire(tag.anchor, "OnClick")
Check(tag.anchor._border.color[3] == 0, "and Anchor again")

-- The tag's second row while anchored: the side it sits off, and the gap, typed. A new side keeps
-- the gap; the anchor shows as a line from the target with the gap on it.
UI.SelectMover(addMover)
Check(tag.sides:IsShown() and tag.side.BOTTOM._border.color[3] == T.accent.b and tag.side.TOP._border.color[3] == 0,
    "an anchored element's tag shows its side, lit")
Check(tag.gap:GetText() == "11" and tag:GetHeight() > 30, "and the gap, on a second row")
local function AnchorGap() return Gaps() end
Check(AnchorGap() == "11", "the anchor is drawn from the target, its gap written on it")
local function Tabs()
    local out = {}
    for _, fr in ipairs(made) do
        if fr.parent == Overlay() and fr.kind == "Button" and fr:IsShown() then out[#out + 1] = fr end
    end
    return out
end
local function TabAt(x, y)
    for _, tab in ipairs(Tabs()) do
        local cx, cy = tab:GetCenter()
        if Near(cx, x) and Near(cy, y) then return tab end
    end
end
local bx, by = Center(boss)
Check(#Tabs() == 4 and TabAt(bx, boss:GetBottom()).fill.colorTex[3] == T.accent.b
    and TabAt(boss:GetLeft(), by).fill.colorTex[3] == T.bg.b, "the target shows a tab on each side, the one it sits off filled")
Fire(TabAt(boss:GetRight(), by), "OnClick")
Check(link.side == "RIGHT" and Near(add:GetLeft(), boss:GetRight() + 11)
    and TabAt(boss:GetRight(), by).fill.colorTex[3] == T.accent.b, "a click on another tab moves it to that side")
Fire(TabAt(bx, boss:GetBottom()), "OnClick")
Check(link.side == "BOTTOM" and Near(add:GetTop(), boss:GetBottom() - 11), "and back")
Fire(tag.side.RIGHT, "OnClick")
Check(link.side == "RIGHT" and Near(add:GetLeft(), boss:GetRight() + 11) and Near(select(2, Center(add)), select(2, Center(boss))),
    "a new side moves it off that side, keeping the gap, centred along it")
Check(tag.side.RIGHT._border.color[3] == T.accent.b and tag.side.BOTTOM._border.color[3] == 0, "and lights it")
Check(Near(Last(addSaved).x, (boss:GetRight() + 11 + 30) - 960), "and saves it")
Type(tag.gap, "20")
Check(Near(add:GetLeft(), boss:GetRight() + 20) and tag.gap:GetText() == "20" and AnchorGap() == "20", "a typed gap moves it out")
Fire(tag.side.LEFT, "OnClick")
Check(Near(add:GetRight(), boss:GetLeft() - 20), "left keeps the gap too")
Fire(tag.side.TOP, "OnClick")
Check(Near(add:GetBottom(), boss:GetTop() + 20) and Near(Center(add), Center(boss)), "and so does top")
Fire(tag.side.BOTTOM, "OnClick")
Type(tag.gap, "11")
Check(Near(add:GetTop(), boss:GetBottom() - 11), "back under it")

UI.SelectMover(addMover)
local addSpot = { Center(add) }
Fire(tag.anchor, "OnClick")
Check(settings.anchoredTo["Add Bar"] == nil and tag.anchor:GetText() == "Anchor", "Unanchor lets go")
Check(not tag.sides:IsShown() and Gaps() == "" and #Tabs() == 0, "and the side row, the anchor line and the tabs go with it")
Fire(tag.anchor, "OnClick")
Fire(keys, "OnKeyDown", "ESCAPE")
boss:ClearAllPoints()
boss:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
Flush()
Check(Near(Center(add), addSpot[1]) and Near(select(2, Center(add)), addSpot[2]), "and it stays put after")

local _, fireMover = Display("Fire", 30, 30, -300, 0, true)
Click(fireMover, "LeftButton")
Check(not tag.anchor:IsShown() and tag.settings:IsShown(), "an element that holds its own spot has no Anchor")
UI.ClearMoverSelection()

-- Profile switches put anchored elements back on their targets, parents first.
settings.anchoredTo = {
    ["Add Bar"] = { target = "Boss Bar", side = "BOTTOM", x = 0, y = -5 },
    ["Fire"] = { target = "Boss Bar", side = "TOP", x = 0, y = 5 },
}
local login
for _, fr in ipairs(made) do
    if fr.events.PLAYER_LOGIN then login = fr end
end
settings.snap = false
ns.Apply()
Check(settings.snap == false, "nothing is dropped before the profile loads")
login.scripts.OnEvent(login, "PLAYER_LOGIN")
ns.Apply()
Flush()
Check(Near(add:GetTop(), boss:GetBottom() - 5) and Near(Center(add), 960), "a profile switch re-places anchored elements")
Check(Near(select(2, Center(fireMover._placement.frame)), 540), "but not one that holds its own spot")
settings.anchoredTo = nil
for _, m in ipairs({ bossMover, addMover, fireMover }) do m:Hide() end

-- A target whose plate grows from its bottom with what it shows, like the Alerts stack: off its
-- side an element keeps its height, above it the element is pushed up.
local stack, stackMover = Display("Stack", 100, 20, -500, -300)
stackMover:ClearAllPoints()
stackMover:SetPoint("BOTTOM", stack, "BOTTOM")
stackMover:SetSize(100, 80)
local beside, besideMover = Display("Beside", 40, 20, -400, -300)
local above, aboveMover = Display("Above", 40, 20, -500, -200)
settings.anchoredTo = {
    ["Beside"] = { target = "Stack", side = "RIGHT", x = 10, y = 0 },
    ["Above"] = { target = "Stack", side = "TOP", x = 0, y = 10 },
}
ns.Apply()
Flush()
local besideY = select(2, Center(beside))
Check(Near(besideY, select(2, Center(stack))) and Near(above:GetBottom(), stackMover:GetTop() + 10),
    "off the side it lines up with the target's own frame, above it clears the plate")
stackMover:SetSize(100, 20)
Flush()
Check(Near(select(2, Center(beside)), besideY) and Near(above:GetBottom(), stackMover:GetTop() + 10),
    "when the plate shrinks the one beside it stays, the one above comes down")
settings.anchoredTo = nil
for _, m in ipairs({ stackMover, besideMover, aboveMover }) do m:Hide() end

-- Anchors and the snap switch saved before they were dropped: both go at login and on every
-- profile switch, and nothing moves, since each element's own position already holds where its
-- anchor put it.
settings.anchors = { ["Swing Timer"] = { target = "Threat Meter", side = "TOP", offsetX = 0, offsetY = 0 } }
settings.snap = false
local before, saves = { Center(swing) }, #swingSaved
ns.Apply()
Check(settings.anchors == nil and settings.snap == nil, "the profile's anchors and snap switch are dropped")
Check(Near(Center(swing), before[1]) and #swingSaved == saves, "without moving or saving anything")
settings.anchors = { ["Threat Meter"] = { target = "SCREEN_LEFT", side = "RIGHT" } }
ns.Apply()
Check(settings.anchors == nil, "and a switched-to profile's are dropped too")

-- The Loot Feed anchored to Alerts (shipped before 1.1.3, on any side since) is let go once per
-- profile, in its saved layouts too; one set afterwards stays.
settings.lootFeedOffAlerts = nil
settings.anchoredTo = {
    ["Loot Feed"] = { target = "Alerts", side = "TOP", x = -276.67, y = -968.63 },
    ["Add Bar"] = { target = "Boss Bar", side = "BOTTOM", x = 0, y = -5 },
}
settings.layouts = { Old = { spots = {}, anchors = { ["Loot Feed"] = { target = "Alerts", side = "RIGHT", x = -300, y = 206 } } } }
ns.Apply()
Flush()
Check(settings.anchoredTo["Loot Feed"] == nil and settings.anchoredTo["Add Bar"].target == "Boss Bar",
    "the Loot Feed lets go of Alerts, other anchors stay")
Check(settings.layouts.Old.anchors["Loot Feed"] == nil, "and a saved layout lets go too")
settings.anchoredTo["Loot Feed"] = { target = "Alerts", side = "TOP", x = 0, y = 10 }
ns.Apply()
Flush()
Check(settings.anchoredTo["Loot Feed"] ~= nil, "anchoring it again afterwards sticks")
settings.anchoredTo, settings.layouts = nil, nil

-- The Elements panel: every element on screen by module, found by name; a row's eye keeps the
-- element out of the way while editing and its padlock holds it in place.
local timer, timerMover, timerSaved = Display("Combat Timer", 120, 32, 300, 100)
timerMover._placement.page = "Threat Meter/Settings"
ns.ShowUnlockMode()
Flush()
local panel, toolbar
for _, fr in ipairs(made) do
    if fr.search and fr.rows then panel = fr end
    if fr._undo then toolbar = fr end
end
local function Rows()
    local out = {}
    for _, row in ipairs(panel.rows) do
        if row:IsShown() then out[#out + 1] = row end
    end
    return out
end
local function RowOf(label)
    for _, row in ipairs(Rows()) do
        if row.item.label == label then return row end
    end
end
local function Titles()
    local out = {}
    for _, t in ipairs(panel.titles) do
        if t:IsShown() then out[#out + 1] = t:GetText() end
    end
    return table.concat(out, " ")
end
Check(panel and panel:IsShown() and toolbar, "the HUD Editor opens with the Elements panel")
Check(RowOf("Threat Meter") and RowOf("Swing Timer") and RowOf("Combat Timer") and not RowOf("Durability"),
    "it lists the elements on screen, not the hidden plates")
Check(Titles() == "QOL THREAT METER", "grouped by module")
panel.search:SetText("swing")
Flush()
Check(#Rows() == 1 and RowOf("Swing Timer"), "the search finds by name")
panel.search:SetText("")
Flush()
Fire(RowOf("Combat Timer"), "OnClick")
Flush()
Check(tag.item == timerMover._placement and RowOf("Combat Timer").fill:IsShown(), "a click on a row selects it, lit")

Fire(RowOf("Swing Timer").eye, "OnClick")
Flush()
Check(settings.hidden["Swing Timer"] and swingMover.alpha == 0 and swingMover.mouse == false,
    "the eye keeps it out of the way: its plate clear, the mouse through it")
Check(RowOf("Swing Timer").eye.icon.texture == "eye_off" and RowOf("Swing Timer").label.color[4] < 1
    and panel.count:GetText() == "3 . 1 hidden", "its row dims and the count says so")
UI.SelectMover(swingMover)
Check(tag.item ~= swingMover._placement, "a hidden element cannot be selected")
Fire(RowOf("Swing Timer").eye, "OnClick")
Flush()
Check(not settings.hidden["Swing Timer"] and swingMover.alpha == 1 and swingMover.mouse == true, "and back")

Fire(RowOf("Combat Timer").lock, "OnClick")
Flush()
Check(settings.locked["Combat Timer"] and timerMover._lock:IsShown() and RowOf("Combat Timer").lock.tip == "Unlock",
    "the padlock holds it in place, shown on its plate")
UI.SelectMover(timerMover)
local tx, ty = Center(timer)
Fire(keys, "OnKeyDown", "RIGHT")
Type(tag.x, "0")
Fire(tag.center, "OnClick")
DragBy(timerMover, timer, 40, 0)
Check(Near(Center(timer), tx) and Near(select(2, Center(timer)), ty) and #timerSaved == 0,
    "a locked element does not move by arrow, typed number, Center or drag")
Fire(RowOf("Combat Timer").lock, "OnClick")
Flush()
Check(not settings.locked["Combat Timer"] and not timerMover._lock:IsShown(), "unlocked again")

-- Undo, Redo and Revert: a run of arrow nudges is one change, a drag another.
Check(toolbar._undo.alpha < 1 and toolbar._redo.alpha < 1 and toolbar._revert.alpha < 1, "with nothing done, Undo, Redo and Revert dim")
UI.SelectMover(timerMover)
for _ = 1, 3 do Fire(keys, "OnKeyDown", "RIGHT") end
Check(Near(Center(timer), tx + 3) and toolbar._undo.alpha == 1, "nudges move it and light Undo")
DragBy(timerMover, timer, 40, 20)
local afterDrag = { Center(timer) }
ctrl = true
Fire(keys, "OnKeyDown", "Z")
ctrl = false
Check(Near(Center(timer), tx + 3) and Near(select(2, Center(timer)), ty) and Near(Last(timerSaved).x, 303),
    "Ctrl + Z puts the drag back and saves it")
Fire(toolbar._undo, "OnClick")
Check(Near(Center(timer), tx) and toolbar._undo.alpha < 1 and toolbar._redo.alpha == 1, "Undo puts the nudges back as one")
ctrl = true
Fire(keys, "OnKeyDown", "Y")
ctrl = false
Fire(toolbar._redo, "OnClick")
Check(Near(Center(timer), afterDrag[1]) and Near(select(2, Center(timer)), afterDrag[2]), "Ctrl + Y and Redo make them again")
Fire(tag.center, "OnClick")
Check(Near(Center(timer), 960) and toolbar._redo.alpha < 1, "a new change clears Redo")
Fire(toolbar._revert, "OnClick")
Check(Near(Center(timer), tx) and Near(select(2, Center(timer)), ty) and toolbar._undo.alpha < 1,
    "Revert puts back everything since the HUD Editor opened")


Fire(toolbar._elements, "OnClick")
Check(not panel:IsShown() and settings.elementsPanel == false, "Elements hides the panel, and it stays hidden")
Fire(toolbar._elements, "OnClick")
Check(panel:IsShown() and settings.elementsPanel == true, "and shows it again")
ns.HideUnlockMode()
Check(not panel:IsShown(), "leaving the HUD Editor hides the panel")

-- Several selected: Shift-click adds and takes away, the tag gives way to a bar over an outline
-- round them all, and they align, space out, move and lock together.
for _, m in ipairs({ meterMover, swingMover, timerMover }) do m:Hide() end
local a1, a1Mover, a1Saved = Display("A1", 100, 20, -300, -300)
local a2, a2Mover = Display("A2", 60, 20, -200, -260)
local a3, a3Mover, a3Saved = Display("A3", 80, 20, -50, -320)
ns.ShowUnlockMode()
Flush()
local function Bar()
    for _, fr in ipairs(made) do
        if fr.align and fr.count and fr.across then return fr end
    end
end
local function ShiftClick(handle)
    shift = true
    Click(handle, "LeftButton")
    shift = false
end
Click(a1Mover, "LeftButton")
ShiftClick(a2Mover)
ShiftClick(a3Mover)
Flush()
local bar = Bar()
Check(bar and bar:IsShown() and bar.count:GetText() == "3 selected" and not tag:IsShown(),
    "Shift-click selects several: the tag gives way to the bar")
Check(#Shown("Texture") == 4 and bar:GetBottom() > a2:GetTop(), "an outline round them all, the bar over it")
Check(a1Mover._placement.selected and a2Mover._placement.selected and a3Mover._placement.selected
    and RowOf("A1").fill:IsShown() and RowOf("A3").fill:IsShown(), "each plate and row is lit")

Fire(bar.align.left, "OnClick")
Check(Near(a1:GetLeft(), 610) and Near(a2:GetLeft(), 610) and Near(a3:GetLeft(), 610), "Line up left edges")
Check(Near(Last(a3Saved).x, 650 - 960), "and saves each")
Fire(toolbar._undo, "OnClick")
Check(Near(a2:GetLeft(), 730) and Near(a3:GetLeft(), 870), "one Undo puts them all back")
Fire(bar.align.top, "OnClick")
Check(Near(a1:GetTop(), 290) and Near(a3:GetTop(), 290), "Line up top edges")
Fire(toolbar._undo, "OnClick")
Fire(bar.align.hcenter, "OnClick")
Check(Near(Center(a1), 780) and Near(Center(a3), 780), "Line up middles")
Fire(toolbar._undo, "OnClick")

Fire(bar.across, "OnClick")
Check(Near(a1:GetLeft(), 610) and Near(a2:GetLeft(), 760) and Near(a3:GetLeft(), 870) and bar.gap:GetText() == "50",
    "Space evenly across: first and last stay, the gaps equal, the gap shown")
Type(bar.gap, "10")
Check(Near(a2:GetLeft(), 720) and Near(a3:GetLeft(), 790), "a typed gap spaces them by it")

local p1, p3 = { Center(a1) }, { Center(a3) }
alt = true
DragBy(a1Mover, a1, 30, 15)
alt = false
Check(Near(Center(a1), p1[1] + 30) and Near(Center(a3), p3[1] + 30) and Near(select(2, Center(a3)), p3[2] + 15),
    "dragging one moves them all")
Check(Near(Last(a3Saved).x, p3[1] + 30 - 960), "and the drop saves each")
for _ = 1, 3 do Fire(keys, "OnKeyDown", "RIGHT") end
Check(Near(Center(a3), p3[1] + 33), "arrow keys move them all")
Fire(toolbar._undo, "OnClick")
Check(Near(Center(a3), p3[1] + 30), "and the run is one Undo")

Fire(bar.lock, "OnClick")
Check(settings.locked.A1 and settings.locked.A2 and settings.locked.A3 and bar.lock.tip == "Unlock all", "Lock all")
local l3 = a3:GetLeft()
Fire(bar.align.left, "OnClick")
for _ = 1, 2 do Fire(keys, "OnKeyDown", "LEFT") end
Check(Near(a3:GetLeft(), l3), "locked, they stay put")
Fire(bar.lock, "OnClick")
Check(not settings.locked.A1 and not settings.locked.A3, "and Unlock all")

ShiftClick(a2Mover)
Check(bar.count:GetText() == "2 selected" and not a2Mover._placement.selected, "Shift-click takes one away")
ShiftClick(a3Mover)
Check(not bar:IsShown() and tag:IsShown() and tag.item == a1Mover._placement, "back to one, the tag is back")
ShiftClick(a3Mover)
Fire(keys, "OnKeyDown", "ESCAPE")
Check(not bar:IsShown() and not a1Mover._placement.selected and not a3Mover._placement.selected,
    "Escape lets them all go")

-- One that follows another selected element comes along with it, once.
settings.anchoredTo = { A2 = { target = "A1", side = "BOTTOM", x = 0, y = -12 } }
ns.Apply()
Flush()
Click(a1Mover, "LeftButton")
ShiftClick(a2Mover)
local gapBefore = a1:GetBottom() - a2:GetTop()
alt = true
DragBy(a1Mover, a1, 0, 40)
alt = false
Check(Near(a1:GetBottom() - a2:GetTop(), gapBefore), "an anchored one in the selection moves once, keeping its gap")
Fire(keys, "OnKeyDown", "ESCAPE")
settings.anchoredTo = nil
ns.HideUnlockMode()

-- Layouts: every spot and anchor kept under a name, loaded back as one change; a locked element
-- stays where it is.
local function Menu()
    Fire(toolbar._layout, "OnClick")
    local entries = {}
    local root = {}
    function root.CreateTitle(_, text) entries[#entries + 1] = { kind = "title", text = text } end
    function root.CreateDivider() entries[#entries + 1] = { kind = "divider" } end
    function root.CreateButton(_, text, fn) entries[#entries + 1] = { kind = "button", text = text, fn = fn } end
    function root.CreateRadio(_, text, isSel, setSel, data)
        entries[#entries + 1] = { kind = "radio", text = text, on = isSel(data), fn = function() setSel(data) end }
    end
    menu.gen(menu.owner, root)
    return entries
end
local function Entry(entries, text)
    for _, e in ipairs(entries) do
        if e.text == text then return e end
    end
end
local function Texts(entries)
    local out = {}
    for _, e in ipairs(entries) do out[#out + 1] = e.text or "-" end
    return table.concat(out, ", ")
end
ns.ShowUnlockMode()
Flush()
Check(toolbar._layout.label:GetText() == "Layouts" and Texts(Menu()) == "Layouts, -, Save as New Layout",
    "with none saved the Layouts menu only saves a new one")
Entry(Menu(), "Save as New Layout").fn()
prompt.accept("Raid|")
local raid1, raid2 = { Center(a1) }, { Center(a2) }
Check(settings.layouts.Raid and settings.layout == "Raid" and toolbar._layout.label:GetText() == "Raid",
    "a new layout is named, its name kept clear of escape codes, and shown on the button")

UI.SelectMover(a1Mover)
for _ = 1, 4 do Fire(keys, "OnKeyDown", "UP") end
UI.SelectMover(a2Mover)
for _ = 1, 6 do Fire(keys, "OnKeyDown", "LEFT") end
settings.anchoredTo = { A3 = { target = "A1", side = "BOTTOM", x = 0, y = -8 } }
Entry(Menu(), "Save as New Layout").fn()
prompt.accept("  Solo ")
Check(settings.layouts.Solo and settings.layouts.Solo.anchors.A3.target == "A1", "a second one, anchors and all")
local entries = Menu()
Check(Texts(entries) == "Layouts, Raid, Solo, -, Save to Solo, Save as New Layout, Rename Solo, Delete Solo"
    and Entry(entries, "Solo").on and not Entry(entries, "Raid").on, "the menu lists them by name, the current one ticked")

local solo1 = { Center(a1) }
Entry(Menu(), "Raid").fn()
Check(Near(Center(a1), raid1[1]) and Near(select(2, Center(a1)), raid1[2]) and Near(Center(a2), raid2[1])
    and settings.anchoredTo.A3 == nil and toolbar._layout.label:GetText() == "Raid",
    "loading one puts every element and anchor back")
Check(Near(Last(a1Saved).y, raid1[2] - 540), "and saves each")
Fire(toolbar._undo, "OnClick")
Check(Near(select(2, Center(a1)), solo1[2]) and settings.anchoredTo.A3.target == "A1", "Undo takes the load back")

settings.locked = { A2 = true }
local held = { Center(a2) }
Entry(Menu(), "Raid").fn()
Check(Near(Center(a2), held[1]) and Near(Center(a1), raid1[1]) and Near(select(2, Center(a1)), raid1[2]),
    "a locked element stays where it is")
settings.locked = {}

combat = true
Entry(Menu(), "Solo").fn()
combat = false
Check(Near(select(2, Center(a1)), raid1[2]) and settings.layout == "Raid", "not in combat")

UI.SelectMover(a1Mover)
Fire(keys, "OnKeyDown", "DOWN")
Entry(Menu(), "Save to Raid").fn()
Check(Near(settings.layouts.Raid.spots.A1[2], raid1[2] - 1 - 540), "Save to keeps where everything is now")
Entry(Menu(), "Save as New Layout").fn()
prompt.accept("Solo")
Check(confirm and confirm.text:find("Solo") and settings.layout == "Raid", "a name in use asks before replacing it")
confirm.yes()
Check(Near(settings.layouts.Solo.spots.A1[2], raid1[2] - 1 - 540) and settings.layout == "Solo", "and replaces it")

Entry(Menu(), "Rename Solo").fn()
Check(prompt.text == "Solo", "Rename starts from the name")
prompt.accept("Raid")
Check(settings.layouts.Solo and printed[#printed]:find("already"), "a name in use is refused")
Entry(Menu(), "Rename Solo").fn()
prompt.accept("Dungeon")
Check(settings.layouts.Dungeon and not settings.layouts.Solo and settings.layout == "Dungeon"
    and toolbar._layout.label:GetText() == "Dungeon", "renamed")
confirm = nil
Entry(Menu(), "Delete Dungeon").fn()
Check(confirm and settings.layouts.Dungeon, "Delete asks first")
confirm.yes()
Check(not settings.layouts.Dungeon and settings.layouts.Raid and settings.layout == nil
    and toolbar._layout.label:GetText() == "Layouts", "and deletes it, nothing current")
UI.ClearMoverSelection()
settings.anchoredTo = nil
ns.HideUnlockMode()

-- Even gaps: a drag lands midway between two elements in line with it, a pair's gap past the
-- pair, or mirrored about the screen's centre, drawn as two equal gaps.
ns.ShowUnlockMode()
for _, fr in ipairs(made) do
    if fr._placement then fr:Hide() end
end
local function LabelAt(x, y)
    for _, plate in ipairs(Shown("Frame")) do
        local cx, cy = plate:GetCenter()
        if Near(cx, x) and Near(cy, y) then return plate.text:GetText() end
    end
end
local function DragTo(handle, frame, left, bottom)
    DragBy(handle, frame, left - frame:GetLeft(), bottom - frame:GetBottom(), true)
end
local _, e1Mover = Display("E1", 100, 20, -600, -400)
local e2, e2Mover = Display("E2", 100, 20, -200, -400)
local m, mMover = Display("M", 60, 20, -420, -350)
DragTo(mMover, m, 533, 130)
Check(Near(m:GetLeft(), 530), "a drag lands midway between two elements")
Check(LabelAt(470, 140) == "120" and LabelAt(650, 140) == "120", "the two equal gaps drawn")
UI.StopMoverDrag(mMover)

e2:ClearAllPoints()
e2:SetPoint("CENTER", UIParent, "CENTER", -400, -400)
Flush()
DragTo(mMover, m, 713, 130)
Check(Near(m:GetLeft(), 710) and LabelAt(460, 140) == "100" and LabelAt(660, 140) == "100",
    "a pair's gap past the pair, both gaps drawn")
UI.StopMoverDrag(mMover)
alt = true
DragTo(mMover, m, 713, 130)
Check(Near(m:GetLeft(), 713), "Alt lets it go there too")
UI.StopMoverDrag(mMover)
alt = false

e1Mover:Hide()
e2:ClearAllPoints()
e2:SetPoint("CENTER", UIParent, "CENTER", -300, -400)
Flush()
DragTo(mMover, m, 1213, 130)
Check(Near(m:GetLeft(), 1210) and LabelAt(835, 140) == "250" and LabelAt(1085, 140) == "250",
    "mirrored about the screen's centre")
UI.StopMoverDrag(mMover)
e2Mover:Hide()
mMover:Hide()

Display("V1", 100, 20, 500, 0)
Display("V2", 100, 20, 500, -60)
local v3, v3Mover = Display("V3", 100, 20, 500, -200)
DragTo(v3Mover, v3, v3:GetLeft(), 413)
Check(Near(v3:GetBottom(), 410) and LabelAt(1460, 450) == "40" and LabelAt(1460, 510) == "40", "and up and down")
UI.StopMoverDrag(v3Mover)

-- A module's own settings can start Anchor for its element (UI.PickAnchorFor), as the tag's button
-- does, and let an anchor go (UI.DropAnchor). An element that keeps its own anchor cannot be picked.
local _, followerMover, followerSaved = Display("Follower", 60, 20, -600, 200)
local leader, leaderMover = Display("Leader", 100, 20, -600, 260)
Flush()
UI.ClearMoverSelection()
UI.PickAnchorFor(followerMover)
Check(tag.item == followerMover._placement and tag.anchor._border.color[3] == T.accent.b,
    "a module's settings select the element and start Anchor")
Click(leaderMover, "LeftButton")
Check(settings.anchoredTo["Follower"] and settings.anchoredTo["Follower"].target == "Leader",
    "the next element clicked becomes what it follows")
leader:ClearAllPoints()
leader:SetPoint("CENTER", UIParent, "CENTER", -600, 300)
Flush()
Check(#followerSaved > 0, "and it moves with it, saved through the module")
UI.DropAnchor(followerMover)
Check(settings.anchoredTo["Follower"] == nil, "letting go drops the anchor")
local _, ownMover = Display("Own", 60, 20, -600, 100, true)
UI.ClearMoverSelection()
UI.PickAnchorFor(ownMover)
Check(tag.item ~= ownMover._placement, "an element that keeps its own anchor is not picked for one")
UI.DropAnchor(nil)
ns.HideUnlockMode()

print(("test-unlock-mode: %d checks passed"):format(checks))

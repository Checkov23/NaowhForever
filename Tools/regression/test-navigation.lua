-- Exercise the real window, widgets and search using addon-owned sample settings.
-- Geometry is a test double; this does not emulate the game's renderer or taint rules.
local frames, timers = {}, {}
local methods = {}
local NOTHING_NS = setmetatable({}, { __index = function() return function() end end })
local env = setmetatable({}, { __index = function(_, k)
    local v = _G[k]
    if v ~= nil then return v end
    if type(k) == "string" and k:find("^C_") then return NOTHING_NS end
end })
env._G = env
local function New(kind, name, parent)
    local f = setmetatable({ kind = kind, name = name, parent = parent, points = {}, scripts = {},
        children = {}, visible = true, width = 0, height = 0, level = parent and parent.level + 1 or 0 },
        { __index = methods })
    frames[#frames + 1] = f
    if parent then parent.children[#parent.children + 1] = f end
    if name then env[name] = f end
    return f
end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:SetPoint(point, relative, relativePoint, x, y)
    if type(relative) == "number" then x, y, relative, relativePoint = relative, relativePoint, self.parent, point
    elseif relative == nil then relative, relativePoint, x, y = self.parent, point, 0, 0
    elseif type(relativePoint) == "number" then x, y, relativePoint = relativePoint, x, point end
    self.points[point] = { relative or self.parent, relativePoint or point, x or 0, y or 0 }
end
function methods:ClearAllPoints() self.points = {}; self.all = nil end
function methods:SetAllPoints(f) self.all = f or self.parent end
function methods:GetWidth()
    if self.all then return self.all:GetWidth() end
    local left, right = self.points.TOPLEFT or self.points.BOTTOMLEFT or self.points.LEFT,
        self.points.TOPRIGHT or self.points.BOTTOMRIGHT or self.points.RIGHT
    if left and right and left[1] == right[1] then return left[1]:GetWidth() + right[3] - left[3] end
    if self.kind == "FontString" and self.width == 0 then return self:GetStringWidth() end
    return self.width
end
function methods:GetHeight()
    if self.all then return self.all:GetHeight() end
    local top, bottom = self.points.TOPLEFT or self.points.TOPRIGHT or self.points.TOP,
        self.points.BOTTOMLEFT or self.points.BOTTOMRIGHT or self.points.BOTTOM
    if top and bottom and top[1] == bottom[1] then return top[1]:GetHeight() + top[4] - bottom[4] end
    if self.kind == "FontString" and self.height == 0 then return self:GetStringHeight() end
    return self.height
end
function methods:SetScript(k, v) self.scripts[k] = v end
function methods:GetScript(k) return self.scripts[k] end
function methods:HookScript(k, v)
    local prior = self.scripts[k]
    self.scripts[k] = function(...) if prior then prior(...) end; v(...) end
end
function methods:Show()
    local was = self.visible; self.visible = true
    if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
    local was = self.visible; self.visible = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetShown(on) if on then self:Show() else self:Hide() end end
function methods:IsShown() return self.visible and (not self.parent or self.parent:IsShown()) end
function methods:SetParent(p) self.parent = p end
function methods:GetParent() return self.parent end
function methods:GetChildren() return unpack(self.children) end
function methods:CreateTexture() return New("Texture", nil, self) end
function methods:GetObjectType() return self.kind end
-- One unit is one screen pixel here, so ns.Hairline and ns.PixelInset keep the layout's numbers.
function methods:GetEffectiveScale() return 1 end
env.PixelUtil = { GetPixelToUIUnitFactor = function() return 1 end,
    GetNearestPixelSize = function(v) return math.floor(v + 0.5) end }
function methods:IsVisible() return self:IsShown() end
function methods:IsMouseOver() return false end
function methods:CreateFontString() return New("FontString", nil, self) end
function methods:SetFont(path, size, flags) self.font, self.size, self.flags = path, size, flags end
function methods:SetText(t)
    self.text = tostring(t or "")
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:GetText() return self.text or "" end
function methods:GetStringWidth() return #(self.text or "") * (self.size or 12) * 0.52 end
function methods:GetStringHeight() return self.size or 12 end
function methods:SetTextColor(r, g, b, a) self.color = { r, g, b, a or 1 } end
methods.SetColorTexture = methods.SetTextColor
methods.SetVertexColor = methods.SetTextColor
function methods:SetTexture(path) self.texture = path end
function methods:SetAlpha(a) self.alpha = a end
function methods:SetBlendMode(mode) self.blend = mode end
function methods:SetRotation(r) self.rotation = r end
function methods:SetJustifyH(j) self.justify = j end
function methods:SetFrameLevel(v) self.level = v end
function methods:GetFrameLevel() return self.level end
function methods:SetScrollChild(f) self.child = f; f:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0) end
function methods:SetVerticalScroll(v)
    self.scroll = v
    if self.scripts.OnVerticalScroll then self.scripts.OnVerticalScroll(self, v) end
end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:GetVerticalScrollRange() return math.max(0, (self.child and self.child:GetHeight() or 0) - self:GetHeight()) end
function methods:GetPoint()
    local p, v = next(self.points)
    if p then return p, unpack(v) end
end
function methods:SetValue(v) self.value = v end
function methods:GetValue() return self.value or 0 end
function methods:SetMinMaxValues(a, b) self.min, self.max = a, b end
function methods:GetMinMaxValues() return self.min, self.max end
function methods:GetScale() return 1 end
function methods:EnableMouse(v) self.mouse = v end
function methods:ClearFocus() self.focus = false end
function methods:SetFocus() self.focus = true end
function methods:HasFocus() return self.focus == true end
for _, name in ipairs({ "RegisterEvent", "RegisterUnitEvent", "UnregisterEvent", "UnregisterAllEvents",
    "SetCursorPosition", "SetFontObject", "SetAutoFocus", "SetMultiLine", "SetMaxLetters", "SetNumeric", "SetTextInsets", "SetWordWrap", "SetSpacing",
    "SetFrameStrata", "SetScale", "SetMovable", "SetClampedToScreen", "EnableKeyboard", "SetPropagateKeyboardInput",
    "RegisterForDrag", "RegisterForClicks", "SetResizable", "SetResizeBounds", "SetNormalTexture", "SetHighlightTexture",
    "SetPushedTexture", "SetTexCoord", "SetTexelSnappingBias", "SetSnapToPixelGrid", "SetOrientation", "SetValueStep",
    "SetObeyStepOnDrag", "EnableMouseWheel", "UpdateScrollChildRect", "SetToplevel",
    "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetHitRectInsets", "HighlightText",
    "StartMoving", "StopMovingOrSizing", "StartSizing" }) do methods[name] = function() end end
function methods:SetThumbTexture(t) self.thumbTexture = t end
env.CreateFrame = New
local VERBS = { "^Set", "^Get", "^Register", "^Unregister", "^Enable", "^Disable", "^Clear", "^Update",
    "^Start", "^Stop", "^Add", "^Remove", "^Play", "^Lock", "^Unlock" }
setmetatable(methods, { __index = function(_, k)
    if type(k) ~= "string" then return nil end
    for _, verb in ipairs(VERBS) do
        if k:find(verb) then return function() end end
    end
end })
env.UIParent = New("Frame"); env.UIParent:SetSize(1920, 1080)
env.C_Timer = { After = function(_, f) timers[#timers + 1] = f end,
    NewTicker = function() return { Cancel = function() end } end }
-- missingAddOns: not loaded this session. disabled: switched off for the next reload.
local missingAddOns, disabled = {}, {}
env.C_AddOns = { GetAddOnMetadata = function() return "test" end,
    IsAddOnLoaded = function(name) return not missingAddOns[name] end,
    GetAddOnEnableState = function(name) return (missingAddOns[name] or disabled[name]) and 0 or 2 end,
    DisableAddOn = function(name) disabled[name] = true end,
    EnableAddOn = function(name) disabled[name] = nil end }
env.SlashCmdList = {}
env.InCombatLockdown = function() return false end
env.LibStub = function() return nil end
env.strtrim = function(s) return s:match("^%s*(.-)%s*$") end
env.UnitName = function() return "Preview" end
env.UnitClass = function() return "Warrior", "WARRIOR", 1 end
env.GetRealmName = function() return "Preview" end
env.GetTime = function() return 0 end
env.UNKNOWNOBJECT = "Unknown"
env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local function Load(path)
    local f = assert(loadfile(path)); setfenv(f, env); f("NaowhForever")
end
Load("Core/Core.lua")
Load("Core/Features.lua")
local ns = env.NaowhForever
local account, settings = {}, {}
ns.AccountSettings = function() return account end
ns.SettingsRoot = function() return settings end
ns.RegisterReapply = function() end
ns.QueueReapply = function() end
Load("Core/Options/Widgets.lua")
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^Core/Unlock/.-%.lua$")) do Load(path) end
-- The options window is several files now: its modules, the window, its Settings page, commands and launchers.
local function LoadWindow()
    for _, name in ipairs({ "Options/Modules", "Options/Window", "Options/SettingsPage", "Commands", "Options/Launchers" }) do
        Load("Core/" .. name .. ".lua")
    end
end
LoadWindow()
Load("Core/Options/Search.lua")
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^Shared/.*%.lua$")) do Load(path) end
Load("Core/Settings.lua")
Load("NaowhForever_QoL/Constants.lua")
env.GameTooltip = New("Frame")
env.GameTooltip.GetOwner = function() return nil end
for _, name in ipairs({ "UnitGroupRolesAssigned", "GetShapeshiftFormID", "GetShapeshiftForm", "IsInGroup",
    "IsInRaid", "IsInInstance", "UnitExists", "UnitAffectingCombat", "IsStealthed", "IsResting", "IsMounted",
    "UnitOnTaxi", "UnitIsDeadOrGhost", "GetPartyAssignment", "GetPlayerAuraBySpellID", "UnitIsUnit" }) do
    env[name] = function() return nil end
end
env.GetNumGroupMembers = function() return 0 end
env.GetNumSubgroupMembers = function() return 0 end
env.GetNumShapeshiftForms = function() return 0 end
env.UnitHealth = function() return 1 end
env.UnitHealthMax = function() return 1 end
env.RegisterUnitWatch = function() end
env.RegisterStateDriver = function() end
env.UnregisterStateDriver = function() end
env.GetFramerate = function() return 60 end
env.GetNetStats = function() return 0, 0, 30, 30 end
env.IsInGuild = function() return false end
env.BNGetNumFriends = function() return 0, 0 end
env.date = os.date
env.UnregisterUnitWatch = function() end
env.Mixin = function(object, ...)
    for i = 1, select("#", ...) do
        for k, v in pairs((select(i, ...))) do object[k] = v end
    end
    return object
end
env.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, SetRGBA = function() end } end
env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
env.hooksecurefunc = function(target, key, fn)
    if type(target) == "table" then
        local prior = target[key]
        target[key] = function(...) if prior then prior(...) end; fn(...) end
    end
end
for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^NaowhForever_TopBar/.*%.lua$")) do Load(path) end
for _, path in ipairs({ "NaowhForever_QoL/Combat/StealthReminder.lua", "NaowhForever_QoL/Combat/CoTank.lua" }) do Load(path) end
local UI = ns.UI
ns.BuildQoLInterfacePage = function(parent, y) return y end
for _, name in ipairs({ "JournalSettings", "DiscoverySettings", "ProfessionSettings", "MacroSettings", "AuraBuffSettings",
    "ThreatMeterSettings", "SwingTimerSettings", "TopBarSettings", "ActionBarSettings", "TrainingSettings",
    "InstanceTrackerSettings", "CompletoSettings", "PvPSettings" }) do
    ns[name] = UI.ModuleSettings(name, { enabled = false })
end
ns.DB = function() return settings end
ns.SetEnabled = function(v) settings.enabled = v end
local function Flush()
    while #timers > 0 do local q = timers; timers = {}; for _, fn in ipairs(q) do fn() end end
end
local function Text(text)
    for _, f in ipairs(frames) do if f.text == text and f:IsShown() then return f end end
end
local function Button(text)
    local label = assert(Text(text), "missing visible label: " .. text)
    local f = label.parent
    while f and not f.scripts.OnClick do f = f.parent end
    return assert(f, "missing button: " .. text)
end
local cases = 0
local function Check(ok, why) assert(ok, why); cases = cases + 1 end
local function Click(button) button.scripts.OnClick(button) end
ns.OpenOptionsWindow()
local function Head(name)
    for _, f in ipairs(frames) do
        local head = f.text == name and f:IsShown() and f.parent
        if head and head.card then return head end
    end
end
Check(Text("Quality of Life / Interface") ~= nil and Head("Top Bar") ~= nil, "opens to QoL Interface, the Top Bar's card first")
Check(Text("ADVENTURE") and Text("COMBAT") and Text("UTILITIES"), "grouped navigation")
Check(not Text("Close") and Button("Reload UI") ~= nil, "no footer: Reload UI sits in the header, closing is the X")
Check(not Text("Custom Reminders"), "unfinished module is absent from navigation")
Check(Button("Quality of Life").switch == nil, "navigation does not toggle modules")
for _, name in ipairs({ "Quality of Life", "Dungeon Journal", "Instance Tracker", "Discovery", "BiS List", "Professions",
    "Gear & Trinkets", "Blessings", "AuraBuffs", "Threat Meter", "Swing Timer",
    "Macros", "Action Bars" }) do
    Check(Button(name).icon ~= nil, name .. " is listed with its glyph")
end
Check(Head("Top Bar").card.uid == "QoL/Interface:topBar", "the Top Bar's own addon puts its card on QoL Interface")
local moduleList = Button("Action Bars").parent
local navTopBar = false
for _, f in ipairs(frames) do
    if f.text == "Top Bar" and f.parent and f.parent.parent == moduleList then navTopBar = true end
end
Check(not navTopBar, "the Top Bar has no sidebar entry: it is switched in Settings and set on QoL Interface")
local moduleScroll = moduleList.parent
local mainWindow = moduleScroll.parent.parent
local originalHeight = mainWindow:GetHeight()
-- Tall enough for every entry, to see the scrollbar go again.
local TALL_WINDOW = 1000
mainWindow:SetHeight(822)
moduleScroll.scripts.OnSizeChanged(moduleScroll)
local lastModule
for _, f in ipairs(frames) do
    if f.parent == moduleList and f.points and f.points.TOPLEFT and f:IsShown()
        and (not lastModule or f.points.TOPLEFT[4] < lastModule.points.TOPLEFT[4]) then
        lastModule = f
    end
end
moduleScroll:SetVerticalScroll(moduleScroll:GetVerticalScrollRange())
Check(-lastModule.points.TOPLEFT[4] + lastModule:GetHeight()
    <= moduleScroll:GetVerticalScroll() + moduleScroll:GetHeight(),
    "scrolled to the end, the last entry is fully in view above the fixed footer")
moduleScroll:SetVerticalScroll(0)
mainWindow:SetHeight(620)
moduleScroll.scripts.OnSizeChanged(moduleScroll)
Check(moduleScroll.bar:IsShown(), "short windows display a navigation scrollbar")
moduleScroll.scripts.OnMouseWheel(moduleScroll, -100)
Check(moduleScroll:GetVerticalScroll() == 0 and moduleScroll.scripts.OnUpdate, "the wheel glides instead of jumping")
for _ = 1, 100 do
    if not moduleScroll.scripts.OnUpdate then break end
    moduleScroll.scripts.OnUpdate(moduleScroll, 0.016)
end
Check(not moduleScroll.scripts.OnUpdate, "the glide stops once it lands")
Check(moduleScroll:GetVerticalScroll() == moduleScroll:GetVerticalScrollRange(), "wheel reaches the last module")
Check(moduleScroll.bar:GetValue() == moduleScroll:GetVerticalScroll(), "scrollbar follows wheel scrolling")
moduleScroll.bar.scripts.OnValueChanged(moduleScroll.bar, 20)
Check(moduleScroll:GetVerticalScroll() == 20, "dragging the scrollbar moves navigation")
mainWindow:SetHeight(TALL_WINDOW)
moduleScroll.scripts.OnSizeChanged(moduleScroll)
Check(moduleScroll:GetVerticalScroll() == 0 and not moduleScroll.bar:IsShown(),
    "growing the window clears the scroll offset and hides the scrollbar")
mainWindow:SetHeight(originalHeight)
moduleScroll.scripts.OnSizeChanged(moduleScroll)

-- The page scrollbar drags itself: the thumb follows the cursor from where it was grabbed.
local pageScroll
for _, f in ipairs(frames) do if f.bar and f.parent == mainWindow then pageScroll = f end end
local pageBar = pageScroll.bar
local pageThumb = pageBar.thumbTexture
local grip
for _, f in ipairs(pageBar.children) do if f.scripts.OnMouseDown then grip = f end end
Check(pageBar.mouse == false and grip.mouse, "the page scrollbar's own Slider drag is off, its grip takes the mouse")
local cursorY, buttonDown = 0, true
env.GetCursorPosition = function() return 0, cursorY end
env.IsMouseButtonDown = function() return buttonDown end
local BAR_TOP, THUMB_H, RANGE = 1000, 100, 1000
local travel = pageBar:GetHeight() - THUMB_H
pageThumb:SetHeight(THUMB_H)
pageBar:SetMinMaxValues(0, RANGE)
pageBar:SetValue(0)
pageThumb.GetCenter = function() return 0, BAR_TOP - THUMB_H / 2 - pageBar:GetValue() / RANGE * travel end
pageScroll.child:SetHeight(pageScroll:GetHeight() + RANGE)
pageScroll.scripts.OnMouseWheel(pageScroll, -1)
Check(pageScroll.scripts.OnUpdate ~= nil, "the page wheel glides")
cursorY = BAR_TOP - THUMB_H / 2 + 10
grip.scripts.OnMouseDown(grip, "LeftButton")
Check(pageScroll.scripts.OnUpdate == nil, "grabbing the scrollbar stops a wheel glide")
Check(pageBar:GetValue() == 0, "grabbing the thumb does not move it")
cursorY = cursorY - travel / 2
grip.scripts.OnUpdate(grip)
Check(pageBar:GetValue() == RANGE / 2, "dragging down scrolls down, in step with the cursor")
cursorY = cursorY + travel / 4
grip.scripts.OnUpdate(grip)
Check(pageBar:GetValue() == RANGE / 4, "dragging up scrolls back up")
buttonDown = false
grip.scripts.OnUpdate(grip)
Check(grip.scripts.OnUpdate == nil, "letting go ends the drag")
buttonDown = true
cursorY = BAR_TOP - pageBar:GetHeight()
grip.scripts.OnMouseDown(grip, "LeftButton")
Check(pageBar:GetValue() == RANGE, "a press on the track brings the thumb to the cursor")
grip.scripts.OnMouseUp(grip, "LeftButton")
pageBar:SetValue(0)
pageScroll:SetVerticalScroll(0)

ns.OpenOptionsWindow("QoL/Combat"); Flush()
local S = ns.QoLSettings
Check(Head("Stealth Reminder") and Head("Co-Tank Frame"),
    "each feature on the page is a card")
Check(not Text("Out of Stealth Color") and not Text("Max Icons"), "cards start closed: their settings do not show")
local function Setting(label)
    local text = Text(label)
    return text and text.parent.setting and text.parent or nil
end
-- Walked through from Co-Tank off with its debuffs on, the original defaults.
S.Set("coTank", false); S.Set("coTankDebuffs", true); Flush()
local coTank = Head("Co-Tank Frame")
coTank.switch.scripts.OnClick(coTank.switch); Flush()
Check(S.Get("coTank") and Setting("Max Icons") ~= nil, "turning a card on opens it")
Check(Setting("Max Icons").label.alpha == 1, "its settings are on while it is on")
local debuffs = Setting("Co-Tank Debuffs")
debuffs.controls.toggle.scripts.OnClick(debuffs.controls.toggle); Flush()
Check(not S.Get("coTankDebuffs") and Setting("Max Icons").label.alpha < 1, "a setting is dimmed while what it needs is off")
Check(Setting("Max Icons").why.text == "Needs Co-Tank Debuffs", "and says what it needs")
Setting("Co-Tank Debuffs").controls.toggle.scripts.OnClick(Setting("Co-Tank Debuffs").controls.toggle); Flush()
Check(S.Get("coTankDebuffs") and Setting("Max Icons").label.alpha == 1, "on again, it is back")
S.Set("coTankWidth", 222); Flush()
Check(Setting("Width").dot.visible and Text("Reset Co-Tank Frame") ~= nil, "a changed setting has its dot, and its card a reset")
local reset = Text("Reset Co-Tank Frame").parent
local changedNote = reset.parent.text
Check(changedNote and changedNote.points.RIGHT and changedNote.points.RIGHT[1] == reset,
    "the changed note stops short of the reset link, so a narrow card does not overlap them")
reset.scripts.OnClick(reset); Flush()
Check(S.Get("coTankWidth") == S.Default("coTankWidth") and not Text("Reset Co-Tank Frame"),
    "the reset puts the card's settings back")
coTank = Head("Co-Tank Frame")
coTank.switch.scripts.OnClick(coTank.switch); Flush()
Check(not S.Get("coTank") and Setting("Width").label.alpha < 1, "turned off, the card stays open with its settings dimmed")
coTank = Head("Co-Tank Frame")
coTank.scripts.OnClick(coTank); Flush()
Check(not Text("Max Icons"), "a click on its head closes it")
Check(not S.Get("coTank"), "closing it keeps its settings")
UI.GoToSetting("QoL/Combat", "Out of Stealth Color", "QoL/Combat:stealthReminder"); Flush()
Check(Setting("Out of Stealth Color") ~= nil, "a jump to a setting opens its card and shows the setting")
ns.OpenOptionsWindow("QoL/Interface"); Flush()
local topBar = Head("Top Bar")
if not Text("24-Hour Clock") then Click(topBar); Flush() end
Check(not Text("Normal") and not Text("Faded") and not Text("In Combat"), "with nothing to compare, the studio shows no moments")
local barStore = topBar.card.store
barStore.Set("mouseover", true); barStore.Set("hideInCombat", true); Flush()
Check(Text("Normal") and Text("Faded") and Text("In Combat"), "an open card with a studio shows its moments")
Click(Button("Faded")); Flush()
-- A slider being dragged holds the page's redraw (it would hide the slider and end the drag),
-- and the page catches up once it is let go.
UI.sliderDrag = {}
barStore.Set("mouseoverAlpha", 30)
local held = timers; timers = {}
for _, fn in ipairs(held) do fn() end
Check(#timers > 0, "a slider being dragged holds the settings page's redraw")
UI.sliderDrag = nil
Flush()
Check(#timers == 0, "and the page draws again once it is let go")
barStore.Set("mouseoverAlpha", 40); Flush()
local studio
for _, f in ipairs(frames) do if f.previews and f:IsShown() then studio = f end end
local preview = studio and studio.previews[topBar.card]
Check(preview and preview.alpha == 0.4, "faded, the preview is at Faded Opacity, drawn again as the setting changes")
Check(Text("Drag to move, x to remove, + to add.") ~= nil, "the preview says how to edit the bar")
barStore.Set("hideInCombat", true)
Click(Button("In Combat")); Flush()
Check(preview.alpha == 0 and preview.sys.alpha == 1, "in combat it hides with Hide In Combat, its FPS / MS up")
barStore.Set("hideInCombat", false); barStore.Set("mouseover", false); Flush()
Click(Head("Top Bar")); Flush()
local found = 0
for _, target in ipairs(UI.Search.Collect()) do
    if target.page == "QoL/Interface" and target.label == "Faded Opacity" and target.card == "QoL/Interface:topBar" then
        found = found + 1
    end
end
Check(found == 1, "the search lists the declared settings, each once")
local strip = Button("Interface").parent
local tabs = 0
for _, child in ipairs(strip.children) do
    if child.scripts.OnClick then
        tabs = tabs + 1
        Check(child.points.LEFT and child.points.LEFT[4] == 0, "QoL categories share one row")
    end
end
Check(tabs == 9, "every QoL category has a tab")
Check(strip.buttons and strip:GetWidth() <= 1440 - 240 - 56, "the tabs are the boxed switch, inside the content width")
Click(Button("Combat")); Flush()
Check(Text("Quality of Life / Combat") ~= nil, "category navigation works")
Click(Button("Swing Timer")); Flush()
Check(Text("Swing Timer / Settings") and not Text("Interface"), "each module shows only its own page")
Click(Button("Threat Meter")); Flush()
Check(Text("Threat Meter / Settings") and not Text("Interface") and not Text("Cursor"),
    "single-page module shows no tab row")
Click(Button("Quality of Life")); Flush()
Check(Text("Quality of Life / Combat") ~= nil, "returning to a module remembers its page")
local count = #frames
for _ = 1, 8 do UI:RefreshPage(true); Flush() end
Check(#frames == count, "refreshes reuse controls without accumulating frames")
local root = env.NaowhForeverOptions
root:Hide(); UI:RefreshPage(true)
local hiddenCount = #frames
Check(#frames == hiddenCount, "hidden refresh does not build controls")
ns.OpenOptionsWindow("QoL/Combat"); Flush()
Check(Text("Co-Tank Frame") ~= nil, "reopening rebuilds the visible page")
local header = Text("Enable QoL").parent
local switch
for _, child in ipairs(header.children) do if child._get then switch = child end end
Check(switch and switch._get() == true, "header switch reads the current module")
ns.QoLSettings.Set("coTankWidth", 222)
switch.scripts.OnClick(); Flush()
Check(Text("Disable Quality of Life? Top Bar needs it, so both will be disabled.") ~= nil
    and ns.QoLSettings.Get("enabled") == true and ns.QoLSettings.Get("coTankWidth") == 222,
    "switching QoL off asks to turn its addon off, with the Top Bar, and its settings are kept")
Click(Button("Cancel")); Flush()
Check(not disabled.NaowhForever_QoL and switch._get() == true, "Cancel keeps QoL on")
Click(Button("Threat Meter")); Flush()
Check(switch._get() == false, "same switch rebinds to the newly selected module")
switch.scripts.OnClick(); Flush()
Check(ns.ThreatMeterSettings.Get("enabled") == true and ns.QoLSettings.Get("enabled") == true,
    "switch changes only the selected module")
Click(Button("Quality of Life")); Flush()
settings = { qol = { enabled = true, coTankWidth = 233 } }
UI:RefreshPage(true); Flush()
Check(switch._get() == true and ns.QoLSettings.Get("coTankWidth") == 233,
    "profile replacement refreshes controls against the new settings")
local beforeWidth = Head("Stealth Reminder"):GetWidth()
root:SetWidth(1640); UI:RefreshPage(true); Flush()
Check(Head("Stealth Reminder"):GetWidth() > beforeWidth, "cards grow with the window")
root:SetWidth(1440); UI:RefreshPage(true); Flush()
Check(Head("Stealth Reminder"):GetWidth() == beforeWidth, "and shrink with it")
local pages = UI.SearchPages
UI.SearchPages = function()
    for _, page in ipairs(pages()) do if page.key == "QoL/Combat" then return { page } end end
end
local hit = UI.Search.Find(UI.Search.Collect(), "Out of Stealth Color")[1]
Check(hit and hit.card == "QoL/Combat:stealthReminder" and hit.trail:find("Stealth Reminder", 1, true),
    "a setting is found in its card, the card named in its trail")
local debuffHit = UI.Search.Find(UI.Search.Collect(), "Co-Tank Debuffs")[1]
Check(debuffHit and debuffHit.card == "QoL/Combat:coTank", "a setting's card is the one it opens")
local iconHit = UI.Search.Find(UI.Search.Collect(), "Max Icons")[1]
UI.GoToSetting("QoL/Combat", "Max Icons", iconHit.card); Flush()
Check(Text("Co-Tank Debuffs") and Text("Max Icons"), "the jump opens its card")
UI.SearchPages = pages
for _, page in ipairs(UI.SearchPages()) do Check(not page.soon, "unfinished pages are not search results") end

-- The sidebar's search: Ctrl+F goes to its box, and typing trims the window to what matches.
-- Modules and tabs without a match dim, the rest count their matches, and the page keeps only
-- its matching cards and settings, the typed words lit. Escape brings it all back.
do
    local ctrl = false
    env.IsControlKeyDown = function() return ctrl end
    local function Plain(text)
        return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
    -- A visible string that reads label once its colour codes are gone.
    local function Shown(label)
        for _, f in ipairs(frames) do
            if f:IsShown() and type(f.text) == "string" and Plain(f.text) == label then return f end
        end
    end
    local function Alpha(button) return button.label.color[4] end
    local note = "Nothing on this page matches the search."
    ns.OpenOptionsWindow("QoL/Interface"); Flush()
    local threatAlpha = Alpha(Button("Threat Meter"))
    Check(not Text("Search  " .. ns.Color("muted", "Ctrl+F")), "the header has no Search button")
    local input = Text("Search settings").parent
    local sidebar = moduleScroll.parent
    Check(input.parent == sidebar, "the search box sits in the sidebar")
    Check(input.points.TOPLEFT[4] > moduleScroll.points.TOPLEFT[4], "above the module list")
    local row = Button("Quality of Life")
    Check(input.points.TOPLEFT[3] == row.points.TOPLEFT[3]
        and input.points.TOPRIGHT[3] == moduleScroll.points.BOTTOMRIGHT[3] + row.points.TOPRIGHT[3],
        "edge to edge with the module rows under it")
    local glass
    for _, f in ipairs(input.children) do if f.texture and f.points.LEFT then glass = f end end
    Check(glass and math.abs(glass.points.LEFT[3] + glass:GetWidth() / 2 - (row.icon.points.LEFT[3] + row.icon:GetWidth() / 2)) <= 0.5
        and Text("Search settings").points.LEFT[3] == row.label.points.LEFT[3],
        "its magnifier and text on the rows' glyph and label columns")
    ctrl = true
    root.scripts.OnKeyDown(root, "F"); Flush()
    ctrl = false
    Check(input:HasFocus() and root:IsShown(), "Ctrl+F puts the cursor in it")

    input:SetText("max icons"); Flush()
    Check(Text("Quality of Life / Combat") ~= nil, "the page moves to the first one with a match")
    local icons = Shown("Max Icons")
    Check(icons and icons.parent.setting and Shown("Co-Tank Frame"), "the matching setting shows, its card open")
    Check(icons.text:find(ns.Color("accent", "Max"), 1, true) and icons.text:find(ns.Color("accent", "Icons"), 1, true),
        "the typed words are lit in its name")
    Check(not Shown("Width") and not Shown("Stealth Reminder"),
        "the rest of the page is left out")
    Check(Button("Quality of Life").count.text == "1" and Alpha(Button("Quality of Life")) == 1,
        "the module with the match counts it")
    Check(Alpha(Button("Threat Meter")) < threatAlpha and Button("Threat Meter").count.text == "",
        "a module without a match dims")
    Check(Button("Interface").text.alpha < 1 and Button("Combat").text.alpha == 1, "and so does a tab")

    S.Set("coTankWidth", 222); Flush()
    Check(not Text("Reset Co-Tank Frame") and not Shown("1 setting changed from its default"),
        "part of a card shows no reset, which would reset what is left out")
    local heldHead = Head("Co-Tank Frame") or Shown("Co-Tank Frame").parent
    Check(heldHead.held and not heldHead.chevron:IsShown(), "a card the search holds open has no chevron")
    heldHead.scripts.OnClick(heldHead); Flush()
    Check(Shown("Max Icons") ~= nil, "and a click on its head does not fold it")
    S.Set("coTankWidth", S.Default("coTankWidth")); Flush()

    input:SetText("co-tank"); Flush()
    Check(Shown("Co-Tank Frame") and Shown("Width") and Shown("Max Icons"),
        "a card's name keeps all of the card")

    input:SetText("zzzz"); Flush()
    Check(Text(note) ~= nil and not Shown("Co-Tank Frame"), "nothing found, the page says so")
    Check(Alpha(Button("Threat Meter")) < threatAlpha and Button("Quality of Life").count.text == "",
        "and every module but the open one dims, none with a count")

    input:SetText("max icons"); Flush()
    root.scripts.OnKeyDown(root, "ESCAPE"); Flush()
    Check(root:IsShown() and input:GetText() == "" and UI.filter == nil, "Escape clears the search, not the window")
    Check(Head("Stealth Reminder") and not Text(note), "the whole page is back")
    Check(Setting("Max Icons") ~= nil, "the card the search found stays open")
    Check(Button("Quality of Life").count.text == "" and Alpha(Button("Threat Meter")) == threatAlpha
        and Button("Interface").text.alpha == 1, "the counts go and nothing is dimmed")

    input:SetText("-"); Flush()
    root.scripts.OnKeyDown(root, "ESCAPE"); Flush()
    Check(root:IsShown() and input:GetText() == "", "Escape clears text with no words in it before closing")

    input:SetText("max icons"); Flush()
    input.scripts.OnEscapePressed(input); Flush()
    Check(input:GetText() == "" and UI.filter == nil and root:IsShown(), "Escape in the box clears it too")
    root.scripts.OnKeyDown(root, "ESCAPE"); Flush()
    Check(not root:IsShown(), "with no search, Escape closes the window")
    ns.OpenOptionsWindow("QoL/Combat"); Flush()
    input:SetText("max icons"); Flush()
    root:Hide(); Flush()
    Check(input:GetText() == "" and UI.filter == nil, "closing the window clears the search")
    ns.OpenOptionsWindow("QoL/Combat"); Flush()
    Check(Head("Stealth Reminder") ~= nil, "and it reopens on the whole page")
    input:SetText("max icons"); Flush()
    UI.GoToSetting("QoL/Combat", "Out of Stealth Color", "QoL/Combat:stealthReminder"); Flush()
    Check(UI.filter == nil and Setting("Out of Stealth Color") ~= nil, "a jump to a setting clears the search first")
    local Settings = ns.Shared.Settings
    Settings.SetOpen(Settings.CardOf("QoL/Combat:stealthReminder"), false)
    UI:RefreshPage(true); Flush()
    input:SetText("color"); Flush()
    UI.GoToSetting("QoL/Interface", nil, "QoL/Interface:topBar"); Flush()
    Click(Button("Combat")); Flush()
    Check(not Text("Out of Stealth Color"), "a jump away does not leave the search's cards open on the page it left")

    -- A page its own builder draws can carry a declared settings page, as Profiles carries the
    -- Setups card: typing what only that card has lands on the page, counts it there, and the
    -- page draws the card with the typed words lit; cleared, the page is whole again.
    input:SetText(""); Flush()
    Settings.Page("Profiles/Setups", S):Card({ id = "setups", name = "Setups", help = "Naowh's setups for you.",
        rows = { { label = "Onboarding", buttonText = "Start", button = function() end,
            help = "Walks you through a profile, a skin and your modules." } } })
    UI.SearchCarries("Profiles", "Profiles/Setups")
    local drawnWith = {}
    ns.BuildProfileSettings = function(parent, y)
        local filter = UI.Search.Narrowed("Profiles")
        drawnWith[#drawnWith + 1] = filter or false
        return y - Settings.Render(parent, "Profiles/Setups", function() end, filter)
    end
    ns.OpenOptionsWindow("QoL/Combat"); Flush()
    input:SetText("onboarding"); Flush()
    Check(Shown("Onboarding") and Shown("Setups") and not Shown("Stealth Reminder"),
        "a setting only the carried card has moves the window to the Profiles page, at that card")
    Check(Button("Profiles").count.text == "1" and Button("Quality of Life").count.text == "",
        "the Profiles page counts it")
    Check(Shown("Onboarding").text:find(ns.Color("accent", "Onboarding"), 1, true) and drawnWith[#drawnWith] ~= false,
        "drawn with the search, its words lit")
    input:SetText("skin"); Flush()
    Check(drawnWith[#drawnWith] == UI.filter, "the page draws again as the words change")
    root.scripts.OnKeyDown(root, "ESCAPE"); Flush()
    Check(UI.filter == nil and drawnWith[#drawnWith] == false and Shown("Onboarding") ~= nil,
        "cleared, the page is drawn whole again")

    -- A window card is found by its button and drawn on its page while the search holds it.
    Settings.Page("QoL/Combat", S):Window({ text = "Open Test Log", open = function() end, headline = "Test Log",
        detail = "Every test, logged." })
    input:SetText("test log"); Flush()
    Check(Text("Quality of Life / Combat") and Shown("Test Log") and not Shown("Stealth Reminder"),
        "a window card found shows on its page, the rest left out")

    -- The Settings page is drawn by its own builder and names what is on it.
    local function NavCount(name)
        for _, f in ipairs(frames) do
            if f.text == name and f:IsShown() and f.parent.count then return tonumber(f.parent.count.text) end
        end
    end
    for _, query in ipairs({ "minimap", "game menu", "window scale", "addon font", "skin", "theme", "modules" }) do
        input:SetText(query); Flush()
        Check(NavCount("Settings"), "'" .. query .. "' is counted on the Settings page")
    end

    -- A module that is off has no pages to search, so its name finds the Settings page, which says so.
    input:SetText(""); Flush()
    missingAddOns.NaowhForever_Training = true
    ns.OpenOptionsWindow("Settings"); Flush()
    input:SetText("training planner"); Flush()
    Check(Text("Training Planner is turned off, so its settings are hidden. Turn it on under Modules below.")
        and Text("MODULES") and NavCount("Settings") >= 1, "a module that is off is found on Settings, with how to turn it on")
    input:SetText(""); Flush()
    missingAddOns.NaowhForever_Training = nil
    input:SetText("training planner"); Flush()
    Check(not Text("Training Planner is turned off, so its settings are hidden. Turn it on under Modules below."),
        "on, it is not called off")

    -- A page its own builder draws says when nothing on it matches, as card pages do.
    input:SetText("zzzz"); Flush()
    Check(Text(note) and Text("MODULES"), "nothing found on the Settings page, it says so over the page")
    input:SetText(""); Flush()
    Check(not Text(note) and Text("MODULES"), "cleared, the note goes")

    -- A module's open-window icon always shows, dimmed until the mouse is on its row.
    local journal = Button("Dungeon Journal")
    Check(journal.open:IsShown() and journal.open.alpha < 1, "the open-window icon shows, dimmed")
    journal.open.scripts.OnEnter(journal.open)
    Check(journal.open.alpha == 1, "and lights up under the mouse")
    journal.open.scripts.OnLeave(journal.open)
    input:SetText("max icons"); Flush()
    Check(journal.open:IsShown() and journal.open.alpha < 1, "it stays while searching")
    input:SetText(""); Flush()
    ns.BuildProfileSettings = nil
end

-- A confirm: No, Escape and a newer confirm taking its place all count as no; Yes does not.
do
    local yes, no = 0, 0
    local function Ask() ns.Confirm("Sure?", function() yes = yes + 1 end, function() no = no + 1 end) end
    Ask(); Click(Button("Yes")); Flush()
    Check(yes == 1 and no == 0, "Yes confirms without counting as no")
    Ask(); Click(Button("No")); Flush()
    Check(yes == 1 and no == 1, "No cancels")
    Ask()
    local dimmer = Text("Sure?").parent.parent
    dimmer.scripts.OnKeyDown(dimmer, "ESCAPE"); Flush()
    Check(yes == 1 and no == 2 and not dimmer:IsShown(), "Escape cancels")
    Ask(); Ask()
    Check(no == 3, "a confirm taking another's place cancels that one")
    Click(Button("No")); Flush()
    Check(no == 4 and yes == 1, "and the new one still answers once")
end

-- A module shipped as its own addon: switching it off disables the addon, with every module
-- linked to it, once the player confirms.
local confirmText, confirmYes, reloadText
ns.Confirm = function(text, yes) confirmText, confirmYes = text, yes end
ns.ConfirmReload = function(text) reloadText = text end
Click(Button("Dungeon Journal")); Flush()
switch.scripts.OnClick(); Flush()
Check(ns.JournalSettings.Get("enabled") == true and confirmText == nil, "switching an addon module on needs no reload")
switch.scripts.OnClick(); Flush()
Check(confirmText and confirmText:find("Dungeon Journal", 1, true) and not confirmText:find("BiS List", 1, true),
    "switching the journal off asks for the journal alone: the BiS List works without it")
Check(next(disabled) == nil, "nothing is disabled before the player confirms")
confirmYes()
Check(disabled.NaowhForever_DungeonJournal and not disabled.NaowhForever_BiS, "confirming disables the journal alone")
Check(reloadText and reloadText:find("reload", 1, true), "then offers the reload")
Check(ns.JournalSettings.Get("enabled") == true, "the module's own switch is kept for when it comes back")
Check(switch._get() == false, "the switch reads off while the disable waits for its reload")
switch.scripts.OnClick(); Flush()
Check(not disabled.NaowhForever_DungeonJournal and switch._get() == true,
    "switching it back on before the reload cancels the disable")
confirmText = nil
Click(Button("Professions")); Flush()
switch.scripts.OnClick(); Flush()
switch.scripts.OnClick(); Flush()
Check(confirmText and confirmText:find("Training Planner", 1, true), "Professions takes Training Planner with it")
confirmYes()
Check(disabled.NaowhForever_Professions and disabled.NaowhForever_Training and not disabled.NaowhForever_BiS,
    "and only the modules that need it")
missingAddOns.NaowhForever_Professions = true
for _, page in ipairs(UI.SearchPages()) do
    Check(not (page.module and page.module.name == "Professions"), "a module addon that is not loaded is not searched")
end
ns.OpenOptionsWindow("Professions/Settings"); Flush()
Check(Text("MODULES") ~= nil, "a link to a module that is off lands on Settings, where it is turned back on")
missingAddOns.NaowhForever_Professions = nil

missingAddOns.NaowhForever_InstanceTracker = true
for _, page in ipairs(UI.SearchPages()) do
    Check(not (page.module and page.module.name == "Instance Tracker"),
        "Instance Tracker is not searched while its addon is not loaded")
end
missingAddOns.NaowhForever_InstanceTracker = nil

-- The core owns Unlock Mode.
ns.ShowUnlockMode(); Flush()
Check(Text("HUD Editor") and Text("Exit Config") and not Text("Snap Elements"), "the core opens the HUD Editor")
Click(Button("Exit Config")); Flush()
Check(not Text("Exit Config") and not ns.IsUnlockModeActive(), "and Exit Config closes it")

ns.OpenOptionsWindow("Settings"); Flush()
local groupInspectRows = 0
for _, f in ipairs(frames) do
    if f.text == "Group Inspect" and f:IsShown() and f.parent and f.parent:IsShown() then
        groupInspectRows = groupInspectRows + 1
    end
end
Check(groupInspectRows >= 3, "Group Inspect: in the sidebar, under Settings > Modules and in Minimap Icons")
ns.OpenOptionsWindow("Group Inspect/Settings"); Flush()
Check(Text("Group Inspect / Settings") ~= nil, "Group Inspect has a settings page of its own")
ns.OpenOptionsWindow("Blessings/Settings"); Flush()
Check(Text("Blessings / Settings") ~= nil, "existing module/tab deep links still work")
ns.OpenOptionsWindow("QoL/Combat"); Flush()
local Settings = ns.Shared.Settings
local function American(text) return not (text and text:find("Colour", 1, true)) end
for key, page in pairs(Settings.pages) do
    for _, card in ipairs(page.items) do
        if not card.window then
            local where = key .. " > " .. card.name
            Check(card.help and card.help ~= "", where .. " has its help")
            Check(American(card.name) and American(card.help), where .. " spells Color the house's way")
            if type(card.switch) == "string" then
                Check(card.store.Default(card.switch) ~= nil, where .. ": its switch has a default")
            end
            local labels = {}
            for _, row in ipairs(Settings.Rows(card)) do
                if row.kind ~= "group" then
                    local what = where .. " > " .. tostring(row.label)
                    Check(row.label and not labels[row.label], what .. " has a name of its own on the card")
                    labels[row.label] = true
                    Check(American(row.label) and American(row.help), what .. " spells Color the house's way")
                    if row.key and row.store == card.store then
                        Check(card.store.Default(row.key) ~= nil, what .. ": " .. row.key .. " has a default")
                    end
                    local needs = type(row.needs) == "string" and { row.needs } or type(row.needs) == "table" and row.needs or {}
                    for _, need in ipairs(needs) do
                        Check(row.store.Default(need) ~= nil, what .. " needs a real setting: " .. need)
                    end
                end
            end
        end
    end
end
-- With Gear & Trinkets and Blessings off, AuraBuffs is the first COMBAT module, listed after
-- Macros; the group still sits above UTILITIES.
missingAddOns.NaowhForever_GearSets, missingAddOns.NaowhForever_Blessings = true, true
missingAddOns.NaowhForever_InstanceTracker = true
local built = #frames
LoadWindow()
ns.OpenOptionsWindow(); Flush()
local headY, trackerNav = {}, false
for i = built + 1, #frames do
    local f = frames[i]
    if (f.text == "COMBAT" or f.text == "UTILITIES") and f.points.TOPLEFT then headY[f.text] = f.points.TOPLEFT[4] end
    if f.text == "Instance Tracker" and f:IsShown() then trackerNav = true end
end
Check(headY.COMBAT and headY.UTILITIES and headY.COMBAT > headY.UTILITIES, "COMBAT stays above UTILITIES with its first modules off")
Check(not trackerNav, "Instance Tracker is left out of the sidebar while its addon is not loaded")
missingAddOns.NaowhForever_GearSets, missingAddOns.NaowhForever_Blessings = nil, nil
missingAddOns.NaowhForever_InstanceTracker = nil

-- Quality of Life is its own addon. The Top Bar needs it (its card sits on QoL > Interface), so
-- switching QoL off takes the Top Bar with it; while QoL is not loaded, the sidebar drops it and
-- its pages land on Settings.
local qolMod
for _, mod in ipairs(ns.Options.MODULES) do
    if mod.addon == "NaowhForever_QoL" then qolMod = mod end
end
Check(qolMod and qolMod.name == "QoL", "Quality of Life is a module addon, NaowhForever_QoL")
local qolRow = false
for _, mod in ipairs(ns.ModuleAddons()) do
    if mod.addon == "NaowhForever_QoL" and mod.store == ns.QoLSettings and mod.key == "enabled" then qolRow = true end
end
Check(qolRow, "and has its own switch under Settings > Modules, on the core's QoL store")
Check(ns.LinkedAddons("NaowhForever_TopBar", true)[2] == "NaowhForever_QoL", "turning the Top Bar on brings QoL")
Check(ns.LinkedAddons("NaowhForever_QoL", false)[2] == "NaowhForever_TopBar", "turning QoL off takes the Top Bar")
confirmText, confirmYes = nil, nil
for addon in pairs(disabled) do disabled[addon] = nil end
ns.Options.SwitchModuleAddon(qolMod, false)
Check(confirmText and confirmText:find("Quality of Life", 1, true) and confirmText:find("Top Bar", 1, true),
    "switching Quality of Life off names the Top Bar in its confirm")
confirmYes()
Check(disabled.NaowhForever_QoL and disabled.NaowhForever_TopBar, "confirming disables QoL and the Top Bar together")
disabled.NaowhForever_QoL, disabled.NaowhForever_TopBar = nil, nil
missingAddOns.NaowhForever_QoL, missingAddOns.NaowhForever_TopBar = true, true
for _, page in ipairs(UI.SearchPages()) do
    Check(not (page.module and page.module.name == "QoL"), "Quality of Life off is not searched")
end
built = #frames
LoadWindow()
ns.OpenOptionsWindow(); Flush()
local qolShown = false
for i = built + 1, #frames do
    local f = frames[i]
    if f.text == "Quality of Life" and f:IsShown() and f.parent and f.parent.icon then qolShown = true end
end
Check(not qolShown, "with QoL not loaded, Quality of Life leaves the sidebar")
Check(Text("MODULES") ~= nil, "and the window opens on Settings instead of QoL > Interface")
missingAddOns.NaowhForever_QoL, missingAddOns.NaowhForever_TopBar = nil, nil

print(cases .. " navigation checks passed")
-- Available only to an offline renderer that loads this test environment.
local capture = rawget(_G, "NAVIGATION_CAPTURE")
if capture then capture(env, frames, ns, Flush) end

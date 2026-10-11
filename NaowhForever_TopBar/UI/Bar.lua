-- Bar.lua: the Top Bar on screen: [buttons] [clock] [buttons] and the FPS / MS readout under it, built on first use and kept current.
local ns = _G.NaowhForever
local UI = ns.UI

local TB = ns.TopBar
local S = TB.Settings
local C = TB.C
local St = TB.Style
local Info = TB.Info
local Look = TB.Look
local Tooltips = TB.Tooltips
local Buttons = TB.Buttons
local Widgets = TB.Widgets

local On = TB.On
local PERCENT, WHITE = C.PERCENT, St.WHITE
local CLOCK_START_SIZE, CLOCK_BTN_W = 20, 80
local REST_X, REST_Y, REST_MIN, REST_SCALE = 5, 2, 12, 0.55
local REST_FRAMES, REST_COLS, REST_V, REST_FRAME_TIME = 8, 16, 0.5, 0.25
local TEXT_GAMEPAD = ns.L("The calendar cannot be opened from the Top Bar with a gamepad.")
local SYS_DROP, SYS_H_PAD, SYS_MIN_W, SYS_TEXT_PAD = C.SYS_DROP, 3, 40, 10
local SYS_TIP_EVERY = 1
local TICK, BADGE_TICKS, ROSTER_EVERY = 1, 10, 15
local ROUND = C.ROUND
local HOME_LATENCY = 3
local COMBAT_DRIVER = "[combat] hide; show"

local BAR_EVENTS = { "PLAYER_UPDATE_RESTING", "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "GUILD_ROSTER_UPDATE" }

local buttons = Buttons.list
local bar, clockText, leftGroup, rightGroup, ticker, unlocked, fitPending
local lastRoster = 0
local tickCount = 0
local events = CreateFrame("Frame")
local pending = CreateFrame("Frame")

local function UpdateHover()
    local faded = S.Get("mouseover") and not unlocked and not (bar:IsMouseOver() or bar.sys:IsMouseOver())
    local alpha = faded and S.Get("mouseoverAlpha") / PERCENT or 1
    bar:SetAlpha(alpha)
    bar.sys:SetAlpha(alpha)
end

local function PaintClock()
    local text = Look.ClockText()
    if text == clockText.last then return false end
    clockText.last = text
    clockText:SetText(text)
    return true
end

local function FitWidth()
    if InCombatLockdown() then fitPending = true; return end
    fitPending = false
    Look.Fit(bar, leftGroup, rightGroup, clockText, bar.nLeft, bar.nRight)
end

local function UpdateSystem()
    local sys = bar.sys
    if not (On() and S.Get("showSystem")) then
        sys:Hide()
        sys.fps = nil
        return
    end
    local fps, ms = math.floor(GetFramerate() + ROUND), math.floor(select(HOME_LATENCY, GetNetStats()))
    if fps ~= sys.fps or ms ~= sys.ms then
        sys.fps, sys.ms = fps, ms
        Look.SystemText(sys.text, fps, ms)
        sys:SetWidth(math.max(SYS_MIN_W, sys.text:GetStringWidth() + SYS_TEXT_PAD))
    end
    sys:Show()
end

local function UpdateResting()
    if bar then bar.rest:SetShown(S.Get("showClock") and IsResting()) end
end

local function AnchorSystem()
    bar.sys:ClearAllPoints()
    if bar:IsShown() then
        bar.sys:SetPoint("TOP", bar, "BOTTOM", 0, -SYS_DROP)
    else
        bar.sys:SetPoint("CENTER", bar, "CENTER")
    end
end

local function PlaceWidgets()
    Widgets.Place(bar)
end

local function UpdateBadges()
    if not bar then return end
    Buttons.SetBadge(buttons.friends, Info.FriendsOnline())
    Buttons.SetBadge(buttons.guild, Info.GuildOnline())
    if TB.Layout.InLayoutOf(TB.Layout.Saved(), "guild") and IsInGuild() and not InCombatLockdown()
        and GetTime() - lastRoster >= ROSTER_EVERY then
        lastRoster = GetTime()
        C_GuildInfo.GuildRoster()
    end
end

local function ClockEnter(self)
    UpdateHover()
    clockText:SetTextColor(Look.Accent())
    Tooltips.Clock(self)
end

local function ClockLeave()
    clockText:SetTextColor(Look.Tone("fg", WHITE))
    GameTooltip:Hide()
    UpdateHover()
end

local function ClockClick()
    if ns.GamepadOwnsPanels() then
        ns.Print(TEXT_GAMEPAD)
    elseif ToggleCalendar then
        ToggleCalendar()
    end
end

local function RestFrame(icon, n)
    icon:SetTexCoord((n - 1) / REST_COLS, n / REST_COLS, 0, REST_V)
end

local function RestFlip(self, elapsed)
    self.frameT = self.frameT + elapsed
    if self.frameT < REST_FRAME_TIME then return end
    self.frameT = self.frameT - REST_FRAME_TIME
    self.frameN = self.frameN % REST_FRAMES + 1
    RestFrame(self.icon, self.frameN)
end

local function RestShown(self)
    self.frameT, self.frameN = 0, 1
    self:SetScript("OnUpdate", RestFlip)
end

local function RestHidden(self)
    self:SetScript("OnUpdate", nil)
end

local function SystemTick(self, elapsed)
    self.tipTime = self.tipTime + elapsed
    if self.tipTime < SYS_TIP_EVERY then return end
    self.tipTime = 0
    Tooltips.System(self)
end

local function SystemEnter(self)
    UpdateHover()
    if not S.Get("systemTooltip") then return end
    Tooltips.System(self)
    self.tipTime = 0
    self:SetScript("OnUpdate", SystemTick)
end

local function SystemLeave(self)
    self:SetScript("OnUpdate", nil)
    GameTooltip:Hide()
    UpdateHover()
end

local function SystemClick(self)
    if IsShiftKeyDown() then collectgarbage("collect") end
    Tooltips.Rescan()
    if S.Get("systemTooltip") then Tooltips.System(self) end
end

local function SavePosition(pos)
    S.Set("pos", pos)
end

local function BuildClock()
    clockText = bar:CreateFontString(nil, "OVERLAY")
    clockText:SetPoint("CENTER")
    clockText:SetFont(ns.UIFontPath(), CLOCK_START_SIZE, "")
    local clockBtn = CreateFrame("Button", nil, bar)
    clockBtn:SetPoint("CENTER", clockText, "CENTER")
    clockBtn:SetScript("OnEnter", ClockEnter)
    clockBtn:SetScript("OnLeave", ClockLeave)
    clockBtn:SetScript("OnClick", ClockClick)
    bar.clockBtn = clockBtn
end

local function BuildRest()
    local rest = CreateFrame("Frame", nil, bar)
    rest:SetPoint("CENTER", clockText, "TOPRIGHT", REST_X, REST_Y)
    rest:Hide()
    rest.icon = rest:CreateTexture(nil, "OVERLAY")
    rest.icon:SetAllPoints()
    rest.icon:SetTexture(St.RESTING)
    RestFrame(rest.icon, 1)
    rest.frameT, rest.frameN = 0, 1
    rest:SetScript("OnShow", RestShown)
    rest:SetScript("OnHide", RestHidden)
    bar.rest = rest
end

local function BuildSystem()
    local sys = CreateFrame("Button", nil, UIParent)
    sys:RegisterForClicks("AnyUp")
    sys.text = sys:CreateFontString(nil, "OVERLAY")
    sys.text:SetPoint("CENTER")
    sys.tipTime = 0
    sys:SetScript("OnEnter", SystemEnter)
    sys:SetScript("OnLeave", SystemLeave)
    sys:SetScript("OnClick", SystemClick)
    bar.sys = sys
end

local function Build()
    bar = CreateFrame("Frame", "NaowhForeverTopBar", UIParent)
    bar:SetFrameStrata("MEDIUM")
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar.segs = Look.NewPills(bar)
    BuildClock()
    BuildRest()
    BuildSystem()
    bar:HookScript("OnShow", AnchorSystem)
    bar:HookScript("OnHide", AnchorSystem)
    bar:SetMouseClickEnabled(false)
    bar:SetScript("OnEnter", UpdateHover)
    bar:SetScript("OnLeave", UpdateHover)
    leftGroup = CreateFrame("Frame", nil, bar)
    rightGroup = CreateFrame("Frame", nil, bar)
    Buttons.Badge(Buttons.Secure("friends", leftGroup, UpdateHover), St.FRIENDS_RGB)
    Buttons.Badge(Buttons.Secure("guild", leftGroup, UpdateHover), St.GUILD_RGB)
    Buttons.Secure("hearth", rightGroup, UpdateHover)
    bar.mover = UI.AttachMover(bar, "Top Bar", SavePosition, "QoL/Interface", "QoL/Interface:topBar")
end

local function Layout(group, keys)
    local list = {}
    for i, key in ipairs(keys) do list[i] = buttons[key] end
    Look.Row(group, list, #list)
end

local function GroupKeys()
    local left, right = {}, {}
    for _, b in pairs(buttons) do b:Hide() end
    Look.Buttons(function(side, key, texture, glyph, coords, name)
        local b = name and Buttons.Broker(name, rightGroup, UpdateHover) or buttons[key]
        if name and not ns.Shared.Parts.ClassicIcon(b.icon, name) then
            b.icon:SetTexture(texture)
            b.icon:SetDesaturated(not (glyph or ns.classicSkin))
            b.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        end
        b:SetParent(side == "left" and leftGroup or rightGroup)
        local keys = side == "left" and left or right
        keys[#keys + 1] = key
    end)
    return left, right
end

local function Tick()
    UpdateSystem()
    if not bar:IsShown() then return end
    if (S.Get("showClock") and PaintClock()) or fitPending then FitWidth() end
    tickCount = tickCount + 1
    if tickCount < BADGE_TICKS then return end
    tickCount = 0
    UpdateBadges()
end

local function StartTicker()
    if ticker then return end
    for i = 1, #BAR_EVENTS do events:RegisterEvent(BAR_EVENTS[i]) end
    tickCount = 0
    ticker = C_Timer.NewTicker(TICK, Tick)
end

local function StopTicker()
    if ticker then ticker:Cancel(); ticker = nil end
    for i = 1, #BAR_EVENTS do events:UnregisterEvent(BAR_EVENTS[i]) end
end

local function Place()
    local pos = S.Get("pos")
    bar:ClearAllPoints()
    if pos then
        bar:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        bar:SetPoint("TOP", UIParent, "TOP", 0, 0)
    end
end

local function Size()
    local h = Look.BarHeight()
    bar:SetHeight(h)
    bar.clockBtn:SetSize(CLOCK_BTN_W, h)
    bar.clockBtn:SetShown(S.Get("showClock"))
    clockText:SetShown(S.Get("showClock"))
    local rest = math.max(REST_MIN, math.floor(h * REST_SCALE + ROUND))
    bar.rest:SetSize(rest, rest)
    Look.ClockFont(clockText)
    clockText.last = nil
    PaintClock()
    Look.SystemFont(bar.sys.text)
    bar.sys.fps = nil
    bar.sys:SetHeight(S.Get("sysSize") + SYS_H_PAD)
end

local function Arrange()
    local left, right = GroupKeys()
    Layout(leftGroup, left)
    Layout(rightGroup, right)
    bar.nLeft, bar.nRight = #left, #right
    FitWidth()
    Look.PaintPills(bar, bar.segs, leftGroup, rightGroup, clockText, #left, #right)
end

local function TurnOff()
    StopTicker()
    if not bar then return end
    UnregisterStateDriver(bar, "visibility")
    bar:Hide()
    bar.sys:Hide()
    PlaceWidgets()
end

local function Apply()
    if InCombatLockdown() then
        pending:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if not (On() or unlocked) then return TurnOff() end
    if not bar then Build() end
    Place()
    Size()
    Arrange()
    if S.Get("hideInCombat") and not unlocked then
        RegisterStateDriver(bar, "visibility", COMBAT_DRIVER)
    else
        UnregisterStateDriver(bar, "visibility")
        bar:Show()
    end
    bar.mover:SetShown(unlocked == true)
    bar:SetMouseMotionEnabled(S.Get("mouseover"))
    UpdateHover()
    AnchorSystem()
    UpdateSystem()
    PlaceWidgets()
    UpdateBadges()
    UpdateResting()
    StartTicker()
end

local function OnPending(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    Apply()
end

local function OnEvent(_, event)
    if event == "PLAYER_UPDATE_RESTING" then
        UpdateResting()
    elseif event == "UPDATE_INSTANCE_INFO" then
        Info.InstanceInfoUpdated()
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if event == "PLAYER_ENTERING_WORLD" then RequestRaidInfo() end
        Apply()
    else
        UpdateBadges()
    end
end

local function SettingChanged(key)
    if key ~= "pos" then Apply() end
end

local function Unlocked()
    unlocked = On() == true
    Apply()
end

local function Locked()
    unlocked = false
    if bar then Apply() end
end

ns.PlaceTopCentreWidgets = PlaceWidgets

pending:SetScript("OnEvent", OnPending)
hooksecurefunc(S, "Set", SettingChanged)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", Unlocked)
hooksecurefunc(ns, "HideUnlockMode", Locked)

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UPDATE_INSTANCE_INFO")
events:SetScript("OnEvent", OnEvent)

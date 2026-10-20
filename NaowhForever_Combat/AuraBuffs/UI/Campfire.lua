-- Campfire.lua: the Campfire reminder on screen, Round or Simple, the Sleeping Bag beside Round, and the Camp Nearby alert.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local S = A.Settings
local T = ns.THEME
local St = A.Style
local Parts = ns.Shared.Parts
local D, Camp = A.CampData, A.Camp
local Look, Bar, Alert, Glow, CampBag = A.CampIcon, A.CampBar, A.CampAlert, A.Glow, A.CampBag

local CAMP_BENEFITS, CAMPFIRE_NEARBY = D.CAMP_BENEFITS, D.CAMPFIRE_NEARBY
local WELCOMING_CAMPFIRE, WELCOMING_CAMPFIRE_CRAFT = D.WELCOMING_CAMPFIRE, D.WELCOMING_CAMPFIRE_CRAFT
local TIME_STEPS = St.CAMP_TIME_STEPS
local REFRESH_NOW = TIME_STEPS[2][1]
local SIT_PREFIX = St.CAMP_SIT_PREFIX
local SECONDS = A.C.SECONDS
local TIMER_PAD = 0.1
local UNLOCK_DURATION, UNLOCK_LEFT = 3600, 2400
local DEFAULT_X, DEFAULT_Y = -260, 120
local ALERT_ORDER = 1
local CARD = A.PAGE .. ":campfire"
local NEARBY_CARD = A.PAGE .. ":campNearby"
local UNLOCK_TEXT = ns.L("+Rested\n+Crit")
local DISMISS_TIP = ns.L("Right-click to dismiss until you leave the campfire.")
local TEXT_MOVER = "Campfire"
local TEXT_NEARBY = "Camp Nearby"
local TEXT_TITLE = "Camp Benefits"
local TEXT_SIT_TIP = ns.L("Click to sit at the campfire.")
local TEXT_UPCOMING = ns.L("You'll get:")
local TEXT_RESTING = ns.L("Resting at a campfire")
local TEXT_LANDS_IN = ns.L("Camp Benefits in")
local TEXT_NO_BONUSES = ns.L("Camp Benefits is up, but it lists no bonuses: this camp may have no features, or they "
    .. "can't be read yet.")
local TEXT_TIME_LEFT = ns.L("Time left")
local TEXT_REFRESH_NOW = ns.L("Refresh now")
local TEXT_REFRESH_IN = ns.L("Refresh in ")
local TEXT_NONE = ns.L("No Camp Benefits")
local TEXT_SIT = ns.L("Sit at a campfire to refresh")
local TEXT_IN_RANGE = ns.L("A campfire is in range")
local MINUTES, SECONDS_LEFT = ns.L("%d min"), ns.L("%d sec")

local Spot = { DEFAULT = { point = "CENTER", relPoint = "CENTER", x = DEFAULT_X, y = DEFAULT_Y } }
Spot.CORNERS = { TOPLEFT = { 1, -1 }, TOP = { 0, -1 }, TOPRIGHT = { -1, -1 }, RIGHT = { -1, 0 },
    BOTTOMLEFT = { 1, 1 }, BOTTOM = { 0, 1 }, BOTTOMRIGHT = { -1, 1 } }

local icon, unlocked, simpleBar
local hasCamp
local shownExpiry
local alert
local alertGen = 0
local alertArmed
local alertDismissed
local ringGen = 0
local showGen = 0
local showArmed
local campState, campExpiry, campUpcoming
local events = CreateFrame("Frame")
local Simple = Camp.Simple

local function On()
    return S.Get("enabled") and S.Get("campfire")
end

local function PaintBuffs()
    local hidden = ns.CampBuffMode() == "hover" and not unlocked and not icon:IsMouseOver()
    icon.buffs:SetAlpha(hidden and 0 or 1)
end

local function TimeWords(left)
    if left >= SECONDS then return MINUTES:format(math.ceil(left / SECONDS)) end
    return SECONDS_LEFT:format(math.max(0, math.ceil(left)))
end

local function TipBonuses(tip)
    local fg, muted = T.fg, T.muted
    for i = 1, Camp.count do
        local feature = Camp.features[i]
        if feature then
            tip:AddDoubleLine(Camp.BonusWords(feature), Camp.FeatureName(feature), fg.r, fg.g, fg.b,
                muted.r, muted.g, muted.b)
        else
            tip:AddLine(Camp.tags[i], fg.r, fg.g, fg.b)
        end
    end
end

local function TipSitting(tip)
    local fg, muted, soft = T.fg, T.muted, T.accentSoft
    if campUpcoming then
        tip:AddLine(TEXT_UPCOMING, fg.r, fg.g, fg.b)
        TipBonuses(tip)
    else
        tip:AddLine(TEXT_RESTING, fg.r, fg.g, fg.b)
    end
    if campExpiry then
        tip:AddDoubleLine(TEXT_LANDS_IN, TimeWords(campExpiry - GetTime()), muted.r, muted.g, muted.b,
            soft.r, soft.g, soft.b)
    end
end

local function TipUp(tip)
    local muted = T.muted
    if Camp.count > 0 then
        TipBonuses(tip)
    else
        tip:AddLine(TEXT_NO_BONUSES, muted.r, muted.g, muted.b, true)
    end
    if not campExpiry then return end
    local left = campExpiry - GetTime()
    local c = Look.Step(left)[2]
    tip:AddDoubleLine(TEXT_TIME_LEFT, TimeWords(left), muted.r, muted.g, muted.b, c.r, c.g, c.b)
    if left <= REFRESH_NOW then
        tip:AddLine(TEXT_REFRESH_NOW, c.r, c.g, c.b)
    else
        tip:AddLine(TEXT_REFRESH_IN .. TimeWords(left - REFRESH_NOW), muted.r, muted.g, muted.b)
    end
end

local function TipMissing(tip)
    local muted, out = T.muted, St.TIME_OUT_RGB
    tip:AddLine(TEXT_NONE, muted.r, muted.g, muted.b)
    tip:AddLine(TEXT_SIT, out.r, out.g, out.b)
end

local function CampTip(owner)
    if unlocked or not Parts.Tip(owner, "ANCHOR_TOP") then return false end
    local tip, soft = GameTooltip, T.accentSoft
    tip:SetText(TEXT_TITLE, T.accent.r, T.accent.g, T.accent.b)
    if campState == "sitting" then
        TipSitting(tip)
    elseif campState == "up" then
        TipUp(tip)
    else
        TipMissing(tip)
    end
    local readable = not (InCombatLockdown() or C_Secrets.ShouldAurasBeSecret())
    if readable and C_UnitAuras.GetPlayerAuraBySpellID(CAMPFIRE_NEARBY) then
        tip:AddLine(TEXT_IN_RANGE, soft.r, soft.g, soft.b)
    end
    return true
end

local function ShowTip(owner)
    if CampTip(owner) then GameTooltip:Show() end
end

local function HideTip()
    GameTooltip:Hide()
end

local function Anchored(simple, left, x, y)
    if simple then return { point = "LEFT", relPoint = "BOTTOMLEFT", x = left, y = y } end
    return { point = "CENTER", relPoint = "BOTTOMLEFT", x = x, y = y }
end

local function SavePos(pos)
    local x, y = icon:GetCenter()
    local left = icon:GetLeft()
    if x and y and left then
        pos = Anchored(Simple(), left, x, y)
        icon:ClearAllPoints()
        icon:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    end
    S.Set("campPos", pos)
end

local function SetGlow(on)
    Glow.Set(icon, on and S.Get("campGlow") and not unlocked, "campGlow")
end

local function OnSitClick(self, button)
    if unlocked then return end
    local dismiss = self.dismiss and (button == "RightButton" or IsControlKeyDown())
    if dismiss then return self.dismiss(self.dismissFrom, "RightButton") end
    if button == "LeftButton" and not InCombatLockdown() then C_ChatInfo.PerformEmote("SIT") end
end

local function OnSitEnter(self)
    Look.Hot(self:GetParent(), true)
    if self.campTip then
        if not CampTip(self) then return end
        GameTooltip:AddLine(TEXT_SIT_TIP, T.fg.r, T.fg.g, T.fg.b)
        GameTooltip:Show()
        return
    end
    if not Parts.Tip(self, "ANCHOR_TOP") then return end
    GameTooltip:SetText(TEXT_SIT_TIP, T.fg.r, T.fg.g, T.fg.b)
    if self.dismiss then GameTooltip:AddLine(DISMISS_TIP, T.muted.r, T.muted.g, T.muted.b) end
    GameTooltip:Show()
end

local function OnSitLeave(self)
    Look.Hot(self:GetParent(), false)
    HideTip()
end

local function SitSpot(fire, above, area, dismiss)
    if fire.sitSpot then return fire.sitSpot end
    local spot = CreateFrame("Button", nil, fire)
    spot:SetAllPoints(area or fire)
    spot:SetFrameLevel(math.max(fire:GetFrameLevel(), above and above:GetFrameLevel() or 0) + 1)
    spot.dismiss, spot.dismissFrom = dismiss, above
    spot.campTip = area ~= nil and not dismiss
    if dismiss then spot:RegisterForClicks("LeftButtonUp", "RightButtonUp") else spot:RegisterForClicks("LeftButtonUp") end
    spot:SetScript("OnClick", OnSitClick)
    spot:SetScript("OnEnter", OnSitEnter)
    spot:SetScript("OnLeave", OnSitLeave)
    fire.sitSpot = spot
    return spot
end

local function ShowSitSpot(fire, on, above, area, dismiss)
    on = on and S.Get("campSitButton") and not unlocked and true or false
    if not (on or fire.sitSpot) then return end
    local spot = SitSpot(fire, above, area, dismiss)
    spot:SetShown(on)
    if not on then Look.Hot(fire, false) end
end

local function Build()
    icon = CreateFrame("Frame", "NaowhForeverCampfire", UIParent)
    icon:SetMovable(true)
    icon:SetClampedToScreen(true)
    Look.New(icon)
    icon:SetScript("OnEnter", PaintBuffs)
    icon:SetScript("OnLeave", PaintBuffs)
    icon.mover = ns.UI.AttachMover(icon, TEXT_MOVER, SavePos, A.PAGE, CARD, true)
    icon:Hide()
end

local function UseStyle(simple)
    if simple and not simpleBar then
        simpleBar = Bar.New(icon)
        simpleBar:SetMouseMotionEnabled(true)
        simpleBar:SetMouseClickEnabled(false)
        simpleBar:SetScript("OnEnter", ShowTip)
        simpleBar:SetScript("OnLeave", HideTip)
    end
    if simpleBar then simpleBar:SetShown(simple) end
    Look.Shown(icon, not simple)
end

function Spot.ForStyle(pos)
    local want = Simple() and "LEFT" or "CENTER"
    if pos.point == want then return pos end
    local x, y = pos.x, pos.y
    local corner = Spot.CORNERS[pos.point]
    if corner then
        local half = S.Get("campIconSize") / 2
        x, y = x + corner[1] * half, y + corner[2] * half
    elseif pos.point == "LEFT" then
        x = x + Bar.FireX(S.Get("campSimpleHeight"))
    end
    if want == "LEFT" then x = x - Bar.FireX(S.Get("campSimpleHeight")) end
    return { point = want, relPoint = pos.relPoint, x = x, y = y }
end

local function Place()
    local saved = S.Get("campPos")
    local pos = Spot.ForStyle(saved or Spot.DEFAULT)
    if saved and pos ~= saved then S.Set("campPos", pos) end
    icon:ClearAllPoints()
    icon:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

local function BarShown()
    return simpleBar ~= nil and simpleBar:IsShown()
end

local function FitRound(spot)
    spot:ClearAllPoints()
    spot:SetPoint("TOP", icon, "TOP")
    spot:SetPoint("BOTTOM", icon.label, "BOTTOM")
    spot:SetWidth(math.max(icon:GetWidth(), icon.label:GetStringWidth()))
end

local function ShowSit(nearby)
    ShowSitSpot(icon, nearby and not BarShown())
    if icon.sitSpot and icon.sitSpot:IsShown() then FitRound(icon.sitSpot) end
    if simpleBar then ShowSitSpot(simpleBar.camp, nearby and BarShown(), simpleBar, simpleBar) end
end

local function PaintTime(color, low)
    if BarShown() then
        Bar.Paint(simpleBar, color, low)
    else
        icon.drain:SetSwipeColor(color.r, color.g, color.b, 1)
    end
end

local function RunTimer(expiry, duration, prefix)
    if BarShown() then
        simpleBar.line:Run(expiry - duration, duration, prefix)
    else
        icon.timer:SetCooldownFromExpirationTime(expiry, duration)
        icon.drain:SetCooldownFromExpirationTime(expiry, duration)
    end
end

local function Timed(on)
    if BarShown() then Bar.Timed(simpleBar, on) else Look.Timed(icon, on) end
end

local function ColorRing(expiry)
    ringGen = ringGen + 1
    local left = expiry - GetTime()
    local step = Look.Step(left)
    PaintTime(step[2], step ~= TIME_STEPS[1])
    if step[1] <= 0 then return end
    local gen = ringGen
    C_Timer.After(left - step[1] + TIMER_PAD, function()
        if gen == ringGen then ColorRing(expiry) end
    end)
end

local function ShowUp(duration, expiry, text, labels, icons, n)
    local timed = S.Get("campTimer") and duration and duration > 0 and expiry and expiry > GetTime() or false
    campState, campExpiry = "up", expiry
    if BarShown() then
        Bar.Up(simpleBar, labels, icons, n, timed)
    else
        Look.Up(icon, ns.CampBuffMode() ~= "off" and text or "")
        PaintBuffs()
    end
    SetGlow(false)
    ShowSit(false)
    if timed then
        if shownExpiry ~= expiry then
            RunTimer(expiry, duration)
            ColorRing(expiry)
            shownExpiry = expiry
        end
        Timed(true)
    else
        Timed(false)
        ringGen = ringGen + 1
        shownExpiry = nil
    end
    icon:Show()
end

local function ShowSitting(duration, expiry, upcoming)
    local timed = S.Get("campTimer") and expiry and expiry > GetTime() or false
    campState, campExpiry, campUpcoming = "sitting", expiry, upcoming
    if BarShown() then
        Bar.Sitting(simpleBar, Camp.barLabels, Camp.barIcons, Camp.barCount, timed, upcoming)
    else
        Look.Sitting(icon)
    end
    SetGlow(false)
    ShowSit(false)
    ringGen = ringGen + 1
    if timed and shownExpiry ~= expiry then
        RunTimer(expiry, duration, SIT_PREFIX)
        PaintTime(T.accent, false)
        shownExpiry = expiry
    elseif not timed then
        shownExpiry = nil
    end
    Timed(timed)
    icon:Show()
end

local function ShowMissing(nearby)
    campState, campExpiry = "missing", nil
    if BarShown() then
        Bar.Missing(simpleBar, nearby)
    else
        Look.Missing(icon, nearby and S.Get("campSitButton"))
    end
    SetGlow(true)
    ShowSit(nearby)
    ringGen = ringGen + 1
    shownExpiry = nil
    icon:SetShown(S.Get("campShowMissing") or unlocked == true)
end

local function AlertTip(self)
    if unlocked or not Parts.Tip(self, "ANCHOR_TOP") then return end
    GameTooltip:SetText(DISMISS_TIP, T.fg.r, T.fg.g, T.fg.b)
    GameTooltip:Show()
end

local function AlertDismiss(self, button)
    if button ~= "RightButton" or unlocked then return end
    alertDismissed = true
    self:EnableMouse(false)
    HideTip()
    Alert.Fade(alert, false)
end

local function OnAlertShow(self)
    self:EnableMouse(IsControlKeyDown())
    self:RegisterEvent("MODIFIER_STATE_CHANGED")
end

local function OnAlertHide(self)
    Alert.Stop(self)
    self:UnregisterEvent("MODIFIER_STATE_CHANGED")
end

local function OnAlertModifier(self)
    self:EnableMouse(IsControlKeyDown())
end

local function OnAlertMouseUp(self, button)
    if button == "LeftButton" and IsControlKeyDown() and not unlocked then
        alertDismissed = true
        Alert.Fade(self, false)
    end
end

local function BuildAlert()
    alert = CreateFrame("Frame", "NaowhForeverCampNearby", UIParent)
    alert:SetMovable(true)
    alert:SetClampedToScreen(true)
    Alert.Look(alert)
    alert:EnableMouse(false)
    alert:SetScript("OnShow", OnAlertShow)
    alert:SetScript("OnHide", OnAlertHide)
    alert:SetScript("OnEvent", OnAlertModifier)
    alert:SetScript("OnMouseUp", OnAlertMouseUp)
    alert.click = CreateFrame("Button", nil, alert)
    alert.click:SetAllPoints()
    alert.click:RegisterForClicks("RightButtonUp")
    alert.click:EnableMouse(false)
    alert.click:SetScript("OnClick", AlertDismiss)
    alert.click:SetScript("OnEnter", AlertTip)
    alert.click:SetScript("OnLeave", HideTip)
    alert:Hide()
    ns.AlertStack(alert, ALERT_ORDER, TEXT_NEARBY, A.PAGE, NEARBY_CARD)
end

local function LayoutAlert()
    alert:SetScale(S.Get("campAlertScale"))
    local f = alert.bar
    Bar.Layout(f)
    if alert:IsShown() then Bar.Nearby(f, f.runStart, f.runLength) end
end

local function SetAlert(show, start, duration)
    if not alert then
        if not show then return end
        BuildAlert()
        LayoutAlert()
    end
    if show then Bar.Nearby(alert.bar, start, duration) end
    Alert.Fade(alert, show)
    if show and not alert.passed and not InCombatLockdown() then
        alert.click:SetPassThroughButtons("LeftButton")
        alert.passed = true
    end
    alert.click:EnableMouse(show and alert.passed and not unlocked or false)
    ShowSitSpot(alert.bar.camp, show, alert.click, alert, AlertDismiss)
end

local function DisarmAlert()
    alertGen = alertGen + 1
    alertArmed = nil
end

local function HideAlert()
    DisarmAlert()
    SetAlert(false)
end

local function ArmAlert(expiry, wait)
    DisarmAlert()
    alertArmed = expiry
    local gen = alertGen
    C_Timer.After(wait + TIMER_PAD, function()
        if gen ~= alertGen then return end
        alertArmed = nil
        Camp.Refresh()
    end)
end

local function AuraTime(aura)
    local expiry = aura and aura.expirationTime
    if expiry and issecretvalue and issecretvalue(expiry) then expiry = nil end
    local left = expiry and expiry > 0 and expiry - GetTime()
    local duration = aura and aura.duration
    if duration and (Camp.Secret(duration) or duration <= 0) then duration = nil end
    return expiry, left, duration
end

local function UpdateAlert(aura)
    if not (S.Get("campNearbyAlert") and C_UnitAuras.GetPlayerAuraBySpellID(CAMPFIRE_NEARBY)) then
        alertDismissed = nil
        return HideAlert()
    end
    if alertDismissed or (Simple() and not aura) then return HideAlert() end
    local expiry, left, duration = AuraTime(aura)
    if aura and not left then return HideAlert() end
    local low = S.Get("campNearbyMinutes") * SECONDS
    local timed = aura and duration and left < low
    SetAlert(not aura or left < low, timed and expiry - duration or nil, timed and duration or nil)
    if not (aura and left >= low) then
        DisarmAlert()
    elseif alertArmed ~= expiry then
        ArmAlert(expiry, left - low)
    end
end

local function ArmShow(expiry, under, left)
    local key = expiry .. ":" .. under
    if showArmed == key then return end
    showArmed = key
    showGen = showGen + 1
    local gen = showGen
    C_Timer.After(left - under + TIMER_PAD, function()
        if gen ~= showGen then return end
        showArmed = nil
        Camp.Refresh()
    end)
end

local function Sitting()
    local sitting = C_UnitAuras.GetPlayerAuraBySpellID(WELCOMING_CAMPFIRE)
        or C_UnitAuras.GetPlayerAuraBySpellID(WELCOMING_CAMPFIRE_CRAFT)
    local duration, expiry = sitting and sitting.duration, sitting and sitting.expirationTime
    if not sitting or (issecretvalue and (issecretvalue(duration) or issecretvalue(expiry))) or duration <= 0 then
        return nil
    end
    return duration, expiry
end

local function RefreshUp(aura)
    local duration, expiry = aura.duration, aura.expirationTime
    if issecretvalue and (issecretvalue(duration) or issecretvalue(expiry)) then
        duration, expiry = nil, nil
    end
    local left = expiry and expiry > 0 and expiry - GetTime()
    local under = S.Get("campShowUnderMinutes") * SECONDS
    if S.Get("campShowUnder") and left and left > under then
        icon:Hide()
        ArmShow(expiry, under, left)
        return
    end
    if showArmed then
        showArmed = nil
        showGen = showGen + 1
    end
    if Simple() or ns.CampBuffMode() ~= "off" then Camp.ReadBonuses(aura) end
    ShowUp(duration, expiry, Camp.text, Camp.barLabels, Camp.barIcons, Camp.barCount)
end

local function ShowCamp(event)
    if not icon then return end
    if unlocked then
        ShowUp(UNLOCK_DURATION, GetTime() + UNLOCK_LEFT, UNLOCK_TEXT, Camp.sampleLabels, Camp.sampleIcons,
            Camp.FillSamples(true))
        SetAlert(S.Get("campNearbyAlert"))
        return
    end
    if not (On() and Camp.InOpenWorld()) then
        icon:Hide()
        return HideAlert()
    end
    if InCombatLockdown() or event == "PLAYER_REGEN_DISABLED" or C_Secrets.ShouldAurasBeSecret() then
        return HideAlert()
    end
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(CAMP_BENEFITS)
    local had = hasCamp
    hasCamp = aura ~= nil
    local sitDuration, sitExpiry = Sitting()
    if sitDuration then
        ShowSitting(sitDuration, sitExpiry, Simple() and Camp.ReadBonuses(aura) or false)
        return HideAlert()
    end
    if aura then
        RefreshUp(aura)
    else
        ShowMissing(C_UnitAuras.GetPlayerAuraBySpellID(CAMPFIRE_NEARBY) ~= nil)
        if had and S.Get("campSound") then
            ns.UI._PlayLSMSound(ns.UI.SoundPathFor(S.Get("campSoundKey")))
        end
    end
    UpdateAlert(aura)
end

local function SyncBag()
    CampBag.Sync(icon, not unlocked and not BarShown() and On() and Camp.InOpenWorld())
end

local function Refresh(_, event)
    ShowCamp(event)
    SyncBag()
end

local function OnEvent(_, event)
    if event == "BAG_UPDATE_DELAYED" or event == "BAG_UPDATE_COOLDOWN" then return SyncBag() end
    Refresh(nil, event)
end

local function Layout(simple)
    UseStyle(simple)
    CampBag.Layout()
    icon:EnableMouse(not simple and ns.CampBuffMode() == "hover")
    if simple then
        Bar.Layout(simpleBar)
        Camp.FilterBar()
    else
        Look.Layout(icon)
    end
end

local function Listen()
    events:RegisterUnitEvent("UNIT_AURA", "player")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    if Simple() then
        events:UnregisterEvent("BAG_UPDATE_DELAYED")
        events:UnregisterEvent("BAG_UPDATE_COOLDOWN")
    else
        events:RegisterEvent("BAG_UPDATE_DELAYED")
        events:RegisterEvent("BAG_UPDATE_COOLDOWN")
    end
end

local function Apply()
    if not On() then
        events:UnregisterAllEvents()
        hasCamp = nil
        ringGen = ringGen + 1
        HideAlert()
        if icon then SetGlow(false) end
        if icon and not unlocked then icon:Hide() end
        if not unlocked then return CampBag.Sync(icon, false) end
    end
    if not icon then Build() end
    Layout(Simple())
    Place()
    icon.mover:SetShown(unlocked == true)
    if On() then Listen() end
    shownExpiry = nil
    Refresh()
    if alert then LayoutAlert() end
end

local function OnSet(key)
    if key == "campNearbyMinutes" then DisarmAlert() end
    if key == "enabled" or (key:find("^camp") and key ~= "campPos") then Apply() end
end

local function OnUnlock()
    unlocked = On() == true
    Apply()
end

local function OnLock()
    unlocked = false
    if icon then Apply() end
end

Camp.Refresh = Refresh

events:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", OnUnlock)
hooksecurefunc(ns, "HideUnlockMode", OnLock)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

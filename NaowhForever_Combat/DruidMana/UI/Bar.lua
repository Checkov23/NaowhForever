-- Bar.lua: the Druid Mana bar on screen: your mana while shapeshifted, the five second rule, the shift cost and your shifts left.
local ns = _G.NaowhForever

local DM = ns.DruidMana
local S = DM.Settings
local St = DM.Style
local T = ns.THEME
local UI = ns.UI
local Parts = ns.Shared.Parts
local ItemBar = ns.Shared.ItemBar

local MANA, MANA_TOKEN = Enum.PowerType.Mana, "MANA"
local PLAYER = "player"
local FIVE_SECONDS = 5
local TICK_SECONDS = 2
local HOME_Y = -200
local PERCENT = 100
local FRAME_NAME = "NaowhForeverDruidMana"
local MOVER_LABEL = "Druid Mana"
local CARD = DM.PAGE .. ":bar"
local SPARK_TEX = "Interface\\CastingBar\\UI-CastingBar-Spark"
local CAT_FORM, TRAVEL_FORM, AQUATIC_FORM, BEAR_FORM, DIRE_BEAR_FORM, MOONKIN_FORM = 1, 3, 4, 5, 8, 31
local FORMS = { [CAT_FORM] = "showCat", [BEAR_FORM] = "showBear", [DIRE_BEAR_FORM] = "showBear",
    [TRAVEL_FORM] = "showTravel", [AQUATIC_FORM] = "showAquatic", [MOONKIN_FORM] = "showMoonkin" }
local BASE_EVENTS = { "UPDATE_SHAPESHIFT_FORM", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED",
    "UNIT_DISPLAYPOWER", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_POWER_UPDATE" }
local SHOWN_EVENTS = { "UNIT_MAXPOWER" }

local TEXT_VALUES, TEXT_CURRENT, TEXT_PERCENT = "%d / %d", "%d", "%.0f%%"
local TEXT_SHIFTS, TEXT_SHIFT = ns.L("%d shifts left"), ns.L("1 shift left")

local holder, bar, costSeg, tick, missClip, missSeg, missTick, spark, left, right, line, countdown, info, bg
local unlockActive, unlocked, inCombat, inFive, pendingPlace, pendingApply, fiveTimer, cost, curve, lastMana
local events = CreateFrame("Frame")

local Readable = DM.Readable

local function Percent()
    if not curve then
        curve = C_CurveUtil.CreateCurve()
        curve:SetType(Enum.LuaCurveType.Linear)
        curve:AddPoint(0, 0)
        curve:AddPoint(1, PERCENT)
    end
    return UnitPowerPercent(PLAYER, MANA, false, curve)
end

local function ManaCost(spellID)
    if not Readable(spellID) then return nil end
    local costs = C_Spell.GetSpellPowerCost(spellID)
    if not Readable(costs) or (issecrettable and issecrettable(costs)) or type(costs) ~= "table" then return nil end
    for i = 1, #costs do
        local kind, amount = costs[i].type, costs[i].cost
        if not (Readable(kind) and Readable(amount)) then return nil end
        if kind == MANA and amount > 0 then return amount end
    end
    return nil
end

local function SavePosition(pos)
    S.Set("druidManaPos", pos)
    if ItemBar.Anchored(S, DM.PREFIX) then S.Set("druidManaAnchor", "UIParent") end
end

local function Build()
    holder = ItemBar.Frame(FRAME_NAME, MOVER_LABEL, SavePosition, DM.PAGE, CARD)
    bg = ns.Solid(holder, "BACKGROUND", T.bg)
    bg:SetAllPoints()
    bar = CreateFrame("StatusBar", nil, holder)
    ns.PixelInset(bar, 1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    local clip = CreateFrame("Frame", nil, bar)
    clip:SetAllPoints()
    clip:SetClipsChildren(true)
    costSeg = clip:CreateTexture(nil, "ARTWORK")
    tick = clip:CreateTexture(nil, "OVERLAY")
    tick:SetColorTexture(St.TICK_RGB.r, St.TICK_RGB.g, St.TICK_RGB.b, 1)
    tick:SetPoint("CENTER", costSeg, "LEFT")
    missClip = CreateFrame("Frame", nil, bar)
    missClip:SetClipsChildren(true)
    missSeg = missClip:CreateTexture(nil, "ARTWORK")
    missSeg:SetPoint("TOPLEFT", bar, "TOPLEFT")
    missSeg:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
    missTick = missClip:CreateTexture(nil, "OVERLAY")
    missTick:SetPoint("CENTER", missSeg, "RIGHT")
    local over = CreateFrame("Frame", nil, bar)
    over:SetAllPoints()
    over:SetFrameLevel(math.max(clip:GetFrameLevel(), missClip:GetFrameLevel()) + 1)
    spark = over:CreateTexture(nil, "OVERLAY")
    spark:SetTexture(SPARK_TEX)
    spark:SetBlendMode("ADD")
    local pulse = spark:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(St.SPARK_ALPHA)
    fade:SetToAlpha(St.SPARK_LOW)
    fade:SetDuration(TICK_SECONDS / 2)
    spark.pulse = pulse
    left = ns.Font(over, St.TEXT_SIZE, St.OUTLINE)
    left:SetPoint("LEFT", St.TEXT_INSET, 0)
    right = ns.Font(over, St.TEXT_SIZE, St.OUTLINE)
    right:SetPoint("RIGHT", -St.TEXT_INSET, 0)
    ns.Border(holder, St.EDGE_RGB)
    countdown = ns.Font(holder, St.TEXT_SIZE, St.OUTLINE)
    countdown:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", 0, -(St.LINE_GAP + St.LINE_H + St.INFO_GAP))
    info = ns.Font(holder, St.TEXT_SIZE, St.OUTLINE)
    info:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -(St.LINE_GAP + St.LINE_H + St.INFO_GAP))
    line = Parts.TimerLine(holder, St.LINE_H, countdown)
    line:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -St.LINE_GAP)
    line:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", 0, -St.LINE_GAP)
    line:Hide()
    holder:Hide()
end

local function Style()
    local width, height = S.Get("width"), S.Get("height")
    holder:SetSize(width, height)
    local texture = UI.TexturePath(S.Get("texture"), St.FLAT_TEX)
    local mana, warn, missing = S.Get("manaColor"), S.Get("warnColor"), S.Get("missingColor")
    bar:SetStatusBarTexture(texture)
    bar:SetStatusBarColor(mana.r, mana.g, mana.b)
    local fill = bar:GetStatusBarTexture()
    costSeg:SetTexture(texture)
    costSeg:SetVertexColor(warn.r, warn.g, warn.b)
    costSeg:ClearAllPoints()
    costSeg:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
    costSeg:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    missClip:ClearAllPoints()
    missClip:SetPoint("TOPLEFT", fill, "TOPRIGHT")
    missClip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
    missSeg:SetTexture(texture)
    missSeg:SetVertexColor(missing.r, missing.g, missing.b)
    missTick:SetColorTexture(missing.r, missing.g, missing.b, 1)
    spark:ClearAllPoints()
    spark:SetPoint("CENTER", fill, "RIGHT")
    bg:SetColorTexture(T.bg.r, T.bg.g, T.bg.b, S.Get("bgAlpha"))
    local size = S.Get("textSize")
    local small = math.max(1, math.floor(size * St.INFO_SIZE))
    Parts.HudFont(left, S.Get("font"), size, S.Get("outline"))
    Parts.HudFont(right, S.Get("font"), size, S.Get("outline"))
    Parts.HudFont(info, S.Get("font"), small, S.Get("outline"))
    Parts.HudFont(countdown, S.Get("font"), small, S.Get("outline"))
    countdown:SetTextColor(St.COUNTDOWN_RGB.r, St.COUNTDOWN_RGB.g, St.COUNTDOWN_RGB.b)
    tick:SetSize(St.TICK_W, height)
    missTick:SetSize(St.TICK_W, height)
    spark:SetSize(St.SPARK_W, height * 2)
    line:Paint(mana)
end

local function Place()
    if InCombatLockdown() then
        pendingPlace = true
        return
    end
    pendingPlace = false
    if UI.HasAnchor(holder.mover) then return end
    ItemBar.Put(holder, S, DM.PREFIX, HOME_Y)
end

local function FormWanted()
    return S.Get(FORMS[GetShapeshiftFormID()] or "showCaster") == true
end

local function Wanted()
    if unlocked then return true end
    return DM.On() and FormWanted() and (not S.Get("combatOnly") or inCombat) and true or false
end

local function FormCost()
    local index = GetShapeshiftForm()
    if not Readable(index) or index == 0 then return nil end
    local _, _, _, spellID = GetShapeshiftFormInfo(index)
    return ManaCost(spellID)
end

local function Inner()
    return S.Get("width") - 2 * ns.OnePixel(bar)
end

local function PlaceCost()
    local max = UnitPowerMax(PLAYER, MANA)
    local known = S.Get("powershift") and cost and Readable(max) and max > 0
    local width = known and Inner() * math.min(cost / max, 1)
    local shown, missing = known and S.Get("shiftMark"), known and S.Get("warnLow")
    if known then
        costSeg:SetWidth(width)
        missSeg:SetWidth(width)
    end
    costSeg:SetShown(shown and true or false)
    tick:SetShown(shown and true or false)
    missSeg:SetShown(missing and true or false)
    missTick:SetShown(missing and true or false)
end

local function Text(cur, max)
    local format = S.Get("text")
    if format == "both" or format == "values" then
        left:SetFormattedText(TEXT_VALUES, cur, max)
    elseif format == "current" then
        left:SetFormattedText(TEXT_CURRENT, cur)
    else
        left:SetText("")
    end
    if format == "both" or format == "percent" then
        right:SetFormattedText(TEXT_PERCENT, Percent())
    else
        right:SetText("")
    end
end

local function Values()
    local cur, max = UnitPower(PLAYER, MANA), UnitPowerMax(PLAYER, MANA)
    bar:SetMinMaxValues(0, max)
    bar:SetValue(cur)
    Text(cur, max)
    local readable = Readable(cur) and Readable(max)
    local shifting = S.Get("powershift") and cost ~= nil
    if shifting and S.Get("shiftsLeft") and readable then
        local n = math.floor(cur / cost)
        if n == 1 then info:SetText(TEXT_SHIFT) else info:SetFormattedText(TEXT_SHIFTS, n) end
    else
        info:SetText("")
    end
    local sparking = S.Get("fiveSecond") and S.Get("regenSpark") and not inFive and not (readable and cur >= max)
    spark:SetShown(sparking and true or false)
    if not sparking then
        spark.pulse:Stop()
    elseif not spark.pulse:IsPlaying() then
        spark.pulse:Play()
    end
end

local function SetEvents(list, on)
    for _, event in ipairs(list) do
        if event:find("^UNIT_") then
            if on then events:RegisterUnitEvent(event, PLAYER) else events:UnregisterEvent(event) end
        elseif on then
            events:RegisterEvent(event)
        else
            events:UnregisterEvent(event)
        end
    end
end

local function Refresh()
    local show = Wanted()
    holder:SetShown(show)
    SetEvents(SHOWN_EVENTS, show)
    if not show then return end
    cost = FormCost()
    PlaceCost()
    line:SetShown(S.Get("fiveSecond") and S.Get("fiveLine") and true or false)
    countdown:SetShown(S.Get("fiveSecond") and S.Get("fiveCountdown") and true or false)
    Values()
end

local function EndFive()
    fiveTimer, inFive = nil, false
    line:Stop()
    if holder:IsShown() then Values() end
end

local function StartFive()
    if fiveTimer then fiveTimer:Cancel() end
    inFive = true
    line:Run(GetTime(), FIVE_SECONDS)
    fiveTimer = C_Timer.NewTimer(FIVE_SECONDS, EndFive)
    if holder:IsShown() then Values() end
end

local function OnMana()
    local cur = UnitPower(PLAYER, MANA)
    local spent = Readable(cur) and lastMana and cur < lastMana
    lastMana = Readable(cur) and cur or nil
    if spent and S.Get("fiveSecond") then
        StartFive()
    elseif holder:IsShown() then
        Values()
    end
end

local function OnSpellcast(spellID)
    if S.Get("fiveSecond") and not Readable(UnitPower(PLAYER, MANA)) and ManaCost(spellID) then StartFive() end
end

local function Stop()
    events:UnregisterAllEvents()
    if fiveTimer then fiveTimer:Cancel() end
    fiveTimer, inFive, lastMana = nil, false, nil
    if not holder then return end
    line:Stop()
    holder:Hide()
    holder.mover:Hide()
end

local function Apply()
    unlocked = unlockActive and DM.On()
    if not DM.On() then return Stop() end
    if not holder then Build() end
    SetEvents(BASE_EVENTS, true)
    local mana = UnitPower(PLAYER, MANA)
    lastMana = Readable(mana) and mana or nil
    inCombat = UnitAffectingCombat(PLAYER) == true
    Style()
    Place()
    holder.mover:SetShown(unlocked == true)
    Refresh()
end

local function OnEvent(_, event, ...)
    if event == "UNIT_POWER_UPDATE" then
        local kind = select(2, ...)
        if Readable(kind) and kind == MANA_TOKEN then OnMana() end
    elseif event == "UNIT_MAXPOWER" then
        PlaceCost()
        Values()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnSpellcast(select(3, ...))
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        Refresh()
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        if pendingPlace then Place() end
        Refresh()
    else
        Refresh()
    end
end

local function ApplyNow()
    pendingApply = false
    Apply()
end

local function OnSet(key)
    if key == "druidManaPos" or pendingApply then return end
    pendingApply = true
    C_Timer.After(0, ApplyNow)
end

local function OnUnlock()
    unlockActive = true
    Apply()
end

local function OnLock()
    unlockActive = false
    Apply()
end

function DM.Frame()
    return holder
end

events:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", OnUnlock)
hooksecurefunc(ns, "HideUnlockMode", OnLock)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

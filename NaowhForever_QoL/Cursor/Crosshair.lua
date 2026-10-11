-- Crosshair.lua: the Crosshair at the middle of the screen, recoloured out of melee range, and its card.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local UI = ns.UI
local T = ns.THEME

local BAR = "Interface\\Buttons\\WHITE8x8"
local RING = "Interface\\AddOns\\NaowhForever_QoL\\Media\\crosshair_ring.tga"
local RING_TEXELS = 512
local TEXEL_HALF = 0.5 / RING_TEXELS
local PI, sin, cos = math.pi, math.sin, math.cos
local TICK = 0.05
local SPAN_PAD = 2
local FRAME_LEVEL = 50
local ROUND = ns.QoLConstants.ROUND

local CAT_FORM, BEAR_FORM, DIRE_BEAR_FORM = 1, 5, 8
local CLAW, MAUL = 1082, 6807
local MELEE = { WARRIOR = 1715, ROGUE = 1752, HUNTER = 2973, SHAMAN = 17364, PALADIN = 679 }
local DRUID_MELEE = { [CAT_FORM] = CLAW, [BEAR_FORM] = MAUL, [DIRE_BEAR_FORM] = MAUL }
local EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_TARGET_CHANGED", "UPDATE_SHAPESHIFT_FORM",
    "SPELLS_CHANGED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }

local PREVIEW_FIT = ns.QoLConstants.CURSOR_PREVIEW_FIT
local STAGE_H = 170
local PREVIEW_Y = ns.QoLConstants.CURSOR_PREVIEW_Y
local NOTE_Y, NOTE_SIZE = ns.Shared.Style.STAGE_NOTE_Y, ns.Shared.Style.STAGE_NOTE_SIZE
local DOT_RANGE, OPACITY_RANGE = ns.QoLConstants.DOT_RANGE, ns.QoLConstants.OPACITY_RANGE
local SOUND_REPEAT_RANGE = ns.QoLConstants.SOUND_REPEAT_RANGE
local PERCENT_SCALE = ns.Shared.Style.PERCENT_SCALE
local ARM_RANGE, THICKNESS_RANGE, GAP_RANGE = { 4, 100, 1 }, { 1, 20, 1 }, { 0, 50, 1 }
local CIRCLE_RANGE, OUTLINE_RANGE, OFFSET_RANGE = { 10, 200, 1 }, { 1, 5, 1 }, { -500, 500, 1 }
local STATES = {
    { key = "inRange", label = "In Range", tip = "No target, or your target in melee range: the crosshair in its own colors." },
    { key = "outOfRange", label = "Out of Range", tip = "Your target out of melee range.", needs = "crossMelee" },
}
local SUMMARY_ONE, SUMMARY = ns.L("%d arm%s%s%s"), ns.L("%d arms%s%s%s")
local WITH_DOT, WITH_CIRCLE, COMBAT_ONLY = ns.L(", dot"), ns.L(", circle"), ns.L(", in combat only")

local ARMS = {
    { key = "crossTop", base = 0 },
    { key = "crossRight", base = PI / 2 },
    { key = "crossBottom", base = PI },
    { key = "crossLeft", base = 3 * PI / 2 },
}

local frame, parts
local inCombat, outOfMelee, lastInRange = false, false, nil
local alarmTicker, tickAcc = nil, 0
local ticker = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and S.Get("crosshair")
end

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

local function Color(key, classKey)
    if classKey and S.Get(classKey) then return RAID_CLASS_COLORS[select(2, UnitClass("player"))] end
    return S.Get(key)
end

local function MeleeSpell()
    local own = S.Get("crossMeleeSpell")
    if own > 0 then return own end
    local _, class = UnitClass("player")
    if class == "DRUID" then return DRUID_MELEE[GetShapeshiftFormID()] end
    local id = MELEE[class]
    return id and C_SpellBook.IsSpellKnown(id) and id or nil
end
ns.MeleeRangeSpell = MeleeSpell

local function Texture(f, layer, sub, path)
    local t = f:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(path, "CLAMP", "CLAMP", "TRILINEAR")
    if path == RING then
        t:SetTexCoord(TEXEL_HALF, 1 - TEXEL_HALF, TEXEL_HALF, 1 - TEXEL_HALF)
        t:SetSnapToPixelGrid(false)
        t:SetTexelSnappingBias(0)
    end
    return t
end

local Look = {}

function Look.New(f)
    local p = { arms = {}, shadows = {} }
    for i = 1, #ARMS do
        p.shadows[i] = Texture(f, "ARTWORK", 0, BAR)
        p.arms[i] = Texture(f, "ARTWORK", 1, BAR)
    end
    p.dotShadow, p.dot = Texture(f, "ARTWORK", 0, BAR), Texture(f, "ARTWORK", 1, BAR)
    p.ringShadow, p.ring = Texture(f, "ARTWORK", 0, RING), Texture(f, "ARTWORK", 1, RING)
    return p
end

local function Place(f, tex, shadow, w, h, x, y, angle, c, outline, ow, alpha)
    tex:SetSize(w, h)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", f, "BOTTOMLEFT", x, y)
    tex:SetRotation(angle)
    tex:SetVertexColor(c.r, c.g, c.b, alpha)
    tex:Show()
    if outline then
        shadow:SetSize(w + ow * 2, h + ow * 2)
        shadow:ClearAllPoints()
        shadow:SetPoint("CENTER", f, "BOTTOMLEFT", x, y)
        shadow:SetRotation(angle)
        shadow:SetVertexColor(outline.r, outline.g, outline.b, alpha)
        shadow:Show()
    else
        shadow:Hide()
    end
end

local function PaintArms(f, p, span, color, outline, ow, alpha)
    local size, thick, gap = S.Get("crossSize"), S.Get("crossThickness"), S.Get("crossGap")
    for i, def in ipairs(ARMS) do
        if S.Get(def.key) then
            local dist = gap + size / 2
            Place(f, p.arms[i], p.shadows[i], thick, size, span + dist * sin(def.base),
                span + dist * cos(def.base), -def.base, color, outline, ow, alpha)
        else
            p.arms[i]:Hide()
            p.shadows[i]:Hide()
        end
    end
end

local function PaintRound(f, tex, shadow, key, sizeKey, span, color, outline, ow, alpha)
    if not S.Get(key) then
        tex:Hide()
        shadow:Hide()
        return
    end
    local size = S.Get(sizeKey)
    Place(f, tex, shadow, size, size, span, span, 0, color, outline, ow, alpha)
end

function Look.Paint(f, p, out)
    local alpha = S.Get("crossOpacity")
    local base = Color("crossColor", "crossClassColor")
    local outline = S.Get("crossOutline") and S.Get("crossOutlineColor") or nil
    local ow = S.Get("crossOutlineWeight")
    local melee = S.Get("crossMelee") and out
    local meleeColor = S.Get("crossMeleeColor")
    if melee and S.Get("crossMeleeBorder") then outline = meleeColor end

    local span = S.Get("crossGap") + S.Get("crossSize") + (outline and ow or 0) + SPAN_PAD
    f:SetSize(span * 2, span * 2)

    PaintArms(f, p, span, melee and S.Get("crossMeleeArms") and meleeColor or base, outline, ow, alpha)
    PaintRound(f, p.dot, p.dotShadow, "crossDot", "crossDotSize", span,
        melee and S.Get("crossMeleeDot") and meleeColor or base, outline, ow, alpha)
    PaintRound(f, p.ring, p.ringShadow, "crossCircle", "crossCircleSize", span,
        melee and S.Get("crossMeleeCircle") and meleeColor or S.Get("crossCircleColor"), outline, ow, alpha)
    return span
end

local function Build()
    frame = CreateFrame("Frame", "NaowhForeverCrosshair", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(FRAME_LEVEL)
    frame:EnableMouse(false)
    parts = Look.New(frame)
end

local function Layout()
    Look.Paint(frame, parts, outOfMelee)
    local scale = UIParent:GetEffectiveScale()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER",
        math.floor(S.Get("crossX") * scale + ROUND) / scale, math.floor(S.Get("crossY") * scale + ROUND) / scale)
end

local function Visible()
    if S.Get("crossCombatOnly") and not inCombat then return false end
    return not (S.Get("crossHideMounted") and IsMounted())
end

local function PlayAlarm()
    UI._PlayLSMSound(UI.SoundPathFor(S.Get("crossMeleeSoundKey")))
end

local function StopAlarm()
    if alarmTicker then
        alarmTicker:Cancel()
        alarmTicker = nil
    end
end

local function StartAlarm()
    StopAlarm()
    PlayAlarm()
    local every = S.Get("crossMeleeSoundInterval")
    if every > 0 then alarmTicker = C_Timer.NewTicker(every, PlayAlarm) end
end

local function SetOutOfMelee(out)
    if out == outOfMelee then return end
    outOfMelee = out
    Layout()
end

local function HasTarget()
    return UnitExists("target") and UnitCanAttack("player", "target")
        and not UnitIsDeadOrGhost("target")
end

local spell

local function Tick(_, elapsed)
    tickAcc = tickAcc + elapsed
    if tickAcc < TICK then return end
    tickAcc = 0
    local inRange = C_Spell.IsSpellInRange(spell, "target")
    if inRange == nil or Secret(inRange) then return end
    if not inRange and lastInRange == true and S.Get("crossMeleeSound") then StartAlarm() end
    if inRange then StopAlarm() end
    lastInRange = inRange
    SetOutOfMelee(not inRange)
end

local function EvaluateMelee()
    spell = MeleeSpell()
    if On() and S.Get("crossMelee") and spell and HasTarget() then
        ticker:SetScript("OnUpdate", Tick)
        if not S.Get("crossMeleeSound") then StopAlarm() end
    else
        ticker:SetScript("OnUpdate", nil)
        StopAlarm()
        lastInRange = nil
        if frame then SetOutOfMelee(false) end
    end
end

local function OnTargetChanged()
    lastInRange = nil
    StopAlarm()
    SetOutOfMelee(false)
    EvaluateMelee()
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    elseif event == "PLAYER_TARGET_CHANGED" then
        OnTargetChanged()
        return
    elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "SPELLS_CHANGED" then
        EvaluateMelee()
        return
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        Layout()
    end
    frame:SetShown(Visible())
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", OnEvent)

local function Apply()
    events:UnregisterAllEvents()
    if not On() then
        if frame then frame:Hide() end
        EvaluateMelee()
        return
    end
    if not frame then Build() end
    inCombat = UnitAffectingCombat("player")
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    Layout()
    frame:SetShown(Visible())
    EvaluateMelee()
end

local function OnSettingChanged(key)
    if key == "enabled" or key:find("^cross") then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Group = ns.Shared.Settings.Group

local function OwnColour() return not S.Get("crossClassColor") end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.shape = CreateFrame("Frame", nil, preview)
    preview.shape:SetPoint("CENTER", 0, PREVIEW_Y)
    preview.parts = Look.New(preview.shape)
    preview.note = preview:CreateFontString(nil, "OVERLAY")
    preview.note:SetPoint("BOTTOM", 0, NOTE_Y)
    preview.note:SetFont(ns.UIFontPath(), NOTE_SIZE, "")
    preview.note:SetTextColor(T.muted.r, T.muted.g, T.muted.b, 1)
    return preview
end

local function PaintPreview(preview, state)
    local out = state == "outOfRange"
    local span = Look.Paint(preview.shape, preview.parts, out)
    preview.shape:SetScale(math.min(1, PREVIEW_FIT / math.max(1, span * 2)))
    preview.note:SetText("")
end

local function Summary(store)
    local arms = 0
    for _, def in ipairs(ARMS) do
        if store.Get(def.key) then arms = arms + 1 end
    end
    return (arms == 1 and SUMMARY_ONE or SUMMARY):format(arms, store.Get("crossDot") and WITH_DOT or "",
        store.Get("crossCircle") and WITH_CIRCLE or "", store.Get("crossCombatOnly") and COMBAT_ONLY or "")
end

ns.Shared.Settings.Page("QoL/Cursor & Crosshair", S):Card({
    id = "crosshair", name = "Crosshair", order = 10, switch = "crosshair", collapsed = true,
    help = "A crosshair at the middle of your screen.",
    summary = Summary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        Group("When"),
        { key = "crossCombatOnly", label = "Only In Combat", toggle = true },
        { key = "crossHideMounted", label = "Hide While Mounted", toggle = true },
        Group("Shape"),
        { key = "crossTop", label = "Top Arm", toggle = true },
        { key = "crossRight", label = "Right Arm", toggle = true },
        { key = "crossBottom", label = "Bottom Arm", toggle = true },
        { key = "crossLeft", label = "Left Arm", toggle = true },
        { key = "crossSize", label = "Arm Length", slider = ARM_RANGE },
        { key = "crossThickness", label = "Thickness", slider = THICKNESS_RANGE },
        { key = "crossGap", label = "Gap", slider = GAP_RANGE, wide = true,
          help = "Space between the middle and each arm." },
        { key = "crossDot", label = "Centre Dot", toggle = true },
        { key = "crossDotSize", label = "Dot Size", slider = DOT_RANGE, needs = "crossDot" },
        { key = "crossCircle", label = "Circle", toggle = true },
        { key = "crossCircleSize", label = "Circle Size", slider = CIRCLE_RANGE, needs = "crossCircle" },
        Group("Color"),
        { key = "crossClassColor", label = "Class Color", toggle = true },
        { key = "crossColor", label = "Color", colour = true, needs = OwnColour, why = "Class color is on" },
        { key = "crossCircleColor", label = "Circle Color", colour = true, needs = "crossCircle" },
        { key = "crossOpacity", label = "Opacity", slider = OPACITY_RANGE, unit = "%", scale = PERCENT_SCALE },
        Group("Outline"),
        { key = "crossOutline", label = "Outline", toggle = true },
        { key = "crossOutlineWeight", label = "Outline Width", slider = OUTLINE_RANGE, needs = "crossOutline" },
        { key = "crossOutlineColor", label = "Outline Color", colour = true, needs = "crossOutline" },
        Group("Position"),
        { key = "crossX", label = "X Offset", slider = OFFSET_RANGE },
        { key = "crossY", label = "Y Offset", slider = OFFSET_RANGE },
        Group("Out of Melee Range"),
        { key = "crossMelee", label = "Recolour Out of Melee Range", toggle = true,
          help = "Changes color while your target is out of melee range. Warriors, rogues, hunters "
              .. "(Raptor Strike), shamans with Stormstrike, and druids in Cat or Bear Form have "
              .. "an ability it can check; anyone else can set a spell ID below." },
        { key = "crossMeleeColor", label = "Out of Range Color", colour = true, needs = "crossMelee" },
        { key = "crossMeleeBorder", label = "Recolour Outline", toggle = true, needs = "crossMelee" },
        { key = "crossMeleeArms", label = "Recolour Arms", toggle = true, needs = "crossMelee" },
        { key = "crossMeleeDot", label = "Recolour Dot", toggle = true, needs = "crossMelee" },
        { key = "crossMeleeCircle", label = "Recolour Circle", toggle = true, needs = "crossMelee" },
        { key = "crossMeleeSound", label = "Play a Sound", toggle = true, needs = "crossMelee",
          help = "Plays as your target leaves melee range." },
        { key = "crossMeleeSoundKey", label = "Sound", sound = true, needs = { "crossMelee", "crossMeleeSound" } },
        { key = "crossMeleeSoundInterval", label = "Repeat Every (s)", slider = SOUND_REPEAT_RANGE,
          needs = { "crossMelee", "crossMeleeSound" },
          help = "Plays the sound again this often while out of range. 0 plays it once." },
        { key = "crossMeleeSpell", label = "Melee Spell ID", text = true, wide = true, always = true,
          help = "Spell ID to check melee range with. 0 uses your class's own. The mouse ring's "
              .. "melee check uses it too.",
          get = function() return tostring(S.Get("crossMeleeSpell")) end,
          set = function(v) S.Set("crossMeleeSpell", tonumber(v) or 0) end },
    },
})

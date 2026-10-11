-- CursorCooldown.lua: Cooldown at Cursor, a card by the mouse when you press something still on cooldown.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME

local PAD = 4
local GAP = 7
local BORDER = 1
local ICON_CROP = ns.QoLConstants.ICON_CROP
local SWIPE_ALPHA = 0.5
local CARD_ALPHA = 0.94
local NAME_SIZE, TIME_SIZE = 0.42, 0.5
local MIN_NAME, MIN_TIME = 10, 11
local MIN_TEXT_WIDTH = 64
local CURSOR_OFFSET = 18
local MATCH_WINDOW = 0.3
local POP_TIME, POP_FROM = 0.12, 0.85
local FADE_TIME = 0.25
local BLACK = { r = 0, g = 0, b = 0 }
local TEXT_NUDGE = 1
local TIME_UNITS = 2
local ROUND = ns.QoLConstants.ROUND
local SIZE_RANGE, TIME_RANGE = { 24, 72, 1 }, { 0.5, 4, 0.25 }
local SUMMARY = ns.L("%d px, %.2gs")

local COOLDOWN_ERRORS = {}
for _, name in ipairs({ "ERR_SPELL_COOLDOWN", "ERR_ABILITY_COOLDOWN", "ERR_ITEM_COOLDOWN" }) do
    if _G[name] then COOLDOWN_ERRORS[_G[name]] = true end
end

local issecretvalue = issecretvalue
local card, binding, hooked, active
local pressedSlot, pressedAt, erroredAt = nil, 0, 0
local hideAt = 0
local lastX, lastY

local function On()
    return S.Get("enabled") and S.Get("cursorCooldown")
end

local function Readable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local function TimeFormatter()
    local formatter = C_StringUtil.CreateSecondsFormatter()
    formatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
    formatter:SetStripIntervalWhitespace(Enum.SecondsFormatterIntervalWhitespace.Strip)
    formatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
    formatter:SetRounding(Enum.SecondsFormatterRounding.Truncate)
    formatter:SetCanRoundUpLastUnit(true)
    formatter:SetDesiredUnitCount(TIME_UNITS)
    return formatter
end

local function ActionName(slot)
    local kind, id = GetActionInfo(slot)
    if not (Readable(kind) and Readable(id)) then return nil end
    if kind == "spell" then return C_Spell.GetSpellName(id) end
    if kind == "item" then return C_Item.GetItemNameByID(id) end
    if kind == "macro" then
        local spell = GetMacroSpell(id)
        if Readable(spell) then return C_Spell.GetSpellName(spell) end
    end
    local text = GetActionText(slot)
    if Readable(text) then return text end
end

local function Stop()
    card:SetScript("OnUpdate", nil)
    card:Hide()
    binding:SetEnabled(false)
end

local function FollowCursor(self)
    local x, y = GetCursorPosition()
    if x ~= lastX or y ~= lastY then
        lastX, lastY = x, y
        local scale = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x / scale + CURSOR_OFFSET, y / scale)
    end
    local left = hideAt - GetTime()
    if left <= 0 then
        Stop()
    elseif left < FADE_TIME then
        self:SetAlpha(left / FADE_TIME)
    end
end

local function BuildIcon()
    card.iconFrame = CreateFrame("Frame", nil, card)
    card.iconFrame:SetPoint("LEFT", PAD, 0)
    ns.Solid(card.iconFrame, "BACKGROUND", BLACK, 1):SetAllPoints()
    card.icon = card.iconFrame:CreateTexture(nil, "ARTWORK")
    card.icon:SetPoint("TOPLEFT", BORDER, -BORDER)
    card.icon:SetPoint("BOTTOMRIGHT", -BORDER, BORDER)
    card.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    card.swipe = CreateFrame("Cooldown", nil, card.iconFrame, "CooldownFrameTemplate")
    card.swipe:SetAllPoints(card.icon)
    card.swipe:SetDrawEdge(false)
    card.swipe:SetHideCountdownNumbers(true)
    card.swipe:SetSwipeColor(BLACK.r, BLACK.g, BLACK.b, SWIPE_ALPHA)
end

local function BuildText()
    card.name = ns.Font(card, MIN_NAME, nil, T.fg)
    card.name:SetPoint("BOTTOMLEFT", card.iconFrame, "RIGHT", GAP, TEXT_NUDGE)
    card.name:SetJustifyH("LEFT")
    card.name:SetWordWrap(false)
    card.time = ns.Font(card, MIN_TIME, nil, T.accentSoft)
    card.time:SetPoint("TOPLEFT", card.iconFrame, "RIGHT", GAP, -TEXT_NUDGE)
    card.time:SetJustifyH("LEFT")
end

local function BuildPop()
    card.pop = card:CreateAnimationGroup()
    local grow = card.pop:CreateAnimation("Scale")
    grow:SetScaleFrom(POP_FROM, POP_FROM)
    grow:SetScaleTo(1, 1)
    grow:SetDuration(POP_TIME)
    grow:SetSmoothing("OUT")
end

local function BuildBinding()
    binding = C_DurationUtil.CreateDurationTextBinding()
    binding:SetToDefaults()
    binding:SetFormatter(TimeFormatter())
    binding:SetFontString(card.time)
    binding:SetEnabled(false)
end

local function Build()
    card = CreateFrame("Frame", "NaowhForeverCursorCooldown", UIParent)
    card:SetFrameStrata("TOOLTIP")
    card:EnableMouse(false)
    ns.Solid(card, "BACKGROUND", T.panel, CARD_ALPHA):SetAllPoints()
    ns.Border(card, BLACK)
    BuildIcon()
    BuildText()
    BuildPop()
    BuildBinding()
    card:Hide()
end

local function Style()
    local size = S.Get("cursorCooldownSize")
    card.iconFrame:SetSize(size, size)
    card.name:SetFont(ns.UIFontPath(), math.max(MIN_NAME, math.floor(size * NAME_SIZE + ROUND)), "")
    card.time:SetFont(ns.UIFontPath(), math.max(MIN_TIME, math.floor(size * TIME_SIZE + ROUND)), "")
    card:SetHeight(size + PAD * 2)
end

local function Fit()
    local textWidth = math.max(MIN_TEXT_WIDTH, math.ceil(card.name:GetStringWidth()))
    card:SetWidth(PAD + card.iconFrame:GetWidth() + GAP + textWidth + PAD * 2)
end

local function Show(slot)
    local cooldown = C_ActionBar.GetActionCooldown(slot)
    if not (cooldown and cooldown.isActive) or cooldown.isOnGCD then return end
    local texture = GetActionTexture(slot)
    if not texture then return end
    local duration = C_ActionBar.GetActionCooldownDuration(slot, true)
    if not duration then return end
    card.icon:SetTexture(texture)
    card.name:SetText(ActionName(slot) or "")
    card.swipe:SetCooldownFromDurationObject(duration)
    binding:SetDuration(duration)
    binding:SetEnabled(true)
    Fit()
    hideAt = GetTime() + S.Get("cursorCooldownTime")
    card:SetAlpha(1)
    card:Show()
    card.pop:Restart()
    lastX, lastY = nil, nil
    FollowCursor(card)
    card:SetScript("OnUpdate", FollowCursor)
end

local function Match()
    if pressedSlot and math.abs(pressedAt - erroredAt) <= MATCH_WINDOW then
        local slot = pressedSlot
        pressedSlot, erroredAt = nil, 0
        Show(slot)
    end
end

local function OnUseAction(slot)
    if not active or type(slot) ~= "number" then return end
    pressedSlot, pressedAt = slot, GetTime()
    Match()
end

local function OnErrorMessage(_, _, _, message)
    if not COOLDOWN_ERRORS[message] then return end
    erroredAt = GetTime()
    Match()
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", OnErrorMessage)

local function Apply()
    active = On() == true
    if not active then
        events:UnregisterAllEvents()
        pressedSlot = nil
        if card then Stop() end
        return
    end
    if not card then Build() end
    if not hooked then
        hooked = true
        hooksecurefunc("UseAction", OnUseAction)
    end
    Style()
    events:RegisterEvent("UI_ERROR_MESSAGE")
end

local function OnSettingChanged(key)
    if key == "enabled" or key:find("^cursorCooldown") then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local Settings = ns.Shared.Settings

local function Summary(store)
    return SUMMARY:format(store.Get("cursorCooldownSize"), store.Get("cursorCooldownTime"))
end

Settings.Page("QoL/Cursor & Crosshair", S):Card({
    id = "cursorCooldown", name = "Cooldown at Cursor", order = 40, switch = "cursorCooldown",
    help = "Press something still on cooldown and its icon, name and time left show by your mouse.",
    summary = Summary,
    rows = {
        { key = "cursorCooldownSize", label = "Icon Size", slider = SIZE_RANGE },
        { key = "cursorCooldownTime", label = "Shown For", slider = TIME_RANGE, unit = "s" },
    },
})

-- XPBar.lua: the QoL XP bar with quest XP and rested on it, the texts around it, and its settings card.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local Played = ns.Shared.Played
local Parts = ns.Shared.Parts

local MINUTE, HOUR = ns.QoLConstants.SECONDS_PER_MINUTE, ns.QoLConstants.SECONDS_PER_HOUR
local DAY, HOURS_PER_DAY, MINUTES_PER_HOUR = ns.QoLConstants.SECONDS_PER_DAY, 24, 60
local THOUSAND, MILLION = ns.QoLConstants.THOUSAND, ns.QoLConstants.MILLION
local PERCENT = ns.QoLConstants.PERCENT
local MIN_RATE_TIME = 60
local MIN_WIDTH = 400
local SIDE_GAP, SLOT_DROP = 6, 4
local TEXT_GAP = 8
local SLOT_FONT_MIN = 8
local INSIDE_INSET = 8
local INSIDE_SHARE, INSIDE_MIN, INSIDE_SIZE = 0.55, 10, 14
local RESTED_MIN_W = 3
local HIDDEN_BELOW = 0.5
local TRACK_RAISE, EDGE_RAISE, TEXT_RAISE = 1, 4, 5
local QUEST_SCAN_DELAY = 0.3
local CLOCK_TICK = 1
local DEFAULT_Y = 190
local MENU_DROP = 2
local TOP_LEFT, TOP, TOP_RIGHT, LEFT, RIGHT, BOTTOM_LEFT, BOTTOM, BOTTOM_RIGHT = 1, 2, 3, 4, 5, 6, 7, 8
local BESIDE = { LEFT, RIGHT }
local SAME_TEXT = { levelshort = "level", levelnum = "level" }
local BLIZZARD_BARS = { "MainMenuExpBar", "ExhaustionTick" }
local EVENTS = { "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING",
    "QUEST_LOG_UPDATE", "DISABLE_XP_GAIN", "ENABLE_XP_GAIN", "PLAYER_LOGOUT", "MODIFIER_STATE_CHANGED",
    "PLAYER_ENTERING_WORLD", "QUEST_TURNED_IN" }
local PVP_INSTANCES = { pvp = true, arena = true }
local SLOTS = {
    { key = "xpBarTopLeft", label = "Top Left", point = "BOTTOMLEFT", rel = "TOPLEFT", y = SLOT_DROP,
      justify = "LEFT" },
    { key = "xpBarTop", label = "Top", point = "BOTTOM", rel = "TOP", y = SLOT_DROP,
      justify = "CENTER" },
    { key = "xpBarTopRight", label = "Top Right", point = "BOTTOMRIGHT", rel = "TOPRIGHT", y = SLOT_DROP,
      justify = "RIGHT" },
    { key = "xpBarLeft", label = "Left", point = "RIGHT", rel = "LEFT", x = -SIDE_GAP, y = 0,
      justify = "RIGHT" },
    { key = "xpBarRight", label = "Right", point = "LEFT", rel = "RIGHT", x = SIDE_GAP, y = 0,
      justify = "LEFT" },
    { key = "xpBarBottomLeft", label = "Bottom Left", point = "TOPLEFT", rel = "BOTTOMLEFT", y = -SLOT_DROP,
      justify = "LEFT" },
    { key = "xpBarBottom", label = "Bottom", point = "TOP", rel = "BOTTOM", y = -SLOT_DROP,
      justify = "CENTER" },
    { key = "xpBarBottomRight", label = "Bottom Right", point = "TOPRIGHT", rel = "BOTTOMRIGHT",
      y = -SLOT_DROP, justify = "RIGHT" },
}
local INSIDE = {
    { key = "xpBarLeftText", label = "Left Text", point = "LEFT", dir = 1, justify = "LEFT" },
    { key = "xpBarCenterText", label = "Center Text", point = "CENTER", dir = 0, justify = "CENTER" },
    { key = "xpBarRightText", label = "Right Text", point = "RIGHT", dir = -1, justify = "RIGHT" },
}
local OLD_TEXTS = {
    { key = "xpBarPlayed", default = true, texts = { { "xpBarTopLeft", "played" } } },
    { key = "xpBarSession", default = false, texts = { { "xpBarTopRight", "session" } } },
    { key = "xpBarLeveling", default = true,
      texts = { { "xpBarBottomLeft", "leveling" }, { "xpBarBottomRight", "xphour" } } },
    { key = "xpBarCompleted", default = false,
      texts = { { "xpBarBottom", "completed" }, { "xpBarBottom", "rested" } } },
}
local BAR_TEXTS = {
    values = { none = "None", level = "Level", levelshort = "Level (Lvl 20)", levelnum = "Level (20)",
        xp = "Current / Max XP", percent = "XP Percent", rested = "Rested Percent" },
    order = { "none", "level", "levelshort", "levelnum", "xp", "percent", "rested" },
}
local HOVER_TEXTS = {
    values = { off = "Off", around = "Around the Bar", all = "All Texts" },
    order = { "off", "around", "all" },
}
local SLOT_TEXTS = {
    values = { none = "None", played = "Played Time", session = "Session Time",
        completed = "Completed Quests (%)", completedxp = "Completed Quests (XP)",
        rested = "Rested Experience", leveling = "Time to Level", xphour = "XP per Hour", pace = "Leveling Pace" },
    order = { "none", "played", "session", "completed", "completedxp", "rested", "pace", "leveling", "xphour" },
}
local TEXT = {
    PLAYED = ns.L("Played:|r "),
    THIS_LEVEL = ns.L("This Level:|r "),
    SESSION = ns.L("Session:|r "),
    COMPLETED = ns.L("Completed Quests:|r "),
    RESTED = ns.L("Rested:|r "),
    TO_LEVEL = ns.L("To Level:|r "),
    XP_HOUR = ns.L("XP/h:|r "),
    PACE = ns.L("%s to level at %s/h"),
    PART = "|r   ",
    PERCENT = "%.1f%%",
    DAYS = "%dd %dh",
    HOURS = "%dh %dm",
    MINUTES = "%dm",
    MILLIONS = "%.1fm",
    THOUSANDS = "%.1fk",
    LEVEL = ns.L("Level "),
    LVL = ns.L("Lvl "),
    MAX_LEVEL = ns.L("Max Level"),
    OF = " / ",
    RESTED_SHARE = ns.L("Rested %.1f%%"),
    RESET_COLORS = "Put the XP Bar colors back to their defaults?",
    RESET_LAYOUT = "Put the XP Bar's size and texts back to their defaults?",
    RESET_LAYOUT_LABEL = ns.L("Reset Size & Texts"),
    RESET_COLORS_LABEL = ns.L("Reset Colors"),
    MOVER = "XP Bar",
    PREVIEW_NOTE = ns.L("Click a text or a + to change what it shows. Right-click the bar to reset it."),
    ON = ns.L("(on "),
    CHANGE = ns.L("|nClick to change."),
    SUMMARY = "%d by %d%s%s",
    AT_MAX = ns.L(", shown at max level"),
    ON_HOVER = ns.L(", texts on mouseover"),
}

local FILL_FROM = CreateColor(0x00 / 255, 0x4f / 255, 0x85 / 255, 1)
local QUEST     = { r = 0xf2 / 255, g = 0xa9 / 255, b = 0x00 / 255 }
local RESTED    = { r = 0x1e / 255, g = 0x40 / 255, b = 0xaf / 255 }
local QUEST_HEX, RESTED_HEX = "|cfff2a900", "|cff6b8cff"
local OPEN_ALPHA = 0.4
local FX = ns.XPBarFX
local FLAT = ns.Shared.Style.WHITE
local EDGE = ns.Shared.Style.BORDER_RGB
local FILL_DARK = 0.55
local RESTED_DARK = 0.7
local HEIGHT_RANGE, WIDTH_RANGE = { 14, 48, 1 }, { MIN_WIDTH, 1200, 10 }
local THIRDS = 3
local PREVIEW_BAR_LEVEL, PREVIEW_ZONE_LEVEL = 2, 3

local COLOR_KEYS = { "xpBarFillColor", "xpBarQuestColor", "xpBarOpenColor", "xpBarRestedColor", "xpBarBgColor",
    "xpBarBorderColor" }
local questHex, restedHex = QUEST_HEX, RESTED_HEX

local function FillGradient()
    local c = S.Get("xpBarFillColor")
    if c then
        return CreateColor(c.r * FILL_DARK, c.g * FILL_DARK, c.b * FILL_DARK, 1), CreateColor(c.r, c.g, c.b, 1)
    end
    local shifted = ns.ThemeTint("accent", nil)
    local from = shifted and CreateColor(shifted.r * FILL_DARK, shifted.g * FILL_DARK, shifted.b * FILL_DARK, 1)
        or FILL_FROM
    return from, CreateColor(T.accent.r, T.accent.g, T.accent.b, 1)
end

local function QuestDefault()
    return ns.ThemeTint("accentSoft", QUEST)
end

local function RestedDefault()
    local shifted = ns.ThemeTint("accent", nil)
    return shifted and { r = shifted.r * RESTED_DARK, g = shifted.g * RESTED_DARK, b = shifted.b * RESTED_DARK }
        or RESTED
end

local function BorderDefault()
    return ns.ThemeTint("line", EDGE)
end

local function OpenDefault()
    local q = S.Get("xpBarQuestColor") or QuestDefault()
    local bg = S.Get("xpBarBgColor") or T.bg
    return { r = q.r * OPEN_ALPHA + bg.r * (1 - OPEN_ALPHA), g = q.g * OPEN_ALPHA + bg.g * (1 - OPEN_ALPHA),
        b = q.b * OPEN_ALPHA + bg.b * (1 - OPEN_ALPHA) }
end

local function PaintBar(b)
    local tex = ns.UI.TexturePath(S.Get("xpBarTexture"), FLAT)
    b.fill:SetTexture(tex)
    b.fill:SetGradient("HORIZONTAL", FillGradient())
    local q = S.Get("xpBarQuestColor") or QuestDefault()
    local r = S.Get("xpBarRestedColor") or RestedDefault()
    local bg = S.Get("xpBarBgColor") or T.bg
    local e = S.Get("xpBarBorderColor") or BorderDefault()
    b.done:SetTexture(tex)
    b.done:SetVertexColor(q.r, q.g, q.b, 1)
    if b.open then
        local o = S.Get("xpBarOpenColor")
        b.open:SetTexture(tex)
        if o then
            b.open:SetVertexColor(o.r, o.g, o.b, 1)
        else
            b.open:SetVertexColor(q.r, q.g, q.b, OPEN_ALPHA)
        end
    end
    b.rested:SetTexture(tex)
    FX.Paint(b, q, r)
    b.bg:SetColorTexture(bg.r, bg.g, bg.b, S.Get("xpBarBgAlpha"))
    b.edge:SetColor(e.r, e.g, e.b, 1)
end

local function UpdateTextColors()
    local q, r = S.Get("xpBarQuestColor"), S.Get("xpBarRestedColor")
    if q then
        questHex = ns.Color(q)
    else
        questHex = ns.ThemeTint("accentSoft", nil) and ns.Color("accentSoft") or QUEST_HEX
    end
    if r then
        restedHex = ns.Color(r)
    else
        restedHex = ns.ThemeTint("accent", nil) and ns.Color("accent") or RESTED_HEX
    end
end

function ns.XPBarDefaultColor(key)
    if key == "xpBarFillColor" then return T.accent end
    if key == "xpBarQuestColor" then return QuestDefault() end
    if key == "xpBarOpenColor" then return OpenDefault() end
    if key == "xpBarRestedColor" then return RestedDefault() end
    if key == "xpBarBorderColor" then return BorderDefault() end
    return T.bg
end

function ns.XPBarColor(key)
    return S.Get(key) or ns.XPBarDefaultColor(key)
end

function ns.ResetXPBarColors()
    ns.Confirm(TEXT.RESET_COLORS, function()
        local db = S.DB()
        for _, k in ipairs(COLOR_KEYS) do db[k] = nil end
        S.Set("xpBarFillColor", nil)
        ns.UI:RefreshPage(true)
    end)
end
ns.XPBarMinWidth = MIN_WIDTH

local bar, clock, unlocked, questTimer, inPvP, hovered
local sessionStart, sessionXP = nil, 0
local lastXP, lastXPMax
local questDone, questOpen = 0, 0


local function TextOf(which)
    return SAME_TEXT[which] or which
end

local function Claim(spots, key, which)
    if which == "none" then return end
    local db, text = S.DB(), TextOf(which)
    for _, spot in ipairs(spots) do
        if spot.key ~= key and TextOf(S.Get(spot.key)) == text then db[spot.key] = "none" end
    end
end

local function OneEach(spots)
    local db, seen = S.DB(), {}
    for _, spot in ipairs(spots) do
        local which = S.Get(spot.key)
        if which and which ~= "none" then
            local text = TextOf(which)
            if seen[text] then db[spot.key] = "none" else seen[text] = true end
        end
    end
end

local function On()
    return S.Get("enabled") and S.Get("xpBar")
end

local function InPvP()
    local _, kind = IsInInstance()
    return PVP_INSTANCES[kind] == true
end

local function AtMaxLevel()
    return UnitLevel("player") >= GetMaxLevelForPlayerExpansion() or IsXPUserDisabled()
end

local function Short(n)
    if n >= MILLION then return TEXT.MILLIONS:format(n / MILLION) end
    if n >= THOUSAND then return TEXT.THOUSANDS:format(n / THOUSAND) end
    return tostring(math.floor(n))
end

local function Grouped(n)
    n = math.floor(n)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
    return tostring(n)
end

local function Duration(seconds)
    seconds = math.max(0, math.floor(seconds))
    local d, h, m = math.floor(seconds / DAY), math.floor(seconds / HOUR) % HOURS_PER_DAY,
        math.floor(seconds / MINUTE) % MINUTES_PER_HOUR
    if d > 0 then return TEXT.DAYS:format(d, h) end
    if h > 0 then return TEXT.HOURS:format(h, m) end
    return TEXT.MINUTES:format(m)
end

local hideBlizzard = false
local hooked = {}

local function BlizzardBars()
    local manager = StatusTrackingBarManager
    if manager and manager.barContainers then return manager.barContainers end
    local list = {}
    for _, name in ipairs(BLIZZARD_BARS) do
        if _G[name] then list[#list + 1] = _G[name] end
    end
    return list
end

local function ShowsXP(frame)
    local enum = StatusTrackingBarInfo and StatusTrackingBarInfo.BarsEnum
    return frame.shownBarIndex == nil or not enum or frame.shownBarIndex == enum.Experience
end

local function Refresh(frame)
    frame:SetAlpha(hideBlizzard and ShowsXP(frame) and 0 or 1)
end

local function OnBlizzardShow(self)
    if hideBlizzard and ShowsXP(self) then Refresh(self) end
end

local function OnBlizzardPending(self)
    if hideBlizzard then Refresh(self) end
end

local function OnBlizzardUpdate(self)
    if hideBlizzard and self:GetAlpha() > 0 and ShowsXP(self) then self:SetAlpha(0) end
end

local function HookBlizzard(frame)
    if hooked[frame] then return end
    hooked[frame] = true
    frame:HookScript("OnShow", OnBlizzardShow)
    if frame.ApplyPendingBarToShow then
        hooksecurefunc(frame, "ApplyPendingBarToShow", OnBlizzardPending)
    end
    frame:HookScript("OnUpdate", OnBlizzardUpdate)
end

local function SetBlizzardHidden(hide)
    if hide == hideBlizzard then return end
    hideBlizzard = hide
    for _, frame in ipairs(BlizzardBars()) do
        HookBlizzard(frame)
        Refresh(frame)
    end
end

local function ScanQuests()
    questTimer = nil
    questDone, questOpen = 0, 0
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and GetQuestLogRewardXP) then return end
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden and info.questID then
            local xp = GetQuestLogRewardXP(info.questID) or 0
            if C_QuestLog.IsComplete(info.questID) then
                questDone = questDone + xp
            else
                questOpen = questOpen + xp
            end
        end
    end
end

local function SessionStore()
    local account = ns.AccountSettings()
    account.xpBarSessions = account.xpBarSessions or {}
    return account.xpBarSessions, UnitName("player") .. "-" .. GetRealmName()
end

local function SaveSession()
    local store, key = SessionStore()
    store[key] = sessionStart and { start = sessionStart, xp = sessionXP } or nil
end

local function LoadSession(isReload)
    local store, key = SessionStore()
    local saved = store[key]
    if isReload and saved and saved.start and not S.Get("xpBarResetOnReload") then
        sessionStart, sessionXP = saved.start, saved.xp or 0
    end
end

local function Segment(tex, from, width, total)
    local w = math.min(width, total - from)
    if w < HIDDEN_BELOW then tex:Hide() return from end
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", from, 0)
    tex:SetPoint("BOTTOMLEFT", from, 0)
    tex:SetWidth(w)
    tex:Show()
    return from + w
end

local function SlotText(which, maxed, max)
    local LABEL, VALUE = ns.Color("muted"), ns.Color("fg")
    local elapsed = time() - sessionStart
    if which == "played" then
        local total = Played.Total()
        if not total then return "" end
        return LABEL .. TEXT.PLAYED .. VALUE .. Duration(total) .. TEXT.PART
            .. LABEL .. TEXT.THIS_LEVEL .. VALUE .. Duration(Played.Level()) .. "|r"
    elseif which == "session" then
        return LABEL .. TEXT.SESSION .. VALUE .. Duration(elapsed) .. "|r"
    elseif maxed then
        return ""
    elseif which == "completed" then
        return LABEL .. TEXT.COMPLETED .. questHex .. TEXT.PERCENT:format(questDone / max * PERCENT) .. "|r"
    elseif which == "completedxp" then
        return LABEL .. TEXT.COMPLETED .. questHex .. Grouped(questDone) .. "|r"
    elseif which == "rested" then
        return LABEL .. TEXT.RESTED .. restedHex .. TEXT.PERCENT:format((GetXPExhaustion() or 0) / max * PERCENT) .. "|r"
    end
    local rate = sessionXP / (math.max(elapsed, MIN_RATE_TIME) / HOUR)
    if rate <= 0 then return "" end
    if which == "leveling" then
        local left = math.max(max - UnitXP("player"), 0)
        return LABEL .. TEXT.TO_LEVEL .. VALUE .. Duration(left / rate * HOUR) .. "|r"
    elseif which == "xphour" then
        return LABEL .. TEXT.XP_HOUR .. VALUE .. Short(rate) .. "|r"
    elseif which == "pace" then
        local left = math.max(max - UnitXP("player"), 0)
        return LABEL .. TEXT.PACE:format(VALUE .. Duration(left / rate * HOUR) .. "|r" .. LABEL,
            VALUE .. Short(rate) .. "|r" .. LABEL) .. "|r"
    end
    return ""
end

local function ConvertOldTexts()
    local db = S.DB()
    local saved = false
    for _, old in ipairs(OLD_TEXTS) do
        if db[old.key] ~= nil then saved = true end
    end
    if not saved then return end
    local picked = false
    for _, slot in ipairs(SLOTS) do
        if db[slot.key] ~= nil then picked = true end
    end
    if not picked then
        for _, slot in ipairs(SLOTS) do db[slot.key] = "none" end
        for _, old in ipairs(OLD_TEXTS) do
            local on = db[old.key]
            if on == nil then on = old.default end
            if on then
                for _, t in ipairs(old.texts) do
                    if db[t[1]] == "none" then db[t[1]] = t[2] end
                end
            end
        end
    end
    for _, old in ipairs(OLD_TEXTS) do db[old.key] = nil end
end

local function Natural(fs)
    local text = fs:GetText()
    if not text or text == "" then return 0 end
    local width = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
    return math.ceil(width) + 1
end

local function RowNeed(nl, nm, nr)
    local shown = (nl > 0 and 1 or 0) + (nm > 0 and 1 or 0) + (nr > 0 and 1 or 0)
    return nl + nm + nr + math.max(0, shown - 1) * TEXT_GAP
end

local function FitRow(w, left, mid, right, placeMid, midIndex)
    local nl, nr, nm = Natural(left), Natural(right), Natural(mid)
    if nm > 0 then
        if nl == 0 and nr == 0 then
            mid:SetWidth(math.max(1, w))
            placeMid(midIndex, 0)
        elseif RowNeed(nl, nm, nr) <= w then
            local from = nl > 0 and nl + TEXT_GAP or 0
            local to = w - (nr > 0 and nr + TEXT_GAP or 0)
            local centre = math.min(math.max(w / 2, from + nm / 2), to - nm / 2)
            mid:SetWidth(nm)
            placeMid(midIndex, centre - w / 2)
            left:SetWidth(math.max(1, centre - nm / 2 - TEXT_GAP))
            right:SetWidth(math.max(1, w - centre - nm / 2 - TEXT_GAP))
        else
            local third = math.max(1, w / THIRDS - TEXT_GAP)
            left:SetWidth(third)
            mid:SetWidth(third)
            right:SetWidth(third)
            placeMid(midIndex, 0)
        end
    elseif nl + nr + TEXT_GAP <= w then
        left:SetWidth(math.max(1, w - nr - TEXT_GAP))
        right:SetWidth(math.max(1, w - nl - TEXT_GAP))
    else
        left:SetWidth(math.max(1, w / 2 - TEXT_GAP))
        right:SetWidth(math.max(1, w / 2 - TEXT_GAP))
    end
end

local function AtFull(fs, base)
    return Natural(fs) * base / (fs._fitSize or base)
end

local function RowSize(w, left, mid, right, base)
    local need = RowNeed(AtFull(left, base), AtFull(mid, base), AtFull(right, base))
    if need <= w then return base end
    return math.max(SLOT_FONT_MIN, math.floor(base * w / need))
end

local function SetSlotSize(fs, size)
    local font, outline = S.Get("xpBarFont"), S.Get("xpBarOutline")
    if fs._fitSize == size and fs._fitFont == font and fs._fitOutline == outline then return end
    fs._fitSize, fs._fitFont, fs._fitOutline = size, font, outline
    Parts.HudFont(fs, font, size, outline)
end

local function FitSlotRow(slots, w, placeMid, base, l, m, r)
    local size = RowSize(w, slots[l], slots[m], slots[r], base)
    SetSlotSize(slots[l], size)
    SetSlotSize(slots[m], size)
    SetSlotSize(slots[r], size)
    FitRow(w, slots[l], slots[m], slots[r], placeMid, m)
end

local function FitSlots(slots, w, placeMid)
    local base = S.Get("xpBarFontSize")
    FitSlotRow(slots, w, placeMid, base, TOP_LEFT, TOP, TOP_RIGHT)
    FitSlotRow(slots, w, placeMid, base, BOTTOM_LEFT, BOTTOM, BOTTOM_RIGHT)
    for _, i in ipairs(BESIDE) do
        SetSlotSize(slots[i], base)
        slots[i]:SetWidth(math.max(1, Natural(slots[i])))
    end
end

local function InsideFont(h)
    return math.max(INSIDE_MIN, math.floor(h * INSIDE_SHARE))
end

local function FitInside(texts, w, h, placeMid)
    local row = w - INSIDE_INSET * 2
    local size = RowSize(row, texts[1], texts[2], texts[3], InsideFont(h))
    for _, fs in ipairs(texts) do SetSlotSize(fs, size) end
    FitRow(row, texts[1], texts[2], texts[3], placeMid, 2)
end

local function TextsChanged(list)
    local changed = false
    for i = 1, #list do
        local fs = list[i]
        local text = fs:GetText()
        if text ~= fs._fitText then
            fs._fitText = text
            changed = true
        end
    end
    return changed
end

local function InsideText(which, level, xp, max, maxed, pct, rested)
    if which == "level" then return TEXT.LEVEL .. level end
    if which == "levelshort" then return TEXT.LVL .. level end
    if which == "levelnum" then return tostring(level) end
    if which == "xp" then return maxed and TEXT.MAX_LEVEL or (xp .. TEXT.OF .. max) end
    if which == "percent" then return TEXT.PERCENT:format(pct) end
    if which == "rested" then return TEXT.RESTED_SHARE:format(rested / max * PERCENT) end
    return ""
end

local Look = {}

function Look.New(b)
    b.bg = ns.Solid(b, "BACKGROUND", T.bg)
    b.bg:SetAllPoints()

    b.track = CreateFrame("Frame", nil, b)
    b.track:SetAllPoints()
    b.track:SetClipsChildren(true)
    b.track:SetFrameLevel(b:GetFrameLevel() + TRACK_RAISE)
    b.fill = b.track:CreateTexture(nil, "ARTWORK")
    b.fill:SetTexture(FLAT)
    b.done = ns.Solid(b.track, "ARTWORK", QUEST, 1)
    b.open = ns.Solid(b.track, "ARTWORK", QUEST, OPEN_ALPHA)
    b.rested = ns.Solid(b.track, "ARTWORK", RESTED, 1)
    b.open:SetDrawLayer("ARTWORK", -1)
    b.rested:SetDrawLayer("ARTWORK", 0)
    b.done:SetDrawLayer("ARTWORK", 1)

    b.edge = ns.Border(b, EDGE)
    b.edge._frame:SetFrameLevel(b:GetFrameLevel() + EDGE_RAISE)

    local text = CreateFrame("Frame", nil, b)
    text:SetAllPoints()
    text:SetFrameLevel(b:GetFrameLevel() + TEXT_RAISE)
    b.text = text
    b.around = CreateFrame("Frame", nil, b)
    b.around:SetAllPoints()
    b.level = ns.Font(text, INSIDE_SIZE, "OUTLINE")
    b.level:SetPoint("LEFT", b.track, "LEFT", INSIDE_INSET, 0)
    b.level:SetJustifyH("LEFT")
    b.value = ns.Font(text, INSIDE_SIZE, "OUTLINE")
    b.value:SetPoint("CENTER", b.track, "CENTER")
    b.pct = ns.Font(text, INSIDE_SIZE, "OUTLINE")
    b.pct:SetPoint("RIGHT", b.track, "RIGHT", -INSIDE_INSET, 0)
    b.pct:SetJustifyH("RIGHT")
    b.inside = { b.level, b.value, b.pct }
    for _, fs in ipairs(b.inside) do fs:SetWordWrap(false) end
    b.placeInside = function(_, dx)
        b.value:ClearAllPoints()
        b.value:SetPoint("CENTER", b.track, "CENTER", dx, 0)
    end
    b.slots = {}
    for i, slot in ipairs(SLOTS) do
        local fs = ns.Font(b.around, S.Get("xpBarFontSize"), "OUTLINE")
        fs:SetPoint(slot.point, b, slot.rel, slot.x or 0, slot.y)
        fs:SetJustifyH(slot.justify)
        fs:SetWordWrap(false)
        b.slots[i] = fs
    end
    b.placeMid = function(i, dx)
        local fs, slot = b.slots[i], SLOTS[i]
        fs:ClearAllPoints()
        fs:SetPoint(slot.point, b, slot.rel, dx, slot.y)
    end
    FX.New(b)
end

function Look.Size(b, w, h)
    b:SetSize(w, h)
    FX.Size(b, w, h)
    for _, fs in ipairs(b.inside) do SetSlotSize(fs, InsideFont(h)) end
    b._fitW = nil
end

function Look.Segments(b, total, pct, done, open, rested, max, maxed)
    local x = Segment(b.fill, 0, total * pct / PERCENT, total)
    if maxed then
        b.done:Hide(); b.open:Hide(); b.rested:Hide()
        return FX.Segments(b, total, x, nil, false, 0)
    end
    local doneEnd = Segment(b.done, x, total * done / max, total)
    if S.Get("xpBarIncomplete") then
        Segment(b.open, doneEnd, total * open / max, total)
    else
        b.open:Hide()
    end
    local w = math.min(math.max(total * rested / max, RESTED_MIN_W), total - x)
    local restedEnd
    if rested > 0 and w >= 1 then
        b.rested:ClearAllPoints()
        b.rested:SetPoint("TOPLEFT", x, 0)
        b.rested:SetPoint("BOTTOMLEFT", x, 0)
        b.rested:SetWidth(w)
        b.rested:Show()
        restedEnd = x + w
    else
        b.rested:Hide()
    end
    FX.Segments(b, total, x, restedEnd, done > 0 and done >= max * (1 - pct / PERCENT), total / max)
end

function Look.Texts(b, level, xp, max, maxed, pct, rested)
    for i, spot in ipairs(INSIDE) do
        b.inside[i]:SetText(InsideText(S.Get(spot.key), level, xp, max, maxed, pct, rested))
    end
end

function Look.Fit(b, total, h)
    local insideChanged = TextsChanged(b.inside)
    local slotsChanged = TextsChanged(b.slots)
    local font, size, outline = S.Get("xpBarFont"), S.Get("xpBarFontSize"), S.Get("xpBarOutline")
    if insideChanged or slotsChanged or b._fitW ~= total or b._fitH ~= h or b._fitFont ~= font
        or b._fitSize ~= size or b._fitOutline ~= outline then
        b._fitW, b._fitH, b._fitFont, b._fitSize, b._fitOutline = total, h, font, size, outline
        FitInside(b.inside, total, h, b.placeInside)
        FitSlots(b.slots, total, b.placeMid)
    end
end

local function ShowsText(which)
    for _, slot in ipairs(SLOTS) do
        if S.Get(slot.key) == which then return true end
    end
    return false
end

local Hover = { AWAY_DIM = 0.25, data = {} }

function Hover.Away(b, mode, away)
    b.around:SetAlpha(mode ~= "off" and away or 1)
    b.text:SetAlpha(mode == "all" and away or 1)
end

function Hover.Reach(b)
    local row = S.Get("xpBarFontSize") + SLOT_DROP
    local top = math.max(Natural(b.slots[TOP_LEFT]), Natural(b.slots[TOP]), Natural(b.slots[TOP_RIGHT]))
    local bottom = math.max(Natural(b.slots[BOTTOM_LEFT]), Natural(b.slots[BOTTOM]), Natural(b.slots[BOTTOM_RIGHT]))
    local left, right = Natural(b.slots[LEFT]), Natural(b.slots[RIGHT])
    b:SetHitRectInsets(left > 0 and -(left + SIDE_GAP) or 0, right > 0 and -(right + SIDE_GAP) or 0,
        top > 0 and -row or 0, bottom > 0 and -row or 0)
end

function Hover.Update()
    local mode = S.Get("xpBarTextsHover")
    if mode ~= "off" then Hover.Reach(bar) end
    Hover.Away(bar, mode, (unlocked or hovered) and 1 or 0)
end

function Hover.Data()
    local d = Hover.data
    local xp, max = UnitXP("player"), math.max(UnitXPMax("player"), 1)
    d.level, d.left = UnitLevel("player"), math.max(max - xp, 0)
    d.leftPct = d.left / max * PERCENT
    d.done, d.open, d.rested = questDone, questOpen, GetXPExhaustion() or 0
    d.ready = questDone > 0 and questDone >= d.left
    local rate = sessionXP / (math.max(time() - sessionStart, MIN_RATE_TIME) / HOUR)
    d.pace = rate > 0 and Duration(d.left / rate * HOUR) or nil
    return d
end

function Hover.Enter()
    hovered = true
    Hover.Update()
    if S.Get("xpBarBreakdown") and sessionStart and not AtMaxLevel() then FX.ShowBreakdown(bar, Hover.Data()) end
end

function Hover.Leave()
    hovered = false
    Hover.Update()
    FX.HideBreakdown()
end

function Hover.Mouse()
    local ctrl = IsControlKeyDown()
    local motion = ctrl or S.Get("xpBarTextsHover") ~= "off" or S.Get("xpBarBreakdown")
    if not motion then hovered = false end
    bar:SetMouseClickEnabled(ctrl)
    bar:SetMouseMotionEnabled(motion)
end

local function Update()
    if not bar then return end
    local maxed = AtMaxLevel()
    if not unlocked and (inPvP or (maxed and not S.Get("xpBarMaxLevel"))) then
        bar:Hide()
        return
    end

    local xp, max = UnitXP("player"), math.max(UnitXPMax("player"), 1)
    local pct = maxed and PERCENT or xp / max * PERCENT
    local rested = GetXPExhaustion() or 0
    Look.Texts(bar, UnitLevel("player"), xp, max, maxed, pct, rested)

    local total = bar:GetWidth()
    Look.Segments(bar, total, pct, questDone, questOpen, rested, max, maxed)

    for i, slot in ipairs(SLOTS) do
        bar.slots[i]:SetText(SlotText(S.Get(slot.key), maxed, max))
    end
    Look.Fit(bar, total, bar:GetHeight())
    Hover.Update()
    bar:Show()
end

local function ScanAndUpdate()
    ScanQuests()
    Update()
end

local function QueueQuestScan()
    if questTimer then return end
    questTimer = C_Timer.NewTimer(QUEST_SCAN_DELAY, ScanAndUpdate)
end

local function PlayedChanged()
    if bar and On() then Update() end
end

function ns.ResetXPBarSession()
    if not sessionStart then return end
    sessionStart, sessionXP = time(), 0
    SaveSession()
    Update()
end

local function CountXP()
    local xp, max = UnitXP("player"), UnitXPMax("player")
    local gained = xp >= lastXP and xp - lastXP or (lastXPMax - lastXP) + xp
    lastXP, lastXPMax = xp, max
    sessionXP = sessionXP + gained
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, _, questXP)
    if event == "QUEST_TURNED_IN" then
        if questXP and questXP > 0 then
            FX.Gain(bar, questXP)
            C_Timer.After(FX.SETTLE, Update)
        end
        return
    end
    if event == "PLAYER_LOGOUT" then
        SaveSession()
        return
    end
    if event == "QUEST_LOG_UPDATE" then
        QueueQuestScan()
        return
    end
    if event == "MODIFIER_STATE_CHANGED" then
        Hover.Mouse()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        inPvP = InPvP()
    elseif event == "PLAYER_LEVEL_UP" then
        QueueQuestScan()
        FX.LevelUp(bar)
    elseif event == "PLAYER_XP_UPDATE" then
        CountXP()
    end
    Update()
end)

local function Place()
    local pos = S.Get("xpBarPos")
    bar:ClearAllPoints()
    if pos then
        bar:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, DEFAULT_Y)
    end
end

local function OnBarMouseUp(_, button)
    if button == "RightButton" and IsControlKeyDown() then ns.ResetXPTicker() end
end

local function Create()
    bar = CreateFrame("Frame", "NaowhForeverXPBar", UIParent)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:EnableMouse(false)
    bar:SetScript("OnMouseUp", OnBarMouseUp)
    bar:SetScript("OnEnter", Hover.Enter)
    bar:SetScript("OnLeave", Hover.Leave)
    Look.New(bar)

    bar.mover = ns.UI.AttachMover(bar, TEXT.MOVER, function(pos) S.Set("xpBarPos", pos) end, "QoL/XP",
        "QoL/XP:xpBar")
end

local function Apply()
    ConvertOldTexts()
    OneEach(SLOTS)
    OneEach(INSIDE)
    UpdateTextColors()
    if not On() then
        events:UnregisterAllEvents()
        events:RegisterEvent("PLAYER_LOGOUT")
        Played.Drop("xpBar")
        if clock then clock:Cancel(); clock = nil end
        if bar then bar:Hide() end
        SetBlizzardHidden(false)
        sessionStart, sessionXP = nil, 0
        return
    end
    if not bar then Create() end
    PaintBar(bar)
    if not sessionStart then sessionStart, sessionXP = time(), 0 end

    Look.Size(bar, math.max(S.Get("xpBarWidth"), ns.XPBarMinWidth), S.Get("xpBarHeight"))
    Place()

    lastXP, lastXPMax = UnitXP("player"), UnitXPMax("player")
    inPvP = InPvP()
    for _, e in ipairs(EVENTS) do events:RegisterEvent(e) end
    if ShowsText("played") then Played.Want("xpBar") else Played.Drop("xpBar") end
    if not clock then clock = C_Timer.NewTicker(CLOCK_TICK, Update) end

    SetBlizzardHidden(true)
    ScanQuests()
    bar.mover:SetShown(unlocked == true)
    Hover.Mouse()
    Update()
end

local STAGE = {
    H = 140, MARGIN = ns.Shared.Style.STAGE_MARGIN, NOTE_Y = ns.Shared.Style.STAGE_NOTE_Y,
    NOTE_SIZE = ns.Shared.Style.STAGE_NOTE_SIZE, NOTE_LINE = 15, MAX_SCALE = 1, FALLBACK_W = 870,
    CHIP = 12, CHIP_ICON = 8, CHIP_BG_ALPHA = 0.6, CHIP_LEVEL = 2, HOVER_ALPHA = 0.15, ZONE_PAD = 4,
    PICK_BUTTON = "LeftButton", MENU_BUTTON = "RightButton", PLUS = ns.Shared.Style.PLUS,
    TIP = { anchor = "cursor", justify = "LEFT" },
    ROWS = {
        { l = TOP_LEFT, m = TOP, r = TOP_RIGHT, point = "BOTTOMLEFT", rel = "TOPLEFT", x = 0, y = SLOT_DROP },
        { l = BOTTOM_LEFT, m = BOTTOM, r = BOTTOM_RIGHT, point = "TOPLEFT", rel = "BOTTOMLEFT", x = 0,
          y = -SLOT_DROP },
        { inside = true, l = 1, m = 2, r = 3, point = "LEFT", rel = "LEFT", x = INSIDE_INSET, y = 0 },
    },
    BESIDE = {
        { slot = LEFT, point = "RIGHT", rel = "LEFT", x = -SIDE_GAP, y = 0 },
        { slot = RIGHT, point = "LEFT", rel = "RIGHT", x = SIDE_GAP, y = 0 },
    },
}
STAGE.TEXT_ROOM = STAGE.NOTE_Y + STAGE.NOTE_LINE

local SAMPLE_LEVEL, SAMPLE_MAX, SAMPLE_XP = 24, 23200, 9512
local SAMPLE_DONE, SAMPLE_OPEN, SAMPLE_RESTED = 2784, 1856, 3596
local SAMPLE_PLAYED, SAMPLE_THIS_LEVEL, SAMPLE_SESSION = 368520, 12540, 4320
local SAMPLE_TO_LEVEL, SAMPLE_RATE = 9600, 8100
local STATES = {
    { key = "levelling", label = "Leveling", tip = "Partway through a level, with quests to hand in." },
    { key = "rested", label = "Rested", tip = "With rested experience ahead of the fill." },
    { key = "away", label = "Mouse Away", tip = "While the mouse is away, with Show Texts On Mouseover on.",
      needs = function() return S.Get("xpBarTextsHover") ~= "off" end },
    { key = "gain", label = "Quest Hand-In", tip = "Just after handing in a quest, with Quest XP Pulse on.",
      needs = function() return S.Get("xpBarGainPulse") end },
    { key = "ready", label = "Ready", tip = "With enough completed quests to level, with Ready to Level on.",
      needs = function() return S.Get("xpBarReadyGlow") end },
    { key = "levelup", label = "Level Up", tip = "The moment you level up, with Level-Up Flash on.",
      needs = function() return S.Get("xpBarLevelFlash") end },
}
local SAMPLE_GAIN = 845

local function PreviewSlotText(which, rested)
    local LABEL, VALUE = ns.Color("muted"), ns.Color("fg")
    if which == "played" then
        return LABEL .. TEXT.PLAYED .. VALUE .. Duration(SAMPLE_PLAYED) .. TEXT.PART .. LABEL .. TEXT.THIS_LEVEL
            .. VALUE .. Duration(SAMPLE_THIS_LEVEL) .. "|r"
    elseif which == "session" then
        return LABEL .. TEXT.SESSION .. VALUE .. Duration(SAMPLE_SESSION) .. "|r"
    elseif which == "completed" then
        return LABEL .. TEXT.COMPLETED .. questHex .. TEXT.PERCENT:format(SAMPLE_DONE / SAMPLE_MAX * PERCENT) .. "|r"
    elseif which == "completedxp" then
        return LABEL .. TEXT.COMPLETED .. questHex .. Grouped(SAMPLE_DONE) .. "|r"
    elseif which == "rested" then
        return LABEL .. TEXT.RESTED .. restedHex .. TEXT.PERCENT:format(rested / SAMPLE_MAX * PERCENT) .. "|r"
    elseif which == "leveling" then
        return LABEL .. TEXT.TO_LEVEL .. VALUE .. Duration(SAMPLE_TO_LEVEL) .. "|r"
    elseif which == "xphour" then
        return LABEL .. TEXT.XP_HOUR .. VALUE .. Short(SAMPLE_RATE) .. "|r"
    elseif which == "pace" then
        return LABEL .. TEXT.PACE:format(VALUE .. Duration(SAMPLE_TO_LEVEL) .. "|r" .. LABEL,
            VALUE .. Short(SAMPLE_RATE) .. "|r" .. LABEL) .. "|r"
    end
    return ""
end

local SLOT_HINT = ns.L("|n|nOnly Played Time and Session Time show at max level.")

local function OpenChoices(zone)
    if zone._menu and zone._menu:IsShown() then
        zone._menu:Close()
        zone._menu = nil
        return
    end
    if not (MenuUtil and MenuUtil.CreateRootMenuDescription and MenuVariants
        and Menu and Menu.GetManager and AnchorUtil) then return end
    local desc = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultMenuMixin())
    if not desc then return end
    if desc.CreateTitle then desc:CreateTitle(ns.L(zone._label)) end
    local shownAt = {}
    for _, spot in ipairs(zone._spots) do
        if spot.key ~= zone._key then shownAt[TextOf(S.Get(spot.key) or "none")] = spot.label end
    end
    local muted = ns.Color("muted")
    for _, k in ipairs(zone._choices.order) do
        local key = k
        local name = ns.L(zone._choices.values[key])
        local at = key ~= "none" and shownAt[TextOf(key)]
        if at then name = name .. " " .. muted .. TEXT.ON .. ns.L(at) .. ")|r" end
        desc:CreateRadio(name,
            function() return S.Get(zone._key) == key end,
            function()
                Claim(zone._spots, zone._key, key)
                S.Set(zone._key, key)
            end)
    end
    zone._menu = Menu.GetManager():OpenMenu(zone, desc,
        AnchorUtil.CreateAnchor("TOPLEFT", zone, "BOTTOMLEFT", 0, -MENU_DROP))
end

local function ChoiceName(zone)
    return zone._choices.values[S.Get(zone._key)] or zone._choices.values.none
end

local function BarMenu(_, root)
    root:CreateTitle(ns.L(TEXT.MOVER))
    root:CreateButton(TEXT.RESET_LAYOUT_LABEL, ns.ResetXPBarLayout)
    root:CreateButton(TEXT.RESET_COLORS_LABEL, ns.ResetXPBarColors)
end

local function Reveal(preview, on)
    preview.revealed = on
    for _, chip in ipairs(preview.chips) do chip:SetShown(on and chip.placed) end
end

local function StageEnter(frame)
    Reveal(frame.preview, true)
end

local function StageLeave(frame)
    local preview = frame.preview
    if not preview:IsMouseOver() then Reveal(preview, false) end
end

local function StageHidden(preview)
    Reveal(preview, false)
end

local function ZoneEnter(zone)
    zone.hover:Show()
    zone.border._frame:Show()
    StageEnter(zone)
    ns.UI.ShowWidgetTooltip(zone, ns.L(zone._label) .. ": " .. ns.L(ChoiceName(zone)) .. TEXT.CHANGE .. zone._hint,
        STAGE.TIP)
end

local function ZoneLeave(zone)
    zone.hover:Hide()
    zone.border._frame:Hide()
    ns.UI.HideWidgetTooltip()
    StageLeave(zone)
end

local function ZoneDown(zone, button)
    if button ~= STAGE.MENU_BUTTON then return OpenChoices(zone) end
    ns.UI.HideWidgetTooltip()
    MenuUtil.CreateContextMenu(zone, BarMenu)
end

local function ZoneHidden(zone)
    if zone._menu then zone._menu:Close(); zone._menu = nil end
end

local function ZoneHandles(_, button, event)
    return event == "GLOBAL_MOUSE_DOWN" and button == STAGE.PICK_BUTTON
end

local function NewZone(preview, fs, spot, spots, choices, hint)
    local b = preview.bar
    local zone = CreateFrame("Button", nil, b)
    zone:SetFrameLevel(b:GetFrameLevel() + PREVIEW_ZONE_LEVEL)
    zone.preview = preview
    zone._fs, zone._label, zone._key, zone._spots, zone._choices = fs, spot.label, spot.key, spots, choices
    zone._hint = hint or ""
    zone.hover = ns.Solid(zone, "BACKGROUND", T.accent, STAGE.HOVER_ALPHA)
    zone.hover:SetAllPoints()
    zone.hover:Hide()
    zone.border = ns.Border(zone, T.accent)
    zone.border._frame:Hide()
    zone.HandlesGlobalMouseEvent = ZoneHandles
    zone:SetScript("OnMouseDown", ZoneDown)
    zone:SetScript("OnEnter", ZoneEnter)
    zone:SetScript("OnLeave", ZoneLeave)
    zone:SetScript("OnHide", ZoneHidden)
    return zone
end

local function NewChip(preview)
    local b = preview.bar
    local chip = CreateFrame("Frame", nil, b)
    chip:SetFrameLevel(b:GetFrameLevel() + STAGE.CHIP_LEVEL)
    chip:SetSize(STAGE.CHIP, STAGE.CHIP)
    ns.Solid(chip, "BACKGROUND", T.bg, STAGE.CHIP_BG_ALPHA):SetAllPoints()
    ns.Border(chip, T.line)
    chip.icon = chip:CreateTexture(nil, "ARTWORK")
    chip.icon:SetTexture(STAGE.PLUS)
    chip.icon:SetSize(STAGE.CHIP_ICON, STAGE.CHIP_ICON)
    chip.icon:SetPoint("CENTER")
    chip.icon:SetVertexColor(T.muted.r, T.muted.g, T.muted.b, 1)
    chip:Hide()
    preview.chips[#preview.chips + 1] = chip
    return chip
end

local function HugText(zone, h)
    local fs = zone._fs
    local pad = STAGE.ZONE_PAD
    local w = math.min(Natural(fs), fs:GetWidth()) + pad * 2
    local justify = fs:GetJustifyH()
    local point = justify == "LEFT" and "LEFT" or justify == "RIGHT" and "RIGHT" or "CENTER"
    local dx = point == "LEFT" and -pad or point == "RIGHT" and pad or 0
    zone:ClearAllPoints()
    zone:SetPoint(point, fs, point, dx, 0)
    zone:SetSize(w, h or (fs:GetStringHeight() + pad * 2))
end

local function Seen(fs)
    local n = Natural(fs)
    if n == 0 then return 0 end
    return math.min(n, fs:GetWidth())
end

local function Clear(x, from, to)
    return to <= from or x + STAGE.CHIP + TEXT_GAP <= from or x >= to + TEXT_GAP
end

local function RowChips(w, l, m, r)
    local chip = STAGE.CHIP
    local lw, mw, rw = Seen(l), Seen(m), Seen(r)
    local _, _, _, dx = m:GetPoint(1)
    local centre = w / 2 + (dx or 0)
    local mFrom, mTo = centre - mw / 2, centre + mw / 2
    local lx, mx, rx
    if lw == 0 and Clear(0, mFrom, mTo) and Clear(0, w - rw, w) then lx, lw = 0, chip end
    if rw == 0 and Clear(w - chip, 0, lw) and Clear(w - chip, mFrom, mTo) then rx, rw = w - chip, chip end
    if mw == 0 then
        local from = lw > 0 and lw + TEXT_GAP or 0
        local to = rw > 0 and w - rw - TEXT_GAP or w
        if to - from >= chip then mx = math.min(math.max((w - chip) / 2, from), to - chip) end
    end
    return lx, mx, rx
end

local function PinChip(chip, x, at, b)
    chip.placed = x ~= nil
    if not x then return end
    chip:ClearAllPoints()
    chip:SetPoint(at.point, b, at.rel, at.x + x, at.y)
end

local function PlaceChips(preview, w)
    local b = preview.bar
    for _, row in ipairs(STAGE.ROWS) do
        local texts = row.inside and b.inside or b.slots
        local chips = row.inside and preview.insideChips or preview.slotChips
        local lx, mx, rx = RowChips(w - row.x * 2, texts[row.l], texts[row.m], texts[row.r])
        PinChip(chips[row.l], lx, row, b)
        PinChip(chips[row.m], mx, row, b)
        PinChip(chips[row.r], rx, row, b)
    end
    for _, side in ipairs(STAGE.BESIDE) do
        PinChip(preview.slotChips[side.slot], Natural(b.slots[side.slot]) == 0 and 0 or nil, side, b)
    end
    Reveal(preview, preview.revealed == true)
end

local function PlaceZone(zone, chip, h)
    local shown = Natural(zone._fs) > 0
    if shown then
        HugText(zone, h)
    elseif chip.placed then
        local size = STAGE.CHIP + STAGE.ZONE_PAD
        zone:ClearAllPoints()
        zone:SetPoint("CENTER", chip, "CENTER")
        zone:SetSize(size, size)
    end
    zone:SetShown(shown or chip.placed)
end

local function PreviewScale(roomW, roomH, footW, footH)
    return math.min(STAGE.MAX_SCALE, roomW / footW, roomH / footH)
end

local function FitStage(preview, w, h)
    local b = preview.bar
    local side = math.max(Natural(b.slots[LEFT]), Natural(b.slots[RIGHT]), STAGE.CHIP) + SIDE_GAP
    local row = math.max(S.Get("xpBarFontSize"), STAGE.CHIP) + SLOT_DROP
    local stageW, stageH = preview:GetWidth(), preview:GetHeight()
    if stageW <= 0 then stageW = STAGE.FALLBACK_W end
    if stageH <= 0 then stageH = STAGE.H end
    local scale = PreviewScale(stageW - STAGE.MARGIN * 2, stageH - STAGE.MARGIN * 2 - STAGE.TEXT_ROOM,
        w + side * 2, h + row * 2)
    b:SetScale(scale)
    b:ClearAllPoints()
    b:SetPoint("CENTER", preview, "CENTER", 0, STAGE.TEXT_ROOM / 2 / scale)
end

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.preview = preview
    preview:EnableMouse(true)
    preview:SetScript("OnEnter", StageEnter)
    preview:SetScript("OnLeave", StageLeave)
    preview:SetScript("OnHide", StageHidden)
    preview.note = ns.Font(preview, STAGE.NOTE_SIZE, nil, T.muted)
    preview.note:SetPoint("BOTTOM", 0, STAGE.NOTE_Y)
    preview.note:SetText(TEXT.PREVIEW_NOTE)
    local b = CreateFrame("Frame", nil, preview)
    preview.bar = b
    b:SetFrameLevel(preview:GetFrameLevel() + PREVIEW_BAR_LEVEL)
    Look.New(b)
    local body = ns.Shared.Settings.EditZone(b, { menu = BarMenu, enter = StageEnter, leave = StageLeave })
    body.preview = preview
    body:SetAllPoints()
    body:SetFrameLevel(b:GetFrameLevel() + STAGE.CHIP_LEVEL)
    preview.chips, preview.insideChips, preview.slotChips = {}, {}, {}
    preview.inside, preview.slots = {}, {}
    for i, spot in ipairs(INSIDE) do
        preview.inside[i] = NewZone(preview, b.inside[i], spot, INSIDE, BAR_TEXTS)
        preview.insideChips[i] = NewChip(preview)
    end
    for i, slot in ipairs(SLOTS) do
        preview.slots[i] = NewZone(preview, b.slots[i], slot, SLOTS, SLOT_TEXTS, SLOT_HINT)
        preview.slotChips[i] = NewChip(preview)
    end
    return preview
end

local function PaintPreview(preview, state)
    UpdateTextColors()
    local b = preview.bar
    local rested = state == "rested" and SAMPLE_RESTED or 0
    for i, slot in ipairs(SLOTS) do b.slots[i]:SetText(PreviewSlotText(S.Get(slot.key), rested)) end
    local w, h = math.max(S.Get("xpBarWidth"), ns.XPBarMinWidth), S.Get("xpBarHeight")
    PaintBar(b)
    Look.Size(b, w, h)
    local pct = SAMPLE_XP / SAMPLE_MAX * PERCENT
    local done = state == "ready" and SAMPLE_MAX - SAMPLE_XP or SAMPLE_DONE
    if state == "gain" then FX.Gain(b, SAMPLE_GAIN, 0) end
    Look.Segments(b, w, pct, done, SAMPLE_OPEN, rested, SAMPLE_MAX, false)
    if state == "levelup" then FX.LevelUp(b) end
    Look.Texts(b, SAMPLE_LEVEL, SAMPLE_XP, SAMPLE_MAX, false, pct, rested)
    Look.Fit(b, w, h)
    Hover.Away(b, state == "away" and S.Get("xpBarTextsHover") or "off", Hover.AWAY_DIM)
    PlaceChips(preview, w)
    for i, zone in ipairs(preview.inside) do PlaceZone(zone, preview.insideChips[i], h) end
    for i, zone in ipairs(preview.slots) do PlaceZone(zone, preview.slotChips[i]) end
    FitStage(preview, w, h)
end

function ns.ResetXPBarLayout()
    ns.Confirm(TEXT.RESET_LAYOUT, function()
        local db = S.DB()
        db.xpBarWidth, db.xpBarHeight = nil, nil
        for _, spot in ipairs(SLOTS) do db[spot.key] = nil end
        for _, spot in ipairs(INSIDE) do db[spot.key] = nil end
        S.Set("xpBarWidth", nil)
        ns.UI:RefreshPage(true)
    end)
end

local Group = ns.Shared.Settings.Group
local SAME_COLOUR = 1 / 255
local FONT_RANGE = { SLOT_FONT_MIN, 20, 1 }
local BAR_TEXT_HELP = ns.L("A text on the bar: click it on the preview to change it. Each text shows in one "
    .. "place on the bar: picking one shown elsewhere moves it there.")
local SLOT_TEXT_HELP = ns.L("A text around the bar: click it on the preview to change it. Each text shows in "
    .. "one place around it: picking one shown elsewhere moves it there. Only Played Time and Session Time show at "
    .. "max level.")

local function SetColour(key, r, g, b)
    local d = ns.XPBarDefaultColor(key)
    if math.abs(r - d.r) <= SAME_COLOUR and math.abs(g - d.g) <= SAME_COLOUR and math.abs(b - d.b) <= SAME_COLOUR then
        if S.Get(key) ~= nil then S.Set(key, nil) end
    else
        S.Set(key, { r = r, g = g, b = b })
    end
end

local function ColourRow(key, label, help)
    return { key = key, label = label, colour = true, help = help,
        get = function()
            local c = ns.XPBarColor(key)
            return c.r, c.g, c.b, 1
        end,
        set = function(r, g, b) SetColour(key, r, g, b) end }
end

local function Hidden(row)
    row.hidden = true
    return row
end

local function TextRow(spot, spots, choices, help)
    local key = spot.key
    return { key = key, label = spot.label, choice = choices, help = help, hidden = true,
        get = function() return S.Get(key) end,
        set = function(which)
            Claim(spots, key, which)
            S.Set(key, which)
        end }
end

local function BarRows()
    local rows = ns.Shared.Settings.Look("xpBar", { bar = "Flat", background = "alpha" })
    table.insert(rows, 2, { key = "xpBarWidth", label = "Width", slider = WIDTH_RANGE })
    table.insert(rows, 3, { key = "xpBarHeight", label = "Height", slider = HEIGHT_RANGE })
    return rows
end

local ROWS = {
    Group("Show"),
    { key = "xpBarMaxLevel", label = "Show at Max Level", toggle = true,
      help = "Keeps the bar up at max level, with your played time and session." },
    { key = "xpBarTextsHover", label = "Show Texts On Mouseover", choice = HOVER_TEXTS,
      help = "Hides the texts until you hover the bar: the ones around it, or those on it too." },
    { key = "xpBarIncomplete", label = "Incomplete Quests", toggle = true,
      help = "The XP of quests still in progress, as a faded segment after the completed ones." },
    { key = "xpBarResetOnReload", label = "Reset Session on Reload", toggle = true,
      help = "Starts the session time and XP/Hour again on a /reload. Off: a /reload carries on the "
          .. "session. A fresh login always starts a new one." },
    BarRows(),
    FX.Rows(Group),
    ns.Shared.Settings.Look("xpBar", { text = true, size = FONT_RANGE }),
    Group("Colors"),
    ColourRow("xpBarFillColor", "Fill Color", "Your experience. Its left end is a darker shade."),
    ColourRow("xpBarQuestColor", "Completed Quests Color", "The XP of completed quests, and their text."),
    ColourRow("xpBarOpenColor", "Incomplete Quests Color",
        "The XP of quests still in progress. By default the completed quests color, faded."),
    ColourRow("xpBarRestedColor", "Rested Color", "Rested experience, and its text."),
    ColourRow("xpBarBgColor", "Background Color", "Behind the fill."),
    ColourRow("xpBarBorderColor", "Border Color", "The line round the bar."),
    Hidden(Group("Text")),
}
for _, spot in ipairs(INSIDE) do ROWS[#ROWS + 1] = TextRow(spot, INSIDE, BAR_TEXTS, BAR_TEXT_HELP) end
ROWS[#ROWS + 1] = Hidden(Group("Around the Bar"))
for _, slot in ipairs(SLOTS) do ROWS[#ROWS + 1] = TextRow(slot, SLOTS, SLOT_TEXTS, SLOT_TEXT_HELP) end

local function Summary(store)
    return TEXT.SUMMARY:format(math.max(store.Get("xpBarWidth"), ns.XPBarMinWidth), store.Get("xpBarHeight"),
        store.Get("xpBarMaxLevel") and TEXT.AT_MAX or "", store.Get("xpBarTextsHover") ~= "off" and TEXT.ON_HOVER or "")
end

ns.Shared.Settings.Page("QoL/XP", S):Card({
    id = "xpBar", name = "XP Bar", order = 10, switch = "xpBar",
    help = "Your level, experience and percentage on one bar, with the XP of completed quests and rested "
        .. "experience drawn past the fill. Replaces Blizzard's experience bar while it is on. Move it in the "
        .. "HUD Editor. Ctrl + right-click the bar to reset the session time and XP/Hour.",
    summary = Summary,
    studio = { height = STAGE.H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = ROWS,
})

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or (key:find("^xpBar") and key ~= "xpBarPos") then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(Played, "Answered", PlayedChanged)
hooksecurefunc(Played, "LeveledUp", PlayedChanged)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = On() == true
    Apply()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    if bar then
        bar.mover:Hide()
        Apply()
    end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function(self, _, isLogin, isReload)
    if not (isLogin or isReload) then return end
    self:UnregisterAllEvents()
    LoadSession(isReload)
    Apply()
end)

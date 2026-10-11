-- GroupXP.lua: Group XP, a bar per group member fed by the addon messages of everyone running it.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local Parts = ns.Shared.Parts

local PREFIX = "NaowhGroupXP"
local GROUP_CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true }
local GUID_PATTERN = ns.QoLConstants.GUID_PATTERN
local MAX_LEVEL, MAX_XP = 1000, 2 ^ 31
local GRADIENT = ns.MEDIA .. "NaowhGradient.tga"
local ROW_H, NAME_W, GAP, BASE_SIZE = 18, 90, 2, 12
local ROW_PAD = ROW_H - BASE_SIZE
local TEXT_SMALLER = 1
local NAME_ROOM = 4
local SEND_DELAY = 2
local PERCENT = ns.QoLConstants.PERCENT
local DEFAULT_X, DEFAULT_Y = 40, 120
local BLACK = ns.Shared.Style.BORDER_RGB
local WHITE = ns.QoLConstants.WHITE_RGB
local ASK = "R"
local MESSAGE = "2 %s %d %d %d"
local MESSAGE_PATTERN = "^2 (%S+) (%d+) (%d+) (%d+)$"
local TEXT_LEVEL, TEXT_NO_LEVEL = ns.L("Lv "), ns.L("Lv ?")
local TEXT_NO_ADDON = ns.L("  |cff9ca3afno addon|r")
local TEXT_MAX = ns.L("  Max")
local TEXT_PROGRESS = ns.L("Lv %d  %.1f%%")
local TEXT_IN_GROUP = ns.L("Shown while you are in a group.")
local MOVER_LABEL = "Group XP"
local SETTINGS_PAGE, SETTINGS_CARD = "QoL/XP", "QoL/XP:groupXP"
local SUMMARY = ns.L("%d wide%s")
local SUMMARY_SELF = ns.L(", with you")
local STAGE_H = 130
local NOTE_Y, NOTE_SIZE = ns.Shared.Style.STAGE_NOTE_Y, ns.Shared.Style.STAGE_NOTE_SIZE
local STAGE_MARGIN = ns.Shared.Style.STAGE_MARGIN
local WIDTH_RANGE = { 160, 500, 10 }
local TEXT_RANGE = { 8, 20, 1 }
local EVENTS = { "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD",
    "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UNIT_LEVEL", "PLAYER_REGEN_ENABLED" }

local frame, unlocked, sendQueued, sendAfterCombat, requestPending
local others = {}
local rows = {}
local mine, units, roster, members, shown, entries, inGroup = {}, {}, {}, {}, {}, {}, {}

local function On()
    return S.Get("enabled") and S.Get("groupXP")
end

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

local function Channel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function Own()
    mine.level, mine.xp, mine.max = UnitLevel("player"), UnitXP("player"), UnitXPMax("player")
    return mine
end

local function Send()
    local channel = Channel()
    if not channel then
        requestPending = false
        return
    end
    if InCombatLockdown() then
        sendAfterCombat = true
        return
    end
    if requestPending then
        requestPending = false
        C_ChatInfo.SendAddonMessage(PREFIX, ASK, channel)
    end
    local own = Own()
    C_ChatInfo.SendAddonMessage(PREFIX, MESSAGE:format(UnitGUID("player"), own.level, own.xp, own.max),
        channel)
end

local function SendQueued()
    sendQueued = false
    Send()
end

local function SendSoon(request)
    if request then requestPending = true end
    if sendQueued then return end
    sendQueued = true
    C_Timer.After(SEND_DELAY, SendQueued)
end

local function Units()
    wipe(units)
    units[1] = "player"
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            local me = UnitIsUnit(unit, "player")
            if not Secret(me) and not me then units[#units + 1] = unit end
        end
    else
        for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
    end
    return units
end

local function Roster()
    Units()
    wipe(roster)
    for _, unit in ipairs(units) do
        local name, guid = UnitName(unit), UnitGUID(unit)
        local _, class = UnitClass(unit)
        if name and guid and not (Secret(name) or Secret(guid) or Secret(class)) then
            local n = #roster + 1
            local m = members[n] or {}
            members[n] = m
            m.unit, m.name, m.class, m.guid = unit, name, class, guid
            roster[n] = m
        end
    end
    return roster
end

local Look = {}

function Look.NewRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.name = ns.Font(row, BASE_SIZE, "OUTLINE")
    row.name:SetPoint("LEFT")
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetPoint("BOTTOMRIGHT")
    row.bar:SetMinMaxValues(0, 1)
    row.bg = ns.Solid(row.bar, "BACKGROUND", T.bg)
    row.bg:SetAllPoints()
    ns.Border(row.bar, BLACK)
    row.text = ns.Font(row.bar, BASE_SIZE - TEXT_SMALLER, "OUTLINE")
    row.text:SetPoint("CENTER")
    return row
end

function Look.Style(row, size)
    local font, outline = S.Get("groupXPFont"), S.Get("groupXPOutline")
    local nameW = NAME_W * size / BASE_SIZE
    row:SetHeight(math.max(ROW_H, size + ROW_PAD))
    Parts.HudFont(row.name, font, size, outline)
    row.name:SetWidth(nameW - NAME_ROOM)
    Parts.HudFont(row.text, font, size - TEXT_SMALLER, outline)
    row.bar:SetPoint("TOPLEFT", nameW, 0)
    row.bar:SetStatusBarTexture(ns.UI.TexturePath(S.Get("groupXPTexture"), GRADIENT))
    row.bar:SetStatusBarColor(T.accent.r, T.accent.g, T.accent.b)
    row.bg:SetColorTexture(T.bg.r, T.bg.g, T.bg.b, S.Get("groupXPBgAlpha"))
end

function Look.Paint(row, name, class, level, data)
    local color = class and RAID_CLASS_COLORS[class] or WHITE
    row.name:SetText(name)
    row.name:SetTextColor(color.r, color.g, color.b)
    local lv = level and level > 0 and (TEXT_LEVEL .. level) or TEXT_NO_LEVEL
    if not data then
        row.bar:SetValue(0)
        row.text:SetText(lv .. TEXT_NO_ADDON)
    elseif data.level >= GetMaxLevelForPlayerExpansion() or data.max <= 0 then
        row.bar:SetValue(1)
        row.text:SetText(TEXT_LEVEL .. data.level .. TEXT_MAX)
    else
        local pct = data.xp / data.max
        row.bar:SetValue(pct)
        row.text:SetText(TEXT_PROGRESS:format(data.level, pct * PERCENT))
    end
    row:Show()
end

local SAMPLE = {
    { name = ns.L("Tank"), class = "WARRIOR", data = { level = 24, xp = 11000, max = 12200 } },
    { name = ns.L("Healer"), class = "PRIEST", data = { level = 25, xp = 3100, max = 13100 } },
    { name = ns.L("Rogue"), class = "ROGUE", level = 23 },
}

function Look.Rows(owner, pool, list)
    local size = S.Get("groupXPFontSize")
    local step = math.max(ROW_H, size + ROW_PAD) + GAP
    owner:SetSize(S.Get("groupXPWidth"), #list * step - GAP)
    for i, m in ipairs(list) do
        local row = pool[i] or Look.NewRow(owner)
        pool[i] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * step)
        row:SetPoint("TOPRIGHT", 0, -(i - 1) * step)
        Look.Style(row, size)
        Look.Paint(row, m.name, m.class, m.level, m.data)
    end
    for i = #list + 1, #pool do pool[i]:Hide() end
end

function Look.Sample(list, withSelf)
    if withSelf then
        local _, class = UnitClass("player")
        list[#list + 1] = { name = UnitName("player"), class = class, data = Own() }
    end
    for _, m in ipairs(SAMPLE) do list[#list + 1] = m end
    return list
end

local function AddEntry(list, m)
    local level = UnitLevel(m.unit)
    if Secret(level) then level = nil end
    local n = #list + 1
    local e = entries[n] or {}
    entries[n] = e
    e.name, e.class, e.level = m.name, m.class, level
    e.data = m.unit == "player" and Own() or others[m.guid]
    list[n] = e
end

local function Refresh()
    if not frame then return end
    wipe(shown)
    local list = shown
    if unlocked then
        Look.Sample(list, true)
    elseif On() and IsInGroup() then
        for _, m in ipairs(Roster()) do
            if m.unit ~= "player" or S.Get("groupXPShowSelf") then AddEntry(list, m) end
        end
    end
    if #list == 0 then
        frame:Hide()
        return
    end
    Look.Rows(frame, rows, list)
    frame:Show()
end

local function Prune()
    wipe(inGroup)
    for _, m in ipairs(Roster()) do inGroup[m.guid] = true end
    for guid in pairs(others) do
        if not inGroup[guid] then others[guid] = nil end
    end
end

local function OnMessage(msg, channel, sender)
    if msg == ASK then
        SendSoon()
        return
    end
    local guid, level, xp, max = msg:match(MESSAGE_PATTERN)
    if not guid or not guid:find(GUID_PATTERN) or guid == UnitGUID("player") then return end
    level, xp, max = tonumber(level), tonumber(xp), tonumber(max)
    if level > MAX_LEVEL or xp > MAX_XP or max > MAX_XP or not ns.SenderIs(sender, channel, guid) then return end
    local data = others[guid] or {}
    others[guid] = data
    data.level, data.xp, data.max = level, xp, max
    Refresh()
end

local function Place()
    local pos = S.Get("groupXPPos")
    frame:ClearAllPoints()
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("LEFT", UIParent, "LEFT", DEFAULT_X, DEFAULT_Y)
    end
end

local function OnAddonMessage(prefix, msg, channel, sender)
    if Secret(prefix) or Secret(msg) or Secret(channel) or Secret(sender) then return end
    if prefix == PREFIX and GROUP_CHANNELS[channel] then OnMessage(msg, channel, sender) end
end

local function OnEvent(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)
        return
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        Prune()
        SendSoon(event == "PLAYER_ENTERING_WORLD")
    elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
        SendSoon()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if not sendAfterCombat then return end
        sendAfterCombat = false
        Send()
        return
    end
    Refresh()
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", OnEvent)

local function SavePosition(pos)
    S.Set("groupXPPos", pos)
end

local function Build()
    frame = CreateFrame("Frame", "NaowhForeverGroupXP", UIParent)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame.mover = ns.UI.AttachMover(frame, MOVER_LABEL, SavePosition, SETTINGS_PAGE, SETTINGS_CARD)
end

local function Apply()
    if not On() then
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() end
    Place()
    frame.mover:SetShown(unlocked == true)
    Refresh()
end

local function OnSettingChanged(key)
    if key == "enabled" or (key:find("^groupXP") and key ~= "groupXPPos") then Apply() end
end

local function OnLogin()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    Prune()
    Apply()
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = On() == true
    Apply()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    if frame then
        frame.mover:Hide()
        Apply()
    end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end

local STATES = {
    { key = "group", label = "In a Group", tip = "Your group's bars, with sample members." },
}

local function NewPreview(stage)
    local preview = CreateFrame("Frame", nil, stage)
    preview:SetAllPoints()
    preview.group = CreateFrame("Frame", nil, preview)
    preview.rows, preview.list = {}, {}
    preview.note = ns.Font(preview, NOTE_SIZE, nil, T.muted)
    preview.note:SetPoint("BOTTOM", 0, NOTE_Y)
    preview.note:SetText(TEXT_IN_GROUP)
    return preview
end

local function PaintPreview(preview)
    local list, group = preview.list, preview.group
    wipe(list)
    Look.Rows(group, preview.rows, Look.Sample(list, S.Get("groupXPShowSelf")))
    local w, h = group:GetWidth(), group:GetHeight()
    local roomW = preview:GetWidth() - STAGE_MARGIN * 2
    local roomH = preview:GetHeight() - STAGE_MARGIN * 2 - NOTE_Y * 2
    local scale = 1
    if roomW > 0 and w > roomW then scale = roomW / w end
    if roomH > 0 and h > 0 and h * scale > roomH then scale = roomH / h end
    group:SetScale(scale)
    group:ClearAllPoints()
    group:SetPoint("CENTER", preview, "CENTER", 0, NOTE_Y / scale)
end

local function Summary(store)
    return SUMMARY:format(store.Get("groupXPWidth"), store.Get("groupXPShowSelf") and SUMMARY_SELF or "")
end

Settings.Page("QoL/XP", S):Card({
    id = "groupXP", name = "Group XP", order = 30, switch = "groupXP",
    help = "A bar per group member with their level and how far through it they are. Every member running "
        .. "Naowh Forever shares their experience, even with this off; anyone else shows their level. "
        .. "Updates wait until combat ends. Move it in the HUD Editor.",
    summary = Summary,
    studio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview },
    rows = {
        { key = "groupXPShowSelf", label = "Show Yourself", toggle = true,
          help = "Your own bar among the group's." },
        Settings.Group("Size"),
        { key = "groupXPWidth", label = "Width", slider = WIDTH_RANGE },
        Settings.Look("groupXP", { text = true, size = TEXT_RANGE, bar = "Naowh Gradient", background = "alpha" }),
    },
})

-- BuffThanks.lua: Buff Thank You Message, a whisper of thanks for a class buff in the open world.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local Parts = ns.Shared.Parts

local FAMILIES = {
    { key = "buffThanksIntellect", label = "Intellect Lines", what = ns.L("Arcane Intellect and Brilliance"),
      ids = { 10157, 10156, 1461, 1460, 1459, 23028 } },
    { key = "buffThanksStamina", label = "Fortitude Lines", what = ns.L("Power Word: Fortitude and its Prayer"),
      ids = { 10938, 10937, 2791, 1245, 1244, 1243, 21564, 21562 } },
    { key = "buffThanksSpirit", label = "Spirit Lines", what = ns.L("Divine Spirit and its Prayer"),
      ids = { 27841, 14819, 14818, 14752, 27681 } },
    { key = "buffThanksShadow", label = "Shadow Protection Lines", what = ns.L("Shadow Protection and its Prayer"),
      ids = { 976, 10957, 10958, 27683 } },
    { key = "buffThanksWild", label = "Wild Lines", what = ns.L("Mark and Gift of the Wild"),
      ids = { 9885, 9884, 8907, 5234, 6756, 5232, 1126, 21850, 21849 } },
    { key = "buffThanksThorns", label = "Thorns Lines", what = "Thorns",
      ids = { 467, 782, 1075, 8914, 9756, 9910 } },
    { key = "buffThanksBlessing", label = "Blessing Lines", what = ns.L("every Paladin blessing"),
      ids = { 25291, 19838, 19837, 19836, 19835, 19834, 19740, 25916, 25782,
          25290, 19854, 19853, 19852, 19850, 19742, 25918, 25894,
          20217, 25898, 1038, 25895, 19979, 19978, 19977, 25890,
          1022, 5599, 10278, 1044, 6940, 20729 } },
}

local OTHERS = {
    1008, 8455, 10169, 10170,
    604, 8450, 8451, 10173, 10174,
    6346, 10060, 1706,
    29166,
    5697, 132, 2970, 11743,
    131, 546,
}

local SENT_MAX, SENT_WINDOW = 3, 60
local SECONDS_PER_MINUTE = ns.QoLConstants.SECONDS_PER_MINUTE

local OPTIONS_WINDOW = "NaowhForeverOptions"
local EDITOR_INSET = 6
local COOLDOWN_RANGE = { 1, 60, 1 }
local EDGE = ns.Shared.Style.BORDER_RGB
local EMOTE_KEY = "?"
local THANK_EMOTE = "THANK"
local WHISPER_KEY = "buffThanksText"
local TEXT_SAVE, TEXT_CANCEL = "Save", "Cancel"

local buffs
local thanked = {}
local windowAt, sentCount = 0, 0
local editor, editKey

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

local function On()
    return S.Get("enabled") and S.Get("buffThanks")
end

local function Line(key, buff, name)
    local lines = {}
    for line in S.Get(key):gmatch("[^\n]+") do
        line = strtrim(line)
        if line ~= "" then lines[#lines + 1] = line end
    end
    if #lines == 0 then return nil end
    local text = lines[math.random(#lines)]:gsub("{buff}", function() return buff end)
    return (text:gsub("{name}", function() return name end))
end

local function Due(key)
    local now, wait = GetTime(), S.Get("buffThanksCooldown") * SECONDS_PER_MINUTE
    for k, at in pairs(thanked) do
        if now - at >= wait then thanked[k] = nil end
    end
    if thanked[key] then return false end
    thanked[key] = now
    return true
end

local function Room(now)
    if now - windowAt >= SENT_WINDOW then windowAt, sentCount = now, 0 end
    return sentCount < SENT_MAX
end

local function Send(text, channel, to)
    sentCount = sentCount + 1
    C_ChatInfo.SendChatMessage(text, channel, nil, to)
end

local function ThankCaster(unit, id, buff)
    if UnitIsUnit(unit, "player") or not UnitIsPlayer(unit) then return end
    if not S.Get("buffThanksGroup") and (UnitInParty(unit) or UnitInRaid(unit)) then return end
    local name, guid = GetUnitName(unit, true), UnitGUID(unit)
    if not name or not Due(guid and not Secret(guid) and guid or name) then return end
    local short, family = Ambiguate(name, "short"), buffs[id]
    local text = S.Get("buffThanksPerBuff") and family ~= true and Line(family, buff, short)
        or Line(WHISPER_KEY, buff, short)
    if text then Send(text, "WHISPER", name) end
end

local function ThankStranger()
    if not (S.Get("buffThanksEmote") and Due(EMOTE_KEY)) then return end
    sentCount = sentCount + 1
    C_ChatInfo.PerformEmote(THANK_EMOTE)
end

local function Thank(aura)
    local unit, id = aura.sourceUnit, aura.spellId
    if Secret(unit) or Secret(id) or not buffs[id] or not Room(GetTime()) then return end
    if unit then
        ThankCaster(unit, id, aura.name)
    else
        ThankStranger()
    end
end

local function OnAura(_, _, _, info)
    if not (info and info.addedAuras) or C_Secrets.ShouldAurasBeSecret() then return end
    if UnitAffectingCombat("player") or IsInInstance() or C_ChatInfo.InChatMessagingLockdown() then return end
    for _, aura in ipairs(info.addedAuras) do
        if aura.isHelpful then Thank(aura) end
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", OnAura)

local function BuildBuffs()
    buffs = {}
    for _, family in ipairs(FAMILIES) do
        for _, id in ipairs(family.ids) do buffs[id] = family.key end
    end
    for _, id in ipairs(OTHERS) do buffs[id] = true end
end

local function Apply()
    events:UnregisterAllEvents()
    if not On() then
        wipe(thanked)
        return
    end
    if not buffs then BuildBuffs() end
    events:RegisterUnitEvent("UNIT_AURA", "player")
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "buffThanks" then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local function FitEditor()
    if not editor then return end
    local view = editor.view
    view:SetHeight(math.max(editor.scroll:GetHeight(), view.box:GetHeight()))
end

local function FollowCursor(_, _, y, _, h)
    local scroll = editor.scroll
    local top, shown, offset = -y, scroll:GetHeight(), scroll:GetVerticalScroll()
    if top < offset then
        scroll:SetVerticalScroll(top)
    elseif top + h > offset + shown then
        scroll:SetVerticalScroll(top + h - shown)
    end
end

local function FocusEnd(view)
    local box = view.box
    box:SetFocus()
    box:SetCursorPosition(#box:GetText())
end

local function NewEditorView(scroll)
    local view = CreateFrame("Frame", nil, scroll)
    ns.Solid(view, "BACKGROUND", ns.THEME.bg, 1):SetAllPoints()
    ns.Border(view, EDGE)
    local box = CreateFrame("EditBox", nil, view)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlight")
    box:SetTextInsets(EDITOR_INSET, EDITOR_INSET, EDITOR_INSET, EDITOR_INSET)
    box:SetPoint("TOPLEFT")
    box:SetPoint("TOPRIGHT")
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnCursorChanged", FollowCursor)
    box:SetScript("OnSizeChanged", FitEditor)
    view:EnableMouse(true)
    view:SetScript("OnMouseDown", FocusEnd)
    view.box = box
    return view
end

local function Opaque()
    return 1
end

local function SaveLines()
    S.Set(editKey, editor.view.box:GetText())
    editor:Hide()
end

local function CloseEditor()
    editor:Hide()
end

local function EditLines(key, title)
    if not editor then
        editor = Parts.SidePanel({ { TEXT_SAVE, SaveLines }, { TEXT_CANCEL, CloseEditor } },
            NewEditorView, Opaque)
        editor.scroll:HookScript("OnSizeChanged", FitEditor)
    end
    editKey = key
    editor.title:SetText(title)
    editor.view.box:SetText(S.Get(key))
    Parts.ShowBeside(editor, _G[OPTIONS_WINDOW])
    local point, owner, relative, x = editor:GetPoint(1)
    editor:SetPoint(point == "TOPLEFT" and "BOTTOMLEFT" or "BOTTOMRIGHT", owner,
        relative == "TOPRIGHT" and "BOTTOMRIGHT" or "BOTTOMLEFT", x, 0)
    FitEditor()
    editor.view.box:SetFocus()
end

local Group = ns.Shared.Settings.Group

local function PerBuffOff()
    return not S.Get("buffThanksPerBuff")
end

local rows = {
    { key = "buffThanksText", label = "Whisper Lines", buttonText = "Edit",
      button = function() EditLines("buffThanksText", ns.L("Whisper Lines")) end,
      help = "One whisper per line, picked at random; {buff} and {name} are filled in." },
    { key = "buffThanksCooldown", label = "Once Per Player Every", slider = COOLDOWN_RANGE, unit = "m",
      help = "The shortest time between two thanks to the same player." },
    { key = "buffThanksGroup", label = "Thank Group Members", toggle = true,
      help = "Also thanks players in your party or raid." },
    { key = "buffThanksPerBuff", label = "Lines Per Buff", toggle = true,
      help = "Own lines for the buffs below; one left empty uses the Whisper Lines." },
}
for _, family in ipairs(FAMILIES) do
    rows[#rows + 1] = { key = family.key, label = family.label, buttonText = "Edit", hidden = PerBuffOff,
        button = function() EditLines(family.key, family.label) end,
        help = ns.L("Whispers for ") .. family.what .. "." }
end
rows[#rows + 1] = Group("Unknown Casters")
rows[#rows + 1] = { key = "buffThanksEmote", label = "Thank With an Emote", toggle = true,
    help = "A /thank to everyone around you when the game cannot name the caster." }

ns.Shared.Settings.Page("QoL/Questing & Group", S):Card({
    id = "buffThanks", name = "Buff Thank You Message", order = 40, switch = "buffThanks",
    help = "Whispers thanks when a player gives you a class buff in the open world; turn friendly "
        .. "nameplates on so the game can name them.",
    rows = rows,
})

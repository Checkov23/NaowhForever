-- CoTank.lua: the Co-Tank Frame, a health bar for the other tank, with their debuffs.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local Parts = ns.Shared.Parts

local BAR = ns.Shared.Style.WHITE
local RIGHTEOUS_FURY = 25780
local PALADIN = select(2, UnitClass("player")) == "PALADIN"
local TANK_FORMS = { [5] = true, [8] = true, [18] = true }
local HIDDEN_DEBUFFS = { [6788] = true, [11196] = true, [15007] = true, [25771] = true }
local BLACK = ns.Shared.Style.BORDER_RGB
local ICON_CROP = ns.QoLConstants.ICON_CROP_TIGHT
local RING_THICKNESS = 2
local RING_STRIPS = 4
local RING_ABOVE, TEXT_ABOVE, DEBUFFS_ABOVE = 3, 1, 5
local COUNT_SIZE, STACK_NUDGE = 10, 1
local NAME_SIZE = 12
local BAR_INSET = 1
local LINE_SLACK = 0.4
local DEFAULT_X = 200
local PREVIEW_MAX, PREVIEW_VALUE = 100, 75
local PREVIEW_NAME = "TankName"
local SECONDS_PER_MINUTE, SECONDS_PER_HOUR = ns.QoLConstants.SECONDS_PER_MINUTE, ns.QoLConstants.SECONDS_PER_HOUR
local SHOW_MINUTES_FROM, SHOW_HOURS_FROM = 90, 5400
local NAME_LENGTH_RANGE, OFFSET_RANGE, DEBUFF_CAP_RANGE = { 0, 20, 1 }, { -2000, 2000, 1 }, { 1, 8, 1 }
local DEBUFF_SIZE_RANGE, DEBUFF_OFFSET_RANGE = { 10, 48, 1 }, { -200, 200, 1 }
local DEBUFF_SPACING_RANGE, DEBUFF_TEXT_RANGE, WIDTH_RANGE = { 0, 12, 1 }, { 6, 20, 1 }, { 50, 400, 5 }
local HEIGHT_RANGE = { 10, 80, 1 }
local TEXT_RANGE = ns.Shared.Style.HUD_TEXT_RANGE
local MOVER_LABEL = "Co-Tank"
local SETTINGS_PAGE, SETTINGS_CARD = "QoL/Combat", "QoL/Combat:coTank"
local SUMMARY = ns.L("%d by %d%s")
local SUMMARY_DEBUFFS = ns.L(", with debuffs")

local DEBUFF_GROUPS = {
    { key = "all",         filter = "HARMFUL" },
    { key = "important",   filter = "HARMFUL", cand = { isBossOrRoleAura = true } },
    { key = "nonplayer",   filter = "HARMFUL", cand = { isFromPlayerOrPlayerPet = false } },
    { key = "dispellable", filter = "HARMFUL|RAID_PLAYER_DISPELLABLE" },
}
for _, g in ipairs(DEBUFF_GROUPS) do
    g.cand = g.cand or {}
    g.cand.excludeSpellIDs = HIDDEN_DEBUFFS
end

local CORNERS = {
    topleft = "TOPLEFT", top = "TOP", topright = "TOPRIGHT",
    left = "LEFT", center = "CENTER", right = "RIGHT",
    bottomleft = "BOTTOMLEFT", bottom = "BOTTOM", bottomright = "BOTTOMRIGHT",
}

local MIRROR = {
    TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT",
    TOPLEFT = "BOTTOMLEFT", TOPRIGHT = "BOTTOMRIGHT",
    BOTTOMLEFT = "TOPLEFT", BOTTOMRIGHT = "TOPRIGHT",
    CENTER = "CENTER",
}

local PREVIEW_ICONS = {
    [[Interface\Icons\Spell_Shadow_ShadowWordPain]],
    [[Interface\Icons\Spell_Fire_Immolation]],
    [[Interface\Icons\Spell_Frost_FrostNova]],
    [[Interface\Icons\Spell_Nature_Earthbind]],
    [[Interface\Icons\Spell_Shadow_CurseOfSargeras]],
    [[Interface\Icons\Spell_Holy_Silence]],
    [[Interface\Icons\Ability_Poisons]],
    [[Interface\Icons\Spell_Shadow_UnholyFrenzy]],
}

local EVENTS = { "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "UPDATE_SHAPESHIFT_FORM",
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }
local UNIT_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE" }

local frame, unlocked
local tank, fury
local debuffs, styleKey
local durationFormatter
local buttons = setmetatable({}, { __mode = "k" })
local Refresh

local function On()
    return S.Get("enabled") and S.Get("coTank")
end

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

local function HasFury()
    if not C_Secrets.ShouldAurasBeSecret() then
        fury = C_UnitAuras.GetPlayerAuraBySpellID(RIGHTEOUS_FURY) ~= nil
    end
    return fury
end

local function PlayerIsTank()
    if UnitGroupRolesAssigned("player") == "TANK" then return true end
    local form = GetShapeshiftFormID()
    return TANK_FORMS[form] == true or (PALADIN and HasFury())
end

local function FindOtherTank()
    local raid = IsInRaid()
    for i = 1, raid and GetNumGroupMembers() or GetNumSubgroupMembers() do
        local unit = (raid and "raid" or "party") .. i
        local isMe, role = UnitIsUnit(unit, "player"), UnitGroupRolesAssigned(unit)
        if not (Secret(isMe) or Secret(role) or isMe)
            and (role == "TANK" or GetPartyAssignment("MAINTANK", unit)) then
            return unit
        end
    end
end

local function DurationFormatter()
    if durationFormatter then return durationFormatter end
    local Up = Enum.NumericRuleFormatRounding.Up
    durationFormatter = C_StringUtil.CreateNumericRuleFormatter()
    durationFormatter:SetBreakpoints({
        { threshold = 0, format = "%d", step = 1, rounding = Up },
        { threshold = SHOW_MINUTES_FROM, format = "%dm", step = 1, rounding = Up,
          components = { { div = SECONDS_PER_MINUTE } } },
        { threshold = SHOW_HOURS_FROM, format = "%dh", step = 1, rounding = Up,
          components = { { div = SECONDS_PER_HOUR } } },
    })
    return durationFormatter
end

local function Flow()
    local corner = CORNERS[S.Get("coTankDebuffPosition")] or "TOP"
    local grow = S.Get("coTankDebuffGrow")
    local point = MIRROR[corner]
    local h, v = grow, "UP"
    if grow == "CENTER" then
        h, v = "RIGHT", point:find("TOP", 1, true) and "DOWN" or "UP"
    elseif grow == "UP" or grow == "DOWN" then
        h, v = "RIGHT", grow
    end
    return corner, point, h, v, grow == "UP" or grow == "DOWN"
end

local function StyleButton(button, r)
    local size = S.Get("coTankDebuffSize")
    local font, outline = S.Get("coTankFont"), S.Get("coTankOutline")
    button:SetSize(size, size)
    button:SetMouseMotionEnabled(S.Get("coTankDebuffTooltips"))
    Parts.HudFont(r.duration, font, S.Get("coTankDebuffDurationSize"), outline)
    r.duration:SetShown(S.Get("coTankDebuffDuration"))
    Parts.HudFont(r.stack, font, S.Get("coTankDebuffStackSize"), outline)
    r.stack:SetShown(S.Get("coTankDebuffStacks"))
end

local function CropIcon(texture)
    texture:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
end

local function BuildCooldown(button, r)
    r.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    r.cooldown:SetAllPoints()
    r.cooldown:SetReverse(true)
    r.cooldown:SetDrawEdge(false)
    r.cooldown:SetHideCountdownNumbers(true)
    ns.Border(r.cooldown, BLACK)
end

local function BuildRing(button, r)
    local ring = CreateFrame("Frame", nil, button)
    ring:SetAllPoints()
    ring:SetFrameLevel(r.cooldown:GetFrameLevel() + RING_ABOVE)
    local strips = {}
    for i = 1, RING_STRIPS do
        strips[i] = ring:CreateTexture(nil, "OVERLAY")
        strips[i]:SetColorTexture(1, 1, 1, 1)
    end
    local w = RING_THICKNESS
    strips[1]:SetPoint("TOPLEFT"); strips[1]:SetPoint("TOPRIGHT"); strips[1]:SetHeight(w)
    strips[2]:SetPoint("BOTTOMLEFT"); strips[2]:SetPoint("BOTTOMRIGHT"); strips[2]:SetHeight(w)
    strips[3]:SetPoint("TOPLEFT", 0, -w); strips[3]:SetPoint("BOTTOMLEFT", 0, w); strips[3]:SetWidth(w)
    strips[4]:SetPoint("TOPRIGHT", 0, -w); strips[4]:SetPoint("BOTTOMRIGHT", 0, w); strips[4]:SetWidth(w)
    local ringOpts = { style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        showWhenHarmful = true, showWhenHelpful = false }
    for i = 1, RING_STRIPS do button:AddDispelTypeTexture(strips[i], ringOpts) end
    return ring
end

local function BuildCounts(button, r, ring)
    local text = CreateFrame("Frame", nil, button)
    text:SetAllPoints()
    text:SetFrameLevel(ring:GetFrameLevel() + TEXT_ABOVE)
    r.stack = ns.Font(text, COUNT_SIZE, "OUTLINE")
    r.stack:SetPoint("BOTTOMRIGHT", STACK_NUDGE, STACK_NUDGE)
    r.duration = ns.Font(text, COUNT_SIZE, "OUTLINE")
    r.duration:SetPoint("CENTER")
end

local function InitButton(button)
    local r = {}
    buttons[button] = r
    button:SetMouseClickEnabled(false)
    r.icon = button:CreateTexture(nil, "ARTWORK")
    r.icon:SetAllPoints()
    CropIcon(r.icon)
    BuildCooldown(button, r)
    BuildCounts(button, r, BuildRing(button, r))
    StyleButton(button, r)
    button:SetIcon(r.icon)
    button:SetDurationCooldown(r.cooldown)
    button:SetApplicationCount(r.stack, {})
    button:SetDurationText(r.duration, { textFormatter = DurationFormatter() })
end

local function BuildDebuffs()
    C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    debuffs = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
    debuffs:SetSize(1, 1)
    debuffs:SetFrameLevel(frame.bar:GetFrameLevel() + DEBUFFS_ABOVE)
    for _, g in ipairs(DEBUFF_GROUPS) do
        debuffs:AddAuraGroup(g.key, g.filter, {
            maxFrameCount = 0,
            candidateFilters = g.cand,
            sortMethod = AuraContainerSortMethod.Default,
            initializeFrame = InitButton,
        })
    end
    debuffs:Hide()
end

local function FlowDebuffs()
    local corner, point, h, v, vertical = Flow()
    local FD = AnchorUtil.FlowDirection
    debuffs:ClearAllPoints()
    debuffs:SetPoint(point, frame, corner, S.Get("coTankDebuffX"), S.Get("coTankDebuffY"))
    debuffs:SetFlowLayoutAnchorPoint((v == "DOWN" and "TOP" or "BOTTOM") .. (h == "LEFT" and "RIGHT" or "LEFT"))
    debuffs:SetFlowLayoutGrowthDirection(h == "LEFT" and FD.Left or FD.Right, v == "DOWN" and FD.Down or FD.Up)
    debuffs:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    debuffs:SetFlowLayoutMaximumLineSize(vertical and S.Get("coTankDebuffSize") + LINE_SLACK or nil)
end

local function SetGroups()
    local size, spacing = S.Get("coTankDebuffSize"), S.Get("coTankDebuffSpacing")
    local layout = { elementWidth = size, elementHeight = size, elementSpacing = spacing, lineSpacing = spacing }
    local active = S.Get("coTankDebuffFilter")
    for _, g in ipairs(DEBUFF_GROUPS) do
        if g.key == active then
            debuffs:SetAuraGroupMaxFrameCount(g.key, S.Get("coTankDebuffCap"))
            debuffs:SetAuraGroupCandidateFilters(g.key, g.cand)
            debuffs:SetAuraGroupLayout(g.key, layout)
        else
            debuffs:SetAuraGroupMaxFrameCount(g.key, 0)
        end
    end
end

local function RestyleButtons()
    local key = table.concat({ S.Get("coTankDebuffSize"), S.Get("coTankFont"), S.Get("coTankOutline"),
        tostring(S.Get("coTankDebuffTooltips")), tostring(S.Get("coTankDebuffDuration")),
        S.Get("coTankDebuffDurationSize"), tostring(S.Get("coTankDebuffStacks")),
        S.Get("coTankDebuffStackSize") }, "|")
    if key == styleKey or C_Secrets.ShouldAurasBeSecret() then return end
    for button, r in pairs(buttons) do StyleButton(button, r) end
    styleKey = key
end

local function LayoutDebuffs()
    FlowDebuffs()
    SetGroups()
    RestyleButtons()
end

local function BuildPreviewDebuffs()
    local host = CreateFrame("Frame", nil, frame)
    host:SetFrameLevel(frame.bar:GetFrameLevel() + DEBUFFS_ABOVE)
    host.icons = {}
    for i, path in ipairs(PREVIEW_ICONS) do
        local icon = CreateFrame("Frame", nil, host)
        icon.tex = icon:CreateTexture(nil, "ARTWORK")
        icon.tex:SetAllPoints()
        icon.tex:SetTexture(path)
        CropIcon(icon.tex)
        ns.Border(icon, BLACK)
        host.icons[i] = icon
    end
    frame.previewDebuffs = host
    return host
end

local function PlacePreviewIcon(icon, host, i, size, spacing, h, v, vertical)
    local off = (i - 1) * (size + spacing)
    icon:SetSize(size, size)
    icon:ClearAllPoints()
    if vertical then
        local from = v == "DOWN" and "TOP" or "BOTTOM"
        icon:SetPoint(from, host, from, 0, v == "DOWN" and -off or off)
    else
        local from = h == "LEFT" and "RIGHT" or "LEFT"
        icon:SetPoint(from, host, from, h == "LEFT" and -off or off, 0)
    end
end

local function ShowPreviewDebuffs(show)
    local host = frame.previewDebuffs
    if not show then
        if host then host:Hide() end
        return
    end
    host = host or BuildPreviewDebuffs()
    local corner, point, h, v, vertical = Flow()
    local size, spacing = S.Get("coTankDebuffSize"), S.Get("coTankDebuffSpacing")
    local n = math.min(S.Get("coTankDebuffCap"), #host.icons)
    local run = n * size + math.max(0, n - 1) * spacing
    host:ClearAllPoints()
    host:SetPoint(point, frame, corner, S.Get("coTankDebuffX"), S.Get("coTankDebuffY"))
    host:SetSize(vertical and size or run, vertical and run or size)
    for i, icon in ipairs(host.icons) do
        icon:SetShown(i <= n)
        if i <= n then PlacePreviewIcon(icon, host, i, size, spacing, h, v, vertical) end
    end
    host:Show()
end

local function SavePosition(pos)
    S.Set("coTankPos", pos)
    S.Set("coTankAnchor", "UIParent")
end

local function Build()
    frame = CreateFrame("Button", "NaowhForeverCoTank", UIParent, "SecureUnitButtonTemplate")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForClicks("AnyUp")
    frame:SetAttribute("type1", "target")
    frame.bg = ns.Solid(frame, "BACKGROUND", T.bg, 1)
    frame.bg:SetAllPoints()
    ns.Border(frame, BLACK)
    frame.bar = CreateFrame("StatusBar", nil, frame)
    ns.PixelInset(frame.bar, BAR_INSET)
    frame.name = ns.Font(frame.bar, NAME_SIZE, "OUTLINE")
    frame.name:SetPoint("CENTER")
    frame.mover = ns.UI.AttachMover(frame, MOVER_LABEL, SavePosition, SETTINGS_PAGE, SETTINGS_CARD)
end

local function Place()
    local pos = S.Get("coTankPos")
    local anchor = _G[S.Get("coTankAnchor")]
    frame:ClearAllPoints()
    if anchor ~= UIParent and type(anchor) == "table" and anchor.GetObjectType then
        frame:SetPoint("CENTER", anchor, "CENTER", S.Get("coTankX"), S.Get("coTankY"))
    elseif pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_X, 0)
    end
end

local function UpdateHealth()
    frame.bar:SetMinMaxValues(0, UnitHealthMax(tank))
    frame.bar:SetValue(UnitHealth(tank))
end

local function SetName(name, classColor)
    if not S.Get("coTankName") then
        frame.name:SetText("")
        return
    end
    local length = S.Get("coTankNameLength")
    if length > 0 and not Secret(name) then name = strsub(name, 1, length) end
    frame.name:SetText(name)
    local c = S.Get("coTankNameClassColor") and classColor or S.Get("coTankNameColor")
    frame.name:SetTextColor(c.r, c.g, c.b, 1)
end

local function Paint()
    local _, class = UnitClass(tank)
    local classColor = not Secret(class) and RAID_CLASS_COLORS[class]
    local c = S.Get("coTankClassColor") and classColor or S.Get("coTankColor")
    frame.bar:SetStatusBarColor(c.r, c.g, c.b)
    SetName(UnitName(tank), classColor)
    UpdateHealth()
end

local function Preview()
    local c = S.Get("coTankColor")
    frame.bar:SetStatusBarColor(c.r, c.g, c.b)
    frame.bar:SetMinMaxValues(0, PREVIEW_MAX)
    frame.bar:SetValue(PREVIEW_VALUE)
    SetName(PREVIEW_NAME, nil)
end

local function OnEvent(_, event)
    if event == "UNIT_AURA" then
        local was = fury
        if HasFury() == was then return end
    end
    Refresh()
end

local function OnUnitEvent(_, event)
    if event == "UNIT_NAME_UPDATE" then
        Paint()
    else
        UpdateHealth()
    end
end

local events = CreateFrame("Frame")
local unitEvents = CreateFrame("Frame")
events:SetScript("OnEvent", OnEvent)
unitEvents:SetScript("OnEvent", OnUnitEvent)

local function Restyle()
    frame:SetSize(S.Get("coTankWidth"), S.Get("coTankHeight"))
    frame.bg:SetAlpha(S.Get("coTankBgAlpha"))
    frame.bar:SetStatusBarTexture(ns.UI.TexturePath(S.Get("coTankTexture"), BAR))
    Parts.HudFont(frame.name, S.Get("coTankFont"), S.Get("coTankFontSize"), S.Get("coTankOutline"))
end

local function ShowDebuffs(showDebuffs)
    if showDebuffs and tank then
        if not debuffs then BuildDebuffs() end
        LayoutDebuffs()
        debuffs:SetUnit(tank)
        debuffs:Show()
        debuffs:UpdateAllAuras()
    elseif debuffs then
        debuffs:Hide()
    end
end

local function Watch()
    for _, event in ipairs(EVENTS) do events:RegisterEvent(event) end
    if PALADIN then events:RegisterUnitEvent("UNIT_AURA", "player") end
end

local function Show()
    local showDebuffs = S.Get("coTankDebuffs")
    if tank then
        for _, event in ipairs(UNIT_EVENTS) do unitEvents:RegisterUnitEvent(event, tank) end
        Paint()
    elseif unlocked then
        Preview()
    end
    ShowPreviewDebuffs(showDebuffs and not tank and unlocked == true)
    ShowDebuffs(showDebuffs)
    frame:SetShown(tank ~= nil or unlocked == true)
end

function Refresh()
    if InCombatLockdown() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    events:UnregisterAllEvents()
    unitEvents:UnregisterAllEvents()
    tank = nil
    if not On() then
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() end
    Watch()
    tank = PlayerIsTank() and FindOtherTank() or nil
    frame:SetAttribute("unit", tank)
    Restyle()
    Place()
    frame.mover:SetShown(unlocked == true)
    Show()
end

local function OnSettingChanged(key)
    if key == "enabled" or (key:find("^coTank") and key ~= "coTankPos") then Refresh() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", function() Refresh() end)
hooksecurefunc(ns, "ShowUnlockMode", function()
    unlocked = S.Get("enabled") == true
    Refresh()
end)
hooksecurefunc(ns, "HideUnlockMode", function()
    unlocked = false
    Refresh()
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function() Refresh() end)

local Group = ns.Shared.Settings.Group
local FILTER = { { important = "Boss & Important", nonplayer = "Non-Player Auras", all = "All Debuffs",
    dispellable = "Dispellable by You" }, { "important", "nonplayer", "all", "dispellable" } }
local POSITION = { { top = "Above", bottom = "Below", left = "Left", right = "Right", topleft = "Top Left",
    topright = "Top Right", bottomleft = "Bottom Left", bottomright = "Bottom Right", center = "Centre" },
    { "top", "bottom", "left", "right", "topleft", "topright", "bottomleft", "bottomright", "center" } }
local GROW = { { CENTER = "Centred", RIGHT = "Right", LEFT = "Left", UP = "Up", DOWN = "Down" },
    { "CENTER", "RIGHT", "LEFT", "UP", "DOWN" } }
local FROM_ANCHOR = ns.L("From the centre of the anchor frame. Only used while anchored to a frame.")

local function OwnHealthColour() return not S.Get("coTankClassColor") end
local function OwnNameColour() return S.Get("coTankName") and not S.Get("coTankNameClassColor") end

local function Summary(store)
    return SUMMARY:format(store.Get("coTankWidth"), store.Get("coTankHeight"),
        store.Get("coTankDebuffs") and SUMMARY_DEBUFFS or "")
end

ns.Shared.Settings.Page("QoL/Combat", S):Card({
    id = "coTank", name = "Co-Tank Frame", order = 40, switch = "coTank",
    help = "A small health bar for the other tank in your group, shown while you are tanking: "
        .. "tank role, Bear Form, Defensive Stance or Righteous Fury. The other tank is whoever has "
        .. "the tank role or the raid's Main Tank assignment. Click it to target them. Changes made "
        .. "in combat apply when the fight ends. Move it in the HUD Editor.",
    summary = Summary,
    rows = {
        Group("Name"),
        { key = "coTankName", label = "Show Name", toggle = true },
        { key = "coTankNameLength", label = "Name Length", slider = NAME_LENGTH_RANGE, needs = "coTankName",
          help = "Cuts the name to this many letters. 0 shows it whole." },
        Group("Position"),
        { key = "coTankAnchor", label = "Anchor to a Frame", text = true, wide = true,
          help = "Frame to anchor to, such as PlayerFrame. UIParent puts it back on the screen, and so "
              .. "does dragging it in the HUD Editor." },
        { key = "coTankX", label = "X Offset", slider = OFFSET_RANGE, help = FROM_ANCHOR },
        { key = "coTankY", label = "Y Offset", slider = OFFSET_RANGE, help = FROM_ANCHOR },
        Group("Debuffs"),
        { key = "coTankDebuffs", label = "Co-Tank Debuffs", toggle = true,
          help = "Shows the other tank's debuffs beside their health bar, in combat too: tank-buster "
              .. "stacks, boss debuffs and anything you can dispel." },
        { key = "coTankDebuffFilter", label = "Filter", choice = FILTER, needs = "coTankDebuffs" },
        { key = "coTankDebuffCap", label = "Max Icons", slider = DEBUFF_CAP_RANGE, needs = "coTankDebuffs" },
        { key = "coTankDebuffSize", label = "Icon Size", slider = DEBUFF_SIZE_RANGE, needs = "coTankDebuffs" },
        { key = "coTankDebuffPosition", label = "Position", choice = POSITION, needs = "coTankDebuffs" },
        { key = "coTankDebuffGrow", label = "Grow", choice = GROW, needs = "coTankDebuffs" },
        { key = "coTankDebuffX", label = "Offset X", slider = DEBUFF_OFFSET_RANGE, needs = "coTankDebuffs" },
        { key = "coTankDebuffY", label = "Offset Y", slider = DEBUFF_OFFSET_RANGE, needs = "coTankDebuffs" },
        { key = "coTankDebuffSpacing", label = "Spacing", slider = DEBUFF_SPACING_RANGE, needs = "coTankDebuffs" },
        { key = "coTankDebuffTooltips", label = "Show Tooltips", toggle = true, needs = "coTankDebuffs",
          help = "Off by default: the bar under the icons is click-to-target." },
        { key = "coTankDebuffDuration", label = "Show Time Left", toggle = true, needs = "coTankDebuffs" },
        { key = "coTankDebuffDurationSize", label = "Time Left Size", slider = DEBUFF_TEXT_RANGE,
          needs = { "coTankDebuffs", "coTankDebuffDuration" } },
        { key = "coTankDebuffStacks", label = "Show Stacks", toggle = true, needs = "coTankDebuffs" },
        { key = "coTankDebuffStackSize", label = "Stacks Size", slider = DEBUFF_TEXT_RANGE,
          needs = { "coTankDebuffs", "coTankDebuffStacks" } },
        Group("Size"),
        { key = "coTankWidth", label = "Width", slider = WIDTH_RANGE },
        { key = "coTankHeight", label = "Height", slider = HEIGHT_RANGE },
        ns.Shared.Settings.Look("coTank", { text = true, size = TEXT_RANGE, bar = "Flat", background = "alpha" }),
        Group("Colors"),
        { key = "coTankClassColor", label = "Class Color Health", toggle = true },
        { key = "coTankColor", label = "Health Color", colour = true, needs = OwnHealthColour,
          why = "Class color is on" },
        { key = "coTankNameClassColor", label = "Class Color Name", toggle = true, needs = "coTankName" },
        { key = "coTankNameColor", label = "Name Color", colour = true, needs = OwnNameColour,
          why = "Needs Show Name, class color off" },
    },
})

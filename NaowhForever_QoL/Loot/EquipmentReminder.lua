-- EquipmentReminder.lua: Equipment Reminder, your trinkets, weapons and enchants in a window before the pull.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME

local SHOWN_SLOTS = {
    { id = 13, name = "Trinket 1" }, { id = 14, name = "Trinket 2" },
    { id = 16, name = "Main Hand" }, { id = 17, name = "Off Hand" }, { id = 18, name = "Ranged" },
}
local ENCHANT_SLOTS = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs",
    [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Ring 1", [12] = "Ring 2", [15] = "Back",
    [16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged",
}
local SPACING = 6
local ICON_CROP = ns.QoLConstants.ICON_CROP
local BG_ALPHA = 0.95
local TITLE_SIZE, TITLE_Y = 13, -8
local CLOSE_SIZE, CLOSE_INSET = 18, 4
local STATUS_W, STATUS_H, STATUS_Y, STATUS_SIZE = 200, 18, 6, 12
local ICONS_Y = -30
local MIN_WIDTH, SIDE_ROOM = 200, 20
local ROOM_WITH_STATUS, ROOM_PLAIN = 66, 44
local DEFAULT_Y = 100
local INSTANCE_DELAY, READY_CHECK_DELAY = 1, 0.2
local HIDE_AFTER_RANGE, ICON_RANGE = { 0, 60, 1 }, { 24, 64, 1 }
local BLACK = ns.Shared.Style.BORDER_RGB
local ISSUE_RGB = { r = 1, g = 0.4, b = 0.4 }
local WHITE_RGB = ns.QoLConstants.WHITE_RGB
local PROBLEM_RGB = { r = 1, g = 0.5, b = 0.3 }
local LABEL_RGB = { r = 0.6, g = 0.6, b = 0.6 }
local HAVE_RGB = { r = 1, g = 0.5, b = 0.5 }
local EXPECTED_RGB = { r = 0.5, g = 0.8, b = 0.5 }
local ENCHANTED = "Enchanted: (.+)"
local TITLE = ns.L("Equipment Check")
local CLOSE = "X"
local SLOT_FALLBACK = ns.L("Slot ")
local EMPTY = ns.L(" - Empty")
local TEXT_ISSUES = ns.L("Enchant Issues")
local TEXT_WRONG, TEXT_MISSING = ns.L("Wrong Enchant"), ns.L("Missing")
local TEXT_HAVE, TEXT_EXPECTED = ns.L("  Have:"), ns.L("  Expected:")
local TEXT_OK = ns.L("|cff4dd17aEnchants OK|r")
local TEXT_COUNT_ONE, TEXT_COUNT = ns.L("|cffff6666%d Enchant Issue|r"), ns.L("|cffff6666%d Enchant Issues|r")
local TEXT_CAPTURED_ONE = ns.L("Captured %d enchant from your gear. The enchant check expects these from now on.")
local TEXT_CAPTURED = ns.L("Captured %d enchants from your gear. The enchant check expects these from now on.")

local frame, hideTimer
local buttons = {}

local function On()
    return S.Get("enabled") and S.Get("equipReminder")
end

local function Plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|A.-|a", ""))
end

local function EnchantName(slot)
    local data = C_TooltipInfo.GetInventoryItem("player", slot)
    for _, line in ipairs(data and data.lines or {}) do
        if line.type == Enum.TooltipDataLineType.ItemEnchantmentPermanent then
            local text = line.leftText
            return Plain(text:match(ENCHANTED) or text)
        end
    end
end

function ns.CaptureEnchants()
    local rules, count = {}, 0
    for slot in pairs(ENCHANT_SLOTS) do
        local name = GetInventoryItemID("player", slot) and EnchantName(slot)
        if name then
            rules[slot] = name
            count = count + 1
        end
    end
    S.Set("equipEnchantRules", rules)
    return count
end

local function BySlot(a, b)
    return a.slot < b.slot
end

local function EnchantIssues()
    local issues = {}
    for slot, expected in pairs(S.Get("equipEnchantRules")) do
        if GetInventoryItemID("player", slot) then
            local have = EnchantName(slot)
            if have ~= expected then
                local name = ENCHANT_SLOTS[slot] and ns.Shared.Items.SlotName(slot)
                issues[#issues + 1] = { slot = name or (SLOT_FALLBACK .. slot), have = have,
                    expected = expected }
            end
        end
    end
    table.sort(issues, BySlot)
    return issues
end

local function SlotEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    if GetInventoryItemID("player", self.slot.id) then
        GameTooltip:SetInventoryItem("player", self.slot.id)
    else
        GameTooltip:SetText((ns.Shared.Items.SlotName(self.slot.id) or self.slot.name) .. EMPTY)
    end
    GameTooltip:Show()
end

local function SlotButton(slot)
    local b = CreateFrame("Button", nil, frame)
    b.slot = slot
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    b.border = ns.Border(b)
    b:SetScript("OnEnter", SlotEnter)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

local function AddIssue(issue)
    GameTooltip:AddDoubleLine(issue.slot .. ":", issue.have and TEXT_WRONG or TEXT_MISSING,
        WHITE_RGB.r, WHITE_RGB.g, WHITE_RGB.b, PROBLEM_RGB.r, PROBLEM_RGB.g, PROBLEM_RGB.b)
    if issue.have then
        GameTooltip:AddDoubleLine(TEXT_HAVE, issue.have, LABEL_RGB.r, LABEL_RGB.g, LABEL_RGB.b,
            HAVE_RGB.r, HAVE_RGB.g, HAVE_RGB.b)
    end
    GameTooltip:AddDoubleLine(TEXT_EXPECTED, issue.expected, LABEL_RGB.r, LABEL_RGB.g, LABEL_RGB.b,
        EXPECTED_RGB.r, EXPECTED_RGB.g, EXPECTED_RGB.b)
end

local function StatusEnter(self)
    if not self.issues or #self.issues == 0 then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(TEXT_ISSUES, ISSUE_RGB.r, ISSUE_RGB.g, ISSUE_RGB.b)
    for _, issue in ipairs(self.issues) do AddIssue(issue) end
    GameTooltip:Show()
end

local function SavePosition(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    S.Set("equipPos", { point = point, relPoint = relPoint, x = x, y = y })
end

local function CancelHide()
    if hideTimer then hideTimer:Cancel(); hideTimer = nil end
end

local function Close()
    frame:Hide()
    CancelHide()
end

local function AutoHide()
    hideTimer = nil
    frame:Hide()
end

local function BuildStatus()
    frame.status = CreateFrame("Frame", nil, frame)
    frame.status:SetSize(STATUS_W, STATUS_H)
    frame.status:SetPoint("BOTTOM", 0, STATUS_Y)
    frame.status:EnableMouse(true)
    frame.status.text = ns.Font(frame.status, STATUS_SIZE)
    frame.status.text:SetPoint("CENTER")
    frame.status:SetScript("OnEnter", StatusEnter)
    frame.status:SetScript("OnLeave", GameTooltip_Hide)
end

local function Build()
    frame = CreateFrame("Frame", "NaowhForeverEquipmentReminder", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    ns.AllowOffscreen(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", SavePosition)
    ns.Solid(frame, "BACKGROUND", T.bg, BG_ALPHA):SetAllPoints()
    ns.Border(frame, T.accent)
    local title = ns.Font(frame, TITLE_SIZE, nil, T.accent)
    title:SetPoint("TOP", 0, TITLE_Y)
    title:SetText(TITLE)
    local close = ns.Button(frame, CLOSE, CLOSE_SIZE, CLOSE_SIZE, Close)
    close:SetPoint("TOPRIGHT", -CLOSE_INSET, -CLOSE_INSET)
    for i, slot in ipairs(SHOWN_SLOTS) do buttons[i] = SlotButton(slot) end
    BuildStatus()
    frame:Hide()
end

local function PaintSlot(b, i, size, width)
    b:SetSize(size, size)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", frame, "TOP", -width / 2 + (i - 1) * (size + SPACING), ICONS_Y)
    local texture = GetInventoryItemTexture("player", b.slot.id)
    b.icon:SetTexture(texture)
    local quality = texture and GetInventoryItemQuality("player", b.slot.id)
    if quality then
        local r, g, bl = C_Item.GetItemQualityColor(quality)
        b.border:SetColor(r, g, bl)
    else
        b.border:SetColor(BLACK.r, BLACK.g, BLACK.b)
    end
end

local function PaintStatus()
    local issues = EnchantIssues()
    frame.status.issues = issues
    if #issues == 0 then
        frame.status.text:SetText(TEXT_OK)
    else
        frame.status.text:SetText((#issues > 1 and TEXT_COUNT or TEXT_COUNT_ONE):format(#issues))
    end
end

local function Refresh()
    local size = S.Get("equipIconSize")
    local width = #SHOWN_SLOTS * size + (#SHOWN_SLOTS - 1) * SPACING
    for i, b in ipairs(buttons) do PaintSlot(b, i, size, width) end
    local enchants = S.Get("equipEnchants")
    frame.status:SetShown(enchants)
    if enchants then PaintStatus() end
    frame:SetSize(math.max(MIN_WIDTH, width + SIDE_ROOM), size + (enchants and ROOM_WITH_STATUS or ROOM_PLAIN))
end

local function Place()
    local pos = S.Get("equipPos")
    frame:ClearAllPoints()
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_Y)
    end
end

function ns.ShowEquipmentReminder()
    if InCombatLockdown() then return end
    if not frame then Build() end
    Place()
    Refresh()
    frame:Show()
    CancelHide()
    local delay = S.Get("equipAutoHide")
    if delay > 0 then hideTimer = C_Timer.NewTimer(delay, AutoHide) end
end

local function ShowIfStillOn()
    if On() and not InCombatLockdown() then ns.ShowEquipmentReminder() end
end

local function ShowSoon(delay)
    C_Timer.After(delay, ShowIfStillOn)
end

local function OnEnteringWorld()
    local inInstance, kind = IsInInstance()
    if inInstance and (kind == "party" or kind == "raid") and S.Get("equipOnInstance") then
        ShowSoon(INSTANCE_DELAY)
    end
end

local function OnEvent(_, event, arg)
    if event == "PLAYER_ENTERING_WORLD" then
        OnEnteringWorld()
    elseif event == "READY_CHECK" then
        if S.Get("equipOnReadyCheck") then ShowSoon(READY_CHECK_DELAY) end
    elseif event == "UNIT_INVENTORY_CHANGED" and arg == "player" and frame and frame:IsShown() then
        Refresh()
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", OnEvent)

local function Apply()
    events:UnregisterAllEvents()
    if not On() then
        if frame then frame:Hide() end
        return
    end
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("READY_CHECK")
    events:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
    if frame and frame:IsShown() then Refresh() end
end

local function OnSettingChanged(key)
    if key == "enabled" or (key:find("^equip") and key ~= "equipPos") then Apply() end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local function CaptureClicked()
    local count = ns.CaptureEnchants()
    ns.Print((count == 1 and TEXT_CAPTURED_ONE or TEXT_CAPTURED):format(count))
end

local function ShowClicked()
    ns.ShowEquipmentReminder()
end

ns.Shared.Settings.Page("QoL/Loot & Items", S):Card({
    id = "equipReminder", name = "Equipment Reminder", order = 90, switch = "equipReminder",
    help = "Your trinkets, weapons and ranged slot in a small window when you enter a dungeon "
        .. "or raid, or on a ready check, so a wrong trinket gets noticed before the pull. "
        .. "Drag the window to move it.",
    rows = {
        { key = "equipEnchants", label = "Enchant Check", toggle = true,
          help = "Adds a line that flags any slot whose enchant is missing or differs from the ones "
              .. "you captured with Capture Current Enchants. Hover it for the details." },
        { key = "equipOnInstance", label = "Show Entering Dungeons & Raids", toggle = true },
        { key = "equipOnReadyCheck", label = "Show on Ready Check", toggle = true },
        { key = "equipAutoHide", label = "Hide After", slider = HIDE_AFTER_RANGE, unit = "s",
          help = "0 keeps it up until you close it." },
        { key = "equipIconSize", label = "Icon Size", slider = ICON_RANGE },
        { label = "Capture Current Enchants", button = CaptureClicked, buttonText = "Capture", always = true,
          help = "Saves the enchants on your gear now as the ones the Enchant Check expects." },
        { label = "Show Equipment Check", button = ShowClicked, buttonText = "Show", always = true,
          help = "Opens the window now, out of combat." },
    },
})

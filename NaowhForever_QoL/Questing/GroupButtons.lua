-- GroupButtons.lua: On-Screen Buttons, Invite and Disband on screen, stacked or side by side.
local ns = _G.NaowhForever

local UI = ns.UI
local T = ns.THEME
local S = ns.QoLSettings
local Parts = ns.Shared.Parts

local GAP, FILL_ALPHA = 4, 0.9
local BLACK = ns.Shared.Style.BORDER_RGB
local LABEL_SIZE = 12
local DEFAULT_X, DEFAULT_Y = 40, -40
local BUTTONS_PER_BAR = 2
local WIDTH_RANGE, HEIGHT_RANGE = { 60, 200, 1 }, { 16, 48, 1 }
local TEXT_RANGE = ns.Shared.Style.HUD_TEXT_RANGE
local MOVER_LABEL = "Group Buttons"
local SETTINGS_PAGE = "QoL/Questing & Group"
local SETTINGS_CARD = "QoL/Questing & Group:groupButtons"
local TEXT_INVITE, TIP_INVITE = ns.L("Invite"), ns.L("Invites your target. Works in combat.")
local TEXT_DISBAND = ns.L("Disband")
local TIP_DISBAND = ns.L("Removes everyone from your group. Group leader only, out of combat.")
local TEXT_IN_COMBAT = ns.L("The group can be disbanded once the fight is over.")
local TEXT_ASK_NAME = ns.L("Invite which player?")
local LAYOUT_NAMES = { stacked = "Stacked", row = "Side by Side" }
local SUMMARY_ROW, SUMMARY_STACKED = ns.L("Side by Side"), ns.L("Invite over Disband")

local bar, moving, pending
local events = CreateFrame("Frame")
local buttons = {}

local function Enter(button)
    button.border:SetColor(T.accent.r, T.accent.g, T.accent.b, 1)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(button.label:GetText(), 1, 1, 1)
    GameTooltip:AddLine(button.tip, T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function Leave(button)
    button.border:SetColor(BLACK.r, BLACK.g, BLACK.b, 1)
    GameTooltip:Hide()
end

local function Style(button, text, tip)
    button.backdrop = Parts.HudBackdrop(button, { color = T.panel, alpha = FILL_ALPHA })
    button.border = button.backdrop.border
    button.label = ns.Font(button, LABEL_SIZE)
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    button.tip = tip
    button:SetScript("OnEnter", Enter)
    button:SetScript("OnLeave", Leave)
end

local function OnDisbandClick()
    if InCombatLockdown() then
        ns.Print(TEXT_IN_COMBAT)
        return
    end
    ns.DisbandGroup()
end

local function SavePosition(pos)
    S.Set("groupButtonsPos", pos)
end

local function Build()
    bar = CreateFrame("Frame", "NaowhForeverGroupButtons", UIParent)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar.invite = CreateFrame("Button", nil, bar, "SecureActionButtonTemplate")
    bar.invite:RegisterForClicks("AnyUp", "AnyDown")
    bar.invite:SetAttribute("type1", "macro")
    bar.invite:SetAttribute("macrotext1", "/invite")
    Style(bar.invite, TEXT_INVITE, TIP_INVITE)
    bar.disband = CreateFrame("Button", nil, bar)
    bar.disband:SetScript("OnClick", OnDisbandClick)
    Style(bar.disband, TEXT_DISBAND, TIP_DISBAND)
    bar.mover = UI.AttachMover(bar, MOVER_LABEL, SavePosition, SETTINGS_PAGE, SETTINGS_CARD)
    buttons[1], buttons[2] = bar.invite, bar.disband
end

local function StyleButtons(w, h)
    local font, size, outline = S.Get("groupButtonsFont"), S.Get("groupButtonsFontSize"), S.Get("groupButtonsOutline")
    local background = S.Get("groupButtonsBackground")
    for _, button in ipairs(buttons) do
        button:SetSize(w, h)
        button.backdrop:SetMode(background)
        Parts.HudFont(button.label, font, size, outline, background)
    end
end

local function Arrange(w, h)
    local stacked = S.Get("groupButtonsLayout") ~= "row"
    if stacked then
        bar:SetSize(w, h * BUTTONS_PER_BAR + GAP)
    else
        bar:SetSize(w * BUTTONS_PER_BAR + GAP, h)
    end
    bar.invite:ClearAllPoints()
    bar.invite:SetPoint("TOPLEFT")
    bar.disband:ClearAllPoints()
    if stacked then
        bar.disband:SetPoint("TOPLEFT", bar.invite, "BOTTOMLEFT", 0, -GAP)
    else
        bar.disband:SetPoint("TOPLEFT", bar.invite, "TOPRIGHT", GAP, 0)
    end
end

local function Place()
    bar:ClearAllPoints()
    local pos = S.Get("groupButtonsPos")
    if pos then
        bar:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        bar:SetPoint("LEFT", UIParent, "LEFT", DEFAULT_X, DEFAULT_Y)
    end
end

local function Apply()
    if InCombatLockdown() then
        pending = true
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    pending = false
    if not (S.Get("enabled") and S.Get("groupButtons")) then
        if bar then bar:Hide() end
        return
    end
    if not bar then Build() end
    local w, h = S.Get("groupButtonsWidth"), S.Get("groupButtonsHeight")
    StyleButtons(w, h)
    Arrange(w, h)
    Place()
    bar.mover:SetShown(moving == true)
    bar:Show()
end

local function OnCombatEnded()
    events:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if pending then Apply() end
end

local function OnSettingChanged(key)
    if key == "enabled" or key:find("^groupButtons") and key ~= "groupButtonsPos" then Apply() end
end

local function OnLogin(self)
    self:UnregisterAllEvents()
    Apply()
end

events:SetScript("OnEvent", OnCombatEnded)
hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", function() moving = true; Apply() end)
hooksecurefunc(ns, "HideUnlockMode", function() moving = false; Apply() end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", OnLogin)

local Settings = ns.Shared and ns.Shared.Settings
if not Settings then return end
local LAYOUT = { LAYOUT_NAMES, { "stacked", "row" } }

local function Disband()
    ns.DisbandGroup()
end

local function InviteName(name)
    C_PartyInfo.InviteUnit(name)
end

local function Invite()
    ns.PromptText(TEXT_ASK_NAME, "", 0, InviteName)
end

local function LayoutSummary(store)
    return store.Get("groupButtonsLayout") == "row" and SUMMARY_ROW or SUMMARY_STACKED
end

Settings.Page("QoL/Questing & Group", S):Card({
    id = "groupButtons", name = "On-Screen Buttons", order = 20, switch = "groupButtons",
    help = "Invite and Disband as buttons on your screen, to click without opening /nf. Invite "
        .. "invites your target and works in combat; Disband works out of combat. Move them "
        .. "in the HUD Editor.",
    summary = LayoutSummary,
    rows = {
        { key = "groupButtonsLayout", label = "Button Layout", choice = LAYOUT,
          help = "Invite over Disband, or side by side." },
        { label = "Disband Group", button = Disband, buttonText = "Disband", always = true,
          help = "Removes everyone from your group. Group leader only." },
        { label = "Invite Player", button = Invite, buttonText = "Invite", always = true,
          help = "Type a name and invite them. Handy when you play with the same people." },
        Settings.Group("Size"),
        { key = "groupButtonsWidth", label = "Button Width", slider = WIDTH_RANGE },
        { key = "groupButtonsHeight", label = "Button Height", slider = HEIGHT_RANGE },
        Settings.Look("groupButtons", { text = true, size = TEXT_RANGE, background = "card" }),
    },
})

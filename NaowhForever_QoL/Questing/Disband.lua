-- Disband.lua: removing everyone from your group (ns.DisbandGroup), for the Disband button.
local ns = _G.NaowhForever

local TEXT_NO_GROUP = ns.L("You are not in a group.")
local TEXT_NOT_LEADER = ns.L("Only the group leader can disband the group.")
local TEXT_DISBAND = ns.L("Remove everyone from your group?")
local TEXT_IN_COMBAT = ns.L("The group can be disbanded once the fight is over.")
local TEXT_TRY_AGAIN = ns.L("The group was not disbanded. Open Disband and click Yes again.")
local GLOW_ALPHA = 0.08

local kicker, armed

local function Macro()
    local lines = {}
    local prefix = IsInRaid() and "raid" or "party"
    for i = GetNumGroupMembers(), 1, -1 do
        local unit = prefix .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local name = GetUnitName(unit, true)
            if name then lines[#lines + 1] = "/uninvite " .. name end
        end
    end
    return table.concat(lines, "\n")
end

ns.DisbandMacro = Macro

local function Disarm()
    armed = nil
    if kicker and not InCombatLockdown() then kicker:Hide() end
end

local function HideOnLeave(self)
    if not InCombatLockdown() then self:Hide() end
end

local function AfterKick(_, _, down)
    if down then return end
    local dimmer = armed
    Disarm()
    if dimmer then dimmer:Hide() end
end

local function Kicker()
    if kicker then return kicker end
    kicker = CreateFrame("Button", "NaowhForeverDisbandButton", UIParent, "SecureActionButtonTemplate")
    kicker:SetFrameStrata("TOOLTIP")
    kicker:RegisterForClicks("AnyUp", "AnyDown")
    kicker:SetAttribute("type", "macro")
    local glow = kicker:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 1, 1, GLOW_ALPHA)
    kicker:SetScript("OnLeave", HideOnLeave)
    kicker:SetScript("PostClick", AfterKick)
    kicker:RegisterEvent("PLAYER_REGEN_DISABLED")
    kicker:SetScript("OnEvent", kicker.Hide)
    kicker:Hide()
    return kicker
end

local function CoverYes(yes)
    if not armed or armed.onClose ~= Disarm or InCombatLockdown() or not yes:GetLeft() then return end
    local cover = Kicker()
    local scale = yes:GetEffectiveScale() / UIParent:GetEffectiveScale()
    cover:SetAttribute("macrotext", Macro())
    cover:ClearAllPoints()
    cover:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", yes:GetLeft() * scale, yes:GetBottom() * scale)
    cover:SetSize(yes:GetWidth() * scale, yes:GetHeight() * scale)
    cover:Show()
end

local function NotCovered()
    Disarm()
    ns.Print(TEXT_TRY_AGAIN)
end

function ns.DisbandGroup()
    if InCombatLockdown() then ns.Print(TEXT_IN_COMBAT); return end
    if not IsInGroup() then ns.Print(TEXT_NO_GROUP); return end
    if not UnitIsGroupLeader("player") then ns.Print(TEXT_NOT_LEADER); return end
    local yes, dimmer = ns.Confirm(TEXT_DISBAND, NotCovered, Disarm)
    if not yes then return end
    if not yes._disbandHooked then
        yes._disbandHooked = true
        yes:HookScript("OnEnter", CoverYes)
    end
    armed = dimmer
    if yes:IsMouseOver() then CoverYes(yes) end
end

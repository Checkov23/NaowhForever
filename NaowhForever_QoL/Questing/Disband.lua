-- Disband.lua: removing everyone from your group (ns.DisbandGroup), for the Disband button.
local ns = _G.NaowhForever

local TEXT_NO_GROUP = ns.L("You are not in a group.")
local TEXT_NOT_LEADER = ns.L("Only the group leader can disband the group.")
local TEXT_DISBAND = ns.L("Remove everyone from your group?")
local TEXT_IN_COMBAT = ns.L("The group can be disbanded once the fight is over.")

local function Disband()
    if InCombatLockdown() then
        ns.Print(TEXT_IN_COMBAT)
        return
    end
    local prefix = IsInRaid() and "raid" or "party"
    for i = GetNumGroupMembers(), 1, -1 do
        local unit = prefix .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then C_PartyInfo.UninviteUnit(GetUnitName(unit, true)) end
    end
end

function ns.DisbandGroup()
    if not IsInGroup() then ns.Print(TEXT_NO_GROUP); return end
    if not UnitIsGroupLeader("player") then ns.Print(TEXT_NOT_LEADER); return end
    ns.Confirm(TEXT_DISBAND, Disband)
end

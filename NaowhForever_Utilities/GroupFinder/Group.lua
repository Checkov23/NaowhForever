-- Group.lua: your group in Forever's group finder: listing and delisting it, its applicants invited or declined, and what Naowh Forever players are told about it (ns.GroupFinder.Group).
local ns = _G.NaowhForever

local GF = ns.GroupFinder
if not GF then return end
local Comms = GF.Comms
local S = GF.Settings

local EVENTS = { "LFG_LIST_ACTIVE_ENTRY_UPDATE", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED" }
local TEXT_DECLINE_LATER = ns.L("Too many whispers are waiting to be sent. Try Decline again in a moment.")

local Group = {
    activity = nil, style = nil, min = 0, tanks = 1, healers = 1, damage = 3, note = "",
    ours = false, listedAt = nil,
}
GF.Group = Group

local createData = { activityIDs = {}, generalPlaystyle = 0 }
local frame, on = nil, false

function Group.Listed()
    return C_LFGList.HasActiveEntryInfo()
end

function Group.CanEdit()
    return not IsInGroup(LE_PARTY_CATEGORY_HOME) or UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME)
end

function Group.Answering()
    return Group.Listed() and Group.CanEdit()
end

function Group.Ready()
    return Group.activity ~= nil and Group.style ~= nil
end

function Group.List()
    if not (GF.On() and Group.Ready() and Group.CanEdit()) then return false end
    createData.activityIDs[1] = Group.activity
    createData.generalPlaystyle = Group.style
    local ok
    if Group.Listed() then
        ok = C_LFGList.UpdateListing(createData)
    else
        ok = C_LFGList.CreateListing(createData)
    end
    if ok then
        Group.ours = true
        Group.listedAt = Group.listedAt or GetTime()
    end
    GF.Fire("group")
    return ok
end

function Group.Delist()
    if not (Group.Listed() and Group.CanEdit()) then return false end
    C_LFGList.RemoveListing()
    return true
end

function Group.Info()
    if Group.ours and Group.Listed() then return Group end
end

function Group.Invite(record)
    if record.invited or not (Group.Answering() and Comms.HasApplicant(record)) then return false end
    C_PartyInfo.InviteUnit(record.name)
    record.invited = true
    GF.Fire("applicant", record)
    return true
end

function Group.Decline(record)
    if not (Group.Answering() and Comms.HasApplicant(record)) then return false end
    if not Comms.Decline(record.name) then
        ns.Print(TEXT_DECLINE_LATER)
        return false
    end
    GF.Fire("applicant")
    return true
end

local function OnEvent()
    if not Group.Listed() then Group.ours, Group.listedAt = false, nil end
    GF.Fire("group")
end

local function Sync()
    local want = GF.On()
    if want == on then return end
    on = want
    if want then
        if not frame then
            frame = CreateFrame("Frame")
            frame:SetScript("OnEvent", OnEvent)
        end
        for _, event in ipairs(EVENTS) do frame:RegisterEvent(event) end
    else
        frame:UnregisterAllEvents()
        Group.ours, Group.listedAt = false, nil
    end
end

S.OnChange(function(key)
    if key == "enabled" then Sync() end
end)
hooksecurefunc(ns, "Apply", Sync)

-- FinderRoles.lua: Group Finder Roles, role buttons on the Group Finder for players of a role and groups that need one.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local Parts = ns.Shared.Parts
local St = ns.Shared.Style

local BUTTON_SIZE = 22
local BUTTON_GAP = 4
local LABEL_GAP = 8
local SET_GAP = 16
local ROW_DROP = 10
local OFF_ALPHA = 0.4
local HINT_WIDTH = 240
local TEXT_PLAYERS = ns.L("Players:")
local TEXT_NEEDS = ns.L("Groups need:")
local TEXT_PLAYER_TIP = ns.L("Show players who signed up as %s.")
local TEXT_NEED_TIP = ns.L("Show groups that still have room for a %s.")
local TEXT_ALL_HIDDEN = ns.L("Your Group Finder Roles picks hide every listing.")

local TANK = { field = "tank", remaining = "TANK_REMAINING", atlas = "groupfinder-icon-role-large-tank", name = "Tank" }
local HEALER = { field = "healer", remaining = "HEALER_REMAINING", atlas = "groupfinder-icon-role-large-heal", name = "Healer" }
local DAMAGE = { field = "dps", remaining = "DAMAGER_REMAINING", atlas = "groupfinder-icon-role-large-dps", name = "Damage" }

local PLAYERS = {
    label = TEXT_PLAYERS, tip = TEXT_PLAYER_TIP,
    { key = "finderRolesTank", role = TANK },
    { key = "finderRolesHealer", role = HEALER },
    { key = "finderRolesDps", role = DAMAGE },
}
local NEEDS = {
    label = TEXT_NEEDS, tip = TEXT_NEED_TIP,
    { key = "finderNeedTank", role = TANK },
    { key = "finderNeedHealer", role = HEALER },
    { key = "finderNeedDps", role = DAMAGE },
}

local pickKeys = {}
for _, pick in ipairs(PLAYERS) do pickKeys[pick.key] = true end
for _, pick in ipairs(NEEDS) do pickKeys[pick.key] = true end

local finder, row
local hidden = {}
local events = CreateFrame("Frame")

local function On()
    return S.Get("enabled") and S.Get("finderRoles") and not ns.GamepadStandDown()
end

local function AnyPicked(set)
    for _, pick in ipairs(set) do
        if S.Get(pick.key) then return true end
    end
    return false
end

local function Filtering()
    if not On() or C_ChatInfo.InChatMessagingLockdown() then return false end
    return AnyPicked(PLAYERS) or AnyPicked(NEEDS)
end

local function PlayerWanted(resultID)
    local player = C_LFGList.GetSearchResultPlayerInfo(resultID, 1)
    local roles = player and player.lfgRoles
    if not roles then return false end
    for _, pick in ipairs(PLAYERS) do
        if S.Get(pick.key) and roles[pick.role.field] then return true end
    end
    return false
end

local function GroupWanted(resultID)
    local counts = C_LFGList.GetSearchResultMemberCounts(resultID)
    if not counts then return false end
    for _, pick in ipairs(NEEDS) do
        if S.Get(pick.key) and (counts[pick.role.remaining] or 0) > 0 then return true end
    end
    return false
end

local function Wanted(resultID)
    local info = C_LFGList.GetSearchResultInfo(resultID)
    if not info then return false end
    if info.hasSelf then return true end
    if info.numMembers == 1 then return PlayerWanted(resultID) end
    return GroupWanted(resultID)
end

local function UpdateRow(entry)
    local keep = not Filtering() or Wanted(entry.resultID)
    if keep == not hidden[entry] then return end
    hidden[entry] = not keep or nil
    entry:SetAlpha(keep and 1 or 0)
    entry:EnableMouse(keep)
end

local function AllHidden()
    local results = finder.results
    if finder.searching or finder.searchFailed or #results == 0 or not Filtering() then return false end
    for i = 1, #results do
        if Wanted(results[i]) then return false end
    end
    return true
end

local function UpdateHint()
    row.hint:SetShown(AllHidden())
end

local function Paint(button)
    local picked = S.Get(button.pick.key)
    button.icon:SetDesaturated(not picked)
    button.icon:SetAlpha(picked and 1 or OFF_ALPHA)
end

local function Refresh()
    for _, button in ipairs(row.buttons) do Paint(button) end
    if not finder:IsShown() then return end
    for _, entry in finder.ScrollBox:EnumerateFrames() do
        if entry.resultID then UpdateRow(entry) end
    end
    UpdateHint()
end

local function OnClick(button)
    S.Set(button.pick.key, not S.Get(button.pick.key))
end

local function AddSet(set, after, gap)
    local label = ns.Font(row, St.SMALL_SIZE)
    label:SetPoint("LEFT", after, after == row and "LEFT" or "RIGHT", gap, 0)
    label:SetText(set.label)
    local last = label
    for i, pick in ipairs(set) do
        local button = CreateFrame("Button", nil, row)
        button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        button:RegisterForClicks("LeftButtonUp")
        button:SetPoint("LEFT", last, "RIGHT", i == 1 and LABEL_GAP or BUTTON_GAP, 0)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.icon:SetAtlas(pick.role.atlas)
        Parts.Press(button)
        button.pick = pick
        button:SetScript("OnClick", OnClick)
        ns.Tooltip(button, pick.role.name, set.tip:format(ns.L(pick.role.name)))
        row.buttons[#row.buttons + 1] = button
        last = button
    end
    return last, label:GetStringWidth() + LABEL_GAP + #set * BUTTON_SIZE + (#set - 1) * BUTTON_GAP
end

local function MakeRow()
    row = CreateFrame("Frame", nil, finder)
    row:SetHeight(BUTTON_SIZE)
    row:SetPoint("TOPLEFT", finder.CategoryDropdown, "BOTTOMLEFT", 0, -ROW_DROP)
    row:SetFrameLevel(finder.CategoryDropdown:GetFrameLevel() + 1)
    row.buttons = {}
    local last, players = AddSet(PLAYERS, row, 0)
    local _, needs = AddSet(NEEDS, last, SET_GAP)
    row:SetWidth(players + SET_GAP + needs)
    row.hint = ns.Font(row, St.TEXT_SIZE, nil, ns.THEME.muted)
    row.hint:SetWidth(HINT_WIDTH)
    row.hint:SetPoint("TOP", finder.NoResultsFound, "TOP")
    row.hint:SetText(TEXT_ALL_HIDDEN)
    row.hint:Hide()
end

local function HookFinder()
    if finder then return end
    local frame = _G.LFGBrowseFrame
    if not frame then return end
    finder = frame
    hooksecurefunc("LFGBrowseSearchEntry_Update", UpdateRow)
    hooksecurefunc(finder, "UpdateResults", UpdateHint)
    MakeRow()
end

local function OnEvent()
    HookFinder()
    if finder then
        events:UnregisterEvent("ADDON_LOADED")
        Refresh()
    end
end

events:SetScript("OnEvent", OnEvent)

local function Apply()
    if not On() then
        events:UnregisterAllEvents()
        if row then
            row:Hide()
            for entry in pairs(hidden) do UpdateRow(entry) end
        end
        return
    end
    HookFinder()
    if not finder then
        events:RegisterEvent("ADDON_LOADED")
        return
    end
    row:Show()
    Refresh()
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "finderRoles" then
        Apply()
    elseif row and pickKeys[key] then
        Refresh()
    end
end

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

ns.Shared.Settings.Page("QoL/Questing & Group", S):Card({
    id = "finderRoles", name = "Group Finder Roles", order = 45, switch = "finderRoles", switchWhy = ns.GamepadWhy,
    help = "Role buttons on the Group Finder that show only the players and groups you want.",
})

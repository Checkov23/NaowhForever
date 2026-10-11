-- TeamRow.lua: your group as it stood for a kill: each member's role icon and name in their class color, you marked.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Kinds = J.View.Kinds
local St = J.Style
local ROLE_ATLAS, TEXT_SIZE = St.ROLE_ATLAS, St.TEXT_SIZE

local TEAM_LINE = 18
local TEAM_PAD = 4
local MEMBER_GAP = 14
local ROLE_GAP = 4
local ROLE_DROP = 1
local ROLE_ICON = 14

local YOU = ns.Color("muted", ns.L(" (you)"))

local function ClassColor(class)
    return class and C_ClassColor.GetClassColor(class) or T.fg
end

local function NewMember(row)
    local member = {}
    member.name = ns.Font(row, TEXT_SIZE)
    member.role = row:CreateTexture(nil, "ARTWORK")
    member.role:SetSize(ROLE_ICON, ROLE_ICON)
    member.role:SetPoint("RIGHT", member.name, "LEFT", -ROLE_GAP, -ROLE_DROP)
    row.members[#row.members + 1] = member
    return member
end

local function SetMember(placed, member)
    local atlas = ROLE_ATLAS[member.role]
    placed.role:SetShown(atlas ~= nil)
    if atlas then placed.role:SetAtlas(atlas) end
    local color = ClassColor(member.class)
    placed.name:SetText(member.me and member.name .. YOU or member.name)
    placed.name:SetTextColor(color.r, color.g, color.b)
    placed.name:Show()
    return atlas and ROLE_ICON + ROLE_GAP or 0
end

J.View.Parts.ClassColor = ClassColor
J.View.Parts.YOU = YOU

Kinds.team = {
    New = function(parent)
        local row = CreateFrame("Frame", nil, parent)
        row.members = {}
        return row
    end,
    Set = function(row, members)
        local width, x, y = row:GetWidth(), 0, 0
        for i, member in ipairs(members) do
            local placed = row.members[i] or NewMember(row)
            local icon = SetMember(placed, member)
            local w = icon + math.ceil(placed.name:GetStringWidth())
            if x > 0 and x + w > width then x, y = 0, y + TEAM_LINE end
            placed.name:ClearAllPoints()
            placed.name:SetPoint("TOPLEFT", x + icon, -y)
            x = x + w + MEMBER_GAP
        end
        for i = #members + 1, #row.members do
            row.members[i].name:Hide()
            row.members[i].role:Hide()
        end
        return y + TEAM_LINE + TEAM_PAD
    end,
}

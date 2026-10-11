-- FactionLinks.lua: a muted label, then a link to each faction or dungeon, and your standing after a faction's.
local ns = _G.NaowhForever

local T = ns.THEME
local J = ns.Journal
local Rep = J.Reputation
local Kinds, Parts = J.View.Kinds, J.View.Parts
local St = J.Style
local TEXT_SIZE, SMALL_SIZE = St.TEXT_SIZE, St.SMALL_SIZE

local LINKS_H, LINK_GAP = 22, 14
local FIRST_GAP = 8
local STANDING_GAP = 6

local TEXT_NOT_MET = ns.L("not met")
local TEXT_VALUE = "%s / %s"

local function LinkClicked(link)
    local view = link:GetParent():GetParent()
    if view.navigate then view.navigate(link.target) end
end

local function StandingText(faction)
    local reaction, value, max = Rep.Standing(faction)
    if not reaction then return ns.Color("muted", TEXT_NOT_MET) end
    local text = J.Colored(Rep.Color(reaction), Rep.Label(reaction))
    if reaction >= Rep.EXALTED then return text end
    return text .. " " .. ns.Color("muted", TEXT_VALUE:format(BreakUpLargeNumbers(value), BreakUpLargeNumbers(max)))
end

local function LinkAt(row, i)
    local link = row.links[i]
    if link then return link end
    link = Parts.Link(row, LinkClicked, true)
    row.links[i] = link
    return link
end

local function AfterAt(row, i)
    local after = row.after[i]
    if after then return after end
    after = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.after[i] = after
    return after
end

local function SetAfter(row, i, link, target)
    local after = AfterAt(row, i)
    after:SetShown(target.tab ~= nil)
    if not target.tab then return link end
    after:ClearAllPoints()
    after:SetPoint("LEFT", link, "RIGHT", STANDING_GAP, 0)
    after:SetText(StandingText(target))
    return after
end

Kinds.links = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        row.label = ns.Font(row, TEXT_SIZE, nil, T.muted)
        row.label:SetPoint("LEFT", 0, 0)
        row.links, row.after = {}, {}
        return row
    end,
    Set = function(row, label, targets)
        row.label:SetText(label)
        local anchor, gap = row.label, FIRST_GAP
        for i, target in ipairs(targets) do
            local link = LinkAt(row, i)
            link.target = target
            Parts.SetLink(link, target.name)
            link:ClearAllPoints()
            link:SetPoint("LEFT", anchor, "RIGHT", gap, 0)
            link:Show()
            gap = LINK_GAP
            anchor = SetAfter(row, i, link, target)
        end
        for i = #targets + 1, #row.links do
            row.links[i]:Hide()
            row.after[i]:Hide()
        end
        return LINKS_H
    end,
}

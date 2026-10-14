-- Recipient.lua: a secure button that follows one named player through raid reordering, even in combat.
local ns = _G.NaowhForever

local B = ns.Blessings
local Parts = ns.Shared.Parts

local TEMPLATE = "NaowhForeverBlessButtonTemplate"
local NOBODY = B.NOBODY

function B.Recipient(parent, name)
    local header = CreateFrame("Frame", name, parent, "SecureGroupHeaderTemplate")
    header:SetAttribute("template", TEMPLATE)
    header:SetAttribute("showPlayer", true)
    header:SetAttribute("showParty", true)
    header:SetAttribute("showRaid", true)
    header:SetAttribute("showSolo", true)
    header:SetAttribute("nameList", NOBODY)
    header:SetAttribute("sortMethod", "NAMELIST")
    header:SetAttribute("point", "TOPLEFT")
    header:SetAttribute("unitsPerColumn", 1)
    header:SetAttribute("maxColumns", 1)
    header:SetPoint("TOPLEFT", parent, "TOPLEFT")
    header:Show()
    local button = header:GetAttribute("child1")
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type1", "spell")
    Parts.Press(button)
    B.Look.Hover(button)
    return header, button
end

function B.SetNames(header, names)
    if header:GetAttribute("nameList") ~= names then header:SetAttribute("nameList", names) end
end

function B.SizeRecipient(header, button, size)
    header:SetAttribute("minWidth", size)
    header:SetAttribute("minHeight", size)
    button:SetSize(size, size)
end

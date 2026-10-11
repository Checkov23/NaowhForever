-- PartRow.lua: Quests or Rares on the Overview: its count and bar, everywhere or in your zone; click to open its tab.
local ns = _G.NaowhForever

local Completo = ns.Completo
local Parts = ns.Shared.Parts
local V = Completo.View

local TEXT_SEE_IN = ns.L("Click to see %s in %s.")
local TEXT_OPEN = ns.L("Click to open %s.")

local function PartEnter(row)
    row.hover:Show()
    if not Parts.Tip(row, "ANCHOR_RIGHT") then return end
    GameTooltip:SetText(row.title:GetText(), 1, 1, 1)
    GameTooltip:AddLine(row.hint, V.Soft())
    GameTooltip:Show()
end

local function PartMouseUp(row, button)
    if button == "LeftButton" then row:GetParent():OpenPart(row.tab, row.zone) end
end

local function NewPart(parent)
    return V.ProgressRow(parent, PartEnter, PartMouseUp)
end

local function SetPart(row, key, zone, label, line, n, total, stripe)
    row.tab, row.zone = key, zone
    row.hint = zone and TEXT_SEE_IN:format(zone.name, label) or TEXT_OPEN:format(label)
    return V.SetProgress(row, label, line, n, total, stripe)
end

V.Kinds.part = { New = NewPart, Set = SetPart }

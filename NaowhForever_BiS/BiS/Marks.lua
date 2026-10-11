-- Marks.lua: your list's rank on item tooltips, and Alt+Shift-click to add an item or take it off.
local ns = _G.NaowhForever

local B = ns.BiS
local S = B.Settings
local Items, Parts = ns.Shared.Items, ns.Shared.Parts

local TEXT_REMOVED = ns.L("Removed %s from your BiS list.")

local function OnItemTooltip(tooltip, data)
    local id = data and data.id
    if not id or issecretvalue(id) or not S.Get("bisTooltip") then return end
    local rank = ns.IsBisItem(id)
    if rank then tooltip:AddLine(Parts.RankLine(rank, B.Lists.List().name)) end
end

local function OnModifiedClick(link)
    if not (IsAltKeyDown() and IsShiftKeyDown() and B.On()) then return end
    local id = Items.IDFrom(link)
    if not id then return end
    if ns.IsBisItem(id) then
        ns.RemoveBisItem(id)
        ns.Print(TEXT_REMOVED:format(Items.Name(id)))
    else
        ns.AddBisItem(id)
    end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
hooksecurefunc("HandleModifiedItemClick", OnModifiedClick)

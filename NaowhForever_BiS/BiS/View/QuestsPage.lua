-- QuestsPage.lua: the BiS List's Quests page, on a Dungeon Journal view (B.View.QuestsPage).
local ns = _G.NaowhForever

local B = ns.BiS
local Q = B.Quests

local QUEST_GAP = 4
local TEXT_NONE = ns.L("No quest gives a pick on your list that you do not have yet.")
local TEXT_CHOICE = ns.L("A choice among its rewards: pick this one.")

local function DrawRewards(view, id)
    for _, itemID in ipairs(Q.Rewards(id)) do
        if Q.Wanted(itemID) then view:Add("item", itemID, nil, view:ItemRank(itemID), view:ItemUpgrade(itemID)) end
    end
    if Q.Choice(id) then view:Note(TEXT_CHOICE) end
end

local function DrawZone(view, zone, entries, indent)
    view:Section(zone.name, #entries)
    for i, entry in ipairs(entries) do
        view:Add("quest", entry, i)
        view.left, view.width = indent, view:GetWidth() - indent
        DrawRewards(view, entry.quest[1])
        view.left, view.width = 0, view:GetWidth()
    end
end

local function Draw(view)
    if not view:IsVisible() then return end
    local J = ns.Journal
    local St = J.Style
    local indent = St.INDENT + St.QUEST_LEVEL_W + QUEST_GAP
    view:Begin(nil, nil, nil)
    view.showChance = false
    local listed = 0
    for _, zone in ipairs(Q.Zones(B.Lists.List())) do
        local entries = J.Quests.List(zone.data, zone.out, zone.pool)
        if #entries > 0 then
            listed = listed + #entries
            DrawZone(view, zone, entries, indent)
            view:Space(St.SECTION_SPACE)
        end
    end
    if listed == 0 then view:Note(TEXT_NONE) end
    view.questsDrawn = true
    view:Finish()
end

function B.View.QuestsPage(parent)
    local view = ns.Journal.View.New(parent)
    view.Redraw = Draw
    return view
end

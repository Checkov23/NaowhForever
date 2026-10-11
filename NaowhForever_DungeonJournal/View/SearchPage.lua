-- SearchPage.lua: a search over every boss, item and faction reward, by dungeon and faction, each with Open.
local ns = _G.NaowhForever

local J = ns.Journal
local Rep = J.Reputation
local ViewMixin = J.View.Mixin
local SECTION_SPACE = J.Style.SECTION_SPACE

local TEXT_OPEN = "Open"
local TEXT_SEARCHING = ns.L("Searching...")
local TEXT_NO_MATCH = ns.L("Nothing in the journal matches %s.")

local EMPTY = {}
local lowerNames = {}

local function LowerName(page)
    local lower = lowerNames[page]
    if not lower then
        lower = page.name:lower()
        lowerNames[page] = lower
    end
    return lower
end

function ViewMixin:DrawFound(page, onOpen)
    if self.grid.n == 0 then return end
    self:SectionLink(page.name, TEXT_OPEN, onOpen, page)
    self:Space(SECTION_SPACE)
    self:DrawGrid()
end

function ViewMixin:SearchDungeon(dungeon, query)
    local found = 0
    local wings = J.FactionShown(dungeon) and dungeon.wings or EMPTY
    for _, wing in ipairs(wings) do
        for _, boss in ipairs(wing.bosses) do
            local byName = LowerName(boss):find(query, 1, true) ~= nil
            local itemQuery = not byName and query or nil
            local shown = self:ShownCount(boss, itemQuery)
            if byName or shown > 0 then
                found = found + 1
                self:Gather(boss, nil, shown, itemQuery)
            end
        end
    end
    return found
end

function ViewMixin:SearchFaction(faction, query)
    local found = 0
    local itemQuery = LowerName(faction):find(query, 1, true) == nil and query or nil
    for _, tier in ipairs(faction.tiers) do
        local shown = self:ListCount(tier.items, itemQuery)
        if shown > 0 then
            found = found + 1
            self:Gather(tier, nil, shown, itemQuery)
        end
    end
    return found
end

function ViewMixin:DrawSearch(query, onOpen)
    self:Begin(nil, nil, query)
    self.onOpen = onOpen
    local found = 0
    for _, dungeon in ipairs(J.Dungeons()) do
        found = found + self:SearchDungeon(dungeon, query)
        self:DrawFound(dungeon, onOpen)
    end
    for _, tab in ipairs(J.TABS) do
        for _, faction in ipairs(J.Factions(tab)) do
            if Rep.Shown(faction) then
                found = found + self:SearchFaction(faction, query)
                self:DrawFound(faction, onOpen)
            end
        end
    end
    if found == 0 then self:Note(self.waiting and TEXT_SEARCHING or TEXT_NO_MATCH:format(query)) end
    self:Finish()
end

-- Window.lua: the Quest List and Rares tabs of the Discovery window (/nfquests, its key binding), by zone.
local ns = _G.NaowhForever

local Completo = ns.Completo
local S = Completo.Settings
local Q = Completo.Quests
local R = Completo.Rares
local V = Completo.View
local Style = Completo.Style
local Shared = ns.Shared
local Parts = Shared.Parts

local SEARCH_MAX = 150
local ALL_ZONES = ns.L("All Zones")
local CONTINENTS = { [0] = "Eastern Kingdoms", [1] = "Kalimdor" }
local ELSEWHERE = ns.L("Elsewhere")
local CONTINENT_ORDER = { CONTINENTS[0], CONTINENTS[1], ELSEWHERE }
local EVENTS = { "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED",
    "LEARNED_SPELL_IN_SKILL_LINE" }
local NO_EVENTS = {}
local SEARCH_HINT = { quests = "Search quests or quest givers", rares = ns.L("Search rares") }
local TEXT_ALL_ZONES = ns.L("All zones")
local TEXT_KILLED_PERCENT = ns.L("%d%% killed")
local TEXT_DONE_PERCENT = ns.L("%d%% done")
local TEXT_QUESTS = ns.L("Quests")
local TEXT_RARES = "Rares"
local TEXT_OPEN = "Open"
local TEXT_QUESTS_DONE = ns.L("Every quest here is done.")
local TEXT_NO_QUESTS = ns.L("No quests here for your character.")
local TEXT_RARES_KILLED = ns.L("Every rare here is killed.")
local TEXT_NO_RARES = ns.L("No rares here for your character.")
local TEXT_NO_QUEST_FOUND = ns.L("No quest or quest giver for your character holds \"%s\".")
local TEXT_NO_RARE_FOUND = ns.L("No rare for your character holds \"%s\".")
local TEXT_FIRST_OF = ns.L("The first %d of %d; type more to narrow it down.")
local TEXT_RARES_PROGRESS = ns.L("%d of %d rares killed")
local TEXT_QUESTS_PROGRESS = ns.L("%d of %d zone quests done")

local window, scroll, view, searchBox
local opened = {}
local kept, focus
local tab = "quests"
local zone
local rareZone
local byContinent = {}
local entries, follow = {}, {}

local Draw = {}
local Tabs = {}
Completo.Tabs = Tabs

local function OnRares()
    return tab == "rares"
end

local function Source()
    return OnRares() and R or Q
end

local function ZoneProgress(z)
    return Source().ZoneProgress(z)
end

local function SetZoneOpen(picked)
    if OnRares() then rareZone = picked else zone = picked end
end

local function Redraw()
    scroll:SetVerticalScroll(0)
    view:Redraw()
end

local function EntryLevel(entry)
    if type(entry) == "table" then return entry.level, entry.name end
    return Q.Level(entry), Q.Name(entry)
end

local function EntryOrder(a, b)
    local la, na = EntryLevel(a)
    local lb, nb = EntryLevel(b)
    if la ~= lb then return la < lb end
    return na < nb
end

local function SortName(z)
    return (z.name:gsub("^The ", ""))
end

local function ZoneOrder(a, b)
    return SortName(a) < SortName(b)
end

local function AllZones()
    SetZoneOpen(nil)
    Redraw()
end

local function OpenFound(picked)
    SetZoneOpen(picked)
    searchBox:SetText("")
    searchBox:ClearFocus()
    Redraw()
end

local function GroupByContinent()
    wipe(byContinent)
    for _, z in ipairs(Source().Zones()) do
        local _, total = ZoneProgress(z)
        if total > 0 then
            local name = CONTINENTS[z.continent] or ELSEWHERE
            byContinent[name] = byContinent[name] or {}
            table.insert(byContinent[name], z)
        end
    end
end

local function DrawAllZones(self)
    local n, total = Source().Progress()
    local about = OnRares() and TEXT_KILLED_PERCENT or TEXT_DONE_PERCENT
    self:Add("hero", TEXT_ALL_ZONES, n, total, about:format(V.Percent(n, total)))
    self:Space(Style.SECTION_GAP)
    GroupByContinent()
    for _, name in ipairs(CONTINENT_ORDER) do
        local list = byContinent[name]
        if list then
            table.sort(list, ZoneOrder)
            self:Section(name, #list)
            for i, z in ipairs(list) do self:Add("zone", z, i % 2 == 0) end
        end
    end
end

local function ZoneHead(self, shown, progress)
    self:SectionLink(shown.name, ALL_ZONES, AllZones)
    self:Space(Style.SECTION_GAP)
    local n, total, low, high = progress(shown)
    self:Add("hero", shown.name, n, total, V.Levels(low, high))
    self:Space(Style.SECTION_GAP)
    return total
end

local function GatherQuests(hideDone)
    local chains, singles = Q.ZoneLists(zone)
    wipe(entries)
    for _, chain in ipairs(chains) do
        local at, steps = Q.ChainAt(chain)
        if not (hideDone and at > steps) then entries[#entries + 1] = chain end
    end
    for _, id in ipairs(singles) do
        if not (hideDone and Q.Done(id)) then entries[#entries + 1] = id end
    end
    table.sort(entries, EntryOrder)
end

local function AddChain(self, chain, stripe)
    for _, id in ipairs(chain.steps[1]) do self:Add("quest", id, "head", nil, nil, stripe) end
    wipe(follow)
    for s = 2, #chain.steps do
        for _, id in ipairs(chain.steps[s]) do follow[#follow + 1] = id end
    end
    for f, id in ipairs(follow) do self:Add("quest", id, "step", f == 1, f == #follow, stripe) end
end

local function DrawZone(self)
    local total = ZoneHead(self, zone, Q.ZoneProgress)
    GatherQuests(S.Get("hideDone"))
    if #entries > 0 then self:Section(TEXT_QUESTS, #entries) end
    for i, entry in ipairs(entries) do
        local stripe = i % 2 == 0
        if type(entry) == "table" then
            AddChain(self, entry, stripe)
        else
            self:Add("quest", entry, nil, nil, nil, stripe)
        end
    end
    if #entries == 0 then self:Note(total > 0 and TEXT_QUESTS_DONE or TEXT_NO_QUESTS) end
end

local function AddRare(self, npc, withZone, stripe)
    self:Add("rare", npc, withZone, stripe)
    if not opened[npc] then return end
    local loot = R.Loot(npc)
    if not loot then return self:Add("drop", nil, npc, stripe) end
    for _, item in ipairs(loot) do self:Add("drop", item, npc, stripe) end
end

local function DrawRareZone(self)
    local total = ZoneHead(self, rareZone, R.ZoneProgress)
    local hideKilled = S.Get("rareHideKilled")
    wipe(entries)
    for _, npc in ipairs(R.ZoneList(rareZone)) do
        if not (hideKilled and R.Killed(npc)) or npc == kept then entries[#entries + 1] = npc end
    end
    if #entries > 0 then self:Section(TEXT_RARES, #entries) end
    for i, npc in ipairs(entries) do AddRare(self, npc, false, i % 2 == 0) end
    if #entries == 0 then self:Note(total > 0 and TEXT_RARES_KILLED or TEXT_NO_RARES) end
end

local function DrawFound(self, text, search, empty, add)
    local zones, n = search(text, SEARCH_MAX)
    if n == 0 then
        self:Note(empty:format(text))
        return
    end
    for _, entry in ipairs(zones) do
        self:Add("section", entry.zone.name, #entry.ids, nil, nil, TEXT_OPEN, OpenFound, entry.zone)
        for i, id in ipairs(entry.ids) do add(self, id, false, i % 2 == 0) end
        self:Space(Style.SECTION_SPACE)
    end
    if n > SEARCH_MAX then self:Note(TEXT_FIRST_OF:format(SEARCH_MAX, n)) end
end

local function AddQuestHit(self, id, _, stripe)
    self:Add("quest", id, nil, nil, nil, stripe)
end

local function SearchText()
    return strtrim(searchBox:GetText() or ""):lower()
end

local function DrawRares(self)
    local text = SearchText()
    if text ~= "" then
        DrawFound(self, text, R.Search, TEXT_NO_RARE_FOUND, AddRare)
    elseif rareZone then
        DrawRareZone(self)
    else
        DrawAllZones(self)
    end
    self:Fit(NO_EVENTS)
end

local function DrawQuests(self)
    Q.Refresh()
    local text = SearchText()
    if text ~= "" then
        local open = zone
        zone = nil
        DrawFound(self, text, Q.Search, TEXT_NO_QUEST_FOUND, AddQuestHit)
        zone = open
    elseif zone then
        DrawZone(self)
    else
        DrawAllZones(self)
    end
    self:Fit(EVENTS)
end

function Draw:Redraw()
    self:Clear()
    if OnRares() then return DrawRares(self) end
    DrawQuests(self)
end

function Draw:Progress(z)
    return ZoneProgress(z)
end

function Draw:OnRares()
    return OnRares()
end

function Draw:OpenZone(picked)
    SetZoneOpen(picked)
    Redraw()
end

function Draw:ShownZone()
    return zone
end

function Draw:IsOpened(npc)
    return opened[npc] == true
end

function Draw:ToggleOpened(npc)
    opened[npc] = not opened[npc] or nil
    view:Redraw()
end

local function Paint()
    if OnRares() then
        window.note.text:SetText(TEXT_RARES_PROGRESS:format(R.Progress()))
    else
        Q.Refresh()
        window.note.text:SetText(TEXT_QUESTS_PROGRESS:format(Q.Progress()))
    end
    window.note:SetWidth(math.max(1, math.ceil(window.note.text:GetStringWidth())))
    searchBox.hint:SetText(SEARCH_HINT[tab])
end

local function IsShown()
    return scroll ~= nil and scroll:IsVisible()
end

local function Searched()
    if IsShown() then Redraw() end
end

function Tabs.Build(host, frame, width)
    window, scroll = host, frame
    view = Shared.View.New(scroll, V.Kinds, Draw)
    view:SetWidth(width)
    scroll:SetScrollChild(view)
    searchBox = Parts.SearchBox(host, SEARCH_HINT.quests, Searched)
    return searchBox
end

local function IsRare(row, npc) return row.rare == npc end

function Tabs.Show(key, opening)
    tab = key
    if opening then
        zone = Q.CurrentZone() or zone
        rareZone = R.CurrentZone() or rareZone
        kept = focus
        if focus then
            rareZone = R.Zone(focus) or rareZone
            opened[focus] = true
            searchBox:SetText("")
        end
    end
    scroll:Show()
    searchBox:Show()
    Paint()
    Redraw()
    local row = focus and view:Find("rare", IsRare, focus)
    if row then view:ScrollToRow(scroll, row) end
    focus = nil
end

function Tabs.Hide()
    scroll:Hide()
    searchBox:Hide()
end

local function OnSettingChanged(key)
    if IsShown() and (key == "hideDone" or key == "rareHideKilled") then view:Redraw() end
end

local function OnRareChanged()
    if not IsShown() or not OnRares() then return end
    Paint()
    view:QueueRedraw()
end

local function OnApply()
    if not IsShown() then return end
    Paint()
    view:Redraw()
end

function ns.OpenCompletoWindow(which, npc)
    focus = npc
    ns.OpenDiscoveryWindow(which == "rares" and "rares" or "quests")
end

function ns.ToggleCompletoWindow()
    ns.ToggleDiscoveryWindow(tab)
end

function NaowhForever_ToggleCompleto()
    ns.ToggleCompletoWindow()
end

S.OnChange(OnSettingChanged)
R.OnChange(OnRareChanged)
hooksecurefunc(ns, "Apply", OnApply)

-- Studio.lua: a settings card's live preview: a stage and the moments it can be seen in, painted by the module's own drawing code (Settings.kinds.studio).
local ns = _G.NaowhForever
local T = ns.THEME
local Shared = ns.Shared
local Settings, Parts = Shared.Settings, Shared.Parts
local SS = Settings.Style

local BORDER_RGB = SS.BORDER_RGB
local PAD = 14
local TOP = 12
local TABS_MARGIN = 24
local TABS_GAP = 8
local DEFAULT_H = 150
local TABS_WIDTH = 1
local FOREVER_TABS_IN = 12

local shownState = {}

local function Shown(card, state)
    local needs = state.needs
    if not needs then return true end
    if type(needs) == "function" then return needs() and true or false end
    return card.store.Get(needs) and true or false
end

local function StateOf(card, states)
    local key = shownState[card.uid]
    for i = 1, #states do
        if states[i].key == key then return key end
    end
    return states[1].key
end

local function TabPicked(row, key)
    shownState[row.card.uid] = key
    row:GetParent():QueueSettingsRedraw()
end

local function NewStudio(view)
    local row = CreateFrame("Frame", nil, view)
    row.stage = CreateFrame("Frame", nil, row)
    row.stage:SetPoint("BOTTOMLEFT", PAD, PAD)
    row.stage:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    ns.Solid(row.stage, "BACKGROUND", T.bg, 1):SetAllPoints()
    ns.Border(row.stage, BORDER_RGB)
    row.stage:SetClipsChildren(true)
    row.previews = {}
    row.states = {}
    return row
end

local function StageHeight(studio)
    local height = studio.height or DEFAULT_H
    if type(height) == "function" then height = height() end
    return height
end

local function Preview(row, card)
    for owner, preview in pairs(row.previews) do preview:SetShown(owner == card) end
    local preview = row.previews[card]
    if not preview then
        preview = card.studio.new(row.stage)
        row.previews[card] = preview
    end
    preview:Show()
    return preview
end

local function ShownStates(row, card)
    local studio, states = card.studio, row.states
    wipe(states)
    for _, s in ipairs(studio.states) do
        if Shown(card, s) then states[#states + 1] = s end
    end
    if #states == 0 then states[1] = studio.states[1] end
    return states
end

local function PaintTabs(row, states, state)
    local many = #states > 1
    if many and not row.tabs then
        row.tabs = Parts.Tabs(row, TABS_WIDTH, states, function(key) TabPicked(row, key) end, true, true)
        if ns.foreverSkin then
            row.tabs:SetPoint("BOTTOMRIGHT", row.stage, "TOPRIGHT", -FOREVER_TABS_IN, 0)
        else
            row.tabs:SetPoint("TOPRIGHT", -PAD, -TOP)
        end
    end
    if row.tabs then
        row.tabs:SetShown(many)
        if many then
            Parts.FitTabs(row.tabs, states, TABS_MARGIN)
            Parts.PaintTabs(row.tabs, state)
        end
    end
    return many and (row.tabs:GetHeight() + (ns.foreverSkin and 0 or TABS_GAP)) or 0
end

local function SetStudio(row, card)
    local studio = card.studio
    row.card = card
    local height = StageHeight(studio)
    local preview = Preview(row, card)
    local states = ShownStates(row, card)
    local state = StateOf(card, states)
    local tabsH = PaintTabs(row, states, state)
    row.stage:SetHeight(height)
    row.preview, row.previewState = preview, state
    studio.paint(preview, state)
    return TOP + tabsH + height + PAD
end

function Settings.PaintPreviews(view)
    local pool = view.pools.studio
    for i = 1, pool and pool.used or 0 do
        local row = pool[i]
        if row.preview and row:IsVisible() then row.card.studio.paint(row.preview, row.previewState) end
    end
end

Settings.kinds.studio = { New = NewStudio, Set = SetStudio }

-- Create.lua: the Create page: a dungeon, the roles you still need, a minimum Naowh Score, a playstyle and a note, listed in Forever's group finder (ns.GroupFinder.UI.Create).
local ns = _G.NaowhForever
local T = ns.THEME

local GF = ns.GroupFinder
if not GF then return end
local UI = GF.UI
local Card, Listings, Search, Group = GF.Card, GF.Listings, GF.Search, GF.Group
local Pick = UI.Pick

local St = UI.Style
local GAP, PAD = St.TEXT_GAP, St.ROW_PAD
local TILE_COLS, TILE_H, TILE_GAP = St.TILE_COLS, St.TILE_H, St.TILE_GAP
local TILE_W = math.floor((UI.LIST_W - (TILE_COLS - 1) * TILE_GAP) / TILE_COLS)
local SECTION_GAP, KICKER_GAP = St.SECTION_GAP, St.KICKER_GAP
local BUTTON_H, STEP_W, ROLE_GROUP_W = St.BUTTON_H, St.STEP_W, St.ROLE_GROUP_W
local STYLE_W = math.floor((UI.LIST_W - (#UI.STYLES - 1) * TILE_GAP) / #UI.STYLES)
local TRACK_W, BOX_W, BOX_ALPHA = St.TRACK_W, St.BOX_W, 1
local MIN_SCORE_MAX, MIN_SCORE_STEP, SCORE_TENTHS, ROUND = 30, 0.5, 10, 0.5
local NOTE_H, LIST_W = St.NOTE_H, St.LIST_BUTTON_W
local NEED_MAX, NOTE_MAX = Card.NEED_MAX, Card.NOTE_MAX
local ROLES = {
    { field = "tanks", atlas = St.ROLE_ATLAS.TANK, label = ns.L("Tank") },
    { field = "healers", atlas = St.ROLE_ATLAS.HEALER, label = ns.L("Healer") },
    { field = "damage", atlas = St.ROLE_ATLAS.DAMAGER, label = ns.L("Damage") },
}

local TEXT_RANGE = "%d-%d"
local TEXT_BOSS, TEXT_BOSSES = ns.L("1 boss"), ns.L("%d bosses")
local TEXT_COUNT = "%d/%d"
local TEXT_DUNGEON, TEXT_ROLES, TEXT_MIN, TEXT_STYLE, TEXT_NOTE = "DUNGEON", "ROLES NEEDED", "MINIMUM SCORE", "STYLE", "NOTE"
local TEXT_NO_DUNGEONS = ns.L("Forever's group finder has no dungeons for your level yet.")
local TEXT_LIST, TEXT_UPDATE, TEXT_RESET = "List Group", "Update Group", "Reset"
local TEXT_PICK = ns.L("Pick a dungeon and a style to list your group.")
local TEXT_LEADER_ONLY = ns.L("Only your group's leader can change its listing.")

local activities = {}
local page, content
local onListed

local function Bosses(activityID)
    local J = ns.Journal
    local key = J and Listings.DungeonOf(activityID)
    local dungeon = key and J.Get(key)
    if not dungeon then return nil end
    local n = 0
    for w = 1, #dungeon.wings do
        local bosses = dungeon.wings[w].bosses
        for b = 1, #bosses do
            if not bosses[b].with and J.Kills.Counted(bosses[b]) then n = n + 1 end
        end
    end
    return n > 0 and n or nil
end

local Paint

local function NewTile(i)
    local tile = ns.Button(content, "", TILE_W, TILE_H)
    tile.idle = tile._rest
    tile._onClick = function()
        Group.activity = tile.activity
        Paint()
    end
    tile.label:ClearAllPoints()
    tile.label:SetPoint("TOPLEFT", GAP, -GAP)
    tile.range = ns.Font(tile, St.SUB_SIZE, nil, T.muted)
    tile.range:SetPoint("BOTTOMLEFT", GAP, GAP)
    tile.bosses = ns.Font(tile, St.SUB_SIZE, nil, T.muted)
    tile.bosses:SetPoint("BOTTOMRIGHT", -GAP, GAP)
    page.tiles[i] = tile
    return tile
end

local function PaintTile(tile, id, x, y)
    local activity = Listings.Activity(id)
    tile.activity = id
    tile:ClearAllPoints()
    tile:SetPoint("TOPLEFT", x, -y)
    ns.SetButtonText(tile, activity.short)
    local level = activity.min > 0 and activity.min or UnitLevel("player")
    local color = GetQuestDifficultyColor(level)
    tile.range:SetText(activity.max > 0 and TEXT_RANGE:format(activity.min, activity.max) or "")
    tile.range:SetTextColor(color.r, color.g, color.b)
    local bosses = Bosses(id)
    tile.bosses:SetText(not bosses and "" or bosses == 1 and TEXT_BOSS or TEXT_BOSSES:format(bosses))
    Pick(tile, Group.activity == id)
    tile:Show()
end

local function PaintTiles(y)
    local n = Search.Activities(activities)
    page.empty:SetShown(n == 0)
    page.empty:SetPoint("TOPLEFT", 0, -y)
    for i = 1, n do
        local tile = page.tiles[i] or NewTile(i)
        local column, line = (i - 1) % TILE_COLS, math.floor((i - 1) / TILE_COLS)
        PaintTile(tile, activities[i], column * (TILE_W + TILE_GAP), y + line * (TILE_H + TILE_GAP))
    end
    for i = n + 1, #page.tiles do page.tiles[i]:Hide() end
    local lines = n > 0 and math.ceil(n / TILE_COLS) or 1
    return y + lines * (TILE_H + TILE_GAP)
end

local function Section(kicker, y)
    kicker:ClearAllPoints()
    kicker:SetPoint("TOPLEFT", 0, -y)
    return y + St.KICKER_SIZE + KICKER_GAP
end

local function Step(role, delta)
    Group[role.field] = math.max(0, math.min(NEED_MAX, Group[role.field] + delta))
    Paint()
end

local function NewRole(i, role)
    local group = CreateFrame("Frame", nil, content)
    group:SetSize(ROLE_GROUP_W, BUTTON_H)
    group.icon = group:CreateTexture(nil, "ARTWORK")
    group.icon:SetSize(St.ROLE_ICON, St.ROLE_ICON)
    group.icon:SetPoint("LEFT")
    group.icon:SetAtlas(role.atlas, false)
    group.label = ns.Font(group, St.LINE_SIZE, nil, T.fg)
    group.label:SetPoint("LEFT", group.icon, "RIGHT", GAP, 0)
    group.label:SetText(role.label)
    group.plus = ns.Button(group, "+", STEP_W, BUTTON_H, function() Step(role, 1) end)
    group.plus:SetPoint("RIGHT")
    group.value = ns.Font(group, St.LINE_SIZE, nil, T.fg)
    group.value:SetPoint("RIGHT", group.plus, "LEFT", -GAP, 0)
    group.minus = ns.Button(group, "-", STEP_W, BUTTON_H, function() Step(role, -1) end)
    group.minus:SetPoint("RIGHT", group.value, "LEFT", -GAP, 0)
    page.roles[i] = group
    return group
end

local function NoteChanged(box)
    Group.note = Card.CleanNote(box:GetText())
    page.count:SetText(TEXT_COUNT:format(#Group.note, NOTE_MAX))
end

local function Reset()
    Group.activity, Group.style, Group.min, Group.note = nil, nil, 0, ""
    Group.tanks, Group.healers, Group.damage = 1, 1, 3
    page.note:SetText("")
    page.slider._refreshValue()
    Paint()
end

local function List()
    if Group.List() and onListed then onListed() end
end

function Paint()
    local y = Section(page.kickers[1], 0)
    y = PaintTiles(y) + SECTION_GAP
    y = Section(page.kickers[2], y)
    for i, group in ipairs(page.roles) do
        group:ClearAllPoints()
        group:SetPoint("TOPLEFT", (i - 1) * (ROLE_GROUP_W + PAD), -y)
        group.value:SetText(tostring(Group[ROLES[i].field]))
    end
    y = y + BUTTON_H + SECTION_GAP
    y = Section(page.kickers[3], y)
    page.box:ClearAllPoints()
    page.box:SetPoint("TOPRIGHT", 0, -y)
    page.slider:ClearAllPoints()
    page.slider:SetPoint("RIGHT", page.box, "LEFT", -GAP, 0)
    y = y + BUTTON_H + SECTION_GAP
    y = Section(page.kickers[4], y)
    for i, button in ipairs(page.styles) do
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", (i - 1) * (STYLE_W + TILE_GAP), -y)
        Pick(button, Group.style == i)
    end
    y = y + BUTTON_H + SECTION_GAP
    y = Section(page.kickers[5], y)
    page.note:ClearAllPoints()
    page.note:SetPoint("TOPLEFT", 0, -y)
    y = y + NOTE_H + GAP
    page.count:ClearAllPoints()
    page.count:SetPoint("TOPRIGHT", 0, -y)
    y = y + St.SUB_SIZE + SECTION_GAP
    local listed, leader = Group.Listed(), Group.CanEdit()
    ns.SetButtonText(page.list, listed and TEXT_UPDATE or TEXT_LIST)
    page.list:ClearAllPoints()
    page.list:SetPoint("TOPRIGHT", 0, -y)
    page.list:SetEnabled(leader and Group.Ready())
    page.list:SetAlpha(leader and Group.Ready() and 1 or St.DISABLED_ALPHA)
    page.reset:ClearAllPoints()
    page.reset:SetPoint("TOPLEFT", 0, -y)
    page.why:SetText(not leader and TEXT_LEADER_ONLY or not Group.Ready() and TEXT_PICK or "")
    y = y + BUTTON_H + GAP
    page.why:ClearAllPoints()
    page.why:SetPoint("TOPRIGHT", 0, -y)
    content:SetHeight(y + St.SUB_SIZE + SECTION_GAP)
end

function UI.Create(parent, listed)
    onListed = listed
    page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", St.CONTENT_INSET, -UI.CONTENT_TOP)
    page:SetPoint("BOTTOMRIGHT", -St.CONTENT_INSET, UI.FOOTER_ROOM)
    local scroll = ns.UI.SlimScroll(page)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -St.SCROLLBAR - St.SCROLL_GAP, 0)
    content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(UI.LIST_W)
    scroll:SetScrollChild(content)
    page.tiles, page.roles, page.styles = {}, {}, {}
    page.kickers = { UI.Kicker(content, TEXT_DUNGEON), UI.Kicker(content, TEXT_ROLES), UI.Kicker(content, TEXT_MIN),
        UI.Kicker(content, TEXT_STYLE), UI.Kicker(content, TEXT_NOTE) }
    page.empty = ns.Font(content, St.SUB_SIZE, nil, T.muted)
    page.empty:SetText(TEXT_NO_DUNGEONS)
    for i, role in ipairs(ROLES) do NewRole(i, role) end
    page.slider, page.box = ns.UI.BuildSliderCore(content, TRACK_W, St.SLIDER_H, St.KNOB, BOX_W, BUTTON_H, St.SUB_SIZE,
        BOX_ALPHA, 0, MIN_SCORE_MAX, MIN_SCORE_STEP,
        function() return Group.min / SCORE_TENTHS end,
        function(value) Group.min = math.floor(value * SCORE_TENTHS + ROUND) end)
    for i, name in ipairs(UI.STYLES) do
        local button = ns.Button(content, name, STYLE_W, BUTTON_H, function()
            Group.style = i
            Paint()
        end)
        button.idle = button._rest
        page.styles[i] = button
    end
    page.note = ns.NewEditBox(content)
    page.note:SetSize(UI.LIST_W, NOTE_H)
    page.note:SetMaxLetters(NOTE_MAX)
    page.note:SetScript("OnTextChanged", NoteChanged)
    page.note:SetScript("OnEscapePressed", page.note.ClearFocus)
    page.note:SetScript("OnEnterPressed", page.note.ClearFocus)
    page.count = ns.Font(content, St.SUB_SIZE, nil, T.muted)
    page.count:SetText(TEXT_COUNT:format(0, NOTE_MAX))
    page.list = ns.PrimaryButton(ns.Button(content, TEXT_LIST, LIST_W, BUTTON_H, List))
    page.reset = ns.Button(content, TEXT_RESET, LIST_W, BUTTON_H, Reset)
    page.why = ns.Font(content, St.SUB_SIZE, nil, T.muted)
    page.Paint = Paint
    page:Hide()
    return page
end

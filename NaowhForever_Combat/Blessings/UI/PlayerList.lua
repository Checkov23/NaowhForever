-- PlayerList.lua: a class's player list above the bar, to bless one person or give them their own blessing.
local ns = _G.NaowhForever

local B = ns.Blessings
local T = ns.THEME
local BLESSINGS, BY_KEY, QUESTION = B.BLESSINGS, B.BY_KEY, B.QUESTION
local Look = B.Look
local Store, Assigned, BuffState, HighestKnown = B.Store, B.Assigned, B.BuffState, B.HighestKnown
local SpellName, SpellIcon, ClassName = B.SpellName, B.SpellIcon, B.ClassName

local ROW_W, ROW_H, ROW_STEP, ROW_X, ROW_TOP = 230, 30, 32, 6, 26
local NAME_SIZE, NOTE_SIZE, TITLE_SIZE = 12, 10, 12
local NAME_X, NAME_Y, NOTE_Y = 4, -2, -1
local SLOT, SLOT_X = 26, -2
local LIST_W, LIST_ROOM, LIST_GAP, LIST_ALPHA = 242, 30, 18, 0.9
local TITLE_X, TITLE_Y = 8, -6
local CLOSE_SIZE, CLOSE_INSET = 18, -4
local NOBODY = B.NOBODY
local ROW_NAME = "NaowhForeverBlessRow"
local TEXT_DEFAULT = ns.L("Class default")
local TEXT_BLESS = ns.L("Bless")
local TEXT_BLESS_TIP = ns.L("Left-click: cast this player's blessing.\nRight-click: give "
    .. "them their own blessing, or back to the class default.")
local TEXT_AFTER_COMBAT = ns.L("The player list opens after combat.")
local TEXT_CLOSE = "X"

local flyout, rows, flyoutClass
local members = {}

local function PlayerMenu(owner, member)
    local store = Store()
    local function Can(entry)
        return B.Learned(entry) and (store.players[member.guid] == entry.key or B.Allowed(member.class, entry.key))
    end
    B.OpenMenu(owner, Ambiguate(member.who, "short"), BLESSINGS,
        function() return store.players[member.guid] end,
        function(key)
            store.players[member.guid] = key
            B.BroadcastSoon()
            B.Changed()
        end, TEXT_DEFAULT, Can)
end

local function NewRow(index)
    local row = CreateFrame("Frame", nil, flyout)
    row:SetSize(ROW_W, ROW_H)
    row.name = ns.Font(row, NAME_SIZE, "OUTLINE")
    row.name:SetPoint("TOPLEFT", NAME_X, NAME_Y)
    row.note = ns.Font(row, NOTE_SIZE, nil, T.muted)
    row.note:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, NOTE_Y)
    row.slot = CreateFrame("Frame", nil, row)
    row.slot:SetSize(SLOT, SLOT)
    row.slot:SetPoint("RIGHT", SLOT_X, 0)
    Look.Icon(row.slot)
    row.header, row.cast = B.Recipient(row.slot, ROW_NAME .. index)
    B.SizeRecipient(row.header, row.cast, SLOT)
    row.cast:SetScript("PostClick", function(self, button, down)
        if button == "RightButton" and not down and row.member then PlayerMenu(self, row.member) end
        if button == "LeftButton" then B.NoteCast(self:GetAttribute("unit"), self:GetAttribute("spell1")) end
    end)
    ns.Tooltip(row.cast, TEXT_BLESS, TEXT_BLESS_TIP)
    B.Watch(row.slot)
    row.cast:HookScript("OnAttributeChanged", function(_, name, value)
        if name == "unit" then B.SetWatch(row.slot, value, row.slot.watchKey) end
    end)
    return row
end

local function PaintRow(row, member, store)
    row.member = member
    local color = RAID_CLASS_COLORS[member.class]
    row.name:SetText(Ambiguate(member.who, "short"))
    row.name:SetTextColor(color.r, color.g, color.b)
    local own = store.players[member.guid]
    local key = Assigned(member)
    row.note:SetText(own and SpellName(own) or TEXT_DEFAULT)
    row.slot.icon:SetTexture(key and SpellIcon(key) or QUESTION)
    B.SetNames(row.header, member.names)
    row.cast:SetAttribute("spell1", key and HighestKnown(BY_KEY[key].ranks))
    B.SetWatch(row.slot, member.unit, key)
    local has, remaining
    if key then has, remaining = BuffState(member.unit, key) end
    Look.State(row.slot, key, has, remaining)
end

local function CloseFlyout()
    B.PlayerList.Toggle(flyoutClass)
end

local PlayerList = {}
B.PlayerList = PlayerList

function PlayerList.Showing()
    return flyoutClass
end

function PlayerList.Build(bar)
    flyout = CreateFrame("Frame", nil, bar)
    flyout:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, LIST_GAP)
    ns.Solid(flyout, "BACKGROUND", T.bg, LIST_ALPHA):SetAllPoints()
    ns.Border(flyout)
    flyout.title = ns.Font(flyout, TITLE_SIZE, "OUTLINE", T.accent)
    flyout.title:SetPoint("TOPLEFT", TITLE_X, TITLE_Y)
    local close = ns.Button(flyout, TEXT_CLOSE, CLOSE_SIZE, CLOSE_SIZE, CloseFlyout)
    close:SetPoint("TOPRIGHT", CLOSE_INSET, CLOSE_INSET)
    rows = {}
    flyout:Hide()
end

function PlayerList.Arrange(roster)
    wipe(members)
    for _, member in ipairs(roster) do
        if member.class == flyoutClass then members[#members + 1] = member end
    end
    if #members == 0 then flyoutClass = nil end
    if not flyoutClass then
        flyout:Hide()
        return
    end
    local store = Store()
    flyout:Show()
    for i, member in ipairs(members) do
        local row = rows[i] or NewRow(i)
        rows[i] = row
        PaintRow(row, member, store)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", ROW_X, -ROW_TOP - (i - 1) * ROW_STEP)
        row:Show()
    end
    for i = #members + 1, #rows do
        B.SetNames(rows[i].header, NOBODY)
        B.SetWatch(rows[i].slot, nil, nil)
        rows[i]:Hide()
    end
    flyout.title:SetText(ClassName(flyoutClass))
    flyout:SetSize(LIST_W, LIST_ROOM + #members * ROW_STEP)
end

function PlayerList.Toggle(class)
    if InCombatLockdown() then
        ns.Print(TEXT_AFTER_COMBAT)
        return
    end
    flyoutClass = flyoutClass ~= class and class or nil
    B.Refresh()
end

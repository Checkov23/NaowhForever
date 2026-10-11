-- Details.lua: the inspect panel's Player tab: talents, gear check, guild and your note.
local ns = _G.NaowhForever

local T = ns.THEME
local IP = ns.InspectPanel
local SW = ns.StatWeights
local St = ns.Shared.Style
local Parts = ns.Shared.Parts

local TITLE_SIZE, LINE_SIZE = IP.SECTION_TITLE_SIZE, IP.SECTION_LINE_SIZE
local TREE_COUNT = 3
local GUILD_INFO_NAME = 3
local TITLE_H, LINE_H, SECTION_GAP = IP.SECTION_TITLE_H, 18, IP.SECTION_GAP
local NOTE_LINES, NOTE_MAX = 3, 200
local LINK_GAP = 10
local WAITING = "..."
local TREES = "%d/%d/%d"
local POINTS = ns.L("%d points")
local NAOWH_BUILD = ns.L("Naowh's %s build")
local NO_TALENTS = ns.L("No talents yet")
local NOT_SHOWN = ns.L("Not shown")
local ITEM_LEVEL, UNENCHANTED, EMPTY_SLOTS = ns.L("Item level"), ns.L("Unenchanted"), ns.L("Empty slots")
local NONE_TEXT = ns.L("None")
local NO_GUILD = ns.L("No guild")
local GEAR_ROWS = { "level", "check", "empty" }
local FRIEND, GUILDMATE = ns.L("Friend"), ns.L("Guildmate")
local GROUPED_ONCE, GROUPED = ns.L("Grouped once"), ns.L("Grouped %d times")
local NO_NOTE = ns.L("No note on them")
local NOTE_TITLE = ns.L("Your note on %s")
local ROLE = {
    ["protection-warrior"] = ns.L("Tank"), ["protection-paladin"] = ns.L("Tank"),
    ["holy-paladin"] = ns.L("Healer"), ["discipline-priest"] = ns.L("Healer"), ["holy-priest"] = ns.L("Healer"),
    ["restoration-druid"] = ns.L("Healer"), ["restoration-shaman"] = ns.L("Healer"),
}
local DAMAGE = ns.L("Damage")
local NONE = {}

local body, rows
local talents = { spent = {}, ids = {} }
local counts, links = {}, {}
local menuGUID

local function Section(y, title)
    local text = ns.Font(body, TITLE_SIZE, nil, T.accentSoft)
    text:SetPoint("TOPLEFT", 0, -y)
    text:SetText(title)
    local line = ns.Solid(body, "ARTWORK", T.line, 1)
    line:SetPoint("TOPLEFT", 0, -(y + TITLE_SIZE + SECTION_GAP))
    line:SetPoint("TOPRIGHT", 0, -(y + TITLE_SIZE + SECTION_GAP))
    ns.Hairline(line, "h")
    return y + TITLE_H
end

local function Line(y)
    local left = ns.Font(body, LINE_SIZE, nil, T.fg)
    left:SetPoint("TOPLEFT", 0, -y)
    left:SetJustifyH("LEFT")
    left:SetWordWrap(false)
    local right = ns.Font(body, LINE_SIZE, nil, T.muted)
    right:SetPoint("TOPRIGHT", 0, -y)
    right:SetPoint("LEFT", left, "RIGHT", LINK_GAP, 0)
    right:SetJustifyH("RIGHT")
    right:SetWordWrap(false)
    return { left = left, right = right }, y + LINE_H
end

local function Color(text, color)
    text:SetTextColor(color.r, color.g, color.b)
end

local function Matches(build, configID, total)
    local points = build.points
    if type(points) ~= "table" or total == 0 or total > #points then return false end
    wipe(counts)
    for i = 1, total do
        local node = points[i]
        counts[node] = (counts[node] or 0) + 1
    end
    for node, n in pairs(counts) do
        local info = C_Traits.GetNodeInfo(configID, node)
        if not (info and info.activeRank == n) then return false end
    end
    return true
end

local function BuildName(classID, configID, total)
    local builds = ns.TrainingBuilds and classID and ns.TrainingBuilds[classID]
    for _, build in ipairs(type(builds) == "table" and builds or NONE) do
        if type(build) == "table" and type(build.name) == "string" and Matches(build, configID, total) then
            return build.name
        end
    end
end

function IP.ReadTalentTrees(configID, class, out)
    local config = configID and C_Traits.GetConfigInfo(configID)
    local treeID = config and config.treeIDs and config.treeIDs[1]
    if not treeID then return false end
    local groups = C_Traits.GetGroupDisplayInfoByTreeID(treeID) or NONE
    wipe(out.ids)
    for i, group in ipairs(groups) do out.ids[i] = group.groupID end
    local infos = C_Traits.GetGroupCurrencyInfo(configID, out.ids) or NONE
    wipe(out.spent)
    local best, most, total = nil, 0, 0
    for i, group in ipairs(groups) do
        local spent = 0
        for _, info in ipairs(infos) do
            local currency = info.traitNodeGroupID == group.groupID and info.currencyInfos and info.currencyInfos[1]
            if currency then spent = currency.spent or 0 end
        end
        out.spent[i] = spent
        total = total + spent
        if spent > most then best, most = i, spent end
    end
    out.count, out.total = #groups, total
    out.tree = best and groups[best].displayName
    out.role = best and (ROLE[SW.TreeSpec(class, best) or ""] or DAMAGE)
    return true
end

local function InspectConfig()
    local consts = Constants and Constants.TraitConsts
    return consts and consts.INSPECT_TRAIT_CONFIG_ID
end

function IP.ReadInspectTalents(class, out)
    if not (C_Traits and C_Traits.HasValidInspectData and C_Traits.HasValidInspectData()) then return false end
    return IP.ReadTalentTrees(InspectConfig(), class, out)
end

local function ReadTalents(unit, guid)
    talents.guid, talents.ok = guid, false
    local _, class, classID = UnitClass(unit)
    if not IP.ReadInspectTalents(class, talents) then return end
    talents.build = BuildName(classID, InspectConfig(), talents.total)
    talents.ok = true
end

local function PaintTalents(guid)
    local points, build = rows.points, rows.build
    build.left:SetText("")
    build.right:SetText("")
    if talents.guid ~= guid then
        points.left:SetText(WAITING)
        points.right:SetText("")
        return
    end
    if not talents.ok then
        points.left:SetText(NOT_SHOWN)
        points.right:SetText("")
        return
    end
    local spent = talents.spent
    if talents.total == 0 then
        points.left:SetText(NO_TALENTS)
        points.right:SetText("")
        return
    end
    points.left:SetText(talents.tree or "")
    if talents.count == TREE_COUNT then
        points.right:SetText(TREES:format(spent[1], spent[2], spent[3]))
    else
        points.right:SetText(POINTS:format(talents.total))
    end
    build.left:SetText(talents.build and NAOWH_BUILD:format(talents.build) or "")
    build.right:SetText(talents.role or "")
end

local function Value(row, text, color)
    row.right:SetText(text)
    Color(row.right, color or T.fg)
end

local function PaintGear(guid)
    local gear = IP.Gear(guid)
    local level, bare, empty = rows.level, rows.check, rows.empty
    if not gear then
        Value(level, WAITING)
        Value(bare, "")
        Value(empty, "")
        return
    end
    Value(level, gear.level and tostring(gear.level) or WAITING)
    if gear.bareCount > 0 then Value(bare, tostring(gear.bareCount), St.WARN_RGB) else Value(bare, NONE_TEXT, T.muted) end
    if gear.empty > 0 then Value(empty, tostring(gear.empty)) else Value(empty, NONE_TEXT, T.muted) end
end

local function PaintGuild(unit, guid)
    local guild, rank = rows.guild, rows.link
    local name, rankName
    if GetGuildInfo then name, rankName = GetGuildInfo(unit) end
    if not (IP.Readable(name) and name ~= "") and C_PaperDollInfo.GetInspectGuildInfo and IP.Ready(guid) then
        name, rankName = select(GUILD_INFO_NAME, C_PaperDollInfo.GetInspectGuildInfo(unit)), nil
    end
    guild.right:SetText("")
    if IP.Readable(name) and name ~= "" then
        guild.left:SetText(name)
        Color(guild.left, T.fg)
        rank.left:SetText(IP.Readable(rankName) and rankName or "")
    else
        guild.left:SetText(NO_GUILD)
        Color(guild.left, T.muted)
        rank.left:SetText("")
    end
    wipe(links)
    if C_FriendList and C_FriendList.IsFriend and C_FriendList.IsFriend(guid) then links[#links + 1] = FRIEND end
    if ns.InGuild and ns.InGuild(guid) then links[#links + 1] = GUILDMATE end
    local H = ns.PlayerHistory
    local rec = H and H.On and H.On() and H.Of and H.Of(guid)
    local groups = type(rec) == "table" and tonumber(rec.groups) or 0
    if groups > 0 then links[#links + 1] = groups == 1 and GROUPED_ONCE or GROUPED:format(groups) end
    rank.right:SetText(#links > 0 and table.concat(links, ", ") or "")
end

local function TagOf(key)
    local H = ns.PlayerHistory
    for _, tag in ipairs(H and type(H.TAGS) == "table" and H.TAGS or NONE) do
        if tag.key == key then return tag end
    end
end

local function TagColor(tag)
    local color = tag.color
    if type(color) == "string" then color = T[color] end
    return type(color) == "table" and color or T.fg
end

local function PaintNote(guid)
    local H = ns.PlayerHistory
    local can = H ~= nil and H.Note ~= nil and H.SetNote ~= nil
    rows.note:SetShown(can)
    if not can then return end
    local note = H.Note(guid)
    local tag = type(note) == "table" and TagOf(note.tag)
    rows.tag:SetText(tag and ns.PlainText(tag.label, NOTE_MAX) or "")
    if tag then Color(rows.tag, TagColor(tag)) end
    local text = type(note) == "table" and ns.PlainText(note.text, NOTE_MAX)
    rows.text:ClearAllPoints()
    if tag then
        rows.text:SetPoint("TOPLEFT", rows.tag, "BOTTOMLEFT", 0, -SECTION_GAP)
    else
        rows.text:SetPoint("TOPLEFT", rows.tag, "TOPLEFT")
    end
    rows.text:SetText(text and text ~= "" and text or NO_NOTE)
    Color(rows.text, text and text ~= "" and T.fg or T.muted)
end

local function Shown()
    local unit, guid = IP.Current()
    if not guid then return nil end
    return unit, guid, IP.FullName(unit)
end

local function EditNote()
    local _, guid, name = Shown()
    local H = ns.PlayerHistory
    if not (guid and H and H.SetNote) then return end
    local note = H.Note(guid)
    local max = tonumber(H.NOTE_MAX) or NOTE_MAX
    ns.PromptText(NOTE_TITLE:format(name or ""), type(note) == "table" and note.text or "", max, function(text)
        local _, now = IP.Current()
        if now ~= guid then return end
        local current = H.Note(guid)
        H.SetNote(guid, text, type(current) == "table" and current.tag or nil, name)
        IP.Refresh()
    end)
end

local function IsTag(key)
    local H = ns.PlayerHistory
    local note = H and menuGUID and H.Note(menuGUID)
    local tag = type(note) == "table" and note.tag or false
    return tag == key
end

local function SetTag(key)
    local _, guid, name = Shown()
    local H = ns.PlayerHistory
    if not (H and guid and guid == menuGUID) then return end
    local note = H.Note(guid)
    H.SetNote(guid, type(note) == "table" and note.text or nil, key or nil, name)
    IP.Refresh()
end

local function ClearNote()
    local _, guid, name = Shown()
    local H = ns.PlayerHistory
    if not (H and guid and guid == menuGUID) then return end
    H.SetNote(guid, nil, nil, name)
    IP.Refresh()
end

local function TagMenu(owner)
    local _, guid = Shown()
    local H = ns.PlayerHistory
    if not (guid and H and H.SetNote) then return end
    menuGUID = guid
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(ns.L("Tag"))
        for _, tag in ipairs(type(H.TAGS) == "table" and H.TAGS or NONE) do
            root:CreateRadio(ns.PlainText(tag.label, NOTE_MAX), IsTag, SetTag, tag.key)
        end
        root:CreateRadio(ns.L("No tag"), IsTag, SetTag, false)
        if H.Note(guid) then
            root:CreateDivider()
            root:CreateButton(ns.L("Clear note"), ClearNote)
        end
    end)
end

local function Build()
    body = IP.bodies.player
    rows = {}
    local y = Section(0, "TALENTS")
    rows.points, y = Line(y)
    rows.build, y = Line(y)
    Color(rows.build.left, T.accentSoft)
    y = Section(y + SECTION_GAP, ns.L("THEIR GEAR"))
    rows.level, y = Line(y)
    rows.check, y = Line(y)
    rows.empty, y = Line(y)
    for _, key in ipairs(GEAR_ROWS) do Color(rows[key].left, T.muted) end
    rows.level.left:SetText(ITEM_LEVEL)
    rows.check.left:SetText(UNENCHANTED)
    rows.empty.left:SetText(EMPTY_SLOTS)
    y = Section(y + SECTION_GAP, "GUILD")
    rows.guild, y = Line(y)
    rows.link, y = Line(y)
    Color(rows.link.left, T.muted)
    Color(rows.link.right, St.HAVE_RGB)
    local note = CreateFrame("Frame", nil, body)
    note:SetPoint("TOPLEFT", 0, -(y + SECTION_GAP))
    note:SetPoint("BOTTOMRIGHT")
    rows.note = note
    local outer = body
    body = note
    local top = Section(0, "NOTE")
    body = outer
    local edit = Parts.Link(note, EditNote)
    Parts.SetLink(edit, "Note")
    edit:SetPoint("TOPRIGHT", 0, 0)
    local tag = Parts.Link(note, TagMenu)
    Parts.SetLink(tag, ns.L("Tag"))
    tag:SetPoint("RIGHT", edit, "LEFT", -LINK_GAP, 0)
    rows.tag = ns.Font(note, LINE_SIZE, nil, T.fg)
    rows.tag:SetPoint("TOPLEFT", 0, -top)
    rows.text = ns.Font(note, LINE_SIZE, nil, T.fg)
    rows.text:SetWidth(IP.BODY_W)
    rows.text:SetJustifyH("LEFT")
    rows.text:SetMaxLines(NOTE_LINES)
end

IP.OnApply(function(on)
    if on and not rows then Build() end
end)

IP.OnRefresh(function(unit, guid)
    if not guid then return end
    if IP.Ready(guid) then ReadTalents(unit, guid) end
    PaintTalents(guid)
    PaintGear(guid)
    PaintGuild(unit, guid)
    PaintNote(guid)
end)

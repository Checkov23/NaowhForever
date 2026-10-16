-- Builds.lua: the Builds tab: a class's builds down the left, the picked one level by level, or in the talent tree.
local ns = _G.NaowhForever

local T = ns.THEME

local Training = ns.Training
local C = Training.C
local Style = Training.Style
local Rows = Training.Rows
local V = Training.View
local Header, Take, Paint, Text, Icon = Rows.Header, Rows.Take, Rows.Paint, Rows.Text, Rows.Icon
local Parts = ns.Shared.Parts

local CLASSES = { 1, 2, 3, 4, 5, 7, 8, 9, 11 }
local CLASS_H, CLASS_GAP = 26, 6
local LIST_W, LIST_ROW = 250, 44
local PANE_GAP = 20
local SELECTED_BAR, PICKED = 2, 0.10
local NAME_X, NAME_DROP, SPEC_DROP, LINE_RIGHT = 12, 8, 4, 8
local SHARE_W = 64
local EDIT_W = 80
local EDIT_TABS_W = 240
local BUTTON_GAP = 6
local LEARN_W, FOLLOW_W = 140, 140
local STEP_LEVEL_X, STEP_LEVEL_W = 10, 90
local STEP_TEXT_GAP, STEP_STATE_RIGHT = 8, 10
local NODE, NODE_GAP, NODE_ROW = 36, 12, 56
local COUNT_GAP = 2
local CHECK, CHECK_X, TICK_INSET, CHECK_GAP = 16, 10, 4, 10
local SKIP_LEVEL_W = 70
local RANK_INDENT = 20
local TREE_ROWS, TREE_SLOTS = 7, 4
local SPEC_H = 28
local NODE_SPELL, NODE_RANKS, NODE_ROW_INDEX, NODE_COLUMN, NODE_SLOT = C.NODE_SPELL, C.NODE_RANKS, C.NODE_ROW, C.NODE_COLUMN, 5
local FONT_SMALL, FONT, FONT_ROW, FONT_COUNT = Style.FONT_SMALL, Style.FONT, Style.FONT_ROW, 10
local TEXT_SAVED_BY_YOU = ns.L("Saved by you")
local TEXT_SPEC_LINE = ns.L("%s, %d points")
local TEXT_LEVEL, TEXT_LEVELS = ns.L("Level "), ns.L("Levels ")
local TEXT_RANK = ns.L("Rank ")
local TEXT_OF = ns.L(" of ")
local TEXT_TAKEN = ns.L("Taken")
local TEXT_NEXT_NOW = ns.L("Next, spend it now")
local TEXT_NEXT_AT = ns.L("Next, at level ")
local TEXT_NODE_RANK = ns.L("Rank %d of %d")
local TEXT_NEXT_RANK = ns.L("Next rank:")
local TEXT_NAME_RANK = ns.L("%s (%s)")
local TEXT_NODE_HINT = ns.L("Click to take the next point here, right-click to give one back.")
local TEXT_UNDO, TEXT_CLEAR, TEXT_DONE = "Undo", "Clear", "Done"
local TEXT_SELECT_ALL = "Select All"
local TEXT_TALENTS, TEXT_SPELLS = "Talents", "Spells"
local TEXT_CLEAR_ASK = ns.L("Take every point out of %s?")
local TEXT_EDITING = ns.L("EDITING ")
local TEXT_EDIT_NOTE = ns.L("%d of %d points. Click talents in the order you take them")
local TEXT_SKIPS, TEXT_SKIPS_NOTE = ns.L("SPELLS TO SKIP"), ns.L("Checked spells are left out when you train; everything else is trained")
local TEXT_SKIPPING = ns.L(", skipping %d")
local TEXT_BY_LEVEL, TEXT_BY_LEVEL_NOTE = ns.L("LEVEL BY LEVEL"), ns.L("The order the points are taken in")
local TEXT_LEARN_NEXT = "Learn Next Points"
local TEXT_FOLLOW, TEXT_STOP_FOLLOW = "Follow This Build", "Stop Following"
local TEXT_EDIT, TEXT_COPY, TEXT_EXPORT, TEXT_DELETE = "Edit", "Copy", "Export", "Delete"
local TEXT_COPY_SUFFIX = ns.L(" Copy")
local TEXT_RENAME, TEXT_RENAME_ASK = "Rename", ns.L("Rename the build")
local TEXT_AFTER_FIGHT = ns.L("Talents can be learned once the fight is over.")
local TEXT_NO_POINTS = ns.L("You have no talent points to spend.")
local TEXT_NOT_BUILD = ns.L("The build's next talent cannot be taken now: your talents are not the build's.")
local TEXT_DELETE_ASK = ns.L("Delete the build %s?")
local TEXT_NO_BUILDS, TEXT_NO_BUILDS_NOTE = ns.L("NO BUILDS YET"), ns.L("Save your talents, start a new build, or import one")
local TEXT_BUILDS, TEXT_BUILDS_NOTE = ns.L("BUILDS"), ns.L("Builds you saved or imported")
local TEXT_OTHER_CLASS = ns.L("Another class's build, to look at")
local TEXT_TAKEN_COUNT = ns.L("%d of %d points taken")
local TEXT_FOLLOWING = ns.L(", following it as you level")

local BuildsView = {}
Training.BuildsView = BuildsView

local function Redraw()
    V.Render()
end

local function NewClassButton()
    return ns.Button(V.body, "", 1, CLASS_H)
end

local function PaintRest(b, accent)
    b._rest = accent and T.accent or Style.BORDER_RGB
    b._border:SetColor(b._rest.r, b._rest.g, b._rest.b, 1)
end

local function ClassRow(classID, y)
    local w = math.floor((V.body:GetWidth() - (#CLASSES - 1) * CLASS_GAP) / #CLASSES)
    for i, id in ipairs(CLASSES) do
        local b = Take("class", NewClassButton)
        b:SetPoint("TOPLEFT", V.body, "TOPLEFT", (i - 1) * (w + CLASS_GAP), y)
        b:SetWidth(w)
        local name, file = GetClassInfo(id)
        b.label:SetText(RAID_CLASS_COLORS[file]:WrapTextInColorCode(name))
        PaintRest(b, id == classID)
        b._onClick = function()
            V.buildClass, V.buildIndex, V.editing = id, 1, false
            Redraw()
        end
    end
    return y - CLASS_H - Style.SECTION_GAP
end

local function BuildRowEnter(self)
    if not self.picked then self.band:SetAlpha(Style.HOVER) end
end

local function BuildRowLeave(self)
    if not self.picked then self.band:SetAlpha(0) end
end

local function NewBuildRow()
    local r = CreateFrame("Button", nil, V.body)
    r:SetSize(LIST_W, LIST_ROW)
    Rows.ListRow(r)
    r.bar = ns.Solid(r, "ARTWORK", T.accent, 1)
    r.bar:SetPoint("TOPLEFT")
    r.bar:SetPoint("BOTTOMLEFT")
    r.bar:SetWidth(SELECTED_BAR)
    r.name = Text(r, FONT_ROW, nil)
    r.name:SetPoint("TOPLEFT", NAME_X, -NAME_DROP)
    r.spec = Text(r, FONT_SMALL, nil, T.muted)
    r.spec:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -SPEC_DROP)
    for _, line in ipairs({ r.name, r.spec }) do
        line:SetPoint("RIGHT", -LINE_RIGHT, 0)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
    end
    r:SetScript("OnEnter", BuildRowEnter)
    r:SetScript("OnLeave", BuildRowLeave)
    return r
end

local function BuildList(builds, y)
    for i, build in ipairs(builds) do
        local r = Take("buildRow", NewBuildRow)
        r:SetPoint("TOPLEFT", V.body, "TOPLEFT", 0, y)
        r.picked = i == V.buildIndex
        r.bar:SetShown(r.picked)
        r.band:SetAlpha(r.picked and PICKED or 0)
        r.name:SetText(build.name)
        local source = build.source or (build.saved and TEXT_SAVED_BY_YOU)
        r.spec:SetText(TEXT_SPEC_LINE:format(ns.L(build.spec), #build.points) .. (source and Style.PLACE_DOT .. source or ""))
        r:SetScript("OnClick", function()
            V.buildIndex, V.editing = i, false
            Redraw()
        end)
        Rows.Stripe(r)
        y = y - LIST_ROW
    end
    return y
end

local function TalentTip(self, rank)
    local entry = Training.TalentEntry(self.classID, self.node)
    if not entry then
        GameTooltip:SetSpellByID(self.spell)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(TEXT_NODE_RANK:format(rank, self.max), 1, 1, 1)
        return
    end
    GameTooltip_SetTitle(GameTooltip, C_Spell.GetSpellName(self.spell) or "")
    GameTooltip:AddLine(TEXT_NODE_RANK:format(rank, self.max), 1, 1, 1)
    if rank > 0 then GameTooltip:AppendInfo("GetTraitEntry", entry, rank) end
    if rank < self.max then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(TEXT_NEXT_RANK, 1, 1, 1)
        GameTooltip:AppendInfo("GetTraitEntry", entry, rank + 1)
    end
end

local function StepEnter(self)
    self.band:SetAlpha(Style.HOVER)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    TalentTip(self, self.last)
    GameTooltip:Show()
end

local function StepLeave(self)
    self.band:SetAlpha(0)
    GameTooltip:Hide()
end

local function NewStep()
    local r = CreateFrame("Button", nil, V.body)
    r:SetHeight(Style.ROW_H)
    Rows.ListRow(r)
    r.level = Text(r, FONT_ROW, nil)
    r.level:SetPoint("LEFT", STEP_LEVEL_X, 0)
    r.level:SetWidth(STEP_LEVEL_W)
    r.level:SetJustifyH("LEFT")
    r.icon = Icon(r, Style.ROW_ICON)
    r.icon.edge:SetPoint("LEFT", r.level, "RIGHT", 0, 0)
    r.name = Text(r, FONT_ROW, nil)
    r.name:SetPoint("LEFT", r.icon, "RIGHT", STEP_TEXT_GAP, 0)
    r.rank = Text(r, FONT, nil, T.muted)
    r.rank:SetPoint("LEFT", r.name, "RIGHT", STEP_TEXT_GAP, 0)
    r.state = Text(r, FONT, nil)
    r.state:SetPoint("RIGHT", -STEP_STATE_RIGHT, 0)
    r:SetScript("OnEnter", StepEnter)
    r:SetScript("OnLeave", StepLeave)
    return r
end

local function Span(first, last, one, many)
    if first == last then return one .. first end
    return many .. first .. "-" .. last
end

local function StepState(ranks, node, first, last, from, level, found)
    if ranks ~= nil and ranks[node] >= last then return T.muted, TEXT_TAKEN, true, found end
    if not ranks or found then return T.muted, "", false, found end
    local at = from + math.max(0, ranks[node] - first + 1)
    return T.accent, level >= at and TEXT_NEXT_NOW or (TEXT_NEXT_AT .. at), false, true
end

local function Steps(classID, build, talents, ranks, level, y)
    local points, count = build.points, {}
    local i, found = 1, false
    while i <= #points do
        local node, j = points[i], i
        while points[j + 1] == node do j = j + 1 end
        local spell, max = talents[node][NODE_SPELL], talents[node][NODE_RANKS]
        local first = (count[node] or 0) + 1
        local last = first + j - i
        count[node] = last
        local from, to = C.FIRST_TALENT_LEVEL + i - 1, C.FIRST_TALENT_LEVEL + j - 1
        local r = Take("step", NewStep)
        r:SetPoint("TOPLEFT", V.body, "TOPLEFT", V.paneX, y)
        r:SetPoint("TOPRIGHT", V.body, "TOPRIGHT", 0, y)
        r.spell, r.classID, r.node, r.last, r.max = spell, classID, node, last, max
        r.level:SetText(Span(from, to, TEXT_LEVEL, TEXT_LEVELS))
        r.icon:SetTexture(C_Spell.GetSpellTexture(spell))
        r.name:SetText(C_Spell.GetSpellName(spell) or "")
        r.rank:SetText(Span(first, last, TEXT_RANK, TEXT_RANK) .. TEXT_OF .. max)
        local color, text, taken
        color, text, taken, found = StepState(ranks, node, first, last, from, level, found)
        r:SetAlpha(taken and Style.LEARNED_ALPHA or 1)
        r.icon:SetDesaturated(taken)
        r.state:SetText(text)
        Paint(r.state, color)
        Rows.Stripe(r)
        y = y - Style.ROW_H
        i = j + 1
    end
    return y
end

local function NodeEnter(self)
    self.border:SetColor(T.accent.r, T.accent.g, T.accent.b, 1)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    TalentTip(self, self.rank)
    if self.why then
        local c = Style.WARN_RGB
        GameTooltip:AddLine(self.why, c.r, c.g, c.b, true)
    end
    GameTooltip:AddLine(TEXT_NODE_HINT, T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function NodeLeave(self)
    self.border:SetColor(self.rest.r, self.rest.g, self.rest.b, 1)
    GameTooltip:Hide()
end

local function NewNode()
    local b = CreateFrame("Button", nil, V.body)
    b:SetSize(NODE, NODE)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.icon = Rows.Crop(b:CreateTexture(nil, "ARTWORK"))
    b.icon:SetAllPoints()
    b.border = ns.Border(b, Style.BORDER_RGB)
    b.count = Text(b, FONT_COUNT, nil)
    b.count:SetPoint("TOP", b, "BOTTOM", 0, -COUNT_GAP)
    b:SetScript("OnEnter", NodeEnter)
    b:SetScript("OnLeave", NodeLeave)
    return b
end

local function NewSpecTitle()
    local h = CreateFrame("Frame", nil, V.body)
    h:SetHeight(SPEC_H)
    h.text = Text(h, FONT_ROW, nil)
    h.text:SetPoint("LEFT")
    return h
end

local function NewEditButton()
    return ns.Button(V.body, "", EDIT_W, Style.SKIP_H + BUTTON_GAP)
end

local function EditDone()
    V.editing = false
    Redraw()
end

local function EditActions(classID, tree, build)
    if V.editTab == "spells" then
        return {
            { TEXT_SELECT_ALL, function() Training.SkipAll(classID, build, true) end },
            { TEXT_CLEAR, function() Training.SkipAll(classID, build, false) end },
            { TEXT_DONE, EditDone },
        }
    end
    return {
        { TEXT_UNDO, function()
            if #build.points > 0 then Training.UndoPoint(tree, build) end
        end },
        { TEXT_CLEAR, function()
            ns.Confirm(TEXT_CLEAR_ASK:format(build.name), function() Training.ClearPoints(build) end)
        end },
        { TEXT_DONE, EditDone },
    }
end

local function PickEditTab(key)
    V.editTab = key
    Redraw()
end

local function NewEditTabs()
    return Parts.Tabs(V.body, EDIT_TABS_W, {
        { key = "talents", label = TEXT_TALENTS },
        { key = "spells", label = TEXT_SPELLS },
    }, PickEditTab)
end

local function EditTabs(y)
    local bar = Take("editTabs", NewEditTabs)
    bar:SetPoint("TOPLEFT", V.body, "TOPLEFT", V.paneX, y)
    Parts.PaintTabs(bar, V.editTab)
    return y - Style.TAB_H - BUTTON_GAP
end

local function EditButtons(classID, tree, build, y)
    local actions = EditActions(classID, tree, build)
    for i, action in ipairs(actions) do
        local b = Take("edit", NewEditButton)
        b:SetPoint("TOPLEFT", V.body, "TOPLEFT", V.paneX + (i - 1) * (EDIT_W + BUTTON_GAP), y)
        ns.SetButtonText(b, action[1])
        b._onClick = action[2]
    end
    return y - Style.SKIP_H - BUTTON_GAP - Style.SECTION_GAP
end

local function SkipEnter(self)
    self.band:SetAlpha(Style.HOVER)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(self.spell)
    GameTooltip:Show()
end

local function NewSkipRow()
    local r = CreateFrame("Button", nil, V.body)
    r:SetHeight(Style.ROW_H)
    Rows.ListRow(r)
    local check = CreateFrame("Frame", nil, r)
    check:SetSize(CHECK, CHECK)
    check:SetPoint("LEFT", CHECK_X, 0)
    r.check = check
    ns.Solid(check, "BACKGROUND", T.panel, 1):SetAllPoints()
    r.box = ns.Border(check, T.line)
    r.tick = ns.Solid(check, "ARTWORK", T.accent, 1)
    r.tick:SetPoint("TOPLEFT", TICK_INSET, -TICK_INSET)
    r.tick:SetPoint("BOTTOMRIGHT", -TICK_INSET, TICK_INSET)
    r.icon = Icon(r, Style.ROW_ICON)
    r.icon.edge:SetPoint("LEFT", check, "RIGHT", CHECK_GAP, 0)
    r.name = Text(r, FONT_ROW, nil)
    r.name:SetPoint("LEFT", r.icon, "RIGHT", STEP_TEXT_GAP, 0)
    r.level = Text(r, FONT, nil, T.muted)
    r.level:SetPoint("RIGHT", -STEP_STATE_RIGHT, 0)
    r.level:SetWidth(SKIP_LEVEL_W)
    r.level:SetJustifyH("RIGHT")
    r:SetScript("OnEnter", SkipEnter)
    r:SetScript("OnLeave", StepLeave)
    return r
end

local function SkipRankName(group, rank)
    local subtext = C_Spell.GetSpellSubtext(group.spells[rank])
    if not subtext or subtext == "" then return group.name end
    return TEXT_NAME_RANK:format(group.name, subtext)
end

local function SkipRow(build, group, rank, y)
    local r = Take("skip", NewSkipRow)
    r:SetPoint("TOPLEFT", V.body, "TOPLEFT", V.paneX, y)
    r:SetPoint("TOPRIGHT", V.body, "TOPRIGHT", 0, y)
    r.check:SetPoint("LEFT", CHECK_X + (rank and RANK_INDENT or 0), 0)
    r.group, r.rank, r.spell = group, rank, group.spells[rank or 1]
    local on = Training.IsSkipping(build, group, rank)
    r.tick:SetShown(on)
    local c = on and T.accent or T.line
    r.box:SetColor(c.r, c.g, c.b, 1)
    r.icon:SetTexture(C_Spell.GetSpellTexture(r.spell))
    r.name:SetText(rank and SkipRankName(group, rank) or group.name)
    r.level:SetText(TEXT_LEVEL .. group.levels[rank or 1])
    r:SetAlpha(on and 1 or Style.LEARNED_ALPHA)
    r:SetScript("OnClick", function() Training.ToggleSkip(build, group, rank) end)
    Rows.Stripe(r)
    return y - Style.ROW_H
end

local function DrawSkips(classID, build, y)
    local skipped = Training.SkipCount(build)
    y = Header(y, TEXT_SKIPS, skipped > 0 and skipped or nil, TEXT_SKIPS_NOTE)
    for _, group in ipairs(Training.SkipGroups(classID)) do
        y = SkipRow(build, group, nil, y)
        if #group.spells > 1 then
            for rank = 1, #group.spells do y = SkipRow(build, group, rank, y) end
        end
    end
    return y - Style.SECTION_GAP
end

local function Spent(tree, points)
    local count, spent = {}, {}
    for _, node in ipairs(points) do
        count[node] = (count[node] or 0) + 1
        local col = tree.talents[node][NODE_COLUMN]
        spent[col] = (spent[col] or 0) + 1
    end
    return count, spent
end

local function DrawNode(classID, tree, build, node, talent, count, x, y)
    local points = build.points
    local b = Take("node", NewNode)
    b:SetPoint("TOPLEFT", V.body, "TOPLEFT", x, y)
    b.spell, b.classID, b.node, b.rank, b.max = talent[NODE_SPELL], classID, node, count[node] or 0, talent[NODE_RANKS]
    points[#points + 1] = node
    b.why = Training.CheckBuild(tree, points)
    points[#points] = nil
    b.icon:SetTexture(C_Spell.GetSpellTexture(talent[NODE_SPELL]))
    b.icon:SetDesaturated(b.rank == 0 and b.why ~= nil)
    b.count:SetText(b.rank .. "/" .. b.max)
    Paint(b.count, b.rank == b.max and T.accent or b.rank > 0 and T.fg or T.muted)
    b.rest = b.rank > 0 and T.accent or Style.BORDER_RGB
    b.border:SetColor(b.rest.r, b.rest.g, b.rest.b, 1)
    b:SetScript("OnClick", function(_, button)
        local why
        if button == "RightButton" then
            why = Training.RemovePoint(tree, build, node)
        else
            why = Training.AddPoint(tree, build, node)
        end
        if why then ns.Print(why) end
    end)
end

local function DrawEditor(classID, tree, build, level, y)
    local points = build.points
    y = Header(y, TEXT_EDITING .. build.name:upper(), nil, TEXT_EDIT_NOTE:format(#points, C.MAX_POINTS))
    y = EditTabs(y)
    y = EditButtons(classID, tree, build, y)
    if V.editTab == "spells" then return DrawSkips(classID, build, y) end
    local count, spent = Spent(tree, points)
    local colW = math.floor((V.body:GetWidth() - V.paneX) / #tree.specs)
    local gridW = TREE_SLOTS * NODE + (TREE_SLOTS - 1) * NODE_GAP
    local function Left(col) return V.paneX + (col - 1) * colW + math.floor((colW - gridW) / 2) end
    for col, spec in ipairs(tree.specs) do
        local h = Take("spec", NewSpecTitle)
        h:SetPoint("TOPLEFT", V.body, "TOPLEFT", Left(col), y)
        h:SetWidth(gridW)
        h.text:SetText(spec .. "  " .. ns.Color("accent", spent[col] or 0))
    end
    local top = y - SPEC_H
    for node, talent in pairs(tree.talents) do
        local col, row, slot = talent[NODE_COLUMN], talent[NODE_ROW_INDEX], talent[NODE_SLOT]
        DrawNode(classID, tree, build, node, talent, count, Left(col) + (slot - 1) * (NODE + NODE_GAP), top - (row - 1) * NODE_ROW)
    end
    y = top - TREE_ROWS * NODE_ROW - Style.SECTION_GAP
    y = Header(y, TEXT_BY_LEVEL, #points, TEXT_BY_LEVEL_NOTE)
    return Steps(classID, build, tree.talents, nil, level, y)
end

local function NewActionButton()
    return ns.Button(V.body, "", SHARE_W, Style.SKIP_H + BUTTON_GAP)
end

local function LearnNext(classID, build)
    local bought = Training.LearnBuild(classID, build)
    if bought > 0 then
        ns.Print(Training.LearnedText(bought, build.name))
    elseif InCombatLockdown() then
        ns.Print(TEXT_AFTER_FIGHT)
    elseif not C_ClassTalents.HasUnspentTalentPoints() then
        ns.Print(TEXT_NO_POINTS)
    else
        ns.Print(TEXT_NOT_BUILD)
    end
end

local function OwnActions(actions, classID, build)
    local following = Training.Followed() == build
    actions[#actions + 1] = { TEXT_LEARN_NEXT, LEARN_W, function() LearnNext(classID, build) end }
    actions[#actions + 1] = { following and TEXT_STOP_FOLLOW or TEXT_FOLLOW, FOLLOW_W, function()
        Training.Follow(classID, not following and build or nil)
    end, following }
end

local function ShareActions(actions, classID, build)
    local saved = build.saved == true
    if saved then
        actions[#actions + 1] = { TEXT_EDIT, SHARE_W, function()
            V.editing, V.editTab = true, "talents"
            Redraw()
        end }
        actions[#actions + 1] = { TEXT_RENAME, SHARE_W, function()
            ns.PromptText(TEXT_RENAME_ASK, build.name, C.BUILD_NAME_MAX, function(name)
                Training.RenameBuild(build, name)
            end)
        end }
    else
        actions[#actions + 1] = { TEXT_COPY, SHARE_W, function()
            V.buildIndex, V.editing, V.editTab = Training.NewBuild(classID, build.name .. TEXT_COPY_SUFFIX, build), true, "talents"
            Redraw()
        end }
    end
    actions[#actions + 1] = { TEXT_EXPORT, SHARE_W, function()
        ns.ShowCopyBox(build.name, Training.ExportBuild(classID, build))
    end }
    if not saved then return end
    actions[#actions + 1] = { TEXT_DELETE, SHARE_W, function()
        ns.Confirm(TEXT_DELETE_ASK:format(build.name), function()
            V.buildIndex, V.editing = 1, false
            Training.DeleteBuild(classID, build)
        end)
    end }
end

local function BuildActions(classID, build, ownClass, y)
    local actions = {}
    if ownClass then OwnActions(actions, classID, build) end
    ShareActions(actions, classID, build)
    local x = V.paneX
    for _, action in ipairs(actions) do
        local b = Take("action", NewActionButton)
        b:SetPoint("TOPLEFT", V.body, "TOPLEFT", x, y)
        b:SetWidth(action[2])
        ns.SetButtonText(b, action[1])
        b._onClick = action[3]
        PaintRest(b, action[4])
        x = x + action[2] + BUTTON_GAP
    end
    return y - Style.SKIP_H - BUTTON_GAP - Style.SECTION_GAP
end

local function TakenNote(build, ranks)
    if not ranks then return TEXT_OTHER_CLASS end
    local taken, count = 0, {}
    for _, node in ipairs(build.points) do
        count[node] = (count[node] or 0) + 1
        if ranks[node] >= count[node] then taken = taken + 1 end
    end
    return TEXT_TAKEN_COUNT:format(taken, #build.points)
        .. (Training.SkipCount(build) > 0 and TEXT_SKIPPING:format(Training.SkipCount(build)) or "")
        .. (Training.Followed() == build and TEXT_FOLLOWING or "")
end

local function DrawPicked(classID, myClass, tree, build, level, y)
    if V.editing and build.saved then return DrawEditor(classID, tree, build, level, y) end
    local ranks = classID == myClass and Training.Ranks(tree.talents) or nil
    local bottom = Header(y, build.name:upper(), nil, TakenNote(build, ranks))
    bottom = BuildActions(classID, build, ranks ~= nil, bottom)
    return Steps(classID, build, tree.talents, ranks, level, bottom)
end

function BuildsView.Draw(level, y)
    local _, _, myClass = UnitClass("player")
    local classID = V.buildClass or myClass
    y = ClassRow(classID, y)
    local tree = ns.TrainingBuilds[classID]
    local builds = Training.Builds(classID)
    if #builds == 0 then return Header(y, TEXT_NO_BUILDS, nil, TEXT_NO_BUILDS_NOTE) end
    if not builds[V.buildIndex] then V.buildIndex = 1 end
    y = Header(y, TEXT_BUILDS, #builds, TEXT_BUILDS_NOTE)
    local listBottom = BuildList(builds, y)
    V.paneX = LIST_W + PANE_GAP
    local bottom = DrawPicked(classID, myClass, tree, builds[V.buildIndex], level, y)
    V.paneX = 0
    return math.min(listBottom, bottom)
end

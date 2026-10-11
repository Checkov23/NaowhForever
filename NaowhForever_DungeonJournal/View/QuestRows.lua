-- QuestRows.lua: your quests in a dungeon as rows: marks, hover card and right-click menu.
local ns = _G.NaowhForever

local GetItemCount, GetItemIconByID, GetItemNameByID = C_Item.GetItemCount, C_Item.GetItemIconByID,
    C_Item.GetItemNameByID

local T = ns.THEME
local J = ns.Journal
local Quests = J.Quests
local View = J.View
local Kinds, Parts = View.Kinds, View.Parts
local IconButton, Plain, Tip = Parts.IconButton, Parts.Plain, Parts.Tip
local ForeverInline, ForeverLine = Parts.ForeverInline, Parts.ForeverLine
local IsForever, CARD_DROP = Parts.IsForever, Parts.CARD_DROP
local QUEST = J.C.QUEST
local St = J.Style
local QUEST_CODE, HAVE_RGB, BANG, QUESTION = St.QUEST_CODE, St.HAVE_RGB, St.BANG, St.QUESTION
local PIN, CHAIN, CHECK, GAP = St.PIN, St.CHAIN, St.CHECK, St.GAP
local PEOPLE, PARTY_SLOT, BAG, QUESTION_ICON = St.PEOPLE, St.PARTY_SLOT, St.BAG, St.QUESTION_ICON
local QUEST_TOP, QUEST_LINE_GAP, QUEST_BOTTOM = St.QUEST_TOP, St.QUEST_LINE_GAP, St.QUEST_BOTTOM
local MARK, CHAIN_SLOT, WAYPOINT_SLOT = St.MARK, St.CHAIN_SLOT, St.WAYPOINT_SLOT
local ROW_LEFT, QUEST_RIGHT = St.ROW_LEFT, St.QUEST_RIGHT
local SMALL_SIZE, TITLE_SIZE, TIP_X = St.SMALL_SIZE, St.HEADING_SIZE, St.CURSOR_TIP_X

local MARK_GAP, TITLE_GAP = 4, 6
local MARK_LEFT = ROW_LEFT + WAYPOINT_SLOT + MARK_GAP
local TITLE_LEFT = MARK_LEFT + MARK + TITLE_GAP
local PARTY_RIGHT = QUEST_RIGHT
local CHAIN_RIGHT = PARTY_RIGHT + PARTY_SLOT + GAP * 2
local RIGHT_W = CHAIN_RIGHT + CHAIN_SLOT
local PIN_MARGIN, CHAIN_MARGIN = 4, 2
local CHAIN_CELLS, PARTY_CELLS = 5, 2
local CELL_GAP = 3
local MARK_HIT_PAD = 4
local NAME_LIFT, NAME_PAD = 2, 4
local ROLE_ICON = 14
local STRIPE_EVERY = J.C.STRIPE_EVERY
local TAKE_STRIDE = 2
local FROM_FIRST_NAME = 3
local HEX_BASE, BYTE = J.C.HEX_BASE, J.C.BYTE
local HEX_CODE = "^|c%x%x(%x%x)(%x%x)(%x%x)"

local STATUS = {
    prereq = ns.L("Prerequisite"), prereqLog = ns.L("Prerequisite"), low = ns.L("Level %d to pick up"), pickup = ns.L("To pick up"),
    tooHigh = ns.L("Too high (%d)"), next = ns.L("Next step"), active = ns.L("In log"), ready = ns.L("Complete"),
}
local CHAIN_STATE = {
    active = QUEST_CODE.active .. ns.L("In log|r"), done = QUEST_CODE.done .. ns.L("Finished|r"),
    todo = QUEST_CODE.done .. ns.L("Not done|r"),
}
local SIDE = { A = ns.L("Alliance"), H = ns.L("Horde"), B = ns.L("Alliance and Horde") }
local SAID_BELOW = { prereq = true, prereqLog = true }

local TEXT_CODE_END = "|r"
local TEXT_CHAIN_TITLE = ns.L("%s: step %d of %d")
local TEXT_CHAIN_HINT = ns.L("Click a step for a waypoint.")
local TEXT_STEP = "%d.  %s  %s"
local TEXT_STEP_DONE = "%d.  %s|r  "
local TEXT_DUNGEON_QUEST = ns.L("(dungeon quest)")
local TEXT_TRACK = ns.L("Track in Quest Log")
local TEXT_NO_CHAT = ns.L("Join a group, or open your chat box first.")
local TEXT_CHAT_LOCKED = ns.L("Chat is locked right now.")
local TEXT_PARTY, TEXT_CHAT = ns.L("Party"), "Chat"
local TEXT_LINK_IN = ns.L("Link in ")
local TEXT_WAYPOINT = ns.L("Waypoint")
local TEXT_SHOW_CHAIN = ns.L("Show Chain")
local TEXT_COPY_WOWHEAD = ns.L("Copy Wowhead Link")
local TEXT_QUEST_ID = ns.L("Quest ID")
local TEXT_LEVEL = ns.L("Level")
local TEXT_PICKED_UP = ns.L("   picked up from %d")
local TEXT_FOR = ns.L("For")
local TEXT_EVERYONE = ns.L("everyone")
local TEXT_STARTS = ns.L("Starts")
local TEXT_CHAIN = ns.L("Chain")
local TEXT_AFTER, TEXT_THEN = ns.L("after "), ns.L("then ")
local TEXT_STEP_OF = ns.L("step %d of %d")
local TEXT_SHARING = ns.L("Sharing")
local TEXT_SHAREABLE = ns.L("can be shared with your party")
local TEXT_NOT_SHAREABLE = ns.L("cannot be shared")
local TEXT_YOUR_PARTY = ns.L("Your party")
local TEXT_HAS_IT = ns.L("has it")
local TEXT_NOT_CLASS = ns.L("not their class")
local TEXT_TOO_LOW = ns.L("level %d, needs %d")
local TEXT_NOT_ON_IT = ns.L("not on it")
local TEXT_UNKNOWN = "?"
local TEXT_REP_EACH = ns.L("+%d reputation each time you hand it in")
local TEXT_HELD_ONCE = ns.L("Your bags hold enough to hand it in once")
local TEXT_HELD_TIMES = ns.L("Your bags hold enough to hand it in %d times")
local TEXT_TAKES = ns.L("It takes")
local TEXT_TAKE_LINE = "|T%d:0|t %d %s"
local TEXT_ITEM = ns.L("item ")
local TEXT_IN_BAGS = ns.L("%d in your bags")
local TEXT_FROM = ns.L("Where to get them")
local TEXT_MORE = ns.L(" and %d more")
local TEXT_HAND_IN_HINT = ns.L("Pin: a waypoint to who takes it    Right-click: Share, Link")
local TEXT_SHARE_HINT = ns.L("Right-click: Share, Link")
local TEXT_TOO_HARD = ns.L("It is level %d, five or more above you, so it will be hard for now.")
local TEXT_CLICK_DETAILS = ns.L("Click: details    ")
local TEXT_MENU_HINT = ns.L("Right-click: Share, Link, Track")
local TEXT_PIN_HINT = ns.L("    Pin: waypoint")
local TEXT_SHARE_WAYPOINT = ns.L("Share the waypoint")
local TEXT_NO_ONE = ns.L("No one else in your group is on this quest")
local TEXT_IN_GROUP = ns.L("In your group on this quest")
local TEXT_ASK_SHARE = ns.L("Click to ask them, one at a time, to share it (they need Naowh Forever).")
local TEXT_WAYPOINT_HINT = ns.L("Right-click to share it in chat, or copy it.")
local TEXT_BAG_ENOUGH = ns.L("In your bags: enough to hand it in %d %s")
local TEXT_TIME, TEXT_TIMES = ns.L("time"), ns.L("times")
local TEXT_BAG_SHORT = ns.L("In your bags: not enough to hand it in yet")
local TEXT_CHAIN_STEP = ns.L("Chain: step %d of %d")
local TEXT_ALONE = ns.L("On its own: no quest leads to it or follows it")
local TEXT_FRACTION = "%s/%s"
local TEXT_ONE_OF_ONE = "1/1"
local TEXT_SPACER = "  "
local TEXT_LIST = ", "
local TEXT_BLANK = " "

local CHECK_ICON = "|T" .. CHECK .. ":0|t "
local EMPTY = {}

local function RGB(code)
    local r, g, b = code:match(HEX_CODE)
    return { r = tonumber(r, HEX_BASE) / BYTE, g = tonumber(g, HEX_BASE) / BYTE, b = tonumber(b, HEX_BASE) / BYTE }
end

local GREY, RED = RGB(QUEST_CODE.low), RGB(QUEST_CODE.tooHigh)
local YELLOW = RGB(QUEST_CODE.prereqLog)
local MARKS = {
    pickup = { BANG }, next = { BANG },
    prereq = { BANG, GREY }, prereqLog = { BANG, GREY },
    low = { BANG, RED }, tooHigh = { BANG, RED },
    active = { QUESTION, T.muted }, ready = { QUESTION },
}
local ROLES = {}
for code, atlas in pairs(St.ROLE_ATLAS) do
    ROLES[code] = CreateAtlasMarkup(atlas, ROLE_ICON, ROLE_ICON) .. TEXT_BLANK .. St.ROLE_NAME[code]
end

local function Hint(text)
    GameTooltip:AddLine(text, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
end

local function Shown(entry)
    return entry.tooHigh and "tooHigh" or entry.kind
end

local function StatusWords(entry)
    local shown = Shown(entry)
    local text = STATUS[shown]
    if shown == "low" then text = text:format(Quests.MinLevel(entry.quest)) end
    if shown == "tooHigh" then text = text:format(entry.level) end
    return text
end

local function StatusText(entry)
    return QUEST_CODE[Shown(entry)] .. StatusWords(entry) .. TEXT_CODE_END
end

local function PaintMark(mark, entry)
    local look = MARKS[Shown(entry)] or MARKS.pickup
    local tint = look[2]
    mark:SetTexture(look[1])
    mark:SetDesaturated(tint ~= nil)
    if tint then mark:SetVertexColor(tint.r, tint.g, tint.b) else mark:SetVertexColor(1, 1, 1) end
end

local function StepLine(i, state, name, own)
    local text = TEXT_STEP:format(i, name, CHAIN_STATE[state])
    if state == "done" then text = QUEST_CODE.done .. TEXT_STEP_DONE:format(i, name) .. CHAIN_STATE.done end
    if i == own then text = text .. "  " .. ns.Color("accentSoft", TEXT_DUNGEON_QUEST) end
    return text
end

local function AddStep(root, i, step, own)
    local state, id = Quests.StepState(step)
    local name = Quests.StepName(id)
    local text = StepLine(i, state, name, own)
    if state ~= "done" and (state == "active" or Quests.StepHasSpot(step, id)) then
        root:CreateButton(text, function() Quests.StepWaypoint(step, state, id, name) end)
    else
        root:CreateTitle(text, WHITE_FONT_COLOR)
    end
end

local function OpenChain(owner, quest)
    local chain, own = Quests.Chain(quest)
    if not chain then return end
    local logged = Quests.LoggedID(quest)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(TEXT_CHAIN_TITLE:format(Quests.Name(quest), own, #chain))
        root:CreateTitle(ns.Color("muted", TEXT_CHAIN_HINT))
        for i, step in ipairs(chain) do AddStep(root, i, step, own) end
        if not logged then return end
        root:CreateDivider()
        root:CreateButton(TEXT_TRACK, function() Quests.Track(logged) end)
    end)
end

local function LinkChannel()
    if IsInGroup() then return Parts.PartyChat(), TEXT_PARTY end
    return nil, TEXT_CHAT
end

local function ChatBoxOpen()
    return ChatFrameUtil.GetActiveWindow() ~= nil
end

local function NoChatTip(tooltip)
    GameTooltip_SetTitle(tooltip, TEXT_NO_CHAT)
end

local function LinkInChat(id)
    local link = GetQuestLink(id)
    if not link or ChatFrameUtil.InsertLink(link) then return end
    local channel = LinkChannel()
    if not channel then return end
    if C_ChatInfo.InChatMessagingLockdown() then
        ns.Print(TEXT_CHAT_LOCKED)
        return
    end
    C_ChatInfo.SendChatMessage(link, channel)
end

local function AddLinkButton(root, linkID)
    local channel, where = LinkChannel()
    local linkable = GetQuestLink(linkID) ~= nil
    local reachable = channel ~= nil or ChatBoxOpen()
    local link = root:CreateButton(TEXT_LINK_IN .. where, function() LinkInChat(linkID) end)
    link:SetEnabled(linkable and reachable)
    if linkable and not reachable then link:SetTooltip(NoChatTip) end
end

local function OpenQuestMenu(row)
    local entry = row.entry
    local quest, logged, name, canWaypoint = entry.quest, entry.loggedID, entry.name, entry.canWaypoint
    local linkID = logged or quest[QUEST.ID]
    local shareable = logged ~= nil and IsInGroup() and C_QuestLog.IsPushableQuest(logged)
    MenuUtil.CreateContextMenu(row, function(_, root)
        root:CreateTitle(name)
        root:CreateButton(SHARE_QUEST, function()
            QuestLogPushQuest(C_QuestLog.GetLogIndexForQuestID(logged))
        end):SetEnabled(shareable)
        AddLinkButton(root, linkID)
        root:CreateDivider()
        if canWaypoint then root:CreateButton(TEXT_WAYPOINT, function() Quests.Waypoint(quest) end) end
        if Quests.Chain(quest) then root:CreateButton(TEXT_SHOW_CHAIN, function() OpenChain(row, quest) end) end
        if logged then root:CreateButton(TEXT_TRACK, function() Quests.Track(logged) end) end
        root:CreateDivider()
        root:CreateButton(TEXT_COPY_WOWHEAD, function()
            ns.ShowCopyCard("quest", TEXT_QUEST_ID, quest[QUEST.ID], name)
        end)
    end)
end

local function ProgressLines(entry)
    if not entry.inLog then return end
    for _, objective in ipairs(C_QuestLog.GetQuestObjectives(entry.loggedID) or EMPTY) do
        local text = objective.text
        if text and text ~= "" then
            if objective.finished then
                GameTooltip:AddLine(CHECK_ICON .. text, T.muted.r, T.muted.g, T.muted.b, true)
            else
                GameTooltip:AddLine(text, 1, 1, 1, true)
            end
        end
    end
end

local function Fact(label, text)
    GameTooltip:AddLine(ns.Color("muted", label .. TEXT_SPACER) .. text, 1, 1, 1, true)
end

local function StepNameAt(chain, i)
    local _, id = Quests.StepState(chain[i])
    return Quests.StepName(id)
end

local function ChainFact(quest)
    local chain, own = Quests.Chain(quest)
    if not chain then return end
    local around = {}
    if chain[own - 1] then around[#around + 1] = TEXT_AFTER .. StepNameAt(chain, own - 1) end
    if chain[own + 1] then around[#around + 1] = TEXT_THEN .. StepNameAt(chain, own + 1) end
    local rest = #around > 0 and ns.Color("muted", ": ") .. table.concat(around, TEXT_LIST) or ""
    Fact(TEXT_CHAIN, TEXT_STEP_OF:format(own, #chain) .. rest)
end

local function ForWhom(quest)
    local class = quest.class
    if class then return ns.L((class:sub(1, 1) .. class:sub(2):lower()) .. "s") end
    return SIDE[quest[QUEST.SIDE]] or TEXT_EVERYONE
end

local function DetailLines(entry)
    local quest = entry.quest
    local need = Quests.MinLevel(quest)
    if entry.level then
        Fact(TEXT_LEVEL, entry.level .. (need and ns.Color("muted", TEXT_PICKED_UP:format(need)) or ""))
    end
    Fact(TEXT_FOR, ForWhom(quest))
    local where = quest[QUEST.WHERE]
    if where and where ~= "" then Fact(TEXT_STARTS, Plain(where)) end
    ChainFact(quest)
    local shareable = quest[QUEST.SHAREABLE]
    if shareable == true then
        Fact(TEXT_SHARING, TEXT_SHAREABLE)
    elseif shareable == false then
        Fact(TEXT_SHARING, TEXT_NOT_SHAREABLE)
    end
end

local function MemberState(unit, entry, need)
    local quest = entry.quest
    if Quests.UnitOnQuest(unit, quest, entry.loggedID) then return TEXT_HAS_IT, HAVE_RGB end
    local _, class = UnitClass(unit)
    if quest.class and class ~= quest.class then return TEXT_NOT_CLASS, T.muted end
    local level = UnitLevel(unit)
    if need and level and level > 0 and level < need then return TEXT_TOO_LOW:format(level, need), T.muted end
    return TEXT_NOT_ON_IT, T.muted
end

local function PartyLines(entry)
    local members = GetNumSubgroupMembers()
    if members == 0 then return end
    local need = Quests.MinLevel(entry.quest)
    GameTooltip:AddLine(TEXT_BLANK)
    Hint(TEXT_YOUR_PARTY)
    for i = 1, members do
        local unit = "party" .. i
        local text, color = MemberState(unit, entry, need)
        GameTooltip:AddDoubleLine(UnitName(unit) or TEXT_UNKNOWN, text, T.fg.r, T.fg.g, T.fg.b, color.r, color.g, color.b)
    end
end

local function TakesLines(takes)
    for i = 1, #takes, TAKE_STRIDE do
        local id, need = takes[i], takes[i + 1]
        local have = GetItemCount(id)
        local color = have >= need and HAVE_RGB or T.muted
        GameTooltip:AddDoubleLine(TEXT_TAKE_LINE:format(GetItemIconByID(id) or QUESTION_ICON, need,
            GetItemNameByID(id) or (TEXT_ITEM .. id)), TEXT_IN_BAGS:format(have),
            T.fg.r, T.fg.g, T.fg.b, color.r, color.g, color.b)
    end
end

local function FromLines(from)
    if not from then return end
    GameTooltip:AddLine(TEXT_BLANK)
    Hint(TEXT_FROM)
    for _, place in ipairs(from) do
        local more = place[2] - (#place - FROM_FIRST_NAME + 1)
        GameTooltip:AddLine(ns.Color("fg", place[1]) .. TEXT_SPACER .. table.concat(place, TEXT_LIST, FROM_FIRST_NAME)
            .. (more > 0 and TEXT_MORE:format(more) or ""), T.muted.r, T.muted.g, T.muted.b, true)
    end
end

local function TurnInLines(entry)
    local turnin, held = entry.turnin, entry.held
    GameTooltip:AddLine(TEXT_REP_EACH:format(turnin.rep), 1, 1, 1)
    if held > 0 then
        GameTooltip:AddLine(QUEST_CODE.ready .. (held == 1 and TEXT_HELD_ONCE or TEXT_HELD_TIMES:format(held))
            .. TEXT_CODE_END)
    end
    GameTooltip:AddLine(TEXT_BLANK)
    Hint(TEXT_TAKES)
    TakesLines(turnin.takes)
    FromLines(turnin.from)
end

local function TooHighLine(entry)
    if entry.tooHigh then GameTooltip:AddLine(TEXT_TOO_HARD:format(entry.level), 1, 1, 1, true) end
end

local function TurnInCard(entry)
    TurnInLines(entry)
    PartyLines(entry)
    GameTooltip:AddLine(TEXT_BLANK)
    Hint(entry.canWaypoint and TEXT_HAND_IN_HINT or TEXT_SHARE_HINT)
end

local function QuestCard(row, entry)
    if row:GetParent().tight then
        GameTooltip:AddLine(Plain(entry.where), T.muted.r, T.muted.g, T.muted.b, true)
    end
    if not SAID_BELOW[entry.kind] then GameTooltip:AddLine(StatusText(entry)) end
    TooHighLine(entry)
    ProgressLines(entry)
    GameTooltip:AddLine(TEXT_BLANK)
    DetailLines(entry)
    PartyLines(entry)
    GameTooltip:AddLine(TEXT_BLANK)
    Hint((entry.loggedID and TEXT_CLICK_DETAILS or "") .. TEXT_MENU_HINT .. (entry.canWaypoint and TEXT_PIN_HINT or ""))
end

local function QuestEnter(hit)
    local row = hit:GetParent()
    row.hover:Show()
    local entry = row.entry
    if not Tip(hit, "ANCHOR_CURSOR_RIGHT", TIP_X, 0) then return end
    GameTooltip:SetText(entry.name)
    if row.forever then GameTooltip:AddLine(ForeverLine()) end
    if entry.turnin then TurnInCard(entry) else QuestCard(row, entry) end
    GameTooltip:Show()
end

local function MarkEnter(hit)
    local row = hit:GetParent()
    row.hover:Show()
    local entry = row.entry
    if not Tip(hit, "ANCHOR_RIGHT") then return end
    local c = (MARKS[Shown(entry)] or MARKS.pickup)[2] or YELLOW
    GameTooltip:SetText(StatusWords(entry), c.r, c.g, c.b)
    if SAID_BELOW[entry.kind] and entry.where then
        GameTooltip:AddLine(Plain(entry.where), 1, 1, 1, true)
    end
    TooHighLine(entry)
    ProgressLines(entry)
    GameTooltip:Show()
end

local function QuestLeave(hit)
    local row = hit:GetParent()
    if not row:IsMouseOver() then row.hover:Hide() end
    GameTooltip:Hide()
end

local function RowEnter(row)
    row.hover:Show()
end

local function RowLeave(row)
    if not row.name:IsMouseOver() then row.hover:Hide() end
end

local function QuestMouseUp(row, button)
    if button == "RightButton" then
        OpenQuestMenu(row)
    elseif row.entry.loggedID then
        View.QuestPanel.Show(row.entry.loggedID, row)
    end
end

local function NameClicked(hit, button)
    QuestMouseUp(hit:GetParent(), button)
end

local function WaypointClicked(button, mouse)
    local quest = button:GetParent().quest
    if mouse ~= "RightButton" then return Quests.Waypoint(quest) end
    local name, map, x, y, note, why = Quests.Spot(quest)
    if map then
        Parts.SharePlace(button, TEXT_SHARE_WAYPOINT, name, map, x, y, note)
    elseif why then
        ns.Print(why)
    end
end

local function ChainClicked(button)
    if button:GetParent().entry.turnin then return end
    OpenChain(button, button:GetParent().quest)
end

local function PaintIcon(button, color)
    button.icon:SetVertexColor(color.r, color.g, color.b)
    button.label:SetTextColor(color.r, color.g, color.b)
end

local function PaintChain(button)
    PaintIcon(button, button.chained and T.accentSoft or T.muted)
end

local function ChainLeave(button)
    PaintChain(button)
    GameTooltip:Hide()
end

local function PaintParty(button)
    PaintIcon(button, button.count > 0 and T.accentSoft or T.muted)
end

local function MemberLine(unit)
    local _, class = UnitClass(unit)
    local color = class and not issecretvalue(class) and C_ClassColor.GetClassColor(class) or HAVE_RGB
    local role = UnitGroupRolesAssigned(unit)
    role = not issecretvalue(role) and ROLES[J.Team.RoleCode(role)] or ""
    GameTooltip:AddDoubleLine(UnitName(unit) or TEXT_UNKNOWN, role, color.r, color.g, color.b,
        T.muted.r, T.muted.g, T.muted.b)
end

local function MembersOnIt(entry)
    GameTooltip:SetText(TEXT_IN_GROUP, 1, 1, 1)
    for i = 1, GetNumSubgroupMembers() do
        local unit = "party" .. i
        if Quests.UnitOnQuest(unit, entry.quest, entry.loggedID) then MemberLine(unit) end
    end
    if entry.inLog or not J.Sharing.On() then return end
    GameTooltip:AddLine(TEXT_BLANK)
    GameTooltip:AddLine(TEXT_ASK_SHARE, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b, true)
end

local function PartyEnter(button)
    PaintIcon(button, T.fg)
    local entry = button:GetParent().entry
    if not Tip(button, "ANCHOR_TOP") then return end
    if button.count == 0 then
        GameTooltip:SetText(TEXT_NO_ONE, 1, 1, 1)
    else
        MembersOnIt(entry)
    end
    GameTooltip:Show()
end

local function PartyClicked(button)
    local entry = button:GetParent().entry
    if button.count > 0 and not entry.inLog then J.Sharing.Ask(entry) end
end

local function PartyLeave(button)
    PaintParty(button)
    GameTooltip:Hide()
end

local function NewCountButton(row, onClick, icon, margin, width, cells)
    local button = IconButton(row, onClick, icon, margin)
    button:SetWidth(width)
    button.label = Parts.Cells(button, SMALL_SIZE, T.accentSoft, cells)
    button.label[1]:SetPoint("RIGHT", button.icon, "LEFT", -CELL_GAP, 0)
    return button
end

local function NewMark(row)
    row.mark = row:CreateTexture(nil, "ARTWORK")
    row.mark:SetSize(MARK, MARK)
    row.markHit = CreateFrame("Frame", nil, row)
    row.markHit:SetSize(MARK + MARK_HIT_PAD, MARK + MARK_HIT_PAD)
    row.markHit:SetPoint("CENTER", row.mark)
    row.markHit:EnableMouse(true)
    row.markHit:SetScript("OnEnter", MarkEnter)
    row.markHit:SetScript("OnLeave", QuestLeave)
    row.markHit:SetScript("OnMouseUp", NameClicked)
end

local function NewText(row)
    row.title = ns.Font(row, TITLE_SIZE, nil, T.fg)
    row.title:SetPoint("TOPLEFT", TITLE_LEFT, -QUEST_TOP)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    row.where = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.where:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -QUEST_LINE_GAP)
    row.where:SetJustifyH("LEFT")
    row.where:SetWordWrap(true)
    row.name = CreateFrame("Button", nil, row)
    row.name:SetPoint("TOPLEFT", row.title, "TOPLEFT", 0, NAME_LIFT)
    row.name:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.name:SetScript("OnEnter", QuestEnter)
    row.name:SetScript("OnLeave", QuestLeave)
    row.name:SetScript("OnClick", NameClicked)
end

local function SetHandIn(chain, entry)
    local takes, held = entry.turnin.takes, entry.held
    chain.icon:SetTexture(BAG)
    chain.chained = held > 0
    local oneItem = held == 0 and #takes == TAKE_STRIDE
    chain.label:SetText(oneItem and TEXT_FRACTION:format(GetItemCount(takes[1]), takes[2]) or held)
    chain.tip = held > 0 and TEXT_BAG_ENOUGH:format(held, held == 1 and TEXT_TIME or TEXT_TIMES) or TEXT_BAG_SHORT
end

local function SetChain(chain, entry)
    chain.icon:SetTexture(CHAIN)
    chain.chained = entry.steps ~= nil
    chain.label:SetText(chain.chained and TEXT_FRACTION:format(entry.step, entry.steps) or TEXT_ONE_OF_ONE)
    chain.tip = chain.chained and TEXT_CHAIN_STEP:format(entry.step, entry.steps) or TEXT_ALONE
end

local function SetSlots(row, entry)
    local chain = row.chain
    if entry.turnin then SetHandIn(chain, entry) else SetChain(chain, entry) end
    chain:SetShown(entry.turnin ~= nil or chain.chained)
    PaintChain(chain)
    row.party.count = entry.party
    row.party.label:SetText(entry.party)
    row.party:SetShown(IsInGroup())
    PaintParty(row.party)
end

local function SetTitle(row, entry, width, compact, tight)
    local left = TITLE_LEFT
    row.title:SetWidth(width)
    row.forever = entry.quest ~= nil and IsForever("quests", entry.quest[QUEST.ID])
    row.title:SetText(row.forever and entry.name .. ForeverInline(SMALL_SIZE, CARD_DROP) or entry.name)
    row.where:SetWidth(compact and row:GetWidth() - left or width)
    row.where:SetText(Plain(entry.where))
    row.where:SetShown(not tight)
    row.name:SetSize(math.max(1, math.min(math.ceil(row.title:GetStringWidth()), width)),
        math.ceil(row.title:GetStringHeight()) + NAME_PAD)
end

local function PlaceIcons(row, compact)
    local line = -(QUEST_TOP + math.ceil(row.title:GetStringHeight()) / 2)
    row.mark:ClearAllPoints()
    row.chain:ClearAllPoints()
    row.waypoint:ClearAllPoints()
    row.party:ClearAllPoints()
    local anchor, y = "RIGHT", 0
    if compact then anchor, y = "TOPRIGHT", line end
    row.party:SetPoint("RIGHT", row, anchor, -PARTY_RIGHT, y)
    row.waypoint:SetPoint("CENTER", row, "TOPLEFT", ROW_LEFT + WAYPOINT_SLOT / 2, line)
    row.mark:SetPoint("CENTER", row, "TOPLEFT", MARK_LEFT + MARK / 2, line)
    row.chain:SetPoint("RIGHT", row, anchor, -CHAIN_RIGHT, y)
end

Kinds.quest = {
    New = function(view)
        local row = CreateFrame("Frame", nil, view)
        Parts.RowBands(row, ROW_LEFT)
        row.waypoint = IconButton(row, WaypointClicked, PIN, PIN_MARGIN)
        row.waypoint.tip = TEXT_WAYPOINT
        row.waypoint.hint = TEXT_WAYPOINT_HINT
        row.waypoint:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.chain = NewCountButton(row, ChainClicked, CHAIN, CHAIN_MARGIN, CHAIN_SLOT, CHAIN_CELLS)
        row.chain:SetScript("OnLeave", ChainLeave)
        row.party = NewCountButton(row, PartyClicked, PEOPLE, nil, PARTY_SLOT, PARTY_CELLS)
        row.party:SetScript("OnEnter", PartyEnter)
        row.party:SetScript("OnLeave", PartyLeave)
        NewMark(row)
        row:EnableMouse(true)
        row:SetScript("OnEnter", RowEnter)
        row:SetScript("OnLeave", RowLeave)
        row:SetScript("OnMouseUp", QuestMouseUp)
        NewText(row)
        return row
    end,
    Set = function(row, entry, index)
        row.entry, row.quest = entry, entry.quest
        row.stripe:SetShown(index % STRIPE_EVERY == 0)
        row.hover:Hide()
        row.waypoint:SetShown(entry.canWaypoint)
        SetSlots(row, entry)
        PaintMark(row.mark, entry)
        local view = row:GetParent()
        local tight = view.tight
        local compact = view.compact and not tight
        local width = row:GetWidth() - TITLE_LEFT - RIGHT_W - GAP * 2
        SetTitle(row, entry, width, compact, tight)
        local height = QUEST_TOP + math.ceil(row.title:GetStringHeight()) + QUEST_BOTTOM
        if not tight then height = height + QUEST_LINE_GAP + math.ceil(row.where:GetStringHeight()) end
        PlaceIcons(row, compact)
        return height
    end,
}

function View.QuestRowWidth(titleWidth)
    return TITLE_LEFT + titleWidth + RIGHT_W + GAP * 2
end

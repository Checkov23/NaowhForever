-- QuestRow.lua: a quest: its level or tick, its name, where it stands, a waypoint pin and its chain's tree line.
local ns = _G.NaowhForever

local T = ns.THEME
local Completo = ns.Completo
local Parts = ns.Shared.Parts
local Style = Completo.Style
local Q = Completo.Quests
local V = Completo.View

local CHAIN_ICON = 14
local CHAIN_GAP = 4
local STEP_INDENT = 26
local TREE_X = Style.INDENT + 7
local TREE_UP, TREE_GAP, TREE_ALPHA, ELBOW = 6, 4, 0.5, 8
local TITLE_GAP = 4
local ICON_DROP = Style.ROW_ICON_DROP
local STATE = {
    done = { ns.L("Done"), "muted" }, log = { ns.L("In your log"), "log" }, low = { ns.L("Needs level %d"), "red" },
    later = { ns.L("Needs an earlier quest"), "muted" }, open = { ns.L("Not done"), "fg" },
    held = { ns.L("Not offered yet"), "muted" },
}
local TEXT_REPEATABLE = ns.L("Repeatable")
local TEXT_PIN_HINT = ns.L("To who gives the quest.")
local TEXT_WAYPOINT = ns.L("Waypoint")
local TEXT_LEVEL = ns.L("Level")
local TEXT_REQUIRES = ns.L("Requires level")
local TEXT_STATUS = ns.L("Status")
local TEXT_CHAIN = ns.L("Chain")
local TEXT_CHAIN_STEPS = ns.L("%d steps, %s")
local TEXT_EVERY_STEP = ns.L("every step done")
local TEXT_ON_STEP = ns.L("on step %d")
local TEXT_PIN_TIP = ns.L("Pin: waypoint    ")
local TEXT_WOWHEAD = ns.L("Right-click: Wowhead link")
local TEXT_CHAIN_DONE = ns.L("Quest chain of %d, all done")
local TEXT_CHAIN_AT = ns.L("Quest chain of %d, on step %d")
local TEXT_STEP_OF = ns.L("Step %d of %d in %s")

local function StateText(id, state)
    if state == "open" and Q.Repeatable(id) then return TEXT_REPEATABLE, Style.REPEAT_RGB end
    local entry = STATE[state]
    local text = entry[1]
    if state == "low" then text = text:format(Q.RequiredLevel(id)) end
    local color = entry[2] == "log" and Style.LOG_RGB or entry[2] == "red" and Style.RED_RGB or T[entry[2]]
    return text, color
end

local function PinClicked(button)
    Q.Waypoint(button:GetParent().quest)
end

local function ChainLine(id)
    local chain = Q.Chain(id)
    if not chain then return nil end
    local at, steps = Q.ChainAt(chain)
    local where = at > steps and TEXT_EVERY_STEP or TEXT_ON_STEP:format(at)
    return TEXT_CHAIN_STEPS:format(steps, where)
end

local function QuestEnter(row)
    row.hover:Show()
    if not Parts.Tip(row, "ANCHOR_RIGHT") then return end
    local id, m = row.quest, T.muted
    GameTooltip:SetText(Q.Name(id), 1, 1, 1)
    GameTooltip:AddDoubleLine(TEXT_LEVEL, Q.Level(id), m.r, m.g, m.b, 1, 1, 1)
    if Q.RequiredLevel(id) > 0 then
        GameTooltip:AddDoubleLine(TEXT_REQUIRES, Q.RequiredLevel(id), m.r, m.g, m.b, 1, 1, 1)
    end
    local text, color = StateText(id, Q.State(id))
    GameTooltip:AddDoubleLine(TEXT_STATUS, text, m.r, m.g, m.b, color.r, color.g, color.b)
    local chain = ChainLine(id)
    if chain then GameTooltip:AddDoubleLine(TEXT_CHAIN, chain, m.r, m.g, m.b, 1, 1, 1) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine((Q.Spot(id) and TEXT_PIN_TIP or "") .. TEXT_WOWHEAD, V.Soft())
    GameTooltip:Show()
end

local function QuestMouseUp(row, button)
    if button == "RightButton" then Parts.CopyWowhead("quest", row.quest, Q.Name(row.quest)) end
end

local function NewTree(row)
    local soft = T.accentSoft
    row.chain = row:CreateTexture(nil, "ARTWORK")
    row.chain:SetTexture(Style.CHAIN, nil, nil, "TRILINEAR")
    row.chain:SetSize(CHAIN_ICON, CHAIN_ICON)
    row.chain:SetPoint("TOPLEFT", Style.INDENT, -(Style.ROW_TOP + ICON_DROP))
    row.chain:SetVertexColor(soft.r, soft.g, soft.b)
    row.trunk = ns.Solid(row, "ARTWORK", soft, TREE_ALPHA)
    ns.Hairline(row.trunk, "v")
    row.branch = ns.Solid(row, "ARTWORK", soft, TREE_ALPHA)
    ns.Hairline(row.branch, "h")
    row.elbow = row:CreateTexture(nil, "ARTWORK")
    row.elbow:SetTexture(Style.ELBOW)
    row.elbow:SetSize(ELBOW, ELBOW)
    row.elbow:SetVertexColor(soft.r, soft.g, soft.b, TREE_ALPHA)
end

local function NewQuest(parent)
    local row = V.NewRow(parent)
    row.pin = Parts.IconButton(row, PinClicked, Style.PIN, 0, TEXT_WAYPOINT)
    row.pin.hint = TEXT_PIN_HINT
    row.pin:SetPoint("RIGHT", -Style.PIN_RIGHT, 0)
    NewTree(row)
    row.tick = V.Tick(row)
    row.level = ns.Font(row, Style.TEXT_SIZE)
    row.level:SetWidth(Style.LEVEL_W)
    row.level:SetJustifyH("LEFT")
    row.title = V.Line(row, Style.TITLE_SIZE, T.fg)
    row.where = V.Line(row, Style.SMALL_SIZE, T.muted)
    row.where:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -Style.LINE_GAP)
    row.status = ns.Font(row, Style.SMALL_SIZE, nil, T.fg)
    row.status:SetPoint("RIGHT", row.pin, "LEFT", -Style.STATUS_GAP, 0)
    row.status:SetJustifyH("RIGHT")
    row:SetScript("OnEnter", QuestEnter)
    row:SetScript("OnLeave", V.RowLeave)
    row:SetScript("OnMouseUp", QuestMouseUp)
    return row
end

local function SetTree(row, first, last, middle)
    row.trunk:ClearAllPoints()
    row.branch:ClearAllPoints()
    row.elbow:ClearAllPoints()
    local up = first and TREE_UP or 0
    local corner = last and ELBOW or 0
    row.trunk:SetPoint("TOPLEFT", TREE_X, up)
    if last then
        row.trunk:SetHeight(up + middle - ELBOW + 1)
    else
        row.trunk:SetPoint("BOTTOMLEFT", TREE_X, 0)
    end
    row.elbow:SetPoint("TOPLEFT", TREE_X, -(middle - ELBOW + 1))
    row.elbow:SetShown(last)
    row.branch:SetPoint("TOPLEFT", TREE_X + corner, -middle)
    row.branch:SetWidth(Style.INDENT + STEP_INDENT - TREE_GAP - TREE_X - corner)
end

local function LeftOf(part)
    if part == "head" then return Style.INDENT + CHAIN_ICON + CHAIN_GAP end
    if part == "step" then return Style.INDENT + STEP_INDENT end
    return Style.INDENT
end

local function Place(row, left)
    local top = -(Style.ROW_TOP + ICON_DROP)
    row.tick:ClearAllPoints()
    row.tick:SetPoint("TOPLEFT", left, top)
    row.level:ClearAllPoints()
    row.level:SetPoint("TOPLEFT", left, top)
    row.title:ClearAllPoints()
    row.title:SetPoint("TOPLEFT", left + Style.LEVEL_W + TITLE_GAP, -Style.ROW_TOP)
end

local function SubLine(id, part, shown)
    local sub = ""
    local chain = Q.Chain(id)
    if part == "head" then
        local at, steps = Q.ChainAt(chain)
        sub = at > steps and TEXT_CHAIN_DONE:format(steps) or TEXT_CHAIN_AT:format(steps, at)
    elseif part ~= "step" and chain then
        local at, steps = Q.ChainStep(id)
        sub = TEXT_STEP_OF:format(at, steps, chain.name)
    end
    local home = Q.Zone(id)
    if shown and home and home ~= shown then sub = V.Join(sub, home.name) end
    return sub
end

local function SetLevel(row, id, finished)
    row.tick:SetShown(finished)
    row.level:SetShown(not finished)
    local level = Q.Level(id)
    row.level:SetText(level > 0 and level or "")
    V.Paint(row.level, GetQuestDifficultyColor(level > 0 and level or UnitLevel("player")))
end

local function SetQuest(row, id, part, first, last, stripe)
    row.quest = id
    V.Reset(row, stripe)
    local step = part == "step"
    local left = LeftOf(part)
    row.chain:SetShown(part == "head")
    Place(row, left)
    local state = Q.State(id)
    local finished = state == "done"
    SetLevel(row, id, finished)
    row.pin:SetShown(Q.Spot(id) ~= nil and not finished)
    local text, color = StateText(id, state)
    row.status:SetText(text)
    V.Paint(row.status, color)
    local textW = row:GetWidth() - left - Style.LEVEL_W - TITLE_GAP - Style.PIN_RIGHT - Style.STATUS_W
        - Style.STATUS_GAP
    row.title:SetWidth(textW)
    row.title:SetText(Q.Name(id))
    V.Paint(row.title, finished and T.muted or T.fg)
    row.where:SetWidth(textW)
    local titleH = math.ceil(row.title:GetStringHeight())
    local sub = SubLine(id, part, row:GetParent():ShownZone())
    local h = Style.ROW_TOP + titleH + Style.ROW_BOTTOM + V.SubHeight(row, sub)
    row.trunk:SetShown(step)
    row.branch:SetShown(step)
    if step then
        SetTree(row, first, last, Style.ROW_TOP + math.floor(titleH / 2))
    else
        row.elbow:Hide()
    end
    return h
end

V.Kinds.quest = { New = NewQuest, Set = SetQuest }

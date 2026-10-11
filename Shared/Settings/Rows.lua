-- Rows.lua: the row kinds of a settings page (Settings.kinds): a setting, a card's head and foot, a group title, an info line and a window card.
local ns = _G.NaowhForever
local T = ns.THEME
local Shared = ns.Shared
local Settings, View, Parts = Shared.Settings, Shared.View, Shared.Parts
local Control = Settings.Control
local SS = Settings.Style

local PAD, CONTROL_GAP, CONTROL_LEVEL, RULE_ALPHA = SS.PAD, SS.CONTROL_GAP, SS.CONTROL_LEVEL, SS.RULE_ALPHA
local SMALL_SIZE = SS.SMALL_SIZE
local ROW_H = 36
local HEAD_H, GROUP_H = SS.HEAD_H, SS.GROUP_H
local FOOT_H = 30
local DOT_X = 5
local DOT_SIZE, DOT_HIT = 6, 12
local LABEL_SIZE, NAME_SIZE = 13, 14
local HELP_HIT = 4
local TOGGLE_GAP = 10
local SUMMARY_GAP = TOGGLE_GAP + 2
local CHEVRON_SIZE = 12
local GROUP_RISE = 7
local OPEN_TURN = SS.OPEN_TURN
local ICON_SIZE, ICON_LEVEL = 22, 5
local ICON_REST, ICON_LIT, ICON_OFF = 0.4, 0.8, 0.12
local INFO_TOP, INFO_GAP, INFO_BOTTOM = 10, 4, 10
local TIP_TITLE = 1
local TEXT_CHANGED = ns.L("Changed")
local TEXT_DEFAULT_IS = ns.L("The default is %s. Click to put it back.")
local TEXT_DEFAULT_ONLY = ns.L("The default is %s.")
local TEXT_PUT_BACK_DEFAULT = ns.L("Click to put back the default.")
local TEXT_ONE_CHANGED = ns.L("1 setting changed from its default")
local TEXT_MANY_CHANGED = ns.L("%d settings changed from their defaults")
local TEXT_RESET = ns.L("Reset %s")
local FOOT_GAP = 8
local TEXT_OFF = ns.L("Off")
local NOTE_GAP = ", "

local NO_ICONS = {}

local groupLabels = {}
local changedText = {}

local function HelpEnter(hit)
    local text = hit.help
    if text and text ~= "" then
        ns.UI.ShowWidgetTooltip(hit, text, { anchor = "cursor", justify = "LEFT" })
    end
end

local function HelpLeave()
    ns.UI.HideWidgetTooltip()
end

local function HelpHit(parent, region)
    local hit = CreateFrame("Frame", nil, parent)
    hit:SetPoint("TOPLEFT", region, "TOPLEFT", -HELP_HIT, HELP_HIT)
    hit:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", HELP_HIT, -HELP_HIT)
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", HelpEnter)
    hit:SetScript("OnLeave", HelpLeave)
    return hit
end

local function Marked(row, text)
    local filter = row:GetParent().filter
    return filter and ns.UI.Search.Mark(filter, text) or text
end

local function Rule(frame, alpha)
    local rule = ns.Solid(frame, "ARTWORK", T.line, alpha or RULE_ALPHA)
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    ns.Hairline(rule, "h")
    return rule
end

local function RowGet(row)
    return row.setting.get()
end

local function RowSet(row, ...)
    Control.Store(row.setting, ...)
end

local function DotEnter(dot)
    local setting = dot:GetParent().setting
    dot.mark:SetVertexColor(T.accent.r, T.accent.g, T.accent.b, 1)
    GameTooltip:SetOwner(dot, "ANCHOR_RIGHT")
    GameTooltip:SetText(ns.L(TEXT_CHANGED), TIP_TITLE, TIP_TITLE, TIP_TITLE)
    local default = Control.Shown(setting, setting.store.Default(setting.key))
    local defaultIs = dot.noReset and TEXT_DEFAULT_ONLY or TEXT_DEFAULT_IS
    GameTooltip:AddLine(default and ns.L(defaultIs, default) or ns.L(TEXT_PUT_BACK_DEFAULT),
        T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function DotLeave(dot)
    dot.mark:SetVertexColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b, 1)
    GameTooltip:Hide()
end

local function DotClicked(dot)
    local row = dot:GetParent()
    DotLeave(dot)
    Settings.ResetRow(row.setting)
    row:GetParent():QueueSettingsRedraw()
end

local function Dot(row)
    local dot = CreateFrame("Button", nil, row)
    dot:SetSize(DOT_HIT, DOT_HIT)
    dot:SetPoint("CENTER", row, "LEFT", DOT_X + DOT_SIZE / 2, 0)
    dot.mark = dot:CreateTexture(nil, "ARTWORK")
    dot.mark:SetTexture(SS.ROUND, nil, nil, "TRILINEAR")
    dot.mark:SetVertexColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b, 1)
    dot.mark:SetSize(DOT_SIZE, DOT_SIZE)
    dot.mark:SetPoint("CENTER")
    dot:SetScript("OnClick", DotClicked)
    dot:SetScript("OnEnter", DotEnter)
    dot:SetScript("OnLeave", DotLeave)
    return dot
end

local function Split(row)
    local split = ns.Solid(row, "ARTWORK", T.line, RULE_ALPHA)
    split:SetPoint("TOPRIGHT")
    split:SetPoint("BOTTOMRIGHT")
    ns.Hairline(split, "v")
    return split
end

local function IconEnter(icon)
    icon:SetAlpha(ICON_LIT)
    local tip = icon.spec and icon.spec.tip
    if tip then ns.UI.ShowWidgetTooltip(icon, tip) end
end

local function IconLeave(icon)
    icon:SetAlpha(ICON_REST)
    ns.UI.HideWidgetTooltip()
end

local function IconClicked(icon)
    local spec = icon.spec
    if not spec then return end
    if spec.cogFor then
        Settings.ToggleCog(icon, icon:GetParent().setting)
    elseif spec.open then
        spec.open(icon)
    end
end

local function NewIcon(row)
    local icon = CreateFrame("Button", nil, row)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetFrameLevel(row:GetFrameLevel() + ICON_LEVEL)
    icon.tex = icon:CreateTexture(nil, "OVERLAY")
    icon.tex:SetAllPoints()
    icon:SetScript("OnEnter", IconEnter)
    icon:SetScript("OnLeave", IconLeave)
    icon:SetScript("OnClick", IconClicked)
    return icon
end

local function SetIcons(row, setting, left, off)
    local icons = setting.icons or NO_ICONS
    for i = 1, #icons do
        local spec = icons[i]
        local icon = row.icons[i]
        if not icon then
            icon = NewIcon(row)
            row.icons[i] = icon
        end
        local on = not off and (spec.enabled == nil or spec.enabled())
        icon.spec = spec
        icon.tex:SetTexture(spec.texture or ns.UI.COGS_ICON)
        local tint = spec.cogFor and Settings.CogChanged(setting.card, setting.label) and T.accentSoft or T.fg
        icon.tex:SetVertexColor(tint.r, tint.g, tint.b, 1)
        icon:ClearAllPoints()
        icon:SetPoint("RIGHT", left, "LEFT", -CONTROL_GAP, 0)
        icon:EnableMouse(on)
        icon:SetAlpha(on and ICON_REST or ICON_OFF)
        icon:Show()
        if spec.cogFor then Settings.CogAnchored(icon, setting) end
        left = icon
    end
    for i = #icons + 1, #row.icons do row.icons[i]:Hide() end
    return left
end

local function NewSetting(view)
    local row = CreateFrame("Frame", nil, view)
    row:SetHeight(ROW_H)
    row.Get = function() return RowGet(row) end
    row.Set = function(...) RowSet(row, ...) end
    row.controls = {}
    row.rule = Rule(row)
    row.split = Split(row)
    row.dot = Dot(row)
    row.label = ns.Font(row, LABEL_SIZE, nil, T.fg)
    row.label:SetPoint("LEFT", PAD, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row.why = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.why:SetJustifyH("RIGHT")
    row.why:SetWordWrap(false)
    row.hit = HelpHit(row, row.label)
    row.dot:SetFrameLevel(row.hit:GetFrameLevel() + 1)
    row.icons = {}
    return row
end

local function ShowControl(row, kind)
    for k, control in pairs(row.controls) do control:SetShown(k == kind) end
    local control = Control.For(row, kind)
    control:Show()
    if control._valBox then control._valBox:Show() end
    for k, other in pairs(row.controls) do
        if other._valBox and k ~= kind then other._valBox:Hide() end
    end
    return control
end

local function PlaceLabel(row, control, why)
    row.why:ClearAllPoints()
    row.why:SetPoint("RIGHT", control, "LEFT", -CONTROL_GAP, 0)
    row.why:SetText(why or "")
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", PAD, 0)
    row.label:SetPoint("RIGHT", why and row.why or control, "LEFT", -CONTROL_GAP, 0)
end

local function SetSetting(row, setting, split)
    row.setting = setting
    local control = ShowControl(row, setting.kind)
    Control.Bind(control, setting)
    row.label:SetText(Marked(row, ns.L(setting.label)))
    row.hit.help = setting.help
    row.dot:SetShown(Settings.Changed(setting))
    row.split:SetShown(split)
    local off, why = Settings.Off(setting)
    Control.Dim(row, control, off)
    PlaceLabel(row, SetIcons(row, setting, control, off), off and ns.L(why) or (setting.note and setting.note(setting)))
    return ROW_H
end

local function HeadClicked(head)
    local card = head.card
    if head.held or not Settings.Openable(card) then return end
    Settings.SetOpen(card, not Settings.IsOpen(card))
    head:GetParent():QueueSettingsRedraw()
end

local function HeadSwitchSet(head, v)
    local card = head.card
    card.switchSet(v)
    if v then Settings.SetOpen(card, true) end
    head:GetParent():QueueSettingsRedraw()
end

local function HeadEnter(head)
    head.chevron:SetVertexColor(T.fg.r, T.fg.g, T.fg.b, 1)
end

local function HeadLeave(head)
    head.chevron:SetVertexColor(T.muted.r, T.muted.g, T.muted.b, 1)
end

local function HeadSwitch(head)
    return ns.UI.BuildToggleControl(head, head:GetFrameLevel() + CONTROL_LEVEL,
        function() local card = head.card; return card and card.switchGet and card.switchGet() end,
        function(v) HeadSwitchSet(head, v) end)
end

local function NewHead(view)
    local head = CreateFrame("Button", nil, view)
    head:SetHeight(HEAD_H)
    ns.Solid(head, "BACKGROUND", T.panel, 1):SetAllPoints()
    head.rule = Rule(head, 1)
    head.chevron = head:CreateTexture(nil, "ARTWORK")
    head.chevron:SetTexture(ns.UI.CHEVRON)
    head.chevron:SetSize(CHEVRON_SIZE, CHEVRON_SIZE)
    head.chevron:SetPoint("LEFT", PAD, 0)
    head.chevron:SetVertexColor(T.muted.r, T.muted.g, T.muted.b, 1)
    head.name = ns.Font(head, NAME_SIZE, nil, ns.classicSkin and T.accent or T.fg, true)
    if ns.classicSkin then
        ns.Border(head, SS.BORDER_RGB)
        Parts.ClassicBox(head)
    end
    head.name:SetPoint("LEFT", head.chevron, "RIGHT", CONTROL_GAP, 0)
    head.nameHit = HelpHit(head, head.name)
    head.switch = HeadSwitch(head)
    head.dot = Dot(head)
    head.dot.noReset = true
    head.dot:SetScript("OnClick", nil)
    head.summary = ns.Font(head, SMALL_SIZE, nil, T.muted)
    head.summary:SetJustifyH("LEFT")
    head.summary:SetWordWrap(false)
    head:SetScript("OnClick", HeadClicked)
    head:SetScript("OnEnter", HeadEnter)
    head:SetScript("OnLeave", HeadLeave)
    return head
end

local function PlaceSwitch(head, card)
    if not card.switchGet then
        head.switch:Hide()
        return head.name
    end
    head.switch:Show()
    head.switch._refreshValue()
    head.switch:ClearAllPoints()
    head.switch:SetPoint("LEFT", head.name, "RIGHT", TOGGLE_GAP, 0)
    return head.switch
end

local function Summary(card)
    local off = card.switchGet and not card.switchGet()
    local summary = card.summary
    if type(summary) == "function" then summary = summary(card.store) end
    if off then summary = TEXT_OFF end
    summary = summary and ns.L(summary)
    local note = card.note and card.note(card)
    if note and summary then return summary .. NOTE_GAP .. note end
    return note or summary
end

local function SetHead(head, card, isOpen, held)
    head.card, head.held = card, held
    head.setting = card.switchSetting
    head.dot:SetShown(head.setting ~= nil and Settings.Changed(head.setting))
    head.name:SetText(Marked(head, ns.L(card.name)))
    head.nameHit.help = card.help
    head.chevron:SetRotation(isOpen and OPEN_TURN or 0)
    head.chevron:SetShown(Settings.Openable(card) and not held)
    head.rule:SetShown(isOpen)
    local anchor = PlaceSwitch(head, card)
    head.summary:ClearAllPoints()
    head.summary:SetPoint("LEFT", anchor, "RIGHT", SUMMARY_GAP, 0)
    head.summary:SetPoint("RIGHT", -PAD, 0)
    head.summary:SetText(Summary(card) or "")
    return HEAD_H
end

local function NewGroup(view)
    local row = CreateFrame("Frame", nil, view)
    row.text = ns.Font(row, SMALL_SIZE, nil, T.accentSoft)
    row.text:SetPoint("BOTTOMLEFT", PAD, GROUP_RISE)
    Rule(row)
    return row
end

local function SetGroup(row, title)
    local label = groupLabels[title]
    if not label then
        label = ns.Upper(ns.L(title))
        groupLabels[title] = label
    end
    row.text:SetText(label)
    return GROUP_H
end

local function ResetClicked(link)
    local foot = link:GetParent()
    Settings.Reset(foot.card)
    foot:GetParent():QueueSettingsRedraw()
end

local function NewFoot(view)
    local foot = CreateFrame("Frame", nil, view)
    foot.text = ns.Font(foot, SMALL_SIZE, nil, T.muted)
    foot.text:SetPoint("LEFT", PAD, 0)
    foot.reset = Parts.Link(foot, ResetClicked, true)
    foot.reset:SetPoint("RIGHT", -PAD, 0)
    foot.text:SetPoint("RIGHT", foot.reset, "LEFT", -FOOT_GAP, 0)
    foot.text:SetJustifyH("LEFT")
    foot.text:SetWordWrap(false)
    return foot
end

local function ChangedText(changed)
    local text = changedText[changed]
    if text then return text end
    text = changed == 1 and ns.L(TEXT_ONE_CHANGED) or ns.L(TEXT_MANY_CHANGED, changed)
    changedText[changed] = text
    return text
end

local function SetFoot(foot, card, changed)
    foot.card = card
    foot.text:SetText(ChangedText(changed))
    Parts.SetLink(foot.reset, ns.L(TEXT_RESET, ns.L(card.name)))
    return FOOT_H
end

local function Value(value)
    if type(value) == "function" then return value() end
    return value
end

local function NewInfoLine(view)
    local row = CreateFrame("Frame", nil, view)
    row.rule = Rule(row)
    row.title = ns.Font(row, LABEL_SIZE, nil, T.fg)
    row.title:SetPoint("TOPLEFT", PAD, -INFO_TOP)
    row.where = ns.Font(row, SMALL_SIZE, nil, T.muted)
    row.where:SetPoint("BOTTOMLEFT", row.title, "BOTTOMRIGHT", CONTROL_GAP, 0)
    row.text = ns.Font(row, LABEL_SIZE - 1, nil, T.muted)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)
    return row
end

local function SetInfoLine(row, line)
    local titled = line.title ~= nil
    row.title:SetText(ns.L(line.title) or "")
    row.where:SetText(line.where or "")
    row.text:ClearAllPoints()
    if titled then
        row.text:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -INFO_GAP)
    else
        row.text:SetPoint("TOPLEFT", PAD, -INFO_TOP)
    end
    row.text:SetWidth(row:GetWidth() - PAD * 2)
    row.text:SetText(ns.L(line.text) or "")
    local textH = line.text and math.ceil(row.text:GetStringHeight()) or 0
    local titleH = titled and (LABEL_SIZE + (line.text and INFO_GAP or 0)) or 0
    return INFO_TOP + titleH + textH + INFO_BOTTOM
end

local function NewWindowCard(view)
    return Parts.SettingsCardFrame(view)
end

local function SetWindowCard(card, spec)
    return Parts.PaintSettingsCard(card, spec.text, spec.open, Value(spec.headline), Value(spec.detail))
end

local kinds = View.NewKinds()
kinds.setting = { New = NewSetting, Set = SetSetting }
kinds.cardHead = { New = NewHead, Set = SetHead }
kinds.group = { New = NewGroup, Set = SetGroup }
kinds.cardFoot = { New = NewFoot, Set = SetFoot }
kinds.window = { New = NewWindowCard, Set = SetWindowCard }
kinds.infoLine = { New = NewInfoLine, Set = SetInfoLine }
Settings.kinds = kinds

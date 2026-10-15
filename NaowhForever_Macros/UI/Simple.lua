-- Simple.lua: the Forge's Simple view: a few plain questions that write the macro, what one press does, and the text it writes.
local ns = _G.NaowhForever
local T = ns.THEME
local UI = ns.UI

local M = ns.Macros
local S = M.Settings
local St = M.Style
local Text = M.Text
local P = M.Parts
local F = M.Forge
local Parts = ns.Shared.Parts

local SMALL_SIZE, NOTE_SIZE, TEXT_SIZE = St.SMALL_SIZE, St.NOTE_SIZE, St.TEXT_SIZE
local SCROLLBAR_ROOM, TAB_H, BLACK, CODE_FONT = St.SCROLLBAR_ROOM, St.TAB_H, St.BORDER_RGB, St.CODE_FONT
local LABEL_W, SPELL_W, CHOICE_W, ROW_GAP, SECTION_GAP = 200, 260, 380, 10, 16
local BOX_PAD, BOX_HEAD, BOX_FILL, CODE_SIZE = 10, 18, 0.08, 12
local ADVANCED_W, TOGGLE_LEVEL = 140, 2

local TEXT_SPELL = ns.L("Cast")
local TEXT_AIM = ns.L("Aim at")
local TEXT_KIND = ns.L("Only on")
local TEXT_FALL = ns.L("If there is no %s")
local TEXT_SELF = ns.L("Hold a key to cast on yourself")
local TEXT_STOP = ns.L("Stop my cast first")
local TEXT_ATTACK = ns.L("Start attacking too")
local TEXT_TIP = ns.L("Show it on the button")
local TEXT_PRESS = ns.L("When you press it")
local TEXT_WRITES = ns.L("The macro it writes")
local TEXT_TOO_BIG = ns.L("This macro does more than Simple can show. Edit it in Advanced.")
local TEXT_ADVANCED = ns.L("Edit in Advanced")
local TEXT_TYPE = ns.L("Type the spell or item it casts.")
local TEXT_CASTS, TEXT_USES = ns.L("Casts %s on %s."), ns.L("Uses %s on %s.")
local TEXT_NO_ONE = { friend = ns.L("No living friend there"), enemy = ns.L("No living enemy there") }
local TEXT_THEN = { target = ns.L("%s: on your target instead."), player = ns.L("%s: on yourself instead."),
    none = ns.L("%s: nothing happens.") }
local TEXT_HOLD = ns.L("Hold %s: on yourself.")
local TEXT_STOPS, TEXT_ATTACKS = ns.L("Stops your cast first."), ns.L("Starts attacking too.")
local ON = { mouseover = ns.L("your mouseover"), target = ns.L("your target"), focus = ns.L("your focus"),
    player = ns.L("yourself") }
local NO = { mouseover = ns.L("mouseover"), target = ns.L("target"), focus = ns.L("focus") }

local AIMS = { { key = "mouseover", label = "Mouseover" }, { key = "target", label = "Target" },
    { key = "focus", label = "Focus" }, { key = "player", label = "Myself" } }
local KINDS = { { key = "friend", label = "Friends" }, { key = "enemy", label = "Enemies" } }
local SELF = { { key = "none", label = "None" }, { key = "shift", label = "Shift" }, { key = "ctrl", label = "Ctrl" },
    { key = "alt", label = "Alt" } }
local FALLS = {
    mouseover = { { key = "target", label = "My Target" }, { key = "player", label = "Myself" },
        { key = "none", label = "Nothing" } },
    target = { { key = "player", label = "Myself" }, { key = "none", label = "Nothing" } },
    player = { { key = "none", label = "Nothing" } },
}
FALLS.focus = FALLS.mouseover
local KEY_NAMES = { shift = "Shift", ctrl = "Ctrl", alt = "Alt" }
local NO_SELF = { SELF[1] }
local TEST = { friend = "help,nodead", enemy = "harm,nodead" }
local BOOLS = { true, false }
local SPELL_COMMANDS = { ["/cast"] = true, ["/use"] = true }

local view
local kind = "friend"
local readBody, readForm
local try = {}

local function Write(f)
    local lines = {}
    if f.tip then lines[#lines + 1] = "#showtooltip" end
    if f.stop then lines[#lines + 1] = "/stopcasting" end
    if f.attack then lines[#lines + 1] = "/startattack" end
    local test = TEST[f.kind]
    local c = f.self ~= "none" and ("[mod:" .. f.self .. ",@player]") or ""
    if f.aim == "player" then
        c = c .. "[@player]"
    elseif f.aim == "target" then
        if f.fall == "player" then
            c = c .. "[" .. test .. "][@player]"
        elseif c ~= "" then
            c = c .. "[]"
        end
    else
        c = c .. "[@" .. f.aim .. "," .. test .. "]"
        if f.fall == "target" then c = c .. "[" .. test .. "]" end
        if f.fall == "player" then c = c .. "[@player]" end
    end
    lines[#lines + 1] = f.cmd .. " " .. (c ~= "" and (c .. " ") or "") .. f.spell
    return strtrim(table.concat(lines, "\n"))
end

local function SpellLine(body)
    local cmd, spell
    for _, line in ipairs(Text.Lines(body)) do
        local word = line:match("^(/%a+)")
        if word and SPELL_COMMANDS[word:lower()] then
            if cmd then return end
            cmd, spell = word:lower(), strtrim(line:gsub("%b[]", ""):sub(#word + 1))
        end
    end
    return cmd, spell
end

local function Copy(f)
    return { tip = f.tip, stop = f.stop, attack = f.attack, kind = f.kind, aim = f.aim, fall = f.fall,
        self = f.self, cmd = f.cmd, spell = f.spell }
end

local function Matches(body)
    for _, aim in ipairs(AIMS) do
        try.aim = aim.key
        for _, fall in ipairs(FALLS[aim.key]) do
            try.fall = fall.key
            for _, key in ipairs(aim.key == "player" and NO_SELF or SELF) do
                try.self = key.key
                if Write(try) == body then return Copy(try) end
            end
        end
    end
end

local function Read(body)
    body = strtrim(body)
    if body == readBody then return readForm end
    readBody, readForm = body, nil
    local cmd, spell = SpellLine(body)
    if not cmd then return end
    try.cmd, try.spell = cmd, spell
    for _, k in ipairs({ kind, kind == "friend" and "enemy" or "friend" }) do
        try.kind = k
        for _, tip in ipairs(BOOLS) do
            try.tip = tip
            for _, stop in ipairs(BOOLS) do
                try.stop = stop
                for _, attack in ipairs(BOOLS) do
                    try.attack = attack
                    readForm = Matches(body)
                    if readForm then
                        kind = readForm.kind
                        return readForm
                    end
                end
            end
        end
    end
end

local function Checked(f)
    return f.aim ~= "player" and (f.aim ~= "target" or f.fall == "player")
end

local function Says(f)
    if f.spell == "" then return TEXT_TYPE end
    local said = {}
    if f.stop then said[#said + 1] = TEXT_STOPS end
    said[#said + 1] = (f.cmd == "/use" and TEXT_USES or TEXT_CASTS):format(ns.Color("accentSoft", f.spell), ON[f.aim])
    if Checked(f) then said[#said + 1] = TEXT_THEN[f.fall]:format(TEXT_NO_ONE[f.kind]) end
    if f.self ~= "none" then said[#said + 1] = TEXT_HOLD:format(ns.L(KEY_NAMES[f.self])) end
    if f.attack then said[#said + 1] = TEXT_ATTACKS end
    return table.concat(said, " ")
end

local function Pick(field, value)
    local f = readForm and Copy(readForm)
    if not f then return end
    local was = f[field]
    f[field] = value
    if field == "kind" then kind, readBody = value, nil end
    if field == "aim" then
        if value == "player" then f.fall, f.self = "none", "none" end
        if value == "target" and f.fall == "target" then f.fall = "none" end
        if FALLS[value] == FALLS.mouseover and FALLS[was] ~= FALLS.mouseover then f.fall = "target" end
    end
    local body = Write(f)
    if body == strtrim(F.draft.body) then return F.DrawSimple() end
    F.SetBody(body, true)
end

local function Label(parent, text)
    local fs = P.Text(parent, TEXT_SIZE)
    fs:SetJustifyH("LEFT")
    if text then fs:SetText(text) end
    return fs
end

local function ChoiceRow(field)
    local row = CreateFrame("Frame", nil, view.body)
    row:SetHeight(TAB_H)
    row.label = Label(row)
    row.label:SetPoint("LEFT")
    row.bar = Parts.Tabs(row, CHOICE_W, {}, function(key) Pick(field, key) end)
    row.bar:SetPoint("LEFT", LABEL_W, 0)
    row.field = field
    return row
end

local function ToggleRow(field, text)
    local row = CreateFrame("Frame", nil, view.body)
    row:SetHeight(TAB_H)
    Label(row, text):SetPoint("LEFT")
    local function Get() return readForm and readForm[field] end
    local function Set(on) Pick(field, on and true or false) end
    row.toggle = UI.BuildToggleControl(row, row:GetFrameLevel() + TOGGLE_LEVEL, Get, Set)
    row.toggle:SetPoint("LEFT", LABEL_W, 0)
    return row
end

local function SpellRow()
    local row = CreateFrame("Frame", nil, view.body)
    row:SetHeight(TAB_H)
    Label(row, TEXT_SPELL):SetPoint("LEFT")
    local box = F.SpellBox(ns.NewEditBox(row))
    box.spells = true
    box:SetSize(SPELL_W, TAB_H)
    box:SetFont(ns.UIFontPath(), TEXT_SIZE, "")
    box:SetPoint("LEFT", LABEL_W, 0)
    box:SetScript("OnEscapePressed", function(self)
        F.SuggestClose(self)
        self:SetText(readForm and readForm.spell or "")
        self:ClearFocus()
    end)
    function box:Commit()
        local spell = strtrim(self:GetText() or "")
        if readForm and spell ~= readForm.spell then Pick("spell", spell) end
    end
    row.box = box
    return row
end

local function NewBox(parent, fill)
    local box = CreateFrame("Frame", nil, parent)
    ns.Solid(box, "BACKGROUND", fill or T.bg, fill and BOX_FILL or 1):SetAllPoints()
    ns.Border(box, BLACK)
    box.head = P.Text(box, SMALL_SIZE, T.accentSoft)
    box.head:SetPoint("TOPLEFT", BOX_PAD, -BOX_PAD)
    box.text = P.Text(box, TEXT_SIZE)
    box.text:SetPoint("TOPLEFT", BOX_PAD, -(BOX_PAD + BOX_HEAD))
    box.text:SetPoint("RIGHT", -BOX_PAD, 0)
    box.text:SetJustifyH("LEFT")
    box.text:SetWordWrap(true)
    return box
end

local function BodySized(scroll, w)
    scroll.body:SetWidth(w)
    if F.draft and view:IsVisible() then F.DrawSimple() end
end

function F.BuildSimple(parent)
    view = CreateFrame("Frame", nil, parent)
    view:SetAllPoints()
    local scroll = UI.SlimScroll(view)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR_ROOM, 0)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(1, 1)
    scroll:SetScrollChild(body)
    scroll.body = body
    scroll:SetScript("OnSizeChanged", BodySized)
    view.body = body
    view.spell = SpellRow()
    view.aim = ChoiceRow("aim")
    view.aim.label:SetText(TEXT_AIM)
    view.kind = ChoiceRow("kind")
    view.kind.label:SetText(TEXT_KIND)
    view.fall = ChoiceRow("fall")
    view.self = ChoiceRow("self")
    view.self.label:SetText(TEXT_SELF)
    view.toggles = { ToggleRow("stop", TEXT_STOP), ToggleRow("attack", TEXT_ATTACK), ToggleRow("tip", TEXT_TIP) }
    view.press = NewBox(body, T.accent)
    view.press.head:SetText(ns.Upper(TEXT_PRESS))
    view.code = NewBox(body)
    view.code.head:SetText(ns.Upper(TEXT_WRITES))
    view.code.text:SetFont(CODE_FONT, CODE_SIZE, "")
    view.tooBig = P.Text(body, NOTE_SIZE, T.muted)
    view.tooBig:SetJustifyH("LEFT")
    view.tooBig:SetText(TEXT_TOO_BIG)
    view.advanced = ns.Button(body, TEXT_ADVANCED, ADVANCED_W, St.BUTTON_H, function()
        S.Set("forgeMode", "advanced")
    end)
    return view
end

local function Place(frame, y, w)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", view.body, "TOPLEFT", 0, -y)
    if w then frame:SetWidth(w) end
end

local function DrawChoice(row, items, shown, y, w)
    Place(row, y, w)
    row.bar:SetWidth(math.min(CHOICE_W, w - LABEL_W))
    Parts.SetTabs(row.bar, items)
    Parts.PaintTabs(row.bar, shown)
    return y + TAB_H + ROW_GAP
end

local function DrawBox(box, text, y, w)
    Place(box, y, w)
    box.text:SetText(text)
    local h = BOX_PAD * 2 + BOX_HEAD + box.text:GetStringHeight()
    box:SetHeight(h)
    return y + h + ROW_GAP
end

function F.DrawSimple()
    if not (view and F.draft) then return end
    local w = math.max(1, view.body:GetWidth())
    local f = Read(F.draft.body)
    local rows = { view.spell, view.aim, view.kind, view.fall, view.self, view.press, view.code }
    for _, row in ipairs(view.toggles) do rows[#rows + 1] = row end
    for _, row in ipairs(rows) do row:SetShown(f ~= nil) end
    view.tooBig:SetShown(f == nil)
    view.advanced:SetShown(f == nil)
    if not f then
        Place(view.tooBig, 0, w)
        Place(view.advanced, view.tooBig:GetStringHeight() + ROW_GAP)
        view.body:SetHeight(view.tooBig:GetStringHeight() + ROW_GAP + St.BUTTON_H)
        return
    end
    local y = 0
    Place(view.spell, y, w)
    if not view.spell.box:HasFocus() then view.spell.box:SetText(f.spell) end
    y = y + TAB_H + ROW_GAP
    y = DrawChoice(view.aim, AIMS, f.aim, y, w)
    view.kind:SetShown(Checked(f))
    if Checked(f) then y = DrawChoice(view.kind, KINDS, f.kind, y, w) end
    view.fall:SetShown(f.aim ~= "player")
    if f.aim ~= "player" then
        view.fall.label:SetText(TEXT_FALL:format(NO[f.aim]))
        y = DrawChoice(view.fall, FALLS[f.aim], f.fall, y, w)
    end
    view.self:SetShown(f.aim ~= "player")
    if f.aim ~= "player" then y = DrawChoice(view.self, SELF, f.self, y, w) end
    for _, row in ipairs(view.toggles) do
        Place(row, y, w)
        row.toggle._refreshValue()
        y = y + TAB_H + ROW_GAP
    end
    y = y + SECTION_GAP - ROW_GAP
    y = DrawBox(view.press, Says(f), y, w)
    y = DrawBox(view.code, Text.Colorize(F.draft.body), y, w)
    view.body:SetHeight(math.max(1, y))
end

-- ProfilesPage.lua: the Profiles page: the profiles, the parts to share and the paste box for Import.
local ns = _G.NaowhForever
local UI = ns.UI
local Profiles = ns.Profiles
local SS = ns.Shared.Settings.Style

local PROFILES_PAGE = UI.PROFILES_PAGE
local SETUPS_PAGE = "Profiles/Setups"
local HEAD_H, HEAD_SIZE = SS.HEAD_H, 14
local INSET = 16
local GAP = 8
local SUMMARY_GAP = 4
local NAME_SIZE, LINE_SIZE, SMALL_SIZE = 13, 12, 11
local ACTIVE_H, ACTIVE_SIZE = 76, 18
local MARK_W, MARK_INSET, MARK_GAP = 3, 16, 12
local LINE_GAP = 6
local ROW_NUDGE = 1
local ACTION_W = 84
local BUTTON_W, BUTTON_H = 120, 26
local SMALL_H = 22
local NEW_W = 110
local GROUP_H = SS.GROUP_H
local PROFILE_H = 46
local SHOWN_CHARS = 2
local TILE_H, TILE_PAD, TILE_GAP = 52, 12, 12
local TILE_NAME_RISE, TILE_DETAIL_DROP = 1, 3
local TWO_COLUMNS_W = SS.TWO_COLUMNS_W
local SEND_H = 58
local FIELD_H = 112
local FIELD_TEXT = 12
local FIELD_INSET_X, FIELD_INSET_Y = 8, 6
local FIELD_EDGE = 1
local SCROLL_ROOM = 13
local IMPORT_GAP = 12
local DIM = 0.4
local NAME_MAX = 40
local TEXT_NEW_PROFILE = "New Profile"
local TEXT_COPY_OF = ns.L("Copy ")
local TEXT_REPLACE_ASK = ns.L("Replace %s with a profile at default settings? Cannot be undone.")
local TEXT_OVERWRITE_ASK = ns.L("Overwrite %s with a copy of %s? Cannot be undone.")
local TEXT_RESET_ASK = ns.L("Reset %s to default settings? Cannot be undone.")
local TEXT_DELETE_ASK = ns.L("Delete %s? Characters using it move to the account's default profile.")
local TEXT_REPLACE, TEXT_OVERWRITE, TEXT_RESET, TEXT_DELETE = ns.L("Replace"), ns.L("Overwrite"), "Reset", "Delete"
local TEXT_AND_MORE = ns.L("%s and %d more")
local TEXT_AND = ns.L(" and ")
local TEXT_IN_USE_HERE = ns.L("In use on this character")
local TEXT_IN_USE_HERE_AND = ns.L("In use on this character and on ")
local TEXT_NOT_IN_USE = ns.L("Not in use on any character")
local TEXT_IN_USE_ON = ns.L("In use on ")
local TEXT_ALSO_IN_USE = ns.L("Also in use on")
local TEXT_LAST_PROFILE = ns.L("The last profile cannot be deleted.")
local TEXT_COPY, TEXT_USE = "Copy", "Use"
local TEXT_COPY_HELP = ns.L("Copy this profile into a new one and switch to it.")
local TEXT_RESET_HELP = ns.L("Put every setting in this profile back to its default.")
local TEXT_NOTHING_SAVED = ns.L("Nothing saved yet")
local TEXT_EXPORT = "Export"
local TEXT_PARTS_GO = ns.L("%d of %d parts of %s go in the string.")
local TEXT_PICK_PART = ns.L("Pick a part to share.")
local TEXT_PASTE_HERE = ns.L("Paste a profile, macro, talent build or BiS list string here.")
local TEXT_IMPORT = "Import"
local TEXT_IMPORT_NOTE = ns.L("You see what it holds and pick the parts before anything changes.")
local TEXT_PROFILES = ns.L("Profiles")
local TEXT_ONE_PROFILE, TEXT_N_PROFILES = ns.L("1 profile on this account"), ns.L(" profiles on this account")
local TEXT_OTHER_PROFILES = ns.L("OTHER PROFILES")
local TEXT_SHARE = ns.L("Share")
local TEXT_SHARE_SUMMARY = ns.L("Pick what goes in the string you give someone.")
local TEXT_PICK_ALL, TEXT_PICK_NONE = ns.L("Pick All"), ns.L("Pick None")
local TEXT_IMPORT_SUMMARY = ns.L("Profiles, Forge macros, talent builds and BiS lists.")
local UNKNOWN = "?"

local wanted = {}
local kinds
local Draw = {}
local NO_EVENTS = {}

local function Ticked(key)
    return wanted[key] ~= false
end

local function Done(ok, err)
    if not ok and err then ns.Print(err) end
    UI:RefreshPage(true)
end

local function NewProfile()
    ns.PromptText(TEXT_NEW_PROFILE, "", NAME_MAX, function(text)
        local name = strtrim(text)
        local function Make(overwrite)
            local ok, err = ns.CreateProfile(name, overwrite)
            if ok then ns.SwitchProfile(name) end
            Done(ok, err)
        end
        if not ns.ProfileExists(name) then return Make(false) end
        ns.Confirm(TEXT_REPLACE_ASK:format(name), function() Make(true) end, nil, TEXT_REPLACE)
    end)
end

local function CopyNamed(from)
    ns.PromptText(TEXT_COPY_OF .. from, "", NAME_MAX, function(text)
        local name = strtrim(text)
        local function Make(overwrite)
            local ok, err = ns.CopyProfile(from, name, overwrite)
            if ok then ns.SwitchProfile(name) end
            Done(ok, err)
        end
        if not ns.ProfileExists(name) then return Make(false) end
        ns.Confirm(TEXT_OVERWRITE_ASK:format(name, from), function() Make(true) end, nil, TEXT_OVERWRITE)
    end)
end

local function ResetActive(name)
    ns.Confirm(TEXT_RESET_ASK:format(name), function() Done(ns.ResetProfileNamed(name)) end, nil, TEXT_RESET)
end

local function DeleteNamed(name)
    ns.Confirm(TEXT_DELETE_ASK:format(name), function() Done(ns.DeleteProfile(name)) end, nil, TEXT_DELETE)
end

local function UseNamed(name)
    Done(ns.SwitchProfile(name))
end

local function Characters()
    local me = UnitName("player") .. "-" .. GetRealmName()
    local by = {}
    for _, known in ipairs(ns.KnownCharacters()) do
        if known.char ~= me then
            local list = by[known.profile] or {}
            by[known.profile] = list
            list[#list + 1] = known.char:match("^[^-]+")
        end
    end
    return by
end

local function NameList(names)
    local n = #names
    if n > SHOWN_CHARS + 1 then
        return TEXT_AND_MORE:format(table.concat(names, ", ", 1, SHOWN_CHARS), n - SHOWN_CHARS)
    end
    if n == 1 then return names[1] end
    return table.concat(names, ", ", 1, n - 1) .. TEXT_AND .. names[n]
end

local function WhoUses(names, active)
    if active then
        return #names == 0 and TEXT_IN_USE_HERE or TEXT_IN_USE_HERE_AND .. NameList(names)
    end
    return #names == 0 and TEXT_NOT_IN_USE or TEXT_IN_USE_ON .. NameList(names)
end

local function Rule(frame, point)
    local rule = ns.Solid(frame, "ARTWORK", ns.THEME.line, 1)
    rule:SetPoint(point .. "LEFT")
    rule:SetPoint(point .. "RIGHT")
    ns.Hairline(rule, "h")
    return rule
end

local function WhoEnter(hit)
    local T = ns.THEME
    if not (hit.names and ns.Shared.Parts.Tip(hit, "ANCHOR_TOP")) then return end
    GameTooltip:SetText(TEXT_ALSO_IN_USE, 1, 1, 1)
    for _, name in ipairs(hit.names) do GameTooltip:AddLine(name, T.muted.r, T.muted.g, T.muted.b) end
    GameTooltip:Show()
end

local function WhoLeave()
    GameTooltip:Hide()
end

local function WhoLine(row, size)
    row.line = ns.Font(row, size, nil, ns.THEME.muted)
    row.line:SetJustifyH("LEFT")
    row.line:SetWordWrap(false)
    row.who = CreateFrame("Frame", nil, row)
    row.who:SetAllPoints(row.line)
    row.who:EnableMouse(true)
    row.who:SetScript("OnEnter", WhoEnter)
    row.who:SetScript("OnLeave", WhoLeave)
end

local function SetWho(row, names, active)
    row.line:SetText(WhoUses(names, active))
    row.who.names = #names > SHOWN_CHARS + 1 and names or nil
end

local function SetUsable(button, on)
    button:SetAlpha(on and 1 or DIM)
    button:EnableMouse(on)
end

local function Paint(fs, color, alpha)
    fs:SetTextColor(color.r, color.g, color.b, alpha or 1)
end

local function SetDelete(button, alone)
    button.alone = alone
    button:SetAlpha(alone and DIM or 1)
    ns.Tooltip(button, alone and TEXT_LAST_PROFILE or nil)
end

local function DeleteButton(row, h)
    local button = ns.Button(row, TEXT_DELETE, ACTION_W, h, function()
        if not row.delete.alone then DeleteNamed(row.profile) end
    end)
    Paint(button.label, ns.Shared.Style.RED_RGB)
    return button
end

local function HeadAction(head)
    if head.action then head.action(head.arg) end
end

local function HeadLinkClicked(link)
    HeadAction(link:GetParent())
end

local function NewHead(view)
    local T = ns.THEME
    local head = CreateFrame("Frame", nil, view)
    ns.Solid(head, "BACKGROUND", T.panel, 1):SetAllPoints()
    Rule(head, "BOTTOM")
    head.name = ns.Font(head, HEAD_SIZE, nil, T.fg)
    head.name:SetPoint("LEFT", INSET, 0)
    head.summary = ns.Font(head, SMALL_SIZE, nil, T.muted)
    head.summary:SetPoint("LEFT", head.name, "RIGHT", GAP + SUMMARY_GAP, 0)
    head.summary:SetJustifyH("LEFT")
    head.summary:SetWordWrap(false)
    head.button = ns.Button(head, "", NEW_W, SMALL_H, function() HeadAction(head) end)
    head.button:SetPoint("RIGHT", -INSET, 0)
    head.link = ns.Shared.Parts.Link(head, HeadLinkClicked)
    head.link:SetPoint("RIGHT", -INSET, 0)
    return head
end

local function SetHead(head, title, summary, actionText, action, arg, asLink)
    local T, Parts = ns.THEME, ns.Shared.Parts
    head.action, head.arg = action, arg
    head.name:SetText(title)
    head.summary:SetText(summary or "")
    head.button:SetShown(actionText ~= nil and not asLink)
    head.link:SetShown(actionText ~= nil and asLink == true)
    local right = head
    if actionText and asLink then
        Parts.SetLink(head.link, actionText)
        head.link.disabled = action == nil
        Parts.LinkColor(head.link, action and T.accentSoft or T.muted)
        right = head.link
    elseif actionText then
        ns.SetButtonText(head.button, actionText)
        right = head.button
    end
    head.summary:SetPoint("RIGHT", right, right == head and "RIGHT" or "LEFT", -INSET, 0)
    return HEAD_H
end

local function NewActive(view)
    local T = ns.THEME
    local row = CreateFrame("Frame", nil, view)
    row.mark = ns.Solid(row, "ARTWORK", T.accent, 1)
    row.mark:SetPoint("TOPLEFT", INSET, -MARK_INSET)
    row.mark:SetPoint("BOTTOMLEFT", INSET, MARK_INSET)
    row.mark:SetWidth(MARK_W)
    row.name = ns.Font(row, ACTIVE_SIZE, nil, T.fg)
    row.name:SetPoint("BOTTOMLEFT", row, "LEFT", INSET + MARK_W + MARK_GAP, LINE_GAP / 2)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    WhoLine(row, LINE_SIZE)
    row.line:SetPoint("TOPLEFT", row, "LEFT", INSET + MARK_W + MARK_GAP, -LINE_GAP / 2)
    row.delete = DeleteButton(row, BUTTON_H)
    row.delete:SetPoint("RIGHT", -INSET, 0)
    row.copy = ns.Button(row, TEXT_COPY, ACTION_W, BUTTON_H, function() CopyNamed(row.profile) end)
    row.copy:SetPoint("RIGHT", row.delete, "LEFT", -GAP, 0)
    ns.Tooltip(row.copy, TEXT_COPY_HELP)
    row.reset = ns.Button(row, TEXT_RESET, ACTION_W, BUTTON_H, function() ResetActive(row.profile) end)
    row.reset:SetPoint("RIGHT", row.copy, "LEFT", -GAP, 0)
    ns.Tooltip(row.reset, TEXT_RESET_HELP)
    row.name:SetPoint("RIGHT", row.reset, "LEFT", -INSET, 0)
    row.line:SetPoint("RIGHT", row.reset, "LEFT", -INSET, 0)
    return row
end

local function SetActive(row, name, names, alone)
    row.profile = name
    row.name:SetText(name)
    SetWho(row, names, true)
    SetDelete(row.delete, alone)
    return ACTIVE_H
end

local function NewGroup(view)
    local row = CreateFrame("Frame", nil, view)
    Rule(row, "TOP")
    row.text = ns.Font(row, SMALL_SIZE, nil, ns.THEME.accentSoft)
    row.text:SetPoint("BOTTOMLEFT", INSET, LINE_GAP)
    return row
end

local function SetGroup(row, title)
    row.text:SetText(title)
    return GROUP_H
end

local function RowEnter(row)
    row.hover:Show()
end

local function RowLeave(row)
    if not row:IsMouseOver() then row.hover:Hide() end
end

local function PartEntered(part)
    RowEnter(part:GetParent())
end

local function PartLeft(part)
    RowLeave(part:GetParent())
end

local function NewProfileRow(view)
    local T = ns.THEME
    local row = CreateFrame("Frame", nil, view)
    ns.Shared.Parts.RowBands(row, INSET)
    row.name = ns.Font(row, NAME_SIZE, nil, T.fg)
    row.name:SetPoint("BOTTOMLEFT", row, "LEFT", INSET, LINE_GAP / 2 - ROW_NUDGE)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    WhoLine(row, SMALL_SIZE)
    row.line:SetPoint("TOPLEFT", row, "LEFT", INSET, -LINE_GAP / 2 + ROW_NUDGE)
    row.delete = DeleteButton(row, SMALL_H)
    row.delete:SetPoint("RIGHT", -INSET, 0)
    row.copy = ns.Button(row, TEXT_COPY, ACTION_W, SMALL_H, function() CopyNamed(row.profile) end)
    row.copy:SetPoint("RIGHT", row.delete, "LEFT", -GAP, 0)
    row.use = ns.AccentBorder(ns.Button(row, TEXT_USE, ACTION_W, SMALL_H, function() UseNamed(row.profile) end))
    row.use:SetPoint("RIGHT", row.copy, "LEFT", -GAP, 0)
    for _, part in ipairs({ row.delete, row.copy, row.use, row.who }) do
        part:HookScript("OnEnter", PartEntered)
        part:HookScript("OnLeave", PartLeft)
    end
    row.name:SetPoint("RIGHT", row.use, "LEFT", -INSET, 0)
    row.line:SetPoint("RIGHT", row.use, "LEFT", -INSET, 0)
    row:EnableMouse(true)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    return row
end

local function SetProfileRow(row, name, names, striped)
    row.profile = name
    row.stripe:SetShown(striped)
    row.hover:Hide()
    row.name:SetText(name)
    SetWho(row, names, false)
    SetDelete(row.delete, false)
    return PROFILE_H
end

local function PickAll(view)
    local all = true
    for _, part in ipairs(Profiles.PARTS) do
        if view.status[part.key] == "ready" and not Ticked(part.key) then all = false end
    end
    for _, part in ipairs(Profiles.PARTS) do wanted[part.key] = not all end
    view:Redraw()
end

local function Pick(tile, on)
    if not tile.ready then return end
    wanted[tile.key] = on
    tile:GetParent():Redraw()
end

local function TileClicked(tile)
    Pick(tile, not Ticked(tile.key))
end

local function TileEnter(tile)
    local T = ns.THEME
    if tile.ready then tile.edge:SetColor(T.accent.r, T.accent.g, T.accent.b, 1) end
    if not ns.Shared.Parts.Tip(tile, "ANCHOR_TOP") then return end
    GameTooltip:SetText(tile.name:GetText(), 1, 1, 1)
    GameTooltip:AddLine(tile.tip, T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function TileLeave(tile)
    local c = ns.Shared.Style.BORDER_RGB
    tile.edge:SetColor(c.r, c.g, c.b, 1)
    GameTooltip:Hide()
end

local function NewTile(view)
    local T, St = ns.THEME, ns.Shared.Style
    local tile = CreateFrame("Button", nil, view)
    ns.Solid(tile, "BACKGROUND", T.fg, St.CARD_FILL):SetAllPoints()
    tile.edge = ns.Border(tile, St.BORDER_RGB)
    tile.switch = UI.BuildToggleControl(tile, nil, function() return tile.ready and Ticked(tile.key) end,
        function(on) Pick(tile, on) end)
    tile.switch:SetPoint("LEFT", TILE_PAD, 0)
    tile.name = ns.Font(tile, NAME_SIZE, nil, T.fg)
    tile.name:SetPoint("BOTTOMLEFT", tile.switch, "RIGHT", TILE_GAP, TILE_NAME_RISE)
    tile.name:SetPoint("RIGHT", -TILE_PAD, 0)
    tile.name:SetJustifyH("LEFT")
    tile.name:SetWordWrap(false)
    tile.detail = ns.Font(tile, SMALL_SIZE, nil, T.muted)
    tile.detail:SetPoint("TOPLEFT", tile.switch, "RIGHT", TILE_GAP, -TILE_DETAIL_DROP)
    tile.detail:SetPoint("RIGHT", -TILE_PAD, 0)
    tile.detail:SetJustifyH("LEFT")
    tile.detail:SetWordWrap(false)
    tile:SetScript("OnClick", TileClicked)
    tile:SetScript("OnEnter", TileEnter)
    tile:SetScript("OnLeave", TileLeave)
    return tile
end

local function SetTile(tile, part, state, detail)
    local T = ns.THEME
    tile.key, tile.ready = part.key, state == "ready"
    tile.name:SetText(ns.L(part.label))
    Paint(tile.name, T.fg, tile.ready and 1 or DIM)
    tile.detail:SetText(state == "empty" and TEXT_NOTHING_SAVED or detail or (ns.L(part.share):gsub("%.$", "")))
    Paint(tile.detail, T.muted, tile.ready and 1 or DIM)
    tile.tip = ns.L(part.share)
    tile.switch._refreshValue()
    SetUsable(tile.switch, tile.ready)
    return TILE_H
end

local function Send()
    local ticks = {}
    for _, part in ipairs(Profiles.PARTS) do ticks[part.key] = Ticked(part.key) or nil end
    ns.ShowProfileExport(ticks)
end

local function NewSend(view)
    local row = CreateFrame("Frame", nil, view)
    Rule(row, "TOP")
    row.count = ns.Font(row, LINE_SIZE, nil, ns.THEME.muted)
    row.count:SetPoint("LEFT", INSET, 0)
    row.send = ns.AccentBorder(ns.Button(row, TEXT_EXPORT, BUTTON_W, BUTTON_H, Send))
    row.send:SetPoint("RIGHT", -INSET, 0)
    row.count:SetPoint("RIGHT", row.send, "LEFT", -INSET, 0)
    row.count:SetJustifyH("LEFT")
    return row
end

local function SetSend(row, count, ready)
    row.count:SetText(count > 0 and TEXT_PARTS_GO:format(count, ready, ns.ActiveProfileName() or UNKNOWN)
        or TEXT_PICK_PART)
    SetUsable(row.send, count > 0)
    return SEND_H
end

local function Typed(box)
    local has = box:GetText():find("%S") ~= nil
    box.hint:SetShown(not has)
    SetUsable(box.go, has)
end

local function TakeIn(box)
    local text = box:GetText()
    box:SetText("")
    box:ClearFocus()
    Typed(box)
    ns.ShowProfileImport(text)
end

local function PasteField(row)
    local T, St = ns.THEME, ns.Shared.Style
    local field = CreateFrame("Frame", nil, row)
    field:SetPoint("TOPLEFT", INSET, -INSET)
    field:SetPoint("TOPRIGHT", -INSET, -INSET)
    field:SetHeight(FIELD_H)
    ns.Solid(field, "BACKGROUND", T.bg, 1):SetAllPoints()
    ns.Border(field, St.BORDER_RGB)
    return field
end

local function PasteBox(field)
    local T = ns.THEME
    local scroll = UI.SlimScroll(field)
    scroll:SetPoint("TOPLEFT", FIELD_EDGE, -FIELD_EDGE)
    scroll:SetPoint("BOTTOMRIGHT", -SCROLL_ROOM, FIELD_EDGE)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetMaxLetters(0)
    box:SetFont(ns.UIFontPath(), FIELD_TEXT, "")
    box:SetTextColor(T.fg.r, T.fg.g, T.fg.b, 1)
    box:SetTextInsets(FIELD_INSET_X, FIELD_INSET_X, FIELD_INSET_Y, FIELD_INSET_Y)
    box:SetHeight(FIELD_H - FIELD_EDGE * 2)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnTextChanged", Typed)
    scroll:SetScrollChild(box)
    scroll:SetScript("OnSizeChanged", function(_, w) box:SetWidth(w) end)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() box:SetFocus() end)
    box.hint = ns.Font(field, FIELD_TEXT, nil, T.muted)
    box.hint:SetPoint("TOPLEFT", FIELD_INSET_X + FIELD_EDGE, -(FIELD_INSET_Y + FIELD_EDGE))
    box.hint:SetText(TEXT_PASTE_HERE)
    return box
end

local function NewPaste(view)
    local row = CreateFrame("Frame", nil, view)
    local field = PasteField(row)
    local box = PasteBox(field)
    box.go = ns.AccentBorder(ns.Button(row, TEXT_IMPORT, BUTTON_W, BUTTON_H, function() TakeIn(box) end))
    box.go:SetPoint("TOPRIGHT", field, "BOTTOMRIGHT", 0, -IMPORT_GAP)
    local note = ns.Font(row, SMALL_SIZE, nil, ns.THEME.muted)
    note:SetPoint("LEFT", field, "BOTTOMLEFT", 0, -(IMPORT_GAP + BUTTON_H / 2))
    note:SetPoint("RIGHT", box.go, "LEFT", -INSET, 0)
    note:SetJustifyH("LEFT")
    note:SetText(TEXT_IMPORT_NOTE)
    row.box = box
    Typed(box)
    return row
end

local function SetPaste()
    return INSET + FIELD_H + IMPORT_GAP + BUTTON_H + INSET
end

function Draw:BeginCard()
    self.left, self.width = 0, self:GetWidth()
    local card = self:Acquire("card")
    card:SetFrameLevel(self:GetFrameLevel())
    return card
end

function Draw:EndCard(card)
    card:SetHeight(self.cursor - card.top)
    self:Space(ns.Shared.Style.CARD_GAP)
end

function Draw:Tiles()
    local w = self:GetWidth() - INSET * 2
    local columns = self:GetWidth() >= TWO_COLUMNS_W and 2 or 1
    local tileW = math.floor((w - GAP * (columns - 1)) / columns)
    local top = self.cursor + INSET
    for i, part in ipairs(Profiles.PARTS) do
        local column = (i - 1) % columns
        if column == 0 and i > 1 then top = top + TILE_H + GAP end
        self.cursor = top
        self.left = INSET + column * (tileW + GAP)
        self.width = column == columns - 1 and w - column * (tileW + GAP) or tileW
        self:Add("part", part, self.status[part.key], self.details[part.key])
    end
    self.cursor = top + TILE_H + INSET
    self.left, self.width = 0, self:GetWidth()
end

function Draw:ProfilesCard()
    local order, by = ns.ListProfiles(), Characters()
    local active = ns.ActiveProfileName()
    local card = self:BeginCard()
    self:Add("head", TEXT_PROFILES, #order == 1 and TEXT_ONE_PROFILE or (#order .. TEXT_N_PROFILES),
        TEXT_NEW_PROFILE, NewProfile)
    self:Add("active", active, by[active] or {}, #order == 1)
    if #order > 1 then
        self:Add("group", TEXT_OTHER_PROFILES)
        local n = 0
        for _, name in ipairs(order) do
            if name ~= active then
                n = n + 1
                self:Add("profile", name, by[name] or {}, n % 2 == 0)
            end
        end
    end
    self:EndCard(card)
end

function Draw:ShareCard()
    local count, ready = 0, 0
    for _, part in ipairs(Profiles.PARTS) do
        if self.status[part.key] == "ready" then
            ready = ready + 1
            if Ticked(part.key) then count = count + 1 end
        end
    end
    local card = self:BeginCard()
    self:Add("head", TEXT_SHARE, TEXT_SHARE_SUMMARY,
        count < ready and TEXT_PICK_ALL or TEXT_PICK_NONE, ready > 0 and PickAll or nil, self, true)
    self:Tiles()
    self:Add("send", count, ready)
    self:EndCard(card)
end

function Draw:ImportCard()
    local card = self:BeginCard()
    self:Add("head", TEXT_IMPORT, TEXT_IMPORT_SUMMARY)
    self:Add("paste")
    self:EndCard(card)
end

function Draw:Redraw()
    self:Clear()
    self:ProfilesCard()
    self:ShareCard()
    self:ImportCard()
    self:Fit(NO_EVENTS)
end

local function Kinds()
    if kinds then return kinds end
    kinds = ns.Shared.View.NewKinds()
    kinds.head = { New = NewHead, Set = SetHead }
    kinds.active = { New = NewActive, Set = SetActive }
    kinds.group = { New = NewGroup, Set = SetGroup }
    kinds.profile = { New = NewProfileRow, Set = SetProfileRow }
    kinds.part = { New = NewTile, Set = SetTile }
    kinds.send = { New = NewSend, Set = SetSend }
    kinds.paste = { New = NewPaste, Set = SetPaste }
    return kinds
end

local function PartStatus(view)
    local all = Profiles.Collect()
    view.status, view.details = {}, {}
    for _, part in ipairs(Profiles.PARTS) do
        view.status[part.key] = all[part.key] and "ready" or "empty"
    end
    for _, part in ipairs(ns.ProfileStringParts({ parts = all })) do view.details[part.key] = part.detail end
end

ns.SETUPS_PAGE = SETUPS_PAGE
if UI.SearchCarries then UI.SearchCarries(PROFILES_PAGE, SETUPS_PAGE) end

function ns.ProfilesSearchTerms(add)
    add(TEXT_NEW_PROFILE, nil, TEXT_PROFILES)
    add(TEXT_USE, nil, TEXT_PROFILES)
    add(TEXT_COPY, TEXT_COPY_HELP, TEXT_PROFILES)
    add(TEXT_RESET, TEXT_RESET_HELP, TEXT_PROFILES)
    add(TEXT_DELETE, nil, TEXT_PROFILES)
    add(TEXT_EXPORT, TEXT_SHARE_SUMMARY, TEXT_SHARE)
    add(TEXT_IMPORT, TEXT_IMPORT_SUMMARY .. " " .. TEXT_PASTE_HERE, TEXT_IMPORT)
end

local function SetupsResized(host, height)
    if host.building then
        host.resized = height
        return
    end
    if height == host.resized then return end
    host.resized = height
    UI:RefreshPage(true)
end

local function SearchNarrowed()
    return UI.Search and UI.Search.Narrowed(PROFILES_PAGE)
end

local function Setups(parent, y, filter)
    local Settings = ns.Shared.Settings
    if not (Settings and Settings.pages[SETUPS_PAGE]) then return y end
    local host = parent.setupsHost
    if not host then
        host = CreateFrame("Frame", nil, parent)
        host.onResize = function(height) SetupsResized(host, height) end
        parent.setupsHost = host
    end
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    host:SetWidth(parent:GetWidth())
    host.building = true
    local height = Settings.Render(host, SETUPS_PAGE, host.onResize, filter)
    host.building = false
    host:SetHeight(height)
    return y - height
end

function ns.BuildProfileSettings(parent, y)
    local narrowed = SearchNarrowed()
    y = Setups(parent, y, narrowed)
    local view = parent.profilesView
    if narrowed then
        if view then view:Hide() end
        return y
    end
    if not view then
        view = ns.Shared.View.New(parent, Kinds(), Draw)
        parent.profilesView = view
    end
    PartStatus(view)
    view:ClearAllPoints()
    view:SetPoint("TOPLEFT", parent, "TOPLEFT", UI.CONTENT_PAD, y - UI.CONTENT_PAD / 2)
    view:SetWidth(math.max(1, parent:GetWidth() - UI.CONTENT_PAD * 2))
    view:Show()
    view:Redraw()
    return y - view:GetHeight() - UI.CONTENT_PAD
end

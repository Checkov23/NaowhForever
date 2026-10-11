-- ProfileDialogs.lua: the Export and Import dialogs of the Profiles page.
local ns = _G.NaowhForever
local UI = ns.UI
local Profiles = ns.Profiles

local EXPORT_W, EXPORT_H, BOX_H = 560, 360, 180
local IMPORT_W, IMPORT_H, PASTE_H = 600, 520, 110
local PAD, ROW_H, BUTTON_W, BUTTON_H = 14, 24, 120, 26
local BOX_RIGHT = 34
local TITLE_SIZE, TEXT_SIZE, SMALL_SIZE = 14, 12, 11
local WHAT_Y, BOX_Y, STATUS_GAP = 40, 62, 12
local PASTE_Y, PREVIEW_GAP, PREVIEW_TOP_GAP, PREVIEW_MIN_ROOM = 40, 16, 14, 44
local TOGGLE_W, TOGGLE_H, ROW_TEXT_GAP = 32, 16, 10
local NAME_ROW_GAP, NAME_W, NAME_H, NAME_MAX, NAME_GAP = 10, 220, 22, 40, 12
local BUTTON_GAP = 4
local UNKNOWN = "?"
local HANDOFFS = {
    { prefix = "!NFM1!", button = "Add Macros", module = "Macros", needs = "ImportMacroString",
      what = ns.L("These are Forge macros. They are added as character macros on this character."),
      go = function(text) ns.ImportMacroString(text) end },
    { prefix = "!NFB1!", button = "Add Build", module = "Training Planner", needs = "Training",
      what = ns.L("This is a talent build. It is added to your builds in the Training Planner."),
      go = function(text) ns.Training.ImportBuild(text, function() end) end },
    { prefix = "!NBIS1!", button = "Add BiS List", module = "BiS List", needs = "ImportBisList",
      what = ns.L("This is a BiS list. It is added next to your own lists."),
      go = function(text) ns.ImportBisList(text) end },
}
local ACTING_LINE = ns.L("It also turns on settings that act for you: %s; they stay off unless you tick Also Import.")
local ACTING_HELP = ns.L("Turns those settings on in the new profile")
local TEXT_EXPORT_TITLE, TEXT_IMPORT_TITLE = ns.L("Export Profile"), ns.L("Import")
local TEXT_PROFILE = ns.L("Profile: %s. %s.")
local TEXT_EXPORTED = ns.L("%d characters. Click the text, then Ctrl+A and Ctrl+C.")
local TEXT_CLOSE, TEXT_IMPORT, TEXT_CANCEL = ns.L("Close"), ns.L("Import"), ns.L("Cancel")
local TEXT_TURN_ON = ns.L("Turn on %s under Settings > Modules to add this.")
local TEXT_PASTE = ns.L("Paste a profile, macro, talent build or BiS list string above.")
local TEXT_SHARED_BY = ns.L("%s, shared by %s on %s. Untick what you don't want.")
local TEXT_A_PROFILE, TEXT_SOMEONE = ns.L("A profile"), ns.L("someone")
local TEXT_ALSO_IMPORT = "Also Import"
local TEXT_NEW_NAME = ns.L("New profile's name")
local TEXT_LIBRARY_MACROS = ns.L(" Library macros")
local TEXT_TALENT_BUILDS = ns.L(" talent builds")
local TEXT_BIS_LISTS = ns.L(" BiS lists")
local TEXT_ADDED = ns.L(" Added %s.")
local TEXT_IMPORTED = ns.L("Imported as %s and switched to it.%s Reload so every module picks it up?")

local export, import

local function ClearFocus(self) self:ClearFocus() end
local function HighlightText(self) self:HighlightText() end

local function MultilineBox(panel, topOffset, height)
    local scroll = UI.SlimScroll(panel)
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, topOffset)
    scroll:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -BOX_RIGHT, topOffset)
    scroll:SetHeight(height)
    ns.Solid(scroll, "BACKGROUND", ns.THEME.bg, 1):SetAllPoints()
    ns.Border(scroll)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetWidth(1)
    box:SetHeight(height)
    box:SetScript("OnEscapePressed", ClearFocus)
    scroll:SetScrollChild(box)
    scroll:SetScript("OnSizeChanged", function(_, w) box:SetWidth(w) end)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() box:SetFocus() end)
    return box
end

local function Title(panel, text)
    local title = ns.Font(panel, TITLE_SIZE, "OUTLINE")
    title:SetPoint("TOP", 0, -PAD)
    title:SetText(text)
end

local function BuildExport()
    local dimmer, panel = ns.MakeModal(EXPORT_W, EXPORT_H, "profileExport")
    Title(panel, TEXT_EXPORT_TITLE)
    local what = UI.KeepFont(panel, "what", SMALL_SIZE, nil, ns.THEME.muted)
    what:SetPoint("TOPLEFT", PAD, -WHAT_Y)
    what:SetPoint("RIGHT", -PAD, 0)
    what:SetJustifyH("LEFT")
    local box = MultilineBox(panel, -BOX_Y, BOX_H)
    box:SetScript("OnEditFocusGained", HighlightText)
    box:SetScript("OnTextChanged", function(self, user) if user then self:SetText(export.text or "") end end)
    local status = UI.KeepFont(panel, "status", SMALL_SIZE, nil, ns.THEME.fg)
    status:SetPoint("TOPLEFT", PAD, -(BOX_Y + BOX_H + STATUS_GAP))
    status:SetPoint("RIGHT", -PAD, 0)
    status:SetJustifyH("LEFT")
    local close = ns.Button(panel, TEXT_CLOSE, BUTTON_W, BUTTON_H, function() dimmer:Hide() end)
    close:SetPoint("BOTTOM", 0, PAD)
    return { dimmer = dimmer, box = box, what = what, status = status }
end

local function PartLabels(wanted)
    local labels = {}
    for _, part in ipairs(Profiles.PARTS) do
        if not wanted or wanted[part.key] then labels[#labels + 1] = part.label end
    end
    return table.concat(labels, ", ")
end

function ns.ShowProfileExport(wanted)
    if not export then export = BuildExport() end
    export.what:SetText(TEXT_PROFILE:format(ns.ActiveProfileName() or UNKNOWN, PartLabels(wanted)))
    local text, why = ns.ExportProfile(wanted)
    if text then
        export.text = text
        export.box:SetText(export.text)
        export.status:SetText(TEXT_EXPORTED:format(#text))
    else
        export.text = ""
        export.box:SetText("")
        export.status:SetText(why or "")
    end
    export.dimmer:Show()
end

local function Handoff(text)
    local flat = text:gsub("%s", "")
    local found
    for _, handoff in ipairs(HANDOFFS) do
        if flat:sub(1, #handoff.prefix) == handoff.prefix then found = handoff end
    end
    return found
end

local function ShowHandoff(handoff)
    import.payload = nil
    import.nameRow:Hide()
    if handoff.needs and not ns[handoff.needs] then
        import.preview:SetText(TEXT_TURN_ON:format(ns.L(handoff.module)))
        import.go:Hide()
        return
    end
    import.preview:SetText(handoff.what)
    ns.SetButtonText(import.go, handoff.button)
    import.go:Show()
end

local function PartRow(i)
    local row = CreateFrame("Frame", nil, import.panel)
    row:SetHeight(ROW_H)
    row.toggle = UI.BuildToggleControl(row, nil, function() return import.wanted[row.key] end,
        function(on) import.wanted[row.key] = on == true end, TOGGLE_W, TOGGLE_H)
    row.toggle:SetPoint("LEFT", 0, 0)
    row.label = UI.KeepFont(row, "label", TEXT_SIZE, nil, ns.THEME.fg)
    row.label:SetPoint("LEFT", row.toggle, "RIGHT", ROW_TEXT_GAP, 0)
    row.help = UI.KeepFont(row, "help", SMALL_SIZE, nil, ns.THEME.muted)
    row.help:SetPoint("LEFT", row.label, "RIGHT", ROW_TEXT_GAP, 0)
    import.rows[i] = row
    return row
end

local function PlacePart(i, part, y)
    local row = import.rows[i] or PartRow(i)
    row.key = part.key
    if import.wanted[part.key] == nil then import.wanted[part.key] = not part.off end
    row.label:SetText(part.label)
    row.help:SetText(part.detail and (part.help .. " (" .. part.detail .. ")") or part.help)
    row.toggle._refreshValue()
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", PAD, y)
    row:SetPoint("RIGHT", -PAD, 0)
    row:Show()
end

local function Preview(payload, acting)
    local preview = TEXT_SHARED_BY:format(
        tostring(payload.name or TEXT_A_PROFILE), tostring(payload.author or TEXT_SOMEONE), tostring(payload.made or UNKNOWN))
    if #acting > 0 then
        preview = preview .. "|n" .. ACTING_LINE:format(table.concat(acting, ", "))
    end
    return preview
end

local function ShowPayload(payload)
    local acting = ns.ProfileActing(payload)
    import.preview:SetText(Preview(payload, acting))
    local y = math.min(-(PASTE_Y + PASTE_H + PREVIEW_MIN_ROOM),
        -(PASTE_Y + PASTE_H + PREVIEW_TOP_GAP + import.preview:GetStringHeight() + PREVIEW_GAP))
    local list = ns.ProfileStringParts(payload)
    if #acting > 0 then
        list[#list + 1] = { key = "acting", label = TEXT_ALSO_IMPORT, help = ACTING_HELP, off = true }
    end
    for i, part in ipairs(list) do
        PlacePart(i, part, y)
        y = y - ROW_H
    end
    import.nameRow:ClearAllPoints()
    import.nameRow:SetPoint("TOPLEFT", PAD, y - NAME_ROW_GAP)
    import.nameRow:SetPoint("RIGHT", -PAD, 0)
    import.nameBox:SetText(Profiles.FreeName(payload.name))
end

local function PaintImport()
    local text = import.box:GetText()
    import.handoff = Handoff(text)
    for _, row in ipairs(import.rows) do row:Hide() end
    if import.handoff then return ShowHandoff(import.handoff) end
    local payload, err = ns.DecodeProfile(text)
    import.payload = payload
    import.nameRow:SetShown(payload ~= nil)
    ns.SetButtonText(import.go, TEXT_IMPORT)
    import.go:SetShown(payload ~= nil)
    if not payload then
        import.preview:SetText(err or TEXT_PASTE)
        return
    end
    ShowPayload(payload)
end

local function Joined(added)
    local joined = {}
    if added.library > 0 then joined[#joined + 1] = added.library .. TEXT_LIBRARY_MACROS end
    if added.builds > 0 then joined[#joined + 1] = added.builds .. TEXT_TALENT_BUILDS end
    if added.bisLists > 0 then joined[#joined + 1] = added.bisLists .. TEXT_BIS_LISTS end
    return #joined > 0 and TEXT_ADDED:format(table.concat(joined, ", ")) or ""
end

local function Go()
    if import.handoff then
        local text = import.box:GetText()
        import.dimmer:Hide()
        import.handoff.go(text)
        return
    end
    local payload = import.payload
    if not payload then return end
    local name, added = ns.ImportProfile(payload, import.wanted, import.nameBox:GetText())
    import.dimmer:Hide()
    if UI.RefreshPage then UI:RefreshPage(true) end
    ns.ConfirmReload(TEXT_IMPORTED:format(name, Joined(added)))
end

local function NameRow(panel)
    local nameRow = CreateFrame("Frame", nil, panel)
    nameRow:SetHeight(ROW_H)
    local nameLabel = UI.KeepFont(nameRow, "label", TEXT_SIZE, nil, ns.THEME.fg)
    nameLabel:SetPoint("LEFT", 0, 0)
    nameLabel:SetText(TEXT_NEW_NAME)
    local nameBox = ns.NewEditBox(nameRow)
    nameBox:SetSize(NAME_W, NAME_H)
    nameBox:SetMaxLetters(NAME_MAX)
    nameBox:SetPoint("LEFT", nameLabel, "RIGHT", NAME_GAP, 0)
    nameBox:SetScript("OnEnterPressed", ClearFocus)
    nameBox:SetScript("OnEscapePressed", ClearFocus)
    return nameRow, nameBox
end

local function BuildImport()
    local dimmer, panel = ns.MakeModal(IMPORT_W, IMPORT_H, "profileImport")
    Title(panel, TEXT_IMPORT_TITLE)
    local box = MultilineBox(panel, -PASTE_Y, PASTE_H)
    local preview = UI.KeepFont(panel, "preview", TEXT_SIZE, nil, ns.THEME.fg)
    preview:SetPoint("TOPLEFT", PAD, -(PASTE_Y + PASTE_H + PREVIEW_TOP_GAP))
    preview:SetPoint("RIGHT", -PAD, 0)
    preview:SetJustifyH("LEFT")
    local nameRow, nameBox = NameRow(panel)
    local go = ns.AccentBorder(ns.Button(panel, TEXT_IMPORT, BUTTON_W, BUTTON_H, Go))
    go:SetPoint("BOTTOMRIGHT", panel, "BOTTOM", -BUTTON_GAP, PAD)
    local cancel = ns.Button(panel, TEXT_CANCEL, BUTTON_W, BUTTON_H, function() dimmer:Hide() end)
    cancel:SetPoint("BOTTOMLEFT", panel, "BOTTOM", BUTTON_GAP, PAD)
    box:SetScript("OnTextChanged", function(_, user) if user then PaintImport() end end)
    return { dimmer = dimmer, panel = panel, box = box, preview = preview, nameRow = nameRow,
        nameBox = nameBox, go = go, rows = {}, wanted = {} }
end

function ns.ShowProfileImport(text)
    if not import then import = BuildImport() end
    import.box:SetText(text or "")
    wipe(import.wanted)
    PaintImport()
    import.dimmer:Show()
    import.box:SetFocus()
end

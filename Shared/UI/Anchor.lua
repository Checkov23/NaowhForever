-- Anchor.lua: anchoring a bar to a frame (ns.Shared.Anchor): its settings rows, the picker that lights the frame under the cursor, and the editor beside the bar.
local ns = _G.NaowhForever
local T = ns.THEME
local Shared = ns.Shared
local Parts = Shared.Parts
local St = Shared.Style
local ItemBar = Shared.ItemBar

local PICKER_W, PICKER_TOP = 440, -120
local BOX_W, BUTTON_W, CONTROL_H = 220, 86, 26
local HINT_SIZE, HINT_GAP = 12, 10
local CONTROL_GAP = 8
local LIGHT_SIZE, LIGHT_LIFT, LIGHT_ALPHA = 13, 4, 0.25
local OFFSET_RANGE = { -500, 500, 1 }
local SCREEN = "UIParent"
local EDIT_PAGE = "%s/Anchor"
local POINT = { ItemBar.POINT_VALUES, ItemBar.POINT_ORDER }
local TEXT_PICKER = ns.L("Anchor the %s")
local TEXT_HINT = ns.L("Click one of your unit frames, or type its name. Esc cancels.")
local TEXT_ANCHOR, TEXT_CANCEL, TEXT_DONE = "Anchor", "Cancel", "Done"
local TEXT_NO_FRAME = ns.L("No frame called %s. Frame names are case sensitive.")
local TEXT_REFUSED = ns.L("%s cannot hold the bar. Pick a unit frame; for a Naowh Forever element, use Anchor to an Element.")
local TEXT_ANCHORED = ns.L("%s anchored to %s.")
local TEXT_BACK = ns.L("%s is back on the screen.")
local TEXT_SWITCH_ON = ns.L("Switch the %s on to set where it sits.")
local TEXT_EDITING = ns.L("Anchor Settings")
local TEXT_NOT_ANCHORED = ns.L("Anchor it to a frame first")

local picker, editor

local Anchor = {}
Shared.Anchor = Anchor

local function EditKeys(spec)
    local p = spec.prefix
    return { p .. "AnchorPoint", p .. "AnchorRelPoint", p .. "X", p .. "Y" }
end

local function Declare(spec)
    if spec.editPage then return end
    spec.editPage = EDIT_PAGE:format(spec.name)
    local p = spec.prefix
    Shared.Settings.Page(spec.editPage, spec.store):Card({
        id = "anchor", name = TEXT_ANCHOR,
        help = "Where on the frame the bar sits.",
        rows = {
            { key = p .. "AnchorPoint", label = "Bar Point", choice = POINT, help = "The point of the bar that attaches." },
            { key = p .. "AnchorRelPoint", label = "Frame Point", choice = POINT,
              help = "The point of the frame it attaches to." },
            { key = p .. "X", label = "X Offset", slider = OFFSET_RANGE },
            { key = p .. "Y", label = "Y Offset", slider = OFFSET_RANGE },
        },
    })
end

local function Opacity()
    return editor and editor.spec and editor.spec.opacity and editor.spec.opacity() or 1
end

local function Finish(keep)
    if not (editor and editor.editing) then return end
    local spec = editor.spec
    editor.editing = nil
    local bar = spec.frame()
    if bar and bar.outline then bar.outline:Hide() end
    if not keep then
        for key, value in pairs(editor.before) do spec.store.Set(key, value) end
    end
    editor:Hide()
    if editor.stashed then
        editor.stashed = nil
        ns.OpenOptionsWindow()
    end
end

local function EditorView(scroll)
    local holder = CreateFrame("Frame", nil, scroll)
    holder:SetHeight(1)
    return holder
end

local function DrawEditor()
    if not (editor and editor.editing) then return end
    local holder = editor.view
    holder:SetHeight(Shared.Settings.Render(holder, editor.spec.editPage,
        function(h) holder:SetHeight(h + ns.UI.CONTENT_PAD) end))
end

local function BuildEditor()
    editor = Parts.SidePanel({
        { TEXT_CANCEL, function() Finish(false) end },
        { TEXT_DONE, function() Finish(true) end },
    }, EditorView, Opacity)
    editor:HookScript("OnHide", function() Finish(true) end)
end

function Anchor.Edit(spec, stashed)
    Declare(spec)
    local bar = spec.frame()
    if not ItemBar.Anchored(spec.store, spec.prefix) then return end
    if not (bar and spec.on()) then
        ns.Print(TEXT_SWITCH_ON:format(spec.name))
        return
    end
    if not editor then BuildEditor() end
    if editor.editing then Finish(true) end
    editor.spec = spec
    editor.before = {}
    for _, key in ipairs(EditKeys(spec)) do editor.before[key] = spec.store.Get(key) end
    editor.stashed = ns.StashOptionsWindow() or stashed or false
    editor.editing = true
    editor.title:SetText(TEXT_EDITING)
    Parts.ShowBeside(editor, bar)
    if bar.outline then bar.outline:Show() end
    DrawEditor()
end

local function NamedFrame(focus, bar)
    local node = focus
    while node and node ~= UIParent and node ~= WorldFrame do
        if node == picker or node == picker.highlight then return nil end
        if node.IsForbidden and node:IsForbidden() then return nil end
        local name = node:GetName()
        if name and _G[name] == node and ItemBar.Anchorable(node, name, bar) then return node, name end
        node = node:GetParent()
    end
end

local function StopPicking(keepAside)
    picker:SetScript("OnUpdate", nil)
    picker.box:ClearFocus()
    picker.highlight:Hide()
    picker:Hide()
    local stashed = picker.stashed
    picker.stashed = nil
    if stashed and not keepAside then ns.OpenOptionsWindow() end
    return stashed
end

local function Choose(name)
    local spec = picker.spec
    local target = _G[name]
    if not (type(target) == "table" and target.GetObjectType) then
        ns.Print(TEXT_NO_FRAME:format(name))
        return
    end
    if not ItemBar.Anchorable(target, name, spec.frame()) then
        ns.Print(TEXT_REFUSED:format(name))
        return
    end
    local bar = spec.frame()
    ns.UI.DropAnchor(bar and bar.mover)
    spec.store.Set(spec.prefix .. "Anchor", name)
    ns.Print(TEXT_ANCHORED:format(spec.name, name))
    Anchor.Edit(spec, StopPicking(true))
end

local function PickerUpdate(self)
    local target, name
    if not self:IsMouseOver() then
        local focus = GetMouseFoci()[1]
        if focus then target, name = NamedFrame(focus, self.spec.frame()) end
    end
    if target ~= self.target then
        local light = self.highlight
        light:ClearAllPoints()
        if target and pcall(light.SetAllPoints, light, target) then
            light.text:SetText(ns.L(name))
            light:Show()
        else
            light:Hide()
            target, name = nil, nil
        end
        self.target, self.name = target, name
    end
    local down = IsMouseButtonDown("LeftButton")
    if down and not self.down and self.target then Choose(self.name) end
    self.down = down
end

local function Typed()
    local text = strtrim(picker.box:GetText())
    if text ~= "" then Choose(text) end
end

local function Cancel()
    StopPicking()
end

local function PickerKey(self, key)
    if InCombatLockdown() then return end
    self:SetPropagateKeyboardInput(key ~= "ESCAPE")
    if key == "ESCAPE" then StopPicking() end
end

local function BuildPicker()
    picker = Parts.Panel("")
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetSize(PICKER_W, St.PANEL_HEADER + HINT_SIZE + HINT_GAP + CONTROL_H + St.PANEL_PAD * 2)
    picker:SetPoint("TOP", UIParent, "TOP", 0, PICKER_TOP)
    picker.close:SetScript("OnClick", Cancel)
    local hint = ns.Font(picker, HINT_SIZE, nil, T.muted)
    hint:SetPoint("TOPLEFT", St.PANEL_PAD, -St.PANEL_HEADER)
    hint:SetText(TEXT_HINT)
    picker.box = ns.NewEditBox(picker)
    picker.box:SetSize(BOX_W, CONTROL_H)
    picker.box:SetPoint("BOTTOMLEFT", St.PANEL_PAD, St.PANEL_PAD)
    picker.box:SetScript("OnEnterPressed", Typed)
    picker.box:SetScript("OnEscapePressed", Cancel)
    ns.Button(picker, TEXT_ANCHOR, BUTTON_W, CONTROL_H, Typed):SetPoint("LEFT", picker.box, "RIGHT", CONTROL_GAP, 0)
    ns.Button(picker, TEXT_CANCEL, BUTTON_W, CONTROL_H, Cancel):SetPoint("BOTTOMRIGHT", -St.PANEL_PAD, St.PANEL_PAD)
    picker:SetScript("OnKeyDown", PickerKey)
    local light = CreateFrame("Frame", nil, UIParent)
    light:SetFrameStrata("TOOLTIP")
    ns.Solid(light, "BACKGROUND", T.accent, LIGHT_ALPHA):SetAllPoints()
    ns.Border(light, T.accent)
    light.text = ns.Font(light, LIGHT_SIZE, "OUTLINE", T.accent)
    light.text:SetPoint("BOTTOM", light, "TOP", 0, LIGHT_LIFT)
    light:Hide()
    picker.highlight = light
    picker:Hide()
end

function Anchor.Pick(spec)
    Declare(spec)
    if not picker then BuildPicker() end
    picker.spec = spec
    picker.title:SetText(TEXT_PICKER:format(spec.name))
    picker.stashed = ns.StashOptionsWindow() or picker.stashed
    picker.target, picker.name = nil, nil
    picker.down = IsMouseButtonDown("LeftButton")
    picker.box:SetText(ItemBar.Anchored(spec.store, spec.prefix) and spec.store.Get(spec.prefix .. "Anchor") or "")
    if not InCombatLockdown() then
        picker:EnableKeyboard(true)
        picker:SetPropagateKeyboardInput(true)
    end
    picker:Show()
    picker:SetScript("OnUpdate", PickerUpdate)
end

function Anchor.Follow(spec)
    local bar = spec.frame()
    if not (bar and spec.on()) then
        ns.Print(TEXT_SWITCH_ON:format(spec.name))
        return
    end
    if ItemBar.Anchored(spec.store, spec.prefix) then spec.store.Set(spec.prefix .. "Anchor", SCREEN) end
    if not ns.IsUnlockModeActive() then ns.ShowUnlockMode() end
    ns.UI.PickAnchorFor(bar.mover)
end

function Anchor.Unanchor(spec)
    spec.store.Set(spec.prefix .. "Anchor", SCREEN)
    ns.Print(TEXT_BACK:format(spec.name))
end

function Anchor.Rows(spec)
    Declare(spec)
    local p = spec.prefix
    local function Anchored() return ItemBar.Anchored(spec.store, p) end
    return {
        { label = "Anchor to an Element", button = function() Anchor.Follow(spec) end, buttonText = "HUD Editor",
          help = "Opens the HUD Editor: click another Naowh Forever element for the bar to move with." },
        { label = "Anchor to a Unit Frame", button = function() Anchor.Pick(spec) end, buttonText = "Choose",
          icons = {
              { texture = St.RESET, enabled = Anchored, open = function() Anchor.Unanchor(spec) end,
                tip = "Puts the bar back on the screen." },
              { enabled = Anchored, open = function() Anchor.Edit(spec) end,
                tip = "Sets its points and offsets on screen, next to the bar." },
          },
          help = "Attaches the bar to one of your unit frames." },
        { key = p .. "Anchor", label = "Unit Frame", text = true,
          help = "The unit frame the bar is attached to, or UIParent for the screen." },
        { key = p .. "AnchorPoint", label = "Bar Point", choice = POINT, needs = Anchored, why = TEXT_NOT_ANCHORED,
          help = "The point of the bar that attaches." },
        { key = p .. "AnchorRelPoint", label = "Frame Point", choice = POINT, needs = Anchored,
          why = TEXT_NOT_ANCHORED, help = "The point of the frame it attaches to." },
        { key = p .. "X", label = "X Offset", slider = OFFSET_RANGE, needs = Anchored, why = TEXT_NOT_ANCHORED },
        { key = p .. "Y", label = "Y Offset", slider = OFFSET_RANGE, needs = Anchored, why = TEXT_NOT_ANCHORED },
    }
end

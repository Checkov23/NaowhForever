-- CodeModal.lua: a code to paste in or copy out, in a modal laid out like the website's: a title, a line, a full-width code box, a summary and its buttons (ns.Shared.Parts.CodeModal).
local ns = _G.NaowhForever
local Parts = ns.Shared.Parts
local St = ns.Shared.Style

local WIDTH, MIN_H, PAD, GAP, LINE_GAP = 560, 150, 20, 12, 4
local TITLE_SIZE, LINE_SIZE = 18, 12
local BOX_H, BUTTON_H, CLOSE_W, ACCEPT_W, BUTTON_GAP = 30, 30, 110, 150, 8
local TEXT_W = WIDTH - PAD * 2
local TEXT_CANCEL = "Cancel"

local function KeepCode(box, userInput)
    if not userInput then return end
    box:SetText(box.code)
    box:HighlightText()
end

local function SelectAll(box)
    box:HighlightText()
end

local function Text(panel, key, size, color, text)
    local fs = ns.UI.KeepFont(panel, key, size, nil, color)
    fs:SetWidth(TEXT_W)
    fs:SetJustifyH("LEFT")
    fs:SetText(text or "")
    return fs
end

local function Height(fs)
    if fs:GetText() == "" then return 0 end
    return math.ceil(fs:GetStringHeight())
end

local function CodeBox(panel, opts, line)
    local box = ns.UI.Keep(panel, "box", ns.NewEditBox)
    box:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -GAP)
    box:SetSize(TEXT_W, BOX_H)
    box:SetMaxLetters(opts.maxLetters or 0)
    box.code = opts.copy and opts.code or nil
    box:SetText(opts.code or "")
    box:SetScript("OnTextChanged", opts.copy and KeepCode or nil)
    box:SetScript("OnEditFocusGained", opts.copy and SelectAll or nil)
    return box
end

local function Buttons(panel, opts, Accept, Close)
    local UI = ns.UI
    local close = UI.KeepButton(panel, "close", opts.closeText or TEXT_CANCEL, CLOSE_W, BUTTON_H, Close)
    if not opts.onAccept then
        close:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        return
    end
    local accept = UI.KeepButton(panel, "accept", opts.acceptText, ACCEPT_W, BUTTON_H, Accept)
    ns.PrimaryButton(accept, St.ON_ACCENT_RGB)
    accept:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    close:SetPoint("RIGHT", accept, "LEFT", -BUTTON_GAP, 0)
end

function Parts.CodeModal(opts)
    local T = ns.THEME
    local dimmer, panel = ns.MakeModal(WIDTH, MIN_H, "codeModal")
    local title = Text(panel, "title", TITLE_SIZE, T.fg, opts.title)
    title:SetPoint("TOPLEFT", PAD, -PAD)
    local line = Text(panel, "line", LINE_SIZE, T.muted, opts.line)
    line:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -LINE_GAP)
    local box = CodeBox(panel, opts, line)
    local summary = Text(panel, "summary", LINE_SIZE, T.fg, opts.summary)
    summary:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -GAP)
    local function Close() dimmer:Hide() end
    local function Accept()
        local value = strtrim(box:GetText() or "")
        if value == "" then return end
        dimmer:Hide()
        opts.onAccept(value)
    end
    Buttons(panel, opts, Accept, Close)
    box:SetScript("OnEnterPressed", opts.onAccept and Accept or Close)
    box:SetScript("OnEscapePressed", Close)
    local textH = Height(title) + LINE_GAP + Height(line) + GAP + BOX_H + GAP + Height(summary)
    panel:SetHeight(math.max(MIN_H, PAD * 2 + textH + GAP + BUTTON_H))
    dimmer:Show()
    box:SetFocus()
    box:HighlightText()
    return dimmer, box
end


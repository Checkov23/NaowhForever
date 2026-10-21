-- Window.lua: a window in the house look (ns.Shared.Parts): the frame, its size grip, the title bar with its logo and icons, the footer, and the Forever frame's place for the title bar.
local ns = _G.NaowhForever
local T = ns.THEME
local Parts = ns.Shared.Parts
local St = ns.Shared.Style

local TipLines = Parts.TipLines

local BORDER_RGB, HEADER, PAD, FOOTER = St.BORDER_RGB, St.WINDOW_HEADER, St.WINDOW_PAD, St.WINDOW_FOOTER
local BAR_ICON, LOGO, LOGO_SIZE = St.BAR_ICON, St.LOGO, St.LOGO_SIZE
local SMALL_SIZE = St.SMALL_SIZE
local LOGO_REST = 0.9
local BRAND_REST = 0.8
local TITLE_SIZE, TITLE_GAP, TITLE_RISE = 20, 10, 1
local SUBTITLE_GAP = 2
local BACK_GAP, BACK_DROP = 16, 1
local CLOSE_SIZE, CLOSE_IN = 24, 8
local GRIP, GRIP_INSET, GRIP_LEVEL = 16, 3, 20
local GRIP_TEXTURE = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-"
local BAR_ICON_PAD, BAR_ICON_IN = 4, 2
local BAR_LABEL_GAP, BAR_LABEL_ROOM = 4, 8
local FOOTER_SIZE = 10
local FOOTER_LOGO = 14
local FOOTER_INSET = 8
local FOOTER_LEFT = 6
local FOOTER_RIGHT = 4
local FOOTER_RISE = 3
local BRAND_GAP = 5
local TEXT_BACK = ns.L("Back")
local TEXT_ADDON = "Naowh Forever"
local TEXT_OPEN_OPTIONS = ns.L("Click to open its options.")
local TEXT_CLOSE = "x"
local TEXT_BRAND, TEXT_BRAND_ACCENT = "Naowh ", "Forever"

local pendingBack, pendingBackText

local function OnShow(frame)
    if not InCombatLockdown() then
        frame:EnableKeyboard(true)
        frame:SetPropagateKeyboardInput(true)
    end
    if pendingBack then
        Parts.SetBack(frame, pendingBack, pendingBackText)
        pendingBack, pendingBackText = nil, nil
    end
end

local function OnHide(frame)
    if frame.stepAside then return end
    local back = frame.onBack
    if not back then return end
    Parts.SetBack(frame, nil)
    back()
end

local function DragStop(frame)
    frame:StopMovingOrSizing()
    local point, _, relativePoint, x, y = frame:GetPoint()
    ns.AccountSettings()[frame.positionKey] = { point, relativePoint, x, y }
end

local function Place(window, positionKey)
    local saved = ns.AccountSettings()[positionKey]
    if type(saved) == "table" then
        window:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    else
        window:SetPoint("CENTER")
    end
end

local function HeaderRule(window)
    local rule = ns.Solid(window, "ARTWORK", BORDER_RGB, 1)
    rule:SetPoint("TOPLEFT", 0, -HEADER)
    rule:SetPoint("TOPRIGHT", 0, -HEADER)
    ns.Hairline(rule, "h")
end

local function KeepSize(window, sizeKey)
    local account = ns.AccountSettings()
    account.windowSizes = account.windowSizes or {}
    account.windowSizes[sizeKey] = { window:GetWidth(), window:GetHeight() }
end

local function LogoEnter(logo)
    logo.icon:SetAlpha(1)
    TipLines(logo, "ANCHOR_BOTTOMRIGHT", TEXT_ADDON, TEXT_OPEN_OPTIONS)
end

local function LogoLeave(logo)
    logo.icon:SetAlpha(LOGO_REST)
    GameTooltip:Hide()
end

local function OpenPage(button)
    ns.OpenOptionsWindow(button.page)
end

local function BackClicked(link)
    link:GetParent():Hide()
end

local function Logo(window, page, middle, texture, size)
    local logo = CreateFrame("Button", nil, window)
    logo:SetSize(size or LOGO_SIZE, size or LOGO_SIZE)
    logo:SetPoint("LEFT", window, "TOPLEFT", PAD, middle)
    logo.icon = logo:CreateTexture(nil, "ARTWORK")
    logo.icon:SetAllPoints()
    logo.icon:SetTexture(texture or LOGO, nil, nil, "TRILINEAR")
    logo.icon:SetAlpha(LOGO_REST)
    logo.page = page
    logo:SetScript("OnClick", OpenPage)
    logo:SetScript("OnEnter", LogoEnter)
    logo:SetScript("OnLeave", LogoLeave)
    return logo
end

local function Light(frame, lit)
    local color = lit and T.accent or T.muted
    frame.icon:SetVertexColor(color.r, color.g, color.b)
    if frame.label then frame.label:SetTextColor(color.r, color.g, color.b) end
end

local function BarLeave(frame)
    Light(frame, false)
    GameTooltip:Hide()
end

local function BarButtonEnter(button)
    Light(button, true)
    TipLines(button, "ANCHOR_BOTTOM", button.tip, button.hint)
end

local function BrandEnter(brand)
    brand:SetAlpha(1)
    TipLines(brand, "ANCHOR_TOP", TEXT_ADDON, TEXT_OPEN_OPTIONS)
end

local function BrandLeave(brand)
    brand:SetAlpha(BRAND_REST)
    GameTooltip:Hide()
end

Parts.LightBarIcon = Light

function Parts.SetBack(window, back, text)
    window.onBack = back
    local link = window.backLink
    if not link then return end
    link:SetShown(back ~= nil)
    if back then Parts.SetLink(link, text or TEXT_BACK) end
end

function Parts.OpenWithBack(open, from, back, text)
    pendingBack, pendingBackText = back, text
    from:Hide()
    open()
    pendingBack, pendingBackText = nil, nil
end

function Parts.Window(width, height, positionKey)
    local window = CreateFrame("Frame", nil, UIParent)
    window:Hide()
    window:SetSize(width, height)
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    ns.AllowOffscreen(window)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window.positionKey = positionKey
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", DragStop)
    Place(window, positionKey)
    window.backdrop = Parts.Backdrop(window)
    ns.Border(window, BORDER_RGB)
    if ns.foreverSkin then Parts.ForeverFrame(window) end
    window:SetScript("OnKeyDown", ns.UI.CloseOnEscape)
    window:SetScript("OnShow", OnShow)
    window:SetScript("OnHide", OnHide)
    HeaderRule(window)
    return window
end

function Parts.ClassicIcon(texture, name)
    local icon = ns.foreverSkin and St.CLASSIC_ICONS[name]
    if not (icon and texture:SetTexture(St.CLASSIC_ICON_PATH .. icon)) then return false end
    local crop = St.CLASSIC_ICON_CROP
    texture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
    texture:SetDesaturated(false)
    texture:SetVertexColor(1, 1, 1, 1)
    return true
end

function Parts.Resizable(window, sizeKey, minW, minH, onSized, onReleased)
    local sizes = ns.AccountSettings().windowSizes
    local saved = sizes and sizes[sizeKey]
    if saved then window:SetSize(math.max(saved[1], minW), math.max(saved[2], minH)) end
    window:SetResizable(true)
    window:SetResizeBounds(minW, minH)
    if onSized then window:SetScript("OnSizeChanged", onSized) end
    local grip = CreateFrame("Button", nil, window)
    grip:SetSize(GRIP, GRIP)
    grip:SetPoint("BOTTOMRIGHT", -GRIP_INSET, GRIP_INSET)
    grip:SetFrameLevel(window:GetFrameLevel() + GRIP_LEVEL)
    grip:SetNormalTexture(GRIP_TEXTURE .. "Up")
    grip:SetHighlightTexture(GRIP_TEXTURE .. "Highlight")
    grip:SetPushedTexture(GRIP_TEXTURE .. "Down")
    grip:SetScript("OnMouseDown", function() window:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        window:StopMovingOrSizing()
        KeepSize(window, sizeKey)
        if onReleased then onReleased() end
    end)
    return grip
end

Parts.Logo = Logo
Parts.Place = Place

local function ForeverTitleBar(window, close, middle)
    local portrait = window.forever.portrait
    window.logo:ClearAllPoints()
    window.logo:SetAllPoints(portrait)
    window.logo.icon:Hide()
    window.title:ClearAllPoints()
    window.title:SetPoint("TOPLEFT", window, "TOPLEFT", St.FOREVER_PORTRAIT_ROOM, middle + LOGO_SIZE / 2 + TITLE_RISE)
    close:Hide()
end

function Parts.TitleBar(window, title, subtitle, page, closeSize, closeText)
    local middle = -HEADER / 2
    window.logo = Logo(window, page, middle)
    window.title = ns.Font(window, TITLE_SIZE, nil, ns.foreverSkin and T.accent or T.fg, true)
    window.title:SetPoint("TOPLEFT", window.logo, "TOPRIGHT", TITLE_GAP, TITLE_RISE)
    window.title:SetText(ns.L(title))
    window.subtitle = ns.Font(window, SMALL_SIZE, nil, T.muted)
    window.subtitle:SetPoint("TOPLEFT", window.title, "BOTTOMLEFT", 0, -SUBTITLE_GAP)
    window.subtitle:SetJustifyH("LEFT")
    window.subtitle:SetWordWrap(false)
    window.subtitle:SetText(ns.L(subtitle))
    window.backLink = Parts.Link(window, BackClicked, true)
    window.backLink:SetPoint("LEFT", window.title, "RIGHT", BACK_GAP, -BACK_DROP)
    window.backLink:Hide()
    closeSize = closeSize or CLOSE_SIZE
    local close = ns.Button(window, closeText or TEXT_CLOSE, closeSize, closeSize, function() window:Hide() end)
    close:SetPoint("RIGHT", window, "TOPRIGHT", -CLOSE_IN, middle)
    window.subtitle:SetPoint("RIGHT", close, "LEFT", -St.BAR_GAP, 0)
    if window.forever then ForeverTitleBar(window, close, middle) end
    return close
end

function Parts.BarIcon(parent, texture, isButton)
    local frame = CreateFrame(isButton and "Button" or "Frame", nil, parent)
    frame:SetSize(BAR_ICON + BAR_ICON_PAD, BAR_ICON + BAR_ICON_PAD)
    frame:EnableMouse(true)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetTexture(texture)
    frame.icon:SetSize(BAR_ICON, BAR_ICON)
    frame.icon:SetPoint("LEFT", BAR_ICON_IN, 0)
    Light(frame, false)
    frame:SetScript("OnLeave", BarLeave)
    return frame
end

function Parts.BarButton(parent, texture, tip, hint, onClick, text)
    local button = Parts.BarIcon(parent, texture, true)
    button.tip, button.hint = tip, hint
    if text then
        button.label = ns.Font(button, St.TEXT_SIZE)
        button.label:SetPoint("LEFT", button.icon, "RIGHT", BAR_LABEL_GAP, 0)
        button.label:SetText(ns.L(text))
        button:SetWidth(BAR_ICON + BAR_LABEL_ROOM + math.ceil(button.label:GetStringWidth()))
        Light(button, false)
    end
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", BarButtonEnter)
    return button
end

function Parts.FooterBrand(window, page, left)
    local brand = CreateFrame("Button", nil, window)
    brand.icon = brand:CreateTexture(nil, "ARTWORK")
    brand.icon:SetTexture(St.LOGO_SMALL, nil, nil, "TRILINEAR")
    brand.icon:SetSize(FOOTER_LOGO, FOOTER_LOGO)
    brand.icon:SetPoint("LEFT")
    brand.text = ns.Font(brand, FOOTER_SIZE, nil, T.fg)
    brand.text:SetPoint("LEFT", brand.icon, "RIGHT", BRAND_GAP, 0)
    brand.text:SetText(TEXT_BRAND .. ns.Color("accent", TEXT_BRAND_ACCENT))
    brand:SetSize(FOOTER_LOGO + BRAND_GAP + math.ceil(brand.text:GetStringWidth()), FOOTER)
    brand:SetPoint("BOTTOMLEFT", (left or FOOTER_LEFT) + FOOTER_INSET, FOOTER_RISE)
    brand.page = page
    brand:SetScript("OnClick", OpenPage)
    brand:SetScript("OnEnter", BrandEnter)
    brand:SetScript("OnLeave", BrandLeave)
    BrandLeave(brand)
    return brand
end

function Parts.FooterNote(window, text, onEnter)
    local note = CreateFrame("Frame", nil, window)
    note.text = ns.Font(note, FOOTER_SIZE, nil, T.muted)
    note.text:SetPoint("RIGHT")
    note.text:SetText(ns.L(text))
    note:SetSize(math.ceil(note.text:GetStringWidth()), FOOTER)
    note:SetPoint("BOTTOMRIGHT", -(FOOTER_RIGHT + FOOTER_INSET), FOOTER_RISE)
    if onEnter then
        note:EnableMouse(true)
        note:SetScript("OnEnter", onEnter)
        note:SetScript("OnLeave", GameTooltip_Hide)
    end
    return note
end

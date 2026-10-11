-- SetupWindow.lua: the onboarding window: its welcome or a new character's choice, then a profile, a skin, the modules and Apply.
local ns = _G.NaowhForever
local T = ns.THEME
local Parts = ns.Shared.Parts
local St = ns.Shared.Style
local Setup = ns.Setup

local WIDTH, HEIGHT = 780, 580
local INSET, EDGE, HEADER = St.CONTENT_INSET, St.WINDOW_PAD, St.WINDOW_HEADER
local BUTTON_H, NAV_W, APPLY_W, START_W, START_H = 26, 110, 150, 170, 32
local FOOT_H = BUTTON_H + EDGE * 2
local TILE_GAP, TILE_H, TILE_MAX_W, HINT_GAP = 12, 156, 230, 22
local ICON, GLYPH, CHECK = 60, 34, 16
local LIT, HOVER = 0.12, 0.06
local ARROW, ARROW_GAP = 12, 6
local TITLE_SIZE, HEAD_SIZE, BODY_SIZE, SMALL_SIZE = 19, 15, 13, 11
local POSITION_KEY = "setupWindow"
local BLACK = St.BORDER_RGB
local RED = St.RED_RGB
local WHITE = { r = 1, g = 1, b = 1 }
local CHECK_ART = ns.MEDIA .. "check.tga"
local NAV_ICONS = ns.MEDIA .. "Navigation\\"
local NAV_FALLBACK = "window"
local TRACK = "Interface\\AddOns\\NaowhForever\\Core\\Onboarding\\Media\\infinity_track.tga"
local GLOW = "Interface\\AddOns\\NaowhForever\\Core\\Onboarding\\Media\\glow_dot.tga"
local HEAD_RGB = { r = 0.85, g = 0.95, b = 1 }
local GLYPHS = "Interface\\AddOns\\NaowhForever\\Core\\Onboarding\\Media\\Setup\\"
local NEXT_ART, BACK_ART = GLYPHS .. "next.tga", GLYPHS .. "back.tga"
local FILTER = "TRILINEAR"
local PANEL_ALPHA, DIM_ALPHA = 0.9, 0.5
local STEP = { choice = -1, welcome = 0, profile = 1, skin = 2, modules = 3, summary = 4, count = 4 }
local WELCOME_LAYOUT = { taglineTop = 30, taglineSpacing = 4, signGap = 6, siteGap = 4, siteTextGrow = 1,
    thanksW = 540, thanksGap = 10, cornerGap = 4, promiseTop = 24, promisePlate = 34, promiseGlyph = 22,
    promiseX = 12, promiseTextRoom = 60, promiseTextGap = 10, promiseSubGap = 3, startGap = 28, keepGap = 10,
    promiseW = 210, promiseH = 58, promiseGap = 12, linkSize = 16, linkGap = 10, footLine = 16, footLineH = 18,
    taglineSize = 30 }
local SIGN_SHAPE = { fullTurn = 2 * math.pi, reachX = 0.44, reachY = 0.84, shrink = 0.45, curve = 1.6, alpha = 0.9,
    w = 168, h = 84, trackAlpha = 0.35, trail = 70, trailStep = 0.022, lap = 4.2, dot = 9, headDot = 22 }
local ANIM = { fadeIn = 0.18, glowOut = 0.45, glowAlpha = 0.5, popIn = 0.18, popFrom = 0.4 }
local SEG = { w = 26, h = 4, gap = 4, right = 44 }
local TILE_LAYOUT = { checkInset = 6, markInset = 4, iconTop = 20, nameGap = 14, textRoom = 20, blurbGap = 5,
    hintGap = 6 }
local SKIN_LAYOUT = { columns = 2, tileH = 220, nameGap = 14 }
local PREVIEW = { w = 190, h = 112, bar = 22, pad = 8, titleSize = 12, bodySize = 11, labelSize = 10,
    buttonW = 64, buttonH = 20 }
local MODULE_LAYOUT = { columns = 3, tileH = 56, gap = 8, plate = 36, glyph = 22, iconX = 10, textGap = 10,
    textRoom = 30, blurbGap = 2 }
local SUMMARY_LAYOUT = { w = 560, rowH = 58, gap = 10, plate = 34, glyph = 22, iconX = 12, textGap = 12,
    textRoom = 70, subGap = 3, pad = 22, rows = 4 }
local FOOT_LAYOUT = { noteGap = 12 }
local CHOICE = { columns = 2, sameArt = ns.MEDIA .. "chain.tga", ownArt = ns.MEDIA .. "wand.tga" }
local PROFILE_ICONS = { minimalist = "essentials", recommended = "everything", [Setup.KEEP] = "purist" }
local PROFILE_ICON_ANY = "everything"
local SUMMARY_ICONS = { skin = "interface", on = "changes", off = "none" }
local LIST_JOIN = ", "
local TEXT_BACK, TEXT_NEXT, TEXT_APPLY = ns.L("Back"), ns.L("Next"), ns.L("Apply")

local TITLE = ns.L("Naowh Forever: Onboarding")
local WELCOME_SUB = ns.L("Welcome")
local WELCOME_FOR = ns.L("Just for %s")
local WELCOME = ns.L("Welcome, and thank you for joining us")
local TAGLINE_1, TAGLINE_2A, TAGLINE_2B = ns.L("One addon"), ns.L("to rule"), ns.L("them all.")
local SITE_LINE = ns.L("New here? Every feature is shown on our website:")
local SITE_LINK = "naowh.gg/forever"
local SITE_TITLE = ns.L("Naowh Forever on naowh.gg")
local SITE_URL = "https://naowh.gg/forever/"
local THANKS = ns.L("This is a new adventure for all of us. Naowh Forever is crafted by a small, dedicated team with "
    .. "a lot of passion, and we hope you enjoy every bit of it.")
local PROMISES = {
    { ns.L("Four quick steps"), ns.L("About a minute."), "questions" },
    { ns.L("Review it all"), ns.L("Nothing changes before you apply."), "review" },
    { ns.L("Undo any time"), ns.L("Restore it from the Profiles page."), "undo" },
}
local START = ns.L("Let's start")
local KEEP = ns.L("or keep my setup as it is")
local STEP_OF = ns.L("Step %d of %d")
local TEXT_PROFILE = { title = ns.L("Where do you want to start?"), hint = ns.L("You can change everything afterwards."),
    keepName = ns.L("Keep mine"), keepBlurb = ns.L("Your settings stay as they are.") }
local TEXT_SKIN = { title = ns.L("How should Naowh Forever look?"), hint = ns.L("For every character on this computer."),
    previewTitle = "Naowh Forever", previewBody = ns.L("Every window looks like this."), previewButton = ns.L("Start") }
local SKIN_NAMES = { [Setup.SKIN_NAOWH] = "Naowh", [Setup.SKIN_CLASSIC] = "Classic+" }
local SKIN_BLURBS = { [Setup.SKIN_NAOWH] = ns.L("Naowh's dark look, with his blue."),
    [Setup.SKIN_CLASSIC] = ns.L("The game's own look, in gold and bronze.") }
local TEXT_MODULES = { title = ns.L("Which modules do you want?"), hint = ns.L("Click a module to turn it on or off."),
    hintFor = ns.L("Click a module to turn it on or off, for %s only."), count = ns.L("%d of %d on") }
local TEXT_SUMMARY = { title = ns.L("Here's your setup"), hint = ns.L("Nothing changes until you apply it."),
    profile = ns.L("Profile"), skin = ns.L("Skin"), on = ns.L("Turns on"), off = ns.L("Turns off"), stays = ns.L("Your settings stay."),
    sameSkin = ns.L("%s, as now") }
local IN_COMBAT = ns.L("Apply after your fight.")
local DONE_RELOAD = ns.L("Your setup is ready. Reload now to finish?")
local DONE = ns.L("Your setup is ready.")
local TEXT_CHOICE = {
    head = ns.L("Welcome, %s!"),
    text = ns.L("You've played Naowh Forever on %s. Share %s's settings, or give %s its own?"),
    sameName = ns.L("Same as %s"), sameBlurb = ns.L("%s uses %s's settings; a change on one shows on both."),
    ownName = ns.L("Set Up %s"), ownBlurb = ns.L("A few quick steps for %s only, its own modules included."),
    sameDone = ns.L("%s now uses the same settings as %s."),
}

local window, step, picks, plan, modules, forCharacter
local newCharacter = {}
local Paint

local function Text(parent, size, color, width, justify)
    local fs = ns.Font(parent, size, nil, color)
    fs:SetJustifyH(justify or "LEFT")
    if width then fs:SetWidth(width) end
    return fs
end

local function SetGlyph(tex, name)
    tex:SetTexture(GLYPHS .. name .. ".tga", nil, nil, FILTER)
end

local function Tint(tex, c)
    tex:SetVertexColor(c.r, c.g, c.b)
end

local function Glyph(parent, plate, size, name)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(plate, plate)
    ns.Solid(holder, "BACKGROUND", T.bg, 1):SetAllPoints()
    holder.edge = ns.Border(holder, BLACK)
    holder.tex = holder:CreateTexture(nil, "ARTWORK")
    holder.tex:SetPoint("CENTER")
    holder.tex:SetSize(size, size)
    if name then SetGlyph(holder.tex, name) end
    return holder
end

local function Rule(parent)
    local rule = ns.Solid(parent, "ARTWORK", T.line, 1)
    ns.Hairline(rule, "h")
    return rule
end

local function Panel(parent)
    local frame = CreateFrame("Frame", nil, parent)
    ns.Solid(frame, "BACKGROUND", T.panel, PANEL_ALPHA):SetAllPoints()
    frame.edge = ns.Border(frame, BLACK)
    return frame
end

local function SetLit(frame, on, hovered)
    local edge = on and T.accent or hovered and T.accentSoft or BLACK
    frame.edge:SetColor(edge.r, edge.g, edge.b, 1)
    frame.lit:SetShown(on or hovered)
    frame.lit:SetAlpha(on and 1 or HOVER / LIT)
end

local function FadeIn(frame)
    if not frame.fadeIn then
        local group = frame:CreateAnimationGroup()
        local alpha = group:CreateAnimation("Alpha")
        alpha:SetFromAlpha(0)
        alpha:SetToAlpha(1)
        alpha:SetDuration(ANIM.fadeIn)
        alpha:SetSmoothing("OUT")
        frame.fadeIn = group
    end
    frame.fadeIn:Stop()
    frame.fadeIn:Play()
end

local function Glow(frame)
    if not frame.glow then
        local tex = frame:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        tex:SetColorTexture(T.accent.r, T.accent.g, T.accent.b, 1)
        tex:SetBlendMode("ADD")
        tex:SetAlpha(0)
        local group = tex:CreateAnimationGroup()
        local alpha = group:CreateAnimation("Alpha")
        alpha:SetFromAlpha(ANIM.glowAlpha)
        alpha:SetToAlpha(0)
        alpha:SetDuration(ANIM.glowOut)
        alpha:SetSmoothing("OUT")
        frame.glow = group
    end
    frame.glow:Stop()
    frame.glow:Play()
end

local function Pop(frame)
    if not frame.pop then
        local group = frame:CreateAnimationGroup()
        local scale = group:CreateAnimation("Scale")
        scale:SetScaleFrom(ANIM.popFrom, ANIM.popFrom)
        scale:SetScaleTo(1, 1)
        scale:SetDuration(ANIM.popIn)
        scale:SetSmoothing("OUT")
        frame.pop = group
    end
    frame.pop:Stop()
    frame.pop:Play()
end

local function Arrow(button, art, after)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ARROW, ARROW)
    icon:SetTexture(art, nil, nil, FILTER)
    Tint(icon, T.fg)
    local shift = (ARROW + ARROW_GAP) / 2
    button.label:ClearAllPoints()
    button.label:SetPoint("CENTER", after and -shift or shift, 0)
    if after then
        icon:SetPoint("LEFT", button.label, "RIGHT", ARROW_GAP, 0)
    else
        icon:SetPoint("RIGHT", button.label, "LEFT", -ARROW_GAP, 0)
    end
    button.arrow = icon
    return button
end

local function Page()
    local page = CreateFrame("Frame", nil, window)
    page:SetPoint("TOPLEFT", 0, -HEADER)
    page:SetPoint("BOTTOMRIGHT", 0, FOOT_H)
    window.pages[#window.pages + 1] = page
    return page
end

local function KeepAsItIs()
    window:Hide()
end

local function Hidden(self)
    window.events:UnregisterAllEvents()
    if self:IsShown() then return end
    local account = ns.AccountSettings()
    account.onboardingSeen, account.welcomeSeen = true, true
    ns.MarkAsked()
end

local function ShowSite()
    ns.ShowCopyLine(SITE_TITLE, SITE_URL, St.LOGO)
end

local function SignPoint(angle)
    local s, c = math.sin(angle), math.cos(angle)
    local k = 1 + s * s
    return SIGN_SHAPE.w * SIGN_SHAPE.reachX * c / k, SIGN_SHAPE.h * SIGN_SHAPE.reachY * s * c / k
end

local function Spin(sign, elapsed)
    sign.angle = (sign.angle + elapsed * SIGN_SHAPE.fullTurn / SIGN_SHAPE.lap) % SIGN_SHAPE.fullTurn
    for i, dot in ipairs(sign.dots) do
        dot:SetPoint("CENTER", sign, "CENTER", SignPoint(sign.angle - (i - 1) * SIGN_SHAPE.trailStep))
    end
end

local function SpinStart(sign)
    sign:SetScript("OnUpdate", Spin)
end

local function SpinStop(sign)
    sign:SetScript("OnUpdate", nil)
end

local function Sign(page)
    local sign = CreateFrame("Frame", nil, page)
    sign:SetSize(SIGN_SHAPE.w, SIGN_SHAPE.h)
    local track = sign:CreateTexture(nil, "ARTWORK")
    track:SetTexture(TRACK, nil, nil, FILTER)
    track:SetAllPoints()
    track:SetVertexColor(T.accent.r, T.accent.g, T.accent.b)
    track:SetAlpha(SIGN_SHAPE.trackAlpha)
    sign.dots = {}
    for i = 1, SIGN_SHAPE.trail + 1 do
        local dot = sign:CreateTexture(nil, "OVERLAY")
        dot:SetTexture(GLOW, nil, nil, FILTER)
        dot:SetBlendMode("ADD")
        if i == 1 then
            dot:SetSize(SIGN_SHAPE.headDot, SIGN_SHAPE.headDot)
            dot:SetVertexColor(HEAD_RGB.r, HEAD_RGB.g, HEAD_RGB.b)
        else
            local fade = (i - 2) / SIGN_SHAPE.trail
            local size = SIGN_SHAPE.dot * (1 - SIGN_SHAPE.shrink * fade)
            dot:SetSize(size, size)
            dot:SetVertexColor(T.accent.r + (HEAD_RGB.r - T.accent.r) * (1 - fade),
                T.accent.g + (HEAD_RGB.g - T.accent.g) * (1 - fade), T.accent.b + (HEAD_RGB.b - T.accent.b) * (1 - fade))
            dot:SetAlpha((1 - fade) ^ SIGN_SHAPE.curve * SIGN_SHAPE.alpha)
        end
        sign.dots[i] = dot
    end
    sign.angle = 0
    Spin(sign, 0)
    sign:SetScript("OnShow", SpinStart)
    sign:SetScript("OnHide", SpinStop)
    return sign
end

local function Corners(page)
    local middle = WELCOME_LAYOUT.footLine + WELCOME_LAYOUT.footLineH / 2
    local x = EDGE + WELCOME_LAYOUT.cornerGap
    for _, link in ipairs(ns.LINKS) do
        local name, url = link[1], link[3]
        local button = Parts.IconButton(page, function() ns.ShowCopyLine(name, url()) end,
            ns.LINK_ICONS .. link[2] .. ".tga", nil, name)
        button:SetSize(WELCOME_LAYOUT.linkSize, WELCOME_LAYOUT.linkSize)
        button.icon:SetSize(WELCOME_LAYOUT.linkSize, WELCOME_LAYOUT.linkSize)
        button:SetPoint("LEFT", window, "BOTTOMLEFT", x, middle)
        x = x + WELCOME_LAYOUT.linkSize + WELCOME_LAYOUT.linkGap
    end
    page.version = ns.Font(page, SMALL_SIZE, nil, T.muted)
    page.version:SetPoint("RIGHT", window, "BOTTOMRIGHT", -EDGE - WELCOME_LAYOUT.cornerGap, middle)
    page.version:SetText(ns.VersionText())
end

local function Tagline(page)
    page.tagline = Text(page, WELCOME_LAYOUT.taglineSize, T.fg, WIDTH - INSET * 2, "CENTER")
    page.tagline:SetPoint("TOP", 0, -WELCOME_LAYOUT.taglineTop)
    page.tagline:SetText(TAGLINE_1 .. "\n" .. ns.Color(T.accent) .. TAGLINE_2A .. "|r " .. St.LOOK_CODE .. TAGLINE_2B .. "|r")
    page.tagline:SetSpacing(WELCOME_LAYOUT.taglineSpacing)
    page.sign = Sign(page)
    page.sign:SetPoint("TOP", page.tagline, "BOTTOM", 0, -WELCOME_LAYOUT.signGap)
end

local function BuildWelcome()
    local page = Page()
    Tagline(page)
    page.head = Text(page, HEAD_SIZE, T.fg, WIDTH - INSET * 2, "CENTER")
    page.head:SetPoint("TOP", page.sign, "BOTTOM", 0, -WELCOME_LAYOUT.signGap)
    page.head:SetText(WELCOME)
    page.site = CreateFrame("Frame", nil, page)
    page.site:SetPoint("BOTTOM", window, "BOTTOM", 0, WELCOME_LAYOUT.footLine)
    page.site:SetHeight(WELCOME_LAYOUT.footLineH)
    local siteText = ns.Font(page.site, SMALL_SIZE + WELCOME_LAYOUT.siteTextGrow, nil, T.muted)
    siteText:SetPoint("LEFT")
    siteText:SetText(SITE_LINE)
    local siteLink = Parts.Link(page.site, ShowSite)
    Parts.SetLink(siteLink, SITE_LINK)
    siteLink:SetPoint("LEFT", siteText, "RIGHT", WELCOME_LAYOUT.siteGap, 0)
    page.site:SetWidth(math.ceil(siteText:GetStringWidth()) + WELCOME_LAYOUT.siteGap + siteLink:GetWidth())
    Corners(page)
    page.text = Text(page, BODY_SIZE, T.muted, WELCOME_LAYOUT.thanksW, "CENTER")
    page.text:SetPoint("TOP", page.head, "BOTTOM", 0, -WELCOME_LAYOUT.thanksGap)
    page.text:SetText(THANKS)
    local rowW = #PROMISES * WELCOME_LAYOUT.promiseW + (#PROMISES - 1) * WELCOME_LAYOUT.promiseGap
    for i, p in ipairs(PROMISES) do
        local tile = Panel(page)
        tile:SetSize(WELCOME_LAYOUT.promiseW, WELCOME_LAYOUT.promiseH)
        tile:SetPoint("TOPLEFT", page.text, "BOTTOM", -rowW / 2 + (i - 1) * (WELCOME_LAYOUT.promiseW + WELCOME_LAYOUT.promiseGap), -WELCOME_LAYOUT.promiseTop)
        local icon = Glyph(tile, WELCOME_LAYOUT.promisePlate, WELCOME_LAYOUT.promiseGlyph, p[3])
        Tint(icon.tex, T.accent)
        icon:SetPoint("LEFT", WELCOME_LAYOUT.promiseX, 0)
        local name = Text(tile, BODY_SIZE, T.fg, WELCOME_LAYOUT.promiseW - WELCOME_LAYOUT.promiseTextRoom)
        name:SetPoint("TOPLEFT", icon, "TOPRIGHT", WELCOME_LAYOUT.promiseTextGap, 0)
        name:SetText(p[1])
        local sub = Text(tile, SMALL_SIZE, T.muted, WELCOME_LAYOUT.promiseW - WELCOME_LAYOUT.promiseTextRoom)
        sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -WELCOME_LAYOUT.promiseSubGap)
        sub:SetText(p[2])
        page.last = tile
    end
    page.start = Arrow(ns.AccentBorder(ns.Button(page, START, START_W, START_H, function()
        step = STEP.profile
        Paint()
    end)), NEXT_ART, true)
    page.start:SetPoint("TOP", page.text, "BOTTOM", 0, -WELCOME_LAYOUT.promiseTop - WELCOME_LAYOUT.promiseH - WELCOME_LAYOUT.startGap)
    page.keep = Parts.Link(page, KeepAsItIs)
    Parts.SetLink(page.keep, KEEP)
    page.keep:SetPoint("TOP", page.start, "BOTTOM", 0, -WELCOME_LAYOUT.keepGap)
    return page
end

local function TileEnter(tile)
    tile.hovered = true
    SetLit(tile, tile.on, true)
end

local function TileLeave(tile)
    tile.hovered = false
    SetLit(tile, tile.on, false)
end

local function TileClick(tile)
    if not tile.onPick then return end
    tile.onPick(tile)
    Glow(tile)
    if tile.on then Pop(tile.check) end
end

local function Tile(page, i)
    local tile = page.tiles[i]
    if tile then return tile end
    tile = CreateFrame("Button", nil, page)
    ns.Solid(tile, "BACKGROUND", T.panel, PANEL_ALPHA):SetAllPoints()
    tile.lit = ns.Solid(tile, "BORDER", T.accent, LIT)
    tile.lit:SetAllPoints()
    tile.edge = ns.Border(tile, BLACK)
    tile.icon = Glyph(tile, ICON, GLYPH)
    tile.name = ns.Font(tile, BODY_SIZE, nil, T.fg)
    tile.blurb = ns.Font(tile, SMALL_SIZE, nil, T.muted)
    tile.check = CreateFrame("Frame", nil, tile)
    tile.check:SetSize(CHECK, CHECK)
    tile.check:SetPoint("TOPRIGHT", -TILE_LAYOUT.checkInset, -TILE_LAYOUT.checkInset)
    ns.Solid(tile.check, "BACKGROUND", T.accent, 1):SetAllPoints()
    local mark = tile.check:CreateTexture(nil, "ARTWORK")
    mark:SetTexture(CHECK_ART)
    mark:SetPoint("CENTER")
    mark:SetSize(CHECK - TILE_LAYOUT.markInset, CHECK - TILE_LAYOUT.markInset)
    tile:SetScript("OnEnter", TileEnter)
    tile:SetScript("OnLeave", TileLeave)
    tile:SetScript("OnClick", TileClick)
    page.tiles[i] = tile
    return tile
end

local function LayoutTile(tile, width)
    tile:SetSize(width, TILE_H)
    tile.name:SetJustifyH("CENTER")
    tile.blurb:SetJustifyH("CENTER")
    tile.icon:ClearAllPoints()
    tile.icon:SetPoint("TOP", 0, -TILE_LAYOUT.iconTop)
    tile.name:ClearAllPoints()
    tile.name:SetPoint("TOP", tile.icon, "BOTTOM", 0, -TILE_LAYOUT.nameGap)
    tile.name:SetWidth(width - TILE_LAYOUT.textRoom)
    tile.blurb:ClearAllPoints()
    tile.blurb:SetPoint("TOP", tile.name, "BOTTOM", 0, -TILE_LAYOUT.blurbGap)
    tile.blurb:SetWidth(width - TILE_LAYOUT.textRoom)
end

local function TileWidth(columns)
    return math.min(TILE_MAX_W, (WIDTH - INSET * 2 - (columns - 1) * TILE_GAP) / columns)
end

local function PaintTile(tile, on)
    tile.on = on
    local text = on and T.accent or T.fg
    tile.name:SetTextColor(text.r, text.g, text.b)
    Tint(tile.icon.tex, text)
    local plate = on and T.accent or BLACK
    tile.icon.edge:SetColor(plate.r, plate.g, plate.b, 1)
    tile.check:SetShown(on)
    SetLit(tile, on, tile.hovered)
end

local function UseMain()
    local who = newCharacter
    if Setup.ShareProfile(who.profile) then ns.Print(TEXT_CHOICE.sameDone:format(who.me, who.main)) end
    window:Hide()
end

local function SetUpOwn()
    if not Setup.OwnProfile(newCharacter.me) then return end
    ns.MarkAsked()
    Setup.ForCharacter(true)
    forCharacter = newCharacter.me
    picks = Setup.Fresh()
    step = STEP.profile
    Paint()
end

local function ChoiceTile(page, i, art, onPick)
    local tile = Tile(page, i)
    local width = TileWidth(CHOICE.columns)
    local rowW = CHOICE.columns * width + (CHOICE.columns - 1) * TILE_GAP
    LayoutTile(tile, width)
    tile:SetPoint("TOPLEFT", page.text, "BOTTOM", -rowW / 2 + (i - 1) * (width + TILE_GAP), -WELCOME_LAYOUT.promiseTop)
    tile.icon.tex:SetTexture(art, nil, nil, FILTER)
    tile.onPick = onPick
    PaintTile(tile, false)
    return tile
end

local function BuildChoice()
    local page = Page()
    Tagline(page)
    page.head = Text(page, HEAD_SIZE, T.fg, WIDTH - INSET * 2, "CENTER")
    page.head:SetPoint("TOP", page.sign, "BOTTOM", 0, -WELCOME_LAYOUT.signGap)
    page.text = Text(page, BODY_SIZE, T.muted, WELCOME_LAYOUT.thanksW, "CENTER")
    page.text:SetPoint("TOP", page.head, "BOTTOM", 0, -WELCOME_LAYOUT.thanksGap)
    page.tiles = {}
    page.same = ChoiceTile(page, 1, CHOICE.sameArt, UseMain)
    page.own = ChoiceTile(page, 2, CHOICE.ownArt, SetUpOwn)
    Corners(page)
    return page
end

local function PaintChoice()
    local page, me, main = window.choice, newCharacter.me, newCharacter.main
    page.head:SetText(TEXT_CHOICE.head:format(me))
    page.text:SetText(TEXT_CHOICE.text:format(main, main, me))
    page.same.name:SetText(TEXT_CHOICE.sameName:format(main))
    page.same.blurb:SetText(TEXT_CHOICE.sameBlurb:format(me, main))
    page.own.name:SetText(TEXT_CHOICE.ownName:format(me))
    page.own.blurb:SetText(TEXT_CHOICE.ownBlurb:format(me))
end

local function BuildStep(title)
    local page = Page()
    page.title = Text(page, TITLE_SIZE, T.fg, WIDTH - INSET * 2, "CENTER")
    page.title:SetText(title)
    page.hint = Text(page, BODY_SIZE, T.muted, WIDTH - INSET * 2, "CENTER")
    page.hint:SetPoint("TOP", page.title, "BOTTOM", 0, -TILE_LAYOUT.hintGap)
    page.tiles = {}
    return page
end

local function PlaceGrid(page, count, columns, width, height, gap)
    local rows = math.ceil(count / columns)
    local tilesH = rows * height + (rows - 1) * gap
    local headH = page.title:GetStringHeight() + TILE_LAYOUT.hintGap + page.hint:GetStringHeight() + HINT_GAP
    local top = math.max(INSET, math.floor((HEIGHT - HEADER - FOOT_H - headH - tilesH) / 2))
    page.title:ClearAllPoints()
    page.title:SetPoint("TOP", 0, -top)
    for i = 1, count do
        local tile = page.tiles[i]
        local row, col = math.floor((i - 1) / columns), (i - 1) % columns
        local inRow = math.min(columns, count - row * columns)
        local rowW = inRow * width + (inRow - 1) * gap
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", page, "TOPLEFT", (WIDTH - rowW) / 2 + col * (width + gap),
            -(top + headH + row * (height + gap)))
        tile:Show()
    end
    for i = count + 1, #page.tiles do page.tiles[i]:Hide() end
end

local function ProfileKeys()
    local keys = {}
    for i, key in ipairs(ns.PRESETS.order) do keys[i] = key end
    keys[#keys + 1] = Setup.KEEP
    return keys
end

local function PickProfile(tile)
    Setup.PickProfile(picks, tile.key)
    Paint()
end

local function BuildProfile()
    local page = BuildStep(TEXT_PROFILE.title)
    page.hint:SetText(TEXT_PROFILE.hint)
    local width = TileWidth(#ProfileKeys())
    for i, key in ipairs(ProfileKeys()) do
        local tile = Tile(page, i)
        LayoutTile(tile, width)
        local preset = ns.PRESETS[key]
        tile.key, tile.onPick = key, PickProfile
        tile.name:SetText(preset and preset.name or TEXT_PROFILE.keepName)
        tile.blurb:SetText(preset and ns.L(preset.about) or TEXT_PROFILE.keepBlurb)
        SetGlyph(tile.icon.tex, PROFILE_ICONS[key] or PROFILE_ICON_ANY)
    end
    return page
end

local function PaintProfile()
    local page = window.profile
    PlaceGrid(page, #page.tiles, #page.tiles, TileWidth(#page.tiles), TILE_H, TILE_GAP)
    for _, tile in ipairs(page.tiles) do PaintTile(tile, tile.key == picks.profile) end
end

local function Palette(skin)
    if skin == Setup.SKIN_CLASSIC then return ns.CLASSIC_PLUS end
    local out = {}
    for i, c in ipairs(ns.ThemePalette(ns.ThemePresetKey())) do out[ns.THEME_EDITABLE[i]] = c end
    return out
end

local function SkinLook(skin)
    local classic = skin == Setup.SKIN_CLASSIC
    local c = Palette(skin)
    return { colors = c, edge = classic and St.CLASSIC_GOLD_RGB or BLACK, title = classic and c.accent or c.fg,
        gameArt = classic, fill = { c.panel, c.panel }, rim = c.accent, label = classic and c.accent or c.fg,
        body = ns.AddonFontPath(classic), heading = ns.HeadingFontPath(classic) }
end

local function PreviewText(parent, path, size, color)
    local fs = ns.Font(parent, size, nil, color)
    fs:SetFont(path, size, "")
    return fs
end

local function PreviewButton(preview, look)
    local button = CreateFrame("Frame", nil, preview)
    button:SetSize(PREVIEW.buttonW, PREVIEW.buttonH)
    button:SetPoint("BOTTOMRIGHT", -PREVIEW.pad, PREVIEW.pad)
    if look.gameArt then
        ns.GameButtonArt(button)
    else
        local top, bottom = look.fill[1], look.fill[2]
        button.fill = ns.Solid(button, "BACKGROUND", WHITE, 1)
        button.fill:SetAllPoints()
        button.fill:SetGradient("VERTICAL", CreateColor(bottom.r, bottom.g, bottom.b, 1), CreateColor(top.r, top.g, top.b, 1))
        button.edge = ns.Border(button, look.rim)
    end
    button.label = PreviewText(button, look.heading, PREVIEW.labelSize, look.label)
    button.label:SetPoint("CENTER")
    button.label:SetText(TEXT_SKIN.previewButton)
    return button
end

local function Preview(tile, skin)
    local look = SkinLook(skin)
    local c = look.colors
    local preview = CreateFrame("Frame", nil, tile)
    preview:SetSize(PREVIEW.w, PREVIEW.h)
    preview.look = look
    preview.bg = ns.Solid(preview, "BACKGROUND", c.bg, 1)
    preview.bg:SetAllPoints()
    preview.edge = ns.Border(preview, look.edge)
    preview.bar = ns.Solid(preview, "BORDER", c.panel, 1)
    preview.bar:SetPoint("TOPLEFT")
    preview.bar:SetPoint("TOPRIGHT")
    preview.bar:SetHeight(PREVIEW.bar)
    preview.rule = ns.Solid(preview, "ARTWORK", c.line, 1)
    preview.rule:SetPoint("TOPLEFT", preview.bar, "BOTTOMLEFT")
    preview.rule:SetPoint("TOPRIGHT", preview.bar, "BOTTOMRIGHT")
    ns.Hairline(preview.rule, "h")
    preview.title = PreviewText(preview, look.heading, PREVIEW.titleSize, look.title)
    preview.title:SetPoint("LEFT", preview.bar, "LEFT", PREVIEW.pad, 0)
    preview.title:SetText(TEXT_SKIN.previewTitle)
    preview.body = PreviewText(preview, look.body, PREVIEW.bodySize, c.muted)
    preview.body:SetPoint("TOPLEFT", preview.bar, "BOTTOMLEFT", PREVIEW.pad, -PREVIEW.pad)
    preview.body:SetText(TEXT_SKIN.previewBody)
    preview.button = PreviewButton(preview, look)
    return preview
end

local function PickSkin(tile)
    picks.skin = tile.key
    Paint()
end

local function BuildSkin()
    local page = BuildStep(TEXT_SKIN.title)
    page.hint:SetText(TEXT_SKIN.hint)
    local width = TileWidth(SKIN_LAYOUT.columns)
    for i, skin in ipairs(Setup.SKINS) do
        local tile = Tile(page, i)
        tile:SetSize(width, SKIN_LAYOUT.tileH)
        tile.icon:Hide()
        tile.preview = Preview(tile, skin)
        tile.preview:SetPoint("TOP", 0, -TILE_LAYOUT.iconTop)
        tile.name:SetJustifyH("CENTER")
        tile.name:SetPoint("TOP", tile.preview, "BOTTOM", 0, -SKIN_LAYOUT.nameGap)
        tile.name:SetWidth(width - TILE_LAYOUT.textRoom)
        tile.blurb:SetJustifyH("CENTER")
        tile.blurb:SetPoint("TOP", tile.name, "BOTTOM", 0, -TILE_LAYOUT.blurbGap)
        tile.blurb:SetWidth(width - TILE_LAYOUT.textRoom)
        tile.key, tile.onPick = skin, PickSkin
        tile.name:SetText(SKIN_NAMES[skin])
        tile.blurb:SetText(SKIN_BLURBS[skin])
    end
    return page
end

local function PaintSkin()
    local page = window.skin
    PlaceGrid(page, #page.tiles, SKIN_LAYOUT.columns, TileWidth(SKIN_LAYOUT.columns), SKIN_LAYOUT.tileH, TILE_GAP)
    for _, tile in ipairs(page.tiles) do PaintTile(tile, tile.key == picks.skin) end
end

local function LayoutModuleTile(tile, width)
    tile:SetSize(width, MODULE_LAYOUT.tileH)
    tile.icon:SetSize(MODULE_LAYOUT.plate, MODULE_LAYOUT.plate)
    tile.icon.tex:SetSize(MODULE_LAYOUT.glyph, MODULE_LAYOUT.glyph)
    tile.icon:ClearAllPoints()
    tile.icon:SetPoint("LEFT", MODULE_LAYOUT.iconX, 0)
    local textW = width - MODULE_LAYOUT.iconX - MODULE_LAYOUT.plate - MODULE_LAYOUT.textGap - MODULE_LAYOUT.textRoom
    tile.name:SetJustifyH("LEFT")
    tile.name:ClearAllPoints()
    tile.name:SetPoint("TOPLEFT", tile.icon, "TOPRIGHT", MODULE_LAYOUT.textGap, 0)
    tile.name:SetWidth(textW)
    tile.blurb:SetJustifyH("LEFT")
    tile.blurb:ClearAllPoints()
    tile.blurb:SetPoint("TOPLEFT", tile.name, "BOTTOMLEFT", 0, -MODULE_LAYOUT.blurbGap)
    tile.blurb:SetWidth(textW)
end

local function FlipModule(tile)
    Setup.Toggle(picks, tile.key, not picks.modules[tile.key])
    Paint()
end

local function BuildModules()
    return BuildStep(TEXT_MODULES.title)
end

local function OnCount()
    local on = 0
    for _, m in ipairs(modules) do
        if picks.modules[m.id] then on = on + 1 end
    end
    return on
end

local function PaintModules()
    local page = window.modules
    page.hint:SetText(forCharacter and TEXT_MODULES.hintFor:format(forCharacter) or TEXT_MODULES.hint)
    local width = TileWidth(MODULE_LAYOUT.columns)
    for i, m in ipairs(modules) do
        local tile = Tile(page, i)
        LayoutModuleTile(tile, width)
        tile.key, tile.onPick = m.id, FlipModule
        tile.name:SetText(m.name)
        tile.blurb:SetText(m.blurb)
        tile.icon.tex:SetTexture(NAV_ICONS .. (m.navIcon or NAV_FALLBACK) .. ".tga", nil, nil, FILTER)
    end
    PlaceGrid(page, #modules, MODULE_LAYOUT.columns, width, MODULE_LAYOUT.tileH, MODULE_LAYOUT.gap)
    for i, m in ipairs(modules) do PaintTile(page.tiles[i], picks.modules[m.id] == true) end
    window.note:SetText(TEXT_MODULES.count:format(OnCount(), #modules))
end

local function SummaryRow(page, i)
    local row = Panel(page)
    row:SetWidth(SUMMARY_LAYOUT.w)
    row.icon = Glyph(row, SUMMARY_LAYOUT.plate, SUMMARY_LAYOUT.glyph)
    Tint(row.icon.tex, T.accent)
    row.icon:SetPoint("TOPLEFT", SUMMARY_LAYOUT.iconX, -SUMMARY_LAYOUT.iconX)
    row.name = Text(row, BODY_SIZE, T.fg, SUMMARY_LAYOUT.w - SUMMARY_LAYOUT.textRoom)
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", SUMMARY_LAYOUT.textGap, 0)
    row.value = Text(row, SMALL_SIZE, T.muted, SUMMARY_LAYOUT.w - SUMMARY_LAYOUT.textRoom)
    row.value:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -SUMMARY_LAYOUT.subGap)
    page.rows[i] = row
    return row
end

local function BuildSummary()
    local page = BuildStep(TEXT_SUMMARY.title)
    page.hint:SetText(TEXT_SUMMARY.hint)
    page.rows = {}
    for i = 1, SUMMARY_LAYOUT.rows do SummaryRow(page, i) end
    return page
end

local function SetRow(row, name, value, icon, color)
    row.name:SetText(name)
    row.value:SetText(value)
    local c = color or T.muted
    row.value:SetTextColor(c.r, c.g, c.b)
    SetGlyph(row.icon.tex, icon)
    row:SetHeight(math.max(SUMMARY_LAYOUT.rowH, row.name:GetStringHeight() + SUMMARY_LAYOUT.subGap
        + row.value:GetStringHeight() + SUMMARY_LAYOUT.pad))
    row:Show()
end

local function SkinLine()
    local name = SKIN_NAMES[plan.skin]
    if plan.skinChanged then return name end
    return TEXT_SUMMARY.sameSkin:format(name)
end

local function PaintSummary()
    local page = window.summary
    local rows = page.rows
    SetRow(rows[1], TEXT_SUMMARY.profile, plan.profile or TEXT_SUMMARY.stays,
        PROFILE_ICONS[picks.profile] or PROFILE_ICON_ANY, plan.profile and T.accent)
    SetRow(rows[2], TEXT_SUMMARY.skin, SkinLine(), SUMMARY_ICONS.skin, plan.skinChanged and T.accent)
    local shown = 2
    if #plan.on > 0 then
        shown = shown + 1
        SetRow(rows[shown], TEXT_SUMMARY.on, table.concat(plan.on, LIST_JOIN), SUMMARY_ICONS.on, T.accent)
    end
    if #plan.off > 0 then
        shown = shown + 1
        SetRow(rows[shown], TEXT_SUMMARY.off, table.concat(plan.off, LIST_JOIN), SUMMARY_ICONS.off, RED)
    end
    for i = shown + 1, #rows do rows[i]:Hide() end
    local headH = page.title:GetStringHeight() + TILE_LAYOUT.hintGap + page.hint:GetStringHeight() + HINT_GAP
    local rowsH = (shown - 1) * SUMMARY_LAYOUT.gap
    for i = 1, shown do rowsH = rowsH + rows[i]:GetHeight() end
    local top = math.max(INSET, math.floor((HEIGHT - HEADER - FOOT_H - headH - rowsH) / 2))
    page.title:ClearAllPoints()
    page.title:SetPoint("TOP", 0, -top)
    local y = top + headH
    for i = 1, shown do
        rows[i]:ClearAllPoints()
        rows[i]:SetPoint("TOP", page, "TOP", 0, -y)
        y = y + rows[i]:GetHeight() + SUMMARY_LAYOUT.gap
    end
    local combat = InCombatLockdown()
    window.next:SetAlpha(combat and DIM_ALPHA or 1)
    window.note:SetText(combat and IN_COMBAT or "")
end

local function PaintSegments()
    for i, seg in ipairs(window.segments) do
        local c = i < step and T.accent or i == step and T.accentSoft or T.line
        seg:SetColorTexture(c.r, c.g, c.b, 1)
        seg:SetShown(step >= STEP.profile and step <= STEP.count)
    end
end

local function PageOf(at)
    if at == STEP.choice then return window.choice end
    if at == STEP.welcome then return window.welcome end
    if at == STEP.profile then return window.profile end
    if at == STEP.skin then return window.skin end
    if at == STEP.modules then return window.modules end
    return window.summary
end

local PAINTERS = { [STEP.profile] = PaintProfile, [STEP.skin] = PaintSkin, [STEP.modules] = PaintModules,
    [STEP.summary] = PaintSummary }

function Paint()
    local page = PageOf(step)
    if step ~= window.painted then
        window.painted = step
        FadeIn(page)
    end
    for _, p in ipairs(window.pages) do p:SetShown(p == page) end
    window.foot:SetShown(step >= STEP.profile)
    PaintSegments()
    local last = step == STEP.summary
    window.next.arrow:SetTexture(last and CHECK_ART or NEXT_ART, nil, nil, FILTER)
    ns.SetButtonText(window.next, last and TEXT_APPLY or TEXT_NEXT)
    window.next:SetAlpha(1)
    window.note:SetText("")
    if step == STEP.choice then
        window.subtitle:SetText(WELCOME_SUB)
        PaintChoice()
    elseif step == STEP.welcome then
        window.subtitle:SetText(forCharacter and WELCOME_FOR:format(forCharacter) or WELCOME_SUB)
    else
        window.subtitle:SetText(STEP_OF:format(step, STEP.count))
        PAINTERS[step]()
    end
end

local function Apply()
    if InCombatLockdown() then return Paint() end
    plan = Setup.Plan(picks)
    if not plan.changes then return window:Hide() end
    local reload = Setup.Apply(picks)
    window:Hide()
    if reload then
        ns.ConfirmReload(DONE_RELOAD)
    else
        ns.Print(DONE)
    end
end

local function Next()
    if step == STEP.summary then return Apply() end
    step = step + 1
    if step == STEP.modules then modules = Setup.Modules() end
    if step == STEP.summary then plan = Setup.Plan(picks) end
    Paint()
end

local function Back()
    step = step - 1
    Paint()
end

local function OnCombat()
    if window:IsShown() and step == STEP.summary then Paint() end
end

local function BuildFoot()
    local foot = CreateFrame("Frame", nil, window)
    foot:SetPoint("BOTTOMLEFT")
    foot:SetPoint("BOTTOMRIGHT")
    foot:SetHeight(FOOT_H)
    local rule = Rule(foot)
    rule:SetPoint("TOPLEFT")
    rule:SetPoint("TOPRIGHT")
    window.back = Arrow(ns.Button(foot, TEXT_BACK, NAV_W, BUTTON_H, Back), BACK_ART)
    window.back:SetPoint("BOTTOMLEFT", EDGE, EDGE)
    window.next = Arrow(ns.AccentBorder(ns.Button(foot, TEXT_NEXT, APPLY_W, BUTTON_H, Next)), NEXT_ART, true)
    window.next:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
    window.note = ns.Font(foot, SMALL_SIZE, nil, T.muted)
    window.note:SetPoint("RIGHT", window.next, "LEFT", -FOOT_LAYOUT.noteGap, 0)
    window.foot = foot
end

local function Build()
    window = Parts.Window(WIDTH, HEIGHT, POSITION_KEY)
    window.backdrop:Paint(1)
    Parts.TitleBar(window, TITLE, "")
    window.logo:EnableMouse(false)
    window.logo.icon:SetAlpha(1)
    window.segments = {}
    for i = STEP.count, 1, -1 do
        local seg = window:CreateTexture(nil, "ARTWORK")
        seg:SetSize(SEG.w, SEG.h)
        local right = SEG.right + (STEP.count - i) * (SEG.w + SEG.gap)
        seg:SetPoint("RIGHT", window, "TOPRIGHT", -right, -HEADER / 2)
        window.segments[i] = seg
    end
    window.pages = {}
    window.choice = BuildChoice()
    window.welcome = BuildWelcome()
    window.profile = BuildProfile()
    window.skin = BuildSkin()
    window.modules = BuildModules()
    window.summary = BuildSummary()
    BuildFoot()
    window.events = CreateFrame("Frame")
    window.events:SetScript("OnEvent", OnCombat)
    window:HookScript("OnShow", function()
        window.events:RegisterEvent("PLAYER_REGEN_DISABLED")
        window.events:RegisterEvent("PLAYER_REGEN_ENABLED")
    end)
    window:HookScript("OnHide", Hidden)
end

local function Open(thisCharacter, first)
    ns.StashOptionsWindow()
    Setup.ForCharacter(thisCharacter)
    forCharacter = thisCharacter and UnitName("player") or nil
    if not window then Build() end
    window.painted = nil
    picks = Setup.Fresh()
    step = first
    Paint()
    window:Show()
end

function ns.ShowSetup(thisCharacter)
    Open(thisCharacter, STEP.welcome)
end

function ns.ShowNewCharacter(me, main, profile)
    newCharacter.me, newCharacter.main, newCharacter.profile = me, main, profile
    Open(nil, STEP.choice)
end

-- Credits.lua: the Credits page in the options window.
local ns = _G.NaowhForever
local T = ns.THEME

local GOLD = { r = 0xe6 / 255, g = 0xcc / 255, b = 0x80 / 255 }
local MEDIA = ns.MEDIA
local ICONS = MEDIA .. "Navigation\\"
local HERO_H, LOGO_SIZE, CARD_H, EMBLEM, ICON = 96, 64, 92, 52, 30
local PAD, GLOW, GLOW_ALPHA, STRIP = 16, 1.3, 0.35, 2
local CHIP_H, CHIP_GAP, CHIP_PAD = 24, 6, 10
local SECTION_GAP, TITLE_GAP = 14, 8
local HERO_TITLE_SIZE, HERO_LINE_SIZE, NAME_SIZE, ROLE_SIZE, LINE_SIZE, CHIP_TEXT_SIZE = 24, 12, 16, 10, 12, 11
local LINE_GAP, NAME_RISE, ROLE_GAP, ROLE_DROP = 6, 2, 8, 1
local HERO_EMBLEM, HERO_EMBLEM_STEP = 34, 40
local TEXT_LEFT = PAD + EMBLEM + PAD - NAME_RISE
local TEXT_NAOWH, TEXT_FOREVER = "Naowh ", "Forever"
local TEXT_VERSION = ns.L("Version %s, made by Naowh's team and the people who play it.")
local UNKNOWN_BUILD = "?"

local function Tier(key)
    return ns.BADGE_TIERS and ns.BADGE_TIERS[key]
end

local TEAM = {
    { tier = "naowh", name = "Naowh", role = "Founder", line = ns.L("The name on it, and the community it is made for.") },
    { tier = "developer", name = "Glyalith", role = "Lead Developer", line = ns.L("Builds and ships Naowh Forever.") },
    { tier = "developer", name = "Dieman", role = "Lead Developer", line = ns.L("Builds and ships Naowh Forever.") },
}

local THANKS = {
    { tier = "ellesmere", name = "Ellesmere", role = "EllesmereUI", line = ns.L("Creator of EllesmereUI, for allowing us to add some of EUI's styling and functionality.") },
    { tier = "moderator", name = ns.L("Moderators"), role = "Community", line = ns.L("Every moderator keeping the Naowh community running.") },
    { tier = "legendary", badges = true, name = ns.L("Legendary Supporters"), role = "Supporters", line = ns.L("Everyone wearing the Legendary badge: you keep Naowh Forever going.") },
    { tier = "epic", badges = true, name = ns.L("Epic Supporters"), role = "Supporters", line = ns.L("Everyone wearing the Epic badge: you keep Naowh Forever going too.") },
    { icon = "checklist", color = T.accentSoft, name = ns.L("Beta Testers"), role = "Community", line = ns.L("Every bug report and screenshot made it better.") },
}

local DATA = {
    { icon = "search", color = GOLD, name = "Wowhead", role = "Data", line = ns.L("WoW Forever's items, quests and NPCs, and what is new in Forever.") },
    { icon = "trophy", color = GOLD, name = "wowsrc.com", role = "Data", line = ns.L("The BiS rankings behind the BiS List.") },
    { icon = "bars", color = GOLD, name = "WoWSims", role = "Data", line = ns.L("The stat weights each spec starts with.") },
    { icon = "map", color = GOLD, name = "Santiago Reyes", role = "Maps", line = ns.L("For his maps of the new Forever dungeons.") },
    { icon = "map", color = GOLD, name = "tr0tsky", role = "Data", line = ns.L("Ley lines and Elemental Convergences behind Skyborne Spots, from the Skyborne Ley Line & Convergence Marker addon.") },
    { icon = "notes", color = GOLD, name = "12dicts and ENABLE", role = "Data", line = ns.L("Alan Beale's 12dicts and the ENABLE word list, the public-domain words behind the Daily Word.") },
}

local LIBRARIES = { "LibStub", "CallbackHandler-1.0", "LibDataBroker-1.1", "LibDBIcon-1.0", "LibSharedMedia-3.0",
    "LibCustomGlow-1.0", "LibDeflate", "LibSerialize" }

local SECTIONS = {
    { title = ns.L("The Team"), people = TEAM },
    { title = ns.L("Thank You"), people = THANKS },
    { title = ns.L("Built With"), people = DATA, chips = LIBRARIES },
}

local function Smooth(texture, path)
    texture:SetTexture(path, nil, nil, "TRILINEAR")
    texture:SetSnapToPixelGrid(false)
    texture:SetTexelSnappingBias(0)
    return texture
end

local function NewHero(view)
    local hero = CreateFrame("Frame", nil, view)
    local St = ns.Shared.Style
    ns.Solid(hero, "BACKGROUND", T.fg, St.WINDOW_CARD_FILL):SetAllPoints()
    ns.Border(hero, St.BORDER_RGB)
    hero.strip = ns.Solid(hero, "ARTWORK", T.accent, 1)
    hero.strip:SetPoint("TOPLEFT")
    hero.strip:SetPoint("TOPRIGHT")
    hero.strip:SetHeight(STRIP)
    hero.logo = Smooth(hero:CreateTexture(nil, "ARTWORK"), St.LOGO)
    hero.logo:SetSize(LOGO_SIZE, LOGO_SIZE)
    hero.logo:SetPoint("LEFT", PAD, 0)
    hero.title = ns.Font(hero, HERO_TITLE_SIZE, nil, T.fg)
    hero.title:SetPoint("TOPLEFT", hero.logo, "TOPRIGHT", PAD, -LINE_GAP)
    hero.line = ns.Font(hero, HERO_LINE_SIZE, nil, T.muted)
    hero.line:SetPoint("TOPLEFT", hero.title, "BOTTOMLEFT", 0, -LINE_GAP)
    hero.emblems = {}
    return hero
end

local HERO_TIERS = { "naowh", "developer", "moderator", "epic", "legendary" }

local function SetHero(hero)
    hero.title:SetText(TEXT_NAOWH .. ns.Color("accent", TEXT_FOREVER))
    hero.line:SetText(TEXT_VERSION:format(ns.CODE_BUILD or UNKNOWN_BUILD))
    local x = -PAD
    for i = #HERO_TIERS, 1, -1 do
        local tier = Tier(HERO_TIERS[i])
        local emblem = hero.emblems[i]
        if not emblem then
            emblem = hero:CreateTexture(nil, "ARTWORK")
            emblem:SetSize(HERO_EMBLEM, HERO_EMBLEM)
            hero.emblems[i] = emblem
        end
        emblem:SetShown(tier ~= nil)
        if tier then
            Smooth(emblem, tier.large)
            emblem:SetPoint("RIGHT", x, 0)
            x = x - HERO_EMBLEM_STEP
        end
    end
    return HERO_H
end

local function NewPerson(view)
    local card = CreateFrame("Frame", nil, view)
    local St = ns.Shared.Style
    ns.Solid(card, "BACKGROUND", T.fg, St.WINDOW_CARD_FILL):SetAllPoints()
    ns.Border(card, St.BORDER_RGB)
    card.strip = card:CreateTexture(nil, "ARTWORK")
    card.strip:SetPoint("TOPLEFT")
    card.strip:SetPoint("TOPRIGHT")
    card.strip:SetHeight(STRIP)
    card.glow = card:CreateTexture(nil, "BORDER")
    card.glow:SetBlendMode("ADD")
    card.art = card:CreateTexture(nil, "ARTWORK")
    card.art:SetPoint("CENTER", card, "LEFT", PAD + EMBLEM / 2, 0)
    card.glow:SetPoint("CENTER", card.art, "CENTER")
    card.name = ns.Font(card, NAME_SIZE, nil, T.fg)
    card.role = ns.Font(card, ROLE_SIZE, nil, T.muted)
    card.role:SetPoint("LEFT", card.name, "RIGHT", ROLE_GAP, -ROLE_DROP)
    card.line = ns.Font(card, LINE_SIZE, nil, T.muted)
    card.line:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -LINE_GAP)
    card.line:SetJustifyH("LEFT")
    card.line:SetWordWrap(true)
    return card
end

local roleText = {}

local function Upper(text)
    local upper = roleText[text]
    if not upper then
        upper = text:upper()
        roleText[text] = upper
    end
    return upper
end

local function SetPerson(card, person, width)
    local tier = person.tier and Tier(person.tier)
    local color = tier and tier.color or person.color or T.accentSoft
    card.strip:SetColorTexture(color.r, color.g, color.b, 1)
    if tier then
        card.art:SetSize(EMBLEM, EMBLEM)
        Smooth(card.art, tier.large)
        card.art:SetVertexColor(1, 1, 1, 1)
        card.glow:Show()
        card.glow:SetSize(EMBLEM * GLOW, EMBLEM * GLOW)
        Smooth(card.glow, tier.large)
        card.glow:SetVertexColor(color.r, color.g, color.b, GLOW_ALPHA)
    else
        card.art:SetSize(ICON, ICON)
        Smooth(card.art, ICONS .. person.icon .. ".tga")
        card.art:SetVertexColor(color.r, color.g, color.b, 1)
        card.glow:Hide()
    end
    card.name:SetText(person.name)
    card.name:SetTextColor(color.r, color.g, color.b, 1)
    card.role:SetText(Upper(person.role))
    card.line:SetWidth(math.max(1, width - TEXT_LEFT - PAD))
    card.line:SetText(person.line)
    local block = card.name:GetStringHeight() + LINE_GAP + card.line:GetStringHeight()
    card.name:ClearAllPoints()
    card.name:SetPoint("TOPLEFT", card, "LEFT", TEXT_LEFT, block / 2)
    return math.max(CARD_H, block + 2 * PAD)
end

local function NewChips(view)
    local row = CreateFrame("Frame", nil, view)
    row.chips = {}
    return row
end

local function Chip(row, i)
    local chip = row.chips[i]
    if not chip then
        chip = CreateFrame("Frame", nil, row)
        chip:SetHeight(CHIP_H)
        ns.Solid(chip, "BACKGROUND", T.panel, 1):SetAllPoints()
        ns.Border(chip, ns.Shared.Style.BORDER_RGB)
        chip.text = ns.Font(chip, CHIP_TEXT_SIZE, nil, T.fg)
        chip.text:SetPoint("CENTER")
        row.chips[i] = chip
    end
    return chip
end

local function SetChips(row, names)
    local width = row:GetWidth()
    local x, y = 0, 0
    for i, name in ipairs(names) do
        local chip = Chip(row, i)
        chip.text:SetText(name)
        local w = math.ceil(chip.text:GetStringWidth()) + CHIP_PAD * 2
        if x > 0 and x + w > width then
            x, y = 0, y + CHIP_H + CHIP_GAP
        end
        chip:SetWidth(w)
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", x, -y)
        chip:Show()
        x = x + w + CHIP_GAP
    end
    for i = #names + 1, #row.chips do row.chips[i]:Hide() end
    return y + CHIP_H
end

local kinds, view
local NO_EVENTS = {}

local Draw = {}

function Draw:DrawCard(person, _, _, _, x, w)
    self.left, self.width = x, w
    local card = self:Acquire("person")
    local height = SetPerson(card, person, w)
    self.left, self.width = 0, self:GetWidth()
    return card, height
end

function Draw:Redraw()
    self:Clear()
    self:Add("hero")
    self:Space(SECTION_GAP)
    for _, section in ipairs(SECTIONS) do
        self:Section(section.title)
        self:Space(TITLE_GAP)
        for _, person in ipairs(section.people) do
            if ns.FEATURE_BADGES == ns.BADGES_LIVE or not person.badges then self:Gather(person) end
        end
        self:DrawGrid()
        if section.chips then self:Add("chips", section.chips) end
        self:Space(SECTION_GAP)
    end
    self:Fit(NO_EVENTS)
end

local function Kinds()
    if kinds then return kinds end
    kinds = ns.Shared.View.NewKinds()
    kinds.hero = { New = NewHero, Set = SetHero }
    kinds.person = { New = NewPerson }
    kinds.chips = { New = NewChips, Set = SetChips }
    return kinds
end

function ns.BuildCreditsPage(parent, y)
    view = parent.creditsView
    if not view then
        view = ns.Shared.View.New(parent, Kinds(), Draw)
        parent.creditsView = view
    end
    view:ClearAllPoints()
    view:SetPoint("TOPLEFT", parent, "TOPLEFT", ns.UI.CONTENT_PAD, y - ns.UI.CONTENT_PAD / 2)
    view:SetWidth(math.max(1, parent:GetWidth() - ns.UI.CONTENT_PAD * 2))
    view:Show()
    view:Redraw()
    return y - view:GetHeight() - ns.UI.CONTENT_PAD
end

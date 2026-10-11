-- Book.lua: the overview tab: a card for each of your professions, with its skill and its next rank.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local C = P.C
local Style = P.Style
local Widgets = P.Widgets

local BOOK_TOP = -40
local PRIMARY_H, CARD_GAP = 128, 8
local SECONDARY_COLUMNS = 3
local PRIMARIES = 2
local NAME_X, NAME_DROP = 12, 10
local SECONDARY_NAME_DROP = 12
local BAR_X, BAR_DROP, BAR_RIGHT = 250, 52, 44
local SECONDARY_BAR_DROP = 38
local SECONDARY_BAR_ROOM = 24
local BAR_H = 18
local MISSING_DROP = 8
local MISSING_ROOM = 40
local STRIP_GAP = 6
local STRIP_H, SECONDARY_STRIP_H = 38, 50
local STRIP_LEVEL = 12
local STRIP_TEXT_X, STRIP_TEXT_DROP = 8, 7
local STRIP_SPACING = 2
local STRIP_PAD = 14
local BOOK_ORDER = { "PrimaryProfession1", "PrimaryProfession2", "SecondaryProfession1",
    "SecondaryProfession2", "SecondaryProfession3" }
local SECONDARY_NAMES = { PROFESSIONS_COOKING or "Cooking", PROFESSIONS_FISHING or "Fishing",
    PROFESSIONS_FIRST_AID or "First Aid" }
local TEXT_TITLE = TRADE_SKILLS or ns.L("Professions")
local TEXT_PRIMARY = PROFESSIONS_FIRST_PROFESSION or ns.L("Primary Profession")
local TEXT_NO_PRIMARY = PROFESSIONS_MISSING_PROFESSION or ns.L("Visit a profession trainer to learn one.")
local TEXT_NOT_LEARNED = ns.L("Not learned yet.")
local TEXT_READY = ns.L("%s%s|r is ready to learn.")
local TEXT_WHERE = "%s - %s %.1f, %.1f"
local TEXT_NO_TEACHER = ns.L("No teacher recorded for your faction.")
local TEXT_CLICK = ns.L("Click for a waypoint.|r")
local TEXT_WAYPOINT = ns.L("Click to set a waypoint.")
local TEXT_SKILL = "%d/%d%s"
local TEXT_BONUS = " (+%d)"
local TEXT_PRIMARY_STRIP = "%s %s\n%s%s|r%s"
local TEXT_SECONDARY_STRIP = "%s\n%s\n%s%s|r%s"

local win

local Book = {}
P.Book = Book
Book.ORDER = BOOK_ORDER

local function Where(npc)
    return TEXT_WHERE:format(npc[C.NPC_NAME], ns.RecipeFinder.ZoneName(npc[C.NPC_MAP]), npc[C.NPC_X], npc[C.NPC_Y])
end

function Book.RankLines(a)
    local npc = a.npc
    return TEXT_READY:format(ns.RecipeFinder.Hex(Style.GOLD_RGB), a.rankName), a.how .. ".",
        npc and Where(npc) or TEXT_NO_TEACHER
end

function Book.Where(npc)
    return Where(npc)
end

local function Indices()
    local prof1, prof2, firstAid, fishing, cooking = GetProfessions()
    return { prof1, prof2, cooking, fishing, firstAid }
end

local function OnStripClick(self)
    if self.alert then ns.ProfessionRank.Waypoint(self.alert.npc) end
end

local function OnStripEnter(self)
    local a = self.alert
    if not a then return end
    local gold = Style.GOLD_RGB
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(a.rankName, gold.r, gold.g, gold.b)
    GameTooltip:AddLine(a.how, 1, 1, 1, true)
    if a.npc then
        GameTooltip:AddLine(Where(a.npc), T.muted.r, T.muted.g, T.muted.b)
        GameTooltip:AddLine(TEXT_WAYPOINT, T.accent.r, T.accent.g, T.accent.b)
    end
    GameTooltip:Show()
end

local function BuildStrip(card, bar, primary)
    local strip = CreateFrame("Button", nil, card)
    strip:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -STRIP_GAP)
    strip:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -STRIP_GAP)
    strip:SetHeight(primary and STRIP_H or SECONDARY_STRIP_H)
    strip:SetFrameLevel(card:GetFrameLevel() + STRIP_LEVEL)
    ns.Solid(strip, "BACKGROUND", Style.GOLD_RGB, Style.BANNER_ALPHA):SetAllPoints()
    ns.Border(strip, Style.BORDER_RGB)
    strip.text = ns.Font(strip, Style.FONT, nil)
    strip.text:SetPoint("TOPLEFT", STRIP_TEXT_X, -STRIP_TEXT_DROP)
    strip.text:SetPoint("TOPRIGHT", -STRIP_TEXT_X, -STRIP_TEXT_DROP)
    strip.text:SetJustifyH(primary and "LEFT" or "CENTER")
    strip.text:SetWordWrap(true)
    strip.text:SetSpacing(STRIP_SPACING)
    strip:SetScript("OnClick", OnStripClick)
    strip:SetScript("OnEnter", OnStripEnter)
    strip:SetScript("OnLeave", GameTooltip_Hide)
    strip:Hide()
    return strip
end

local function PlaceCard(card, book, i, innerW, cardW)
    if card.primary then
        card:SetPoint("TOPLEFT", 0, -(i - 1) * (PRIMARY_H + CARD_GAP))
        card:SetSize(innerW, PRIMARY_H)
        return
    end
    local x = (i - PRIMARIES - 1) * (cardW + CARD_GAP)
    card:SetPoint("TOPLEFT", x, -PRIMARIES * (PRIMARY_H + CARD_GAP))
    card:SetPoint("BOTTOMLEFT", book, "BOTTOMLEFT", x, 0)
    card:SetWidth(cardW)
end

local function PlaceBar(card, bar, innerW, cardW)
    if card.primary then
        card.name:SetPoint("TOPLEFT", NAME_X, -NAME_DROP)
        bar:SetPoint("TOPLEFT", BAR_X, -BAR_DROP)
        bar:SetSize(innerW - BAR_X - BAR_RIGHT, BAR_H)
    else
        card.name:SetPoint("TOP", 0, -SECONDARY_NAME_DROP)
        bar:SetPoint("TOP", 0, -SECONDARY_BAR_DROP)
        bar:SetSize(cardW - SECONDARY_BAR_ROOM, BAR_H)
    end
end

local function BuildCard(book, i, innerW, cardW)
    local primary = i <= PRIMARIES
    local card = CreateFrame("Frame", nil, book)
    ns.Solid(card, "BACKGROUND", T.panel, Style.PANEL_ALPHA):SetAllPoints()
    ns.Border(card, Style.BORDER_RGB)
    card.primary = primary
    PlaceCard(card, book, i, innerW, cardW)
    card.name = ns.Font(card, Style.FONT_HEAD, nil, Style.GOLD_RGB)
    local bar = CreateFrame("StatusBar", nil, card)
    ns.Solid(bar, "BACKGROUND", T.bg, 1):SetAllPoints()
    Widgets.StyleBar(bar)
    PlaceBar(card, bar, innerW, cardW)
    card.bar = bar
    card.barText = ns.Font(bar, Style.FONT, "OUTLINE")
    card.barText:SetPoint("CENTER")
    card.missing = ns.Font(card, Style.FONT, nil, T.muted)
    card.missing:SetPoint("CENTER", 0, primary and -MISSING_DROP or 0)
    card.missing:SetWidth((primary and innerW or cardW) - MISSING_ROOM)
    card.missing:SetWordWrap(true)
    card.rankStrip = BuildStrip(card, bar, primary)
    return card
end

function Book.Build(frame)
    win = frame
    local book = CreateFrame("Frame", nil, win)
    book:SetPoint("TOPLEFT", Style.PAD, BOOK_TOP)
    book:SetPoint("BOTTOMRIGHT", -Style.PAD, Style.PAD)
    book:Hide()
    win.book = book
    local innerW = Style.WINDOW_W - Style.PAD * 2
    local cardW = (innerW - CARD_GAP * (SECONDARY_COLUMNS - 1)) / SECONDARY_COLUMNS
    book.cards = {}
    for i = 1, #BOOK_ORDER do book.cards[i] = BuildCard(book, i, innerW, cardW) end
end

local function RenderStrip(card, a)
    local strip = card.rankStrip
    strip.alert = a
    strip:SetShown(a ~= nil)
    if not a then return end
    local rank, how, where = Book.RankLines(a)
    local muted = ns.RecipeFinder.Hex(T.muted)
    local click = a.npc and (ns.RecipeFinder.Hex(T.accent) .. TEXT_CLICK)
    if card.primary then
        strip.text:SetText(TEXT_PRIMARY_STRIP:format(rank, how, muted, where, click and ("  " .. click) or ""))
    else
        strip.text:SetText(TEXT_SECONDARY_STRIP:format(rank, how, muted, where, click and ("\n" .. click) or ""))
    end
    strip:SetHeight(strip.text:GetStringHeight() + STRIP_PAD)
end

local function RenderLearned(card, index)
    local name, _, rank, maxRank, _, _, line, modifier = GetProfessionInfo(index)
    card.name:SetText(name)
    RenderStrip(card, ns.ProfessionRank and ns.ProfessionRank.For(line, rank, maxRank, name))
    card.bar:SetMinMaxValues(0, math.max(maxRank or 0, 1))
    card.bar:SetValue(rank or 0)
    card.barText:SetText(TEXT_SKILL:format(rank or 0, maxRank or 0,
        (modifier or 0) > 0 and TEXT_BONUS:format(modifier) or ""))
    card.bar:Show()
    card.missing:Hide()
end

local function RenderMissing(card, i)
    card.name:SetText(card.primary and TEXT_PRIMARY or SECONDARY_NAMES[i - PRIMARIES])
    card.missing:SetText(card.primary and TEXT_NO_PRIMARY or TEXT_NOT_LEARNED)
    card.bar:Hide()
    card.missing:Show()
    card.rankStrip:Hide()
end

function Book.Render()
    win.title:SetText(TEXT_TITLE)
    local indices = Indices()
    for i, card in ipairs(win.book.cards) do
        local index = indices[i]
        if index then
            RenderLearned(card, index)
        else
            RenderMissing(card, i)
        end
    end
end

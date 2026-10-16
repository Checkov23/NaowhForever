-- Rows.lua: what the planner's pages are drawn from: pooled cards, rows and section titles, and a spell's clicks.
local ns = _G.NaowhForever

local T = ns.THEME

local Training = ns.Training
local Style = Training.Style

local LEVEL, SPELL = Training.C.ENTRY_LEVEL, Training.C.ENTRY_SPELL
local SHADOW_X, SHADOW_Y = 1, -1
local ICON_EDGE = 1
local COLS = 3
local CARD_H, CARD_GAP, CARD_ICON = 58, 10, 36
local CARD_ICON_X, CARD_TEXT_GAP = 10, 10
local CARD_NAME_DROP, CARD_NAME_ROOM = 2, 60
local CARD_RANK_LIFT = 2
local CARD_PRICE_EDGE = 10
local SKIP_EDGE = 8
local ROW_ICON_X, ROW_TEXT_GAP = 5, 8
local ROW_PRICE_EDGE = 8
local WHY_GAP, RESTORE_GAP = 16, 12
local RESTORE_W, RESTORE_H = 64, 20
local TITLE_LIFT = 5
local LATER_ICON, LATER_ICONS = 20, 5
local LATER_ICON_GAP = 4
local LATER_LEVEL_X, LATER_LEVEL_W = 10, 70
local LATER_NAMES_GAP, LATER_PRICE_GAP = 8, 12
local FONT_SMALL, FONT, FONT_ROW, FONT_CARD = Style.FONT_SMALL, Style.FONT, Style.FONT_ROW, 14
local COUNT_GAP = "   "
local TEXT_SKIP, TEXT_RESTORE = ns.L("Skip"), ns.L("Restore")
local TEXT_LEARNED = ns.L("Learned")
local TEXT_QUEST = ns.L("Quest")
local TEXT_AT_TRAINER = ns.L("At the trainer")
local TEXT_RANK_FIRST = ns.L("Learn %s (%s) first.")
local TEXT_NEEDS_TALENT = ns.L("Needs the talent %s.")
local TEXT_TRAINABLE = ns.L("Trainable at level %d.")
local TEXT_BY_BUILD = ns.L("Skipped by the build you follow.")
local TEXT_YOUR_BUILD = ns.L("Your build")
local TEXT_BY_QUEST = ns.L("Taught by a quest, not a trainer.")
local TEXT_OVER = ns.L("Over %s: %s %s to %s, +%d%%")
local TEXT_RANK_BEFORE = ns.L("the rank before")
local TEXT_HINT = ns.L("Shift-click to link it. Right-click to skip it.")
local TEXT_HINT_WEAPON = ns.L("Shift-click to link it. Click for a waypoint to where it is taught.")
local TEXT_BY_MASTER = ns.L("Taught by a weapon master: %s.")
local TEXT_BY_CLASS = ns.L("Taught by your class trainer.")
local TEXT_SPELL = ns.L("Spell ")
local TEXT_STOP_SKIP, TEXT_STOP_SKIP_ALL = ns.L("Stop Skipping"), ns.L("Stop Skipping All Ranks")
local TEXT_SKIP_ALL = ns.L("Skip All Ranks")
local TEXT_UPGRADE = "  %s+%d%%|r"

local V = { tab = "spells", buildIndex = 1, paneX = 0, editing = false, editTab = "talents" }
Training.View = V

local pools = {}
local listed = 0

local Rows = {}
Training.Rows = Rows

function Rows.Take(kind, make)
    local pool = pools[kind]
    if not pool then
        pool = { list = {}, used = 0 }
        pools[kind] = pool
    end
    pool.used = pool.used + 1
    local f = pool.list[pool.used]
    if not f then
        f = make()
        pool.list[pool.used] = f
    end
    f:ClearAllPoints()
    f:Show()
    return f
end

function Rows.ReleaseAll()
    for _, pool in pairs(pools) do
        for i = 1, #pool.list do pool.list[i]:Hide() end
        pool.used = 0
    end
end

function Rows.Paint(fs, c)
    fs:SetTextColor(c.r, c.g, c.b, 1)
end

function Rows.Text(parent, size, flags, color)
    local fs = ns.Font(parent, size, flags, color)
    fs:SetShadowOffset(SHADOW_X, SHADOW_Y)
    fs:SetShadowColor(0, 0, 0, Style.SHADOW_ALPHA)
    return fs
end

function Rows.Crop(texture)
    texture:SetTexCoord(Style.ICON_CROP, Style.ICON_CROP_HIGH, Style.ICON_CROP, Style.ICON_CROP_HIGH)
    return texture
end

function Rows.Icon(parent, size)
    local edge = parent:CreateTexture(nil, "BORDER")
    local black = Style.BORDER_RGB
    edge:SetColorTexture(black.r, black.g, black.b, 1)
    edge:SetSize(size + 2 * ICON_EDGE, size + 2 * ICON_EDGE)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    ns.PixelInset(icon, ICON_EDGE, edge)
    Rows.Crop(icon)
    icon.edge = edge
    return icon
end

local Text, Paint, Take, Icon = Rows.Text, Rows.Paint, Rows.Take, Rows.Icon

local function FromBuild(spell)
    return Training.BuildSkipped(spell) and not Training.Ignored()[spell]
end

local function Reason(entry, state)
    if state == "ignored" and FromBuild(entry[SPELL]) then
        return TEXT_BY_BUILD
    elseif state == "rank" then
        return TEXT_RANK_FIRST:format(C_Spell.GetSpellName(entry.needs) or "", C_Spell.GetSpellSubtext(entry.needs) or "")
    elseif state == "talent" then
        return TEXT_NEEDS_TALENT:format(C_Spell.GetSpellName(entry.talent) or "")
    elseif state == "weapon" then
        return entry.masters and TEXT_BY_MASTER:format(table.concat(entry.masters, ", ")) or TEXT_BY_CLASS
    elseif state == "soon" or state == "later" then
        return TEXT_TRAINABLE:format(entry[LEVEL])
    elseif entry.quest then
        return TEXT_BY_QUEST
    end
end

function Rows.UpgradeTag(entry)
    local up = Training.Upgrade(entry)
    return up and TEXT_UPGRADE:format(Style.UP_CODE, up.pct) or ""
end

local function SpellEnter(self)
    if self.band then
        self.band:SetAlpha(Style.HOVER)
    else
        self.border:SetColor(T.accent.r, T.accent.g, T.accent.b, 1)
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(self.entry[SPELL])
    local up = Training.Upgrade(self.entry)
    if up then
        local before = self.entry.needs or self.entry.talent
        local c = Style.UP_RGB
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(TEXT_OVER:format(C_Spell.GetSpellSubtext(before) or TEXT_RANK_BEFORE,
            up.what, up.from, up.to, up.pct), c.r, c.g, c.b, true)
    end
    local reason = Reason(self.entry, self.state)
    if reason then
        local c = Style.WARN_RGB
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(reason, c.r, c.g, c.b, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(self.state == "weapon" and TEXT_HINT_WEAPON or TEXT_HINT, T.muted.r, T.muted.g, T.muted.b, true)
    GameTooltip:Show()
end

local function SpellLeave(self)
    if self.band then
        self.band:SetAlpha(0)
    else
        local c = Style.BORDER_RGB
        self.border:SetColor(c.r, c.g, c.b, 1)
    end
    GameTooltip:Hide()
end

local function SkipMenu(spell, skipped)
    return function(_, root)
        root:CreateTitle(C_Spell.GetSpellName(spell) or (TEXT_SPELL .. spell))
        if skipped then
            root:CreateButton(TEXT_STOP_SKIP, function() Training.SetIgnored(spell, false, false) end)
            root:CreateButton(TEXT_STOP_SKIP_ALL, function() Training.SetIgnored(spell, true, false) end)
        else
            root:CreateButton(TEXT_SKIP, function() Training.SetIgnored(spell, false, true) end)
            root:CreateButton(TEXT_SKIP_ALL, function() Training.SetIgnored(spell, true, true) end)
        end
    end
end

local function SpellClick(self, button)
    local spell = self.entry[SPELL]
    if button == "RightButton" then
        if self.state == "weapon" or self.state == "ignored" and FromBuild(spell) then return end
        MenuUtil.CreateContextMenu(self, SkipMenu(spell, self.state == "ignored"))
    elseif IsModifiedClick("CHATLINK") then
        ChatFrameUtil.InsertLink(C_Spell.GetSpellLink(spell))
    elseif self.state == "weapon" then
        Training.WaypointToMaster(self.entry)
    end
end

local function PriceText(entry)
    local price = Training.Price(entry)
    if price > 0 then return Training.Coins(price) end
    if entry.quest then return ns.Color("muted", TEXT_QUEST) end
    return ns.Color("muted", TEXT_AT_TRAINER)
end

function Rows.ListRow(b)
    b.stripe = ns.Solid(b, "BACKGROUND", T.fg, Style.STRIPE)
    b.stripe:SetAllPoints()
    b.band = ns.Solid(b, "BACKGROUND", T.fg, 1)
    b.band:SetAllPoints()
    b.band:SetAlpha(0)
end

function Rows.Stripe(row)
    listed = listed + 1
    row.stripe:SetShown(listed % 2 == 0)
end

local function SpellButton(height, list, parent)
    local b = CreateFrame("Button", nil, parent or V.body)
    b:SetHeight(height)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if list then
        Rows.ListRow(b)
    else
        b.bg = ns.Solid(b, "BACKGROUND", T.fg, Style.WINDOW_CARD_FILL)
        b.bg:SetAllPoints()
        b.border = ns.Border(b, Style.BORDER_RGB)
    end
    b:SetScript("OnEnter", SpellEnter)
    b:SetScript("OnLeave", SpellLeave)
    b:SetScript("OnClick", SpellClick)
    return b
end

local function NewCard()
    local c = SpellButton(CARD_H)
    c.icon = Icon(c, CARD_ICON)
    c.icon.edge:SetPoint("LEFT", CARD_ICON_X, 0)
    c.name = Text(c, FONT_CARD, nil)
    c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", CARD_TEXT_GAP, -CARD_NAME_DROP)
    c.name:SetPoint("RIGHT", -CARD_NAME_ROOM, 0)
    c.name:SetJustifyH("LEFT")
    c.name:SetWordWrap(false)
    c.rank = Text(c, FONT, nil, T.muted)
    c.rank:SetPoint("BOTTOMLEFT", c.icon, "BOTTOMRIGHT", CARD_TEXT_GAP, CARD_RANK_LIFT)
    c.price = Text(c, FONT_ROW, nil)
    c.price:SetPoint("TOPRIGHT", -CARD_PRICE_EDGE, -CARD_PRICE_EDGE)
    c.skip = ns.Button(c, TEXT_SKIP, Style.SKIP_W, Style.SKIP_H)
    c.skip:SetPoint("BOTTOMRIGHT", -SKIP_EDGE, SKIP_EDGE)
    return c
end

local function Card(entry, state, x, y, w)
    local c = Take("card", NewCard)
    c:SetPoint("TOPLEFT", V.body, "TOPLEFT", x, y)
    c:SetWidth(w)
    c.entry, c.state = entry, state
    local learned = state == "learned"
    c.icon:SetTexture(C_Spell.GetSpellTexture(entry[SPELL]))
    c.icon:SetDesaturated(state ~= "now")
    c.name:SetText(C_Spell.GetSpellName(entry[SPELL]) or "")
    c.rank:SetText(learned and TEXT_LEARNED or ((C_Spell.GetSpellSubtext(entry[SPELL]) or "") .. Rows.UpgradeTag(entry)))
    c.price:SetText(PriceText(entry))
    c:SetAlpha(learned and Style.LEARNED_ALPHA or 1)
    c.skip:SetShown(state == "now")
    c.skip._onClick = function() Training.SetIgnored(entry[SPELL], false, true) end
    return c
end

function Rows.NewRow(parent)
    local r = SpellButton(Style.ROW_H, true, parent)
    r.icon = Icon(r, Style.ROW_ICON)
    r.icon.edge:SetPoint("LEFT", ROW_ICON_X, 0)
    r.name = Text(r, FONT_ROW, nil)
    r.name:SetPoint("LEFT", r.icon, "RIGHT", ROW_TEXT_GAP, 0)
    r.rank = Text(r, FONT, nil, T.muted)
    r.rank:SetPoint("LEFT", r.name, "RIGHT", ROW_TEXT_GAP, 0)
    r.price = Text(r, FONT_ROW, nil)
    r.price:SetPoint("RIGHT", -ROW_PRICE_EDGE, 0)
    r.why = Text(r, FONT, nil, Style.WARN_RGB)
    r.why:SetPoint("RIGHT", r.price, "LEFT", -WHY_GAP, 0)
    r.restore = ns.Button(r, TEXT_RESTORE, RESTORE_W, RESTORE_H)
    r.restore:SetPoint("RIGHT", r.price, "LEFT", -RESTORE_GAP, 0)
    return r
end

function Rows.FillRow(r, entry, state, why)
    r.entry, r.state = entry, state
    r.icon:SetTexture(C_Spell.GetSpellTexture(entry[SPELL]))
    r.icon:SetDesaturated(true)
    r.name:SetText(C_Spell.GetSpellName(entry[SPELL]) or "")
    r.rank:SetText((C_Spell.GetSpellSubtext(entry[SPELL]) or "") .. (state == "learned" and "" or Rows.UpgradeTag(entry)))
    r.price:SetText(PriceText(entry))
    local fromBuild = state == "ignored" and FromBuild(entry[SPELL])
    r.why:SetText(fromBuild and TEXT_YOUR_BUILD or why or "")
    Paint(r.why, (state == "rank" or state == "talent") and Style.WARN_RGB or T.muted)
    r.why:SetShown(state ~= "ignored" or fromBuild)
    r.restore:SetShown(state == "ignored" and not fromBuild)
    r.restore._onClick = function() Training.SetIgnored(entry[SPELL], false, false) end
end

function Rows.Row(entry, state, y, why)
    local r = Take("row", Rows.NewRow)
    r:SetPoint("TOPLEFT", V.body, "TOPLEFT", 0, y)
    r:SetPoint("TOPRIGHT", V.body, "TOPRIGHT", 0, y)
    Rows.FillRow(r, entry, state, why)
    Rows.Stripe(r)
    return y - Style.ROW_H
end

function Rows.NewHeader(parent)
    local h = CreateFrame("Frame", nil, parent or V.body)
    h:SetHeight(Style.SECTION_H)
    h.title = Text(h, FONT, nil, T.accentSoft)
    h.title:SetPoint("BOTTOMLEFT", 0, TITLE_LIFT)
    h.note = Text(h, FONT_SMALL, nil, T.muted)
    h.note:SetPoint("BOTTOMRIGHT", 0, TITLE_LIFT)
    local rule = ns.Solid(h, "ARTWORK", T.line, 1)
    rule:SetPoint("BOTTOMLEFT")
    rule:SetPoint("BOTTOMRIGHT")
    ns.Hairline(rule, "h")
    return h
end

function Rows.FillHeader(h, title, count, note)
    h.title:SetText(title .. (count and (COUNT_GAP .. ns.Color("muted", count)) or ""))
    h.note:SetText(note or "")
end

function Rows.Header(y, title, count, note)
    local h = Take("header", Rows.NewHeader)
    h:SetPoint("TOPLEFT", V.body, "TOPLEFT", V.paneX, y)
    h:SetPoint("TOPRIGHT", V.body, "TOPRIGHT", 0, y)
    Rows.FillHeader(h, title, count, note)
    listed = 0
    return y - Style.SECTION_H - Style.SECTION_SPACE
end

function Rows.Cards(entries, y, stateOf)
    local w = math.floor((V.body:GetWidth() - (COLS - 1) * CARD_GAP) / COLS)
    for i, entry in ipairs(entries) do
        local col, line = (i - 1) % COLS, math.floor((i - 1) / COLS)
        Card(entry, stateOf(entry), col * (w + CARD_GAP), y - line * (CARD_H + CARD_GAP), w)
    end
    return y - math.ceil(#entries / COLS) * (CARD_H + CARD_GAP)
end

local function LaterEnter(self)
    self.band:SetAlpha(Style.HOVER)
end

local function LaterLeave(self)
    self.band:SetAlpha(0)
end

function Rows.NewLater()
    local b = CreateFrame("Button", nil, V.body)
    b:SetHeight(Style.ROW_H)
    Rows.ListRow(b)
    b.level = Text(b, FONT_ROW, nil)
    b.level:SetPoint("LEFT", LATER_LEVEL_X, 0)
    b.level:SetWidth(LATER_LEVEL_W)
    b.level:SetJustifyH("LEFT")
    b.price = Text(b, FONT_ROW, nil)
    b.price:SetPoint("RIGHT", -ROW_PRICE_EDGE, 0)
    b.icons = {}
    for i = 1, LATER_ICONS do
        local icon = Icon(b, LATER_ICON)
        icon.edge:SetPoint("LEFT", b.level, "RIGHT", (i - 1) * (LATER_ICON + LATER_ICON_GAP), 0)
        b.icons[i] = icon
    end
    b.names = Text(b, FONT, nil, T.muted)
    b.names:SetPoint("LEFT", b.level, "RIGHT", LATER_ICONS * (LATER_ICON + LATER_ICON_GAP) + LATER_NAMES_GAP, 0)
    b.names:SetPoint("RIGHT", b.price, "LEFT", -LATER_PRICE_GAP, 0)
    b.names:SetJustifyH("LEFT")
    b.names:SetWordWrap(false)
    b:SetScript("OnEnter", LaterEnter)
    b:SetScript("OnLeave", LaterLeave)
    return b
end

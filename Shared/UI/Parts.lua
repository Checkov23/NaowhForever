-- Parts.lua: the small parts a page is made of (ns.Shared.Parts): icons in text, smooth textures, hover cards, the chevron, links and back links, icon buttons, the flat hover and pressed look for a bar button, pills, the worn bar and the Wowhead copy card.
local ns = _G.NaowhForever
local T = ns.THEME
local Shared = ns.Shared
local Parts = Shared.Parts
local St = Shared.Style

local ACTION, ARROW, HAVE_RGB = St.ACTION, St.ARROW, St.HAVE_RGB
local INLINE_ICON = "|T%s:0:0:0:%d:64:64:0:64:0:64:%d:%d:%d|t"
local COLOR_SCALE = 255
local LINK_H, LINK_SIZE = 18, St.TEXT_SIZE
local LINK_ARROW, LINK_ARROW_OUT, LINK_ARROW_ROOM = 10, 2, 12
local UNDERLINE_DROP = 1
local PILL_PAD, PILL_FILL = 4, St.TAB_FILL
local WORN_W, WORN_OUT, WORN_END = 2, 2, 4
local TIP_TITLE = 1
local ID_LABELS = { item = ns.L("Item ID"), spell = ns.L("Spell ID"), quest = ns.L("Quest ID"), npc = ns.L("NPC ID"), object = ns.L("Object ID") }
local TEXT_ID = ns.L("ID")
local COPY_FIELD = "url"
local HOVER_ALPHA, PUSHED_ALPHA = 0.15, 0.35
local FLAT_BLEND = "BLEND"
local PUSHED_LAYER, PUSHED_SUBLEVEL = "ARTWORK", 1

local function Tip(owner, anchor, x, y)
    if Menu.GetManager():IsAnyMenuOpen() then return false end
    GameTooltip:SetOwner(owner, anchor, x, y)
    return true
end

local function TipLines(owner, anchor, title, line)
    if not Parts.Tip(owner, anchor) then return false end
    GameTooltip:SetText(ns.L(title), TIP_TITLE, TIP_TITLE, TIP_TITLE)
    if line then GameTooltip:AddLine(ns.L(line), T.muted.r, T.muted.g, T.muted.b, true) end
    GameTooltip:Show()
    return true
end

local function Smooth(texture, path)
    if path then texture:SetTexture(path, nil, nil, "TRILINEAR") end
    texture:SetSnapToPixelGrid(false)
    texture:SetTexelSnappingBias(0)
    return texture
end

local function Arrow(parent, size, color)
    local arrow = parent:CreateTexture(nil, "ARTWORK")
    arrow:SetTexture(ARROW)
    arrow:SetSize(size, size)
    arrow:SetVertexColor(color.r, color.g, color.b)
    return arrow
end

local function LinkColor(link, color)
    link.text:SetTextColor(color.r, color.g, color.b)
    if link.arrow then link.arrow:SetVertexColor(color.r, color.g, color.b) end
end

local function LinkEnter(link)
    if link.tip and not TipLines(link, "ANCHOR_TOP", link.tip, link.tipLine) then return end
    if link.disabled then return end
    LinkColor(link, T.fg)
    link.underline:Show()
end

local function LinkLeave(link)
    if link.tip then GameTooltip:Hide() end
    LinkColor(link, link.disabled and T.muted or T.accentSoft)
    link.underline:Hide()
end

local function IconColor(button, color)
    button.icon:SetVertexColor(color.r, color.g, color.b)
    if button.label then button.label:SetTextColor(color.r, color.g, color.b) end
end

local function IconEnter(button)
    IconColor(button, T.fg)
    if not Tip(button, "ANCHOR_TOP") then return end
    GameTooltip:SetText(ns.L(button.tip))
    if button.hint then GameTooltip:AddLine(ns.L(button.hint), T.accentSoft.r, T.accentSoft.g, T.accentSoft.b) end
    GameTooltip:Show()
end

local function IconLeave(button)
    IconColor(button, T.accentSoft)
    GameTooltip:Hide()
end

Parts.TOOLTIP_DROP = 1
Parts.CARD_DROP = 0
Parts.Tip = Tip
Parts.TipLines = TipLines
Parts.Smooth = Smooth
Parts.Arrow = Arrow
Parts.LinkColor = LinkColor

function Parts.Inline(texture, color, drop)
    return INLINE_ICON:format(texture, -(drop or Parts.TOOLTIP_DROP),
        color.r * COLOR_SCALE, color.g * COLOR_SCALE, color.b * COLOR_SCALE)
end

local function SyncPushed(button, _, down)
    button:SetButtonState(down and "PUSHED" or "NORMAL")
end

local function Flat(texture, colour, alpha)
    texture:SetColorTexture(colour.r, colour.g, colour.b, alpha)
    texture:SetBlendMode(FLAT_BLEND)
    ns.PixelInset(texture, 1)
end

function Parts.Hover(button)
    local hover = button:GetHighlightTexture()
    if not hover then
        hover = ns.Solid(button, "HIGHLIGHT")
        button:SetHighlightTexture(hover)
    end
    Flat(hover, T.fg, HOVER_ALPHA)
    local pushed = button:GetPushedTexture()
    if pushed then Flat(pushed, St.BORDER_RGB, PUSHED_ALPHA) end
end

function Parts.Press(button)
    button:SetPushedTexture(ns.Solid(button, PUSHED_LAYER))
    button:GetPushedTexture():SetDrawLayer(PUSHED_LAYER, PUSHED_SUBLEVEL)
    Parts.Hover(button)
    button:HookScript("OnClick", SyncPushed)
end

function Parts.Link(parent, onClick, arrow)
    local link = CreateFrame("Button", nil, parent)
    link:SetHeight(LINK_H)
    link.text = ns.Font(link, LINK_SIZE, nil, T.accentSoft)
    if arrow then
        link.arrow = Arrow(link, LINK_ARROW, T.accentSoft)
        link.arrow:SetPoint("RIGHT", LINK_ARROW_OUT, 0)
        link.text:SetPoint("RIGHT", link.arrow, "LEFT", 0, 0)
    else
        link.text:SetPoint("RIGHT")
    end
    link.underline = ns.Solid(link, "ARTWORK", T.fg, 1)
    link.underline:SetPoint("TOPLEFT", link.text, "BOTTOMLEFT", 0, -UNDERLINE_DROP)
    link.underline:SetPoint("TOPRIGHT", link.text, "BOTTOMRIGHT", 0, -UNDERLINE_DROP)
    ns.Hairline(link.underline, "h")
    link.underline:Hide()
    link:SetScript("OnClick", onClick)
    link:SetScript("OnEnter", LinkEnter)
    link:SetScript("OnLeave", LinkLeave)
    return link
end

function Parts.SetLink(link, text)
    link.text:SetText(ns.L(text))
    link:SetWidth(math.ceil(link.text:GetStringWidth()) + (link.arrow and LINK_ARROW_ROOM or 0))
end

function Parts.FlipLink(link)
    if not link.arrow then return end
    link.arrow:ClearAllPoints()
    link.arrow:SetPoint("LEFT", -LINK_ARROW_OUT, 0)
    link.arrow:SetRotation(math.pi)
    link.text:ClearAllPoints()
    link.text:SetPoint("LEFT", link.arrow, "RIGHT", 0, 0)
end

function Parts.IconButton(parent, onClick, texture, margin, tip)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(ACTION, ACTION)
    button.icon = Smooth(button:CreateTexture(nil, "ARTWORK"), texture)
    button.icon:SetSize(ACTION, ACTION)
    button.icon:SetPoint("RIGHT", margin or 0, 0)
    button.icon:SetVertexColor(T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    button.tip = tip
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", IconEnter)
    button:SetScript("OnLeave", IconLeave)
    return button
end

function Parts.Pill(parent, size, color)
    local pill = CreateFrame("Frame", nil, parent)
    pill.fill = ns.Solid(pill, "BACKGROUND", color, PILL_FILL)
    pill.fill:SetAllPoints()
    pill.edge = ns.Border(pill, color)
    pill.text = ns.Font(pill, size, nil, color)
    pill.text:SetPoint("CENTER")
    pill:SetHeight(size + PILL_PAD)
    return pill
end

function Parts.ColorPill(pill, color)
    if pill.color == color then return end
    pill.color = color
    pill.fill:SetColorTexture(color.r, color.g, color.b, PILL_FILL)
    pill.edge:SetColor(color.r, color.g, color.b)
    pill.text:SetTextColor(color.r, color.g, color.b)
end

function Parts.SetPill(pill, text)
    pill.text:SetText(ns.L(text))
    pill:SetWidth(math.ceil(pill.text:GetStringWidth()) + 2 * PILL_PAD)
    return pill:GetWidth()
end

function Parts.WornBar(row, inset)
    local bar = ns.Solid(row, "ARTWORK", HAVE_RGB, 1)
    bar:SetPoint("TOPLEFT", -inset + WORN_OUT, -WORN_END)
    bar:SetPoint("BOTTOMLEFT", -inset + WORN_OUT, WORN_END)
    bar:SetWidth(WORN_W)
    bar:Hide()
    return bar
end

function Parts.CopyWowhead(kind, id, name)
    ns.ShowCopyCard(kind, ID_LABELS[kind] or TEXT_ID, id, name, COPY_FIELD)
end

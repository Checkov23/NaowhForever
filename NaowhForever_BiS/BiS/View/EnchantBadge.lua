-- EnchantBadge.lua: the enchant dot on a slot's icon, and its advice on hover (B.View.EnchantBadge).
local ns = _G.NaowhForever

local T = ns.THEME
local B = ns.BiS
local Enchants = B.Enchants
local Parts = ns.Shared.Parts
local Tip = Parts.Tip
local St = B.Style

local PLACE_DOT = St.PLACE_DOT
local HAVE_RGB, RED_RGB, TITLE_RGB, RIM_RGB = St.HAVE_RGB, St.RED_RGB, St.TIP_TITLE_RGB, St.BORDER_RGB
local DOT, DOT_RIM, DOT_HIT, DOT_IN = 6, 2, 14, 3
local DOT_LIFT = 5
local RIM_ALPHA = 0.85
local ASK = "LF Enchanter: %s (%s), will tip"
local TEXT_ENCHANTS = ns.L("Enchants: ")
local TEXT_NOTHING_ON = ns.L("Nothing on it yet.")
local TEXT_HAS_BEST = ns.L("It has the best for its level.")
local TEXT_ON_NOW = ns.L("On it now: ")
local TEXT_ON_NOW_ELSEWHERE = ns.L("On it now: an enchant from elsewhere.")
local TEXT_ALSO = ns.L("Also worth a look")
local TEXT_CLICK = ns.L("Click: ask for it in Trade, or copy the message")
local TEXT_KNOWN = ns.L("You know it.")
local TEXT_ENCHANTING = ns.L("Enchanting ")
local TEXT_ON_AVERAGE = ns.L(" on average")
local TEXT_ENCHANT = ns.L("Enchant ")
local TEXT_ASK_FOR = ns.L("Ask for ")
local BLANK = " "
local LEARN = { trainer = ns.L("trainers teach it"), vendor = ns.L("a vendor sells the formula"),
    drop = ns.L("its formula drops"), quest = ns.L("from a quest") }

local ItemLevelText = B.View.Memo(ns.L("Best for this level %d item%s"))

local function SpellName(spell)
    return C_Spell.GetSpellName(spell) or (TEXT_ENCHANT .. spell)
end

local function AddEnchant(spell, color)
    local enchant = ns.BiSEnchants[spell]
    local fg, muted = T.fg, T.muted
    GameTooltip:AddDoubleLine(SpellName(spell), enchant.text and enchant.text .. (enchant.proc and TEXT_ON_AVERAGE or ""),
        color.r, color.g, color.b, fg.r, fg.g, fg.b)
    local learn = LEARN[enchant.source]
    GameTooltip:AddLine(TEXT_ENCHANTING .. enchant.skill .. (learn and PLACE_DOT .. learn or ""), muted.r, muted.g, muted.b)
    if IsPlayerSpell(spell) then GameTooltip:AddLine(TEXT_KNOWN, HAVE_RGB.r, HAVE_RGB.g, HAVE_RGB.b) end
end

local function Heading(text)
    GameTooltip:AddLine(BLANK)
    GameTooltip:AddLine(text, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
end

local function OnItNow(a)
    local muted = T.muted
    if a.current == 0 then
        GameTooltip:AddLine(TEXT_NOTHING_ON, RED_RGB.r, RED_RGB.g, RED_RGB.b)
    elseif a.onIt and a.onIt == a.now then
        GameTooltip:AddLine(TEXT_HAS_BEST, HAVE_RGB.r, HAVE_RGB.g, HAVE_RGB.b)
    elseif a.onIt then
        GameTooltip:AddLine(TEXT_ON_NOW .. SpellName(a.onIt), muted.r, muted.g, muted.b)
    else
        GameTooltip:AddLine(TEXT_ON_NOW_ELSEWHERE, muted.r, muted.g, muted.b)
    end
end

local function EnchantEnter(button)
    local slot = button:GetParent().slot
    local a = Enchants.Advise(slot)
    if not Tip(button, "ANCHOR_RIGHT") then return end
    GameTooltip:SetText(TEXT_ENCHANTS .. ns.Shared.Items.SlotName(slot), TITLE_RGB.r, TITLE_RGB.g, TITLE_RGB.b)
    OnItNow(a)
    if a.now and a.now ~= a.onIt then
        Heading(ItemLevelText(a.itemLevel, ""))
        AddEnchant(a.now, a.todo and T.accent or T.fg)
    end
    if a.specials[1] then
        Heading(TEXT_ALSO)
        for _, spell in ipairs(a.specials) do AddEnchant(spell, T.fg) end
    end
    GameTooltip:AddLine(BLANK)
    GameTooltip:AddLine(TEXT_CLICK, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    GameTooltip:Show()
end

local function EnchantClicked(button)
    local spell = Enchants.Advise(button:GetParent().slot).now
    if not spell then return end
    local name, text = SpellName(spell), ns.BiSEnchants[spell].text or ""
    Parts.ShareMenu(button, TEXT_ASK_FOR .. name, function()
        return ASK:format(C_Spell.GetSpellLink(spell) or name, text)
    end, TEXT_ASK_FOR .. name, ASK:format(name, text), true, C_Spell.GetSpellTexture(spell))
end

local function TipEnter(badge)
    if not Tip(badge, "ANCHOR_RIGHT") then return end
    GameTooltip:SetText(badge.tip, TITLE_RGB.r, TITLE_RGB.g, TITLE_RGB.b)
    GameTooltip:Show()
end

function B.View.EnchantBadge(button, opts)
    local badge = CreateFrame("Button", nil, button)
    badge:SetSize(DOT_HIT, DOT_HIT)
    badge:SetPoint("CENTER", button, "TOPRIGHT", -DOT_IN - DOT / 2, -DOT_IN - DOT / 2)
    badge:SetFrameLevel(button:GetFrameLevel() + DOT_LIFT)
    local rim = Parts.Smooth(badge:CreateTexture(nil, "ARTWORK"), St.ROUND)
    rim:SetSize(DOT + DOT_RIM * 2, DOT + DOT_RIM * 2)
    rim:SetPoint("CENTER")
    rim:SetVertexColor(RIM_RGB.r, RIM_RGB.g, RIM_RGB.b, RIM_ALPHA)
    local dot = Parts.Smooth(badge:CreateTexture(nil, "OVERLAY"), St.ROUND)
    dot:SetSize(DOT, DOT)
    dot:SetPoint("CENTER")
    local color = opts and opts.color or T.accent
    dot:SetVertexColor(color.r, color.g, color.b)
    badge.tip = opts and opts.tip
    badge:SetScript("OnEnter", badge.tip and TipEnter or EnchantEnter)
    badge:SetScript("OnLeave", GameTooltip_Hide)
    if not badge.tip then badge:SetScript("OnClick", EnchantClicked) end
    badge:Hide()
    return badge
end

function B.View.PaintEnchantBadge(badge, slot)
    badge:SetShown(Enchants.Advise(slot).todo == true)
end

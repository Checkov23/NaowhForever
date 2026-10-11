-- BagHero.lua: the Sleeping Bag card: how far along the chain you are, the level it needs, and the bag.
local ns = _G.NaowhForever

local T = ns.THEME
local Discovery = ns.Discovery
local C = Discovery.C
local Parts = ns.Shared.Parts
local Style = Discovery.Style
local Bag = Discovery.Bag
local V = Discovery.View

local NEXT_GAP, NEXT_DROP = 10, 3
local ABOUT_GAP = 8
local COUNT_TOP = 26
local ABOUT_RIGHT = 80
local REWARD = 36
local REWARD_INSET = 16
local TEXT_KICKER = ns.L("SLEEPING BAG")
local TEXT_COUNT = "%d / %d"
local TEXT_NEXT = ns.L("Next: %s")
local TEXT_HAVE_BAG = ns.L("You have the Cozy Sleeping Bag")
local TEXT_ABOUT = ns.L("A hidden quest chain across Azeroth: click each thing in the world in turn. It gives a lot "
    .. "of experience, and ends in the Cozy Sleeping Bag; rest in it for a bonus to experience.")
local TEXT_NEEDS_LEVEL = ns.L(" Needs level %d.")

local function NewReward(hero)
    local item = ns.SleepingBag.item
    hero.reward = Parts.ItemIcon(hero, REWARD)
    hero.reward:SetPoint("TOPRIGHT", -REWARD_INSET, -REWARD_INSET)
    hero.reward.item = item
    hero.reward.texture:SetTexture(C_Item.GetItemIconByID(item) or C.FALLBACK_ICON)
    hero.reward:EnableMouse(true)
    hero.reward:SetScript("OnEnter", V.RewardEnter)
    hero.reward:SetScript("OnLeave", GameTooltip_Hide)
end

local function NewBagHero(parent)
    local hero = CreateFrame("Frame", nil, parent)
    ns.Solid(hero, "BACKGROUND", T.fg, Style.CARD_FILL):SetAllPoints()
    ns.Border(hero, Style.BORDER_RGB)
    hero.kicker = ns.Font(hero, Style.KICKER_SIZE, nil, T.accentSoft)
    hero.kicker:SetPoint("TOPLEFT", Style.HERO_PAD, -Style.HERO_TOP)
    hero.kicker:SetText(TEXT_KICKER)
    hero.count = ns.Font(hero, Style.COUNT_SIZE, nil, T.fg)
    hero.count:SetPoint("TOPLEFT", hero.kicker, "BOTTOMLEFT", 0, -Style.COUNT_GAP)
    hero.next = ns.Font(hero, Style.TEXT_SIZE, nil, T.muted)
    hero.next:SetPoint("BOTTOMLEFT", hero.count, "BOTTOMRIGHT", NEXT_GAP, NEXT_DROP)
    hero.about = ns.Font(hero, Style.SMALL_SIZE, nil, T.muted)
    hero.about:SetPoint("TOPLEFT", hero.count, "BOTTOMLEFT", 0, -ABOUT_GAP)
    hero.about:SetPoint("RIGHT", -ABOUT_RIGHT, 0)
    hero.about:SetJustifyH("LEFT")
    hero.about:SetWordWrap(true)
    NewReward(hero)
    return hero
end

local function About()
    if Bag.Level() then return TEXT_ABOUT end
    return TEXT_ABOUT .. ns.Color("fg", TEXT_NEEDS_LEVEL:format(ns.SleepingBag.level))
end

local function SetBagHero(hero)
    local steps = Bag.Steps()
    local step, at = Bag.Current()
    local done = (at or #steps + 1) - 1
    hero.count:SetText(TEXT_COUNT:format(done, #steps))
    hero.next:SetText(step and TEXT_NEXT:format(Bag.Name(step)) or TEXT_HAVE_BAG)
    hero.about:SetText(About())
    return COUNT_TOP + math.ceil(hero.count:GetStringHeight()) + ABOUT_GAP
        + math.ceil(hero.about:GetStringHeight()) + Style.HERO_PAD
end

V.Kinds.bagHero = { New = NewBagHero, Set = SetBagHero }

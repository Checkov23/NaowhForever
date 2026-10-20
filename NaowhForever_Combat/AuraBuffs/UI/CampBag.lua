-- CampBag.lua: the Sleeping Bag beside the Round campfire icon while you carry it near a campfire, a secure button that uses it.
local ns = _G.NaowhForever

local A = ns.AuraBuffs
local T = ns.THEME
local St = A.Style
local Parts = ns.Shared.Parts
local D, Look, Secret = A.CampData, A.CampIcon, A.Camp.Secret

local ITEM = ns.Shared.Items.SLEEPING_BAG
local GCD = A.C.GCD
local WAKE_PAD = 0.1
local FALLBACK_ICON = St.CAMP_BAG_FALLBACK_ICON
local NEARBY, SITTING, SITTING_CRAFT = D.CAMPFIRE_NEARBY, D.WELCOMING_CAMPFIRE, D.WELCOMING_CAMPFIRE_CRAFT
local WELL_RESTED = D.WELL_RESTED
local TEXT_USE = ns.L("Click to use your Sleeping Bag.")

local bag, dirty
local waiter
local readyAt

local CampBag = {}
A.CampBag = CampBag

local function OnEnter(self)
    if not Parts.Tip(self, "ANCHOR_TOP") then return end
    GameTooltip:SetItemByID(ITEM)
    GameTooltip:AddLine(TEXT_USE, T.fg.r, T.fg.g, T.fg.b)
    GameTooltip:Show()
end

local function OnLeave()
    GameTooltip:Hide()
end

local function OnCombatEnd(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    A.Camp.Refresh()
end

local function OnReady()
    readyAt = nil
    A.Camp.Refresh()
end

local function Cooldown()
    local start, duration, enable = C_Container.GetItemCooldown(ITEM)
    if Secret(start) or Secret(duration) or Secret(enable) then return end
    if enable == 1 and duration and duration > GCD and start + duration > GetTime() then return start, duration end
end

local function Rested()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(WELL_RESTED)
    if not aura then return end
    local expiry, duration, stacks = aura.expirationTime, aura.duration, aura.applications
    if Secret(expiry) or Secret(duration) or Secret(stacks) then return end
    if not (duration and duration > 0 and expiry and expiry > GetTime()) then return end
    return expiry, duration, stacks
end

local function ShowCooldown()
    local start, duration = Cooldown()
    Look.BagCooldown(bag, start, duration)
    local ends = start and start + duration
    if not ends or ends == readyAt then return end
    readyAt = ends
    C_Timer.After(ends - GetTime() + WAKE_PAD, OnReady)
end

local function Build()
    bag = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    bag:SetClampedToScreen(true)
    Look.NewBag(bag, FALLBACK_ICON)
    bag:RegisterForClicks("AnyUp", "AnyDown")
    bag:SetAttribute("type1", "item")
    bag:SetAttribute("item1", "item:" .. ITEM)
    bag:SetScript("OnEnter", OnEnter)
    bag:SetScript("OnLeave", OnLeave)
    bag:Hide()
    dirty = true
end

local function WaitForCombat()
    if not waiter then
        waiter = CreateFrame("Frame")
        waiter:SetScript("OnEvent", OnCombatEnd)
    end
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function Near()
    return C_UnitAuras.GetPlayerAuraBySpellID(NEARBY) or C_UnitAuras.GetPlayerAuraBySpellID(SITTING)
        or C_UnitAuras.GetPlayerAuraBySpellID(SITTING_CRAFT)
end

local function Wanted(icon, round)
    return round and icon ~= nil and C_Item.GetItemCount(ITEM) > 0 and Near() ~= nil
end

local function Art()
    if bag.art then return end
    local art = C_Item.GetItemIconByID(ITEM)
    if not art then return end
    bag.tex:SetTexture(art)
    bag.art = art
end

local function Place(icon)
    if dirty then
        Look.BagLayout(bag)
        dirty = false
    end
    local x, y = Look.BagSpot(icon, bag)
    if not x then return false end
    if bag.x ~= x or bag.y ~= y then
        bag:ClearAllPoints()
        bag:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        bag.x, bag.y = x, y
    end
    return true
end

function CampBag.Layout()
    dirty = true
    if bag then bag.x, bag.y = nil, nil end
end

function CampBag.Sync(icon, round)
    if InCombatLockdown() then
        if bag and bag:IsShown() then WaitForCombat() end
        return
    end
    if C_Secrets.ShouldAurasBeSecret() then return end
    if not Wanted(icon, round) then
        if bag then bag:Hide() end
        return
    end
    if not bag then Build() end
    Art()
    ShowCooldown()
    Look.BagRested(bag, Rested())
    bag:SetShown(Place(icon))
end

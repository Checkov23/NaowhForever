-- Bar.lua: the Blessing Bar: your aura and Righteous Fury, a button per class in the group, and its events.
local ns = _G.NaowhForever

local B = ns.Blessings
local S = B.Settings
local CLASSES, AURAS, FURY, BY_KEY, FAMILY, QUESTION = B.CLASSES, B.AURAS, B.FURY, B.BY_KEY, B.FAMILY, B.QUESTION
local Look, Keys, PlayerList = B.Look, B.Keys, B.PlayerList
local On, IsPaladin, Secret, Store, Learned, HighestKnown = B.On, B.IsPaladin, B.Secret, B.Store, B.Learned, B.HighestKnown
local Survey, CastSpell, BuffState, Roster, ClassName = B.Survey, B.CastSpell, B.BuffState, B.Roster, B.ClassName
local RED, YELLOW, BLUE = Look.RED, Look.YELLOW, Look.BLUE

local GROUP_CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true }
local GLOW_LIB, GLOW_KEY = "LibCustomGlow-1.0", "NaowhBless"
local GLOW_LINES, GLOW_THICKNESS = 8, 1
local HOME_Y = 230
local RESCAN_DELAY = 1
local LANDING_WINDOW = 1
local TICK = 3
local NOBODY = B.NOBODY
local CARD = B.PAGE .. ":bar"
local CELL_NAME = "NaowhForeverBless"
local TEXT_MOVER = "Blessings"
local TEXT_AURA = ns.L("Aura")
local TEXT_FURY = "Righteous Fury"
local TEXT_TARGET = ns.L("Left-click: bless %s.\n")
local TEXT_NEXT = ns.L("In combat each click blesses the next who needed it.\n")
local TEXT_MENU = ns.L("Right-click: choose the blessing, the player list or assignments.")
local CLASS_STEP = [[
    if button ~= "LeftButton" then return end
    local n = self:GetAttribute("count") or 0
    local i = self:GetAttribute("step") or 1
    local header = self:GetParent()
    if not header:IsVisible() then return false end
    for _ = 1, n do
        if i > n then i = 1 end
        header:SetAttribute("nameList", self:GetAttribute("queueNames" .. i))
        if self:GetAttribute("unit") then
            self:SetAttribute("spell1", self:GetAttribute("queueSpell" .. i))
            self:SetAttribute("step", i + 1)
            return
        end
        i = i + 1
    end
    return false
]]

local bar, cells, auraButton, furyButton, secureHandler
local dirty, ticker, unlocked, buildAfterCombat
local refreshQueued, landing, landingQueued
local events = CreateFrame("Frame")
local Refresh, Apply

local function Changed()
    Refresh()
    if ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
end

local function Glow(cell, glow)
    if glow == cell.glowing then return end
    cell.glowing = glow
    local LCG = LibStub(GLOW_LIB)
    if glow then
        LCG.PixelGlow_Start(cell, { glow.r, glow.g, glow.b, 1 }, GLOW_LINES, nil, nil, GLOW_THICKNESS, 0, 0, nil, GLOW_KEY)
    else
        LCG.PixelGlow_Stop(cell, GLOW_KEY)
    end
end

local function QueueCell(cell, queue)
    local parts = {}
    for i, entry in ipairs(queue) do parts[i] = entry.names .. "=" .. entry.spell end
    local signature = table.concat(parts, ";")
    if signature == cell.signature then return end
    cell.signature = signature
    for i, entry in ipairs(queue) do
        cell.cast:SetAttribute("queueNames" .. i, entry.names)
        cell.cast:SetAttribute("queueSpell" .. i, entry.spell)
    end
    cell.cast:SetAttribute("count", #queue)
end

local function PrepareCell(cell)
    local members = cell.members
    local s = Survey(members)
    local queue = s.queue
    local key = Store().classes[cell.class]
    local shown = s.spell or (key and CastSpell(key, members))
    cell.icon:SetTexture(shown and C_Spell.GetSpellTexture(shown) or QUESTION)
    QueueCell(cell, queue)
    cell.cast:SetAttribute("step", 1)
    B.SetNames(cell.header, queue[1] and queue[1].names or NOBODY)
    cell.target, cell.queued = s.target, #queue
    local color = s.classMissing > 0 and RED or s.classDue > 0 and YELLOW
        or s.missingNear + s.expiringNear > 0 and BLUE or nil
    Look.Class(cell, color, s.reachable, s.missing, s.shortest)
    Glow(cell, s.classMissing > 0 and Look.Tint(RED))
end

local function CellTip(cell)
    local target = cell.target and Ambiguate(cell.target.who, "short")
    return (target and TEXT_TARGET:format(target) or "")
        .. ((cell.queued or 0) > 1 and TEXT_NEXT or "")
        .. TEXT_MENU
end

local function NewCell(class)
    local cell = CreateFrame("Frame", nil, bar)
    cell.class = class
    Look.Icon(cell)
    Look.Label(cell, class)
    cell.header, cell.cast = B.Recipient(cell, CELL_NAME .. class)
    cell.cast:RegisterForClicks("AnyUp")
    cell.cast:SetAttribute("useOnKeyDown", false)
    cell.cast:SetAttribute("count", 0)
    cell.cast:SetScript("PreClick", function(_, button)
        if button == "LeftButton" and not InCombatLockdown() and not C_Secrets.ShouldAurasBeSecret() then
            PrepareCell(cell)
        end
    end)
    SecureHandlerWrapScript(cell.cast, "OnClick", secureHandler, CLASS_STEP)
    cell.cast:SetScript("PostClick", function(self, button, down)
        if button == "RightButton" and not down then B.ClassMenu(self, class) end
    end)
    local function Tip() return CellTip(cell) end
    ns.Tooltip(cell.cast, ClassName(class), Tip)
    ns.Tooltip(cell, ClassName(class), Tip)
    cell:EnableMouse(true)
    cell:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then B.ClassMenu(self, class) end
    end)
    return cell
end

local function CurrentAura()
    local key = Store().aura
    if key and Learned(BY_KEY[key]) then return key end
    for _, entry in ipairs(AURAS) do
        if Learned(entry) then return entry.key end
    end
end

local function FuryName()
    return C_Spell.GetSpellName(FURY.ranks[1]) or TEXT_FURY
end

local function NewSelfButton(name)
    local btn = CreateFrame("Button", name, bar, "SecureActionButtonTemplate")
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("type1", "spell")
    btn:SetAttribute("unit1", "player")
    btn:SetHighlightTexture(Look.HIGHLIGHT, "ADD")
    Look.Icon(btn)
    B.Watch(btn)
    return btn
end

local function PrepareSelf(btn, key)
    local spell = HighestKnown(BY_KEY[key].ranks)
    btn:SetAttribute("spell1", spell)
    btn.icon:SetTexture(C_Spell.GetSpellTexture(spell))
    B.SetWatch(btn, "player", key)
    Look.State(btn, key, BuffState("player", key))
end

local function PlaceSelf(x)
    local aura = S.Get("blessShowAura") and CurrentAura()
    if aura then
        PrepareSelf(auraButton, aura)
        x = Look.Place(auraButton, bar, x)
    else
        auraButton:Hide()
    end
    if S.Get("blessShowFury") and Learned(FURY) then
        PrepareSelf(furyButton, "fury")
        x = Look.Place(furyButton, bar, x)
    else
        furyButton:Hide()
    end
    return Look.Gap(x)
end

local function ByClass(roster)
    local byClass = {}
    for _, member in ipairs(roster) do
        byClass[member.class] = byClass[member.class] or {}
        table.insert(byClass[member.class], member)
    end
    return byClass
end

local function PlaceCells(byClass, x)
    local size = Look.size
    for _, class in ipairs(CLASSES) do
        local members = byClass[class]
        local cell = cells[class]
        if members then
            cell = cell or NewCell(class)
            cells[class] = cell
            cell.members = members
            B.SizeRecipient(cell.header, cell.cast, size)
            x = Look.Place(cell, bar, x)
            PrepareCell(cell)
        elseif cell then
            B.SetNames(cell.header, NOBODY)
            LibStub(GLOW_LIB).PixelGlow_Stop(cell, GLOW_KEY)
            cell.glowing = nil
            cell:Hide()
        end
    end
    return x
end

function Refresh()
    if not bar then return end
    if InCombatLockdown() or C_Secrets.ShouldAurasBeSecret() then
        dirty = true
        return
    end
    dirty = false
    if not (On() and IsPaladin()) then
        bar:Hide()
        Keys.Clear()
        return
    end
    bar:Show()
    if not bar:IsVisible() then return end
    B.BeginAuraMemo()
    Look.Read()
    local x = PlaceSelf(0)
    local roster = Roster()
    local byClass = ByClass(roster)
    x = PlaceCells(byClass, x)
    PlayerList.Arrange(roster)
    Keys.Fill(byClass)
    B.EndAuraMemo()
    Look.Fit(bar, x)
    bar:SetShown(x > 0 or bar.mover:IsShown())
end

local function SavePosition(pos)
    S.Set("blessPos", pos)
end

local function OnAuraClick(self, button, down)
    if button ~= "RightButton" or down then return end
    B.AuraMenu(self)
end

local function BuildBar()
    bar = CreateFrame("Frame", "NaowhForeverBlessingBar", UIParent)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    cells = {}
    bar.mover = ns.UI.AttachMover(bar, TEXT_MOVER, SavePosition, B.PAGE, CARD)
    local pos = S.Get("blessPos")
    if pos then
        bar:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, HOME_Y)
    end
    auraButton = NewSelfButton("NaowhForeverBlessAura")
    auraButton:SetScript("PostClick", OnAuraClick)
    ns.Tooltip(auraButton, TEXT_AURA, B.AURA_TIP)
    furyButton = NewSelfButton("NaowhForeverBlessFury")
    ns.Tooltip(furyButton, FuryName(), B.FURY_TIP)
    secureHandler = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    Keys.Build(secureHandler)
    PlayerList.Build(bar)
end

local function RunLanded()
    landingQueued = false
    Refresh()
end

local function RefreshLanded()
    if landingQueued then return end
    landingQueued = true
    C_Timer.After(0, RunLanded)
end

local function RunQueued()
    refreshQueued = false
    Refresh()
end

local function RefreshSoon()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(RESCAN_DELAY, RunQueued)
end

local function OnAddonMessage(prefix, msg, channel, sender)
    if Secret(prefix) or Secret(msg) or Secret(channel) or Secret(sender) then return end
    if prefix == B.PREFIX and GROUP_CHANNELS[channel] then B.OnMessage(msg, sender) end
end

local function OnCombatEnded()
    if buildAfterCombat then
        buildAfterCombat = false
        Apply()
    elseif dirty then
        Refresh()
    end
    B.AfterCombat()
    if unlocked and bar then bar.mover:Show() end
end

local function OnUnitAura(unit)
    local fresh = landing and GetTime() - landing < LANDING_WINDOW
    if refreshQueued and not fresh then return end
    if InCombatLockdown() then
        dirty = true
        return
    end
    if unit == "player" or unit:find("party", 1, true) == 1 or unit:find("raid", 1, true) == 1 then
        if fresh then RefreshLanded() else RefreshSoon() end
    end
end

local function OnEvent(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        B.SyncSoon()
        RefreshSoon()
    elseif event == "PARTY_LEADER_CHANGED" then
        if ns.UI.RefreshPage then ns.UI:RefreshPage(true) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        OnCombatEnded()
    elseif event == "PLAYER_REGEN_DISABLED" then
        if bar then bar.mover:Hide() end
    elseif event == "SPELLS_CHANGED" then
        B.BroadcastSoon()
        RefreshSoon()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        if not InCombatLockdown() and not Secret(spellID) and FAMILY[spellID] then landing = GetTime() end
    elseif event == "UNIT_AURA" then
        OnUnitAura(...)
    end
end

local function OnTick()
    if bar:IsShown() and not InCombatLockdown() then RefreshSoon() end
end

local function Stop()
    if bar and InCombatLockdown() then
        dirty = true
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
    elseif bar then
        bar:Hide()
        Keys.Clear()
    end
end

local function Listen()
    C_ChatInfo.RegisterAddonMessagePrefix(B.PREFIX)
    events:RegisterEvent("CHAT_MSG_ADDON")
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PARTY_LEADER_CHANGED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function ListenPaladin()
    events:RegisterEvent("UNIT_AURA")
    events:RegisterEvent("SPELLS_CHANGED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
end

function Apply()
    events:UnregisterAllEvents()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    if not On() then return Stop() end
    Listen()
    if not IsPaladin() then return end
    ListenPaladin()
    if not bar and InCombatLockdown() then
        buildAfterCombat = true
        return
    end
    if not bar then BuildBar() end
    ticker = C_Timer.NewTicker(TICK, OnTick)
    Refresh()
end

local function OnSet(key)
    if key:find("^bless") and key ~= "blessPos" and key ~= "blessWindowAlpha" then Apply() end
end

local function OnUnlock()
    unlocked = true
    if bar and not InCombatLockdown() then
        bar.mover:Show()
        bar:Show()
    end
end

local function OnLock()
    unlocked = false
    if not bar then return end
    bar.mover:Hide()
    Refresh()
end

B.Refresh = Refresh
B.Changed = Changed
B.CurrentAura = CurrentAura
B.FuryName = FuryName

events:SetScript("OnEvent", OnEvent)
hooksecurefunc(S, "Set", OnSet)
hooksecurefunc(ns, "Apply", Apply)
hooksecurefunc(ns, "ShowUnlockMode", OnUnlock)
hooksecurefunc(ns, "HideUnlockMode", OnLock)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

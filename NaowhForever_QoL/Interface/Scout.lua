-- Scout.lua: a creature's abilities, how much of your physical damage its armor takes, and a beast's pet family for hunters, on its tooltip.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local St = ns.Shared.Style
local C = ns.QoLConstants

local MAX_LEVEL = #ns.ScoutArmor
local UNKNOWN_GAP = 10
local ARMOR_BASE, ARMOR_PER_LEVEL, ARMOR_CAP = 400, 85, 0.75
local MAX_LISTED = 8
local MS_PER_SECOND = 1000
local TIP_GAP = 2
local HALF = 0.5
local GOLD = St.FOREVER_GOLD_RGB
local WHITE = C.WHITE_RGB
local TAME_RGB, UNTAME_RGB = St.HAVE_RGB, St.RED_RGB
local ICON = "|T%d:0|t %s"
local KEYS = { ctrl = IsControlKeyDown, alt = IsAltKeyDown, shift = IsShiftKeyDown }
local KEY_NAMES = { ctrl = "Ctrl", alt = "Alt", shift = "Shift" }
local MODIFIERS = { LCTRL = "ctrl", RCTRL = "ctrl", LALT = "alt", RALT = "alt", LSHIFT = "shift", RSHIFT = "shift" }
local ARMOR, SCHOOLS_IMMUNE, MECHANICS_IMMUNE, FIRST_RESIST = 1, 2, 3, 4
local LIST_JOIN, RESIST_PAIR = ", ", "%s %d"
local SCHOOLS = { { 1, ns.L("Physical") }, { 2, ns.L("Holy") }, { 4, ns.L("Fire") }, { 8, ns.L("Nature") },
    { 16, ns.L("Frost") }, { 32, ns.L("Shadow") }, { 64, ns.L("Arcane") } }
local MECHANICS = { { 12, ns.L("Stun") }, { 5, ns.L("Fear") }, { 7, ns.L("Root") }, { 11, ns.L("Slow") },
    { 9, ns.L("Silence") }, { 10, ns.L("Sleep") }, { 1, ns.L("Charm") }, { 17, ns.L("Polymorph") },
    { 18, ns.L("Banish") }, { 2, ns.L("Disorient") }, { 26, ns.L("Interrupt") }, { 15, ns.L("Bleed") },
    { 20, ns.L("Shackle") }, { 3, ns.L("Disarm") } }
for _, mechanic in ipairs(MECHANICS) do mechanic[1] = bit.lshift(1, mechanic[1] - 1) end
local band = bit.band
local PHYSICAL = SCHOOLS[1][1]
local RESISTED = { ns.L("Holy"), ns.L("Fire"), ns.L("Nature"), ns.L("Frost"), ns.L("Shadow"), ns.L("Arcane") }
local HUNTER = "HUNTER"
local WORLD_BOSS = "worldboss"
local CREATURE, VEHICLE = "Creature", "Vehicle"
local DETAILS_TIP = "NaowhForeverScoutDetails"
local SPELL_TIP = "NaowhForeverScoutSpell"
local SEP = St.PLACE_DOT
local TEXT_ABILITIES = ns.L("Abilities")
local TEXT_ARMOR = ns.L("Armor")
local TEXT_ARMOR_VALUE, TEXT_ARMOR_ESTIMATE = "%d", "~%d"
local TEXT_IMMUNE = ns.L("Immune: %s")
local TEXT_RESISTS = ns.L("Resists: %s")
local TEXT_REDUCTION = ns.L("Your physical damage")
local TEXT_REDUCTION_VALUE = "-%.1f%%"
local TEXT_FAMILY = ns.L("Pet family")
local TEXT_TAMEABLE = ns.L("Tameable")
local TEXT_UNTAMEABLE = ns.L("Untameable")
local TEXT_UNTIL = ns.L("Untameable until level %d")
local TEXT_NOT_YET = ns.L("Untameable at your level")
local TEXT_HINT = ns.L("Hold %s for ability details")
local TEXT_INSTANT = ns.L("Instant")
local TEXT_CAST = ns.L("%ss cast")
local TEXT_RANGE = ns.L("%d yd")
local TEXT_RANGES = ns.L("%d-%d yd")
local TEXT_MELEE = ns.L("Melee")
local TEXT_SUMMARY = ns.L("Hold %s for details")

local abilities, tameable, stats, events, details
local listed = {}
local spellTips, named, requested = {}, {}, {}
local shown

local function On()
    return S.Get("enabled") and S.Get("scout")
end

local function Unpack(packed)
    local u = C_EncodingUtil
    return u.DeserializeCBOR(u.DecompressString(u.DecodeBase64(packed), Enum.CompressionMethod.Deflate))
end

local function Load()
    if abilities then return true end
    if InCombatLockdown() then return false end
    local flat, tame = Unpack(ns.ScoutAbilitiesPacked), Unpack(ns.ScoutTameablePacked)
    if type(flat) ~= "table" or type(tame) ~= "table" then return false end
    abilities, tameable = {}, {}
    for i = 1, #flat, 2 do abilities[flat[i]] = flat[i + 1] end
    for _, npc in ipairs(tame[2]) do tameable[npc] = true end
    ns.ScoutAbilitiesPacked, ns.ScoutTameablePacked = nil, nil
    return true
end

local function Stats()
    if stats then return stats end
    if InCombatLockdown() then return nil end
    local numbers = Unpack(ns.ScoutStatsPacked)
    if type(numbers) ~= "table" then return nil end
    stats = {}
    for i = 1, #numbers, 2 do stats[numbers[i]] = numbers[i + 1] end
    ns.ScoutStatsPacked = nil
    return stats
end

local function Secret(value)
    return issecretvalue and issecretvalue(value)
end

local function NpcID(guid)
    if Secret(guid) or type(guid) ~= "string" then return nil end
    local kind, _, _, _, _, entry = strsplit("-", guid)
    if kind ~= CREATURE and kind ~= VEHICLE then return nil end
    return tonumber(entry)
end

local function KeyDown()
    return KEYS[S.Get("scoutKey")]()
end

local function Meta(info)
    local cast = info.castTime > 0 and TEXT_CAST:format(info.castTime / MS_PER_SECOND) or TEXT_INSTANT
    local range = TEXT_MELEE
    if info.maxRange > 0 then
        range = info.minRange > 0 and TEXT_RANGES:format(info.minRange, info.maxRange) or TEXT_RANGE:format(info.maxRange)
    end
    return range .. SEP .. cast
end

local function Known(list)
    wipe(named)
    for i = 1, #list do
        if #named == MAX_LISTED then break end
        if C_Spell.GetSpellName(list[i]) then named[#named + 1] = list[i] end
    end
    return named
end

local function HideDetails()
    if details then details:Hide() end
    for _, tip in ipairs(spellTips) do tip:Hide() end
end

local function NewTip(name)
    local tip = CreateFrame("GameTooltip", name, UIParent, "GameTooltipTemplate")
    tip:SetClampedToScreen(true)
    return tip
end

local ShowDetails

local function Described(spell)
    local text = C_Spell.GetSpellDescription(spell)
    if text and text ~= "" then return text end
    if not requested[spell] then
        requested[spell] = true
        Spell:CreateFromSpellID(spell):ContinueOnSpellLoad(function()
            if shown and KeyDown() then ShowDetails() end
        end)
    end
end

local function OnLeft()
    local x = GameTooltip:GetCenter()
    return x and x > UIParent:GetWidth() * HALF
end

local function ShowInline(list)
    details = details or NewTip(DETAILS_TIP)
    details:SetOwner(UIParent, "ANCHOR_NONE")
    details:ClearAllPoints()
    details:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 0, -TIP_GAP)
    for _, spell in ipairs(list) do
        local name, icon = C_Spell.GetSpellName(spell), C_Spell.GetSpellTexture(spell)
        details:AddLine(icon and ICON:format(icon, name) or name, WHITE.r, WHITE.g, WHITE.b)
        local text = Described(spell)
        if text then details:AddLine(text, T.fg.r, T.fg.g, T.fg.b, true) end
    end
    details:Show()
end

local function ShowBeside(list)
    local left = OnLeft()
    local anchor = GameTooltip
    for i, spell in ipairs(list) do
        spellTips[i] = spellTips[i] or NewTip(SPELL_TIP .. i)
        local tip = spellTips[i]
        tip:SetOwner(UIParent, "ANCHOR_NONE")
        tip:ClearAllPoints()
        if i == 1 then
            if left then tip:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -TIP_GAP, 0)
            else tip:SetPoint("TOPLEFT", anchor, "TOPRIGHT", TIP_GAP, 0) end
        else
            tip:SetPoint(left and "TOPRIGHT" or "TOPLEFT", anchor, left and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, -TIP_GAP)
        end
        tip:SetSpellByID(spell)
        tip:Show()
        anchor = tip
    end
end

ShowDetails = function()
    HideDetails()
    if not (shown and GameTooltip:IsShown()) then return end
    if S.Get("scoutDetails") == "beside" then ShowBeside(shown) else ShowInline(shown) end
end

local function AddAbilities(tooltip, list)
    tooltip:AddLine(TEXT_ABILITIES, T.accentSoft.r, T.accentSoft.g, T.accentSoft.b)
    for _, spell in ipairs(list) do
        local info = C_Spell.GetSpellInfo(spell)
        local name, icon = info.name, C_Spell.GetSpellTexture(spell)
        tooltip:AddDoubleLine(icon and ICON:format(icon, name) or name, Meta(info), WHITE.r, WHITE.g, WHITE.b,
            T.muted.r, T.muted.g, T.muted.b)
    end
    if S.Get("scoutHint") then
        tooltip:AddLine(TEXT_HINT:format(ns.L(KEY_NAMES[S.Get("scoutKey")])), T.muted.r, T.muted.g, T.muted.b)
    end
end

local function MobLevel(unit, player)
    local level = UnitLevel(unit)
    if Secret(level) then return nil end
    if level and level > 0 then return math.min(level, MAX_LEVEL) end
    local class = UnitClassification(unit)
    if not Secret(class) and class == WORLD_BOSS then return MAX_LEVEL end
    return math.min(player + UNKNOWN_GAP, MAX_LEVEL)
end

local function AddArmor(tooltip, unit, npc)
    local hostile = UnitCanAttack("player", unit)
    if Secret(hostile) or not hostile then return end
    local player = UnitLevel("player")
    local row = Stats() and stats[npc]
    if row and band(row[SCHOOLS_IMMUNE], PHYSICAL) ~= 0 then return end
    local own = row and row[ARMOR]
    local armor, text = own, TEXT_ARMOR_VALUE
    if not own or own == 0 then
        local level = MobLevel(unit, player)
        if not level then return end
        armor, text = ns.ScoutArmor[level], TEXT_ARMOR_ESTIMATE
    end
    local cut = math.min(ARMOR_CAP, armor / (armor + ARMOR_BASE + ARMOR_PER_LEVEL * player))
    tooltip:AddDoubleLine(TEXT_ARMOR, text:format(armor), T.accentSoft.r, T.accentSoft.g, T.accentSoft.b,
        GOLD.r, GOLD.g, GOLD.b)
    tooltip:AddDoubleLine(TEXT_REDUCTION, TEXT_REDUCTION_VALUE:format(cut * C.PERCENT), T.muted.r, T.muted.g, T.muted.b,
        GOLD.r, GOLD.g, GOLD.b)
end

local function AddImmunities(tooltip, npc)
    local own = Stats() and stats[npc]
    if not own then return end
    wipe(listed)
    for _, school in ipairs(SCHOOLS) do
        if band(own[SCHOOLS_IMMUNE], school[1]) ~= 0 then listed[#listed + 1] = school[2] end
    end
    for _, mechanic in ipairs(MECHANICS) do
        if band(own[MECHANICS_IMMUNE], mechanic[1]) ~= 0 then listed[#listed + 1] = mechanic[2] end
    end
    if #listed > 0 then
        tooltip:AddLine(TEXT_IMMUNE:format(table.concat(listed, LIST_JOIN)), T.muted.r, T.muted.g, T.muted.b, true)
    end
    wipe(listed)
    for i, school in ipairs(RESISTED) do
        local points = own[FIRST_RESIST + i - 1]
        if points and points > 0 then listed[#listed + 1] = RESIST_PAIR:format(school, points) end
    end
    if #listed > 0 then
        tooltip:AddLine(TEXT_RESISTS:format(table.concat(listed, LIST_JOIN)), T.muted.r, T.muted.g, T.muted.b, true)
    end
end

local function AddFamily(tooltip, unit, npc)
    if select(2, UnitClass("player")) ~= HUNTER then return end
    local family, level = UnitCreatureFamily(unit), UnitLevel(unit)
    if Secret(family) or not family or Secret(level) then return end
    local text, color = TEXT_TAMEABLE, TAME_RGB
    if not tameable[npc] then
        text, color = TEXT_UNTAMEABLE, UNTAME_RGB
    elseif level <= 0 then
        text, color = TEXT_NOT_YET, UNTAME_RGB
    elseif level > UnitLevel("player") then
        text, color = TEXT_UNTIL:format(level), UNTAME_RGB
    end
    tooltip:AddDoubleLine(TEXT_FAMILY, family .. SEP .. text, T.muted.r, T.muted.g, T.muted.b, color.r, color.g, color.b)
end

local function OnUnit(tooltip, data)
    if tooltip ~= GameTooltip or tooltip:IsForbidden() then return end
    shown = nil
    HideDetails()
    if not On() or (not S.Get("scoutInstances") and IsInInstance()) or not Load() then return end
    local npc = NpcID(data and data.guid)
    local _, unit = tooltip:GetUnit()
    if not npc or not unit or Secret(unit) then return end
    if S.Get("scoutFamily") then AddFamily(tooltip, unit, npc) end
    local list = S.Get("scoutAbilities") and abilities[npc]
    if list then
        list = Known(list)
        if #list > 0 then
            AddAbilities(tooltip, list)
            shown = { unpack(list) }
            if KeyDown() then C_Timer.After(0, ShowDetails) end
        end
    end
    if S.Get("scoutArmor") then AddArmor(tooltip, unit, npc) end
    if S.Get("scoutImmunities") then AddImmunities(tooltip, npc) end
end

local function OnTooltipHide()
    shown = nil
    HideDetails()
end

local function OnEvent(_, event, key, down)
    if event == "PLAYER_REGEN_ENABLED" then
        if Load() then
            events:UnregisterEvent("PLAYER_REGEN_ENABLED")
        end
        return
    end
    if not shown or MODIFIERS[key] ~= S.Get("scoutKey") then return end
    if down == 1 then ShowDetails() else HideDetails() end
end

local function Apply()
    if not On() then
        if events then events:UnregisterAllEvents() end
        shown = nil
        HideDetails()
        return
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnit)
        GameTooltip:HookScript("OnHide", OnTooltipHide)
    end
    events:UnregisterAllEvents()
    if S.Get("scoutAbilities") then events:RegisterEvent("MODIFIER_STATE_CHANGED") end
    if not Load() then
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
end

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key:find("^scout") then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

local KEY_CHOICE = { KEY_NAMES, { "ctrl", "alt", "shift" } }
local DETAILS = { { inline = "In the Tooltip", beside = "Beside It" }, { "inline", "beside" } }

local function Summary(store)
    return TEXT_SUMMARY:format(ns.L(KEY_NAMES[store.Get("scoutKey")]))
end

ns.Shared.Settings.Page("QoL/Interface", S):Card({
    id = "scout", name = "Scout", order = 52, switch = "scout",
    help = "What a creature can do, and how much of your physical damage its armor takes, on its tooltip.",
    summary = Summary,
    rows = {
        { key = "scoutAbilities", label = "Creature Abilities", toggle = true,
          help = "The spells a creature is known to use, under its name." },
        { key = "scoutArmor", label = "Armor and Damage Reduction", toggle = true,
          help = "The armor expected at its level, and how much of your physical damage it takes." },
        { key = "scoutImmunities", label = "Immunities and Resistances", toggle = true,
          help = "The effects and schools a creature is immune to, and the spell schools it resists." },
        { key = "scoutKey", label = "Details Key", choice = KEY_CHOICE,
          help = "Hold it over a creature to read what each ability does." },
        { key = "scoutDetails", label = "Details Show", choice = DETAILS,
          help = "Under the creature's tooltip, or as the full spell tooltips beside it." },
        { key = "scoutFamily", label = "Pet Family", toggle = true,
          help = "Hunters see a beast's pet family and whether they can tame it yet." },
        { key = "scoutInstances", label = "Also in Instances", toggle = true },
        { key = "scoutHint", label = "Key Hint", toggle = true,
          help = "A line saying which key shows the details." },
    },
})

-- SpellEfficiency.lua: Mana Efficiency, a mana spell's (or macro's) healing or damage per mana and per second on its tooltip, and its card preview.
local ns = _G.NaowhForever

local GetSpellPowerCost = C_Spell.GetSpellPowerCost
local GetSpellInfo = C_Spell.GetSpellInfo
local GetSpellBonusHealing = GetSpellBonusHealing
local GetSpellBonusDamage = GetSpellBonusDamage
local GetSpellCritChance = GetSpellCritChance
local GetActionInfo = GetActionInfo
local GetMacroSpell = GetMacroSpell
local UnitLevel = UnitLevel
local floor, min = math.floor, math.min
local find, sub = string.find, string.sub
local tonumber = tonumber

local S = ns.QoLSettings
local T = ns.THEME
local C = ns.QoLConstants
local St = ns.Shared.Style
local Data = ns.SpellEfficiencyData
local TalentData = ns.SpellEfficiencyTalents

local SCHOOL, LEVEL, MAX_LEVEL, AREA = 1, 2, 3, 4
local PART_START, PART_SIZE = 5, 9
local KIND, DIRECT, DIRECT_PER_LEVEL, DIRECT_COEFFICIENT = 0, 1, 2, 3
local TICK, TICK_PER_LEVEL, TICK_COEFFICIENT, TICKS, SECONDS = 4, 5, 6, 7, 8
local HEAL, DAMAGE = 1, 0
local MOD_NODE, MOD_OP = 1, 2
local OP_DIRECT, OP_PERIODIC, OP_CRIT_REFUND = 0, 1, 2
local DATA_SEPARATOR = ","
local MOD_SEPARATOR = ";"
local DATA_NUMBER = "^%-?%d+%.?%d*$"
local COLOR_KEY = "spellEfficiencyColor"
local LOW_LEVEL_CAP, LOW_LEVEL_STEP = 20, 0.0375
local MS_PER_SECOND = 1000
local PERCENT = 100
local MANA = Enum.PowerType.Mana
local DECIMALS_MAX = 2
local DEFAULT_DECIMALS = 2
local PREVIEW_SPELL = 2053
local SHOW_HEAL, SHOW_DAMAGE = "heal", "damage"
local STYLE_SHORT = "short"
local SEPARATOR = "  ||  "
local LONG_FIRST = { ns.L("%s %s per mana"), ns.L("%s %s per second"), ns.L("%s %s per mana per second") }
local LONG_NEXT = { ns.L("%s per mana"), ns.L("%s per second"), ns.L("%s per mana per second") }
local SHORT_PIECE = "%s %s"
local PER_TARGET = ns.L("%s / target")
local SHORT_LABELS = {
    [HEAL] = { "HPM", "HPS", "HPM/s" },
    [DAMAGE] = { "DPM", "DPS", "DPM/s" },
}
local KIND_WORDS = { [HEAL] = ns.L("healing"), [DAMAGE] = ns.L("damage") }
local PER_MANA, PER_SECOND, PER_MANA_SECOND = 1, 2, 3
local WHOLE = "%d"

local STAGE_H = 254
local MOCK_PAD, MOCK_LINE, MOCK_GAP = 8, 16, 10
local MOCK_ROWS = 3
local TITLE_SIZE, TEXT_SIZE = 13, 11
local SAMPLE_POWER = 100
local SAMPLES = {
    { name = ns.L("Sample Heal"), kind = HEAL, amount = 450, coefficient = 0.857, mana = 300, cast = 2.5 },
    { name = ns.L("Sample Bolt"), kind = DAMAGE, amount = 400, coefficient = 0.857, mana = 200, cast = 3 },
    { name = ns.L("Sample Nova"), kind = DAMAGE, amount = 150, coefficient = 0.107, mana = 100, cast = 1.5, area = true },
}
local TEXT_MANA = ns.L("%d Mana")
local TEXT_CAST = ns.L("%s sec cast")
local TEXT_SAMPLE_POWER = ns.L("Sample spells with %d spell power.")
local TEXT_SAMPLE_BASE = ns.L("Sample spells, base numbers only.")
local TEXT_OFF = ns.L("Turn on Mana Efficiency to add this line to your tooltips.")
local STATES = { { key = "sample", label = "Sample" } }

local NUMBER_FORMATS = {}
for decimals = 0, DECIMALS_MAX do NUMBER_FORMATS[decimals] = "%." .. decimals .. "f" end

local hooked
local decoded = {}
local decodedMods = {}
local decoratedAt = setmetatable({}, { __mode = "k" })
local decoratedText = setmetatable({}, { __mode = "k" })
local scratch, sampleRates = {}, {}

local function On()
    return S.Get("enabled") and S.Get("spellEfficiency")
end

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

local function Readable(v)
    return not Secret(v) and (not canaccessvalue or canaccessvalue(v))
end

local function ReadableTable(v)
    return Readable(v) and not (issecrettable and issecrettable(v)) and type(v) == "table"
end

local function Decode(text)
    if type(text) ~= "string" then return false end
    local entry, count, at = {}, 0, 1
    repeat
        local stop = find(text, DATA_SEPARATOR, at, true)
        local field = sub(text, at, (stop or 0) - 1)
        if not find(field, DATA_NUMBER) then return false end
        count = count + 1
        entry[count] = tonumber(field)
        at = stop and stop + 1
    until not at
    if count < PART_START or (count - AREA) % PART_SIZE ~= 0 then return false end
    for part = PART_START, count, PART_SIZE do
        local kind = entry[part + KIND]
        if kind ~= HEAL and kind ~= DAMAGE then return false end
    end
    return entry
end

local function Entry(spellID)
    local entry = decoded[spellID]
    if entry == nil then
        local text = Data[spellID]
        if text == nil then return nil end
        entry = Decode(text)
        decoded[spellID] = entry
    end
    return entry or nil
end

local function DecodeMods(text)
    if type(text) ~= "string" then return false end
    local mods, at = {}, 1
    repeat
        local stop = find(text, MOD_SEPARATOR, at, true)
        local part = sub(text, at, (stop or 0) - 1)
        local mod, count, from = {}, 0, 1
        repeat
            local comma = find(part, DATA_SEPARATOR, from, true)
            local field = sub(part, from, (comma or 0) - 1)
            if not find(field, DATA_NUMBER) then return false end
            count = count + 1
            mod[count] = tonumber(field)
            from = comma and comma + 1
        until not from
        if count <= MOD_OP then return false end
        mods[#mods + 1] = mod
        at = stop and stop + 1
    until not at
    return mods
end

local function ModsOf(spellID)
    local mods = decodedMods[spellID]
    if mods == nil then
        local text = TalentData[spellID]
        if text == nil then return nil end
        mods = DecodeMods(text)
        decodedMods[spellID] = mods
    end
    return mods or nil
end

local function TalentRank(node)
    local config = C_ClassTalents.GetActiveConfigID()
    local info = config and C_Traits.GetNodeInfo(config, node)
    local rank = ReadableTable(info) and info.activeRank
    return type(rank) == "number" and rank or 0
end

local function CritChance(school)
    if C_Secrets and C_Secrets.ShouldUnitStatsBeSecret and C_Secrets.ShouldUnitStatsBeSecret() then return nil end
    local crit = GetSpellCritChance(school)
    if not Readable(crit) or type(crit) ~= "number" then return nil end
    return min(crit / PERCENT, 1)
end

local function TalentEffects(spellID, school)
    local direct, periodic, cost = 1, 1, 1
    local mods = S.Get("spellEfficiencyTalents") and ModsOf(spellID)
    if not mods then return direct, periodic, cost end
    for i = 1, #mods do
        local mod = mods[i]
        local rank = TalentRank(mod[MOD_NODE])
        if rank > 0 then
            local value = mod[MOD_OP + min(rank, #mod - MOD_OP)]
            local op = mod[MOD_OP]
            if op == OP_DIRECT then
                direct = direct + value
            elseif op == OP_PERIODIC then
                periodic = periodic + value
            elseif op == OP_CRIT_REFUND then
                local crit = CritChance(school)
                if crit then cost = cost * (1 - value * crit) end
            else
                cost = cost * (1 - value)
            end
        end
    end
    return direct, periodic, cost
end

local function LineColor()
    local color = S.Get(COLOR_KEY)
    if type(color) == "table" and type(color.r) == "number" and type(color.g) == "number" and type(color.b) == "number" then
        return color
    end
    return S.Default(COLOR_KEY)
end

local function Shows(kind)
    local show = S.Get("spellEfficiencyShow")
    if show == SHOW_HEAL then return kind == HEAL end
    if show == SHOW_DAMAGE then return kind ~= HEAL end
    return true
end

local function Number(value, whole)
    if whole then return WHOLE:format(floor(value + C.ROUND)) end
    return (NUMBER_FORMATS[S.Get("spellEfficiencyDecimals")] or NUMBER_FORMATS[DEFAULT_DECIMALS]):format(value)
end

local function Piece(text, which, kind, value, area)
    local number = Number(value, which == PER_SECOND)
    local piece
    if S.Get("spellEfficiencyStyle") == STYLE_SHORT then
        piece = SHORT_PIECE:format(SHORT_LABELS[kind][which], number)
    elseif text then
        piece = LONG_NEXT[which]:format(number)
    else
        piece = LONG_FIRST[which]:format(number, KIND_WORDS[kind])
    end
    if area then piece = PER_TARGET:format(piece) end
    if not text then return piece end
    return text .. SEPARATOR .. piece
end

local function Rate(part, kind, amount, mana, seconds)
    local perMana = amount / mana
    part.kind, part.amount, part.perMana = kind, amount, perMana
    if seconds and seconds > 0 then
        part.perSecond, part.perManaSecond = amount / seconds, perMana / seconds
    else
        part.perSecond, part.perManaSecond = nil, nil
    end
    return part
end

local function Line(part, area)
    local kind = part.kind
    local text = S.Get("spellEfficiencyPerMana") and Piece(nil, PER_MANA, kind, part.perMana, area) or nil
    if part.perSecond then
        if S.Get("spellEfficiencyPerSecond") then text = Piece(text, PER_SECOND, kind, part.perSecond, area) end
        if S.Get("spellEfficiencyPerManaSecond") then text = Piece(text, PER_MANA_SECOND, kind, part.perManaSecond, area) end
    end
    return text
end

local function Penalty(entry)
    local spellLevel = entry[LEVEL]
    if spellLevel < 1 or spellLevel >= LOW_LEVEL_CAP then return 1 end
    return 1 - (LOW_LEVEL_CAP - spellLevel) * LOW_LEVEL_STEP
end

local function Gain(entry, level)
    local cap = entry[MAX_LEVEL]
    if cap > 0 and level > cap then level = cap end
    local gain = level - entry[LEVEL]
    return gain > 0 and gain or 0
end

local function Amount(entry, at, gain, bonus, directMod, periodicMod)
    local scaled = bonus * Penalty(entry)
    local direct = (entry[at + DIRECT] + entry[at + DIRECT_PER_LEVEL] * gain + entry[at + DIRECT_COEFFICIENT] * scaled) * directMod
    local tick = (entry[at + TICK] + entry[at + TICK_PER_LEVEL] * gain + entry[at + TICK_COEFFICIENT] * scaled) * periodicMod
    return direct + tick * entry[at + TICKS]
end

local function Seconds(entry, at, castMs)
    if castMs > 0 then return castMs / MS_PER_SECOND end
    local seconds = entry[at + SECONDS]
    return seconds > 0 and seconds or nil
end

local function ManaCost(spellID)
    local costs = GetSpellPowerCost(spellID)
    if not ReadableTable(costs) then return nil end
    for i = 1, #costs do
        local cost = costs[i]
        local powerType, amount = cost.type, cost.cost
        if not (Readable(powerType) and Readable(amount)) then return nil end
        if powerType == MANA and amount > 0 then return amount end
    end
    return nil
end

local function CastMs(spellID)
    local info = GetSpellInfo(spellID)
    if not ReadableTable(info) then return nil end
    local castMs = info.castTime
    if not Readable(castMs) or type(castMs) ~= "number" then return nil end
    return castMs
end

local function Bonus(entry, kind)
    if not S.Get("spellEfficiencyBonus") then return 0 end
    if C_Secrets and C_Secrets.ShouldUnitStatsBeSecret and C_Secrets.ShouldUnitStatsBeSecret() then return nil end
    local bonus
    if kind == HEAL then bonus = GetSpellBonusHealing() else bonus = GetSpellBonusDamage(entry[SCHOOL]) end
    if not Readable(bonus) or type(bonus) ~= "number" then return nil end
    return bonus
end

local function Decorates(tooltip)
    return tooltip == GameTooltip or tooltip == ItemRefTooltip
end

local function AlreadyDecorated(tooltip, text)
    local at = decoratedAt[tooltip]
    if not (at and at <= tooltip:NumLines() and decoratedText[tooltip] == text) then return false end
    local left = _G[tooltip:GetName() .. "TextLeft" .. at]
    local shown = left and left:GetText()
    return Readable(shown) and shown == text
end

local function Efficiency(spellID, out)
    local entry = Entry(spellID)
    if not entry then return nil end
    local mana = ManaCost(spellID)
    if not mana then return nil end
    local castMs = CastMs(spellID)
    if not castMs then return nil end
    local level = UnitLevel("player")
    if not Readable(level) then return nil end
    local gain = Gain(entry, level)
    local directMod, periodicMod, costMod = TalentEffects(spellID, entry[SCHOOL])
    mana = mana * costMod
    out = out or {}
    out.mana, out.castMs, out.area, out.level = mana, castMs, entry[AREA] == 1, entry[LEVEL]
    local count = 0
    for at = PART_START, #entry, PART_SIZE do
        local kind = entry[at + KIND]
        if Shows(kind) then
            local bonus = Bonus(entry, kind)
            if not bonus then break end
            local amount = Amount(entry, at, gain, bonus, directMod, periodicMod)
            if amount > 0 and mana > 0 then
                count = count + 1
                out[count] = Rate(out[count] or {}, kind, amount, mana, Seconds(entry, at, castMs))
            end
        end
    end
    out.count = count
    return out
end

local function AddLines(tooltip, spellID)
    local result = Efficiency(spellID, scratch)
    if not result then return end
    local color = LineColor()
    local first
    for i = 1, result.count do
        local text = Line(result[i], result.area)
        if text then
            if not first then
                if AlreadyDecorated(tooltip, text) then return end
                first = text
            end
            tooltip:AddLine(text, color.r, color.g, color.b)
            if first == text then
                decoratedAt[tooltip], decoratedText[tooltip] = tooltip:NumLines(), text
            end
        end
    end
end

local function SpellOf(data)
    if not ReadableTable(data) then return nil end
    local id = data.id
    if not Readable(id) or type(id) ~= "number" then return nil end
    return id
end

local function ActionSlot(owner)
    local action = owner.action
    if Readable(action) and type(action) == "number" then return action end
    action = owner.GetAttribute and owner:GetAttribute("action")
    if Readable(action) and type(action) == "number" then return action end
end

local function MacroSpellOf(tooltip)
    local owner = tooltip:GetOwner()
    local action = owner and ActionSlot(owner)
    if not action then return nil end
    local kind, id, subType = GetActionInfo(action)
    if kind ~= "macro" or not (Readable(id) and type(id) == "number") then return nil end
    if subType == "spell" then return id end
    local spellID = GetMacroSpell(id)
    if Readable(spellID) and type(spellID) == "number" then return spellID end
    return nil
end

local function Decorate(tooltip, data)
    if not On() or tooltip:IsForbidden() or not Decorates(tooltip) then return end
    local spellID = SpellOf(data)
    if spellID then AddLines(tooltip, spellID) end
end

local function DecorateMacro(tooltip)
    if not On() or tooltip:IsForbidden() or not Decorates(tooltip) then return end
    local spellID = MacroSpellOf(tooltip)
    if spellID then AddLines(tooltip, spellID) end
end

local function Apply()
    if hooked or not On() then return end
    hooked = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, Decorate)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Macro, DecorateMacro)
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "spellEfficiency" then Apply() end
end

ns.SpellEfficiencyOf = Efficiency
ns.SpellEfficiencyNumber = Number

function ns.PreviewSpellEfficiency()
    if GameTooltip:IsForbidden() then return end
    local foci = GetMouseFoci and GetMouseFoci()
    GameTooltip:SetOwner(foci and foci[1] or UIParent, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(PREVIEW_SPELL)
    AddLines(GameTooltip, PREVIEW_SPELL)
    GameTooltip:Show()
end

local function SampleLine(sample)
    if not Shows(sample.kind) then return nil end
    local bonus = S.Get("spellEfficiencyBonus") and SAMPLE_POWER * sample.coefficient or 0
    return Line(Rate(sampleRates, sample.kind, sample.amount + bonus, sample.mana, sample.cast), sample.area)
end

local function NewMock(shot)
    local mock = CreateFrame("Frame", nil, shot)
    mock:SetHeight(MOCK_PAD * 2 + MOCK_LINE * MOCK_ROWS)
    ns.Solid(mock, "BACKGROUND", St.CLASSIC_TIP_RGB, St.CLASSIC_TIP_ALPHA):SetAllPoints()
    ns.Border(mock, St.CLASSIC_TIP_EDGE_RGB)
    mock.name = ns.Font(mock, TITLE_SIZE, nil, St.TIP_TITLE_RGB)
    mock.name:SetPoint("TOPLEFT", MOCK_PAD, -MOCK_PAD)
    mock.mana = ns.Font(mock, TEXT_SIZE, nil, St.TIP_TITLE_RGB)
    mock.mana:SetPoint("TOPLEFT", MOCK_PAD, -MOCK_PAD - MOCK_LINE)
    mock.cast = ns.Font(mock, TEXT_SIZE, nil, St.TIP_TITLE_RGB)
    mock.cast:SetPoint("TOPRIGHT", -MOCK_PAD, -MOCK_PAD - MOCK_LINE)
    mock.line = ns.Font(mock, TEXT_SIZE)
    mock.line:SetPoint("TOPLEFT", MOCK_PAD, -MOCK_PAD - MOCK_LINE * (MOCK_ROWS - 1))
    mock.line:SetPoint("RIGHT", -MOCK_PAD, 0)
    mock.line:SetJustifyH("LEFT")
    mock.line:SetWordWrap(false)
    return mock
end

local function NewPreview(stage)
    local shot = CreateFrame("Frame", nil, stage)
    shot:SetAllPoints()
    shot.mocks = {}
    local above
    for i = 1, #SAMPLES do
        local mock = NewMock(shot)
        if above then
            mock:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -MOCK_GAP)
            mock:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -MOCK_GAP)
        else
            mock:SetPoint("TOPLEFT", St.STAGE_MARGIN, -St.STAGE_MARGIN)
            mock:SetPoint("TOPRIGHT", -St.STAGE_MARGIN, -St.STAGE_MARGIN)
        end
        shot.mocks[i] = mock
        above = mock
    end
    shot.note = ns.Font(shot, St.STAGE_NOTE_SIZE, nil, T.muted)
    shot.note:SetPoint("BOTTOM", 0, St.STAGE_NOTE_Y)
    return shot
end

local function PaintPreview(shot)
    local color = LineColor()
    for i = 1, #SAMPLES do
        local sample, mock = SAMPLES[i], shot.mocks[i]
        mock.name:SetText(sample.name)
        mock.mana:SetText(TEXT_MANA:format(sample.mana))
        mock.cast:SetText(TEXT_CAST:format(sample.cast))
        mock.line:SetText(SampleLine(sample) or "")
        mock.line:SetTextColor(color.r, color.g, color.b, 1)
    end
    if not On() then
        shot.note:SetText(TEXT_OFF)
    elseif S.Get("spellEfficiencyBonus") then
        shot.note:SetText(TEXT_SAMPLE_POWER:format(SAMPLE_POWER))
    else
        shot.note:SetText(TEXT_SAMPLE_BASE)
    end
end

ns.SpellEfficiencyStudio = { height = STAGE_H, states = STATES, new = NewPreview, paint = PaintPreview }

hooksecurefunc(S, "Set", OnSettingChanged)
hooksecurefunc(ns, "Apply", Apply)
Apply()

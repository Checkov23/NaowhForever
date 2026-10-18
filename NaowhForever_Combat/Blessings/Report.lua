-- Report.lua: the paladins' blessings as lines of chat, to the group or yourself (B.ReportChannels, B.Report).
local ns = _G.NaowhForever

local B = ns.Blessings
local MyName, Store, Others = B.MyName, B.Store, B.Others

local LINE_MAX = 240
local TEXT_HEADER = ns.L("--- Paladin blessings ---")
local TEXT_END = ns.L("--- End of blessings ---")
local TEXT_NOTHING = ns.L("Nothing")
local TEXT_NONE = ns.L("There are no paladins to report.")
local TEXT_COMBAT = ns.L("Reports are sent outside combat.")

local function InRaid() return IsInRaid() end
local function InParty() return IsInGroup() end
local function InInstanceGroup() return LE_PARTY_CATEGORY_INSTANCE ~= nil and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) end
local function InGuild() return IsInGuild() end
local function Always() return true end

local CHANNELS = {
    { key = "SELF", label = ns.L("Yourself"), can = Always },
    { key = "SAY", label = ns.L("Say"), can = Always },
    { key = "PARTY", label = ns.L("Party"), can = InParty },
    { key = "RAID", label = ns.L("Raid"), can = InRaid },
    { key = "INSTANCE_CHAT", label = ns.L("Instance"), can = InInstanceGroup },
    { key = "GUILD", label = ns.L("Guild"), can = InGuild },
}

function B.ReportChannels()
    local list = {}
    for _, channel in ipairs(CHANNELS) do
        if channel.can() then list[#list + 1] = channel end
    end
    return list
end

local function Given(plan)
    local byBlessing, order = {}, {}
    for _, class in ipairs(B.CLASSES) do
        local key = plan.classes[class]
        if key then
            if not byBlessing[key] then
                byBlessing[key] = {}
                order[#order + 1] = key
            end
            table.insert(byBlessing[key], B.ClassName(class))
        end
    end
    local parts = {}
    for _, key in ipairs(order) do
        parts[#parts + 1] = B.SpellName(key) .. " (" .. table.concat(byBlessing[key], ", ") .. ")"
    end
    if plan.salv then parts[#parts + 1] = B.SpellName(B.SALVATION.key) end
    if plan.aura then parts[#parts + 1] = B.SpellName(plan.aura) end
    return #parts > 0 and table.concat(parts, ", ") or TEXT_NOTHING
end

local function Split(text, out)
    while #text > LINE_MAX do
        local comma = text:sub(1, LINE_MAX):match("^.*(), ")
        out[#out + 1] = text:sub(1, comma and comma - 1 or LINE_MAX)
        text = "  " .. text:sub(comma and comma + 2 or LINE_MAX + 1)
    end
    out[#out + 1] = text
end

function B.ReportLines()
    local plans = {}
    if B.IsPaladin() then plans[1] = { who = MyName(), plan = Store() } end
    local names = {}
    for who in pairs(Others()) do names[#names + 1] = who end
    table.sort(names)
    for _, who in ipairs(names) do plans[#plans + 1] = { who = who, plan = Others()[who] } end
    if #plans == 0 then return end
    local lines = { TEXT_HEADER }
    for _, entry in ipairs(plans) do
        Split(Ambiguate(entry.who, "short") .. ": " .. Given(entry.plan), lines)
    end
    lines[#lines + 1] = TEXT_END
    return lines
end

function B.Report(channel)
    if InCombatLockdown() then return ns.Print(TEXT_COMBAT) end
    local lines = B.ReportLines()
    if not lines then return ns.Print(TEXT_NONE) end
    for _, line in ipairs(lines) do
        if channel == "SELF" then ns.Print(line) else SendChatMessage(line, channel) end
    end
end

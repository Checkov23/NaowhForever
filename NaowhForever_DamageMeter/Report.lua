-- Report.lua: a report of the meter to chat.
local ns = _G.NaowhForever

local DM = ns.DamageMeter
local S = DM.Settings
local Format, Plain = DM.Format, DM.Plain

local TEXT_COMBAT = ns.L("Reports are sent outside combat.")
local TEXT_EMPTY = ns.L("There is nothing to report yet.")
local LINE, LINE_RATE = "%d. %s  %s", "%s (%s)"
local HEADER = "%s, %s"

local function InRaid() return IsInRaid() end
local function InParty() return IsInGroup() end
local function InInstanceGroup() return LE_PARTY_CATEGORY_INSTANCE ~= nil and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) end
local function InGuild() return IsInGuild() end
local function Always() return true end

local CHANNELS = {
    { key = "SELF", label = "Yourself", can = Always },
    { key = "SAY", label = "Say", can = Always },
    { key = "PARTY", label = "Party", can = InParty },
    { key = "RAID", label = "Raid", can = InRaid },
    { key = "INSTANCE_CHAT", label = "Instance", can = InInstanceGroup },
    { key = "GUILD", label = "Guild", can = InGuild },
}

function DM.Channels()
    local list = {}
    for _, channel in ipairs(CHANNELS) do
        if channel.can() then list[#list + 1] = channel end
    end
    return list
end

function DM.ReportLines(session, mode, sessionName, count, withRate)
    local lines = { HEADER:format(mode.label, sessionName) }
    local sources = session.combatSources
    for i = 1, #sources do
        if #lines > count then break end
        local source = sources[i]
        local name, total, rate = DM.DisplayName(source), source.totalAmount, source.amountPerSecond
        if Plain(name, "string") and Plain(total, "number") then
            local value = Format(total)
            if withRate and mode.rate and Plain(rate, "number") then value = LINE_RATE:format(value, Format(rate)) end
            lines[#lines + 1] = LINE:format(#lines, name, value)
        end
    end
    return lines
end

function DM.Report(channel, modeKey, sessionKey, fightID)
    if InCombatLockdown() then ns.Print(TEXT_COMBAT) return end
    local lines = DM.ReportLines(DM.Session(modeKey, sessionKey, fightID), DM.Mode(modeKey),
        DM.SessionName(sessionKey, fightID), S.Get("reportLines"), DM.HasColumn(1, "rate"))
    if #lines < 2 then ns.Print(TEXT_EMPTY) return end
    for _, line in ipairs(lines) do
        if channel == "SELF" then ns.Print(line) else SendChatMessage(line, channel) end
    end
end

-- Run with Lua 5.1 from the repository root: the Blessings report (every paladin's plan as lines of
-- chat, split before the chat limit, to yourself or a channel you are in, never in combat) and the
-- status a paladin shares (Symbols of Kings, Lay on Hands and Divine Intervention).
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local grouped, raid, instanceGroup, guild, combat = false, false, false, false, false
local sent, printed = {}, {}
local known, cooldown, symbols, now = {}, {}, 7, 1000
local mine = { classes = { WARRIOR = "might", ROGUE = "might", MAGE = "kings" }, salv = true, aura = "devotion" }
local others = {}
local NAMES = { might = "Blessing of Might", kings = "Blessing of Kings", salvation = "Blessing of Salvation",
    devotion = "Devotion Aura", wisdom = "Blessing of Wisdom" }
local B = {
    CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" },
    SALVATION = { key = "salvation" },
    SYMBOL_OF_KINGS = 21177,
    Secret = function(v) return v == "SECRET" end,
    IsPaladin = function() return true end,
    MyName = function() return "Glyadin Skywolf" end,
    Store = function() return mine end,
    Others = function() return others end,
    SpellName = function(key) return NAMES[key] end,
    ClassName = function(class) return class:sub(1, 1) .. class:sub(2):lower() end,
    HighestKnown = function(ids)
        for i = #ids, 1, -1 do if known[ids[i]] then return ids[i] end end
    end,
}
local env = setmetatable({
    NaowhForever = { Blessings = B, L = function(s) return s end, Print = function(m) printed[#printed + 1] = m end },
    IsInRaid = function() return raid end,
    IsInGroup = function(category)
        if category then return instanceGroup end
        return grouped
    end,
    IsInGuild = function() return guild end,
    LE_PARTY_CATEGORY_INSTANCE = 2,
    InCombatLockdown = function() return combat end,
    SendChatMessage = function(text, channel) sent[#sent + 1] = { text, channel } end,
    Ambiguate = function(name) return (name:gsub(" .*", "")) end,
    GetTime = function() return now end,
    C_Item = { GetItemCount = function() return symbols end },
    C_Spell = { GetSpellCooldown = function(id) return cooldown[id] end },
}, { __index = _G })
env._G = env
for _, file in ipairs({ "Status.lua", "Report.lua" }) do
    local chunk = assert(loadfile("NaowhForever_Combat/Blessings/" .. file))
    setfenv(chunk, env)
    chunk("NaowhForever", env.NaowhForever)
end

local function Keys(list)
    local out = {}
    for _, channel in ipairs(list) do out[#out + 1] = channel.key end
    return table.concat(out, ",")
end

check("alone: yourself and say", Keys(B.ReportChannels()) == "SELF,SAY")
grouped = true
check("in a party", Keys(B.ReportChannels()) == "SELF,SAY,PARTY")
raid, instanceGroup, guild = true, true, true
check("in a raid, an instance group and a guild", Keys(B.ReportChannels()) == "SELF,SAY,PARTY,RAID,INSTANCE_CHAT,GUILD")

local lines = B.ReportLines()
check("a header and a footer", lines[1] == "--- Paladin blessings ---" and lines[#lines] == "--- End of blessings ---")
check("you: each blessing with its classes, Salvation and the aura",
    lines[2] == "Glyadin: Blessing of Might (Warrior, Rogue), Blessing of Kings (Mage), Blessing of Salvation, "
        .. "Devotion Aura")
others["Bram Hollow"] = { classes = { PRIEST = "wisdom" } }
others["Alma Reed"] = { classes = {} }
lines = B.ReportLines()
check("the others follow, by name", lines[3] == "Alma: Nothing" and lines[4] == "Bram: Blessing of Wisdom (Priest)")

B.Report("RAID")
check("sent to the channel, line by line", #sent == 5 and sent[1][2] == "RAID" and sent[1][1] == "--- Paladin blessings ---")
sent = {}
B.Report("SELF")
check("to yourself, nothing is sent", #sent == 0 and #printed == 5)
printed = {}
combat = true
B.Report("RAID")
check("in combat nothing goes", #sent == 0 and #printed == 1)
combat = false

B.IsPaladin = function() return false end
others["Bram Hollow"], others["Alma Reed"] = nil, nil
printed = {}
B.Report("PARTY")
check("no paladins: a word, no chat", #sent == 0 and #printed == 1)
B.IsPaladin = function() return true end

local many = { classes = {} }
for i, class in ipairs(B.CLASSES) do many.classes[class] = (i % 2 == 0) and "wisdom" or "might" end
NAMES.wisdom = string.rep("W", 120)
NAMES.might = string.rep("M", 120)
others["Long Name"] = many
lines = B.ReportLines()
local longest = 0
for _, line in ipairs(lines) do longest = math.max(longest, #line) end
check("a long plan is split before the chat limit", longest <= 240 and #lines == 5 and lines[4]:sub(1, 2) == "  ")
others["Long Name"] = nil

-- The status a paladin shares.
check("no spells known: nothing to time", select(2, B.OwnStatus()) == -1 and select(3, B.OwnStatus()) == -1)
known[10310], known[19752] = true, true
check("known and ready", select(2, B.OwnStatus()) == 0 and select(3, B.OwnStatus()) == 0)
cooldown[10310] = { startTime = 900, duration = 3600 }
cooldown[19752] = { startTime = 995, duration = 1.5 }
local sym, loh, di = B.OwnStatus()
check("the Symbols and the time left on Lay on Hands", sym == 7 and loh == 3500)
check("the global cooldown is not a cooldown", di == 0)
cooldown[10310] = { startTime = "SECRET", duration = 3600 }
check("a hidden cooldown reads as ready, not an error", select(2, B.OwnStatus()) == 0)
cooldown[10310] = { startTime = 900, duration = 3600 }
check("the message", B.StatusMessage() == "I|7|3500|0")
check("the spells to watch", B.IsStatusSpell(633) and B.IsStatusSpell(19752) and not B.IsStatusSpell(20217))

print(("test-blessing-report: %d checks passed"):format(checks))

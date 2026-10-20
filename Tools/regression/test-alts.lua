-- Loads Alts.lua against stubbed bags and tooltips and checks the Alt Item Counts
-- lines (who holds the item and where, most first, nothing when it is only in the bags you
-- look at), the bag count kept for this character, and what a tooltip refresh and a bag scan
-- cost: an item tooltip in the bags is redrawn several times a second while hovered.
-- Run from the repo root: lua Tools/regression/test-alts.lua
local f = assert(io.open(arg[1] or "NaowhForever_QoL/Loot/Alts.lua", "rb"))
local source = f:read("*a"); f:close()

local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end
local Measure = dofile("Tools/regression/measure.lua")(check)

local function Noop() end
local frames = {}
local function Frame()
    local w = { scripts = {}, events = {} }
    function w:SetScript(k, fn) self.scripts[k] = fn end
    function w:RegisterEvent(e) self.events[e] = true end
    function w:UnregisterAllEvents() for k in pairs(self.events) do self.events[k] = nil end end
    frames[#frames + 1] = w
    return w
end

local values = { enabled = true, altCounts = true }
local S = { Get = function(k) return values[k] end, Set = function(k, v) values[k] = v end }

-- bag -> slot -> the item info the client hands back, made once.
local BAGS = {
    [0] = { { itemID = 10, stackCount = 5 }, { itemID = 30, stackCount = 7 }, false, { itemID = 10 } },
}
BAGS[0][4].stackCount = nil

local account = { alts = { ["Realm-Alliance"] = {
    Alt = { class = "MAGE", bags = { [10] = 2 }, mail = { [10] = 1 } },
    Third = { class = "ROGUE", bags = { [20] = 4 } },
    ["Third Other"] = { class = "ROGUE", full = true },
    You = { class = "PALADIN", bank = { [10] = 3 } },
} } }

local post
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    QoLSettings = S, Apply = Noop, QoLConstants = dofile("Tools/regression/qol_constants.lua"),
    AccountSettings = function() return account end,
    Color = function() return "|cff0091edNaowh|r" end,
}
local COLORS = {}
for class, hex in pairs({ PALADIN = "|cfff58cba", MAGE = "|cff69ccf0", ROGUE = "|cfffff569" }) do
    COLORS[class] = { WrapTextInColorCode = function(_, text) return hex .. text .. "|r" end }
end
local env = setmetatable({
    _G = { NaowhForever = ns },
    CreateFrame = Frame,
    hooksecurefunc = function(t, name, hook)
        local orig = t[name]
        t[name] = function(...) orig(...); hook(...) end
    end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    GetRealmName = function() return "Realm" end,
    UnitFactionGroup = function() return "Alliance" end,
    UnitName = function() return "You" end,
    GetUnitName = function() return "You Surname" end,
    UnitClass = function() return "Paladin", "PALADIN" end,
    UnitLevel = function() return 20 end,
    GetMoney = function() return 1234 end,
    BACKPACK_CONTAINER = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4,
    Enum = { TooltipDataType = { Item = 0 }, BagIndex = { CharacterBankTab_1 = 6, CharacterBankTab_9 = 14 } },
    C_Container = {
        GetContainerNumSlots = function(bag) return BAGS[bag] and #BAGS[bag] or 0 end,
        GetContainerItemInfo = function(bag, slot) return BAGS[bag][slot] or nil end,
    },
    C_ClassColor = { GetClassColor = function(class) return COLORS[class] end },
    TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) post = fn end },
}, { __index = _G })
local chunk = assert(loadstring(source, "Alts"))
setfenv(chunk, env)
chunk()

local events, boot
for _, w in ipairs(frames) do
    if w.events.PLAYER_LOGIN then boot = w else events = w end
end
boot.scripts.OnEvent(boot, "PLAYER_LOGIN")
check("bag scan listens once Alt Item Counts is on", events.events.BAG_UPDATE_DELAYED == true)

local realm = account.alts["Realm-Alliance"]
local you = realm["You Surname"]
check("you are kept by your whole name, moved from your first name", you and you.bank[10] == 3 and realm.You == nil)
check("and marked as saved by your whole name", you.full == true)
check("your bags counted, stacks added up", you.bags[10] == 6 and you.bags[30] == 7)
local kept = you.bags
BAGS[0][2] = false
events.scripts.OnEvent(events, "BAG_UPDATE_DELAYED")
check("an item gone from the bags is gone from the count", you.bags[30] == nil and you.bags[10] == 6)
check("the count is kept in the same table", you.bags == kept)

local tip = { n = 0, left = {}, right = {} }
function tip:AddDoubleLine(l, r)
    self.n = self.n + 1
    self.left[self.n], self.right[self.n] = l, r
end
local data = { id = 0 }
local function Lines(id)
    tip.n, data.id = 0, id
    post(tip, data)
    local out = {}
    for i = 1, tip.n do out[i] = tip.left[i] .. " = " .. tostring(tip.right[i]) end
    return table.concat(out, " | ")
end

check("held by you and an alt, most first", Lines(10) == "Total owned = 12"
    .. " |   |cfff58cbaYou Surname|r = 6 bags, 3 bank |   |cff69ccf0Alt|r = 2 bags, 1 mail")
check("held only by an alt", Lines(20) == "Total owned = 4 |   |cfffff569Third|r = 4 bags")
BAGS[0][2] = { itemID = 30, stackCount = 7 }
events.scripts.OnEvent(events, "BAG_UPDATE_DELAYED")
check("only in the bags you look at: no lines", Lines(30) == "")
check("nobody has it: no lines", Lines(40) == "")

local listed, full = {}, {}
for _, alt in ipairs(ns.AltList()) do full[alt.name] = alt.full end
check("the list says which alts were saved by their whole name", full["Third Other"] == true and full.Third == false)

for _, alt in ipairs(ns.AltList()) do listed[#listed + 1] = alt.name end
table.sort(listed)
check("the Alts list leaves you out by your whole name", table.concat(listed, ",") == "Alt,Third,Third Other")

do
    local other = { alts = { ["Realm-Alliance"] = { You = { class = "MAGE", money = 5 } } } }
    ns.AccountSettings = function() return other end
    local again = assert(loadstring(source, "Alts"))
    setfenv(again, env)
    local before = #frames
    again()
    for i = before + 1, #frames do
        if frames[i].events.PLAYER_LOGIN then frames[i].scripts.OnEvent(frames[i], "PLAYER_LOGIN") end
    end
    local saved = other.alts["Realm-Alliance"]
    check("a first name saved by another class is not taken over", saved.You.class == "MAGE"
        and saved["You Surname"].class == "PALADIN" and saved["You Surname"].money == 1234)
    ns.AccountSettings = function() return account end
end

Measure("an item tooltip refresh", 0.05, function() tip.n, data.id = 0, 10; post(tip, data) end)
Measure("a bag scan", 0.05, function() events.scripts.OnEvent(events, "BAG_UPDATE_DELAYED") end)

print(("PASS alts: %d checks"):format(checks))

-- Run with Lua 5.1 from the repository root: what a pasted string or another player's message can
-- do to us. Bombs, cycles, shared tables, deep nesting, numbers that do not save, escape codes in
-- names, flooding and claims made for someone else are each refused without an error and without
-- touching saved data. Offline: no client taint, rendering or real addon channel.
rawset(_G, "C_AddOns", { DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end })
strmatch = string.match
dofile("Libs/LibStub/LibStub.lua")
dofile("Libs/LibDeflate/LibDeflate.lua")
dofile("Libs/LibSerialize/LibSerialize.lua")
local LS, LD = LibStub("LibSerialize"), LibStub("LibDeflate")
local LoadDecode = dofile("Tools/regression/load_decode.lua")

local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local function Encode(value) return LD:EncodeForPrint(LD:CompressDeflate(LS:Serialize(value))) end
local function Timed(fn)
    local t = os.clock()
    local a, b = fn()
    return os.clock() - t, a, b
end

local D = LoadDecode(setmetatable({}, { __index = _G }))
local SMALL = { maxChars = 100000, maxBytes = 1048576, maxDepth = 8, maxValues = 20000 }

do -- the size scan agrees with LibDeflate on every level and kind of input
    math.randomseed(11)
    for trial = 1, 24 do
        local parts = {}
        for i = 1, math.random(0, 6000) do parts[i] = string.char(32 + math.random(0, trial % 4 * 30 + 1)) end
        local s = table.concat(parts) .. string.rep("ab", math.random(0, 3000))
        local packed = LD:CompressDeflate(s, { level = trial % 10 })
        check("scan size matches, trial " .. trial, D.InflatedSize(packed, 1e9) == #s)
    end
    check("an empty stream is broken", D.InflatedSize("", 10) == nil)
    check("a truncated stream is broken", D.InflatedSize(LD:CompressDeflate(string.rep("xyz", 999)):sub(1, 5), 1e9) == nil)
end

do -- a decompression bomb is refused at its cap, before LibDeflate builds it
    local bomb = LD:EncodeForPrint(LD:CompressDeflate(string.rep("A", 8 * 1024 * 1024)))
    local took, value, why = Timed(function() return D.String(bomb, SMALL) end)
    check("bomb refused", value == nil and why == "damaged")
    check(("bomb refused fast (%.3f s)"):format(took), took < 1)
    check("a body over the cap is refused unread", select(2, D.String(string.rep("a", 100001), SMALL)) == "big")
    for _, junk in ipairs({ "", "!!!!", "abcd", string.rep("z", 5000), Encode({ name = string.rep("q", 300), n = 12345 }):sub(1, 20) }) do
        check("junk is damaged, not an error: " .. #junk, D.String(junk, SMALL) == nil)
    end
end

do -- cycles, shared tables, depth, keys and numbers
    local cycle = { name = "x" }
    cycle.self = cycle
    check("a cycle is refused", D.String(Encode(cycle), SMALL) == nil)
    local layer = { 1 }
    for _ = 1, 25 do layer = { layer, layer } end
    local billion = Encode({ v = 1, layer = layer })
    check("shared tables cost little to send", #billion < 2000)
    local took, value = Timed(function() return D.String(billion, { maxChars = 1e6, maxBytes = 4194304,
        maxDepth = 32, maxValues = 1000000 }) end)
    check(("2^25 paths through shared tables are refused (%.3f s)"):format(took), value == nil and took < 2)
    local deep = {}
    for _ = 1, 40 do deep = { deep } end
    check("nesting past the cap is refused", D.String(Encode(deep), SMALL) == nil)
    check("a table key is refused", D.String(Encode({ [{}] = 1 }), SMALL) == nil)
    check("a boolean key is refused", D.String(Encode({ [true] = 1 }), SMALL) == nil)
    check("infinity is refused", D.String(Encode({ w = math.huge }), SMALL) == nil)
    check("minus infinity is refused", D.String(Encode({ w = -math.huge }), SMALL) == nil)
    check("not-a-number is refused", D.String(Encode({ w = 0 / 0 }), SMALL) == nil)
    check("plain data comes back", D.String(Encode({ v = 1, list = { 1, 2.5, "x", true } }), SMALL).list[2] == 2.5)
end

do -- text from outside shows as text
    check("escapes and line breaks go", D.Text("|cffe6cc80Naowh|r\n[Naowh]: |Hurl:x|h[click]|h |TInterface\\x:0|t", 200)
        == "cffe6cc80Naowhr[Naowh]: Hurl:xh[click]h TInterface\\x:0t")
    check("capped", #D.Text(string.rep("a", 500), 40) == 40)
    check("not a string is nil", D.Text(5) == nil and D.Text({}) == nil)
end

-------------------------------------------------------------------------------
--  The Profiles page's import, and an old Reminder Pack string, on the real libraries
-------------------------------------------------------------------------------
local function World()
    local w = { profiles = { Default = { tankReminder = {} } }, account = {}, printed = {} }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        UI = { Widgets = {} }, CODE_BUILD = "test", Macros = { C = { LIMIT = 255 } },
        THEME = { accent = {}, muted = {}, fg = {}, panel = {}, bg = {}, line = {} },
        Color = function(_, text) return text or "" end,
        Print = function(m) w.printed[#w.printed + 1] = m end,
        ListProfiles = function() return {} end,
        SettingsRoot = function() return w.profiles.Default end,
        AccountSettings = function() return w.account end,
        ModuleDefaults = function(key) return key == "qol" and { enabled = true } or nil end,
        ActiveProfileName = function() return "Default" end,
        ProfileExists = function(name) return w.profiles[name] ~= nil end,
        ProfileTable = function(name) return w.profiles[name] end,
        ProfileRoot = function(name)
            w.profiles[name] = w.profiles[name] or { tankReminder = {} }
            return w.profiles[name]
        end,
        EnsureProfile = function(name)
            w.profiles[name] = w.profiles[name] or {}
            return w.profiles[name]
        end,
        SwitchProfile = function(name) w.switched = name end,
        RefreshRuntime = function() end,
    }
    local env = setmetatable({ NaowhForever = ns, UnitName = function() return "Me" end, UnitGUID = function() return "Player-1" end, date = os.date,
        CreateFrame = function() return { SetScript = function() end } end }, { __index = _G })
    env._G = env
    ns.Shared = { Decode = LoadDecode(env) }
    local chunk = assert(loadfile("Core/Profiles/ProfileShare.lua"))
    setfenv(chunk, env)
    chunk()
    w.ns, w.env = ns, env
    return w
end

local function Profile(payload) return "NFPROFILE1:" .. Encode(payload) end

do -- a profile string: names, consumables, class macros, the look and BiS lists
    local w = World()
    local layer = {}
    for _ = 1, 22 do layer = { layer, layer } end
    local took, bomb = Timed(function() return w.ns.DecodeProfile(Profile({ format = 1, parts = { settings = { qol = layer } } })) end)
    check(("a shared-table profile is refused without a freeze (%.3f s)"):format(took), bomb == nil and took < 2)

    local payload = w.ns.DecodeProfile(Profile({ format = 1,
        name = "|TInterface\\AddOns\\NaowhForever\\Core\\Badges\\Media\\BadgeNaowhChat.tga:0|t Official",
        author = "|cffe6cc80Naowh|r\n[Naowh]: trust me", made = "|Hurl:x|h",
        parts = {
            consumables = { { category = "food", itemID = 13931 }, { category = "food", itemID = -1 } },
            reminders = { customReminders = { ["1"] = { a = { name = 5 } } },
                utilityReminders = { consumables = { { category = "food", itemID = 13931 } } } },
            macros = { classMacros = { PALADIN = { { name = "Fine", body = string.rep("x", 900) } } } },
            look = { windowScale = "big", themeColors = 7, uiFont = "Naowh" },
            bisLists = { MAGE = { { name = "|cffff0000Red|r\nList", spec = "fire", slots = { [1] = 101, [4] = 5,
                [2] = "x", [3] = 1e300, [99] = 7 }, extra = { [1] = { 102, -1, 0.5, 103 } } } } },
        } }))
    check("the profile decodes", payload ~= nil)
    check("its name, author and date are plain text", not payload.name:find("|", 1, true)
        and #payload.name <= 64 and payload.author == "cffe6cc80Naowhr[Naowh]: trust me" and payload.made == "Hurl:xh")
    check("consumables are left out", payload.parts.consumables == nil)
    check("an old reminders part is gone, and cannot stand in for them", payload.parts.reminders == nil)
    check("class macros past the game's limits are left out", payload.parts.macros.classMacros == nil)
    local _, added = w.ns.ImportProfile(payload, { consumables = true, macros = true, look = true, bisLists = true }, "Mine")
    check("the look takes only values of the right type", w.account.windowScale == nil and w.account.themeColors == nil
        and w.account.uiFont == "Naowh")
    local list = w.account.bisLists.MAGE.lists[1]
    check("a BiS list lands cleaned", added.bisLists == 1 and list.name == "cffff0000RedrList" and list.spec == "fire")
    check("only gear slots holding item IDs", list.slots[1] == 101 and list.slots[2] == nil and list.slots[3] == nil
        and list.slots[4] == nil and list.slots[99] == nil)
    check("and picks that are item IDs", #list.extra[1] == 2 and list.extra[1][2] == 103)
    check("the reminders' store untouched", next(w.profiles.Mine.tankReminder) == nil)
end

do -- an old Reminder Pack string, even a bomb, is refused unread and changes nothing
    local w = World()
    local data = { presets = { ["250"] = { p1 = { name = "Tank", list = { 1 } } } },
        utilityReminders = { consumables = { { category = "food", itemID = 13931 } } } }
    local pack = "NSRPACK2:" .. Encode({ format = 1, name = "|cff0091edNaowh Official|r", data = data })
    local payload, why = w.ns.DecodeProfile(pack)
    check("a pack is refused with a message", payload == nil and why == "Reminder Packs are no longer supported.")
    local bomb = "NSRPACK2:" .. LD:EncodeForPrint(LD:CompressDeflate(string.rep("\0", 6 * 1024 * 1024)))
    local took, value, said = Timed(function() return w.ns.DecodeProfile(bomb) end)
    check(("a pack bomb is refused unread (%.3f s)"):format(took), value == nil and said == why and took < 1)
    local ok, told = w.env.NaowhForever_API:ImportProfile(pack, "Naowh")
    check("the installer's import refuses it and says why", ok == false and told == why
        and w.printed[1] == "Naowh Forever import failed: " .. why)
    check("no profile is made or switched to", w.profiles.Naowh == nil and w.switched == nil
        and next(w.profiles.Default.tankReminder) == nil)
end

-------------------------------------------------------------------------------
--  The Wago-facing half of NaowhForever_API: any profile exports, the same string decodes
-------------------------------------------------------------------------------
do
    local w = World()
    local API = w.env.NaowhForever_API
    w.profiles.Other = { qol = { enabled = false } }
    w.profiles.Default.qol = { enabled = true }
    local qolStore = { key = "qol", Default = function() return true end }
    w.ns.ModuleAddons = function()
        return { { addon = "NaowhForever_QoL", store = qolStore, key = "enabled", on = true },
            { addon = "NaowhForever_Macros", key = "enabled", on = false } }
    end
    w.ns.ListProfiles = function() return { "Default", "Other" } end
    w.ns.SwitchProfile = function(name) w.switched = name return true end
    w.ns.KnownCharacters = function() return { { char = "Me-Realm", profile = "Other" } } end
    local keys = API:GetProfileKeys()
    check("every profile is a key", keys.Default == true and keys.Other == true and not keys.Nope)
    check("the current profile key", API:GetCurrentProfileKey() == "Default")
    check("assignments are character to profile", API:GetProfileAssignments()["Me-Realm"] == "Other")
    local str = API:ExportProfile("Other")
    check("a profile that is not current exports as a profile string", type(str) == "string" and str:sub(1, 11) == "NFPROFILE1:")
    local payload = w.ns.DecodeProfile(str)
    check("it carries that profile, named after it", payload.name == "Other" and payload.parts.settings.qol.enabled == false)
    local modules = payload.parts.settings.__modules
    check("its modules are that profile's switches, not this character's", modules.NaowhForever_QoL == false)
    check("a module with no store here is left out", modules.NaowhForever_Macros == nil)
    check("exporting it leaves the profile as it was", w.profiles.Other.tankReminder == nil)
    local current = w.ns.DecodeProfile(API:ExportProfile("Default")).parts.settings
    check("the current profile still exports its own", current.qol.enabled == true)
    check("with this character's modules", current.__modules.NaowhForever_QoL == true
        and current.__modules.NaowhForever_Macros == false)
    check("decoding gives the parts", API:DecodeProfileString(str).settings.qol.enabled == false)
    check("decoding junk gives nil", API:DecodeProfileString("garbage") == nil and API:DecodeProfileString(nil) == nil)
    check("an unknown or bad key exports nothing and makes no profile", API:ExportProfile("Nope") == nil
        and API:ExportProfile(nil) == nil and API:ExportProfile({}) == nil and w.profiles.Nope == nil)
    check("SetProfile switches to an existing profile", API:SetProfile("Other") == true and w.switched == "Other")
    w.switched = nil
    check("SetProfile ignores an unknown one", API:SetProfile("Nope") == false and w.switched == nil)
end

-------------------------------------------------------------------------------
--  Blessings: a paladin's per-player choices are capped
-------------------------------------------------------------------------------
do
    local frames = {}
    local account = {}
    local meta = { __index = function() return function() end end }
    local function Frame()
        local f = setmetatable({ scripts = {} }, meta)
        function f:SetScript(k, fn) self.scripts[k] = fn end
        frames[#frames + 1] = f
        return f
    end
    local units = {
        player = { "Me Self", "Me", "WARRIOR" },
        party1 = { "Holy Man", "Holy", "PALADIN" },
    }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QoLSettings = { Get = function() return true end, Set = function() end },
        THEME = { fg = {}, muted = {}, accent = {}, bg = {} }, AccountSettings = function() return account end,
        Print = function() end,
        Apply = function() end, UI = { RefreshPage = function() end },
        Shared = { Style = dofile("Tools/regression/shared_style.lua"), Parts = { HudFont = function() end } },
        ShowUnlockMode = function() end, HideUnlockMode = function() end }
    local env = setmetatable({ NaowhForever = ns, CreateFrame = Frame, hooksecurefunc = function() end,
        C_Timer = { After = function() end }, GetTime = function() return 0 end,
        GetRealmName = function() return "Forever" end, C_SpellBook = { IsSpellKnown = function() return true end },
        IsInRaid = function() return false end, GetNumSubgroupMembers = function() return 1 end,
        GetNumGroupMembers = function() return 2 end, GetNormalizedRealmName = function() return "Forever" end,
        UnitFullName = function(u) return units[u] and units[u][1] end,
        UnitName = function(u) return units[u] and units[u][2] end,
        UnitClass = function(u) return units[u] and units[u][3], units[u] and units[u][3] end,
        UnitGUID = function(u) return units[u] and ("Player-1-" .. u) end,
        Ambiguate = function(name) return name end, issecretvalue = function() return false end,
        UnitIsGroupLeader = function() return false end, UnitIsGroupAssistant = function() return false end,
    }, { __index = _G })
    env._G = env
    for _, path in ipairs(dofile("Tools/regression/toc_files.lua")("^NaowhForever_Combat/Blessings/.*%.lua$")) do
        if not path:find("/UI/Window%.lua$") then
            local chunk = assert(loadfile(path))
            setfenv(chunk, env)
            chunk("NaowhForever", ns)
        end
    end
    local fire
    for _, f in ipairs(frames) do
        if f.scripts.OnEvent and not fire then
            local ok = pcall(f.scripts.OnEvent, f, "CHAT_MSG_ADDON", "NaowhBless", "F|----------|", "PARTY", "Holy Man")
            if ok and ns.Blessings.Others()["Holy Man"] then fire = f end
        end
    end
    check("a paladin in the group is heard", fire ~= nil)
    local function Send(text, sender)
        fire.scripts.OnEvent(fire, "CHAT_MSG_ADDON", "NaowhBless", text, "PARTY", sender or "Holy Man")
    end
    local n = 0
    for batch = 1, 60 do
        local parts = {}
        for i = 1, 12 do
            n = n + 1
            parts[i] = ("Player-9-%06X=m"):format(n)
        end
        Send("P|" .. (batch == 1 and 1 or 2) .. "|" .. table.concat(parts, ","))
    end
    local count = 0
    for _ in pairs(ns.Blessings.Others()["Holy Man"].players) do count = count + 1 end
    check(("720 claimed players keep 40 (%d)"):format(count), count == 40)
    Send("F|----------|")
    Send("P|2|Player-9-FFFFFF=m")
    count = 0
    for _ in pairs(ns.Blessings.Others()["Holy Man"].players) do count = count + 1 end
    check("a plan update does not reset the cap", count == 40)
    Send("P|1|Player-9-000001=k")
    count = 0
    for _ in pairs(ns.Blessings.Others()["Holy Man"].players) do count = count + 1 end
    check("a fresh list starts over", count == 1)
    Send("P|1|Player-9-000001=k", "Stranger Danger")
    check("a sender with no plan is ignored", ns.Blessings.Others()["Stranger Danger"] == nil)

    -- Salvation is no class blessing any more: an older client's class Salvation reads as Salvation given,
    -- the flag in the known list says the same, and a Salvation code in the aura place is no plan at all.
    Send("F|-s--------|msw")
    local holy = ns.Blessings.Others()["Holy Man"]
    check("an older client's class Salvation becomes Salvation given", holy.classes.PALADIN == nil and holy.salv == true)
    check("and it is a spell they know", holy.known.salvation == true)
    Send("F|----------|mw")
    check("no code and no flag: no Salvation", ns.Blessings.Others()["Holy Man"].salv == nil)
    Send("F|----------|mwsY")
    check("the flag in the known list says Salvation is on", ns.Blessings.Others()["Holy Man"].salv == true)
    Send("F|---------s|m")
    check("Salvation in the aura place is refused, the plan left as it was",
        ns.Blessings.Others()["Holy Man"].salv == true and ns.Blessings.Others()["Holy Man"].aura == nil)
    Send("P|1|Player-9-000002=s")
    local own = 0
    for _ in pairs(ns.Blessings.Others()["Holy Man"].players) do own = own + 1 end
    check("a player's own Salvation from an older client is not kept", own == 0)
    Send("V|Me Self-Forever|1")
    check("a Salvation setting from a player who cannot assign is ignored", ns.Blessings.Others()["Holy Man"].salv == true)

    -- Symbols of Kings and cooldowns come as numbers and are clamped; Free Assignment is a flag.
    Send("I|12|600|-1")
    local status = ns.Blessings.Others()["Holy Man"].status
    check("a paladin's Symbols and cooldowns are kept", status.symbols == 12 and status.loh == 600 and status.di == nil)
    Send("I|99999|0|0")
    check("a silly Symbol count is clamped", ns.Blessings.Others()["Holy Man"].status.symbols == 9999)
    Send("I|abc|0|0")
    Send("I|5|x|0")
    check("a status that is not numbers is ignored", ns.Blessings.Others()["Holy Man"].status.symbols == 9999)
    Send("I|7|0|0", "Stranger Danger")
    check("a status from a sender with no plan is ignored", ns.Blessings.Others()["Stranger Danger"] == nil)
    Send("F|----------|mwX")
    check("the flag in the known list says Free Assignment is on", ns.Blessings.Others()["Holy Man"].free == true)
    Send("F|----------|mw")
    check("and its absence says it is off", ns.Blessings.Others()["Holy Man"].free == nil)
    check("a plan update keeps the last status", ns.Blessings.Others()["Holy Man"].status.symbols == 9999)

    units.player[3] = "PALADIN"
    local store = ns.Blessings.Store()
    Send("S|Me Self-Forever|k---------")
    check("a paladin who does not lead cannot plan for you", next(store.classes) == nil)
    store.free = true
    Send("S|Me Self-Forever|k---------")
    check("with Free Assignment on, a paladin in the group can", store.classes.WARRIOR == "kings")
    Send("S|Me Self-Forever|-m--------", "Stranger Danger")
    check("with it on, someone who is not in the group still cannot", store.classes.WARRIOR == "kings"
        and store.classes.PALADIN == nil)
    units.party1[3] = "WARRIOR"
    Send("S|Me Self-Forever|-m--------")
    check("with it on, a player who is not a paladin and not an assistant cannot", store.classes.PALADIN == nil)
    units.party1[3] = "PALADIN"
    units.player[3] = "WARRIOR"
end

print(("PASS import safety: %d checks"):format(checks))

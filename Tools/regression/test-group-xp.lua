-- Offline behavior checks for Group XP; these do not emulate client taint, comms or rendering.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local NO_ADDON = "|cff9ca3afno addon|r"
-- Methods a stub frame lacks do nothing, from one shared function, so stubs add no garbage.
local function Noop() end
local NOOP_META = { __index = function() return Noop end }
local DEFAULTS = { enabled = true, groupXP = true, groupXPShowSelf = true, groupXPRaid = false, groupXPWidth = 260,
    groupXPFont = "", groupXPFontSize = 12, groupXPOutline = "OUTLINE", groupXPTexture = "", groupXPBgAlpha = 0.85 }
local GRADIENT = "Interface\\AddOns\\NaowhForever\\Core\\Media\\NaowhGradient.tga"

local function boot(settings)
    local s = { now = 0, timers = {}, sent = {}, created = {}, combat = false, group = true,
        raid = false, settings = settings or {},
        units = {
            player = { name = "You", surname = "Lightbringer", guid = "Player-1-01", class = "PALADIN", level = 20, xp = 500, max = 1000 },
            party1 = { name = "Tank", surname = "Ironhide", guid = "Player-1-02", class = "WARRIOR", level = 21 },
            party2 = { name = "Mage", surname = "Frostwhisper", guid = "Player-2-03", class = "MAGE", level = 19 },
        } }
    local function frame(kind, name, parent)
        local f = { kind = kind, parent = parent, scripts = {}, events = {}, fonts = {}, shown = true }
        setmetatable(f, NOOP_META)
        function f:SetScript(k, fn) self.scripts[k] = fn end
        function f:RegisterEvent(k) self.events[k] = true end
        function f:UnregisterAllEvents() self.events = {} end
        function f:Show() self.shown = true end
        function f:Hide() self.shown = false end
        function f:SetShown(v) self.shown = v and true or false end
        function f:SetSize(w, h) self.w, self.h = w, h end
        function f:SetHeight(h) self.h = h end
        function f:SetStatusBarTexture(path) self.texture = path end
        function f:SetColorTexture(_, _, _, a) self.alpha = a end
        function f:SetText(t) self.text = t end
        function f:SetValue(v) self.value = v end
        return f
    end
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"), QoLConstants = dofile("Tools/regression/qol_constants.lua"), THEME = { bg = {}, accent = { r = 0, g = 0.5, b = 1 } },
        Font = function(parent)
            local fs = frame("FontString", nil, parent)
            parent.fonts[#parent.fonts + 1] = fs
            return fs
        end,
        Solid = function() return frame("Texture") end, Border = function() return frame("Border") end,
        Apply = function() end, ShowUnlockMode = function() end,
        HideUnlockMode = function() end,
        UI = { AttachMover = function() return frame("Mover") end,
            TexturePath = function(name, own) if name == "" then return own end return "lsm:" .. name end },
        Shared = { Style = dofile("Tools/regression/shared_style.lua"),
            Parts = { HudFont = function(fs, font, size, outline) fs.font = font .. " " .. size .. " " .. outline end } } }
    ns.QoLSettings = {
        Get = function(k)
            local v = s.settings[k]
            if v == nil then v = DEFAULTS[k] end
            return v
        end,
        Set = function(k, v) s.settings[k] = v end,
    }
    local function partyCount()
        local n = 0
        while s.units["party" .. (n + 1)] do n = n + 1 end
        return n
    end
    local env = { _G = { NaowhForever = ns }, UIParent = frame("Parent"),
        CreateFrame = function(kind, name, parent)
            local f = frame(kind, name, parent)
            s.created[#s.created + 1] = f
            return f
        end,
        RAID_CLASS_COLORS = { PALADIN = { r = 1, g = 0.5, b = 0.7 }, WARRIOR = { r = 0.8, g = 0.6, b = 0.4 },
            MAGE = { r = 0.4, g = 0.8, b = 1 } },
        LE_PARTY_CATEGORY_INSTANCE = 2,
        IsInGroup = function(cat) return s.group and cat == nil end, IsInRaid = function() return s.raid end,
        GetNumSubgroupMembers = partyCount,
        GetNumGroupMembers = function() return partyCount() + 1 end,
        InCombatLockdown = function() return s.combat end,
        UnitLevel = function(u) return s.units[u] and s.units[u].level end,
        UnitXP = function() return s.units.player.xp end,
        UnitXPMax = function() return s.units.player.max end,
        UnitName = function(u) return s.units[u] and s.units[u].name end,
        UnitFullName = function(u) local m = s.units[u] if m then return m.name, m.surname end end,
        GetNormalizedRealmName = function() return "Forever" end,
        UnitGUID = function(u) return s.units[u] and s.units[u].guid end,
        UnitClass = function(u) return "x", s.units[u] and s.units[u].class end,
        UnitIsUnit = function(a, b) return a == b end,
        GetMaxLevelForPlayerExpansion = function() return 60 end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end end,
        issecretvalue = function(v) return type(v) == "table" and v.secret == true end,
        C_ChatInfo = { RegisterAddonMessagePrefix = function(p) s.prefix = p end,
            SendAddonMessage = function(p, msg, channel) s.sent[#s.sent + 1] = { p, msg, channel } end },
        C_Timer = { After = function(delay, fn) s.timers[#s.timers + 1] = { at = s.now + delay, fn = fn } end },
        hooksecurefunc = function(t, k, fn)
            local old = t[k]; t[k] = function(...) local r = old(...); fn(...); return r end
        end,
    }
    setmetatable(env, { __index = _G })
    local senders = assert(loadfile("Core/Senders.lua")); setfenv(senders, env); senders()
    local f = assert(io.open("NaowhForever_QoL/XP/GroupXP.lua", "rb"))
    local src = f:read("*a"); f:close()
    local chunk = assert(loadstring(src, "GroupXP")); setfenv(chunk, env); chunk()
    local events, bootFrame = s.created[1], s.created[2]
    s.events = events
    s.S = ns.QoLSettings
    function s.fire(event, ...) events.scripts.OnEvent(events, event, ...) end
    function s.msg(msg, sender, channel) s.fire("CHAT_MSG_ADDON", "NaowhGroupXP", msg, channel or "PARTY", sender) end
    function s.run(seconds)
        s.now = s.now + seconds
        local due = {}
        for i = #s.timers, 1, -1 do
            if s.timers[i].at <= s.now then due[#due + 1] = table.remove(s.timers, i) end
        end
        for _, t in ipairs(due) do t.fn() end
    end
    -- What each shown row reads, "Name: bar text", top to bottom.
    function s.rows()
        local out = {}
        for _, bar in ipairs(s.created) do
            if bar.kind == "StatusBar" and bar.parent.shown then
                out[#out + 1] = bar.parent.fonts[1].text .. ": " .. bar.fonts[1].text
            end
        end
        return table.concat(out, " | ")
    end
    function s.messages()
        local out = {}
        for _, m in ipairs(s.sent) do out[#out + 1] = m[2] end
        return table.concat(out, ",")
    end
    bootFrame.scripts.OnEvent(bootFrame, "PLAYER_LOGIN")
    s.display = s.created[3]
    return s
end

do -- off: no display, but numbers are still shared and kept
    local s = boot({ groupXP = false })
    check("off builds no display", #s.created == 2)
    s.fire("PLAYER_ENTERING_WORLD")
    s.run(2)
    check("off still shares", s.messages() == "R,2 Player-1-01 20 500 1000")
    s.msg("2 Player-1-02 21 300 1200", "Tank Ironhide")
    s.S.Set("groupXP", true)
    check("switching on shows what was heard while off",
        s.rows() == "You: Lv 20  50.0% | Tank: Lv 21  25.0% | Mage: Lv 19  " .. NO_ADDON)
end

do -- starting: asks the group and sends its own numbers, once, after the throttle
    local s = boot()
    check("prefix registered", s.prefix == "NaowhGroupXP")
    check("nothing sent before the throttle", #s.sent == 0)
    s.fire("PLAYER_ENTERING_WORLD")
    s.run(2)
    check("request then numbers", s.messages() == "R,2 Player-1-01 20 500 1000")
    check("to the party", s.sent[1][3] == "PARTY" and s.sent[2][3] == "PARTY")
    for _ = 1, 10 do s.fire("PLAYER_XP_UPDATE") end
    s.run(2)
    check("a burst of XP updates is one send", s.messages() == "R,2 Player-1-01 20 500 1000,2 Player-1-01 20 500 1000")
    s.S.Set("groupXPWidth", 300)
    s.run(2)
    check("a setting change sends no request", select(2, s.messages():gsub("R", "")) == 1)
    s.sent = {}
    s.fire("PLAYER_ENTERING_WORLD")
    s.run(2)
    check("a loading screen asks again", s.messages() == "R,2 Player-1-01 20 500 1000")
end

do -- answering: a request gets our numbers back, without asking again
    local s = boot()
    s.run(2)
    s.sent = {}
    s.msg("R", "Tank Ironhide")
    s.msg("R", "Mage Frostwhisper")
    s.run(2)
    check("two requests, one answer", s.messages() == "2 Player-1-01 20 500 1000")
end

do -- display: yourself, a member with the addon, a member without it
    local s = boot()
    s.msg("2 Player-1-02 21 300 1200", "Tank Ironhide")
    s.fire("CHAT_MSG_ADDON", "OtherPrefix", "2 Player-2-03 50 1 2", "PARTY", "Mage Frostwhisper")
    s.msg("junk", "Mage Frostwhisper")
    s.msg("1 21 1 2", "Mage Frostwhisper")
    s.msg("2 Player-2-03 21 1 2", "Mage Frostwhisper", "WHISPER")
    check("rows read from the messages",
        s.rows() == "You: Lv 20  50.0% | Tank: Lv 21  25.0% | Mage: Lv 19  " .. NO_ADDON)
    s.msg("2 Player-2-03 60 0 0", "Mage Frostwhisper")
    check("matched by GUID whatever the sender name, max level shown",
        s.rows() == "You: Lv 20  50.0% | Tank: Lv 21  25.0% | Mage: Lv 60  Max")
end

do -- ignored: a secret message (a string op on it would error), and our own echo
    local s = boot()
    s.msg({ secret = true }, "Tank Ironhide")
    s.msg("2 Player-1-01 60 0 0", "You Lightbringer")
    check("secret message and own echo ignored",
        s.rows() == "You: Lv 20  50.0% | Tank: Lv 21  " .. NO_ADDON .. " | Mage: Lv 19  " .. NO_ADDON)
end

do -- switching off hides the bars and keeps sharing, with no O
    local s = boot()
    s.fire("PLAYER_ENTERING_WORLD")
    s.run(2)
    s.sent = {}
    s.S.Set("groupXP", false)
    check("hidden when off", not s.display.shown)
    check("no O sent", #s.sent == 0)
    s.fire("PLAYER_XP_UPDATE")
    s.run(2)
    check("XP still shared while off", s.messages() == "2 Player-1-01 20 500 1000")
    s.sent = {}
    s.msg("R", "Tank Ironhide")
    s.run(2)
    check("requests still answered while off", s.messages() == "2 Player-1-01 20 500 1000")
end

do -- a member who leaves is dropped
    local s = boot()
    s.msg("2 Player-1-02 21 300 1200", "Tank Ironhide")
    s.units.party1, s.units.party2 = s.units.party2, nil
    s.fire("GROUP_ROSTER_UPDATE")
    check("two rows after one leaves", s.rows() == "You: Lv 20  50.0% | Mage: Lv 19  " .. NO_ADDON)
    s.units.party2 = { name = "Tank", guid = "Player-1-02", class = "WARRIOR", level = 21 }
    s.fire("GROUP_ROSTER_UPDATE")
    check("rejoining starts without old numbers", s.rows():find("Tank: Lv 21  " .. NO_ADDON, 1, true) ~= nil)
end

do -- combat: sends wait and go out once combat ends
    local s = boot()
    s.fire("PLAYER_ENTERING_WORLD")
    s.combat = true
    s.run(2)
    check("no send in combat", #s.sent == 0)
    s.combat = false
    s.fire("PLAYER_REGEN_ENABLED")
    check("sent when combat ends", s.messages() == "R,2 Player-1-01 20 500 1000")
    s.fire("PLAYER_REGEN_ENABLED")
    check("only once", #s.sent == 2)
end

do -- solo: hidden, no send
    local s = boot()
    s.group = false
    s.units.party1, s.units.party2 = nil, nil
    s.fire("GROUP_ROSTER_UPDATE")
    s.run(2)
    check("hidden solo", not s.display.shown)
    check("no send solo", #s.sent == 0)
end

do -- raid: hidden unless Show in Raids is on, still sharing
    local s = boot()
    s.raid = true
    s.fire("GROUP_ROSTER_UPDATE")
    s.run(2)
    check("hidden in a raid by default", not s.display.shown)
    check("still shares in a raid", s.messages() == "2 Player-1-01 20 500 1000" and s.sent[1][3] == "RAID")
    s.S.Set("groupXPRaid", true)
    check("Show in Raids shows it", s.display.shown)
    s.raid = false
    s.S.Set("groupXPRaid", false)
    s.fire("GROUP_ROSTER_UPDATE")
    check("back to a party, it shows again", s.display.shown)
end

do -- Show Yourself off drops your row
    local s = boot({ groupXPShowSelf = false })
    s.fire("GROUP_ROSTER_UPDATE")
    check("no row for yourself", s.rows() == "Tank: Lv 21  " .. NO_ADDON .. " | Mage: Lv 19  " .. NO_ADDON)
end

do -- only GUIDs in the group are kept: a stranger's numbers, or a flood of made-up GUIDs, leave nothing
    local s = boot()
    for i = 1, 500 do s.msg(("2 Player-9-%06X 60 1 2"):format(i), "Tank Ironhide") end
    s.units.party3 = { name = "Late", surname = "Joiner", guid = "Player-9-000001", class = "MAGE", level = 10 }
    s.fire("GROUP_ROSTER_UPDATE")
    check("numbers for a GUID outside the group were not kept", s.rows():find("Late: Lv 10  " .. NO_ADDON, 1, true))
    s.msg("2 Player-9-000001 12 50 100", "Late Joiner")
    check("once they are in the group, theirs are", s.rows():find("Late: Lv 12  50.0%", 1, true))
end

do -- cost: roster changes and messages are heard with the bars off too, so they make no garbage
    local Measure = dofile("Tools/regression/measure.lua")(check)
    local s = boot({ groupXP = false })
    s.msg("2 Player-1-02 21 300 1200", "Tank Ironhide")
    Measure("a roster change with the bars off", 0.05, function() s.fire("GROUP_ROSTER_UPDATE") end)
    Measure("a member's numbers with the bars off", 0.05,
        function() s.msg("2 Player-1-02 21 300 1200", "Tank Ironhide") end)
    local on = boot()
    on.msg("2 Player-1-02 21 300 1200", "Tank Ironhide")
    Measure("a roster change with the bars on", 0.1, function() on.fire("GROUP_ROSTER_UPDATE") end)
    check("bars still right after the measured redraws",
        on.rows() == "You: Lv 20  50.0% | Tank: Lv 21  25.0% | Mage: Lv 19  " .. NO_ADDON)
end

do
    local s = boot()
    local before = s.rows()
    local SECRET = { secret = true }
    s.fire("CHAT_MSG_ADDON", SECRET, "2 Player-1-02 21 300 1200", "PARTY", "Tank Ironhide")
    s.fire("CHAT_MSG_ADDON", "NaowhGroupXP", "2 Player-1-02 21 300 1200", SECRET, "Tank Ironhide")
    check("a secret prefix or channel is skipped before it is compared", s.rows() == before)
    s.msg("2 |TInterface\\AddOns\\NaowhForever\\Core\\Badges\\Media\\BadgeNaowhChat.tga:0|t 60 1 2", "Tank Ironhide")
    s.msg("2 %s%d%n 60 1 2", "Tank Ironhide")
    s.msg("2 Player-9-ABCDEF 60 1 2", "Stranger")
    check("a GUID that is not a player's, or not in the group, keeps nothing", s.rows() == before)
    s.msg("2 Player-1-02 " .. ("9"):rep(400) .. " 1 2", "Tank Ironhide")
    s.msg("2 Player-1-02 21 " .. ("9"):rep(40) .. " 2", "Tank Ironhide")
    check("numbers past any level or XP are dropped", s.rows() == before)
    local long = "2 Player-1-02 21 300 1200 " .. ("|cffff0000x|r"):rep(300)
    local started = os.clock()
    for _ = 1, 100 do s.msg(long, "Tank Ironhide") end
    check("a long message of color codes is refused, and quickly", s.rows() == before
        and os.clock() - started < 0.5)
    s.msg("2 Player-1-02 21 300 1200", "Tank Ironhide")
    check("the real message still shows", s.rows():find("Tank: Lv 21  25.0%", 1, true) ~= nil)
    s.units.party3 = { name = "Stranger", guid = "Player-9-ABCDEF", class = "MAGE", level = 12 }
    s.fire("GROUP_ROSTER_UPDATE")
    check("numbers sent before joining were not kept for them",
        s.rows():find("Stranger: Lv 12  " .. NO_ADDON, 1, true) ~= nil)
    s.msg("2 Player-9-ABCDEF 12 50 100", "Stranger")
    check("once in the group they are heard", s.rows():find("Stranger: Lv 12  50.0%", 1, true) ~= nil)
end

do
    local s = boot()
    local before = s.rows()
    s.msg("2 Player-2-03 60 0 0", "Tank Ironhide")
    s.msg("2 Player-2-03 60 0 0", "Tank")
    s.msg("2 Player-2-03 60 0 0", "Mage")
    s.msg("2 Player-2-03 60 0 0", "Mage Frostwhisperer")
    check("a member sending another member's GUID is dropped", s.rows() == before)
    s.msg("2 Player-1-02 21 300 1200", "Outsider Someone")
    check("a sender not in the group is dropped", s.rows() == before)
    s.msg("2 Player-2-03 19 100 1000", "Mage-Frostwhisper")
    check("their own GUID is taken, the name with a dash", s.rows():find("Mage: Lv 19  10.0%", 1, true) ~= nil)
    s.msg("2 Player-1-02 21 600 1200", "Tank Ironhide-Forever")
    check("and with your realm after it", s.rows():find("Tank: Lv 21  50.0%", 1, true) ~= nil)
    s.msg("2 Player-1-02 21 900 1200", "Tank Ironhide-Elsewhere")
    check("another realm's same name is not them", s.rows():find("Tank: Lv 21  50.0%", 1, true) ~= nil)
end

do -- the look: today's rows by default, then each option applies, a bigger font making taller rows
    local s = boot()
    local row, bar
    for _, f in ipairs(s.created) do
        if f.kind == "StatusBar" and f.parent.shown and not bar then bar, row = f, f.parent end
    end
    check("default: the gradient bar on its 85% background", bar.texture == GRADIENT and row.bg.alpha == 0.85)
    check("default: outlined names at 12, bar text at 11, 18 tall", row.fonts[1].font == " 12 OUTLINE"
        and bar.fonts[1].font == " 11 OUTLINE" and row.h == 18 and s.display.h == 3 * 20 - 2)
    s.S.Set("groupXPTexture", "Smooth")
    s.S.Set("groupXPBgAlpha", 0.4)
    check("Bar Texture and Background Opacity apply", bar.texture == "lsm:Smooth" and row.bg.alpha == 0.4)
    s.S.Set("groupXPFont", "Arial")
    s.S.Set("groupXPOutline", "")
    s.S.Set("groupXPFontSize", 16)
    check("Font, Outline and Font Size apply", row.fonts[1].font == "Arial 16 " and bar.fonts[1].font == "Arial 15 ")
    check("a bigger font makes taller rows", row.h == 22 and s.display.h == 3 * 24 - 2)
end

print(("PASS group XP: %d checks"):format(checks))

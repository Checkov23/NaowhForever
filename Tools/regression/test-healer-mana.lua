-- Offline behavior checks for Healer Mana; these do not emulate client taint or rendering.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

-- Methods a stub frame lacks do nothing, from one shared function, so stubs add no garbage.
local function Noop() end
local NOOP_META = { __index = function() return Noop end }
local DEFAULTS = { enabled = true, healerMana = true, healerManaWhere = "instance", healerManaShowSelf = true,
    healerManaDrinking = true, healerManaWidth = 160, healerManaFont = "", healerManaFontSize = 12,
    healerManaOutline = "OUTLINE", healerManaBackground = "card" }
local UNIT_EVENTS = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_CONNECTION", "UNIT_AURA" }
local SECRET = { secret = true }
local GREEN, YELLOW, RED = { r = 0, g = 1, b = 0 }, { r = 1, g = 1, b = 0 }, { r = 1, g = 0, b = 0 }

local function boot(settings, units)
    local s = { now = 0, timers = {}, created = {}, group = true, raid = false, instance = "party",
        secretAuras = false, settings = settings or {}, backdrops = {} }
    s.units = units or {
        player = { name = "Shammy", guid = "Player-1-01", class = "SHAMAN", mana = 900, max = 1000 },
        party1 = { name = "Holy", guid = "Player-1-02", class = "PRIEST", mana = 200, max = 1000 },
        party2 = { name = "Tank", guid = "Player-1-03", class = "WARRIOR", mana = 0, max = 0 },
        party3 = { name = "Ret", guid = "Player-1-04", class = "PALADIN", role = "DAMAGER", mana = 100, max = 1000 },
        party4 = { name = "Tree", guid = "Player-1-05", class = "DRUID", role = "HEALER", mana = 500, max = 1000 },
    }
    local function frame(kind, name, parent)
        local f = { kind = kind, parent = parent, scripts = {}, events = {}, fonts = {}, shown = true }
        setmetatable(f, NOOP_META)
        function f:SetScript(k, fn) self.scripts[k] = fn end
        function f:RegisterEvent(k) self.events[k] = true end
        function f:RegisterUnitEvent(k, u) self.events[k] = u end
        function f:UnregisterEvent(k) self.events[k] = nil end
        function f:UnregisterAllEvents() self.events = {} end
        function f:Show() self.shown = true end
        function f:Hide() self.shown = false end
        function f:SetShown(v) self.shown = v and true or false end
        function f:SetSize(w, h) self.w, self.h = w, h end
        function f:SetHeight(h) self.h = h end
        function f:SetText(t) self.text = t end
        function f:SetFormattedText(fmt, v) self.text = fmt:format(v) end
        function f:SetTextColor(r, g, b) self.r, self.g, self.b = r, g, b end
        function f:CreateTexture() return frame("Texture", nil, self) end
        function f:GetWidth() return self.w or 0 end
        function f:GetHeight() return self.h or 0 end
        return f
    end
    local St = { TIME_OK_RGB = GREEN, TIME_LOW_RGB = YELLOW, TIME_OUT_RGB = RED, RED_RGB = RED }
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, QoLConstants = dofile("Tools/regression/qol_constants.lua"), THEME = { bg = {}, fg = { r = 1, g = 1, b = 1 }, muted = { r = 0.5, g = 0.5, b = 0.5 } },
        Font = function(parent)
            local fs = frame("FontString", nil, parent)
            parent.fonts[#parent.fonts + 1] = fs
            return fs
        end,
        Apply = function() end, ShowUnlockMode = function() end,
        HideUnlockMode = function() end,
        UI = { AttachMover = function() return frame("Mover") end },
        Shared = { Style = St, Parts = {
            HudFont = function(fs, font, size, outline) fs.font = font .. " " .. size .. " " .. outline end,
            HudBackdrop = function(owner)
                local b = { owner = owner }
                s.backdrops[owner] = b
                function b:SetMode(mode) self.mode = mode end
                return b
            end } } }
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
    local function unit(u) return s.units[u] or {} end
    local env = { _G = { NaowhForever = ns }, UIParent = frame("Parent"),
        CreateFrame = function(kind, name, parent)
            local f = frame(kind, name, parent)
            s.created[#s.created + 1] = f
            return f
        end,
        RAID_CLASS_COLORS = { SHAMAN = { r = 0, g = 0.4, b = 0.9 }, PRIEST = { r = 1, g = 1, b = 1 },
            DRUID = { r = 1, g = 0.5, b = 0 }, PALADIN = { r = 1, g = 0.5, b = 0.7 }, WARRIOR = { r = 0.8, g = 0.6, b = 0.4 } },
        Enum = { LuaCurveType = { Linear = 1 } },
        IsInGroup = function() return s.group end, IsInRaid = function() return s.raid end,
        IsInInstance = function() return s.instance ~= "none", s.instance end,
        GetNumSubgroupMembers = partyCount,
        GetNumGroupMembers = function() return partyCount() + 1 end,
        UnitName = function(u) return s.units[u] and s.units[u].name end,
        UnitGUID = function(u) return s.units[u] and s.units[u].guid end,
        UnitClass = function(u) return "x", s.units[u] and s.units[u].class end,
        UnitGroupRolesAssigned = function(u) return unit(u).role or "NONE" end,
        UnitIsUnit = function(a, b) return a == b end,
        UnitIsConnected = function(u) return not unit(u).offline end,
        UnitIsDeadOrGhost = function(u) return unit(u).dead == true end,
        UnitPower = function(u) return unit(u).mana end,
        UnitPowerMax = function(u) return unit(u).max end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end end,
        issecretvalue = function(v) return v == SECRET end,
        C_Secrets = { ShouldAurasBeSecret = function() return s.secretAuras end },
        C_Spell = { GetSpellName = function(id) return id == 430 and "Drink" or nil end },
        C_UnitAuras = { GetAuraDataBySpellName = function(u, name, filter)
            s.fullLooks = (s.fullLooks or 0) + 1
            if name == "Drink" and filter == "HELPFUL" and unit(u).drinking then return { auraInstanceID = 70 } end
        end },
        C_Timer = { After = function(delay, fn) s.timers[#s.timers + 1] = { at = s.now + delay, fn = fn } end },
        hooksecurefunc = function(t, k, fn)
            local old = t[k]; t[k] = function(...) local r = old(...); fn(...); return r end
        end,
    }
    setmetatable(env, { __index = _G })
    s.env = env
    local f = assert(io.open("NaowhForever_QoL/Combat/HealerMana.lua", "rb"))
    local src = f:read("*a"); f:close()
    local chunk = assert(loadstring(src, "HealerMana")); setfenv(chunk, env); chunk()
    local events, bootFrame = s.created[1], s.created[2]
    s.events = events
    s.S = ns.QoLSettings
    -- A unit event reaches only the frames listening to that unit, as RegisterUnitEvent does.
    function s.fire(event, u, ...)
        if not event:find("^UNIT_") then return events.scripts.OnEvent(events, event, u, ...) end
        for i = 1, #s.created do
            local w = s.created[i]
            if w.events[event] == u then w.scripts.OnEvent(w, event, u, ...) end
        end
    end
    function s.run(seconds)
        s.now = s.now + seconds
        local due = {}
        for i = #s.timers, 1, -1 do
            if s.timers[i].at <= s.now then due[#due + 1] = table.remove(s.timers, i) end
        end
        for _, t in ipairs(due) do t.fn() end
    end
    -- The shown rows, "Name pct" (with "+cup" while drinking), top to bottom.
    function s.rows()
        local display = s.created[3]
        if not display or not display.shown then return "" end
        local out = {}
        for _, row in ipairs(s.created) do
            if row.parent == display and row.kind == "Frame" and row.shown then
                local cup = row.icon and row.icon.shown and "+cup " or ""
                out[#out + 1] = cup .. row.fonts[2].text .. " " .. row.fonts[1].text
            end
        end
        return table.concat(out, " | ")
    end
    function s.row(i)
        local n = 0
        for _, row in ipairs(s.created) do
            if row.parent == s.created[3] and row.kind == "Frame" and row.shown then
                n = n + 1
                if n == i then return row end
            end
        end
    end
    bootFrame.scripts.OnEvent(bootFrame, "PLAYER_LOGIN")
    s.display = s.created[3]
    return s
end

local function same(fs, ref) return fs.r == ref.r and fs.g == ref.g and fs.b == ref.b end

-- The units something listens to for these events, sorted: "party1 party4 player".
local function listening(s, list)
    local seen, out = {}, {}
    for _, f in ipairs(s.created) do
        for _, e in ipairs(list) do
            local u = f.events[e]
            if u == true then out[#out + 1] = "everyone" end
            if type(u) == "string" and not seen[u] then seen[u] = true; out[#out + 1] = u end
        end
    end
    table.sort(out)
    return table.concat(out, " ")
end

local function hearsNone(s, list) return listening(s, list) == "" end

do -- off: nothing built and nothing heard
    local s = boot({ healerMana = false })
    check("off builds no display", #s.created == 2)
    check("off hears no events", next(s.events.events) == nil)
    s.S.Set("healerMana", true)
    check("switching on shows the healers", s.rows() ~= "")
    s.S.Set("healerMana", false)
    check("switching off hides them and stops listening", not s.created[3].shown and next(s.events.events) == nil)
end

do -- who shows, and in what order
    local s = boot()
    check("healers only, lowest mana first: role healer and healing classes, not a damage paladin",
        s.rows() == "Holy 20.0% | Tree 50.0% | Shammy 90.0%")
    check("in a dungeon each healer's own events are heard, nobody else's",
        listening(s, UNIT_EVENTS) == "party1 party4 player")
    check("mana colors: out, low, plenty", same(s.row(1).fonts[1], RED) and same(s.row(2).fonts[1], YELLOW)
        and same(s.row(3).fonts[1], GREEN))
    check("names in class color", s.row(3).fonts[2].b == 0.9)
end

do -- a burst of mana ticks is one redraw, and only mana on a healer counts
    local s = boot()
    s.units.party1.mana = 950
    for _ = 1, 20 do s.fire("UNIT_POWER_UPDATE", "party1", "MANA") end
    check("one redraw queued for a burst", #s.timers == 1)
    check("nothing drawn before it runs", s.rows() == "Holy 20.0% | Tree 50.0% | Shammy 90.0%")
    s.run(0.25)
    check("the new order once it runs", s.rows() == "Tree 50.0% | Shammy 90.0% | Holy 95.0%")
    s.fire("UNIT_POWER_UPDATE", "party1", "RAGE")
    s.fire("UNIT_POWER_UPDATE", "party2", "MANA")
    s.fire("UNIT_POWER_UPDATE", "target", "MANA")
    s.fire("UNIT_POWER_UPDATE", "party1", SECRET)
    check("other powers, a secret power, non-healers and other units queue nothing", #s.timers == 0)
end

do -- a burst of roster events is one rebuild, and the listeners follow the healers
    local s = boot()
    for _ = 1, 10 do s.fire("GROUP_ROSTER_UPDATE") end
    check("one rebuild queued for a roster burst", #s.timers == 1)
    s.units.party3.role = "HEALER"
    s.fire("PLAYER_ROLES_ASSIGNED")
    s.run(0.25)
    check("rebuilt once it runs", s.rows() == "Ret 10.0% | Holy 20.0% | Tree 50.0% | Shammy 90.0%")
    check("the new healer is heard", listening(s, UNIT_EVENTS) == "party1 party3 party4 player")
    s.units.party3.role = "DAMAGER"
    s.fire("GROUP_ROSTER_UPDATE")
    s.run(0.25)
    check("and stops being heard once not a healer", listening(s, UNIT_EVENTS) == "party1 party4 player")
    local made = #s.created
    s.fire("GROUP_ROSTER_UPDATE")
    s.run(0.25)
    check("a rebuild with the same healers makes no frames", #s.created == made)
end

do -- where it shows
    local s = boot()
    s.instance = "none"
    s.fire("PLAYER_ENTERING_WORLD")
    check("hidden outside dungeons and raids", not s.display.shown)
    check("no unit events outside", hearsNone(s, UNIT_EVENTS))
    s.S.Set("healerManaWhere", "group")
    check("Any Group shows it in the open world", s.rows() == "Holy 20.0% | Tree 50.0% | Shammy 90.0%")
    s.group = false
    s.units = { player = s.units.player }
    s.fire("GROUP_ROSTER_UPDATE")
    s.run(0.25)
    check("hidden solo", not s.display.shown and hearsNone(s, UNIT_EVENTS))
end

do -- dead and offline go last, with what they are
    local s = boot()
    s.units.party1.dead = true
    s.units.party4.offline = true
    s.fire("UNIT_CONNECTION", "party4")
    s.run(0.25)
    check("dead and offline after the living", s.rows() == "Shammy 90.0% | Holy Dead | Tree Offline")
    check("dead in red", same(s.row(2).fonts[1], RED))
end

do -- drinking
    local s = boot()
    s.units.party4.drinking = true
    s.fire("UNIT_AURA", "party4")
    s.run(0.25)
    check("a cup by a healer drinking", s.rows() == "Holy 20.0% | +cup Tree 50.0% | Shammy 90.0%")
    s.fire("UNIT_AURA", "party4")
    check("an aura change that is not drinking queues nothing", #s.timers == 0)
    s.secretAuras = true
    s.units.party4.drinking = false
    s.fire("UNIT_AURA", "party4")
    s.run(0.25)
    check("while auras are secret the last answer stands", s.rows():find("+cup Tree", 1, true) ~= nil)
    s.secretAuras = false
    s.fire("UNIT_AURA", "party4")
    s.run(0.25)
    check("and clears once they are readable", s.rows() == "Holy 20.0% | Tree 50.0% | Shammy 90.0%")
    s.units.party4.drinking = true
    s.S.Set("healerManaDrinking", false)
    check("Mark Drinking off shows no cup", s.rows() == "Holy 20.0% | Tree 50.0% | Shammy 90.0%")
end

do -- drinking from the aura event's own changes, with no full look
    local s = boot()
    s.fullLooks = 0
    s.fire("UNIT_AURA", "party4", { addedAuras = { { name = "Renew", auraInstanceID = 5 } } })
    check("an added aura that is not Drink queues nothing", #s.timers == 0)
    s.fire("UNIT_AURA", "party4", { addedAuras = { { name = SECRET, auraInstanceID = 6 } } })
    check("a secret aura name is not read", #s.timers == 0)
    s.fire("UNIT_AURA", "party4", { addedAuras = { { name = "Drink", auraInstanceID = 7 } } })
    s.run(0.25)
    check("Drink added shows the cup", s.rows() == "Holy 20.0% | +cup Tree 50.0% | Shammy 90.0%")
    s.fire("UNIT_AURA", "party4", { removedAuraInstanceIDs = { 5 } })
    check("another aura removed leaves it", #s.timers == 0)
    s.fire("UNIT_AURA", "party4", { removedAuraInstanceIDs = { 7 } })
    s.run(0.25)
    check("that Drink removed clears it", s.rows() == "Holy 20.0% | Tree 50.0% | Shammy 90.0%")
    check("none of it looked the auras up", s.fullLooks == 0)
    s.units.party4.drinking = true
    s.fire("UNIT_AURA", "party4", { isFullUpdate = true })
    s.run(0.25)
    check("a full update looks once", s.fullLooks == 1 and s.rows():find("+cup Tree", 1, true) ~= nil)
    s.fire("UNIT_AURA", "party4", { removedAuraInstanceIDs = { 70 } })
    s.run(0.25)
    check("and the Drink it found clears by its ID", s.rows() == "Holy 20.0% | Tree 50.0% | Shammy 90.0%")
end

do -- secret mana: the order holds, the client writes the share, or "--" without the API
    local s = boot()
    s.units.party1.mana = SECRET
    s.units.player.mana = SECRET
    s.fire("UNIT_POWER_UPDATE", "party1", "MANA")
    s.run(0.25)
    check("without UnitPowerPercent a secret share shows --, in the order it had",
        s.rows() == "Holy -- | Tree 50.0% | Shammy --")
    s.env.UnitPowerPercent = function(u) return u == "party1" and 99 or 12.5 end
    s.env.C_CurveUtil = { CreateCurve = function()
        return setmetatable({}, NOOP_META)
    end }
    s.fire("UNIT_POWER_UPDATE", "party1", "MANA")
    s.run(0.25)
    check("with it the client's share shows, order still held", s.rows() == "Holy 99.0% | Tree 50.0% | Shammy 12.5%")
    s.units.party1.mana, s.units.player.mana = 990, 50
    s.fire("UNIT_POWER_UPDATE", "party1", "MANA")
    s.run(0.25)
    check("sorted again once readable", s.rows() == "Shammy 5.0% | Tree 50.0% | Holy 99.0%")
end

do -- a druid in a form keeps the share it last showed
    local s = boot()
    s.units.party4.mana, s.units.party4.max = 30, 0
    s.fire("UNIT_DISPLAYPOWER", "party4")
    s.run(0.25)
    check("last share kept", s.rows() == "Holy 20.0% | Tree 50.0% | Shammy 90.0%")
end

do -- Show Yourself off drops your row; a raid lists you once
    local s = boot({ healerManaShowSelf = false })
    check("no row for yourself", s.rows() == "Holy 20.0% | Tree 50.0%")
    local u = {
        player = { name = "Shammy", guid = "Player-1-01", class = "SHAMAN", mana = 900, max = 1000 },
        party1 = { name = "Holy", guid = "Player-1-02", class = "PRIEST", mana = 200, max = 1000 },
    }
    local r = boot(nil, u)
    r.raid, r.instance = true, "raid"
    u.raid1, u.raid2 = u.player, u.party1
    u.party1 = nil
    r.env.UnitIsUnit = function(a, b) return (a == "raid1" or a == "player") and b == "player" end
    r.env.GetNumGroupMembers = function() return 2 end
    r.fire("GROUP_ROSTER_UPDATE")
    r.run(0.25)
    check("a raid lists you once", r.rows() == "Holy 20.0% | Shammy 90.0%")
end

do -- the look: options apply, a bigger font makes taller rows
    local s = boot()
    check("default: a card, outlined text at 12, sized to its rows",
        s.backdrops[s.display].mode == "card" and s.row(1).fonts[2].font == " 12 OUTLINE"
        and s.display.w == 160 and s.display.h == 3 * 16 + 12)
    s.S.Set("healerManaBackground", "soft")
    s.S.Set("healerManaFont", "Arial")
    s.S.Set("healerManaOutline", "")
    s.S.Set("healerManaFontSize", 16)
    s.S.Set("healerManaWidth", 200)
    check("Background, Font, Outline, Size and Width apply", s.backdrops[s.display].mode == "soft"
        and s.row(1).fonts[2].font == "Arial 16 " and s.row(1).fonts[1].font == "Arial 16 "
        and s.display.w == 200 and s.display.h == 3 * 20 + 12)
    local sets = 0
    s.backdrops[s.display].SetMode = function(b, mode) b.mode = mode; sets = sets + 1 end
    s.units.party1.mana = 300
    s.fire("UNIT_POWER_UPDATE", "party1", "MANA")
    s.run(0.25)
    check("a mana tick does not restyle the card", sets == 0 and s.rows() == "Holy 30.0% | Tree 50.0% | Shammy 90.0%")
end

do -- a share that did not move is not written again
    local s = boot()
    local writes = 0
    local pct = s.row(1).fonts[1]
    pct.SetText = function(fs, v) fs.text = v; writes = writes + 1 end
    s.units.party1.mana = 200.4
    s.fire("UNIT_POWER_UPDATE", "party1", "MANA")
    s.run(0.25)
    check("the same 20.0% is not formatted again", writes == 0 and s.rows():find("Holy 20.0%", 1, true) == 1)
    s.units.party1.mana = 210
    s.fire("UNIT_POWER_UPDATE", "party1", "MANA")
    s.run(0.25)
    check("a new share is", writes == 1 and s.rows():find("Holy 21.0%", 1, true) == 1)
end

do -- cost: a mana tick redraw makes no garbage
    local Measure = dofile("Tools/regression/measure.lua")(check)
    local s = boot()
    s.env.C_Timer.After = function(_, fn) fn() end -- the redraw at once: the stub's queue makes garbage
    Measure("a mana tick redrawn", 0.1, function() s.fire("UNIT_POWER_UPDATE", "party1", "MANA") end)
    check("rows still right after the measured redraws", s.rows() == "Holy 20.0% | Tree 50.0% | Shammy 90.0%")
end

print(("PASS healer mana: %d checks"):format(checks))

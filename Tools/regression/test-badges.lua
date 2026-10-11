-- Run with Lua 5.1 from the repository root: supporter badges in chat, the hover card, the
-- player tooltip line and the group toast, against stubs of the chat and tooltip APIs they use,
-- with ns.FEATURE_BADGES at 1; at 0, the team's badges only, on the defaults, with no settings card.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local SECRET = setmetatable({}, { __tostring = function() return "secret" end })

local DEFAULTS = { badgeChat = true, badgeCard = true, badgeTooltip = true,
    badgeBanner = false, badgeBannerSkipGuild = true }

local function fixture(withChatUtil, settings, flag)
    local state = { nameFilters = {}, callbacks = {}, postCalls = {}, printed = {}, sounds = 0,
        group = {}, raid = false, combat = false, region = 3, me = "Player-1-SELF", account = {},
        guild = {}, onLoaded = {}, frames = 0, hooks = 0, cards = {}, roster = {} }
    local values = {}
    for k, v in pairs(DEFAULTS) do values[k] = v end
    for k, v in pairs(settings or {}) do values[k] = v end
    local S = { Get = function(k) return values[k] end, Set = function(k, v) values[k] = v end,
        Default = function(k) return DEFAULTS[k] end }
    state.S = S
    local noop = function() end
    local function frame()
        local f = { scripts = {}, events = {} }
        setmetatable(f, { __index = function(_, key)
            if key == "CreateAnimationGroup" or key == "CreateAnimation" or key == "CreateTexture"
                or key == "CreateFontString" or key == "CreateMaskTexture" then
                return function() return frame() end
            end
            return noop
        end })
        function f:Show() self.visible = true end
        function f:Hide() self.visible = false end
        function f:IsShown() return self.visible == true end
        function f:SetText(text) self.text = text end
        function f:SetScript(name, fn) self.scripts[name] = fn end
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterEvent(e) self.events[e] = nil end
        function f:GetEffectiveScale() return 1 end
        return f
    end
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        THEME = { bg = {}, line = {}, fg = {}, muted = {}, accentSoft = {} },
        Solid = function() return frame() end,
        Border = function() return { SetColor = noop } end,
        -- Text 6 wide a character, in a string state.fontWidth wide (wide enough by default).
        Font = function()
            local font = frame()
            function font:GetStringWidth() return #(self.text or "") * 6 end
            function font:GetWidth() return state.fontWidth or 400 end
            return font
        end,
        FontInset = function(size) return size * 0.075 end,
        Print = function(msg) state.printed[#state.printed + 1] = msg end,
        AccountSettings = function() return state.account end,
        QoLSettings = S,
        Apply = function() end,
        MakeModal = function() local d = frame(); state.modal = d; return d, frame() end,
        NewEditBox = function() return frame() end,
        -- The team member running the tests is staff in US only: previews are allowed, but
        -- in EU (the default region here) their own name has no badge.
        BADGE_STAFF = { [1] = { ["Player-1-SELF"] = "developer" }, [3] = {} },
        BADGE_PATRONS = { [3] = {} },
        FEATURE_BADGES = flag or 1, BADGES_LIVE = 1, LINKS = { { "Discord", "discord" } },
        Shared = { Roster = { AddTooltip = function(fn) state.roster[#state.roster + 1] = fn end },
            Settings = { Page = function(key)
            return { Card = function(_, def) state.cards[key .. ":" .. def.id] = def end }
        end } },
    }
    ns.UI = {
        KeepFont = function() return frame() end,
        KeepButton = function() return frame() end,
        Keep = function() state.box = state.box or frame(); return state.box end,
    }
    state.ns = ns
    local names = { ["Player-1-SELF"] = "Me" }
    local env = {
        _G = { NaowhForever = ns },
        UIParent = frame(),
        CreateFrame = function() state.frames = state.frames + 1; return frame() end,
        CreateColor = function() return {} end,
        GetCursorPosition = function() return 100, 100 end,
        GetCurrentRegion = function() return state.region end,
        UnitIsInMyGuild = function(unit)
            local i = tonumber(unit:match("%d+$"))
            return i ~= nil and state.guild[state.group[i]] == true
        end,
        hooksecurefunc = function(t, key, fn)
            state.hooks = state.hooks + 1
            local orig = t[key]
            t[key] = function(...) orig(...); fn(...) end
        end,
        UnitGUID = function(unit)
            if unit == "player" then return state.me end
            local i = tonumber(unit:match("%d+$"))
            return i and state.group[i]
        end,
        UnitFullName = function(unit)
            if unit == "player" then return "Me", "Myself" end
            local i = tonumber(unit:match("%d+$"))
            return i and names[state.group[i]] or "Someone", "Surname"
        end,
        IsInGroup = function() return #state.group > 0 end,
        IsInRaid = function() return state.raid end,
        GetNumGroupMembers = function() return #state.group + 1 end,
        InCombatLockdown = function() return state.combat end,
        PlaySound = function(kit) state.sounds = state.sounds + 1; state.lastSound = kit end,
        SOUNDKIT = { UI_LEGENDARY_LOOT_TOAST = 63971, UI_EPICLOOT_TOAST = 31578, UI_72_ARTIFACT_FORGE_ACTIVATE_FINAL_TIER = 83681,
            UI_72_ARTIFACT_FORGE_FINAL_TRAIT_UNLOCKED = 83682, UI_PVP_HONOR_PRESTIGE_RANK_UP = 77003 },
        Ambiguate = function(name) return (name:gsub("%-.*", "")) end,
        issecretvalue = function(v) return v == SECRET end,
        date = function() return "2026-09" end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
        strsplit = function(sep, s)
            local out = {}
            for piece in (s .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = piece end
            return unpack(out)
        end,
        EventRegistry = {
            RegisterCallback = function(_, event, fn, owner)
                state.callbacks[event] = { fn = fn, owner = owner }
            end,
            UnregisterCallback = function(_, event) state.callbacks[event] = nil end,
        },
        TooltipDataProcessor = { AddTooltipPostCall = function(_, fn)
            state.postCalls[#state.postCalls + 1] = fn
        end },
        Enum = { TooltipDataType = { Unit = 2 } },
        EventUtil = { ContinueOnAddOnLoaded = function(name, fn) state.onLoaded[name] = fn end },
        ScrollBoxListMixin = { Event = { OnInitializedFrame = "OnInitializedFrame" } },
    }
    if withChatUtil then
        env.ChatFrameUtil = {
            AddSenderNameFilter = function(fn) state.nameFilters[#state.nameFilters + 1] = fn end,
            RemoveSenderNameFilter = function(fn)
                for i = #state.nameFilters, 1, -1 do
                    if state.nameFilters[i] == fn then table.remove(state.nameFilters, i) end
                end
            end,
        }
    end
    setmetatable(env, { __index = _G })
    local chunk = assert(loadfile("Core/Badges/Badges.lua")); setfenv(chunk, env); chunk()
    ns.Apply()  -- what login does
    state.names = names
    state.env = env
    -- Guild & Communities' member list: a scroll box of rows, each with its member and name.
    function state.communities(guids)
        local scroll = { rows = {}, callbacks = {}, infos = {} }
        function scroll:RegisterCallback(event, fn, owner) self.callbacks[event] = { fn = fn, owner = owner } end
        function scroll:UnregisterCallback(event) self.callbacks[event] = nil end
        function scroll:ForEachFrame(fn) for _, row in ipairs(self.rows) do fn(row) end end
        function scroll:Fill(row, guid)   -- the list puts a member in a row, as it scrolls
            -- One member table per GUID, made once: the stub must not make garbage of its own.
            local info = guid and self.infos[guid]
            if guid and not info then info = { guid = guid }; self.infos[guid] = info end
            row.memberInfo = info
            local cb = self.callbacks.OnInitializedFrame
            if cb then cb.fn(cb.owner, row) end
        end
        for i, guid in ipairs(guids) do
            local name = frame()
            name.GetStringWidth = function() return 40 end
            name.GetWidth = function() return 120 end
            local nameFrame = frame()
            nameFrame.Name = name
            nameFrame.CreateTexture = function()
                local t = frame()
                t.SetPoint = function(texture, point, relativeTo, _, x)
                    texture.point, texture.relativeTo, texture.x = point, relativeTo, x
                end
                return t
            end
            scroll.rows[i] = { memberInfo = guid and { guid = guid } or nil, NameFrame = nameFrame }
        end
        env.CommunitiesFrame = { MemberList = { ScrollBox = scroll } }
        return scroll
    end
    state.api = ns._BadgesTest
    function state.fire(event) state.api.GroupEvents.scripts.OnEvent(state.api.GroupEvents, event) end
    function state.staff(guid, entry, region)
        ns.BADGE_STAFF[region or 3] = ns.BADGE_STAFF[region or 3] or {}
        ns.BADGE_STAFF[region or 3][guid] = entry
        state.api.BuildRoster()
    end
    function state.patron(guid, since, region, tier)
        ns.BADGE_PATRONS[region or 3] = ns.BADGE_PATRONS[region or 3] or {}
        ns.BADGE_PATRONS[region or 3][guid] = { since = since, tier = tier }
        state.api.BuildRoster()
    end
    return state
end

-- Chat name: the filter receives (event, decoratedName, text, sender, ..., lineID, guid).
local function say(filter, name, lineID, guid)
    return filter("CHAT_MSG_SAY", name, "hi", name, "", "", "", "", 0, 0, "", 0, lineID, guid)
end

do  -- chat, card, tooltip
    local s = fixture(true)
    s.staff("Player-1-DEV", { tier = "developer", title = "Lead Developer" })
    s.patron("Player-1-LEG", "2026-03")
    s.patron("Player-1-EPIC", "2026-05", nil, "epic")
    s.patron("Player-1-ODD", nil, nil, "mythic")
    s.staff("Player-1-OLD", "developer")
    s.staff("Player-1-BAD", "no-such-tier")
    local filter = s.nameFilters[1]
    check("built in: the name filter is registered at load", #s.nameFilters == 1)
    check("hover callbacks registered", s.callbacks["ChatFrame.OnHyperlinkEnter"] ~= nil)
    check("tooltip post-call registered", #s.postCalls == 1)

    local dev = say(filter, "Glyalith", 1, "Player-1-DEV")
    check("developer badge after the name", dev:find("BadgeDeveloperChat.tga", 1, true)
        and dev:sub(1, 9) == "Glyalith ")
    check("the badge is as tall as the text", dev:find("BadgeDeveloperChat.tga:0:0:", 1, true) ~= nil)
    check("legendary badge", say(filter, "Patron", 2, "Player-1-LEG"):find("BadgeLegendaryChat.tga", 1, true))
    check("epic badge", say(filter, "Epic", 8, "Player-1-EPIC"):find("BadgeEpicChat.tga", 1, true))
    check("a patron with no tier the addon knows wears the Legendary one",
        say(filter, "Odd", 9, "Player-1-ODD"):find("BadgeLegendaryChat.tga", 1, true))
    check("the moderator is red now, epic purple is the Epic patrons'",
        s.api.TIERS.moderator.hex == "ffe0383e" and s.api.TIERS.epic.hex == "ffa335ee")
    check("plain tier string still works", say(filter, "Old", 6, "Player-1-OLD"):find("BadgeDeveloper", 1, true))
    check("unknown tier: name unchanged", say(filter, "Bad", 7, "Player-1-BAD") == "Bad")
    check("no roster entry: name unchanged", say(filter, "Someone", 3, "Player-1-NOBODY") == "Someone")
    check("no GUID: name unchanged", say(filter, "Someone", 4, nil) == "Someone")
    check("secret GUID: name unchanged, no error", say(filter, "Someone", 5, SECRET) == "Someone")

    local enter = s.callbacks["ChatFrame.OnHyperlinkEnter"]
    enter.fn(enter.owner, {}, "player:Glyalith-Realm:1:SAY", "[Glyalith]")
    local card = s.api.Card()
    check("hovering a badged name shows the card", card and card.visible)
    check("card: personal title", card.title.text == "Lead Developer")
    check("card: player name without realm", card.player.text == "Glyalith")
    check("card: no since line without a date", card.since.text == "")
    s.callbacks["ChatFrame.OnHyperlinkLeave"].fn(enter.owner, {})
    check("leaving hides it", not card.visible)
    enter.fn(enter.owner, {}, "player:Patron-Realm:2:SAY", "[Patron]")
    check("card: tier title", card.title.text == "Legendary Patron")
    check("card: supporter since", card.since.text == "Supporter since March 2026")
    s.callbacks["ChatFrame.OnHyperlinkLeave"].fn(enter.owner, {})
    enter.fn(enter.owner, {}, "player:Epic-Realm:8:SAY", "[Epic]")
    check("epic card: its title and since", card.title.text == "Epic Patron"
        and card.since.text == "Supporter since May 2026")
    s.callbacks["ChatFrame.OnHyperlinkLeave"].fn(enter.owner, {})
    enter.fn(enter.owner, {}, "player:Someone-Realm:3:SAY", "[Someone]")
    check("no card for a plain name", not card.visible)
    enter.fn(enter.owner, {}, "item:1234", "[Item]")
    enter.fn(enter.owner, {}, SECRET, "[?]")
    check("other and secret links ignored", not card.visible)

    check("since: bad dates give nothing", s.api.SinceOf({ tier = "legendary", since = "2026-13" }) == nil
        and s.api.SinceOf({ tier = "legendary", since = "soon" }) == nil
        and s.api.SinceOf("legendary") == nil)
    check("since: never on a developer", s.api.SinceOf({ tier = "developer", since = "2026-01" }) == nil)

    -- The line cache is a fixed ring: old lines are forgotten, nothing grows.
    local size = s.api.CACHE_SIZE
    for line = 100, 100 + size do say(filter, "Glyalith", line, "Player-1-DEV") end
    local cached = 0
    for _ in pairs(s.api.guidByLine) do cached = cached + 1 end
    check("line cache stays at its size", cached == size)
    check("oldest line forgotten", s.api.guidByLine[100] == nil)

    local lines = {}
    local tooltip = { AddLine = function(_, text) lines[#lines + 1] = text end }
    s.postCalls[1](tooltip, { guid = "Player-1-LEG" })
    check("tooltip line for a supporter", lines[1] and lines[1]:find("Legendary Patron", 1, true))
    s.postCalls[1](tooltip, { guid = SECRET })
    s.postCalls[1](tooltip, { guid = "Player-1-NOBODY" })
    check("no tooltip line otherwise", #lines == 1)

    -- The game's own tooltip: a plate over its top instead of the line, gone with the tooltip.
    local env = getfenv(s.postCalls[1])
    local made, create = {}, env.CreateFrame
    env.CreateFrame = function(...)
        local f = create(...)
        made[#made + 1] = f
        return f
    end
    local hooks, tipShown, showing = {}, true, "Player-1-LEG"
    env.GameTooltip = { AddLine = tooltip.AddLine, HookScript = function(_, script, fn) hooks[script] = fn end,
        IsShown = function() return tipShown end,
        GetPrimaryTooltipData = function() return { guid = showing } end }
    s.postCalls[1](env.GameTooltip, { guid = "Player-1-LEG" })
    local plate = made[1]
    check("the game's tooltip: a plate over it, with the title, and no line", plate and plate:IsShown()
        and plate.title.text:find("Legendary Patron", 1, true) and #lines == 1)
    check("in full where it fits", plate.title.text:find("^Naowh Forever ") ~= nil)
    s.fontWidth = 100
    plate.scripts.OnSizeChanged(plate)
    check("on a narrow tooltip, the title alone, not cut off", plate.title.text == "Legendary Patron")
    s.fontWidth = nil
    plate.scripts.OnSizeChanged(plate)
    check("and in full again when it widens", plate.title.text:find("^Naowh Forever ") ~= nil)
    check("no hooks on the game's tooltip", next(hooks) == nil)
    plate.scripts.OnUpdate(plate)
    check("the plate stays while the tooltip shows them", plate:IsShown())
    tipShown = false
    plate.scripts.OnUpdate(plate)
    check("the plate goes when the tooltip hides", not plate:IsShown())
    tipShown = true
    s.postCalls[1](env.GameTooltip, { guid = "Player-1-LEG" })
    showing = "Player-1-OTHER"
    plate.scripts.OnUpdate(plate)
    check("and when it moves on to someone else", not plate:IsShown() and #made == 1)
    showing = "Player-1-LEG"
    s.postCalls[1](env.GameTooltip, { guid = "Player-1-LEG" })
    s.postCalls[1](env.GameTooltip, { guid = "Player-1-NOBADGE" })
    check("and when the next player has no badge", not plate:IsShown())

    local row, owned = {}, true
    s.ns.Shared.Roster.Showing = function(r) return owned and r == row end
    check("the guild and friends lists' tooltips are asked for once", #s.roster == 1)
    s.roster[1](env.GameTooltip, "Player-1-LEG", { guid = "Player-1-LEG" }, row, env.GameTooltip)
    check("a badged player in the guild or friends list: the same plate", plate:IsShown() and #made == 1
        and plate.title.text:find("Legendary Patron", 1, true))
    plate.scripts.OnUpdate(plate)
    check("it stays while the tooltip is that member's", plate:IsShown())
    owned = false
    plate.scripts.OnUpdate(plate)
    check("and goes when the list's tooltip leaves the row", not plate:IsShown())
    owned = true
    s.roster[1](env.GameTooltip, "Player-1-NOBADGE", { guid = "Player-1-NOBADGE" }, row, env.GameTooltip)
    check("a member with no badge: no plate", not plate:IsShown())
    env.GameTooltip, env.CreateFrame = nil, create

    -- As a player with no badge sees it: your own taken away for the session.
    s.ns.BadgesCommand("preview none")
    check("preview none: your own name wears no badge, the panel sees none",
        not say(filter, "Me", 899, "Player-1-SELF"):find("Badge", 1, true) and s.ns.BadgeOf("Player-1-SELF") == nil)
    s.ns.BadgesCommand("preview developer")
    -- The card for a preview badge on any name, as the character panel's pitch card shows it.
    s.ns.ShowBadgeCard("legendary", "Dieman")
    check("a preview badge's card: the tier's title on the name given", card.title.text == "Legendary Patron"
        and card.player.text == "Dieman" and card:IsShown())
    s.ns.HideBadgeCard()
    check("and it hides", not card:IsShown())
    check("preview badges your own name", say(filter, "Me", 900, "Player-1-SELF"):find("BadgeDeveloper", 1, true))
    enter.fn(enter.owner, {}, "player:Me-Realm:900:SAY", "[Me]")
    check("developer preview: title, no supporter date", card.title.text == "Lead Developer"
        and card.since.text == "")
    s.ns.BadgesCommand("preview")
    say(filter, "Me", 902, "Player-1-SELF")
    enter.fn(enter.owner, {}, "player:Me-Realm:902:SAY", "[Me]")
    check("legendary preview: supporter date", card.since.text == "Supporter since September 2026")
    s.ns.BadgesCommand("preview naowh")
    check("naowh badge in chat", say(filter, "Me", 903, "Player-1-SELF"):find("BadgeNaowhChat.tga", 1, true))
    enter.fn(enter.owner, {}, "player:Me-Realm:903:SAY", "[Me]")
    check("naowh card", card.title.text == "Founder" and card.about.text == "The Man. The King."
        and card.since.text == "")
    lines = {}
    s.postCalls[1](tooltip, { guid = "Player-1-SELF" })
    check("naowh tooltip line", lines[1] and lines[1]:find("Naowh, the Founder", 1, true))
    s.ns.BadgesCommand("toast")
    check("naowh toast plays the biggest sound", s.lastSound == 83682
        and s.api.Toast().title.text == "Founder")
    s.ns.BadgesCommand("preview moderator")
    check("moderator badge in chat", say(filter, "Me", 905, "Player-1-SELF"):find("BadgeModeratorChat.tga", 1, true))
    enter.fn(enter.owner, {}, "player:Me-Realm:905:SAY", "[Me]")
    check("moderator card", card.title.text == "Moderator" and card.since.text == "")
    local shown = s.api.Toast()
    shown.life.scripts.OnFinished(shown.life)  -- let the Founder toast finish first
    s.ns.BadgesCommand("toast")
    check("moderator toast sound: PvP Prestige rank up", s.lastSound == 77003)
    s.ns.BadgesCommand("preview ellesmere")
    check("EllesmereUI creator badge in chat", say(filter, "Me", 906, "Player-1-SELF")
        :find("BadgeEllesmereChat.tga", 1, true))
    enter.fn(enter.owner, {}, "player:Me-Realm:906:SAY", "[Me]")
    check("EllesmereUI creator card", card.title.text == "EllesmereUI Creator"
        and card.about.text == "Makes EllesmereUI." and card.since.text == "")
    lines = {}
    s.postCalls[1](tooltip, { guid = "Player-1-SELF" })
    check("EllesmereUI creator tooltip line", lines[1] and lines[1]:find("Ellesmere, creator of EllesmereUI", 1, true))
    s.ns.BadgesCommand("preview naowh")

    s.ns.BadgesCommand("preview nobody")
    check("unknown preview tier: help, no change", s.printed[#s.printed]:find("preview %[")
        and say(filter, "Me", 904, "Player-1-SELF"):find("BadgeNaowhChat.tga", 1, true))

    s.ns.BadgesCommand("preview off")
    check("preview off", say(filter, "Me", 901, "Player-1-SELF") == "Me")
    s.ns.BadgesCommand("id")
    check("id shows your GUID with its region", s.box.text == "3:Player-1-SELF")
    s.ns.BadgesCommand("nope")
    local usage = s.printed[#s.printed]
    check("the help names both patron tiers, its pipes escaped", usage:find("[legendary||epic||moderator||", 1, true)
        and not usage:gsub("||", ""):find("|", 1, true))
end

do  -- group toast
    local s = fixture(true)
    s.patron("Player-1-LEG", "2026-01")
    s.staff("Player-1-DEV", "developer")
    s.names["Player-1-LEG"] = "Patron"
    s.S.Set("badgeBanner", true)

    s.group = { "Player-1-LEG" }
    s.fire("PLAYER_ENTERING_WORLD")
    check("login inside a group: no toast", s.api.Toast() == nil)
    s.fire("GROUP_ROSTER_UPDATE")
    check("already there at login: still no toast", s.api.Toast() == nil)

    s.group = {}
    s.fire("GROUP_ROSTER_UPDATE")
    s.group = { "Player-1-OTHER", "Player-1-LEG" }
    s.fire("GROUP_ROSTER_UPDATE")
    local toast = s.api.Toast()
    check("after leaving and regrouping, a patron joining shows a toast", toast and toast.visible)
    check("toast text: first name and surname", toast.text.text == "Patron Surname joined your party")
    check("toast title", toast.title.text == "Legendary Patron")
    check("toast plays a sound", s.sounds == 1)
    s.fire("GROUP_ROSTER_UPDATE")
    check("announced once per group", s.sounds == 1)

    s.combat = true
    s.group = { "Player-1-OTHER", "Player-1-LEG", "Player-1-DEV" }
    s.fire("GROUP_ROSTER_UPDATE")
    check("in combat: waits", s.api.QueueSize() == 0 and s.api.GroupEvents.events.PLAYER_REGEN_ENABLED)
    s.combat = false
    s.fire("PLAYER_REGEN_ENABLED")
    check("after combat: queued behind the showing toast", s.api.QueueSize() == 1
        and not s.api.GroupEvents.events.PLAYER_REGEN_ENABLED)
    toast.life.scripts.OnFinished(toast.life)
    check("next toast shows when the first finishes", toast.visible and toast.title.text == "Developer")
    check("developer toast sound: Artifact final tier activated", s.lastSound == 83681)
    s.patron("Player-1-EPIC", "2026-05", nil, "epic")
    s.names["Player-1-EPIC"] = "Epic"
    s.group = { "Player-1-OTHER", "Player-1-LEG", "Player-1-DEV", "Player-1-EPIC" }
    s.fire("GROUP_ROSTER_UPDATE")
    toast.life.scripts.OnFinished(toast.life)
    check("an Epic patron joining: their title and the epic loot sound", toast.visible
        and toast.title.text == "Epic Patron" and s.lastSound == 31578)

    s.group = { SECRET }
    s.fire("GROUP_ROSTER_UPDATE")
    check("secret GUID in the group: nothing, no error", s.api.QueueSize() == 0)
end

do  -- a quiet scan put off by combat stays quiet; a normal one in the same fight wins
    local s = fixture(true)
    s.patron("Player-1-LEG", "2026-01")
    s.S.Set("badgeBanner", true)
    s.group = { "Player-1-LEG" }
    s.combat = true
    s.fire("PLAYER_ENTERING_WORLD")
    check("reload in combat inside a group: waits", s.api.GroupEvents.events.PLAYER_REGEN_ENABLED)
    s.combat = false
    s.fire("PLAYER_REGEN_ENABLED")
    check("after combat: still no banner for who was already there", s.api.Toast() == nil)

    local t = fixture(true)
    t.patron("Player-1-LEG", "2026-01")
    t.patron("Player-1-NEW", "2026-01")
    t.S.Set("badgeBanner", true)
    t.group = { "Player-1-LEG" }
    t.combat = true
    t.fire("PLAYER_ENTERING_WORLD")
    t.group = { "Player-1-LEG", "Player-1-NEW" }
    t.fire("GROUP_ROSTER_UPDATE")
    t.combat = false
    t.fire("PLAYER_REGEN_ENABLED")
    check("someone joining mid-fight still gets a banner", t.api.Toast() and t.api.Toast().visible)
end

do
    local s = fixture(false)
    check("without ChatFrameUtil: no chat filter, no error", #s.nameFilters == 0
        and s.callbacks["ChatFrame.OnHyperlinkEnter"] == nil)
end

do  -- settings: each part on and off, and nothing registered while off
    local s = fixture(true)
    s.patron("Player-1-LEG", "2026-01")
    local filter = s.nameFilters[1]
    check("defaults: chat badges, card and tooltip on", filter ~= nil
        and s.callbacks["ChatFrame.OnHyperlinkEnter"] ~= nil and #s.postCalls == 1)
    check("defaults: group banner off, not even listening", s.api.GroupEvents.events.GROUP_ROSTER_UPDATE == nil)

    s.S.Set("badgeCard", false)
    check("card off: hover callbacks gone, badges stay", s.callbacks["ChatFrame.OnHyperlinkEnter"] == nil
        and #s.nameFilters == 1)
    s.S.Set("badgeCard", true)
    s.S.Set("badgeChat", false)
    check("chat off: name filter gone, and the card with it", #s.nameFilters == 0
        and s.callbacks["ChatFrame.OnHyperlinkEnter"] == nil)
    s.S.Set("badgeChat", true)
    check("chat back on: filter and card back", #s.nameFilters == 1
        and s.callbacks["ChatFrame.OnHyperlinkEnter"] ~= nil)

    local lines = {}
    local tooltip = { AddLine = function(_, text) lines[#lines + 1] = text end }
    s.S.Set("badgeTooltip", false)
    s.postCalls[1](tooltip, { guid = "Player-1-LEG" })
    check("tooltip off: no line", #lines == 0)
    s.S.Set("badgeTooltip", true)
    s.postCalls[1](tooltip, { guid = "Player-1-LEG" })
    check("tooltip on: line back, still one post-call", #lines == 1 and #s.postCalls == 1)

    s.group = { "Player-1-LEG" }
    s.S.Set("badgeBanner", true)
    check("banner on inside a group: no banner for who's already there", s.api.Toast() == nil
        and s.api.GroupEvents.events.GROUP_ROSTER_UPDATE)
    s.patron("Player-1-GUILDIE", "2026-01")
    s.guild["Player-1-GUILDIE"] = true
    s.group = { "Player-1-LEG", "Player-1-GUILDIE" }
    s.fire("GROUP_ROSTER_UPDATE")
    check("guild members skipped by default", s.api.Toast() == nil)
    s.S.Set("badgeBannerSkipGuild", false)
    s.patron("Player-1-GUILDIE2", "2026-01")
    s.guild["Player-1-GUILDIE2"] = true
    s.group = { "Player-1-LEG", "Player-1-GUILDIE", "Player-1-GUILDIE2" }
    s.fire("GROUP_ROSTER_UPDATE")
    check("guild members shown when that's off", s.api.Toast() and s.api.Toast().visible)
    s.S.Set("badgeBanner", false)
    check("banner off: stops listening", s.api.GroupEvents.events.GROUP_ROSTER_UPDATE == nil)

    local quiet = fixture(true, { badgeTooltip = false })
    check("tooltip off from the start: no post-call added", #quiet.postCalls == 0)
    quiet.S.Set("badgeTooltip", true)
    check("added when turned on", #quiet.postCalls == 1)
end

do  -- a patron with no "since" date: everything still works, the card just skips that line
    local s = fixture(true)
    s.patron("Player-1-NODATE", nil)
    local filter = s.nameFilters[1]
    check("no date: badge in chat", say(filter, "Patron", 1, "Player-1-NODATE")
        :find("BadgeLegendaryChat", 1, true))
    local enter = s.callbacks["ChatFrame.OnHyperlinkEnter"]
    enter.fn(enter.owner, {}, "player:Patron-Realm:1:SAY", "[Patron]")
    local card = s.api.Card()
    check("no date: card shows without the since line", card.visible
        and card.title.text == "Legendary Patron" and card.since.text == "")
    local lines = {}
    s.postCalls[1]({ AddLine = function(_, text) lines[#lines + 1] = text end },
        { guid = "Player-1-NODATE" })
    check("no date: tooltip line", lines[1] ~= nil)
end

do  -- regions, staff over patrons, the badge code and who may preview
    local s = fixture(true)
    local filter = s.nameFilters[1]
    s.patron("Player-9-SAME", "2026-01", 1)  -- a US patron
    check("another region's badge never shows", say(filter, "Twin", 1, "Player-9-SAME") == "Twin")
    s.region = 1
    s.api.BuildRoster()
    check("it shows in its own region", say(filter, "Twin", 2, "Player-9-SAME"):find("BadgeLegendary", 1, true))
    s.region = 3
    s.api.BuildRoster()

    s.patron("Player-1-BOTH", "2025-06")
    s.staff("Player-1-BOTH", { tier = "moderator" })
    check("staff wins over patron", say(filter, "Both", 3, "Player-1-BOTH"):find("BadgeModerator", 1, true))

    s.staff("Player-4613-OLD", { tier = "developer" }, 90)
    s.region = 110
    s.api.BuildRoster()
    check("a region the game renumbered (90 is now 110) keeps its badges",
        say(filter, "Old", 4, "Player-4613-OLD"):find("BadgeDeveloper", 1, true))
    s.region = 3
    s.api.BuildRoster()

    s.fire("PLAYER_ENTERING_WORLD")
    s.me = "Player-1-ALT2"
    s.fire("PLAYER_ENTERING_WORLD")  -- the event is unregistered after the first; log in again
    s.api.GroupEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
    s.fire("PLAYER_ENTERING_WORLD")
    s.me = "Player-1-ALT1"
    s.api.GroupEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
    s.fire("PLAYER_ENTERING_WORLD")
    s.region = 1
    s.me = "Player-7-US"
    s.api.GroupEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
    s.fire("PLAYER_ENTERING_WORLD")
    s.region, s.me = 3, "Player-1-ALT1"
    local code, count = s.api.BadgeCode()
    check("one code for every character, this one first, by region",
        code == "3:Player-1-ALT1,Player-1-ALT2,Player-1-SELF;1:Player-7-US" and count == 4)
    s.ns.BadgesCommand("id")
    check("id shows the code in a copy box", s.box.text == code and s.modal.visible)
    s.box.scripts.OnTextChanged(s.box, true)
    check("the copy box is read only", s.box.text == code)

    s.me = "Player-1-NOBODY"
    s.ns.BadgesCommand("preview naowh")
    check("preview is staff only", s.printed[#s.printed]:find("team", 1, true)
        and say(filter, "Nobody", 4, "Player-1-NOBODY") == "Nobody")
    s.ns.BadgesCommand("toast")
    check("test toast is staff only", s.api.Toast() == nil)
end

do  -- the real staff and patron files load and make sense
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,}
    for _, path in ipairs({ "Core/Badges/Staff.lua", "Core/Badges/Patrons.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, setmetatable({ _G = { NaowhForever = ns } }, { __index = _G }))
        chunk()
    end
    local staffTiers = { naowh = true, developer = true, moderator = true, ellesmere = true }
    local ok = type(ns.BADGE_STAFF) == "table" and type(ns.BADGE_PATRONS) == "table"
    for region, list in pairs(ns.BADGE_STAFF) do
        for guid, entry in pairs(list) do
            local tier = type(entry) == "table" and entry.tier or entry
            ok = ok and math.floor(region) == region and region >= 1 and guid:match("^Player%-%d+%-%x+$") ~= nil
                and staffTiers[tier] == true
        end
    end
    for region, list in pairs(ns.BADGE_PATRONS) do
        for guid, entry in pairs(list) do
            ok = ok and math.floor(region) == region and region >= 1 and guid:match("^Player%-%d+%-%x+$") ~= nil
                and (entry.since == nil or entry.since:match("^%d%d%d%d%-%d%d$") ~= nil)
        end
    end
    check("staff and patron files: region numbers, real GUIDs, known tiers", ok)
end

do  -- cost: every chat line and every group change go through this code
    local s = fixture(true)
    for i = 1, 5 do s.patron("Player-1-SUP" .. i, "2026-01") end
    s.S.Set("badgeBanner", true)
    local filter = s.nameFilters[1]
    local post = s.postCalls[1]

    -- Stubs that allocate nothing, so the numbers are the module's own.
    local guidByUnit = { player = "Player-1-SELF" }
    for i = 1, 40 do guidByUnit["raid" .. i] = i <= 5 and ("Player-1-SUP" .. i) or ("Player-1-R" .. i) end
    s.env.UnitGUID = function(unit) return guidByUnit[unit] end
    s.env.UnitFullName = function() return "Someone", "Surname" end
    s.env.PlaySound = function() end
    local members = {}
    for i = 1, 40 do members[i] = guidByUnit["raid" .. i] end
    s.group, s.raid = members, true

    local function measure(runs, fn)
        collectgarbage("collect")
        collectgarbage("stop")
        local kb = collectgarbage("count")
        local start = os.clock()
        for i = 1, runs do fn(i) end
        local ms = (os.clock() - start) * 1000 / runs
        local garbage = (collectgarbage("count") - kb) / runs
        collectgarbage("restart")
        return ms, garbage
    end

    local plainMs, plainKB = measure(200000, function(i)
        say(filter, "Someone", i, "Player-1-NOBODY")
    end)
    local supMs = measure(50000, function(i)
        say(filter, "Patron", i, "Player-1-SUP1")
    end)
    local tipData = { guid = "Player-1-NOBODY" }  -- Blizzard passes this in
    local tipMs, tipKB = measure(200000, function()
        post(nil, tipData)
    end)
    s.fire("PLAYER_ENTERING_WORLD")  -- the first scan announces quietly
    local scanMs, scanKB = measure(20000, function()
        s.fire("GROUP_ROSTER_UPDATE")
    end)

    print(string.format("chat line, no badge: %.5f ms, %.4f KB", plainMs, plainKB))
    print(string.format("chat line, badge:    %.5f ms", supMs))
    print(string.format("unit tooltip:        %.5f ms, %.4f KB", tipMs, tipKB))
    print(string.format("40-man raid change:  %.5f ms, %.4f KB", scanMs, scanKB))

    check("chat line without a badge: under 0.005 ms", plainMs < 0.005)
    check("chat line without a badge: no garbage", plainKB < 0.001)
    check("chat line with a badge: under 0.01 ms", supMs < 0.01)
    check("unit tooltip: under 0.005 ms, no garbage", tipMs < 0.005 and tipKB < 0.001)
    check("40-man raid change: under 0.1 ms, no garbage", scanMs < 0.1 and scanKB < 0.001)
end

do  -- the guild and community member list
    local s = fixture(true)
    s.staff("Player-1-DEV", { tier = "developer", title = "Lead Developer" })
    check("before the window opens, the list waits for its code", s.onLoaded.Blizzard_Communities ~= nil)
    local scroll = s.communities({ "Player-1-DEV", "Player-1-NOBODY" })
    s.onLoaded.Blizzard_Communities()
    check("then it follows the list", scroll.callbacks.OnInitializedFrame ~= nil)
    local dev, other = scroll.rows[1], scroll.rows[2]
    local badge = s.api.ListBadges[dev]
    check("a badged member's row shows the badge", badge and badge:IsShown())
    check("after the name", badge.point == "LEFT" and badge.relativeTo == dev.NameFrame.Name
        and badge.x > 40)
    check("no badge for anyone else", s.api.ListBadges[other] == nil)
    scroll:Fill(dev, "Player-1-NOBODY")
    check("a row reused for someone else hides its badge", not badge:IsShown())
    scroll:Fill(dev, "Player-1-DEV")
    check("and shows it again for a badged member", badge:IsShown())
    s.S.Set("badgeChat", false)
    s.ns.Apply()
    check("badges off: the list is no longer followed", scroll.callbacks.OnInitializedFrame == nil)
    check("and its badges are hidden", not badge:IsShown())

    -- Cost: the list fills a row as it scrolls; a full screen of rows, refilled.
    s.S.Set("badgeChat", true)
    s.ns.Apply()
    local many = {}
    for i = 1, 20 do many[i] = i % 4 == 0 and "Player-1-DEV" or "Player-1-NOBODY" end
    local big = s.communities(many)
    s.onLoaded.Blizzard_Communities()
    local runs = 500
    collectgarbage("collect")
    collectgarbage("stop")
    local before, start = collectgarbage("count"), os.clock()
    for _ = 1, runs do
        for i = 1, #big.rows do big:Fill(big.rows[i], many[i]) end
    end
    local ms = (os.clock() - start) * 1000 / runs
    local kb = (collectgarbage("count") - before) / runs
    collectgarbage("restart")
    print(("  guild list, 20 rows filled: %.5f ms, %.4f KB"):format(ms, kb))
    check("filling a screen of the guild list: under 0.05 ms", ms < 0.05)
    check("and no garbage", kb < 0.01)
end

do  -- the settings card, with the flag on
    local s = fixture(true)
    local card = s.cards["QoL/Interface:supporterBadges"]
    check("flag 1: the Supporter Badges card is on QoL > Interface", card and card.name == "Supporter Badges"
        and #card.rows == 6)
    check("flag 1: its last row shows your badge code", card.rows[6].button == s.ns.ShowBadgeCode)
    check("flag 1: /nf badges answers", type(s.ns.BadgesCommand) == "function" and s.ns.BADGE_TIERS ~= nil)
    local patreon = s.ns.LINKS[2]
    check("flag 1: Naowh's Patreon joins the links, after the others", #s.ns.LINKS == 2 and patreon[1] == "Patreon"
        and patreon[2] == "patreon" and patreon[3]() == "https://www.patreon.com/naowh")
end

do  -- ns.FEATURE_BADGES = 0: the team's badges only, on the defaults, with no settings card
    -- Saved settings a player turned off before are not read: the defaults hold.
    local s = fixture(true, { badgeChat = false, badgeCard = false, badgeTooltip = false,
        badgeBanner = true }, 0)
    local ns = s.ns
    s.staff("Player-1-DEV", { tier = "developer", title = "Lead Developer" })
    s.staff("Player-1-MOD", "moderator")
    s.staff("Player-1-NAOWH", "naowh")
    s.patron("Player-1-LEG", "2026-03")
    local filter = s.nameFilters[1]
    check("flag 0: the chat filter is on, whatever was saved", #s.nameFilters == 1)
    check("flag 0: hover card on", s.callbacks["ChatFrame.OnHyperlinkEnter"] ~= nil)
    check("flag 0: tooltip line on", #s.postCalls == 1)
    check("flag 0: the banner stays off, its default", not s.api.GroupEvents.events.GROUP_ROSTER_UPDATE)
    check("flag 0: no settings card", next(s.cards) == nil)
    check("flag 0: no Patreon link", #ns.LINKS == 1)
    check("flag 0: a developer's badge in chat", say(filter, "Glyalith", 1, "Player-1-DEV"):find("BadgeDeveloper", 1, true))
    check("flag 0: a moderator's badge in chat", say(filter, "Mod", 2, "Player-1-MOD"):find("BadgeModerator", 1, true))
    check("flag 0: Naowh's badge in chat", say(filter, "Naowh", 3, "Player-1-NAOWH"):find("BadgeNaowh", 1, true))
    check("flag 0: a patron's name is plain", say(filter, "Patron", 4, "Player-1-LEG") == "Patron")
    check("flag 0: no epic tier either", ns.BADGE_TIERS.epic == nil)
    check("flag 0: no patron tier for anyone", ns.BadgeOf("Player-1-LEG") == nil and ns.BADGE_TIERS.legendary == nil
        and ns.BadgeOf("Player-1-DEV") == ns.BADGE_TIERS.developer)
    s.callbacks["ChatFrame.OnHyperlinkEnter"].fn(nil, {}, "player:Glyalith-Realm:1:SAY", "[Glyalith]")
    local card = s.api.Card()
    check("flag 0: the developer's hover card", card and card.visible and card.title.text == "Lead Developer"
        and card.since.text == "")
    local lines = {}
    local tooltip = { AddLine = function(_, text) lines[#lines + 1] = text end }
    s.postCalls[1](tooltip, { guid = "Player-1-MOD" })
    s.postCalls[1](tooltip, { guid = "Player-1-LEG" })
    check("flag 0: a tooltip line for the moderator, none for the patron", #lines == 1
        and lines[1]:find("Moderator", 1, true))
    ns.ShowBadgeCard("legendary", "Someone")
    check("flag 0: no patron preview card", card.title.text == "Lead Developer")

    s.me = "Player-1-SELF"
    s.region = 1
    s.api.BuildRoster()
    ns.BadgesCommand("preview")
    check("flag 0: a plain preview is the developer's", say(filter, "Me", 10, "Player-1-SELF"):find("BadgeDeveloper", 1, true))
    ns.BadgesCommand("preview legendary")
    check("flag 0: no legendary preview, the help without it", not s.printed[#s.printed]:lower():find("legendary", 1, true))
    check("the help's pipes are escaped, so |n in |naowh and |none is no line break",
        not s.printed[#s.printed]:gsub("||", ""):find("|", 1, true))
    ns.BadgesCommand("toast")
    check("flag 0: the test toast is a team one", s.api.Toast().title.text == "Lead Developer")
    local hint
    ns.UI.KeepFont = function(_, key)
        return { SetPoint = function() end, SetWidth = function() end,
            SetText = function(_, text) if key == "hint" then hint = text end end }
    end
    ns.BadgesCommand("id")
    check("flag 0: the badge code asks no support request", hint and not hint:lower():find("support", 1, true))
    check("flag 0: Naowh's Discord link is still set", ns.NAOWH_DISCORD == "https://discord.com/invite/naowh")
end

do
    local s = fixture(true)
    s.staff("Player-1-DEV", "developer")
    local filter = s.nameFilters[1]
    local fake = "Naowh |TInterface\\AddOns\\NaowhForever\\Core\\Badges\\Media\\BadgeNaowhChat.tga:0:0:0:-1|t"
    check("a name wearing the badge's texture gets no badge of ours", say(filter, fake, 1, "Player-1-FAKE") == fake)
    check("a name like the team's, on another GUID, gets nothing", say(filter, "Glyalith", 2, "Player-1-NOPE") == "Glyalith")
    local long = ("|cffff0000Naowh Forever:|r "):rep(160)
    local started = os.clock()
    local out
    for line = 3, 1002 do
        out = filter("CHAT_MSG_SAY", "Glyalith", long, "Glyalith", "", "", "", "", 0, 0, "", 0, line, "Player-1-DEV")
    end
    check("a 4000-letter line of color codes costs the filter nothing", #long > 4000
        and out == "Glyalith " .. s.api.TIERS.developer.markup and os.clock() - started < 0.5)
    check("the filter returns the name, never the message", not out:find("Naowh Forever:", 1, true))

    local enter = s.callbacks["ChatFrame.OnHyperlinkEnter"]
    for _, link in ipairs({ "player", "player:", "player::", "player:Glyalith-Realm:abc:SAY",
        "player:Glyalith-Realm:" .. ("9"):rep(400) .. ":SAY", "player:%s%d:5:SAY",
        "player:|TInterface\\AddOns\\NaowhForever\\Core\\Badges\\Media\\BadgeNaowhChat.tga:0|t:7:SAY",
        "garrmission:1:2", ("player:" .. ("x"):rep(4000)) }) do
        enter.fn(enter.owner, {}, link, "[x]")
    end
    check("crafted player links show no card", s.api.Card() == nil or not s.api.Card().visible)
    enter.fn(enter.owner, {}, "player:%s%d-Realm:1002:SAY", "[x]")
    check("a name with format codes on a badged line shows as written", s.api.Card().visible
        and s.api.Card().player.text == "%s%d")
end

print(checks .. " badge checks passed")

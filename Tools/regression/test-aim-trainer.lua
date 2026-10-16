-- Offline checks for the QoL Aim Trainer (NaowhForever_QoL/Travel/AimTrainer.lua) and its leaderboard
-- (NaowhForever_QoL/Travel/AimBoard.lua) against stubs that do not allocate: nothing built or listened to
-- while off, scoring, hits and misses (a miss costs 50, never below 0, and pops "-50"), Reflex
-- expiry, the round's end and best records, the enemy faction's faces and the plain-disc fallback,
-- combat and landing closing it, no OnUpdate while idle, no garbage per click, miss or frame; sharing
-- only once you have a best, bests (payload, checks, caps, rate limits, combat, groups and
-- requests), ranks, the leaderboard view and its header, Clear Leaderboard and the card's groups.
-- These do not emulate
-- client taint, rendering or a second client. Run with Lua 5.1 from the repository root.
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local guids, guidCount = {}, 0
local function G(name)
    if not guids[name] then
        guidCount = guidCount + 1
        guids[name] = ("Player-1-%08X"):format(guidCount)
    end
    return guids[name]
end

local FACE = "Interface\\Icons\\Achievement_Character_"
local HORDE_IDS = { Orc_Male = 101, Orc_Female = 102, Undead_Male = 103, Undead_Female = 104,
    Tauren_Male = 105, Tauren_Female = 106, Troll_Male = 107, Troll_Female = 108 }
local ALLIANCE_IDS = { Human_Male = 201, Human_Female = 202, Dwarf_Male = 203, Dwarf_Female = 204,
    Nightelf_Male = 205, Nightelf_Female = 206, Gnome_Male = 207, Gnome_Female = 208 }

local function fixture(opts)
    opts = opts or {}
    local s = { now = 100, cx = 0, cy = 0, combat = false, taxi = false, faction = opts.faction,
        created = 0, events = 0, frames = {}, prints = 0, sounds = 0, addonSounds = 0,
        settings = opts.settings or {} }
    local any
    local function noop() return any end
    any = setmetatable({}, { __index = function() return noop end })
    local M = {}
    local meta = { __index = function(_, k) return M[k] or noop end }
    local function new(kind, parent)
        local o = setmetatable({ kind = kind, parent = parent, scripts = {}, events = {}, shown = true,
            w = 0, h = 0, px = 0, py = 0 }, meta)
        return o
    end
    local function frame(kind, _, parent)
        s.created = s.created + 1
        local f = new(kind, parent)
        s.frames[#s.frames + 1] = f
        return f
    end
    function M:SetScript(k, fn) self.scripts[k] = fn end
    function M:GetScript(k) return self.scripts[k] end
    function M:EnableMouse(v) self.mouse = v end
    function M:SetAlpha(a) self.alpha = a end
    function M:RegisterEvent(e) self.events[e] = true; s.events = s.events + 1 end
    function M:UnregisterEvent(e) self.events[e] = nil end
    function M:Show()
        if self.shown then return end
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function M:Hide()
        if not self.shown then return end
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function M:SetShown(v) if v then self:Show() else self:Hide() end end
    function M:IsShown() return self.shown end
    function M:SetPoint(_, _, _, x, y) if type(x) == "number" then self.px, self.py = x, y end end
    function M:SetSize(w, h) self.w, self.h = w, h end
    function M:GetWidth() return self.w end
    function M:GetHeight() return self.h end
    function M:GetCenter() return self.px, self.py end
    function M:GetLeft() return 0 end
    function M:GetTop() return 0 end
    function M:SetWidth(w) self.w = w end
    function M:GetEffectiveScale() return 1 end
    function M:GetFrameLevel() return 1 end
    function M:GetParent() return self.parent end
    function M:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
    function M:CreateTexture() return new("Texture", self) end
    function M:CreateMaskTexture() return new("Mask", self) end
    function M:CreateFontString() return new("FontString", self) end
    function M:CreateAnimationGroup() return new("AnimationGroup", self) end
    function M:CreateAnimation() return new("Animation", self) end
    function M:SetTexture(v) self.tex = v end
    function M:SetText(v) self.text = v end
    function M:SetFormattedText(fmt, a) self.fmt, self.a1 = fmt, a end
    function M:Play() self.playing = true end
    function M:Stop() self.playing = false end
    function M:UnregisterAllEvents() for k in pairs(self.events) do self.events[k] = nil end end

    local defaults = { enabled = true, aimTrainer = true, aimMode = "hexakill",
        aimPulse = true, aimSound = true, aimSoundKey = "game:click", aimShare = true }
    local S = {}
    function S.Get(k) if s.settings[k] ~= nil then return s.settings[k] end return defaults[k] end
    function S.Set(k, v) s.settings[k] = v end
    local account = {}
    local card
    local ns = { RegisterMinimapFeature = function() end, L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"), QoLConstants = dofile("Tools/regression/qol_constants.lua"), QoLSettings = S, THEME = { accent = { r = 0, g = 0.5, b = 1 }, accentSoft = { r = 0.3, g = 0.7, b = 1 },
        bg = { r = 0, g = 0, b = 0 }, panel = { r = 0.1, g = 0.1, b = 0.1 }, fg = { r = 1, g = 1, b = 1 },
        muted = { r = 0.6, g = 0.6, b = 0.6 } } }
    ns.UI = { AttachMover = function(f) local m = new("Frame", f); m.shown = false; return m end,
        CloseOnEscape = function() end, PlaySoundKey = function() s.addonSounds = s.addonSounds + 1 end }
    local parts, backdrop = {}, { Card = noop, Paint = noop }
    ns.Shared = { Style = { BORDER_RGB = { r = 0, g = 0, b = 0 }, RED_RGB = { r = 0.97, g = 0.44, b = 0.44 },
        ROUND = "round", WINDOW_HEADER = 52, BAR_GAP = 12, TAB_H = 26, TAB_FILL = 0.16 }, Parts = parts, Settings = {
        Group = function(title) return { group = title } end,
        Page = function() return { Card = function(_, spec) card = spec; return spec end } end } }
    function parts.Smooth(t) return t end
    function parts.Backdrop() return backdrop end
    function parts.TitleBar(w)
        w.title, w.subtitle, w.logo = w:CreateFontString(), w:CreateFontString(), frame("Button", nil, w)
        local close = frame("Button", nil, w)
        close:SetSize(24, 24)
        return close
    end
    function parts.BarButton(parent, _, _, _, onClick)
        local b = frame("Button", nil, parent)
        b.scripts.OnClick = onClick
        return b
    end
    function parts.Tabs(parent, w, _, onPick)
        local bar = frame("Frame", nil, parent)
        bar:SetSize(w, 26)
        bar.onPick = onPick
        return bar
    end
    function parts.PaintTabs(bar, picked) bar.picked = picked end
    function ns.Font(parent) return parent:CreateFontString() end
    function ns.Hairline(t) return t end
    function ns.Solid(parent) return parent:CreateTexture() end
    function ns.Border() end
    function ns.AllowOffscreen() end
    function ns.Button(parent, _, w, h, onClick)
        local b = frame("Button", nil, parent)
        b:SetSize(w, h)
        b._onClick = onClick
        b.scripts.OnClick = function() if b._onClick then b._onClick() end end
        return b
    end
    function ns.AccentBorder(f) return f end
    function ns.SetButtonText(b, text) b.text = text end
    function ns.Tooltip() end
    function ns.Print() s.prints = s.prints + 1 end
    function ns.AccountSettings() return account end
    function ns.Apply() end
    function ns.ShowUnlockMode() end
    function ns.HideUnlockMode() end
    function ns.SoundChoices() return {}, {}, {} end
    function ns.Confirm(_, yes) yes() end
    s.offered = true
    function ns.FlightGameHideButton(parent, size)
        local b = frame("Button", nil, parent)
        b.shown = false
        s.hide, s.hideSize = b, size
        return b
    end
    function ns.FlightGameOffered(reason) return reason == "flight" and s.offered end

    local slash = {}
    local env = { _G = { NaowhForever = ns }, UIParent = new("Frame"), CreateFrame = frame,
        GetTime = function() return s.now end,
        GetCursorPosition = function() return s.cx, s.cy end,
        InCombatLockdown = function() return s.combat end,
        UnitOnTaxi = function() return s.taxi end,
        UnitFactionGroup = function() return s.faction end,
        PlaySound = function() s.sounds = s.sounds + 1 end,
        SOUNDKIT = { IG_MAINMENU_OPTION = 852, MAP_PING = 3175 },
        BreakUpLargeNumbers = function(n) return tostring(n) end,
        SlashCmdList = slash }
    s.sent, s.prefixes, s.timers, s.guild, s.group = {}, {}, {}, opts.guild, opts.group
    s.guid = opts.guid or "Player-4613-006EB819"
    s.clock = 20000 * 86400 + 3600
    env.C_ChatInfo = { RegisterAddonMessagePrefix = function(p) s.prefixes[#s.prefixes + 1] = p end,
        SendAddonMessage = function(p, m, c) s.sent[#s.sent + 1] = { prefix = p, msg = m, channel = c } end }
    local function Cancel(timer) timer.cancelled = true end
    env.C_Timer = { After = function(d, fn) s.timers[#s.timers + 1] = { at = s.now + d, fn = fn } end,
        NewTimer = function(d, fn)
            local timer = { Cancel = Cancel }
            s.timers[#s.timers + 1] = { at = s.now + d, fn = function() if not timer.cancelled then fn() end end }
            return timer
        end }
    env.IsInGuild = function() return s.guild end
    env.IsInGroup = function(category)
        if category then return s.group == "INSTANCE_CHAT" end
        return s.group ~= nil
    end
    env.IsInRaid = function() return s.group == "RAID" end
    env.LE_PARTY_CATEGORY_INSTANCE = 2
    s.party, s.roster = {}, {}
    env.UnitGUID = function(unit)
        if unit == "player" then return s.guid end
        local m = s.party[tonumber(unit:match("^party(%d+)$") or 0)]
        return m and m[2]
    end
    env.UnitFullName = function(unit)
        if unit == "player" then return "Die", "Man" end
        local m = s.party[tonumber(unit:match("^party(%d+)$") or 0)]
        if m then return m[1]:match("^([^%- ]+)[%- ]?(.*)$") end
    end
    env.GetNumSubgroupMembers = function() return #s.party end
    env.GetNormalizedRealmName = function() return "Forever" end
    env.GetNumGuildMembers = function() return #s.roster end
    env.GetGuildRosterInfo = function(i)
        local m = s.roster[i]
        if m then return m[1], nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, m[2] end
    end
    env.UnitClass = function() return "Mage", "MAGE" end
    env.issecretvalue = function(v) return v ~= nil and v == s.secret end
    env.time = function() return s.clock end
    env.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
    env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    if opts.files ~= false then
        env.GetFileIDFromPath = function(path)
            local race = path:sub(#FACE + 1)
            return HORDE_IDS[race] or ALLIANCE_IDS[race]
        end
    end
    env.hooksecurefunc = function(t, k, fn)
        if type(t) == "string" then t, k, fn = env, t, k end
        local old = t[k]
        t[k] = function(...) old(...); fn(...) end
    end
    setmetatable(env, { __index = _G })
    for _, path in ipairs({ "Core/Senders.lua", "NaowhForever_QoL/Travel/AimTrainer.lua",
        "NaowhForever_QoL/Travel/AimBoard.lua" }) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk()
    end
    s.ns, s.S, s.env, s.account, s.slash = ns, S, env, account, slash
    s.card = function() return card end

    function s.panel()
        for _, f in ipairs(s.frames) do if f.scripts.OnKeyDown then return f end end
    end
    function s.area()
        for _, f in ipairs(s.frames) do if f.kind == "Frame" and f.scripts.OnMouseDown then return f end end
    end
    function s.targets()
        local out = {}
        for _, f in ipairs(s.frames) do
            if f.kind == "Button" and f.scripts.OnMouseDown then out[#out + 1] = f end
        end
        return out
    end
    function s.clickArea() s.area().scripts.OnMouseDown(s.area(), "LeftButton") end
    function s.hit(t)
        s.cx, s.cy = t.px, t.py
        t.scripts.OnMouseDown(t, "LeftButton")
    end
    function s.edge(t)
        s.cx, s.cy = t.px + t.w / 2, t.py + t.w / 2
        t.scripts.OnMouseDown(t, "LeftButton")
    end
    function s.tick(dt)
        s.now = s.now + dt
        local p = s.panel()
        if p.scripts.OnUpdate then p.scripts.OnUpdate(p, dt) end
    end
    function s.wait(dt)
        s.now = s.now + dt
        local i = 1
        while i <= #s.timers do
            local t = s.timers[i]
            if t.at <= s.now then
                table.remove(s.timers, i)
                t.fn()
            else
                i = i + 1
            end
        end
    end
    function s.comms()
        for _, f in ipairs(s.frames) do
            if f.scripts.OnEvent and not f.scripts.OnKeyDown then return f end
        end
    end
    function s.member(list, name, guid)
        for _, m in ipairs(list) do
            if m[1] == name then m[2] = guid return end
        end
        list[#list + 1] = { name, guid }
    end
    function s.receive(message, channel, sender)
        local f = s.comms()
        local text = message:gsub("@", G(sender))
        local claimed = text:match("^%d+ B (%S+)")
        if claimed and not s.strict then
            if channel == "GUILD" then s.member(s.roster, sender, claimed) end
            if channel == "PARTY" or channel == "RAID" then s.member(s.party, sender, claimed) end
        end
        ns._SendersTest.GuildChanged()
        f.scripts.OnEvent(f, "CHAT_MSG_ADDON", "NaowhAim", text, channel, sender)
    end
    function s.event(event)
        local f = s.comms()
        f.scripts.OnEvent(f, event)
    end
    function s.board(mode)
        local list = s.account.aimBoard and s.account.aimBoard[mode]
        if not list then return nil end
        local byName = {}
        for _, e in pairs(list) do byName[e.name] = e end
        return byName
    end
    return s
end

local function between(v, lo, hi) return type(v) == "number" and v >= lo and v <= hi end

-- Off: nothing built, nothing listened to, and nothing opens.
do
    local s = fixture({ faction = "Alliance", settings = { aimTrainer = false } })
    check("off: no frames at load", s.created == 0)
    check("off: no events at load", s.events == 0)
    local card = s.card()
    check("the card is declared on QoL/Travel", card and card.id == "aimTrainer" and card.switch == "aimTrainer")
    check("the card has a studio", card.studio and card.studio.new and card.studio.paint)
    check("/nfaim is registered", s.env.SLASH_NAOWHFOREVERAIM1 == "/nfaim" and s.slash.NAOWHFOREVERAIM ~= nil)
    s.slash.NAOWHFOREVERAIM("")
    check("off: /nfaim says so and builds nothing", s.prints == 1 and s.created == 0)
    s.ns.AimOffer("flight")
    s.ns.ToggleAimTrainer()
    check("off: offers and toggles build nothing", s.created == 0)
    s.S.Set("aimTrainer", true)
    check("switching it on with no records builds and registers nothing", s.created == 0 and s.events == 0
        and #s.prefixes == 0 and s.panel() == nil and #s.sent == 0)
end

-- Don't Show on Flights: the eye shows when a flight opened it by itself, and goes once a round starts.
do
    local s = fixture({ faction = "Alliance" })
    s.ns.AimOffer("flight")
    check("a flight opening it shows the eye", s.hide and s.hide.shown)
    check("the eye's box is the close button's size", s.hideSize == 24)
    s.clickArea()
    check("starting a round hides the eye", not s.hide.shown)
    s.panel():Hide()
    s.ns.ToggleAimTrainer()
    check("opened by hand, no eye", s.panel().shown and not s.hide.shown)
    s.panel():Hide()
    s.offered = false
    s.ns.AimPlay("gridshot", "flight")
    check("a game button with nothing opening by itself shows no eye", s.panel().shown and not s.hide.shown)
end

-- Gridshot: scoring, hits and misses, round end, records, sound.
do
    local s = fixture({ faction = "Alliance", settings = { aimTrainer = true, aimMode = "gridshot" } })
    s.ns.ToggleAimTrainer()
    local p = s.panel()
    check("opens by hand", p and p.shown)
    check("no OnUpdate while idle", p.scripts.OnUpdate == nil)
    check("listens for combat only while shown", p.events.PLAYER_REGEN_DISABLED == true)
    local targets = s.targets()
    check("six targets pooled, for Hexakill", #targets == 6)
    check("no target shown before the round", not targets[1].shown and not targets[2].shown)
    s.clickArea()
    check("clicking the play area starts a round", p.scripts.OnUpdate ~= nil)
    check("three targets up", targets[1].shown and targets[2].shown and targets[3].shown
        and not targets[4].shown)
    check("targets sized by Target Size", targets[1].w == 44)
    check("targets inside the play area", between(targets[1].px, 22, 458) and between(-targets[1].py, 22, 278))
    check("pulse plays", targets[1].ring.playing)
    s.hit(targets[1])
    check("an instant hit scores double", p.score.a1 == 200)
    check("the hit sound plays", s.sounds == 1)
    check("the hit target comes back somewhere", targets[1].shown)
    s.now = s.now + 0.5
    s.hit(targets[2])
    check("half a second, combo 2: 158", p.score.a1 == 358)
    check("combo counts", p.combo.a1 == 2)
    s.cx, s.cy = 120, -90
    s.clickArea()
    check("a miss breaks the combo", p.combo.a1 == 0)
    check("a miss costs 50", p.score.a1 == 308)
    check("accuracy 2 of 3", p.accuracy.a1 == 67)
    local pop = p.missPops[1]
    check("a miss pops -50 where you clicked", pop.shown and pop.text == "-50" and pop.anim.playing
        and pop.px == 120 and pop.py == -90)
    s.edge(targets[3])
    check("the corner of a target's box is a miss", p.score.a1 == 258 and p.accuracy.a1 == 50)
    check("the next miss takes the next pooled pop", p.missPops[2].shown and p.missNext == 2)
    s.tick(31)
    check("the round ends on time", p.scripts.OnUpdate == nil)
    check("targets hidden at the end", not targets[1].shown and not targets[2].shown and not targets[3].shown)
    check("the results card shows", p.card.shown and p.card.title.text == "New Best!")
    check("best score saved per mode", s.account.aimBest.gridshot == 258)
    check("no best accuracy under ten shots", s.account.aimBestAccuracy.gridshot == nil)
    check("average reaction in ms", p.card.values[4].a1 == 250)
    local function locked()
        local b = p.card.buttons
        return b[1].mouse == false and b[2].mouse == false and b[3].mouse == false and b[2].alpha < 1
    end
    check("the results card's buttons wait a moment before they take a click", locked()
        and not p.modeButton.shown and not p.boardButton.shown)
    s.wait(0.5)
    check("still waiting after half a second", locked())
    s.wait(0.5)
    check("then they take clicks, and the header buttons come back", p.card.close.mouse == true
        and p.card.close.alpha == 1 and p.modeButton.shown and p.boardButton.shown)

    p.card.again._onClick()
    check("Play Again starts another round", p.scripts.OnUpdate ~= nil and not p.card.shown)
    local before = s.sounds
    s.S.Set("aimSound", false)
    for i = 1, 12 do s.hit(targets[(i % 3) + 1]) end
    check("sound read at round start", s.sounds == before + 12)
    s.tick(31)
    check("a better round is a new best", s.account.aimBest.gridshot > 258)
    check("best accuracy kept with ten shots or more", s.account.aimBestAccuracy.gridshot == 100)
    p.card.again._onClick()
    for i = 1, 3 do s.hit(targets[i]) end
    s.tick(31)
    check("a worse round keeps the best", p.card.title.text == "Round Over")
    p:Hide()
    check("closing during the wait clears it", p.card.close.mouse == true and not p.shown)
    s.wait(1)
    s.ns.ToggleAimTrainer()
    s.clickArea()
    for i = 1, 3 do s.hit(targets[i]) end
    s.tick(31)
    check("sound off: no sound", s.sounds == before + 12)
    p.card.close._onClick()
    check("Close hides it", not p.shown and p.scripts.OnUpdate == nil)
    check("hidden: stops listening for combat", p.events.PLAYER_REGEN_DISABLED == nil)
    s.card().rows[#s.card().rows].button()
    check("Reset Records clears every mode", s.account.aimBest == nil and s.account.aimBestAccuracy == nil)
end

-- Hexakill: six up at once; AimPlay picks a mode and opens it.
do
    local s = fixture({ faction = "Alliance", settings = { aimTrainer = true } })
    s.ns.AimPlay("hexakill", "flight")
    local p, targets = s.panel(), s.targets()
    check("AimPlay opens it in the mode asked for", p and p.shown and s.settings.aimMode == "hexakill")
    s.clickArea()
    local up = 0
    for i = 1, #targets do if targets[i].shown then up = up + 1 end end
    check("hexakill: six targets up", up == 6)
    s.hit(targets[4])
    check("hexakill: a hit brings a new one", targets[4].shown)
    s.ns.AimPlay("bogus")
    check("an unknown mode falls back to Hexakill", s.settings.aimMode == "hexakill")
end

-- Reflex: one shrinking target, expiry is a miss.
do
    local s = fixture({ faction = "Horde", settings = { aimTrainer = true, aimMode = "reflex" } })
    s.ns.ToggleAimTrainer()
    local p, targets = s.panel(), s.targets()
    s.clickArea()
    check("reflex: nothing at the start", not targets[1].shown)
    s.tick(0.7)
    check("reflex: one target after a moment", targets[1].shown and not targets[2].shown)
    check("reflex: full size", targets[1].w == 44)
    s.tick(0.75)
    check("reflex: halfway through its life, half its size", math.abs(targets[1].w - 22) < 0.01)
    s.tick(0.8)
    check("reflex: it vanishes", not targets[1].shown)
    check("reflex: a vanished target is a miss", p.accuracy.a1 == 0 and p.combo.a1 == 0)
    check("reflex: a miss at 0 stays at 0", p.score.a1 == 0)
    check("reflex: the -50 pops at the target's spot", p.missPops[1].shown
        and p.missPops[1].px == targets[1].px and p.missPops[1].py == targets[1].py)
    s.tick(0.8)
    check("reflex: the next one comes", targets[1].shown)
    s.hit(targets[1])
    check("reflex: a hit retires it", not targets[1].shown and p.accuracy.a1 == 50)
    check("reflex: the time shows", p.time.fmt == "%.1f")
    local scored = p.score.a1
    s.tick(0.8)
    check("reflex: another target comes", targets[1].shown)
    s.tick(1.6)
    check("reflex: a vanished target costs 50", not targets[1].shown and scored > 50
        and p.score.a1 == scored - 50 and p.combo.a1 == 0)
end

-- The score never drops below 0.
do
    local s = fixture({ faction = "Alliance", settings = { aimMode = "gridshot" } })
    s.ns.ToggleAimTrainer()
    local p = s.panel()
    s.clickArea()
    s.clickArea()
    check("a miss at 0 stays at 0", p.score.a1 == 0 and p.combo.a1 == 0)
    s.hit(s.targets()[1])
    for _ = 1, 3 do s.clickArea() end
    check("three misses after a hit: 200 less 150", p.score.a1 == 50)
    s.clickArea()
    check("a miss never takes the score below 0", p.score.a1 == 0)
    check("four pops, reused in turn", #p.missPops == 4 and p.missNext == 1)
end

-- The enemy faction's faces, and the plain disc when there is none.
do
    local s = fixture({ faction = "Alliance", settings = { aimTrainer = true } })
    s.ns.ToggleAimTrainer()
    s.clickArea()
    local t = s.targets()[1]
    check("Alliance: a Horde face", between(t.face.tex, 101, 108) and t.face.shown)
    check("faces are masked round", t.face ~= nil and t.mask ~= nil)
end
do
    local s = fixture({ faction = "Horde", settings = { aimTrainer = true } })
    s.ns.ToggleAimTrainer()
    s.clickArea()
    local t = s.targets()[2]
    check("Horde: an Alliance face", between(t.face.tex, 201, 208) and t.face.shown)
end
do
    local s = fixture({ faction = nil, settings = { aimTrainer = true } })
    s.ns.ToggleAimTrainer()
    s.clickArea()
    local t = s.targets()[1]
    check("no faction: the plain disc", not t.face.shown and t.body.shown)
    s.ns.ToggleAimTrainer()
    s.faction = "Neutral"
    s.ns.ToggleAimTrainer()
    s.clickArea()
    check("neutral: the plain disc", not t.face.shown)
end
do
    local s = fixture({ faction = "Alliance", files = false, settings = { aimTrainer = true } })
    s.ns.ToggleAimTrainer()
    s.clickArea()
    check("no file check: the plain disc", not s.targets()[1].face.shown)
end

-- Combat, flights and switching off.
do
    local s = fixture({ faction = "Alliance", settings = { aimTrainer = true } })
    s.combat = true
    s.ns.ToggleAimTrainer()
    check("refuses to open in combat", s.created == 0 and s.prints == 1)
    s.ns.AimOffer("flight")
    check("a flight offer in combat opens nothing, quietly", s.created == 0 and s.prints == 1)
    s.combat = false
    s.ns.AimOffer("flight")
    local p = s.panel()
    check("a flight offer opens it", p and p.shown)
    s.clickArea()
    s.combat = true
    p.scripts.OnEvent(p, "PLAYER_REGEN_DISABLED")
    check("combat closes it and stops the round", not p.shown and p.scripts.OnUpdate == nil)
    s.combat = false
    s.ns.ToggleAimTrainer()
    s.ns.AimDismiss("flight")
    check("opened by hand off a taxi: landing leaves it", p.shown)
    s.ns.ToggleAimTrainer()
    s.taxi = true
    s.ns.ToggleAimTrainer()
    s.ns.AimDismiss("flight")
    check("opened by hand on a taxi: landing closes it", not p.shown)
    s.ns.AimOffer("flight")
    s.clickArea()
    s.S.Set("aimTrainer", false)
    check("switching off closes it", not p.shown and p.scripts.OnUpdate == nil)
    check("the Play button asks whether it is on", s.ns.AimTrainerOn() == false)
    s.ns.AimOffer("flight")
    check("off: a flight offer opens nothing", not p.shown)
end

-- Not in Unlock Mode (Robin, 2026-10-05: it took a lot of room): the window drags itself.
do
    local s = fixture({ faction = "Alliance", settings = { aimTrainer = true } })
    s.ns.ShowUnlockMode()
    local p = s.panel()
    check("Unlock Mode does not open it", not (p and p.shown))
    s.ns.HideUnlockMode()
    s.ns.AimOffer("flight")
    p = s.panel()
    check("it drags by itself", p and p.scripts.OnDragStart ~= nil and p.scripts.OnDragStop ~= nil)
end

-- The card's Play Now and its summary.
do
    local s = fixture({ faction = "Alliance", settings = { aimTrainer = true } })
    local card = s.card()
    check("summary without a best", card.summary(s.S) == "Hexakill, no best yet")
    local groups, size, single, keys = 0, nil, false, {}
    for _, row in ipairs(card.rows) do
        if row.label == "Play Now" then row.button() end
        if row.key then keys[row.key] = true end
        if row.group then
            if size == 1 then single = true end
            groups, size = groups + 1, 0
        elseif size then
            size = size + 1
        end
    end
    if size == 1 then single = true end
    check("three groups, none with a single row", groups == 3 and not single)
    check("no flight toggle of its own", not keys.aimAutoFlight and keys.aimMode and keys.aimShare)
    check("Play Now opens it", s.panel() and s.panel().shown)
    s.account.aimBest = { hexakill = 4210 }
    check("summary with a best", card.summary(s.S) == "Hexakill, best 4210")
end

-- No garbage per click or per frame.
do
    local s = fixture({ faction = "Alliance", settings = { aimTrainer = true } })
    s.ns.ToggleAimTrainer()
    s.clickArea()
    local targets = s.targets()
    for i = 1, 30 do s.hit(targets[(i % 3) + 1]); s.clickArea(); s.tick(0.001) end
    collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    for i = 1, 600 do
        s.hit(targets[(i % 3) + 1])
        s.clickArea()
        s.tick(0.01)
    end
    local grown = collectgarbage("count") - before
    collectgarbage("restart")
    check(("no garbage per click or frame (%.3f KB)"):format(grown), grown < 0.05)
    for _ = 1, 20 do s.clickArea(); s.edge(targets[1]) end
    collectgarbage("collect")
    collectgarbage("stop")
    before = collectgarbage("count")
    for _ = 1, 600 do
        s.clickArea()
        s.edge(targets[1])
    end
    grown = collectgarbage("count") - before
    collectgarbage("restart")
    check(("no garbage per miss (%.3f KB)"):format(grown), grown < 0.05)

    local r = fixture({ faction = "Alliance", settings = { aimTrainer = true, aimMode = "reflex" } })
    r.ns.ToggleAimTrainer()
    r.clickArea()
    local t = r.targets()[1]
    for _ = 1, 50 do
        r.tick(0.05)
        if t.shown then r.hit(t) end
    end
    collectgarbage("collect")
    collectgarbage("stop")
    before = collectgarbage("count")
    for i = 1, 600 do
        r.tick(0.02)
        if t.shown and i % 7 == 0 then r.hit(t) end
    end
    grown = collectgarbage("count") - before
    collectgarbage("restart")
    check(("reflex: no garbage per frame (%.3f KB)"):format(grown), grown < 0.05)
end

local function msg(mode, score, acc, class, day, guid)
    return ("2 B %s %s %s %s %s %s"):format(guid or "@", mode, score, acc, class or "WARRIOR", day or 20000)
end

-- Sharing waits for a first best: a round's record starts it, a saved best starts it at login,
-- and Reset Records stops it.
do
    local s = fixture({ faction = "Alliance", guild = true })
    s.ns.Apply()
    s.wait(30)
    check("no records: no prefix, no events, nothing sent", #s.prefixes == 0 and s.events == 0
        and s.comms() == nil and #s.sent == 0)
    s.ns.AimBoard.Record("hexakill")
    check("no records: a record call starts nothing", #s.prefixes == 0 and s.comms() == nil)
    s.ns.ToggleAimTrainer()
    s.clickArea()
    s.hit(s.targets()[1])
    s.tick(31)
    check("a first best starts listening", #s.prefixes == 1 and s.comms() ~= nil
        and s.comms().events.CHAT_MSG_ADDON and s.comms().events.GROUP_ROSTER_UPDATE)
    check("nothing goes out before the settle", #s.sent == 0)
    s.wait(11)
    check("after the settle: a request and the new best to the guild", #s.sent == 2
        and s.sent[1].msg == "2 R " .. s.guid and s.sent[2].msg == "2 B " .. s.guid .. " hexakill 200 - MAGE 20000")
    for _, row in ipairs(s.card().rows) do
        if row.label == "Reset Records" then row.button() end
    end
    check("Reset Records stops it", next(s.comms().events) == nil)
    s.ns.AimBoard.Record("hexakill")
    s.wait(30)
    check("no records again: nothing more sent", #s.sent == 2 and next(s.comms().events) == nil)
end
do
    local s = fixture({ faction = "Alliance", guild = true })
    s.account.aimBest = { reflex = 900 }
    s.ns.Apply()
    check("a saved best: listening from login", #s.prefixes == 1 and s.comms().events.CHAT_MSG_ADDON)
    s.account.aimBest = { reflex = 0 }
    s.ns.AimBoard.Sync()
    check("a zero best is not a best", next(s.comms().events) == nil)
end

-- Sharing: nothing registered or sent while off or with Share My Scores off.
do
    local s = fixture({ faction = "Alliance", guild = true, settings = { aimShare = false, aimTrainer = false } })
    s.ns.Apply()
    s.S.Set("aimTrainer", true)
    check("share off: nothing built or registered", s.created == 0 and s.events == 0 and #s.prefixes == 0)
    s.account.aimBest = { gridshot = 4210 }
    s.ns.AimBoard.Record("gridshot")
    s.wait(30)
    check("share off: nothing sent", #s.sent == 0)
    s.S.Set("aimShare", true)
    check("share on: the prefix and three events", #s.prefixes == 1 and s.prefixes[1] == "NaowhAim" and s.events == 3)
    check("share on: nothing sent before the settle", #s.sent == 0)
    s.S.Set("aimTrainer", false)
    check("the Aim Trainer off: no events", next(s.comms().events) == nil)
    s.wait(30)
    check("a settle pending when switched off sends nothing", #s.sent == 0)
    s.S.Set("aimTrainer", true)
    check("on again: the prefix is not registered twice", #s.prefixes == 1)
end

-- Login: after a settle, a request and your bests to the guild; the payload's round trip.
do
    local s = fixture({ faction = "Alliance", guild = true, settings = { aimTrainer = true } })
    s.account.aimBest = { gridshot = 4210, reflex = 900 }
    s.account.aimBestAccuracy = { gridshot = 87 }
    s.ns.Apply()
    s.wait(5)
    check("login: nothing before the settle", #s.sent == 0)
    s.wait(6)
    check("login: a request, then your bests, to the guild", #s.sent == 3 and s.sent[1].msg == "2 R " .. s.guid
        and s.sent[1].channel == "GUILD" and s.sent[1].prefix == "NaowhAim" and s.sent[3].channel == "GUILD")
    check("the payload carries your GUID", s.sent[2].msg == "2 B " .. s.guid .. " gridshot 4210 87 MAGE 20000"
        and s.sent[3].msg == "2 B " .. s.guid .. " reflex 900 - MAGE 20000")
    check("payloads stay short", #msg("hexakill", 240000, 100, "WARRIOR", 20000, s.guid) <= 112)
    s.ns.Apply()
    s.wait(30)
    check("Apply again sends nothing more", #s.sent == 3)

    local r = fixture({ faction = "Horde", guid = "Player-4613-00000002", settings = { aimTrainer = true } })
    r.account.aimBest = { hexakill = 100 }
    r.ns.Apply()
    r.receive(s.sent[2].msg, "GUILD", "Other-Guy")
    r.receive(s.sent[3].msg, "GUILD", "Other-Guy")
    local e = r.account.aimBoard.gridshot[s.guid]
    check("round trip: kept under the sender's GUID", e and e.score == 4210 and e.acc == 87
        and e.class == "MAGE" and e.day == 20000 and e.guild == true)
    check("round trip: the full name, first and surname", e.name == "Other Guy")
    local x = r.account.aimBoard.reflex[s.guid]
    check("round trip: no accuracy", x and x.score == 900 and x.acc == nil)
    r.receive(s.sent[2].msg, "PARTY", "Other-Guy")
    check("a guild entry stays one when it also comes over the group", e.guild == true)
    r.receive(msg("gridshot", 3000, 50), "PARTY", "Party-Pal")
    check("a group entry is not a guild one", r.board("gridshot")["Party Pal"].guild == false)
    local waiting = #r.timers
    r.receive(s.sent[1].msg, "GUILD", "Other-Guy")
    check("a request is answered, not stored", #r.timers == waiting + 1 and e.score == 4210)
end

-- Names: Forever's first names are not unique, so entries are kept by GUID under the full name.
do
    local s = fixture({ faction = "Alliance", settings = { aimTrainer = true, aimMode = "gridshot" } })
    s.account.aimBest = { gridshot = 2500 }
    s.ns.Apply()
    s.receive(msg("gridshot", 3000, 50), "GUILD", "Die-Dudu")
    s.receive(msg("gridshot", 2000, 50), "GUILD", "Die-Pri")
    local board = s.board("gridshot")
    check("one first name, two players", board["Die Dudu"].score == 3000 and board["Die Pri"].score == 2000)
    s.receive(msg("gridshot", 1000, 50, "MAGE", 20000, "Player-1-0000BEEF"), "GUILD", "Same-Name")
    s.receive(msg("gridshot", 1500, 50, "MAGE", 20000, "Player-1-0000CAFE"), "GUILD", "Same-Name")
    local n = 0
    for _ in pairs(s.account.aimBoard.gridshot) do n = n + 1 end
    check("one full name, two GUIDs: two entries", n == 4)
    s.receive(msg("gridshot", 100, 50), "GUILD", "Lonely")
    check("a name with no surname shows as it is", s.board("gridshot").Lonely.score == 100)
    s.receive(msg("gridshot", 100, 50), "GUILD", string.rep("x", 41))
    check("a name too long is ignored", s.board("gridshot")[string.rep("x", 41)] == nil)
    s.ns.ToggleAimTrainer()
    local p = s.panel()
    p.boardButton.scripts.OnClick(p.boardButton)
    local rows = p.board.rows
    check("the view: full names, two rows for one first name", rows[1].name.text == "Die Dudu"
        and rows[2].name.text == "Die Man" and rows[3].name.text == "Die Pri")
    check("your own row is your full name", rows[2].mark.shown)
end

-- Claims for someone else: a best is kept only from the guild member its GUID names, and an
-- entry stays with the name it was saved under.
do
    local s = fixture({ faction = "Alliance", settings = { aimTrainer = true } })
    s.account.aimBest = { hexakill = 100 }
    s.ns.Apply()
    s.strict = true
    s.roster = { { "Real-Player", "Player-1-0000AAAA" }, { "Spray-Er", "Player-1-0000B001" } }
    s.receive(msg("gridshot", 3000, 50, "MAGE", 20000, "Player-1-0000AAAA"), "GUILD", "Real-Player")
    s.receive(msg("gridshot", 240000, 100, "MAGE", 20000, "Player-1-0000AAAA"), "GUILD", "Fake-Player")
    check("another sender cannot take a player's entry", s.board("gridshot")["Real Player"].score == 3000
        and s.board("gridshot")["Fake Player"] == nil)
    for i = 1, 6 do
        s.receive(msg("gridshot", 1000 + i, 50, "MAGE", 20000, ("Player-1-0000B%03X"):format(i)), "GUILD", "Spray-Er")
    end
    local sprayed = 0
    for _, e in pairs(s.account.aimBoard.gridshot) do if e.name == "Spray Er" then sprayed = sprayed + 1 end end
    check("one sender fills only its own entry", sprayed == 1)
    local later = fixture({ faction = "Alliance", settings = { aimTrainer = true } })
    later.account.aimBest = { hexakill = 100 }
    later.account.aimBoard = { gridshot = { ["Player-1-0000AAAA"] = { score = 3000, acc = 50, class = "MAGE",
        day = 20000, name = "Real Player" } } }
    later.ns.Apply()
    later.strict = true
    later.roster = { { "Real-Player", "Player-1-0000AAAA" }, { "Fake-Player", "Player-1-0000FFFF" } }
    later.receive(msg("gridshot", 240000, 100, "MAGE", 20000, "Player-1-0000AAAA"), "GUILD", "Fake-Player")
    check("nor in a later session, from what was saved", later.board("gridshot")["Real Player"].score == 3000)
end

-- What arrives is checked: length, version, GUID, mode, score ceiling, accuracy, class, day, channel, sender.
do
    local s = fixture({ faction = "Alliance", settings = { aimTrainer = true } })
    s.account.aimBest = { hexakill = 100 }
    s.ns.Apply()
    local ceiling = s.ns.AimRules.Ceiling
    check("ceilings from the scoring rules and the 30 s round", ceiling("gridshot") == 240000
        and ceiling("hexakill") == 240000 and ceiling("reflex") == 47200)
    local bad = {
        { "too long", msg("gridshot", 100, 50, string.rep("A", 100)) },
        { "a class too long", msg("gridshot", 100, 50, string.rep("A", 13)) },
        { "the old format", "1 B gridshot 100 50 MAGE 20000" },
        { "another version", "3 B @ gridshot 100 50 MAGE 20000" },
        { "no version", "B @ gridshot 100 50 MAGE 20000" },
        { "no GUID", "2 B gridshot 100 50 MAGE 20000" },
        { "a creature GUID", msg("gridshot", 100, 50, "MAGE", 20000, "Creature-0-1-2-3-4-5") },
        { "a malformed GUID", msg("gridshot", 100, 50, "MAGE", 20000, "Player-1-XYZ") },
        { "a GUID too long", msg("gridshot", 100, 50, "MAGE", 20000, "Player-1-" .. string.rep("A", 40)) },
        { "an impossible score", msg("gridshot", 240001, 50) },
        { "an impossible Reflex score", msg("reflex", 47201, 50) },
        { "a zero score", msg("gridshot", 0, 50) },
        { "accuracy over 100", msg("gridshot", 100, 101) },
        { "malformed accuracy", msg("gridshot", 100, "5-0") },
        { "negative accuracy", msg("gridshot", 100, "-5") },
        { "an unknown mode", msg("bogus", 100, 50) },
        { "a day in the future", msg("gridshot", 100, 50, "MAGE", 20002) },
        { "a lowercase class", msg("gridshot", 100, 50, "mage") },
        { "an extra field", msg("gridshot", 100, 50) .. " 1" },
    }
    for i, case in ipairs(bad) do
        s.receive(case[2], "GUILD", "Sender " .. i)
        check("rejects " .. case[1], s.account.aimBoard == nil)
    end
    s.receive(msg("gridshot", 100, 50), "WHISPER", "Whisperer")
    check("whispers are ignored", s.account.aimBoard == nil)
    local f = s.comms()
    f.scripts.OnEvent(f, "CHAT_MSG_ADDON", "OtherPrefix", msg("gridshot", 100, 50, nil, nil, "Player-1-00000001"),
        "GUILD", "Someone")
    check("other prefixes are ignored", s.account.aimBoard == nil)
    s.secret = "Secret Sender"
    s.receive(msg("gridshot", 100, 50), "GUILD", "Secret Sender")
    check("a secret sender is ignored", s.account.aimBoard == nil)
    s.secret = nil
    s.receive(msg("gridshot", 100, 50, "MAGE", 20000, s.guid), "GUILD", "Anyone-Else")
    check("your own GUID is ignored, whatever the name", s.account.aimBoard == nil)
    local waiting = #s.timers
    s.receive("2 R " .. s.guid, "GUILD", "Die-Man")
    s.receive("2 R Creature-0-1", "GUILD", "Bad-Asker")
    s.receive("1 R", "GUILD", "Old-Asker")
    check("your own request, a bad GUID and the old request are not answered", #s.timers == waiting)
    s.receive(msg("gridshot", 240000, 100), "GUILD", "Top Gun")
    check("the ceiling itself is allowed", s.board("gridshot")["Top Gun"].score == 240000)
end

do
    local s = fixture({ faction = "Alliance", settings = { aimTrainer = true } })
    s.account.aimBest = { hexakill = 100 }
    s.ns.Apply()
    s.strict = true
    s.roster = { { "Real-One", "Player-1-0000AAAA" }, { "Other-Guild", "Player-1-0000BBBB" } }
    s.party = { { "Party-Pal", "Player-1-0000CCCC" }, { "Second-Pal", "Player-1-0000DDDD" } }
    s.receive(msg("gridshot", 9000, 50, "MAGE", 20000, "Player-1-0000BBBB"), "GUILD", "Real-One")
    check("a guildmate sending another's GUID is dropped", s.account.aimBoard == nil)
    s.receive(msg("gridshot", 9000, 50, "MAGE", 20000, "Player-1-0000EEEE"), "GUILD", "Not-Here")
    check("a sender not in the guild is dropped", s.account.aimBoard == nil)
    s.receive(msg("gridshot", 9000, 50, "MAGE", 20000, "Player-1-0000DDDD"), "PARTY", "Party-Pal")
    check("a group member sending another member's GUID is dropped", s.account.aimBoard == nil)
    s.receive(msg("gridshot", 3000, 50, "MAGE", 20000, "Player-1-0000AAAA"), "GUILD", "Real-One-Forever")
    check("their own is taken, with your realm after the name", s.board("gridshot")["Real One-Forever"].score == 3000)
    s.receive(msg("gridshot", 4000, 50, "MAGE", 20000, "Player-1-0000CCCC"), "PARTY", "Party Pal")
    check("and from the group, the name with a space", s.board("gridshot")["Party Pal"].score == 4000)
end

-- Caps: 200 entries per mode, the weakest dropped; a rate limit per sender.
do
    local s = fixture({ faction = "Alliance", settings = { aimTrainer = true } })
    s.account.aimBest = { hexakill = 100 }
    s.ns.Apply()
    for i = 1, 205 do s.receive(msg("gridshot", i * 10, 50), "GUILD", "Player " .. i) end
    local function stats()
        local count, lowest = 0, math.huge
        for _, e in pairs(s.account.aimBoard.gridshot) do
            count = count + 1
            lowest = math.min(lowest, e.score)
        end
        return count, lowest
    end
    local count, lowest = stats()
    check("at most 200 kept per mode", count == 200)
    check("the weakest are dropped", lowest == 60 and s.board("gridshot")["Player 1"] == nil)
    s.receive(msg("gridshot", 5, 50), "GUILD", "Weak One")
    check("full: a score under the weakest is not kept", s.board("gridshot")["Weak One"] == nil)
    s.receive(msg("gridshot", 60, 50, "MAGE", 19999), "GUILD", "Old One")
    check("full: a tie with the weakest from an older day is not kept", s.board("gridshot")["Old One"] == nil)
    s.receive(msg("gridshot", 9999, 50), "GUILD", "Player 205")
    count = stats()
    check("an update to a kept player keeps the count", count == 200 and s.board("gridshot")["Player 205"].score == 9999)

    local r = fixture({ faction = "Alliance", settings = { aimTrainer = true } })
    r.account.aimBest = { hexakill = 100 }
    r.ns.Apply()
    for i = 1, 13 do r.receive(msg("gridshot", 100 + i, 50), "GUILD", "Spammer") end
    check("rate limited per sender", r.board("gridshot").Spammer.score == 112)
    r.wait(61)
    r.receive(msg("gridshot", 500, 50), "GUILD", "Spammer")
    check("allowed again after the window", r.board("gridshot").Spammer.score == 500)
end

-- Never sent in combat: held until it ends.
do
    local s = fixture({ faction = "Alliance", guild = true, settings = { aimTrainer = true } })
    s.account.aimBest = { hexakill = 3000 }
    s.ns.Apply()
    s.combat = true
    s.wait(11)
    check("combat: nothing sent at the settle", #s.sent == 0)
    s.ns.AimBoard.Record("hexakill")
    s.receive("2 R @", "GUILD", "Asker")
    s.wait(5)
    check("combat: a new best and an answer wait", #s.sent == 0)
    s.receive(msg("gridshot", 2000, 60), "GUILD", "Fighter")
    check("combat: what arrives is still kept", s.board("gridshot").Fighter.score == 2000)
    s.combat = false
    s.event("PLAYER_REGEN_ENABLED")
    check("after combat: the request and your best go out", #s.sent >= 2 and s.sent[1].msg == "2 R " .. s.guid
        and s.sent[2].msg == "2 B " .. s.guid .. " hexakill 3000 - MAGE 20000")
    local n = #s.sent
    s.event("PLAYER_REGEN_ENABLED")
    check("and only once", #s.sent == n)
end

-- Groups: joining asks and gives, debounced; requests are answered after a moment, rate limited.
do
    local s = fixture({ faction = "Alliance", settings = { aimTrainer = true } })
    s.account.aimBest = { gridshot = 4210 }
    s.ns.Apply()
    s.wait(11)
    check("no guild, no group: nothing sent", #s.sent == 0)
    s.group = "PARTY"
    s.event("GROUP_ROSTER_UPDATE")
    s.event("GROUP_ROSTER_UPDATE")
    check("joining: one update for a burst", #s.timers == 1)
    s.wait(2)
    check("joining a group: a request and your best", #s.sent == 2 and s.sent[1].msg == "2 R " .. s.guid
        and s.sent[1].channel == "PARTY" and s.sent[2].channel == "PARTY")
    s.event("GROUP_ROSTER_UPDATE")
    s.wait(2)
    check("a roster change in the same group sends nothing", #s.sent == 2)
    s.receive("2 R @", "PARTY", "New Member")
    s.receive("2 R @", "PARTY", "Other Member")
    check("an answer waits a moment, once", #s.sent == 2 and #s.timers == 1)
    s.wait(3)
    check("the answer goes to the group", #s.sent == 3 and s.sent[3].channel == "PARTY"
        and s.sent[3].msg == "2 B " .. s.guid .. " gridshot 4210 - MAGE 20000")
    s.receive("2 R @", "PARTY", "Third Member")
    s.wait(3)
    check("answers are rate limited", #s.sent == 3)
    s.wait(10)
    s.receive("2 R @", "PARTY", "Third Member")
    s.wait(3)
    check("and answered again later", #s.sent == 4)
    s.group = nil
    s.event("GROUP_ROSTER_UPDATE")
    s.wait(2)
    s.group = "INSTANCE_CHAT"
    s.event("GROUP_ROSTER_UPDATE")
    s.wait(2)
    check("an instance group uses INSTANCE_CHAT", s.sent[#s.sent].channel == "INSTANCE_CHAT")
    local n = #s.sent
    s.ns.AimBoard.Record("gridshot")
    check("a new best goes to the group", #s.sent == n + 1 and s.sent[#s.sent].channel == "INSTANCE_CHAT")
end

-- Ranks, the results card's line, the leaderboard view, Clear Leaderboard and the card's rows.
do
    local s = fixture({ faction = "Alliance", settings = { aimTrainer = true, aimMode = "gridshot" } })
    s.account.aimBest = { gridshot = 4210 }
    s.account.aimBestAccuracy = { gridshot = 87 }
    s.account.aimBoard = { gridshot = {
        [G("A")] = { score = 5000, acc = 90, class = "WARRIOR", day = 20000, name = "A", guild = true },
        [G("B")] = { score = 4210, class = "MAGE", day = 20000, name = "B", guild = false },
        [G("C")] = { score = 3000, acc = 70, class = "ROGUE", day = 20000, name = "C", guild = true },
        [s.guid] = { score = 1, class = "MAGE", day = 20000, name = "Die Man", guild = true },
        ["Old Name"] = { score = 9000, class = "MAGE", day = 20000, name = "Old Name", guild = true },
        [G("Broken")] = "not a table",
    } }
    local board = s.ns.AimBoard
    local rank, n = board.Rank("gridshot")
    check("rank: a tie shares its rank, yourself counted once, name keys ignored", rank == 2 and n == 4)
    rank, n = board.Rank("gridshot", true)
    check("rank among the guild", rank == 2 and n == 3)
    check("no best, no rank", board.Rank("reflex") == nil and board.RankLine("reflex") == nil)

    s.ns.ToggleAimTrainer()
    local p = s.panel()
    s.clickArea()
    s.tick(31)
    check("results: your rank", p.card.rank.text == "Rank #2 of 4")
    s.account.aimBest.gridshot = 100
    p.card.again._onClick()
    local targets = s.targets()
    for i = 1, 3 do s.hit(targets[i]) end
    s.tick(31)
    check("results: a new personal best and its rank", s.account.aimBest.gridshot == 630
        and p.card.rank.text == "New personal best, rank #4 of 4")

    p.card.board._onClick()
    local v = p.board
    check("the results card opens the leaderboard", v.shown and not p.card.shown)
    check("its title names the mode under the kicker", v.kicker.text == "LEADERBOARD" and v.title.text == "Gridshot")
    check("the header's text is clipped beside the filters", v.title.w > 0 and v.count.w == v.title.w
        and v.kicker.w == v.title.w and v.title.w + v.filters.w < v.w - 24)
    check("its count", v.count.fmt == "%d players%s" and v.count.a1 == 4)
    local rows = v.rows
    check("rows by score", rows[1].name.text == "A" and rows[2].name.text == "B" and rows[3].name.text == "C"
        and rows[4].name.text == "Die Man" and not rows[5].shown)
    check("your row highlighted", rows[4].mark.shown and not rows[1].mark.shown and not v.you.shown)
    v.back._onClick()
    check("Back returns to the results card", not v.shown and p.card.shown)

    s.account.aimBest.gridshot = 4210
    p.boardButton.scripts.OnClick(p.boardButton)
    check("the header button opens it too", v.shown)
    check("ties: better accuracy first, sharing the rank", rows[2].name.text == "Die Man" and rows[2].rank.a1 == 2
        and rows[3].name.text == "B" and rows[3].rank.a1 == 2 and rows[4].rank.a1 == 4)
    v.filters.onPick("guild")
    check("Guild: only guild entries and you", v.count.a1 == 3 and rows[1].name.text == "A"
        and rows[2].name.text == "Die Man" and rows[3].name.text == "C" and not rows[4].shown)
    for i = 1, 12 do
        s.account.aimBoard.gridshot[G("P" .. i)] = { score = 6000 + i, class = "MAGE", day = 20000, name = "P" .. i }
    end
    v.filters.onPick("all")
    check("below the top 10: rows full, none of them yours", rows[10].shown and not rows[10].mark.shown
        and rows[1].name.text == "P12")
    check("below the top 10: your row under them, with its rank", v.you.shown and v.you.mark.shown
        and v.you.rank.a1 == 14 and v.count.a1 == 16)
    s.S.Set("aimMode", "reflex")
    check("switching mode keeps it open on the new mode", v.shown and v.title.text == "Reflex" and v.empty.shown)
    s.S.Set("aimMode", "gridshot")
    p.boardButton.scripts.OnClick(p.boardButton)
    check("the header button closes it again", not v.shown and s.area().hint.shown)
    p.boardButton.scripts.OnClick(p.boardButton)
    s.clickArea()
    p.boardButton.scripts.OnClick(p.boardButton)
    check("a round hides the leaderboard and its button", not v.shown and not p.boardButton.shown)
    s.tick(31)
    p.card.board._onClick()

    s.ns.Apply()
    local list = s.account.aimBoard.gridshot
    check("switching sharing on clears name keys and broken entries", list["Old Name"] == nil
        and list[G("Broken")] == nil and list[G("A")] ~= nil)
    p.boardButton.scripts.OnClick(p.boardButton)

    local card = s.card()
    local keys = {}
    for _, row in ipairs(card.rows) do
        if row.key then keys[row.key] = true end
        if row.label == "Clear Leaderboard" then row.button() end
    end
    check("Clear Leaderboard forgets others' scores", s.account.aimBoard == nil)
    check("and keeps your records", s.account.aimBest.gridshot == 4210)
    check("the open leaderboard redraws", v.count.a1 == 1 and v.you.shown == false and rows[1].name.text == "Die Man")
    check("Share My Scores is on the card", keys.aimShare)
    check("no settings that change the game", not (keys.aimDuration or keys.aimSize or keys.aimTargetSize
        or keys.aimLifetime))
    check("the summary has no round length", card.summary(s.S) == "Gridshot, best 4210")
end

-- No garbage per message received. The parsed fields are strings the test keeps alive, as a
-- game session would after the first message, so only tables or closures would show. One whole round,
-- the clock moved on as every measured round moves it, runs after the collector stops: the collect can
-- shrink the interpreter's stack, and a round with a new rate window reaches deeper than one without,
-- so a lighter warm-up let the stack regrow inside the measure on some builds (32-bit Windows Lua).
do
    local s = fixture({ faction = "Alliance", settings = { aimTrainer = true } })
    s.account.aimBest = { hexakill = 100 }
    s.ns.Apply()
    local keep, senders, messages = { "50", "20000", "WARRIOR", "gridshot" }, {}, {}
    for i = 1, 10 do
        senders[i] = "Sender-" .. i
        keep[#keep + 1] = tostring(1000 + i)
        keep[#keep + 1] = G(senders[i])
        messages[i] = msg("gridshot", 1000 + i, 50, nil, nil, G(senders[i]))
    end
    local f = s.comms()
    local handler = f.scripts.OnEvent
    local function Round()
        s.now = s.now + 61
        for i = 1, 10 do handler(f, "CHAT_MSG_ADDON", "NaowhAim", messages[i], "GUILD", senders[i]) end
        for _ = 1, 20 do handler(f, "CHAT_MSG_ADDON", "NaowhAim", messages[1], "GUILD", senders[1]) end
    end
    for i = 1, 10 do handler(f, "CHAT_MSG_ADDON", "NaowhAim", messages[i], "GUILD", senders[i]) end
    collectgarbage("collect")
    collectgarbage("stop")
    Round()
    local before = collectgarbage("count")
    for _ = 1, 50 do Round() end
    local grown = collectgarbage("count") - before
    collectgarbage("restart")
    check(("no garbage per message received (%.3f KB)"):format(grown), grown < 0.05 and #keep == 24)
end

do
    local f = assert(io.open("Core/Settings.lua", "rb"))
    local qol = f:read("*a")
    f:close()
    check("Hexakill is the default mode", qol:find('aimMode = "hexakill"', 1, true) ~= nil)
    local features = assert(io.open("Core/Features.lua", "rb"))
    local switches = features:read("*a")
    features:close()
    check("the Aim Trainer is on by default", qol:find("aimTrainer = F.aimTrainer,", 1, true) ~= nil
        and switches:find("aimTrainer = true,", 1, true) ~= nil)
    check("no flight toggle of its own", qol:find("aimAutoFlight", 1, true) == nil)
end

print(checks .. " aim trainer checks passed")

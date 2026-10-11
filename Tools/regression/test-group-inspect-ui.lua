-- Run with Lua 5.1 from the repository root: Group Inspect's window, party cards, raid rows and
-- settings preview, loaded from the files Shared.xml and GroupInspect.xml load, against stubs and
-- a stubbed ns.GroupInspect that hands out records shaped as the module's contract says. Checks
-- that it builds and listens to nothing while off; opening it turns it on and starts the scan
-- (GI.Open), closing it stops it; solo, a party of five and of three, a raid of forty on pooled
-- rows (no frames made on a redraw); the view switch, every sort and filter; a member's change
-- repainting only their card or row (sorting again only when their place changes); the progress
-- line; the refresh buttons; the gear tooltip; the settings card and its preview (GI.Preview);
-- and that a repaint makes no garbage.
local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end
local Measure = dofile("Tools/regression/measure.lua")(check)

-------------------------------------------------------------------------------
--  Stubs: a frame keeps its scripts, hooks, size, text, alpha and shown state, and runs its
--  OnShow and OnHide (script, then hook) when that changes; every other method is one shared
--  do-nothing function, so the stubs make no garbage of their own.
-------------------------------------------------------------------------------
local NOTHING = function() end
local Frame
local made = 0
local function Run(f, script)
    local fn = f.scripts[script]
    if fn then fn(f) end
    fn = f.hooks[script]
    if fn then fn(f) end
end
local METHODS = {
    SetScript = function(f, script, fn) f.scripts[script] = fn end,
    GetScript = function(f, script) return f.scripts[script] end,
    HookScript = function(f, script, fn) f.hooks[script] = fn end,
    RegisterEvent = function(f, event) f.events[event] = true end,
    UnregisterAllEvents = function(f) for event in pairs(f.events) do f.events[event] = nil end end,
    GetParent = function(f) return rawget(f, "parent") end,
    IsForbidden = function() return false end,
    SetWidth = function(f, w) f.w = w end,
    SetHeight = function(f, h) f.h = h end,
    SetSize = function(f, w, h) f.w, f.h = w, h end,
    GetWidth = function(f) return rawget(f, "w") or 600 end,
    GetHeight = function(f) return rawget(f, "h") or 24 end,
    SetText = function(f, text) f.text = text end,
    GetText = function(f) return rawget(f, "text") or "" end,
    SetTextColor = function(f, r, g, b) f.r, f.g, f.b = r, g, b end,
    GetStringWidth = function() return 40 end,
    GetUnboundedStringWidth = function(f) return #(rawget(f, "text") or "") * (rawget(f, "fitSize") or 15) * 0.6 end,
    GetStringHeight = function() return 12 end,
    SetTexture = function(f, texture) f.texture = texture end,
    SetAtlas = function(f, atlas) f.atlas = atlas end,
    SetAlpha = function(f, alpha) f.alpha = alpha end,
    SetScale = function(f, scale) f.scale = scale end,
    SetColorTexture = function(f, r) f.red = r end,
    Show = function(f)
        local was = rawget(f, "shown") ~= false
        f.shown = true
        if not was then Run(f, "OnShow") end
    end,
    Hide = function(f)
        local was = rawget(f, "shown") ~= false
        f.shown = false
        if was then Run(f, "OnHide") end
    end,
    SetShown = function(f, shown)
        if shown then f:Show() else f:Hide() end
    end,
    IsShown = function(f) return rawget(f, "shown") ~= false end,
    IsVisible = function(f) return rawget(f, "shown") ~= false end,
    IsMouseOver = function() return false end,
    GetEffectiveScale = function() return 1 end,
    GetFrameLevel = function() return 1 end,
    CreateTexture = function(f) return Frame(f) end,
    CreateFontString = function(f) return Frame(f) end,
}
local META = { __index = function(_, key)
    if METHODS[key] then return METHODS[key] end
    if type(key) == "string" and key:find("^%u") then return NOTHING end
end }
function Frame(parent)
    made = made + 1
    return setmetatable({ scripts = {}, hooks = {}, events = {}, parent = parent }, META)
end

local WHITE = { r = 1, g = 1, b = 1 }
local timers, printed = {}, {}
local function Flush()
    local n = #timers
    for i = 1, n do timers[i]() end
    for i = n, 1, -1 do table.remove(timers, i) end
end

local QOL = { enabled = true, groupInspect = false, groupInspectShare = true, groupInspectSort = "score",
    groupInspectView = "gear", groupInspectAlpha = 1, naowhScoreCompare = "max", badgeChat = true }
local values, listeners = {}, {}
local S = {
    Get = function(key)
        local v = values[key]
        if v == nil then return QOL[key] end
        return v
    end,
    Set = function(key, value)
        values[key] = value
        for i = 1, #listeners do listeners[i](key, value) end
    end,
    OnChange = function(fn) listeners[#listeners + 1] = fn end,
    Default = function(key) return QOL[key] end,
}

-------------------------------------------------------------------------------
--  The records, as the contract shapes them, made once and reused as Records.lua's are
-------------------------------------------------------------------------------
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local ROLES = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }
local SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }
local SPENT = { 21, 9, 0 }
local function Record(i, prefix)
    local gear = {}
    for _, slot in ipairs(SLOTS) do
        local id = 1000 + slot
        local enchanted
        if slot == 5 then enchanted = i % 2 ~= 0 end
        gear[slot] = { id = id, link = "item:" .. id .. ":0", quality = slot % 2 == 0 and 4 or 3, ilvl = 20 + slot,
            enchanted = enchanted,
            bis = slot == 1 and i % 4 == 0 or nil }
    end
    local nf = i % 3 == 0
    return {
        guid = ("%s-%04d"):format(prefix, i), unit = i == 1 and "player" or "raid" .. i,
        name = ("%s %02d"):format(prefix == "Player" and "Member" or "Sample", i), classFile = CLASSES[(i - 1) % 9 + 1],
        level = 25, role = ROLES[(i - 1) % 5 + 1], online = true, inRange = true,
        state = i == 1 and "self" or "ready", hasNF = nf, nfVersion = nf and "0.5.25" or nil,
        score = 10 + (i * 7) % 30 + (i % 10) / 10, scoreShared = nf, ilvl = 20 + i % 9, gear = gear,
        talents = { spent = SPENT, tree = "Marksmanship", role = "Damage" },
        stats = { STR = 0, AGI = 84 + i, STA = 53, INT = 0, SPI = 0, AP = 184, SP = 0, CRIT = 12.3, HIT = 3.0, ARMOR = 541 },
        statsShared = nf, updated = 100,
    }
end
local RECORDS, SAMPLES = {}, {}
for i = 1, 40 do RECORDS[i] = Record(i, "Player") end
RECORDS[2].gear[17] = nil
for i = 1, 25 do SAMPLES[i] = Record(i, "Preview") end
local SAMPLE_PARTY = { SAMPLES[1], SAMPLES[2], SAMPLES[3], SAMPLES[4], SAMPLES[5] }

local GI = { opened = 0, closed = 0, refreshed = {}, refreshedAll = 0, fns = {}, roster = {}, mode = "solo",
    previewing = false, previewMode = "party" }
local function Roster()
    if GI.previewing then return GI.previewMode == "raid" and SAMPLES or SAMPLE_PARTY end
    return GI.roster
end
function GI.On() return S.Get("groupInspect") == true end
function GI.Open() GI.opened = GI.opened + 1; GI.open = true end
function GI.Close() GI.closed = GI.closed + 1; GI.open = false end
function GI.IsOpen() return GI.open == true end
function GI.Mode()
    if GI.previewing then return GI.previewMode end
    return GI.mode
end
function GI.Count() return #Roster() end
function GI.Members() return Roster() end
function GI.Member(guid)
    local list = Roster()
    for i = 1, #list do
        if list[i].guid == guid then return list[i] end
    end
end
function GI.OnChange(fn) GI.fns[#GI.fns + 1] = fn end
function GI.Refresh(guid) GI.refreshed[#GI.refreshed + 1] = guid end
function GI.RefreshAll() GI.refreshedAll = GI.refreshedAll + 1 end
function GI.Preview(on) GI.previewing = on and true or false end
function GI.PreviewMode(mode) GI.previewMode = mode end
local function Fire(guid)
    for i = 1, #GI.fns do GI.fns[i](guid) end
end
local function SetRoster(n)
    for i = #GI.roster, 1, -1 do GI.roster[i] = nil end
    for i = 1, n do GI.roster[i] = RECORDS[i] end
    GI.mode = n <= 1 and "solo" or n <= 5 and "party" or "raid"
    Fire(nil)
end

-------------------------------------------------------------------------------
--  The rest of the addon these files use
-------------------------------------------------------------------------------
local tooltip = Frame()
tooltip.lines = {}
tooltip.SetOwner = function(self, owner) self.owner = owner; self.link = nil end
tooltip.GetOwner = function() return nil end
tooltip.SetHyperlink = function(self, link) self.link = link end
tooltip.SetText = function(self, text) self.lines[1] = text; for i = #self.lines, 2, -1 do self.lines[i] = nil end end
tooltip.AddLine = function(self, text) self.lines[#self.lines + 1] = text end
tooltip.IsForbidden = function(self) return self.forbidden == true end

local MANAGER = { IsAnyMenuOpen = function() return false end }
local menus = { modified = {} }
local ns
ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"),
    THEME = setmetatable({}, { __index = function() return WHITE end }),
    QoLSettings = S,
    GroupInspect = GI,
    Color = function(_, text) return tostring(text) end,
    Font = function(parent) return Frame(parent) end,
    Solid = function(parent) return Frame(parent) end,
    Hairline = function(region) return region end,
    PixelInset = function(region) return region end,
    AllowOffscreen = NOTHING,
    Border = function(parent)
        local edge = Frame(parent)
        edge.SetColor = function(self, r, g, b) self.r, self.g, self.b = r, g, b end
        edge._frame = edge
        return edge
    end,
    Button = function(parent, text, _, _, onClick)
        local button = Frame(parent)
        button.label, button.onClick = text, onClick
        return button
    end,
    AccentBorder = function(frame) return frame end,
    SetButtonText = NOTHING,
    UIFontPath = function() return "font" end,
    UIScale = function() return 1 end,
    AccountSettings = function() return {} end,
    Print = function(text) printed[#printed + 1] = text end,
    PlainText = function(text) return type(text) == "string" and text or nil end,
    FEATURE_BADGES = 1, BADGES_LIVE = 1,
    BadgeOf = function(guid)
        if guid == "Player-0002" then return ns.DEVELOPER end
    end,
    DEVELOPER = { title = "Developer", chat = "BadgeDeveloperChat", tooltipLine = "Naowh Forever Developer",
        about = "Builds Naowh Forever." },
    OpenOptionsWindow = function(page) ns.openedPage = page end,
    OpenFromOptions = function(open) open() end,
    Apply = NOTHING,
    UI = {
        SlimScroll = function(parent) return Frame(parent) end,
        CloseOnEscape = NOTHING,
        CONTENT_PAD = 20,
        Keep = function(parent, key, make)
            local kept = rawget(parent, key)
            if not kept then kept = make(parent); parent[key] = kept end
            return kept
        end,
        BuildSliderCore = function(parent)
            local slider = Frame(parent)
            slider.rail, slider.fill, slider.thumb = Frame(slider), Frame(slider), Frame(slider)
            slider.valueBox, slider.valueFill = Frame(parent), Frame(parent)
            slider.valueBorder = { _frame = Frame(parent) }
            slider._refreshValue = NOTHING
            return slider, slider.valueBox
        end,
    },
    NaowhScore = {
        Colored = function(score) return "|cff1eff00" .. score .. "|r" end,
        Tooltip = function() return "score line" end,
    },
    BiS = { View = { EnchantBadge = function(parent) return Frame(parent) end } },
    CharacterPanel = {
        BADGE_H = 68,
        ScoreCard = function(parent, width)
            local score = Frame(parent)
            score.barW = width
            return score
        end,
        PaintScoreCard = function(score, value) score.painted = value end,
        ScoreCardWaiting = function(score) score.painted = false end,
        SizeScoreCard = function(score, width) score.barW = width end,
    },
}

local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function(_, _, parent) return Frame(parent) end,
    Mixin = function(target, ...)
        for i = 1, select("#", ...) do
            for k, v in pairs((select(i, ...))) do target[k] = v end
        end
        return target
    end,
    hooksecurefunc = function(t, name, fn)
        local original = t[name]
        t[name] = function(...) original(...); fn(...) end
    end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    issecretvalue = function() return false end,
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    C_Item = {
        GetItemIconByID = function(id) return 130000 + id end,
        GetItemQualityByID = function() return 4 end,
        GetItemNameByID = function(id) return "Item " .. id end,
        GetItemInfoInstant = NOTHING,
        GetItemCount = function() return 0 end,
        IsItemDataCachedByID = function() return true end,
    },
    ITEM_QUALITY_COLORS = { [3] = { r = 0, g = 0.44, b = 0.87 }, [4] = { r = 0.64, g = 0.21, b = 0.93 } },
    RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } },
    CLASS_ICON_TCOORDS = setmetatable({}, { __index = function(t, class)
        t[class] = { 0, 0.25, 0, 0.25 }
        return t[class]
    end }),
    GameTooltip = tooltip,
    GameTooltip_Hide = NOTHING,
    Menu = { GetManager = function() return MANAGER end,
        ModifyMenu = function(tag, fn)
            local handle = { tag = tag, fn = fn }
            handle.Unregister = function() handle.gone = true end
            menus.modified[#menus.modified + 1] = handle
            return handle
        end },
    IsInGroup = function() return GI.mode ~= "solo" end,
    IsInRaid = function() return GI.mode == "raid" end,
    GetNumGroupMembers = function() return #GI.roster end,
    MenuUtil = { CreateContextMenu = function(owner, fn) menus[#menus + 1] = { owner = owner, fn = fn } end },
    InCombatLockdown = function() return false end,
    IsMouseButtonDown = function() return false end,
    CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, SetRGBA = NOTHING } end,
    UIParent = Frame(),
    C_CurrencyInfo = { GetCoinTextureString = function(copper) return tostring(copper) end },
    C_PaperDollInfo = { GetInventorySlotInfoForInvSlot = function(slot) return slot, "empty:" .. slot, false end },
}, { __index = _G })
env._G = env

-------------------------------------------------------------------------------
--  Loading: off, nothing made, nothing listened to
-------------------------------------------------------------------------------
local mine = TocFiles("^NaowhForever_GroupInspect/.*%.lua$")
local ORDER = { "/GroupInspect%.lua$", "/Constants%.lua$", "/Data/Preview%.lua$", "/Records%.lua$", "/Inspect%.lua$",
    "/PreviewGroup%.lua$", "/Stats%.lua$", "/OwnStats%.lua$", "/Message%.lua$", "/Share%.lua$", "/View/Style%.lua$",
    "/View/Texts%.lua$", "/View/Parts%.lua$", "/View/Pill%.lua$", "/View/Gear%.lua$", "/View/Card%.lua$",
    "/View/CardPaint%.lua$", "/View/Party%.lua$", "/View/RaidOrder%.lua$", "/View/RaidBar%.lua$", "/View/Row%.lua$",
    "/View/Raid%.lua$", "/View/Solo%.lua$", "/UI/Window%.lua$", "/UI/Menu%.lua$", "/UI/SettingsPage%.lua$" }
check("GroupInspect.xml loads its files in the contract's order", #mine == #ORDER and (function()
    for i, pattern in ipairs(ORDER) do
        if not mine[i]:find(pattern) then return false end
    end
    return true
end)())
local files = TocFiles("^Shared/.*%.lua$")
local before = made
Load(files, env)
local shared = made
for i = 1, #mine do
    if mine[i]:find("/Constants%.lua$") or mine[i]:find("/View/") or mine[i]:find("/UI/") then Load({ mine[i] }, env) end
end
local UI = GI.UI
check("off: nothing made at load, nothing listened to, no timer", made == shared and #GI.fns == 0 and #timers == 0
    and before <= shared)
check("the window's opener, toggle and key binding are there", type(ns.OpenGroupInspect) == "function"
    and type(ns.ToggleGroupInspect) == "function" and type(env.NaowhForever_ToggleGroupInspect) == "function")

local function Source(path)
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end
local qol = Source("Core/Settings.lua")
local switches = Source("Core/Features.lua")
check("its defaults: off, sharing on, by score, the gear view", qol:find("groupInspect = F.groupInspect,", 1, true)
    and switches:find("groupInspect = false,", 1, true) and switches:find("groupInspectShare = true,", 1, true)
    and qol:find("groupInspectShare = F.groupInspectShare,", 1, true) and qol:find('groupInspectSort = "score"', 1, true)
    and qol:find('groupInspectView = "gear"', 1, true) and qol:find("groupInspectAlpha = 1", 1, true))
check("/nf group and its key binding", Source("Core/Commands.lua"):find('cmd == "group"', 1, true)
    and Source("Bindings.xml"):find("NaowhForever_ToggleGroupInspect()", 1, true))

local Settings = ns.Shared.Settings
check("no longer a card on QoL > Character", not (Settings.pages["QoL/Character"]
    and Settings.pages["QoL/Character"].cards.groupInspect))
local page = Settings.pages["Group Inspect/Settings"]
local banner = page and page.items[1]
check("its own page opens with the banner and Open Group Inspect", banner and banner.window
    and banner.text == "Open Group Inspect")
local pageCards = page.cards
check("then Share Your Stats, the Preview, Key Binding and Window, in that order", page.items[2] == pageCards.share
    and page.items[3] == pageCards.preview and page.items[4] == pageCards.binding and page.items[5] == pageCards.window)
check("Share Your Stats is its switch", pageCards.share.switch == "groupInspectShare" and #pageCards.share.rows == 0)
local card = pageCards.preview
check("the preview: a party and a raid", card.studio.states[1].key == "party" and card.studio.states[2].key == "raid")
check("the key binding and the window's opacity", pageCards.binding.rows[1].binding == "NAOWHFOREVER_GROUPINSPECT"
    and pageCards.window.rows[1].key == "groupInspectAlpha")
check("the banner says you are not in a group", banner.headline() == "Not in a group" and banner.detail():find("preview"))
check("nothing hooks the unit menus while off", #menus.modified == 0)

local core = Source("Core/Options/Modules.lua")
local list = assert(core:match("local MODULES = (%b{})"))
local MODULES = assert(loadstring("return " .. list))()
local module
for _, mod in ipairs(MODULES) do if mod.name == "Group Inspect" then module = mod end end
check("a module addon of its own under Combat, needing BiS, switched by groupInspect", module
    and module.group == "COMBAT" and module.addon == "NaowhForever_GroupInspect" and module.needs[1] == "NaowhForever_BiS"
    and module.settings == "QoLSettings" and module.enabledKey == "groupInspect")
local toc = Source("NaowhForever_GroupInspect/NaowhForever_GroupInspect.toc")
local djToc = Source("NaowhForever_DungeonJournal/NaowhForever_DungeonJournal.toc")
check("its TOC: the journal's Interface and Version, needing NaowhForever and BiS, loading its XML",
    toc:match("## Interface:[^%c]*") == djToc:match("## Interface:[^%c]*")
    and toc:match("## Version:[^%c]*") == djToc:match("## Version:[^%c]*")
    and toc:find("## Dependencies: NaowhForever, NaowhForever_BiS", 1, true)
    and toc:find("## Group: NaowhForever", 1, true) and toc:find("GroupInspect.xml", 1, true))
check("packaged as its own addon, and no longer loaded by BiS", Source(".pkgmeta"):find(
    "NaowhForever/NaowhForever_GroupInspect: NaowhForever_GroupInspect", 1, true)
    and not Source("NaowhForever_BiS/NaowhForever_BiS.toc"):find("GroupInspect", 1, true))
check("its window from /nfgroup, the Top Bar and its minimap button", module.command == "group"
    and module.short == "Group" and module.open == "ToggleGroupInspect" and module.icon ~= nil
    and module.navIcon == "group" and module.tabs[1].name == "Settings")
do
    local chunk = assert(Source("Core/Options/Launchers.lua"):match("(local LOGO = .*)"))
    local objects, opened, event = {}, nil, nil
    local frame = { SetScript = function(_, _, fn) event = fn end, RegisterEvent = NOTHING, UnregisterEvent = NOTHING }
    local libs = {
        ["LibDataBroker-1.1"] = { NewDataObject = function(_, name, data) objects[name] = data; return data end },
        ["LibDBIcon-1.0"] = { Register = NOTHING },
    }
    local account = {}
    local launchEnv = setmetatable({ ns = { MEDIA = dofile("Tools/regression/core_media.lua"), AccountSettings = function() return account end, L = function(t) return t end,
            SaveModuleDefaults = NOTHING, ThemeTint = function(_, literal) return literal end, ToggleOptionsWindow = NOTHING },
        CreateFrame = function() return frame end, LibStub = function(name) return libs[name] end,
        MODULES = MODULES, MinimapButtonOn = function() return false end,
        OpenModule = function(mod) opened = mod end, Loaded = function() return true end }, { __index = _G })
    local launcher = assert(loadstring(chunk, "launcher"))
    setfenv(launcher, launchEnv)
    launcher()
    event(frame)
    local object = objects.NaowhForeverGroup
    check("a launcher for the Top Bar and the minimap, hidden on the minimap until switched on", object
        and object.type == "launcher" and object.icon == module.icon and account.moduleButtons["Group Inspect"].hide)
    object.OnClick()
    check("which opens Group Inspect", opened == module)
end

-------------------------------------------------------------------------------
--  Opening: turned on, the scan started, solo's note
-------------------------------------------------------------------------------
env.NaowhForever_ToggleGroupInspect()
local window = UI.Window()
check("turning it on hooks the party and raid unit menus, once", #menus.modified == 3
    and menus.modified[1].tag == "MENU_UNIT_PARTY" and menus.modified[2].tag == "MENU_UNIT_RAID_PLAYER"
    and menus.modified[3].tag == "MENU_UNIT_RAID")
check("opening turns it on and says so", S.Get("groupInspect") == true and printed[1]:find("turned on", 1, true))
check("opening starts the scan once (GI.Open), and listens to changes once", GI.opened == 1 and #GI.fns == 1)
check("solo: the note, no cards, no rows", window.solo:IsShown() and not window.scroll:IsShown()
    and window.summary.text == "")

-------------------------------------------------------------------------------
--  A party of five, then three
-------------------------------------------------------------------------------
SetRoster(5)
local cards = {}
local partyBoard = window.board
check("a party: the board shown, the raid hidden", partyBoard:IsShown()
    and not window.scroll:IsShown() and not window.solo:IsShown() and window.summary.text == "Party of 5")
for i = 1, 5 do cards[i] = partyBoard.cards[i] end
local c2 = cards[2]
check("a card each, by roster order", cards[1].name.text == "Member 01" and cards[5].name.text == "Member 05"
    and cards[5]:IsShown())
check("the name, level and class, and the class's band", c2.name.text == "Member 02"
    and c2.sub.text == "Level 25 Paladin" and c2.class.texture.shown ~= false)
check("the NF pill only on who runs it", cards[3].nf:IsShown() and not c2.nf:IsShown()
    and cards[3].nf.text.text == "NF")
check("a supporter's own badge after their name, apart from the NF pill", c2.badge:IsShown()
    and c2.badge.icon.texture == "BadgeDeveloperChat" and not cards[3].badge:IsShown())
c2.badge.scripts.OnEnter(c2.badge)
check("the badge says what it is on hover", tooltip.lines[1] == "Naowh Forever Developer"
    and tooltip.lines[2] == "Builds Naowh Forever.")
check("the role icon, the game's group finder ones", cards[1].role.atlas == "UI-LFG-RoleIcon-Tank-Micro-GroupFinder"
    and c2.role.atlas == "UI-LFG-RoleIcon-Healer-Micro-GroupFinder")
check("five cards: the narrow layout", c2.w == UI.Style.PARTY_W and c2.slots[1].w == UI.Style.SLOT
    and c2.score.barW == UI.Style.PARTY_W - 2 * UI.Style.PARTY_PAD
    and c2.score.painted == RECORDS[2].score and c2.ilvl.text == tostring(RECORDS[2].ilvl))
local function Has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
check("the gear: 17 slots, the item's icon, its level and the missing enchant",
    #c2.slots == 17 and c2.slots[1].texture.texture == 131001 and c2.slots[5].bare:IsShown()
    and not cards[3].slots[5].bare:IsShown() and Has(c2.enchants.text, UI.Style.WARN_CODE .. "0/1|r")
    and Has(cards[3].enchants.text, "1/1|r") and Has(cards[3].enchants.text, "enchanted"))
check("an empty slot shows the game's empty slot art, dimmed", c2.slots[16].texture.texture == "empty:17"
    and c2.slots[16].texture.alpha == UI.Style.EMPTY_ALPHA and c2.slots[1].texture.alpha == 1)
check("their BiS star on the slot", cards[4].slots[1].marks.rank.text ~= "" and c2.slots[1].marks.rank.text == "")
local function CellsText(cells)
    local out = ""
    for i = 1, #cells do
        if cells[i].shown ~= false and cells[i].text then out = cells[i].text .. out end
    end
    return out
end
check("the talents: tree, points, role", c2.tree.text == "Marksmanship" and CellsText(c2.points) == "21/9/0"
    and c2.trole.text == "Damage")
local st = c2.stats
check("the stats: only those they have, down two columns of lined-up numbers", st[1].label.text == "Agility"
    and CellsText(st[1].value) == "86" and st[3].label.text == "Atk Power" and st[4].label.text == "Crit"
    and CellsText(st[4].value) == "12.3%" and st[6].label.text == "Armor" and st[7].label.text == ""
    and CellsText(st[7].value) == "")
check("where the stats are from: theirs, from gear, or yours", c2.from.text == "From gear"
    and cards[3].from.text == "From their Naowh Forever" and cards[1].from.text == "Yours")
check("the progress line and the footer", window.progress.text == "Everyone inspected"
    and window.note.text.text == "1 of 5 run Naowh Forever")

SetRoster(3)
check("a party of three: two cards hidden, the three centred", not cards[4]:IsShown() and not cards[5]:IsShown()
    and cards[3]:IsShown() and window.summary.text == "Party of 3")
check("four or fewer: wider cards, bigger slots, the full stat names", c2.w == UI.Style.PARTY_WIDE_W
    and c2.slots[1].w == UI.Style.WIDE_SLOT and c2.score.barW == UI.Style.PARTY_WIDE_W - 2 * UI.Style.PARTY_PAD
    and c2.stats[3].label.text == "Attack Power" and partyBoard.h == UI.PARTY_LAYOUTS.wide.h)
check("the widest party fits the window", UI.PARTY_H <= UI.CONTENT_H)
RECORDS[3].name = "Serinnar Ravenshadowmoon"
Fire(RECORDS[3].guid)
check("a long name: smaller, down to the minimum", cards[3].name.fitSize == UI.Style.NAME_MIN
    and cards[3].name.text == "Serinnar Ravenshadowmoon")
check("a short one stays full size", c2.name.fitSize == UI.Style.NAME_SIZE)
cards[3].nameHit.scripts.OnEnter(cards[3].nameHit)
check("and the whole name on hover", tooltip.lines[1] == "Serinnar Ravenshadowmoon"
    and tooltip.lines[2] == "Level 25 Hunter")
RECORDS[3].name = "Member 03"
local role = RECORDS[3].role
RECORDS[3].role = nil
Fire(RECORDS[3].guid)
check("no role known: no role icon", not cards[3].role:IsShown())
RECORDS[3].role = role

-------------------------------------------------------------------------------
--  A member's change repaints only their card
-------------------------------------------------------------------------------
SetRoster(5)
local function CountPaints(fn)
    local real = ns.CharacterPanel.PaintScoreCard
    local n = 0
    ns.CharacterPanel.PaintScoreCard = function(...) n = n + 1; return real(...) end
    fn()
    ns.CharacterPanel.PaintScoreCard = real
    return n
end
RECORDS[2].score = 31.4
check("a member's change repaints only their card", CountPaints(function() Fire(RECORDS[2].guid) end) == 1
    and c2.score.painted == 31.4)
RECORDS[2].state, RECORDS[3].state = "out_of_range", "queued"
Fire(RECORDS[2].guid)
check("out of range: faded and said, the progress line counts it", c2.alpha == UI.Style.AWAY_ALPHA
    and c2.state.text == "Out of range" and window.progress.text == "Inspected 3 of 5, 1 out of range")
RECORDS[2].state, RECORDS[3].state = "ready", "ready"
Fire(nil)
c2.refresh.scripts.OnClick(c2.refresh)
check("a card's refresh asks GI.Refresh for that member", GI.refreshed[1] == RECORDS[2].guid)

-------------------------------------------------------------------------------
--  The gear tooltip: the game's own, from the record, with ours under it
-------------------------------------------------------------------------------
local slot = c2.slots[5]
slot.scripts.OnEnter(slot)
check("hovering a slot shows the game's item tooltip and the missing enchant", tooltip.link == "item:1005:0"
    and tooltip.lines[#tooltip.lines] == "No enchant")
tooltip.forbidden, tooltip.link = true, nil
slot.scripts.OnEnter(slot)
check("a forbidden tooltip is left alone", tooltip.link == nil)
tooltip.forbidden = false
cards[3].nf.scripts.OnEnter(cards[3].nf)
check("Naowh Forever's mark says its version", tooltip.lines[1] == "Runs Naowh Forever"
    and tooltip.lines[2] == "Version 0.5.25")

-------------------------------------------------------------------------------
--  A raid of forty: pooled rows
-------------------------------------------------------------------------------
SetRoster(40)
local view = window.list.view
local function Rows()
    return view.pools.member
end
check("a raid: rows shown, the cards hidden", window.scroll:IsShown() and not partyBoard:IsShown()
    and window.summary.text == "Raid of 40")
check("the raid's view found", view ~= nil and Rows().used == 40)
local first = Rows()[1]
check("sorted by score, highest first", Rows()[1].sortValue >= Rows()[2].sortValue
    and Rows()[39].sortValue >= Rows()[40].sortValue)
check("a row: class band, name, score, item level, gear strip", first.name.text ~= nil and first.score.text ~= nil
    and first.gear:IsShown() and #first.slots == 17 and not first.tree:IsShown() and not first.stats:IsShown())
local function RowFor(guid)
    local rows = Rows()
    for i = 1, rows.used do if rows[i].guid == guid then return rows[i] end end
end
check("a raid row: the NF pill and the supporter badge, each its own", RowFor(RECORDS[3].guid).nf:IsShown()
    and not RowFor(RECORDS[3].guid).badge:IsShown() and RowFor(RECORDS[2].guid).badge:IsShown()
    and not RowFor(RECORDS[2].guid).nf:IsShown())
local framesAfter = made
Fire(nil)
view:Redraw()
check("a redraw makes no frames: the rows are reused", made == framesAfter and Rows().used == 40)

S.Set("groupInspectView", "talents")
check("the talents view", Rows()[1].tree:IsShown() and Rows()[1].points.text == "21/9/0"
    and not Rows()[1].gear:IsShown() and view.header.title.text == "TALENTS")
S.Set("groupInspectView", "stats")
check("the stats view: their key stats inline, the header explains the shades", Rows()[1].stats:IsShown()
    and Rows()[1].stats.count == 6 and view.header.tip:IsShown())
S.Set("groupInspectView", "gear")
framesAfter = made
S.Set("groupInspectView", "talents")
S.Set("groupInspectView", "stats")
S.Set("groupInspectView", "gear")
check("once each view has been seen, switching makes no frames", made == framesAfter)

local function Sorted(less)
    local rows = Rows()
    for i = 1, rows.used - 1 do
        if less(rows[i + 1], rows[i]) then return false end
    end
    return true
end
local function Rec(row) return GI.Member(row.guid) end
S.Set("groupInspectSort", "name")
check("sorted by name", Rec(Rows()[1]).name == "Member 01" and Sorted(function(a, b) return Rec(a).name < Rec(b).name end))
S.Set("groupInspectSort", "class")
check("sorted by class", Sorted(function(a, b) return Rec(a).classFile < Rec(b).classFile end))
S.Set("groupInspectSort", "role")
check("sorted by role: tanks, healers, then damage", Rec(Rows()[1]).role == "TANK" and Rec(Rows()[40]).role == "DAMAGER")
S.Set("groupInspectSort", "ilvl")
check("sorted by item level", Sorted(function(a, b) return Rec(a).ilvl > Rec(b).ilvl end))
S.Set("groupInspectSort", "score")

UI.ToggleFilter({ group = "class", value = "MAGE" })
check("filtered to mages", Rows().used == 4 and Rec(Rows()[1]).classFile == "MAGE")
UI.ToggleFilter({ group = "role", value = "TANK" })
check("and tanks among them", Rows().used == 1)
UI.ClearFilters()
UI.ToggleFilter({ group = "armor", value = "Plate" })
check("plate wearers", Rows().used == 10)
UI.ClearFilters()
UI.ToggleFilter({ group = "nf" })
check("who runs Naowh Forever", Rows().used == 13)
UI.ClearFilters()
UI.ToggleFilter({ group = "bare" })
check("who is missing an enchant", Rows().used == 20)
UI.ToggleFilter({ group = "class", value = "DRUID" })
UI.ToggleFilter({ group = "class", value = "DRUID" })
UI.ToggleFilter({ group = "class", value = "DRUID" })
check("filters add up: druids missing an enchant", Rows().used == 2)
UI.ClearFilters()
check("filters cleared: everyone", Rows().used == 40 and made == framesAfter)

-------------------------------------------------------------------------------
--  A member's change in the raid: their row only, or a sort when their place changes
-------------------------------------------------------------------------------
local function RowOf(guid)
    local rows = Rows()
    for i = 1, rows.used do if rows[i].guid == guid then return rows[i] end end
end
Flush()
local target = RECORDS[17]
local row = RowOf(target.guid)
local scoreTexts = 0
local realScore = UI.ScoreText
UI.ScoreText = function(...) scoreTexts = scoreTexts + 1; return realScore(...) end
target.ilvl = 28
Fire(target.guid)
check("a change that keeps their place repaints their row only, no sort queued", scoreTexts == 1 and #timers == 0
    and row.ilvl.text == "28")
target.score = 99
Fire(target.guid)
check("a new score queues one sort", #timers == 1)
Flush()
check("and the sort puts them first", Rows()[1].guid == target.guid)
UI.ScoreText = realScore
RECORDS[5].state, RECORDS[6].state, RECORDS[7].state, RECORDS[8].state = "out_of_range", "out_of_range", "offline", "queued"
Fire(nil)
check("the raid's progress line", window.progress.text == "Inspected 36 of 40, 2 out of range, 1 offline")
check("a row's state, subtle", RowOf(RECORDS[8].guid).state.text == "Queued"
    and RowOf(RECORDS[7].guid).alpha == UI.Style.AWAY_ALPHA)
RowOf(RECORDS[9].guid).refresh.scripts.OnClick(RowOf(RECORDS[9].guid).refresh)
check("a row's refresh asks GI.Refresh for that member", GI.refreshed[#GI.refreshed] == RECORDS[9].guid)
for i = 5, 8 do RECORDS[i].state = "ready" end
Fire(nil)

-- An older Naowh Forever on a member: their NF pill in the warning color, ours in the accent.
check("versions compared part by part", UI.Older("0.5.22-beta", "0.5.24-beta") and UI.Older("0.5.9", "0.5.24")
    and not UI.Older("0.5.24-beta", "0.5.24-beta") and not UI.Older("0.5.25", "0.5.24-beta")
    and not UI.Older(nil, "0.5.24") and UI.Older("0.5", "0.5.1") and not UI.Older("0.6.0", "0.5.24"))
do
    local saved = ns.CODE_BUILD
    rawset(ns, "CODE_BUILD", "0.5.24-beta")
    local pill = UI.NFPill(Frame(), {})
    UI.PaintNFPill(pill, { hasNF = true, nfVersion = "0.5.22-beta" })
    check("an older version: the warning color", pill.color == ns.Shared.Style.WARN_RGB)
    UI.PaintNFPill(pill, { hasNF = true, nfVersion = "0.5.24-beta" })
    check("the same or newer: the accent", pill.color == ns.THEME.accent)
    rawset(ns, "CODE_BUILD", saved)
end

-------------------------------------------------------------------------------
--  Garbage: a repaint makes none
-------------------------------------------------------------------------------
print("Group Inspect, measured:")
Measure("a raid member's row repainted", 1, function() Fire(target.guid) end)
Measure("the raid of forty redrawn", 5, function() view:Redraw() end)
SetRoster(5)
Measure("a party member's card repainted", 1, function() Fire(RECORDS[2].guid) end)
Measure("the party of five repainted", 2, function() Fire(nil) end)

-------------------------------------------------------------------------------
--  Closing, turning it off
-------------------------------------------------------------------------------
window:Hide()
check("closing stops the scan (GI.Close)", GI.closed == 1 and GI.open == false)
ns.ToggleGroupInspect()
check("opening again starts it again", GI.opened == 2 and window:IsShown())
local menuRoot = { added = {} }
function menuRoot:CreateDivider() self.added[#self.added + 1] = "-" end
function menuRoot:CreateButton(text, fn) self.added[#self.added + 1] = text; self.click = fn end
window:Hide()
menus.modified[1].fn(nil, menuRoot, {})
check("in a group, the menu gets Group Inspect under a divider", menuRoot.added[1] == "-"
    and menuRoot.added[2] == "Group Inspect")
menuRoot.click()
check("which opens the window", window:IsShown())
S.Set("groupInspect", false)
check("turned off: the window closes", not window:IsShown() and GI.closed == 3)
check("and the menu hooks come off", menus.modified[1].gone and menus.modified[3].gone)
local addedBefore = #menuRoot.added
menus.modified[1].fn(nil, menuRoot, {})
check("an old menu callback adds nothing while off", #menuRoot.added == addedBefore)

-------------------------------------------------------------------------------
--  The settings preview: the sample roster, never real players
-------------------------------------------------------------------------------
local stage = Frame()
stage.w, stage.h = 640, 320
local preview = card.studio.new(stage)
preview.w, preview.h = 640, 320
card.studio.paint(preview, "party")
check("the preview asks for the sample party", GI.previewing and GI.previewMode == "party"
    and preview.board:IsShown() and preview.board.cards[1].name.text == "Sample 01")
check("scaled to fit the stage", preview.board.scale and preview.board.scale < 1)
card.studio.paint(preview, "raid")
check("and the sample raid, as rows", GI.previewMode == "raid" and preview.list.view.pools.member.used == 25
    and not preview.board:IsShown())
UI.ToggleFilter({ group = "class", value = "MAGE" })
card.studio.paint(preview, "raid")
check("the preview shows everyone, whatever the window's filters", preview.list.view.pools.member.used == 25)
UI.ClearFilters()
preview:Hide()
check("hiding the preview ends it", GI.previewing == false)
check("Open Group Inspect on the banner turns it on and opens the window", (function()
    banner.open()
    return window:IsShown() and S.Get("groupInspect") == true
end)())
check("on again: the menus hooked again", #menus.modified == 6)
check("in a party the banner counts the group and who runs Naowh Forever", banner.headline():find("Party of 5", 1, true)
    and banner.headline():find("1 runs Naowh Forever", 1, true))

print(("test-group-inspect-ui: %d checks passed"):format(checks))

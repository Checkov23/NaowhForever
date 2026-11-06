-- Run with Lua 5.1 from the repository root: the Group Finder's window and Browse rows, loaded from the files
-- Shared.xml and GroupFinder.xml load, against stubs and a stubbed ns.GroupFinder whose listings, cards and
-- search are shaped as the module's contract says. Checks that it builds and listens to nothing until opened;
-- opening turns it on; the note before a search, while searching, after a failure and in chat lockdown; the
-- rows, your own listing first then newest first, with the dungeon, its levels, the leader in their class color,
-- the role slots of a group, a solo player's roles and a raid's count; the leader's card (score, kills, quests)
-- and the wait for it; a delisted listing faded; a card's arrival redrawing on pooled rows; Search; the bar's
-- dungeon chips, text filter and sort; turning it off closing the window; and the settings page's window card.
local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

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
    GetStringHeight = function() return 12 end,
    SetTexture = function(f, texture) f.texture = texture end,
    SetAtlas = function(f, atlas) f.atlas = atlas end,
    SetAlpha = function(f, alpha) f.alpha = alpha end,
    SetScale = function(f, scale) f.scale = scale end,
    SetColorTexture = function(f, r, g, b) f.red, f.green, f.blue = r, g, b end,
    SetEnabled = function(f, on) f.enabled = on end,
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
local ACCENT = { r = 0, g = 0.57, b = 0.93 }
local MUTED = { r = 0.5, g = 0.5, b = 0.5 }
local MAGE = { r = 0.25, g = 0.78, b = 0.92 }
local timers, printed, menus = {}, {}, {}
local function Flush()
    local n = #timers
    for i = 1, n do timers[i]() end
    for i = n, 1, -1 do table.remove(timers, i) end
end

local values, listeners = { enabled = false }, {}
local S = {
    Get = function(key) return values[key] end,
    Set = function(key, value)
        values[key] = value
        for i = 1, #listeners do listeners[i](key, value) end
    end,
    OnChange = function(fn) listeners[#listeners + 1] = fn end,
    Default = function() return false end,
}

-------------------------------------------------------------------------------
--  The module's rules, as their contract shapes them
-------------------------------------------------------------------------------
local TANK, HEALER, DAMAGE = 4, 2, 1
local ACTIVITY = {
    [1] = { name = "The Deadmines", short = "DM", min = 17, max = 26, size = 5 },
    [2] = { name = "Shadowfang Keep", short = "SFK", min = 22, max = 30, size = 5 },
    [3] = { name = "Molten Core", short = "MC", min = 0, max = 0, size = 40 },
}
local function Member(name, class, level, roles, leader)
    return { name = name, class = class, level = level, roles = roles, leader = leader }
end
local ENTRIES = {
    { id = 11, leader = "Korvath", activity = 2, dungeon = "ShadowfangKeep", numMembers = 3, age = 600, delisted = false,
        mine = false, tanks = 1, healers = 0, damage = 2, nMembers = 3,
        members = { Member("Korvath", "WARRIOR", 25, TANK, true), Member("Magi", "MAGE", 24, DAMAGE),
            Member("Kilt", "MAGE", 24, DAMAGE) } },
    { id = 12, leader = "Nessa", activity = 1, dungeon = "Deadmines", numMembers = 1, age = 30, delisted = false,
        mine = false, tanks = 0, healers = 0, damage = 0, nMembers = 1,
        members = { Member("Nessa", "PRIEST", 19, HEALER + DAMAGE, true) } },
    { id = 13, leader = "Die Man", activity = 1, dungeon = "Deadmines", numMembers = 2, age = 900, delisted = false,
        mine = true, tanks = 0, healers = 1, damage = 1, nMembers = 2,
        members = { Member("Die Man", "MAGE", 20, DAMAGE, true), Member("Pal", "PALADIN", 20, HEALER) } },
    { id = 14, leader = "Raider", activity = 3, numMembers = 12, age = 120, delisted = true, mine = false,
        tanks = 2, healers = 3, damage = 7, nMembers = 5,
        members = { Member("Raider", "MAGE", 60, DAMAGE, true) } },
}
local cards = {
    Korvath = { score = 239, level = 25, dungeon = "ShadowfangKeep", hasKills = true, nKills = 3, kills = { 2, 0, 1 },
        hasQuests = true, nHave = 2,
        group = { min = 120, tanks = 0, healers = 1, damage = 1, note = "Bring food" } },
}
local applied, applies = {}, {}
local function Applicant(name, class, score, at)
    return { name = name, at = at, note = "Hi", card = { class = class, level = 25, roles = DAMAGE + HEALER, score = score,
        hasKills = true, nKills = 2, kills = { 3, 4 }, bisHave = 9, bisTotal = 14, hasQuests = true, nHave = 1 } }
end
local mine = { score = 189, level = 20, dungeon = "Deadmines", hasKills = true, nKills = 2, kills = { 0, 0 },
    hasQuests = false, nHave = 0 }
local waitingFor = { Nessa = true }

local GF = { Settings = S, PAGE = "Group Finder/Settings", fns = {}, asks = 0, runs = 0 }
function GF.On() return S.Get("enabled") == true end
function GF.Listen(what, fn)
    GF.fns[what] = GF.fns[what] or {}
    table.insert(GF.fns[what], fn)
end
function GF.Fire(what, a)
    for _, fn in ipairs(GF.fns[what] or {}) do fn(a) end
end
GF.Card = { TANK = TANK, HEALER = HEALER, DAMAGE = DAMAGE, NEED_MAX = 9, NOTE_MAX = 60, Mine = function() return mine end,
    CleanNote = function(text) return text end }
GF.Comms = { IsMe = function(name) return name == "Die Man" end, applicants = {},
    SentTo = function(name) return applied[name] end }
local Group = { tanks = 1, healers = 1, damage = 3, min = 0, note = "", listed = false, leader = true, lists = 0,
    invites = {}, declines = {} }
GF.Group = Group
function Group.Listed() return Group.listed end
function Group.CanEdit() return Group.leader end
function Group.Answering() return Group.listed and Group.leader end
function Group.Ready() return Group.activity ~= nil and Group.style ~= nil end
function Group.List()
    Group.lists = Group.lists + 1
    if not Group.Ready() then return false end
    Group.listed, Group.ours, Group.listedAt = true, true, 0
    return true
end
function Group.Delist() Group.listed, Group.ours, Group.listedAt = false, false, nil end
function Group.Info() if Group.ours and Group.listed then return Group end end
function Group.Invite(record)
    Group.invites[#Group.invites + 1] = record.name
    record.invited = true
end
function Group.Decline(record) Group.declines[#Group.declines + 1] = record.name end
GF.Listings = { entries = {}, n = 0, state = "none", searched = false }
function GF.Listings.Read()
    local L = GF.Listings
    if L.state == "locked" then return 0 end
    if L.searched and L.state ~= "failed" then
        for i, entry in ipairs(ENTRIES) do L.entries[i] = entry end
        L.n, L.state = #ENTRIES, "ready"
    end
    return L.n
end
function GF.Listings.Activity(id) return ACTIVITY[id] end
function GF.Listings.DungeonOf(id) return id == 1 and "Deadmines" or id == 2 and "ShadowfangKeep" or nil end
local function Newest(a, b)
    if a.mine ~= b.mine then return a.mine end
    return a.age < b.age
end
GF.Browse = {
    Ask = function() GF.asks = GF.asks + 1 end,
    CardOf = function(leader) return cards[leader], waitingFor[leader] == true end,
    Apply = function(leader) applies[#applies + 1] = leader end,
    Matches = function(entry, needle) return entry.leader:lower():find(needle, 1, true) ~= nil end,
    Sort = function(order, how)
        GF.sortedBy = how
        table.sort(order, Newest)
    end,
}
GF.Search = { state = "idle", pick = "level", LEVEL = "level", ALL = "all", Category = function() return 2 end }
function GF.Search.Run(pick)
    GF.runs = GF.runs + 1
    GF.Search.pick = pick or GF.Search.pick
    GF.Search.state = "searching"
    return true
end
function GF.Search.Activities(list)
    list[1], list[2], list[3] = 3, 1, 2
    return 3
end
function GF.Search.Suits(id) return id ~= 2 end

local tooltip = Frame()
tooltip.SetOwner, tooltip.SetText, tooltip.AddLine = NOTHING, NOTHING, NOTHING
local ns
ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    MEDIA = dofile("Tools/regression/core_media.lua"),
    THEME = setmetatable({ accent = ACCENT, muted = MUTED }, { __index = function() return WHITE end }),
    Journal = {
        Get = function(key)
            if key == "ShadowfangKeep" then return { wings = { { bosses = { { encounters = { 3 } } } } } } end
            if key ~= "Deadmines" then return nil end
            return { wings = { { bosses = { { encounters = { 1 } }, { encounters = { 2 } },
                { with = "Sneed", encounters = { 2 } }, {} } } } }
        end,
        Kills = { Counted = function(boss) return boss.encounters ~= nil end },
    },
    GroupFinder = GF,
    Color = function(_, text) return tostring(text) end,
    Font = function(parent) return Frame(parent) end,
    Solid = function(parent) return Frame(parent) end,
    Hairline = function(region) return region end,
    PixelInset = function(region) return region end,
    AllowOffscreen = NOTHING,
    Border = function(parent)
        local edge = Frame(parent)
        edge.SetColor = NOTHING
        edge._frame = edge
        return edge
    end,
    Button = function(parent, text, _, _, onClick)
        local button = Frame(parent)
        button.label = Frame(button)
        button.label.text = text
        button._border = { SetColor = function(self, r, g, b) self.r, self.g, self.b = r, g, b end }
        button._rest, button._onClick = WHITE, onClick
        button.Click = function(self) if self._onClick then self._onClick() end end
        return button
    end,
    AccentBorder = function(frame) return frame end,
    PrimaryButton = function(button)
        button.primary = true
        return button
    end,
    SetButtonText = function(button, text) button.label.text = text end,
    NewEditBox = function(parent) return Frame(parent) end,
    NewSearchBox = function(parent, hint, onChange)
        local box = Frame(parent)
        box.hint, box.onChange = Frame(box), onChange
        box.border = { SetColor = NOTHING }
        box.hint.text = hint
        return box
    end,
    UIFontPath = function() return "font" end,
    UIScale = function() return 1 end,
    AccountSettings = function() return {} end,
    Print = function(text) printed[#printed + 1] = text end,
    Apply = NOTHING,
    UI = {
        SlimScroll = function(parent) return Frame(parent) end,
        CloseOnEscape = NOTHING,
        CONTENT_PAD = 20,
        BuildSliderCore = function(parent, _, _, _, _, _, _, _, low, high, step, get, set)
            local track = Frame(parent)
            track.low, track.high, track.step, track._get, track._set = low, high, step, get, set
            track._refreshValue = function() track.value = get() end
            return track, Frame(parent)
        end,
    },
    NaowhScore = { Colored = function(score, level) return ("score %.1f at %d"):format(score, level) end },
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
    Menu = { GetManager = function() return { IsAnyMenuOpen = function() return false end } end },
    MenuUtil = { CreateContextMenu = function(owner, generator) menus[#menus + 1] = { owner = owner, fill = generator } end },
    IsMouseButtonDown = function() return false end,
    C_CurrencyInfo = { GetCoinTextureString = function(copper) return tostring(copper) end },
    C_PaperDollInfo = { GetInventorySlotInfoForInvSlot = function(slot) return slot, "empty:" .. slot, false end },
    RAID_CLASS_COLORS = { MAGE = MAGE },
    CLASS_ICON_TCOORDS = setmetatable({}, { __index = function(t, class)
        t[class] = { 0, 0.25, 0, 0.25 }
        return t[class]
    end }),
    GameTooltip = tooltip,
    GameTooltip_Hide = NOTHING,
    InCombatLockdown = function() return false end,
    CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, SetRGBA = NOTHING } end,
    UIParent = Frame(),
    GetTime = function() return 600 end,
    GetQuestDifficultyColor = function() return { r = 0.25, g = 0.75, b = 0.25 } end,
    GetClassInfo = function(id) return "Class", id == 8 and "MAGE" or "PRIEST", id end,
    UnitName = function(unit) return unit == "player" and "Die Man" or nil end,
    UnitClass = function() return "Mage", "MAGE" end,
    UnitLevel = function() return 20 end,
    C_LFGList = {
        GetActiveEntryInfo = function()
            if Group.listed then return { activityIDs = { 2 }, generalPlaystyle = 3 } end
        end,
        GetAvailableActivities = function() return { 2, 1, 3 } end,
    },
    GROUP_FINDER_GENERAL_PLAYSTYLE1 = "Learning", GROUP_FINDER_GENERAL_PLAYSTYLE2 = "Relaxed",
    GROUP_FINDER_GENERAL_PLAYSTYLE3 = "Competitive", GROUP_FINDER_GENERAL_PLAYSTYLE4 = "Carry Offered",
}, { __index = _G })
env._G = env

-------------------------------------------------------------------------------
--  Loading: nothing made, nothing listened to
-------------------------------------------------------------------------------
Load(TocFiles("^Shared/.*%.lua$"), env)
local shared = made
for _, path in ipairs(TocFiles("^NaowhForever_Utilities/GroupFinder/.*%.lua$")) do
    if path:find("/View/") or path:find("/UI/") then Load({ path }, env) end
end
local UI = GF.UI
local function Listened()
    local n = 0
    for _, list in pairs(GF.fns) do n = n + #list end
    return n
end
check("nothing made at load, nothing listened to, no timer", made == shared and Listened() == 0 and #timers == 0)
check("the window's opener and toggle are there", type(ns.OpenGroupFinder) == "function"
    and type(ns.ToggleGroupFinder) == "function" and UI.Window() == nil)

local page = ns.Shared.Settings.pages["Group Finder/Settings"]
local banner = page and page.items[1]
check("its settings page opens with Open Group Finder, then Your Card", banner and banner.window
    and banner.text == "Open Group Finder" and page.items[2] == page.cards.card)

-------------------------------------------------------------------------------
--  Opening: turns it on, then the note before a search
-------------------------------------------------------------------------------
ns.OpenGroupFinder()
local window = UI.Window()
local view = window.view
check("opening turns it on and says so", values.enabled == true and printed[1]:find("turned on", 1, true))
check("the window is shown, titled, with its Search button", window:IsShown() and window.title.text == "Looking For Group"
    and window.search ~= nil)
check("it listens once opened", Listened() > 0)

local function Note()
    local note = view:Find("note", function() return true end)
    return note and note.text and note.text.text
end

local function Listing(id)
    return view:Find("listing", function(row) return row.id == id end)
end

check("before a search: a note to search, no rows, no count", Note() and Note():find("Search", 1, true)
    and Listing(11) == nil and window.subtitle.text == "")
check("the leaders were asked on the draw", GF.asks == 1)

window.search.scripts.OnClick(window.search)
Flush()
check("Search runs a search", GF.runs == 1)
check("and says it is searching", Note() == "Searching...")

GF.Listings.searched = true
GF.Search.state = "done"
GF.Fire("listings", false)
Flush()
check("results: four rows and the count", Listing(11) and Listing(12) and Listing(13) and Listing(14)
    and window.subtitle.text == "4 groups" and Note() == nil)
check("your own listing first, then newest first", Listing(13).index == 1 and Listing(12).index == 2
    and Listing(14).index == 3 and Listing(11).index == 4)

local group = Listing(11)
check("a listing's dungeon and its levels", group.title.text == "Shadowfang Keep" and group.range.text == "22-30")
check("its leader and level", group.leader.text == "Korvath" and group.level.text == "25")
local mage = Listing(13)
check("the leader in their class color, on the band too", mage.leader.r == MAGE.r and mage.band.red == MAGE.r)
check("a group's spots: its roles, then empty", group.slots[1].atlas == UI.Style.ROLE_ATLAS.TANK
    and group.slots[2].atlas == UI.Style.ROLE_ATLAS.DAMAGER and group.slots[3].atlas == UI.Style.ROLE_ATLAS.DAMAGER
    and group.slots[4].atlas == UI.Style.EMPTY_SLOT and group.slots[5].atlas == UI.Style.EMPTY_SLOT
    and group.slots[5]:IsShown())
local solo = Listing(12)
check("a solo player's roles, and no empty spots", solo.slots[1].atlas == UI.Style.ROLE_ATLAS.HEALER
    and solo.slots[2].atlas == UI.Style.ROLE_ATLAS.DAMAGER and not solo.slots[3]:IsShown())
local raid = Listing(14)
check("a raid's size as a count", raid.size:IsShown() and raid.size.text == "12/40" and not raid.slots[1]:IsShown()
    and raid.range.text == "")
check("a delisted listing is faded", raid.alpha == UI.Style.DELISTED_ALPHA and group.alpha == 1)
check("the leader's card: score, kills and quests", group.score.text == "score 23.9 at 25"
    and group.kills.text == "3 boss kills" and group.quests.text == "2 quests")
check("a leader waited on shows it", solo.score.text == "..." and solo.kills.text == "")
check("no card and none coming: nothing", raid.score.text == "")
check("your own card on your own listing", mage.score.text == "score 18.9 at 20" and mage.kills.text == "First time"
    and mage.quests.text == "")
check("how long ago each was listed", solo.age.text == "just now" and group.age.text == "10m ago")

-------------------------------------------------------------------------------
--  The bar: dungeon chips, the text filter and the sort
-------------------------------------------------------------------------------
local bar = window.bar
local chips = bar.chips
check("chips for your level, all, then each dungeon by level", bar:IsShown() and chips[1].label.text == "For your level"
    and chips[2].label.text == "All" and chips[3].label.text == "MC" and chips[4].label.text == "DM 17-26"
    and chips[5].label.text == "SFK 22-30")
check("your level picked to start, in the accent", chips[1]._rest == ACCENT and chips[4]._rest == WHITE)
check("a dungeon outside your level is muted", chips[5].label.r == MUTED.r and chips[4].label.r == WHITE.r)
local runs = GF.runs
chips[4]:Click()
check("a chip searches for its dungeon and is picked", GF.runs == runs + 1 and GF.Search.pick == 1
    and chips[4]._rest == ACCENT and chips[1]._rest == WHITE)
chips[2]:Click()
check("All searches every dungeon", GF.Search.pick == "all" and chips[2]._rest == ACCENT and chips[4]._rest == WHITE)
chips[1]:Click()
GF.Search.state = "done"
view:Redraw()
check("the filter box says what it finds", bar.search.hint.text == "Filter by dungeon, leader or note")
bar.search.onChange("KOR")
Flush()
check("typing filters the rows, and the count says so", Listing(11) and not Listing(12) and not Listing(13)
    and window.subtitle.text == "1 of 4 groups")
bar.search.onChange("onyxia")
Flush()
check("nothing matching says so", Note() == "No groups match your filter." and not Listing(11))
bar.search.onChange("")
Flush()
check("clearing it shows them all again", Listing(11) and Listing(12) and Listing(13) and Listing(14)
    and window.subtitle.text == "4 groups")
check("the sort, newest to start", bar.sort.text.text == "Sort: Newest" and GF.sortedBy == nil)
bar.sort.scripts.OnClick(bar.sort)
local radios = {}
menus[#menus].fill(nil, { CreateTitle = NOTHING, CreateRadio = function(_, label, _, set, key)
    radios[#radios + 1] = { label = label, set = set, key = key }
end })
check("its menu: Newest, Naowh Score and Level", menus[#menus].owner == bar.sort and #radios == 3
    and radios[1].label == "Newest" and radios[2].label == "Naowh Score" and radios[3].label == "Level")
radios[2].set(radios[2].key)
Flush()
check("picking one saves it, says so and sorts by it", values.sort == "score" and bar.sort.text.text == "Sort: Naowh Score"
    and GF.sortedBy == "score")
values.sort = nil
view:Redraw()

local before = made
cards.Nessa = { score = 211, level = 19, dungeon = "Deadmines", hasKills = false, nKills = 0, kills = {},
    hasQuests = true, nHave = 0 }
waitingFor.Nessa = nil
GF.Fire("card")
Flush()
check("a card arriving redraws its row", Listing(12).score.text == "score 21.1 at 19")
check("on the same rows: nothing made", made == before)
cards.Nessa.dungeon = "ShadowfangKeep"
view:Redraw()
check("a card for another dungeon shows only the score", Listing(12).kills.text == "" and Listing(12).quests.text == ""
    and Listing(12).score.text == "score 21.1 at 19")

GF.Search.state = "failed"
GF.Fire("search", "failed")
Flush()
check("a failed search says so, and shows no rows", Note():find("failed", 1, true) and Listing(11) == nil)
GF.Search.state = "unavailable"
view:Redraw()
check("nothing to search at your level says so", Note():find("nothing to search", 1, true))
GF.Search.state = "done"
GF.Listings.state = "locked"
view:Redraw()
check("chat lockdown says listings cannot be read", Note():find("encounter", 1, true) and Listing(11) == nil)
GF.Listings.state = "ready"
view:Redraw()

-------------------------------------------------------------------------------
--  Browse: the leader's group, and applying
-------------------------------------------------------------------------------
cards.Nessa, waitingFor.Nessa = nil, true
view:Redraw()
group = Listing(11)
check("a listed leader's minimum score beside their score", group.min.text == "12.0+")
check("their note and the roles they need, on hover", group.note == "Bring food"
    and group.needs == "Needs 0 tank, 1 healer, 1 damage")
check("Apply on a leader who runs Naowh Forever", group.apply:IsShown())
check("not on a leader waited on, your own or a delisted listing", not Listing(12).apply:IsShown()
    and not Listing(13).apply:IsShown() and not Listing(14).apply:IsShown())
check("no group, no minimum", Listing(13).min.text == "" and Listing(13).needs == nil)
group.apply:Click()
check("Apply applies to the leader", applies[1] == "Korvath")
applied.Korvath = { acked = false }
GF.Fire("applied")
Flush()
check("then says it is sent, with no Apply", Listing(11).status.text == "Applied" and not Listing(11).apply:IsShown())
applied.Korvath.acked = true
GF.Fire("received")
Flush()
check("and when the leader's game has it", Listing(11).status.text == "Received")
applied.Korvath.declined = true
GF.Fire("declined")
Flush()
check("and when declined", Listing(11).status.text == "Declined")

-------------------------------------------------------------------------------
--  Tabs and Create
-------------------------------------------------------------------------------
local pages = window.pages
local function Tab(key)
    for _, button in ipairs(window.tabs.buttons) do
        if button.key == key and button:IsShown() then return button end
    end
end
check("three tabs: Browse, Your Group and Create", Tab("browse") and Tab("group") and Tab("create")
    and Tab("group").label == "Your Group")
window.tabs.onPick("create")
local create = pages.create
check("Create shows its page, without the Browse list, its bar or Search", create:IsShown()
    and not window.scroll:IsShown() and not window.bar:IsShown() and not window.search:IsShown()
    and not pages.group:IsShown())
local tiles = create.tiles
check("a tile per dungeon, by level", #tiles == 3 and tiles[1].label.text == "MC" and tiles[2].label.text == "DM"
    and tiles[3].label.text == "SFK")
check("each with its levels, in their difficulty's color", tiles[2].range.text == "17-26" and tiles[2].range.g == 0.75
    and tiles[1].range.text == "")
check("and its bosses from the Journal", tiles[2].bosses.text == "2 bosses" and tiles[3].bosses.text == "1 boss"
    and tiles[1].bosses.text == "")
check("nothing to list yet: why, and List Group off", create.list.label.text == "List Group"
    and create.list.enabled == false and create.why.text:find("Pick a dungeon", 1, true))
tiles[2]:Click()
check("a tile picks its dungeon, marked in the accent", Group.activity == 1 and tiles[2]._rest == ACCENT
    and tiles[3]._rest == WHITE)
create.styles[3]:Click()
check("a style picks the game's playstyle", Group.style == 3 and create.styles[3]._rest == ACCENT
    and create.styles[3].label.text == "Competitive")
check("then List Group is on", create.list.enabled == true and create.why.text == "" and create.list.primary)
create.roles[3].plus:Click()
create.roles[1].minus:Click()
create.roles[1].minus:Click()
check("roles needed go up and down, never below none", Group.damage == 4 and Group.tanks == 0
    and create.roles[3].value.text == "4" and create.roles[1].value.text == "0")
check("the minimum score slider runs from 0 to 30 in halves", create.slider.low == 0 and create.slider.high == 30
    and create.slider.step == 0.5)
create.slider._set(12.5)
check("and sets it in tenths", Group.min == 125)
create.note:SetText("Quests welcome")
create.note.scripts.OnTextChanged(create.note)
check("the note, with its count", Group.note == "Quests welcome" and create.count.text == "14/60")
Group.leader = false
create.Paint()
check("not the leader: why, and List Group off", create.list.enabled == false
    and create.why.text:find("leader", 1, true))
Group.leader = true
create.list:Click()
check("List Group lists it and shows Your Group", Group.lists == 1 and Group.listed and pages.group:IsShown()
    and not create:IsShown())

-------------------------------------------------------------------------------
--  Your Group
-------------------------------------------------------------------------------
local yours = pages.group
check("your listing's dungeon and levels", yours.title.text == "Shadowfang Keep" and yours.range.text == "22-30")
check("its playstyle, minimum score, how long it is listed and who applied",
    yours.info.text == "Competitive   Minimum score 12.5   Listed 10m ago   0 applied")
check("your party", yours.party[1].text == "Die Man 20" and yours.party[1].r == MAGE.r and yours.party[2].text == "")
check("the leader can delist", yours.delist:IsShown())
local function Applicants()
    return yours.view:Find("note", function() return true end), yours.view
end
local note = Applicants()
check("nobody applied yet says so", note and note.text.text:find("No one has applied", 1, true))
GF.Comms.applicants[1] = Applicant("Erin", 5, 211, 1)
GF.Comms.applicants[1].card.kills = { 1, 0 }
GF.Comms.applicants[2] = Applicant("Magus", 8, 239, 2)
GF.Fire("applicant")
Flush()
local function Row(name)
    return yours.view:Find("applicant", function(row) return row.record.name == name end)
end
check("the applicants, best score first", Row("Magus").index == 1 and Row("Erin").index == 2)
check("and the count on the tab", Tab("group").label == "Your Group (2)")
local magus = Row("Magus")
check("an applicant's name in their class color, their score, kills, BiS and quests", magus.name.text == "Magus"
    and magus.name.r == MAGE.r and magus.score.text == "score 23.9 at 25" and magus.kills.text == "7 boss kills"
    and magus.bis.text == "BiS 9/14" and magus.quests.text == "1 quest")
check("one boss kill reads as one", Row("Erin").kills.text == "1 boss kill")
check("the roles they apply as", magus.roles[1].atlas == UI.Style.ROLE_ATLAS.HEALER
    and magus.roles[2].atlas == UI.Style.ROLE_ATLAS.DAMAGER and not magus.roles[3]:IsShown())
check("and their note on hover", magus.note == "Hi")
magus.invite:Click()
check("Invite invites them", Group.invites[1] == "Magus")
GF.Fire("applicant")
Flush()
check("then says so instead of Invite", not Row("Magus").invite:IsShown() and Row("Magus").invited.text == "Invited")
Row("Erin").decline:Click()
check("Decline declines them", Group.declines[1] == "Erin")
Group.leader = false
GF.Fire("group")
Flush()
check("no longer the leader: no applicants, no count", Row("Magus") == nil and Tab("group").label == "Your Group"
    and not yours.info.text:find("applied", 1, true))
Group.leader = true
GF.Fire("group")
Flush()
check("leading again, they are back", Row("Magus") ~= nil and Tab("group").label == "Your Group (2)")
yours.delist:Click()
GF.Fire("group")
Flush()
note = Applicants()
check("delisted: no listing, a note to make one", note and note.text.text:find("no listing", 1, true)
    and not yours.delist:IsShown() and yours.title.text == "")
window.tabs.onPick("create")
check("Create after delisting lists again", create.list.label.text == "List Group")
create.reset:Click()
check("Reset clears the form", Group.activity == nil and Group.style == nil and Group.min == 0 and Group.note == ""
    and Group.tanks == 1 and Group.damage == 3 and create.slider.value == 0)
window.tabs.onPick("browse")
check("Browse again shows the list, its bar and Search", window.scroll:IsShown() and window.bar:IsShown()
    and window.search:IsShown())

S.Set("enabled", false)
check("turning it off closes the window", not window:IsShown())
ns.ToggleGroupFinder()
check("the toggle opens it again, turning it on", window:IsShown() and values.enabled == true)
ns.ToggleGroupFinder()
check("and closes it", not window:IsShown())

print(("test-group-finder-ui: %d checks passed"):format(checks))

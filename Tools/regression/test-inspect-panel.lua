-- Run with Lua 5.1 from the repository root: the Naowh inspect panel, loaded from the files
-- Shared.xml, CharacterPanel.xml and InspectPanel.xml load (with the real sender check and the
-- BiS List's enchant rules), against stubs of the game's inspect window. Checks that it is off
-- and hooks nothing by default, waits for the game's inspect window to load, and once on fades
-- the art, widens the window and paints each part for the GUID shown: the slots' marks, the
-- score card, talents, gear check, guild, note and History; a stale INSPECT_READY for another
-- player is ignored; their BiS stars come only from their own answer, and every bad answer is
-- dropped; the answering side's limits; missing APIs and a missing Player History break
-- nothing; it stands down for EllesmereUI's inspect sheet and swaps it like the character
-- panel; off again, the game's art and width come back; and neither a slot's update, a
-- refresh nor an answer read makes garbage.
local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Measure = dofile("Tools/regression/measure.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

-------------------------------------------------------------------------------
--  Stubs: a frame keeps its scripts, hooks, events, size, text, alpha, anchors and shown
--  state; every other method is one shared do-nothing function, so stubs make no garbage.
-------------------------------------------------------------------------------
local NOTHING = function() end
local Frame
local made = 0
local created = {}
local METHODS = {
    SetScript = function(f, script, fn) f.scripts[script] = fn end,
    HookScript = function(f, script, fn) f.hooks[script] = fn end,
    GetParent = function(f) return rawget(f, "parent") end,
    SetText = function(f, text) f.text = text end,
    Show = function(f) f.shown = true end,
    Hide = function(f) f.shown = false end,
    SetShown = function(f, shown) f.shown = shown and true or false end,
    IsShown = function(f) return rawget(f, "shown") ~= false end,
    IsVisible = function(f) return rawget(f, "shown") ~= false end,
    SetAlpha = function(f, alpha) f.alpha = alpha end,
    SetDesaturated = function(f, on) f.desaturated = on end,
    SetVertexColor = function(f, r, g, b) f.r, f.g, f.b = r, g, b end,
    SetTextColor = function(f, r, g, b) f.r, f.g, f.b = r, g, b end,
    SetWidth = function(f, w) f.w = w end,
    SetHeight = function(f, h) f.h = h end,
    SetTexCoord = function(f, l) f.crop = l end,
    GetFrameLevel = function() return 1 end,
    GetStringWidth = function() return 40 end,
    GetText = function(f) return rawget(f, "text") end,
    GetWidth = function(f) return rawget(f, "w") or 300 end,
    GetHeight = function(f) return rawget(f, "h") or 37 end,
    SetPoint = function(f, point, relative, _, x)
        local points = rawget(f, "points")
        if not points then points = {}; f.points = points end
        points[point] = relative
        if point == "BOTTOMRIGHT" then f.right = x end
    end,
    ClearAllPoints = function(f)
        local points = rawget(f, "points")
        if points then for k in pairs(points) do points[k] = nil end end
    end,
    SetAllPoints = function(f, relative) f.points = { all = relative or true } end,
    GetEffectiveScale = function() return 1 end,
    CreateTexture = function(f) return Frame(f) end,
    CreateFontString = function(f) return Frame(f) end,
    GetObjectType = function() return "Texture" end,
    RegisterEvent = function(f, event) f.events[event] = true end,
    UnregisterEvent = function(f, event) f.events[event] = nil end,
    UnregisterAllEvents = function(f) for k in pairs(f.events) do f.events[k] = nil end end,
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
local fonts = {}
local hooks, sent, timers, menus, prompts, notes, remembered = {}, {}, {}, {}, {}, {}, {}
local state = { values = {}, listeners = {}, now = 100, clock = 1000000 }

-- The players: you, A (Bob Smith, a Fury warrior running Naowh Forever) and B (Cat Jones).
local GUID_ME, GUID_A, GUID_B = "Player-1-0000000A", "Player-1-000000AA", "Player-1-000000BB"
local units = {
    player = { guid = GUID_ME, first = "Die", second = "Man", level = 20, faction = "Alliance",
        items = { [1] = 101 } },
    target = {},
}
local A = { guid = GUID_A, first = "Bob", second = "Smith", level = 22, faction = "Alliance",
    items = { [1] = 101, [2] = 102, [5] = 200, [8] = 300, [16] = 500 } }
local B = { guid = GUID_B, first = "Cat", second = "Jones", level = 18, faction = "Alliance",
    items = { [1] = 111, [5] = 211 } }
local function Target(who) units.target = who end
Target(A)

-- Items: their links (enchant second), levels, kinds.
local ENCHANT = { [102] = 0, [200] = 0, [300] = 0 }
local LEVEL = { [101] = 30, [102] = 25, [200] = 24, [300] = 20, [500] = 26, [111] = 15, [211] = 16 }
local EQUIP = { [101] = "INVTYPE_HEAD", [102] = "INVTYPE_NECK", [200] = "INVTYPE_CHEST", [300] = "INVTYPE_FEET",
    [500] = "INVTYPE_2HWEAPON", [111] = "INVTYPE_HEAD", [211] = "INVTYPE_CHEST" }
local LINK, LEVEL_OF, ID_OF = {}, {}, {}
for id, level in pairs(LEVEL) do
    local link = ("item:%d:%d"):format(id, ENCHANT[id] or 41)
    LINK[id], LEVEL_OF[link], ID_OF[link] = link, level, id
end
local GAIN = { [300] = 12.4 }

-- Their talents: 5 / 20 / 0, a Fury tree; Naowh's Fury build is 5 points in five talents.
local GROUPS = { { groupID = 11, displayName = "Arms" }, { groupID = 12, displayName = "Fury" },
    { groupID = 13, displayName = "Protection" } }
local CURRENCY = { { traitNodeGroupID = 11, currencyInfos = { { spent = 5 } } },
    { traitNodeGroupID = 12, currencyInfos = { { spent = 20 } } },
    { traitNodeGroupID = 13, currencyInfos = { { spent = 0 } } } }
local NODES = { [1001] = { activeRank = 5 }, [1002] = { activeRank = 5 }, [1003] = { activeRank = 5 },
    [1004] = { activeRank = 5 }, [1005] = { activeRank = 5 } }
local CONFIG = { treeIDs = { 77 } }
local FURY = { name = "Fury", points = {} }
for node = 1001, 1005 do for _ = 1, 5 do FURY.points[#FURY.points + 1] = node end end

local QOL_DEFAULTS = { inspectPanelBadge = true }
-- The same tables each call, so a repaint's garbage is the module's.
local COMBAT, WEIGHTS = { name = "Combat Rogue" }, { agi = 1 }
local DEVELOPER = { title = "Developer", color = WHITE, large = "art" }
local NO_UNIT = {}
local WARRIOR_TREES = { "arms-warrior", "fury-warrior", "protection-warrior" }
local S = {
    Get = function(key) return state.values[key] end,
    Set = function(key, value)
        state.values[key] = value
        for _, fn in ipairs(state.listeners) do fn(key, value) end
    end,
    OnChange = function(fn) state.listeners[#state.listeners + 1] = fn end,
    Default = function(key) return QOL_DEFAULTS[key] end,
}
state.values = { enabled = true, characterPanel = false, inspectPanel = false, inspectPanelScore = true,
    inspectPanelBadge = true, inspectPanelShareBis = false, naowhScoreCompare = "max" }

local SCORE = { player = 26.4 }
local COMPLETE = { player = true }
local gamepad = false
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    GamepadStandDown = function() return gamepad end,
    THEME = setmetatable({}, { __index = function() return WHITE end }),
    Color = function(_, text) return tostring(text) end,
    Font = function(parent)
        local fs = Frame(parent)
        fonts[#fonts + 1] = fs
        return fs
    end,
    Solid = function(parent) return Frame(parent) end,
    Border = function()
        return { SetColor = function(self, r, g, b) self.r, self.g, self.b = r, g, b end }
    end,
    Hairline = function(region) return region end,
    UIFontPath = function() return "font" end,
    PixelInset = function(region) return region end,
    UI = { Keep = NOTHING },
    QoLSettings = S,
    Apply = NOTHING,
    FEATURE_BADGES = 1, BADGES_LIVE = 1,
    PlainText = function(text, max)
        if type(text) ~= "string" then return nil end
        if max and #text > max then text = text:sub(1, max) end
        return (text:gsub("%c", " "):gsub("||", "\1"):gsub("|", "||"):gsub("\1", "||"))
    end,
    IsBisItem = function(id) return state.myBis and state.myBis[id] end,
    BadgeOf = function(guid)
        if guid == GUID_A then return DEVELOPER, "developer" end
    end,
    BadgeSince = function() return nil end,
    BADGE_TIERS = {},
    TrainingBuilds = { [1] = { FURY } },
    StatWeights = {
        OnChange = NOTHING,
        STATS = { { "agi", "Agility" } },
        ActiveSpec = function() return "combat-rogue" end,
        Spec = function() return COMBAT end,
        For = function() return WEIGHTS end,
        Power = function() return 100 end,
        BestGain = function(id) return GAIN[id] end,
        TreeSpec = function(class, index) return class == "WARRIOR" and WARRIOR_TREES[index] or nil end,
    },
    NaowhScore = {
        Unit = function(unit) return SCORE[unit] or 0, COMPLETE[unit] == true end,
        Colored = function(score) return "|cff1eff00" .. score .. "|r" end,
        Best = function() return 58.8 end,
        Grade = function(score) return score / 58.8 end,
        RAMP = { { 0, 0.6, 0.6, 0.6 }, { 1, 1, 0.5, 0 } },
        COMPARE = { LEVEL = "level", BOTH = "both", MAX = "max" },
        Text = tostring,
        Remember = function(guid, score) remembered[guid] = score end,
        Known = function(guid) return state.known and state.known[guid] end,
    },
    ConfirmReload = function() state.reloads = (state.reloads or 0) + 1 end,
    Confirm = NOTHING,
    PromptText = function(title, text, max, onAccept)
        prompts[#prompts + 1] = { title = title, text = text, max = max, accept = onAccept }
    end,
}
ns.BiS = {
    On = function() return true end,
    OnListChange = NOTHING,
    Lists = { CurrentSpec = NOTHING },
    View = {
        EnchantBadge = function(parent, opts)
            local badge = Frame(parent)
            badge.opts = opts
            return badge
        end,
        PaintEnchantBadge = NOTHING,
    },
}
-- One enchant, for a chest (INVTYPE_CHEST, inventory type 5): a chest can be enchanted, a neck or
-- feet cannot.
ns.BiSEnchants = { [7418] = { enchant = 41, skill = 1, class = 4, inv = 2 ^ 5, sub = 0, stats = { sta = 2 } } }

local tooltip = Frame()
tooltip.SetText = function(self, text) self.lines = { text } end
tooltip.AddLine = function(self, text) self.lines[#self.lines + 1] = text end
tooltip.AddDoubleLine = function(self, left, right) self.lines[#self.lines + 1] = left .. "=" .. tostring(right) end
tooltip.IsForbidden = function() return false end
tooltip.GetOwner = function(self) return self.owner end

local function Unit(unit) return units[unit] or NO_UNIT end

local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function(_, _, parent)
        local f = Frame(parent)
        created[#created + 1] = f
        if parent then
            local children = rawget(parent, "children") or {}
            parent.children = children
            children[#children + 1] = f
        end
        return f
    end,
    hooksecurefunc = function(a, b, c)
        if type(a) == "string" then hooks[a] = b else
            local original = a[b]
            a[b] = function(...) original(...); c(...) end
        end
    end,
    issecretvalue = function() return false end,
    C_Item = {
        GetItemNameByID = function(id) return "item " .. id end,
        GetItemQualityByID = function(id) return id and 4 or nil end,
        GetDetailedItemLevelInfo = function(link) return LEVEL_OF[link] end,
        GetItemInfoInstant = function(item)
            local id = type(item) == "number" and item or ID_OF[item]
            return id, nil, nil, EQUIP[id], nil, 4, 0
        end,
        GetItemInfo = NOTHING,
        IsItemDataCachedByID = function() return true end,
        GetItemCount = function() return 0 end,
    },
    GetInventoryItemID = function(unit, slot) return Unit(unit).items and Unit(unit).items[slot] end,
    GetInventoryItemLink = function(unit, slot)
        local id = Unit(unit).items and Unit(unit).items[slot]
        return id and LINK[id]
    end,
    UnitGUID = function(unit) return Unit(unit).guid end,
    UnitFullName = function(unit) return Unit(unit).first, Unit(unit).second end,
    UnitName = function(unit) return Unit(unit).first end,
    UnitLevel = function(unit) return Unit(unit).level end,
    UnitIsPlayer = function(unit) return Unit(unit).guid ~= nil end,
    UnitFactionGroup = function(unit) return Unit(unit).faction end,
    UnitClass = function() return "Warrior", "WARRIOR", 1 end,
    GetNormalizedRealmName = function() return "Forever" end,
    GetNumGuildMembers = function() return 0 end,
    GetGuildInfo = function(unit) if unit == "target" and units.target == A then return "Naowh", "Officer" end end,
    C_FriendList = { IsFriend = function(guid) return guid == GUID_A end },
    C_PaperDollInfo = { GetInspectItemLevel = function() return 23.4 end },
    C_Traits = {
        HasValidInspectData = function() return state.talentsReady ~= false end,
        GetConfigInfo = function(id) return id == -1 and CONFIG or nil end,
        GetGroupDisplayInfoByTreeID = function() return GROUPS end,
        GetGroupCurrencyInfo = function() return CURRENCY end,
        GetNodeInfo = function(_, node) return NODES[node] end,
    },
    Constants = { TraitConsts = { INSPECT_TRAIT_CONFIG_ID = -1 } },
    C_ChatInfo = {
        RegisterAddonMessagePrefix = function(prefix) state.prefix = prefix end,
        SendAddonMessage = function(prefix, message, channel, target)
            sent[#sent + 1] = { prefix = prefix, message = message, channel = channel, target = target }
        end,
        InChatMessagingLockdown = function() return false end,
    },
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    GetTime = function() return state.now end,
    time = function() return state.clock end,
    date = function() return "1 Jan 2026" end,
    EventUtil = { ContinueOnAddOnLoaded = function(name, fn) state.waitingFor, state.onLoaded = name, fn end },
    TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) state.itemTooltip = fn end },
    Enum = { TooltipDataType = { Item = 0 } },
    MenuUtil = { CreateContextMenu = function(owner, fn) menus[#menus + 1] = { owner = owner, fn = fn } end },
    ITEM_QUALITY_COLORS = { [4] = { hex = "|cffa335ee", r = 0.64, g = 0.21, b = 0.93 } },
    RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } },
    GameTooltip = tooltip,
    GameTooltip_Hide = NOTHING,
    UIParent = Frame(),
    Menu = { GetManager = function() return { IsAnyMenuOpen = function() return false end } end },
    InCombatLockdown = function() return false end,
    PANEL_INSET_RIGHT_OFFSET = -6,
    PANEL_INSET_BOTTOM_OFFSET = 4,
    GameFontNormal = "GameFontNormal",
    CreateColor = function() return { SetRGBA = NOTHING } end,
}, { __index = _G })
env._G = env
env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

-- The game's inspect window, as Blizzard_InspectUI makes it on Forever (Camelot XML).
local NAMES = { "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands",
    "Finger0", "Finger1", "Trinket0", "Trinket1", "Back", "MainHand", "SecondaryHand", "Ranged", "Tabard" }
local slots = {}
local function Window()
    local frame = Frame()
    frame.w = 338
    frame.NineSlice, frame.PortraitContainer, frame.Bg, frame.TopTileStreaks = Frame(), Frame(), Frame(), Frame()
    frame.Inset = Frame(frame)
    frame.Inset.Bg, frame.Inset.NineSlice = Frame(), Frame()
    frame.CloseButton = Frame(frame)
    frame.ModeTabs = { Tabs = { Frame(), Frame() } }
    frame.ModeTabs.Tabs[1].Background = Frame()
    frame.TitleContainer = { TitleText = Frame() }
    frame.shown = false
    env.InspectFrame = frame
    env.InspectPaperDollFrame = Frame(frame)
    env.InspectPaperDollFrame.InspectTalents = Frame()
    env.InspectGuildFrame = Frame(frame)
    env.INSPECTFRAME_SUBFRAMES = { "InspectPaperDollFrame", "InspectGuildFrame" }
    env.InspectModelFrame = Frame(env.InspectPaperDollFrame)
    env.InspectModelFrame.BackgroundTopLeft = Frame()
    env.InspectModelFrameBorderTopLeft = Frame()
    env.InspectLevelText = Frame()
    for i, name in ipairs(NAMES) do
        local button = Frame()
        button.icon, button.IconBorder, button.BorderFrame, button.normal = Frame(button), Frame(button),
            Frame(button), Frame(button)
        button.GetNormalTexture = function(self) return self.normal end
        slots[i] = button
        env["Inspect" .. name .. "Slot"] = button
    end
    return frame
end

local files = TocFiles("^Shared/.*%.lua$")
files[#files + 1] = "Core/Senders.lua"
files[#files + 1] = "NaowhForever_BiS/BiS/Constants.lua"
files[#files + 1] = "NaowhForever_BiS/BiS/Enchants.lua"
for _, path in ipairs(TocFiles("^NaowhForever_BiS/CharacterPanel/.*%.lua$")) do files[#files + 1] = path end
local panelFiles = TocFiles("^NaowhForever_BiS/InspectPanel/.*%.lua$")
check("the TOC loads the inspect panel's files, its settings last",
    panelFiles[#panelFiles] == "NaowhForever_BiS/InspectPanel/UI/SettingsPage.lua"
    and panelFiles[1] == "NaowhForever_BiS/InspectPanel/InspectPanel.lua")
for _, path in ipairs(panelFiles) do files[#files + 1] = path end
Load(files, env)
local IP = ns.InspectPanel
local Test = IP._TheirBiSTest
ns.Shared.ForeverNew.items[101] = true

local function Message(text, sender, channel)
    Test.OnMessage(nil, "CHAT_MSG_ADDON", "NaowhInspect", text, channel or "WHISPER", sender)
end

-------------------------------------------------------------------------------
--  Off (and Share Your BiS off, checked on its own below): nothing hooked, nothing made,
--  nothing waited for.
-------------------------------------------------------------------------------
local before = made
ns.Apply()
check("off: the game's inspect window not waited for, nothing hooked or made", state.onLoaded == nil
    and hooks.InspectPaperDollItemSlotButton_Update == nil and made == before and not IP.On())

-------------------------------------------------------------------------------
--  Gamepad interface style: it stays off, waiting for and hooking nothing.
-------------------------------------------------------------------------------
gamepad = true
S.Set("inspectPanel", true)
check("gamepad style: the inspect window not waited for, nothing hooked or made", state.onLoaded == nil
    and state.waitingFor == nil and hooks.InspectPaperDollItemSlotButton_Update == nil and made == before
    and not IP.On())
S.Set("inspectPanel", false)
gamepad = false

-------------------------------------------------------------------------------
--  On before the game has loaded its inspect window: it waits for it, and builds nothing.
-------------------------------------------------------------------------------
S.Set("inspectPanel", true)
check("on: waits for Blizzard_InspectUI, hooking nothing yet", state.waitingFor == "Blizzard_InspectUI"
    and hooks.InspectPaperDollItemSlotButton_Update == nil and IP.pane == nil)

-------------------------------------------------------------------------------
--  The game loads it: hooked, widened, dressed.
-------------------------------------------------------------------------------
local frame = Window()
state.onLoaded()
-- The switch keeps its picked side in .shown (the shared tabs' own field): its showing is read
-- through its own SetShown here.
IP.switch.SetShown = function(self, on) self.visible = on and true or false end
check("loaded: the slot update and the inset's bottom hooked", hooks.InspectPaperDollItemSlotButton_Update ~= nil
    and hooks.FrameTemplate_SetButtonBarHeight ~= nil and frame.hooks.OnShow ~= nil and frame.hooks.OnHide ~= nil)
check("the window a pane wider, its tabs' frames kept on the left", frame.w == 338 + 233
    and env.InspectPaperDollFrame.points.BOTTOMRIGHT == frame and env.InspectPaperDollFrame.right == -233
    and env.InspectGuildFrame.right == -233)
check("the inset keeps its width", frame.Inset.right == -6 - 233)
hooks.FrameTemplate_SetButtonBarHeight(frame, 26)
check("and again when the game moves its bottom (the guild tab's button bar)", frame.Inset.right == -6 - 233)
check("the game's art faded, never hidden", frame.NineSlice.alpha == 0 and frame.PortraitContainer.alpha == 0
    and frame.Bg.alpha == 0 and frame.Inset.Bg.alpha == 0 and env.InspectModelFrame.BackgroundTopLeft.alpha == 0
    and env.InspectModelFrameBorderTopLeft.alpha == 0 and frame.NineSlice.shown ~= false)
check("its side tabs in our colors", frame.ModeTabs.Tabs[1].Background.desaturated == true)
local head, neck, chest, feet = slots[1], slots[2], slots[5], slots[8]
check("each slot's art faded and its icon cropped", head.normal.alpha == 0 and head.IconBorder.alpha == 0
    and head.icon.crop == 0.08)

local events
for _, f in ipairs(created) do
    if f.events.INSPECT_READY then events = f end
end
check("INSPECT_READY listened to while on", events ~= nil)

-- Reported in game: the window's code loads with its unit still false, and a slot update came
-- before the game set who is inspected.
do
    local realGUID = env.UnitGUID
    env.UnitGUID = function(unit)
        assert(type(unit) == "string", "UnitGUID wants a unit string")
        return realGUID(unit)
    end
    frame.unit, frame.shown = false, true
    check("no unit yet (false): no one inspected", IP.Current() == nil)
    hooks.InspectPaperDollItemSlotButton_Update(slots[1])
    check("and a slot update before it paints nothing, without an error", true)
    frame.shown = false
    env.UnitGUID = realGUID
end

-------------------------------------------------------------------------------
--  The window shows A: each part painted for A.
-------------------------------------------------------------------------------
local Update = hooks.InspectPaperDollItemSlotButton_Update
frame.unit, frame.shown = "target", true
frame.hooks.OnShow(frame)
for _, button in ipairs(slots) do Update(button) end
local function Ours(button) return button.children and button.children[1] end
local h, n, c, f = Ours(head), Ours(neck), Ours(chest), Ours(feet)
check("ours over each slot, knowing its slot", h.slot == 1 and c.slot == 5 and f.slot == 8)
check("the edge in the quality's color; an empty slot black", h.edge.r == 0.64 and Ours(slots[3]).edge.r == 0)
check("their item levels and Forever's mark", h.marks.level.text == 30 and c.marks.level.text == 24
    and h.marks.forever.shown == true and c.marks.forever.shown == false)
check("no BiS star before their Naowh Forever answers", h.marks.rank.text == "" and c.marks.rank.text == "")
check("the green arrow on what would be an upgrade for you, only there", f.marks.up.shown == true
    and h.marks.up.shown == false)
check("an orange dot on a slot an enchanter could enchant that has none", c.bare.shown == true
    and c.bare.opts.tip == "No enchant" and n.bare.shown == false and f.bare.shown == false)
tooltip.owner = feet
tooltip.lines = {}
state.itemTooltip(tooltip)
check("hovering the upgrade: how much, for your spec", tooltip.lines[1] and tooltip.lines[1]:find("+12% upgrade", 1, true))
tooltip.owner, tooltip.lines = head, {}
state.itemTooltip(tooltip)
check("nothing added to a slot that is not one", #tooltip.lines == 0)

local card = IP.card
check("the score card waits while their items load, never another's score", card.value.text == "...")
SCORE.target, COMPLETE.target = 41.2, true
IP.Refresh()
check("their Naowh Score once loaded, in its color, kept for their tooltip",
    card.value.text == "|cff1eff0041.2|r" and remembered[GUID_A] == 41.2)
check("yours under the bar to compare", card.you.text == "You |cff1eff0026.4|r")
card.scripts.OnEnter(card)
check("its hover card: theirs, yours and the best", tooltip.lines[2] == "Bob=|cff1eff0041.2|r"
    and tooltip.lines[3] == "You=|cff1eff0026.4|r")
check("their supporter badge plate in the model's corner", IP.plate.shown == true
    and IP.plate.title.text == "Developer" and IP.plate.guid == GUID_A)

-------------------------------------------------------------------------------
--  The Player tab: talents, gear check, guild and how you know them.
-------------------------------------------------------------------------------
local function Font(text)
    for i = #fonts, 1, -1 do
        if rawget(fonts[i], "text") == text then return fonts[i] end
    end
end
local function Shows(text) return Font(text) ~= nil end

check("the Player tab shown, no switch without Player History", IP.bodies.player.shown ~= false
    and IP.bodies.history.shown == false and IP.switch.visible == false)
check("their talents: points per tree, their lead tree and its role", Shows("5/20/0") and Shows("Fury") and Shows("Damage"))
check("named when their points follow one of Naowh's builds", Shows("Naowh's Fury build"))
check("their gear: item level, unenchanted and empty slots",
    Shows("Item level") and Shows("23") and Shows("Unenchanted") and Shows("Empty slots") and Shows("11")
    and not Shows("Upgrades for you"))
check("their guild and rank, and how you know them", Shows("Naowh") and Shows("Officer") and Shows("Friend"))
check("no note section without Player History", Font("NOTE").parent.shown == false)

-------------------------------------------------------------------------------
--  Their BiS: asked of their Naowh Forever, kept only from them, for them, while shown.
-------------------------------------------------------------------------------
local pending = Test.pending
check("asked by whisper as their inspect was ready: their GUID, then yours", sent[1]
    and sent[1].prefix == "NaowhInspect" and sent[1].channel == "WHISPER" and sent[1].target == "Bob Smith"
    and sent[1].message == "1 Q " .. GUID_A .. " " .. GUID_ME and state.prefix == "NaowhInspect")
local ANSWER = "1 A " .. GUID_A .. " 1:101:1,5:200:2"
Message(ANSWER, "Eve-Evil")
check("an answer from anyone else: dropped, the ask still out", h.marks.rank.text == "" and pending.guid == GUID_A)
Message("1 A " .. GUID_B .. " 1:101:1", "Bob-Smith")
check("an answer naming another GUID: dropped", h.marks.rank.text == "" and pending.guid == GUID_A)
Message(ANSWER, "Bob-Smith")
local star1, star2 = h.marks.rank.text, c.marks.rank.text
check("their answer: their BiS star on each item they wear from their list, by its rank", star1 ~= ""
    and star2 ~= "" and star1 ~= star2 and f.marks.rank.text == "" and pending.guid == nil)
Message("1 A " .. GUID_A .. " 1:101:3", "Bob-Smith")
check("one answer per ask: a second is dropped", h.marks.rank.text == star1)
check("the Player tab knows they run Naowh Forever", IP.RunsNaowh(GUID_A) and not IP.RunsNaowh(GUID_B))

local function AskAgain()
    state.now = state.now + 11
    IP.Refresh()
end
local count = #sent
IP.Refresh()
check("not asked again within ASK_GAP", #sent == count)
local BAD = {
    "4:101:1",                     -- the shirt is no gear slot
    "99:101:1",
    "1:10a:1",
    "1:2147483648:1",
    "1:101:1,1:101:2",             -- the same slot twice
    "1:101:1,",
    "1:101:0",
    "1:101:1;5:200:2",
    "1:101:1,5:200:2,8:300:1,2:102:1,3:1:1,6:1:1,7:1:1,9:1:1,10:1:1,11:1:1,12:1:1,13:1:1,14:1:1,15:1:1,"
        .. "16:500:1,17:1:1,18:1:1,1:1:1",
    ("1:101:1,"):rep(40) .. "5:200:1",
}
for i, body in ipairs(BAD) do
    AskAgain()
    check("asked again after ASK_GAP (" .. i .. ")", pending.guid == GUID_A)
    Message("1 A " .. GUID_A .. " " .. body, "Bob Smith")
    check("a malformed answer dropped whole (" .. i .. ")", h.marks.rank.text == star1 and c.marks.rank.text == star2)
end
AskAgain()
Message("1 A " .. GUID_A .. " 1:101:3", "Bob Smith")
check("a good answer replaces theirs, from \"First Surname\" too", h.marks.rank.text ~= star1
    and c.marks.rank.text == "")
AskAgain()
A.items[1] = 111
Update(head)
check("a star only on the item they still wear in that slot", h.marks.rank.text == "")
A.items[1] = 101
state.now = state.now + 11
pending.guid = nil
AskAgain()
frame.shown, frame.unit = false, nil
frame.hooks.OnHide(frame)
Message("1 A " .. GUID_A .. " 1:101:1", "Bob-Smith")
check("an answer after the window closed: dropped", pending.guid == nil)
frame.shown, frame.unit = true, "target"
frame.hooks.OnShow(frame)
check("their stars kept from their last good answer", h.marks.rank.text ~= star1 and h.marks.rank.text ~= "")
local late = #sent
state.now = state.now + 11
IP.Refresh()
check("asked again", #sent == late + 1)
pending.at = state.now - 11
Message("1 A " .. GUID_A .. " 1:101:1", "Bob-Smith")
check("an answer later than ANSWER_WAIT: dropped", pending.guid == nil and h.marks.rank.text ~= star1)

-------------------------------------------------------------------------------
--  A stale INSPECT_READY: another player's inspect data is never read as theirs.
-------------------------------------------------------------------------------
events.scripts.OnEvent(events, "INSPECT_READY", GUID_B)
CURRENCY[2].currencyInfos[1].spent = 1
SCORE.target = 5
A.items[5] = nil
events.scripts.OnEvent(events, "UNIT_INVENTORY_CHANGED", "target")
check("INSPECT_READY for another GUID: their talents, gear check and score not read again", Shows("5/20/0")
    and Shows("11") and card.value.text == "|cff1eff0041.2|r")
events.scripts.OnEvent(events, "INSPECT_READY", GUID_A)
check("theirs again: read again", Shows("5/1/0") and Shows("12")
    and card.value.text == "|cff1eff005|r")
CURRENCY[2].currencyInfos[1].spent = 20
SCORE.target = 41.2
A.items[5] = 200
events.scripts.OnEvent(events, "INSPECT_READY", GUID_A)

-------------------------------------------------------------------------------
--  Another player: B, who does not run Naowh Forever and never answers.
-------------------------------------------------------------------------------
frame.shown, frame.unit = false, nil
frame.hooks.OnHide(frame)
Target(B)
COMPLETE.target = false
frame.shown, frame.unit = true, "target"
frame.hooks.OnShow(frame)
for _, button in ipairs(slots) do Update(button) end
check("B's card: \"...\" while their items load, never A's score", card.value.text == "...")
check("B asked too; with no answer, no stars", sent[#sent].message:find(GUID_B, 1, true)
    and h.marks.rank.text == "" and c.marks.rank.text == "")
check("no badge plate for B, who has none", IP.plate.shown == false)
Message(ANSWER, "Bob-Smith")
check("A's answer arriving while B shows: dropped", h.marks.rank.text == "")
COMPLETE.target, SCORE.target = true, 12
IP.Refresh()
check("B's own score once loaded", card.value.text == "|cff1eff0012|r")
B.faction = "Horde"
local horde = #sent
state.now = state.now + 11
IP.Refresh()
check("the other faction is never whispered", #sent == horde)
B.faction = "Alliance"
frame.shown, frame.unit = false, nil
frame.hooks.OnHide(frame)
Target(A)
COMPLETE.target, SCORE.target = true, 41.2
frame.shown, frame.unit = true, "target"
frame.hooks.OnShow(frame)

-------------------------------------------------------------------------------
--  Player History: with a record, the History tab; your note and tag on them.
-------------------------------------------------------------------------------
local DAY = 86400
local REC = {
    name = "Bob Smith", classFile = "WARRIOR", firstSeen = state.clock - 30 * DAY, lastSeen = state.clock - 3 * DAY,
    groups = 4, dungeons = 2, raids = 1,
    sessions = {
        { at = state.clock - 3 * DAY, seconds = 2520, kind = "party", place = "Wailing Caverns", instance = "party" },
        { at = state.clock - 5 * DAY, seconds = 30, kind = "raid" },
    },
    chats = {
        { at = state.clock - 3 * DAY, mine = false, channel = "WHISPER", text = "|cffff0000inv|r %s %d" },
        { at = state.clock - 3 * DAY, mine = true, channel = "PARTY", text = "omw" },
    },
}
local history = { on = true, rec = REC }
local TAGS = { { key = "tank", label = "Great Tank", color = "accent" },
    { key = "avoid", label = "Avoid", color = { r = 1, g = 0, b = 0 } } }
ns.PlayerHistory = {
    NOTE_MAX = 120,
    On = function() return history.on end,
    Of = function(guid) return guid == GUID_A and history.rec or nil end,
    Note = function(guid) return notes[guid] end,
    SetNote = function(guid, text, tag, name)
        notes.last = { guid = guid, text = text, tag = tag, name = name }
        notes[guid] = (text or tag) and { text = text, tag = tag, at = state.clock } or nil
    end,
    TAGS = TAGS,
}
notes[GUID_A] = { text = "Solid |Tbad:0|t tank", tag = "tank", at = state.clock }
IP.Refresh()
check("with Player History on: the switch, on the Player tab", IP.switch.visible == true
    and IP.bodies.player.shown ~= false)
check("how you know them now counts your groups", Shows("Friend, Grouped 4 times"))
check("your tag on them, and your note as plain text", Shows("Great Tank")
    and Shows("Solid ||Tbad:0||t tank") and Font("NOTE").parent.shown == true)
IP.switch.onPick("history")
check("the History tab", IP.bodies.history.shown == true and IP.bodies.player.shown == false)
check("a line of how often you grouped and when you last saw them",
    Shows("Grouped 4 times: 2 dungeons, 1 raid. Last seen 3 days ago."))
check("your last groups: where, how long, how long ago", Shows("Wailing Caverns, 42 min") and Shows("Raid, under a minute")
    and Shows("3 days ago") and Shows("5 days ago"))
check("the last lines said, by whom, as plain text never as a format", Shows("||cffff0000inv||r %s %d")
    and Shows("omw") and Shows("You") and Shows("whisper, 3 days ago"))
history.rec = nil
IP.Refresh()
check("on, with no record: a short line only", Shows("No history with them yet."))
history.on = false
IP.Refresh()
check("History off: no tab to switch to, the Player tab back", IP.switch.visible == false
    and IP.bodies.player.shown ~= false and IP.bodies.history.shown == false)
check("and notes still work with it off", Shows("Great Tank"))
history.on, history.rec = true, REC

-- Editing: the Note link asks for the text; the Tag link's menu sets the tag or clears the note.
local function Link(text)
    local label = Font(text)
    return label and label.parent
end
Link("Note").scripts.OnClick(Link("Note"))
local prompt = prompts[#prompts]
check("the Note link: a prompt with your note so far", prompt and prompt.title == "Your note on Bob Smith"
    and prompt.text == "Solid |Tbad:0|t tank")
check("the note box takes only as much as Player History keeps", prompt.max == 120)
prompt.accept("Great healer too")
check("saved for their GUID, the tag kept", notes.last.guid == GUID_A and notes.last.text == "Great healer too"
    and notes.last.tag == "tank" and notes.last.name == "Bob Smith" and Shows("Great healer too"))
Link("Tag").scripts.OnClick(Link("Tag"))
local radios, buttons = {}, {}
local root = {
    CreateTitle = NOTHING, CreateDivider = NOTHING,
    CreateRadio = function(_, label, isSelected, setSelected, data)
        radios[#radios + 1] = { label = label, isSelected = isSelected, set = setSelected, data = data }
    end,
    CreateButton = function(_, label, fn) buttons[label] = fn end,
}
menus[#menus].fn(nil, root)
check("the Tag menu: each tag, No tag, the one set picked", #radios == 3 and radios[1].label == "Great Tank"
    and radios[1].isSelected(radios[1].data) and not radios[2].isSelected(radios[2].data)
    and radios[3].label == "No tag" and buttons["Clear note"] ~= nil)
radios[2].set(radios[2].data)
check("picking a tag keeps the note", notes.last.tag == "avoid" and notes.last.text == "Great healer too"
    and Shows("Avoid"))
buttons["Clear note"]()
check("Clear note clears both", notes.last.text == nil and notes.last.tag == nil and notes[GUID_A] == nil
    and Shows("No note on them"))

-------------------------------------------------------------------------------
--  No garbage: a slot's update, a refresh, an answer read.
-------------------------------------------------------------------------------
notes[GUID_A] = { text = "ok", tag = "tank", at = state.clock }
IP.Refresh()
Measure(check)("every slot updated", 1, function()
    for i = 1, #slots do Update(slots[i]) end
end)

Measure(check)("a refresh of every part", 2, function() IP.Refresh() end)
Measure(check)("an answer read", 1, function()
    pending.guid, pending.unit, pending.at = GUID_A, "target", state.now
    Message(ANSWER, "Bob-Smith")
end)
Measure(check)("another addon's whisper passed over", 0.05, function()
    Test.OnMessage(nil, "CHAT_MSG_ADDON", "OtherAddon", "1 Q x y", "WHISPER", "Eve-Evil")
end)

-------------------------------------------------------------------------------
--  Missing APIs: nothing breaks, what cannot be known says so.
-------------------------------------------------------------------------------
local saved = { C_Traits = env.C_Traits, GetGuildInfo = env.GetGuildInfo, C_FriendList = env.C_FriendList,
    builds = ns.TrainingBuilds, level = env.C_PaperDollInfo.GetInspectItemLevel, history = ns.PlayerHistory }
env.C_Traits, env.GetGuildInfo, env.C_FriendList, ns.TrainingBuilds = nil, nil, nil, nil
env.C_PaperDollInfo.GetInspectItemLevel, ns.PlayerHistory = nil, nil
IP.Refresh()
check("no talent API: \"Not shown\"; no guild API: no guild; no link known", Shows("Not shown")
    and Shows("No guild") and not Shows("Not a friend or guildmate"))
check("no Player History: no switch, no note section", IP.switch.visible == false and Font("NOTE").parent.shown == false)
env.C_Traits, env.GetGuildInfo, env.C_FriendList = saved.C_Traits, saved.GetGuildInfo, saved.C_FriendList
ns.TrainingBuilds, env.C_PaperDollInfo.GetInspectItemLevel = saved.builds, saved.level
state.talentsReady = false
IP.Refresh()
check("no valid inspect talent data: \"Not shown\"", Shows("Not shown"))
state.talentsReady = nil
IP.Refresh()
check("no Naowh build matched without the Training Planner's data: just the points", Shows("5/20/0"))

-------------------------------------------------------------------------------
--  Answering: Share Your BiS.
-------------------------------------------------------------------------------
frame.shown, frame.unit = false, nil
frame.hooks.OnHide(frame)
state.myBis = { [101] = 1 }
local listener
for _, f2 in ipairs(created) do
    if f2.scripts.OnEvent == Test.OnMessage then listener = f2 end
end
S.Set("inspectPanelShareBis", true)
check("Share Your BiS on: addon whispers listened to", listener.events.CHAT_MSG_ADDON == true)
local ASKER = "Player-1-00000ACE"
local function Asked(from) Message("1 Q " .. GUID_ME .. " " .. ASKER, from or "Asker-One") end
local answers = #sent
Asked()
local reply = sent[#sent]
check("an ask for you answered: your GUID and your list's items you wear, by whisper to the asker",
    #sent == answers + 1 and reply.target == "Asker-One" and reply.channel == "WHISPER"
    and reply.message == "1 A " .. GUID_ME .. " 1:101:1")
check("nothing of theirs sent back", not reply.message:find(ASKER, 1, true))
Asked()
check("the same asker again at once: not answered", #sent == answers + 1)
state.now = state.now + 3
Asked()
check("after ANSWER_GAP: answered again", #sent == answers + 2)
Message("1 Q " .. GUID_B .. " " .. ASKER, "Other-One")
check("an ask for someone else: not answered", #sent == answers + 2)
Message("1 Q " .. GUID_ME .. " " .. ASKER, "Party-One", "PARTY")
check("not over a whisper: not answered", #sent == answers + 2)
state.myBis = nil
Asked("Plain-One")
check("no item on your list: \"-\"", sent[#sent].message == "1 A " .. GUID_ME .. " -")
state.myBis = { [101] = 1 }
state.now = state.now + 10
local burst = #sent
for i = 1, 15 do Asked("Asker-" .. i) end
check("at most ANSWERS_MAX in a window, however many ask", #sent == burst + 10)
state.now = state.now + 20
for _, fn in ipairs(timers) do fn() end
check("an ask with no answer expires", pending.guid == nil)
S.Set("inspectPanelShareBis", false)
local off = #sent
Asked("Late-One")
check("Share Your BiS off: never answered, and not listened to", #sent == off and not listener.events.CHAT_MSG_ADDON)

-------------------------------------------------------------------------------
--  EllesmereUI's inspect sheet: ours stands down, the game's look and width back for it.
-------------------------------------------------------------------------------
env.EllesmereUI = { GetBlizzWindowStyle = function(key) return key == "inspect" and "eui" or "off" end }
S.Set("inspectPanel", true)
check("EllesmereUI styles the inspect window: Naowh's stands down", not IP.On() and frame.w == 338
    and frame.NineSlice.alpha == 1 and head.normal.alpha == 1 and h.shown == false and IP.pane.shown == false)
check("its tabs' frames over the whole window again, the inset its own width",
    env.InspectPaperDollFrame.points.all == frame and frame.Inset.right == -6)
local painted = h.marks.level.text
A.items[1] = 111
Update(head)
check("and the game's updates paint nothing of ours", h.marks.level.text == painted)
A.items[1] = 101
env.EllesmereUI = { GetBlizzWindowStyle = function() return "off" end }
S.Set("inspectPanel", true)
check("its sheet off: Naowh's on again", IP.On() and frame.w == 338 + 233 and head.normal.alpha == 0
    and h.shown == true)

-- Turned off with an ask still out: their answer paints nothing over the game's slots.
Target(A)
frame.shown, frame.unit = true, "target"
state.now = state.now + 11
frame.hooks.OnShow(frame)
check("an ask out as it is turned off", pending.guid == GUID_A)
S.Set("inspectPanel", false)
Message("1 A " .. GUID_A .. " 1:101:1", "Bob-Smith")
check("off: their answer still comes, and paints none of ours over the game's slots", h.shown == false
    and pending.guid == nil)

-------------------------------------------------------------------------------
--  Off: the game's art, width and fonts back; ours hidden.
-------------------------------------------------------------------------------
S.Set("inspectPanel", false)
check("off: the window its own width, its art back, ours hidden", frame.w == 338 and frame.NineSlice.alpha == 1
    and frame.Bg.alpha == 1 and head.normal.alpha == 1 and head.icon.crop == 0 and h.shown == false
    and IP.pane.shown == false and not events.events.INSPECT_READY)
Update(head)
check("and the game's updates paint nothing of ours", h.shown == false)

-------------------------------------------------------------------------------
--  The switch swaps EllesmereUI's inspect sheet for ours, and back, as the character panel's.
-------------------------------------------------------------------------------
local db = {}
env.EllesmereUIDB = db
env.EllesmereUI = { GetBlizzWindowStyle = function(key)
    if key ~= "inspect" then return "off" end
    return db.themedInspectSheet == false and "off" or "eui"
end }
state.reloads = 0
S.Set("inspectPanel", true)
check("on: EllesmereUI's inspect sheet off, a reload offered, ours on", db.themedInspectSheet == false
    and state.reloads == 1 and IP.On())
S.Set("inspectPanel", false)
check("off: EllesmereUI's back on, a reload offered", db.themedInspectSheet == true and state.reloads == 2)
db.themedInspectSheet = false
S.Set("inspectPanel", true)
S.Set("inspectPanel", false)
check("turned off in EllesmereUI's own options: left off, no reload asked", db.themedInspectSheet == false
    and state.reloads == 2)
check("the character panel's sheet left alone", db.themedCharacterSheet == nil)
env.EllesmereUIDB, env.EllesmereUI = nil, nil

-------------------------------------------------------------------------------
--  The settings card: with ns.FEATURE_BADGES 0, no Supporter Badge row.
-------------------------------------------------------------------------------
local function Card(flag)
    local cards = {}
    local store = { Get = function(key) return key ~= "inspectPanelBadge" or flag == 1 end }
    local flagNs = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        FEATURE_BADGES = flag, BADGES_LIVE = 1, QoLSettings = store,
        InspectPanel = { EllesmereSheet = function() return false end },
        Shared = { Settings = { Page = function()
            return { Card = function(_, def) cards[def.id] = def end }
        end } },
    }
    Load({ "NaowhForever_BiS/InspectPanel/UI/SettingsPage.lua" }, setmetatable({ _G = { NaowhForever = flagNs } },
        { __index = _G }))
    return cards.inspectPanel, store
end
local offCard, offStore = Card(0)
check("flag 0: no badge row, the score row first", offCard.rows[1].key == "inspectPanelScore"
    and #offCard.rows == 2 and offCard.summary(offStore) == "With their Naowh Score")
local onCard, onStore = Card(1)
check("flag 1: the badge row first; Share Your BiS works with the card off", onCard.rows[1].key == "inspectPanelBadge"
    and onCard.rows[3].key == "inspectPanelShareBis" and onCard.rows[3].always == true
    and onCard.summary(onStore) == "With their badge and Naowh Score" and onCard.switch == "inspectPanel")
for _, row in ipairs(onCard.rows) do
    check(row.label .. "'s help is one short sentence", #row.help < 100 and not row.help:find("%. "))
end

print(("test-inspect-panel: %d checks passed"):format(checks))

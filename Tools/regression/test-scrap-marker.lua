-- Run with Lua 5.1 from the repository root: the QoL Scrap Marker and its Scrap List, loaded
-- from the Shared files and the two QoL files against stubs of the game's bags, EllesmereUI's,
-- gear sets and a vendor. Checks: off and hooking nothing by default; a plain Alt-click marks
-- and unmarks by item ID, other clicks do nothing, and quest items, keys, items with no sell
-- price, your BiS and gear sets are refused; marks for the account or one character (by GUID);
-- the rules (gear you can't wear, old common gear) and the keep list; Baganator's bags (nothing
-- until it loads, then one corner widget and junk plugin, the Alt-click and the mark on its live
-- buttons only, read at the click, and a refresh asked on each change); the vendor selling a few
-- at a time only while it is open and out of combat, rereading each slot, keeping protected
-- items and stopping when it closes; Ask First's panel and Nothing; the card's summary; the
-- API Bag Space reads; the Scrap List window (built on first open, its rows, X, scope tag,
-- search, drop, Clear All, Export and Import, live updates); and no garbage per bag update,
-- sale step or list redraw.
local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Measure = dofile("Tools/regression/measure.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

-------------------------------------------------------------------------------
--  Stubs: a frame keeps its parent, points, scripts, hooks, events and shown state; every other
--  method is one shared do-nothing function, so the stubs make no garbage of their own.
-------------------------------------------------------------------------------
local NOTHING = function() end
local Frame
local made = 0
local loose = {}
local METHODS = {
    GetParent = function(f) return rawget(f, "parent") end,
    SetText = function(f, text) f.text = text end,
    GetText = function(f) return rawget(f, "text") end,
    Show = function(f) f.shown = true end,
    Hide = function(f) f.shown = false end,
    SetShown = function(f, shown) f.shown = shown and true or false end,
    IsShown = function(f) return rawget(f, "shown") ~= false end,
    IsVisible = function(f) return rawget(f, "shown") ~= false end,
    IsMouseOver = function() return false end,
    SetAlpha = function(f, alpha) f.alpha = alpha end,
    GetFrameLevel = function() return 1 end,
    GetHeight = function() return 37 end,
    GetWidth = function() return 400 end,
    GetRight = function() return 500 end,
    GetScale = function() return 1 end,
    GetEffectiveScale = function() return 1 end,
    GetStringWidth = function() return 40 end,
    GetStringHeight = function() return 12 end,
    SetPoint = function(f, point, relative) f.points[point] = relative end,
    ClearAllPoints = function(f) for k in pairs(f.points) do f.points[k] = nil end end,
    CreateTexture = function(f)
        local texture = Frame(f)
        f.made = texture
        return texture
    end,
    CreateFontString = function(f) return Frame(f) end,
    SetTexture = function(f, texture) f.texture = texture end,
    SetAtlas = function(f, atlas)
        f.atlas = atlas
        if rawget(f, "parent") then f.parent.made = atlas end
    end,
    SetScript = function(f, name, fn) f.scripts[name] = fn end,
    HookScript = function(f, name, fn)
        f.hooks[name] = f.hooks[name] and error("hooked twice: " .. name) or fn
    end,
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
    return setmetatable({ parent = parent, points = {}, scripts = {}, hooks = {}, events = {} }, META)
end

local WHITE = { r = 1, g = 1, b = 1 }

-- itemID -> name, class, subclass, equip slot, quality, required level, vendor price
local ITEMS = {
    [201] = { "Linen Cloth", 7, 0, "", 1, 0, 13 },
    [202] = { "Quest Letter", 12, 0, "", 1, 0, 1 },
    [203] = { "Cellar Key", 13, 0, "", 1, 0, 5 },
    [204] = { "Hearthstone", 15, 0, "", 1, 0, 0 },
    [205] = { "Green Belt", 4, 2, "INVTYPE_WAIST", 2, 20, 50 },
    [206] = { "Wolf Fang", 15, 0, "", 0, 0, 20 },
    [207] = { "Apprentice Wand", 2, 19, "INVTYPE_RANGEDRIGHT", 2, 15, 30 },
    [208] = { "Worn Shortsword", 2, 7, "INVTYPE_WEAPON", 1, 5, 10 },
    [209] = { "Plate Helm", 4, 4, "INVTYPE_HEAD", 3, 28, 100 },
    [210] = { "Mail Boots", 4, 3, "INVTYPE_FEET", 2, 25, 80 },
    [211] = { "Rare Ring", 4, 0, "INVTYPE_FINGER", 3, 30, 20000 },
    [212] = { "Silver Bar", 7, 0, "", 2, 0, 15000 },
    [213] = { "Copper Ore", 7, 0, "", 1, 0, 1 },
    [214] = { "Broken Fang", 15, 0, "", 0, 0, 3 },
}
local LINKS = {}
for id, item in pairs(ITEMS) do LINKS[id] = "[" .. item[1] .. "]" end
local QUALITY = { [0] = { hex = "|cff9d9d9d", r = 0.6, g = 0.6, b = 0.6 }, [1] = WHITE,
    [2] = { hex = "|cff1eff00", r = 0.1, g = 1, b = 0 }, [3] = { hex = "|cff0070dd", r = 0, g = 0.4, b = 0.9 } }

local DEFAULTS = { enabled = true, scrapMarker = false, scrapMarkerVendor = "sell", scrapMarkerScope = "account",
    scrapMarkerShow = true, scrapMarkerProtect = true, scrapRuleWear = false, scrapRuleOld = false,
    scrapRuleLevels = 10 }
local state = {
    values = {}, listeners = {}, overlays = {}, refreshed = 0, account = {}, printed = {}, postCalls = 0,
    sold = {}, combat = false, ctrl = false, shift = false, alt = false, guid = "Player-1-0001",
    bags = { [0] = {}, [1] = {} }, size = { [0] = 30, [1] = 8 }, locked = {}, refreshPage = 0,
    bis = {}, setIDs = { 1 }, setItems = {}, level = 30, loaded = { EllesmereUIBags = true },
}
for k, v in pairs(DEFAULTS) do state.values[k] = v end

-- The slot's info, one table per slot reused as the real API's return would be read.
local infos = {}
local function Info(bag, slot)
    local id = state.bags[bag][slot]
    if not id then return nil end
    local key = bag * 100 + slot
    local t = infos[key] or {}
    infos[key] = t
    t.itemID, t.stackCount, t.isLocked = id, 2, state.locked[key] == true
    t.hasNoValue = ITEMS[id][7] == 0
    return t
end
local function Count(id)
    local n = 0
    for _, bag in pairs(state.bags) do
        for _, held in pairs(bag) do
            if held == id then n = n + 2 end
        end
    end
    return n
end

-- The game's bag: its item buttons, each with its bag and slot, enumerated as the game does.
local function ItemButton(bag, slot)
    local button = Frame()
    button.bag, button.slot = bag, slot
    button.GetBagID = function(self) return self.bag end
    button.GetID = function(self) return self.slot end
    return button
end
local function Next(frame, i)
    i = i + 1
    local button = frame.items[i]
    if button then return i, button end
end
local bagFrame = Frame()
bagFrame.items = {}
for slot = 1, 30 do bagFrame.items[slot] = ItemButton(0, slot) end
bagFrame.EnumerateValidItems = function(self) return Next, self, 0 end
bagFrame.UpdateItems = NOTHING

local S = {
    Get = function(key) return state.values[key] end,
    Set = function(key, value)
        state.values[key] = value
        for _, fn in ipairs(state.listeners) do fn(key, value) end
    end,
    OnChange = function(fn) state.listeners[#state.listeners + 1] = fn end,
}

local buttons = {}
local function Button(parent, text, _, _, onClick)
    local button = Frame(parent)
    button.text, button.onClick = text, onClick
    buttons[text] = button
    return button
end
local searchBox

local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    QoLConstants = dofile("Tools/regression/qol_constants.lua"),
    THEME = setmetatable({}, { __index = function() return WHITE end }),
    Color = function(_, text) return text and tostring(text) or "" end,
    Font = function(parent) return Frame(parent) end,
    Solid = function(parent) return Frame(parent) end,
    Border = function() return { SetColor = NOTHING } end,
    AllowOffscreen = NOTHING,
    AccentBorder = function(b) return b end,
    Hairline = function(region) return region end,
    UIFontPath = function() return "font" end,
    UIScale = function() return 1 end,
    PixelInset = function(region) return region end,
    Button = Button,
    NewSearchBox = function(parent, _, onSearch)
        local box = Frame(parent)
        box.hint, box.onSearch, box.border = Frame(box), onSearch, { SetColor = NOTHING }
        searchBox = box
        return box
    end,
    UI = { Keep = NOTHING, RefreshPage = function() state.refreshPage = state.refreshPage + 1 end,
        SlimScroll = function(parent) return Frame(parent) end, CloseOnEscape = NOTHING },
    QoLSettings = S,
    Apply = NOTHING,
    AccountSettings = function() return state.account end,
    Print = function(msg) state.printed[#state.printed + 1] = msg end,
    Confirm = function(text, onYes) state.asked = text; if state.answer ~= false then onYes() end end,
    ShowCopyLine = function(_, text) state.copied = text end,
    PromptText = function(_, _, _, onAccept) onAccept(state.paste) end,
    IsBisItem = function(id) return state.bis[id] end,
}

local EUI = {
    RegisterItemOverlayIcon = function(name, fn) state.overlays[name] = fn end,
    UnregisterItemOverlayIcon = function(name) state.overlays[name] = nil end,
    RefreshInventory = function() state.refreshed = state.refreshed + 1 end,
    IsVisible = function() return true end,
}

local BAGANATOR = { widgets = {}, junk = {}, refreshes = 0 }
BAGANATOR.API = {
    RegisterCornerWidget = function(label, id, onUpdate, onInit, defaultPosition, isFast)
        assert(not BAGANATOR.widgets[id], "corner widget registered twice")
        BAGANATOR.widgets[id] = { label = label, onUpdate = onUpdate, onInit = onInit, corner = defaultPosition,
            isFast = isFast }
    end,
    RegisterJunkPlugin = function(label, id, callback) BAGANATOR.junk[id] = { label = label, callback = callback } end,
    RequestItemButtonsRefresh = function() BAGANATOR.refreshes = BAGANATOR.refreshes + 1 end,
}

local timers = {}
local hooksOnBag = 0
local uiParent = Frame()
local merchant = Frame(uiParent)
merchant.shown = false
local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function(_, _, parent)
        local f = Frame(parent)
        if parent then
            local children = rawget(parent, "children") or {}
            parent.children = children
            children[#children + 1] = f
        else
            loose[#loose + 1] = f
        end
        return f
    end,
    hooksecurefunc = function(a, b, c)
        if a == bagFrame then hooksOnBag = hooksOnBag + 1 end
        local original = a[b]
        a[b] = function(...) original(...); c(...) end
    end,
    Mixin = function(object, ...)
        for i = 1, select("#", ...) do
            for k, v in pairs((select(i, ...))) do object[k] = v end
        end
        return object
    end,
    C_Item = {
        GetItemInfoInstant = function(id)
            local item = ITEMS[id]
            if not item then return nil end
            return id, nil, nil, item[4], nil, item[2], item[3]
        end,
        GetItemInfo = function(id)
            local item = ITEMS[id]
            return item[1], LINKS[id], item[5], item[6], item[6], nil, nil, 20, nil, nil, item[7]
        end,
        GetItemQualityByID = function(id) return ITEMS[id] and ITEMS[id][5] end,
        GetItemNameByID = function(id) return ITEMS[id] and ITEMS[id][1] end,
        GetItemIconByID = function(id) return id end,
        GetItemCount = Count,
        IsItemDataCachedByID = function() return true end,
    },
    C_Container = {
        GetContainerItemID = function(bag, slot) return state.bags[bag][slot] end,
        GetContainerItemLink = function(bag, slot) return LINKS[state.bags[bag][slot]] end,
        GetContainerItemInfo = Info,
        GetContainerNumSlots = function(bag) return state.size[bag] end,
        UseContainerItem = function(bag, slot)
            if state.keep then return end
            state.sold[#state.sold + 1] = state.bags[bag][slot]
            state.bags[bag][slot] = nil
        end,
    },
    C_EquipmentSet = {
        GetEquipmentSetIDs = function() return state.setIDs end,
        GetItemIDs = function() return state.setItems end,
    },
    C_CurrencyInfo = { GetCoinTextureString = function(copper) return copper .. "c" end },
    C_AddOns = { IsAddOnLoaded = function(name) return state.loaded[name] == true end },
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end },
    TooltipDataProcessor = { AddTooltipPostCall = function(_, fn)
        state.postCalls = state.postCalls + 1
        state.tooltip = fn
    end },
    Enum = { TooltipDataType = { Item = 0 } },
    Menu = { GetManager = function() return { IsAnyMenuOpen = function() return false end } end },
    MerchantFrame = merchant,
    InCombatLockdown = function() return state.combat end,
    IsControlKeyDown = function() return state.ctrl end,
    IsShiftKeyDown = function() return state.shift end,
    IsAltKeyDown = function() return state.alt end,
    GetCursorInfo = function() if state.cursor then return "item", state.cursor, LINKS[state.cursor] end end,
    ClearCursor = function() state.cursor = nil end,
    UnitGUID = function() return state.guid end,
    UnitClass = function() return "Warrior", "WARRIOR" end,
    UnitLevel = function() return state.level end,
    BACKPACK_CONTAINER = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS = 1,
    EUI_Bags = EUI,
    Baganator = BAGANATOR,
    ContainerFrameContainer = { ContainerFrames = { bagFrame } },
    ITEM_QUALITY_COLORS = QUALITY,
    GameTooltip = Frame(),
    UIParent = uiParent,
    CreateColor = function() return Frame() end,
    GetTime = function() return 0 end,
}, { __index = _G })
env._G = env
env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
env.GameTooltip.GetOwner = function() return nil end

local files = TocFiles("^Shared/.*%.lua$")
check("the Shared bag helper loads with Shared", #TocFiles("^Shared/Game/Bags%.lua$") == 1)
check("the TOC loads the Scrap Marker and its list", #TocFiles("^NaowhForever_QoL/Loot/ScrapMarker%.lua$") == 1
    and #TocFiles("^NaowhForever_QoL/Loot/ScrapList%.lua$") == 1)
-- The copy cards are stubbed, so their Shared file is left out.
for i = #files, 1, -1 do
    if files[i] == "Shared/UI/CopyCard.lua" then table.remove(files, i) end
end
files[#files + 1] = "NaowhForever_QoL/Loot/ScrapMarker.lua"
files[#files + 1] = "NaowhForever_QoL/Loot/ScrapList.lua"
local before = made
Load(files, env)
check("nothing made at load", made == before and #loose == 0)
local Scrap = ns.ScrapMarker

-- The views and side panels made, as they are made.
local views, panels = {}, {}
local NewView, NewPanel = ns.Shared.View.New, ns.Shared.Parts.SidePanel
ns.Shared.View.New = function(...)
    local view = NewView(...)
    views[#views + 1] = view
    return view
end
ns.Shared.Parts.SidePanel = function(...)
    local panel = NewPanel(...)
    panels[#panels + 1] = panel
    return panel
end

local function wipe(t) for k in pairs(t) do t[k] = nil end return t end
local function Fire(event)
    for _, f in ipairs(loose) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event) end
    end
end
local function Registered(event)
    for _, f in ipairs(loose) do
        if f.events[event] then return true end
    end
    return false
end
local function Click(button, mouse, ctrl, shift, alt)
    state.ctrl, state.shift, state.alt = ctrl == true, shift == true, alt == true
    local hook = button.hooks.OnClick
    if hook then hook(button, mouse) end
    state.ctrl, state.shift, state.alt = false, false, false
end
local function Alt(button) Click(button, "LeftButton", false, false, true) end
local function Mark(button) return button.children and button.children[1] end
local function Printed() return state.printed[#state.printed] end
local due = {}
local function RunTimers()
    local n = #timers
    for i = 1, n do due[i] = timers[i] end
    wipe(timers)
    for i = 1, n do
        local fn = due[i]
        due[i] = nil
        fn()
    end
end
local function Set(key, value) S.Set(key, value) end

-------------------------------------------------------------------------------
--  Off by default: nothing hooked, registered or made.
-------------------------------------------------------------------------------
state.bags[0] = { 201, 202, 203, 204, 205, 206, nil, 201 }
before = made
ns.Apply()
check("off by default: the game's bags not hooked, EllesmereUI's hook not taken", bagFrame.UpdateItems == NOTHING
    and next(state.overlays) == nil)
check("off by default: no tooltip hook, no frames, no events", state.postCalls == 0 and made == before
    and #loose == 0)
check("off: Bag Space is told nothing is scrap", Scrap.IsScrap(201) == false)

-------------------------------------------------------------------------------
--  On: marking with a plain Alt-click
-------------------------------------------------------------------------------
Set("scrapMarker", true)
check("on: the game's bags hooked, EllesmereUI's hook taken, the tooltip hooked once",
    bagFrame.UpdateItems ~= NOTHING and state.overlays.NaowhForeverScrap ~= nil and state.postCalls == 1)
check("on: listens for the vendor, combat and gear sets", Registered("MERCHANT_SHOW") and Registered("MERCHANT_CLOSED")
    and Registered("PLAYER_REGEN_DISABLED") and Registered("EQUIPMENT_SETS_CHANGED"))
check("on: no level-up listener without the Old Common Gear rule", not Registered("PLAYER_LEVEL_UP"))
bagFrame:UpdateItems()
local cloth, quest, key, stone, belt, fang = bagFrame.items[1], bagFrame.items[2], bagFrame.items[3],
    bagFrame.items[4], bagFrame.items[5], bagFrame.items[6]
check("a click hook on each bag button, post-hooked, never a script set",
    cloth.hooks.OnClick ~= nil and next(cloth.scripts) == nil and cloth.hooks.OnMouseUp == nil)
check("nothing marked yet: no icons made", Mark(cloth) == nil and Mark(bagFrame.items[8]) == nil)

local printed = #state.printed
Click(cloth, "LeftButton")
Click(cloth, "RightButton")
Click(cloth, "MiddleButton")
check("plain left, right and middle clicks do nothing", state.account.scrapItems == nil and #state.printed == printed)
Click(cloth, "LeftButton", true)
check("Ctrl-click alone does not mark (it is the game's dressing room)", state.account.scrapItems == nil)
Click(cloth, "LeftButton", true, false, true)
Click(cloth, "LeftButton", false, true, true)
check("Ctrl-Alt and Shift-Alt clicks do not mark", state.account.scrapItems == nil and #state.printed == printed)
Click(cloth, "RightButton", false, false, true)
check("Alt with the right button does not mark", state.account.scrapItems == nil)
state.cursor = 205
Alt(cloth)
state.cursor = nil
check("holding an item on the cursor: no mark", state.account.scrapItems == nil)

Alt(cloth)
check("Alt-click marks the item by its ID, for the account", state.account.scrapItems[201] == true
    and Printed():find("marked as scrap", 1, true) ~= nil)
check("every copy shows the scrap icon, on its own frame over the slot", Mark(cloth).shown == true
    and Mark(bagFrame.items[8]).shown == true and Mark(cloth).parent == cloth)
check("the icon in the top-right corner, the game's scrap art", Mark(cloth).points.TOPRIGHT ~= nil
    and Mark(cloth).made == ns.Shared.Style.SCRAP_ATLAS and Mark(cloth).alpha == 1)
check("the settings page told to redraw", state.refreshPage > 0)

local tip = { lines = {}, AddLine = function(self, text) self.lines[#self.lines + 1] = text end }
state.tooltip(tip, { id = 201 })
state.tooltip(tip, { id = 205 })
check("a marked item's tooltip says it sells at the next vendor; others say nothing",
    #tip.lines == 1 and tip.lines[1] == "Scrap: sold at the next vendor")

Alt(cloth)
check("Alt-click again unmarks it", state.account.scrapItems[201] == nil and Mark(cloth).shown == false
    and Mark(bagFrame.items[8]).shown == false and Printed():find("no longer scrap", 1, true) ~= nil)

for _, button in ipairs({ quest, key, stone }) do Alt(button) end
check("quest items, keys and items with no sell price are refused, each with why",
    next(state.account.scrapItems) == nil and state.printed[#state.printed - 2]:find("quest item", 1, true)
    and state.printed[#state.printed - 1]:find("key", 1, true) and Printed():find("no sell price", 1, true))

-- Protected: your BiS and your gear sets.
state.bags[0][9], state.bags[0][10] = 209, 210
bagFrame:UpdateItems()
state.bis[209], state.setItems[1] = true, 210
Fire("EQUIPMENT_SETS_CHANGED")
Alt(bagFrame.items[9])
check("your BiS is refused, saying so", state.account.scrapItems[209] == nil and Printed():find("BiS", 1, true))
Alt(bagFrame.items[10])
check("an item in a gear set is refused, saying so", state.account.scrapItems[210] == nil
    and Printed():find("gear set", 1, true))
Set("scrapMarkerProtect", false)
Alt(bagFrame.items[10])
check("Protect BiS and Gear Sets off: a gear set's item can be marked", state.account.scrapItems[210] == true)
Alt(bagFrame.items[10])
Set("scrapMarkerProtect", true)
state.bags[0][9], state.bags[0][10] = nil, nil

-- A button first painted in combat is hooked only once combat is over.
local late = ItemButton(0, 30)
bagFrame.items[30] = late
state.combat = true
bagFrame:UpdateItems()
check("no hook added in combat", late.hooks.OnClick == nil)
state.combat = false
bagFrame:UpdateItems()
check("hooked on the next paint out of combat", late.hooks.OnClick ~= nil)
bagFrame.items[30] = nil

-------------------------------------------------------------------------------
--  EllesmereUI's bags
-------------------------------------------------------------------------------
local paint = state.overlays.NaowhForeverScrap
local function EllesmereButton()
    local button = Frame()
    button._textOverlay = Frame(button)
    return button
end
local eCloth, eEmpty = EllesmereButton(), EllesmereButton()
local data = { bag = 0, slot = 8, info = { itemID = 201 }, itemLink = LINKS[201] }
paint(eCloth, data)
paint(eEmpty, { bag = 0, slot = 0 })
check("its slots take the click hook; its placeholder slots get nothing", eCloth.hooks.OnClick ~= nil
    and eEmpty.hooks.OnClick == nil and Mark(eEmpty._textOverlay) == nil)
local refreshed = state.refreshed
Alt(eCloth)
paint(eCloth, data)
check("Alt-click in its bags marks the slot it painted, and repaints them", state.account.scrapItems[201] == true
    and state.refreshed > refreshed)
check("the icon on the frame it gives other addons' marks", Mark(eCloth._textOverlay)
    and Mark(eCloth._textOverlay).shown == true)
Alt(fang)
check("a second item marked", state.account.scrapItems[206] == true)

-------------------------------------------------------------------------------
--  Baganator's bags
-------------------------------------------------------------------------------
check("Baganator not loaded: nothing registered, no refresh asked, after marking",
    next(BAGANATOR.widgets) == nil and next(BAGANATOR.junk) == nil and BAGANATOR.refreshes == 0)
state.loaded.Baganator = true
ns.Apply()
ns.Apply()
local widget, junk = BAGANATOR.widgets.NaowhForeverScrap, BAGANATOR.junk.NaowhForeverScrap
check("loaded: one corner widget, top right, fast, and one junk plugin, under one name", widget
    and junk and widget.label == "Naowh Forever Scrap" and junk.label == widget.label
    and widget.corner.corner == "top_right" and widget.isFast == true)
local function BaganatorButton(bag, slot)
    local button = ItemButton(bag, slot)
    button.GetBagID = function(self) return self.bag end
    return button
end
state.bags[1][1] = 213
local bCloth, bOre = BaganatorButton(0, 8), BaganatorButton(1, 1)
local bClothMark, bOreMark = widget.onInit(bCloth), widget.onInit(bOre)
check("each button's mark made on init, the game's scrap art", bClothMark.made == ns.Shared.Style.SCRAP_ATLAS
    and bClothMark ~= bOreMark)
check("a marked item shows the mark, an unmarked one not", widget.onUpdate(bClothMark, { itemID = 201 }) == true
    and bClothMark.alpha == 1 and widget.onUpdate(bOreMark, { itemID = 213 }) == false)
check("both live buttons take the click hook", bCloth.hooks.OnClick ~= nil and bOre.hooks.OnClick ~= nil)
local refreshes = BAGANATOR.refreshes
Alt(bOre)
check("Alt-click on a Baganator button marks its item, and asks Baganator to refresh",
    state.account.scrapItems[213] == true and BAGANATOR.refreshes > refreshes
    and widget.onUpdate(bOreMark, { itemID = 213 }) == true)
Click(bOre, "LeftButton")
Click(bOre, "LeftButton", false, true, true)
check("plain and Shift-Alt clicks on it do nothing", state.account.scrapItems[213] == true)
Alt(bOre)
check("Alt-click again unmarks it", state.account.scrapItems[213] == nil)
bOre.bag, bOre.slot = 0, 8
Alt(bOre)
check("a pooled button moved to another slot marks what is there at the click", state.account.scrapItems[201] == nil
    and state.account.scrapItems[213] == nil)
Alt(bOre)
check("and unmarks it again", state.account.scrapItems[201] == true)
local bLate = BaganatorButton(0, 6)
local bLateMark = widget.onInit(bLate)
state.combat = true
widget.onUpdate(bLateMark, { itemID = 206 })
check("no hook added in combat", bLate.hooks.OnClick == nil)
state.combat = false
widget.onUpdate(bLateMark, { itemID = 206 })
check("hooked on its next paint out of combat", bLate.hooks.OnClick ~= nil)
local bOther = ItemButton(0, 8)
bOther.GetBagID = function() return nil end
local bOtherMark = widget.onInit(bOther)
check("another character's bags: no mark, no click hook", widget.onUpdate(bOtherMark, { itemID = 201 }) == false
    and bOther.hooks.OnClick == nil)
check("junk: scrap and grey items with a price, nothing else", junk.callback(0, 8, 201) == true
    and junk.callback(0, 1, 214) == true and junk.callback(0, 5, 205) == false and junk.callback(0, 4, 204) == false)
state.bags[1][1] = nil

-------------------------------------------------------------------------------
--  Show Mark off
-------------------------------------------------------------------------------
Set("scrapMarkerShow", false)
paint(eCloth, data)
check("Show Mark off: the icons hide", Mark(cloth).shown == false and Mark(eCloth._textOverlay).shown == false
    and widget.onUpdate(bClothMark, { itemID = 201 }) == false)
Alt(belt)
check("marking still works without the icon", state.account.scrapItems[205] == true and Mark(belt) == nil)
Alt(belt)
Set("scrapMarkerShow", true)
check("Show Mark on again: the icons back", Mark(cloth).shown == true)

-------------------------------------------------------------------------------
--  This character only, by GUID
-------------------------------------------------------------------------------
Set("scrapMarkerScope", "char")
Alt(belt)
check("New Marks on This Character: kept under this character's GUID, not the account",
    state.account.scrapChars[state.guid][205] == true and state.account.scrapItems[205] == nil
    and Scrap.Scope(205) == "char")
Scrap.SwitchScope(205)
check("switched to the account", state.account.scrapItems[205] == true and state.account.scrapChars[state.guid][205] == nil)
Scrap.SwitchScope(205)
check("and back to this character", Scrap.Scope(205) == "char")
state.account.scrapChars["Player-1-0002"] = { [208] = true }
check("another character's marks (same first name or not) don't count here", Scrap.IsScrap(208) == false)
Alt(belt)
check("Alt-click unmarks a character mark too", Scrap.Scope(205) == nil)
Set("scrapMarkerScope", "account")

-------------------------------------------------------------------------------
--  Rules
-------------------------------------------------------------------------------
state.bags[0][11], state.bags[0][12] = 207, 208
bagFrame:UpdateItems()
local wand, sword = bagFrame.items[11], bagFrame.items[12]
check("rules off by default: a wand is not scrap for a warrior", Scrap.IsScrap(207) == false and Mark(wand) == nil)
Set("scrapRuleWear", true)
check("Gear You Can't Wear: a warrior's wand is scrap, not stored", Scrap.IsScrap(207) == true
    and state.account.scrapItems[207] == nil)
check("its icon dimmed, to tell it from a mark", Mark(wand).shown == true and Mark(wand).alpha < 1)
check("gear a warrior can wear is not picked", Scrap.IsScrap(205) == false and Scrap.IsScrap(208) == false)
state.bis[207] = true
check("a protected item never matches a rule", Scrap.IsScrap(207) == false)
state.bis[207] = nil
Set("scrapRuleOld", true)
check("Old Common Gear: a white sword 25 levels below you is scrap, and level-ups are listened for",
    Scrap.IsScrap(208) == true and Registered("PLAYER_LEVEL_UP") and Mark(sword).shown == true)
Set("scrapRuleLevels", 30)
check("not when it is within Levels Below You", Scrap.IsScrap(208) == false)
Set("scrapRuleLevels", 10)
check("green gear is never old common gear", Scrap.RuleMatch(205) == nil)
Alt(wand)
check("Alt-click on a rule's item keeps it: the rule skips it after", Scrap.IsScrap(207) == false
    and state.account.scrapKeep[207] == true and Mark(wand).shown == false)
Alt(wand)
check("Alt-click again marks it, and it leaves the keep list", state.account.scrapItems[207] == true
    and state.account.scrapKeep[207] == nil)
Alt(wand)
state.account.scrapKeep[207] = nil
Set("scrapRuleWear", false)
Set("scrapRuleOld", false)
state.bags[0][11], state.bags[0][12] = nil, nil

-------------------------------------------------------------------------------
--  Selling
-------------------------------------------------------------------------------
merchant.shown = true
state.bags[0] = { 201, 202, 203, 204, 205, 206, nil, 201 }
state.bags[1] = { 201, 206, 205, 201 }
check("nothing sells away from a vendor", #timers == 0 and #state.sold == 0)
Fire("MERCHANT_SHOW")
check("the first batch waits a moment for the vendor's window", #timers == 1 and #state.sold == 0)
RunTimers()
check("a batch of six marked items sold, across both bags", #state.sold == 6 and #timers == 1)
for _, id in ipairs(state.sold) do check("only marked items sold", id == 201 or id == 206) end
RunTimers()
check("nothing left: it stops", #state.sold == 6 and #timers == 0)
check("one line of what it sold", Printed() == "Sold 6 scrap items for 184c.")
check("unmarked and unsellable items stay", state.bags[0][2] == 202 and state.bags[0][5] == 205
    and state.bags[1][3] == 205)

local function Refill()
    state.bags[0] = { 201, 201, 201, 201, 201, 201, 201, 201, 201, 201 }
    state.bags[1] = { 206, 206 }
end

-- Each slot is read again right before its sale, and a locked one is skipped.
wipe(state.sold)
Refill()
state.locked[2] = true
Fire("MERCHANT_SHOW")
RunTimers()
state.bags[0][9], state.bags[0][10] = 205, nil
RunTimers()
check("a locked slot skipped, a slot changed between batches reread", #state.sold == 9
    and state.bags[0][2] == 201 and state.bags[0][9] == 205)
state.locked[2] = nil

-- A marked item protected since: kept, and said so.
wipe(state.sold)
Refill()
state.setItems[1] = 206
Fire("EQUIPMENT_SETS_CHANGED")
Fire("MERCHANT_SHOW")
RunTimers()
RunTimers()
check("a marked item now in a gear set is kept, and the line says so", #state.sold == 10
    and state.bags[1][1] == 206 and Printed() == "Sold 10 scrap items for 260c. Kept 2 protected.")
state.setItems[1] = nil
Fire("EQUIPMENT_SETS_CHANGED")

-- The vendor closes mid-way: the sale stops at once, and says what it sold.
wipe(state.sold)
Refill()
Fire("MERCHANT_SHOW")
RunTimers()
Fire("MERCHANT_CLOSED")
check("closing the vendor says what was sold", Printed() == "Sold 6 scrap items for 156c.")
RunTimers()
check("and nothing more sells", #state.sold == 6 and #timers == 0)

-- The vendor's window gone without the event: the next sale checks it and stops.
wipe(state.sold)
Refill()
Fire("MERCHANT_SHOW")
merchant.shown = false
RunTimers()
check("no sale while the vendor's window is not shown", #state.sold == 0)
merchant.shown = true

-- Combat: nothing sells, and combat starting mid-way stops it.
Fire("MERCHANT_SHOW")
state.combat = true
RunTimers()
check("no sale in combat", #state.sold == 0)
state.combat = false
Fire("MERCHANT_SHOW")
RunTimers()
Fire("PLAYER_REGEN_DISABLED")
RunTimers()
check("combat starting stops the sale", #state.sold == 6 and #timers == 0)

-- Opened again while waiting: one start, never two.
wipe(state.sold)
Refill()
Fire("MERCHANT_SHOW")
Fire("MERCHANT_CLOSED")
Fire("MERCHANT_SHOW")
check("a reopened vendor waits once", #timers == 1)
RunTimers()
check("a reopened vendor runs one step, not one per opening", #state.sold == 6)
RunTimers()
check("then the rest", #state.sold == 12)

-------------------------------------------------------------------------------
--  At the Vendor: Ask First, then Nothing
-------------------------------------------------------------------------------
Set("scrapMarkerVendor", "ask")
wipe(state.sold)
Refill()
Fire("MERCHANT_SHOW")
RunTimers()
local ask = panels[1]
check("Ask First: nothing sold, a panel docked to the vendor's window", #state.sold == 0 and ask and ask.shown ~= false
    and (ask.points.TOPLEFT == merchant or ask.points.TOPRIGHT == merchant))
check("its title asks, with the total", ask.title.text == "Sell your scrap for 340c?")
local askView = ask.view
check("a row per item about to go, with its count and value", askView.pools.item.used == 2
    and askView.pools.item[1].meta.text == "x20" and askView.pools.item[1].value.text == "260c"
    and askView.pools.item[1].remove.shown == false)
check("Ask First's tooltip line says offered", (function()
    wipe(tip.lines)
    state.tooltip(tip, { id = 201 })
    return tip.lines[1] == "Scrap: offered at the next vendor"
end)())
ask.buttons["Not Now"].onClick()
check("Not Now closes it, selling nothing", ask.shown == false and #state.sold == 0)
Scrap.ShowAsk()
ask.buttons.Sell.onClick()
RunTimers()
check("Sell closes it and sells through the guarded loop", ask.shown == false and #state.sold == 12)
Refill()
Fire("MERCHANT_SHOW")
RunTimers()
Fire("MERCHANT_CLOSED")
check("the panel closes with the vendor", ask.shown == false)

Set("scrapMarkerVendor", "none")
wipe(state.sold)
Refill()
check("Nothing: no vendor events", not Registered("MERCHANT_SHOW"))
Fire("MERCHANT_SHOW")
RunTimers()
check("Nothing: nothing sold, the marks kept", #state.sold == 0 and state.account.scrapItems[201] == true)
wipe(tip.lines)
state.tooltip(tip, { id = 201 })
check("the tooltip says Scrap only", tip.lines[1] == "Scrap")
Set("scrapMarkerVendor", "sell")
merchant.shown = false
Fire("MERCHANT_CLOSED")

-------------------------------------------------------------------------------
--  The settings card
-------------------------------------------------------------------------------
local card = ns.Shared.Settings.CardOf("QoL/Loot & Items:scrapMarker")
check("a Scrap Marker card on QoL > Loot & Items, switched by scrapMarker", card and card.switch == "scrapMarker")
check("its summary counts the marks and what your scrap is worth", card.summary() == "2 items marked, 340c in your bags")
for _, row in ipairs(card.rows) do
    if row.kind ~= "group" then
        check("each help one short sentence: " .. tostring(row.label), row.help and #row.help < 100
            and not row.help:find("%. %u"))
        check("each key has a default: " .. tostring(row.key), row.key == nil or DEFAULTS[row.key] ~= nil)
    end
end
check("the card's help one short sentence", #card.help < 100)
local page = ns.Shared.Settings.pages["QoL/Loot & Items"]
local windowCard
for _, item in ipairs(page.items) do
    if item.window and item.text == "Open Scrap List" then windowCard = item end
end
check("an Open Scrap List card on the page", windowCard ~= nil)

-------------------------------------------------------------------------------
--  The Scrap List window
-------------------------------------------------------------------------------
check("the window is not built before it opens", #views == 1)
state.bags[0] = { 201, 205, 207, 209 }
state.bags[1] = { 206 }
state.bis[209] = true
Set("scrapRuleWear", true)
Scrap.Mark(204)
state.account.scrapItems[210] = true
windowCard.open()
local list = views[2]
check("built on first open", list ~= nil)
local function Rows()
    local out = {}
    for i = 1, list.pools.item.used do out[i] = list.pools.item[i] end
    return out
end
local function Ids()
    local out = {}
    for i, row in ipairs(Rows()) do out[i] = row.itemID end
    return table.concat(out, ",")
end
check("rows: the marks and the rule's matches you carry; carried first, then by name", Ids() == "207,201,206,210")
local rows = Rows()
check("a mark's row: what you carry and its value, Account, an X", rows[2].meta.text == "2 in your bags"
    and rows[2].value.text == "26c" and rows[2].tag.text.text == "Account" and rows[2].remove.shown == true)
check("a rule's row: the Rule tag (not a link) and why", rows[1].tag.text.text == "Rule" and rows[1].onTag == nil
    and rows[1].meta.text:find("Can't wear", 1, true))
check("one not in your bags says so, with no value", rows[4].meta.text == "Not in your bags" and rows[4].value.text == "")
check("its name in its quality color", rows[3].name.text == "Wolf Fang")

rows[2].onTag(201)
RunTimers()
check("the tag switches a mark to this character", Scrap.Scope(201) == "char"
    and Rows()[2].tag.text.text == "Character")
Scrap.SwitchScope(201)
RunTimers()

-- Live: an Alt-click while it is open redraws it once.
local queued = #timers
Alt(bagFrame.items[2])
check("Alt-click while open: one redraw queued", #timers == queued + 1)
RunTimers()
check("and the row is there", Ids():find("205", 1, true) ~= nil)

Rows()[1].onRemove(207)
RunTimers()
check("X on a rule's row keeps it", state.account.scrapKeep[207] == true and not Ids():find("207", 1, true))
state.account.scrapKeep[207] = nil
local x = Rows()
for _, row in ipairs(x) do
    if row.itemID == 206 then row.onRemove(206) end
end
RunTimers()
check("X on a mark's row unmarks it", state.account.scrapItems[206] == nil and not Ids():find("206", 1, true))

-- Search.
local box = searchBox
box.onSearch("CLO")
check("search filters by name", Ids() == "201")
box.onSearch("nothing like it")
check("no match: a line says so", list.pools.item.used == 0 and list.pools.note.used == 1
    and list.pools.note[1].text.text == "No scrap item matches your search.")
box.onSearch("")

-- A drop marks it, with the same refusals as Alt-click.
state.cursor = 206
list.onDrop()
RunTimers()
check("an item dropped on the list is marked, and goes back to its bag", state.account.scrapItems[206] == true
    and state.cursor == nil)
state.cursor = 202
list.onDrop()
check("a quest item dropped is refused", state.account.scrapItems[202] == nil and Printed():find("quest item", 1, true))
state.cursor = 204
Scrap.Unscrap(204)
list.onDrop()
check("an item with no sell price dropped is refused", state.account.scrapItems[204] == nil)

-- Export and Import.
local exportButton
for _, child in ipairs(rawget(views[2].parent.parent, "children")) do
    if child.tip == "Export this list" then exportButton = child end
    if child.tip == "Import a list" then state.importButton = child end
end
exportButton.scripts.OnClick()
check("Export: a versioned plain string of the marked IDs", state.copied == "NFSCRAP:1:201,205,206,210")
check("Import refuses what isn't a Scrap List", Scrap.Parse("NFSCRAP:2:201") == nil and Scrap.Parse("hello") == nil
    and Scrap.Parse("NFSCRAP:1:201;DROP") == nil)
local parsed = Scrap.Parse("NFSCRAP:1:208, 208,201")
check("Import reads numbers only, once each", #parsed == 2 and parsed[1] == 208 and parsed[2] == 201)
local long = {}
for i = 1, 600 do long[i] = i end
check("Import stops at 500 items", #Scrap.Parse("NFSCRAP:1:" .. table.concat(long, ",")) == 500)
state.paste, state.answer = "NFSCRAP:1:208,201,202,99999", false
state.importButton.scripts.OnClick()
check("Import asks first, counting only what is new and allowed, by name",
    state.asked == "Add 1 item to your scrap list: |cffffffffWorn Shortsword|r?" and state.account.scrapItems[208] == nil)
state.answer = nil
state.importButton.scripts.OnClick()
check("yes: merged in, nothing replaced", state.account.scrapItems[208] == true and state.account.scrapItems[201] == true)
state.paste, state.answer = "NFSCRAP:1:213,212,208,207,211", false
state.importButton.scripts.OnClick()
check("Import names the best first, by quality, and warns about what is worth keeping", state.asked
    == "Add 4 items to your scrap list: |cff0070ddRare Ring|r, |cff1eff00Apprentice Wand|r, |cff1eff00Silver Bar|r"
    .. " and 1 more?|n|cfffb923c1 of these is Rare or better, and 2 sell for 1g or more.|r" and state.account.scrapItems[211] == nil)
state.paste = "NFSCRAP:1:207"
state.importButton.scripts.OnClick()
check("one Uncommon item is called out too", state.asked
    == "Add 1 item to your scrap list: |cff1eff00Apprentice Wand|r?|n|cfffb923c1 of these is Uncommon.|r")
state.answer = nil

-- Clear All, after asking.
RunTimers()
local clear = buttons["Clear All"]
state.answer = false
clear.onClick()
check("Clear All asks first", state.asked == "Unmark every item marked as scrap?" and state.account.scrapItems ~= nil)
state.answer = nil
clear.onClick()
Set("scrapRuleWear", false)
RunTimers()
check("then clears every mark, and the list says how to mark", state.account.scrapItems == nil
    and list.pools.item.used == 0 and list.pools.note[1].text.text
    == "Nothing marked. Alt-click an item in your bags to mark it.")
state.bis[209] = nil

-------------------------------------------------------------------------------
--  The shared bag helper: one hook per bag frame, each module's painter run
-------------------------------------------------------------------------------
local other = 0
ns.Shared.Bags.OnGameUpdate(function() other = other + 1 end)
bagFrame:UpdateItems()
check("a second painter runs on the same hook, the frame hooked once", other == 1 and hooksOnBag == 1)

-------------------------------------------------------------------------------
--  Cost: a bag update, a sale step and a list redraw
-------------------------------------------------------------------------------
state.bags[0] = {}
for slot = 1, 29 do state.bags[0][slot] = slot % 2 == 0 and 201 or 205 end
state.bags[1] = { 207, 208, 206 }
Set("scrapRuleWear", true)
bagFrame:UpdateItems()
local marked = bagFrame.items[2]
Alt(marked)
Alt(bagFrame.items[1])
check("marked again for the cost runs", state.account.scrapItems[201] == true and Mark(marked).shown == true)
Measure(check)("a bag of 30 painted", 1, function() bagFrame:UpdateItems() end)
Measure(check)("an EllesmereUI slot painted", 1, function() paint(eCloth, data) end)
local bDetails = { itemID = 201 }
Measure(check)("a Baganator slot painted", 1, function() widget.onUpdate(bClothMark, bDetails) end)
merchant.shown = true
state.keep = true
while #timers > 0 do RunTimers() end
local stepped = #state.printed
Measure(check)("a sale step of six", 1, function()
    wipe(timers)
    Fire("MERCHANT_SHOW")
    local offer = timers[1]
    wipe(timers)
    offer()
end)
check("each run sold a step and did not finish", #state.printed == stepped)
state.keep = false
wipe(timers)
list:Redraw()
local pooled = #list.pools.item
Measure(check)("the Scrap List redrawn", 2, function() list:Redraw() end)
check("its rows pooled: no new row on a redraw", #list.pools.item == pooled and list.pools.item.used == 3)

-------------------------------------------------------------------------------
--  Off again: everything inert
-------------------------------------------------------------------------------
Fire("MERCHANT_CLOSED")
merchant.shown = false
refreshed = state.refreshed
refreshes = BAGANATOR.refreshes
wipe(state.sold)
Set("scrapMarker", false)
check("off: icons hide, EllesmereUI's hook let go, no events", Mark(marked).shown == false
    and state.overlays.NaowhForeverScrap == nil and not Registered("MERCHANT_SHOW")
    and not Registered("EQUIPMENT_SETS_CHANGED"))
check("off: Bag Space is told nothing is scrap", Scrap.IsScrap(201) == false)
check("off: Baganator refreshed, its marks hidden, only greys junk", BAGANATOR.refreshes > refreshes
    and widget.onUpdate(bClothMark, { itemID = 201 }) == false and junk.callback(0, 8, 201) == false
    and junk.callback(0, 1, 214) == true)
Alt(bCloth)
check("off: Alt-click on a Baganator button does nothing", state.account.scrapItems[201] == true)
Alt(marked)
wipe(tip.lines)
state.tooltip(tip, { id = 201 })
check("off: Alt-click and the tooltip do nothing", state.account.scrapItems[201] == true and #tip.lines == 0)
bagFrame:UpdateItems()
check("off: a bag update paints nothing", Mark(marked).shown == false)
Set("scrapMarker", true)
check("on again: EllesmereUI's hook taken again, its bags repainted, the icons back",
    state.overlays.NaowhForeverScrap ~= nil and state.refreshed > refreshed and Mark(marked).shown == true)

print(("test-scrap-marker: %d checks passed"):format(checks))

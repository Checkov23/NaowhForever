-- Run with Lua 5.1 from the repository root: Bag Marks, the BiS List's slot marks on the items
-- in your bags, loaded from the Shared files and NaowhForever_BiS/BiS/View/Bags.lua against stubs of the game's
-- bags and EllesmereUI's. Checks that it is off and hooks nothing by default; on, gear shows its
-- item level, your BiS its star, what is new in Forever its mark and an upgrade its arrow, in the game's bags and in
-- EllesmereUI's (where ours stand in for its item level and make room for its BoE word and
-- Pawn's arrow); a new list paints the stars again; off again, ours hide and EllesmereUI's item
-- level comes back; and painting a bag makes no garbage.
local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")
local Measure = dofile("Tools/regression/measure.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

-------------------------------------------------------------------------------
--  Stubs: a frame keeps its parent, points, text, alpha and shown state; every other method
--  is one shared do-nothing function, so the stubs make no garbage of their own.
-------------------------------------------------------------------------------
local NOTHING = function() end
local Frame
local made = 0
local METHODS = {
    GetParent = function(f) return rawget(f, "parent") end,
    SetText = function(f, text) f.text = text end,
    SetTextColor = function(f, r, g, b) f.cr, f.cg, f.cb = r, g, b end,
    GetText = function(f) return rawget(f, "text") end,
    Show = function(f) f.shown = true end,
    Hide = function(f) f.shown = false end,
    SetShown = function(f, shown) f.shown = shown and true or false end,
    IsShown = function(f) return rawget(f, "shown") ~= false end,
    SetAlpha = function(f, alpha) f.alpha = alpha end,
    GetFrameLevel = function() return 1 end,
    GetHeight = function() return 37 end,
    SetPoint = function(f, point, relative) f.points[point] = relative end,
    ClearAllPoints = function(f) for k in pairs(f.points) do f.points[k] = nil end end,
    CreateTexture = function(f) return Frame(f) end,
    CreateFontString = function(f) return Frame(f) end,
}
local META = { __index = function(_, key)
    if METHODS[key] then return METHODS[key] end
    if type(key) == "string" and key:find("^%u") then return NOTHING end
end }
function Frame(parent)
    made = made + 1
    return setmetatable({ parent = parent, points = {} }, META)
end

local WHITE = { r = 1, g = 1, b = 1 }
local state = { bags = {}, values = {}, listeners = {}, lists = {}, overlays = {}, refreshed = 0 }

-- Items: 101 a helm, your BiS and new in Forever; 102 a chest, on no list; 500 a potion.
local GEAR = { [101] = "INVTYPE_HEAD", [102] = "INVTYPE_CHEST" }
local LEVELS = { link1 = 30, link2 = 25, link3 = 1 }
local RANK = { [101] = 1 }

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
state.values = { enabled = true, bis = true, bisBagMarks = false }

local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    THEME = setmetatable({}, { __index = function() return WHITE end }),
    Color = function(_, text) return tostring(text) end,
    Font = function(parent) return Frame(parent) end,
    Solid = function(parent) return Frame(parent) end,
    Border = function() return { SetColor = NOTHING } end,
    Hairline = function(region) return region end,
    UIFontPath = function() return "font" end,
    PixelInset = function(region) return region end,
    UI = { Keep = NOTHING },
    QoLSettings = S,
    Apply = NOTHING,
    IsBisItem = function(id) return RANK[id] end,
}
-- Stat Weights: the chest is an upgrade by your spec's weights (its own test weighs them).
local WEIGHTS = { agi = 1 }
ns.StatWeights = {
    ActiveSpec = function() return "assassination-rogue" end,
    For = function() return WEIGHTS end,
    Power = function() state.powerReads = (state.powerReads or 0) + 1; return 100 end,
    BestGain = function(id, _, weights, power)
        return weights == WEIGHTS and power == 100 and state.upgrades[id] or nil
    end,
}
state.upgrades = { [102] = 4 }
ns.BiS = {
    On = function() return state.values.bis end,
    OnListChange = function(fn) state.lists[#state.lists + 1] = fn end,
}

-- EllesmereUI's bags: the hook it offers, and a refresh that repaints through it.
local EUI = {
    RegisterItemOverlayIcon = function(name, fn) state.overlays[name] = fn end,
    UnregisterItemOverlayIcon = function(name) state.overlays[name] = nil end,
    RefreshInventory = function() state.refreshed = state.refreshed + 1 end,
    IsVisible = function() return true end,
}

local env = setmetatable({
    NaowhForever = ns,
    CreateFrame = function(_, _, parent)
        local f = Frame(parent)
        if parent then
            local children = rawget(parent, "children") or {}
            parent.children = children
            children[#children + 1] = f
        end
        return f
    end,
    hooksecurefunc = function(a, b, c)
        local original = a[b]
        a[b] = function(...) original(...); c(...) end
    end,
    C_Item = {
        GetItemInfoInstant = function(id) return id, nil, nil, GEAR[id] end,
        GetDetailedItemLevelInfo = function(link) return LEVELS[link] end,
        GetItemQualityByID = function() return state.quality or 4 end,
        GetItemNameByID = function(id) return "item " .. id end,
        GetItemCount = function() return 0 end,
        IsItemDataCachedByID = function() return true end,
    },
    C_Container = {
        GetContainerItemID = function(_, slot) return state.bags[slot] end,
        GetContainerItemLink = function(_, slot) return state.bags[slot] and ("link" .. slot) end,
    },
    C_AddOns = { IsAddOnLoaded = function(name) return name == "EllesmereUIBags" and state.eui == true end },
    EUI_Bags = EUI,
    ContainerFrameContainer = { ContainerFrames = { bagFrame } },
    ITEM_QUALITY_COLORS = { [4] = { hex = "|cffa335ee", r = 0.64, g = 0.21, b = 0.93 } },
    GameTooltip = Frame(),
    UIParent = Frame(),
    CreateColor = function() return {} end,
    GetTime = function() return state.now or 0 end,
}, { __index = _G })
env._G = env
env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

local files = TocFiles("^Shared/.*%.lua$")
files[#files + 1] = "NaowhForever_BiS/BiS/Constants.lua"
files[#files + 1] = "NaowhForever_BiS/BiS/View/Bags.lua"
check("the TOC loads the bag marks", #TocFiles("^NaowhForever_BiS/BiS/View/Bags%.lua$") == 1)
Load(files, env)
ns.Shared.ForeverNew.items[101] = true

-------------------------------------------------------------------------------
--  Off by default: nothing hooked, nothing made.
-------------------------------------------------------------------------------
state.eui = true
state.bags = { [1] = 101, [2] = 102, [3] = 500 }
local before = made
ns.Apply()
check("off by default: the game's bags not hooked, EllesmereUI's hook not taken, nothing made",
    bagFrame.UpdateItems == NOTHING and next(state.overlays) == nil and made == before)

-------------------------------------------------------------------------------
--  On: the game's bags
-------------------------------------------------------------------------------
S.Set("bisBagMarks", true)
check("on: the game's bags hooked, EllesmereUI's hook taken", bagFrame.UpdateItems ~= NOTHING
    and state.overlays.NaowhForever ~= nil)
bagFrame:UpdateItems()
-- Ours: the frame the module made over a button (the only frame it makes there).
local function SetOn(over) return over.children and over.children[1] end
local helm, chest, potion, empty = SetOn(bagFrame.items[1]), SetOn(bagFrame.items[2]), SetOn(bagFrame.items[3]),
    SetOn(bagFrame.items[4])
check("marks on each item, none made for an empty slot", helm and chest and potion and empty == nil
    and helm.parent == bagFrame.items[1])
check("gear shows its item level; a potion none", helm.level.text == 30 and chest.level.text == 25
    and potion.level.text == "")
check("your BiS's star on it, nothing on what is not on your list", helm.rank.text ~= ""
    and chest.rank.text == "" and potion.rank.text == "")
check("Forever's mark on what is new in Forever, only there", helm.forever.shown == true
    and chest.forever.shown == false)
check("the shade behind a number or a star only", helm.shade.shown == true and potion.shade.shown == false)
check("the upgrade arrow on gear better than what you wear, BiS or not; none on the rest",
    chest.up.shown == true and helm.up.shown == false and potion.up.shown == false)
check("your gear's worth read once a frame, not once a slot", state.powerReads == 1)
state.now = 1
state.bags[1] = nil
bagFrame:UpdateItems()
check("a slot emptied: its marks hide", helm.shown == false)
state.bags[1] = 101
bagFrame:UpdateItems()

-- A new list: the stars again.
RANK[102] = 2
for _, fn in ipairs(state.lists) do fn() end
check("a new list paints the stars again", chest.rank.text ~= "")
RANK[102] = nil

-------------------------------------------------------------------------------
--  EllesmereUI's bags
-------------------------------------------------------------------------------
local function EllesmereButton()
    local button = Frame()
    button._textOverlay, button.ItemLevelText, button.BindTypeText = Frame(button), Frame(button), Frame(button)
    button.UpgradeIcon = Frame(button)
    button.UpgradeIcon.shown = false
    return button
end
local paint = state.overlays.NaowhForever
local eHelm, ePotion, eEmpty = EllesmereButton(), EllesmereButton(), EllesmereButton()
local data = { info = { itemID = 101 }, itemLink = "link1" }
paint(eHelm, data)
local mark = SetOn(eHelm._textOverlay)
check("over EllesmereUI's slot, on the frame it gives other addons' marks", mark and mark.parent == eHelm._textOverlay)
check("ours stand in for its item level", mark.level.text == 30 and eHelm.ItemLevelText.alpha == 0)
paint(ePotion, { info = { itemID = 500 }, itemLink = "link3" })
check("where ours shows no level, its own is left alone", ePotion.ItemLevelText.alpha == 1)
paint(eEmpty, { bag = 0, slot = 0 })
check("its empty and placeholder slots: nothing made", SetOn(eEmpty._textOverlay) == nil)
eHelm.BindTypeText.text = "BoE"
eHelm.UpgradeIcon.shown = true
paint(eHelm, data)
check("its BoE word puts our star after it, Pawn's arrow our level before it",
    mark.rank.points.LEFT == eHelm.BindTypeText and mark.level.points.RIGHT == eHelm.UpgradeIcon)
eHelm.BindTypeText.text = ""
eHelm.UpgradeIcon.shown = false
paint(eHelm, data)
check("without them, the corners of every slot of ours", mark.rank.points.BOTTOMLEFT ~= nil
    and mark.level.points.BOTTOMRIGHT ~= nil and mark.rank.points.LEFT == nil)
S.Set("bisBagLevels", false)
bagFrame:UpdateItems()
paint(eHelm, data)
check("an old profile's Item Level in Bags off is ignored: Bag Marks keeps the level, in both bags",
    helm.level.text == 30 and mark.level.text == 30 and eHelm.ItemLevelText.alpha == 0)
check("the level in its quality's color, never a stack count's white", helm.level.cr == 0.64
    and helm.level.cb == 0.93)
state.quality = 1
bagFrame:UpdateItems()
check("common gear's level in gold", helm.level.cr == 1 and helm.level.cg == 0.82 and helm.level.cb == 0)
state.quality = nil

-------------------------------------------------------------------------------
--  Cost: painting a bag of 30 slots
-------------------------------------------------------------------------------
for slot = 4, 30 do state.bags[slot] = slot % 3 == 0 and 101 or 500 end
bagFrame:UpdateItems()
Measure(check)("a bag of 30 painted", 1, function() bagFrame:UpdateItems() end)
Measure(check)("an EllesmereUI slot painted", 1, function() paint(eHelm, data) end)

-------------------------------------------------------------------------------
--  Off again
-------------------------------------------------------------------------------
local refreshed = state.refreshed
S.Set("bisBagMarks", false)
check("off: ours hide, EllesmereUI's item level back, its hook let go", helm.shown == false and mark.shown == false
    and eHelm.ItemLevelText.alpha == 1 and state.overlays.NaowhForever == nil and state.refreshed == refreshed)
bagFrame:UpdateItems()
check("and the game's bag updates paint nothing of ours", helm.shown == false)
S.Set("bisBagMarks", true)
check("on again: EllesmereUI's hook taken again, its bags repainted", state.overlays.NaowhForever ~= nil
    and state.refreshed > refreshed and helm.shown == true)

print(("test-bag-marks: %d checks passed"):format(checks))

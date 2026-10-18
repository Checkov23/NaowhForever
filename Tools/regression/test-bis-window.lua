-- Run with Lua 5.1 from the repository root: the BiS List's window, paperdoll and slot
-- picker, built and drawn from the files Shared.xml and BiS.xml load, against stubs and the
-- real rankings. Checks what they show, that a click changes the list and everything
-- redraws, what a redraw costs, and that loot is only listened to while Drop Alert is on.
local Load = dofile("Tools/regression/load_files.lua")
local TocFiles = dofile("Tools/regression/toc_files.lua")

local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

-------------------------------------------------------------------------------
--  Stubs: a frame keeps its scripts, events, size, text and shown state; every other method
--  is one shared do-nothing function, so the stubs make no garbage of their own.
-------------------------------------------------------------------------------
local NOTHING = function() end
local tried = 0   -- items tried on the model
local WHITE = { r = 1, g = 1, b = 1 }
local Frame
local METHODS = {
    SetScript = function(f, script, fn) f.scripts[script] = fn end,
    GetScript = function(f, script) return f.scripts[script] end,
    HookScript = function(f, script, fn) f.hooks[script] = fn end,
    RegisterEvent = function(f, event) f.events[event] = true end,
    RegisterUnitEvent = function(f, event) f.events[event] = true end,
    UnregisterAllEvents = function(f) for event in pairs(f.events) do f.events[event] = nil end end,
    GetParent = function(f) return rawget(f, "parent") end,
    SetWidth = function(f, w) f.w = w end,
    SetHeight = function(f, h) f.h = h end,
    SetSize = function(f, w, h) f.w, f.h = w, h end,
    GetWidth = function(f) return rawget(f, "w") or 300 end,
    GetHeight = function(f) return rawget(f, "h") or 24 end,
    SetText = function(f, text) f.text = text end,
    GetText = function(f) return rawget(f, "text") or "" end,
    GetStringWidth = function() return 40 end,
    GetStringHeight = function() return 12 end,
    Show = function(f) f.shown = true end,
    Hide = function(f) f.shown = false end,
    SetShown = function(f, shown) f.shown = shown and true or false end,
    IsShown = function(f) return rawget(f, "shown") ~= false end,
    IsVisible = function(f) return rawget(f, "shown") ~= false end,
    IsMouseOver = function() return false end,
    GetFrameLevel = function() return 1 end,
    GetScale = function() return 1 end,
    GetEffectiveScale = function() return 1 end,
    GetRight = function() return 300 end,
    GetVerticalScroll = function(f) return rawget(f, "scrolled") or 0 end,
    SetVerticalScroll = function(f, y) f.scrolled = y end,
    GetVerticalScrollRange = function() return 5000 end,
    SetDesaturated = function(f, on) f.desaturated = on end,
    SetAlpha = function(f, alpha) f.alpha = alpha end,
    SetFont = function(f, path, size, flags) f.font, f.size, f.flags = path, size, flags end,
    EnableMouse = function(f, on) f.mouse = on end,
    CreateTexture = function(f) return Frame(f) end,
    TryOn = function() tried = tried + 1 end,
    CreateFontString = function(f) return Frame(f) end,
    -- Animations: groups and their steps, which play nothing here.
    CreateAnimationGroup = function(f) return Frame(f) end,
    CreateAnimation = function(f) return Frame(f) end,
}
local META = { __index = function(_, key)
    if METHODS[key] then return METHODS[key] end
    if type(key) == "string" and key:find("^%u") then return NOTHING end
end }
function Frame(parent)
    return setmetatable({ scripts = {}, hooks = {}, events = {}, parent = parent }, META)
end

-- Every ranked item goes in the slot it is ranked for.
-- What the game says of an item: a weapon is a one-handed sword, armor leather, a held item misc.
local WEAPON, ARMOR = { 2, 7 }, { 4, 2 }
local ITEM_CLASS = { INVTYPE_WEAPON = WEAPON, INVTYPE_2HWEAPON = { 2, 8 }, INVTYPE_HOLDABLE = { 4, 0 },
    INVTYPE_NECK = { 4, 0 }, INVTYPE_CLOAK = { 4, 1 } }

local INVTYPE = { [1] = "INVTYPE_HEAD", [2] = "INVTYPE_NECK", [3] = "INVTYPE_SHOULDER", [15] = "INVTYPE_CLOAK",
    [5] = "INVTYPE_CHEST", [9] = "INVTYPE_WRIST", [10] = "INVTYPE_HAND", [6] = "INVTYPE_WAIST",
    [7] = "INVTYPE_LEGS", [8] = "INVTYPE_FEET", [11] = "INVTYPE_FINGER", [12] = "INVTYPE_FINGER",
    [13] = "INVTYPE_TRINKET", [14] = "INVTYPE_TRINKET", [16] = "INVTYPE_WEAPON", [17] = "INVTYPE_HOLDABLE",
    [18] = "INVTYPE_RANGEDRIGHT" }

local function Fixture()
    local state = { account = {}, printed = {}, worn = {}, frames = {}, timers = {} }
    local values = { bis = true, bisTooltip = true, bisLootAlert = false, bisWindowAlpha = 1,
        bisAlertFor = "all", bisAlertChat = true, bisAlertBadge = true, bisToast = true,
        bisDropSound = "game:raidwarning", bisYoursSound = "game:epicloot", bisToastScale = 1, bisToastTime = 6,
        bisToastAlpha = 0.95, bisToastGlow = true, bisToastStar = "icon", bisToastBorder = "rank",
        bisToastEvent = true, bisToastRank = true, bisToastSlot = true, bisToastSource = false, bisToastGain = true,
        bisToastFont = "", bisToastFontSize = 13, bisToastOutline = "NONE" }
    local listeners = {}
    local S = {
        Get = function(key) return values[key] end,
        Set = function(key, value)
            values[key] = value
            for i = 1, #listeners do listeners[i](key, value) end
        end,
        OnChange = function(fn) listeners[#listeners + 1] = fn end,
    }
    local equip, names = {}, setmetatable({}, { __index = function(t, id)
        t[id] = "Item " .. id
        return t[id]
    end })
    local links = setmetatable({}, { __index = function(t, id)
        t[id] = "|Hitem:" .. id .. "::|h[Item]|h"
        return t[id]
    end })
    local ns = {
        THEME = setmetatable({}, { __index = function() return WHITE end }),
        QoLSettings = S,
        UI = { SlimScroll = function(parent) return Frame(parent) end, CloseOnEscape = NOTHING,
            RefreshPage = NOTHING, CONTENT_PAD = 20,
            FontPath = function(name) return name == "" and "font" or "lsm:" .. name end,
            AttachMover = function(frame) return Frame(frame) end,
            _PlayLSMSound = function(path) state.sounds = (state.sounds or 0) + 1; state.soundPath = path end,
            SoundPathFor = function(key) return "sound:" .. key end,
            -- A module's settings, in memory: its defaults until set, and who listens.
            ModuleSettings = function(_, defaults)
                local db, heard = {}, {}
                return {
                    Get = function(k) if db[k] == nil then return defaults[k] end return db[k] end,
                    Set = function(k, v)
                        db[k] = v
                        for i = 1, #heard do heard[i](k, v) end
                    end,
                    OnChange = function(fn) heard[#heard + 1] = fn end,
                    Toggle = NOTHING,
                }
            end,
            -- A slider shows its value in its box, through its _format when it has one.
            BuildSliderCore = function(parent, _, _, _, _, _, _, _, _, _, _, get, set)
                local slider = Frame(parent)
                slider.rail, slider.fill, slider.thumb = Frame(slider), Frame(slider), Frame(slider)
                slider.valueBox, slider.valueFill = Frame(parent), Frame(parent)
                slider.valueBorder = { _frame = Frame(parent) }
                slider._get, slider._set = get, set
                slider._refreshValue = function()
                    local format = rawget(slider, "_format")
                    if format then slider.valueBox:SetText(format(get())) end
                end
                return slider, slider.valueBox
            end,
            BuildToggleControl = function(parent, _, get, set)
                local toggle = Frame(parent)
                toggle._get, toggle._set, toggle._refreshValue = get, set, NOTHING
                return toggle
            end,
            ShowWidgetTooltip = function(_, text) state.tip = text end,
            HideWidgetTooltip = NOTHING },
        AccountSettings = function() return state.account end,
        Print = function(text) state.printed[#state.printed + 1] = text end,
        Color = function(_, text) return text end,
        L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        Font = function(parent) return Frame(parent) end,
        Solid = function(parent) return Frame(parent) end,
        -- As ns.Hairline and ns.PixelInset: whole-pixel sizing has no effect on these stubs.
        Hairline = function(region) return region end,
        PixelInset = function(region) return region end,
        AllowOffscreen = function() end,
        Border = function(parent)
            local edge = Frame(parent)
            edge.SetColor = function(self, r, _, _, a) self.red, self.opacity = r, a end
            edge._frame = edge
            return edge
        end,
        Button = function(parent, text, _, _, onClick)
            local button = Frame(parent)
            button.label, button.onClick = text, onClick
            return button
        end,
        AccentBorder = function(frame) return frame end,
        SetButtonText = function(button, text) button.label = text end,
        Tooltip = function(frame, title, body) frame.tipTitle, frame.tipBody = title, body end,
        StashOptionsWindow = function() state.stashed = true end,
        SoundChoices = function() return {}, { ["Naowh: Ding"] = "Ding" }, { "Naowh: Ding" } end,
        NewEditBox = function(parent) return Frame(parent) end,
        UIScale = function() return 1 end,
        UIFontPath = function() return "font" end,
        Apply = NOTHING,
        ThemeTint = function() return WHITE end,
    }
    local env = setmetatable({
        _G = { NaowhForever = ns, ITEM_MOD_AGILITY_SHORT = "Agility" },
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        issecretvalue = function() return false end,
        IsModifiedClick = function() return false end,
        UnitClass = function() return "Mage", "MAGE" end,
        UnitFactionGroup = function() return "Alliance" end,
        UnitName = function() return "Die Man" end,
        UnitLevel = function() return state.level or 60 end,
        -- Each of your five stats at 50, gear in it.
        UnitStat = function() return 50, 50 end,
        UnitAttackSpeed = function() return 2.6, 2.6 end,
        C_Secrets = { ShouldUnitStatsBeSecret = function() return false end },
        GetRealmName = function() return "Realm" end,
        GetInventoryItemID = function(_, slot) return state.worn[slot] end,
        GetInventoryItemTexture = function(_, slot) return state.worn[slot] and 134400 end,
        -- With state.enchants[slot], what you wear there has that enchant on it.
        GetInventoryItemLink = function(_, slot)
            local id = state.worn[slot]
            if not id then return nil end
            local enchant = state.enchants and state.enchants[slot]
            return enchant and "|Hitem:" .. id .. ":" .. enchant .. ":|h[Item]|h" or links[id]
        end,
        IsPlayerSpell = function(spell) return spell == state.known end,
        C_Spell = { GetSpellName = function(spell) return "Enchant " .. spell end,
            GetSpellTexture = function() return 136244 end },
        InCombatLockdown = function() return false end,
        -- Loot: a roll's item, the loot window's items and the corpse they came from, and the clock.
        GetLootRollItemLink = function() return state.roll end,
        GetNumLootItems = function() return #(state.loot or {}) end,
        GetLootSlotLink = function(slot) return state.loot[slot] end,
        GetLootSourceInfo = function() return state.corpse end,
        GetTime = function() return state.now or 100 end,
        PlaySound = function() state.sounds = (state.sounds or 0) + 1 end,
        SOUNDKIT = { RAID_WARNING = 8959 },
        C_Map = {
            GetBestMapForUnit = function() return 1413 end,
            GetFallbackWorldMapID = function() return 947 end,
            GetMapInfo = function(id) return { mapID = id, parentMapID = id == 1413 and 947 or 0 } end,
            GetMapChildrenInfo = function() return { { name = "The Barrens", mapID = 1413 } } end,
            OpenWorldMap = function(id) state.mapOpened = id end,
        },
        CreateFrame = function(_, _, parent)
            local frame = Frame(parent)
            state.frames[#state.frames + 1] = frame
            return frame
        end,
        CreateColor = function() return Frame() end,
        Mixin = function(target, ...)
            for i = 1, select("#", ...) do
                for k, v in pairs((select(i, ...))) do target[k] = v end
            end
            return target
        end,
        hooksecurefunc = function(t, key, fn)
            if type(t) ~= "table" then return end
            local original = t[key]
            t[key] = function(...) original(...); fn(...) end
        end,
        C_Timer = { After = function(_, fn) state.timers[#state.timers + 1] = fn end },
        -- Bag Marks' bag reads (its own test is test-bag-marks's; off here).
        C_Container = { GetContainerItemID = function() end, GetContainerItemLink = function() end },
        C_Item = {
            GetItemInfoInstant = function(item)
                local id = tonumber(tostring(item):match("item:(%d+)")) or item
                local loc = equip[id]
                if not loc then return nil end
                local kind = ITEM_CLASS[loc] or ARMOR
                return id, "", "", loc, 134400, kind[1], kind[2]
            end,
            GetItemInfo = function(id) return names[id], links[id], 3, 25, state.itemLevel or 60 end,
            GetDetailedItemLevelInfo = function() return 20 end,
            -- Every item gives 5 Agility and 5 Intellect, and a point of fire resistance; what
            -- you wear gives 2 and 2.
            GetItemStats = function(link)
                local worn = link:find("|h", 1, true) ~= nil
                return { ITEM_MOD_AGILITY_SHORT = worn and 2 or 5, ITEM_MOD_INTELLECT_SHORT = worn and 2 or 5,
                    ITEM_MOD_FIRE_RESISTANCE_SHORT = not worn and 1 or nil }
            end,
            GetItemNameByID = function(id) return names[id] end,
            GetItemIconByID = function() return 134400 end,
            IsItemDataCachedByID = function() return true end,
            GetItemQualityByID = function() return 3 end,
            GetItemCount = function() return 0 end,
            IsEquippedItem = function(id)
                for _, worn in pairs(state.worn) do
                    if worn == id then return true end
                end
                return false
            end,
        },
        C_PaperDollInfo = { GetInventorySlotInfoForInvSlot = function() return 0, 136516 end },
        ITEM_QUALITY_COLORS = { [3] = { hex = "|cff0070dd" } },
        TooltipDataProcessor = { AddTooltipPostCall = NOTHING },
        CreateAtlasMarkup = function() return "" end,
        Enum = { TooltipDataType = { Item = 0 }, UIMapType = { Zone = 3 } },
        GameTooltip = Frame(),
        WorldMapFrame = Frame(),
        GameTooltip_Hide = NOTHING,
        UIParent = Frame(),
        MenuUtil = { CreateContextMenu = NOTHING },
        -- state.menuOpen: a menu is open, and hover cards keep out of its way.
        Menu = { GetManager = function()
            return { IsAnyMenuOpen = function() return state.menuOpen == true end, OpenMenu = NOTHING }
        end },
    }, { __index = _G })
    local files = { "Core/Features.lua" }
    for _, path in ipairs(TocFiles("^Shared/.*%.lua$")) do
        if not path:find("^Shared/Data/%a*Items?%a*%.lua$") then files[#files + 1] = path end
    end
    files[#files + 1] = "NaowhForever_BiS/NaowhScore/Data/Formula.lua"   -- the paperdoll's score; not its tooltips
    files[#files + 1] = "NaowhForever_BiS/NaowhScore/NaowhScore.lua"
    for _, path in ipairs(TocFiles("^NaowhForever_BiS/StatWeights/.*%.lua$")) do files[#files + 1] = path end
    for _, path in ipairs(TocFiles("^NaowhForever_BiS/BiS/.*%.lua$")) do files[#files + 1] = path end
    Load(files, env)
    ns.Shared.ItemFacts = {}
    for _, spec in ipairs(ns.BiSData.specs) do
        for slot, ids in pairs(spec.slots) do
            for _, id in ipairs(ids) do equip[id] = equip[id] or INVTYPE[slot] end
        end
    end
    return ns, state, S
end

-- The BiS views made so far, in order: the window's, then the picker's.
local function Views(state, B)
    local views = {}
    for _, frame in ipairs(state.frames) do
        if rawget(frame, "kinds") == B.View.Kinds then views[#views + 1] = frame end
    end
    return views
end

local Measure = dofile("Tools/regression/measure.lua")(check)

-------------------------------------------------------------------------------
--  The window
-------------------------------------------------------------------------------
local ns, state, S = Fixture()
local B = ns.BiS
check("BiS.xml loads its files", #TocFiles("^NaowhForever_BiS/BiS/.*%.lua$") == 37)

ns.OpenBisWindow()
local view = Views(state, B)[1]
check("the window draws", view ~= nil)
check("a row per slot", view.pools.slotRow.used == 17)
check("nothing picked, nothing listed", view.pools.pick.used == 0 and view.pools.place.used == 0)
check("an empty slot asks you to pick its BiS", view.pools.slotRow[1].name.text:find("Pick its BiS", 1, true))
local summary = view.summary
check("the summary pinned over the list, out of its scroll: none yours, a bar of every slot",
    summary and summary:GetParent() ~= view and summary:GetParent() ~= view:GetParent()
    and summary.count.text == "0/0" and #summary.segments == 17)

-- Your picks, slot by slot, each the top of its slot's ranking, as you would add them in its
-- picker; none for the off hand while the main hand's is a two-hander.
local filled, used = 0, {}
for _, gear in ipairs(ns.Shared.Items.GEAR_SLOTS) do
    local slot = gear[1]
    if not (slot == 17 and B.OffHandIdle(B.Lists.List())) then
        for _, id in ipairs(B.Rankings.Candidates(slot, B.Lists.CurrentSpec())) do
            if not used[id] then
                used[id], filled = true, filled + 1
                ns.AddBisPick(slot, id)
                break
            end
        end
    end
end
check("a pick for each slot", filled > 10)
check("and the window redraws with them: one row a slot, no backups open", view.pools.slotRow.used == 17
    and view.pools.pick.used == 0)
check("with somewhere to run next", view.pools.place.used > 0 and view.pools.place.used <= 3)
local place = view.pools.place[1]
check("a place says which slots it is for, and who drops them", place.detail.text ~= "" and place.detail.text ~= nil)
check("the summary's bar marks what is still to get", summary.segments[1].state == "get")
check("the model tries your BiS on", tried > 0)

-- The filter: what you have yet to get, what to put on.
local list = B.Lists.List()
state.worn[1] = list.slots[1]
view:SetFilter("get")
check("To get leaves out what you have", view.pools.slotRow.used == view.counts.get and view.counts.get == filled - 1)
view:SetFilter("wear")
check("In bag: nothing in your bags, so a word instead", view.pools.slotRow.used == 0
    and view.pools.note[1].text.text:find("Nothing to put on", 1, true))
view:SetFilter("all")
check("All again", view.pools.slotRow.used == 17)
check("a section counts what is yours", view.pools.section[2].text.text:find("1 of 10 yours", 1, true))

-- The paperdoll's button for the slot.
local function DollButton(slot)
    for _, frame in ipairs(state.frames) do
        local parent = frame:GetParent()
        if rawget(frame, "slot") == slot and parent and rawget(parent, "buttons") then return frame end
    end
end
local head, neck = DollButton(1), DollButton(2)
check("a BiS you wear has the green line under its icon", head.worn.shown == true)
check("and the marks every slot has: its item level in the corner, no star (each is your BiS)",
    head.marks.level.text ~= nil and head.marks.level.text ~= "" and head.marks.rank.text == ""
    and head.marks.forever == head.iconFrame.forever)
check("one you do not wear has no line, and keeps its color", head.iconFrame.badge == nil
    and neck.worn.shown == false
    and neck.icon.desaturated == false)
check("a slot's row marks what you wear with the green bar, not the check",
    view.rows[1].worn.shown == true and view.rows[1].iconFrame.badge == nil)
check("and its segment in the bar is worn", summary.segments[1].state == "worn")
local badges = true
for _, row in pairs(view.rows) do
    local forever = row.bis ~= nil and ns.Shared.Parts.IsForever("items", row.bis)
    if (row.iconFrame.forever.shown == true) ~= forever then badges = false end
end
check("Forever's badge on the icon of each BiS new in Forever, and only those", badges)
summary.segments[3].scripts.OnClick(summary.segments[3])
check("a click on a segment lights its slot's row", view.rows[3].lit.shown == true)
view:GetParent():SetHeight(600)
view:GetParent().scrolled = nil
head.scripts.OnEnter(head)
check("hovering a slot lights its row", view.rows[1].lit.shown == true and view.rows[2].lit.shown == false)
check("without scrolling while the row shows", view:GetParent().scrolled == nil)
view.rowTops[18] = 4000
view:ScrollTo(18)
check("a row out of sight is scrolled to", (view:GetParent().scrolled or 0) > 0)
local doll = head:GetParent()
-- One item worn, at 20; every BiS at 25: the Naowh Score of each (its own test has the formula).
local gains = doll.gainsBlock
local function Number(text) return tonumber((text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("[%d%.]+")) end
local nowScore = ns.NaowhScore.Unit("player")
local bisScore = Number(gains.value.text)
check("the score card: with your BiS big, the gain on the right and what it is from",
    bisScore and bisScore > nowScore and gains.which.text == "with your BiS"
    and gains.other.text == ("from %.1f"):format(nowScore)
    and math.abs(Number(gains.gain.text) - (bisScore - nowScore)) <= 0.1)
check("the floating score over the model is gone", doll.big == nil)
local bar = gains.bar
-- With no journal data here, the scale is a little over what is shown.
check("the bar: filled to what you wear, your BiS's stretch lighter, plain after",
    bar:IsShown() and bar.gain:IsShown() and bar.rest:IsShown() and bar.cut:IsShown())
check("the scale named at its end", bar.topLabel.text:find("^Best ") ~= nil)
check("no goal of your level's unless graded against Both", not bar.goal:IsShown())
S.Set("naowhScoreCompare", "both")
doll:SetLook("bis")
check("with Both, your level's goal ticked and named in gold", bar.goal:IsShown()
    and bar.goalLabel.text:find("^Level 60 goal ") ~= nil)
S.Set("naowhScoreCompare", "level")
doll:SetLook("bis")
check("against the level, the scale is its best, and no tick", not bar.goal:IsShown()
    and bar.topLabel.text:find("^Level 60 best ") ~= nil)
S.Set("naowhScoreCompare", nil)
doll:SetLook("bis")
check("and the stats it adds that your spec weighs, by name and amount: a mage's Intellect",
    gains.grid.cells[1].name.text == "Intellect" and gains.grid.cells[1].value.text:find("+", 1, true))
check("not what it does not weigh (Agility, fire resistance), and four cells at most",
    gains.grid.cells[2].name.text == "" and #gains.grid.cells == 4)
local before = tried
doll:SetLook("now")
check("Now shows what you wear: nothing tried on", tried == before and doll.look == "now")
check("and the card follows: what you wear now, big", Number(gains.value.text) == tonumber(("%.1f"):format(nowScore))
    and gains.which.text == "now" and gains.other.text == "with your BiS")
neck.scripts.OnEnter(neck)
check("hovering a slot in Now tries its BiS on", tried == before + 1)
neck.scripts.OnLeave(neck)
doll:SetLook("bis")
check("Your BiS tries it all on again", tried > before)

-- How much stronger each BiS makes you: every item here gives 5 Agility, what you wear 2.
local SW = ns.StatWeights
local specKey = B.Lists.CurrentSpec().key
SW.Set(specKey, "agi", 1)
state.worn[2] = 999001   -- something else on your neck
view:Redraw()
local upgrades = view.gains
check("a BiS over what you wear says how much stronger it makes you, in its own column",
    upgrades[2] and upgrades[2] > 0 and view.rows[2].gain.text.text:find("+%d+%%") ~= nil
    and not view.rows[2].name.text:find("%%"))
check("no star after the name: every BiS here is your BiS", not view.rows[2].name.text:find("star", 1, true))
check("a slot with nothing on gains its BiS's whole worth", upgrades[3] and upgrades[3] > upgrades[2])
check("a BiS you wear gains nothing", upgrades[1] == nil and not view.rows[1].gain:IsShown())
-- The gain as a data bar: the list's biggest fills its cell, the rest their share of it.
local biggest, smaller
for slot, gain in pairs(upgrades) do
    if gain == view.mostGain then biggest = view.rows[slot] elseif not smaller then smaller = view.rows[slot] end
end
check("the biggest gain's bar fills its cell, a smaller one's is shorter", biggest
    and biggest.gain.bar.w >= biggest.gain.w - 1 and (not smaller or smaller.gain.bar.w < biggest.gain.bar.w))
local first = view.pools.place[1]
check("Run Next puts what makes you strongest first, and says by how much",
    first and first.place.gain > 0 and first.gain.text.text:find("+%d+%%") ~= nil
    and not first.count.text:find("%%")
    and (not view.pools.place[2] or view.pools.place[2].place.gain <= first.place.gain))
local opened
ns.OpenStatWeightsWindow = function() opened = true end
B.Actions.StatWeights()
check("the title bar's scales open your weights", opened)
state.worn[2] = nil
SW.Set(specKey, "agi", nil)
check("your weights kept only where they differ from the default", next(state.account.statWeights or {}) == nil)

Measure("the list redrawn", 2, function() view:Redraw() end)

-------------------------------------------------------------------------------
--  Enchants: the best for your spec on what you wear, by level
-------------------------------------------------------------------------------
local E = B.Enchants
local weights = ns.StatWeights.For(B.Lists.CurrentSpec().key)
check("every spec has weights", (function()
    for _, spec in ipairs(ns.BiSData.specs) do
        if not ns.StatWeights.Spec(spec.key) then return false end
    end
    return true
end)())
check("nothing worn on the wrists, nothing to enchant there", not E.ToDo(9) and not E.Advise(9).now)
state.worn[9] = list.slots[9]
local advice = E.Advise(9)
local best = advice.now and ns.BiSEnchants[advice.now]
check("bare bracers take the best wrist enchant for a mage", best and best.inv == 512 and advice.todo
    and advice.current == 0 and (best.stats.spell or 0) > 0 and weights)
check("the same advice until something changes", E.Advise(9) == advice)
view:Redraw()
local wand = DollButton(9).wand
check("the wand on its paperdoll slot shows a better enchant waits", wand:IsShown()
    and view.rows[9].enchant == nil)
wand.scripts.OnEnter(wand)
-- A click: a menu to ask for it, Trade first, or to copy the message.
local env = getfenv(ns.OpenBisWindow)
local menu, sent, copied = {}, nil, nil
local function Item(text, fn)
    local item = { text = text, fn = fn, enabled = true }
    function item:SetEnabled(on) self.enabled = on end
    menu[#menu + 1] = item
    return item
end
local root = { CreateTitle = NOTHING, CreateDivider = NOTHING, CreateButton = function(_, text, fn) return Item(text, fn) end }
env.MenuUtil = { CreateContextMenu = function(_, build) env.wipe(menu); build(nil, root) end }
env.C_ChatInfo = { InChatMessagingLockdown = function() return false end,
    SendChatMessage = function(text, channel, _, to) sent = { text, channel, to } end }
env.GetChannelList = function() return 1, "General - City", false, 2, "Trade - City", false end
env.C_Spell.GetSpellLink = function(spell) return "[Enchant " .. spell .. "]" end
env.UnitIsPlayer, env.IsInGroup, env.IsInRaid, env.IsInGuild = NOTHING, NOTHING, NOTHING, NOTHING
ns.ShowCopyLine = function(_, text) copied = text end
ns.ShowCopyCard = function(kind, _, id, _, mode) copied = mode == "url" and kind .. "=" .. id end
wand.scripts.OnClick(wand)
check("the wand's menu asks in Trade first", menu[1] and menu[1].text == "Trade" and menu[1].enabled)
menu[1].fn()
check("Trade gets the ask, with the recipe's link", sent and sent[2] == "CHANNEL" and sent[3] == 2
    and sent[1]:find("^LF Enchanter: %[Enchant " .. advice.now .. "%] %(%+") ~= nil)
menu[#menu].fn()
check("Copy has it as plain text", copied and copied:find("LF Enchanter: Enchant " .. advice.now, 1, true) == 1)
env.GetChannelList = NOTHING
wand.scripts.OnClick(wand)
check("out of a city, Trade waits", menu[1].text == "Trade" and not menu[1].enabled)
local tipOwner = env.GameTooltip.SetOwner
local owned = 0
env.GameTooltip.SetOwner = function() owned = owned + 1 end
local hands = view.rows[10]
hands.scripts.OnEnter(hands)
check("a row lights up, its item's card waits for its icon or name", owned == 0 and hands.hover.shown)
state.menuOpen = true
hands.tipZone.scripts.OnEnter(hands.tipZone)
check("with the menu open, no card over it either", owned == 0)
state.menuOpen = false
hands.tipZone.scripts.OnEnter(hands.tipZone)
check("and once it is closed, the card", owned == 1)
env.GameTooltip.SetOwner = tipOwner
view:SetFilter("enchant")
check("To enchant keeps the bracers", view.pools.slotRow.used == 1 and view.rows[9] ~= nil
    and view.pools.place.used == 0)
state.enchants = { [9] = best.enchant }
view:Redraw()
check("with that enchant on, the wand goes", not wand:IsShown())
check("with that enchant on, nothing to do", not E.ToDo(9) and view.pools.slotRow.used == 0
    and view.pools.note[1].text.text:find("best enchant", 1, true))
view:SetFilter("all")
state.enchants = { [9] = 999999 }
check("an enchant we do not know of is left alone", not E.ToDo(9) and E.Advise(9).onIt == nil)
-- A level 8 bracer, then a level 22 one: other items, other links, read again.
state.enchants, state.itemLevel = { [9] = "0" }, 8
advice = E.Advise(9)
check("a level 8 bracer gets what an apprentice enchanter has, and nothing for later",
    advice.now and ns.BiSEnchants[advice.now].skill <= 75 and advice.itemLevel == 8 and advice.later == nil)
state.enchants, state.itemLevel = { [9] = "00" }, 22
advice = E.Advise(9)
check("a level 22 one what suits a level 22 item, whatever your level",
    advice.itemLevel == 22 and E.LevelFor(ns.BiSEnchants[advice.now].skill) <= 20)
for _, spell in ipairs(advice.specials) do
    check("and only specials that suit it too", E.LevelFor(ns.BiSEnchants[spell].skill) <= 22)
end
state.enchants, state.itemLevel = nil, nil
state.worn[16] = list.slots[16]
for _, spell in ipairs(E.Advise(16).specials) do
    local special = ns.BiSEnchants[spell].special
    check("a special is shown for a stat a mage values", special == "any" or weights[special] >= 0.3)
end
state.worn[2], state.worn[15] = list.slots[2], list.slots[15]
local necklace, cloak = E.Advise(2).now, E.Advise(15).now
check("a necklace takes a neck enchant, a cloak a cloak one",
    necklace and ns.BiSEnchants[necklace].inv == 4 and cloak and ns.BiSEnchants[cloak].inv == 65536)
local weapon = E.Advise(16).now and ns.BiSEnchants[E.Advise(16).now]
check("a mage's sword takes a weapon enchant", weapon and weapon.class == 2)
Measure("the list redrawn, with enchants", 2, function() view:Redraw() end)

-------------------------------------------------------------------------------
--  A slot's picker, and its backups opened under its row
-------------------------------------------------------------------------------
local function SectionIn(v, title)
    for i = 1, v.pools.section.used do
        local row = v.pools.section[i]
        if row.text.text and row.text.text:upper():find(title:upper(), 1, true) then return row end
    end
end
local function NoteIn(v, part)
    for i = 1, v.pools.note.used do
        local row = v.pools.note[i]
        if row.text.text and row.text.text:find(part, 1, true) then return row end
    end
end

B.OpenPicker(1, head)
local picker = Views(state, B)[2]
check("the picker is its own view", picker and picker.page == "picker")
check("without the Dungeon Journal, the picker's dungeon drops ask to turn it on",
    SectionIn(picker, "Dungeon drops") and NoteIn(picker, "what drops in dungeons for this slot"))
local own, add, numbered = 0, 0, false
for i = 1, picker.pools.pick.used do
    local row = picker.pools.pick[i]
    if row.mode == "own" then own = own + 1 else add = add + 1 end
    if row.name.text:find("^1%.") then numbered = true end
end
check("your pick, then the ranking and the drops", own == 1 and add > 0)
check("the ranking shows its own order", numbered)
local candidate
for i = 1, picker.pools.pick.used do
    local row = picker.pools.pick[i]
    if row.mode == "add" and not row.rank then candidate = row break end
end
local added = candidate.itemID   -- the redraw gives its row to another item
candidate.scripts.OnClick(candidate, "LeftButton")
check("a click adds it as the next pick", B.Picks(B.Lists.List(), 1)[2] == added)
check("and the picker redraws", picker.pools.pick[2].rank == 2)
check("the slot's row says it has two picks", view.rows[1].toggle.text.text == "2 picks")
view:Toggle(1)
local backup = view.pools.backup[1]
check("opened, its backup shows under it", view.pools.backup.used == 1 and backup.itemID == added)
check("laid out as the slot row: its rank where the slot's name is, no star after the name",
    backup.rankText.text:find("2nd", 1, true) and not backup.name.text:find("star", 1, true)
    and backup:GetHeight() == view.rows[1]:GetHeight())
check("joined to its slot by a line: up under the slot's name, turning into its branch on the rounded corner",
    backup.trunk.h == 9 + backup:GetHeight() / 2 + 1 - 8 + 1 and backup.elbow:IsShown() and backup.branch:IsShown())
check("Forever's mark on the icon's corner, never in the name", backup.iconFrame.forever ~= nil
    and not backup.name.text:find("|T", 1, true) and not view.rows[1].name.text:find("|T", 1, true))
check("its source is a link that says where it goes", backup.source:IsShown() and backup.source.itemID == added
    and B.Sources.Hint(added):find("^Click: ") ~= nil)
-- A source's click, by what the data knows (the dungeon's is the Journal's: see
-- test-bis-dungeon-drops): an NPC out in the world a waypoint, else its Wowhead link.
check("an item an NPC has: a waypoint on them", B.Sources.Of(285330) == "npc"
    and B.Sources.Hint(285330) == "Click: a waypoint on Swiftmane")
local lookup
for id in pairs(ns.BiSData.sources) do
    if B.Sources.Of(id) == "wowhead" then lookup = id break end
end
copied = nil
B.Sources.Go(lookup)
check("nothing better known: its Wowhead link to copy", lookup and copied and copied:find("item=" .. lookup, 1, true))
view:Toggle(1)
check("and folds away", view.pools.backup.used == 0)

-- Drop Alert's test: up for a roll now, dropped and yours after.
local said = #state.printed
check("the test plays with your first BiS", B.Alerts.Test() and #state.printed == said + 1)
for _, fn in ipairs(state.timers) do fn() end
check("then dropped, then yours", #state.printed >= said + 3
    and state.printed[#state.printed]:find("is yours", 1, true))

-------------------------------------------------------------------------------
--  Off means quiet
-------------------------------------------------------------------------------
S.Set("bisLootAlert", true)
local listening = false
for _, frame in ipairs(state.frames) do
    if frame.events.LOOT_READY then listening = true end
end
check("Drop Alert on, loot is listened to", listening)

-- Once per drop: the roll, then the boss's loot window opened twice, say one line.
local loot
for _, frame in ipairs(state.frames) do
    if frame.events.LOOT_READY then loot = frame end
end
local bisHead = B.Picks(B.Lists.List(), 1)[1]
local link = "|cff0070dd|Hitem:" .. bisHead .. "::|h[Hat]|h|r"
local sounds
said, sounds = #state.printed, state.sounds or 0
state.roll, state.loot, state.corpse, state.now = link, { link }, "Creature-0-1-2-3-4-5", 100
loot.scripts.OnEvent(loot, "START_LOOT_ROLL", 7)
check("a roll for your BiS says so", #state.printed == said + 1 and state.sounds == sounds + 1)
local line = state.printed[#state.printed]
check("with its star, the item, and the slot it is your BiS for",
    line:find("up for a roll", 1, true) and line:find("your BiS for Head", 1, true) and line:find(link, 1, true))
loot.scripts.OnEvent(loot, "LOOT_READY")
loot.scripts.OnEvent(loot, "LOOT_READY")
check("the same drop in the loot window, opened again, says nothing more", #state.printed == said + 1)
state.now, state.corpse = 900, "Creature-0-1-2-3-4-6"
loot.scripts.OnEvent(loot, "LOOT_READY")
check("another copy from another corpse later does", #state.printed == said + 2)
loot.scripts.OnEvent(loot, "LOOT_READY")
check("once", #state.printed == said + 2)

-------------------------------------------------------------------------------
--  Drop Alert as you set it: which picks, the alert on screen, chat, sounds
-------------------------------------------------------------------------------
local painted
local paint = B.Toast.Paint
B.Toast.Paint = function(f, ...) painted = f; return paint(f, ...) end
local second = B.Picks(B.Lists.List(), 1)[2]
local rolls = 7
local function Roll(item)
    rolls, state.now, painted = rolls + 1, state.now + 1000, nil
    said, sounds = #state.printed, state.sounds or 0
    state.roll = "|cff0070dd|Hitem:" .. item .. "::|h[Hat]|h|r"
    loot.scripts.OnEvent(loot, "START_LOOT_ROLL", rolls)
end
Roll(bisHead)
check("an alert on screen too: what happened, your rank, the slot", painted
    and painted.detail.text:find("Up for a roll", 1, true) and painted.detail.text:find("Your BiS", 1, true)
    and painted.detail.text:find("Head", 1, true))
local holder, up = painted:GetParent(), 0
for _, frame in ipairs(state.frames) do
    if rawget(frame, "parent") == holder and rawget(frame, "shown") then up = up + 1 end
end
check("stacked under one holder you move in Unlock Mode, three at most", rawget(holder, "mover") and up == 3)
S.Set("bisAlertFor", "bis")
Roll(second)
check("Alert For your BiS only: your second pick says nothing", not painted and #state.printed == said
    and state.sounds == sounds)
S.Set("bisAlertFor", "top2")
Roll(second)
check("your top two: it does, in its own words", painted and painted.detail.text:find("Your second pick", 1, true)
    and #state.printed == said + 1)
S.Set("bisAlertChat", false)
Roll(bisHead)
check("Chat Line off: the alert and the sound only", painted and #state.printed == said and state.sounds == sounds + 1)
S.Set("bisToast", false)
Roll(bisHead)
check("On-Screen Alert off: no alert", not painted and state.sounds == sounds + 1)
S.Set("bisDropSound", "Naowh: Ding")
Roll(bisHead)
check("a sound of your own from the list", state.soundPath == "sound:Naowh: Ding" and state.sounds == sounds + 1)
S.Set("bisDropSound", "none")
Roll(bisHead)
check("or none", state.sounds == sounds)
S.Set("bisAlertFor", "all")
S.Set("bisAlertChat", true)
S.Set("bisToast", true)
S.Set("bisDropSound", "game:raidwarning")

-- How it looks.
local toast = B.Toast.New(Frame())
paint(toast, bisHead, 1, "dropped")
check("by default: the star, a border and a glow in your rank's color", toast.star:IsShown()
    and toast.edge.opacity == 1 and toast.glow:IsShown() and toast.bg.alpha == 0.95)
S.Set("bisToastStar", "none")
S.Set("bisToastBorder", "none")
S.Set("bisToastGlow", false)
S.Set("bisToastEvent", false)
S.Set("bisToastSlot", false)
S.Set("bisToastGain", false)
S.Set("bisToastAlpha", 0.5)
paint(toast, bisHead, 1, "dropped")
check("each can go", not toast.star:IsShown() and toast.edge.opacity == 0 and not toast.glow:IsShown()
    and toast.bg.alpha == 0.5)
check("and only the parts you keep say anything", toast.detail.text == "Your BiS")
check("its text in the Addon Font at today's sizes, no outline", toast.name.font == "font" and toast.name.size == 13
    and toast.name.flags == "" and toast.detail.size == 11 and toast.detail.flags == "")
S.Set("bisToastFont", "Naowh")
S.Set("bisToastFontSize", 16)
S.Set("bisToastOutline", "OUTLINE")
paint(toast, bisHead, 1, "dropped")
check("Font, Font Size and Outline change both lines", toast.name.font == "lsm:Naowh" and toast.name.size == 16
    and toast.name.flags == "OUTLINE" and toast.detail.font == "lsm:Naowh" and toast.detail.size == 14
    and toast.detail.flags == "OUTLINE")
S.Set("bisToastFont", "")
S.Set("bisToastFontSize", 13)
S.Set("bisToastOutline", "NONE")
S.Set("bisToastGain", true)

-- The preview on Drop Alert's card: the alert as it will look, in the moment picked.
local studio = B.AlertStudio
check("its moments: up for a roll, dropped, yours", #studio.states == 3 and studio.states[1].key == "roll"
    and studio.states[3].label == "Yours!")
local stage = Frame()
stage.w = 600
local preview = studio.new(stage)
local function PreviewOf(parent)
    for _, frame in ipairs(state.frames) do
        if rawget(frame, "parent") == parent then return frame end
    end
end
check("drawn on its own frame on the stage", preview and PreviewOf(stage) == preview)
studio.paint(preview, "dropped")
check("with your BiS, as you set it", preview.toast:IsShown() and preview.toast.detail.text:find("^Your BiS") ~= nil
    and not preview.empty:IsShown() and not preview.note:IsShown())
S.Set("bisToastEvent", true)
studio.paint(preview, "roll")
check("Up for a roll", preview.toast.detail.text:find("^Up for a roll") ~= nil)
studio.paint(preview, "yours")
check("Yours! too", preview.toast.detail.text:find("^Yours!") ~= nil)
studio.paint(preview, "dropped")
check("and dropped", preview.toast.detail.text:find("^Dropped") ~= nil)
S.Set("bisToastEvent", false)
S.Set("bisToast", false)
studio.paint(preview, "dropped")
check("On-Screen Alert off: faded, with a note", preview.toast.alpha == 0.35 and preview.note:IsShown())
S.Set("bisToast", true)

-- The page: its cards, and the rows hang on the module and on On-Screen Alert.
local page = ns.Shared.Settings.pages["BiS List/Settings"]
local cards, rows = {}, {}
for _, item in ipairs(page.items) do
    if item.id then
        cards[#cards + 1] = item.id
        for _, row in ipairs(item.rows) do
            if row.label then rows[row.label] = row end
        end
    end
end
check("one page: the window's card, then its cards in order", page.items[1].window
    and page.items[1].text == "Open BiS List" and table.concat(cards, ",")
    == "marks,dropAlert,lists,statWeights,keys")
check("no Window card: the windows are always solid", page.cards.window == nil and rows["Window Opacity"] == nil)
check("the tooltip and bag marks card is named for them", page.cards.marks.name == "Marks on Items")
check("Marks on Items holds Show on Tooltips and Bag Marks only: Bag Marks draws the level",
    #page.cards.marks.rows == 2 and page.cards.marks.rows[1].key == "bisTooltip"
    and page.cards.marks.rows[2].key == "bisBagMarks" and rows["Item Level in Bags"] == nil)
check("Drop Alert: its switch and its preview", page.cards.dropAlert.switch == "bisLootAlert"
    and page.cards.dropAlert.studio == studio)
check("no list management on it: that is the window's", rows["Manage Lists"] == nil and rows["Your List"]
    and rows["Rankings For"] and rows["Key Binding"] == nil and page.cards.keys.rows[1].label == "Open BiS List"
    and page.cards.keys.rows[1].binding == "NAOWHFOREVER_BIS")
check("how it looks needs On-Screen Alert", rows["Size"].needs[2] == "bisToast" and rows["Star"].needs[2] == "bisToast")
check("a size in percent is saved as a scale", rows["Size"].get() == 100)
rows["Size"].set(120)
check("as a fraction", S.Get("bisToastScale") == 1.2)
rows["Size"].set(100)
sounds = state.sounds or 0
rows["It's Yours Sound"].set("game:epicloot")
check("a sound plays as you pick it", state.sounds == sounds + 1 and S.Get("bisYoursSound") == "game:epicloot")
local values = rows["Drop Sound"].choice()
check("the game's own sounds offered too", values["game:raidwarning"] == "Raid Warning (game)")
said = #state.printed
rows["Play Test"].button()
check("Play Test plays Drop Alert", #state.printed == said + 1)
S.Set("bisToastSlot", true)
S.Set("bisToastAlpha", 0.95)
S.Set("bisLootAlert", false)
for _, frame in ipairs(state.frames) do
    check("Drop Alert off, it is not", not frame.events.LOOT_READY)
end
local window
for _, frame in ipairs(state.frames) do
    if rawget(frame, "positionKey") == "bisWindow" then window = frame end
end
check("the window is open", window and window:IsShown())
ns.TurnOnModule = function(addon) state.turnedOn = addon end
check("without the Dungeon Journal, the Quests tab is still there", window.pages:IsShown())
window.pages.onPick("quests")
local questsOff = SectionIn(view, "Quests for your BiS")
check("its page says the quests come from the Dungeon Journal, with a link to turn it on",
    questsOff and NoteIn(view, "Turn on the Dungeon Journal to see the quests"))
questsOff.onLink(questsOff.linkArg)
check("the link turns the Dungeon Journal on", state.turnedOn == "NaowhForever_DungeonJournal")
view:Redraw()
check("and a redraw keeps that page", SectionIn(view, "Quests for your BiS") ~= nil)
local listParent = view:GetParent()
view.parent = nil
check("hovering a slot on the Quests page has no list to scroll", pcall(head.scripts.OnEnter, head))
view.parent = listParent
window.pages.onPick("list")
check("Run next asks for it for each dungeon's levels and quests", SectionIn(view, "Run next")
    and NoteIn(view, "each dungeon's levels and quests"))
place = view.pools.place[1]
place.dungeon, place.map, place.spot = nil, 1413, nil
place.scripts.OnClick(place)
check("a zone to run to opens on the map, the BiS List put away", state.mapOpened == 1413 and not window:IsShown())
ns.OpenBisWindow()
ns.PlaceWaypoint = function(title, map, x, y, note) state.waypoint = { title, map, x, y, note } end
place.spot, place.spotItem, place.map = ns.BiSSpots[285330], 285330, 1413
place.scripts.OnClick(place)
check("and with who drops your BiS there, a waypoint on them",
    state.waypoint and state.waypoint[1] == "Swiftmane" and state.waypoint[2] == 1413 and not window:IsShown())
local worldMap = getfenv(ns.OpenBisWindow).WorldMapFrame
worldMap.hooks.OnHide(worldMap)
check("and closing the map brings it back", window:IsShown())
ns.OpenJournalWindow = function(dungeon, back) state.journalOpened, state.journalBack = dungeon, back end
place.dungeon = "a dungeon"
place.open.scripts.OnClick(place.open)
check("Open on a place to run puts the BiS List away for the Journal",
    not window:IsShown() and state.journalOpened == "a dungeon")
state.journalBack()
check("and closing the Journal brings it back", window:IsShown())
state.journalBack()
S.Set("bis", false)
check("turning the module off closes it", not window:IsShown())

-- New List: the dialog's own parts, as the stubs make them: the modal, the name box, the
-- dropdowns (Start From, then Spec's Picks), the toggles (Only for, then one per slot) and buttons.
do
    local modal, box, dropdowns, toggles, buttons = nil, nil, {}, {}, {}
    ns.MakeModal = function()
        modal = Frame()
        return modal, Frame()
    end
    ns.NewEditBox = function(parent)
        box = Frame(parent)
        return box
    end
    ns.Button = function(parent, text, _, _, onClick)
        local button = Frame(parent)
        buttons[text] = onClick
        return button
    end
    local BuildToggle = ns.UI.BuildToggleControl
    ns.UI.BuildToggleControl = function(...)
        local toggle = BuildToggle(...)
        toggles[#toggles + 1] = toggle
        return toggle
    end
    ns.UI.BuildDropdownControl = function(parent, _, _, names, _, get, set)
        local dropdown = Frame(parent)
        dropdown._values, dropdown._get, dropdown._set, dropdown._refreshLabel = names, get, set, NOTHING
        dropdowns[#dropdowns + 1] = dropdown
        return dropdown
    end
    -- What a dropdown's menu offers: its titles, and each radio's text, data and whether it is enabled.
    local function Menu(dropdown)
        local offer = { titles = {}, radios = {} }
        dropdown._menuFill({
            CreateTitle = function(_, text) offer.titles[#offer.titles + 1] = text end,
            CreateRadio = function(_, text, _, pick, data)
                local radio = { text = text, data = data, pick = pick, enabled = true }
                function radio:SetEnabled(on) self.enabled = on end
                offer.radios[#offer.radios + 1] = radio
                return radio
            end,
        })
        return offer
    end
    local L = B.Lists
    local source = L.List()
    local spec = L.CurrentSpec()
    local short = L.SpecShort(spec)
    B.Actions.New()
    local from, specPick = dropdowns[1], dropdowns[2]
    check("New List opens the dialog, starting from Empty with no spec to pick",
        modal.shown and from._get() == 0 and not specPick:IsShown() and #toggles == 1 + 17)
    check("Only for names the spec on show, unticked", toggles[1]._get() == false)
    local offered = Menu(from)
    local picked
    for _, radio in ipairs(offered.radios) do
        if radio.data == source.id then picked = radio end
    end
    check("Start From offers Empty, then the class lists", offered.radios[1].data == 0
        and offered.titles[1] == "Class lists" and picked and picked.text == source.name)
    picked.pick(source.id)
    check("a class list asks which spec's picks, the one on show first", specPick:IsShown() and specPick._get() == spec.key)
    local specs = Menu(specPick)
    local greyed = 0
    for _, radio in ipairs(specs.radios) do
        if not radio.enabled then greyed = greyed + 1 end
    end
    check("a spec with nothing picked can't be chosen", #specs.radios == #B.Rankings.ClassSpecs()
        and specs.radios[1].text:find(short, 1, true) == 1 and greyed == #specs.radios - 1)
    toggles[2]._set(false)
    box:SetText("Copy")
    buttons.Create()
    local copy = L.List()
    check("Create makes the list with every ticked slot's picks", copy.name == "Copy" and not modal.shown
        and copy.slots[1] == nil and copy.slots[2] == source.slots[2] and copy.slots[2] ~= nil and copy.specOnly == nil)
    B.Actions.New()
    check("opened again, it starts over", from._get() == 0 and toggles[1]._get() == false and box:GetText() == "")
    toggles[1]._set(true)
    box:SetText("Solo")
    buttons.Create()
    check("ticked, the list is the spec's own", L.List().name == "Solo" and L.List().specOnly == true)
    local titles, radios = {}, {}
    local menuRoot = { CreateDivider = NOTHING, CreateButton = NOTHING,
        CreateTitle = function(_, text) titles[#titles + 1] = text end,
        CreateRadio = function(_, text) radios[#radios + 1] = text end }
    env.MenuUtil = { CreateContextMenu = function(_, build) build(nil, menuRoot) end }
    B.Actions.ListMenu()
    check("the menu lists the class's lists, then the spec's own under its heading",
        #titles == 2 and titles[2] == short .. " only" and radios[#radios] == "Solo" and #radios >= 2)
    local other = B.Rankings.ClassSpecs()[2]
    ns.SelectBisList(source.id)
    ns.SetBisSpec(other.key)
    ns.AddBisPick(1, B.Rankings.Candidates(1, other)[1])
    B.Actions.New()
    picked.pick(source.id)
    check("with picks on two specs, Spec's Picks starts on the tab's", specPick._get() == other.key)
end

do
    local f = assert(io.open("NaowhForever_BiS/BiS/Gains.lua", "rb"))
    local source = f:read("*a")
    f:close()
    check("your BiS's stats are read through the stat weights' bounded cache, not a copy of their own",
        source:find("ns.StatWeights.Stats", 1, true) ~= nil and not source:find("GetItemStats", 1, true))
end

print(("test-bis-window: %d checks passed"):format(checks))

-- Loads BagSpace.lua, after the Shared files it draws with, against stubbed bag,
-- item and frame APIs and checks what the row offers, what the clicks do, stacking, the card's
-- look (header, shared marks, the clock and quest badges drawn from the game's atlases, prices in
-- their largest coin centred under even cells, no outline, colors by state), its Background (the
-- card, a soft fade or none, from the shared HUD backdrop, with the matching text shadow), its
-- Font, Font Size and Outline (the header and prices scale with the size), the tooltip lines that
-- explain the badges, its settings preview and card rows, and what a scan costs.
-- Run from the repo root: lua Tools/regression/test-bag-space.lua
local f = assert(io.open(arg[1] or "NaowhForever_QoL/Loot/BagSpace.lua", "rb"))
local source = f:read("*a"); f:close()
local SHARED = { "Shared/Shared.lua", "Shared/Style.lua", "Shared/UI/Parts.lua", "Shared/UI/Marks.lua", "Shared/UI/Text.lua", "Shared/UI/Hud.lua", "Shared/UI/Timer.lua", "Shared/UI/Share.lua", "Shared/UI/Panels.lua" }

-- itemID -> name, quality, required level, max stack, vendor price, class
local ITEMS = {
    [1] = { "Small Egg", 1, 0, 20, 4, 7 },
    [2] = { "Coyote Meat", 1, 0, 20, 3, 7 },
    [3] = { "Light Feather", 1, 0, 20, 41, 7 },
    [4] = { "Chipped Boar Tusk", 0, 0, 5, 38, 15 },
    [5] = { "Flash Powder", 1, 0, 20, 1, 5 },          -- reagent: protected
    [6] = { "Quest Letter", 1, 0, 1, 1, 12 },          -- quest: protected
    [7] = { "Hearthstone", 1, 0, 1, 0, 15 },           -- no vendor price: never offered
    [8] = { "Blue Ring", 3, 0, 1, 900, 4 },            -- rare: above the quality limit
    [9] = { "Tough Jerky", 1, 5, 20, 1, 0 },           -- food ten or more levels below: old
    [10] = { "Linen Cloth", 1, 0, 20, 13, 7 },
    [11] = { "Green Belt", 2, 0, 1, 50, 4 },
}

local WHITE = { r = 1, g = 1, b = 1, hex = "|cffffffff" }
local HEX = { accent = "0091ed", muted = "9a9ea6", fg = "f0f1f3", accentSoft = "4db5f5" }
-- The game's coin string, stubbed: what Parts.Coins caches, so prices can be traced to it.
local function CoinString(copper) return "<" .. copper .. ">" end

local function Fixture(opts)
    local settings = opts.settings or {}
    local defaults = {
        enabled = true, bagSpace = true, bagSpaceCount = 4, bagSpaceSize = 36,
        bagSpaceGrow = "RIGHT", bagSpaceReverse = false, bagSpaceMaxQuality = 2, bagSpaceJunkFirst = false,
        bagSpaceAuction = true, bagSpaceProtect = true, bagSpaceFreeBelow = 0,
        bagSpaceHideCombat = true, bagSpaceOnFull = true, bagSpaceShowFree = true,
        bagSpaceStack = true, bagSpaceOldFirst = false, bagSpacePrices = true,
        bagSpaceTipVendor = true, bagSpaceTipAuction = true, bagSpaceTipDelete = true, bagSpaceTipIgnore = true,
        bagSpaceBackground = "card", bagSpaceFont = "", bagSpaceFontSize = 12, bagSpaceOutline = "",
    }
    local db, printed, buttons = {}, {}, {}
    local made = 0                         -- frames made, all told
    local bags = opts.bags                 -- bags[bag][slot] = { id, count } or nil
    local cursor, ctrl, now = nil, false, 1000
    local registered = {}
    local infoCache = {}                   -- one table per slot, as reused as the real API allows

    local S = {}
    function S.Get(k) if settings[k] ~= nil then return settings[k] end return defaults[k] end
    function S.Set(k, v) settings[k] = v end
    function S.DB() return db end

    -- Methods are made once and shared, so the stubs add no garbage to the cost measured below.
    local function Noop() end
    -- Any method a stub lacks does nothing; a field never set is nil, as on a real frame.
    local noopMeta = { __index = function(_, k) if type(k) == "string" and k:find("^%u") then return Noop end end }
    local Widget
    local methods = setmetatable({
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetShown = function(self, v) self.shown = v and true or false end,
        IsShown = function(self) return self.shown end,
        SetText = function(self, v) self.text = v end,
        SetFont = function(self, font, size, flags) self.font, self.size, self.flags = font, size, flags end,
        SetTextColor = function(self, r, g, b) self.r, self.g, self.b = r, g, b end,
        SetShadowOffset = function(self, x, y) self.shadowX, self.shadowY = x, y end,
        SetShadowColor = function(self, _, _, _, a) self.shadowA = a end,
        SetTexCoord = function(self, l, r, t, b) self.coords = l + r * 10 + t * 100 + b * 1000 end,
        SetSize = function(self, w, h) self.w, self.h = w, h end,
        SetWidth = function(self, w) self.w = w end,
        SetHeight = function(self, h) self.h = h end,
        GetWidth = function(self) return self.w or 0 end,
        GetHeight = function(self) return self.h or 0 end,
        SetPoint = function(self, point, _, _, x, y) self.point, self.x, self.y = point, x, y end,
        SetScale = function(self, s) self.scale = s end,
        GetFrameLevel = function() return 1 end,
        GetStringWidth = function() return 20 end,
        SetTexture = function(self, v) self.texture = v end,
        SetAtlas = function(self, v) self.atlas = v end,
        SetVertexColor = function(self, r, g, b, a) self.vr, self.vg, self.vb, self.va = r, g, b, a end,
        SetScript = function(self, name, fn) self[name] = fn end,
        CreateTexture = function() return Widget("region") end,
        CreateFontString = function() return Widget("region") end,
        RegisterEvent = function(self, e) registered[e] = registered[e] or {}; registered[e][self] = true end,
        UnregisterEvent = function(self, e) if registered[e] then registered[e][self] = nil end end,
        UnregisterAllEvents = function(self) for _, set in pairs(registered) do set[self] = nil end end,
    }, noopMeta)
    local widgetMeta = { __index = methods }
    function Widget(kind)
        made = made + 1
        return setmetatable({ kind = kind, shown = true }, widgetMeta)
    end
    local border = {}
    function border.SetColor(_, r, g, b)
        if r == WHITE.r and g == WHITE.g and b == WHITE.b then border.white = true end
    end
    local borderMeta = { __index = border }
    local tipLines = {}
    local tooltip = setmetatable({
        SetOwner = function() for i = #tipLines, 1, -1 do tipLines[i] = nil end end,
        AddLine = function(_, text, r, g, b) tipLines[#tipLines + 1] = { text = text, r = r, g = g, b = b } end,
    }, noopMeta)
    local cards = {}

    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        QoLConstants = dofile("Tools/regression/qol_constants.lua"),
        Color = function(token, text) return "|cff" .. HEX[token] .. (text and (text .. "|r") or "") end,
        THEME = { accent = { r = 0, g = 0.57, b = 0.93 }, muted = { r = 0.6, g = 0.6, b = 0.6 },
            fg = { r = 0.94, g = 0.95, b = 0.95 }, bg = { r = 0.05, g = 0.06, b = 0.07 },
            line = { r = 0.18, g = 0.19, b = 0.21 }, accentSoft = { r = 0.3, g = 0.71, b = 0.96 } },
        QoLSettings = S,
        Print = function(msg) printed[#printed + 1] = msg end,
        Apply = function() end,
        ShowUnlockMode = function() end,
        HideUnlockMode = function() end,
        IsBisItem = function(id) return opts.bis and opts.bis[id] end,
        AuctionPrice = function(id) return opts.ah and opts.ah[id] end,
        ScrapMarker = opts.scrap,
        Font = function(_, size, flags, color)
            local w = Widget("font")
            w.size, w.flags, w.color = size, flags, color
            return w
        end,
        Solid = function() return Widget("texture") end,
        PixelInset = function(region) return region end,
        Border = function() return setmetatable({ _frame = Widget("frame") }, borderMeta) end,
        -- ns.Button, keeping its label and click so the Stack button can be read and pressed.
        Button = function(_, text, _, _, onClick)
            local w = Widget("button")
            w.label, w._onClick = Widget("font"), onClick
            w.label.text = text
            return w
        end,
        SetButtonText = function(button, text) button.label.text = text end,
        AccentBorder = function(frame) return frame end,
        Confirm = function(_, onYes) onYes() end,
        UI = { AttachMover = function() return Widget("mover") end,
            FontPath = function(name) return name == "" and "addon-font" or name end },
    }

    local function Item(bag, slot) return bags[bag] and bags[bag][slot] end
    local function Info(bag, slot)
        local it = Item(bag, slot)
        if not it then return nil end
        local key = bag * 100 + slot
        local t = infoCache[key] or {}
        infoCache[key] = t
        local def = ITEMS[it.id]
        t.itemID, t.stackCount, t.quality, t.iconFileID = it.id, it.count, def[2], it.id
        t.hyperlink, t.isLocked = "[" .. def[1] .. "]", false
        return t
    end
    local function Place(bag, slot)
        local it = Item(bag, slot)
        if not it then
            bags[bag][slot] = cursor
            cursor = nil
        elseif it.id == cursor.id then
            local room = ITEMS[it.id][4] - it.count
            local moved = math.min(room, cursor.count)
            it.count = it.count + moved
            cursor.count = cursor.count - moved
            if cursor.count == 0 then cursor = nil end
        else
            bags[bag][slot], cursor = cursor, it
        end
    end

    local env = {
        BACKPACK_CONTAINER = 0, NUM_BAG_SLOTS = #bags,
        ITEM_QUALITY_COLORS = setmetatable({}, { __index = function() return WHITE end }),
        ERR_INV_FULL = "Inventory is full.", ERR_BAG_FULL = "That bag is full.",
        wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        time = function() return now end,
        GetTime = function() return now end,
        UnitLevel = function() return opts.level or 20 end,
        UnitAffectingCombat = function() return false end,
        InCombatLockdown = function() return false end,
        IsControlKeyDown = function() return ctrl end,
        IsModifiedClick = function() return false end,
        GameTooltip = tooltip,
        GameTooltip_Hide = function() end,
        C_Timer = { After = function(_, fn) fn() end },
        C_Container = {
            GetContainerNumSlots = function(bag) return bags[bag] and bags[bag].size or 0 end,
            GetContainerNumFreeSlots = function(bag)
                local n = 0
                for slot = 1, bags[bag].size do if not bags[bag][slot] then n = n + 1 end end
                return n, 0
            end,
            GetContainerItemInfo = Info,
            PickupContainerItem = function(bag, slot)
                if cursor then return Place(bag, slot) end
                cursor, bags[bag][slot] = bags[bag][slot], nil
            end,
            SplitContainerItem = function(bag, slot, amount)
                local it = bags[bag][slot]
                it.count = it.count - amount
                cursor = { id = it.id, count = amount }
            end,
            UseContainerItem = function(bag, slot) bags[bag][slot] = nil end,
        },
        C_Item = {
            GetItemInfo = function(id)
                local d = ITEMS[id]
                return d[1], nil, d[2], nil, d[3], nil, nil, d[4], nil, nil, d[5]
            end,
            GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, ITEMS[id][6] end,
        },
        C_QuestLog = {
            GetNumQuestLogEntries = function() return opts.quests and #opts.quests or 0 end,
            GetInfo = function(i) return { questID = i, title = opts.quests[i].title, isHeader = false } end,
            GetQuestObjectives = function(id) return opts.quests[id].objectives end,
        },
        C_CurrencyInfo = { GetCoinTextureString = CoinString },
        CreateColor = function() return WHITE end,
        GetCursorInfo = function() if cursor then return "item", cursor.id end end,
        ClearCursor = function() cursor = nil end,
        DeleteCursorItem = function() cursor = nil end,
        CreateFrame = function(kind, name)
            local w = Widget(kind)
            if kind == "Button" then buttons[#buttons + 1] = w end
            if name == "NaowhForeverBagSpace" then buttons.row = w end
            return w
        end,
        hooksecurefunc = function(tbl, key, fn)
            local orig = tbl[key]
            tbl[key] = function(...) orig(...); fn(...) end
        end,
    }
    env._G = { NaowhForever = ns }
    setmetatable(env, { __index = _G })
    for _, path in ipairs(SHARED) do
        local shared = assert(loadfile(path))
        setfenv(shared, env)
        shared()
    end
    local Parts = ns.Shared.Parts
    -- Every corner badge the shared part makes, so the row's clock and "!" can be traced to it.
    local tags, ItemBadge = {}, Parts.ItemBadge
    function Parts.ItemBadge(...)
        local badge = ItemBadge(...)
        tags[badge] = true
        return badge
    end
    if opts.studio then
        local settingsFile = assert(loadfile("Shared/Settings/Settings.lua"))
        setfenv(settingsFile, env)
        settingsFile()
    end
    local chunk = assert(loadstring(source)); setfenv(chunk, env)
    chunk()
    if opts.studio then cards = ns.Shared.Settings.pages["QoL/Loot & Items"].cards end

    local t = { ns = ns, printed = printed, env = env, buttons = buttons, Parts = Parts, tags = tags, tipLines = tipLines,
        border = border,
        Style = ns.Shared.Style, cards = cards, settings = settings }
    function t.Made() return made end
    function t.Fire(event, ...)
        for frame in pairs(registered[event] or {}) do frame.OnEvent(frame, event, ...) end
    end
    -- What the row shows, left to right: "Stack" for the header's Stack button, then item names.
    function t.Row()
        local out = {}
        if not (buttons.row and buttons.row.shown) then return "" end
        if buttons.row.stack.shown then out[1] = "Stack" end
        for _, b in ipairs(buttons) do
            if b.shown and b.pick then
                out[#out + 1] = b.pick.stack and "Stack" or ITEMS[b.pick.itemID][1]
            end
        end
        return table.concat(out, ", ")
    end
    function t.FreeText()
        return buttons.row and buttons.row.free and buttons.row.free.text.text
    end
    -- Scrap Marker's "+N" beside the count, nil while hidden.
    function t.ScrapText()
        local scrap = buttons.row.free.scrap
        return scrap.shown and scrap.text or nil
    end
    function t.ClickStack()
        buttons.row.stack._onClick()
    end
    function t.Button(i)
        local n = 0
        for _, b in ipairs(buttons) do
            if b.shown and b.pick then
                n = n + 1
                if n == i then return b end
            end
        end
    end
    function t.Click(i, mouse, withCtrl)
        ctrl = withCtrl or false
        local b = t.Button(i)
        b.OnClick(b, mouse or "LeftButton")
        ctrl = false
    end
    function t.Count(id)
        local n = 0
        for bag = 0, #bags do
            for slot = 1, bags[bag].size do
                local it = bags[bag][slot]
                if it and it.id == id then n = n + it.count end
            end
        end
        return n
    end
    function t.Slots(id)
        local n = 0
        for bag = 0, #bags do
            for slot = 1, bags[bag].size do
                if bags[bag][slot] and bags[bag][slot].id == id then n = n + 1 end
            end
        end
        return n
    end
    t.db, t.Set = db, S.Set
    -- The world loads: the module builds and scans.
    for frame in pairs(registered.PLAYER_LOGIN or {}) do frame.OnEvent(frame, "PLAYER_LOGIN") end
    return t
end

local failures = 0
local function Check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(("FAIL %s\n  got:  %s\n  want: %s"):format(label, tostring(got), tostring(want)))
    end
end

local function Bag(size, items)
    local bag = { size = size }
    for slot, it in pairs(items) do bag[slot] = { id = it[1], count = it[2] } end
    return bag
end

-- Cheapest stack first; protected, priceless and too-good items never offered.
do
    local t = Fixture({ bags = { [0] = Bag(16, {
        { 3, 2 }, { 1, 3 }, { 2, 11 }, { 4, 2 }, { 5, 10 }, { 6, 1 }, { 7, 1 }, { 8, 1 },
    }) } })
    Check("cheapest stack first", t.Row(), "Small Egg, Coyote Meat, Chipped Boar Tusk, Light Feather")
    Check("counter reads free out of total", t.FreeText(), "8/16")
end

-- Poor and Common items keep the house 1px black edge; only Uncommon and better show their color.
do
    local t = Fixture({ bags = { [0] = Bag(16, { { 4, 2 }, { 1, 3 } }) } })
    Check("Poor and Common items keep the black edge, not their quality color",
        t.Row() .. " " .. tostring(t.border.white == true), "Small Egg, Chipped Boar Tusk false")
end

-- Scrap Marker's scrap keeps the cheapest-first order and the quality limit; only the counter
-- shows the slots it frees at the next vendor. With Scrap Marker off, there's no +N.
do
    local scrap = { on = true, ids = { [3] = true, [8] = true } }
    scrap.On = function() return scrap.on end
    scrap.IsScrap = function(id) return scrap.on and scrap.ids[id] == true end
    local t = Fixture({ scrap = scrap, bags = { [0] = Bag(16, { { 3, 2 }, { 1, 3 }, { 4, 2 }, { 8, 1 } }) } })
    Check("scrap is not moved first or let past the quality limit", t.Row(),
        "Small Egg, Chipped Boar Tusk, Light Feather")
    Check("header: free out of total", t.FreeText(), "12/16")
    Check("header: slots scrap frees", t.ScrapText(), "+2")
    scrap.on = false
    t.ns.BagSpaceRescan()
    Check("Scrap Marker off: the usual order", t.Row(), "Small Egg, Chipped Boar Tusk, Light Feather")
    Check("Scrap Marker off: the usual counter", t.FreeText(), "12/16")
    Check("Scrap Marker off: no +N", t.ScrapText(), nil)
end

-- Grey Items First puts the tusk ahead of everything.
do
    local t = Fixture({ settings = { bagSpaceJunkFirst = true },
        bags = { [0] = Bag(16, { { 3, 2 }, { 1, 3 }, { 4, 2 } }) } })
    Check("grey first", t.Row(), "Chipped Boar Tusk, Small Egg, Light Feather")
end

-- An auction price above the vendor price values the stack at the auction price.
do
    local t = Fixture({ ah = { [1] = 500 }, bags = { [0] = Bag(16, { { 1, 3 }, { 2, 11 } }) } })
    Check("auction value counts", t.Row(), "Coyote Meat, Small Egg")
end

-- BiS items are protected; outlevelled food is marked old and can go first.
do
    local t = Fixture({ bis = { [2] = true }, settings = { bagSpaceOldFirst = true },
        bags = { [0] = Bag(16, { { 1, 3 }, { 2, 11 }, { 9, 20 } }) } })
    Check("BiS protected, old food first", t.Row(), "Tough Jerky, Small Egg")
    Check("old flag", t.Button(1).pick.old, true)
end

-- Ctrl-click deletes; middle-click ignores with the time it happened.
do
    local t = Fixture({ bags = { [0] = Bag(16, { { 1, 3 }, { 2, 11 } }) } })
    t.Click(1, "LeftButton", true)
    t.Fire("BAG_UPDATE_DELAYED")
    Check("ctrl-click deleted the eggs", t.Count(1), 0)
    Check("deleted message", t.printed[#t.printed]:find("^deleted") ~= nil, true)
    t.Click(1, "MiddleButton")
    Check("middle-click ignores with a time", type(t.db.bagSpaceIgnore[2]), "number")
    Check("ignored item leaves the row", t.Row(), "")
end

-- An unfinished quest objective flags its item, puts it last and asks for a second Ctrl-click;
-- a finished objective, or a count-first objective text, is read the same way.
do
    local t = Fixture({
        quests = {
            { title = "Westfall Stew", objectives = {
                { type = "item", text = "Small Egg: 1/3", finished = false, numFulfilled = 1, numRequired = 3 },
                { type = "item", text = "Coyote Meat: 5/5", finished = true, numFulfilled = 5, numRequired = 5 },
            } },
            { title = "Linen Trouble", objectives = {
                { type = "item", text = "2/6 Linen Cloth", finished = false, numFulfilled = 2, numRequired = 6 },
            } },
        },
        bags = { [0] = Bag(16, { { 1, 3 }, { 2, 11 }, { 10, 1 } }) },
    })
    Check("quest items go last", t.Row(), "Coyote Meat, Small Egg, Linen Cloth")
    Check("badge on a quest item", t.Button(2).quest.shown, true)
    Check("no badge on a finished objective", t.Button(1).quest.shown, false)
    t.Click(2, "LeftButton", true)
    Check("first ctrl-click only warns", t.Count(1), 3)
    Check("warning names the quest", t.printed[#t.printed]:find("Westfall Stew %(1/3%)") ~= nil, true)
    t.Click(2, "LeftButton", true)
    t.Fire("BAG_UPDATE_DELAYED")
    Check("second ctrl-click deletes", t.Count(1), 0)
end

-- Uncommon and better only go on the cursor, so the game's own delete confirmation applies.
do
    local t = Fixture({ bags = { [0] = Bag(16, { { 11, 1 } }) } })
    t.Click(1, "LeftButton", true)
    Check("uncommon is picked up, not deleted", select(2, t.env.GetCursorInfo()), 11)
    Check("ground hint", t.printed[#t.printed]:find("is on your cursor") ~= nil, true)
end

-- Unlock Mode shows your own items where you have them, and the sample question mark only in
-- the slots left over, with your real free-slot count.
do
    local bags = { [0] = Bag(16, { { 1, 3 }, { 2, 11 } }) }
    local t = Fixture({ bags = bags })
    local free = t.FreeText()
    t.ns.ShowUnlockMode()
    local icons = {}
    for _, b in ipairs(t.buttons) do
        if b.shown and b.icon then icons[#icons + 1] = b.icon.texture end
    end
    Check("unlock: four slots shown", #icons, 4)
    Check("unlock: your items first", type(icons[1]) == "number" and type(icons[2]) == "number", true)
    Check("unlock: a sample only where you have no item",
        icons[3] == "Interface\\Icons\\INV_Misc_QuestionMark" and icons[4] == icons[3], true)
    Check("unlock: your real free slots", t.FreeText(), free)
end

-- The key binding redraws the row from the scan it acts on, so icons match their items.
do
    local bags = { [0] = Bag(16, { { 1, 3 }, { 2, 11 }, { 3, 2 } }) }
    local t = Fixture({ bags = bags })
    bags[0][1] = nil   -- the eggs are gone, with no bag event yet
    t.env.NaowhForever_BagSpacePickUp()
    Check("binding picks up the cheapest", select(2, t.env.GetCursorInfo()), 2)
    for i = 1, 2 do
        local b = t.Button(i)
        Check("icon " .. i .. " matches its item", b.icon.texture, b.pick.itemID)
    end
end

-- Stacking starts from a fresh scan: a stack moved by hand since the row was drawn is found
-- where it is now, and the item put in its old slot stays put.
do
    local bags = { [0] = Bag(16, { { 1, 3 }, { 1, 5 }, { 2, 11 } }) }
    local t = Fixture({ bags = bags })
    bags[0][4], bags[0][1] = bags[0][1], { id = 10, count = 3 }
    t.ClickStack()
    for _ = 1, 5 do t.Fire("BAG_UPDATE_DELAYED") end
    Check("linen left alone", bags[0][1] and bags[0][1].id, 10)
    Check("moved eggs merged", t.Slots(1), 1)
    Check("no moved eggs lost", t.Count(1), 8)
end

-- Two part-filled egg stacks: a Stack button that merges them into one slot.
do
    local t = Fixture({ bags = { [0] = Bag(16, { { 1, 3 }, { 1, 5 }, { 2, 11 } }) } })
    Check("stack button first", t.Row():match("^[^,]+"), "Stack")
    Check("stack button says what it frees", t.buttons.row.stack.label.text, "Stack +1")
    t.ClickStack()
    for _ = 1, 5 do t.Fire("BAG_UPDATE_DELAYED") end
    Check("eggs merged into one slot", t.Slots(1), 1)
    Check("no eggs lost", t.Count(1), 8)
    Check("stack message", t.printed[#t.printed], "stacked your bags: 1 slot freed.")
end

-- A threshold hides the row until an "Inventory is full" error brings it up.
do
    local t = Fixture({ settings = { bagSpaceFreeBelow = 3 },
        bags = { [0] = Bag(16, { { 1, 3 }, { 2, 11 } }) } })
    Check("hidden with room to spare", t.Row(), "")
    t.Fire("UI_ERROR_MESSAGE", 0, "Inventory is full.")
    Check("shown after inventory full", t.Row(), "Small Egg, Coyote Meat")
end

-- The card's look: the outlevelled clock and the quest "!" are the shared corner badges, the
-- game's own atlases on a dark round backing, no text; the stack count is the shared marks'
-- number, prices are the shared compact coins centred under each icon, the text has the house
-- shadow and no outline, and the free count is colored by how full the bags are.
do
    local t = Fixture({
        settings = { bagSpaceOldFirst = true },
        quests = { { title = "Linen Trouble", objectives = {
            { type = "item", text = "2/6 Linen Cloth", finished = false, numFulfilled = 2, numRequired = 6 },
        } } },
        bags = { [0] = Bag(16, { { 9, 20 }, { 1, 3 }, { 10, 1 } }) },
    })
    local St, Parts, T = t.Style, t.Parts, t.ns.THEME
    Check("look: the order", t.Row(), "Tough Jerky, Small Egg, Linen Cloth")
    local old, egg, quest = t.Button(1), t.Button(2), t.Button(3)
    Check("look: the old mark is a shared badge", t.tags[old.old] and old.old.shown, true)
    Check("look: a clock from the game's atlas", old.old.art.atlas, St.CLOCK_ATLAS)
    Check("look: the clock atlas", St.CLOCK_ATLAS, "auctionhouse-icon-clock")
    Check("look: the white clock tinted the warning color", old.old.art.vr == St.WARN_RGB.r
        and old.old.art.vg == St.WARN_RGB.g and old.old.art.vb == St.WARN_RGB.b, true)
    Check("look: no text on the badge", old.old.text, nil)
    Check("look: in the top-left corner", old.old.point, "TOPLEFT")
    Check("look: about 12px of art on a 14px round backing", old.old.art.w == 12 and old.old.w == 14
        and old.old.back.texture == St.ROUND, true)
    Check("look: the backing dark, in the house edge color", old.old.back.vr == St.BORDER_RGB.r
        and old.old.back.va == 0.75, true)
    Check("look: no clock on fresh food", egg.old.shown, false)
    Check("look: the quest mark is a shared badge", t.tags[quest.quest] and quest.quest.shown, true)
    Check("look: the game's quest bang", quest.quest.art.atlas, St.QUEST_ATLAS)
    Check("look: the quest bang atlas", St.QUEST_ATLAS, "smallquestbang")
    Check("look: its own gold, untinted", quest.quest.art.vr, nil)
    Check("look: in the top-right corner", quest.quest.point, "TOPRIGHT")
    Check("look: no OLD or ! text left", source:find('"OLD"', 1, true) == nil and source:find('"!"', 1, true) == nil, true)
    local function TipHas(cell, atlas, words)
        cell.OnEnter(cell)
        for _, line in ipairs(t.tipLines) do
            if type(line.text) == "string" and line.text:find("|A:" .. atlas .. ":", 1, true)
                and line.text:find(words, 1, true) then return line end
        end
    end
    local oldTip = TipHas(old, St.CLOCK_ATLAS, "Outlevelled: 10 or more levels below you")
    Check("look: the tooltip explains the clock, with it", oldTip ~= nil, true)
    Check("look: in the warning color", oldTip and oldTip.r == St.WARN_RGB.r, true)
    Check("look: the clock in the tooltip tinted too", oldTip and oldTip.text:find(":251:146:60|a", 1, true) ~= nil, true)
    Check("look: the tooltip explains the bang", TipHas(quest, St.QUEST_ATLAS, "Needed for Linen Trouble (2/6)") ~= nil, true)
    Check("look: no clock line on fresh food", TipHas(egg, St.CLOCK_ATLAS, "Outlevelled"), nil)
    Check("look: stack count in the shared marks", old.marks.level.text, 20)
    Check("look: no count on a single item", quest.marks.level.text, "")
    Check("look: price from the shared coins", old.price.text, Parts.Coins(20, true))
    Check("look: the coins are the game's", old.price.text, CoinString(20))
    Check("look: compact coins keep the largest, to the nearest", Parts.Coins(12345, true), CoinString(10000))
    Check("look: silver to the nearest", Parts.Coins(236, true), CoinString(200))
    Check("look: half a silver rounds up", Parts.Coins(250, true), CoinString(300))
    Check("look: copper as it is", Parts.Coins(95, true), CoinString(95))
    Check("look: the full amount without compact", Parts.Coins(236), CoinString(236))
    Check("look: the price centred under its icon", old.price.point == "TOP" and old.price.x == 0
        and old.price.y == -3, true)
    Check("look: cells as wide as the icons, evenly spaced", egg.x - old.x == 36 + 6 and quest.x - egg.x == 36 + 6, true)
    Check("look: prices muted", old.price.color, T.muted)
    Check("look: no own money formatter", source:find("Money(", 1, true), nil)
    local free = t.buttons.row.free
    for _, text in ipairs({ old.price, free.text, free.word, free.scrap }) do
        Check("look: no outline", text.flags, "")
        Check("look: the Addon Font", text.font, "addon-font")
        Check("look: the house shadow", text.shadowX == St.HUD_SHADOW_X and text.shadowY == St.HUD_SHADOW_Y, true)
    end
    Check("look: room to spare in the text color", free.text.r, T.fg.r)
    local backdrop = t.buttons.row.backdrop
    Check("look: the card is the shared HUD backdrop", backdrop and backdrop.mode, "card")
    Check("look: the card and its edge shown", backdrop.fill.shown and backdrop.border._frame.shown, true)
    Check("look: no soft fade made until it is picked", backdrop.soft, nil)
    Check("look: the card wraps the row", t.buttons.row.card.w, 3 * 36 + 2 * 6 + 2 * 6)
    t.Set("bagSpaceSize", 24)
    Check("look: small icons close up, the price narrower with them", egg.x - old.x, 24 + 4)
    t.Set("bagSpaceSize", 16)
    Check("look: the gap keeps a floor", egg.x - old.x, 16 + 3)
    t.Set("bagSpaceSize", 36)
    t.Set("bagSpacePrices", false)
    Check("look: Show Prices off", old.price.shown, false)
    t.Set("bagSpaceGrow", "DOWN")
    Check("look: down, one under another", egg.x == 0 and egg.y < 0, true)
end

-- Reverse Order: the cheapest sits at the far end, the card and its anchor stay put.
do
    local bags = { [0] = Bag(16, { { 9, 20 }, { 1, 3 }, { 2, 4 }, { 3, 5 } }) }
    for dir, step in pairs({ RIGHT = { 1, 0 }, LEFT = { -1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }) do
        local t = Fixture({ settings = { bagSpaceCount = 3, bagSpaceGrow = dir }, bags = bags })
        local row = t.buttons.row
        local first, last = row.cells[1], row.cells[3]
        local card, cheapest = { row.card.w, row.card.h, row.cardX, row.cardY }, first.price.text
        Check("reverse " .. dir .. ": cheapest next to the anchor by default", first.x == 0 and first.y == 0, true)
        local span = (last.x - first.x) * step[1] + (last.y - first.y) * step[2]
        Check("reverse " .. dir .. ": later cells step away", span > 0, true)
        t.Set("bagSpaceReverse", true)
        Check("reverse " .. dir .. ": the last cell takes the anchor", last.x == 0 and last.y == 0, true)
        Check("reverse " .. dir .. ": the cheapest a full span away",
            first.x == span * step[1] and first.y == span * step[2], true)
        Check("reverse " .. dir .. ": still the cheapest in cell 1", first.price.text, cheapest)
        Check("reverse " .. dir .. ": the card is the same", row.card.w == card[1] and row.card.h == card[2]
            and row.cardX == card[3] and row.cardY == card[4], true)
    end
end

-- Count Filled Slots, Slot Count on the Right and Larger Cheapest Icon: off as before, each changes only its own part.
do
    local scrap = { ids = { [3] = true } }
    scrap.On = function() return true end
    scrap.IsScrap = function(id) return scrap.ids[id] == true end
    local t = Fixture({ scrap = scrap, bags = { [0] = Bag(16, { { 3, 2 }, { 1, 3 }, { 4, 2 } }) } })
    local row = t.buttons.row
    local first, second = row.cells[1], row.cells[2]
    local w, h = row.card.w, row.card.h
    Check("free by default", t.FreeText() .. " " .. row.free.word.text .. " " .. t.ScrapText(), "13/16 free +1")
    Check("count left, Stack right by default", row.free.point .. " " .. row.stack.point, "TOPLEFT TOPRIGHT")
    Check("every icon one size by default", first.w == 36 and second.x == 36 + 6, true)
    t.Set("bagSpaceShowFilled", true)
    Check("filled: used out of total, the junk sale counting down",
        t.FreeText() .. " " .. row.free.word.text .. " " .. t.ScrapText(), "3/16 filled -1")
    t.Set("bagSpaceFreeRight", true)
    Check("count right, Stack left", row.free.point .. " " .. row.stack.point, "TOPRIGHT TOPLEFT")
    t.Set("bagSpaceShowFree", false)
    Check("no count shown: Stack back on the right", row.stack.point, "TOPRIGHT")
    t.Set("bagSpaceShowFree", true)
    t.Set("bagSpaceBigCheapest", true)
    Check("larger: the cheapest a size up, the rest as they were", first.w .. " " .. second.w, "46 36")
    Check("larger: its near edge where it was", first.x - first.w / 2, -18)
    Check("larger: the next icon moved over by the difference", second.x, 36 + 6 + 10)
    Check("larger: the card grows to fit", row.card.w == w + 10 and row.card.h == h + 10, true)
    t.Set("bagSpaceReverse", true)
    Check("larger, reversed: the cheapest at the far end", first.x - first.w / 2, 2 * (36 + 6) - 18)
    Check("larger, reversed: the others keep the anchor", row.cells[3].x, 0)
    t.Set("bagSpaceGrow", "DOWN")
    t.Set("bagSpaceReverse", false)
    Check("larger, down: the next icon below the larger one", row.cells[2].y, -(36 + 3 + 12 + 6) - 10)
    Check("larger, down: the card as wide as the larger icon", row.card.w >= 46 + 2 * 6, true)
end

-- Background: the card by default; Soft swaps it for the shared fade with the stronger shadow on
-- the header and the prices, cells made afterwards too; None shows neither, the icons keep their
-- edges; and a scan in either makes no garbage.
do
    local t = Fixture({ settings = { bagSpaceCount = 2 },
        bags = { [0] = Bag(16, { { 9, 20 }, { 1, 3 }, { 2, 4 }, { 3, 5 }, { 10, 1 }, { 4, 2 } }) } })
    local St, row = t.Style, t.buttons.row
    local backdrop, free = row.backdrop, row.free
    local function Texts()
        local list = { free.text, free.word, free.scrap }
        for _, b in ipairs(row.cells) do list[#list + 1] = b.price end
        return list
    end
    local function AllShadow(x, y, a)
        for _, text in ipairs(Texts()) do
            if text.flags ~= "" or text.shadowX ~= x or text.shadowY ~= y or text.shadowA ~= a then return false end
        end
        return true
    end
    local function SoftShown(on)
        if not backdrop.soft then return not on end
        for _, tex in ipairs(backdrop.soft) do
            if tex.shown ~= on then return false end
        end
        return true
    end
    Check("background: Card by default", backdrop.mode == "card" and backdrop.fill.shown
        and backdrop.border._frame.shown, true)
    Check("background: the card's alpha", St.HUD_CARD_ALPHA, 0.85)
    Check("background: the house shadow on the card", AllShadow(St.HUD_SHADOW_X, St.HUD_SHADOW_Y, St.HUD_SHADOW_ALPHA), true)
    t.Set("bagSpaceBackground", "soft")
    Check("background: Soft hides the card and its edge", backdrop.fill.shown or backdrop.border._frame.shown, false)
    Check("background: Soft is nine pieces of the round shade", backdrop.soft and #backdrop.soft, 9)
    Check("background: all shown", SoftShown(true), true)
    local shade = true
    for _, tex in ipairs(backdrop.soft) do
        if tex.texture ~= St.SOFT_SHADE or tex.va ~= St.HUD_SOFT_ALPHA or tex.vr ~= t.ns.THEME.bg.r then shade = false end
    end
    Check("background: the shade in the theme's background, at the soft alpha", shade, true)
    Check("background: Soft's stronger shadow, no outline", AllShadow(St.HUD_SHADOW_X, St.HUD_SHADOW_Y,
        St.HUD_SOFT_SHADOW_ALPHA), true)
    local cells = #row.cells
    t.Set("bagSpaceCount", 6)
    Check("background: more cells made in Soft", #row.cells > cells, true)
    Check("background: a cell made in Soft gets its shadow", AllShadow(St.HUD_SHADOW_X, St.HUD_SHADOW_Y,
        St.HUD_SOFT_SHADOW_ALPHA), true)
    local pieces = backdrop.soft
    t.Set("bagSpaceBackground", "none")
    Check("background: None shows no card", backdrop.fill.shown or backdrop.border._frame.shown, false)
    Check("background: and no fade", SoftShown(false) and backdrop.soft == pieces, true)
    Check("background: None's shadow, no outline", AllShadow(St.HUD_BARE_SHADOW_X, St.HUD_BARE_SHADOW_Y,
        St.HUD_BARE_SHADOW_ALPHA), true)
    Check("background: the icons keep their edges", row.cells[1].edge._frame ~= nil and row.cells[1].edge._frame.shown, true)
    for _, mode in ipairs({ "soft", "none" }) do
        t.Set("bagSpaceBackground", mode)
        for _ = 1, 50 do t.Fire("BAG_UPDATE_DELAYED") end
        collectgarbage("collect")
        collectgarbage("stop")
        local kb = collectgarbage("count")
        for _ = 1, 500 do t.Fire("BAG_UPDATE_DELAYED") end
        local grown = collectgarbage("count") - kb
        collectgarbage("restart")
        Check("background: no garbage per scan in " .. mode, grown / 500 < 0.05, true)
    end
    t.Set("bagSpaceBackground", "card")
    Check("background: back to the card", backdrop.fill.shown and backdrop.border._frame.shown and SoftShown(false), true)
    Check("background: the house shadow again", AllShadow(St.HUD_SHADOW_X, St.HUD_SHADOW_Y, St.HUD_SHADOW_ALPHA), true)
    local qol = io.open("Core/Settings.lua", "rb")
    local defaults = qol:read("*a"); qol:close()
    Check("background: Card by default in the settings", defaults:find('bagSpaceBackground = "card"', 1, true) ~= nil, true)
end

-- Text: today's look by default (the Addon Font, 12 in the header and 10 under the icons, the
-- header 16 tall, no outline); Font, Font Size and Outline reach the header and the prices, the
-- header line, the bag and the price room scale with the size, and a scan after a change makes
-- no garbage.
do
    local t = Fixture({ settings = { bagSpaceCount = 2 }, bags = { [0] = Bag(16, { { 1, 3 }, { 2, 4 }, { 4, 2 } }) } })
    local row = t.buttons.row
    local free, price = row.free, row.cells[1].price
    Check("text: header at 12 by default", free.text.size == 12 and free.word.size == 12 and free.scrap.size == 12, true)
    Check("text: prices at 10 by default", price.size, 10)
    Check("text: the header line 16 tall", free.h == 16 and row.stack.h == 16, true)
    Check("text: the bag 12 wide", free.icon.w, 12)
    Check("text: cells 36 apart with prices", row.cells[2].x - row.cells[1].x, 36 + 6)
    Check("text: the card under the header", row.card.h, 16 + 5 + 36 + 3 + 12 + 6 * 2)
    t.Set("bagSpaceFont", "Friz Quadrata TT")
    Check("text: Font on the header", free.text.font, "Friz Quadrata TT")
    Check("text: Font on the prices", price.font, "Friz Quadrata TT")
    t.Set("bagSpaceFontSize", 18)
    Check("text: Font Size on the header", free.text.size, 18)
    Check("text: the prices scale with it", price.size, 15)
    Check("text: the header line too", free.h == 24 and row.stack.h == 24, true)
    Check("text: and the bag", free.icon.w, 18)
    Check("text: the price room grows", row.card.h, 24 + 5 + 36 + 3 + 18 + 6 * 2)
    Check("text: wide prices widen the cells", row.cells[2].x - row.cells[1].x, 48 + 6)
    t.Set("bagSpaceOutline", "THICKOUTLINE")
    Check("text: Outline on the header", free.word.flags, "THICKOUTLINE")
    Check("text: Outline on the prices", price.flags, "THICKOUTLINE")
    Check("text: outlined text drops the shadow", price.shadowA, 0)
    t.Set("bagSpaceCount", 3)
    Check("text: a cell made later gets the look", row.cells[3].price.size == 15
        and row.cells[3].price.flags == "THICKOUTLINE" and row.cells[3].price.font == "Friz Quadrata TT", true)
    for _ = 1, 50 do t.Fire("BAG_UPDATE_DELAYED") end
    collectgarbage("collect")
    collectgarbage("stop")
    local kb = collectgarbage("count")
    for _ = 1, 500 do t.Fire("BAG_UPDATE_DELAYED") end
    local grown = collectgarbage("count") - kb
    collectgarbage("restart")
    Check("text: no garbage per scan", grown / 500 < 0.05, true)
    local qol = io.open("Core/Settings.lua", "rb")
    local defaults = qol:read("*a"); qol:close()
    Check("text: today's look in the settings", defaults:find('bagSpaceFont = "", bagSpaceFontSize = 12, '
        .. 'bagSpaceOutline = ""', 1, true) ~= nil, true)
end

-- Few slots free: the count turns orange; none: red.
do
    local function Filled(n)
        local items = {}
        for slot = 1, n do items[slot] = { 1, 1 } end
        return Fixture({ bags = { [0] = Bag(16, items) } })
    end
    local low, full = Filled(15), Filled(16)
    Check("low: one free", low.FreeText(), "1/16")
    Check("low: orange", low.buttons.row.free.text.r, low.Style.WARN_RGB.r)
    Check("full: none free", full.FreeText(), "0/16")
    Check("full: red", full.buttons.row.free.text.r, full.Style.RED_RGB.r)
end

-- The settings card's preview: nothing built until the card opens (and nothing at all while Bag
-- Space is off), then the same card from the addon's samples, following Items Shown, Highest
-- Quality Offered, Icon Size, Direction, the sort settings, Offer to Stack and Show Free Slots,
-- with Low and Full states, a hover that acts on nothing, and no garbage per paint.
do
    local t = Fixture({ studio = true, settings = { bagSpace = false }, bags = { [0] = Bag(16, { { 1, 3 } }) } })
    local studio = t.cards.bagSpace and t.cards.bagSpace.studio
    Check("studio: declared on the card", studio ~= nil, true)
    Check("studio: no card while Bag Space is off", t.buttons.row, nil)
    local before = t.Made()
    local stage = t.env.CreateFrame("Frame")
    local preview = studio.new(stage)
    Check("studio: built when the card opens", t.Made() > before + 1, true)
    preview.w, preview.h = 500, studio.height
    local view = preview.view
    local function Names()
        local out = {}
        for _, b in ipairs(view.cells) do
            if b.shown then out[#out + 1] = b.pick.name end
        end
        return table.concat(out, ", ")
    end
    studio.paint(preview, "bags")
    Check("studio: cheapest first, the quest item last", Names(),
        "Worn Leather Pants, Ruined Pelt, Tough Jerky, Linen Cloth")
    Check("studio: the free count", view.free.text.text, "28/52")
    Check("studio: Scrap Marker's +N", view.free.scrap.text, "+2")
    Check("studio: the Stack button", view.stack.shown, true)
    Check("studio: the clock on the jerky", view.cells[3].old.shown and view.cells[3].old.art.atlas == t.Style.CLOCK_ATLAS, true)
    Check("studio: the quest mark on the linen", view.cells[4].quest.shown, true)
    Check("studio: prices from the shared coins", view.cells[1].price.text, t.Parts.Coins(150, true))
    local made = t.Made()
    studio.paint(preview, "bags")
    Check("studio: a repaint makes no frames", t.Made(), made)
    t.Set("bagSpaceCount", 2)
    studio.paint(preview, "bags")
    Check("studio: Items Shown", Names(), "Worn Leather Pants, Ruined Pelt")
    t.Set("bagSpaceCount", 8)
    t.Set("bagSpaceMaxQuality", 0)
    studio.paint(preview, "bags")
    Check("studio: Highest Quality Offered", Names(), "Ruined Pelt")
    t.Set("bagSpaceMaxQuality", 3)
    t.Set("bagSpaceJunkFirst", true)
    studio.paint(preview, "bags")
    Check("studio: Grey Items First", Names(), "Ruined Pelt, Worn Leather Pants, Tough Jerky, Jade Ring, Linen Cloth")
    t.Set("bagSpaceJunkFirst", false)
    t.Set("bagSpaceOldFirst", true)
    studio.paint(preview, "bags")
    Check("studio: Outlevelled First", Names():match("^[^,]+"), "Tough Jerky")
    t.Set("bagSpaceSize", 48)
    t.Set("bagSpaceGrow", "UP")
    studio.paint(preview, "bags")
    Check("studio: Icon Size", view.cells[1].w, 48)
    Check("studio: Direction", view.cells[2].x == 0 and view.cells[2].y > 0, true)
    Check("studio: shrunk to fit the stage", view.scale < 1, true)
    t.Set("bagSpaceStack", false)
    studio.paint(preview, "bags")
    Check("studio: Offer to Stack off", view.stack.shown, false)
    studio.paint(preview, "low")
    Check("studio: Low", view.free.text.text, "4/52")
    Check("studio: Low in orange", view.free.text.r, t.Style.WARN_RGB.r)
    studio.paint(preview, "full")
    Check("studio: Full", view.free.text.text, "0/52")
    Check("studio: Full in red", view.free.text.r, t.Style.RED_RGB.r)
    Check("studio: Low and Full need the free count", studio.states[2].needs == "bagSpaceShowFree"
        and studio.states[3].needs == "bagSpaceShowFree", true)
    t.Set("bagSpaceShowFree", false)
    studio.paint(preview, "bags")
    Check("studio: Show Free Slots off", view.free.shown, false)
    view.cells[1].OnEnter(view.cells[1])
    Check("studio: a sample only shows a tooltip", rawget(view.cells[1], "OnClick"), nil)
    Check("studio: the card by default", view.backdrop.mode == "card" and view.backdrop.fill.shown, true)
    t.Set("bagSpaceBackground", "soft")
    studio.paint(preview, "bags")
    Check("studio: Soft in the preview", view.backdrop.mode == "soft" and view.backdrop.fill.shown == false
        and view.backdrop.soft ~= nil and view.backdrop.soft[1].shown, true)
    Check("studio: its prices with Soft's shadow", view.cells[1].price.shadowA, t.Style.HUD_SOFT_SHADOW_ALPHA)
    t.Set("bagSpaceBackground", "none")
    studio.paint(preview, "bags")
    Check("studio: None in the preview", view.backdrop.mode == "none" and view.backdrop.fill.shown == false
        and view.backdrop.soft[1].shown == false, true)
    t.Set("bagSpaceBackground", "card")
    studio.paint(preview, "bags")
    local rows = {}
    for _, r in ipairs(t.cards.bagSpace.rows) do
        if r.key then rows[r.key] = r end
    end
    local bg = rows.bagSpaceBackground
    Check("studio: Background is a choice", bg and bg.choice == t.Parts.HUD_BACKGROUNDS and bg.label, "Background")
    Check("studio: its help one short sentence", bg.help and #bg.help < 100 and not bg.help:find("%. %u"), true)
    local group, groups, groupOf = nil, {}, {}
    for _, r in ipairs(t.cards.bagSpace.rows) do
        if r.group then
            group = r.group
            groups[#groups + 1] = group
        elseif r.key then
            groupOf[r.key] = group
        end
    end
    Check("studio: the standard groups after its own", table.concat(groups, ", "),
        "Offered, Showing, Tooltips, Size, Text, Background, Visibility")
    Check("studio: Background in the Background group", groupOf.bagSpaceBackground, "Background")
    Check("studio: Font, Font Size and Outline in Text", groupOf.bagSpaceFont == "Text"
        and groupOf.bagSpaceFontSize == "Text" and groupOf.bagSpaceOutline == "Text", true)
    Check("studio: Outline is the shared choice", rows.bagSpaceOutline.choice, t.Parts.HUD_OUTLINES)
    Check("studio: Hide in Combat under Visibility", groupOf.bagSpaceHideCombat, "Visibility")
    Check("studio: Icon Size under Size", groupOf.bagSpaceSize, "Size")
    t.Set("bagSpaceFontSize", 18)
    t.Set("bagSpaceOutline", "OUTLINE")
    studio.paint(preview, "bags")
    Check("studio: the preview follows Font Size", view.free.text.size, 18)
    Check("studio: and Outline", view.cells[1].price.flags, "OUTLINE")
    t.Set("bagSpaceFontSize", 12)
    t.Set("bagSpaceOutline", "")
    studio.paint(preview, "bags")
    for _ = 1, 20 do studio.paint(preview, "bags") end
    collectgarbage("collect")
    collectgarbage("stop")
    local kb = collectgarbage("count")
    for _ = 1, 500 do studio.paint(preview, "full") end
    local grown = collectgarbage("count") - kb
    collectgarbage("restart")
    Check("studio: no garbage per paint", grown / 500 < 0.05, true)
end

-- Cost: a full set of bags, scanned the way loot triggers it.
do
    local bags = { [0] = Bag(16, {}) }
    for b = 1, 4 do bags[b] = Bag(20, {}) end
    local n = 0
    for b = 0, 4 do
        for slot = 1, bags[b].size do
            n = n + 1
            local id = n % 10 + 1
            bags[b][slot] = { id = id, count = math.max(1, (n * 7) % ITEMS[id][4]) }
        end
    end
    local t = Fixture({ bags = bags })
    local SCANS = 2000
    for _ = 1, 50 do t.Fire("BAG_UPDATE_DELAYED") end   -- warm the pools
    collectgarbage("collect")
    collectgarbage("stop")
    local before, start = collectgarbage("count"), os.clock()
    for _ = 1, SCANS do t.Fire("BAG_UPDATE_DELAYED") end
    local elapsed, grown = os.clock() - start, collectgarbage("count") - before
    collectgarbage("restart")
    print(("bag space: %d slots, %.3f ms and %.2f KB per scan and redraw")
        :format(96, elapsed * 1000 / SCANS, grown / SCANS))
    Check("under 1 ms per scan", elapsed * 1000 / SCANS < 1, true)
    -- Pooled: once warm, a scan leaves nothing for the garbage collector.
    Check("no garbage per scan", grown / SCANS < 0.05, true)
end

-- Shift-click links through ChatFrameUtil: ChatEdit_InsertLink is a deprecated shim Forever
-- does not load, so a call to it does nothing there.
local deprecated = false
for line in source:gmatch("[^\n]+") do
    if not line:match("^%s*%-%-") and line:find("ChatEdit_", 1, true) then deprecated = true end
end
Check("no deprecated ChatEdit_ calls", deprecated, false)
Check("Shift-click links through ChatFrameUtil",
    source:find("ChatFrameUtil.InsertLink(p.link)", 1, true) ~= nil, true)

if failures > 0 then
    print(failures .. " failure(s)")
    os.exit(1)
end
print("test-bag-space: all passed")

-- Run with Lua 5.1 from the repository root: Quick Attach on the Send Mail tab attaches every stack
-- of the clicked category and nothing else, up to the 12 attachment slots. A tester's "Cloth" click
-- attached two stacks and stopped: MAIL_SEND_INFO_UPDATE is a synchronous, unique event on
-- Forever, so it fires inside ClickSendMailItemButton and not again for an attach made from its
-- own handler. The mail here works the same way, or lands each attachment later (async).
local path = arg and arg[1] or "NaowhForever_QoL/Loot/Mail.lua"

local CLOTH, METAL, OTHER = 5, 7, 11
local ITEMS = {
    [2592] = { 7, CLOTH, "Cloth" }, [2589] = { 7, CLOTH, "Cloth" }, [4306] = { 7, CLOTH, "Cloth" },
    [5498] = { 7, OTHER, "Other" }, [5500] = { 7, OTHER, "Other" },
    [2770] = { 7, METAL, "Metal & Stone" }, [2835] = { 7, METAL, "Metal & Stone" },
    [6060] = { 4, 2, "Leather" }, [6061] = { 4, 2, "Leather" },
}

local bags = { [0] = {}, [1] = {} }
local function Put(bag, slot, itemID, extra)
    local info = bags[bag][slot] or {}
    bags[bag][slot] = info
    info.itemID, info.isLocked, info.isBound, info.quality = itemID, false, false, 1
    if extra then
        info.isBound, info.quality = extra.isBound or false, extra.quality or 1
    end
    return info
end

local mail, mode, lastAttached = {}, "sync", 0
local cursorItem, cursorBag, cursorSlot
local landSlot, landItem
local swaps, printed = 0, {}
local frames, dispatching, buttons, menu = {}, {}, {}, {}
local settings = { enabled = true, mailQuickAttach = true }

local function Fire(event, ...)
    if dispatching[event] then return end
    dispatching[event] = true
    for _, f in ipairs(frames) do
        if f.events[event] and f.handler then f.handler(f, event, ...) end
    end
    dispatching[event] = false
end

local function Reset()
    for b = 0, 1 do for s in pairs(bags[b]) do bags[b][s] = nil end end
    for i = 1, 12 do mail[i] = nil end
    Put(0, 1, 2592); Put(0, 2, 5498); Put(0, 3, 2589); Put(0, 4, 2770)
    Put(0, 5, 4306); Put(0, 6, 5500); Put(0, 7, 2835)
    Put(0, 8, 6060, { isBound = true, quality = 2 }); Put(0, 9, 6061, { quality = 2 })
    Put(1, 2, 2592)
    cursorItem, cursorBag, cursorSlot, landSlot, landItem = nil, nil, nil, nil, nil
    swaps, lastAttached, mode = 0, 0, "sync"
    for k in pairs(printed) do printed[k] = nil end
    for k in pairs(dispatching) do dispatching[k] = nil end
end

local function Land()
    local slot, item = landSlot, landItem
    landSlot, landItem = nil, nil
    mail[slot] = item
    Fire("MAIL_SEND_INFO_UPDATE")
end

local env = {}
local function Frame()
    local f = { events = {}, shown = true }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(_, fn) self.handler = fn end
    function f:SetPoint() end
    function f:ClearAllPoints() end
    function f:SetShown(on) self.shown = on end
    function f:IsShown() return self.shown end
    return f
end

local root = {}
function root:CreateTitle(text) menu[#menu + 1] = { title = text } end
function root:CreateButton(text, fn) menu[#menu + 1] = { text = text, fn = fn } end

local function Load()
    for k in pairs(frames) do frames[k] = nil end
    local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        QoLSettings = { Get = function(key) return settings[key] end, Set = function() end },
        QoLConstants = dofile("Tools/regression/qol_constants.lua"),
        Color = function(_, text) return text end,
        Print = function(msg) printed[#printed + 1] = msg end,
        Button = function(_, text, _, _, onClick)
            local b = Frame()
            buttons[text] = onClick
            return b
        end,
        Tooltip = function() end,
        Apply = function() end,
        Shared = { Settings = { Page = function() return { Card = function() end } end } },
    }
    for k in pairs(env) do env[k] = nil end
    setmetatable(env, { __index = _G })
    env._G = env
    env.NaowhForever = ns
    env.Enum = { ItemClass = { Tradegoods = 7, Weapon = 2, Armor = 4 }, ItemQuality = { Uncommon = 2 } }
    env.CreateFrame = function()
        local f = Frame()
        frames[#frames + 1] = f
        return f
    end
    env.hooksecurefunc = function() end
    env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    env.BACKPACK_CONTAINER, env.NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0, 1
    env.WHITE_FONT_COLOR = {}
    env.SendMailFrame, env.MailFrame = Frame(), Frame()
    env.MenuUtil = { CreateContextMenu = function(owner, gen)
        for k in pairs(menu) do menu[k] = nil end
        gen(owner, root)
    end }
    env.C_Item = { GetItemInfoInstant = function(itemID)
        local d = ITEMS[itemID]
        return itemID, "Trade Goods", d[3], "", 0, d[1], d[2]
    end }
    env.C_Container = {
        GetContainerNumSlots = function(bag) return bag == 0 and 9 or 4 end,
        GetContainerItemID = function(bag, slot)
            local info = bags[bag][slot]
            return info and info.itemID or nil
        end,
        GetContainerItemInfo = function(bag, slot) return bags[bag][slot] end,
        PickupContainerItem = function(bag, slot)
            local info = bags[bag][slot]
            if cursorItem then swaps = swaps + 1 return end
            if not info or info.isLocked then return end
            info.isLocked = true
            cursorItem, cursorBag, cursorSlot = info.itemID, bag, slot
        end,
    }
    env.GetCursorInfo = function()
        if cursorItem then return "item", cursorItem, "link" end
    end
    env.ClearCursor = function()
        if cursorBag then bags[cursorBag][cursorSlot].isLocked = false end
        cursorItem, cursorBag, cursorSlot = nil, nil, nil
    end
    env.HasSendMailItem = function(i) return mail[i] ~= nil end
    env.GetSendMailItem = function(i) return "item", mail[i], 0, 1, 1 end
    env.ClickSendMailItemButton = function(i)
        if not cursorItem then return end
        if mail[i] or landSlot == i then swaps = swaps + 1 return end
        local item = cursorItem
        cursorItem, cursorBag, cursorSlot = nil, nil, nil
        lastAttached = item
        if mode == "sync" then
            mail[i] = item
            Fire("MAIL_SEND_INFO_UPDATE")
        else
            landSlot, landItem = i, item
        end
    end
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)
    chunk()
    frames[2].handler(frames[2], "PLAYER_LOGIN")
end

local function OpenMenu()
    buttons.Attach()
    return menu
end

local function Click(label)
    for _, e in ipairs(OpenMenu()) do
        if e.text and e.text:find(label, 1, true) == 1 then
            e.fn()
            return
        end
    end
    error("no menu entry " .. label)
end

local function Attached()
    local n, cloth = 0, 0
    for i = 1, 12 do
        if mail[i] then
            n = n + 1
            if ITEMS[mail[i]][2] == CLOTH and ITEMS[mail[i]][1] == 7 then cloth = cloth + 1 end
        end
    end
    return n, cloth
end

local count, failed = 0, 0
local function Case(name, fn)
    Reset()
    Load()
    local ok, err = pcall(fn)
    if ok then
        count = count + 1
        print("PASS " .. name)
    else
        failed = failed + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end

Case("menu counts stacks, says so, and leaves out bound and locked items", function()
    local texts = {}
    for _, e in ipairs(OpenMenu()) do if e.text then texts[#texts + 1] = e.text end end
    local all = table.concat(texts, " | ")
    assert(all:find("All trade goods (8 stacks)", 1, true), all)
    assert(all:find("Cloth (4 stacks)", 1, true), all)
    assert(all:find("Other (2 stacks)", 1, true), all)
    assert(all:find("Metal & Stone (2 stacks)", 1, true), all)
    assert(all:find("Unbound gear (1 stack)", 1, true), all)
end)

Case("synchronous event: a Cloth click attaches all 4 cloth stacks and nothing else", function()
    Click("Cloth")
    local n, cloth = Attached()
    assert(n == 4 and cloth == 4, ("attached %d, cloth %d"):format(n, cloth))
    assert(swaps == 0 and not cursorItem, "no swaps, cursor left empty")
end)

Case("after attaching, the menu shows only what is left", function()
    Click("Cloth")
    local texts = {}
    for _, e in ipairs(OpenMenu()) do if e.text then texts[#texts + 1] = e.text end end
    local all = table.concat(texts, " | ")
    assert(not all:find("Cloth", 1, true), all)
    assert(all:find("All trade goods (4 stacks)", 1, true), all)
end)

Case("async landing: one stack at a time, the next once the last has landed", function()
    mode = "async"
    Click("Cloth")
    for _ = 1, 4 do
        assert(landSlot, "an attachment is on its way")
        Land()
    end
    assert(not landSlot, "nothing more after the last cloth stack")
    local n, cloth = Attached()
    assert(n == 4 and cloth == 4, ("attached %d, cloth %d"):format(n, cloth))
    assert(swaps == 0, "never clicked a busy slot")
end)

Case("bags that change while waiting: a non-cloth item moved into a queued slot is skipped", function()
    mode = "async"
    Click("Cloth")
    Put(0, 3, 5498)
    while landSlot do Land() end
    local n, cloth = Attached()
    assert(n == 3 and cloth == 3, ("attached %d, cloth %d"):format(n, cloth))
end)

Case("12 slots: stops when full and says how many did not fit", function()
    for i = 1, 10 do mail[i] = 2770 end
    Click("All trade goods")
    local n = Attached()
    assert(n == 12, "filled to 12, got " .. n)
    assert(#printed == 1 and printed[1]:find("6 stacks didn't fit", 1, true), printed[1] or "no message")
end)

Case("closing the mailbox cancels the queue", function()
    mode = "async"
    Click("Cloth")
    Fire("MAIL_CLOSED")
    Land()
    assert(not landSlot and (Attached()) == 1, "only the stack already on its way")
end)

Case("sending the mail cancels the queue", function()
    mode = "async"
    Click("Cloth")
    Fire("MAIL_SEND_SUCCESS")
    Land()
    assert(not landSlot and (Attached()) == 1, "only the stack already on its way")
end)

Case("an item the player picks up meanwhile is left on the cursor", function()
    mode = "async"
    Click("Cloth")
    bags[0][9].isLocked = true
    cursorItem, cursorBag, cursorSlot = 6061, 0, 9
    Land()
    assert(cursorItem == 6061 and (Attached()) == 1 and not landSlot, "stopped, cursor untouched")
end)

Case("no garbage per attach step", function()
    mode = "async"
    Click("Cloth")
    while landSlot do Land() end
    Reset()
    mode = "async"
    Click("Cloth")
    collectgarbage("stop")
    local before = collectgarbage("count")
    Land()
    Land()
    local after = collectgarbage("count")
    collectgarbage("restart")
    assert(landSlot and lastAttached ~= 0, "still attaching")
    assert(after - before <= 0, ("%.3f KB per two steps"):format(after - before))
end)

collectgarbage("restart")
if failed > 0 then error(failed .. " mail attach regressions failed") end
print(count .. " mail attach regressions passed")

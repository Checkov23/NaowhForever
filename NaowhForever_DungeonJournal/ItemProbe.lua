-- ItemProbe.lua: /nf itemprobe: asks the server for every item the Journal lists, for Tools/sources/items_in_game.py.
local ns = _G.NaowhForever

local GetItemNameByID = C_Item.GetItemNameByID
local RequestLoadItemDataByID = C_Item.RequestLoadItemDataByID

local J = ns.Journal

local BATCH = 50
local WAIT = 5

local TEXT_DONE = "Item probe: %d items load, %d are not in Forever. /reload to save them, then run "
    .. "Tools/sources/items_in_game.py."
local TEXT_RUNNING = ns.L("Item probe: still running.")
local TEXT_ASKING = ns.L("Item probe: asking for %d items.")

local frame, queue, pending, loads, refused, at, waiting, generation
local running = false
local Next

local function Sorted(set)
    local list = {}
    for id in pairs(set) do list[#list + 1] = id end
    table.sort(list)
    return list
end

local function Count(set)
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    return n
end

local function Finish()
    running = false
    frame:UnregisterAllEvents()
    local _, build = GetBuildInfo()
    local sv = _G.NaowhForeverDB
    if type(sv) == "table" then
        sv.journalProbe = { build = tonumber(build) or 0, loads = Sorted(loads), refused = Sorted(refused) }
    end
    ns.Print(TEXT_DONE:format(Count(loads), Count(refused)))
end

local function Answer(id, sent)
    if not pending[id] then return end
    pending[id] = nil
    waiting = waiting - 1
    if sent then loads[id] = true else refused[id] = true end
end

local function TimeUp(asked)
    if asked ~= generation or not running then return end
    for id in pairs(pending) do Answer(id, GetItemNameByID(id) ~= nil) end
    Next()
end

local function Ask(id)
    if GetItemNameByID(id) then
        loads[id] = true
        return
    end
    pending[id] = true
    waiting = waiting + 1
    RequestLoadItemDataByID(id)
end

Next = function()
    if waiting > 0 then return end
    if at > #queue then return Finish() end
    generation = generation + 1
    for i = at, math.min(at + BATCH - 1, #queue) do Ask(queue[i]) end
    at = at + BATCH
    if waiting == 0 then return Next() end
    local asked = generation
    C_Timer.After(WAIT, function() TimeUp(asked) end)
end

local function OnEvent(_, _, id, success)
    Answer(id, success == true)
    if waiting == 0 then Next() end
end

function ns.JournalItemProbe()
    if running then return ns.Print(TEXT_RUNNING) end
    local seen = {}
    for id in pairs(J.Items) do seen[id] = true end
    for id in pairs(J.NotYet) do seen[id] = true end
    queue, pending, loads, refused = Sorted(seen), {}, {}, {}
    at, waiting, generation, running = 1, 0, 0, true
    frame = frame or CreateFrame("Frame")
    frame:SetScript("OnEvent", OnEvent)
    frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    ns.Print(TEXT_ASKING:format(#queue))
    Next()
end

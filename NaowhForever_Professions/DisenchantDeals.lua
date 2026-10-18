-- DisenchantDeals.lua: resumable expected-value searches over the last auction scan.
local ns = _G.NaowhForever

local GetItemInfo = C_Item.GetItemInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local IsItemDataCached = C_Item.IsItemDataCachedByID
local RequestItemData = C_Item.RequestLoadItemDataByID

local P = ns.Professions
local S = P.Settings
local Values = P.DisenchantValues

local MODE_LEVEL, MODE_PROFIT = "level", "profit"
local BUILD_CHUNK = 75
local LOAD_BATCH = 5
local LOAD_DELAY = 0.05
local MAX_LEVEL_RESULTS = 10
local PERCENT = 100
local PROFESSION_SLOTS = 5

local jobs = {}
local tooltipCache = {}
local loadQueue, queued, requested = {}, {}, {}
local loadHead = 1
local generation = 0
local mode = MODE_PROFIT
local guaranteedOnly = false
local currentSkillOnly = false
local active, listener
local pumpGeneration, sortGeneration
local tooltipPrices, tooltipScan

local Deals = { MODE_LEVEL = MODE_LEVEL, MODE_PROFIT = MODE_PROFIT }
P.DisenchantDeals = Deals

local function Changed()
    if listener then listener() end
end

local function EnchantingSkill()
    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(P.Disenchant.ENCHANTING)
    local skill = info and tonumber(info.skillLevel)
    if skill and skill > 0 then return skill end
    local professions = { GetProfessions() }
    for slot = 1, PROFESSION_SLOTS do
        local index = professions[slot]
        if index then
            local _, _, rank, _, _, _, line, modifier = GetProfessionInfo(index)
            if line == P.Disenchant.ENCHANTING then return (rank or 0) + (modifier or 0) end
        end
    end
end

local function Scan()
    if ns.AuctionPriceList then return ns.AuctionPriceList() end
end

local function Fresh(job, prices, scanned, skill)
    return job and job.prices == prices and job.scan == scanned
        and (job.mode ~= MODE_LEVEL or job.bracket == Values.LevelBracket(skill))
end

local function ProfitBetter(a, b)
    if a.profit ~= b.profit then return a.profit > b.profit end
    if a.roi ~= b.roi then return a.roi > b.roi end
    return a.item < b.item
end

local function Better(job, a, b)
    if job.mode == MODE_LEVEL then return Values.LevelBetter(a, b) end
    return ProfitBetter(a, b)
end

local function RefreshVisible(job)
    wipe(job.visible)
    for _, entry in ipairs(job.candidates) do
        local skillReady = not currentSkillOnly
            or job.skill and entry.required and entry.required <= job.skill
        if job.mode ~= MODE_PROFIT or (not guaranteedOnly or entry.guaranteed) and skillReady then
            job.visible[#job.visible + 1] = entry
            if job.mode == MODE_LEVEL and #job.visible == MAX_LEVEL_RESULTS then return end
        end
    end
end

local function Sort(job)
    if not job.dirty then return end
    table.sort(job.candidates, job.mode == MODE_LEVEL and Values.LevelBetter or ProfitBetter)
    job.dirty = false
    RefreshVisible(job)
end

local function Add(job, entry)
    if not entry or job.byItem[entry.item] then return end
    job.byItem[entry.item] = entry
    job.candidates[#job.candidates + 1] = entry
    job.dirty = true
end

local function Entry(itemID, price, prices, whichMode, itemLink)
    local name, link, quality, baseLevel, _, _, _, _, equip, icon, _, classID = GetItemInfo(itemLink or itemID)
    if not name or not Values.Takes(classID, quality, equip) then return end
    local level = C_Item.GetDetailedItemLevelInfo(link) or baseLevel
    local required = Values.RequiredSkill(level, quality)
    local gross, outcomes = Values.Expected(classID, quality, level, prices)
    outcomes = outcomes or Values.Outcomes(classID, quality, level)
    if not outcomes then return end
    local value = gross and Values.AfterCut(gross)
    local profit = value and price and value - price
    local entry = {
        item = itemID, name = name, link = link, icon = icon, quality = quality, price = price, scanPrice = price,
        gross = gross, value = value, profit = profit, roi = profit and profit / price * PERCENT,
        outcomes = outcomes, required = required, mode = whichMode, prices = prices,
    }
    entry.guaranteed = price and Values.Guaranteed(outcomes, prices, price) or false
    return entry
end

local function Evaluate(job, itemID, price)
    local entry = Entry(itemID, price, job.prices, job.mode)
    if not (entry and entry.gross) then return end
    local profit = entry.profit
    if job.mode == MODE_LEVEL and not Values.LevelEligible(entry.required, job.skill) then return end
    if not job.best or profit > job.best.profit then job.best = entry end
    if job.mode == MODE_PROFIT and profit <= 0 then return end
    Add(job, entry)
end

local function Needed(itemID)
    return active and active.pending[itemID] ~= nil
end

local PumpLoads

local function QueueLoad(itemID)
    if queued[itemID] or requested[itemID] then return end
    queued[itemID] = true
    loadQueue[#loadQueue + 1] = itemID
end

PumpLoads = function(gen)
    if gen ~= generation or not active or pumpGeneration ~= gen then return end
    local sent = 0
    while sent < LOAD_BATCH and loadHead <= #loadQueue do
        local itemID = loadQueue[loadHead]
        loadHead = loadHead + 1
        queued[itemID] = nil
        if Needed(itemID) and not requested[itemID] then
            requested[itemID] = true
            RequestItemData(itemID)
            sent = sent + 1
        end
    end
    if loadHead <= #loadQueue then
        C_Timer.After(LOAD_DELAY, function() PumpLoads(gen) end)
    else
        wipe(loadQueue)
        loadHead, pumpGeneration = 1, nil
    end
end

local function StartPump()
    if not active or pumpGeneration == generation then return end
    local gen = generation
    pumpGeneration = gen
    C_Timer.After(0, function() PumpLoads(gen) end)
end

local function Request(job, itemID, price)
    if job.pending[itemID] then return end
    job.pending[itemID] = price
    job.pendingCount = job.pendingCount + 1
    QueueLoad(itemID)
end

local function Candidate(job, itemID, price)
    local _, _, _, equip, _, classID = GetItemInfoInstant(itemID)
    if not Values.Equipment(classID, equip) then return end
    if not IsItemDataCached(itemID) then return Request(job, itemID, price) end
    Evaluate(job, itemID, price)
end

local function Finish(job)
    if not (job.iterated and job.pendingCount == 0) then return end
    Sort(job)
    job.done = true
    if active == job then Changed() end
end

local BuildStep

BuildStep = function(job, gen)
    if gen ~= generation or active ~= job then return end
    local itemID = job.cursor
    local price
    for _ = 1, BUILD_CHUNK do
        itemID, price = next(job.prices, itemID)
        if itemID == nil then break end
        if price and price > 0 then Candidate(job, itemID, price) end
    end
    job.cursor = itemID
    if itemID == nil then
        job.iterated = true
        Finish(job)
    else
        Changed()
        C_Timer.After(0, function() BuildStep(job, gen) end)
    end
    StartPump()
end

local function ResumePending(job)
    for itemID, price in pairs(job.pending) do
        if IsItemDataCached(itemID) then
            job.pending[itemID] = nil
            job.pendingCount = job.pendingCount - 1
            Evaluate(job, itemID, price)
        else
            requested[itemID] = nil
            QueueLoad(itemID)
        end
    end
end

local function NewJob(prices, scanned, skill)
    return {
        mode = mode, prices = prices, scan = scanned, skill = skill,
        bracket = Values.LevelBracket(skill), candidates = {}, visible = {}, byItem = {},
        pending = {}, pendingCount = 0,
    }
end

local function Begin(job)
    generation = generation + 1
    active = job
    ResumePending(job)
    if job.mode == MODE_LEVEL and not Values.SkillupBand(job.skill) then
        job.iterated, job.done = true, true
        RefreshVisible(job)
        return Changed()
    end
    if not job.iterated then
        local gen = generation
        C_Timer.After(0, function() BuildStep(job, gen) end)
    else
        Finish(job)
    end
    StartPump()
    Changed()
end

function Deals.On()
    return P.On() and S.Get("disenchantDeals") and P.Disenchant.Known()
end

function Deals.SetListener(fn)
    listener = fn
end

function Deals.Mode()
    return mode
end

function Deals.SetMode(nextMode)
    if nextMode ~= MODE_LEVEL and nextMode ~= MODE_PROFIT or nextMode == mode then return end
    generation = generation + 1
    active, mode = nil, nextMode
    wipe(tooltipCache)
    Changed()
end

function Deals.GuaranteedOnly()
    return guaranteedOnly
end

function Deals.SetGuaranteedOnly(value)
    guaranteedOnly = value == true
    local job = Deals.Job()
    if job then RefreshVisible(job) end
    Changed()
end

function Deals.CurrentSkillOnly()
    return currentSkillOnly
end

function Deals.SetCurrentSkillOnly(value)
    currentSkillOnly = value == true
    local job = Deals.Job()
    if job then
        job.skill = EnchantingSkill()
        RefreshVisible(job)
    end
    Changed()
end

function Deals.Job()
    local prices, scanned = Scan()
    local skill = EnchantingSkill()
    local job = jobs[mode]
    if Fresh(job, prices, scanned, skill) then return job end
end

function Deals.Active()
    return active == Deals.Job()
end

function Deals.Start()
    local prices, scanned = Scan()
    if not (prices and scanned) then return Changed() end
    local skill = EnchantingSkill()
    local job = jobs[mode]
    if not Fresh(job, prices, scanned, skill) then
        job = NewJob(prices, scanned, skill)
        jobs[mode] = job
    end
    if job.done then
        active = job
        return Changed()
    end
    Begin(job)
end

function Deals.Pause()
    generation = generation + 1
    active, pumpGeneration, sortGeneration = nil, nil, nil
end

function Deals.ScanChanged()
    local _, scanned = Scan()
    local changed = false
    for which, job in pairs(jobs) do
        if job.scan ~= scanned then jobs[which], changed = nil, true end
    end
    if changed then
        Deals.Pause()
        wipe(loadQueue)
        wipe(queued)
        wipe(requested)
        loadHead = 1
        Changed()
    end
end

function Deals.SkillChanged()
    if mode == MODE_PROFIT then
        local job = Deals.Job()
        if not (currentSkillOnly and job) then return end
        job.skill = EnchantingSkill()
        RefreshVisible(job)
        return Changed()
    end
    local job = Deals.Job()
    if not job then Deals.Start() end
end

function Deals.ItemLoaded(itemID, loaded)
    requested[itemID], queued[itemID] = nil, nil
    local touched = false
    for _, job in pairs(jobs) do
        local price = job.pending[itemID]
        if price then
            job.pending[itemID] = nil
            job.pendingCount = job.pendingCount - 1
            if loaded then Evaluate(job, itemID, price) end
            Finish(job)
            touched = touched or active == job
        end
    end
    if not touched then return end
    if sortGeneration ~= generation then
        local gen = generation
        sortGeneration = gen
        C_Timer.After(0, function()
            if sortGeneration ~= gen then return end
            sortGeneration = nil
            if gen ~= generation or not active then return end
            Sort(active)
            Changed()
        end)
    end
    StartPump()
end

local function Remove(job, entry)
    for i, candidate in ipairs(job.candidates) do
        if candidate == entry then table.remove(job.candidates, i) break end
    end
    job.byItem[entry.item] = nil
end

local function Insert(job, entry)
    local low, high = 1, #job.candidates + 1
    while low < high do
        local middle = math.floor((low + high) / 2)
        if job.candidates[middle] and Better(job, job.candidates[middle], entry) then
            low = middle + 1
        else
            high = middle
        end
    end
    table.insert(job.candidates, low, entry)
    job.byItem[entry.item] = entry
end

function Deals.UpdateLive(entry, price)
    local job = jobs[entry.mode]
    if not job or job.byItem[entry.item] ~= entry then return end
    Remove(job, entry)
    if price then
        entry.price = price
        entry.profit = entry.value - price
        entry.roi = entry.profit / price * PERCENT
        entry.guaranteed = Values.Guaranteed(entry.outcomes, job.prices, price)
        if job.mode ~= MODE_PROFIT or entry.profit > 0 then Insert(job, entry) end
    end
    RefreshVisible(job)
    Changed()
end

function Deals.Prices()
    local job = Deals.Job()
    return job and job.prices
end

function Deals.TooltipEntry(itemID, itemLink)
    local prices, scanned = Scan()
    if not (prices and scanned and itemID) then return end
    if prices ~= tooltipPrices or scanned ~= tooltipScan then
        wipe(tooltipCache)
        tooltipPrices, tooltipScan = prices, scanned
    end
    local key = itemLink or itemID
    local entry = tooltipCache[key]
    if entry then return entry end
    entry = Entry(itemID, prices[itemID], prices, mode, itemLink)
    if entry then tooltipCache[key] = entry end
    return entry
end

function Deals.Skill()
    return EnchantingSkill()
end

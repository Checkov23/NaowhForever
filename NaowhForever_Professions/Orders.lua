-- Orders.lua: craft orders to another player: what each craft takes, the suggested tip, and the messages sent.
local ns = _G.NaowhForever

local T = ns.THEME

local P = ns.Professions
local S = P.Settings
local C = P.C
local W = P.State
local R = P.Recipes
local Prices = P.Prices
local Links = P.Links
local Text = P.Text

local MAX = 9
local MIN_TIP = 100
local DEFAULT_TIP = 10
local PERCENT = C.PERCENT
local MESSAGE_GAP = 0.4
local MAX_MESSAGE = 255
local ROUND_SILVER_UNDER, ROUND_TEN_SILVER_UNDER = 10000, 100000
local ROUND_TEN_SILVER = 1000
local ROUND = C.ROUND
local INVITE_LINES = {
    "Hi! Inviting you to my group for some crafts from your profession.",
    "Hey, sending you an invite. I'd like to order a few crafts from you.",
    "Hi there! Invite incoming, got some crafting work for you if you're up for it.",
    "Hey! Saw your profession, inviting you so I can ask for a few crafts.",
    "Hello! Mind joining my group? I'd like a few things crafted, with a tip of course.",
    "Hi! Sent you an invite for some crafts, easier to sort out in party chat.",
}
local ASK_LINES = {
    "Could you craft %dx %s for me?",
    "Would you make %dx %s for me?",
    "Could I get %dx %s from you?",
    "Any chance you could craft %dx %s?",
    "Would you mind making %dx %s for me?",
    "Can you make %dx %s for me?",
}
local TEXT_NO_MATERIALS = "No materials from me."
local TEXT_I_BRING = "I bring"
local TEXT_MATERIAL = "%dx %s"
local TEXT_OF = " (of %d)"
local TEXT_TIP = "Tip: %s."
local TEXT_UNKNOWN = "?"
local TEXT_SENT = ns.L("Asked %s %sfor %s.")
local TEXT_IN_INSTANCE, TEXT_IN_PARTY = ns.L("in instance chat "), ns.L("in party chat ")
local TEXT_ONE_CRAFT, TEXT_CRAFTS = ns.L("1 craft"), ns.L(" crafts")

local byCrafter = {}
local lastPick = {}

local function Pick(lines)
    local last = lastPick[lines]
    local pick = math.random(#lines - (last and 1 or 0))
    if last and pick >= last then pick = pick + 1 end
    lastPick[lines] = pick
    return lines[pick]
end

local function Send(message, channel, who)
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    send(message, channel, nil, who)
end

local function Crafter()
    local _, name = C_TradeSkillUI.IsTradeSkillLinked()
    if type(name) == "string" and name ~= "" then return name end
    local guid = Links.GUID()
    if not guid then return end
    local _, _, _, _, _, n, realm = GetPlayerInfoByGUID(guid)
    if n and n ~= "" then return (realm and realm ~= "") and (n .. "-" .. realm) or n end
end

local function Get()
    local who = Crafter()
    if not who then return end
    local o = byCrafter[who]
    if not o then
        o = { who = who, list = {}, drafts = {} }
        byCrafter[who] = o
    end
    if W.linked and Links.GUID() then o.guid = Links.GUID() end
    return o
end

local function Draft(info)
    local o = info and Get()
    if not o then return end
    local d = o.drafts[info.recipeID]
    if not d then
        local output, made = R.OutputItem(info.recipeID)
        d = { recipeID = info.recipeID, name = info.name, icon = info.icon, output = output,
            made = made or 1, reagents = R.Reagents(info.recipeID), crafts = 1, bring = {} }
        o.drafts[info.recipeID] = d
    end
    if #d.reagents == 0 then d.reagents = R.Reagents(info.recipeID) end
    return d
end

local function Index(o, d)
    for i, e in ipairs(o.list) do
        if e == d then return i end
    end
end

local function Bringing(d, r)
    local total = r.need * d.crafts
    local b = d.bring[r.itemID]
    if b == true then return total end
    return math.min(b or 0, total)
end

local function Round(copper)
    local step = copper < ROUND_SILVER_UNDER and C.COPPER_PER_SILVER
        or copper < ROUND_TEN_SILVER_UNDER and ROUND_TEN_SILVER or C.COPPER_PER_GOLD
    return math.floor(copper / step + ROUND) * step
end

local function Value(d)
    local v = { theirs = 0, all = 0, missing = 0, theirsCount = 0, bringCount = 0, parts = {} }
    for _, r in ipairs(d.reagents) do
        local total = r.need * d.crafts
        local mine = Bringing(d, r)
        local each, from = Prices.BuyPrice(r.itemID)
        v.parts[#v.parts + 1] = { itemID = r.itemID, total = total, mine = mine, each = each, from = from }
        if mine > 0 then v.bringCount = v.bringCount + 1 end
        if total > mine then v.theirsCount = v.theirsCount + 1 end
        if each then
            v.theirs = v.theirs + each * (total - mine)
            v.all = v.all + each * total
        else
            v.missing = v.missing + 1
        end
    end
    local each = d.output and ns.AuctionPrice and ns.AuctionPrice(d.output)
    v.value = each and each * d.made * d.crafts
    v.pct = S.Get("orderTip") or DEFAULT_TIP
    local base = v.value or (v.missing == 0 and v.all > 0 and v.all) or nil
    if base then
        local share = v.pct > 0 and math.max(MIN_TIP, base * v.pct / PERCENT) or 0
        v.pay = Round(v.theirs + share)
    end
    return v
end

local function Pay(d, v)
    return d.tip or v.pay
end

local function CoinValue(coin)
    if coin == "g" then return C.COPPER_PER_GOLD end
    if coin == "s" then return C.COPPER_PER_SILVER end
    return 1
end

local function Parse(text)
    text = (text or ""):lower():gsub("%s", "")
    if text == "" then return end
    local gold = tonumber(text)
    if gold then return math.max(0, math.floor(gold * C.COPPER_PER_GOLD + ROUND)) end
    local total, bad = 0, false
    local rest = text:gsub("([%d%.]+)([gsc])", function(n, coin)
        n = tonumber(n)
        if not n then bad = true return "" end
        total = total + n * CoinValue(coin)
        return ""
    end)
    if bad or rest ~= "" then return end
    return math.floor(total + ROUND)
end

local function Materials(v, pieces)
    local mats = {}
    for _, p in ipairs(v.parts) do
        if p.mine > 0 then
            mats[#mats + 1] = TEXT_MATERIAL:format(p.mine, R.Link(p.itemID))
                .. (p.mine < p.total and TEXT_OF:format(p.total) or "")
        end
    end
    if #mats == 0 then
        pieces[#pieces + 1] = TEXT_NO_MATERIALS
        return
    end
    pieces[#pieces + 1] = TEXT_I_BRING
    for i, m in ipairs(mats) do pieces[#pieces + 1] = m .. (i < #mats and "," or ".") end
end

local function Split(pieces)
    local out, line = {}, ""
    for _, piece in ipairs(pieces) do
        local joined = line == "" and piece or (line .. " " .. piece)
        if #joined > MAX_MESSAGE and line ~= "" then
            out[#out + 1] = line
            line = piece
        else
            line = joined
        end
    end
    if line ~= "" then out[#out + 1] = line end
    return out
end

local function Messages(d, name)
    local v = Value(d)
    local what = d.output and R.Link(d.output, d.name)
        or C_TradeSkillUI.GetRecipeLink(d.recipeID) or ("[" .. (d.name or TEXT_UNKNOWN) .. "]")
    local ask = Pick(ASK_LINES):format(d.crafts, what)
    if name then ask = name .. ", " .. ask:sub(1, 1):lower() .. ask:sub(2) end
    local pieces = { ask }
    Materials(v, pieces)
    local pay = Pay(d, v)
    if pay and pay > 0 then pieces[#pieces + 1] = TEXT_TIP:format(Text.Short(pay)) end
    return Split(pieces)
end

local function Grouped(o)
    if not (o and IsInGroup()) then return end
    local raid = IsInRaid()
    local want = Ambiguate(o.who, "none")
    for i = 1, raid and GetNumGroupMembers() or GetNumSubgroupMembers() do
        local unit = (raid and "raid" or "party") .. i
        local guid = UnitGUID(unit)
        local name = GetUnitName(unit, true)
        if (o.guid and guid == o.guid) or (name and Ambiguate(name, "none") == want) then
            return raid and "raid" or "party"
        end
    end
end

local function Channel(o)
    if Grouped(o) ~= "party" then return "WHISPER" end
    return IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY"
end

local function SendOrder()
    local o = Get()
    if not (o and #o.list > 0) then return end
    local who = o.who
    local channel = Channel(o)
    local short = Ambiguate(who, "short")
    local messages = {}
    for _, d in ipairs(o.list) do
        for _, m in ipairs(Messages(d, channel ~= "WHISPER" and short or nil)) do
            messages[#messages + 1] = m
        end
    end
    for i, m in ipairs(messages) do
        C_Timer.After((i - 1) * MESSAGE_GAP, function()
            Send(m, channel, channel == "WHISPER" and who or nil)
        end)
    end
    o.sent = TEXT_SENT:format(short, channel == "WHISPER" and ""
        or channel == "INSTANCE_CHAT" and TEXT_IN_INSTANCE or TEXT_IN_PARTY,
        #o.list == 1 and TEXT_ONE_CRAFT or (#o.list .. TEXT_CRAFTS))
    wipe(o.list)
    wipe(o.drafts)
end

local function Invite()
    local who = Crafter()
    if not who then return end
    Send(Pick(INVITE_LINES), "WHISPER", who)
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(who)
    else
        InviteUnit(who)
    end
end

local function Count(recipeID)
    local o = Get()
    local d = o and o.drafts[recipeID]
    if d and Index(o, d) then return Text.Hex(T.accent) .. "x" .. d.crafts .. "|r" end
    return ""
end

local function Current()
    return W.linked and Draft(R.SelectedInfo()) or nil
end

P.Orders = {
    MAX = MAX,
    Crafter = Crafter,
    Get = Get,
    Draft = Draft,
    Index = Index,
    Bringing = Bringing,
    Value = Value,
    Pay = Pay,
    Parse = Parse,
    Grouped = Grouped,
    Channel = Channel,
    Send = SendOrder,
    Invite = Invite,
    Count = Count,
    Current = Current,
}

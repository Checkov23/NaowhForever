-- Gamble.lua: group gambling sessions with Classic rolls and Deathroll.
local ns = _G.NaowhForever

local Ambiguate, IsInGroup, IsInRaid = Ambiguate, IsInGroup, IsInRaid
local UnitGUID, UnitName = UnitGUID, UnitName
local UnitIsConnected, GetNumGroupMembers = UnitIsConnected, GetNumGroupMembers
local floor, random = math.floor, math.random
local concat, remove = table.concat, table.remove
local lower, trim = strlower, strtrim
local RegisterAddonMessagePrefix = C_ChatInfo.RegisterAddonMessagePrefix
local SendAddonMessage, SendChatMessage = C_ChatInfo.SendAddonMessage, C_ChatInfo.SendChatMessage

local S = ns.QoLSettings
local T = ns.THEME
local Parts, St = ns.Shared.Parts, ns.Shared.Style

local PREFIX = "NaowhGamble"
local PAGE = "QoL/Questing & Group"

local WINDOW_W, WINDOW_H = 520, 470
local PAD, HEADER, FOOTER = St.WINDOW_PAD, St.WINDOW_HEADER, St.WINDOW_FOOTER
local INSET, ROW_GAP = St.CONTENT_INSET, 10
local CONTROLS_H, CONFIG_FIELD_W, MODE_BUTTON_W = 84, 130, 160
local POOL_W, POOL_H = 100, 28
local CHANNEL_W, CHANNEL_H = 118, 28
local ANNOUNCE_W = 120
local BUTTON_W, BUTTON_H, BUTTON_GAP, BUTTON_LIFT = 112, 28, 8, 6
local HELP_BUTTON_W = 104
local FIELD_INSET = 8
local WORD_FIELD_H, WORD_LABEL_H, WORD_GAP = 26, 16, 22
local LABEL_FONT, TEXT_FONT = 12, 13
local STATUS_H, ROSTER_H = 28, 140
local HELP_GUTTER, HELP_SCROLL_GAP = 32, 8
local HELP_TEXT_HEIGHT = 1000
local SILVER_PER_GOLD = 100
local MS_PER_SECOND = 1000
local ROLL_CAPTURES, SELF_ROLL_CAPTURES = 4, 3

local MAX_POOL, MAX_WORD = 1000000, 24
local MAX_PARTICIPANTS, MAX_PLAYER_NAME, MAX_ROSTER_CHUNK = 40, 48, 150
local MAX_ID, MAX_GUID = 64, 32

local function FormatPool(amount)
    local gold = floor(amount / SILVER_PER_GOLD)
    local silver = amount % SILVER_PER_GOLD
    return ("%dg%02ds"):format(gold, silver)
end

local function ParsePool(text)
    if type(text) ~= "string" then return nil end
    local goldText, silverText = lower(trim(text)):match("^(%d+)g(%d+)s$")
    if not goldText then return nil end
    local gold, silver = tonumber(goldText), tonumber(silverText)
    if not (gold and silver and gold <= floor(MAX_POOL / SILVER_PER_GOLD)
        and silver <= MAX_POOL) then return nil end
    local amount = gold * SILVER_PER_GOLD + silver
    if amount < 1 or amount > MAX_POOL then return nil end
    return amount
end

local CHAT_EVENTS = {
    CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID",
}

local CHANNELS = { "PARTY", "RAID" }

local CHANNEL_LABEL = { PARTY = ns.L("Party"), RAID = ns.L("Raid") }
local CHANNEL_CHAT = { PARTY = "Party", RAID = "Raid" }
local MODE_LABEL = { classic = ns.L("Classic"), deathroll = ns.L("Deathroll") }

local PATTERN_ESCAPE = {
    ["%"] = "%%", ["^"] = "%^", ["$"] = "%$", ["("] = "%(", [")"] = "%)",
    ["."] = "%.", ["["] = "%[", ["]"] = "%]", ["*"] = "%*", ["+"] = "%+",
    ["-"] = "%-", ["?"] = "%?",
}
local TITLE, SUBTITLE = ns.L("Gamble"), ns.L("Classic and Deathroll")
local TEXT_POOL = ns.L("Pool (g/s)")
local TEXT_CHANNEL = ns.L("%s Chat")
local TEXT_NEW, TEXT_LAST_CALL = ns.L("New Game"), ns.L("Last Call")
local TEXT_START = ns.L("Start Rolling")
local TEXT_CANCEL = ns.L("Cancel Session")
local TEXT_NO_GAME = ns.L("Start a new session before rolling.")
local TEXT_NOT_LOBBY = ns.L("This session is already rolling.")
local TEXT_NOT_HOST = ns.L("Only the session host can start a new session.")
local TEXT_NEED_PLAYERS = ns.L("At least two players must join first.")
local TEXT_BAD_POOL = ns.L("Enter a pool as gold and silver (for example 10g50s), between 0g01s and %s.")
local TEXT_BAD_WORD = ns.L("Join and leave words must be different single words without |.")
local TEXT_NEED_GROUP = ns.L("Join a party or raid before using that chat channel.")
local TEXT_STARTED = ns.L("Gamble session started: %s, pool %s. Say \"%s\" to join or \"%s\" to leave; use /roll when it's your turn.")
local TEXT_CANCELLED = ns.L("Gamble session cancelled by %s.")
local TEXT_HOST_LEFT = ns.L("Host left; session ended.")
local TEXT_LAST = ns.L("Last call: say \"%s\" in %s chat to join.")
local TEXT_LEFT = ns.L("%s left the Gamble session.")
local TEXT_DUEL = ns.L("Deathroll: %s and %s are playing for %s.")
local TEXT_DUEL_START = ns.L("%s was randomly selected to roll first. Roll from 1 to %d.")
local TEXT_CLASSIC_START = ns.L("Everyone can start rolling from 1 to %d.")
local TEXT_ANNOUNCE, TEXT_STILL_NEED = ns.L("Announce Rolls"), ns.L("Still need to roll: %s. Roll from 1 to %d.")
local TEXT_NEXT_ROLL = ns.L("%s, roll from 1 to %d.")
local TEXT_NO_ROLLS = ns.L("Everyone has rolled.")
local TEXT_FULL_TIE = ns.L("Everyone rolled %d: roll again from 1 to %d.")
local TEXT_SETTLEMENT = ns.L("%s pays %s %s.")
local TEXT_ROSTER = ns.L("No players have joined yet.")
local TEXT_ROSTER_ROW = "%s  %s"
local TEXT_MODE = ns.L("Game mode: %s")
local TEXT_JOIN_WORD = ns.L("Join word")
local TEXT_LEAVE_WORD = ns.L("Leave word")
local TEXT_NO_SESSION, TEXT_LOBBY = ns.L("No session"), ns.L("Waiting for players to join")
local TEXT_ROLLING, TEXT_DEATHROLLING = ns.L("Waiting for rolls"), ns.L("Deathroll in progress")
local TEXT_SESSION_CANCELLED, TEXT_COMPLETE = ns.L("Session cancelled"), ns.L("Session complete")
local TEXT_HELP, TEXT_BACK = ns.L("How to play"), ns.L("Back to game")
local TEXT_COMM_FAILED = ns.L("Gamble could not register its group message prefix.")
local TEXT_NOT_ACTIVE = ns.L("Turn on Gamble under QoL > Questing & Group first.")

local window, controls, poolBox, channelButton, announceButton, status, roster, helpView
local joinBox, leaveBox, modeButton
local newButton, lastCallButton, startButton, cancelButton, helpButton

local events, prefixRegistered
local OnEvent

local game

local function Secret(value)
    return issecretvalue and issecretvalue(value)
end

local function IsPlayerGUID(guid)
    return type(guid) == "string" and #guid <= MAX_GUID and guid:find("^Player%-") ~= nil
end

local function Names(players)
    local names = {}
    for i, player in ipairs(players) do
        names[i] = type(player) == "table" and player.name or player
    end
    if #names < 3 then return concat(names, " and ") end
    return concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end

local function HostIsConnected()
    if not (game and game.hostGUID and IsInGroup()) then return false end
    local raid = IsInRaid()
    local count = GetNumGroupMembers() - (raid and 0 or 1)
    local prefix = raid and "raid" or "party"
    for index = 1, count do
        local unit = prefix .. index
        local guid = UnitGUID(unit)
        if not Secret(guid) and guid == game.hostGUID then return UnitIsConnected(unit) end
    end
    return false
end

local function IsOn()
    return S.Get("enabled") and S.Get("gamble")
end

local function ValidWords(joinWord, leaveWord)
    return type(joinWord) == "string" and type(leaveWord) == "string"
        and joinWord:match("^%S+$") and leaveWord:match("^%S+$")
        and not joinWord:find("|", 1, true) and not leaveWord:find("|", 1, true)
        and #joinWord <= MAX_WORD and #leaveWord <= MAX_WORD
        and lower(joinWord) ~= lower(leaveWord)
end

local function ChannelAvailable(channel)
    if channel == "RAID" then return IsInRaid() end
    return channel == "PARTY" and IsInGroup() and not IsInRaid()
end

local function SendChat(text, channel)
    if not ChannelAvailable(channel) then
        ns.Print(TEXT_NEED_GROUP)
        return false
    end
    SendChatMessage(text, channel)
    return true
end

local function SendAddon(text, channel)
    if not ChannelAvailable(channel) then return false end
    SendAddonMessage(PREFIX, text, channel)
    return true
end

local function NeedEvents()
    return IsOn() and ((window and window:IsShown()) or (game and game.phase ~= "complete"))
end

local function UpdateListening()
    local listen = NeedEvents()
    if not listen then
        if events then events:UnregisterAllEvents() end
        return
    end
    if not prefixRegistered then
        local registered = RegisterAddonMessagePrefix(PREFIX)
        if registered == false then
            ns.Print(TEXT_COMM_FAILED)
            return
        end
        prefixRegistered = true
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", OnEvent)
    end
    events:UnregisterAllEvents()
    events:RegisterEvent("CHAT_MSG_SYSTEM")
    events:RegisterEvent("CHAT_MSG_ADDON")
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:RegisterEvent("UNIT_CONNECTION")
    for event in pairs(CHAT_EVENTS) do events:RegisterEvent(event) end
end

local function SendAddonToAvailable(text)
    for _, channel in ipairs(CHANNELS) do
        if ChannelAvailable(channel) then SendAddon(text, channel) end
    end
end

local function RequestOpenSessions()
    SendAddonToAvailable("Q")
end

local function AddPlayer(guid, name)
    if game.players[guid] or #game.participants >= MAX_PARTICIPANTS then return nil end
    local player = { key = guid, name = name }
    game.players[guid] = player
    game.participants[#game.participants + 1] = player
    return player
end

local function RemovePlayer(guid)
    local player = game.players[guid]
    if not player then return false end
    game.players[player.key] = nil
    for i, entry in ipairs(game.participants) do
        if entry == player then
            remove(game.participants, i)
            break
        end
    end
    return true
end

local function DecodePlayers(encoded)
    local players = {}
    if #encoded > MAX_PARTICIPANTS * (MAX_GUID + MAX_PLAYER_NAME + 2) then return nil end
    local seen = {}
    for entry in encoded:gmatch("[^,]+") do
        local guid, name = entry:match("^([^:]+):(.+)$")
        if not (IsPlayerGUID(guid) and #name <= MAX_PLAYER_NAME) or seen[guid]
            or #players >= MAX_PARTICIPANTS then return nil end
        seen[guid] = true
        players[#players + 1] = { key = guid, name = name }
    end
    return players
end

local function RosterMap(players)
    local out = {}
    for _, player in ipairs(players) do out[player.key] = player end
    return out
end

local function UpdateDisplay()
    if not (window and window:IsShown()) then return end
    local phaseText = TEXT_NO_SESSION
    if game and game.phase == "lobby" then phaseText = TEXT_LOBBY end
    if game and game.phase == "rolling" then phaseText = TEXT_ROLLING end
    if game and game.phase == "deathroll" then phaseText = TEXT_DEATHROLLING end
    if game and game.phase == "complete" then
        phaseText = game.hostLeft and TEXT_HOST_LEFT
            or (game.cancelled and TEXT_SESSION_CANCELLED or TEXT_COMPLETE)
    end
    status:SetText(phaseText)

    local rows = {}
    for _, player in ipairs(game and game.participants or {}) do
        local value = game.round and game.round.rolls[player.key]
        if value then
            rows[#rows + 1] = TEXT_ROSTER_ROW:format(player.name, tostring(value))
        else
            rows[#rows + 1] = player.name
        end
    end
    roster:SetText(#rows > 0 and concat(rows, "\n") or TEXT_ROSTER)

    local channel = game and game.phase ~= "complete" and game.channel or S.Get("gambleChannel")
    channel = CHANNEL_LABEL[channel] and channel or "PARTY"
    ns.SetButtonText(channelButton, TEXT_CHANNEL:format(CHANNEL_LABEL[channel]))
    if game and game.phase ~= "complete" then poolBox:SetText(FormatPool(game.pool)) end
    lastCallButton:SetEnabled(game ~= nil and game.phase == "lobby" and game.isHost)
    startButton:SetEnabled(game ~= nil and game.phase == "lobby" and game.isHost)
    cancelButton:SetEnabled(game ~= nil and game.phase ~= "complete" and game.isHost)
    announceButton:SetEnabled(game ~= nil and game.isHost and game.round ~= nil
        and (game.phase == "rolling" or game.phase == "deathroll"))
    channelButton:SetEnabled(not (game and game.phase ~= "complete"))
    poolBox:SetEnabled(not (game and game.phase ~= "complete"))
end

local function AddonPayload(kind, ...)
    if not game then return kind end
    return kind .. "|" .. game.id .. "|" .. concat({ ... }, "|")
end

local function ChunkPlayers(players)
    local chunks, current, size = {}, {}, 0
    for _, player in ipairs(players) do
        local entry = player.key .. ":" .. player.name
        local added = #entry + (#current > 0 and 1 or 0)
        if size + added > MAX_ROSTER_CHUNK then
            chunks[#chunks + 1] = concat(current, ",")
            current, size = {}, 0
            added = #entry
        end
        current[#current + 1], size = entry, size + added
    end
    if #current > 0 then chunks[#chunks + 1] = concat(current, ",") end
    return chunks
end

local function BroadcastRoster()
    if not (game and game.isHost) then return end
    if #game.participants == 0 then return end
    game.rosterVersion = (game.rosterVersion or 0) + 1
    local chunks = ChunkPlayers(game.participants)
    for index, chunk in ipairs(chunks) do
        SendAddon(AddonPayload("R", game.rosterVersion, index, #chunks, chunk), game.channel)
    end
end

local function BroadcastRound()
    if not (game and game.isHost and game.round) then return end
    game.roundVersion = (game.roundVersion or 0) + 1
    local chunks = ChunkPlayers(game.round.players)
    for index, chunk in ipairs(chunks) do
        SendAddon(AddonPayload("C", game.roundVersion, game.round.max, index, #chunks, chunk), game.channel)
    end
end

local function AssemblePlayers(kind, version, index, count, encoded)
    version, index, count = tonumber(version), tonumber(index), tonumber(count)
    if not (version and index and count and version >= 0 and index >= 1
        and count >= 1 and count <= MAX_PARTICIPANTS and index <= count
        and #encoded <= MAX_ROSTER_CHUNK) then return nil end
    game.playerVersions = game.playerVersions or {}
    if version <= (game.playerVersions[kind] or 0) then return nil end
    game.playerAssemblies = game.playerAssemblies or {}
    local assembly = game.playerAssemblies[kind]
    if assembly and version < assembly.version then return nil end
    if not (assembly and assembly.version == version and assembly.count == count) then
        assembly = { version = version, count = count, chunks = {} }
        game.playerAssemblies[kind] = assembly
    end
    assembly.chunks[index] = encoded
    for part = 1, count do
        if not assembly.chunks[part] then return nil end
    end
    game.playerAssemblies[kind] = nil
    game.playerVersions[kind] = version
    return DecodePlayers(concat(assembly.chunks, ","))
end

local function BroadcastOpen()
    if not (game and game.isHost) then return end
    SendAddon(AddonPayload("O", game.pool, game.mode, game.joinWord, game.leaveWord, game.hostGUID),
        game.channel)
end

local function SetClassicRound(players, max)
    local expected = RosterMap(players)
    game.phase = "rolling"
    game.round = { expected = expected, rolls = {}, players = players, max = max }
    if game.isHost then
        BroadcastRound()
    end
    UpdateDisplay()
end

local function SetDeathrollTurn(player, max)
    game.phase = "deathroll"
    game.round = { expected = { [player.key] = player }, rolls = {}, players = { player }, max = max }
    if game.isHost then
        SendAddon(AddonPayload("T", max, player.key), game.channel)
    end
    UpdateDisplay()
end

local function StartDeathroll()
    local players = game.participants
    local firstIndex, secondIndex = random(#players), random(#players - 1)
    if secondIndex >= firstIndex then secondIndex = secondIndex + 1 end
    local first, second = players[firstIndex], players[secondIndex]
    SendChat(TEXT_DUEL:format(first.name, second.name, FormatPool(game.pool)), game.channel)
    local starter = random(2) == 1 and first or second
    game.duel = { first = first, second = second, next = starter, pot = game.pool }
    SendAddon(AddonPayload("M", game.pool, first.key, second.key, starter.key), game.channel)
    SendChat(TEXT_DUEL_START:format(starter.name, game.pool), game.channel)
    SetDeathrollTurn(starter, game.pool)
end

local function StartRolling()
    if not game then ns.Print(TEXT_NO_GAME); return end
    if not game.isHost then ns.Print(TEXT_NOT_HOST); return end
    if game.phase ~= "lobby" then ns.Print(TEXT_NOT_LOBBY); return end
    if #game.participants < 2 then
        ns.Print(TEXT_NEED_PLAYERS)
        return
    end
    if game.mode == "deathroll" then
        StartDeathroll()
    else
        SendChat(TEXT_CLASSIC_START:format(game.pool), game.channel)
        SetClassicRound(game.participants, game.pool)
    end
end

local function FinishClassic(winner, loser, amount)
    if winner and loser and winner ~= loser and amount > 0 then
        SendChat(TEXT_SETTLEMENT:format(loser.name, winner.name, FormatPool(amount)), game.channel)
    end
    SendAddon(AddonPayload("D", loser and loser.name or "", winner and winner.name or "", amount), game.channel)
    game.tieBreak = nil
    game.phase = "complete"
    UpdateListening()
    UpdateDisplay()
end

local function ContinueClassicTieBreak()
    local tie = game.tieBreak
    if tie.highPlayers then
        tie.side = "high"
        SetClassicRound(tie.highPlayers, game.pool)
    elseif tie.lowPlayers then
        tie.side = "low"
        SetClassicRound(tie.lowPlayers, game.pool)
    else
        FinishClassic(tie.winner, tie.loser, tie.originalHigh - tie.originalLow)
    end
end

local function ClassicTieBreakResult()
    local tie, round = game.tieBreak, game.round
    local extreme, tied
    for _, player in ipairs(round.players) do
        local value = round.rolls[player.key]
        if tie.side == "high" then
            if extreme == nil or value > extreme then extreme, tied = value, { player }
            elseif value == extreme then tied[#tied + 1] = player end
        elseif extreme == nil or value < extreme then
            extreme, tied = value, { player }
        elseif value == extreme then
            tied[#tied + 1] = player
        end
    end
    if #tied > 1 then
        tie[tie.side .. "Players"] = tied
    elseif tie.side == "high" then
        tie.winner, tie.highPlayers = tied[1], nil
    else
        tie.loser, tie.lowPlayers = tied[1], nil
    end
    ContinueClassicTieBreak()
end

local function ClassicResult()
    if game.tieBreak then
        ClassicTieBreakResult()
        return
    end
    local high, low, highs, lows
    for _, player in ipairs(game.round.players) do
        local value = game.round.rolls[player.key]
        if high == nil or value > high then high, highs = value, { player }
        elseif value == high then highs[#highs + 1] = player end
        if low == nil or value < low then low, lows = value, { player }
        elseif value == low then lows[#lows + 1] = player end
    end
    local tie = {
        originalHigh = high,
        originalLow = low,
        winner = #highs == 1 and highs[1] or nil,
        loser = #lows == 1 and lows[1] or nil,
        highPlayers = #highs > 1 and highs or nil,
        lowPlayers = #lows > 1 and lows or nil,
    }
    if high == low then
        SendChat(TEXT_FULL_TIE:format(high, game.round.max), game.channel)
        SetClassicRound(game.round.players, game.round.max)
    elseif tie.highPlayers or tie.lowPlayers then
        game.tieBreak = tie
        ContinueClassicTieBreak()
    else
        FinishClassic(tie.winner, tie.loser, tie.originalHigh - tie.originalLow)
    end
end

local function DeathrollResult(player, value)
    local duel = game.duel
    if not duel then return end
    if value == 1 then
        local winner = player.key == duel.first.key and duel.second or duel.first
        SendChat(TEXT_SETTLEMENT:format(player.name, winner.name, FormatPool(duel.pot)), game.channel)
        SendAddon(AddonPayload("D", player.name, winner.name, duel.pot), game.channel)
        game.phase = "complete"
        UpdateListening()
        UpdateDisplay()
        return
    end
    local nextPlayer = player.key == duel.first.key and duel.second or duel.first
    duel.next = nextPlayer
    SetDeathrollTurn(nextPlayer, value)
end

local function OnRoll(player, value, minimum, maximum)
    local key = player.key
    if minimum ~= 1 or maximum ~= game.round.max or value < minimum or value > maximum then return end
    if game.round.rolls[key] then return end
    game.round.rolls[key] = value
    UpdateDisplay()
    if not game.isHost then return end
    local count = 0
    for _ in pairs(game.round.expected) do count = count + 1 end
    local rolled = 0
    for _ in pairs(game.round.rolls) do rolled = rolled + 1 end
    if rolled < count then return end
    if game.phase == "rolling" then
        ClassicResult()
    elseif game.phase == "deathroll" then
        DeathrollResult(game.round.expected[key], value)
    end
end

local function CompileRollPattern(format, expectedCaptures)
    if type(format) ~= "string" then return nil end
    local pattern, captures, index = { "^" }, 0, 1
    while index <= #format do
        local char = format:sub(index, index)
        if char == "%" and index < #format then
            local nextChar = format:sub(index + 1, index + 1)
            if nextChar == "s" then
                pattern[#pattern + 1], captures, index = "(.+)", captures + 1, index + 2
            elseif nextChar == "d" then
                pattern[#pattern + 1], captures, index = "(%d+)", captures + 1, index + 2
            else
                pattern[#pattern + 1] = PATTERN_ESCAPE[char] or char
                index = index + 1
            end
        else
            pattern[#pattern + 1] = PATTERN_ESCAPE[char] or char
            index = index + 1
        end
    end
    pattern[#pattern + 1] = "$"
    if captures ~= expectedCaptures then return nil end
    return concat(pattern)
end

local ROLL_PATTERN = CompileRollPattern(_G.RANDOM_ROLL_RESULT, ROLL_CAPTURES)
local SELF_ROLL_PATTERN = CompileRollPattern(_G.YOU_ROLL_RESULT, SELF_ROLL_CAPTURES)

local function Roller(name)
    local found
    for _, player in pairs(game.round.expected) do
        if player.name == name then
            if found then return nil end
            found = player
        end
    end
    return found
end

local function OnSystemMessage(message)
    if Secret(message) or type(message) ~= "string" or not (ROLL_PATTERN and game and game.round) then return end
    local player
    local name, value, minimum, maximum = message:match(ROLL_PATTERN)
    if name then
        player = Roller(Ambiguate(name, "none"))
    elseif SELF_ROLL_PATTERN then
        value, minimum, maximum = message:match(SELF_ROLL_PATTERN)
        if value then player = game.round.expected[UnitGUID("player")] end
    end
    if not player then return end
    OnRoll(player, tonumber(value), tonumber(minimum), tonumber(maximum))
end

local function OnChannelMessage(event, message, sender, _, _, _, _, _, _, _, _, _, guid)
    if Secret(message) or Secret(sender) or Secret(guid) then return end
    if not (game and game.isHost and game.phase == "lobby" and CHAT_EVENTS[event] == game.channel
        and type(message) == "string" and type(sender) == "string" and IsPlayerGUID(guid)) then return end
    local word = lower(trim(message))
    if word == lower(game.joinWord) then
        local player = AddPlayer(guid, Ambiguate(sender, "none"))
        if not player then return end
        SendAddon(AddonPayload("J", guid, player.name), game.channel)
        UpdateDisplay()
    elseif word == lower(game.leaveWord) then
        local player = game.players[guid]
        if not player then return end
        RemovePlayer(guid)
        SendChat(TEXT_LEFT:format(player.name), game.channel)
        SendAddon(AddonPayload("L", guid), game.channel)
        UpdateDisplay()
    end
end

local function OpenPayload(sender, channel, id, pool, mode, joinWord, leaveWord, hostGUID)
    local amount = tonumber(pool)
    if not (amount and amount >= 1 and amount <= MAX_POOL and amount == floor(amount)
        and (mode == "classic" or mode == "deathroll") and #id <= MAX_ID
        and ValidWords(joinWord, leaveWord) and IsPlayerGUID(hostGUID)) then return end
    if game and game.phase ~= "complete" then return end
    if not ns.SenderIs(sender, channel, hostGUID) then return end
    game = {
        id = id, pool = amount, mode = mode, channel = channel, phase = "lobby",
        hostGUID = hostGUID, isHost = false, participants = {}, players = {},
        joinWord = joinWord, leaveWord = leaveWord,
    }
    UpdateListening()
    UpdateDisplay()
end

local function OnAddonMessage(prefix, message, channel, sender)
    if Secret(prefix) or Secret(message) or Secret(channel) or Secret(sender) then return end
    if prefix ~= PREFIX or type(message) ~= "string" or type(sender) ~= "string" then return end
    if message == "Q" then
        if game and game.isHost and game.phase ~= "complete" and game.channel == channel then
            BroadcastOpen()
            BroadcastRoster()
            if game.phase == "rolling" and game.round then
                BroadcastRound()
            elseif game.phase == "deathroll" and game.round then
                SendAddon(AddonPayload("M", game.duel.pot, game.duel.first.key, game.duel.second.key,
                    game.duel.next.key), game.channel)
                SendAddon(AddonPayload("T", game.round.max, game.round.players[1].key), game.channel)
            end
        end
        return
    end
    local kind, id, rest = message:match("^([A-Z])|([^|]+)|?(.*)$")
    if kind == "O" then
        local pool, mode, joinWord, leaveWord, hostGUID = rest:match("^(%d+)|([^|]+)|([^|]*)|([^|]*)|([^|]*)$")
        if pool and ChannelAvailable(channel) then
            OpenPayload(sender, channel, id, pool, mode, joinWord, leaveWord, hostGUID)
        end
        return
    end
    if not (game and not game.isHost and game.id == id and game.channel == channel) then return end
    if not ns.SenderIs(sender, channel, game.hostGUID) then return end
    if kind == "J" then
        local guid, name = rest:match("^([^|]+)|([^|]+)$")
        if IsPlayerGUID(guid) and #name <= MAX_PLAYER_NAME and AddPlayer(guid, name) then UpdateDisplay() end
    elseif kind == "L" then
        if RemovePlayer(rest) then UpdateDisplay() end
    elseif kind == "R" then
        local version, index, count, chunk = rest:match("^(%d+)|(%d+)|(%d+)|(.+)$")
        local players = chunk and AssemblePlayers("R", version, index, count, chunk)
        if players and #players > 0 then
            game.participants, game.players = players, RosterMap(players)
            UpdateDisplay()
        end
    elseif kind == "C" then
        local version, max, index, count, chunk =
            rest:match("^(%d+)|(%d+)|(%d+)|(%d+)|(.+)$")
        local players = chunk and AssemblePlayers("C", version, index, count, chunk)
        max = tonumber(max)
        if max and max <= MAX_POOL and players and #players > 0 then
            game.phase, game.mode = "rolling", "classic"
            game.round = { expected = RosterMap(players), players = players, rolls = {}, max = max }
            UpdateDisplay()
        end
    elseif kind == "M" then
        local amount, firstGUID, secondGUID, starter = rest:match("^(%d+)|([^|]+)|([^|]+)|([^|]+)$")
        amount = tonumber(amount)
        local first, second, firstRoller = game.players[firstGUID], game.players[secondGUID], game.players[starter]
        if amount and amount <= MAX_POOL and first and second and firstRoller then
            game.mode = "deathroll"
            game.duel = { first = first, second = second, next = firstRoller, pot = amount }
            UpdateDisplay()
        end
    elseif kind == "T" then
        local max, guid = rest:match("^(%d+)|([^|]+)$")
        max = tonumber(max)
        local player = game.players[guid]
        if max and max <= MAX_POOL and player then
            game.mode = "deathroll"
            game.duel = game.duel or { first = player, second = player, next = player, pot = game.pool }
            game.phase = "deathroll"
            game.round = { expected = { [player.key] = player }, players = { player }, rolls = {}, max = max }
            UpdateDisplay()
        end
    elseif kind == "D" and game.phase ~= "complete" then
        local amount = rest:match("^[^|]*|[^|]*|(%d+)$")
        amount = tonumber(amount)
        if amount and amount <= MAX_POOL then
            game.phase = "complete"
            UpdateListening()
            UpdateDisplay()
        end
    elseif kind == "X" then
        game.phase = "complete"
        game.cancelled = true
        UpdateListening()
        UpdateDisplay()
    end
end

local function EndRemoteSessionIfHostLeft()
    if not (game and not game.isHost and game.phase ~= "complete")
        or HostIsConnected() then return end
    game.phase, game.cancelled, game.hostLeft = "complete", true, true
    UpdateListening()
    UpdateDisplay()
end

function OnEvent(_, event, ...)
    if event == "CHAT_MSG_SYSTEM" then
        OnSystemMessage(...)
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_CONNECTION" then
        EndRemoteSessionIfHostLeft()
    elseif CHAT_EVENTS[event] then
        OnChannelMessage(event, ...)
    end
end

local function GetPool()
    local amount = ParsePool(poolBox:GetText() or "")
    if not amount then
        ns.Print(TEXT_BAD_POOL:format(FormatPool(MAX_POOL)))
        return nil
    end
    S.Set("gamblePool", FormatPool(amount))
    return amount
end

local function NewGame()
    if not IsOn() then ns.Print(TEXT_NOT_ACTIVE); return end
    EndRemoteSessionIfHostLeft()
    if game and game.phase ~= "complete" and not game.isHost then
        ns.Print(TEXT_NOT_HOST)
        return
    end
    if game and game.phase ~= "complete" and game.phase ~= "lobby" then
        ns.Print(TEXT_NOT_LOBBY)
        return
    end
    local channel = S.Get("gambleChannel")
    if not CHANNEL_LABEL[channel] then
        channel = "PARTY"
        S.Set("gambleChannel", channel)
    end
    if not ChannelAvailable(channel) then
        ns.Print(TEXT_NEED_GROUP)
        return
    end
    local pool = GetPool()
    if not pool then return end
    local joinWord, leaveWord = S.Get("gambleJoinWord"), S.Get("gambleLeaveWord")
    if not ValidWords(joinWord, leaveWord) then
        ns.Print(TEXT_BAD_WORD)
        return
    end
    if game and game.isHost and game.phase == "lobby" then
        SendAddon(AddonPayload("X"), game.channel)
    end
    game = nil
    local mode = S.Get("gambleMode")
    if mode ~= "deathroll" then mode = "classic" end
    game = {
        id = ("%d:%s"):format(floor(GetTime() * MS_PER_SECOND), UnitGUID("player")),
        pool = pool, mode = mode, channel = channel, phase = "lobby", isHost = true,
        hostGUID = UnitGUID("player"), participants = {}, players = {},
        joinWord = joinWord, leaveWord = leaveWord,
    }
    UpdateListening()
    BroadcastOpen()
    SendChat(TEXT_STARTED:format(MODE_LABEL[mode], FormatPool(pool), game.joinWord, game.leaveWord), channel)
    UpdateDisplay()
end

local function LastCall()
    if not (game and game.isHost and game.phase == "lobby") then ns.Print(TEXT_NOT_LOBBY); return end
    SendChat(TEXT_LAST:format(game.joinWord, CHANNEL_CHAT[game.channel]), game.channel)
end

local function CancelSession()
    if not game or game.phase == "complete" then ns.Print(TEXT_NO_GAME); return end
    if not game.isHost then ns.Print(TEXT_NOT_HOST); return end
    SendAddon(AddonPayload("X"), game.channel)
    SendChat(TEXT_CANCELLED:format(UnitName("player")), game.channel)
    game.phase = "complete"
    game.cancelled = true
    UpdateListening()
    UpdateDisplay()
end

local function AnnounceRolls()
    if not (game and game.isHost and game.round) then return end
    if game.phase == "deathroll" then
        local player = game.duel and game.duel.next or game.round.players[1]
        if player then SendChat(TEXT_NEXT_ROLL:format(player.name, game.round.max), game.channel) end
        return
    end
    if game.phase ~= "rolling" then return end
    local waiting = {}
    for _, player in ipairs(game.round.players) do
        if not game.round.rolls[player.key] then waiting[#waiting + 1] = player.name end
    end
    local message = #waiting > 0 and TEXT_STILL_NEED:format(Names(waiting), game.round.max)
        or TEXT_NO_ROLLS
    SendChat(message, game.channel)
end

local function CycleChannel()
    local current = S.Get("gambleChannel") or "PARTY"
    local nextIndex = 1
    for index, channel in ipairs(CHANNELS) do
        if channel == current then nextIndex = index % #CHANNELS + 1; break end
    end
    S.Set("gambleChannel", CHANNELS[nextIndex])
    ns.SetButtonText(channelButton, TEXT_CHANNEL:format(CHANNEL_LABEL[CHANNELS[nextIndex]]))
end

local function SaveWords()
    local joinWord = trim(joinBox:GetText() or "")
    local leaveWord = trim(leaveBox:GetText() or "")
    if not ValidWords(joinWord, leaveWord) then
        ns.Print(TEXT_BAD_WORD)
        return
    end
    S.Set("gambleJoinWord", joinWord)
    S.Set("gambleLeaveWord", leaveWord)
    joinBox:SetText(joinWord)
    leaveBox:SetText(leaveWord)
end

local function ToggleMode()
    S.Set("gambleMode", S.Get("gambleMode") == "deathroll" and "classic" or "deathroll")
    ns.SetButtonText(modeButton, TEXT_MODE:format(MODE_LABEL[S.Get("gambleMode")]))
end

local function SavePool()
    if not poolBox then return end
    GetPool()
    poolBox:ClearFocus()
end

local function ShowHelp(show)
    if not helpView then return end
    helpView:SetShown(show)
    controls:SetShown(not show)
    status:SetShown(not show)
    roster:SetShown(not show)
    newButton:SetShown(not show)
    lastCallButton:SetShown(not show)
    startButton:SetShown(not show)
    cancelButton:SetShown(not show)
    ns.SetButtonText(helpButton, show and TEXT_BACK or TEXT_HELP)
end

local function ToggleHelp()
    ShowHelp(not helpView:IsShown())
end

local function CreateControls()
    controls = CreateFrame("Frame", nil, window)
    controls:SetPoint("TOPLEFT", window, "TOPLEFT", INSET, -(HEADER + INSET + ROW_GAP))
    controls:SetSize(WINDOW_W - INSET * 2, CONTROLS_H)
    local poolLabel = ns.Font(controls, LABEL_FONT, nil, T.muted)
    poolLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", PAD, 0)
    poolLabel:SetText(TEXT_POOL)
    poolBox = ns.NewEditBox(controls, { inset = FIELD_INSET })
    poolBox:SetSize(POOL_W, POOL_H)
    poolBox:SetPoint("LEFT", poolLabel, "RIGHT", ROW_GAP, 0)
    poolBox:SetText(S.Get("gamblePool"))
    poolBox:SetScript("OnEnterPressed", SavePool)
    poolBox:SetScript("OnEditFocusLost", SavePool)

    channelButton = ns.Button(controls, "", CHANNEL_W, CHANNEL_H, CycleChannel)
    channelButton:SetPoint("LEFT", poolBox, "RIGHT", ROW_GAP, 0)
    ns.SetButtonText(channelButton,
        TEXT_CHANNEL:format(CHANNEL_LABEL[S.Get("gambleChannel")] or CHANNEL_LABEL.PARTY))
    announceButton = ns.Button(controls, TEXT_ANNOUNCE, ANNOUNCE_W, CHANNEL_H, AnnounceRolls)
    announceButton:SetPoint("LEFT", channelButton, "RIGHT", ROW_GAP, 0)

    local configTop = POOL_H + ROW_GAP
    local joinLabel = ns.Font(controls, LABEL_FONT, nil, T.muted)
    joinLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", PAD, -configTop)
    joinLabel:SetText(TEXT_JOIN_WORD)
    joinBox = ns.NewEditBox(controls, { inset = FIELD_INSET })
    joinBox:SetSize(CONFIG_FIELD_W, WORD_FIELD_H)
    joinBox:SetPoint("TOPLEFT", controls, "TOPLEFT", PAD, -(configTop + WORD_LABEL_H))
    joinBox:SetText(S.Get("gambleJoinWord") or "join")
    joinBox:SetScript("OnEnterPressed", SaveWords)
    joinBox:SetScript("OnEditFocusLost", SaveWords)

    local leaveLabel = ns.Font(controls, LABEL_FONT, nil, T.muted)
    leaveLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", PAD + CONFIG_FIELD_W + WORD_GAP, -configTop)
    leaveLabel:SetText(TEXT_LEAVE_WORD)
    leaveBox = ns.NewEditBox(controls, { inset = FIELD_INSET })
    leaveBox:SetSize(CONFIG_FIELD_W, WORD_FIELD_H)
    leaveBox:SetPoint("TOPLEFT", controls, "TOPLEFT", PAD + CONFIG_FIELD_W + WORD_GAP, -(configTop + WORD_LABEL_H))
    leaveBox:SetText(S.Get("gambleLeaveWord") or "leave")
    leaveBox:SetScript("OnEnterPressed", SaveWords)
    leaveBox:SetScript("OnEditFocusLost", SaveWords)

    modeButton = ns.Button(controls, "", MODE_BUTTON_W, BUTTON_H, ToggleMode)
    modeButton:SetPoint("LEFT", leaveBox, "RIGHT", ROW_GAP, 0)
    ns.SetButtonText(modeButton, TEXT_MODE:format(MODE_LABEL[S.Get("gambleMode")] or MODE_LABEL.classic))
end

local function CreateWindow()
    window = Parts.Window(WINDOW_W, WINDOW_H, "gambleWindow")
    window.backdrop:Card(PAD, HEADER + PAD, PAD, FOOTER + PAD)
    local closeButton = Parts.TitleBar(window, TITLE, SUBTITLE, PAGE)
    helpButton = ns.Button(window, TEXT_HELP, HELP_BUTTON_W, BUTTON_H, ToggleHelp)
    helpButton:SetPoint("RIGHT", closeButton, "LEFT", -ROW_GAP, 0)
    Parts.FooterBrand(window, PAGE)
    CreateControls()

    helpView = CreateFrame("Frame", nil, window)
    helpView:SetPoint("TOPLEFT", window, "TOPLEFT", INSET, -(HEADER + INSET))
    helpView:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -INSET, FOOTER + INSET)
    local helpScroll = ns.UI.SlimScroll(helpView)
    helpScroll:SetPoint("TOPLEFT")
    helpScroll:SetPoint("BOTTOMRIGHT", -HELP_SCROLL_GAP, 0)
    local helpContent = CreateFrame("Frame", nil, helpScroll)
    helpContent:SetSize(WINDOW_W - INSET * 2 - HELP_GUTTER, 1)
    helpScroll:SetScrollChild(helpContent)
    local helpText = ns.Font(helpContent, TEXT_FONT, nil, T.fg)
    helpText:SetPoint("TOPLEFT", helpContent, "TOPLEFT", 0, 0)
    helpText:SetWidth(WINDOW_W - INSET * 2 - HELP_GUTTER)
    helpText:SetJustifyH("LEFT")
    helpText:SetJustifyV("TOP")
    helpText:SetWordWrap(true)
    helpText:SetText(ns.L(ns.GambleHelpText))
    local textHeight = helpText:GetStringHeight()
    helpContent:SetHeight(textHeight > 0 and textHeight or HELP_TEXT_HEIGHT)
    helpView:Hide()

    status = ns.Font(window, TEXT_FONT, "OUTLINE", T.accent)
    status:SetPoint("TOPLEFT", INSET, -(HEADER + INSET + CONTROLS_H + ROW_GAP))
    roster = ns.Font(window, LABEL_FONT)
    roster:SetPoint("TOPLEFT", INSET, -(HEADER + INSET + CONTROLS_H + ROW_GAP + STATUS_H))
    roster:SetPoint("RIGHT", -INSET, 0)
    roster:SetHeight(ROSTER_H)
    roster:SetJustifyH("LEFT")
    roster:SetJustifyV("TOP")

    newButton = ns.Button(window, TEXT_NEW, BUTTON_W, BUTTON_H, NewGame)
    lastCallButton = ns.Button(window, TEXT_LAST_CALL, BUTTON_W, BUTTON_H, LastCall)
    startButton = ns.AccentBorder(ns.Button(window, TEXT_START, BUTTON_W, BUTTON_H, StartRolling))
    cancelButton = ns.Button(window, TEXT_CANCEL, BUTTON_W, BUTTON_H, CancelSession)
    local rowWidth = BUTTON_W * 4 + BUTTON_GAP * 3
    local rowLeft = floor((WINDOW_W - rowWidth) / 2)
    local rowBottom = FOOTER + PAD + BUTTON_LIFT
    newButton:SetPoint("BOTTOMLEFT", rowLeft, rowBottom)
    lastCallButton:SetPoint("BOTTOMLEFT", rowLeft + BUTTON_W + BUTTON_GAP, rowBottom)
    startButton:SetPoint("BOTTOMLEFT", rowLeft + (BUTTON_W + BUTTON_GAP) * 2, rowBottom)
    cancelButton:SetPoint("BOTTOMLEFT", rowLeft + (BUTTON_W + BUTTON_GAP) * 3, rowBottom)
    window:HookScript("OnShow", function()
        UpdateListening()
        RequestOpenSessions()
        UpdateDisplay()
    end)
    window:HookScript("OnHide", UpdateListening)
    UpdateDisplay()
end

function ns.ToggleGamble()
    if not IsOn() then ns.Print(TEXT_NOT_ACTIVE); return end
    if not window then CreateWindow() end
    if window:IsShown() then
        window:Hide()
    else
        window:SetScale(ns.UIScale())
        window:Show()
        window.backdrop:Paint(1)
    end
end

local function OpenGamble()
    ns.StashOptionsWindow()
    ns.ToggleGamble()
end

local function OnSettingChanged(key)
    if key == "enabled" or key == "gamble" then
        if not IsOn() then
            game = nil
            if window then window:Hide() end
        end
        UpdateListening()
    elseif key == "gambleChannel" and channelButton then
        local channel = game and game.phase ~= "complete" and game.channel or S.Get("gambleChannel")
        ns.SetButtonText(channelButton,
            TEXT_CHANNEL:format(CHANNEL_LABEL[channel] or CHANNEL_LABEL.PARTY))
    elseif key == "gambleMode" and modeButton then
        ns.SetButtonText(modeButton,
            TEXT_MODE:format(MODE_LABEL[S.Get("gambleMode")] or MODE_LABEL.classic))
    end
    UpdateDisplay()
end

S.OnChange(OnSettingChanged)
ns.Shared.Settings.Page(PAGE, S):Card({
    id = "gamble", name = "Gamble", order = 50, switch = "gamble",
    help = "Run Classic gambling sessions or a two-player Deathroll.",
    rows = {
        { label = "Open Gamble", buttonText = "Open", button = OpenGamble,
          help = "Opens the Gamble window." },
    },
})

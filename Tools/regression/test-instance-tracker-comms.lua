-- Nova Instance Tracker reset messages. The codec is the real LibSerialize and LibDeflate.
-- The decisions are the functions the tracker sends and accepts. From the repo root:
--   lua5.1 Tools/regression/test-instance-tracker-comms.lua
local function Read(path)
    local f = assert(io.open(path, "rb"))
    local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return source
end
local function Slice(source, a, b)
    local first = assert(source:find(a, 1, true), a)
    return source:sub(first, assert(source:find(b, first + #a, true), b) - 1)
end

strmatch = string.match
assert(loadfile("Libs/LibStub/LibStub.lua"))()
assert(loadfile("Libs/LibSerialize/LibSerialize.lua"))()
assert(loadfile("Libs/LibDeflate/LibDeflate.lua"))()

local tracker = Read("NaowhForever_InstanceTracker/NaowhForever_InstanceTracker.lua")
local code = Slice(tracker, "local NIT_PREFIX = ", "\n-- end Nova reset wire format")
    .. "\nreturn { Encode = NitEncode, Wire = NitWire, Decode = NitDecode,"
    .. " Incoming = NitIncoming, Outbound = NitOutbound, Announce = NitAnnounce,"
    .. " Clear = ClearNamedCopy }\n"
local env = { LibStub = LibStub, ns = { L = dofile("Tools/regression/locale_stub.lua").L } }
setmetatable(env, { __index = _G })
local chunk = assert(loadstring(code))
setfenv(chunk, env)
local Nit = chunk()

local count = 0
local function Case(name, fn)
    fn()
    count = count + 1
    print("PASS " .. name)
end

local STILL = "has been reset (Players still inside old instance can zone out and enter new)."

local function Lives()
    return {
        ["36:"] = { name = "Ragefire Chasm", at = 1 },
        ["36:Heroic"] = { name = "Ragefire Chasm", at = 1 },
        ["33:"] = { name = "Shadowfang Keep", at = 1 },
    }
end

Case("a name with spaces round-trips as one addon message", function()
    local plain = "instanceReset 1 Ragefire Chasm"
    local wire = Nit.Wire(plain)
    assert(type(wire) == "string" and wire ~= "" and #wire <= 255, "one addon message")
    local lead = wire:byte(1)
    assert(lead ~= 1 and lead ~= 2 and lead ~= 3, "not an AceComm multipart control byte")
    assert(Nit.Decode(wire) == plain, Nit.Decode(wire))
end)

Case("the three reset commands clear only that instance", function()
    for _, cmd in ipairs({ "instanceReset", "instanceResetNoMsg", "instanceResetOther" }) do
        local lives = Lives()
        local hour = { { name = "Ragefire Chasm" }, { name = "Shadowfang Keep" } }
        local instance = Nit.Incoming(cmd .. " 1 Ragefire Chasm", "Leader", "Realm", "Realm", { Leader = true })
        assert(instance == "Ragefire Chasm", cmd)
        assert(Nit.Clear(lives, instance))
        assert(lives["36:"] == nil and lives["36:Heroic"] == nil, cmd .. " clears every copy of that name")
        assert(lives["33:"].name == "Shadowfang Keep", cmd .. " leaves a different instance")
        assert(#hour == 2 and hour[1].name == "Ragefire Chasm", "the hour list is not shortened")
    end
end)

Case("only a reset without the chat line is printed", function()
    local _, line = Nit.Incoming("instanceReset 1 Deadmines", "Leader", "Realm", "Realm", { Leader = true })
    assert(line == nil)
    local instance, printed = Nit.Incoming("instanceResetNoMsg 1 Deadmines", "Mage-Realm", "Realm", "Realm",
        { Mage = true })
    assert(instance == "Deadmines")
    assert(printed == "Deadmines has been reset by the group leader (Mage).", printed)
    _, printed = Nit.Incoming("instanceResetOther 1 Deadmines", "Glyadin Skywolf", "Realm", "Realm", nil)
    assert(printed == "Deadmines has been reset by the group leader (Glyadin Skywolf).", printed)
end)

Case("an old version and a member who is not the leader are dropped", function()
    assert(Nit.Incoming("instanceReset 0.99 Deadmines", "Leader", "Realm", "Realm", { Leader = true }) == nil)
    assert(Nit.Incoming("instanceReset nope Deadmines", "Leader", "Realm", "Realm", { Leader = true }) == nil)
    assert(Nit.Incoming("instanceReset 1 Deadmines", "Mage", "Realm", "Realm", { Mage = false, Leader = true }) == nil)
    local instance = Nit.Incoming("instanceReset 1 Deadmines", "Glyadin Skywolf", "Realm", "Realm", { Leader = true })
    assert(instance == "Deadmines", "a full name no unit returns is still taken")
    assert(Nit.Incoming("instanceReset 1 Deadmines", "Mage-Other", "Realm", "Realm", nil) == nil)
end)

Case("a successful reset sends the chat line and instanceReset", function()
    local chat, plain = Nit.Outbound("success", "Deadmines", "Deadmines has been reset.", true)
    assert(chat == "[NIT] Deadmines has been reset.", chat)
    assert(plain == "instanceReset 1 Deadmines", plain)
    chat, plain = Nit.Outbound("inside", "Deadmines", "Cannot reset Deadmines.", true)
    assert(chat == "[NIT] Deadmines " .. STILL, chat)
    assert(plain == "instanceReset 1 Deadmines", plain)
end)

Case("reset chat follows the setting, Nova, and a lock", function()
    assert(Nit.Announce(false, false, false) == "addon", "setting off sends no chat line")
    assert(Nit.Announce(true, true, false) == nil, "Nova loaded sends nothing")
    assert(Nit.Announce(false, true, false) == nil, "Nova loaded still sends nothing")
    assert(Nit.Announce(true, false, true) == "addon", "chat locked sends no chat line")
    assert(Nit.Announce(true, false, false) == "chat", "setting on sends the chat line")
end)

Case("a failed chat send uses instanceResetNoMsg and no chat line", function()
    local chat, plain = Nit.Outbound("success", "Deadmines", "Deadmines has been reset.", false)
    assert(chat == nil)
    assert(plain == "instanceResetNoMsg 1 Deadmines", plain)
    chat, plain = Nit.Outbound("inside", "Wailing Caverns", "Cannot reset Wailing Caverns.", false)
    assert(chat == nil)
    assert(plain == "instanceResetNoMsg 1 Wailing Caverns", plain)
    chat, plain = Nit.Outbound("zoning", "Deadmines", "Cannot reset Deadmines. Players are zoning.", true)
    assert(chat == "[NIT] Cannot reset Deadmines. Players are zoning.", chat)
    assert(plain == nil)
    chat, plain = Nit.Outbound("offline", "Deadmines", "Cannot reset Deadmines. Players are offline.", false)
    assert(chat == nil and plain == nil)
end)

print(count .. " instance tracker comm regressions passed")

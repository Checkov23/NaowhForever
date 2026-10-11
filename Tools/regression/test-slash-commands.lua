-- Run with Lua 5.1 from the repository root: a custom slash command that runs another
-- command calls that command's handler itself. Running it through the chat box (SetText,
-- SendText) ran the game's chat code from the addon and blocked the player's next chat
-- message, so the chat box must never be touched. Secure macro commands (/cast, /use,
-- /target) are not run at all; the player is told why.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"):gsub("\r\n", "\n"); f:close()
    return s
end

-- Any use of the chat box at all is recorded.
local touched = {}
local function ChatBox(label)
    return setmetatable({}, {
        __index = function(_, key)
            touched[#touched + 1] = label .. "." .. tostring(key)
            return function() return "" end
        end,
        __newindex = function(_, key) touched[#touched + 1] = label .. "." .. tostring(key) end,
    })
end

local function noop() end
local frame = { RegisterEvent = noop, SetScript = noop }
local settings = { enabled = true, slashCommands = true }
local db = {}
local printed = {}
local gamepad = false
local emotes = {}
local secure = { ["/CAST"] = true, ["/USE"] = true, ["/TARGET"] = true }

-- The game's SlashCmdList, with the table its metatable reads entries from once the chat box
-- has moved them there.
local proxy = {}
local env = {
    NaowhForever = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
        QoLSettings = {
            Get = function(key) return settings[key] end,
            DB = function() return db end,
            Set = noop,
        },
        UI = {}, THEME = {},
        Print = function(msg) printed[#printed + 1] = msg end,
        GamepadOwnsPanels = function() return gamepad end,
        Apply = noop,
    },
    SlashCmdList = setmetatable({}, { __index = proxy }),
    hash_SlashCmdList = {},
    hash_EmoteTokenList = { ["/DANCE"] = "DANCE" },
    C_ChatInfo = {
        PerformEmote = function(token, target)
            emotes[#emotes + 1] = { token = token, target = target }
        end,
    },
    IsSecureCmd = function(command) return secure[string.upper(command)] or nil end,
    ChatFrame1EditBox = ChatBox("ChatFrame1EditBox"),
    DEFAULT_CHAT_FRAME = { editBox = ChatBox("DEFAULT_CHAT_FRAME.editBox") },
    CreateFrame = function() return frame end,
    hooksecurefunc = noop,
    CopyTable = function(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end,
    strupper = string.upper, strlower = string.lower,
    strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
    InCombatLockdown = function() return false end,
    C_AddOns = {
        DoesAddOnExist = function() return false end,
        IsAddOnLoaded = function() return true end,
    },
}
env._G = env
setmetatable(env, { __index = _G })
local chunk = assert(loadstring(Read("NaowhForever_QoL/System/SlashCommands.lua"), "SlashCommands"))
setfenv(chunk, env)
chunk()
local ns = env.NaowhForever

-- Handlers that record what they were called with.
local calls = {}
local function Handler(label)
    return function(msg, box)
        calls[#calls + 1] = { label = label, msg = msg, box = box }
    end
end

-- Not yet moved by the chat box: still a plain SlashCmdList entry, with two aliases.
env.SLASH_FOO1, env.SLASH_FOO2 = "/foo", "/fo"
rawset(env.SlashCmdList, "FOO", Handler("foo"))
-- Already moved into the hash the chat box keeps.
env.hash_SlashCmdList["/BAR"] = Handler("bar")
-- Moved into the proxy, with the hash entry since cleared by its addon.
env.SLASH_BAZ1 = "/baz"
proxy.BAZ = Handler("baz")
env.SLASH_RELOAD1 = "/reload"
proxy.RELOAD = Handler("reload")

db.slashList = {
    { name = "f", command = "/foo hello", enabled = true },
    { name = "o", command = "FO", enabled = true },
    { name = "b", command = "/bar", enabled = true },
    { name = "z", command = "/baz", enabled = true },
    { name = "c", command = "/cast Fireball", enabled = true },
    { name = "t", command = "/target", enabled = true },
    { name = "s", command = "/say", enabled = true },
    { name = "d", command = "/dance", enabled = true },
    { name = "r", command = "/reload", enabled = true },
    { name = "kb", frame = "QuickKeybindFrame", enabled = true },
}
local kb = { shown = false }
function kb:IsShown() return self.shown end
function kb:SetShown(v) self.shown = v end
env.QuickKeybindFrame = kb
ns.RefreshSlashCommands()

local function Run(name, msg)
    local id = "NAOWHFOREVER_" .. string.upper(name)
    check("/" .. name .. " is registered", env["SLASH_" .. id .. "1"] == "/" .. name)
    local before = #calls
    env.SlashCmdList[id](msg)
    return calls[before + 1], #calls - before
end

local call, n = Run("f", "world")
check("a plain SlashCmdList command runs once", n == 1 and call.label == "foo")
check("its own text and the typed text are passed on", call.msg == "hello world")
check("with no chat box", call.box == nil)

call = Run("o", "")
check("a command without a slash, by its second alias, runs", call and call.label == "foo"
    and call.msg == "")

call = Run("b", "  x y  ")
check("a command the chat box has already hashed runs", call and call.label == "bar")
check("typed text is trimmed like the chat box does", call.msg == "x y")

call = Run("z", "")
check("a command moved behind SlashCmdList's metatable runs", call and call.label == "baz")

local printedBefore = #printed
n = select(2, Run("c", ""))
check("/cast is not run", n == 0)
check("and the player is told it can't be", printed[#printed] ~= nil
    and #printed == printedBefore + 1 and printed[#printed]:find("/cast can't be run", 1, true))
n = select(2, Run("t", "party1"))
check("/target is not run", n == 0 and printed[#printed]:find("/target can't be run", 1, true))

n = select(2, Run("s", "hello"))
check("an unknown command (a chat type) runs nothing and says so", n == 0
    and printed[#printed]:find("/say isn't a command", 1, true))

printedBefore = #printed
n = select(2, Run("d", "Bob"))
check("an emote is performed with the typed target", n == 0 and #emotes == 1
    and emotes[1].token == "DANCE" and emotes[1].target == "Bob" and #printed == printedBefore)

n = select(2, Run("r", ""))
check("/reload is not run, since the game blocks it from addon code", n == 0
    and printed[#printed]:find("Type /reload", 1, true))

Run("kb", "")
check("a window command still opens its window", kb.shown)
gamepad = true
Run("kb", "")
check("with a gamepad a window command leaves the window alone and says so", kb.shown
    and printed[#printed]:find("with a gamepad", 1, true))
gamepad = false

check("the chat box was never touched: " .. table.concat(touched, ", "), #touched == 0)

-- No code in the module reaches for the game's chat box.
local source = Read("NaowhForever_QoL/System/SlashCommands.lua")
for _, word in ipairs({ "SendText", "ChatFrame1EditBox", "DEFAULT_CHAT_FRAME", "ChatEdit_" }) do
    check("the module does not use " .. word, not source:find(word, 1, true))
end

print(("test-slash-commands: %d checks passed"):format(checks))

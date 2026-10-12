-- Run with Lua 5.1 from the repository root: Group Tools' on-screen Invite and Disband buttons.
-- Nothing is made while off; Invite runs the game's /invite from a secure button; the layout
-- stacks or lines up; secure changes wait for the end of a fight; Disband waits too; each kept
-- person gets a button, with Invite All and the target Invite as switches.
local NOTHING = function() end
local frames, printed, disbanded, invited, invitedAll = {}, {}, 0, {}, 0
local combat = false

local function Frame(kind, parent, template)
    local f = { kind = kind, parent = parent, template = template, scripts = {}, attrs = {}, events = {} }
    setmetatable(f, { __index = function(_, k)
        if type(k) == "string" and k:find("^%u") then return NOTHING end
    end })
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:SetAttribute(k, v) self.attrs[k] = v end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(v) self.shown = v and true or false end
    function f:IsShown() return self.shown == true end
    function f:SetText(text) self.text = text end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetPoint(...) self.point = { ... } end
    function f:SetFont(path, size, flags) self.font, self.size, self.flags = path, size, flags end
    frames[#frames + 1] = f
    return f
end

local settings = { enabled = true, groupButtonsTarget = true, groupButtonsInviteAll = false, groupButtonsWidth = 90, groupButtonsHeight = 24, groupButtonsFont = "",
    groupButtonsFontSize = 12, groupButtonsOutline = "NONE", groupButtonsBackground = "card" }
local setHooks = {}
local S = { Get = function(k) return settings[k] end }
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,
    QoLSettings = S,
    THEME = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end }),
    UI = { AttachMover = function(parent) return Frame("Mover", parent) end,
        FontPath = function(name) return name == "" and "font" or "lsm:" .. name end },
    Shared = { Style = dofile("Tools/regression/shared_style.lua"), Parts = { HudFont = function(fs, font, size, outline)
        fs:SetFont(font == "" and "font" or "lsm:" .. font, size, outline == "NONE" and "" or outline)
    end, HudBackdrop = function(_, opts)
        local backdrop = { opts = opts, border = { SetColor = NOTHING } }
        function backdrop:SetMode(mode) self.mode = mode end
        return backdrop
    end } },
    Solid = function(parent) return Frame("Texture", parent) end,
    Border = function() return { SetColor = NOTHING } end,
    Font = function(parent) return Frame("FontString", parent) end,
    Print = function(m) printed[#printed + 1] = m end,
    DisbandGroup = function() disbanded = disbanded + 1 end,
    InvitePerson = function(i) invited[#invited + 1] = i end,
    InviteAll = function() invitedAll = invitedAll + 1 end,
    InviteWho = function(entry) return entry.tag or entry.char end,
    Apply = NOTHING, ShowUnlockMode = NOTHING, HideUnlockMode = NOTHING,
}
local env = setmetatable({
    NaowhForever = ns,
    UIParent = {},
    CreateFrame = function(kind, _, parent, template) return Frame(kind, parent, template) end,
    InCombatLockdown = function() return combat end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    hooksecurefunc = function(t, _, fn)
        if t == S then setHooks[#setHooks + 1] = fn end
    end,
}, { __index = _G })
env._G = env
local chunk = assert(loadfile("NaowhForever_QoL/Questing/GroupButtons.lua"))
setfenv(chunk, env)
chunk()
local events, boot = frames[1], frames[2]

local function Set(k, v)
    settings[k] = v
    for _, fn in ipairs(setHooks) do fn(k) end
end

local function Bar()
    for _, f in ipairs(frames) do
        if f.invite then return f end
    end
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("off by default: nothing is made", function()
    boot.scripts.OnEvent(boot, "PLAYER_LOGIN")
    assert(Bar() == nil and #frames == 2)
end)

Case("on: Invite runs the game's /invite from a secure button, stacked over Disband", function()
    Set("groupButtons", true)
    local bar = Bar()
    assert(bar and bar.shown)
    assert(bar.invite.template == "SecureActionButtonTemplate")
    assert(bar.invite.attrs.type1 == "macro" and bar.invite.attrs.macrotext1 == "/invite")
    assert(bar.disband.template == nil, "Disband is the addon's own")
    assert(bar.w == 90 and bar.h == 52, "stacked: " .. bar.w .. "x" .. bar.h)
    assert(bar.disband.point[3] == "BOTTOMLEFT", "Disband under Invite")
end)

Case("side by side", function()
    Set("groupButtonsLayout", "row")
    local bar = Bar()
    assert(bar.w == 184 and bar.h == 24, "row: " .. bar.w .. "x" .. bar.h)
    assert(bar.disband.point[3] == "TOPRIGHT", "Disband right of Invite")
end)

Case("today's look by default: 90x24, the panel card, the Addon Font at 12 with no outline", function()
    local bar = Bar()
    local invite = bar.invite
    assert(invite.w == 90 and invite.h == 24 and invite.backdrop.mode == "card")
    assert(invite.backdrop.opts.alpha == 0.9, "the panel fill as before")
    assert(invite.label.font == "font" and invite.label.size == 12 and invite.label.flags == "")
end)

Case("size, text and background apply to both buttons", function()
    Set("groupButtonsWidth", 120)
    Set("groupButtonsHeight", 30)
    Set("groupButtonsFont", "Naowh")
    Set("groupButtonsFontSize", 14)
    Set("groupButtonsOutline", "OUTLINE")
    Set("groupButtonsBackground", "none")
    local bar = Bar()
    assert(bar.w == 244 and bar.h == 30, "side by side, wider: " .. bar.w .. "x" .. bar.h)
    for _, button in ipairs({ bar.invite, bar.disband }) do
        assert(button.w == 120 and button.h == 30 and button.backdrop.mode == "none")
        assert(button.label.font == "lsm:Naowh" and button.label.size == 14 and button.label.flags == "OUTLINE")
    end
    Set("groupButtonsWidth", 90)
    Set("groupButtonsHeight", 24)
end)

Case("a change in combat waits for the fight to end", function()
    combat = true
    Set("groupButtonsLayout", "stacked")
    assert(Bar().w == 184 and events.events.PLAYER_REGEN_ENABLED, "nothing moved yet")
    combat = false
    events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
    assert(Bar().w == 90 and not events.events.PLAYER_REGEN_ENABLED, "applied after")
end)

Case("Disband waits for the end of a fight, then disbands", function()
    local bar = Bar()
    combat = true
    bar.disband.scripts.OnClick(bar.disband)
    assert(disbanded == 0 and printed[#printed]:find("fight is over"), "refused in combat")
    combat = false
    bar.disband.scripts.OnClick(bar.disband)
    assert(disbanded == 1)
end)

Case("each kept person gets a button between Invite and Disband", function()
    Set("groupInvites", { { name = "Robin", tag = "Robin#1234" }, { name = "Gly", char = "Glyalith" } })
    local bar = Bar()
    assert(bar.w == 90 and bar.h == 24 * 4 + 4 * 3, "four stacked: " .. bar.w .. "x" .. bar.h)
    local gly = bar.disband.point[2]
    local robin = gly.point[2]
    assert(robin.label.text == "Robin" and robin.point[2] == bar.invite, "Robin under Invite")
    assert(gly.label.text == "Gly" and gly.tip == "Invites Glyalith.")
    gly.scripts.OnClick(gly)
    assert(invited[1] == 2, "the button invites its own person")
end)

Case("Invite All after the people, only when switched on", function()
    local bar = Bar()
    assert(not bar.inviteAll.shown)
    Set("groupButtonsInviteAll", true)
    assert(bar.inviteAll.shown and bar.disband.point[2] == bar.inviteAll)
    bar.inviteAll.scripts.OnClick(bar.inviteAll)
    assert(invitedAll == 1)
end)

Case("the target Invite can go; a removed person's button hides", function()
    Set("groupButtonsTarget", false)
    Set("groupInvites", { { name = "Robin", tag = "Robin#1234" } })
    local bar = Bar()
    assert(not bar.invite.shown, "no target Invite")
    local robin = bar.inviteAll.point[2]
    assert(robin.label.text == "Robin" and robin.point[1] == "TOPLEFT" and robin.point[2] == nil, "Robin first")
    local hidden = 0
    for _, f in ipairs(frames) do
        if f.label and f.label.text == "Gly" and f.shown == false then hidden = hidden + 1 end
    end
    assert(hidden == 1, "Gly's button hidden")
    assert(bar.h == 24 * 3 + 4 * 2)
end)

Case("turning it off hides it", function()
    Set("groupButtons", false)
    assert(Bar().shown == false)
end)

print(("test-group-buttons: %d cases passed"):format(count))

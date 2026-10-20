-- test-roster.lua -- Shared/Game/Roster.lua: lines on a player's tooltip in the Guild & Communities
-- list and the Friends list. Nothing hooked until a module asks; each row hooked once, new and old;
-- lines in the order modules asked; the tooltip shown again only when a line went in; secret GUIDs
-- and a tooltip that isn't the row's are left alone; a friend's lines on our own tooltip under the
-- game's, gone with it. Run from the addon root: lua5.1 Tools/regression/test-roster.lua
local checks = 0
local function check(name, ok)
    assert(ok, name)
    checks = checks + 1
end

local SECRET = {}
local state = { onLoaded = {}, shown = 0, calls = {} }
local function Row(guid)
    local row = { memberInfo = guid and { guid = guid, level = 20 } or nil, hooks = 0 }
    function row.HookScript(self, script, fn)
        self.hooks = self.hooks + 1
        self[script] = fn
    end
    return row
end
local scroll = { rows = { Row("Player-1-A"), Row("Player-1-B") } }
function scroll.RegisterCallback(_, event, fn, owner) state.callback, state.event, state.owner = fn, event, owner end
function scroll.ForEachFrame(self, fn) for _, row in ipairs(self.rows) do fn(row) end end

local tooltip = { owner = nil, shownNow = true }
function tooltip.IsForbidden() return false end
function tooltip.IsShown(self) return self.shownNow end
function tooltip.IsOwned(self, frame) return self.owner == frame end
function tooltip.Show() state.shown = state.shown + 1 end

local friendsTooltip = { shownNow = false, width = 180 }
function friendsTooltip.IsShown(self) return self.shownNow end
function friendsTooltip.GetWidth(self) return self.width end

local tip = { shownNow = false, lines = {}, made = 0 }
function tip.SetOwner(self, owner, anchor) self.owner, self.anchor = owner, anchor end
function tip.ClearAllPoints() end
function tip.SetPoint(self, point, relativeTo, relativePoint) self.point = { point, relativeTo, relativePoint } end
function tip.SetMinimumWidth(self, width) self.minWidth = width end
function tip.Show(self) self.shownNow = true end
function tip.Hide(self) self.shownNow = false end
function tip.IsShown(self) return self.shownNow end
function tip.SetScript(self, script, fn) self[script] = fn end
local fontLine = { SetFontObject = function(self, font) self.font = font end }
local fontRight = { SetFontObject = function(self, font) self.font = font end }

local friends = {
    [1] = { guid = "Player-1-F1", level = 25, connected = true },
    [2] = { guid = "Player-1-F2", level = 30, connected = false },
}
local bnet = {
    [1] = { gameAccountInfo = { wowProjectID = 1, playerGuid = "Player-1-B1", characterLevel = 40, isOnline = true } },
    [2] = { gameAccountInfo = { wowProjectID = 9, playerGuid = "Player-1-B2", characterLevel = 60, isOnline = true } },
}

local gamepad = false
local ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, Shared = {},
    GamepadStandDown = function() return gamepad end }
local env = setmetatable({
    _G = { NaowhForever = ns, NaowhForeverFriendTooltipTextLeft1 = fontLine,
        NaowhForeverFriendTooltipTextRight1 = fontRight },
    GameTooltip = tooltip,
    GameTooltipText = "GameTooltipText",
    FriendsTooltip = friendsTooltip,
    UIParent = {},
    FRIENDS_BUTTON_TYPE_BNET = 1, FRIENDS_BUTTON_TYPE_WOW = 2, WOW_PROJECT_ID = 1,
    Enum = { ClubMemberPresence = { Online = 1, Offline = 3 } },
    C_FriendList = { GetFriendInfoByIndex = function(id) return friends[id] end },
    C_BattleNet = { GetFriendAccountInfo = function(id) return bnet[id] end },
    CreateFrame = function(kind, name, _, template)
        tip.made, tip.kind, tip.name, tip.template = tip.made + 1, kind, name, template
        return tip
    end,
    hooksecurefunc = function(name, fn) state.hooked = state.hooked or {}; state.hooked[name] = fn end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    issecretvalue = function(v) return rawequal(v, SECRET) end,
    ScrollBoxListMixin = { Event = { OnInitializedFrame = "OnInitializedFrame" } },
    EventUtil = { ContinueOnAddOnLoaded = function(name, fn) state.onLoaded[name] = fn end },
}, { __index = _G })
local chunk = assert(loadfile("Shared/Game/Roster.lua"))
setfenv(chunk, env)
chunk()
local Roster = ns.Shared.Roster

check("nothing hooked at load", state.callback == nil and next(state.onLoaded) == nil)
gamepad = true
Roster.AddTooltip(function() end)
check("the Gamepad interface style: the friends and guild lists are left alone", next(state.onLoaded) == nil
    and state.hooked == nil)
gamepad = false
Roster.AddTooltip(function(_, guid, info, row)
    state.calls[#state.calls + 1] = "badge:" .. guid .. ":" .. info.level
    return false
end)
check("before the window opens, it waits for the list's code", state.onLoaded.Blizzard_Communities ~= nil)
env.CommunitiesFrame = { MemberList = { ScrollBox = scroll } }
state.onLoaded.Blizzard_Communities()
check("the rows already there are hooked", scroll.rows[1].hooks == 1 and scroll.rows[2].hooks == 1)
check("and the list's new rows will be", state.event == "OnInitializedFrame" and state.callback ~= nil)
Roster.AddTooltip(function(_, guid)
    state.calls[#state.calls + 1] = "score:" .. guid
    return guid == "Player-1-A"
end)
check("a second module adds no second hook", scroll.rows[1].hooks == 1)
local new = Row("Player-1-C")
state.callback(state.owner, new)
state.callback(state.owner, new)
state.callback(state.owner, scroll.rows[1])
check("a row is hooked once however often it's reused", new.hooks == 1 and scroll.rows[1].hooks == 1)

local A = scroll.rows[1]
tooltip.owner = A
A.OnEnter(A)
check("lines in the order modules asked", state.calls[1] == "badge:Player-1-A:20" and state.calls[2] == "score:Player-1-A")
check("shown again when a line went in", state.shown == 1)
local B = scroll.rows[2]
tooltip.owner = B
B.OnEnter(B)
check("not shown again when none did", state.shown == 1 and #state.calls == 4)

for k in pairs(state.calls) do state.calls[k] = nil end
tooltip.owner = A
B.OnEnter(B)
check("the tooltip on another row: left alone", #state.calls == 0)
tooltip.owner, tooltip.shownNow = B, false
B.OnEnter(B)
check("no tooltip (an expanded list with nothing cut short): left alone", #state.calls == 0)
tooltip.shownNow = true
local secret = Row(SECRET)
state.callback(state.owner, secret)
tooltip.owner = secret
secret.OnEnter(secret)
local empty = Row(nil)
state.callback(state.owner, empty)
tooltip.owner = empty
empty.OnEnter(empty)
check("a secret GUID or no member: left alone", #state.calls == 0)

local function FriendRow(kind, id)
    local row = Row(nil)
    row.buttonType, row.id = kind, id
    return row
end
local function Hover(row)
    friendsTooltip.shownNow, friendsTooltip.button = true, row
    for k in pairs(state.calls) do state.calls[k] = nil end
    if row.OnEnter then row.OnEnter(row) end
end

check("the Friends list waits for its code too", state.onLoaded.Blizzard_FriendsFrame ~= nil and state.hooked == nil)
env.FriendsFrame_UpdateFriendButton = function() end
state.onLoaded.Blizzard_FriendsFrame()
local Updated = state.hooked and state.hooked.FriendsFrame_UpdateFriendButton
check("then hooks the game's row update, after it", Updated ~= nil)
local wowOnline, wowOffline = FriendRow(2, 1), FriendRow(2, 2)
local bnetWow, bnetOther = FriendRow(1, 1), FriendRow(1, 2)
for _, row in ipairs({ wowOnline, wowOffline, bnetWow, bnetOther }) do Updated(row) end
Updated(wowOnline)
check("each friend row hooked once", wowOnline.hooks == 1 and bnetOther.hooks == 1 and tip.made == 0)

local seen = {}
Roster.AddTooltip(function(_, guid, info, _, anchor)
    seen.guid, seen.presence, seen.level, seen.anchor = guid, info.presence, info.level, anchor
    return guid == "Player-1-F1"
end)
local probe = FriendRow(2, 1)
Updated(probe)
Hover(probe)
check("a friend's GUID, level and presence, the game's tooltip as the anchor", seen.guid == "Player-1-F1"
    and seen.level == 25 and seen.presence == 1 and seen.anchor == friendsTooltip)
check("our tooltip: one, made when first needed, named, its first line in the body font", tip.made == 1
    and tip.kind == "GameTooltip" and tip.name == "NaowhForeverFriendTooltip" and tip.template == "GameTooltipTemplate"
    and fontLine.font == "GameTooltipText" and fontRight.font == "GameTooltipText")
check("lines on it: shown under the game's, as wide", tip:IsShown() and tip.owner == friendsTooltip
    and tip.point[2] == friendsTooltip and tip.point[1] == "TOPLEFT" and tip.point[3] == "BOTTOMLEFT"
    and tip.minWidth == 180)
check("the friend's row is the one showing", Roster.Showing(probe) and not Roster.Showing(wowOffline))

Hover(wowOffline)
check("an offline friend: Offline", seen.guid == "Player-1-F2" and seen.presence == 3)
check("nothing added for them: our tooltip hidden", not tip:IsShown())
Hover(bnetWow)
check("a Battle.net friend in this game: their character", seen.guid == "Player-1-B1" and seen.level == 40)
seen.guid = nil
Hover(bnetOther)
check("a Battle.net friend in another game: left alone", seen.guid == nil and not tip:IsShown())

Hover(probe)
check("shown again on hover", tip:IsShown())
friendsTooltip.shownNow = false
tip.OnUpdate(tip)
check("gone when the game's tooltip goes", not tip:IsShown() and not Roster.Showing(probe))
friendsTooltip.shownNow, friendsTooltip.button = true, probe
tip:Show()
friendsTooltip.button = wowOffline
tip.OnUpdate(tip)
check("and when it moves to another friend", not tip:IsShown())
friendsTooltip.button = probe
friends[1].guid = "Player-1-F9"
seen.guid = nil
Updated(probe)
check("the list refreshing under the mouse: drawn again for whoever the row is now", seen.guid == "Player-1-F9")
Updated(wowOffline)
check("other rows refreshing: left alone", seen.guid == "Player-1-F9")
friends[1].guid = SECRET
seen.guid = nil
Hover(probe)
check("a secret GUID: left alone", seen.guid == nil and not tip:IsShown())

print(("test-roster: %d checks passed"):format(checks))

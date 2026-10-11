-- Tooltips.lua: the Top Bar's tooltips at Tooltip Size: friends, guild, Hearthstone, the clock, the FPS / MS readout and any broker's (ns.TopBar.Tooltips).
local ns = _G.NaowhForever

local TB = ns.TopBar
local S = TB.Settings
local C = TB.C
local St = TB.Style
local Info = TB.Info
local Look = TB.Look

local Tone, Accent = Look.Tone, Look.Accent
local HEARTHSTONE, PERCENT = C.HEARTHSTONE, C.PERCENT
local WHITE, LABEL_GREY, EMPTY_GREY, MORE_GREY = St.WHITE, St.LABEL_GREY, St.EMPTY_GREY, St.MORE_GREY
local GOOD, GUILD_COUNT, GUILD_NAME, BNET = St.FRIENDS_RGB, St.GUILD_COUNT_RGB, St.GUILD_NAME_RGB, St.BNET_RGB
local READY, COOLDOWN, NO_CLASS = St.READY_RGB, St.COOLDOWN_RGB, St.NO_CLASS_RGB
local ROSTER_CAP = 40
local ROSTER_EVERY, MEM_SCAN_EVERY, MEM_SHOWN, KB_PER_MB = 10, 30, 10, 1024
local AFK, DND = 1, 2
local ROUND = C.ROUND
local ADDON_TITLE = 2

local TEXT_FRIENDS, TEXT_GUILD, TEXT_HEARTH = ns.L("Friends"), ns.L("Guild"), "Hearthstone"
local TEXT_ONLINE, TEXT_NO_FRIENDS, TEXT_NO_GUILD = ns.L("Online"), ns.L("No friends online"), ns.L("Not in a guild")
local TEXT_OPEN_FRIENDS, TEXT_OPEN_GUILD = ns.L("Click to open Friends"), ns.L("Click to open Guild")
local TEXT_BIND, TEXT_COOLDOWN, TEXT_READY = ns.L("Bind"), ns.L("Cooldown"), ns.L("Ready")
local TEXT_MORE = ns.L("... and %d more")
local TEXT_AFK, TEXT_DND = ns.L("<AFK>"), ns.L("<DND>")
local TEXT_FPS, TEXT_FPS_VALUE = ns.L("FPS"), ns.L("%d fps")
local TEXT_HOME, TEXT_WORLD, TEXT_MS = ns.L("Home Latency"), ns.L("World Latency"), ns.L("%d ms")
local TEXT_MEMORY, TEXT_MB, TEXT_KB = ns.L("Addon Memory"), ns.L("%.2f MB"), ns.L("%.0f KB")
local TEXT_SYSTEM_HINT = ns.L("Click: refresh    Shift-click: collect garbage")
local TEXT_DATE = "%A, %B %d"
local TEXT_SAVED = ns.L("Saved Instances")
local TEXT_RESETS = ns.L("resets in ")
local TEXT_UNKNOWN = "?"
local NAME_GAP, AREA_GAP = "  ", " - "

local tipBase, tipHooked
local lastTipRoster, lastMemScan = 0, 0
local memList = {}

local function TipHidden(self)
    if not tipBase then return end
    self:SetScale(tipBase)
    tipBase = nil
end

local function OwnTooltip(owner)
    if not tipHooked then
        tipHooked = true
        GameTooltip:HookScript("OnHide", TipHidden)
    end
    GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
    tipBase = tipBase or GameTooltip:GetScale()
    GameTooltip:SetScale(tipBase * S.Get("tooltipScale") / PERCENT)
end

local function More(shown)
    if shown > ROSTER_CAP then GameTooltip:AddLine(TEXT_MORE:format(shown - ROSTER_CAP), Tone("muted", MORE_GREY)) end
end

local function BattleNetRight(ga)
    local right = ga.characterName or ""
    if ga.areaName and ga.areaName ~= "" then
        right = (right ~= "" and right .. AREA_GAP or "") .. ga.areaName
    end
    return right
end

local function AddFriendsRoster()
    local shown = 0
    local lr, lg, lb = Tone("muted", LABEL_GREY)
    local function Row(left, right, r, g, b)
        shown = shown + 1
        if shown <= ROSTER_CAP then GameTooltip:AddDoubleLine(left, right or "", r, g, b, lr, lg, lb) end
    end
    for i = 1, (BNGetNumFriends() or 0) do
        local acc = C_BattleNet.GetFriendAccountInfo(i)
        local ga = acc and acc.gameAccountInfo
        if ga and ga.isOnline and ga.clientProgram == BNET_CLIENT_WOW then
            Row(acc.accountName or TEXT_UNKNOWN, BattleNetRight(ga), BNET.r, BNET.g, BNET.b)
        end
    end
    for i = 1, C_FriendList.GetNumFriends() do
        local fi = C_FriendList.GetFriendInfoByIndex(i)
        if fi and fi.connected then
            Row(fi.name .. (fi.level and fi.level > 0 and NAME_GAP .. fi.level or ""), fi.area, Tone("fg", WHITE))
        end
    end
    More(shown)
    return shown
end

local function Away(status, grey)
    if status == AFK then return NAME_GAP .. grey .. TEXT_AFK .. "|r" end
    if status == DND then return NAME_GAP .. grey .. TEXT_DND .. "|r" end
    return ""
end

local function AddGuildRoster()
    if GetTime() - lastTipRoster >= ROSTER_EVERY then
        lastTipRoster = GetTime()
        C_GuildInfo.GuildRoster()
    end
    local gname = GetGuildInfo("player")
    if gname then GameTooltip:AddLine(gname, GUILD_NAME.r, GUILD_NAME.g, GUILD_NAME.b) end
    local shown = 0
    local lr, lg, lb = Tone("muted", LABEL_GREY)
    local grey = ns.ThemeTint("muted", nil) and ns.Color("muted") or St.AWAY_GREY
    for i = 1, GetNumGuildMembers() do
        local name, _, _, level, _, zone, _, _, online, status, class = GetGuildRosterInfo(i)
        if online then
            shown = shown + 1
            if shown <= ROSTER_CAP then
                local cc = RAID_CLASS_COLORS[class] or NO_CLASS
                GameTooltip:AddDoubleLine(level .. NAME_GAP .. (name:match("[^%-]+") or name) .. Away(status, grey),
                    zone or "", cc.r, cc.g, cc.b, lr, lg, lb)
            end
        end
    end
    More(shown)
end

local function FriendsTip()
    local mr, mg, mb = Tone("muted", LABEL_GREY)
    GameTooltip:AddLine(TEXT_FRIENDS, Tone("fg", WHITE))
    GameTooltip:AddDoubleLine(TEXT_ONLINE, tostring(Info.FriendsOnline()), mr, mg, mb, GOOD.r, GOOD.g, GOOD.b)
    if not InCombatLockdown() then
        GameTooltip:AddLine(" ")
        local ok, count = pcall(AddFriendsRoster)
        if ok and count == 0 then GameTooltip:AddLine(TEXT_NO_FRIENDS, Tone("muted", EMPTY_GREY)) end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(TEXT_OPEN_FRIENDS, Accent())
end

local function GuildTip()
    local mr, mg, mb = Tone("muted", LABEL_GREY)
    GameTooltip:AddLine(TEXT_GUILD, Tone("fg", WHITE))
    local n = Info.GuildOnline()
    if n then
        GameTooltip:AddDoubleLine(TEXT_ONLINE, tostring(n), mr, mg, mb, GUILD_COUNT.r, GUILD_COUNT.g, GUILD_COUNT.b)
        if not InCombatLockdown() then
            GameTooltip:AddLine(" ")
            pcall(AddGuildRoster)
        end
    else
        GameTooltip:AddLine(TEXT_NO_GUILD, mr, mg, mb)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(TEXT_OPEN_GUILD, Accent())
end

local function HearthTip()
    local mr, mg, mb = Tone("muted", LABEL_GREY)
    GameTooltip:AddLine(C_Item.GetItemNameByID(HEARTHSTONE) or TEXT_HEARTH, Tone("fg", WHITE))
    GameTooltip:AddDoubleLine(TEXT_BIND, GetBindLocation() or "", mr, mg, mb, Tone("fg", WHITE))
    local cd = Info.HearthCooldown()
    if cd then
        GameTooltip:AddDoubleLine(TEXT_COOLDOWN, Info.FmtCD(cd), mr, mg, mb, COOLDOWN.r, COOLDOWN.g, COOLDOWN.b)
    else
        GameTooltip:AddDoubleLine(TEXT_COOLDOWN, TEXT_READY, mr, mg, mb, READY.r, READY.g, READY.b)
    end
end

local TOOLTIP = { friends = FriendsTip, guild = GuildTip, hearth = HearthTip }

local function ByMem(a, b) return a.mem > b.mem end

local function ScanMemory()
    if GetTime() - lastMemScan < MEM_SCAN_EVERY then return end
    lastMemScan = GetTime()
    UpdateAddOnMemoryUsage()
    local n = 0
    for i = 1, C_AddOns.GetNumAddOns() do
        local mem = GetAddOnMemoryUsage(i)
        if mem > 0 then
            n = n + 1
            memList[n] = memList[n] or {}
            memList[n].name, memList[n].mem = select(ADDON_TITLE, C_AddOns.GetAddOnInfo(i)), mem
        end
    end
    for i = n + 1, #memList do memList[i] = nil end
    table.sort(memList, ByMem)
end

local function AddMemory()
    if #memList == 0 then return end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(TEXT_MEMORY, Accent())
    local fr, fg, fb = Tone("fg", WHITE)
    for i = 1, math.min(MEM_SHOWN, #memList) do
        local e = memList[i]
        GameTooltip:AddDoubleLine(e.name, e.mem > KB_PER_MB and TEXT_MB:format(e.mem / KB_PER_MB)
            or TEXT_KB:format(e.mem), fr, fg, fb, Accent())
    end
end

local Tooltips = {}
TB.Tooltips = Tooltips

function Tooltips.Button(b)
    OwnTooltip(b)
    TOOLTIP[b.key]()
    GameTooltip:Show()
end

function Tooltips.System(owner)
    OwnTooltip(owner)
    local fps = math.floor(GetFramerate() + ROUND)
    local _, _, home, world = GetNetStats()
    local mr, mg, mb = Tone("muted", LABEL_GREY)
    GameTooltip:AddDoubleLine(TEXT_FPS, TEXT_FPS_VALUE:format(fps), mr, mg, mb, Look.FpsRGB(fps))
    GameTooltip:AddDoubleLine(TEXT_HOME, TEXT_MS:format(math.floor(home)), mr, mg, mb, Look.MsRGB(home))
    GameTooltip:AddDoubleLine(TEXT_WORLD, TEXT_MS:format(math.floor(world)), mr, mg, mb, Look.MsRGB(world))
    ScanMemory()
    AddMemory()
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(TEXT_SYSTEM_HINT, Accent())
    GameTooltip:Show()
end

function Tooltips.Rescan()
    lastMemScan = 0
end

function Tooltips.Clock(owner)
    OwnTooltip(owner)
    GameTooltip:SetText(date(TEXT_DATE), Tone("fg", WHITE))
    local list = Info.Lockouts()
    if #list > 0 then
        local mr, mg, mb = Tone("muted", LABEL_GREY)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(TEXT_SAVED, Tone("fg", WHITE))
        for _, l in ipairs(list) do
            GameTooltip:AddDoubleLine(l.name, TEXT_RESETS .. l.reset, mr, mg, mb, Tone("fg", WHITE))
        end
    end
    GameTooltip:Show()
end

function Tooltips.Broker(owner, name)
    local obj = TB.LDB():GetDataObjectByName(name)
    if not obj then return end
    if obj.OnEnter then
        obj.OnEnter(owner)
    elseif obj.OnTooltipShow then
        GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
        obj.OnTooltipShow(GameTooltip)
        GameTooltip:Show()
    end
end

function Tooltips.LeaveBroker(owner, name)
    local obj = TB.LDB():GetDataObjectByName(name)
    if obj and obj.OnLeave then obj.OnLeave(owner) end
end

-- Badges.lua: the team's and patrons' badges in chat, on a card, on tooltips and in a banner.
local ns = _G.NaowhForever
local T = ns.THEME
local S = ns.QoLSettings
local Confirm = ns.BadgeConfirm
local PATRONS = ns.FEATURE_BADGES == ns.BADGES_LIVE
local RENUMBERED = { [110] = 90 }

local MEDIA = "Interface\\AddOns\\NaowhForever\\Core\\Badges\\Media\\"
local CACHE_SIZE = 200
local TOAST_HOLD = 4
local STEP_IN, STEP_HOLD, STEP_OUT = 1, 2, 3
local BYTE = 255
local PARTY_OTHERS, RAID_SIZE = 4, 40
local CHROME = { bgAlpha = 0.97, barInset = 1, barH = 2, glowGrow = 1.3, edgeAlpha = 0.9 }
local SHINE = { bands = 2, w = 12, h = 90, alpha = 0.45, travel = 110, duration = 0.9, delay = 0.3, rest = 2.4,
    sublevel = 2 }
local CARD = { name = "NaowhForeverBadgeCard", w = 360, icon = 80, glowX = 2, pulseFrom = 0.2, pulseTo = 0.75,
    pulseTime = 1.1, shrink = 0.94, grow = 1.06, brandSize = 10, titleSize = 19, playerSize = 13, aboutSize = 11,
    sinceSize = 10, titleGap = 4, aboutGap = 6, aboutW = 238, siteSize = 10, siteX = 10, siteY = 8, sinceAlpha = 0.85,
    h = 112, sinceH = 136, cursorX = 16, cursorY = 12, textLeft = 110, textTop = 16 }
local PLATE = { h = 26, icon = 18, gap = 2, pad = 6, glowNudge = 2, titleSize = 12 }
local TOAST = { name = "NaowhForeverBadgeToast", w = 360, h = 66, y = 150, icon = 50, glowX = 2, brandSize = 9,
    brandX = 74, brandY = 12, textSize = 14, titleSize = 12, lineGap = 3, fadeIn = 0.3, growFrom = 0.92, fadeOut = 0.6 }
local LIST = { badge = 14, gap = 3 }
local CODE = { w = 440, h = 150, headSize = 14, headY = 14, hintSize = 11, hintGap = 6, textW = 400, boxGap = 12,
    boxH = 28, buttonW = 96, buttonH = 26, buttonShift = 52, pad = 14 }
local PREVIEW_TITLE = "Lead Developer"
local TEXT_BRAND = "NAOWH FOREVER"
local TEXT_SITE = "naowh.gg"
local TEXT_NAMED = "Naowh Forever "
local TEXT_SINCE = ns.L("Supporter since %s %s")
local TEXT_JOINED = ns.L("%s joined your %s")
local TEXT_A_SUPPORTER, TEXT_A_TEAM_MEMBER = ns.L("A supporter"), ns.L("A team member")
local TEXT_RAID, TEXT_PARTY = ns.L("raid"), ns.L("party")
local TEXT_CODE_TITLE = ns.L("Your character code")
local TEXT_CHARACTER, TEXT_CHARACTERS = ns.L(" character"), ns.L(" characters")
local TEXT_CODE_SUPPORT = ns.L(". Ctrl+C to copy it, then paste it on naowh.gg/forever/account.")
local TEXT_CODE_TEAM = ns.L(". Ctrl+C to copy it, then send it to the team on Discord to be added.")
local TEXT_DISCORD, TEXT_CLOSE, TEXT_DISCORD_TITLE = ns.L("Discord"), ns.L("Close"), ns.L("Naowh's Discord")
local TEXT_STAFF_ONLY = ns.L("Badge previews are for the Naowh Forever team.")
local TEXT_PREVIEW_NONE = ns.L("Preview on: you wear no badge until you reload, as a player without one sees it.")
local TEXT_PREVIEW_ON = ns.L("Preview on: your name wears the %s badge until you reload. Say something to see it.")
local TEXT_PREVIEW_OFF = ns.L("Preview off.")
local TEXT_USAGE = "/nf badges id || status || claim CODE || preview [%smoderator||developer||ellesmere||naowh||none] || preview off || toast"
local TEXT_USAGE_PATRON = "legendary||epic||basic||"
local TEXT_SUMMARY = ns.L("%d of %d on")
local TEXT_STATUS_NONE = ns.L("No badge on this character")
local TEXT_STATUS_CONFIRMED = ns.L("%s, your claim matches naowh.gg")
local TEXT_STATUS_CHECKING = ns.L("%s, checking your claim")
local TEXT_STATUS_UNCLAIMED = ns.L("%s, not claimed on this character yet")
local TEXT_STATUS_OFF = ns.L("%s, off: the claim or BattleTag does not match naowh.gg")
local TEXT_CLAIM_BAD = ns.L("That is not a claim code: it looks like K7P2-9XQM, from your naowh.gg account.")
local TEXT_CLAIM_DONE = ns.L("Your Naowh Forever badge is claimed on this character.")
local TEXT_CLAIM_WRONG = ns.L("That claim is not this character's, or the BattleTag saved on naowh.gg is not yours.")
local TEXT_CLAIM_SAVED = ns.L("Claim saved: your badge shows once this character is on the badge list, "
    .. "with the next Naowh Forever update.")
local CLAIM_COMMAND = "^[Cc][Ll][Aa][Ii][Mm]%s+(%S+)$"
local TEXT_CLAIM_PROMPT = ns.L("Paste your claim code from naowh.gg")
local CLAIM_LETTERS = 9
local PATREON_LINK = { "Patreon", "patreon", function() return "https://www.patreon.com/naowh" end }
local MONTHS = { ns.L("January"), ns.L("February"), ns.L("March"), ns.L("April"), ns.L("May"), ns.L("June"),
    ns.L("July"), ns.L("August"), ns.L("September"), ns.L("October"), ns.L("November"), ns.L("December") }

local function Setting(key)
    if PATRONS then return S.Get(key) end
    return S.Default(key)
end

local TIERS = {
    naowh = {
        title = "Founder",
        about = ns.L("The Man. The King."),
        label = "Naowh, the Founder",
        color = { r = 0xe6 / 255, g = 0xcc / 255, b = 0x80 / 255 },
        chat = MEDIA .. "BadgeNaowhChat.tga",
        large = MEDIA .. "BadgeNaowhLarge.tga",
        sound = "UI_72_ARTIFACT_FORGE_FINAL_TRAIT_UNLOCKED",
    },
    developer = {
        title = "Developer",
        about = ns.L("Builds Naowh Forever."),
        color = { r = 0x00 / 255, g = 0x91 / 255, b = 0xed / 255 },
        chat = MEDIA .. "BadgeDeveloperChat.tga",
        large = MEDIA .. "BadgeDeveloperLarge.tga",
        sound = "UI_72_ARTIFACT_FORGE_ACTIVATE_FINAL_TIER",
    },
    moderator = {
        title = "Moderator",
        about = ns.L("Keeps the community running."),
        color = { r = 0xe0 / 255, g = 0x38 / 255, b = 0x3e / 255 },
        chat = MEDIA .. "BadgeModeratorChat.tga",
        large = MEDIA .. "BadgeModeratorLarge.tga",
        sound = "UI_PVP_HONOR_PRESTIGE_RANK_UP",
    },
    ellesmere = {
        title = "EllesmereUI Creator",
        about = ns.L("Makes EllesmereUI."),
        label = "Ellesmere, creator of EllesmereUI",
        color = { r = 0x0e / 255, g = 0xd2 / 255, b = 0x9b / 255 },
        chat = MEDIA .. "BadgeEllesmereChat.tga",
        large = MEDIA .. "BadgeEllesmereLarge.tga",
        sound = "UI_72_ARTIFACT_FORGE_ACTIVATE_FINAL_TIER",
    },
    legendary = {
        title = "Legendary Patron",
        about = ns.L("Supports Naowh at the Legendary tier on Patreon."),
        color = { r = 0xff / 255, g = 0x80 / 255, b = 0x00 / 255 },
        chat = MEDIA .. "BadgeLegendaryChat.tga",
        large = MEDIA .. "BadgeLegendaryLarge.tga",
        sound = "UI_LEGENDARY_LOOT_TOAST",
        showsSince = true,
    },
    epic = {
        title = "Epic Patron",
        about = ns.L("Supports Naowh at the Epic tier on Patreon."),
        color = { r = 0xa3 / 255, g = 0x35 / 255, b = 0xee / 255 },
        chat = MEDIA .. "BadgeEpicChat.tga",
        large = MEDIA .. "BadgeEpicLarge.tga",
        sound = "UI_EPICLOOT_TOAST",
        showsSince = true,
    },
    basic = {
        title = "Basic Patron",
        about = ns.L("Supports Naowh at the Basic tier on Patreon."),
        color = { r = 0x00 / 255, g = 0x70 / 255, b = 0xdd / 255 },
        chat = MEDIA .. "BadgeBasicChat.tga",
        large = MEDIA .. "BadgeBasicLarge.tga",
        sound = "UI_RAID_LOOT_TOAST_LESSER_ITEM_WON",
        showsSince = true,
    },
}
local PATRON_TIER, DEFAULT_PATRON_TIER = { legendary = true, epic = true, basic = true }, "legendary"
if not PATRONS then TIERS.legendary, TIERS.epic, TIERS.basic = nil, nil, nil end
if PATRONS then ns.LINKS[#ns.LINKS + 1] = PATREON_LINK end
local BADGE_DROP = 1

for _, tier in pairs(TIERS) do
    local c = tier.color
    tier.hex = string.format("ff%02x%02x%02x", c.r * BYTE, c.g * BYTE, c.b * BYTE)
    tier.markup = ("|T%s:0:0:0:%d|t"):format(tier.chat, -BADGE_DROP)
    tier.tooltipLine = "|T" .. tier.chat .. ":16:16|t |c" .. tier.hex
        .. (tier.label or (TEXT_NAMED .. ns.L(tier.title))) .. "|r"
end

local issecretvalue = issecretvalue
local function Secret(value) return issecretvalue and issecretvalue(value) end

local previewGUID, previewEntry

local roster = {}
local patronCount = 0

local function AddRegion(lists, region, patrons)
    local list = region and lists and lists[region]
    if not list then return end
    for guid, entry in pairs(list) do
        if patrons then
            if not PATRON_TIER[entry.tier] then entry.tier = DEFAULT_PATRON_TIER end
            entry.patron = true
            patronCount = patronCount + 1
        end
        roster[guid] = entry
    end
end

local function BuildRoster()
    wipe(roster)
    patronCount = 0
    local region = GetCurrentRegion and GetCurrentRegion()
    local before = region and RENUMBERED[region]
    if PATRONS then
        AddRegion(ns.BADGE_PATRONS, before, true)
        AddRegion(ns.BADGE_PATRONS, region, true)
    end
    AddRegion(ns.BADGE_STAFF, before)
    AddRegion(ns.BADGE_STAFF, region)
end
BuildRoster()

local function EntryOf(guid, who, unit)
    if not guid or Secret(guid) then return nil end
    if guid == previewGUID then return previewEntry end
    local entry = roster[guid]
    if entry and entry.patron and not Confirm.Shows(guid, who, unit) then return nil end
    return entry
end

local function IsStaff(guid)
    for _, list in pairs(ns.BADGE_STAFF or {}) do
        if list[guid] then return true end
    end
    return false
end

local function TierOf(entry)
    if type(entry) == "table" then return TIERS[entry.tier] end
    return entry and TIERS[entry]
end

local function TitleOf(entry, tier)
    return ns.L(type(entry) == "table" and entry.title or tier.title)
end

local function SinceOf(entry)
    local tier = TierOf(entry)
    local since = tier and tier.showsSince and entry.since
    if type(since) ~= "string" then return nil end
    local year, month = since:match("^(%d%d%d%d)%-(%d%d)$")
    month = year and MONTHS[tonumber(month)]
    if not month then return nil end
    return TEXT_SINCE:format(month, year)
end

local guidByLine, lineAt, nextSlot = {}, {}, 1

local function Remember(lineID, guid)
    local old = lineAt[nextSlot]
    if old then guidByLine[old] = nil end
    lineAt[nextSlot], guidByLine[lineID] = lineID, guid
    nextSlot = nextSlot % CACHE_SIZE + 1
end

local function DecorateName(_, name, _, sender, _, _, _, _, _, _, _, _, lineID, guid)
    local tier = TierOf(EntryOf(guid, sender))
    if not tier then return name end
    if lineID and not Secret(lineID) then Remember(lineID, guid) end
    return name .. " " .. tier.markup
end

local function Chrome(frame, iconSize)
    local bg = ns.Solid(frame, "BACKGROUND", T.bg, CHROME.bgAlpha)
    bg:SetAllPoints()
    frame.border = ns.Border(frame)

    frame.bar = frame:CreateTexture(nil, "ARTWORK")
    frame.bar:SetPoint("TOPLEFT", CHROME.barInset, -CHROME.barInset)
    frame.bar:SetPoint("TOPRIGHT", -CHROME.barInset, -CHROME.barInset)
    frame.bar:SetHeight(CHROME.barH)
    frame.bar:SetColorTexture(1, 1, 1, 1)

    frame.glow = frame:CreateTexture(nil, "ARTWORK")
    frame.glow:SetSize(iconSize * CHROME.glowGrow, iconSize * CHROME.glowGrow)
    frame.glow:SetBlendMode("ADD")

    frame.icon = frame:CreateTexture(nil, "OVERLAY")
    frame.icon:SetSize(iconSize, iconSize)
    frame.icon:SetPoint("CENTER", frame.glow)
end

local function Paint(frame, tier)
    local c = tier.color
    frame.border:SetColor(c.r, c.g, c.b, CHROME.edgeAlpha)
    frame.bar:SetGradient("HORIZONTAL", CreateColor(c.r, c.g, c.b, 1), CreateColor(c.r, c.g, c.b, 0))
    frame.glow:SetTexture(tier.large)
    frame.icon:SetTexture(tier.large)
end

local card

local function AddShine(frame)
    frame.mask = frame:CreateMaskTexture()
    frame.mask:SetAllPoints(frame.icon)
    frame.shines = {}
    for i = 1, SHINE.bands do
        local band = frame:CreateTexture(nil, "OVERLAY", nil, SHINE.sublevel)
        band:SetSize(SHINE.w, SHINE.h)
        band:SetColorTexture(1, 1, 1, 1)
        band:SetBlendMode("ADD")
        band:AddMaskTexture(frame.mask)
        if i == 1 then
            band:SetPoint("RIGHT", frame.icon, "LEFT", 0, 0)
            band:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, SHINE.alpha))
        else
            band:SetPoint("LEFT", frame.shines[1], "RIGHT", 0, 0)
            band:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, SHINE.alpha), CreateColor(1, 1, 1, 0))
        end
        local sweep = band:CreateAnimationGroup()
        sweep:SetLooping("REPEAT")
        local move = sweep:CreateAnimation("Translation")
        move:SetOffset(SHINE.travel, 0)
        move:SetDuration(SHINE.duration)
        move:SetStartDelay(SHINE.delay)
        move:SetEndDelay(SHINE.rest)
        move:SetSmoothing("IN_OUT")
        band.sweep = sweep
        frame.shines[i] = band
    end
end

local function Pulse(glow)
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(CARD.pulseFrom)
    fade:SetToAlpha(CARD.pulseTo)
    fade:SetDuration(CARD.pulseTime)
    fade:SetSmoothing("IN_OUT")
    local grow = pulse:CreateAnimation("Scale")
    grow:SetScaleFrom(CARD.shrink, CARD.shrink)
    grow:SetScaleTo(CARD.grow, CARD.grow)
    grow:SetDuration(CARD.pulseTime)
    grow:SetSmoothing("IN_OUT")
    return pulse
end

local function OnCardShow(self)
    self.pulse:Play()
    for i = 1, #self.shines do self.shines[i].sweep:Play() end
end

local function OnCardHide(self)
    self.pulse:Stop()
    for i = 1, #self.shines do self.shines[i].sweep:Stop() end
end

local function CardLine(frame, size, color, above, aboveSize, gap)
    local line = ns.Font(frame, size, nil, color)
    if above then
        line:SetPoint("TOPLEFT", above, "BOTTOMLEFT", ns.FontInset(aboveSize) - ns.FontInset(size), -gap)
    else
        line:SetPoint("TOPLEFT", CARD.textLeft - ns.FontInset(size), -CARD.textTop)
    end
    return line
end

local function CardLines(frame)
    frame.brand = CardLine(frame, CARD.brandSize, T.muted)
    frame.brand:SetText(TEXT_BRAND)
    frame.title = CardLine(frame, CARD.titleSize, nil, frame.brand, CARD.brandSize, CARD.titleGap)
    frame.player = CardLine(frame, CARD.playerSize, nil, frame.title, CARD.titleSize, CARD.titleGap)
    frame.about = CardLine(frame, CARD.aboutSize, T.muted, frame.player, CARD.playerSize, CARD.aboutGap)
    frame.about:SetWidth(CARD.aboutW)
    frame.about:SetJustifyH("LEFT")
    frame.since = CardLine(frame, CARD.sinceSize, nil, frame.about, CARD.aboutSize, CARD.aboutGap)
    frame.site = ns.Font(frame, CARD.siteSize, nil, T.accentSoft)
    frame.site:SetPoint("BOTTOMRIGHT", -CARD.siteX, CARD.siteY)
    frame.site:SetText(TEXT_SITE)
end

local function BuildCard()
    card = CreateFrame("Frame", CARD.name, UIParent)
    card:SetFrameStrata("TOOLTIP")
    card:SetWidth(CARD.w)
    card:SetClampedToScreen(true)
    card:Hide()
    Chrome(card, CARD.icon)
    card.glow:SetPoint("LEFT", CARD.glowX, 0)
    AddShine(card)
    card.pulse = Pulse(card.glow)
    card:SetScript("OnShow", OnCardShow)
    card:SetScript("OnHide", OnCardHide)
    CardLines(card)
end

local function ShowEntryCard(entry, playerName)
    local tier = TierOf(entry)
    if not tier then return end
    if not card then BuildCard() end
    Paint(card, tier)
    card.mask:SetTexture(tier.large, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    local c = tier.color
    card.title:SetText(TitleOf(entry, tier))
    card.title:SetTextColor(c.r, c.g, c.b, 1)
    card.player:SetText(playerName or "")
    card.about:SetText(tier.about)
    local since = SinceOf(entry)
    card.since:SetText(since or "")
    card.since:SetTextColor(c.r, c.g, c.b, CARD.sinceAlpha)
    card:SetHeight(since and CARD.sinceH or CARD.h)

    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    card:ClearAllPoints()
    card:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + CARD.cursorX, y / scale + CARD.cursorY)
    card:Show()
end

local function ShowCard(guid, playerName)
    ShowEntryCard(EntryOf(guid), playerName)
end

local function OnLinkEnter(_, _, link)
    if not link or Secret(link) then return end
    local kind, name, lineID = strsplit(":", link)
    if kind ~= "player" then return end
    local guid = guidByLine[tonumber(lineID)]
    if guid then ShowCard(guid, Ambiguate and Ambiguate(name, "none") or name) end
end

local function OnLinkLeave()
    if card then card:Hide() end
end

local plate, plateRow

local function HidePlate()
    if plate then plate:Hide() end
end

local function PlateUpdate()
    if plateRow then
        if not ns.Shared.Roster.Showing(plateRow) then plate:Hide() end
        return
    end
    local data = GameTooltip:IsShown() and GameTooltip:GetPrimaryTooltipData()
    local guid = data and data.guid
    if not guid or Secret(guid) or guid ~= plate.guid then plate:Hide() end
end

local function FitTitle()
    local title = plate.title
    title:SetText(plate.full)
    if plate.short and title:GetStringWidth() > title:GetWidth() then title:SetText(plate.short) end
end

local function BuildPlate()
    plate = CreateFrame("Frame", nil, UIParent)
    plate:SetFrameStrata("TOOLTIP")
    plate:SetHeight(PLATE.h)
    plate:Hide()
    Chrome(plate, PLATE.icon)
    plate.glow:SetPoint("LEFT", PLATE.pad - PLATE.glowNudge, 0)
    plate.title = ns.Font(plate, PLATE.titleSize)
    plate.title:SetPoint("LEFT", plate.icon, "RIGHT", PLATE.pad, 0)
    plate.title:SetPoint("RIGHT", -PLATE.pad, 0)
    plate.title:SetJustifyH("LEFT")
    plate.title:SetWordWrap(false)
    plate:SetScript("OnSizeChanged", FitTitle)
    plate:SetScript("OnUpdate", PlateUpdate)
end

local function ShowPlate(tooltip, guid, entry, tier, row)
    if not plate then BuildPlate() end
    plate.guid, plateRow = guid, row
    Paint(plate, tier)
    local c = tier.color
    local title = TitleOf(entry, tier)
    plate.full = tier.label or (TEXT_NAMED .. title)
    plate.short = not tier.label and title or nil
    FitTitle()
    plate.title:SetTextColor(c.r, c.g, c.b, 1)
    plate:ClearAllPoints()
    plate:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", 0, PLATE.gap)
    plate:SetPoint("BOTTOMRIGHT", tooltip, "TOPRIGHT", 0, PLATE.gap)
    plate:Show()
end

local FullName

local function PatronListed(guid)
    local listed = guid and not Secret(guid) and roster[guid]
    return listed and listed.patron
end

local function TooltipUnit(tooltip)
    local unit = tooltip and tooltip.GetUnit and select(2, tooltip:GetUnit())
    if type(unit) ~= "string" or Secret(unit) then return nil end
    return unit
end

local function AddTooltipLine(tooltip, data)
    if not Setting("badgeTooltip") then return end
    local guid = data and data.guid
    local unit = PatronListed(guid) and TooltipUnit(tooltip)
    local entry = EntryOf(guid, unit and FullName(unit), unit or nil)
    local tier = TierOf(entry)
    if not tier then
        if tooltip == GameTooltip then HidePlate() end
        return
    end
    if tooltip == GameTooltip then
        ShowPlate(tooltip, data.guid, entry, tier)
    else
        tooltip:AddLine(tier.tooltipLine)
    end
end

local function AddRosterPlate(_, guid, _, row, anchor)
    if not Setting("badgeTooltip") then return end
    local entry = EntryOf(guid)
    local tier = TierOf(entry)
    if tier then ShowPlate(anchor, guid, entry, tier, row) end
end

local toast
local queueEntry, queueName, queueRaid, queueHead, queueTail = {}, {}, {}, 1, 0

local function ToastLife(frame)
    local life = frame:CreateAnimationGroup()
    life:SetToFinalAlpha(true)
    local inFade = life:CreateAnimation("Alpha")
    inFade:SetFromAlpha(0)
    inFade:SetToAlpha(1)
    inFade:SetDuration(TOAST.fadeIn)
    inFade:SetOrder(STEP_IN)
    local inGrow = life:CreateAnimation("Scale")
    inGrow:SetScaleFrom(TOAST.growFrom, TOAST.growFrom)
    inGrow:SetScaleTo(1, 1)
    inGrow:SetDuration(TOAST.fadeIn)
    inGrow:SetOrder(STEP_IN)
    local hold = life:CreateAnimation("Alpha")
    hold:SetFromAlpha(1)
    hold:SetToAlpha(1)
    hold:SetDuration(TOAST_HOLD)
    hold:SetOrder(STEP_HOLD)
    local outFade = life:CreateAnimation("Alpha")
    outFade:SetFromAlpha(1)
    outFade:SetToAlpha(0)
    outFade:SetDuration(TOAST.fadeOut)
    outFade:SetOrder(STEP_OUT)
    return life
end

local function BuildToast()
    toast = CreateFrame("Frame", TOAST.name, UIParent)
    toast:SetFrameStrata("HIGH")
    toast:SetSize(TOAST.w, TOAST.h)
    toast:SetPoint("TOP", UIParent, "TOP", 0, -TOAST.y)
    toast:Hide()
    Chrome(toast, TOAST.icon)
    toast.glow:SetPoint("LEFT", TOAST.glowX, 0)

    toast.brand = ns.Font(toast, TOAST.brandSize, nil, T.muted)
    toast.brand:SetPoint("TOPLEFT", TOAST.brandX, -TOAST.brandY)
    toast.brand:SetText(TEXT_BRAND)
    toast.text = ns.Font(toast, TOAST.textSize)
    toast.text:SetPoint("TOPLEFT", toast.brand, "BOTTOMLEFT", 0, -TOAST.lineGap)
    toast.title = ns.Font(toast, TOAST.titleSize)
    toast.title:SetPoint("TOPLEFT", toast.text, "BOTTOMLEFT", 0, -TOAST.lineGap)
    toast.life = ToastLife(toast)
end

local ShowNextToast

local function OnToastDone()
    toast:Hide()
    ShowNextToast()
end

function ShowNextToast()
    if queueHead > queueTail or (toast and toast:IsShown()) then return end
    local entry, name, raid = queueEntry[queueHead], queueName[queueHead], queueRaid[queueHead]
    queueEntry[queueHead], queueName[queueHead], queueRaid[queueHead] = nil, nil, nil
    queueHead = queueHead + 1
    local tier = TierOf(entry)
    if not tier then return ShowNextToast() end
    if not toast then
        BuildToast()
        toast.life:SetScript("OnFinished", OnToastDone)
    end
    Paint(toast, tier)
    local c = tier.color
    toast.text:SetText(TEXT_JOINED:format(name or (PATRONS and TEXT_A_SUPPORTER or TEXT_A_TEAM_MEMBER),
        raid and TEXT_RAID or TEXT_PARTY))
    toast.title:SetText(TitleOf(entry, tier))
    toast.title:SetTextColor(c.r, c.g, c.b, 1)
    toast:Show()
    toast.life:Play()
    local kit = SOUNDKIT and SOUNDKIT[tier.sound]
    if kit then PlaySound(kit) end
end

function FullName(unit)
    local first, surname = UnitFullName(unit)
    if not first or Secret(first) or Secret(surname) then return nil end
    if surname and surname ~= "" then return first .. " " .. surname end
    return first
end

local function QueueToast(entry, name, raid)
    queueTail = queueTail + 1
    queueEntry[queueTail], queueName[queueTail], queueRaid[queueTail] = entry, name, raid
    ShowNextToast()
end

local PARTY_UNITS, RAID_UNITS = {}, {}
for i = 1, PARTY_OTHERS do PARTY_UNITS[i] = "party" .. i end
for i = 1, RAID_SIZE do RAID_UNITS[i] = "raid" .. i end

local announced = {}
local waitName, waitRaid = {}, {}
local playerGUID, bannerOn
local SyncListen
local groupEvents = CreateFrame("Frame")

local function RememberCharacter()
    local region = GetCurrentRegion and GetCurrentRegion()
    local guid = UnitGUID("player")
    if not region or not guid or Secret(guid) then return end
    local account = ns.AccountSettings()
    account.badgeCharacters = account.badgeCharacters or {}
    local characters = account.badgeCharacters
    characters[region] = characters[region] or {}
    characters[region][guid] = FullName("player") or characters[region][guid] or true
end

local function InMyGuild(unit)
    local result = UnitIsInMyGuild and UnitIsInMyGuild(unit)
    return result == true and not Secret(result)
end

local deferQuiet

local function ScanGroup(quiet)
    if not IsInGroup() then
        wipe(announced)
        wipe(waitName)
        wipe(waitRaid)
        return
    end
    if InCombatLockdown() then
        deferQuiet = quiet and deferQuiet ~= false
        groupEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    local raid = IsInRaid()
    local units = raid and RAID_UNITS or PARTY_UNITS
    local count = math.min(GetNumGroupMembers() - (raid and 0 or 1), #units)
    for i = 1, count do
        local unit = units[i]
        local guid = UnitGUID(unit)
        if guid and not Secret(guid) and guid ~= playerGUID and not announced[guid] then
            local name = roster[guid] and FullName(unit)
            local entry = EntryOf(guid, name, unit)
            local wanted = not quiet and not (Setting("badgeBannerSkipGuild") and InMyGuild(unit))
            if TierOf(entry) then
                announced[guid] = true
                if wanted then QueueToast(entry, name, raid) end
            elseif wanted and roster[guid] and roster[guid].patron then
                waitName[guid], waitRaid[guid] = name or false, raid
            end
        end
    end
end

local function OnGroupEvent(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        playerGUID = UnitGUID("player")
        local mine = roster[playerGUID]
        Confirm.SetEntry(mine and mine.patron and mine or nil)
        if mine and mine.patron then Confirm.Mine() end
        SyncListen()
        RememberCharacter()
        if bannerOn then ScanGroup(true) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        local quiet = deferQuiet
        deferQuiet = nil
        ScanGroup(quiet)
    else
        ScanGroup(false)
    end
end

groupEvents:SetScript("OnEvent", OnGroupEvent)
groupEvents:RegisterEvent("PLAYER_ENTERING_WORLD")

local listBadges = setmetatable({}, { __mode = "k" })
local listOn, listWaiting

local function MemberScroll()
    local frame = CommunitiesFrame
    return frame and frame.MemberList and frame.MemberList.ScrollBox
end

local function PaintRow(row)
    local info = listOn and row.memberInfo
    local guid = info and info.guid
    local tier = guid and not Secret(guid) and TierOf(EntryOf(guid, info.name))
    local badge = listBadges[row]
    if not tier then
        if badge then badge:Hide() end
        return
    end
    local name = row.NameFrame and row.NameFrame.Name
    if not name then return end
    if not badge then
        badge = row.NameFrame:CreateTexture(nil, "OVERLAY")
        badge:SetSize(LIST.badge, LIST.badge)
        listBadges[row] = badge
    end
    badge:SetTexture(tier.chat)
    badge:ClearAllPoints()
    local width = math.min(name:GetStringWidth(), name:GetWidth())
    badge:SetPoint("LEFT", name, "LEFT", width + LIST.gap, -BADGE_DROP)
    badge:Show()
end

local function RowInitialized(_, row)
    PaintRow(row)
end

local function HookList()
    listWaiting = false
    local scroll = MemberScroll()
    if not (scroll and listOn) then return end
    scroll:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, RowInitialized, listBadges)
    scroll:ForEachFrame(PaintRow)
end

local function SyncList(on)
    if on == (listOn or false) then return end
    listOn = on
    local scroll = MemberScroll()
    if on then
        if scroll then
            HookList()
        elseif not listWaiting then
            listWaiting = true
            EventUtil.ContinueOnAddOnLoaded("Blizzard_Communities", HookList)
        end
    else
        if scroll then scroll:UnregisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, listBadges) end
        for _, badge in pairs(listBadges) do badge:Hide() end
    end
end

local function OnConfirmed(guid)
    if listOn then
        local scroll = MemberScroll()
        if scroll then scroll:ForEachFrame(PaintRow) end
    end
    local name = waitName[guid]
    if name ~= nil and bannerOn and not announced[guid] then
        announced[guid] = true
        QueueToast(roster[guid], name or nil, waitRaid[guid])
    end
    waitName[guid], waitRaid[guid] = nil, nil
end
Confirm.OnConfirmed(OnConfirmed)

local chatOn, cardOn, tooltipHooked

function SyncListen()
    local mine = playerGUID and roster[playerGUID]
    local shown = chatOn or Setting("badgeTooltip") or bannerOn
    Confirm.Listen(PATRONS and patronCount > 0 and (shown or (mine and mine.patron)) and true or false)
end

local function Apply()
    local chatAPI = (ChatFrameUtil and ChatFrameUtil.AddSenderNameFilter) ~= nil
    local chat = chatAPI and Setting("badgeChat") == true
    if chat ~= (chatOn or false) then
        chatOn = chat
        if chat then
            ChatFrameUtil.AddSenderNameFilter(DecorateName)
        else
            ChatFrameUtil.RemoveSenderNameFilter(DecorateName)
        end
    end
    SyncList(chat)

    local cardWanted = chat and Setting("badgeCard") == true
    if cardWanted ~= (cardOn or false) then
        cardOn = cardWanted
        if cardWanted then
            EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkEnter", OnLinkEnter, TIERS)
            EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkLeave", OnLinkLeave, TIERS)
        else
            EventRegistry:UnregisterCallback("ChatFrame.OnHyperlinkEnter", TIERS)
            EventRegistry:UnregisterCallback("ChatFrame.OnHyperlinkLeave", TIERS)
            OnLinkLeave()
        end
    end

    if Setting("badgeTooltip") and not tooltipHooked then
        tooltipHooked = true
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddTooltipLine)
        ns.Shared.Roster.AddTooltip(AddRosterPlate)
    end

    local banner = Setting("badgeBanner") == true
    if banner ~= (bannerOn or false) then
        bannerOn = banner
        if banner then
            groupEvents:RegisterEvent("GROUP_ROSTER_UPDATE")
            ScanGroup(true)
        else
            groupEvents:UnregisterEvent("GROUP_ROSTER_UPDATE")
            groupEvents:UnregisterEvent("PLAYER_REGEN_ENABLED")
            wipe(announced)
            wipe(waitName)
            wipe(waitRaid)
        end
    end

    SyncListen()
end

local function OnSettingSet(key)
    if type(key) == "string" and key:find("^badge") then Apply() end
end

hooksecurefunc(S, "Set", OnSettingSet)
hooksecurefunc(ns, "Apply", Apply)

local function PreviewEntry(tierKey)
    if tierKey == "developer" then return { tier = tierKey, title = PREVIEW_TITLE } end
    return { tier = tierKey, since = date("%Y-%m") }
end

local currentRegion

local function CurrentFirst(a, b)
    if a == currentRegion or b == currentRegion then return a == currentRegion and b ~= currentRegion end
    return a < b
end

local function CodeEntry(guid, name)
    if type(name) ~= "string" then return guid end
    return guid .. "=" .. (name:gsub("[%s,;:=]", "_"))
end

local function BadgeCode()
    local characters = ns.AccountSettings().badgeCharacters or {}
    local current = GetCurrentRegion and GetCurrentRegion()
    local me = UnitGUID("player")
    local regions, count = {}, 0
    for region in pairs(characters) do regions[#regions + 1] = region end
    currentRegion = current
    table.sort(regions, CurrentFirst)
    local groups = {}
    for _, region in ipairs(regions) do
        local list = {}
        local names = characters[region]
        for guid in pairs(names) do
            if not (region == current and guid == me) then list[#list + 1] = guid end
        end
        table.sort(list)
        for i = 1, #list do list[i] = CodeEntry(list[i], names[list[i]]) end
        if region == current and me then table.insert(list, 1, CodeEntry(me, names[me])) end
        if #list > 0 then
            count = count + #list
            groups[#groups + 1] = region .. ":" .. table.concat(list, ",")
        end
    end
    return table.concat(groups, ";"), count
end

local DISCORD = "https://discord.com/invite/naowh"
ns.NAOWH_DISCORD = DISCORD

local function ShowCode(code, count)
    local UI = ns.UI
    local dimmer, panel = ns.MakeModal(CODE.w, CODE.h, "badgeCode")
    local head = UI.KeepFont(panel, "head", CODE.headSize, "OUTLINE")
    head:SetPoint("TOP", 0, -CODE.headY)
    head:SetText(TEXT_CODE_TITLE)
    local hint = UI.KeepFont(panel, "hint", CODE.hintSize, nil, T.muted)
    hint:SetPoint("TOP", head, "BOTTOM", 0, -CODE.hintGap)
    hint:SetWidth(CODE.textW)
    hint:SetText(count .. (count == 1 and TEXT_CHARACTER or TEXT_CHARACTERS)
        .. (PATRONS and TEXT_CODE_SUPPORT or TEXT_CODE_TEAM))
    local box = UI.Keep(panel, "box", ns.NewEditBox)
    box:SetPoint("TOP", hint, "BOTTOM", 0, -CODE.boxGap)
    box:SetSize(CODE.textW, CODE.boxH)
    box:SetMaxLetters(0)
    box:SetText(code)
    box:SetScript("OnTextChanged", function(self, byUser)
        if byUser then self:SetText(code); self:HighlightText() end
    end)
    box:SetScript("OnEscapePressed", function() dimmer:Hide() end)
    UI.KeepButton(panel, "discord", TEXT_DISCORD, CODE.buttonW, CODE.buttonH, function()
        dimmer:Hide()
        ns.ShowCopyLine(TEXT_DISCORD_TITLE, DISCORD, (TIERS.legendary or TIERS.naowh).large)
    end):SetPoint("BOTTOM", panel, "BOTTOM", -CODE.buttonShift, CODE.pad)
    UI.KeepButton(panel, "close", TEXT_CLOSE, CODE.buttonW, CODE.buttonH, function() dimmer:Hide() end)
        :SetPoint("BOTTOM", panel, "BOTTOM", CODE.buttonShift, CODE.pad)
    dimmer:Show()
    box:SetFocus()
    box:HighlightText()
end

local PREVIEW_TIER = PATRONS and "legendary" or "developer"

local function BadgeStatus()
    local guid = playerGUID or UnitGUID("player")
    local entry = guid and not Secret(guid) and roster[guid]
    local tier = TierOf(entry)
    if not tier then return TEXT_STATUS_NONE end
    local title = TitleOf(entry, tier)
    if not entry.patron then return title end
    local state = Confirm.State()
    if state == Confirm.CONFIRMED then return TEXT_STATUS_CONFIRMED:format(title) end
    if state == Confirm.UNCLAIMED then return TEXT_STATUS_UNCLAIMED:format(title) end
    if state == Confirm.MISMATCH then return TEXT_STATUS_OFF:format(title) end
    return TEXT_STATUS_CHECKING:format(title)
end

local function ClaimCommand(code)
    local ok, state = Confirm.Claim(code)
    if not ok then
        ns.Print(TEXT_CLAIM_BAD)
    elseif state == Confirm.CONFIRMED then
        ns.Print(TEXT_CLAIM_DONE)
    elseif state == Confirm.UNCLAIMED or state == Confirm.MISMATCH then
        ns.Print(TEXT_CLAIM_WRONG)
    elseif not Confirm.Listed() then
        ns.Print(TEXT_CLAIM_SAVED)
    else
        ns.Print(BadgeStatus())
    end
end

function ns.BadgesCommand(arg)
    local raw = strtrim(arg or "")
    local claim = PATRONS and raw:match(CLAIM_COMMAND)
    if claim then return ClaimCommand(claim) end
    local word = raw:lower()
    local previewTier = word == "preview" and PREVIEW_TIER or word:match("^preview (%a+)$")
    local staffOnly = previewTier or word == "toast"
    if staffOnly and not IsStaff(UnitGUID("player")) then
        ns.Print(TEXT_STAFF_ONLY)
    elseif word == "id" then
        RememberCharacter()
        local code, count = BadgeCode()
        ShowCode(code, count)
    elseif word == "status" and PATRONS then
        ns.Print(BadgeStatus())
    elseif previewTier == "none" then
        previewEntry = false
        previewGUID = UnitGUID("player")
        ns.Print(TEXT_PREVIEW_NONE)
    elseif previewTier and TIERS[previewTier] then
        previewEntry = PreviewEntry(previewTier)
        previewGUID = UnitGUID("player")
        ns.Print(TEXT_PREVIEW_ON:format(TierOf(previewEntry).title))
    elseif word == "preview off" then
        previewGUID, previewEntry = nil, nil
        ns.Print(TEXT_PREVIEW_OFF)
    elseif word == "toast" then
        QueueToast(previewEntry or PreviewEntry(PREVIEW_TIER), FullName("player"), IsInRaid())
    else
        ns.Print(TEXT_USAGE:format(PATRONS and TEXT_USAGE_PATRON or ""))
    end
end

function ns.BadgeOf(guid, who, unit)
    local entry = EntryOf(guid, who, unit)
    local tier = TierOf(entry)
    if not tier then return nil end
    return tier, entry
end
ns.BADGE_TIERS = TIERS
ns.BadgeSince = SinceOf

function ns.PromptBadgeClaim()
    ns.PromptText(TEXT_CLAIM_PROMPT, "", CLAIM_LETTERS, ClaimCommand)
end

function ns.ShowBadgeCode()
    RememberCharacter()
    ShowCode(BadgeCode())
end

ns._BadgesTest = { DecorateName = DecorateName, ListBadges = listBadges, OnLinkEnter = OnLinkEnter, TIERS = TIERS,
    guidByLine = guidByLine, CACHE_SIZE = CACHE_SIZE, SinceOf = SinceOf,
    BuildRoster = BuildRoster, BadgeCode = BadgeCode, BadgeStatus = BadgeStatus,
    Card = function() return card end, Toast = function() return toast end,
    QueueSize = function() return queueTail - queueHead + 1 end, GroupEvents = groupEvents }

local Settings = PATRONS and ns.Shared and ns.Shared.Settings
if not Settings then return end

local BADGE_KEYS = { "badgeChat", "badgeCard", "badgeTooltip", "badgeBanner", "badgeBannerSkipGuild" }

local function BadgesSummary(store)
    local on = 0
    for i = 1, #BADGE_KEYS do
        if store.Get(BADGE_KEYS[i]) then on = on + 1 end
    end
    return TEXT_SUMMARY:format(on, #BADGE_KEYS)
end

Settings.Page("QoL/Interface", S):Card({
    id = "supporterBadges", name = "Supporter Badges", order = 55,
    help = "Shows who Naowh, the developers, the moderators and our Legendary and Epic patrons are: a badge "
        .. "by their name in chat, a line on their tooltip and, if you want it, a banner when one "
        .. "of them joins your group.",
    search = "badge id claim code /nf badges nf badges",
    summary = BadgesSummary,
    rows = {
        { key = "badgeChat", label = "Chat Badges", toggle = true,
          help = "The Naowh Forever N next to the name of Naowh, the developers, the moderators and "
              .. "our Legendary and Epic patrons in chat." },
        { key = "badgeCard", label = "Hover Card", toggle = true, needs = "badgeChat",
          help = "Hover a badged name in chat to see their card." },
        { key = "badgeTooltip", label = "Tooltip Line", toggle = true,
          help = "A line in their color on their player tooltip." },
        { key = "badgeBanner", label = "Group Banner", toggle = true,
          help = "A banner and a sound when one of them joins your group." },
        { key = "badgeBannerSkipGuild", label = "No Banner For Guild Members", toggle = true,
          needs = "badgeBanner", help = "Skips the banner when they're in your guild." },
        { label = "Show My Character Code", buttonText = "Show", button = ns.ShowBadgeCode,
          help = "Your characters' code, to add them to your badge on naowh.gg." },
    },
})

if not ns.SETUPS_PAGE then return end

Settings.Page(ns.SETUPS_PAGE, S):Card({
    id = "yourBadge", name = "Your Badge", order = 5,
    help = "Your badge on this character, and whether it matched the BattleTag saved on naowh.gg.",
    search = "badge battletag status supporter patron claim code",
    summary = BadgeStatus,
    rows = {
        { label = "Claim", buttonText = "Claim", button = ns.PromptBadgeClaim,
          help = "Paste the claim code from naowh.gg, if the Naowh Forever app doesn't do it for you." },
        { label = "Show My Character Code", buttonText = "Show", button = ns.ShowBadgeCode,
          help = "Your characters' code, to add them to your badge on naowh.gg." },
    },
})

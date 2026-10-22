-- AuraIcon.lua: an aura icon with its stacks and the game's own countdown, the same look on an aura button and on a settings preview (Shared.AuraIcon).
local ns = _G.NaowhForever

local ROUND = 0.5
local WARN_SPAN = 2
local UNITS_SHOWN = 1

local formatter

local function Formatter()
    if formatter then return formatter end
    formatter = C_StringUtil.CreateSecondsFormatter()
    formatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
    formatter:SetStripIntervalWhitespace(Enum.SecondsFormatterIntervalWhitespace.Strip)
    formatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
    formatter:SetRounding(Enum.SecondsFormatterRounding.RoundUp)
    formatter:SetDesiredUnitCount(UNITS_SHOWN)
    return formatter
end

local function Color(rgba)
    return CreateColor(rgba[1], rgba[2], rgba[3], rgba[4])
end

function ns.Shared.AuraIcon(S, St)
    local BORDER, ICON_CROP, TEXT_INSET = St.BORDER, St.ICON_CROP, St.TEXT_INSET
    local TIME_SIZE, COUNT_SIZE, MIN_TEXT = St.TIME_SIZE, St.COUNT_SIZE, St.MIN_TEXT
    local BLACK, OUTLINE, BLINK = St.BLACK, St.OUTLINE, St.BLINK
    local WHITE_RGBA, YELLOW_RGBA, RED_RGBA, FAINT_RGBA = St.WHITE_RGBA, St.YELLOW_RGBA, St.RED_RGBA, St.FAINT_RGBA
    local timerOptions, timerSignature

    local Icon = { Formatter = Formatter }

    function Icon.Size()
        return S.Get("size")
    end

    function Icon.TextSize(ratio)
        return math.max(MIN_TEXT, math.floor(Icon.Size() * ratio + ROUND))
    end

    local function WarnCurve(warnAt, blink)
        local curve = C_CurveUtil.CreateColorCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        curve:AddPoint(0, Color(RED_RGBA))
        if blink then
            local at, faint = BLINK, true
            while at < warnAt do
                curve:AddPoint(at, Color(faint and FAINT_RGBA or RED_RGBA))
                at, faint = at + BLINK, not faint
            end
        end
        curve:AddPoint(warnAt, Color(YELLOW_RGBA))
        curve:AddPoint(warnAt * WARN_SPAN, Color(WHITE_RGBA))
        return curve
    end

    local function TimerOptions()
        local warn = S.Get("warn") == true
        local signature = (warn and "1" or "0") .. S.Get("warnAt") .. (S.Get("warnBlink") and "1" or "0")
        if signature ~= timerSignature then
            timerSignature = signature
            timerOptions = { textFormatter = Formatter() }
            if warn then
                timerOptions.textColor = { curve = WarnCurve(S.Get("warnAt"), S.Get("warnBlink") == true),
                    property = Enum.DurationTextBindingProperty.RemainingDuration }
            end
        end
        return timerOptions, timerSignature
    end

    function Icon.TimeColor(left)
        if not S.Get("warn") then return WHITE_RGBA end
        local warnAt = S.Get("warnAt")
        if left < warnAt then return RED_RGBA end
        if left < warnAt * WARN_SPAN then return YELLOW_RGBA end
        return WHITE_RGBA
    end

    function Icon.Style(button)
        local size = Icon.Size()
        button:SetSize(size, size)
        button.timeText:SetFont(ns.UIFontPath(), Icon.TextSize(TIME_SIZE), OUTLINE)
        button.countText:SetFont(ns.UIFontPath(), Icon.TextSize(COUNT_SIZE), OUTLINE)
        button.timeText:SetShown(S.Get("timer") == true)
        button.countText:SetShown(S.Get("count") == true)
        if not button.aura then return end
        local options, signature = TimerOptions()
        if button.timerSignature ~= signature then
            button.timerSignature = signature
            button:SetDurationText(button.timeText, options)
        end
    end

    function Icon.New(frame)
        local ground = frame:CreateTexture(nil, "BACKGROUND")
        ground:SetAllPoints()
        ground:SetColorTexture(BLACK.r, BLACK.g, BLACK.b, 1)
        frame.icon = frame:CreateTexture(nil, "ARTWORK")
        frame.icon:SetPoint("TOPLEFT", BORDER, -BORDER)
        frame.icon:SetPoint("BOTTOMRIGHT", -BORDER, BORDER)
        frame.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        frame.swipe = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
        frame.swipe:SetAllPoints(frame.icon)
        frame.swipe:SetDrawEdge(false)
        frame.swipe:SetHideCountdownNumbers(true)
        frame.swipe:SetReverse(true)
        local text = CreateFrame("Frame", nil, frame)
        text:SetAllPoints()
        text:SetFrameLevel(frame.swipe:GetFrameLevel() + 1)
        frame.timeText = text:CreateFontString(nil, "OVERLAY")
        frame.timeText:SetPoint("BOTTOM", 0, TEXT_INSET)
        frame.countText = text:CreateFontString(nil, "OVERLAY")
        frame.countText:SetPoint("TOPRIGHT", -TEXT_INSET, -TEXT_INSET)
        Icon.Style(frame)
    end

    function Icon.SetClass(texture, coords)
        ns.Shared.Parts.ClassCrop(texture, coords)
    end

    return Icon
end

-- Quiz.lua: the WoW quiz for campfires and flights, also opened by /naowh quiz.
local ns = _G.NaowhForever

local S = ns.QoLSettings
local T = ns.THEME
local St = ns.Shared.Style

local CAMPFIRE_SEATED = 1229739
local RIGHT, WRONG = St.HAVE_RGB, St.RED_RGB
local QUIZ_W, QUIZ_H = 400, 330
local QUIZ_ALPHA = 0.95
local PAD, INSET = 12, 16
local LOGO_SIZE, LOGO_TOP, TITLE_GAP = 26, 8, 8
local TITLE_SIZE, QUESTION_SIZE, RESULT_SIZE, SCORE_SIZE = 16, 14, 14, 11
local CLOSE_SIZE, CLOSE_INSET = 22, 10
local QUESTION_TOP, QUESTION_H = 48, 44
local ANSWERS = 4
local ANSWER_W, ANSWER_H, ANSWER_TOP, ANSWER_STEP = 368, 30, 100, 36
local RESULT_TOP, NEXT_TOP = 250, 246
local NEXT_W, NEXT_H = 130, 26
local SCORE_BOTTOM = 14
local DEFAULT_Y = 120

local TEXT_TITLE = ns.L("Naowh Quiz")
local TEXT_SCORE = ns.L("%d / %d right   |   streak %d   |   best %d")
local TEXT_RIGHT = ns.L("|cff4dd17aCorrect!|r")
local TEXT_WRONG = St.RED_CODE .. ns.L("Not quite.|r")
local TEXT_NEXT = ns.L("Next Question")
local TEXT_CLOSE = "X"
local TEXT_BOTH = ns.L("While flying and at the campfire")
local TEXT_FLYING = ns.L("While flying")
local TEXT_CAMP = ns.L("At the campfire")
local TEXT_BY_HAND = ns.L("Only when you open it")

local quiz, deck, current
local openedFor
local atCamp
local asked, correct, streak = 0, 0, 0
local events = CreateFrame("Frame")

local function Best()
    return ns.AccountSettings().quizBest or 0
end

local function Shuffled(n)
    local out = {}
    for i = 1, n do out[i] = i end
    for i = n, 2, -1 do
        local j = math.random(i)
        out[i], out[j] = out[j], out[i]
    end
    return out
end

local function UpdateScore()
    quiz.score:SetText(TEXT_SCORE:format(correct, asked, streak, Best()))
end

local function NextQuestion()
    local bank = ns.QUIZ_QUESTIONS
    if not deck or #deck == 0 then deck = Shuffled(#bank) end
    local q = bank[table.remove(deck)]
    local order = Shuffled(#q.a)
    current = { answer = nil }
    quiz.question:SetText(q.q)
    for i, btn in ipairs(quiz.answers) do
        local pick = order[i]
        btn.label:SetText(q.a[pick])
        btn.label:SetTextColor(T.fg.r, T.fg.g, T.fg.b)
        btn.right = pick == 1
        btn:Enable()
        if btn.right then current.answer = btn end
    end
    quiz.result:SetText("")
    quiz.next:Hide()
end

local function Answer(btn)
    if not current or current.done then return end
    current.done = true
    asked = asked + 1
    for _, b in ipairs(quiz.answers) do b:Disable() end
    local c = current.answer
    c.label:SetTextColor(RIGHT.r, RIGHT.g, RIGHT.b)
    if btn.right then
        correct, streak = correct + 1, streak + 1
        if streak > Best() then ns.AccountSettings().quizBest = streak end
        quiz.result:SetText(TEXT_RIGHT)
    else
        streak = 0
        btn.label:SetTextColor(WRONG.r, WRONG.g, WRONG.b)
        quiz.result:SetText(TEXT_WRONG)
    end
    UpdateScore()
    quiz.next:Show()
end

local function OnDragStop(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    S.Set("quizPos", { point = point, relPoint = relPoint, x = x, y = y })
end

local function OnClose()
    ns.QuizDismiss()
end

local function BuildFrame()
    quiz = CreateFrame("Frame", "NaowhForeverQuiz", UIParent)
    quiz:SetSize(QUIZ_W, QUIZ_H)
    quiz:SetFrameStrata("HIGH")
    quiz:SetMovable(true)
    quiz:SetClampedToScreen(true)
    ns.AllowOffscreen(quiz)
    quiz:EnableMouse(true)
    quiz:RegisterForDrag("LeftButton")
    quiz:SetScript("OnDragStart", quiz.StartMoving)
    quiz:SetScript("OnDragStop", OnDragStop)
    ns.Solid(quiz, "BACKGROUND", T.bg, QUIZ_ALPHA):SetAllPoints()
    ns.Border(quiz)
end

local function BuildTitle()
    local logo = quiz:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(St.LOGO_SMALL, nil, nil, "TRILINEAR")
    logo:SetSize(LOGO_SIZE, LOGO_SIZE)
    logo:SetPoint("TOPLEFT", PAD, -LOGO_TOP)

    local title = ns.Font(quiz, TITLE_SIZE, "OUTLINE", T.accent)
    title:SetPoint("LEFT", logo, "RIGHT", TITLE_GAP, 0)
    title:SetText(TEXT_TITLE)

    local close = ns.Button(quiz, TEXT_CLOSE, CLOSE_SIZE, CLOSE_SIZE, OnClose)
    close:SetPoint("TOPRIGHT", -CLOSE_INSET, -CLOSE_INSET)
end

local function BuildBody()
    quiz.question = ns.Font(quiz, QUESTION_SIZE, nil)
    quiz.question:SetPoint("TOPLEFT", INSET, -QUESTION_TOP)
    quiz.question:SetPoint("RIGHT", -INSET, 0)
    quiz.question:SetJustifyH("LEFT")
    quiz.question:SetWordWrap(true)
    quiz.question:SetHeight(QUESTION_H)
    quiz.question:SetJustifyV("TOP")

    quiz.answers = {}
    for i = 1, ANSWERS do
        local btn = ns.Button(quiz, "", ANSWER_W, ANSWER_H)
        btn:SetPoint("TOPLEFT", INSET, -ANSWER_TOP - (i - 1) * ANSWER_STEP)
        btn:SetScript("OnClick", Answer)
        btn:SetMotionScriptsWhileDisabled(true)
        quiz.answers[i] = btn
    end

    quiz.result = ns.Font(quiz, RESULT_SIZE, "OUTLINE")
    quiz.result:SetPoint("TOPLEFT", INSET, -RESULT_TOP)

    quiz.next = ns.Button(quiz, TEXT_NEXT, NEXT_W, NEXT_H, NextQuestion)
    quiz.next:SetPoint("TOPRIGHT", -INSET, -NEXT_TOP)

    quiz.score = ns.Font(quiz, SCORE_SIZE, nil, T.muted)
    quiz.score:SetPoint("BOTTOMLEFT", INSET, SCORE_BOTTOM)
end

local function Build()
    BuildFrame()
    BuildTitle()
    BuildBody()
    quiz:Hide()
end

local function Place()
    local pos = S.Get("quizPos")
    quiz:ClearAllPoints()
    if pos then
        quiz:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        quiz:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_Y)
    end
end

local function Open(reason)
    if not ns.QUIZ_QUESTIONS or #ns.QUIZ_QUESTIONS == 0 then return end
    if not quiz then Build() end
    if quiz:IsShown() then return end
    openedFor = reason
    Place()
    NextQuestion()
    UpdateScore()
    quiz:Show()
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        ns.QuizDismiss(openedFor)
        return
    end
    if InCombatLockdown() or C_Secrets.ShouldAurasBeSecret() then return end
    local here = C_UnitAuras.GetPlayerAuraBySpellID(CAMPFIRE_SEATED) ~= nil
    if here == atCamp then return end
    atCamp = here
    if here then ns.QuizOffer("camp") else ns.QuizDismiss("camp") end
end

function ns.QuizDismiss(reason)
    if not (quiz and quiz:IsShown()) then return end
    if reason and openedFor ~= reason then return end
    quiz:Hide()
end

function ns.QuizOffer(reason)
    if not S.Get("enabled") or InCombatLockdown() then return end
    if reason == "camp" and not S.Get("quizCamp") then return end
    Open(reason)
end

function ns.QuizPlay(reason)
    if not S.Get("enabled") or InCombatLockdown() then return end
    Open(reason)
end

function ns.ToggleQuiz()
    if quiz and quiz:IsShown() then quiz:Hide() else Open(nil) end
end

local function Apply()
    events:UnregisterAllEvents()
    if not S.Get("enabled") then
        ns.QuizDismiss(openedFor)
        return
    end
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    if S.Get("quizCamp") then
        events:RegisterUnitEvent("UNIT_AURA", "player")
    else
        atCamp = nil
    end
end

local function ResetPosition()
    S.Set("quizPos", nil)
    if quiz then Place() end
end

local function Summary(store)
    local flight, camp = store.Get("flightGame") == "quiz", store.Get("quizCamp")
    if flight and camp then return TEXT_BOTH end
    if flight then return TEXT_FLYING end
    if camp then return TEXT_CAMP end
    return TEXT_BY_HAND
end

events:SetScript("OnEvent", OnEvent)

hooksecurefunc(S, "Set", function(key)
    if key == "enabled" or key == "quizCamp" then Apply() end
end)
hooksecurefunc(ns, "Apply", Apply)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", Apply)

ns.Shared.Settings.Page("QoL/Travel", S):Card({
    id = "quiz", name = "Quiz", order = 20,
    help = "A WoW quiz for campfires and flights, or any time with /naowh quiz.",
    summary = Summary,
    rows = {
        { key = "quizCamp", label = "Quiz at the Campfire", toggle = true,
          help = "The quiz opens when you sit down at a campfire and closes when you stand up." },
        { label = "Open the Quiz", buttonText = "Open", button = ns.ToggleQuiz,
          help = "Opens the quiz now, or closes it." },
        { label = "Quiz Position", buttonText = "Reset", button = ResetPosition,
          help = "Puts the quiz back where it first opened." },
    },
})

ns.RegisterMinimapFeature({
    id = "Quiz", name = "Quiz", icon = "Interface\\Icons\\INV_Misc_QuestionMark",
    open = ns.ToggleQuiz, tooltip = "Click to open or close the Quiz.",
})

-- Run with Lua 5.1 from the repository root: the profession window's docked Blizzard parts stay readable:
-- the Unlearn button shows a red cross even where its atlas is missing, and every tab gets one outline
-- on the right edge. With Dock Shopping List on the tabs move to the left edge, mirrored, with no outline.
local f = assert(io.open(arg[1] or "NaowhForever_Professions/UI/Takeover.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local function Slice(a, b)
    local first = assert(source:find(a, 1, true))
    return source:sub(first, assert(source:find(b, first + #a, true)) - 1)
end

local ATLAS, FALLBACK = "Profession-button-red-crossmark", "Interface/RAIDFRAME/ReadyCheck-NotReady"
local WIN = {}
local function Env(atlasKnown, tabsLeft, frame)
    local made, hooks = 0, 0
    local env = {
        UNLEARN_ATLAS = ATLAS, UNLEARN_FALLBACK = FALLBACK, UNLEARN_SIZE = 20, outlines = {},
        TABS_DROP = -60, EMPTY = {}, win = WIN, tabsLeft = tabsLeft, mirrored = {}, flippedArt = {},
        hookedArt = {}, placing = false, ProfessionsFrame = frame,
        FLIP = { LEFT = "RIGHT", RIGHT = "LEFT", TOPLEFT = "TOPRIGHT", TOPRIGHT = "TOPLEFT",
            BOTTOMLEFT = "BOTTOMRIGHT", BOTTOMRIGHT = "BOTTOMLEFT" },
        hooksecurefunc = function() hooks = hooks + 1 end,
        wipe = function(t) for k in pairs(t) do t[k] = nil end end,
        C_Texture = { GetAtlasInfo = function(name) return atlasKnown and name == ATLAS and {} or nil end },
        ns = { THEME = { accent = { r = 0, g = 0.57, b = 0.93 } },
            Border = function()
                made = made + 1
                local outline = { shown = true }
                outline.SetShown = function(self, on) self.shown = on end
                return { _frame = outline }
            end },
    }
    setmetatable(env, { __index = _G })
    local code = Slice("local function OutlineTab(", "\nlocal function Place(")
        .. "\nreturn OutlineTab, ShowUnlearn, DockTabs"
    local chunk = assert(loadstring(code)); setfenv(chunk, env)
    local Outline, Show, Dock = chunk()
    return env, Outline, Show, function() return made end, Dock, function() return hooks end
end
local function Icon()
    return { SetTexture = function(self, t) self.texture = t end,
        SetSize = function(self, w, h) self.w, self.h = w, h end,
        SetAlpha = function(self, a) self.alpha = a end }
end
local function Anchored(points)
    local region = { points = points }
    function region:GetNumPoints() return #self.points end
    function region:GetPoint(i) return unpack(self.points[i]) end
    function region:ClearAllPoints() self.points = {} end
    function region:SetPoint(...) self.points[#self.points + 1] = { ... } end
    return region
end
local function Tab()
    local tab = Anchored({ { "TOPLEFT", "parent", "TOPRIGHT", 0, 0 } })
    local art = Anchored({ { "LEFT", tab, "LEFT", 3, 0 } })
    art.coords = { 0, 0, 0, 1, 1, 0, 1, 1 }
    function art:GetObjectType() return "Texture" end
    function art:GetAtlas() return "tab" end
    function art:GetTexCoord() return unpack(self.coords) end
    function art:SetTexCoord(...) self.coords = { ... } end
    tab.art = art
    function tab:GetRegions() return self.art end
    function tab:SetIgnoreParentAlpha(on) self.ignoring = on end
    return tab
end
local function Frame()
    return { ProfessionsOverviewTab = Tab(), rightProfessionTabs = { Tab() } }
end
local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

Case("an Unlearn button without its atlas gets the red cross texture", function()
    local _, _, Show = Env(false)
    local button = { Icon = Icon() }
    Show(button)
    assert(button.Icon.texture == FALLBACK and button.Icon.w == 20 and button.Icon.h == 20 and button.Icon.alpha == 1)
end)
Case("with its atlas it keeps it, at a size and strength that can be seen", function()
    local _, _, Show = Env(true)
    local button = { Icon = Icon() }
    Show(button)
    assert(button.Icon.texture == nil and button.Icon.w == 20 and button.Icon.alpha == 1)
end)
Case("a button with no icon is left alone", function()
    local _, _, Show = Env(true)
    Show({})
end)
Case("a tab is outlined once, hidden when undocked and shown again when docked", function()
    local env, Outline, _, made = Env(true)
    local tab = {}
    Outline(tab, true)
    Outline(tab, true)
    assert(made() == 1 and env.outlines[tab]._frame.shown == true, "one outline, shown")
    Outline(tab, false)
    assert(env.outlines[tab]._frame.shown == false, "hidden when undocked")
    Outline(tab, true)
    assert(made() == 1 and env.outlines[tab]._frame.shown == true, "shown again, not made twice")
    local never = {}
    Outline(never, false)
    assert(made() == 1 and env.outlines[never] == nil, "an undocked tab never gets one")
end)
Case("Dock Shopping List off: the tabs dock on the right edge, outlined, art untouched", function()
    local frame = Frame()
    local head, tab = frame.ProfessionsOverviewTab, frame.rightProfessionTabs[1]
    local env, _, _, made, Dock, hooks = Env(true, false, frame)
    Dock(true)
    local p = head.points[1]
    assert(#head.points == 1 and p[1] == "TOPLEFT" and p[2] == WIN and p[3] == "TOPRIGHT", "right edge")
    assert(made() == 2 and env.outlines[head]._frame.shown and env.outlines[tab]._frame.shown, "outlined")
    assert(hooks() == 0 and #env.mirrored == 0 and tab.art.coords[1] == 0 and tab.art.points[1][1] == "LEFT",
        "nothing mirrored or hooked")
    assert(head.ignoring and tab.ignoring, "the tabs ignore their parent's alpha")
    Dock(false)
    assert(head.points[1][2] == "parent" and not env.outlines[head]._frame.shown and not tab.ignoring, "put back")
end)
Case("Dock Shopping List on: the tabs move to the left edge, mirrored, with no outline", function()
    local frame = Frame()
    local head, tab = frame.ProfessionsOverviewTab, frame.rightProfessionTabs[1]
    local env, _, _, made, Dock, hooks = Env(true, true, frame)
    Dock(true)
    local p = head.points[1]
    assert(p[1] == "TOPRIGHT" and p[2] == WIN and p[3] == "TOPLEFT", "left edge")
    assert(made() == 0, "no outline")
    assert(hooks() == 2 and tab.art.coords[1] == 1 and tab.art.points[1][1] == "RIGHT"
        and tab.art.points[1][4] == -3, "art flipped and its anchors swapped")
    Dock(false)
    assert(head.points[1][2] == "parent" and tab.art.coords[1] == 0 and tab.art.points[1][1] == "LEFT"
        and #env.mirrored == 0, "put back")
end)
Case("the side is read once, when the window is first built, and only the left side moves the window", function()
    assert(Slice("local function FirstBuild(", "\nlocal function ShowParts(")
        :find("tabsLeft = S.Get(\"shoppingListDock\")", 1, true))
    assert(Slice("function Drag.Fit()", "\nlocal function OnDragStart(")
        :find("if not tabsLeft then return end", 1, true))
end)
Case("docking restyles the Unlearn button", function()
    assert(Slice("local function DockCards(", "\nlocal function DockBook(")
        :find("ShowUnlearn(blizz.UnlearnButton)", 1, true))
end)
print(count .. " profession tab icon regressions passed")

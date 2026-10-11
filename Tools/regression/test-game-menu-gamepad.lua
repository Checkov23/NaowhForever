local file = assert(io.open("Core/Options/GameMenu.lua", "rb"))
local source = file:read("*a"):gsub("\r\n", "\n"); file:close()
local first = assert(source:find("local function Clicked()", 1, true))
local last = assert(source:find("local function PlaceAfterOptions", first, true))
local added, owns, hidden, opened = 0, false, 0, 0
local menu = { buttons = {} }
function menu:AddButton() self.buttons[#self.buttons + 1] = {} return {} end
local env = {
 On = function() return true end,
 TEXT_NAOWH = "Naowh ",
 TEXT_FOREVER = "Forever",
 PlaySound = function() end,
 SOUNDKIT = {},
 GameMenuFrame = {},
 HideUIPanel = function() hidden = hidden + 1 end,
 ns = { L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, GamepadOwnsPanels = function() return owns end, OpenOptionsWindow = function() opened = opened + 1 end,
  Color = function(_, text) return text end },
 MainMenuFrameMixin = { AddButton = function() added = added + 1 return {} end },
}
local chunk = assert(loadstring("local button\n" .. source:sub(first, last - 1) .. "return Added, Clicked"))
setfenv(chunk, env)
local Added, Clicked = chunk()
Added(menu)
assert(added == 1, "button must be added from the pool")
assert(#menu.buttons == 0, "button must stay out of menu.buttons")
owns = true
Added(menu)
assert(added == 1, "button must be left out while the gamepad owns Blizzard's panels")
owns = false
Clicked()
assert(hidden == 1 and opened == 1, "a click hides the menu and opens the window")
owns = true
Clicked()
assert(hidden == 1 and opened == 2, "a click after the menu went gamepad must not hide it from our code")
print("5 game menu gamepad checks passed")

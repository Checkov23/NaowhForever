-- Returns ns.Shared.Places as Shared/Game/Places.lua makes it, with the map aliases of
-- Shared/Data/SameMaps.lua, for a test whose stub ns builds its own ns.Shared rather than loading
-- Shared.xml. Not a test itself (run-all.sh runs only test*.lua). Run from the repo root:
--
--   Shared = { Places = dofile("Tools/regression/shared_places.lua"), ... }
local shared = {}
for _, path in ipairs({ "Shared/Data/SameMaps.lua", "Shared/Game/Places.lua" }) do
    local chunk = assert(loadfile(path))
    setfenv(chunk, { _G = { NaowhForever = { Shared = shared } } })
    chunk()
end
return shared.Places

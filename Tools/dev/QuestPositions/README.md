# QuestPositions

A development addon, never shipped (`.pkgmeta` leaves out `Tools/`). It asks the game client which
zone map each quest giver's spawn is on, for the quests `Tools/build/elsewhere_quests.py` can place
from no Wowhead page.

## Use

1. `python Tools/build/elsewhere_quests.py --offline --positions` writes `Positions.lua` here: the
   spawns not resolved yet.
2. Point a Forever `Interface\AddOns\QuestPositions` folder at this one (a junction works) and
   start the game; a new addon folder needs a restart.
3. Type `/questpositions`, then `/reload` so the game writes `QuestPositionsResults` to
   `WTF/Account/<account>/SavedVariables/QuestPositions.lua`.
4. `python Tools/build/elsewhere_quests.py --offline --resolved <that file>` keeps the answers in
   `Tools/data/completo_positions.json`, places the quests and says how often the client agrees
   with Wowhead on the givers both place. Then `python Tools/build/completo_quests.py --offline`.
5. Take the folder out of AddOns again.

## Why

- A spawn's world position is put on its continent's map, then `C_Map.GetMapInfoAtPosition` gives
  the zone under it, the lookup the continent map's zone highlight uses, as in Journeys' `World.ToMap`.
  Unlike that, it starts from the continent's map and goes on down while the map under it is a zone
  (a city inside one), at most `MAX_DEPTH`.
- A position the client puts on no zone is saved with nothing after its `=`, so it is not asked
  again.
- The answers in `completo_positions.json` are kept by world position and never expire: after Forever
  redraws a map, delete it and resolve them again.
- The results are one string per position, `continent,x,y=uiMapID,x,y`, so the build reads them
  with a pattern instead of a Lua parser.

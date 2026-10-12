# Tools/nav: the walking maps

Bakes the Forever client's terrain into the walking maps Journeys plans walks on, and packs them into
`NaowhForever_JourneysData/`. Node, not Python: the two libraries it stands on are JavaScript. Nothing
here ships.

```
cd Tools/nav
npm install --ignore-scripts      # once: @rhyster/wow-casc-dbc and recast-navigation, pinned
node bake.mjs 1                   # Kalimdor; 0 is the Eastern Kingdoms, 2991 Zephras Isle
node pack.mjs 1 --write           # writes NaowhForever_JourneysData/Data/Map1*.lua and the XML
```

A bake downloads the client's files from Blizzard's CDN the first time (`.cache/files`, about 2 GB for
both continents) and keeps every finished tile in `.cache/tiles`, so a stopped bake picks up where it
left off. Run one bake at a time: the download library keeps a cache of its own in `cache/`. Delete
`.cache/tiles` after changing anything in `tile.mjs`, `mesh.mjs` or the readers.

## Layout

| File | What it does |
| --- | --- |
| `casc.mjs` | Reads a client file by its file ID from the CDN (`wow_classic_beta`, which is Forever), cached. |
| `wago.mjs` | Reads a game table for a build from wago.tools, as `Tools/sources/wago.py` does. |
| `adt.mjs` | A map tile's terrain, its holes, its liquids and what stands on it, in world yards. |
| `wmo.mjs` | A WMO's collision triangles. |
| `m2.mjs` | A doodad's collision triangles. |
| `place.mjs` | Puts a model's triangles into the world. |
| `mesh.mjs` | Gathers everything solid around one tile, with its neighbours' near edge. |
| `tile.mjs` | Builds a tile's walkable polygons with Recast, liquids marked as lakes, sea or blocked. |
| `bake.mjs` | Bakes every tile of a map. |
| `link.mjs` | Joins the polygons on either side of every tile edge. |
| `graph.mjs` | The crossings between tiles and the walking cost between a tile's crossings. |
| `cbor.mjs` | The CBOR writer the packed data uses. |
| `pack.mjs` | Drops the small cut-off pieces, packs every tile, the crossings and the network's walks, and writes the data addon. |
| `places.mjs` | Lists the network's places by the groups that walk to each other, to see what a bake cut off. |
| `render.mjs`, `minimap.mjs`, `region.mjs`, `overview.mjs` | Pictures of a bake, over the game's own minimap, to check it by eye. |

## Why

- Positions are world yards, x north and y west, as the game's tables and `UnitPosition` give them.
  Recast is y up: (east, up, south) = (-y, z, -x) is a rotation, so triangles keep their winding.
- A model's placement is a rotation about up by its second angle plus a half turn, then its first,
  then its third. This was fitted against the bounding boxes the map files store for every WMO they
  place (28 WMOs, 0.002 yards apart). Model floors face up as stored.
- Newer WMO groups keep their triangle flags in `MPY2` (four bytes a triangle) instead of `MOPY`, and
  may index with `MOVX`. Forever's rebuilt cities use them; reading only `MOPY` left the Orgrimmar
  flight tower out.
- The cell is a tile divided by 533 (about 1.0006 yards). With a whole yard, a tile's far edge fell up
  to two thirds of a cell off the true line and half the tile edges failed to join.
- Liquids: Forever's own ocean (`PBRWater - Generic - Ocean`) is filed with water's sounds, so the
  sea is told apart by its name as well. Lakes and rivers swim at 1.6 times the cost, the sea at 2.5;
  lava and slime block. Only ground deeper than 1.5 yards under the surface is marked.
- About 44% of the polygons are small pieces cut off from everything around them: roofs, ledges, and
  tower tops whose stairs did not bake (the Orgrimmar flight tower's ramp comes out in a dozen pieces).
  They are dropped. A place or a player on one is walked from the nearest large piece within 80 yards,
  with the height between added to the cost; in game they find the stairs themselves.
- A flight point's position in the game's table is where the flight starts, a few yards from the
  master, so `Tools/build/journeys.py` moves it onto the flight master from `Shared/Game/Towns.lua`.
  The table's height is kept: it tells a tower's top from the ground under it.
- Contours are simplified to 3 cells: it halves the data against 1.5, and a walk does not need the
  outline of a wall closer than that.
- Lifts are not in the client's tables (the server spawns them), so Thunder Bluff, Freewind Post and
  Undercity's lifts are not in the network yet.

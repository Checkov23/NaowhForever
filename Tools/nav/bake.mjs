// Bakes every tile of a map into walkable polygons, saved one JSON per tile in .cache/tiles, so a
// stopped bake picks up where it left off.
//   node bake.mjs <map> [x0 y0 x1 y1]     map is 0 (Eastern Kingdoms), 1 (Kalimdor) or 2991 (Zephras Isle)
import { mkdir, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { file, CACHE, version } from './casc.mjs';
import { tiles } from './adt.mjs';
import { gather } from './mesh.mjs';
import { build, liquidAreas, MARGIN } from './tile.mjs';
import { table } from './wago.mjs';

export const WDT = { 0: 775971, 1: 782779, 2991: 7198644 };
export const BUILD = '1.60.1.70338';
export const TILES = join(CACHE, 'tiles');
const AT_ONCE = 6;

export function tilePath(map, x, y) {
  return join(TILES, `${map}_${x}_${y}.json`);
}

async function Bake(map, list, t, liquids) {
  const path = tilePath(map, t.x, t.y);
  if (existsSync(path)) return 'kept';
  const geometry = await gather(list, t.x, t.y, MARGIN);
  const tile = await build(geometry, t.x, t.y, liquids);
  await writeFile(path, JSON.stringify(tile ?? { verts: [], polys: [] }));
  return tile ? tile.polys.length : 0;
}

async function main() {
  const [mapArg, ...range] = process.argv.slice(2);
  const map = Number(mapArg);
  if (!(map in WDT)) throw new Error('map is 0, 1 or 2991');
  await mkdir(TILES, { recursive: true });
  const liquids = liquidAreas(await table('LiquidType', BUILD));
  let list = tiles(await file(WDT[map]));
  const all = list;
  if (range.length === 4) {
    const [x0, y0, x1, y1] = range.map(Number);
    list = list.filter(t => t.x >= x0 && t.x <= x1 && t.y >= y0 && t.y <= y1);
  }
  console.log(`map ${map}, client ${version?.VersionsName ?? 'cached'}: ${list.length} tiles`);
  let next = 0, done = 0, polys = 0;
  const start = Date.now();
  async function Worker() {
    while (next < list.length) {
      const t = list[next++];
      const result = await Bake(map, all, t, liquids);
      done++;
      if (typeof result === 'number') polys += result;
      if (done % 25 === 0 || done === list.length) {
        const rate = (Date.now() - start) / done / 1000;
        console.log(`${done}/${list.length} tiles, ${polys} polys, ${rate.toFixed(1)} s a tile`);
      }
    }
  }
  await Promise.all(Array.from({ length: AT_ONCE }, Worker));
}

if (process.argv[1] && process.argv[1].endsWith('bake.mjs')) await main();

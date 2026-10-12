// Lists a packed map's network places by the groups that can walk to each other: run after a bake to
// see what got cut off (an island is meant to be; a city flight master is not).
//   node places.mjs <map>
import { readFile } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { pack } from './pack.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const map = Number(process.argv[2]);
const r = await pack(map);
const lua = await readFile(join(HERE, '..', '..', 'NaowhForever_Journeys', 'Data', 'Network.lua'), 'utf8');
const names = {};
for (const m of lua.matchAll(/\[(\d+)\] = \{ "((?:[^"\\]|\\.)*)"/g)) names[`f${m[1]}`] = m[2];
const groups = [];
const seen = new Set();
r.spots.forEach((s, i) => {
  if (seen.has(i) || !r.attach[i]) return;
  const group = [];
  r.spots.forEach((t, j) => { if (r.walks[i][j] >= 0) { group.push(j); seen.add(j); } });
  groups.push(group);
});
groups.sort((a, b) => b.length - a.length);
const pairs = r.walks.flat().filter(v => v >= 0).length;
console.log(`map ${map}: ${r.tiles.size} tiles, ${pairs} of ${r.spots.length ** 2} place pairs walk to each other`);
for (const g of groups) console.log(g.length, g.map(j => names[r.spots[j].key] || r.spots[j].key).join(' | '));

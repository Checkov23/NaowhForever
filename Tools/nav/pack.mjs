// Packs a baked map for the addon: each tile's polygons, the crossings between tiles with the cost
// between every two on a tile, and the walking cost between every two places of the Journeys network.
// A tile's vertices and polygon corners are stored as differences from the one before, which halves
// them once deflated; its polygons' neighbours are left out, as the addon finds them by shared edges.
//   node pack.mjs <map> [--write]
import { readFile, writeFile, mkdir, readdir, unlink } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateRawSync } from 'node:zlib';
import { load, linkAll } from './link.mjs';
import { crossings, tileCosts, adjacency, spread, centroid } from './graph.mjs';
import { bounds } from './mesh.mjs';
import { tiles as tileList } from './adt.mjs';
import { file } from './casc.mjs';
import { WDT } from './bake.mjs';
import { encode } from './cbor.mjs';
import { AREA_WATER, AREA_OCEAN } from './tile.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..', '..');
const NETWORK = join(ROOT, 'NaowhForever_Journeys', 'Data', 'Network.lua');
const Q = 1;
const ATTACH_REACH = 80;
const NO_WAY = -1;
const MAIN_SIZE = 300;
const MAX_POLY_VERTS = 8;   // Walk.lua keys a polygon's edges as polygon * 8 + edge
const DATA = join(ROOT, 'NaowhForever_JourneysData', 'Data');
const FILE_BYTES = 3500000;
const CRLF = String.fromCharCode(13, 10);

// The network's places on a map: [{ key, x, y, z }], keyed as the addon names them.
export async function places(map) {
  const lua = await readFile(NETWORK, 'utf8');
  const out = [];
  const flights = lua.slice(lua.indexOf('flights = {'), lua.indexOf('hops = {'));
  for (const m of flights.matchAll(/\[(\d+)\] = \{ "(?:[^"\\]|\\.)*", (\d+), (-?[\d.]+), (-?[\d.]+), (-?[\d.]+|nil),/g)) {
    if (Number(m[2]) === map) out.push({ key: `f${m[1]}`, x: Number(m[3]), y: Number(m[4]), z: m[5] === 'nil' ? null : Number(m[5]) });
  }
  const ships = lua.slice(lua.indexOf('ships = {'), lua.indexOf('links = {')).split('\n').filter(l => l.includes('{ "'));
  ships.forEach((line, s) => {
    [...line.matchAll(/\{ (\d+), (-?[\d.]+), (-?[\d.]+), \d+, "/g)].forEach((m, d) => {
      if (Number(m[1]) === map) out.push({ key: `s${s + 1}.${d + 1}`, x: Number(m[2]), y: Number(m[3]), z: null });
    });
  });
  const links = lua.slice(lua.indexOf('links = {')).split('\n').filter(l => l.includes('{ "'));
  links.forEach((line, l) => {
    [...line.matchAll(/\{ (\d+), (-?[\d.]+), (-?[\d.]+), "/g)].forEach((m, e) => {
      if (Number(m[1]) === map) out.push({ key: `l${l + 1}.${e + 1}`, x: Number(m[2]), y: Number(m[3]), z: null });
    });
  });
  return out;
}

function TileOf(x, y) {
  const TILE = 1600 / 3, ORIGIN = 32 * TILE;
  return [Math.floor((ORIGIN - y) / TILE), Math.floor((ORIGIN - x) / TILE)];
}

function Inside(tile, poly, x, y) {
  const v = poly.verts.map(i => tile.verts[i]);
  let inside = false;
  for (let i = 0, j = v.length - 1; i < v.length; j = i++) {
    if ((v[i][1] > y) !== (v[j][1] > y) && x < (v[j][0] - v[i][0]) * (y - v[i][1]) / (v[j][1] - v[i][1]) + v[i][0]) inside = !inside;
  }
  return inside;
}

// The polygon a place stands on, or the nearest within reach: [poly, extra yards] or null. With keep,
// only polygons it accepts are looked at. The extra yards count the height between too, when known.
export function standOn(tile, x, y, z, keep = () => true) {
  let best = null, bestScore = Infinity;
  tile.polys.forEach((poly, p) => {
    if (!keep(p)) return;
    const c = centroid(tile, poly);
    const flat = Math.hypot(c[0] - x, c[1] - y);
    const inside = Inside(tile, poly, x, y);
    const rise = z == null ? 0 : Math.abs(c[2] - z);
    const score = (inside ? 0 : flat) + rise * (inside ? 1 : 0.25);
    if (score < bestScore && (inside || flat < ATTACH_REACH)) { best = [p, inside ? 0 : flat + rise]; bestScore = score; }
  });
  return best;
}

// Which polygons lie in small pieces cut off from everything around them (a tower top whose stairs
// did not bake, a ledge): a Set of "x,y:poly". Places and players on one are walked from the nearest
// ground of a large piece instead, as the game's own pathing gets them down.
export function smallPieces(tiles) {
  const id = new Map();
  const size = [];
  for (const [key, tile] of tiles) {
    tile.polys.forEach((_, p) => {
      if (id.has(`${key}:${p}`)) return;
      const c = size.length;
      size.push(0);
      const stack = [[key, p]];
      id.set(`${key}:${p}`, c);
      while (stack.length) {
        const [k, q] = stack.pop();
        size[c]++;
        const t = tiles.get(k);
        const [x, y] = k.split(',').map(Number);
        const next = t.polys[q].neighbours.filter(n => n >= 0).map(n => [k, n]);
        for (const [lp, , dx, dy, o] of t.links) if (lp === q) next.push([`${x + dx},${y + dy}`, o]);
        for (const [k2, o] of next) if (tiles.has(k2) && !id.has(`${k2}:${o}`)) { id.set(`${k2}:${o}`, c); stack.push([k2, o]); }
      }
    });
  }
  const small = new Set();
  for (const [poly, c] of id) if (size[c] < MAIN_SIZE) small.add(poly);
  return small;
}

// Drops the small pieces from every tile, renumbering the polygons that stay and their neighbours and
// links. Nobody's walk starts on one: a spot on one is walked from the nearest large piece.
function prune(tiles, small) {
  for (const [key, tile] of [...tiles]) {
    const keep = new Map();
    tile.polys.forEach((_, p) => { if (!small.has(`${key}:${p}`)) keep.set(p, keep.size); });
    if (!keep.size) { tiles.delete(key); continue; }
    tile.polys = [...keep.keys()].map(p => {
      const poly = tile.polys[p];
      return { ...poly, neighbours: poly.neighbours.map(n => n >= 0 ? (keep.get(n) ?? -1) : n) };
    });
    tile.keep = keep;
  }
  for (const [key, tile] of tiles) {
    const [x, y] = key.split(',').map(Number);
    tile.links = tile.links.flatMap(([p, k, dx, dy, q]) => {
      const other = tiles.get(`${x + dx},${y + dy}`);
      const mine = tile.keep.get(p), theirs = other && other.keep.get(q);
      return mine === undefined || theirs === undefined ? [] : [[mine, k, dx, dy, theirs]];
    });
  }
  for (const tile of tiles.values()) delete tile.keep;
}

function GraphSearch(count, adj, seeds) {
  const cost = new Float64Array(count).fill(Infinity);
  const asTile = Array.from({ length: count }, (_, i) => adj.get(i) || []);
  const result = spread(asTile, seeds);
  for (let i = 0; i < count; i++) cost[i] = result[i];
  return cost;
}

export async function pack(map) {
  const all = tileList(await file(WDT[map]));
  const tiles = new Map();
  for (const t of all) {
    const tile = await load(map, t.x, t.y);
    if (tile && tile.polys.length) tiles.set(`${t.x},${t.y}`, tile);
  }
  const joined = linkAll(tiles);
  prune(tiles, smallPieces(tiles));
  const cross = crossings(tiles);
  const { edges, byTile } = tileCosts(tiles, cross);

  const adj = new Map();
  for (const [a, b, c] of edges) {
    if (!adj.has(a)) adj.set(a, []);
    if (!adj.has(b)) adj.set(b, []);
    adj.get(a).push([b, c]);
    adj.get(b).push([a, c]);
  }

  const spots = await places(map);
  const attach = [];
  for (const s of spots) {
    const [tx, ty] = TileOf(s.x, s.y);
    const key = `${tx},${ty}`;
    const tile = tiles.get(key);
    const stand = tile && standOn(tile, s.x, s.y, s.z);
    if (!stand) { attach.push(null); console.log(`  ${s.key} has no ground under it`); continue; }
    const cost = spread(adjacency(tile), [[stand[0], stand[1]]]);
    const mids = tile.polys.map(p => centroid(tile, p));
    const reach = (byTile.get(key) || []).map(({ c, poly }) =>
      [c.id, cost[poly] + Math.hypot(mids[poly][0] - c.point[0], mids[poly][1] - c.point[1])])
      .filter(([, c]) => Number.isFinite(c));
    attach.push({ key, poly: stand[0], cost, reach });
  }

  const walks = spots.map(() => spots.map(() => NO_WAY));
  spots.forEach((s, i) => {
    const a = attach[i];
    if (!a) return;
    const dist = GraphSearch(cross.length, adj, a.reach);
    spots.forEach((t, j) => {
      const b = attach[j];
      if (!b) return;
      let best = i === j ? 0 : Infinity;
      if (b.key === a.key) best = Math.min(best, a.cost[b.poly]);
      for (const [c, extra] of b.reach) best = Math.min(best, dist[c] + extra);
      if (Number.isFinite(best)) walks[i][j] = Math.round(best);
    });
  });

  const blobs = new Map();
  for (const [key, tile] of tiles) {
    const [x, y] = key.split(',').map(Number);
    const b = bounds(x, y);
    const v = [];
    let last = [0, 0, 0];
    for (const [wx, wy, wz] of tile.verts) {
      const q = [Math.round((b.x0 - wx) * Q), Math.round((b.y0 - wy) * Q), Math.round(wz * Q)];
      v.push(q[0] - last[0], q[1] - last[1], q[2] - last[2]);
      last = q;
    }
    const p = [];
    let index = 0;
    for (const poly of tile.polys) {
      if (poly.verts.length > MAX_POLY_VERTS) throw new Error(`tile ${key} has a polygon of ${poly.verts.length} corners`);
      p.push(poly.verts.length);
      for (const i of poly.verts) { p.push(i + 1 - index); index = i + 1; }
    }
    const area = tile.polys.map(p => p.area === AREA_WATER ? 1 : p.area === AREA_OCEAN ? 2 : 0);
    const data = {
      v,
      p,
      l: tile.links.flatMap(([p, k, dx, dy, q]) => [p + 1, k + 1, dx, dy, q + 1]),
      x: (byTile.get(key) || []).flatMap(({ c, poly }) => [c.id + 1, poly + 1]),
    };
    if (area.some(a => a)) data.a = area;
    blobs.set(key, encode(data));
  }
  const graph = encode({
    c: cross.flatMap(c => c.point.map(v => Math.round(v * Q))),
    e: edges.flatMap(([a, b, c]) => [a + 1, b + 1, Math.round(c)]),
  });
  const table = encode({
    k: spots.map(s => s.key),
    d: walks.flat(),
    r: attach.map(a => {
      if (!a) return [];
      const [tx, ty] = a.key.split(',').map(Number);
      return [tx, ty, a.poly + 1, ...a.reach.flatMap(([c, cost]) => [c + 1, Math.round(cost)])];
    }),
  });
  return { tiles, joined, cross, edges, spots, attach, walks, blobs, graph, table };
}

function Size(buf) {
  const z = deflateRawSync(buf, { level: 9 });
  return { raw: buf.length, deflated: z.length, base64: Math.ceil(z.length / 3) * 4 };
}

function Blob(buf) {
  return deflateRawSync(buf, { level: 9 }).toString('base64');
}

function Header(name, what) {
  return [`-- ${name}: ${what}, generated by Tools/nav/pack.mjs.`, 'local ns = _G.NaowhForever', ''];
}

async function Write(map, r) {
  await mkdir(DATA, { recursive: true });
  for (const old of await readdir(DATA)) {
    if (old === `Map${map}.lua` || old.startsWith(`Map${map}_`)) await unlink(join(DATA, old));
  }
  const files = [];
  let lines = null, size = 0;
  const flush = () => { if (lines) files.push(lines); lines = null; size = 0; };
  for (const [key, buf] of [...r.blobs].sort()) {
    if (!lines) lines = ['local T = ns.JourneyData.tiles[' + map + ']'];
    const line = `T["${key.replace(',', '_')}"] = "${Blob(buf)}"`;
    lines.push(line);
    size += line.length;
    if (size > FILE_BYTES) flush();
  }
  flush();
  const names = [];
  for (let i = 0; i < files.length; i++) {
    const name = `Map${map}_${i + 1}.lua`;
    names.push(name);
    await writeFile(join(DATA, name), [...Header(name, `walking tiles of map ${map}, part ${i + 1}`), ...files[i], ''].join(CRLF));
  }
  const graphName = `Map${map}.lua`;
  names.unshift(graphName);
  await writeFile(join(DATA, graphName), [...Header(graphName, `the crossings and the network's walks of map ${map}`),
    `ns.JourneyData.graph[${map}] = "${Blob(r.graph)}"`, `ns.JourneyData.walks[${map}] = "${Blob(r.table)}"`, ''].join(CRLF));
  await WriteXml();
  return names;
}

async function WriteXml() {
  const files = (await readdir(DATA)).filter(f => /^Map\d+(_\d+)?\.lua$/.test(f)).sort();
  const lines = ['<Ui xmlns="http://www.blizzard.com/wow/ui/">',
    '    <!-- JourneysData.xml: the walking maps, generated by Tools/nav/pack.mjs. -->',
    '    <Script file="Data.lua"/>',
    ...files.map(f => `    <Script file="Data\\${f}"/>`), '</Ui>', ''];
  await writeFile(join(DATA, '..', 'JourneysData.xml'), lines.join(CRLF));
}

if (process.argv[1] && process.argv[1].endsWith('pack.mjs')) {
  const map = Number(process.argv[2]);
  const r = await pack(map);
  if (process.argv.includes('--write')) console.log('wrote', (await Write(map, r)).join(', '));
  let total = { raw: 0, deflated: 0, base64: 0 };
  for (const b of r.blobs.values()) { const s = Size(b); for (const k in total) total[k] += s[k]; }
  console.log(`map ${map}: ${r.tiles.size} tiles, ${r.joined} joined edges, ${r.cross.length} crossings, ${r.edges.length} crossing edges`);
  console.log('tiles', total, 'graph', Size(r.graph), 'walks', Size(r.table));
  const reachable = r.walks.flat().filter(v => v >= 0).length;
  console.log(`places ${r.spots.length}, attached ${r.attach.filter(Boolean).length}, walk pairs found ${reachable} of ${r.spots.length ** 2}`);
}

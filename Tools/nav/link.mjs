// Joins baked tiles: an edge a polygon has on its tile's side is matched with the edges of the
// next tile's polygons on the same line that overlap it at about the same height.
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { bounds } from './mesh.mjs';
import { tilePath } from './bake.mjs';

const ON_LINE = 0.05;
const STEP = 2;
const NORTH = 0, SOUTH = 1, WEST = 2, EAST = 3;
const OPPOSITE = [SOUTH, NORTH, EAST, WEST];
const STEPS = [[0, -1], [0, 1], [-1, 0], [1, 0]];

export async function load(map, x, y) {
  const path = tilePath(map, x, y);
  if (!existsSync(path)) return null;
  return JSON.parse(await readFile(path, 'utf8'));
}

// The side of the tile an edge lies on, and its span along that side, or null.
function Side(tile, b, a, c) {
  const p = tile.verts[a], q = tile.verts[c];
  const near = (u, v, line) => Math.abs(u - line) < ON_LINE && Math.abs(v - line) < ON_LINE;
  if (near(p[0], q[0], b.x0)) return { side: NORTH, lo: Math.min(p[1], q[1]), hi: Math.max(p[1], q[1]), z: (p[2] + q[2]) / 2 };
  if (near(p[0], q[0], b.x1)) return { side: SOUTH, lo: Math.min(p[1], q[1]), hi: Math.max(p[1], q[1]), z: (p[2] + q[2]) / 2 };
  if (near(p[1], q[1], b.y0)) return { side: WEST, lo: Math.min(p[0], q[0]), hi: Math.max(p[0], q[0]), z: (p[2] + q[2]) / 2 };
  if (near(p[1], q[1], b.y1)) return { side: EAST, lo: Math.min(p[0], q[0]), hi: Math.max(p[0], q[0]), z: (p[2] + q[2]) / 2 };
  return null;
}

function BorderEdges(tile, tx, ty) {
  const b = bounds(tx, ty);
  const edges = [[], [], [], []];
  tile.polys.forEach((poly, p) => {
    poly.neighbours.forEach((n, k) => {
      if (n > -2) return;
      const s = Side(tile, b, poly.verts[k], poly.verts[(k + 1) % poly.verts.length]);
      if (s) edges[s.side].push({ poly: p, edge: k, ...s });
    });
  });
  return edges;
}

// Adds tile.links = [[poly, edge, dx, dy, otherPoly], ...] to every tile of the map in tiles (a Map
// of "x,y" to tile) and returns how many edges were joined.
export function linkAll(tiles) {
  const borders = new Map();
  for (const [key, tile] of tiles) {
    const [x, y] = key.split(',').map(Number);
    borders.set(key, BorderEdges(tile, x, y));
    tile.links = [];
  }
  let joined = 0;
  for (const [key, tile] of tiles) {
    const [x, y] = key.split(',').map(Number);
    const mine = borders.get(key);
    for (let side = 0; side < 4; side++) {
      const [dx, dy] = STEPS[side];
      const theirs = borders.get(`${x + dx},${y + dy}`);
      if (!theirs) continue;
      for (const e of mine[side]) {
        for (const f of theirs[OPPOSITE[side]]) {
          if (Math.min(e.hi, f.hi) - Math.max(e.lo, f.lo) <= 0 || Math.abs(e.z - f.z) > STEP) continue;
          tile.links.push([e.poly, e.edge, dx, dy, f.poly]);
          joined++;
        }
      }
    }
  }
  return joined;
}

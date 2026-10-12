// Everything solid around one map tile, in world yards: its terrain and its neighbours' near edge,
// the WMOs and doodads standing there, and its liquids. Neighbours matter because the walkable
// area is shrunk away from walls, and a wall just over the edge still counts.
import { file } from './casc.mjs';
import { TILE, terrain, objects, water } from './adt.mjs';
import { wmo } from './wmo.mjs';
import { m2 } from './m2.mjs';
import { placer } from './place.mjs';

const ORIGIN = 32 * TILE;

// The tile's world box: x from x1 up to x0 (north edge), y from y1 up to y0 (west edge).
export function bounds(tx, ty, margin = 0) {
  const x0 = ORIGIN - ty * TILE + margin, y0 = ORIGIN - tx * TILE + margin;
  return { x0, y0, x1: x0 - TILE - 2 * margin, y1: y0 - TILE - 2 * margin };
}

function Inside(b, x, y) {
  return x <= b.x0 && x >= b.x1 && y <= b.y0 && y >= b.y1;
}

function Add(out, verts, tris, map, box) {
  const base = out.verts.length / 3;
  const keep = new Array(verts.length / 3);
  for (let i = 0; i < verts.length; i += 3) {
    const [x, y, z] = map ? map(verts[i], verts[i + 1], verts[i + 2]) : [verts[i], verts[i + 1], verts[i + 2]];
    out.verts.push(x, y, z);
    keep[i / 3] = Inside(box, x, y);
  }
  for (let t = 0; t < tris.length; t += 3) {
    const a = tris[t], b = tris[t + 1], c = tris[t + 2];
    if (!keep[a] && !keep[b] && !keep[c]) continue;
    out.tris.push(base + a, base + b, base + c);
  }
}

// { verts, tris, water } for tile (tx, ty) of a map's tile list, with margin yards of its neighbours.
export async function gather(list, tx, ty, margin) {
  const box = bounds(tx, ty, margin);
  const out = { verts: [], tris: [], water: [] };
  const seen = new Set();
  for (const t of list) {
    if (Math.abs(t.x - tx) > 1 || Math.abs(t.y - ty) > 1) continue;
    const root = await file(t.root);
    if (!root) continue;
    const ground = terrain(root);
    Add(out, ground.verts, ground.tris, null, box);
    for (const w of water(root, t.x, t.y)) out.water.push(w);
    const obj = t.obj0 && await file(t.obj0);
    if (!obj) continue;
    const { doodads, wmos } = objects(obj);
    for (const w of wmos) {
      if (seen.has('w' + w.uid)) continue;
      seen.add('w' + w.uid);
      const model = await wmo(w.fdid);
      if (!model) continue;
      const map = placer(w);
      for (const g of model.groups) Add(out, g.verts, g.tris, map, box);
    }
    for (const d of doodads) {
      if (seen.has('d' + d.uid)) continue;
      seen.add('d' + d.uid);
      const model = await m2(d.fdid);
      if (model) Add(out, model.verts, model.tris, placer(d), box);
    }
  }
  return out;
}

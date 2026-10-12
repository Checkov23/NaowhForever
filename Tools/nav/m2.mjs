// An M2 doodad's collision mesh (trees, fences, rocks): the triangles its header lists for collision,
// in the model's own space, z up. Most small props have none and block nothing.
import { file, chunks } from './casc.mjs';

const COLLISION_INDICES = 216;
const COLLISION_POSITIONS = 224;
const cache = new Map();

function Array32(buf, base, at) {
  return { count: buf.readUInt32LE(base + at), offset: buf.readUInt32LE(base + at + 4) };
}

// { verts: [x, y, z, ...], tris: [a, b, c, ...] }, or null when it has no collision or no file.
export async function m2(fdid) {
  if (cache.has(fdid)) return cache.get(fdid);
  const buf = await file(fdid);
  let model = null;
  const md21 = buf && chunks(buf).find(c => c.id === 'MD21');
  if (md21) {
    const base = md21.start;
    const idx = Array32(buf, base, COLLISION_INDICES), pos = Array32(buf, base, COLLISION_POSITIONS);
    if (idx.count >= 3 && pos.count) {
      const verts = [], tris = [];
      for (let k = 0; k < pos.count * 3; k++) verts.push(buf.readFloatLE(base + pos.offset + k * 4));
      for (let k = 0; k < idx.count; k++) tris.push(buf.readUInt16LE(base + idx.offset + k * 2));
      model = { verts, tris };
    }
  }
  cache.set(fdid, model);
  return model;
}

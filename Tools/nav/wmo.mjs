// A WMO's collision: its root names the group files, each group holds triangles with a flags byte
// that says which ones block movement. Positions are the model's own, z up. Newer groups keep the
// flags four bytes a triangle (MPY2 for MOPY) and may index with 32 bits (MOVX for MOVI).
import { file, chunks } from './casc.mjs';

const RENDER = 0x20, DETAIL = 0x04, COLLISION = 0x08;
const MOGP_HEADER = 68;
const cache = new Map();

function Collides(flags) {
  return (flags & COLLISION) !== 0 || ((flags & RENDER) !== 0 && (flags & DETAIL) === 0);
}

function Group(buf) {
  const mogp = chunks(buf).find(c => c.id === 'MOGP');
  if (!mogp) return null;
  const sub = chunks(buf, mogp.start + MOGP_HEADER, mogp.start + mogp.size);
  const get = id => sub.find(c => c.id === id);
  const flags = get('MOPY') ?? get('MPY2'), movt = get('MOVT');
  const movi = get('MOVI') ?? get('MOVX');
  if (!flags || !movi || !movt) return null;
  const flagStride = flags.id === 'MPY2' ? 4 : 2;
  const wide = movi.id === 'MOVX';
  const index = wide ? i => buf.readUInt32LE(movi.start + i * 4) : i => buf.readUInt16LE(movi.start + i * 2);
  const verts = [];
  for (let at = movt.start; at < movt.start + movt.size; at += 4) verts.push(buf.readFloatLE(at));
  const tris = [];
  const count = movi.size / (wide ? 12 : 6);
  for (let t = 0; t < count; t++) {
    if (!Collides(buf[flags.start + t * flagStride])) continue;
    tris.push(index(t * 3), index(t * 3 + 1), index(t * 3 + 2));
  }
  return { verts, tris };
}

// { lo: [x, y, z], hi: [x, y, z], groups: [{ verts, tris }] }, or null when the file is missing.
export async function wmo(fdid) {
  if (cache.has(fdid)) return cache.get(fdid);
  const root = await file(fdid);
  let model = null;
  if (root) {
    const list = chunks(root);
    const mohd = list.find(c => c.id === 'MOHD');
    const gfid = list.find(c => c.id === 'GFID');
    const box = [];
    for (let k = 0; k < 6; k++) box.push(root.readFloatLE(mohd.start + 36 + k * 4));
    model = { lo: box.slice(0, 3), hi: box.slice(3), groups: [] };
    const count = gfid ? Math.min(root.readUInt32LE(mohd.start + 4), gfid.size / 4) : 0;
    for (let at = gfid ? gfid.start : 0; at < (gfid ? gfid.start + count * 4 : 0); at += 4) {
      const id = root.readUInt32LE(at);
      const buf = id && await file(id);
      const group = buf && Group(buf);
      if (group && group.tris.length) model.groups.push(group);
    }
  }
  cache.set(fdid, model);
  return model;
}

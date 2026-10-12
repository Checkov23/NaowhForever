// A map tile's terrain (its root file) and what stands on it (its obj0 file), in world yards:
// x north, y west, z up, as the game's tables and UnitPosition give them.
import { chunks } from './casc.mjs';

export const TILE = 1600 / 3;
export const CHUNK = TILE / 16;
const UNIT = CHUNK / 8;
const HIGH_RES_HOLES = 0x10000;
const MDDF_FILE_ID = 0x40;
const MODF_FILE_ID = 0x8;
const ORIGIN = 32 * TILE;

// The tile's file IDs from its map's WDT: { root, obj0 } for each tile index y * 64 + x.
export function tiles(wdt) {
  const maid = chunks(wdt).find(c => c.id === 'MAID');
  const list = [];
  for (let i = 0; i < 4096; i++) {
    const root = wdt.readUInt32LE(maid.start + i * 32);
    if (root) list.push({ x: i % 64, y: Math.floor(i / 64), root, obj0: wdt.readUInt32LE(maid.start + i * 32 + 4) });
  }
  return list;
}

// Whether quad (row, col) of a chunk, 0 to 7, is a hole.
function Hole(buf, h, flags, row, col) {
  if (flags & HIGH_RES_HOLES) return (buf[h + 20 + row] >> col) & 1;
  const low = buf.readUInt16LE(h + 60);
  return (low >> ((row >> 1) * 4 + (col >> 1))) & 1;
}

// The terrain as triangles: { verts: [x, y, z, ...], tris: [a, b, c, ...] }.
export function terrain(root) {
  const verts = [], tris = [];
  for (const mcnk of chunks(root).filter(c => c.id === 'MCNK')) {
    const h = mcnk.start;
    const flags = root.readUInt32LE(h);
    const px = root.readFloatLE(h + 104), py = root.readFloatLE(h + 108), pz = root.readFloatLE(h + 112);
    const mcvt = chunks(root, h + 128, h + mcnk.size).find(c => c.id === 'MCVT');
    if (!mcvt) continue;
    const base = verts.length / 3;
    for (let k = 0; k < 145; k++) {
      const row = Math.floor(k / 17), rest = k % 17;
      const inner = rest >= 9;
      const i = inner ? row + 0.5 : row, j = inner ? rest - 9 + 0.5 : rest;
      verts.push(px - i * UNIT, py - j * UNIT, pz + root.readFloatLE(mcvt.start + k * 4));
    }
    for (let row = 0; row < 8; row++) {
      for (let col = 0; col < 8; col++) {
        if (Hole(root, h, flags, row, col)) continue;
        const tl = base + row * 17 + col, tr = tl + 1, bl = tl + 17, br = bl + 1, c = tl + 9;
        tris.push(c, tr, tl, c, br, tr, c, bl, br, c, tl, bl);
      }
    }
  }
  return { verts, tris };
}

// The tile's liquids as boxes over its terrain: [{ x0, y0, x1, y1, level, type }], x0 > x1 and
// y0 > y1 (world x and y fall across a tile). type is the LiquidType ID; level is the surface's top.
export function water(root, tileX, tileY) {
  const mh2o = chunks(root).find(c => c.id === 'MH2O');
  const list = [];
  if (!mh2o) return list;
  const base = mh2o.start;
  const top = ORIGIN - tileY * TILE, left = ORIGIN - tileX * TILE;
  for (let i = 0; i < 256; i++) {
    const head = base + i * 12;
    const ofs = root.readUInt32LE(head), layers = root.readUInt32LE(head + 4);
    const cx = i % 16, cy = Math.floor(i / 16);
    for (let l = 0; l < layers; l++) {
      const at = base + ofs + l * 24;
      const type = root.readUInt16LE(at);
      const level = root.readFloatLE(at + 8);
      const ox = root[at + 12], oy = root[at + 13], w = root[at + 14], h = root[at + 15];
      const x0 = top - cy * CHUNK - oy * UNIT, y0 = left - cx * CHUNK - ox * UNIT;
      list.push({ x0, y0, x1: x0 - h * UNIT, y1: y0 - w * UNIT, level, type });
    }
  }
  return list;
}

function Placement(buf, at) {
  return {
    x: ORIGIN - buf.readFloatLE(at + 8), y: ORIGIN - buf.readFloatLE(at), z: buf.readFloatLE(at + 4),
  };
}

// What stands on the tile: { doodads: [{ fdid, pos, rot, scale, uid }], wmos: [{ fdid, pos, rot, scale, uid, set }] }.
export function objects(obj0) {
  const doodads = [], wmos = [];
  for (const c of chunks(obj0)) {
    if (c.id === 'MDDF') {
      for (let at = c.start; at + 36 <= c.start + c.size; at += 36) {
        const flags = obj0.readUInt16LE(at + 34);
        if (!(flags & MDDF_FILE_ID)) continue;
        doodads.push({ fdid: obj0.readUInt32LE(at), uid: obj0.readUInt32LE(at + 4), pos: Placement(obj0, at + 8),
          rot: [obj0.readFloatLE(at + 20), obj0.readFloatLE(at + 24), obj0.readFloatLE(at + 28)],
          scale: obj0.readUInt16LE(at + 32) / 1024 });
      }
    } else if (c.id === 'MODF') {
      for (let at = c.start; at + 64 <= c.start + c.size; at += 64) {
        const flags = obj0.readUInt16LE(at + 56);
        if (!(flags & MODF_FILE_ID)) continue;
        wmos.push({ fdid: obj0.readUInt32LE(at), uid: obj0.readUInt32LE(at + 4), pos: Placement(obj0, at + 8),
          rot: [obj0.readFloatLE(at + 20), obj0.readFloatLE(at + 24), obj0.readFloatLE(at + 28)],
          lo: Placement(obj0, at + 32), hi: Placement(obj0, at + 44),
          set: obj0.readUInt16LE(at + 58), scale: obj0.readUInt16LE(at + 62) / 1024 || 1 });
      }
    }
  }
  return { doodads, wmos };
}

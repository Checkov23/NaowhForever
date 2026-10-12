// A map tile's minimap picture from the client (BLP2, DXT1), as RGB, to check a bake against.
import { file, chunks } from './casc.mjs';

const MINIMAP = 7;

function Color(c) {
  return [((c >> 11) & 31) * 255 / 31, ((c >> 5) & 63) * 255 / 63, (c & 31) * 255 / 31];
}

function Dxt1(buf, at, w, h) {
  const out = new Uint8Array(w * h * 3);
  for (let by = 0; by < h / 4; by++) for (let bx = 0; bx < w / 4; bx++) {
    const c0 = buf.readUInt16LE(at), c1 = buf.readUInt16LE(at + 2), bits = buf.readUInt32LE(at + 4);
    at += 8;
    const a = Color(c0), b = Color(c1);
    const pal = c0 > c1
      ? [a, b, a.map((v, i) => (2 * v + b[i]) / 3), a.map((v, i) => (v + 2 * b[i]) / 3)]
      : [a, b, a.map((v, i) => (v + b[i]) / 2), [0, 0, 0]];
    for (let k = 0; k < 16; k++) {
      const p = pal[(bits >> (2 * k)) & 3];
      const x = bx * 4 + (k & 3), y = by * 4 + (k >> 2);
      out.set(p.map(Math.round), (y * w + x) * 3);
    }
  }
  return out;
}

// { w, h, rgb } or null.
export async function minimap(wdtId, tx, ty) {
  const wdt = await file(wdtId);
  const maid = chunks(wdt).find(c => c.id === 'MAID');
  const id = wdt.readUInt32LE(maid.start + (ty * 64 + tx) * 32 + MINIMAP * 4);
  const blp = id && await file(id);
  if (!blp || blp[8] !== 2 || blp[9] !== 0) return null;
  const w = blp.readUInt32LE(12), h = blp.readUInt32LE(16);
  return { w, h, rgb: Dxt1(blp, blp.readUInt32LE(20), w, h) };
}

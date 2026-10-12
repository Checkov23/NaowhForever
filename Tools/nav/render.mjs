// Draws a baked tile from above as a PNG, to check a bake by eye: ground green, lakes blue, sea navy, walls
// black, tile edges red.
import { writeFile } from 'node:fs/promises';
import { deflateSync, crc32 } from 'node:zlib';
import { bounds } from './mesh.mjs';
import { AREA_WATER, AREA_OCEAN } from './tile.mjs';

const SIZE = 1024;
const GROUND = [70, 150, 70], WATER = [60, 110, 200], OCEAN = [30, 50, 120], WALL = [0, 0, 0], EDGE = [220, 40, 40], BG = [235, 235, 235];

function Png(width, height, rgb) {
  const raw = Buffer.alloc((width * 3 + 1) * height);
  for (let y = 0; y < height; y++) rgb.copy(raw, y * (width * 3 + 1) + 1, y * width * 3, (y + 1) * width * 3);
  const chunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type), data]);
    const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body) >>> 0);
    return Buffer.concat([len, body, crc]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4); ihdr[8] = 8; ihdr[9] = 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}

export async function render(tile, tx, ty, path, marks = [], under = null) {
  const b = bounds(tx, ty);
  const px = new Uint8Array(SIZE * SIZE * 3);
  for (let i = 0; i < SIZE * SIZE; i++) px.set(BG, i * 3);
  if (under) {
    for (let v = 0; v < SIZE; v++) for (let u = 0; u < SIZE; u++) {
      const at = (Math.floor(v * under.h / SIZE) * under.w + Math.floor(u * under.w / SIZE)) * 3;
      px.set(under.rgb.subarray(at, at + 3), (v * SIZE + u) * 3);
    }
  }
  const toPx = (x, y) => [(b.y0 - y) / (b.y0 - b.y1) * SIZE, (b.x0 - x) / (b.x0 - b.x1) * SIZE];
  const set = (u, v, c) => { if (u >= 0 && v >= 0 && u < SIZE && v < SIZE) px.set(c, (v * SIZE + u) * 3); };
  for (const poly of tile.polys) {
    const pts = poly.verts.map(i => toPx(tile.verts[i][0], tile.verts[i][1]));
    const color = poly.area === AREA_WATER ? WATER : poly.area === AREA_OCEAN ? OCEAN : GROUND;
    const tint = under ? (u, v) => { const at = (v * SIZE + u) * 3; px.set(px.subarray(at, at + 3).map((c, i) => (c + color[i]) / 2), at); } : null;
    let minV = Infinity, maxV = -Infinity;
    for (const p of pts) { minV = Math.min(minV, p[1]); maxV = Math.max(maxV, p[1]); }
    for (let v = Math.max(0, Math.floor(minV)); v <= Math.min(SIZE - 1, Math.ceil(maxV)); v++) {
      const xs = [];
      for (let k = 0; k < pts.length; k++) {
        const a = pts[k], c = pts[(k + 1) % pts.length];
        if ((a[1] <= v && c[1] > v) || (c[1] <= v && a[1] > v)) xs.push(a[0] + (v - a[1]) / (c[1] - a[1]) * (c[0] - a[0]));
      }
      xs.sort((p, q) => p - q);
      for (let k = 0; k + 1 < xs.length; k += 2) {
        for (let u = Math.max(0, Math.ceil(xs[k])); u <= Math.min(SIZE - 1, xs[k + 1]); u++) {
          if (tint) tint(u, v); else set(u, v, color);
        }
      }
    }
    for (let k = 0; k < pts.length; k++) {
      const a = pts[k], c = pts[(k + 1) % pts.length];
      const n = poly.neighbours[k];
      if (n === -1 || n <= -2) {
        const steps = Math.ceil(Math.hypot(c[0] - a[0], c[1] - a[1]));
        for (let s = 0; s <= steps; s++) {
          set(Math.round(a[0] + (c[0] - a[0]) * s / steps), Math.round(a[1] + (c[1] - a[1]) * s / steps), n === -1 ? WALL : EDGE);
        }
      }
    }
  }
  for (const [x, y] of marks) {
    const [u, v] = toPx(x, y);
    for (let du = -4; du <= 4; du++) for (let dv = -4; dv <= 4; dv++) set(Math.round(u) + du, Math.round(v) + dv, EDGE);
  }
  await writeFile(path, Png(SIZE, SIZE, Buffer.from(px)));
}

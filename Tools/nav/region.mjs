// Draws the tiles around a spot over the game's minimap: polygons reachable from the spot green, the
// rest grey, the spot red. For finding where a bake cuts a walk.
//   node region.mjs <map> <x> <y> <tiles across> <out.png>
import { writeFile } from 'node:fs/promises';
import { deflateSync, crc32 } from 'node:zlib';
import { load, linkAll } from './link.mjs';
import { standOn } from './pack.mjs';
import { minimap } from './minimap.mjs';
import { bounds } from './mesh.mjs';
import { WDT } from './bake.mjs';

const PX = 384;
const TILE = 1600 / 3, ORIGIN = 32 * TILE;

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

const [mapArg, xArg, yArg, nArg, out] = process.argv.slice(2);
const map = Number(mapArg), x = Number(xArg), y = Number(yArg), n = Number(nArg);
const cx = Math.floor((ORIGIN - y) / TILE), cy = Math.floor((ORIGIN - x) / TILE);
const half = Math.floor(n / 2);
const tiles = new Map();
for (let tx = cx - half - 1; tx <= cx + half + 1; tx++) for (let ty = cy - half - 1; ty <= cy + half + 1; ty++) {
  const t = await load(map, tx, ty);
  if (t && t.polys.length) tiles.set(`${tx},${ty}`, t);
}
linkAll(tiles);
const reach = new Set();
const startKey = `${cx},${cy}`;
const [p0] = standOn(tiles.get(startKey), x, y, null);
const queue = [[startKey, p0]];
reach.add(`${startKey}:${p0}`);
while (queue.length) {
  const [key, p] = queue.pop();
  const tile = tiles.get(key);
  const [tx, ty] = key.split(',').map(Number);
  const next = tile.polys[p].neighbours.filter(q => q >= 0).map(q => [key, q]);
  for (const [lp, , dx, dy, q] of tile.links) if (lp === p) next.push([`${tx + dx},${ty + dy}`, q]);
  for (const [k, q] of next) if (tiles.has(k) && !reach.has(`${k}:${q}`)) { reach.add(`${k}:${q}`); queue.push([k, q]); }
}

const W = n * PX, H = n * PX;
const px = Buffer.alloc(W * H * 3, 0);
for (let ix = 0; ix < n; ix++) for (let iy = 0; iy < n; iy++) {
  const tx = cx - half + ix, ty = cy - half + iy;
  const pic = await minimap(WDT[map], tx, ty);
  if (pic) {
    for (let v = 0; v < PX; v++) for (let u = 0; u < PX; u++) {
      const at = (Math.floor(v * pic.h / PX) * pic.w + Math.floor(u * pic.w / PX)) * 3;
      px.set(pic.rgb.subarray(at, at + 3), ((iy * PX + v) * W + ix * PX + u) * 3);
    }
  }
  const tile = tiles.get(`${tx},${ty}`);
  if (!tile) continue;
  const b = bounds(tx, ty);
  tile.polys.forEach((poly, p) => {
    const color = reach.has(`${tx},${ty}:${p}`) ? [40, 220, 40] : [160, 160, 160];
    const pts = poly.verts.map(i => [ix * PX + (b.y0 - tile.verts[i][1]) / TILE * PX, iy * PX + (b.x0 - tile.verts[i][0]) / TILE * PX]);
    const minV = Math.floor(Math.min(...pts.map(q => q[1]))), maxV = Math.ceil(Math.max(...pts.map(q => q[1])));
    for (let v = minV; v <= maxV; v++) {
      const xs = [];
      for (let k = 0; k < pts.length; k++) {
        const a = pts[k], c = pts[(k + 1) % pts.length];
        if ((a[1] <= v && c[1] > v) || (c[1] <= v && a[1] > v)) xs.push(a[0] + (v - a[1]) / (c[1] - a[1]) * (c[0] - a[0]));
      }
      xs.sort((m, q) => m - q);
      for (let k = 0; k + 1 < xs.length; k += 2) {
        for (let u = Math.ceil(xs[k]); u <= xs[k + 1]; u++) {
          if (u < 0 || v < 0 || u >= W || v >= H) continue;
          const at = (v * W + u) * 3;
          px.set(px.subarray(at, at + 3).map((c, i) => (c + color[i]) / 2), at);
        }
      }
    }
  });
}
const su = Math.round(((ORIGIN - y) / TILE - (cx - half)) * PX), sv = Math.round(((ORIGIN - x) / TILE - (cy - half)) * PX);
for (let du = -5; du <= 5; du++) for (let dv = -5; dv <= 5; dv++) {
  const u = su + du, v = sv + dv;
  if (u >= 0 && v >= 0 && u < W && v < H) px.set([255, 0, 0], (v * W + u) * 3);
}
await writeFile(out, Png(W, H, px));
console.log(`reachable ${reach.size} polys`);

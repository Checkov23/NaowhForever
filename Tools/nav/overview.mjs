// Draws a whole baked map from above, polygons reachable from a spot in green and the rest grey, with
// spots marked: to check a map's connections by eye.
//   node overview.mjs <map> <out.png> x,y [x,y ...]
import { writeFile } from 'node:fs/promises';
import { deflateSync, crc32 } from 'node:zlib';
import { pack, standOn } from './pack.mjs';
import { bounds } from './mesh.mjs';

const PX = 96;

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

const [mapArg, out, ...spotArgs] = process.argv.slice(2);
const map = Number(mapArg);
const spots = spotArgs.map(s => s.split(',').map(Number));
const r = await pack(map);
const keys = [...r.tiles.keys()].map(k => k.split(',').map(Number));
const minX = Math.min(...keys.map(k => k[0])), maxX = Math.max(...keys.map(k => k[0]));
const minY = Math.min(...keys.map(k => k[1])), maxY = Math.max(...keys.map(k => k[1]));
const W = (maxX - minX + 1) * PX, H = (maxY - minY + 1) * PX;
const px = Buffer.alloc(W * H * 3, 235);

const reach = new Set();
const [sx, sy] = spots[0];
const TILE = 1600 / 3, ORIGIN = 32 * TILE;
const startKey = `${Math.floor((ORIGIN - sy) / TILE)},${Math.floor((ORIGIN - sx) / TILE)}`;
const stand = standOn(r.tiles.get(startKey), sx, sy, null);
const queue = [[startKey, stand[0]]];
reach.add(`${startKey}:${stand[0]}`);
while (queue.length) {
  const [key, p] = queue.pop();
  const tile = r.tiles.get(key);
  const [x, y] = key.split(',').map(Number);
  const next = tile.polys[p].neighbours.filter(n => n >= 0).map(n => [key, n]);
  for (const [lp, , dx, dy, q] of tile.links) if (lp === p) next.push([`${x + dx},${y + dy}`, q]);
  for (const [k, q] of next) if (r.tiles.has(k) && !reach.has(`${k}:${q}`)) { reach.add(`${k}:${q}`); queue.push([k, q]); }
}

for (const [key, tile] of r.tiles) {
  const [tx, ty] = key.split(',').map(Number);
  const b = bounds(tx, ty);
  const ox = (tx - minX) * PX, oy = (ty - minY) * PX;
  tile.polys.forEach((poly, p) => {
    const color = reach.has(`${key}:${p}`) ? [60, 160, 60] : poly.area ? [80, 110, 190] : [150, 150, 150];
    const pts = poly.verts.map(i => [ox + (b.y0 - tile.verts[i][1]) / TILE * PX, oy + (b.x0 - tile.verts[i][0]) / TILE * PX]);
    const minV = Math.floor(Math.min(...pts.map(q => q[1]))), maxV = Math.ceil(Math.max(...pts.map(q => q[1])));
    for (let v = minV; v <= maxV; v++) {
      const xs = [];
      for (let k = 0; k < pts.length; k++) {
        const a = pts[k], c = pts[(k + 1) % pts.length];
        if ((a[1] <= v && c[1] > v) || (c[1] <= v && a[1] > v)) xs.push(a[0] + (v - a[1]) / (c[1] - a[1]) * (c[0] - a[0]));
      }
      xs.sort((m, n) => m - n);
      for (let k = 0; k + 1 < xs.length; k += 2) {
        for (let u = Math.ceil(xs[k]); u <= xs[k + 1]; u++) if (u >= 0 && v >= 0 && u < W && v < H) px.set(color, (v * W + u) * 3);
      }
    }
  });
}
for (const [x, y] of spots) {
  const u = Math.round((ORIGIN - y) / TILE * PX - minX * PX), v = Math.round((ORIGIN - x) / TILE * PX - minY * PX);
  for (let du = -3; du <= 3; du++) for (let dv = -3; dv <= 3; dv++) {
    const uu = u + du, vv = v + dv;
    if (uu >= 0 && vv >= 0 && uu < W && vv < H) px.set([220, 30, 30], (vv * W + uu) * 3);
  }
}
await writeFile(out, Png(W, H, px));
console.log(`reachable ${reach.size} polys, image ${W}x${H}`);

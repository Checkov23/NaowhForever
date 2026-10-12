// The walking graph built from linked tiles: crossings (where paths pass from one tile to the next)
// and the walking cost between the crossings of each tile. Costs are yards, dearer in water.
import { AREA_WATER, AREA_OCEAN } from './tile.mjs';
import { bounds } from './mesh.mjs';

export const SWIM = 1.6;
export const SEA = 2.5;
const GAP = 2;
const SAME_LEVEL = 2;

function Factor(area) {
  return area === AREA_WATER ? SWIM : area === AREA_OCEAN ? SEA : 1;
}

export function centroid(tile, poly) {
  let x = 0, y = 0, z = 0;
  for (const i of poly.verts) { x += tile.verts[i][0]; y += tile.verts[i][1]; z += tile.verts[i][2]; }
  const n = poly.verts.length;
  return [x / n, y / n, z / n];
}

function Dist(a, b) {
  return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
}

// Each tile's neighbour lists with costs: adjacency[p] = [[q, cost], ...], from centroid to the shared
// edge's middle to the next centroid, each half at its own polygon's rate.
export function adjacency(tile) {
  const mids = tile.polys.map(p => centroid(tile, p));
  return tile.polys.map((poly, p) => {
    const list = [];
    poly.neighbours.forEach((q, k) => {
      if (q < 0) return;
      const a = tile.verts[poly.verts[k]], b = tile.verts[poly.verts[(k + 1) % poly.verts.length]];
      const mid = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2];
      list.push([q, Dist(mids[p], mid) * Factor(poly.area) + Dist(mid, mids[q]) * Factor(tile.polys[q].area)]);
    });
    return list;
  });
}

// Dijkstra over one tile's polygons from several seeds [[poly, cost]]: cost to every polygon reached.
export function spread(adj, seeds) {
  const cost = new Float64Array(adj.length).fill(Infinity);
  const heap = [];
  const push = (p, c) => {
    heap.push([c, p]);
    let i = heap.length - 1;
    while (i > 0) {
      const up = (i - 1) >> 1;
      if (heap[up][0] <= heap[i][0]) break;
      [heap[up], heap[i]] = [heap[i], heap[up]];
      i = up;
    }
  };
  const pop = () => {
    const top = heap[0], last = heap.pop();
    if (heap.length) {
      heap[0] = last;
      let i = 0;
      for (;;) {
        const l = 2 * i + 1, r = l + 1;
        let m = i;
        if (l < heap.length && heap[l][0] < heap[m][0]) m = l;
        if (r < heap.length && heap[r][0] < heap[m][0]) m = r;
        if (m === i) break;
        [heap[m], heap[i]] = [heap[i], heap[m]];
        i = m;
      }
    }
    return top;
  };
  for (const [p, c] of seeds) if (c < cost[p]) { cost[p] = c; push(p, c); }
  while (heap.length) {
    const [c, p] = pop();
    if (c > cost[p]) continue;
    for (const [q, w] of adj[p]) {
      if (c + w < cost[q]) { cost[q] = c + w; push(q, c + w); }
    }
  }
  return cost;
}

// The crossings between tiles: [{ id, point: [x, y, z], ends: [[key, poly], [key, poly]] }]. Each is a run
// of linked edges along one tile side, made once from the tile on its north or west.
export function crossings(tiles) {
  const list = [];
  for (const [key, tile] of tiles) {
    const [x, y] = key.split(',').map(Number);
    const b = bounds(x, y);
    for (const [dx, dy] of [[1, 0], [0, 1]]) {
      const other = `${x + dx},${y + dy}`;
      if (!tiles.has(other)) continue;
      const edges = tile.links.filter(l => l[2] === dx && l[3] === dy).map(([p, k, , , q]) => {
        const poly = tile.polys[p];
        const a = tile.verts[poly.verts[k]], c = tile.verts[poly.verts[(k + 1) % poly.verts.length]];
        const along = dx ? [a[0], c[0]] : [a[1], c[1]];
        return { p, q, lo: Math.min(...along), hi: Math.max(...along), z: (a[2] + c[2]) / 2 };
      }).sort((e, f) => e.lo - f.lo);
      let run = [];
      const flush = () => {
        if (!run.length) return;
        const lo = run[0].lo, hi = Math.max(...run.map(e => e.hi)), middle = (lo + hi) / 2;
        const pick = run.reduce((best, e) => Math.abs((e.lo + e.hi) / 2 - middle) < Math.abs((best.lo + best.hi) / 2 - middle) ? e : best);
        const point = dx ? [middle, b.y1, pick.z] : [b.x1, middle, pick.z];
        list.push({ id: list.length, point, ends: [[key, pick.p], [other, pick.q]] });
        run = [];
      };
      for (const e of edges) {
        const last = run[run.length - 1];
        if (last && (e.lo > Math.max(...run.map(r => r.hi)) + GAP || Math.abs(e.z - last.z) > SAME_LEVEL)) flush();
        run.push(e);
      }
      flush();
    }
  }
  return list;
}

// The cost between every two crossings of each tile: [[a, b, cost], ...] with a < b, by crossing id.
export function tileCosts(tiles, list) {
  const byTile = new Map();
  for (const c of list) for (const [key, poly] of c.ends) {
    if (!byTile.has(key)) byTile.set(key, []);
    byTile.get(key).push({ c, poly });
  }
  const edges = [];
  for (const [key, here] of byTile) {
    const tile = tiles.get(key);
    const adj = adjacency(tile);
    const mids = tile.polys.map(p => centroid(tile, p));
    for (let i = 0; i < here.length; i++) {
      const from = here[i];
      const cost = spread(adj, [[from.poly, Dist(from.c.point, mids[from.poly])]]);
      for (let j = i + 1; j < here.length; j++) {
        const to = here[j];
        const total = cost[to.poly] + Dist(mids[to.poly], to.c.point);
        if (Number.isFinite(total)) edges.push([Math.min(from.c.id, to.c.id), Math.max(from.c.id, to.c.id), total]);
      }
    }
  }
  return { edges, byTile };
}

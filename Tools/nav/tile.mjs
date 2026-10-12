// Builds one map tile's walkable polygons with Recast, from the geometry mesh.mjs gathers.
// Recast is y up; the world is x north, y west, z up. (east, up, south) = (-y, z, -x) is a rotation,
// so the triangles keep their winding and floors still face up.
import {
  init, Recast, RecastBuildContext, FloatArray, IntArray, UnsignedCharArray, RecastPolyMesh,
  createRcConfig, allocHeightfield, freeHeightfield, createHeightfield, markWalkableTriangles, rasterizeTriangles,
  filterLowHangingWalkableObstacles, filterLedgeSpans, filterWalkableLowHeightSpans,
  allocCompactHeightfield, freeCompactHeightfield, buildCompactHeightfield, erodeWalkableArea, markBoxArea,
  buildDistanceField, buildRegions, allocContourSet, freeContourSet, buildContours, allocPolyMesh, freePolyMesh,
  buildPolyMesh, calcGridSize,
} from '@recast-navigation/core';
import { bounds } from './mesh.mjs';

// A tile is 533 cells across exactly, so both sides of a tile edge fall on the same line.
export const CELL = 1600 / 3 / 533;
export const CELL_HEIGHT = 0.25;
export const AREA_GROUND = 63;
export const AREA_WATER = 1;
export const AREA_OCEAN = 2;
const AREA_NONE = 0;
const AGENT_HEIGHT = 2, AGENT_CLIMB = 1.5, AGENT_RADIUS = 0.6;
const SLOPE = 50;
const SWIM_DEPTH = 1.5;
const DEEP = 1000;
const BORDER = Math.ceil(AGENT_RADIUS / CELL) + 3;
export const MARGIN = BORDER * CELL + 2;

let ready = false;

function Rc(x, y, z) { return [-y, z, -x]; }

function Config() {
  return createRcConfig({
    cs: CELL, ch: CELL_HEIGHT, walkableSlopeAngle: SLOPE,
    walkableHeight: Math.ceil(AGENT_HEIGHT / CELL_HEIGHT), walkableClimb: Math.floor(AGENT_CLIMB / CELL_HEIGHT),
    walkableRadius: Math.ceil(AGENT_RADIUS / CELL), maxEdgeLen: 40, maxSimplificationError: 3,
    minRegionArea: 64, mergeRegionArea: 400, maxVertsPerPoly: 6, borderSize: BORDER,
    detailSampleDist: 6, detailSampleMaxError: 1,
  });
}

function MarkWater(ctx, chf, list, liquids) {
  for (const w of list) {
    const area = liquids.get(w.type) ?? AREA_NONE;
    const a = Rc(w.x0, w.y0, w.level - DEEP), b = Rc(w.x1, w.y1, w.level - SWIM_DEPTH);
    markBoxArea(ctx, [Math.min(a[0], b[0]), a[1], Math.min(a[2], b[2])],
      [Math.max(a[0], b[0]), b[1], Math.max(a[2], b[2])], area, chf);
  }
}

// The area each LiquidType ID makes of the ground under it: lakes and rivers swim, the sea swims
// dearer, lava and slime block. Forever's own ocean is filed with water's sounds, so its name says.
export function liquidAreas(rows) {
  const areas = new Map();
  for (const r of rows) {
    const bank = Number(r.SoundBank);
    const area = bank >= 2 ? AREA_NONE : bank === 1 || /Ocean/.test(r.Name) ? AREA_OCEAN : AREA_WATER;
    areas.set(Number(r.ID), area);
  }
  return areas;
}

// { verts: [[x, y, z], ...] world yards, polys: [{ verts: [i...], neighbours: [n...], area }] } or null.
// A neighbour is a poly index, -1 for a wall, or -2 - dir for an edge on the tile's side dir.
export async function build(geometry, tx, ty, liquids) {
  if (!ready) { await init(); ready = true; }
  if (!geometry.tris.length) return null;
  const ctx = new RecastBuildContext();
  const cfg = Config();
  const box = bounds(tx, ty);
  const pos = new Float32Array(geometry.verts.length);
  let lo = Infinity, hi = -Infinity;
  for (let i = 0; i < geometry.verts.length; i += 3) {
    const r = Rc(geometry.verts[i], geometry.verts[i + 1], geometry.verts[i + 2]);
    pos[i] = r[0]; pos[i + 1] = r[1]; pos[i + 2] = r[2];
    lo = Math.min(lo, r[1]); hi = Math.max(hi, r[1]);
  }
  const pad = BORDER * CELL;
  const bmin = [-box.y0 - pad, lo - 1, -box.x0 - pad], bmax = [-box.y1 + pad, hi + 1, -box.x1 + pad];
  const grid = calcGridSize(bmin, bmax, CELL);
  const verts = new FloatArray(); verts.copy(pos);
  const tris = new IntArray(); tris.copy(Int32Array.from(geometry.tris));
  const nv = pos.length / 3, nt = geometry.tris.length / 3;
  const areas = new UnsignedCharArray(); areas.resize(nt);

  const hf = allocHeightfield();
  createHeightfield(ctx, hf, grid.width, grid.height, bmin, bmax, CELL, CELL_HEIGHT);
  markWalkableTriangles(ctx, cfg.walkableSlopeAngle, verts, nv, tris, nt, areas);
  rasterizeTriangles(ctx, verts, nv, tris, areas, nt, hf, cfg.walkableClimb);
  filterLowHangingWalkableObstacles(ctx, cfg.walkableClimb, hf);
  filterLedgeSpans(ctx, cfg.walkableHeight, cfg.walkableClimb, hf);
  filterWalkableLowHeightSpans(ctx, cfg.walkableHeight, hf);
  const chf = allocCompactHeightfield();
  buildCompactHeightfield(ctx, cfg.walkableHeight, cfg.walkableClimb, hf, chf);
  freeHeightfield(hf);
  erodeWalkableArea(ctx, cfg.walkableRadius, chf);
  MarkWater(ctx, chf, geometry.water, liquids);
  buildDistanceField(ctx, chf);
  buildRegions(ctx, chf, cfg.borderSize, cfg.minRegionArea, cfg.mergeRegionArea);
  const cset = allocContourSet();
  buildContours(ctx, chf, cfg.maxSimplificationError, cfg.maxEdgeLen, cset, Recast.RC_CONTOUR_TESS_WALL_EDGES);
  const pm = allocPolyMesh();
  buildPolyMesh(ctx, cset, cfg.maxVertsPerPoly, pm);
  freeCompactHeightfield(chf);
  freeContourSet(cset);
  verts.destroy(); tris.destroy(); areas.destroy();

  const mesh = new RecastPolyMesh(pm.raw ?? pm);
  const out = Read(mesh);
  freePolyMesh(pm);
  return out;
}

function Read(mesh) {
  const nvp = mesh.nvp();
  const o = mesh.bmin();
  const bmin = [o.x, o.y, o.z];
  const verts = [];
  for (let i = 0; i < mesh.nverts(); i++) {
    const vx = mesh.verts(i * 3), vy = mesh.verts(i * 3 + 1), vz = mesh.verts(i * 3 + 2);
    const rx = bmin[0] + vx * CELL, ry = bmin[1] + vy * CELL_HEIGHT, rz = bmin[2] + vz * CELL;
    verts.push([-rz, -rx, ry]);
  }
  const polys = [];
  for (let p = 0; p < mesh.npolys(); p++) {
    const vs = [], ns = [];
    for (let k = 0; k < nvp; k++) {
      const v = mesh.polys(p * nvp * 2 + k);
      if (v === 0xffff) break;
      vs.push(v);
      const n = mesh.polys(p * nvp * 2 + nvp + k);
      ns.push(n === 0xffff ? -1 : (n & 0x8000) ? -2 - (n & 0xf) : n);
    }
    polys.push({ verts: vs, neighbours: ns, area: mesh.areas(p) });
  }
  return { verts, polys };
}

// Puts a model's vertices into the world. The rotation order and the half turn were fitted against
// the bounding boxes the map files store for every WMO they place (28 WMOs, 0.002 yards apart).
const D = Math.PI / 180;
const HALF_TURN = 180;

function Rz(a) { const c = Math.cos(a), s = Math.sin(a); return [[c, -s, 0], [s, c, 0], [0, 0, 1]]; }
function Ry(a) { const c = Math.cos(a), s = Math.sin(a); return [[c, 0, s], [0, 1, 0], [-s, 0, c]]; }
function Rx(a) { const c = Math.cos(a), s = Math.sin(a); return [[1, 0, 0], [0, c, -s], [0, s, c]]; }
function Mul(A, B) { return A.map(r => [0, 1, 2].map(j => r[0] * B[0][j] + r[1] * B[1][j] + r[2] * B[2][j])); }

// A function from a model's (x, y, z) to the world's, for a placement { pos, rot, scale }.
export function placer(p) {
  const M = Mul(Mul(Rz((p.rot[1] + HALF_TURN) * D), Ry(p.rot[0] * D)), Rx(p.rot[2] * D));
  const s = p.scale;
  return (x, y, z) => [
    p.pos.x + s * (M[0][0] * x + M[0][1] * y + M[0][2] * z),
    p.pos.y + s * (M[1][0] * x + M[1][1] * y + M[1][2] * z),
    p.pos.z + s * (M[2][0] * x + M[2][1] * y + M[2][2] * z),
  ];
}

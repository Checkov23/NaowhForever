// A small CBOR writer for what the walking data holds: integers, strings, arrays and string-keyed maps.
// The client reads it back with C_EncodingUtil.DeserializeCBOR.
function Head(out, major, n) {
  if (n < 24) out.push((major << 5) | n);
  else if (n < 0x100) out.push((major << 5) | 24, n);
  else if (n < 0x10000) out.push((major << 5) | 25, n >> 8, n & 0xff);
  else if (n < 0x100000000) out.push((major << 5) | 26, (n >>> 24) & 0xff, (n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff);
  else throw new Error(`too big for the walking data: ${n}`);
}

function Write(out, v) {
  if (Number.isInteger(v)) {
    if (v >= 0) Head(out, 0, v); else Head(out, 1, -1 - v);
  } else if (typeof v === 'string') {
    const bytes = Buffer.from(v, 'utf8');
    Head(out, 3, bytes.length);
    for (const b of bytes) out.push(b);
  } else if (Array.isArray(v)) {
    Head(out, 4, v.length);
    for (const item of v) Write(out, item);
  } else if (v && typeof v === 'object') {
    const keys = Object.keys(v);
    Head(out, 5, keys.length);
    for (const k of keys) { Write(out, k); Write(out, v[k]); }
  } else {
    throw new Error(`the walking data holds no ${typeof v}: ${v}`);
  }
}

export function encode(v) {
  const out = [];
  Write(out, v);
  return Buffer.from(out);
}

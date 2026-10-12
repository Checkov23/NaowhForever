// Reads the Forever client's files from Blizzard's CDN by file ID, keeping each one in .cache/files
// so a second bake downloads nothing. The product is wow_classic_beta, which is Forever.
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { CASCClient } from '@rhyster/wow-casc-dbc';

const HERE = dirname(fileURLToPath(import.meta.url));
export const CACHE = join(HERE, '.cache');
const FILES = join(CACHE, 'files');
const REGION = 'us';
const PRODUCT = 'wow_classic_beta';

let opening;
export let version;

async function Open() {
  version = await CASCClient.getProductVersion(REGION, PRODUCT);
  const client = new CASCClient(REGION, PRODUCT, version, CASCClient.LogLevel.warn);
  await client.init();
  await client.loadRemoteTACTKeys();
  return client;
}

function open() {
  opening ??= Open();
  return opening;
}

// The file's bytes, or null when the build has no such file (a model a map names but the client lacks).
export async function file(fdid) {
  const path = join(FILES, String(fdid));
  if (existsSync(path)) {
    const bytes = await readFile(path);
    return bytes.length ? bytes : null;
  }
  const c = await open();
  const keys = c.getContentKeysByFileDataID(fdid);
  let bytes = null;
  if (keys && keys.length) {
    try {
      bytes = (await c.getFileByContentKey(keys[0].cKey)).buffer;
    } catch (err) {
      if (!String(err.message).includes('encrypt')) throw err;
    }
  }
  await mkdir(FILES, { recursive: true });
  await writeFile(path, bytes ?? Buffer.alloc(0));
  return bytes;
}

// Every chunk of a chunked file: { id, start, size } with id read the right way round.
export function chunks(buf, from = 0, to = buf.length) {
  const list = [];
  const end = Math.min(to, buf.length);
  let off = from;
  while (off + 8 <= end) {
    const id = buf.toString('ascii', off, off + 4).split('').reverse().join('');
    const size = buf.readUInt32LE(off + 4);
    list.push({ id, start: off + 8, size });
    off += 8 + size;
  }
  return list;
}

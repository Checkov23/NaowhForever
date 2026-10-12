// The game's tables for a Forever build as CSV rows from wago.tools, the same source as Tools/sources/wago.py.
const AGENT = 'NaowhForever-tools (+https://github.com/naowh-gaming/NaowhForever)';

function Parse(text) {
  const rows = [];
  let row = [], field = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n') { row.push(field.replace(/\r$/, '')); rows.push(row); row = []; field = ''; }
    else field += c;
  }
  if (field || row.length) { row.push(field); rows.push(row); }
  return rows;
}

export async function table(name, build) {
  const res = await fetch(`https://wago.tools/db2/${name}/csv?build=${build}`, { headers: { 'User-Agent': AGENT } });
  if (!res.ok) throw new Error(`${name}: ${res.status} from wago.tools`);
  const [head, ...rows] = Parse(await res.text());
  return rows.filter(r => r.length === head.length).map(r => Object.fromEntries(head.map((h, i) => [h, r[i]])));
}

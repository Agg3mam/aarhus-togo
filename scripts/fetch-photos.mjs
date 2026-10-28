// Finder et frit licenseret foto til hvert sted via OpenStreetMap → Wikidata (P18) → Wikimedia Commons.
// Kør: node scripts/fetch-photos.mjs  → ios/HyggeVert/Images/<id>.jpg + ios/HyggeVert/Data/photo-credits.json
// Steder uden foto på Commons får intet billede (appen viser så kategoriens farve og ikon).
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const UA = { 'User-Agent': 'HyggeVert-school-prototype/1.0 (school project)' };
const root = new URL('../ios/HyggeVert/', import.meta.url);
const { places } = JSON.parse(readFileSync(new URL('Data/places.json', root)));
const overrides = JSON.parse(readFileSync(new URL('./photo-overrides.json', import.meta.url)));
const imgDir = new URL('Images/', root);
mkdirSync(imgDir, { recursive: true });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function getJSON(url) {
  for (let i = 0; i < 5; i++) {
    const res = await fetch(url, { headers: UA });
    const text = await res.text();
    try { return JSON.parse(text); } catch { await sleep(5000 * (i + 1)); }
  }
  throw new Error('For mange kald: ' + url);
}
const strip = (html) => (html ?? '').replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();

const creditsUrl = new URL('Data/photo-credits.json', root);
// Fotos, der allerede er hentet, beholdes (slet filen for at starte forfra).
const credits = existsSync(creditsUrl) ? JSON.parse(readFileSync(creditsUrl)) : {};
for (const p of places) {
  if (credits[p.id] && !overrides[p.id]) continue;
  let file = overrides[p.id]?.file ?? null;
  let qid = overrides[p.id]?.wikidata ?? null;
  if (overrides[p.id] === null) { console.log('–', p.id, '(fravalgt)'); continue; }
  if (!file && !qid && p.osm) {
    try {
      const [type, id] = p.osm.split('/');
      const el = (await getJSON(`https://api.openstreetmap.org/api/0.6/${type}/${id}.json`)).elements?.[0];
      qid = el?.tags?.wikidata ?? null;
      if (el?.tags?.wikimedia_commons?.startsWith('File:')) file = el.tags.wikimedia_commons.slice(5);
    } catch {}
    await sleep(600);
  }
  if (!file && qid) {
    const wd = await getJSON(`https://www.wikidata.org/wiki/Special:EntityData/${qid}.json`);
    file = wd.entities?.[qid]?.claims?.P18?.[0]?.mainsnak?.datavalue?.value ?? null;
  }
  if (!file) { console.log('–', p.id, qid ? `(${qid} uden foto)` : '(ingen Wikidata)'); continue; }

  const info = await getJSON('https://commons.wikimedia.org/w/api.php?action=query&format=json&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=900&titles=' + encodeURIComponent('File:' + file));
  const page = Object.values(info.query.pages)[0];
  const ii = page.imageinfo?.[0];
  if (!ii) { console.log('–', p.id, 'Commons-fil mangler', file); continue; }
  const m = ii.extmetadata;
  const out = new URL(`Images/${p.id}.jpg`, root);
  if (!existsSync(out)) {
    const buf = Buffer.from(await (await fetch(ii.thumburl, { headers: UA })).arrayBuffer());
    writeFileSync(out, buf);
    execFileSync('sips', ['-Z', '800', '-s', 'format', 'jpeg', '-s', 'formatOptions', '60', out.pathname, '--out', out.pathname], { stdio: 'ignore' });
  }
  credits[p.id] = {
    file,
    // Ryd op i Commons' forfatterfelt ("Nico-dk (talk) 21:08 …", "Original uploader was …").
    author: strip(m.Artist?.value).replace(/\s*\(talk\).*$/, '').replace(/^No machine-readable author.*$/, '')
      .replace(/^Original uploader was\s+/, '').replace(/\s+at\s+\S+\.wikipedia.*$/, '').replace(/^user\s+/, '').trim(),
    license: strip(m.LicenseShortName?.value),
    url: ii.descriptionurl,
  };
  console.log('✓', p.id.padEnd(20), credits[p.id].license.padEnd(14), credits[p.id].author.slice(0, 40));
  await sleep(1200);
  writeFileSync(creditsUrl, JSON.stringify(credits, null, 1));
}
writeFileSync(creditsUrl, JSON.stringify(credits, null, 1));
console.log(Object.keys(credits).length, 'fotos af', places.length, 'steder');

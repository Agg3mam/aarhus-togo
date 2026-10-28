// Slår stedernes koordinater op i OpenStreetMap via Nominatim (højst 1 kald pr. sekund).
// Kør: node scripts/geocode.mjs  → data/places.json  (steder, der ikke findes, skrives ud og udelades)
import { readFileSync, writeFileSync } from 'node:fs';

const src = JSON.parse(readFileSync(new URL('./places-src.json', import.meta.url)));
const outUrl = new URL('../ios/HyggeVert/Data/places.json', import.meta.url);
// Steder, der allerede har koordinater, slås ikke op igen (kør med --all for at slå alle op).
const known = process.argv.includes('--all') ? new Map()
  : new Map(JSON.parse(readFileSync(outUrl)).places.map((p) => [p.id, p]));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const places = [], missing = [];

for (const p of src) {
  const old = known.get(p.id);
  if (old) {
    const { q, alt, ...rest } = p;
    places.push({ ...rest, lat: old.lat, lng: old.lng, osm: old.osm });
    continue;
  }
  let hit = null;
  for (const q of [p.q, ...(p.alt ?? [])]) {
    const url = 'https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&countrycodes=dk&q=' + encodeURIComponent(q);
    const res = await fetch(url, { headers: { 'User-Agent': 'HyggeVert-school-prototype/1.0', 'Accept-Language': 'da' } });
    const [r] = await res.json();
    await sleep(1100);
    if (r) { hit = r; break; }
  }
  if (!hit) { missing.push(p.name); console.log('IKKE FUNDET', p.name); continue; }
  const { q, alt, ...rest } = p;
  places.push({ ...rest, lat: +(+hit.lat).toFixed(6), lng: +(+hit.lon).toFixed(6), osm: `${hit.osm_type}/${hit.osm_id}` });
  console.log(p.id.padEnd(20), hit.lat, hit.lon, '|', hit.category + '/' + hit.type, '|', hit.display_name.slice(0, 90));
}
writeFileSync(outUrl, JSON.stringify({
  source: 'Koordinater: OpenStreetMap contributors via Nominatim (ODbL). Beskrivelser: skrevet til Aarhus ToGo.',
  missing, places,
}, null, 1));

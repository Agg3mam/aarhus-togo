// Henter bus- og letbanestoppesteder i Aarhus Kommune fra OpenStreetMap (Overpass API) én gang.
// Kør: node scripts/fetch-stops.mjs  → src/data/stops.json
import { writeFileSync } from 'node:fs';

const query = `[out:json][timeout:90];
area["name"="Aarhus Kommune"]["admin_level"="7"]->.a;
(
  node["highway"="bus_stop"](area.a);
  node["railway"="tram_stop"](area.a);
  nwr["public_transport"="platform"]["tram"="yes"](area.a);
  node["public_transport"="stop_position"]["tram"="yes"](area.a);
  nwr["railway"="platform"]["tram"="yes"](area.a);
);
out center;`;

const res = await fetch(process.env.OVERPASS ?? 'https://overpass-api.de/api/interpreter', {
  method: 'POST',
  headers: { 'User-Agent': 'HyggeVert-school-prototype/1.0', 'Content-Type': 'application/x-www-form-urlencoded' },
  body: 'data=' + encodeURIComponent(query),
});
if (!res.ok) throw new Error('Overpass ' + res.status);
const { elements } = await res.json();

const dist = (a, b) => {
  const R = 6371000, r = Math.PI / 180;
  const dLat = (b.lat - a.lat) * r, dLng = (b.lng - a.lng) * r;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * r) * Math.cos(b.lat * r) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
};

// Saml perroner med samme navn inden for 150 m til ét stoppested (begge retninger).
const stops = [];
for (const e of elements) {
  const name = e.tags?.name;
  if (!name) continue;
  const type = e.tags.railway === 'tram_stop' || e.tags.tram === 'yes' ? 'tram' : 'bus';
  const lat = e.lat ?? e.center?.lat, lon = e.lon ?? e.center?.lon;
  if (lat == null) continue;
  const p = { lat, lng: lon };
  const twin = stops.find((s) => s.name === name && s.type === type && dist(s, p) < (type === 'tram' ? 400 : 150));
  if (twin) continue;
  stops.push({ id: 'osm-' + e.id, name, type, lat: +lat.toFixed(6), lng: +lon.toFixed(6) });
}
// Et letbanestop med samme navn som et busstop vinder (letbanen er den interessante).
writeFileSync(new URL('../ios/HyggeVert/Data/stops.json', import.meta.url), JSON.stringify({
  source: 'OpenStreetMap contributors via Overpass API (ODbL)',
  fetched: new Date().toISOString().slice(0, 10),
  stops,
}));
console.log(`${elements.length} OSM-noder → ${stops.length} stoppesteder (${stops.filter((s) => s.type === 'tram').length} letbane)`);

// Henter Donkey Republic-hubs i Aarhus fra det offentlige GBFS-feed (CC0-1.0) én gang.
// Kør: node scripts/fetch-donkey.mjs  → src/data/donkey-hubs.json
import { writeFileSync } from 'node:fs';

const url = 'https://stables.donkey.bike/api/public/gbfs/2/donkey_aarhus/en/station_information.json';
const { data } = await (await fetch(url)).json();
const hubs = data.stations.map((s) => ({
  id: s.station_id,
  name: s.name.trim(),
  lat: +s.lat.toFixed(6),
  lng: +s.lon.toFixed(6),
  deeplink: s.rental_uris?.ios ?? null,
  demo: false,
}));
writeFileSync(new URL('../ios/HyggeVert/Data/donkey-hubs.json', import.meta.url), JSON.stringify({
  source: 'Donkey Republic GBFS station_information (licens CC0-1.0)',
  url,
  fetched: new Date().toISOString().slice(0, 10),
  hubs,
}));
console.log(hubs.length + ' Donkey-hubs');
